import { readdir, readFile, writeFile } from 'node:fs/promises';
import { join, relative } from 'node:path';
import { createHash } from 'node:crypto';
const root = 'build/web';
const files = [];
async function walk(dir) {
  for (const entry of await readdir(dir, { withFileTypes: true })) {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) await walk(path);
    else if (!entry.name.endsWith('.map') && !['sw.js', '.last_build_id'].includes(entry.name)) files.push(relative(root, path).replaceAll('\\', '/'));
  }
}
await walk(root);
files.sort();
const digest = createHash('sha256');
for (const file of files) digest.update(await readFile(join(root, file)));
const version = digest.digest('hex').slice(0, 16);
await writeFile(join(root, 'sw.js'), `
const CACHE = 'nido-' + ${JSON.stringify(version)};
const FILES = ${JSON.stringify(files)};
self.addEventListener('install', event => event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(FILES.map(f => new URL(f, self.registration.scope).href)))));
self.addEventListener('activate', event => event.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(k => k.startsWith('nido-') && k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim())));
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);
  if (event.request.method !== 'GET' || !url.href.startsWith(self.registration.scope)) return;
  if (event.request.mode === 'navigate') {
    event.respondWith(fetch(event.request).catch(() => caches.match(new URL('index.html', self.registration.scope).href)));
  } else {
    event.respondWith(caches.match(event.request).then(cached => cached || fetch(event.request)));
  }
});
`);
console.log(`Offline cache generated: ${files.length} files, version ${version}`);
