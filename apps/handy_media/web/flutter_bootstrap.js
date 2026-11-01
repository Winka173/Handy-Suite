{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load();
if ('serviceWorker' in navigator) {
  window.addEventListener('load', async () => {
    try {
      const registration = await navigator.serviceWorker.register('handy_media_service_worker.js');
      const offerUpdate = () => {
        if (!registration.waiting || !navigator.serviceWorker.controller || document.getElementById('handy-app-update')) return;
        const button = document.createElement('button');
        button.id = 'handy-app-update';
        button.textContent = 'Update available / Có bản cập nhật';
        button.style.cssText = 'position:fixed;bottom:16px;right:16px;z-index:99999;padding:16px;border-radius:12px;background:#D97706;color:#fff';
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
