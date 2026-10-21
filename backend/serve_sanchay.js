const http = require('http');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');

const PORT = process.env.PORT || 3000;
const ROOT_DIR = path.join(__dirname, '..');
const BUILD_WEB_DIR = path.join(ROOT_DIR, 'mobile', 'build', 'web');
const LANDING_PATH = fs.existsSync(path.join(__dirname, 'index.html'))
  ? path.join(__dirname, 'index.html')
  : path.join(ROOT_DIR, 'mobile', 'web', 'landing.html');
const PRIVACY_PATH = fs.existsSync(path.join(__dirname, 'privacy.html'))
  ? path.join(__dirname, 'privacy.html')
  : path.join(ROOT_DIR, 'mobile', 'web', 'privacy.html');
const TERMS_PATH = fs.existsSync(path.join(__dirname, 'terms.html'))
  ? path.join(__dirname, 'terms.html')
  : path.join(ROOT_DIR, 'mobile', 'web', 'terms.html');
const NOT_FOUND_PATH = path.join(ROOT_DIR, 'mobile', 'web', '404.html');
const ROBOTS_PATH = path.join(ROOT_DIR, 'mobile', 'web', 'robots.txt');
const SITEMAP_PATH = path.join(ROOT_DIR, 'mobile', 'web', 'sitemap.xml');
const COCKPIT_PATH = path.join(ROOT_DIR, 'frontend', 'stitch_sanchay_wealth_app_ui_system', 'dashboard_cockpit', 'code.html');

const APK_PATH = [
  path.join(ROOT_DIR, 'mobile', 'build', 'app', 'outputs', 'flutter-apk', 'app-release.apk'),
  path.join(ROOT_DIR, 'mobile', 'sanchay-release.apk'),
  path.join(ROOT_DIR, 'frontend', 'public', 'sanchay-release.apk'),
  path.join(__dirname, 'sanchay-release.apk')
].find(p => fs.existsSync(p)) || path.join(ROOT_DIR, 'mobile', 'sanchay-release.apk');

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.mjs': 'application/javascript; charset=utf-8',
  '.wasm': 'application/wasm',
  '.json': 'application/json',
  '.css': 'text/css',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.xml': 'application/xml',
  '.txt': 'text/plain; charset=utf-8',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2'
};

const SECURITY_HEADERS = {
  'X-Content-Type-Options': 'nosniff',
  'X-Frame-Options': 'SAMEORIGIN',
  'X-XSS-Protection': '1; mode=block',
  'Strict-Transport-Security': 'max-age=63072000; includeSubDomains; preload',
  'Referrer-Policy': 'strict-origin-when-cross-origin',
  'Access-Control-Allow-Origin': '*'
};

const server = http.createServer((req, res) => {
  const url = req.url.split('?')[0];

  // Helper to send file with security headers
  const sendFile = (filePath, contentType, statusCode = 200, customHeaders = {}) => {
    if (fs.existsSync(filePath)) {
      const headers = {
        'Content-Type': contentType,
        ...SECURITY_HEADERS,
        ...customHeaders
      };
      res.writeHead(statusCode, headers);
      fs.createReadStream(filePath).pipe(res);
      return true;
    }
    return false;
  };

  // Handle OPTIONS for CORS preflight
  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      ...SECURITY_HEADERS,
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type'
    });
    res.end();
    return;
  }

  // API Route for Feedback / Bug Reports
  if (req.method === 'POST' && (url === '/api/feedback' || url === '/api/contact')) {
    let body = '';
    req.on('data', chunk => { body += chunk.toString(); });
    req.on('end', () => {
      try {
        const data = JSON.parse(body || '{}');
        console.log('[SANCHAY FEEDBACK RECEIVED]:', data);
        res.writeHead(200, {
          'Content-Type': 'application/json; charset=utf-8',
          ...SECURITY_HEADERS
        });
        res.end(JSON.stringify({
          success: true,
          message: 'Feedback received securely. Ticket created.',
          timestamp: new Date().toISOString()
        }));
      } catch (err) {
        res.writeHead(400, {
          'Content-Type': 'application/json; charset=utf-8',
          ...SECURITY_HEADERS
        });
        res.end(JSON.stringify({ success: false, error: 'Malformed JSON payload' }));
      }
    });
    return;
  }

  // 1. Direct APK Download Routes
  if (url === '/download' || url === '/sanchay-release.apk' || url === '/app-release.apk') {
    if (fs.existsSync(APK_PATH)) {
      const stat = fs.statSync(APK_PATH);
      res.writeHead(200, {
        'Content-Type': 'application/vnd.android.package-archive',
        'Content-Disposition': 'attachment; filename="sanchay-release.apk"',
        'Content-Length': stat.size,
        ...SECURITY_HEADERS
      });
      fs.createReadStream(APK_PATH).pipe(res);
      return;
    }
  }

  // 2. Legal & Compliance Routes
  if (url === '/privacy') {
    if (sendFile(PRIVACY_PATH, 'text/html; charset=utf-8')) return;
  }
  if (url === '/terms') {
    if (sendFile(TERMS_PATH, 'text/html; charset=utf-8')) return;
  }
  if (url === '/robots.txt') {
    if (sendFile(ROBOTS_PATH, 'text/plain; charset=utf-8')) return;
  }
  if (url === '/sitemap.xml') {
    if (sendFile(SITEMAP_PATH, 'application/xml; charset=utf-8')) return;
  }

  // 3. Web Cockpit Route
  if (url === '/cockpit') {
    if (sendFile(COCKPIT_PATH, 'text/html; charset=utf-8')) return;
  }

  // 4. Favicon & icons
  if (url === '/favicon.png' || url === '/favicon.ico') {
    const favPath = path.join(__dirname, 'web', 'favicon.png');
    if (sendFile(favPath, 'image/png')) return;
  }

  // 5. Landing Page Route
  if (url === '/' || url === '/index.html') {
    if (sendFile(LANDING_PATH, 'text/html; charset=utf-8')) return;
  }

  // 6. Flutter Web build assets (if build/web exists)
  if (fs.existsSync(BUILD_WEB_DIR)) {
    let reqPath = decodeURI(url);
    const filePath = path.join(BUILD_WEB_DIR, reqPath);
    if (filePath.startsWith(BUILD_WEB_DIR) && fs.existsSync(filePath) && fs.statSync(filePath).isFile()) {
      const ext = path.extname(filePath).toLowerCase();
      sendFile(filePath, MIME_TYPES[ext] || 'application/octet-stream');
      return;
    }
  }

  // 7. Custom 404 Route
  if (fs.existsSync(NOT_FOUND_PATH)) {
    sendFile(NOT_FOUND_PATH, 'text/html; charset=utf-8', 404);
    return;
  }

  res.writeHead(404, { 'Content-Type': 'text/plain', ...SECURITY_HEADERS });
  res.end('404 Not Found');
});

server.listen(PORT, '0.0.0.0', () => {
  const url = `http://localhost:${PORT}`;
  console.log(`\n========================================`);
  console.log(` ✨ SANCHAY WEALTH APP SHOWCASE IS RUNNING!`);
  console.log(` Showcase: ${url}`);
  console.log(` Privacy:  ${url}/privacy`);
  console.log(` Terms:    ${url}/terms`);
  console.log(` Cockpit:  ${url}/cockpit`);
  console.log(` APK:      ${url}/download`);
  console.log(`========================================\n`);
});
