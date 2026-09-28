// =====================================================================
// PLATEAU-CAMION-MILITAIRE.JS — LE CAMION EST UNE PIECE QUI SE DEPLACE
// 29 septembre 2026
// =====================================================================
//
// CE QUE CE FICHIER N'EST PAS. Ce n'est pas un taxi renomme, pas une
// teleportation, pas une modale qui imite une piece, et rien ici ne connait
// Vince, la caserne de Luthecia ni Republia. Le camion est un OBJET SERVEUR qui
// a une position ; son interieur est une PIECE ORDINAIRE du jeu, dont la ville
// est celle du camion.
//
// LES TROIS REUTILISATIONS QUI EVITENT UN SECOND MOTEUR.
//
//   1. LE BATIMENT SYNTHETIQUE. Le precedent est 'rue-centrale' : un
//      identifiant de batiment qui ne designe aucun batiment de la carte mais un
//      CONTEXTE de presence, deja porte tel quel par `presences` et par
//      personnages_donnees.current_building. L'interieur du camion, c'est
//      (batiment = 'camion-militaire', piece = <id du camion>).
//
//   2. LA PIECE INJECTEE A CHAUD. Le precedent est hydraterPiecesDynamiques
//      (plateau-immobilier.js) : les lots d'un terrain deviennent des pieces
//      ordinaires de BUILDINGS au moment d'y entrer. On fait exactement pareil,
//      avec une seule piece a la fois -- celle du camion que l'on ouvre.
//
//   3. LE SOCLE leader -> accompagnants. On n'ecrit JAMAIS la position d'un
//      soldat. pnj_position_effective() la resout par celle de son chef :
//      un Lieutenant qui monte emmene sa section, un Lieutenant transporte
//      l'emmene, un Lieutenant qui descend la fait descendre. Zero ligne de
//      code militaire ici, et aucune liste speciale dans « Personnes
//      presentes » -- carteDetachementPiece fait deja le travail, comme dans
//      n'importe quelle autre piece.
//
// L'AUTORITE EST ENTIEREMENT SERVEUR. Capacite, priorite militaire, cout en PA,
// droit de commander, destinations : rien de tout cela n'est decide ici. Ce
// fichier demande et affiche.

// L'interieur de TOUS les camions partage ce batiment ; chaque camion est une
// piece. Meme valeur que camion_batiment_interieur() cote serveur.
const RP_CAMION_BATIMENT = 'camion-militaire';

// Fond de repli de l'interieur, utilise tant que l'image n'est pas deposee dans
// le depot. On ne fabrique aucune image de remplacement : le chemin attendu est
// une DONNEE (camions_militaires.image_url), et son absence ne bloque rien.
const RP_CAMION_FOND_REPLI = 'linear-gradient(135deg,#0c1208,#141a0c 45%,#0a0f06)';

// Camions stationnes dans la piece courante (vue EXTERIEURE). Relu a chaque
// entree de piece et toutes les 30 s : un camion qui part fait disparaitre le
// bouton, un camion qui arrive le fait apparaitre.
let RP_CAMIONS_ICI = [];

// Etat du camion dans lequel je me trouve (vue INTERIEURE), ou null. Porte
// aussi mon droit de commander et la liste des destinations -- tous deux
// decides par le serveur.
let RP_CAMION_ETAT = null;

// Veille de bord : tant que je suis dedans, je redemande l'etat. C'est la
// SEULE concession au multijoueur de ce lot -- le jeu n'a aucun temps reel, et
// un occupant transporte par un officier doit pouvoir s'en apercevoir.
let RP_CAMION_VEILLE = null;
const RP_CAMION_VEILLE_MS = 10000;

// Signature du dernier contexte rendu : evite de redessiner les ordres a chaque
// passage de la veille alors que rien n'a bouge.
let RP_CAMION_SIGNATURE = '';

