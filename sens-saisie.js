// SAISIE DE GAUCHE À DROITE PARTOUT, SAUF EN ARABE (Fred, 24/11/2026, mission « Purge », point B.6).
// Constat après la fusion de #1184 (qui ne réglait que les deux champs de création de parti) : une vingtaine de champs
// portent dir="auto" (organisations, forum, élections, énigmes…), et l'éditeur du forum hérite du sens de la page. Avec
// dir="auto", le navigateur choisit le sens d'après le premier caractère tapé : un message qui commence par un chiffre,
// un emoji ou un mot arabe cité part de droite à gauche.
// Règle unique ici : tout champ de saisie (input texte, textarea, zone éditable du forum) prend le sens de la LANGUE
// choisie — de droite à gauche en arabe, de gauche à droite dans toutes les autres — jamais celui de son contenu.
// Présentation seulement : aucun texte n'est modifié. Un champ peut s'exclure avec data-sens-libre.
(function (global) {
  'use strict';
  const doc = global.document;
  if (!doc) return;
  const CHAMPS = 'input:not([type]),input[type="text"],input[type="search"],input[type="email"],input[type="url"],input[type="tel"],'
    + 'input[type="password"],input[type="number"],textarea,[contenteditable=""],[contenteditable="true"]';
  function langue() {
    try {
      return (global.RPPlateauI18n && global.RPPlateauI18n.language && global.RPPlateauI18n.language())
        || (global.i18next && global.i18next.language) || 'fr';
    } catch (_) { return 'fr'; }
  }
  function sensSaisie() { return String(langue() || 'fr').slice(0, 2) === 'ar' ? 'rtl' : 'ltr'; }
  function appliquer(racine) {
    if (!racine || racine.nodeType !== 1) return;
    const sens = sensSaisie();
    const champs = racine.matches && racine.matches(CHAMPS) ? [racine] : [];
    if (racine.querySelectorAll) champs.push(...racine.querySelectorAll(CHAMPS));
    for (const champ of champs) {
      if (champ.hasAttribute('data-sens-libre')) continue;
      if (champ.getAttribute('dir') !== sens) champ.setAttribute('dir', sens);
    }
  }
  function toutAppliquer() { appliquer(doc.body); }
  global.rpSensSaisie = sensSaisie;
  global.rpAppliquerSensSaisie = toutAppliquer;
  (global.RP_I18N_CHANGE_CALLBACKS = global.RP_I18N_CHANGE_CALLBACKS || []).push(toutAppliquer);
  function demarrer() {
    toutAppliquer();
    if (global.i18next && typeof global.i18next.on === 'function') global.i18next.on('languageChanged', toutAppliquer);
    if (!global.MutationObserver) return;
    // Champs ajoutés par les fenêtres, et champs dont un autre code remet dir="auto" ou rend une zone éditable.
    new global.MutationObserver(mutations => {
      for (const m of mutations) {
        if (m.type === 'childList') m.addedNodes.forEach(appliquer);
        else appliquer(m.target);
      }
    }).observe(doc.body, { childList: true, subtree: true, attributes: true, attributeFilter: ['dir', 'contenteditable', 'type'] });
  }
  if (doc.readyState === 'loading') doc.addEventListener('DOMContentLoaded', demarrer, { once: true });
  else demarrer();
})(typeof window !== 'undefined' ? window : this);
