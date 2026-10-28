// Segédfüggvények a Dart kódnak (lib/push_web.dart): telepítettség, push engedély és FCM token.
(function () {
  const config = {
    apiKey: 'AIzaSyDl_vaVNBglOVGTRE_lsDHug96BsAkc_ss',
    appId: '1:738529451537:web:407a509ffc04f5c2129bb0',
    messagingSenderId: '738529451537',
    projectId: 'lifest-c95f3',
  };
  const sdk = 'https://www.gstatic.com/firebasejs/10.14.1/';

  function load(src) {
    return new Promise((resolve, reject) => {
      const s = document.createElement('script');
      s.src = src;
      s.onload = resolve;
      s.onerror = () => reject(new Error('Nem sikerült betölteni: ' + src));
      document.head.appendChild(s);
    });
  }

  async function registration() {
    return (await navigator.serviceWorker.getRegistration('./')) || navigator.serviceWorker.register('sw.js');
  }

  window.eletrendPush = {
    /** Tud-e ez a böngésző push értesítést (iPhone-on csak a kezdőképernyőre tett app). */
    supported() {
      return 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window;
    },
    /** 'granted', 'denied', 'default' vagy 'unsupported'. */
    permission() {
      return 'Notification' in window ? Notification.permission : 'unsupported';
    },
    /** A kezdőképernyőről, saját ablakban fut-e. */
    standalone() {
      return window.matchMedia('(display-mode: standalone)').matches || navigator.standalone === true;
    },
    ios() {
      return /iPhone|iPad|iPod/.test(navigator.userAgent) ||
        (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
    },
    /**
     * Engedélyt kér (ha [ask]), és visszaadja az FCM tokent, vagy null-t.
     * Az engedélykérés legyen az első lépés: a Safari csak közvetlenül koppintásra engedi.
     */
    async token(vapidKey, ask) {
      const permission = ask ? await Notification.requestPermission() : Notification.permission;
      if (permission !== 'granted') return null;
      if (!window.firebase || !firebase.messaging) {
        await load(sdk + 'firebase-app-compat.js');
        await load(sdk + 'firebase-messaging-compat.js');
      }
      const app = firebase.apps.find((a) => a.name === 'push') || firebase.initializeApp(config, 'push');
      return app.messaging().getToken({ vapidKey, serviceWorkerRegistration: await registration() });
    },
  };

  // Offline működés: a service worker már az első betöltéskor települ.
  if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => registration().catch((e) => console.warn('Service worker:', e)));
  }
})();
