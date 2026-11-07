/* Dialogue d'entrée : garde présidentiel / joueur.
 * Seules les chaînes de présentation varient avec la locale ; aucune
 * modification des étapes, des décisions, des flèches ou des ordres.
 */
(function(global){
 'use strict';
 const resources=global.RP_I18N_RESOURCES;
 if(!resources)return;
 const entries={
  "fr": {
    "guardWarning": "Hey, vous !<br><br>Vous n'êtes pas autorisé à rester ici ! Le Président va bientôt sortir !<br><br>Et puis vous êtes nouveau, on ne vous a jamais vu, je me trompe ? Allez vous présenter à l'Hôtel de Ville sinon c'est au commissariat que vous finirez.",
    "playerAsks": "Je veux bien, mais ou est l'Hotel de Ville ?",
    "guardDirections": "Continuez sur cette rue, ensuite il y aura un croisement.<br><br>Continuez encore une fois sur la même rue, et vous trouverez l'Hôtel de Ville.<br><br>Adressez-vous au secrétaire municipal <strong>Petit</strong>.<br><br>Il vous parlera sûrement des impôts, mais répondez-lui simplement que <strong>vous êtes nouveau</strong>, cela devrait l'adoucir.",
    "playerThanks": "D'accord... merci... je lui dirai que je suis nouveau...",
    "hostileTitle": "Un garde presidentiel",
    "friendlyTitle": "Le garde presidentiel",
    "you": "Vous"
  },
  "en": {
    "guardWarning": "Hey, you!<br><br>You're not allowed to stay here! The President is about to come out!<br><br>And you're new, aren't you? I've never seen you before. Go and introduce yourself at Town Hall, or you'll end up at the police station.",
    "playerAsks": "All right, but where is Town Hall?",
    "guardDirections": "Keep going down this street until you reach a crossroads.<br><br>Carry on along the same street, and you'll find Town Hall.<br><br>Speak to municipal secretary <strong>Petit</strong>.<br><br>He'll probably talk about taxes, but just tell him <strong>you're new here</strong>. That should soften him up.",
    "playerThanks": "All right... thank you... I'll tell him I'm new here...",
    "hostileTitle": "A presidential guard",
    "friendlyTitle": "The presidential guard",
    "you": "You"
  },
  "es": {
    "guardWarning": "¡Eh, usted!<br><br>¡No tiene permiso para quedarse aquí! ¡El Presidente está a punto de salir!<br><br>Y además es nuevo, ¿verdad? Nunca le había visto. Preséntese en el Ayuntamiento, ¡o acabará en comisaría!",
    "playerAsks": "De acuerdo, pero ¿dónde está el Ayuntamiento?",
    "guardDirections": "Siga por esta calle hasta llegar a un cruce.<br><br>Continúe por la misma calle y encontrará el Ayuntamiento.<br><br>Pregunte por el secretario municipal <strong>Petit</strong>.<br><br>Seguramente le hablará de impuestos, pero dígale simplemente que <strong>es nuevo aquí</strong>. Seguro que se ablanda.",
    "playerThanks": "Vale... gracias... le diré que soy nuevo...",
    "hostileTitle": "Un guardia presidencial",
    "friendlyTitle": "El guardia presidencial",
    "you": "Usted"
  },
  "zh-TW": {
    "guardWarning": "嘿，你！<br><br>你不能待在這裡！總統馬上就要出來了！<br><br>而且你是新來的，對吧？我以前沒見過你。快去市政廳報到，不然就等著進警察局吧。",
    "playerAsks": "好吧……可是市政廳在哪裡？",
    "guardDirections": "沿著這條街一直走，直到十字路口。<br><br>繼續沿同一條路走，就能找到市政廳。<br><br>去找市政秘書 <strong>Petit</strong>。<br><br>他大概會跟你談稅務，不過你只要說<strong>我是新來的</strong>，他應該就會和氣些。",
    "playerThanks": "好……謝謝……我會跟他說我是新來的……",
    "hostileTitle": "總統衛兵",
    "friendlyTitle": "那名總統衛兵",
    "you": "你"
  },
  "ru": {
    "guardWarning": "Эй, вы!<br><br>Вам нельзя здесь оставаться! Президент скоро выйдет!<br><br>И вы здесь новенький, верно? Раньше я вас не видел. Ступайте представиться в мэрию, иначе окажетесь в полицейском участке.",
    "playerAsks": "Хорошо, но где находится мэрия?",
    "guardDirections": "Идите по этой улице до перекрёстка.<br><br>Дальше следуйте прямо по той же улице — там будет мэрия.<br><br>Обратитесь к муниципальному секретарю <strong>Petit</strong>.<br><br>Он наверняка заговорит о налогах, но просто скажите: <strong>я новенький</strong>. Это должно его смягчить.",
    "playerThanks": "Ладно... спасибо... скажу ему, что я новенький...",
    "hostileTitle": "Президентский гвардеец",
    "friendlyTitle": "Президентский гвардеец",
    "you": "Вы"
  },
  "ko": {
    "guardWarning": "이봐요, 거기!<br><br>여기 머물면 안 됩니다! 대통령께서 곧 나오실 겁니다!<br><br>당신은 새로 왔죠? 본 적이 없거든요. 시청에 가서 신고하세요. 안 그러면 경찰서로 가게 될 겁니다.",
    "playerAsks": "알겠습니다. 그런데 시청은 어디 있나요?",
    "guardDirections": "이 길을 따라 교차로까지 가세요.<br><br>같은 길로 계속 가면 시청이 나옵니다.<br><br>시청 비서 <strong>Petit</strong>에게 말을 거세요.<br><br>세금 이야기를 꺼내겠지만 <strong>새로 왔어요</strong>라고만 말하면 좀 누그러질 겁니다.",
    "playerThanks": "네... 고맙습니다... 새로 왔다고 말할게요...",
    "hostileTitle": "대통령 경비병",
    "friendlyTitle": "그 대통령 경비병",
    "you": "당신"
  },
  "ar": {
    "guardWarning": "أنت هناك!<br><br>لا يُسمح لك بالبقاء هنا! سيخرج الرئيس بعد قليل!<br><br>وأنت وافد جديد، أليس كذلك؟ لم أرك من قبل. اذهب وقدّم نفسك في البلدية، وإلا انتهى بك الأمر في مركز الشرطة.",
    "playerAsks": "حسنًا، ولكن أين تقع البلدية؟",
    "guardDirections": "تابع السير في هذا الشارع حتى تصل إلى تقاطع.<br><br>واصل في الشارع نفسه وستجد البلدية.<br><br>تحدّث إلى السكرتير البلدي <strong>Petit</strong>.<br><br>سيتحدث على الأرجح عن الضرائب، لكن أخبره ببساطة: <strong>أنا جديد</strong>. هذا قد يجعله أكثر لطفًا.",
    "playerThanks": "حسنًا... شكرًا... سأخبره أنني جديد...",
    "hostileTitle": "حارس رئاسي",
    "friendlyTitle": "الحارس الرئاسي",
    "you": "أنت"
  },
  "pt-BR": {
    "guardWarning": "Ei, você!<br><br>Você não pode ficar aqui! O Presidente vai sair daqui a pouco!<br><br>E você é novo, não é? Nunca vi você antes. Vá se apresentar na Prefeitura, ou vai acabar na delegacia.",
    "playerAsks": "Tudo bem, mas onde fica a Prefeitura?",
    "guardDirections": "Siga por esta rua até chegar a um cruzamento.<br><br>Continue na mesma rua e encontrará a Prefeitura.<br><br>Procure o secretário municipal <strong>Petit</strong>.<br><br>Ele provavelmente vai falar de impostos, mas diga apenas que <strong>você é novo aqui</strong>. Isso deve deixá-lo mais tranquilo.",
    "playerThanks": "Certo... obrigado... vou dizer que sou novo aqui...",
    "hostileTitle": "Um guarda presidencial",
    "friendlyTitle": "O guarda presidencial",
    "you": "Você"
  },
  "de": {
    "guardWarning": "He, Sie da!<br><br>Sie dürfen sich hier nicht aufhalten! Der Präsident kommt gleich heraus!<br><br>Und Sie sind neu hier, nicht wahr? Ich habe Sie noch nie gesehen. Melden Sie sich im Rathaus, sonst landen Sie auf der Polizeiwache.",
    "playerAsks": "In Ordnung, aber wo ist das Rathaus?",
    "guardDirections": "Gehen Sie diese Straße entlang bis zur Kreuzung.<br><br>Bleiben Sie auf derselben Straße, dann erreichen Sie das Rathaus.<br><br>Melden Sie sich beim Stadtsekretär <strong>Petit</strong>.<br><br>Er wird vermutlich über Steuern sprechen. Sagen Sie einfach, dass <strong>Sie neu hier sind</strong>. Das sollte ihn besänftigen.",
    "playerThanks": "In Ordnung... danke... ich werde ihm sagen, dass ich neu bin...",
    "hostileTitle": "Ein Präsidentengardist",
    "friendlyTitle": "Der Präsidentengardist",
    "you": "Sie"
  }
};
 for(const [lang,values] of Object.entries(entries)) if(resources[lang]?.translation)
  resources[lang].translation.guardWelcome={...values};
 function label(key,original) {
  if(typeof original!=='string'||entries.fr[key]!==original)return original;
  const lng=global.RPPlateauI18n?.language?.()||'fr';
  const v=global.i18next?.t?.('guardWelcome.'+key,{lng,defaultValue:original});
  if(typeof v!=='string'||!v.trim()||/<(?!br\s*\/?\s*>|strong>|\/strong>)/i.test(v))return original;
  return v;
 }
 global.RPGuardWelcomeI18n=Object.freeze({label});
})(window);
