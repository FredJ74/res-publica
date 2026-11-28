/* ===========================================================================
   RES PUBLICA — api/_paiement-courriels.js
   E-MAILS DU PAIEMENT (mission du 28/11/2026, étape 4) : confirmation d'achat, rappel d'abonnement annuel, débit en double.
   Textes dans les 9 langues du jeu. Envoi par l'API REST de Resend (aucune dépendance) si RESEND_API_KEY et
   COURRIEL_EXPEDITEUR existent dans Vercel ; sinon rien n'est envoyé (raison « courriel_inactif ») et les e-mails de Stripe
   (reçus, factures, rappels de renouvellement réglés dans le tableau de bord Stripe) restent la seule trace.
   =========================================================================== */

export const LANGUES_COURRIEL = ['fr', 'en', 'es', 'de', 'ru', 'ko', 'ar', 'pt-BR', 'zh-TW'];

export const TEXTES_COURRIEL = {
  fr: {
    sujetAchat: 'Human Gambit — confirmation de votre achat', sujetAbonnement: 'Human Gambit — confirmation de votre abonnement',
    corpsAchat: 'Merci ! Votre paiement de {montant} pour « {produit} » est confirmé. L’avantage est activé sur votre compte.',
    vendeur: 'Vendeur : {vendeur}.', vendeurStripe: 'Stripe (Link), vendeur officiel de cette vente',
    mentionTva: 'TVA non applicable, article 293 B du CGI.',
    renonciation: 'Vous avez demandé la livraison immédiate et renoncé à votre droit de rétractation (case cochée le {date}).',
    abonnement: 'Votre abonnement ({periode}) se renouvelle automatiquement. Vous pouvez le résilier à tout moment depuis la fiche de votre compte (onglet Identité) : la résiliation prend effet à la fin de la période payée. Remboursement intégral sur demande dans les 14 jours suivant le premier paiement si aucun avantage n’a été utilisé.',
    periodeMois: 'mensuel', periodeAn: 'annuel',
    sujetRappel: 'Human Gambit — votre abonnement annuel sera renouvelé le {date}',
    corpsRappel: 'Votre abonnement annuel sera renouvelé automatiquement le {date}, pour {montant}. Pour l’arrêter, résiliez-le avant cette date depuis la fiche de votre compte (onglet Identité) ; ce que vous avez activé reste acquis.',
    sujetDoublon: 'Human Gambit — paiement en double remboursé',
    corpsDoublon: 'Nous avons reçu deux paiements pour « {produit} ». Le second ({montant}) vous est remboursé intégralement.',
    erreur: 'Tout débit en erreur ou en double est remboursé : répondez simplement à cet e-mail.', signature: 'L’équipe de Human Gambit'
  },
  en: {
    sujetAchat: 'Human Gambit — your purchase is confirmed', sujetAbonnement: 'Human Gambit — your subscription is confirmed',
    corpsAchat: 'Thank you! Your payment of {montant} for “{produit}” is confirmed. The benefit is now active on your account.',
    vendeur: 'Seller: {vendeur}.', vendeurStripe: 'Stripe (Link), merchant of record for this sale',
    mentionTva: 'VAT not applicable, article 293 B of the French General Tax Code.',
    renonciation: 'You asked for immediate delivery and waived your right of withdrawal (box ticked on {date}).',
    abonnement: 'Your {periode} subscription renews automatically. You can cancel it at any time from your account sheet (Identity tab): cancellation takes effect at the end of the paid period. Full refund on request within 14 days of the first payment if no benefit has been used.',
    periodeMois: 'monthly', periodeAn: 'yearly',
    sujetRappel: 'Human Gambit — your yearly subscription renews on {date}',
    corpsRappel: 'Your yearly subscription will renew automatically on {date}, for {montant}. To stop it, cancel before that date from your account sheet (Identity tab); what you have activated stays yours.',
    sujetDoublon: 'Human Gambit — duplicate payment refunded',
    corpsDoublon: 'We received two payments for “{produit}”. The second one ({montant}) is refunded in full.',
    erreur: 'Any mistaken or duplicate charge is refunded: just reply to this e-mail.', signature: 'The Human Gambit team'
  },
  es: {
    sujetAchat: 'Human Gambit — confirmación de su compra', sujetAbonnement: 'Human Gambit — confirmación de su suscripción',
    corpsAchat: '¡Gracias! Su pago de {montant} por «{produit}» está confirmado. La ventaja ya está activa en su cuenta.',
    vendeur: 'Vendedor: {vendeur}.', vendeurStripe: 'Stripe (Link), vendedor oficial de esta venta',
    mentionTva: 'IVA no aplicable, artículo 293 B del Código General de Impuestos francés.',
    renonciation: 'Pidió la entrega inmediata y renunció a su derecho de desistimiento (casilla marcada el {date}).',
    abonnement: 'Su suscripción {periode} se renueva automáticamente. Puede cancelarla en cualquier momento desde la ficha de su cuenta (pestaña Identidad): la cancelación surte efecto al final del periodo pagado. Reembolso íntegro a petición en los 14 días siguientes al primer pago si no se ha usado ninguna ventaja.',
    periodeMois: 'mensual', periodeAn: 'anual',
    sujetRappel: 'Human Gambit — su suscripción anual se renovará el {date}',
    corpsRappel: 'Su suscripción anual se renovará automáticamente el {date}, por {montant}. Para detenerla, cancélela antes de esa fecha desde la ficha de su cuenta (pestaña Identidad); lo que haya activado sigue siendo suyo.',
    sujetDoublon: 'Human Gambit — pago duplicado reembolsado',
    corpsDoublon: 'Recibimos dos pagos por «{produit}». El segundo ({montant}) se le reembolsa íntegramente.',
    erreur: 'Todo cargo erróneo o duplicado se reembolsa: basta con responder a este correo.', signature: 'El equipo de Human Gambit'
  },
  de: {
    sujetAchat: 'Human Gambit — Ihr Kauf ist bestätigt', sujetAbonnement: 'Human Gambit — Ihr Abonnement ist bestätigt',
    corpsAchat: 'Danke! Ihre Zahlung von {montant} für „{produit}“ ist bestätigt. Der Vorteil ist in Ihrem Konto aktiv.',
    vendeur: 'Verkäufer: {vendeur}.', vendeurStripe: 'Stripe (Link), offizieller Verkäufer dieses Kaufs',
    mentionTva: 'Keine Mehrwertsteuer gemäß Artikel 293 B des französischen Steuergesetzbuchs (CGI).',
    renonciation: 'Sie haben die sofortige Lieferung verlangt und auf Ihr Widerrufsrecht verzichtet (Kästchen angekreuzt am {date}).',
    abonnement: 'Ihr {periode} Abonnement verlängert sich automatisch. Sie können es jederzeit im Kontoblatt (Reiter Identität) kündigen: Die Kündigung wirkt zum Ende des bezahlten Zeitraums. Volle Erstattung auf Anfrage innerhalb von 14 Tagen nach der ersten Zahlung, wenn kein Vorteil genutzt wurde.',
    periodeMois: 'monatliches', periodeAn: 'jährliches',
    sujetRappel: 'Human Gambit — Ihr Jahresabonnement verlängert sich am {date}',
    corpsRappel: 'Ihr Jahresabonnement verlängert sich automatisch am {date} für {montant}. Um es zu beenden, kündigen Sie vor diesem Datum im Kontoblatt (Reiter Identität); was Sie aktiviert haben, bleibt Ihnen.',
    sujetDoublon: 'Human Gambit — doppelte Zahlung erstattet',
    corpsDoublon: 'Wir haben zwei Zahlungen für „{produit}“ erhalten. Die zweite ({montant}) wird Ihnen vollständig erstattet.',
    erreur: 'Jede irrtümliche oder doppelte Abbuchung wird erstattet: Antworten Sie einfach auf diese E-Mail.', signature: 'Das Team von Human Gambit'
  },
  ru: {
    sujetAchat: 'Human Gambit — покупка подтверждена', sujetAbonnement: 'Human Gambit — подписка подтверждена',
    corpsAchat: 'Спасибо! Ваш платёж {montant} за «{produit}» подтверждён. Преимущество уже активно в вашем аккаунте.',
    vendeur: 'Продавец: {vendeur}.', vendeurStripe: 'Stripe (Link), официальный продавец по этой покупке',
    mentionTva: 'НДС не применяется, статья 293 B Общего налогового кодекса Франции.',
    renonciation: 'Вы попросили немедленную поставку и отказались от права на отказ от покупки (отметка поставлена {date}).',
    abonnement: 'Ваша подписка ({periode}) продлевается автоматически. Отменить её можно в любой момент в карточке аккаунта (вкладка «Личность»): отмена вступает в силу в конце оплаченного периода. Полный возврат по запросу в течение 14 дней после первого платежа, если ни одно преимущество не использовано.',
    periodeMois: 'ежемесячная', periodeAn: 'годовая',
    sujetRappel: 'Human Gambit — годовая подписка продлится {date}',
    corpsRappel: 'Ваша годовая подписка автоматически продлится {date} за {montant}. Чтобы её остановить, отмените её до этой даты в карточке аккаунта (вкладка «Личность»); всё активированное останется за вами.',
    sujetDoublon: 'Human Gambit — двойной платёж возвращён',
    corpsDoublon: 'Мы получили два платежа за «{produit}». Второй ({montant}) возвращается вам полностью.',
    erreur: 'Любое ошибочное или двойное списание возвращается: просто ответьте на это письмо.', signature: 'Команда Human Gambit'
  },
  ko: {
    sujetAchat: 'Human Gambit — 구매가 확인되었습니다', sujetAbonnement: 'Human Gambit — 구독이 확인되었습니다',
    corpsAchat: '감사합니다! 「{produit}」에 대한 {montant} 결제가 확인되었습니다. 혜택이 계정에 적용되었습니다.',
    vendeur: '판매자: {vendeur}.', vendeurStripe: '이 판매의 공식 판매자인 Stripe(Link)',
    mentionTva: '부가가치세 비적용, 프랑스 조세일반법 제293 B조.',
    renonciation: '즉시 제공을 요청하고 청약철회권을 포기하셨습니다({date}에 체크).',
    abonnement: '{periode} 구독은 자동으로 갱신됩니다. 계정 시트(신원 탭)에서 언제든지 해지할 수 있으며, 해지는 결제된 기간이 끝날 때 적용됩니다. 혜택을 사용하지 않았다면 첫 결제 후 14일 이내에 요청 시 전액 환불됩니다.',
    periodeMois: '월간', periodeAn: '연간',
    sujetRappel: 'Human Gambit — 연간 구독이 {date}에 갱신됩니다',
    corpsRappel: '연간 구독이 {date}에 {montant}(으)로 자동 갱신됩니다. 중단하려면 그 전에 계정 시트(신원 탭)에서 해지하세요. 활성화한 것은 계속 유지됩니다.',
    sujetDoublon: 'Human Gambit — 중복 결제 환불',
    corpsDoublon: '「{produit}」에 대해 두 번 결제되었습니다. 두 번째 결제({montant})는 전액 환불됩니다.',
    erreur: '잘못되었거나 중복된 청구는 환불됩니다. 이 메일에 답장해 주세요.', signature: 'Human Gambit 팀'
  },
  ar: {
    sujetAchat: 'Human Gambit — تأكيد عملية الشراء', sujetAbonnement: 'Human Gambit — تأكيد الاشتراك',
    corpsAchat: 'شكرًا! تم تأكيد دفعتك البالغة {montant} مقابل «{produit}». الميزة مفعّلة الآن في حسابك.',
    vendeur: 'البائع: {vendeur}.', vendeurStripe: 'Stripe (Link)، البائع الرسمي لهذه العملية',
    mentionTva: 'ضريبة القيمة المضافة غير مطبقة، المادة 293 B من قانون الضرائب العام الفرنسي.',
    renonciation: 'طلبت التسليم الفوري وتنازلت عن حقك في العدول (تم وضع العلامة في {date}).',
    abonnement: 'يتجدد اشتراكك ({periode}) تلقائيًا. يمكنك إلغاؤه في أي وقت من بطاقة حسابك (تبويب الهوية)، ويسري الإلغاء في نهاية الفترة المدفوعة. استرداد كامل عند الطلب خلال 14 يومًا من الدفعة الأولى إذا لم تُستخدم أي ميزة.',
    periodeMois: 'شهري', periodeAn: 'سنوي',
    sujetRappel: 'Human Gambit — سيتجدد اشتراكك السنوي في {date}',
    corpsRappel: 'سيتجدد اشتراكك السنوي تلقائيًا في {date} مقابل {montant}. لإيقافه، ألغِه قبل هذا التاريخ من بطاقة حسابك (تبويب الهوية)؛ ما فعّلته يبقى لك.',
    sujetDoublon: 'Human Gambit — استرداد دفعة مكررة',
    corpsDoublon: 'تلقينا دفعتين مقابل «{produit}». تُسترد الدفعة الثانية ({montant}) بالكامل.',
    erreur: 'يُسترد كل خصم خاطئ أو مكرر: يكفي الرد على هذه الرسالة.', signature: 'فريق Human Gambit'
  },
  'pt-BR': {
    sujetAchat: 'Human Gambit — confirmação da sua compra', sujetAbonnement: 'Human Gambit — confirmação da sua assinatura',
    corpsAchat: 'Obrigado! Seu pagamento de {montant} por “{produit}” foi confirmado. A vantagem já está ativa na sua conta.',
    vendeur: 'Vendedor: {vendeur}.', vendeurStripe: 'Stripe (Link), vendedor oficial desta venda',
    mentionTva: 'IVA não aplicável, artigo 293 B do Código Geral de Impostos francês.',
    renonciation: 'Você pediu a entrega imediata e renunciou ao seu direito de arrependimento (caixa marcada em {date}).',
    abonnement: 'Sua assinatura {periode} é renovada automaticamente. Você pode cancelá-la a qualquer momento na ficha da sua conta (aba Identidade): o cancelamento vale ao fim do período pago. Reembolso integral a pedido em até 14 dias após o primeiro pagamento, se nenhuma vantagem tiver sido usada.',
    periodeMois: 'mensal', periodeAn: 'anual',
    sujetRappel: 'Human Gambit — sua assinatura anual será renovada em {date}',
    corpsRappel: 'Sua assinatura anual será renovada automaticamente em {date}, por {montant}. Para interrompê-la, cancele antes dessa data na ficha da sua conta (aba Identidade); o que você ativou continua seu.',
    sujetDoublon: 'Human Gambit — pagamento duplicado reembolsado',
    corpsDoublon: 'Recebemos dois pagamentos por “{produit}”. O segundo ({montant}) será reembolsado integralmente.',
    erreur: 'Toda cobrança indevida ou duplicada é reembolsada: basta responder a este e-mail.', signature: 'A equipe do Human Gambit'
  },
  'zh-TW': {
    sujetAchat: 'Human Gambit — 購買確認', sujetAbonnement: 'Human Gambit — 訂閱確認',
    corpsAchat: '謝謝！您為「{produit}」支付的 {montant} 已確認，優惠已在您的帳號啟用。',
    vendeur: '賣方：{vendeur}。', vendeurStripe: 'Stripe（Link），本次銷售的正式賣方',
    mentionTva: '不適用增值稅，依法國稅法第 293 B 條。',
    renonciation: '您要求立即交付並放棄撤回權（於 {date} 勾選）。',
    abonnement: '您的{periode}訂閱會自動續訂。您可隨時在帳號資料卡（身分分頁）取消，取消於已付期間結束時生效。若未使用任何優惠，首次付款後 14 天內可申請全額退款。',
    periodeMois: '月繳', periodeAn: '年繳',
    sujetRappel: 'Human Gambit — 您的年繳訂閱將於 {date} 續訂',
    corpsRappel: '您的年繳訂閱將於 {date} 以 {montant} 自動續訂。若要停止，請在此日期前於帳號資料卡（身分分頁）取消；您已啟用的內容仍歸您所有。',
    sujetDoublon: 'Human Gambit — 重複付款已退款',
    corpsDoublon: '我們收到兩筆「{produit}」的付款，第二筆（{montant}）將全額退還。',
    erreur: '任何錯誤或重複扣款都會退還：直接回覆此郵件即可。', signature: 'Human Gambit 團隊'
  }
};

