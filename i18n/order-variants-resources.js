/* Variantes d'ordres de même fn : uniquement le texte visible.
 * Les identifiants métiers, frais et droits restent inchangés ;
 * une variante ne devient jamais une nouvelle commande dans le catalogue.
 */
(function(global){
 'use strict';
 const resources=global.RP_I18N_RESOURCES;
 if(!resources)return;
 const variants={
  "fr": {
    "hotel_basic": "Reserver une chambre",
    "hotel_standard": "Réserver une chambre d'hôtel",
    "rumours_tables": "Ecouter les tables",
    "rumours_barman": "Ecouter le barman",
    "rumours_general": "Ecouter les rumeurs",
    "rumours_owner": "Ecouter le patron",
    "rumours_waitress": "Écouter la serveuse",
    "rumours_listen": "Tendre l'oreille",
    "press_conference": "Conférence de presse"
  },
  "en": {
    "hotel_basic": "Reserve a room",
    "hotel_standard": "Reserve a hotel room",
    "rumours_tables": "Listen to the conversations at the tables",
    "rumours_barman": "Listen to the bartender",
    "rumours_general": "Listen to rumours",
    "rumours_owner": "Listen to the owner",
    "rumours_waitress": "Listen to the waitress",
    "rumours_listen": "Keep an ear out",
    "press_conference": "Press conference"
  },
  "es": {
    "hotel_basic": "Reservar una habitación",
    "hotel_standard": "Reservar una habitación de hotel",
    "rumours_tables": "Escuchar las conversaciones de las mesas",
    "rumours_barman": "Escuchar al camarero",
    "rumours_general": "Escuchar rumores",
    "rumours_owner": "Escuchar al dueño",
    "rumours_waitress": "Escuchar a la camarera",
    "rumours_listen": "Prestar atención",
    "press_conference": "Conferencia de prensa"
  },
  "zh-TW": {
    "hotel_basic": "預訂房間",
    "hotel_standard": "預訂飯店房間",
    "rumours_tables": "聽聽各桌的談話",
    "rumours_barman": "聽酒保說話",
    "rumours_general": "打聽傳聞",
    "rumours_owner": "聽老闆說話",
    "rumours_waitress": "聽女服務生說話",
    "rumours_listen": "側耳傾聽",
    "press_conference": "記者會"
  },
  "ru": {
    "hotel_basic": "Забронировать номер",
    "hotel_standard": "Забронировать номер в гостинице",
    "rumours_tables": "Прислушаться к разговорам за столиками",
    "rumours_barman": "Послушать бармена",
    "rumours_general": "Послушать слухи",
    "rumours_owner": "Послушать хозяина",
    "rumours_waitress": "Послушать официантку",
    "rumours_listen": "Прислушаться",
    "press_conference": "Пресс-конференция"
  },
  "ko": {
    "hotel_basic": "객실 예약",
    "hotel_standard": "호텔 객실 예약",
    "rumours_tables": "테이블 대화 엿듣기",
    "rumours_barman": "바텐더 이야기 듣기",
    "rumours_general": "소문 듣기",
    "rumours_owner": "주인 이야기 듣기",
    "rumours_waitress": "종업원 이야기 듣기",
    "rumours_listen": "귀 기울이기",
    "press_conference": "기자회견"
  },
  "ar": {
    "hotel_basic": "حجز غرفة",
    "hotel_standard": "حجز غرفة فندقية",
    "rumours_tables": "الاستماع إلى أحاديث الطاولات",
    "rumours_barman": "الاستماع إلى الساقي",
    "rumours_general": "الاستماع إلى الشائعات",
    "rumours_owner": "الاستماع إلى صاحب المكان",
    "rumours_waitress": "الاستماع إلى النادلة",
    "rumours_listen": "الإصغاء جيدًا",
    "press_conference": "مؤتمر صحفي"
  },
  "pt-BR": {
    "hotel_basic": "Reservar um quarto",
    "hotel_standard": "Reservar um quarto de hotel",
    "rumours_tables": "Ouvir conversas nas mesas",
    "rumours_barman": "Ouvir o barman",
    "rumours_general": "Ouvir os boatos",
    "rumours_owner": "Ouvir o dono",
    "rumours_waitress": "Ouvir a garçonete",
    "rumours_listen": "Ficar de ouvidos atentos",
    "press_conference": "Coletiva de imprensa"
  },
  "de": {
    "hotel_basic": "Ein Zimmer buchen",
    "hotel_standard": "Ein Hotelzimmer buchen",
    "rumours_tables": "Gespräche an den Tischen belauschen",
    "rumours_barman": "Dem Barkeeper zuhören",
    "rumours_general": "Gerüchte anhören",
    "rumours_owner": "Dem Wirt zuhören",
    "rumours_waitress": "Der Kellnerin zuhören",
    "rumours_listen": "Die Ohren spitzen",
    "press_conference": "Pressekonferenz"
  }
};
 for(const [locale,labels] of Object.entries(variants)) {
  if(resources[locale]?.translation)
   resources[locale].translation.orderVariants={...labels};
 }
})(window);
