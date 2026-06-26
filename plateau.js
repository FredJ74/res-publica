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
  employees: [],
  employes: [],
  escortActive: [],
  tracesEnquete: [],
  dernierDormir: 0
};

// =====================
// INIT
// =====================
// Encode un objet PNJ en toute securite pour l'injection dans des attributs HTML —
// encodeURIComponent seul ne touche pas aux apostrophes, ce qui casse les onclick="...('...')"
// quand un nom de PNJ contient une apostrophe (ex: "Agent d'Entretien")
function encodePnjSafe(obj) {
  return encodeURIComponent(JSON.stringify(obj)).replace(/'/g, '%27');
}

window.addEventListener('DOMContentLoaded', () => {
  loadCharacter();
  // Restaurer dernierDormir depuis localStorage
  try {
    const dormirData = JSON.parse(localStorage.getItem('respublica_dormir_' + (state.char?.name || 'default')) || '{}');
    if (dormirData.dernierDormir) state.dernierDormir = dormirData.dernierDormir;
    if (dormirData.day) state.day = Math.max(state.day, dormirData.day);
  } catch(e) {}
  if (!state.currentCity) state.currentCity = 'capitale';
  if (!state.country) state.country = 'republic';
  applyEmpireTheme(state.country);
  // Sauvegarder la position courante
  if (state.char) {
    state.char.country = state.country;
    state.char.currentCity = state.currentCity;
    // Inclure poste et données importantes dans state.char avant sauvegarde
    if (state.char) {
      state.char.poste = state.poste || null;
      state.char.currentCity = state.currentCity || 'capitale';
      state.char.arg = state.arg || 0;
      state.char.resources = { inf: state.inf||0, pop: state.pop||0, dis: state.dis||50 };
      state.char.currentBuilding = state.currentBuilding || null;
      state.char.currentRoom = state.currentRoom || null;
    }
    localStorage.setItem('respublica_char_' + (state.char?.name || 'default'), JSON.stringify(state.char));
    localStorage.setItem('respublica_char', JSON.stringify(state.char));
  }
  buildCityTabs();
  updateUI();
  updateLocationDisplay();
  startClock();
  // Init Supabase
  if (typeof sbInit === 'function') sbInit();

  // Synchroniser les cycles électoraux depuis Supabase
  setTimeout(() => {
    syncCyclesDepuisSupabase().then(() => verifierPostesVacants());
  }, 2000);

  // Vérification mails toutes les 2 minutes
  verifierNouveauxMails();
  setInterval(verifierNouveauxMails, 120000);

  // Événements partagés (journal global) — au chargement puis toutes les 90 secondes
  setTimeout(() => chargerEvenementsPartages(), 1500);
  setTimeout(() => chargerOrganisations(), 1800);
  setTimeout(() => recupererDonsEnAttente(), 2000);
  setInterval(chargerEvenementsPartages, 90000);
  setInterval(recupererDonsEnAttente, 90000);

  // Présence en pièce — re-publier + rafraîchir les joueurs visibles toutes les 30 secondes
  setInterval(() => {
    if (typeof sbUpdatePresence === 'function' && state.char?.name && state.currentBuilding && state.currentRoom) {
      sbUpdatePresence(state.char.name, state.country, state.currentCity, state.currentBuilding, state.currentRoom).catch(() => {});
    }
    if (typeof chargerVraisJoueursPresents === 'function') chargerVraisJoueursPresents();
  }, 30000);

  // Séquence de chargement espacée pour éviter les conflits de modaux
  setTimeout(() => genererMeteoPolitique(), 1000);
  setTimeout(() => genererEvenementAleatoire(), 3000);
  setTimeout(() => {
    if (!sessionStorage.getItem('journaliste_done')) {
      afficherReactionJournaliste();
      sessionStorage.setItem('journaliste_done', '1');
    }
  }, 5000);
  // Journal du matin en dernier — après tous les autres
  setTimeout(() => afficherJournalDuMatin(), 8000);

  // Forcer le rendu complet au chargement
  setTimeout(() => {
    forceRenderCity(state.currentCity || 'capitale');
  }, 300);
});

function loadCharacter() {
  try {
    // Lire le dernier personnage actif, puis sa clé propre
    const lastName = localStorage.getItem('respublica_last_char');
    const saved = lastName
      ? (localStorage.getItem('respublica_char_' + lastName) || localStorage.getItem('respublica_char'))
      : localStorage.getItem('respublica_char');
    if (saved) {
      const char = JSON.parse(saved);
      applyCharToState(char);
      console.log('Personnage charge (local):', char.name, '| Pays:', state.country);
      // Restaurer la position exacte (piece) ou la personne se trouvait avant le rafraichissement
      restaurerPositionApresChargement(char);
      // Synchroniser depuis Supabase en arrière-plan
      if (char.name && typeof sbLoadPersonnage === 'function') {
        sbLoadPersonnage(char.name).then(sbState => {
          if (sbState) {
            // Fusionner les données Supabase (plus récentes)
            Object.assign(state, sbState);
            applyCharToState(state.char);
            updateUI();
            // Re-tenter la restauration de position avec la donnee Supabase (potentiellement plus a jour)
            restaurerPositionApresChargement(state.char);
            console.log('Personnage synchronisé depuis Supabase:', char.name);
          }
        }).catch(() => {});
      }
    }
  } catch(e) { console.warn('Erreur chargement personnage', e); }
}

// Si le joueur etait dans un batiment/piece avant de rafraichir, on l'y replace directement
function restaurerPositionApresChargement(char) {
  if (!char.currentBuilding || !char.currentRoom) return;
  if (!BUILDINGS[char.currentBuilding] || !BUILDINGS[char.currentBuilding].rooms?.[char.currentRoom]) return;
  setTimeout(() => {
    try {
      enterBuilding(char.currentBuilding);
      enterRoom(char.currentBuilding, char.currentRoom, null);
    } catch(e) { console.warn('Erreur restauration position', e); }
  }, 300);
}

function applyCharToState(char) {
  if (!char) return;
  state.char = char;
  state.country = char.country || 'republic';
  state.currentCity = char.currentCity || 'capitale';
  state.arg = char.arg || 4250;
  if (char.poste) state.poste = char.poste;
  state.liquide = Math.floor(state.arg * 0.15);
  state.banque = state.arg - state.liquide;
  state.inf = char.resources?.inf || 25;
  state.pop = char.resources?.pop || 30;
  state.dis = char.resources?.dis || 85;

  // UI
  const nameEl = document.getElementById('char-name-display');
  if (nameEl) nameEl.textContent = char.name || 'Mon Personnage';
  const ar = ARCHETYPES.find(x => x.id === char.archetype);
  const ca = CAREERS.find(x => x.id === char.career);
  const roleEl = document.getElementById('char-role-display');
  const posteLabel = state.poste?.name || null;
  if (roleEl) roleEl.textContent = posteLabel
    ? `${posteLabel} · ${ar?.name||'?'}`
    : `${ar?.name||'?'} · ${ca?.name||'?'}`;
  const fullnameEl = document.getElementById('char-fullname-left');
  if (fullnameEl) fullnameEl.textContent = char.name || 'Mon Personnage';
  const co = COUNTRIES[char.country];
  const archEl = document.getElementById('char-arch-left');
  const posteStr = state.poste?.name ? `${state.poste.name} · ` : '';
  if (archEl) archEl.textContent = `${posteStr}${ar?.name||'?'} · ${co?.n||'?'}`;

  // Photo
  try {
    const photoSaved = localStorage.getItem('respublica_photo_' + (state.char?.name || 'default')) || localStorage.getItem('respublica_photo');
    const photoUrl = photoSaved || char.photoUrl;
    if (photoUrl && photoUrl.length > 10) {
      const imgTag = `<img src="${photoUrl}" alt="Photo" style="width:100%;height:100%;object-fit:cover;border-radius:50%"/>`;
      const photoEl = document.getElementById('char-photo-left');
      const avatarEl = document.getElementById('char-avatar-top');
      if (photoEl) photoEl.innerHTML = imgTag;
      if (avatarEl) avatarEl.innerHTML = imgTag;
    }
  } catch(photoErr) { console.warn('Photo non chargee:', photoErr); }

  if (char.stats) {
    const statGrid = document.getElementById('stat-mini-grid');
    if (statGrid) statGrid.innerHTML = STAT_DEFS.map(({k}) => `
      <div class="stat-mini">
        <div class="stat-mini-name">${k}</div>
        <div class="stat-mini-val">${char.stats[k]||8}</div>
      </div>`).join('');
  }

  const cur = co?.cur || 'FR';
  const argEl = document.getElementById('r-arg');
  if (argEl) argEl.textContent = state.arg.toLocaleString('fr-FR') + ' ' + cur;
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

function advanceTime(pa) {
  // Chaque PA consomme environ 30 minutes de temps de jeu
  if (!TEST_MODE && pa > 0) {
    state.minute = (state.minute || 0) + (pa * 30);
    while (state.minute >= 60) {
      state.minute -= 60;
      state.hour = (state.hour + 1) % 24;
      if (state.hour === 0) {
        state.day = (state.day || 1) + 1;
        state.midnightDone = false;
      }
    }
    updateClock();
  }
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
  alimenterBudgets();
  checkScandale();
  checkEffacementCrimes();
  payerInformateurs();
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
  const tabs = document.getElementById('city-tabs');
  if (!tabs) return; // Supprimé de l'UI, on ne fait rien
}

function travelToCity(cityId) {
  if (cityId === state.currentCity) {
    forceRenderCity(cityId);
    return;
  }
  // Villes spéciales (caserne, QHS) — accès conditionné sur place, pas depuis la carte
  const specialCities = ['caserne', 'qhs'];
  if (specialCities.includes(cityId)) {
    showToast('Accès restreint', 'Cette zone n\'est accessible que via un taxi depuis le centre multinodal.', false);
    return;
  }
  // Voyage inter-villes bloqué — doit passer par le centre multinodal
  showToast('Transport requis', 'Pour voyager entre les villes, rendez-vous au Centre Multinodal.', false);
}

function forceRenderCity(cityId) {
  const world = WORLD[state.country];
  if (!world) return;
  const city = world[cityId];
  if (!city) return;

  // Mise a jour tabs
  document.querySelectorAll('.city-tab').forEach(t => t.classList.remove('active'));
  document.querySelectorAll('.city-tab').forEach(t => {
    if (t.textContent === city.name) t.classList.add('active');
  });

  document.getElementById('city-name-display').textContent = `${city.name}, ${city.isCapitale ? 'Capitale de ' : ''}${COUNTRIES[state.country]?.n || ''}`;

  // Vue rue
  showVueRue();
  renderMinimap(cityId);
  updateLocationDisplay();
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
  const world = WORLD[state.country];
  const city = world?.[state.currentCity];
  const ctx = city?.buildingContext?.[id];
  const localName = ctx?.name || city?.buildingNames?.[id] || b.shortName || b.name;
  const localDesc = ctx?.desc || b.desc || '';

  // PNJ présents
  const pnjList = ctx?.persons?.length > 0 ? ctx.persons :
    Object.values(b.rooms || {}).flatMap(r => r.persons || []);
  const personCount = pnjList.length;

  // Actions principales (3 max depuis la première pièce)
  const firstRoom = Object.values(b.rooms || {})[0];
  const actions = (firstRoom?.orders || []).slice(0, 3).map(o => o.label).join(' · ');

  const locked = b.locked ? '<span style="font-size:.6rem;color:#5a3020">· Accès restreint</span>' : '';

  // Noms des PNJ pour le tooltip
  const pnjHtml = pnjList.slice(0, 4).map(p =>
    '<div style="font-size:.68rem;color:#8a8060">· ' + (p.name||'').replace(' (PNJ)','') + '</div>'
  ).join('');

  const tooltip = '<div class="minimap-tooltip">' +
    '<div class="mtt-title">' + localName + '</div>' +
    (localDesc ? '<div class="mtt-desc">' + localDesc.substring(0,110) + (localDesc.length > 110 ? '...' : '') + '</div>' : '') +
    (pnjHtml ? '<div class="mtt-pnj">' + pnjHtml + '</div>' : '') +
    (actions ? '<div class="mtt-actions">Actions : ' + actions + '</div>' : '') +
    '</div>';

  return '<div class="minimap-building ' + (b.capitaleOnly ? 'capital-only' : '') + ' has-tooltip" onclick="enterBuilding(\'' + id + '\')">' +
    '<div class="minimap-bld-icon"><i class="ti ' + b.icon + '" style="font-size:.8rem"></i></div>' +
    '<div class="minimap-bld-info">' +
      '<div class="minimap-bld-name">' + localName + '</div>' +
      '<div class="minimap-bld-cat">' + b.cat + ' ' + locked + '</div>' +
      (personCount > 0 ? '<div class="minimap-persons">' + personCount + ' personne' + (personCount > 1 ? 's' : '') + '</div>' : '') +
    '</div>' +
    tooltip +
  '</div>';
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
    document.getElementById('rue-title').textContent = city.streetName || (city.isCapitale ? 'Avenue de la République' : `Rue principale de ${city.name}`);
    document.getElementById('rue-desc').textContent = city.desc;
  }

  // Image de rue directe depuis data.js
  const rueImage = document.getElementById('rue-image');
  const imgUrl = city?.imageUrl;
  if (imgUrl) {
    rueImage.style.background = `linear-gradient(180deg, rgba(0,0,0,0.1) 0%, rgba(0,0,0,0.4) 100%), url('${imgUrl}') center/cover no-repeat`;
  } else {
    rueImage.style.background = 'linear-gradient(135deg,#0a0a07,#0f0d08)';
  }
  const existing = document.getElementById('rue-emoji');
  if (existing) existing.remove();
}

function applyEmpireTheme(country) {
  document.body.classList.remove('empire-republic','empire-narco','empire-soviet','empire-khalija');
  document.body.classList.add('empire-' + (country || 'republic'));
}

function getBuildingContext(buildingId) {
  // Retourne le contexte local du bâtiment selon l'empire et la ville actuels
  const world = WORLD[state.country];
  const city = world?.[state.currentCity];
  return city?.buildingContext?.[buildingId] || null;
}

function enterBuilding(buildingId) {
  const b = BUILDINGS[buildingId];
  if (!b) return;

  if (b.locked) {
    showToast('Acces restreint', "Vous n'tes pas membre de cet etablissement.", false);
    addJournalEntry(`Vous tentez d'entrer mais l'acces vous est refuse.`, 'event-bad');
    return;
  }

  state.currentBuilding = buildingId;
  deplacerGroupeAvecPj(buildingId, null, state.currentCity);

  // Générer PNJ aléatoire si terrain à bâtir
  if (buildingId?.startsWith('terrain-a-batir')) {
    chargerPnjTerrain(buildingId);
    // Le PNJ est maintenant dans sessionStorage — forcer re-rendu après
    setTimeout(() => {
      if (state.currentRoom && state.currentBuilding === buildingId) {
        const room = BUILDINGS[buildingId]?.rooms?.[state.currentRoom];
        if (room) {
          let persons = [...(room.persons || [])];
          const stored = sessionStorage.getItem('terrain_pnj_' + buildingId);
          if (stored) {
            try {
              const pnjTerrain = JSON.parse(stored);
              if (pnjTerrain.name && !persons.find(p => p.name === pnjTerrain.name)) {
                persons = [...persons, pnjTerrain];
              }
            } catch(e) {}
          }
          renderPersonsList(persons);
        }
      }
    }, 100);
  }
  document.getElementById('vue-rue').classList.remove('active');
  document.getElementById('vue-batiment').classList.add('active');

  // Utiliser le contexte local si disponible
  const ctx = getBuildingContext(buildingId);
  const displayName = ctx?.name || b.name;
  const displayCat = b.cat;

  // Header
  document.getElementById('bat-nom').textContent = displayName;
  document.getElementById('bat-cat').textContent = displayCat;

  // Onglets pieces
  const rooms = Object.entries(b.rooms || {});
  const ctxForTabs = getBuildingContext(buildingId);
  document.getElementById('pieces-tabs').innerHTML = rooms.map(([roomId, room], i) => {
    const isZoneEmb = roomId === 'zone_embarquement';
    const locked = isZoneEmb && !state.douanePassee;
    const style = locked ? 'opacity:.4;pointer-events:none;cursor:not-allowed' : '';
    const icon = locked ? '🔒 ' : '';
    const tabName = ctxForTabs?.roomOverrides?.[roomId]?.name || room.name;
    return `<div class="piece-tab ${i === 0 ? 'active' : ''}" onclick="enterRoom('${buildingId}','${roomId}',this)" style="${style}">
      ${icon}${tabName}
    </div>`;
  }).join('');

  // Entrer dans la premiere piece
  if (rooms.length > 0) {
    enterRoom(buildingId, rooms[0][0], null);
  }

  updateLocationDisplay();
  addJournalEntry(`Vous entrez dans ${displayName}.`, '');
}

function enterRoom(buildingId, roomId, tabEl) {
  // Vérifier accès zone embarquement
  if (!checkZoneEmbarquementAcces(buildingId, roomId)) return;
  const b = BUILDINGS[buildingId];
  if (!b) return;
  const room = b.rooms?.[roomId];
  if (!room) return;

  state.currentRoom = roomId;
  deplacerGroupeAvecPj(buildingId, roomId, state.currentCity);

  // Synchroniser la position dans state.char a CHAQUE deplacement (pas seulement au chargement de page)
  if (state.char) {
    state.char.currentBuilding = buildingId;
    state.char.currentRoom = roomId;
    localStorage.setItem('respublica_char_' + (state.char.name || 'default'), JSON.stringify(state.char));
    localStorage.setItem('respublica_char', JSON.stringify(state.char));
    // Pousser aussi vers Supabase pour que la position survive a un rafraichissement avant la prochaine sauvegarde periodique
    if (typeof sbSavePersonnage === 'function') {
      sbSavePersonnage(state).catch(() => {});
    }
  }

  // Réinitialiser le cache des vrais joueurs (on change de pièce, l'ancien cache est obsolète)
  window._vraisJoueursPresents = [];

  // Publier sa présence pour que les autres joueurs nous voient (multijoueur temps réel)
  if (typeof sbUpdatePresence === 'function' && state.char?.name) {
    sbUpdatePresence(state.char.name, state.country, state.currentCity, buildingId, roomId).catch(() => {});
  }

  // Update tabs
  if (tabEl) {
    document.querySelectorAll('.piece-tab').forEach(t => t.classList.remove('active'));
    tabEl.classList.add('active');
  }

  // Contexte local : desc, PNJ et roomOverrides selon empire/ville
  const ctx = getBuildingContext(buildingId);
  const isFirstRoom = Object.keys(b.rooms || {})[0] === roomId;
  const roomOverride = ctx?.roomOverrides?.[roomId];

  // Image de la piece — priorité : ROOM_IMAGES_EMPIRE > roomOverride > room.imageUrl
  const empireRoomImg = (typeof ROOM_IMAGES_EMPIRE !== 'undefined')
    ? ROOM_IMAGES_EMPIRE[state.country]?.[buildingId]?.[roomId]
    : null;

  const pieceImg = document.getElementById('piece-image');
  const imgUrl = empireRoomImg || roomOverride?.imageUrl || room.imageUrl;
  if (imgUrl) {
    pieceImg.style.background = `linear-gradient(180deg, rgba(0,0,0,0.05) 0%, rgba(0,0,0,0.5) 100%), url('${imgUrl}') center/cover no-repeat`;
  } else {
    pieceImg.style.background = room.imageBg || 'linear-gradient(135deg,#0a0a07,#0f0d08)';
  }
  // Supprimer ancien emoji si present
  const existing = pieceImg.querySelector('.piece-emoji');
  if (existing) existing.remove();

  document.getElementById('piece-nom').textContent = roomOverride?.name || room.name;
  const displayDesc = (isFirstRoom && ctx?.desc) ? ctx.desc : (room.desc || '');
  document.getElementById('piece-desc').textContent = displayDesc;
  let displayPersons = (isFirstRoom && ctx?.persons?.length > 0) ? ctx.persons : (room.persons || []);

  // Injecter PNJ terrain si applicable
  if (buildingId?.startsWith('terrain-a-batir')) {
    const stored = sessionStorage.getItem('terrain_pnj_' + buildingId);
    if (stored) {
      try {
        const pnjTerrain = JSON.parse(stored);
        if (pnjTerrain.name) displayPersons = [...displayPersons, pnjTerrain];
      } catch(e) {}
    }
  }

  renderPersonsList(displayPersons);

  // Ordres
  renderRoomActions(room, buildingId, roomId);

  // Loc
  const ctxName = ctx?.name || b.shortName || b.name;
  document.getElementById('loc-name').textContent = ctxName;
  document.getElementById('loc-sub').textContent = room.name;
}

// =====================
// DOUANES AEROPORT
// =====================
function doPasserDouanesAeroport() {
  const pays = state.country || 'republic';
  const msgs = {
    republic: "L'inspecteur Prosper Tampon examine vos papiers, tamponne trois formulaires et vous laisse passer.",
    narco:    "Juanita Soborno vous sourit. Vous glissez un billet. Elle regarde ailleurs. Bonne route.",
    soviet:   "Nadejda Contrôle fouille votre bagage méthodiquement. Tout est en ordre, Camarade.",
    khalija:  "Le Chambellan Al-Transit incline la tête. Vos papiers sont en règle. Bienvenue."
  };

  // Si Recherché : jet de détection
  if (state.recherche?.length > 0) {
    const dis = state.char?.stats?.DIS || 50;
    const roll = Math.floor(Math.random() * 100) + 1;
    const taux = Math.max(5, 70 + Math.floor(dis/10) - getMalusISN());
    if (roll > taux) {
      showToast('Intercepté !', 'Votre statut de Recherché a été détecté. Vous êtes arrêté(e).', false);
      addJournalEntry('Interception aux douanes. Arrestation.', 'event-bad');
      return;
    }
  }

  state.douanePassee = true;
  const msg = msgs[pays] || msgs['republic'];
  showToast('Douanes passées', msg, true);
  addJournalEntry('Contrôle douanier passé. Accès zone embarquement autorisé.', 'event-info');

  // Activer l'onglet zone embarquement
  const tabs = document.querySelectorAll('.piece-tab');
  tabs.forEach(t => {
    if (t.textContent.includes('Embarquement') || t.textContent.includes('Embarque')) {
      t.style.opacity = '1';
      t.style.pointerEvents = 'auto';
      t.style.color = 'var(--gold)';
    }
  });
}

function checkZoneEmbarquementAcces(buildingId, roomId) {
  // Verrouiller la zone embarquement si douane non passée
  if (roomId === 'zone_embarquement' && !state.douanePassee) {
    showToast('Accès refusé', 'Vous devez d\'abord passer le contrôle douanier.', false);
    return false;
  }
  return true;
}

function sortirBatiment() {
  state.douanePassee = false;
  showVueRue();
  addJournalEntry(`Vous sortez du batiment.`, '');
}

// =====================
// PERSONS LIST
// =====================
function renderPersonsList(persons) {
  persons = [...(persons || [])]; // mutable copy
  const relCol = r => r === 'ally' ? '#4a8a4a' : r === 'enemy' ? '#8a3a2a' : '#6a6040';
  const relTxt = r => r === 'ally' ? 'Allie' : r === 'enemy' ? 'Hostile' : 'Neutre';

  const char = state.char;
  const ar = ARCHETYPES.find(x => x.id === char?.archetype);

  // Carte du PJ lui-meme — cliquable pour ouvrir la fiche personnage centrale
  const savedPhoto = localStorage.getItem('respublica_photo_' + (state.char?.name || 'default')) || localStorage.getItem('respublica_photo');
  const photoUrl = savedPhoto || char?.photoUrl;
  const photoHtml = photoUrl
    ? '<img src="' + photoUrl + '" alt="Vous" style="width:100%;height:100%;object-fit:cover;border-radius:50%"/>'
    : '<i class="ti ti-user" style="font-size:.75rem;color:#C9A84C"></i>';

  const selfCard = char ? '<div class="person-card" style="border-left:2px solid #C9A84C;cursor:pointer" onclick="openSelfView()" title="Cliquer pour dormir, inventaire, fiche">' +
    '<div class="person-avatar" style="border-color:#C9A84C">' + photoHtml + '</div>' +
    '<div>' +
    '<div class="person-name" style="color:#C9A84C">' + char.name + ' <span style="font-size:.6rem;color:#6a5a20">(Vous)</span></div>' +
    (state.recherche?.length > 0 ? '<div style="font-size:.62rem;color:#cc2020;font-family:Bebas Neue,sans-serif;letter-spacing:.1em;animation:blink 1s infinite">⚠ RECHERCHÉ</div>' : '') +
    '<div class="person-role">' + (state.poste?.name || ar?.name || 'Citoyen') + '</div>' +
    '<div style="font-size:.58rem;color:#4a8a4a">Cliquer : dormir · inventaire · fiche</div>' +
    '</div></div>' : '';

  const personCards = persons.length === 0 ? '' : persons.map(p => {
    const av = PNJ_AVATAR[p.job] || PNJ_AVATAR.default;
    const empireCol = COUNTRIES[state.country]?.col || '#C9A84C';
    const avatarHtml = p.photoUrl
      ? '<div class="person-avatar" style="overflow:hidden;border-color:' + (av.color || empireCol) + '">' +
        '<img src="' + p.photoUrl + '" style="width:100%;height:100%;object-fit:cover;object-position:' + (p.photoPos || '50% 15%') + '"/>' +
        '</div>'
      : '<div class="person-avatar"><i class="ti ' + av.icon + '" style="font-size:.75rem;color:' + (av.color || '#8a8060') + '"></i></div>';

    // Cadavre : onclick spécial via data-attributes
    if (p.terrainPnjId === 'cadavre') {
      return '<div class="person-card" onclick="ouvrirCadavreListe(this)" ' +
        'data-photo="' + (p.photoUrl || '') + '" ' +
        'data-pos="' + (p.photoPos || '50% 40%') + '" ' +
        'data-role="' + (p.role || 'Cadavre') + '" ' +
        'data-trait="' + (p.trait || '').replace(/"/g, '&quot;') + '">' +
        avatarHtml +
        '<div>' +
        '<div class="person-name">' + p.name + '</div>' +
        '<div class="person-role">' + p.role + '</div>' +
        '<div class="person-rel" style="color:#8a3a2a;font-size:.58rem">⚠ Décédé</div>' +
        '</div></div>';
    }

    const pData = encodePnjSafe(p);
    return '<div class="person-card" onclick="openPnjModal(this.dataset.enc)" data-enc="' + pData + '">' +
      avatarHtml +
      '<div>' +
      '<div class="person-name">' + p.name + '</div>' +
      '<div class="person-role">' + p.role + '</div>' +
      '<div class="person-rel" style="color:' + relCol(p.rel) + ';font-size:.58rem">' + relTxt(p.rel) + '</div>' +
      '</div></div>';
  }).join('');

  // Ajouter PNJ terrain si on est sur un terrain
  if (state.currentBuilding?.startsWith('terrain-a-batir')) {
    const stored = sessionStorage.getItem('terrain_pnj_' + state.currentBuilding);
    if (stored) {
      try {
        const pnjTerrain = JSON.parse(stored);
        if (pnjTerrain.name && !persons.find(p => p.name === pnjTerrain.name)) {
          persons = [...persons, pnjTerrain];
        }
      } catch(e) {}
    }
  }
  // Ajouter PNJ terrain si on est sur un terrain
  if (state.currentBuilding?.startsWith('terrain-a-batir')) {
    const stored = sessionStorage.getItem('terrain_pnj_' + state.currentBuilding);
    if (stored) {
      try {
        const pnjTerrain = JSON.parse(stored);
        if (pnjTerrain.name && !persons.find(p => p.name === pnjTerrain.name)) {
          persons = [...persons, pnjTerrain];
        }
      } catch(e) {}
    }
  }
  const simules = getSimulesPresents();
  const simuleCards = simules.map(p => {
    const enc = encodePnjSafe({...p, isPJ: true});
    return '<div class="person-card" onclick="openPnjModal(this.dataset.enc)" data-enc="' + enc + '" style="border-left:2px solid #4a6aaa">' +
      '<div class="person-avatar" style="border-color:#4a6aaa"><i class="ti ti-user-circle" style="font-size:.75rem;color:#4a6aaa"></i></div>' +
      '<div><div class="person-name" style="color:#8aaad0">' + p.name + ' <span style="font-size:.6rem;color:#3a5a8a">[SIM]</span></div>' +
      '<div class="person-role">' + p.role + '</div>' +
      '<div style="font-size:.6rem;color:#3a5a8a">INF:' + p.resources.inf + ' POP:' + p.resources.pop + '</div>' +
      '</div></div>';
  }).join('');

  // Ajouter les employés du groupe présents dans cette pièce
  const groupeHtml = getGroupeHtmlPourPiece(state.currentBuilding, state.currentRoom);

  const finalContent = selfCard + groupeHtml + simuleCards + personCards;
  document.getElementById('persons-list').innerHTML = finalContent ||
    '<div class="person-empty">Personne d\'autre ici</div>';

  // Charger les VRAIS joueurs présents dans cette pièce (Supabase) — async, ajouté après coup
  chargerVraisJoueursPresents();
}

// Cache partagé des photos de profil (nom -> photo_url), réutilisé pour la présence, le forum et les mails
window._cachePhotosJoueurs = window._cachePhotosJoueurs || {};
window._cachePhotosJoueursTimestamp = window._cachePhotosJoueursTimestamp || 0;
async function rafraichirCachePhotosJoueurs() {
  const maintenant = Date.now();
  // Rafraichir au maximum toutes les 60 secondes pour éviter de spammer Supabase
  if (maintenant - window._cachePhotosJoueursTimestamp < 60000 && Object.keys(window._cachePhotosJoueurs).length > 0) {
    return window._cachePhotosJoueurs;
  }
  if (typeof sbListPersonnages === 'function') {
    try {
      const joueurs = await sbListPersonnages() || [];
      const cache = {};
      joueurs.forEach(j => { if (j.photo_url) cache[j.name] = j.photo_url; });
      window._cachePhotosJoueurs = cache;
      window._cachePhotosJoueursTimestamp = maintenant;
    } catch(e) {}
  }
  return window._cachePhotosJoueurs;
}

// Retourne le HTML d'avatar (vraie photo si connue, sinon icone par defaut)
function getAvatarHtmlPourNom(nom, taille, bordColor) {
  const t = taille || 32;
  const c = bordColor || '#C9A84C';
  const photo = window._cachePhotosJoueurs?.[nom];
  if (photo) {
    return '<div style="width:' + t + 'px;height:' + t + 'px;border-radius:50%;overflow:hidden;border:1px solid ' + c + ';flex-shrink:0"><img src="' + photo + '" style="width:100%;height:100%;object-fit:cover"/></div>';
  }
  return '<div style="width:' + t + 'px;height:' + t + 'px;border-radius:50%;background:#1a1508;border:1px solid ' + c + ';display:flex;align-items:center;justify-content:center;flex-shrink:0"><i class="ti ti-user" style="font-size:' + (t*0.45) + 'px;color:' + c + '"></i></div>';
}

// Affiche les autres PJ réellement présents dans la pièce courante (rafraîchi périodiquement)
async function chargerVraisJoueursPresents() {
  if (typeof sbGetPresencesInRoom !== 'function') return;
  const buildingId = state.currentBuilding, roomId = state.currentRoom;
  const moi = state.char?.name;
  try {
    const presents = await sbGetPresencesInRoom(state.country, state.currentCity, buildingId, roomId);
    if (state.currentBuilding !== buildingId || state.currentRoom !== roomId) return;
    const autres = presents.filter(p => p.name !== moi);

    // Recuperer les photos depuis l'annuaire des personnages (presences n'a pas de photo)
    const photosParNom = await rafraichirCachePhotosJoueurs();

    // Mettre en cache pour getCurrentRoomPersons() (utilisé par assassinat, dons, etc.)
    window._vraisJoueursPresents = autres.map(p => ({
      name: p.name, role: 'Joueur', rel: 'neutral', isPJ: true, job: null,
      photoUrl: photosParNom[p.name] || null
    }));

    const empireCol = COUNTRIES[state.country]?.col || '#C9A84C';
    const html = window._vraisJoueursPresents.map(p => {
      const enc = encodePnjSafe(p);
      const avatarHtml = p.photoUrl
        ? '<div class="person-avatar" style="overflow:hidden;border-color:' + empireCol + '"><img src="' + p.photoUrl + '" style="width:100%;height:100%;object-fit:cover"/></div>'
        : '<div class="person-avatar" style="border-color:' + empireCol + '"><i class="ti ti-user" style="font-size:.75rem;color:' + empireCol + '"></i></div>';
      return '<div class="person-card vrai-joueur-card" onclick="openPnjModal(\'' + enc + '\')" style="border-left:2px solid ' + empireCol + '" title="Interagir">' +
      avatarHtml +
      '<div><div class="person-name" style="color:#f0ead6">' + p.name + ' <span style="font-size:.6rem;color:' + empireCol + '">[JOUEUR]</span></div>' +
      '<div class="person-role">Présent ici</div></div></div>';
    }).join('');

    // Retirer les anciennes cartes joueur avant d'inserer les nouvelles (evite les doublons au rafraichissement)
    const list0 = document.getElementById('persons-list');
    if (list0) list0.querySelectorAll('.vrai-joueur-card').forEach(el => el.remove());

    if (html) {
      const list = document.getElementById('persons-list');
      const empty = list.querySelector('.person-empty');
      if (empty) empty.remove();
      list.insertAdjacentHTML('beforeend', html);
    }
  } catch(e) { console.warn('chargerVraisJoueursPresents error', e); }
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
    // Verifier requiresPost : doit avoir le bon poste specifique
    let needsPost = false;
    if (o.requiresPost) {
      if (o.requiresPost === true) {
        // Juste avoir un poste
        needsPost = !state.poste;
      } else {
        // Verifier le poste specifique
        const posteId = state.poste?.id || '';
        const reqPost = o.requiresPost;
        if (reqPost === 'president') needsPost = posteId !== 'president';
        else if (reqPost === 'pm') needsPost = posteId !== 'pm';
        else if (reqPost === 'depute') needsPost = !posteId.startsWith('depute');
        else if (reqPost === 'juge') needsPost = posteId !== 'juge';
        else if (reqPost === 'magistrat') needsPost = !['juge','procureur'].includes(posteId);
        else if (reqPost === 'commissaire') needsPost = posteId !== 'commissaire';
        else needsPost = posteId !== reqPost;
      }
    }
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
      // Message explicatif avec le poste requis
      const postesNoms = {
        president: 'Président de la République',
        pm: 'Premier Ministre',
        depute: 'Député',
        juge: 'Juge',
        magistrat: 'Magistrat',
        commissaire: 'Commissaire',
        min_int: "Ministre de l'Intérieur",
        min_fin: 'Ministre des Finances',
        min_just: 'Ministre de la Justice',
        min_def: 'Ministre de la Défense',
        min_info: "Ministre de l'Information",
        min_ae: 'Ministre des AE'
      };
      const posteRequisNom = o.requiresPost === true ? 'un poste institutionnel' : (postesNoms[o.requiresPost] || o.requiresPost);
      onclickFn = 'showPostRequired(' + JSON.stringify(posteRequisNom) + ')';
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
  if (fn === 'consulter_elections') { ouvrirTableauElectoral(); return; }
  if (fn === 'creer_poste_ministre')    { creerPosteMinistre(); return; }
  if (fn === 'creer_comite')            { creerComite(); return; }
  if (fn === 'supprimer_poste_custom')  { supprimerPosteCustom(); return; }
  if (fn === 'nommer_ministre')         { openNominerModal(); return; }
  if (fn === 'nommer_pm')               { ouvrirModalCibleRepertoire('nommer_pm_confirm', 'Nommer un Premier Ministre'); return; }
  if (fn === 'nommer_ministre_pm')      { ouvrirNommerMinistresModal(); return; }
  if (fn === 'declarer_guerre_empire' || fn === 'declarer_guerre')  { ouvrirModalGuerreEmpire(); return; }
  if (fn === 'gracier_condamne' || fn === 'gracier') { ouvrirModalGracier(); return; }
  if (fn === 'decret_referendum')       { ouvrirForumNationalSousForumPresident('referendum'); return; }
  if (fn === 'jour_deuil')             { ouvrirForumNationalSousForumPresident('deuil'); return; }
  if (fn === 'solliciter_audience_president') { solliciterAudiencePresident(); return; }
  if (fn === 'etat_nation' || fn === 'etat_urgence')             { ouvrirIndicesImperiaux(); return; }
  if (fn === 'fixer_impots_locaux')    { ouvrirFixerImpotsLocaux(); return; }
  if (fn === 'prendre_train')          { ouvrirModalTransport('train'); return; }
  if (fn === 'taxi_caserne')           { doTaxiSpecial('caserne'); return; }
  if (fn === 'passer_douanes_aeroport'){ doPasserDouanesAeroport(); return; }
  if (fn === 'organigramme')           { ouvrirOrganigramme(); return; }
  if (fn === 'louer_local')              { ouvrirModalLouerLocal(); return; }
  if (fn === 'gerer_local')              { ouvrirModalGererLocal(); return; }
  if (fn === 'donner_argent_pnj')       { doDonnerArgentPnj(); return; }
  if (fn === 'appeler_police_terrain')  { doAppelerPoliceTerrain(); return; }
  if (fn === 'expulsion_legale')        { doExpulsionLegale(); return; }
  if (fn === 'donner_argent_pnj')       { doDonnerArgentPnj(); return; }
  if (fn === 'expulsion_legale')         { doExpulsionLegale(); return; }
  if (fn === 'appeler_police_terrain')  { doAppelerPoliceTerrain(); return; }
  if (fn === 'faire_disparaitre_cadavre') { doFaireDisparaitreCadavre(); return; }
  if (fn === 'negocier_squatteurs')     { doNegocierSquatteurs(); return; }
  if (fn === 'signer_compromis')        { doSignerCompromis(); return; }
  if (fn === 'acheter_terrain')         { doAcheterTerrain(); return; }
  if (fn === 'racheter_terrain')        { doRacheterTerrain(); return; }
  if (fn === 'decret_inutile')         { signerDecretInutile(); return; }
  if (fn === 'elections_tableau')      { ouvrirTableauElectoral(); return; }
  if (fn === 'changer_domicile')       { changerDomicile(state.country, state.currentCity); return; }
  if (fn === 'deposer_candidature')    { deposerCandidature(buildingId, state.country, state.currentCity); return; }
  if (fn === 'commanditer_sondage')    { commanderSondage(); return; }
  if (fn === 'escort_infos')           { doEscortInfos(); return; }
  if (fn === 'escort_piege')           { doEscortPiege(); return; }
  if (fn === 'recruter_informateur_1') { consulterInformateur(1); return; }
  if (fn === 'recruter_informateur_2') { consulterInformateur(2); return; }
  if (fn === 'recruter_informateur_3') { consulterInformateur(3); return; }
  if (fn === 'recruter_informateur_4') { consulterInformateur(4); return; }
  if (fn === 'interroger_informateur_1'){ interrogerInformateur(1); return; }
  if (fn === 'interroger_informateur_2'){ interrogerInformateur(2); return; }
  if (fn === 'interroger_informateur_3'){ interrogerInformateur(3); return; }
  if (fn === 'interroger_informateur_4'){ interrogerInformateur(4); return; }
  if (fn === 'recruter_info')          { ouvrirRecruterInformateur(1); return; }
  if (fn === 'recruter_info_2')        { ouvrirRecruterInformateur(2); return; }
  if (fn === 'recruter_info_3')        { ouvrirRecruterInformateur(3); return; }
  if (fn === 'recruter_info_4')        { ouvrirRecruterInformateur(4); return; }
  if (fn === 'consulter_info')         { consulterInformateur(1); return; }
  if (fn === 'consulter_info_2')       { consulterInformateur(2); return; }
  if (fn === 'consulter_info_3')       { consulterInformateur(3); return; }
  if (fn === 'consulter_info_4')       { consulterInformateur(4); return; }
  if (fn === 'gerer_informateurs')     { ouvrirGestionInformateurs(); return; }
  if (fn === 'taxi_qhs')               { doTaxiSpecial('qhs'); return; }
  if (fn === 'prendre_bus_taxi')       { ouvrirModalTransport('bus'); return; }
  if (fn === 'prendre_avion')          { ouvrirModalTransport('avion'); return; }
  if (fn === 'prendre_bateau')         { ouvrirModalTransport('bateau'); return; }
  if (fn === 'controle_douanes')       { doControlDouanes(); return; }
  if (fn === 'corrompre_douanier')     { doCorrompreDoanier(); return; }
  if (fn === 'expedier_colis')         { ouvrirExpedierColis(); return; }
  if (fn === 'receptionner_commande')  { ouvrirReceptionnerCommande(); return; }
  if (fn === 'contrebande_port')       { doContrebandePort(); return; }
  if (fn === 'blocus_portuaire')       { doBlocusPortuaire(); return; }
  if (fn === 'inspecter_cargaisons')   { doInspecterCargaisons(); return; }
  if (fn === 'consulter_manifeste')    { doConsulterManifeste(); return; }
  if (fn === 'falsifier_manifeste')    { doFalsifierManifeste(); return; }
  if (fn === 'acheter_parapluie')      { doAcheterPoisonObjet('parapluie'); return; }
  if (fn === 'acheter_ghb')            { doAcheterPoisonObjet('ghb'); return; }
  if (fn === 'acheter_polonium')       { doAcheterPoisonObjet('polonium'); return; }
  if (fn === 'acheter_vipere')         { doAcheterPoisonObjet('vipere'); return; }
  if (fn === 'assassiner')             { ouvrirModalAssassiner(); return; }
  if (fn === 'se_cacher')              { doSeCacher(); return; }
  if (fn === 'empoisonner')            { ouvrirModalEmpoisonner(); return; }
  if (fn === 'repartition_budget_local'){ ouvrirRepartitionBudgetLocal(); return; }
  if (fn === 'campagne_securite')      { doCampagneSecurite(); return; }
  if (fn === 'acte_officiel_mairie')   { ouvrirActeOfficielMairie(); return; }
  if (fn === 'contester_resultats')    { ouvrirContesterResultats(); return; }
  if (fn === 'calendrier_elections')   { ouvrirCalendrierElections(); return; }
  if (fn === 'observer_debats')         { observerDebats(); return; }
  if (fn === 'consulter_annuaire_deputes') { consulterAnnuaireDeputes(); return; }
  if (fn === 'objet_trouve')            { reclamerObjetTrouve(); return; }
  if (fn === 'voter_loi')              { ouvrirVoteLoi(); return; }
  if (fn === 'deposer_projet')         { ouvrirDeposerProjet(); return; }
  if (fn === 'ecouter_rumeurs')        { ecouterRumeurs(); return; }
  if (fn === 'forum_president_conference' || fn === 'conference_presse' || fn === 'donner_conf')  { ouvrirForumNationalSousForumPresident('conference'); return; }
  if (fn === 'forum_president_annonce' || fn === 'annonce_officielle')     { ouvrirForumNationalSousForumPresident('annonce'); return; }
  if (fn === 'forum_president_propagande' || fn === 'propagande_etat')  { ouvrirForumNationalSousForumPresident('propagande'); return; }
  if (fn === 'forum_president_dementi' || fn === 'dementi')     { ouvrirForumNationalSousForumPresident('dementi'); return; }
  if (fn === 'consulter_archives_lois') { ouvrirArchivesLois(); return; }
  if (fn === 'consulter_archives_tribunal') { ouvrirArchivesTribunal(); return; }
  if (fn === 'porter_plainte')          { ouvrirPorterPlainte(); return; }
  if (fn === 'rendre_sentence')         { ouvrirRendreSentence(); return; }
  if (fn === 'falsifier_document')      { ouvrirFalsifierDocument(); return; }
  if (fn === 'fiscal' || fn === 'gestion_budget') { ouvrirGestionBudget(); return; }
  if (fn === 'negocier_paix')        { ouvrirModalEmpireCible('negocier_paix', 'Negocier un accord de paix avec'); return; }
  if (fn === 'prier')                { doPrier(); return; }
  if (fn === 'se_confesser')         { doSeConfeser(); return; }
  if (fn === 'faire_don')            { doFaireDon(cost); return; }
  if (fn === 'demander_benediction') { doDemanderBenediction(); return; }
  if (fn === 'pelerin')              { doPelerin(); return; }
  if (fn === 'excommunier')          { ouvrirModalCibleRepertoire('excommunier', 'Excommunier'); return; }
  if (fn === 'benediction_etat')     { doBenedictionEtat(); return; }
  if (fn === 'consulter_confessions'){ doConsulterConfessions(); return; }
  if (fn === 'acheter_relique')      { doAcheterRelique(); return; }
  if (fn === 'scanner_aleatoire')    { declencherScandale(); return; }
  if (fn === 'accord_diplomatique')  { ouvrirModalEmpireCible('accord_diplomatique', 'Ouvrir des negociations avec'); return; }
  if (fn === 'produire_fuite')       { ouvrirProduireFuite(); return; }
  if (fn === 'fabriquer_scandale')   { ouvrirFabrquerScandale(); return; }
  if (fn === 'etat_nation')          { ouvrirIndicesImperiaux(); return; }

  // Handlers complementaires v17
  if (fn === 'corrompre_fonct' || fn === 'corrompre_police' || fn === 'corrompre_journaliste') { doCorruption(fn, cost); return; }
  if (fn === 'se_reposer' || fn === 'se_nourrir') { doSeReposer(fn); return; }
  if (fn === 'soins' || fn === 'soins_basiques' || fn === 'soins_discrets' || fn === 'soins_urgence') { doSesoigner(); return; }
  if (fn === 'requete_avocat') { doRequeteAvocat(); return; }
  if (fn === 'greve_faim') { doGreveFaim(); return; }
  if (fn === 'tentative_evasion') { doTentativeEvasion(); return; }
  if (fn === 'visiter_prisonnier') { doVisiterPrisonnier(); return; }
  if (fn === 'se_renseigner') { doSeRenseigner(); return; }
  if (fn === 'ecouter')        { doSeRenseigner(); return; }
  if (fn === 'reserver') { doReserver(); return; }
  if (fn === 'interview') { doInterview(); return; }
  if (fn === 'article') { doArticle(); return; }
  if (fn === 'etouffer') { doEtouffer(); return; }
  if (fn === 'archives') { ouvrirArchivesTribunal(); return; }
  if (fn === 'consulter_dossiers') { ouvrirArchivesTribunal(); return; }
  if (fn === 'demander_info_loge') { doLogeInfo(); return; }
  if (fn === 'se_former') { doSeFormer(); return; }
  if (fn === 'recruter_info') { doRecruterInfo(); return; }
  if (fn === 'mobiliser_police') { doMobiliserPolice(); return; }
  if (fn === 'mobiliser_armee') { doMobiliserArmee(); return; }
  if (fn === 'etat_urgence') { doEtatUrgence(); return; }
  if (fn === 'inspecter_troupes') { doInspecterTroupes(); return; }
  if (fn === 'ouvrir_enquete') { ouvrirModalCibleRepertoire('ouvrir_enquete', 'Ouvrir une enquete sur'); return; }
  if (fn === 'annuler_poursuites') { ouvrirModalAffaires('annuler'); return; }
  if (fn === 'nommer_juge') { ouvrirModalNommerJuge(); return; }
  if (fn === 'nommer_commissaire') { ouvrirModalNommerCommissaire(); return; }
  if (fn === 'censurer_media') { ouvrirModalMedia(); return; }
  if (fn === 'commanditer_sondage') { ouvrirModalTexteLibre('commanditer_sondage', 'Commanditer un sondage', 'Preciser le sujet...'); return; }
  if (fn === 'cessez_le_feu') { ouvrirModalEmpireCible('cessez_le_feu', 'Negocier un cessez-le-feu avec'); return; }
  if (fn === 'signer_traite') { ouvrirModalTraite(); return; }
  if (fn === 'ouvrir_ambassade') { ouvrirModalEmpireCible('ouvrir_ambassade', 'Ouvrir une ambassade dans'); return; }
  if (fn === 'sanctions_diplo') { ouvrirModalEmpireCible('sanctions', 'Imposer des sanctions a'); return; }
  if (fn === 'subvention') { ouvrirModalCibleRepertoire('subvention', 'Accorder une subvention a'); return; }
  if (fn === 'redressement_fiscal') { ouvrirModalCibleRepertoire('redressement_fiscal', 'Redressement fiscal contre'); return; }
  if (fn === 'augmenter_impots') { doAugmenterImpots(true); return; }
  if (fn === 'baisser_impots') { doAugmenterImpots(false); return; }
  if (fn === 'allegemement_fiscal') { ouvrirModalSecteur(); return; }
  if (fn === 'interdire_manif') { ouvrirModalTexteLibre('interdire_manif', 'Interdire une manifestation', 'Nom ou sujet de la manifestation...'); return; }
  if (fn === 'repression_manif') { ouvrirModalTexteLibre('reprimer_manif', 'Ordonner la repression', 'Manifestation ou rassemblement cible...'); return; }
  if (fn === 'autoriser_manif') { doAutoriserManif(); return; }
  if (fn === 'renseignement') { ouvrirModalRenseignement(); return; }
  if (fn === 'planifier_operation') { ouvrirModalTexteLibre('planifier_operation', 'Planifier une operation', 'Decrivez l\'operation...'); return; }
  if (fn === 'mobiliser') { doMobiliserPolice(); return; }
  if (fn === 'dissoudre_assemblee') { doDissoudreAssemblee(); return; }
  if (fn === 'negocier') { showToast('Ordre contact', 'Utilisez les ordres contact en cliquant sur le personnage cible.', false); return; }
  if (fn === 'parler_pnj') { showToast('Ordre contact', 'Cliquez directement sur le personnage pour interagir.', false); return; }
  if (fn === 'plainte') { ouvrirPorterPlainte(); return; }
  if (fn === 'projet_loi') { ouvrirDeposerProjet(); return; }
  if (fn === 'greve') { doGrevePNJ(); return; }
  if (fn === 'recruter_etud') { doRecruterMilitants(); return; }
  if (fn === 'acte_officiel') { doActeOfficiel(); return; }

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
    const cur = COUNTRIES[state.country]?.cur || 'FR';
    const msgs = [];
    const today = state.day || 1;

    // Vérifier si déjà dormi aujourd'hui
    if (state.dernierDormir === (state.day || 1)) {
      showToast('Déjà dormi', 'Vous avez déjà dormi aujourd\'hui. Attendez demain.', false);
      return;
    }

    // 1. PA bonus selon hotel
    if (ef.paBonus && resultType !== 'fail') {
      state.paBonus = ef.paBonus || 0;
      msgs.push(`+${ef.paBonus} PA bonus demain`);
    }

    // 2. Salaire journalier
    if (!state.salaireTouche) {
      state.salaireTouche = true;
      const posteId = state.poste?.id || 'default';
      const salaire = SALAIRES[posteId] || SALAIRES.default;
      state.arg += salaire;
      state.liquide += Math.floor(salaire * 0.3);
      state.banque += Math.ceil(salaire * 0.7);
      msgs.push(`Salaire : +${salaire.toLocaleString('fr-FR')} ${cur}`);
      addJournalEntry(`Salaire journalier versé : ${salaire.toLocaleString('fr-FR')} ${cur} (${state.poste?.name || 'Citoyen'}).`, 'event-good');
    } else {
      addJournalEntry("Vous avez déjà perçu votre salaire aujourd'ui.", '');
    }

    // 3. Effets poison progressifs
    if (state.poisonActif) {
      const poison = state.poisonActif;
      const jourPoison = (state.day || 1) - (poison.jourDebut || 1);
      if (jourPoison === 0) {
        state.pa = Math.max(0, state.pa - 2);
        const msgPoison = poison.message || 'Vous vous réveillez avec une douleur inexpliquée. -2 PA.';
        msgs.push('⚠️ ' + msgPoison);
        addJournalEntry(msgPoison, 'event-bad');
        const statPerdue = {'republic':'VOL','narco':'PER','soviet':'INT','khalija':'CHA'}[poison.empireSource] || 'VOL';
        if (state.char?.stats?.[statPerdue]) {
          state.char.stats[statPerdue] = Math.max(1, state.char.stats[statPerdue] - 2);
          addJournalEntry(`Votre ${statPerdue} diminue de 2 points.`, 'event-bad');
        }
      } else if (jourPoison === 1) {
        state.hp = Math.max(1, Math.floor(state.hp / 2));
        msgs.push("⚠️ Votre état empire. HP divisés par 2.");
        addJournalEntry("L'empoisonnement progresse. Vos HP sont divisés par 2.", 'event-bad');
      } else {
        state.poisonActif = null;
        msgs.push('Vous semblez vous remettre de votre malaise.');
        addJournalEntry('Les effets du poison se dissipent.', 'event-good');
      }
    }

    // 4. Paiement des informateurs
    if (state.informateurs?.length > 0) {
      const toRemove = [];
      state.informateurs.forEach((inf, i) => {
        if (inf.joursActif !== undefined) inf.joursActif++;
        const cout = INFORMATEUR_NIVEAUX[inf.niveau]?.cout || 150;
        if (state.arg >= cout) {
          state.arg -= cout;
          addJournalEntry(`Informateur niveau ${inf.niveau} payé : -${cout} ${cur}.`, 'event-info');
        } else {
          toRemove.push(i);
          addJournalEntry(`Fonds insuffisants. Votre informateur niveau ${inf.niveau} vous quitte.`, 'event-bad');
        }
      });
      toRemove.reverse().forEach(i => state.informateurs.splice(i, 1));
    }

    // 5. Effacement automatique des crimes
    checkEffacementCrimes();

    // 6. Avancement du jour + reset
    state.salaireTouche = false;
    state.day = (state.day || 1) + 1;
    state.dernierDormir = state.day; // Bloque le jour suivant
    state.douanePassee = false;
    localStorage.setItem('respublica_dormir_' + (state.char?.name || 'default'), JSON.stringify({dernierDormir: state.dernierDormir, day: state.day}));

    // Revenus passifs des organisations
    // appliquerRevenusPassifsOrga(); // V1 obsolète — remplacée par appliquerBonusLocation() dans payerLocations()
    // Vérifier postes vacants
    verifierPostesVacants();

    if (msgs.length > 0) showToast('Bonne nuit !', msgs.join(' · '), true, true);
    updateUI();
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

// =====================
// FICHES PERSONNALITÉ PNJ
// =====================
const PNJ_PERSONALITIES = {
  // RÉPUBLIA
  'Gaston Retard': { trait: "Fonctionnaire depuis 34 ans. N'a jamais annoncé un train à l'heure. Le considère comme une forme d'art. Parle de lui-même à la troisième personne quand il est stressé.", style: "bureaucratique épuisé, cynique poli, fier de son inefficacité" },
  'Mireille Guichet': { trait: "Sourit en permanence sans raison. Répond à tout par 'C'est noté' sans jamais noter quoi que ce soit.", style: "serviable de façade, passive-agressive, adore les formulaires" },
  'Raoul Toufaud': { trait: "Commissaire qui pointe toujours dans la mauvaise direction. Confond régulièrement les suspects et les témoins. A résolu exactement 0 affaire.", style: "autoritaire incompétent, se vexe facilement, cite le règlement sans le connaître" },
  'Brigitte Menottes': { trait: "Inspectrice qui menotterait sa propre ombre si elle pouvait. Zèle inversement proportionnel à son efficacité.", style: "zélée et inutile, parle en jargon policier inventé" },
  'Honoré Cozetoujours': { trait: "Juge qui condamne avant d'écouter. A condamné son greffier par erreur trois fois.", style: "sentencieux, cite des lois inventées, tape du marteau de façon aléatoire" },
  'Bernard Coffre-Fort': { trait: "Directeur de banque qui n'a jamais ouvert un compte de sa vie. Confond les débits et les crédits.", style: "solennel et incompétent, parle en chiffres qui ne correspondent à rien" },
  'Hans Von Discret': { trait: "Banquier suisse qui confirme uniquement par un silence pesant. Sa discrétion est telle qu'il nie son propre nom.", style: "mutisme calculé, réponses en non-dits, accent suisse exagéré" },
  'Frère Jacques D\'Equerre': { trait: "Grand Maître qui parle uniquement en métaphores géométriques. Le triangle est sa réponse à tout.", style: "énigmatique pompeux, métaphores maçonniques absurdes, clin d'œil permanent" },

  // EL ESTADO
  'Pedro Tequila': { trait: "Barman philosophe qui mélange les cocktails et les théories politiques. Chaque verre est une leçon de vie qu'on ne demandait pas.", style: "jovial menaçant, proverbes inventés en espagnol approximatif, toujours un couteau sur le comptoir" },
  'Lupe Cantina': { trait: "Serveuse armée qui prend les commandes avec un revolver à la ceinture. Le pourboire est obligatoire.", style: "souriante dangereuse, mélange espagnol et français au hasard, mentionne El Don sans raison" },
  'El Capitan Gordo': { trait: "Incorruptible jusqu'à 500 pesos. Après, tout est négociable. A un portrait d'El Don derrière lui en permanence.", style: "autoritaire jovial, corruption assumée, cite El Don à tout moment" },
  'Consuela Silencio': { trait: "Inspectrice qui tire sa force du silence absolu. Peut rester immobile 4 heures en vous fixant.", style: "intimidation par le silence, parle rare et percutant, regard qui tue" },
  'El Juez Manchado': { trait: "Juge dont les verdicts se vendent au kilo. Propose une grille tarifaire officieuse après chaque audience.", style: "corruption institutionnalisée, formules juridiques espagnoles inventées, sourire gras" },
  'Carlos Retraso': { trait: "Chef de gare qui annonce des horaires purement décoratifs. Les trains partent quand El Don le décide.", style: "bureaucrate tropical, délais assumés, chaleur étouffante dans chaque phrase" },
  'Juanita Soborno': { trait: "Agente des douanes qui fait passer les colis avec un sourire si on glisse un billet dans le passeport.", style: "corruption charmante, regard complice, formules douanières inventées" },

  // SOVARKA
  'Olga Soupe': { trait: "Cantinière qui sert la même soupe depuis 1952. Considère la variété culinaire comme une déviation bourgeoise.", style: "stoïcisme soviétique, fierté de la betterave, citations du Parti dans chaque phrase" },
  'Boris Betterave': { trait: "Cuisinier qui n'a jamais vu une épice. La betterave est son seul ingrédient et il en est fier.", style: "enthousiasme soviétique pour le vide, compare tout à la betterave" },
  'Camarade Borodine': { trait: "Commissaire du Peuple qui remplit des rapports en triple sur les rapports qu'il vient de remplir. Voit des contre-révolutionnaires partout.", style: "paranoïa douce, camarade à tout bout de champ, formulaires comme religion" },
  'Nadejda Formulaire': { trait: "Secrétaire qui sourit uniquement en remplissant des formulaires. Considère la joie comme contre-révolutionnaire.", style: "robotique administrative, formulaires en quadruple, bonheur dans la paperasse" },
  'Camarade Horaire': { trait: "Chef de gare qui pense que les trains arrivent à l'heure parce que le Parti l'a décrété. La réalité est un détail.", style: "idéologique inflexible, nie l'évidence, cite des statistiques inventées" },
  'Nadejda Contrôle': { trait: "Inspectrice des douanes qui fouille les bagages méthodiquement en enregistrant tout en triple. A trouvé une fois un livre non approuvé. C'est son plus grand fait d'armes.", style: "zèle procédurier, méfiance systématique, fierté du protocole" },

  // AL-KHALIJA
  'Hassan Marchandage': { trait: "Marchand dont le premier prix affiché est une insulte à la négociation. Le vrai prix n'apparaît qu'après 40 minutes de marchandage rituel.", style: "protocole du marchandage sacré, bénédictions du Loukoum Divin entre chaque offre" },
  'Yasmine Épices': { trait: "Marchande qui connaît le prix de chaque secret de la ville. Les épices sont son prétexte, les informations son commerce.", style: "mystérieuse parfumée, double sens permanent, cite le Loukoum Divin en cas de doute" },
  'Chambellan Ibn Protocole': { trait: "Chef de la Garde qui ne parle qu'en troisième personne. Considère le tutoiement comme un crime de lèse-majesté.", style: "protocole excessif, troisième personne, bénédictions du Sheikh imbriquées" },
  'Fatima Al-Secret': { trait: "Inspectrice dont les interrogatoires consistent à servir du thé en silence jusqu'à ce que l'interlocuteur avoue spontanément.", style: "douceur menaçante, thé comme arme, patience infinie" },
  'Chambellan Al-Transit': { trait: "Directeur du Hub Royal qui accueille selon le rang. Un visa en or pour les notables, une heure d'attente pour les autres.", style: "protocole hiérarchique absolu, bénédictions Royal, troisième personne" },
  'Yasmine Embarquement': { trait: "Hôtesse royale qui sourit avec une précision chirurgicale calculée au millimètre par le protocole.", style: "perfection froide, formules royales mémorisées, sourire mécanique parfait" },
  'Cheikh Al-Verdict': { trait: "Grand Juge dont les verdicts s'inspirent des textes sacrés et des instructions discrètes du Palais. Le Loukoum Divin guide sa main.", style: "sentences solennelles, citations du Loukoum Divin, justice royale assumée" },

  // Escorts
  'Roxane Velours':    { trait: "Escort de luxe dont le carnet d'adresses vaut plus que celui du Premier Ministre. Chaque confidence lui appartient. Elle sourit toujours — c'est inclus dans le tarif.", style: "charme discret, double sens constant, connait tous les secrets des couloirs du pouvoir" },
  'Lola Discreta':     { trait: "Informatrice double jeu a Ciudad Roja. Travaille officiellement pour El Don. Et pour deux autres personnes. Elle-meme ne sait plus tres bien pour qui.", style: "mysterieuse enjouee, proverbes espagnols inventes, revele toujours un peu plus qu'elle ne devrait" },
  'Natasha Privilege': { trait: "Reservee aux cadres du Parti. Tres bien informee sur les deliberations internes. Ce qu'elle entend reste confidentiel — sauf si on lui demande poliment.", style: "distinction sovietique, formules du Parti recyclees, discretion absolue sur demande express" },

  // Reporters
  'Jodie Moitout':     { trait: "Journaliste micro-trottoir de L'Autruche Entravee. Tend son micro a n'importe qui, n'importe ou, n'importe quand. Les gens lui disent tout sans savoir pourquoi. Son sourire est une arme.", style: "enthousiasme journalistique communicatif, questions anodines aux reponses explosives, micro tendu en permanence" }
};

// Traits génériques par empire si PNJ non répertorié
const EMPIRE_STYLES = {
  republic: { tone: "bureaucratique français épuisé, cynique poli", religion: "le Tabernacle des Impôts", currency: "FR", leader: "le Président" },
  narco:    { tone: "jovial menaçant, corruption assumée, espagnol de bazar", religion: "le Laboratoire de Prière", currency: "PS", leader: "El Don" },
  soviet:   { tone: "idéologique soviétique, formulaires sacrés, Camarade partout", religion: "le Kolkhoze Spirituel", currency: "RP", leader: "le Parti" },
  khalija:  { tone: "protocole royal excessif, Loukoum Divin omniprésent, bénédictions imbriquées", religion: "la Pâtisserie Sacrée", currency: "DR", leader: "le Sheikh" }
};




// =====================
// POP-UP STATS PERSONNAGE
// =====================
function ouvrirStatsPerso() {
  const co = COUNTRIES[state.country];
  const cur = co?.cur || 'FR';
  const char = state.char;
  const ar = ARCHETYPES.find(x => x.id === char?.archetype);

  const stats = [
    { label: 'Influence',   val: state.inf  || 0, max: 100, col: '#4a6aaa', icon: 'ti-crown',       desc: 'Poids politique et réseau' },
    { label: 'Popularité',  val: state.pop  || 0, max: 100, col: '#aa6a4a', icon: 'ti-speakerphone', desc: 'Soutien de la population' },
    { label: 'Discrétion',  val: state.dis  || 0, max: 100, col: '#8a4aaa', icon: 'ti-eye-off',      desc: 'Capacité à agir sans être détecté' },
    { label: 'Santé',       val: state.hp   || 0, max: 100, col: '#aa4a4a', icon: 'ti-heart',        desc: 'État physique' },
    { label: 'Moral',       val: state.moral|| 0, max: 100, col: '#6a8aaa', icon: 'ti-brain',        desc: 'Résistance psychologique' },
  ];

  const persoStats = char?.stats || {};
  const STAT_DEFS_LOCAL = [
    { k:'INT', n:'Intelligence', col:'#6a8aaa', i:'ti-brain' },
    { k:'CHA', n:'Charisme',     col:'#aa8a4a', i:'ti-speakerphone' },
    { k:'VOL', n:'Volonté',      col:'#4a8a6a', i:'ti-flame' },
    { k:'PER', n:'Perception',   col:'#4a6aaa', i:'ti-eye' },
    { k:'DUP', n:'Duplicité',    col:'#8a4a8a', i:'ti-masks-theater' },
    { k:'ENT', n:'Entregent',    col:'#8a6a4a', i:'ti-network' },
  ];

  const barsHtml = stats.map(s => {
    const pct = Math.round(s.val);
    return '<div style="margin-bottom:.5rem">' +
      '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:.2rem">' +
        '<div style="display:flex;align-items:center;gap:.4rem">' +
          '<i class="ti ' + s.icon + '" style="font-size:.75rem;color:' + s.col + '"></i>' +
          '<span style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;color:#a09060">' + s.label + '</span>' +
        '</div>' +
        '<span style="font-family:Bebas Neue,sans-serif;font-size:.82rem;color:' + s.col + '">' + pct + '</span>' +
      '</div>' +
      '<div style="height:4px;background:#1a1810;border-radius:2px">' +
        '<div style="height:100%;width:' + pct + '%;background:' + s.col + ';border-radius:2px;transition:width .3s"></div>' +
      '</div>' +
      '<div style="font-size:.6rem;color:#4a4030;margin-top:.1rem">' + s.desc + '</div>' +
    '</div>';
  }).join('');

  const persoHtml = STAT_DEFS_LOCAL.map(s => {
    const val = persoStats[s.k] || 0;
    return '<div style="text-align:center">' +
      '<div style="font-size:.62rem;color:' + s.col + ';font-family:Bebas Neue,sans-serif;letter-spacing:.06em">' + s.k + '</div>' +
      '<div style="font-size:1rem;color:#f0ead6;font-family:Bebas Neue,sans-serif">' + val + '</div>' +
      '<div style="font-size:.58rem;color:#4a4030">' + s.n + '</div>' +
    '</div>';
  }).join('');

  document.getElementById('postes-modal-title').textContent = 'Statistiques — ' + (char?.name || 'Mon Personnage');
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.6rem 1rem">' +
      '<div style="font-size:.7rem;color:#8a8060;margin-bottom:.8rem;font-style:italic">' +
        (ar?.name || '') + ' · ' + (co?.n || '') +
        (state.poste?.name ? ' · ' + state.poste.name : '') +
      '</div>' +
      '<div style="font-family:Bebas Neue,sans-serif;font-size:.65rem;letter-spacing:.15em;color:#4a4030;margin-bottom:.5rem">INDICES</div>' +
      barsHtml +
      '<div style="border-top:1px solid #2a2010;margin:.6rem 0"></div>' +
      '<div style="font-family:Bebas Neue,sans-serif;font-size:.65rem;letter-spacing:.15em;color:#4a4030;margin-bottom:.5rem">ATTRIBUTS PERSONNELS</div>' +
      '<div style="display:grid;grid-template-columns:repeat(6,1fr);gap:.4rem">' + persoHtml + '</div>' +
      '<div style="border-top:1px solid #2a2010;margin:.6rem 0"></div>' +
      '<div style="display:flex;justify-content:space-between;font-size:.72rem;color:#8a8060">' +
        '<span>💰 Liquide : <strong style="color:#C9A84C">' + (state.liquide||0).toLocaleString('fr-FR') + ' ' + cur + '</strong></span>' +
        '<span>🏦 Banque : <strong style="color:#C9A84C">' + (state.banque||0).toLocaleString('fr-FR') + ' ' + cur + '</strong></span>' +
      '</div>' +
    '</div>';

  document.getElementById('modal-postes').classList.add('open');
}

// =====================
// MENU MESSAGES (Forum + Mail)
// =====================
// =====================
// AVATARS CSS PNJ
// =====================
const PNJ_AVATAR = {
  commissaire:   { icon: 'ti-shield-lock',       color: '#4a6aaa' },
  inspecteur:    { icon: 'ti-search',             color: '#4a6aaa' },
  policier:      { icon: 'ti-shield',             color: '#4a6aaa' },
  gardien:       { icon: 'ti-lock',               color: '#6a6060' },
  juge:          { icon: 'ti-gavel',              color: '#C9A84C' },
  avocat:        { icon: 'ti-scale',              color: '#8a8060' },
  journaliste:   { icon: 'ti-news',               color: '#8a4a20' },
  redacteur:     { icon: 'ti-pencil',             color: '#8a4a20' },
  banquier:      { icon: 'ti-building-bank',      color: '#4a8a4a' },
  medecin:       { icon: 'ti-stethoscope',        color: '#4a9a9a' },
  infirmier:     { icon: 'ti-heart-rate-monitor', color: '#4a9a9a' },
  serveur:       { icon: 'ti-bowl',               color: '#8a6a40' },
  hotelier:      { icon: 'ti-building-castle',    color: '#8a6a40' },
  barman:        { icon: 'ti-glass',              color: '#8a6a40' },
  militaire:     { icon: 'ti-military-rank',      color: '#4a6a4a' },
  general:       { icon: 'ti-medal',              color: '#C9A84C' },
  maire:         { icon: 'ti-building-community', color: '#C9A84C' },
  secretaire:    { icon: 'ti-file-certificate',   color: '#8a8060' },
  professeur:    { icon: 'ti-school',             color: '#6a4a8a' },
  loge:          { icon: 'ti-hexagon',            color: '#8a2020' },
  armurier:      { icon: 'ti-shield',             color: '#6a6060' },
  commercant:    { icon: 'ti-building-store',     color: '#8a6a40' },
  syndicaliste:  { icon: 'ti-users-group',        color: '#8a2020' },
  douanier:      { icon: 'ti-clipboard-check',    color: '#4a6aaa' },
  chef_gare:     { icon: 'ti-train',              color: '#6a6060' },
  hotesse:       { icon: 'ti-user-heart',         color: '#8a4a6a' },
  grand_pretre:  { icon: 'ti-star',               color: '#C9A84C' },
  escort:        { icon: 'ti-heart',              color: '#aa4a6a' },
  capitaine_port:{ icon: 'ti-anchor',             color: '#4a6aaa' },
  protocole:     { icon: 'ti-crown',              color: '#C9A84C' },
  garde:         { icon: 'ti-shield',             color: '#4a6aaa' },
  porteparole:   { icon: 'ti-speakerphone',       color: '#8a4a20' },
  archiviste:    { icon: 'ti-archive',            color: '#8a8060' },
  directeur:     { icon: 'ti-briefcase',          color: '#C9A84C' },
  citoyen:       { icon: 'ti-user',               color: '#6a6060' },
  depute:        { icon: 'ti-building-arch',      color: '#C9A84C' },
  default:       { icon: 'ti-user',               color: '#6a6060' }
};

function getPnjAvatar(pnj, empireColor) {
  // Photo escort selon empire si pas de photoUrl
  if (!pnj.photoUrl && pnj.job === 'escort') {
    const escortPhotos = {
      republic: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/escort-republic.png',
      narco:    'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/escort-narco.png',
      soviet:   'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/escort-soviet.png',
      khalija:  'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/escort-khalija.png',
    };
    pnj.photoUrl = escortPhotos[state.country] || '';
    pnj.photoPos = '50% 10%';
  }
    if (pnj.photoUrl) {
    const col = empireColor || '#C9A84C';
    const safeName = (pnj.name || '').replace(' (PNJ)', '');
    return '<div style="flex-shrink:0;text-align:center">' +
      '<div onclick="ouvrirPhotoPleinEcran(this)" data-url="' + pnj.photoUrl + '" data-nom="' + safeName + '" ' +
      'style="width:90px;height:90px;border-radius:6px;border:2px solid ' + col + ';overflow:hidden;cursor:pointer;position:relative">' +
      '<img src="' + pnj.photoUrl + '" style="width:100%;height:100%;object-fit:cover;object-position:' + (pnj.photoPos || '50% 15%') + '"/>' +
      '<div style="position:absolute;bottom:0;right:0;background:rgba(0,0,0,.6);padding:2px 4px;font-size:9px;color:' + col + '">🔍</div>' +
      '</div></div>';
  }
  const av = PNJ_AVATAR[pnj.job] || PNJ_AVATAR.default;
  const col = empireColor || av.color;
  return '<div style="width:56px;height:56px;border-radius:50%;border:2px solid ' + col + ';background:rgba(0,0,0,0.3);display:flex;align-items:center;justify-content:center;flex-shrink:0">' +
    '<i class="ti ' + av.icon + '" style="font-size:1.4rem;color:' + col + '"></i>' +
    '</div>';
}


function ouvrirPhotoPleinEcran(el) {
  const url = el.dataset?.url || el;
  const nom = el.dataset?.nom || '';
  // Créer overlay plein écran
  const overlay = document.createElement('div');
  overlay.id = 'photo-overlay';
  overlay.onclick = () => overlay.remove();
  overlay.style.cssText = 'position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,0.92);z-index:99999;display:flex;flex-direction:column;align-items:center;justify-content:center;cursor:pointer';
  overlay.innerHTML =
    '<div style="font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;color:#C9A84C;margin-bottom:.8rem">' + nom.replace(' (PNJ)','') + '</div>' +
    '<img src="' + url + '" style="max-width:90vw;max-height:85vh;object-fit:contain;border:1px solid #3a2a10"/>' +
    '<div style="font-size:.65rem;color:#4a4030;margin-top:.6rem">Cliquer pour fermer</div>';
  document.body.appendChild(overlay);
}


function openPnjModal(encodedPnj) {
  let pnj;
  try { pnj = JSON.parse(decodeURIComponent(encodedPnj)); }
  catch(e) { return; }

  // Cadavre — photo plein écran uniquement, pas de dialogue
  if (pnj.terrainPnjId === 'cadavre') {
    ouvrirPhotoCadavre(JSON.stringify({
      photoUrl: pnj.photoUrl, photoPos: pnj.photoPos,
      role: pnj.role, trait: pnj.trait
    }));
    return;
  }

  const isPJ = pnj.isPJ === true;
  document.getElementById('modal-pnj').classList.add('open');
  document.getElementById('pnj-modal-title').textContent = pnj.name?.replace(' (PNJ)', '') || 'Inconnu';

  // Avatar CSS par type de PNJ
  const empireCol = COUNTRIES[state.country]?.col || '#C9A84C';
  const avatarHtml = typeof getPnjAvatar === 'function' ? getPnjAvatar(pnj, empireCol) : '';
  const avatarEl = document.getElementById('pnj-avatar-container');
  if (avatarEl) avatarEl.innerHTML = avatarHtml;

  // Rôle et trait de personnalité
  const roleEl = document.getElementById('pnj-role-display');
  if (roleEl) roleEl.textContent = pnj.role?.replace(' (PNJ)', '') || '';
  const traitEl = document.getElementById('pnj-trait-display');
  const pnjKey = pnj.name?.replace(' (PNJ)', '').trim();
  const perso = typeof PNJ_PERSONALITIES !== 'undefined' ? PNJ_PERSONALITIES[pnjKey] : null;
  if (traitEl) traitEl.textContent = perso?.trait || '';
  const speech = document.getElementById('pnj-speech');
  speech.innerHTML = '<div class="pnj-loading"><span class="spin"></span> En train de repondre...</div>';
  const enc = encodePnjSafe(pnj);

  let actionBtns = '';
  const pnjSafeName = pnj.name.replace(/'/g, '');
  const pnjSafeRole = (pnj.role||'').replace(/'/g, '');
  const pnjRel = pnj.rel || 'neutral';

  if (isPJ) {
    const inGroup = state.group && state.group.members && state.group.members.includes(pnj.name);
    const pnjJson = encodePnjSafe(pnj);
    actionBtns += (!inGroup
      ? '<button class="pnj-action-btn" onclick="rejoindrePJ(decodeURIComponent(\'' + pnjJson + '\'))"><i class="ti ti-users" style="font-size:.85rem"></i> Rejoindre ce joueur</button>'
      : '<button class="pnj-action-btn" onclick="quitterGroupe()"><i class="ti ti-user-minus" style="font-size:.85rem"></i> Quitter le groupe</button>');
    actionBtns += '<button class="pnj-action-btn" onclick="addContactByName(\'' + pnjSafeName + '\',\'' + pnjSafeRole + '\',\'' + pnjRel + '\')"><i class="ti ti-user-plus" style="font-size:.85rem"></i> Ajouter au repertoire</button>';
    actionBtns += '<button class="pnj-action-btn" onclick="document.getElementById(\'modal-pnj\').classList.remove(\'open\');composerMailPour(\'' + pnjSafeName + '\')"><i class="ti ti-mail" style="font-size:.85rem"></i> Envoyer un mail</button>';
  }

  if (!isPJ) {
    const dejaDansRep = (state.contacts || []).some(c => c.name === pnj.name);
    if (!dejaDansRep) {
      actionBtns += '<button class="pnj-action-btn" onclick="addContactByName(\'' + pnjSafeName + '\',\'' + pnjSafeRole + '\',\'' + pnjRel + '\')"><i class="ti ti-user-plus" style="font-size:.85rem"></i> Ajouter au repertoire</button>';
    }
  }

  actionBtns += '<button class="pnj-action-btn" onclick="ouvrirDonPnjModal(\'' + enc + '\')"><i class="ti ti-coins" style="font-size:.85rem"></i> Donner de l\'argent</button>';

  const objetsDispos = (state.inventory || []).filter(i => i.type !== 'acte_officiel');
  if (objetsDispos.length > 0) {
    actionBtns += '<button class="pnj-action-btn" onclick="ouvrirDonObjetPnjModal(\'' + enc + '\')"><i class="ti ti-package" style="font-size:.85rem"></i> Donner un objet</button>';
  }

  const tractsDispos = (state.inventory || []).filter(i => i.type === 'tract');
  if (tractsDispos.length > 0) {
    if (isPJ) {
      actionBtns += '<button class="pnj-action-btn" onclick="document.getElementById(\'modal-pnj\').classList.remove(\'open\');donnerTracts(\'' + pnjSafeName + '\')"><i class="ti ti-files" style="font-size:.85rem"></i> Donner des tracts</button>';
    } else {
      actionBtns += '<button class="pnj-action-btn" onclick="document.getElementById(\'modal-pnj\').classList.remove(\'open\');distribuerTractPNJ(\'' + pnjSafeName + '\')"><i class="ti ti-file-description" style="font-size:.85rem"></i> Distribuer un tract</button>';
    }
  }

  if (pnj.rel === 'enemy') {
    actionBtns += '<button class="pnj-action-btn" onclick="talkToPnj(\'' + enc + '\', \'confrontation\')"><i class="ti ti-sword" style="font-size:.85rem"></i> Confronter</button>';
  }


  // Recruter comme employé (tous PNJ sauf escort qui a son propre bouton)
  if (!isPJ && pnj.job !== 'escort') {
    const nomCourt = pnj.name.replace(' (PNJ)', '').replace(/'/g, '');
    const dejEmploye = (state.employes || []).some(e => e.nom === nomCourt);
    if (!dejEmploye) {
      actionBtns += '<button class="pnj-action-btn" onclick="ouvrirModalRecrutPnj(\'' + enc + '\')"><i class="ti ti-user-plus" style="font-size:.85rem"></i> Recruter comme employé</button>';
    } else {
      const empData = (state.employes || []).find(e => e.nom === nomCourt);
      if (empData && !empData.inGroupe && empData.buildingId === state.currentBuilding && empData.roomId === state.currentRoom) {
        actionBtns += '<button class="pnj-action-btn" onclick="recupererPnjDansGroupe(\'' + nomCourt + '\')"><i class="ti ti-users" style="font-size:.85rem"></i> Rejoindre le groupe</button>';
      }
      if (empData && empData.inGroupe) {
        actionBtns += '<button class="pnj-action-btn" onclick="laisserPnjEnPlace(\'' + nomCourt + '\')"><i class="ti ti-map-pin" style="font-size:.85rem"></i> Laisser ici</button>';
      }
    }
  }

  // Recruter escort
  if (pnj.job === 'escort') {
    const escortNom = pnj.name.replace(' (PNJ)', '').replace(/'/g, '');
    actionBtns += '<button class="pnj-action-btn" onclick="ouvrirRecrutementEscort(\'' + escortNom + '\')"><i class="ti ti-heart" style="font-size:.85rem"></i> Recruter comme escort</button>';
  }

  // Interroger l'hotesse des objets trouves sur ses souvenirs
  if (pnj.job === 'hotesse_objets_trouves') {
    actionBtns += '<button class="pnj-action-btn" onclick="document.getElementById(\'modal-pnj\').classList.remove(\'open\');ouvrirModalInterrogerAccueil()"><i class="ti ti-message-question" style="font-size:.85rem"></i> Demander des confidences</button>';
  }

  const encCible = encodePnjSafe(pnj);
  actionBtns += '<button class="pnj-action-btn" style="color:#cc4444;border-color:#3a1010" onclick="document.getElementById(\'modal-pnj\').classList.remove(\'open\');ouvrirModalAssassinat(\'' + encCible + '\')"><i class="ti ti-skull" style="font-size:.85rem"></i> Assassiner</button>';
  document.getElementById('pnj-actions').innerHTML = actionBtns +
    (isPJ
      ? '<div style="margin-top:.6rem;font-size:.7rem;color:#6a5a30;font-style:italic">C\'est un vrai joueur — utilisez le mail pour lui parler, l\'IA ne repond pas a sa place.</div>'
      : '<div style="display:flex;gap:.4rem;margin-top:.5rem">' +
        '<input id="pnj-question-libre" type="text" style="flex:1;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem .6rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none" placeholder="Posez votre question..." onkeydown="handlePnjKey(event)" />' +
        '<button onclick="envoyerQuestion()" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.4rem .7rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer"><i class="ti ti-send" style="font-size:.8rem"></i></button>' +
        '</div>');

  // Stocker l'enc pour envoyerQuestion
  state._currentPnjEnc = enc;

  // Recharger l'historique de la conversation du jour (uniquement pour les PNJ — jamais pour un vrai joueur)
  if (!isPJ) {
    const pnjNameClean = pnj.name?.replace(' (PNJ)', '').trim();
    const convKeyOpen = 'conv_' + (pnjNameClean||'pnj') + '_day' + (state.day||1);
    const histOpen = state.pnjConversations?.[convKeyOpen] || [];

    if (histOpen.length >= 2) {
      // Afficher le dernier échange
      const lastReply = histOpen.filter(h => h.role === 'assistant').slice(-1)[0];
      if (lastReply) {
        const speechEl = document.getElementById('pnj-speech');
        if (speechEl) speechEl.textContent = lastReply.content;
      }
    } else {
      talkToPnj(enc, 'bonjour');
    }
  } else {
    const speechEl = document.getElementById('pnj-speech');
    if (speechEl) speechEl.textContent = '';
  }
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

  // Si c'est un journaliste, générer une réaction au forum
  const pnjKey = pnj.name?.replace(' (PNJ)', '').trim();
  const isJournaliste = pnj.job === 'journaliste' || pnj.job === 'redacteur';
  if (isJournaliste && !action) {
    const reaction = await genererReactionJournaliste();
    if (reaction) {
      const speech = document.getElementById('pnj-speech');
      if (speech) speech.textContent = reaction.texte;
      return;
    }
  }

  // Fiche personnalité du PNJ
  const perso = PNJ_PERSONALITIES[pnjKey];
  const empireStyle = EMPIRE_STYLES[state.country] || EMPIRE_STYLES.republic;

  // Récupérer les derniers posts du forum local pour le contexte
  const recentPosts = (FORUM_TOPICS['local'] || []).slice(0, 2).map(t =>
    `"${t.title}" (par ${t.author})`).join(', ');
  const forumContext = recentPosts ? `Actualité du forum local : ${recentPosts}.` : '';

  // Événements politiques
  const politicalContext = state.poste
    ? `Le joueur occupe le poste de ${state.poste.name}.`
    : 'Le joueur n\'a pas de poste officiel.';
  const recherchéContext = state.recherche?.length > 0
    ? 'ATTENTION : le joueur est recherché par les autorités.'
    : '';

  const prompt = `Tu joues un personnage dans Res Publica, un jeu de rôle politique parodique et satirique.
L'empire est ${co?.n} (${empireStyle.tone}).
La religion locale est ${empireStyle.religion}. Le chef suprême est ${empireStyle.leader}.

Ton personnage : ${pnj.name?.replace(' (PNJ)', '')}, ${pnj.role}.
${perso ? `Ta personnalité : ${perso.trait}` : `Tu es un PNJ typique de ${co?.n}.`}
${perso ? `Ton style : ${perso.style}` : ''}
Relation avec le joueur : ${pnj.rel === 'ally' ? 'allié de confiance' : pnj.rel === 'enemy' ? 'ennemi déclaré' : 'neutre'}.

Le joueur : ${char?.name || 'Inconnu'}, ${ar?.name || 'citoyen'}.
${politicalContext} ${recherchéContext}
${forumContext}

${isQuestion ? `Le joueur te pose cette question : "${action}". Réponds en restant dans ton personnage.` : `Le joueur ${actionDesc}.`}

RÈGLES ABSOLUES :
- 2 phrases maximum, jamais plus
- Reste dans ton personnage parodique
- Intègre naturellement les éléments de l'empire (religion locale, monnaie ${empireStyle.currency}, ambiance)
- Jamais de vrais noms de dieux ou religions réelles
- Réponds UNIQUEMENT avec ta réplique, sans guillemets ni introduction`;

  // Récupérer l'historique de la conversation du jour
  const pnjKey2 = pnj.name?.replace(' (PNJ)', '').trim();
  const convKey = 'conv_' + (pnjKey2||'pnj') + '_day' + (state.day||1);
  if (!state.pnjConversations) state.pnjConversations = {};
  if (!state.pnjConversations[convKey]) state.pnjConversations[convKey] = [];
  const history = state.pnjConversations[convKey];

  // Construire les messages avec historique
  const messages = [
    { role: 'user', content: prompt }
  ];
  // Ajouter les échanges précédents (max 6 pour rester léger)
  const recentHistory = history.slice(-6);
  if (recentHistory.length > 0) {
    messages[0].content = prompt + '\n\nHistorique du jour :\n' +
      recentHistory.map(h => (h.role === 'user' ? 'Joueur: ' : pnjKey2 + ': ') + h.content).join('\n');
  }

  try {
    const resp = await fetch('/api/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: 'claude-haiku-4-5-20251001',
        max_tokens: 150,
        messages
      })
    });
    if (!resp.ok) throw new Error('HTTP ' + resp.status);
    const data = await resp.json();
    const text = data.content?.[0]?.text;
    if (text) {
      speech.textContent = text;
      // Sauvegarder dans l'historique
      history.push({ role: 'user', content: action });
      history.push({ role: 'assistant', content: text });
      state.pnjConversations[convKey] = history;
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


// =====================
// COMMUNICATION RÉELLE ENTRE JOUEURS (remplace les fausses notifications locales)
// =====================

// Trouve le nom du PJ qui occupe reellement un poste donne (via Supabase, pas le state local)
async function getTitulairePoste(posteId) {
  if (typeof sbListPersonnages !== 'function') return null;
  try {
    const joueurs = await sbListPersonnages() || [];
    const titulaire = joueurs.find(j => j.country === state.country && j.poste?.id === posteId);
    return titulaire?.name || null;
  } catch(e) { return null; }
}

// Trouve le responsable de la loge maçonnique (chef d'organisation type 'loge')
function getResponsableLoge() {
// Structure plate pour les organisations (prepare le support multi-empire futur)
// state.organisations est une liste a plat ; country_origine = empire de creation (regles/grades)
function getMesOrgasPays(country) {
  return (state.organisations || []).filter(o => o.country_origine === (country || state.country));
}
function getOrgaById(orgaId) {
  return (state.organisations || []).find(o => o.id === orgaId);
}

// Sauvegarde une organisation modifiee vers Supabase (appelee apres chaque action qui change son etat)
function sauvegarderOrga(orga) {
  if (!orga) return;
  if (typeof sbSaveOrganisation === 'function') sbSaveOrganisation(orga).catch(() => {});
}

// Charge toutes les organisations depuis Supabase au demarrage (remplace l'ancien state.orgasEmpire local perdu au rafraichissement)
async function chargerOrganisations() {
  if (typeof sbLoadOrganisations !== 'function') return;
  try {
    const orgas = await sbLoadOrganisations();
    state.organisations = orgas;
    // Rafraichir l'affichage si la fiche est ouverte sur l'onglet organisations
    const tab = document.querySelector('#vue-self .piece-tab.active');
    if (tab && document.getElementById('vue-self')?.classList.contains('active')) {
      switchSelfTab('orgas', null);
    }
  } catch(e) { console.warn('chargerOrganisations error', e); }
}

  const orgas = getMesOrgasPays();
  const loge = orgas.find(o => o.type === 'loge');
  return loge?.chef || null;
}

// Envoie une vraie notification a un autre joueur (mail Supabase). Si destinataire inconnu/absent, notifie le joueur courant a la place pour ne pas perdre l'information.
async function envoyerNotificationVraiJoueur(destinataire, sujet, corps) {
  const from = state.char?.name || 'Anonyme';
  const h = String(state.hour || 8).padStart(2,'0');
  const time = 'Jour ' + (state.day || 1) + ' · ' + h + 'h';

  if (destinataire && typeof sbSendMail === 'function') {
    await sbSendMail(from, destinataire, sujet, corps, time).catch(() => {});
  } else {
    // Pas de titulaire connu — on garde une trace locale pour ne pas perdre l'info
    addMailNotification('Système', sujet + ' (en attente de titulaire)', corps);
  }
}

// Loge — demander le responsable
function logeDemanderResponsable() {
  const speech = document.getElementById('pnj-speech');
  speech.textContent = "Le portier disparait un instant puis revient. Il dit : Je lui transmets votre demande. Le Venerable Maitre vous repondra des qu'il en aura pris connaissance.";
  envoyerNotificationVraiJoueur(getResponsableLoge?.() || null, 'Demande d\'audience', (state.char?.name||'Anonyme') + ' sollicite un entretien avec le Venerable Maitre de la Loge.');
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
  document.getElementById('postes-modal-title').textContent = 'Marchander un vote';
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
    showToast('Refuse !', "Le depute n' pas accepte.", false);
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
          : p.holder === state.char?.name
            ? `<button class="poste-btn" style="opacity:.4;cursor:default;color:#C9A84C">Votre poste</button>`
            : p.holder.startsWith('PNJ')
              ? `<button class="poste-btn pnj" onclick="postulerPoste('${p.id}','${p.name}')">Deloger le PNJ</button>`
              : `<button class="poste-btn" style="opacity:.4;cursor:default">Occupe</button>`
        }
      </div>`).join('')}
  `;

  document.getElementById('modal-postes').classList.add('open');
}




// =====================
// JOURNALISTES PNJ RÉACTIFS
// =====================
const JOURNALISTES_PNJ = {
  republic: {
    name: 'Gustave Encre',
    journal: "L'Autruche Entravée",
    trait: "Journaliste d'investigation alcoolique. Déterre les scandales par accident en cherchant ses clés. A une source dans chaque ministère mais ne sait plus lequel.",
    style: "cynique désabusé, métaphores journalistiques épuisées, boit du café tiède depuis 1987"
  },
  narco: {
    name: 'El Editor',
    journal: 'El Narco Times',
    trait: "Rédacteur en chef qui blanchit les nouvelles comme El Don blanchit l'argent. Chaque article est une œuvre de fiction assumée.",
    style: "propagandiste jovial, español aproximativo, cite El Don dans chaque paragraphe"
  },
  soviet: {
    name: 'Rédacteur Vérité',
    journal: 'La Pravdovka',
    trait: "Journaliste du Parti qui vérifie trois fois si une information est approuvée avant de la publier. A publié le même article depuis 1973 avec des noms différents.",
    style: "zèle idéologique mécanique, vérité = ce que dit le Parti, enthousiasme performatif"
  },
  khalija: {
    name: 'Rédacteur Al-Vérité',
    journal: 'Le Minaret Doré',
    trait: "Journaliste royal qui ne publie que ce que le Palais approuve. Ses éditoriaux commencent tous par une bénédiction du Sheikh et finissent par une autre.",
    style: "déférence royale absolue, Loukoum Divin dans chaque titre, vérité = volonté du Sheikh"
  }
};

async function genererReactionJournaliste() {
  const journaliste = JOURNALISTES_PNJ[state.country];
  if (!journaliste) return null;

  // Récupérer les derniers topics du forum local
  const topics = FORUM_TOPICS[state.country === 'republic' ? 'local' : 'local'] || [];
  const recentTopics = topics.slice(0, 3);
  if (recentTopics.length === 0) return null;

  const topicsText = recentTopics.map(t =>
    `"${t.title}" (par ${t.author})`
  ).join(', ');

  const co = COUNTRIES[state.country];
  const empireStyle = EMPIRE_STYLES[state.country] || EMPIRE_STYLES.republic;

  const prompt = `Tu es ${journaliste.name}, journaliste de "${journaliste.journal}" dans l'empire ${co?.n}.
Ta personnalité : ${journaliste.trait}
Ton style : ${journaliste.style}
Religion locale : ${empireStyle.religion}. Chef suprême : ${empireStyle.leader}.

Sujets récents sur le forum local : ${topicsText}

Rédige UNE courte réaction journalistique (2-3 phrases max) à ces actualités.
Style parodique et satirique. Intègre les éléments de l'empire naturellement.
PAS de vrais dieux ou religions. Réponds UNIQUEMENT avec ta réaction, sans introduction.`;

  try {
    const resp = await fetch('/api/chat', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({
        model: 'claude-sonnet-4-5',
        max_tokens: 150,
        messages: [{ role: 'user', content: prompt }]
      })
    });
    if (!resp.ok) return null;
    const data = await resp.json();
    return { journaliste, texte: data.content?.[0]?.text };
  } catch(e) { return null; }
}

async function afficherReactionJournaliste() {
  const reaction = await genererReactionJournaliste();
  if (!reaction) return;

  // Afficher dans le journal des événements
  addJournalEntry(
    `📰 ${reaction.journaliste.journal} — ${reaction.journaliste.name} : "${reaction.texte}"`,
    'event-info'
  );
}


// =====================
// ESCORTS — INFORMATIONS ET PIÈGE
// =====================

// =====================
// UTILITAIRE — Liste PJ + PNJ connus
// =====================
function getAllPJsAndPNJs() {
  const result = [];
  // PJ connus (depuis state.pjConnus ou contacts)
  const pjConnus = state.pjConnus || [];
  pjConnus.forEach(nom => {
    if (!result.some(r => r.name === nom)) {
      result.push({ name: nom, role: 'Joueur', isPJ: true });
    }
  });
  // Contacts du répertoire
  (state.contacts || []).forEach(c => {
    if (!result.some(r => r.name === c.name)) {
      result.push({ name: c.name, role: c.role || 'Contact', isPJ: false });
    }
  });
  // PNJ du bâtiment actuel
  if (state.currentBuilding && state.currentRoom) {
    const room = BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom];
    (room?.persons || []).forEach(p => {
      if (!result.some(r => r.name === p.name)) {
        result.push({ name: p.name, role: p.role || 'PNJ', isPJ: false });
      }
    });
  }
  // Si toujours vide, retourner une cible générique
  if (result.length === 0) {
    result.push({ name: 'Un notable local', role: 'Personnage politique', isPJ: false });
  }
  return result;
}

async function doEscortInfos() {
  const cibles = getAllPJsAndPNJs().filter(c => c.name !== state.char?.name);
  if (cibles.length === 0) { showToast('Personne à cibler', 'Aucune cible disponible.', false); return; }

  const co = COUNTRIES[state.country];
  const cur = co?.cur || 'FR';

  if (state.arg < 300) { showToast('Fonds insuffisants', `300 ${cur} requis.`, false); return; }
  state.arg -= 300;

  // Choisir une cible au hasard parmi les PJ/PNJ connus
  const cible = cibles[Math.floor(Math.random() * Math.min(3, cibles.length))];

  const prompt = `Tu joues dans Res Publica, jeu politique parodique.
Une escort de luxe (${state.country === 'republic' ? 'Roxane Velours' : state.country === 'narco' ? 'Lola Discreta' : 'Natasha Privilege'}) a recueilli des informations compromettantes sur ${cible.name} (${cible.role || 'personnage politique'}) dans l'empire ${co?.n}.
Génère UNE révélation compromettante, parodique et drôle (2 phrases max). Style scandale politique. Pas de vrais noms de personnes réelles. Pas de religions réelles.`;

  try {
    const resp = await fetch('/api/chat', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({ model: 'claude-haiku-4-5-20251001', max_tokens: 60, messages: [{ role: 'user', content: prompt }] })
    });
    const data = await resp.json();
    const info = data.content?.[0]?.text?.trim() || 'Information confidentielle obtenue.';

    // Créer un kompromat dans l'inventaire
    addToInventory({
      id: 'kompromat-' + Date.now(),
      name: 'Kompromat sur ' + cible.name,
      icon: 'ti-file-shredder',
      desc: info,
      type: 'kompromat',
      cible: cible.name,
      legal: false
    });

    state.inf = Math.min(100, (state.inf || 0) + 5);
    updateUI();
    addJournalEntry('Kompromat obtenu sur ' + cible.name + '. Ajouté à l\'inventaire.', 'event-info');
    showToast('Information obtenue !', info.substring(0, 100) + (info.length > 100 ? '...' : ''), true, true);

  } catch(e) {
    showToast('Erreur', 'Impossible d\'obtenir l\'information.', false);
  }
}

function doEscortPiege() {
  const co = COUNTRIES[state.country];
  const cur = co?.cur || 'FR';
  const cost = 800;

  // Sélectionner une cible PJ dans le répertoire
  const pjContacts = (state.contacts || []).filter(c => c.isPJ || c.type === 'pj');
  if (pjContacts.length === 0) {
    showToast('Aucune cible', 'Vous devez avoir des PJ dans votre répertoire pour organiser un piège.', false);
    return;
  }
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }

  // Modal de sélection de cible
  document.getElementById('postes-modal-title').textContent = '🕵 Choisir une cible';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +
    '<div style="font-size:.75rem;color:#8a8060;font-style:italic;margin-bottom:.7rem">Sélectionnez le PJ à piéger. Coût : ' + cost + ' ' + cur + '.</div>' +
    pjContacts.map(c =>
      '<div onclick="confirmerEscortPiege(\'' + c.name.replace(/'/g,'') + '\')" style="display:flex;align-items:center;gap:.6rem;padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;cursor:pointer" onmouseover="this.style.background=\'#1a1005\'" onmouseout="this.style.background=\'#0f0d05\'">' +
        '<i class="ti ti-user" style="font-size:.9rem;color:#8a6a20"></i>' +
        '<div><div style="font-size:.82rem;color:#c0b090">' + c.name + '</div>' +
        '<div style="font-size:.65rem;color:#4a4030">' + (c.role||'PJ') + '</div></div>' +
      '</div>'
    ).join('') +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerEscortPiege(nomCible) {
  const co = COUNTRIES[state.country];
  const cur = co?.cur || 'FR';
  const cost = 800;

  document.getElementById('modal-postes').classList.remove('open');

  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  state.arg -= cost;

  // Stats commanditaire
  const dup = state.char?.stats?.DUP || 8;
  const dis = state.dis || 50;

  // On simule les stats de la cible (on ne les a pas côté client)
  const cibleDUP = Math.floor(Math.random() * 6) + 6; // entre 6 et 12
  const cibleDIS = Math.floor(Math.random() * 40) + 30; // entre 30 et 70

  // Jet de succès
  const taux = Math.min(80, 30 + Math.floor(dup * 2) - Math.floor(cibleDUP * 1.5));
  const roll = Math.floor(Math.random() * 100) + 1;

  if (roll <= taux) {
    // SUCCÈS
    const prompt = 'Res Publica, jeu politique parodique. ' + nomCible + ' vient d\'être piégé(e) par une escort dans un scandale compromettant. Génère UN titre de scandale parodique (1 phrase max, style journal à scandales).';
    let scandale = nomCible + ' impliqué(e) dans un scandale compromettant avec une escort.';
    try {
      const resp = await fetch('/api/chat', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({ model: 'claude-haiku-4-5-20251001', max_tokens: 60, messages: [{ role: 'user', content: prompt }] })
      });
      const data = await resp.json();
      scandale = data.content?.[0]?.text?.trim() || scandale;
    } catch(e) {}

    // Effets sur commanditaire
    state.inf = Math.min(100, (state.inf||0) + 10);
    state.pop = Math.min(100, (state.pop||0) + 5);

    // Kompromat généré
    addToInventory({
      name: 'Kompromat sur ' + nomCible,
      icon: 'ti-file-shredder',
      type: 'kompromat',
      cible: nomCible,
      desc: scandale,
      legal: false,
      expireDay: (state.day||1) + 10
    });

    updateUI();
    addExternalEvent('📰 SCANDALE : ' + scandale);
    addJournalEntry('Piège réussi sur ' + nomCible + '. Scandale : "' + scandale.substring(0,60) + '"', 'event-good');
    showToast('Piège réussi !', scandale, true, true);

  } else {
    // ÉCHEC — argent perdu, la cible peut enquêter
    updateUI();
    addJournalEntry('Piège raté sur ' + nomCible + '. -' + cost + ' ' + cur + ' perdus.', 'event-bad');
    showToast('Piège raté', nomCible + ' a éventé la manœuvre. Argent perdu.', false);

    // Jet d\'enquête de la cible contre le commanditaire
    const tauxEnquete = Math.min(70, Math.floor(cibleDUP * 4) + Math.floor(cibleDIS / 10));
    const rollEnquete = Math.floor(Math.random() * 100) + 1;
    if (rollEnquete <= tauxEnquete) {
      // Cible trouve le commanditaire
      const tauxIdentif = Math.min(80, tauxEnquete - Math.floor(dup * 2) - Math.floor(dis / 10));
      const rollIdentif = Math.floor(Math.random() * 100) + 1;
      if (rollIdentif <= tauxIdentif) {
        state.pop = Math.max(0, (state.pop||0) - 15);
        state.dis = Math.max(0, (state.dis||50) - 10);
        updateUI();
        addExternalEvent('📰 ' + nomCible + ' révèle avoir été la cible d\'un complot orchestré par ' + (state.char?.name||'un personnage politique') + ' !');
        addJournalEntry('Enquête de ' + nomCible + ' : vous avez été identifié(e). -15 POP -10 DIS.', 'event-bad');
        showToast('Identifié(e) !', nomCible + ' vous a démasqué(e). -15 POP -10 DIS.', false);
      } else {
        addJournalEntry('La cible enquête mais ne vous retrouve pas.', 'event-info');
      }
    }
  }
}



// =====================
// PLAN VISUEL DE LA VILLE
// =====================

// Disposition des bâtiments sur le plan (x, y, w, h)
const PLAN_LAYOUTS = {
  capitale: {
    'palais-presidentiel':          [14,  12, 104, 60],
    'assemblee':                    [14,  80, 104, 58],
    'tribunal':                    [152,  12,  96, 60],
    'palais-gouvernement':         [152,  80,  96, 58],
    'banque-nationale':            [286,  12,  80, 60],
    'banque-privee':               [376,  12,  72, 60],
    'hotel-republica':             [286,  80, 162, 58],
    'la-tribune':                  [488,  12,  84, 60],
    'loge-maconnique':             [582,  12,  84, 60],
    'universite':                  [488,  80,  88, 58],
    'clinique-privee':             [584,  80,  82, 58],
    'commissariat':                 [14, 168, 104,110],
    'armurerie':                   [148, 168, 100, 52],
    'dispensaire-public':          [148, 228, 100, 50],
    'marche':                      [286, 168, 168,110],
    'tabernacle-impots':           [488, 168,  84, 52],
    'mairie-capitale':             [582, 168,  84,110],
    'terrain-a-batir-1':           [488, 228,  84, 50],
    'centre-multinodal-luthecia':  [ 14, 330, 104,104],
    'siege-syndical':              [148, 330, 100, 52],
    'usine-principale':            [148, 390, 100, 52],
    'terrain-a-batir-2':           [286, 330,  76,104],
    'terrain-a-batir-3':           [372, 330,  76,104],
    'port-sainte-marie':           [488, 330, 178,104],
    'qhs-prison':                  [ 14, 476, 104, 96],
    'caserne-militaire':           [148, 476, 100, 96],
    'terrain-a-batir-4':           [286, 476,  76, 96],
    'terrain-a-batir-5':           [372, 476,  76, 96],
    'terrain-a-batir-6':           [488, 476,  84, 96],
    'terrain-a-batir-7':           [582, 476,  84, 96],
  },
  ville_a: {
    'hotel-port':                  [ 14,  12, 100, 60],
    'mairie':                      [ 14,  80, 100, 58],
    'banque-locale':               [152,  12,  96, 60],
    'dispensaire-public-v':        [152,  80,  96, 58],
    'commissariat-local':          [286,  12,  80, 60],
    'bar-des-pecheurs':            [376,  12,  72, 60],
    'imprimerie-librairie':        [286,  80, 162, 58],
    'centre-multinodal-port-sainte-marie': [14, 168, 120, 100],
    'port-sainte-marie':           [152, 168, 130, 100],
    'terrain-a-batir-2':           [298, 168,  76, 100],
    'terrain-a-batir-3':           [384, 168,  76, 100],
    'terrain-a-batir-4':           [470, 168,  76, 100],
    'terrain-a-batir-5':           [556, 168,  76, 100],
  },
  ville_b: {
    'hotel-mineur':                [ 14,  12, 100, 60],
    'mairie':                      [ 14,  80, 100, 58],
    'banque-locale':               [152,  12,  96, 60],
    'dispensaire-public-v':        [152,  80,  96, 58],
    'commissariat-local':          [286,  12,  80, 60],
    'siege-syndical':              [376,  12,  72, 60],
    'usine-principale':            [286,  80, 162, 58],
    'centre-multinodal-montrouge': [ 14, 168, 120, 100],
    'terrain-a-batir-3':           [152, 168,  76, 100],
    'terrain-a-batir-4':           [238, 168,  76, 100],
    'terrain-a-batir-5':           [324, 168,  76, 100],
    'terrain-a-batir-6':           [410, 168,  76, 100],
    'terrain-a-batir-7':           [496, 168,  76, 100],
  }
};

// Icônes emoji par bâtiment
const PLAN_ICONS = {
  'palais-presidentiel': '🏛', 'palais-gouvernement': '🏛',
  'assemblee': '⚖', 'tribunal': '⚖',
  'banque-nationale': '🏦', 'banque-privee': '🔐', 'banque-locale': '🏦',
  'hotel-republica': '🏨', 'hotel-port': '🏨', 'hotel-mineur': '🏨',
  'clinique-privee': '🏥', 'dispensaire-public': '🏥', 'dispensaire-public-v': '🏥',
  'commissariat': '🛡', 'commissariat-local': '🛡',
  'la-tribune': '📰', 'imprimerie-librairie': '🖨',
  'loge-maconnique': '⬡', 'universite': '🎓',
  'marche': '🛒', 'armurerie': '🛡',
  'siege-syndical': '👥', 'usine-principale': '🏭',
  'mairie-capitale': '🏫', 'mairie': '🏫',
  'tabernacle-impots': '⛪', 'laboratoire-priere': '⛪',
  'kolkhoze-spirituel': '🚜', 'patisserie-sacree': '🧁',
  'centre-multinodal-luthecia': '🚉',
  'centre-multinodal-port-sainte-marie': '🚉',
  'centre-multinodal-montrouge': '🚉',
  'port-sainte-marie': '⚓', 'port-novomirsk': '⚓',
  'port-ciudad-roja': '⚓', 'port-al-madina': '⚓',
  'bar-des-pecheurs': '🐟', 'caserne-militaire': '🎖',
  'qhs-prison': '🔒',
  'default': '🏢'
};

function ouvrirPlanVille(countryId, cityId, readOnly) {
  countryId = countryId || state.country;
  cityId = cityId || state.currentCity;
  readOnly = readOnly || false;

  const co = COUNTRIES[countryId];
  const world = WORLD[countryId];
  const city = world?.[cityId];
  if (!city) return;

  const empireColor = co?.col || '#C9A84C';
  const layout = PLAN_LAYOUTS[cityId] || PLAN_LAYOUTS.capitale;
  const buildings = city.buildings || [];

  // Rues : définies par les espaces entre îlots
  const SVG_W = 680, SVG_H = 600;

  let svg = '<svg viewBox="0 0 ' + SVG_W + ' ' + SVG_H + '" xmlns="http://www.w3.org/2000/svg" style="width:100%;height:auto;display:block">';

  // Style animation
  svg += '<defs><style>@keyframes pulse{0%,100%{r:5;opacity:1}50%{r:9;opacity:.3}}.pd{animation:pulse 1.4s ease-in-out infinite}</style></defs>';

  // Fond
  svg += '<rect width="' + SVG_W + '" height="' + SVG_H + '" fill="#111008"/>';

  // Rues principales
  svg += '<rect x="0" y="290" width="' + SVG_W + '" height="24" fill="#1e1c10"/>';
  svg += '<rect x="258" y="0" width="20" height="' + SVG_H + '" fill="#1e1c10"/>';
  svg += '<rect x="0" y="148" width="' + SVG_W + '" height="14" fill="#1a1810"/>';
  svg += '<rect x="0" y="448" width="' + SVG_W + '" height="14" fill="#1a1810"/>';
  svg += '<rect x="128" y="0" width="12" height="' + SVG_H + '" fill="#1a1810"/>';
  svg += '<rect x="468" y="0" width="12" height="' + SVG_H + '" fill="#1a1810"/>';

  // Tirets
  svg += '<line x1="0" y1="302" x2="' + SVG_W + '" y2="302" stroke="#2e2a14" stroke-width="1" stroke-dasharray="16,10"/>';
  svg += '<line x1="268" y1="0" x2="268" y2="' + SVG_H + '" stroke="#2e2a14" stroke-width="1" stroke-dasharray="16,10"/>';

  // Parc central
  svg += '<rect x="282" y="168" width="74" height="110" rx="5" fill="#0d1807"/>';
  svg += '<ellipse cx="302" cy="196" rx="13" ry="11" fill="#122010"/>';
  svg += '<ellipse cx="326" cy="185" rx="11" ry="10" fill="#162812"/>';
  svg += '<ellipse cx="314" cy="212" rx="10" ry="9" fill="#142210"/>';
  svg += '<ellipse cx="336" cy="205" rx="10" ry="9" fill="#122010"/>';

  // Bâtiments
  buildings.forEach(id => {
    const pos = layout[id];
    if (!pos) return;
    const b = BUILDINGS[id];
    if (!b) return;
    const [bx, by, bw, bh] = pos;
    const ctx = city.buildingContext?.[id];
    const localName = ctx?.name || b.shortName || b.name || id;
    const icon = PLAN_ICONS[id] || PLAN_ICONS.default;
    const isHere = id === state.currentBuilding && countryId === state.country;
    const isTerrain = id.startsWith('terrain-a-batir');
    const cx = bx + bw/2;

    const borderColor = isHere ? empireColor : (isTerrain ? '#3a3020' : '#2a2818');
    const borderW = isHere ? 2 : 1;
    const bgColor = isTerrain ? '#0e0e08' : '#141208';
    const textColor = isHere ? empireColor : (isTerrain ? '#4a4030' : '#a09060');
    const dashAttr = isTerrain ? ' stroke-dasharray="5,3"' : '';
    const clickFn = readOnly ? '' : 'onclick="document.getElementById(\'modal-minimap-ville\').classList.remove(\'open\');enterBuilding(\'' + id + '\')"';

    svg += '<g ' + clickFn + ' style="cursor:' + (readOnly ? 'default' : 'pointer') + '">';
    svg += '<rect x="' + bx + '" y="' + by + '" width="' + bw + '" height="' + bh + '" rx="3"';
    svg += ' fill="' + bgColor + '" stroke="' + borderColor + '" stroke-width="' + borderW + '"' + dashAttr + '/>';

    // Icône
    const iconY = by + Math.max(18, bh * 0.38);
    svg += '<text x="' + cx + '" y="' + iconY + '" text-anchor="middle" font-size="' + (bh > 70 ? 20 : 15) + '" fill="' + textColor + '">' + icon + '</text>';

    // Nom (1 ou 2 lignes selon largeur)
    const name1 = localName.length > 14 && bw < 100
      ? localName.substring(0, 13) + '…'
      : localName;
    const nameY = by + bh - 10;
    svg += '<text x="' + cx + '" y="' + nameY + '" text-anchor="middle" font-size="8" fill="' + textColor + '" font-family="sans-serif">' + name1 + '</text>';

    svg += '</g>';

    // Point rouge clignotant si joueur ici
    if (isHere) {
      const pcx = bx + bw - 8;
      const pcy = by + 8;
      svg += '<circle cx="' + pcx + '" cy="' + pcy + '" r="9" fill="#cc2020" opacity="0.2" class="pd"/>';
      svg += '<circle cx="' + pcx + '" cy="' + pcy + '" r="5" fill="#ff3333" stroke="#fff" stroke-width="1.2" class="pd"/>';
    }
  });

  // Titre
  svg += '<text x="340" y="590" text-anchor="middle" font-size="8" fill="#3a3520" font-family="sans-serif" letter-spacing="2">' + city.name.toUpperCase() + ' — ' + (co?.n || '').toUpperCase() + '</text>';

  // Légende
  svg += '<circle cx="16" cy="595" r="4" fill="#ff3333"/>';
  svg += '<text x="26" y="599" font-size="7.5" fill="#8a6a6a" font-family="sans-serif">Vous êtes ici</text>';

  svg += '</svg>';

  const title = city.name + (readOnly ? ' — ' + co?.n + ' (information)' : ' — ' + co?.n);
  document.getElementById('minimap-ville-title').textContent = title;
  document.getElementById('minimap-ville-body').innerHTML =
    (readOnly ? '<div style="padding:.4rem .6rem .6rem;font-size:.72rem;color:#8a3a20;border-bottom:1px solid #2a1010;margin-bottom:.4rem"><i class="ti ti-info-circle"></i> Utilisez l\'aeroport ou le port pour vous rendre dans cet empire.</div>' : '') +
    '<div style="padding:.4rem">' + svg + '</div>';

  document.getElementById('modal-minimap-ville').classList.add('open');
}


// =====================
// MINIMAP LECTURE SEULE (villes étrangères)
// =====================
function ouvrirMinimapLectureSeule(countryId, cityId) {
  ouvrirPlanVille(countryId, cityId, true);
}
function ouvrirMinimapLectureSeule_old(countryId, cityId) {
  const co = COUNTRIES[countryId];
  const world = WORLD[countryId];
  const city = world?.[cityId];
  if (!city) return;

  const buildings = city.buildings || [];
  const empireColor = co?.col || '#C9A84C';

  const cardsHtml = buildings.map(id => {
    const b = BUILDINGS[id];
    if (!b) return '';
    const ctx = city.buildingContext?.[id];
    const localName = ctx?.name || b.shortName || b.name;
    const localDesc = ctx?.desc || b.desc || '';
    const pnjList = ctx?.persons || Object.values(b.rooms || {}).flatMap(r => r.persons || []);
    const pnjHtml = pnjList.slice(0,3).map(p =>
      '<span style="font-size:.68rem;color:#8a8060">· ' + (p.name||'').replace(' (PNJ)','') + '</span>'
    ).join('<br>');

    return '<div style="display:flex;gap:.6rem;align-items:flex-start;padding:.5rem .8rem;border-bottom:1px solid #1a1810;cursor:default">' +
      '<div style="width:28px;height:28px;border-radius:4px;background:#0a0a07;border:1px solid #2a2010;display:flex;align-items:center;justify-content:center;flex-shrink:0">' +
        '<i class="ti ' + b.icon + '" style="font-size:.75rem;color:' + empireColor + '"></i>' +
      '</div>' +
      '<div style="flex:1">' +
        '<div style="font-size:.78rem;color:#f0ead6;margin-bottom:.1rem">' + localName + '</div>' +
        '<div style="font-size:.68rem;color:#6a5a30;margin-bottom:.2rem">' + localDesc.substring(0,80) + (localDesc.length > 80 ? '...' : '') + '</div>' +
        (pnjHtml ? '<div>' + pnjHtml + '</div>' : '') +
      '</div>' +
    '</div>';
  }).join('');

  document.getElementById('postes-modal-title').textContent =
    city.name + ' — ' + co?.n + ' (lecture seule)';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.5rem .8rem;font-size:.72rem;color:#8a3a20;border-bottom:1px solid #2a1010;margin-bottom:.2rem">' +
      '<i class="ti ti-lock" style="font-size:.7rem"></i> ' +
      'Vous ne pouvez pas vous rendre ici sans passer par l\'aeroport ou le port.' +
    '</div>' +
    cardsHtml;
  document.getElementById('modal-postes').classList.add('open');
}








// Wrappers pour les onclick électoraux
function voterPourCandidat(el) { voterPour(el.dataset.nom, el.dataset.poste, el.dataset.country, el.dataset.city); ouvrirBureauDeVote(el.dataset.poste, el.dataset.country, el.dataset.city); }
function distribuerProspectusModalBtn(el) { distribuerProspectusModal(el.dataset.nom, el.dataset.poste, el.dataset.country, el.dataset.city); }
function distribuerProspectusBtn(el) { distribuerProspectus(el.dataset.pnj, el.dataset.nom, el.dataset.poste, el.dataset.country, el.dataset.city); ouvrirBureauDeVote(el.dataset.poste, el.dataset.country, el.dataset.city); }
function ouvrirBureauDeVoteBtn(el) { ouvrirBureauDeVote(el.dataset.poste, el.dataset.country, el.dataset.city); }
function deposerCandidatureBtn(el) { deposerCandidature(el.dataset.poste, el.dataset.country, state.currentCity); }
function fermerModalPostes() { document.getElementById('modal-postes').classList.remove('open'); }


// =====================
// CALENDRIER ÉLECTORAL
// =====================
function ouvrirCalendrierElectoral() {
  const country = state.country;
  const co = COUNTRIES[country];
  const now = Date.now();
  const semaine = 7 * 24 * 60 * 60 * 1000;
  const villeCourante = state.currentCity || 'capitale';
  const villeNom = WORLD[country]?.[villeCourante]?.name || villeCourante;

  const formatDate = ts => {
    const d = new Date(ts);
    return d.toLocaleDateString('fr-FR', { weekday:'short', day:'numeric', month:'short' }) +
      ' à ' + d.toLocaleTimeString('fr-FR', { hour:'2-digit', minute:'2-digit' });
  };

  const diffJours = ts => {
    const diff = ts - now;
    if (diff < 0) return '<span style="color:#8a3a2a">Passé</span>';
    const j = Math.floor(diff / 86400000);
    const h = Math.floor((diff % 86400000) / 3600000);
    if (j > 0) return '<span style="color:#4a8a4a">Dans ' + j + 'j ' + h + 'h</span>';
    return '<span style="color:#C9A84C">Dans ' + h + 'h</span>';
  };

  const postes = [
    ...POSTES_ELECTIFS.national,
    ...POSTES_ELECTIFS.departemental,
    ...POSTES_ELECTIFS.local
  ];

  // Initialiser les cycles manquants
  if (!CYCLES_ELECTORAUX[country]) CYCLES_ELECTORAUX[country] = {};
  postes.forEach(p => {
    const city = posteEstLocal(p.id) ? villeCourante : null;
    const cle = getCleCycle(p.id, city);
    if (!CYCLES_ELECTORAUX[country][cle]) initCycleElectoral(country, p.id, city);
  });

  const lignes = postes.map(p => {
    const estLocal = posteEstLocal(p.id);
    const city = estLocal ? villeCourante : null;
    const cle = getCleCycle(p.id, city);
    const cycle = CYCLES_ELECTORAUX[country][cle];
    const phase = getPhaseActuelle(country, p.id, city);
    const nbCandidats = cycle?.candidats?.length || 0;
    const titulaire = cycle?.eluId || (state.postes?.[country]?.[p.id]) || null;
    const labelPoste = p.name + (estLocal ? ' — ' + villeNom : '');

    const phaseStyle = {
      [PHASES_ELECTORALES.CANDIDATURES]: { col: '#4a6aaa', label: 'Candidatures' },
      [PHASES_ELECTORALES.CAMPAGNE]:     { col: '#aa8a4a', label: 'Campagne' },
      [PHASES_ELECTORALES.VOTE]:         { col: '#4a8a4a', label: '🗳 Vote' },
      [PHASES_ELECTORALES.SECOND_TOUR]:  { col: '#8a6a4a', label: 'Campagne 2nd tour' },
      [PHASES_ELECTORALES.VOTE2]:        { col: '#4a8a4a', label: '🗳 2nd tour' },
      [PHASES_ELECTORALES.VACANT]:       { col: '#8a3a2a', label: 'Vacant' },
    }[phase] || { col: '#6a5a30', label: '?' };

    // Prochaines échéances
    const echeances = [];
    if (cycle) {
      if (cycle.dateDebutCandidatures && cycle.dateDebutCandidatures > now)
        echeances.push({ label: 'Ouverture candidatures', date: cycle.dateDebutCandidatures });
      if (cycle.dateDebutCampagne && cycle.dateDebutCampagne > now)
        echeances.push({ label: 'Début campagne', date: cycle.dateDebutCampagne });
      if (cycle.dateVote && cycle.dateVote > now)
        echeances.push({ label: '🗳 Vote', date: cycle.dateVote });
      if (cycle.dateResultats && cycle.dateResultats > now)
        echeances.push({ label: 'Résultats', date: cycle.dateResultats });
    }
    const prochaine = echeances.length > 0 ? echeances[0] : null;

    return '<div style="padding:.6rem .4rem;border-bottom:1px solid #1a1810">' +
      '<div style="display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:.3rem">' +
        '<div>' +
          '<div style="font-family:Bebas Neue,sans-serif;font-size:.82rem;color:#c0b090">' + labelPoste + '</div>' +
          '<div style="font-size:.65rem;color:#6a5a30">' +
            (titulaire ? '✦ ' + titulaire : 'Poste vacant') +
          '</div>' +
        '</div>' +
        '<div style="text-align:right">' +
          '<div style="font-size:.68rem;font-family:Bebas Neue,sans-serif;color:' + phaseStyle.col + ';letter-spacing:.06em">' + phaseStyle.label + '</div>' +
          '<div style="font-size:.62rem;color:#4a4030">' + nbCandidats + ' candidat(s)</div>' +
        '</div>' +
      '</div>' +
      // Échéances
      (echeances.length > 0
        ? '<div style="background:#0a0907;border:1px solid #1a1810;border-radius:3px;padding:.35rem .5rem;margin-top:.3rem">' +
          echeances.slice(0,3).map(e =>
            '<div style="display:flex;justify-content:space-between;font-size:.65rem;margin-bottom:.15rem">' +
              '<span style="color:#8a8060">' + e.label + '</span>' +
              '<span>' + diffJours(e.date) + ' <span style="color:#4a4030">(' + formatDate(e.date) + ')</span></span>' +
            '</div>'
          ).join('') +
          '</div>'
        : '') +
      // Boutons action
      '<div style="display:flex;gap:.4rem;margin-top:.4rem">' +
        '<button onclick="ouvrirBureauDeVoteBtn(this)" data-poste="' + p.id + '" data-country="' + country + '" data-city="' + (city||'') + '" style="font-size:.62rem;font-family:Bebas Neue,sans-serif;padding:.2rem .5rem;border:1px solid #2a2010;background:transparent;color:#8a8060;cursor:pointer">Détails →</button>' +
        (phase === PHASES_ELECTORALES.CANDIDATURES
          ? '<button onclick="deposerCandidatureBtn2Btn(this)" data-poste="' + p.id + '" data-country="' + country + '" data-city="' + (city||'') + '" style="font-size:.62rem;font-family:Bebas Neue,sans-serif;padding:.2rem .5rem;border:1px solid #4a6aaa;background:transparent;color:#6a8aca;cursor:pointer">📋 Candidater</button>'
          : '') +
      '</div>' +
    '</div>';
  }).join('');

  document.getElementById('postes-modal-title').textContent = '📅 Calendrier Électoral — ' + (co?.n || country);
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.2rem .4rem">' +
    '<div style="font-size:.65rem;color:#4a4030;padding:.3rem .4rem;margin-bottom:.3rem;font-style:italic">' +
      'Mandat : 5-6 semaines · Candidatures : J-7 avant campagne · Second tour si aucun candidat ne dépasse 50%+1' +
    '</div>' +
    lignes +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

function deposerCandidatureBtn2Btn(el) { deposerCandidatureBtn2(el.dataset.poste, el.dataset.country, el.dataset.city); }
function deposerCandidatureBtn2(posteId, country, city) {
  fermerModalPostes();
  deposerCandidature(posteId, country, city || state.currentCity);
}



// =====================
// PNJ ADMINISTRATEUR (poste vacant)
// =====================
const PNJ_ADMINISTRATEURS = {
  president: {
    republic: { name: 'Gaston Intérim',     role: 'Président par intérim', trait: 'Nommé faute de candidat. Signe des décrets sans les lire. Facile à déloger.' },
    narco:    { name: 'Don Provisional',    role: 'Président par intérim', trait: 'Personne ne sait comment il est arrivé là. Donne des ordres au hasard.' },
    soviet:   { name: 'Camarade Provisoire',role: 'Administrateur du Parti',trait: 'Le Parti l\'a nommé. Le Parti peut l\'enlever. Très facile à déloger.' },
    khalija:  { name: 'Wali Al-Niyaba',     role: 'Régent intérimaire',    trait: 'Nommé par le Palais en attendant mieux. N\'a aucune ambition personnelle.' },
  },
  maire: {
    republic: { name: 'Hubert Gestionnaire', role: 'Maire administrateur', trait: 'Ancien chef de bureau. Gère les poubelles. Rien d\'autre.' },
    narco:    { name: 'El Temporal',         role: 'Maire par défaut',     trait: 'Là par accident. Part dès qu\'on lui demande.' },
    soviet:   { name: 'Camarade Local',      role: 'Administrateur local', trait: 'Nommé d\'office. Applique les directives. Toutes les directives.' },
    khalija:  { name: 'Moudir Al-Waqt',      role: 'Administrateur royal', trait: 'Le Palais gère directement. Pour l\'instant.' },
  },
  depute: {
    republic: { name: 'Suppléant Dubois',    role: 'Député suppléant',     trait: 'Remplace le siège vide. Vote blanc à chaque session.' },
    narco:    { name: 'El Suplente',         role: 'Député intérimaire',   trait: 'Là pour les apparences.' },
    soviet:   { name: 'Délégué du Peuple',   role: 'Représentant collectif',trait: 'Le Parti représente déjà le peuple. C\'est une formalité.' },
    khalija:  { name: 'Wakil Al-Sha\'b',    role: 'Représentant intérimaire',trait: 'Nommé par le Cheikh en attendant.' },
  }
};

function nommerAdministrateurSiVacant(country, posteId) {
  if (!CYCLES_ELECTORAUX[country]?.[posteId]) return;
  const cycle = CYCLES_ELECTORAUX[country][posteId];

  // Ne nommer que si poste vraiment vacant (pas d'élu, phase VACANT)
  if (cycle.eluId || cycle.administrateur) return;
  if (getPhaseActuelle(country, posteId) !== PHASES_ELECTORALES.VACANT) return;

  const adminDef = PNJ_ADMINISTRATEURS[posteId]?.[country];
  if (!adminDef) return;

  cycle.administrateur = {
    ...adminDef,
    nommeLeJour: state.day || 1,
    facileADeloger: true
  };
  cycle.eluId = adminDef.name + ' (Admin)';

  addJournalEntry('🏛 ' + adminDef.name + ' nommé ' + adminDef.role + ' — poste vacant.', 'event-info');
  addExternalEvent('🏛 ' + adminDef.name + ' prend les rênes de ' + (POSTES_ELECTIFS.national.concat(POSTES_ELECTIFS.local).find(p=>p.id===posteId)?.name || posteId) + ' à ' + (COUNTRIES[country]?.n || country) + '.');

  // Publier sur le forum
  if (typeof sbCreateTopic === 'function') {
    sbCreateTopic('local',
      '🏛 Nomination : ' + adminDef.name,
      'Faute de candidat, ' + adminDef.name + ' est nommé ' + adminDef.role + '.\n\n"' + adminDef.trait + '"\n\nIl peut être destitué par un vote de l\'assemblée ou une candidature au prochain cycle.',
      'Système'
    );
  }
}

// Vérifier tous les postes vacants au chargement et au réveil
function verifierPostesVacants() {
  const country = state.country;
  if (!CYCLES_ELECTORAUX[country]) return;
  Object.keys(CYCLES_ELECTORAUX[country]).forEach(posteId => {
    nommerAdministrateurSiVacant(country, posteId);
  });
}

// =====================
// PERSISTANCE ÉLECTORALE SUPABASE
// =====================
async function sbSaveCycleElectoral(country, posteId, cycle, city) {
  if (typeof sbInsert !== 'function') return;
  const cle = getCleCycle(posteId, city);
  try {
    await sbInsert('cycles_electoraux', {
      id: country + '_' + cle,
      country, poste_id: posteId, city: posteEstLocal(posteId) ? (city || null) : null,
      data: JSON.stringify(cycle),
      updated_at: new Date().toISOString()
    });
  } catch(e) {}
}

async function sbLoadCyclesElectoraux(country) {
  if (typeof sbGet !== 'function') return null;
  try {
    const rows = await sbGet('cycles_electoraux', 'country=eq.' + country);
    if (!rows || !rows.length) return null;
    const result = {};
    rows.forEach(r => {
      const cle = getCleCycle(r.poste_id, r.city);
      result[cle] = JSON.parse(r.data);
    });
    return result;
  } catch(e) { return null; }
}

async function sbVoterPour(country, posteId, votant, candidat, city) {
  if (typeof sbInsert !== 'function') return;
  const cle = getCleCycle(posteId, city);
  try {
    await sbInsert('votes_electoraux', {
      id: country + '_' + cle + '_' + votant,
      country, poste_id: posteId, city: posteEstLocal(posteId) ? (city || null) : null,
      votant, candidat,
      created_at: new Date().toISOString()
    });
  } catch(e) {}
}

async function sbGetVotes(country, posteId, city) {
  if (typeof sbGet !== 'function') return [];
  try {
    let filtre = 'country=eq.' + country + '&poste_id=eq.' + posteId;
    if (posteEstLocal(posteId) && city) filtre += '&city=eq.' + city;
    return await sbGet('votes_electoraux', filtre) || [];
  } catch(e) { return []; }
}

async function sbDeposerCandidature(country, posteId, candidat, city) {
  if (typeof sbInsert !== 'function') return;
  const cle = getCleCycle(posteId, city);
  try {
    await sbInsert('candidatures', {
      id: country + '_' + cle + '_' + candidat.nom,
      country, poste_id: posteId, city: posteEstLocal(posteId) ? (city || null) : null,
      nom: candidat.nom, programme: candidat.programme,
      archetype: candidat.archetype,
      created_at: new Date().toISOString()
    });
  } catch(e) {}
}

async function sbGetCandidatures(country, posteId, city) {
  if (typeof sbGet !== 'function') return [];
  try {
    let filtre = 'country=eq.' + country + '&poste_id=eq.' + posteId;
    if (posteEstLocal(posteId) && city) filtre += '&city=eq.' + city;
    return await sbGet('candidatures', filtre) || [];
  } catch(e) { return []; }
}

async function syncCyclesDepuisSupabase() {
  const country = state.country;
  const cycles = await sbLoadCyclesElectoraux(country);
  if (cycles) {
    CYCLES_ELECTORAUX[country] = { ...(CYCLES_ELECTORAUX[country]||{}), ...cycles };
  }
  // Charger votes et candidatures pour les postes pertinents (national + ceux de la ville courante)
  const postes = [...POSTES_ELECTIFS.national, ...POSTES_ELECTIFS.departemental, ...POSTES_ELECTIFS.local];
  for (const p of postes) {
    const city = posteEstLocal(p.id) ? state.currentCity : null;
    const cle = getCleCycle(p.id, city);
    if (!CYCLES_ELECTORAUX[country]?.[cle]) continue;
    const votes = await sbGetVotes(country, p.id, city);
    const candidatures = await sbGetCandidatures(country, p.id, city);
    if (votes.length) {
      CYCLES_ELECTORAUX[country][cle].votes = {};
      votes.forEach(v => { CYCLES_ELECTORAUX[country][cle].votes[v.votant] = v.candidat; });
    }
    if (candidatures.length) {
      CYCLES_ELECTORAUX[country][cle].candidats = candidatures.map(c => ({
        nom: c.nom, programme: c.programme, archetype: c.archetype,
        prospectusDistribues: 0
      }));
    }
  }
}

// =====================
// MOTEUR ÉLECTORAL
// =====================

// Initialiser le cycle électoral pour un empire/poste
// Détermine si un poste est local (niveau ville) ou national
function posteEstLocal(posteId) {
  const poste = [...(POSTES_ELECTIFS.national||[]), ...(POSTES_ELECTIFS.departemental||[]), ...(POSTES_ELECTIFS.local||[])]
    .find(p => p.id === posteId);
  return poste?.niveau === 'ville';
}

// Clé effective du cycle — inclut la ville pour les postes locaux (maire, depute)
function getCleCycle(posteId, city) {
  if (posteEstLocal(posteId) && city) return posteId + '_' + city;
  return posteId;
}

function initCycleElectoral(country, posteId, city) {
  const cle = getCleCycle(posteId, city);
  if (!CYCLES_ELECTORAUX[country]) CYCLES_ELECTORAUX[country] = {};
  if (CYCLES_ELECTORAUX[country][cle]) return;

  const now = Date.now();
  const semaine = 7 * 24 * 60 * 60 * 1000;
  CYCLES_ELECTORAUX[country][cle] = {
    posteId, city: posteEstLocal(posteId) ? (city || null) : null,
    phase: PHASES_ELECTORALES.CANDIDATURES,
    dateDebutCandidatures: now,
    dateDebutCampagne: now + semaine,
    dateVote: now + 2 * semaine,
    dateResultats: now + 2 * semaine + 24 * 60 * 60 * 1000,
    candidats: [],
    votes: {},       // { nomPJ: nomCandidat }
    votesPNJ: {},    // { pnjId: nomCandidat }
    tour: 1,
    eluId: null,
  };
}

// Obtenir la phase actuelle d'un cycle
function getPhaseActuelle(country, posteId, city) {
  const cle = getCleCycle(posteId, city);
  const cycle = CYCLES_ELECTORAUX[country]?.[cle];
  if (!cycle) return null;
  const now = Date.now();
  if (now < cycle.dateDebutCampagne) return PHASES_ELECTORALES.CANDIDATURES;
  if (now < cycle.dateVote) return PHASES_ELECTORALES.CAMPAGNE;
  if (now < cycle.dateResultats) return PHASES_ELECTORALES.VOTE;
  return PHASES_ELECTORALES.VACANT;
}

// Déposer une candidature
function deposerCandidature(posteId, country, city) {
  const nom = state.char?.name;
  if (!nom) return;

  // Vérifier domiciliation
  const domicile = state.domicile;
  if (!domicile || domicile.country !== (country || state.country)) {
    showToast('Non domicilié', 'Vous devez être domicilié dans cet empire pour vous présenter.', false);
    return;
  }

  const poste = [...(POSTES_ELECTIFS.national), ...(POSTES_ELECTIFS.departemental), ...(POSTES_ELECTIFS.local)]
    .find(p => p.id === posteId);
  if (!poste) return;

  // Vérifier niveau d'influence requis
  if ((state.inf || 0) < (poste.minInf || 0)) {
    showToast('Influence insuffisante', 'Il faut ' + poste.minInf + ' INF minimum pour ce poste.', false);
    return;
  }

  // Vérifier cumul des mandats
  if (state.poste && state.poste.id !== posteId) {
    const interdits = [['president','maire'],['president','depute'],['maire','depute']];
    const conflict = interdits.some(pair =>
      pair.includes(state.poste.id) && pair.includes(posteId)
    );
    if (conflict) {
      showToast('Cumul interdit', 'Vous ne pouvez pas cumuler ' + state.poste.name + ' et ' + poste.name + '.', false);
      return;
    }
  }

  const c = country || state.country;
  const cle = getCleCycle(posteId, city);
  if (!CYCLES_ELECTORAUX[c]) CYCLES_ELECTORAUX[c] = {};
  if (!CYCLES_ELECTORAUX[c][cle]) initCycleElectoral(c, posteId, city);

  const cycle = CYCLES_ELECTORAUX[c][cle];
  if (getPhaseActuelle(c, posteId, city) !== PHASES_ELECTORALES.CANDIDATURES) {
    showToast('Hors délai', 'Les candidatures ne sont pas ouvertes pour ce poste.', false);
    return;
  }

  if (cycle.candidats.find(ca => ca.nom === nom)) {
    showToast('Déjà candidat', 'Vous êtes déjà candidat à ce poste.', false);
    return;
  }

  // Ouvrir modal pour programme
  ouvrirModalCandidature(posteId, c, poste, cycle, city);
}

function ouvrirModalCandidature(posteId, country, poste, cycle, city) {
  const nom = state.char?.name;
  document.getElementById('postes-modal-title').textContent = '🗳️ Candidature — ' + poste.name;
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +
    '<div style="font-size:.78rem;color:#c0b090;margin-bottom:.8rem">Présentez votre programme en quelques mots. Il sera visible de tous les électeurs.</div>' +
    '<textarea id="prog-texte" rows="4" placeholder="Mon programme..." ' +
    'style="width:100%;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,Georgia,serif;font-size:.85rem;box-sizing:border-box;resize:vertical"></textarea>' +
    '<div style="display:flex;gap:.5rem;margin-top:.6rem">' +
    '<button onclick="confirmerCandidature(this)" data-poste="' + posteId + '" data-country="' + country + '" data-city="' + (city||'') + '" ' +
    'style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">' +
    '🗳️ Déposer ma candidature</button>' +
    '<button onclick="fermerModalPostes()" ' +
    'style="font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem .8rem;border:1px solid #2a2010;background:transparent;color:#6a5a30;cursor:pointer">Annuler</button>' +
    '</div></div>';
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerCandidature(el) {
  const posteId = el?.dataset?.poste || el;
  const country = el?.dataset?.country || arguments[1];
  const city = el?.dataset?.city || arguments[2] || null;
  const nom = state.char?.name;
  const programme = document.getElementById('prog-texte')?.value?.trim() || '';
  if (!programme) { showToast('Programme requis', 'Décrivez votre programme.', false); return; }

  const cle = getCleCycle(posteId, city);
  const cycle = CYCLES_ELECTORAUX[country][cle];
  const nouveauCandidat = {
    nom, programme,
    archetype: state.char?.archetype,
    posteActuel: state.poste?.name || null,
    prospectusDistribues: 0,
    dateInscription: Date.now(),
  };
  cycle.candidats.push(nouveauCandidat);
  // Persister en Supabase
  sbDeposerCandidature(country, posteId, nouveauCandidat, city).catch(() => {});
  sbSaveCycleElectoral(country, posteId, cycle, city).catch(() => {});

  document.getElementById('modal-postes').classList.remove('open');
  showToast('Candidature enregistrée !', 'Vous êtes candidat à ' + posteId + (city ? ' (' + city + ')' : '') + '.', true);
  addJournalEntry('📋 Candidature déposée au poste : ' + posteId + (city ? ' — ' + city : '') + '.', 'event-info');

  // Publier sur le forum
  if (typeof sbCreateTopic === 'function') {
    sbCreateTopic('local',
      '🗳️ Candidature de ' + nom + ' — ' + POSTES_ELECTIFS.national.concat(POSTES_ELECTIFS.local).concat(POSTES_ELECTIFS.departemental).find(p=>p.id===posteId)?.name,
      nom + ' se présente aux élections.\n\nProgramme :\n' + programme,
      nom
    );
  }
}

// Vote PJ
function voterPour(candidatNom, posteId, country, city) {
  const votant = state.char?.name;
  if (!votant) return;

  const domicile = state.domicile;
  if (!domicile || domicile.country !== country) {
    showToast('Non domicilié', 'Vous ne pouvez pas voter dans cet empire.', false);
    return;
  }

  const cle = getCleCycle(posteId, city);
  const cycle = CYCLES_ELECTORAUX[country]?.[cle];
  if (!cycle) return;

  if (getPhaseActuelle(country, posteId, city) !== PHASES_ELECTORALES.VOTE &&
      getPhaseActuelle(country, posteId, city) !== PHASES_ELECTORALES.VOTE2) {
    showToast('Vote fermé', 'Le vote n\'est pas ouvert actuellement.', false);
    return;
  }

  if (cycle.votes[votant]) {
    showToast('Déjà voté', 'Vous avez déjà voté pour ce poste.', false);
    return;
  }

  cycle.votes[votant] = candidatNom;
  // Persister en Supabase
  sbVoterPour(country, posteId, votant, candidatNom, city).catch(() => {});
  sbSaveCycleElectoral(country, posteId, cycle, city).catch(() => {});
  showToast('Vote enregistré !', 'Vous avez voté pour ' + candidatNom + '.', true);
  addJournalEntry('🗳️ Vote enregistré pour ' + candidatNom + (city ? ' (' + city + ')' : '') + '.', 'event-info');
}

// Distribuer un prospectus à un PNJ
function distribuerProspectus(pnjId, candidatNom, posteId, country, city) {
  const cle = getCleCycle(posteId, city);
  const cycle = CYCLES_ELECTORAUX[country]?.[cle];
  if (!cycle) return;

  if (state.pa < 1) { showToast('PA insuffisants', '1 PA requis.', false); return; }
  if (state.arg < 50) { showToast('Fonds insuffisants', '50 FR requis par prospectus.', false); return; }

  // Un PNJ ne peut recevoir qu'un seul prospectus
  if (cycle.votesPNJ[pnjId]) {
    showToast('Déjà converti', 'Ce PNJ a déjà reçu un prospectus.', false);
    return;
  }

  const phase = getPhaseActuelle(country, posteId, city);
  if (phase !== PHASES_ELECTORALES.CAMPAGNE && phase !== PHASES_ELECTORALES.CAMPAGNE) {
    showToast('Hors campagne', 'Les prospectus ne se distribuent que pendant la campagne.', false);
    return;
  }

  state.pa -= 1;
  state.arg -= 50;
  cycle.votesPNJ[pnjId] = candidatNom;

  // Trouver le candidat et incrémenter son compteur
  const candidat = cycle.candidats.find(c => c.nom === candidatNom);
  if (candidat) candidat.prospectusDistribues++;

  updateUI();
  showToast('Prospectus distribué !', pnjId + ' votera pour ' + candidatNom + '. -1 PA · -50 FR', true);
  addJournalEntry('📄 Prospectus distribué à ' + pnjId + ' pour ' + candidatNom + '.', 'event-info');
}

// Calculer les résultats
function calculerResultats(posteId, country) {
  const cycle = CYCLES_ELECTORAUX[country]?.[posteId];
  if (!cycle) return null;

  const scores = {};
  cycle.candidats.forEach(c => { scores[c.nom] = 0; });

  // Votes PJ
  Object.values(cycle.votes).forEach(nom => {
    if (scores[nom] !== undefined) scores[nom]++;
  });

  // Votes PNJ
  Object.values(cycle.votesPNJ).forEach(nom => {
    if (scores[nom] !== undefined) scores[nom]++;
  });

  const totalVoix = Object.values(scores).reduce((s, v) => s + v, 0);
  if (totalVoix === 0) return { scores, totalVoix: 0, elu: null, secondTour: [] };

  // Vérifier majorité absolue
  const sorted = Object.entries(scores).sort((a, b) => b[1] - a[1]);
  const premier = sorted[0];

  if (premier[1] > totalVoix / 2) {
    return { scores, totalVoix, elu: premier[0], secondTour: [] };
  }

  // Second tour — candidats > 15%
  const qualifies = sorted.filter(([, v]) => v / totalVoix >= 0.15).map(([n]) => n);
  return { scores, totalVoix, elu: null, secondTour: qualifies };
}

// Afficher le bureau de vote
function ouvrirBureauDeVote(posteId, country, city) {
  const cle = getCleCycle(posteId, city);
  const cycle = CYCLES_ELECTORAUX[country]?.[cle];
  if (!cycle || !cycle.candidats.length) {
    showToast('Aucun candidat', 'Personne ne s\'est présenté.', false);
    return;
  }

  const phase = getPhaseActuelle(country, posteId, city);
  const poste = [...POSTES_ELECTIFS.national, ...POSTES_ELECTIFS.local, ...POSTES_ELECTIFS.departemental]
    .find(p => p.id === posteId);
  const monVote = cycle.votes[state.char?.name];
  const co = COUNTRIES[country];
  const villeNom = city ? (WORLD[country]?.[city]?.name || city) : null;

  const candidatsHtml = cycle.candidats.map(ca => {
    const aVote = monVote === ca.nom;
    return '<div style="padding:.6rem .4rem;border-bottom:1px solid #1a1810">' +
      '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:.3rem">' +
        '<div style="font-family:Bebas Neue,sans-serif;font-size:.82rem;color:' + (aVote ? '#C9A84C' : '#c0b090') + '">' +
          ca.nom + (aVote ? ' ✦ (votre vote)' : '') +
        '</div>' +
        (phase === PHASES_ELECTORALES.VOTE || phase === PHASES_ELECTORALES.VOTE2
          ? (!monVote
            ? '<button onclick="voterPourCandidat(this)" data-nom="' + ca.nom + '" data-poste="' + posteId + '" data-country="' + country + '" data-city="' + (city||'') + '" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;letter-spacing:.08em;padding:.25rem .6rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">Voter</button>'
            : '') : '') +
      '</div>' +
      '<div style="font-size:.72rem;color:#8a8060;font-style:italic;margin-bottom:.2rem">' + ca.programme + '</div>' +
      (phase === PHASES_ELECTORALES.CAMPAGNE || phase === PHASES_ELECTORALES.SECOND_TOUR
        ? '<button onclick="distribuerProspectusModalBtn(this)" data-nom="' + ca.nom + '" data-poste="' + posteId + '" data-country="' + country + '" data-city="' + (city||'') + '" style="font-size:.65rem;font-family:Bebas Neue,sans-serif;letter-spacing:.06em;padding:.2rem .5rem;border:1px solid #3a5a3a;background:transparent;color:#4a8a4a;cursor:pointer">📄 Distribuer prospectus (1 PA · 50 ' + (co?.cur||'FR') + ')</button>'
        : '') +
    '</div>';
  }).join('');

  const phaseLabel = {
    [PHASES_ELECTORALES.CANDIDATURES]: '📋 Candidatures ouvertes',
    [PHASES_ELECTORALES.CAMPAGNE]:     '📢 Campagne électorale',
    [PHASES_ELECTORALES.VOTE]:         '🗳️ Vote en cours',
    [PHASES_ELECTORALES.SECOND_TOUR]:  '📢 Campagne — Second tour',
    [PHASES_ELECTORALES.VOTE2]:        '🗳️ Second tour',
  }[phase] || '❓ Phase inconnue';

  document.getElementById('postes-modal-title').textContent = '🗳️ ' + (poste?.name || posteId) + (villeNom ? ' — ' + villeNom : '') + ' — ' + (co?.n || country);
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.6rem 1rem">' +
    '<div style="font-family:Bebas Neue,sans-serif;font-size:.68rem;letter-spacing:.1em;color:#6a8a6a;margin-bottom:.6rem">' + phaseLabel + '</div>' +
    candidatsHtml +
    (phase === PHASES_ELECTORALES.CANDIDATURES
      ? '<button onclick="deposerCandidatureBtn(this)" data-poste="' + posteId + '" data-country="' + country + '" data-city="' + (city||'') + '" style="width:100%;margin-top:.8rem;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">📋 Déposer ma candidature</button>'
      : '') +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

function distribuerProspectusModal(candidatNom, posteId, country, city) {
  // Récupérer les PNJ présents dans la pièce courante
  const room = BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom];
  const persons = room?.persons || [];
  if (!persons.length) {
    showToast('Personne ici', 'Aucun PNJ à qui distribuer un prospectus.', false);
    return;
  }

  const cle = getCleCycle(posteId, city);
  const cycle = CYCLES_ELECTORAUX[country]?.[cle];
  const disponibles = persons.filter(p => !cycle?.votesPNJ[p.name]);

  if (!disponibles.length) {
    showToast('Déjà convaincus', 'Tous les PNJ présents ont déjà reçu un prospectus.', false);
    return;
  }

  const html = disponibles.map(p =>
    '<div style="display:flex;justify-content:space-between;align-items:center;padding:.4rem .2rem;border-bottom:1px solid #1a1810">' +
    '<span style="font-size:.78rem;color:#c0b090">' + p.name.replace(' (PNJ)','') + '</span>' +
    '<button onclick="distribuerProspectusBtn(this)" data-pnj="' + p.name + '" data-nom="' + candidatNom + '" data-poste="' + posteId + '" data-country="' + country + '" data-city="' + (city||'') + '" ' +
    'style="font-size:.65rem;font-family:Bebas Neue,sans-serif;padding:.2rem .5rem;border:1px solid #3a5a3a;background:transparent;color:#4a8a4a;cursor:pointer">Distribuer</button>' +
    '</div>'
  ).join('');

  document.getElementById('postes-modal-title').textContent = '📄 Distribuer pour ' + candidatNom;
  document.getElementById('postes-body').innerHTML = '<div style="padding:.6rem 1rem">' + html + '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

// Consulter les résultats via informateur
function consulterResultatsInformateur(posteId, country) {
  if (!state.informateurs?.length) {
    showToast('Informateur requis', 'Recrutez un informateur pour connaître les résultats en temps réel.', false);
    return;
  }

  const res = calculerResultats(posteId, country);
  if (!res) return;

  const sorted = Object.entries(res.scores).sort((a,b) => b[1]-a[1]);
  const html = sorted.map(([nom, voix]) => {
    const pct = res.totalVoix > 0 ? Math.round(voix/res.totalVoix*100) : 0;
    return '<div style="margin-bottom:.4rem">' +
      '<div style="display:flex;justify-content:space-between;font-size:.78rem;color:#c0b090;margin-bottom:.15rem">' +
        '<span>' + nom + '</span><span>' + voix + ' voix (' + pct + '%)</span>' +
      '</div>' +
      '<div style="height:4px;background:#1a1810;border-radius:2px">' +
        '<div style="height:100%;width:' + pct + '%;background:#C9A84C;border-radius:2px"></div>' +
      '</div></div>';
  }).join('');

  document.getElementById('postes-modal-title').textContent = '🕵️ Résultats en temps réel';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.6rem 1rem">' +
    '<div style="font-size:.68rem;color:#6a5a30;margin-bottom:.6rem;font-style:italic">Source : informateur. ' + res.totalVoix + ' voix comptabilisées.</div>' +
    html +
    (res.elu ? '<div style="margin-top:.6rem;font-size:.78rem;color:#4a8a4a">→ Majorité atteinte : ' + res.elu + ' élu(e) si le vote clôture maintenant.</div>' : '') +
    (res.secondTour.length ? '<div style="margin-top:.6rem;font-size:.78rem;color:#aa8a4a">→ Second tour probable entre : ' + res.secondTour.join(', ') + '.</div>' : '') +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

// Afficher le tableau de bord électoral complet
function ouvrirTableauElectoral() {
  const country = state.country;
  const co = COUNTRIES[country];
  const villeCourante = state.currentCity || 'capitale';
  const villeNom = WORLD[country]?.[villeCourante]?.name || villeCourante;

  if (!CYCLES_ELECTORAUX[country]) {
    POSTES_ELECTIFS.national.forEach(p => initCycleElectoral(country, p.id));
  }

  const postes = [...POSTES_ELECTIFS.national, ...POSTES_ELECTIFS.departemental, ...POSTES_ELECTIFS.local];
  const html = postes.map(p => {
    const estLocal = posteEstLocal(p.id);
    const city = estLocal ? villeCourante : null;
    const cle = getCleCycle(p.id, city);
    const cycle = CYCLES_ELECTORAUX[country]?.[cle];
    const phase = cycle ? getPhaseActuelle(country, p.id, city) : 'Non initialisé';
    const nbCandidats = cycle?.candidats.length || 0;
    const titulaire = state.postes?.[country]?.[p.id] || 'Vacant';
    const labelPoste = p.name + (estLocal ? ' — ' + villeNom : '');

    const phaseCol = {
      [PHASES_ELECTORALES.CANDIDATURES]: '#4a6aaa',
      [PHASES_ELECTORALES.CAMPAGNE]:     '#aa8a4a',
      [PHASES_ELECTORALES.VOTE]:         '#4a8a4a',
      [PHASES_ELECTORALES.SECOND_TOUR]:  '#8a6a4a',
      [PHASES_ELECTORALES.VOTE2]:        '#4a8a4a',
      [PHASES_ELECTORALES.VACANT]:       '#8a3a2a',
    }[phase] || '#6a5a30';

    return '<div style="padding:.5rem .4rem;border-bottom:1px solid #1a1810">' +
      '<div style="display:flex;justify-content:space-between;align-items:center">' +
        '<div>' +
          '<div style="font-family:Bebas Neue,sans-serif;font-size:.78rem;color:#c0b090">' + labelPoste + '</div>' +
          '<div style="font-size:.65rem;color:#6a5a30">' + titulaire + '</div>' +
        '</div>' +
        '<div style="text-align:right">' +
          '<div style="font-size:.65rem;color:' + phaseCol + ';font-family:Bebas Neue,sans-serif">' + (phase || 'N/A') + '</div>' +
          '<div style="font-size:.62rem;color:#4a4030">' + nbCandidats + ' candidat(s)</div>' +
        '</div>' +
      '</div>' +
    '<button onclick="ouvrirBureauDeVoteBtn(this)" data-poste="' + p.id + '" data-country="' + country + '" data-city="' + (city||'') + '" ' +
      'style="margin-top:.3rem;font-size:.65rem;font-family:Bebas Neue,sans-serif;letter-spacing:.06em;padding:.2rem .5rem;border:1px solid #2a2010;background:transparent;color:#8a8060;cursor:pointer">Voir détails →</button>' +
    '</div>';
  }).join('');

  document.getElementById('postes-modal-title').textContent = '🗳️ Élections — ' + (co?.n || country);
  document.getElementById('postes-body').innerHTML = '<div style="padding:.4rem .6rem">' + html + '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

// Changer de domicile (depuis la mairie)
function changerDomicile(newCountry, newCity) {
  const co = COUNTRIES[newCountry];
  const cur = co?.cur || 'FR';
  const cout = 200;

  if (state.arg < cout) {
    showToast('Fonds insuffisants', cout + ' ' + cur + ' requis pour changer de domicile.', false);
    return;
  }

  state.arg -= cout;
  const ancienDomicile = state.domicile;
  state.domicile = { country: newCountry, city: newCity, depuis: state.day || 1 };

  // Perdre les postes liés à l'ancienne domiciliation
  if (state.poste) {
    const postesLocaux = ['maire', 'depute'];
    if (postesLocaux.includes(state.poste.id)) {
      addJournalEntry('⚠️ Changement de domicile : vous perdez votre poste de ' + state.poste.name + '.', 'event-bad');
      state.poste = null;
    if (state.char) state.char.poste = null;
    }
  }

  updateUI();
  showToast('Domicile changé !', newCity + ', ' + co?.n + '. -' + cout + ' ' + cur, true);
  addJournalEntry('🏠 Nouveau domicile : ' + newCity + ', ' + (co?.n || newCountry) + '.', 'event-info');
}



function confirmerCreationOrgaBtn(el) { confirmerCreationOrga(el.dataset.type); }
function ouvrirForumOrgaBtn(el) { ouvrirForumOrga(el.dataset.id); }
function ouvrirGestionOrgaBtn(el) { ouvrirGestionOrga(el.dataset.id); }
function posterMessageOrgaBtn(el) { posterMessageOrga(el.dataset.id); }
function ouvrirCreationOrgaBtn(el) { ouvrirCreationOrga(el.dataset.type); }


// =====================
// ALLIANCES ENTRE PJ
// =====================
function ouvrirMenuAlliances() {
  if (typeof sbListPersonnages !== 'function') {
    showToast('Indisponible', 'Connexion Supabase requise.', false);
    return;
  }

  const alliances = state.alliances || [];
  const demandesRecues = state.demandes_alliance || [];

  sbListPersonnages().then(joueurs => {
    const autres = (joueurs || []).filter(j => j.name !== state.char?.name);
    const cur = COUNTRIES[state.country]?.cur || 'FR';

    const alliancesHtml = alliances.length > 0
      ? '<div style="margin-bottom:.8rem">' +
        '<div style="font-family:Bebas Neue,sans-serif;font-size:.65rem;letter-spacing:.12em;color:#4a8a4a;margin-bottom:.4rem">VOS ALLIANCES ACTIVES</div>' +
        alliances.map(a =>
          '<div style="display:flex;justify-content:space-between;align-items:center;padding:.3rem .4rem;border-bottom:1px solid #1a1810">' +
          '<span style="font-size:.78rem;color:#c0b090">' + a.nom + '</span>' +
          '<span style="font-size:.65rem;color:#4a8a4a">' + a.type + '</span>' +
          '<button onclick="rompreAlliance(this)" data-nom="' + a.nom + '" style="font-size:.6rem;color:#8a3a2a;background:none;border:none;cursor:pointer">Rompre</button>' +
          '</div>'
        ).join('') +
        '</div>'
      : '<div style="font-size:.72rem;color:#4a4030;margin-bottom:.8rem;font-style:italic">Aucune alliance active.</div>';

    const demandesHtml = demandesRecues.length > 0
      ? '<div style="margin-bottom:.8rem">' +
        '<div style="font-family:Bebas Neue,sans-serif;font-size:.65rem;letter-spacing:.12em;color:#C9A84C;margin-bottom:.4rem">DEMANDES REÇUES</div>' +
        demandesRecues.map(d =>
          '<div style="display:flex;justify-content:space-between;align-items:center;padding:.3rem .4rem;border-bottom:1px solid #1a1810">' +
          '<span style="font-size:.78rem;color:#c0b090">' + d.de + ' → ' + d.type + '</span>' +
          '<div style="display:flex;gap:.4rem">' +
          '<button onclick="accepterAlliance(this)" data-de="' + d.de + '" data-type="' + d.type + '" style="font-size:.65rem;color:#4a8a4a;background:none;border:1px solid #2a5a2a;padding:.2rem .4rem;cursor:pointer">✓ Accepter</button>' +
          '<button onclick="refuserAlliance(this)" data-de="' + d.de + '" style="font-size:.65rem;color:#8a3a2a;background:none;border:1px solid #5a2a2a;padding:.2rem .4rem;cursor:pointer">✗ Refuser</button>' +
          '</div></div>'
        ).join('') +
        '</div>'
      : '';

    const proposerHtml = autres.length > 0
      ? '<div>' +
        '<div style="font-family:Bebas Neue,sans-serif;font-size:.65rem;letter-spacing:.12em;color:#6a5a30;margin-bottom:.4rem">PROPOSER UNE ALLIANCE</div>' +
        '<select id="alliance-joueur" style="width:100%;background:#0a0a07;border:1px solid #2a2010;color:#c0b090;padding:.3rem;margin-bottom:.4rem;font-family:Crimson Pro,Georgia,serif">' +
        autres.map(j => '<option value="' + j.name + '">' + j.name + '</option>').join('') +
        '</select>' +
        '<select id="alliance-type" style="width:100%;background:#0a0a07;border:1px solid #2a2010;color:#c0b090;padding:.3rem;margin-bottom:.4rem;font-family:Crimson Pro,Georgia,serif">' +
        '<option value="Non-agression">Pacte de non-agression</option>' +
        '<option value="Coalition électorale">Coalition électorale</option>' +
        '<option value="Partage d\'informateurs">Partage d\'informateurs</option>' +
        '<option value="Alliance économique">Alliance économique</option>' +
        '</select>' +
        '<button onclick="proposerAlliance()" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.4rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">Envoyer la proposition</button>' +
        '</div>'
      : '<div style="font-size:.72rem;color:#4a4030;font-style:italic">Aucun autre joueur disponible.</div>';

    document.getElementById('postes-modal-title').textContent = '🤝 Alliances';
    document.getElementById('postes-body').innerHTML =
      '<div style="padding:.6rem 1rem">' + alliancesHtml + demandesHtml + proposerHtml + '</div>';
    document.getElementById('modal-postes').classList.add('open');
  }).catch(() => showToast('Erreur', 'Impossible de charger les joueurs.', false));
}

async function proposerAlliance() {
  const joueur = document.getElementById('alliance-joueur')?.value;
  const type   = document.getElementById('alliance-type')?.value;
  if (!joueur || !type) return;

  const from = state.char?.name || 'Anonyme';
  const sujet = '🤝 Proposition d\'alliance : ' + type;
  const corps = from + ' vous propose une alliance de type <strong>' + type + '</strong>.<br><br>' +
    'Pour accepter, répondez à ce mail avec "J\'accepte". Pour refuser, répondez "Je refuse".';

  if (typeof sendMail === 'function') await sendMail(joueur, sujet, corps);
  document.getElementById('modal-postes').classList.remove('open');
  showToast('Proposition envoyée !', joueur + ' a reçu votre demande d\'alliance.', true);
  addJournalEntry('Proposition d\'alliance (' + type + ') envoyée à ' + joueur + '.', 'event-info');
}

function accepterAlliance(el) {
  const de = el?.dataset?.de || el;
  const type = el?.dataset?.type || arguments[1];
  if (!state.alliances) state.alliances = [];
  state.alliances.push({ nom: de, type: type, depuis: state.day || 1 });
  state.demandes_alliance = (state.demandes_alliance || []).filter(d => d.de !== de);
  if (typeof sendMail === 'function') {
    sendMail(de, '✅ Alliance acceptée', state.char?.name + ' accepte votre proposition d\'alliance : ' + type + '.');
  }
  document.getElementById('modal-postes').classList.remove('open');
  showToast('Alliance conclue !', 'Avec ' + de + ' — ' + type, true);
  addJournalEntry('Alliance conclue avec ' + de + ' : ' + type + '.', 'event-good');
}

function refuserAlliance(el) {
  const de = el?.dataset?.de || el;
  state.demandes_alliance = (state.demandes_alliance || []).filter(d => d.de !== de);
  if (typeof sendMail === 'function') {
    sendMail(de, '❌ Alliance refusée', state.char?.name + ' décline votre proposition d\'alliance.');
  }
  ouvrirMenuAlliances();
}

function rompreAlliance(el) {
  const nom = el?.dataset?.nom || el;
  state.alliances = (state.alliances || []).filter(a => a.nom !== nom);
  if (typeof sendMail === 'function') {
    sendMail(nom, '⚠️ Alliance rompue', state.char?.name + ' met fin à votre alliance.');
  }
  showToast('Alliance rompue', 'Avec ' + nom, false);
  addJournalEntry('Alliance rompue avec ' + nom + '.', 'event-bad');
  ouvrirMenuAlliances();
}

// =====================
// OBJECTIFS SECRETS PAR ARCHÉTYPE
// =====================
const OBJECTIFS_SECRETS = {
  ambitieux: {
    label: 'L\'Ambitieux',
    objectifs: [
      { id: 'obj_president',   desc: 'Devenir Président de votre empire',          condition: s => s.poste?.id === 'president',                                          points: 50 },
      { id: 'obj_inf80',       desc: 'Atteindre 80 points d\'Influence',           condition: s => (s.inf||0) >= 80,                                                     points: 20 },
      { id: 'obj_poste_haut',  desc: 'Occuper un poste ministériel',               condition: s => s.poste && !['citoyen','depute'].includes(s.poste.id),                 points: 15 },
      { id: 'obj_argent_50k',  desc: 'Accumuler 50 000 FR en banque',              condition: s => (s.banque||0) >= 50000,                                               points: 25 },
    ]
  },
  criminel: {
    label: 'Le Criminel',
    objectifs: [
      { id: 'obj_blanchir',    desc: 'Blanchir 20 000 FR via des activités louches', condition: s => (s.argent_blanchi||0) >= 20000,                                    points: 40 },
      { id: 'obj_dis90',       desc: 'Maintenir une Discrétion supérieure à 90',  condition: s => (s.dis||0) >= 90,                                                      points: 20 },
      { id: 'obj_informateur', desc: 'Recruter 2 informateurs simultanément',      condition: s => (s.informateurs||[]).length >= 2,                                     points: 15 },
      { id: 'obj_jamais_arrete',desc: 'Ne jamais être arrêté pendant 10 jours',   condition: s => (s.jours_libres||0) >= 10,                                            points: 30 },
    ]
  },
  journaliste: {
    label: 'Le Journaliste',
    objectifs: [
      { id: 'obj_scandales',   desc: 'Publier 5 scandales sur le forum',           condition: s => (s.scandales_publies||0) >= 5,                                        points: 30 },
      { id: 'obj_sondages',    desc: 'Commander 3 sondages absurdes',              condition: s => (s.sondages_commandes||0) >= 3,                                       points: 15 },
      { id: 'obj_micro',       desc: 'Interviewer 5 PNJ différents',               condition: s => (s.pnj_interviewes||[]).length >= 5,                                  points: 20 },
      { id: 'obj_forum_actif', desc: 'Publier 10 posts sur le forum',              condition: s => (s.posts_forum||0) >= 10,                                             points: 25 },
    ]
  },
  fonctionnaire: {
    label: 'Le Fonctionnaire',
    objectifs: [
      { id: 'obj_poste_stable', desc: 'Conserver le même poste 7 jours',           condition: s => (s.jours_meme_poste||0) >= 7,                                        points: 25 },
      { id: 'obj_formulaires',  desc: 'Remplir 10 demandes administratives',       condition: s => (s.formulaires_remplis||0) >= 10,                                    points: 15 },
      { id: 'obj_corruption',   desc: 'Corrompre 3 fonctionnaires',                condition: s => (s.fonctionnaires_corrompus||0) >= 3,                                 points: 20 },
      { id: 'obj_banque_stable', desc: 'Avoir 15 000 FR en banque pendant 5 jours',condition: s => (s.jours_banque_15k||0) >= 5,                                        points: 30 },
    ]
  },
  militaire: {
    label: 'Le Militaire',
    objectifs: [
      { id: 'obj_caserne',      desc: 'Visiter la caserne 5 fois',                 condition: s => (s.visites_caserne||0) >= 5,                                         points: 15 },
      { id: 'obj_ordre',        desc: 'Faire appel à la police 3 fois',            condition: s => (s.appels_police||0) >= 3,                                           points: 20 },
      { id: 'obj_hp_max',       desc: 'Maintenir 100 HP pendant 5 jours',          condition: s => (s.jours_hp_max||0) >= 5,                                            points: 25 },
      { id: 'obj_ministre_def', desc: 'Devenir Ministre de la Défense',            condition: s => s.poste?.id === 'ministre_defense',                                  points: 40 },
    ]
  },
  religieux: {
    label: 'Le Religieux',
    objectifs: [
      { id: 'obj_pop80',        desc: 'Atteindre 80 de Popularité',                condition: s => (s.pop||0) >= 80,                                                    points: 25 },
      { id: 'obj_moral_max',    desc: 'Maintenir 100 de Moral pendant 5 jours',   condition: s => (s.jours_moral_max||0) >= 5,                                         points: 20 },
      { id: 'obj_pelerinage',   desc: 'Visiter 3 empires différents',              condition: s => (s.empires_visites||[]).length >= 3,                                  points: 30 },
      { id: 'obj_sermons',      desc: 'Publier 5 messages inspirants sur le forum',condition: s => (s.sermons_publies||0) >= 5,                                         points: 20 },
    ]
  }
};

function afficherObjectifsSecrets() {
  const archetype = state.char?.archetype || 'ambitieux';
  const obj = OBJECTIFS_SECRETS[archetype] || OBJECTIFS_SECRETS.ambitieux;
  const completed = state.objectifs_completes || [];

  // Vérifier nouvelles complétion
  obj.objectifs.forEach(o => {
    if (!completed.includes(o.id) && o.condition(state)) {
      completed.push(o.id);
      state.objectifs_completes = completed;
      state.inf = Math.min(100, (state.inf||0) + Math.floor(o.points/5));
      showToast('🎯 Objectif accompli !', o.desc + ' (+' + o.points + ' pts)', true);
      addJournalEntry('🎯 Objectif secret accompli : ' + o.desc, 'event-good');
    }
  });

  const totalPoints = obj.objectifs.reduce((s,o) => s + (completed.includes(o.id) ? o.points : 0), 0);
  const maxPoints   = obj.objectifs.reduce((s,o) => s + o.points, 0);

  const html = obj.objectifs.map(o => {
    const done = completed.includes(o.id);
    return '<div style="display:flex;align-items:center;gap:.6rem;padding:.5rem .4rem;border-bottom:1px solid #1a1810">' +
      '<div style="font-size:1rem">' + (done ? '✅' : '⬜') + '</div>' +
      '<div style="flex:1">' +
        '<div style="font-size:.78rem;color:' + (done ? '#4a8a4a' : '#c0b090') + '">' + o.desc + '</div>' +
        '<div style="font-size:.65rem;color:#8a7050">' + o.points + ' points</div>' +
      '</div>' +
    '</div>';
  }).join('');

  document.getElementById('postes-modal-title').textContent = '🎯 Objectifs — ' + obj.label;
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.6rem 1rem">' +
    '<div style="font-size:.7rem;color:#C9A84C;font-family:Bebas Neue,sans-serif;letter-spacing:.08em;margin-bottom:.6rem">' +
      'Score : ' + totalPoints + ' / ' + maxPoints + ' points' +
    '</div>' +
    html +
    '<div style="font-size:.65rem;color:#8a7050;margin-top:.6rem;font-style:italic">Ces objectifs sont secrets — les autres joueurs ne les voient pas.</div>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

// Vérifier objectifs à chaque updateUI
let _verifyingObjectifs = false;
function verifierObjectifs() {
  if (_verifyingObjectifs) return;
  const archetype = state.char?.archetype;
  if (!archetype || !OBJECTIFS_SECRETS[archetype]) return;
  const obj = OBJECTIFS_SECRETS[archetype];
  const completed = state.objectifs_completes || [];
  let changed = false;
  obj.objectifs.forEach(o => {
    try {
      if (!completed.includes(o.id) && o.condition(state)) {
        completed.push(o.id);
        state.objectifs_completes = completed;
        changed = true;
        showToast('🎯 Objectif accompli !', o.desc, true);
        addJournalEntry('🎯 ' + o.desc, 'event-good');
      }
    } catch(e) {} // Condition peut échouer si state incomplet
  });
  if (changed) {
    _verifyingObjectifs = true;
    state.inf = Math.min(100, (state.inf||0) + 2);
    _verifyingObjectifs = false;
  }
}

// =====================
// JOURNAL DU MATIN
// =====================
async function afficherJournalDuMatin() {
  const today = state.day || 1;
  const sessionKey = 'journal_matin_day_' + today;
  if (sessionStorage.getItem(sessionKey)) return;
  sessionStorage.setItem(sessionKey, '1');

  const co = COUNTRIES[state.country];
  const empireStyle = EMPIRE_STYLES?.[state.country] || { tone: 'parodique', religion: 'la Foi Locale', leader: 'le Chef' };
  // Récupérer la vraie situation politique depuis Supabase
  let presidentNom = 'Poste vacant';
  let autresPostes = [];
  let resumeActions = '';
  let topics = '';

  if (typeof sbListPersonnages === 'function') {
    try {
      const joueurs = await sbListPersonnages() || [];
      const memeEmpire = joueurs.filter(j => j.country === state.country);
      const president = memeEmpire.find(j => j.poste && j.poste.id === 'president');
      presidentNom = president?.name || 'Poste vacant';
      autresPostes = memeEmpire
        .filter(j => j.poste && j.poste.id !== 'president' && j.name !== state.char?.name)
        .map(j => j.name + ' (' + j.poste.name + ')')
        .slice(0, 3);
      const autres = joueurs.filter(j => j.name !== state.char?.name);
      if (autres.length > 0) {
        resumeActions = autres.slice(0,3).map(j => j.name + ' vu à ' + (j.current_city || 'lieu inconnu')).join(', ');
      }
    } catch(e) {}
  }

  if (typeof FORUM_TOPICS !== 'undefined') {
    topics = (FORUM_TOPICS['local'] || []).slice(0, 3).map(t => '"' + t.title + '" (par ' + t.author + ')').join(', ');
  }

  const contextePolitique = presidentNom !== 'Poste vacant'
    ? presidentNom + ' occupe la présidence.'
    : 'Le fauteuil présidentiel est vacant.';
  const contextPostes = autresPostes.length > 0 ? 'Autres postes : ' + autresPostes.join(', ') + '.' : '';

  const prompt = 'Tu es le rédacteur du journal du matin dans ' + (co?.n || 'l\'empire') + ', jeu politique parodique. ' +
    'Style : ' + empireStyle.tone + '. Religion : ' + empireStyle.religion + '. ' +
    'SITUATION RÉELLE DU JOUR : ' + contextePolitique + ' ' + contextPostes + ' ' +
    (resumeActions ? 'Joueurs actifs : ' + resumeActions + '. ' : '') +
    (topics ? 'Sujets du forum : ' + topics + '. ' : '') +
    'Jour ' + today + '. ' +
    'Rédige un bref journal du matin parodique COHÉRENT avec cette situation réelle : 1 titre + 3 brèves drôles. ' +
    'Si un président est nommé, ne dis PAS que le fauteuil est vide. Pas de vrais dieux. Max 6 lignes.';

  try {
    const resp = await fetch('/api/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ model: 'claude-sonnet-4-5', max_tokens: 200, messages: [{ role: 'user', content: prompt }] })
    });
    const data = await resp.json();
    const journal = data.content?.[0]?.text;
    if (!journal) return;

    // Afficher dans un modal dédié
    document.getElementById('postes-modal-title').textContent = '📰 Journal du Matin — Jour ' + today;
    document.getElementById('postes-body').innerHTML =
      '<div style="padding:.8rem 1rem">' +
      '<div style="font-size:.7rem;color:#6a5a30;margin-bottom:.6rem;font-family:Bebas Neue,sans-serif;letter-spacing:.08em">' +
        co?.n?.toUpperCase() + ' · ÉDITION DU JOUR ' + today +
      '</div>' +
      '<div style="font-size:.85rem;color:#c0b090;line-height:1.9;white-space:pre-line;font-family:Crimson Pro,Georgia,serif;border-left:2px solid #3a2a10;padding-left:.8rem">' +
        journal +
      '</div>' +
      '<div style="margin-top:.8rem;display:flex;gap:.5rem">' +
        '<button onclick="publierJournal(this.dataset.txt)" data-txt="' + journal.replace(/"/g,'&quot;') + '" ' +
        'style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.4rem .8rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">' +
        '<i class="ti ti-news" style="font-size:.7rem"></i> Publier sur le forum</button>' +
        '<button onclick="document.getElementById(\'modal-postes\').classList.remove(\'open\')" ' +
        'style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.4rem .8rem;border:1px solid #3a2a10;background:transparent;color:#6a5a30;cursor:pointer">Fermer</button>' +
      '</div></div>';
    document.getElementById('modal-postes').classList.add('open');

    addJournalEntry('📰 Journal du matin disponible — Jour ' + today, 'event-info');
  } catch(e) {}
}

async function publierJournal(texte) {
  document.getElementById('modal-postes').classList.remove('open');
  if (typeof sbCreateTopic === 'function') {
    const from = state.char?.name || 'Rédaction';
    await sbCreateTopic('local', '📰 Journal du Matin — Jour ' + (state.day||1), texte, from);
    showToast('Journal publié !', 'Visible sur le forum local.', true);
  }
}

// =====================
// NOTIFICATIONS MAILS
// =====================
async function verifierNouveauxMails() {
  if (typeof sbGetMailsFor !== 'function') return;
  const nom = state.char?.name;
  if (!nom) return;
  try {
    const mails = await sbGetMailsFor(nom);
    const nonLus = (mails || []).filter(m => !m.read && m.to_player === nom).length;
    const badge = document.getElementById('mail-badge');
    if (badge) {
      if (nonLus > 0) {
        badge.textContent = nonLus;
        badge.style.display = 'inline';
      } else {
        badge.style.display = 'none';
      }
    }
    // Mettre à jour le titre de la page
    if (nonLus > 0) {
      document.title = '(' + nonLus + ') Res Publica';
    } else {
      document.title = 'Res Publica';
    }
  } catch(e) {}
}

// =====================
// MÉTÉO POLITIQUE QUOTIDIENNE
// =====================
async function genererMeteoPolitique() {
  if (sessionStorage.getItem('meteo_done_' + (state.day || 1))) return;

  const co = COUNTRIES[state.country];
  const empireStyle = EMPIRE_STYLES?.[state.country] || { tone: 'parodique', religion: 'la Foi Locale', leader: 'le Chef' };
  const president = POSTES[state.country]?.capitale?.find(p => p.id === 'president');
  const presidentNom = president?.holder || 'Personne';
  const topics = (typeof FORUM_TOPICS !== 'undefined' ? (FORUM_TOPICS['local'] || []) : []).slice(0, 2).map(t => t.title).join(', ');

  const prompt = 'Tu es le météorologue politique de ' + (co?.n || 'l\'empire') + ' dans Res Publica, jeu parodique. ' +
    'Style : ' + empireStyle.tone + '. Religion : ' + empireStyle.religion + '. Chef : ' + empireStyle.leader + '. ' +
    'Président actuel : ' + presidentNom + '. ' +
    (topics ? 'Actualités récentes : ' + topics + '. ' : '') +
    'Génère un bulletin météo POLITIQUE absurde et drôle pour aujourd\'hui (Jour ' + (state.day || 1) + '). ' +
    '3 lignes max. Style bulletin météo détourné. Ex: "Risque d\'orage institutionnel au nord, prévoir parapluie et avocat." ' +
    'Pas de vrais dieux. Répondre UNIQUEMENT avec le bulletin, sans introduction.';

  try {
    const resp = await fetch('/api/chat', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({ model: 'claude-sonnet-4-5', max_tokens: 120, messages: [{ role: 'user', content: prompt }] })
    });
    const data = await resp.json();
    const meteo = data.content?.[0]?.text;
    if (meteo) {
      addJournalEntry('🌦 MÉTÉO POLITIQUE — Jour ' + (state.day || 1) + ' : ' + meteo, 'event-info');
      sessionStorage.setItem('meteo_done_' + (state.day || 1), '1');
    }
  } catch(e) {}
}

// =====================
// ÉVÉNEMENTS ALÉATOIRES
// =====================
const EVENEMENTS_TYPES = [
  { id: 'scandale', label: 'Scandale', prob: 0.25 },
  { id: 'greve', label: 'Grève surprise', prob: 0.15 },
  { id: 'visite', label: 'Visite diplomatique', prob: 0.10 },
  { id: 'panne', label: 'Panne administrative', prob: 0.20 },
  { id: 'bonne_nouvelle', label: 'Bonne nouvelle', prob: 0.15 },
  { id: 'rumeur', label: 'Rumeur persistante', prob: 0.15 },
];

async function genererEvenementAleatoire() {
  if (sessionStorage.getItem('event_done_' + (state.day || 1))) return;

  // Probabilité globale de 40% d'avoir un événement
  if (Math.random() > 0.4) return;

  const roll = Math.random();
  let cumul = 0;
  let type = EVENEMENTS_TYPES[0];
  for (const e of EVENEMENTS_TYPES) {
    cumul += e.prob;
    if (roll <= cumul) { type = e; break; }
  }

  const co = COUNTRIES[state.country];
  const empireStyle = EMPIRE_STYLES?.[state.country] || { tone: 'parodique', religion: 'la Foi Locale', leader: 'le Chef' };

  const prompts = {
    scandale: 'Génère un titre de scandale politique absurde et parodique dans ' + (co?.n || 'l\'empire') + '. Style : ' + empireStyle.tone + '. 1 phrase. Pas de vrais dieux.',
    greve: 'Génère une annonce de grève surprise absurde dans ' + (co?.n || 'l\'empire') + '. Corps de métier inattendu. Style : ' + empireStyle.tone + '. 1 phrase.',
    visite: 'Génère une annonce de visite diplomatique absurde dans ' + (co?.n || 'l\'empire') + '. Visiteur improbable. Style : ' + empireStyle.tone + '. 1 phrase.',
    panne: 'Génère une annonce de panne administrative absurde dans ' + (co?.n || 'l\'empire') + '. Service inattendu en panne. Style : ' + empireStyle.tone + '. 1 phrase.',
    bonne_nouvelle: 'Génère une bonne nouvelle politique absurde dans ' + (co?.n || 'l\'empire') + '. Style : ' + empireStyle.tone + '. 1 phrase. Religion locale : ' + empireStyle.religion + '.',
    rumeur: 'Génère une rumeur politique absurde qui circule dans ' + (co?.n || 'l\'empire') + '. Style : ' + empireStyle.tone + '. 1 phrase.',
  };

  const emojis = { scandale: '🔥', greve: '✊', visite: '🤝', panne: '⚠️', bonne_nouvelle: '🎉', rumeur: '👂' };

  try {
    const resp = await fetch('/api/chat', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({ model: 'claude-sonnet-4-5', max_tokens: 100, messages: [{ role: 'user', content: prompts[type.id] }] })
    });
    const data = await resp.json();
    const texte = data.content?.[0]?.text;
    if (texte) {
      const emoji = emojis[type.id] || '📢';
      addJournalEntry(emoji + ' ' + type.label.toUpperCase() + ' : ' + texte, 'event-' + (type.id === 'bonne_nouvelle' ? 'good' : type.id === 'scandale' ? 'bad' : 'info'));
      addExternalEvent(emoji + ' ' + texte);
      sessionStorage.setItem('event_done_' + (state.day || 1), '1');
    }
  } catch(e) {}
}

// =====================
// DÉCRETS PRÉSIDENTIELS
// =====================
async function signerDecretInutile() {
  if (state.poste?.id !== 'president') {
    showToast('Accès refusé', 'Seul le Président peut signer des décrets.', false);
    return;
  }

  const co = COUNTRIES[state.country];
  const cur = co?.cur || 'FR';
  const empireStyle = EMPIRE_STYLES?.[state.country] || { tone: 'parodique', religion: 'la Foi Locale', leader: 'le Chef' };

  const sujets = [
    'la couleur officielle des formulaires administratifs',
    'l\'heure légale de la sieste nationale',
    'l\'obligation de saluer le portrait du président en entrant dans les bâtiments',
    'la taxe sur les soupirs excessifs dans les couloirs officiels',
    'la nomination d\'un Commissaire aux Bonnes Nouvelles',
    'l\'interdiction des réunions se terminant sans conclusion',
    'la journée nationale du silence administratif',
    'l\'instauration d\'une prime à la loyauté inconditionnelle',
    'la mise en place d\'un formulaire pour contester les formulaires',
    'l\'obligation de finir chaque discours par une citation du Président'
  ];
  const sujet = sujets[Math.floor(Math.random() * sujets.length)];

  document.getElementById('postes-modal-title').textContent = 'Rédaction du Décret...';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060;font-style:italic">La plume présidentielle est à l\'œuvre...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const prompt = 'Tu es le rédacteur des décrets présidentiels dans ' + (co?.n || 'l\'empire') + ', jeu parodique. ' +
    'Style : ' + empireStyle.tone + '. Religion : ' + empireStyle.religion + '. ' +
    'Rédige un décret présidentiel ABSURDE et PARODIQUE sur : ' + sujet + '. ' +
    'Format : Titre officiel + Article 1 + Article 2 + Effet parodique sur la population. ' +
    'Max 6 lignes. Très drôle. Pas de vrais dieux ni religions réelles.';

  try {
    const resp = await fetch('/api/chat', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({ model: 'claude-sonnet-4-5', max_tokens: 250, messages: [{ role: 'user', content: prompt }] })
    });
    const data = await resp.json();
    const decret = data.content?.[0]?.text || 'Décret indisponible.';

    // Effets gameplay
    const popEffect = Math.floor(Math.random() * 20) - 5; // -5 à +15
    const infEffect = Math.floor(Math.random() * 10) + 2;
    state.pop = Math.max(0, Math.min(100, (state.pop || 50) + popEffect));
    state.inf = Math.min(100, (state.inf || 0) + infEffect);
    updateUI();

    document.getElementById('postes-modal-title').textContent = '📜 Décret Présidentiel';
    document.getElementById('postes-body').innerHTML =
      '<div style="padding:1rem">' +
      '<div style="font-size:.7rem;color:#6a5a30;margin-bottom:.6rem;border-bottom:1px solid #2a2010;padding-bottom:.4rem">Signé par ' + (state.char?.name || 'Le Président') + ' · Jour ' + (state.day || 1) + '</div>' +
      '<div style="font-size:.85rem;color:#c0a060;line-height:1.9;white-space:pre-line;font-family:Crimson Pro,Georgia,serif">' + decret + '</div>' +
      '<div style="margin-top:.8rem;font-size:.72rem;color:' + (popEffect >= 0 ? '#4a8a4a' : '#8a3a2a') + '">' +
        (popEffect >= 0 ? '+' : '') + popEffect + ' POP · +' + infEffect + ' INF</div>' +
      '<div style="margin-top:.6rem;display:flex;gap:.5rem">' +
      '<button onclick="publierDecret(this.dataset.txt)" data-txt="' + decret.replace(/"/g, '&quot;') + '" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.4rem .8rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer"><i class="ti ti-speakerphone" style="font-size:.7rem"></i> Publier</button>' +
      '<button onclick="document.getElementById(\'modal-postes\').classList.remove(\'open\')" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.4rem .8rem;border:1px solid #3a2a10;background:transparent;color:#6a5a30;cursor:pointer">Fermer</button>' +
      '</div></div>';

    addJournalEntry('📜 Décret signé sur : ' + sujet + '. ' + (popEffect >= 0 ? '+' : '') + popEffect + ' POP · +' + infEffect + ' INF.', 'event-info');

  } catch(e) {
    document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a3a20">Erreur de rédaction. La plume est fatiguée.</div>';
  }
}

async function publierDecret(texte) {
  document.getElementById('modal-postes').classList.remove('open');
  if (typeof sbCreateTopic === 'function') {
    const from = state.char?.name || 'Le Président';
    await sbCreateTopic('local', '📜 Décret Présidentiel', texte, from);
    showToast('Décret publié !', 'Visible sur le forum national.', true);
  }
}



function ouvrirCadavreListe(el) {
  const photo = el.dataset.photo;
  const pos   = el.dataset.pos || '50% 40%';
  const role  = el.dataset.role || 'Cadavre';
  const trait = el.dataset.trait || '';
  ouvrirPhotoCadavre(JSON.stringify({ photoUrl: photo, photoPos: pos, role, trait }));
}

function ouvrirPhotoCadavre(jsonStr) {
  try {
    const pnj = JSON.parse(jsonStr);
    const overlay = document.createElement('div');
    overlay.onclick = () => overlay.remove();
    overlay.style.cssText = 'position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,0.95);z-index:99999;display:flex;flex-direction:column;align-items:center;justify-content:center;cursor:pointer';
    const photoHtml = pnj.photoUrl
      ? '<img src="' + pnj.photoUrl + '" style="max-width:85vw;max-height:70vh;object-fit:contain;border:1px solid #3a2a10;margin-bottom:.8rem"/>'
      : '<div style="font-size:4rem;margin-bottom:.8rem">💀</div>';
    overlay.innerHTML = photoHtml +
      '<div style="font-family:Bebas Neue,sans-serif;font-size:.9rem;letter-spacing:.12em;color:#8a3a2a;margin-bottom:.4rem">' + (pnj.role || 'Cadavre') + '</div>' +
      '<div style="font-size:.78rem;color:#6a5a30;font-style:italic;max-width:400px;text-align:center;padding:0 1rem">' + (pnj.trait || '') + '</div>' +
      '<div style="font-size:.62rem;color:#3a3020;margin-top:1rem">Cliquer pour fermer</div>';
    document.body.appendChild(overlay);
  } catch(e) {}
}

// =====================
// PNJ ALÉATOIRES SUR LES TERRAINS
// =====================
function genererPnjTerrain(buildingId) {
  const country = state.country || 'republic';
  const profiles = (typeof TERRAIN_PNJ_PROFILES !== 'undefined')
    ? TERRAIN_PNJ_PROFILES[country] || TERRAIN_PNJ_PROFILES.republic
    : [];
  if (!profiles.length) return null;

  // Indices impériaux modifient les probabilités
  const indices = INDICES_NATIONAUX?.[country] || { ISN:30, IE:50, ID:40, IS:45 };
  const isn = indices.ISN || 30;
  const ie  = indices.IE  || 50;
  const id  = indices.ID  || 40;
  const is  = indices.IS  || 45;

  // Ajuster les probabilités selon indices
  const adjustedProfiles = profiles.map(p => {
    let prob = p.prob;
    if (p.id === 'squatter_agr')  prob = Math.max(0.01, prob - isn/200 - is/200);
    if (p.id === 'squatter_cool') prob = Math.max(0.02, prob - isn/300);
    if (p.id === 'cadavre')       prob = Math.max(0.005, prob + (100-id)/500);
    if (p.id === 'promoteur')     prob = Math.max(0.03, prob + ie/400);
    if (p.id === 'inspecteur')    prob = Math.max(0.05, prob + isn/300);
    if (p.id === 'vide')          prob = Math.max(0.05, prob + isn/200);
    return { ...p, prob };
  });

  // Normaliser et tirer au sort
  const total = adjustedProfiles.reduce((s, p) => s + p.prob, 0);
  let roll = Math.random() * total;
  for (const p of adjustedProfiles) {
    roll -= p.prob;
    if (roll <= 0) return p.id === 'vide' ? null : p;
  }
  return null;
}

async function interagirPnjTerrain(pnjId) {
  const country = state.country || 'republic';
  const profiles = TERRAIN_PNJ_PROFILES?.[country] || TERRAIN_PNJ_PROFILES?.republic || [];
  const pnj = profiles.find(p => p.id === pnjId);
  if (!pnj) return;

  const indices = INDICES_NATIONAUX?.[country] || { ISN:30, IE:50, ID:40, IS:45 };
  const is = indices.IS || 45;
  const cha = state.char?.stats?.CHA || 8;
  const cur = COUNTRIES[country]?.cur || 'FR';

  // Squatteurs agressifs — jet CHA + IS
  if (pnj.agressif) {
    const bonusCHA = Math.floor(cha / 2);
    const bonusIS  = Math.floor(is / 10);
    const taux = Math.min(80, 20 + bonusCHA + bonusIS);
    const roll = Math.floor(Math.random() * 100) + 1;

    if (roll <= taux) {
      // Succès — CHA évite l'agression
      state.inf = Math.min(100, (state.inf||0) + 2);
      updateUI();
      addJournalEntry('Vous avez calmé les squatteurs par votre charisme. +2 INF.', 'event-good');
      showToast('Tension désamorcée !', 'Votre charisme a évité la bagarre. (Jet ' + roll + '/' + taux + '%)', true);
    } else {
      // Échec — bagarre
      const degats = Math.floor(Math.random() * 15) + 10;
      state.hp = Math.max(0, (state.hp||100) - degats);
      state.dis = Math.max(0, (state.dis||50) - 5);
      updateUI();
      addJournalEntry('Vous avez été attaqué par des squatteurs. -' + degats + ' HP. -5 DIS.', 'event-bad');
      showToast('Bagarre !', '-' + degats + ' HP · -5 DIS (Jet ' + roll + '/' + taux + '%)', false);
    }
    return;
  }

  // Squatteurs cools — bière et côtelette
  if (pnj.id === 'squatter_cool') {
    const hpBonus = Math.floor(Math.random() * 8) + 5;
    const moralBonus = Math.floor(Math.random() * 8) + 5;
    state.hp = Math.min(100, (state.hp||100) + hpBonus);
    state.moral = Math.min(100, (state.moral||50) + moralBonus);
    // Info gratuite parfois
    const infoBonus = Math.random() > 0.5;
    if (infoBonus) state.inf = Math.min(100, (state.inf||0) + 3);
    updateUI();
    addJournalEntry('Les squatteurs vous offrent bière et côtelette. +' + hpBonus + ' HP · +' + moralBonus + ' Moral' + (infoBonus ? ' · +3 INF' : '') + '.', 'event-good');
    showToast('Accueil chaleureux !', '+' + hpBonus + ' HP · +' + moralBonus + ' Moral' + (infoBonus ? ' · +3 INF (tuyau)' : ''), true);
    return;
  }

  // Cadavre — blocage administratif
  if (pnj.id === 'cadavre') {
    const id_idx = indices.ID || 40;
    const delai = Math.max(1, Math.round(5 - id_idx/25));
    state.dis = Math.max(0, (state.dis||50) - 10);
    updateUI();
    addJournalEntry('Cadavre découvert sur le terrain ! Enquête obligatoire. Blocage administratif : ' + delai + ' jour(s). -10 DIS.', 'event-bad');
    showToast('Cadavre découvert !', 'Enquête requise. Formalités bloquées ' + delai + ' jour(s). -10 DIS.', false);
    // Signaler à la police
    if (!state.recherche) state.recherche = [];
    addExternalEvent('🚨 Cadavre découvert sur un terrain à ' + (WORLD[country]?.[state.currentCity]?.name || 'la ville') + '. Enquête en cours.');
    return;
  }

  // Promoteur — propose rachat à prix gonflé
  if (pnj.id === 'promoteur') {
    const prixGonfle = Math.floor(Math.random() * 5000) + 6000;
    addJournalEntry(pnj.name + ' vous propose de racheter ce terrain pour ' + prixGonfle.toLocaleString('fr-FR') + ' ' + cur + '.', 'event-info');
    showToast(pnj.name, 'Offre de rachat : ' + prixGonfle.toLocaleString('fr-FR') + ' ' + cur + '. Intéressant ?', true);
    return;
  }

  // Gardien — peut être soudoyé
  if (pnj.id === 'gardien') {
    const pot = Math.floor(isn / 5) * 10 + 100;
    document.getElementById('postes-modal-title').textContent = pnj.name + ' — Gardien';
    document.getElementById('postes-body').innerHTML =
      '<div style="padding:1rem">' +
      '<div style="font-size:.82rem;color:#a09060;margin-bottom:.8rem;font-style:italic">"' + (pnj.trait || (pnj.job === 'escort' ? 'Je connais tous les secrets de cette ville. Mon tarif : 500 ' + (COUNTRIES[state.country]?.cur || 'FR') + '/réveil.' : 'Un personnage discret.')) + '"</div>' +
      '<button onclick="soudoyerGardienTerrain(' + pot + ');document.getElementById(\'modal-postes\').classList.remove(\'open\')" ' +
      'style="font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem .8rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer;display:block;margin-bottom:.4rem;width:100%">' +
      '<i class="ti ti-coin"></i> Soudoyer (' + pot + ' ' + cur + ')</button>' +
      '<button onclick="document.getElementById(\'modal-postes\').classList.remove(\'open\')" ' +
      'style="font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem .8rem;border:1px solid #2a2010;background:transparent;color:#6a5a30;cursor:pointer;width:100%">Partir</button>' +
      '</div>';
    document.getElementById('modal-postes').classList.add('open');
    return;
  }

  // Inspecteur — vérifie les permis
  if (pnj.id === 'inspecteur') {
    const aPermis = state.inventory?.find(i => i.type === 'permis' && i.building === state.currentBuilding);
    if (aPermis) {
      addJournalEntry(pnj.name + ' vérifie vos permis. Tout est en ordre.', 'event-info');
      showToast('Contrôle passé', 'Vos permis sont valides.', true);
    } else {
      state.dis = Math.max(0, (state.dis||50) - 8);
      updateUI();
      addJournalEntry(pnj.name + ' vous demande un permis de construire. Vous n\'en avez pas. -8 DIS.', 'event-bad');
      showToast('Contrôle raté !', 'Permis manquant. -8 DIS.', false);
    }
    return;
  }

  // Par défaut — juste parler
  showToast(pnj.name, pnj.trait || 'Un personnage mystérieux.', true);
}

function soudoyerGardienTerrain(montant) {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  if (state.arg < montant) {
    showToast('Fonds insuffisants', montant + ' ' + cur + ' requis.', false);
    return;
  }
  const dup = state.char?.stats?.DUP || 8;
  const taux = Math.min(80, 40 + Math.floor(dup/2));
  const roll = Math.floor(Math.random() * 100) + 1;
  state.arg -= montant;
  if (roll <= taux) {
    state.dis = Math.min(100, (state.dis||50) + 5);
    updateUI();
    showToast('Gardien soudoyé !', 'Il regarde ailleurs. +5 DIS.', true);
    addJournalEntry('Gardien soudoyé pour ' + montant + ' ' + cur + '. -' + montant + ' ' + cur + ' · +5 DIS.', 'event-good');
  } else {
    state.dis = Math.max(0, (state.dis||50) - 10);
    updateUI();
    showToast('Refus !', 'Il n\'a pas accepté. -10 DIS.', false);
    addJournalEntry('Tentative de corruption du gardien refusée. -' + montant + ' ' + cur + ' · -10 DIS.', 'event-bad');
  }
}

// Appeler au chargement d'un terrain
function chargerPnjTerrain(buildingId) {
  if (!buildingId?.startsWith('terrain-a-batir')) return;

  // Vérifier si état persistant existe déjà
  const ts = getTerrainState(buildingId);

  // Si police est intervenue, vider le PNJ
  if (ts.policeInterventionAt && Date.now() > ts.policeInterventionAt && ts.pnj) {
    setTerrainState(buildingId, { pnj: null, pnjData: null, policeAppellee: null, policeInterventionAt: null });
    sessionStorage.removeItem('terrain_pnj_' + buildingId);
    showToast('Terrain libéré', 'La police est intervenue.', true);
    return;
  }

  // Utiliser le PNJ persistant si disponible
  if (ts.pnjData) {
    sessionStorage.setItem('terrain_pnj_' + buildingId, JSON.stringify({
      name: ts.pnjData.name + ' (PNJ)',
      role: ts.pnjData.role,
      job: ts.pnjData.job,
      rel: ts.pnjData.rel,
      trait: ts.pnjData.trait,
      photoUrl: ts.pnjData.photoUrl,
      photoPos: ts.pnjData.photoPos,
      terrainPnjId: ts.pnjData.id
    }));
    return;
  }

  // Générer automatiquement au premier passage
  const pnjObj = genererPnjTerrain(buildingId);
  if (pnjObj) {
    setTerrainState(buildingId, { pnj: pnjObj.id, pnjData: pnjObj, dateGeneration: Date.now() });
    sessionStorage.setItem('terrain_pnj_' + buildingId, JSON.stringify({
      name: pnjObj.name + ' (PNJ)', role: pnjObj.role, job: pnjObj.job,
      rel: pnjObj.rel, trait: pnjObj.trait, photoUrl: pnjObj.photoUrl,
      photoPos: pnjObj.photoPos, terrainPnjId: pnjObj.id
    }));
  } else {
    sessionStorage.removeItem('terrain_pnj_' + buildingId);
  }
}


// =====================
// GESTION TERRAIN — HIÉRARCHIE DES ORDRES
// =====================

// État persistant des terrains (Supabase + localStorage)
function getTerrainState(buildingId) {
  const key = 'terrain_state_' + state.country + '_' + buildingId;
  try {
    const stored = localStorage.getItem(key);
    return stored ? JSON.parse(stored) : {};
  } catch(e) { return {}; }
}

function setTerrainState(buildingId, updates) {
  const key = 'terrain_state_' + state.country + '_' + buildingId;
  const current = getTerrainState(buildingId);
  const newState = { ...current, ...updates };
  try { localStorage.setItem(key, JSON.stringify(newState)); } catch(e) {}

  // Synchroniser avec Supabase si disponible
  if (typeof sbSetTerrainState === 'function') {
    sbSetTerrainState(state.country, buildingId, newState).catch(() => {});
  }
  return newState;
}

// Vérifier si un ordre terrain est disponible selon l'état du terrain
function terrainOrdreDisponible(fn, buildingId) {
  const ts = getTerrainState(buildingId);
  const pnj = ts.pnj; // PNJ persistant sur ce terrain

  // Ordres bloqués si cadavre présent
  if (pnj === 'cadavre') {
    const bloques = ['signer_compromis', 'permis_construire', 'permis_corrompu', 'acheter_terrain'];
    if (bloques.includes(fn)) return { ok: false, raison: 'Un cadavre bloque les démarches administratives. Résolvez la situation d\'abord.' };
  }

  // Ordres bloqués si squatteurs présents
  if (pnj === 'squatter_agr' || pnj === 'squatter_cool') {
    if (fn === 'signer_compromis') return { ok: false, raison: 'Des squatteurs occupent le terrain. Faites intervenir la police ou négociez leur départ.' };
  }

  // Ordre cadavre seulement si cadavre présent
  if (fn === 'faire_disparaitre_cadavre' && pnj !== 'cadavre')
    return { ok: false, raison: 'Aucun cadavre sur ce terrain.' };

  // Ordre négociation seulement si squatteurs présents
  if (fn === 'negocier_squatteurs' && pnj !== 'squatter_agr' && pnj !== 'squatter_cool')
    return { ok: false, raison: 'Aucun squatteur à négocier.' };

  // Compromis requis avant permis
  if (fn === 'permis_construire' || fn === 'permis_corrompu') {
    if (!ts.compromis) return { ok: false, raison: 'Signez d\'abord un compromis de vente.' };
  }

  return { ok: true };
}

// Inspecter le terrain — déclenche la génération du PNJ persistant
function doVerifierTerrain() {
  const id = state.currentBuilding;
  let ts = getTerrainState(id);

  if (!ts.pnj) {
    // Générer et persister le PNJ
    const pnjObj = genererPnjTerrain(id);
    ts = setTerrainState(id, {
      pnj: pnjObj ? pnjObj.id : null,
      pnjData: pnjObj || null,
      dateGeneration: Date.now()
    });
    // Mettre à jour le sessionStorage aussi pour l'affichage
    if (pnjObj) {
      sessionStorage.setItem('terrain_pnj_' + id, JSON.stringify({
        name: pnjObj.name + ' (PNJ)', role: pnjObj.role, job: pnjObj.job,
        rel: pnjObj.rel, trait: pnjObj.trait, terrainPnjId: pnjObj.id,
        photoUrl: pnjObj.photoUrl, photoPos: pnjObj.photoPos
      }));
    } else {
      sessionStorage.removeItem('terrain_pnj_' + id);
    }
  }

  const pnj = ts.pnjData;
  if (!pnj) {
    addJournalEntry('Terrain inspecté. Rien à signaler.', 'event-info');
    showToast('Terrain libre', 'Aucun obstacle. Vous pouvez procéder aux démarches.', true);
  } else {
    addJournalEntry('Terrain inspecté. ' + (pnj.role || 'Présence') + ' détectée.', 'event-info');
    showToast(pnj.role || 'Obstacle détecté', pnj.trait || '', pnj.rel !== 'enemy');
  }

  // Recharger la pièce complète pour afficher le PNJ
  if (state.currentRoom && state.currentBuilding) {
    enterRoom(state.currentBuilding, state.currentRoom);
  }
}

// Appeler la police sur un terrain — ouvre le choix
function doAppelerPoliceTerrain() {
  const id = state.currentBuilding;
  const ts = getTerrainState(id);
  const pnj = ts.pnjData;
  const indices = INDICES_NATIONAUX?.[state.country] || { ISN: 30 };
  const isn = indices.ISN || 30;
  const delaiH = Math.max(6, Math.round(96 - isn * 0.6));
  const delaiRapideH = Math.max(1, Math.round(delaiH / 4));
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const coutSoudoiement = Math.floor(100 + isn * 3);

  document.getElementById('postes-modal-title').textContent = '🚔 Appeler la police';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +
    '<div style="font-size:.78rem;color:#c0b090;margin-bottom:.8rem">' +
      (pnj ? 'Présence détectée : <strong>' + pnj.role + '</strong>.' : 'Terrain occupé.') +
    '</div>' +
    '<div style="display:flex;flex-direction:column;gap:.5rem">' +
    '<button onclick="doExpulsionLegale();fermerModalPostes()" ' +
    'style="text-align:left;padding:.6rem .8rem;border:1px solid #3a5a3a;background:#0a0f0a;color:#6ada6a;font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.06em;cursor:pointer">' +
    '⚖️ Expulsion légale — délai ' + delaiH + 'h (gratuit)</button>' +
    '<button onclick="doExpulsionAcceleree(' + coutSoudoiement + ');fermerModalPostes()" ' +
    'style="text-align:left;padding:.6rem .8rem;border:1px solid #5a5a20;background:#0a0f00;color:#C9A84C;font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.06em;cursor:pointer">' +
    '💰 Soudoyer l\'inspecteur — ' + coutSoudoiement + ' ' + cur + ' · délai ' + delaiRapideH + 'h</button>' +
    '<button onclick="fermerModalPostes()" ' +
    'style="padding:.4rem;border:1px solid #2a2010;background:transparent;color:#6a5a30;font-family:Bebas Neue,sans-serif;font-size:.68rem;cursor:pointer">Annuler</button>' +
    '</div></div>';
  document.getElementById('modal-postes').classList.add('open');
}

function doExpulsionAcceleree(cout) {
  const id = state.currentBuilding;
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const indices = INDICES_NATIONAUX?.[state.country] || { ISN: 30 };
  const isn = indices.ISN || 30;
  const delaiRapideH = Math.max(1, Math.round((96 - isn * 0.6) / 4));
  const dup = state.char?.stats?.DUP || 8;
  const taux = Math.min(80, 40 + Math.floor(dup * 2));
  const roll = Math.floor(Math.random() * 100) + 1;

  if (state.arg < cout) { showToast('Fonds insuffisants', cout + ' ' + cur + ' requis.', false); return; }

  state.arg -= cout;
  if (roll <= taux) {
    setTerrainState(id, {
      policeAppellee: Date.now(),
      policeInterventionAt: Date.now() + delaiRapideH * 3600000
    });
    state.dis = Math.max(0, (state.dis || 50) - 5);
    updateUI();
    addJournalEntry('Inspecteur soudoyé pour ' + cout + ' ' + cur + '. Expulsion dans ' + delaiRapideH + 'h. -5 DIS.', 'event-good');
    showToast('Arrangé !', 'Expulsion dans ' + delaiRapideH + 'h. -' + cout + ' ' + cur + ' · -5 DIS.', true);
  } else {
    state.dis = Math.max(0, (state.dis || 50) - 15);
    updateUI();
    addJournalEntry('Tentative de corruption refusée. -' + cout + ' ' + cur + ' · -15 DIS.', 'event-bad');
    showToast('Refus !', 'L\'inspecteur a refusé. -' + cout + ' ' + cur + ' · -15 DIS.', false);
  }
}

// Faire disparaître le cadavre
function doFaireDisparaitreCadavre() {
  const id = state.currentBuilding;
  const ts = getTerrainState(id);
  const indices = INDICES_NATIONAUX?.[state.country] || { ISN: 30, ID: 40 };
  const isn = indices.ISN || 30;
  const id_idx = indices.ID || 40;

  const dis = state.dis || 50;
  const cha = state.char?.stats?.CHA || 8;
  const bonusOrga = calculerBonusOrga();
  const taux = Math.min(85, Math.floor(dis/2 + cha/2) - Math.floor(isn/5) + (bonusOrga.dis || 0) / 3);
  const roll = Math.floor(Math.random() * 100) + 1;

  if (roll <= taux) {
    // Succès — cadavre disparu
    const prescriptionJours = Math.max(7, Math.round(id_idx * 0.6));
    setTerrainState(id, {
      pnj: null, pnjData: null,
      cadavreDisparuAt: Date.now(),
      prescriptionAt: Date.now() + prescriptionJours * 86400000,
      actesIllegaux: [...(ts.actesIllegaux || []), {
        type: 'cadavre_dissimule',
        auteur: state.char?.name,
        date: Date.now(),
        prescriptionAt: Date.now() + prescriptionJours * 86400000
      }]
    });
    sessionStorage.removeItem('terrain_pnj_' + id);
    state.dis = Math.max(0, (state.dis || 50) - 5);
    updateUI();
    addJournalEntry('Cadavre dissimulé avec succès. Jet ' + roll + '/' + taux + '%. Prescription dans ' + prescriptionJours + ' jours.', 'event-good');
    showToast('Cadavre dissimulé !', 'Terrain libre. Prescription dans ' + prescriptionJours + ' jours. -5 DIS.', true);
  } else {
    // Échec — garde à vue
    state.dis = Math.max(0, (state.dis || 50) - 20);
    state.hp = Math.max(0, (state.hp || 100) - 5);
    updateUI();
    addJournalEntry('Flagrant délit ! Garde à vue de 24h. Jet ' + roll + '/' + taux + '%. -20 DIS · -5 HP.', 'event-bad');
    showToast('Arrêté !', 'Garde à vue 24h. -20 DIS · -5 HP. (Jet ' + roll + '/' + taux + '%)', false);
    // Bloquer le joueur 24h
    if (!state.recherche) state.recherche = [];
    state.recherche.push({ type: 'suspicion_cadavre', terrain: id, debut: Date.now(), fin: Date.now() + 86400000 });
    addExternalEvent('🚨 ' + (state.char?.name) + ' a été arrêté pour suspicion de dissimulation de cadavre à ' + (WORLD[state.country]?.[state.currentCity]?.name || 'la ville') + '.');
  }
}

// Négocier avec les squatteurs
function doNegocierSquatteurs() {
  const id = state.currentBuilding;
  const ts = getTerrainState(id);
  const pnj = ts.pnjData;
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  const minMontant = pnj?.id === 'squatter_agr' ? 500 : 0;

  document.getElementById('postes-modal-title').textContent = 'Négocier le départ';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +
    '<div style="font-size:.78rem;color:#c0b090;margin-bottom:.6rem;font-style:italic">"' + (pnj?.trait || '') + '"</div>' +
    (minMontant > 0 ? '<div style="font-size:.7rem;color:#8a3a2a;margin-bottom:.5rem">Ces squatteurs refuseront toute offre inférieure à ' + minMontant + ' ' + cur + '.</div>' : '') +
    '<div style="font-size:.72rem;color:#8a8060;margin-bottom:.4rem">Chaque 100 ' + cur + ' supplémentaires améliorent vos chances de +1%.</div>' +
    '<input id="negoc-montant" type="number" min="' + minMontant + '" step="100" placeholder="Montant proposé..." ' +
    'style="width:100%;padding:.4rem .6rem;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;font-family:Crimson Pro,Georgia,serif;font-size:.85rem;box-sizing:border-box;margin-bottom:.6rem"/>' +
    '<button onclick="confirmerNegociation()" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">Négocier</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerNegociation() {
  const id = state.currentBuilding;
  const ts = getTerrainState(id);
  const pnj = ts.pnjData;
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const montant = parseInt(document.getElementById('negoc-montant')?.value || 0);
  const indices = INDICES_NATIONAUX?.[state.country] || { IS: 45 };
  const is = indices.IS || 45;

  if (!montant || montant < (pnj?.id === 'squatter_agr' ? 500 : 0)) {
    showToast('Montant insuffisant', 'Les squatteurs refusent.', false);
    return;
  }
  if (state.arg < montant) {
    showToast('Fonds insuffisants', 'Vous n\'avez pas ' + montant + ' ' + cur + '.', false);
    return;
  }

  const cha = state.char?.stats?.CHA || 8;
  const bonusArgent = Math.min(40, Math.floor(montant / 100));
  const bonusOrga2 = calculerBonusOrga();
  const taux = Math.min(90, Math.floor(cha * 3 + is / 5) + bonusArgent + (bonusOrga2.nego_cha || 0));
  const roll = Math.floor(Math.random() * 100) + 1;

  state.arg -= montant;
  document.getElementById('modal-postes').classList.remove('open');

  if (roll <= taux) {
    setTerrainState(id, { pnj: null, pnjData: null });
    sessionStorage.removeItem('terrain_pnj_' + id);
    updateUI();
    addJournalEntry('Squatteurs convaincus pour ' + montant + ' ' + cur + '. Jet ' + roll + '/' + taux + '%.', 'event-good');
    showToast('Terrain libéré !', 'Les squatteurs sont partis. -' + montant + ' ' + cur, true);
  } else {
    updateUI();
    addJournalEntry('Négociation échouée. ' + montant + ' ' + cur + ' perdus. Jet ' + roll + '/' + taux + '%.', 'event-bad');
    showToast('Refus !', 'Ils ont pris l\'argent mais restent. -' + montant + ' ' + cur, false);
  }
}

// Signer un compromis de vente
function doSignerCompromis() {
  const id = state.currentBuilding;
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  const dispo = terrainOrdreDisponible('signer_compromis', id);
  if (!dispo.ok) { showToast('Impossible', dispo.raison, false); return; }

  setTerrainState(id, {
    compromis: true,
    compromisAt: Date.now(),
    compromisExpireAt: Date.now() + 7 * 86400000
  });
  state.arg -= 500;
  updateUI();
  addJournalEntry('Compromis de vente signé pour 500 ' + cur + '. Valable 7 jours.', 'event-good');
  showToast('Compromis signé !', 'Terrain réservé 7 jours. -500 ' + cur, true);
}

// Acheter le terrain (modifié pour tenir compte du permis)
function doAcheterTerrain() {
  const id = state.currentBuilding;
  const ts = getTerrainState(id);
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const b = BUILDINGS[id];
  const localName = b?.shortName || b?.name || id;

  const dispo = terrainOrdreDisponible('acheter_terrain', id);
  if (!dispo.ok) { showToast('Impossible', dispo.raison, false); return; }

  const prix = 5000;
  if (state.arg < prix) { showToast('Fonds insuffisants', prix + ' ' + cur + ' requis.', false); return; }

  state.arg -= prix;
  if (!state.terrainsAchetes) state.terrainsAchetes = {};
  state.terrainsAchetes[id] = state.char?.name;

  const aPermis = ts.permis;
  setTerrainState(id, {
    proprietaire: state.char?.name,
    acheteAt: Date.now(),
    constructionAutorisee: !!aPermis
  });

  updateUI();
  if (!aPermis) {
    addJournalEntry('Terrain ' + localName + ' acheté pour ' + prix + ' ' + cur + '. SANS permis — construction bloquée jusqu\'autorisation du maire.', 'event-info');
    showToast('Terrain acheté !', 'Sans permis : construction bloquée. Demandez l\'autorisation au maire.', true);
  } else {
    addJournalEntry('Terrain ' + localName + ' acheté pour ' + prix + ' ' + cur + '. Permis valide.', 'event-good');
    showToast('Terrain acheté !', 'Avec permis. Construction autorisée.', true);
  }
}


// =====================
// DONNER DE L'ARGENT À UN PNJ
// =====================
function doDonnerArgentPnj() {
  const id = state.currentBuilding;
  const ts = getTerrainState(id);
  const pnj = ts.pnjData;
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  if (!pnj) {
    showToast('Personne ici', 'Aucun PNJ à qui donner quelque chose.', false);
    return;
  }

  const indices = INDICES_NATIONAUX?.[state.country] || { ISN:30, IE:50, ID:40, IS:45 };
  const isn = indices.ISN || 30;

  // Seuil minimum selon type de PNJ et ISN
  const seuils = {
    inspecteur: Math.floor(100 + isn * 2),
    gardien: Math.floor(50 + isn),
    squatter_agr: 500,
    squatter_cool: 0,
    promoteur: 0,
    cadavre: 0,
    default: 0
  };
  const seuilMin = seuils[pnj.id] || seuils.default;

  // PNJ incorruptibles selon ISN (inspecteur en Sovarka)
  const tauxRefus = Math.max(0, isn - 50) / 2;

  document.getElementById('postes-modal-title').textContent = 'Donner à ' + (pnj.name || 'ce PNJ');
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +
    '<div style="font-size:.78rem;color:#c0b090;margin-bottom:.6rem;font-style:italic">"' + (pnj.trait || '') + '"</div>' +
    (seuilMin > 0
      ? '<div style="font-size:.7rem;color:#8a6a30;margin-bottom:.5rem">Montant minimum suggéré : ' + seuilMin + ' ' + cur + '</div>'
      : '') +
    (tauxRefus > 0
      ? '<div style="font-size:.68rem;color:#8a3a2a;margin-bottom:.5rem">Risque de refus : ' + Math.round(tauxRefus) + '% (empire sécurisé)</div>'
      : '') +
    '<input id="don-montant" type="number" min="0" step="50" placeholder="Montant en ' + cur + '..." ' +
    'style="width:100%;padding:.4rem .6rem;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;font-family:Crimson Pro,Georgia,serif;font-size:.85rem;box-sizing:border-box;margin-bottom:.6rem"/>' +
    '<button onclick="confirmerDonArgent()" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">💰 Donner</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerDonArgent() {
  const id = state.currentBuilding;
  const ts = getTerrainState(id);
  const pnj = ts.pnjData;
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const montant = parseInt(document.getElementById('don-montant')?.value || 0);
  const indices = INDICES_NATIONAUX?.[state.country] || { ISN:30, IE:50, IS:45 };
  const isn = indices.ISN || 30;

  if (!montant || montant <= 0) { showToast('Montant invalide', 'Entrez un montant.', false); return; }
  if (state.arg < montant) { showToast('Fonds insuffisants', montant + ' ' + cur + ' requis.', false); return; }

  const dup = state.char?.stats?.DUP || 8;
  const dis = state.dis || 50;

  // Jet de refus selon ISN
  const tauxRefus = Math.max(0, isn - 50) / 2;
  const rollRefus = Math.floor(Math.random() * 100) + 1;

  document.getElementById('modal-postes').classList.remove('open');

  if (rollRefus <= tauxRefus) {
    // Refus — pénalité DIS
    state.dis = Math.max(0, (state.dis || 50) - 10);
    updateUI();
    addJournalEntry('Don refusé par ' + (pnj?.name || 'le PNJ') + '. -10 DIS. (Refus ' + rollRefus + '/' + Math.round(tauxRefus) + '%)', 'event-bad');
    showToast('Refus !', (pnj?.name || 'Le PNJ') + ' a refusé avec indignation. -10 DIS.', false);
    return;
  }

  // Don accepté — effets selon type de PNJ
  state.arg -= montant;

  const effets = {
    inspecteur: () => {
      // Corruption inspecteur — ferme les yeux sur les manquements
      const taux = Math.min(85, Math.floor(dup * 3 + montant / 50));
      const roll = Math.floor(Math.random() * 100) + 1;
      if (roll <= taux) {
        setTerrainState(id, { inspecteurCorrompu: true, permisImplicite: true });
        state.dis = Math.max(0, (state.dis || 50) - 5);
        updateUI();
        addJournalEntry('Inspecteur corrompu pour ' + montant + ' ' + cur + '. Manquements ignorés. -5 DIS.', 'event-good');
        showToast('Arrangement conclu !', 'L\'inspecteur regarde ailleurs. -5 DIS.', true);
        // Retirer le PNJ
        setTerrainState(id, { pnj: null, pnjData: null });
        sessionStorage.removeItem('terrain_pnj_' + id);
        if (state.currentRoom) enterRoom(state.currentBuilding, state.currentRoom);
      } else {
        state.dis = Math.max(0, (state.dis || 50) - 15);
        updateUI();
        addJournalEntry('Tentative de corruption échouée. -' + montant + ' ' + cur + ' · -15 DIS.', 'event-bad');
        showToast('Refus indigné !', 'L\'inspecteur menace de faire un rapport. -15 DIS.', false);
      }
    },
    gardien: () => {
      setTerrainState(id, { pnj: null, pnjData: null });
      sessionStorage.removeItem('terrain_pnj_' + id);
      state.dis = Math.min(100, (state.dis || 50) + 3);
      updateUI();
      addJournalEntry('Gardien soudoyé pour ' + montant + ' ' + cur + '. +3 DIS.', 'event-good');
      showToast('Gardien convaincu !', 'Il regarde ailleurs. +3 DIS.', true);
      if (state.currentRoom) enterRoom(state.currentBuilding, state.currentRoom);
    },
    squatter_cool: () => {
      const bonus = Math.min(40, Math.floor(montant / 100));
      const cha = state.char?.stats?.CHA || 8;
      const taux = Math.min(85, cha * 3 + bonus);
      const roll = Math.floor(Math.random() * 100) + 1;
      if (roll <= taux) {
        setTerrainState(id, { pnj: null, pnjData: null });
        sessionStorage.removeItem('terrain_pnj_' + id);
        updateUI();
        addJournalEntry('Squatteurs partis pour ' + montant + ' ' + cur + '. Jet ' + roll + '/' + taux + '%.', 'event-good');
        showToast('Ils s\'en vont !', '"Ok on se casse. Ciao." -' + montant + ' ' + cur, true);
        if (state.currentRoom) enterRoom(state.currentBuilding, state.currentRoom);
      } else {
        updateUI();
        showToast('Ils prennent l\'argent mais restent...', '-' + montant + ' ' + cur, false);
        addJournalEntry('Squatteurs ont pris ' + montant + ' ' + cur + ' mais refusent de partir. Jet ' + roll + '/' + taux + '%.', 'event-bad');
      }
    },
    squatter_agr: () => {
      if (montant < 500) {
        state.arg += montant; // Rembourser
        showToast('Insulté !', 'Ils ont jeté vos billets. Minimum 500 ' + cur + '.', false);
        return;
      }
      const bonus = Math.min(40, Math.floor(montant / 100));
      const taux = Math.min(70, 15 + bonus);
      const roll = Math.floor(Math.random() * 100) + 1;
      if (roll <= taux) {
        setTerrainState(id, { pnj: null, pnjData: null });
        sessionStorage.removeItem('terrain_pnj_' + id);
        updateUI();
        addJournalEntry('Squatteurs agressifs partis pour ' + montant + ' ' + cur + '. Jet ' + roll + '/' + taux + '%.', 'event-good');
        showToast('Ils partent !', '"On se casse. Cette fois." -' + montant + ' ' + cur, true);
        if (state.currentRoom) enterRoom(state.currentBuilding, state.currentRoom);
      } else {
        state.hp = Math.max(0, (state.hp || 100) - 10);
        updateUI();
        addJournalEntry('Squatteurs ont pris ' + montant + ' ' + cur + ' et vous ont frappé. -10 HP.', 'event-bad');
        showToast('Volés et tabassés !', '-' + montant + ' ' + cur + ' · -10 HP.', false);
      }
    },
    promoteur: () => {
      // Le promoteur révèle des infos
      state.inf = Math.min(100, (state.inf || 0) + 5);
      updateUI();
      addJournalEntry('Gérard Spéculos vous donne des infos sur le marché pour ' + montant + ' ' + cur + '. +5 INF.', 'event-good');
      showToast('Info obtenue !', '+5 INF. Il sait des choses sur ce quartier.', true);
    },
    default: () => {
      updateUI();
      addJournalEntry('Don de ' + montant + ' ' + cur + ' accepté.', 'event-info');
      showToast('Don accepté', (pnj?.name || 'Le PNJ') + ' apprécie le geste.', true);
    }
  };

  (effets[pnj?.id] || effets.default)();
}

// Expulsion légale via police (sans soudoiement)
function doExpulsionLegale() {
  const id = state.currentBuilding;
  const ts = getTerrainState(id);
  const indices = INDICES_NATIONAUX?.[state.country] || { ISN:30 };
  const isn = indices.ISN || 30;

  // Délai selon ISN — plus ISN est élevé, plus c'est rapide
  const delaiH = Math.max(6, Math.round(96 - isn * 0.6));
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  // Ajouter l'inspecteur de police comme PNJ visible
  const pnjPolice = (TERRAIN_PNJ_PROFILES?.[state.country] || TERRAIN_PNJ_PROFILES?.republic || [])
    .find(p => p.id === 'inspecteur_police') || {
      name: 'L\'Inspecteur', role: 'Inspecteur de police', job: 'commissaire',
      rel: 'neutral', trait: 'Arrive quand on l\'appelle. Prend note. Repart.'
    };

  // Stocker la demande d'expulsion
  setTerrainState(id, {
    expulsionDemandeeAt: Date.now(),
    expulsionAt: Date.now() + delaiH * 3600000,
    pnjPolice: pnjPolice
  });

  // Afficher l'inspecteur de police dans la pièce temporairement
  const pnjPoliceSession = {
    name: pnjPolice.name + ' (PNJ)',
    role: pnjPolice.role,
    job: pnjPolice.job,
    rel: pnjPolice.rel,
    trait: pnjPolice.trait,
    photoUrl: pnjPolice.photoUrl,
    photoPos: pnjPolice.photoPos,
    terrainPnjId: 'inspecteur_police'
  };
  sessionStorage.setItem('terrain_pnj_police_' + id, JSON.stringify(pnjPoliceSession));

  addJournalEntry('Expulsion légale demandée. L\'inspecteur est sur place. Résolution dans ' + delaiH + 'h.', 'event-info');
  showToast('Police sur place', 'Expulsion dans ' + delaiH + 'h. Soudoyez l\'inspecteur pour accélérer.', true);

  if (state.currentRoom) enterRoom(state.currentBuilding, state.currentRoom);
}

// =====================
// RACHAT DE TERRAIN ENTRE PJ
// =====================
function doRacheterTerrain() {
  const building = state.currentBuilding;
  const b = BUILDINGS[building];
  if (!b) return;

  // Vérifier si le terrain appartient à quelqu'un
  const proprietaire = state.terrainsAchetes?.[building];
  if (!proprietaire) {
    showToast('Terrain libre', 'Ce terrain n\'est pas encore propriété privée. Vous pouvez l\'acheter directement.', false);
    return;
  }
  if (proprietaire === state.char?.name) {
    showToast('Votre terrain', 'Ce terrain vous appartient déjà.', false);
    return;
  }

  const cur = COUNTRIES[state.country]?.cur || 'FR';

  // Ouvrir modal pour saisir le prix
  document.getElementById('postes-modal-title').textContent = 'Offre de rachat';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1rem">' +
    '<div style="font-size:.82rem;color:#a09060;margin-bottom:.8rem">Ce terrain appartient à <strong style="color:#C9A84C">' + proprietaire + '</strong>.<br>Proposez un prix de rachat. Un mail lui sera envoyé automatiquement.</div>' +
    '<input id="rachat-prix" type="number" min="1000" step="500" placeholder="Prix proposé en ' + cur + '..." style="width:100%;padding:.4rem .6rem;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;font-family:Crimson Pro,Georgia,serif;font-size:.85rem;box-sizing:border-box;margin-bottom:.6rem"/>' +
    '<button onclick="confirmerRachat(this)" data-building="' + building + '" data-proprio="' + proprietaire + '" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer;width:100%">Envoyer l\'offre</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerRachat(btn) {
  const buildingId = btn?.dataset?.building || btn;
  const proprietaire = btn?.dataset?.proprio || arguments[1];
  const prix = parseInt(document.getElementById('rachat-prix')?.value || 0);
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const b = BUILDINGS[buildingId];
  const localName = b?.shortName || b?.name || buildingId;

  if (!prix || prix < 1000) {
    showToast('Prix invalide', 'Proposez au moins 1000 ' + cur + '.', false);
    return;
  }
  if (state.arg < prix) {
    showToast('Fonds insuffisants', 'Vous n\'avez pas ' + prix.toLocaleString('fr-FR') + ' ' + cur + '.', false);
    return;
  }

  // Envoyer un mail au propriétaire
  const from = state.char?.name || 'Anonyme';
  const subject = 'Offre de rachat — ' + localName;
  const body = from + ' vous propose de racheter votre terrain "' + localName + '" pour <strong>' + prix.toLocaleString('fr-FR') + ' ' + cur + '</strong>.<br><br>Pour accepter, répondez à ce mail en indiquant "J\'accepte". Le transfert sera effectué par la mairie.';

  if (typeof sendMail === 'function') {
    await sendMail(proprietaire, subject, body);
  }

  document.getElementById('modal-postes').classList.remove('open');
  addJournalEntry('Offre de rachat envoyée à ' + proprietaire + ' pour ' + prix.toLocaleString('fr-FR') + ' ' + cur + '.', 'event-info');
  showToast('Offre envoyée !', proprietaire + ' a reçu votre proposition.', true);
}

function accepterRachat(acheteur, buildingId, prix) {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const b = BUILDINGS[buildingId];
  const localName = b?.shortName || b?.name || buildingId;

  // Transférer le terrain
  if (!state.terrainsAchetes) state.terrainsAchetes = {};
  state.terrainsAchetes[buildingId] = acheteur;
  state.arg += prix;
  updateUI();

  addJournalEntry('Terrain "' + localName + '" vendu à ' + acheteur + ' pour ' + prix.toLocaleString('fr-FR') + ' ' + cur + '.', 'event-good');
  showToast('Terrain vendu !', '+' + prix.toLocaleString('fr-FR') + ' ' + cur, true);

  // Notifier l'acheteur
  if (typeof sendMail === 'function') {
    sendMail(acheteur, 'Transfert de propriété — ' + localName,
      'Votre offre a été acceptée. Le terrain "' + localName + '" vous appartient désormais.');
  }
}

// =====================
// SONDAGES ABSURDES
// =====================
async function commanderSondage() {
  const co = COUNTRIES[state.country];
  const cur = co?.cur || 'FR';

  if (state.arg < 200) {
    showToast('Fonds insuffisants', '200 ' + cur + ' requis.', false);
    return;
  }
  state.arg -= 200;

  const sujets = [
    'la popularité du fromage local comme symbole national',
    'l\'opportunité de renommer la capitale',
    'l\'instauration d\'une journée nationale obligatoire de sieste',
    'la privatisation de la météo',
    'l\'élection du PNJ le plus sympathique de la ville',
    'l\'interdiction des réunions de plus de 3 personnes le lundi matin',
    'la construction d\'une statue du fondateur de l\'empire',
    'la légalisation du troc comme monnaie officielle',
    'l\'obligation de porter un chapeau dans les institutions',
    'la semaine de travail à 2 jours'
  ];
  const sujet = sujets[Math.floor(Math.random() * sujets.length)];
  const empireStyle = EMPIRE_STYLES?.[state.country] || { tone: 'parodique', religion: 'la Foi Locale', leader: 'le Chef' };

  const prompt = 'Tu travailles dans un institut de sondage parodique dans l\'empire ' + (co?.n || 'inconnu') + '. ' +
    'Style : ' + empireStyle.tone + '. Religion locale : ' + empireStyle.religion + '. Chef suprême : ' + empireStyle.leader + '. ' +
    'Génère un sondage absurde et parodique sur : ' + sujet + '. ' +
    'Format : 1 question + 4 choix de réponse + 1 résultat fictif avec pourcentages. ' +
    'Maximum 6 lignes. Très drôle et dans le style de l\'empire. Pas de vrais dieux.';

  document.getElementById('postes-modal-title').textContent = 'Sondage en cours...';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060;font-style:italic">Institut de Sondage au travail...</div>';
  document.getElementById('modal-postes').classList.add('open');

  try {
    const resp = await fetch('/api/chat', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({ model: 'claude-sonnet-4-5', max_tokens: 250, messages: [{ role: 'user', content: prompt }] })
    });
    const data = await resp.json();
    const resultat = data.content?.[0]?.text || 'Sondage indisponible.';

    document.getElementById('postes-modal-title').textContent = '📊 Sondage Officiel';
    document.getElementById('postes-body').innerHTML =
      '<div style="padding:1rem">' +
      '<div style="font-size:.7rem;color:#6a5a30;margin-bottom:.6rem;font-style:italic">Commandé par ' + (state.char?.name || 'Anonyme') + ' · Coût : 200 ' + cur + '</div>' +
      '<div style="font-size:.85rem;color:#c0a060;line-height:1.8;white-space:pre-line;font-family:Crimson Pro,Georgia,serif">' + resultat + '</div>' +
      '<div style="margin-top:.8rem;display:flex;gap:.5rem">' +
      '<button onclick="publierSondage(this.dataset.txt)" data-txt="' + resultat.replace(/"/g, '&quot;') + '"" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.4rem .8rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer"><i class="ti ti-news" style="font-size:.7rem"></i> Publier sur le forum</button>' +
      '<button onclick="document.getElementById(\'modal-postes\').classList.remove(\'open\')" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.4rem .8rem;border:1px solid #3a2a10;background:transparent;color:#6a5a30;cursor:pointer">Fermer</button>' +
      '</div></div>';

    state.inf = Math.min(100, (state.inf || 0) + 3);
    updateUI();
    addJournalEntry('Sondage commandé sur : ' + sujet + '. -200 ' + cur, 'event-info');

  } catch(e) {
    document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a3a20">Erreur lors de la génération du sondage.</div>';
  }
}

async function publierSondage(texte) {
  document.getElementById('modal-postes').classList.remove('open');
  if (typeof sbCreateTopic === 'function') {
    const from = state.char?.name || 'Anonyme';
    await sbCreateTopic('local', '📊 Sondage : ' + texte.substring(0, 50) + '...', texte, from);
    showToast('Sondage publié !', 'Visible sur le forum local.', true);
    addJournalEntry('Sondage publié sur le forum.', 'event-info');
  } else {
    showToast('Forum indisponible', 'Impossible de publier.', false);
  }
}

// =====================
// RÉPERTOIRE PJ
// =====================
async function ouvrirRepertoirePJ() {
  document.getElementById('postes-modal-title').textContent = 'Répertoire des Joueurs';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a8060;font-style:italic">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const myName = state.char?.name || '';
  const empireColors = { republic:'#C9A84C', narco:'#d4862a', soviet:'#9a2020', khalija:'#20a090' };
  const empireNames  = { republic:'Républia', narco:'El Estado', soviet:'Sovarka', khalija:'Al-Khalija' };

  // Charger depuis Supabase
  let joueurs = [];
  if (typeof sbListPersonnages === 'function') {
    try { joueurs = await sbListPersonnages() || []; } catch(e) {}
  }

  // Ajouter soi-même si pas dans la liste
  if (myName && !joueurs.find(j => j.name === myName)) {
    joueurs.unshift({ name: myName, country: state.country, current_city: state.currentCity, poste: state.poste, domicile: state.domicile });
  }

  if (joueurs.length === 0) {
    document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#4a4030;font-style:italic">Aucun joueur enregistre pour l\'instant.</div>';
    return;
  }

  // Grouper par empire
  const byEmpire = {};
  joueurs.forEach(j => {
    if (!byEmpire[j.country]) byEmpire[j.country] = [];
    byEmpire[j.country].push(j);
  });

  const html = Object.entries(byEmpire).map(([country, pjs]) => {
    const col = empireColors[country] || '#C9A84C';
    const empName = empireNames[country] || country;
    return `
      <div style="padding:.4rem 1rem;font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.15em;color:${col};border-bottom:1px solid #2a2010;margin-top:.3rem">
        ${empName} — ${pjs.length} joueur(s)
      </div>
      ${pjs.map(j => {
        const isMe = j.name === myName;
        const posteLabel = j.poste?.name || '';
        const villeDomicileId = j.domicile?.city;
        const villeDomicileNom = villeDomicileId ? (WORLD[j.country]?.[villeDomicileId]?.name || villeDomicileId) : null;
        return `
          <div style="display:flex;align-items:center;gap:.8rem;padding:.5rem 1rem;border-bottom:1px solid #1a1810;${isMe ? 'background:rgba(201,168,76,0.05)' : ''}">
            <div style="width:32px;height:32px;border-radius:50%;border:1px solid ${isMe ? col : '#2a2010'};background:#0a0a07;display:flex;align-items:center;justify-content:center;flex-shrink:0">
              <i class="ti ti-user" style="font-size:.75rem;color:${isMe ? col : '#4a4030'}"></i>
            </div>
            <div style="flex:1">
              <div style="font-size:.82rem;color:${isMe ? col : '#f0ead6'};font-weight:${isMe ? 'bold' : 'normal'}">
                ${j.name}${isMe ? ' ✦' : ''}
              </div>
              <div style="font-size:.68rem;color:#6a5a30">
                ${posteLabel ? posteLabel + ' · ' : ''}${empName}${villeDomicileNom ? ' · Domicile : ' + villeDomicileNom : ''}
              </div>
            </div>
            ${!isMe ? `<button onclick="composerMailPour(this.dataset.name)" data-name="${j.name}" style="font-family:Bebas Neue,sans-serif;font-size:.62rem;letter-spacing:.06em;padding:.2rem .5rem;border:1px solid #2a2010;background:transparent;color:#8a8060;cursor:pointer">
              <i class="ti ti-mail" style="font-size:.65rem"></i>
            </button>` : ''}
          </div>`;
      }).join('')}
    `;
  }).join('');

  document.getElementById('postes-body').innerHTML = html;
}

function composerMailPour(destinataire) {
  // Fermer les autres modaux
  document.getElementById('modal-postes').classList.remove('open');
  // Ouvrir le modal de composition indépendant
  document.getElementById('compose-mail-to').value = destinataire || '';
  document.getElementById('compose-mail-subject').value = '';
  document.getElementById('compose-mail-body').value = '';
  document.getElementById('modal-compose-mail').classList.add('open');
}

function fermerComposeMail() {
  document.getElementById('modal-compose-mail').classList.remove('open');
}

async function envoyerComposeMail() {
  const to = document.getElementById('compose-mail-to').value.trim();
  const subject = document.getElementById('compose-mail-subject').value.trim();
  const body = document.getElementById('compose-mail-body').value.trim();
  if (!to || !subject || !body) {
    showToast('Champs requis', 'Remplissez tous les champs.', false);
    return;
  }
  if (typeof sendMail === 'function') {
    await sendMail(to, subject, body);
  } else {
    // Fallback direct Supabase
    const from = state.char?.name || 'Anonyme';
    const h = String(state.hour || 8).padStart(2,'0');
    const time = 'Jour ' + (state.day || 1) + ' · ' + h + 'h';
    if (typeof sbSendMail === 'function') await sbSendMail(from, to, subject, body, time);
    addJournalEntry('Mail envoyé à ' + to + ' : "' + subject + '".', 'event-info');
    showToast('Mail envoyé', 'À ' + to + ' — "' + subject + '"', true);
  }
  fermerComposeMail();
}

// =====================
// ORGANIGRAMME
// =====================
function ouvrirOrganigramme() {
  const postes = POSTES[state.country];
  if (!postes) return;
  const co = COUNTRIES[state.country];
  const myName = state.char?.name || '';

  const sections = [
    { title: 'Exécutif', postes: postes.capitale || [] },
    { title: 'Assemblée', postes: postes.assemblee || [] },
    { title: 'Villes', postes: [
      ...(postes.ville_a || []),
      ...(postes.ville_b || [])
    ]}
  ].filter(s => s.postes.length > 0);

  document.getElementById('postes-modal-title').textContent = `Organigramme — ${co?.n || 'Empire'}`;
  document.getElementById('postes-body').innerHTML = sections.map(s => `
    <div style="padding:.5rem 1rem;font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.15em;color:#8a6a20;border-bottom:1px solid #2a2010;margin-top:.3rem">${s.title}</div>
    ${s.postes.map(p => {
      // Vérifier si le joueur courant occupe ce poste
      const isMe = state.poste?.id === p.id;
      const holderName = isMe ? myName : p.holder;
      const isPJ = holderName && !holderName.startsWith('PNJ');
      const holderLabel = !holderName
        ? '<span style="color:#4a4030;font-style:italic">Vacant</span>'
        : holderName.startsWith('PNJ')
          ? '<span style="color:#4a4030">PNJ</span>'
          : `<span style="color:${isMe ? '#C9A84C' : '#4a8a4a'}">${holderName}${isMe ? ' ✦' : ''}</span>`;
      return `<div style="display:flex;justify-content:space-between;align-items:center;padding:.4rem 1rem;border-bottom:1px solid #1a1810">
        <div style="font-size:.78rem;color:#c0b090">${p.name}</div>
        <div style="font-size:.75rem">${holderLabel}</div>
      </div>`;
    }).join('')}
  `).join('');

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
    // Marquer le poste comme pris dans POSTES
    if (poste) poste.holder = state.char?.name || 'Joueur';
    // Libérer l'ancien poste si applicable
    if (state.poste?.id && state.poste.id !== posteId) {
      const oldPoste = [...(POSTES[state.country]?.capitale||[]), ...(POSTES[state.country]?.assemblee||[])].find(p => p.id === state.poste.id);
      if (oldPoste && oldPoste.holder === (state.char?.name || 'Joueur')) oldPoste.holder = null;
    }
    state.poste = { id: posteId, name: posteName };
    if (state.char) state.char.poste = state.poste;
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

  document.getElementById('postes-modal-title').textContent = 'Porter plainte';
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
  const nouvellePlainte = {
    id: 'plainte-' + Date.now(),
    country: state.country,
    city: state.currentCity,
    cible, motif,
    heure: `${String(resultH).padStart(2,'0')}h${m}`,
    day: state.day + 1,
    status: 'pending'
  };
  state.plaintesEnCours.push(nouvellePlainte);
  if (typeof sbSavePlainte === 'function') sbSavePlainte(nouvellePlainte).catch(() => {});
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
      // Programmer le resultat de l'enquete (motif transporte pour le tribunal)
      if (!state.enquetesEnCours) state.enquetesEnCours = [];
      state.enquetesEnCours.push({ cible: p.cible, motif: p.motif, day: state.day + 1, status: 'pending' });
    } else {
      result = `Actes illegaux confirmes pour ${p.cible}. Mise en garde a vue. Proces dans 24h.`;
      addExternalEvent(`ACTION EXTERIEURE : ${p.cible} a ete place(e) en garde a vue suite a votre plainte. Proces prevu demain.`, 'local');
      // Transmettre directement au tribunal — l'affaire est mure pour jugement
      transmettreAffaireAuTribunal(p.cible, p.motif || 'Plainte initiale confirmee par les forces de l\'ordre.');
    }
    addMailNotification('Commissariat Central', `RE: Votre plainte du Jour ${p.day - 1}`, result);
    if (typeof sbSavePlainte === 'function') sbSavePlainte(p).catch(() => {});
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
      result = `Enquete conclue : actes illegaux confirmes pour ${e.cible}. Mise en garde a vue immediate. Affaire transmise au tribunal pour jugement.`;
      if (!state.prisonniers) state.prisonniers = [];
      state.prisonniers.push({ nom: e.cible, depuis: `Jour ${state.day}`, raison: 'Garde a vue suite a enquete' });
      addExternalEvent(`${e.cible} a ete place(e) en garde a vue. Affaire transmise au tribunal.`, 'local');
      // Transmettre au tribunal pour jugement public
      transmettreAffaireAuTribunal(e.cible, e.motif || 'Enquete policiere ayant confirme des actes illegaux.');
    }
    addMailNotification('Brigade Criminelle', `Conclusions enquete : ${e.cible}`, result);
  });
}

// =====================
// PONT COMMISSARIAT → TRIBUNAL
// Transmet une affaire confirmee pour jugement public (forum + file d'attente du juge)
// =====================
function transmettreAffaireAuTribunal(cible, motif) {
  const ville = WORLD[state.country]?.[state.currentCity]?.name || 'la ville';
  const forumKey = 'tribunal_' + state.currentCity;

  // Ajouter à la file d'attente du juge (statut lu par ouvrirRendreSentence) — visible par TOUS les juges via Supabase
  if (!state.plaintesEnCours) state.plaintesEnCours = [];
  const affaireTransmise = { id: 'affaire-' + Date.now(), country: state.country, city: state.currentCity, cible, motif, jour: state.day, status: 'deposee' };
  state.plaintesEnCours.push(affaireTransmise);
  if (typeof sbSavePlainte === 'function') sbSavePlainte(affaireTransmise).catch(() => {});

  // Publier sur le forum tribunal local (visible de tous, transparence judiciaire)
  if (!FORUM_TOPICS[forumKey]) FORUM_TOPICS[forumKey] = [];
  FORUM_TOPICS[forumKey].unshift({
    id: 'affaire-' + Date.now(),
    title: '[AFFAIRE TRANSMISE] ' + cible,
    author: 'Brigade Criminelle',
    time: 'Jour ' + (state.day || 1),
    replies: 0,
    isPlainte: true,
    cible,
    posts: [{
      author: 'Brigade Criminelle',
      time: 'Jour ' + (state.day || 1),
      content: '**AFFAIRE TRANSMISE AU TRIBUNAL**\n\nMis en cause : ' + cible + '\n\nMotif :\n' + motif + '\n\n_En attente de jugement par un magistrat._'
    }]
  });

  // Publier aussi sur Supabase pour que tous les joueurs de la ville le voient
  if (typeof sbCreateTopic === 'function') {
    const auteur = 'Brigade Criminelle';
    const heure = 'Jour ' + (state.day || 1);
    const textePost = '**AFFAIRE TRANSMISE AU TRIBUNAL**\n\nMis en cause : ' + cible + '\n\nMotif :\n' + motif + '\n\n_En attente de jugement par un magistrat._';
    sbCreateTopic(forumKey, '⚖️ [AFFAIRE] ' + cible, auteur, state.country, heure)
      .then(topicId => {
        if (topicId && typeof sbCreatePost === 'function') {
          sbCreatePost(topicId, auteur, textePost, heure);
        }
      }).catch(e => console.warn('Erreur transmission tribunal:', e));
  }
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
    const resp = await fetch('/api/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ model: 'claude-sonnet-4-5', max_tokens: 150, messages: [{ role: 'user', content: prompt }] })
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
  document.getElementById('postes-modal-title').textContent = 'Lancer une rumeur';
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
    addJournalEntry(`Rumeur sur ${cible} : personne n' a cru.`, '');
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

  document.getElementById('postes-modal-title').textContent = 'Assassiner — ' + cible.name;
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.82rem;color:#cc4444;font-style:italic;margin-bottom:1rem;padding:.5rem;background:#0f0505;border:1px solid #3a1010">Acte criminel. Peine : 7 jours QHS si echec. 15 jours si decouvert ulterieurement.</div>';

  // Options
  html += '<div style="display:flex;flex-direction:column;gap:.5rem">';

  html += '<button onclick="confirmerAssassinatArme(\'' + encodedCible + '\',\'mains\',' + tauxMains + ')" style="display:flex;justify-content:space-between;align-items:center;padding:.6rem 1rem;border:1px solid #3a2010;background:#0f0805;color:#c0a080;cursor:pointer;font-family:Crimson Pro,serif;font-size:.85rem">' +
    '<span>A mains nues</span><span style="font-family:Bebas Neue,sans-serif;font-size:.75rem;color:#8a6040">' + tauxMains + '% · 2 PA</span></button>';

  html += '<button onclick="confirmerAssassinatArme(\'' + encodedCible + '\',\'arme\',' + tauxArme + ')" ' +
    (!hasBlade ? 'disabled style="opacity:.4;cursor:not-allowed;' : 'style="cursor:pointer;') +
    'display:flex;justify-content:space-between;align-items:center;padding:.6rem 1rem;border:1px solid #4a1a08;background:#0f0805;color:' + (hasBlade ? '#c06040' : '#4a3020') + ';font-family:Crimson Pro,serif;font-size:.85rem">' +
    '<span>Arme blanche ' + (!hasBlade ? '(aucune en inventaire)' : '') + '</span>' +
    '<span style="font-family:Bebas Neue,sans-serif;font-size:.75rem;color:#8a5030">' + tauxArme + '% · 2 PA</span></button>';

  html += '<button onclick="confirmerAssassinatArme(\'' + encodedCible + '\',\'feu\',' + tauxFeu + ')" ' +
    (!hasGun ? 'disabled style="opacity:.4;cursor:not-allowed;' : 'style="cursor:pointer;') +
    'display:flex;justify-content:space-between;align-items:center;padding:.6rem 1rem;border:1px solid #5a1a08;background:#0f0805;color:' + (hasGun ? '#cc4444' : '#4a2020') + ';font-family:Crimson Pro,serif;font-size:.85rem">' +
    '<span>Arme a feu ' + (!hasGun ? '(aucune en inventaire)' : '') + ' — bruit !</span>' +
    '<span style="font-family:Bebas Neue,sans-serif;font-size:.75rem;color:#8a3030">' + tauxFeu + '% · 3 PA · -20 DIS</span></button>';

  html += '</div></div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerAssassinatArme(encodedCible, mode, taux) {
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
  document.getElementById('postes-modal-title').textContent = 'Joueurs Simules — Mode Test';
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


function depenseBudget(institution, montant) {
  const b = getBudgetInstitution(institution);
  if (!b) return true;
  if (b.solde < montant) {
    showToast('Budget insuffisant', institution + ' manque de fonds. Le ministre des Finances doit revoir la repartition.', false);
    addExternalEvent('L\'institution ' + institution + ' est sous-financee. Certains services sont suspendus.');
    return false;
  }
  b.solde -= montant;
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
  document.getElementById('postes-modal-title').textContent = 'Faire imprimer des tracts';
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
  document.getElementById('postes-modal-title').textContent = 'Donner des tracts a ' + pjName;
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
    openPnjModal(encodePnjSafe(portier));
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

  document.getElementById('postes-modal-title').textContent = 'Nommer un ministre';
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

async function validerNomination() {
  const poste = document.getElementById('nommer-poste')?.value;
  const contact = document.getElementById('nommer-contact')?.value;
  if (!poste || !contact) return;
  const noms = { min_int:"Ministre de l'Interieur", min_fin:'Ministre des Finances', min_just:'Ministre de la Justice', min_def:'Ministre de la Defense', min_info:"Ministre de l'Information", min_ae:'Ministre des AE' };
  const posteNom = noms[poste] || (state.postesCustom?.ministre?.nom) || (state.postesCustom?.comite?.nom) || poste;
  document.getElementById('modal-postes').classList.remove('open');
  await envoyerNotificationVraiJoueur(contact, 'Nomination ministerielle', 'Par decision presidentielle, vous etes nomme(e) au poste de ' + posteNom + '. Prenez vos fonctions immediatement.');
  showToast('Nomination envoyee', contact + ' nomme(e) ' + posteNom, true, true);
  addJournalEntry('Nomination de ' + contact + ' au poste de ' + posteNom, 'event-good');
  addExternalEvent('Nomination officielle : ' + contact + ' est nomme(e) ' + posteNom + ' par le President.');
}

function openCandidatureModal() {
  // Verifier que les elections sont en phase candidatures
  const elections = state.electionsEnCours || [];
  const electionsOuvertes = elections.filter(e => e.phase === 'candidatures');
  if (elections.length > 0 && electionsOuvertes.length === 0) {
    showToast('Candidatures fermees', 'La periode de candidature est terminee. Les campagnes sont en cours.', false);
    return;
  }
  document.getElementById('postes-modal-title').textContent = 'Deposer une candidature';
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

function confirmerCandidatureLegacy_MORT(electionId) {
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
  document.getElementById('postes-modal-title').textContent = 'Elections en cours';

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
  document.getElementById('postes-modal-title').textContent = 'Voter — ' + election.nom;
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
  // Unifie avec le module forum — une seule vraie implementation de la messagerie
  if (typeof switchToMail === 'function') {
    switchToMail();
    document.getElementById('modal-forum').classList.add('open');
  } else {
    showToast('Erreur', 'Messagerie indisponible.', false);
  }
}

// =====================
// FORUM EN VUE CENTRALE
// =====================
function openForumView(forumId) {
  openForum_module(forumId || 'local');
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
  let topics = FORUM_TOPICS[forumId] || [];
  // Charger depuis Supabase si forum tribunal
  if (forumId.startsWith('tribunal_') && typeof sbLoadForumTopics === 'function') {
    sbLoadForumTopics(forumId).then(rows => {
      if (rows?.length) {
        FORUM_TOPICS[forumId] = rows;
        renderForumTopics(forumId);
      }
    }).catch(()=>{});
  }
  const labels = {
    local:'Forum Local', regional:'Forum Regional', national:'Forum National',
    international:'Forum International', gouv:'Forum Gouvernemental',
    syndical:'Forum Syndical', president:'Forum Presidentiel', conseil:'Conseil des Ministres'
  };

  let html = '<div style="display:flex;height:100%">';

  // Sidebar forums
  html += '<div style="width:160px;background:#111208;border-right:1px solid #1a1a10;overflow-y:auto;flex-shrink:0">';
  const tribunalKey = 'tribunal_' + (state.currentCity || 'capitale');
  const villeNomForum = WORLD[state.country]?.[state.currentCity]?.name || 'la ville';
  const forums = [
    {id:'local',label:'Local'},{id:'regional',label:'Regional'},{id:'national',label:'National'},
    {id:'international',label:'International'},{id:'president',label:'Presidentiel'},
    {id:'conseil',label:'Conseil Min.'},{id:'gouv',label:'Gouvernemental'},{id:'syndical',label:'Syndical'},
    {id:tribunalKey,label:'⚖️ Tribunal — ' + villeNomForum}
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


function addExternalEvent(text, scope) {
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

  // Partager via Supabase — scope 'local' = visible uniquement dans la ville courante, sinon national
  if (typeof sbAddEvenementGlobal === 'function') {
    const city = scope === 'local' ? (state.currentCity || null) : null;
    sbAddEvenementGlobal(state.country || 'republic', city, text, state.day || 1).catch(() => {});
  }
}

// Charger les événements partagés depuis Supabase et les insérer dans le journal local
// Cache persistant (localStorage) des IDs d'evenements deja affiches, propre a chaque personnage
function _getEvenementsChargesKey() {
  return 'respublica_evtvus_' + (state.char?.name || 'default');
}
function _getEvenementsCharges() {
  try {
    const raw = localStorage.getItem(_getEvenementsChargesKey());
    return raw ? new Set(JSON.parse(raw)) : new Set();
  } catch(e) { return new Set(); }
}
function _saveEvenementsCharges(set) {
  try {
    // Garder seulement les 300 derniers IDs pour ne pas grossir indefiniment
    const arr = Array.from(set).slice(-300);
    localStorage.setItem(_getEvenementsChargesKey(), JSON.stringify(arr));
  } catch(e) {}
}

async function chargerEvenementsPartages() {
  if (typeof sbGetEvenementsRecents !== 'function') return;
  try {
    const rows = await sbGetEvenementsRecents(state.country || 'republic', state.currentCity || 'capitale');
    if (!rows || rows.length === 0) return;
    const j = document.getElementById('journal');
    if (!j) return;
    const dejaVus = _getEvenementsCharges();
    // Trier du plus ancien au plus récent pour insertion cohérente
    const nouveaux = rows.filter(r => !dejaVus.has(r.id)).sort((a,b) => a.id - b.id);
    nouveaux.forEach(r => {
      dejaVus.add(r.id);
      const div = document.createElement('div');
      div.className = 'journal-entry journal-external';
      div.innerHTML = `
        <span class="journal-time">Jour ${r.jour || '?'}</span>
        <span class="journal-alert" onclick="this.style.display='none'" title="Cliquer pour marquer comme lu">●</span>
        <span class="journal-text event-external"><strong>${r.texte}</strong></span>
      `;
      j.insertBefore(div, j.firstChild);
    });
    if (nouveaux.length > 0) _saveEvenementsCharges(dejaVus);
  } catch(e) { console.warn('chargerEvenementsPartages error', e); }
}

// Récupère et crédite les dons d'argent reçus de la part d'autres joueurs (depuis Supabase)
async function recupererDonsEnAttente() {
  if (typeof sbRecupererDonsEnAttente !== 'function') return;
  const moi = state.char?.name;
  if (!moi) return;
  try {
    const dons = await sbRecupererDonsEnAttente(moi);
    if (!dons || dons.length === 0) return;
    const cur = COUNTRIES[state.country]?.cur || 'FR';
    let total = 0;
    for (const don of dons) {
      total += don.montant;
      if (typeof sbMarquerDonTraite === 'function') await sbMarquerDonTraite(don.id).catch(() => {});
    }
    if (total > 0) {
      state.arg = (state.arg || 0) + total;
      updateUI();
      addJournalEntry('💰 Vous avez reçu ' + total + ' ' + cur + ' en dons.', 'event-good');
      showToast('Dons reçus !', '+' + total + ' ' + cur + ' crédité(s) sur votre compte.', true, true);
    }
  } catch(e) { console.warn('recupererDonsEnAttente error', e); }
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
  // Mettre a jour le badge immediatement
  const unread = state.mails.filter(m => !m.read).length;
  const badge = document.getElementById('mail-badge');
  if (badge) { badge.textContent = unread; badge.style.display = unread > 0 ? 'inline' : 'none'; }
}

function showPostRequired(posteNom) {
  const msg = posteNom
    ? 'Cet ordre est réservé au ' + posteNom + '. Postez votre candidature au Palais du Gouvernement.'
    : 'Vous devez occuper un poste institutionnel pour accéder à cet ordre.';
  showToast('Accès restreint', msg, false);
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
  tuto: {
    titre: '🎓 Tutoriel — Premiers pas',
    contenu: `Bienvenue dans Res Publica ! Voici comment commencer en 5 étapes.

━━━━━━━━━━━━━━━━━━━━━━━━
ÉTAPE 1 — Créer votre personnage
━━━━━━━━━━━━━━━━━━━━━━━━
Choisissez votre empire, votre archétype et votre carrière. Chaque combinaison donne des bonus différents. Le criminel est rapide à l'argent, le fonctionnaire est stable, le journaliste accumule de l'influence.

━━━━━━━━━━━━━━━━━━━━━━━━
ÉTAPE 2 — Explorer la ville
━━━━━━━━━━━━━━━━━━━━━━━━
Utilisez le bouton "Plan" pour voir la carte de votre ville. Cliquez sur un bâtiment pour y entrer. Chaque bâtiment contient des pièces et des PNJ avec qui vous pouvez interagir.

━━━━━━━━━━━━━━━━━━━━━━━━
ÉTAPE 3 — Parler aux PNJ
━━━━━━━━━━━━━━━━━━━━━━━━
Cliquez sur un PNJ pour lui parler. Les PNJ répondent en fonction de leur personnalité et de l'actualité du forum. Certains ont des informations, d'autres des services.

━━━━━━━━━━━━━━━━━━━━━━━━
ÉTAPE 4 — Passer des ordres
━━━━━━━━━━━━━━━━━━━━━━━━
Chaque pièce propose des ordres (boutons en bas). Certains coûtent des PA (Points d'Action), d'autres de l'argent. Les ordres légaux sont sans risque, les ordres gris sont risqués, les illégaux peuvent vous valoir une arrestation.

━━━━━━━━━━━━━━━━━━━━━━━━
ÉTAPE 5 — Dormir pour progresser
━━━━━━━━━━━━━━━━━━━━━━━━
Dormez une fois par jour dans un hôtel ou via votre fiche personnage. Cela vous verse votre salaire, restaure vos PA et fait avancer le temps. Sans sommeil, pas de revenus !

━━━━━━━━━━━━━━━━━━━━━━━━
CONSEILS
━━━━━━━━━━━━━━━━━━━━━━━━
• Postez sur le forum — c'est le cœur de la vie politique
• Envoyez des mails aux autres joueurs via le bouton Messages
• Consultez l'organigramme à la mairie pour voir les postes disponibles
• Pour voyager, rendez-vous au Centre Multinodal`
  },
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
  religion: {
    titre: 'Les Religions',
    contenu: `Chaque empire possède sa propre religion officielle, source de cohésion sociale et de pouvoir politique.

LES 4 RELIGIONS :
• Républia → Le Papyrusisme — Vénération du Formulaire Sacré en 12 exemplaires. Grand Prêtre : le Percepteur Suprême. Temple : le Tabernacle des Impôts. Péché mortel : rendre un formulaire incomplet.

• El Estado → Le Cocaïsme — Culte de la Feuille Sacrée. Grand Prêtre : le Parrain Céleste. Temple : le Laboratoire de Prière. Communion quotidienne obligatoire.

• Sovarka → Le Tractorisme — Vénération du Tracteur Collectif. Grand Prêtre : le Camarade Pontife. Temple : le Kolkhoze Spirituel. Hérésie suprême : le tracteur privé.

• Al-Khalija → Le Loukoumisme — Vénération du Loukoum Divin. Grand Prêtre : le Grand Confiseur. Temple : la Pâtisserie Sacrée. Péché mortel : refuser un loukoum offert.

INDICE DE PIÉTÉ (IP) :
Chaque empire a un Indice de Piété (0-100). Plus il est élevé, plus la religion est influente. Il impacte l'Indice Social, la popularité des élus et l'ordre public.

LIEUX DE CULTE :
Chaque empire possède un lieu de culte accessible à tous. On peut y prier (+IP +Moral), se confesser (+Moral, mais le prêtre sait tout), faire des dons (+IP +POP), ou se déclarer pèlerin (+DIS).

CONFESSION :
Attention ! Tout ce que vous confiez au Grand Prêtre peut être consulté par le chef d'État. Choisissez vos aveux avec soin.

LE CHEF D'ÉTAT ET LA RELIGION :
Le Président peut nommer le Grand Prêtre depuis son bureau. Il peut aussi décréter des jours saints (impact IP et IS).`
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

    const dejaDormi = state.dernierDormir === (state.day || 1);
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

  } else if (tab === 'orgas') {
    content.innerHTML = '<div style="padding:.8rem 1rem">' + renderOngletOrgas() + '</div>';

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

    html += '<div style="margin-top:1rem;display:flex;gap:.5rem;flex-wrap:wrap">';
    html += '<button onclick="ouvrirModalChangerPhoto()" style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.08em;padding:.4rem .8rem;border:1px solid #6a5a30;background:transparent;color:#C9A84C;cursor:pointer"><i class="ti ti-camera"></i> Modifier la photo</button>';
    html += '</div>';

    html += '<div style="margin-top:2rem;padding-top:1rem;border-top:1px solid #2a1a10">';
    html += '<button onclick="ouvrirModalDetruirePersonnage()" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;letter-spacing:.08em;padding:.4rem .8rem;border:1px solid #6a2a20;background:transparent;color:#8a4a3a;cursor:pointer"><i class="ti ti-skull"></i> Détruire mon personnage</button>';
    html += '</div>';

    html += '</div>';
    content.innerHTML = html;
  }
}

// =====================
// CHANGEMENT DE PHOTO DE PROFIL
// =====================
function ouvrirModalChangerPhoto() {
  document.getElementById('postes-modal-title').textContent = 'Modifier la photo de profil';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.5rem">DEPUIS UN FICHIER</div>';
  html += '<input type="file" id="photo-file-input" accept="image/*" onchange="handlePhotoFileChange(event)" style="width:100%;color:#c0b090;font-size:.82rem;margin-bottom:1rem">';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.5rem">OU DEPUIS UNE URL</div>';
  html += '<input type="text" id="photo-url-input" placeholder="https://..." style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:1rem;box-sizing:border-box">';
  html += '<div id="photo-preview-zone" style="margin-bottom:1rem"></div>';
  html += '<button onclick="confirmerChangementPhoto()" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Enregistrer la photo</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

let _photoTemp = null;
function handlePhotoFileChange(event) {
  const f = event.target.files[0];
  if (!f) return;
  const r = new FileReader();
  r.onload = e => {
    _photoTemp = e.target.result;
    document.getElementById('photo-preview-zone').innerHTML = '<img src="' + _photoTemp + '" style="width:80px;height:80px;border-radius:50%;object-fit:cover;border:2px solid #8a6a20">';
  };
  r.readAsDataURL(f);
}

async function confirmerChangementPhoto() {
  const urlInput = document.getElementById('photo-url-input')?.value?.trim();
  const photoFinal = _photoTemp || urlInput || null;
  if (!photoFinal) { showToast('Aucune photo', 'Choisissez un fichier ou entrez une URL.', false); return; }

  if (!state.char) return;
  state.char.photoUrl = photoFinal;
  localStorage.setItem('respublica_photo_' + state.char.name, photoFinal);
  document.getElementById('modal-postes').classList.remove('open');

  if (typeof sbUpdatePhotoBio === 'function') {
    await sbUpdatePhotoBio(state.char.name, photoFinal, undefined).catch(() => {});
  }

  // Forcer la mise a jour du cache partage immediatement (sinon il faut attendre jusqu'a 60s)
  if (window._cachePhotosJoueurs && state.char.name) {
    window._cachePhotosJoueurs[state.char.name] = photoFinal;
  }

  _photoTemp = null;
  showToast('Photo mise à jour', 'Votre nouvelle photo de profil est enregistrée.', true, true);
  // Rafraîchir l'affichage de la fiche
  switchSelfTab('identite', document.querySelectorAll('#vue-self .piece-tab')[2] || null);
}

// =====================
// SUPPRESSION DE PERSONNAGE
// =====================
function ouvrirModalDetruirePersonnage() {
  document.getElementById('postes-modal-title').textContent = 'Détruire mon personnage';
  let html = '<div style="padding:1rem">';
  html += '<div style="color:#cc4444;font-size:.85rem;line-height:1.6;margin-bottom:1rem"><i class="ti ti-alert-triangle"></i> <strong>Action irréversible.</strong> Votre personnage (' + (state.char?.name||'') + ') sera définitivement supprimé : poste, ressources, candidatures et votes en cours seront effacés.<br><br>Vos messages sur les forums et vos mails resteront visibles, comme une trace historique.</div>';
  html += '<input type="text" id="confirm-destroy-input" placeholder="Tapez le nom de votre personnage pour confirmer" style="width:100%;background:#121005;border:1px solid #6a2a20;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:1rem;box-sizing:border-box">';
  html += '<button onclick="confirmerDestructionPersonnage()" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #6a2a20;background:transparent;color:#cc4444;cursor:pointer">Détruire définitivement</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerDestructionPersonnage() {
  const saisie = document.getElementById('confirm-destroy-input')?.value?.trim();
  const nom = state.char?.name;
  if (!nom || saisie !== nom) {
    showToast('Confirmation incorrecte', 'Le nom saisi ne correspond pas.', false);
    return;
  }

  document.getElementById('modal-postes').classList.remove('open');

  if (typeof sbDeletePersonnage === 'function') {
    await sbDeletePersonnage(nom).catch(() => {});
  }

  // Nettoyer le localStorage local
  localStorage.removeItem('respublica_char_' + nom);
  localStorage.removeItem('respublica_dormir_' + nom);
  localStorage.removeItem('respublica_photo_' + nom);
  localStorage.removeItem('respublica_evtvus_' + nom);
  localStorage.removeItem('respublica_char');
  localStorage.removeItem('respublica_last_char');

  showToast('Personnage détruit', 'Vous allez être redirigé vers la création d\'un nouveau personnage.', true, true);
  setTimeout(() => { window.location.href = 'index.html'; }, 2000);
}

function doDormir() {
  const today = state.day || 1;
  if (state.dernierDormir === today) {
    showToast('Deja dormi', 'Vous avez deja dormi aujourd\'hui. Attendez demain.', false);
    return;
  }

  // Prélever le coût selon l'hôtel
  const coutsDormir = {
    'hotel-republica': 80, 'hotel-port': 60, 'hotel-mineur': 40,
    'hotel-narco': 80, 'hotel-soviet': 60, 'hotel-khalija': 80
  };
  const coutDormir = coutsDormir[state.currentBuilding] || 0;
  const curD = COUNTRIES[state.country]?.cur || 'FR';
  if (coutDormir > 0 && state.arg < coutDormir) {
    showToast('Fonds insuffisants', coutDormir + ' ' + curD + ' requis pour la nuit.', false);
    return;
  }
  if (coutDormir > 0) state.arg -= coutDormir;

  const b = state.currentBuilding ? BUILDINGS[state.currentBuilding] : null;
  const confortMap = {
    'hotel-republica':    { moral: 5, paBonus: 5 },
    'hotel-port':         { moral: 3, paBonus: 2 },
    'hotel-mineur':       { moral: 3, paBonus: 2 },
    'palais-presidentiel':{ moral: 8, paBonus: 8 }
  };
  const confort = confortMap[state.currentBuilding] || { moral: 1, paBonus: 0 };

  state.salaireTouche = true;
  state.day = today + 1;
  state.dernierDormir = state.day; // Bloque le jour suivant
  state.douanePassee = false;
  localStorage.setItem('respublica_dormir_' + (state.char?.name || 'default'), JSON.stringify({dernierDormir: state.dernierDormir, day: state.day}));
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

  // Payer les loyers des locations actives
  payerLocations();
  // Payer les escorts actives
  payerEscorts();
  payerEmployes();

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
  const country = state.country || 'republic';

  // Répliques situationnelles par empire
  const repliques = {
    republic: [
      "Veuillez me suivre, s'il vous plaît. Formulaire 47-B à remplir au commissariat. En triple.",
      "Vous êtes en état d'arrestation. Votre droit au silence est garanti — personne ne vous écoutera de toute façon.",
      "J'ai un mandat. Enfin, j'ai quelque chose. C'est peut-être mon ticket de métro. Suivez-moi quand même."
    ],
    narco: [
      "Dura lex, cède ta Rolex. ¡Vámonos!",
      "El Don dit que la loi s'applique à tout le monde. Sauf à ceux qui paient. Vous payez ?",
      "Alto ! Police d'El Estado. Vos mains, votre portefeuille, dans l'ordre que vous préférez."
    ],
    soviet: [
      "Camarade, vous êtes en état d'arrestation révolutionnaire. Formulaire B-47 en quadruple exemplaire.",
      "Le Parti a été informé de vos activités déviantes. Veuillez nous suivre pour rééducation volontaire obligatoire.",
      "Halte au nom du Peuple ! Vos papiers, votre loyauté, votre betterave du jour."
    ],
    khalija: [
      "Que la grâce du Loukoum Divin soit sur vous, mais pas sur vos activités. Veuillez nous suivre.",
      "Le Sheikh, dans son infinie sagesse pâtissière, a ordonné votre arrestation. C'est un honneur.",
      "Par décret royal et au nom du Loukoum Sacré, vous êtes arrêté(e). Le protocole l'exige."
    ]
  };

  const replique = repliques[country][Math.floor(Math.random() * 3)];

  // Coût corruption selon empire
  const coutCorruption = { republic: 500, narco: 200, soviet: 800, khalija: 600 };
  const cout = coutCorruption[country] || 500;
  const cur = (window.COUNTRIES?.[country]?.cur) || 'FR';
  const tauxCorruption = { republic: 45, narco: 75, soviet: 20, khalija: 50 };
  const taux = tauxCorruption[country] || 45;

  document.getElementById('postes-modal-title').textContent = 'Interception policière !';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1rem">' +
    '<div style="font-size:.82rem;color:#8a8060;font-style:italic;font-family:Crimson Pro,Georgia,serif;border-left:2px solid #8a3a2a;padding-left:.6rem;margin-bottom:.8rem">"' + replique + '"</div>' +
    '<div style="font-size:.88rem;color:#cc4444;font-family:Playfair Display,serif;margin-bottom:.4rem">Chef d\'inculpation : ' + peine.label + '</div>' +
    '<div style="font-size:.78rem;color:#8a8060;margin-bottom:1rem">Peine encourue : ' + peine.jours + ' jour(s) d\'emprisonnement.</div>' +
    '<div style="display:flex;flex-direction:column;gap:.5rem">' +
    '<button onclick="procederArrestation(\'' + peineType + '\',false);document.getElementById(\'modal-postes\').classList.remove(\'open\')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1rem;border:1px solid #4a6a4a;background:transparent;color:#6a9a6a;cursor:pointer"><i class="ti ti-check" style="font-size:.8rem"></i> Se rendre</button>' +
    '<button onclick="tenterCorruptionArrestation(\'' + peineType + '\',' + cout + ',' + taux + ')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer"><i class="ti ti-coin" style="font-size:.8rem"></i> Corrompre l\'agent (' + cout + ' ' + cur + ' · ' + taux + '%)</button>' +
    '<button onclick="tenterFuite()" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1rem;border:1px solid #8a6a20;background:transparent;color:#8a8060;cursor:pointer"><i class="ti ti-run" style="font-size:.8rem"></i> Fuir (VOL+DIS)</button>' +
    '<button onclick="tenterResistance(\'' + peineType + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1rem;border:1px solid #8a2020;background:transparent;color:#cc4444;cursor:pointer"><i class="ti ti-sword" style="font-size:.8rem"></i> Résister (très risqué)</button>' +
    '</div></div>';
  document.getElementById('modal-postes').classList.add('open');
}

function tenterCorruptionArrestation(peineType, cout, taux) {
  const country = state.country || 'republic';
  const cur = (window.COUNTRIES?.[country]?.cur) || 'FR';

  if (state.arg < cout) {
    showToast('Fonds insuffisants', `Il vous faut ${cout} ${cur} pour corrompre l'gent.`, false);
    return;
  }

  state.arg -= cout;
  const dup = state.char?.stats?.DUP || 8;
  const bonus = Math.floor(dup / 10) * 5;
  const roll = Math.floor(Math.random() * 100) + 1;
  const tauxFinal = Math.min(85, taux + bonus);

  // Répliques succès/échec par empire
  const succesRepliques = {
    republic: "Très bien. Je n'ai rien vu. Je ne vois d'ailleurs jamais rien le mercredi.",
    narco:    "¡Excelente! El Don dit que la générosité est une vertu. Bonne journée, señor.",
    soviet:   "Le formulaire d'arrestation se sera... égaré. Ça arrive. Bonne journée, Camarade.",
    khalija:  "Que le Loukoum Divin bénisse votre générosité. Le Chambellan n'a rien remarqué."
  };
  const echecRepliques = {
    republic: "Comment osez-vous ? Ajoutez 'tentative de corruption' au dossier. Et doublez la mise.",
    narco:    "¡Dios mío! Vous croyez que je suis corruptible ? Doublez et on en reparle.",
    soviet:   "Trahison contre-révolutionnaire ! Formulaire de corruption en quadruple. Plus deux ans.",
    khalija:  "Ô impudent ! Ceci est une insulte au protocole royal. Et le montant était insuffisant."
  };

  document.getElementById('modal-postes').classList.remove('open');

  if (roll <= tauxFinal) {
    state.dis = Math.max(0, state.dis - 10);
    updateUI();
    const rep = succesRepliques[country] || succesRepliques.republic;
    showToast('Corruption réussie !', `"${rep}"`, true, true);
    addJournalEntry(`Corruption réussie. -${cout} ${cur} · -10 DIS. Vous êtes libre.`, 'event-good');
    // Effacer une infraction
    if (state.recherche?.length > 0) state.recherche.pop();
  } else {
    state.dis = Math.max(0, state.dis - 15);
    updateUI();
    const rep = echecRepliques[country] || echecRepliques.republic;
    showToast('Corruption ratée !', `"${rep}"`, false);
    addJournalEntry(`Tentative de corruption échouée. -${cout} ${cur} · -15 DIS. Arrestation aggravée.`, 'event-bad');
    procederArrestation(peineType, true);
  }
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
    if (state.char) state.char.poste = null;
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

// =====================
// FORUM NATIONAL SOUS-FORUM PRESIDENT
// =====================
function ouvrirForumNationalSousForumPresident(type) {
  // Ouvre le forum en vue centrale sur le sous-forum presidentiel
  document.querySelectorAll('.vue').forEach(v => v.classList.remove('active'));
  document.getElementById('vue-forum').classList.add('active');

  const titres = {
    conference: 'Conférence de Presse',
    annonce:    'Annonce Officielle',
    propagande: "Propagande d'État",
    dementi:    'Démenti Officiel',
    referendum: 'Référendum National',
    deuil:      'Décret de Deuil National'
  };
  const effets = {
    conference: { pop:15, inf:10, isn:0, ie:0, id:0, is:5 },
    annonce:    { pop:5,  inf:5,  isn:0, ie:0, id:0, is:2 },
    propagande: { pop:20, inf:0,  isn:0, ie:0, id:-5,is:8 },
    dementi:    { pop:8,  inf:5,  isn:0, ie:0, id:0, is:0 },
    referendum: { pop:10, inf:8,  isn:0, ie:0, id:3, is:5 },
    deuil:      { pop:15, inf:0,  isn:0, ie:-5,id:0, is:8 }
  };

  document.getElementById('forum-view-subtitle').textContent = 'Forum National — Forum Présidentiel';
  const body = document.getElementById('forum-view-body');
  const ef = effets[type] || {};
  const titre = titres[type] || 'Message Présidentiel';

  let efStr = [];
  if (ef.pop) efStr.push((ef.pop > 0 ? '+' : '') + ef.pop + ' POP');
  if (ef.inf) efStr.push((ef.inf > 0 ? '+' : '') + ef.inf + ' INF');
  if (ef.is)  efStr.push((ef.is  > 0 ? '+' : '') + ef.is  + ' IS');
  if (ef.id)  efStr.push((ef.id  > 0 ? '+' : '') + ef.id  + ' ID');
  if (type === 'deuil') efStr.push('Pas d\'impôts aujourd\'hui');

  let isRef = type === 'referendum';
  let html = '<div style="display:flex;flex-direction:column;width:100%;height:100%">';
  html += '<div style="padding:.6rem 1rem;background:#111208;border-bottom:1px solid #1a1810;display:flex;align-items:center;gap:.8rem">';
  html += '<button onclick="closeForumView()" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;padding:.2rem .5rem;border:1px solid #2a2010;background:transparent;color:#8a7040;cursor:pointer">← Annuler</button>';
  html += '<div style="font-family:Playfair Display,serif;font-size:.88rem;color:#E8D880">' + titre + '</div>';
  html += '<div style="margin-left:auto;font-size:.68rem;color:#4a8a4a">' + efStr.join(' · ') + '</div>';
  html += '</div>';
  html += '<div style="flex:1;overflow-y:auto;padding:1rem;max-width:700px">';

  if (isRef) {
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">QUESTION DU REFERENDUM</div>';
    html += '<input id="pres-ref-question" type="text" placeholder="Quelle est la question soumise au vote ?" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.6rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.6rem"/>';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">RÉPONSES (1 seul choix)</div>';
    html += '<input id="pres-ref-rep1" type="text" placeholder="Réponse 1 (ex: Oui)" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none;margin-bottom:.3rem"/>';
    html += '<input id="pres-ref-rep2" type="text" placeholder="Réponse 2 (ex: Non)" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none;margin-bottom:.3rem"/>';
    html += '<input id="pres-ref-rep3" type="text" placeholder="Réponse 3 (optionnel)" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none;margin-bottom:.5rem"/>';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.3rem">DURÉE DU VOTE</div>';
    html += '<select id="pres-ref-duree" style="background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none;margin-bottom:.8rem">';
    html += '<option value="3">3 jours</option><option value="5">5 jours</option><option value="7">7 jours</option></select>';
  } else {
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">TITRE</div>';
    html += '<input id="pres-msg-titre" type="text" placeholder="Titre de votre message officiel..." style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.6rem"/>';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">MESSAGE</div>';
    html += '<textarea id="pres-msg-contenu" rows="6" placeholder="Rédigez votre message officiel..." style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.6rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;resize:none;margin-bottom:.6rem"></textarea>';
  }

  html += '<button onclick="publierMessagePresidentiel(\'' + type + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.5rem 1.4rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Publier</button>';
  html += '</div></div>';
  body.innerHTML = html;
}

function publierMessagePresidentiel(type) {
  const effets = {
    conference: { pop:15, inf:10, is:5 },
    annonce:    { pop:5,  inf:5,  is:2 },
    propagande: { pop:20, inf:0,  is:8, id:-5 },
    dementi:    { pop:8,  inf:5  },
    referendum: { pop:10, inf:8,  is:5, id:3 },
    deuil:      { pop:15, is:8,   ie:-5 }
  };
  const ef = effets[type] || {};
  const pays = state.country || 'republic';

  let titre, contenu;
  if (type === 'referendum') {
    titre = document.getElementById('pres-ref-question')?.value?.trim();
    const rep1 = document.getElementById('pres-ref-rep1')?.value?.trim();
    const rep2 = document.getElementById('pres-ref-rep2')?.value?.trim();
    const rep3 = document.getElementById('pres-ref-rep3')?.value?.trim();
    const duree = parseInt(document.getElementById('pres-ref-duree')?.value || '5');
    if (!titre || !rep1 || !rep2) { showToast('Champs requis', 'Question et au moins 2 réponses.', false); return; }
    const reponses = [rep1, rep2, ...(rep3 ? [rep3] : [])].map(r => ({ label: r, voix: 0 }));
    if (!state.referendums) state.referendums = [];
    state.referendums.push({ question: titre, reponses, jourFin: state.day + duree, clos: false });
    contenu = 'Le Président soumet ce référendum au vote populaire. Vote ouvert pendant ' + duree + ' jour(s).';
    if (!FORUM_TOPICS['president']) FORUM_TOPICS['president'] = [];
    FORUM_TOPICS['president'].unshift({
      id: 'ref-' + Date.now(), title: '[REFERENDUM] ' + titre,
      author: state.char?.name || 'President', time: 'Jour ' + state.day,
      isReferendum: true, reponses,
      posts: [{ author: state.char?.name, time: 'Jour ' + state.day, content: contenu }]
    });
  } else {
    titre = document.getElementById('pres-msg-titre')?.value?.trim();
    contenu = document.getElementById('pres-msg-contenu')?.value?.trim();
    if (!titre || !contenu) { showToast('Champs requis', 'Titre et contenu obligatoires.', false); return; }
    if (!FORUM_TOPICS['president']) FORUM_TOPICS['president'] = [];
    FORUM_TOPICS['president'].unshift({
      id: 'pres-' + Date.now(), title: '[PRESIDENCE] ' + titre,
      author: state.char?.name || 'President', time: 'Jour ' + state.day,
      posts: [{ author: state.char?.name, time: 'Jour ' + state.day, content: contenu }]
    });
  }

  // Appliquer les effets
  if (ef.pop) state.pop = Math.min(100, state.pop + ef.pop);
  if (ef.inf) state.inf = Math.min(100, state.inf + ef.inf);
  if (ef.is && INDICES_NATIONAUX?.[pays]) INDICES_NATIONAUX[pays].IS = Math.min(100, INDICES_NATIONAUX[pays].IS + ef.is);
  if (ef.id && INDICES_NATIONAUX?.[pays]) INDICES_NATIONAUX[pays].ID = Math.max(0, INDICES_NATIONAUX[pays].ID + ef.id);
  if (ef.ie && INDICES_NATIONAUX?.[pays]) INDICES_NATIONAUX[pays].IE = Math.max(0, INDICES_NATIONAUX[pays].IE + ef.ie);
  if (type === 'deuil') state.deuil = state.day;

  updateUI();
  closeForumView();

  const efParts = [];
  if (ef.pop) efParts.push((ef.pop>0?'+':'')+ef.pop+' POP');
  if (ef.inf) efParts.push((ef.inf>0?'+':'')+ef.inf+' INF');
  showToast('Publié !', titre + (efParts.length ? ' · ' + efParts.join(' ') : ''), true, true);
  addJournalEntry('Publication présidentielle : ' + titre, 'event-good');
  addExternalEvent('PRESIDENCE : ' + titre + (type === 'deuil' ? ' — Journée de deuil national.' : ''));
}

// =====================
// DECLARER LA GUERRE
// =====================
function ouvrirModalGuerreEmpire() {
  const empires = Object.entries(COUNTRIES).filter(([k]) => k !== (state.country || 'republic'));
  const guerresActives = state.guerres || [];

  document.getElementById('postes-modal-title').textContent = 'Déclarer la guerre';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#cc4444;font-style:italic;margin-bottom:.8rem">-20 POP +10 INF · Nation : -20 ID +15 ISN. Irréversible sans cessez-le-feu.</div>';

  empires.forEach(([k, co]) => {
    const enGuerre = guerresActives.some(g => g.empire === k);
    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.7rem;margin-bottom:.5rem;display:flex;align-items:center;justify-content:space-between">';
    html += '<div style="display:flex;align-items:center;gap:.6rem">';
    html += '<i class="ti ' + (co.icon||'ti-flag') + '" style="font-size:1.1rem;color:' + (co.col||'#8a6a20') + '"></i>';
    html += '<div><div style="font-family:Playfair Display,serif;font-size:.85rem;color:#c0b090">' + co.n + '</div>';
    html += '<div style="font-size:.68rem;color:' + (enGuerre ? '#cc4444' : '#5a4030') + '">' + (enGuerre ? 'En guerre' : 'En paix') + '</div></div></div>';
    if (!enGuerre) {
      html += '<button onclick="confirmerGuerreEmpire(\'' + k + '\',\'' + co.n + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;padding:.3rem .7rem;border:1px solid #8a2020;background:transparent;color:#cc4444;cursor:pointer"><i class="ti ti-sword" style="font-size:.75rem"></i> Déclarer</button>';
    } else {
      html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.65rem;color:#6a2020">CONFLIT EN COURS</div>';
    }
    html += '</div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerGuerreEmpire(empireId, empireName) {
  document.getElementById('modal-postes').classList.remove('open');
  const pays = state.country || 'republic';
  if (!state.guerres) state.guerres = [];
  state.guerres.push({ empire: empireId, nom: empireName, depuis: 'Jour ' + state.day });
  state.pop = Math.max(0, state.pop - 20);
  state.inf = Math.min(100, state.inf + 10);
  if (INDICES_NATIONAUX?.[pays]) {
    INDICES_NATIONAUX[pays].ID = Math.max(0, INDICES_NATIONAUX[pays].ID - 20);
    INDICES_NATIONAUX[pays].ISN = Math.min(100, INDICES_NATIONAUX[pays].ISN + 15);
  }
  updateUI();
  showToast('Guerre déclarée !', 'Conflit ouvert avec ' + empireName + '. -20 POP +10 INF -20 ID +15 ISN.', false);
  addExternalEvent('GUERRE DÉCLARÉE : ' + (COUNTRIES[pays]?.n||'') + ' entre en guerre contre ' + empireName + ' !');
  addMailNotification('État-Major', 'Declaration de guerre', 'La guerre a ete declaree contre ' + empireName + '. L\'armee est en alerte maximale. +15 ISN.');
}

// =====================
// DEPOSER UN PROJET DE LOI
// =====================
function ouvrirDeposerProjet() {
  // Verifier que le PJ est depute
  const posteId = state.poste?.id;
  const estDepute = posteId && (posteId.startsWith('depute') || posteId === 'depute_1' || posteId === 'depute_2');

  if (!estDepute) {
    showToast('Accès refusé', 'Vous n\'êtes pas député(e). Seuls les députés peuvent déposer un projet de loi.', false);
    return;
  }

  // Ouvrir le forum parlementaire en vue centrale
  document.querySelectorAll('.vue').forEach(v => v.classList.remove('active'));
  document.getElementById('vue-forum').classList.add('active');
  document.getElementById('forum-view-subtitle').textContent = 'Forum Parlementaire — Déposer un projet';

  const body = document.getElementById('forum-view-body');
  let html = '<div style="display:flex;flex-direction:column;width:100%;height:100%">';
  html += '<div style="padding:.6rem 1rem;background:#111208;border-bottom:1px solid #1a1810;display:flex;align-items:center;gap:.8rem">';
  html += '<button onclick="closeForumView()" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;padding:.2rem .5rem;border:1px solid #2a2010;background:transparent;color:#8a7040;cursor:pointer">← Annuler</button>';
  html += '<div style="font-family:Playfair Display,serif;font-size:.88rem;color:#E8D880">Déposer un projet de loi</div>';
  html += '</div>';
  html += '<div style="flex:1;overflow-y:auto;padding:1rem;max-width:700px">';
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.8rem;padding:.5rem;background:#0a0a05;border:1px solid #1a1810">Le projet sera soumis au vote le mercredi suivant, à condition d\'avoir été déposé au moins 5 jours avant.</div>';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">TITRE DU PROJET</div>';
  html += '<input id="projet-titre" type="text" placeholder="Ex: Loi sur la transparence des finances publiques" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.6rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.6rem"/>';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">EXPOSÉ DES MOTIFS</div>';
  html += '<textarea id="projet-contenu" rows="6" placeholder="Décrivez votre projet, ses objectifs et ses impacts attendus..." style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.6rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;resize:none;margin-bottom:.6rem"></textarea>';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">IMPACT SOUHAITÉ</div>';
  html += '<input id="projet-impact" type="text" placeholder="Ex: +10 IE, -5 IS, augmentation budget commissariat..." style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none;margin-bottom:.8rem"/>';
  html += '<button onclick="soumettreProjetLoi()" style="font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.5rem 1.4rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Soumettre le projet</button>';
  html += '</div></div>';
  body.innerHTML = html;
}

function soumettreProjetLoi() {
  const titre = document.getElementById('projet-titre')?.value?.trim();
  const contenu = document.getElementById('projet-contenu')?.value?.trim();
  const impact = document.getElementById('projet-impact')?.value?.trim();
  if (!titre || !contenu) { showToast('Champs requis', 'Titre et exposé obligatoires.', false); return; }

  const jourDepot = state.day;
  const jourVoteMin = jourDepot + 5;

  if (!FORUM_TOPICS['parlement']) FORUM_TOPICS['parlement'] = [];
  const topic = {
    id: 'loi-' + Date.now(),
    title: '[PROJET] ' + titre,
    author: state.char?.name || 'Député',
    time: 'Jour ' + jourDepot,
    posts: [{
      author: state.char?.name,
      time: 'Jour ' + jourDepot,
      content: contenu + (impact ? '\n\nImpact attendu : ' + impact : '')
    }]
  };
  FORUM_TOPICS['parlement'].unshift(topic);

  if (!state.loisEnCours) state.loisEnCours = [];
  state.loisEnCours.push({
    id: topic.id, titre, auteur: state.char?.name,
    jourDepot, jourVoteMin, pret: false, votes: []
  });

  closeForumView();
  showToast('Projet soumis !', titre + ' · Vote possible à partir du Jour ' + jourVoteMin, true, true);
  addJournalEntry('Projet de loi soumis : ' + titre, 'event-good');
  addExternalEvent('FORUM PARLEMENTAIRE : Nouveau projet de loi déposé par ' + (state.char?.name||'Anonyme') + ' : "' + titre + '"');
  // Mail a tous les deputes (simulation)
  addMailNotification('Secrétariat de l\'Assemblée', 'Nouveau projet de loi', 'Un projet de loi a été déposé : "' + titre + '". Consultez le Forum Parlementaire pour le détail. Vote à partir du Jour ' + jourVoteMin + '.');
}

// =====================
// ECOUTER LES RUMEURS (IA)
// =====================
async function ecouterRumeurs() {
  const ville = WORLD[state.country]?.[state.currentCity]?.name || 'la ville';
  const char = state.char;
  const pnjPresents = ['Le Commissaire', 'Un député', 'Un journaliste', 'Un commerçant', 'Un inconnu'];
  const source = pnjPresents[Math.floor(Math.random() * pnjPresents.length)];

  showToast('Vous tendez l\'oreille...', 'En attente d\'une information.', false);

  const context = 'Empire : ' + (COUNTRIES[state.country]?.n || 'Républia') +
    '. Ville : ' + ville +
    '. Votre personnage : ' + (char?.name || 'Anonyme') +
    (state.poste ? ', ' + state.poste.name : '') +
    '. Jour ' + state.day + '.' +
    (state.guerres?.length ? ' Guerre en cours contre : ' + state.guerres.map(g=>g.nom).join(', ') + '.' : '') +
    (state.electionsEnCours?.length ? ' Elections en cours.' : '');

  try {
    const resp = await fetch('/api/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: 'claude-sonnet-4-5',
        max_tokens: 200,
        messages: [{
          role: 'user',
          content: 'Tu es le narrateur d\'un jeu de rôle politique parodique et satirique. Contexte : ' + context + '. Génère UNE rumeur courte (2-3 phrases max) que "' + source + '" chuchote à l\'oreille du joueur. La rumeur doit être crédible, légèrement compromettante pour un personnage politique ou une institution, et adaptée au contexte. Ton satirique et cynique. Réponds UNIQUEMENT avec la rumeur, sans introduction.'
        }]
      })
    });
    const data = await resp.json();
    const rumeur = data.content?.[0]?.text || 'Rien d\'intéressant à rapporter aujourd\'hui.';

    document.getElementById('postes-modal-title').textContent = source + ' vous glisse à l\'oreille...';
    document.getElementById('postes-body').innerHTML =
      '<div style="padding:1.2rem">' +
      '<div style="font-size:.85rem;color:#c0b090;font-style:italic;line-height:1.7;font-family:Crimson Pro,serif">"' + rumeur + '"</div>' +
      '<div style="font-size:.68rem;color:#4a4030;margin-top:.8rem">Source : ' + source + ' · Fiabilité incertaine</div>' +
      '</div>';
    document.getElementById('modal-postes').classList.add('open');

    state.inf = Math.min(100, state.inf + 1);
    updateUI();
    addJournalEntry('Rumeur entendue à ' + ville, 'event-info');

  } catch(e) {
    showToast('Silence', 'Personne ne parle aujourd\'hui.', false);
  }
}

async function solliciterAudiencePresident() {
  const char = state.char;
  const nomDemandeur = char?.name || 'Anonyme';
  // Message automatique au demandeur
  showToast(
    'Demande transmise',
    'Je transmets votre demande à Monsieur le Président. Il vous contactera dès qu\'il en aura pris connaissance.',
    true
  );
  addJournalEntry('Vous avez sollicite une audience presidentielle.', 'event-info');
  // Mail au President (vrai titulaire recherche via Supabase)
  const titulaire = await getTitulairePoste('president');
  await envoyerNotificationVraiJoueur(titulaire, 'Demande d\'audience de ' + nomDemandeur,
    nomDemandeur + ' sollicite une audience presidentielle. Vous pouvez lui repondre directement par mail.');
}

// =====================
// INDICES IMPERIAUX - CORRIGE
// =====================
function ouvrirIndicesImperiaux() {
  // Ouvrir dans un modal simple pour eviter les problemes de vue
  const empires = [
    { key:'republic', name:'Républia',   col:'#4a9ade' },
    { key:'narco',    name:'El Estado',  col:'#cc4444' },
    { key:'soviet',   name:'Sovarka',    col:'#cc2020' },
    { key:'khalija',  name:'Al-Khalija', col:'#C9A84C' }
  ];

  document.getElementById('postes-modal-title').textContent = 'Indices Imperiaux';
  let html = '<div style="padding:1rem">';

  empires.forEach(emp => {
    const idx = (typeof INDICES_NATIONAUX !== 'undefined') ? (INDICES_NATIONAUX[emp.key] || {ISN:30,IE:50,ID:40,IS:45}) : {ISN:30,IE:50,ID:40,IS:45};
    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.7rem;margin-bottom:.5rem">';
    html += '<div style="font-family:Playfair Display,serif;font-size:.88rem;color:' + emp.col + ';margin-bottom:.5rem">' + emp.name + '</div>';
    html += '<div style="display:grid;grid-template-columns:repeat(4,1fr);gap:.3rem">';
    [['ISN','Securite','#4a8a4a'],['IE','Eco','#C9A84C'],['ID','Diplo','#4a6aaa'],['IS','Social','#aa6a4a'],['IP','Piété','#8a4a8a']].forEach(([k,label,col]) => {
      const val = idx[k] || 0;
      html += '<div style="text-align:center;padding:.3rem;background:#0a0805;border:1px solid #1a1810">';
      html += '<div style="font-size:.58rem;color:#4a4030">' + label + '</div>';
      html += '<div style="font-family:Bebas Neue,sans-serif;font-size:1.2rem;color:' + col + '">' + val + '</div>';
      html += '<div style="height:3px;background:#0a0a05;margin-top:.15rem"><div style="height:100%;width:' + val + '%;background:' + col + ';opacity:.6"></div></div>';
      html += '</div>';
    });
    html += '</div></div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// =====================
// PRODUIRE UNE FUITE
// =====================
async function ouvrirProduireFuite() {
  const contacts = state.contacts || [];
  if (contacts.length === 0) {
    showToast('Repertoire vide', 'Ajoutez des contacts pour cibler une fuite.', false);
    return;
  }
  document.getElementById('postes-modal-title').textContent = 'Produire une fuite';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#cc4444;font-style:italic;margin-bottom:.8rem">Acte illegal. Taux 55%. Si succes : rumeur dans le journal + mail a la cible (-10 INF -10 POP).</div>';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">CIBLE</div>';
  html += '<select id="fuite-cible" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.8rem">';
  contacts.forEach(c => { html += '<option value="' + c.name + '">' + c.name + '</option>'; });
  html += '</select>';
  html += '<button onclick="confirmerFuite()" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Lancer la fuite</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerFuite() {
  const cible = document.getElementById('fuite-cible')?.value;
  if (!cible) return;
  document.getElementById('modal-postes').classList.remove('open');

  const roll = Math.floor(Math.random() * 100) + 1;
  const taux = Math.max(5, 55 - getMalusISN());

  if (roll <= taux) {
    // Generer la rumeur via IA
    try {
      const resp = await fetch('/api/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: 'claude-sonnet-4-5',
          max_tokens: 150,
          messages: [{
            role: 'user',
            content: 'Tu es le narrateur d\'un jeu politique parodique. Génère une courte rumeur compromettante (2 phrases max) concernant ' + cible + ', un personnage politique fictif. Ton satirique. Commence directement par la rumeur sans introduction.'
          }]
        })
      });
      const data = await resp.json();
      const rumeur = data.content?.[0]?.text || 'Des informations compromettantes circulent sur ' + cible + '.';

      addExternalEvent('FUITE : ' + rumeur);
      addMailNotification('Source anonyme', 'Information vous concernant', 'Des informations vous concernant ont ete divulguees : "' + rumeur + '". Votre reputation en patit. -10 INF -10 POP.');
      showToast('Fuite reussie !', 'Rumeur publiee dans le journal des evenements.', true, true);
      addJournalEntry('Fuite produite contre ' + cible + '.', 'event-bad');
      checkDetection('produire_fuite', 'success');

    } catch(e) {
      addExternalEvent('FUITE : Des informations compromettantes sur ' + cible + ' circulent dans les couloirs du pouvoir.');
      showToast('Fuite reussie !', 'Rumeur publiee.', true);
    }
  } else {
    showToast('Echec', 'La fuite n\'a pas pu etre organisee.', false);
    checkDetection('produire_fuite', 'fail');
  }
}

// =====================
// FABRIQUER UN SCANDALE
// =====================
function ouvrirFabrquerScandale() {
  const contacts = state.contacts || [];
  if (contacts.length === 0) {
    showToast('Repertoire vide', 'Ajoutez des contacts pour cibler un scandale.', false);
    return;
  }
  const isJournaliste = state.char?.career === 'press';
  const isMinInfo = state.poste?.id === 'min_info';
  const bonusCarriere = isJournaliste ? 15 : isMinInfo ? 10 : 0;
  const taux = 35 + bonusCarriere;

  document.getElementById('postes-modal-title').textContent = 'Fabriquer un scandale';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#cc4444;font-style:italic;margin-bottom:.8rem">Acte illegal. Taux ' + taux + '%' + (bonusCarriere > 0 ? ' (bonus ' + (isJournaliste ? 'journaliste' : 'MInfo') + ' +' + bonusCarriere + '%)' : '') + '. Si decouvert : Recherche pour diffamation.</div>';

  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">CIBLE</div>';
  html += '<select id="scandale-cible" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.6rem">';
  contacts.forEach(c => { html += '<option value="' + c.name + '">' + c.name + '</option>'; });
  html += '</select>';

  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">CONTENU DU SCANDALE</div>';
  html += '<textarea id="scandale-contenu" rows="4" placeholder="Decrivez le scandale fabrique..." style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;resize:none;margin-bottom:.8rem"></textarea>';
  html += '<button onclick="confirmerScandale(' + taux + ')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Publier le scandale</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerScandale(taux) {
  const cible = document.getElementById('scandale-cible')?.value;
  const contenu = document.getElementById('scandale-contenu')?.value?.trim();
  if (!cible || !contenu) { showToast('Champs requis', '', false); return; }
  document.getElementById('modal-postes').classList.remove('open');

  const roll = Math.floor(Math.random() * 100) + 1;
  const tauxFinal = Math.max(5, taux - getMalusISN());

  if (roll <= tauxFinal) {
    // Publier dans le forum national
    if (!FORUM_TOPICS['national']) FORUM_TOPICS['national'] = [];
    FORUM_TOPICS['national'].unshift({
      id: 'scandale-' + Date.now(),
      title: '[SCANDALE] Revelations sur ' + cible,
      author: 'Source anonyme',
      time: 'Jour ' + state.day,
      posts: [{ author: 'Source anonyme', time: 'Jour ' + state.day, content: contenu }]
    });

    // Mail a la cible
    addMailNotification('Redaction anonyme', 'Scandale vous concernant', 'Un article compromettant vous concernant vient d\'etre publie dans le forum national. -15 INF -15 POP -10 Moral.');
    addExternalEvent('SCANDALE : Revelations compromettantes sur ' + cible + ' publiees dans le forum national !');
    showToast('Scandale publie !', 'Article dans le forum national. -15 INF -15 POP -10 Moral sur ' + cible, true, true);
    addJournalEntry('Scandale fabrique contre ' + cible, 'event-bad');

    // Risque de decouverte (30%)
    const rollDecouv = Math.floor(Math.random() * 100) + 1;
    if (rollDecouv <= 30) {
      setTimeout(() => {
        state.recherche = [{ acte: 'diffamation', type: 'delit_grave', jour: state.day }];
        addExternalEvent('RETOUR DE BATON : Vous avez ete identifie(e) comme l\'auteur du scandale ! Recherche pour diffamation.');
        showToast('Decouvert !', 'Vous etes recherche(e) pour diffamation. -20 POP -15 INF.', false);
        state.pop = Math.max(0, state.pop - 20);
        state.inf = Math.max(0, state.inf - 15);
        updateUI();
      }, 1500);
    }
    checkDetection('fabriquer_scandale', 'success');
  } else {
    showToast('Echec', 'Le scandale n\'a pas pris. Personne ne l\'a cru.', false);
    checkDetection('fabriquer_scandale', 'fail');
  }
}

// =====================
// ASSEMBLEE NATIONALE
// =====================
function observerDebats() {
  const deputes = ['Depute Marchand (PNJ)', 'Depute Fontaine (PNJ)', 'Depute Rousseau (PNJ)', 'Depute Girard (PNJ)'];
  const positions = ['Pour', 'Contre', 'Abstention'];
  const loisEnCours = state.loisEnCours || [];

  document.getElementById('postes-modal-title').textContent = 'Observer les debats';
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

  document.getElementById('postes-modal-title').textContent = 'Voter une loi';
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
  document.getElementById('postes-modal-title').textContent = 'Archives de l\'Assemblee';
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
  document.getElementById('postes-modal-title').textContent = loi.titre;
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;margin-bottom:.6rem">Depose par ' + loi.auteur + ' · Vote Jour ' + loi.jourVote + '</div>';
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
  document.getElementById('postes-modal-title').textContent = 'Archives du Tribunal';
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
  document.getElementById('postes-modal-title').textContent = 'Jugement — ' + j.accuse;
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#6a5a30;margin-bottom:.5rem">Date : Jour ' + j.jour + ' · Juge : ' + (j.juge||'PNJ') + '</div>';
  html += '<div style="font-size:.82rem;color:#c0b090;margin-bottom:.3rem">Motif : ' + j.motif + '</div>';
  html += '<div style="font-size:.82rem;color:#c0b090;margin-bottom:.3rem">Peine : ' + (j.peine||'N/A') + '</div>';
  if (j.executee !== undefined) html += '<div style="font-size:.78rem;color:' + (j.executee ? '#4a8a4a' : '#8a6a20') + '">' + (j.executee ? 'Peine executee' : 'Peine en cours ou amenagee') + '</div>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

// Le tribunal ne sert plus a deposer une plainte (role du commissariat),
// mais a CONSULTER les affaires transmises par la police et en attente de jugement.
async function ouvrirPorterPlainte() {
  const ville = WORLD[state.country]?.[state.currentCity]?.name || 'la ville';
  document.getElementById('postes-modal-title').textContent = 'Affaires du Tribunal de ' + ville;
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a8060;font-style:italic">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  // Charger depuis Supabase pour voir les affaires de TOUS les joueurs de la ville, pas juste les siennes
  if (typeof sbLoadPlaintes === 'function') {
    try {
      const toutes = await sbLoadPlaintes(state.country);
      state.plaintesEnCours = toutes;
    } catch(e) {}
  }
  const affairesEnAttente = (state.plaintesEnCours || []).filter(p => p.status === 'deposee' && p.city === state.currentCity);

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">' +
    'Pour porter plainte, rendez-vous au commissariat. Le tribunal ne traite que les affaires transmises par les forces de l\'ordre suite a une enquete concluante.</div>';

  if (affairesEnAttente.length === 0) {
    html += '<div style="font-size:.85rem;color:#5a5040">Aucune affaire en attente de jugement pour le moment.</div>';
  } else {
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">EN ATTENTE DE JUGEMENT</div>';
    affairesEnAttente.forEach(a => {
      html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem">';
      html += '<div style="font-family:Playfair Display,serif;font-size:.82rem;color:#c0b090">' + a.cible + '</div>';
      html += '<div style="font-size:.7rem;color:#6a5a30;margin-top:.2rem">' + (a.motif||'') + '</div>';
      html += '<div style="font-size:.65rem;color:#4a4030;margin-top:.3rem">Transmise le Jour ' + a.jour + '</div>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}



// =====================
// FONCTIONS COMPLEMENTAIRES V17
// =====================

function doCorruption(fn, cost) {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  if (state.arg < cost) { showToast('Fonds insuffisants', 'Il vous faut ' + cost + ' ' + cur, false); return; }
  const roll = Math.floor(Math.random() * 100) + 1;
  const taux = Math.max(5, 65 - getMalusISN());
  if (roll <= taux) {
    state.arg -= cost;
    state.dis = Math.max(0, state.dis - 5);
    updateUI();
    showToast('Corruption reussie', 'Le service a ete obtenu. -5 DIS.', true);
    addJournalEntry('Corruption : ' + fn.replace(/_/g,' '), 'event-bad');
    checkDetection(fn, 'success');
  } else {
    showToast('Echec', 'La tentative de corruption a echoue.', false);
    checkDetection(fn, 'fail');
  }
}

function doSeReposer(fn) {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  if (fn === 'se_nourrir') {
    const cost = 10;
    if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
    state.arg -= cost;
    state.moral = Math.min(100, state.moral + 3);
    updateUI();
    showToast('Verre pris', '+3 Moral. -' + cost + ' ' + cur + '.', true);
  } else {
    state.moral = Math.min(100, state.moral + 2);
    updateUI();
    showToast('Repos', '+2 Moral.', true);
  }
}

function doRequeteAvocat() {
  addMailNotification('Cabinet juridique', 'Prise en charge', 'Votre demande a ete enregistree. Un avocat vous assistera lors de votre comparution. Reduction de peine possible.');
  showToast('Avocat contacte', 'Un avocat prend votre dossier en charge. Reduction de peine possible.', true);
  addJournalEntry('Requete avocat deposee.', 'event-info');
}

function doGreveFaim() {
  state.hp = Math.max(1, state.hp - 5);
  state.pop = Math.min(100, state.pop + 3);
  updateUI();
  showToast('Greve de la faim', '-5 HP +3 POP. Pression politique sur l\'administration.', false);
  addExternalEvent((state.char?.name||'Un detenu') + ' entame une greve de la faim. Pression politique.');
}

function doTentativeEvasion() {
  const roll = Math.floor(Math.random() * 100) + 1;
  if (roll <= 5) {
    state.estEmprisonne = null;
    state.recherche = [];
    showToast('Evasion reussie !', 'Vous etes libre ! Restez discret.', true, true);
    addJournalEntry('Evasion reussie !', 'event-good');
  } else {
    if (state.estEmprisonne) state.estEmprisonne.jours += 7;
    showToast('Evasion echouee', 'Tentative echouee. +7 jours de detention.', false);
    addJournalEntry('Tentative d\'evasion echouee. Peine aggravee.', 'event-bad');
  }
}

function doVisiterPrisonnier() {
  ouvrirModalCibleRepertoire('visiter_prisonnier', 'Rendre visite a un detenu');
}

async function doSeRenseigner() {
  const co = COUNTRIES[state.country];
  const pjConnus = (state.pjConnus || []).join(', ') || 'des personnages politiques locaux';
  const ville = state.currentCity || 'la capitale';
  const prompt = 'Res Publica, jeu parodique politique. Empire : ' + (co?.n||'inconnu') + '. Ville : ' + ville + '. Le barman murmure une rumeur croustillante sur la vie politique locale, impliquant si possible un de ces personnages : ' + pjConnus + '. 1 phrase max, ton parodique et cynique.';
  try {
    const resp = await fetch('/api/chat', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({ model: 'claude-haiku-4-5-20251001', max_tokens: 60, messages: [{ role: 'user', content: prompt }] })
    });
    const data = await resp.json();
    const info = data.content?.[0]?.text?.trim() || 'Le barman hausse les épaules. Rien de neuf ce soir.';
    state.inf = Math.min(100, (state.inf||0) + 3);
    updateUI();
    showToast('Le barman murmure...', info, true, true);
    addJournalEntry('Barman : "' + info.substring(0,80) + '"', 'event-info');
    addExternalEvent('🍺 Une rumeur court dans les bars de ' + ville + ' : ' + info);
  } catch(e) {
    const infos = [
      'Un élu local aurait été vu sortir du casino à 4h du matin.',
      'Des rumeurs courent sur un remaniement imminent.',
      'Quelqu\'un cherche à acheter des votes dans le quartier.',
      'Une affaire financière menace d\'éclabousser le gouvernement.'
    ];
    const info = infos[Math.floor(Math.random() * infos.length)];
    state.inf = Math.min(100, (state.inf||0) + 2);
    updateUI();
    showToast('Le barman murmure...', info, true, true);
    addJournalEntry('Barman : "' + info + '"', 'event-info');
  }
}

function doReserver() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cost = 80;
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  state.arg -= cost;
  state.chambreReservee = state.currentBuilding;
  updateUI();
  showToast('Chambre reservee', 'Chambre reservee. -' + cost + ' ' + cur + '. Passez l\'ordre Dormir depuis votre fiche.', true);
  addJournalEntry('Chambre reservee. -' + cost + ' ' + cur + '.', 'event-info');
}

function doInterview() {
  const roll = Math.floor(Math.random() * 100) + 1;
  const impact = roll <= 50 ? 1 : -1;
  state.pop = Math.max(0, Math.min(100, state.pop + impact * 5));
  updateUI();
  showToast('Interview', (impact > 0 ? 'Bonne impression. +5 POP.' : 'Mauvaise impression. -5 POP.'), impact > 0);
  addExternalEvent((state.char?.name||'Un personnage') + ' s\'est exprime dans la presse. Impact : ' + (impact > 0 ? '+5 POP' : '-5 POP'));
}

function doArticle() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cost = 300;
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  state.arg -= cost;
  updateUI();
  ouvrirModalCibleRepertoire('article_favorable', 'Rediger un article favorable sur');
}

function doEtouffer() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cost = 800;
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  state.arg -= cost;
  showToast('Ordre contact requis', 'Cliquez sur le journaliste cible pour etouffer un article.', false);
}

function doLogeInfo() {
  const infos = [
    'Les freres vous revelent qu\'un elu cache des fonds offshore.',
    'La Loge sait qui a commande l\'assassinat de la semaine derniere.',
    'Un ministre est en negociation secrete avec un empire etranger.',
    'Des elections anticipees se preparent dans l\'ombre.'
  ];
  const info = infos[Math.floor(Math.random() * infos.length)];
  state.inf = Math.min(100, state.inf + 5);
  updateUI();
  showToast('Information de la Loge', info, true, true);
  addJournalEntry('Information confidentielle obtenue de la Loge.', 'event-info');
}

function doSeFormer() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cost = 100;
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  state.arg -= cost;
  const stats = ['INT','CHA','VOL','PER','DUP','ENT'];
  document.getElementById('postes-modal-title').textContent = 'Suivre une formation';
  let html = '<div style="padding:1rem"><div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Choisir la caracteristique a ameliorer (+1 point) :</div>';
  stats.forEach(s => {
    html += '<button onclick="appliquerFormation(\'' + s + '\')" style="display:block;width:100%;text-align:left;padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;color:#c0b090;cursor:pointer;font-family:Crimson Pro,serif;font-size:.85rem;margin-bottom:.3rem">' + s + ' (actuel : ' + (state.char?.stats?.[s]||8) + ')</button>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function appliquerFormation(stat) {
  document.getElementById('modal-postes').classList.remove('open');
  if (!state.char) return;
  if (!state.char.stats) state.char.stats = {};
  state.char.stats[stat] = (state.char.stats[stat]||8) + 1;
  showToast('Formation terminee', stat + ' : ' + state.char.stats[stat] + ' (+1)', true, true);
  addJournalEntry('Formation suivie : +1 ' + stat, 'event-good');
}

function doRecruterInfo() {
  const contacts = state.contacts || [];
  if (contacts.length === 0) { showToast('Repertoire vide', 'Ajoutez des contacts pour recruter.', false); return; }
  if (!state.informateurs) state.informateurs = [];
  document.getElementById('postes-modal-title').textContent = 'Recruter un informateur';
  let html = '<div style="padding:1rem"><div style="font-size:.8rem;color:#8a8060;margin-bottom:.8rem">L\'informateur enverra des mails reguliers avec des informations utiles.</div>';
  contacts.forEach(c => {
    html += '<button onclick="confirmerRecrutement(\'' + c.name + '\')" style="display:block;width:100%;text-align:left;padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;color:#c0b090;cursor:pointer;margin-bottom:.3rem;font-family:Crimson Pro,serif;font-size:.85rem">' + c.name + '</button>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerRecrutement(nom) {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cost = 150;
  document.getElementById('modal-postes').classList.remove('open');
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis pour recruter.', false); return; }
  // Vérifier pas déjà informateur
  if (!state.informateurs) state.informateurs = [];
  if (state.informateurs.some(i => i.nom === nom)) { showToast('Déjà informateur', nom + ' est déjà dans votre réseau.', false); return; }
  // Vérifier limite (max 2)
  if (state.informateurs.length >= 2) { showToast('Limite atteinte', 'Vous ne pouvez pas avoir plus de 2 informateurs simultanément.', false); return; }
  state.arg -= cost;
  state.informateurs.push({
    nom, niveau: 1,
    label: nom,
    cout: cost,
    coutJour: cost,
    depuis: state.day,
    joursActif: 0
  });
  updateUI();
  showToast('Informateur recrute', nom + ' rejoint votre reseau. -' + cost + ' ' + cur + '/jour.', true);
  addJournalEntry('Informateur recrute : ' + nom + ' (N1). -' + cost + ' ' + cur + '/jour.', 'event-info');
}

function doMobiliserPolice() {
  const pays = state.country || 'republic';
  if (INDICES_NATIONAUX?.[pays]) INDICES_NATIONAUX[pays].ISN = Math.min(100, INDICES_NATIONAUX[pays].ISN + 15);
  state.pop = Math.max(0, state.pop - 5);
  updateUI();
  showToast('Forces de l\'ordre mobilisees', '+15 ISN -5 POP.', false);
  addExternalEvent('Mobilisation des forces de l\'ordre. +15 ISN.');
}

function doMobiliserArmee() {
  const pays = state.country || 'republic';
  if (INDICES_NATIONAUX?.[pays]) INDICES_NATIONAUX[pays].ISN = Math.min(100, INDICES_NATIONAUX[pays].ISN + 20);
  updateUI();
  showToast('Armee mobilisee', '+20 ISN. Alerte maximale.', false);
  addExternalEvent('L\'armee est en etat d\'alerte maximale. +20 ISN.');
}

function doEtatUrgence() {
  const pays = state.country || 'republic';
  if (INDICES_NATIONAUX?.[pays]) {
    INDICES_NATIONAUX[pays].ISN = Math.min(100, INDICES_NATIONAUX[pays].ISN + 25);
    INDICES_NATIONAUX[pays].IS  = Math.max(0,   INDICES_NATIONAUX[pays].IS  - 10);
  }
  state.pop = Math.max(0, state.pop - 15);
  state.inf = Math.min(100, state.inf + 5);
  updateUI();
  showToast('Etat d\'urgence declare !', '+25 ISN -10 IS -15 POP +5 INF.', false);
  addExternalEvent('ETAT D\'URGENCE declare. Libertes civiles suspendues.');
}

function doInspecterTroupes() {
  state.inf = Math.min(100, state.inf + 3);
  const pays = state.country || 'republic';
  if (INDICES_NATIONAUX?.[pays]) INDICES_NATIONAUX[pays].ISN = Math.min(100, INDICES_NATIONAUX[pays].ISN + 2);
  updateUI();
  showToast('Inspection terminee', '+3 INF +2 ISN. Les troupes sont impressionnees.', true);
}

function doAugmenterImpots(augmenter) {
  const pays = state.country || 'republic';
  const delta = augmenter ? 5 : -5;
  state.pop = Math.max(0, Math.min(100, state.pop - (augmenter ? 8 : -5)));
  if (INDICES_NATIONAUX?.[pays]) INDICES_NATIONAUX[pays].IE = Math.max(0, Math.min(100, INDICES_NATIONAUX[pays].IE + (augmenter ? 5 : -5)));
  if (!state.tauxImposition) state.tauxImposition = 20;
  state.tauxImposition = Math.max(5, Math.min(50, state.tauxImposition + delta));
  updateUI();
  showToast(augmenter ? 'Impots augmentes' : 'Impots baisses', 'Taux : ' + state.tauxImposition + '% ' + (augmenter ? '-8 POP +5 IE' : '+5 POP -5 IE'), augmenter ? false : true);
  addExternalEvent('FINANCES : Taux d\'imposition fixe a ' + state.tauxImposition + '% par le Ministre des Finances.');
}

function doAutoriserManif() {
  const pays = state.country || 'republic';
  if (INDICES_NATIONAUX?.[pays]) INDICES_NATIONAUX[pays].ISN = Math.max(0, INDICES_NATIONAUX[pays].ISN - 5);
  state.pop = Math.min(100, state.pop + 5);
  updateUI();
  showToast('Manifestation autorisee', '+5 POP -5 ISN.', true);
}

function doDissoudreAssemblee() {
  state.pop = Math.max(0, state.pop - 10);
  state.inf = Math.max(0, state.inf - 5);
  const pays = state.country || 'republic';
  if (INDICES_NATIONAUX?.[pays]) {
    INDICES_NATIONAUX[pays].IS = Math.max(0, INDICES_NATIONAUX[pays].IS - 5);
    INDICES_NATIONAUX[pays].IE = Math.max(0, INDICES_NATIONAUX[pays].IE - 5);
  }
  updateUI();
  showToast('Assemblee dissoute !', 'Nouvelles elections declenchees. -10 POP -5 INF.', false);
  addExternalEvent('DISSOLUTION : L\'Assemblee Nationale est dissoute. Nouvelles elections convoquees.');
}

function doGrevePNJ() {
  const pays = state.country || 'republic';
  if (INDICES_NATIONAUX?.[pays]) INDICES_NATIONAUX[pays].IE = Math.max(0, INDICES_NATIONAUX[pays].IE - 5);
  updateUI();
  showToast('Greve declenchee', 'Les travailleurs cessent le travail. -5 IE.', false);
  addExternalEvent('GREVE : Mouvement social en cours. Impact economique.');
}

function doRecruterMilitants() {
  state.inf = Math.min(100, state.inf + 3);
  updateUI();
  showToast('Militants recrutes', '+3 INF. Votre base de soutien se renforce.', true);
  addJournalEntry('Recrutement de militants effectue.', 'event-info');
}

function doActeOfficiel() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cost = 50;
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  state.arg -= cost;
  if (!state.inventory) state.inventory = [];
  state.inventory.push({ type:'document', name:'Acte officiel de la mairie', icon:'ti-file-certificate', legal:true });
  updateUI();
  showToast('Acte delivre', 'Acte officiel ajoute a votre inventaire.', true);
}

// =====================
// SYSTEME DE BUDGET DES INSTITUTIONS
// =====================
const BUDGET_DEFAULT = {
  presidence: { solde: 50000, coutOrdre: 500 },
  min_int:    { solde: 30000, coutOrdre: 400 },
  min_fin:    { solde: 25000, coutOrdre: 300 },
  min_just:   { solde: 20000, coutOrdre: 350 },
  min_def:    { solde: 40000, coutOrdre: 600 },
  min_info:   { solde: 15000, coutOrdre: 250 },
  min_ae:     { solde: 20000, coutOrdre: 300 },
  assemblee:  { solde: 35000, coutOrdre: 200 },
  tribunal:   { solde: 20000, coutOrdre: 400 },
  commissariat:{ solde: 25000, coutOrdre: 350 },
  mairie:     { solde: 30000, coutOrdre: 250 }
};

// Repartition par defaut (%) - modifiable par le Ministre des Finances
const REPARTITION_DEFAULT = {
  presidence: 15, min_int: 8, min_fin: 6, min_just: 6,
  min_def: 10, min_info: 5, min_ae: 6,
  assemblee: 8, tribunal: 6, commissariat: 8, mairie: 12, reserve: 10
};

function getBudgetInstitution(inst) {
  if (!state.budgets) state.budgets = JSON.parse(JSON.stringify(BUDGET_DEFAULT));
  if (!state.budgets[inst]) state.budgets[inst] = { solde: 10000, coutOrdre: 300 };
  return state.budgets[inst];
}

function verifierBudgetInstitution(inst) {
  const b = getBudgetInstitution(inst);
  if (b.solde < b.coutOrdre) {
    const noms = {
      presidence:'la Presidence', min_fin:'le Ministere des Finances',
      min_int:'le Ministere de l\'Interieur', mairie:'la Mairie'
    };
    showToast('Budget insuffisant',
      'Le budget de ' + (noms[inst]||inst) + ' est insuffisant. Le Ministre des Finances doit revoir la repartition budgetaire.',
      false);
    return false;
  }
  b.solde -= b.coutOrdre;
  return true;
}

function alimenterBudgets() {
  // Appele a minuit - distribue les recettes fiscales
  const pays = state.country || 'republic';
  const pop = CITY_POPULATION?.[pays];
  if (!pop) return;
  let recettesTotales = 0;
  Object.values(pop).forEach(ville => {
    recettesTotales += ville.dailyTaxRevenue || 0;
  });

  const rep = state.repartitionBudget || REPARTITION_DEFAULT;
  if (!state.budgets) state.budgets = JSON.parse(JSON.stringify(BUDGET_DEFAULT));

  Object.keys(rep).forEach(inst => {
    if (inst === 'reserve') return;
    const montant = Math.floor(recettesTotales * (rep[inst] / 100));
    if (state.budgets[inst]) {
      state.budgets[inst].solde = Math.min(state.budgets[inst].solde + montant, 200000);
    }
  });

  // Reserve
  if (!state.reserve) state.reserve = 0;
  state.reserve += Math.floor(recettesTotales * ((rep.reserve || 10) / 100));
}

// =====================
// PREROGATIVES DU MAIRE
// =====================
function ouvrirFixerImpotsLocaux() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const taux = state.tauxImpositionLocal || 15;
  document.getElementById('postes-modal-title').textContent = 'Fixer les impôts locaux';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Taux actuel : ' + taux + '%. Impact direct sur les recettes municipales et la popularité.</div>';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">NOUVEAU TAUX (%)</div>';
  html += '<input id="taux-local-input" type="range" min="5" max="40" value="' + taux + '" oninput="document.getElementById(\'taux-local-val\').textContent=this.value+\'%\'" style="width:100%;margin-bottom:.3rem">';
  html += '<div id="taux-local-val" style="font-family:Bebas Neue,sans-serif;font-size:1.2rem;color:#C9A84C;text-align:center;margin-bottom:.6rem">' + taux + '%</div>';
  html += '<div style="font-size:.72rem;color:#5a5040;margin-bottom:.8rem">En dessous de 10% : budget serré mais populaire. Au dessus de 25% : recettes élevées mais impopulaire.</div>';
  html += '<button onclick="validerImpotsLocaux()" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Appliquer</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function validerImpotsLocaux() {
  const nouveauTaux = parseInt(document.getElementById('taux-local-input')?.value || '15');
  const ancienTaux = state.tauxImpositionLocal || 15;
  state.tauxImpositionLocal = nouveauTaux;
  const delta = nouveauTaux - ancienTaux;
  state.pop = Math.max(0, Math.min(100, state.pop - Math.floor(delta * 0.5)));
  document.getElementById('modal-postes').classList.remove('open');
  updateUI();
  showToast('Impôts locaux fixés', 'Taux : ' + nouveauTaux + '%. ' + (delta > 0 ? '-' + Math.floor(delta*0.5) + ' POP' : '+' + Math.floor(Math.abs(delta)*0.5) + ' POP'), delta > 0 ? false : true);
  addExternalEvent('MAIRIE : Le taux d\'imposition local est fixé à ' + nouveauTaux + '% par le Maire.');
}

function ouvrirRepartitionBudgetLocal() {
  const institutions = { commissariat: 40, dispensaire: 30, voirie: 20, services: 10 };
  const rep = state.budgetLocal || { ...institutions };
  document.getElementById('postes-modal-title').textContent = 'Budget municipal';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Répartition du budget entre les services municipaux. Total doit être 100%.</div>';
  const noms = { commissariat:'Commissariat', dispensaire:'Dispensaire', voirie:'Voirie', services:'Services municipaux' };
  Object.keys(rep).forEach(inst => {
    html += '<div style="display:flex;align-items:center;gap:.5rem;margin-bottom:.4rem">';
    html += '<div style="font-size:.78rem;color:#c0b090;width:130px">' + (noms[inst]||inst) + '</div>';
    html += '<input type="number" min="0" max="80" value="' + rep[inst] + '" id="bloc-' + inst + '" style="width:55px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.3rem;font-size:.82rem;outline:none">';
    html += '<span style="font-size:.72rem;color:#4a4030">%</span>';
    html += '</div>';
  });
  html += '<button onclick="validerBudgetLocal()" style="margin-top:.7rem;font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Valider</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function validerBudgetLocal() {
  const insts = ['commissariat','dispensaire','voirie','services'];
  let total = 0;
  const newRep = {};
  insts.forEach(inst => {
    const v = parseInt(document.getElementById('bloc-' + inst)?.value || '0');
    newRep[inst] = v;
    total += v;
  });
  if (total !== 100) { showToast('Total incorrect', 'Le total doit être 100%. Actuel : ' + total + '%.', false); return; }
  state.budgetLocal = newRep;
  document.getElementById('modal-postes').classList.remove('open');
  showToast('Budget validé', 'Nouvelle répartition municipale appliquée.', true);
  addJournalEntry('Répartition du budget municipal modifiée par le Maire.', 'event-info');
}

function doCampagneSecurite() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cost = 500;
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  state.arg -= cost;
  if (!verifierBudgetInstitution('mairie')) return;
  const pays = state.country || 'republic';
  if (INDICES_NATIONAUX?.[pays]) INDICES_NATIONAUX[pays].ISN = Math.min(100, INDICES_NATIONAUX[pays].ISN + 10);
  state.pop = Math.max(0, state.pop - 3);
  updateUI();
  showToast('Campagne de sécurité', '+10 ISN local. -3 POP. Prélevé sur budget mairie.', false);
  addExternalEvent('MAIRIE : Campagne de sécurité lancée par le Maire. +10 ISN.');
}

const ACTES_OFFICIELS = [
  { id:'acte_naissance',   name:'Acte de naissance fictif',       desc:'Identité alternative. Utile pour se fondre dans la masse.' },
  { id:'certif_residence', name:'Certificat de résidence',        desc:'+10% réussite ordres administratifs locaux.' },
  { id:'extrait_casier',   name:'Extrait de casier vierge',       desc:'Efface vos antécédents dans les archives locales.' },
  { id:'permis_exercer',   name:'Permis d\'exercer une activité', desc:'Autorise l\'exploitation d\'un commerce dans la ville.' },
  { id:'laissez_passer',   name:'Laissez-passer officiel',        desc:'+15 DIS dans la ville pendant 48h.' }
];

function ouvrirActeOfficielMairie() {
  document.getElementById('postes-modal-title').textContent = 'Délivrer un acte officiel';
  let html = '<div style="padding:1rem"><div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Choisir l\'acte à délivrer :</div>';
  ACTES_OFFICIELS.forEach(acte => {
    html += '<div onclick="delivrerActe(\'' + acte.id + '\')" style="padding:.6rem .8rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;cursor:pointer" onmouseover="this.style.background=\'#151005\'" onmouseout="this.style.background=\'#0f0d05\'">';
    html += '<div style="font-size:.82rem;color:#c0b090">' + acte.name + '</div>';
    html += '<div style="font-size:.68rem;color:#5a4030">' + acte.desc + '</div>';
    html += '</div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function delivrerActe(acteId) {
  document.getElementById('modal-postes').classList.remove('open');
  const acte = ACTES_OFFICIELS.find(a => a.id === acteId);
  if (!acte) return;
  if (!state.inventory) state.inventory = [];
  // Supprimer l'ancien acte du meme type si existant
  state.inventory = state.inventory.filter(i => i.acteId !== acteId);
  state.inventory.push({ type:'acte_officiel', name:acte.name, icon:'ti-file-certificate', legal:true, acteId, desc:acte.desc });
  updateUI();
  showToast('Acte délivré', acte.name + ' ajouté à votre inventaire.', true, true);
  addJournalEntry('Acte officiel délivré : ' + acte.name, 'event-info');
}

function ouvrirContesterResultats() {
  const elections = state.electionsEnCours?.filter(e => e.phase === 'termine') || [];
  document.getElementById('postes-modal-title').textContent = 'Contester des résultats';
  let html = '<div style="padding:1rem">';
  if (elections.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucune élection récente à contester.</div>';
  } else {
    html += '<div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Un recours sera déposé dans le sous-forum Tribunal. Le juge tranchera dans 48h.</div>';
    elections.forEach((e, i) => {
      html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.7rem;margin-bottom:.5rem">';
      html += '<div style="font-family:Playfair Display,serif;font-size:.85rem;color:#E8C97A">' + e.nom + '</div>';
      html += '<div style="font-size:.7rem;color:#5a4030">Élu : ' + (e.resultat?.elu || 'N/A') + '</div>';
      html += '<textarea id="motif-contestation-' + i + '" rows="3" placeholder="Motif de la contestation..." style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none;resize:none;margin:.4rem 0"></textarea>';
      html += '<button onclick="soumettreConte(' + i + ')" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;padding:.3rem .7rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Contester</button>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function soumettreConte(idx) {
  const e = (state.electionsEnCours||[]).filter(el => el.phase === 'termine')[idx];
  const motif = document.getElementById('motif-contestation-' + idx)?.value?.trim();
  if (!motif) { showToast('Motif requis', '', false); return; }
  document.getElementById('modal-postes').classList.remove('open');
  const ville = WORLD[state.country]?.[state.currentCity]?.name || 'la ville';
  const forumKey = 'tribunal_' + state.currentCity;
  if (!FORUM_TOPICS[forumKey]) FORUM_TOPICS[forumKey] = [];
  FORUM_TOPICS[forumKey].unshift({
    id: 'contestation-' + Date.now(),
    title: '[CONTESTATION] ' + e.nom,
    author: state.char?.name || 'Anonyme',
    time: 'Jour ' + state.day,
    posts: [{ author: state.char?.name, time: 'Jour ' + state.day, content: 'RECOURS ELECTORAL\n\nElection contestée : ' + e.nom + '\nMotif : ' + motif + '\n\nLe juge est prié de statuer dans les 48 heures.' }]
  });
  showToast('Recours déposé', 'Contestation publiée dans le forum du Tribunal de ' + ville + '. Décision dans 48h.', true);
  addJournalEntry('Contestation électorale déposée : ' + e.nom, 'event-info');
  addExternalEvent('ELECTORAL : ' + (state.char?.name||'Anonyme') + ' conteste les résultats de l\'élection : ' + e.nom);
}

// =====================
// CALENDRIER ELECTORAL
// =====================
// =====================
// SYSTEME DE TRANSPORT
// =====================
const TRANSPORT_CONFIG = {
  train:  { pa:2, cost:75,  label:'Train',  icon:'ti-train',  type:'intra',  desc:'Intra-empire uniquement. Plus économique.' },
  bus:    { pa:1, cost:150, label:'Bus/Taxi',icon:'ti-bus',   type:'intra',  desc:'Intra-empire. Rapide.' },
  avion:  { pa:3, cost:250, label:'Avion',  icon:'ti-plane', type:'inter',  desc:'Inter-empire. Contrôle douanes obligatoire.' },
  bateau: { pa:4, cost:100, label:'Bateau', icon:'ti-ship',  type:'inter',  desc:'Inter-empire. Moins cher, plus lent.' }
};

const VILLES_PAR_EMPIRE = {
  republic: [
    { id:'capitale',  name:'Luthecia',          type:'capitale' },
    { id:'ville_a',   name:'Port-Sainte-Marie',  type:'ville' },
    { id:'ville_b',   name:'Montrouge',           type:'ville' }
  ],
  narco: [
    { id:'capitale',  name:'Ciudad Roja',         type:'capitale' },
    { id:'ville_a',   name:'Puerto Oscuro',        type:'ville' },
    { id:'ville_b',   name:'La Selva',             type:'ville' }
  ],
  soviet: [
    { id:'capitale',  name:'Novomirsk',            type:'capitale' },
    { id:'ville_a',   name:'Stalinova',             type:'ville' },
    { id:'ville_b',   name:'Kolkhoz-7',             type:'ville' }
  ],
  khalija: [
    { id:'capitale',  name:'Al-Madina',            type:'capitale' },
    { id:'ville_a',   name:'Oasis Al-Zafar',       type:'ville' },
    { id:'ville_b',   name:'Port Al-Nour',          type:'ville' }
  ]
};

const EMPIRES_CONFIG = {
  republic: { name:'Républia', cur:'FR' },
  narco:    { name:'El Estado', cur:'PS' },
  soviet:   { name:'Sovarka',   cur:'RP' },
  khalija:  { name:'Al-Khalija',cur:'DR' }
};

function ouvrirModalTransport(mode) {
  const config = TRANSPORT_CONFIG[mode];
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const pays = state.country || 'republic';
  const isInter = config.type === 'inter';

  document.getElementById('postes-modal-title').textContent = 'Prendre le ' + config.label;
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">' + config.pa + ' PA · ' + config.cost + ' ' + cur + ' · ' + config.desc + '</div>';

  if (isInter) {
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">DESTINATION — EMPIRE</div>';
    Object.entries(EMPIRES_CONFIG).forEach(([key, emp]) => {
      if (key === pays) return;
      html += '<div onclick="confirmerTransport(\'' + mode + '\',\'' + key + '\',\'capitale\')" style="padding:.6rem .8rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;cursor:pointer" onmouseover="this.style.background=\'#151005\'" onmouseout="this.style.background=\'#0f0d05\'">';
      html += '<div style="font-size:.85rem;color:#c0b090">' + emp.name + '</div>';
      html += '<div style="font-size:.7rem;color:#5a4030">Capitale</div>';
      html += '</div>';
    });
  } else {
    // Intra-empire
    const villes = VILLES_PAR_EMPIRE[pays] || [];
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">DESTINATION</div>';
    villes.forEach(ville => {
      if (ville.id === state.currentCity) return;
      html += '<div onclick="confirmerTransport(\'' + mode + '\',\'' + pays + '\',\'' + ville.id + '\')" style="padding:.6rem .8rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;cursor:pointer" onmouseover="this.style.background=\'#151005\'" onmouseout="this.style.background=\'#0f0d05\'">';
      html += '<div style="font-size:.85rem;color:#c0b090">' + ville.name + '</div>';
      html += '<div style="font-size:.7rem;color:#5a4030">' + (ville.type === 'capitale' ? 'Capitale' : 'Ville') + '</div>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function executerVoyage(mode, empireId, villeId) {
  const config = TRANSPORT_CONFIG[mode];
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  state.arg -= config.cost;
  const ancienEmpire = state.country;
  state.country = empireId;
  state.currentCity = villeId;
  state.currentBuilding = null;
  state.currentRoom = null;
  if (state.char) {
    state.char.country = empireId;
    state.char.currentCity = villeId;
    localStorage.setItem('respublica_char_' + (state.char?.name || 'default'), JSON.stringify(state.char));
  }
  applyEmpireTheme(empireId);
  buildCityTabs();
  updateUI();
  forceRenderCity(villeId);
  const villeName = VILLES_PAR_EMPIRE[empireId]?.find(v => v.id === villeId)?.name || villeId;
  const empireName = EMPIRES_CONFIG[empireId]?.name || empireId;
  showToast('Bienvenue à ' + villeName + ' !', empireName + ' · -' + config.cost + ' ' + cur, true, true);
  addJournalEntry('Voyage en ' + config.label + ' → ' + villeName + ' (' + empireName + ')', 'event-info');
  addExternalEvent((state.char?.name||'Anonyme') + ' est arrivé(e) à ' + villeName + ' (' + empireName + ').');
}

function confirmerTransport(mode, empireId, villeId) {
  document.getElementById('modal-postes').classList.remove('open');
  const config = TRANSPORT_CONFIG[mode];
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  if (state.arg < config.cost) {
    showToast('Fonds insuffisants', 'Il vous faut ' + config.cost + ' ' + cur, false);
    return;
  }

  // Controle douanes obligatoire pour avion et bateau
  if (mode === 'avion' || mode === 'bateau') {
    const msgs = {
      republic: "L'inspecteur Prosper Tampon examine vos papiers, tamponne trois formulaires et vous laisse passer.",
      narco:    "Juanita Soborno vous sourit. Vous glissez un billet. Elle regarde ailleurs. Bonne route.",
      soviet:   "Nadejda Contrôle fouille votre bagage méthodiquement. Tout est en ordre, Camarade.",
      khalija:  "Le Chambellan Al-Transit incline la tête. Vos papiers sont en règle. Bienvenue."
    };

    // Si recherche : jet de detection
    if (state.recherche?.length > 0) {
      const dis = state.char?.stats?.DIS || 50;
      const roll = Math.floor(Math.random() * 100) + 1;
      const taux = Math.max(5, 70 + Math.floor(dis/10) - getMalusISN());
      if (roll > taux) {
        showToast('Intercepté aux douanes !', 'Votre statut de Recherché a été détecté. Vous êtes arrêté(e).', false);
        addJournalEntry('Interception aux douanes. Arrestation.', 'event-bad');
        addExternalEvent((state.char?.name||'Anonyme') + ' a été intercepté(e) aux douanes.');
        return;
      }
    }

    // Afficher modal douanes avant de voyager
    const msg = msgs[state.country] || msgs['republic'];
    document.getElementById('postes-modal-title').textContent = '🛂 Contrôle douanier';
    document.getElementById('postes-body').innerHTML =
      '<div style="padding:1.2rem">' +
      '<div style="font-size:.88rem;color:#c0b090;font-style:italic;line-height:1.8;font-family:Crimson Pro,serif">' + msg + '</div>' +
      '<div style="margin-top:1rem;text-align:right">' +
      '<button onclick="document.getElementById(\'modal-postes\').classList.remove(\'open\');executerVoyage(\'' + mode + '\',\'' + empireId + '\',\'' + villeId + '\')" ' +
      'style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.4rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Embarquer →</button>' +
      '</div></div>';
    document.getElementById('modal-postes').classList.add('open');
    addJournalEntry('Passage aux douanes.', 'event-info');
    return; // On attend la confirmation
  }

  // Voyage a 100% si ressources OK
  state.arg -= config.cost;

  // Changer d'empire et de ville
  const ancienEmpire = state.country;
  state.country = empireId;
  state.currentCity = villeId;
  state.currentBuilding = null;
  state.currentRoom = null;

  // Sauvegarder dans localStorage
  if (state.char) {
    state.char.country = empireId;
    state.char.currentCity = villeId;
    localStorage.setItem('respublica_char_' + (state.char?.name || 'default'), JSON.stringify(state.char));
  }

  // Reconstruire l'interface pour le nouvel empire
  buildCityTabs();
  updateUI();
  updateLocationDisplay();
  renderMinimap(villeId);

  // Forcer le rechargement de la vue rue dans le nouvel empire
  const world = WORLD[empireId];
  const city = world?.[villeId];
  if (city) {
    document.getElementById('city-name-display').textContent = city.name + ', ' + (COUNTRIES[empireId]?.n || empireId);
    document.querySelectorAll('.city-tab').forEach(t => {
      t.classList.toggle('active', t.textContent === city.name);
    });
    // Mettre a jour le titre et la description de la rue
    const rueTitle = document.getElementById('rue-title');
    const rueDesc = document.getElementById('rue-desc');
    if (rueTitle) rueTitle.textContent = city.isCapitale ? 'Avenue Principale' : 'Rue principale de ' + city.name;
    if (rueDesc) rueDesc.textContent = city.desc || '';
    // Mettre a jour l'image de la rue
    const rueImage = document.getElementById('rue-image');
    if (rueImage && city.imageUrl) {
      rueImage.style.background = `linear-gradient(180deg, rgba(0,0,0,0.1) 0%, rgba(0,0,0,0.4) 100%), url('${city.imageUrl}') center/cover no-repeat`;
      rueImage.style.backgroundSize = 'cover';
    }
    // Afficher la vue rue
    document.getElementById('vue-rue').classList.add('active');
    document.getElementById('vue-batiment').classList.remove('active');
    // Mettre a jour les personnes presentes
    renderPersonsList(city.persons || []);
  }

  const villeName = VILLES_PAR_EMPIRE[empireId]?.find(v => v.id === villeId)?.name || city?.name || villeId;
  const empireName = EMPIRES_CONFIG[empireId]?.name || empireId;
  showToast('Bienvenue à ' + villeName + ' !', empireName + ' · -' + config.cost + ' ' + cur, true, true);
  addJournalEntry('Voyage en ' + config.label + ' → ' + villeName + ' (' + empireName + ')', 'event-info');
  addExternalEvent((state.char?.name||'Anonyme') + ' est arrivé(e) à ' + villeName + ' (' + empireName + ').');
}

function doControlDouanes() {
  if (!state.recherche?.length) {
    showToast('Contrôle', 'Contrôle routinier. Tout est en ordre. Bonne route.', true);
    return;
  }
  const dis = state.char?.stats?.DIS || 50;
  const roll = Math.floor(Math.random() * 100) + 1;
  const taux = Math.max(5, 70 + Math.floor(dis/10) - getMalusISN());
  if (roll <= taux) {
    showToast('Contrôle passé', 'L\'agent a regardé vos papiers sans trop y prêter attention. Ouf.', true);
  } else {
    showToast('Interception !', 'L\'agent a reconnu votre signalement. Vous êtes arrêté(e).', false);
    addJournalEntry('Interception aux douanes.', 'event-bad');
  }
}

function doCorrompreDoanier() {
  const roll = Math.floor(Math.random() * 100) + 1;
  const dup = state.char?.stats?.DUP || 8;
  const inf = state.inf || 0;
  const taux = Math.max(5, 55 + Math.floor(dup/10) + Math.floor(inf/10) + 20); // +20 zone transport
  if (roll <= taux) {
    state.arg -= 300;
    state.dis = Math.max(0, state.dis - 5);
    updateUI();
    showToast('Agent corrompu', 'L\'agent regarde ailleurs. -300 FR -5 DIS.', true);
    addJournalEntry('Corruption douanière réussie.', 'event-bad');
    checkDetection('corrompre_douanier', 'success');
  } else {
    showToast('Refus !', 'L\'agent n\'a pas mordu. Tentative notée.', false);
    checkDetection('corrompre_douanier', 'fail');
  }
}

// =====================
// SYSTEME PORT
// =====================
function ouvrirExpedierColis() {
  const inventaire = (state.inventory || []).filter(i => i.type !== 'acte_officiel');
  if (inventaire.length === 0) { showToast('Inventaire vide', 'Aucun objet à expédier.', false); return; }
  const contacts = state.contacts || [];
  if (contacts.length === 0) { showToast('Répertoire vide', 'Aucun destinataire disponible.', false); return; }

  document.getElementById('postes-modal-title').textContent = 'Expédier un colis';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">2 PA · 200 FR · Livraison sous 24h dans un autre empire.</div>';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">OBJET À EXPÉDIER</div>';
  html += '<select id="exp-objet" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.6rem">';
  inventaire.forEach((obj, i) => { html += '<option value="' + i + '">' + obj.name + '</option>'; });
  html += '</select>';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">DESTINATAIRE</div>';
  html += '<select id="exp-dest" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.8rem">';
  contacts.forEach(c => { html += '<option value="' + c.name + '">' + c.name + '</option>'; });
  html += '</select>';
  html += '<button onclick="confirmerExpedition()" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Expédier</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerExpedition() {
  const objIdx = parseInt(document.getElementById('exp-objet')?.value || '0');
  const dest = document.getElementById('exp-dest')?.value;
  const inventaire = (state.inventory || []).filter(i => i.type !== 'acte_officiel');
  const obj = inventaire[objIdx];
  if (!obj || !dest) return;
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  if (state.arg < 200) { showToast('Fonds insuffisants', '200 ' + cur + ' requis.', false); return; }
  state.arg -= 200;
  state.inventory = state.inventory.filter(i => i !== obj);
  updateUI();
  document.getElementById('modal-postes').classList.remove('open');
  if (!state.colisEnCours) state.colisEnCours = [];
  state.colisEnCours.push({ objet: obj, dest, jourArrivee: state.day + 1 });
  showToast('Colis expédié !', obj.name + ' envoyé à ' + dest + '. Arrivée dans 24h.', true, true);
  addJournalEntry('Colis expédié : ' + obj.name + ' → ' + dest, 'event-info');
  addMailNotification('Service postal', 'Colis en route', 'Un colis (' + obj.name + ') a été expédié par ' + (state.char?.name||'Anonyme') + '. Récupérez-le au port sous 24h.');
}

function ouvrirReceptionnerCommande() {
  const colis = (state.colisEnCours || []).filter(c => c.jourArrivee <= state.day);
  document.getElementById('postes-modal-title').textContent = 'Réceptionner une commande';
  let html = '<div style="padding:1rem">';
  if (colis.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucun colis en attente de réception.</div>';
  } else {
    colis.forEach((c, i) => {
      html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.7rem;margin-bottom:.5rem;display:flex;align-items:center;justify-content:space-between">';
      html += '<div><div style="font-size:.82rem;color:#c0b090">' + c.objet.name + '</div>';
      html += '<div style="font-size:.7rem;color:#5a4030">Expédié par ' + (c.expediteur||'Inconnu') + '</div></div>';
      html += '<button onclick="recupererColis(' + i + ')" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;padding:.3rem .6rem;border:1px solid #4a8a4a;background:transparent;color:#4a8a4a;cursor:pointer">Récupérer</button>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function recupererColis(idx) {
  const colis = (state.colisEnCours || []).filter(c => c.jourArrivee <= state.day);
  const c = colis[idx];
  if (!c) return;
  if (!state.inventory) state.inventory = [];
  state.inventory.push(c.objet);
  state.colisEnCours = state.colisEnCours.filter(x => x !== c);
  updateUI();
  document.getElementById('modal-postes').classList.remove('open');
  showToast('Colis récupéré !', c.objet.name + ' ajouté à votre inventaire.', true, true);
}

function doContrebandePort() {
  const pays = state.country || 'republic';
  const dis = state.char?.stats?.DIS || 8;
  const dup = state.char?.stats?.DUP || 8;
  const empMod = { republic:0, narco:25, soviet:-20, khalija:10 }[pays] || 0;
  const taux = Math.max(5, 55 + Math.floor(dis/10) + Math.floor(dup/10) + 15 + empMod - getMalusISN());
  const roll = Math.floor(Math.random() * 100) + 1;

  if (roll <= taux) {
    if (!state.inventory) state.inventory = [];
    state.inventory.push({ type:'contrebande', name:'Cargaison de contrebande', icon:'ti-package-off', legal:false, desc:'Marchandises importées illégalement.' });
    state.dis = Math.max(0, state.dis - 5);
    updateUI();
    showToast('Contrebande réussie !', 'Cargaison ajoutée à votre inventaire. -5 DIS.', true, true);
    addJournalEntry('Contrebande portuaire réussie.', 'event-bad');
    checkDetection('contrebande_port', 'success');
  } else {
    showToast('Échec !', 'La douane a repéré la manœuvre.', false);
    checkDetection('contrebande_port', 'fail');
  }
}

function doBlocusPortuaire() {
  const vol = state.char?.stats?.VOL || 8;
  const ent = state.char?.stats?.ENT || 8;
  const taux = Math.max(5, 60 + Math.floor(vol/10) + Math.floor(ent/10) - getMalusISN());
  const roll = Math.floor(Math.random() * 100) + 1;
  const pays = state.country || 'republic';

  if (roll <= taux) {
    if (INDICES_NATIONAUX?.[pays]) INDICES_NATIONAUX[pays].IE = Math.max(0, INDICES_NATIONAUX[pays].IE - 5);
    updateUI();
    showToast('Blocus déclenché !', 'Le port est paralysé pour 24h. -5 IE.', false);
    addExternalEvent('GRÈVE : Blocus portuaire déclenché ! Importations/exportations suspendues 24h. -5 IE.');
    addJournalEntry('Blocus portuaire initié.', 'event-info');
  } else {
    state.pop = Math.max(0, state.pop - 8);
    updateUI();
    showToast('Échec du blocus', 'Le mouvement n\'a pas pris. -8 POP.', false);
    checkDetection('blocus_portuaire', 'fail');
  }
}

function doInspecterCargaisons() {
  const int_ = state.char?.stats?.INT || 8;
  const pays = state.country || 'republic';
  const isBonus = pays === 'soviet';
  const taux = Math.max(5, 80 + Math.floor(int_/10) + (isBonus ? 15 : 0));
  const roll = Math.floor(Math.random() * 100) + 1;

  if (roll <= taux) {
    state.inf = Math.min(100, state.inf + 5);
    updateUI();
    const trouve = Math.random() < 0.4;
    if (trouve) {
      showToast('Contrebande détectée !', 'Une cargaison suspecte a été repérée. +5 INF. Ouvrir une enquête ?', true, true);
      addExternalEvent('INSPECTION : Contrebande détectée au port par ' + (state.char?.name||'Anonyme') + '. Enquête en cours.');
    } else {
      showToast('Inspection terminée', 'Rien d\'anormal. +5 INF.', true);
    }
  } else {
    showToast('Inspection sans résultat', 'Rien à signaler. -3 INF.', false);
    state.inf = Math.max(0, state.inf - 3);
    updateUI();
  }
}

function doConsulterManifeste() {
  const int_ = state.char?.stats?.INT || 8;
  const taux = Math.max(5, 75 + Math.floor(int_/10));
  const roll = Math.floor(Math.random() * 100) + 1;

  if (roll <= taux) {
    state.inf = Math.min(100, state.inf + 3);
    updateUI();
    showToast('Manifeste consulté', 'Vous repérez des incohérences dans les registres. +3 INF.', true);
    addJournalEntry('Manifeste portuaire consulté. Incohérences notées.', 'event-info');
  } else {
    showToast('Accès refusé', 'Le registre n\'est pas disponible.', false);
  }
}

function doFalsifierManifeste() {
  const dup = state.char?.stats?.DUP || 8;
  const taux = Math.max(5, 40 + Math.floor(dup/10) - getMalusISN());
  const roll = Math.floor(Math.random() * 100) + 1;

  if (roll <= taux) {
    state.arg -= 200;
    updateUI();
    showToast('Manifeste falsifié', 'La cargaison a disparu des registres.', true, true);
    addJournalEntry('Falsification du manifeste portuaire.', 'event-bad');
    checkDetection('falsifier_manifeste', 'success');
  } else {
    showToast('Échec !', 'La falsification a échoué.', false);
    checkDetection('falsifier_manifeste', 'fail');
  }
}

// =====================
// OBJETS POISON
// =====================
const POISON_OBJETS = {
  parapluie: { name:'Parapluie républien', icon:'ti-umbrella',   cout:400, empire:'republic', msg:'Un accessoire élégant. Discret. La pointe contient... quelque chose.' },
  ghb:       { name:'GHB de contrebande', icon:'ti-flask',       cout:300, empire:'narco',    msg:'Un flacon transparent. Inodore, incolore. À manier avec précaution.' },
  polonium:  { name:'Fiole de Polonium',  icon:'ti-radioactive', cout:600, empire:'soviet',   msg:'Un petit contenant blindé. Ne pas ouvrir sans combinaison.' },
  vipere:    { name:'Vipère des sables',  icon:'ti-bug',         cout:350, empire:'khalija',  msg:'Une petite boîte percée. On entend un léger sifflement.' }
};

function doAcheterPoisonObjet(type) {
  const obj = POISON_OBJETS[type];
  if (!obj) return;
  const pays = state.country || 'republic';
  const cur = COUNTRIES[pays]?.cur || 'FR';

  if (state.arg < obj.cout) { showToast('Fonds insuffisants', obj.cout + ' ' + cur + ' requis.', false); return; }

  state.arg -= obj.cout;
  if (!state.inventory) state.inventory = [];
  state.inventory.push({
    type: 'poison', name: obj.name, icon: obj.icon,
    poisonType: type, legal: false, usageUnique: true,
    desc: obj.msg
  });
  updateUI();
  showToast('Objet acquis', obj.name + ' ajouté à votre inventaire. Usage unique.', true, true);
  addJournalEntry('Achat : ' + obj.name, 'event-bad');
}

// =====================
// ASSASSINER
// =====================
function ouvrirModalAssassiner() {
  // Verifier prérequis : se cacher réussi
  if (!state.estCache) {
    showToast('Prérequis manquant', 'Vous devez d\'abord réussir l\'ordre "Se cacher" dans cette pièce.', false);
    return;
  }
  const personnesPresentes = getCurrentRoomPersons().filter(p => p.isPJ && p.name !== state.char?.name);
  if (personnesPresentes.length === 0) {
    showToast('Personne à cibler', 'Aucun PJ dans cette pièce.', false);
    return;
  }

  document.getElementById('postes-modal-title').textContent = 'Assassiner';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#cc4444;font-style:italic;margin-bottom:.8rem">Acte illégal. Prérequis : Se cacher réussi. Taux base : 35% − PER cible/10 + Bonus empire + Bonus carrière criminel +15%.</div>';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">CIBLE</div>';
  personnesPresentes.forEach(p => {
    html += '<div onclick="confirmerAssassinat(\'' + p.name + '\')" style="padding:.7rem;border:1px solid #3a1010;background:#0f0505;margin-bottom:.4rem;cursor:pointer;display:flex;align-items:center;justify-content:space-between" onmouseover="this.style.background=\'#1a0808\'" onmouseout="this.style.background=\'#0f0505\'">';
    html += '<div style="font-size:.85rem;color:#c0b090">' + p.name + '</div>';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.65rem;color:#cc4444">ÉLIMINER</div>';
    html += '</div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerAssassinat(cibleNom) {
  document.getElementById('modal-postes').classList.remove('open');
  const pays = state.country || 'republic';
  const empMod = { republic:0, narco:20, soviet:-10, khalija:0 }[pays] || 0;
  const careerBonus = state.char?.career === 'criminel' ? 15 : 0;
  const perCible = 50; // Simulation PER cible - en vrai multijoueur on lirait le localStorage cible
  const taux = Math.max(5, 35 - Math.floor(perCible/10) + empMod + careerBonus - getMalusISN());
  const roll = Math.floor(Math.random() * 100) + 1;

  if (roll <= taux) {
    // Succes
    state.estCache = false;
    showToast('Assassinat réussi', cibleNom + ' est hors de combat. 0 PA 0 HP.', true, true);
    addJournalEntry('Assassinat de ' + cibleNom + ' réussi.', 'event-bad');
    addExternalEvent('ALERTE : ' + cibleNom + ' vient d\'être assassiné(e) ! Aucun témoin.');
    addMailNotification('Événement', 'Vous avez été assassiné(e)', 'Quelqu\'un vous a attaqué. Vous êtes à 0 PA et 0 HP. Passez l\'ordre Dormir pour récupérer.');
    // Enregistrer dans l'historique criminel (disparait apres 8 jours)
    if (!state.historiqueCrimes) state.historiqueCrimes = [];
    state.historiqueCrimes.push({ acte:'assassinat', cible:cibleNom, jour:state.day, expireJour: state.day + 8 });
  } else {
    // Echec
    state.estCache = false;
    state.recherche = [{ acte:'tentative_assassinat', type:'crime', jour:state.day, peine:2 }];
    showToast('Échec ! Vous êtes repéré(e)', 'Tentative d\'assassinat ratée. Recherché(e). 2 jours de prison.', false);
    addJournalEntry('Tentative d\'assassinat ratée. Statut : Recherché.', 'event-bad');
    addExternalEvent('ALERTE : Tentative d\'assassinat sur ' + cibleNom + ' ! L\'auteur est en fuite.');
    updateUI();
  }
}

// =====================
// EMPOISONNER
// =====================
const POISON_MESSAGES = {
  parapluie: 'Quelque chose vous pique dans le dos. Une douleur irradie dans tout votre corps et s\'intensifie d\'heure en heure. Était-ce en lien avec cette personne qui vous a touché avec le bout de son parapluie et s\'est excusée ? Vous perdez 2 PA.',
  ghb:       'Votre esprit devient confus. Vous avez la tête qui tourne et vos sens sont perturbés. Vous avez l\'impression d\'avoir été drogué(e), mais par qui ? Vous perdez 2 PA.',
  polonium:  'Vous vous sentez subitement faible. En passant la main dans vos cheveux, ils se décrochent par paquets de votre crâne, comme si vous aviez été mis(e) en contact avec quelque chose de radioactif. Vous perdez 2 PA.',
  vipere:    'Vous ressentez une violente douleur au niveau du mollet. Deux petits trous douloureux et rouges sont visibles. Un serpent vous aurait-il mordu(e) ? Vous perdez 2 PA.'
};

const POISON_STAT_PERDUE = {
  republic: 'VOL',
  narco:    'PER',
  soviet:   'INT',
  khalija:  'CHA'
};

function ouvrirModalEmpoisonner() {
  if (!state.estCache) {
    showToast('Prérequis manquant', 'Vous devez d\'abord réussir l\'ordre "Se cacher" dans cette pièce.', false);
    return;
  }
  const poisonInventaire = (state.inventory || []).find(i => i.type === 'poison');
  if (!poisonInventaire) {
    showToast('Objet manquant', 'Vous n\'avez pas d\'objet poison dans votre inventaire. Procurez-vous en dans votre empire.', false);
    return;
  }
  const personnesPresentes = getCurrentRoomPersons().filter(p => p.isPJ && p.name !== state.char?.name);
  if (personnesPresentes.length === 0) {
    showToast('Personne à cibler', 'Aucun PJ dans cette pièce.', false);
    return;
  }

  document.getElementById('postes-modal-title').textContent = 'Empoisonner';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#cc4444;font-style:italic;margin-bottom:.8rem">Acte illégal. Objet : ' + poisonInventaire.name + ' (usage unique). Effets progressifs sur 3 jours.</div>';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">CIBLE</div>';
  personnesPresentes.forEach(p => {
    html += '<div onclick="confirmerEmpoisonnement(\'' + p.name + '\')" style="padding:.7rem;border:1px solid #2a1a30;background:#0f050f;margin-bottom:.4rem;cursor:pointer" onmouseover="this.style.background=\'#1a0818\'" onmouseout="this.style.background=\'#0f050f\'">';
    html += '<div style="font-size:.85rem;color:#c0b090">' + p.name + '</div>';
    html += '</div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerEmpoisonnement(cibleNom) {
  document.getElementById('modal-postes').classList.remove('open');
  const pays = state.country || 'republic';
  const empMod = { republic:0, narco:20, soviet:-10, khalija:0 }[pays] || 0;
  const careerBonus = state.char?.career === 'criminel' ? 15 : 0;
  const perCible = 50;
  const taux = Math.max(5, 40 - Math.floor(perCible/10) + empMod + careerBonus - getMalusISN());
  const roll = Math.floor(Math.random() * 100) + 1;

  // Supprimer l'objet poison de l'inventaire (usage unique)
  const poisonIdx = (state.inventory || []).findIndex(i => i.type === 'poison');
  if (poisonIdx >= 0) state.inventory.splice(poisonIdx, 1);

  if (roll <= taux) {
    state.estCache = false;
    // Enregistrer l'empoisonnement actif sur la cible
    if (!state.empoisonnements) state.empoisonnements = [];
    state.empoisonnements.push({
      cible: cibleNom,
      empireEmpoisonneur: pays,
      jourDebut: state.day,
      statPerdue: POISON_STAT_PERDUE[pays],
      actif: true
    });

    // Message a la cible
    const poisonType = (state.inventory||[]).find(i => i.type === 'poison')?.poisonType || 'parapluie';
    const msg = POISON_MESSAGES[poisonType] || POISON_MESSAGES['parapluie'];
    addMailNotification('Événement mystérieux', 'Vous vous sentez mal', msg);
    addExternalEvent('MYSTERE : ' + cibleNom + ' se sent soudainement très mal...');

    if (!state.historiqueCrimes) state.historiqueCrimes = [];
    state.historiqueCrimes.push({ acte:'empoisonnement', cible:cibleNom, jour:state.day, expireJour: state.day + 8 });

    updateUI();
    showToast('Poison administré', cibleNom + ' commencera à ressentir les effets. Objet utilisé.', true, true);
    addJournalEntry('Empoisonnement de ' + cibleNom + '.', 'event-bad');
  } else {
    state.estCache = false;
    state.recherche = [{ acte:'tentative_empoisonnement', type:'crime', jour:state.day, peine:2 }];
    updateUI();
    showToast('Échec ! Repéré(e)', 'L\'empoisonnement a échoué. Objet perdu. Recherché(e). 2 jours de prison.', false);
    addJournalEntry('Tentative d\'empoisonnement échouée. Recherché.', 'event-bad');
  }
}

// =====================
// TAXI SPECIAL — CASERNE / QHS
// =====================
const ACCES_CASERNE = ['president', 'min_def', 'commissaire'];
const ACCES_QHS = ['president', 'min_just', 'juge', 'commissaire', 'avocat'];

function doTaxiSpecial(destination) {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  if (state.arg < 200) { showToast('Fonds insuffisants', '200 ' + cur + ' requis.', false); return; }

  const label = destination === 'caserne' ? 'la Caserne' : 'le QHS';
  const cityKey = destination === 'caserne' ? 'caserne' : 'qhs';

  // Verifier acces
  const posteId = state.poste?.id || '';
  const accesLibres = destination === 'caserne' ? ACCES_CASERNE : ACCES_QHS;
  const aAccesLibre = accesLibres.some(p => posteId.includes(p));
  const aLaissezPasser = (state.inventory||[]).some(i =>
    i.acteId === 'laissez_passer' || i.acteId === 'acte_officiel' || i.type === 'document_falsifie'
  );

  if (!aAccesLibre && !aLaissezPasser) {
    showToast('Accès refusé', 'Vous n\'avez pas les autorisations pour vous rendre à ' + label + '. Procurez-vous un laissez-passer officiel ou un ordre de visite.', false);
    return;
  }

  // Si faux document — jet DUP
  const aVraiDoc = aAccesLibre || (state.inventory||[]).some(i => i.acteId === 'laissez_passer' && i.legal);
  if (!aVraiDoc && aLaissezPasser) {
    const dup = state.char?.stats?.DUP || 8;
    const roll = Math.floor(Math.random() * 100) + 1;
    const taux = Math.max(5, 50 + Math.floor(dup/10) - getMalusISN());
    if (roll > taux) {
      showToast('Faux document détecté !', 'La garde a reconnu le faux. Vous êtes arrêté(e).', false);
      state.recherche = [{ acte:'faux_document', type:'delit_grave', jour:state.day, peine:4 }];
      updateUI();
      addJournalEntry('Faux laissez-passer détecté à l\'entrée de ' + label + '. Arrestation.', 'event-bad');
      return;
    }
  }

  // Voyage OK
  state.arg -= 200;
  state.currentCity = cityKey;
  state.currentBuilding = null;
  state.currentRoom = null;
  if (state.char) {
    state.char.currentCity = cityKey;
    localStorage.setItem('respublica_char_' + (state.char?.name || 'default'), JSON.stringify(state.char));
  }
  buildCityTabs();
  updateUI();
  forceRenderCity(cityKey);
  showToast('En route !', 'Vous arrivez à ' + label + '. -200 ' + cur, true);
  addJournalEntry('Taxi vers ' + label, 'event-info');
}

// =====================
// SYSTEME INFORMATEURS
// =====================
const INFORMATEUR_NIVEAUX = {
  1: { label:'Informateur de rue',      cout:150, lieux:['hotel-republica','marche','bar-des-pecheurs'], desc:'Localisation approximative, rumeurs locales.' },
  2: { label:'Informateur politique',   cout:400, lieux:['loge-maconnique','universite','siege-syndical'], desc:'Localisation précise, intentions vote, voyages.' },
  3: { label:'Informateur criminel',    cout:700, lieux:['port-sainte-marie','bar-des-pecheurs','contrebande'], desc:'Indice empire d\'origine d\'un crime, contrebandes.' },
  4: { label:'Taupe',                   cout:1500, lieux:['loge-maconnique'], desc:'Confessions, transactions, ordres passés 24h.' }
};

function getInfomateurInfo(niveau) {
  const pays = state.country || 'republic';
  const infos = {
    1: [
      (state.char?.name||'Anonyme') + ' a été aperçu(e) dans le quartier nord de la ville.',
      'Un PJ inconnu a été vu entrer et sortir rapidement du commissariat.',
      'Des rumeurs circulent sur une prochaine élection anticipée.',
      'Quelqu\'un cherche à recruter des partisans discrètement.'
    ],
    2: [
      'Un député a été vu entrer au Palais Présidentiel ce matin.',
      'Des tractations sont en cours pour une alliance électorale secrète.',
      'Un PJ influent a pris l\'avion hier soir vers un autre empire.',
      'Le vote de mercredi prochain semble déjà arrangé par deux députés.'
    ],
    3: [
      'L\'auteur du crime récent semble venir de ' + (['Républia','El Estado','Sovarka','Al-Khalija'][Math.floor(Math.random()*4)]) + '.',
      'Une cargaison suspecte est attendue au port dans les prochaines 24h.',
      'Des échanges d\'argent non déclarés ont eu lieu entre deux PJ.',
      'Un contrat a été passé dans les milieux criminels contre un élu.'
    ],
    4: [
      'Un PJ a confessé au Grand Prêtre avoir falsifié des documents électoraux.',
      'Une transaction de 5000 FR a été effectuée entre deux PJ hier soir.',
      'Dans les dernières 24h, un PJ a passé les ordres : Corrompre, Produire une fuite.',
      'Un ministre prépare sa démission et contacte l\'opposition en secret.'
    ]
  };
  const list = infos[niveau] || infos[1];
  return list[Math.floor(Math.random() * list.length)];
}

function ouvrirRecruterInformateur(niveau) {
  const cfg = INFORMATEUR_NIVEAUX[niveau];
  if (!cfg) return;
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  // Verifier max 2 informateurs
  if (!state.informateurs) state.informateurs = [];
  if (state.informateurs.length >= 2) {
    showToast('Maximum atteint', 'Vous ne pouvez avoir que 2 informateurs simultanément.', false);
    return;
  }
  // Verifier si niveau deja actif
  if (state.informateurs.find(i => i.niveau === niveau)) {
    showToast('Déjà actif', 'Vous avez déjà un informateur de niveau ' + niveau + '.', false);
    return;
  }

  document.getElementById('postes-modal-title').textContent = 'Recruter un informateur — Niveau ' + niveau;
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1.2rem">' +
    '<div style="font-size:.85rem;color:#c0b090;line-height:1.7;font-family:Crimson Pro,serif;margin-bottom:.8rem">' + cfg.desc + '</div>' +
    '<div style="font-size:.75rem;color:#8a6a20;margin-bottom:1rem">Coût : <strong>' + cfg.cout + ' ' + cur + '/jour</strong> · Prélevé à chaque Dormir · Max 2 informateurs simultanés</div>' +
    '<button onclick="confirmerRecrutementInformateur(' + niveau + ')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.4rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Recruter</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerRecrutementInformateur(niveau) {
  document.getElementById('modal-postes').classList.remove('open');
  const cfg = INFORMATEUR_NIVEAUX[niveau];
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  if (state.arg < cfg.cout) {
    showToast('Fonds insuffisants', cfg.cout + ' ' + cur + ' requis.', false);
    return;
  }
  state.arg -= cfg.cout;
  if (!state.informateurs) state.informateurs = [];
  state.informateurs.push({ niveau, label: cfg.label, cout: cfg.cout, actif: true, joursActif: 0 });
  updateUI();
  showToast('Informateur recruté !', cfg.label + ' est maintenant actif. -' + cfg.cout + ' ' + cur + '/jour via Dormir.', true);
  addJournalEntry('Informateur niveau ' + niveau + ' recruté : ' + cfg.label, 'event-info');
}

function payerInformateurs() {
  if (!state.informateurs?.length) return;
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  let total = 0;
  state.informateurs = state.informateurs.filter(inf => {
    if (state.arg >= inf.cout) {
      state.arg -= inf.cout;
      total += inf.cout;
      inf.joursActif++;
      return true;
    } else {
      addJournalEntry('Votre informateur niveau ' + inf.niveau + ' (' + inf.label + ') a quitté faute de paiement.', 'event-bad');
      showToast('Informateur parti', inf.label + ' est parti — fonds insuffisants.', false);
      return false;
    }
  });
  if (total > 0) addJournalEntry('Salaires informateurs : -' + total + ' ' + cur, 'event-info');
}

function consulterInformateur(niveau) {
  if (!state.informateurs) state.informateurs = [];

  // Max 2 informateurs simultanés
  if (state.informateurs.length >= 2) {
    showToast('Limite atteinte', 'Vous avez deja 2 informateurs actifs. Licenciez-en un avant d\'en recruter un autre.', false);
    return;
  }

  // Vérifier si niveau déjà actif
  if (state.informateurs.find(i => i.niveau === niveau)) {
    showToast('Déjà actif', `Vous avez déjà un informateur de niveau ${niveau}.`, false);
    return;
  }

  const config = INFORMATEUR_NIVEAUX[niveau];
  if (!config) return;
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  // Vérifier les fonds pour le premier paiement
  if (state.arg < config.cout) {
    showToast('Fonds insuffisants', `${config.cout} ${cur} requis pour recruter cet informateur.`, false);
    return;
  }

  // Premier paiement immédiat
  state.arg -= config.cout;
  state.informateurs.push({ niveau, jourRecrutement: state.day || 1 });

  // Obtenir une info immédiatement
  const info = getInfomateurInfo(niveau);
  state.inf = Math.min(100, (state.inf || 0) + niveau);
  updateUI();

  addJournalEntry(`Informateur niveau ${niveau} recruté. -${config.cout} ${cur}.`, 'event-info');

  document.getElementById('postes-modal-title').textContent = `Informateur Niveau ${niveau} — ${config.label}`;
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1.2rem">' +
    '<div style="font-size:.75rem;color:#6a5a30;font-family:Bebas Neue,sans-serif;letter-spacing:.1em;margin-bottom:.6rem">INFORMATION REÇUE</div>' +
    '<div style="font-size:.88rem;color:#c0b090;font-style:italic;line-height:1.8;font-family:Crimson Pro,serif">"' + info + '"</div>' +
    '<div style="font-size:.68rem;color:#4a4030;margin-top:.8rem;border-top:1px solid #2a2010;padding-top:.6rem">' +
    'Source : ' + config.label + ' · +' + niveau + ' INF · Coût : ' + config.cout + ' ' + cur + '/jour · Paye lors de l\'ordre Dormir</div>' +
    '<div style="margin-top:.8rem;display:flex;gap:.5rem">' +
    '<button onclick="licencierInformateur(' + niveau + ')" style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.08em;padding:.4rem .8rem;border:1px solid #8a3a2a;background:transparent;color:#8a3a2a;cursor:pointer">Licencier</button>' +
    '<button onclick="document.getElementById(&quot;modal-postes&quot;).classList.remove(&quot;open&quot;)" style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.08em;padding:.4rem .8rem;border:1px solid #4a4030;background:transparent;color:#8a8060;cursor:pointer">Fermer</button>' +
    '</div></div>';
  document.getElementById('modal-postes').classList.add('open');
}

function licencierInformateur(niveau) {
  if (!state.informateurs) return;
  state.informateurs = state.informateurs.filter(i => i.niveau !== niveau);
  document.getElementById('modal-postes').classList.remove('open');
  showToast('Informateur licencié', `Votre informateur niveau ${niveau} est congédié.`, true);
  addJournalEntry(`Informateur niveau ${niveau} licencié.`, 'event-info');
}

function interrogerInformateur(niveau) {
  // Obtenir une nouvelle info d'un informateur déjà recruté
  if (!state.informateurs?.find(i => i.niveau === niveau)) {
    showToast('Pas d\'informateur', `Vous n'vez pas d'nformateur de niveau ${niveau} actif.`, false);
    return;
  }
  const info = getInfomateurInfo(niveau);
  state.inf = Math.min(100, (state.inf || 0) + Math.ceil(niveau / 2));
  updateUI();

  document.getElementById('postes-modal-title').textContent = `Rapport — Informateur Niveau ${niveau}`;
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1.2rem">' +
    '<div style="font-size:.88rem;color:#c0b090;font-style:italic;line-height:1.8;font-family:Crimson Pro,serif">"' + info + '"</div>' +
    '<div style="font-size:.68rem;color:#4a4030;margin-top:.8rem">+' + Math.ceil(niveau/2) + ' INF · ' + INFORMATEUR_NIVEAUX[niveau]?.label + '</div>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
  addJournalEntry(`Rapport reçu de votre informateur niveau ${niveau}.`, 'event-info');
}
function ouvrirGestionInformateurs() {
  const infos = state.informateurs || [];
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  document.getElementById('postes-modal-title').textContent = 'Mes Informateurs';
  let html = '<div style="padding:1rem">';
  if (infos.length === 0) {
    html += '<div style="font-size:.82rem;color:#6a6040;font-style:italic">Aucun informateur actif. Recrutez-en depuis les bâtiments appropriés.</div>';
  } else {
    infos.forEach((inf, i) => {
      html += '<div style="border:1px solid var(--border);background:var(--bg2);padding:.7rem;margin-bottom:.5rem;display:flex;align-items:center;justify-content:space-between">';
      html += '<div><div style="font-size:.82rem;color:#c0b090">Niveau ' + inf.niveau + ' — ' + inf.label + '</div>';
      html += '<div style="font-size:.68rem;color:#6a6040">-' + inf.cout + ' ' + cur + '/jour · Actif depuis ' + inf.joursActif + ' jour(s)</div></div>';
      html += '<button onclick="congediерInformateur(' + i + ')" style="font-family:Bebas Neue,sans-serif;font-size:.65rem;padding:.25rem .5rem;border:1px solid #8a3a2a;background:transparent;color:#8a3a2a;cursor:pointer">Congédier</button>';
      html += '</div>';
    });
  }
  html += '<div style="font-size:.7rem;color:#4a4030;margin-top:.8rem">Maximum 2 informateurs simultanés.</div>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function congediерInformateur(idx) {
  if (!state.informateurs) return;
  const inf = state.informateurs[idx];
  if (!inf) return;
  state.informateurs.splice(idx, 1);
  document.getElementById('modal-postes').classList.remove('open');
  showToast('Informateur congédié', inf.label + ' ne travaille plus pour vous.', true);
  addJournalEntry('Informateur niveau ' + inf.niveau + ' congédié.', 'event-info');
}


function doSeCacher() {
  const dis = state.char?.stats?.DIS || state.dis || 50;
  const taux = Math.max(5, 70 + Math.floor(dis/10) - getMalusISN() + 15); // +15 zone transport
  const roll = Math.floor(Math.random() * 100) + 1;
  if (roll <= taux) {
    state.estCache = true;
    showToast('Vous êtes caché(e)', 'Personne ne vous voit. Vous pouvez maintenant passer l\'ordre Assassiner ou Empoisonner.', true, true);
    addJournalEntry('Ordre Se cacher réussi. Prêt(e) pour action discrète.', 'event-info');
    // Se cache se reinitialise apres changement de piece
  } else {
    state.estCache = false;
    showToast('Échec', 'Vous n\'avez pas réussi à vous dissimuler suffisamment.', false);
  }
}

function getCurrentRoomPersons() {
  const building = BUILDINGS[state.currentBuilding];
  if (!building) return [];
  const room = building.rooms?.[state.currentRoom];
  const pnjStatiques = room?.persons || [];
  // Inclure les vrais joueurs presents (mis en cache par chargerVraisJoueursPresents)
  const vraisJoueurs = window._vraisJoueursPresents || [];
  return [...pnjStatiques, ...vraisJoueurs];
}

// Verifier effacement automatique des crimes
function checkEffacementCrimes() {
  if (!state.historiqueCrimes) return;
  const avant = state.historiqueCrimes.length;
  state.historiqueCrimes = state.historiqueCrimes.filter(c => c.expireJour > state.day);
  const apres = state.historiqueCrimes.length;
  if (avant > apres) {
    addJournalEntry('Les preuves matérielles de votre crime ont disparu. Vous ne pouvez plus être inquiété(e) pour ceci.', 'event-good');
  }
}

function ouvrirCalendrierElections() {
  const elections = state.electionsEnCours || [];
  document.getElementById('postes-modal-title').textContent = 'Calendrier électoral';
  let html = '<div style="padding:1rem">';

  // Cycle electoral
  html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.8rem;margin-bottom:.8rem">';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.5rem">CYCLE ÉLECTORAL (5-6 semaines)</div>';
  const phases = [
    { label: 'Semaines 1-3', desc: 'Mandat en cours', col: '#4a8a4a' },
    { label: 'Semaine 3', desc: 'Ouverture des candidatures', col: '#C9A84C' },
    { label: 'Semaines 4-5', desc: 'Campagne électorale — vote PJ + tracts', col: '#aa6a4a' },
    { label: 'Dimanche soir', desc: 'Résultats à minuit', col: '#6a8aaa' }
  ];
  phases.forEach(p => {
    html += '<div style="display:flex;gap:.6rem;align-items:center;margin-bottom:.3rem">';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.68rem;color:' + p.col + ';width:90px">' + p.label + '</div>';
    html += '<div style="font-size:.75rem;color:#8a8060">' + p.desc + '</div>';
    html += '</div>';
  });
  html += '</div>';

  // Elections en cours
  if (elections.length === 0) {
    html += '<div style="font-size:.85rem;color:#5a5040;font-style:italic">Aucune élection en cours ou programmée.</div>';
  } else {
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.5rem">ÉLECTIONS EN COURS / À VENIR</div>';
    elections.forEach(e => {
      const phaseCol = { candidatures:'#4a8a4a', campagne:'#C9A84C', depouillement:'#aa6a4a', termine:'#4a4030' }[e.phase] || '#8a8060';
      const phaseLabel = { candidatures:'Candidatures ouvertes', campagne:'Campagne en cours', depouillement:'Dépouillement', termine:'Terminée' }[e.phase] || e.phase;
      html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.7rem;margin-bottom:.5rem">';
      html += '<div style="display:flex;justify-content:space-between;align-items:center">';
      html += '<div style="font-family:Playfair Display,serif;font-size:.85rem;color:#E8C97A">' + e.nom + '</div>';
      html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.65rem;color:' + phaseCol + ';border:1px solid;padding:.1rem .3rem">' + phaseLabel + '</div>';
      html += '</div>';
      html += '<div style="font-size:.7rem;color:#5a4030;margin-top:.2rem">Tour ' + (e.tour||1) + ' · Résultats : Jour ' + e.jourResultat + '</div>';
      if (e.phase === 'candidatures') {
        html += '<div style="font-size:.7rem;color:#4a8a4a;margin-top:.2rem">✓ Candidatures encore acceptées</div>';
      } else if (e.phase === 'campagne') {
        html += '<div style="font-size:.7rem;color:#cc4444;margin-top:.2rem">✗ Candidatures fermées — campagne en cours</div>';
      }
      html += '</div>';
    });
  }

  // Prochaines elections prevues
  html += '<div style="font-size:.68rem;color:#4a4030;font-style:italic;margin-top:.6rem">Les candidatures ferment au début de la semaine 4. Après cette date, il n\'est plus possible de se présenter.</div>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function ouvrirGestionBudget() {
  // Reserve au Ministre des Finances
  const rep = state.repartitionBudget || { ...REPARTITION_DEFAULT };
  const noms = {
    presidence:'Presidence', min_int:'Min. Interieur', min_fin:'Min. Finances',
    min_just:'Min. Justice', min_def:'Min. Defense', min_info:'Min. Information',
    min_ae:'Min. AE', assemblee:'Assemblee', tribunal:'Tribunal',
    commissariat:'Commissariat', mairie:'Mairie', reserve:'Reserve'
  };

  document.getElementById('postes-modal-title').textContent = 'Repartition budgetaire';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Fixez le pourcentage des recettes fiscales attribue a chaque institution. Total doit etre 100%.</div>';

  let total = Object.values(rep).reduce((s, v) => s + v, 0);
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;color:' + (total === 100 ? '#4a8a4a' : '#cc4444') + ';margin-bottom:.6rem">TOTAL : ' + total + '% (doit etre 100%)</div>';

  Object.keys(rep).forEach(inst => {
    html += '<div style="display:flex;align-items:center;gap:.5rem;margin-bottom:.4rem">';
    html += '<div style="font-size:.78rem;color:#c0b090;width:120px">' + (noms[inst]||inst) + '</div>';
    html += '<input type="number" min="0" max="50" value="' + rep[inst] + '" id="budget-' + inst + '" onchange="majTotalBudget()" style="width:55px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.3rem;font-size:.82rem;outline:none">';
    html += '<span style="font-size:.72rem;color:#4a4030">%</span>';
    if (state.budgets?.[inst]) html += '<span style="font-size:.68rem;color:#5a5040;margin-left:.3rem">Solde: ' + (state.budgets[inst].solde||0).toLocaleString('fr-FR') + ' FR</span>';
    html += '</div>';
  });

  html += '<button onclick="validerRepartitionBudget()" style="margin-top:.8rem;font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Valider la repartition</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function majTotalBudget() {
  const rep = state.repartitionBudget || { ...REPARTITION_DEFAULT };
  let total = 0;
  Object.keys(rep).forEach(inst => {
    const val = parseInt(document.getElementById('budget-' + inst)?.value || '0');
    total += val;
  });
  // Mettre a jour l'affichage du total
  document.getElementById('postes-modal-title').textContent = 'Repartition — Total : ' + total + '%';
}

function validerRepartitionBudget() {
  const rep = state.repartitionBudget || { ...REPARTITION_DEFAULT };
  let total = 0;
  const newRep = {};
  Object.keys(rep).forEach(inst => {
    const val = parseInt(document.getElementById('budget-' + inst)?.value || '0');
    newRep[inst] = val;
    total += val;
  });
  if (total !== 100) {
    showToast('Total incorrect', 'Le total doit etre exactement 100%. Actuel : ' + total + '%.', false);
    return;
  }
  state.repartitionBudget = newRep;
  document.getElementById('modal-postes').classList.remove('open');
  showToast('Repartition validee !', 'Les nouveaux taux s\'appliqueront a partir de minuit.', true, true);
  addJournalEntry('Repartition budgetaire modifiee par le Ministre des Finances.', 'event-info');
  addExternalEvent('FINANCES : Nouvelle repartition budgetaire fixee par le Ministre des Finances.');
}

// =====================
// SYSTEME RELIGIEUX
// =====================
function getIP() {
  const pays = state.country || 'republic';
  if (typeof INDICES_NATIONAUX !== 'undefined' && INDICES_NATIONAUX[pays]) {
    if (!INDICES_NATIONAUX[pays].IP) INDICES_NATIONAUX[pays].IP = 40;
    return INDICES_NATIONAUX[pays].IP;
  }
  return 40;
}

function modifierIP(delta) {
  const pays = state.country || 'republic';
  if (typeof INDICES_NATIONAUX !== 'undefined' && INDICES_NATIONAUX[pays]) {
    INDICES_NATIONAUX[pays].IP = Math.max(0, Math.min(100, (INDICES_NATIONAUX[pays].IP || 40) + delta));
  }
}

const RELIGIONS = {
  republic: { nom: 'Papyrusisme', grandPretre: 'Percepteur Suprême', temple: 'Tabernacle des Impôts', peche: 'rendre un formulaire incomplet' },
  narco:    { nom: 'Cocaïsme',   grandPretre: 'Parrain Céleste',     temple: 'Laboratoire de Prière', peche: 'refuser la communion' },
  soviet:   { nom: 'Tractorisme',grandPretre: 'Camarade Pontife',    temple: 'Kolkhoze Spirituel',    peche: 'posséder un tracteur privé' },
  khalija:  { nom: 'Loukoumisme',grandPretre: 'Grand Confiseur',     temple: 'Pâtisserie Sacrée',     peche: 'refuser un loukoum offert' }
};

function doPrier() {
  const pays = state.country || 'republic';
  const religion = RELIGIONS[pays];
  modifierIP(3);
  state.moral = Math.min(100, state.moral + 2);
  updateUI();
  const msgs = {
    republic: 'Vous remplissez un formulaire en 12 exemplaires. La grâce administrative vous envahit. +3 IP +2 Moral.',
    narco:    'Vous communiez avec la Feuille Sacrée. Vous vous sentez soudainement très... éveillé. +3 IP +2 Moral.',
    soviet:   'Vous chantez l\'hymne au Tracteur Collectif. Vos camarades vous applaudissent. +3 IP +2 Moral.',
    khalija:  'Vous dégustez un loukoum divin. Goût pistache. C\'est une révélation. +3 IP +2 Moral.'
  };
  showToast('Prière accomplie', msgs[pays] || '+3 IP +2 Moral', true);
  addJournalEntry('Prière au ' + (religion?.temple || 'temple'), 'event-info');
}

function doSeConfeser() {
  const pays = state.country || 'republic';
  const religion = RELIGIONS[pays];
  state.moral = Math.min(100, state.moral + 5);
  updateUI();
  // Le pretre apprend des informations (simulation)
  const secrets = [
    'Vous avouez avoir corrompu un fonctionnaire. Le ' + religion?.grandPretre + ' note soigneusement.',
    'Vous confessez vos activités illégales. Le ' + religion?.grandPretre + ' hoche la tête d\'un air entendu.',
    'Vous révélez vos plans politiques secrets. "Intéressant", dit le ' + religion?.grandPretre + '.',
    'Vous avouez n\'avoir jamais rempli tous vos formulaires. Le ' + religion?.grandPretre + ' est scandalisé.'
  ];
  const secret = secrets[Math.floor(Math.random() * secrets.length)];
  showToast('Confession', secret + ' +5 Moral.', true);
  addJournalEntry('Confession au ' + (religion?.temple || 'temple') + '. +5 Moral.', 'event-info');
  // Risque de fuite (20%)
  if (Math.random() < 0.2) {
    setTimeout(() => addExternalEvent('RUMEUR : Des confidences faites au ' + (religion?.temple||'temple') + ' auraient été divulguées...'), 2000);
  }
}

function doFaireDon(cost) {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  if (!verifierBudgetInstitution('presidence')) {
    if (state.arg < (cost || 200)) { showToast('Fonds insuffisants', '', false); return; }
    state.arg -= (cost || 200);
  }
  modifierIP(5);
  state.pop = Math.min(100, state.pop + 3);
  updateUI();
  showToast('Don effectué', '+5 IP +3 POP. Le ' + (RELIGIONS[state.country]?.grandPretre||'Grand Prêtre') + ' vous bénit.', true);
}

function doDemanderBenediction() {
  const roll = Math.floor(Math.random() * 100) + 1;
  if (roll <= 80) {
    if (!state.benediction) state.benediction = {};
    state.benediction.actif = true;
    state.benediction.expire = state.day + 1;
    showToast('Béni !', 'Vous bénéficiez d\'un bonus de +5% sur votre prochain ordre pendant 24h.', true, true);
    addJournalEntry('Bénédiction reçue. +5% prochain ordre.', 'event-good');
  } else {
    showToast('Pas de réponse', 'Le Très-Haut est occupé. Revenez demain.', false);
  }
}

function doPelerin() {
  state.dis = Math.min(100, state.dis + 10);
  if (!state.pelerinExpire) state.pelerinExpire = state.day + 1;
  updateUI();
  showToast('Pèlerin déclaré', '+10 DIS pendant 24h. Accès facilité aux lieux saints des autres empires.', true);
  addJournalEntry('Statut de pèlerin déclaré.', 'event-info');
}

function doBenedictionEtat() {
  modifierIP(10);
  state.pop = Math.min(100, state.pop + 5);
  updateUI();
  showToast('Bénédiction d\'État', '+10 IP national. +5 POP pour le chef d\'État.', true, true);
  addExternalEvent('RELIGION : Un acte d\'État a reçu la bénédiction du ' + (RELIGIONS[state.country]?.grandPretre||'Grand Prêtre') + '.');
}

function doConsulterConfessions() {
  const confessions = [
    'Un haut fonctionnaire a avoué détourner des fonds depuis 3 ans.',
    'Un ministre a confessé ses contacts avec un empire étranger.',
    'Un député a avoué avoir vendu son vote lors du dernier scrutin.',
    'Un officier de police a confessé avoir falsifié des preuves.'
  ];
  const secret = confessions[Math.floor(Math.random() * confessions.length)];
  state.inf = Math.min(100, state.inf + 8);
  updateUI();
  document.getElementById('postes-modal-title').textContent = 'Archives des Confessions';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem"><div style="font-size:.85rem;color:#c0b090;font-style:italic;line-height:1.7">"' + secret + '"</div><div style="font-size:.7rem;color:#4a4030;margin-top:.6rem">Source : confessions scellées · +8 INF</div></div>';
  document.getElementById('modal-postes').classList.add('open');
}

function doAcheterRelique() {
  if (!state.inventory) state.inventory = [];
  state.inventory.push({ type:'relique', name:'Relique du Loukoum Sacré', icon:'ti-star', legal:true, effet:'ip+10', desc:'Accès facilité aux zones réservées d\'Al-Khalija.' });
  modifierIP(10);
  state.arg -= 500;
  updateUI();
  showToast('Relique acquise !', 'Relique du Loukoum Sacré ajoutée à votre inventaire. +10 IP.', true, true);
}

// =====================
// SCANDALES ALEATOIRES
// =====================
function declencherScandale() {
  if (typeof SCANDALES_PREDEFINIS === 'undefined' || SCANDALES_PREDEFINIS.length === 0) return;
  const scandale = SCANDALES_PREDEFINIS[Math.floor(Math.random() * SCANDALES_PREDEFINIS.length)];
  addExternalEvent('🔴 SCANDALE : ' + scandale);
  showToast('Scandale !', scandale.substring(0, 80) + '...', false);
}

// Declencher un scandale aleatoire de temps en temps (a minuit, 15% de chance)
function checkScandale() {
  if (Math.random() < 0.15) {
    declencherScandale();
  }
}

async function ouvrirRendreSentence() {
  document.getElementById('postes-modal-title').textContent = 'Rendre la sentence';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a8060;font-style:italic">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  // Charger depuis Supabase pour voir TOUTES les affaires transmises, par n'importe quel commissariat
  if (typeof sbLoadPlaintes === 'function') {
    try {
      const toutes = await sbLoadPlaintes(state.country);
      state.plaintesEnCours = toutes;
    } catch(e) {}
  }
  const affaires = state.plaintesEnCours?.filter(p => p.status === 'deposee') || [];

  let html = '<div style="padding:1rem">';
  if (affaires.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucune affaire en attente de jugement.</div>';
  } else {
    affaires.forEach((a) => {
      html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.8rem;margin-bottom:.6rem">';
      html += '<div style="font-family:Playfair Display,serif;font-size:.85rem;color:#E8C97A;margin-bottom:.3rem">Affaire : ' + a.cible + '</div>';
      html += '<div style="font-size:.72rem;color:#8a8060;margin-bottom:.6rem">' + a.motif + '</div>';
      html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.68rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.4rem">SENTENCE</div>';
      html += '<div style="display:flex;flex-direction:column;gap:.3rem">';
      html += '<button onclick="appliquerSentence(&quot;' + a.id + '&quot;,\'amende\')" style="text-align:left;padding:.4rem .7rem;border:1px solid #2a4a20;background:#0a0d05;color:#6a9a6a;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem">Amende (montant + repartition)</button>';
      html += '<button onclick="appliquerSentence(&quot;' + a.id + '&quot;,\'prison\')" style="text-align:left;padding:.4rem .7rem;border:1px solid #3a2a10;background:#0a0d05;color:#9a8a4a;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem">Prison (max 7 jours)</button>';
      html += '<button onclick="appliquerSentence(&quot;' + a.id + '&quot;,\'amenagement\')" style="text-align:left;padding:.4rem .7rem;border:1px solid #2a3a4a;background:#0a0d05;color:#6a8aaa;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem">Amenagement de peine (pointage commissariat)</button>';
      html += '<button onclick="appliquerSentence(&quot;' + a.id + '&quot;,\'qhs\')" style="text-align:left;padding:.4rem .7rem;border:1px solid #4a1a10;background:#0a0d05;color:#9a4a3a;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem">Envoi au QHS</button>';
      html += '</div></div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function appliquerSentence(affaireId, type) {
  const affaire = (state.plaintesEnCours||[]).find(p => p.id === affaireId);
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

  if (typeof sbSavePlainte === 'function') await sbSavePlainte(affaire).catch(() => {});

  document.getElementById('modal-postes').classList.remove('open');
  showToast('Sentence rendue', affaire.cible + ' : ' + details, true, true);
  addExternalEvent('JUGEMENT : ' + affaire.cible + ' condamne(e) a : ' + details + ' (Juge : ' + (state.char?.name||'PNJ') + ')');
  if (typeof sbSendMail === 'function') {
    const h = String(state.hour || 8).padStart(2,'0');
    const time = 'Jour ' + (state.day || 1) + ' · ' + h + 'h';
    sbSendMail('Tribunal', affaire.cible, 'Resultat de votre affaire', 'La sentence a ete rendue : ' + details, time).catch(() => {});
  }
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
  document.getElementById('postes-modal-title').textContent = 'Falsifier un document';
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

  document.getElementById('postes-modal-title').textContent = 'Postuler a un poste';
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
  if (state.char) state.char.poste = state.poste;
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
  document.getElementById('postes-modal-title').textContent = titre;
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
  document.getElementById('postes-modal-title').textContent = 'Gracier un condamne';
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
  document.getElementById('postes-modal-title').textContent = 'Nationaliser une entreprise';
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
  document.getElementById('postes-modal-title').textContent = titre;
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
    envoyerNotificationVraiJoueur(nomCible, 'Nomination au poste de Premier Ministre',
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
  document.getElementById('postes-modal-title').textContent = titre;
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
  document.getElementById('postes-modal-title').textContent = 'Allegement fiscal sectoriel';
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

async function ouvrirModalAffaires(mode) {
  const titre = mode === 'annuler' ? 'Annuler des poursuites' : 'Gestion judiciaire';
  document.getElementById('postes-modal-title').textContent = titre;
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a8060;font-style:italic">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  if (typeof sbLoadPlaintes === 'function') {
    try { state.plaintesEnCours = await sbLoadPlaintes(state.country); } catch(e) {}
  }
  const affaires = state.plaintesEnCours?.filter(p => p.status === 'pending') || [];
  const condamnes = state.prisonniers?.filter(p => p.jourFin > state.day) || [];

  let html = '<div style="padding:1rem">';
  const liste = mode === 'annuler' ? affaires : condamnes;
  if (liste.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucune affaire en cours.</div>';
  } else {
    liste.forEach((a) => {
      const refId = a.id || a.nom; // prisonniers n'ont pas forcement d'id, fallback sur le nom
      html += '<div style="padding:.5rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;display:flex;justify-content:space-between;align-items:center">';
      html += '<div style="font-size:.82rem;color:#c0b090">' + (a.cible||a.nom||'Inconnu') + ' <span style="font-size:.68rem;color:#5a4030">— ' + (a.motif||a.raison||'') + '</span></div>';
      html += '<button onclick="annulerAffaire(&quot;' + refId + '&quot;,\'' + mode + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.65rem;padding:.2rem .5rem;border:1px solid #8a3020;background:transparent;color:#cc4a3a;cursor:pointer">Annuler</button>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function annulerAffaire(refId, mode) {
  document.getElementById('modal-postes').classList.remove('open');
  if (mode === 'annuler') {
    const affaire = (state.plaintesEnCours||[]).find(p => p.id === refId);
    if (affaire) {
      affaire.status = 'annulee';
      if (typeof sbSavePlainte === 'function') await sbSavePlainte(affaire).catch(() => {});
      showToast('Poursuites annulees', 'La procedure a ete classee.', false);
      addJournalEntry('Annulation de poursuites par le Ministre de la Justice.', 'event-info');
    }
  }
}

function ouvrirModalNommerJuge() {
  if (state.poste?.id !== 'min_just') {
    showToast('Accès refusé', 'Seul le Ministre de la Justice peut nommer un juge.', false);
    return;
  }
  ouvrirNominerPosteNomme('juge');
}

function ouvrirModalNommerCommissaire() {
  if (state.poste?.id !== 'maire') {
    showToast('Accès refusé', 'Seul le Maire peut nommer un commissaire.', false);
    return;
  }
  ouvrirNominerPosteNomme('commissaire');
}

function ouvrirModalRenseignement() {
  const contacts = state.contacts || [];
  const empires = Object.entries(COUNTRIES).filter(([k]) => k !== state.country);
  document.getElementById('postes-modal-title').textContent = 'Operation de renseignement';
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
  document.getElementById('postes-modal-title').textContent = 'Censurer un media';
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
  document.getElementById('postes-modal-title').textContent = 'Signer un traite';
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
  document.getElementById('postes-modal-title').textContent = 'Nommer un ambassadeur';
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
  envoyerNotificationVraiJoueur(contact, 'Nomination comme ambassadeur', 'Vous avez ete nomme(e) ambassadeur(rice) aupres de ' + empireName + ' par le Ministre des Affaires Etrangeres.');
  addExternalEvent('NOMINATION : ' + contact + ' nomme(e) ambassadeur(rice) aupres de ' + empireName + '.');
  showToast('Ambassadeur nomme', contact + ' → ' + empireName, true);
}

function doReceptionAvecBonus(fn, cost) {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  // Prelever sur le budget de la Presidence, pas sur l'argent personnel
  if (!verifierBudgetInstitution('presidence')) return;

  // Bonus/malus selon popularite
  const popBonus = state.pop > 20 ? Math.floor((state.pop - 20) * 1) : -Math.floor((20 - state.pop) * 1);
  const taux = Math.min(95, Math.max(5, 80 + Math.floor(popBonus / 2)));
  const roll = Math.floor(Math.random() * 100) + 1;

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

  document.getElementById('postes-modal-title').textContent = 'Nommer des ministres';
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
  envoyerNotificationVraiJoueur(contact, 'Nomination ministerielle', 'Par decision du Premier Ministre, vous etes nomme(e) ' + posteNom + '. Prenez vos fonctions immediatement.');
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
  document.getElementById('postes-modal-title').textContent = 'Creer un poste ministeriel';
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
  document.getElementById('postes-modal-title').textContent = 'Creer un comite';
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
  document.getElementById('postes-modal-title').textContent = 'Supprimer un poste';
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

// =====================
// ANNUAIRE DES DEPUTES
// =====================
function consulterAnnuaireDeputes() {
  const country = state.country;
  const co = COUNTRIES[country];
  const titulairesConnus = state.postes?.[country] || {};

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">25 sieges a l\'Assemblee Nationale de ' + (co?.n||country) + '.</div>';
  for (let i = 1; i <= 25; i++) {
    const titulaire = titulairesConnus['depute_' + i] || 'Vacant (PNJ)';
    html += '<div style="display:flex;justify-content:space-between;padding:.4rem .2rem;border-bottom:1px solid #1a1810">';
    html += '<span style="font-size:.78rem;color:#6a5a30">Siege ' + i + '</span>';
    html += '<span style="font-size:.8rem;color:#c0b090">' + titulaire + '</span>';
    html += '</div>';
  }
  html += '</div>';
  document.getElementById('postes-modal-title').textContent = 'Annuaire des Députés';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// =====================
// OBJET TROUVE (Accueil Assemblee) — 50% de chance, kompromat potentiel
// =====================
const OBJETS_TROUVES_ASSEMBLEE = [
  { name: 'Parapluie aux couleurs du parti', icon: 'ti-umbrella', desc: 'Un parapluie noir orne du logo du parti majoritaire. Oublié dans un coin.', compromettant: false },
  { name: 'Dossier de presse périmé', icon: 'ti-file-text', desc: 'Un vieux dossier de presse évoquant vaguement un scandale jamais éclairci.', compromettant: true },
  { name: 'Petite culotte en dentelle', icon: 'ti-shirt', desc: 'Une petite culotte en dentelle noire, avec une carte de visite d\'escort glissée dedans.', compromettant: true, imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/objet-culotte-dentelle.png' },
  { name: 'Enveloppe administrative suspecte', icon: 'ti-package', desc: 'Une enveloppe officielle mal refermée, laissant voir un sachet de poudre blanche.', compromettant: true, imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/objet-sachet-poudre.png' },
  { name: 'Boîte de préservatifs entamée', icon: 'ti-heart', desc: 'Une boîte de préservatifs entamée, un numéro de téléphone griffonné au marqueur.', compromettant: true },
  { name: 'Agenda à codes ridicules', icon: 'ti-notebook', desc: 'Un agenda de poche listant des rendez-vous sous des noms de code grotesques.', compromettant: true },
  { name: 'Bouteille de whisky entamée', icon: 'ti-bottle', desc: 'Une bouteille de whisky bon marché, à moitié vide, planquée derrière un radiateur.', compromettant: false, imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/objet-whisky.png' }
];

function reclamerObjetTrouve() {
  const reussite = Math.random() < 0.5;
  if (!reussite) {
    showToast('Service des objets trouvés', 'Rien d\'intéressant aujourd\'hui. "Repassez demain", lâche l\'hôtesse des objets trouvés.', true);
    addJournalEntry('Vous avez fouillé le service des objets trouvés. Rien à signaler.', '');
    return;
  }

  const objet = OBJETS_TROUVES_ASSEMBLEE[Math.floor(Math.random() * OBJETS_TROUVES_ASSEMBLEE.length)];
  const id = 'objet-trouve-' + Date.now();

  addToInventory({
    id,
    name: objet.name,
    icon: objet.icon,
    desc: objet.desc,
    type: objet.compromettant ? 'kompromat' : 'objet',
    cible: null,
    legal: !objet.compromettant,
    imageUrl: objet.imageUrl || null
  });

  // Enregistrer le souvenir du PNJ d'accueil (qui sait que CE PJ a recupere CET objet)
  if (!state.souvenirsAccueil) state.souvenirsAccueil = [];
  const souvenir = {
    id: 'souv-' + Date.now(),
    pjNom: state.char?.name || 'Anonyme',
    objetNom: objet.name,
    jourCreation: state.day || 1,
    jourExpiration: (state.day || 1) + 12,
    revele: false
  };
  state.souvenirsAccueil.push(souvenir);

  // Persister le souvenir sur Supabase pour que les autres PJ puissent l'interroger
  if (typeof sbAjouterSouvenirAccueil === 'function') {
    sbAjouterSouvenirAccueil(souvenir).catch(() => {});
  }

  showToast('Objet trouvé !', 'Vous récupérez : ' + objet.name + '. L\'agent d\'entretien note discrètement votre nom dans son carnet...', true, true);
  addJournalEntry('Objet trouvé réclamé : ' + objet.name + '.', objet.compromettant ? 'event-bad' : 'event-good');
}

// =====================
// MODAL DE SELECTION POUR INTERROGER L'ACCUEIL
// =====================
async function ouvrirModalInterrogerAccueil() {
  document.getElementById('postes-modal-title').textContent = 'Demander des confidences';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a8060;font-style:italic">Recherche des habitants...</div>';
  document.getElementById('modal-postes').classList.add('open');

  let habitants = [];
  if (typeof sbListPersonnages === 'function') {
    try { habitants = (await sbListPersonnages() || []).filter(h => h.name !== state.char?.name); } catch(e) {}
  }

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">"Dites-moi, qui vous intéresse ?" murmure l\'agent d\'entretien avec un sourire entendu.</div>';
  if (habitants.length === 0) {
    html += '<div style="font-size:.85rem;color:#5a5040">Aucun habitant connu pour le moment.</div>';
  } else {
    html += '<select id="interroger-accueil-cible" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.8rem">';
    habitants.forEach(h => { html += '<option value="' + h.name + '">' + h.name + '</option>'; });
    html += '</select>';
    html += '<button onclick="interrogerAccueilSurObjets(document.getElementById(\'interroger-accueil-cible\').value);document.getElementById(\'modal-postes\').classList.remove(\'open\')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Demander</button>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

// =====================
// INTERROGER LE PERSONNEL D'ACCUEIL SUR LES OBJETS TROUVES
// =====================
async function interrogerAccueilSurObjets(cibleNom) {
  if (typeof sbGetSouvenirsAccueilPour !== 'function') {
    showToast('Indisponible', 'Service indisponible pour le moment.', false);
    return;
  }
  const souvenirs = await sbGetSouvenirsAccueilPour(cibleNom).catch(() => []);
  const valides = (souvenirs || []).filter(s => s.jour_expiration >= (state.day || 1));

  if (valides.length === 0) {
    showToast('Aucun souvenir', 'L\'agent d\'entretien ne se souvient de rien de particulier sur ' + cibleNom + '.', false);
    return;
  }

  const liste = valides.map(s => '— ' + s.objet_nom + ' (Jour ' + s.jour_creation + ')').join('<br>');
  showToast('Confidence obtenue', cibleNom + ' a récupéré : ' + valides.map(s => s.objet_nom).join(', '), true, true);
  addJournalEntry('L\'agent d\'entretien vous confie que ' + cibleNom + ' a récupéré ces objets :<br>' + liste, 'event-info');
}

function addToInventory(item) {
  state.inventory.push(item);
  renderInventory();
}
function renderInventory() {
  const el = document.getElementById('inv-items');
  if (!el) return;
  if (state.inventory.length === 0) {
    el.innerHTML = '<div class="inv-item-empty">Aucun objet</div>';
    return;
  }
  el.innerHTML = state.inventory.map((item, idx) => {
    const legal = item.legal === false ? '<span style="color:#cc4444;font-size:.6rem"> ⚠ Illégal</span>' : '';
    const expiry = item.expireDay ? '<div style="font-size:.6rem;color:#6a5030">Expire jour ' + item.expireDay + '</div>' : '';
    return '<div class="inv-item" style="display:flex;align-items:center;justify-content:space-between;gap:.4rem">' +
      '<div style="display:flex;align-items:center;gap:.4rem;flex:1;min-width:0;cursor:pointer" onclick="ouvrirDetailObjetInventaire(' + idx + ')">' +
        '<i class="ti ' + (item.icon||'ti-package') + '" style="font-size:.85rem;color:#8a6a20;flex-shrink:0"></i>' +
        '<div style="min-width:0">' +
          '<div style="font-size:.78rem;color:#c0b090;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">' + item.name + legal + '</div>' +
          (item.desc ? '<div style="font-size:.62rem;color:#4a4030;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">' + item.desc.substring(0,60) + (item.desc.length>60?'...':'') + '</div>' : '') +
          expiry +
        '</div>' +
      '</div>' +
      '<button onclick="supprimerItemInventaire(' + idx + ')" title="Supprimer" style="flex-shrink:0;background:none;border:1px solid #3a1a1a;color:#6a3a2a;cursor:pointer;padding:.15rem .35rem;font-size:.65rem;font-family:Bebas Neue,sans-serif">✕</button>' +
    '</div>';
  }).join('');
}

// =====================
// DETAIL D'UN OBJET D'INVENTAIRE (clic) + GESTION (donner/jeter/abandonner/supprimer)
// =====================
async function ouvrirDetailObjetInventaire(idx) {
  const item = state.inventory[idx];
  if (!item) return;

  document.getElementById('postes-modal-title').textContent = item.name;
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a8060;font-style:italic">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const legal = item.legal === false ? '<span style="color:#cc4444;font-size:.72rem"> ⚠ Objet illégal / compromettant</span>' : '';
  const imageHtml = item.imageUrl
    ? '<img src="' + item.imageUrl + '" style="width:100%;border-radius:4px;margin-bottom:.8rem;max-height:220px;object-fit:cover"/>'
    : '';

  // Charger les vrais joueurs presents pour l'option "donner"
  let joueursPresents = [];
  if (typeof sbGetPresencesInRoom === 'function' && state.currentBuilding && state.currentRoom) {
    try {
      const presents = await sbGetPresencesInRoom(state.country, state.currentCity, state.currentBuilding, state.currentRoom);
      joueursPresents = (presents || []).filter(p => p.name !== state.char?.name);
    } catch(e) {}
  }

  let html = '<div style="padding:1rem">';
  html += imageHtml;
  html += '<div style="font-size:.85rem;color:#a0a080;line-height:1.6;margin-bottom:.8rem">' + (item.desc || '') + legal + '</div>';

  html += '<div style="display:flex;flex-direction:column;gap:.4rem">';

  if (joueursPresents.length > 0) {
    html += '<select id="donner-objet-cible" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none">';
    joueursPresents.forEach(p => { html += '<option value="' + p.name + '">' + p.name + '</option>'; });
    html += '</select>';
    html += '<button onclick="donnerObjetAJoueur(' + idx + ')" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.4rem .7rem;border:1px solid #4a6aaa;background:transparent;color:#6a8aca;cursor:pointer"><i class="ti ti-gift"></i> Donner a ce joueur</button>';
  }

  html += '<button onclick="jeterObjetInventaire(' + idx + ', false)" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.4rem .7rem;border:1px solid #6a5a30;background:transparent;color:#8a8060;cursor:pointer"><i class="ti ti-trash"></i> Jeter discretement</button>';
  html += '<button onclick="jeterObjetInventaire(' + idx + ', true)" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.4rem .7rem;border:1px solid #8a6a30;background:transparent;color:#a0905a;cursor:pointer"><i class="ti ti-map-pin"></i> Abandonner ici (risque que quelqu\'un le trouve)</button>';
  html += '<button onclick="supprimerItemInventaire(' + idx + ');document.getElementById(\'modal-postes\').classList.remove(\'open\')" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.4rem .7rem;border:1px solid #6a2a20;background:transparent;color:#cc4444;cursor:pointer"><i class="ti ti-x"></i> Supprimer</button>';

  html += '</div></div>';
  document.getElementById('postes-body').innerHTML = html;
}

function donnerObjetAJoueur(idx) {
  const item = state.inventory[idx];
  const cible = document.getElementById('donner-objet-cible')?.value;
  if (!item || !cible) return;

  state.inventory.splice(idx, 1);
  renderInventory();
  document.getElementById('modal-postes').classList.remove('open');
  showToast('Objet donné', 'Vous avez donné "' + item.name + '" à ' + cible + '.', true, true);
  addJournalEntry('Vous avez donné "' + item.name + '" à ' + cible + '.', 'event-info');

  // Notifier le destinataire par mail reel
  if (typeof sbSendMail === 'function') {
    const h = String(state.hour || 8).padStart(2,'0');
    const time = 'Jour ' + (state.day || 1) + ' · ' + h + 'h';
    sbSendMail(state.char?.name || 'Anonyme', cible, 'Objet reçu',
      (state.char?.name || 'Quelqu\'un') + ' vous a remis : "' + item.name + '". ' + (item.desc || ''), time).catch(() => {});
  }
}

function jeterObjetInventaire(idx, abandonner) {
  const item = state.inventory[idx];
  if (!item) return;
  state.inventory.splice(idx, 1);
  renderInventory();
  document.getElementById('modal-postes').classList.remove('open');

  if (abandonner) {
    showToast('Objet abandonné', '"' + item.name + '" laissé sur place. Quelqu\'un pourrait le trouver...', true);
    addJournalEntry('Vous avez abandonné "' + item.name + '" sur place.', 'event-info');
    // Petite chance qu'un PNJ le remarque et que ca se sache (registre comique, sans gravite)
    if (Math.random() < 0.15) {
      addExternalEvent('👀 Un témoin affirme avoir vu ' + (state.char?.name||'quelqu\'un') + ' abandonner un objet suspect.', 'local');
    }
  } else {
    showToast('Objet jeté', '"' + item.name + '" a disparu discrètement.', true);
    addJournalEntry('Vous avez jeté "' + item.name + '" discrètement.', '');
  }
}
function toggleSection(panelId, chevronId) {
  const panel = document.getElementById(panelId);
  const chev = document.getElementById(chevronId);
  if (!panel) return;
  const open = panel.style.display !== 'none';
  panel.style.display = open ? 'none' : 'block';
  if (chev) chev.style.transform = open ? '' : 'rotate(90deg)';
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
  verifierObjectifs();
  const cur = state.char ? (COUNTRIES[state.char.country]?.cur || 'FR') : 'FR';
  // Sauvegarde auto Supabase
  if (typeof sbAutoSave === 'function' && state?.char?.name) sbAutoSave();
  renderEmployesPanel();
  // Sauvegarde localStorage — sync état complet
  if (state.char?.name) {
    state.char.poste       = state.poste || null;
    state.char.currentCity = state.currentCity || 'capitale';
    state.char.arg         = state.arg || 0;
    state.char.resources   = { inf: state.inf||0, pop: state.pop||0, dis: state.dis||50 };
    state.char.hp          = state.hp || 100;
    state.char.pa          = state.pa || 10;
    state.char.moral       = state.moral || 75;
    try {
      localStorage.setItem('respublica_char_' + state.char.name, JSON.stringify(state.char));
      localStorage.setItem('respublica_char', JSON.stringify(state.char));
    } catch(e) {}
  }
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

// =====================
// V28B — SYSTÈME DE LOCATION DE LOCAUX
// =====================

function getLocationsActives() {
  if (!state.locationsActives) state.locationsActives = [];
  return state.locationsActives;
}

function getLocationPourRoom(buildingId, roomId) {
  return getLocationsActives().find(l => l.buildingId === buildingId && l.roomId === roomId);
}

function ouvrirModalLouerLocal() {
  const buildingId = state.currentBuilding;
  const roomId = state.currentRoom;
  if (!buildingId || !roomId) return;

  const room = BUILDINGS[buildingId]?.rooms?.[roomId];
  if (!room?.locationData) { showToast('Erreur', 'Local non trouvé.', false); return; }

  const loc = room.locationData;
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  // Vérifier si déjà loué par quelqu'un
  const dejaLoue = getLocationPourRoom(buildingId, roomId);
  if (dejaLoue) {
    if (dejaLoue.locataire === state.char?.name) {
      ouvrirModalGererLocal();
    } else {
      showToast('Déjà loué', 'Ce local est occupé par ' + dejaLoue.locataire + '.', false);
    }
    return;
  }

  // Bonus formatés
  const bonusParts = [];
  if (loc.bonusPOP > 0) bonusParts.push('+' + loc.bonusPOP + ' POP');
  if (loc.bonusINF > 0) bonusParts.push('+' + loc.bonusINF + ' INF');
  if (loc.bonusDIS > 0) bonusParts.push('+' + loc.bonusDIS + ' DIS');
  const bonusStr = bonusParts.join(' · ') || 'Aucun bonus direct';

  // Organisations disponibles
  const mesOrgas = (getMesOrgasPays()).filter(o =>
    o.membres?.some(m => m.nom === state.char?.name)
  );

  let orgaSelect = '<div style="font-size:.72rem;color:#4a4030;font-style:italic">Aucune organisation — fondez-en une pour bénéficier des bonus.</div>';
  if (mesOrgas.length > 0) {
    orgaSelect = '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.3rem">ASSOCIER À UNE ORGANISATION</div>' +
      '<select id="loc-orga-select" style="width:100%;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;padding:.4rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.6rem">' +
      '<option value="">— Aucune organisation —</option>' +
      mesOrgas.map(o => '<option value="' + o.id + '">' + o.nom + '</option>').join('') +
      '</select>';
  }

  document.getElementById('postes-modal-title').textContent = '📋 Louer : ' + loc.label;
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +
    '<div style="font-size:.78rem;color:#a09060;font-style:italic;margin-bottom:.7rem;border-left:2px solid #3a2a10;padding-left:.6rem">' + (room.desc || '') + '</div>' +
    '<div style="display:grid;grid-template-columns:1fr 1fr;gap:.4rem;margin-bottom:.7rem">' +
      '<div style="background:#0a0805;border:1px solid #1a1810;padding:.5rem;text-align:center">' +
        '<div style="font-size:.62rem;color:#4a4030">LOYER / JOUR</div>' +
        '<div style="font-family:Bebas Neue,sans-serif;font-size:1.1rem;color:#C9A84C">' + loc.prix.toLocaleString('fr-FR') + ' ' + cur + '</div>' +
      '</div>' +
      '<div style="background:#0a0805;border:1px solid #1a1810;padding:.5rem;text-align:center">' +
        '<div style="font-size:.62rem;color:#4a4030">BONUS ORGANISATION</div>' +
        '<div style="font-size:.78rem;color:#4a8a4a;margin-top:.2rem">' + bonusStr + '</div>' +
      '</div>' +
    '</div>' +
    orgaSelect +
    '<div style="font-size:.7rem;color:#6a5a30;margin-bottom:.7rem">Le premier loyer est prélevé immédiatement. Ensuite, chaque réveil.</div>' +
    '<button onclick="confirmerLocation()" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">🔑 Signer le bail</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerLocation() {
  const buildingId = state.currentBuilding;
  const roomId = state.currentRoom;
  const room = BUILDINGS[buildingId]?.rooms?.[roomId];
  if (!room?.locationData) return;

  const loc = room.locationData;
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const orgaId = document.getElementById('loc-orga-select')?.value || '';

  if (state.arg < loc.prix) {
    showToast('Fonds insuffisants', loc.prix + ' ' + cur + ' requis pour le premier loyer.', false);
    return;
  }

  state.arg -= loc.prix;
  if (!state.locationsActives) state.locationsActives = [];

  state.locationsActives.push({
    buildingId, roomId,
    localLabel: loc.label,
    batimentLabel: BUILDINGS[buildingId]?.shortName || buildingId,
    prix: loc.prix,
    bonusPOP: loc.bonusPOP || 0,
    bonusINF: loc.bonusINF || 0,
    bonusDIS: loc.bonusDIS || 0,
    orgaId,
    locataire: state.char?.name,
    country: state.country,
    depuis: state.day || 1,
    visible: true
  });

  document.getElementById('modal-postes').classList.remove('open');
  updateUI();

  const bonusParts = [];
  if (loc.bonusPOP > 0) bonusParts.push('+' + loc.bonusPOP + ' POP');
  if (loc.bonusINF > 0) bonusParts.push('+' + loc.bonusINF + ' INF');
  if (loc.bonusDIS > 0) bonusParts.push('+' + loc.bonusDIS + ' DIS');

  showToast('Bail signé !', loc.label + ' loué. -' + loc.prix + ' ' + cur + '/jour.' + (bonusParts.length ? ' ' + bonusParts.join(' · ') : ''), true, true);
  addJournalEntry('Location signée : ' + loc.label + ' (' + (BUILDINGS[buildingId]?.shortName || buildingId) + '). -' + loc.prix + ' ' + cur + '/jour.', 'event-good');

  // Recharger la pièce pour afficher "Gérer mon local"
  if (state.currentRoom) enterRoom(buildingId, roomId, null);
}

function ouvrirModalGererLocal() {
  const buildingId = state.currentBuilding;
  const roomId = state.currentRoom;
  const location = getLocationPourRoom(buildingId, roomId);

  if (!location || location.locataire !== state.char?.name) {
    showToast('Non locataire', 'Vous ne louez pas ce local.', false);
    return;
  }

  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const mesOrgas = (getMesOrgasPays()).filter(o =>
    o.membres?.some(m => m.nom === state.char?.name)
  );

  const bonusParts = [];
  if (location.bonusPOP > 0) bonusParts.push('+' + location.bonusPOP + ' POP');
  if (location.bonusINF > 0) bonusParts.push('+' + location.bonusINF + ' INF');
  if (location.bonusDIS > 0) bonusParts.push('+' + location.bonusDIS + ' DIS');

  const orgaActuelle = mesOrgas.find(o => o.id === location.orgaId);

  let orgaSelect = '';
  if (mesOrgas.length > 0) {
    orgaSelect = '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.1em;color:#8a6a20;margin:.6rem 0 .3rem">ORGANISATION ASSOCIÉE</div>' +
      '<select id="gerer-orga-select" style="width:100%;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;padding:.4rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.5rem">' +
      '<option value="">— Aucune —</option>' +
      mesOrgas.map(o => '<option value="' + o.id + '"' + (o.id === location.orgaId ? ' selected' : '') + '>' + o.nom + '</option>').join('') +
      '</select>' +
      '<button onclick="changerOrgaLocation()" style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.08em;padding:.3rem .8rem;border:1px solid #4a6a4a;background:transparent;color:#6a9a6a;cursor:pointer;margin-bottom:.5rem">Mettre à jour</button>';
  }

  document.getElementById('postes-modal-title').textContent = '⚙️ ' + location.localLabel;
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +
    '<div style="display:grid;grid-template-columns:1fr 1fr;gap:.4rem;margin-bottom:.6rem">' +
      '<div style="background:#0a0805;border:1px solid #1a1810;padding:.5rem;text-align:center">' +
        '<div style="font-size:.62rem;color:#4a4030">LOYER / JOUR</div>' +
        '<div style="font-family:Bebas Neue,sans-serif;font-size:1rem;color:#C9A84C">' + location.prix.toLocaleString('fr-FR') + ' ' + cur + '</div>' +
      '</div>' +
      '<div style="background:#0a0805;border:1px solid #1a1810;padding:.5rem;text-align:center">' +
        '<div style="font-size:.62rem;color:#4a4030">BONUS ACTIFS</div>' +
        '<div style="font-size:.72rem;color:#4a8a4a;margin-top:.2rem">' + (bonusParts.join(' · ') || 'Aucun') + '</div>' +
      '</div>' +
    '</div>' +
    '<div style="font-size:.72rem;color:#6a5a30;margin-bottom:.4rem">Loué depuis le Jour ' + location.depuis + ' · ' + (location.batimentLabel || '') + '</div>' +
    '<div style="font-size:.72rem;color:' + (orgaActuelle ? '#4a8a4a' : '#6a5a30') + ';margin-bottom:.5rem">Organisation : ' + (orgaActuelle ? orgaActuelle.nom : 'Aucune') + '</div>' +
    orgaSelect +
    '<div style="margin-bottom:.6rem">' +
      '<button onclick="ouvrirCreerOrga()" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.4rem;border:1px solid #4a6a4a;background:transparent;color:#6a9a6a;cursor:pointer"><i class=\"ti ti-building\" style=\"font-size:.8rem\"></i> Créer une organisation ici</button>' +
    '</div>' +
    '<div style="display:flex;gap:.4rem;margin-top:.6rem">' +
      '<button onclick="toggleVisibiliteLocation()" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.06em;padding:.35rem;border:1px solid #3a4a5a;background:transparent;color:#6a8aaa;cursor:pointer">' +
        (location.visible ? '👁 Masquer' : '👁 Afficher') + ' sur le plan' +
      '</button>' +
      '<button onclick="resilierBail()" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.06em;padding:.35rem;border:1px solid #5a2a2a;background:transparent;color:#8a3a2a;cursor:pointer">❌ Résilier le bail</button>' +
    '</div>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

function changerOrgaLocation() {
  const buildingId = state.currentBuilding;
  const roomId = state.currentRoom;
  const location = getLocationPourRoom(buildingId, roomId);
  if (!location) return;
  const newOrgaId = document.getElementById('gerer-orga-select')?.value || '';
  location.orgaId = newOrgaId;
  const orga = getOrgaById(newOrgaId);
  showToast('Organisation mise à jour', orga ? orga.nom + ' associée à ce local.' : 'Aucune organisation associée.', true);
  addJournalEntry('Organisation du local ' + location.localLabel + ' mise à jour.', '');
}

function toggleVisibiliteLocation() {
  const buildingId = state.currentBuilding;
  const roomId = state.currentRoom;
  const location = getLocationPourRoom(buildingId, roomId);
  if (!location) return;
  location.visible = !location.visible;
  document.getElementById('modal-postes').classList.remove('open');
  showToast(location.visible ? 'Local visible' : 'Local masqué', location.visible ? 'Votre local apparaît sur le plan de ville.' : 'Votre local est discret.', true);
}

function resilierBail() {
  const buildingId = state.currentBuilding;
  const roomId = state.currentRoom;
  const idx = (state.locationsActives || []).findIndex(l => l.buildingId === buildingId && l.roomId === roomId);
  if (idx < 0) return;

  const location = state.locationsActives[idx];
  document.getElementById('modal-postes').classList.remove('open');

  // Confirmation
  document.getElementById('postes-modal-title').textContent = 'Résilier le bail ?';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1rem">' +
    '<div style="font-size:.85rem;color:#c0b090;margin-bottom:.8rem">Vous allez résilier votre bail sur <strong>' + location.localLabel + '</strong>. Cette action est irréversible.</div>' +
    '<div style="display:flex;gap:.5rem">' +
      '<button onclick="confirmerResiliation(' + idx + ')" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem;border:1px solid #8a3a2a;background:transparent;color:#cc4444;cursor:pointer">Confirmer la résiliation</button>' +
      '<button onclick="fermerModalPostes()" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem;border:1px solid #2a2010;background:transparent;color:#6a5a30;cursor:pointer">Annuler</button>' +
    '</div></div>';
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerResiliation(idx) {
  if (!state.locationsActives?.[idx]) return;
  const location = state.locationsActives[idx];
  state.locationsActives.splice(idx, 1);
  document.getElementById('modal-postes').classList.remove('open');
  showToast('Bail résilié', location.localLabel + ' libéré.', false);
  addJournalEntry('Bail résilié : ' + location.localLabel + '.', 'event-info');
  if (state.currentRoom) enterRoom(state.currentBuilding, state.currentRoom, null);
}

// Paiement des loyers au réveil
function payerLocations() {
  const locations = state.locationsActives || [];
  if (locations.length === 0) return;

  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const pays = state.country || 'republic';
  const toExpulse = [];

  locations.forEach((loc, i) => {
    if (loc.locataire !== state.char?.name) return; // Pas notre location

    if (state.arg >= loc.prix) {
      state.arg -= loc.prix;
      addJournalEntry('Loyer payé : ' + loc.localLabel + ' -' + loc.prix + ' ' + cur, 'event-info');

      // Appliquer les bonus à l'organisation associée
      if (loc.orgaId) {
        appliquerBonusLocation(loc);
      }
    } else {
      // Fonds insuffisants — mail d'avertissement J1, expulsion J2
      if (!loc.avertissement) {
        loc.avertissement = true;
        addMailNotification('Gestionnaire immobilier', 'Loyer impayé — ' + loc.localLabel,
          'Votre loyer de ' + loc.prix + ' ' + cur + ' pour ' + loc.localLabel + ' n\'a pas pu etre preleve. Regularisez sous 24h ou vous serez expulse(e).');
        addJournalEntry('⚠️ Loyer impayé : ' + loc.localLabel + '. Avertissement envoyé.', 'event-bad');
      } else {
        // Deuxième défaut → expulsion
        toExpulse.push(i);
      }
    }
  });

  // Traiter les expulsions en ordre inverse
  toExpulse.reverse().forEach(i => expulserLocataire(i));
}

function appliquerBonusLocation(loc) {
  const orga = getOrgaById(loc.orgaId);
  if (!orga) return;

  // Stocker les bonus dans l'orga
  if (!orga.bonusLocaux) orga.bonusLocaux = { pop: 0, inf: 0, dis: 0 };
  orga.bonusLocaux.pop = (orga.bonusLocaux.pop || 0) + (loc.bonusPOP || 0);
  orga.bonusLocaux.inf = (orga.bonusLocaux.inf || 0) + (loc.bonusINF || 0);
  orga.bonusLocaux.dis = (orga.bonusLocaux.dis || 0) + (loc.bonusDIS || 0);

  // Appliquer au joueur (fraction des bonus)
  const mult = 0.3; // 30% des bonus de l'orga profitent directement au chef
  const estChef = orga.chef === state.char?.name;
  if (estChef) {
    if (loc.bonusPOP > 0) state.pop = Math.min(100, (state.pop || 0) + Math.floor(loc.bonusPOP * mult));
    if (loc.bonusINF > 0) state.inf = Math.min(100, (state.inf || 0) + Math.floor(loc.bonusINF * mult));
    if (loc.bonusDIS > 0) state.dis = Math.min(100, (state.dis || 50) + Math.floor(loc.bonusDIS * mult));
  }
}

function expulserLocataire(idx) {
  if (!state.locationsActives?.[idx]) return;
  const loc = state.locationsActives[idx];
  const pays = state.country || 'republic';

  // Message d'expulsion selon empire
  const msgs = {
    republic: 'Maître Huissier Formulaire vous signifie votre expulsion du local "' + loc.localLabel + '". Vous avez quitté les lieux conformément à la procédure 47-B.',
    narco:    'Deux messieurs d\'El Don ont recupere les cles de "' + loc.localLabel + '". Sans discussion. Bonne journée.',
    soviet:   'Le Camarade Gestionnaire a redistribue votre local ' + loc.localLabel + ' au collectif. Loi du Parti.',
    khalija:  'Par decret du Sheikh, votre occupation de ' + loc.localLabel + ' prend fin immediatement.'
  };

  state.locationsActives.splice(idx, 1);
  addMailNotification('Gestionnaire immobilier', 'Expulsion — ' + loc.localLabel, msgs[pays] || msgs.republic);
  addExternalEvent('🏢 ' + (state.char?.name || 'Anonyme') + ' a été expulsé(e) de "' + loc.localLabel + '" pour loyer impayé.');
  addJournalEntry('Expulsion : ' + loc.localLabel + ' perdu pour loyer impayé.', 'event-bad');
}

// Vue d'ensemble des locations actives
function ouvrirMesLocations() {
  const locations = (state.locationsActives || []).filter(l => l.locataire === state.char?.name);
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  document.getElementById('postes-modal-title').textContent = '🏢 Mes Locations';

  if (locations.length === 0) {
    document.getElementById('postes-body').innerHTML =
      '<div style="padding:1rem;font-size:.85rem;color:#4a4030;font-style:italic">Vous ne louez aucun local actuellement. Rendez-vous dans un Centre Commercial, Artisanal ou d\'Affaires.</div>';
    document.getElementById('modal-postes').classList.add('open');
    return;
  }

  const totalLoyer = locations.reduce((s, l) => s + l.prix, 0);
  const html = locations.map((loc, i) => {
    const bonusParts = [];
    if (loc.bonusPOP > 0) bonusParts.push('+' + loc.bonusPOP + ' POP');
    if (loc.bonusINF > 0) bonusParts.push('+' + loc.bonusINF + ' INF');
    if (loc.bonusDIS > 0) bonusParts.push('+' + loc.bonusDIS + ' DIS');
    const orga = getOrgaById(loc.orgaId);

    return '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.7rem;margin-bottom:.5rem">' +
      '<div style="display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:.3rem">' +
        '<div>' +
          '<div style="font-family:Bebas Neue,sans-serif;font-size:.82rem;color:#C9A84C">' + loc.localLabel + '</div>' +
          '<div style="font-size:.68rem;color:#6a5a30">' + (loc.batimentLabel || '') + ' · Depuis Jour ' + loc.depuis + '</div>' +
        '</div>' +
        '<div style="text-align:right">' +
          '<div style="font-family:Bebas Neue,sans-serif;font-size:.82rem;color:#c0b090">' + loc.prix + ' ' + cur + '/jour</div>' +
          '<div style="font-size:.65rem;color:#4a8a4a">' + (bonusParts.join(' · ') || '') + '</div>' +
        '</div>' +
      '</div>' +
      '<div style="font-size:.68rem;color:' + (orga ? '#4a8a4a' : '#4a4030') + ';margin-bottom:.4rem">Organisation : ' + (orga ? orga.nom : 'Aucune') + '</div>' +
      '<button onclick="confirmerResiliation(' + i + ')" style="font-family:Bebas Neue,sans-serif;font-size:.65rem;padding:.2rem .5rem;border:1px solid #5a2a2a;background:transparent;color:#8a3a2a;cursor:pointer">Résilier</button>' +
      '</div>';
  }).join('');

  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.6rem 1rem">' +
    '<div style="font-size:.72rem;color:#8a6a20;margin-bottom:.6rem;font-family:Bebas Neue,sans-serif;letter-spacing:.08em">TOTAL LOYERS : ' + totalLoyer.toLocaleString('fr-FR') + ' ' + cur + '/JOUR</div>' +
    html + '</div>';
  document.getElementById('modal-postes').classList.add('open');
}


// =====================
// V29B — SYSTÈME D'ORGANISATIONS
// =====================

// ------ CRÉATION ------

function ouvrirCreerOrga() {
  const mesOrgas = getMesOrgasPays();
  const typesDispos = Object.entries(TYPES_ORGANISATIONS).filter(([type, def]) => {
    // Vérifier qu'on n'a pas déjà créé une orga de ce type
    return !mesOrgas.some(o => o.type === type && o.fondateur === state.char?.name);
  });

  if (typesDispos.length === 0) {
    showToast('Maximum atteint', 'Vous avez déjà fondé une organisation de chaque type.', false);
    return;
  }

  document.getElementById('postes-modal-title').textContent = '🏛 Créer une Organisation';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +
    '<div style="font-size:.75rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Choisissez le type d\'organisation à fonder. Vous ne pouvez fonder qu\'une organisation de chaque type.</div>' +
    typesDispos.map(([type, def]) =>
      '<div onclick="ouvrirFormulaireOrga(\'' + type + '\')" style="display:flex;align-items:center;gap:.8rem;padding:.6rem .8rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;cursor:pointer" onmouseover="this.style.background=\'#151005\'" onmouseout="this.style.background=\'#0f0d05\'">' +
        '<i class="ti ' + def.icon + '" style="font-size:1.1rem;color:#C9A84C;flex-shrink:0"></i>' +
        '<div>' +
          '<div style="font-family:Bebas Neue,sans-serif;font-size:.82rem;color:#E8C97A;letter-spacing:.06em">' + def.label + '</div>' +
          '<div style="font-size:.68rem;color:#4a4030">' + (def.secret ? '🔒 Secrète · ' : '') + 'Requis : ' + formatReqOrga(def.requis) + '</div>' +
        '</div>' +
      '</div>'
    ).join('') +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

function formatReqOrga(requis) {
  if (!requis) return 'Aucun';
  return Object.entries(requis).map(([k, v]) => {
    if (k === 'arg') return v.toLocaleString('fr-FR') + ' FR';
    return k.toUpperCase() + ' ≥ ' + v;
  }).join(', ');
}

function ouvrirFormulaireOrga(type) {
  const def = TYPES_ORGANISATIONS[type];
  if (!def) return;
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  // Vérifier conditions
  const requis = def.requis || {};
  let blocage = null;
  if (requis.pop && (state.pop || 0) < requis.pop) blocage = 'POP insuffisante (' + (state.pop||0) + '/' + requis.pop + ')';
  if (requis.inf && (state.inf || 0) < requis.inf) blocage = 'INF insuffisante (' + (state.inf||0) + '/' + requis.inf + ')';
  if (requis.dis && (state.dis || 0) < requis.dis) blocage = 'DIS insuffisante (' + (state.dis||0) + '/' + requis.dis + ')';
  if (requis.arg && state.arg < requis.arg) blocage = 'Fonds insuffisants (' + state.arg.toLocaleString('fr-FR') + '/' + requis.arg.toLocaleString('fr-FR') + ' ' + cur + ')';

  document.getElementById('postes-modal-title').textContent = 'Fonder : ' + def.label;
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +
    (blocage ? '<div style="background:#1a0808;border:1px solid #5a1a1a;padding:.6rem;margin-bottom:.7rem;font-size:.78rem;color:#cc4444">⛔ ' + blocage + '</div>' : '') +
    '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.3rem">NOM DE L\'ORGANISATION</div>' +
    '<input id="orga-nom-input" type="text" maxlength="40" placeholder="Ex: Loge du Grand Nord, Parti du Progrès..." style="width:100%;padding:.4rem .6rem;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;font-family:Crimson Pro,serif;font-size:.9rem;box-sizing:border-box;margin-bottom:.6rem"/>' +
    '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.3rem">DESCRIPTION (optionnel)</div>' +
    '<textarea id="orga-desc-input" maxlength="200" placeholder="Décrivez votre organisation en quelques mots..." style="width:100%;padding:.4rem .6rem;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;font-family:Crimson Pro,serif;font-size:.85rem;box-sizing:border-box;resize:none;height:60px;margin-bottom:.7rem"></textarea>' +
    '<button onclick="confirmerCreationOrga(\'' + type + '\')" ' + (blocage ? 'disabled style="opacity:.4;cursor:not-allowed"' : '') + ' style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">🏛 Fonder cette organisation</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerCreationOrga(type) {
  const def = TYPES_ORGANISATIONS[type];
  if (!def) return;
  const nom = document.getElementById('orga-nom-input')?.value?.trim();
  const desc = document.getElementById('orga-desc-input')?.value?.trim() || '';

  if (!nom || nom.length < 2) { showToast('Nom requis', 'Donnez un nom à votre organisation.', false); return; }

  const id = 'orga_' + Date.now();
  const grades = def.grades?.[state.country] || ['Membre', 'Cadre', 'Dirigeant', 'Chef'];
  const monGrade = grades[grades.length - 1]; // Fondateur = grade max

  if (!state.organisations) state.organisations = [];

  const nouvelleOrga = {
    id, type, nom, desc,
    fondateur: state.char?.name,
    chef: state.char?.name,
    country: state.country,
    country_origine: state.country,
    creeLe: state.day || 1,
    membres: [{ nom: state.char?.name, grade: monGrade, gradeIdx: grades.length - 1, rejointLe: state.day || 1 }],
    demandesAdhesion: [],
    bonusLocaux: { pop: 0, inf: 0, dis: 0 },
    caisse: 0,
    localId: state.currentBuilding + ':' + state.currentRoom,
    visible: !def.secret,
  };

  state.organisations.push(nouvelleOrga);
  if (typeof sbSaveOrganisation === 'function') sbSaveOrganisation(nouvelleOrga).catch(() => {});

  // Lier au local en cours si on vient de gerer_local
  const location = (state.locationsActives || []).find(l =>
    l.buildingId === state.currentBuilding && l.locataire === state.char?.name
  );
  if (location) location.orgaId = id;

  document.getElementById('modal-postes').classList.remove('open');
  updateUI();
  showToast('Organisation fondée !', '"' + nom + '" est née. Vous en êtes le ' + monGrade + '.', true, true);
  addJournalEntry('Fondation de "' + nom + '" (' + def.label + ').', 'event-good');
  addExternalEvent('🏛 ' + (state.char?.name || 'Anonyme') + ' fonde "' + nom + '", une nouvelle ' + def.label + '.');
}

// ------ ONGLET ORGAS ------

function renderOngletOrgas() {
  const mesOrgas = (getMesOrgasPays()).filter(o =>
    o.membres?.some(m => m.nom === state.char?.name)
  );
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  if (mesOrgas.length === 0) {
    return '<div style="padding:1.5rem;text-align:center;color:#4a4030;font-style:italic;font-size:.85rem">' +
      '<i class="ti ti-building-community" style="font-size:2rem;color:#2a2010;display:block;margin-bottom:.8rem"></i>' +
      'Vous n\'appartenez a aucune organisation.<br>' +
      '<span style="font-size:.75rem">Louez un local et creez votre organisation depuis "Gerer mon local".</span>' +
      '</div>';
  }

  return mesOrgas.map(orga => {
    const def = TYPES_ORGANISATIONS[orga.type] || {};
    const estChef = orga.chef === state.char?.name;
    const monMembre = orga.membres?.find(m => m.nom === state.char?.name);
    const demandesCount = (orga.demandesAdhesion || []).length;
    const avatar = orga.avatar || '';

    return '<div style="border:1px solid #2a2010;background:#0f0d05;margin-bottom:.8rem">' +

      '<div style="padding:.8rem 1rem;border-bottom:1px solid #1a1208;display:flex;align-items:center;gap:.7rem">' +
        (avatar ? '<img src="' + avatar + '" style="width:36px;height:36px;border-radius:50%;object-fit:cover;border:1px solid #3a2a10"/>' :
          '<div style="width:36px;height:36px;border-radius:50%;background:#1a1208;display:flex;align-items:center;justify-content:center"><i class="ti ' + (def.icon||'ti-users') + '" style="font-size:1rem;color:#C9A84C"></i></div>') +
        '<div style="flex:1;min-width:0">' +
          '<div style="font-family:Bebas Neue,sans-serif;font-size:.92rem;color:#E8C97A;letter-spacing:.06em">' + orga.nom + '</div>' +
          '<div style="font-size:.68rem;color:#6a5a30">' + (def.label||'') + ' · ' + (monMembre?.grade||'') + (estChef ? ' 👑' : '') + ' · ' + (orga.membres?.length||0) + ' membres</div>' +
          (orga.devise ? '<div style="font-size:.65rem;color:#4a4030;font-style:italic">"' + orga.devise + '"</div>' : '') +
        '</div>' +
        '<div style="font-family:Bebas Neue,sans-serif;font-size:.75rem;color:#C9A84C">' + (orga.caisse||0).toLocaleString('fr-FR') + ' ' + cur + '</div>' +
      '</div>' +

      '<div style="padding:.5rem .8rem;display:flex;flex-wrap:wrap;gap:.35rem;border-bottom:1px solid #1a1208">' +
        '<button onclick="ouvrirForumDepuisOrga()" style="font-family:Bebas Neue,sans-serif;font-size:.65rem;letter-spacing:.06em;padding:.3rem .6rem;border:1px solid #1a3a1a;background:transparent;color:#4a7a4a;cursor:pointer">📋 Forum</button>' +
        '<button onclick="ouvrirMailOrga(\'' + orga.id + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.65rem;letter-spacing:.06em;padding:.3rem .6rem;border:1px solid #1a2a3a;background:transparent;color:#4a6a8a;cursor:pointer">✉️ Courrier</button>' +
        '<button onclick="ouvrirOrdresOrga(\'' + orga.id + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.65rem;letter-spacing:.06em;padding:.3rem .6rem;border:1px solid #2a2a3a;background:transparent;color:#6a6aaa;cursor:pointer">⚡ Actions</button>' +
      '</div>' +

      (estChef ?
        '<div style="padding:.5rem .8rem;display:flex;flex-wrap:wrap;gap:.35rem;border-bottom:1px solid #1a1208">' +
          '<button onclick="ouvrirGestionMembres(\'' + orga.id + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.65rem;letter-spacing:.06em;padding:.3rem .6rem;border:1px solid #2a3a2a;background:transparent;color:#6a9a6a;cursor:pointer">👥 Membres</button>' +
          (demandesCount > 0 ?
            '<button onclick="ouvrirDemandesAdhesion(\'' + orga.id + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.65rem;letter-spacing:.06em;padding:.3rem .6rem;border:1px solid #4a3a1a;background:transparent;color:#C9A84C;cursor:pointer">📨 Candidatures (' + demandesCount + ')</button>' :
            '<button disabled style="font-family:Bebas Neue,sans-serif;font-size:.65rem;padding:.3rem .6rem;border:1px solid #1a1a10;background:transparent;color:#3a3020;cursor:not-allowed">📨 Aucune candidature</button>'
          ) +
          '<button onclick="ouvrirOptionsOrga(\'' + orga.id + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.65rem;letter-spacing:.06em;padding:.3rem .6rem;border:1px solid #3a2a10;background:transparent;color:#8a6a20;cursor:pointer">⚙️ Parametres</button>' +
        '</div>'
      : '') +

      (!estChef ?
        '<div style="padding:.4rem .8rem">' +
           '<button onclick="quitterOrga(\'' + orga.id + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.65rem;padding:.25rem .5rem;border:1px solid #3a1a1a;background:transparent;color:#6a3a2a;cursor:pointer">Quitter cette organisation</button>' +
        '</div>'
      : '') +

    '</div>';
  }).join('');
}

// ------ MEMBRES ------

function ouvrirGestionMembres(orgaId) {
  const orga = getOrgaById(orgaId);
  if (!orga) return;
  const def = TYPES_ORGANISATIONS[orga.type] || {};
  const grades = def.grades?.[state.country] || ['Membre', 'Cadre', 'Dirigeant', 'Chef'];
  const estChef = orga.chef === state.char?.name;

  document.getElementById('postes-modal-title').textContent = '👥 ' + orga.nom + ' — Membres';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.6rem 1rem">' +
    orga.membres.map(m =>
      '<div style="display:flex;align-items:center;gap:.6rem;padding:.5rem 0;border-bottom:1px solid #1a1208">' +
        '<i class="ti ti-user" style="font-size:.9rem;color:#8a6a20;flex-shrink:0"></i>' +
        '<div style="flex:1">' +
          '<div style="font-size:.82rem;color:#c0b090">' + m.nom + (m.nom === orga.chef ? ' 👑' : '') + '</div>' +
          '<div style="font-size:.65rem;color:#6a5a30">' + m.grade + ' · Depuis Jour ' + m.rejointLe + '</div>' +
        '</div>' +
        (estChef && m.nom !== state.char?.name ?
          '<div style="display:flex;gap:.3rem">' +
            '<button onclick="monterGrade(\'' + orgaId + '\',\'' + m.nom + '\')" title="Monter en grade" style="background:none;border:1px solid #2a3a2a;color:#4a8a4a;cursor:pointer;padding:.2rem .4rem;font-size:.65rem">▲</button>' +
            '<button onclick="descendreGrade(\'' + orgaId + '\',\'' + m.nom + '\')" title="Descendre en grade" style="background:none;border:1px solid #3a2a1a;color:#8a4a2a;cursor:pointer;padding:.2rem .4rem;font-size:.65rem">▼</button>' +
            '<button onclick="exclureMembre(\'' + orgaId + '\',\'' + m.nom + '\')" title="Exclure" style="background:none;border:1px solid #3a1a1a;color:#cc4444;cursor:pointer;padding:.2rem .4rem;font-size:.65rem">✕</button>' +
          '</div>'
        : '') +
      '</div>'
    ).join('') +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

function monterGrade(orgaId, nomMembre) {
  const orga = getOrgaById(orgaId);
  if (!orga) return;
  const def = TYPES_ORGANISATIONS[orga.type] || {};
  const grades = def.grades?.[state.country] || ['Membre', 'Cadre', 'Dirigeant', 'Chef'];
  const membre = orga.membres.find(m => m.nom === nomMembre);
  if (!membre || membre.gradeIdx >= grades.length - 1) return;
  membre.gradeIdx++;
  membre.grade = grades[membre.gradeIdx];
  showToast('Grade attribué', nomMembre + ' est maintenant ' + membre.grade + '.', true);
  sauvegarderOrga(orga);
  ouvrirGestionMembres(orgaId);
}

function descendreGrade(orgaId, nomMembre) {
  const orga = getOrgaById(orgaId);
  if (!orga) return;
  const def = TYPES_ORGANISATIONS[orga.type] || {};
  const grades = def.grades?.[state.country] || ['Membre', 'Cadre', 'Dirigeant', 'Chef'];
  const membre = orga.membres.find(m => m.nom === nomMembre);
  if (!membre || membre.gradeIdx <= 0) return;
  membre.gradeIdx--;
  membre.grade = grades[membre.gradeIdx];
  showToast('Grade retiré', nomMembre + ' est maintenant ' + membre.grade + '.', false);
  sauvegarderOrga(orga);
  ouvrirGestionMembres(orgaId);
}

function exclureMembre(orgaId, nomMembre) {
  const orga = getOrgaById(orgaId);
  if (!orga) return;
  orga.membres = orga.membres.filter(m => m.nom !== nomMembre);
  showToast('Membre exclu', nomMembre + ' a été exclu de ' + orga.nom + '.', false);
  addJournalEntry(nomMembre + ' exclu de "' + orga.nom + '".', 'event-bad');
  sauvegarderOrga(orga);
  ouvrirGestionMembres(orgaId);
}

// ------ DEMANDES D'ADHÉSION ------

function demanderAdhesion(orgaId) {
  // Recherche directe dans la liste plate (fonctionne deja nativement multi-empire)
  let orga = getOrgaById(orgaId);
  if (!orga) return;
  const def = TYPES_ORGANISATIONS[orga.type] || {};

  // Vérif : déjà membre ?
  if (orga.membres?.some(m => m.nom === state.char?.name)) {
    showToast('Déjà membre', 'Vous êtes déjà membre de cette organisation.', false); return;
  }
  // Vérif : déjà une orga de ce type en adhésion ?
  const mesOrgas = getMesOrgasPays();
  const dejaType = mesOrgas.some(o => o.type === orga.type && o.membres?.some(m => m.nom === state.char?.name));
  if (dejaType) {
    showToast('Limite atteinte', 'Vous appartenez déjà à une organisation de type ' + def.label + '.', false); return;
  }
  // Vérif : demande déjà en cours ?
  if (orga.demandesAdhesion?.some(d => d.nom === state.char?.name)) {
    showToast('Demande en cours', 'Votre demande est déjà en attente.', false); return;
  }

  if (!orga.demandesAdhesion) orga.demandesAdhesion = [];
  orga.demandesAdhesion.push({ nom: state.char?.name, date: state.day || 1 });
  showToast('Demande envoyée', 'Votre demande d\'adhésion à "' + orga.nom + '" a été envoyée.', true);
  addJournalEntry('Demande d\'adhésion à "' + orga.nom + '".', '');
}

function ouvrirDemandesAdhesion(orgaId) {
  const orga = getOrgaById(orgaId);
  if (!orga) return;
  const def = TYPES_ORGANISATIONS[orga.type] || {};
  const grades = def.grades?.[state.country] || ['Membre'];

  document.getElementById('postes-modal-title').textContent = '📨 Demandes — ' + orga.nom;
  const demandes = orga.demandesAdhesion || [];

  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.6rem 1rem">' +
    (demandes.length === 0 ? '<div style="color:#4a4030;font-style:italic;font-size:.82rem">Aucune demande en attente.</div>' :
      demandes.map(d =>
        '<div style="display:flex;align-items:center;gap:.6rem;padding:.5rem 0;border-bottom:1px solid #1a1208">' +
          '<div style="flex:1"><div style="font-size:.82rem;color:#c0b090">' + d.nom + '</div><div style="font-size:.65rem;color:#4a4030">Demande du Jour ' + d.date + '</div></div>' +
          '<button onclick="accepterAdhesion(\'' + orgaId + '\',\'' + d.nom + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.65rem;padding:.25rem .5rem;border:1px solid #2a4a2a;background:transparent;color:#4a8a4a;cursor:pointer;margin-right:.3rem">✓ Accepter</button>' +
          '<button onclick="refuserAdhesion(\'' + orgaId + '\',\'' + d.nom + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.65rem;padding:.25rem .5rem;border:1px solid #3a1a1a;background:transparent;color:#aa4444;cursor:pointer">✕ Refuser</button>' +
        '</div>'
      ).join('')
    ) +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

function accepterAdhesion(orgaId, nomCandidat) {
  const orga = getOrgaById(orgaId);
  if (!orga) return;
  const def = TYPES_ORGANISATIONS[orga.type] || {};
  const grades = def.grades?.[state.country] || ['Membre'];

  orga.demandesAdhesion = (orga.demandesAdhesion || []).filter(d => d.nom !== nomCandidat);
  orga.membres.push({ nom: nomCandidat, grade: grades[0], gradeIdx: 0, rejointLe: state.day || 1 });
  showToast('Membre accepté', nomCandidat + ' rejoint "' + orga.nom + '" comme ' + grades[0] + '.', true);
  addJournalEntry(nomCandidat + ' accepté dans "' + orga.nom + '".', 'event-good');
  sauvegarderOrga(orga);
  ouvrirDemandesAdhesion(orgaId);
}

function refuserAdhesion(orgaId, nomCandidat) {
  const orga = getOrgaById(orgaId);
  if (!orga) return;
  orga.demandesAdhesion = (orga.demandesAdhesion || []).filter(d => d.nom !== nomCandidat);
  showToast('Demande refusée', nomCandidat + ' a été refusé.', false);
  sauvegarderOrga(orga);
  ouvrirDemandesAdhesion(orgaId);
}

// ------ ORDRES SPÉCIFIQUES ------

function ouvrirOrdresOrga(orgaId) {
  const orga = getOrgaById(orgaId);
  if (!orga) return;
  const def = TYPES_ORGANISATIONS[orga.type] || {};
  const ordres = def.ordres || [];
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const monMembre = orga.membres?.find(m => m.nom === state.char?.name);
  const monGradeIdx = monMembre?.gradeIdx || 0;

  document.getElementById('postes-modal-title').textContent = '⚡ Actions — ' + orga.nom;
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.6rem 1rem">' +
    ordres.map(ordre => {
      const rangMin = (typeof ORGA_ORDRE_RANG_MIN !== 'undefined' && ORGA_ORDRE_RANG_MIN[ordre.fn]) || 0;
      const disabled = monGradeIdx < rangMin;
      return '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.6rem .8rem;margin-bottom:.4rem' + (disabled ? ';opacity:.4' : '') + '">' +
        '<div style="display:flex;align-items:center;gap:.5rem;margin-bottom:.3rem">' +
          '<i class="ti ' + ordre.icon + '" style="font-size:.9rem;color:#C9A84C"></i>' +
          '<div style="font-family:Bebas Neue,sans-serif;font-size:.78rem;color:#E8C97A">' + ordre.label + '</div>' +
          '<div style="margin-left:auto;font-size:.65rem;color:#8a6a20">' + ordre.pa + ' PA' + (ordre.cost > 0 ? ' · ' + ordre.cost.toLocaleString('fr-FR') + ' ' + cur : '') + '</div>' +
        '</div>' +
        '<div style="font-size:.68rem;color:#6a5a30;margin-bottom:.4rem">' + ordre.desc + '</div>' +
        (disabled ?
          '<div style="font-size:.65rem;color:#5a3a2a">Rang insuffisant pour cet ordre.</div>' :
          '<button onclick="executerOrdreOrga(\'' + orgaId + '\',\'' + ordre.fn + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.65rem;letter-spacing:.06em;padding:.25rem .6rem;border:1px solid #3a2a10;background:transparent;color:#C9A84C;cursor:pointer">Exécuter</button>'
        ) +
      '</div>';
    }).join('') +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

function executerOrdreOrga(orgaId, fn) {
  const orga = getOrgaById(orgaId);
  if (!orga) return;
  const def = TYPES_ORGANISATIONS[orga.type] || {};
  const ordre = (def.ordres || []).find(o => o.fn === fn);
  if (!ordre) return;
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  // Vérifs PA et coût
  if ((state.pa || 0) < ordre.pa) { showToast('PA insuffisants', ordre.pa + ' PA requis.', false); return; }
  if (ordre.cost > 0 && state.arg < ordre.cost) { showToast('Fonds insuffisants', ordre.cost + ' ' + cur + ' requis.', false); return; }

  state.pa -= ordre.pa;
  if (ordre.cost > 0) state.arg -= ordre.cost;

  // Effets selon fonction
  const effets = {
    orga_petition:       () => { const gain = Math.floor(Math.random()*8)+3; state.pop = Math.min(100,(state.pop||0)+gain); showToast('Pétition lancée !','+'+gain+' POP.',true); addJournalEntry('Pétition de "'+orga.nom+'". +'+gain+' POP.','event-good'); addExternalEvent('📋 "'+orga.nom+'" lance une pétition publique.'); },
    orga_meeting:        () => { state.pop=Math.min(100,(state.pop||0)+5); state.inf=Math.min(100,(state.inf||0)+3); showToast('Meeting !','+5 POP +3 INF.',true,true); addJournalEntry('Meeting de "'+orga.nom+'".','event-good'); addExternalEvent('📢 "'+orga.nom+'" organise un meeting.'); },
    orga_collecte:       () => { const don=Math.floor(Math.random()*500)+200; orga.caisse=(orga.caisse||0)+don; showToast('Collecte réussie !','+'+don+' '+cur+' dans la caisse.',true); addJournalEntry('Collecte "'+orga.nom+'". +'+don+' '+cur+'.','event-good'); },
    orga_dividendes:     () => { const part=Math.floor((orga.caisse||0)*0.3); if(part<10){showToast('Caisse vide','Pas assez de fonds à distribuer.',false);return;} orga.caisse-=part; state.arg+=part; showToast('Dividendes versés !','+'+part+' '+cur+'.',true); addJournalEntry('Dividendes reçus de "'+orga.nom+'". +'+part+' '+cur+'.','event-good'); },
    orga_benediction:    () => { state.moral=Math.min(100,(state.moral||50)+10); state.pop=Math.min(100,(state.pop||0)+5); showToast('Bénédiction !','Cérémonie en votre honneur. +10 Moral +5 POP.',true,true); addJournalEntry('Bénédiction de "'+orga.nom+'".','event-good'); addExternalEvent('✨ "'+orga.nom+'" organise une cérémonie de bénédiction.'); },
    orga_anatheme:       () => { state.moral=Math.max(0,(state.moral||50)-15); state.pop=Math.max(0,(state.pop||0)-10); showToast('Anathème !','Cérémonie contre un PJ. -15 Moral -10 POP à la cible.',false); addJournalEntry('Anathème prononcé par "'+orga.nom+'".','event-bad'); addExternalEvent('⛧ "'+orga.nom+'" prononce un anathème public.'); },
    orga_pelerinage:     () => { state.pop=Math.min(100,(state.pop||0)+8); showToast('Pèlerinage !','+8 POP. Grand rassemblement.',true,true); addExternalEvent('🕊 "'+orga.nom+'" organise un grand pèlerinage.'); },
    orga_blanchiment:    () => { const s=Math.floor(Math.random()*100)+1; if(s<=40){state.dis=Math.max(0,(state.dis||50)-10);showToast('Blanchiment raté !','-10 DIS.',false);}else{const gain=Math.floor(Math.random()*2000)+500;state.arg+=gain;showToast('Blanchiment réussi !','+'+gain+' '+cur+'.',true);} addJournalEntry('Blanchiment via "'+orga.nom+'".','event-bad'); },
    orga_racket:         () => { const s=Math.floor(Math.random()*100)+1; if(s<=30){state.dis=Math.max(0,(state.dis||50)-15);showToast('Racket raté !','Arrestation risquée. -15 DIS.',false);}else{const gain=Math.floor(Math.random()*1000)+300;state.arg+=gain;showToast('Racket réussi !','+'+gain+' '+cur+'.',true);} },
    orga_contrebande:    () => { const s=Math.floor(Math.random()*100)+1; if(s<=35){state.dis=Math.max(0,(state.dis||50)-20);showToast('Cargaison saisie !','-20 DIS.',false);}else{const gain=Math.floor(Math.random()*3000)+1000;state.arg+=gain;showToast('Contrebande réussie !','+'+gain+' '+cur+'.',true);} },
    orga_campagne_presse:() => { state.pop=Math.min(100,(state.pop||0)+6); state.inf=Math.min(100,(state.inf||0)+5); showToast('Article favorable !','+6 POP +5 INF.',true,true); addExternalEvent('📰 "'+orga.nom+'" publie une campagne de presse favorable.'); },
    orga_scoop:          () => { state.inf=Math.min(100,(state.inf||0)+10); showToast('Scoop publié !','+10 INF. Scandale public.',true,true); addExternalEvent('🔥 "'+orga.nom+'" publie un scoop explosif !'); },
    orga_rituel:         () => { state.inf=Math.min(100,(state.inf||0)+6); showToast('Rituel accompli.','+6 INF. Nouveau membre initié.',true); },
    orga_reseau:         () => { state.inf=Math.min(100,(state.inf||0)+8); showToast('Réseau activé.','+8 INF. Information exclusive obtenue.',true,true); addJournalEntry('Réseau de la Loge activé. +8 INF.','event-good'); },
    orga_cooptation:     () => { state.inf=Math.min(100,(state.inf||0)+5); showToast('Cooptation discrète.','Un poste peut être attribué sans élection.',true); },
  };

  const effet = effets[fn];
  if (effet) { effet(); }
  else { showToast('Action exécutée.', ordre.label + ' accompli.', true); addJournalEntry(ordre.label + ' via "' + orga.nom + '".', ''); }

  sauvegarderOrga(orga);
  document.getElementById('modal-postes').classList.remove('open');
  updateUI();
}

// ------ OPTIONS CHEF ------

function ouvrirOptionsOrga(orgaId) {
  const orga = getOrgaById(orgaId);
  if (!orga || orga.chef !== state.char?.name) return;

  document.getElementById('postes-modal-title').textContent = 'Parametres — ' + orga.nom;
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +

    '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.3rem">NOM</div>' +
    '<input id="orga-rename-input" type="text" maxlength="40" value="' + orga.nom + '" style="width:100%;padding:.4rem .6rem;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;font-family:Crimson Pro,serif;font-size:.9rem;box-sizing:border-box;margin-bottom:.5rem"/>' +

    '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.3rem">DEVISE</div>' +
    '<input id="orga-devise-input" type="text" maxlength="80" placeholder="Ex: La force dans l\'union..." value="' + (orga.devise||'') + '" style="width:100%;padding:.4rem .6rem;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;font-family:Crimson Pro,serif;font-size:.9rem;box-sizing:border-box;margin-bottom:.5rem"/>' +

    '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.3rem">AVATAR (URL image)</div>' +
    '<input id="orga-avatar-input" type="text" maxlength="300" placeholder="https://..." value="' + (orga.avatar||'') + '" style="width:100%;padding:.4rem .6rem;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;font-family:Crimson Pro,serif;font-size:.85rem;box-sizing:border-box;margin-bottom:.6rem"/>' +

    '<button onclick="sauvegarderOptionsOrga(\'' + orgaId + '\')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.4rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer;margin-bottom:.8rem">Sauvegarder</button>' +

    '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.3rem">VISIBILITE</div>' +
    '<button onclick="toggleVisibiliteOrga(\'' + orgaId + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.7rem;padding:.3rem .8rem;border:1px solid #3a4a5a;background:transparent;color:#6a8aaa;cursor:pointer;margin-bottom:.8rem">' + (orga.visible ? '👁 Rendre secrete' : '👁 Rendre visible') + '</button>' +

    '<div style="margin-top:.4rem;border-top:1px solid #1a1208;padding-top:.6rem">' +
    '<button onclick="dissoudreOrga(\'' + orgaId + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.7rem;padding:.3rem .8rem;border:1px solid #5a1a1a;background:transparent;color:#cc4444;cursor:pointer">Dissoudre</button>' +
    '</div></div>';
  document.getElementById('modal-postes').classList.add('open');
}

function renommerOrga(orgaId) {
  const orga = getOrgaById(orgaId);
  if (!orga) return;
  const newNom = document.getElementById('orga-rename-input')?.value?.trim();
  if (!newNom || newNom.length < 2) return;
  orga.nom = newNom;
  sauvegarderOrga(orga);
  showToast('Organisation renommée', '"' + newNom + '"', true);
  document.getElementById('modal-postes').classList.remove('open');
  switchSelfTab('orgas', null);
}

function toggleVisibiliteOrga(orgaId) {
  const orga = getOrgaById(orgaId);
  if (!orga) return;
  orga.visible = !orga.visible;
  showToast(orga.visible ? 'Organisation visible' : 'Organisation secrète', '', true);
  sauvegarderOrga(orga);
  document.getElementById('modal-postes').classList.remove('open');
}

function dissoudreOrga(orgaId) {
  const orga = getOrgaById(orgaId);
  if (!orga) return;
  state.organisations = (state.organisations || []).filter(o => o.id !== orgaId);
  if (typeof sbDeleteOrganisation === 'function') sbDeleteOrganisation(orgaId).catch(() => {});
  document.getElementById('modal-postes').classList.remove('open');
  showToast('Organisation dissoute', '"' + orga.nom + '" n\'existe plus.', false);
  addJournalEntry('"' + orga.nom + '" dissoute.', 'event-bad');
  switchSelfTab('orgas', null);
}

function quitterOrga(orgaId) {
  const orga = getOrgaById(orgaId);
  if (!orga) return;
  if (orga.chef === state.char?.name) { showToast('Impossible', 'Dissolvez l\'organisation ou transmettez la direction avant de partir.', false); return; }
  orga.membres = orga.membres.filter(m => m.nom !== state.char?.name);
  showToast('Vous avez quitté', '"' + orga.nom + '"', false);
  addJournalEntry('Départ de "' + orga.nom + '".', '');
  switchSelfTab('orgas', null);
}

function ouvrirForumDepuisOrga() {
  document.getElementById('modal-postes').classList.remove('open');
  document.getElementById('vue-self').classList.remove('active');
  openForum();
}



// =====================
// V27 — DON D'ARGENT A UN PNJ
// =====================
function ouvrirDonPnjModal(encodedPnj) {
  let pnj;
  try { pnj = JSON.parse(decodeURIComponent(encodedPnj)); } catch(e) { return; }
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const job = pnj.job || 'default';
  const jobLabels = {
    serveur:'Un pourboire genereux. Il pourrait vous glisser une info utile.',
    barman:'Il entend tout. Arroser le barman, c\'est investir dans le renseignement.',
    commissaire:'Risque. Mais parfois ca passe. Jet de DUP.',
    policier:'Risque. Mais parfois ca passe. Jet de DUP.',
    inspecteur:'Risque. Mais parfois ca passe. Jet de DUP.',
    journaliste:'Un geste editorial. Peut generer un article favorable.',
    banquier:'Un service discret. Il fera passer votre transaction sans questions.',
    medecin:'Des soins off-record. Pas de trace medicale.',
    commercant:'Ca fait du bien a la reputation locale.',
    juge:'Delicat. Un juge corruptible peut classer une affaire.',
    avocat:'L\'avocat peut faire accelerer une procedure.',
    loge:'Un don a la Loge. Le reseau se souviendra.',
    grand_pretre:'+IP et benediction.',
    escort:'Informations exclusives.',
    default:'Un geste de bonne volonte. Effets variables.'
  };
  // modal-pnj reste ouvert
  document.getElementById('postes-modal-title').textContent = 'Donner de l\'argent a ' + pnj.name.replace(' (PNJ)', '');
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +
    '<div style="font-size:.78rem;color:#a09060;font-style:italic;margin-bottom:.7rem;border-left:2px solid #3a2a10;padding-left:.6rem">' + (jobLabels[job] || jobLabels.default) + '</div>' +
    '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">MONTANT (' + cur + ')</div>' +
    '<input id="don-pnj-montant" type="number" min="10" step="50" placeholder="Ex: 200" style="width:100%;padding:.4rem .6rem;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;font-family:Crimson Pro,Georgia,serif;font-size:.9rem;box-sizing:border-box;margin-bottom:.7rem"/>' +
    '<button onclick="confirmerDonPnj(\'' + encodedPnj + '\')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">💰 Donner</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerDonPnj(encodedPnj) {
  let pnj;
  try { pnj = JSON.parse(decodeURIComponent(encodedPnj)); } catch(e) { return; }
  const montant = parseInt(document.getElementById('don-pnj-montant')?.value || 0);
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const job = pnj.job || 'default';
  const isn = INDICES_NATIONAUX?.[state.country]?.ISN || 30;
  if (!montant || montant <= 0) { showToast('Montant invalide', 'Entrez un montant.', false); return; }
  if (state.arg < montant) { showToast('Fonds insuffisants', montant + ' ' + cur + ' requis.', false); return; }
  document.getElementById('modal-postes').classList.remove('open');
  state.arg -= montant;
  updateUI();

  // Don a un VRAI joueur — depot reel via Supabase, credite automatiquement a sa prochaine connexion
  if (pnj.isPJ) {
    const nomCourt = pnj.name.replace(' (PNJ)','');
    const expediteur = state.char?.name || 'Anonyme';
    const h = String(state.hour || 8).padStart(2,'0');
    const time = 'Jour ' + (state.day || 1) + ' · ' + h + 'h';
    if (typeof sbDeposerDon === 'function') {
      await sbDeposerDon(nomCourt, montant, expediteur).catch(() => {});
    }
    if (typeof sbSendMail === 'function') {
      await sbSendMail(expediteur, nomCourt, 'Don d\'argent recu',
        expediteur + ' vous a fait don de ' + montant + ' ' + cur + '. La somme sera automatiquement creditee sur votre compte a votre prochaine connexion.', time).catch(() => {});
    }
    addJournalEntry('Vous avez donne ' + montant + ' ' + cur + ' a ' + nomCourt + '.', 'event-good');
    showToast('Don envoye', nomCourt + ' recevra ' + montant + ' ' + cur + ' automatiquement.', true, true);
    return;
  }
  const dup = state.char?.stats?.DUP || 8;
  const nomCourt = pnj.name.replace(' (PNJ)','');
  const jobsRisques = ['commissaire','policier','inspecteur','juge'];
  const tauxRefus = jobsRisques.includes(job) ? Math.max(0, isn - 30) / 2 : 0;
  const rollRefus = Math.floor(Math.random() * 100) + 1;
  if (tauxRefus > 0 && rollRefus <= tauxRefus) {
    state.arg += montant;
    state.dis = Math.max(0, (state.dis||50) - 15);
    updateUI();
    addJournalEntry('Don refuse par ' + nomCourt + '. -15 DIS.', 'event-bad');
    showToast('Refus indigne !', nomCourt + ' a refuse. -15 DIS.', false);
    return;
  }
  const effets = {
    serveur:     () => { state.moral=Math.min(100,(state.moral||50)+5); state.inf=Math.min(100,(state.inf||0)+2); showToast('Pourboire verse !','+5 Moral +2 INF.',true); addJournalEntry('Pourboire a '+nomCourt+'. +5 Moral +2 INF.','event-good'); },
    barman:      () => { state.inf=Math.min(100,(state.inf||0)+5); showToast('Le barman apprecie !','+5 INF.',true,true); addJournalEntry('Don barman. +5 INF.','event-good'); },
    commissaire: () => { const t=Math.min(70,30+Math.floor(dup*2)); const r=Math.floor(Math.random()*100)+1; if(r<=t){state.dis=Math.max(0,(state.dis||50)-5);showToast('Arrangement discret','-5 DIS.',true);addJournalEntry('Corruption commissaire. -5 DIS.','event-bad');}else{state.dis=Math.max(0,(state.dis||50)-20);showToast('Refus !','-20 DIS.',false);} },
    policier:    () => { const t=Math.min(65,25+Math.floor(dup*2)); const r=Math.floor(Math.random()*100)+1; if(r<=t){state.dis=Math.max(0,(state.dis||50)-3);showToast('Il regarde ailleurs.','-3 DIS.',true);}else{state.dis=Math.max(0,(state.dis||50)-15);showToast('Refus !','-15 DIS.',false);} },
    inspecteur:  () => { const t=Math.min(70,35+Math.floor(dup*2)); const r=Math.floor(Math.random()*100)+1; if(r<=t){state.dis=Math.max(0,(state.dis||50)-5);showToast('Inspecteur convaincu !','-5 DIS.',true);}else{state.dis=Math.max(0,(state.dis||50)-15);showToast('Refus !','-15 DIS.',false);} },
    journaliste: () => { state.inf=Math.min(100,(state.inf||0)+8); state.pop=Math.min(100,(state.pop||0)+5); showToast('Article favorable !','+8 INF +5 POP.',true,true); addExternalEvent((state.char?.name||'Anonyme')+' beneficie d\'une couverture favorable.'); },
    banquier:    () => { state.dis=Math.min(100,(state.dis||50)+5); showToast('Service discret.','+5 DIS.',true); },
    medecin:     () => { const s=Math.min(25,Math.floor(montant/10)); state.hp=Math.min(100,(state.hp||100)+s); showToast('Soins off-record !','+'+s+' HP.',true); },
    commercant:  () => { state.pop=Math.min(100,(state.pop||0)+4); state.inf=Math.min(100,(state.inf||0)+2); showToast('Reputation locale !','+4 POP +2 INF.',true); },
    juge:        () => { const t=Math.min(55,20+Math.floor(dup*2)); const r=Math.floor(Math.random()*100)+1; if(r<=t){state.dis=Math.max(0,(state.dis||50)-8);showToast('Le juge est comprehensif.','-8 DIS.',true,true);}else{state.dis=Math.max(0,(state.dis||50)-25);showToast('SCANDALE !','-25 DIS.',false);} },
    avocat:      () => { state.inf=Math.min(100,(state.inf||0)+5); showToast('L\'avocat note votre generosite.','+5 INF.',true); },
    loge:        () => { state.inf=Math.min(100,(state.inf||0)+8); showToast('Don a la Loge.','+8 INF.',true,true); },
    grand_pretre:() => { state.pop=Math.min(100,(state.pop||0)+5); state.moral=Math.min(100,(state.moral||50)+5); showToast('Don beni !','+5 POP +5 Moral.',true,true); },
    escort:      () => { state.inf=Math.min(100,(state.inf||0)+6); showToast('Information exclusive !','+6 INF.',true,true); },
  };
  const effet = effets[job];
  if (effet) { effet(); }
  else {
    const moralBonus = Math.min(8, Math.floor(montant / 50));
    state.moral = Math.min(100,(state.moral||50)+moralBonus);
    showToast('Don accepte.', nomCourt+' apprecie. +'+moralBonus+' Moral.', true);
    addJournalEntry('Don a '+nomCourt+'.','event-good');
  }
  updateUI();
}

// =====================
// V27 — DON D'OBJET A UN PNJ
// =====================
function ouvrirDonObjetPnjModal(encodedPnj) {
  let pnj;
  try { pnj = JSON.parse(decodeURIComponent(encodedPnj)); } catch(e) { return; }
  const objets = (state.inventory || []).filter(i => i.type !== 'acte_officiel');
  if (objets.length === 0) { showToast('Inventaire vide', 'Aucun objet a donner.', false); return; }
  // modal-pnj reste ouvert
  document.getElementById('postes-modal-title').textContent = 'Donner un objet a ' + pnj.name.replace(' (PNJ)', '');
  let html = '<div style="padding:.8rem 1rem"><div style="font-size:.75rem;color:#8a8060;font-style:italic;margin-bottom:.7rem">Choisir l\'objet a remettre :</div>';
  objets.forEach((obj, i) => {
    const idx = state.inventory.indexOf(obj);
    html += '<div onclick="confirmerDonObjetPnj('+idx+',\''+encodedPnj+'\')" style="display:flex;align-items:center;gap:.6rem;padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;cursor:pointer" onmouseover="this.style.background=\'#151005\'" onmouseout="this.style.background=\'#0f0d05\'"><i class="ti '+(obj.icon||'ti-package')+'" style="font-size:.9rem;color:#8a6a20"></i><div><div style="font-size:.8rem;color:#c0b090">'+obj.name+'</div><div style="font-size:.65rem;color:#4a4030">'+(obj.desc||'')+'</div></div></div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerDonObjetPnj(objIdx, encodedPnj) {
  let pnj;
  try { pnj = JSON.parse(decodeURIComponent(encodedPnj)); } catch(e) { return; }
  const obj = state.inventory[objIdx];
  if (!obj) return;
  const job = pnj.job || 'default';
  const nomCourt = pnj.name.replace(' (PNJ)','');
  document.getElementById('modal-postes').classList.remove('open');
  let msg = '', bon = true;
  if (obj.type === 'tract') {
    obj.quantite = (obj.quantite||1) - 1;
    if (obj.quantite <= 0) state.inventory.splice(objIdx, 1);
    state.pop = Math.min(100,(state.pop||0)+2);
    msg = nomCourt + ' prend le tract. +2 POP.';
    addJournalEntry('Tract remis a '+nomCourt+'.','event-good');
  } else if (obj.type === 'kompromat') {
    if (['journaliste','redacteur'].includes(job)) {
      state.inventory.splice(objIdx,1); state.inf=Math.min(100,(state.inf||0)+8); state.pop=Math.min(100,(state.pop||0)+5);
      const cible=obj.cible||'une personnalite';
      addExternalEvent('SCANDALE : Un kompromat sur '+cible+' a ete divulgue !');
      msg='Le journaliste s\'empare du dossier. +8 INF +5 POP.';
    } else {
      state.inventory.splice(objIdx,1); state.inf=Math.min(100,(state.inf||0)+3);
      msg=nomCourt+' prend le document. +3 INF.';
    }
  } else {
    state.inventory.splice(objIdx,1); state.moral=Math.min(100,(state.moral||50)+3); state.inf=Math.min(100,(state.inf||0)+2);
    msg=nomCourt+' accepte le cadeau. +3 Moral +2 INF.';
    addJournalEntry('Objet offert a '+nomCourt+'.','event-good');
  }
  updateUI();
  showToast(bon?'Don effectue !':'Action risquee.', msg, bon);
}


// =====================
// FONCTIONS MANQUANTES — avec prélèvement
// =====================

function doAcheterEntreprise() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cost = 8000;
  if (state.arg < cost) { showToast('Fonds insuffisants', cost.toLocaleString('fr-FR') + ' ' + cur + ' requis.', false); return; }
  state.arg -= cost;
  state.pop = Math.min(100, (state.pop||0) + 5);
  state.inf = Math.min(100, (state.inf||0) + 8);
  addToInventory({ name: "Acte d'acquisition d'entreprise", icon: 'ti-building-factory', type: 'acte_officiel', legal: true, desc: 'Vous êtes propriétaire d\'une entreprise locale.' });
  updateUI();
  showToast('Entreprise achetée !', '-' + cost.toLocaleString('fr-FR') + ' ' + cur + '. +5 POP +8 INF.', true);
  addJournalEntry('Achat entreprise. -' + cost.toLocaleString('fr-FR') + ' ' + cur + '.', 'event-good');
}

function doArreter() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cost = 500;
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  state.arg -= cost;
  const isn = INDICES_NATIONAUX?.[state.country]?.ISN || 30;
  INDICES_NATIONAUX[state.country] = INDICES_NATIONAUX[state.country] || {};
  INDICES_NATIONAUX[state.country].ISN = Math.min(100, isn + 5);
  updateUI();
  showToast('Arrestation ordonnée', '-' + cost + ' ' + cur + '. +5 ISN.', false);
  addJournalEntry('Ordre d\'arrestation. -' + cost + ' ' + cur + '.', 'event-bad');
}

function doCompteOffshore() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cost = 1000;
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  state.arg -= cost;
  state.dis = Math.min(100, (state.dis||50) + 10);
  updateUI();
  showToast('Compte offshore ouvert', '-' + cost + ' ' + cur + '. +10 DIS. Transactions discrètes activées.', true);
  addJournalEntry('Compte offshore ouvert. -' + cost + ' ' + cur + '.', 'event-info');
}

function doCorrompreGardien() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cost = 800;
  const dup = state.char?.stats?.DUP || 8;
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  state.arg -= cost;
  const taux = Math.min(80, 30 + Math.floor(dup * 3));
  const roll = Math.floor(Math.random() * 100) + 1;
  if (roll <= taux) {
    state.dis = Math.max(0, (state.dis||50) - 5);
    updateUI();
    showToast('Gardien corrompu !', 'Il regardera ailleurs. -5 DIS.', true);
    addJournalEntry('Gardien corrompu. -' + cost + ' ' + cur + '.', 'event-bad');
  } else {
    updateUI();
    showToast('Refus du gardien !', 'Il n\'a pas accepté. Argent perdu.', false);
    addJournalEntry('Corruption gardien échouée. -' + cost + ' ' + cur + '.', 'event-bad');
  }
}

function doDefense() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cost = 300;
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  state.arg -= cost;
  state.dis = Math.min(100, (state.dis||50) + 8);
  updateUI();
  showToast('Défense renforcée', '-' + cost + ' ' + cur + '. +8 DIS. Votre sécurité est accrue.', true);
  addJournalEntry('Défense renforcée. -' + cost + ' ' + cur + '.', 'event-good');
}

function doDinerAffaires() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cost = 120;
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  state.arg -= cost;
  state.inf = Math.min(100, (state.inf||0) + 4);
  state.moral = Math.min(100, (state.moral||50) + 3);
  updateUI();
  showToast('Dîner d\'affaires', '-' + cost + ' ' + cur + '. +4 INF +3 Moral.', true);
  addJournalEntry('Dîner d\'affaires. -' + cost + ' ' + cur + '.', 'event-good');
}

function doFalsifierDocs() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cost = 500;
  const dup = state.char?.stats?.DUP || 8;
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  state.arg -= cost;
  const taux = Math.min(75, 25 + Math.floor(dup * 3));
  const roll = Math.floor(Math.random() * 100) + 1;
  if (roll <= taux) {
    addToInventory({ name: 'Document falsifié', icon: 'ti-file-x', type: 'document_falsifie', legal: false, desc: 'Document officiel falsifié.' });
    updateUI();
    showToast('Documents falsifiés !', '-' + cost + ' ' + cur + '. Document ajouté à l\'inventaire.', true);
    addJournalEntry('Falsification docs réussie. -' + cost + ' ' + cur + '.', 'event-bad');
  } else {
    updateUI();
    showToast('Falsification ratée !', 'Le faussaire a échoué. Argent perdu.', false);
  }
}

function doImprimerClandestin() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cost = 300;
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  state.arg -= cost;
  state.dis = Math.max(0, (state.dis||50) - 5);
  addToInventory({ name: 'Publication clandestine', icon: 'ti-file-description', type: 'tract', legal: false, quantite: 20, desc: 'Pamphlet imprimé clandestinement.' });
  updateUI();
  showToast('Impression clandestine !', '-' + cost + ' ' + cur + '. 20 tracts clandestins. -5 DIS.', true);
  addJournalEntry('Impression clandestine. -' + cost + ' ' + cur + '.', 'event-bad');
}

function doImprimerLivre() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cost = 500;
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  state.arg -= cost;
  state.pop = Math.min(100, (state.pop||0) + 6);
  state.inf = Math.min(100, (state.inf||0) + 4);
  addToInventory({ name: 'Livre publié', icon: 'ti-book', type: 'document', legal: true, desc: 'Votre ouvrage, publié à compte d\'auteur.' });
  updateUI();
  showToast('Livre publié !', '-' + cost + ' ' + cur + '. +6 POP +4 INF.', true);
  addExternalEvent((state.char?.name||'Anonyme') + ' publie un ouvrage.');
  addJournalEntry('Publication livre. -' + cost + ' ' + cur + '.', 'event-good');
}

function doInvestir() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cost = 500;
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  state.arg -= cost;
  const roll = Math.floor(Math.random() * 100) + 1;
  const gain = roll > 40 ? Math.floor(cost * (0.5 + Math.random())) : 0;
  if (gain > 0) {
    state.arg += gain;
    updateUI();
    showToast('Investissement rentable !', '-' + cost + ' +' + gain + ' ' + cur + '. Bénéfice : ' + (gain-cost) + ' ' + cur + '.', true);
    addJournalEntry('Investissement réussi. +' + (gain-cost) + ' ' + cur + '.', 'event-good');
  } else {
    updateUI();
    showToast('Investissement raté', '-' + cost + ' ' + cur + '. Tout est perdu.', false);
    addJournalEntry('Investissement perdu. -' + cost + ' ' + cur + '.', 'event-bad');
  }
}

function doMarchander() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cost = 100;
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  state.arg -= cost;
  state.inf = Math.min(100, (state.inf||0) + 3);
  state.pop = Math.min(100, (state.pop||0) + 2);
  updateUI();
  showToast('Marchandage réussi', '-' + cost + ' ' + cur + '. +3 INF +2 POP.', true);
  addJournalEntry('Marchandage. -' + cost + ' ' + cur + '.', 'event-good');
}

function doReunionPrivee() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cost = 50;
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  state.arg -= cost;
  state.inf = Math.min(100, (state.inf||0) + 5);
  state.dis = Math.min(100, (state.dis||50) + 3);
  updateUI();
  showToast('Réunion discrète', '-' + cost + ' ' + cur + '. +5 INF +3 DIS.', true);
  addJournalEntry('Réunion privée. -' + cost + ' ' + cur + '.', 'event-info');
}

function doSocieteEcran() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cost = 500;
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  state.arg -= cost;
  state.dis = Math.min(100, (state.dis||50) + 12);
  updateUI();
  showToast('Société écran créée', '-' + cost + ' ' + cur + '. +12 DIS. Transactions masquées.', true);
  addJournalEntry('Société écran créée. -' + cost + ' ' + cur + '.', 'event-info');
}



function supprimerItemInventaire(idx) {
  if (!state.inventory[idx]) return;
  const item = state.inventory[idx];
  state.inventory.splice(idx, 1);
  renderInventory();
  showToast('Objet supprimé', item.name + ' retiré de l\'inventaire.', false);
}


// =====================
// ROXANNE VELOURS — Recrutement escort
// =====================
function ouvrirRecrutementEscort(nomEscort) {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const tarifHeure = 500;

  document.getElementById('modal-pnj').classList.remove('open');
  document.getElementById('postes-modal-title').textContent = '💋 ' + nomEscort;
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +
    '<div style="font-size:.78rem;color:#a09060;font-style:italic;margin-bottom:.7rem;border-left:2px solid #3a2a10;padding-left:.6rem">' +
      '"Mon tarif est de ' + tarifHeure + ' ' + cur + '/heure. Pour une nuit complète, vous savez ce que ça vaut."' +
    '</div>' +
    '<div style="font-size:.75rem;color:#6a5030;margin-bottom:.8rem">Elle rejoint votre groupe. Vous serez débité(e) de <strong style="color:#C9A84C">' + tarifHeure + ' ' + cur + '</strong> à chaque réveil. En cas de non-paiement, une plainte sera déposée et la presse informée.</div>' +
    '<div style="display:flex;gap:.5rem">' +
      '<button onclick="confirmerRecrutementEscort(\'' + nomEscort.replace(/'/g,'') + '\',' + tarifHeure + ')" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">Recruter</button>' +
      '<button onclick="document.getElementById(\'modal-postes\').classList.remove(\'open\')" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem;border:1px solid #2a2010;background:transparent;color:#6a5030;cursor:pointer">Décliner</button>' +
    '</div></div>';
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerRecrutementEscort(nomEscort, tarif) {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  document.getElementById('modal-postes').classList.remove('open');

  // Vérifier doublon
  if ((state.employes || []).some(e => e.job === 'escort')) {
    showToast('Escort déjà recrutée', 'Vous avez déjà une escort dans votre groupe.', false);
    return;
  }
  if ((state.employes || []).length >= MAX_EMPLOYES) {
    showToast('Limite atteinte', 'Maximum ' + MAX_EMPLOYES + ' employés.', false);
    return;
  }

  if (state.arg < tarif) {
    showToast('Fonds insuffisants', tarif + ' ' + cur + ' requis pour la première heure.', false);
    return;
  }
  state.arg -= tarif;

  // Rejoindre le groupe
  if (!state.group) state.group = { leader: state.char?.name, members: [state.char?.name] };
  if (!state.group.members.includes(nomEscort)) state.group.members.push(nomEscort);

  // Enregistrer l'escort active
  if (!state.escortActive) state.escortActive = [];
  state.escortActive.push({ nom: nomEscort, tarif, depuis: state.day || 1 });

  // Ajouter dans state.employes pour affichage panel
  if (!state.employes) state.employes = [];
  const escortPhotos = {
    republic: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/escort-republic.png',
    narco:    'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/escort-narco.png',
    soviet:   'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/escort-soviet.png',
    khalija:  'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/escort-khalija.png',
  };
  state.employes.push({
    nom: nomEscort, role: 'Escort de luxe', job: 'escort',
    photoUrl: escortPhotos[state.country] || '',
    photoPos: '50% 10%',
    cout: tarif, inGroupe: true,
    buildingId: state.currentBuilding,
    roomId: state.currentRoom,
    city: state.currentCity,
    depuis: state.day || 1,
    stats: typeof PNJ_STATS_PAR_JOB !== 'undefined' ? PNJ_STATS_PAR_JOB.escort : {}
  });
  renderEmployesPanel();

  // Générer une remplaçante dans la pièce
  const toutesMaisonEmpire = {
    republic: ['Sophia Élégance', 'Camille Discrétion', 'Laure Prestige', 'Nina Velours', 'Clara Minuit'],
    narco:    ['Lola Discreta', 'Carmen Silencio', 'Rosa Secreto', 'Valentina Sombra', 'Isabel Poder'],
    soviet:   ['Natasha Privilège', 'Olga Silence', 'Irina Distinction', 'Vera Konspiratsiya', 'Anya Nuit'],
    khalija:  ['Yasmin Al-Sirr', 'Fatima Al-Layl', 'Noor Al-Khafia', 'Hana Al-Majd', 'Rima Al-Asrar'],
  };
  const listePossibles = (toutesMaisonEmpire[state.country] || toutesMaisonEmpire.republic)
    .filter(n => n !== nomEscort);
  const remplacante = listePossibles[Math.floor(Math.random() * listePossibles.length)];
  if (!state.escortRemplacante) state.escortRemplacante = {};
  state.escortRemplacante[state.currentBuilding + '_' + state.currentRoom] = {
    name: remplacante + ' (PNJ)',
    role: 'Escort de luxe',
    job: 'escort',
    rel: 'neutral'
  };

  // Trace enquête (10 jours)
  if (!state.tracesEnquete) state.tracesEnquete = [];
  state.tracesEnquete.push({
    type: 'recrutement_escort',
    desc: (state.char?.name||'Anonyme') + ' a recruté ' + nomEscort + ' comme escort personnelle.',
    jour: state.day || 1,
    expireJour: (state.day || 1) + 10
  });

  updateUI();
  showToast('Escort recrutée !', nomEscort + ' rejoint votre groupe. -' + tarif + ' ' + cur + '/réveil.', true, true);
  addJournalEntry('Recrutement escort : ' + nomEscort + '. -' + tarif + ' ' + cur + '/réveil.', 'event-info');
  addExternalEvent('👀 ' + (state.char?.name||'Anonyme') + ' est vu(e) accompagné(e) de ' + nomEscort + '.');
}

function payerEscorts() {
  if (!state.escortActive?.length) return;
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const toRemove = [];

  state.escortActive.forEach((escort, i) => {
    if (state.arg >= escort.tarif) {
      state.arg -= escort.tarif;
      addJournalEntry('Escort ' + escort.nom + ' payée. -' + escort.tarif + ' ' + cur + '.', 'event-info');
    } else {
      // Non-paiement — esclandre
      toRemove.push(i);
      state.pop = Math.max(0, (state.pop||0) - 20);
      state.dis = Math.max(0, (state.dis||50) - 15);
      addMailNotification('Tribunal', 'Plainte déposée par ' + escort.nom,
        escort.nom + ' a déposé une plainte pour non-paiement de services. -20 POP -15 DIS. La presse a été informée.');
      addExternalEvent('📰 SCANDALE : ' + (state.char?.name||'Anonyme') + ' accusé(e) de non-paiement par ' + escort.nom + ' !');
      addJournalEntry('Non-paiement escort. Plainte + article presse. -20 POP -15 DIS.', 'event-bad');
      // Retirer du groupe
      if (state.group?.members) {
        state.group.members = state.group.members.filter(m => m !== escort.nom);
      }
    }
  });

  toRemove.reverse().forEach(i => state.escortActive.splice(i, 1));
}



// =====================
// V31 — SYSTÈME DE GROUPE & EMPLOYÉS PNJ
// =====================

const MAX_EMPLOYES = 10;

function getEmployes() {
  if (!state.employes) state.employes = [];
  return state.employes;
}

function isEmploye(nomPnj) {
  return getEmployes().some(e => e.nom === nomPnj);
}

function isInGroupe(nomPnj) {
  return getEmployes().some(e => e.nom === nomPnj && e.inGroupe);
}

// =====================
// RECRUTER UN PNJ
// =====================
function ouvrirModalRecrutPnj(encodedPnj) {
  let pnj;
  try { pnj = JSON.parse(decodeURIComponent(encodedPnj)); } catch(e) { return; }

  const nomCourt = pnj.name.replace(' (PNJ)', '');
  if (isEmploye(nomCourt)) {
    showToast('Déjà employé', nomCourt + ' travaille déjà pour vous.', false);
    return;
  }
  if (getEmployes().length >= MAX_EMPLOYES) {
    showToast('Limite atteinte', 'Vous ne pouvez pas recruter plus de ' + MAX_EMPLOYES + ' PNJ simultanément.', false);
    return;
  }

  const stats = getPnjStats(pnj);
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cout = pnj.job === 'escort' ? 500 : (stats.recrutCout || 150);

  document.getElementById('postes-modal-title').textContent = 'Recruter — ' + nomCourt;
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +
    '<div style="font-size:.78rem;color:#a09060;font-style:italic;margin-bottom:.7rem;border-left:2px solid #3a2a10;padding-left:.6rem">' +
      (pnj.trait || 'Un PNJ disponible pour vos missions.') +
    '</div>' +
    '<div style="display:grid;grid-template-columns:repeat(4,1fr);gap:.3rem;margin-bottom:.7rem">' +
      '<div style="text-align:center;background:#0a0805;border:1px solid #1a1208;padding:.4rem"><div style="font-size:.55rem;color:#4a4030">FOR</div><div style="font-size:.85rem;color:#C9A84C;font-family:Bebas Neue">' + stats.FOR + '</div></div>' +
      '<div style="text-align:center;background:#0a0805;border:1px solid #1a1208;padding:.4rem"><div style="font-size:.55rem;color:#4a4030">CHA</div><div style="font-size:.85rem;color:#C9A84C;font-family:Bebas Neue">' + stats.CHA + '</div></div>' +
      '<div style="text-align:center;background:#0a0805;border:1px solid #1a1208;padding:.4rem"><div style="font-size:.55rem;color:#4a4030">DUP</div><div style="font-size:.85rem;color:#C9A84C;font-family:Bebas Neue">' + stats.DUP + '</div></div>' +
      '<div style="text-align:center;background:#0a0805;border:1px solid #1a1208;padding:.4rem"><div style="font-size:.55rem;color:#4a4030">LOY</div><div style="font-size:.85rem;color:#C9A84C;font-family:Bebas Neue">' + stats.loyaute + '</div></div>' +
    '</div>' +
    '<div style="font-size:.72rem;color:#6a5030;margin-bottom:.7rem">Coût : <strong style="color:#C9A84C">' + cout + ' ' + cur + '/jour</strong> · ' + (MAX_EMPLOYES - getEmployes().length) + ' place(s) restante(s)</div>' +
    '<button onclick="confirmerRecrutPnj(\'' + encodePnjSafe(pnj) + '\',' + cout + ')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">Recruter</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerRecrutPnj(encodedPnj, cout) {
  let pnj;
  try { pnj = JSON.parse(decodeURIComponent(encodedPnj)); } catch(e) { return; }

  const nomCourt = pnj.name.replace(' (PNJ)', '');
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  document.getElementById('modal-postes').classList.remove('open');

  if (state.arg < cout) {
    showToast('Fonds insuffisants', cout + ' ' + cur + ' requis.', false);
    return;
  }
  if (getEmployes().length >= MAX_EMPLOYES) {
    showToast('Limite atteinte', 'Maximum ' + MAX_EMPLOYES + ' PNJ.', false);
    return;
  }

  state.arg -= cout;

  const stats = getPnjStats(pnj);
  const employe = {
    nom: nomCourt,
    nomComplet: pnj.name,
    role: pnj.role || '',
    job: pnj.job || 'default',
    photoUrl: pnj.photoUrl || '',
    photoPos: pnj.photoPos || '50% 15%',
    stats,
    cout,
    inGroupe: true,
    buildingId: state.currentBuilding,
    roomId: state.currentRoom,
    city: state.currentCity,
    depuis: state.day || 1,
  };

  state.employes.push(employe);
  updateUI();
  renderEmployesPanel();
  // Afficher immédiatement dans la pièce actuelle
  if (state.currentBuilding && state.currentRoom) {
    const room = BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom];
    const world = WORLD[state.country];
    const city = world?.[state.currentCity];
    const ctx = city?.buildingContext?.[state.currentBuilding];
    const displayPersons = (ctx?.persons?.length > 0) ? ctx.persons : (room?.persons || []);
    renderPersonsList(displayPersons);
  }

  showToast(nomCourt + ' recruté(e) !', '-' + cout + ' ' + cur + '/jour. Il/elle rejoint votre groupe.', true);
  addJournalEntry('Recrutement : ' + nomCourt + ' (' + (pnj.role||'PNJ') + '). -' + cout + ' ' + cur + '/jour.', 'event-good');

  // Remplaçant générique pour le PNJ recruté
  if (typeof genererPnjRemplacant === 'function') {
    genererPnjRemplacant(pnj, employe);
  }

  // Trace enquête
  if (!state.tracesEnquete) state.tracesEnquete = [];
  state.tracesEnquete.push({
    type: 'recrutement_pnj',
    desc: (state.char?.name||'Anonyme') + ' a recruté ' + nomCourt + '.',
    jour: state.day || 1,
    expireJour: (state.day || 1) + 10
  });
}

// =====================
// PAIEMENT DES EMPLOYÉS AU RÉVEIL
// =====================
function payerEmployes() {
  const employes = getEmployes();
  if (employes.length === 0) return;
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const toFire = [];

  employes.forEach((emp, i) => {
    if (state.arg >= emp.cout) {
      state.arg -= emp.cout;
      addJournalEntry('Salaire ' + emp.nom + '. -' + emp.cout + ' ' + cur + '.', 'event-info');
    } else {
      toFire.push(i);
      addMailNotification('Ressources Humaines', emp.nom + ' a quitté votre service',
        emp.nom + ' n\'a pas été payé(e). Il/elle quitte votre groupe immédiatement.');
      addJournalEntry(emp.nom + ' non payé(e). Départ.', 'event-bad');
      showToast('Départ de ' + emp.nom, 'Fonds insuffisants. -1 employé.', false);
    }
  });

  toFire.reverse().forEach(i => state.employes.splice(i, 1));
}

// =====================
// LAISSER UN PNJ EN PLACE / RÉCUPÉRER
// =====================
function laisserPnjEnPlace(nomPnj) {
  const emp = getEmployes().find(e => e.nom === nomPnj);
  if (!emp) return;
  emp.inGroupe = false;
  emp.buildingId = state.currentBuilding;
  emp.roomId = state.currentRoom;
  emp.city = state.currentCity;

  // Compter combien de PNJ sont déjà laissés dans cette pièce
  const memeEndroit = getEmployes().filter(e =>
    !e.inGroupe && e.buildingId === state.currentBuilding && e.roomId === state.currentRoom && e.nom !== nomPnj
  );
  const msgGroupe = memeEndroit.length > 0
    ? ' Il/elle rejoint ' + memeEndroit.map(e => e.nom).join(', ') + ' sur place.'
    : ' Il/elle reste seul(e) dans cette pièce.';

  updateUI();
  renderEmployesPanel();
  // Rafraîchir la liste des personnes
  if (state.currentBuilding && state.currentRoom) {
    const room = BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom];
    const ctx = WORLD[state.country]?.[state.currentCity]?.buildingContext?.[state.currentBuilding];
    renderPersonsList((ctx?.persons?.length > 0) ? ctx.persons : (room?.persons || []));
  }
  showToast(nomPnj + ' laissé(e) ici', 'Vous pouvez le/la récupérer à tout moment.' + msgGroupe, false);
}

function recupererPnjDansGroupe(nomPnj) {
  const emp = getEmployes().find(e => e.nom === nomPnj);
  if (!emp) return;
  // Vérifier que le PJ est dans la même pièce
  if (emp.buildingId !== state.currentBuilding || emp.roomId !== state.currentRoom) {
    showToast('Absent(e)', nomPnj + ' n\'est pas dans cette pièce.', false);
    return;
  }
  emp.inGroupe = true;
  updateUI();
  renderEmployesPanel();
  showToast(nomPnj + ' rejoint le groupe !', '', true);
}

function licencierPnj(nomPnj) {
  const idx = state.employes?.findIndex(e => e.nom === nomPnj);
  if (idx < 0) return;
  state.employes.splice(idx, 1);
  updateUI();
  renderEmployesPanel();
  showToast(nomPnj + ' licencié(e)', 'Il/elle retourne à ses activités.', false);
  addJournalEntry('Licenciement : ' + nomPnj + '.', 'event-info');
}

// =====================
// DÉBAUCHAGE PAR UN AUTRE PJ
// =====================
function tentativeDebauchage(nomPnj) {
  const emp = getEmployes ? null : null; // cherche dans state global
  // Cette fonction sera appelée depuis le modal PNJ d'un PNJ qui appartient à un autre PJ
  // Pour l'instant on ouvre un modal de confirmation
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  document.getElementById('postes-modal-title').textContent = 'Débaucher ' + nomPnj;
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +
    '<div style="font-size:.78rem;color:#a09060;font-style:italic;margin-bottom:.7rem">Tenter de débaucher ce PNJ. Le résultat dépend de vos statistiques, de celles du PNJ, et de celles de son employeur actuel.</div>' +
    '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.3rem">POT-DE-VIN (' + cur + ')</div>' +
    '<input id="debauche-montant" type="number" min="100" step="100" placeholder="Ex: 500" style="width:100%;padding:.4rem .6rem;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;font-family:Crimson Pro,serif;font-size:.9rem;box-sizing:border-box;margin-bottom:.7rem"/>' +
    '<button onclick="confirmerDebauchage(\'' + nomPnj.replace(/'/g,'') + '\')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.75rem;padding:.4rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">Tenter le débauchage</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerDebauchage(nomPnj) {
  const montant = parseInt(document.getElementById('debauche-montant')?.value || 0);
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  document.getElementById('modal-postes').classList.remove('open');

  if (!montant || montant < 100) { showToast('Montant insuffisant', 'Minimum 100 ' + cur + '.', false); return; }
  if (state.arg < montant) { showToast('Fonds insuffisants', montant + ' ' + cur + ' requis.', false); return; }

  state.arg -= montant;

  // Stats du débaucheur
  const chaDeb = state.char?.stats?.CHA || 8;
  const infDeb = state.inf || 30;

  // On simule les stats du PNJ et de l'employeur (inconnu côté client)
  // En multiplayer réel, on irait chercher dans Supabase
  const loyaute = 50; // valeur simulée
  const chaEmp = 8;   // employeur simulé
  const infEmp = 30;

  // Jet complexe
  const scoreDebauche = Math.floor(chaDeb * 3) + Math.floor(infDeb / 5) + Math.floor(montant / 100);
  const scoreDefense = Math.floor(loyaute * 1.5) + Math.floor(chaEmp * 2) + Math.floor(infEmp / 5);
  const roll = Math.floor(Math.random() * 100) + 1;
  const taux = Math.min(70, Math.max(10, 35 + scoreDebauche - scoreDefense));

  if (roll <= taux) {
    // Succès — le PNJ change d'employeur
    if (!state.employes) state.employes = [];
    state.employes.push({
      nom: nomPnj, role: 'PNJ débauché', job: 'default',
      cout: Math.floor(montant / 3), inGroupe: true,
      buildingId: state.currentBuilding, roomId: state.currentRoom,
      city: state.currentCity, depuis: state.day || 1,
      stats: PNJ_STATS_PAR_JOB.default,
    });
    updateUI();
    renderEmployesPanel();
    showToast('Débauchage réussi !', nomPnj + ' rejoint votre groupe. -' + montant + ' ' + cur, true);
    addJournalEntry('Débauchage réussi : ' + nomPnj + '.', 'event-good');
    addExternalEvent('💼 ' + nomPnj + ' a changé d\'employeur !');
  } else {
    // Échec — l'employeur est notifié
    updateUI();
    showToast('Débauchage raté', '-' + montant + ' ' + cur + ' perdus. L\'employeur a été informé.', false);
    addJournalEntry('Débauchage raté de ' + nomPnj + '. -' + montant + ' ' + cur + '.', 'event-bad');
    // Notification à l'employeur (via Supabase en multijoueur)
    addExternalEvent('⚠️ Quelqu\'un a tenté de débaucher ' + nomPnj + ' !');
  }
}

// =====================
// AFFICHAGE PANEL EMPLOYÉS
// =====================
function renderEmployesPanel() {
  const el = document.getElementById('employes-list');
  if (!el) return;
  const employes = getEmployes();
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  const panel = document.getElementById('employes-panel');
  if (employes.length === 0) {
    el.innerHTML = '<div style="font-size:.72rem;color:#3a3020;font-style:italic;padding:.3rem 0">Aucun employé</div>';
    return;
  }
  // Ouvrir le panel automatiquement si employés présents
  if (panel && panel.style.display === 'none') {
    panel.style.display = 'block';
    const chev = document.getElementById('emp-chevron');
    if (chev) chev.style.transform = 'rotate(90deg)';
  }

  el.innerHTML = employes.map(emp => {
    const avatar = emp.photoUrl
      ? '<img src="' + emp.photoUrl + '" style="width:28px;height:28px;border-radius:50%;object-fit:cover;object-position:' + (emp.photoPos||'50% 15%') + ';border:1px solid ' + (emp.inGroupe ? '#C9A84C' : '#3a2a10') + ';flex-shrink:0"/>'
      : '<div style="width:28px;height:28px;border-radius:50%;background:#1a1208;display:flex;align-items:center;justify-content:center;border:1px solid ' + (emp.inGroupe ? '#C9A84C' : '#2a1a08') + ';flex-shrink:0"><i class="ti ti-user" style="font-size:.7rem;color:#8a6a20"></i></div>';

    return '<div style="display:flex;align-items:center;gap:.4rem;padding:.3rem 0;border-bottom:1px solid #1a1208">' +
      avatar +
      '<div style="flex:1;min-width:0">' +
        '<div style="font-size:.72rem;color:#c0b090;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">' + emp.nom + '</div>' +
        '<div style="font-size:.6rem;color:#4a4030">' + (emp.inGroupe ? '🟢 En groupe' : '📍 En faction') + ' · ' + emp.cout + ' ' + cur + '/j</div>' +
      '</div>' +
      '<div style="display:flex;gap:.2rem">' +
        (emp.inGroupe
          ? '<button onclick="laisserPnjEnPlace(\'' + emp.nom.replace(/'/g,'') + '\')" title="Laisser dans cette piece — sort du groupe mais reste votre employe" style="background:none;border:1px solid #2a3a2a;color:#4a7a4a;cursor:pointer;padding:.15rem .3rem;font-size:.6rem">📍</button>'
          : '<button onclick="recupererPnjDansGroupe(\'' + emp.nom.replace(/'/g,'') + '\')" title="Faire rejoindre votre groupe" style="background:none;border:1px solid #3a2a10;color:#8a6a20;cursor:pointer;padding:.15rem .3rem;font-size:.6rem">🔄</button>'
        ) +
        '<button onclick="licencierPnj(\'' + emp.nom.replace(/'/g,'') + '\')" title="Renvoyer cet employe — arret du contrat et du salaire" style="background:none;border:1px solid #3a1a1a;color:#6a3a2a;cursor:pointer;padding:.15rem .3rem;font-size:.6rem">✕</button>' +
      '</div>' +
    '</div>';
  }).join('');
}

// =====================
// DÉPLACEMENT — PNJ en groupe suivent le PJ
// =====================
function deplacerGroupeAvecPj(buildingId, roomId, cityId) {
  const employes = getEmployes();
  employes.forEach(emp => {
    if (emp.inGroupe) {
      emp.buildingId = buildingId;
      emp.roomId = roomId;
      emp.city = cityId || state.currentCity;
    }
  });
}

// =====================
// AFFICHAGE GROUPE DANS LA PIÈCE
// =====================
function getGroupeHtmlPourPiece(buildingId, roomId) {
  const employes = getEmployes();
  // Les employés inGroupe sont TOUJOURS avec le PJ, peu importe la pièce
  const iciGroupe = employes.filter(e => e.inGroupe);
  const iciFaction = employes.filter(e => !e.inGroupe && e.buildingId === buildingId && e.roomId === roomId);

  if (iciGroupe.length === 0 && iciFaction.length === 0) return '';

  const renderEmpCard = (emp, inGroupe) => {
    const borderCol = inGroupe ? '#C9A84C' : '#3a2a10';
    const avatarHtml = emp.photoUrl
      ? '<div class="person-avatar" style="overflow:hidden;border-color:' + borderCol + '">' +
        '<img src="' + emp.photoUrl + '" style="width:100%;height:100%;object-fit:cover;object-position:' + (emp.photoPos||'50% 15%') + '"/>' +
        '</div>'
      : '<div class="person-avatar" style="border-color:' + borderCol + '"><i class="ti ti-user" style="font-size:.75rem;color:#8a6a20"></i></div>';

    const encEmp = encodePnjSafe({ name: emp.nomComplet || emp.nom + ' (PNJ)', role: emp.role, job: emp.job, photoUrl: emp.photoUrl, photoPos: emp.photoPos, rel: 'ally' });
    return '<div class="person-card" style="border-left:2px solid ' + borderCol + ';cursor:pointer" onclick="openPnjModal(\'' + encEmp + '\')">' +
      avatarHtml +
      '<div>' +
        '<div class="person-name" style="color:' + (inGroupe ? '#C9A84C' : '#a09060') + '">' + emp.nom + '</div>' +
        '<div class="person-role">' + (emp.role || 'Employé') + '</div>' +
        '<div style="font-size:.58rem;color:' + (inGroupe ? '#4a6a20' : '#4a4030') + '">' + (inGroupe ? '🟢 Dans votre groupe' : '📍 En faction ici') + '</div>' +
      '</div>' +
    '</div>';
  };

  let html = '';
  if (iciGroupe.length > 0) {
    html += iciGroupe.map(e => renderEmpCard(e, true)).join('');
  }
  if (iciFaction.length > 0) {
    html += iciFaction.map(e => renderEmpCard(e, false)).join('');
  }
  return html;
}

// =====================
// BONUS COMBAT avec PNJ
// =====================
function calculerBonusCombatGroupe() {
  const employes = getEmployes().filter(e => e.inGroupe);
  const bonus = { for: 0, hp: 0, pop: 0, inf: 0, dis: 0, moral: 0, arg: 0 };
  employes.forEach(emp => {
    const cb = emp.stats?.combatBonus || {};
    Object.keys(cb).forEach(k => { if (bonus[k] !== undefined) bonus[k] += cb[k]; });
  });
  return bonus;
}



// =====================
// REMPLAÇANT PNJ RECRUTÉ
// =====================
const PNJ_NOMS_REMPLACEMENT = {
  serveur:     { republic: ['Marcel Fricassée','Hervé Couverture','Denis Nappe','Robert Plateau'], narco: ['Carlos Servicio','Miguel Plato','Juan Mesa','Pedro Vino'], soviet: ['Igor Traktir','Boris Bufet','Alexei Stol','Dmitri Stolovaya'], khalija: ['Hamid Khadim','Samir Sofra','Tariq Khidma','Walid Sufra'] },
  barman:      { republic: ['Gérard Cocktail','Philippe Mojito','Bernard Whisky','Alain Pression'], narco: ['Chuy Tequila','Nacho Mezcal','Beto Cerveza','Lalo Pulque'], soviet: ['Vadim Vodka','Yuri Stakan','Pavel Naliv','Kostya Bochka'], khalija: ['Rashid Chai','Karim Qahwa','Nasser Shay','Ziad Ahwa'] },
  hotelier:    { republic: ['Édouard Velours','Gaston Parquet','Maurice Couloir','Lucien Clef'], narco: ['Roberto Lujoso','Ernesto Suite','Alfonso Lobby','Gonzalo Hall'], soviet: ['Anatoly Gostinitsa','Viktor Nomer','Semyon Klyuch','Filipp Etazh'], khalija: ['Khalid Funduq','Mazen Ghurfa','Jamal Miftah','Faris Rudha'] },
  escort:      { republic: ['Sophie Élégance','Camille Velours','Laure Minuit','Clara Prestige'], narco: ['Lola Discreta','Carmen Sombra','Rosa Secreto','Valentina Poder'], soviet: ['Natasha Nuit','Olga Privilege','Irina Tayna','Vera Noch'], khalija: ['Yasmin Sirr','Fatima Layl','Noor Khafia','Hana Majd'] },
  default:     { republic: ['Jean Quelconque','Pierre Dudule','Henri Tartempion','Louis Machin'], narco: ['José Cualquiera','Manuel Fulano','Diego Mengano','Ramón Perengano'], soviet: ['Ivan Prostoy','Nikita Obychny','Georgy Ryad','Sasha Prosto'], khalija: ['Ali Adi','Omar Aadi','Hassan Adi','Youssef Basit'] },
};

function genererPnjRemplacant(pnjOriginal, employe) {
  const job = pnjOriginal.job || 'default';
  const pays = state.country || 'republic';
  const nomsDispos = (PNJ_NOMS_REMPLACEMENT[job] || PNJ_NOMS_REMPLACEMENT.default)[pays] || PNJ_NOMS_REMPLACEMENT.default.republic;
  const nomOriginal = employe.nom;
  const candidats = nomsDispos.filter(n => n !== nomOriginal);
  const nouveauNom = candidats[Math.floor(Math.random() * candidats.length)];

  // Mettre à jour le PNJ dans la room ou buildingContext
  const world = WORLD[pays];
  const city = world?.[state.currentCity];
  const ctx = city?.buildingContext?.[state.currentBuilding];
  const room = BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom];

  const sources = [];
  if (ctx?.persons) sources.push(ctx.persons);
  if (room?.persons) sources.push(room.persons);

  sources.forEach(list => {
    const idx = list.findIndex(p => p.name === pnjOriginal.name);
    if (idx >= 0) {
      list[idx] = { ...list[idx], name: nouveauNom + ' (PNJ)' };
    }
  });
}



// =====================
// SYSTÈME GÉNÉRIQUE — NOMINATION DE POSTES (juge, commissaire)
// =====================

// Vérifie si un PJ peut accepter ce poste (règles de cumul strict)
function peutAccepterPosteNomme(posteId) {
  const regle = POSTES_NOMMES_EXCLUSIFS[posteId];
  if (!regle) return { ok: true };
  if (!state.poste) return { ok: true };
  if (regle.compatibles.includes(state.poste.id)) return { ok: true };
  return { ok: false, raison: 'Vous occupez déjà le poste de ' + (state.poste.name || state.poste.id) + ', incompatible avec ' + regle.label + '.' };
}

// Liste des habitants éligibles — ville pour commissaire, pays entier pour juge
async function listerHabitantsEligibles(posteId) {
  if (typeof sbListPersonnages !== 'function') return [];
  const regle = POSTES_NOMMES_EXCLUSIFS[posteId];
  if (!regle) return [];
  try {
    const joueurs = await sbListPersonnages() || [];
    return joueurs.filter(j => {
      if (j.country !== state.country) return false;
      if (regle.scope === 'ville' && j.current_city !== state.currentCity) return false;
      return true;
    });
  } catch(e) { return []; }
}

// Ouvre le modal de sélection pour nommer un juge ou un commissaire
async function ouvrirNominerPosteNomme(posteId) {
  const regle = POSTES_NOMMES_EXCLUSIFS[posteId];
  if (!regle) return;

  document.getElementById('postes-modal-title').textContent = 'Nommer un ' + regle.label.toLowerCase();
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a8060;font-style:italic">Recherche des habitants éligibles...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const habitants = await listerHabitantsEligibles(posteId);
  const villeNom = regle.scope === 'ville' ? (WORLD[state.country]?.[state.currentCity]?.name || state.currentCity) : null;

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">' +
    (regle.scope === 'ville'
      ? 'Habitants domiciliés à ' + villeNom + '.'
      : 'Habitants domiciliés dans ' + (COUNTRIES[state.country]?.n || 'cet empire') + '.') +
    ' Le poste de ' + regle.label + ' est incompatible avec tout autre poste sauf Député.</div>';

  if (habitants.length === 0) {
    html += '<div style="font-size:.85rem;color:#5a5040">Aucun habitant éligible trouvé.</div>';
  } else {
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">CANDIDAT</div>';
    html += '<select id="nomme-poste-contact" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.8rem">';
    habitants.forEach(h => { html += '<option value="' + h.name + '">' + h.name + '</option>'; });
    html += '</select>';
    html += '<button onclick="envoyerNominationPosteNomme(\'' + posteId + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Envoyer la nomination</button>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

// Envoie le mail de nomination avec bouton d'acceptation intégré
async function envoyerNominationPosteNomme(posteId) {
  const regle = POSTES_NOMMES_EXCLUSIFS[posteId];
  const destinataire = document.getElementById('nomme-poste-contact')?.value;
  if (!destinataire || !regle) return;

  document.getElementById('modal-postes').classList.remove('open');

  const nommeurNom = state.char?.name || 'Anonyme';
  const villeNom = regle.scope === 'ville' ? (WORLD[state.country]?.[state.currentCity]?.name || state.currentCity) : null;
  const sujet = 'Nomination au poste de ' + regle.label;

  const corps = nommeurNom + ' vous propose le poste de <strong>' + regle.label + '</strong>' +
    (villeNom ? ' pour la ville de ' + villeNom : ' pour ' + (COUNTRIES[state.country]?.n || "l'empire")) + '.<br><br>' +
    '<em>Ce poste est incompatible avec tout autre poste, sauf Député.</em><br><br>' +
    '<button onclick="accepterNominationPosteNomme(\'' + posteId + '\',\'' + (villeNom ? state.currentCity : '') + '\',\'' + state.country + '\',\'' + nommeurNom.replace(/'/g,'') + '\')" ' +
    'style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer;margin-top:.5rem">✓ Accepter le poste</button>';

  if (typeof sbSendMail === 'function') {
    const h = String(state.hour || 8).padStart(2,'0');
    const time = 'Jour ' + (state.day || 1) + ' · ' + h + 'h';
    await sbSendMail(nommeurNom, destinataire, sujet, corps, time);
    showToast('Nomination envoyée', destinataire + ' a reçu votre proposition.', true);
    addJournalEntry('Nomination de ' + destinataire + ' au poste de ' + regle.label + ' proposée.', 'event-info');
  } else {
    showToast('Erreur', 'Système de mail indisponible.', false);
  }
}

// Appelée quand le destinataire clique "Accepter le poste" dans le mail
function accepterNominationPosteNomme(posteId, city, country, nommeurNom) {
  const regle = POSTES_NOMMES_EXCLUSIFS[posteId];
  if (!regle) return;

  const check = peutAccepterPosteNomme(posteId);
  if (!check.ok) {
    showToast('Impossible', check.raison, false);
    return;
  }

  state.poste = { id: posteId, name: regle.label, city: city || null };
  if (state.char) state.char.poste = state.poste;
  state.salaireTouche = false;
  updateUI();

  showToast('Poste accepté !', 'Vous êtes désormais ' + regle.label + (city ? ' de ' + (WORLD[country]?.[city]?.name || city) : '') + '.', true, true);
  addJournalEntry('Vous avez accepté le poste de ' + regle.label + '.', 'event-good');
  addExternalEvent('🏛 ' + (state.char?.name || 'Anonyme') + ' est nommé(e) ' + regle.label + (city ? ' de ' + (WORLD[country]?.[city]?.name || city) : '') + '.', city ? 'local' : 'national');

  // Notifier le nommeur
  if (typeof sbSendMail === 'function' && nommeurNom) {
    const h = String(state.hour || 8).padStart(2,'0');
    const time = 'Jour ' + (state.day || 1) + ' · ' + h + 'h';
    sbSendMail(state.char?.name || 'Anonyme', nommeurNom, 'Nomination acceptée',
      (state.char?.name || 'Le candidat') + ' a accepté le poste de ' + regle.label + '.', time).catch(() => {});
  }
}


document.querySelectorAll('.modal-overlay').forEach(m => {
  m.addEventListener('click', function(e) {
    if (e.target === this) this.classList.remove('open');
  });
});
