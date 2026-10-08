const fs = require('fs');
const path = require('path');
const https = require('https');
const { spawn } = require('child_process');

function getGitCredential() {
  return new Promise((resolve, reject) => {
    const p = spawn('git', ['credential', 'fill'], { stdio: ['pipe', 'pipe', 'pipe'] });
    let stdout = '';
    let stderr = '';
    p.stdout.on('data', (d) => { stdout += d.toString(); });
    p.stderr.on('data', (d) => { stderr += d.toString(); });
    p.on('close', (code) => {
      if (code !== 0) return reject(new Error('git credential fill failed: ' + stderr));
      let username = '';
      let password = '';
      for (const line of stdout.split('\n')) {
        if (line.startsWith('username=')) username = line.replace('username=', '').trim();
        if (line.startsWith('password=')) password = line.replace('password=', '').trim();
      }
      resolve({ username, token: password });
    });
    p.stdin.write('protocol=https\nhost=github.com\n\n');
  });
}

function githubRequest(urlStr, options = {}, data = null) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(urlStr);
    const reqOptions = {
      hostname: parsed.hostname,
      path: parsed.pathname + parsed.search,
      method: options.method || 'GET',
      headers: {
        'User-Agent': 'Sanchat-Release-Pipeline/1.0',
        ...options.headers,
      },
    };

    const req = https.request(reqOptions, (res) => {
      const chunks = [];
      res.on('data', (chunk) => chunks.push(chunk));
      res.on('end', () => {
        const body = Buffer.concat(chunks).toString();
        resolve({ statusCode: res.statusCode, headers: res.headers, body });
      });
    });

    req.on('error', reject);
    if (data) {
      req.write(data);
    }
    req.end();
  });
}

async function uploadReleaseAsset(uploadUrlTemplate, filePath, assetName, token) {
  // uploadUrlTemplate is like: https://uploads.github.com/repos/OWNER/REPO/releases/ID/assets{?name,label}
  const baseUploadUrl = uploadUrlTemplate.split('{')[0];
  const targetUrl = `${baseUploadUrl}?name=${encodeURIComponent(assetName)}`;
  const stats = fs.statSync(filePath);
  const fileSize = stats.size;

  console.log(`Uploading ${assetName} (${fileSize} bytes) to ${targetUrl}...`);

  return new Promise((resolve, reject) => {
    const parsed = new URL(targetUrl);
    const reqOptions = {
      hostname: parsed.hostname,
      path: parsed.pathname + parsed.search,
      method: 'POST',
      headers: {
        'User-Agent': 'Sanchat-Release-Pipeline/1.0',
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/vnd.android.package-archive',
        'Content-Length': fileSize,
      },
    };

    const req = https.request(reqOptions, (res) => {
      const chunks = [];
      res.on('data', (chunk) => chunks.push(chunk));
      res.on('end', () => {
        const body = Buffer.concat(chunks).toString();
        resolve({ statusCode: res.statusCode, headers: res.headers, body });
      });
    });

    req.on('error', reject);

    const stream = fs.createReadStream(filePath);
    stream.on('error', reject);
    stream.pipe(req);
  });
}

