/* Interventions spontanées des PNJ sociaux — texte d'affichage uniquement.
 * Le choix du jalon, ses conditions, la relation et la mémoire restent au serveur.
 * Aucun appel DeepSeek, aucune traduction de la réponse libre du joueur.
 */
(function(global){
  'use strict';
  const resources=global.RP_I18N_RESOURCES;
  if(!resources)return;
  const labels={
  "fr": {
    "jeanLou": "Alors moussaillon, on apprécie l'endroit ? C'est la deuxième fois que je vous vois venir ici.",
    "marine": "Bonjour {{name}}, bienvenue dans notre restaurant Capitaine Sauvage. N'ayez crainte, c'est le surnom de mon Papa, mais il est très gentil."
  },
  "en": {
    "jeanLou": "Well, sailor, enjoying the place? That's the second time I've seen you come in here.",
    "marine": "Hello {{name}}, welcome to our restaurant, Capitaine Sauvage. Don't worry, that's just my dad's nickname. He's actually very kind."
  },
  "es": {
    "jeanLou": "Bueno, marinero, ¿te gusta el lugar? Ya es la segunda vez que te veo por aquí.",
    "marine": "Hola, {{name}}. Te damos la bienvenida a nuestro restaurante Capitaine Sauvage. No te preocupes, ese es solo el apodo de mi padre. En realidad es muy amable."
  },
  "zh-TW": {
    "jeanLou": "喂，水手，喜歡這裡嗎？我已經第二次看見你走進來了。",
    "marine": "你好，{{name}}，歡迎來到我們的餐廳 Capitaine Sauvage。別擔心，那只是我爸爸的綽號，其實他人很好。"
  },
  "ru": {
    "jeanLou": "Ну что, морячок, нравится здесь? Я вас уже второй раз тут вижу.",
    "marine": "Здравствуйте, {{name}}! Добро пожаловать в наш ресторан Capitaine Sauvage. Не пугайтесь названия: это всего лишь прозвище моего папы. На самом деле он очень добрый."
  },
  "ko": {
    "jeanLou": "어이, 선원 양반! 여기 마음에 들어요? 벌써 두 번째로 오는 걸 봤거든요.",
    "marine": "안녕하세요, {{name}}님. 저희 Capitaine Sauvage 식당에 오신 걸 환영해요. 걱정 마세요. 그건 아빠의 별명일 뿐이에요. 사실 아주 다정한 분이랍니다."
  },
  "ar": {
    "jeanLou": "حسنًا يا بحّار، هل أعجبك المكان؟ هذه ثاني مرة أراك تدخل إلى هنا.",
    "marine": "مرحبًا يا {{name}}، أهلًا بك في مطعمنا Capitaine Sauvage. لا تقلق، فهذا مجرد لقب والدي، وهو في الحقيقة لطيف جدًا."
  },
  "pt-BR": {
    "jeanLou": "E aí, marujo, gostando daqui? Já é a segunda vez que vejo você entrar.",
    "marine": "Olá, {{name}}! Boas-vindas ao nosso restaurante Capitaine Sauvage. Não se preocupe, esse é só o apelido do meu pai. Ele é muito gentil."
  },
  "de": {
    "jeanLou": "Na, Matrose, gefällt's dir hier? Ich sehe dich schon zum zweiten Mal hereinkommen.",
    "marine": "Hallo {{name}}, willkommen in unserem Restaurant Capitaine Sauvage. Keine Sorge, das ist nur der Spitzname meines Vaters. Eigentlich ist er sehr freundlich."
  }
};
  for(const [locale,strings] of Object.entries(labels)){
    if(resources[locale]?.translation)
      resources[locale].translation.socialPnj={...strings};
  }
  function format(key,variables,original){
    if(typeof original!=='string')return original;
    if(global.RP_I18N_GAME_ENABLED!==true)return original;
    if(!Object.hasOwn(labels.fr,key))return original;
    const lang=global.RPPlateauI18n?.language?.()||'fr';
    if(lang==='fr'||!Object.hasOwn(labels,lang))return original;
    const template=resources[lang]?.translation?.socialPnj?.[key];
    if(typeof template!=='string'||!template.trim())return original;
    const name=typeof variables?.name==='string'?variables.name:'';
    // Ne pas interpréter HTML ni traduire le nom propre du PJ.
    return template.replace(/\{\{name\}\}/g,name);
  }
  global.RPSocialPnjI18n=Object.freeze({format});
})(window);
