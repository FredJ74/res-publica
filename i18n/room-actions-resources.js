/* Titres des actions et commandes d'audioguide : affichage uniquement.
 * Le lecteur audio, les coûts en PA, la source de la salle et les callbacks restent intacts.
 */
(function(global){
 'use strict';
 const resources=global.RP_I18N_RESOURCES;
 if(!resources)return;
 const texts={
  "fr": {
    "actionsAvailable": "ACTIONS DISPONIBLES",
    "audioTooltip": "Ecouter l'audioguide de cette salle",
    "audioAction": "Écouter l'audioguide",
    "audioCost": "gratuit · 0 PA"
  },
  "en": {
    "actionsAvailable": "AVAILABLE ACTIONS",
    "audioTooltip": "Listen to this room's audio guide",
    "audioAction": "Listen to the audio guide",
    "audioCost": "free · 0 PA"
  },
  "es": {
    "actionsAvailable": "ACCIONES DISPONIBLES",
    "audioTooltip": "Escuchar la audioguía de esta sala",
    "audioAction": "Escuchar la audioguía",
    "audioCost": "gratis · 0 PA"
  },
  "zh-TW": {
    "actionsAvailable": "可執行的操作",
    "audioTooltip": "聆聽此展廳的語音導覽",
    "audioAction": "聆聽語音導覽",
    "audioCost": "免費 · 0 PA"
  },
  "ru": {
    "actionsAvailable": "ДОСТУПНЫЕ ДЕЙСТВИЯ",
    "audioTooltip": "Прослушать аудиогид по этому залу",
    "audioAction": "Прослушать аудиогид",
    "audioCost": "бесплатно · 0 PA"
  },
  "ko": {
    "actionsAvailable": "이용 가능한 행동",
    "audioTooltip": "이 방의 오디오 가이드 듣기",
    "audioAction": "오디오 가이드 듣기",
    "audioCost": "무료 · 0 PA"
  },
  "ar": {
    "actionsAvailable": "الإجراءات المتاحة",
    "audioTooltip": "الاستماع إلى الدليل الصوتي لهذه القاعة",
    "audioAction": "استمع إلى الدليل الصوتي",
    "audioCost": "مجانًا · 0 PA"
  },
  "pt-BR": {
    "actionsAvailable": "AÇÕES DISPONÍVEIS",
    "audioTooltip": "Ouvir o audioguia desta sala",
    "audioAction": "Ouvir audioguia",
    "audioCost": "grátis · 0 PA"
  },
  "de": {
    "actionsAvailable": "VERFÜGBARE AKTIONEN",
    "audioTooltip": "Audioguide für diesen Raum anhören",
    "audioAction": "Audioguide anhören",
    "audioCost": "kostenlos · 0 PA"
  }
};
 for(const [locale,words] of Object.entries(texts))
  if(resources[locale]?.translation)resources[locale].translation.roomActions={...words};
 function label(key,original){
  if(typeof original!=='string'||!Object.hasOwn(texts.fr,key)||texts.fr[key]!==original)return original;
  if(global.RP_I18N_GAME_ENABLED!==true)return original;
  const locale=global.RPPlateauI18n?.language?.()||'fr';
  const translated=resources[locale]?.translation?.roomActions?.[key];
  return typeof translated==='string'&&translated.trim()?translated:original;
 }
 function labelHtml(key,original){
  return label(key,original).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 }
 global.RPRoomActionsI18n=Object.freeze({label,labelHtml});
})(window);
