// =====================
// PLATEAU-TRANSFERTS-DETENUS.JS
// « Demander le transfert d'un détenu » (ambassadeur, ambassades de Républia et de Sovarka) et « Demandes de transfert
// de détenus » (ministre des Affaires étrangères du pays hôte). Décision de Fred du 27/11/2026. Le serveur tranche tout
// (transfert_detenu_detenus, transfert_detenu_demander, transfert_detenu_demandes, transfert_detenu_decider).
// =====================
(function () {
  'use strict';

  const T = {
    fr: { tDemande: 'Demander le transfert d’un détenu', tDemandes: 'Demandes de transfert de détenus', refus: 'Refusé',
      reseau: 'Le serveur ne répond pas. Rien n’a été prélevé.',
      intro: 'Vos compatriotes détenus dans ce pays. La demande (1 PA) part au ministre des Affaires étrangères du pays hôte ; s’il accepte, le détenu purge chez lui le reste de sa peine.',
      introMae: 'Demandes des ambassadeurs étrangers. Si vous acceptez, le détenu est transféré dans une prison de son pays et y purge le reste de sa peine.',
      demander: 'Demander le transfert', accepter: 'Accepter', refuser: 'Refuser', aucun: 'Aucun compatriote détenu ici.', aucune: 'Aucune demande.',
      enAttente: 'Demande en attente', finJour: 'fin de peine : jour {j}', par: 'Demandé par {n} ({e})',
      envoye: 'Demande envoyée au ministre des Affaires étrangères.', accepte: 'Transfert accepté : le détenu part purger sa peine chez lui.',
      refuse: 'Transfert refusé.', s_en_attente: 'en attente', s_accepte: 'accepté', s_refuse: 'refusé', s_caduque: 'caduque',
      mesDemandes: 'Vos demandes', decidePar: 'décidé par {n}',
      e: { republic: 'Républia', soviet: 'Sovarka', narco: 'El Estado', khalija: 'Al-Khalija' },
      r: { pas_compatriote: 'Ce détenu n’est pas votre compatriote.', pas_detenu_ici: 'Ce détenu n’est pas emprisonné dans ce pays.',
        regime_particulier: 'Ce détenu relève d’un régime particulier (QHS, goulag ou interrogatoire).', demande_deja_en_cours: 'Une demande est déjà en cours pour ce détenu.',
        pays_non_ouvert: 'Le transfert ouvrira avec ce pays.', reserve_ambassadeur: 'Réservé à l’ambassadeur nommé.', pas_sur_place: 'Vous devez être à votre ambassade.',
        reserve_min_ae: 'Réservé au ministre des Affaires étrangères.', demande_introuvable: 'Demande introuvable.', demande_deja_traitee: 'Demande déjà traitée.',
        demande_caduque: 'Demande caduque : le détenu a été libéré ou sa détention a changé.', pa_insuffisants: 'Il vous manque des PA.',
        defaut: 'Action refusée. Rien n’a été prélevé.' } },
    en: { tDemande: 'Request a detainee transfer', tDemandes: 'Detainee transfer requests', refus: 'Refused',
      reseau: 'The server is not responding. Nothing was charged.',
      intro: 'Your fellow citizens detained in this country. The request (1 AP) goes to the host country’s Foreign Minister; if accepted, the detainee serves the rest of the sentence at home.',
      introMae: 'Requests from foreign ambassadors. If you accept, the detainee is moved to a prison in their own country and serves the rest of the sentence there.',
      demander: 'Request transfer', accepter: 'Accept', refuser: 'Refuse', aucun: 'No fellow citizen detained here.', aucune: 'No requests.',
      enAttente: 'Request pending', finJour: 'sentence ends: day {j}', par: 'Requested by {n} ({e})',
      envoye: 'Request sent to the Foreign Minister.', accepte: 'Transfer accepted: the detainee goes home to serve the sentence.',
      refuse: 'Transfer refused.', s_en_attente: 'pending', s_accepte: 'accepted', s_refuse: 'refused', s_caduque: 'lapsed',
      mesDemandes: 'Your requests', decidePar: 'decided by {n}',
      e: { republic: 'Républia', soviet: 'Sovarka', narco: 'El Estado', khalija: 'Al-Khalija' },
      r: { pas_compatriote: 'This detainee is not your fellow citizen.', pas_detenu_ici: 'This detainee is not imprisoned in this country.',
        regime_particulier: 'This detainee is under a special regime (QHS, gulag or interrogation).', demande_deja_en_cours: 'A request is already pending for this detainee.',
        pays_non_ouvert: 'Transfers will open with this country.', reserve_ambassadeur: 'Appointed ambassador only.', pas_sur_place: 'You must be at your embassy.',
        reserve_min_ae: 'Foreign Minister only.', demande_introuvable: 'Request not found.', demande_deja_traitee: 'Request already handled.',
        demande_caduque: 'Request lapsed: the detainee was released or the detention changed.', pa_insuffisants: 'You do not have enough AP.',
        defaut: 'Action refused. Nothing was charged.' } },
    es: { tDemande: 'Solicitar el traslado de un detenido', tDemandes: 'Solicitudes de traslado de detenidos', refus: 'Rechazado',
      reseau: 'El servidor no responde. No se ha cobrado nada.',
      intro: 'Sus compatriotas detenidos en este país. La solicitud (1 PA) va al ministro de Asuntos Exteriores del país anfitrión; si acepta, el detenido cumple el resto de la pena en su país.',
      introMae: 'Solicitudes de embajadores extranjeros. Si acepta, el detenido es trasladado a una prisión de su país y cumple allí el resto de la pena.',
      demander: 'Solicitar el traslado', accepter: 'Aceptar', refuser: 'Rechazar', aucun: 'Ningún compatriota detenido aquí.', aucune: 'Ninguna solicitud.',
      enAttente: 'Solicitud pendiente', finJour: 'fin de la pena: día {j}', par: 'Solicitado por {n} ({e})',
      envoye: 'Solicitud enviada al ministro de Asuntos Exteriores.', accepte: 'Traslado aceptado: el detenido cumplirá la pena en su país.',
      refuse: 'Traslado rechazado.', s_en_attente: 'pendiente', s_accepte: 'aceptado', s_refuse: 'rechazado', s_caduque: 'caducada',
      mesDemandes: 'Sus solicitudes', decidePar: 'decidido por {n}',
      e: { republic: 'Républia', soviet: 'Sovarka', narco: 'El Estado', khalija: 'Al-Khalija' },
      r: { pas_compatriote: 'Este detenido no es su compatriota.', pas_detenu_ici: 'Este detenido no está preso en este país.',
        regime_particulier: 'Este detenido está bajo un régimen especial (QHS, gulag o interrogatorio).', demande_deja_en_cours: 'Ya hay una solicitud en curso para este detenido.',
        pays_non_ouvert: 'El traslado se abrirá con este país.', reserve_ambassadeur: 'Reservado al embajador nombrado.', pas_sur_place: 'Debe estar en su embajada.',
        reserve_min_ae: 'Reservado al ministro de Asuntos Exteriores.', demande_introuvable: 'Solicitud no encontrada.', demande_deja_traitee: 'Solicitud ya tratada.',
        demande_caduque: 'Solicitud caducada: el detenido fue liberado o su detención cambió.', pa_insuffisants: 'Le faltan PA.',
        defaut: 'Acción rechazada. No se ha cobrado nada.' } },
    'zh-TW': { tDemande: '申請移交被拘留者', tDemandes: '被拘留者移交申請', refus: '已拒絕',
      reseau: '伺服器沒有回應。未扣除任何費用。',
      intro: '你在此國被拘留的同胞。申請（1 PA）會送交東道國外交部長；若他同意，被拘留者將回國服完剩餘刑期。',
      introMae: '外國大使的申請。若你同意，被拘留者將被移送至其本國監獄，並在那裡服完剩餘刑期。',
      demander: '申請移交', accepter: '同意', refuser: '拒絕', aucun: '這裡沒有被拘留的同胞。', aucune: '沒有申請。',
      enAttente: '申請待處理', finJour: '刑期結束：第 {j} 天', par: '由 {n}（{e}）申請',
      envoye: '申請已送交外交部長。', accepte: '移交已同意：被拘留者將回國服刑。',
      refuse: '移交已拒絕。', s_en_attente: '待處理', s_accepte: '已同意', s_refuse: '已拒絕', s_caduque: '已失效',
      mesDemandes: '你的申請', decidePar: '由 {n} 決定',
      e: { republic: 'Républia', soviet: 'Sovarka', narco: 'El Estado', khalija: 'Al-Khalija' },
      r: { pas_compatriote: '此被拘留者不是你的同胞。', pas_detenu_ici: '此被拘留者並未在此國服刑。',
        regime_particulier: '此被拘留者處於特殊制度下（QHS、古拉格或訊問中）。', demande_deja_en_cours: '此被拘留者已有申請在處理中。',
        pays_non_ouvert: '與此國的移交將於日後開放。', reserve_ambassadeur: '僅限獲任命的大使。', pas_sur_place: '你必須在你的大使館內。',
        reserve_min_ae: '僅限外交部長。', demande_introuvable: '找不到申請。', demande_deja_traitee: '申請已處理。',
        demande_caduque: '申請已失效：被拘留者已獲釋或拘留狀況已改變。', pa_insuffisants: '你的 PA 不足。',
        defaut: '操作被拒絕。未扣除任何費用。' } },
    ru: { tDemande: 'Запросить перевод заключённого', tDemandes: 'Запросы о переводе заключённых', refus: 'Отказано',
      reseau: 'Сервер не отвечает. Ничего не списано.',
      intro: 'Ваши соотечественники, задержанные в этой стране. Запрос (1 ОД) уходит министру иностранных дел принимающей страны; если он согласится, заключённый отбудет остаток срока на родине.',
      introMae: 'Запросы иностранных послов. Если вы согласитесь, заключённого переведут в тюрьму его страны, где он отбудет остаток срока.',
      demander: 'Запросить перевод', accepter: 'Принять', refuser: 'Отклонить', aucun: 'Здесь нет задержанных соотечественников.', aucune: 'Запросов нет.',
      enAttente: 'Запрос ожидает решения', finJour: 'конец срока: день {j}', par: 'Запросил {n} ({e})',
      envoye: 'Запрос отправлен министру иностранных дел.', accepte: 'Перевод принят: заключённый отбудет срок на родине.',
      refuse: 'Перевод отклонён.', s_en_attente: 'ожидает', s_accepte: 'принят', s_refuse: 'отклонён', s_caduque: 'утратил силу',
      mesDemandes: 'Ваши запросы', decidePar: 'решил {n}',
      e: { republic: 'Républia', soviet: 'Sovarka', narco: 'El Estado', khalija: 'Al-Khalija' },
      r: { pas_compatriote: 'Этот заключённый не ваш соотечественник.', pas_detenu_ici: 'Этот заключённый не отбывает срок в этой стране.',
        regime_particulier: 'Этот заключённый на особом режиме (QHS, гулаг или допрос).', demande_deja_en_cours: 'По этому заключённому уже есть запрос.',
        pays_non_ouvert: 'Переводы с этой страной откроются позже.', reserve_ambassadeur: 'Только для назначенного посла.', pas_sur_place: 'Нужно находиться в своём посольстве.',
        reserve_min_ae: 'Только для министра иностранных дел.', demande_introuvable: 'Запрос не найден.', demande_deja_traitee: 'Запрос уже рассмотрен.',
        demande_caduque: 'Запрос утратил силу: заключённый освобождён или его содержание изменилось.', pa_insuffisants: 'Не хватает ОД.',
        defaut: 'Действие отклонено. Ничего не списано.' } },
    ko: { tDemande: '구금자 이송 요청', tDemandes: '구금자 이송 요청 목록', refus: '거부됨',
      reseau: '서버가 응답하지 않습니다. 아무것도 차감되지 않았습니다.',
      intro: '이 나라에 구금된 당신의 동포들입니다. 요청(1 PA)은 주재국 외무장관에게 전달되며, 승인되면 구금자는 고국에서 남은 형기를 마칩니다.',
      introMae: '외국 대사들의 요청입니다. 승인하면 구금자는 자국 교도소로 이송되어 그곳에서 남은 형기를 마칩니다.',
      demander: '이송 요청', accepter: '승인', refuser: '거부', aucun: '이곳에 구금된 동포가 없습니다.', aucune: '요청이 없습니다.',
      enAttente: '요청 대기 중', finJour: '형기 종료: {j}일차', par: '{n}({e}) 요청',
      envoye: '외무장관에게 요청을 보냈습니다.', accepte: '이송 승인: 구금자는 고국에서 형기를 마칩니다.',
      refuse: '이송이 거부되었습니다.', s_en_attente: '대기 중', s_accepte: '승인됨', s_refuse: '거부됨', s_caduque: '효력 상실',
      mesDemandes: '당신의 요청', decidePar: '{n} 결정',
      e: { republic: 'Républia', soviet: 'Sovarka', narco: 'El Estado', khalija: 'Al-Khalija' },
      r: { pas_compatriote: '이 구금자는 당신의 동포가 아닙니다.', pas_detenu_ici: '이 구금자는 이 나라에 수감되어 있지 않습니다.',
        regime_particulier: '이 구금자는 특별 체제(QHS, 굴라크, 심문)에 있습니다.', demande_deja_en_cours: '이 구금자에 대한 요청이 이미 진행 중입니다.',
        pays_non_ouvert: '이 나라와의 이송은 나중에 열립니다.', reserve_ambassadeur: '임명된 대사 전용입니다.', pas_sur_place: '당신의 대사관에 있어야 합니다.',
        reserve_min_ae: '외무장관 전용입니다.', demande_introuvable: '요청을 찾을 수 없습니다.', demande_deja_traitee: '이미 처리된 요청입니다.',
        demande_caduque: '요청 효력 상실: 구금자가 석방되었거나 구금 상태가 바뀌었습니다.', pa_insuffisants: 'PA가 부족합니다.',
        defaut: '행동이 거부되었습니다. 아무것도 차감되지 않았습니다.' } },
    ar: { tDemande: 'طلب نقل محتجز', tDemandes: 'طلبات نقل المحتجزين', refus: 'مرفوض',
      reseau: 'الخادم لا يستجيب. لم يُخصم شيء.',
      intro: 'مواطنوك المحتجزون في هذا البلد. يُرسل الطلب (نقطة عمل واحدة) إلى وزير خارجية البلد المضيف؛ إن وافق، يقضي المحتجز بقية عقوبته في بلده.',
      introMae: 'طلبات السفراء الأجانب. إن وافقت، يُنقل المحتجز إلى سجن في بلده ويقضي فيه بقية عقوبته.',
      demander: 'طلب النقل', accepter: 'قبول', refuser: 'رفض', aucun: 'لا يوجد مواطن محتجز هنا.', aucune: 'لا توجد طلبات.',
      enAttente: 'طلب قيد الانتظار', finJour: 'نهاية العقوبة: اليوم {j}', par: 'طلبه {n} ({e})',
      envoye: 'أُرسل الطلب إلى وزير الخارجية.', accepte: 'قُبل النقل: سيقضي المحتجز عقوبته في بلده.',
      refuse: 'رُفض النقل.', s_en_attente: 'قيد الانتظار', s_accepte: 'مقبول', s_refuse: 'مرفوض', s_caduque: 'ساقط',
      mesDemandes: 'طلباتك', decidePar: 'قرّره {n}',
      e: { republic: 'Républia', soviet: 'Sovarka', narco: 'El Estado', khalija: 'Al-Khalija' },
      r: { pas_compatriote: 'هذا المحتجز ليس من مواطنيك.', pas_detenu_ici: 'هذا المحتجز ليس مسجونًا في هذا البلد.',
        regime_particulier: 'هذا المحتجز يخضع لنظام خاص (QHS أو الغولاغ أو الاستجواب).', demande_deja_en_cours: 'يوجد طلب قيد المعالجة لهذا المحتجز.',
        pays_non_ouvert: 'سيُفتح النقل مع هذا البلد لاحقًا.', reserve_ambassadeur: 'مخصص للسفير المعيّن.', pas_sur_place: 'يجب أن تكون في سفارتك.',
        reserve_min_ae: 'مخصص لوزير الخارجية.', demande_introuvable: 'الطلب غير موجود.', demande_deja_traitee: 'سبقت معالجة الطلب.',
        demande_caduque: 'سقط الطلب: أُفرج عن المحتجز أو تغيّر احتجازه.', pa_insuffisants: 'تنقصك نقاط عمل.',
        defaut: 'رُفض الإجراء. لم يُخصم شيء.' } },
    'pt-BR': { tDemande: 'Pedir a transferência de um detido', tDemandes: 'Pedidos de transferência de detidos', refus: 'Recusado',
      reseau: 'O servidor não responde. Nada foi cobrado.',
      intro: 'Seus compatriotas detidos neste país. O pedido (1 PA) vai ao ministro das Relações Exteriores do país anfitrião; se ele aceitar, o detido cumpre o resto da pena em casa.',
      introMae: 'Pedidos de embaixadores estrangeiros. Se você aceitar, o detido é levado a uma prisão do seu país e lá cumpre o resto da pena.',
      demander: 'Pedir a transferência', accepter: 'Aceitar', refuser: 'Recusar', aucun: 'Nenhum compatriota detido aqui.', aucune: 'Nenhum pedido.',
      enAttente: 'Pedido pendente', finJour: 'fim da pena: dia {j}', par: 'Pedido por {n} ({e})',
      envoye: 'Pedido enviado ao ministro das Relações Exteriores.', accepte: 'Transferência aceita: o detido vai cumprir a pena em casa.',
      refuse: 'Transferência recusada.', s_en_attente: 'pendente', s_accepte: 'aceito', s_refuse: 'recusado', s_caduque: 'caducado',
      mesDemandes: 'Seus pedidos', decidePar: 'decidido por {n}',
      e: { republic: 'Républia', soviet: 'Sovarka', narco: 'El Estado', khalija: 'Al-Khalija' },
      r: { pas_compatriote: 'Este detido não é seu compatriota.', pas_detenu_ici: 'Este detido não está preso neste país.',
        regime_particulier: 'Este detido está sob regime especial (QHS, gulag ou interrogatório).', demande_deja_en_cours: 'Já há um pedido em andamento para este detido.',
        pays_non_ouvert: 'A transferência abrirá com este país.', reserve_ambassadeur: 'Reservado ao embaixador nomeado.', pas_sur_place: 'Você precisa estar na sua embaixada.',
        reserve_min_ae: 'Reservado ao ministro das Relações Exteriores.', demande_introuvable: 'Pedido não encontrado.', demande_deja_traitee: 'Pedido já tratado.',
        demande_caduque: 'Pedido caducado: o detido foi solto ou a detenção mudou.', pa_insuffisants: 'Faltam PA.',
        defaut: 'Ação recusada. Nada foi cobrado.' } },
    de: { tDemande: 'Überstellung eines Gefangenen beantragen', tDemandes: 'Anträge auf Überstellung von Gefangenen', refus: 'Abgelehnt',
      reseau: 'Der Server antwortet nicht. Nichts wurde abgebucht.',
      intro: 'Ihre in diesem Land inhaftierten Landsleute. Der Antrag (1 AP) geht an den Außenminister des Gastlandes; stimmt er zu, verbüßt der Gefangene den Rest der Strafe in der Heimat.',
      introMae: 'Anträge ausländischer Botschafter. Wenn Sie zustimmen, wird der Gefangene in ein Gefängnis seines Landes verlegt und verbüßt dort den Rest der Strafe.',
      demander: 'Überstellung beantragen', accepter: 'Annehmen', refuser: 'Ablehnen', aucun: 'Hier ist kein Landsmann inhaftiert.', aucune: 'Keine Anträge.',
      enAttente: 'Antrag ausstehend', finJour: 'Strafende: Tag {j}', par: 'Beantragt von {n} ({e})',
      envoye: 'Antrag an den Außenminister gesendet.', accepte: 'Überstellung angenommen: Der Gefangene verbüßt die Strafe in der Heimat.',
      refuse: 'Überstellung abgelehnt.', s_en_attente: 'ausstehend', s_accepte: 'angenommen', s_refuse: 'abgelehnt', s_caduque: 'hinfällig',
      mesDemandes: 'Ihre Anträge', decidePar: 'entschieden von {n}',
      e: { republic: 'Républia', soviet: 'Sovarka', narco: 'El Estado', khalija: 'Al-Khalija' },
      r: { pas_compatriote: 'Dieser Gefangene ist nicht Ihr Landsmann.', pas_detenu_ici: 'Dieser Gefangene sitzt nicht in diesem Land ein.',
        regime_particulier: 'Dieser Gefangene unterliegt einem Sonderregime (QHS, Gulag oder Verhör).', demande_deja_en_cours: 'Für diesen Gefangenen läuft bereits ein Antrag.',
        pays_non_ouvert: 'Überstellungen mit diesem Land öffnen später.', reserve_ambassadeur: 'Nur für den ernannten Botschafter.', pas_sur_place: 'Sie müssen in Ihrer Botschaft sein.',
        reserve_min_ae: 'Nur für den Außenminister.', demande_introuvable: 'Antrag nicht gefunden.', demande_deja_traitee: 'Antrag bereits bearbeitet.',
        demande_caduque: 'Antrag hinfällig: Der Gefangene wurde freigelassen oder seine Haft hat sich geändert.', pa_insuffisants: 'Ihnen fehlen AP.',
        defaut: 'Aktion abgelehnt. Nichts wurde abgebucht.' } }
  };

  function langue() {
    const brut = (typeof i18next !== 'undefined' && i18next.language) ? String(i18next.language) : 'fr';
    if (T[brut]) return brut;
    const court = brut.slice(0, 2).toLowerCase();
    if (court === 'zh') return 'zh-TW';
    if (court === 'pt') return 'pt-BR';
    return T[court] ? court : 'fr';
  }
  function t(cle, vars) {
    const l = T[langue()] || T.fr;
    let s = (l[cle] !== undefined ? l[cle] : T.fr[cle]) || cle;
    Object.keys(vars || {}).forEach(k => { s = s.split('{' + k + '}').join(String(vars[k])); });
    return s;
  }
  function motif(v) { const l = T[langue()] || T.fr, r = v && v.raison; return (r && (l.r[r] || T.fr.r[r])) || l.r.defaut; }
  function empire(e) { const l = T[langue()] || T.fr; return (l.e && l.e[e]) || e; }
  function echapper(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  }
  async function rpc(nom, params) {
    if (typeof sbRpcVerdict !== 'function') return null;
    try { return await sbRpcVerdict(nom, params || {}); } catch (_) { return null; }
  }
  function ouvrir(titre, corps) {
    const t1 = document.getElementById('postes-modal-title'), b = document.getElementById('postes-body'),
          m = document.getElementById('modal-postes');
    if (!t1 || !b || !m) return null;
    t1.textContent = titre;
    b.innerHTML = '<div class="cpj-dialogue transferts-detenus" dir="auto">' + corps + '</div>';
    m.classList.add('open');
    return b;
  }
  const bouton = (libelle, attr, primaire) => '<button type="button" class="cpj-touche' + (primaire ? ' cpj-primaire' : '') + '" ' + attr + '>' + echapper(libelle) + '</button>';
  function empireDuBureau() {
    const carte = (typeof AMBASSADE_ROOM_EMPIRE_MAP !== 'undefined') ? AMBASSADE_ROOM_EMPIRE_MAP : null;
    return carte && typeof state !== 'undefined' ? carte[state.currentRoom] : null;
  }

  let occupe = false;
  async function ouvrirTransfertDetenu() {
    const e = empireDuBureau();
    const v = await rpc('transfert_detenu_detenus', { p_empire: e });
    if (!v) { showToast(t('tDemande'), t('reseau'), false); return; }
    if (v.ok !== true) { showToast(t('refus'), motif(v), false); return; }
    const detenus = Array.isArray(v.detenus) ? v.detenus : [], demandes = Array.isArray(v.demandes) ? v.demandes : [];
    let corps = '<p class="cpj-note">' + echapper(t('intro')) + '</p>' + (detenus.length ? detenus.map(d =>
      '<div style="display:flex;flex-wrap:wrap;gap:.6rem;align-items:center;margin:.35rem 0"><span><strong>' + echapper(d.nom) + '</strong> — '
        + echapper(t('finJour', { j: d.jour_fin })) + '</span>'
        + (d.en_attente ? '<span class="cpj-note">' + echapper(t('enAttente')) + '</span>'
          : d.refus ? '<span class="cpj-note">' + echapper(motif({ raison: d.refus })) + '</span>'
          : bouton(t('demander'), 'data-transfert="' + echapper(d.nom) + '"', true)) + '</div>').join('')
      : '<p class="cpj-note">' + echapper(t('aucun')) + '</p>');
    if (demandes.length) corps += '<p><strong>' + echapper(t('mesDemandes')) + '</strong></p>' + demandes.map(d => '<div class="cpj-note">'
      + echapper(d.detenu) + ' — ' + echapper(t('s_' + d.statut)) + (d.decideur ? ' (' + echapper(t('decidePar', { n: d.decideur })) + ')' : '') + '</div>').join('');
    const b = ouvrir(t('tDemande'), corps); if (!b) return;
    b.querySelectorAll('[data-transfert]').forEach(el => el.addEventListener('click', () => demander(e, el.getAttribute('data-transfert'))));
  }
  async function demander(e, nom) {
    if (occupe) return;
    occupe = true;
    try {
      const v = await rpc('transfert_detenu_demander', { p_empire: e, p_detenu: nom });
      if (!v) { showToast(t('tDemande'), t('reseau'), false); return; }
      if (v.ok !== true) { showToast(t('refus'), motif(v), false); return; }
      if (typeof appliquerPaiementServeur === 'function' && v.paie) appliquerPaiementServeur(v.paie);
      showToast(t('tDemande'), t('envoye'), true);
      if (typeof addJournalEntry === 'function') addJournalEntry(t('tDemande') + ' : ' + nom, 'event-info');
      if (typeof updateUI === 'function') updateUI();
    } finally { occupe = false; }
    await ouvrirTransfertDetenu();
  }

  async function ouvrirDemandesTransfert() {
    const v = await rpc('transfert_detenu_demandes', {});
    if (!v) { showToast(t('tDemandes'), t('reseau'), false); return; }
    if (v.ok !== true) { showToast(t('refus'), motif(v), false); return; }
    const liste = Array.isArray(v.demandes) ? v.demandes : [];
    const corps = '<p class="cpj-note">' + echapper(t('introMae')) + '</p>' + (liste.length ? liste.map(d =>
      '<div style="margin:.5rem 0;padding-bottom:.4rem;border-bottom:1px solid rgba(169,141,86,.3)"><div><strong>' + echapper(d.detenu) + '</strong></div>'
        + '<div class="cpj-note">' + echapper(t('par', { n: d.ambassadeur, e: empire(d.empire) })) + '</div>'
        + (d.statut === 'en_attente'
          ? '<div style="display:flex;gap:.6rem;margin-top:.3rem">' + bouton(t('accepter'), 'data-demande="' + Number(d.id) + '" data-decision="accepter"', true)
            + bouton(t('refuser'), 'data-demande="' + Number(d.id) + '" data-decision="refuser"', false) + '</div>'
          : '<div class="cpj-note">' + echapper(t('s_' + d.statut)) + (d.decideur ? ' — ' + echapper(t('decidePar', { n: d.decideur })) : '') + '</div>')
        + '</div>').join('') : '<p class="cpj-note">' + echapper(t('aucune')) + '</p>');
    const b = ouvrir(t('tDemandes'), corps); if (!b) return;
    b.querySelectorAll('[data-demande]').forEach(el => el.addEventListener('click', () => decider(Number(el.getAttribute('data-demande')), el.getAttribute('data-decision'))));
  }
  async function decider(id, decision) {
    if (occupe) return;
    occupe = true;
    try {
      const v = await rpc('transfert_detenu_decider', { p_id: id, p_decision: decision });
      if (!v) { showToast(t('tDemandes'), t('reseau'), false); return; }
      if (v.ok !== true) { showToast(t('refus'), motif(v), false); return; }
      showToast(t('tDemandes'), t(decision === 'accepter' ? 'accepte' : 'refuse'), true);
    } finally { occupe = false; }
    await ouvrirDemandesTransfert();
  }

  window.ouvrirTransfertDetenu = ouvrirTransfertDetenu;
  window.ouvrirDemandesTransfert = ouvrirDemandesTransfert;
  window.RP_TRANSFERTS_DETENUS_T = T;
})();
