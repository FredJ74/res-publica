/* Pont de localisation du plateau, non encore chargé. Le moteur reste i18next. */
(function (global) {
  'use strict';
  const LANGS = Object.freeze(['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de']);
  function language() {
    try { const value=global.localStorage?.getItem('respublica_language'); return LANGS.includes(value) ? value : 'fr'; }
    catch (_) { return 'fr'; }
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
  global.RPPlateauI18n=Object.freeze({LANGS,language,translate,message,number});
})(window);
