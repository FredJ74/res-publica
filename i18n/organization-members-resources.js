/* Membres des organisations : textes fixes, noms et grades RP inchangés. */
(function(global){
 'use strict';
 const locales=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
 const rows=[
  [
    "sinceDay",
    "Depuis Jour ",
    "Since Day ",
    "Desde el día ",
    "加入日：",
    "Со дня ",
    "가입일: ",
    "منذ اليوم ",
    "Desde o dia ",
    "Seit Tag "
  ],
  [
    "promote",
    "Monter en grade",
    "Promote",
    "Ascender de rango",
    "晉升",
    "Повысить в звании",
    "승급",
    "ترقية",
    "Promover",
    "Befördern"
  ],
  [
    "demote",
    "Descendre en grade",
    "Demote",
    "Degradar de rango",
    "降級",
    "Понизить в звании",
    "강등",
    "خفض الرتبة",
    "Rebaixar",
    "Degradieren"
  ],
  [
    "exclude",
    "Exclure",
    "Expel",
    "Expulsar",
    "除名",
    "Исключить",
    "제명",
    "طرد",
    "Expulsar",
    "Ausschließen"
  ]
];
 for(const [index,lang]of locales.entries())if(global.RP_I18N_RESOURCES?.[lang]?.translation)
  global.RP_I18N_RESOURCES[lang].translation.organizationMembers=Object.fromEntries(rows.map(row=>[row[0],row[index+1]]));
})(window);
