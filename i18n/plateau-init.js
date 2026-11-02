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
  engine.init({
    lng:locale,
    fallbackLng:'fr',
    supportedLngs:supported,
    resources:config,
    interpolation:{escapeValue:false}
  }, function(error) {
    if(error) { console.error('i18n plateau : initialisation impossible',error); return; }
    global.document.documentElement.lang=locale;
    global.document.querySelectorAll('[data-i18n]').forEach(function(element){
      const key=element.getAttribute('data-i18n');
      const translated=engine.t(key);
      element.textContent=element.hasAttribute('data-i18n-uppercase')
        ? translated.toLocaleUpperCase(locale) : translated;
      if(locale==='ar') element.setAttribute('dir','rtl');
    });
  });
})(window);
