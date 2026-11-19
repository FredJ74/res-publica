// SYNDICAT NATIONAL DE SOVARKA (Fred, 18/11/2026, « Décisions du 18/11 », points 3 et 7 ; GAME-DESIGN-NOVOMIRSK.md).
// Bureau du syndicat national (mairies de Novomirsk, Krasnov, Starovka) : adhérer, consulter, quitter, élire le chef
// (moteur générique des organisations), « Manifestation de soutien au président » (ordre du chef). Le serveur décide
// de tout (migration 20261118053000) ; l'écran n'affiche que ses verdicts. Textes dans les neuf langues.
(function (global) {
'use strict';
const ID = 'orga_syndicat_etat_soviet';
const T = {
  fr: {
    title: 'Syndicat national', joined: 'Vous êtes désormais adhérent du Syndicat national de Sovarka.',
    alreadyMember: 'Vous êtes déjà membre du Syndicat national.', notMember: 'Vous n’êtes pas membre du Syndicat national.',
    left: 'Vous avez rendu votre carte du Syndicat national.', chefOnly: 'Réservé au chef du Syndicat national.',
    chief: 'Chef : {chef}', members: 'Syndiqués : {n}',
    rule: 'Manifestation de soutien au président : ordre du chef, 10 syndiqués au moins, une par jour et par ville. Chaque syndiqué présent dans la ville défile et paie 2 PA (pas à 3 PA ou moins). Taux = présents ÷ domiciliés ; au-dessus de 50 %, +1 de popularité par tranche de 5 % (plafond +10), en dessous −1 par tranche.',
    rallyDone: '{presents} syndiqué(s) dans le cortège pour {domicilies} domicilié(s) : participation {taux} %.',
    effectPlus: 'Popularité du président : +{n}.', effectMinus: 'Désaveu : popularité du président {n}.',
    effectNone: 'Aucun effet sur la popularité du président.', effectNoPj: 'Président non joueur ou présidence vacante : aucun effet.',
    electionPrompt: 'Motivez votre décision : elle sera publiée.', electionBtn: 'Déclencher l’élection',
    electionRunning: 'Une élection est déjà en cours.', tooEarly: 'Encore {n} jour(s) avant une nouvelle élection.',
    m_pas_au_bureau_syndical: 'Rendez-vous au bureau du syndicat national d’une mairie de Sovarka.',
    m_syndicat_trop_petit: 'Il faut au moins 10 syndiqués.', m_deja_manifeste_aujourdhui: 'Une manifestation a déjà eu lieu aujourd’hui dans cette ville.',
    m_fonds_insuffisants: '15 PSK requis.', m_pa_insuffisants: 'PA insuffisants.', refused: 'Le serveur a refusé l’opération.'
  },
  en: {
    title: 'National union', joined: 'You are now a member of the Sovarka National Union.',
    alreadyMember: 'You are already a member of the National Union.', notMember: 'You are not a member of the National Union.',
    left: 'You handed back your National Union card.', chefOnly: 'Reserved for the leader of the National Union.',
    chief: 'Leader: {chef}', members: 'Members: {n}',
    rule: 'Rally in support of the president: ordered by the leader, at least 10 members, once per day and per city. Every member present in the city marches and pays 2 AP (not at 3 AP or less). Rate = present ÷ residents; above 50%, +1 popularity per 5% step (cap +10), below −1 per step.',
    rallyDone: '{presents} member(s) in the procession for {domicilies} resident(s): turnout {taux}%.',
    effectPlus: 'President’s popularity: +{n}.', effectMinus: 'Disavowal: president’s popularity {n}.',
    effectNone: 'No effect on the president’s popularity.', effectNoPj: 'Non-player president or vacant presidency: no effect.',
    electionPrompt: 'Explain your decision: it will be published.', electionBtn: 'Call the election',
    electionRunning: 'An election is already under way.', tooEarly: '{n} more day(s) before a new election.',
    m_pas_au_bureau_syndical: 'Go to the national union office in a Sovarka town hall.',
    m_syndicat_trop_petit: 'At least 10 members are required.', m_deja_manifeste_aujourdhui: 'A rally has already taken place in this city today.',
    m_fonds_insuffisants: '15 PSK required.', m_pa_insuffisants: 'Not enough AP.', refused: 'The server refused the operation.'
  },
  es: {
    title: 'Sindicato nacional', joined: 'Ahora es afiliado del Sindicato nacional de Sovarka.',
    alreadyMember: 'Ya es miembro del Sindicato nacional.', notMember: 'No es miembro del Sindicato nacional.',
    left: 'Ha devuelto su carné del Sindicato nacional.', chefOnly: 'Reservado al jefe del Sindicato nacional.',
    chief: 'Jefe: {chef}', members: 'Afiliados: {n}',
    rule: 'Manifestación de apoyo al presidente: orden del jefe, al menos 10 afiliados, una por día y por ciudad. Cada afiliado presente en la ciudad desfila y paga 2 PA (no con 3 PA o menos). Tasa = presentes ÷ domiciliados; por encima del 50 %, +1 de popularidad por tramo de 5 % (tope +10), por debajo −1 por tramo.',
    rallyDone: '{presents} afiliado(s) en el cortejo para {domicilies} domiciliado(s): participación {taux} %.',
    effectPlus: 'Popularidad del presidente: +{n}.', effectMinus: 'Desaire: popularidad del presidente {n}.',
    effectNone: 'Ningún efecto en la popularidad del presidente.', effectNoPj: 'Presidente no jugador o presidencia vacante: sin efecto.',
    electionPrompt: 'Motive su decisión: se publicará.', electionBtn: 'Convocar la elección',
    electionRunning: 'Ya hay una elección en curso.', tooEarly: 'Faltan {n} día(s) para una nueva elección.',
    m_pas_au_bureau_syndical: 'Vaya a la oficina del sindicato nacional de un ayuntamiento de Sovarka.',
    m_syndicat_trop_petit: 'Se necesitan al menos 10 afiliados.', m_deja_manifeste_aujourdhui: 'Hoy ya hubo una manifestación en esta ciudad.',
    m_fonds_insuffisants: 'Se requieren 15 PSK.', m_pa_insuffisants: 'PA insuficientes.', refused: 'El servidor rechazó la operación.'
  },
  'zh-TW': {
    title: '全國工會', joined: '您現在是索瓦爾卡全國工會的會員。',
    alreadyMember: '您已是全國工會會員。', notMember: '您不是全國工會會員。',
    left: '您已交回全國工會會員證。', chefOnly: '僅限全國工會主席。',
    chief: '主席：{chef}', members: '會員：{n}',
    rule: '支持總統遊行：由主席下令，至少 10 名會員，每市每日一次。市內每位在場會員都會參加並支付 2 行動點（行動點 3 點以下者不參加）。比率 = 在場人數 ÷ 戶籍人數；高於 50 % 時每 5 % 人氣 +1（上限 +10），低於時每級 −1。',
    rallyDone: '遊行隊伍中有 {presents} 名會員，戶籍會員 {domicilies} 名：參與率 {taux} %。',
    effectPlus: '總統人氣：+{n}。', effectMinus: '不信任：總統人氣 {n}。',
    effectNone: '對總統人氣沒有影響。', effectNoPj: '總統非玩家或總統職位空缺：沒有影響。',
    electionPrompt: '請說明您的決定：將會公開。', electionBtn: '發起選舉',
    electionRunning: '已有選舉正在進行。', tooEarly: '還需 {n} 天才能再次選舉。',
    m_pas_au_bureau_syndical: '請前往索瓦爾卡市政廳的全國工會辦公室。',
    m_syndicat_trop_petit: '至少需要 10 名會員。', m_deja_manifeste_aujourdhui: '本市今天已經舉行過遊行。',
    m_fonds_insuffisants: '需要 15 PSK。', m_pa_insuffisants: '行動點不足。', refused: '伺服器拒絕了此操作。'
  },
  ru: {
    title: 'Национальный профсоюз', joined: 'Теперь вы член Национального профсоюза Соварки.',
    alreadyMember: 'Вы уже состоите в Национальном профсоюзе.', notMember: 'Вы не состоите в Национальном профсоюзе.',
    left: 'Вы сдали билет Национального профсоюза.', chefOnly: 'Только для председателя Национального профсоюза.',
    chief: 'Председатель: {chef}', members: 'Членов: {n}',
    rule: 'Манифестация в поддержку президента: по приказу председателя, не менее 10 членов, одна в день в каждом городе. Каждый член профсоюза, находящийся в городе, идёт в колонне и платит 2 ОД (кроме тех, у кого 3 ОД или меньше). Доля = присутствующие ÷ прописанные; выше 50 % — +1 популярности за каждые 5 % (не более +10), ниже — −1 за каждые 5 %.',
    rallyDone: 'В колонне {presents} член(ов) профсоюза при {domicilies} прописанных: явка {taux} %.',
    effectPlus: 'Популярность президента: +{n}.', effectMinus: 'Недоверие: популярность президента {n}.',
    effectNone: 'Популярность президента не изменилась.', effectNoPj: 'Президент — не игрок или пост вакантен: без последствий.',
    electionPrompt: 'Обоснуйте решение: оно будет опубликовано.', electionBtn: 'Объявить выборы',
    electionRunning: 'Выборы уже идут.', tooEarly: 'До новых выборов ещё {n} дн.',
    m_pas_au_bureau_syndical: 'Пройдите в бюро национального профсоюза в мэрии Соварки.',
    m_syndicat_trop_petit: 'Нужно не менее 10 членов.', m_deja_manifeste_aujourdhui: 'Сегодня в этом городе уже была манифестация.',
    m_fonds_insuffisants: 'Нужно 15 PSK.', m_pa_insuffisants: 'Недостаточно ОД.', refused: 'Сервер отклонил операцию.'
  },
  ko: {
    title: '전국 노동조합', joined: '이제 소바르카 전국 노동조합의 조합원입니다.',
    alreadyMember: '이미 전국 노동조합의 조합원입니다.', notMember: '전국 노동조합의 조합원이 아닙니다.',
    left: '전국 노동조합 조합원증을 반납했습니다.', chefOnly: '전국 노동조합 위원장 전용입니다.',
    chief: '위원장: {chef}', members: '조합원: {n}',
    rule: '대통령 지지 집회: 위원장의 명령, 조합원 최소 10명, 도시별 하루 한 번. 도시에 있는 모든 조합원이 행진하며 2 AP를 냅니다(AP가 3 이하이면 제외). 비율 = 참석자 ÷ 거주 등록자; 50 % 초과 시 5 %마다 인기 +1(최대 +10), 미만 시 5 %마다 −1.',
    rallyDone: '행렬에 조합원 {presents}명, 거주 등록 조합원 {domicilies}명: 참여율 {taux} %.',
    effectPlus: '대통령 인기: +{n}.', effectMinus: '불신임: 대통령 인기 {n}.',
    effectNone: '대통령 인기에 영향이 없습니다.', effectNoPj: '대통령이 플레이어가 아니거나 공석: 효과 없음.',
    electionPrompt: '결정 이유를 적으세요. 공개됩니다.', electionBtn: '선거 시작',
    electionRunning: '이미 선거가 진행 중입니다.', tooEarly: '새 선거까지 {n}일 남았습니다.',
    m_pas_au_bureau_syndical: '소바르카 시청의 전국 노동조합 사무실로 가세요.',
    m_syndicat_trop_petit: '조합원이 최소 10명 필요합니다.', m_deja_manifeste_aujourdhui: '오늘 이 도시에서 이미 집회가 열렸습니다.',
    m_fonds_insuffisants: '15 PSK가 필요합니다.', m_pa_insuffisants: 'AP가 부족합니다.', refused: '서버가 작업을 거부했습니다.'
  },
  ar: {
    title: 'النقابة الوطنية', joined: 'أصبحت الآن منتسبًا إلى النقابة الوطنية لسوفاركا.',
    alreadyMember: 'أنت منتسب بالفعل إلى النقابة الوطنية.', notMember: 'لست منتسبًا إلى النقابة الوطنية.',
    left: 'أعدت بطاقة النقابة الوطنية.', chefOnly: 'مخصص لرئيس النقابة الوطنية.',
    chief: 'الرئيس: {chef}', members: 'المنتسبون: {n}',
    rule: 'مظاهرة دعم الرئيس: بأمر من الرئيس، 10 منتسبين على الأقل، مرة واحدة في اليوم لكل مدينة. يسير كل منتسب موجود في المدينة ويدفع 2 نقطة عمل (إلا من لديه 3 نقاط أو أقل). النسبة = الحاضرون ÷ المقيمون؛ فوق 50 % تزيد الشعبية 1 عن كل 5 % (حتى +10)، وتحتها تنقص 1 عن كل 5 %.',
    rallyDone: '{presents} منتسب في الموكب مقابل {domicilies} مقيم: نسبة المشاركة {taux} %.',
    effectPlus: 'شعبية الرئيس: +{n}.', effectMinus: 'تبرؤ: شعبية الرئيس {n}.',
    effectNone: 'لا أثر على شعبية الرئيس.', effectNoPj: 'رئيس غير لاعب أو رئاسة شاغرة: لا أثر.',
    electionPrompt: 'علّل قرارك: سيُنشر.', electionBtn: 'الدعوة إلى الانتخاب',
    electionRunning: 'هناك انتخاب جارٍ بالفعل.', tooEarly: 'بقي {n} يوم قبل انتخاب جديد.',
    m_pas_au_bureau_syndical: 'توجه إلى مكتب النقابة الوطنية في إحدى بلديات سوفاركا.',
    m_syndicat_trop_petit: 'يلزم 10 منتسبين على الأقل.', m_deja_manifeste_aujourdhui: 'جرت مظاهرة اليوم بالفعل في هذه المدينة.',
    m_fonds_insuffisants: 'يلزم 15 PSK.', m_pa_insuffisants: 'نقاط العمل غير كافية.', refused: 'رفض الخادم العملية.'
  },
  'pt-BR': {
    title: 'Sindicato nacional', joined: 'Agora você é filiado ao Sindicato nacional de Sovarka.',
    alreadyMember: 'Você já é membro do Sindicato nacional.', notMember: 'Você não é membro do Sindicato nacional.',
    left: 'Você devolveu sua carteira do Sindicato nacional.', chefOnly: 'Reservado ao chefe do Sindicato nacional.',
    chief: 'Chefe: {chef}', members: 'Filiados: {n}',
    rule: 'Manifestação de apoio ao presidente: ordem do chefe, ao menos 10 filiados, uma por dia e por cidade. Cada filiado presente na cidade desfila e paga 2 PA (não com 3 PA ou menos). Taxa = presentes ÷ domiciliados; acima de 50 %, +1 de popularidade por faixa de 5 % (teto +10), abaixo −1 por faixa.',
    rallyDone: '{presents} filiado(s) no cortejo para {domicilies} domiciliado(s): participação {taux} %.',
    effectPlus: 'Popularidade do presidente: +{n}.', effectMinus: 'Desaprovação: popularidade do presidente {n}.',
    effectNone: 'Nenhum efeito na popularidade do presidente.', effectNoPj: 'Presidente não jogador ou presidência vaga: sem efeito.',
    electionPrompt: 'Justifique sua decisão: ela será publicada.', electionBtn: 'Convocar a eleição',
    electionRunning: 'Já há uma eleição em andamento.', tooEarly: 'Faltam {n} dia(s) para uma nova eleição.',
    m_pas_au_bureau_syndical: 'Vá ao escritório do sindicato nacional de uma prefeitura de Sovarka.',
    m_syndicat_trop_petit: 'São necessários ao menos 10 filiados.', m_deja_manifeste_aujourdhui: 'Já houve uma manifestação hoje nesta cidade.',
    m_fonds_insuffisants: '15 PSK necessários.', m_pa_insuffisants: 'PA insuficientes.', refused: 'O servidor recusou a operação.'
  },
  de: {
    title: 'Nationale Gewerkschaft', joined: 'Sie sind jetzt Mitglied der Nationalen Gewerkschaft Sowarkas.',
    alreadyMember: 'Sie sind bereits Mitglied der Nationalen Gewerkschaft.', notMember: 'Sie sind kein Mitglied der Nationalen Gewerkschaft.',
    left: 'Sie haben Ihren Ausweis der Nationalen Gewerkschaft zurückgegeben.', chefOnly: 'Dem Vorsitzenden der Nationalen Gewerkschaft vorbehalten.',
    chief: 'Vorsitzender: {chef}', members: 'Mitglieder: {n}',
    rule: 'Kundgebung zur Unterstützung des Präsidenten: auf Befehl des Vorsitzenden, mindestens 10 Mitglieder, einmal pro Tag und Stadt. Jedes in der Stadt anwesende Mitglied marschiert mit und zahlt 2 AP (nicht bei 3 AP oder weniger). Quote = Anwesende ÷ Gemeldete; über 50 % +1 Beliebtheit je 5 %-Stufe (höchstens +10), darunter −1 je Stufe.',
    rallyDone: '{presents} Mitglied(er) im Zug bei {domicilies} Gemeldeten: Beteiligung {taux} %.',
    effectPlus: 'Beliebtheit des Präsidenten: +{n}.', effectMinus: 'Missbilligung: Beliebtheit des Präsidenten {n}.',
    effectNone: 'Keine Auswirkung auf die Beliebtheit des Präsidenten.', effectNoPj: 'Präsident kein Spieler oder Amt vakant: keine Auswirkung.',
    electionPrompt: 'Begründen Sie Ihre Entscheidung: Sie wird veröffentlicht.', electionBtn: 'Wahl ausrufen',
    electionRunning: 'Es läuft bereits eine Wahl.', tooEarly: 'Noch {n} Tag(e) bis zu einer neuen Wahl.',
    m_pas_au_bureau_syndical: 'Gehen Sie in das Büro der Nationalen Gewerkschaft in einem Rathaus Sowarkas.',
    m_syndicat_trop_petit: 'Mindestens 10 Mitglieder sind nötig.', m_deja_manifeste_aujourdhui: 'In dieser Stadt fand heute bereits eine Kundgebung statt.',
    m_fonds_insuffisants: '15 PSK erforderlich.', m_pa_insuffisants: 'Nicht genug AP.', refused: 'Der Server hat den Vorgang abgelehnt.'
  }
};
function langue() {
  const l = (global.RPPlateauI18n && typeof global.RPPlateauI18n.language === 'function' && global.RPPlateauI18n.language())
    || (global.i18next && global.i18next.language) || 'fr';
  return T[l] ? l : (T[String(l).split('-')[0]] ? String(l).split('-')[0] : 'fr');
}
function texteSyndicatEtat(cle, vars) {
  const s = (T[langue()] && T[langue()][cle]) || T.fr[cle] || cle;
  return String(s).replace(/\{(\w+)\}/g, (m, k) => (vars && Object.prototype.hasOwnProperty.call(vars, k)) ? String(vars[k]) : m);
}
const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const motif = v => (v && T.fr['m_' + v.raison]) ? texteSyndicatEtat('m_' + v.raison)
  : (v && v.raison === 'deja_membre') ? texteSyndicatEtat('alreadyMember')
  : (v && v.raison === 'reserve_au_chef') ? texteSyndicatEtat('chefOnly') : texteSyndicatEtat('refused');

function getSyndicatEtat() { return (typeof state !== 'undefined' && state && (state.organisations || []).find(o => o.id === ID)) || null; }
function getChefSyndicatEtat() { return getSyndicatEtat()?.chef || null; }
async function chargerSyndicatEtat() {
  if (!getSyndicatEtat() && typeof global.chargerOrganisations === 'function') await global.chargerOrganisations();
  return getSyndicatEtat();
}
const estMembre = o => !!o?.membres?.some(m => (m.nom || m) === state?.char?.name);

async function doAdhererSyndicatEtat() {
  const orga = await chargerSyndicatEtat();
  if (!orga) { global.showToast(texteSyndicatEtat('title'), texteSyndicatEtat('refused'), false); return; }
  if (estMembre(orga)) { global.showToast(texteSyndicatEtat('title'), texteSyndicatEtat('alreadyMember'), false); return; }
  const grades = global.TYPES_ORGANISATIONS?.syndicale?.grades?.soviet || ['Adherent'];
  const r = typeof global.sbCaisseCollective === 'function'
    ? await global.sbCaisseCollective('organisation_adhesion_payante', { p_orga: ID, p_grade: grades[0] }, [ID, 'adhesion'])
    : { ok: false, raison: 'reponse_absente' };
  if (!r || !r.ok) { global.showToast(texteSyndicatEtat('title'), motif(r), false); return; }
  if (r.paiement && typeof global.appliquerPaiementServeur === 'function') global.appliquerPaiementServeur(r.paiement);
  if (typeof global.chargerOrganisations === 'function') await global.chargerOrganisations();
  if (typeof global.updateUI === 'function') global.updateUI();
  global.showToast(texteSyndicatEtat('title'), texteSyndicatEtat('joined'), true, true);
  if (typeof global.addJournalEntry === 'function') global.addJournalEntry('Adhésion au Syndicat national de Sovarka (-15 PSK, cotisation unique).', 'event-good');
}

async function doConsulterSyndicatEtat() {
  const orga = await chargerSyndicatEtat();
  if (!orga) { global.showToast(texteSyndicatEtat('title'), texteSyndicatEtat('refused'), false); return; }
  const noms = (orga.membres || []).map(m => m.nom || m);
  const titre = document.getElementById('postes-modal-title'), corps = document.getElementById('postes-body');
  if (!titre || !corps) return;
  titre.textContent = orga.nom || texteSyndicatEtat('title');
  corps.innerHTML = '<div style="padding:1rem" dir="auto">' +
    '<p>' + esc(texteSyndicatEtat('chief', { chef: String(orga.chef || '—').replace(' (PNJ)', '') })) + '</p>' +
    '<p>' + esc(texteSyndicatEtat('members', { n: noms.length })) + '</p>' +
    (noms.length ? '<ul style="margin:.3rem 0 .8rem 1rem">' + noms.map(n => '<li>' + esc(n) + '</li>').join('') + '</ul>' : '') +
    '<p style="font-size:.8rem;color:#a09070">' + esc(texteSyndicatEtat('rule')) + '</p></div>';
  document.getElementById('modal-postes')?.classList.add('open');
}

async function doQuitterSyndicatEtat() {
  const orga = await chargerSyndicatEtat();
  if (!estMembre(orga)) { global.showToast(texteSyndicatEtat('title'), texteSyndicatEtat('notMember'), false); return; }
  const ok = typeof global.organisationEssayerCommande === 'function'
    && await global.organisationEssayerCommande(ID, 'quitter', { nom: state.char.name });
  if (!ok) return;
  if (typeof global.updateUI === 'function') global.updateUI();
  global.showToast(texteSyndicatEtat('title'), texteSyndicatEtat('left'), true);
}

async function doDeclencherElectionSyndicatEtat(pa, cost) {
  const orga = await chargerSyndicatEtat();
  if (!estMembre(orga)) { global.showToast(texteSyndicatEtat('title'), texteSyndicatEtat('notMember'), false); return; }
  if (orga.election?.enCours) { global.showToast(texteSyndicatEtat('title'), texteSyndicatEtat('electionRunning'), false); return; }
  const jour = state.day || 1;
  if (orga.election?.derniereElection && (jour - orga.election.derniereElection) < 7) {
    global.showToast(texteSyndicatEtat('title'), texteSyndicatEtat('tooEarly', { n: 7 - (jour - orga.election.derniereElection) }), false); return;
  }
  document.getElementById('postes-modal-title').textContent = texteSyndicatEtat('electionBtn');
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem" dir="auto">' +
    '<div style="font-size:.8rem;color:#8a8060;margin-bottom:.6rem">' + esc(texteSyndicatEtat('electionPrompt')) + '</div>' +
    '<textarea id="election-motivation" rows="4" dir="auto" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;box-sizing:border-box;margin-bottom:.6rem"></textarea>' +
    '<button onclick="confirmerDeclenchementElection(\'' + ID + '\',' + (Number(pa) || 0) + ',' + (Number(cost) || 0) + ')" style="width:100%;font-family:Bebas Neue,sans-serif;padding:.55rem;border:1px solid #8a6a20;background:transparent;color:#c8a84b;cursor:pointer">' + esc(texteSyndicatEtat('electionBtn')) + '</button></div>';
  document.getElementById('modal-postes')?.classList.add('open');
}

let manifEnCours = false;
async function doManifestationSoutienPresident() {
  if (manifEnCours) return;
  const orga = await chargerSyndicatEtat();
  if (!orga || orga.chef !== state?.char?.name) { global.showToast(texteSyndicatEtat('title'), texteSyndicatEtat('chefOnly'), false); return; }
  manifEnCours = true;
  const cle = 'hg-syndicat-etat:' + (state.char?.name || '') + ':manif';
  try {
    let requete = sessionStorage.getItem(cle);
    if (!requete) { requete = crypto.randomUUID(); sessionStorage.setItem(cle, requete); }
    const v = await global.sbRpcVerdict('syndicat_etat_manifester', { p_requete: requete }).catch(() => null);
    if (v && !v.transport) sessionStorage.removeItem(cle);
    if (!v || v.ok !== true) { global.showToast(texteSyndicatEtat('title'), motif(v), false); return; }
    if (typeof v.pa === 'number') state.pa = v.pa;
    const effet = !v.president_pj ? texteSyndicatEtat('effectNoPj')
      : v.effet_pop > 0 ? texteSyndicatEtat('effectPlus', { n: v.effet_pop })
      : v.effet_pop < 0 ? texteSyndicatEtat('effectMinus', { n: v.effet_pop }) : texteSyndicatEtat('effectNone');
    global.showToast(texteSyndicatEtat('title'), texteSyndicatEtat('rallyDone', { presents: v.presents, domicilies: v.domicilies, taux: v.taux }) + ' ' + effet, true, true);
    if (typeof global.addJournalEntry === 'function') global.addJournalEntry('Manifestation de soutien au président : ' + v.presents + ' syndiqué(s), participation ' + v.taux + ' %.', 'event-good');
    if (typeof global.updateUI === 'function') global.updateUI();
  } finally { manifEnCours = false; }
}

Object.assign(global, { RPSyndicatEtatI18n: { textes: T }, texteSyndicatEtat, getSyndicatEtat, getChefSyndicatEtat,
  doAdhererSyndicatEtat, doConsulterSyndicatEtat, doQuitterSyndicatEtat, doDeclencherElectionSyndicatEtat, doManifestationSoutienPresident });
})(typeof window !== 'undefined' ? window : globalThis);
