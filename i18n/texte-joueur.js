/* Affichage des textes écrits par les joueurs.
 * La traduction arrive d'un service séparé ; ce module n'invente ni traduction,
 * ni frais, ni sauvegarde. L'original n'est jamais modifié.
 */
(function(global){
 'use strict';
 function normalizeLanguage(value) {
  const tags=Object.keys(global.RP_I18N_LANGUAGES||{fr:{}});
  return tags.includes(value)?value:null;
 }
 function view(record,readerLocale,showOriginal=false) {
  const original=String(record?.original??'');
  const sourceLanguage=normalizeLanguage(record?.originalLanguage);
  const locale=normalizeLanguage(readerLocale)||'fr';
  const translated=typeof record?.translation==='string'?record.translation:null;
  const target=normalizeLanguage(record?.translationLanguage);
  const hasTranslation=translated!==null && target===locale && locale!==sourceLanguage;
  return Object.freeze({
   text:showOriginal||!hasTranslation?original:translated,
   original,
   shownLanguage:showOriginal||!hasTranslation?sourceLanguage:locale,
   showOriginalAvailable:hasTranslation,
   translated:hasTranslation&&!showOriginal
  });
 }
 function renderText(element,record,locale,showOriginal=false) {
  if(!element || !('textContent' in element)) return false;
  element.textContent=view(record,locale,showOriginal).text;
  return true;
 }
 global.RPPlayerText=Object.freeze({view,renderText});
})(window);
