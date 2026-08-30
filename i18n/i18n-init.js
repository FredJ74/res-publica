// =====================
// RES PUBLICA — SOCLE I18N (LOT 1)
// i18next core vendorise localement (i18n/i18next.min.js, build UMD officiel v26.4.0, licence
// MIT -- telecharge et verifie depuis le registre npm officiel, voir i18n/i18next.LICENSE.txt).
// Aucune dependance CDN en production pour cette brique, aucun backend HTTP i18next (ressources
// embarquees dans i18n/resources.js), aucun plugin de detection de langue : la priorite de
// detection (localStorage > langue navigateur > francais) est ecrite ici a la main, quelques
// lignes suffisant au besoin decrit -- pas de dependance i18next-browser-languagedetector
// supplementaire pour ca.
//
// Reutilisable tel quel sur d'autres pages plus tard : appliquerTraductionsRP() et
// changerLangueRP() ne dependent d'aucun element specifique a la page d'accueil.
// =====================

const RP_I18N_STORAGE_KEY = 'respublica_language';
const RP_I18N_LANGUES_SUPPORTEES = ['fr', 'en'];
const RP_I18N_LANGUE_DEFAUT = 'fr';

// Priorite de detection initiale : preference explicitement enregistree > langue du navigateur
// (uniquement son prefixe 'fr'/'en', jamais l'IP ni le pays reel, jamais l'empire choisi dans le
// jeu) > francais. localStorage peut etre indisponible (navigation privee stricte de certains
// navigateurs) -- repli silencieux sur la detection navigateur dans ce cas.
function detecterLangueInitialeRP() {
  try {
    const stockee = localStorage.getItem(RP_I18N_STORAGE_KEY);
    if (stockee && RP_I18N_LANGUES_SUPPORTEES.includes(stockee)) return stockee;
  } catch (e) { /* localStorage indisponible -- on continue sur la detection navigateur */ }

  const langueNavigateur = ((navigator.language || navigator.userLanguage || '') + '').toLowerCase();
  if (langueNavigateur.indexOf('fr') === 0) return 'fr';
  if (langueNavigateur.indexOf('en') === 0) return 'en';
  return RP_I18N_LANGUE_DEFAUT;
}

// Applique les traductions a tous les elements marques -- convention legere et generique
// (section 10 du lot) : data-i18n pour le contenu texte, data-i18n-placeholder pour l'attribut
// placeholder des champs de saisie. Une seule fonction, pas de framework maison.
function appliquerTraductionsRP() {
  document.querySelectorAll('[data-i18n]').forEach(function (el) {
    el.textContent = i18next.t(el.getAttribute('data-i18n'));
  });
  document.querySelectorAll('[data-i18n-placeholder]').forEach(function (el) {
    el.setAttribute('placeholder', i18next.t(el.getAttribute('data-i18n-placeholder')));
  });
  document.documentElement.lang = i18next.language;
  document.title = 'Res Publica — ' + i18next.t('home.subtitle');

  const boutonFr = document.getElementById('lang-btn-fr');
  const boutonEn = document.getElementById('lang-btn-en');
  if (boutonFr && boutonEn) {
    boutonFr.classList.toggle('lang-actif', i18next.language === 'fr');
    boutonEn.classList.toggle('lang-actif', i18next.language === 'en');
  }
}

// Changement manuel de langue (section 11) : met a jour i18next, reapplique les traductions,
// enregistre la preference, met a jour visuellement le selecteur -- reutilisable sur d'autres
// pages plus tard sans modification.
function changerLangueRP(langue) {
  if (RP_I18N_LANGUES_SUPPORTEES.indexOf(langue) === -1) return;
  i18next.changeLanguage(langue, function () {
    appliquerTraductionsRP();
    try { localStorage.setItem(RP_I18N_STORAGE_KEY, langue); }
    catch (e) { console.warn('Preference de langue non sauvegardee (localStorage indisponible)', e); }
  });
}

i18next.init({
  lng: detecterLangueInitialeRP(),
  fallbackLng: RP_I18N_LANGUE_DEFAUT,
  supportedLngs: RP_I18N_LANGUES_SUPPORTEES,
  resources: window.RP_I18N_RESOURCES,
  interpolation: { escapeValue: false }
}, function (err) {
  if (err) { console.error('i18next : erreur d\'initialisation', err); return; }
  appliquerTraductionsRP();
});
