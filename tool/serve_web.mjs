import http from 'node:http';
import { readFile } from 'node:fs/promises';
import { resolve, extname, sep } from 'node:path';
const root = resolve('build/web');
const prefix = '/nido-finanzas/';
const mime = { '.html':'text/html; charset=utf-8', '.js':'text/javascript; charset=utf-8', '.json':'application/json', '.wasm':'application/wasm', '.png':'image/png', '.woff2':'font/woff2', '.ttf':'font/ttf' };
http.createServer(async (req,res) => {
  if (req.url === '/') { res.writeHead(302,{Location:prefix}); res.end(); return; }
  try {
    const pathname = decodeURIComponent(new URL(req.url,'http://localhost').pathname);
    if (!pathname.startsWith(prefix)) { res.writeHead(404); res.end(); return; }
    const file = resolve(root,pathname.slice(prefix.length) || 'index.html');
    if (!file.startsWith(root + sep)) { res.writeHead(403); res.end(); return; }
    const data = await readFile(file);
    res.writeHead(200,{'Content-Type':mime[extname(file)] || 'application/octet-stream','Cache-Control':'no-cache'});
    res.end(data);
  } catch { res.writeHead(404); res.end(); }
}).listen(Number(process.env.NIDO_PREVIEW_PORT ?? '8080'),'127.0.0.1',()=>console.log(`Nido preview: http://127.0.0.1:${process.env.NIDO_PREVIEW_PORT ?? '8080'}/nido-finanzas/`));