const LOCALES = { fr: 'fr-FR', en: 'en-GB', es: 'es-ES', de: 'de-DE', ru: 'ru-RU', ko: 'ko-KR', ar: 'ar', 'pt-BR': 'pt-BR', 'zh-TW': 'zh-TW' };
export const langueCourriel = l => (LANGUES_COURRIEL.includes(l) ? l : 'fr');
const remplir = (s, v) => String(s).replace(/\{([a-z]+)\}/g, (m, k) => (v && v[k] != null ? String(v[k]) : m));
export function montantTexte(centimes, langue) {
  try { return new Intl.NumberFormat(LOCALES[langueCourriel(langue)], { style: 'currency', currency: 'EUR' }).format(Number(centimes) / 100); }
  catch (_) { return (Number(centimes) / 100).toFixed(2) + ' €'; }
}
export function dateTexte(d, langue) {
  try { return new Date(d).toLocaleDateString(LOCALES[langueCourriel(langue)], { year: 'numeric', month: 'long', day: 'numeric', timeZone: 'Europe/Paris' }); }
  catch (_) { return String(d).slice(0, 10); }
}

// Contenu des e-mails (fonctions pures, éprouvées au banc).
export function courrielConfirmation(info, { editeurNom } = {}) {
  const l = langueCourriel(info.langue), T = TEXTES_COURRIEL[l];
  const montant = montantTexte(info.montant_centimes, l);
  const vendeur = info.mode_vente === 'stripe' ? T.vendeurStripe : (editeurNom || 'Human Gambit');
  const lignes = [remplir(T.corpsAchat, { montant, produit: info.libelle }), remplir(T.vendeur, { vendeur })];
  if (info.mode_vente !== 'stripe') lignes.push(T.mentionTva);
  if (info.renonciation) lignes.push(remplir(T.renonciation, { date: dateTexte(info.renonciation_le || Date.now(), l) }));
  if (info.nature === 'abonnement') lignes.push(remplir(T.abonnement, { periode: info.intervalle === 'year' ? T.periodeAn : T.periodeMois }));
  lignes.push(T.erreur, '', T.signature);
  return { sujet: info.nature === 'abonnement' ? T.sujetAbonnement : T.sujetAchat, texte: lignes.join('\n\n') };
}
export function courrielRappelAnnuel(r) {
  const l = langueCourriel(r.langue), T = TEXTES_COURRIEL[l], date = dateTexte(r.fin, l);
  const montant = r.montant_centimes ? montantTexte(r.montant_centimes, l) : '—';
  return { sujet: remplir(T.sujetRappel, { date }), texte: [remplir(T.corpsRappel, { date, montant }), T.erreur, '', T.signature].join('\n\n') };
}
export function courrielDoublon(info) {
  const l = langueCourriel(info.langue), T = TEXTES_COURRIEL[l];
  return { sujet: T.sujetDoublon, texte: [remplir(T.corpsDoublon, { produit: info.libelle, montant: montantTexte(info.montant_centimes, l) }), '', T.signature].join('\n\n') };
}

