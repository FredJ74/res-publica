/* ===========================
   RES PUBLICA — PLATEAU.JS v2
   =========================== */

// =====================
// STATE
// =====================
const TEST_MODE = true; // PA illimites

let state = {
  pa: 999, paMax: 999,
  arg: 4250, liquide: 500, banque: 3750,
  inf: 25, pop: 30, dis: 85, hp: 92, moral: 78,
  day: 1, hour: 8,
  country: 'republic',
  currentCity: 'capitale',
  currentBuilding: null,
  currentRoom: null,
  char: null,
  inventory: [],
  poste: null,
  employees: []
};

// =====================
// INIT
// =====================
window.addEventListener('DOMContentLoaded', () => {
  loadCharacter();
  buildCityTabs();
  if (!state.currentCity) state.currentCity = 'capitale';
  renderMinimap('capitale');
  updateUI();
  updateLocationDisplay();
  startClock();
  // Fix: afficher image de rue des le chargement
  setTimeout(() => { travelToCity(state.currentCity || 'capitale'); }, 100);
});

function loadCharacter() {
  try {
    const saved = localStorage.getItem('respublica_char');
    if (saved) {
      const char = JSON.parse(saved);
      state.char = char;
      state.country = char.country || 'republic';
      state.arg = char.arg || 4250;
      state.liquide = Math.floor(state.arg * 0.15);
      state.banque = state.arg - state.liquide;
      state.inf = char.resources?.inf || 25;
      state.pop = char.resources?.pop || 30;
      state.dis = char.resources?.dis || 85;

      // UI
      document.getElementById('char-name-display').textContent = char.name || 'Mon Personnage';
      const ar = ARCHETYPES.find(x => x.id === char.archetype);
      const ca = CAREERS.find(x => x.id === char.career);
      document.getElementById('char-role-display').textContent = `${ar?.name||'?'} · ${ca?.name||'?'}`;
      document.getElementById('char-fullname-left').textContent = char.name || 'Mon Personnage';
      const co = COUNTRIES[char.country];
      document.getElementById('char-arch-left').textContent = `${ar?.name||'?'} · ${co?.n||'?'}`;

      // Photo — stockee separement pour eviter depassement localStorage
      try {
        const photoSaved = localStorage.getItem('respublica_photo');
        const photoUrl = photoSaved || char.photoUrl;
        if (photoUrl && photoUrl.length > 10) {
          const imgTag = `<img src="${photoUrl}" alt="Photo" style="width:100%;height:100%;object-fit:cover;border-radius:50%"/>`;
          document.getElementById('char-photo-left').innerHTML = imgTag;
          document.getElementById('char-avatar-top').innerHTML = imgTag;
        }
      } catch(photoErr) {
        console.warn('Photo non chargee:', photoErr);
      }

      if (char.stats) {
        document.getElementById('stat-mini-grid').innerHTML = STAT_DEFS.map(({k}) => `
          <div class="stat-mini">
            <div class="stat-mini-name">${k}</div>
            <div class="stat-mini-val">${char.stats[k]||8}</div>
          </div>`).join('');
      }

      const cur = co?.cur || 'FR';
      document.getElementById('r-arg').textContent = state.arg.toLocaleString('fr-FR') + ' ' + cur;

      console.log('Personnage charge:', char.name, '| Pays:', state.country);
    }
  } catch(e) { console.warn('Erreur chargement personnage', e); }
}

// =====================
// CLOCK
// =====================
function startClock() {
  syncRealTime();
  updateClock();
  // Mise a jour toutes les minutes
  setInterval(() => {
    syncRealTime();
    updateClock();
    checkMidnight();
  }, 60000);
}

function syncRealTime() {
  // Calage sur l'heure reelle francaise
  const now = new Date();
  const frTime = new Date(now.toLocaleString('en-US', { timeZone: 'Europe/Paris' }));
  state.hour = frTime.getHours();
  state.minute = frTime.getMinutes();
  state.day = state.day || 1; // Le jour de jeu est incremente a minuit
}

function updateClock() {
  const h = String(state.hour).padStart(2,'0');
  const m = String(state.minute||0).padStart(2,'0');
  const el = document.getElementById('game-time');
  if (el) el.textContent = `Jour ${state.day} · ${h}h${m}`;
}

function checkMidnight() {
  if (state.hour === 0 && state.minute < 2) {
    if (!state.midnightDone) {
      state.midnightDone = true;
      runMidnightUpdate();
    }
  } else {
    state.midnightDone = false;
  }
}

function runMidnightUpdate() {
  state.day++;
  state.salaireTouche = false;
  // Traiter les plaintes et enquetes en cours
  traiterPlaintes();
  traiterEnquetes();
  // Budget institutions et population
  mettreAJourBudgets();
  mettreAJourPopulation();
  // Revenus fiscaux
  const pop = CITY_POPULATION[state.country]?.[state.currentCity];
  if (pop) {
    const taxRevenue = pop.dailyTaxRevenue || 0;
    const oilRevenue = pop.oilRevenue || 0;
    const totalRevenue = taxRevenue + oilRevenue;
    if (totalRevenue > 0 && state.poste && ['president','pm','min_fin'].includes(state.poste.id)) {
      addJournalEntry(`Mise a jour minuit : recettes fiscales de ${totalRevenue.toLocaleString('fr-FR')} versees au tresor national.`, 'event-info');
    }
  }
  addJournalEntry(`Nouveau jour : Jour ${state.day}. La ville s\'eveille.`, 'event-info');
  updateClock();
}

// =====================
// CITY TABS
// =====================
function buildCityTabs() {
  const co = COUNTRIES[state.country];
  if (!co) return;
  const world = WORLD[state.country];
  if (!world) return;

  const tabs = document.getElementById('city-tabs');
  tabs.innerHTML = Object.entries(world).map(([cityId, city]) => `
    <div class="city-tab ${cityId === state.currentCity ? 'active' : ''}"
      onclick="travelToCity('${cityId}')">${city.name}</div>
  `).join('');
}

function travelToCity(cityId) {
  if (cityId === state.currentCity) return;
  const isSameCountry = true;
  const cost = isSameCountry ? 2 : 5;
  if (!TEST_MODE && state.pa < cost) {
    showToast('PA insuffisants', `Le voyage coute ${cost} PA.`, false);
    return;
  }
  if (!TEST_MODE) state.pa -= cost;

  state.currentCity = cityId;
  state.currentBuilding = null;
  state.currentRoom = null;

  const world = WORLD[state.country];
  const city = world[cityId];

  // Mise a jour tabs
  document.querySelectorAll('.city-tab').forEach(t => t.classList.remove('active'));
  document.querySelectorAll('.city-tab').forEach(t => {
    if (t.textContent === city.name) t.classList.add('active');
  });

  document.getElementById('city-name-display').textContent = `${city.name}, ${city.isCapitale ? 'Capitale de ' : ''}${COUNTRIES[state.country].n}`;

  // Vue rue
  showVueRue();
  renderMinimap(cityId);
  updateLocationDisplay();

  addJournalEntry(`Vous arrivez a ${city.name}.`, 'event-info');
  // Verifier interception si recherche
  if (state.recherche && state.recherche.length > 0) {
    setTimeout(() => checkArrestationAuDeplacement(), 500);
  }
  if (!TEST_MODE) updateUI();
}

// =====================
// MINIMAP
// =====================
function renderMinimap(cityId) {
  const world = WORLD[state.country];
  const city = world?.[cityId];
  if (!city) return;

  const grid = document.getElementById('minimap-grid');
  const buildingIds = city.buildings || [];

  // Separer capitales et publics
  const capitalOnly = buildingIds.filter(id => BUILDINGS[id]?.capitaleOnly);
  const regular = buildingIds.filter(id => !BUILDINGS[id]?.capitaleOnly);

  let html = '';

  if (capitalOnly.length > 0 && city.isCapitale) {
    html += `<div class="minimap-section-title">Institutions nationales</div>`;
    html += capitalOnly.map(id => minimapCard(id)).join('');
  }

  html += `<div class="minimap-section-title">Batiments</div>`;
  html += regular.map(id => minimapCard(id)).join('');

  grid.innerHTML = html;
}

function minimapCard(id) {
  const b = BUILDINGS[id];
  if (!b) return '';
  const personCount = Object.values(b.rooms || {}).reduce((acc, r) => acc + (r.persons?.length || 0), 0);
  const locked = b.locked ? '<span style="font-size:.6rem;color:#5a3020">· Acces restreint</span>' : '';
  return `
    <div class="minimap-building ${b.capitaleOnly ? 'capital-only' : ''}" onclick="enterBuilding('${id}')">
      <div class="minimap-bld-icon"><i class="ti ${b.icon}" style="font-size:.8rem"></i></div>
      <div class="minimap-bld-info">
        <div class="minimap-bld-name">${b.shortName || b.name}</div>
        <div class="minimap-bld-cat">${b.cat} ${locked}</div>
        ${personCount > 0 ? `<div class="minimap-persons">${personCount} personne${personCount > 1 ? 's' : ''}</div>` : ''}
      </div>
    </div>`;
}

// =====================
// NAVIGATION BATIMENTS
// =====================
function showVueRue() {
  document.getElementById('vue-rue').classList.add('active');
  document.getElementById('vue-batiment').classList.remove('active');
  state.currentBuilding = null;
  state.currentRoom = null;
  updateLocationDisplay();

  const world = WORLD[state.country];
  const city = world?.[state.currentCity];
  if (city) {
    document.getElementById('rue-title').textContent = city.isCapitale ? 'Avenue de la Republique' : `Rue principale de ${city.name}`;
    document.getElementById('rue-desc').textContent = city.desc;
  }

  // Image de rue directe depuis data.js
  const rueImage = document.getElementById('rue-image');
  const imgUrl = city?.imageUrl;
  if (imgUrl) {
    rueImage.style.background = `linear-gradient(180deg, rgba(0,0,0,0.1) 0%, rgba(0,0,0,0.7) 100%), url('${imgUrl}') center/cover no-repeat`;
  } else {
    rueImage.style.background = 'linear-gradient(135deg,#0a0a07,#0f0d08)';
  }
  const existing = document.getElementById('rue-emoji');
  if (existing) existing.remove();
}

function enterBuilding(buildingId) {
  const b = BUILDINGS[buildingId];
  if (!b) return;

  if (b.locked) {
    showToast('Acces restreint', "Vous n'etes pas membre de cet etablissement.", false);
    addJournalEntry(`Vous tentez d'entrer a ${b.name} mais l'acces vous est refuse.`, 'event-bad');
    return;
  }

  state.currentBuilding = buildingId;
  document.getElementById('vue-rue').classList.remove('active');
  document.getElementById('vue-batiment').classList.add('active');

  // Header
  document.getElementById('bat-nom').textContent = b.name;
  document.getElementById('bat-cat').textContent = b.cat;

  // Onglets pieces
  const rooms = Object.entries(b.rooms || {});
  document.getElementById('pieces-tabs').innerHTML = rooms.map(([roomId, room], i) => `
    <div class="piece-tab ${i === 0 ? 'active' : ''}" onclick="enterRoom('${buildingId}','${roomId}',this)">
      ${room.name}
    </div>`).join('');

  // Entrer dans la premiere piece
  if (rooms.length > 0) {
    enterRoom(buildingId, rooms[0][0], null);
  }

  updateLocationDisplay();
  addJournalEntry(`Vous entrez dans ${b.name}.`, '');
}

function enterRoom(buildingId, roomId, tabEl) {
  const b = BUILDINGS[buildingId];
  if (!b) return;
  const room = b.rooms?.[roomId];
  if (!room) return;

  state.currentRoom = roomId;

  // Update tabs
  if (tabEl) {
    document.querySelectorAll('.piece-tab').forEach(t => t.classList.remove('active'));
    tabEl.classList.add('active');
  }

  // Image de la piece
  const pieceImg = document.getElementById('piece-image');
  if (room.imageUrl) {
    pieceImg.style.background = `linear-gradient(180deg, rgba(0,0,0,0.05) 0%, rgba(0,0,0,0.85) 100%), url('${room.imageUrl}') center/cover no-repeat`;
  } else {
    pieceImg.style.background = room.imageBg || 'linear-gradient(135deg,#0a0a07,#0f0d08)';
  }
  // Supprimer ancien emoji si present
  const existing = pieceImg.querySelector('.piece-emoji');
  if (existing) existing.remove();

  document.getElementById('piece-nom').textContent = room.name;
  document.getElementById('piece-desc').textContent = room.desc;

  // Personnes
  renderPersonsList(room.persons || []);

  // Ordres
  renderRoomActions(room, buildingId, roomId);

  // Loc
  document.getElementById('loc-name').textContent = b.shortName || b.name;
  document.getElementById('loc-sub').textContent = room.name;
}

function sortirBatiment() {
  showVueRue();
  addJournalEntry(`Vous sortez du batiment.`, '');
}

// =====================
// PERSONS LIST
// =====================
function renderPersonsList(persons) {
  const relCol = r => r === 'ally' ? '#4a8a4a' : r === 'enemy' ? '#8a3a2a' : '#6a6040';
  const relTxt = r => r === 'ally' ? 'Allie' : r === 'enemy' ? 'Hostile' : 'Neutre';

  const char = state.char;
  const ar = ARCHETYPES.find(x => x.id === char?.archetype);

  // Carte du PJ lui-meme — cliquable pour ouvrir la fiche personnage centrale
  const photoHtml = char?.photoUrl
    ? '<img src="' + char.photoUrl + '" alt="Vous" style="width:100%;height:100%;object-fit:cover;border-radius:50%"/>'
    : '<i class="ti ti-user" style="font-size:.75rem;color:#C9A84C"></i>';

  const selfCard = char ? '<div class="person-card" style="border-left:2px solid #C9A84C;cursor:pointer" onclick="openSelfView()" title="Cliquer pour dormir, inventaire, fiche">' +
    '<div class="person-avatar" style="border-color:#C9A84C">' + photoHtml + '</div>' +
    '<div>' +
    '<div class="person-name" style="color:#C9A84C">' + char.name + ' <span style="font-size:.6rem;color:#6a5a20">(Vous)</span></div>' +
    '<div class="person-role">' + (state.poste?.name || ar?.name || 'Citoyen') + '</div>' +
    '<div style="font-size:.58rem;color:#4a8a4a">Cliquer : dormir · inventaire · fiche</div>' +
    '</div></div>' : '';

  const personCards = persons.length === 0 ? '' : persons.map(p => {
    const avatarHtml = (typeof renderPnjAvatarHtml === 'function')
      ? renderPnjAvatarHtml(p, 28)
      : '<div class="person-avatar"><i class="ti ti-user" style="font-size:.75rem"></i></div>';
    return '<div class="person-card" onclick="openPnjModal(\'' + encodeURIComponent(JSON.stringify(p)) + '\')">' +
      avatarHtml +
      '<div>' +
      '<div class="person-name">' + p.name + '</div>' +
      '<div class="person-role">' + p.role + '</div>' +
      '<div class="person-rel" style="color:' + relCol(p.rel) + ';font-size:.58rem">' + relTxt(p.rel) + '</div>' +
      '</div></div>';
  }).join('');

  const simules = getSimulesPresents();
  const simuleCards = simules.map(p => {
    const enc = encodeURIComponent(JSON.stringify({...p, isPJ: true}));
    return '<div class="person-card" onclick="openPnjModal(\'' + enc + '\')" style="border-left:2px solid #4a6aaa">' +
      '<div class="person-avatar" style="border-color:#4a6aaa"><i class="ti ti-user-circle" style="font-size:.75rem;color:#4a6aaa"></i></div>' +
      '<div><div class="person-name" style="color:#8aaad0">' + p.name + ' <span style="font-size:.6rem;color:#3a5a8a">[SIM]</span></div>' +
      '<div class="person-role">' + p.role + '</div>' +
      '<div style="font-size:.6rem;color:#3a5a8a">INF:' + p.resources.inf + ' POP:' + p.resources.pop + '</div>' +
      '</div></div>';
  }).join('');

  document.getElementById('persons-list').innerHTML = selfCard + simuleCards + personCards ||
    '<div class="person-empty">Personne d\'autre ici</div>';
}

// =====================
// ROOM ACTIONS
// =====================
function renderRoomActions(room, buildingId, roomId) {
  const orders = room.orders || [];
  const cur = COUNTRIES[state.char?.country || 'republic']?.cur || 'FR';

  document.getElementById('action-context-bat').textContent =
    room.name.toUpperCase() + ' — ACTIONS DISPONIBLES';

  // Plus d'ordres communs ici — se_cacher/blocus/incendier sont dans la fiche personnage
  const allOrders = [...orders];

  const buttons = allOrders.map(o => {
    const needsPost = o.requiresPost && !state.poste;
    const paDisplay = TEST_MODE ? '0 PA' : o.pa + ' PA';
    // Appliquer malus ISN sur les actes illegaux
    let tauxAffiche = o.successRate || 70;
    if (o.type === 'illegal') {
      tauxAffiche = Math.max(5, tauxAffiche - getMalusISN());
    }
    const costDisplay = o.cost > 0 ? o.cost.toLocaleString('fr-FR') + ' ' + cur : 'gratuit';
    const ef = ORDER_EFFECTS[o.fn] || {};
    const gainParts = [];
    if (ef.hp > 0)    gainParts.push('+' + ef.hp + ' Sante');
    if (ef.moral > 0) gainParts.push('+' + ef.moral + ' Moral');
    if (ef.inf > 0)   gainParts.push('+' + ef.inf + ' INF');
    if (ef.pop > 0)   gainParts.push('+' + ef.pop + ' POP');
    if (ef.arg > 0)   gainParts.push('+' + ef.arg + ' ' + cur);
    const gainStr = gainParts.join(' · ');
    const riskParts = [];
    if (ef.dis < 0)   riskParts.push(ef.dis + ' DIS');
    if (ef.pop < 0)   riskParts.push(ef.pop + ' POP');
    const riskStr = riskParts.join(' · ');
    const rate = o.successRate || 70;
    const tooltipParts = [];
    if (o.desc) tooltipParts.push(o.desc);
    if (gainStr) tooltipParts.push('Gain: ' + gainStr);
    if (riskStr) tooltipParts.push('Risque: ' + riskStr);
    tooltipParts.push('Reussite: ' + rate + '%');
    const tooltip = tooltipParts.join(' | ');

    let onclickFn = '';
    if (needsPost) {
      onclickFn = 'showPostRequired()';
    } else if (o.fn === 'plainte_police') {
      onclickFn = 'openPlainteModal()';
    } else if (o.fn === 'gerer_finances') {
      onclickFn = 'openFinancesModal()';
    } else if (o.fn === 'postuler') {
      onclickFn = 'openPostesModal()';
    } else {
      const safeLabel = o.label.replace(/'/g, ' ');
      const safeDesc = (o.desc||'').replace(/'/g, ' ');
      onclickFn = "doOrder('" + o.fn + "'," + o.pa + "," + o.cost + ",'" + safeLabel + "','" + safeDesc + "'," + rate + ")";
    }

    const gainBadge = gainStr ? '<span class="action-gain">' + gainStr + '</span>' : '';
    const blockedCls = needsPost ? ' blocked' : '';
    return '<button class="action-btn ' + o.type + blockedCls + '" onclick="' + onclickFn + '" title="' + tooltip + '"><i class="ti ' + o.icon + '" style="font-size:.82rem"></i> ' + o.label + ' <span class="pa-cost">' + costDisplay + ' · ' + paDisplay + '</span>' + gainBadge + '</button>';
  });

  document.getElementById('actions-row-bat').innerHTML = buttons.join('') ||
    '<div style="font-size:.75rem;color:#3a3020;font-style:italic;padding:.3rem">Aucune action disponible ici.</div>';
}

// =====================
// ORDERS SYSTEM
// =====================
function doOrder(fn, pa, cost, label, desc, successRate) {
  successRate = successRate || 70;
  const cur = COUNTRIES[state.char?.country || 'republic']?.cur || 'FR';

  // PA check (ignore si mode test)
  if (!TEST_MODE && state.pa < pa) {
    showToast('PA insuffisants', `Il vous manque ${pa - state.pa} PA.`, false);
    return;
  }

  // Argent check
  if (cost > 0 && state.arg < cost) {
    showToast('Fonds insuffisants', `Cette action coute ${cost} ${cur}.`, false);
    return;
  }

  // Ordres speciaux
  if (fn === 'postuler') { ouvrirPostulerPoste(); return; }
  if (fn === 'gerer_finances') { openFinancesModal(); return; }
  if (fn === 'plainte_police') { openPlainteModal(); return; }
  if (fn === 'archives_police') { doArchivesPolice(); return; }
  if (fn === 'pouls_populaire') { doPoulsPopulaire(); return; }
  if (fn === 'lancer_rumeur_cible') { openRumeurModal(); return; }
  if (fn === 'distribuer_tract') { doDistribuerTract(); return; }
  if (fn === 'demander_parler_loge') { doLogePortail(); return; }
    if (fn === 'acheter_arme_legale') { doAcheterArme(true); return; }
    if (fn === 'imprimer_tracts') { ouvrirModalImprimerTracts(); return; }
  if (fn === 'acheter_arme_illegale') { doAcheterArme(false); return; }
  if (fn === 'consulter_registre_armes') { doConsulterRegistre(); return; }
  if (fn === 'marchander_vote') { openMarchanderVoteModal(); return; }
  if (fn === 'assassiner') { showToast('Cliquez sur la cible', 'Pour assassiner, cliquez sur le personnage cible dans la liste des personnes presentes.', false); return; }
  if (fn === 'deposer_candidature') { openCandidatureModal(); return; }
  if (fn === 'consulter_elections') { openElectionsModal(); return; }
  if (fn === 'creer_poste_ministre')    { creerPosteMinistre(); return; }
  if (fn === 'creer_comite')            { creerComite(); return; }
  if (fn === 'supprimer_poste_custom')  { supprimerPosteCustom(); return; }
  if (fn === 'nommer_ministre')         { openNominerModal(); return; }
  if (fn === 'nommer_pm')               { ouvrirModalCibleRepertoire('nommer_pm_confirm', 'Nommer un Premier Ministre'); return; }
  if (fn === 'nommer_ministre_pm')      { ouvrirNommerMinistresModal(); return; }
  if (fn === 'declarer_guerre_empire')  { ouvrirModalEmpireCible('declarer_guerre', 'Declarer la guerre'); return; }
  if (fn === 'gracier_condamne')        { ouvrirModalGracier(); return; }
  if (fn === 'decret_referendum')       { ouvrirForumPresidentCentral('referendum'); return; }
  if (fn === 'nationaliser_entreprise') { ouvrirModalNationaliser(); return; }
  if (fn === 'jour_deuil')              { ouvrirForumPresidentCentral('deuil'); return; }
  if (fn === 'solliciter_audience_president') { solliciterAudiencePresident(); return; }
  if (fn === 'etat_nation')              { ouvrirIndicesImperiaux(); return; }
  if (fn === 'observer_debats')          { observerDebats(); return; }
  if (fn === 'voter_loi')               { ouvrirVoteLoi(); return; }
  if (fn === 'deposer_projet')          { ouvrirForumView('parlement'); return; }
  if (fn === 'consulter_archives_lois') { ouvrirArchivesLois(); return; }
  if (fn === 'consulter_archives_tribunal') { ouvrirArchivesTribunal(); return; }
  if (fn === 'porter_plainte')          { ouvrirPorterPlainte(); return; }
  if (fn === 'rendre_sentence')         { ouvrirRendreSentence(); return; }
  if (fn === 'falsifier_document')      { ouvrirFalsifierDocument(); return; }
  if (fn === 'interdire_manif_cible')   { ouvrirModalTexteLibre('interdire_manif', 'Interdire une manifestation', 'Preciser le nom ou sujet de la manifestation a interdire...'); return; }
  if (fn === 'reprimer_manif_cible')    { ouvrirModalTexteLibre('reprimer_manif', 'Ordonner la repression', 'Preciser la manifestation ou le rassemblement cible...'); return; }
  if (fn === 'redressement_cible')      { ouvrirModalCibleRepertoire('redressement_fiscal', 'Redressement fiscal'); return; }
  if (fn === 'subvention_cible')        { ouvrirModalCibleRepertoire('subvention', 'Accorder une subvention'); return; }
  if (fn === 'allegemement_secteur')    { ouvrirModalSecteur(); return; }
  if (fn === 'annuler_poursuites_cible'){ ouvrirModalAffaires('annuler'); return; }
  if (fn === 'ouvrir_enquete_cible')    { ouvrirModalCibleRepertoire('ouvrir_enquete', 'Ouvrir une enquete sur'); return; }
  if (fn === 'nommer_juge_cible')       { ouvrirModalNommerJuge(); return; }
  if (fn === 'cessez_le_feu_empire')    { ouvrirModalEmpireCible('cessez_le_feu', 'Negocier un cessez-le-feu avec'); return; }
  if (fn === 'renseignement_cible')     { ouvrirModalRenseignement(); return; }
  if (fn === 'censurer_media_cible')    { ouvrirModalMedia(); return; }
  if (fn === 'commanditer_sondage_cible') { ouvrirModalTexteLibre('commanditer_sondage', 'Commanditer un sondage', 'Preciser le sujet du sondage...'); return; }
  if (fn === 'signer_traite_empire')    { ouvrirModalTraite(); return; }
  if (fn === 'ouvrir_ambassade_empire') { ouvrirModalEmpireCible('ouvrir_ambassade', 'Ouvrir une ambassade dans'); return; }
  if (fn === 'nommer_ambassadeur_cible'){ ouvrirModalNommerAmbassadeur(); return; }
  if (fn === 'sanctions_empire')        { ouvrirModalEmpireCible('sanctions', 'Imposer des sanctions a'); return; }
  if (fn === 'forum_president_conference' || fn === 'forum_president_annonce' ||
      fn === 'forum_president_propagande' || fn === 'forum_president_dementi') {
    ouvrirForumPresidentCentral(fn); return;
  }
  if (fn === 'reception_etat' || fn === 'banquet_diplo') { doReceptionAvecBonus(fn, cost); return; }

  // Deduire PA et argent
  if (!TEST_MODE) state.pa = Math.max(0, state.pa - pa);
  if (cost > 0) state.arg = Math.max(0, state.arg - cost);

  // Roll
  // Ajuster le taux selon le groupe pour le blocus
  if (fn === 'organiser_blocus') {
    const groupBonus = getGroupSize ? getGroupSize() - 1 : 0;
    successRate = Math.min(90, 25 + groupBonus);
  }

  const roll = Math.floor(Math.random() * 100) + 1;
  const effectiveRate = successRate >= 98 ? 99 : successRate;
  let resultType;
  if (roll <= 100 - effectiveRate) { resultType = 'crit-fail'; }
  else if (roll <= 100 - (effectiveRate * 0.7)) { resultType = 'fail'; }
  else if (roll <= 100 - (effectiveRate * 0.4)) { resultType = 'partial'; }
  else if (roll >= 95) { resultType = 'crit'; }
  else { resultType = 'success'; }

  // Ordres a succes garanti
  const alwaysSuccess = ['se_nourrir','dormir','se_reposer','soins','soins_urgence','soins_basiques','deplacer','gerer_finances','reserver','parler_pnj','se_renseigner','assister_session','voter_loi','plainte','plainte_police','archives','archives_police','acheter_arme','acheter_gilet','acheter_terrain','se_presenter','rencontrer','se_former'];
  if (alwaysSuccess.includes(fn)) resultType = roll >= 95 ? 'crit' : 'success';

  applyEffects(fn, resultType, cost);
  const msg = buildResultMsg(fn, resultType, desc, label);
  const isGood = ['crit','success','partial'].includes(resultType);
  showToast(buildResultLabel(resultType, roll), msg, isGood, resultType === 'crit');
  addJournalEntry(`${label} — ${buildResultLabel(resultType, roll)}. ${msg}`,
    resultType === 'crit' || resultType === 'success' ? 'event-good' : resultType === 'crit-fail' ? 'event-bad' : '');

  // Verifier detection si acte illegal
  if (ACTES_ILLEGAUX[fn] && resultType !== 'crit-fail') {
    checkDetection(fn, resultType);
  }

  advanceTime(Math.max(0, pa));
  updateUI();
}

function applyEffects(fn, resultType, cost) {
  const ef = ORDER_EFFECTS[fn] || {};
  const mult = resultType === 'crit' ? 1.5 : resultType === 'success' ? 1 :
               resultType === 'partial' ? 0.5 : resultType === 'fail' ? 0 : -0.5;

  // Remboursement partiel si echec
  if (resultType === 'fail' && cost > 0) state.arg += Math.floor(cost * 0.3);
  if (resultType === 'crit-fail' && cost > 0) { /* Pas de remboursement */ }

  // Appliquer effets
  if (ef.hp)    state.hp    = Math.min(100, Math.max(0, state.hp    + Math.round(ef.hp    * mult)));
  if (ef.moral) state.moral = Math.min(100, Math.max(0, state.moral + Math.round(ef.moral * mult)));
  if (ef.inf)   state.inf   = Math.min(100, Math.max(0, state.inf   + Math.round(ef.inf   * mult)));
  if (ef.pop)   state.pop   = Math.min(100, Math.max(0, state.pop   + Math.round(ef.pop   * (resultType === 'crit-fail' ? -1 : mult))));
  if (ef.dis)   state.dis   = Math.min(100, Math.max(0, state.dis   + Math.round(ef.dis   * (ef.dis < 0 ? 1 : mult))));
  if (ef.arg)   state.arg   = Math.min(9999999, Math.max(0, state.arg + Math.round(ef.arg * mult)));

  // PA bonus (dormir en hotel) + salaire journalier
  if (fn === 'dormir') {
    if (ef.paBonus && resultType !== 'fail') {
      state.paBonus = ef.paBonus || 0;
      addJournalEntry(`Nuit confortable. +${ef.paBonus} PA bonus demain.`, 'event-good');
    }
    // Salaire journalier — une seule fois par jour
    if (!state.salaireTouche) {
      state.salaireTouche = true;
      const posteId = state.poste?.id || 'default';
      const salaire = SALAIRES[posteId] || SALAIRES.default;
      state.arg += salaire;
      state.liquide += Math.floor(salaire * 0.3);
      state.banque += Math.ceil(salaire * 0.7);
      addJournalEntry(`Salaire journalier verse : ${salaire.toLocaleString('fr-FR')} ${COUNTRIES[state.country]?.cur||'FR'} (${state.poste?.name || 'Citoyen'}).`, 'event-good');
      showToast('Salaire verse', `+${salaire.toLocaleString('fr-FR')} ${COUNTRIES[state.country]?.cur||'FR'}`, true);
    } else {
      addJournalEntry('Vous avez deja percu votre salaire aujourd\'hui.', '');
    }
  }

  // Effets speciaux
  // Blocus : 1 PA quoi qu'il arrive + bonus groupe
  if (fn === 'organiser_blocus') {
    if (!TEST_MODE) state.pa = Math.max(0, state.pa - 1);
  }
  if (fn === 'acheter_arme')    addToInventory({name:'Arme de poing', icon:'ti-gun', type:'arme'});
  if (fn === 'acheter_gilet')   addToInventory({name:'Gilet pare-balles', icon:'ti-shield', type:'protection'});
  if (fn === 'acheter_terrain') addToInventory({name:'Terrain (terrain en jeu)', icon:'ti-fence', type:'bien'});
}

function buildResultLabel(type, roll) {
  const labels = {
    'crit':      `Succes critique ! (${roll})`,
    'success':   `Succes (${roll})`,
    'partial':   `Succes partiel (${roll})`,
    'fail':      `Echec (${roll})`,
    'crit-fail': `Echec critique ! (${roll})`
  };
  return labels[type] || `Resultat (${roll})`;
}

function buildResultMsg(fn, type, desc, label) {
  if (type === 'crit') return (desc ? desc + ' ' : '') + 'Resultat exceptionnel !';
  if (type === 'success') return desc || `${label} execute avec succes.`;
  if (type === 'partial') return `${label} partiellement reussi. Effet reduit.`;
  if (type === 'fail') return `${label} a echoue. Ressources partiellement recuperees.`;
  if (type === 'crit-fail') return `${label} s'est retourne contre vous. Consequences negatives.`;
  return desc || '';
}

// =====================
// PNJ INTERACTION
// =====================
function openPnjModal(encodedPnj) {
  let pnj;
  try { pnj = JSON.parse(decodeURIComponent(encodedPnj)); }
  catch(e) { return; }

  const isPJ = pnj.isPJ === true;
  document.getElementById('modal-pnj').classList.add('open');
  document.getElementById('pnj-modal-title').textContent = pnj.name;
  const speech = document.getElementById('pnj-speech');
  speech.innerHTML = '<div class="pnj-loading"><span class="spin"></span> En train de repondre...</div>';
  const enc = encodeURIComponent(JSON.stringify(pnj));

  let actionBtns = '';
  if (isPJ) {
    const inGroup = state.group && state.group.members && state.group.members.includes(pnj.name);
    const pnjJson = encodeURIComponent(JSON.stringify(pnj));
    actionBtns = (!inGroup
      ? '<button class="pnj-action-btn" onclick="rejoindrePJ(decodeURIComponent(\'' + pnjJson + '\'))"><i class="ti ti-users" style="font-size:.85rem"></i> Rejoindre ce joueur</button>'
      : '<button class="pnj-action-btn" onclick="quitterGroupe()"><i class="ti ti-user-minus" style="font-size:.85rem"></i> Quitter le groupe</button>')
      + '<button class="pnj-action-btn" onclick="addContactByName(\'' + pnj.name.replace(/'/g, '') + '\', \'' + (pnj.role||'').replace(/'/g, '') + '\', \'' + (pnj.rel||'neutral') + '\')"><i class="ti ti-user-plus" style="font-size:.85rem"></i> Ajouter au repertoire</button>';
  }
  if (pnj.rel === 'enemy') {
    actionBtns += '<button class="pnj-action-btn" onclick="talkToPnj(\'' + enc + '\', \'confrontation\')"><i class="ti ti-sword" style="font-size:.85rem"></i> Confronter</button>';
  }
  // Bouton assassiner (toujours disponible sur PNJ/PJ autres)
  const encCible = encodeURIComponent(JSON.stringify(pnj));
  actionBtns += '<button class="pnj-action-btn" style="color:#cc4444;border-color:#3a1010" onclick="document.getElementById(\'modal-pnj\').classList.remove(\'open\');ouvrirModalAssassinat(\'' + encCible + '\')"><i class="ti ti-skull" style="font-size:.85rem"></i> Assassiner</button>';

  // Boutons tracts
  const hasTracts = (state.inventory||[]).some(i => i.type === 'tract');
  if (hasTracts) {
    if (pnj.isPJ) {
      // Don de main a main a un PJ
      actionBtns += '<button class="pnj-action-btn" onclick="document.getElementById(\'modal-pnj\').classList.remove(\'open\');donnerTracts(\'' + pnj.name + '\')"><i class="ti ti-files" style="font-size:.85rem"></i> Donner des tracts</button>';
    } else {
      // Distribution a un PNJ
      actionBtns += '<button class="pnj-action-btn" onclick="document.getElementById(\'modal-pnj\').classList.remove(\'open\');distribuerTractPNJ(\'' + pnj.name + '\')"><i class="ti ti-file-description" style="font-size:.85rem"></i> Distribuer un tract</button>';
    }
  }

  document.getElementById('pnj-actions').innerHTML = actionBtns +
    '<div style="display:flex;gap:.4rem;margin-top:.5rem">' +
    '<input id="pnj-question-libre" type="text" style="flex:1;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem .6rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none" placeholder="Posez votre question..." onkeydown="handlePnjKey(event)" />' +
    '<button onclick="envoyerQuestion()" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.4rem .7rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer"><i class="ti ti-send" style="font-size:.8rem"></i></button>' +
    '</div>';

  // Stocker l'enc pour envoyerQuestion
  state._currentPnjEnc = enc;

  talkToPnj(enc, 'bonjour');
}

function handlePnjKey(event) {
  if (event.key === 'Enter') envoyerQuestion();
}

function envoyerQuestion(enc) {
  const input = document.getElementById('pnj-question-libre');
  if (!input) return;
  const q = input.value.trim();
  if (!q) return;
  input.value = '';
  const encToUse = enc || state._currentPnjEnc;
  if (encToUse) talkToPnj(encToUse, q);
}

async function talkToPnj(encodedPnj, action) {
  let pnj;
  try { pnj = JSON.parse(decodeURIComponent(encodedPnj)); }
  catch(e) { return; }

  if (!action || action.trim() === '') return;

  const speech = document.getElementById('pnj-speech');
  speech.innerHTML = '<div class="pnj-loading"><span class="spin"></span> En train de repondre...</div>';

  const char = state.char;
  const ar = ARCHETYPES.find(x => x.id === char?.archetype);
  const co = COUNTRIES[state.country];

  // Gestion speciale loge
  if (pnj.job === 'portier' && action === 'bonjour') {
    speech.textContent = 'Le portier vous devisage longuement a travers le judas. "Que voulez-vous ?"';
    document.getElementById('pnj-actions').innerHTML += `
      <div style="margin-top:.8rem;border-top:1px solid #2a2010;padding-top:.8rem">
        <div style="font-size:.72rem;color:#6a5a20;font-family:'Bebas Neue',sans-serif;letter-spacing:.1em;margin-bottom:.4rem">REPONDRE :</div>
        <button class="pnj-action-btn" onclick="logeDemanderResponsable()">
          <i class="ti ti-user-star" style="font-size:.85rem"></i> Je veux parler au responsable de la loge
        </button>
        <button class="pnj-action-btn" onclick="logeDemanderAdhesion()">
          <i class="ti ti-user-plus" style="font-size:.85rem"></i> Je veux faire partie des votres
        </button>
      </div>`;
    return;
  }

  // Actions predefinies
  const actionMap = {
    'bonjour':       'vous salue a son arrivee',
    'information':   'lui demande des informations sur la situation politique locale',
    'alliance':      'lui propose une alliance politique discrete',
    'confrontation': 'le confronte directement en lui reprochant ses actions'
  };
  const actionDesc = actionMap[action] || `lui pose la question suivante : "${action}"`;
  const isQuestion = !actionMap[action];

  const prompt = `Tu joues un personnage dans un jeu de role politique parodique satirique (Res Publica).
Ton personnage : ${pnj.name}, ${pnj.role}, dans l'empire "${co?.n}".
Relation avec le joueur : ${pnj.rel === 'ally' ? 'allie de confiance' : pnj.rel === 'enemy' ? 'ennemi declare' : 'neutre'}.
Le joueur : ${char?.name || 'Inconnu'}, ${ar?.name || ''}, ${state.poste ? state.poste.name : 'sans poste'}.
${isQuestion ? `Le joueur te pose cette question : "${action}". Reponds de facon coherente avec ton role.` : `Le joueur ${actionDesc}.`}
Reponds en 2-3 phrases max. Ton satirique et politique. Sois caracteriel.
Reponds UNIQUEMENT avec ta replique, sans guillemets ni introduction.`;

  try {
    const resp = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: 'claude-sonnet-4-20250514',
        max_tokens: 200,
        messages: [{ role: 'user', content: prompt }]
      })
    });
    if (!resp.ok) throw new Error('HTTP ' + resp.status);
    const data = await resp.json();
    const text = data.content?.[0]?.text;
    if (text) {
      speech.textContent = text;
    } else { throw new Error('no text'); }
  } catch(e) {
    const fallbacks = {
      enemy:   ['Circulez, il n\'y a rien a vous dire.', 'Votre presence m\'importune.', 'Je n\'ai rien a declarer.'],
      ally:    ['Ah, vous voila ! On a des choses a discuter.', 'Je vous attendais justement.', 'Entrons dans le vif du sujet.'],
      neutral: ['Bonjour. Que puis-je faire pour vous ?', 'Oui ? J\'ecoute.', 'En quoi puis-je vous aider ?']
    };
    const list = fallbacks[pnj.rel] || fallbacks.neutral;
    speech.textContent = list[Math.floor(Math.random() * list.length)];
  }
}

