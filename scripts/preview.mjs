// preview.mjs - 本地静态预览服务器（镜像 Vercel 行为）：
//   * 为 .wasm 返回 application/wasm
//   * 无点路径（应用路由）回退到 index.html（SPA）
// 用法：PORT=8080 node scripts/preview.mjs   （须在项目根目录运行）
import http from 'http';
import { readFile, stat } from 'fs/promises';
import { extname, join, normalize } from 'path';

const root = join(process.cwd(), 'build', 'web');
const port = Number(process.env.PORT) || 8080;

const mime = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript',
  '.mjs': 'text/javascript',
  '.css': 'text/css',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.webp': 'image/webp',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff2': 'font/woff2',
  '.json': 'application/json',
  '.bin': 'application/octet-stream',
  '.frag': 'text/plain',
  '.txt': 'text/plain; charset=utf-8',
};

http
  .createServer(async (req, res) => {
    try {
      let urlPath = decodeURIComponent((req.url || '/').split('?')[0]);
      if (urlPath === '/' || urlPath === '') urlPath = '/index.html';
      let filePath = normalize(join(root, urlPath));
      if (!filePath.startsWith(root)) {
        res.writeHead(403);
        return res.end('forbidden');
      }
      let st;
      try {
        st = await stat(filePath);
      } catch {
        // SPA fallback：把应用路由回退到 index.html
        filePath = join(root, 'index.html');
        st = await stat(filePath);
      }
      if (st.isDirectory()) filePath = join(filePath, 'index.html');
      const data = await readFile(filePath);
      const ct = mime[extname(filePath).toLowerCase()] || 'application/octet-stream';
      res.writeHead(200, {
        'Content-Type': ct,
        'Cache-Control': 'no-store',
        'Cross-Origin-Opener-Policy': 'same-origin',
        'Cross-Origin-Embedder-Policy': 'credentialless',
      });
      res.end(data);
    } catch (e) {
      res.writeHead(500);
      res.end(String(e));
    }
  })
  .listen(port, () => console.log('preview ready: http://localhost:' + port));