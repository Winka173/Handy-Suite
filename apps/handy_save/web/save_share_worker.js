/* Appended to Handy Save's static-assets worker. Incoming links use IndexedDB,
   never CacheStorage, query strings, network forwarding, or bookmark storage. */
(() => {
  const MAX_BODY = 1048576, MAX_TEXT = 262144, MAX_QUEUE = 100;
  class ShareError extends Error {
    constructor(status, message) { super(message); this.status = status; }
  }
  async function readShare(request) {
    if (request.headers.get('content-type')?.split(';')[0].trim().toLowerCase() !== 'application/x-www-form-urlencoded') {
      throw new ShareError(415, 'Share requires a URL-encoded form. Paste the link in Handy Save instead.');
    }
    const declared = request.headers.get('content-length');
    if (declared && (!/^\d+$/.test(declared) || Number(declared) > MAX_BODY)) throw new ShareError(413, 'Shared content is too large.');
    if (!request.body) throw new ShareError(400, 'The shared content is empty.');
    const reader = request.body.getReader(), chunks = [];
    let size = 0;
    try {
      while (true) {
        const part = await reader.read();
        if (part.done) break;
        size += part.value.byteLength;
        if (size > MAX_BODY) { await reader.cancel(); throw new ShareError(413, 'Shared content is too large.'); }
        chunks.push(part.value);
      }
    } finally { reader.releaseLock(); }
    const data = new Uint8Array(size);
    let offset = 0;
    for (const part of chunks) { data.set(part, offset); offset += part.byteLength; }
    let raw;
    try { raw = new TextDecoder('utf-8', { fatal: true }).decode(data); }
    catch { throw new ShareError(400, 'Shared content must be UTF-8 text.'); }
    const fields = new URLSearchParams(raw);
    for (const name of fields.keys()) {
      if (!['title', 'text', 'url'].includes(name) || fields.getAll(name).length !== 1) throw new ShareError(400, 'Unsupported share fields.');
    }
    const title = (fields.get('title') || '').trim(), text = (fields.get('text') || '').trim(), url = (fields.get('url') || '').trim();
    const combined = [text, url && !text.includes(url) ? url : ''].filter(Boolean).join('\n');
    if (!combined || combined.includes('\0') || title.includes('\0')) throw new ShareError(400, 'Share a link or paste it in Handy Save.');
    if (new TextEncoder().encode(combined).length > MAX_TEXT || title.length > 8192) throw new ShareError(413, 'Shared text exceeds the allowed size.');
    return { text: combined, title: title || null };
  }
  function queueShare(share) {
    return new Promise((resolve, reject) => {
      const open = indexedDB.open('handy-save-incoming', 1);
      open.onupgradeneeded = () => { if (!open.result.objectStoreNames.contains('shares')) open.result.createObjectStore('shares', { keyPath: 'id' }); };
      let settled = false;
      const fail = () => { settled = true; reject(new ShareError(503, 'Incoming share could not be saved. Open Handy Save and paste the link.')); };
      open.onerror = fail; open.onblocked = fail;
      open.onsuccess = () => {
        const db = open.result;
        if (settled) { db.close(); return; }
        const tx = db.transaction('shares', 'readwrite'), store = tx.objectStore('shares');
        let failure;
        tx.oncomplete = () => { db.close(); resolve(); };
        tx.onabort = tx.onerror = () => { db.close(); reject(failure || new ShareError(503, 'Incoming share could not be saved. Open Handy Save and paste the link.')); };
        const count = store.count();
        count.onsuccess = () => {
          if (count.result >= MAX_QUEUE) { failure = new ShareError(503, 'Incoming share inbox is full. Open Handy Save before sharing more links.'); tx.abort(); return; }
          const id = crypto.randomUUID ? crypto.randomUUID() : Array.from(crypto.getRandomValues(new Uint8Array(16)), b => b.toString(16).padStart(2, '0')).join('');
          store.add({ id, ...share, receivedAt: new Date().toISOString() });
        };
      };
    });
  }
  async function receive(request) {
    try {
      await queueShare(await readShare(request));
      try { for (const client of await self.clients.matchAll({ type: 'window', includeUncontrolled: true })) client.postMessage({ type: 'handy-save-share' }); } catch { /* Durable inbox is also drained at startup. */ }
      return Response.redirect(new URL('?shared=1', self.registration.scope).href, 303);
    } catch (error) {
      return new Response(error instanceof ShareError ? error.message : 'Incoming share could not be saved. Open Handy Save and paste the link.', { status: error instanceof ShareError ? error.status : 503, headers: { 'content-type': 'text/plain; charset=utf-8', 'cache-control': 'no-store' } });
    }
  }
  self.addEventListener('fetch', event => {
    if (event.request.method !== 'POST') return;
    const url = new URL(event.request.url), target = new URL('share-target', self.registration.scope);
    if (url.origin !== target.origin || url.pathname !== target.pathname || url.search) return;
    event.respondWith(receive(event.request));
  });
})();
