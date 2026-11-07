/* Traduction d'affichage des quatre salles du gouvernement.
 * Un seul moteur i18next : réutilise les locales et le dictionnaire central.
 * Le nom source, roomId, navigation, état de porte et ordres restent inchangés.
 */
(function(global){
 'use strict';
 const resources=global.RP_I18N_RESOURCES;
 if(!resources)return;
 const localized={
  "fr": {
    "bureaux": "Bureau du Président du Conseil du Peuple",
    "salle_conseil": "Salle du Conseil du Peuple",
    "salle_presse": "Salle de Presse",
    "archives_gouv": "Archives Gouvernementales"
  },
  "en": {
    "bureaux": "Office of the President of the People's Council",
    "salle_conseil": "People's Council Chamber",
    "salle_presse": "Press Room",
    "archives_gouv": "Government Archives"
  },
  "es": {
    "bureaux": "Despacho del Presidente del Consejo del Pueblo",
    "salle_conseil": "Sala del Consejo del Pueblo",
    "salle_presse": "Sala de prensa",
    "archives_gouv": "Archivos gubernamentales"
  },
  "zh-TW": {
    "bureaux": "人民委員會主席辦公室",
    "salle_conseil": "人民委員會會議廳",
    "salle_presse": "新聞發布室",
    "archives_gouv": "政府檔案室"
  },
  "ru": {
    "bureaux": "Кабинет председателя Совета народа",
    "salle_conseil": "Зал Совета народа",
    "salle_presse": "Пресс-зал",
    "archives_gouv": "Правительственный архив"
  },
  "ko": {
    "bureaux": "인민평의회 의장실",
    "salle_conseil": "인민평의회 회의실",
    "salle_presse": "기자회견실",
    "archives_gouv": "정부 기록보관소"
  },
  "ar": {
    "bureaux": "مكتب رئيس مجلس الشعب",
    "salle_conseil": "قاعة مجلس الشعب",
    "salle_presse": "قاعة الصحافة",
    "archives_gouv": "الأرشيف الحكومي"
  },
  "pt-BR": {
    "bureaux": "Gabinete do Presidente do Conselho do Povo",
    "salle_conseil": "Sala do Conselho do Povo",
    "salle_presse": "Sala de imprensa",
    "archives_gouv": "Arquivos governamentais"
  },
  "de": {
    "bureaux": "Büro des Vorsitzenden des Volksrats",
    "salle_conseil": "Saal des Volksrats",
    "salle_presse": "Presseraum",
    "archives_gouv": "Regierungsarchiv"
  }
};
 const expected=localized.fr;
 for(const [locale,labels] of Object.entries(localized)){
  if(resources[locale]?.translation)
   resources[locale].translation.rooms={...labels};
 }
 function label(buildingId,roomId,original){
  if(buildingId!=='palais-gouvernement'||typeof original!=='string')return original;
  if(!Object.hasOwn(expected,roomId)||original!==expected[roomId])return original;
  const locale=global.RPPlateauI18n?.language?.()||'fr';
  const translated=global.i18next?.t?.('rooms.'+roomId,{lng:locale,defaultValue:original});
  return typeof translated==='string'&&translated.trim() ? translated : original;
 }
 function labelHtml(buildingId,roomId,original){
  const output=label(buildingId,roomId,original);
  if(output===original)return original;
  return output.replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 }
 global.RPRoomI18n=Object.freeze({label,labelHtml});
})(window);
