/* Réponses de secours de l'interface PNJ, jamais des répliques fournisseur.
 * Les actions, le constat de profil absent et les étapes de quête restent autoritaires.
 * Aucune traduction de texte joueur ou de mémoire PNJ.
 */
(function(global){
 'use strict';
 const resources=global.RP_I18N_RESOURCES;
 if(!resources)return;
 const labels={
  "fr": {
    "noConversation": "Ce personnage n'engage pas de conversation.",
    "temporaryUnavailable": "Discussion impossible momentanément. Veuillez réessayer dans quelques instants.",
    "noConversationHint": "Cette personne ne tient pas de conversation. Les autres actions restent disponibles.",
    "questRecap": "Je vous remontre où nous en sommes."
  },
  "en": {
    "noConversation": "This character does not engage in conversation.",
    "temporaryUnavailable": "Conversation is temporarily unavailable. Please try again shortly.",
    "noConversationHint": "This person does not hold conversations. Other actions remain available.",
    "questRecap": "Let me show you where we are again."
  },
  "es": {
    "noConversation": "Este personaje no entabla conversaciones.",
    "temporaryUnavailable": "La conversación no está disponible por el momento. Vuelve a intentarlo en unos instantes.",
    "noConversationHint": "Esta persona no mantiene conversaciones. Las demás acciones siguen disponibles.",
    "questRecap": "Te mostraré de nuevo en qué punto estamos."
  },
  "zh-TW": {
    "noConversation": "這個角色不會進行對話。",
    "temporaryUnavailable": "目前暫時無法對話，請稍後再試。",
    "noConversationHint": "此人不提供對話功能，其他行動仍可使用。",
    "questRecap": "讓我再向你說明目前的進度。"
  },
  "ru": {
    "noConversation": "Этот персонаж не ведёт бесед.",
    "temporaryUnavailable": "Разговор временно недоступен. Попробуйте ещё раз чуть позже.",
    "noConversationHint": "С этим персонажем нельзя поговорить. Остальные действия по-прежнему доступны.",
    "questRecap": "Давайте я ещё раз покажу, на чём мы остановились."
  },
  "ko": {
    "noConversation": "이 캐릭터와는 대화할 수 없습니다.",
    "temporaryUnavailable": "일시적으로 대화할 수 없습니다. 잠시 후 다시 시도하세요.",
    "noConversationHint": "이 사람과는 대화할 수 없습니다. 다른 행동은 계속 이용할 수 있습니다.",
    "questRecap": "현재 진행 상황을 다시 보여 드릴게요."
  },
  "ar": {
    "noConversation": "هذه الشخصية لا تدخل في محادثات.",
    "temporaryUnavailable": "المحادثة غير متاحة مؤقتًا. يُرجى المحاولة مجددًا بعد قليل.",
    "noConversationHint": "لا يمكن التحاور مع هذه الشخصية. تظل الإجراءات الأخرى متاحة.",
    "questRecap": "دعني أوضح لك مجددًا أين وصلنا."
  },
  "pt-BR": {
    "noConversation": "Este personagem não participa de conversas.",
    "temporaryUnavailable": "A conversa está temporariamente indisponível. Tente novamente em instantes.",
    "noConversationHint": "Esta pessoa não conversa. As outras ações continuam disponíveis.",
    "questRecap": "Vou mostrar novamente em que ponto estamos."
  },
  "de": {
    "noConversation": "Diese Figur führt keine Gespräche.",
    "temporaryUnavailable": "Ein Gespräch ist vorübergehend nicht möglich. Bitte versuche es in Kürze erneut.",
    "noConversationHint": "Mit dieser Person sind keine Gespräche möglich. Andere Aktionen bleiben verfügbar.",
    "questRecap": "Ich zeige dir noch einmal, wo wir stehen."
  }
};
 for(const [locale,entries] of Object.entries(labels)){
  if(resources[locale]?.translation)resources[locale].translation.pnjStatus={...entries};
 }
 const canonical=labels.fr;
 function label(key,original){
  if(!Object.hasOwn(canonical,key)||typeof original!=='string'||original!==canonical[key])return original;
  const locale=global.RPPlateauI18n?.language?.()||'fr';
  const t=global.i18next?.t?.('pnjStatus.'+key,{lng:locale,defaultValue:original});
  return typeof t==='string'&&t.trim() ? t : original;
 }
 global.RPPnjStatusI18n=Object.freeze({label});
})(window);
