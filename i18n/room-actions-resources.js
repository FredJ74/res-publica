/* Titres des actions et commandes d'audioguide : affichage uniquement.
 * Le lecteur audio, les coûts en PA, la source de la salle et les callbacks restent intacts.
 */
(function(global){
 'use strict';
 const resources=global.RP_I18N_RESOURCES;
 if(!resources)return;
 const texts={
  "fr": {
    "actionsAvailable": "ACTIONS DISPONIBLES",
    "audioTooltip": "Ecouter l'audioguide de cette salle",
    "audioAction": "Écouter l'audioguide",
    "audioCost": "gratuit · 0 PA",
    "caserneEngagement": "Engagement et affectation",
    "caserneService": "Service et distinctions",
    "caserneRecrutement": "Gestion des engagements",
    "caserneCommandement": "Commandement et effectifs",
    "caserneSection": "Ma section",
    "caserneBudget": "Budget et stratégie",
    "zeroPaTitle": "Attention : 0 PA",
    "zeroPaOrder": "« {label} » vous laissera à 0 PA : vous serez transféré(e) à l'hôpital et immobilisé(e) 2 à 3 jours. Continuer ?",
    "zeroPaGeneric": "Cet ordre vous laissera à 0 PA : vous serez transféré(e) à l'hôpital et immobilisé(e) 2 à 3 jours. Continuer ?",
    "zeroPaConfirm": "Confirmer",
    "zeroPaCancel": "Annuler"
  },
  "en": {
    "actionsAvailable": "AVAILABLE ACTIONS",
    "audioTooltip": "Listen to this room's audio guide",
    "audioAction": "Listen to the audio guide",
    "audioCost": "free · 0 PA",
    "caserneEngagement": "Enlistment and assignment",
    "caserneService": "Service and honours",
    "caserneRecrutement": "Enlistment administration",
    "caserneCommandement": "Command and personnel",
    "caserneSection": "My section",
    "caserneBudget": "Budget and strategy",
    "zeroPaTitle": "Warning: 0 PA",
    "zeroPaOrder": "“{label}” will leave you at 0 PA: you will be taken to hospital and laid up for 2 to 3 days. Continue?",
    "zeroPaGeneric": "This order will leave you at 0 PA: you will be taken to hospital and laid up for 2 to 3 days. Continue?",
    "zeroPaConfirm": "Confirm",
    "zeroPaCancel": "Cancel"
  },
  "es": {
    "actionsAvailable": "ACCIONES DISPONIBLES",
    "audioTooltip": "Escuchar la audioguía de esta sala",
    "audioAction": "Escuchar la audioguía",
    "audioCost": "gratis · 0 PA",
    "caserneEngagement": "Alistamiento y destino",
    "caserneService": "Servicio y condecoraciones",
    "caserneRecrutement": "Gestión de alistamientos",
    "caserneCommandement": "Mando y efectivos",
    "caserneSection": "Mi sección",
    "caserneBudget": "Presupuesto y estrategia",
    "zeroPaTitle": "Atención: 0 PA",
    "zeroPaOrder": "«{label}» le dejará con 0 PA: será trasladado(a) al hospital e inmovilizado(a) de 2 a 3 días. ¿Continuar?",
    "zeroPaGeneric": "Esta orden le dejará con 0 PA: será trasladado(a) al hospital e inmovilizado(a) de 2 a 3 días. ¿Continuar?",
    "zeroPaConfirm": "Confirmar",
    "zeroPaCancel": "Cancelar"
  },
  "zh-TW": {
    "actionsAvailable": "可執行的操作",
    "audioTooltip": "聆聽此展廳的語音導覽",
    "audioAction": "聆聽語音導覽",
    "audioCost": "免費 · 0 PA",
    "caserneEngagement": "入伍與分配",
    "caserneService": "服役與榮譽",
    "caserneRecrutement": "入伍管理",
    "caserneCommandement": "指揮與兵力",
    "caserneSection": "我的分隊",
    "caserneBudget": "預算與戰略",
    "zeroPaTitle": "注意：0 PA",
    "zeroPaOrder": "「{label}」會讓您剩下 0 PA：您將被送往醫院，並臥床 2 至 3 天。要繼續嗎？",
    "zeroPaGeneric": "此指令會讓您剩下 0 PA：您將被送往醫院，並臥床 2 至 3 天。要繼續嗎？",
    "zeroPaConfirm": "確認",
    "zeroPaCancel": "取消"
  },
  "ru": {
    "actionsAvailable": "ДОСТУПНЫЕ ДЕЙСТВИЯ",
    "audioTooltip": "Прослушать аудиогид по этому залу",
    "audioAction": "Прослушать аудиогид",
    "audioCost": "бесплатно · 0 PA",
    "caserneEngagement": "Призыв и назначение",
    "caserneService": "Служба и награды",
    "caserneRecrutement": "Управление набором",
    "caserneCommandement": "Командование и личный состав",
    "caserneSection": "Моё отделение",
    "caserneBudget": "Бюджет и стратегия",
    "zeroPaTitle": "Внимание: 0 PA",
    "zeroPaOrder": "«{label}» оставит вас с 0 PA: вас доставят в больницу, и вы будете прикованы к постели на 2–3 дня. Продолжить?",
    "zeroPaGeneric": "Это действие оставит вас с 0 PA: вас доставят в больницу, и вы будете прикованы к постели на 2–3 дня. Продолжить?",
    "zeroPaConfirm": "Подтвердить",
    "zeroPaCancel": "Отмена"
  },
  "ko": {
    "actionsAvailable": "이용 가능한 행동",
    "audioTooltip": "이 방의 오디오 가이드 듣기",
    "audioAction": "오디오 가이드 듣기",
    "audioCost": "무료 · 0 PA",
    "caserneEngagement": "입대 및 배치",
    "caserneService": "복무와 훈장",
    "caserneRecrutement": "입대 관리",
    "caserneCommandement": "지휘 및 병력",
    "caserneSection": "내 분대",
    "caserneBudget": "예산 및 전략",
    "zeroPaTitle": "주의: 0 PA",
    "zeroPaOrder": "「{label}」을(를) 실행하면 0 PA가 됩니다. 병원으로 이송되어 2~3일 동안 움직일 수 없습니다. 계속하시겠습니까?",
    "zeroPaGeneric": "이 명령을 실행하면 0 PA가 됩니다. 병원으로 이송되어 2~3일 동안 움직일 수 없습니다. 계속하시겠습니까?",
    "zeroPaConfirm": "확인",
    "zeroPaCancel": "취소"
  },
  "ar": {
    "actionsAvailable": "الإجراءات المتاحة",
    "audioTooltip": "الاستماع إلى الدليل الصوتي لهذه القاعة",
    "audioAction": "استمع إلى الدليل الصوتي",
    "audioCost": "مجانًا · 0 PA",
    "caserneEngagement": "التجنيد والتعيين",
    "caserneService": "الخدمة والأوسمة",
    "caserneRecrutement": "إدارة التجنيد",
    "caserneCommandement": "القيادة والأفراد",
    "caserneSection": "فصيلتي",
    "caserneBudget": "الميزانية والاستراتيجية",
    "zeroPaTitle": "تنبيه: 0 PA",
    "zeroPaOrder": "«{label}» سيتركك عند 0 PA: ستُنقل إلى المستشفى وتبقى طريح الفراش لمدة 2 إلى 3 أيام. هل تريد المتابعة؟",
    "zeroPaGeneric": "هذا الأمر سيتركك عند 0 PA: ستُنقل إلى المستشفى وتبقى طريح الفراش لمدة 2 إلى 3 أيام. هل تريد المتابعة؟",
    "zeroPaConfirm": "تأكيد",
    "zeroPaCancel": "إلغاء"
  },
  "pt-BR": {
    "actionsAvailable": "AÇÕES DISPONÍVEIS",
    "audioTooltip": "Ouvir o audioguia desta sala",
    "audioAction": "Ouvir audioguia",
    "audioCost": "grátis · 0 PA",
    "caserneEngagement": "Alistamento e lotação",
    "caserneService": "Serviço e condecorações",
    "caserneRecrutement": "Gestão dos alistamentos",
    "caserneCommandement": "Comando e efetivos",
    "caserneSection": "Minha seção",
    "caserneBudget": "Orçamento e estratégia",
    "zeroPaTitle": "Atenção: 0 PA",
    "zeroPaOrder": "«{label}» vai deixar você com 0 PA: você será levado(a) ao hospital e ficará imobilizado(a) de 2 a 3 dias. Continuar?",
    "zeroPaGeneric": "Esta ordem vai deixar você com 0 PA: você será levado(a) ao hospital e ficará imobilizado(a) de 2 a 3 dias. Continuar?",
    "zeroPaConfirm": "Confirmar",
    "zeroPaCancel": "Cancelar"
  },
  "de": {
    "actionsAvailable": "VERFÜGBARE AKTIONEN",
    "audioTooltip": "Audioguide für diesen Raum anhören",
    "audioAction": "Audioguide anhören",
    "audioCost": "kostenlos · 0 PA",
    "caserneEngagement": "Einberufung und Zuteilung",
    "caserneService": "Dienst und Auszeichnungen",
    "caserneRecrutement": "Verwaltung der Einberufungen",
    "caserneCommandement": "Führung und Personal",
    "caserneSection": "Mein Zug",
    "caserneBudget": "Haushalt und Strategie",
    "zeroPaTitle": "Achtung: 0 PA",
    "zeroPaOrder": "„{label}“ lässt Sie bei 0 PA: Sie werden ins Krankenhaus gebracht und sind 2 bis 3 Tage außer Gefecht. Fortfahren?",
    "zeroPaGeneric": "Dieser Befehl lässt Sie bei 0 PA: Sie werden ins Krankenhaus gebracht und sind 2 bis 3 Tage außer Gefecht. Fortfahren?",
    "zeroPaConfirm": "Bestätigen",
    "zeroPaCancel": "Abbrechen"
  }
};
 for(const [locale,words] of Object.entries(texts))
  if(resources[locale]?.translation)resources[locale].translation.roomActions={...words};
 function label(key,original){
  if(typeof original!=='string'||!Object.hasOwn(texts.fr,key)||texts.fr[key]!==original)return original;
  if(global.RP_I18N_GAME_ENABLED!==true)return original;
  const locale=global.RPPlateauI18n?.language?.()||'fr';
  const translated=resources[locale]?.translation?.roomActions?.[key];
  return typeof translated==='string'&&translated.trim()?translated:original;
 }
 function labelHtml(key,original){
  return label(key,original).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 }
 global.RPRoomActionsI18n=Object.freeze({label,labelHtml});
})(window);
