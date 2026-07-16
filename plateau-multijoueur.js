// =====================
// PLATEAU-MULTIJOUEUR.JS
// Personnes presentes, groupe, employes PNJ, recrutement, escort
// =====================

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

    if (p.estJoueurReel) {
      return '<div class="person-card" onclick="composerMailPour(\'' + p.name.replace(/'/g, "\\'") + '\')" title="Envoyer un message">' +
        avatarHtml +
        '<div>' +
        '<div class="person-name">' + p.name + '</div>' +
        '<div class="person-role" style="color:#6a9aca">Joueur — cliquer pour contacter</div>' +
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
  document.getElementById('modal-postes').classList.remove('open');
  showToast('Temporairement indisponible', 'Le recrutement de PNJ comme employé est en cours de refonte.', false);
  return;
  // Code ci-dessous desactive temporairement (duplication de PNJ en cours de refonte)
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
  updateUI();
  renderEmployesPanel();
  tracerActionPourRumeur('escort', null);

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

function toggleChatPiece() {
  const panel = document.getElementById('chat-piece-panel');
  if (!panel) return;
  const ouvert = panel.style.display !== 'none';
  if (ouvert) {
    panel.style.display = 'none';
    if (_chatInterval) { clearInterval(_chatInterval); _chatInterval = null; }
  } else {
    panel.style.display = 'flex';
    chargerDestinatairesChat();
    rafraichirChatPiece(true);
    _chatInterval = setInterval(() => rafraichirChatPiece(false), 4000);
  }
}

// Liste deroulante des destinataires possibles (salon + chaque PJ present)
async function chargerDestinatairesChat() {
  const select = document.getElementById('chat-destinataire-select');
  if (!select) return;

  let presents = [];
  if (typeof sbGetPresencesInRoom === 'function' && state.currentBuilding && state.currentRoom) {
    try {
      const tous = await sbGetPresencesInRoom(state.country, state.currentCity, state.currentBuilding, state.currentRoom);
      presents = (tous || []).filter(p => p.name !== state.char?.name);
    } catch(e) {}
  }

  let html = '<option value="">💬 Salon de la pièce (tout le monde)</option>';
  presents.forEach(p => { html += '<option value="' + p.name + '">🔒 ' + p.name + ' (privé)</option>'; });
  select.innerHTML = html;
}

function changerDestinataireChat() {
  const select = document.getElementById('chat-destinataire-select');
  _chatDestinataire = select?.value || null;
  document.getElementById('chat-messages-zone').innerHTML = '';
  _chatDernierMessage = null;
  rafraichirChatPiece(true);
}

async function rafraichirChatPiece(reset) {
  if (typeof sbGetMessagesChatPiece !== 'function') return;
  if (!state.currentBuilding || !state.currentRoom) return;

  try {
    const messages = await sbGetMessagesChatPiece(
      state.country, state.currentCity, state.currentBuilding, state.currentRoom,
      reset ? null : _chatDernierMessage
    );
    if (!messages || messages.length === 0) return;

    const moi = state.char?.name;
    const zone = document.getElementById('chat-messages-zone');
    if (!zone) return;

    const pertinents = messages.filter(m => {
      if (!m.destinataire) return true; // message de salon, visible par tous
      // message prive : visible seulement par l'auteur et le destinataire concerne
      return m.auteur === moi || m.destinataire === moi;
    });

    if (reset) zone.innerHTML = '';

    pertinents.forEach(m => {
      const estMoi = m.auteur === moi;
      const estPrive = !!m.destinataire;
      const couleurFond = estPrive ? '#1a1408' : '#0f0d05';
      const labelPrive = estPrive ? '<span style="color:#aa7a30;font-size:.6rem"> (privé)</span>' : '';
      zone.insertAdjacentHTML('beforeend',
        '<div style="margin-bottom:.4rem;text-align:' + (estMoi ? 'right' : 'left') + '">' +
        '<div style="display:inline-block;max-width:80%;padding:.35rem .6rem;border-radius:8px;background:' + couleurFond + ';border:1px solid #2a2010">' +
        '<div style="font-size:.62rem;color:#8a6a30">' + m.auteur + labelPrive + '</div>' +
        '<div style="font-size:.78rem;color:#e0d8c0">' + m.message + '</div>' +
        '</div></div>'
      );
    });

    zone.scrollTop = zone.scrollHeight;
    _chatDernierMessage = messages[messages.length - 1].created_at;
  } catch(e) { console.warn('rafraichirChatPiece error', e); }
}

async function envoyerMessageChatPiece() {
  const input = document.getElementById('chat-message-input');
  const texte = input?.value?.trim();
  if (!texte || !state.currentBuilding || !state.currentRoom) return;

  const message = {
    id: 'chat-' + Date.now() + '-' + Math.floor(Math.random()*1000),
    country: state.country,
    city: state.currentCity,
    building_id: state.currentBuilding,
    room_id: state.currentRoom,
    auteur: state.char?.name || 'Anonyme',
    destinataire: _chatDestinataire || null,
    message: texte
  };

  input.value = '';
  if (typeof sbEnvoyerMessageChat === 'function') {
    await sbEnvoyerMessageChat(message).catch(() => {});
  }
  rafraichirChatPiece(false);
}

// Fermer le chat automatiquement au changement de piece (rien a garder)
function reinitialiserChatPiece() {
  const zone = document.getElementById('chat-messages-zone');
  if (zone) zone.innerHTML = '';
  _chatDernierMessage = null;
  _chatDestinataire = null;
  if (document.getElementById('chat-piece-panel')?.style.display !== 'none') {
    chargerDestinatairesChat();
  }
}
