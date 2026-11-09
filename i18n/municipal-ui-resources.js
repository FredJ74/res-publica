/* Textes fixes des fenêtres communales, sans changement des ordres, coûts ni autorités. */
(function(global){
 'use strict';
 const catalog=global.RP_I18N_RESOURCES;
 if(!catalog)return;
 const words={
  "fr": {
    "civilStatusTitle": "État civil",
    "civilStatusEmpty": "Aucune démarche d'état civil disponible ici.",
    "comingSoon": "Bientôt disponible",
    "registerLoading": "Consultation du registre...",
    "manageApplications": "Gérer les candidatures reçues",
    "appointReplacement": "Nommer quelqu'un d'autre",
    "appointHolder": "Nommer un titulaire",
    "dismissHolder": "Révoquer le titulaire"
  },
  "en": {
    "civilStatusTitle": "Civil registry",
    "civilStatusEmpty": "No civil registry services are available here.",
    "comingSoon": "Coming soon",
    "registerLoading": "Checking the register...",
    "manageApplications": "Review applications received",
    "appointReplacement": "Appoint someone else",
    "appointHolder": "Appoint an officeholder",
    "dismissHolder": "Dismiss the officeholder"
  },
  "es": {
    "civilStatusTitle": "Registro civil",
    "civilStatusEmpty": "No hay trámites del registro civil disponibles aquí.",
    "comingSoon": "Próximamente",
    "registerLoading": "Consultando el registro...",
    "manageApplications": "Examinar las candidaturas recibidas",
    "appointReplacement": "Nombrar a otra persona",
    "appointHolder": "Nombrar a un titular",
    "dismissHolder": "Destituir al titular"
  },
  "zh-TW": {
    "civilStatusTitle": "民事登記",
    "civilStatusEmpty": "這裡目前沒有可辦理的民事登記業務。",
    "comingSoon": "即將推出",
    "registerLoading": "正在查詢登記冊……",
    "manageApplications": "審查收到的申請",
    "appointReplacement": "任命其他人",
    "appointHolder": "任命職位負責人",
    "dismissHolder": "解除現任者職務"
  },
  "ru": {
    "civilStatusTitle": "Отдел записи актов гражданского состояния",
    "civilStatusEmpty": "Здесь нет доступных услуг ЗАГС.",
    "comingSoon": "Скоро появится",
    "registerLoading": "Проверка реестра...",
    "manageApplications": "Рассмотреть поступившие заявления",
    "appointReplacement": "Назначить другого кандидата",
    "appointHolder": "Назначить должностное лицо",
    "dismissHolder": "Отстранить действующего руководителя"
  },
  "ko": {
    "civilStatusTitle": "민원·가족관계 등록",
    "civilStatusEmpty": "이곳에서 이용할 수 있는 가족관계 등록 업무가 없습니다.",
    "comingSoon": "추후 제공",
    "registerLoading": "명부 확인 중...",
    "manageApplications": "접수된 지원서 검토",
    "appointReplacement": "다른 사람 임명",
    "appointHolder": "직책 담당자 임명",
    "dismissHolder": "현직자 해임"
  },
  "ar": {
    "civilStatusTitle": "السجل المدني",
    "civilStatusEmpty": "لا تتوفر هنا أي معاملات للسجل المدني.",
    "comingSoon": "قريبًا",
    "registerLoading": "جارٍ مراجعة السجل...",
    "manageApplications": "مراجعة طلبات الترشيح الواردة",
    "appointReplacement": "تعيين شخص آخر",
    "appointHolder": "تعيين شاغل المنصب",
    "dismissHolder": "عزل شاغل المنصب"
  },
  "pt-BR": {
    "civilStatusTitle": "Registro civil",
    "civilStatusEmpty": "Não há serviços de registro civil disponíveis aqui.",
    "comingSoon": "Em breve",
    "registerLoading": "Consultando o registro...",
    "manageApplications": "Analisar candidaturas recebidas",
    "appointReplacement": "Nomear outra pessoa",
    "appointHolder": "Nomear um titular",
    "dismissHolder": "Destituir o titular"
  },
  "de": {
    "civilStatusTitle": "Standesamt",
    "civilStatusEmpty": "Hier sind keine standesamtlichen Vorgänge verfügbar.",
    "comingSoon": "Demnächst verfügbar",
    "registerLoading": "Register wird geprüft...",
    "manageApplications": "Eingegangene Bewerbungen prüfen",
    "appointReplacement": "Eine andere Person ernennen",
    "appointHolder": "Amtsinhaber ernennen",
    "dismissHolder": "Amtsinhaber abberufen"
  }
};
 for(const [locale,translations] of Object.entries(words))
   if(catalog[locale]?.translation) catalog[locale].translation.municipalUi={...translations};
 function label(key,original){
   if(global.RP_I18N_GAME_ENABLED!==true)return original;
   if(!Object.hasOwn(words.fr,key))return original;
   const lng=global.RPPlateauI18n?.language?.() || 'fr';
   if(lng==='fr')return original;
   const translated=catalog[lng]?.translation?.municipalUi?.[key];
   return typeof translated==='string'&&translated.trim()?translated:original;
 }
 function labelHtml(key,original){
   const value=label(key,original);
   return value===original?original:value.replace(/[&<>"']/g,c=>({
     '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'
   })[c]);
 }
 global.RPMunicipalI18n=Object.freeze({label,labelHtml});
})(window);
