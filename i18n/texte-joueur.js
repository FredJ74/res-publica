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
  // Une réponse vide ou uniquement composée d'espaces ne peut jamais masquer
  // l'original : conserver le contenu du joueur comme repli permanent.
  const hasTranslation=translated!==null && translated.trim().length>0 &&
   target===locale && locale!==sourceLanguage;
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
  const result=view(record,locale,showOriginal);
  element.textContent=result.text;
  // La direction ne concerne que le contenu du joueur : les boutons et la
  // disposition du plateau restent inchangés. L'original rétablit son sens.
  element.setAttribute?.('dir',result.shownLanguage==='ar'?'rtl':'auto');
   // Attribut lang réservé au texte réellement affiché (traduction ou original).
   if(result.shownLanguage) element.setAttribute?.('lang',result.shownLanguage);
   else element.removeAttribute?.('lang');
  return true;
 }
 function attachToggle(element,button,record,locale,labels) {
  if(!element || !button || typeof button.addEventListener!=='function') return null;
  let showOriginal=false;
  const names=labels||{};
  function render() {
   const result=view(record,locale,showOriginal);
   element.textContent=result.text;
   element.setAttribute?.('dir',result.shownLanguage==='ar'?'rtl':'auto');
   // Attribut lang réservé au texte réellement affiché (traduction ou original).
   if(result.shownLanguage) element.setAttribute?.('lang',result.shownLanguage);
   else element.removeAttribute?.('lang');
   button.hidden=!result.showOriginalAvailable;
   button.textContent=showOriginal?(names.showTranslation||'Voir la traduction'):(names.showOriginal||"Voir l'original");
   button.setAttribute?.('aria-pressed',showOriginal?'true':'false');
   return result;
  }
  function toggle(){showOriginal=!showOriginal;render();}
  button.addEventListener('click',toggle);
  render();
  return Object.freeze({render,detach:function(){button.removeEventListener?.('click',toggle)}});
 }
 global.RPPlayerText=Object.freeze({view,renderText,attachToggle});
})(window);