function closePnjModal() {
  document.getElementById('modal-pnj').classList.remove('open');
}

// Ajouter un contact au repertoire
function addContactByName(name, role, rel) {
  addContact({ name: name, role: role, rel: rel });
}

function addContact(pnj) {
  if (!state.contacts) state.contacts = [];
  const exists = state.contacts.find(c => c.name === pnj.name);
  if (exists) {
    showToast('Deja dans le repertoire', pnj.name + ' est deja dans vos contacts.', false);
    return;
  }
  state.contacts.push({ name: pnj.name, role: pnj.role, rel: pnj.rel });
  showToast('Contact ajoute', pnj.name + ' a ete ajoute a votre repertoire.', true);
  addJournalEntry(pnj.name + ' ajoute au repertoire.', '');
}

// Loge — demander le responsable
function logeDemanderResponsable() {
  const speech = document.getElementById('pnj-speech');
  speech.textContent = "Le portier disparait un instant puis revient. Il dit : Je lui transmets votre demande. Le Venerable Maitre vous repondra des qu'il en aura pris connaissance.";
  addMailNotification('Loge Maconnique', "Demande d'audience", "Votre demande d'entretien avec le Venerable Maitre a ete transmise. Vous recevrez une reponse des qu'il en aura pris connaissance.");
  addJournalEntry('Vous avez demande une audience aupres du Venerable Maitre de la Loge.', 'event-info');
}

function logeDemanderAdhesion() {
  const speech = document.getElementById('pnj-speech');
  speech.textContent = '"Vous devez vous faire recommander par un parrain membre de notre Loge. Sans cela, votre demande ne peut aboutir." La porte se referme.';
  addJournalEntry("La Loge vous a informe qu'un parrain est necessaire pour adherer.", '');
}

// =====================
// SYSTEME DE GROUPE
// =====================
function rejoindrePJ(encodedPnj) {
  let pnj;
  try { pnj = JSON.parse(decodeURIComponent(encodedPnj)); } catch(e) { return; }
  const myName = state.char && state.char.name ? state.char.name : 'Joueur';
  if (!state.group) {
    state.group = { leader: pnj.name, members: [pnj.name, myName] };
  } else {
    if (!state.group.members.includes(myName)) state.group.members.push(myName);
  }
  if (state.employees && state.employees.length > 0) {
    state.employees.forEach(function(e) {
      if (!state.group.members.includes(e.name)) state.group.members.push(e.name);
    });
  }
  closePnjModal();
  showToast('Groupe rejoint !', 'Vous avez rejoint le groupe de ' + pnj.name + '. Il est le leader.', true);
  addJournalEntry('Vous avez rejoint le groupe de ' + pnj.name + '.', 'event-info');
}

function quitterGroupe() {
  const myName = state.char && state.char.name ? state.char.name : 'Joueur';
  if (!state.group) return;
  state.group.members = state.group.members.filter(function(m) { return m !== myName; });
  if (state.group.members.length <= 1) state.group = null;
  closePnjModal();
  showToast('Groupe quitte', 'Vous avez quitte le groupe.', false);
  addJournalEntry('Vous avez quitte le groupe.', '');
}

function getGroupSize() {
  if (!state.group) return 1 + (state.employees ? state.employees.length : 0);
  return state.group.members.length;
}

function isGroupLeader() {
  if (!state.group) return true;
  return state.group.leader === (state.char && state.char.name ? state.char.name : 'Joueur');
}

// =====================
// ARMURERIE
// =====================
function doAcheterArme(legal) {
  const cur = COUNTRIES[state.char && state.char.country ? state.char.country : 'republic'] && COUNTRIES[state.char.country].cur ? COUNTRIES[state.char.country].cur : 'FR';
  const cost = legal ? 400 : 800;
  if (legal) {
    if (state.arg < cost) { showToast('Fonds insuffisants', 'Il vous faut ' + cost + ' ' + cur, false); return; }
    state.arg -= cost;
    addToInventory({ name: 'Pistolet (legal)', icon: 'ti-shield', type: 'arme', legal: true });
    if (!state.registreArmes) state.registreArmes = [];
    state.registreArmes.push({ acheteur: state.char && state.char.name, arme: 'Pistolet', date: 'Jour ' + state.day, legal: true });
    updateUI();
    showToast('Arme achetee', 'Pistolet acquis legalement. Enregistre dans le registre.', true);
    addJournalEntry('Achat arme legal. Enregistre dans le registre de l armurerie.', '');
  } else {
    if (state.tentativeArmeIllegale && state.tentativeArmeIllegale >= state.day) {
      showToast('Impossible', 'Vous devez dormir avant de retenter cette approche.', false);
      return;
    }
    if (state.arg < cost) { showToast('Fonds insuffisants', 'Il vous faut ' + cost + ' ' + cur, false); return; }
    const roll = Math.floor(Math.random() * 100) + 1;
    if (roll <= 50) {
      state.arg -= cost;
      state.dis = Math.max(0, state.dis - 5);
      addToInventory({ name: 'Pistolet (non enregistre)', icon: 'ti-eye-off', type: 'arme', legal: false });
      updateUI();
      showToast('Arme obtenue !', 'Pistolet acquis sans enregistrement. -5 Discretion.', true, true);
      addJournalEntry('Achat arme illicite reussi. Non enregistre.', '');
    } else {
      state.tentativeArmeIllegale = state.day;
      showToast('Echec', "L'armurier a refuse. Reessayez apres avoir dormi.", false);
      addJournalEntry('Tentative achat illicite echouee. Dormez avant de retenter.', 'event-bad');
    }
  }
}

function doConsulterRegistre() {
  const cur = COUNTRIES[state.char && state.char.country ? state.char.country : 'republic'] && COUNTRIES[state.char.country].cur ? COUNTRIES[state.char.country].cur : 'FR';
  const postesAutorise = ['commissaire','juge','magistrat'];
  const hasAccess = state.poste && postesAutorise.some(function(p) { return state.poste.id && state.poste.id.includes(p); });
  const registre = state.registreArmes || [];
  const derniers = registre.filter(function(r) { return state.day - parseInt(r.date.replace('Jour ','')) <= 180; });
  if (hasAccess) {
    const msg = derniers.length === 0 ? 'Aucune vente enregistree les 6 derniers mois.' : derniers.map(function(r) { return r.acheteur + ' : ' + r.arme + ' (' + r.date + ')'; }).join(' | ');
    showToast('Registre consulte', msg.substring(0,100), true);
    addJournalEntry(msg, 'event-info');
  } else {
    const roll = Math.floor(Math.random() * 100) + 1;
    if (roll <= 30) {
      if (state.arg < 100) { showToast('Fonds insuffisants', '100 ' + cur + ' requis.', false); return; }
      state.arg -= 100;
      state.inf = Math.min(100, state.inf + 5);
      state.pop = Math.min(100, state.pop + 5);
      const msg = derniers.length === 0 ? 'Aucune vente.' : derniers.map(function(r) { return r.acheteur + ' : ' + r.arme; }).join(' | ');
      updateUI();
      showToast('Registre obtenu', '+5 INF +5 POP.', true);
      addJournalEntry('Registre consulte apres corruption. ' + msg, 'event-info');
    } else {
      state.inf = Math.max(0, state.inf - 5);
      state.pop = Math.max(0, state.pop - 5);
      updateUI();
      showToast('Refuse !', "L'armurier refuse et vous signale. -5 INF -5 POP.", false);
      addJournalEntry('Corruption armurerie echouee. -5 INF -5 POP.', 'event-bad');
    }
  }
}

// =====================
// MARCHANDER UN VOTE
// =====================
function openMarchanderVoteModal() {
  const votes = state.votesEnCours || [];
  if (votes.length === 0) {
    showToast('Aucun vote en cours', "Aucun vote en cours a l'Assemblee.", false);
    return;
  }
  const bonusInf = Math.floor((state.inf / 100) * 10);
  const tauxFinal = Math.min(90, 40 + bonusInf);
  document.getElementById('modal-postes').querySelector('.modal-title').textContent = 'Marchander un vote';
  let html = '<div style="padding:1rem"><div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Taux : ' + tauxFinal + '% (base 40% + ' + bonusInf + '% INF). Cout : 200 FR + 1 PA si succes.</div>';
  votes.forEach(function(v, i) {
    html += '<div style="padding:.7rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.5rem">';
    html += '<div style="font-family:Playfair Display,serif;font-size:.88rem;color:#E8C97A;margin-bottom:.2rem">' + (v.titre || 'Vote ' + i) + '</div>';
    html += '<div style="font-size:.72rem;color:#6a5a30">Pour : ' + (v.pour||0) + ' | Contre : ' + (v.contre||0) + '</div>';
    html += '<button onclick="state._voteIdx=' + i + ';soumettreVoteMarchande(' + tauxFinal + ')" style="margin-top:.4rem;font-family:Bebas Neue,sans-serif;font-size:.72rem;padding:.3rem .7rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Marchander ce vote</button>';
    html += '</div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function soumettreVoteMarchande(taux) {
  const voteId = state._voteIdx !== undefined ? (state.votesEnCours || [])[state._voteIdx]?.id : null;
  document.getElementById('modal-postes').classList.remove('open');
  const cur = COUNTRIES[state.char && state.char.country ? state.char.country : 'republic'] && COUNTRIES[state.char.country].cur ? COUNTRIES[state.char.country].cur : 'FR';
  if (state.arg < 200) { showToast('Fonds insuffisants', '200 ' + cur + ' requis.', false); return; }
  const roll = Math.floor(Math.random() * 100) + 1;
  const vote = (state.votesEnCours || []).find(function(v) { return v.id === voteId; });
  if (roll <= taux) {
    state.arg -= 200; state.pa = Math.max(0, state.pa - 1); state.inf = Math.min(100, state.inf + 3);
    if (vote) vote.pour = (vote.pour || 0) + 1;
    updateUI();
    showToast('Vote marchande !', 'Un depute a vote dans votre sens. -200 ' + cur + ' -1 PA +3 INF.', true, true);
    addJournalEntry('Vote marchande avec succes : ' + (vote && vote.titre ? vote.titre : voteId), 'event-good');
  } else {
    showToast('Refuse !', "Le depute n'a pas accepte.", false);
    addJournalEntry('Tentative corruption depute echouee.', 'event-bad');
  }
}

// =====================
// POSTES MODAL
// =====================
function openPostesModal() {
  const postes = POSTES[state.country];
  if (!postes) return;

  const world = WORLD[state.country];
  const city = world?.[state.currentCity];
  const co = COUNTRIES[state.country];

  let allPostes = [];
  if (city?.isCapitale) {
    allPostes = [...(postes.capitale || []), ...(postes.assemblee || [])];
  } else {
    allPostes = postes[state.currentCity] || [];
  }

  const available = allPostes.filter(p => !p.holder || p.holder.startsWith('PNJ'));

  document.getElementById('postes-body').innerHTML = `
    <div style="padding:.8rem 1rem;font-size:.8rem;color:#8a8060;border-bottom:1px solid #1a1810;font-style:italic">
      ${available.length} poste(s) disponible(s) a ${city?.name || 'cette ville'}.
    </div>
    ${allPostes.map(p => `
      <div class="poste-item">
        <div>
          <div class="poste-name">${p.name}</div>
          <div class="poste-holder">${p.holder ? (p.holder.startsWith('PNJ') ? 'Occupe par un PNJ (delogeable)' : `Occupe par ${p.holder}`) : 'Poste vacant'}</div>
        </div>
        ${!p.holder
          ? `<button class="poste-btn" onclick="postulerPoste('${p.id}','${p.name}')">Postuler</button>`
          : p.holder.startsWith('PNJ')
            ? `<button class="poste-btn pnj" onclick="postulerPoste('${p.id}','${p.name}')">Deloger le PNJ</button>`
            : `<button class="poste-btn" style="opacity:.4;cursor:default">Occupe</button>`
        }
      </div>`).join('')}
  `;

  document.getElementById('modal-postes').classList.add('open');
}

async function postulerPoste(posteId, posteName) {
  document.getElementById('modal-postes').classList.remove('open');

  // Verifier si c'est un poste ministeriel — necessite validation du President
  const postesMinisteriels = ['pm','min_int','min_fin','min_just','min_def','min_info','min_ae'];
  if (postesMinisteriels.includes(posteId)) {
    showToast('Demande transmise', `Votre candidature au poste de ${posteName} a ete transmise au President de la Republique. Vous aurez une reponse sous peu.`, true);
    addJournalEntry(`Demande de poste envoyee : ${posteName}. En attente de reponse presidentielle.`, 'event-info');
    // Stocker la demande en attente
    if (!state.pendingPostRequests) state.pendingPostRequests = [];
    state.pendingPostRequests.push({ posteId, posteName, date: `Jour ${state.day}` });
    return;
  }

  // Verifier si le joueur n'a pas deja ce poste
  if (state.poste?.id === posteId) {
    showToast('Poste deja occupe', `Vous occupez deja le poste de ${posteName}.`, false);
    return;
  }

  const postes = POSTES[state.country];
  const allPostes = [
    ...(postes?.capitale || []),
    ...(postes?.assemblee || []),
    ...(postes?.[state.currentCity] || [])
  ];
  const poste = allPostes.find(p => p.id === posteId);
  const isVacant = !poste?.holder;
  const isPnjHolder = poste?.holder?.startsWith('PNJ');

  const successRate = isVacant ? 90 : isPnjHolder ? 65 : 0;
  if (successRate === 0) {
    showToast('Poste occupe', `Ce poste est occupe par un autre joueur.`, false);
    return;
  }

  const roll = Math.floor(Math.random() * 100) + 1;
  if (roll <= successRate) {
    // Marquer le poste comme pris
    if (poste) poste.holder = state.char?.name || 'Joueur';
    state.poste = { id: posteId, name: posteName };
    state.salaireTouche = false;
    state.inf = Math.min(100, state.inf + 15);
    updateUI();
    showToast('Poste obtenu !', `Vous occupez desormais le poste de ${posteName}. +15 Influence.`, true, true);
    addJournalEntry(`Poste obtenu : ${posteName}. +15 Influence.`, 'event-good');
    // Mettre a jour l'affichage du personnage
    if (document.getElementById('char-arch-left')) {
      const ar = ARCHETYPES.find(x => x.id === state.char?.archetype);
      const co = COUNTRIES[state.country];
      document.getElementById('char-arch-left').textContent = `${posteName} · ${co?.n||''}`;
    }
  } else {
    showToast('Candidature refusee', `Votre demande pour le poste de ${posteName} a ete rejetee.`, false);
    addJournalEntry(`Candidature refusee : ${posteName}.`, 'event-bad');
  }
}

// =====================
// PLAINTE MODALE
// =====================
function openPlainteModal() {
  const contacts = state.contacts || [];

  const contactsSection = contacts.length === 0
    ? `<div style="font-size:.8rem;color:#7a5020;font-style:italic;padding:.5rem;background:#0f0805;border:1px solid #2a1810">
        Votre repertoire est vide. Veuillez prealablement enregistrer la personne que vous ciblez dans celui-ci.
       </div>`
    : contacts.map(c => `
        <label style="display:flex;align-items:center;gap:.5rem;font-size:.85rem;color:#c0b090;cursor:pointer;padding:.2rem 0">
          <input type="radio" name="plainte-cible" value="${c.name}" style="accent-color:#C9A84C"/>
          ${c.name} — ${c.role || ''}
        </label>`).join('');

  const modalHtml = `
    <div style="padding:1rem">
      <div style="font-size:.85rem;color:#8a8060;font-style:italic;margin-bottom:1rem">
        Vous deposez une plainte. Un resultat vous sera communique par mail dans 24h.
      </div>
      <div style="margin-bottom:1rem">
        <div style="font-family:'Bebas Neue',sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.5rem">CONTRE</div>
        <label style="display:flex;align-items:center;gap:.5rem;font-size:.85rem;color:#c0b090;cursor:pointer;margin-bottom:.6rem">
          <input type="radio" name="plainte-cible" value="X" checked style="accent-color:#C9A84C"/>
          Contre X (personne inconnue)
        </label>
        <div style="font-family:'Bebas Neue',sans-serif;font-size:.68rem;letter-spacing:.1em;color:#5a4a20;margin-bottom:.4rem">OU CONTRE UNE PERSONNE DE MON REPERTOIRE :</div>
        ${contactsSection}
      </div>
      <div style="margin-bottom:1rem">
        <div style="font-family:'Bebas Neue',sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">MOTIF</div>
        <textarea id="plainte-motif" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.6rem;font-family:'Crimson Pro',serif;font-size:.85rem;height:70px;outline:none;resize:none" placeholder="Decrivez les faits reproches..."></textarea>
      </div>
      <button onclick="soumettrePlaynte()" style="font-family:'Bebas Neue',sans-serif;letter-spacing:.1em;font-size:.82rem;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">
        <i class="ti ti-send" style="font-size:.8rem"></i> Deposer la plainte
      </button>
    </div>
  `;

  document.getElementById('modal-postes').querySelector('.modal-title').textContent = 'Porter plainte';
  document.getElementById('postes-body').innerHTML = modalHtml;
  document.getElementById('modal-postes').classList.add('open');
}

function soumettrePlaynte() {
  const cible = document.querySelector('input[name="plainte-cible"]:checked')?.value || 'X';
  const motif = document.getElementById('plainte-motif')?.value?.trim() || 'Motif non precise';
  document.getElementById('modal-postes').classList.remove('open');

  const h = String(state.hour).padStart(2,'0');
  const m = String(state.minute||0).padStart(2,'0');
  const resultH = (state.hour + 24) % 24;

  addJournalEntry(`Plainte deposee contre ${cible}. Motif : ${motif}. Vous serez informe du resultat demain a ${String(resultH).padStart(2,'0')}h${m}.`, 'event-info');
  showToast('Plainte enregistree', `Resultat communique demain a ${String(resultH).padStart(2,'0')}h${m}.`, true);

  // Simuler le resultat 24h apres (en jeu = apres l'ordre dormir)
  if (!state.plaintesEnCours) state.plaintesEnCours = [];
  state.plaintesEnCours.push({
    cible, motif,
    heure: `${String(resultH).padStart(2,'0')}h${m}`,
    day: state.day + 1,
    status: 'pending'
  });
}

function traiterPlaintes() {
  if (!state.plaintesEnCours) return;
  const traitees = state.plaintesEnCours.filter(p => p.day <= state.day && p.status === 'pending');
  traitees.forEach(p => {
    p.status = 'done';
    const roll = Math.floor(Math.random() * 100) + 1;
    let result = '';
    if (roll < 40) {
      result = `Classement sans suite. La plainte contre ${p.cible} n'a pas abouti.`;
    } else if (roll < 75) {
      result = `Ouverture d'une enquete concernant ${p.cible}. Conclusions dans 24h.`;
      // Programmer le resultat de l'enquete
      if (!state.enquetesEnCours) state.enquetesEnCours = [];
      state.enquetesEnCours.push({ cible: p.cible, day: state.day + 1, status: 'pending' });
    } else {
      result = `Actes illegaux confirmes pour ${p.cible}. Mise en garde a vue. Proces dans 24h.`;
      addExternalEvent(`ACTION EXTERIEURE : ${p.cible} a ete place(e) en garde a vue suite a votre plainte. Proces prevu demain.`);
    }
    addMailNotification('Commissariat Central', `RE: Votre plainte du Jour ${p.day - 1}`, result);
  });
}

function traiterEnquetes() {
  if (!state.enquetesEnCours) return;
  const traitees = state.enquetesEnCours.filter(e => e.day <= state.day && e.status === 'pending');
  traitees.forEach(e => {
    e.status = 'done';
    const roll = Math.floor(Math.random() * 100) + 1;
    let result = '';
    if (roll < 50) {
      result = `Enquete conclue : non-lieu pour ${e.cible}. Aucune preuve suffisante.`;
    } else {
      result = `Enquete conclue : actes illegaux confirmes pour ${e.cible}. Mise en garde a vue immediate. Proces demain.`;
      if (!state.prisonniers) state.prisonniers = [];
      state.prisonniers.push({ nom: e.cible, depuis: `Jour ${state.day}`, raison: 'Garde a vue suite a enquete' });
      addExternalEvent(`${e.cible} a ete place(e) en garde a vue. Visible dans les archives du commissariat.`);
    }
    addMailNotification('Brigade Criminelle', `Conclusions enquete : ${e.cible}`, result);
  });
}

// Ajouter evenement externe (rouge + gras + point clignotant)
// =====================
// MARCHE — ORDRES SPECIFIQUES
// =====================
async function doPoulsPopulaire() {
  addJournalEntry('Vous interrogez les passants du marche...', '');
  showToast('Sondage en cours', 'Les habitants parlent...', true);

  // Generer un sondage via IA
  const char = state.char;
  const co = COUNTRIES[state.country];
  const prompt = `Tu es un narrateur dans un jeu de role politique parodique (Res Publica, empire ${co?.n}).
Genere un court sondage d'opinion populaire (2-3 phrases) comme si tu etais un habitant du marche.
${state.electionsEnCours?.length > 0
  ? `Il y a des elections en cours avec ces candidats : ${state.electionsEnCours.map(e => e.candidats?.join(', ')).join(' | ')}. Donne un resultat en pourcentages.`
  : `Pas d'election en cours. Parle de la popularite des personnages politiques connus : ${state.pjConnus?.join(', ') || 'personne de particulier'}.`
}
Style : direct, populaire, parodique. Format : phrase construite du genre "D'apres ce qu'on entend, X serait le plus populaire..." Reponds uniquement avec le sondage.`;

  try {
    const resp = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ model: 'claude-sonnet-4-20250514', max_tokens: 150, messages: [{ role: 'user', content: prompt }] })
    });
    const data = await resp.json();
    const text = data.content?.[0]?.text;
    if (text) {
      showToast('Pouls de la population', text.substring(0, 100), true);
      addJournalEntry('Sondage : ' + text, 'event-info');
    }
  } catch(e) {
    const fallback = `D'apres les habitants, la situation politique est tendue. "On ne sait plus qui croire", dit une marchande.`;
    showToast('Pouls de la population', fallback, true);
    addJournalEntry('Sondage : ' + fallback, 'event-info');
  }
}

