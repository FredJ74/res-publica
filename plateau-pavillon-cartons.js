// =====================
// PLATEAU-PAVILLON-CARTONS.JS
// Réception à la Grande Salle du Pavillon des Ambassadeurs (Novomirsk) : cartons d'invitation (décision de Fred du
// 27/11/2026). Celui qui a réservé la salle pour aujourd'hui choisit ses invités ; chacun reçoit un carton nominatif
// (inventaire + courrier). L'invité « Donne » le carton à un PNJ de l'accueil : la Grande Salle lui est ouverte jusqu'à
// minuit. Le serveur décide tout (pavillon_cartons_etat, pavillon_cartons_envoyer, pavillon_carton_remettre).
// =====================
(function () {
  'use strict';

  const T = {
    fr: { titre: 'Cartons d’invitation', choisir: 'Choisir les invités', envoyer: 'Envoyer les cartons', refus: 'Refusé',
      reseau: 'Le serveur ne répond pas.', intro: 'Cochez les joueurs à inviter ce soir. Chacun reçoit un carton nominatif dans son inventaire et un message au courrier. Le carton n’est valable qu’aujourd’hui.',
      dejaInvites: 'Déjà invités : {n}', aucun: 'Aucun joueur à inviter.', envoyes: '{n} carton(s) envoyé(s).', filtre: 'Chercher un nom',
      remis: 'L’hôtesse prend votre carton sans un regard pour votre nom : la Grande Salle vous est ouverte jusqu’à minuit.',
      r: { reception_non_reservee: 'Réservez d’abord la Grande Salle pour aujourd’hui.', aucun_invite: 'Choisissez au moins un invité.',
        trop_d_invites: 'Quarante invités au plus par envoi.', pas_a_l_accueil: 'Le carton se remet à l’accueil du Pavillon.',
        pnj_accueil_requis: 'Le carton se remet à une hôtesse ou au garde de l’accueil.', pas_un_carton: 'Ce n’est pas un carton d’invitation.',
        carton_pas_valable_aujourdhui: 'Ce carton n’est pas valable aujourd’hui.', objet_introuvable: 'Objet introuvable dans votre inventaire.',
        defaut: 'Action refusée.' } },
    en: { titre: 'Invitation cards', choisir: 'Choose the guests', envoyer: 'Send the cards', refus: 'Refused',
      reseau: 'The server is not responding.', intro: 'Tick the players to invite tonight. Each receives a named card in their inventory and a message by mail. The card is valid today only.',
      dejaInvites: 'Already invited: {n}', aucun: 'No player to invite.', envoyes: '{n} card(s) sent.', filtre: 'Search a name',
      remis: 'The hostess takes your card without a glance at your name: the Grand Hall is open to you until midnight.',
      r: { reception_non_reservee: 'First book the Grand Hall for today.', aucun_invite: 'Choose at least one guest.',
        trop_d_invites: 'Forty guests at most per sending.', pas_a_l_accueil: 'The card is handed in at the Pavilion reception.',
        pnj_accueil_requis: 'Hand the card to a hostess or the reception guard.', pas_un_carton: 'This is not an invitation card.',
        carton_pas_valable_aujourdhui: 'This card is not valid today.', objet_introuvable: 'Item not found in your inventory.',
        defaut: 'Action refused.' } },
    es: { titre: 'Tarjetas de invitación', choisir: 'Elegir a los invitados', envoyer: 'Enviar las tarjetas', refus: 'Rechazado',
      reseau: 'El servidor no responde.', intro: 'Marque a los jugadores que invita esta noche. Cada uno recibe una tarjeta nominativa en su inventario y un mensaje por correo. La tarjeta solo vale hoy.',
      dejaInvites: 'Ya invitados: {n}', aucun: 'Ningún jugador que invitar.', envoyes: '{n} tarjeta(s) enviada(s).', filtre: 'Buscar un nombre',
      remis: 'La azafata toma su tarjeta sin mirar su nombre: el Gran Salón le queda abierto hasta medianoche.',
      r: { reception_non_reservee: 'Reserve primero el Gran Salón para hoy.', aucun_invite: 'Elija al menos un invitado.',
        trop_d_invites: 'Cuarenta invitados como máximo por envío.', pas_a_l_accueil: 'La tarjeta se entrega en la recepción del Pabellón.',
        pnj_accueil_requis: 'Entregue la tarjeta a una azafata o al guardia de la recepción.', pas_un_carton: 'No es una tarjeta de invitación.',
        carton_pas_valable_aujourdhui: 'Esta tarjeta no vale hoy.', objet_introuvable: 'Objeto no encontrado en su inventario.',
        defaut: 'Acción rechazada.' } },
    'zh-TW': { titre: '邀請函', choisir: '選擇賓客', envoyer: '寄出邀請函', refus: '已拒絕',
      reseau: '伺服器沒有回應。', intro: '勾選今晚要邀請的玩家。每人都會在物品欄收到一張記名邀請函，並收到一封郵件。邀請函僅限今日有效。',
      dejaInvites: '已邀請：{n}', aucun: '沒有可邀請的玩家。', envoyes: '已寄出 {n} 張邀請函。', filtre: '搜尋姓名',
      remis: '接待員收下你的邀請函，看也不看你的名字：大廳對你開放至午夜。',
      r: { reception_non_reservee: '請先預訂今日的大廳。', aucun_invite: '請至少選擇一位賓客。',
        trop_d_invites: '每次最多邀請四十位。', pas_a_l_accueil: '邀請函須在貴賓樓接待處交出。',
        pnj_accueil_requis: '請把邀請函交給接待員或接待處警衛。', pas_un_carton: '這不是邀請函。',
        carton_pas_valable_aujourdhui: '這張邀請函今天無效。', objet_introuvable: '物品欄中找不到此物品。',
        defaut: '操作被拒絕。' } },
    ru: { titre: 'Пригласительные билеты', choisir: 'Выбрать гостей', envoyer: 'Отправить приглашения', refus: 'Отказано',
      reseau: 'Сервер не отвечает.', intro: 'Отметьте игроков, которых приглашаете сегодня вечером. Каждый получит именной билет в инвентарь и письмо по почте. Билет действует только сегодня.',
      dejaInvites: 'Уже приглашены: {n}', aucun: 'Некого пригласить.', envoyes: 'Отправлено билетов: {n}.', filtre: 'Искать имя',
      remis: 'Хозяйка берёт ваш билет, даже не взглянув на имя: Большой зал открыт для вас до полуночи.',
      r: { reception_non_reservee: 'Сначала забронируйте Большой зал на сегодня.', aucun_invite: 'Выберите хотя бы одного гостя.',
        trop_d_invites: 'Не более сорока гостей за раз.', pas_a_l_accueil: 'Билет сдаётся у входа в Павильон.',
        pnj_accueil_requis: 'Отдайте билет хозяйке или охраннику у входа.', pas_un_carton: 'Это не пригласительный билет.',
        carton_pas_valable_aujourdhui: 'Этот билет сегодня не действует.', objet_introuvable: 'Предмет не найден в инвентаре.',
        defaut: 'Действие отклонено.' } },
    ko: { titre: '초대장', choisir: '손님 고르기', envoyer: '초대장 보내기', refus: '거부됨',
      reseau: '서버가 응답하지 않습니다.', intro: '오늘 밤 초대할 플레이어를 선택하세요. 각자 인벤토리에 기명 초대장과 우편 메시지를 받습니다. 초대장은 오늘만 유효합니다.',
      dejaInvites: '이미 초대됨: {n}', aucun: '초대할 플레이어가 없습니다.', envoyes: '초대장 {n}장을 보냈습니다.', filtre: '이름 검색',
      remis: '안내원이 당신의 이름은 보지도 않고 초대장을 받습니다. 대연회장은 자정까지 당신에게 열려 있습니다.',
      r: { reception_non_reservee: '먼저 오늘의 대연회장을 예약하세요.', aucun_invite: '손님을 한 명 이상 고르세요.',
        trop_d_invites: '한 번에 최대 40명까지입니다.', pas_a_l_accueil: '초대장은 파빌리온 안내 데스크에서 냅니다.',
        pnj_accueil_requis: '안내원이나 안내 데스크 경비에게 초대장을 건네세요.', pas_un_carton: '초대장이 아닙니다.',
        carton_pas_valable_aujourdhui: '이 초대장은 오늘 유효하지 않습니다.', objet_introuvable: '인벤토리에서 물건을 찾을 수 없습니다.',
        defaut: '행동이 거부되었습니다.' } },
    ar: { titre: 'بطاقات الدعوة', choisir: 'اختيار الضيوف', envoyer: 'إرسال البطاقات', refus: 'مرفوض',
      reseau: 'الخادم لا يستجيب.', intro: 'حدّد اللاعبين الذين تدعوهم الليلة. يتلقى كل منهم بطاقة اسمية في مخزونه ورسالة بالبريد. البطاقة صالحة اليوم فقط.',
      dejaInvites: 'مدعوون سابقًا: {n}', aucun: 'لا يوجد لاعب لدعوته.', envoyes: 'أُرسلت {n} بطاقة.', filtre: 'ابحث عن اسم',
      remis: 'تأخذ المضيفة بطاقتك دون أن تنظر إلى اسمك: القاعة الكبرى مفتوحة لك حتى منتصف الليل.',
      r: { reception_non_reservee: 'احجز القاعة الكبرى لهذا اليوم أولًا.', aucun_invite: 'اختر ضيفًا واحدًا على الأقل.',
        trop_d_invites: 'أربعون ضيفًا على الأكثر في كل إرسال.', pas_a_l_accueil: 'تُسلَّم البطاقة في استقبال الجناح.',
        pnj_accueil_requis: 'سلّم البطاقة إلى مضيفة أو إلى حارس الاستقبال.', pas_un_carton: 'هذه ليست بطاقة دعوة.',
        carton_pas_valable_aujourdhui: 'هذه البطاقة غير صالحة اليوم.', objet_introuvable: 'الغرض غير موجود في مخزونك.',
        defaut: 'رُفض الإجراء.' } },
    'pt-BR': { titre: 'Convites', choisir: 'Escolher os convidados', envoyer: 'Enviar os convites', refus: 'Recusado',
      reseau: 'O servidor não responde.', intro: 'Marque os jogadores que vai convidar hoje à noite. Cada um recebe um convite nominal no inventário e uma mensagem pelo correio. O convite só vale hoje.',
      dejaInvites: 'Já convidados: {n}', aucun: 'Nenhum jogador para convidar.', envoyes: '{n} convite(s) enviado(s).', filtre: 'Buscar um nome',
      remis: 'A recepcionista pega seu convite sem olhar seu nome: o Grande Salão fica aberto para você até a meia-noite.',
      r: { reception_non_reservee: 'Reserve primeiro o Grande Salão para hoje.', aucun_invite: 'Escolha ao menos um convidado.',
        trop_d_invites: 'No máximo quarenta convidados por envio.', pas_a_l_accueil: 'O convite é entregue na recepção do Pavilhão.',
        pnj_accueil_requis: 'Entregue o convite a uma recepcionista ou ao guarda da recepção.', pas_un_carton: 'Isto não é um convite.',
        carton_pas_valable_aujourdhui: 'Este convite não vale hoje.', objet_introuvable: 'Objeto não encontrado no seu inventário.',
        defaut: 'Ação recusada.' } },
    de: { titre: 'Einladungskarten', choisir: 'Gäste auswählen', envoyer: 'Karten verschicken', refus: 'Abgelehnt',
      reseau: 'Der Server antwortet nicht.', intro: 'Kreuzen Sie die Spieler an, die Sie heute Abend einladen. Jeder erhält eine persönliche Karte ins Inventar und eine Nachricht per Post. Die Karte gilt nur heute.',
      dejaInvites: 'Bereits eingeladen: {n}', aucun: 'Kein Spieler zum Einladen.', envoyes: '{n} Karte(n) verschickt.', filtre: 'Namen suchen',
      remis: 'Die Hostess nimmt Ihre Karte, ohne auf Ihren Namen zu schauen: Der Große Saal steht Ihnen bis Mitternacht offen.',
      r: { reception_non_reservee: 'Reservieren Sie zuerst den Großen Saal für heute.', aucun_invite: 'Wählen Sie mindestens einen Gast.',
        trop_d_invites: 'Höchstens vierzig Gäste pro Versand.', pas_a_l_accueil: 'Die Karte wird am Empfang des Pavillons abgegeben.',
        pnj_accueil_requis: 'Geben Sie die Karte einer Hostess oder dem Wachmann am Empfang.', pas_un_carton: 'Das ist keine Einladungskarte.',
        carton_pas_valable_aujourdhui: 'Diese Karte gilt heute nicht.', objet_introuvable: 'Gegenstand nicht im Inventar gefunden.',
        defaut: 'Aktion abgelehnt.' } }
  };

  function langue() {
    const brut = (typeof window !== 'undefined' && window.RPPlateauI18n && window.RPPlateauI18n.language && window.RPPlateauI18n.language())
      || ((typeof i18next !== 'undefined' && i18next.language) ? String(i18next.language) : 'fr');
    if (T[brut]) return brut;
    const court = String(brut).slice(0, 2).toLowerCase();
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
  function echapper(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  }
  async function rpc(nom, params) {
    if (typeof sbRpcVerdict !== 'function') return null;
    try { return await sbRpcVerdict(nom, params || {}); } catch (_) { return null; }
  }

  async function ouvrirCartonsInvitation() {
    const v = await rpc('pavillon_cartons_etat', {});
    if (!v) { showToast(t('titre'), t('reseau'), false); return; }
    if (v.ok !== true) { showToast(t('refus'), motif(v), false); return; }
    const invites = new Set(v.invites || []);
    const joueurs = (v.joueurs || []).filter(n => !invites.has(n));
    const t1 = document.getElementById('postes-modal-title'), b = document.getElementById('postes-body'), m = document.getElementById('modal-postes');
    if (!t1 || !b || !m) return;
    t1.textContent = t('titre');
    b.innerHTML = '<div class="cpj-dialogue pavillon-cartons" dir="auto"><p class="cpj-note">' + echapper(t('intro')) + '</p>'
      + (invites.size ? '<p class="cpj-note">' + echapper(t('dejaInvites', { n: [...invites].join(', ') })) + '</p>' : '')
      + (joueurs.length
        ? '<input class="cpj-champ" id="cartons-filtre" placeholder="' + echapper(t('filtre')) + '" style="width:100%;margin-bottom:.5rem">'
          + '<div id="cartons-liste" style="max-height:40vh;overflow:auto;display:flex;flex-direction:column;gap:.25rem">'
          + joueurs.map(n => '<label data-nom="' + echapper(n.toLowerCase()) + '"><input type="checkbox" value="' + echapper(n) + '"> ' + echapper(n) + '</label>').join('')
          + '</div><div style="margin-top:.8rem"><button type="button" class="cpj-touche cpj-primaire" id="cartons-envoyer">' + echapper(t('envoyer')) + '</button></div>'
        : '<p class="cpj-note">' + echapper(t('aucun')) + '</p>') + '</div>';
    m.classList.add('open');
    const filtre = b.querySelector('#cartons-filtre');
    if (filtre) filtre.addEventListener('input', () => {
      const q = filtre.value.trim().toLowerCase();
      b.querySelectorAll('#cartons-liste label').forEach(l => { l.style.display = !q || l.getAttribute('data-nom').includes(q) ? '' : 'none'; });
    });
    const bouton = b.querySelector('#cartons-envoyer');
    if (bouton) bouton.addEventListener('click', async () => {
      const choix = [...b.querySelectorAll('#cartons-liste input:checked')].map(i => i.value);
      bouton.disabled = true;
      try {
        const r = await rpc('pavillon_cartons_envoyer', { p_invites: choix });
        if (!r) { showToast(t('titre'), t('reseau'), false); return; }
        if (r.ok !== true) { showToast(t('refus'), motif(r), false); return; }
        showToast(t('titre'), t('envoyes', { n: r.envoyes }), true);
      } finally { bouton.disabled = false; }
      await ouvrirCartonsInvitation();
    });
  }

  // Appelé depuis le don d'objet à un PNJ (confirmerDonObjetPnj) quand l'objet est un carton d'invitation.
  async function remettreCartonInvitation(index, objet, nomPnj) {
    const signature = typeof signatureObjetInventaire === 'function' ? signatureObjetInventaire(objet) : null;
    if (!signature) return;
    const v = await rpc('pavillon_carton_remettre', { p_index: index, p_signature: signature, p_pnj: nomPnj });
    if (!v) { showToast(t('titre'), t('reseau'), false); return; }
    if (v.ok !== true) { showToast(t('refus'), motif(v), false); return; }
    if (typeof sbAdopterInventaireServeur === 'function') sbAdopterInventaireServeur(v);
    if (typeof renderInventory === 'function') renderInventory();
    if (typeof updateUI === 'function') updateUI();
    showToast(t('titre'), t('remis'), true);
  }

  // Faux carton d'invitation (« Falsifier un document », Fred, 27/11/2026) : le faussaire choisit la date de la réception
  // et, s'il le veut, le nom inscrit. Le serveur reçoit 'faux_carton|AAAA-MM-JJ|nom' (crime_falsifier ou faux_document_imprimer).
  const TF = {
    fr: { titre: 'Faux carton d’invitation', note: 'Choisissez la date de la réception ; le nom inscrit est facultatif. Un faux réussi vaut un vrai carton pour une seule remise à l’accueil du Pavillon.', date: 'Date de la réception', nom: 'Nom inscrit (facultatif)', valider: 'Falsifier', dateRequise: 'Indiquez une date.' },
    en: { titre: 'Forged invitation card', note: 'Choose the date of the reception; the name written on it is optional. A successful forgery is as good as a real card for one hand-in at the Pavilion reception.', date: 'Reception date', nom: 'Name written (optional)', valider: 'Forge', dateRequise: 'Enter a date.' },
    es: { titre: 'Tarjeta de invitación falsa', note: 'Elija la fecha de la recepción; el nombre escrito es opcional. Una falsificación lograda vale como una tarjeta auténtica para una sola entrega en la recepción del Pabellón.', date: 'Fecha de la recepción', nom: 'Nombre escrito (opcional)', valider: 'Falsificar', dateRequise: 'Indique una fecha.' },
    'zh-TW': { titre: '偽造邀請函', note: '選擇招待會日期；寫上的姓名可不填。偽造成功的邀請函等同真品，可在貴賓樓接待處交出一次。', date: '招待會日期', nom: '寫上的姓名（可不填）', valider: '偽造', dateRequise: '請填寫日期。' },
    ru: { titre: 'Поддельный пригласительный билет', note: 'Выберите дату приёма; имя на билете можно не указывать. Удачная подделка стоит настоящего билета на одну сдачу у входа в Павильон.', date: 'Дата приёма', nom: 'Имя на билете (необязательно)', valider: 'Подделать', dateRequise: 'Укажите дату.' },
    ko: { titre: '위조 초대장', note: '연회 날짜를 고르세요. 적을 이름은 선택 사항입니다. 위조에 성공하면 파빌리온 안내 데스크에 한 번 낼 때까지 진짜 초대장과 같습니다.', date: '연회 날짜', nom: '적을 이름(선택)', valider: '위조하기', dateRequise: '날짜를 입력하세요.' },
    ar: { titre: 'بطاقة دعوة مزوّرة', note: 'اختر تاريخ الحفل؛ الاسم المكتوب اختياري. التزوير الناجح يساوي بطاقة حقيقية لتسليم واحد في استقبال الجناح.', date: 'تاريخ الحفل', nom: 'الاسم المكتوب (اختياري)', valider: 'تزوير', dateRequise: 'أدخل تاريخًا.' },
    'pt-BR': { titre: 'Convite falso', note: 'Escolha a data da recepção; o nome escrito é opcional. Uma falsificação bem-sucedida vale um convite verdadeiro para uma única entrega na recepção do Pavilhão.', date: 'Data da recepção', nom: 'Nome escrito (opcional)', valider: 'Falsificar', dateRequise: 'Indique uma data.' },
    de: { titre: 'Gefälschte Einladungskarte', note: 'Wählen Sie das Datum des Empfangs; der eingetragene Name ist freiwillig. Eine gelungene Fälschung gilt wie eine echte Karte für eine einzige Abgabe am Empfang des Pavillons.', date: 'Datum des Empfangs', nom: 'Eingetragener Name (freiwillig)', valider: 'Fälschen', dateRequise: 'Geben Sie ein Datum an.' }
  };
  const tf = k => ((TF[langue()] || TF.fr)[k] || TF.fr[k]);
  function fauxCartonOuvrir(mode, pa, cost) {
    const t1 = document.getElementById('postes-modal-title'), b = document.getElementById('postes-body'), m = document.getElementById('modal-postes');
    if (!t1 || !b || !m) return;
    const auj = new Date().toLocaleDateString('sv-SE', { timeZone: 'Europe/Paris' });
    t1.textContent = tf('titre');
    b.innerHTML = '<div class="cpj-dialogue" dir="auto"><p class="cpj-note">' + echapper(tf('note')) + '</p>'
      + '<label class="cpj-note">' + echapper(tf('date')) + ' <input type="date" id="faux-carton-date" class="cpj-champ" value="' + auj + '"></label> '
      + '<input type="text" id="faux-carton-nom" maxlength="60" class="cpj-champ" placeholder="' + echapper(tf('nom')) + '"> '
      + '<button type="button" class="cpj-touche cpj-primaire" id="faux-carton-ok">' + echapper(tf('valider')) + '</button></div>';
    m.classList.add('open');
    b.querySelector('#faux-carton-ok').addEventListener('click', () => {
      const date = String(b.querySelector('#faux-carton-date').value || '');
      if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) { showToast(tf('titre'), tf('dateRequise'), false); return; }
      const nom = String(b.querySelector('#faux-carton-nom').value || '').replace(/\|/g, ' ').trim();
      const doc = ['faux_carton', date, nom].join('|');
      m.classList.remove('open');
      if (mode === 'greffe') { if (typeof confirmerFalsification === 'function') confirmerFalsification(doc, pa, cost); }
      else if (typeof fauxImprimer === 'function') fauxImprimer(doc);
    });
  }
  window.fauxCartonOuvrir = fauxCartonOuvrir;
  window.RP_FAUX_CARTON_T = TF;
  window.ouvrirCartonsInvitation = ouvrirCartonsInvitation;
  window.remettreCartonInvitation = remettreCartonInvitation;
  window.cartonsInvitationLibelle = () => t('choisir');
  window.RP_PAVILLON_CARTONS_T = T;
})();
