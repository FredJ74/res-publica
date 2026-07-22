// =====================
// PLATEAU-MULTIJOUEUR.JS
// Personnes presentes, groupe, employes PNJ, recrutement, escort
// =====================

// =====================
// PERSONS LIST
// =====================
const CODETENUS_CATALOGUE = [
  { nom: 'Tristan Cabane', photoUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/commissariat-tristan-cabane.png' },
  { nom: 'Edgard Havu',    photoUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/commissariat-edgard-havu.png' },
  { nom: 'Simona Venture', photoUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/commissariat-simona-venture.png' },
  { nom: 'Kevin Diesel',   photoUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/commissariat-kevin-diesel.png' }
];

function appliquerRemplacantCodetenu(persons) {
  if (!state.codetenuRemplacant || !state.currentBuilding || !state.currentRoom) return persons;
  return persons.map(p => {
    if (p.job !== 'codetenu') return p;
    const cle = state.currentBuilding + '_' + state.currentRoom;
    const remp = state.codetenuRemplacant[cle];
    if (!remp) return p;
    return { ...p, name: remp.name, role: remp.role, photoUrl: remp.photoUrl || p.photoUrl, photoPos: remp.photoPos || p.photoPos };
  });
}

function ouvrirRecrutementCodetenu(nomCodetenu) {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const tarifJour = 100;

  document.getElementById('modal-pnj').classList.remove('open');
  document.getElementById('postes-modal-title').textContent = 'Codetenu - ' + nomCodetenu;
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +
    '<div style="font-size:.78rem;color:#a09060;font-style:italic;margin-bottom:.7rem;border-left:2px solid #3a2a10;padding-left:.6rem">' +
      '"On se serre les coudes ici. ' + tarifJour + ' ' + cur + '/jour, et je reste avec toi."' +
    '</div>' +
    '<div style="font-size:.75rem;color:#6a5030;margin-bottom:.8rem">Il rejoint votre groupe. Vous serez debite(e) de <strong style="color:#C9A84C">' + tarifJour + ' ' + cur + '</strong> a chaque reveil.</div>' +
    '<div style="display:flex;gap:.5rem">' +
      '<button onclick="confirmerRecrutementCodetenu(\'' + nomCodetenu.replace(/'/g,'') + '\',' + tarifJour + ')" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">Recruter</button>' +
      '<button onclick="document.getElementById(\'modal-postes\').classList.remove(\'open\')" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem;border:1px solid #2a2010;background:transparent;color:#6a5030;cursor:pointer">Decliner</button>' +
    '</div></div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerRecrutementCodetenu(nomCodetenu, tarif) {
  document.getElementById('modal-postes').classList.remove('open');
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  if ((state.employes || []).some(e => e.job === 'codetenu')) {
    showToast('Deja recrute', 'Vous avez deja un codetenu dans votre groupe.', false);
    return;
  }
  if ((state.employes || []).length >= MAX_EMPLOYES) {
    showToast('Limite atteinte', 'Maximum ' + MAX_EMPLOYES + ' employes.', false);
    return;
  }
  if (state.arg < tarif) {
    showToast('Fonds insuffisants', tarif + ' ' + cur + ' requis pour la premiere journee.', false);
    return;
  }
  state.arg -= tarif;

  const statsCodetenu = {
    FOR: Math.floor(Math.random() * 5) + 8,
    DUP: Math.floor(Math.random() * 5) + 8
  };

  const infoActuel = CODETENUS_CATALOGUE.find(c => c.nom === nomCodetenu) || CODETENUS_CATALOGUE[0];

  if (!state.employes) state.employes = [];
  state.employes.push({
    nom: nomCodetenu, role: 'Codetenu', job: 'codetenu',
    photoUrl: infoActuel.photoUrl, photoPos: '50% 15%',
    cout: tarif, inGroupe: true,
    buildingId: state.currentBuilding,
    roomId: state.currentRoom,
    city: state.currentCity,
    depuis: state.day || 1,
    stats: statsCodetenu
  });
  updateUI();
  if (typeof renderEmployesPanel === 'function') renderEmployesPanel();

  const restants = CODETENUS_CATALOGUE.filter(c => c.nom !== nomCodetenu);
  const autre = restants[Math.floor(Math.random() * restants.length)] || CODETENUS_CATALOGUE[0];
  if (!state.codetenuRemplacant) state.codetenuRemplacant = {};
  const cleSlot = state.currentBuilding + '_' + state.currentRoom;
  state.codetenuRemplacant[cleSlot] = {
    name: autre.nom + ' (PNJ)',
    role: 'Detenu',
    job: 'codetenu',
    rel: 'neutral',
    photoUrl: autre.photoUrl,
    photoPos: '50% 15%'
  };

  if (typeof renderPersonsList === 'function' && typeof BUILDINGS !== 'undefined') {
    const room = BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom];
    if (room?.persons) renderPersonsList(room.persons);
  }

  showToast('Codetenu recrute !', nomCodetenu + ' rejoint votre groupe. -' + tarif + ' ' + cur + '/reveil.', true, true);
  addJournalEntry('Recrutement codetenu : ' + nomCodetenu + '. -' + tarif + ' ' + cur + '/reveil.', 'event-info');
}

function appliquerRemplacantesEscort(persons) {
  if (!state.escortRemplacante || !state.currentBuilding || !state.currentRoom) return persons;
  return persons.map(p => {
    if (p.job !== 'escort' || !p.genre) return p;
    const cle = state.currentBuilding + '_' + state.currentRoom + '_' + p.genre;
    const remp = state.escortRemplacante[cle];
    if (!remp) return p;
    return { ...p, name: remp.name, role: remp.role, photoUrl: remp.photoUrl || p.photoUrl, photoPos: remp.photoPos || p.photoPos };
  });
}

const POSTES_UNIQUES_A_MASQUER = ['president','pm','maire','min_int','min_fin','min_just','min_def','min_info','min_ae'];
// Note : commissaire/juge/commandant sont volontairement exclus -- ces PNJ restent affiches
// en permanence pour l'ambiance du plateau, puisqu'aucune prerogative de jeu n'est encore
// codee sur ces postes (a construire plus tard).

function filtrerPnjPostesPourvus(persons) {
  const cache = window._titulairesPostes || {};
  return persons.filter(p => {
    if (!p.job || !POSTES_UNIQUES_A_MASQUER.includes(p.job)) return true;
    if (!p.name || !p.name.includes('(PNJ)')) return true;
    const titulaire = cache[p.job + '_' + state.currentCity] || cache[p.job];
    return !titulaire;
  });
}

async function rafraichirTitulairesPostesElectifs() {
  if (typeof sbListPersonnages !== 'function') return;
  try {
    const joueurs = await sbListPersonnages() || [];
    const cache = {};
    joueurs.forEach(j => {
      let poste = j.poste;
      if (typeof poste === 'string') { try { poste = JSON.parse(poste); } catch(e) { poste = null; } }
      if (!poste || !poste.id) return;
      const cle = poste.city ? (poste.id + '_' + poste.city) : poste.id;
      cache[cle] = j.name;
    });
    window._titulairesPostes = cache;
  } catch(e) {}
}

function renderPersonsList(persons, targetId) {
  targetId = targetId || 'persons-list';
  persons = [...(persons || [])]; // mutable copy
  persons = appliquerRemplacantesEscort(persons);
  persons = appliquerRemplacantCodetenu(persons);
  persons = filtrerPnjPostesPourvus(persons);
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
    '<div class="person-name" style="color:#C9A84C">' + char.name + ' <span style="font-size:.8rem;color:#6a5a20">(Vous)</span></div>' +
    (state.recherche?.length > 0 ? '<div style="font-size:.82rem;color:#cc2020;font-family:Bebas Neue,sans-serif;letter-spacing:.1em;animation:blink 1s infinite">⚠ RECHERCHÉ</div>' : '') +
    '<div class="person-role">' + (state.poste?.name || ar?.name || 'Citoyen') + '</div>' +
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
        '<div class="person-rel" style="color:#8a3a2a;font-size:.78rem">⚠ Décédé</div>' +
        '</div></div>';
    }

    const pData = encodePnjSafe(p);
    return '<div class="person-card" onclick="openPnjModal(this.dataset.enc)" data-enc="' + pData + '">' +
      avatarHtml +
      '<div>' +
      '<div class="person-name">' + p.name + '</div>' +
      '<div class="person-role">' + p.role + '</div>' +
      '<div class="person-rel" style="color:' + relCol(p.rel) + ';font-size:.78rem">' + relTxt(p.rel) + '</div>' +
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
      '<div><div class="person-name" style="color:#8aaad0">' + p.name + ' <span style="font-size:.8rem;color:#3a5a8a">[SIM]</span></div>' +
      '<div class="person-role">' + p.role + '</div>' +
      '<div style="font-size:.8rem;color:#3a5a8a">INF:' + p.resources.inf + ' POP:' + p.resources.pop + '</div>' +
      '</div></div>';
  }).join('');

  // Ajouter les employés du groupe présents dans cette pièce
  const groupeHtml = getGroupeHtmlPourPiece(state.currentBuilding, state.currentRoom);

  const finalContent = selfCard + groupeHtml + simuleCards + personCards;
  document.getElementById(targetId).innerHTML = finalContent ||
    '<div class="person-empty">Personne d\'autre ici</div>';

  // Charger les VRAIS joueurs présents dans cette pièce (Supabase) — async, ajouté après coup
  chargerVraisJoueursPresents();
  // Charger les objets abandonnés visibles dans cette pièce — affichés à la suite des personnes
  if (typeof chargerObjetsAbandonnesDansPiece === 'function') chargerObjetsAbandonnesDansPiece();
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
async function chargerVraisJoueursPresents(buildingIdParam, roomIdParam, targetId) {
  if (typeof sbGetPresencesInRoom !== 'function') return;
  const buildingId = buildingIdParam !== undefined ? buildingIdParam : state.currentBuilding;
  const roomId = roomIdParam !== undefined ? roomIdParam : state.currentRoom;
  targetId = targetId || 'persons-list';
  const moi = state.char?.name;
  try {
    const presents = await sbGetPresencesInRoom(state.country, state.currentCity, buildingId, roomId);
    // Si on a change de piece/scene entre temps (pour la rue, on verifie le noeud actuel)
    if (buildingId === 'rue-centrale') {
      if (typeof rueCentraleNoeudActuel !== 'undefined' && rueCentraleNoeudActuel !== roomId) return;
    } else if (state.currentBuilding !== buildingId || state.currentRoom !== roomId) {
      return;
    }
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
      '<div><div class="person-name" style="color:#f0ead6">' + p.name + ' <span style="font-size:.8rem;color:' + empireCol + '">[JOUEUR]</span></div>' +
      '<div class="person-role">Présent ici</div></div></div>';
    }).join('');

    // PNJ voyageant avec les autres joueurs presents (escorts, employes recrutes) --
    // simple affichage, non interactifs, pour rendre visible ce qui ne l'etait pas.
    const pnjDesAutres = [];
    autres.forEach(p => {
      (p.groupe_pnj || []).forEach(pnjInfo => {
        pnjDesAutres.push({ nom: pnjInfo.nom, role: (pnjInfo.role || 'PNJ') + ' de ' + p.name });
      });
    });
    window._pnjDesAutresJoueurs = pnjDesAutres;
    const htmlPnjAutres = pnjDesAutres.map(p => {
      return '<div class="person-card autre-groupe-card" style="border-left:2px solid #6a5a30" title="' + p.role + '">' +
        '<div class="person-avatar" style="border-color:#6a5a30"><i class="ti ti-user" style="font-size:.75rem;color:#6a5a30"></i></div>' +
        '<div><div class="person-name" style="color:#c0b090">' + p.nom + '</div>' +
        '<div class="person-role">' + p.role + '</div></div></div>';
    }).join('');

    // Retirer les anciennes cartes joueur avant d'inserer les nouvelles (evite les doublons au rafraichissement)
    const list0 = document.getElementById(targetId);
    if (list0) {
      list0.querySelectorAll('.vrai-joueur-card').forEach(el => el.remove());
      list0.querySelectorAll('.autre-groupe-card').forEach(el => el.remove());
    }

    const htmlTotal = html + htmlPnjAutres;
    if (htmlTotal) {
      const list = document.getElementById(targetId);
      const empty = list.querySelector('.person-empty');
      if (empty) empty.remove();
      list.insertAdjacentHTML('beforeend', htmlTotal);
    }
  } catch(e) { console.warn('chargerVraisJoueursPresents error', e); }
}

