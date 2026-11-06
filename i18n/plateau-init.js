/* Internationalisation statique du plateau : moteur i18next existant, pas de moteur concurrent.
 * Pilote du bandeau principal, sans modifier les ordres et messages serveur.
 */
(function (global) {
  'use strict';
  const engine=global.i18next, config=global.RP_I18N_RESOURCES;
  if(!engine || !config) return;
  const supported=Object.keys(global.RP_I18N_LANGUAGES||{fr:{}});
  let locale='fr';
  try { const saved=global.localStorage?.getItem('respublica_language'); if(supported.includes(saved))locale=saved; }
  catch (_) { /* navigateur sans localStorage */ }
  // Point d'entrée générique pour les futures interfaces créées par JavaScript.
  // Le rendu initial s'en sert aussi : les écrans n'instancient pas un 2e moteur.
  function apply(root) {
    const elementRoot=root||global.document;
    const nodes=Array.from(elementRoot.querySelectorAll?.('[data-i18n]')||[]);
    if(elementRoot.getAttribute?.('data-i18n')) nodes.unshift(elementRoot);
    for(const element of nodes) {
      const key=element.getAttribute('data-i18n');
      // Une clé encore absente du catalogue ne doit jamais devenir un libellé
      // technique affiché au joueur : conserver le français existant.
      if(!key) continue;
      const translated=engine.t(key,{defaultValue:null});
      if(typeof translated!=='string' || !translated.trim() || translated===key) continue;
      element.textContent=element.hasAttribute('data-i18n-uppercase')
        ? translated.toLocaleUpperCase(locale) : translated;
      if(locale==='ar') element.setAttribute('dir','rtl');
      else element.removeAttribute?.('dir');
    }
    // Les info-bulles de la barre supérieure doivent être traduites sans
    // remplacer le contenu des boutons (icônes, badges, compteurs).
    const titleNodes=Array.from(elementRoot.querySelectorAll?.('[data-i18n-title]')||[]);
    if(elementRoot.getAttribute?.('data-i18n-title')) titleNodes.unshift(elementRoot);
    for(const element of titleNodes) {
      const key=element.getAttribute('data-i18n-title');
      if(!key) continue;
      const translated=engine.t(key);
      if(typeof translated==='string' && translated.trim() && translated!==key) {
        element.setAttribute('title',translated);
      }
    }
  }
  global.RPI18nPlateau=Object.freeze({apply,locale:()=>locale});
  engine.init({
    lng:locale,
    fallbackLng:'fr',
    supportedLngs:supported,
    resources:config,
    interpolation:{escapeValue:false}
  }, function(error) {
    if(error) { console.error('i18n plateau : initialisation impossible',error); return; }
    global.document.documentElement.lang=locale;
    apply(global.document);
  });
})(window);
