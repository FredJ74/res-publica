Warning: truncated output (original token count: 158925)
Total output lines: 10114

// =====================
// PLATEAU-ORGANISATIONS-QUETES.JS
// Organisations (sauvegarde/chargement), systeme de quetes, loge maconnique
// =====================

// =====================
// LOOKUP UNIQUE — qui detient reellement un poste, quel que soit son type
// Refonte du 9 aout 2026 : remplace getTitulairePoste (aveugle aux PNJ, ne trouvait que les
// vrais joueurs), getTitulaireMaire (idem, variante maire) et getTitulairePosteNomme (deja
// correcte mais dupliquee) - trois fonctions qui faisaient à peu pres la meme recherche avec
// des resultats differents. Retourne toujours {nom, estPJ} ou null si le poste est vraiment
// vacant (ni PJ ni PNJ).
// =====================
async function getTitulaireActuel(posteId, city, pays, options) {
  // Seulement pour les PNJ municipaux permanents : lecture fraiche, sans cache
  // electoral ni inference depuis le casting. Une panne leve, ce n'est pas une vacance.
  if (options?.lectureFraiche) {
    const { lireTitulaireMunicipal } = await import('./continuite-municipale.mjs');
    if (typeof sbGet !== 'function') throw new Error('Registre municipal indisponible');
    return lireTitulaireMunicipal(posteId, pays || state.country, city, sbGet);
  }
  const country = pays || state.country;

  if (POSTES_NOMMES_EXCLUSIFS[posteId]) {
    // Poste nomme : vrai joueur d'abord (state.poste sur sa fiche), PNJ (titulaires_pnj) en repli.
    if (typeof sbListPersonnages === 'function') {
      try {
        const joueurs = await sbListPersonnages() || [];
        let posteMatch = null;
        const match = joueurs.find(j => {
          let poste = j.poste;
          if (typeof poste === 'string') { try { poste = JSON.parse(poste); } catch(e) { poste = null; } }
          if (j.country !== country || !poste || poste.id !== posteId) return false;
          if (city && poste.city !== city) return false;
          posteMatch = poste;
          return true;
        });
        // posteComplet (25 aout 2026, lot priorite PJ) : ajout additif -- porte l'objet poste
        // integral (id/name/city/nommeLe) pour permettre a l'appelant de verifier une eventuelle
        // protection (estPosteProtege, plateau-politique.js) sans requete supplementaire. Ne
        // change rien pour les appelants existants, qui ne lisaient que .nom/.estPJ.
        if (match) return { nom: match.name, estPJ: true, posteComplet: posteMatch };
      } catch(e) {}
    }
    if (typeof sbGetTitulairePnj === 'function') {
      const nomPnj = await sbGetTitulairePnj(country, posteId, city).catch(() => null);
      if (nomPnj) return { nom: nomPnj, estPJ: false };
    }
    return null;
  }

  // Poste elu (POSTES_ELECTIFS) : cycle.eluId fait autorite (toujours a jour, ecrit par le
  // cron a la resolution de chaque election — bien plus fiable que state.poste des AUTRES
  // joueurs, qui ne se met a jour qu'a LEUR prochaine connexion, voir appliquerVictoireElectorale).
  const villeCycle = (posteId === 'maire' || posteId === 'depute') ? (city || state.currentCity) : null;
  const cle = typeof getCleCycle === 'function' ? getCleCycle(posteId, villeCycle) : posteId;
  // Depute (chantier "Hotel de Ville / elections", 4 septembre 2026) : 3 sieges reels par ville,
  // stockes dans cycle.elus (tableau), jamais cycle.eluId (reserve aux postes a siege unique).
  // Cette fonction ne retourne jamais qu'UN SEUL titulaire par contrat -- repli defensif sur le
  // premier siege pourvu du tableau pour tout appelant generique ; l'organigramme national (qui a
  // besoin des 3 sieges) lit cycle.elus directement, sans passer par ici.
  const lireEluDuCycle = c => posteId === 'depute' ? (Array.isArray(c?.elus) ? c.elus.find(Boolean) : undefined) : c?.eluId;
  let eluId = lireEluDuCycle(CYCLES_ELECTORAUX?.[country]?.[cle]);
  if (eluId === undefined && typeof sbLoadCyclesElectoraux === 'function') {
    const cycles = await sbLoadCyclesElectoraux(country).catch(() => null);
    if (cycles) {
      CYCLES_ELECTORAUX[country] = { ...(CYCLES_ELECTORAUX[country]||{}), ...cycles };
      eluId = lireEluDuCycle(cycles[cle]);
    }
  }
  if (!eluId) return null;

  if (typeof sbListPersonnages === 'function') {
    try {
      const joueurs = await sbListPersonnages() || [];
      const estPJ = joueurs.some(j => j.country === country && j.name === eluId);
      return { nom: eluId, estPJ };
    } catch(e) {}
  }
  return { nom: eluId, estPJ: false };
}

// Structure plate pour les organisations (prepare le support multi-empire futur)
// state.organisations est une liste a plat ; country_origine = empire de creation (regles/grades)