// ---------------------------------------------------------------------------
// LE BATIMENT D'ACCUEIL
// ---------------------------------------------------------------------------
// Declare ici plutot que dans data.js : ce n'est pas un lieu de la carte, il
// n'apparait sur aucune minimap (renderMinimap ne lit que city.buildings, ou il
// ne figure pas) et ses pieces sont entierement dynamiques.
function camionDeclarerBatiment() {
  if (typeof BUILDINGS === 'undefined') return;
  if (!BUILDINGS[RP_CAMION_BATIMENT]) {
    BUILDINGS[RP_CAMION_BATIMENT] = {
      name: 'Camion militaire',
      shortName: 'Camion',
      cat: 'Militaire — véhicule',
      icon: 'ti-truck',
      bgColor: '#0a0f06',
      desc: "L'intérieur bâché d'un camion de transport de troupe.",
      rooms: {}
    };
  }
}
camionDeclarerBatiment();

// Une piece par camion, et une seule a la fois : on repart d'un objet vide pour
// qu'un ancien camion ne laisse jamais un onglet fantome derriere lui.
//
// `sortieVers` est lu par sortirBatiment (plateau-navigation.js) : c'est la
// facon generique de dire « la sortie de cette piece ne donne pas sur la rue,
// mais sur ce lieu-la ». Un camion stationne au corps de garde rend au corps de
// garde, pas au trottoir de la caserne.
function camionInjecterPiece(camion) {
  camionDeclarerBatiment();
  if (typeof BUILDINGS === 'undefined' || !camion || !camion.id) return null;
  const b = BUILDINGS[RP_CAMION_BATIMENT];
  b.rooms = {};
  b.rooms[camion.id] = {
    name: camion.libelle || 'Camion militaire',
    imageUrl: camion.image_url || null,
    imageBg: RP_CAMION_FOND_REPLI,
    desc: "L'intérieur bâché du camion. Deux bancs face à face, dos à la ridelle.",
    persons: [],
    orders: [],
    sortieVers: {
      city: camion.ville, buildingId: camion.building_id, roomId: camion.room_id,
      handler: 'camionSortieDeleguee'
    }
  };
  return b.rooms[camion.id];
}

// ---------------------------------------------------------------------------
// ORDRES — QUATRIEME SOURCE DYNAMIQUE
// ---------------------------------------------------------------------------
// Meme mecanisme que les ordres de commerce (C6) : renderRoomActions interroge
// un REGISTRE de sources dynamiques, et chaque mecanique y depose la sienne. Ce
// fichier n'ajoute donc pas une exception de plus dans renderRoomActions, il
// s'inscrit dans le registre.
//
// Rien n'est decide ici : la liste vient du dernier etat serveur connu. Quand
// il est inconnu, la fonction rend une liste vide et absolument rien ne change.
function ordresCamionDuLieu(buildingId, roomId /*, ville */) {
  const base = { pa: 0, cost: 0, type: 'legal', successRate: 100 };

  // VUE INTERIEURE — je suis dans un camion.
  if (buildingId === RP_CAMION_BATIMENT) {
    const e = RP_CAMION_ETAT;
    if (!e || !e.camion || e.camion.id !== roomId) return [];
    const ordres = [Object.assign({}, base, {
      fn: 'camion_descendre', icon: 'ti-arrow-down-circle',
      label: 'Descendre du camion',
      desc: 'Revenir dans le lieu où le camion est stationné. Gratuit. Vos accompagnants descendent avec vous.'
    })];
    // Un civil ne voit AUCUNE commande : ni grisee, ni barree. Il n'a rien a
    // faire du volant, et un bouton mort n'informe personne.
    if (!e.peut_commander) return ordres;

    ordres.push(Object.assign({}, base, {
      fn: 'camion_conduire', icon: 'ti-steering-wheel',
      label: 'Conduire le camion vers…',
      desc: 'Vous voyagez avec le camion. 2 PA par occupant réellement transporté, chacun sur ses propres PA.'
    }));
    if (e.grade === 'lieutenant') {
      ordres.push(Object.assign({}, base, {
        fn: 'camion_a_vide', icon: 'ti-truck-return',
        label: 'Retour à vide à la caserne',
        desc: 'Vous donnez l\'ordre et restez ici avec votre section. Les autres occupants restent à bord et sont transportés.'
      }));
    } else if (e.grade === 'capitaine') {
      ordres.push(Object.assign({}, base, {
        fn: 'camion_a_vide', icon: 'ti-truck-delivery',
        label: 'Envoyer à vide vers…',
        desc: 'Vous donnez l\'ordre et restez ici. Les autres occupants restent à bord et sont transportés.'
      }));
    }
    return ordres;
  }

  // VUE EXTERIEURE — un ou plusieurs camions stationnent ici.
  if (!RP_CAMIONS_ICI.length) return [];
  return [Object.assign({}, base, {
    fn: 'camion_militaire', icon: 'ti-truck',
    label: RP_CAMIONS_ICI.length > 1
      ? 'Camions militaires (' + RP_CAMIONS_ICI.length + ')' : 'Camion militaire',
    desc: 'Monter dans le camion. Gratuit, et le véhicule ne bouge pas.'
  })];
}