function getMonGroupePNJ() {
  const liste = [];
  (state.escortActive || []).forEach(e => liste.push({ nom: e.nom, role: 'Escort' }));
  (state.employes || []).filter(e => e.inGroupe).forEach(e => liste.push({ nom: e.nom, role: e.role || 'Employe' }));
  return liste;
}


// ROXANNE VELOURS — Recrutement escort
// =====================
function ouvrirRecrutementEscort(nomEscort, genre) {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const tarifJour = 800;

  document.getElementById('modal-pnj').classList.remove('open');
  document.getElementById('postes-modal-title').textContent = '💋 ' + nomEscort;
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +
    '<div style="font-size:.78rem;color:#a09060;font-style:italic;margin-bottom:.7rem;border-left:2px solid #3a2a10;padding-left:.6rem">' +
      '"Agence Roxane Velours. Mon tarif est de ' + tarifJour + ' ' + cur + '/jour, tout compris."' +
    '</div>' +
    '<div style="font-size:.75rem;color:#6a5030;margin-bottom:.8rem">Elle/il rejoint votre groupe. Vous serez débité(e) de <strong style="color:#C9A84C">' + tarifJour + ' ' + cur + '</strong> à chaque réveil. En cas de non-paiement, une plainte sera déposée et la presse informée.</div>' +
    '<div style="display:flex;gap:.5rem">' +
      '<button onclick="confirmerRecrutementEscort(\'' + nomEscort.replace(/'/g,'') + '\',' + tarifJour + ',\'' + (genre||'F') + '\')" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">Recruter</button>' +
      '<button onclick="document.getElementById(\'modal-postes\').classList.remove(\'open\')" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem;border:1px solid #2a2010;background:transparent;color:#6a5030;cursor:pointer">Décliner</button>' +
    '</div></div>';
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerRenvoyerEscort(nomEscort) {
  document.getElementById('modal-pnj')?.classList.remove('open');
  if (!state.escortActive) state.escortActive = [];
  state.escortActive = state.escortActive.filter(e => e.nom !== nomEscort);
  if (state.group?.members) state.group.members = state.group.members.filter(n => n !== nomEscort);
  updateUI();
  showToast('Escort renvoyee', nomEscort + ' ne fait plus partie de votre groupe.', true);
  addJournalEntry(nomEscort + ' a ete renvoyee.', 'event-info');
}

async function confirmerRecrutementEscort(nomEscort, tarif, genre) {
  document.getElementById('modal-postes').classList.remove('open');
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  if ((state.employes || []).some(e => e.job === 'escort' && e.genre === genre)) {
    showToast('Déjà recrutée', 'Vous avez déjà une escort de ce type dans votre groupe.', false);
    return;
  }
  if ((state.employes || []).length >= MAX_EMPLOYES) {
    showToast('Limite atteinte', 'Maximum ' + MAX_EMPLOYES + ' employés.', false);
    return;
  }
  if (state.arg < tarif) {
    showToast('Fonds insuffisants', tarif + ' ' + cur + ' requis pour la première journée.', false);
    return;
  }
  state.arg -= tarif;

  // Stats aleatoires (personnage "cheate", d'ou le salaire eleve)
  const statsEscort = {
    CHA: Math.floor(Math.random() * 7) + 12, // 12-18
    DUP: Math.floor(Math.random() * 7) + 10, // 10-16
    INT: Math.floor(Math.random() * 7) + 8   // 8-14
  };

  if (!state.group) state.group = { leader: state.char?.name, members: [state.char?.name] };
  if (!state.group.members.includes(nomEscort)) state.group.members.push(nomEscort);

  if (!state.escortActive) state.escortActive = [];
  state.escortActive.push({ nom: nomEscort, tarif, depuis: state.day || 1, genre, palier: 0 });

  // Banque de photos Agence Roxane Velours (independante du prenom, tiree au hasard par genre)
  const PHOTOS_ESCORT = {
    F: [
      'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/escort-f-1-robe-verte.png',
      'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/escort-f-2-robe-or.png',
      'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/escort-f-3-robe-marine.png'
    ],
    H: [
      'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/escort-h-1-costume-beige.png',
      'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/escort-h-2-chemise-noire.png',
      'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/escort-h-3-chemise-ouverte.png'
    ]
  };
  const poolPhotos = PHOTOS_ESCORT[genre] || PHOTOS_ESCORT.F;
  const photoChoisie = poolPhotos[Math.floor(Math.random() * poolPhotos.length)];

  if (!state.employes) state.employes = [];
  state.employes.push({
    nom: nomEscort, role: 'Escort — Agence Roxane Velours', job: 'escort', genre,
    photoUrl: photoChoisie, photoPos: '50% 15%',
    cout: tarif, inGroupe: true,
    buildingId: state.currentBuilding,
    roomId: state.currentRoom,
    city: state.currentCity,
    depuis: state.day || 1,
    stats: statsEscort
  });
  updateUI();
  if (typeof renderEmployesPanel === 'function') renderEmployesPanel();

  // Tracage pour les rumeurs vraies — doublee si le PJ est marie(e)
  if (typeof tracerActionPourRumeur === 'function') {
    tracerActionPourRumeur('escort', null);
    try {
      if (typeof sbGetMariageActif === 'function') {
        const mariage = await sbGetMariageActif(state.char?.name);
        if (mariage) tracerActionPourRumeur('escort', null);
      }
    } catch(e) {}
  }

  // Generer une remplacante/remplacant du meme genre, propre a ce slot (piece + genre)
  const poolParEmpireEtGenre = {
    republic: { F: ['Natacha', 'Éléonore', 'Sabine', 'Camille', 'Laure', 'Nina', 'Clara'], H: ['Julien', 'Antoine', 'Maxime', 'Thibault', 'Victor', 'Hugo', 'Nathan'] },
    narco:    { F: ['Lola Discreta', 'Carmen Silencio', 'Rosa Secreto', 'Valentina Sombra', 'Isabel Poder'], H: ['Diego Sombra', 'Rafael Secreto', 'Mateo Poder'] },
    soviet:   { F: ['Natasha Privilège', 'Olga Silence', 'Irina Distinction', 'Vera Konspiratsiya', 'Anya Nuit'], H: ['Boris Silence', 'Igor Distinction', 'Dimitri Nuit'] },
    khalija:  { F: ['Yasmin Al-Sirr', 'Fatima Al-Layl', 'Noor Al-Khafia', 'Hana Al-Majd', 'Rima Al-Asrar'], H: ['Karim Al-Sirr', 'Malik Al-Layl', 'Samir Al-Khafia'] }
  };
  const pool = (poolParEmpireEtGenre[state.country] || poolParEmpireEtGenre.republic)[genre] || poolParEmpireEtGenre.republic.F;
  const listePossibles = pool.filter(n => n !== nomEscort);
  const remplacante = listePossibles[Math.floor(Math.random() * listePossibles.length)] || pool[0];

  const photoRemplacante = poolPhotos[Math.floor(Math.random() * poolPhotos.length)];
  if (!state.escortRemplacante) state.escortRemplacante = {};
  const cleSlot = state.currentBuilding + '_' + state.currentRoom + '_' + genre;
  state.escortRemplacante[cleSlot] = {
    name: remplacante + ' (PNJ)',
    role: 'Escort — Agence Roxane Velours',
    job: 'escort',
    rel: 'neutral',
    genre,
    photoUrl: photoRemplacante,
    photoPos: '50% 15%'
  };

  if (typeof renderPersonsList === 'function' && typeof BUILDINGS !== 'undefined') {
    const room = BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom];
    if (room?.persons) renderPersonsList(room.persons);
  }

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

const INFORMATEURS_CATALOGUE = [
  { nom: 'Momo Fouine',       genre: 'H', photoUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/informateur-h-1-corpulent.png' },
  { nom: 'Bernard Filature',  genre: 'H', photoUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/informateur-h-2-lunettes.png' },
  { nom: 'Gaspard Renseigne', genre: 'H', photoUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/informateur-h-3-jeune-casquette.png' },
  { nom: 'Lucienne Indic',    genre: 'F', photoUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/informateur-f-2-agee.png' },
  { nom: 'Rita Tuyau',        genre: 'F', photoUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/informateur-f-3-brune.png' },
  { nom: 'Nadège Oreille',    genre: 'F', photoUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/informateur-f-1-la-poste.png' }
];

async function doRecruterInformateurPNJ() {
  if (!state.employes) state.employes = [];
  if (state.employes.some(e => e.job === 'informateur')) {
    showToast('Déjà en poste', 'Vous employez déjà un informateur. Renvoyez-le avant d\'en recruter un autre.', false);
    return;
  }
  const room = BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom];
  const ordre = room?.orders?.find(o => o.fn === 'recruter_informateur_pnj');
  const cout = ordre?.cost || 150;
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  if (state.arg < cout) {
    showToast('Fonds insuffisants', cout + ' ' + cur + ' requis pour la première journée.', false);
    return;
  }
  state.arg -= cout;

  const infoChoisi = INFORMATEURS_CATALOGUE[Math.floor(Math.random() * INFORMATEURS_CATALOGUE.length)];
  const nomPnj = infoChoisi.nom + ' (PNJ)';
  const perInformateur = Math.floor(Math.random() * 7) + 12; // 12 a 18

  state.employes.push({
    nom: nomPnj, role: 'Informateur', job: 'informateur',
    genre: infoChoisi.genre, photoUrl: infoChoisi.photoUrl, photoPos: '50% 15%',
    cout, inGroupe: true,
    buildingId: state.currentBuilding,
    roomId: state.currentRoom,
    city: state.currentCity,
    depuis: state.day || 1,
    stats: { PER: perInformateur }
  });

  updateUI();
  showToast('Informateur recruté !', nomPnj + ' rejoint votre groupe (PER ' + perInformateur + '). -' + cout + ' ' + cur + '.', true, true);
  addJournalEntry('Recrutement d\'un informateur : ' + nomPnj + ' (PER ' + perInformateur + ', ' + cout + ' ' + cur + '/jour).', 'event-good');

  // Pas d'ecriture dans room.persons (objet BUILDINGS global, partage par tous les
  // joueurs) : l'informateur a deja ete ajoute a state.employes avec inGroupe:true
  // ci-dessus, ce qui suffit a le faire apparaitre via la carte "Dans votre groupe"
  // (getGroupeHtmlPourPiece, lue directement par renderPersonsList). Ecrire aussi ici
  // produisait une deuxieme carte "Allie" permanente et dupliquee pour ce meme PNJ.
  if (room && typeof renderPersonsList === 'function') renderPersonsList(room.persons);
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
      '<div style="text-align:center;background:#0a0805;border:1px solid #1a1208;padding:.4rem"><div style="font-size:.78rem;color:#9a8a68">FOR</div><div style="font-size:.85rem;color:#C9A84C;font-family:Bebas Neue">' + stats.FOR + '</div></div>' +
      '<div style="text-align:center;background:#0a0805;border:1px solid #1a1208;padding:.4rem"><div style="font-size:.78rem;color:#9a8a68">CHA</div><div style="font-size:.85rem;color:#C9A84C;font-family:Bebas Neue">' + stats.CHA + '</div></div>' +
      '<div style="text-align:center;background:#0a0805;border:1px solid #1a1208;padding:.4rem"><div style="font-size:.78rem;color:#9a8a68">DUP</div><div style="font-size:.85rem;color:#C9A84C;font-family:Bebas Neue">' + stats.DUP + '</div></div>' +
      '<div style="text-align:center;background:#0a0805;border:1px solid #1a1208;padding:.4rem"><div style="font-size:.78rem;color:#9a8a68">LOY</div><div style="font-size:.85rem;color:#C9A84C;font-family:Bebas Neue">' + stats.loyaute + '</div></div>' +
    '</div>' +
    '<div style="font-size:.72rem;color:#6a5030;margin-bottom:.7rem">Coût : <strong style="color:#C9A84C">' + cout + ' ' + cur + '/jour</strong> · ' + (MAX_EMPLOYES - getEmployes().length) + ' place(s) restante(s)</div>' +
    '<button onclick="confirmerRecrutPnj(\'' + encodePnjSafe(pnj) + '\',' + cout + ')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">Recruter</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerRecrutPnj(encodedPnj, cout) {
  document.getElementById('modal-postes').classList.remove('open');
  showToast('Temporairement indisponible', 'Le recrutement de PNJ comme employé est en cours de refonte.', false);
  return;
  // Code ci-dessous desactive temporairement (duplication de PNJ en cours de refonte)
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
  const emp = state.employes[idx];
  state.employes.splice(idx, 1);

  // Retirer une eventuelle entree fantome dans la piece d'origine (anciens recrutements
  // avant correctif, ou PNJ non inGroupe rattaches a une piece precise).
  const roomOrigine = BUILDINGS[emp.buildingId]?.rooms?.[emp.roomId];
  if (roomOrigine?.persons) {
    const pIdx = roomOrigine.persons.findIndex(p => p.name === nomPnj);
    if (pIdx >= 0) roomOrigine.persons.splice(pIdx, 1);
  }

  updateUI();
  renderEmployesPanel();
  // Rafraichir la liste "personnes presentes" de la piece COURANTE : un employe inGroupe
  // apparait "Dans votre groupe" dans n'importe quelle piece, pas seulement celle ou il
  // a ete recrute — il faut donc toujours rafraichir ici, sans quoi la carte reste
  // affichee jusqu'a un rafraichissement complet de la page.
  const roomCourante = BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom];
  if (roomCourante && typeof renderPersonsList === 'function') {
    renderPersonsList(roomCourante.persons || []);
  }
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
  document.getElementById('modal-postes').classList.remove('open');
  showToast('Temporairement indisponible', 'Le debauchage de PNJ est en cours de refonte.', false);
  return;
  // Code ci-dessous desactive temporairement (duplication de PNJ en cours de refonte)
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
    el.innerHTML = '<div style="font-size:.72rem;color:#9a8a68;font-style:italic;padding:.3rem 0">Aucun employé</div>';
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
        '<div style="font-size:.8rem;color:#9a8a68">' + (emp.inGroupe ? '🟢 En groupe' : '📍 En faction') + ' · ' + emp.cout + ' ' + cur + '/j</div>' +
      '</div>' +
      '<div style="display:flex;gap:.2rem">' +
        (emp.inGroupe
          ? '<button onclick="laisserPnjEnPlace(\'' + emp.nom.replace(/'/g,'') + '\')" title="Laisser dans cette piece — sort du groupe mais reste votre employe" style="background:none;border:1px solid #2a3a2a;color:#4a7a4a;cursor:pointer;padding:.15rem .3rem;font-size:.8rem">📍</button>'
          : '<button onclick="recupererPnjDansGroupe(\'' + emp.nom.replace(/'/g,'') + '\')" title="Faire rejoindre votre groupe" style="background:none;border:1px solid #3a2a10;color:#8a6a20;cursor:pointer;padding:.15rem .3rem;font-size:.8rem">🔄</button>'
        ) +
        '<button onclick="licencierPnj(\'' + emp.nom.replace(/'/g,'') + '\')" title="Renvoyer cet employe — arret du contrat et du salaire" style="background:none;border:1px solid #3a1a1a;color:#6a3a2a;cursor:pointer;padding:.15rem .3rem;font-size:.8rem">✕</button>' +
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
        '<div style="font-size:.78rem;color:' + (inGroupe ? '#4a6a20' : '#4a4030') + '">' + (inGroupe ? '🟢 Dans votre groupe' : '📍 En faction ici') + '</div>' +
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
// SYSTEME DE GROUPE + ARMURERIE (complement)
// =====================

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
// Note : l'ancien systeme d'achat d'arme generique et de consultation du registre
// (doAcheterArme, doConsulterRegistre) a ete remplace par le triptyque d'armes par empire
// et le registre Supabase partage, dans plateau-actions-illegales-rumeurs.js.


// =====================
// CHAT EN PIECE (fenetre persistante, messages ephemeres)
// =====================
let _chatInterval = null;
let _chatDernierMessage = null;
let _chatDestinataire = null; // null = salon commun de la piece

// =====================
// MESSAGERIE PERSISTANTE — remplace l'ancien chat lie a une piece physique.
// Une conversation existe independamment du lieu : soit privee (2 personnes, id = noms
// tries), soit un salon nomme (rejoignable/quittable librement, comme convenu avec Fred).
// =====================

let _conversationActuelle = null; // { id, type: 'prive'|'salon', label }
let _chatNotifInterval = null;

function toggleChatPiece() {
  const panel = document.getElementById('chat-piece-panel');
  if (!panel) return;
  const ouvert = panel.style.display !== 'none';
  if (ouvert) {
    panel.style.display = 'none';
    if (_chatInterval) { clearInterval(_chatInterval); _chatInterval = null; }
  } else {
    panel.style.display = 'flex';
    ouvrirListeConversations();
  }
}

// Ouvre directement une conversation privee avec quelqu'un (appele depuis le bouton
// "Parler" de la fenetre PNJ/joueur), sans passer par la liste.
function ouvrirConversationAvec(nom) {
  const panel = document.getElementById('chat-piece-panel');
  if (panel) panel.style.display = 'flex';
  _conversationActuelle = { id: getConversationId(state.char?.name, nom), type: 'prive', label: nom };
  afficherVueConversation();
}

async function ouvrirListeConversations() {
  const moi = state.char?.name;
  document.getElementById('chat-piece-body').innerHTML = '<div style="padding:1rem;color:#8a8060;font-style:italic;font-size:.75rem">Chargement...</div>';

  let conversationsPrivees = [];
  let salons = [];
  try {
    if (typeof sbGet === 'function') {
      const tousMessages = await sbGet('messages_chat', `order=created_at.desc&limit=300`);
      const idsVus = new Set();
      (tousMessages || []).forEach(m => {
        if (!m.salon && m.conversation_id.split('__').includes(moi) && !idsVus.has(m.conversation_id)) {
          idsVus.add(m.conversation_id);
          const autre = m.conversation_id.split('__').find(n => n !== moi);
          conversationsPrivees.push({ id: m.conversation_id, label: autre });
        }
      });
    }
    if (typeof sbGetMesSalons === 'function') {
      salons = await sbGetMesSalons(moi);
    }
  } catch(e) { console.warn('ouvrirListeConversations error', e); }

  let html = '<div style="padding:.5rem .6rem;display:flex;flex-direction:column;gap:.3rem;overflow-y:auto;flex:1">';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.85rem;letter-spacing:.1em;color:#8a6a20;margin-top:.2rem">CONVERSATIONS</div>';
  if (conversationsPrivees.length === 0 && salons.length === 0) {
    html += '<div style="font-size:.72rem;color:#6a5a30;font-style:italic">Aucune conversation pour le moment.</div>';
  }
  conversationsPrivees.forEach(c => {
    html += '<div onclick="ouvrirConversationAvec(\'' + c.label.replace(/'/g,"\\'") + '\')" style="padding:.4rem .6rem;background:#121005;border:1px solid #2a2010;cursor:pointer;font-size:.78rem;color:#e0d8c0">🔒 ' + c.label + '</div>';
  });
  salons.forEach(s => {
    html += '<div onclick="ouvrirSalonChat(\'' + s.id + '\',\'' + s.nom.replace(/'/g,"\\'") + '\')" style="padding:.4rem .6rem;background:#121005;border:1px solid #2a2010;cursor:pointer;font-size:.78rem;color:#e0d8c0">💬 ' + s.nom + '</div>';
  });
  html += '<button onclick="ouvrirCreerSalonPrompt()" style="margin-top:.4rem;font-family:Bebas Neue,sans-serif;font-size:.68rem;letter-spacing:.08em;padding:.35rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">+ Créer un salon</button>';
  html += '</div>';
  document.getElementById('chat-piece-body').innerHTML = html;
}

function ouvrirCreerSalonPrompt() {
  const nom = prompt('Nom du salon à créer :');
  if (!nom || !nom.trim()) return;
  creerEtOuvrirSalon(nom.trim());
}

async function creerEtOuvrirSalon(nom) {
  if (typeof sbCreerSalon !== 'function') return;
  const id = await sbCreerSalon(nom, state.char?.name).catch(() => null);
  if (id) ouvrirSalonChat(id, nom);
}

function ouvrirSalonChat(salonId, nom) {
  _conversationActuelle = { id: salonId, type: 'salon', label: nom };
  afficherVueConversation();
}

function retourListeConversations() {
  if (_chatInterval) { clearInterval(_chatInterval); _chatInterval = null; }
  _conversationActuelle = null;
  ouvrirListeConversations();
}

function afficherVueConversation() {
  if (!_conversationActuelle) return;
  const estSalon = _conversationActuelle.type === 'salon';
  let html = '<div style="display:flex;justify-content:space-between;align-items:center;padding:.4rem .6rem;border-bottom:1px solid #2a2010">';
  html += '<span style="font-size:.72rem;color:#8a8060;cursor:pointer" onclick="retourListeConversations()">← Conversations</span>';
  html += '<span style="font-size:.78rem;color:#C9A84C">' + (estSalon ? '💬 ' : '🔒 ') + _conversationActuelle.label + '</span>';
  html += estSalon ? '<span style="font-size:.85rem;color:#aa5050;cursor:pointer" onclick="quitterSalonActuelChat()">Quitter</span>' : '<span></span>';
  html += '</div>';
  html += '<div id="chat-messages-zone" style="flex:1;overflow-y:auto;padding:.4rem .6rem"></div>';
  html += '<div style="display:flex;gap:.4rem;padding:.5rem .6rem;border-top:1px solid #2a2010">' +
    '<input id="chat-message-input" type="text" placeholder="Votre message..." onkeydown="if(event.key===\'Enter\')envoyerMessageConversation()" style="flex:1;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:1rem;outline:none">' +
    '<button onclick="envoyerMessageConversation()" style="background:transparent;border:1px solid #8a6a20;color:#C9A84C;padding:.4rem .6rem;cursor:pointer;font-size:.78rem">→</button></div>';
  document.getElementById('chat-piece-body').innerHTML = html;

  _chatDernierMessage = null;
  rafraichirConversationActuelle(true);
  _chatInterval = setInterval(() => rafraichirConversationActuelle(false), 4000);
}

async function quitterSalonActuelChat() {
  if (!_conversationActuelle || _conversationActuelle.type !== 'salon') return;
  if (typeof sbQuitterSalon === 'function') {
    await sbQuitterSalon(_conversationActuelle.id, state.char?.name).catch(() => {});
  }
  retourListeConversations();
}

async function rafraichirConversationActuelle(reset) {
  if (!_conversationActuelle || typeof sbGetMessagesConversation !== 'function') return;
  try {
    const messages = await sbGetMessagesConversation(_conversationActuelle.id, reset ? null : _chatDernierMessage);
    const moi = state.char?.name;
    const zone = document.getElementById('chat-messages-zone');
    if (!zone) return;
    if (!messages || messages.length === 0) {
      if (reset && zone.children.length === 0) zone.innerHTML = '<div style="font-size:.72rem;color:#6a5a30;font-style:italic">Aucun message pour le moment.</div>';
      return;
    }
    if (reset) zone.innerHTML = '';
    messages.forEach(m => {
      const estMoi = m.auteur === moi;
      zone.insertAdjacentHTML('beforeend',
        '<div style="margin-bottom:.4rem;text-align:' + (estMoi ? 'right' : 'left') + '">' +
        '<div style="display:inline-block;max-width:80%;padding:.35rem .6rem;border-radius:8px;background:#0f0d05;border:1px solid #2a2010">' +
        '<div style="font-size:.9rem;color:#a08850">' + m.auteur + '</div>' +
        '<div style="font-size:1rem;color:#e0d8c0">' + m.message + '</div>' +
        '</div></div>'
      );
    });
    zone.scrollTop = zone.scrollHeight;
    _chatDernierMessage = messages[messages.length - 1].created_at;
    if (typeof sbMarquerConversationLue === 'function') sbMarquerConversationLue(_conversationActuelle.id, moi).catch(() => {});
    verifierNotificationChat();
  } catch(e) { console.warn('rafraichirConversationActuelle error', e); }
}

async function envoyerMessageConversation() {
  const input = document.getElementById('chat-message-input');
  const texte = input?.value?.trim();
  if (!texte || !_conversationActuelle) return;
  input.value = '';
  if (typeof sbEnvoyerMessageChat === 'function') {
    await sbEnvoyerMessageChat(_conversationActuelle.id, state.char?.name || 'Anonyme', texte, _conversationActuelle.type === 'salon').catch(() => {});
  }
  rafraichirConversationActuelle(false);
}

// Point clignotant persistant sur le bouton chat flottant, verifie regulierement
// (survit a une deconnexion : le message reste marque non-lu tant qu'on n'a pas ouvert
// la conversation, meme si l'auteur est reparti ou hors ligne entre temps).
let _dernierEtatNonLuChat = false;
async function verifierNotificationChat() {
  if (typeof sbAMessagesNonLus !== 'function' || !state.char?.name) return;
  try {
    const nonLu = await sbAMessagesNonLus(state.char.name);
    const badge = document.getElementById('chat-notif-badge');
    if (badge) badge.style.display = nonLu ? 'block' : 'none';

    if (nonLu && !_dernierEtatNonLuChat) {
      const panel = document.getElementById('chat-piece-panel');
      if (panel && panel.style.display !== 'flex') {
        panel.style.display = 'flex';
        if (typeof ouvrirListeConversations === 'function') ouvrirListeConversations();
      }
    }
    _dernierEtatNonLuChat = nonLu;
  } catch(e) {}
}

function demarrerPollingNotificationChat() {
  if (_chatNotifInterval) return;
  verifierNotificationChat();
  _chatNotifInterval = setInterval(verifierNotificationChat, 15000);
}