function doDistribuerTract() {
  const tracts = state.inventory.filter(i => i.type === 'tract');
  if (tracts.length === 0) {
    showToast('Aucun tract', 'Vous n\'avez pas de tract en inventaire. Faites-en imprimer a l\'imprimerie.', false);
    return;
  }
  const roll = Math.floor(Math.random() * 100) + 1;
  if (roll <= 70) {
    state.pop = Math.min(100, state.pop + 2);
    tracts[0].qty = (tracts[0].qty || 1) - 1;
    if (tracts[0].qty <= 0) state.inventory = state.inventory.filter(i => i !== tracts[0]);
    updateUI();
    addJournalEntry('Vous avez distribue des tracts. +2 POP.', 'event-good');
    showToast('Tracts distribues', '+2 Popularite. Les passants prennent vos tracts.', true);
  } else {
    addJournalEntry('Distribution de tracts peu efficace. Les passants ignorent vos tracts.', '');
    showToast('Distribution difficile', 'Les passants ne s\'y interessent pas beaucoup.', false);
  }
}

function openRumeurModal() {
  const contacts = state.contacts || [];
  if (contacts.length === 0) {
    showToast('Repertoire vide', 'Vous n\'avez personne dans votre repertoire. Rencontrez d\'abord des personnages.', false);
    return;
  }
  document.getElementById('modal-postes').querySelector('.modal-title').textContent = 'Lancer une rumeur';
  document.getElementById('postes-body').innerHTML = `
    <div style="padding:1rem">
      <div style="font-size:.82rem;color:#8a8060;font-style:italic;margin-bottom:1rem">
        Taux de reussite : 50%. En cas de succes : +/-5 POP sur la cible.
      </div>
      <div style="margin-bottom:1rem">
        <div style="font-family:'Bebas Neue',sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">CIBLE</div>
        ${contacts.map(c => `
          <label style="display:flex;align-items:center;gap:.5rem;font-size:.82rem;color:#c0b090;cursor:pointer;padding:.2rem 0">
            <input type="radio" name="rumeur-cible" value="${c.name}" style="accent-color:#C9A84C"/>
            ${c.name}
          </label>`).join('')}
      </div>
      <div style="margin-bottom:1rem">
        <div style="font-family:'Bebas Neue',sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">TYPE DE RUMEUR</div>
        <label style="display:flex;align-items:center;gap:.5rem;font-size:.82rem;color:#6a9060;cursor:pointer;margin-bottom:.3rem">
          <input type="radio" name="rumeur-type" value="positive" style="accent-color:#4a8a4a"/> Rumeur positive (+5 POP sur la cible)
        </label>
        <label style="display:flex;align-items:center;gap:.5rem;font-size:.82rem;color:#9a5040;cursor:pointer">
          <input type="radio" name="rumeur-type" value="negative" checked style="accent-color:#8a3a2a"/> Rumeur negative (-5 POP sur la cible)
        </label>
      </div>
      <button onclick="soumettreRumeur()" style="font-family:'Bebas Neue',sans-serif;letter-spacing:.1em;font-size:.82rem;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">
        Lancer la rumeur
      </button>
    </div>`;
  document.getElementById('modal-postes').classList.add('open');
}

function soumettreRumeur() {
  const cible = document.querySelector('input[name="rumeur-cible"]:checked')?.value;
  const type = document.querySelector('input[name="rumeur-type"]:checked')?.value || 'negative';
  document.getElementById('modal-postes').classList.remove('open');
  if (!cible) { showToast('Selectionnez une cible', '', false); return; }

  const roll = Math.floor(Math.random() * 100) + 1;
  if (roll <= 50) {
    const impact = type === 'positive' ? 5 : -5;
    addJournalEntry(`Rumeur ${type} sur ${cible} lancee avec succes. Impact : ${impact > 0 ? '+' : ''}${impact} POP sur ${cible}.`, 'event-good');
    showToast('Rumeur repandue', `La rumeur ${type} circule sur ${cible}. ${impact > 0 ? '+' : ''}${impact} POP.`, true);
  } else {
    addJournalEntry(`Rumeur sur ${cible} : personne n'y a cru.`, '');
    showToast('Rumeur inefficace', 'Personne ne semble y preter attention.', false);
  }
}

// =====================
// ASSASSINAT
// =====================
function ouvrirModalAssassinat(encodedCible) {
  let cible;
  try { cible = JSON.parse(decodeURIComponent(encodedCible)); } catch(e) { return; }

  const char = state.char;
  const armes = (state.inventory||[]).filter(i => i.type === 'arme');
  const hasBlade = armes.some(a => a.name.toLowerCase().includes('couteau') || a.name.toLowerCase().includes('arme blanche'));
  const hasGun   = armes.some(a => a.name.toLowerCase().includes('pistolet') || a.name.toLowerCase().includes('feu'));

  const vol = char?.stats?.VOL || 8;
  const per = char?.stats?.PER || 8;
  const dup = char?.stats?.DUP || 8;

  const tauxMains = Math.min(60, 20 + Math.floor(vol * 1.5));
  const tauxArme  = Math.min(75, 40 + Math.floor(dup * 1.2));
  const tauxFeu   = Math.min(85, 60 + Math.floor(per * 1.0));

  document.getElementById('modal-postes').querySelector('.modal-title').textContent = 'Assassiner — ' + cible.name;
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.82rem;color:#cc4444;font-style:italic;margin-bottom:1rem;padding:.5rem;background:#0f0505;border:1px solid #3a1010">Acte criminel. Peine : 7 jours QHS si echec. 15 jours si decouvert ulterieurement.</div>';

  // Options
  html += '<div style="display:flex;flex-direction:column;gap:.5rem">';

  html += '<button onclick="confirmerAssassinat(\'' + encodedCible + '\',\'mains\',' + tauxMains + ')" style="display:flex;justify-content:space-between;align-items:center;padding:.6rem 1rem;border:1px solid #3a2010;background:#0f0805;color:#c0a080;cursor:pointer;font-family:Crimson Pro,serif;font-size:.85rem">' +
    '<span>A mains nues</span><span style="font-family:Bebas Neue,sans-serif;font-size:.75rem;color:#8a6040">' + tauxMains + '% · 2 PA</span></button>';

  html += '<button onclick="confirmerAssassinat(\'' + encodedCible + '\',\'arme\',' + tauxArme + ')" ' +
    (!hasBlade ? 'disabled style="opacity:.4;cursor:not-allowed;' : 'style="cursor:pointer;') +
    'display:flex;justify-content:space-between;align-items:center;padding:.6rem 1rem;border:1px solid #4a1a08;background:#0f0805;color:' + (hasBlade ? '#c06040' : '#4a3020') + ';font-family:Crimson Pro,serif;font-size:.85rem">' +
    '<span>Arme blanche ' + (!hasBlade ? '(aucune en inventaire)' : '') + '</span>' +
    '<span style="font-family:Bebas Neue,sans-serif;font-size:.75rem;color:#8a5030">' + tauxArme + '% · 2 PA</span></button>';

  html += '<button onclick="confirmerAssassinat(\'' + encodedCible + '\',\'feu\',' + tauxFeu + ')" ' +
    (!hasGun ? 'disabled style="opacity:.4;cursor:not-allowed;' : 'style="cursor:pointer;') +
    'display:flex;justify-content:space-between;align-items:center;padding:.6rem 1rem;border:1px solid #5a1a08;background:#0f0805;color:' + (hasGun ? '#cc4444' : '#4a2020') + ';font-family:Crimson Pro,serif;font-size:.85rem">' +
    '<span>Arme a feu ' + (!hasGun ? '(aucune en inventaire)' : '') + ' — bruit !</span>' +
    '<span style="font-family:Bebas Neue,sans-serif;font-size:.75rem;color:#8a3030">' + tauxFeu + '% · 3 PA · -20 DIS</span></button>';

  html += '</div></div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerAssassinat(encodedCible, mode, taux) {
  document.getElementById('modal-postes').classList.remove('open');
  let cible;
  try { cible = JSON.parse(decodeURIComponent(encodedCible)); } catch(e) { return; }

  const paCost = mode === 'feu' ? 3 : 2;
  if (!TEST_MODE) state.pa = Math.max(0, state.pa - paCost);

  const roll = Math.floor(Math.random() * 100) + 1;

  if (roll <= taux) {
    // Succes
    if (mode === 'feu') state.dis = Math.max(0, state.dis - 20);

    // Marquer la cible comme assassinee
    if (!state.assassinats) state.assassinats = [];
    state.assassinats.push({ cible: cible.name, jour: state.day, mode, decouvert: false });

    // Effets sur la cible si PJ simule
    const pjSimule = state.pjSimules?.find(p => p.name === cible.name);
    if (pjSimule) {
      pjSimule.resources.hp = 5;
      pjSimule.estAssassine = { jour: state.day, ville: state.currentCity };
    }

    // Reduction population si PNJ
    if (!cible.isPJ) {
      const pop = CITY_POPULATION[state.country]?.[state.currentCity];
      if (pop) pop.total = Math.max(0, pop.total - 1);
    }

    showToast('Acte commis', cible.name + ' est grièvement blesse(e). Vous n\'etes pas identifie(e).', false);
    addJournalEntry('Vous avez attaque ' + cible.name + ' (' + mode + '). Non identifie(e) pour l\'instant.', 'event-bad');

    // Detection potentielle
    checkDetection('assassiner_' + mode, 'success');

  } else {
    // Echec — arrested
    addExternalEvent('Tentative d\'homicide sur ' + cible.name + ' ! Vous avez ete identifie(e). Arrestation imminente.');
    state.recherche = [{ acte: 'tentative_homicide', type: 'crime', jour: state.day }];
    setTimeout(() => ouvrirModalArrestation('crime'), 800);
  }
  updateUI();
}

// =====================
// MODE SIMULATION PJ
// =====================
function initSimulation() {
  if (!state.pjSimules) {
    state.pjSimules = JSON.parse(JSON.stringify(PJ_SIMULES));
  }
}

function getSimulesPresents() {
  if (!state.pjSimules) initSimulation();
  return state.pjSimules.filter(p =>
    p.currentCity === state.currentCity &&
    p.currentBuilding === state.currentBuilding &&
    !p.estAssassine
  );
}

function ouvrirPanneauSimulation() {
  if (!state.pjSimules) initSimulation();
  document.getElementById('modal-postes').querySelector('.modal-title').textContent = 'Joueurs Simules — Mode Test';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#6a5a30;font-style:italic;margin-bottom:.8rem;padding:.5rem;background:#0a0805;border:1px solid #1a1810">Mode simulation actif. Ces PJ fictifs permettent de tester les interactions multijoueur.</div>';

  state.pjSimules.forEach((p, i) => {
    const ar = ARCHETYPES.find(x => x.id === p.archetype);
    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.8rem;margin-bottom:.6rem">';
    html += '<div style="display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:.4rem">';
    html += '<div><div style="font-family:Playfair Display,serif;font-size:.9rem;color:#E8C97A">' + p.name + '</div>';
    html += '<div style="font-size:.72rem;color:#6a5a30">' + p.role + '</div>';
    html += (p.poste ? '<div style="font-size:.68rem;color:#C9A84C;margin-top:.15rem">' + p.poste.name + '</div>' : '') + '</div>';
    html += '<div style="font-size:.68rem;color:' + (p.estAssassine ? '#cc2020' : '#4a8a4a') + '">' + (p.estAssassine ? 'Hospitalise' : 'Actif') + '</div>';
    html += '</div>';

    // Position et deplacement
    const cityName = WORLD[p.country]?.[p.currentCity]?.name || p.currentCity;
    html += '<div style="font-size:.72rem;color:#5a5040;margin-bottom:.5rem">Position : ' + cityName + (p.currentBuilding ? ' · ' + (BUILDINGS[p.currentBuilding]?.shortName || p.currentBuilding) : ' · Rue') + '</div>';

    // Ressources
    html += '<div style="display:flex;gap:.4rem;flex-wrap:wrap;margin-bottom:.5rem">';
    [['INF',p.resources.inf,'#4a6aaa'],['POP',p.resources.pop,'#aa6a4a'],['DIS',p.resources.dis,'#8a4aaa'],['HP',p.resources.hp,'#aa4a4a']].forEach(([k,v,c]) => {
      html += '<div style="font-size:.65rem;padding:.15rem .4rem;background:#0a0805;border:1px solid #1a1810"><span style="color:#4a4030">' + k + '</span> <span style="color:' + c + ';font-family:Bebas Neue,sans-serif">' + v + '</span></div>';
    });
    html += '</div>';

    // Actions de deplacement
    html += '<div style="display:flex;gap:.3rem;flex-wrap:wrap">';
    Object.entries(WORLD[p.country] || {}).forEach(([cityId, city]) => {
      if (cityId !== p.currentCity) {
        html += '<button onclick="deplacerSimule(' + i + ',\'' + cityId + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.62rem;letter-spacing:.06em;padding:.2rem .4rem;border:1px solid #2a2010;background:transparent;color:#6a5a30;cursor:pointer">→ ' + city.name + '</button>';
      }
    });
    html += '<button onclick="deplacerSimuleBatiment(' + i + ')" style="font-family:Bebas Neue,sans-serif;font-size:.62rem;letter-spacing:.06em;padding:.2rem .4rem;border:1px solid #2a4a20;background:transparent;color:#4a7a4a;cursor:pointer">Entrer ici</button>';
    html += '</div>';
    html += '</div>';
  });

  html += '<button onclick="actualiserSimules()" style="width:100%;margin-top:.5rem;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.1em;padding:.4rem;border:1px solid #3a2a10;background:transparent;color:#8a7040;cursor:pointer">Actualiser les positions</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function deplacerSimule(idx, cityId) {
  if (!state.pjSimules?.[idx]) return;
  state.pjSimules[idx].currentCity = cityId;
  state.pjSimules[idx].currentBuilding = null;
  showToast('PJ deplace', state.pjSimules[idx].name + ' est maintenant a ' + (WORLD[state.pjSimules[idx].country]?.[cityId]?.name || cityId), true);
  ouvrirPanneauSimulation();
}

function deplacerSimuleBatiment(idx) {
  if (!state.pjSimules?.[idx]) return;
  state.pjSimules[idx].currentCity = state.currentCity;
  state.pjSimules[idx].currentBuilding = state.currentBuilding;
  showToast('PJ deplace', state.pjSimules[idx].name + ' entre dans ce batiment.', true);
  // Recharger les personnes presentes
  if (state.currentBuilding && state.currentRoom) {
    const b = BUILDINGS[state.currentBuilding];
    const room = b?.rooms?.[state.currentRoom];
    if (room) renderPersonsList(room.persons || []);
  }
  ouvrirPanneauSimulation();
}

function actualiserSimules() {
  ouvrirPanneauSimulation();
}

// =====================
// BUDGET INSTITUTIONS
// =====================
function getBudgetInstitution(institution) {
  const budgets = BUDGETS_INSTITUTIONS[state.country]?.[state.currentCity];
  if (!budgets) return null;
  if (!state.budgetsActuels) state.budgetsActuels = {};
  const key = state.currentCity + '_' + institution;
  if (!state.budgetsActuels[key]) {
    state.budgetsActuels[key] = { ...budgets[institution] };
  }
  return state.budgetsActuels[key];
}

function depenseBudget(institution, montant) {
  const b = getBudgetInstitution(institution);
  if (!b) return true;
  if (b.budget < montant) {
    showToast('Budget insuffisant', institution + ' manque de fonds. Le maire doit augmenter le budget.', false);
    addExternalEvent('L\'institution ' + institution + ' est sous-financee. Certains services sont suspendus.');
    return false;
  }
  b.budget -= montant;
  return true;
}

function mettreAJourBudgets() {
  if (!state.budgetsActuels) return;
  // Recettes fiscales allouees aux institutions
  const pop = CITY_POPULATION[state.country]?.[state.currentCity];
  if (!pop) return;
  const recettes = pop.dailyTaxRevenue || 0;
  const allocation = Math.floor(recettes * 0.4); // 40% des recettes aux institutions
  Object.keys(state.budgetsActuels).forEach(key => {
    if (key.startsWith(state.currentCity)) {
      state.budgetsActuels[key].budget = Math.min(
        state.budgetsActuels[key].budget + Math.floor(allocation / 3),
        20000
      );
    }
  });
}

// =====================
// POPULATION DYNAMIQUE
// =====================
function mettreAJourPopulation() {
  Object.keys(CITY_POPULATION[state.country] || {}).forEach(cityId => {
    const pop = CITY_POPULATION[state.country][cityId];
    if (!pop) return;
    // Regeneration lente : +0.1% par jour
    const regen = Math.floor(pop.total * 0.001);
    pop.total = Math.min(pop.totalMax || pop.total * 1.5, pop.total + regen);
    // Recalculer les impots
    pop.dailyTaxRevenue = Math.floor(pop.total * pop.taxRate / 365);
  });
}