// Inscription au registre partage. Le registre est cree ici s'il n'existe pas
// encore : l'ordre de chargement des fichiers ne doit jamais decider de ce qui
// marche.
if (typeof window !== 'undefined') {
  window.RP_ORDRES_DYNAMIQUES = window.RP_ORDRES_DYNAMIQUES || [];
  if (!window.RP_ORDRES_DYNAMIQUES.includes(ordresCamionDuLieu)) {
    window.RP_ORDRES_DYNAMIQUES.push(ordresCamionDuLieu);
  }
}

// ---------------------------------------------------------------------------
// RAFRAICHISSEMENT DU CONTEXTE
// ---------------------------------------------------------------------------
// Un seul point d'entree, appele depuis enterRoom et depuis la boucle de
// presence de 30 s. Il ne fait rien hors des lieux concernes, redessine les
// ordres lui-meme quand -- et seulement quand -- quelque chose a change.
async function camionRafraichirContexte() {
  if (typeof state === 'undefined' || !state.char || !state.currentBuilding || !state.currentRoom) {
    RP_CAMIONS_ICI = []; RP_CAMION_ETAT = null; return false;
  }
  const bat = state.currentBuilding, piece = state.currentRoom;

  if (bat === RP_CAMION_BATIMENT) {
    if (typeof sbCamionEtat !== 'function') return false;
    const e = await sbCamionEtat(piece).catch(() => null);
    if (!e || e.ok !== true) return false;
    if (state.currentBuilding !== bat || state.currentRoom !== piece) return false;
    RP_CAMION_ETAT = e;
    RP_CAMIONS_ICI = [];
    return camionAppliquerEtat(e);
  }

  RP_CAMION_ETAT = null;
  if (typeof sbCamionsIci !== 'function') return false;
  const r = await sbCamionsIci(state.country, state.currentCity, bat, piece).catch(() => null);
  if (!r || r.ok !== true) return false;
  if (state.currentBuilding !== bat || state.currentRoom !== piece) return false;
  RP_CAMIONS_ICI = r.camions || [];
  return camionRedessinerSiChange('ext|' + bat + '|' + piece + '|' +
    RP_CAMIONS_ICI.map(c => c.id).join(','));
}

function camionRedessinerSiChange(signature) {
  if (signature === RP_CAMION_SIGNATURE) return false;
  RP_CAMION_SIGNATURE = signature;
  if (typeof renderRoomActions !== 'function') return true;
  const b = (typeof BUILDINGS !== 'undefined') ? BUILDINGS[state.currentBuilding] : null;
  const room = b && b.rooms ? b.rooms[state.currentRoom] : null;
  if (room) renderRoomActions(room, state.currentBuilding, state.currentRoom);
  return true;
}

