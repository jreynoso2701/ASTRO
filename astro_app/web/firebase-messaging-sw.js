// Service Worker para Firebase Cloud Messaging (web push notifications)
importScripts('https://www.gstatic.com/firebasejs/11.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/11.7.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyDqgZbN2xeq3NrBNZBmv-hCtPq5DlBt2fg',
  appId: '1:124307506572:web:3b4676d9273caab0cc42a9',
  messagingSenderId: '124307506572',
  projectId: 'astro-b97c2',
  authDomain: 'astro-b97c2.firebaseapp.com',
  storageBucket: 'astro-b97c2.appspot.com',
  measurementId: 'G-5K6RCG9B88',
});

const messaging = firebase.messaging();

// Background message handler — muestra notificación nativa del navegador.
messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title ?? 'ASTRO';
  const options = {
    body: payload.notification?.body ?? '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
  };
  return self.registration.showNotification(title, options);
});
