{{flutter_js}}
{{flutter_build_config}}
// Japanese, Chinese and Korean cards: the bundled fonts are Latin and
// Vietnamese only, so the first time such a glyph shows, the engine fetches a
// Noto slice for it from fonts.gstatic.com (online once). Keep each slice in
// this app's own cache so it renders offline from then on. Nothing else is
// fetched, and the asset service worker never deletes this cache.
(() => {
  const FONT_ORIGIN = 'https://fonts.gstatic.com/';
  const FONT_CACHE = 'handy_recall-fonts-v1';
  if (!('caches' in window)) return;
  const network = window.fetch.bind(window);
  window.fetch = async (input, init) => {
    const url = typeof input === 'string' ? input : input && input.url;
    if (typeof url !== 'string' || !url.startsWith(FONT_ORIGIN)) return network(input, init);
    let cache = null;
    try {
      cache = await caches.open(FONT_CACHE);
      const hit = await cache.match(url);
      if (hit) return hit;
    } catch (_) {
      cache = null;
    }
    const response = await network(input, init);
    if (cache && response.ok) cache.put(url, response.clone()).catch(() => {});
    return response;
  };
})();
_flutter.loader.load();
if ('serviceWorker' in navigator) {
  window.addEventListener('load', async () => {
    try {
      const registration = await navigator.serviceWorker.register('handy_recall_service_worker.js');
      const offerUpdate = () => {
        if (!registration.waiting || !navigator.serviceWorker.controller || document.getElementById('handy-app-update')) return;
        const button = document.createElement('button');
        button.id = 'handy-app-update';
        button.textContent = 'Update available / Có bản cập nhật';
        button.style.cssText = 'position:fixed;bottom:16px;right:16px;z-index:99999;padding:16px;border-radius:12px;background:#7C3AED;color:#fff';
        button.onclick = () => {
          if (confirm('Reload after saving your work? / Tải lại sau khi đã lưu công việc?')) {
            navigator.serviceWorker.addEventListener('controllerchange', () => location.reload(), {once:true});
            registration.waiting.postMessage({type:'activate-update'});
          }
        };
        document.body.appendChild(button);
      };
      offerUpdate();
      registration.addEventListener('updatefound', () => registration.installing?.addEventListener('statechange', offerUpdate));
    } catch (error) {
      console.warn('Offline asset cache unavailable. Export a backup before leaving this page.', error.name);
    }
  });
}
