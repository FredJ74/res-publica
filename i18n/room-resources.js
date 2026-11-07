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
 // Intitulés propres aux six ministères de Sovarka (autres empires inchangés).
 const ministries={
  "fr": {
    "bureau_min_int": "Bureau - Ministre de la Sécurité du Peuple",
    "bureau_min_fin": "Bureau - Ministre de l'Économie collective",
    "bureau_min_just": "Bureau - Ministre de la Justice prolétarienne",
    "bureau_min_def": "Bureau - Ministre de la Défense de la Patrie",
    "bureau_min_info": "Bureau - Ministre de la Vérité officielle",
    "bureau_min_ae": "Bureau - Ministre de l'Amitié entre les Peuples"
  },
  "en": {
    "bureau_min_int": "Office — Minister of People's Security",
    "bureau_min_fin": "Office — Minister of the Collective Economy",
    "bureau_min_just": "Office — Minister of Proletarian Justice",
    "bureau_min_def": "Office — Minister of Homeland Defence",
    "bureau_min_info": "Office — Minister of Official Truth",
    "bureau_min_ae": "Office — Minister of Friendship among Peoples"
  },
  "es": {
    "bureau_min_int": "Despacho — Ministro de Seguridad del Pueblo",
    "bureau_min_fin": "Despacho — Ministro de Economía Colectiva",
    "bureau_min_just": "Despacho — Ministro de Justicia Proletaria",
    "bureau_min_def": "Despacho — Ministro de Defensa de la Patria",
    "bureau_min_info": "Despacho — Ministro de la Verdad Oficial",
    "bureau_min_ae": "Despacho — Ministro de Amistad entre los Pueblos"
  },
  "zh-TW": {
    "bureau_min_int": "人民安全部長辦公室",
    "bureau_min_fin": "集體經濟部長辦公室",
    "bureau_min_just": "無產階級司法部長辦公室",
    "bureau_min_def": "祖國國防部長辦公室",
    "bureau_min_info": "官方真相部長辦公室",
    "bureau_min_ae": "民族友誼部長辦公室"
  },
  "ru": {
    "bureau_min_int": "Кабинет министра народной безопасности",
    "bureau_min_fin": "Кабинет министра коллективной экономики",
    "bureau_min_just": "Кабинет министра пролетарской юстиции",
    "bureau_min_def": "Кабинет министра обороны Родины",
    "bureau_min_info": "Кабинет министра официальной правды",
    "bureau_min_ae": "Кабинет министра дружбы народов"
  },
  "ko": {
    "bureau_min_int": "인민안전부 장관실",
    "bureau_min_fin": "집단경제부 장관실",
    "bureau_min_just": "프롤레타리아 사법부 장관실",
    "bureau_min_def": "조국방위부 장관실",
    "bureau_min_info": "공식 진실부 장관실",
    "bureau_min_ae": "민족 간 우호부 장관실"
  },
  "ar": {
    "bureau_min_int": "مكتب وزير أمن الشعب",
    "bureau_min_fin": "مكتب وزير الاقتصاد الجماعي",
    "bureau_min_just": "مكتب وزير العدالة البروليتارية",
    "bureau_min_def": "مكتب وزير الدفاع عن الوطن",
    "bureau_min_info": "مكتب وزير الحقيقة الرسمية",
    "bureau_min_ae": "مكتب وزير الصداقة بين الشعوب"
  },
  "pt-BR": {
    "bureau_min_int": "Gabinete — Ministro da Segurança do Povo",
    "bureau_min_fin": "Gabinete — Ministro da Economia Coletiva",
    "bureau_min_just": "Gabinete — Ministro da Justiça Proletária",
    "bureau_min_def": "Gabinete — Ministro da Defesa da Pátria",
    "bureau_min_info": "Gabinete — Ministro da Verdade Oficial",
    "bureau_min_ae": "Gabinete — Ministro da Amizade entre os Povos"
  },
  "de": {
    "bureau_min_int": "Büro — Minister für Volkssicherheit",
    "bureau_min_fin": "Büro — Minister für Kollektivwirtschaft",
    "bureau_min_just": "Büro — Minister für proletarische Justiz",
    "bureau_min_def": "Büro — Minister für Landesverteidigung",
    "bureau_min_info": "Büro — Minister für offizielle Wahrheit",
    "bureau_min_ae": "Büro — Minister für Völkerfreundschaft"
  }
};
 for(const [lang,labels] of Object.entries(ministries)) Object.assign(localized[lang],labels);
 // Mairies provinciales : uniquement les trois intitulés canoniques des gabarits.
 const mairie={
  "fr": {
    "accueil_mairie": "Accueil",
    "bureau_maire_local": "Bureau du Maire",
    "bureau_maire_adjoint": "Bureau du Maire Adjoint"
  },
  "en": {
    "accueil_mairie": "Reception",
    "bureau_maire_local": "Mayor's Office",
    "bureau_maire_adjoint": "Deputy Mayor's Office"
  },
  "es": {
    "accueil_mairie": "Recepción",
    "bureau_maire_local": "Despacho del alcalde",
    "bureau_maire_adjoint": "Despacho del teniente de alcalde"
  },
  "zh-TW": {
    "accueil_mairie": "接待處",
    "bureau_maire_local": "市長辦公室",
    "bureau_maire_adjoint": "副市長辦公室"
  },
  "ru": {
    "accueil_mairie": "Приёмная",
    "bureau_maire_local": "Кабинет мэра",
    "bureau_maire_adjoint": "Кабинет заместителя мэра"
  },
  "ko": {
    "accueil_mairie": "안내실",
    "bureau_maire_local": "시장실",
    "bureau_maire_adjoint": "부시장실"
  },
  "ar": {
    "accueil_mairie": "الاستقبال",
    "bureau_maire_local": "مكتب رئيس البلدية",
    "bureau_maire_adjoint": "مكتب نائب رئيس البلدية"
  },
  "pt-BR": {
    "accueil_mairie": "Recepção",
    "bureau_maire_local": "Gabinete do prefeito",
    "bureau_maire_adjoint": "Gabinete do vice-prefeito"
  },
  "de": {
    "accueil_mairie": "Empfang",
    "bureau_maire_local": "Büro des Bürgermeisters",
    "bureau_maire_adjoint": "Büro des stellvertretenden Bürgermeisters"
  }
};
 for(const [locale,labels] of Object.entries(mairie)) Object.assign(localized[locale],labels);
 const expected=localized.fr;
 for(const [locale,labels] of Object.entries(localized)){
  if(resources[locale]?.translation)
   resources[locale].translation.rooms={...labels};
 }
 function label(buildingId,roomId,original){
  if(typeof original!=='string')return original;
  // Les autres édifices et les variantes politiques conservent leurs noms.
  if(buildingId==='mairie') {
   if(!Object.hasOwn(mairie.fr,roomId)||original!==mairie.fr[roomId])return original;
  } else if(buildingId==='palais-gouvernement') {
   if(!Object.hasOwn(expected,roomId)||original!==expected[roomId])return original;
  } else return original;
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
