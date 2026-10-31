// A LIFEUP service workere: offline működés (gyorsítótár) és push értesítések fogadása.
//
// Gyorsítótár: „előbb a hálózat”. Interneten mindig a friss változat jön, közben eltesszük;
// internet nélkül az eltett változatból indul az app. Így frissítés után sem ragad be régi verzió.

const CACHE = 'lifeup-v2';

// Csak az app saját fájljait és a futtatáshoz kellő Google-fájlokat (CanvasKit, Firebase, betűk) tesszük el.
// A Firestore és a bejelentkezés kérései sosem kerülnek a gyorsítótárba.
const CACHEABLE_HOSTS = ['www.gstatic.com', 'fonts.gstatic.com', 'fonts.googleapis.com'];

self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(caches.open(CACHE).then((c) => c.addAll(['./', './index.html', './manifest.json'])).catch(() => {}));
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      // A Flutter régi, elavult service workerének gyorsítótárait eltakarítjuk.
      for (const key of await caches.keys()) {
        if (key !== CACHE) await caches.delete(key);
      }
      await self.clients.claim();
    })(),
  );
});

function cacheable(request) {
  if (request.method !== 'GET') return false;
  const url = new URL(request.url);
  if (url.origin === self.location.origin) return true;
  return CACHEABLE_HOSTS.includes(url.hostname);
}

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (!cacheable(request)) return;
  event.respondWith(
    (async () => {
      try {
        const response = await fetch(request);
        if (response.ok && (response.type === 'basic' || response.type === 'cors')) {
          const copy = response.clone();
          caches.open(CACHE).then((c) => c.put(request, copy));
        }
        return response;
      } catch (e) {
        const cached = await caches.match(request, { ignoreSearch: request.mode === 'navigate' });
        if (cached) return cached;
        if (request.mode === 'navigate') {
          const index = await caches.match('./index.html');
          if (index) return index;
        }
        throw e;
      }
    })(),
  );
});

// Push értesítések (Firebase Cloud Messaging). A szerver (Cloud Function) `webpush.notification`-nel
// küldi, ezt a Firebase könyvtár magától megjeleníti; koppintásra a `fcmOptions.link` nyílik meg.
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyDl_vaVNBglOVGTRE_lsDHug96BsAkc_ss',
  appId: '1:738529451537:web:407a509ffc04f5c2129bb0',
  messagingSenderId: '738529451537',
  projectId: 'lifest-c95f3',
  authDomain: 'lifest-c95f3.firebaseapp.com',
  storageBucket: 'lifest-c95f3.firebasestorage.app',
});
firebase.messaging();
