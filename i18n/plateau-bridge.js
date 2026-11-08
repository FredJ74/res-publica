/* Pont de localisation du plateau (catalogue central). Le moteur reste i18next. */
(function (global) {
  'use strict';
  // Les neuf langues viennent du même catalogue que l'accueil.
  const LANGS = Object.freeze(Object.keys(global.RP_I18N_LANGUAGES || {fr:1}));
  function resolve(code) {
    if(typeof code!=='string' || !code.trim())return null;
    const parts=code.toLowerCase().split('-');
    const exact=LANGS.find(lang=>lang.toLowerCase()===parts.join('-'));
    if(exact)return exact;
    return LANGS.find(lang=>{
      const wanted=lang.toLowerCase().split('-');
      if(wanted[0]!==parts[0])return false;
      // Les langues simples acceptent leur région (es-MX, pt-PT ? non :
      // pt-BR est une langue régionale et exige explicitement BR).
      if(wanted.length===1)return true;
      return parts.length>1 && wanted[wanted.length-1]===parts[parts.length-1];
    }) || null;
  }
  function language() {
    // Le moteur est la source unique APRÈS initialisation : changer de langue
    // dans la session ne doit pas laisser menus et dialogues en désaccord.
    const active=global.i18next?.language;
    if(typeof active==='string' && active.trim())return resolve(active) || 'fr';
    // La préférence enregistrée et le navigateur ne servent qu'au premier accès.
    try {
      const saved=global.localStorage?.getItem('respublica_language');
      // Comme sur l'accueil, une préférence persistée doit être exacte.
      if(LANGS.includes(saved))return saved;
    } catch (_) { /* stockage indisponible */ }
    // Une seule préférence navigateur, comme i18n-init.js sur l'accueil :
    // les deux pages doivent choisir la même langue au premier accès.
    const navigator=global.navigator || {};
    return resolve(navigator.language || navigator.userLanguage || '') || 'fr';
  }
  function translate(key, vars={}) {
    if(typeof key!=='string' || !/^[\w.-]+$/.test(key)) return '';
    return typeof global.i18next?.t==='function' ? global.i18next.t(key,{...vars,lng:language()}) : key;
  }
  function message(original, translated, locale) {
    const originalText=String(original??'');
    const usable=typeof translated==='string' && LANGS.includes(locale) && locale===language();
    return Object.freeze({ original:originalText, displayed:usable?translated:originalText, isTranslated:usable });
  }
  function number(value) { return Number.isFinite(value)?new Intl.NumberFormat(language(),{maximumFractionDigits:0}).format(value):''; }
  global.RPPlateauI18n=Object.freeze({LANGS,resolve,language,translate,message,number});
})(window);
