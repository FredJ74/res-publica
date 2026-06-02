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
  renderMinimap('capitale');
  updateUI();
  updateLocationDisplay();
  startClock();
  // Fix: afficher image de rue des le chargement
  setTimeout(() => showVueRue(), 100);
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

  // Ajouter le PJ lui-meme dans la liste
  const char = state.char;
  const ar = ARCHETYPES.find(x => x.id === char?.archetype);
  const selfCard = char ? `
    <div class="person-card" style="border-left:2px solid #C9A84C">
      <div class="person-avatar" style="border-color:#C9A84C">
        ${char.photoUrl ? `<img src="${char.photoUrl}" alt="Vous" style="width:100%;height:100%;object-fit:cover;border-radius:50%"/>` : `<i class="ti ti-user" style="font-size:.75rem;color:#C9A84C"></i>`}
      </div>
      <div>
        <div class="person-name" style="color:#C9A84C">${char.name} <span style="font-size:.6rem;color:#6a5a20">(Vous)</span></div>
        <div class="person-role">${state.poste?.name || ar?.name || 'Citoyen'}</div>
        <div class="person-rel rel-ally">Vous-meme</div>
      </div>
    </div>` : '';

  const personCards = persons.length === 0 ? '' : persons.map(p => {
    const avatarHtml = (typeof renderPnjAvatarHtml === 'function')
      ? renderPnjAvatarHtml(p, 28)
      : `<div class="person-avatar"><i class="ti ti-user" style="font-size:.75rem"></i></div>`;
    return `
      <div class="person-card" onclick="openPnjModal('${encodeURIComponent(JSON.stringify(p))}')">
        ${avatarHtml}
        <div>
          <div class="person-name">${p.name}</div>
          <div class="person-role">${p.role}</div>
          <div class="person-rel" style="color:${relCol(p.rel)};font-size:.58rem">${relTxt(p.rel)}</div>
        </div>
      </div>`;
  }).join('');

  document.getElementById('persons-list').innerHTML = selfCard + personCards ||
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

  // Ordres communs a tous les batiments
  const commonOrders = [
    {fn:'se_cacher',       label:'Se cacher',        pa:1, cost:0, type:'grey',    icon:'ti-eye-off', successRate:70,  desc:'Vous vous dissimulezdans la piece. Bonus actions illegales.'},
    {fn:'organiser_blocus',label:'Organiser blocus',  pa:3, cost:0, type:'illegal', icon:'ti-ban',     successRate:40,  desc:'Necessite un groupe. Bloque l acces au batiment.'},
    {fn:'incendier',       label:'Incendier',          pa:3, cost:0, type:'illegal', icon:'ti-flame',   successRate:30,  desc:'Declencher un incendie. Plus difficile si nombreux temoins.'}
  ];

  const allOrders = [...orders, ...commonOrders];

  const buttons = allOrders.map(o => {
    const needsPost = o.requiresPost && !state.poste;
    const paDisplay = TEST_MODE ? '0 PA' : o.pa + ' PA';
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
  if (fn === 'postuler') { openPostesModal(); return; }
  if (fn === 'gerer_finances') { openFinancesModal(); return; }
  if (fn === 'plainte_police') { openPlainteModal(); return; }
  if (fn === 'archives_police') { doArchivesPolice(); return; }
  if (fn === 'pouls_populaire') { doPoulsPopulaire(); return; }
  if (fn === 'lancer_rumeur_cible') { openRumeurModal(); return; }
  if (fn === 'distribuer_tract') { doDistribuerTract(); return; }
  if (fn === 'demander_parler_loge') { doLogePortail(); return; }
    if (fn === 'acheter_arme_legale') { doAcheterArme(true); return; }
  if (fn === 'acheter_arme_illegale') { doAcheterArme(false); return; }
  if (fn === 'consulter_registre_armes') { doConsulterRegistre(); return; }
  if (fn === 'marchander_vote') { openMarchanderVoteModal(); return; }
  if (fn === 'deposer_candidature') { openCandidatureModal(); return; }
  if (fn === 'consulter_elections') { openElectionsModal(); return; }

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
  if (election.candidats.includes(nom)) {
    showToast('Deja candidat', 'Vous etes deja candidat a cette election.', false);
    return;
  }
  election.candidats.push(nom);
  showToast('Candidature enregistree !', 'Vous etes officiellement candidat a ' + election.nom, true, true);
  addJournalEntry('Vous avez depose votre candidature pour : ' + election.nom, 'event-good');
}

function openElectionsModal() {
  document.getElementById('modal-postes').querySelector('.modal-title').textContent = 'Elections en cours';
  const elections = state.electionsEnCours || [];
  document.getElementById('postes-body').innerHTML = `
    <div style="padding:1rem">
      ${elections.length === 0
        ? `<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucune election en cours pour le moment.</div>`
        : elections.map(e => `
            <div style="padding:.7rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.5rem">
              <div style="font-family:'Playfair Display',serif;font-size:.9rem;color:#E8C97A">${e.nom}</div>
              <div style="font-size:.72rem;color:#6a5a30;margin:.2rem 0">Date limite : ${e.date}</div>
              <div style="font-size:.78rem;color:#8a8060">Candidats declares : ${e.candidats?.join(', ') || 'Aucun'}</div>
            </div>`).join('')}
    </div>`;
  document.getElementById('modal-postes').classList.add('open');
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
