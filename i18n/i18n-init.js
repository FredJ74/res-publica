// =====================
// RES PUBLICA — SOCLE I18N (LOT 1 + LOT 2.5 : architecture N langues)
// i18next core vendorise localement (i18n/i18next.min.js, build UMD officiel v26.4.0, licence
// MIT -- telecharge et verifie depuis le registre npm officiel, voir i18n/i18next.LICENSE.txt).
// Aucune dependance CDN en production pour cette brique, aucun backend HTTP i18next (ressources
// embarquees dans i18n/resources.js), aucun plugin de detection de langue : la priorite de
// detection (localStorage > langue navigateur > francais) est ecrite ici a la main, quelques
// lignes suffisant au besoin decrit -- pas de dependance i18next-browser-languagedetector
// supplementaire pour ca.
//
// LOT 2.5 (passage de 2 a N langues, ajout de l'espagnol) : plus AUCUNE hypothese "deux langues"
// dans ce fichier -- la liste des langues supportees, la detection navigateur, le rendu du
// selecteur et la mise en evidence du bouton actif sont tous pilotes par
// window.RP_I18N_LANGUAGES (i18n/resources.js), jamais par une cascade if/else par langue.
// Ajouter une langue (ex. portugais demain) = ajouter son entree a RP_I18N_LANGUAGES + son arbre
// de traductions dans RP_I18N_RESOURCES -- aucune autre modification necessaire dans ce fichier
// ni dans index.html.
//
// Reutilisable tel quel sur d'autres pages plus tard : appliquerTraductionsRP() et
// changerLangueRP() ne dependent d'aucun element specifique a la page d'accueil.
// =====================

const RP_I18N_STORAGE_KEY = 'respublica_language';
// Derivee de la config centrale (i18n/resources.js) -- jamais une seconde liste maintenue a la
// main ici. Charge AVANT ce fichier (voir index.html), donc toujours disponible a ce stade.
const RP_I18N_LANGUES_SUPPORTEES = Object.keys(window.RP_I18N_LANGUAGES || { fr: 1 });
const RP_I18N_LANGUE_DEFAUT = 'fr'; // francais = langue source/canonique du projet, jamais derive de la config

// Priorite de detection initiale : preference explicitement enregistree > langue du navigateur
// (uniquement son sous-code primaire -- 'fr' de 'fr-CA', 'es' de 'es-MX'... -- jamais l'IP ni le
// pays reel, jamais l'empire choisi dans le jeu) > francais. Resolution GENERIQUE : le sous-code
// primaire est simplement compare a la liste des langues supportees, quel que soit leur nombre --
// aucune cascade if/else dediee a une langue precise. localStorage peut etre indisponible
// (navigation privee stricte de certains navigateurs) -- repli silencieux sur la detection
// navigateur dans ce cas ; une preference stockee mais devenue non supportee est ignoree proprement
// (le controle RP_I18N_LANGUES_SUPPORTEES.includes(...) l'exclut naturellement, sans cas special).
function detecterLangueInitialeRP() {
  try {
    const stockee = localStorage.getItem(RP_I18N_STORAGE_KEY);
    if (stockee && RP_I18N_LANGUES_SUPPORTEES.includes(stockee)) return stockee;
  } catch (e) { /* localStorage indisponible -- on continue sur la detection navigateur */ }

  const langueNavigateur = ((navigator.language || navigator.userLanguage || '') + '').toLowerCase();
  const sousCodePrimaire = langueNavigateur.split('-')[0]; // 'es-MX' -> 'es', 'fr-CA' -> 'fr', etc.
  if (RP_I18N_LANGUES_SUPPORTEES.includes(sousCodePrimaire)) return sousCodePrimaire;
  return RP_I18N_LANGUE_DEFAUT;
}

// Genere le contenu du selecteur de langue (#lang-switcher, index.html) a partir de la config
// centrale -- jamais de markup statique par langue a maintenir. Un bouton par langue supportee
// (autonyme, jamais traduit), separateurs "|" entre eux. Reste le meme composant simple
// (boutons + separateurs) qu'avant ce lot, seulement genere plutot qu'ecrit en dur -- pas de
// nouveau composant UI, pas de <select> introduit sans raison.
function genererSelecteurLangueRP() {
  const conteneur = document.getElementById('lang-switcher');
  if (!conteneur) return;
  conteneur.innerHTML = RP_I18N_LANGUES_SUPPORTEES.map(function (code, i) {
    const nom = (window.RP_I18N_LANGUAGES[code] && window.RP_I18N_LANGUAGES[code].nativeName) || code.toUpperCase();
    const separateur = i > 0 ? '<span class="lang-sep">|</span>' : '';
    return separateur + '<button id="lang-btn-' + code + '" onclick="changerLangueRP(\'' + code + '\')">' + nom + '</button>';
  }).join('');
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

  // Mise en evidence du bouton actif -- generique sur TOUTES les langues supportees, jamais deux
  // variables dediees fr/en : fonctionne a l'identique pour 2 langues ou pour 10.
  RP_I18N_LANGUES_SUPPORTEES.forEach(function (code) {
    const bouton = document.getElementById('lang-btn-' + code);
    if (bouton) bouton.classList.toggle('lang-actif', i18next.language === code);
  });
}

// Changement manuel de langue (section 11) : met a jour i18next, reapplique les traductions,
// enregistre la preference, met a jour visuellement le selecteur -- reutilisable sur d'autres
// pages plus tard sans modification.
//
// Hook de rafraichissement dynamique (Lot 2, i18n creation de personnage) : appliquerTraductionsRP()
// ne retraduit que le DOM STATIQUE (attributs data-i18n deja presents) -- elle ignore tout ce
// qu'une page genere dynamiquement en JS (ex. les grilles de creation.js). window.RP_I18N_ON_LANGUAGE_CHANGE
// est un point d'extension OPTIONNEL, jamais defini par ce fichier lui-meme (qui reste generique
// et reutilisable sur n'importe quelle page) : une page qui a du contenu dynamique a retraduire
// peut y assigner sa propre fonction de rafraichissement (voir creation.js,
// rafraichirEcranCreationApresChangementLangue) ; les pages qui n'en ont pas besoin n'ont rien a
// faire, l'appel est un simple no-op silencieux.
function changerLangueRP(langue) {
  if (RP_I18N_LANGUES_SUPPORTEES.indexOf(langue) === -1) return;
  i18next.changeLanguage(langue, function () {
    appliquerTraductionsRP();
    if (typeof window.RP_I18N_ON_LANGUAGE_CHANGE === 'function') window.RP_I18N_ON_LANGUAGE_CHANGE();
    try { localStorage.setItem(RP_I18N_STORAGE_KEY, langue); }
    catch (e) { console.warn('Preference de langue non sauvegardee (localStorage indisponible)', e); }
  });
}

genererSelecteurLangueRP();

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
