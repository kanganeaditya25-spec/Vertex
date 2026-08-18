const CACHE_NAME = 'productivity-dashboard-v2';
const ASSET_VERSION = '?v=20260818-2';
const ASSETS_TO_CACHE = [
  '/',
  '/index.html',
  `/css/style.css${ASSET_VERSION}`,
  `/js/api.js${ASSET_VERSION}`,
  `/js/app.js${ASSET_VERSION}`,
  `/js/pages/login.js${ASSET_VERSION}`,
  `/js/pages/dashboard.js${ASSET_VERSION}`,
  `/js/pages/tasks.js${ASSET_VERSION}`,
  `/js/pages/library.js${ASSET_VERSION}`,
  `/js/pages/reports.js${ASSET_VERSION}`,
  `/js/pages/settings.js${ASSET_VERSION}`,
  '/manifest.json'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      console.log('[Service Worker] Caching App Shell v2');
      return cache.addAll(ASSETS_TO_CACHE);
    }).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => Promise.all(
      keys.filter(key => key !== CACHE_NAME).map(key => caches.delete(key))
    )).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET' || event.request.url.includes('/api/')) return;

  // Network-first keeps online users current while retaining offline support.
  event.respondWith(
    fetch(event.request).then((response) => {
      const copy = response.clone();
      caches.open(CACHE_NAME).then(cache => cache.put(event.request, copy));
      return response;
    }).catch(() => caches.match(event.request).then((cachedResponse) => {
      if (cachedResponse) return cachedResponse;
      if (event.request.mode === 'navigate') return caches.match('/index.html');
      return Response.error();
    }))
  );
});

self.addEventListener('push', (event) => {
  let data = { title: 'Notification', body: 'Something happened!' };
  try {
    data = event.data.json();
  } catch (e) {
    if (event.data) data = { title: 'Productivity Notification', body: event.data.text() };
  }

  const options = {
    body: data.body,
    icon: 'data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><rect width="100" height="100" rx="20" fill="%236c7ae0"/><text x="50" y="65" font-size="50" fill="white" text-anchor="middle">⚡</text></svg>',
    badge: 'data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><text y=".9em" font-size="90">⚡</text></svg>',
    data: { url: data.url || '/' },
    tag: data.tag || 'general-notification',
    renotify: true
  };

  event.waitUntil(self.registration.showNotification(data.title, options));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const clickActionUrl = event.notification.data.url;

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
      for (const client of windowClients) {
        if (client.url.includes(self.location.origin) && 'focus' in client) {
          return client.focus().then(() => client.navigate ? client.navigate(clickActionUrl) : undefined);
        }
      }
      if (clients.openWindow) return clients.openWindow(clickActionUrl);
    })
  );
});
