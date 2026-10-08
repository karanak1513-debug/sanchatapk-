const https = require('https');

async function testUrl(url, method = 'GET') {
  return new Promise((resolve) => {
    const req = https.request(url, { method }, (res) => {
      resolve({
        statusCode: res.statusCode,
        headers: res.headers,
      });
    });
    req.on('error', (err) => {
      resolve({ error: err.message });
    });
    req.end();
  });
}

async function verify() {
  const baseUrl = 'https://stitchsanchaywealthappuisystem.vercel.app';
  console.log(`Verifying deployment at ${baseUrl}...`);

  const tests = [
    { name: 'Root URL (/)', url: `${baseUrl}/`, method: 'GET' },
    { name: 'Deep-link /privacy', url: `${baseUrl}/privacy`, method: 'GET' },
    { name: 'Deep-link /terms', url: `${baseUrl}/terms`, method: 'GET' },
    { name: 'APK Download Endpoint', url: `${baseUrl}/downloads/sanchat-release.apk`, method: 'HEAD' },
  ];

  for (const t of tests) {
    const res = await testUrl(t.url, t.method);
    console.log(`[${t.name}] Status: ${res.statusCode}`);
    if (t.name.includes('APK')) {
      console.log(`  Content-Disposition: ${res.headers['content-disposition']}`);
      console.log(`  Content-Length: ${res.headers['content-length']} bytes`);
      console.log(`  Cache-Control: ${res.headers['cache-control']}`);
    }
  }
}

verify();
