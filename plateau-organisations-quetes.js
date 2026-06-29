// =====================
// PLATEAU-ORGANISATIONS-QUETES.JS
// Organisations (sauvegarde/chargement), systeme de quetes, loge maconnique
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

// Structure plate pour les organisations (prepare le support multi-empire futur)
// state.organisations est une liste a plat ; country_origine = empire de creation (regles/grades)

// =====================
// SYSTEME DE QUETES (animation plateau)
// =====================
const RECOMPENSES_QUETE = ['argent', 'objet', 'titre', 'dossier_surveillance']; // 'terrain' traite a part (necessite un terrain libre reel)

// Construit un resume compact des lieux/PNJ disponibles dans la ville courante, pour le prompt IA
function getLieuxDisponiblesPourQuete(country, city) {
  const lieux = [];
  const villeData = WORLD[country]?.[city];
  const buildingIds = villeData?.buildings || [];
  buildingIds.forEach(bId => {
    const b = BUILDINGS[bId];
    if (!b || !b.rooms) return;
    Object.entries(b.rooms).forEach(([roomId, room]) => {
      const persons = (room.persons || []).map(p => p.name.replace(' (PNJ)', ''));
      if (persons.length > 0) {
        lieux.push({ buildingId: bId, roomId, buildingName: b.name, roomName: room.name, pnjs: persons });
      }
    });
  });
  return lieux;
}

// Verifie s'il faut lancer une nouvelle quete (appelee periodiquement)
async function verifierLancementQuete() {
  if (typeof sbGetQueteActive !== 'function') return;
  try {
    const queteActive = await sbGetQueteActive(state.country);
    if (queteActive) return; // Une quete est deja en cours, on attend sa resolution

    const derniereResolue = await sbGetDerniereQueteResolue(state.country);
    const jourActuel = state.day || 1;
    if (derniereResolue) {
      const joursDepuisResolution = jourActuel - (derniereResolue.jour_creation || 0);
      if (joursDepuisResolution < 5) return; // Pas encore le moment de relancer
    }

    await lancerNouvelleQuete();
  } catch(e) { console.warn('verifierLancementQuete error', e); }
}

async function lancerNouvelleQuete() {
  const lieux = getLieuxDisponiblesPourQuete(state.country, state.currentCity || 'capitale');
  if (lieux.length === 0) return;

  const lieuChoisi = lieux[Math.floor(Math.random() * lieux.length)];
  const pnjChoisi = lieuChoisi.pnjs[Math.floor(Math.random() * lieuChoisi.pnjs.length)];
  const nbEtapes = Math.floor(Math.random() * 4) + 2; // 2 a 5 etapes

  // Tirage du "Graal" (terrain a batir) - tres rare, 5% ET seulement si un terrain est libre
  let recompenseType;
  let terrainGagnePotentiel = null;
  if (Math.random() < 0.05) {
    const terrainsLibres = await getTerrainsVraimentLibres(state.country);
    if (terrainsLibres.length > 0) {
      terrainGagnePotentiel = terrainsLibres[Math.floor(Math.random() * terrainsLibres.length)];
    }
  }
  recompenseType = terrainGagnePotentiel ? 'terrain' : RECOMPENSES_QUETE[Math.floor(Math.random() * RECOMPENSES_QUETE.length)];

  // Generer le titre/description de la quete via IA
  const co = COUNTRIES[state.country];
  let titre = 'Une affaire mystérieuse', description = 'Une étrange rumeur circule dans la ville.';
  try {
    const resp = await fetch('/api/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: 'claude-sonnet-4-5', max_tokens: 150,
        messages: [{ role: 'user', content: 'Jeu politique parodique dans ' + (co?.n||'un empire') + '. Genere un TITRE court (5 mots max) et une DESCRIPTION (2 phrases) pour une quete/enquete mysterieuse que les joueurs peuvent resoudre. Format : TITRE: ... DESCRIPTION: ...' }]
      })
    });
    const data = await resp.json();
    const texte = data.content?.[0]?.text || '';
    const mTitre = texte.match(/TITRE:\\s*(.+)/);
    const mDesc = texte.match(/DESCRIPTION:\\s*(.+)/);
    if (mTitre) titre = mTitre[1].trim();
    if (mDesc) description = mDesc[1].trim();
  } catch(e) {}

  const quete = {
    id: 'quete-' + Date.now(),
    country: state.country,
    titre, description,
    etape_actuelle: 1,
    nb_etapes_total: nbEtapes,
    building_id: lieuChoisi.buildingId,
    room_id: lieuChoisi.roomId,
    pnj_actif: pnjChoisi,
    recompense_type: recompenseType,
    recompense_detail: terrainGagnePotentiel ? JSON.stringify(terrainGagnePotentiel) : null,
    cible_dossier: recompenseType === 'dossier_surveillance' ? await choisirCibleDossier(state.country) : null,
    statut: 'active',
    jour_creation: state.day || 1
  };

  if (typeof sbCreerQuete === 'function') {
    await sbCreerQuete(quete).catch(() => {});
  }

  const villeNom = WORLD[state.country]?.[state.currentCity]?.name || state.currentCity;
  addExternalEvent('🔍 ' + titre + ' — une nouvelle affaire à élucider à ' + villeNom + '.', 'national');
}

