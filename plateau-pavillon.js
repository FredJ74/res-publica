// Pavillon des Ambassadeurs — baux et réception institutionnels.
// Le navigateur ne décide ni du droit d'accès, ni de la devise, ni du prix ou du paiement.
const PAVILLON_TEXTES = {
  fr: {titre:'Pavillon des Ambassadeurs',bail:'Bail diplomatique',reception:'Grande salle de réception',indisponible:'État indisponible, aucune réservation effectuée.',
    reserver:'Louer pour 7 jours',renouveler:'Renouveler pour 7 jours',resilier:'Résilier le bail (+1 jour de ménage)',
    reserve:'Cette suite est déjà occupée.',recu:'Confirmation du serveur',refus:'Réservation refusée',
    acces:'Réservé aux dignitaires étrangers autorisés et à leur institution payeuse.',
    suite:'Prix par jour : {prix} FR. Le bail est payé 7 jours d’avance par l’institution. Bonus : +3 PA à chaque sommeil autorisé.',
    receptionTexte:'Location exclusive pour aujourd’hui : 1 500 PSK, débités de la caisse de l’institution.',
    somme:'Montant facturé : {montant} {devise}',fin:'Date de fin (exclusive) : {date}',reserverReception:'Réserver pour aujourd’hui',
    confirme:'L’opération a été enregistrée par le serveur.',motif:'Motif : {motif}'},
  en: {titre:'Ambassadors’ Pavilion',bail:'Diplomatic lease',reception:'Grand reception hall',indisponible:'Unable to confirm availability. No booking made.',reserver:'Rent for 7 days',renouveler:'Renew for 7 days',resilier:'End lease (+1 day cleaning charge)',reserve:'This suite is occupied.',recu:'Server confirmation',refus:'Booking declined',acces:'Only authorized foreign dignitaries and their paying institutions.',suite:'Daily price: {prix} FR. The institution prepays 7 days. Bonus: +3 AP on each eligible sleep.',receptionTexte:'Exclusive booking for today: 1,500 PSK charged to the institution.',somme:'Amount charged: {montant} {devise}',fin:'End date (exclusive): {date}',reserverReception:'Book for today',confirme:'The server has confirmed this transaction.',motif:'Reason: {motif}'},
  es: {titre:'Pabellón de Embajadores',bail:'Arrendamiento diplomático',reception:'Gran sala de recepción',indisponible:'Estado no disponible. No se ha reservado.',reserver:'Alquilar 7 días',renouveler:'Renovar 7 días',resilier:'Rescindir (+1 día de limpieza)',reserve:'La suite está ocupada.',recu:'Confirmación del servidor',refus:'Reserva rechazada',acces:'Reservado a dignatarios extranjeros autorizados.',suite:'Precio diario: {prix} FR, 7 días pagados por la institución. +3 PA por descanso válido.',receptionTexte:'Reserva exclusiva por hoy: 1500 PSK a cargo de la institución.',somme:'Importe: {montant} {devise}',fin:'Fin (exclusivo): {date}',reserverReception:'Reservar hoy',confirme:'Confirmado por el servidor.',motif:'Motivo: {motif}'},
  de: {titre:'Botschafterpavillon',bail:'Diplomatische Miete',reception:'Großer Empfangssaal',indisponible:'Status nicht verfügbar. Keine Buchung.',reserver:'Für 7 Tage mieten',renouveler:'Um 7 Tage verlängern',resilier:'Kündigen (+1 Reinigungstag)',reserve:'Suite belegt.',recu:'Serverbestätigung',refus:'Buchung abgelehnt',acces:'Nur für berechtigte ausländische Würdenträger.',suite:'Tagespreis: {prix} FR, 7 Tage durch die Institution im Voraus. +3 AP pro gültiger Ruhe.',receptionTexte:'Exklusiv für heute: 1.500 PSK auf Kosten der Institution.',somme:'Betrag: {montant} {devise}',fin:'Ende (exklusiv): {date}',reserverReception:'Für heute buchen',confirme:'Vom Server bestätigt.',motif:'Grund: {motif}'},
  ru: {titre:'Павильон послов',bail:'Дипломатическая аренда',reception:'Большой зал приёмов',indisponible:'Статус недоступен. Бронирования нет.',reserver:'Арендовать на 7 дней',renouveler:'Продлить на 7 дней',resilier:'Расторгнуть (+1 день уборки)',reserve:'Люкс занят.',recu:'Подтверждение сервера',refus:'Отказ в бронировании',acces:'Только уполномоченным иностранным должностным лицам.',suite:'Цена: {prix} FR в день. Учреждение оплачивает 7 дней. +3 ОД за каждый разрешённый сон.',receptionTexte:'Эксклюзивно на сегодня: 1500 PSK за счёт учреждения.',somme:'Списано: {montant} {devise}',fin:'Окончание (не включительно): {date}',reserverReception:'Забронировать сегодня',confirme:'Сервер подтвердил операцию.',motif:'Причина: {motif}'},
  ko: {titre:'대사관 파빌리온',bail:'외교 숙소 임대',reception:'대연회장',indisponible:'상태를 확인할 수 없습니다. 예약되지 않았습니다.',reserver:'7일 임대',renouveler:'7일 연장',resilier:'해지 (청소비 1일)',reserve:'이미 사용 중인 객실입니다.',recu:'서버 확인',refus:'예약 거절',acces:'허가된 외국 고위 인사만 이용할 수 있습니다.',suite:'하루 {prix} FR, 기관에서 7일 선불. 허용된 수면마다 행동력 +3.',receptionTexte:'오늘 독점 대관: 기관이 1,500 PSK 지불.',somme:'결제 금액: {montant} {devise}',fin:'종료일(미포함): {date}',reserverReception:'오늘 예약',confirme:'서버에서 확인했습니다.',motif:'사유: {motif}'},
  ar: {titre:'جناح السفراء',bail:'إيجار دبلوماسي',reception:'قاعة الاستقبال الكبرى',indisponible:'الحالة غير متاحة. لم يتم الحجز.',reserver:'استئجار 7 أيام',renouveler:'تجديد 7 أيام',resilier:'إنهاء (+يوم تنظيف)',reserve:'الجناح مشغول.',recu:'تأكيد الخادم',refus:'رُفض الحجز',acces:'للمسؤولين الأجانب المخولين فقط.',suite:'السعر اليومي {prix} FR، تدفع المؤسسة 7 أيام مقدمًا. +3 نقاط عمل لكل نوم مسموح.',receptionTexte:'حجز حصري لليوم: 1500 PSK من صندوق المؤسسة.',somme:'المبلغ: {montant} {devise}',fin:'تاريخ النهاية (غير شامل): {date}',reserverReception:'احجز اليوم',confirme:'تم التأكيد من الخادم.',motif:'السبب: {motif}'},
  'pt-BR': {titre:'Pavilhão dos Embaixadores',bail:'Aluguel diplomático',reception:'Grande salão de recepção',indisponible:'Estado indisponível. Nenhuma reserva feita.',reserver:'Alugar por 7 dias',renouveler:'Renovar por 7 dias',resilier:'Rescindir (+1 dia de limpeza)',reserve:'Suíte ocupada.',recu:'Confirmação do servidor',refus:'Reserva recusada',acces:'Apenas dignitários estrangeiros autorizados.',suite:'Diária: {prix} FR, 7 dias pré-pagos pela instituição. +3 PA por descanso permitido.',receptionTexte:'Reserva exclusiva para hoje: 1.500 PSK da instituição.',somme:'Cobrado: {montant} {devise}',fin:'Fim (exclusivo): {date}',reserverReception:'Reservar hoje',confirme:'Servidor confirmou a operação.',motif:'Motivo: {motif}'},
  'zh-TW': {titre:'大使館貴賓樓',bail:'外交租約',reception:'大型接待廳',indisponible:'無法確認狀態，尚未預訂。',reserver:'租用 7 天',renouveler:'續租 7 天',resilier:'提前終止（加收一天清潔費）',reserve:'此套房已被租用。',recu:'伺服器確認',refus:'預訂遭拒',acces:'僅限獲授權的外國貴賓。',suite:'每日 {prix} FR，由機構預付 7 天。每次有效睡眠 +3 行動點。',receptionTexte:'今日獨家預訂：由機構支付 1,500 PSK。',somme:'金額：{montant} {devise}',fin:'到期日（不包含）：{date}',reserverReception:'預訂今日',confirme:'伺服器已確認。',motif:'原因：{motif}'}
};
const PAVILLON_REFUS = {
  acteur_non_authentifie:'Session non authentifiée',pas_au_pavillon:'Vous devez être dans le Pavillon',
  dignitaire_etranger_requis:'Titre de dignitaire étranger requis',
  caisse_institution_absente:'Aucune caisse institutionnelle reconnue',
  pas_dans_la_piece:'Vous devez être dans la salle concernée',
  reception_deja_reservee:'Réception déjà réservée aujourd’hui',
  suite_occupee:'Cette suite est occupée',bail_non_titulaire:'Aucun bail actif à votre nom',
  solde_insuffisant:'Caisse institutionnelle insuffisante',
  caisse_absente:'Caisse de destination absente',
  parametres_invalides:'Requête invalide',piece_invalide:'Pièce inconnue'
};
let pavillonActeEnCours=false;
function pavillonT(key, vars={}) {
  const lang=typeof window!=='undefined' && (window.getLang?.() || window.i18n?.lang || localStorage.getItem('rp_lang')) || 'fr';
  const template=(PAVILLON_TEXTES[lang] || PAVILLON_TEXTES.fr)[key] || PAVILLON_TEXTES.fr[key] || key;
  return template.replace(/\{(\w+)\}/g,(_,k)=>String(vars[k] ?? ''));
}
function pavillonMotif(v) { return PAVILLON_REFUS[v?.raison] || pavillonT('motif',{motif:v?.raison||'non_confirme'}); }
function pavillonBouton(label,action,room) {
  const code='pavillonSoumettre('+JSON.stringify(action)+','+JSON.stringify(room)+')';
  return vehBouton(label,code,true);
}
async function ouvrirPavillonSuite() {
  const room=state.currentRoom;
  if(!['suite_parti','suite_privee','suite_presidentielle'].includes(room))return;
  const v=await sbRpcVerdict('pavillon_etat',{}).catch(()=>null);
  if(!v || v.transport || !v.ok){showToast(pavillonT('titre'),pavillonT('indisponible'),false);return;}
  let body='<p>'+pavillonT('suite',{prix:v.prix_jour})+'</p>';
  if(v.autorisation!==true) body+='<p>'+pavillonT('acces')+'</p>';
  else if(v.reserve && v.locataire){
    body+='<p>'+pavillonT('fin',{date:v.fin_excl})+'</p>';
    body+=pavillonBouton(pavillonT('renouveler'),'renouveler',room);
    body+=pavillonBouton(pavillonT('resilier'),'resilier',room);
  } else if (v.reserve) body+='<p>'+pavillonT('reserve')+'</p>';
  else body+=pavillonBouton(pavillonT('reserver'),'reserver',room);
  vehModal(pavillonT('bail'),body);
}
async function ouvrirPavillonReception() {
  const v=await sbRpcVerdict('pavillon_etat',{}).catch(()=>null);
  if(!v || v.transport || !v.ok){showToast(pavillonT('titre'),pavillonT('indisponible'),false);return;}
  let body='<p>'+pavillonT('receptionTexte')+'</p>';
  if(v.autorisation!==true)body+='<p>'+pavillonT('acces')+'</p>';
  else if(v.reception_reservee)body+='<p>'+pavillonT('reserve')+'</p>';
  else body+=pavillonBouton(pavillonT('reserverReception'),'reception','salle_reception');
  vehModal(pavillonT('reception'),body);
}
async function pavillonSoumettre(action,room) {
  if(pavillonActeEnCours || !['reserver','renouveler','resilier','reception'].includes(action))return;
  pavillonActeEnCours=true;
  const cle='hg-pavillon:'+String(state.char?.name||'')+':'+room+':'+action;
  try {
    let requete=sessionStorage.getItem(cle);
    if(!requete){requete=crypto.randomUUID();sessionStorage.setItem(cle,requete);}
    const v=await sbRpcVerdict('pavillon_acte',{p_requete:requete,p_action:action,p_piece:room}).catch(()=>null);
    if(v && !v.transport)sessionStorage.removeItem(cle);
    if(!v || v.ok!==true) {
      showToast(pavillonT('refus'),v?.transport?pavillonT('indisponible'):pavillonMotif(v),false);return;
    }
    document.getElementById('modal-postes')?.classList.remove('open');
    showToast(pavillonT('recu'),pavillonT('confirme')+' '+pavillonT('somme',{montant:v.montant,devise:v.devise}),true);
    if(typeof updateUI==='function')updateUI();
  } finally {pavillonActeEnCours=false; }
}
