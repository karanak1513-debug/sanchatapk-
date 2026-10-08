const https = require('https');

async function testUrl(url, method = 'GET', maxRedirects = 5) {
  return new Promise((resolve) => {
    const req = https.request(url, { method }, (res) => {
      if ([301, 302, 307, 308].includes(res.statusCode) && res.headers.location && maxRedirects > 0) {
        return resolve({
          statusCode: res.statusCode,
          headers: res.headers,
          redirectUrl: res.headers.location,
        });
      }
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
    { name: 'Verification Page (/verification)', url: `${baseUrl}/verification`, method: 'GET' },
    { name: 'Deep-link /privacy', url: `${baseUrl}/privacy`, method: 'GET' },
    { name: 'Deep-link /terms', url: `${baseUrl}/terms`, method: 'GET' },
    { name: 'Official Download Route (/download)', url: `${baseUrl}/download`, method: 'GET' },
  ];

  for (const t of tests) {
    const res = await testUrl(t.url, t.method);
    console.log(`[${t.name}] Status: ${res.statusCode}`);
    if (res.redirectUrl) {
      console.log(`  Redirect Location: ${res.redirectUrl.substring(0, 80)}...`);
      // Follow the redirect to verify target asset
      const targetRes = await testUrl(res.redirectUrl, 'HEAD');
      console.log(`  Target Follow Status: ${targetRes.statusCode}`);
      if (targetRes.headers) {
        console.log(`  Target Content-Length: ${targetRes.headers['content-length']} bytes`);
        console.log(`  Target Content-Type: ${targetRes.headers['content-type']}`);
      }
    }
  }
}

verify();