// Choisit un PJ avec poste comme cible pour la recompense "dossier de surveillance"
async function choisirCibleDossier(country) {
  if (typeof sbListPersonnages !== 'function') return null;
  try {
    const joueurs = await sbListPersonnages() || [];
    const avecPoste = joueurs.filter(j => j.country === country && j.poste);
    if (avecPoste.length === 0) return null;
    return avecPoste[Math.floor(Math.random() * avecPoste.length)].name;
  } catch(e) { return null; }
}

// =====================
// PROGRESSION DANS UNE QUETE (clic sur le bon PNJ)
// =====================

// Verifie si le PNJ clique correspond a une quete active, et affiche le bouton si oui
async function getQueteActivePourPnj(nomPnj) {
  if (typeof sbGetQueteActive !== 'function') return null;
  try {
    const quete = await sbGetQueteActive(state.country);
    if (!quete) return null;
    if (quete.building_id !== state.currentBuilding || quete.room_id !== state.currentRoom) return null;
    if (quete.pnj_actif !== nomPnj) return null;
    return quete;
  } catch(e) { return null; }
}

async function progresserQuete(queteId) {
  document.getElementById('modal-pnj')?.classList.remove('open');
  if (typeof sbGetQueteActive !== 'function') return;
  const quete = await sbGetQueteActive(state.country);
  if (!quete || quete.id !== queteId) { showToast('Trop tard', 'Cette piste a déjà été suivie par quelqu\'un d\'autre.', false); return; }

  const etapeSuivante = quete.etape_actuelle + 1;

  if (etapeSuivante > quete.nb_etapes_total) {
    // DERNIERE ETAPE — remettre la recompense
    await remettreRecompenseQuete(quete);
    return;
  }

  // Generer la nouvelle etape : nouveau lieu/PNJ
  const lieux = getLieuxDisponiblesPourQuete(state.country, state.currentCity || 'capitale');
  if (lieux.length === 0) return;
  const lieuChoisi = lieux[Math.floor(Math.random() * lieux.length)];
  const pnjChoisi = lieuChoisi.pnjs[Math.floor(Math.random() * lieuChoisi.pnjs.length)];

  let indice = 'La piste continue ailleurs...';
  try {
    const resp = await fetch('/api/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: 'claude-sonnet-4-5', max_tokens: 100,
        messages: [{ role: 'user', content: 'Jeu politique parodique. Quete en cours : "' + quete.titre + '" (' + quete.description + '). Le joueur vient de progresser. Donne UNE phrase courte d\'indice narratif sur la suite (sans reveler le lieu exact), ton mysterieux et parodique.' }]
      })
    });
    const data = await resp.json();
    indice = data.content?.[0]?.text || indice;
  } catch(e) {}

  if (typeof sbMettreAJourQuete === 'function') {
    await sbMettreAJourQuete(quete.id, {
      etape_actuelle: etapeSuivante,
      building_id: lieuChoisi.buildingId,
      room_id: lieuChoisi.roomId,
      pnj_actif: pnjChoisi
    }).catch(() => {});
  }

  showToast('Piste suivie !', indice, true, true);
  addJournalEntry('Quête "' + quete.titre + '" : étape ' + etapeSuivante + '/' + quete.nb_etapes_total + ' — ' + indice, 'event-good');
}

