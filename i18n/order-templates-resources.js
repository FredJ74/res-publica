/* Modèles d'affichage des tarifs de loyers et des terrains.
 * Les nombres et monnaies proviennent du label original, jamais calculés ici.
 * Aucun ordre métier, prix ou droit ne dépend de ce catalogue.
 */
(function(global){
 'use strict';
 const resources=global.RP_I18N_RESOURCES;
 if(!resources)return;
 const templates={
  "fr": {
    "rental_local": "Louer ce local ({{price}} {{currency}}/jour)",
    "rental_suite": "Louer cette suite ({{price}} {{currency}}/jour)",
    "rental_safe": "Louer ce coffre ({{price}} {{currency}}/jour)",
    "rental_apartment": "Louer cet appartement ({{price}} {{currency}}/jour)",
    "buy_plot": "Acheter ce terrain ({{area}} m² — {{price}} FR)",
    "buy_plot_plain": "Acheter ce terrain",
    "sovarka_meeting_today": "Réserver pour aujourd’hui — {{price}} PSK"
  },
  "en": {
    "rental_local": "Rent these premises ({{price}} {{currency}}/day)",
    "rental_suite": "Rent this suite ({{price}} {{currency}}/day)",
    "rental_safe": "Rent this safe-deposit box ({{price}} {{currency}}/day)",
    "rental_apartment": "Rent this apartment ({{price}} {{currency}}/day)",
    "buy_plot": "Buy this plot ({{area}} m² — {{price}} FR)",
    "buy_plot_plain": "Buy this plot",
    "sovarka_meeting_today": "Reserve for today — {{price}} PSK"
  },
  "es": {
    "rental_local": "Alquilar este local ({{price}} {{currency}}/día)",
    "rental_suite": "Alquilar esta suite ({{price}} {{currency}}/día)",
    "rental_safe": "Alquilar esta caja de seguridad ({{price}} {{currency}}/día)",
    "rental_apartment": "Alquilar este apartamento ({{price}} {{currency}}/día)",
    "buy_plot": "Comprar este terreno ({{area}} m² — {{price}} FR)",
    "buy_plot_plain": "Comprar este terreno",
    "sovarka_meeting_today": "Reservar para hoy — {{price}} PSK"
  },
  "zh-TW": {
    "rental_local": "租用此營業場所（{{price}} {{currency}}／天）",
    "rental_suite": "租用此套房（{{price}} {{currency}}／天）",
    "rental_safe": "租用此保管箱（{{price}} {{currency}}／天）",
    "rental_apartment": "租用此公寓（{{price}} {{currency}}／天）",
    "buy_plot": "購買此地塊（{{area}} m² — {{price}} FR）",
    "buy_plot_plain": "購買此地塊",
    "sovarka_meeting_today": "預訂今天的場地 — {{price}} PSK"
  },
  "ru": {
    "rental_local": "Арендовать помещение ({{price}} {{currency}}/день)",
    "rental_suite": "Арендовать люкс ({{price}} {{currency}}/день)",
    "rental_safe": "Арендовать сейф ({{price}} {{currency}}/день)",
    "rental_apartment": "Арендовать квартиру ({{price}} {{currency}}/день)",
    "buy_plot": "Купить участок ({{area}} м² — {{price}} FR)",
    "buy_plot_plain": "Купить участок",
    "sovarka_meeting_today": "Забронировать на сегодня — {{price}} PSK"
  },
  "ko": {
    "rental_local": "이 점포 임대 ({{price}} {{currency}}/일)",
    "rental_suite": "이 스위트룸 임대 ({{price}} {{currency}}/일)",
    "rental_safe": "이 보관함 임대 ({{price}} {{currency}}/일)",
    "rental_apartment": "이 아파트 임대 ({{price}} {{currency}}/일)",
    "buy_plot": "이 토지 구매 ({{area}} m² — {{price}} FR)",
    "buy_plot_plain": "이 토지 구매",
    "sovarka_meeting_today": "오늘 예약 — {{price}} PSK"
  },
  "ar": {
    "rental_local": "استئجار هذا المحل ({{price}} {{currency}}/يوم)",
    "rental_suite": "استئجار هذا الجناح ({{price}} {{currency}}/يوم)",
    "rental_safe": "استئجار صندوق الأمانات ({{price}} {{currency}}/يوم)",
    "rental_apartment": "استئجار هذه الشقة ({{price}} {{currency}}/يوم)",
    "buy_plot": "شراء هذه الأرض ({{area}} م² — {{price}} FR)",
    "buy_plot_plain": "شراء هذه الأرض",
    "sovarka_meeting_today": "الحجز لليوم — {{price}} PSK"
  },
  "pt-BR": {
    "rental_local": "Alugar este estabelecimento ({{price}} {{currency}}/dia)",
    "rental_suite": "Alugar esta suíte ({{price}} {{currency}}/dia)",
    "rental_safe": "Alugar este cofre ({{price}} {{currency}}/dia)",
    "rental_apartment": "Alugar este apartamento ({{price}} {{currency}}/dia)",
    "buy_plot": "Comprar este terreno ({{area}} m² — {{price}} FR)",
    "buy_plot_plain": "Comprar este terreno",
    "sovarka_meeting_today": "Reservar para hoje — {{price}} PSK"
  },
  "de": {
    "rental_local": "Dieses Geschäftslokal mieten ({{price}} {{currency}}/Tag)",
    "rental_suite": "Diese Suite mieten ({{price}} {{currency}}/Tag)",
    "rental_safe": "Dieses Schließfach mieten ({{price}} {{currency}}/Tag)",
    "rental_apartment": "Diese Wohnung mieten ({{price}} {{currency}}/Tag)",
    "buy_plot": "Dieses Grundstück kaufen ({{area}} m² — {{price}} FR)",
    "buy_plot_plain": "Dieses Grundstück kaufen",
    "sovarka_meeting_today": "Für heute reservieren — {{price}} PSK"
  }
};
 for(const [locale,labels] of Object.entries(templates)){
  if(resources[locale]?.translation) resources[locale].translation.orderTemplates={...labels};
 }
})(window);
