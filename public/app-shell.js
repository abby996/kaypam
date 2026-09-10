/* ============================================================
   KayPam — App Shell (PWA)
   Jere: Service Worker + Bannière enstalasyon
   ============================================================ */

(() => {

  /* ===== TRADUCTIONS BANNIÈRE ===== */
  const pwaTranslations = {
    fr: {
      install_banner: "Installez KayPam sur votre téléphone !",
      install_manual: "Pour installer KayPam :\n\n• Android : Menu Chrome → \"Ajouter à l'écran d'accueil\"\n• iPhone : Bouton Partager → \"Sur l'écran d'accueil\""
    },
    en: {
      install_banner: "Install KayPam on your phone!",
      install_manual: "To install KayPam:\n\n• Android: Chrome menu → \"Add to Home screen\"\n• iPhone: Share button → \"Add to Home Screen\""
    },
    ht: {
      install_banner: "Enstale KayPam sou telefòn ou!",
      install_manual: "Pou enstale KayPam:\n\n• Android : Menu Chrome → \"Ajouter à l'écran d'accueil\"\n• iPhone : Bouton Partager → \"Sur l'écran d'accueil\""
    }
  };

  function getPwaText(key) {
    const lang = localStorage.getItem('kaypam_lang') || 'fr';
    return (pwaTranslations[lang] && pwaTranslations[lang][key])
      || (pwaTranslations.fr && pwaTranslations.fr[key])
      || key;
  }

  /* ===== SERVICE WORKER ===== */
  if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
      navigator.serviceWorker.register('/service-worker.js')
        .then(() => console.log('✅ Service Worker enregistré'))
        .catch(error => console.error('❌ Service Worker erreur:', error));
    });
  }

  /* ===== SI DÉJÀ INSTALLÉ, NE RIEN FAIRE ===== */
  if (window.matchMedia('(display-mode: standalone)').matches
      || window.navigator.standalone === true
      || localStorage.getItem('kaypam_installed') === 'true') {
    console.log('✅ KayPam déjà installé');
    return;
  }

  /* ===== SI BANNIÈRE DÉJÀ FERMÉE RÉCEMMENT (7 JOURS) ===== */
  const dismissed = localStorage.getItem('kaypam_install_dismissed');
  if (dismissed) {
    const daysSince = (Date.now() - parseInt(dismissed)) / (1000 * 60 * 60 * 24);
    if (daysSince < 7) {
      console.log('⏸️ Bannière fermée récemment — pas d\'affichage');
      return;
    }
  }

  /* ===== CRÉER LA BANNIÈRE (sèlman) ===== */
  let deferredPrompt = null;
  const banner = document.createElement('div');
  banner.id = 'install-banner';
  banner.style.cssText = `
    display:none;
    background:#16243B;
    color:#fff;
    padding:14px 20px;
    text-align:center;
    position:fixed;
    bottom:0;
    left:0;
    right:0;
    z-index:999;
    box-shadow:0 -4px 20px rgba(0,0,0,0.3);
    cursor:pointer;
    font-family:-apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    font-size:14px;
    font-weight:600;
    padding-bottom:calc(14px + env(safe-area-inset-bottom, 0px));
    animation:slideUpBanner .4s ease;
  `;

  /* Animasyon */
  const style = document.createElement('style');
  style.textContent = `
    @keyframes slideUpBanner {
      from { transform: translateY(100%); }
      to { transform: translateY(0); }
    }
  `;
  document.head.appendChild(style);

  banner.innerHTML = `
    <div style="display:flex;align-items:center;justify-content:center;gap:10px;">
      <span style="font-size:20px;">📱</span>
      <span id="install-banner-text">${getPwaText('install_banner')}</span>
    </div>
  `;

  /* ===== KLIK SOU BANNIÈRE A ===== */
  banner.addEventListener('click', () => {
    if (deferredPrompt) {
      // Montre dyalòg enstalasyon an
      deferredPrompt.prompt();
      deferredPrompt.userChoice.then((choiceResult) => {
        console.log('✅ Choix utilisateur:', choiceResult.outcome);
        deferredPrompt = null;
        banner.style.display = 'none';
      });
    } else {
      // Pa gen prompt (iPhone) → montre enstriksyon yo
      alert(getPwaText('install_manual'));
    }
  });

  document.body.appendChild(banner);

  /* ===== DÉTECTER beforeinstallprompt ===== */
  window.addEventListener('beforeinstallprompt', (event) => {
    event.preventDefault();
    deferredPrompt = event;
    const bannerText = document.getElementById('install-banner-text');
    if (bannerText) {
      bannerText.textContent = getPwaText('install_banner');
    }
    banner.style.display = 'block';
    console.log('✅ Bannière d\'installation affichée');
  });

  /* ===== DÉTECTER appinstalled ===== */
  window.addEventListener('appinstalled', () => {
    console.log('✅ KayPam installé!');
    banner.style.display = 'none';
    localStorage.setItem('kaypam_installed', 'true');
  });

  /* ===== SUR iOS, MONTRER LA BANNIÈRE APRÈS 3 SECONDES ===== */
  const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent) && !window.MSStream;
  if (isIOS) {
    setTimeout(() => {
      const bannerText = document.getElementById('install-banner-text');
      if (bannerText) {
        bannerText.textContent = getPwaText('install_banner');
      }
      banner.style.display = 'block';
      console.log('✅ Bannière iOS affichée');
    }, 3000);
  }

})();