const echapper = s => String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

// Envoi. Renvoie { ok, raison? }. Une clé d'idempotence évite un double envoi si le webhook est rejoué.
export async function envoyerCourriel({ a, sujet, texte, cle }, { env = process.env, fetchFn = fetch } = {}) {
  if (!env.RESEND_API_KEY || !env.COURRIEL_EXPEDITEUR) return { ok: false, raison: 'courriel_inactif' };
  if (!a || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(String(a))) return { ok: false, raison: 'adresse_invalide' };
  try {
    const r = await fetchFn('https://api.resend.com/emails', {
      method: 'POST',
      headers: { Authorization: 'Bearer ' + env.RESEND_API_KEY, 'Content-Type': 'application/json', ...(cle ? { 'Idempotency-Key': String(cle).slice(0, 256) } : {}) },
      body: JSON.stringify({ from: env.COURRIEL_EXPEDITEUR, to: [String(a)], subject: sujet, text: texte,
        html: '<div style="font-family:sans-serif;line-height:1.5">' + texte.split('\n\n').map(p => '<p>' + echapper(p) + '</p>').join('') + '</div>' }),
      signal: AbortSignal.timeout(8000)
    });
    return r.ok ? { ok: true } : { ok: false, raison: 'envoi_refuse_' + r.status };
  } catch (_) { return { ok: false, raison: 'envoi_echoue' }; }
}
