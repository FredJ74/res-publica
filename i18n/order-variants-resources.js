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
    "hotel_standard": "Réserver une chambre d'hôtel"
  },
  "en": {
    "hotel_basic": "Reserve a room",
    "hotel_standard": "Reserve a hotel room"
  },
  "es": {
    "hotel_basic": "Reservar una habitación",
    "hotel_standard": "Reservar una habitación de hotel"
  },
  "zh-TW": {
    "hotel_basic": "預訂房間",
    "hotel_standard": "預訂飯店房間"
  },
  "ru": {
    "hotel_basic": "Забронировать номер",
    "hotel_standard": "Забронировать номер в гостинице"
  },
  "ko": {
    "hotel_basic": "객실 예약",
    "hotel_standard": "호텔 객실 예약"
  },
  "ar": {
    "hotel_basic": "حجز غرفة",
    "hotel_standard": "حجز غرفة فندقية"
  },
  "pt-BR": {
    "hotel_basic": "Reservar um quarto",
    "hotel_standard": "Reservar um quarto de hotel"
  },
  "de": {
    "hotel_basic": "Ein Zimmer buchen",
    "hotel_standard": "Ein Hotelzimmer buchen"
  }
};
 for(const [locale,labels] of Object.entries(variants)) {
  if(resources[locale]?.translation)
   resources[locale].translation.orderVariants={...labels};
 }
})(window);
