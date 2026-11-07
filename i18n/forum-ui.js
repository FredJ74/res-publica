/* Commandes d'interface du forum : traduction d'affichage uniquement.
 * Ni identité de publication, ni forum, ni texte utilisateur, ni requête serveur.
 * Réutilise le même dictionnaire et le même moteur i18next que le plateau.
 */
(function(global){
 'use strict';
 const resources=global.RP_I18N_RESOURCES;
 if(!resources)return;
 const words={
  "fr": {
    "newTopic": "Nouveau sujet",
    "reply": "Répondre",
    "retry": "Réessayer",
    "newMail": "Nouveau mail",
    "back": "Retour",
    "backToTopic": "Retour au sujet",
    "postAs": "Publier en tant que",
    "sendAs": "Envoyer en tant que"
  },
  "en": {
    "newTopic": "New topic",
    "reply": "Reply",
    "retry": "Retry",
    "newMail": "New mail",
    "back": "Back",
    "backToTopic": "Back to topic",
    "postAs": "Post as",
    "sendAs": "Send as"
  },
  "es": {
    "newTopic": "Nuevo tema",
    "reply": "Responder",
    "retry": "Reintentar",
    "newMail": "Nuevo correo",
    "back": "Volver",
    "backToTopic": "Volver al tema",
    "postAs": "Publicar como",
    "sendAs": "Enviar como"
  },
  "zh-TW": {
    "newTopic": "新主題",
    "reply": "回覆",
    "retry": "重試",
    "newMail": "新郵件",
    "back": "返回",
    "backToTopic": "返回主題",
    "postAs": "以此身分發表",
    "sendAs": "以此身分傳送"
  },
  "ru": {
    "newTopic": "Новая тема",
    "reply": "Ответить",
    "retry": "Повторить попытку",
    "newMail": "Новое письмо",
    "back": "Назад",
    "backToTopic": "К теме",
    "postAs": "Опубликовать от имени",
    "sendAs": "Отправить от имени"
  },
  "ko": {
    "newTopic": "새 주제",
    "reply": "답글",
    "retry": "다시 시도",
    "newMail": "새 편지",
    "back": "뒤로",
    "backToTopic": "주제로 돌아가기",
    "postAs": "다음 이름으로 게시",
    "sendAs": "다음 이름으로 보내기"
  },
  "ar": {
    "newTopic": "موضوع جديد",
    "reply": "الرد",
    "retry": "إعادة المحاولة",
    "newMail": "رسالة جديدة",
    "back": "رجوع",
    "backToTopic": "العودة إلى الموضوع",
    "postAs": "النشر باسم",
    "sendAs": "الإرسال باسم"
  },
  "pt-BR": {
    "newTopic": "Novo tópico",
    "reply": "Responder",
    "retry": "Tentar novamente",
    "newMail": "Novo e-mail",
    "back": "Voltar",
    "backToTopic": "Voltar ao tópico",
    "postAs": "Publicar como",
    "sendAs": "Enviar como"
  },
  "de": {
    "newTopic": "Neues Thema",
    "reply": "Antworten",
    "retry": "Erneut versuchen",
    "newMail": "Neue Nachricht",
    "back": "Zurück",
    "backToTopic": "Zurück zum Thema",
    "postAs": "Veröffentlichen als",
    "sendAs": "Senden als"
  }
};
 const keys=new Set(Object.keys(words.fr));
 for(const [lang,labels] of Object.entries(words)){
  if(resources[lang]?.translation)
   resources[lang].translation.forumUI={...labels};
 }
 function labelHtml(key,original){
  if(!keys.has(key)||typeof original!=='string')return original;
  const locale=global.RPPlateauI18n?.language?.()||'fr';
  const translation=global.i18next?.t?.('forumUI.'+key,{lng:locale,defaultValue:original});
  if(typeof translation!=='string'||!translation.trim()||translation===original)return original;
  return translation.replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 }
 global.RPForumUI=Object.freeze({labelHtml});
})(window);
