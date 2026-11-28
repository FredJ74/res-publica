// =====================
// PLATEAU-PAIEMENT.JS
// Paiement par Stripe en fonctionnement mixte (décision de Fred, 28/11/2026 ; serveur : api/_paiement.js, migration
// 20261128120000). Avant tout achat : le vendeur (l'éditeur, ou Stripe hors UE), le prix rendu par la base, la case CGV et,
// pour l'unité ou une option, la case NON pré-cochée de renonciation au droit de rétractation. Fiche du compte (onglet
// Identité) : état de l'abonnement, « Résilier mon abonnement » en deux clics (effet à la fin de la période payée) et
// remboursement dans les 14 jours si aucun avantage n'a été utilisé. Le serveur décide de tout ; aucun prix n'est écrit ici.
// Textes dans les 9 langues du jeu.
// =====================
(function () {
  'use strict';

  const T = {
    fr: {
      titre: 'Paiement', prix: 'Prix : {prix}', vendeurEditeur: 'Vendeur : {nom}.', tva: 'TVA non applicable, article 293 B du CGI.',
      vendeurStripe: 'Vendeur : Stripe (Link), vendeur officiel de cette vente ; il gère le paiement, les taxes, la facture et l’assistance.',
      cgv: 'J’ai lu et j’accepte les conditions générales de vente.', cgvLien: 'Lire les conditions générales de vente',
      renonciation: 'Je demande la livraison immédiate et je renonce à mon droit de rétractation.',
      aboInfo: 'Abonnement {periode}, renouvelé automatiquement. Résiliable à tout moment depuis la fiche de votre compte (onglet Identité), avec effet à la fin de la période payée. Remboursement intégral sur demande dans les 14 jours suivant le premier paiement si aucun avantage n’a été utilisé.',
      periodeMois: 'mensuel', periodeAn: 'annuel', payer: 'Payer {prix}', annuler: 'Annuler', ouverture: 'Ouverture du paiement sécurisé…',
      retourOk: 'Paiement reçu : votre achat est activé dès que Stripe le confirme (quelques secondes).', retourAnnule: 'Paiement annulé : rien n’a été débité.',
      compteTitre: 'ABONNEMENT', aboActif: 'Abonnement {periode} actif jusqu’au {date}, renouvelé automatiquement.',
      aboResilie: 'Abonnement {periode} résilié : il reste actif jusqu’au {date}, sans renouvellement.',
      resilier: 'Résilier mon abonnement', resilierQuestion: 'L’abonnement restera actif jusqu’au {date}, puis ne sera pas renouvelé. Ce que vous avez activé reste acquis.',
      resilierConfirmer: 'Confirmer la résiliation', resilieOk: 'Résiliation enregistrée : votre abonnement reste actif jusqu’au {date}.',
      rembourser: 'Demander le remboursement (jusqu’au {date})', rembourserQuestion: 'L’abonnement prend fin immédiatement et le paiement vous est remboursé intégralement.',
      rembourserConfirmer: 'Confirmer le remboursement', rembourseOk: 'Remboursement demandé : votre abonnement a pris fin.',
      m: { pays_non_servi: 'Les achats ne sont pas disponibles depuis votre pays. Le jeu reste entièrement gratuit.',
           vente_hors_ue_fermee: 'Les achats ne sont pas encore ouverts dans votre pays. Le jeu reste entièrement gratuit.',
           pays_inconnu: 'Votre pays n’a pas pu être déterminé : achat impossible pour le moment.', paiement_inactif: 'Le paiement n’est pas encore ouvert.',
           cgv_requises: 'Veuillez accepter les conditions générales de vente.', renonciation_requise: 'Veuillez cocher la demande de livraison immédiate.',
           deja_abonne: 'Vous êtes déjà abonné.', option_deja_acquise: 'Option déjà acquise.', prix_non_fixe: 'Prix pas encore fixé.',
           inclus_pendant_la_beta: 'Inclus pendant la bêta.', deja_resilie: 'Abonnement déjà résilié.',
           avantage_utilise: 'Un avantage de l’abonnement a déjà été utilisé : remboursement impossible.', delai_depasse: 'Le délai de 14 jours est dépassé.',
           aucun_abonnement: 'Aucun abonnement en cours.', fournisseur_indisponible: 'Le service de paiement ne répond pas. Réessayez.', indispo: 'Le serveur ne répond pas. Réessayez.' }
    },
    en: {
      titre: 'Payment', prix: 'Price: {prix}', vendeurEditeur: 'Seller: {nom}.', tva: 'VAT not applicable, article 293 B of the French General Tax Code.',
      vendeurStripe: 'Seller: Stripe (Link), merchant of record for this sale; it handles payment, taxes, invoice and support.',
      cgv: 'I have read and accept the terms and conditions of sale.', cgvLien: 'Read the terms and conditions of sale',
      renonciation: 'I request immediate delivery and waive my right of withdrawal.',
      aboInfo: '{periode} subscription, renewed automatically. Cancel at any time from your account sheet (Identity tab), effective at the end of the paid period. Full refund on request within 14 days of the first payment if no benefit has been used.',
      periodeMois: 'Monthly', periodeAn: 'Yearly', payer: 'Pay {prix}', annuler: 'Cancel', ouverture: 'Opening secure payment…',
      retourOk: 'Payment received: your purchase is activated as soon as Stripe confirms it (a few seconds).', retourAnnule: 'Payment cancelled: nothing was charged.',
      compteTitre: 'SUBSCRIPTION', aboActif: '{periode} subscription active until {date}, renewed automatically.',
      aboResilie: '{periode} subscription cancelled: it stays active until {date}, with no renewal.',
      resilier: 'Cancel my subscription', resilierQuestion: 'The subscription stays active until {date} and will not renew. What you have activated stays yours.',
      resilierConfirmer: 'Confirm cancellation', resilieOk: 'Cancellation recorded: your subscription stays active until {date}.',
      rembourser: 'Ask for a refund (until {date})', rembourserQuestion: 'The subscription ends now and the payment is refunded in full.',
      rembourserConfirmer: 'Confirm refund', rembourseOk: 'Refund requested: your subscription has ended.',
      m: { pays_non_servi: 'Purchases are not available from your country. The game stays entirely free.',
           vente_hors_ue_fermee: 'Purchases are not open in your country yet. The game stays entirely free.',
           pays_inconnu: 'Your country could not be determined: no purchase for now.', paiement_inactif: 'Payment is not open yet.',
           cgv_requises: 'Please accept the terms and conditions of sale.', renonciation_requise: 'Please tick the request for immediate delivery.',
           deja_abonne: 'You are already subscribed.', option_deja_acquise: 'Option already owned.', prix_non_fixe: 'Price not set yet.',
           inclus_pendant_la_beta: 'Included during the beta.', deja_resilie: 'Subscription already cancelled.',
           avantage_utilise: 'A subscription benefit has already been used: no refund possible.', delai_depasse: 'The 14-day period has passed.',
           aucun_abonnement: 'No active subscription.', fournisseur_indisponible: 'The payment service is not responding. Try again.', indispo: 'The server is not responding. Try again.' }
    },
    es: {
      titre: 'Pago', prix: 'Precio: {prix}', vendeurEditeur: 'Vendedor: {nom}.', tva: 'IVA no aplicable, artículo 293 B del Código General de Impuestos francés.',
      vendeurStripe: 'Vendedor: Stripe (Link), vendedor oficial de esta venta; gestiona el pago, los impuestos, la factura y la asistencia.',
      cgv: 'He leído y acepto las condiciones generales de venta.', cgvLien: 'Leer las condiciones generales de venta',
      renonciation: 'Solicito la entrega inmediata y renuncio a mi derecho de desistimiento.',
      aboInfo: 'Suscripción {periode}, renovada automáticamente. Cancelable en cualquier momento desde la ficha de su cuenta (pestaña Identidad), con efecto al final del periodo pagado. Reembolso íntegro a petición en los 14 días siguientes al primer pago si no se ha usado ninguna ventaja.',
      periodeMois: 'mensual', periodeAn: 'anual', payer: 'Pagar {prix}', annuler: 'Cancelar', ouverture: 'Abriendo el pago seguro…',
      retourOk: 'Pago recibido: su compra se activa en cuanto Stripe la confirme (unos segundos).', retourAnnule: 'Pago cancelado: no se ha cobrado nada.',
      compteTitre: 'SUSCRIPCIÓN', aboActif: 'Suscripción {periode} activa hasta el {date}, renovada automáticamente.',
      aboResilie: 'Suscripción {periode} cancelada: sigue activa hasta el {date}, sin renovación.',
      resilier: 'Cancelar mi suscripción', resilierQuestion: 'La suscripción seguirá activa hasta el {date} y no se renovará. Lo que haya activado sigue siendo suyo.',
      resilierConfirmer: 'Confirmar la cancelación', resilieOk: 'Cancelación registrada: su suscripción sigue activa hasta el {date}.',
      rembourser: 'Pedir el reembolso (hasta el {date})', rembourserQuestion: 'La suscripción termina ahora y el pago se le reembolsa íntegramente.',
      rembourserConfirmer: 'Confirmar el reembolso', rembourseOk: 'Reembolso solicitado: su suscripción ha terminado.',
      m: { pays_non_servi: 'Las compras no están disponibles desde su país. El juego sigue siendo totalmente gratuito.',
           vente_hors_ue_fermee: 'Las compras aún no están abiertas en su país. El juego sigue siendo totalmente gratuito.',
           pays_inconnu: 'No se ha podido determinar su país: compra imposible por ahora.', paiement_inactif: 'El pago aún no está abierto.',
           cgv_requises: 'Acepte las condiciones generales de venta.', renonciation_requise: 'Marque la solicitud de entrega inmediata.',
           deja_abonne: 'Ya está suscrito.', option_deja_acquise: 'Opción ya adquirida.', prix_non_fixe: 'Precio aún no fijado.',
           inclus_pendant_la_beta: 'Incluido durante la beta.', deja_resilie: 'Suscripción ya cancelada.',
           avantage_utilise: 'Ya se ha usado una ventaja de la suscripción: reembolso imposible.', delai_depasse: 'El plazo de 14 días ha pasado.',
           aucun_abonnement: 'Ninguna suscripción en curso.', fournisseur_indisponible: 'El servicio de pago no responde. Inténtelo de nuevo.', indispo: 'El servidor no responde. Inténtelo de nuevo.' }
    },
    de: {
      titre: 'Zahlung', prix: 'Preis: {prix}', vendeurEditeur: 'Verkäufer: {nom}.', tva: 'Keine Mehrwertsteuer gemäß Artikel 293 B des französischen Steuergesetzbuchs (CGI).',
      vendeurStripe: 'Verkäufer: Stripe (Link), offizieller Verkäufer dieses Kaufs; zuständig für Zahlung, Steuern, Rechnung und Support.',
      cgv: 'Ich habe die Allgemeinen Verkaufsbedingungen gelesen und akzeptiere sie.', cgvLien: 'Allgemeine Verkaufsbedingungen lesen',
      renonciation: 'Ich verlange die sofortige Lieferung und verzichte auf mein Widerrufsrecht.',
      aboInfo: '{periode} Abonnement, automatisch verlängert. Jederzeit im Kontoblatt (Reiter Identität) kündbar, wirksam zum Ende des bezahlten Zeitraums. Volle Erstattung auf Anfrage innerhalb von 14 Tagen nach der ersten Zahlung, wenn kein Vorteil genutzt wurde.',
      periodeMois: 'Monatliches', periodeAn: 'Jährliches', payer: '{prix} bezahlen', annuler: 'Abbrechen', ouverture: 'Sichere Zahlung wird geöffnet…',
      retourOk: 'Zahlung erhalten: Ihr Kauf wird aktiviert, sobald Stripe ihn bestätigt (wenige Sekunden).', retourAnnule: 'Zahlung abgebrochen: Es wurde nichts abgebucht.',
      compteTitre: 'ABONNEMENT', aboActif: '{periode} Abonnement aktiv bis {date}, automatisch verlängert.',
      aboResilie: '{periode} Abonnement gekündigt: Es bleibt bis {date} aktiv, ohne Verlängerung.',
      resilier: 'Mein Abonnement kündigen', resilierQuestion: 'Das Abonnement bleibt bis {date} aktiv und wird nicht verlängert. Was Sie aktiviert haben, bleibt Ihnen.',
      resilierConfirmer: 'Kündigung bestätigen', resilieOk: 'Kündigung erfasst: Ihr Abonnement bleibt bis {date} aktiv.',
      rembourser: 'Erstattung beantragen (bis {date})', rembourserQuestion: 'Das Abonnement endet sofort und die Zahlung wird vollständig erstattet.',
      rembourserConfirmer: 'Erstattung bestätigen', rembourseOk: 'Erstattung beantragt: Ihr Abonnement ist beendet.',
      m: { pays_non_servi: 'Käufe sind aus Ihrem Land nicht möglich. Das Spiel bleibt vollständig kostenlos.',
           vente_hors_ue_fermee: 'Käufe sind in Ihrem Land noch nicht geöffnet. Das Spiel bleibt vollständig kostenlos.',
           pays_inconnu: 'Ihr Land konnte nicht ermittelt werden: Kauf derzeit nicht möglich.', paiement_inactif: 'Die Zahlung ist noch nicht geöffnet.',
           cgv_requises: 'Bitte akzeptieren Sie die Allgemeinen Verkaufsbedingungen.', renonciation_requise: 'Bitte kreuzen Sie die sofortige Lieferung an.',
           deja_abonne: 'Sie sind bereits Abonnent.', option_deja_acquise: 'Option bereits erworben.', prix_non_fixe: 'Preis noch nicht festgelegt.',
           inclus_pendant_la_beta: 'In der Beta enthalten.', deja_resilie: 'Abonnement bereits gekündigt.',
           avantage_utilise: 'Ein Vorteil des Abonnements wurde bereits genutzt: keine Erstattung möglich.', delai_depasse: 'Die 14-Tage-Frist ist abgelaufen.',
           aucun_abonnement: 'Kein laufendes Abonnement.', fournisseur_indisponible: 'Der Zahlungsdienst antwortet nicht. Bitte erneut versuchen.', indispo: 'Der Server antwortet nicht. Bitte erneut versuchen.' }
    },
    ru: {
      titre: 'Оплата', prix: 'Цена: {prix}', vendeurEditeur: 'Продавец: {nom}.', tva: 'НДС не применяется, статья 293 B Общего налогового кодекса Франции.',
      vendeurStripe: 'Продавец: Stripe (Link), официальный продавец по этой покупке; отвечает за оплату, налоги, счёт и поддержку.',
      cgv: 'Я прочитал(а) и принимаю общие условия продажи.', cgvLien: 'Прочитать общие условия продажи',
      renonciation: 'Я прошу немедленную поставку и отказываюсь от права на отказ от покупки.',
      aboInfo: 'Подписка ({periode}), продлевается автоматически. Отменить можно в любой момент в карточке аккаунта (вкладка «Личность»), отмена вступает в силу в конце оплаченного периода. Полный возврат по запросу в течение 14 дней после первого платежа, если ни одно преимущество не использовано.',
      periodeMois: 'ежемесячная', periodeAn: 'годовая', payer: 'Оплатить {prix}', annuler: 'Отмена', ouverture: 'Открываем защищённую оплату…',
      retourOk: 'Платёж получен: покупка активируется, как только Stripe её подтвердит (несколько секунд).', retourAnnule: 'Оплата отменена: ничего не списано.',
      compteTitre: 'ПОДПИСКА', aboActif: 'Подписка ({periode}) активна до {date}, продлевается автоматически.',
      aboResilie: 'Подписка ({periode}) отменена: она активна до {date}, без продления.',
      resilier: 'Отменить подписку', resilierQuestion: 'Подписка останется активной до {date} и не будет продлена. Всё активированное останется за вами.',
      resilierConfirmer: 'Подтвердить отмену', resilieOk: 'Отмена записана: подписка активна до {date}.',
      rembourser: 'Запросить возврат (до {date})', rembourserQuestion: 'Подписка заканчивается сейчас, платёж возвращается полностью.',
      rembourserConfirmer: 'Подтвердить возврат', rembourseOk: 'Возврат запрошен: подписка завершена.',
      m: { pays_non_servi: 'Покупки недоступны из вашей страны. Игра остаётся полностью бесплатной.',
           vente_hors_ue_fermee: 'Покупки в вашей стране пока не открыты. Игра остаётся полностью бесплатной.',
           pays_inconnu: 'Не удалось определить вашу страну: покупка пока невозможна.', paiement_inactif: 'Оплата пока не открыта.',
           cgv_requises: 'Примите общие условия продажи.', renonciation_requise: 'Отметьте запрос на немедленную поставку.',
           deja_abonne: 'У вас уже есть подписка.', option_deja_acquise: 'Опция уже приобретена.', prix_non_fixe: 'Цена ещё не установлена.',
           inclus_pendant_la_beta: 'Включено на время беты.', deja_resilie: 'Подписка уже отменена.',
           avantage_utilise: 'Преимущество подписки уже использовано: возврат невозможен.', delai_depasse: 'Срок в 14 дней истёк.',
           aucun_abonnement: 'Нет активной подписки.', fournisseur_indisponible: 'Платёжный сервис не отвечает. Повторите попытку.', indispo: 'Сервер не отвечает. Повторите попытку.' }
    },
    ko: {
      titre: '결제', prix: '가격: {prix}', vendeurEditeur: '판매자: {nom}.', tva: '부가가치세 비적용, 프랑스 조세일반법 제293 B조.',
      vendeurStripe: '판매자: 이 판매의 공식 판매자인 Stripe(Link). 결제, 세금, 영수증, 고객 지원을 담당합니다.',
      cgv: '판매 약관을 읽었으며 이에 동의합니다.', cgvLien: '판매 약관 읽기',
      renonciation: '즉시 제공을 요청하며 청약철회권을 포기합니다.',
      aboInfo: '{periode} 구독, 자동 갱신. 계정 시트(신원 탭)에서 언제든지 해지할 수 있으며 결제된 기간이 끝날 때 적용됩니다. 혜택을 사용하지 않았다면 첫 결제 후 14일 이내 요청 시 전액 환불됩니다.',
      periodeMois: '월간', periodeAn: '연간', payer: '{prix} 결제', annuler: '취소', ouverture: '보안 결제를 여는 중…',
      retourOk: '결제 완료: Stripe가 확인하는 즉시(몇 초) 구매가 활성화됩니다.', retourAnnule: '결제 취소: 청구된 금액이 없습니다.',
      compteTitre: '구독', aboActif: '{periode} 구독이 {date}까지 활성 상태이며 자동 갱신됩니다.',
      aboResilie: '{periode} 구독 해지됨: {date}까지 활성 상태이며 갱신되지 않습니다.',
      resilier: '구독 해지', resilierQuestion: '구독은 {date}까지 유지되고 갱신되지 않습니다. 활성화한 것은 계속 유지됩니다.',
      resilierConfirmer: '해지 확인', resilieOk: '해지 완료: 구독은 {date}까지 유지됩니다.',
      rembourser: '환불 요청({date}까지)', rembourserQuestion: '구독이 즉시 종료되고 결제 금액이 전액 환불됩니다.',
      rembourserConfirmer: '환불 확인', rembourseOk: '환불 요청 완료: 구독이 종료되었습니다.',
      m: { pays_non_servi: '귀하의 국가에서는 구매할 수 없습니다. 게임은 계속 완전히 무료입니다.',
           vente_hors_ue_fermee: '귀하의 국가에서는 아직 구매가 열리지 않았습니다. 게임은 계속 완전히 무료입니다.',
           pays_inconnu: '국가를 확인할 수 없어 지금은 구매할 수 없습니다.', paiement_inactif: '결제가 아직 열리지 않았습니다.',
           cgv_requises: '판매 약관에 동의해 주세요.', renonciation_requise: '즉시 제공 요청에 체크해 주세요.',
           deja_abonne: '이미 구독 중입니다.', option_deja_acquise: '이미 보유한 옵션입니다.', prix_non_fixe: '가격이 아직 정해지지 않았습니다.',
           inclus_pendant_la_beta: '베타 기간에는 포함되어 있습니다.', deja_resilie: '이미 해지된 구독입니다.',
           avantage_utilise: '구독 혜택을 이미 사용하여 환불할 수 없습니다.', delai_depasse: '14일 기한이 지났습니다.',
           aucun_abonnement: '진행 중인 구독이 없습니다.', fournisseur_indisponible: '결제 서비스가 응답하지 않습니다. 다시 시도하세요.', indispo: '서버가 응답하지 않습니다. 다시 시도하세요.' }
    },
    ar: {
      titre: 'الدفع', prix: 'السعر: {prix}', vendeurEditeur: 'البائع: {nom}.', tva: 'ضريبة القيمة المضافة غير مطبقة، المادة 293 B من قانون الضرائب العام الفرنسي.',
      vendeurStripe: 'البائع: Stripe (Link)، البائع الرسمي لهذه العملية؛ يتولى الدفع والضرائب والفاتورة والدعم.',
      cgv: 'قرأت شروط البيع العامة وأوافق عليها.', cgvLien: 'قراءة شروط البيع العامة',
      renonciation: 'أطلب التسليم الفوري وأتنازل عن حقي في العدول.',
      aboInfo: 'اشتراك {periode} يتجدد تلقائيًا. يمكن إلغاؤه في أي وقت من بطاقة حسابك (تبويب الهوية)، ويسري الإلغاء في نهاية الفترة المدفوعة. استرداد كامل عند الطلب خلال 14 يومًا من الدفعة الأولى إذا لم تُستخدم أي ميزة.',
      periodeMois: 'شهري', periodeAn: 'سنوي', payer: 'ادفع {prix}', annuler: 'إلغاء', ouverture: 'جارٍ فتح الدفع الآمن…',
      retourOk: 'تم استلام الدفع: تُفعَّل عملية الشراء فور تأكيد Stripe (بضع ثوانٍ).', retourAnnule: 'أُلغي الدفع: لم يُخصم أي مبلغ.',
      compteTitre: 'الاشتراك', aboActif: 'اشتراك {periode} نشط حتى {date}، ويتجدد تلقائيًا.',
      aboResilie: 'أُلغي اشتراك {periode}: يبقى نشطًا حتى {date} دون تجديد.',
      resilier: 'إلغاء اشتراكي', resilierQuestion: 'سيبقى الاشتراك نشطًا حتى {date} ثم لن يتجدد. ما فعّلته يبقى لك.',
      resilierConfirmer: 'تأكيد الإلغاء', resilieOk: 'تم تسجيل الإلغاء: يبقى اشتراكك نشطًا حتى {date}.',
      rembourser: 'طلب الاسترداد (حتى {date})', rembourserQuestion: 'ينتهي الاشتراك فورًا ويُسترد المبلغ بالكامل.',
      rembourserConfirmer: 'تأكيد الاسترداد', rembourseOk: 'تم طلب الاسترداد: انتهى اشتراكك.',
      m: { pays_non_servi: 'الشراء غير متاح من بلدك. تبقى اللعبة مجانية بالكامل.',
           vente_hors_ue_fermee: 'لم يُفتح الشراء في بلدك بعد. تبقى اللعبة مجانية بالكامل.',
           pays_inconnu: 'تعذّر تحديد بلدك: الشراء غير ممكن حاليًا.', paiement_inactif: 'الدفع غير مفتوح بعد.',
           cgv_requises: 'يرجى الموافقة على شروط البيع العامة.', renonciation_requise: 'يرجى وضع علامة على طلب التسليم الفوري.',
           deja_abonne: 'أنت مشترك بالفعل.', option_deja_acquise: 'الخيار مملوك بالفعل.', prix_non_fixe: 'لم يُحدَّد السعر بعد.',
           inclus_pendant_la_beta: 'مشمول خلال النسخة التجريبية.', deja_resilie: 'الاشتراك ملغى بالفعل.',
           avantage_utilise: 'استُخدمت ميزة من الاشتراك: الاسترداد غير ممكن.', delai_depasse: 'انقضت مهلة الأيام الأربعة عشر.',
           aucun_abonnement: 'لا يوجد اشتراك جارٍ.', fournisseur_indisponible: 'خدمة الدفع لا تستجيب. أعد المحاولة.', indispo: 'الخادم لا يستجيب. أعد المحاولة.' }
    },
    'pt-BR': {
      titre: 'Pagamento', prix: 'Preço: {prix}', vendeurEditeur: 'Vendedor: {nom}.', tva: 'IVA não aplicável, artigo 293 B do Código Geral de Impostos francês.',
      vendeurStripe: 'Vendedor: Stripe (Link), vendedor oficial desta venda; cuida do pagamento, dos impostos, da fatura e do suporte.',
      cgv: 'Li e aceito as condições gerais de venda.', cgvLien: 'Ler as condições gerais de venda',
      renonciation: 'Peço a entrega imediata e renuncio ao meu direito de arrependimento.',
      aboInfo: 'Assinatura {periode}, renovada automaticamente. Cancelável a qualquer momento na ficha da sua conta (aba Identidade), com efeito ao fim do período pago. Reembolso integral a pedido em até 14 dias após o primeiro pagamento, se nenhuma vantagem tiver sido usada.',
      periodeMois: 'mensal', periodeAn: 'anual', payer: 'Pagar {prix}', annuler: 'Cancelar', ouverture: 'Abrindo o pagamento seguro…',
      retourOk: 'Pagamento recebido: sua compra é ativada assim que a Stripe confirmar (alguns segundos).', retourAnnule: 'Pagamento cancelado: nada foi cobrado.',
      compteTitre: 'ASSINATURA', aboActif: 'Assinatura {periode} ativa até {date}, renovada automaticamente.',
      aboResilie: 'Assinatura {periode} cancelada: continua ativa até {date}, sem renovação.',
      resilier: 'Cancelar minha assinatura', resilierQuestion: 'A assinatura continua ativa até {date} e não será renovada. O que você ativou continua seu.',
      resilierConfirmer: 'Confirmar o cancelamento', resilieOk: 'Cancelamento registrado: sua assinatura continua ativa até {date}.',
      rembourser: 'Pedir o reembolso (até {date})', rembourserQuestion: 'A assinatura termina agora e o pagamento é reembolsado integralmente.',
      rembourserConfirmer: 'Confirmar o reembolso', rembourseOk: 'Reembolso solicitado: sua assinatura terminou.',
      m: { pays_non_servi: 'As compras não estão disponíveis no seu país. O jogo continua totalmente gratuito.',
           vente_hors_ue_fermee: 'As compras ainda não estão abertas no seu país. O jogo continua totalmente gratuito.',
           pays_inconnu: 'Não foi possível determinar seu país: compra impossível por enquanto.', paiement_inactif: 'O pagamento ainda não está aberto.',
           cgv_requises: 'Aceite as condições gerais de venda.', renonciation_requise: 'Marque o pedido de entrega imediata.',
           deja_abonne: 'Você já é assinante.', option_deja_acquise: 'Opção já adquirida.', prix_non_fixe: 'Preço ainda não definido.',
           inclus_pendant_la_beta: 'Incluído durante a beta.', deja_resilie: 'Assinatura já cancelada.',
           avantage_utilise: 'Uma vantagem da assinatura já foi usada: reembolso impossível.', delai_depasse: 'O prazo de 14 dias passou.',
           aucun_abonnement: 'Nenhuma assinatura em andamento.', fournisseur_indisponible: 'O serviço de pagamento não responde. Tente de novo.', indispo: 'O servidor não responde. Tente de novo.' }
    },
    'zh-TW': {
      titre: '付款', prix: '價格：{prix}', vendeurEditeur: '賣方：{nom}。', tva: '不適用增值稅，依法國稅法第 293 B 條。',
      vendeurStripe: '賣方：Stripe（Link），本次銷售的正式賣方，負責付款、稅務、發票與客服。',
      cgv: '我已閱讀並接受銷售條款。', cgvLien: '閱讀銷售條款',
      renonciation: '我要求立即交付，並放棄撤回權。',
      aboInfo: '{periode}訂閱，自動續訂。可隨時在帳號資料卡（身分分頁）取消，於已付期間結束時生效。若未使用任何優惠，首次付款後 14 天內可申請全額退款。',
      periodeMois: '月繳', periodeAn: '年繳', payer: '支付 {prix}', annuler: '取消', ouverture: '正在開啟安全付款…',
      retourOk: '已收到付款：Stripe 確認後（數秒內）即啟用您的購買。', retourAnnule: '付款已取消：未扣任何款項。',
      compteTitre: '訂閱', aboActif: '{periode}訂閱有效至 {date}，自動續訂。',
      aboResilie: '{periode}訂閱已取消：有效至 {date}，不再續訂。',
      resilier: '取消我的訂閱', resilierQuestion: '訂閱將持續有效至 {date}，之後不再續訂。您已啟用的內容仍歸您所有。',
      resilierConfirmer: '確認取消', resilieOk: '已登記取消：您的訂閱有效至 {date}。',
      rembourser: '申請退款（至 {date}）', rembourserQuestion: '訂閱立即結束，款項全額退還。',
      rembourserConfirmer: '確認退款', rembourseOk: '已申請退款：您的訂閱已結束。',
      m: { pays_non_servi: '您所在的國家無法購買。遊戲仍完全免費。',
           vente_hors_ue_fermee: '您所在的國家尚未開放購買。遊戲仍完全免費。',
           pays_inconnu: '無法判定您所在的國家：目前無法購買。', paiement_inactif: '付款尚未開放。',
           cgv_requises: '請接受銷售條款。', renonciation_requise: '請勾選立即交付的要求。',
           deja_abonne: '您已訂閱。', option_deja_acquise: '已擁有此選項。', prix_non_fixe: '尚未定價。',
           inclus_pendant_la_beta: '測試期間已包含。', deja_resilie: '訂閱已取消。',
           avantage_utilise: '已使用訂閱優惠：無法退款。', delai_depasse: '已超過 14 天期限。',
           aucun_abonnement: '目前沒有訂閱。', fournisseur_indisponible: '付款服務沒有回應，請再試一次。', indispo: '伺服器沒有回應，請再試一次。' }
    }
  };
  const LOCALES = { fr: 'fr-FR', en: 'en-GB', es: 'es-ES', de: 'de-DE', ru: 'ru-RU', ko: 'ko-KR', ar: 'ar', 'pt-BR': 'pt-BR', 'zh-TW': 'zh-TW' };

  function langue() {
    const l = (typeof window !== 'undefined' && window.RP_I18N_GAME_ENABLED === true && window.RPPlateauI18n?.language?.()) || 'fr';
    return T[l] ? l : 'fr';
  }
  function t(cle, vars) {
    const l = T[langue()];
    let s = (l[cle] !== undefined ? l[cle] : T.fr[cle]) || cle;
    Object.keys(vars || {}).forEach(k => { s = s.split('{' + k + '}').join(String(vars[k])); });
    return s;
  }
  const motif = r => { const m = T[langue()].m; return (r && (m[r] || T.fr.m[r])) || m.indispo; };
  const ech = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const prixTexte = c => { try { return new Intl.NumberFormat(LOCALES[langue()], { style: 'currency', currency: 'EUR' }).format(Number(c) / 100); } catch (_) { return (Number(c) / 100).toFixed(2) + ' €'; } };
  const dateTexte = d => { try { return new Date(d).toLocaleDateString(LOCALES[langue()], { year: 'numeric', month: 'long', day: 'numeric' }); } catch (_) { return String(d).slice(0, 10); } };
  const periode = intervalle => intervalle === 'year' ? t('periodeAn') : t('periodeMois');
  const toast = (titre, corps, ok) => { if (typeof window.showToast === 'function') window.showToast(titre, corps, ok !== false); };

  async function appeler(corps) {
    try {
      if (typeof window.rpAuthAssurerSession === 'function') await window.rpAuthAssurerSession();
      const jeton = typeof window.rpAuthJeton === 'function' ? window.rpAuthJeton() : null;
      if (!jeton) return { ok: false, raison: 'acteur_non_authentifie' };
      const res = await fetch('/api/paiement', { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + jeton }, body: JSON.stringify(corps) });
      return (await res.json().catch(() => null)) || { ok: false, raison: 'indispo' };
    } catch (_) { return { ok: false, raison: 'indispo' }; }
  }

  // Écran de confirmation avant le paiement : vendeur, prix de la base, cases à cocher. p = produit rendu par premium_droits_lire.
  async function confirmerAchat(produit, cible, p) {
    const m = document.getElementById('modal-postes'), ti = document.getElementById('postes-modal-title'), c = document.getElementById('postes-body');
    if (!m || !c || !p) return false;
    if (ti) ti.textContent = t('titre');
    c.innerHTML = '<div class="cpj-dialogue" style="padding:1rem;max-width:620px;margin:auto"><p class="cpj-note">…</p></div>';
    m.classList.add('open');
    const zone = c.firstElementChild || c;
    const e = await appeler({ action: 'etat' });
    if (!e || e.ok !== true || !e.achats_possibles) {
      zone.innerHTML = '<p>' + ech(motif(e && e.raison)) + '</p><button type="button" class="cpj-touche" data-paiement-annuler>' + ech(t('annuler')) + '</button>';
      zone.querySelector('[data-paiement-annuler]')?.addEventListener('click', () => m.classList.remove('open'));
      return false;
    }
    const abonnement = p.nature === 'abonnement', renonciationRequise = p.nature === 'option' || p.nature === 'unite';
    const intervalle = p.produit === 'abonnement_annuel' ? 'year' : 'month';
    const vendeur = e.vendeur === 'stripe' ? '<p>' + ech(t('vendeurStripe')) + '</p>'
      : '<p>' + ech(t('vendeurEditeur', { nom: e.editeur_nom || 'Human Gambit' })) + '<br><span class="cpj-note">' + ech(t('tva')) + '</span></p>';
    const cgvLien = e.cgv_url && /^(https:\/\/|\/)/.test(e.cgv_url) ? ' <a href="' + ech(e.cgv_url) + '" target="_blank" rel="noopener">' + ech(t('cgvLien')) + '</a>' : '';
    zone.innerHTML = '<p><strong>' + ech(p.libelle) + '</strong><br>' + ech(t('prix', { prix: prixTexte(p.prix_centimes) })) + '</p>' + vendeur +
      (abonnement ? '<p class="cpj-note">' + ech(t('aboInfo', { periode: periode(intervalle) })) + '</p>' : '') +
      '<p><label><input type="checkbox" data-paiement-cgv> ' + ech(t('cgv')) + '</label>' + cgvLien + '</p>' +
      (renonciationRequise ? '<p><label><input type="checkbox" data-paiement-renonciation> ' + ech(t('renonciation')) + '</label></p>' : '') +
      '<p><button type="button" class="cpj-touche cpj-primaire" data-paiement-payer disabled>' + ech(t('payer', { prix: prixTexte(p.prix_centimes) })) + '</button> ' +
      '<button type="button" class="cpj-touche" data-paiement-annuler>' + ech(t('annuler')) + '</button></p><p class="cpj-note" role="status" data-paiement-retour></p>';
    const cgv = zone.querySelector('[data-paiement-cgv]'), ren = zone.querySelector('[data-paiement-renonciation]');
    const payer = zone.querySelector('[data-paiement-payer]'), retour = zone.querySelector('[data-paiement-retour]');
    const maj = () => { payer.disabled = !(cgv.checked && (!ren || ren.checked)); };
    cgv.addEventListener('change', maj); if (ren) ren.addEventListener('change', maj);
    zone.querySelector('[data-paiement-annuler]').addEventListener('click', () => m.classList.remove('open'));
    payer.addEventListener('click', async () => {
      payer.disabled = true; retour.textContent = t('ouverture');
      const r = await appeler({ action: 'commander', produit, cible: cible || null, cgv: cgv.checked === true, renonciation: !!(ren && ren.checked), langue: langue() });
      if (r && r.ok && typeof r.url === 'string' && /^(https:\/\/checkout\.stripe\.com\/|\/)/.test(r.url)) { window.location.assign(r.url); return; }
      retour.textContent = motif(r && r.raison); maj();
    });
    return true;
  }

  // Fiche du compte (onglet Identité) : rendu synchrone d'un conteneur, rempli par l'état réel du serveur.
  function rpHtmlAbonnementCompte() {
    setTimeout(rafraichirAbonnementCompte, 0);
    return '<div id="bloc-abonnement-compte"></div>';
  }
  async function rafraichirAbonnementCompte(message) {
    const bloc = document.getElementById('bloc-abonnement-compte');
    if (!bloc || typeof window.sbRpc !== 'function') return;
    let a = await window.sbRpc('premium_abonnement_lire', {}).catch(() => null);
    a = Array.isArray(a) ? a[0] : a;
    if (!a || a.ok !== true || !a.abonne) { bloc.innerHTML = message ? '<div class="cpj-dialogue" style="margin-top:1.4rem;padding:.8rem .9rem"><p class="cpj-note">' + ech(message) + '</p></div>' : ''; return; }
    const date = dateTexte(a.fin);
    let h = '<div class="cpj-dialogue" style="margin-top:1.4rem;padding:.8rem .9rem"><div class="cpj-note"><strong>' + ech(t('compteTitre')) + '</strong></div>' +
      '<p>' + ech(a.annule ? t('aboResilie', { periode: periode(a.intervalle), date }) : t('aboActif', { periode: periode(a.intervalle), date })) + '</p>';
    if (message) h += '<p class="cpj-note" role="status">' + ech(message) + '</p>';
    if (a.resiliable) h += '<p><button type="button" class="cpj-touche" data-abo-resilier>' + ech(t('resilier')) + '</button></p>';
    if (a.remboursable && a.remboursable_jusqu_au) h += '<p><button type="button" class="cpj-touche" data-abo-rembourser>' + ech(t('rembourser', { date: dateTexte(a.remboursable_jusqu_au) })) + '</button></p>';
    h += '<div data-abo-confirmer></div></div>';
    bloc.innerHTML = h;
    const zone = bloc.querySelector('[data-abo-confirmer]');
    const demander = (question, libelle, action, okTexte) => {
      zone.innerHTML = '<p class="cpj-note">' + ech(question) + '</p><button type="button" class="cpj-touche cpj-primaire" data-abo-oui>' + ech(libelle) +
        '</button> <button type="button" class="cpj-touche" data-abo-non>' + ech(t('annuler')) + '</button>';
      zone.querySelector('[data-abo-non]').addEventListener('click', () => { zone.innerHTML = ''; });
      zone.querySelector('[data-abo-oui]').addEventListener('click', async ev => {
        ev.currentTarget.disabled = true;
        const r = await appeler({ action });
        rafraichirAbonnementCompte(r && r.ok ? okTexte(r) : motif(r && r.raison));
      });
    };
    // Résiliation : 1er clic « Résilier mon abonnement », 2e clic « Confirmer la résiliation ».
    bloc.querySelector('[data-abo-resilier]')?.addEventListener('click', () =>
      demander(t('resilierQuestion', { date }), t('resilierConfirmer'), 'resilier', r => t('resilieOk', { date: dateTexte(r.fin || a.fin) })));
    bloc.querySelector('[data-abo-rembourser]')?.addEventListener('click', () =>
      demander(t('rembourserQuestion'), t('rembourserConfirmer'), 'rembourser_abonnement', () => t('rembourseOk')));
  }

  // Retour de la page de paiement de Stripe.
  function retourDePaiement() {
    try {
      const u = new URL(window.location.href), etat = u.searchParams.get('paiement');
      if (etat !== 'ok' && etat !== 'annule') return;
      setTimeout(() => toast(t('titre'), etat === 'ok' ? t('retourOk') : t('retourAnnule'), etat === 'ok'), 1500);
      u.searchParams.delete('paiement'); u.searchParams.delete('achat');
      window.history.replaceState(null, '', u.pathname + (u.search || '') + u.hash);
    } catch (_) { /* rien */ }
  }

  if (typeof window !== 'undefined') {
    window.RP_PAIEMENT_T = T;
    window.rpHtmlAbonnementCompte = rpHtmlAbonnementCompte;
    window.RPPaiement = Object.freeze({ confirmerAchat, rafraichirAbonnementCompte, rpHtmlAbonnementCompte });
    if (typeof document !== 'undefined' && document.readyState !== 'loading') retourDePaiement();
    else if (typeof document !== 'undefined') document.addEventListener('DOMContentLoaded', retourDePaiement);
  }
})();
