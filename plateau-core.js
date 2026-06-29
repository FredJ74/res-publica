// =====================
// PLATEAU-CORE.JS
// Fondations : state global, initialisation, horloge, mise a jour UI, toast/journal
// =====================

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
  setTimeout(() => appliquerNaturalisationAcceptee(), 2100);
  setTimeout(() => appliquerNominationPosteEnAttente(), 2300);
  setTimeout(() => recupererDonsEnAttente(), 2000);
  setTimeout(() => recupererVolsEnAttente(), 2200);
  setTimeout(() => recupererImpactsEnAttente(), 2400);
  setTimeout(() => verifierLancementQuete(), 2600);
  setInterval(chargerEvenementsPartages, 90000);
  setInterval(recupererDonsEnAttente, 90000);
  setInterval(recupererVolsEnAttente, 90000);
  setInterval(recupererImpactsEnAttente, 90000);

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