// ---------------------------------------------------------------------------
// LE CAMION A BOUGE PENDANT QUE JE REGARDAIS AILLEURS
// ---------------------------------------------------------------------------
// Trois situations, et une seule regle : LE SERVEUR A RAISON.
//   - il dit que je ne suis plus dedans  -> je vais ou il dit que je suis ;
//   - il dit que le camion a change de ville -> j'y suis, et je le vois ;
//   - rien n'a bouge -> je ne redessine rien.
function camionAppliquerEtat(e) {
  const cam = e.camion || {};
  const moi = e.moi || {};

  // Debarque ou transporte hors du camion par un ordre d'un autre joueur.
  if (e.dedans !== true) {
    RP_CAMION_ETAT = null;
    camionArreterVeille();
    camionNaviguerVers(moi.ville, moi.building_id, moi.room_id);
    if (typeof showToast === 'function') {
      showToast('Vous n\'êtes plus à bord',
        'Le camion est reparti sans vous. Vous êtes resté(e) sur place.', false);
    }
    return true;
  }

  // Le camion m'a emmene : seule la VILLE change, je n'ai pas quitte la piece.
  if (moi.ville && state.currentCity !== moi.ville) {
    camionPoserVille(moi.ville);
    if (typeof showToast === 'function') {
      showToast('Le camion est arrivé',
        'Vous êtes transporté(e) jusqu\'à ' + camionNomVille(moi.ville) + '.', true);
    }
    if (typeof addJournalEntry === 'function') {
      addJournalEntry('Transporté(e) en camion militaire jusqu\'à ' + camionNomVille(moi.ville) + '.', 'event-info');
    }
  }
  // Les PA debites par le serveur redescendent ici. Une BAISSE seulement : le
  // verrou de la fiche ignore de toute facon toute hausse cliente.
  if (typeof moi.pa === 'number' && moi.pa < (state.pa || 0)) {
    state.pa = moi.pa;
    if (typeof updateUI === 'function') updateUI();
  }
  camionInjecterPiece(cam);
  return camionRedessinerSiChange('int|' + cam.id + '|' + cam.ville + '|' +
    (e.peut_commander ? '1' : '0') + '|' + (e.grade || '') + '|' + (e.occupants_total || 0));
}

function camionNomVille(villeId) {
  if (typeof WORLD !== 'undefined' && WORLD[state.country] && WORLD[state.country][villeId]) {
    return WORLD[state.country][villeId].name || villeId;
  }
  return villeId;
}

// Changement de VILLE sans changement de piece : le joueur n'a pas bouge dans le
// camion, c'est le camion qui a bouge. On ecrit la ville partout ou elle vit,
// puis on laisse l'entree de piece republier la presence.
function camionPoserVille(villeId) {
  state.currentCity = villeId;
  if (state.char) {
    state.char.currentCity = villeId;
    try {
      localStorage.setItem('respublica_char_' + (state.char.name || 'default'), JSON.stringify(state.char));
      localStorage.setItem('respublica_char', JSON.stringify(state.char));
    } catch (e) { /* quota : sans effet, la verite est au serveur */ }
  }
  if (typeof applyEmpireTheme === 'function') applyEmpireTheme(state.country);
  if (typeof updateLocationDisplay === 'function') updateLocationDisplay();
  if (typeof sbUpdatePresence === 'function' && state.char && state.char.name) {
    sbUpdatePresence(state.char.name, state.country, villeId,
      state.currentBuilding, state.currentRoom).catch(() => {});
  }
}

// Navigation ordinaire vers un couple batiment/piece, en changeant de ville si
// besoin. Aucune mecanique nouvelle : enterBuilding + enterRoom, comme partout.
function camionNaviguerVers(villeId, buildingId, roomId) {
  if (!buildingId || !roomId) return;
  if (villeId && state.currentCity !== villeId) {
    state.currentCity = villeId;
    if (state.char) state.char.currentCity = villeId;
    if (typeof buildCityTabs === 'function') buildCityTabs();
  }
  if (typeof enterBuilding === 'function') enterBuilding(buildingId, true);
  if (typeof enterRoom === 'function') enterRoom(buildingId, roomId, null);
  if (typeof updateUI === 'function') updateUI();
}

// ---------------------------------------------------------------------------
// VEILLE DE BORD
// ---------------------------------------------------------------------------
// Uniquement tant que je suis a bord, uniquement sur ce camion, et arretee des
// que j'en descends. Ce n'est pas un moteur de temps reel : c'est la plus petite
// chose qui permette a un passager de constater qu'on l'a emmene.
function camionDemarrerVeille() {
  camionArreterVeille();
  RP_CAMION_VEILLE = setInterval(() => {
    if (typeof state === 'undefined' || state.currentBuilding !== RP_CAMION_BATIMENT) {
      camionArreterVeille(); return;
    }
    camionRafraichirContexte().catch(() => {});
  }, RP_CAMION_VEILLE_MS);
}

