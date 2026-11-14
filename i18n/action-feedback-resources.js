/* Refus communs : présentation seule, moteur i18next et notifications existants. */
(function(global){
 'use strict';
 const locales=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
 const rows=[
  [
    "postNamed",
    "Cette action est réservée à : {{values.post}}.",
    "This action is reserved for: {{values.post}}.",
    "Esta acción está reservada a: {{values.post}}.",
    "此行動僅限以下職位：{{values.post}}。",
    "Это действие доступно только для должности: {{values.post}}.",
    "이 행동은 다음 직위 전용입니다: {{values.post}}.",
    "هذا الإجراء مقصور على: {{values.post}}.",
    "Esta ação é reservada a: {{values.post}}.",
    "Diese Aktion ist vorbehalten für: {{values.post}}."
  ],
  [
    "fundsRequired",
    "{{values.required}} {{values.currency}} requis — vous disposez de {{values.available}} {{values.currency}}.",
    "{{values.required}} {{values.currency}} required — you have {{values.available}} {{values.currency}}.",
    "Se requieren {{values.required}} {{values.currency}} — dispones de {{values.available}} {{values.currency}}.",
    "需要 {{values.required}} {{values.currency}}——你持有 {{values.available}} {{values.currency}}。",
    "Требуется {{values.required}} {{values.currency}} — у вас {{values.available}} {{values.currency}}.",
    "{{values.required}} {{values.currency}} 필요 — 보유 금액은 {{values.available}} {{values.currency}}입니다.",
    "المطلوب {{values.required}} {{values.currency}} — لديك {{values.available}} {{values.currency}}.",
    "São necessários {{values.required}} {{values.currency}} — você tem {{values.available}} {{values.currency}}.",
    "{{values.required}} {{values.currency}} erforderlich — du hast {{values.available}} {{values.currency}}."
  ],
  [
    "cashboxRequired",
    "Cette action est financée par une caisse institutionnelle, qui ne couvre pas les {{values.required}} {{values.currency}} nécessaires.",
    "This action is funded by an institutional treasury that cannot cover the required {{values.required}} {{values.currency}}.",
    "Esta acción se financia con una caja institucional que no puede cubrir los {{values.required}} {{values.currency}} necesarios.",
    "此行動由機構金庫出資，但金庫不足以支付所需的 {{values.required}} {{values.currency}}。",
    "Это действие финансируется из кассы учреждения, в которой недостаточно средств для необходимых {{values.required}} {{values.currency}}.",
    "이 행동은 기관 금고에서 비용을 부담하지만, 필요한 {{values.required}} {{values.currency}}을(를) 충당할 수 없습니다.",
    "يُموَّل هذا الإجراء من خزينة مؤسسة لا تغطي المبلغ المطلوب وقدره {{values.required}} {{values.currency}}.",
    "Esta ação é financiada por um caixa institucional que não cobre os {{values.required}} {{values.currency}} necessários.",
    "Diese Aktion wird aus einer Institutionskasse finanziert, die die erforderlichen {{values.required}} {{values.currency}} nicht decken kann."
  ],
  [
    "actionNotRecorded",
    "Le serveur n'a pas pu enregistrer cette action : rien ne vous a été prélevé. Réessayez dans un instant ; si cela persiste, rechargez la page.",
    "The server could not record this action: nothing has been charged to you. Try again shortly; if this persists, reload the page.",
    "El servidor no ha podido registrar esta acción: no se te ha cobrado nada. Vuelve a intentarlo en un momento; si el problema persiste, recarga la página.",
    "伺服器無法記錄此行動：你未被扣除任何款項。請稍後再試；若情況持續，請重新載入頁面。",
    "Сервер не смог записать это действие: с вас ничего не списано. Повторите попытку через некоторое время; если проблема сохраняется, перезагрузите страницу.",
    "서버에서 이 행동을 기록하지 못해 아무것도 차감되지 않았습니다. 잠시 후 다시 시도하고, 문제가 계속되면 페이지를 새로고침하세요.",
    "لم يتمكن الخادم من تسجيل هذا الإجراء: لم يُخصم منك شيء. حاول مجددًا بعد قليل؛ وإذا استمر الأمر، فأعد تحميل الصفحة.",
    "O servidor não conseguiu registrar esta ação: nada foi debitado de você. Tente novamente daqui a pouco; se o problema persistir, recarregue a página.",
    "Der Server konnte diese Aktion nicht speichern: Dir wurde nichts abgezogen. Versuche es gleich noch einmal; wenn das Problem bleibt, lade die Seite neu."
  ],
  [
    "apRequired",
    "{{values.required}} PA requis — il vous en reste {{values.available}}.",
    "{{values.required}} AP required — you have {{values.available}} left.",
    "Se requieren {{values.required}} PA — te quedan {{values.available}}.",
    "需要 {{values.required}} 點行動點數——你還剩 {{values.available}} 點。",
    "Требуется {{values.required}} ОД — у вас осталось {{values.available}}.",
    "행동 점수 {{values.required}}점 필요 — {{values.available}}점 남았습니다.",
    "المطلوب {{values.required}} من نقاط العمل — تبقى لديك {{values.available}}.",
    "São necessários {{values.required}} PA — você tem {{values.available}} restantes.",
    "{{values.required}} AP erforderlich — du hast noch {{values.available}}."
  ],
  [
    "titleReserved",
    "Action réservée",
    "Restricted action",
    "Acción reservada",
    "專屬行動",
    "Действие ограничено",
    "직위 전용 행동",
    "إجراء مقيّد",
    "Ação reservada",
    "Aktion vorbehalten"
  ]
];
 for(const [index,lang]of locales.entries())if(global.RP_I18N_RESOURCES?.[lang]?.translation)
  global.RP_I18N_RESOURCES[lang].translation.actionFeedback=Object.fromEntries(rows.map(row=>[row[0],row[index+1]]));
 global.RPToastI18n?.registerTitle?.('Action réservée','actionFeedback.titleReserved');
})(window);