// Cumule les bonus de grade (ORGANISATIONS_DEF[type].bonus) de toutes les organisations dont
// le joueur est membre, par cle de stat (ex: 'nego_cha', 'dis', 'terrain_discount'...).
// Fix 9 aout 2026 : fonction appelee depuis plateau-pnj.js (doFaireDisparaitreCadavre,
// confirmerNegociation) mais jamais definie nulle part - ReferenceError garantie a chaque
// appel, donc negocier_squatteurs et faire_disparaitre_cadavre plantaient systematiquement.
// Les donnees de bonus existaient deja completement dans ORGANISATIONS_DEF, juste jamais lues.
function calculerBonusOrga() {
  const bonus = {};
  const nom = state.char?.name;
  if (!nom || typeof ORGANISATIONS_DEF === 'undefined') return bonus;

  (state.organisations || []).forEach(orga => {
    const monMembre = (orga.membres || []).find(m => m.nom === nom);
    if (!monMembre) return;
    const def = ORGANISATIONS_DEF[orga.type];
    if (!def || !def.bonus) return;
    const monGradeIdx = monMembre.gradeIdx ?? 0;

    // Par stat, ne garder que le meilleur palier debloque (les paliers d'une meme organisation
    // sont des seuils croissants, pas des bonus cumulables entre eux - ex: grade 3 nego_cha
    // remplace le bonus du grade 1/2, il ne s'y ajoute pas).
    const meilleurParStat = {};
    def.bonus.forEach(b => {
      if (b.grade > monGradeIdx) return;
      const actuel = meilleurParStat[b.stat];
      if (actuel === undefined || (typeof b.valeur === 'number' && b.valeur > actuel)) {
        meilleurParStat[b.stat] = b.valeur;
      }
    });

    // En revanche, les bonus de plusieurs organisations DIFFERENTES sur la meme stat se cumulent.
    Object.entries(meilleurParStat).forEach(([stat, valeur]) => {
      if (typeof valeur === 'number') bonus[stat] = (bonus[stat] || 0) + valeur;
      else if (bonus[stat] === undefined) bonus[stat] = valeur;
    });
  });

  return bonus;
}

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
    const r = await rpRedaction('quete_nouvelle',
      'Jeu politique parodique dans ' + (co?.n||'un empire') + '. Genere un TITRE court (5 mots max) et une DESCRIPTION (2 phrases) pour une quete/enquete mysterieuse que les joueurs peuvent resoudre. Format : TITRE: ... DESCRIPTION: ...');
    const texte = r.texte || '';
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
    const r = await rpRedaction('quete_progression',
      'Jeu politique parodique. Quete en cours : "' + quete.titre + '" (' + quete.description + '). Le joueur vient de progresser. Donne UNE phrase courte d\'indice narratif sur la suite (sans reveler le lieu exact), ton mysterieux et parodique.');
    indice = r.texte || indice;
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

  // RECOMPENSE REJOUABLE CORRIGEE (17 septembre 2026, audit des frontieres d'autorite).
  // Avant : la recompense (argent, terrain, objet, dossier) etait distribuee D'ABORD, puis la
  // quete etait marquee resolue par sbMettreAJourQuete(...).catch(() => {}) -- or sbUpdate ne
  // leve jamais, il rend null. Si le marquage echouait, la quete restait 'active' : le joueur
  // pouvait la reboucler et encaisser la recompense autant de fois qu'il le voulait. Et deux
  // joueurs resolvant la meme affaire en meme temps etaient tous deux payes.
  // Desormais : la quete est RECLAMEE d'abord, par une mise a jour conditionnelle au statut
  // 'active' (PostgREST renvoie les lignes reellement modifiees : zero ligne = quelqu'un d'autre
  // l'a prise, ou elle etait deja resolue). La recompense n'est distribuee qu'apres.
  const reclamee = (typeof sbReclamerQuete === 'function')
    ? await sbReclamerQuete(quete.id, state.char?.name || 'Anonyme') : null;
  if (!reclamee) {
    showToast('Affaire déjà classée', 'Cette affaire a déjà été résolue. Aucune récompense n\'a été remise.', false);
    return;
  }

  if (quete.recompense_type === 'terrain') {
    let terrainInfo = null;
    try { terrainInfo = JSON.parse(quete.recompense_detail); } catch(e) {}

    if (terrainInfo) {
      // Re-verifier que le terrain est toujours libre (au cas ou quelqu'un l'aurait pris entre temps)
      const terrainsLibresActuels = await getTerrainsVraimentLibres(state.country);
      const stillLibre = terrainsLibresActuels.some(t => t.buildingId === terrainInfo.buildingId);
      // Chemin technique protege par le gel successoral (n'appartient pas au metier
      // Testament/Succession, voir rapport d'architecture) : une recompense de quete ne doit pas
      // pouvoir attribuer un terrain actuellement immobilise par une succession en cours. Verifie
      // directement le champ (pas refuserSiGele(), qui afficherait un toast redondant avec le
      // message de repli deja existant ci-dessous en cas d'indisponibilite).
      const gele = (typeof idSuccessionGelantActif === 'function') && !!(await idSuccessionGelantActif('terrain', terrainInfo.buildingId).catch(() => null));

      if (stillLibre && !gele) {
        const profiles = TERRAIN_PNJ_PROFILES?.[state.country] || TERRAIN_PNJ_PROFILES?.republic || [];
        const squatterProfiles = profiles.filter(p => p.id === 'squatter_cool' || p.id === 'squatter_agr');
        const squatterChoisi = squatterProfiles[Math.floor(Math.random() * squatterProfiles.length)] || null;

        // UN PATCH, PAS UN BLOB (chantier 5, 10 octobre 2026). Ces quatre cles partaient telles
        // quelles a sbSetTerrainState -- qui ecrit `data` EN ENTIER. Ce terrain perdait donc
        // surface, valeur, ville et tout le reste a l'instant ou il etait gagne. Le correctif de ce
        // patron, revendique ailleurs dans le depot (« Lot 1.5.0 »), n'avait jamais ete propage
        // jusqu'ici. terrain_proprietaire_muter fusionne maintenant le patch sur l'etat REEL lu
        // sous verrou, et verifie que cette quete est bien la mienne et bien resolue.
        const patchQuete = {
          proprietaire: state.char?.name,
          pnj: squatterChoisi?.id || null,
          pnjData: squatterChoisi || null,
          dateGeneration: Date.now()
        };
        const vTerrain = typeof sbRpc === 'function'
          ? await sbRpc('terrain_proprietaire_muter', {
              p_terrain_id: terrainInfo.buildingId, p_titre: 'recompense_quete',
              p_patch: patchQuete, p_reference: quete.id
            }).then(rows => Array.isArray(rows) ? rows[0] : rows).catch(() => null)
          : null;
        const villeNom = WORLD[state.country]?.[terrainInfo.cityId]?.name || terrainInfo.cityId;
        if (vTerrain && vTerrain.ok === true) {
          // Le cache local recopie l'etat arrete par le SERVEUR, jamais le patch.
          if (typeof setTerrainState === 'function' && vTerrain.etat) {
            setTerrainState(terrainInfo.buildingId, vTerrain.etat);
          }
          msg = '🏛️ Vous gagnez un TERRAIN À BÂTIR à ' + villeNom + ' (' + terrainInfo.buildingId + ') ! Attention : des squatteurs s\'y sont déjà installés...';
        } else {
          // LA QUETE EST DEJA CONSOMMEE (sbReclamerQuete est un compare-and-swap irreversible) :
          // on ne peut pas la rendre. On dit la verite plutot que d'annoncer un terrain qui n'a
          // pas change de main -- et la compensation est celle, deja arbitree, du terrain pris.
          const montantCompensation = 1500;
          state.arg = (state.arg || 0) + montantCompensation;
          msg = 'Le transfert du terrain promis à ' + villeNom + " n'a pas pu être enregistré ("
              + ((vTerrain && vTerrain.raison) || 'appel non abouti') + '). En compensation : +'
              + montantCompensation + ' ' + cur + '.';
        }
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


// Affiche le tableau de toutes les organisations connues, groupees par empire.
// Une organisation existe toujours en tant qu'entite connue, meme secrete (secret =
// visibilite, pas existence) : seuls son chef et son siege sont masques pour un visiteur
// qui n'en est pas membre. Un membre (y compris non-chef) garde l'acces complet.
function ouvrirTableauOrganisations() {
  const toutes = state.organisations || [];
  const suisMembreDe = (o) => (o.membres || []).some(m => m.nom === state.char?.name);

  const parEmpire = {};
  toutes.forEach(o => {
    const emp = o.country_origine || o.country || 'republic';
    if (!parEmpire[emp]) parEmpire[emp] = [];
    parEmpire[emp].push(o);
  });

  document.getElementById('postes-modal-title').textContent = 'Tableau des organisations';
  let html = '<div style="padding:1rem">';

  const empireIds = Object.keys(parEmpire);
  if (empireIds.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucune organisation connue pour l\'instant.</div>';
  } else {
    empireIds.forEach(emp => {
      const empireNom = COUNTRIES[emp]?.n || emp;
      html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.85rem;letter-spacing:.12em;color:#C9A84C;margin:.8rem 0 .5rem;border-bottom:1px solid #2a2010;padding-bottom:.3rem">' + empireNom + '</div>';
      parEmpire[emp].forEach(o => {
        const typeDef = TYPES_ORGANISATIONS[o.type] || {};
        const typeLabel = typeDef.label || o.type;
        const masquer = !o.visible && !suisMembreDe(o);
        let infoLigne;
        if (masquer) {
          infoLigne = 'Chef : non communiqué · Siège : non communiqué';
        } else {
          let buildingNom, roomNom;
          if (o.type === 'supporters') {
            const villeCtx = WORLD[o.country_origine || o.country]?.[o.city]?.buildingContext?.['stade'];
            buildingNom = BUILDINGS['stade']?.shortName || BUILDINGS['stade']?.name || 'Stade';
            roomNom = villeCtx?.roomOverrides?.siege_supporters?.name || BUILDINGS['stade']?.rooms?.siege_supporters?.name || 'Siège des Supporters';
          } else {
            const buildingId = (o.localId || '').split(':')[0];
            const roomId = (o.localId || '').split(':')[1];
            buildingNom = BUILDINGS[buildingId]?.shortName || BUILDINGS[buildingId]?.name || buildingId || 'Siège inconnu';
            roomNom = BUILDINGS[buildingId]?.rooms?.[roomId]?.name || '';
          }
          infoLigne = 'Chef : ' + (o.chef || o.fondateur || '?') + ' · Siège : ' + buildingNom + (roomNom ? ' (' + roomNom + ')' : '');
        }
        html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.6rem .8rem;margin-bottom:.5rem">' +
          '<div style="display:flex;justify-content:space-between;align-items:baseline">' +
          '<span style="font-family:Playfair Display,serif;font-size:.95rem;color:#e0d5b8">' + o.nom + (o.visible ? '' : ' 🔒') + '</span>' +
          '<span style="font-size:.7rem;color:#8a6a20">' + typeLabel + '</span>' +
          '</div>' +
          '<div style="font-size:.75rem;color:#8a8060;margin-top:.2rem">' + infoLigne + '</div>' +
          '</div>';
      });
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
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

// Retourne null uniquement si le serveur confirme que le contrat n'est pas encore installe.
// Le repli transitoire disparaitra avec la fermeture globale des anciennes ecritures.
async function organisationEssayerCommande(orgaId, action, parametres) {
  const contexte=equipementsCollectifsContexte();
  const r=await sbOrganisationCommande(orgaId,action,parametres);
  if(!equipementsCollectifsContexteValide(contexte))return false;
  if(r?.disponible===false)return null;
  if(!r?.ok){showToast('Opération non confirmée','Actualisez avant de recommencer. Aucun repli vers une sauvegarde générale.',false);return false;}
  // Un recu rejoue ne contient pas d'ancien solde : relire la ligne courante.
  const fraiche=await sbGetOrganisationParId(orgaId).catch(()=>null);
  if(!equipementsCollectifsContexteValide(contexte))return false;
  if(!fraiche||fraiche.id!==orgaId){showToast('Opération enregistrée','La relecture est indisponible. Actualisez la liste.',true);return false;}
  state.organisations=(state.organisations||[]).map(o=>o.id===orgaId?fraiche:o);
  return true;
}

// Charge toutes les organisations depuis Supabase au demarrage (remplace l'ancien state.orgasEmpire local perdu au rafraichissement)
let RP_ORGANISATIONS_LECTURE = 0;
async function chargerOrganisations() {
  if (typeof sbLoadOrganisations !== 'function') return;
  const version = ++RP_ORGANISATIONS_LECTURE, personnage = state.char;
  const uid = typeof rpAuthUid === 'function' ? rpAuthUid() : null;
  const jeton = typeof rpAuthJeton === 'function' ? rpAuthJeton() : null;
  try {
    const orgas = await sbLoadOrganisations();
    if (version !== RP_ORGANISATIONS_LECTURE || state.char !== personnage
        || (typeof rpAuthUid === 'function' && rpAuthUid() !== uid)
        || (typeof rpAuthJeton === 'function' && rpAuthJeton() !== jeton)) return;
    if (!Array.isArray(orgas)) throw new Error('organisations_lecture_indisponible');
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
  const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : 'Jour ' + (state.day || 1);

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

// Types hors du parcours "creer depuis un local loue" (game design arrete le 26 aout 2026) :
// sportive/supporters relevent de systemes dedies (championnat, clubs de supporters de stade),
// jamais fondes via ce formulaire generique -- deja signale par leur propre maxParCreation:0.
const TYPES_ORGA_EXCLUS_LOCAL_LOUE = ['sportive', 'supporters'];

// Libelles affiches pour CE parcours uniquement (ne modifie pas def.label, qui reste
// "Organisation Criminelle"/"Organisation Mediatique"/"Organisation Economique" partout ailleurs
// -- tableau general, mes organisations, etc.). "secrete" decrit ici la visibilite proposee au
// joueur, pas une nature criminelle imposee.
const LIBELLES_TYPE_ORGA_LOCAL_LOUE = {
  criminelle: 'Organisation Secrète',
  mediatique: 'Organisation de presse',
  economique: 'Organisation commerciale',
};
function libelleTypeOrgaLocalLoue(type, def) {
  return LIBELLES_TYPE_ORGA_LOCAL_LOUE[type] || def.label;
}

function ouvrirCreerOrga() {
  const mesOrgas = getMesOrgasPays();
  const typesDispos = Object.entries(TYPES_ORGANISATIONS).filter(([type, def]) => {
    if (TYPES_ORGA_EXCLUS_LOCAL_LOUE.includes(type)) return false;
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
          '<div style="font-family:Bebas Neue,sans-serif;font-size:.82rem;color:#E8C97A;letter-spacing:.06em">' + libelleTypeOrgaLocalLoue(type, def) + '</div>' +
          '<div style="font-size:.68rem;color:#9a8a68">' + (def.secret ? '🔒 Secrète · ' : '') + 'Requis : ' + formatReqOrga(def.requis) + '</div>' +
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

  document.getElementById('postes-modal-title').textContent = 'Fonder : ' + libelleTypeOrgaLocalLoue(type, def);
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +
    (blocage ? '<div style="background:#1a0808;border:1px solid #5a1a1a;padding:.6rem;margin-bottom:.7rem;font-size:.78rem;color:#cc4444">⛔ ' + blocage + '</div>' : '') +
    '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.3rem">NOM DE L\'ORGANISATION</div>' +
    '<input id="orga-nom-input" type="text" maxlength="40" placeholder="Ex: Loge du Grand Nord, Parti du Progrès..." style="width:100%;padding:.4rem .6rem;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;font-family:Crimson Pro,serif;font-size:.9rem;box-sizing:border-box;margin-bottom:.6rem"/>' +
    '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.3rem">DESCRIPTION (optionnel)</div>' +
    '<textarea id="orga-desc-input" maxlength="200" placeholder="Décrivez votre organisation en quelques mots..." style="width:100%;padding:.4rem .6rem;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;font-family:Crimson Pro,serif;font-size:.85rem;box-sizing:border-box;resize:none;height:60px;margin-bottom:.7rem"></textarea>' +
    (def.secret ? '<div style="font-size:.72rem;color:#6a5a30;font-style:italic;margin-bottom:.7rem">🔒 Confidentialité automatique : chef, siège et membres resteront cachés au public. L\'adhésion se fera uniquement sur invitation.</div>' : '') +
    // corpsMetier (greves, 3 septembre 2026) : tag structurel optionnel, uniquement pour les
    // syndicats -- §9 du cahier des charges ("ne jamais hardcoder un nom du type Syndicat des
    // policiers"). Liste FERMEE (GREVE_CORPS_METIER_OPTIONS, data.js), jamais du texte libre :
    // la consequence mecanique (blocage de la repression policiere) doit rester un choix
    // deliberement assume a la creation, jamais un hasard de nommage.
    (type === 'syndicale' ? (
      '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.3rem">CORPS DE MÉTIER REPRÉSENTÉ (optionnel)</div>' +
      '<select id="orga-corps-metier-select" style="width:100%;padding:.4rem .6rem;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;font-family:Crimson Pro,serif;font-size:.85rem;box-sizing:border-box;margin-bottom:.7rem">' +
      GREVE_CORPS_METIER_OPTIONS.map(o => '<option value="' + o.id + '">' + escapeHtmlText(o.label) + '</option>').join('') +
      '</select>'
    ) : '') +
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
    // Jauge officielle d'influence de l'organisation (0-100, confirmee le 2 septembre 2026,
    // chantier "refonte Lancer une rumeur") -- valeur neutre de depart, jamais undefined/NaN.
    influence: 50,
    localId: state.currentBuilding + ':' + state.currentRoom,
    // Confidentialite entierement determinee par le type (def.secret), plus de choix joueur
    // dans ce parcours (game design arrete le 26 aout 2026) : les 6 types publics restent
    // toujours publics ici, seule "criminelle" (Organisation Secrete) est automatiquement visible:false.
    visible: !def.secret,
  };

  // corpsMetier (greves, 3 septembre 2026) : uniquement propose/lu pour un syndicat -- absent
  // (undefined) pour tout autre type, jamais une chaine vide ecrite en base par defaut.
  if (type === 'syndicale') {
    const corpsMetier = document.getElementById('orga-corps-metier-select')?.value || '';
    if (corpsMetier) nouvelleOrga.corpsMetier = corpsMetier;
  }

  state.organisations.push(nouvelleOrga);
  if (typeof sbSaveOrganisation === 'function') sbSaveOrganisation(nouvelleOrga).catch(() => {});

  // Lier au local en cours si on vient de gerer_local (scope ville ajoute le 2026-08-16 ;
  // les 7 locations sans city ont ete migrees, plus de repli de compatibilite necessaire).
  //
  // roomId ajoute le 6 septembre 2026 (Lot 1.0) : ouvrirCreerOrga() n'a qu'UN seul appelant, le
  // bouton "Creer une organisation ici" de la modale "Gerer mon local"
  // (plateau-justice-economie.js), donc toujours une piece precise. Sans le roomId, un joueur
  // louant deux locaux dans le MEME batiment et la meme ville voyait l'organisation rattachee au
  // premier bail trouve dans le tableau, pas a celui d'ou il venait de cliquer -- sans
  // consequence tant que rien n'etait persiste, mais ecrit desormais reellement en base.
  const location = (state.locationsActives || []).find(l =>
    l.buildingId === state.currentBuilding && l.roomId === state.currentRoom &&
    estTitulaire(l.locataire) && l.city === state.currentCity
  );
  if (location) {
    location.orgaId = id;
    // Persistance reelle (Lot 1.0) : sans cet appel, orgaId ne vivait qu'en memoire et
    // disparaissait au prochain chargerLocations(). Fire-and-forget assume, comme
    // sbSaveOrganisation juste au-dessus : confirmerCreationOrga reste synchrone (son unique
    // appelant est un onclick inline), l'organisation elle-meme est deja creee et valide, et un
    // echec d'ecriture du bail ne doit jamais annuler la fondation. En cas d'echec on restaure
    // la valeur precedente en memoire et on dit exactement au joueur quoi faire.
    if (typeof persisterLocation === 'function') {
      persisterLocation(location).then(ok => {
        if (ok) return;
        location.orgaId = '';
        showToast('Domiciliation non enregistrée',
          'L\'organisation a bien été créée, mais sa domiciliation dans ce local n\'a pas pu être enregistrée. Associez-la depuis « Gérer mon local ».', false);
      }).catch(() => {});
    }
  }

  document.getElementById('modal-postes').classList.remove('open');
  updateUI();
  showToast('Organisation fondée !', '"' + nom + '" est née. Vous en êtes le ' + monGrade + '.', true, true);
  addJournalEntry('Fondation de "' + nom + '" (' + def.label + ').', 'event-good');
  // Fuite corrigee le 26 aout 2026 : cette annonce publique (fondateur + nom d'orga) etait
  // envoyee inconditionnellement, y compris pour une organisation secrete -- exposait le chef
  // et l'existence de l'organisation des sa creation, avant meme tout autre affichage.
  if (nouvelleOrga.visible) {
    addExternalEvent('🏛 ' + (state.char?.name || 'Anonyme') + ' fonde "' + nom + '", une nouvelle ' + def.label + '.');
  }
}

// ------ ONGLET ORGAS ------

function renderOngletOrgas() {
  const mesOrgas = (getMesOrgasPays()).filter(o =>
    o.membres?.some(m => m.nom === state.char?.name)
  );
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  if (mesOrgas.length === 0) {
    return '<div style="padding:1.5rem;text-align:center;color:#9a8a68;font-style:italic;font-size:.85rem">' +
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
    // Avatar personnalise en priorite, fallback icone du type -- meme fonction/doctrine que le
    // forum et la messagerie (getAvatarHtmlPost), un seul rendu partout (17 aout 2026).
    const avatarHtml = typeof getAvatarHtmlPost === 'function'
      ? getAvatarHtmlPost(true, orga.avatar || def.icon || null, orga.nom, 36)
      : '<div style="width:36px;height:36px;border-radius:50%;background:#1a1208;display:flex;align-items:center;justify-content:center"><i class="ti ' + (def.icon||'ti-users') + '" style="font-size:1rem;color:#C9A84C"></i></div>';

    return '<div style="border:1px solid #2a2010;background:#0f0d05;margin-bottom:.8rem">' +

      '<div style="padding:.8rem 1rem;border-bottom:1px solid #1a1208;display:flex;align-items:center;gap:.7rem">' +
        avatarHtml +
        '<div style="flex:1;min-width:0">' +
          '<div style="font-family:Bebas Neue,sans-serif;font-size:.92rem;color:#E8C97A;letter-spacing:.06em">' + orga.nom + '</div>' +
          '<div style="font-size:.72rem;color:#8a8060">' + (def.label||'') + ' · ' + (monMembre?.grade||'') + (estChef ? ' 👑' : '') + ' · ' + (orga.membres?.length||0) + ' membres</div>' +
          (orga.devise ? '<div style="font-size:.85rem;color:#9a8a68;font-style:italic">"' + orga.devise + '"</div>' : '') +
        '</div>' +
        '<div style="font-family:Bebas Neue,sans-serif;font-size:.75rem;color:#C9A84C">' + (orga.caisse||0).toLocaleString('fr-FR') + ' ' + cur + '</div>' +
      '</div>' +

      '<div style="padding:.5rem .8rem;display:flex;flex-wrap:wrap;gap:.35rem;border-bottom:1px solid #1a1208">' +
        '<button onclick="ouvrirForumDepuisOrga(\'' + orga.id + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.85rem;letter-spacing:.06em;padding:.3rem .6rem;border:1px solid #1a3a1a;background:transparent;color:#4a7a4a;cursor:pointer">📋 Forum</button>' +
        '<button onclick="ouvrirMailOrga(\'' + orga.id + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.85rem;letter-spacing:.06em;padding:.3rem .6rem;border:1px solid #1a2a3a;background:transparent;color:#4a6a8a;cursor:pointer">✉️ Courrier</button>' +
        '<button onclick="ouvrirOrdresOrga(\'' + orga.id + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.85rem;letter-spacing:.06em;padding:.3rem .6rem;border:1px solid #2a2a3a;background:transparent;color:#6a6aaa;cursor:pointer">⚡ Actions</button>' +
      '</div>' +

      (estChef ?
        '<div style="padding:.5rem .8rem;display:flex;flex-wrap:wrap;gap:.35rem;border-bottom:1px solid #1a1208">' +
          '<button type="button" data-organisation="' + commercePjEchapper(orga.id) + '" onclick="equipementsCollectifsOuvrir(this.dataset.organisation)">Équipements</button>' +
          '<button onclick="ouvrirGestionMembres(\'' + orga.id + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.85rem;letter-spacing:.06em;padding:.3rem .6rem;border:1px solid #2a3a2a;background:transparent;color:#6a9a6a;cursor:pointer">👥 Membres</button>' +
          (!orga.visible ?
            // Organisation secrete : adhesion uniquement sur invitation, pas de candidature publique.
            '<button onclick="ouvrirInviterMembreOrga(\'' + orga.id + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.85rem;letter-spacing:.06em;padding:.3rem .6rem;border:1px solid #4a3a1a;background:transparent;color:#C9A84C;cursor:pointer">✉️ Inviter</button>' :
            (demandesCount > 0 ?
              '<button onclick="ouvrirDemandesAdhesion(\'' + orga.id + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.85rem;letter-spacing:.06em;padding:.3rem .6rem;border:1px solid #4a3a1a;background:transparent;color:#C9A84C;cursor:pointer">📨 Candidatures (' + demandesCount + ')</button>' :
              '<button disabled style="font-family:Bebas Neue,sans-serif;font-size:.85rem;padding:.3rem .6rem;border:1px solid #1a1a10;background:transparent;color:#9a8a68;cursor:not-allowed">📨 Aucune candidature</button>'
            )
          ) +
          '<button onclick="ouvrirOptionsOrga(\'' + orga.id + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.85rem;letter-spacing:.06em;padding:.3rem .6rem;border:1px solid #3a2a10;background:transparent;color:#8a6a20;cursor:pointer">⚙️ Parametres</button>' +
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
          '<button onclick="doDeclencherElectionClub(1,0)" style="font-family:Bebas Neue,sans-serif;font-size:.85rem;padding:.25rem .5rem;border:1px solid #2a2010;background:transparent;color:#8a8060;cursor:pointer">🗳 Déclencher une élection</button>' +
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
          '<div style="font-size:.85rem;color:#6a5a30">' + m.grade + ' · Depuis Jour ' + m.rejointLe + '</div>' +
        '</div>' +
        (estChef && m.nom !== state.char?.name ?
          '<div style="display:flex;gap:.3rem">' +
            '<button onclick="monterGrade(\'' + orgaId + '\',\'' + m.nom + '\')" title="Monter en grade" style="background:none;border:1px solid #2a3a2a;color:#4a8a4a;cursor:pointer;padding:.2rem .4rem;font-size:.85rem">▲</button>' +
            '<button onclick="descendreGrade(\'' + orgaId + '\',\'' + m.nom + '\')" title="Descendre en grade" style="background:none;border:1px solid #3a2a1a;color:#8a4a2a;cursor:pointer;padding:.2rem .4rem;font-size:.85rem">▼</button>' +
            '<button onclick="exclureMembre(\'' + orgaId + '\',\'' + m.nom + '\')" title="Exclure" style="background:none;border:1px solid #3a1a1a;color:#cc4444;cursor:pointer;padding:.2rem .4rem;font-size:.85rem">✕</button>' +
          '</div>'
        : '') +
      '</div>'
    ).join('') +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function monterGrade(orgaId, nomMembre) {
  const orga = getOrgaById(orgaId);
  if (!orga) return;
  const def = TYPES_ORGANISATIONS[orga.type] || {};
  const grades = def.grades?.[state.country] || ['Membre', 'Cadre', 'Dirigeant', 'Chef'];
  const membre = orga.membres.find(m => m.nom === nomMembre);
  if (!membre || membre.gradeIdx >= grades.length - 1) return;
  const serveur=await organisationEssayerCommande(orgaId,'promouvoir',{nom:nomMembre});
  if(serveur===false)return;
  if(serveur===null){
  membre.gradeIdx++;
  membre.grade = grades[membre.gradeIdx];
  sauvegarderOrga(orga);
  }
  showToast('Grade attribué', nomMembre + ' est maintenant ' + getOrgaById(orgaId).membres.find(m=>m.nom===nomMembre).grade + '.', true);
  ouvrirGestionMembres(orgaId);
}

async function descendreGrade(orgaId, nomMembre) {
  const orga = getOrgaById(orgaId);
  if (!orga) return;
  const def = TYPES_ORGANISATIONS[orga.type] || {};
  const grades = def.grades?.[state.country] || ['Membre', 'Cadre', 'Dirigeant', 'Chef'];
  const membre = orga.membres.find(m => m.nom === nomMembre);
  if (!membre || membre.gradeIdx <= 0) return;
  const serveur=await organisationEssayerCommande(orgaId,'retrograder',{nom:nomMembre});
  if(serveur===false)return;
  if(serveur===null){
  membre.gradeIdx--;
  membre.grade = grades[membre.gradeIdx];
  sauvegarderOrga(orga);
  }
  showToast('Grade retiré', nomMembre + ' est maintenant ' + getOrgaById(orgaId).membres.find(m=>m.nom===nomMembre).grade + '.', false);
  ouvrirGestionMembres(orgaId);
}

async function exclureMembre(orgaId, nomMembre) {
  const orga = getOrgaById(orgaId);
  if (!orga) return;
  const serveur=await organisationEssayerCommande(orgaId,'exclure',{nom:nomMembre});
  if(serveur===false)return;
  if(serveur===null){orga.membres = orga.membres.filter(m => m.nom !== nomMembre);sauvegarderOrga(orga);}
  showToast('Membre exclu', nomMembre + ' a été exclu de ' + orga.nom + '.', false);
  addJournalEntry(nomMembre + ' exclu de "' + orga.nom + '".', 'event-bad');
  ouvrirGestionMembres(orgaId);
}

// ------ DEMANDES D'ADHÉSION ------

async function demanderAdhesion(orgaId) {
  // Recherche directe dans la liste plate (fonctionne deja nativement multi-empire)
  let orga = getOrgaById(orgaId);
  if (!orga) return;
  const def = TYPES_ORGANISATIONS[orga.type] || {};

  // Organisation secrete (26 aout 2026) : adhesion uniquement sur invitation, aucune
  // candidature spontanee possible -- voir ouvrirInviterMembreOrga/accepterInvitationOrga.
  if (!orga.visible) {
    showToast('Adhésion impossible', 'Cette organisation recrute uniquement sur invitation.', false);
    return;
  }

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

  const serveur=await organisationEssayerCommande(orgaId,'demander',{});
  if(serveur===false)return;
  if(serveur===null){
  if (!orga.demandesAdhesion) orga.demandesAdhesion = [];
  orga.demandesAdhesion.push({ nom: state.char?.name, date: state.day || 1 });
  sauvegarderOrga(orga);
  }

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
    (demandes.length === 0 ? '<div style="color:#9a8a68;font-style:italic;font-size:.82rem">Aucune demande en attente.</div>' :
      demandes.map(d =>
        '<div style="display:flex;align-items:center;gap:.6rem;padding:.5rem 0;border-bottom:1px solid #1a1208">' +
          '<div style="flex:1"><div style="font-size:.82rem;color:#c0b090">' + d.nom + '</div><div style="font-size:.85rem;color:#9a8a68">Demande du Jour ' + d.date + '</div></div>' +
          '<button onclick="accepterAdhesion(\'' + orgaId + '\',\'' + d.nom + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.85rem;padding:.25rem .5rem;border:1px solid #2a4a2a;background:transparent;color:#4a8a4a;cursor:pointer;margin-right:.3rem">✓ Accepter</button>' +
          '<button onclick="refuserAdhesion(\'' + orgaId + '\',\'' + d.nom + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.85rem;padding:.25rem .5rem;border:1px solid #3a1a1a;background:transparent;color:#aa4444;cursor:pointer">✕ Refuser</button>' +
        '</div>'
      ).join('')
    ) +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function accepterAdhesion(orgaId, nomCandidat) {
  const orga = getOrgaById(orgaId);
  if (!orga) return;
  const def = TYPES_ORGANISATIONS[orga.type] || {};
  const grades = def.grades?.[state.country] || ['Membre'];

  const serveur=await organisationEssayerCommande(orgaId,'admettre',{nom:nomCandidat});
  if(serveur===false)return;
  if(serveur===null){
  orga.demandesAdhesion = (orga.demandesAdhesion || []).filter(d => d.nom !== nomCandidat);
  orga.membres.push({ nom: nomCandidat, grade: grades[0], gradeIdx: 0, rejointLe: state.day || 1 });
  sauvegarderOrga(orga);
  }
  showToast('Membre accepté', nomCandidat + ' rejoint "' + orga.nom + '" comme ' + grades[0] + '.', true);
  addJournalEntry(nomCandidat + ' accepté dans "' + orga.nom + '".', 'event-good');
  ouvrirDemandesAdhesion(orgaId);
}

async function refuserAdhesion(orgaId, nomCandidat) {
  const orga = getOrgaById(orgaId);
  if (!orga) return;
  const serveur=await organisationEssayerCommande(orgaId,'refuser_demande',{nom:nomCandidat});
  if(serveur===false)return;
  if(serveur===null){
  orga.demandesAdhesion = (orga.demandesAdhesion || []).filter(d => d.nom !== nomCandidat);
  sauvegarderOrga(orga);
  }
  showToast('Demande refusée', nomCandidat + ' a été refusé.', false);
  ouvrirDemandesAdhesion(orgaId);
}

// ------ INVITATION (organisations secretes) ------
// Regle arretee le 26 aout 2026 : on entre dans une organisation secrete UNIQUEMENT sur
// invitation, jamais par candidature spontanee (cf. garde ajoutee dans demanderAdhesion).
// Aucun systeme d'invitation generique ne preexistait dans le code (seul un mecanisme de
// candidature/acceptation, a sens inverse, existait pour les organisations publiques) : ce
// bloc reutilise entierement le canal deja existant et deja valide pour ce genre de flux
// (mail prive avec bouton d'action integre -- meme doctrine que la nomination a un poste
// nomme, envoyerNominationPosteNomme/accepterNominationPosteNomme dans plateau-politique.js),
// sans creer de deuxieme systeme de messagerie. Aucune permission de recrutement dediee
// n'existe dans le modele d'organisation actuel (seul le grade est modelise) : seul le chef
// peut inviter, regle provisoire signalee dans le rapport comme demande au §7.

// Ouvre la selection d'un destinataire (reserve au chef d'une organisation secrete).
async function ouvrirInviterMembreOrga(orgaId) {
  const orga = getOrgaById(orgaId);
  if (!orga || orga.chef !== state.char?.name || orga.visible) return;

  document.getElementById('postes-modal-title').textContent = '✉️ Inviter — ' + orga.nom;
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a8060;font-style:italic">Recherche des personnages...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const tous = typeof sbListPersonnages === 'function' ? await sbListPersonnages().catch(() => []) : [];
  const membresActuels = new Set((orga.membres || []).map(m => m.nom));
  const dejaInvites = new Set((orga.invitationsEnvoyees || []).map(i => i.nom));
  const eligibles = (tous || []).filter(j =>
    j.country === orga.country_origine && j.name !== state.char?.name && !membresActuels.has(j.name) && !dejaInvites.has(j.name)
  );

  if (eligibles.length === 0) {
    document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a8060;font-style:italic">Aucun personnage disponible à inviter.</div>';
    return;
  }

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.72rem;color:#8a8060;margin-bottom:.6rem">L\'invitation est privée : seul(e) le/la destinataire en a connaissance.</div>';
  html += '<select id="invite-orga-select" style="width:100%;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;padding:.4rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.6rem">';
  eligibles.forEach(j => { html += '<option value="' + j.name + '">' + j.name + '</option>'; });
  html += '</select>';
  html += '<button onclick="envoyerInvitationOrga(\'' + orgaId + '\')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">Envoyer l\'invitation</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

// Envoie l'invitation par mail prive, avec deux boutons integres au corps du message (identique
// dans son principe a la nomination a un poste nomme -- accepter -- complete ici d'un refus
// explicite). L'invitation est aussi enregistree dans orga.invitationsEnvoyees (meme forme que
// demandesAdhesion) : c'est cette entree, retiree des qu'accepterInvitationOrga OU
// refuserInvitationOrga s'execute, qui rend l'invitation a usage unique -- un second clic sur
// l'un ou l'autre bouton du meme mail (ou une reponse tardive apres traitement) ne trouve plus
// rien en attente et n'a donc aucun effet.
async function envoyerInvitationOrga(orgaId) {
  const orga = getOrgaById(orgaId);
  if (!orga || orga.chef !== state.char?.name || orga.visible) return;
  const destinataire = document.getElementById('invite-orga-select')?.value;
  if (!destinataire) return;
  if ((orga.invitationsEnvoyees || []).some(i => i.nom === destinataire)) {
    showToast('Invitation déjà envoyée', destinataire + ' a déjà une invitation en attente.', false); return;
  }

  const serveur=await organisationEssayerCommande(orgaId,'inviter',{nom:destinataire});
  if(serveur===false)return;
  if(serveur===true){
    document.getElementById('modal-postes').classList.remove('open');
    showToast('Invitation envoyée',destinataire+' a reçu votre invitation.',true);
    addJournalEntry('Invitation envoyée à '+destinataire+' pour "'+orga.nom+'".','');
    return;
  }

  document.getElementById('modal-postes').classList.remove('open');

  const nomInvitant = state.char?.name || 'Anonyme';
  const nomInvitantEchap = nomInvitant.replace(/'/g,"\\'");
  const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : 'Jour ' + (state.day || 1);
  const sujet = 'Invitation — ' + orga.nom;
  const corps = 'L\'organisation <strong>' + orga.nom + '</strong> vous invite à la rejoindre.<br><br>' +
    '<em>Cette invitation est privée : personne d\'autre n\'en a connaissance.</em><br><br>' +
    marqueurActionMail('orga_oui', orgaId, nomInvitantEchap) + marqueurActionMail('orga_non', orgaId, nomInvitantEchap);

  if (typeof sbSendMail === 'function') {
    await sbSendMail(orga.nom, destinataire, sujet, corps, time).catch(() => {});
    if (!orga.invitationsEnvoyees) orga.invitationsEnvoyees = [];
    orga.invitationsEnvoyees.push({ nom: destinataire, date: state.day || 1 });
    sauvegarderOrga(orga);
    showToast('Invitation envoyée', destinataire + ' a reçu votre invitation.', true);
    addJournalEntry('Invitation envoyée à ' + destinataire + ' pour "' + orga.nom + '".', '');
  } else {
    showToast('Erreur', 'Système de mail indisponible.', false);
  }
}

// Appelée quand le destinataire clique "Accepter l'invitation" dans le mail.
async function accepterInvitationOrga(orgaId, nomInvitant) {
  const orga = getOrgaById(orgaId);
  if (!orga) { showToast('Invitation expirée', 'Cette organisation n\'existe plus.', false); return; }
  if (!(orga.invitationsEnvoyees || []).some(i => i.nom === state.char?.name)) {
    showToast('Invitation déjà traitée', 'Cette invitation n\'est plus valable.', false); return;
  }
  if (orga.membres?.some(m => m.nom === state.char?.name)) {
    showToast('Déjà membre', 'Vous êtes déjà membre de cette organisation.', false); return;
  }
  const def = TYPES_ORGANISATIONS[orga.type] || {};
  const mesOrgas = getMesOrgasPays();
  const dejaType = mesOrgas.some(o => o.type === orga.type && o.membres?.some(m => m.nom === state.char?.name));
  if (dejaType) {
    showToast('Limite atteinte', 'Vous appartenez déjà à une organisation de type ' + (def.label || orga.type) + '.', false); return;
  }

  const serveur=await organisationEssayerCommande(orgaId,'accepter_invitation',{});
  if(serveur===false)return;
  if(serveur===null){
  orga.invitationsEnvoyees = (orga.invitationsEnvoyees || []).filter(i => i.nom !== state.char?.name);
  const grades = def.grades?.[state.country] || ['Membre'];
  if (!orga.membres) orga.membres = [];
  orga.membres.push({ nom: state.char?.name, grade: grades[0], gradeIdx: 0, rejointLe: state.day || 1 });
  sauvegarderOrga(orga);
  }

  showToast('Invitation acceptée', 'Vous rejoignez "' + orga.nom + '" comme ' + getOrgaById(orgaId).membres.find(m=>m.nom===state.char.name).grade + '.', true);
  addJournalEntry('Invitation acceptée : membre de "' + orga.nom + '".', 'event-good');

  if (typeof sbSendMail === 'function' && nomInvitant) {
    const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : 'Jour ' + (state.day || 1);
    sbSendMail(orga.nom, nomInvitant, 'Invitation acceptée', (state.char?.name || 'Le destinataire') + ' a rejoint ' + orga.nom + '.', time).catch(() => {});
  }
  updateUI();
}

// Appelée quand le destinataire clique "Refuser l'invitation" dans le mail.
async function refuserInvitationOrga(orgaId, nomInvitant) {
  const orga = getOrgaById(orgaId);
  if (!orga) { showToast('Invitation expirée', 'Cette organisation n\'existe plus.', false); return; }
  if (!(orga.invitationsEnvoyees || []).some(i => i.nom === state.char?.name)) {
    showToast('Invitation déjà traitée', 'Cette invitation n\'est plus valable.', false); return;
  }

  const serveur=await organisationEssayerCommande(orgaId,'refuser_invitation',{});
  if(serveur===false)return;
  if(serveur===null){
  orga.invitationsEnvoyees = (orga.invitationsEnvoyees || []).filter(i => i.nom !== state.char?.name);
  sauvegarderOrga(orga);
  }

  showToast('Invitation refusée', '', false);
  addJournalEntry('Invitation refusée : "' + orga.nom + '".', '');

  // Retour prive au chef uniquement (aucune information publique generee).
  if (typeof sbSendMail === 'function' && nomInvitant) {
    const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : 'Jour ' + (state.day || 1);
    sbSendMail(orga.nom, nomInvitant, 'Invitation refusée', (state.char?.name || 'Le destinataire') + ' a refusé de rejoindre ' + orga.nom + '.', time).catch(() => {});
  }
}

// ------ ORDRES SPÉCIFIQUES ------

function ouvrirOrdresOrga(orgaId) {
  const orga = getOrgaById(orgaId);
  if (!orga) return;
  const def = TYPES_ORGANISATIONS[orga.type] || {};
  // visibleSi (greves, 3 septembre 2026) : filtre un ordre selon l'etat courant de CETTE
  // organisation (ex. "Lancer une greve" disparait pendant qu'une greve est deja active, "Mettre
  // fin" n'apparait que dans ce cas) -- generique, retro-compatible (absent = toujours visible,
  // comportement inchange pour tous les ordres existants avant ce lot).
  const ordres = (def.ordres || []).filter(o => !o.visibleSi || o.visibleSi(orga));
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const monMembre = orga.membres?.find(m => m.nom === state.char?.name);
  const monGradeIdx = monMembre?.gradeIdx || 0;
  const estChef = orga.chef === state.char?.name;

  document.getElementById('postes-modal-title').textContent = '⚡ Actions — ' + orga.nom;
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.6rem 1rem">' +
    ordres.map(ordre => {
      const rangMin = (typeof ORGA_ORDRE_RANG_MIN !== 'undefined' && ORGA_ORDRE_RANG_MIN[ordre.fn]) || 0;
      // chefOnly (greves, 3 septembre 2026) : gate complementaire a ORGA_ORDRE_RANG_MIN (base
      // sur le grade) -- le chef n'est pas necessairement le membre au grade le plus eleve.
      const rangInsuffisant = monGradeIdx < rangMin;
      const chefRequisManquant = !!ordre.chefOnly && !estChef;
      const disabled = rangInsuffisant || chefRequisManquant;
      return '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.6rem .8rem;margin-bottom:.4rem' + (disabled ? ';opacity:.4' : '') + '">' +
        '<div style="display:flex;align-items:center;gap:.5rem;margin-bottom:.3rem">' +
          '<i class="ti ' + ordre.icon + '" style="font-size:.9rem;color:#C9A84C"></i>' +
          '<div style="font-family:Bebas Neue,sans-serif;font-size:.78rem;color:#E8C97A">' + ordre.label + '</div>' +
          '<div style="margin-left:auto;font-size:.85rem;color:#8a6a20">' + ordre.pa + ' PA' + (TEST_MODE && ordre.pa > 0 ? ' (illimité' + (ordre.pa > 1 ? 's' : '') + ')' : '') + (ordre.cost > 0 ? ' · ' + ordre.cost.toLocaleString('fr-FR') + ' ' + cur : '') + '</div>' +
        '</div>' +
        '<div style="font-size:.68rem;color:#6a5a30;margin-bottom:.4rem">' + ordre.desc + '</div>' +
        (disabled ?
          '<div style="font-size:.85rem;color:#5a3a2a">' + (chefRequisManquant ? 'Réservé au chef.' : 'Rang insuffisant pour cet ordre.') + '</div>' :
          '<button onclick="executerOrdreOrga(\'' + orgaId + '\',\'' + ordre.fn + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.85rem;letter-spacing:.06em;padding:.25rem .6rem;border:1px solid #3a2a10;background:transparent;color:#C9A84C;cursor:pointer">Exécuter</button>'
        ) +
      '</div>';
    }).join('') +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function executerOrdreOrga(orgaId, fn) {
  const orga = getOrgaById(orgaId);
  if (!orga) return;

  if (fn === 'demander_autorisation_manifester') { ouvrirDemandeAutorisationManifester(orgaId); return; }
  // Greves (3 septembre 2026) : chacune ouvre son propre formulaire (cible/revendications) ou sa
  // propre confirmation, avant toute deduction de PA -- meme doctrine que la manifestation
  // ci-dessus, jamais le chemin generique effets{} plus bas (qui deduit AVANT de savoir si le
  // joueur ira au bout du formulaire).
  if (fn === 'greve_lancer') { ouvrirLancerGreve(orgaId); return; }
  if (fn === 'greve_terminer') { confirmerTerminerGreve(orgaId); return; }
  if (fn === 'greve_generale_appeler') { ouvrirAppelGreveGenerale(orgaId); return; }
  if (fn === 'greve_generale_retirer') { confirmerRetraitGreveGenerale(orgaId); return; }

  const def = TYPES_ORGANISATIONS[orga.type] || {};
  const ordre = (def.ordres || []).find(o => o.fn === fn);
  if (!ordre) return;
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  // GARDE D'AUTORITE SUR LES ORDRES FINANCIERS — CENTRALISEE ICI (Lot 4.3).
  //
  // DEFAUT PREEXISTANT CORRIGE : cette fonction n'avait AUCUNE garde de role. N'importe quel joueur
  // connaissant l'identifiant d'une organisation pouvait appeler orga_dividendes et transferer 30 %
  // de sa caisse vers son propre portefeuille. Le rang minimum et chefOnly n'etaient verifies qu'a
  // l'affichage des boutons, jamais ici.
  //
  // LA GARDE EST POSEE EN UN SEUL POINT, avant toute deduction et tout effet : ajouter un ordre
  // financier a un type d'organisation ne peut plus faire oublier le controle.
  if (ORDRES_ORGA_FINANCIERS.indexOf(fn) !== -1) {
    const v = verdictAutoriteCaisseOrga(orga, state.char?.name);
    if (!v.ok) {
      showToast('Accès refusé', v.message || 'Vous ne gérez pas la caisse de cette organisation.', false);
      return;
    }
  }

  // Vérif coût financier (garde metier/financiere conservee). La disponibilite des PA est
  // desormais tranchee uniquement par deduireCoutOrdre() ci-dessous (Lot 1, correctif suite a
  // revue) -- plus de garde manuelle state.pa<..., qui bloquait a tort meme sous
  // TEST_MODE=true.
  if (ordre.cost > 0 && state.arg < ordre.cost) { showToast('Fonds insuffisants', ordre.cost + ' ' + cur + ' requis.', false); return; }

  // Deduction PA+cout centralisee -- deduireCoutOrdre() est l'AUTORITE UNIQUE sur la
  // disponibilite des PA. Appelee avant tout effet de bord (bloc "effets" plus bas) :
  // fail-closed.
  const effets = {
    orga_petition:       () => { const gain = Math.floor(Math.random()*8)+3; state.pop = Math.min(100,(state.pop||0)+gain); showToast('Pétition lancée !','+'+gain+' POP.',true); addJournalEntry('Pétition de "'+orga.nom+'". +'+gain+' POP.','event-good'); addExternalEvent('📋 "'+orga.nom+'" lance une pétition publique.'); },
    orga_meeting:        () => { state.pop=Math.min(100,(state.pop||0)+5); state.inf=Math.min(100,(state.inf||0)+3); showToast('Meeting !','+5 POP +3 INF.',true,true); addJournalEntry('Meeting de "'+orga.nom+'".','event-good'); addExternalEvent('📢 "'+orga.nom+'" organise un meeting.'); },
    orga_collecte:       () => { const don=Math.floor(Math.random()*500)+200; orga.caisse=(orga.caisse||0)+don; showToast('Collecte réussie !','+'+don+' '+cur+' dans la caisse.',true); addJournalEntry('Collecte "'+orga.nom+'". +'+don+' '+cur+'.','event-good'); },
    orga_dividendes:     () => { const part=Math.floor((orga.caisse||0)*0.3); if(part<10){showToast('Caisse vide','Pas assez de fonds à distribuer.',false);return;} orga.caisse-=part; crediterFondsOrdinaires(part); showToast('Dividendes versés !','+'+part+' '+cur+'.',true); addJournalEntry('Dividendes reçus de "'+orga.nom+'". +'+part+' '+cur+'.','event-good'); },
    orga_benediction:    () => { state.moral=Math.min(100,(state.moral||50)+10); state.pop=Math.min(100,(state.pop||0)+5); showToast('Bénédiction !','Cérémonie en votre honneur. +10 Moral +5 POP.',true,true); addJournalEntry('Bénédiction de "'+orga.nom+'".','event-good'); addExternalEvent('✨ "'+orga.nom+'" organise une cérémonie de bénédiction.'); },
    orga_anatheme:       () => { state.moral=Math.max(0,(state.moral||50)-15); state.pop=Math.max(0,(state.pop||0)-10); showToast('Anathème !','Cérémonie contre un PJ. -15 Moral -10 POP à la cible.',false); addJournalEntry('Anathème prononcé par "'+orga.nom+'".','event-bad'); addExternalEvent('⛧ "'+orga.nom+'" prononce un anathème public.'); },
    orga_pelerinage:     () => { state.pop=Math.min(100,(state.pop||0)+8); showToast('Pèlerinage !','+8 POP. Grand rassemblement.',true,true); addExternalEvent('🕊 "'+orga.nom+'" organise un grand pèlerinage.'); },
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

  // ---------------------------------------------------------------------------
  // AUCUN PAIEMENT POUR UN ORDRE SANS EFFET (20 septembre 2026).
  //
  // La table des effets est remontee ICI, AVANT le paiement, pour qu'on puisse verifier
  // qu'un effet existe avant de prelever quoi que ce soit. C'est la condition qui rend sur
  // le correctif du paiement juste en dessous : sans elle, transmettre enfin le nom de
  // l'ordre transformerait les ordres encore non implementes en boutons REELLEMENT
  // factures -- jusqu'a 2 000 FR et 4 PA pour une action qui ne fait rien.
  //
  // Le repli historique affichait « Action executee. » sur un ordre sans effet : c'etait la
  // seule ligne du code qui affirmait au joueur quelque chose de faux. Il dit desormais la
  // verite, et surtout il ne coute rien.
  if (!effets[fn]) {
    showToast('Action indisponible', (ordre.label || 'Cette action') + " n'est pas encore en service.", false);
    return;
  }

  // LE NOM DE L'ORDRE EST ENFIN TRANSMIS (20 septembre 2026).
  //
  // Il manquait. deduireCoutOrdre retombait alors sur state._ordreEnCours -- le dernier ordre
  // de PLATEAU joue, aucun ordre d'organisation ne passant par doOrder. payer_ordre etant
  // fail-closed sur le couple (PA, cout) declare pour ce fn, l'ordre etait facture sous le nom
  // d'un autre et refuse : le joueur voyait « PA insuffisants » avec trente PA en poche.
  // Ce defaut frappait les 34 ordres d'organisation, y compris ceux qui ont un effet.
  const r = await deduireCoutOrdre({ pa: ordre.pa, cost: ordre.cost, fn: fn });
  if (!r.ok) {
    showToast(r.raison === 'fonds_insuffisants' ? 'Fonds insuffisants' : 'PA insuffisants',
      r.raison === 'fonds_insuffisants' ? ordre.cost + ' ' + cur + ' requis.' : ordre.pa + ' PA requis.', false);
    return;
  }

  // ORDRES CRIMINELS RETIRES le 20 septembre 2026 (arbitrage GD). orga_racket,
  // orga_contrebande et orga_blanchiment crediaient un montant tire au sort sans
  // debiter personne, et promettaient des mecaniques inexistantes : « extorquer un
  // commerce ou PJ » sans jamais lire ni debiter une cible, « arrestation risquee »
  // sans declencher d'arrestation, « +DIS » alors qu'ils ne pouvaient que la faire
  // baisser, une « cargaison » n'entrant dans aucun stock. Jamais arbitres depuis
  // leur introduction (V29, 16 juin 2026), et deja signales comme non tranches par
  // l'audit du 27 aout 2026. Supprimes sans mecanique de remplacement : le principe
  // est de ne pas remplacer une interaction humaine par un bouton automatique.
  // Effets selon fonction

  // L'absence d'effet a deja ete tranchee plus haut, AVANT le paiement : on ne peut plus
  // arriver ici sans effet. La branche de repli est conservee en garde defensive, mais elle
  // n'affirme plus qu'une action a ete executee -- c'est ce mensonge qui faisait croire au
  // joueur qu'un ordre fantome avait produit quelque chose.
  const effet = effets[fn];
  if (effet) { effet(); }
  else { console.error('[orga] ordre sans effet parvenu apres paiement : ' + fn); }

  sauvegarderOrga(orga);
  document.getElementById('modal-postes').classList.remove('open');
  updateUI();
}

// ------ OPTIONS CHEF ------

// Avatar d'organisation (17 aout 2026) : orga.avatar reste LA seule propriete d'avatar
// (deja existante avant ce lot, deja affichee dans "Mes organisations" -- aucune deuxieme
// propriete creee). URL saisie a la main ET fichier importe aboutissent tous les deux a une
// simple URL ecrite dans ce meme champ -- mutuellement exclusifs dans ce formulaire (choisir un
// fichier vide le champ URL et inversement), jamais deux avatars distincts.
let _orgaAvatarFileTemp = null;

function renderApercuAvatarOrgaHtml(nom, icone) {
  return typeof getAvatarHtmlPost === 'function' ? getAvatarHtmlPost(true, icone || null, nom, 56) : '';
}

function mettreAJourApercuAvatarOrga(nom, type) {
  _orgaAvatarFileTemp = null;
  const valeur = document.getElementById('orga-avatar-input')?.value?.trim() || '';
  const icone = valeur || (TYPES_ORGANISATIONS[type]?.icon) || null;
  const zone = document.getElementById('orga-avatar-preview');
  if (zone) zone.innerHTML = renderApercuAvatarOrgaHtml(nom, icone);
}

function handleOrgaAvatarFileChange(event) {
  const f = event.target.files[0];
  if (!f) return;
  const okTypes = ['image/png', 'image/jpeg', 'image/webp'];
  if (!okTypes.includes(f.type)) {
    showToast('Format non supporté', 'PNG, JPG/JPEG ou WEBP uniquement.', false);
    event.target.value = '';
    return;
  }
  if (f.size > 2 * 1024 * 1024) {
    showToast('Fichier trop volumineux', 'Taille maximale : 2 Mo.', false);
    event.target.value = '';
    return;
  }
  _orgaAvatarFileTemp = f;
  const avatarInput = document.getElementById('orga-avatar-input');
  if (avatarInput) avatarInput.value = '';
  const zone = document.getElementById('orga-avatar-preview');
  if (zone) {
    const url = URL.createObjectURL(f);
    zone.innerHTML = '<div style="width:56px;height:56px;border-radius:50%;overflow:hidden;border:1px solid #C9A84C;flex-shrink:0"><img src="' + url + '" style="width:100%;height:100%;object-fit:cover"/></div>';
  }
}

function ouvrirOptionsOrga(orgaId) {
  const orga = getOrgaById(orgaId);
  if (!orga || orga.chef !== state.char?.name) return;
  _orgaAvatarFileTemp = null;
  const nomEchap = escapeHtmlText(orga.nom);
  const icone = orga.avatar || (TYPES_ORGANISATIONS[orga.type]?.icon) || null;

  document.getElementById('postes-modal-title').textContent = 'Parametres — ' + orga.nom;
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +

    '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.3rem">NOM</div>' +
    '<input id="orga-rename-input" type="text" maxlength="40" value="' + nomEchap + '" style="width:100%;padding:.4rem .6rem;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;font-family:Crimson Pro,serif;font-size:.9rem;box-sizing:border-box;margin-bottom:.5rem"/>' +

    '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.3rem">DEVISE</div>' +
    '<input id="orga-devise-input" type="text" maxlength="80" placeholder="Ex: La force dans l\'union..." value="' + escapeHtmlText(orga.devise||'') + '" style="width:100%;padding:.4rem .6rem;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;font-family:Crimson Pro,serif;font-size:.9rem;box-sizing:border-box;margin-bottom:.5rem"/>' +

    '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.3rem">AVATAR DE L\'ORGANISATION</div>' +
    '<div style="display:flex;align-items:center;gap:.7rem;margin-bottom:.5rem">' +
      '<div id="orga-avatar-preview">' + renderApercuAvatarOrgaHtml(orga.nom, icone) + '</div>' +
      '<div style="font-size:.68rem;color:#8a8060;flex:1">Aperçu — mis à jour à chaque changement, avant sauvegarde.</div>' +
    '</div>' +
    '<div style="font-size:.72rem;color:#8a6a20;margin-bottom:.2rem">URL de l\'image</div>' +
    '<input id="orga-avatar-input" type="text" maxlength="300" placeholder="https://..." value="' + escapeHtmlText(orga.avatar||'') + '" oninput="mettreAJourApercuAvatarOrga(\'' + nomEchap.replace(/'/g,"\\'") + '\',\'' + orga.type + '\')" style="width:100%;padding:.4rem .6rem;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;font-family:Crimson Pro,serif;font-size:.85rem;box-sizing:border-box;margin-bottom:.4rem"/>' +
    '<div style="font-size:.7rem;color:#6a5a30;margin-bottom:.2rem">— ou —</div>' +
    '<label style="display:inline-block;font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.06em;padding:.35rem .7rem;border:1px solid #3a2a10;background:transparent;color:#8a8060;cursor:pointer;margin-bottom:.3rem">' +
      '<i class="ti ti-upload"></i> Importer une image depuis mon ordinateur' +
      '<input type="file" accept="image/png,image/jpeg,image/webp" onchange="handleOrgaAvatarFileChange(event)" style="display:none"/>' +
    '</label>' +
    '<div style="font-size:.65rem;color:#6a5a30;margin-bottom:.6rem">PNG (transparence supportée), JPG/JPEG ou WEBP — 2 Mo maximum.</div>' +

    '<button onclick="sauvegarderOptionsOrga(\'' + orgaId + '\')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.4rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer;margin-bottom:.8rem">Sauvegarder</button>' +

    // Bascule de visibilite reservee au type "criminelle" (Organisation Secrete) : les 6 autres
    // types restent toujours publics dans ce game design (26 aout 2026), aucune bascule proposee.
    (orga.type === 'criminelle' ?
      '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.3rem">VISIBILITE</div>' +
      '<button onclick="toggleVisibiliteOrga(\'' + orgaId + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.7rem;padding:.3rem .8rem;border:1px solid #3a4a5a;background:transparent;color:#6a8aaa;cursor:pointer;margin-bottom:.8rem">' + (orga.visible ? '👁 Rendre secrete' : '👁 Rendre visible') + '</button>'
    : '') +

    '<div style="margin-top:.4rem;border-top:1px solid #1a1208;padding-top:.6rem">' +
    '<button onclick="dissoudreOrga(\'' + orgaId + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.7rem;padding:.3rem .8rem;border:1px solid #5a1a1a;background:transparent;color:#cc4444;cursor:pointer">Dissoudre</button>' +
    '</div></div>';
  document.getElementById('modal-postes').classList.add('open');
}

// Corrige un bug preexistant trouve en auditant ce panneau (17 aout 2026) : le bouton
// "Sauvegarder" appelait deja sauvegarderOptionsOrga(orgaId), mais cette fonction n'a jamais
// existe nulle part dans le depot (verifie : aucune definition, seulement cette reference) --
// Nom/Devise/Avatar n'ont donc jamais pu etre sauvegardes via ce panneau jusqu'ici (Visibilite/
// Dissoudre restent inchanges, deja geres par leurs propres boutons/fonctions independants).
// Controle d'autorisation frais AU MOMENT EXACT de la sauvegarde (meme doctrine que forum/
// mails, sbGetOrganisationParId, jamais confiance au seul state.organisations perime) --
// couvre explicitement la perte de statut de chef entre ouverture du panneau et clic
// Sauvegarder.
//
// Upload de fichier (revu le 17 aout 2026 apres audit securite) : le nettoyage de l'ancien
// avatar uploade n'est plus declenche ici cote client -- sbUploadOrgAvatar() passe desormais
// par api/upload-org-avatar.js, qui determine et supprime lui-meme l'ancien fichier (a partir
// de sa PROPRE lecture fraiche de l'organisation, jamais d'une valeur fournie par le client) de
// facon atomique avec l'upload. Le client n'a plus aucun droit d'ecriture/suppression direct
// sur le bucket Storage.
async function sauvegarderOptionsOrga(orgaId) {
  const orga = getOrgaById(orgaId);
  if (!orga) return;

  const orgaFraiche = typeof sbGetOrganisationParId === 'function' ? await sbGetOrganisationParId(orgaId).catch(() => null) : null;
  if (!orgaFraiche || orgaFraiche.chef !== state.char?.name) {
    showToast('Action refusée', "Vous n'êtes plus habilité à modifier cette organisation.", false);
    return;
  }

  const newNom = document.getElementById('orga-rename-input')?.value?.trim();
  const newDevise = document.getElementById('orga-devise-input')?.value?.trim() || '';
  const urlSaisie = document.getElementById('orga-avatar-input')?.value?.trim() || '';

  let nouvelAvatar = urlSaisie;
  if (_orgaAvatarFileTemp) {
    if (typeof sbUploadOrgAvatar !== 'function') {
      showToast('Import indisponible', "L'import de fichier n'est pas disponible pour le moment.", false);
      return;
    }
    const urlUploadee = await sbUploadOrgAvatar(orgaId, _orgaAvatarFileTemp);
    if (!urlUploadee) {
      showToast("Échec de l'import", "L'image n'a pas pu être envoyée. Réessayez ou utilisez une URL.", false);
      return;
    }
    nouvelAvatar = urlUploadee;
  }

  const params={devise:newDevise,avatar:nouvelAvatar};
  if(newNom&&newNom.length>=2)params.nom=newNom;
  const serveur=await organisationEssayerCommande(orgaId,'informations',params);
  if(serveur===false)return;
  if(serveur===null){Object.assign(orga,params);sauvegarderOrga(orga);}

  _orgaAvatarFileTemp = null;
  showToast('Paramètres enregistrés', '"' + getOrgaById(orgaId).nom + '"', true);
  document.getElementById('modal-postes').classList.remove('open');
  switchSelfTab('orgas', null);
}

async function renommerOrga(orgaId) {
  const orga = getOrgaById(orgaId);
  if (!orga) return;
  const newNom = document.getElementById('orga-rename-input')?.value?.trim();
  if (!newNom || newNom.length < 2) return;
  const serveur=await organisationEssayerCommande(orgaId,'informations',{nom:newNom});
  if(serveur===false)return;
  if(serveur===null){orga.nom=newNom;sauvegarderOrga(orga);}
  showToast('Organisation renommée', '"' + newNom + '"', true);
  document.getElementById('modal-postes').classList.remove('open');
  switchSelfTab('orgas', null);
}

async function toggleVisibiliteOrga(orgaId) {
  const orga = getOrgaById(orgaId);
  if (!orga || orga.chef !== state.char?.name) return;
  // Reserve au type "criminelle" (Organisation Secrete) -- les 6 autres types restent toujours
  // publics dans ce game design, jamais de bascule vers secret pour eux (26 aout 2026).
  if (orga.type !== 'criminelle') return;
  const visible=!orga.visible;
  const serveur=await organisationEssayerCommande(orgaId,'visibilite',{visible});
  if(serveur===false)return;
  if(serveur===null){orga.visible=visible;sauvegarderOrga(orga);}
  showToast(visible ? 'Organisation visible' : 'Organisation secrète', '', true);
  document.getElementById('modal-postes').classList.remove('open');
}

const dissolutionsOrganisationsEnCours = new Set();
async function dissoudreOrga(orgaId) {
  const orga = getOrgaById(orgaId);
  if (!orga || dissolutionsOrganisationsEnCours.has(orgaId)) return;
  if (orga.chef!==state.char?.name) {showToast('Accès refusé','Seule la direction peut dissoudre cette organisation.',false);return;}
  const contexte=equipementsCollectifsContexte();
  dissolutionsOrganisationsEnCours.add(orgaId);
  let confirme=false;
  try{confirme=typeof sbDeleteOrganisation==='function'&&await sbDeleteOrganisation(orgaId)===true;}catch(_){}
  finally{dissolutionsOrganisationsEnCours.delete(orgaId);}
  if(!equipementsCollectifsContexteValide(contexte))return;
  if(!confirme){showToast('Dissolution non confirmée','Actualisez la liste avant de recommencer. Le matériel de l’organisation doit être préservé.',false);return;}
  // Historisation APRES suppression confirmee (chronique_nationale) -- uniquement si l'organisation etait
  // publique : une organisation criminelle/secrete dissoute ne doit jamais laisser de trace
  // publique de son existence passee.
  if (orga.visible && typeof sbEnregistrerEvenementPublic === 'function') {
    sbEnregistrerEvenementPublic(orga.country, 'organisation_dissolution', {
      personnages: [orga.chef].filter(Boolean),
      libelle: '"' + orga.nom + '" a été dissoute.',
      data: { orga_id: orga.id, type: orga.type, nom: orga.nom, chef: orga.chef },
      sourceRef: orga.id
    }).catch(() => {});
  }
  state.organisations = (state.organisations || []).filter(o => o.id !== orgaId);
  document.getElementById('modal-postes').classList.remove('open');
  showToast('Organisation dissoute', '"' + orga.nom + '" n\'existe plus.', false);
  addJournalEntry('"' + orga.nom + '" dissoute.', 'event-bad');
  switchSelfTab('orgas', null);
}

async function quitterOrga(orgaId) {
  const orga = getOrgaById(orgaId);
  if (!orga) return;
  if (orga.chef === state.char?.name) { showToast('Impossible', 'Dissolvez l\'organisation ou transmettez la direction avant de partir.', false); return; }
  const serveur=await organisationEssayerCommande(orgaId,'quitter',{nom:state.char.name});
  if(serveur===false)return;
  if(serveur===null){orga.membres=orga.membres.filter(m=>m.nom!==state.char.name);sauvegarderOrga(orga);}
  showToast('Vous avez quitté', '"' + orga.nom + '"', false);
  addJournalEntry('Départ de "' + orga.nom + '".', '');
  switchSelfTab('orgas', null);
}

function titreChefOrga(type) {
  const titres = { sportive: 'Président du club sportif', supporters: 'Président du club des supporters', syndicale: 'Secrétaire général', mediatique: 'Directeur de Publication' };
  return titres[type] || 'Président';
}

// Correctif du 17 aout 2026 (envoi de mail au nom d'une organisation) : n'expose plus le nom
// reel du chef dans l'expediteur (mailFromOverride prefixait auparavant "NomDuChef, Titre",
// visible du destinataire -- viole la doctrine du forum ou seuls le nom et l'icone de l'
// organisation sont publics) et ne se fiait plus a un controle fait une seule fois a l'
// ouverture. Preselectionne desormais simplement l'organisation dans le meme selecteur "Envoyer
// en tant que" que le compositeur standard (renderEnvoyerMailEnTantQue, forum.js) -- la
// verification fraiche du chef a lieu au moment exact de l'envoi (resoudreIdentitePublication,
// appelee par sendMail), pas ici. Ce controle prealable reste une simple economie de clic
// (eviter d'ouvrir le compositeur pour rien si le joueur n'est deja plus chef), pas la barriere
// de securite reelle.
function ouvrirMailOrga(orgaId) {
  const orga = getOrgaById(orgaId);
  if (!orga) return;
  const estChef = orga.chef === state.char?.name;
  if (!estChef) {
    showToast('Réservé au président', 'Seul le/la ' + titreChefOrga(orga.type).toLowerCase() + ' peut envoyer du courrier officiel au nom de "' + orga.nom + '".', false);
    return;
  }
  document.getElementById('modal-postes')?.classList.remove('open');
  document.getElementById('vue-self')?.classList.remove('active');
  mailView = 'compose';
  openForumView('local');
  document.getElementById('forum-main').innerHTML = renderMailCompose('', '', orgaId);
}

function ouvrirForumDepuisOrga(orgaId) {
  const orga = getOrgaById(orgaId);
  const mapping = { sportive: 'sport', supporters: 'sport', syndicale: 'syndicats', mediatique: 'presse' };
  // Repli sur le Local de la ville courante pour une organisation sans forum dedie.
  const forumCible = mapping[orga?.type] || ((typeof idForumLocal === 'function') ? idForumLocal() : 'local');
  document.getElementById('modal-postes')?.classList.remove('open');
  document.getElementById('vue-self')?.classList.remove('active');
  openForumView(forumCible);
}


// =====================
// CHAMPIONNAT SPORTIF
// =====================

// =====================
// CALENDRIER REEL DU CHAMPIONNAT — ANCRAGE DIMANCHE 20H EUROPE/PARIS
// (chantier "calendrier dimanche 20h", 1er septembre 2026)
// =====================
// Audit prealable (rapport separe) : l'ancien systeme derivait CHAQUE journee de
// saison.dateDebut (horodatage reel de creation de la saison, jamais garanti tomber un dimanche)
// + (numero-1)*7 jours, avec l'heure fixee via Date.setHours(20,...) -- une methode LOCALE AU
// NAVIGATEUR qui l'execute, jamais un fuseau horaire fixe. Resultat reel observe : la J1 de la
// saison en cours a ete jouee un mardi (dateDebut = 2026-09-01T18:34:15Z, un mardi).
//
// Ce bloc centralise TOUT le calcul temporel lie au calendrier reel dans une seule fonction
// (prochainDimanche20hParis), comme demande -- aucun autre endroit du fichier ne doit plus
// calculer une heure de coup d'envoi a la main. Fuseau horaire de reference : Europe/Paris,
// via Intl.DateTimeFormat avec timeZone explicite -- JAMAIS Date.getHours()/setHours() (qui
// lisent/ecrivent l'heure locale de la machine qui execute le code, differente pour chaque
// joueur). Gere nativement l'alternance heure d'ete/hiver (CEST/CET) : "20h heure de Paris"
// reste 20h heure de Paris toute l'annee, jamais un decalage UTC fixe.
function decomposerDateTimezone(date, timeZone) {
  const fmt = new Intl.DateTimeFormat('en-US', {
    timeZone, year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false
  });
  const parts = fmt.formatToParts(date).reduce((acc, p) => { acc[p.type] = p.value; return acc; }, {});
  // "24" ne doit jamais fuiter en heure locale (minuit) -- normalise en 0, cas documente de
  // hour12:false dans certains moteurs (heure "24:00" au lieu de "00:00").
  const heure = parts.hour === '24' ? 0 : parseInt(parts.hour, 10);
  return { annee: +parts.year, mois: +parts.month, jour: +parts.day, heure, minute: +parts.minute, seconde: +parts.second };
}

// Convertit une date/heure "murale" (annee/mois/jour/heure/minute) EXPRIMEE dans timeZone en
// l'instant UTC absolu correspondant. Principe standard (une seule iteration suffit : aucune
// des heures de coup d'envoi utilisees ici, 20h, ne tombe jamais dans l'heure ambigue/inexistante
// du changement d'heure, qui se produit toujours autour de 2h-3h du matin) : on devine un instant
// UTC candidat avec les memes chiffres, on relit quelle heure ca donne reellement dans timeZone,
// et on corrige l'ecart constate.
function heureMuraleVersInstantUTC(annee, mois, jour, heure, minute, timeZone) {
  const candidatUTC = Date.UTC(annee, mois - 1, jour, heure, minute, 0);
  const lu = decomposerDateTimezone(new Date(candidatUTC), timeZone);
  const luCommeUTC = Date.UTC(lu.annee, lu.mois - 1, lu.jour, lu.heure, lu.minute, lu.seconde);
  const ecartMs = luCommeUTC - candidatUTC;
  return new Date(candidatUTC - ecartMs);
}

// Fonction UNIQUE et centrale : le prochain dimanche 20h00 Europe/Paris a partir de `depuis`
// (un instant reel quelconque, independant du fuseau horaire du navigateur qui appelle cette
// fonction -- deux joueurs dans des fuseaux differents obtiennent le MEME instant absolu).
// Regle validee (section 2 du chantier) : si `depuis` tombe deja un dimanche AVANT 20h heure de
// Paris, la meme journee (ce dimanche) est retenue ; a partir de 20h00 pile ce dimanche-la, ou
// n'importe quel autre jour de la semaine, c'est le dimanche SUIVANT qui est retenu.
function prochainDimanche20hParis(depuis) {
  const d = decomposerDateTimezone(depuis, 'Europe/Paris');
  // Jour de la semaine du dimanche calendaire "d" (0=dimanche...6=samedi) -- calcule sur un simple
  // triplet annee/mois/jour via UTC, sans aucune notion d'heure/fuseau (getUTCDay() d'un minuit
  // UTC reconstruit a partir d'un triplet calendaire donne toujours le bon jour de semaine civil,
  // quel que soit le fuseau d'origine du triplet).
  const jourSemaine = new Date(Date.UTC(d.annee, d.mois - 1, d.jour)).getUTCDay();
  let joursAAjouter;
  if (jourSemaine === 0) {
    joursAAjouter = (d.heure < 20) ? 0 : 7;
  } else {
    joursAAjouter = 7 - jourSemaine;
  }
  // Date.UTC normalise automatiquement un jour hors bornes du mois (ex. jour 33 -> mois suivant) :
  // pas besoin de gerer manuellement les fins de mois ici.
  return heureMuraleVersInstantUTC(d.annee, d.mois, d.jour + joursAAjouter, 20, 0, 'Europe/Par…108925 tokens truncated…ubLocal.nom + ' sera boycotté par ses supporters.', true, true);
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

// Correctif du 25 aout 2026 (bug production v78) : utilisait getClubLocal() -- le club de la
// VILLE VISITEE -- pour le titre ET pour calculerClassementClub, au lieu du club REEL du joueur
// (licenceSportive.clubId). Un PJ licencie a Luthecia consultant "Mon niveau sportif" en visite a
// PSM voyait donc le titre/classement de La Brise Mariannaise. Accessible depuis la fiche
// personnage (plateau-personnage.js, bouton "Mon niveau sportif"), donc potentiellement DEPUIS
// N'IMPORTE QUELLE ville -- l'appartenance sportive doit toujours venir de la licence, jamais de
// la localisation. calculerClassementClub interroge deja sbListJoueursLicencies filtre par
// licence_sportive.clubId reel (supabase.js) : seul l'appel ICI passait le mauvais club en
// entree ; un joueur licencie ailleurs n'a donc jamais pu apparaitre dans l'effectif/classement
// d'un club qui n'est pas le sien -- cette partie etait deja correcte.
async function doVoirMonClassement() {
  const lic = state.char?.licenceSportive;
  const statutActuel = statutLicenceSportive();
  const monClub = statutActuel === 'active' || statutActuel === 'impaye' ? getClub(lic.clubId) : null;
  if (!monClub) {
    showToast('Indisponible', 'Vous devez avoir une licence sportive dans un club.', false);
    return;
  }
  document.getElementById('postes-modal-title').textContent = 'Mon niveau — ' + monClub.nom;
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const classement = await calculerClassementClub(monClub);
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

async function doConsulterClassementBookmaker(pa, cost) {
  const clubLocal = getClubLocal();
  if (!clubLocal) { showToast('Indisponible', 'Aucun club local ici.', false); return; }
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('Fonds insuffisants', '', false); return; }
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
// LECTURE SEULE DEPUIS LE 20 SEPTEMBRE 2026 (§6.3). Cette fonction CREAIT la ligne quand elle
// n'existait pas -- une ecriture a la simple consultation. La table est desormais fermee en
// ecriture aux clients : la ligne est creee par le serveur, au depot de la premiere candidature.
// Une absence de ligne n'est pas une anomalie, c'est un club sans president.
async function chargerPresidentClub(clubId) {
  if (typeof sbGetPresidentClub !== 'function') return null;
  const data = await sbGetPresidentClub(clubId).catch(() => null);
  return data || { president: null, dateElection: null, candidature: null };
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

  // Deduction PA centralisee -- deduireCoutOrdre() est l'AUTORITE UNIQUE sur la disponibilite
  // des PA (plus de garde manuelle state.pa<1, qui bloquait a tort meme sous TEST_MODE=true).
  // Appelee avant sbCreerDemandeManifestation (mutation Supabase) : fail-closed.
  const rPa = await deduireCoutOrdre({ pa: 1, cost: 0 });
  if (!rPa.ok) { showToast('PA insuffisants', '1 PA requis.', false); return; }
  updateUI();

  const nbMembres = orga.membres?.length || 1;
  const intensite = Math.min(3, 1 + Math.floor(nbMembres / 10));
  const maireInfo = orga.type === 'supporters' ? await getTitulaireActuel('maire', state.currentCity) : null;
  const cible = maireInfo?.estPJ ? maireInfo.nom : null;

  await sbCreerDemandeManifestation({
    orgaId, orgaNom: orga.nom, orgaType: orga.type,
    pays: state.country, ville: state.currentCity,
    sujet, sens, intensite, cible,
    dateEvenement: dateEvenement.toISOString(),
    dateDepot: maintenant.toISOString()
  });

  document.getElementById('modal-postes')?.classList.remove('open');
  const minIntInfo = await getTitulaireActuel('min_int');
  const minIntNom = minIntInfo?.estPJ ? minIntInfo.nom : null;
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
  const maireInfo = await getTitulaireActuel('maire', club.city, club.country);
  return {
    chefSupporters: supporters?.chef || null,
    maire: maireInfo?.estPJ ? maireInfo.nom : null,
    capitaine
  };
}

async function doPostulerPresidentClub(pa, cost) {
  const clubLocal = getClubLocal();
  if (!clubLocal) { showToast('Indisponible', '', false); return; }
  const data = await chargerPresidentClub(clubLocal.id);

  if (data.candidature) { showToast('Candidature en cours', 'Une candidature est déjà en cours de vote.', false); return; }
  if (data.president && data.president !== state.char?.name) {
    const jour = state.day || 1;
    const saison = await chargerOuInitialiserSaison();
    const midSaison = (saison?.dateDebut ? joursEcoulesDepuis(saison.dateDebut) : 0) ;
    if (data.dateElection && (jour - data.dateElection) < 8) { // ~mi-saison (saison=11 journees, protection ~ 5-6 sem)
      showToast('Poste protégé', 'Le président en poste ne peut pas être remis en question avant la mi-saison.', false);
      return;
    }
  }

  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }

  // LE SERVEUR RESOUT LES TROIS ELECTEURS (§6.3, 20 septembre 2026).
  //
  // CE QUI SE PASSAIT. La candidature embarquait un instantane des electeurs ECRIT PAR LE
  // PROPOSANT, puis la ligne etait ecrite en direct. Comme le silence vaut accord, y inscrire
  // trois noms quelconques -- ou trois complices -- suffisait a etre elu sans qu'aucun ne vote.
  // Desormais le client ne transmet plus aucune identite : il donne le club, rien d'autre.
  // Les regles sont inchangees (candidature unique, protection de 8 jours, scrutin de 2 jours).
  const rPost = await sbRpc('club_president_postuler', { p_club: clubLocal.id })
    .then(function (rows) { return Array.isArray(rows) ? rows[0] : rows; })
    .catch(function () { return null; });
  if (!rPost || rPost.ok !== true) {
    const motifs = {
      candidature_en_cours: 'Une candidature est déjà en cours de vote.',
      poste_protege:        'Le président en poste ne peut pas être remis en question avant la mi-saison.',
      club_inconnu:         'Club introuvable.'
    };
    showToast('Candidature refusée', motifs[rPost && rPost.raison] || 'Le serveur a refusé la candidature.', false);
    return;
  }

  const electeurs = rPost.electeurs || {};
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
  // Le serveur verifie que l'appelant est bien l'un des trois electeurs DE SON PROPRE
  // instantane, et qu'il n'a pas deja vote. Le client ne transmet que son bulletin.
  const rVote = await sbRpc('club_president_voter', { p_club: clubId, p_vote: !!vote })
    .then(function (rows) { return Array.isArray(rows) ? rows[0] : rows; })
    .catch(function () { return null; });
  document.getElementById('modal-postes')?.classList.remove('open');
  if (!rVote || rVote.ok !== true) {
    const motifs = {
      non_electeur:       'Vous ne faites pas partie des trois électeurs.',
      deja_vote:          'Vous avez déjà voté sur cette candidature.',
      aucune_candidature: 'Aucune candidature en cours.'
    };
    showToast('Vote refusé', motifs[rVote && rVote.raison] || 'Le serveur a refusé ce vote.', false);
    return;
  }
  showToast('Vote enregistré', '', true, true);
  await verifierElectionPresident(getClub(clubId));
}

// LE DEPOUILLEMENT EST FAIT PAR LE SERVEUR (§6.3, 20 septembre 2026).
//
// Les regles sont celles d'avant, a la ligne pres : on ne depouille que si les trois ont vote
// OU si l'echeance est atteinte ; les votes manquants comptent pour « oui » (silence = accord) ;
// il faut 2 voix sur 3. Ce qui change, c'est que le comptage ne se fait plus dans le navigateur
// a partir d'un instantane d'electeurs que le navigateur avait lui-meme ecrit.
//
// Appelable par n'importe qui sans risque : la RPC refuse tant que le scrutin est en cours, et
// ne fait rien d'autre que ce que les bulletins disent. C'est ce qui permet de la declencher a
// l'ouverture du bureau, comme avant.
async function verifierElectionPresident(club) {
  if (!club || typeof sbRpc !== 'function') return;
  const r = await sbRpc('club_president_cloturer', { p_club: club.id })
    .then(function (rows) { return Array.isArray(rows) ? rows[0] : rows; })
    .catch(function () { return null; });
  if (!r || r.ok !== true) return;   // scrutin en cours ou aucune candidature : rien a annoncer

  if (r.elu) {
    addExternalEvent('🏛 ' + r.candidat + ' est élu(e) président(e) de "' + club.nom + '".');
  } else {
    addExternalEvent('🏛 La candidature de ' + r.candidat + ' à la présidence de "' + club.nom + '" a été rejetée.');
  }
}

// =====================
// TRANSFERTS ENTRE CLUBS
// =====================
async function doProposerTransfert(pa, cost) {
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
  html += '<button onclick="confirmerPropositionTransfert(\'' + clubLocal.id + '\',' + pa + ',' + cost + ')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.55rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Envoyer l\'offre</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerPropositionTransfert(clubAchatId, pa, cost) {
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
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }

  // L'OFFRE EST LA CONTREPARTIE DES PA, ET SON IDENTIFIANT N'ETAIT JAMAIS RELU
  // (chantier 5, 9 octobre 2026).
  //
  // `sbCreerTransfert` rend `null` quand l'INSERT n'aboutit pas -- c'est le correctif du
  // 7 octobre sur les douze fonctions qui fabriquaient un identifiant credible pour une ligne
  // inexistante. Ici, `transfertId` etait affecte et plus jamais lu : les PA et le cout etaient
  // deja preleves, le courrier partait au president du club vendeur en lui annoncant une offre
  // chiffree, et le toast disait « Le président a été notifié » -- pour une offre qui n'existait
  // dans aucune table. Le president invite a repondre ne trouvait rien a repondre.
  //
  // Les PA ne sont pas rembourses, et ce n'est pas un oubli : `deduireCoutOrdre` est le point
  // d'execution irreversible de l'ordre, par doctrine du projet. On cesse simplement d'annoncer
  // une offre qui n'a pas ete enregistree.
  const transfertId = await sbCreerTransfert({
    joueur: nomJoueur, clubDepartId: clubVenteId, clubArriveeId: clubAchatId,
    prixClub: prix, statut: 'propose', proposePar: state.char?.name
  }).catch(() => null);
  if (!transfertId) {
    document.getElementById('modal-postes')?.classList.remove('open');
    console.error('doProposerTransfert : offre pour ' + nomJoueur + ' a ' + prix
                  + ' FR NON enregistree, les PA sont pourtant engages');
    showToast('Offre non enregistrée',
      'L\'offre pour ' + nomJoueur + ' n\'a pas pu être enregistrée. Le président de '
      + clubVente.nom + ' n\'a pas été notifié, et les PA restent engagés.', false);
    addJournalEntry('Offre de transfert pour ' + nomJoueur + ' NON enregistrée.', 'event-bad');
    return;
  }

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

  // Le joueur accepte : licence basculee, points d'entrainement conserves, argent reparti.
  // nonRenouvellement repart a false par construction (nouvel objet) -- un transfert accepte
  // annule donc automatiquement toute demande de non-renouvellement en cours (§3 : le joueur
  // vient explicitement d'accepter de poursuivre sa carriere, dans son nouveau club).
  // derniereSaisonTraitee aligne la nouvelle licence sur la saison en cours, comme une prise
  // normale (doPrendreLicenceSportive) -- evite qu'elle soit vue comme "a renouveler" avant la
  // VRAIE prochaine saison.
  if (state.char?.name === t.joueur) {
    const saison = await chargerOuInitialiserSaison();
    state.char.licenceSportive = { clubId: t.clubArriveeId, dateAchat: state.day || 1, statut: 'active', derniereSaisonTraitee: saison?.numero || 1, nonRenouvellement: false };
    crediterFondsOrdinaires(t.prixJoueur || 0);
    updateUI();
  }
  await crediterBudgetClub(t.clubDepartId, t.prixClub, 'Transfert de ' + t.joueur);
  await crediterBudgetClub(t.clubArriveeId, -(t.prixClub), 'Transfert de ' + t.joueur);
  t.statut = 'termine';
  await sbMajTransfert(transfertId, t);
  showToast('Transfert accepté !', 'Vous jouez désormais pour ' + getClub(t.clubArriveeId).nom + '.', true, true);
  addJournalEntry('Transfert accepté vers ' + getClub(t.clubArriveeId).nom + '.', 'event-good');
  // Meme correctif que doPrendreLicenceSportive/doDemanderNonRenouvellementLicence : rafraichit
  // les ordres de la piece courante (le joueur peut avoir accepte ce transfert depuis n'importe
  // ou, y compris depuis le stade d'un club) pour que "Prendre sa licence sportive" (et les
  // autres ordres dependants de licenceSportive) reflete immediatement le nouveau club.
  if (state.char?.name === t.joueur && state.currentRoom) enterRoom(state.currentBuilding, state.currentRoom, null);
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

function doChoisirAccessoireClub(pa, cost) {
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
    html += '<button onclick="confirmerAchatAccessoireClub(\'' + a.id + '\',\'' + a.label + '\',' + a.prix + ',' + pa + ',' + cost + ')" style="display:flex;align-items:center;gap:.7rem;padding:.6rem .8rem;border:1px solid #2a2010;background:transparent;color:#c0b090;cursor:pointer;font-size:.8rem;text-align:left">';
    html += img
      ? '<img src="' + img + '" style="width:56px;height:56px;object-fit:cover;border:1px solid #2a2010;flex-shrink:0"/>'
      : '<i class="ti ' + a.icon + '" style="font-size:1.4rem;color:#8a6a20;width:56px;text-align:center;flex-shrink:0"></i>';
    html += '<span style="flex:1">' + a.label + '</span><span style="color:#C9A84C">' + a.prix + ' FR</span></button>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerAchatAccessoireClub(id, label, prix, pa, cost) {
  const clubLocal = getClubLocal();
  document.getElementById('modal-postes').classList.remove('open');
  if (getFondsDisponiblesOrdinaires() < prix) { showToast('Fonds insuffisants', prix + ' FR requis.', false); return; }
  // Vente legale : regle generale des interdictions (arbitrage du 11 septembre 2026), avant tout debit.
  if (typeof assembleeControlerVenteLegale === 'function'
      && !(await assembleeControlerVenteLegale([{ type: 'accessoire_sport' }]))) return;
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }
  const debitAccessoire = await debiterFondsOrdinaires(prix);
  if (!debitAccessoire.ok) { showToast('Fonds insuffisants', prix + ' FR requis.', false); return; }
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

// Reutilise calculerKickoffJournee (source canonique unique de l'heure des matchs, deja utilisee
// par le moteur live) -- jamais une deuxieme source d'heure recalculee independamment (section 14).
function formatDateJournee(saison, numero) {
  const kickoff = calculerKickoffJournee(saison, numero);
  if (!kickoff) return 'date à confirmer'; // C5 : jamais une date fabriquee en heure locale
  // Affichage explicitement rendu dans le fuseau canonique : deux joueurs dans deux fuseaux
  // differents lisent la meme heure officielle de coup d'envoi (20h00), et non leur heure locale.
  return kickoff.toLocaleDateString('fr-FR', { timeZone: 'Europe/Paris', day: '2-digit', month: '2-digit', year: 'numeric' }) +
    ' à ' + kickoff.toLocaleTimeString('fr-FR', { timeZone: 'Europe/Paris', hour: '2-digit', minute: '2-digit' }) + ' (Paris)';
}

async function doObserverMatch() {
  document.getElementById('postes-modal-title').textContent = 'Championnat — Résultats & Calendrier';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  let saison = await verifierEtJouerJournees();
  if (!saison) {
    document.getElementById('postes-body').innerHTML =
      '<div style="padding:1.5rem;text-align:center;color:#8a8060;font-style:italic">Championnat momentanément indisponible (connexion). Réessayez dans un instant.</div>';
    return;
  }
  const clubLocal = getClubLocal();

  let html = '<div style="padding:1rem">';

  if (saison.phase === 'terminee' && saison.resultatsFinales) {
    const rf = saison.resultatsFinales;
    html += '<div style="text-align:center;padding:.8rem;border:1px solid #C9A84C;margin-bottom:1rem">';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:1rem;letter-spacing:.1em;color:#C9A84C">🏆 ' + getClub(rf.champion).nom + '</div>';
    html += '<div style="font-size:.75rem;color:#8a8060;margin-top:.3rem">Champion de la saison ' + saison.numero + ' — finale au ' + getClub(rf.stadeClubId).nom + '</div>';
    html += '<div style="font-size:.72rem;color:#6a5a30;margin-top:.3rem">' + rf.finale.recit + '</div>';
    html += '</div>';
    // Lot G (5 septembre 2026) : desormais ATTENDU, et concurrent-safe (etat frais + verification
    // phase==='terminee' + CAS, voir demarrerNouvelleSaison). L'appel non-await precedent laissait
    // deux joueurs ouvrant cette modale en meme temps creer deux saisons differentes, la seconde
    // ecrasant la premiere.
    await demarrerNouvelleSaison(saison);
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
  if (!saison) {
    document.getElementById('postes-body').innerHTML =
      '<div style="padding:1.5rem;text-align:center;color:#8a8060;font-style:italic">Palmarès momentanément indisponible (connexion). Réessayez dans un instant.</div>';
    return;
  }
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

async function doParierMatch(pa, cost) {
  const saison = await verifierEtJouerJournees();
  if (!saison) { showToast('Paris indisponibles', 'Impossible de lire le championnat pour le moment. Réessayez dans un instant.', false); return; }

  const prochaineJournee = saison.calendrier.find(j => j.matchs.some(m => !m.played));
  if (!prochaineJournee) { showToast('Aucun pari disponible', 'Plus aucun match à venir cette saison.', false); return; }

  document.getElementById('postes-modal-title').textContent = 'Parier — Journée ' + prochaineJournee.numero;
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;margin-bottom:.6rem">Choisissez un match</div>';
  prochaineJournee.matchs.filter(m => !m.played).forEach(m => {
    html += '<button onclick="ouvrirFormulairePari(\'' + m.home + '\',\'' + m.away + '\',' + prochaineJournee.numero + ',' + saison.numero + ',' + pa + ',' + cost + ')" style="width:100%;text-align:left;margin-bottom:.4rem;padding:.55rem .7rem;border:1px solid #2a2010;background:transparent;color:#c0b090;cursor:pointer;font-size:.8rem">' + getClub(m.home).nom + ' vs ' + getClub(m.away).nom + '</button>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function ouvrirFormulairePari(homeId, awayId, journeeNumero, saisonNumero, pa, cost) {
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
  html += '<button onclick="confirmerPariMatch(\'' + homeId + '\',\'' + awayId + '\',' + journeeNumero + ',' + saisonNumero + ',' + pa + ',' + cost + ')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.55rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Valider le pari</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerPariMatch(homeId, awayId, journeeNumero, saisonNumero, pa, cost) {
  const mise = parseInt(document.getElementById('pari-mise')?.value || '0');
  const choix = document.getElementById('pari-choix')?.value || 'domicile';
  if (!mise || mise < 10) { showToast('Mise invalide', 'Minimum 10 FR.', false); return; }
  if (state.arg < mise) { showToast('Fonds insuffisants', '', false); return; }
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }

  document.getElementById('modal-postes')?.classList.remove('open');

  // L'ENGAGEMENT DU PARI PASSE PAR LE SERVEUR (§6.3, 20 septembre 2026).
  //
  // CE QUI SE PASSAIT. La ligne etait inseree directement dans paris_sportifs, et la mise
  // seulement retranchee de state.arg. Comme la table etait ouverte en ecriture a tout joueur
  // connecte, il suffisait d'inserer APRES le coup de sifflet un pari portant le bon pronostic
  // et la mise de son choix : football_paris_resoudre, elle, faisait son travail et payait.
  // Gain garanti, mise jamais reellement payee.
  //
  // Desormais : le parieur est l'appelant, la saison est lue par le serveur, le match doit
  // exister ET ne pas etre joue, la mise est REELLEMENT prelevee avant l'inscription, et
  // l'identifiant deterministe interdit un second pari sur la meme rencontre.
  const rPari = await sbRpc('football_pari_engager', {
    p_home: homeId, p_away: awayId, p_journee: journeeNumero, p_choix: choix, p_mise: mise
  }).then(function (rows) { return Array.isArray(rows) ? rows[0] : rows; })
    .catch(function () { return null; });

  if (!rPari || rPari.ok !== true) {
    const motifs = {
      match_deja_joue:    'Ce match est déjà joué.',
      pari_deja_engage:   'Vous avez déjà parié sur cette rencontre.',
      fonds_insuffisants: 'Fonds insuffisants.',
      mise_invalide:      'Mise invalide (minimum 10 FR).',
      match_inconnu:      'Ce match est introuvable au calendrier.',
      journee_inconnue:   'Journée introuvable au calendrier.'
    };
    showToast('Pari refusé', motifs[rPari && rPari.raison] || 'Le serveur a refusé ce pari.', false);
    return;
  }

  // Recopie de l'etat arrete par le serveur, jamais un calcul local.
  if (typeof rPari.arg === 'number') { state.arg = Number(rPari.arg); if (state.char) state.char.arg = state.arg; }
  updateUI();

  const homeClub = getClub(homeId), advClub = getClub(awayId);
  showToast('Pari enregistré', mise + ' FR misés sur ' + homeClub.nom + ' vs ' + advClub.nom + '. Résultat au coup de sifflet final.', true, true);
  addJournalEntry('Pari de ' + mise + ' FR sur ' + homeClub.nom + ' vs ' + advClub.nom + '.', 'event-info');
}

// Resout tous les paris en attente pour une journee qui vient d'etre jouee
// RESOLUTION ET PAIEMENT SONT INDISSOCIABLES (16 septembre 2026).
//
// Le pari etait d'abord marque `resolu = true` -- ecriture qui aboutit -- puis le gagnant etait
// credite par une ecriture directe sur SA fiche, que la vue personnages refuse depuis le
// chantier B. Le pari devenait donc definitivement resolu sans que le gain soit verse, pendant
// qu'un mail « Pari gagne ! » partait, et aucune passe ne le reprenait plus jamais.
//
// football_paris_resoudre retrouve le match dans le championnat, exige qu'il soit joue, lit le
// score persiste, applique les memes cotes, et fait les deux ecritures dans la meme transaction.
// Le client n'annonce plus que ce qui a REELLEMENT eu lieu -- les mails sont envoyes a partir du
// compte rendu du serveur, jamais d'un calcul local.
async function resoudreParisJournee(saisonNumero, journee) {
  if (typeof sbRpc !== 'function') return;
  const rows = await sbRpc('football_paris_resoudre', { p_journee: journee.numero }).catch(() => null);
  const r = Array.isArray(rows) ? rows[0] : rows;
  if (!r || r.ok !== true || !Array.isArray(r.detail) || !r.detail.length) return;

  const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : '';
  for (const pari of r.detail) {
    if (typeof sbSendMail !== 'function') break;
    const msg = pari.gagne
      ? 'Votre pari sur ' + getClub(pari.homeId).nom + ' vs ' + getClub(pari.awayId).nom + ' est gagnant ! +' + Number(pari.gain || 0).toLocaleString('fr-FR') + ' FR.'
      : 'Votre pari sur ' + getClub(pari.homeId).nom + ' vs ' + getClub(pari.awayId).nom + ' est perdant. Mise perdue.';
    await sbSendMail('Ligue Officielle', pari.joueur, pari.gagne ? 'Pari gagné !' : 'Pari perdu', msg, time).catch(() => {});
  }
}

// =====================
// GREVES, GREVE GENERALE ET CONTRE-POUVOIRS (audit valide + implementation, 3 septembre 2026)
// =====================
// Grève ORDINAIRE : vit entièrement dans organisations.data.greve (comme election/caisse, déjà
// inline sur l'organisation) -- aucune nouvelle table. Ciblage calqué sur "Lancer une rumeur"
// (plateau-pnj.js, _rumeur) : PJ/Gouvernement/Entreprise/Organisation/Pays, texte libre pour les
// revendications, aucune résolution automatique (le RP entre joueurs détermine un éventuel
// accord -- seul le chef peut mettre fin à la grève, jamais un vote ni une fin automatique).
let _greve = null;
let _grevePjCache = null;

function ouvrirLancerGreve(orgaId) {
  const orga = getOrgaById(orgaId);
  if (!orga) return;
  if (orga.chef !== state.char?.name) { showToast('Accès refusé', 'Réservé au chef du syndicat.', false); return; }
  if (orga.greve?.actif) { showToast('Grève déjà en cours', 'Ce syndicat est déjà en grève.', false); return; }
  const nbMembres = orga.membres?.length || 0;
  if (nbMembres < GREVE_MEMBRES_MIN) {
    showToast('Syndicat trop petit', 'Au moins ' + GREVE_MEMBRES_MIN + ' membres sont nécessaires (' + nbMembres + ' actuellement).', false);
    return;
  }

  _greve = { orgaId, type: 'pj', cibleValue: null, cibleLabel: null, revendications: '', soumission: false };
  _grevePjCache = null;

  document.getElementById('postes-modal-title').textContent = '✊ Lancer une grève';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +
    '<div style="font-size:.75rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">La grève reste active jusqu\'à ce que vous utilisiez « Mettre fin à la grève ». Aucune résolution automatique : le résultat se négocie entre joueurs.</div>' +
    '<div style="font-family:\'Bebas Neue\',sans-serif;font-size:.7rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.3rem">CIBLE</div>' +
    '<select id="greve-type-select" onchange="changerTypeGreve(this.value)" style="width:100%;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;padding:.4rem;font-family:\'Crimson Pro\',serif;font-size:.85rem;outline:none;margin-bottom:.7rem">' +
      '<option value="pj">PJ</option>' +
      '<option value="gouvernement">Gouvernement</option>' +
      '<option value="entreprise">Entreprise</option>' +
      '<option value="organisation">Organisation</option>' +
      '<option value="pays">Pays</option>' +
    '</select>' +
    '<div id="greve-cible-zone" style="margin-bottom:.5rem"></div>' +
    '<div id="greve-cible-recap" style="font-size:.72rem;color:#9a8a68;font-style:italic;margin-bottom:.8rem">Aucune cible sélectionnée.</div>' +
    '<div style="font-family:\'Bebas Neue\',sans-serif;font-size:.7rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.3rem">REVENDICATIONS</div>' +
    '<textarea id="greve-revendications-input" oninput="majRevendicationsGreve(this.value)" placeholder="Rédigez librement vos revendications..." style="width:100%;min-height:90px;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;padding:.5rem;font-family:\'Crimson Pro\',serif;font-size:.85rem;outline:none;resize:vertical;margin-bottom:.9rem;box-sizing:border-box"></textarea>' +
    '<button id="greve-btn-valider" onclick="validerLancementGreve()" style="width:100%;font-family:\'Bebas Neue\',sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.6rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">Lancer la grève — 1 PA</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');

  changerTypeGreve('pj');
}

function majRevendicationsGreve(val) { if (_greve) _greve.revendications = val; }

function majRecapCibleGreve() {
  const recap = document.getElementById('greve-cible-recap');
  if (!recap || !_greve) return;
  recap.textContent = _greve.cibleLabel ? ('Cible sélectionnée : ' + _greve.cibleLabel) : 'Aucune cible sélectionnée.';
}

async function chargerPjPourGreve() {
  if (_grevePjCache) return _grevePjCache;
  _grevePjCache = (typeof sbListPersonnages === 'function') ? await sbListPersonnages().catch(() => []) : [];
  return _grevePjCache || [];
}

async function changerTypeGreve(nouveauType) {
  if (!_greve) return;
  _greve.type = nouveauType;
  _greve.cibleValue = null;
  _greve.cibleLabel = null;
  majRecapCibleGreve();

  const zone = document.getElementById('greve-cible-zone');
  if (!zone) return;

  if (nouveauType === 'pj') {
    zone.innerHTML =
      '<input type="text" id="greve-pj-search" autocomplete="off" oninput="rechercherPjGreve(this.value)" placeholder="Rechercher un PJ par nom (2 caractères min)..." style="width:100%;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;padding:.4rem;font-family:\'Crimson Pro\',serif;font-size:.85rem;outline:none;box-sizing:border-box">' +
      '<div id="greve-pj-suggestions" style="margin-top:.3rem"></div>';
    chargerPjPourGreve();
    return;
  }

  if (nouveauType === 'organisation') {
    zone.innerHTML = '<div style="font-size:.78rem;color:#9a8a68">Chargement des organisations...</div>';
    const orgas = (typeof chargerOrganisationsPourRumeur === 'function') ? await chargerOrganisationsPourRumeur() : [];
    if (_greve.type !== 'organisation') return; // le joueur a change de type entre-temps
    zone.innerHTML = '<select id="greve-cible-select" onchange="choisirCibleSimpleGreve(this)" style="width:100%;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;padding:.4rem;font-family:\'Crimson Pro\',serif;font-size:.85rem;outline:none">' +
      '<option value="">— Choisir une organisation —</option>' +
      orgas.map(o => '<option value="' + o.id + '" data-label="' + escapeHtmlText(o.nom) + '">' + escapeHtmlText(o.nom) + ' (' + escapeHtmlText(COUNTRIES[o.country]?.n || o.country) + ')</option>').join('') +
      '</select>';
    return;
  }

  if (nouveauType === 'entreprise') {
    zone.innerHTML = '<select id="greve-cible-select" onchange="choisirCibleSimpleGreve(this)" style="width:100%;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;padding:.4rem;font-family:\'Crimson Pro\',serif;font-size:.85rem;outline:none">' +
      '<option value="">— Choisir une entreprise —</option>' +
      GREVE_ENTREPRISES_CIBLABLES.map(e => '<option value="' + e.id + '" data-label="' + escapeHtmlText(e.label) + '">' + escapeHtmlText(e.label) + '</option>').join('') +
      '</select>';
    return;
  }

  // gouvernement / pays : meme liste de pays, seule la semantique de l'effet differe ensuite
  // (meme convention que _rumeur, plateau-pnj.js).
  const paysListe = Object.keys(COUNTRIES).sort((a, b) => (COUNTRIES[a].n || a).localeCompare(COUNTRIES[b].n || b, 'fr'));
  zone.innerHTML = '<select id="greve-cible-select" onchange="choisirCibleSimpleGreve(this)" style="width:100%;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;padding:.4rem;font-family:\'Crimson Pro\',serif;font-size:.85rem;outline:none">' +
    '<option value="">— Choisir un pays —</option>' +
    paysListe.map(p => '<option value="' + p + '" data-label="' + escapeHtmlText(COUNTRIES[p].n || p) + '">' + escapeHtmlText(COUNTRIES[p].n || p) + '</option>').join('') +
    '</select>';
}

function rechercherPjGreve(query) {
  const suggestionsDiv = document.getElementById('greve-pj-suggestions');
  if (!suggestionsDiv) return;
  const q = (query || '').trim().toLowerCase();
  if (q.length < 2) { suggestionsDiv.innerHTML = ''; return; }
  const resultats = (_grevePjCache || []).filter(p => (p.name || '').toLowerCase().includes(q)).slice(0, 8);
  if (resultats.length === 0) {
    suggestionsDiv.innerHTML = '<div style="font-size:.75rem;color:#7a6a50;padding:.3rem">Aucun résultat.</div>';
    return;
  }
  suggestionsDiv.innerHTML = resultats.map(p =>
    '<div onclick="choisirCiblePjGreve(\'' + p.name.replace(/'/g, "\\'") + '\')" style="padding:.4rem .6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.25rem;cursor:pointer;font-size:.8rem;color:#c0b090" onmouseover="this.style.background=\'#1a1005\'" onmouseout="this.style.background=\'#0f0d05\'">' +
      escapeHtmlText(p.name) + (p.country ? ' <span style="color:#7a6a50">(' + escapeHtmlText(COUNTRIES[p.country]?.n || p.country) + ')</span>' : '') +
    '</div>'
  ).join('');
}

function choisirCiblePjGreve(nom) {
  if (!_greve) return;
  _greve.cibleValue = nom;
  _greve.cibleLabel = nom;
  const input = document.getElementById('greve-pj-search');
  if (input) input.value = nom;
  const suggestions = document.getElementById('greve-pj-suggestions');
  if (suggestions) suggestions.innerHTML = '';
  majRecapCibleGreve();
}

function choisirCibleSimpleGreve(selectEl) {
  if (!_greve) return;
  const opt = selectEl.selectedOptions[0];
  _greve.cibleValue = selectEl.value || null;
  _greve.cibleLabel = (opt && selectEl.value) ? opt.getAttribute('data-label') : null;
  majRecapCibleGreve();
}

async function validerLancementGreve() {
  if (!_greve || _greve.soumission) return;
  const orga = getOrgaById(_greve.orgaId);
  if (!orga) { showToast('Syndicat introuvable', '', false); return; }
  if (orga.chef !== state.char?.name) { showToast('Accès refusé', 'Réservé au chef du syndicat.', false); return; }
  if (!_greve.cibleValue) { showToast('Cible requise', 'Sélectionnez une cible avant de lancer la grève.', false); return; }
  const revendications = (_greve.revendications || '').trim();
  if (!revendications) { showToast('Revendications requises', 'Rédigez vos revendications avant de lancer la grève.', false); return; }
  const nbMembres = orga.membres?.length || 0;
  if (nbMembres < GREVE_MEMBRES_MIN) { showToast('Syndicat trop petit', 'Au moins ' + GREVE_MEMBRES_MIN + ' membres sont nécessaires.', false); return; }
  if (orga.greve?.actif) { showToast('Grève déjà en cours', '', false); return; }

  _greve.soumission = true;
  const r = await deduireCoutOrdre({ pa: 1, cost: 0 });
  if (!r.ok) { signalerRefusCout(r); _greve.soumission = false; return; }

  orga.greve = {
    actif: true,
    type: _greve.type,
    cibleValue: _greve.cibleValue,
    cibleLabel: _greve.cibleLabel,
    revendications,
    dateDebut: new Date().toISOString(),
    joursActifs: 0,
    derniereApplicationJour: null
  };
  sauvegarderOrga(orga);

  document.getElementById('modal-postes').classList.remove('open');
  showToast('Grève lancée !', '"' + orga.nom + '" est en grève contre ' + _greve.cibleLabel + '.', true, true);
  addJournalEntry('Grève lancée par "' + orga.nom + '" contre ' + _greve.cibleLabel + '. Revendications : ' + revendications, 'event-info');
  addExternalEvent('✊ "' + orga.nom + '" se met en grève. Revendications : ' + revendications);
  if (typeof sbEnregistrerEvenementPublic === 'function') {
    sbEnregistrerEvenementPublic(orga.country, 'greve_ordinaire_debut', {
      personnages: [orga.chef].filter(Boolean),
      libelle: '"' + orga.nom + '" se met en grève contre ' + orga.greve.cibleLabel + '. Revendications : ' + revendications,
      data: { orga_id: orga.id, orga_nom: orga.nom, chef: orga.chef, cible: orga.greve.cibleLabel, revendications },
      sourceRef: orga.id
    }).catch(() => {});
  }
  _greve = null;
  updateUI();
}

function confirmerTerminerGreve(orgaId) {
  const orga = getOrgaById(orgaId);
  if (!orga) return;
  if (orga.chef !== state.char?.name) { showToast('Accès refusé', 'Réservé au chef du syndicat.', false); return; }
  if (!orga.greve?.actif) { showToast('Aucune grève en cours', '', false); return; }

  const cibleLabel = orga.greve.cibleLabel;
  const revendicationsFin = orga.greve.revendications;
  // orga.greve est ECRASE par null juste apres : la duree reelle de la mobilisation (parfois
  // plusieurs dizaines de jours) etait detruite avec lui, et la chronique nationale ne gardait que
  // « une greve a commence » / « une greve s'est terminee », sans moyen de reconstituer combien de
  // temps elle avait dure. On capture les deux valeurs, comme le code capture deja cibleLabel et
  // revendications pour exactement cette raison.
  const dateDebutGreve = orga.greve.dateDebut || null;
  const joursActifsGreve = orga.greve.joursActifs || 0;
  orga.greve = null;
  sauvegarderOrga(orga);

  document.getElementById('modal-postes').classList.remove('open');
  showToast('Grève terminée', 'La grève de "' + orga.nom + '" contre ' + cibleLabel + ' a pris fin.', true);
  addJournalEntry('Fin de la grève de "' + orga.nom + '" contre ' + cibleLabel + '.', 'event-info');
  addExternalEvent('🏳 "' + orga.nom + '" met fin à sa grève.');
  if (typeof sbEnregistrerEvenementPublic === 'function') {
    sbEnregistrerEvenementPublic(orga.country, 'greve_ordinaire_fin', {
      personnages: [orga.chef].filter(Boolean),
      libelle: 'Fin de la grève de "' + orga.nom + '" contre ' + cibleLabel + '.',
      data: { orga_id: orga.id, orga_nom: orga.nom, chef: orga.chef, cible: cibleLabel, revendications: revendicationsFin, date_debut: dateDebutGreve, jours_actifs: joursActifsGreve },
      sourceRef: orga.id
    }).catch(() => {});
  }
  updateUI();
}

// =====================
// GREVE GENERALE — consultation intersyndicale (table dediee greves_generales, cf.
// migration_greves.sql -- coordonne PLUSIEURS organisations, ne peut pas vivre dans le jsonb
// d'une seule d'entre elles, meme besoin structurel que demandes_manifestation en son temps).
// =====================
const GREVE_GENERALE_ACTIVITE_MAX_JOURS = 30;

// §4 du cahier des charges : source fiable de "derniere activite reelle du chef" -- personnages.
// updated_at, retouchee au minimum toutes les 30s de connexion active (filet de securite
// periodique, voir sbVerifierEtSauvegarderPersonnage/supabase.js) ainsi qu'a chaque action de
// jeu -- deja utilisee dans ce but exact ailleurs dans ce projet.
async function chefActifRecemment(nomChef) {
  if (!nomChef || typeof sbGet !== 'function') return false;
  const rows = await sbGet('personnages', `name=eq.${encodeURIComponent(nomChef)}&select=updated_at`).catch(() => null);
  const updatedAt = rows?.[0]?.updated_at;
  if (!updatedAt) return false;
  const ecouleMs = Date.now() - new Date(updatedAt).getTime();
  return ecouleMs <= GREVE_GENERALE_ACTIVITE_MAX_JOURS * 24 * 60 * 60 * 1000;
}

// Liste FIGEE au moment ou elle est appelee (au lancement de la consultation, jamais recalculee
// apres coup -- §4 : "au lancement de la consultation, etablir la liste des syndicats actifs
// eligibles"). Un syndicat qui ne remplit pas ces conditions ne compte pas dans le denominateur
// et n'a aucun pouvoir de blocage.
async function syndicatsEligiblesGreveGenerale(pays) {
  const toutes = (typeof sbLoadOrganisations === 'function') ? await sbLoadOrganisations().catch(() => []) : [];
  const syndicats = (toutes || []).filter(o =>
    o.type === 'syndicale' && o.country_origine === pays && o.chef && (o.membres?.length || 0) >= GREVE_MEMBRES_MIN
  );
  const resultats = [];
  for (const s of syndicats) {
    if (await chefActifRecemment(s.chef)) resultats.push(s);
  }
  return resultats;
}

function compterAdherentsUniques(orgasListe) {
  const noms = new Set();
  (orgasListe || []).forEach(o => (o.membres || []).forEach(m => { if (m?.nom) noms.add(m.nom); }));
  return noms.size;
}

// §9 du cahier des charges : identification STRUCTURELLE (jamais par nom d'organisation) --
// tout syndicat declare corpsMetier==='police' a la creation (voir ouvrirFormulaireOrga/
// confirmerCreationOrga) qui est ACTUELLEMENT en greve (ordinaire) ou participant actif d'une
// greve generale rend la repression policiere indisponible (plateau-politique.js,
// ouvrirReprimerManif/confirmerReprimerManif + l'option "reprimer" de mobiliser_police).
// Redevient disponible des que ce syndicat met fin a sa greve ou se retire de la greve generale.
function syndicatPoliceEnGreve(pays) {
  return (state.organisations || []).some(o =>
    o.type === 'syndicale' && o.country_origine === pays && o.corpsMetier === 'police' &&
    (o.greve?.actif || o.greveGeneraleStatut === 'actif')
  );
}

async function ouvrirAppelGreveGenerale(orgaId) {
  const orga = getOrgaById(orgaId);
  if (!orga) return;
  if (orga.chef !== state.char?.name) { showToast('Accès refusé', 'Réservé au chef du syndicat.', false); return; }
  if (orga.greveGeneraleEnCoursId) { showToast('Déjà engagé', 'Ce syndicat participe déjà à une consultation ou une grève générale en cours.', false); return; }
  const nbMembres = orga.membres?.length || 0;
  if (nbMembres < GREVE_MEMBRES_MIN) { showToast('Syndicat trop petit', 'Au moins ' + GREVE_MEMBRES_MIN + ' membres sont nécessaires.', false); return; }

  const pays = orga.country_origine || state.country;
  const existante = await sbGet('greves_generales', `country=eq.${encodeURIComponent(pays)}&statut=in.(consultation,active)`).catch(() => null);
  if (existante && existante.length > 0) {
    showToast('Grève générale déjà en cours', 'Une consultation ou une grève générale est déjà en cours dans ce pays.', false);
    return;
  }

  document.getElementById('postes-modal-title').textContent = '📣 Appeler à une grève générale';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +
    '<div style="font-size:.75rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Ceci n\'engage AUCUNE grève immédiatement. Un mail sera envoyé à chaque chef de syndicat actif éligible, et un sujet public sera créé sur le Forum National. La grève générale n\'entrera en vigueur que si au moins 2/3 des syndicats éligibles acceptent, pour un total d\'au moins ' + GREVE_GENERALE_ADHERENTS_MIN + ' adhérents uniques.</div>' +
    '<div style="font-family:\'Bebas Neue\',sans-serif;font-size:.7rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.3rem">REVENDICATIONS</div>' +
    '<textarea id="greve-generale-revendications-input" placeholder="Rédigez librement vos revendications..." style="width:100%;min-height:90px;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;padding:.5rem;font-family:\'Crimson Pro\',serif;font-size:.85rem;outline:none;resize:vertical;margin-bottom:.9rem;box-sizing:border-box"></textarea>' +
    '<button onclick="confirmerAppelGreveGenerale(\'' + orgaId + '\')" style="width:100%;font-family:\'Bebas Neue\',sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.6rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">Lancer la consultation — 1 PA</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerAppelGreveGenerale(orgaId) {
  const orga = getOrgaById(orgaId);
  if (!orga) return;
  if (orga.chef !== state.char?.name) { showToast('Accès refusé', 'Réservé au chef du syndicat.', false); return; }
  const revendications = (document.getElementById('greve-generale-revendications-input')?.value || '').trim();
  if (!revendications) { showToast('Revendications requises', 'Rédigez vos revendications avant de lancer la consultation.', false); return; }
  const nbMembres = orga.membres?.length || 0;
  if (nbMembres < GREVE_MEMBRES_MIN) { showToast('Syndicat trop petit', '', false); return; }
  if (orga.greveGeneraleEnCoursId) { showToast('Déjà engagé', '', false); return; }

  const r = await deduireCoutOrdre({ pa: 1, cost: 0 });
  if (!r.ok) { signalerRefusCout(r); return; }

  const pays = orga.country_origine || state.country;
  const eligibles = await syndicatsEligiblesGreveGenerale(pays);
  // L'initiateur est toujours reput eligible (c'est son chef qui agit a l'instant meme).
  if (!eligibles.some(s => s.id === orga.id)) eligibles.push(orga);

  const ggId = 'greve_generale_' + Date.now();
  const participants = eligibles.map(s => ({
    orgaId: s.id,
    orgaNom: s.nom,
    chef: s.chef,
    statut: s.id === orga.id ? 'accepte' : 'en_discussion'
  }));

  const inserted = (typeof sbInsert === 'function') ? await sbInsert('greves_generales', {
    id: ggId, country: pays, statut: 'consultation',
    initiateur: orga.chef, syndicat_initiateur_id: orga.id,
    revendications, participants,
    date_lancement: new Date().toISOString(), jours_actifs: 0
  }).catch(() => null) : null;
  if (!inserted) { showToast('Erreur', "La consultation n'a pas pu être lancée.", false); return; }

  orga.greveGeneraleEnCoursId = ggId;
  orga.greveGeneraleStatut = 'actif'; // l'initiateur soutient d'office son propre appel
  sauvegarderOrga(orga);

  // Mail a chaque chef eligible SAUF l'initiateur (deja acquis) -- boutons Accepter/Refuser en
  // ligne, meme pattern que le vote de confiance (notifierDeputesPourVoteConfiance,
  // plateau-politique.js).
  const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : 'Jour ' + (state.day || 1);
  const sujet = 'Appel à la grève générale — ' + orga.nom;
  for (const s of eligibles) {
    if (s.id === orga.id) continue;
    const corps = orga.chef + ', chef du syndicat « ' + orga.nom + ' », appelle à une grève générale.<br><br>' +
      '<i>Revendications :</i> ' + escapeHtmlText(revendications) + '<br><br>' +
      marqueurActionMail('greve_oui', ggId, s.id) + marqueurActionMail('greve_non', ggId, s.id);
    await sbSendMail(orga.nom, s.chef, sujet, corps, time).catch(() => {});
  }

  // Sujet public sur le Forum National (pas 'presse', reserve aux journalistes -- pas
  // 'gouvernement', prive aux ministres, voir audit).
  if (typeof sbCreateTopic === 'function') {
    const titre = 'Appel à la grève générale — ' + orga.nom;
    const topicId = await sbCreateTopic('national', titre, orga.chef, pays, time, true, false, orga.chef, orga.id, orga.avatar || (TYPES_ORGANISATIONS.syndicale?.icon)).catch(() => null);
    if (topicId) {
      const corpsTopic = orga.chef + ', chef du syndicat « ' + orga.nom + ' », appelle à une grève générale.<br><br><i>Revendications :</i><br>' + escapeHtmlText(revendications);
      await sbCreatePost(topicId, orga.chef, corpsTopic, time, true, false, [], null, orga.chef, orga.id, orga.avatar || null).catch(() => {});
      await sbUpdate('greves_generales', `id=eq.${encodeURIComponent(ggId)}`, { forum_topic_id: topicId }).catch(() => {});
    }
  }

  document.getElementById('modal-postes').classList.remove('open');
  showToast('Consultation lancée !', eligibles.length + ' syndicat(s) éligible(s) consulté(s).', true, true);
  addJournalEntry('Appel à la grève générale lancé par "' + orga.nom + '".', 'event-info');
  addExternalEvent('📣 "' + orga.nom + '" appelle à une grève générale. Consultation intersyndicale en cours.');
  updateUI();
}

// Appelee depuis les boutons du mail (meme pattern que voterConfiance, plateau-politique.js) --
// verifie que le repondant est bien le chef ACTUEL du syndicat concerne, relit la ligne en
// direct (jamais un cache), et applique la reponse via un CAS structurel sur la colonne jsonb
// "participants" (meme doctrine que journal_editions.double_page_centrale) pour ne jamais
// perdre une reponse concurrente d'un autre chef repondant au meme moment.
async function repondreAppelGreveGenerale(ggId, orgaId, reponse) {
  const orga = (typeof sbGetOrganisationParId === 'function') ? await sbGetOrganisationParId(orgaId).catch(() => null) : getOrgaById(orgaId);
  if (!orga) { showToast('Syndicat introuvable', '', false); return; }
  if (orga.chef !== state.char?.name) { showToast('Accès refusé', 'Réservé au chef de ce syndicat.', false); return; }

  let ggFinal = null;
  for (let tentative = 0; tentative < 5 && !ggFinal; tentative++) {
    const rows = await sbGet('greves_generales', `id=eq.${encodeURIComponent(ggId)}`).catch(() => null);
    const gg = rows?.[0];
    if (!gg) { showToast('Consultation introuvable', 'Cette grève générale n\'existe plus.', false); return; }
    if (gg.statut !== 'consultation') { showToast('Trop tard', 'Cette consultation est déjà close.', false); return; }
    const participants = gg.participants || [];
    const idx = participants.findIndex(p => p.orgaId === orgaId);
    if (idx === -1) { showToast('Non concerné', 'Votre syndicat ne fait pas partie de cette consultation.', false); return; }
    if (participants[idx].statut !== 'en_discussion') { showToast('Déjà répondu', 'Votre syndicat a déjà répondu à cet appel.', false); return; }

    const nouveauxParticipants = participants.map((p, i) => i === idx ? { ...p, statut: reponse } : p);
    const filtreCAS = `id=eq.${encodeURIComponent(ggId)}&participants=eq.${encodeURIComponent(JSON.stringify(gg.participants))}`;
    const res = await sbUpdate('greves_generales', filtreCAS, { participants: nouveauxParticipants }).catch(() => null);
    if (res && res.length > 0) ggFinal = res[0];
  }
  if (!ggFinal) { showToast('Réponse non enregistrée', 'Une autre réponse a été traitée au même moment, réessayez.', false); return; }

  orga.greveGeneraleStatut = reponse;
  sauvegarderOrga(orga);

  showToast(reponse === 'accepte' ? 'Grève générale acceptée' : 'Grève générale refusée', 'Votre syndicat "' + orga.nom + '" a répondu.', true);
  addJournalEntry('"' + orga.nom + '" a ' + (reponse === 'accepte' ? 'accepté' : 'refusé') + ' l\'appel à la grève générale.', 'event-info');

  await verifierAdoptionGreveGenerale(ggId);
  updateUI();
}

// §5 du cahier des charges : adoption des que >= 2/3 des syndicats eligibles (arrondi superieur)
// ont accepte ET que les syndicats ayant accepte representent ensemble >= 100 adherents uniques.
// Verifiee apres CHAQUE reponse (jamais une seule fois par un cron) -- une reponse peut a tout
// moment faire basculer le seuil.
async function verifierAdoptionGreveGenerale(ggId) {
  const rows = await sbGet('greves_generales', `id=eq.${encodeURIComponent(ggId)}`).catch(() => null);
  const gg = rows?.[0];
  if (!gg || gg.statut !== 'consultation') return;
  const participants = gg.participants || [];
  const eligibles = participants.length;
  if (eligibles === 0) return;
  const acceptes = participants.filter(p => p.statut === 'accepte');
  const seuil = Math.ceil(eligibles * 2 / 3);
  if (acceptes.length < seuil) return;

  const toutesOrgas = (typeof sbLoadOrganisations === 'function') ? await sbLoadOrganisations().catch(() => []) : [];
  const orgasAcceptees = acceptes.map(p => toutesOrgas.find(o => o.id === p.orgaId)).filter(Boolean);
  const adherentsUniques = compterAdherentsUniques(orgasAcceptees);
  if (adherentsUniques < GREVE_GENERALE_ADHERENTS_MIN) return; // pas encore assez d'adherents mobilises, la consultation reste ouverte

  const palier = palierGreveGenerale(adherentsUniques);
  const filtreCAS = `id=eq.${encodeURIComponent(ggId)}&statut=eq.consultation`;
  const res = await sbUpdate('greves_generales', filtreCAS, {
    statut: 'active',
    date_entree_vigueur: new Date().toISOString(),
    puissance_niveau: palier ? palier.niveau : 1
  }).catch(() => null);
  if (!res || res.length === 0) return; // deja adoptee entretemps par une autre reponse concurrente

  // Syndicats non-acceptants : "ne sont associes a rien" (§5) -- detaches de la consultation.
  // Syndicats acceptants : passent en participation active (visibleSi de greve_generale_retirer).
  for (const p of participants) {
    const orgaLive = toutesOrgas.find(o => o.id === p.orgaId);
    if (!orgaLive) continue;
    if (p.statut === 'accepte') {
      orgaLive.greveGeneraleStatut = 'actif';
    } else {
      orgaLive.greveGeneraleEnCoursId = null;
      orgaLive.greveGeneraleStatut = null;
    }
    if (typeof sbSaveOrganisation === 'function') await sbSaveOrganisation(orgaLive).catch(() => {});
  }

  showToast('Grève générale adoptée !', 'Niveau ' + (palier ? palier.niveau : 1) + ' — ' + adherentsUniques + ' adhérents mobilisés.', true, true);
  addJournalEntry('La grève générale est entrée en vigueur (niveau ' + (palier ? palier.niveau : 1) + ').', 'event-info');
  addExternalEvent('🔥 La grève générale entre en vigueur ! ' + adherentsUniques + ' adhérents mobilisés à travers le pays.');
}

// §8 du cahier des charges : pas de second vote collectif, chaque chef retire son syndicat
// individuellement, definitivement, sans attendre le lendemain (recalcul immediat).
async function confirmerRetraitGreveGenerale(orgaId) {
  const orga = getOrgaById(orgaId);
  if (!orga) return;
  if (orga.chef !== state.char?.name) { showToast('Accès refusé', 'Réservé au chef du syndicat.', false); return; }
  if (!orga.greveGeneraleEnCoursId || orga.greveGeneraleStatut !== 'actif') {
    showToast('Non concerné', 'Ce syndicat ne participe à aucune grève générale active.', false);
    return;
  }
  const ggId = orga.greveGeneraleEnCoursId;

  let retireOk = false;
  for (let tentative = 0; tentative < 5 && !retireOk; tentative++) {
    const rows = await sbGet('greves_generales', `id=eq.${encodeURIComponent(ggId)}`).catch(() => null);
    const gg = rows?.[0];
    if (!gg || gg.statut !== 'active') {
      orga.greveGeneraleEnCoursId = null; orga.greveGeneraleStatut = null; sauvegarderOrga(orga);
      showToast('Grève générale déjà terminée', '', false);
      return;
    }
    const participants = gg.participants || [];
    const idx = participants.findIndex(p => p.orgaId === orgaId);
    if (idx === -1 || participants[idx].statut !== 'accepte') { showToast('Non concerné', '', false); return; }
    const nouveauxParticipants = participants.map((p, i) => i === idx ? { ...p, statut: 'retire' } : p);
    const filtreCAS = `id=eq.${encodeURIComponent(ggId)}&participants=eq.${encodeURIComponent(JSON.stringify(gg.participants))}`;
    const res = await sbUpdate('greves_generales', filtreCAS, { participants: nouveauxParticipants }).catch(() => null);
    if (res && res.length > 0) retireOk = true;
  }
  if (!retireOk) { showToast('Retrait non enregistré', 'Réessayez.', false); return; }

  orga.greveGeneraleEnCoursId = null;
  orga.greveGeneraleStatut = null;
  sauvegarderOrga(orga);

  document.getElementById('modal-postes').classList.remove('open');
  showToast('Syndicat retiré', '"' + orga.nom + '" ne participe plus à la grève générale.', true);
  addJournalEntry('"' + orga.nom + '" se retire de la grève générale.', 'event-info');
  addExternalEvent('🚪 "' + orga.nom + '" se retire de la grève générale.');

  await recalculerPuissanceApresRetraitGreveGenerale(ggId);
  updateUI();
}

// Recalcul IMMEDIAT (jamais differe au cron du lendemain) sur les adherents uniques des
// syndicats ENCORE participants -- exemple du cahier des charges §8 (500 -> niveau 5, retrait de
// 130 -> 370 restants -> niveau 3). En-dessous de 100 adherents uniques restants : fin
// automatique de la grève générale.
async function recalculerPuissanceApresRetraitGreveGenerale(ggId) {
  const rows = await sbGet('greves_generales', `id=eq.${encodeURIComponent(ggId)}`).catch(() => null);
  const gg = rows?.[0];
  if (!gg || gg.statut !== 'active') return;
  const participants = gg.participants || [];
  const restants = participants.filter(p => p.statut === 'accepte');

  const toutesOrgas = (typeof sbLoadOrganisations === 'function') ? await sbLoadOrganisations().catch(() => []) : [];
  const orgasRestantes = restants.map(p => toutesOrgas.find(o => o.id === p.orgaId)).filter(Boolean);
  const adherentsUniques = compterAdherentsUniques(orgasRestantes);

  if (adherentsUniques < GREVE_GENERALE_ADHERENTS_MIN) {
    await sbUpdate('greves_generales', `id=eq.${encodeURIComponent(ggId)}`, { statut: 'terminee' }).catch(() => {});
    for (const orgaLive of orgasRestantes) {
      orgaLive.greveGeneraleEnCoursId = null;
      orgaLive.greveGeneraleStatut = null;
      if (typeof sbSaveOrganisation === 'function') await sbSaveOrganisation(orgaLive).catch(() => {});
    }
    addExternalEvent('🏳 La grève générale s\'effondre : moins de ' + GREVE_GENERALE_ADHERENTS_MIN + ' adhérents mobilisés.');
    addJournalEntry('La grève générale a pris fin (effondrement de la mobilisation).', 'event-info');
    return;
  }

  const palier = palierGreveGenerale(adherentsUniques);
  await sbUpdate('greves_generales', `id=eq.${encodeURIComponent(ggId)}`, { puissance_niveau: palier ? palier.niveau : 1 }).catch(() => {});
}

// ===========================================================================================
// LES SYNDICATS ETUDIANTS DE LA SALLE DE REUNION (13 octobre 2026)
// ===========================================================================================
//
// DEUX ECRANS, ET ILS NE DECIDENT RIEN. `syndicat_etudiant_domicilier` verifie la PRESENCE dans
// la salle, paie 150 FR de frais de greffe a la caisse du Tribunal par `payer_ordre`, ecrit le
// syndicat et DELIVRE l'extrait de domiciliation -- le tout dans une seule transaction. Le
// navigateur envoie un nom et affiche un verdict.
//
// AUCUNE EXCLUSIVITE. La porte ne verifie PAS si le local est deja occupe : plusieurs syndicats
// sont domicilies ici en meme temps, et c'est la nature nouvelle de la piece. C'est l'inverse
// exact de `confirmerCreationOrga`, le chemin des locaux loues, qui refuse sur `localId` -- et
// ce chemin-la n'est plus atteignable ici, la salle n'etant plus louable.
//
// AUCUNE PREROGATIVE NOUVELLE. Un syndicat etudiant est un syndicat : les ecrans de membres,
// d'adhesion et d'ordres sont CEUX QUI EXISTENT, reutilises tels quels.

const SYNDICAT_ETUDIANT_LOCAL = 'universite:salle_reunion';

const SYNDICAT_REFUS = {
  acteur_non_authentifie: "Votre personnage n'est pas reconnu par le serveur.",
  personnage_introuvable: "Votre personnage n'a pas ete retrouve.",
  nom_requis:             "Donnez un nom a votre syndicat (deux caracteres au moins).",
  nom_trop_long:          "Nom trop long (80 caracteres au plus).",
  presence_en_salle_de_reunion_requise: "Il faut etre dans la salle de reunion de l'universite.",
  inventaire_plein:       "Votre inventaire est plein : le greffe n'aurait pas ou vous remettre l'extrait.",
  caisse_du_tribunal_introuvable: "La caisse du tribunal est introuvable. Signalez-le.",
  pa_insuffisants:        "Vous n'avez pas assez de PA (2 requis).",
  fonds_insuffisants:     "Vous n'avez pas les 150 FR de frais de greffe.",
  ordre_inconnu:          "Cet ordre n'est pas declare au miroir des couts. Signalez-le.",
  cout_non_declare:       "Le cout annonce n'est pas celui que le serveur connait. Signalez-le."
};

function ouvrirSyndicatEtudiantCreer() {
  document.getElementById('postes-modal-title').textContent = 'Domicilier un syndicat etudiant';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1rem">'
    + '<div style="font-size:.78rem;color:#8a8060;line-height:1.6;margin-bottom:.8rem">'
    + '150 FR de <strong style="color:#c0b090">frais de greffe</strong> — verses a la caisse du '
    + 'Tribunal — et 2 PA. Aucun loyer, aucun cout recurrent, aucune exclusivite : plusieurs '
    + 'syndicats sont domicilies dans cette salle. La constitution vous delivre un '
    + '<strong style="color:#c0b090">extrait de domiciliation</strong> dans votre inventaire.'
    + '</div>'
    + '<input id="syndet-nom" type="text" maxlength="80" placeholder="Nom du syndicat" '
    + 'style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;'
    + 'font-family:Crimson Pro,serif;font-size:.85rem;outline:none;box-sizing:border-box;margin-bottom:.4rem">'
    + '<textarea id="syndet-desc" maxlength="300" rows="3" placeholder="Objet du syndicat (facultatif)" '
    + 'style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;'
    + 'font-family:Crimson Pro,serif;font-size:.85rem;outline:none;box-sizing:border-box;resize:vertical"></textarea>'
    + '<button onclick="confirmerSyndicatEtudiantCreer()" style="margin-top:.6rem;'
    + 'font-family:Bebas Neue,sans-serif;font-size:.74rem;letter-spacing:.08em;padding:.4rem .8rem;'
    + 'border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">'
    + 'Domicilier (150 FR · 2 PA)</button>'
    + '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerSyndicatEtudiantCreer() {
  const nom = (document.getElementById('syndet-nom')?.value || '').trim();
  const desc = (document.getElementById('syndet-desc')?.value || '').trim();
  if (!nom || nom.length < 2) { showToast('Nom requis', 'Donnez un nom a votre syndicat.', false); return; }
  if (typeof sbRpc !== 'function') return;
  document.getElementById('modal-postes').classList.remove('open');
  const v = await sbRpc('syndicat_etudiant_domicilier', { p_nom: nom, p_desc: desc || null })
    .then(r => Array.isArray(r) ? r[0] : r).catch(() => null);
  if (!v || v.ok !== true) {
    const r = v && v.raison;
    showToast('Domiciliation refusee',
      (r && SYNDICAT_REFUS[r]) || "Le greffe n'a pas enregistre la domiciliation.", false);
    return;
  }
  // LA BASE FAIT AUTORITE SUR LES DEUX ECRITURES : le syndicat et l'extrait. On relit.
  if (typeof chargerOrganisations === 'function') await chargerOrganisations().catch(() => {});
  if (typeof rafraichirInventaireDepuisServeur === 'function') await rafraichirInventaireDepuisServeur();
  showToast('Syndicat domicilie',
    nom + ' est domicilie a la salle de reunion. L\'extrait de domiciliation est dans votre '
    + 'inventaire — 150 FR de frais de greffe.', true, true);
  addJournalEntry('Syndicat etudiant domicilie : ' + nom + '.', 'event-good');
  updateUI();
  ouvrirSyndicatsEtudiants();
}

// LES SYNDICATS DOMICILIES ICI. L'ecran REUTILISE les fonctions qui existent -- gestion des
// membres, demande d'adhesion, ordres d'organisation -- et n'en ajoute aucune. Le duplicata de
// l'extrait, lui, passe par la porte du GREFFE : il se demande au tribunal, pas ici.
function ouvrirSyndicatsEtudiants() {
  const moi = state.char?.name;
  const ici = (state.organisations || []).filter(o => o && o.localId === SYNDICAT_ETUDIANT_LOCAL);
  const ech = (t) => (typeof escapeHtmlText === 'function') ? escapeHtmlText(t) : String(t == null ? '' : t);

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;line-height:1.6;margin-bottom:.8rem">'
       + 'Les syndicats etudiants domicilies dans cette salle. Elle n\'est louable par personne, '
       + 'et aucun syndicat ne la privatise.'
       + '</div>';
  if (ici.length === 0) {
    html += '<div style="font-size:.82rem;color:#8a8060;font-style:italic">'
         + 'Aucun syndicat n\'est domicilie ici pour l\'instant.</div>';
  }
  ici.forEach(o => {
    const id = JSON.stringify(o.id).replace(/"/g, '&quot;');
    const membres = Array.isArray(o.membres) ? o.membres : [];
    const suisMembre = membres.some(m => m && m.nom === moi);
    const suisDirigeant = (o.president === moi || o.secretaire === moi || o.chef === moi);
    html += '<div style="border-top:1px solid #2a1a0a;padding:.6rem 0">'
         + '<div style="font-size:.84rem;color:#E8C97A">' + ech(o.nom || o.id) + '</div>'
         + '<div style="font-size:.72rem;color:#8a8060">'
         + membres.length + ' membre(s)'
         + (o.president ? ' · President : ' + ech(o.president) : '')
         + (o.secretaire ? ' · Secretaire : ' + ech(o.secretaire) : '')
         + '</div>';
    if (o.desc) {
      html += '<div style="font-size:.76rem;color:#9a8a68;font-style:italic;margin-top:.2rem">'
           + ech(o.desc) + '</div>';
    }
    html += '<div style="display:flex;flex-wrap:wrap;gap:.3rem;margin-top:.4rem">';
    if (!suisMembre) {
      html += '<button onclick="demanderAdhesion(' + id + ')" style="font-family:Bebas Neue,sans-serif;'
           + 'font-size:.72rem;letter-spacing:.06em;padding:.3rem .6rem;border:1px solid #4a6aaa;'
           + 'background:transparent;color:#6a8aca;cursor:pointer">Demander a adherer</button>';
    } else {
      html += '<button onclick="ouvrirGestionMembres(' + id + ')" style="font-family:Bebas Neue,sans-serif;'
           + 'font-size:.72rem;letter-spacing:.06em;padding:.3rem .6rem;border:1px solid #3a2a10;'
           + 'background:transparent;color:#9a8a4a;cursor:pointer">Membres</button>';
      html += '<button onclick="ouvrirOrdresOrga(' + id + ')" style="font-family:Bebas Neue,sans-serif;'
           + 'font-size:.72rem;letter-spacing:.06em;padding:.3rem .6rem;border:1px solid #3a2a10;'
           + 'background:transparent;color:#9a8a4a;cursor:pointer">Ordres</button>';
    }
    if (suisDirigeant) {
      html += '<button onclick="ouvrirDemandesAdhesion(' + id + ')" style="font-family:Bebas Neue,sans-serif;'
           + 'font-size:.72rem;letter-spacing:.06em;padding:.3rem .6rem;border:1px solid #8a6a20;'
           + 'background:transparent;color:#C9A84C;cursor:pointer">Demandes d\'adhesion</button>';
    }
    html += '</div></div>';
  });
  html += '<div style="font-size:.72rem;color:#5a4030;font-style:italic;margin-top:.8rem">'
       + 'Le duplicata de l\'extrait de domiciliation se demande au GREFFE du tribunal, par le '
       + 'President ou le Secretaire.</div>';
  html += '</div>';
  document.getElementById('postes-modal-title').textContent = 'Syndicats etudiants';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}