// =====================
// TRACTS
// =====================
function ouvrirModalImprimerTracts() {
  const contacts = state.contacts || [];
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  document.getElementById('modal-postes').querySelector('.modal-title').textContent = 'Faire imprimer des tracts';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">150 ' + cur + ' par lot de 10 tracts.</div>';

  if (contacts.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060">Repertoire vide. Ajoutez des contacts pour cibler un PJ.</div>';
  } else {
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">TYPE DE TRACT</div>';
    html += '<div style="display:flex;gap:.5rem;margin-bottom:.7rem">';
    html += '<button id="tract-type-pour" onclick="selectTractType(\'pour\')" style="flex:1;padding:.4rem;border:1px solid #4a8a4a;background:#0a1008;color:#6a9a6a;cursor:pointer;font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em">POUR un PJ</button>';
    html += '<button id="tract-type-contre" onclick="selectTractType(\'contre\')" style="flex:1;padding:.4rem;border:1px solid #2a2010;background:#0f0d05;color:#5a5040;cursor:pointer;font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em">CONTRE un PJ</button>';
    html += '</div>';

    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">CIBLE</div>';
    html += '<select id="tract-cible" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.7rem">';
    contacts.forEach(c => { html += '<option value="' + c.name + '">' + c.name + '</option>'; });
    html += '</select>';

    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">QUANTITE</div>';
    html += '<select id="tract-quantite" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.8rem">';
    [10,20,50,100].forEach(q => {
      const cout = q / 10 * 150;
      html += '<option value="' + q + '">' + q + ' tracts — ' + cout + ' ' + cur + '</option>';
    });
    html += '</select>';

    html += '<button onclick="confirmerImpression()" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Commander</button>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
  // Selectionner "pour" par defaut
  window._tractType = 'pour';
}

function selectTractType(type) {
  window._tractType = type;
  const btnPour = document.getElementById('tract-type-pour');
  const btnContre = document.getElementById('tract-type-contre');
  if (type === 'pour') {
    btnPour.style.cssText = 'flex:1;padding:.4rem;border:1px solid #4a8a4a;background:#0a1808;color:#6a9a6a;cursor:pointer;font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em';
    btnContre.style.cssText = 'flex:1;padding:.4rem;border:1px solid #2a2010;background:#0f0d05;color:#5a5040;cursor:pointer;font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em';
  } else {
    btnPour.style.cssText = 'flex:1;padding:.4rem;border:1px solid #2a2010;background:#0f0d05;color:#5a5040;cursor:pointer;font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em';
    btnContre.style.cssText = 'flex:1;padding:.4rem;border:1px solid #8a2020;background:#1a0808;color:#9a4a4a;cursor:pointer;font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em';
  }
}

function confirmerImpression() {
  const type = window._tractType || 'pour';
  const cible = document.getElementById('tract-cible')?.value;
  const quantite = parseInt(document.getElementById('tract-quantite')?.value || '10');
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cout = quantite / 10 * 150;

  if (state.arg < cout) {
    showToast('Fonds insuffisants', 'Il vous faut ' + cout + ' ' + cur, false);
    return;
  }

  document.getElementById('modal-postes').classList.remove('open');
  state.arg -= cout;
  if (!state.inventory) state.inventory = [];

  // Chercher si un lot similaire existe deja
  const existing = state.inventory.find(i => i.type === 'tract' && i.cible === cible && i.tractType === type);
  if (existing) {
    existing.quantite += quantite;
  } else {
    state.inventory.push({
      type: 'tract',
      name: 'Tracts ' + (type === 'pour' ? 'POUR' : 'CONTRE') + ' ' + cible,
      icon: 'ti-file-description',
      tractType: type,
      cible: cible,
      quantite: quantite,
      legal: true
    });
  }

  updateUI();
  showToast('Tracts imprimes !', quantite + ' tracts ' + type + ' ' + cible + ' ajoutes a votre inventaire. -' + cout + ' ' + cur, true, true);
  addJournalEntry('Production de ' + quantite + ' tracts ' + type + ' ' + cible, 'event-info');
}

function donnerTracts(pjName) {
  const tracts = (state.inventory||[]).filter(i => i.type === 'tract');
  if (tracts.length === 0) {
    showToast('Aucun tract', 'Vous n\'avez pas de tracts en inventaire.', false);
    return;
  }
  document.getElementById('modal-postes').querySelector('.modal-title').textContent = 'Donner des tracts a ' + pjName;
  let html = '<div style="padding:1rem">';
  tracts.forEach((t, idx) => {
    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.7rem;margin-bottom:.5rem">';
    html += '<div style="font-size:.82rem;color:#c0b090;margin-bottom:.4rem">' + t.name + ' <span style="color:#C9A84C">(' + t.quantite + ' restants)</span></div>';
    html += '<div style="display:flex;align-items:center;gap:.5rem">';
    html += '<input id="don-tract-' + idx + '" type="number" min="1" max="' + t.quantite + '" value="1" style="width:60px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.3rem;font-size:.82rem;outline:none">';
    html += '<button onclick="confirmerDonTracts(' + idx + ',\'' + pjName + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;letter-spacing:.08em;padding:.3rem .6rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Donner</button>';
    html += '</div></div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerDonTracts(tractIdx, pjName) {
  const tracts = (state.inventory||[]).filter(i => i.type === 'tract');
  const tract = tracts[tractIdx];
  if (!tract) return;
  const quantite = parseInt(document.getElementById('don-tract-' + tractIdx)?.value || '1');
  if (quantite < 1 || quantite > tract.quantite) {
    showToast('Quantite invalide', 'Entre 1 et ' + tract.quantite, false);
    return;
  }
  document.getElementById('modal-postes').classList.remove('open');
  tract.quantite -= quantite;
  if (tract.quantite <= 0) {
    const i = state.inventory.indexOf(tract);
    state.inventory.splice(i, 1);
  }

  // Ajouter au PJ simule si applicable
  const pjSim = state.pjSimules?.find(p => p.name === pjName);
  if (pjSim) {
    if (!pjSim.inventory) pjSim.inventory = [];
    const existing = pjSim.inventory.find(i => i.type === 'tract' && i.cible === tract.cible && i.tractType === tract.tractType);
    if (existing) { existing.quantite += quantite; }
    else { pjSim.inventory.push({...tract, quantite}); }
  }

  updateUI();
  showToast('Tracts donnes', quantite + ' tracts remis a ' + pjName + '.', true);
  addJournalEntry('Don de ' + quantite + ' tracts a ' + pjName, 'event-info');
}

function distribuerTractPNJ(pnjName) {
  const tracts = (state.inventory||[]).filter(i => i.type === 'tract');
  if (tracts.length === 0) {
    showToast('Aucun tract', 'Vous n\'avez pas de tracts en inventaire.', false);
    return;
  }
  // Utiliser le premier lot de tracts disponible
  const tract = tracts[0];
  tract.quantite -= 1;
  if (tract.quantite <= 0) {
    const i = state.inventory.indexOf(tract);
    state.inventory.splice(i, 1);
  }

  // Jet 50% + bonus INF/10
  const bonusInf = Math.floor(state.inf / 10);
  const taux = Math.min(80, 50 + bonusInf);
  const roll = Math.floor(Math.random() * 100) + 1;
  const succes = roll <= taux;

  if (succes) {
    // Verifier si periode electorale
    const enElection = state.electionsEnCours?.some(e => e.phase === 'campagne');
    const estCandidat = state.electionsEnCours?.some(e =>
      e.candidats?.some(c => c.nom === tract.cible)
    );

    if (enElection && estCandidat) {
      // +1 voix au candidat
      state.electionsEnCours.forEach(e => {
        const candidat = e.candidats?.find(c => c.nom === tract.cible);
        if (candidat) candidat.voix = (candidat.voix||0) + 1;
      });
      showToast('Tract distribue !', pnjName + ' votera pour ' + tract.cible + '. +1 voix.', true, true);
    } else {
      // +/- POP sur la cible
      if (tract.tractType === 'pour') {
        state.pop = Math.min(100, state.pop + 2);
        showToast('Tract distribue !', '+2 POP pour ' + tract.cible, true);
      } else {
        state.pop = Math.max(0, state.pop - 2);
        showToast('Tract distribue !', '-2 POP pour ' + tract.cible, true);
      }
    }
    addJournalEntry('Tract distribue a ' + pnjName + ' — succes.', 'event-good');
  } else {
    showToast('Sans effet', pnjName + ' n\'a pas ete convaincu(e). Tract consomme.', false);
    addJournalEntry('Distribution de tract a ' + pnjName + ' — sans effet.', '');
  }
  updateUI();
}

function doLogePortail() {
  const roll = Math.floor(Math.random() * 100) + 1;
  if (roll <= 95) {
    // Trouver le portier de la loge
    const portier = { name: 'Le Portier', role: 'PNJ - Gardien de la Loge', rel: 'neutral', job: 'portier' };
    openPnjModal(encodeURIComponent(JSON.stringify(portier)));
    addJournalEntry('Le portier de la Loge repond a votre appel.', '');
  } else {
    showToast('Pas de reponse', 'Personne ne repond a votre frappe. Reessayez plus tard.', false);
    addJournalEntry('Vous avez frappe a la porte de la Loge mais personne n\'a repondu.', '');
  }
}

function openNominerModal() {
  const contacts = state.contacts || [];
  const ministeres = ['min_int','min_fin','min_just','min_def','min_info','min_ae'];
  const noms = { min_int:"Ministre de l'Interieur", min_fin:'Ministre des Finances', min_just:'Ministre de la Justice', min_def:'Ministre de la Defense', min_info:"Ministre de l'Information", min_ae:'Ministre des AE' };

  document.getElementById('modal-postes').querySelector('.modal-title').textContent = 'Nommer un ministre';
  let html = '<div style="padding:1rem">';
  if (contacts.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Votre repertoire est vide. Enregistrez d\'abord des contacts.</div>';
  } else {
    html += '<div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Le PJ selectionne recevra un mail de nomination.</div>';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">POSTE</div>';
    html += '<select id="nommer-poste" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.7rem">';
    ministeres.forEach(m => { html += '<option value="' + m + '">' + noms[m] + '</option>'; });
    if (state.postesCustom?.ministre) html += '<option value="custom_ministre">' + state.postesCustom.ministre.nom + '</option>';
    if (state.postesCustom?.comite) html += '<option value="custom_comite">' + state.postesCustom.comite.nom + '</option>';
    html += '</select>';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">NOMME</div>';
    html += '<select id="nommer-contact" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.8rem">';
    contacts.forEach(c => { html += '<option value="' + c.name + '">' + c.name + '</option>'; });
    html += '</select>';
    html += '<button onclick="validerNomination()" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Envoyer la nomination</button>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function validerNomination() {
  const poste = document.getElementById('nommer-poste')?.value;
  const contact = document.getElementById('nommer-contact')?.value;
  if (!poste || !contact) return;
  const noms = { min_int:"Ministre de l'Interieur", min_fin:'Ministre des Finances', min_just:'Ministre de la Justice', min_def:'Ministre de la Defense', min_info:"Ministre de l'Information", min_ae:'Ministre des AE' };
  const posteNom = noms[poste] || (state.postesCustom?.ministre?.nom) || (state.postesCustom?.comite?.nom) || poste;
  document.getElementById('modal-postes').classList.remove('open');
  addMailNotification('Presidence de la Republique', 'Nomination ministerielle', 'Par decision presidentielle, vous etes nomme(e) au poste de ' + posteNom + '. Prenez vos fonctions immediatement.');
  showToast('Nomination envoyee', contact + ' nomme(e) ' + posteNom, true, true);
  addJournalEntry('Nomination de ' + contact + ' au poste de ' + posteNom, 'event-good');
  addExternalEvent('Nomination officielle : ' + contact + ' est nomme(e) ' + posteNom + ' par le President.');
}

function openCandidatureModal() {
  document.getElementById('modal-postes').querySelector('.modal-title').textContent = 'Deposer une candidature';
  const elections = state.electionsEnCours || [];
  document.getElementById('postes-body').innerHTML = `
    <div style="padding:1rem">
      ${elections.length === 0
        ? `<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucune election n'est actuellement en cours. Revenez lorsqu'une election sera declaree.</div>`
        : elections.map(e => `
            <div style="padding:.7rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.5rem">
              <div style="font-family:'Playfair Display',serif;font-size:.9rem;color:#E8C97A;margin-bottom:.2rem">${e.nom}</div>
              <div style="font-size:.72rem;color:#6a5a30">Date : ${e.date} · Candidats : ${e.candidats?.length || 0}</div>
              <button onclick="confirmerCandidature('${e.id}')" style="margin-top:.5rem;font-family:'Bebas Neue',sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.3rem .7rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">
                Me declarer candidat
              </button>
            </div>`).join('')}
      <div style="margin-top:.8rem;font-size:.72rem;color:#4a4030;font-style:italic">
        Pour lancer une election, contactez le Maire ou le Responsable electoral.
      </div>
    </div>`;
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerCandidature(electionId) {
  document.getElementById('modal-postes').classList.remove('open');
  if (!state.electionsEnCours) return;
  const election = state.electionsEnCours.find(e => e.id === electionId);
  if (!election) return;
  if (!election.candidats) election.candidats = [];
  const nom = state.char?.name || 'Anonyme';
  if (election.candidats.find(c => c.nom === nom)) {
    showToast('Deja candidat', 'Vous etes deja candidat a cette election.', false);
    return;
  }
  election.candidats.push({ nom, voix: 0, isPJ: true });
  showToast('Candidature enregistree !', 'Vous etes officiellement candidat a ' + election.nom, true, true);
  addJournalEntry('Candidature deposee pour : ' + election.nom, 'event-good');
  addMailNotification('Commission Electorale', 'Confirmation de candidature', 'Votre candidature pour le poste de ' + election.nom + ' a bien ete enregistree. La campagne electorale debute dans ' + (election.joursAvantCampagne || 0) + ' jour(s).');
}

function openElectionsModal() {
  document.getElementById('modal-postes').querySelector('.modal-title').textContent = 'Elections en cours';

  // Initialiser des elections de demo si aucune
  if (!state.electionsEnCours || state.electionsEnCours.length === 0) {
    state.electionsEnCours = [
      {
        id: 'election-president-1',
        nom: 'President de la Republique',
        type: 'president',
        phase: 'campagne', // candidatures | campagne | depouillement | termine
        jourDebut: 1,
        jourCampagne: 4,
        jourResultat: 7,
        joursAvantCampagne: 0,
        candidats: [
          { nom: 'Bertrand (PNJ)', voix: 0, isPJ: false },
          { nom: 'Leroux (PNJ)', voix: 0, isPJ: false }
        ],
        tour: 1,
        resultat: null
      }
    ];
  }

  const elections = state.electionsEnCours;
  let html = '<div style="padding:1rem">';

  elections.forEach(e => {
    const phaseLabel = { candidatures: 'Depot des candidatures', campagne: 'Campagne electorale', depouillement: 'Depouillement', termine: 'Termine' }[e.phase] || e.phase;
    const phaseColor = { candidatures: '#6a9a5a', campagne: '#C9A84C', depouillement: '#aa6a4a', termine: '#4a4030' }[e.phase] || '#8a8060';

    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.8rem;margin-bottom:.8rem">';
    html += '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:.4rem">';
    html += '<div style="font-family:Playfair Display,serif;font-size:.9rem;color:#E8C97A">' + e.nom + '</div>';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.68rem;letter-spacing:.1em;color:' + phaseColor + ';border:1px solid;padding:.1rem .4rem">' + phaseLabel + '</div>';
    html += '</div>';
    html += '<div style="font-size:.72rem;color:#6a5a30;margin-bottom:.5rem">Tour ' + (e.tour||1) + ' · Resultats : Jour ' + e.jourResultat + '</div>';

    // Candidats et voix
    if (e.candidats && e.candidats.length > 0) {
      const totalVoix = e.candidats.reduce((s, c) => s + (c.voix||0), 0) || 1;
      html += '<div style="margin-bottom:.5rem">';
      e.candidats.forEach(c => {
        const pct = Math.round((c.voix||0) / totalVoix * 100);
        const isMoi = c.nom === (state.char?.name);
        html += '<div style="display:flex;align-items:center;gap:.5rem;margin-bottom:.2rem">';
        html += '<div style="font-size:.75rem;color:' + (isMoi ? '#C9A84C' : '#c0b090') + ';width:140px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">' + c.nom + (isMoi ? ' (Vous)' : '') + '</div>';
        html += '<div style="flex:1;height:6px;background:#1a1810;border-radius:3px"><div style="height:100%;background:' + (isMoi ? '#C9A84C' : '#4a6a4a') + ';width:' + pct + '%;border-radius:3px"></div></div>';
        html += '<div style="font-size:.7rem;color:#6a5a30;width:30px;text-align:right">' + pct + '%</div>';
        html += '</div>';
      });
      html += '</div>';
    }

    // Boutons selon phase
    const dejaCandidatObj = e.candidats && e.candidats.find(c => c.nom === (state.char?.name));
    if (e.phase === 'candidatures' && !dejaCandidatObj) {
      html += '<button onclick="confirmerCandidature(\'' + e.id + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.3rem .7rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer;margin-right:.4rem">Me declarer candidat</button>';
    }
    if (e.phase === 'campagne') {
      html += '<button onclick="voterElection(\'' + e.id + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.3rem .7rem;border:1px solid #4a8a4a;background:transparent;color:#6a9a6a;cursor:pointer;margin-right:.4rem">' + (state.aVote?.[e.id] ? 'Vote deja exprime' : 'Voter') + '</button>';
    }
    html += '</div>';
  });

  html += '<div style="font-size:.72rem;color:#4a4030;font-style:italic;margin-top:.5rem">Calendrier : candidatures semaine 1-3 · campagne semaine 4-5 · resultats dimanche soir.</div>';
  html += '</div>';

  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function voterElection(electionId) {
  if (state.aVote?.[electionId]) {
    showToast('Vote deja exprime', 'Vous avez deja vote pour cette election.', false);
    return;
  }
  const election = (state.electionsEnCours||[]).find(e => e.id === electionId);
  if (!election || !election.candidats || election.candidats.length === 0) return;

  // Afficher la liste des candidats pour voter
  document.getElementById('modal-postes').classList.remove('open');
  document.getElementById('modal-postes').querySelector('.modal-title').textContent = 'Voter — ' + election.nom;
  let html = '<div style="padding:1rem"><div style="font-size:.82rem;color:#8a8060;font-style:italic;margin-bottom:1rem">Vous ne pouvez voter qu\'une seule fois.</div>';
  election.candidats.forEach((c, i) => {
    html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;cursor:pointer;transition:background .2s" onclick="confirmerVote(\'' + electionId + '\',' + i + ')" onmouseover="this.style.background=\'#151005\'" onmouseout="this.style.background=\'#0f0d05\'">';
    html += '<div style="font-family:Playfair Display,serif;font-size:.85rem;color:#c0b090">' + c.nom + '</div>';
    html += '<div style="font-size:.7rem;color:#5a5040">' + (c.isPJ ? 'Joueur' : 'PNJ') + '</div>';
    html += '</div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerVote(electionId, candidatIdx) {
  document.getElementById('modal-postes').classList.remove('open');
  const election = (state.electionsEnCours||[]).find(e => e.id === electionId);
  if (!election) return;
  if (!state.aVote) state.aVote = {};
  state.aVote[electionId] = true;
  election.candidats[candidatIdx].voix = (election.candidats[candidatIdx].voix||0) + 1;
  // Ajouter voix aleatoires PNJ pour simulation
  election.candidats.forEach((c, i) => {
    if (i !== candidatIdx) c.voix = (c.voix||0) + Math.floor(Math.random() * 5);
  });
  showToast('Vote enregistre !', 'Vous avez vote pour ' + election.candidats[candidatIdx].nom, true, true);
  addJournalEntry('Vote exprime pour ' + election.candidats[candidatIdx].nom + ' (' + election.nom + ')', 'event-info');
}

function calculerResultatElection(election) {
  if (!election || !election.candidats) return;
  const total = election.candidats.reduce((s, c) => s + (c.voix||0), 0) || 1;
  // Ajouter voix PNJ pour simulation realiste
  election.candidats.forEach(c => {
    if (!c.isPJ) c.voix = (c.voix||0) + Math.floor(Math.random() * 200 + 50);
  });
  const sorted = [...election.candidats].sort((a,b) => (b.voix||0) - (a.voix||0));
  const totalFinal = sorted.reduce((s,c) => s + (c.voix||0), 0);
  const premier = sorted[0];
  const pct = Math.round((premier.voix||0) / totalFinal * 100);

  if (pct > 50) {
    // Elu au premier tour
    election.phase = 'termine';
    election.resultat = { elu: premier.nom, pct, tour: 1 };
    addExternalEvent('ELECTION : ' + premier.nom + ' elu(e) au 1er tour avec ' + pct + '% des voix (' + election.nom + ')');
    addMailNotification('Commission Electorale', 'Resultats election : ' + election.nom, premier.nom + ' est elu(e) avec ' + pct + '% des voix. Mandat de 5 semaines.');
  } else {
    // Second tour entre les 2 premiers
    const deuxieme = sorted[1];
    election.tour = 2;
    election.phase = 'campagne';
    election.candidats = [sorted[0], sorted[1]].map(c => ({...c, voix: 0}));
    election.jourResultat = election.jourResultat + 7;
    addExternalEvent('ELECTION : Aucun candidat n\'a la majorite. Second tour entre ' + premier.nom + ' et ' + deuxieme.nom);
    addMailNotification('Commission Electorale', '2eme tour — ' + election.nom, 'Aucun candidat n\'a obtenu la majorite absolue. Second tour entre ' + premier.nom + ' et ' + deuxieme.nom + '.');
  }
}

// =====================
// BOITE MAIL
// =====================
function openMailbox() {
  // Afficher la boite mail a la place de l'image centrale
  document.querySelectorAll('.vue').forEach(v => v.classList.remove('active'));
  document.getElementById('vue-mail').classList.add('active');
  switchMailTab('inbox', document.querySelector('#vue-mail .piece-tab'));
}

// =====================
// FORUM EN VUE CENTRALE
// =====================
function openForumView(forumId) {
  document.querySelectorAll('.vue').forEach(v => v.classList.remove('active'));
  document.getElementById('vue-forum').classList.add('active');
  const labels = {
    local:'Forum Local', regional:'Forum Regional', national:'Forum National',
    international:'Forum International', gouv:'Forum Gouvernemental',
    syndical:'Forum Syndical', president:'Forum Presidentiel', conseil:'Conseil des Ministres'
  };
  document.getElementById('forum-view-subtitle').textContent = labels[forumId] || 'Forum';
  // Injecter le contenu forum dans la vue centrale
  const body = document.getElementById('forum-view-body');
  body.innerHTML = '';
  // Creer un conteneur et appeler le module forum
  const container = document.createElement('div');
  container.style.cssText = 'width:100%;height:100%;overflow:hidden';
  body.appendChild(container);
  if (typeof renderForumInContainer === 'function') {
    renderForumInContainer(container, forumId);
  } else {
    // Fallback : rendu direct
    container.innerHTML = buildForumHTML(forumId);
  }
}

function closeForumView() {
  document.getElementById('vue-forum').classList.remove('active');
  if (state.currentBuilding) {
    document.getElementById('vue-batiment').classList.add('active');
  } else {
    document.getElementById('vue-rue').classList.add('active');
  }
}

function buildForumHTML(forumId) {
  const topics = FORUM_TOPICS[forumId] || [];
  const labels = {
    local:'Forum Local', regional:'Forum Regional', national:'Forum National',
    international:'Forum International', gouv:'Forum Gouvernemental',
    syndical:'Forum Syndical', president:'Forum Presidentiel', conseil:'Conseil des Ministres'
  };

  let html = '<div style="display:flex;height:100%">';

  // Sidebar forums
  html += '<div style="width:160px;background:#111208;border-right:1px solid #1a1a10;overflow-y:auto;flex-shrink:0">';
  const forums = [
    {id:'local',label:'Local'},{id:'regional',label:'Regional'},{id:'national',label:'National'},
    {id:'international',label:'International'},{id:'president',label:'Presidentiel'},
    {id:'conseil',label:'Conseil Min.'},{id:'gouv',label:'Gouvernemental'},{id:'syndical',label:'Syndical'}
  ];
  forums.forEach(f => {
    const active = f.id === forumId;
    html += '<div onclick="openForumView(\'' + f.id + '\')" style="padding:.5rem .7rem;cursor:pointer;' +
      (active ? 'background:#1a1a10;border-left:2px solid #C9A84C;' : 'border-left:2px solid transparent;') +
      'border-bottom:1px solid #1a1a10">' +
      '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;color:' +
      (active ? '#E8C97A' : '#8a8060') + '">' + f.label + '</div>' +
      '<div style="font-size:.6rem;color:#4a4030">' + (FORUM_TOPICS[f.id]?.length || 0) + ' sujets</div>' +
      '</div>';
  });
  html += '</div>';

  // Contenu principal
  html += '<div style="flex:1;display:flex;flex-direction:column;overflow:hidden">';

  // Header
  html += '<div style="padding:.6rem 1rem;background:#111208;border-bottom:1px solid #2a2810;display:flex;justify-content:space-between;align-items:center">';
  html += '<div style="font-family:Playfair Display,serif;font-size:.9rem;color:#E8D880">' + (labels[forumId]||'Forum') + '</div>';
  html += '<button onclick="ouvrirNouveauSujet(\'' + forumId + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.1em;padding:.3rem .7rem;border:1px solid #6a5a20;background:transparent;color:#C9A84C;cursor:pointer">+ Nouveau sujet</button>';
  html += '</div>';

  // Liste des sujets
  html += '<div style="flex:1;overflow-y:auto">';
  if (topics.length === 0) {
    html += '<div style="padding:2rem;text-align:center;font-size:.82rem;color:#4a4030;font-style:italic">Aucun sujet pour le moment.</div>';
  } else {
    // En-tete
    html += '<div style="display:grid;grid-template-columns:1fr 80px 60px 80px;padding:.3rem .8rem;background:#0a0a05;border-bottom:1px solid #1a1808">';
    ['Sujet','Auteur','Reponses','Date'].forEach(h => {
      html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.62rem;letter-spacing:.1em;color:#4a4030">' + h + '</div>';
    });
    html += '</div>';
    topics.forEach((t, i) => {
      const isRef = t.isReferendum;
      html += '<div onclick="ouvrirSujetForum(\'' + forumId + '\',' + i + ')" style="display:grid;grid-template-columns:1fr 80px 60px 80px;padding:.5rem .8rem;background:#151208;border-bottom:1px solid #1e1a08;cursor:pointer;transition:background .15s" onmouseover="this.style.background=\'#1e1a08\'" onmouseout="this.style.background=\'#151208\'">';
      html += '<div><div style="font-size:.85rem;color:' + (isRef ? '#8ad080' : '#E0D090') + ';margin-bottom:.1rem">' +
        (isRef ? '<i class="ti ti-checkbox" style="font-size:.75rem"></i> ' : '') + t.title + '</div>' +
        '<div style="font-size:.68rem;color:#6a6040">' + (t.author||'Anonyme') + '</div></div>';
      html += '<div style="font-size:.75rem;color:#9a9060;align-self:center">' + (t.author||'') + '</div>';
      html += '<div style="font-size:.75rem;color:#6a6040;align-self:center;text-align:center">' + (t.replies||t.posts?.length||0) + '</div>';
      html += '<div style="font-size:.72rem;color:#5a5030;align-self:center">' + (t.time||'') + '</div>';
      html += '</div>';
    });
  }
  html += '</div></div></div>';
  return html;
}

function ouvrirSujetForum(forumId, topicIdx) {
  const topic = (FORUM_TOPICS[forumId]||[])[topicIdx];
  if (!topic) return;
  const body = document.getElementById('forum-view-body');
  let html = '<div style="display:flex;flex-direction:column;width:100%;height:100%">';
  html += '<div style="padding:.5rem 1rem;background:#111208;border-bottom:1px solid #1a1810;display:flex;align-items:center;gap:.8rem">';
  html += '<button onclick="openForumView(\'' + forumId + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;padding:.2rem .5rem;border:1px solid #2a2010;background:transparent;color:#8a7040;cursor:pointer">← Retour</button>';
  html += '<div style="font-family:Playfair Display,serif;font-size:.88rem;color:#E8D880">' + topic.title + '</div>';
  html += '</div>';
  html += '<div style="flex:1;overflow-y:auto;padding:.8rem 1rem">';

  // Referendum special
  if (topic.isReferendum && topic.reponses) {
    const dejaVote = state.refVotes?.[topic.id];
    html += '<div style="background:#0f0d05;border:1px solid #2a3a20;padding:.8rem;margin-bottom:.8rem">';
    html += '<div style="font-family:Playfair Display,serif;font-size:.82rem;color:#8ad080;margin-bottom:.6rem">REFERENDUM : ' + topic.title.replace('[REFERENDUM] ','') + '</div>';
    topic.reponses.forEach((r, ri) => {
      const total = topic.reponses.reduce((s, x) => s + (x.voix||0), 0) || 1;
      const pct = Math.round((r.voix||0) / total * 100);
      html += '<div style="margin-bottom:.4rem">';
      if (!dejaVote) {
        html += '<button onclick="voterReferendum(\'' + forumId + '\',' + topicIdx + ',' + ri + ')" style="width:100%;text-align:left;padding:.4rem .7rem;border:1px solid #2a3a20;background:#0a0a05;color:#c0c080;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem">' + r.label + '</button>';
      } else {
        html += '<div style="padding:.4rem .7rem;border:1px solid #1a2810;background:#0a0a05;font-family:Crimson Pro,serif;font-size:.82rem;color:' + (dejaVote === ri ? '#8ad080' : '#5a5030') + '">';
        html += r.label + ' <span style="float:right;font-family:Bebas Neue,sans-serif">' + pct + '%</span></div>';
        html += '<div style="height:4px;background:#0a0a05;margin-top:.1rem"><div style="height:100%;width:' + pct + '%;background:#4a8a4a"></div></div>';
      }
      html += '</div>';
    });
    if (dejaVote !== undefined) html += '<div style="font-size:.7rem;color:#4a6a3a;margin-top:.3rem">Vote enregistre.</div>';
    html += '</div>';
  }

  // Posts
  (topic.posts||[]).forEach(p => {
    html += '<div style="background:#181408;border:1px solid #2a2408;padding:.7rem;margin-bottom:.5rem">';
    html += '<div style="display:flex;justify-content:space-between;margin-bottom:.4rem">';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.75rem;color:#E8C97A">' + (p.author||'Anonyme') + '</div>';
    html += '<div style="font-size:.65rem;color:#4a4030">' + (p.time||'') + '</div>';
    html += '</div>';
    html += '<div style="font-size:.88rem;color:#c8c090;line-height:1.7">' + (p.content||'') + '</div>';
    html += '</div>';
  });

  // Zone de reponse
  html += '<div style="margin-top:.8rem;border-top:1px solid #1a1810;padding-top:.8rem">';
  html += '<textarea id="forum-reply-text" rows="3" placeholder="Votre reponse..." style="width:100%;background:#121005;border:1px solid #2a2010;color:#d0c890;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;resize:none;margin-bottom:.4rem"></textarea>';
  html += '<button onclick="publierReponse(\'' + forumId + '\',' + topicIdx + ')" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.1em;padding:.4rem .9rem;border:1px solid #6a5a20;background:transparent;color:#C9A84C;cursor:pointer">Repondre</button>';
  html += '</div></div></div>';
  body.innerHTML = html;
}

function voterReferendum(forumId, topicIdx, reponseIdx) {
  const topic = (FORUM_TOPICS[forumId]||[])[topicIdx];
  if (!topic || !topic.reponses) return;
  if (!state.refVotes) state.refVotes = {};
  state.refVotes[topic.id] = reponseIdx;
  topic.reponses[reponseIdx].voix = (topic.reponses[reponseIdx].voix||0) + 1;
  ouvrirSujetForum(forumId, topicIdx);
  showToast('Vote enregistre', 'Vous avez vote pour : ' + topic.reponses[reponseIdx].label, true);
}

function publierReponse(forumId, topicIdx) {
  const texte = document.getElementById('forum-reply-text')?.value?.trim();
  if (!texte) return;
  const topic = (FORUM_TOPICS[forumId]||[])[topicIdx];
  if (!topic) return;
  if (!topic.posts) topic.posts = [];
  topic.posts.push({ author: state.char?.name||'Anonyme', time: 'Jour ' + state.day, content: texte });
  topic.replies = (topic.replies||0) + 1;
  ouvrirSujetForum(forumId, topicIdx);
  showToast('Reponse publiee', '', true);
}

function ouvrirNouveauSujet(forumId) {
  const body = document.getElementById('forum-view-body');
  let html = '<div style="display:flex;flex-direction:column;width:100%;height:100%">';
  html += '<div style="padding:.5rem 1rem;background:#111208;border-bottom:1px solid #1a1810;display:flex;align-items:center;gap:.8rem">';
  html += '<button onclick="openForumView(\'' + forumId + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;padding:.2rem .5rem;border:1px solid #2a2010;background:transparent;color:#8a7040;cursor:pointer">← Annuler</button>';
  html += '<div style="font-family:Playfair Display,serif;font-size:.88rem;color:#E8D880">Nouveau sujet</div>';
  html += '</div>';
  html += '<div style="flex:1;overflow-y:auto;padding:1rem">';
  html += '<input id="new-topic-title" type="text" placeholder="Titre du sujet..." style="width:100%;background:#121005;border:1px solid #2a2010;color:#d0c890;padding:.6rem;font-family:Crimson Pro,serif;font-size:.88rem;outline:none;margin-bottom:.6rem"/>';
  html += '<textarea id="new-topic-content" rows="6" placeholder="Contenu du message..." style="width:100%;background:#121005;border:1px solid #2a2010;color:#d0c890;padding:.6rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;resize:none;margin-bottom:.6rem"></textarea>';
  html += '<button onclick="publierNouveauSujet(\'' + forumId + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Publier</button>';
  html += '</div></div>';
  body.innerHTML = html;
}

function publierNouveauSujet(forumId) {
  const titre = document.getElementById('new-topic-title')?.value?.trim();
  const contenu = document.getElementById('new-topic-content')?.value?.trim();
  if (!titre || !contenu) { showToast('Champs requis', 'Titre et contenu obligatoires.', false); return; }
  if (!FORUM_TOPICS[forumId]) FORUM_TOPICS[forumId] = [];
  const newTopic = {
    id: 'topic-' + Date.now(),
    title: titre,
    author: state.char?.name||'Anonyme',
    time: 'Jour ' + state.day,
    replies: 0,
    posts: [{ author: state.char?.name||'Anonyme', time: 'Jour ' + state.day, content: contenu }]
  };
  FORUM_TOPICS[forumId].unshift(newTopic);
  showToast('Sujet publie !', titre, true, true);
  openForumView(forumId);
}

function closeMailView() {
  document.getElementById('vue-mail').classList.remove('active');
  // Retourner a la vue precedente
  if (state.currentBuilding) {
    document.getElementById('vue-batiment').classList.add('active');
  } else {
    document.getElementById('vue-rue').classList.add('active');
  }
}

function switchMailTab(tab, el) {
  if (el) {
    document.querySelectorAll('#vue-mail .piece-tab').forEach(function(t) { t.classList.remove('active'); });
    el.classList.add('active');
  }
  var mails = state.mails || [];
  var contacts = state.contacts || [];
  var sent = state.sentMails || [];
  var content = document.getElementById('mail-content');
  var compose = document.getElementById('mail-compose');
  var subtitle = document.getElementById('mail-view-subtitle');

  if (tab === 'inbox') {
    compose.style.display = 'none';
    var unread = mails.filter(function(m) { return !m.read; }).length;
    if (subtitle) subtitle.textContent = 'Messages recus' + (unread > 0 ? ' (' + unread + ' non lu' + (unread > 1 ? 's' : '') + ')' : '');
    var html = "";
    html += '<div style="text-align:right;padding:.5rem 1rem;border-bottom:1px solid #1a1810"><button onclick="openMailCompose()" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;padding:.3rem .7rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">+ Nouveau message</button></div>';
    if (mails.length === 0) {
      html += '<div style="padding:2rem;font-size:.85rem;color:#4a4030;font-style:italic;text-align:center">Aucun message recu.</div>';
    } else {
      var reversed = mails.slice().reverse();
      reversed.forEach(function(m, i) {
        var idx = mails.length - 1 - i;
        var bg = m.read ? 'transparent' : '#0f0a05';
        var nameColor = m.read ? '#8a8060' : '#E8C97A';
        var fw = m.read ? 'normal' : '700';
        var textColor = m.read ? '#5a5040' : '#c0b090';
        html += '<div onclick="readMailInView(' + idx + ')" style="padding:.7rem 1rem;border-bottom:1px solid #1a1810;cursor:pointer;background:' + bg + '">';
        html += '<div style="display:flex;justify-content:space-between;margin-bottom:.2rem">';
        html += '<span style="font-family:Playfair Display,serif;font-size:.82rem;color:' + nameColor + ';font-weight:' + fw + '">' + (m.from || '') + '</span>';
        html += '<span style="font-size:.65rem;color:#4a4030">Jour ' + (m.day || '') + '</span></div>';
        html += '<div style="font-size:.78rem;color:' + textColor + '">' + (m.subject || '') + '</div>';
        if (!m.read) html += '<span style="display:inline-block;width:6px;height:6px;background:#C9A84C;border-radius:50%;margin-top:.2rem"></span>';
        html += '</div>';
      });
    }
    content.innerHTML = html;
  } else if (tab === 'sent') {
    compose.style.display = 'none';
    if (subtitle) subtitle.textContent = 'Messages envoyes';
    if (sent.length === 0) {
      content.innerHTML = '<div style="padding:2rem;font-size:.85rem;color:#4a4030;font-style:italic;text-align:center">Aucun message envoye.</div>';
    } else {
      var h = '';
      sent.slice().reverse().forEach(function(m) {
        h += '<div style="padding:.7rem 1rem;border-bottom:1px solid #1a1810">';
        h += '<div style="display:flex;justify-content:space-between;margin-bottom:.2rem">';
        h += '<span style="font-family:Playfair Display,serif;font-size:.82rem;color:#8a8060">A : ' + (m.to || '') + '</span>';
        h += '<span style="font-size:.65rem;color:#4a4030">Jour ' + (m.day || '') + '</span></div>';
        h += '<div style="font-size:.78rem;color:#5a5040">' + (m.subject || '') + '</div></div>';
      });
      content.innerHTML = h;
    }
  } else if (tab === 'contacts') {
    compose.style.display = 'none';
    if (subtitle) subtitle.textContent = 'Repertoire';
    if (contacts.length === 0) {
      content.innerHTML = '<div style="padding:2rem;font-size:.85rem;color:#4a4030;font-style:italic;text-align:center">Repertoire vide. Rencontrez des personnages pour les ajouter.</div>';
    } else {
      var h = '<div style="padding:.5rem 0">';
      contacts.forEach(function(c) {
        h += '<div style="display:flex;justify-content:space-between;align-items:center;padding:.6rem 1rem;border-bottom:1px solid #1a1810">';
        h += '<div><div style="font-family:Playfair Display,serif;font-size:.82rem;color:#c0b090">' + (c.name || '') + '</div>';
        h += '<div style="font-size:.68rem;color:#5a5040">' + (c.role || '') + '</div></div>';
        h += '<button onclick="prefillMailTo(' + JSON.stringify(c.name) + ')" style="font-family:Bebas Neue,sans-serif;font-size:.65rem;letter-spacing:.08em;padding:.2rem .5rem;border:1px solid #3a2a10;background:transparent;color:#8a7040;cursor:pointer">Ecrire</button>';
        h += '</div>';
      });
      h += '</div>';
      content.innerHTML = h;
    }
  } else if (tab === 'compose') {
    compose.style.display = 'block';
    if (subtitle) subtitle.textContent = 'Nouveau message';
    content.innerHTML = '';
  }
}

function openMailCompose() {
  switchMailTab('compose', null);
}


function goBackToInbox() { switchMailTab("inbox", null); }

function readMailInView(index) {
  var mails = state.mails || [];
  var mail = mails[index];
  if (!mail) return;
  mail.read = true;
  updateUI();
  var el = document.getElementById('mail-content');
  var compose = document.getElementById('mail-compose');
  if (compose) compose.style.display = 'none';
  var h = '<div style="padding:1rem">';
  h += '<button onclick="goBackToInbox()" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;padding:.3rem .6rem;border:1px solid #3a2a10;background:transparent;color:#8a8060;cursor:pointer;margin-bottom:1rem">Retour</button>';
  h += '<div style="font-size:.7rem;color:#6a5a20;margin-bottom:.2rem">DE : ' + (mail.from||'') + '</div>';
  h += '<div style="font-size:.7rem;color:#6a5a20;margin-bottom:.6rem">OBJET : ' + (mail.subject||'') + '</div>';
  h += '<div style="font-size:.85rem;color:#a0a080;line-height:1.7;padding:.8rem;background:#0f0d05;border:1px solid #2a2010">' + (mail.body||'') + '</div>';
  h += '</div>';
  el.innerHTML = h;
}

function prefillMailTo(name) {
  switchMailTab('compose', null);
  setTimeout(() => {
    const to = document.getElementById('mail-to');
    if (to) to.value = name;
  }, 50);
}

function sendMail() {
  const to = document.getElementById('mail-to')?.value?.trim();
  const subject = document.getElementById('mail-subject')?.value?.trim();
  const body = document.getElementById('mail-body')?.value?.trim();
  if (!to || !subject || !body) { showToast('Champs requis', 'Remplissez tous les champs.', false); return; }
  if (!state.sentMails) state.sentMails = [];
  state.sentMails.push({ to, subject, body, day: state.day });
  document.getElementById('mail-to').value = '';
  document.getElementById('mail-subject').value = '';
  document.getElementById('mail-body').value = '';
  showToast('Message envoye', 'Votre message a ete envoye a ' + to, true);
  addJournalEntry('Vous avez envoye un mail a ' + to + ' : ' + subject, 'event-info');
  switchMailTab('sent', null);
}

function readMail(index) { readMailInView(index); }

function addExternalEvent(text) {
  const j = document.getElementById('journal');
  const h = String(state.hour).padStart(2,'0');
  const m = String(state.minute||0).padStart(2,'0');
  const div = document.createElement('div');
  div.className = 'journal-entry journal-external';
  div.innerHTML = `
    <span class="journal-time">Jour ${state.day} · ${h}h${m}</span>
    <span class="journal-alert" onclick="this.style.display='none'" title="Cliquer pour marquer comme lu">●</span>
    <span class="journal-text event-external"><strong>${text}</strong></span>
  `;
  j.insertBefore(div, j.firstChild);
}

// Archives police — liste des prisonniers
function doArchivesPolice() {
  const prisonniers = state.prisonniers || [];
  const derniers30j = prisonniers.filter(p => {
    const dayNum = parseInt(p.depuis.replace('Jour ','')) || 0;
    return state.day - dayNum <= 30;
  });

  let msg = '';
  if (derniers30j.length === 0) {
    msg = 'Archives consultees : aucune personne emprisonnee au cours des 30 derniers jours.';
  } else {
    msg = `Archives consultees : ${derniers30j.length} personne(s) emprisonnee(s) ces 30 derniers jours : ${derniers30j.map(p => p.nom + ' (' + p.depuis + ')').join(', ')}.`;
  }
  showToast('Archives consultees', msg.substring(0, 80) + '...', true);
  addJournalEntry(msg, 'event-info');
}

// Notification mail simple
function addMailNotification(from, subject, body) {
  if (!state.mails) state.mails = [];
  state.mails.push({ from, subject, body, day: state.day, read: false });
  addExternalEvent(`Nouveau mail de ${from} : "${subject}"`);
}

function showPostRequired() {
  showToast('Poste requis', 'Vous devez occuper un poste institutionnel pour acceder a cet ordre.', false);
}

// =====================
// FINANCES MODAL
// =====================
function openFinancesModal() {
  const cur = COUNTRIES[state.char?.country || 'republic']?.cur || 'FR';

  document.getElementById('finances-body').innerHTML = `
    <div class="finance-row">
      <div class="finance-label">Argent total</div>
      <div class="finance-amount">${state.arg.toLocaleString('fr-FR')} ${cur}</div>
    </div>
    <div class="finance-row">
      <div class="finance-label">Argent liquide (sur vous)</div>
      <div class="finance-amount">${state.liquide.toLocaleString('fr-FR')} ${cur}</div>
    </div>
    <div class="finance-row">
      <div class="finance-label">En banque</div>
      <div class="finance-amount">${state.banque.toLocaleString('fr-FR')} ${cur}</div>
    </div>
    <div style="padding:.8rem 1rem;border-bottom:1px solid #1a1810">
      <div style="font-size:.75rem;color:#6a5a30;margin-bottom:.5rem;font-family:'Bebas Neue',sans-serif;letter-spacing:.1em">DEPOT / RETRAIT</div>
      <div style="display:flex;gap:.5rem;align-items:center;margin-bottom:.5rem">
        <input class="finance-input" id="finance-amount-input" type="number" placeholder="Montant" min="1" max="${state.banque}"/>
        <button class="finance-btn" onclick="deposerArgent()">Deposer</button>
        <button class="finance-btn danger" onclick="retirerArgent()">Retirer</button>
      </div>
      <div style="font-size:.72rem;color:#5a5040;font-style:italic">Le depot et le retrait sont 100% securises et sans risque.</div>
    </div>
    ${state.poste ? `
    <div style="padding:.8rem 1rem">
      <div style="font-size:.75rem;color:#6a5a30;margin-bottom:.3rem;font-family:'Bebas Neue',sans-serif;letter-spacing:.1em">MON POSTE</div>
      <div style="font-size:.85rem;color:#c0b090">${state.poste.name}</div>
    </div>` : ''}
  `;

  document.getElementById('modal-finances').classList.add('open');
}

function deposerArgent() {
  const amount = parseInt(document.getElementById('finance-amount-input').value);
  if (!amount || amount <= 0 || amount > state.liquide) {
    showToast('Erreur', 'Montant invalide ou insuffisant en liquide.', false);
    return;
  }
  state.liquide -= amount;
  state.banque += amount;
  document.getElementById('modal-finances').classList.remove('open');
  showToast('Depot effectue', `${amount.toLocaleString('fr-FR')} deposes en banque.`, true);
  addJournalEntry(`Depot bancaire : ${amount.toLocaleString('fr-FR')}.`, '');
}

function retirerArgent() {
  const amount = parseInt(document.getElementById('finance-amount-input').value);
  if (!amount || amount <= 0 || amount > state.banque) {
    showToast('Erreur', 'Montant invalide ou solde bancaire insuffisant.', false);
    return;
  }
  state.banque -= amount;
  state.liquide += amount;
  document.getElementById('modal-finances').classList.remove('open');
  showToast('Retrait effectue', `${amount.toLocaleString('fr-FR')} retires de la banque.`, true);
  addJournalEntry(`Retrait bancaire : ${amount.toLocaleString('fr-FR')}.`, '');
}

// =====================
// CHAR SHEET
// =====================
function openCharSheet() {
  const char = state.char;
  if (!char) return;
  const co = COUNTRIES[char.country];
  const ar = ARCHETYPES.find(x => x.id === char.archetype);
  const ca = CAREERS.find(x => x.id === char.career);
  const or = ORIGINS.find(x => x.id === char.origin);
  const sc = SCHOOLS.find(x => x.id === char.school);

  const photo = char.photoUrl
    ? `<img src="${char.photoUrl}" style="width:70px;height:70px;border-radius:50%;border:2px solid #8a6a20;object-fit:cover">`
    : `<div style="width:70px;height:70px;border-radius:50%;background:#1a1508;border:2px solid #3a2a10;display:flex;align-items:center;justify-content:center;color:#C9A84C"><i class="ti ti-user" style="font-size:1.8rem"></i></div>`;

  document.getElementById('char-sheet-body').innerHTML = `
    <div style="padding:1rem;display:flex;align-items:center;gap:1rem;border-bottom:1px solid #1a1810">
      ${photo}
      <div>
        <div style="font-family:'Playfair Display',serif;font-size:1.2rem;font-weight:700;color:#E8C97A">${char.name}</div>
        <div style="font-size:.8rem;color:#7a7060;font-style:italic">${ar?.name||''} · ${co?.n||''}</div>
        ${state.poste ? `<div style="font-size:.75rem;color:#C9A84C;margin-top:.2rem"><i class="ti ti-briefcase" style="font-size:.7rem"></i> ${state.poste.name}</div>` : ''}
        ${char.motto ? `<div style="font-size:.75rem;color:#5a5040;margin-top:.3rem;font-style:italic">"${char.motto}"</div>` : ''}
      </div>
    </div>
    <div class="char-sheet-grid">
      <div class="cs-section">
        <div class="cs-title">Caracteristiques</div>
        ${STAT_DEFS.map(({k,n,i}) => `
          <div class="cs-stat-row">
            <span class="cs-stat-name"><i class="ti ${i}" style="font-size:.75rem;vertical-align:-1px"></i> ${n}</span>
            <span class="cs-stat-val">${char.stats?.[k]||8}</span>
          </div>`).join('')}
      </div>
      <div class="cs-section">
        <div class="cs-title">Ressources</div>
        <div class="cs-stat-row"><span class="cs-stat-name">Argent total</span><span class="cs-stat-val">${state.arg.toLocaleString('fr-FR')} ${co?.cur||'FR'}</span></div>
        <div class="cs-stat-row"><span class="cs-stat-name">Liquide</span><span class="cs-stat-val">${state.liquide.toLocaleString('fr-FR')}</span></div>
        <div class="cs-stat-row"><span class="cs-stat-name">En banque</span><span class="cs-stat-val">${state.banque.toLocaleString('fr-FR')}</span></div>
        <div class="cs-stat-row"><span class="cs-stat-name">Influence</span><span class="cs-stat-val">${state.inf}/100</span></div>
        <div class="cs-stat-row"><span class="cs-stat-name">Popularite</span><span class="cs-stat-val">${state.pop}/100</span></div>
        <div class="cs-stat-row"><span class="cs-stat-name">Discretion</span><span class="cs-stat-val">${state.dis}/100</span></div>
        <div class="cs-stat-row"><span class="cs-stat-name">Sante</span><span class="cs-stat-val">${state.hp}/100</span></div>
        <div class="cs-stat-row"><span class="cs-stat-name">Moral</span><span class="cs-stat-val">${state.moral}/100</span></div>
      </div>
    </div>
    <div style="padding:.8rem 1rem;border-top:1px solid #1a1810">
      <div class="cs-title" style="margin-bottom:.4rem">Parcours</div>
      <div style="display:flex;flex-wrap:wrap;gap:.4rem;margin-bottom:.6rem">
        ${[or,sc,ar,ca].filter(Boolean).map(x => `
          <div style="font-size:.72rem;padding:.2rem .6rem;border:1px solid #2a2010;color:#8a8060;background:#0f0d05;display:flex;align-items:center;gap:.3rem">
            <i class="ti ${x.icon}" style="font-size:.75rem"></i> ${x.name}
          </div>`).join('')}
      </div>
      ${char.bio ? `<div style="font-size:.82rem;color:#8a8060;font-style:italic;line-height:1.6">${char.bio}</div>` : ''}
    </div>
    <div style="padding:.8rem 1rem;border-top:1px solid #1a1810">
      <div class="cs-title" style="margin-bottom:.4rem">Inventaire</div>
      ${state.inventory.length === 0
        ? '<div style="font-size:.75rem;color:#3a3020;font-style:italic">Aucun objet</div>'
        : state.inventory.map(item => `
            <div style="display:flex;align-items:center;gap:.4rem;font-size:.78rem;color:#c0b090;padding:.2rem 0">
              <i class="ti ${item.icon}" style="font-size:.8rem;color:#8a6a20"></i> ${item.name}
            </div>`).join('')}
    </div>
  `;

  document.getElementById('modal-char').classList.add('open');
}
function closeCharSheet() {
  document.getElementById('modal-char').classList.remove('open');
}

// =====================
// WORLD MAP
// =====================
function openWorldMap() {
  const body = document.getElementById('world-map-body');
  body.innerHTML = renderWorldMapSVG();
  body.style.display = 'flex';
  body.style.flexDirection = 'column';
  body.style.height = '520px';
  document.getElementById('modal-world').classList.add('open');
}
function closeWorldMap() {
  document.getElementById('modal-world').classList.remove('open');
}

// =====================
// REGLES DU JEU
// =====================
const REGLES = {
  intro: {
    titre: 'Le Grand Jeu',
    contenu: `Res Publica est un jeu de rôle politique parodique multijoueur. Vous incarnez un personnage qui cherche à conquérir le pouvoir dans l'un des quatre empires fictifs : Républia, El Estado, Sovarka ou Al-Khalija.

Le jeu se déroule en temps réel, calé sur l'heure française. Chaque nuit à minuit, une mise à jour traite les événements en cours : résultats d'élections, enquêtes policières, revenus fiscaux.

L'objectif : gravir les échelons politiques, accumuler de l'influence et de la popularité, et survivre aux trahisons de vos adversaires.`
  },
  personnage: {
    titre: 'Créer son personnage',
    contenu: `Votre personnage est défini par 4 choix fondamentaux :

ORIGINE SOCIALE — Détermine votre capital de départ et vos bonus de stats.
• Milieu défavorisé : 200 FR, +VOL +DUP
• Classe ouvrière : 500 FR, +VOL +ENT
• Petite bourgeoisie : 1200 FR, +INT +CHA
• Haute société : 3000 FR, +ENT +CHA

PARCOURS SCOLAIRE — Détermine les carrières accessibles et vos points de compétence.
• Pas d'école : bloque plusieurs carrières
• Études supérieures et Hautes écoles : toutes les carrières accessibles

ARCHÉTYPE — Votre nature profonde. Définit vos bonus de ressources et votre style de jeu.

CARRIÈRE — Votre activité principale. Donne des contacts, des compétences et un salaire journalier.`
  },
  plateau: {
    titre: 'Le plateau de jeu',
    contenu: `POINTS D'ACTION (PA) — Vous disposez de 24 PA par jour. Chaque ordre en consomme selon sa complexité. Certains ordres sont gratuits. En mode test, les PA sont illimités.

RESSOURCES :
• Influence (INF) — Votre poids politique
• Popularité (POP) — Votre cote auprès du public
• Discrétion (DIS) — Votre capacité à agir sans être détecté
• Santé — Votre état physique (0 = hospitalisation)
• Moral — Votre résistance psychologique

ORDRES — Chaque action est résolue par un jet de dés (1-100). Le taux de réussite dépend de vos caractéristiques. Les résultats possibles : succès critique, succès, succès partiel, échec, échec critique.

SALAIRE — Vous ne touchez votre salaire journalier qu'en passant l'ordre "Dormir" (une seule fois par jour).`
  },
  politique: {
    titre: 'La vie politique',
    contenu: `POSTES ET MANDATS :
Les postes sont organisés en pyramide à 7 niveaux. En haut : le Président, le Premier Ministre, les Ministres. En bas : les élus locaux et les citoyens.

ÉLECTIONS :
• Mandat de 5-6 semaines
• Résultats à minuit le dimanche
• Candidatures possibles dès la 3e semaine après les dernières élections
• Campagne électorale : 4e semaine — vote des PJ + distribution de tracts aux PNJ
• 1er tour : >50% = élu direct, sinon 2e tour entre les 2 premiers
• Pour les mairies/gouvernorats : 2e tour entre ceux ayant obtenu >20%
• Députés : scrutin uninominal par circonscription, 1 tour, majorité relative

NOMMER UN MINISTRE :
Seul le Président peut nommer des ministres. La nomination se fait via un mail envoyé au candidat depuis le Bureau du Palais Présidentiel.`
  },
  interactions: {
    titre: 'Les interactions',
    contenu: `PARLER AUX PNJ/PJ — Cliquez sur un personnage présent dans une pièce pour ouvrir le dialogue. Posez n'importe quelle question dans le champ libre. Les réponses sont générées par l'IA.

GROUPES — Un PJ peut rejoindre un autre PJ en cliquant sur sa fiche. Le PJ rejoint devient le leader. Seul le leader peut déplacer le groupe. La taille du groupe influence certains ordres (blocus, etc.).

BOÎTE MAIL — Accessible depuis le bouton "Mail" en haut. Contient vos messages reçus, envoyés et votre répertoire de contacts.

AJOUTER UN CONTACT — Cliquez sur un PJ puis "Ajouter au répertoire". Indispensable pour porter plainte, lancer une rumeur ciblée, ou envoyer un mail.

LE FORUM — Accessible depuis le bouton "Forum" en haut. C'est l'espace de communication publique et privée du jeu. Il comporte plusieurs forums :
• Forum Local — Discussions de votre ville
• Forum Régional — Discussions régionales
• Forum National — Débats politiques nationaux
• Forum International — Relations entre empires
• Forum Gouvernemental — Réservé au gouvernement (Président + ministres)
• Forum Syndical — Réservé aux syndicalistes
Pour créer un sujet : bouton "Nouveau sujet". Pour répondre : bouton "Répondre" dans le sujet. L'éditeur permet la mise en forme (gras, souligné, centrage) et l'insertion d'images. Les sujets créés sont visibles de tous les membres du forum concerné.`
  },
  economie: {
    titre: "L'économie",
    contenu: `ARGENT — Séparé entre argent liquide (sur vous) et argent en banque. Le salaire est versé 30% en liquide, 70% en banque.

SALAIRES JOURNALIERS (versés via l'ordre Dormir) :
• Président : 5 000 FR/jour
• Premier Ministre : 3 500 FR/jour
• Ministres : 2 800 FR/jour
• Députés : 1 200 FR/jour
• Maires : 800 FR/jour
• Citoyen sans poste : 150 FR/jour

REVENUS FISCAUX — La population PNJ génère des impôts chaque nuit à minuit. Visibles du Président et du Ministre des Finances.

FREEMIUM — Le jeu est gratuit. Les abonnements premium donnent du confort mais jamais d'avantage compétitif direct.`
  }
};

// =====================
// FICHE PERSONNAGE CENTRALE
// =====================
function openSelfView() {
  document.querySelectorAll('.vue').forEach(v => v.classList.remove('active'));
  document.getElementById('vue-self').classList.add('active');
  const char = state.char;
  if (char) {
    document.getElementById('self-view-name').textContent = char.name || 'Mon Personnage';
    document.getElementById('self-view-role').textContent = state.poste?.name || 'Citoyen';
  }
  switchSelfTab('actions', document.querySelector('#vue-self .piece-tab'));
}

function closeSelfView() {
  document.getElementById('vue-self').classList.remove('active');
  if (state.currentBuilding) {
    document.getElementById('vue-batiment').classList.add('active');
  } else {
    document.getElementById('vue-rue').classList.add('active');
  }
}

function switchSelfTab(tab, el) {
  if (el) {
    document.querySelectorAll('#vue-self .piece-tab').forEach(t => t.classList.remove('active'));
    el.classList.add('active');
  }
  const content = document.getElementById('self-content');
  const cur = COUNTRIES[state.char?.country || 'republic']?.cur || 'FR';

  if (tab === 'actions') {
    // Determiner le confort du lieu
    const b = state.currentBuilding ? BUILDINGS[state.currentBuilding] : null;
    const confortMap = {
      'hotel-republica': { label: 'Hotel de luxe', moral: 5, paBonus: 5, icon: 'ti-building-castle' },
      'hotel-port':      { label: 'Hotel modeste', moral: 3, paBonus: 2, icon: 'ti-bed' },
      'hotel-mineur':    { label: 'Hotel modeste', moral: 3, paBonus: 2, icon: 'ti-bed' },
      'palais-presidentiel': { label: 'Residence officielle', moral: 8, paBonus: 8, icon: 'ti-building-monument' }
    };
    const confort = confortMap[state.currentBuilding] || { label: 'Lieu ordinaire', moral: 1, paBonus: 0, icon: 'ti-home' };

    const dejaDormi = state.salaireTouche;
    const salaire = (state.poste ? (SALAIRES[state.poste.id] || SALAIRES.default) : SALAIRES.default);

    let html = '<div style="padding:1.2rem;max-width:600px">';

    // Ordre Dormir
    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:1rem;margin-bottom:.8rem">';
    html += '<div style="display:flex;align-items:center;gap:.6rem;margin-bottom:.5rem">';
    html += '<i class="ti ti-moon" style="font-size:1.2rem;color:#6a8aaa"></i>';
    html += '<div><div style="font-family:Playfair Display,serif;font-size:.95rem;color:#E8C97A">Dormir</div>';
    html += '<div style="font-size:.72rem;color:#6a5a30"><i class="ti ' + confort.icon + '" style="font-size:.7rem"></i> ' + confort.label + '</div></div>';
    html += '</div>';
    html += '<div style="font-size:.78rem;color:#8a8060;margin-bottom:.6rem;line-height:1.5">';
    html += (dejaDormi ? '<span style="color:#4a4030">Vous avez deja dormi aujourd\'hui.</span>' : 'Versement du salaire : <strong style="color:#C9A84C">+' + salaire.toLocaleString('fr-FR') + ' ' + cur + '</strong>') + '<br>';
    html += '+' + confort.moral + ' Moral · ';
    html += (confort.paBonus > 0 ? '+' + confort.paBonus + ' PA bonus demain' : 'Pas de bonus PA') + '</div>';
    html += '<button onclick="doDormir()" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.4rem 1rem;border:1px solid ' + (dejaDormi ? '#2a2010' : '#4a6a8a') + ';background:transparent;color:' + (dejaDormi ? '#4a4030' : '#6a8aaa') + ';cursor:' + (dejaDormi ? 'not-allowed' : 'pointer') + '"' + (dejaDormi ? ' disabled' : '') + '>Dormir maintenant</button>';
    html += '</div>';

    // Se soigner
    const medocs = (state.inventory || []).filter(i => i.type === 'medicament');
    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:1rem;margin-bottom:.8rem">';
    html += '<div style="display:flex;align-items:center;gap:.6rem;margin-bottom:.5rem">';
    html += '<i class="ti ti-first-aid-kit" style="font-size:1.2rem;color:#6a9a6a"></i>';
    html += '<div style="font-family:Playfair Display,serif;font-size:.95rem;color:#E8C97A">Se soigner</div></div>';
    html += '<div style="font-size:.78rem;color:#8a8060;margin-bottom:.6rem">' + (medocs.length > 0 ? medocs.length + ' medicament(s) en inventaire. +20 HP par utilisation.' : 'Aucun medicament en inventaire.') + '</div>';
    html += '<button onclick="doSesoigner()" ' + (medocs.length === 0 ? 'disabled style="opacity:.4;cursor:not-allowed"' : '') + ' style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.4rem 1rem;border:1px solid #2a4a20;background:transparent;color:#4a8a4a;cursor:pointer">Utiliser un medicament</button>';
    html += '</div>';

    // Mediter
    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:1rem">';
    html += '<div style="display:flex;align-items:center;gap:.6rem;margin-bottom:.5rem">';
    html += '<i class="ti ti-brain" style="font-size:1.2rem;color:#8a6aaa"></i>';
    html += '<div style="font-family:Playfair Display,serif;font-size:.95rem;color:#E8C97A">Mediter</div></div>';
    html += '<div style="font-size:.78rem;color:#8a8060;margin-bottom:.6rem">Se recentrer. +3 Moral. 1 PA.</div>';
    html += '<button onclick="doOrder(\'se_reposer\',1,0,\'Mediter\',\'Vous prenez le temps de vous recentrer.\',100);closeSelfView()" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.4rem 1rem;border:1px solid #3a2a5a;background:transparent;color:#8a6aaa;cursor:pointer">Mediter</button>';
    html += '</div>';

    // Ordres tactiques
    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:1rem;margin-bottom:.8rem">';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.15em;color:#8a6a20;margin-bottom:.6rem">ACTIONS TACTIQUES</div>';

    const malusISN = getMalusISN();
    const groupSize = getGroupSize ? getGroupSize() : 1;
    const tauxBlocus = Math.min(90, 25 + (groupSize - 1));

    html += '<div style="display:flex;flex-direction:column;gap:.4rem">';
    html += '<button onclick="doOrder(\'se_cacher\',1,0,\'Se cacher\',\'Vous vous dissimulez dans la piece.\',70);closeSelfView()" style="display:flex;justify-content:space-between;align-items:center;padding:.5rem .8rem;border:1px solid #2a3a20;background:#0a0d08;color:#8a9a6a;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem">';
    html += '<span><i class="ti ti-eye-off" style="font-size:.85rem"></i> Se cacher</span><span style="font-family:Bebas Neue,sans-serif;font-size:.68rem;color:#4a6a3a">70% · 1 PA</span></button>';

    html += '<button onclick="doOrder(\'organiser_blocus\',3,0,\'Organiser un blocus\',\'Le groupe bloque l\\\'acces.\','+tauxBlocus+');closeSelfView()" style="display:flex;justify-content:space-between;align-items:center;padding:.5rem .8rem;border:1px solid #3a1a1a;background:#0d0808;color:#9a6a4a;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem">';
    html += '<span><i class="ti ti-ban" style="font-size:.85rem"></i> Organiser un blocus</span><span style="font-family:Bebas Neue,sans-serif;font-size:.68rem;color:#6a3a20">' + tauxBlocus + '% · 1 PA · groupe:' + groupSize + '</span></button>';

    const tauxIncendie = Math.max(5, 30 - malusISN);
    html += '<button onclick="doOrder(\'incendier\',3,0,\'Incendier\',\'Vous mettez le feu.\','+tauxIncendie+');closeSelfView()" style="display:flex;justify-content:space-between;align-items:center;padding:.5rem .8rem;border:1px solid #4a1a08;background:#100805;color:#aa5a30;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem">';
    html += '<span><i class="ti ti-flame" style="font-size:.85rem"></i> Incendier</span><span style="font-family:Bebas Neue,sans-serif;font-size:.68rem;color:#8a3a10">' + tauxIncendie + '% · 3 PA · ISN:' + (INDICES_NATIONAUX[state.country]?.ISN||30) + '</span></button>';
    html += '</div></div>';

    html += '</div>';
    content.innerHTML = html;

  } else if (tab === 'inventaire') {
    const items = state.inventory || [];
    let html = '<div style="padding:1.2rem;max-width:600px">';

    // Argent
    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.8rem;margin-bottom:.6rem">';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.15em;color:#8a6a20;margin-bottom:.5rem">FINANCES</div>';
    html += '<div style="display:grid;grid-template-columns:1fr 1fr;gap:.4rem">';
    html += '<div style="padding:.5rem;background:#0a0805"><div style="font-size:.68rem;color:#4a4030">Liquide</div><div style="font-family:Bebas Neue,sans-serif;font-size:1.1rem;color:#C9A84C">' + (state.liquide||0).toLocaleString('fr-FR') + ' ' + cur + '</div></div>';
    html += '<div style="padding:.5rem;background:#0a0805"><div style="font-size:.68rem;color:#4a4030">En banque</div><div style="font-family:Bebas Neue,sans-serif;font-size:1.1rem;color:#C9A84C">' + (state.banque||0).toLocaleString('fr-FR') + ' ' + cur + '</div></div>';
    html += '</div></div>';

    // Objets
    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.8rem">';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.15em;color:#8a6a20;margin-bottom:.5rem">OBJETS (' + items.length + ')</div>';
    if (items.length === 0) {
      html += '<div style="font-size:.8rem;color:#3a3020;font-style:italic">Aucun objet en votre possession.</div>';
    } else {
      items.forEach((item, i) => {
        html += '<div style="display:flex;align-items:center;justify-content:space-between;padding:.4rem .3rem;border-bottom:1px solid #1a1810">';
        html += '<div style="display:flex;align-items:center;gap:.4rem"><i class="ti ' + (item.icon||'ti-package') + '" style="font-size:.9rem;color:#8a6a20"></i><div>';
        html += '<div style="font-size:.8rem;color:#c0b090">' + item.name + '</div>';
        html += '<div style="font-size:.65rem;color:#4a4030">' + (item.legal !== undefined ? (item.legal ? 'Legal' : 'Non enregistre') : '') + '</div>';
        html += '</div></div>';
        html += '<button onclick="dropItem(' + i + ')" style="font-size:.65rem;color:#6a3020;background:transparent;border:none;cursor:pointer;padding:.2rem .4rem">Jeter</button>';
        html += '</div>';
      });
    }
    html += '</div>';
    html += '</div>';
    content.innerHTML = html;

  } else if (tab === 'identite') {
    const char = state.char;
    const ar = ARCHETYPES.find(x => x.id === char?.archetype);
    const ca = CAREERS.find(x => x.id === char?.career);
    const co = COUNTRIES[state.country];
    const photo = char?.photoUrl
      ? '<img src="' + char.photoUrl + '" style="width:80px;height:80px;border-radius:50%;border:2px solid #8a6a20;object-fit:cover">'
      : '<div style="width:80px;height:80px;border-radius:50%;background:#1a1508;border:2px solid #3a2a10;display:flex;align-items:center;justify-content:center;color:#C9A84C"><i class="ti ti-user" style="font-size:1.8rem"></i></div>';

    let html = '<div style="padding:1.2rem;max-width:600px">';
    html += '<div style="display:flex;align-items:center;gap:1rem;margin-bottom:1rem;padding-bottom:1rem;border-bottom:1px solid #1a1810">';
    html += photo;
    html += '<div><div style="font-family:Playfair Display,serif;font-size:1.2rem;font-weight:700;color:#E8C97A">' + (char?.name||'') + '</div>';
    html += '<div style="font-size:.8rem;color:#7a7060;font-style:italic">' + (ar?.name||'') + ' · ' + (co?.n||'') + '</div>';
    if (state.poste) html += '<div style="font-size:.75rem;color:#C9A84C;margin-top:.2rem"><i class="ti ti-briefcase" style="font-size:.7rem"></i> ' + state.poste.name + '</div>';
    if (char?.motto) html += '<div style="font-size:.72rem;color:#5a5040;margin-top:.3rem;font-style:italic">"' + char.motto + '"</div>';
    html += '</div></div>';

    // Stats
    html += '<div style="display:grid;grid-template-columns:repeat(3,1fr);gap:.3rem;margin-bottom:.8rem">';
    STAT_DEFS.forEach(s => {
      html += '<div style="text-align:center;padding:.4rem;background:#0f0d05;border:1px solid #1a1810">';
      html += '<div style="font-size:.6rem;color:#4a4030;text-transform:uppercase">' + s.k + '</div>';
      html += '<div style="font-family:Bebas Neue,sans-serif;font-size:1.2rem;color:#C9A84C">' + (char?.stats?.[s.k]||8) + '</div>';
      html += '</div>';
    });
    html += '</div>';

    if (char?.bio) html += '<div style="font-size:.82rem;color:#8a8060;font-style:italic;line-height:1.7;padding:.8rem;background:#0f0d05;border:1px solid #1a1810">' + char.bio + '</div>';
    html += '</div>';
    content.innerHTML = html;
  }
}

function doDormir() {
  if (state.salaireTouche) {
    showToast('Deja dormi', 'Vous avez deja percu votre salaire aujourd\'hui.', false);
    return;
  }
  const b = state.currentBuilding ? BUILDINGS[state.currentBuilding] : null;
  const confortMap = {
    'hotel-republica':    { moral: 5, paBonus: 5 },
    'hotel-port':         { moral: 3, paBonus: 2 },
    'hotel-mineur':       { moral: 3, paBonus: 2 },
    'palais-presidentiel':{ moral: 8, paBonus: 8 }
  };
  const confort = confortMap[state.currentBuilding] || { moral: 1, paBonus: 0 };

  state.salaireTouche = true;
  const salaire = state.poste ? (SALAIRES[state.poste.id] || SALAIRES.default) : SALAIRES.default;
  state.arg += salaire;
  state.liquide += Math.floor(salaire * 0.3);
  state.banque += Math.ceil(salaire * 0.7);
  state.moral = Math.min(100, state.moral + confort.moral);
  if (confort.paBonus > 0) state.paBonus = confort.paBonus;

  updateUI();
  const cur = COUNTRIES[state.char?.country || 'republic']?.cur || 'FR';
  showToast('Bonne nuit !', 'Salaire verse : +' + salaire.toLocaleString('fr-FR') + ' ' + cur + ' · +' + confort.moral + ' Moral', true, true);
  addJournalEntry('Vous dormez. Salaire verse : +' + salaire.toLocaleString('fr-FR') + ' ' + cur, 'event-good');

  // Traiter les evenements nocturnes
  traiterPlaintes();
  traiterEnquetes();
  checkArrestationAuReveil();

  // Rafraichir la vue
  switchSelfTab('actions', null);
}

function doSesoigner() {
  const medocs = (state.inventory || []).filter(i => i.type === 'medicament');
  if (medocs.length === 0) { showToast('Aucun medicament', '', false); return; }
  const idx = state.inventory.indexOf(medocs[0]);
  state.inventory.splice(idx, 1);
  state.hp = Math.min(100, state.hp + 20);
  updateUI();
  showToast('Soins', '+20 Sante. ' + (state.inventory.filter(i=>i.type==='medicament').length) + ' medicament(s) restant(s).', true);
  switchSelfTab('inventaire', null);
}

function dropItem(index) {
  const item = state.inventory[index];
  if (!item) return;
  state.inventory.splice(index, 1);
  showToast('Objet jete', item.name + ' retire de votre inventaire.', false);
  switchSelfTab('inventaire', null);
}

// =====================
// SYSTEME D'ARRESTATION
// =====================
const PEINES = {
  delit_mineur:   { jours: 2,  label: 'Delit mineur',   amendeBase: 500  },
  delit_grave:    { jours: 4,  label: 'Delit grave',     amendeBase: 1500 },
  crime:          { jours: 8,  label: 'Crime',           amendeBase: 5000 },
  crime_etat:     { jours: 30, label: "Crime d'Etat",    amendeBase: 0    }
};

const ACTES_ILLEGAUX = {
  corrompre_fonct:    { type: 'delit_mineur',  detectRate: 30 },
  corrompre_police:   { type: 'delit_mineur',  detectRate: 35 },
  corrompre_juge:     { type: 'delit_grave',   detectRate: 40 },
  corrompre_journaliste:{ type: 'delit_mineur',detectRate: 25 },
  blanchiment:        { type: 'delit_grave',   detectRate: 35 },
  societe_ecran:      { type: 'delit_mineur',  detectRate: 25 },
  falsifier_docs:     { type: 'delit_grave',   detectRate: 40 },
  acheter_arme_illegale:{ type: 'delit_mineur',detectRate: 20 },
  acheter_bombe_illegale:{ type: 'crime',      detectRate: 55 },
  fabriquer_bombe:    { type: 'crime',         detectRate: 60 },
  incendier:          { type: 'crime',         detectRate: 70 },
  arreter:            { type: 'delit_grave',   detectRate: 40 },
  fabriquer_scandale: { type: 'delit_grave',   detectRate: 45 },
  fuite_info:         { type: 'delit_grave',   detectRate: 40 },
  imprimer_clandestin:{ type: 'delit_mineur',  detectRate: 30 },
  tentative_evasion:  { type: 'crime',         detectRate: 90 },
  se_rebeller:        { type: 'delit_mineur',  detectRate: 60 }
};

function checkDetection(fn, resultType) {
  const acte = ACTES_ILLEGAUX[fn];
  if (!acte) return;
  if (resultType === 'fail' || resultType === 'crit-fail') return; // Pas d'acte = pas de detection

  // Immunite selon poste
  const posteId = state.poste?.id;
  if (posteId === 'president') return; // Immunite totale
  if (['pm','min_int','min_fin','min_just','min_def','min_info','min_ae'].includes(posteId)) {
    if (acte.type === 'delit_mineur') return; // Immunite partielle ministres
  }

  const roll = Math.floor(Math.random() * 100) + 1;
  const tauxDetect = Math.max(5, acte.detectRate - Math.floor(state.dis / 10));

  if (roll <= tauxDetect) {
    if (!state.recherche) state.recherche = [];
    state.recherche.push({ acte: fn, type: acte.type, jour: state.day });
    addExternalEvent('ALERTE : Votre activite illegale (' + fn.replace(/_/g,' ') + ') a ete detectee. Vous etes recherche(e).');
    state.dis = Math.max(0, state.dis - 10);
    updateUI();
  }
}

function checkArrestationAuDeplacement() {
  if (!state.recherche || state.recherche.length === 0) return;
  const alerteMax = state.recherche.reduce((max, r) => {
    const peine = PEINES[r.type];
    return peine && peine.jours > (PEINES[max]?.jours||0) ? r.type : max;
  }, 'delit_mineur');

  const roll = Math.floor(Math.random() * 100) + 1;
  const tauxInter = Math.max(5, 30 - Math.floor(state.dis / 5));

  if (roll <= tauxInter) {
    ouvrirModalArrestation(alerteMax);
  }
}

function checkArrestationAuReveil() {
  // Chance reduite d'arrestation pendant la nuit
  if (!state.recherche || state.recherche.length === 0) return;
  const roll = Math.floor(Math.random() * 100) + 1;
  if (roll <= 10) {
    const alerteMax = state.recherche[state.recherche.length - 1]?.type || 'delit_mineur';
    addExternalEvent('La police a retrouve votre trace. Vous avez ete arrete(e) dans la nuit.');
    procederArrestation(alerteMax, false);
  }
}

function ouvrirModalArrestation(peineType) {
  const peine = PEINES[peineType] || PEINES.delit_mineur;
  document.getElementById('modal-postes').querySelector('.modal-title').textContent = 'Interception policiere !';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1rem">' +
    '<div style="font-size:.88rem;color:#cc4444;font-family:Playfair Display,serif;margin-bottom:1rem">Des policiers vous barrent la route. Chef d\'inculpation : ' + peine.label + '.</div>' +
    '<div style="font-size:.8rem;color:#8a8060;margin-bottom:1rem">Peine encourue : ' + peine.jours + ' jour(s) d\'emprisonnement.</div>' +
    '<div style="display:flex;flex-direction:column;gap:.5rem">' +
    '<button onclick="procederArrestation(\'' + peineType + '\',false);document.getElementById(\'modal-postes\').classList.remove(\'open\')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1rem;border:1px solid #4a6a4a;background:transparent;color:#6a9a6a;cursor:pointer"><i class="ti ti-check" style="font-size:.8rem"></i> Se rendre</button>' +
    '<button onclick="tenterFuite()" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer"><i class="ti ti-run" style="font-size:.8rem"></i> Fuir (VOL+DIS)</button>' +
    '<button onclick="tenterResistance(\'' + peineType + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1rem;border:1px solid #8a2020;background:transparent;color:#cc4444;cursor:pointer"><i class="ti ti-sword" style="font-size:.8rem"></i> Resister (tres risque)</button>' +
    '</div></div>';
  document.getElementById('modal-postes').classList.add('open');
}

function procederArrestation(peineType, resistanceAggravante) {
  const peine = PEINES[peineType] || PEINES.delit_mineur;
  const jours = peine.jours + (resistanceAggravante ? 2 : 0);
  const amende = peine.amendeBase;

  state.estEmprisonne = { jours, jourFin: state.day + jours, raison: peine.label };
  state.recherche = [];
  if (amende > 0) state.arg = Math.max(0, state.arg - amende);
  if (state.poste && peineType === 'crime') {
    addExternalEvent('Votre poste de ' + state.poste.name + ' vous a ete retire suite a votre arrestation.');
    state.poste = null;
  }
  updateUI();
  addExternalEvent('Vous avez ete arrete(e) pour ' + peine.label + '. ' + jours + ' jour(s) d\'emprisonnement. Amende : ' + amende.toLocaleString('fr-FR') + ' FR.');
  if (!state.prisonniers) state.prisonniers = [];
  state.prisonniers.push({ nom: state.char?.name, depuis: 'Jour ' + state.day, raison: peine.label, jourFin: state.day + jours });
}

function tenterFuite() {
  document.getElementById('modal-postes').classList.remove('open');
  const vol = state.char?.stats?.VOL || 8;
  const bonus = Math.floor(state.dis / 10) + Math.floor(vol / 2);
  const taux = Math.min(70, 30 + bonus);
  const roll = Math.floor(Math.random() * 100) + 1;

  if (roll <= taux) {
    state.dis = Math.max(0, state.dis - 20);
    updateUI();
    showToast('Fuite reussie !', 'Vous echappez aux policiers. -20 Discretion.', true, true);
    addJournalEntry('Vous avez pris la fuite face aux policiers. Votre discretion chute.', 'event-bad');
  } else {
    addExternalEvent('Tentative de fuite echouee. Arrestation avec circonstance aggravante.');
    const peineType = state.recherche?.[0]?.type || 'delit_mineur';
    procederArrestation(peineType, true);
  }
}

function tenterResistance(peineType) {
  document.getElementById('modal-postes').classList.remove('open');
  const vol = state.char?.stats?.VOL || 8;
  const taux = Math.min(30, vol * 2);
  const roll = Math.floor(Math.random() * 100) + 1;

  if (roll <= taux) {
    state.dis = Math.max(0, state.dis - 30);
    state.hp = Math.max(1, state.hp - 15);
    updateUI();
    showToast('Resistance reussie !', 'Vous vous echappez malgre tout. -30 DIS -15 HP.', true);
    addJournalEntry('Vous avez resiste violemment aux forces de l\'ordre. Fortement recherche(e).', 'event-bad');
    // Aggravation du statut
    if (!state.recherche) state.recherche = [];
    state.recherche.push({ acte: 'rebellion', type: 'delit_grave', jour: state.day });
  } else {
    addExternalEvent('Resistance aux forces de l\'ordre. Arrestation avec chef de rebellion.');
    procederArrestation(peineType, true);
    state.hp = Math.max(1, state.hp - 20);
    updateUI();
  }
}

function openRulesView() {
  document.querySelectorAll('.vue').forEach(v => v.classList.remove('active'));
  document.getElementById('vue-rules').classList.add('active');
  renderRulesContent('intro');
}

function closeRulesView() {
  document.getElementById('vue-rules').classList.remove('active');
  if (state.currentBuilding) {
    document.getElementById('vue-batiment').classList.add('active');
  } else {
    document.getElementById('vue-rue').classList.add('active');
  }
}

function renderRulesContent(section) {
  const regle = REGLES[section];
  if (!regle) return;

  document.querySelectorAll('.rules-tab').forEach(t => t.classList.remove('active'));
  document.querySelectorAll('.rules-tab').forEach(t => {
    if (t.dataset.section === section) t.classList.add('active');
  });

  const content = document.getElementById('rules-content');
  if (!content) return;
  content.innerHTML = '<div style="padding:1.5rem;max-width:700px">' +
    '<div style="font-family:Playfair Display,serif;font-size:1.3rem;color:#C9A84C;margin-bottom:1rem">' + regle.titre + '</div>' +
    '<div style="font-size:.88rem;color:#a0a080;line-height:1.9;white-space:pre-line">' + regle.contenu + '</div>' +
    '</div>';
}

// =====================
// ORDRES PRESIDENTIELS
// =====================
// =====================
// FONCTIONS PRESIDENTIELLES V13
// =====================

function solliciterAudiencePresident() {
  const char = state.char;
  const nomDemandeur = char?.name || 'Anonyme';
  // Message automatique au demandeur
  showToast(
    'Demande transmise',
    'Je transmets votre demande à Monsieur le Président. Il vous contactera dès qu\'il en aura pris connaissance.',
    true
  );
  addJournalEntry('Vous avez sollicite une audience presidentielle.', 'event-info');
  // Mail au President
  addMailNotification(
    'Secretariat de la Presidence',
    'Demande d\'audience de ' + nomDemandeur,
    nomDemandeur + ' sollicite une audience presidentielle. Vous pouvez lui repondre directement a cette adresse mail.'
  );
}

// =====================
// INDICES IMPERIAUX (bouton topbar)
// =====================
function ouvrirIndicesImperiaux() {
  document.querySelectorAll('.vue').forEach(v => v.classList.remove('active'));
  const el = document.getElementById('vue-self');
  el.classList.add('active');
  document.getElementById('self-view-name').textContent = 'Indices Imperiaux';
  document.getElementById('self-view-role').textContent = 'Etat des 4 empires';

  const content = document.getElementById('self-content');
  const empires = [
    { key:'republic', name:'Républia',   col:'#4a9ade', flag:'🇫🇷' },
    { key:'narco',    name:'El Estado',  col:'#cc4444', flag:'🔴' },
    { key:'soviet',   name:'Sovarka',    col:'#cc2020', flag:'⭐' },
    { key:'khalija',  name:'Al-Khalija', col:'#C9A84C', flag:'🌙' }
  ];

  let html = '<div style="padding:1.2rem;max-width:700px">';
  html += '<div style="font-family:Playfair Display,serif;font-size:1.1rem;color:#C9A84C;margin-bottom:1rem">Indices des 4 Empires</div>';

  empires.forEach(emp => {
    const idx = (typeof INDICES_NATIONAUX !== 'undefined') ? (INDICES_NATIONAUX[emp.key] || {ISN:30,IE:50,ID:40,IS:45}) : {ISN:30,IE:50,ID:40,IS:45};
    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.8rem;margin-bottom:.6rem">';
    html += '<div style="font-family:Playfair Display,serif;font-size:.9rem;color:' + emp.col + ';margin-bottom:.6rem">' + emp.flag + ' ' + emp.name + '</div>';
    html += '<div style="display:grid;grid-template-columns:repeat(4,1fr);gap:.4rem">';
    [['ISN','Securite','#4a8a4a'],['IE','Economique','#C9A84C'],['ID','Diplomatique','#4a6aaa'],['IS','Social','#aa6a4a']].forEach(([k,label,col]) => {
      const val = idx[k] || 0;
      html += '<div style="text-align:center;padding:.4rem;background:#0a0805;border:1px solid #1a1810">';
      html += '<div style="font-size:.6rem;color:#4a4030;text-transform:uppercase">' + label + '</div>';
      html += '<div style="font-family:Bebas Neue,sans-serif;font-size:1.3rem;color:' + col + '">' + val + '</div>';
      html += '<div style="height:4px;background:#0a0a05;margin-top:.2rem"><div style="height:100%;width:' + val + '%;background:' + col + ';opacity:.6"></div></div>';
      html += '</div>';
    });
    html += '</div></div>';
  });

  html += '<div style="font-size:.72rem;color:#4a4030;font-style:italic;margin-top:.5rem">Cliquer sur "Etat de la Nation" au Palais Presidentiel pour le detail et l\'impact de chaque indice.</div>';
  html += '</div>';
  content.innerHTML = html;
}

// =====================
// ASSEMBLEE NATIONALE
// =====================
function observerDebats() {
  const deputes = ['Depute Marchand (PNJ)', 'Depute Fontaine (PNJ)', 'Depute Rousseau (PNJ)', 'Depute Girard (PNJ)'];
  const positions = ['Pour', 'Contre', 'Abstention'];
  const loisEnCours = state.loisEnCours || [];

  document.getElementById('modal-postes').querySelector('.modal-title').textContent = 'Observer les debats';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Vous observez discretement les echanges dans la salle.</div>';

  if (loisEnCours.length > 0) {
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">VOTES EN COURS</div>';
    loisEnCours.forEach(loi => {
      html += '<div style="padding:.5rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem">';
      html += '<div style="font-size:.82rem;color:#c0b090;margin-bottom:.3rem">' + loi.titre + '</div>';
      deputes.forEach(d => {
        const pos = positions[Math.floor(Math.random() * positions.length)];
        const col = pos === 'Pour' ? '#4a8a4a' : pos === 'Contre' ? '#8a3a2a' : '#6a6040';
        html += '<div style="font-size:.72rem;color:#6a6040">' + d + ' : <span style="color:' + col + '">' + pos + '</span></div>';
      });
      html += '</div>';
    });
  } else {
    html += '<div style="font-size:.82rem;color:#5a5030;font-style:italic">Aucune loi en cours de deliberation. La prochaine session est mercredi.</div>';
  }

  // Bonus journaliste
  if (state.char?.career === 'press') {
    state.inf = Math.min(100, state.inf + 1);
    updateUI();
    html += '<div style="font-size:.72rem;color:#C9A84C;margin-top:.5rem">+1 INF (bonus journaliste)</div>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function ouvrirVoteLoi() {
  const now = new Date();
  const isWednesday = now.getDay() === 3; // 0=dim, 3=mer
  const isBeforeDeadline = now.getHours() < 20;
  const loisEnCours = (state.loisEnCours || []).filter(l => l.pret);

  document.getElementById('modal-postes').querySelector('.modal-title').textContent = 'Voter une loi';
  let html = '<div style="padding:1rem">';

  if (!isWednesday || !isBeforeDeadline) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Le vote se tient uniquement le mercredi jusqu\'a 20h. Prochaine session : mercredi prochain.</div>';
  } else if (loisEnCours.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucune loi en attente de vote pour cette session.</div>';
  } else {
    loisEnCours.forEach((loi, i) => {
      const dejaVote = state.votesLois?.[loi.id];
      html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.8rem;margin-bottom:.6rem">';
      html += '<div style="font-family:Playfair Display,serif;font-size:.85rem;color:#E8C97A;margin-bottom:.3rem">' + loi.titre + '</div>';
      html += '<div style="font-size:.72rem;color:#6a5a30;margin-bottom:.5rem">Depose par ' + loi.auteur + ' le Jour ' + loi.jourDepot + '</div>';
      if (dejaVote) {
        html += '<div style="font-size:.78rem;color:#4a6a4a">Vote exprime : <strong>' + dejaVote + '</strong></div>';
      } else {
        html += '<div style="display:flex;gap:.5rem">';
        ['Pour', 'Contre', 'Abstention'].forEach(choix => {
          const col = choix === 'Pour' ? '#4a8a4a' : choix === 'Contre' ? '#8a2020' : '#6a6040';
          html += '<button onclick="enregistrerVoteLoi(' + i + ',\'' + choix + '\')" style="flex:1;padding:.4rem;border:1px solid ' + col + ';background:transparent;color:' + col + ';cursor:pointer;font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em">' + choix + '</button>';
        });
        html += '</div>';
      }
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function enregistrerVoteLoi(loiIdx, choix) {
  const loi = (state.loisEnCours || []).filter(l => l.pret)[loiIdx];
  if (!loi) return;
  if (!state.votesLois) state.votesLois = {};
  state.votesLois[loi.id] = choix;
  if (!loi.votes) loi.votes = [];
  loi.votes.push({ depute: state.char?.name || 'Anonyme', choix });
  document.getElementById('modal-postes').classList.remove('open');
  showToast('Vote enregistre', choix + ' pour : ' + loi.titre, true, true);
  addJournalEntry('Vote : ' + choix + ' — ' + loi.titre, 'event-info');
}

function ouvrirArchivesLois() {
  const archives = state.archivesLois || [];
  document.getElementById('modal-postes').querySelector('.modal-title').textContent = 'Archives de l\'Assemblee';
  let html = '<div style="padding:1rem">';
  if (archives.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucune loi votee pour le moment.</div>';
  } else {
    archives.forEach((loi, i) => {
      html += '<div onclick="ouvrirDetailLoi(' + i + ')" style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;cursor:pointer;transition:background .15s" onmouseover="this.style.background=\'#151005\'" onmouseout="this.style.background=\'#0f0d05\'">';
      html += '<div style="display:flex;justify-content:space-between;align-items:center">';
      html += '<div style="font-family:Playfair Display,serif;font-size:.82rem;color:#c0b090">' + loi.titre + '</div>';
      const col = loi.resultat === 'Adoptee' ? '#4a8a4a' : '#8a2020';
      html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;color:' + col + '">' + (loi.resultat||'En cours') + '</div>';
      html += '</div>';
      html += '<div style="font-size:.68rem;color:#5a4030">Jour ' + loi.jourVote + ' · ' + (loi.votes?.length||0) + ' votants</div>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function ouvrirDetailLoi(idx) {
  const loi = (state.archivesLois||[])[idx];
  if (!loi) return;
  document.getElementById('modal-postes').querySelector('.modal-title').textContent = loi.titre;
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#6a5a30;margin-bottom:.6rem">Depose par ' + loi.auteur + ' · Vote Jour ' + loi.jourVote + '</div>';
  const col = loi.resultat === 'Adoptee' ? '#4a8a4a' : '#8a2020';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:1rem;color:' + col + ';margin-bottom:.8rem">' + (loi.resultat||'En cours') + '</div>';
  if (loi.votes?.length > 0) {
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">VOTES NOMINATIFS</div>';
    loi.votes.forEach(v => {
      const vc = v.choix === 'Pour' ? '#4a8a4a' : v.choix === 'Contre' ? '#8a2020' : '#5a5040';
      html += '<div style="display:flex;justify-content:space-between;font-size:.78rem;padding:.2rem 0;border-bottom:1px solid #1a1810">';
      html += '<span style="color:#c0b090">' + v.depute + '</span><span style="color:' + vc + '">' + v.choix + '</span></div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

// =====================
// TRIBUNAL
// =====================
function ouvrirArchivesTribunal() {
  const jugements = state.archivesJugements || [];
  document.getElementById('modal-postes').querySelector('.modal-title').textContent = 'Archives du Tribunal';
  let html = '<div style="padding:1rem">';
  if (jugements.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucun jugement enregistre pour le moment.</div>';
  } else {
    jugements.forEach((j, i) => {
      html += '<div onclick="ouvrirDetailJugement(' + i + ')" style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;cursor:pointer" onmouseover="this.style.background=\'#151005\'" onmouseout="this.style.background=\'#0f0d05\'">';
      html += '<div style="display:flex;justify-content:space-between">';
      html += '<div style="font-family:Playfair Display,serif;font-size:.82rem;color:#c0b090">' + j.accuse + '</div>';
      html += '<div style="font-size:.7rem;color:#5a4030">Jour ' + j.jour + '</div>';
      html += '</div>';
      html += '<div style="font-size:.72rem;color:#6a5a30">' + j.motif + ' · ' + (j.peine||'En cours') + '</div>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function ouvrirDetailJugement(idx) {
  const j = (state.archivesJugements||[])[idx];
  if (!j) return;
  document.getElementById('modal-postes').querySelector('.modal-title').textContent = 'Jugement — ' + j.accuse;
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#6a5a30;margin-bottom:.5rem">Date : Jour ' + j.jour + ' · Juge : ' + (j.juge||'PNJ') + '</div>';
  html += '<div style="font-size:.82rem;color:#c0b090;margin-bottom:.3rem">Motif : ' + j.motif + '</div>';
  html += '<div style="font-size:.82rem;color:#c0b090;margin-bottom:.3rem">Peine : ' + (j.peine||'N/A') + '</div>';
  if (j.executee !== undefined) html += '<div style="font-size:.78rem;color:' + (j.executee ? '#4a8a4a' : '#8a6a20') + '">' + (j.executee ? 'Peine executee' : 'Peine en cours ou amenagee') + '</div>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

function ouvrirPorterPlainte() {
  const ville = WORLD[state.country]?.[state.currentCity]?.name || 'la ville';
  document.getElementById('modal-postes').querySelector('.modal-title').textContent = 'Porter plainte';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Votre plainte sera deposee dans le sous-forum "Tribunal de ' + ville + '", visible uniquement par les habitants de ' + ville + '.</div>';

  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">CONTRE QUI ?</div>';
  html += '<div style="display:flex;gap:.5rem;margin-bottom:.7rem">';
  html += '<button id="plainte-cible-btn" onclick="selectPlainteCible(\'cible\')" style="flex:1;padding:.3rem;border:1px solid #8a6a20;background:#0f0d05;color:#C9A84C;cursor:pointer;font-family:Bebas Neue,sans-serif;font-size:.7rem">Un PJ identifie</button>';
  html += '<button id="plainte-x-btn" onclick="selectPlainteCible(\'x\')" style="flex:1;padding:.3rem;border:1px solid #2a2010;background:#0f0d05;color:#5a5040;cursor:pointer;font-family:Bebas Neue,sans-serif;font-size:.7rem">Contre X (inconnu)</button>';
  html += '</div>';

  html += '<div id="plainte-cible-select" style="margin-bottom:.7rem">';
  const contacts = state.contacts || [];
  if (contacts.length > 0) {
    html += '<select id="plainte-cible-nom" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none">';
    contacts.forEach(c => { html += '<option value="' + c.name + '">' + c.name + '</option>'; });
    html += '</select>';
  } else {
    html += '<div style="font-size:.78rem;color:#5a5040">Repertoire vide. La plainte sera deposee contre X.</div>';
  }
  html += '</div>';

  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">MOTIF</div>';
  html += '<textarea id="plainte-motif" rows="4" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;resize:none;margin-bottom:.7rem" placeholder="Decrivez les faits reprochés, la date, les circonstances..."></textarea>';
  html += '<button onclick="soumettrePlainte()" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Deposer la plainte</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
  window._plainteCible = 'cible';
}

function selectPlainteCible(type) {
  window._plainteCible = type;
  document.getElementById('plainte-cible-btn').style.borderColor = type === 'cible' ? '#8a6a20' : '#2a2010';
  document.getElementById('plainte-cible-btn').style.color = type === 'cible' ? '#C9A84C' : '#5a5040';
  document.getElementById('plainte-x-btn').style.borderColor = type === 'x' ? '#8a6a20' : '#2a2010';
  document.getElementById('plainte-x-btn').style.color = type === 'x' ? '#C9A84C' : '#5a5040';
}

function soumettrePlainte() {
  const motif = document.getElementById('plainte-motif')?.value?.trim();
  if (!motif) { showToast('Motif requis', 'Decrivez les faits.', false); return; }
  const cibleNom = window._plainteCible === 'cible'
    ? (document.getElementById('plainte-cible-nom')?.value || 'X')
    : 'X (inconnu)';
  const ville = WORLD[state.country]?.[state.currentCity]?.name || 'la ville';
  const forumKey = 'tribunal_' + state.currentCity;
  if (!FORUM_TOPICS[forumKey]) FORUM_TOPICS[forumKey] = [];
  FORUM_TOPICS[forumKey].unshift({
    id: 'plainte-' + Date.now(),
    title: '[PLAINTE] ' + (state.char?.name||'Anonyme') + ' contre ' + cibleNom,
    author: state.char?.name || 'Anonyme',
    time: 'Jour ' + state.day,
    replies: 0,
    isPlainte: true,
    cible: cibleNom,
    posts: [{
      author: state.char?.name || 'Anonyme',
      time: 'Jour ' + state.day,
      content: '**DEPOT DE PLAINTE**\n\nPlaignant : ' + (state.char?.name||'Anonyme') + '\nMis en cause : ' + cibleNom + '\n\nFaits :\n' + motif
    }]
  });
  if (!state.plaintesEnCours) state.plaintesEnCours = [];
  state.plaintesEnCours.push({ cible: cibleNom, motif, jour: state.day, status: 'deposee' });
  document.getElementById('modal-postes').classList.remove('open');
  showToast('Plainte deposee !', 'Visible dans le forum "Tribunal de ' + ville + '". Jugement le jeudi.', true, true);
  addJournalEntry('Plainte deposee contre ' + cibleNom, 'event-info');
  addExternalEvent('Une plainte a ete deposee contre ' + cibleNom + ' au Tribunal de ' + ville + '.');
}

function ouvrirRendreSentence() {
  const affaires = state.plaintesEnCours?.filter(p => p.status === 'deposee') || [];
  document.getElementById('modal-postes').querySelector('.modal-title').textContent = 'Rendre la sentence';
  let html = '<div style="padding:1rem">';
  if (affaires.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucune affaire en attente de jugement.</div>';
  } else {
    affaires.forEach((a, i) => {
      html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.8rem;margin-bottom:.6rem">';
      html += '<div style="font-family:Playfair Display,serif;font-size:.85rem;color:#E8C97A;margin-bottom:.3rem">Affaire : ' + a.cible + '</div>';
      html += '<div style="font-size:.72rem;color:#6a5a30;margin-bottom:.6rem">' + a.motif + '</div>';
      html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.68rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.4rem">SENTENCE</div>';
      html += '<div style="display:flex;flex-direction:column;gap:.3rem">';
      html += '<button onclick="appliquerSentence(' + i + ',\'amende\')" style="text-align:left;padding:.4rem .7rem;border:1px solid #2a4a20;background:#0a0d05;color:#6a9a6a;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem">Amende (montant + repartition)</button>';
      html += '<button onclick="appliquerSentence(' + i + ',\'prison\')" style="text-align:left;padding:.4rem .7rem;border:1px solid #3a2a10;background:#0a0d05;color:#9a8a4a;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem">Prison (max 7 jours)</button>';
      html += '<button onclick="appliquerSentence(' + i + ',\'amenagement\')" style="text-align:left;padding:.4rem .7rem;border:1px solid #2a3a4a;background:#0a0d05;color:#6a8aaa;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem">Amenagement de peine (pointage commissariat)</button>';
      html += '<button onclick="appliquerSentence(' + i + ',\'qhs\')" style="text-align:left;padding:.4rem .7rem;border:1px solid #4a1a10;background:#0a0d05;color:#9a4a3a;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem">Envoi au QHS</button>';
      html += '</div></div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function appliquerSentence(idx, type) {
  const affaire = (state.plaintesEnCours||[]).filter(p => p.status === 'deposee')[idx];
  if (!affaire) return;
  affaire.status = 'jugee';

  const cur = COUNTRIES[state.country]?.cur || 'FR';
  let details = '';

  if (type === 'amende') {
    const montant = 500;
    details = 'Amende de ' + montant + ' ' + cur;
  } else if (type === 'prison') {
    const duree = 3;
    details = 'Prison ' + duree + ' jours';
    if (!state.prisonniers) state.prisonniers = [];
    state.prisonniers.push({ nom: affaire.cible, depuis: 'Jour ' + state.day, raison: affaire.motif, jourFin: state.day + duree });
  } else if (type === 'amenagement') {
    details = 'Amenagement : pointage quotidien au commissariat';
  } else if (type === 'qhs') {
    details = 'Envoi au QHS';
    if (!state.prisonniers) state.prisonniers = [];
    state.prisonniers.push({ nom: affaire.cible, depuis: 'Jour ' + state.day, raison: affaire.motif, jourFin: state.day + 30, qhs: true });
  }

  if (!state.archivesJugements) state.archivesJugements = [];
  state.archivesJugements.push({
    accuse: affaire.cible,
    motif: affaire.motif,
    peine: details,
    juge: state.char?.name || 'PNJ',
    jour: state.day,
    executee: false
  });

  document.getElementById('modal-postes').classList.remove('open');
  showToast('Sentence rendue', affaire.cible + ' : ' + details, true, true);
  addExternalEvent('JUGEMENT : ' + affaire.cible + ' condamne(e) a : ' + details + ' (Juge : ' + (state.char?.name||'PNJ') + ')');
  addMailNotification('Tribunal', 'Resultat de votre affaire', 'La sentence a ete rendue : ' + details);
}

// =====================
// FALSIFIER UN DOCUMENT
// =====================
const DOCUMENTS_FALSIFIABLES = [
  { id:'fausse_identite',   name:'Fausse identite',          desc:'Change votre nom affiche dans le jeu temporairement.',     icon:'ti-id-badge' },
  { id:'faux_casier',       name:'Faux casier judiciaire vierge', desc:'Efface vos antecedents judiciaires dans les archives.', icon:'ti-file-x' },
  { id:'faux_permis',       name:'Faux permis de construire', desc:'Permet de construire sans passer par la mairie.',          icon:'ti-building' },
  { id:'faux_contrat',      name:'Faux contrat commercial',   desc:'Legitime une transaction illegale ou un transfert.',       icon:'ti-file-text' },
  { id:'fausse_convocation',name:'Fausse convocation officielle', desc:'Attire un PJ dans un lieu de votre choix.',           icon:'ti-mail' }
];

function ouvrirFalsifierDocument() {
  document.getElementById('modal-postes').querySelector('.modal-title').textContent = 'Falsifier un document';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#cc4444;font-style:italic;margin-bottom:.8rem">Acte illegal. Taux 45%. Echec : alerte possible. Document ajoute a votre inventaire si succes.</div>';
  DOCUMENTS_FALSIFIABLES.forEach(doc => {
    html += '<div onclick="confirmerFalsification(\'' + doc.id + '\')" style="padding:.6rem .8rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;cursor:pointer;transition:background .15s" onmouseover="this.style.background=\'#151005\'" onmouseout="this.style.background=\'#0f0d05\'">';
    html += '<div style="display:flex;align-items:center;gap:.6rem">';
    html += '<i class="ti ' + doc.icon + '" style="font-size:1rem;color:#8a6a20"></i>';
    html += '<div><div style="font-size:.82rem;color:#c0b090">' + doc.name + '</div>';
    html += '<div style="font-size:.68rem;color:#5a4030">' + doc.desc + '</div></div>';
    html += '</div></div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerFalsification(docId) {
  document.getElementById('modal-postes').classList.remove('open');
  const doc = DOCUMENTS_FALSIFIABLES.find(d => d.id === docId);
  if (!doc) return;

  const roll = Math.floor(Math.random() * 100) + 1;
  const taux = Math.max(5, 45 - getMalusISN());

  if (roll <= taux) {
    if (!state.inventory) state.inventory = [];
    state.inventory.push({
      type: 'document_falsifie',
      name: doc.name,
      icon: doc.icon,
      docId: doc.id,
      legal: false,
      desc: doc.desc
    });
    state.arg -= 300;
    updateUI();
    showToast('Document falsifie !', doc.name + ' ajoute a votre inventaire.', true, true);
    addJournalEntry('Falsification : ' + doc.name, 'event-bad');
    checkDetection('falsifier_document', 'success');
  } else {
    showToast('Echec !', 'La falsification a echoue. Vous etes peut-etre repere(e).', false);
    checkDetection('falsifier_document', 'fail');
    addJournalEntry('Tentative de falsification echouee.', 'event-bad');
  }
}

// =====================
// CORRIGER POSTULER
// =====================
function ouvrirPostulerPoste() {
  const pays = state.country || 'republic';
  const ville = state.currentCity || 'capitale';
  const postes = POSTES[pays]?.[ville] || POSTES[pays]?.capitale || [];

  document.getElementById('modal-postes').querySelector('.modal-title').textContent = 'Postuler a un poste';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Postes disponibles a ' + (WORLD[pays]?.[ville]?.name||ville) + ' :</div>';

  if (postes.length === 0) {
    html += '<div style="font-size:.85rem;color:#5a5040">Aucun poste disponible ici.</div>';
  } else {
    postes.forEach(poste => {
      const estOccupeParPJ = poste.holder && !poste.holder.startsWith('PNJ-');
      const estPresident = poste.id === 'president';
      const estPM = poste.id === 'pm';
      const isPJHolder = estOccupeParPJ;
      const moi = state.char?.name;

      // Ne pas afficher son propre poste
      if (poste.holder === moi) return;

      html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.7rem;margin-bottom:.5rem">';
      html += '<div style="display:flex;justify-content:space-between;align-items:center">';
      html += '<div><div style="font-family:Playfair Display,serif;font-size:.85rem;color:#E8C97A">' + poste.name + '</div>';
      html += '<div style="font-size:.7rem;color:#5a4030">Titulaire actuel : ' + (poste.holder || 'Vacant') + '</div></div>';

      if (estPresident && isPJHolder) {
        html += '<div style="font-size:.68rem;color:#6a3020;font-style:italic">Inaccessible</div>';
      } else if (estPM && isPJHolder) {
        html += '<div style="font-size:.68rem;color:#6a3020;font-style:italic">Inaccessible</div>';
      } else if (!isPJHolder) {
        // Poste PNJ - prise automatique
        html += '<button onclick="prendrePoste(\'' + poste.id + '\',\'' + poste.name + '\',false)" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;padding:.25rem .6rem;border:1px solid #4a8a4a;background:transparent;color:#4a8a4a;cursor:pointer">Prendre le poste</button>';
      } else {
        // Poste minister PJ - envoyer demande au PM
        html += '<button onclick="demanderPosteAuPM(\'' + poste.id + '\',\'' + poste.name + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;padding:.25rem .6rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Postuler</button>';
      }
      html += '</div></div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function prendrePoste(posteId, posteNom, isPJHolder) {
  document.getElementById('modal-postes').classList.remove('open');
  const pays = state.country || 'republic';
  const ville = state.currentCity || 'capitale';
  const postes = POSTES[pays]?.[ville] || POSTES[pays]?.capitale || [];
  const poste = postes.find(p => p.id === posteId);
  if (poste) poste.holder = state.char?.name;
  state.poste = { id: posteId, name: posteNom };
  updateUI();
  showToast('Poste pris !', 'Vous etes desormais ' + posteNom + '.', true, true);
  addJournalEntry('Prise de poste : ' + posteNom, 'event-good');
  addExternalEvent((state.char?.name||'Anonyme') + ' prend le poste de ' + posteNom + '.');
}

function demanderPosteAuPM(posteId, posteNom) {
  document.getElementById('modal-postes').classList.remove('open');
  addMailNotification(
    'Demande de poste',
    'Candidature : ' + posteNom,
    (state.char?.name||'Anonyme') + ' souhaite postuler au poste de ' + posteNom + '. Vous pouvez le/la nommer depuis votre bureau.'
  );
  showToast('Demande envoyee', 'Le Premier Ministre a ete informe de votre candidature au poste de ' + posteNom + '.', true);
  addJournalEntry('Candidature envoyee au PM pour : ' + posteNom, 'event-info');
}

function ouvrirEtatNation() {
  const pays = state.country || 'republic';
  const idx = INDICES_NATIONAUX[pays] || { ISN:30, IE:50, ID:40, IS:45 };
  document.querySelectorAll('.vue').forEach(v => v.classList.remove('active'));
  const el = document.getElementById('vue-self');
  if (!el) return;
  el.classList.add('active');
  document.getElementById('self-view-name').textContent = 'Etat de la Nation';
  document.getElementById('self-view-role').textContent = COUNTRIES[pays]?.n || '';
  const content = document.getElementById('self-content');

  const indices = [
    { k:'ISN', label:'Securite Nationale',    val:idx.ISN, col:'#4a8a4a', desc:'Impact sur les actes illegaux et leur detection.' },
    { k:'IE',  label:'Economique',            val:idx.IE,  col:'#C9A84C', desc:'Impact sur les revenus fiscaux et les salaires.' },
    { k:'ID',  label:'Diplomatique',          val:idx.ID,  col:'#4a6aaa', desc:'Impact sur les relations inter-empires et voyages.' },
    { k:'IS',  label:'Social',               val:idx.IS,  col:'#aa6a4a', desc:'Impact sur la popularite des elus et risques de greve.' }
  ];

  let html = '<div style="padding:1.5rem;max-width:650px">';
  html += '<div style="font-family:Playfair Display,serif;font-size:1.1rem;color:#C9A84C;margin-bottom:1.2rem">Indices de la Nation — ' + (COUNTRIES[pays]?.n||'') + '</div>';

  indices.forEach(ind => {
    const pct = ind.val;
    const niveau = pct <= 20 ? 'Critique' : pct <= 40 ? 'Faible' : pct <= 60 ? 'Moyen' : pct <= 80 ? 'Bon' : 'Excellent';
    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.8rem;margin-bottom:.6rem">';
    html += '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:.4rem">';
    html += '<div><span style="font-family:Bebas Neue,sans-serif;font-size:.85rem;color:' + ind.col + ';letter-spacing:.1em">Indice ' + ind.label + ' (' + ind.k + ')</span></div>';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:1.1rem;color:' + ind.col + '">' + pct + '/100 — ' + niveau + '</div>';
    html += '</div>';
    html += '<div style="height:8px;background:#1a1810;border-radius:4px;overflow:hidden;margin-bottom:.4rem">';
    html += '<div style="height:100%;width:' + pct + '%;background:' + ind.col + ';border-radius:4px;transition:width .5s"></div></div>';
    html += '<div style="font-size:.72rem;color:#5a5040">' + ind.desc + '</div>';
    html += '</div>';
  });

  // Malus illegal actuel
  const malus = getMalusIllegal ? getMalusIllegal(pays) : 0;
  const multDet = getMultDetection ? getMultDetection(pays) : 1;
  html += '<div style="padding:.7rem;background:#0a0805;border:1px solid #1a1810;font-size:.78rem;color:#6a5a30">';
  html += 'ISN actuel : malus de <strong style="color:#C9A84C">-' + malus + '%</strong> sur tous les actes illegaux · taux de detection x<strong style="color:#C9A84C">' + multDet + '</strong>';
  html += '</div>';
  html += '</div>';
  content.innerHTML = html;
}

function ouvrirModalEmpireCible(action, titre) {
  const empires = Object.entries(COUNTRIES).filter(([k]) => k !== state.country);
  document.getElementById('modal-postes').querySelector('.modal-title').textContent = titre;
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.82rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Choisir un empire cible :</div>';
  empires.forEach(([k, co]) => {
    html += '<button onclick="executerOrdreEmpire(\'' + action + '\',\'' + k + '\',\'' + co.n + '\')" style="display:flex;align-items:center;gap:.6rem;width:100%;padding:.6rem .8rem;border:1px solid #2a2010;background:#0f0d05;color:#c0b090;cursor:pointer;font-family:Crimson Pro,serif;font-size:.85rem;margin-bottom:.4rem">';
    html += '<i class="ti ' + co.icon + '" style="font-size:1rem;color:' + co.col + '"></i> ' + co.n + '</button>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function executerOrdreEmpire(action, empireId, empireName) {
  document.getElementById('modal-postes').classList.remove('open');
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  if (action === 'declarer_guerre') {
    if (!state.guerres) state.guerres = [];
    state.guerres.push({ empire: empireId, nom: empireName, depuis: 'Jour ' + state.day });
    INDICES_NATIONAUX[state.country].ID = Math.max(0, INDICES_NATIONAUX[state.country].ID - 20);
    addExternalEvent('GUERRE DECLAREE : ' + (COUNTRIES[state.country]?.n||'') + ' declare la guerre a ' + empireName + ' !');
    addMailNotification('Etat-Major', 'Declaration de guerre', 'La guerre a ete declaree contre ' + empireName + '. L\'armee est en alerte maximale.');
    showToast('Guerre declaree !', 'Conflit ouvert avec ' + empireName + '. -20 ID.', false);
  } else if (action === 'cessez_le_feu') {
    if (state.guerres) state.guerres = state.guerres.filter(g => g.empire !== empireId);
    INDICES_NATIONAUX[state.country].ID = Math.min(100, INDICES_NATIONAUX[state.country].ID + 10);
    showToast('Cessez-le-feu', 'Negociation en cours avec ' + empireName + '. +10 ID.', true);
    addJournalEntry('Cessez-le-feu negocie avec ' + empireName, 'event-good');
  } else if (action === 'ouvrir_ambassade') {
    if (!state.ambassades) state.ambassades = [];
    state.ambassades.push({ empire: empireId, nom: empireName });
    INDICES_NATIONAUX[state.country].ID = Math.min(100, INDICES_NATIONAUX[state.country].ID + 8);
    state.arg -= 1000;
    updateUI();
    showToast('Ambassade ouverte', 'Representation diplomatique etablie a ' + empireName + '. +8 ID.', true);
  } else if (action === 'sanctions') {
    INDICES_NATIONAUX[state.country].ID = Math.max(0, INDICES_NATIONAUX[state.country].ID - 5);
    INDICES_NATIONAUX[empireId] = INDICES_NATIONAUX[empireId] || {};
    showToast('Sanctions imposees', 'Sanctions economiques contre ' + empireName + '. -5 ID.', false);
    addExternalEvent('Sanctions officielles imposees contre ' + empireName + '.');
  } else {
    showToast(action.replace(/_/g,' '), 'Action menee envers ' + empireName, true);
    addJournalEntry(action.replace(/_/g,' ') + ' : ' + empireName, 'event-info');
  }
}

function ouvrirModalGracier() {
  const condamnes = state.prisonniers?.filter(p => p.jourFin > state.day) || [];
  document.getElementById('modal-postes').querySelector('.modal-title').textContent = 'Gracier un condamne';
  let html = '<div style="padding:1rem">';
  if (condamnes.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucun condamne actuellement en detention.</div>';
  } else {
    condamnes.forEach((p, i) => {
      html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;display:flex;justify-content:space-between;align-items:center">';
      html += '<div><div style="font-family:Playfair Display,serif;font-size:.85rem;color:#c0b090">' + p.nom + '</div>';
      html += '<div style="font-size:.7rem;color:#5a4030">' + p.raison + ' · liberation prevue Jour ' + p.jourFin + '</div></div>';
      html += '<button onclick="confirmerGrace(' + i + ')" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;padding:.25rem .6rem;border:1px solid #4a8a4a;background:transparent;color:#4a8a4a;cursor:pointer">Gracier</button>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerGrace(idx) {
  const condamnes = state.prisonniers?.filter(p => p.jourFin > state.day) || [];
  const condamne = condamnes[idx];
  if (!condamne) return;
  condamne.jourFin = state.day; // Liberation immediate
  document.getElementById('modal-postes').classList.remove('open');
  const popBonus = state.pop > 50 ? 5 : -2;
  state.pop = Math.min(100, state.pop + popBonus);
  updateUI();
  showToast('Grace accordee', condamne.nom + ' est libere(e). ' + (popBonus > 0 ? '+' : '') + popBonus + ' POP.', true);
  addExternalEvent('GRACE PRESIDENTIELLE : ' + condamne.nom + ' a ete gracie(e) par le President.');
}

function ouvrirForumPresidentCentral(type) {
  // Ouvre le forum presidentiel en vue centrale
  document.querySelectorAll('.vue').forEach(v => v.classList.remove('active'));
  document.getElementById('vue-mail').classList.add('active'); // Reutilise la vue mail
  document.getElementById('mail-view-subtitle').textContent = 'Forum Presidentiel';
  document.getElementById('mail-compose').style.display = 'none';

  const titres = {
    'referendum': 'Creer un Referendum',
    'deuil': 'Decret de Deuil National',
    'forum_president_conference': 'Conference de Presse',
    'forum_president_annonce': 'Annonce Officielle',
    'forum_president_propagande': "Propagande d'Etat",
    'forum_president_dementi': 'Dementi Officiel'
  };

  const titre = titres[type] || 'Forum Presidentiel';
  const content = document.getElementById('mail-content');

  let html = '<div style="padding:1.2rem;max-width:650px">';
  html += '<div style="font-family:Playfair Display,serif;font-size:1rem;color:#C9A84C;margin-bottom:1rem">' + titre + '</div>';

  if (type === 'referendum') {
    html += '<div style="margin-bottom:.8rem"><div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">QUESTION DU REFERENDUM</div>';
    html += '<input id="ref-question" type="text" placeholder="Quelle est la question soumise au vote ?" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.6rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.5rem"/></div>';
    html += '<div style="margin-bottom:.8rem"><div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">REPONSES POSSIBLES (1 seul choix)</div>';
    html += '<input id="ref-rep1" type="text" placeholder="Reponse 1 (ex: Oui)" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none;margin-bottom:.3rem"/>';
    html += '<input id="ref-rep2" type="text" placeholder="Reponse 2 (ex: Non)" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none;margin-bottom:.3rem"/>';
    html += '<input id="ref-rep3" type="text" placeholder="Reponse 3 (optionnel)" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none;margin-bottom:.5rem"/>';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">DUREE DU VOTE</div>';
    html += '<select id="ref-duree" style="background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none">';
    html += '<option value="3">3 jours</option><option value="5">5 jours</option><option value="7">7 jours</option></select></div>';
    html += '<button onclick="publierReferendum()" style="font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Publier le referendum</button>';
  } else {
    html += '<div style="margin-bottom:.8rem"><div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">TITRE</div>';
    html += '<input id="forum-pres-titre" type="text" placeholder="Titre de votre message..." style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.5rem"/></div>';
    html += '<div style="margin-bottom:.8rem"><div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">MESSAGE</div>';
    html += '<textarea id="forum-pres-message" rows="5" placeholder="Redigez votre message officiel..." style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;resize:none"></textarea></div>';
    html += '<button onclick="publierForumPresident(\'' + type + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Publier</button>';
  }

  html += '<button onclick="closeMailView()" style="margin-left:.5rem;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #3a2a10;background:transparent;color:#6a5a30;cursor:pointer">Annuler</button>';
  html += '</div>';
  content.innerHTML = html;
}

function publierReferendum() {
  const question = document.getElementById('ref-question')?.value?.trim();
  const rep1 = document.getElementById('ref-rep1')?.value?.trim();
  const rep2 = document.getElementById('ref-rep2')?.value?.trim();
  const rep3 = document.getElementById('ref-rep3')?.value?.trim();
  const duree = parseInt(document.getElementById('ref-duree')?.value || '5');
  if (!question || !rep1 || !rep2) { showToast('Champs requis', 'Question et au moins 2 reponses obligatoires.', false); return; }

  const reponses = [rep1, rep2, ...(rep3 ? [rep3] : [])].map(r => ({ label: r, voix: 0 }));
  if (!state.referendums) state.referendums = [];
  state.referendums.push({ question, reponses, jourFin: state.day + duree, clos: false, auteur: state.char?.name });

  // Publier dans le forum presidentiel
  if (!FORUM_TOPICS['national']) FORUM_TOPICS['national'] = [];
  FORUM_TOPICS['national'].unshift({
    id: 'ref-' + Date.now(), title: '[REFERENDUM] ' + question,
    author: state.char?.name || 'President',
    time: 'Jour ' + state.day, views: 0, replies: 0,
    isReferendum: true, reponses,
    posts: [{ author: state.char?.name, time: 'Jour ' + state.day, content: 'Le President soumet ce referendum au vote populaire. Vote ouvert pendant ' + duree + ' jours.' }]
  });

  state.pop = Math.min(100, state.pop + 8);
  updateUI();
  closeMailView();
  showToast('Referendum publie !', question + ' — Vote ouvert ' + duree + ' jours. +8 POP.', true, true);
  addExternalEvent('REFERENDUM : Le President soumet au vote : "' + question + '"');
}

function publierForumPresident(type) {
  const titre = document.getElementById('forum-pres-titre')?.value?.trim();
  const message = document.getElementById('forum-pres-message')?.value?.trim();
  if (!titre || !message) { showToast('Champs requis', 'Titre et message obligatoires.', false); return; }

  if (!FORUM_TOPICS['national']) FORUM_TOPICS['national'] = [];
  FORUM_TOPICS['national'].unshift({
    id: 'pres-' + Date.now(), title: '[PRESIDENCE] ' + titre,
    author: state.char?.name || 'President',
    time: 'Jour ' + state.day, views: 0, replies: 0,
    posts: [{ author: state.char?.name, time: 'Jour ' + state.day, content: message }]
  });

  const effets = {
    'forum_president_conference': { pop: 15, inf: 10 },
    'forum_president_annonce':    { pop: 5,  inf: 5  },
    'forum_president_propagande': { pop: 20, inf: 0  },
    'forum_president_dementi':    { pop: 8,  inf: 3  }
  };
  const ef = effets[type] || {};
  if (ef.pop) state.pop = Math.min(100, state.pop + ef.pop);
  if (ef.inf) state.inf = Math.min(100, state.inf + ef.inf);
  if (type === 'jour_deuil') {
    // Pas d'impots ce jour
    state.deuil = state.day;
    addExternalEvent('DEUIL NATIONAL : Journee chommee declaree par le President. Pas de recettes fiscales aujourd\'hui.');
  }
  updateUI();
  closeMailView();
  showToast('Publie !', titre + (ef.pop ? ' +' + ef.pop + ' POP' : '') + (ef.inf ? ' +' + ef.inf + ' INF' : ''), true, true);
  addJournalEntry('Publication presidentielle : ' + titre, 'event-good');
}

function ouvrirModalNationaliser() {
  const entreprises = ENTREPRISES_PRIVEES[state.country] || [];
  document.getElementById('modal-postes').querySelector('.modal-title').textContent = 'Nationaliser une entreprise';
  let html = '<div style="padding:1rem">';
  if (entreprises.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucune entreprise privee recensee pour le moment. Les entreprises achetees par des PJ apparaitront ici.</div>';
  } else {
    entreprises.forEach((e, i) => {
      html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;display:flex;justify-content:space-between;align-items:center">';
      html += '<div style="font-size:.85rem;color:#c0b090">' + e.nom + ' <span style="font-size:.68rem;color:#5a4030">(propriete : ' + (e.proprio||'inconnu') + ')</span></div>';
      html += '<button onclick="confirmerNationalisation(' + i + ')" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;padding:.25rem .6rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">Nationaliser</button>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerNationalisation(idx) {
  const e = ENTREPRISES_PRIVEES[state.country]?.[idx];
  if (!e) return;
  e.nationalise = true;
  document.getElementById('modal-postes').classList.remove('open');
  INDICES_NATIONAUX[state.country].IE = Math.min(100, INDICES_NATIONAUX[state.country].IE + 5);
  showToast('Nationalisation', e.nom + ' est desormais propriete de l\'Etat. +5 IE.', true);
  addExternalEvent('NATIONALISATION : ' + e.nom + ' placee sous controle de l\'Etat par decret presidentiel.');
}

function ouvrirModalCibleRepertoire(action, titre) {
  const contacts = state.contacts || [];
  document.getElementById('modal-postes').querySelector('.modal-title').textContent = titre;
  let html = '<div style="padding:1rem">';
  if (contacts.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Votre repertoire est vide. Enregistrez des contacts pour cibler des personnes.</div>';
  } else {
    html += '<div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Choisir la cible :</div>';
    contacts.forEach((c, i) => {
      html += '<div onclick="executerOrdreContact(\'' + action + '\',\'' + c.name + '\')" style="padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.3rem;cursor:pointer;transition:background .2s" onmouseover="this.style.background=\'#151005\'" onmouseout="this.style.background=\'#0f0d05\'">';
      html += '<div style="font-family:Playfair Display,serif;font-size:.82rem;color:#c0b090">' + c.name + '</div>';
      html += '<div style="font-size:.68rem;color:#5a4030">' + (c.role||'') + '</div></div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function executerOrdreContact(action, nomCible) {
  document.getElementById('modal-postes').classList.remove('open');
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  if (action === 'nommer_pm_confirm') {
    addMailNotification('Presidence de la Republique', 'Nomination au poste de Premier Ministre',
      'Par decision presidentielle, vous etes nomme(e) Premier Ministre. Prenez vos fonctions immediatement au Palais du Gouvernement.');
    addExternalEvent('NOMINATION : ' + nomCible + ' est nomme(e) Premier Ministre par le President.');
    showToast('PM nomme', nomCible + ' est le nouveau Premier Ministre.', true, true);
  } else if (action === 'redressement_fiscal') {
    const montant = 2000;
    state.arg += montant;
    INDICES_NATIONAUX[state.country].IE = Math.max(0, INDICES_NATIONAUX[state.country].IE - 3);
    updateUI();
    showToast('Redressement', 'Redressement fiscal contre ' + nomCible + '. +' + montant + ' ' + cur + ' -3 IE.', true);
    addJournalEntry('Redressement fiscal contre ' + nomCible, 'event-info');
    addMailNotification('Ministere des Finances', 'Notification de redressement', 'Un redressement fiscal vous a ete notifie par le Ministre des Finances.');
  } else if (action === 'subvention') {
    const montant = 500;
    if (state.arg < montant) { showToast('Fonds insuffisants', '', false); return; }
    state.arg -= montant;
    INDICES_NATIONAUX[state.country].IS = Math.min(100, INDICES_NATIONAUX[state.country].IS + 3);
    updateUI();
    showToast('Subvention accordee', 'Subvention de ' + montant + ' ' + cur + ' versee a ' + nomCible + '. +3 IS.', true);
  } else if (action === 'ouvrir_enquete') {
    const budget = getBudgetInstitution('tribunal');
    if (!depenseBudget('tribunal', 600)) return;
    if (!state.enquetesEnCours) state.enquetesEnCours = [];
    state.enquetesEnCours.push({ cible: nomCible, day: state.day + 1, status: 'pending', initiateur: 'Ministre Justice' });
    showToast('Enquete ouverte', 'Enquete judiciaire lancee contre ' + nomCible + '. Resultat dans 24h.', true);
    addJournalEntry('Enquete judiciaire ouverte contre ' + nomCible, 'event-info');
  } else {
    showToast(action.replace(/_/g,' '), 'Action menee sur ' + nomCible, true);
    addJournalEntry(action.replace(/_/g,' ') + ' : ' + nomCible, 'event-info');
  }
}

function ouvrirModalTexteLibre(action, titre, placeholder) {
  document.getElementById('modal-postes').querySelector('.modal-title').textContent = titre;
  let html = '<div style="padding:1rem">';
  html += '<textarea id="texte-libre-input" rows="4" placeholder="' + placeholder + '" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.6rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;resize:none;margin-bottom:.7rem"></textarea>';
  html += '<button onclick="executerOrdreTexte(\'' + action + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Valider</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function executerOrdreTexte(action) {
  const texte = document.getElementById('texte-libre-input')?.value?.trim();
  if (!texte) { showToast('Champ requis', 'Veuillez remplir le champ.', false); return; }
  document.getElementById('modal-postes').classList.remove('open');
  if (action === 'interdire_manif') {
    INDICES_NATIONAUX[state.country].ISN = Math.min(100, INDICES_NATIONAUX[state.country].ISN + 5);
    state.pop = Math.max(0, state.pop - 5);
    updateUI();
    showToast('Manifestation interdite', texte + ' — +5 ISN -5 POP.', true);
    addExternalEvent('INTERDICTION : La manifestation "' + texte + '" a ete interdite par le Ministre de l\'Interieur.');
  } else if (action === 'reprimer_manif') {
    INDICES_NATIONAUX[state.country].ISN = Math.min(100, INDICES_NATIONAUX[state.country].ISN + 10);
    state.pop = Math.max(0, state.pop - 15);
    updateUI();
    showToast('Repression ordonnee', texte + ' — +10 ISN -15 POP.', false);
    addExternalEvent('REPRESSION : Ordre de dispersion force pour "' + texte + '".');
  } else if (action === 'commanditer_sondage') {
    state.inf = Math.min(100, state.inf + 5);
    updateUI();
    showToast('Sondage publie', '"' + texte + '" publie dans le forum national. +5 INF.', true);
  } else {
    showToast(action, texte, true);
    addJournalEntry(action + ' : ' + texte, 'event-info');
  }
}

function ouvrirModalSecteur() {
  document.getElementById('modal-postes').querySelector('.modal-title').textContent = 'Allegement fiscal sectoriel';
  let html = '<div style="padding:1rem"><div style="font-size:.82rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Choisir le secteur beneficiaire :</div>';
  SECTEURS.forEach(s => {
    html += '<button onclick="appliquerAllegement(\'' + s + '\')" style="display:block;width:100%;text-align:left;padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;color:#c0b090;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem;margin-bottom:.3rem">' + s + '</button>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function appliquerAllegement(secteur) {
  document.getElementById('modal-postes').classList.remove('open');
  INDICES_NATIONAUX[state.country].IE = Math.min(100, INDICES_NATIONAUX[state.country].IE + 5);
  state.inf = Math.min(100, state.inf + 8);
  updateUI();
  showToast('Allegement accorde', secteur + ' : -taxes +5 IE +8 INF.', true);
  addJournalEntry('Allegement fiscal accorde au secteur : ' + secteur, 'event-info');
}

function ouvrirModalAffaires(mode) {
  const affaires = state.plaintesEnCours?.filter(p => p.status === 'pending') || [];
  const condamnes = state.prisonniers?.filter(p => p.jourFin > state.day) || [];
  const titre = mode === 'annuler' ? 'Annuler des poursuites' : 'Gestion judiciaire';
  document.getElementById('modal-postes').querySelector('.modal-title').textContent = titre;
  let html = '<div style="padding:1rem">';
  const liste = mode === 'annuler' ? affaires : condamnes;
  if (liste.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucune affaire en cours.</div>';
  } else {
    liste.forEach((a, i) => {
      html += '<div style="padding:.5rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;display:flex;justify-content:space-between;align-items:center">';
      html += '<div style="font-size:.82rem;color:#c0b090">' + (a.cible||a.nom||'Inconnu') + ' <span style="font-size:.68rem;color:#5a4030">— ' + (a.motif||a.raison||'') + '</span></div>';
      html += '<button onclick="annulerAffaire(' + i + ',\'' + mode + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.65rem;padding:.2rem .5rem;border:1px solid #8a3020;background:transparent;color:#cc4a3a;cursor:pointer">Annuler</button>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function annulerAffaire(idx, mode) {
  document.getElementById('modal-postes').classList.remove('open');
  if (mode === 'annuler' && state.plaintesEnCours?.[idx]) {
    state.plaintesEnCours[idx].status = 'annulee';
    showToast('Poursuites annulees', 'La procedure a ete classee.', false);
    addJournalEntry('Annulation de poursuites par le Ministre de la Justice.', 'event-info');
  }
}

function ouvrirModalNommerJuge() {
  const contacts = state.contacts || [];
  const tribunaux = ['Tribunal de Luthecia', 'Tribunal de Port-Sainte-Marie', 'Tribunal de Montrouge'];
  document.getElementById('modal-postes').querySelector('.modal-title').textContent = 'Nommer un juge';
  let html = '<div style="padding:1rem">';
  if (contacts.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Repertoire vide. Enregistrez des contacts.</div>';
  } else {
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">PJ A NOMMER</div>';
    html += '<select id="juge-contact" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.7rem">';
    contacts.forEach(c => { html += '<option value="' + c.name + '">' + c.name + '</option>'; });
    html += '</select>';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">TRIBUNAL</div>';
    html += '<select id="juge-tribunal" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.7rem">';
    tribunaux.forEach(t => { html += '<option value="' + t + '">' + t + '</option>'; });
    html += '</select>';
    html += '<button onclick="confirmerNommerJuge()" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Nommer</button>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerNommerJuge() {
  const contact = document.getElementById('juge-contact')?.value;
  const tribunal = document.getElementById('juge-tribunal')?.value;
  document.getElementById('modal-postes').classList.remove('open');
  addMailNotification('Ministere de la Justice', 'Nomination au poste de juge', 'Vous avez ete nomme(e) juge au ' + tribunal + ' par le Ministre de la Justice.');
  addExternalEvent('NOMINATION : ' + contact + ' nomme(e) juge au ' + tribunal + '.');
  showToast('Juge nomme', contact + ' au ' + tribunal, true);
}

function ouvrirModalRenseignement() {
  const contacts = state.contacts || [];
  const empires = Object.entries(COUNTRIES).filter(([k]) => k !== state.country);
  document.getElementById('modal-postes').querySelector('.modal-title').textContent = 'Operation de renseignement';
  let html = '<div style="padding:1rem"><div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Cible : PJ suspect ou empire etranger ?</div>';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">EMPIRES</div>';
  empires.forEach(([k, co]) => {
    html += '<button onclick="executerOrdreEmpire(\'renseignement\',\'' + k + '\',\'' + co.n + '\')" style="display:flex;align-items:center;gap:.5rem;width:100%;padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;color:#c0b090;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem;margin-bottom:.3rem"><i class="ti ' + co.icon + '" style="color:' + co.col + '"></i> ' + co.n + '</button>';
  });
  if (contacts.length > 0) {
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin:.7rem 0 .4rem">PJ SUSPECTS (repertoire)</div>';
    contacts.forEach(c => {
      html += '<button onclick="executerOrdreContact(\'renseignement_pj\',\'' + c.name + '\')" style="display:block;width:100%;text-align:left;padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;color:#c0b090;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem;margin-bottom:.3rem">' + c.name + '</button>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function ouvrirModalMedia() {
  const medias = MEDIAS[state.country] || [];
  document.getElementById('modal-postes').querySelector('.modal-title').textContent = 'Censurer un media';
  let html = '<div style="padding:1rem"><div style="font-size:.8rem;color:#cc4444;font-style:italic;margin-bottom:.8rem">Attention : la censure peut provoquer un scandale si elle est decouverte.</div>';
  medias.forEach((m, i) => {
    html += '<button onclick="censurer(\'' + m + '\')" style="display:block;width:100%;text-align:left;padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;color:#c0b090;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem;margin-bottom:.3rem">' + m + '</button>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function censurer(media) {
  document.getElementById('modal-postes').classList.remove('open');
  INDICES_NATIONAUX[state.country].IS = Math.max(0, INDICES_NATIONAUX[state.country].IS - 8);
  const roll = Math.floor(Math.random() * 100) + 1;
  if (roll <= 30) {
    addExternalEvent('SCANDALE : La censure de ' + media + ' a ete revelee ! -20 POP.');
    state.pop = Math.max(0, state.pop - 20);
    updateUI();
  } else {
    showToast('Media censure', media + ' suspendu. -8 IS.', false);
    addJournalEntry('Censure de ' + media, 'event-bad');
  }
}

function ouvrirModalTraite() {
  const empires = Object.entries(COUNTRIES).filter(([k]) => k !== state.country);
  const types = ['Commercial', 'De paix', "D'alliance militaire", 'Non-agression', 'Culturel'];
  document.getElementById('modal-postes').querySelector('.modal-title').textContent = 'Signer un traite';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">EMPIRE</div>';
  html += '<select id="traite-empire" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.7rem">';
  empires.forEach(([k, co]) => { html += '<option value="' + k + '">' + co.n + '</option>'; });
  html += '</select>';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">TYPE DE TRAITE</div>';
  html += '<select id="traite-type" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.7rem">';
  types.forEach(t => { html += '<option value="' + t + '">' + t + '</option>'; });
  html += '</select>';
  html += '<button onclick="signerTraite()" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Signer</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function signerTraite() {
  const empireId = document.getElementById('traite-empire')?.value;
  const type = document.getElementById('traite-type')?.value;
  document.getElementById('modal-postes').classList.remove('open');
  const empireName = COUNTRIES[empireId]?.n || empireId;
  INDICES_NATIONAUX[state.country].ID = Math.min(100, INDICES_NATIONAUX[state.country].ID + 12);
  if (!state.traites) state.traites = [];
  state.traites.push({ empire: empireId, type, jour: state.day });
  showToast('Traite signe', 'Traite ' + type + ' avec ' + empireName + '. +12 ID.', true, true);
  addExternalEvent('TRAITE : Accord ' + type + ' signe entre ' + (COUNTRIES[state.country]?.n||'') + ' et ' + empireName + '.');
}

function ouvrirModalNommerAmbassadeur() {
  const contacts = state.contacts || [];
  const empires = Object.entries(COUNTRIES).filter(([k]) => k !== state.country);
  document.getElementById('modal-postes').querySelector('.modal-title').textContent = 'Nommer un ambassadeur';
  let html = '<div style="padding:1rem">';
  if (contacts.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Repertoire vide.</div>';
  } else {
    html += '<select id="amb-contact" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;margin-bottom:.7rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none">';
    contacts.forEach(c => { html += '<option value="' + c.name + '">' + c.name + '</option>'; });
    html += '</select>';
    html += '<select id="amb-empire" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;margin-bottom:.7rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none">';
    empires.forEach(([k,co]) => { html += '<option value="' + k + '">' + co.n + '</option>'; });
    html += '</select>';
    html += '<button onclick="confirmerAmbassadeur()" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Nommer</button>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerAmbassadeur() {
  const contact = document.getElementById('amb-contact')?.value;
  const empireId = document.getElementById('amb-empire')?.value;
  document.getElementById('modal-postes').classList.remove('open');
  const empireName = COUNTRIES[empireId]?.n || empireId;
  addMailNotification('Ministere des AE', 'Nomination comme ambassadeur', 'Vous avez ete nomme(e) ambassadeur(rice) aupres de ' + empireName + ' par le Ministre des Affaires Etrangeres.');
  addExternalEvent('NOMINATION : ' + contact + ' nomme(e) ambassadeur(rice) aupres de ' + empireName + '.');
  showToast('Ambassadeur nomme', contact + ' → ' + empireName, true);
}

function doReceptionAvecBonus(fn, cost) {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  if (state.arg < cost) { showToast('Fonds insuffisants', 'Il vous faut ' + cost + ' ' + cur, false); return; }

  // Bonus/malus selon popularite
  const popBonus = state.pop > 20 ? Math.floor((state.pop - 20) * 1) : -Math.floor((20 - state.pop) * 1);
  const taux = Math.min(95, Math.max(5, 80 + Math.floor(popBonus / 2)));
  const roll = Math.floor(Math.random() * 100) + 1;

  state.arg -= cost;
  updateUI();

  if (roll <= taux) {
    state.pop = Math.min(100, state.pop + 10);
    state.inf = Math.min(100, state.inf + 8);
    state.moral = Math.min(100, state.moral + 5);
    INDICES_NATIONAUX[state.country].ID = Math.min(100, INDICES_NATIONAUX[state.country].ID + 5);
    updateUI();
    showToast(fn === 'reception_etat' ? 'Reception reussie !' : 'Banquet reussi !', '+10 POP +8 INF +5 Moral +5 ID.', true, true);
    addJournalEntry(fn === 'reception_etat' ? 'Reception d\'Etat reussie.' : 'Banquet diplomatique reussi.', 'event-good');
  } else {
    state.pop = Math.max(0, state.pop - 30);
    state.inf = Math.max(0, state.inf - 30);
    state.moral = Math.max(0, state.moral - 10);
    updateUI();
    showToast('Echec !', 'Les invites ont boude votre ' + (fn === 'reception_etat' ? 'reception' : 'banquet') + '. -30 POP -30 INF -10 Moral.', false);
    addExternalEvent('HUMILIATION : La ' + (fn === 'reception_etat' ? 'reception' : 'banquet diplomatique') + ' du President s\'est soldee par un echec cuisant. -30 POP -30 INF -10 Moral.');
  }
}

function ouvrirNommerMinistresModal() {
  const contacts = state.contacts || [];
  const postesMinisteriels = [
    { id:'min_int', name:"Ministre de l'Interieur" },
    { id:'min_fin', name:'Ministre des Finances' },
    { id:'min_just', name:'Ministre de la Justice' },
    { id:'min_def', name:'Ministre de la Defense' },
    { id:'min_info', name:"Ministre de l'Information" },
    { id:'min_ae', name:'Ministre des AE' }
  ];
  if (state.postesCustom?.ministre) postesMinisteriels.push({ id:'custom_ministre', name:state.postesCustom.ministre.nom });
  if (state.postesCustom?.comite) postesMinisteriels.push({ id:'custom_comite', name:state.postesCustom.comite.nom });

  document.getElementById('modal-postes').querySelector('.modal-title').textContent = 'Nommer des ministres';
  let html = '<div style="padding:1rem">';
  if (contacts.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Repertoire vide. Enregistrez des contacts PJ.</div>';
  } else {
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">POSTE</div>';
    html += '<select id="nommer-min-poste" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.7rem">';
    postesMinisteriels.forEach(p => { html += '<option value="' + p.id + '">' + p.name + '</option>'; });
    html += '</select>';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">PJ A NOMMER</div>';
    html += '<select id="nommer-min-contact" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.8rem">';
    contacts.forEach(c => { html += '<option value="' + c.name + '">' + c.name + '</option>'; });
    html += '</select>';
    html += '<button onclick="validerNominationMinistre()" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Envoyer la nomination</button>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function validerNominationMinistre() {
  const posteId = document.getElementById('nommer-min-poste')?.value;
  const contact = document.getElementById('nommer-min-contact')?.value;
  const postesNoms = { min_int:"Ministre de l'Interieur", min_fin:'Ministre des Finances', min_just:'Ministre de la Justice', min_def:'Ministre de la Defense', min_info:"Ministre de l'Information", min_ae:'Ministre des AE' };
  const posteNom = postesNoms[posteId] || (state.postesCustom?.ministre?.nom) || (state.postesCustom?.comite?.nom) || posteId;
  document.getElementById('modal-postes').classList.remove('open');
  addMailNotification('Premier Ministre', 'Nomination ministerielle', 'Par decision du Premier Ministre, vous etes nomme(e) ' + posteNom + '. Prenez vos fonctions immediatement.');
  addExternalEvent('NOMINATION : ' + contact + ' est nomme(e) ' + posteNom + ' par le Premier Ministre.');
  showToast('Nomination envoyee', contact + ' → ' + posteNom, true, true);
}

// Appliquer malus ISN aux actes illegaux
function getMalusISN() {
  const isn = INDICES_NATIONAUX[state.country]?.ISN || 30;
  if (isn <= 20) return 0;
  if (isn <= 40) return 5;
  if (isn <= 60) return 10;
  if (isn <= 80) return 15;
  return 25;
}

function creerPosteMinistre() {
  if (!state.postesCustom) state.postesCustom = { ministre: null, comite: null };
  if (state.postesCustom.ministre) {
    showToast('Limite atteinte', 'Vous avez deja cree un poste ministeriel custom. Supprimez-le d\'abord.', false);
    return;
  }
  document.getElementById('modal-postes').querySelector('.modal-title').textContent = 'Creer un poste ministeriel';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem">' +
    '<div style="font-size:.82rem;color:#8a8060;font-style:italic;margin-bottom:1rem">Vous pouvez creer 1 poste ministeriel et 1 comite. Salaire aligne sur les ministres (2800 FR/jour).</div>' +
    '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">INTITULE DU POSTE</div>' +
    '<input id="custom-poste-nom" type="text" placeholder="Ex: Ministre de la Transition Numerique" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.6rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.8rem"/>' +
    '<button onclick="validerCreationPoste(\'ministre\')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Creer ce poste</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

function creerComite() {
  if (!state.postesCustom) state.postesCustom = { ministre: null, comite: null };
  if (state.postesCustom.comite) {
    showToast('Limite atteinte', 'Vous avez deja cree un comite. Supprimez-le d\'abord.', false);
    return;
  }
  document.getElementById('modal-postes').querySelector('.modal-title').textContent = 'Creer un comite';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem">' +
    '<div style="font-size:.82rem;color:#8a8060;font-style:italic;margin-bottom:1rem">Comite presidentiel special. Salaire aligne sur les ministres.</div>' +
    '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">INTITULE DU COMITE</div>' +
    '<input id="custom-poste-nom" type="text" placeholder="Ex: Comite pour la Modernisation de l\'Etat" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.6rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.8rem"/>' +
    '<button onclick="validerCreationPoste(\'comite\')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Creer ce comite</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

function validerCreationPoste(type) {
  const nom = document.getElementById('custom-poste-nom')?.value?.trim();
  if (!nom) { showToast('Nom requis', 'Donnez un nom a ce poste.', false); return; }
  if (!state.postesCustom) state.postesCustom = { ministre: null, comite: null };
  state.postesCustom[type] = { nom, salaire: 2800, createur: state.char?.name, jour: state.day };
  document.getElementById('modal-postes').classList.remove('open');
  showToast('Poste cree !', '"' + nom + '" a ete cree. Nommez quelqu\'un depuis votre bureau.', true, true);
  addJournalEntry('Nouveau poste cree par decret presidentiel : ' + nom, 'event-good');
  addExternalEvent('Le President a cree le poste de "' + nom + '" par decret.');
}

function supprimerPosteCustom() {
  if (!state.postesCustom || (!state.postesCustom.ministre && !state.postesCustom.comite)) {
    showToast('Aucun poste custom', 'Vous n\'avez pas cree de poste ou comite a supprimer.', false);
    return;
  }
  document.getElementById('modal-postes').querySelector('.modal-title').textContent = 'Supprimer un poste';
  let html = '<div style="padding:1rem">';
  if (state.postesCustom.ministre) {
    html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.5rem;display:flex;justify-content:space-between;align-items:center">';
    html += '<div style="font-size:.85rem;color:#c0b090">' + state.postesCustom.ministre.nom + '</div>';
    html += '<button onclick="confirmerSupprPoste(\'ministre\')" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;padding:.25rem .6rem;border:1px solid #8a2020;background:transparent;color:#cc4444;cursor:pointer">Supprimer</button>';
    html += '</div>';
  }
  if (state.postesCustom.comite) {
    html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.5rem;display:flex;justify-content:space-between;align-items:center">';
    html += '<div style="font-size:.85rem;color:#c0b090">' + state.postesCustom.comite.nom + '</div>';
    html += '<button onclick="confirmerSupprPoste(\'comite\')" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;padding:.25rem .6rem;border:1px solid #8a2020;background:transparent;color:#cc4444;cursor:pointer">Supprimer</button>';
    html += '</div>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerSupprPoste(type) {
  const nom = state.postesCustom[type]?.nom || '';
  state.postesCustom[type] = null;
  document.getElementById('modal-postes').classList.remove('open');
  showToast('Poste supprime', '"' + nom + '" a ete supprime.', false);
  addJournalEntry('Poste supprime par decret : ' + nom, '');
}

// =====================
// FORUM
// =====================
// Forum gere par forum.js

// openForum delegue a forum.js
// Forum gere par forum.js — voir openForum() dans forum.js

// =====================
// INVENTORY
// =====================
function addToInventory(item) {
  state.inventory.push(item);
  renderInventory();
}
function renderInventory() {
  const el = document.getElementById('inv-items');
  if (!el) return;
  el.innerHTML = state.inventory.length === 0
    ? '<div class="inv-item-empty">Aucun objet</div>'
    : state.inventory.map(item => `
        <div class="inv-item">
          <i class="ti ${item.icon}" style="font-size:.8rem;color:#8a6a20"></i> ${item.name}
        </div>`).join('');
}
function toggleInventaire() {
  const panel = document.getElementById('inventaire-panel');
  const chevron = document.getElementById('inv-chevron');
  if (panel.style.display === 'none') {
    panel.style.display = 'block';
    chevron.className = 'ti ti-chevron-down';
  } else {
    panel.style.display = 'none';
    chevron.className = 'ti ti-chevron-right';
  }
}

// =====================
// UI UPDATE
// =====================
function updateUI() {
  const cur = state.char ? (COUNTRIES[state.char.country]?.cur || 'FR') : 'FR';
  document.getElementById('r-pa').textContent   = TEST_MODE ? '∞' : state.pa;
  document.getElementById('b-pa').style.width   = TEST_MODE ? '100%' : (state.pa / state.paMax * 100) + '%';
  document.getElementById('r-arg').textContent  = state.arg.toLocaleString('fr-FR') + ' ' + cur;
  document.getElementById('r-inf').textContent  = state.inf;
  document.getElementById('b-inf').style.width  = state.inf + '%';
  document.getElementById('r-pop').textContent  = state.pop;
  document.getElementById('b-pop').style.width  = state.pop + '%';
  document.getElementById('r-dis').textContent  = state.dis;
  document.getElementById('b-dis').style.width  = state.dis + '%';
  document.getElementById('r-hp').textContent   = state.hp;
  document.getElementById('b-hp').style.width   = state.hp + '%';
  document.getElementById('r-moral').textContent = state.moral;
  document.getElementById('b-moral').style.width  = state.moral + '%';

  // Badge mail
  const unread = (state.mails || []).filter(m => !m.read).length;
  const badge = document.getElementById('mail-badge');
  if (badge) {
    badge.textContent = unread;
    badge.style.display = unread > 0 ? 'inline' : 'none';
  }

  // Indices nationaux dans topbar
  const pays = state.country || 'republic';
  const idx = (typeof INDICES_NATIONAUX !== 'undefined') ? (INDICES_NATIONAUX[pays] || {ISN:30,IE:50,ID:40,IS:45}) : {ISN:30,IE:50,ID:40,IS:45};
  const setIdx = (id, val) => { const el = document.getElementById(id); if (el) el.textContent = val; };
  setIdx('idx-isn', idx.ISN);
  setIdx('idx-ie',  idx.IE);
  setIdx('idx-id',  idx.ID);
  setIdx('idx-is',  idx.IS);
  // Nom de l'empire
  const indicesBar = document.getElementById('indices-bar');
  if (indicesBar) {
    const nomSpan = indicesBar.querySelector('span');
    if (nomSpan) nomSpan.textContent = COUNTRIES[pays]?.n || 'Republia';
    indicesBar.title = 'Indices de ' + (COUNTRIES[pays]?.n || 'Republia') + ' — cliquer pour details';
  }

  // Inventaire
  document.getElementById('inv-liquide').textContent = state.liquide.toLocaleString('fr-FR') + ' ' + cur;
  document.getElementById('inv-banque').textContent  = state.banque.toLocaleString('fr-FR') + ' ' + cur;
}

function updateLocationDisplay() {
  const world = WORLD[state.country];
  const city = world?.[state.currentCity];
  const co = COUNTRIES[state.country];

  document.getElementById('loc-city').textContent = `${city?.name || ''}, ${co?.n || ''}`;

  if (!state.currentBuilding) {
    document.getElementById('loc-name').textContent = 'Dans la rue';
    document.getElementById('loc-sub').textContent = 'Selectionnez un batiment';
  }
}

// =====================
// TOAST & JOURNAL
// =====================
function showToast(result, msg, success, isCrit) {
  const t = document.getElementById('result-toast');
  t.className = isCrit ? 'toast-crit' : success ? 'toast-success' : 'toast-fail';
  document.getElementById('toast-result').textContent = result;
  document.getElementById('toast-sub').textContent = msg;
  t.style.display = 'block';
  clearTimeout(window._toastTimer);
  window._toastTimer = setTimeout(() => { t.style.display = 'none'; }, 3800);
}

function addJournalEntry(text, cls) {
  const j = document.getElementById('journal');
  const h = String(state.hour).padStart(2,'0');
  const div = document.createElement('div');
  div.className = 'journal-entry';
  div.innerHTML = `<span class="journal-time">Jour ${state.day} · ${h}h00</span>
    <span class="journal-text ${cls||''}">${text}</span>`;
  j.insertBefore(div, j.firstChild);
}

// Close modals on overlay click
document.querySelectorAll('.modal-overlay').forEach(m => {
  m.addEventListener('click', function(e) {
    if (e.target === this) this.classList.remove('open');
  });
});