function camionArreterVeille() {
  if (RP_CAMION_VEILLE) { clearInterval(RP_CAMION_VEILLE); RP_CAMION_VEILLE = null; }
}

// ---------------------------------------------------------------------------
// MONTER
// ---------------------------------------------------------------------------
function doCamionMilitaire() {
  if (!RP_CAMIONS_ICI.length) {
    if (typeof showToast === 'function') {
      showToast('Aucun camion ici', 'Le camion n\'est plus stationné à cet endroit.', false);
    }
    camionRafraichirContexte().catch(() => {});
    return;
  }
  if (RP_CAMIONS_ICI.length === 1) { camionMonter(RP_CAMIONS_ICI[0].id).catch(function () {}); return; }
  camionChoisir('Monter dans un camion', RP_CAMIONS_ICI.map(c => ({
    cle: c.id,
    libelle: c.libelle + ' — ' + c.occupants + '/' + c.capacite + ' à bord'
  })), 'camionMonter');
}

async function camionMonter(camionId) {
  camionFermerModale();
  if (typeof sbCamionMonter !== 'function') return;
  const r = await sbCamionMonter(camionId, nouvelleCleCamion());
  if (!r || r.ok !== true) { camionSignalerRefus(r, 'Impossible de monter'); return; }
  if (Array.isArray(r.debarques) && r.debarques.length > 0 && typeof showToast === 'function') {
    showToast('Place faite', 'Votre section embarque : ' + r.debarques.length +
      ' occupant(s) ont dû descendre.', true);
  }
  await camionEntrerDansLaPiece(camionId);
}

// Entrer PHYSIQUEMENT dans la piece du camion. La position serveur est deja
// posee par camion_monter ; on relit l'etat pour connaitre l'image, le libelle
// et les droits, puis on entre comme dans n'importe quelle piece.
async function camionEntrerDansLaPiece(camionId) {
  const e = await sbCamionEtat(camionId).catch(() => null);
  if (!e || e.ok !== true) { camionSignalerRefus(e, 'Camion indisponible'); return; }
  RP_CAMION_ETAT = e;
  RP_CAMIONS_ICI = [];
  RP_CAMION_SIGNATURE = '';
  camionInjecterPiece(e.camion);
  if (e.camion && e.camion.ville && state.currentCity !== e.camion.ville) {
    state.currentCity = e.camion.ville;
    if (state.char) state.char.currentCity = e.camion.ville;
  }
  if (typeof enterBuilding === 'function') enterBuilding(RP_CAMION_BATIMENT, true);
  if (typeof enterRoom === 'function') enterRoom(RP_CAMION_BATIMENT, camionId, null);

  // RECONCILIATION. enterBuilding porte des verrous d'etat qui lui sont propres
  // -- detention, hospitalisation, surcharge d'inventaire -- et peut donc
  // refuser l'entree apres que le serveur a deja pose la position. Plutot que de
  // laisser diverger les deux, on redescend proprement : le serveur redevient
  // d'accord avec l'ecran, et le joueur lit le motif du refus que le verrou a
  // deja affiche.
  if (state.currentBuilding !== RP_CAMION_BATIMENT) {
    await sbCamionDescendre(camionId).catch(() => null);
    RP_CAMION_ETAT = null;
    return;
  }

  camionDemarrerVeille();
  if (typeof addJournalEntry === 'function') addJournalEntry('Vous montez dans le camion militaire.', '');
}

// ---------------------------------------------------------------------------
// DESCENDRE
// ---------------------------------------------------------------------------
async function doCamionDescendre() {
  const e = RP_CAMION_ETAT;
  if (!e || !e.camion) return;
  const r = await sbCamionDescendre(e.camion.id);
  if (!r || r.ok !== true) { camionSignalerRefus(r, 'Impossible de descendre'); return; }
  camionArreterVeille();
  RP_CAMION_ETAT = null;
  RP_CAMION_SIGNATURE = '';
  camionNaviguerVers(r.ville, r.building_id, r.room_id);
  if (typeof addJournalEntry === 'function') addJournalEntry('Vous descendez du camion militaire.', '');
}

