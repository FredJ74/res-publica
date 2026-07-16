// =====================
// PLATEAU-ORGANISATIONS-QUETES.JS
// Organisations (sauvegarde/chargement), systeme de quetes, loge maconnique
// =====================

// Trouve le nom du PJ qui occupe reellement un poste donne (via Supabase, pas le state local)
async function getTitulairePoste(posteId, ville, pays) {
  if (typeof sbListPersonnages !== 'function') return null;
  try {
    const joueurs = await sbListPersonnages() || [];
    const cible = pays || state.country;
    const titulaire = joueurs.find(j => j.country === cible && j.poste?.id === posteId && (!ville || j.poste?.city === ville));
    return titulaire?.name || null;
  } catch(e) { return null; }
}

// Cas particulier du maire : le posteId varie selon la ville (maire_a, maire_b...), pas de poste 'maire' generique
async function getTitulaireMaire(pays, ville) {
  if (typeof sbListPersonnages !== 'function') return null;
  try {
    const joueurs = await sbListPersonnages() || [];
    const cible = pays || state.country;
    const titulaire = joueurs.find(j => j.country === cible && j.poste?.id?.startsWith('maire') && (!ville || j.poste?.city === ville));
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
    if (typeof verifierElectionsOrganisations === 'function') verifierElectionsOrganisations();
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

  const localIdActuel = state.currentBuilding + ':' + state.currentRoom;
  const orgaExistanteIci = (state.organisations || []).find(o => o.localId === localIdActuel);
  if (orgaExistanteIci) {
    showToast('Local déjà occupé', 'Une organisation ("' + orgaExistanteIci.nom + '") est déjà établie ici.', false);
    return;
  }

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
          '<div style="font-size:.72rem;color:#8a8060">' + (def.label||'') + ' · ' + (monMembre?.grade||'') + (estChef ? ' 👑' : '') + ' · ' + (orga.membres?.length||0) + ' membres</div>' +
          (orga.devise ? '<div style="font-size:.65rem;color:#4a4030;font-style:italic">"' + orga.devise + '"</div>' : '') +
        '</div>' +
        '<div style="font-family:Bebas Neue,sans-serif;font-size:.75rem;color:#C9A84C">' + (orga.caisse||0).toLocaleString('fr-FR') + ' ' + cur + '</div>' +
      '</div>' +

      '<div style="padding:.5rem .8rem;display:flex;flex-wrap:wrap;gap:.35rem;border-bottom:1px solid #1a1208">' +
        '<button onclick="ouvrirForumDepuisOrga(\'' + orga.id + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.65rem;letter-spacing:.06em;padding:.3rem .6rem;border:1px solid #1a3a1a;background:transparent;color:#4a7a4a;cursor:pointer">📋 Forum</button>' +
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
           '<button onclick="quitterOrga(\'' + orga.id + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;padding:.3rem .6rem;border:1px solid #6a3a2a;background:transparent;color:#cc6a44;cursor:pointer">Quitter cette organisation</button>' +
        '</div>'
      : '') +

      ((orga.type === 'sportive' || orga.type === 'supporters') ? (
        orga.election?.enCours ? (
          '<div style="padding:.6rem .8rem;border-top:1px solid #1a1208;background:#0c0a06">' +
          '<div style="font-size:.7rem;color:#C9A84C;font-family:Bebas Neue,sans-serif;letter-spacing:.06em;margin-bottom:.3rem">ÉLECTION — ' + (orga.election.phase === 'candidatures' ? 'Candidatures ouvertes' : 'Vote en cours') + '</div>' +
          (orga.election.phase === 'candidatures' && !orga.election.candidats.some(c => c.nom === state.char?.name)
            ? '<button onclick="seProsenterCandidat(\'' + orga.id + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;padding:.3rem .6rem;border:1px solid #4a3a1a;background:transparent;color:#C9A84C;cursor:pointer">Se présenter</button>'
            : '') +
          (orga.election.phase === 'vote'
            ? orga.election.candidats.map(c => '<button onclick="voterElection(\'' + orga.id + '\',\'' + c.nom + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;margin:.15rem .3rem .15rem 0;padding:.3rem .6rem;border:1px solid ' + (orga.election.votes[state.char?.name] === c.nom ? '#C9A84C' : '#2a2010') + ';background:transparent;color:#c0b090;cursor:pointer">' + c.nom + '</button>').join('')
            : '') +
          '</div>'
        ) : (
          '<div style="padding:.5rem .8rem;border-top:1px solid #1a1208">' +
          '<button onclick="doDeclencherElectionClub()" style="font-family:Bebas Neue,sans-serif;font-size:.65rem;padding:.25rem .5rem;border:1px solid #2a2010;background:transparent;color:#8a8060;cursor:pointer">🗳 Déclencher une élection</button>' +
          '</div>'
        )
      ) : '') +

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

  if (fn === 'demander_autorisation_manifester') { ouvrirDemandeAutorisationManifester(orgaId); return; }

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
    orga_hooliganisme:   () => {
      const pays = state.country || 'republic';
      if (INDICES_NATIONAUX[pays]) {
        INDICES_NATIONAUX[pays].ISN = Math.max(0, INDICES_NATIONAUX[pays].ISN - 5);
        INDICES_NATIONAUX[pays].IS = Math.max(0, INDICES_NATIONAUX[pays].IS - 5);
      }
      if (!state.historiqueCrimes) state.historiqueCrimes = [];
      state.historiqueCrimes.push({ acte: 'hooliganisme', cible: null, jour: state.day, expireJour: (state.day||1) + 8 });
      if (typeof tracerActionPourRumeur === 'function') tracerActionPourRumeur('hooliganisme', null);
      showToast('Échauffourées !', 'Les supporters sèment le chaos après le match. -5 Sécurité Nationale, -5 Social.', true, true);
      addJournalEntry('Échauffourées organisées par "' + orga.nom + '". Impact sur la sécurité nationale et le climat social.', 'event-bad');
      addExternalEvent('⚠️ Des échauffourées éclatent en marge d\'un match, attribuées aux supporters de "' + orga.nom + '".');
    },
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

function titreChefOrga(type) {
  const titres = { sportive: 'Président du club sportif', supporters: 'Président du club des supporters', syndicale: 'Secrétaire général', mediatique: 'Directeur de Publication' };
  return titres[type] || 'Président';
}

function ouvrirMailOrga(orgaId) {
  const orga = getOrgaById(orgaId);
  if (!orga) return;
  const estChef = orga.chef === state.char?.name;
  if (!estChef) {
    showToast('Réservé au président', 'Seul le/la ' + titreChefOrga(orga.type).toLowerCase() + ' peut envoyer du courrier officiel au nom de "' + orga.nom + '".', false);
    return;
  }
  mailFromOverride = (state.char?.name || 'Anonyme') + ', ' + titreChefOrga(orga.type);
  document.getElementById('modal-postes')?.classList.remove('open');
  document.getElementById('vue-self')?.classList.remove('active');
  mailView = 'compose';
  openForumView('local');
  document.getElementById('forum-main').innerHTML = renderMailCompose();
}

function ouvrirForumDepuisOrga(orgaId) {
  const orga = getOrgaById(orgaId);
  const mapping = { sportive: 'sport', supporters: 'sport', syndicale: 'syndicats', mediatique: 'presse' };
  const forumCible = mapping[orga?.type] || 'local';
  document.getElementById('modal-postes')?.classList.remove('open');
  document.getElementById('vue-self')?.classList.remove('active');
  openForumView(forumCible);
}


// =====================
// CHAMPIONNAT SPORTIF
// =====================

// Calendrier en tour simple (methode du cercle) : 12 clubs -> 11 journees de 6 matchs
function genererCalendrierSaison() {
  const clubs = CLUBS_SPORTIFS.map(c => c.id);
  const n = clubs.length;
  const journees = [];
  let arr = clubs.slice(1);

  for (let j = 0; j < n - 1; j++) {
    const matchs = [];
    const roundClubs = [clubs[0], ...arr];
    const inverse = j % 2 === 1;
    for (let i = 0; i < n / 2; i++) {
      const home = roundClubs[i];
      const away = roundClubs[n - 1 - i];
      matchs.push({
        home: inverse ? away : home, away: inverse ? home : away,
        played: false, scoreHome: null, scoreAway: null, recit: null
      });
    }
    journees.push({ numero: j + 1, matchs });
    arr.push(arr.shift());
  }
  return journees;
}

function getClub(id) { return CLUBS_SPORTIFS.find(c => c.id === id); }

function genererEvenementsMatch(home, away, scoreHome, scoreAway) {
  const events = [];
  const minutesUtilisees = new Set();
  function minuteLibre() {
    let m;
    do { m = Math.floor(Math.random() * 90) + 1; } while (minutesUtilisees.has(m));
    minutesUtilisees.add(m);
    return m;
  }
  const vedette = (club) => club.vedettes[Math.floor(Math.random() * club.vedettes.length)];

  for (let i = 0; i < scoreHome; i++) {
    events.push({ minute: minuteLibre(), texte: `BUT ! ${vedette(home)} fait trembler les filets pour ${home.nom} !`, type: 'but' });
  }
  for (let i = 0; i < scoreAway; i++) {
    events.push({ minute: minuteLibre(), texte: `BUT ! ${vedette(away)} marque pour ${away.nom} !`, type: 'but' });
  }
  const templatesColor = [
    (c) => `Frappe cadrée de ${c}, à côté !`,
    (c) => `Carton jaune pour ${c}.`,
    (c) => `Bel arrêt du gardien devant ${c}.`,
    (c) => `Occasion manquée pour ${c}, seul face au but.`,
    (c) => `Corner obtenu, mais rien de dangereux.`,
    (c) => `Tacle appuyé de ${c}, l'arbitre laisse jouer.`
  ];
  const nbColor = 3 + Math.floor(Math.random() * 3);
  for (let i = 0; i < nbColor; i++) {
    const club = Math.random() < 0.5 ? home : away;
    const joueur = vedette(club);
    const t = templatesColor[Math.floor(Math.random() * templatesColor.length)];
    events.push({ minute: minuteLibre(), texte: t(joueur), type: 'action' });
  }

  events.sort((a, b) => a.minute - b.minute);
  events.push({ minute: 90, texte: `Coup de sifflet final. Score final : ${home.nom} ${scoreHome} - ${scoreAway} ${away.nom}.`, type: 'fin' });
  return events;
}

function simulerMatch(clubHomeId, clubAwayId, bonusHome, bonusAway, boycotte) {
  const home = getClub(clubHomeId), away = getClub(clubAwayId);
  const avantageDomicile = boycotte ? -5 : 5; // un stade boycotte desavantage legerement l'equipe locale
  const forceHome = home.valeurBase + avantageDomicile + (bonusHome || 0);
  const forceAway = away.valeurBase + (bonusAway || 0);
  const buts = (force) => Math.max(0, Math.round((force / 28) + (Math.random() * 2.6 - 0.9)));
  const scoreHome = buts(forceHome);
  const scoreAway = buts(forceAway);

  let recit;
  if (scoreHome > scoreAway) recit = `${home.nom} s'impose ${scoreHome}-${scoreAway} face à ${away.nom} devant son public.`;
  else if (scoreAway > scoreHome) recit = `${away.nom} s'impose ${scoreAway}-${scoreHome} sur la pelouse de ${home.nom}.`;
  else recit = `Match nul ${scoreHome}-${scoreAway} entre ${home.nom} et ${away.nom}.`;

  const evenements = genererEvenementsMatch(home, away, scoreHome, scoreAway);

  return { scoreHome, scoreAway, recit, evenements };
}

function calculerClassement(journeesJouees) {
  const table = {};
  CLUBS_SPORTIFS.forEach(c => { table[c.id] = { id:c.id, nom:c.nom, pts:0, j:0, v:0, n:0, d:0, bp:0, bc:0 }; });
  (journeesJouees || []).forEach(journee => {
    journee.matchs.forEach(m => {
      if (!m.played) return;
      const h = table[m.home], a = table[m.away];
      if (!h || !a) return;
      h.j++; a.j++;
      h.bp += m.scoreHome; h.bc += m.scoreAway;
      a.bp += m.scoreAway; a.bc += m.scoreHome;
      if (m.scoreHome > m.scoreAway) { h.v++; h.pts += 3; a.d++; }
      else if (m.scoreAway > m.scoreHome) { a.v++; a.pts += 3; h.d++; }
      else { h.n++; a.n++; h.pts++; a.pts++; }
    });
  });
  return Object.values(table).sort((x, y) => (y.pts - x.pts) || ((y.bp - y.bc) - (x.bp - x.bc)) || (y.bp - x.bp));
}

function choisirStadeFinale(stadesUtilises) {
  let dispo = CLUBS_SPORTIFS.filter(c => !(stadesUtilises || []).includes(c.id));
  if (dispo.length === 0) dispo = CLUBS_SPORTIFS.slice();
  return dispo[Math.floor(Math.random() * dispo.length)].id;
}

// Simule un tour a elimination directe, aller-retour (score cumule)
function simulerTourElimination(clubsQualifies) {
  const n = clubsQualifies.length;
  const paires = [];
  for (let i = 0; i < n / 2; i++) paires.push([clubsQualifies[i], clubsQualifies[n - 1 - i]]);

  return paires.map(([a, b]) => {
    const aller = simulerMatch(a, b);
    const retour = simulerMatch(b, a);
    const totalA = aller.scoreHome + retour.scoreAway;
    const totalB = aller.scoreAway + retour.scoreHome;
    return {
      home:a, away:b, aller, retour, totalA, totalB,
      vainqueur: totalA >= totalB ? a : b,
      recit: `${getClub(a).nom} ${totalA} - ${totalB} ${getClub(b).nom} (cumul aller-retour)`
    };
  });
}

async function chargerOuInitialiserSaison() {
  if (typeof sbGetChampionnat !== 'function') return null;
  let saison = await sbGetChampionnat().catch(() => null);
  if (!saison) {
    saison = {
      numero: 1,
      dateDebut: new Date().toISOString(),
      phase: 'reguliere',
      calendrier: genererCalendrierSaison(),
      stadeFinaleClubId: choisirStadeFinale([]),
      stadesUtilises: [],
      resultatsFinales: null,
      palmares: []
    };
    if (typeof sbSaveChampionnat === 'function') await sbSaveChampionnat(saison).catch(() => {});
  }
  return saison;
}

function joursEcoulesDepuis(dateISO) {
  return Math.max(0, Math.floor((Date.now() - new Date(dateISO).getTime()) / (1000 * 60 * 60 * 24)));
}

// Fait avancer la saison selon le temps reel ecoule (1 journee par semaine).
// Peut etre appelee par n'importe quel joueur au chargement — verifie avant de rejouer une journee deja faite.
async function publierResultatsJourneeSurForum(numeroSaison, journee) {
  if (typeof sbCreateTopic !== 'function' || typeof formatDateHeureJeu !== 'function') return;
  const time = formatDateHeureJeu();
  const titre = 'Journée ' + journee.numero + ' — Saison ' + numeroSaison;
  const contenu = journee.matchs.map(m => m.recit).join('<br>');

  const topicId = await sbCreateTopic('sport', titre, 'Ligue Officielle', state.country || 'republic', time).catch(() => null);
  if (topicId && typeof sbCreatePost === 'function') {
    await sbCreatePost(topicId, 'Ligue Officielle', contenu, time).catch(() => {});
  }
  if (!FORUM_TOPICS['sport']) FORUM_TOPICS['sport'] = [];
  FORUM_TOPICS['sport'].unshift({
    id: topicId || 'sport-' + Date.now(), title: titre, author: 'Ligue Officielle',
    time, views: 1, replies: 0, lastPostAuthor: 'Ligue Officielle', lastPostTime: time,
    posts: [{ author: 'Ligue Officielle', time, content: contenu }]
  });
}

async function publierTourPlayoffSurForum(numeroSaison, titreManche, resultats) {
  if (typeof sbCreateTopic !== 'function' || typeof formatDateHeureJeu !== 'function') return;
  const time = formatDateHeureJeu();
  const titre = titreManche + ' — Saison ' + numeroSaison;
  const contenu = resultats.map(r => r.recit).join('<br>');

  const topicId = await sbCreateTopic('sport', titre, 'Ligue Officielle', state.country || 'republic', time).catch(() => null);
  if (topicId && typeof sbCreatePost === 'function') {
    await sbCreatePost(topicId, 'Ligue Officielle', contenu, time).catch(() => {});
  }
  if (!FORUM_TOPICS['sport']) FORUM_TOPICS['sport'] = [];
  FORUM_TOPICS['sport'].unshift({
    id: topicId || 'sport-playoff-' + Date.now(), title: titre, author: 'Ligue Officielle',
    time, views: 1, replies: 0, lastPostAuthor: 'Ligue Officielle', lastPostTime: time,
    posts: [{ author: 'Ligue Officielle', time, content: contenu }]
  });
}

async function publierPhasesFinalesSurForum(numeroSaison, rf) {
  if (typeof sbCreateTopic !== 'function' || typeof formatDateHeureJeu !== 'function') return;
  const time = formatDateHeureJeu();
  const titre = '🏆 Sacre du champion — Saison ' + numeroSaison;
  let contenu = '<b>Finale</b> (au ' + getClub(rf.stadeClubId).nom + ')<br>' + rf.finale.recit;
  contenu += '<br><br><b>' + getClub(rf.champion).nom + ' est sacré champion de la saison ' + numeroSaison + ' !</b>';

  const topicId = await sbCreateTopic('sport', titre, 'Ligue Officielle', state.country || 'republic', time).catch(() => null);
  if (topicId && typeof sbCreatePost === 'function') {
    await sbCreatePost(topicId, 'Ligue Officielle', contenu, time).catch(() => {});
  }
  if (!FORUM_TOPICS['sport']) FORUM_TOPICS['sport'] = [];
  FORUM_TOPICS['sport'].unshift({
    id: topicId || 'sport-finale-' + Date.now(), title: titre, author: 'Ligue Officielle',
    time, views: 1, replies: 0, lastPostAuthor: 'Ligue Officielle', lastPostTime: time,
    posts: [{ author: 'Ligue Officielle', time, content: contenu }]
  });
}

async function verifierNotificationsAvantMatch(saison) {
  if (saison.phase !== 'reguliere') return;
  const joursEcoules = joursEcoulesDepuis(saison.dateDebut);
  const prochaine = saison.calendrier.find(j => !j.matchs.every(m => m.played));
  if (!prochaine || prochaine.notifie24h) return;

  const dateResolution = (prochaine.numero - 1) * 7;
  if (joursEcoules !== dateResolution - 1) return; // on notifie seulement la veille exacte

  for (const m of prochaine.matchs) {
    const clubHome = getClub(m.home), clubAway = getClub(m.away);
    const [contribHome, contribAway] = await Promise.all([calculerContributionEquipe(clubHome), calculerContributionEquipe(clubAway)]);
    await notifierConvocationAnticipee(clubHome, contribHome, clubAway);
    await notifierConvocationAnticipee(clubAway, contribAway, clubHome);
  }
  prochaine.notifie24h = true;
  if (typeof sbSaveChampionnat === 'function') await sbSaveChampionnat(saison).catch(() => {});
}

async function notifierConvocationAnticipee(club, contrib, adversaire) {
  const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : '';
  for (const t of contrib.titulaires) {
    if (typeof sbSendMail === 'function') {
      await sbSendMail('Ligue Officielle', t.nom, 'Convocation — ' + club.nom,
        'Vous êtes titulaire pour le match de demain face à ' + adversaire.nom + '. Dernière chance de vous entraîner avant le coup d\'envoi !', time).catch(() => {});
    }
  }
  for (const r of contrib.remplacants) {
    if (typeof sbSendMail === 'function') {
      await sbSendMail('Ligue Officielle', r.nom, 'Convocation — ' + club.nom,
        'Vous êtes remplaçant pour le match de demain face à ' + adversaire.nom + '.', time).catch(() => {});
    }
  }
}

async function jouerMatchsTour(paires, avecRetour) {
  const resultats = [];
  for (const [a, b] of paires) {
    const clubA = getClub(a), clubB = getClub(b);
    const [contribA, contribB] = await Promise.all([calculerContributionEquipe(clubA), calculerContributionEquipe(clubB)]);
    const res = simulerMatch(a, b, contribA.bonus, contribB.bonus);
    resultats.push({ home: a, away: b, scoreHome: res.scoreHome, scoreAway: res.scoreAway, recit: res.recit });
    await notifierCompositionsEtBlessures(clubA, contribA, res.scoreHome, res.scoreAway);
    await notifierCompositionsEtBlessures(clubB, contribB, res.scoreAway, res.scoreHome);
  }
  return resultats;
}

function determinerVainqueursAgrege(aller, retour) {
  // retour : memes paires mais domicile/exterieur inverses (b recoit a)
  return aller.map((m, i) => {
    const r = retour[i];
    const totalA = m.scoreHome + r.scoreAway; // buts de "a" sur les deux manches
    const totalB = m.scoreAway + r.scoreHome; // buts de "b" sur les deux manches
    return totalA >= totalB ? m.home : m.away;
  });
}

async function progresserPlayoffs(saison) {
  const p = saison.playoffs;
  const jour = state.day || 1;
  if (jour < p.prochaineDate) return false;

  if (p.etape === 'quarts_aller') {
    p.quarts.aller = await jouerMatchsTour(p.quarts.paires, false);
    await publierTourPlayoffSurForum(saison.numero, 'Quarts de finale (aller)', p.quarts.aller);
    p.etape = 'quarts_retour';
    p.prochaineDate = jour + 7;
    return true;
  }
  if (p.etape === 'quarts_retour') {
    const pairesRetour = p.quarts.paires.map(([a, b]) => [b, a]);
    p.quarts.retour = await jouerMatchsTour(pairesRetour, true);
    await publierTourPlayoffSurForum(saison.numero, 'Quarts de finale (retour)', p.quarts.retour);
    p.quarts.vainqueurs = determinerVainqueursAgrege(p.quarts.aller, p.quarts.retour);
    p.demies = { paires: [[p.quarts.vainqueurs[0], p.quarts.vainqueurs[3]], [p.quarts.vainqueurs[1], p.quarts.vainqueurs[2]]], aller: null, retour: null, vainqueurs: null };
    p.etape = 'demies_aller';
    p.prochaineDate = jour + 7;
    return true;
  }
  if (p.etape === 'demies_aller') {
    p.demies.aller = await jouerMatchsTour(p.demies.paires, false);
    await publierTourPlayoffSurForum(saison.numero, 'Demi-finales (aller)', p.demies.aller);
    p.etape = 'demies_retour';
    p.prochaineDate = jour + 7;
    return true;
  }
  if (p.etape === 'demies_retour') {
    const pairesRetour = p.demies.paires.map(([a, b]) => [b, a]);
    p.demies.retour = await jouerMatchsTour(pairesRetour, true);
    await publierTourPlayoffSurForum(saison.numero, 'Demi-finales (retour)', p.demies.retour);
    p.demies.vainqueurs = determinerVainqueursAgrege(p.demies.aller, p.demies.retour);
    p.finale = { paire: [p.demies.vainqueurs[0], p.demies.vainqueurs[1]], resultat: null };
    p.etape = 'finale';
    p.prochaineDate = jour + 7;
    return true;
  }
  if (p.etape === 'finale') {
    const [a, b] = p.finale.paire;
    const [contribA, contribB] = await Promise.all([calculerContributionEquipe(getClub(a)), calculerContributionEquipe(getClub(b))]);
    const res = simulerMatch(a, b, contribA.bonus, contribB.bonus);
    p.finale.resultat = { home:a, away:b, scoreHome:res.scoreHome, scoreAway:res.scoreAway, recit:res.recit };
    await notifierCompositionsEtBlessures(getClub(a), contribA, res.scoreHome, res.scoreAway);
    await notifierCompositionsEtBlessures(getClub(b), contribB, res.scoreAway, res.scoreHome);

    const champion = res.scoreHome >= res.scoreAway ? a : b;
    const finaliste = champion === a ? b : a;
    const classementFinal = calculerClassement(saison.calendrier);

    saison.resultatsFinales = { quarts: p.quarts, demies: p.demies, finale: p.finale.resultat, champion, stadeClubId: saison.stadeFinaleClubId };
    saison.palmares.push({
      saison: saison.numero,
      champion: getClub(champion).nom,
      finaliste: getClub(finaliste).nom,
      stade: getClub(saison.stadeFinaleClubId).nom,
      classementFinal: classementFinal.map(c => ({ nom:c.nom, pts:c.pts }))
    });
    saison.phase = 'terminee';
    p.etape = 'termine';
    await publierPhasesFinalesSurForum(saison.numero, saison.resultatsFinales);
    return true;
  }
  return false;
}

async function verifierEtJouerJournees() {
  const saison = await chargerOuInitialiserSaison();
  if (!saison || saison.phase === 'terminee') return saison;

  await verifierNotificationsAvantMatch(saison);

  const joursEcoules = joursEcoulesDepuis(saison.dateDebut);
  const journeeCible = Math.min(Math.floor(joursEcoules / 7), saison.calendrier.length - 1);
  let modifie = false;
  const journeesNouvellementJouees = [];

  for (let i = 0; i <= journeeCible; i++) {
    const journee = saison.calendrier[i];
    if (!journee) continue;
    let journeeVientDetreJouee = false;
    for (const m of journee.matchs) {
      if (!m.played) {
        const demandeMatch = m.demandeManifId ? await sbGetDemandeManifestationParId(m.demandeManifId).catch(() => null) : null;
        const clubHome = getClub(m.home), clubAway = getClub(m.away);

        if (demandeMatch?.statut === 'interdite') {
          Object.assign(m, { scoreHome: 0, scoreAway: 1, recit: 'Match interdit par le Ministère de l\'Intérieur — victoire par forfait de ' + clubAway.nom + ' (0-1).', evenements: [], played: true });
          modifie = true;
          journeeVientDetreJouee = true;
          addExternalEvent('🚫 Le match ' + clubHome.nom + ' vs ' + clubAway.nom + ' est interdit par le Ministère de l\'Intérieur. Victoire par forfait de ' + clubAway.nom + '.');
          continue;
        }

        const [contribHome, contribAway] = await Promise.all([
          calculerContributionEquipe(clubHome),
          calculerContributionEquipe(clubAway)
        ]);
        const res = simulerMatch(m.home, m.away, contribHome.bonus, contribAway.bonus, m.boycotte);
        Object.assign(m, { scoreHome: res.scoreHome, scoreAway: res.scoreAway, recit: res.recit, evenements: res.evenements, played: true,
          compositions: {
            home: { titulaires: contribHome.titulaires.map(t=>t.nom), remplacants: contribHome.remplacants.map(t=>t.nom) },
            away: { titulaires: contribAway.titulaires.map(t=>t.nom), remplacants: contribAway.remplacants.map(t=>t.nom) }
          }
        });
        modifie = true;
        journeeVientDetreJouee = true;
        await notifierCompositionsEtBlessures(clubHome, contribHome, m.scoreHome, m.scoreAway);
        await notifierCompositionsEtBlessures(clubAway, contribAway, m.scoreAway, m.scoreHome);
      }
    }
    if (journeeVientDetreJouee) journeesNouvellementJouees.push(journee);
  }

  for (const journee of journeesNouvellementJouees) {
    await publierResultatsJourneeSurForum(saison.numero, journee);
    await resoudreParisJournee(saison.numero, journee);
  }

  // Une fois la phase reguliere entierement jouee, on enchaine les phases finales,
  // etalees sur plusieurs semaines (une semaine par manche), comme la phase reguliere.
  if (saison.phase === 'reguliere' && saison.calendrier.every(j => j.matchs.every(m => m.played))) {
    const classement = calculerClassement(saison.calendrier);
    const top8 = classement.slice(0, 8).map(c => c.id);
    saison.phase = 'quarts';
    saison.playoffs = {
      top8,
      etape: 'quarts_aller',
      prochaineDate: (state.day || 1) + 7,
      quarts: { paires: [[top8[0],top8[7]],[top8[3],top8[4]],[top8[1],top8[6]],[top8[2],top8[5]]], aller: null, retour: null, vainqueurs: null },
      demies: null,
      finale: null
    };
    modifie = true;
  }

  if (saison.playoffs && saison.phase !== 'terminee') {
    const rejoue = await progresserPlayoffs(saison);
    if (rejoue) modifie = true;
  }

  if (modifie && typeof sbSaveChampionnat === 'function') {
    await sbSaveChampionnat(saison).catch(() => {});
  }
  return saison;
}

// Demarre une toute nouvelle saison (appelee automatiquement une fois la precedente terminee et consultee)
async function demarrerNouvelleSaison(saisonPrecedente) {
  const nouvelle = {
    numero: (saisonPrecedente?.numero || 0) + 1,
    dateDebut: new Date().toISOString(),
    phase: 'reguliere',
    calendrier: genererCalendrierSaison(),
    stadeFinaleClubId: choisirStadeFinale(saisonPrecedente?.stadesUtilises || []),
    stadesUtilises: [...(saisonPrecedente?.stadesUtilises || []), saisonPrecedente?.stadeFinaleClubId].filter(Boolean),
    resultatsFinales: null,
    palmares: saisonPrecedente?.palmares || []
  };
  if (typeof sbSaveChampionnat === 'function') await sbSaveChampionnat(nouvelle).catch(() => {});
  await genererDemandesManifestationMatchs(nouvelle);
  return nouvelle;
}

// Cree automatiquement une demande de manifestation par match de la saison (dimanche 20h, calcule depuis dateDebut)
async function genererDemandesManifestationMatchs(saison) {
  const debut = new Date(saison.dateDebut);
  for (const j of saison.calendrier) {
    const dateMatch = new Date(debut.getTime() + (j.numero - 1) * 7 * 86400000);
    dateMatch.setHours(20, 0, 0, 0);
    for (const m of j.matchs) {
      const clubHome = getClub(m.home), clubAway = getClub(m.away);
      const id = await sbCreerDemandeManifestation({
        orgaId: null, orgaNom: 'Ligue Officielle', orgaType: 'sportive',
        pays: clubHome.country, ville: clubHome.city,
        sujet: clubHome.nom + ' vs ' + clubAway.nom + ' (Journée ' + j.numero + ')',
        sens: null, intensite: 0, cible: null,
        matchInfo: { home: m.home, away: m.away, journeeNumero: j.numero, saisonNumero: saison.numero },
        dateEvenement: dateMatch.toISOString(),
        dateDepot: new Date().toISOString(),
        auto: true
      }).catch(() => null);
      m.demandeManifId = id;
    }
  }
  if (typeof sbSaveChampionnat === 'function') await sbSaveChampionnat(saison).catch(() => {});
}

// =====================
// PERFORMANCE DES JOUEURS & INDICES LOCAUX
// =====================
const LABELS_PERF = { defense: 'Défense', technique: 'Technique', endurance: 'Endurance' };
// Mapping indice local -> parametre de performance
// Securite -> Defense, Ecoles(education) -> Technique, Espaces verts(cadre de vie) -> Endurance
// Associatif -> bonus global multiplicatif sur toute la contribution de l'equipe

function multiplicateurIndice(val) {
  // 0 -> x0.7, 50 -> x1.0, 100 -> x1.3
  return 0.7 + ((val || 50) / 100) * 0.6;
}

async function getIndicesPourVille(country, city) {
  const key = country + '_' + city;
  if (typeof sbGetBudgetMunicipal !== 'function') return { securite:50, associatif:50, ecoles:50, espaces_verts:50 };
  const data = await sbGetBudgetMunicipal(key).catch(() => null);
  return data?.indices || { securite:50, associatif:50, ecoles:50, espaces_verts:50 };
}

const TITULAIRES_MAX = 11;
const REMPLACANTS_MAX = 4;

async function calculerContributionEquipe(club) {
  if (typeof sbListJoueursLicencies !== 'function') return { bonus: 0, titulaires: [], remplacants: [], nonRetenus: [] };
  const licencies = await sbListJoueursLicencies(club.id).catch(() => []);
  const jour = state.day || 1;
  const dispo = (licencies || []).filter(j => !(j.blessure_sportive?.jusquauJour > jour));

  const withTotal = dispo.map(j => {
    const p = j.performance_sportive || { defense:0, technique:0, endurance:0 };
    return { nom: j.name, perf: p, total: (p.defense||0) + (p.technique||0) + (p.endurance||0) };
  }).filter(j => j.total > club.valeurBase * 0.5); // seuil de qualification face aux PNJ du club

  withTotal.sort((a, b) => b.total - a.total);
  const titulaires = withTotal.slice(0, TITULAIRES_MAX);
  const remplacants = withTotal.slice(TITULAIRES_MAX, TITULAIRES_MAX + REMPLACANTS_MAX);
  const nonRetenus = withTotal.slice(TITULAIRES_MAX + REMPLACANTS_MAX);

  const indices = await getIndicesPourVille(club.country, club.city);
  let bonus = 0;
  titulaires.forEach(t => {
    bonus += (t.perf.defense || 0) * multiplicateurIndice(indices.securite) * 0.3;
    bonus += (t.perf.technique || 0) * multiplicateurIndice(indices.ecoles) * 0.3;
    bonus += (t.perf.endurance || 0) * multiplicateurIndice(indices.espaces_verts) * 0.3;
  });
  bonus *= multiplicateurIndice(indices.associatif);

  return { bonus: Math.round(bonus), titulaires, remplacants, nonRetenus };
}

// Envoie la convocation (titulaire/remplacant/non retenu) et applique un risque de blessure aux titulaires
async function notifierCompositionsEtBlessures(club, contrib, butsPour, butsContre) {
  const jour = state.day || 1;
  const resultat = butsPour > butsContre ? 'victoire' : (butsPour < butsContre ? 'defaite' : 'match nul');
  const victoire = butsPour > butsContre;

  const budgetClub = await chargerBudgetClub(club.id);
  const salaires = budgetClub.salaires;

  for (const t of contrib.titulaires) {
    const montant = salaires.titulaire + (victoire ? salaires.primeVictoire : 0);
    if (montant > 0 && typeof sbAppliquerSalaire === 'function') await sbAppliquerSalaire(t.nom, montant).catch(() => {});
  }
  for (const r of contrib.remplacants) {
    if (salaires.remplacant > 0 && typeof sbAppliquerSalaire === 'function') await sbAppliquerSalaire(r.nom, salaires.remplacant).catch(() => {});
  }
  const totalVerse = contrib.titulaires.length * (salaires.titulaire + (victoire ? salaires.primeVictoire : 0)) + contrib.remplacants.length * salaires.remplacant;
  if (totalVerse > 0) await crediterBudgetClub(club.id, -totalVerse, 'Salaires des joueurs (' + resultat + ')');

  for (const t of contrib.titulaires) {
    let messageBlessure = '';
    const blesse = Math.random() < 0.08;
    if (blesse) {
      const grave = Math.random() < 0.3;
      const duree = grave ? (7 + Math.floor(Math.random()*4)) : (2 + Math.floor(Math.random()*2));
      const degatsPV = grave ? 30 : 15;
      if (typeof sbAppliquerBlessureSportive === 'function') {
        await sbAppliquerBlessureSportive(t.nom, { jusquauJour: jour + duree, gravite: grave ? 'grave' : 'legere' }, degatsPV).catch(() => {});
      }
      messageBlessure = '<br><br>⚠️ Vous vous êtes blessé(e) pendant le match (' + (grave ? 'gravement' : 'légèrement') + '). Indisponible ' + duree + ' jour(s), -' + degatsPV + ' PV.';
    }
    if (typeof sbSendMail === 'function') {
      await sbSendMail('Ligue Officielle', t.nom, 'Vous étiez titulaire — ' + club.nom,
        'Vous étiez titulaire lors du dernier match (' + resultat + ', ' + butsPour + '-' + butsContre + '). Salaire perçu : ' + (salaires.titulaire + (victoire ? salaires.primeVictoire : 0)).toLocaleString('fr-FR') + ' FR.' + messageBlessure, formatDateHeureJeu()).catch(() => {});
    }
  }
  for (const r of contrib.remplacants) {
    if (typeof sbSendMail === 'function') {
      await sbSendMail('Ligue Officielle', r.nom, 'Vous étiez remplaçant — ' + club.nom,
        'Vous étiez remplaçant lors du dernier match (' + resultat + ', ' + butsPour + '-' + butsContre + '). Salaire perçu : ' + salaires.remplacant.toLocaleString('fr-FR') + ' FR.', formatDateHeureJeu()).catch(() => {});
    }
  }
  for (const n of contrib.nonRetenus) {
    if (typeof sbSendMail === 'function') {
      await sbSendMail('Ligue Officielle', n.nom, 'Non retenu(e) — ' + club.nom,
        'Vous n\'avez pas été retenu(e) pour le dernier match. Entraînez-vous pour retrouver votre place.', formatDateHeureJeu()).catch(() => {});
    }
  }
}

// Sauvegarde immediate de state.char (local + Supabase) — necessaire pour tout changement qui
// doit survivre a un rafraichissement de page, meme sans changement de piece/batiment.
function sauvegarderPersonnageImmediat() {
  if (!state.char) return;
  try {
    localStorage.setItem('respublica_char_' + (state.char.name || 'default'), JSON.stringify(state.char));
    localStorage.setItem('respublica_char', JSON.stringify(state.char));
  } catch (e) {}
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
}

// Renvoie la valeur EFFECTIVE d'une caracteristique, en tenant compte d'un eventuel bonus
// de formation temporaire (voir doSeFormer). A utiliser partout ou une stat compte (CHA
// pour se defendre, etc.) au lieu de lire state.char.stats directement.
function getStatEffective(stat) {
  const base = state.char?.stats?.[stat] ?? 8;
  const bonus = (state.char?.bonusFormation?.stat === stat) ? (state.char.bonusFormation.valeur || 0) : 0;
  return base + bonus;
}

// SUIVRE UNE FORMATION (Universite, amphi) — bonus TEMPORAIRE (+2, jusqu'au prochain sommeil),
// max 1 formation par jour, cout 100 FR.
function doSeFormer() {
  if (state.char?.dernierFormationJour === state.day) {
    showToast('Déjà formé aujourd\'hui', 'Une seule formation par jour.', false);
    return;
  }
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cost = 100;
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  state.arg -= cost;
  const stats = ['INT','CHA','VOL','PER','DUP','ENT'];
  document.getElementById('postes-modal-title').textContent = 'Suivre une formation';
  let html = '<div style="padding:1rem"><div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Choisir la caractéristique à booster pour la journée (+2, effet jusqu\'à votre prochain sommeil) :</div>';
  stats.forEach(s => {
    html += '<button onclick="appliquerFormation(\'' + s + '\')" style="display:block;width:100%;text-align:left;padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;color:#c0b090;cursor:pointer;font-family:Crimson Pro,serif;font-size:.85rem;margin-bottom:.3rem">' + s + ' (actuel : ' + getStatEffective(s) + ')</button>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function appliquerFormation(stat) {
  document.getElementById('modal-postes').classList.remove('open');
  if (!state.char) return;
  state.char.dernierFormationJour = state.day;
  state.char.bonusFormation = { stat, valeur: 2 };
  sauvegarderPersonnageImmediat();
  updateUI();
  showToast('Formation terminée', '+2 ' + stat + ' jusqu\'à votre prochain sommeil.', true, true);
  addJournalEntry('Formation suivie à l\'université : +2 ' + stat + ' (temporaire).', 'event-good');
}

// RECRUTER DES MILITANTS (Universite, amphi) — conditionne a l'adhesion a un syndicat actif,
// 1 recrutement/jour, plafond de 2 militants par joueur. Prepare les futures manifestations.
async function doRecruterMilitants() {
  const orgas = state.organisations || [];
  const syndicat = orgas.find(o => o.type === 'syndicale' && o.membres?.some(m => m.nom === state.char?.name));
  if (!syndicat) {
    showToast('Adhésion requise', "Il faut être membre d'un syndicat étudiant actif pour recruter des militants.", false);
    return;
  }
  if (state.char?.dernierRecrutementMilitant === state.day) {
    showToast('Déjà fait aujourd\'hui', 'Un seul recrutement de militant par jour.', false);
    return;
  }
  const mesMilitants = typeof sbGetMesMilitants === 'function'
    ? await sbGetMesMilitants(state.country, state.char?.name).catch(() => [])
    : [];
  if (mesMilitants.length >= 2) {
    showToast('Plafond atteint', 'Vous avez déjà 2 militants recrutés (maximum).', false);
    return;
  }
  const noms = ['Sacha Fervent', 'Lila Combattante', 'Noé Insurgé', 'Maya Debout', 'Théo Rebelle', 'Zoé Militante'];
  const nomPnj = noms[Math.floor(Math.random() * noms.length)] + ' (PNJ)';

  state.char.dernierRecrutementMilitant = state.day;
  sauvegarderPersonnageImmediat();
  if (typeof sbRecruterMilitant === 'function') {
    await sbRecruterMilitant(state.country, state.char?.name, nomPnj).catch(() => {});
  }
  updateUI();
  showToast('Militant recruté !', nomPnj + ' rejoint votre réseau (' + (mesMilitants.length + 1) + '/2).', true);
  addJournalEntry('Recrutement d\'un militant étudiant : ' + nomPnj + ' (syndicat : ' + syndicat.nom + ').', 'event-good');
}

function doPrendreLicenceSportive() {
  const clubLocal = getClubLocal();
  if (!clubLocal) { showToast('Indisponible', 'Aucun club local ici.', false); return; }
  if (state.char?.licenceSportive?.clubId === clubLocal.id) { showToast('Déjà licencié(e)', 'Vous avez déjà votre licence pour ' + clubLocal.nom + '.', false); return; }
  if (state.arg < 300) { showToast('Fonds insuffisants', '300 FR requis.', false); return; }
  state.arg -= 300;
  if (!state.char) return;
  state.char.licenceSportive = { clubId: clubLocal.id, dateAchat: state.day || 1 };
  sauvegarderPersonnageImmediat();
  updateUI();
  showToast('Licence obtenue !', 'Vous pouvez désormais vous entraîner et jouer pour ' + clubLocal.nom + '.', true, true);
  addJournalEntry('Licence sportive prise pour ' + clubLocal.nom + ' (-300 FR).', 'event-good');
}

function verifierEtResetEntrainementsJour() {
  if (!state.char) return;
  if (state.char.entrainementsJour?.jour !== state.day) {
    state.char.entrainementsJour = { jour: state.day || 1, nb: 0 };
  }
}

function estIndisponiblePourSport() {
  const b = state.char?.blessureSportive;
  return b && b.jusquauJour > (state.day || 1);
}

function doTenueEntrainement() {
  const clubLocal = getClubLocal();
  if (!state.char?.licenceSportive) { showToast('Licence requise', 'Prenez votre licence sportive avant de vous entraîner.', false); return; }
  if (estIndisponiblePourSport()) {
    const reste = state.char.blessureSportive.jusquauJour - (state.day||1);
    showToast('Blessé(e)', 'Encore ' + reste + ' jour(s) avant de pouvoir vous entraîner.', false);
    return;
  }
  verifierEtResetEntrainementsJour();
  const perf = state.char.performance || { defense:0, technique:0, endurance:0 };
  const nb = state.char.entrainementsJour?.nb || 0;

  document.getElementById('postes-modal-title').textContent = "Tenue d'entraînement";
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;margin-bottom:.8rem">Entraînements aujourd\'hui : ' + nb + '/2</div>';
  ['defense','technique','endurance'].forEach(stat => {
    html += '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:.5rem;padding:.4rem .6rem;border:1px solid #2a2010">';
    html += '<span style="font-size:.8rem;color:#c0b090">' + LABELS_PERF[stat] + ' : <b style="color:#C9A84C">' + (perf[stat]||0) + '</b></span>';
    html += '<button ' + (nb >= 2 ? 'disabled' : '') + ' onclick="confirmerEntrainement(\'' + stat + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.7rem;padding:.3rem .6rem;border:1px solid #4a3a1a;background:transparent;color:' + (nb>=2?'#5a5040':'#C9A84C') + ';cursor:' + (nb>=2?'default':'pointer') + '">S\'entraîner</button>';
    html += '</div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerEntrainement(stat) {
  verifierEtResetEntrainementsJour();
  if ((state.char.entrainementsJour?.nb || 0) >= 2) { showToast('Limite atteinte', 'Maximum 2 entraînements par jour.', false); return; }
  state.char.entrainementsJour.nb = (state.char.entrainementsJour.nb || 0) + 1;

  const blesse = Math.random() < 0.05;
  if (blesse) {
    const grave = Math.random() < 0.3;
    const duree = grave ? (7 + Math.floor(Math.random()*4)) : (2 + Math.floor(Math.random()*2));
    const degatsPV = grave ? 30 : 15;
    state.char.blessureSportive = { jusquauJour: (state.day||1) + duree, gravite: grave ? 'grave' : 'legere' };
    state.hp = Math.max(1, (state.hp||100) - degatsPV);
    sauvegarderPersonnageImmediat();
    document.getElementById('modal-postes')?.classList.remove('open');
    updateUI();
    showToast('Blessure à l\'entraînement !', (grave?'Grave':'Légère') + '. Indisponible ' + duree + ' jour(s). -' + degatsPV + ' PV.', false);
    return;
  }

  if (!state.char.performance) state.char.performance = { defense:0, technique:0, endurance:0 };
  state.char.performance[stat] = (state.char.performance[stat] || 0) + 2;
  sauvegarderPersonnageImmediat();
  updateUI();
  showToast('Entraînement réussi', '+2 ' + LABELS_PERF[stat] + '.', true, true);
  doTenueEntrainement();
}

async function doConseilEntraineurAdjoint() {
  if (!state.char?.licenceSportive) { showToast('Licence requise', 'Prenez votre licence sportive pour recevoir des conseils.', false); return; }
  const clubLocal = getClubLocal();
  if (!clubLocal) { showToast('Indisponible', 'Aucun club local ici.', false); return; }

  document.getElementById('postes-modal-title').textContent = "Conseil de l'entraîneur adjoint";
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const classement = await calculerClassementClub(clubLocal);
  const position = classement.findIndex(j => j.nom === state.char?.name);
  const moi = classement[position];
  const perf = state.char.performance || { defense:0, technique:0, endurance:0 };
  const total = moi ? moi.total : (perf.defense + perf.technique + perf.endurance);

  let html = '<div style="padding:1rem;font-size:.85rem;color:#c0b090;line-height:1.5">';

  if (moi?.statut === 'titulaire') {
    html += '"Beau travail, tu es titulaire. Continue comme ça et surveille le classement — d\'autres poussent derrière toi."';
  } else if (moi?.statut === 'remplaçant') {
    html += '"Tu es dans le groupe des quinze, en tant que remplaçant. Encore un effort pour viser une place de titulaire."';
  } else if (moi?.statut === 'blessé') {
    html += '"Repose-toi d\'abord. On reparlera entraînement une fois que tu seras remis."';
  } else {
    const seuilIdx = TITULAIRES_MAX + REMPLACANTS_MAX - 1; // dernier retenu (15e)
    const dernierRetenu = classement[seuilIdx];
    const seuilTotal = dernierRetenu ? dernierRetenu.total : Math.ceil(clubLocal.valeurBase * 0.5);
    const manque = Math.max(1, seuilTotal - total + 1);

    const indices = await getIndicesPourVille(clubLocal.country, clubLocal.city);
    const options = [
      { stat: 'defense', mult: multiplicateurIndice(indices.securite), label: 'Défense' },
      { stat: 'technique', mult: multiplicateurIndice(indices.ecoles), label: 'Technique' },
      { stat: 'endurance', mult: multiplicateurIndice(indices.espaces_verts), label: 'Endurance' }
    ].sort((a, b) => b.mult - a.mult);
    const meilleure = options[0];
    const joursNecessaires = Math.ceil(manque / 4); // 2 seances/jour x +2 points = +4/jour max

    html += '"Il te manque environ <b style="color:#C9A84C">' + manque + ' points</b> pour intégrer les quinze. ';
    html += 'Avec le contexte actuel de la ville, c\'est ta <b style="color:#C9A84C">' + meilleure.label + '</b> qui te rapportera le plus. ';
    html += 'Si tu t\'entraînes à fond dessus, compte environ <b style="color:#C9A84C">' + joursNecessaires + ' jour(s)</b>."';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

function doTenueMatch() {
  if (!state.char?.licenceSportive) { showToast('Licence requise', 'Prenez votre licence sportive.', false); return; }
  if (estIndisponiblePourSport()) {
    const reste = state.char.blessureSportive.jusquauJour - (state.day||1);
    showToast('Blessé(e)', 'Encore ' + reste + ' jour(s) avant de pouvoir jouer.', false);
    return;
  }
  const perf = state.char.performance || { defense:0, technique:0, endurance:0 };
  const total = (perf.defense||0) + (perf.technique||0) + (perf.endurance||0);

  document.getElementById('postes-modal-title').textContent = 'Tenue de match';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;margin-bottom:.8rem">Répartissez librement vos ' + total + ' points de performance. Modifiable jusqu\'au coup d\'envoi du prochain match.</div>';
  ['defense','technique','endurance'].forEach(stat => {
    html += '<div style="margin-bottom:.5rem">';
    html += '<label style="font-size:.75rem;color:#c0b090;display:block;margin-bottom:.2rem">' + LABELS_PERF[stat] + '</label>';
    html += '<input type="number" id="perf-' + stat + '" value="' + (perf[stat]||0) + '" min="0" max="' + total + '" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;box-sizing:border-box"/>';
    html += '</div>';
  });
  html += '<div id="perf-total-warning" style="font-size:.72rem;color:#cc6a44;margin-bottom:.6rem"></div>';
  html += '<button onclick="confirmerReallocationPerformance(' + total + ')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.55rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Valider la répartition</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerReallocationPerformance(total) {
  const nouvelle = {};
  let somme = 0;
  ['defense','technique','endurance'].forEach(stat => {
    const v = Math.max(0, parseInt(document.getElementById('perf-' + stat)?.value || '0'));
    nouvelle[stat] = v;
    somme += v;
  });
  if (somme !== total) {
    document.getElementById('perf-total-warning').textContent = 'Le total doit rester égal à ' + total + ' points (actuellement ' + somme + ').';
    return;
  }
  state.char.performance = nouvelle;
  document.getElementById('modal-postes')?.classList.remove('open');
  updateUI();
  showToast('Répartition mise à jour', 'Votre configuration sera utilisée pour le prochain match.', true, true);
}

function getClubLocal() {
  const pays = state.country || 'republic';
  const ville = state.currentCity || 'capitale';
  return CLUBS_SPORTIFS.find(c => c.country === pays && c.city === ville);
}

async function doRegarderLive() {
  document.getElementById('postes-modal-title').textContent = 'Choisir un match à suivre';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const saison = await verifierEtJouerJournees();
  let derniereJournee = null;
  for (let i = saison.calendrier.length - 1; i >= 0; i--) {
    if (saison.calendrier[i].matchs.every(m => m.played)) { derniereJournee = saison.calendrier[i]; break; }
  }
  if (!derniereJournee) {
    document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#5a5040;font-style:italic">Aucun match joué pour l\'instant. Revenez après la première journée.</div>';
    return;
  }

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;margin-bottom:.6rem">Journée ' + derniereJournee.numero + '</div>';
  derniereJournee.matchs.forEach((m, idx) => {
    html += '<button onclick="afficherLiveMatch(' + derniereJournee.numero + ',' + idx + ')" style="width:100%;text-align:left;margin-bottom:.4rem;padding:.55rem .7rem;border:1px solid #2a2010;background:transparent;color:#c0b090;cursor:pointer;font-size:.8rem">' + getClub(m.home).nom + ' <b style="color:#C9A84C">' + m.scoreHome + ' - ' + m.scoreAway + '</b> ' + getClub(m.away).nom + '</button>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function afficherLiveMatch(numeroJournee, matchIdx) {
  const saison = await chargerOuInitialiserSaison();
  const journee = saison.calendrier.find(j => j.numero === numeroJournee);
  const m = journee?.matchs?.[matchIdx];
  if (!m) return;

  const home = getClub(m.home), away = getClub(m.away);
  // Repli pour les matchs joues avant l'ajout des evenements synchronises
  const evenements = m.evenements || genererEvenementsMatch(home, away, m.scoreHome, m.scoreAway);

  document.getElementById('postes-modal-title').textContent = home.nom + ' vs ' + away.nom;
  let html = '<div style="padding:1rem">';
  html += '<div style="text-align:center;font-family:Bebas Neue,sans-serif;font-size:1.1rem;color:#C9A84C;margin-bottom:.8rem">' + home.nom + ' ' + m.scoreHome + ' - ' + m.scoreAway + ' ' + away.nom + '</div>';
  html += '<div style="max-height:340px;overflow-y:auto;display:flex;flex-direction:column;gap:.5rem">';
  evenements.forEach(e => {
    const couleur = e.type === 'but' ? '#6ab858' : (e.type === 'fin' ? '#C9A84C' : '#b0a080');
    html += '<div style="font-size:.8rem;color:' + couleur + '"><b style="color:#8a6a20">' + e.minute + '\'</b> ' + e.texte + '</div>';
  });
  html += '</div></div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function doRejoindreClubSupporters() {
  if (!state.organisations) state.organisations = [];
  const pays = state.country || 'republic';
  const ville = state.currentCity || 'capitale';
  const clubLocal = getClubLocal();
  if (!clubLocal) { showToast('Indisponible', 'Aucun club local ici.', false); return; }

  let orga = state.organisations.find(o => o.type === 'supporters' && o.country === pays && o.city === ville);

  const dejaMembre = orga?.membres?.some(m => m.nom === state.char?.name);
  if (dejaMembre) { showToast('Déjà membre', 'Vous êtes déjà membre du club de supporters de ' + clubLocal.nom + '.', false); return; }

  if (state.arg < 150) { showToast('Fonds insuffisants', '150 FR requis pour l\'adhésion.', false); return; }
  state.arg -= 150;
  state.pa = Math.max(0, (state.pa || 0) - 1);

  const def = TYPES_ORGANISATIONS.supporters;
  const grades = def?.grades?.[pays] || ['Sympathisant', 'Membre', 'Ultra', 'Meneur'];

  if (!orga) {
    orga = {
      id: 'orga_supporters_' + pays + '_' + ville,
      type: 'supporters',
      nom: 'Club de Supporters — ' + clubLocal.nom,
      desc: 'Les fidèles du ' + clubLocal.nom + '.',
      fondateur: 'Alfredo Mifassole (PNJ)', chef: 'Alfredo Mifassole (PNJ)', chefEstPnj: true,
      country: pays, city: ville, country_origine: pays,
      creeLe: state.day || 1,
      membres: [], demandesAdhesion: [],
      bonusLocaux: { pop:0, inf:0, dis:0 }, caisse: 0,
      election: null,
      visible: true
    };
    state.organisations.push(orga);
  }

  orga.membres.push({ nom: state.char?.name, grade: grades[0], gradeIdx: 0, rejointLe: state.day || 1 });
  sauvegarderOrga(orga);

  document.getElementById('modal-postes')?.classList.remove('open');
  updateUI();
  showToast('Bienvenue !', 'Vous êtes désormais ' + grades[0] + ' du club de supporters — ' + clubLocal.nom + '.', true, true);
  addJournalEntry('Adhésion au club de supporters du ' + clubLocal.nom + ' (-150 FR).', 'event-good');
  await crediterBudgetClub(clubLocal.id, 150, 'Cotisation supporter');

  // Rafraichir immediatement l'onglet Organisations si la fiche est deja ouverte dessus
  if (document.getElementById('vue-self')?.classList.contains('active')) {
    switchSelfTab('orgas', null);
  }
}

function getClubSupportersLocal() {
  const pays = state.country || 'republic';
  const ville = state.currentCity || 'capitale';
  return (state.organisations || []).find(o => o.type === 'supporters' && o.country === pays && o.city === ville);
}

function doDeclencherElectionClub() {
  const orga = getClubSupportersLocal();
  if (!orga) { showToast('Indisponible', 'Aucun club de supporters ici.', false); return; }
  const estMembre = orga.membres?.some(m => m.nom === state.char?.name);
  if (!estMembre) { showToast('Réservé aux membres', 'Adhérez au club pour déclencher une élection.', false); return; }
  if (orga.election?.enCours) { showToast('Élection en cours', 'Une élection est déjà en cours pour ce club.', false); return; }
  const jour = state.day || 1;
  if (orga.election?.derniereElection && (jour - orga.election.derniereElection) < 7) {
    const reste = 7 - (jour - orga.election.derniereElection);
    showToast('Trop tôt', 'Encore ' + reste + ' jour(s) avant de pouvoir redéclencher une élection.', false);
    return;
  }

  document.getElementById('postes-modal-title').textContent = 'Déclencher une élection';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#8a8060;margin-bottom:.6rem">Motivez votre décision — ce message sera publié sur le forum du championnat.</div>';
  html += '<textarea id="election-motivation" rows="4" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;box-sizing:border-box;margin-bottom:.8rem" placeholder="Pourquoi déclenchez-vous cette élection ?"></textarea>';
  html += '<button onclick="confirmerDeclenchementElection(\'' + orga.id + '\')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.55rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Déclencher l\'élection</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerDeclenchementElection(orgaId) {
  const orga = getOrgaById(orgaId);
  if (!orga) return;
  const motivation = document.getElementById('election-motivation')?.value?.trim();
  if (!motivation) { showToast('Motivation requise', '', false); return; }

  const jour = state.day || 1;
  const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : '';
  orga.election = {
    enCours: true, phase: 'candidatures',
    motivateur: state.char?.name, motivation,
    dateDeclenchement: jour, dateFinCandidatures: jour + 3, dateFinVote: jour + 6,
    candidats: [], votes: {},
    derniereElection: orga.election?.derniereElection || null
  };
  sauvegarderOrga(orga);

  if (typeof sbCreateTopic === 'function') {
    const titre = '🗳 Élection déclenchée — ' + orga.nom;
    const contenu = (state.char?.name || 'Un membre') + ' déclenche une élection pour la présidence de "' + orga.nom + '" :<br><br><em>' + motivation + '</em><br><br>Les candidatures sont ouvertes pendant 3 jours, suivies de 3 jours de vote.';
    const topicId = await sbCreateTopic('sport', titre, state.char?.name || 'Anonyme', state.country, time).catch(() => null);
    if (topicId && typeof sbCreatePost === 'function') await sbCreatePost(topicId, state.char?.name || 'Anonyme', contenu, time).catch(() => {});
    if (!FORUM_TOPICS['sport']) FORUM_TOPICS['sport'] = [];
    FORUM_TOPICS['sport'].unshift({ id: topicId || 'election-' + Date.now(), title: titre, author: state.char?.name, time, views: 1, replies: 0, lastPostAuthor: state.char?.name, lastPostTime: time, posts: [{ author: state.char?.name, time, content: contenu }] });
  }

  document.getElementById('modal-postes')?.classList.remove('open');
  updateUI();
  showToast('Élection déclenchée !', 'Les candidatures sont ouvertes pour 3 jours.', true, true);
  if (document.getElementById('vue-self')?.classList.contains('active')) switchSelfTab('orgas', null);
}

function seProsenterCandidat(orgaId) {
  const orga = getOrgaById(orgaId);
  if (!orga?.election?.enCours || orga.election.phase !== 'candidatures') { showToast('Indisponible', 'La période de candidature est terminée.', false); return; }
  const estMembre = orga.membres?.some(m => m.nom === state.char?.name);
  if (!estMembre) { showToast('Réservé aux membres', '', false); return; }
  if (orga.election.candidats.some(c => c.nom === state.char?.name)) { showToast('Déjà candidat', '', false); return; }
  orga.election.candidats.push({ nom: state.char?.name });
  sauvegarderOrga(orga);
  updateUI();
  showToast('Candidature enregistrée !', 'Vous êtes candidat à la présidence de "' + orga.nom + '".', true, true);
  if (document.getElementById('vue-self')?.classList.contains('active')) switchSelfTab('orgas', null);
}

function voterElection(orgaId, candidatNom) {
  const orga = getOrgaById(orgaId);
  if (!orga?.election?.enCours || orga.election.phase !== 'vote') { showToast('Indisponible', 'Le vote n\'est pas ouvert.', false); return; }
  const estMembre = orga.membres?.some(m => m.nom === state.char?.name);
  if (!estMembre) { showToast('Réservé aux membres', '', false); return; }
  orga.election.votes[state.char?.name] = candidatNom;
  sauvegarderOrga(orga);
  updateUI();
  showToast('Vote enregistré', 'Vous votez pour ' + candidatNom + '.', true);
  if (document.getElementById('vue-self')?.classList.contains('active')) switchSelfTab('orgas', null);
}

// Fait avancer toutes les elections en cours (candidatures -> vote -> depouillement).
// Appelee par n'importe quel joueur au chargement, comme le championnat.
function verifierElectionsOrganisations() {
  (state.organisations || []).forEach(orga => {
    if (!orga.election?.enCours) return;
    const jour = state.day || 1;

    if (orga.election.phase === 'candidatures' && jour >= orga.election.dateFinCandidatures) {
      orga.election.phase = 'vote';
      sauvegarderOrga(orga);
    }

    if (orga.election.phase === 'vote' && jour >= orga.election.dateFinVote) {
      const decompte = {};
      Object.values(orga.election.votes).forEach(nom => { decompte[nom] = (decompte[nom] || 0) + 1; });
      let vainqueur = null, maxVoix = -1;
      orga.election.candidats.forEach(c => {
        const voix = decompte[c.nom] || 0;
        if (voix > maxVoix) { maxVoix = voix; vainqueur = c.nom; }
      });

      if (vainqueur) {
        orga.chef = vainqueur;
        orga.chefEstPnj = false;
        const def = TYPES_ORGANISATIONS[orga.type];
        const grades = def?.grades?.[orga.country] || [];
        const membre = orga.membres.find(m => m.nom === vainqueur);
        if (membre && grades.length) { membre.grade = grades[grades.length - 1]; membre.gradeIdx = grades.length - 1; }
        addExternalEvent('🗳 ' + vainqueur + ' remporte l\'élection à la présidence de "' + orga.nom + '".');
      }

      orga.election = { enCours: false, phase: null, derniereElection: jour, candidats: [], votes: {} };
      sauvegarderOrga(orga);
    }
  });
}

function doConsulterOrganigrammeSupporters() {
  const orga = getClubSupportersLocal();
  if (!orga) { showToast('Indisponible', 'Aucun club de supporters ici.', false); return; }

  const def = TYPES_ORGANISATIONS.supporters;
  const grades = def?.grades?.[orga.country] || [];

  document.getElementById('postes-modal-title').textContent = 'Organigramme — ' + orga.nom;
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.85rem;color:#C9A84C;font-family:Bebas Neue,sans-serif;letter-spacing:.06em;margin-bottom:.2rem">' + orga.nom + (orga.chefEstPnj ? ' (poste de président vacant — assuré par PNJ)' : '') + '</div>';
  html += '<div style="font-size:.75rem;color:#8a8060;margin-bottom:.8rem">Président actuel : ' + orga.chef + '</div>';

  const membresTries = [...(orga.membres || [])].sort((a, b) => (b.gradeIdx || 0) - (a.gradeIdx || 0));
  html += '<div style="max-height:280px;overflow-y:auto;display:flex;flex-direction:column;gap:.3rem">';
  if (membresTries.length === 0) {
    html += '<div style="font-size:.78rem;color:#5a5040;font-style:italic">Aucun membre pour l\'instant.</div>';
  }
  membresTries.forEach(m => {
    const estChef = m.nom === orga.chef;
    html += '<div style="display:flex;justify-content:space-between;padding:.35rem .5rem;border:1px solid #2a2010;font-size:.78rem;color:' + (estChef ? '#C9A84C' : '#c0b090') + '"><span>' + m.nom + (estChef ? ' 👑' : '') + '</span><span>' + m.grade + '</span></div>';
  });
  html += '</div>';

  if (orga.election?.enCours) {
    html += '<div style="margin-top:1rem;padding:.6rem;border:1px solid #4a3a1a;background:#0f0d05">';
    html += '<div style="font-size:.75rem;color:#C9A84C;font-family:Bebas Neue,sans-serif;letter-spacing:.06em">ÉLECTION EN COURS — ' + (orga.election.phase === 'candidatures' ? 'Candidatures ouvertes' : 'Vote en cours') + '</div>';
    html += '<div style="font-size:.72rem;color:#8a8060;margin-top:.3rem;font-style:italic">« ' + orga.election.motivation + ' » — ' + orga.election.motivateur + '</div>';
    if (orga.election.candidats.length > 0) {
      html += '<div style="font-size:.75rem;color:#c0b090;margin-top:.5rem">Candidats : ' + orga.election.candidats.map(c => c.nom).join(', ') + '</div>';
    }
    html += '</div>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

const PRODUITS_VISUELS_CLUB = {
  'olympique-luthecia': {
    echarpe: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/produit-echarpe-luthecia.png',
    casquette: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/produit-casquette-luthecia.png',
    maillot: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/produit-tshirt-luthecia.png'
  },
  'cheminote-montrouge': {
    echarpe: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/produit-echarpe-montrouge-dediee.png',
    casquette: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/produits-casquette-echarpe-montrouge.png',
    maillot: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/produit-tshirt-montrouge.png'
  },
  'brise-mariannaise': {
    echarpe: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/produits-casquette-echarpe-mariannaise.png',
    casquette: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/produits-casquette-echarpe-mariannaise.png',
    maillot: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/produit-polo-mariannaise.png'
  }
};

// =====================
// BUDGET DU CLUB SPORTIF
// =====================
async function chargerBudgetClub(clubId) {
  if (typeof sbGetBudgetClub !== 'function') return null;
  let data = await sbGetBudgetClub(clubId).catch(() => null);
  if (!data) {
    data = { clubId, caisse: 0, historique: [], derniereSubventionJour: state.day || 1, salaires: { titulaire: 100, remplacant: 50, primeVictoire: 150 } };
    if (typeof sbSaveBudgetClub === 'function') await sbSaveBudgetClub(clubId, data).catch(() => {});
  }
  if (!data.salaires) data.salaires = { titulaire: 100, remplacant: 50, primeVictoire: 150 };
  return data;
}

async function crediterBudgetClub(clubId, montant, motif) {
  const data = await chargerBudgetClub(clubId);
  if (!data) return;
  data.caisse = Math.max(0, (data.caisse || 0) + montant);
  data.historique = data.historique || [];
  data.historique.push({ jour: state.day || 1, montant, motif });
  if (data.historique.length > 50) data.historique = data.historique.slice(-50); // on garde un historique recent, pas infini
  if (typeof sbSaveBudgetClub === 'function') await sbSaveBudgetClub(clubId, data).catch(() => {});
  return data;
}

// Reverse une partie de l'allocation "associatif" du budget municipal vers la caisse du club local, une fois par jour
async function verifierSubventionMairie(club) {
  const budgetMairie = await chargerBudgetMunicipal().catch(() => null);
  if (!budgetMairie) return;
  const budgetClub = await chargerBudgetClub(club.id);
  const jour = state.day || 1;
  const joursEcoules = jour - (budgetClub.derniereSubventionJour || jour);
  if (joursEcoules <= 0) return;

  const dailyRevenue = (typeof CITY_POPULATION !== 'undefined' && CITY_POPULATION[club.country]?.[club.city]?.dailyTaxRevenue) || 2000;
  const montantParJour = Math.round(dailyRevenue * ((budgetMairie.allocation.associatif || 0) / 100) * 0.1); // 10% de la ligne associative, par jour
  const montantTotal = montantParJour * Math.min(joursEcoules, 14);

  if (montantTotal > 0) await crediterBudgetClub(club.id, montantTotal, 'Subvention municipale');
  budgetClub.derniereSubventionJour = jour;
  if (typeof sbSaveBudgetClub === 'function') await sbSaveBudgetClub(club.id, budgetClub).catch(() => {});
}

async function doConsulterBudgetClub() {
  const clubLocal = getClubLocal();
  if (!clubLocal) { showToast('Indisponible', 'Aucun club local ici.', false); return; }

  document.getElementById('postes-modal-title').textContent = 'Budget — ' + clubLocal.nom;
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  await verifierSubventionMairie(clubLocal);
  const data = await chargerBudgetClub(clubLocal.id);

  let html = '<div style="padding:1rem">';
  html += '<div style="text-align:center;font-family:Bebas Neue,sans-serif;font-size:1.3rem;color:#C9A84C;margin-bottom:1rem">' + (data.caisse || 0).toLocaleString('fr-FR') + ' FR</div>';
  html += '<div style="font-size:.72rem;color:#8a8060;margin-bottom:.4rem">Dernières opérations</div>';
  html += '<div style="max-height:220px;overflow-y:auto;display:flex;flex-direction:column;gap:.25rem">';
  if (!data.historique || data.historique.length === 0) {
    html += '<div style="font-size:.75rem;color:#5a5040;font-style:italic">Aucune opération pour l\'instant.</div>';
  } else {
    [...data.historique].reverse().forEach(h => {
      const col = h.montant >= 0 ? '#6ab858' : '#cc6a44';
      html += '<div style="display:flex;justify-content:space-between;font-size:.75rem;padding:.2rem 0;border-bottom:1px solid #1a1208"><span style="color:#c0b090">' + h.motif + '</span><span style="color:' + col + '">' + (h.montant>=0?'+':'') + h.montant.toLocaleString('fr-FR') + ' FR</span></div>';
    });
  }
  html += '</div></div>';
  document.getElementById('postes-body').innerHTML = html;
}

// =====================
// SPONSORING
// =====================
const PALIERS_SPONSORING = [
  { montant: 500, inf: 2, label: 'Sponsor bronze' },
  { montant: 1500, inf: 5, label: 'Sponsor argent' },
  { montant: 3000, inf: 10, label: 'Sponsor officiel' }
];

function doSponsoriserClub() {
  const clubLocal = getClubLocal();
  if (!clubLocal) { showToast('Indisponible', 'Aucun club local ici.', false); return; }

  document.getElementById('postes-modal-title').textContent = 'Sponsoriser ' + clubLocal.nom;
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;margin-bottom:.8rem">Votre nom sera associé au club — visibilité en échange de votre soutien financier.</div>';
  PALIERS_SPONSORING.forEach(p => {
    html += '<button onclick="confirmerSponsoring(' + p.montant + ',\'' + p.label + '\',' + p.inf + ')" style="display:flex;justify-content:space-between;width:100%;margin-bottom:.4rem;padding:.55rem .7rem;border:1px solid #2a2010;background:transparent;color:#c0b090;cursor:pointer;font-size:.8rem">';
    html += '<span>' + p.label + '</span><span style="color:#C9A84C">' + p.montant.toLocaleString('fr-FR') + ' FR · +' + p.inf + ' INF</span></button>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerSponsoring(montant, label, inf) {
  const clubLocal = getClubLocal();
  document.getElementById('modal-postes')?.classList.remove('open');
  if (state.arg < montant) { showToast('Fonds insuffisants', montant + ' FR requis.', false); return; }
  state.arg -= montant;
  state.inf = Math.min(100, (state.inf || 0) + inf);
  clubLocal.sponsorActuel = state.char?.name || null;
  updateUI();
  showToast(label + ' !', 'Votre nom est désormais associé à ' + clubLocal.nom + '. +' + inf + ' INF.', true, true);
  addJournalEntry(label + ' de ' + clubLocal.nom + ' (-' + montant + ' FR, +' + inf + ' INF).', 'event-good');
  await crediterBudgetClub(clubLocal.id, montant, label + ' — ' + (state.char?.name || 'Anonyme'));
}

// =====================
// TRACTS SPORTIFS
// =====================
function doImprimerTractsSportifs() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  document.getElementById('postes-modal-title').textContent = 'Tracts pour un match';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;margin-bottom:.8rem">150 ' + cur + ' le lot de 50 tracts. Actuellement en stock : ' + (state.char?.tractsSportifs || 0) + '.</div>';
  html += '<button onclick="confirmerImpressionTractsSportifs()" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.55rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Commander 50 tracts (150 ' + cur + ')</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerImpressionTractsSportifs() {
  if (state.arg < 150) { showToast('Fonds insuffisants', '150 FR requis.', false); return; }
  state.arg -= 150;
  if (!state.char) return;
  state.char.tractsSportifs = (state.char.tractsSportifs || 0) + 50;
  document.getElementById('modal-postes')?.classList.remove('open');
  updateUI();
  showToast('Tracts imprimés', '50 tracts ajoutés à votre stock.', true, true);
  addJournalEntry('Impression de 50 tracts sportifs (-150 FR).', 'event-good');
}

function calculerFrequentationStade(club, position) {
  const capacite = Math.round(club.valeurBase * 300);
  const tauxRemplissage = Math.max(0.3, 1 - (position - 1) * 0.06);
  return Math.round(capacite * Math.min(1, tauxRemplissage));
}

function bonusClassementTracts(position) {
  // 1er -> x1.5, 12e -> x0.7
  return 1.5 - (position - 1) * (0.8 / 11);
}

async function doDistribuerTractsMatch() {
  const clubLocal = getClubLocal();
  if (!clubLocal) { showToast('Indisponible', 'Aucun club local ici.', false); return; }
  const orgaSupporters = getClubSupportersLocal();
  const estMembre = orgaSupporters?.membres?.some(m => m.nom === state.char?.name);
  if (!estMembre) { showToast('Réservé aux membres', 'Vous devez être membre du club de supporters pour distribuer des tracts ici.', false); return; }
  const stock = state.char?.tractsSportifs || 0;
  if (stock <= 0) { showToast('Aucun tract', 'Faites imprimer des tracts à l\'imprimerie.', false); return; }
  if (!state.char?.candidatures?.length && !state.candidatureEnCours) {
    showToast('Réservé aux candidats', 'Vous devez être candidat déclaré à une élection.', false);
    return;
  }

  const saison = await verifierEtJouerJournees();
  const classement = calculerClassement(saison.calendrier);
  const position = classement.findIndex(c => c.id === clubLocal.id) + 1 || classement.length;

  const frequentation = calculerFrequentationStade(clubLocal, position);
  const distribues = Math.min(stock, frequentation);
  const bonus = bonusClassementTracts(position);
  const voixGagnees = Math.round((distribues / 10) * bonus);

  state.char.tractsSportifs = stock - distribues;
  state.pop = Math.min(100, (state.pop || 0) + Math.round(voixGagnees / 5));
  updateUI();
  showToast('Tracts distribués !', distribues + ' tracts distribués (' + frequentation + ' spectateurs, ' + position + 'e au classement). ~' + voixGagnees + ' électeurs convaincus.', true, true);
  addJournalEntry('Distribution de ' + distribues + ' tracts avant le match de ' + clubLocal.nom + '. ~' + voixGagnees + ' voix gagnées.', 'event-good');
}

// =====================
// MANIFESTATION DU CLUB DE SUPPORTERS
// =====================
async function doOrganiserManifestation() {
  const orga = getClubSupportersLocal();
  if (!orga) { showToast('Indisponible', 'Aucun club de supporters ici.', false); return; }
  const estChef = orga.chef === state.char?.name;
  if (!estChef) { showToast('Réservé au président', 'Seul le président du club de supporters peut organiser une manifestation.', false); return; }
  ouvrirDemandeAutorisationManifester(orga.id);
}

// =====================
// BOYCOTT
// =====================
async function doOrganiserBoycott() {
  const orga = getClubSupportersLocal();
  const clubLocal = getClubLocal();
  if (!orga || !clubLocal) { showToast('Indisponible', '', false); return; }
  const estChef = orga.chef === state.char?.name;
  if (!estChef) { showToast('Réservé au président', 'Seul le président du club de supporters peut décider d\'un boycott.', false); return; }

  const saison = await chargerOuInitialiserSaison();
  const prochaineJournee = saison.calendrier.find(j => j.matchs.some(m => !m.played && m.home === clubLocal.id));
  if (!prochaineJournee) { showToast('Aucun match à domicile', 'Pas de prochain match à domicile pour ce club.', false); return; }
  const match = prochaineJournee.matchs.find(m => !m.played && m.home === clubLocal.id);
  match.boycotte = true;

  document.getElementById('modal-postes')?.classList.remove('open');
  showToast('Boycott décidé', 'Le prochain match à domicile de ' + clubLocal.nom + ' sera boycotté par ses supporters.', true, true);
  addJournalEntry('Le club de supporters décide de boycotter le prochain match à domicile.', 'event-bad');
  addExternalEvent('🚫 Le club de supporters de "' + clubLocal.nom + '" annonce un boycott du prochain match à domicile.');
}

// =====================
// CLASSEMENT DES JOUEURS DU CLUB
// =====================
async function calculerClassementClub(club) {
  const licencies = await sbListJoueursLicencies(club.id).catch(() => []);
  const jour = state.day || 1;
  const dispo = (licencies || []);
  const classement = dispo.map(j => {
    const p = j.performance_sportive || { defense:0, technique:0, endurance:0 };
    const total = (p.defense||0) + (p.technique||0) + (p.endurance||0);
    const blesse = j.blessure_sportive?.jusquauJour > jour;
    return { nom: j.name, perf: p, total, blesse };
  }).sort((a, b) => b.total - a.total);

  classement.forEach((j, i) => {
    if (j.blesse) j.statut = 'blessé';
    else if (j.total <= club.valeurBase * 0.5) j.statut = 'insuffisant';
    else if (i < TITULAIRES_MAX) j.statut = 'titulaire';
    else if (i < TITULAIRES_MAX + REMPLACANTS_MAX) j.statut = 'remplaçant';
    else j.statut = 'non retenu';
  });
  return classement;
}

function getCapitaine(classement) {
  const titulaire = classement.find(j => j.statut === 'titulaire');
  return titulaire ? titulaire.nom : null; // null -> capitaine PNJ par defaut
}

async function doVoirMonClassement() {
  const clubLocal = getClubLocal();
  if (!clubLocal || !state.char?.licenceSportive) {
    showToast('Indisponible', 'Vous devez avoir une licence sportive dans un club.', false);
    return;
  }
  document.getElementById('postes-modal-title').textContent = 'Mon niveau — ' + clubLocal.nom;
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const classement = await calculerClassementClub(clubLocal);
  const position = classement.findIndex(j => j.nom === state.char?.name);
  const moi = classement[position];
  const perf = state.char.performance || { defense:0, technique:0, endurance:0 };

  let html = '<div style="padding:1rem">';
  html += '<div style="text-align:center;margin-bottom:1rem">';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:1.4rem;color:#C9A84C">' + (moi?.total || (perf.defense+perf.technique+perf.endurance)) + ' points</div>';
  html += '<div style="font-size:.8rem;color:#8a8060">Défense ' + perf.defense + ' · Technique ' + perf.technique + ' · Endurance ' + perf.endurance + '</div>';
  html += '</div>';
  if (position >= 0) {
    const statutCol = { titulaire:'#6ab858', 'remplaçant':'#C9A84C', 'non retenu':'#8a8060', blessé:'#cc6a44', insuffisant:'#8a8060' };
    html += '<div style="text-align:center;font-size:.85rem;color:' + (statutCol[moi.statut]||'#c0b090') + '">Position #' + (position+1) + ' — ' + moi.statut.toUpperCase() + '</div>';
  } else {
    html += '<div style="text-align:center;font-size:.8rem;color:#5a5040;font-style:italic">Aucun classement disponible pour l\'instant.</div>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function doConsulterClassementBookmaker() {
  const clubLocal = getClubLocal();
  if (!clubLocal) { showToast('Indisponible', 'Aucun club local ici.', false); return; }
  if (state.arg < 75) { showToast('Fonds insuffisants', '75 FR requis.', false); return; }
  state.arg -= 75;
  updateUI();

  document.getElementById('postes-modal-title').textContent = 'Classement des joueurs — ' + clubLocal.nom;
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const classement = await calculerClassementClub(clubLocal);
  const capitaine = getCapitaine(classement);

  let html = '<div style="padding:1rem">';
  if (classement.length === 0) {
    html += '<div style="font-size:.8rem;color:#5a5040;font-style:italic">Aucun joueur licencié pour l\'instant.</div>';
  } else {
    html += '<div style="max-height:320px;overflow-y:auto;display:flex;flex-direction:column;gap:.25rem">';
    classement.forEach((j, i) => {
      const estCapitaine = j.nom === capitaine;
      html += '<div style="display:flex;justify-content:space-between;padding:.3rem .5rem;border:1px solid #2a2010;font-size:.78rem;color:#c0b090">';
      html += '<span>#' + (i+1) + ' ' + j.nom + (estCapitaine ? ' (C)' : '') + '</span><span style="color:#C9A84C">' + j.total + ' pts</span></div>';
    });
    html += '</div>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  addJournalEntry('Consultation du classement des joueurs de ' + clubLocal.nom + ' (-75 FR).', 'event-info');
}

// =====================
// PRESIDENT DU CLUB SPORTIF
// =====================
async function chargerPresidentClub(clubId) {
  if (typeof sbGetPresidentClub !== 'function') return null;
  let data = await sbGetPresidentClub(clubId).catch(() => null);
  if (!data) {
    data = { president: null, dateElection: null, candidature: null };
    if (typeof sbSavePresidentClub === 'function') await sbSavePresidentClub(clubId, data).catch(() => {});
  }
  return data;
}

// =====================
// DEMANDES D'AUTORISATION DE MANIFESTER
// =====================
const DELAI_DEPOT_MIN_H = 24;
const DELAI_AUTOVALIDATION_H = 12;

function ouvrirDemandeAutorisationManifester(orgaId) {
  const orga = getOrgaById(orgaId);
  if (!orga) return;
  if (orga.chef !== state.char?.name) { showToast('Réservé au chef', 'Seul le chef de l\'organisation peut déposer cette demande.', false); return; }

  const isSupporters = orga.type === 'supporters';

  document.getElementById('postes-modal-title').textContent = 'Demander une autorisation de manifester';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.72rem;color:#8a8060;margin-bottom:.7rem">Le dépôt doit se faire au moins ' + DELAI_DEPOT_MIN_H + 'h avant l\'événement. Validée automatiquement ' + DELAI_AUTOVALIDATION_H + 'h avant si le Ministre de l\'Intérieur n\'a rien décidé.</div>';
  html += '<label style="font-size:.72rem;color:#8a8060;display:block;margin-bottom:.3rem">Sujet du rassemblement</label>';
  html += '<textarea id="manif-sujet-orga" rows="2" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;resize:none;box-sizing:border-box;margin-bottom:.6rem"></textarea>';
  if (isSupporters) {
    html += '<label style="font-size:.72rem;color:#8a8060;display:block;margin-bottom:.3rem">Position vis-à-vis du maire</label>';
    html += '<div style="display:flex;gap:.4rem;margin-bottom:.6rem">';
    html += '<button onclick="document.getElementById(\'manif-sens\').value=\'faveur\';document.querySelectorAll(\'.sens-btn\').forEach(b=>b.style.borderColor=\'#2a2010\');this.style.borderColor=\'#6ab858\'" class="sens-btn" style="flex:1;padding:.4rem;border:1px solid #6ab858;background:transparent;color:#c0b090;cursor:pointer;font-size:.72rem">En faveur</button>';
    html += '<button onclick="document.getElementById(\'manif-sens\').value=\'defaveur\';document.querySelectorAll(\'.sens-btn\').forEach(b=>b.style.borderColor=\'#2a2010\');this.style.borderColor=\'#cc6a44\'" class="sens-btn" style="flex:1;padding:.4rem;border:1px solid #2a2010;background:transparent;color:#c0b090;cursor:pointer;font-size:.72rem">Contre</button>';
    html += '</div><input type="hidden" id="manif-sens" value="faveur"/>';
  }
  html += '<label style="font-size:.72rem;color:#8a8060;display:block;margin-bottom:.3rem">Date (JJ/MM/AAAA)</label>';
  html += '<input id="manif-date" type="date" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-size:.85rem;outline:none;box-sizing:border-box;margin-bottom:.6rem"/>';
  html += '<label style="font-size:.72rem;color:#8a8060;display:block;margin-bottom:.3rem">Heure</label>';
  html += '<input id="manif-heure" type="time" value="18:00" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-size:.85rem;outline:none;box-sizing:border-box;margin-bottom:.8rem"/>';
  html += '<button onclick="confirmerDemandeManifestation(\'' + orgaId + '\')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.55rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Déposer la demande</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerDemandeManifestation(orgaId) {
  const orga = getOrgaById(orgaId);
  const sujet = document.getElementById('manif-sujet-orga')?.value?.trim();
  const dateStr = document.getElementById('manif-date')?.value;
  const heureStr = document.getElementById('manif-heure')?.value;
  const sens = document.getElementById('manif-sens')?.value || null;
  if (!sujet || !dateStr || !heureStr) { showToast('Champs requis', '', false); return; }

  const dateEvenement = new Date(dateStr + 'T' + heureStr + ':00');
  const maintenant = new Date();
  const heuresAvant = (dateEvenement - maintenant) / (1000 * 60 * 60);
  if (heuresAvant < DELAI_DEPOT_MIN_H) {
    showToast('Trop tard', 'La demande doit être déposée au moins ' + DELAI_DEPOT_MIN_H + 'h avant l\'événement.', false);
    return;
  }

  if ((state.pa || 0) < 1) { showToast('PA insuffisants', '1 PA requis.', false); return; }
  state.pa -= 1;
  updateUI();

  const nbMembres = orga.membres?.length || 1;
  const intensite = Math.min(3, 1 + Math.floor(nbMembres / 10));
  const cible = orga.type === 'supporters' ? await getTitulaireMaire(state.country, state.currentCity) : null;

  await sbCreerDemandeManifestation({
    orgaId, orgaNom: orga.nom, orgaType: orga.type,
    pays: state.country, ville: state.currentCity,
    sujet, sens, intensite, cible,
    dateEvenement: dateEvenement.toISOString(),
    dateDepot: maintenant.toISOString()
  });

  document.getElementById('modal-postes')?.classList.remove('open');
  const minIntNom = await getTitulairePoste('min_int');
  if (minIntNom && typeof sbSendMail === 'function') {
    await sbSendMail('Préfecture', minIntNom, 'Nouvelle demande de manifestation',
      orga.nom + ' demande une autorisation pour : "' + sujet + '", le ' + dateEvenement.toLocaleString('fr-FR') + '.', typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : '').catch(() => {});
  }
  showToast('Demande déposée', 'Le Ministère de l\'Intérieur a été notifié.', true, true);
  addJournalEntry('Demande d\'autorisation de manifester déposée pour "' + orga.nom + '".', 'event-good');
}

// Applique l'effet reel d'une demande validee (acceptee ou auto-validee)
async function appliquerEffetManifestationValidee(demande) {
  if (demande.orgaType === 'supporters' && demande.sens && demande.cible) {
    const signe = demande.sens === 'faveur' ? 1 : -1;
    const rows = await sbGet('personnages', `name=eq.${encodeURIComponent(demande.cible)}&select=cha,dup,legitimite`).catch(() => []);
    const r = rows?.[0] || {};
    const nouveauCha = Math.max(0, Math.min(100, (r.cha ?? 50) + signe * 3 * demande.intensite));
    const nouveauDup = Math.max(0, Math.min(100, (r.dup ?? 50) + (signe > 0 ? 3 : -5) * demande.intensite));
    const nouvelleLegitimite = Math.max(0, Math.min(100, (r.legitimite ?? 50) + signe * 4 * demande.intensite));
    await sbUpdate('personnages', `name=eq.${encodeURIComponent(demande.cible)}`, { cha: nouveauCha, dup: nouveauDup, legitimite: nouvelleLegitimite }).catch(() => {});
    if (demande.cible === state.char?.name) { state.cha = nouveauCha; state.dup = nouveauDup; state.legitimite = nouvelleLegitimite; updateUI(); }
    addExternalEvent('📣 Manifestation ' + (demande.sens === 'faveur' ? 'en soutien' : 'contre') + ' le maire, organisée par "' + demande.orgaNom + '".');
  } else {
    addExternalEvent('📣 Manifestation autorisée : "' + demande.sujet + '" (' + demande.orgaNom + ').');
  }
}

async function getElecteursClub(club) {
  const supporters = getClubSupportersLocal ? (state.organisations || []).find(o => o.type === 'supporters' && o.country === club.country && o.city === club.city) : null;
  const classement = await calculerClassementClub(club);
  const capitaine = getCapitaine(classement);
  const maire = await getTitulaireMaire(club.country, club.city);
  return {
    chefSupporters: supporters?.chef || null,
    maire,
    capitaine
  };
}

async function doPostulerPresidentClub() {
  const clubLocal = getClubLocal();
  if (!clubLocal) { showToast('Indisponible', '', false); return; }
  const data = await chargerPresidentClub(clubLocal.id);

  if (data.candidature) { showToast('Candidature en cours', 'Une candidature est déjà en cours de vote.', false); return; }
  if (data.president && data.president !== state.char?.name) {
    const jour = state.day || 1;
    const saison = await chargerOuInitialiserSaison();
    const midSaison = (saison.dateDebut ? joursEcoulesDepuis(saison.dateDebut) : 0) ;
    if (data.dateElection && (jour - data.dateElection) < 8) { // ~mi-saison (saison=11 journees, protection ~ 5-6 sem)
      showToast('Poste protégé', 'Le président en poste ne peut pas être remis en question avant la mi-saison.', false);
      return;
    }
  }

  const electeurs = await getElecteursClub(clubLocal);
  const jour = state.day || 1;
  data.candidature = {
    candidat: state.char?.name,
    dateDebut: jour,
    dateLimite: jour + 2, // 48h ~ 2 jours de jeu
    votes: {},
    electeurs
  };
  await sbSavePresidentClub(clubLocal.id, data);

  const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : '';
  const votants = [electeurs.chefSupporters, electeurs.maire, electeurs.capitaine].filter(Boolean);
  for (const v of votants) {
    if (typeof sbSendMail === 'function') {
      await sbSendMail('Ligue Officielle', v, 'Candidature à la présidence — ' + clubLocal.nom,
        state.char?.name + ' se porte candidat(e) à la présidence de ' + clubLocal.nom + '. Rendez-vous au bureau du président pour voter (48h, silence = accord).', time).catch(() => {});
    }
  }
  showToast('Candidature déposée !', 'Les 3 votants ont été notifiés.', true, true);
  addJournalEntry('Candidature à la présidence de ' + clubLocal.nom + ' déposée.', 'event-good');
}

async function doConsulterBureauPresident() {
  const clubLocal = getClubLocal();
  if (!clubLocal) { showToast('Indisponible', '', false); return; }
  document.getElementById('postes-modal-title').textContent = 'Bureau du Président — ' + clubLocal.nom;
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  await verifierElectionPresident(clubLocal);
  const data = await chargerPresidentClub(clubLocal.id);

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.85rem;color:#C9A84C;font-family:Bebas Neue,sans-serif;margin-bottom:.6rem">Président actuel : ' + (data.president || 'Poste vacant') + '</div>';

  if (data.candidature) {
    const c = data.candidature;
    html += '<div style="border:1px solid #4a3a1a;background:#0f0d05;padding:.6rem;margin-bottom:.8rem">';
    html += '<div style="font-size:.78rem;color:#c0b090;margin-bottom:.4rem">Candidat : ' + c.candidat + '</div>';
    const votants = [
      { role:'Chef supporters', nom: c.electeurs.chefSupporters },
      { role:'Maire', nom: c.electeurs.maire },
      { role:'Capitaine', nom: c.electeurs.capitaine }
    ];
    votants.forEach(v => {
      const vote = v.nom ? c.votes[v.nom] : undefined;
      const estMoi = v.nom === state.char?.name;
      html += '<div style="display:flex;justify-content:space-between;font-size:.75rem;color:#8a8060;padding:.15rem 0">';
      html += '<span>' + v.role + (v.nom ? ' (' + v.nom + ')' : ' — PNJ') + '</span>';
      html += '<span>' + (vote === true ? '✅ Pour' : vote === false ? '❌ Contre' : 'En attente') + '</span></div>';
      if (estMoi && vote === undefined) {
        html += '<div style="display:flex;gap:.4rem;margin-top:.3rem">';
        html += '<button onclick="voterPresidentClub(\'' + clubLocal.id + '\',true)" style="flex:1;padding:.35rem;border:1px solid #4a8a4a;background:transparent;color:#6ab858;cursor:pointer;font-size:.7rem">Pour</button>';
        html += '<button onclick="voterPresidentClub(\'' + clubLocal.id + '\',false)" style="flex:1;padding:.35rem;border:1px solid #8a4a4a;background:transparent;color:#cc6a44;cursor:pointer;font-size:.7rem">Contre</button>';
        html += '</div>';
      }
    });
    html += '</div>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function voterPresidentClub(clubId, vote) {
  const data = await chargerPresidentClub(clubId);
  if (!data.candidature) return;
  data.candidature.votes[state.char?.name] = vote;
  await sbSavePresidentClub(clubId, data);
  document.getElementById('modal-postes')?.classList.remove('open');
  showToast('Vote enregistré', '', true, true);
  await verifierElectionPresident(getClub(clubId));
}

async function verifierElectionPresident(club) {
  const data = await chargerPresidentClub(club.id);
  if (!data.candidature) return;
  const c = data.candidature;
  const jour = state.day || 1;
  const votants = [c.electeurs.chefSupporters, c.electeurs.maire, c.electeurs.capitaine].filter(Boolean);
  const tousVotes = votants.every(v => c.votes[v] !== undefined);
  const delaiDepasse = jour >= c.dateLimite;

  if (!tousVotes && !delaiDepasse) return;

  // Completer les votes manquants par "oui" (silence = accord)
  votants.forEach(v => { if (c.votes[v] === undefined) c.votes[v] = true; });
  const pourCount = Object.values(c.votes).filter(v => v === true).length;
  const valide = pourCount >= 2;

  if (valide) {
    data.president = c.candidat;
    data.dateElection = jour;
    addExternalEvent('🏛 ' + c.candidat + ' est élu(e) président(e) de "' + club.nom + '".');
  } else {
    addExternalEvent('🏛 La candidature de ' + c.candidat + ' à la présidence de "' + club.nom + '" a été rejetée.');
  }
  data.candidature = null;
  await sbSavePresidentClub(club.id, data);
}

// =====================
// TRANSFERTS ENTRE CLUBS
// =====================
async function doProposerTransfert() {
  const clubLocal = getClubLocal();
  if (!clubLocal) { showToast('Indisponible', '', false); return; }
  const dataPresident = await chargerPresidentClub(clubLocal.id);
  if (dataPresident.president !== state.char?.name) { showToast('Réservé au président', 'Seul le président du club peut proposer un transfert.', false); return; }

  document.getElementById('postes-modal-title').textContent = 'Proposer un transfert';
  let html = '<div style="padding:1rem">';
  html += '<label style="font-size:.72rem;color:#8a8060;display:block;margin-bottom:.3rem">Nom du joueur ciblé</label>';
  html += '<input id="transfert-joueur" type="text" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;box-sizing:border-box;margin-bottom:.6rem"/>';
  html += '<label style="font-size:.72rem;color:#8a8060;display:block;margin-bottom:.3rem">Prix proposé au club (FR)</label>';
  html += '<input id="transfert-prix" type="number" value="1000" min="0" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;box-sizing:border-box;margin-bottom:.8rem"/>';
  html += '<button onclick="confirmerPropositionTransfert(\'' + clubLocal.id + '\')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.55rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Envoyer l\'offre</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerPropositionTransfert(clubAchatId) {
  const nomJoueur = document.getElementById('transfert-joueur')?.value?.trim();
  const prix = parseInt(document.getElementById('transfert-prix')?.value || '0');
  if (!nomJoueur || prix <= 0) { showToast('Champs requis', '', false); return; }

  const joueur = await sbGetJoueurClub(nomJoueur);
  if (!joueur?.licence_sportive?.clubId) { showToast('Joueur introuvable', 'Ce joueur n\'a pas de licence sportive active.', false); return; }
  const clubVenteId = joueur.licence_sportive.clubId;
  if (clubVenteId === clubAchatId) { showToast('Déjà dans votre club', '', false); return; }

  const clubVente = getClub(clubVenteId), clubAchat = getClub(clubAchatId);
  const dataVente = await chargerPresidentClub(clubVenteId);
  if (!dataVente.president) { showToast('Club sans président', 'Impossible de négocier avec un club sans président désigné.', false); return; }

  const transfertId = await sbCreerTransfert({
    joueur: nomJoueur, clubDepartId: clubVenteId, clubArriveeId: clubAchatId,
    prixClub: prix, statut: 'propose', proposePar: state.char?.name
  });

  document.getElementById('modal-postes')?.classList.remove('open');
  const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : '';
  if (typeof sbSendMail === 'function') {
    await sbSendMail('Ligue Officielle', dataVente.president, 'Offre de transfert — ' + nomJoueur,
      clubAchat.nom + ' propose ' + prix.toLocaleString('fr-FR') + ' FR pour ' + nomJoueur + '. Rendez-vous au bureau du président de ' + clubVente.nom + ' pour répondre.', time).catch(() => {});
  }
  showToast('Offre envoyée', 'Le président de ' + clubVente.nom + ' a été notifié.', true, true);
  addJournalEntry('Offre de transfert envoyée pour ' + nomJoueur + ' (' + prix + ' FR).', 'event-good');
}

async function doGererOffresTransfert() {
  const clubLocal = getClubLocal();
  if (!clubLocal) { showToast('Indisponible', '', false); return; }
  const dataPresident = await chargerPresidentClub(clubLocal.id);
  if (dataPresident.president !== state.char?.name) { showToast('Réservé au président', '', false); return; }

  document.getElementById('postes-modal-title').textContent = 'Offres de transfert reçues';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const offres = await sbGetTransfertsClubVente(clubLocal.id);
  let html = '<div style="padding:1rem">';
  if (offres.length === 0) {
    html += '<div style="font-size:.8rem;color:#5a5040;font-style:italic">Aucune offre en attente.</div>';
  } else {
    offres.forEach(o => {
      const clubAchat = getClub(o.clubArriveeId);
      html += '<div style="border:1px solid #2a2010;padding:.6rem;margin-bottom:.6rem">';
      html += '<div style="font-size:.8rem;color:#c0b090">' + o.joueur + ' — ' + clubAchat.nom + ' propose ' + o.prixClub.toLocaleString('fr-FR') + ' FR' + (o.statut==='contre_offre'?' (votre contre-offre en attente)':'') + '</div>';
      if (o.statut === 'propose') {
        html += '<div style="display:flex;gap:.4rem;margin-top:.4rem">';
        html += '<button onclick="repondreOffreTransfert(\'' + o.id + '\',\'accepte\')" style="flex:1;padding:.35rem;border:1px solid #4a8a4a;background:transparent;color:#6ab858;cursor:pointer;font-size:.7rem">Accepter</button>';
        html += '<button onclick="repondreOffreTransfert(\'' + o.id + '\',\'refuse\')" style="flex:1;padding:.35rem;border:1px solid #8a4a4a;background:transparent;color:#cc6a44;cursor:pointer;font-size:.7rem">Refuser</button>';
        html += '</div>';
        html += '<input id="contre-' + o.id + '" type="number" placeholder="Contre-offre (FR)" style="width:100%;margin-top:.4rem;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.3rem;font-size:.75rem;outline:none;box-sizing:border-box"/>';
        html += '<button onclick="repondreOffreTransfert(\'' + o.id + '\',\'contre\')" style="width:100%;margin-top:.3rem;padding:.3rem;border:1px solid #4a6a8a;background:transparent;color:#5a8ad0;cursor:pointer;font-size:.7rem">Faire une contre-offre</button>';
      }
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function repondreOffreTransfert(transfertId, action) {
  const rows = await sbGet('transferts_clubs', `id=eq.${encodeURIComponent(transfertId)}`);
  const t = rows?.[0]?.data;
  if (!t) return;
  const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : '';
  const clubAchat = getClub(t.clubArriveeId), clubVente = getClub(t.clubDepartId);
  const dataAchat = await chargerPresidentClub(t.clubArriveeId);

  if (action === 'refuse') {
    t.statut = 'termine';
    await sbMajTransfert(transfertId, t);
    if (dataAchat.president && typeof sbSendMail === 'function') await sbSendMail('Ligue Officielle', dataAchat.president, 'Transfert refusé', clubVente.nom + ' a refusé votre offre pour ' + t.joueur + '.', time).catch(() => {});
    showToast('Offre refusée', '', true);
  } else if (action === 'contre') {
    const montant = parseInt(document.getElementById('contre-' + transfertId)?.value || '0');
    if (!montant) { showToast('Montant requis', '', false); return; }
    t.statut = 'contre_offre'; t.prixClub = montant;
    await sbMajTransfert(transfertId, t);
    if (dataAchat.president && typeof sbSendMail === 'function') await sbSendMail('Ligue Officielle', dataAchat.president, 'Contre-offre de transfert', clubVente.nom + ' propose une contre-offre de ' + montant.toLocaleString('fr-FR') + ' FR pour ' + t.joueur + '.', time).catch(() => {});
    showToast('Contre-offre envoyée', '', true);
  } else if (action === 'accepte') {
    t.statut = 'attente_joueur';
    await sbMajTransfert(transfertId, t);
    if (typeof sbSendMail === 'function') {
      await sbSendMail('Ligue Officielle', t.joueur, 'Offre de transfert vous concernant',
        clubAchat.nom + ' souhaite vous recruter (accord trouvé avec ' + clubVente.nom + ' : ' + t.prixClub.toLocaleString('fr-FR') + ' FR). Consultez vos offres de transfert dans votre fiche personnage.', time).catch(() => {});
    }
    showToast('Accord entre clubs !', 'Le joueur va maintenant être consulté.', true, true);
  }
  document.getElementById('modal-postes')?.classList.remove('open');
}

async function doConsulterMesOffresTransfert() {
  document.getElementById('postes-modal-title').textContent = 'Mes offres de transfert';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const offres = await sbGetTransfertsJoueur(state.char?.name);
  let html = '<div style="padding:1rem">';
  if (offres.length === 0) {
    html += '<div style="font-size:.8rem;color:#5a5040;font-style:italic">Aucune offre en attente.</div>';
  } else {
    offres.forEach(o => {
      const clubAchat = getClub(o.clubArriveeId), clubVente = getClub(o.clubDepartId);
      html += '<div style="border:1px solid #2a2010;padding:.6rem;margin-bottom:.6rem">';
      html += '<div style="font-size:.8rem;color:#c0b090">' + clubAchat.nom + ' souhaite vous recruter depuis ' + clubVente.nom + '</div>';
      html += '<div style="font-size:.75rem;color:#8a8060;margin:.2rem 0">Prime de signature proposée : ' + (o.prixJoueur||0).toLocaleString('fr-FR') + ' FR</div>';
      html += '<div style="display:flex;gap:.4rem">';
      html += '<button onclick="repondreTransfertJoueur(\'' + o.id + '\',true)" style="flex:1;padding:.35rem;border:1px solid #4a8a4a;background:transparent;color:#6ab858;cursor:pointer;font-size:.7rem">Accepter</button>';
      html += '<button onclick="repondreTransfertJoueur(\'' + o.id + '\',false)" style="flex:1;padding:.35rem;border:1px solid #8a4a4a;background:transparent;color:#cc6a44;cursor:pointer;font-size:.7rem">Refuser</button>';
      html += '</div></div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function repondreTransfertJoueur(transfertId, accepte) {
  const rows = await sbGet('transferts_clubs', `id=eq.${encodeURIComponent(transfertId)}`);
  const t = rows?.[0]?.data;
  if (!t) return;
  document.getElementById('modal-postes')?.classList.remove('open');

  if (!accepte) {
    t.statut = 'termine';
    await sbMajTransfert(transfertId, t);
    showToast('Transfert refusé', '', true);
    return;
  }

  // Le joueur accepte : licence basculee, points d'entrainement conserves, argent reparti
  if (state.char?.name === t.joueur) {
    state.char.licenceSportive = { clubId: t.clubArriveeId, dateAchat: state.day || 1 };
    state.arg += (t.prixJoueur || 0);
    updateUI();
  }
  await crediterBudgetClub(t.clubDepartId, t.prixClub, 'Transfert de ' + t.joueur);
  await crediterBudgetClub(t.clubArriveeId, -(t.prixClub), 'Transfert de ' + t.joueur);
  t.statut = 'termine';
  await sbMajTransfert(transfertId, t);
  showToast('Transfert accepté !', 'Vous jouez désormais pour ' + getClub(t.clubArriveeId).nom + '.', true, true);
  addJournalEntry('Transfert accepté vers ' + getClub(t.clubArriveeId).nom + '.', 'event-good');
}

async function doGererSalairesClub() {
  const clubLocal = getClubLocal();
  if (!clubLocal) { showToast('Indisponible', '', false); return; }
  const dataPresident = await chargerPresidentClub(clubLocal.id);
  if (dataPresident.president !== state.char?.name) { showToast('Réservé au président', '', false); return; }

  const budget = await chargerBudgetClub(clubLocal.id);

  document.getElementById('postes-modal-title').textContent = 'Salaires des joueurs — ' + clubLocal.nom;
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.72rem;color:#8a8060;margin-bottom:.8rem">Versés automatiquement après chaque match, prélevés sur la caisse du club.</div>';
  html += '<label style="font-size:.72rem;color:#8a8060;display:block;margin-bottom:.3rem">Forfait titulaire (FR/match)</label>';
  html += '<input id="sal-titulaire" type="number" value="' + budget.salaires.titulaire + '" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-size:.8rem;outline:none;box-sizing:border-box;margin-bottom:.6rem"/>';
  html += '<label style="font-size:.72rem;color:#8a8060;display:block;margin-bottom:.3rem">Forfait remplaçant (FR/match)</label>';
  html += '<input id="sal-remplacant" type="number" value="' + budget.salaires.remplacant + '" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-size:.8rem;outline:none;box-sizing:border-box;margin-bottom:.6rem"/>';
  html += '<label style="font-size:.72rem;color:#8a8060;display:block;margin-bottom:.3rem">Prime de victoire (FR, titulaires uniquement)</label>';
  html += '<input id="sal-prime" type="number" value="' + budget.salaires.primeVictoire + '" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-size:.8rem;outline:none;box-sizing:border-box;margin-bottom:.8rem"/>';
  html += '<button onclick="confirmerSalairesClub(\'' + clubLocal.id + '\')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.55rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Valider</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerSalairesClub(clubId) {
  const budget = await chargerBudgetClub(clubId);
  budget.salaires.titulaire = Math.max(0, parseInt(document.getElementById('sal-titulaire')?.value || '0'));
  budget.salaires.remplacant = Math.max(0, parseInt(document.getElementById('sal-remplacant')?.value || '0'));
  budget.salaires.primeVictoire = Math.max(0, parseInt(document.getElementById('sal-prime')?.value || '0'));
  await sbSaveBudgetClub(clubId, budget);
  document.getElementById('modal-postes')?.classList.remove('open');
  showToast('Salaires mis à jour', '', true, true);
}

function doChoisirAccessoireClub() {
  const clubLocal = getClubLocal();
  if (!clubLocal) { showToast('Indisponible', 'Aucun club local ici.', false); return; }

  const visuels = PRODUITS_VISUELS_CLUB[clubLocal.id] || {};
  const accessoires = [
    { id:'echarpe', label:'Écharpe', prix:80, icon:'ti-scarf' },
    { id:'casquette', label:'Casquette', prix:60, icon:'ti-hat' },
    { id:'maillot', label:'Maillot', prix:150, icon:'ti-shirt' }
  ];

  document.getElementById('postes-modal-title').textContent = 'Accessoires — ' + clubLocal.nom;
  let html = '<div style="padding:1rem;display:flex;flex-direction:column;gap:.6rem">';
  accessoires.forEach(a => {
    const img = visuels[a.id];
    html += '<button onclick="confirmerAchatAccessoireClub(\'' + a.id + '\',\'' + a.label + '\',' + a.prix + ')" style="display:flex;align-items:center;gap:.7rem;padding:.6rem .8rem;border:1px solid #2a2010;background:transparent;color:#c0b090;cursor:pointer;font-size:.8rem;text-align:left">';
    html += img
      ? '<img src="' + img + '" style="width:56px;height:56px;object-fit:cover;border:1px solid #2a2010;flex-shrink:0"/>'
      : '<i class="ti ' + a.icon + '" style="font-size:1.4rem;color:#8a6a20;width:56px;text-align:center;flex-shrink:0"></i>';
    html += '<span style="flex:1">' + a.label + '</span><span style="color:#C9A84C">' + a.prix + ' FR</span></button>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerAchatAccessoireClub(id, label, prix) {
  const clubLocal = getClubLocal();
  document.getElementById('modal-postes').classList.remove('open');
  if (state.arg < prix) { showToast('Fonds insuffisants', prix + ' FR requis.', false); return; }
  state.arg -= prix;
  if (!state.inventory) state.inventory = [];
  state.inventory.push({ type:'accessoire_sport', name: label + ' — ' + clubLocal.nom, icon:'ti-shirt', legal:true });
  updateUI();
  showToast('Achat effectué', label + ' du ' + clubLocal.nom + ' ajouté(e) à votre inventaire.', true, true);
  addJournalEntry('Achat : ' + label + ' du ' + clubLocal.nom + ' (-' + prix + ' FR).', 'event-good');
  await crediterBudgetClub(clubLocal.id, prix, 'Vente boutique : ' + label);
}

function doAcheterAccessoirePersonnalise() {
  showToast('Bientôt disponible', 'La personnalisation (nom, numéro) sera réservée aux comptes premium.', false);
}

function formatDateJournee(saison, numero) {
  const debut = new Date(saison.dateDebut);
  const dateMatch = new Date(debut.getTime() + (numero - 1) * 7 * 86400000);
  return dateMatch.toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit', year: 'numeric' });
}

async function doObserverMatch() {
  document.getElementById('postes-modal-title').textContent = 'Championnat — Résultats & Calendrier';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  let saison = await verifierEtJouerJournees();
  const clubLocal = getClubLocal();

  let html = '<div style="padding:1rem">';

  if (saison.phase === 'terminee' && saison.resultatsFinales) {
    const rf = saison.resultatsFinales;
    html += '<div style="text-align:center;padding:.8rem;border:1px solid #C9A84C;margin-bottom:1rem">';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:1rem;letter-spacing:.1em;color:#C9A84C">🏆 ' + getClub(rf.champion).nom + '</div>';
    html += '<div style="font-size:.75rem;color:#8a8060;margin-top:.3rem">Champion de la saison ' + saison.numero + ' — finale au ' + getClub(rf.stadeClubId).nom + '</div>';
    html += '<div style="font-size:.72rem;color:#6a5a30;margin-top:.3rem">' + rf.finale.recit + '</div>';
    html += '</div>';
    demarrerNouvelleSaison(saison);
  } else if (clubLocal) {
    let prochain = null, dernier = null;
    for (const j of saison.calendrier) {
      const m = j.matchs.find(mm => mm.home === clubLocal.id || mm.away === clubLocal.id);
      if (!m) continue;
      if (m.played) dernier = { journee:j.numero, m };
      else if (!prochain) prochain = { journee:j.numero, m };
    }
    html += '<div style="margin-bottom:1rem"><div style="font-family:Bebas Neue,sans-serif;font-size:.85rem;letter-spacing:.08em;color:#c0b090;margin-bottom:.3rem">' + clubLocal.nom + '</div>';
    if (prochain) {
      const adv = prochain.m.home === clubLocal.id ? prochain.m.away : prochain.m.home;
      const domicile = prochain.m.home === clubLocal.id;
      html += '<div style="font-size:.8rem;color:#8a8060">Prochain match (J' + prochain.journee + ') : ' + (domicile ? 'à domicile contre ' : 'à l\'extérieur face à ') + getClub(adv).nom + '</div>';
    } else {
      html += '<div style="font-size:.8rem;color:#5a5040;font-style:italic">Saison terminée pour ce club.</div>';
    }
    if (dernier) {
      html += '<div style="font-size:.78rem;color:#6ab858;margin-top:.4rem">Dernier résultat (J' + dernier.journee + ') : ' + dernier.m.recit + '</div>';
    }
    html += '</div>';
  }

  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.4rem">CALENDRIER COMPLET</div>';
  html += '<div style="max-height:220px;overflow-y:auto;margin-bottom:1rem">';
  saison.calendrier.forEach(j => {
    html += '<div style="font-size:.68rem;text-align:center;color:#6a5a30;margin:.4rem 0 .1rem">Journée ' + j.numero + ' — ' + formatDateJournee(saison, j.numero) + '</div>';
    j.matchs.forEach(m => {
      const enCours = clubLocal && (m.home === clubLocal.id || m.away === clubLocal.id);
      const ligne = m.played
        ? getClub(m.home).nom + '&nbsp;&nbsp;' + m.scoreHome + ' - ' + m.scoreAway + '&nbsp;&nbsp;' + getClub(m.away).nom
        : getClub(m.home).nom + '&nbsp;&nbsp;vs&nbsp;&nbsp;' + getClub(m.away).nom + ' (à venir)';
      html += '<div style="font-size:.72rem;text-align:center;color:' + (enCours ? '#C9A84C' : '#8a8060') + ';padding:.15rem 0">' + ligne + '</div>';
    });
  });
  html += '</div>';

  const classement = calculerClassement(saison.calendrier);
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.4rem">CLASSEMENT</div>';
  html += '<div style="max-height:280px;overflow-y:auto">';
  html += '<div style="display:grid;grid-template-columns:1.6rem 1fr 2rem 2rem 2rem 2rem 2.4rem;gap:.3rem;font-size:.68rem;color:#6a5a30;padding:.2rem .4rem;border-bottom:1px solid #2a2010"><span>#</span><span>Club</span><span>J</span><span>V</span><span>N</span><span>D</span><span>Pts</span></div>';
  classement.forEach((c, i) => {
    html += '<div style="display:grid;grid-template-columns:1.6rem 1fr 2rem 2rem 2rem 2rem 2.4rem;gap:.3rem;font-size:.74rem;color:' + (clubLocal && c.id === clubLocal.id ? '#C9A84C' : '#c0b090') + ';padding:.25rem .4rem">';
    html += '<span>' + (i+1) + '</span><span>' + c.nom + '</span><span>' + c.j + '</span><span>' + c.v + '</span><span>' + c.n + '</span><span>' + c.d + '</span><span>' + c.pts + '</span></div>';
  });
  html += '</div></div>';

  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function doConsulterPalmares() {
  document.getElementById('postes-modal-title').textContent = 'Palmarès du Championnat';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const saison = await chargerOuInitialiserSaison();
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Historique complet et permanent des saisons passées.</div>';

  if (!saison.palmares || saison.palmares.length === 0) {
    html += '<div style="font-size:.8rem;color:#5a5040;text-align:center;padding:1.5rem 0">Saison ' + saison.numero + ' en cours. Aucun champion couronné pour l\'instant.</div>';
  } else {
    html += '<div style="display:flex;flex-direction:column;gap:.5rem;max-height:340px;overflow-y:auto">';
    [...saison.palmares].reverse().forEach(p => {
      html += '<div style="border:1px solid #2a2010;background:#0a0805;padding:.6rem">';
      html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.08em;color:#C9A84C">Saison ' + p.saison + ' — 🏆 ' + p.champion + '</div>';
      html += '<div style="font-size:.7rem;color:#8a8060;margin-top:.2rem">Finale au ' + p.stade + ' · Finaliste : ' + p.finaliste + '</div>';
      html += '</div>';
    });
    html += '</div>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function doParierMatch() {
  const saison = await verifierEtJouerJournees();

  const prochaineJournee = saison.calendrier.find(j => j.matchs.some(m => !m.played));
  if (!prochaineJournee) { showToast('Aucun pari disponible', 'Plus aucun match à venir cette saison.', false); return; }

  document.getElementById('postes-modal-title').textContent = 'Parier — Journée ' + prochaineJournee.numero;
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;margin-bottom:.6rem">Choisissez un match</div>';
  prochaineJournee.matchs.filter(m => !m.played).forEach(m => {
    html += '<button onclick="ouvrirFormulairePari(\'' + m.home + '\',\'' + m.away + '\',' + prochaineJournee.numero + ',' + saison.numero + ')" style="width:100%;text-align:left;margin-bottom:.4rem;padding:.55rem .7rem;border:1px solid #2a2010;background:transparent;color:#c0b090;cursor:pointer;font-size:.8rem">' + getClub(m.home).nom + ' vs ' + getClub(m.away).nom + '</button>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function ouvrirFormulairePari(homeId, awayId, journeeNumero, saisonNumero) {
  const homeClub = getClub(homeId), advClub = getClub(awayId);

  document.getElementById('postes-modal-title').textContent = 'Parier sur ce match';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#c0b090;margin-bottom:.8rem">' + homeClub.nom + ' (domicile) vs ' + advClub.nom + '</div>';
  html += '<div style="font-size:.72rem;color:#5a5040;font-style:italic;margin-bottom:.6rem">Le pari sera tranché par le vrai résultat du match, pas avant.</div>';
  html += '<label style="font-size:.72rem;color:#8a8060;display:block;margin-bottom:.4rem">Votre pronostic</label>';
  html += '<div style="display:flex;gap:.4rem;margin-bottom:.8rem">';
  html += '<button onclick="document.getElementById(\'pari-choix\').value=\'domicile\';document.querySelectorAll(\'.pari-btn\').forEach(b=>b.style.borderColor=\'#2a2010\');this.style.borderColor=\'#C9A84C\'" class="pari-btn" style="flex:1;padding:.5rem;border:1px solid #C9A84C;background:transparent;color:#c0b090;cursor:pointer;font-size:.72rem">Victoire ' + homeClub.nom + '</button>';
  html += '<button onclick="document.getElementById(\'pari-choix\').value=\'nul\';document.querySelectorAll(\'.pari-btn\').forEach(b=>b.style.borderColor=\'#2a2010\');this.style.borderColor=\'#C9A84C\'" class="pari-btn" style="flex:1;padding:.5rem;border:1px solid #2a2010;background:transparent;color:#c0b090;cursor:pointer;font-size:.72rem">Match nul</button>';
  html += '<button onclick="document.getElementById(\'pari-choix\').value=\'adversaire\';document.querySelectorAll(\'.pari-btn\').forEach(b=>b.style.borderColor=\'#2a2010\');this.style.borderColor=\'#C9A84C\'" class="pari-btn" style="flex:1;padding:.5rem;border:1px solid #2a2010;background:transparent;color:#c0b090;cursor:pointer;font-size:.72rem">Victoire ' + advClub.nom + '</button>';
  html += '</div>';
  html += '<input type="hidden" id="pari-choix" value="domicile"/>';
  html += '<label style="font-size:.72rem;color:#8a8060;display:block;margin-bottom:.4rem">Mise (FR)</label>';
  html += '<input id="pari-mise" type="number" value="100" min="10" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.9rem;outline:none;box-sizing:border-box;margin-bottom:.8rem"/>';
  html += '<button onclick="confirmerPariMatch(\'' + homeId + '\',\'' + awayId + '\',' + journeeNumero + ',' + saisonNumero + ')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.55rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Valider le pari</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerPariMatch(homeId, awayId, journeeNumero, saisonNumero) {
  const mise = parseInt(document.getElementById('pari-mise')?.value || '0');
  const choix = document.getElementById('pari-choix')?.value || 'domicile';
  if (!mise || mise < 10) { showToast('Mise invalide', 'Minimum 10 FR.', false); return; }
  if (state.arg < mise) { showToast('Fonds insuffisants', '', false); return; }

  document.getElementById('modal-postes')?.classList.remove('open');
  state.arg -= mise;
  updateUI();

  await sbCreerPari({
    joueur: state.char?.name, homeId, awayId, choix, mise,
    journeeNumero, saisonNumero
  });

  const homeClub = getClub(homeId), advClub = getClub(awayId);
  showToast('Pari enregistré', mise + ' FR misés sur ' + homeClub.nom + ' vs ' + advClub.nom + '. Résultat au coup de sifflet final.', true, true);
  addJournalEntry('Pari de ' + mise + ' FR sur ' + homeClub.nom + ' vs ' + advClub.nom + '.', 'event-info');
}

// Resout tous les paris en attente pour une journee qui vient d'etre jouee
async function resoudreParisJournee(saisonNumero, journee) {
  if (typeof sbGetParisJourneeNonResolus !== 'function') return;
  const paris = await sbGetParisJourneeNonResolus(journee.numero, saisonNumero).catch(() => []);
  if (!paris.length) return;

  const gains = { domicile: 2.5, nul: 3.5, adversaire: 3 };
  for (const pari of paris) {
    const m = journee.matchs.find(mm => mm.home === pari.homeId && mm.away === pari.awayId);
    if (!m || !m.played) continue;

    let resultatReel;
    if (m.scoreHome > m.scoreAway) resultatReel = 'domicile';
    else if (m.scoreHome < m.scoreAway) resultatReel = 'adversaire';
    else resultatReel = 'nul';

    const gagne = resultatReel === pari.choix;
    const gain = gagne ? Math.round(pari.mise * gains[pari.choix]) : 0;
    await sbResoudrePari(pari.id, pari.joueur, gain);

    const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : '';
    if (typeof sbSendMail === 'function') {
      const msg = gagne
        ? 'Votre pari sur ' + getClub(pari.homeId).nom + ' vs ' + getClub(pari.awayId).nom + ' est gagnant ! +' + gain.toLocaleString('fr-FR') + ' FR.'
        : 'Votre pari sur ' + getClub(pari.homeId).nom + ' vs ' + getClub(pari.awayId).nom + ' est perdant. Mise perdue.';
      await sbSendMail('Ligue Officielle', pari.joueur, gagne ? 'Pari gagné !' : 'Pari perdu', msg, time).catch(() => {});
    }
  }
}
