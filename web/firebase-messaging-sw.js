importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyCZe5z5nJO5-C1lgYOj8DgPofDSOgeISks",
  projectId: "rituals-b3bed",
  messagingSenderId: "637686614153",
  appId: "1:637686614153:web:e4b62d2860185740361e58",
});

const messaging = firebase.messaging();

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
    tag: data.groupId ?? 'rituals',   // collapse duplicate group notifications
  });
});

// Open/focus the app when a notification is tapped
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const groupId = event.notification.data?.groupId;
  const targetUrl = groupId
    ? self.location.origin + '/home/' + groupId
    : self.location.origin + '/';

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
      // Focus existing window if already open
      for (const client of windowClients) {
        if (client.url.startsWith(self.location.origin) && 'focus' in client) {
          client.postMessage({ type: 'NOTIFICATION_TAP', groupId });
          return client.focus();
        }
      }
      // Otherwise open a new window
      if (clients.openWindow) {
        return clients.openWindow(targetUrl);
      }
    })
  );
});
