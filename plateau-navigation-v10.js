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

  const tooltipData = JSON.stringify({
    name: localName,
    desc: localDesc.substring(0,140) + (localDesc.length > 140 ? '...' : ''),
    pnj: pnjList.slice(0, 4).map(p => (p.name||'').replace(' (PNJ)','')),
    actions: actions
  }).replace(/"/g, '&quot;');

  return '<div class="minimap-building ' + (b.capitaleOnly ? 'capital-only' : '') + '" onclick="enterBuilding(\'' + id + '\')" onmouseenter="showBuildingTooltip(' + tooltipData + ')" onmouseleave="hideBuildingTooltip()">' +
    '<div class="minimap-bld-icon"><i class="ti ' + b.icon + '" style="font-size:.8rem"></i></div>' +
    '<div class="minimap-bld-info">' +
      '<div class="minimap-bld-name">' + localName + '</div>' +
      '<div class="minimap-bld-cat">' + b.cat + ' ' + locked + '</div>' +
      (personCount > 0 ? '<div class="minimap-persons">' + personCount + ' personne' + (personCount > 1 ? 's' : '') + '</div>' : '') +
    '</div>' +
  '</div>';
}

function showBuildingTooltip(data) {
  const el = document.getElementById('building-hover-tooltip');
  if (!el) return;
  let html = '<div class="mtt-title">' + data.name + '</div>';
  if (data.desc) html += '<div class="mtt-desc">' + data.desc + '</div>';
  if (data.pnj && data.pnj.length) {
    html += '<div class="mtt-pnj">' + data.pnj.map(n => '<div style="font-size:.72rem;color:#8a8060">· ' + n + '</div>').join('') + '</div>';
  }
  if (data.actions) html += '<div class="mtt-actions">Actions : ' + data.actions + '</div>';
  el.innerHTML = html;
  el.classList.add('visible');
}