async function remettreRecompenseQuete(quete) {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  let msg = '';

  if (quete.recompense_type === 'terrain') {
    let terrainInfo = null;
    try { terrainInfo = JSON.parse(quete.recompense_detail); } catch(e) {}

    if (terrainInfo) {
      // Re-verifier que le terrain est toujours libre (au cas ou quelqu'un l'aurait pris entre temps)
      const terrainsLibresActuels = await getTerrainsVraimentLibres(state.country);
      const stillLibre = terrainsLibresActuels.some(t => t.buildingId === terrainInfo.buildingId);

      if (stillLibre) {
        const profiles = TERRAIN_PNJ_PROFILES?.[state.country] || TERRAIN_PNJ_PROFILES?.republic || [];
        const squatterProfiles = profiles.filter(p => p.id === 'squatter_cool' || p.id === 'squatter_agr');
        const squatterChoisi = squatterProfiles[Math.floor(Math.random() * squatterProfiles.length)] || null;

        const nouvelEtat = {
          proprietaire: state.char?.name,
          pnj: squatterChoisi?.id || null,
          pnjData: squatterChoisi || null,
          dateGeneration: Date.now()
        };

        if (typeof sbSetTerrainState === 'function') {
          await sbSetTerrainState(state.country, terrainInfo.buildingId, nouvelEtat).catch(() => {});
        }
        // Mettre aussi a jour le localStorage local si le joueur consulte ce terrain plus tard
        try {
          localStorage.setItem('terrain_state_' + state.country + '_' + terrainInfo.buildingId, JSON.stringify(nouvelEtat));
        } catch(e) {}

        if (!state.terrainsAchetes) state.terrainsAchetes = {};
        state.terrainsAchetes[terrainInfo.buildingId] = state.char?.name;

        const villeNom = WORLD[state.country]?.[terrainInfo.cityId]?.name || terrainInfo.cityId;
        msg = '🏛️ Vous gagnez un TERRAIN À BÂTIR à ' + villeNom + ' (' + terrainInfo.buildingId + ') ! Attention : des squatteurs s\'y sont déjà installés...';
      } else {
        // Terrain plus disponible -> fallback sur de l'argent consequent en compensation
        const montantCompensation = 1500;
        state.arg = (state.arg || 0) + montantCompensation;
        msg = 'Le terrain promis a été pris entre-temps. En compensation : +' + montantCompensation + ' ' + cur + '.';
      }
    }
  } else if (quete.recompense_type === 'argent') {
    const montant = Math.floor(Math.random() * 2000) + 200; // 200 a 2200, large echelle
    state.arg = (state.arg || 0) + montant;
    msg = '+' + montant + ' ' + cur + ' !';
  } else if (quete.recompense_type === 'objet') {
    const objetsPossibles = (typeof OBJETS_TROUVES_ASSEMBLEE !== 'undefined') ? OBJETS_TROUVES_ASSEMBLEE : [];
    if (objetsPossibles.length > 0) {
      const obj = objetsPossibles[Math.floor(Math.random() * objetsPossibles.length)];
      addToInventory({ id: 'quete-obj-' + Date.now(), name: obj.name, icon: obj.icon, desc: obj.desc, type: obj.compromettant ? 'kompromat' : 'objet', legal: !obj.compromettant, imageUrl: obj.imageUrl || null });
      msg = 'Vous obtenez : ' + obj.name + '.';
    } else {
      msg = 'Un mystérieux colis vous est remis.';
    }
  } else if (quete.recompense_type === 'titre') {
    if (!state.titresHonorifiques) state.titresHonorifiques = [];
    const titreObtenu = 'Résolveur de "' + quete.titre + '"';
    state.titresHonorifiques.push({ titre: titreObtenu, jour: state.day || 1 });
    msg = 'Titre honorifique obtenu : "' + titreObtenu + '" (cosmétique).';
  } else if (quete.recompense_type === 'dossier_surveillance' && quete.cible_dossier) {
    let actions = [];
    if (typeof sbGetActionsTracables === 'function') {
      try { actions = await sbGetActionsTracables(state.country, state.currentCity, state.day || 1); } catch(e) {}
    }
    const actionsCible = actions.filter(a => a.auteur === quete.cible_dossier);
    const contenu = actionsCible.length > 0
      ? actionsCible.map(a => '- ' + a.type_action + (a.cible ? ' (cible: ' + a.cible + ')' : '') + ' — Jour ' + a.jour).join('\n')
      : 'Aucune action notable recensée récemment.';
    addToInventory({
      id: 'dossier-' + Date.now(), name: 'Dossier de surveillance — ' + quete.cible_dossier,
      icon: 'ti-folder-search', desc: 'Compilation d\'actions réelles concernant ' + quete.cible_dossier + ' :\n' + contenu,
      type: 'kompromat', legal: false
    });
    msg = 'Vous obtenez un dossier de surveillance complet sur ' + quete.cible_dossier + ' !';
  }

  if (typeof sbMettreAJourQuete === 'function') {
    await sbMettreAJourQuete(quete.id, { statut: 'resolue', resolu_par: state.char?.name, recompense_detail: msg }).catch(() => {});
  }

  updateUI();
  showToast('Affaire résolue !', msg, true, true);
  addJournalEntry('🏆 ' + (state.char?.name||'Quelqu\'un') + ' a résolu "' + quete.titre + '" ! ' + msg, 'event-good');
  addExternalEvent('🏆 ' + (state.char?.name||'Quelqu\'un') + ' a résolu l\'affaire "' + quete.titre + '" !', 'national');
}


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

// Trouve le responsable de la loge maçonnique (chef d'organisation type 'loge')
function getResponsableLoge() {
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
// V29B — SYSTEME D'ORGANISATIONS (creation, membres, grades)
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
  sauvegarderOrga(orga);
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
