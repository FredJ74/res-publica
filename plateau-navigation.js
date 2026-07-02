// =====================
// PLATEAU-NAVIGATION.JS
// Deplacements, plan de ville, minimap, transport, douanes, port
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

  // Verrou : emprisonnement — impossible de quitter le commissariat avant la fin de la peine
  if (state.estEmprisonne && buildingId !== 'commissariat') {
    showToast('Emprisonné(e)', 'Vous êtes en détention. Impossible de sortir avant la fin de votre peine (ou tentez une évasion).', false);
    return;
  }

  if (b.locked) {
    showToast('Accès restreint', "Vous n'êtes pas membre de cet établissement.", false);
    addJournalEntry("Vous tentez d'entrer mais l'accès vous est refusé.", 'event-bad');
    return;
  }

  // Controle acces loge maconnique — necessite d'etre membre d'une organisation de type 'loge'
  if (b.requiresMembership === 'loge') {
    const orgas = state.organisations || [];
    const estMembre = orgas.some(o => o.type === 'loge' && o.statut === 'actif');
    if (!estMembre) {
      showToast('Accès refusé', "Vous devez être membre d'une loge pour entrer ici.", false);
      addJournalEntry("Vous tentez d'entrer dans la loge mais un portier vous barre la route.", 'event-bad');
      if (typeof logeDemanderAdhesion === 'function') {
        setTimeout(() => logeDemanderAdhesion(), 500);
      }
      return;
    }
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

  // Charger les objets abandonnes visibles dans cette piece
  if (typeof chargerObjetsAbandonnesDansPiece === 'function') chargerObjetsAbandonnesDansPiece();

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
  if (state.estEmprisonne) {
    showToast('Emprisonné(e)', 'Vous êtes en détention. Impossible de sortir avant la fin de votre peine (ou tentez une évasion).', false);
    return;
  }
  state.douanePassee = false;
  showVueRue();
  addJournalEntry(`Vous sortez du batiment.`, '');
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
  if (state.estEmprisonne) {
    showToast('Emprisonné(e)', 'Vous êtes en détention. Impossible de voyager avant la fin de votre peine.', false);
    return;
  }
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

