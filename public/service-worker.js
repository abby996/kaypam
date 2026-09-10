/* ============================================================
   KayPam — Service Worker (PWA)
   ============================================================ */

const CACHE_NAME = 'kaypam-v1';
const OFFLINE_URL = '/offline.html';

/* Fichye ki dwe kache pou fonksyone ofline */
const ASSETS_TO_CACHE = [
  '/',
  '/index.html',
  '/publier.html',
  '/mes-annonces.html',
  '/offline.html',
  '/manifest.json',
  '/icons/167.png',
  '/icons/180.png',
  '/icons/launchericon-192x192.png',
  '/icons/launchericon-512x512.png',
  '/icons/Square150x150Logo.scale-200.png'
];

/* ===== INSTALLATION ===== */
self.addEventListener('install', (event) => {
  console.log('📦 Service Worker: Installation...');
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => {
        console.log('📦 Service Worker: Mise en cache des fichiers');
        return cache.addAll(ASSETS_TO_CACHE);
      })
      .then(() => {
        console.log('✅ Service Worker: Installation réussie');
        return self.skipWaiting();
      })
      .catch((error) => {
        console.error('❌ Service Worker: Erreur installation', error);
      })
  );
});

/* ===== ACTIVATION ===== */
self.addEventListener('activate', (event) => {
  console.log('🚀 Service Worker: Activation...');
  event.waitUntil(
    caches.keys()
      .then((cacheNames) => {
        return Promise.all(
          cacheNames.map((cacheName) => {
            if (cacheName !== CACHE_NAME) {
              console.log('🗑️ Service Worker: Suppression ancien cache', cacheName);
              return caches.delete(cacheName);
            }
          })
        );
      })
      .then(() => {
        console.log('✅ Service Worker: Activé');
        return self.clients.claim();
      })
  );
});

/* ===== INTERCEPTION DES REQUÊTES ===== */
self.addEventListener('fetch', (event) => {
  const request = event.request;
  const url = new URL(request.url);
  
  // Pa entèsepte les requêtes Supabase ou API
  if (url.hostname.includes('supabase') || url.pathname.startsWith('/api/')) {
    return;
  }
  
  // Pa entèsepte les requêtes POST/PUT/DELETE
  if (request.method !== 'GET') {
    return;
  }
  
  // Strategie: Cache en premye, puis réseau
  event.respondWith(
    caches.match(request)
      .then((cachedResponse) => {
        if (cachedResponse) {
          // Fichye nan cache → retounen li
          return cachedResponse;
        }
        
        // Pa nan cache → chèche sou entènèt
        return fetch(request)
          .then((response) => {
            // Pa kache repons ki pa bon
            if (!response || response.status !== 200 || response.type !== 'basic') {
              return response;
            }
            
            // Kache yon kopi
            const responseToCache = response.clone();
            caches.open(CACHE_NAME)
              .then((cache) => {
                cache.put(request, responseToCache);
              });
            
            return response;
          })
          .catch(() => {
            // Si pa gen entènèt epi fichye pa nan cache
            if (request.mode === 'navigate') {
              return caches.match(OFFLINE_URL);
            }
            return new Response('Hors ligne', {
              status: 503,
              statusText: 'Service Unavailable',
              headers: new Headers({ 'Content-Type': 'text/plain' })
            });
          });
      })
  );
});

/* ===== MISE À JOUR ===== */
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});

console.log('✅ Service Worker KayPam chargé');