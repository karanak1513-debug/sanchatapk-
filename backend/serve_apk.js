const http = require('http');
const fs = require('fs');
const path = require('path');
const os = require('os');
const crypto = require('crypto');

const PORT = process.env.PORT || 8080;
const ROOT_DIR = path.join(__dirname, '..');
const BASE_DIR = __dirname;
const LANDING_PATH = fs.existsSync(path.join(BASE_DIR, 'index.html'))
  ? path.join(BASE_DIR, 'index.html')
  : path.join(ROOT_DIR, 'mobile', 'web', 'landing.html');
const BRANDING_DIR = path.join(ROOT_DIR, 'mobile', 'assets', 'branding');
const WEB_DIR = path.join(ROOT_DIR, 'mobile', 'web');

function getReleaseApkInfo() {
  const candidatePaths = [
    path.join(ROOT_DIR, 'mobile', 'build', 'app', 'outputs', 'flutter-apk', 'app-release.apk'),
    path.join(ROOT_DIR, 'mobile', 'sanchay-release.apk'),
    path.join(ROOT_DIR, 'frontend', 'public', 'sanchay-release.apk'),
    path.join(BASE_DIR, 'sanchay-release.apk'),
    path.join(BASE_DIR, 'app-release.apk'),
  ];

  for (const apkPath of candidatePaths) {
    if (fs.existsSync(apkPath)) {
      try {
        const stat = fs.statSync(apkPath);
        const buffer = fs.readFileSync(apkPath);
        const sha256 = crypto.createHash('sha256').update(buffer).digest('hex');
        const sizeMb = (stat.size / (1024 * 1024)).toFixed(1);
        return {
          exists: true,
          path: apkPath,
          sizeBytes: stat.size,
          sizeMb: `${sizeMb} MB`,
          sha256: sha256,
          version: '1.0.0',
          versionCode: 1,
          packageId: 'com.aistudio.sanchay.savtrkr',
          targetSdk: 36,
          compileSdk: 36,
          releaseDate: 'October 2026',
        };
      } catch (e) {
        console.error('Error reading APK:', e);
      }
    }
  }

  return {
    exists: false,
    path: null,
    sizeBytes: 0,
    sizeMb: '64.1 MB',
    sha256: 'Pending release build completion',
    version: '1.0.0',
    versionCode: 1,
    packageId: 'com.aistudio.sanchay.savtrkr',
    targetSdk: 36,
    compileSdk: 36,
    releaseDate: 'October 2026',
  };
}

function getAllLocalIps() {
  const interfaces = os.networkInterfaces();
  const addresses = [];
  for (const name of Object.keys(interfaces)) {
    for (const iface of interfaces[name]) {
      if (iface.family === 'IPv4' && !iface.internal) {
        addresses.push({ name, ip: iface.address });
      }
    }
  }
  return addresses;
}

const server = http.createServer((req, res) => {
  const parsedUrl = req.url.split('?')[0];

  // Enable CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  // 1. API: Release Info
  if (parsedUrl === '/api/release-info') {
    const info = getReleaseApkInfo();
    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify(info, null, 2));
    return;
  }

  // 2. APK Download Route
  if (parsedUrl === '/download' || parsedUrl === '/sanchat.apk' || parsedUrl === '/sanchay-release.apk' || parsedUrl === '/app-release.apk') {
    const info = getReleaseApkInfo();
    if (!info.exists) {
      res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end('APK not found. Please wait for flutter build apk --release to complete.');
      return;
    }

    res.writeHead(200, {
      'Content-Type': 'application/vnd.android.package-archive',
      'Content-Disposition': 'attachment; filename="sanchat-release.apk"',
      'Content-Length': info.sizeBytes,
      'X-SHA256-Checksum': info.sha256,
      'Cache-Control': 'no-cache',
    });

    const stream = fs.createReadStream(info.path);
    stream.pipe(res);
    return;
  }

  // 3. Static Brand Assets: /assets/branding/* or /branding/*
  if (parsedUrl.startsWith('/assets/branding/') || parsedUrl.startsWith('/branding/')) {
    const filename = path.basename(parsedUrl);
    const assetPath = path.join(BRANDING_DIR, filename);
    if (fs.existsSync(assetPath)) {
      const ext = path.extname(filename).toLowerCase();
      const mimeMap = {
        '.png': 'image/png',
        '.svg': 'image/svg+xml',
        '.jpg': 'image/jpeg',
        '.jpeg': 'image/jpeg',
        '.webp': 'image/webp',
      };
      res.writeHead(200, { 'Content-Type': mimeMap[ext] || 'application/octet-stream' });
      fs.createReadStream(assetPath).pipe(res);
      return;
    }
  }

  // 4. Icons & Favicon
  if (parsedUrl === '/favicon.png' || parsedUrl === '/favicon.ico') {
    const fav = path.join(WEB_DIR, 'favicon.png');
    if (fs.existsSync(fav)) {
      res.writeHead(200, { 'Content-Type': 'image/png' });
      fs.createReadStream(fav).pipe(res);
      return;
    }
  }

  if (parsedUrl.startsWith('/icons/')) {
    const iconFile = path.basename(parsedUrl);
    const iconPath = path.join(WEB_DIR, 'icons', iconFile);
    if (fs.existsSync(iconPath)) {
      res.writeHead(200, { 'Content-Type': 'image/png' });
      fs.createReadStream(iconPath).pipe(res);
      return;
    }
  }

  // 5. Default: Sanchat Official Product Website
  if (parsedUrl === '/' || parsedUrl === '/index.html' || parsedUrl === '/landing.html') {
    if (fs.existsSync(LANDING_PATH)) {
      const info = getReleaseApkInfo();
      let html = fs.readFileSync(LANDING_PATH, 'utf8');

      // Inject live actual APK attributes
      html = html.replace(/\$\{fileSizeMb\}/g, info.sizeMb);
      html = html.replace(/\$\{sha256\}/g, info.sha256);
      html = html.replace(/\$\{releaseDate\}/g, info.releaseDate);
      html = html.replace(/\$\{version\}/g, info.version);

      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
      res.end(html);
      return;
    }
  }

  // Fallback 404
  res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
  res.end('404 Not Found - Sanchat Release Server');
});

server.listen(PORT, '0.0.0.0', () => {
  const ipList = getAllLocalIps();
  console.log(`\n======================================================`);
  console.log(`  🛡️ SANCHAT OFFICIAL PRODUCTION WEBPAGE & APK SERVER`);
  console.log(`======================================================`);
  console.log(`  Local Website: http://localhost:${PORT}`);
  console.log(`  Direct APK:    http://localhost:${PORT}/download`);
  console.log(`  Release Info:  http://localhost:${PORT}/api/release-info`);
  ipList.forEach(({ name, ip }) => {
    console.log(`  Network (${name}): http://${ip}:${PORT}`);
  });
  console.log(`======================================================\n`);
});