// Sortie generique du batiment (bouton « Sortir ») : la piece declare
// `sortieVers`, sortirBatiment la lit. On passe malgre tout par la RPC, pour que
// la position serveur soit celle du lieu de stationnement et non de la rue.
function camionSortieDeleguee() {
  doCamionDescendre().catch(() => {});
}

// ---------------------------------------------------------------------------
// CONDUIRE / ENVOYER
// ---------------------------------------------------------------------------
function doCamionConduire() {
  const e = RP_CAMION_ETAT;
  if (!e || !e.peut_commander) return;
  const dests = e.destinations || [];
  if (!dests.length) {
    if (typeof showToast === 'function') showToast('Aucune destination', 'Ce camion est déjà partout où il peut aller.', false);
    return;
  }
  camionChoisir('Conduire le camion vers…', dests, 'camionPartir', true);
}

function doCamionAVide() {
  const e = RP_CAMION_ETAT;
  if (!e || !e.peut_commander) return;
  // Le Lieutenant ne renvoie le camion qu'a SA caserne : aucun choix a lui
  // proposer. Le serveur applique la meme regle, cet ecran ne fait que la
  // refleter.
  if (e.grade === 'lieutenant') { camionPartirAVide('__caserne__'); return; }
  const dests = e.destinations || [];
  if (!dests.length) {
    if (typeof showToast === 'function') showToast('Aucune destination', 'Ce camion est déjà partout où il peut aller.', false);
    return;
  }
  camionChoisir('Envoyer le camion à vide vers…', dests, 'camionPartirAVide', true);
}

// Ces deux entrees sont appelees depuis un onclick : elles ne rendent pas de
// promesse a qui les appelle, donc elles avalent elles-memes tout rejet.
function camionPartir(destinationCle)      { camionDeplacer(destinationCle, true).catch(function () {}); }
function camionPartirAVide(destinationCle) { camionDeplacer(destinationCle, false).catch(function () {}); }

async function camionDeplacer(destinationCle, avecOfficier) {
  camionFermerModale();
  const e = RP_CAMION_ETAT;
  if (!e || !e.camion) return;
  const camionId = e.camion.id;
  const r = await sbCamionDeplacer(camionId, destinationCle, avecOfficier, nouvelleCleCamion());
  if (!r || r.ok !== true) { camionSignalerRefus(r, 'Le camion ne part pas'); return; }

  const arrivee = r.arrivee || {};
  const nbPj = Array.isArray(r.transportes_pj) ? r.transportes_pj.length : 0;
  const nbPnj = r.transportes_pnj || 0;
  const detail = (nbPj + nbPnj) + ' occupant(s) transporté(s), ' + (r.cout_par_occupant || 2) + ' PA chacun.';

  if (avecOfficier) {
    if (typeof showToast === 'function') showToast('En route', arrivee.libelle + '. ' + detail, true);
    if (typeof addJournalEntry === 'function') {
      addJournalEntry('Camion militaire : trajet vers ' + arrivee.libelle + '. ' + detail, 'event-info');
    }
    RP_CAMION_SIGNATURE = '';
    await camionEntrerDansLaPiece(camionId);   // toujours a bord, ville nouvelle
  } else {
    if (typeof showToast === 'function') {
      showToast('Camion envoyé', 'Le camion part pour ' + arrivee.libelle + '. ' +
        (nbPj + nbPnj > 0 ? detail : 'Personne à bord.'), true);
    }
    if (typeof addJournalEntry === 'function') {
      addJournalEntry('Camion militaire renvoyé à vide vers ' + arrivee.libelle + '.', 'event-info');
    }
    camionArreterVeille();
    RP_CAMION_ETAT = null;
    RP_CAMION_SIGNATURE = '';
    const dep = r.depart || {};
    camionNaviguerVers(dep.ville, dep.building_id, dep.room_id);
  }
}

