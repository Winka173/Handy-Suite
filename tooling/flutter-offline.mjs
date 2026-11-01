import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
const app = process.argv[2] ?? 'handy_tools';
if (!/^handy_(tools|docs|media|dev|keep|recall|save|spend)$/.test(app))
  throw new Error('Unknown Flutter app');
const root = path.resolve(`apps/${app}/build/web`);
if (app === 'handy_save')
  fs.copyFileSync(
    'apps/handy_save/web/save_share_worker.js',
    path.join(root, 'save_share_worker.js'),
  );
function walk(dir) {
  return fs
    .readdirSync(dir, { withFileTypes: true })
    .flatMap((e) =>
      e.isDirectory() ? walk(path.join(dir, e.name)) : [path.join(dir, e.name)],
    );
}
const files = walk(root)
  .sort()
  .filter(
    (f) =>
      !f.endsWith('.map') &&
      !f.includes('service_worker') &&
      !path.basename(f).startsWith('.'),
  );
const hash = createHash('sha256');
for (const f of files) {
  hash.update(path.relative(root, f));
  hash.update(fs.readFileSync(f));
}
const version = hash.digest('hex').slice(0, 16),
  urls = files.map((f) => path.relative(root, f).replaceAll('\\', '/'));
const worker = `const CACHE=${JSON.stringify(`${app}-assets-${version}`)};
const URLS=${JSON.stringify(urls)};
const OWN_PREFIX=${JSON.stringify(`${app}-assets-`)};
self.addEventListener('install',event=>event.waitUntil((async()=>{const cache=await caches.open(CACHE);await cache.addAll(URLS);})()));
self.addEventListener('message',event=>{if(event.data?.type==='activate-update')self.skipWaiting();});
self.addEventListener('activate',event=>event.waitUntil((async()=>{for(const key of await caches.keys())if(key.startsWith(OWN_PREFIX)&&key!==CACHE)await caches.delete(key);await self.clients.claim();})()));
self.addEventListener('fetch',event=>{const url=new URL(event.request.url),base=new URL(self.registration.scope);if(event.request.method!=='GET'||url.origin!==base.origin)return;const relative=url.pathname.slice(base.pathname.length);if(event.request.mode==='navigate'){event.respondWith(caches.open(CACHE).then(c=>c.match('index.html')).then(cached=>cached||fetch(event.request)));}else if(URLS.includes(relative)){event.respondWith(caches.open(CACHE).then(c=>c.match(relative)).then(cached=>cached||fetch(event.request)));}});`;
fs.writeFileSync(
  path.join(root, `${app}_service_worker.js`),
  worker +
    (app === 'handy_save' ? "\nimportScripts('save_share_worker.js');\n" : ''),
);
fs.mkdirSync('docs/qa/evidence', { recursive: true });
fs.writeFileSync(
  `docs/qa/evidence/${app}-offline-assets.json`,
  JSON.stringify(
    {
      version,
      files: urls,
      bytes: files.reduce((sum, f) => sum + fs.statSync(f).size, 0),
      scope:
        'static assets only; no user files, API responses or tokens cached',
    },
    null,
    2,
  ),
);
process.stdout.write(
  `Offline asset cache ${app}: ${urls.length} files, version ${version}\n`,
);