function hideBuildingTooltip() {
  const el = document.getElementById('building-hover-tooltip');
  if (el) el.classList.remove('visible');
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

  const rueImage = document.getElementById('rue-image');
  const minimap = document.getElementById('minimap');
  const ambiance = document.getElementById('rue-ambiance');

  // Nettoyer un eventuel ancien conteneur de rue centrale avant de re-rendre (evite les doublons)
  const ancienConteneur = document.getElementById('rue-centrale-conteneur');
  if (ancienConteneur) ancienConteneur.remove();

  const noeudDepart = typeof RUE_CENTRALE_DEPART !== 'undefined' ? RUE_CENTRALE_DEPART[state.country]?.[state.currentCity] : null;
  const rueCentraleDisponible = noeudDepart && typeof RUE_CENTRALE_NOEUDS !== 'undefined' && RUE_CENTRALE_NOEUDS[state.country]?.[noeudDepart];

  if (rueCentraleDisponible) {
    // Nouvelle navigation par scenes (zoom/fondu) — remplace l'image statique et la mini-carte
    if (minimap) minimap.style.display = 'none';
    if (ambiance) ambiance.style.display = 'none';
    rueImage.style.background = 'none';
    const conteneur = document.createElement('div');
    conteneur.id = 'rue-centrale-conteneur';
    conteneur.style.cssText = 'position:absolute; inset:0; z-index:0;';
    rueImage.insertBefore(conteneur, rueImage.firstChild);
    // Reprend le dernier noeud visite dans cette ville (ex: en sortant d'un batiment)
    // plutot que de toujours reinitialiser sur le noeud de depart.
    const noeudReprise = typeof obtenirNoeudRueCentraleMemorise === 'function'
      ? obtenirNoeudRueCentraleMemorise(state.country, state.currentCity, noeudDepart)
      : noeudDepart;
    initialiserRueCentrale(state.country, noeudReprise);
  } else {
    // Ancien systeme (image statique + mini-carte des batiments) — pour les villes pas encore converties
    if (minimap) minimap.style.display = '';
    if (ambiance) ambiance.style.display = '';
    const imgUrl = city?.imageUrl;
    if (imgUrl) {
      rueImage.style.background = `linear-gradient(180deg, rgba(0,0,0,0.1) 0%, rgba(0,0,0,0.4) 100%), url('${imgUrl}') center/cover no-repeat`;
    } else {
      rueImage.style.background = 'linear-gradient(135deg,#0a0a07,#0f0d08)';
    }
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

function joursRestantsPeine() {
  if (!state.estEmprisonne) return 0;
  return Math.max(0, state.estEmprisonne.jourFin - (state.day || 1));
}

function joursEcoulesHospitalisation() {
  if (!state.hospitalisation) return 0;
  return (state.day || 1) - state.hospitalisation.jourDebut;
}

function batimentHospitalisation() {
  if (!state.hospitalisation) return null;
  return state.hospitalisation.lieu === 'clinique' ? 'clinique-privee' : 'dispensaire-public';
}

function enterBuilding(buildingId, skipAutoRoom) {
  const b = BUILDINGS[buildingId];
  if (!b) return;

  // Verrou militaire : un detachement hostile peut bloquer/attaquer l'entree (verifie en parallele, sans bloquer l'affichage)
  if (typeof rafraichirCacheImmuniteMilitaire === 'function') rafraichirCacheImmuniteMilitaire().catch(() => {});
  if (typeof verifierCouvreFeu === 'function') verifierCouvreFeu().catch(() => {});
  if (typeof suivreEscorteAvecMoi === 'function') suivreEscorteAvecMoi(buildingId).catch(() => {});
  if (typeof verifierMissionMilitaireEntree === 'function') {
    const buildingPrecedent = state.currentBuilding, roomPrecedent = state.currentRoom;
    verifierMissionMilitaireEntree(buildingId, null).then(bloque => {
      if (bloque && buildingPrecedent) enterBuilding(buildingPrecedent, true);
    }).catch(() => {});
  }

  // Verrou : emprisonnement — impossible de quitter le commissariat avant la fin de la peine
  if (state.estEmprisonne && buildingId !== 'commissariat') {
    showToast('Emprisonné(e)', 'Vous êtes en détention. Impossible de sortir avant la fin de votre peine (' + joursRestantsPeine() + ' jour(s) restant(s), ou tentez une évasion).', false);
    return;
  }

  // Verrou : hospitalisation — jour 1 uniquement, aucun deplacement sauf transfert vers la clinique privee
  if (state.hospitalisation && joursEcoulesHospitalisation() === 1 && buildingId !== batimentHospitalisation() && buildingId !== 'clinique-privee') {
    showToast('Hospitalisé(e)', 'Vous êtes encore trop faible pour vous déplacer aujourd\'hui. Seul un transfert vers une clinique privée est possible.', false);
    return;
  }

  // Verrou : batiment ferme suite a un incendie ou des explosifs
  const fermeture = typeof batimentEstFerme === 'function' ? batimentEstFerme(buildingId) : null;
  if (fermeture) {
    const joursRestants = Math.max(1, fermeture.jour_fin - (state.day || 1));
    showToast('Bâtiment fermé', (b.name || buildingId) + ' est fermé suite à un ' + (fermeture.motif === 'explosifs' ? 'attentat à l\'explosif' : 'incendie') + '. Réouverture dans ' + joursRestants + ' jour(s).', false);
    return;
  }

  if (b.locked) {
    showToast('Accès restreint', "Vous n'êtes pas membre de cet établissement.", false);
    addJournalEntry("Vous tentez d'entrer mais l'accès vous est refusé.", 'event-bad');
    return;
  }

  // Controle acces loge maconnique : les membres actifs d'une loge entrent directement
  // (pour ne pas alourdir la navigation) ; les non-membres declenchent une rencontre
  // avec le portier (doLogePortail, avec son propre jet de chance) plutot qu'un refus sec.
  if (b.requiresMembership === 'loge') {
    const orgas = state.organisations || [];
    const loge = orgas.find(o => o.type === 'loge' && o.statut === 'actif');
    const estMembre = loge?.membres?.some(m => m.nom === state.char?.name);
    if (!estMembre) {
      if (typeof doLogePortail === 'function') doLogePortail();
      else showToast('Accès refusé', "Vous devez être membre d'une loge pour entrer ici.", false);
      return;
    }
  }

  state.currentBuilding = buildingId;
  deplacerGroupeAvecPj(buildingId, null, state.currentCity);

  // Precharger la liste des ambassades etrangeres ouvertes ici (partagee via Supabase), pour
  // que le controle d'acces des bureaux d'ambassadeurs (voir enterRoom) reste synchrone.
  if (buildingId === 'quartier-ambassades' && typeof sbGetAmbassadesOuvertes === 'function') {
    sbGetAmbassadesOuvertes(state.country).then(rows => {
      state.ambassadesOuvertesCache = (rows || []).map(r => r.data?.empire || r.empire).filter(Boolean);
    }).catch(() => { state.ambassadesOuvertesCache = []; });
  }

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

  // Entrer dans la premiere piece — sauf si on s'apprete a restaurer une position precise juste apres
  // (sinon cette navigation automatique ecrase la bonne piece dans localStorage avant qu'on ait pu la restaurer)
  if (!skipAutoRoom && rooms.length > 0) {
    enterRoom(buildingId, rooms[0][0], null);
  }

  updateLocationDisplay();
  addJournalEntry(`Vous entrez dans ${displayName}.`, '');
}

function enterRoom(buildingId, roomId, tabEl) {
  // Verrou : emprisonnement — reste bloque en cellule, aucun changement de piece
  if (state.estEmprisonne && !(buildingId === 'commissariat' && roomId === 'prison')) {
    showToast('Emprisonné(e)', 'Vous êtes confiné(e) à votre cellule. ' + joursRestantsPeine() + ' jour(s) restant(s) avant votre libération.', false);
    return;
  }
  // Verrou : hospitalisation — jour 1 uniquement, reste dans sa chambre
  if (state.hospitalisation && joursEcoulesHospitalisation() === 1 && buildingId !== batimentHospitalisation()) {
    showToast('Hospitalisé(e)', 'Vous êtes encore alité(e) aujourd\'hui.', false);
    return;
  }
  // Vérifier accès zone embarquement
  if (!checkZoneEmbarquementAcces(buildingId, roomId)) return;
  // Vérifier accès bureau d'ambassadeur — ferme tant que l'empire concerné n'a pas ouvert
  // son ambassade ici (voir sbOuvrirAmbassade / cache charge dans enterBuilding).
  const AMBASSADE_ROOM_EMPIRE = { bureau_al_khalija: 'khalija', bureau_sovarka: 'soviet', bureau_el_estado: 'narco' };
  if (buildingId === 'quartier-ambassades' && AMBASSADE_ROOM_EMPIRE[roomId]) {
    const empireRequis = AMBASSADE_ROOM_EMPIRE[roomId];
    const ouvertes = state.ambassadesOuvertesCache || [];
    if (!ouvertes.includes(empireRequis)) {
      showToast('Bureau fermé', "Aucune ambassade de " + (COUNTRIES[empireRequis]?.n || empireRequis) + " n'est ouverte ici pour le moment.", false);
      return;
    }
  }
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
  document.querySelectorAll('.piece-tab').forEach(t => t.classList.remove('active'));
  if (tabEl) {
    tabEl.classList.add('active');
  } else {
    // Restauration automatique (rafraichissement de page) : pas d'onglet clique, on le retrouve par roomId
    const roomIds = Object.keys(b.rooms || {});
    const idx = roomIds.indexOf(roomId);
    const tabs = document.querySelectorAll('.piece-tab');
    if (idx >= 0 && tabs[idx]) tabs[idx].classList.add('active');
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
  let displayDesc = (isFirstRoom && ctx?.desc) ? ctx.desc : (room.desc || '');
  if (state.estEmprisonne && buildingId === 'commissariat' && roomId === 'prison') {
    const joursRestants = Math.max(0, state.estEmprisonne.jourFin - (state.day || 1));
    displayDesc += ' — Peine : ' + state.estEmprisonne.raison + '. Temps restant : ' + joursRestants + ' jour(s) (libération au Jour ' + state.estEmprisonne.jourFin + ').';
  }
  if (state.hospitalisation && buildingId === batimentHospitalisation()) {
    const joursRestants = Math.max(0, state.hospitalisation.jourFin - (state.day || 1));
    displayDesc += ' — En convalescence. Temps restant estimé : ' + joursRestants + ' jour(s).';
  }
  document.getElementById('piece-desc').textContent = displayDesc;
  const ROOMS_AVEC_CAISSE_SPECIFIQUE = {
    'bureaux': 'gouvernement-pm', 'bureau_min_int': 'gouvernement-min_int', 'bureau_min_fin': 'gouvernement-min_fin',
    'bureau_min_just': 'gouvernement-min_just', 'bureau_min_info': 'gouvernement-min_info', 'bureau_min_ae': 'gouvernement-min_ae',
    'bureau_min_def': 'gouvernement-min_def'
  };
  const ROOMS_AVEC_CAISSE = { 'palais-presidentiel': 'palais-presidentiel', 'mairie-capitale': 'mairie-capitale', 'caserne-militaire': 'caserne-militaire' };
  const caisseBuildingId = (buildingId === 'palais-gouvernement' ? ROOMS_AVEC_CAISSE_SPECIFIQUE[roomId] : null) || ROOMS_AVEC_CAISSE[buildingId] || (buildingId === 'stade' && roomId === 'buvette' ? 'stade-buvette' : null);
  if (caisseBuildingId && typeof chargerCaisseBatiment === 'function') {
    chargerCaisseBatiment(state.country || 'republic', caisseBuildingId).then(c => {
      const el = document.getElementById('piece-desc');
      if (el) el.textContent = displayDesc + ' — Caisse : ' + (c.solde || 0).toLocaleString('fr-FR') + ' FR.';
    }).catch(() => {});
  }
  let displayPersons = roomOverride?.persons?.length > 0 ? roomOverride.persons : ((isFirstRoom && ctx?.persons?.length > 0) ? ctx.persons : (room.persons || []));

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

  // Detachement militaire eventuellement present (asynchrone, ne bloque pas l'affichage normal)
  if (typeof getAffichageDetachementPiece === 'function') {
    getAffichageDetachementPiece(state.country || 'republic', buildingId, roomId).then(det => {
      if (det && state.currentBuilding === buildingId && state.currentRoom === roomId) {
        const missionLabel = { bloquer_acces:'Bloque l\'accès', securiser:'Sécurise la pièce', assassiner:'Ordre : neutraliser les intrus', arreter:'Ordre : arrêter les intrus', surveiller:'En surveillance', escorter:'Escorte en cours' }[det.mission] || 'Sans consigne';
        renderPersonsList([...displayPersons, { name: det.nom, role: det.nombre + ' soldats — ' + missionLabel, rel: 'neutral', job: 'militaire' }]);
      }
    }).catch(() => {});
  }

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
    showToast('Emprisonné(e)', 'Vous êtes en détention. Impossible de sortir avant la fin de votre peine (' + joursRestantsPeine() + ' jour(s) restant(s), ou tentez une évasion).', false);
    return;
  }
  state.douanePassee = false;
  state.currentBuilding = null;
  state.currentRoom = null;
  // Effacer et persister IMMEDIATEMENT (meme mecanisme que enterRoom), sinon un rafraichissement
  // de la page restaure la derniere piece visitee au lieu de laisser le joueur dans la rue —
  // restaurerPositionApresChargement() ne fait confiance qu'a ce qui est ecrit ici.
  if (state.char) {
    state.char.currentBuilding = null;
    state.char.currentRoom = null;
    localStorage.setItem('respublica_char_' + (state.char.name || 'default'), JSON.stringify(state.char));
    localStorage.setItem('respublica_char', JSON.stringify(state.char));
    if (typeof sbSavePersonnage === 'function') {
      sbSavePersonnage(state).catch(() => {});
    }
  }
  showVueRue();
  addJournalEntry(`Vous sortez du batiment.`, '');
}


// =====================
// PLAN VISUEL DE LA VILLE
// =====================

// Disposition des bâtiments sur le plan (x, y, w, h)
const PLAN_LAYOUTS = {
  capitale: {
    // Plan valide visuellement avec Fred (perimetre + route en croix strictement interne).
    // Quartier des Ambassades au nord (exterieur) ; Stade/Commercial/Affaires autour de
    // l'intersection centrale ; Centre Multimodal aligne sur le perimetre est (exterieur) ;
    // Centre Artisanal (exterieur) et Armurerie (interieur, facade ouest) de part et d'autre
    // de la jonction ouest ; Terrains a Bâtir + Tabernacle + Marche au sud-ouest (exterieur) ;
    // la rue des institutions repartie de part et d'autre de l'intersection sud : Palais->
    // Imprimerie a l'ouest (7 batiments), Hotel de Ville->Loge a l'est (8 batiments).

    'quartier-ambassades':         [270,  20, 140, 50],

    'centre-affaires':             [150, 270,  90, 45],
    'centre-commercial':           [250, 270,  76, 45],
    'stade':                       [354, 270,  90, 45],
    'place-formulaire-liberte':    [400, 345,  90, 70],

    'centre-multinodal-luthecia':  [560, 281,  70, 100],

    'centre-artisanal':            [ 10, 260, 110, 45],
    'armurerie':                   [140, 345,  70, 100],

    'terrain-a-batir-1':           [ 10, 345, 110, 26],
    'terrain-a-batir-4':           [ 10, 375, 110, 26],
    'terrain-a-batir-5':           [ 10, 405, 110, 26],
    'terrain-a-batir-6':           [ 10, 435, 110, 26],
    'terrain-a-batir-7':           [ 10, 465, 110, 26],

    'marche':                      [ 10, 495, 110, 30],
    'tabernacle-impots':           [ 10, 530, 110, 40],

    // Rue des institutions — ouest (Palais Presidentiel -> Imprimerie)
    'palais-presidentiel':         [135, 470,  26, 45],
    'palais-gouvernement':         [163, 470,  26, 45],
    'assemblee':                   [191, 470,  26, 45],
    'tribunal':                    [219, 470,  26, 45],
    'universite':                  [247, 470,  26, 45],
    'dispensaire-public':          [275, 470,  26, 45],
    'la-tribune':                  [303, 470,  26, 45],

    // Rue des institutions — est (Hotel de Ville -> Loge)
    'mairie-capitale':             [345, 470,  22, 45],
    'office-notarial':             [369, 470,  22, 45],
    'hotel-republica':             [393, 470,  22, 45],
    'banque-nationale':            [417, 470,  22, 45],
    'banque-privee':               [441, 470,  22, 45],
    'clinique-privee':             [465, 470,  22, 45],
    'loge-maconnique':             [489, 470,  22, 45],
    'commissariat':                [513, 470,  22, 45],
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
  'centre-commercial': '🛍', 'centre-artisanal': '🔨', 'centre-affaires': '💼',
  'office-notarial': '📜', 'stade': '⚽', 'quartier-ambassades': '🏳', 'place-formulaire-liberte': '📋',
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

  // Perimetre (perimetrique) — rectangle qui ceinture la ville
  svg += '<rect x="130" y="150" width="420" height="370" rx="8" fill="none" stroke="#3a3418" stroke-width="2"/>';

  // Route nord-sud, strictement a l'interieur du perimetre
  svg += '<rect x="336" y="150" width="8" height="370" fill="#1e1c10"/>';
  svg += '<line x1="340" y1="150" x2="340" y2="520" stroke="#2e2a14" stroke-width="1" stroke-dasharray="16,10"/>';

  // Route est-ouest, strictement a l'interieur du perimetre
  svg += '<rect x="130" y="331" width="420" height="8" fill="#1e1c10"/>';
  svg += '<line x1="130" y1="335" x2="550" y2="335" stroke="#2e2a14" stroke-width="1" stroke-dasharray="16,10"/>';

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
    showToast('Emprisonné(e)', 'Vous êtes en détention. Impossible de voyager avant la fin de votre peine (' + joursRestantsPeine() + ' jour(s) restant(s)).', false);
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

