importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyCZe5z5nJO5-C1lgYOj8DgPofDSOgeISks",
  projectId: "rituals-b3bed",
  messagingSenderId: "637686614153",
  appId: "1:637686614153:web:e4b62d2860185740361e58",
});

const messaging = firebase.messaging();

const PHOTO_CACHE = 'ritual-photos-v1';

// Cache-first for Firebase Storage relay photos.
// Any relay photo the PWA loads is persisted locally so it survives Storage TTL.
self.addEventListener('fetch', (event) => {
  const url = event.request.url;
  if (
    url.includes('firebasestorage.googleapis.com') &&
    url.includes('/relay/')
  ) {
    event.respondWith(
      caches.open(PHOTO_CACHE).then(async (cache) => {
        // Serve from cache if available (survives Storage deletion)
        const cached = await cache.match(url);
        if (cached) return cached;

        // Not cached yet — fetch, cache, return
        try {
          const response = await fetch(event.request);
          if (response.ok) {
            cache.put(url, response.clone());
          }
          return response;
        } catch {
          return new Response('', { status: 503 });
        }
      })
    );
  }
});

// Show notification for background messages
messaging.onBackgroundMessage((message) => {
  console.log('[SW] Background message:', message);
  const notification = message.notification ?? {};
  const data = message.data ?? {};

  self.registration.showNotification(notification.title ?? 'New photo!', {
    body: notification.body ?? 'Someone shared a photo',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: data,
    tag: data.groupId ?? 'rituals',
  });
});

// Open/focus the app when a notification is tapped
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const { groupId, ritualId } = event.notification.data ?? {};
  const targetUrl = groupId
    ? self.location.origin + '/home/' + groupId
    : self.location.origin + '/';

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
      for (const client of windowClients) {
        if (client.url.startsWith(self.location.origin) && 'focus' in client) {
          client.postMessage({ type: 'NOTIFICATION_TAP', groupId, ritualId });
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(targetUrl);
      }
    })
  );
});