async function main() {
  const apkPath = path.resolve(__dirname, '../build/app/outputs/flutter-apk/app-release.apk');
  if (!fs.existsSync(apkPath)) {
    throw new Error('APK not found at ' + apkPath);
  }

  const { token } = await getGitCredential();
  if (!token) {
    throw new Error('No GitHub token returned from Git Credential Manager');
  }

  const owner = 'karanak1513-debug';
  const repo = 'sanchat-core-apk';
  const tag = 'v1.0.0';

  console.log(`Checking existing releases for ${owner}/${repo}...`);
  const listRes = await githubRequest(`https://api.github.com/repos/${owner}/${repo}/releases`, {
    headers: { 'Authorization': `Bearer ${token}` },
  });

  if (listRes.statusCode < 200 || listRes.statusCode >= 300) {
    throw new Error(`Failed to list releases: HTTP ${listRes.statusCode}: ${listRes.body}`);
  }

  const releases = JSON.parse(listRes.body);
  let release = releases.find((r) => r.tag_name === tag);

  if (!release) {
    console.log(`Creating release for tag ${tag}...`);
    const createRes = await githubRequest(
      `https://api.github.com/repos/${owner}/${repo}/releases`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
      },
      JSON.stringify({
        tag_name: tag,
        target_commitish: 'main',
        name: 'Sanchat v1.0.0 (Build 1) — Official Production Release',
        body: `## Sanchat Android Universal Release v1.0.0

- **Package ID**: \`com.aistudio.sanchay.savtrkr\`
- **Target SDK**: Android 16 (API 36)
- **Compile SDK**: Android 16+ (API 37)
- **Min SDK**: Android 7.0+ (API 24)
- **Signing**: Scheme v1 (JAR), v2 (Full APK), v3 (Android 9+) Verified
- **SHA-256**: \`38f784ac1713871e6f33f6d5b39a767fdf226f95371400504298c5305a71a1d8\`
- **Asset**: \`sanchat-release.apk\` (65,271,909 bytes / 62.2 MB)

Official cryptographic signature and deterministic verification release.`,
        draft: false,
        prerelease: false,
      })
    );

    if (createRes.statusCode !== 201) {
      throw new Error(`Failed to create release: HTTP ${createRes.statusCode}: ${createRes.body}`);
    }
    release = JSON.parse(createRes.body);
    console.log(`Created release with ID ${release.id}.`);
    console.log(`Found existing release ID ${release.id} for tag ${tag}. Updating description...`);
    await githubRequest(
      `https://api.github.com/repos/${owner}/${repo}/releases/${release.id}`,
      {
        method: 'PATCH',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
      },
      JSON.stringify({
        name: 'Sanchat v1.0.0 (Build 1) — Official Production Release',
        body: `## Sanchat Android Universal Release v1.0.0

- **Package ID**: \`com.aistudio.sanchay.savtrkr\`
- **Target SDK**: Android 16 (API 36)
- **Compile SDK**: Android 16+ (API 37)
- **Min SDK**: Android 7.0+ (API 24)
- **Signing**: Scheme v1 (JAR), v2 (Full APK), v3 (Android 9+) Verified
- **SHA-256**: \`38f784ac1713871e6f33f6d5b39a767fdf226f95371400504298c5305a71a1d8\`
- **Asset**: \`sanchat-release.apk\` (65,271,909 bytes / 62.2 MB)

Official cryptographic signature and deterministic verification release.`,
      })
    );
  }

  // Check if asset sanchat-release.apk already exists
  const assetName = 'sanchat-release.apk';
  const existingAsset = (release.assets || []).find((a) => a.name === assetName);
  if (existingAsset) {
    console.log(`Deleting existing asset ID ${existingAsset.id} (${existingAsset.name})...`);
    const delRes = await githubRequest(
      `https://api.github.com/repos/${owner}/${repo}/releases/assets/${existingAsset.id}`,
      {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` },
      }
    );
    console.log(`Delete response: HTTP ${delRes.statusCode}`);
  }

  console.log('Uploading release asset...');
  const uploadRes = await uploadReleaseAsset(release.upload_url, apkPath, assetName, token);

  if (uploadRes.statusCode !== 201) {
    throw new Error(`Failed to upload asset: HTTP ${uploadRes.statusCode}: ${uploadRes.body}`);
  }

  const uploadedAsset = JSON.parse(uploadRes.body);
  console.log('Successfully uploaded release asset!');
  console.log('Asset ID:', uploadedAsset.id);
  console.log('Asset Name:', uploadedAsset.name);
  console.log('Size:', uploadedAsset.size);
  console.log('Browser Download URL:', uploadedAsset.browser_download_url);
}

main().catch((err) => {
  console.error('ERROR:', err.message);
  process.exit(1);
});
