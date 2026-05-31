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
  updateClock();
}
function updateClock() {
  const h = String(state.hour).padStart(2,'0');
  document.getElementById('game-time').textContent = `Jour ${state.day} · ${h}h00`;
}
function advanceTime(hours = 1) {
  state.hour += hours;
  if (state.hour >= 24) { state.hour = 0; state.day++; }
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

  document.getElementById('persons-list').innerHTML = persons.length === 0
    ? '<div class="person-empty">Personne ici</div>'
    : persons.map(p => `
        <div class="person-card" onclick="openPnjModal('${encodeURIComponent(JSON.stringify(p))}')">
          <div class="person-avatar"><i class="ti ti-user" style="font-size:.75rem"></i></div>
          <div>
            <div class="person-name">${p.name}</div>
            <div class="person-role">${p.role}</div>
            <div class="person-rel" style="color:${relCol(p.rel)};font-size:.58rem">${relTxt(p.rel)}</div>
          </div>
        </div>`).join('');
}

// =====================
// ROOM ACTIONS
// =====================
function renderRoomActions(room, buildingId, roomId) {
  const orders = room.orders || [];
  const cur = COUNTRIES[state.char?.country || 'republic']?.cur || 'FR';

  document.getElementById('action-context-bat').textContent =
    `${room.name.toUpperCase()} — ACTIONS DISPONIBLES`;

  document.getElementById('actions-row-bat').innerHTML = orders.map(o => {
    const needsPost = o.requiresPost && !state.poste;
    const paDisplay = TEST_MODE ? '0 PA' : `${o.pa} PA`;
    const costDisplay = o.cost > 0 ? `${o.cost} ${cur}` : 'gratuit';

    return `<button class="action-btn ${o.type} ${needsPost ? 'blocked' : ''}"
      onclick="${needsPost ? `showPostRequired()` : `doOrder('${o.fn}',${o.pa},${o.cost},'${o.label}','${(o.desc||'').replace(/'/g,"\\'")}',${o.successRate||70})`}"
      title="${needsPost ? 'Poste requis' : (o.desc||'')}">
      <i class="ti ${o.icon}" style="font-size:.82rem"></i> ${o.label}
      <span class="pa-cost">${costDisplay} · ${paDisplay}</span>
    </button>`;
  }).join('') || '<div style="font-size:.75rem;color:#3a3020;font-style:italic;padding:.3rem">Aucune action disponible ici.</div>';
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
  if (fn === 'parler_pnj') { return; } // Gere par click sur person card

  // Deduire PA et argent
  if (!TEST_MODE) state.pa = Math.max(0, state.pa - pa);
  if (cost > 0) state.arg = Math.max(0, state.arg - cost);

  // Roll
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

  // PA bonus (dormir en hotel)
  if (fn === 'dormir' && ef.paBonus && resultType !== 'fail') {
    // Note pour le prochain jour
    state.paBonus = ef.paBonus || 0;
    addJournalEntry(`Nuit confortable. +${ef.paBonus} PA bonus demain.`, 'event-good');
  }

  // Effets speciaux
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

  document.getElementById('modal-pnj').classList.add('open');
  document.getElementById('pnj-modal-title').textContent = pnj.name;

  const speech = document.getElementById('pnj-speech');
  speech.innerHTML = '<div class="pnj-loading"><span class="spin"></span> En train de repondre...</div>';

  // Actions selon relation
  const relTxt = pnj.rel === 'ally' ? 'Allie' : pnj.rel === 'enemy' ? 'Hostile' : 'Neutre';
  document.getElementById('pnj-actions').innerHTML = `
    <button class="pnj-action-btn" onclick="talkToPnj('${encodeURIComponent(JSON.stringify(pnj))}','bonjour')">
      <i class="ti ti-message" style="font-size:.85rem"></i> Engager la conversation
    </button>
    <button class="pnj-action-btn" onclick="talkToPnj('${encodeURIComponent(JSON.stringify(pnj))}','information')">
      <i class="ti ti-info-circle" style="font-size:.85rem"></i> Demander des informations
    </button>
    ${pnj.rel !== 'enemy' ? `<button class="pnj-action-btn" onclick="talkToPnj('${encodeURIComponent(JSON.stringify(pnj))}','alliance')">
      <i class="ti ti-handshake" style="font-size:.85rem"></i> Proposer une alliance
    </button>` : `<button class="pnj-action-btn" onclick="talkToPnj('${encodeURIComponent(JSON.stringify(pnj))}','confrontation')">
      <i class="ti ti-sword" style="font-size:.85rem"></i> Confronter
    </button>`}
  `;

  // Message d'accueil par defaut
  talkToPnj(encodedPnj, 'bonjour');
}

async function talkToPnj(encodedPnj, action) {
  let pnj;
  try { pnj = JSON.parse(decodeURIComponent(encodedPnj)); }
  catch(e) { return; }

  const speech = document.getElementById('pnj-speech');
  speech.innerHTML = '<div class="pnj-loading"><span class="spin"></span> En train de repondre...</div>';

  const char = state.char;
  const ar = ARCHETYPES.find(x => x.id === char?.archetype);
  const co = COUNTRIES[state.country];
  const actionDesc = {
    'bonjour': 'salue ce personnage',
    'information': 'demande des informations sur la situation politique',
    'alliance': 'propose une alliance politique',
    'confrontation': 'confronte ce personnage directement'
  }[action] || action;

  const prompt = `Tu es un personnage dans un jeu de role politique parodique appele "Res Publica". Tu joues le role de : ${pnj.name}, ${pnj.role}, dans le pays fictif "${co?.n}". Ta relation avec le joueur est : ${pnj.rel === 'ally' ? 'allie' : pnj.rel === 'enemy' ? 'hostile' : 'neutre'}. Le joueur se nomme ${char?.name || 'Inconnu'} et est un ${ar?.name || 'personnage'}. Le joueur te ${actionDesc}. Reponds en 2-3 phrases maximum, de facon coherente avec ton role et ta relation, avec un ton satirique et politique. Sois precis et caracteriel. Reponds uniquement avec ta replique, sans guillemets ni introduction.`;

  try {
    const resp = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: 'claude-sonnet-4-20250514',
        max_tokens: 300,
        messages: [{ role: 'user', content: prompt }]
      })
    });
    const data = await resp.json();
    if (data.content?.[0]?.text) {
      speech.textContent = data.content[0].text;
    } else {
      speech.textContent = 'Ce personnage ne souhaite pas s\'exprimer pour le moment.';
    }
  } catch(e) {
    speech.textContent = '(La conversation est impossible pour le moment. Verifiez votre connexion.)';
  }
}

function closePnjModal() {
  document.getElementById('modal-pnj').classList.remove('open');
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

  const isVacant = !POSTES[state.country]?.capitale?.find(p => p.id === posteId)?.holder;
  const successRate = isVacant ? 85 : 65;
  const roll = Math.floor(Math.random() * 100) + 1;

  if (roll <= successRate) {
    state.poste = { id: posteId, name: posteName };
    state.inf = Math.min(100, state.inf + 10);
    showToast(`Poste obtenu !`, `Vous occupez desormais le poste de ${posteName}.`, true, true);
    addJournalEntry(`Vous avez obtenu le poste de ${posteName}. +10 Influence.`, 'event-good');
  } else {
    showToast(`Candidature refusee`, `Votre demande pour le poste de ${posteName} a ete rejetee.`, false);
    addJournalEntry(`Votre candidature au poste de ${posteName} a ete rejetee.`, 'event-bad');
  }
  updateUI();
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
  body.innerHTML = `
    <div style="padding:.7rem 1rem;font-size:.8rem;color:#6a6050;font-style:italic;border-bottom:1px solid #1a1810">
      Les voyages entre villes consomment des PA. Les voyages entre empires consomment davantage.
    </div>
    <div class="world-map-grid">
      ${Object.entries(COUNTRIES).map(([countryId, co]) => `
        <div class="world-country">
          <div class="world-country-name" style="color:${co.col}">
            <i class="ti ${co.icon}" style="font-size:.9rem;vertical-align:-2px"></i> ${co.n}
          </div>
          <div style="font-size:.72rem;color:#5a5040;margin-bottom:.5rem">${co.desc.substring(0,60)}...</div>
          ${Object.entries(WORLD[countryId]||{}).map(([cityId, city]) => {
            const isCurrent = countryId === state.country && cityId === state.currentCity;
            const cost = countryId === state.country ? (isCurrent ? 0 : 2) : 5;
            return `
              <div class="world-city ${isCurrent ? 'current' : ''}"
                onclick="${isCurrent ? '' : `closeWorldMap();travelToCity('${cityId}')`}"
                style="${isCurrent ? 'cursor:default' : ''}">
                <span class="world-city-name">${city.name}${city.isCapitale ? ' ★' : ''}</span>
                <span class="world-city-cost">${isCurrent ? 'ICI' : cost + ' PA'}</span>
              </div>`;
          }).join('')}
        </div>`).join('')}
    </div>
  `;
  document.getElementById('modal-world').classList.add('open');
}
function closeWorldMap() {
  document.getElementById('modal-world').classList.remove('open');
}

// =====================
// FORUM
// =====================
const FORUM_DATA = {
  local: [
    {author:'CitoyenAnonyme',  time:'Jour 1 · 07h30', text:"La corruption au commissariat central est inacceptable ! Qui va agir ?"},
    {author:'JournalisteX',    time:'Jour 1 · 06h00', text:"Sources confirment que le Prefet Moreau aurait des liens avec des fonds offshore. Enquete en cours."}
  ],
  regional: [
    {author:'ElectedOfficialB', time:'Jour 1 · 05h00', text:"Le budget regional de Port-Sainte-Marie sera presente la semaine prochaine. Les syndicats se mobilisent."}
  ],
  national: [
    {author:'ObservateurPolitique', time:'Jour 1 · 08h00', text:"Le gouvernement en place semble fragilise. Des elections anticipees seraient envisagees selon nos informations."}
  ],
  international: [
    {author:'DiplomateEtranger', time:'Jour 1 · 04h00', text:"Les tensions entre Republia et El Estado s'intensifient autour des accords commerciaux."}
  ],
  prive: []
};
let currentForumTab = 'local';

function openForum() {
  renderForum('local');
  document.getElementById('modal-forum').classList.add('open');
}
function renderForum(tab) {
  currentForumTab = tab;
  const msgs = FORUM_DATA[tab] || [];
  document.getElementById('forum-body').innerHTML = `
    <div class="forum-tabs">
      ${['local','regional','national','international','prive'].map(t => `
        <div class="forum-tab ${t === tab ? 'active' : ''}" onclick="renderForum('${t}')">
          ${t.charAt(0).toUpperCase() + t.slice(1)}
        </div>`).join('')}
    </div>
    <div class="forum-content">
      ${msgs.length === 0
        ? '<div style="font-size:.82rem;color:#4a4030;font-style:italic;text-align:center;padding:2rem">Aucun message dans ce forum.</div>'
        : msgs.map(m => `
            <div class="forum-msg">
              <div class="forum-msg-author">${m.author}</div>
              <div class="forum-msg-text">${m.text}</div>
              <div class="forum-msg-time">${m.time}</div>
            </div>`).join('')}
    </div>
    <div class="forum-compose">
      <input class="forum-input" id="forum-input" placeholder="Ecrire un message dans le forum ${tab}..." />
      <button class="forum-send" onclick="postForumMsg()">Publier</button>
    </div>
  `;
}
function postForumMsg() {
  const input = document.getElementById('forum-input');
  const text = input.value.trim();
  if (!text) return;
  const char = state.char;
  FORUM_DATA[currentForumTab].unshift({
    author: char?.name || 'Anonyme',
    time: `Jour ${state.day} · ${String(state.hour).padStart(2,'0')}h00`,
    text: text
  });
  state.pop = Math.min(100, state.pop + 1);
  updateUI();
  renderForum(currentForumTab);
  addJournalEntry(`Vous avez publie un message sur le forum ${currentForumTab}.`, 'event-info');
}

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
