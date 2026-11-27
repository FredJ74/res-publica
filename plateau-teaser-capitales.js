// =====================
// PLATEAU-TEASER-CAPITALES.JS
// Ciudad Roja et Al Madina en teaser (décision 17, codée le 28/11/2026) : le reste d'El Estado et d'Al-Khalija reste fermé.
// Les départs en bus ou en taxi et la flèche du bas de la rue de l'hôtel affichent « Accès interdit ! » et un gros point
// d'interrogation cerclé ; un clic sur ce point ouvre le compteur d'ouverture, calculé par le serveur
// (teaser_ouverture_compteur) : 150 PJ actifs dans chacune des six villes de Républia et de Sovarka, et tous les postes de
// ministre, de maire et d'adjoint occupés par des joueurs.
// =====================
(function () {
  'use strict';

  const T = {
    fr: { titre: 'Accès interdit !', message: 'Accès interdit ! Il sera ouvert quand Républia et Sovarka seront suffisamment peuplées. Parlez du jeu autour de vous pour accélérer son ouverture !',
      aide: 'Voir les conditions d’ouverture', conditions: 'Conditions d’ouverture', villes: 'Au moins 150 joueurs actifs (connectés dans les 7 derniers jours et domiciliés dans la ville) dans chacune des six villes :',
      postes: 'Et tous ces postes occupés par des joueurs :', occupe: 'occupé', vacant: 'vacant', rempli: 'Toutes les conditions sont remplies : l’ouverture approche !',
      actifs: '{n} / {requis} joueurs actifs', reseau: 'Le compteur est indisponible pour l’instant.',
      p: { min_ae: 'Ministre des Affaires étrangères', min_def: 'Ministre de la Défense', min_fin: 'Ministre des Finances', min_info: 'Ministre de l’Information', min_int: 'Ministre de l’Intérieur', min_just: 'Ministre de la Justice', maire: 'Maire', maire_adjoint: 'Maire adjoint' } },
    en: { titre: 'No entry!', message: 'No entry! It will open when Républia and Sovarka are populated enough. Tell people about the game to speed up its opening!',
      aide: 'See the opening conditions', conditions: 'Opening conditions', villes: 'At least 150 active players (logged in within the last 7 days and domiciled in the city) in each of the six cities:',
      postes: 'And all these posts held by players:', occupe: 'held', vacant: 'vacant', rempli: 'All conditions are met: the opening is near!',
      actifs: '{n} / {requis} active players', reseau: 'The counter is unavailable for now.',
      p: { min_ae: 'Foreign Minister', min_def: 'Defence Minister', min_fin: 'Finance Minister', min_info: 'Information Minister', min_int: 'Interior Minister', min_just: 'Justice Minister', maire: 'Mayor', maire_adjoint: 'Deputy Mayor' } },
    es: { titre: '¡Acceso prohibido!', message: '¡Acceso prohibido! Se abrirá cuando Républia y Sovarka estén lo bastante pobladas. ¡Hable del juego a su alrededor para acelerar su apertura!',
      aide: 'Ver las condiciones de apertura', conditions: 'Condiciones de apertura', villes: 'Al menos 150 jugadores activos (conectados en los últimos 7 días y domiciliados en la ciudad) en cada una de las seis ciudades:',
      postes: 'Y todos estos puestos ocupados por jugadores:', occupe: 'ocupado', vacant: 'vacante', rempli: 'Se cumplen todas las condiciones: ¡la apertura se acerca!',
      actifs: '{n} / {requis} jugadores activos', reseau: 'El contador no está disponible por ahora.',
      p: { min_ae: 'Ministro de Asuntos Exteriores', min_def: 'Ministro de Defensa', min_fin: 'Ministro de Finanzas', min_info: 'Ministro de Información', min_int: 'Ministro del Interior', min_just: 'Ministro de Justicia', maire: 'Alcalde', maire_adjoint: 'Teniente de alcalde' } },
    'zh-TW': { titre: '禁止進入！', message: '禁止進入！當 Républia 與 Sovarka 人口足夠時便會開放。向身邊的人介紹這款遊戲，加快它的開放！',
      aide: '查看開放條件', conditions: '開放條件', villes: '六座城市各自至少有 150 名活躍玩家（最近 7 天內上線且居住在該城市）：',
      postes: '並且以下職位皆由玩家擔任：', occupe: '已就任', vacant: '空缺', rempli: '所有條件皆已達成：開放即將到來！',
      actifs: '{n} / {requis} 名活躍玩家', reseau: '計數器目前無法使用。',
      p: { min_ae: '外交部長', min_def: '國防部長', min_fin: '財政部長', min_info: '新聞部長', min_int: '內政部長', min_just: '司法部長', maire: '市長', maire_adjoint: '副市長' } },
    ru: { titre: 'Вход запрещён!', message: 'Вход запрещён! Он откроется, когда Républia и Sovarka будут достаточно населены. Расскажите об игре знакомым, чтобы ускорить открытие!',
      aide: 'Условия открытия', conditions: 'Условия открытия', villes: 'Не менее 150 активных игроков (заходивших за последние 7 дней и проживающих в городе) в каждом из шести городов:',
      postes: 'И все эти должности заняты игроками:', occupe: 'занято', vacant: 'вакантно', rempli: 'Все условия выполнены: открытие близко!',
      actifs: '{n} / {requis} активных игроков', reseau: 'Счётчик пока недоступен.',
      p: { min_ae: 'Министр иностранных дел', min_def: 'Министр обороны', min_fin: 'Министр финансов', min_info: 'Министр информации', min_int: 'Министр внутренних дел', min_just: 'Министр юстиции', maire: 'Мэр', maire_adjoint: 'Заместитель мэра' } },
    ko: { titre: '출입 금지!', message: '출입 금지! Républia와 Sovarka에 사람이 충분히 모이면 열립니다. 주변에 게임을 알려 개방을 앞당겨 주세요!',
      aide: '개방 조건 보기', conditions: '개방 조건', villes: '여섯 도시 각각에 활성 플레이어(최근 7일 내 접속, 해당 도시 거주) 150명 이상:',
      postes: '그리고 다음 직책이 모두 플레이어로 채워져야 합니다:', occupe: '재직', vacant: '공석', rempli: '모든 조건이 충족되었습니다. 개방이 가까워졌습니다!',
      actifs: '활성 플레이어 {n} / {requis}명', reseau: '지금은 집계를 볼 수 없습니다.',
      p: { min_ae: '외무장관', min_def: '국방장관', min_fin: '재무장관', min_info: '정보장관', min_int: '내무장관', min_just: '법무장관', maire: '시장', maire_adjoint: '부시장' } },
    ar: { titre: 'الدخول ممنوع!', message: 'الدخول ممنوع! سيُفتح حين تصبح Républia وSovarka مأهولتين بما يكفي. تحدّث عن اللعبة حولك لتسريع افتتاحها!',
      aide: 'عرض شروط الافتتاح', conditions: 'شروط الافتتاح', villes: '150 لاعبًا نشطًا على الأقل (اتصلوا خلال الأيام السبعة الأخيرة ويقيمون في المدينة) في كل مدينة من المدن الست:',
      postes: 'وجميع هذه المناصب يشغلها لاعبون:', occupe: 'مشغول', vacant: 'شاغر', rempli: 'تحققت كل الشروط: الافتتاح يقترب!',
      actifs: '{n} / {requis} لاعبًا نشطًا', reseau: 'العدّاد غير متاح حاليًا.',
      p: { min_ae: 'وزير الخارجية', min_def: 'وزير الدفاع', min_fin: 'وزير المالية', min_info: 'وزير الإعلام', min_int: 'وزير الداخلية', min_just: 'وزير العدل', maire: 'رئيس البلدية', maire_adjoint: 'نائب رئيس البلدية' } },
    'pt-BR': { titre: 'Acesso proibido!', message: 'Acesso proibido! Será aberto quando Républia e Sovarka estiverem povoadas o bastante. Fale do jogo ao seu redor para acelerar a abertura!',
      aide: 'Ver as condições de abertura', conditions: 'Condições de abertura', villes: 'Pelo menos 150 jogadores ativos (conectados nos últimos 7 dias e domiciliados na cidade) em cada uma das seis cidades:',
      postes: 'E todos estes cargos ocupados por jogadores:', occupe: 'ocupado', vacant: 'vago', rempli: 'Todas as condições foram cumpridas: a abertura está próxima!',
      actifs: '{n} / {requis} jogadores ativos', reseau: 'O contador está indisponível no momento.',
      p: { min_ae: 'Ministro das Relações Exteriores', min_def: 'Ministro da Defesa', min_fin: 'Ministro das Finanças', min_info: 'Ministro da Informação', min_int: 'Ministro do Interior', min_just: 'Ministro da Justiça', maire: 'Prefeito', maire_adjoint: 'Vice-prefeito' } },
    de: { titre: 'Zutritt verboten!', message: 'Zutritt verboten! Er öffnet, sobald Républia und Sovarka ausreichend bevölkert sind. Erzählen Sie anderen vom Spiel, um die Öffnung zu beschleunigen!',
      aide: 'Öffnungsbedingungen ansehen', conditions: 'Öffnungsbedingungen', villes: 'Mindestens 150 aktive Spieler (in den letzten 7 Tagen eingeloggt und in der Stadt wohnhaft) in jeder der sechs Städte:',
      postes: 'Und alle diese Ämter von Spielern besetzt:', occupe: 'besetzt', vacant: 'unbesetzt', rempli: 'Alle Bedingungen sind erfüllt: Die Öffnung naht!',
      actifs: '{n} / {requis} aktive Spieler', reseau: 'Der Zähler ist derzeit nicht verfügbar.',
      p: { min_ae: 'Außenminister', min_def: 'Verteidigungsminister', min_fin: 'Finanzminister', min_info: 'Informationsminister', min_int: 'Innenminister', min_just: 'Justizminister', maire: 'Bürgermeister', maire_adjoint: 'Stellvertretender Bürgermeister' } }
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
  const poste = id => ((T[langue()] || T.fr).p[id]) || T.fr.p[id] || id;
  function echapper(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  }
  function nomVille(pays, ville) {
    const v = typeof WORLD !== 'undefined' && WORLD[pays] && WORLD[pays][ville];
    return (v && v.name) || ville;
  }
  function nomPays(pays) {
    return (typeof COUNTRIES !== 'undefined' && COUNTRIES[pays] && COUNTRIES[pays].name) || pays;
  }
  function ouvrir(titre, corps) {
    const t1 = document.getElementById('postes-modal-title'), b = document.getElementById('postes-body'), m = document.getElementById('modal-postes');
    if (!t1 || !b || !m) return null;
    t1.textContent = titre;
    b.innerHTML = '<div class="cpj-dialogue teaser-capitales" dir="auto">' + corps + '</div>';
    m.classList.add('open');
    return b;
  }

  function teaserAccesInterdit() {
    const b = ouvrir(t('titre'), '<p style="font-size:1.05rem;text-align:center;margin:.4rem 0 1rem">' + echapper(t('message')) + '</p>'
      + '<div style="text-align:center"><button type="button" id="teaser-aide" aria-label="' + echapper(t('aide')) + '" title="' + echapper(t('aide')) + '" '
      + 'class="cpj-touche" style="width:72px;height:72px;border-radius:50%;font-size:2.6rem;line-height:1;padding:0">?</button></div>');
    if (b) b.querySelector('#teaser-aide').addEventListener('click', teaserCompteur);
  }

  async function teaserCompteur() {
    let v = null;
    if (typeof sbRpcVerdict === 'function') { try { v = await sbRpcVerdict('teaser_ouverture_compteur', {}); } catch (_) { v = null; } }
    if (!v || v.ok !== true) { if (typeof showToast === 'function') showToast(t('conditions'), t('reseau'), false); return; }
    const marque = ok => ok ? '✔' : '✖';
    const villes = (v.villes || []).map(x => '<li>' + marque(x.atteint) + ' ' + echapper(nomVille(x.pays, x.ville)) + ' (' + echapper(nomPays(x.pays)) + ') — '
      + echapper(t('actifs', { n: x.actifs, requis: x.requis })) + '</li>').join('');
    const postes = (v.postes || []).map(x => '<li>' + marque(x.occupe) + ' ' + echapper(poste(x.poste)) + (x.ville ? ' — ' + echapper(nomVille(x.pays, x.ville)) : '')
      + ' (' + echapper(nomPays(x.pays)) + ') : ' + echapper(t(x.occupe ? 'occupe' : 'vacant')) + '</li>').join('');
    ouvrir(t('conditions'), (v.conditions_remplies ? '<p><strong>' + echapper(t('rempli')) + '</strong></p>' : '')
      + '<p>' + echapper(t('villes')) + '</p><ul style="margin:.3rem 0 .8rem 1rem">' + villes + '</ul>'
      + '<p>' + echapper(t('postes')) + '</p><ul style="margin:.3rem 0 0 1rem;max-height:40vh;overflow:auto">' + postes + '</ul>');
  }

  window.teaserAccesInterdit = teaserAccesInterdit;
  window.teaserCompteur = teaserCompteur;
  window.RP_TEASER_CAPITALES_T = T;
})();