// ---------------------------------------------------------------------------
// PETITE MODALE DE CHOIX — celle du jeu, pas une nouvelle
// ---------------------------------------------------------------------------
function camionChoisir(titre, options, handler) {
  const ech = (t) => (typeof escapeHtmlText === 'function') ? escapeHtmlText(String(t == null ? '' : t)) : String(t == null ? '' : t);
  let html = '<div style="padding:1rem">';
  options.forEach(o => {
    html += '<div onclick="' + handler + '(\'' + String(o.cle).replace(/'/g, '') + '\')" ' +
      'style="padding:.6rem .8rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;cursor:pointer" ' +
      'onmouseover="this.style.background=\'#151005\'" onmouseout="this.style.background=\'#0f0d05\'">' +
      '<div style="font-size:.85rem;color:#c0b090">' + ech(o.libelle) + '</div></div>';
  });
  html += '</div>';
  document.getElementById('postes-modal-title').textContent = titre;
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function camionFermerModale() {
  const m = document.getElementById('modal-postes');
  if (m) m.classList.remove('open');
}

// Un refus a une RAISON, et elle est dite. Un echec de transport n'est jamais
// presente comme un refus metier (lecon du chantier C5.1).
const RP_CAMION_RAISONS = {
  acteur_non_authentifie:   'Votre session a expiré. Rechargez la page.',
  camion_introuvable:       'Ce camion n\'existe plus.',
  camion_hors_service:      'Ce camion est hors service.',
  pas_sur_place:            'Vous n\'êtes pas à l\'endroit où le camion stationne.',
  pas_a_bord:               'Vous n\'êtes pas dans ce camion.',
  hors_de_mon_pays:         'Ce camion n\'appartient pas à votre pays.',
  camion_complet:           'Le camion est complet.',
  section_trop_nombreuse:   'Votre section est plus nombreuse que la capacité du camion.',
  capacite_insuffisante:    'Impossible de faire assez de place pour votre section.',
  capacite_depassee:        'Le camion transporte déjà plus que sa capacité : il ne part pas.',
  officier_absent_du_camion:'Vous devez être physiquement dans le camion pour donner cet ordre.',
  grade_insuffisant:        'Seuls un Lieutenant ou un Capitaine peuvent commander ce camion.',
  destination_refusee:      'Cette destination n\'est pas ouverte à ce camion.',
  envoi_a_vide_hors_caserne:'Un Lieutenant ne peut renvoyer le camion qu\'à sa caserne de rattachement.',
  pa_insuffisants_section:  'Un membre de votre section n\'a pas les 2 PA nécessaires : le départ est annulé, personne n\'a été débité.',
  cle_requete_absente:      'Ordre mal formé. Rouvrez l\'écran.',
  personnage_introuvable:   'Votre personnage est introuvable côté serveur.'
};

function camionSignalerRefus(r, titre) {
  const raison = (r && r.raison) || 'inconnu';
  const transport = r && r.transport;
  if (typeof showToast !== 'function') return;
  if (transport && transport.etat && transport.etat !== 'ok') {
    showToast('Action non aboutie',
      'La demande n\'a pas pu être envoyée au serveur (' + (transport.http || transport.etat) + ').', false);
    return;
  }
  showToast(titre || 'Refusé', RP_CAMION_RAISONS[raison] || ('Refusé : ' + raison), false);
}

// ---------------------------------------------------------------------------
// RESTAURATION APRES RECHARGEMENT DE PAGE
// ---------------------------------------------------------------------------
// La piece du camion n'existe pas au chargement : elle est injectee a l'entree.
// Meme traitement que les pieces de lot (restaurerPieceDynamiqueDifferee) : UNE
// seule tentative, apres la reponse du serveur, sans jamais insister.
let _camionRestaurationTentee = false;

async function camionRestaurerDifferee(camionId) {
  if (_camionRestaurationTentee) return false;
  _camionRestaurationTentee = true;
  if (typeof sbCamionEtat !== 'function') return false;
  const e = await sbCamionEtat(camionId).catch(() => null);
  if (!e || e.ok !== true) return false;
  if (e.dedans !== true) {
    // Le serveur dit que je n'y suis plus : je vais ou il dit que je suis.
    const moi = e.moi || {};
    camionNaviguerVers(moi.ville, moi.building_id, moi.room_id);
    return true;
  }
  await camionEntrerDansLaPiece(camionId);
  return true;
}
