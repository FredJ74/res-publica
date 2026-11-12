/* Présentation du plan Open Space de Luthécia : affichage seul. */
(function(global){'use strict';
const words={
  "fr": {
    "toRent": "À louer",
    "occupied": "Occupé",
    "postA": "Open Space A",
    "postB": "Open Space B",
    "postC": "Open Space C",
    "postD": "Open Space D"
  },
  "en": {
    "toRent": "For rent",
    "occupied": "Occupied",
    "postA": "Shared Workspace A",
    "postB": "Shared Workspace B",
    "postC": "Shared Workspace C",
    "postD": "Shared Workspace D"
  },
  "es": {
    "toRent": "En alquiler",
    "occupied": "Ocupado",
    "postA": "Espacio compartido A",
    "postB": "Espacio compartido B",
    "postC": "Espacio compartido C",
    "postD": "Espacio compartido D"
  },
  "zh-TW": {
    "toRent": "招租中",
    "occupied": "已出租",
    "postA": "共享辦公區 A",
    "postB": "共享辦公區 B",
    "postC": "共享辦公區 C",
    "postD": "共享辦公區 D"
  },
  "ru": {
    "toRent": "Сдаётся в аренду",
    "occupied": "Занято",
    "postA": "Общий офис A",
    "postB": "Общий офис B",
    "postC": "Общий офис C",
    "postD": "Общий офис D"
  },
  "ko": {
    "toRent": "임대 가능",
    "occupied": "사용 중",
    "postA": "공유 사무실 A",
    "postB": "공유 사무실 B",
    "postC": "공유 사무실 C",
    "postD": "공유 사무실 D"
  },
  "ar": {
    "toRent": "متاح للإيجار",
    "occupied": "مشغول",
    "postA": "مساحة عمل مشتركة A",
    "postB": "مساحة عمل مشتركة B",
    "postC": "مساحة عمل مشتركة C",
    "postD": "مساحة عمل مشتركة D"
  },
  "pt-BR": {
    "toRent": "Para alugar",
    "occupied": "Ocupado",
    "postA": "Escritório compartilhado A",
    "postB": "Escritório compartilhado B",
    "postC": "Escritório compartilhado C",
    "postD": "Escritório compartilhado D"
  },
  "de": {
    "toRent": "Zu vermieten",
    "occupied": "Belegt",
    "postA": "Gemeinschaftsbüro A",
    "postB": "Gemeinschaftsbüro B",
    "postC": "Gemeinschaftsbüro C",
    "postD": "Gemeinschaftsbüro D"
  }
};
if(global.RP_I18N_RESOURCES)for(const [locale,values] of Object.entries(words)){
 const dest=global.RP_I18N_RESOURCES[locale]?.translation;
 if(dest)dest.openSpace=values;
}
function text(key,fr){
 const lang=global.RP_I18N_GAME_ENABLED===true?(global.RPPlateauI18n?.language?.()||'fr'):'fr';
 return lang==='fr'?String(fr):words[lang]?.[key]||String(fr);
}
global.RPOpenSpaceI18n=Object.freeze({words,text});
})(window);
