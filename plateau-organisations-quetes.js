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
async function getTitulaireActuel(posteId, city, pays) {
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
  let eluId = CYCLES_ELECTORAUX?.[country]?.[cle]?.eluId;
  if (eluId === undefined && typeof sbLoadCyclesElectoraux === 'function') {
    const cycles = await sbLoadCyclesElectoraux(country).catch(() => null);
    if (cycles) {
      CYCLES_ELECTORAUX[country] = { ...(CYCLES_ELECTORAUX[country]||{}), ...cycles };
      eluId = cycles[cle]?.eluId;
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

// Presence dynamique du PNJ "Le Maire" de Luthecia, selon que le poste est occupe par un
// PJ ou vacant. Bureau du Maire : le PNJ n'y est que si le poste est vacant (sinon, c'est le
// PJ qui l'occupe). Hall : le PNJ (retrograde en simple citoyen) n'y apparait QUE si le
// poste est occupe par un PJ (sinon, il est "au travail" dans son bureau).
async function verifierPresenceMaireLuthecia(buildingId, roomId) {
  if (buildingId !== 'mairie-capitale') return;
  if (roomId !== 'hall_mairie' && roomId !== 'bureau_maire') return;
  if (typeof getTitulaireActuel !== 'function' || typeof renderPersonsList !== 'function') return;

  const titulaireInfo = await getTitulaireActuel('maire', 'capitale');
  const titulaire = titulaireInfo?.estPJ ? titulaireInfo.nom : null;
  // Le joueur a change de piece entre-temps : on n'ecrase pas un affichage devenu obsolete
  if (state.currentBuilding !== buildingId || state.currentRoom !== roomId) return;

  const room = BUILDINGS[buildingId]?.rooms?.[roomId];
  if (!room) return;
  const autresPersonnes = (room.persons || []).filter(p => p.job !== 'maire');

  if (roomId === 'bureau_maire') {
    renderPersonsList(titulaire ? autresPersonnes : (room.persons || []));
  } else if (roomId === 'hall_mairie') {
    if (titulaire) {
      const ancienMaire = { name: 'Gaston Ferule', role: 'Ancien maire, simple citoyen désormais', rel: 'neutral', job: 'citoyen' };
      renderPersonsList([...autresPersonnes, ancienMaire]);
    } else {
      renderPersonsList(autresPersonnes);
    }
  }
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

        const nouvelEtat = {
          proprietaire: state.char?.name,
          pnj: squatterChoisi?.id || null,
          pnjData: squatterChoisi || null,
          dateGeneration: Date.now()
        };

        // Systeme unifie : cache local (state.terrainsState) + Supabase
        if (typeof setTerrainState === 'function') {
          setTerrainState(terrainInfo.buildingId, nouvelEtat);
        }
        if (typeof sbSetTerrainState === 'function') {
          await sbSetTerrainState(state.country, terrainInfo.buildingId, nouvelEtat).catch(() => {});
        }

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
    // Confidentialite entierement determinee par le type (def.secret), plus de choix joueur
    // dans ce parcours (game design arrete le 26 aout 2026) : les 6 types publics restent
    // toujours publics ici, seule "criminelle" (Organisation Secrete) est automatiquement visible:false.
    visible: !def.secret,
  };

  state.organisations.push(nouvelleOrga);
  if (typeof sbSaveOrganisation === 'function') sbSaveOrganisation(nouvelleOrga).catch(() => {});

  // Lier au local en cours si on vient de gerer_local (scope ville ajoute le 2026-08-16 ;
  // les 7 locations sans city ont ete migrees, plus de repli de compatibilite necessaire)
  const location = (state.locationsActives || []).find(l =>
    l.buildingId === state.currentBuilding && l.locataire === state.char?.name &&
    l.city === state.currentCity
  );
  if (location) location.orgaId = id;

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

  document.getElementById('modal-postes').classList.remove('open');

  const nomInvitant = state.char?.name || 'Anonyme';
  const nomInvitantEchap = nomInvitant.replace(/'/g,"\\'");
  const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : 'Jour ' + (state.day || 1);
  const sujet = 'Invitation — ' + orga.nom;
  const corps = 'L\'organisation <strong>' + orga.nom + '</strong> vous invite à la rejoindre.<br><br>' +
    '<em>Cette invitation est privée : personne d\'autre n\'en a connaissance.</em><br><br>' +
    '<button onclick="accepterInvitationOrga(\'' + orgaId + '\',\'' + nomInvitantEchap + '\')" ' +
    'style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer;margin-top:.5rem;margin-right:.5rem">✓ Accepter l\'invitation</button>' +
    '<button onclick="refuserInvitationOrga(\'' + orgaId + '\',\'' + nomInvitantEchap + '\')" ' +
    'style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #6a3a2a;background:transparent;color:#8a4a2a;cursor:pointer;margin-top:.5rem">✕ Refuser l\'invitation</button>';

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

  orga.invitationsEnvoyees = (orga.invitationsEnvoyees || []).filter(i => i.nom !== state.char?.name);
  const grades = def.grades?.[state.country] || ['Membre'];
  if (!orga.membres) orga.membres = [];
  orga.membres.push({ nom: state.char?.name, grade: grades[0], gradeIdx: 0, rejointLe: state.day || 1 });
  sauvegarderOrga(orga);
  showToast('Invitation acceptée', 'Vous rejoignez "' + orga.nom + '" comme ' + grades[0] + '.', true);
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

  orga.invitationsEnvoyees = (orga.invitationsEnvoyees || []).filter(i => i.nom !== state.char?.name);
  sauvegarderOrga(orga);
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
          '<div style="margin-left:auto;font-size:.85rem;color:#8a6a20">' + ordre.pa + ' PA' + (TEST_MODE && ordre.pa > 0 ? ' (illimité' + (ordre.pa > 1 ? 's' : '') + ')' : '') + (ordre.cost > 0 ? ' · ' + ordre.cost.toLocaleString('fr-FR') + ' ' + cur : '') + '</div>' +
        '</div>' +
        '<div style="font-size:.68rem;color:#6a5a30;margin-bottom:.4rem">' + ordre.desc + '</div>' +
        (disabled ?
          '<div style="font-size:.85rem;color:#5a3a2a">Rang insuffisant pour cet ordre.</div>' :
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

  const def = TYPES_ORGANISATIONS[orga.type] || {};
  const ordre = (def.ordres || []).find(o => o.fn === fn);
  if (!ordre) return;
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  // Vérif coût financier (garde metier/financiere conservee). La disponibilite des PA est
  // desormais tranchee uniquement par deduireCoutOrdre() ci-dessous (Lot 1, correctif suite a
  // revue) -- plus de garde manuelle state.pa<..., qui bloquait a tort meme sous
  // TEST_MODE=true.
  if (ordre.cost > 0 && state.arg < ordre.cost) { showToast('Fonds insuffisants', ordre.cost + ' ' + cur + ' requis.', false); return; }

  // Deduction PA+cout centralisee -- deduireCoutOrdre() est l'AUTORITE UNIQUE sur la
  // disponibilite des PA. Appelee avant tout effet de bord (bloc "effets" plus bas) :
  // fail-closed.
  const r = await deduireCoutOrdre({ pa: ordre.pa, cost: ordre.cost });
  if (!r.ok) {
    showToast(r.raison === 'fonds_insuffisants' ? 'Fonds insuffisants' : 'PA insuffisants',
      r.raison === 'fonds_insuffisants' ? ordre.cost + ' ' + cur + ' requis.' : ordre.pa + ' PA requis.', false);
    return;
  }

  // Effets selon fonction
  const effets = {
    orga_petition:       () => { const gain = Math.floor(Math.random()*8)+3; state.pop = Math.min(100,(state.pop||0)+gain); showToast('Pétition lancée !','+'+gain+' POP.',true); addJournalEntry('Pétition de "'+orga.nom+'". +'+gain+' POP.','event-good'); addExternalEvent('📋 "'+orga.nom+'" lance une pétition publique.'); },
    orga_meeting:        () => { state.pop=Math.min(100,(state.pop||0)+5); state.inf=Math.min(100,(state.inf||0)+3); showToast('Meeting !','+5 POP +3 INF.',true,true); addJournalEntry('Meeting de "'+orga.nom+'".','event-good'); addExternalEvent('📢 "'+orga.nom+'" organise un meeting.'); },
    orga_collecte:       () => { const don=Math.floor(Math.random()*500)+200; orga.caisse=(orga.caisse||0)+don; showToast('Collecte réussie !','+'+don+' '+cur+' dans la caisse.',true); addJournalEntry('Collecte "'+orga.nom+'". +'+don+' '+cur+'.','event-good'); },
    orga_dividendes:     () => { const part=Math.floor((orga.caisse||0)*0.3); if(part<10){showToast('Caisse vide','Pas assez de fonds à distribuer.',false);return;} orga.caisse-=part; crediterFondsOrdinaires(part); showToast('Dividendes versés !','+'+part+' '+cur+'.',true); addJournalEntry('Dividendes reçus de "'+orga.nom+'". +'+part+' '+cur+'.','event-good'); },
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

  if (newNom && newNom.length >= 2) orga.nom = newNom;
  orga.devise = newDevise;
  orga.avatar = nouvelAvatar;
  sauvegarderOrga(orga);

  _orgaAvatarFileTemp = null;
  showToast('Paramètres enregistrés', '"' + orga.nom + '"', true);
  document.getElementById('modal-postes').classList.remove('open');
  switchSelfTab('orgas', null);
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
  if (!orga || orga.chef !== state.char?.name) return;
  // Reserve au type "criminelle" (Organisation Secrete) -- les 6 autres types restent toujours
  // publics dans ce game design, jamais de bascule vers secret pour eux (26 aout 2026).
  if (orga.type !== 'criminelle') return;
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
  sauvegarderOrga(orga);
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

// Source de verite unique pour l'identite visuelle d'un club, a partir de son id stable
// (chantier animations football, 28 aout 2026). Ne fabrique aucune donnee : renvoie
// exactement le champ `identite` deja porte par CLUBS_SPORTIFS, ou null si absent.
function identiteVisuelleClub(id) {
  const club = getClub(id);
  return (club && club.identite) || null;
}

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
  // Piete -> avantage offensif (lot "piete/football", 26 aout 2026) : locale au club (sa PROPRE
  // ville, jamais celle de l'adversaire ni celle ou se joue le match), lue directement dans
  // indices_villes (systeme distinct de budget_municipal utilise par securite/ecoles/espaces_
  // verts/associatif ci-dessus -- getIndiceVille gere deja nativement le repli pour les 3 autres
  // empires, aucun risque de regression hors Republia).
  const pieteHome = (typeof getIndiceVille === 'function') ? getIndiceVille(home.country, home.city, 'piete') : 50;
  const pieteAway = (typeof getIndiceVille === 'function') ? getIndiceVille(away.country, away.city, 'piete') : 50;
  const forceHome = (home.valeurBase + avantageDomicile + (bonusHome || 0)) * multiplicateurPiete(pieteHome);
  const forceAway = (away.valeurBase + (bonusAway || 0)) * multiplicateurPiete(pieteAway);
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

  const kickoff = calculerKickoffJournee(saison, prochaine.numero);
  for (const m of prochaine.matchs) {
    const clubHome = getClub(m.home), clubAway = getClub(m.away);
    const [contribHome, contribAway] = await Promise.all([calculerContributionEquipe(clubHome), calculerContributionEquipe(clubAway)]);
    await notifierConvocationAnticipee(clubHome, contribHome, clubAway, kickoff);
    await notifierConvocationAnticipee(clubAway, contribAway, clubHome, kickoff);
  }
  prochaine.notifie24h = true;
  if (typeof sbSaveChampionnat === 'function') await sbSaveChampionnat(saison).catch(() => {});
}

// Chantier "football live" (28 aout 2026) : le message n'entretient plus l'idee d'une presence
// physique volontaire au stade -- le personnage est automatiquement engage dans le match, hors
// ligne ou non (regle validee, section 17). Donne l'heure exacte d'echauffement/coup d'envoi/fin
// prevue, calculee depuis calculerKickoffJournee (meme calendrier que la resolution reelle,
// jamais une heure inventee separement).
async function notifierConvocationAnticipee(club, contrib, adversaire, kickoff) {
  const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : '';
  const dateTxt = kickoff.toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' });
  const heureEchauffement = new Date(kickoff.getTime() - DUREE_ECHAUFFEMENT_MS);
  const heureFin = finPrevueMatch(kickoff);
  const fmtH = (d) => d.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
  for (const t of contrib.titulaires) {
    if (typeof sbSendMail === 'function') {
      await sbSendMail('Ligue Officielle', t.nom, 'Convocation — ' + club.nom,
        'Vous êtes titulaire pour le match du ' + dateTxt + ' face à ' + adversaire.nom + '.<br><br>' +
        'Échauffement à ' + fmtH(heureEchauffement) + '.<br>Coup d\'envoi à ' + fmtH(kickoff) + '.<br>Fin prévue à ' + fmtH(heureFin) + '.<br><br>' +
        'Vous serez automatiquement engagé(e) dans le match dès le début de l\'échauffement — aucune présence physique n\'est nécessaire, et cela ne dépend pas de votre connexion. ' +
        'Vous serez en revanche indisponible pour toute autre démarche pendant cette période. Dernière chance de vous entraîner avant le coup d\'envoi !',
        time).catch(() => {});
    }
  }
  for (const r of contrib.remplacants) {
    if (typeof sbSendMail === 'function') {
      await sbSendMail('Ligue Officielle', r.nom, 'Convocation — ' + club.nom,
        'Vous êtes remplaçant(e) pour le match du ' + dateTxt + ' face à ' + adversaire.nom + ', échauffement à ' + fmtH(heureEchauffement) + '.', time).catch(() => {});
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
  let saison = await chargerOuInitialiserSaison();
  if (!saison || saison.phase === 'terminee') return saison;

  await verifierNotificationsAvantMatch(saison);

  // Chantier "football live" (28 aout 2026) : la resolution des matchs de la journee courante de
  // saison reguliere est entierement deleguee a avancerFootballLive() (echauffement 5min + 2x10min
  // + mitemps 5min, evenements progressifs, verrou d'immobilisation, recompenses idempotentes --
  // voir son entete). Cette fonction (verifierEtJouerJournees) ne reste responsable que du cycle
  // de vie de la saison elle-meme (init, transition vers les phases finales, progression des
  // phases finales) -- les playoffs restent geres a l'identique par jouerMatchsTour/
  // progresserPlayoffs, hors perimetre de ce chantier (resolution instantanee, inchangee).
  if (saison.phase === 'reguliere') {
    const avancee = await avancerFootballLive();
    if (avancee) saison = avancee;
    else saison = await chargerOuInitialiserSaison() || saison; // relit un etat pousse par un AUTRE client entre-temps
  }

  let modifie = false;

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

// Piete -> avantage offensif (lot "piete/football", 26 aout 2026) : meme philosophie que
// multiplicateurIndice ci-dessus (lineaire, neutre a 50), amplitude reduite -- piete est un
// facteur SECONDAIRE, jamais plus de +-10% (regle validee), contre +-30% pour securite/ecoles/
// espaces_verts/associatif. 0 -> x0.9, 50 -> x1.0 (neutre), 100 -> x1.1. Applique directement sur
// la force finale dans simulerMatch (ce qui determine les buts), jamais sur une caracteristique
// de joueur ni un nouveau jet -- le moteur n'a pas de probabilite offensive separee de la force
// continue existante, donc c'est elle qui porte l'effet, au meme endroit que l'avantage du
// terrain (avantageDomicile).
function multiplicateurPiete(val) {
  // 0 -> x0.9, 50 -> x1.0, 100 -> x1.1
  return 0.9 + ((val || 50) / 100) * 0.2;
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

// =====================================================================
// FOOTBALL LIVE (chantier "match reel 30 minutes", 28 aout 2026)
// =====================================================================
// Architecture : AUCUNE nouvelle table/colonne/RPC. Tout vit dans le meme document unique
// championnat.data (jsonb, une seule ligne id=1) deja utilise par le systeme existant -- un
// sous-objet `live` est ajoute a chaque match, additif et retro-compatible (les anciens matchs
// joues avant ce chantier n'ont jamais ce champ et continuent de se lire exactement comme avant,
// via played/scoreHome/scoreAway/recit/evenements/compositions, inchanges).
//
// Concurrence : plusieurs clients peuvent executer ce moteur simultanement (meme principe que
// l'ancien verifierEtJouerJournees). Toute ecriture passe par ecrireChampionnatCAS, un
// compare-and-swap PostgREST natif (PATCH conditionne sur l'updated_at lu au debut du tick) --
// si un autre client a deja ecrit entre-temps, la condition ne correspond plus a aucune ligne,
// PostgREST renvoie un tableau vide (aucune ligne modifiee), et CE client abandonne son tick sans
// avoir rien persiste. Les effets de bord EXTERNES (salaire, popularite, blessure reelle, mail --
// tout ce qui touche une autre table que championnat) ne sont JAMAIS appliques avant d'avoir
// remporte ce compare-and-swap : ils sont d'abord decides localement (phase pure), puis
// uniquement executes APRES un CAS gagnant (phase d'effets). Un tick perdant n'a donc RIEN
// applique nulle part, jamais de salaire/popularite/blessure en double, jamais de mail en double.
//
// Non-anticipation : aucun evenement futur n'est jamais precalcule puis simplement cache/differe.
// Seuls forceHome/forceAway (un TAUX, deja reconstituable a partir de donnees publiques -- stats
// des titulaires, indices de ville) sont fixes a la composition figee ; le nombre, l'instant et
// l'auteur de chaque but/action/blessure sont tires minute par minute, uniquement au moment ou
// cette minute est effectivement atteinte par l'horloge reelle (voir avancerEvenementsJusqua).
// =====================================================================

const HEURE_MATCH = 20; // Coup d'envoi fixe a 20h00 (heure de jeu), calendrier existant inchange.
const DUREE_ECHAUFFEMENT_MS = 5 * 60000;
const DUREE_MT1_MS = 10 * 60000;
const DUREE_PAUSE_MS = 5 * 60000;
const DUREE_MT2_MS = 10 * 60000;
const TAUX_BLESSURE_PAR_TITULAIRE = 0.08; // identique au taux historique (notifierCompositionsEtBlessures)

function calculerKickoffJournee(saison, numeroJournee) {
  const debut = new Date(saison.dateDebut);
  const d = new Date(debut.getTime() + (numeroJournee - 1) * 7 * 86400000);
  d.setHours(HEURE_MATCH, 0, 0, 0);
  return d;
}

// Pure fonction du temps reel ecoule depuis kickoffAt -- jamais dependante d'un etat client.
// echauffement [-5,0) -> mt1 [0,10) (minutes fictives 0->45) -> mitemps [10,15) -> mt2 [15,25)
// (minutes fictives 45->90) -> termine [25,+inf).
function phaseMatchActuelle(kickoffAt, maintenant) {
  const t = maintenant.getTime() - kickoffAt.getTime();
  if (t < -DUREE_ECHAUFFEMENT_MS) return { statut: 'a_venir', minuteFictive: null };
  if (t < 0) return { statut: 'echauffement', minuteFictive: null };
  if (t < DUREE_MT1_MS) return { statut: 'mt1', minuteFictive: Math.min(45, Math.floor((t / DUREE_MT1_MS) * 45)) };
  if (t < DUREE_MT1_MS + DUREE_PAUSE_MS) return { statut: 'mitemps', minuteFictive: 45 };
  if (t < DUREE_MT1_MS + DUREE_PAUSE_MS + DUREE_MT2_MS) {
    const t2 = t - DUREE_MT1_MS - DUREE_PAUSE_MS;
    return { statut: 'mt2', minuteFictive: 45 + Math.min(45, Math.floor((t2 / DUREE_MT2_MS) * 45)) };
  }
  return { statut: 'termine', minuteFictive: 90 };
}

function finPrevueMatch(kickoffAt) {
  return new Date(kickoffAt.getTime() + DUREE_MT1_MS + DUREE_PAUSE_MS + DUREE_MT2_MS);
}

// Tirage pondere generique. pool = [{item, poids}], poids > 0. Renvoie null si pool vide (jamais
// d'invention de faux joueur -- l'appelant doit alors se rabattre sur club.vedettes).
function tirerPondere(pool) {
  if (!pool || pool.length === 0) return null;
  const total = pool.reduce((s, p) => s + p.poids, 0);
  if (total <= 0) return pool[Math.floor(Math.random() * pool.length)].item;
  let r = Math.random() * total;
  for (const p of pool) { r -= p.poids; if (r <= 0) return p.item; }
  return pool[pool.length - 1].item;
}

// Pondere par la stat pertinente + un leger effet Endurance (plus marque en seconde periode,
// regle validee : "Endurance peut notamment conserver davantage d'influence en seconde periode").
// titulaires : tableau {nom, perf:{defense,technique,endurance}} (compositionFigee.home/away.titulaires).
function poolPondereeParStat(titulaires, statKey, phase) {
  return (titulaires || []).map(t => {
    const perf = t.perf || {};
    let poids = 1 + (perf[statKey] || 0);
    poids *= phase === 'mt2' ? (1 + (perf.endurance || 0) / 50) : (1 + (perf.endurance || 0) / 150);
    return { item: t.nom, poids };
  });
}

const TEMPLATES_COULEUR_LIVE = [
  { type: 'occasion', offensif: true,  texte: (c) => `Frappe cadrée de ${c}, à côté !` },
  { type: 'occasion', offensif: true,  texte: (c) => `Grosse occasion pour ${c}, seul(e) face au gardien !` },
  { type: 'occasion', offensif: true,  texte: (c) => `Corner obtenu par ${c}, dangereux.` },
  { type: 'carton',   offensif: false, texte: (c) => `Carton jaune pour ${c}.` },
  { type: 'action',   offensif: false, texte: (c) => `Bel arrêt du gardien devant ${c}.` },
  { type: 'action',   offensif: false, texte: (c) => `Interception décisive de ${c}.` },
  { type: 'action',   offensif: false, texte: (c) => `Tacle appuyé de ${c}, l'arbitre laisse jouer.` },
  { type: 'action',   offensif: false, texte: (c) => `Faute sifflée contre ${c}.` }
];

function genererBut(live, cote, club, titulaires, minute, phase) {
  const buteur = tirerPondere(poolPondereeParStat(titulaires, 'technique', phase))
    || club.vedettes[Math.floor(Math.random() * club.vedettes.length)];
  if (cote === 'home') live.scoreHome++; else live.scoreAway++;
  live.evenements.push({
    minute, atRealTime: new Date().toISOString(), type: 'but', club: cote, joueur: buteur,
    texte: 'BUT ! ' + buteur + ' fait trembler les filets pour ' + club.nom + ' ! (' + live.scoreHome + '-' + live.scoreAway + ')'
  });
}

function genererEvenementCouleurLive(live, clubHome, clubAway, titHome, titAway, minute, phase) {
  const cote = Math.random() < 0.5 ? 'home' : 'away';
  const club = cote === 'home' ? clubHome : clubAway;
  const titulaires = cote === 'home' ? titHome : titAway;
  const tpl = TEMPLATES_COULEUR_LIVE[Math.floor(Math.random() * TEMPLATES_COULEUR_LIVE.length)];
  const statKey = tpl.offensif ? 'technique' : 'defense';
  const joueur = tirerPondere(poolPondereeParStat(titulaires, statKey, phase))
    || club.vedettes[Math.floor(Math.random() * club.vedettes.length)];
  live.evenements.push({ minute, atRealTime: new Date().toISOString(), type: tpl.type, club: cote, joueur, texte: tpl.texte(joueur) });
}

// Meme taux agrege que l'ancien systeme post-match (8% par titulaire, reparti ici minute par
// minute sur les 90 minutes fictives) -- meme repartition grave/legere, meme duree, memes PV.
// PURE : ne mute jamais personnages directement. La blessure decidee est deposee comme un
// "effet en attente" (live.effetsRestants) plutot qu'appliquee en ligne -- voir
// appliquerEffetRestant/drainerEffetsRestants, qui garantissent qu'elle sera appliquee
// EXACTEMENT une fois meme si le client qui gagne le CAS de ce tick disparait avant d'avoir pu
// l'appliquer (correctif du 28 aout 2026, cf. entete "REPRISE POST-CAS" plus bas).
function tenterBlessureLive(live, cote, club, titulaires, minute) {
  if (!titulaires || titulaires.length === 0) return; // aucun PJ reel titulaire -> pas de blessure reelle possible
  const proba = (TAUX_BLESSURE_PAR_TITULAIRE * titulaires.length) / 90;
  if (Math.random() >= proba) return;
  const joueur = titulaires[Math.floor(Math.random() * titulaires.length)].nom;
  const grave = Math.random() < 0.3;
  const duree = grave ? (7 + Math.floor(Math.random() * 4)) : (2 + Math.floor(Math.random() * 2));
  const degatsPV = grave ? 30 : 15;
  live.evenements.push({
    minute, atRealTime: new Date().toISOString(), type: 'blessure', club: cote, joueur,
    texte: '⚠️ ' + joueur + ' se blesse (' + (grave ? 'gravement' : 'légèrement') + ') et doit sortir.'
  });
  const detail = { joueur, grave, duree, degatsPV, minute };
  if (!live.blessures) live.blessures = [];
  live.blessures.push(detail);
  if (!live.effetsRestants) live.effetsRestants = [];
  live.effetsRestants.push({
    id: 'blessure-' + joueur + '-' + minute + '-' + Date.now() + '-' + Math.floor(Math.random() * 1e6),
    type: 'blessure', joueur, blessure: { jusquauJour: (state.day || 1) + duree, gravite: grave ? 'grave' : 'legere' }, degatsPV
  });
}

// Genere, de facon purement synchrone, tous les evenements dus entre live.minuteGeneree (exclu)
// et minuteCible (inclus) -- boucle bornee a 90 iterations au pire, aucun cout reseau. Rien n'est
// jamais genere pour une minute non encore atteinte par l'horloge reelle (voir phaseMatchActuelle) :
// meme lors d'un rattrapage tardif (client revenu apres la fin du match), les evenements des
// minutes intermediaires sont tires ICI, au moment du rattrapage -- jamais pre-decides avant.
// =====================================================================
// TRIBUNES ACTIVES (chantier "supporters", 28 aout 2026)
// =====================================================================
// Choix de camp : PERSISTANT pour un match donne (live.supportersChoix[nom] = 'home'|'away'|
// 'neutre'), ecrit une seule fois via CAS (choisirCampSupporter), jamais modifiable ensuite --
// aucun mecanisme de changement de camp n'existe. Presence ACTIVE : jamais persistee comme telle,
// toujours recalculee a la volee depuis le systeme de presence deja existant du jeu
// (sbGetPresencesInRoom, rafraichi automatiquement toutes les 30s par tout client present --
// plateau-core.js). Un supporter ne compte donc que si les DEUX conditions sont vraies au moment
// du calcul : un choix de camp enregistre pour CE match, et une presence active dans le Stade/
// Terrain de la ville hote. Fermer la modale du live ne touche ni l'un ni l'autre.
// =====================================================================

// Ecrit le choix de camp d'UN joueur pour UN match, une seule fois (immuable ensuite). CAS avec
// quelques tentatives bornees -- action rare (une fois par joueur par match), aucune file
// d'attente necessaire contrairement au moteur de match lui-meme.
async function choisirCampSupporter(journeeNumero, matchIdx, choix) {
  const nom = state.char?.name;
  if (!nom) return false;
  for (let tentative = 0; tentative < 5; tentative++) {
    const charge = await chargerChampionnatAvecVersion();
    if (!charge) return false;
    const { saison, version } = charge;
    const journee = saison.calendrier.find(j => j.numero === journeeNumero);
    const m = journee?.matchs?.[matchIdx];
    if (!m || !m.live || m.played) return false;
    if (!m.live.supportersChoix) m.live.supportersChoix = {};
    if (m.live.supportersChoix[nom]) return true; // deja choisi pour ce match -- immuable, rien a faire
    m.live.supportersChoix[nom] = choix;
    const cas = await ecrireChampionnatCAS(saison, version);
    if (cas.ok) return true;
    // course perdue -- retente sur l'etat frais (un autre client a ecrit entre-temps)
  }
  return false;
}

// Effectif ACTIF de chaque camp a l'instant present : choix persistant ET presence active ET
// jamais un titulaire (deja engage sportivement, section 12 -- pas de double comptage). Une seule
// lecture reseau (presence), reutilisable pour le calcul du bonus ET pour l'affichage (compteurs +
// noms, jamais la formule -- voir rendu du live).
async function compterSupportersActifs(clubHome, clubAway, live) {
  const vide = { home: { count: 0, noms: [] }, away: { count: 0, noms: [] } };
  if (!live?.supportersChoix || typeof sbGetPresencesInRoom !== 'function') return vide;
  const presents = await sbGetPresencesInRoom(clubHome.country, clubHome.city, clubHome.stadeBuilding || 'stade', 'terrain').catch(() => []);
  const nomsPresents = new Set((presents || []).map(p => p.name));
  const titulaires = new Set([
    ...((live.compositionFigee?.home?.titulaires || []).map(t => t.nom)),
    ...((live.compositionFigee?.away?.titulaires || []).map(t => t.nom))
  ]);
  const homeNoms = [], awayNoms = [];
  for (const [nom, choix] of Object.entries(live.supportersChoix)) {
    if (!nomsPresents.has(nom) || titulaires.has(nom)) continue;
    if (choix === 'home') homeNoms.push(nom);
    else if (choix === 'away') awayNoms.push(nom);
  }
  return { home: { count: homeNoms.length, noms: homeNoms }, away: { count: awayNoms.length, noms: awayNoms } };
}

// Ecart GLOBAL maximal entre les deux equipes (regle validee) : D = supporters domicile -
// exterieur, impactGlobal = 5*tanh(D/6) -- D=0 -> 0, D=5 -> ~3.4, D=10 -> ~4.7, jamais plus de 5.
// Positif favorise le domicile. Correctif du 28 aout 2026 : appliquer +impactGlobal a domicile ET
// -impactGlobal a l'exterieur DOUBLE l'ecart reel (jusqu'a ~9.4 a D=10 au lieu du plafond de 5
// specifie) -- l'appelant (avancerEvenementsJusqua) doit repartir la moitie de cette valeur de
// chaque cote pour que l'ECART TOTAL entre les deux equipes reste plafonne a ~5, jamais chaque
// cote individuellement. Repli sans Math.tanh (deja standard, mais defensif).
function bonusTribunes(countHome, countAway) {
  const d = countHome - countAway;
  const t = (typeof Math.tanh === 'function') ? Math.tanh(d / 6) : (Math.exp(d / 3) - 1) / (Math.exp(d / 3) + 1);
  return 5 * t;
}

function avancerEvenementsJusqua(live, clubHome, clubAway, minuteCible, impactGlobalTribunes) {
  const titHome = live.compositionFigee.home.titulaires;
  const titAway = live.compositionFigee.away.titulaires;
  // Bonus tribunes (deja calcule pour cet appel, voir progresserMatchLive) applique au TAUX,
  // jamais retroactivement : seuls les evenements generes a partir de maintenant en tiennent
  // compte -- ceux deja dans live.evenements restent inchanges. La MOITIE de l'ecart global est
  // appliquee de chaque cote (+ a domicile, - a l'exterieur) afin que l'ECART TOTAL entre les deux
  // equipes reste plafonne a la valeur calibree (~5), jamais le double.
  const b = (impactGlobalTribunes || 0) / 2;
  const tauxButHome = Math.max(0, (live.forceHome || 0) + b) / 28; // meme formule que l'ancien simulerMatch (buts = round(force/28 + bruit))
  const tauxButAway = Math.max(0, (live.forceAway || 0) - b) / 28;
  while (live.minuteGeneree < minuteCible) {
    live.minuteGeneree++;
    const m = live.minuteGeneree;
    if (m === 45) continue; // la mi-temps a son propre evenement dedie, pas de tir a la 45e minute pile
    const phase = m <= 45 ? 'mt1' : 'mt2';
    if (Math.random() < tauxButHome / 90) genererBut(live, 'home', clubHome, titHome, m, phase);
    if (Math.random() < tauxButAway / 90) genererBut(live, 'away', clubAway, titAway, m, phase);
    if (Math.random() < 0.12) genererEvenementCouleurLive(live, clubHome, clubAway, titHome, titAway, m, phase);
    tenterBlessureLive(live, 'home', clubHome, titHome, m);
    tenterBlessureLive(live, 'away', clubAway, titAway, m);
  }
}

// Fait progresser UN match vers la phase cible (phaseInfo, deja calculee depuis l'horloge reelle).
// Phase PURE cote effets externes (les blessures decidees sont deposees dans live.effetsRestants,
// jamais appliquees ici) -- la seule chose "impure" ici est la lecture (jamais l'ecriture) de sbListJoueursLicencies
// via calculerContributionEquipe, au moment de la composition figee. Renvoie true si `match.live`
// a ete modifie (donc s'il faut tenter une ecriture).
async function progresserMatchLive(clubHome, clubAway, match, kickoff, phaseInfo) {
  if (!match.live) {
    match.live = {
      kickoffAt: kickoff.toISOString(), statut: 'a_venir', compositionFigee: null,
      forceHome: null, forceAway: null, scoreHome: 0, scoreAway: 0, minuteGeneree: 0,
      evenements: [], blessures: [], effetsRestants: [], supportersChoix: {}
    };
  }
  const live = match.live;
  const maintenant = new Date().toISOString();
  let modifie = false;

  // Composition figee UNE SEULE FOIS, des que l'echauffement (ou une phase ulterieure atteinte
  // directement, ex. rattrapage tardif) est constate.
  if (!live.compositionFigee && phaseInfo.statut !== 'a_venir') {
    const [contribHome, contribAway] = await Promise.all([calculerContributionEquipe(clubHome), calculerContributionEquipe(clubAway)]);
    live.compositionFigee = {
      home: { titulaires: contribHome.titulaires.map(t => ({ nom: t.nom, perf: t.perf })), remplacants: contribHome.remplacants.map(t => t.nom) },
      away: { titulaires: contribAway.titulaires.map(t => ({ nom: t.nom, perf: t.perf })), remplacants: contribAway.remplacants.map(t => t.nom) }
    };
    const avantageDomicile = match.boycotte ? -5 : 5;
    const pieteHome = typeof getIndiceVille === 'function' ? getIndiceVille(clubHome.country, clubHome.city, 'piete') : 50;
    const pieteAway = typeof getIndiceVille === 'function' ? getIndiceVille(clubAway.country, clubAway.city, 'piete') : 50;
    live.forceHome = (clubHome.valeurBase + avantageDomicile + contribHome.bonus) * multiplicateurPiete(pieteHome);
    live.forceAway = (clubAway.valeurBase + contribAway.bonus) * multiplicateurPiete(pieteAway);
    live.statut = 'echauffement';
    live.evenements.push({
      minute: 0, atRealTime: maintenant, type: 'composition', club: null, joueur: null,
      texte: 'Compositions officielles : ' + clubHome.nom + ' vs ' + clubAway.nom + '.'
    });
    modifie = true;
  }
  if (!live.compositionFigee) return modifie; // trop tot (a_venir)
  if (!live.supportersChoix) live.supportersChoix = {}; // retro-compat : matchs deja commences avant ce chantier

  const ordre = ['echauffement', 'mt1', 'mitemps', 'mt2', 'termine'];
  const idxCible = ordre.indexOf(phaseInfo.statut === 'a_venir' ? 'echauffement' : phaseInfo.statut);

  if (live.statut === 'echauffement' && idxCible >= ordre.indexOf('mt1')) {
    live.evenements.push({ minute: 0, atRealTime: maintenant, type: 'debut', club: null, joueur: null, texte: "Coup d'envoi !" });
    live.statut = 'mt1';
    modifie = true;
  }
  // Effectifs des tribunes releves juste avant CHAQUE generation d'evenements (pas de precision a
  // la milliseconde requise, section 19 -- mais recalcule separement pour mt1 et pour mt2 au cas
  // ou les deux transitions seraient rattrapees dans le meme appel, pour ne jamais utiliser un
  // effectif perime). Aucun evenement sportif pendant l'echauffement/la mi-temps, donc aucun
  // bonus a calculer a ces moments (section 5).
  if (live.statut === 'mt1') {
    const minuteCible = idxCible >= ordre.indexOf('mitemps') ? 45 : (phaseInfo.minuteFictive || 0);
    if (minuteCible > live.minuteGeneree) {
      const supportersActuels = await compterSupportersActifs(clubHome, clubAway, live);
      avancerEvenementsJusqua(live, clubHome, clubAway, minuteCible, bonusTribunes(supportersActuels.home.count, supportersActuels.away.count));
      modifie = true;
    }
    if (idxCible >= ordre.indexOf('mitemps')) {
      live.evenements.push({
        minute: 45, atRealTime: maintenant, type: 'mitemps', club: null, joueur: null,
        texte: 'Mi-temps : ' + clubHome.nom + ' ' + live.scoreHome + ' - ' + live.scoreAway + ' ' + clubAway.nom
      });
      live.statut = 'mitemps';
      modifie = true;
    }
  }
  if (live.statut === 'mitemps' && idxCible >= ordre.indexOf('mt2')) {
    live.evenements.push({ minute: 45, atRealTime: maintenant, type: 'reprise', club: null, joueur: null, texte: 'Coup d\'envoi de la seconde période !' });
    live.statut = 'mt2';
    modifie = true;
  }
  if (live.statut === 'mt2') {
    const minuteCible = idxCible >= ordre.indexOf('termine') ? 90 : (phaseInfo.minuteFictive || 45);
    if (minuteCible > live.minuteGeneree) {
      const supportersActuels = await compterSupportersActifs(clubHome, clubAway, live);
      avancerEvenementsJusqua(live, clubHome, clubAway, minuteCible, bonusTribunes(supportersActuels.home.count, supportersActuels.away.count));
      modifie = true;
    }
    if (idxCible >= ordre.indexOf('termine')) {
      live.statut = 'termine';
      live.evenements.push({
        minute: 90, atRealTime: maintenant, type: 'fin', club: null, joueur: null,
        texte: 'Coup de sifflet final ! ' + clubHome.nom + ' ' + live.scoreHome + ' - ' + live.scoreAway + ' ' + clubAway.nom + '.'
      });
      modifie = true;
    }
  }
  return modifie;
}

// =====================================================================
// REPRISE POST-CAS (correctif du 28 aout 2026)
// =====================================================================
// Probleme corrige : gagner le CAS de finalisation (m.played devient true, persiste) puis
// disparaitre (crash/refresh/perte reseau) AVANT d'avoir fini d'appliquer les effets externes
// (salaire/POP/blessure/mail, plusieurs dizaines d'appels sequentiels) laissait ces effets
// DEFINITIVEMENT perdus : m.played bloque toute nouvelle tentative de finalisation, donc plus
// personne ne rappelait jamais la fonction qui les appliquait.
//
// Correction : chaque effet individuel (une recompense de titulaire/remplacant, un credit de
// caisse de club, une blessure reelle) devient un ELEMENT PERSISTE dans live.effetsRestants
// (construit pendant la phase PURE, donc ecrit par le MEME CAS qui pose played:true -- jamais
// perdu). Son application se fait ensuite par petites revendications independantes : on relit
// l'etat frais, on retire CET ELEMENT PRECIS de la liste (CAS), et seulement APRES avoir gagne
// CE CAS localise-t-on l'effet externe correspondant. Un crash au milieu ne peut donc jamais
// faire perdre plus qu'UN SEUL element (deja retire de la liste mais pas encore applique a
// l'exterieur) -- fenetre de quelques centaines de ms par element, du meme ordre que le residu
// deja accepte pour la persistance du PA (autosave debounce). drainerEffetsRestants est rappelee
// a CHAQUE tick (voir avancerFootballLive), meme quand rien d'autre ne change ce tick-la : elle
// reprend donc automatiquement tout effet laisse en attente par un client disparu, sans action du
// joueur, sans mecanique de gameplay nouvelle.
// =====================================================================

// PURE : construit la liste des effets dus a la fin d'un match (jamais d'appel reseau externe
// autre que des LECTURES -- chargerBudgetClub). Appelee dans la phase pure d'avancerFootballLive,
// AVANT le CAS, pour que la liste soit ecrite atomiquement avec played:true.
async function construireEffetsRestantsMatch(match, clubHome, clubAway) {
  const live = match.live;
  const victoireHome = live.scoreHome > live.scoreAway;
  const victoireAway = live.scoreAway > live.scoreHome;
  const nul = live.scoreHome === live.scoreAway;
  const budgetHome = await chargerBudgetClub(clubHome.id);
  const budgetAway = await chargerBudgetClub(clubAway.id);
  const items = [];
  const uid = () => Date.now() + '-' + Math.floor(Math.random() * 1e6);

  function ajouterCote(club, compo, victoire, budget) {
    const salaires = budget.salaires;
    const resultatLabel = victoire ? 'victoire' : (nul ? 'match nul' : 'défaite');
    const gainPop = victoire ? 30 : 20; // regle validee : +20 pour avoir dispute le match (defaite/nul), +30 au total si victoire (jamais +20 puis +30)
    let totalSalaires = 0;
    for (const t of compo.titulaires) {
      const montant = salaires.titulaire + (victoire ? salaires.primeVictoire : 0);
      const blessureJoueur = (live.blessures || []).find(b => b.joueur === t.nom);
      const msgBlessure = blessureJoueur
        ? '<br><br>⚠️ Vous vous êtes blessé(e) pendant le match (' + (blessureJoueur.grave ? 'gravement' : 'légèrement') + '). Indisponible ' + blessureJoueur.duree + ' jour(s), -' + blessureJoueur.degatsPV + ' PV.'
        : '';
      items.push({
        id: 'recomp-' + t.nom + '-' + uid(), type: 'recompense', nom: t.nom, montant, gainPop,
        sujet: 'Vous étiez titulaire — ' + club.nom,
        corps: 'Vous avez disputé le match (' + resultatLabel + ', ' + live.scoreHome + '-' + live.scoreAway + '). Salaire perçu : ' + montant.toLocaleString('fr-FR') + ' FR. +' + gainPop + ' Popularité.' + msgBlessure
      });
      totalSalaires += montant;
    }
    for (const nomRemp of compo.remplacants) {
      items.push({
        id: 'recomp-' + nomRemp + '-' + uid(), type: 'recompense', nom: nomRemp, montant: salaires.remplacant, gainPop: 0,
        sujet: 'Vous étiez remplaçant — ' + club.nom,
        corps: 'Vous étiez remplaçant(e) lors du dernier match (' + live.scoreHome + '-' + live.scoreAway + '). Salaire perçu : ' + salaires.remplacant.toLocaleString('fr-FR') + ' FR.'
      });
      totalSalaires += salaires.remplacant;
    }
    if (totalSalaires > 0) items.push({ id: 'budget-' + club.id + '-' + uid(), type: 'budget_club', clubId: club.id, montant: totalSalaires, motif: 'Salaires des joueurs (' + resultatLabel + ')' });
  }

  ajouterCote(clubHome, live.compositionFigee.home, victoireHome, budgetHome);
  ajouterCote(clubAway, live.compositionFigee.away, victoireAway, budgetAway);
  if (!live.effetsRestants) live.effetsRestants = [];
  live.effetsRestants.push(...items);
}

// Applique UN effet externe deja revendique (retire de la liste par un CAS gagnant -- voir
// drainerEffetsRestants). Jamais appelee avant cette revendication.
async function appliquerEffetRestant(item) {
  if (item.type === 'blessure') {
    if (typeof sbAppliquerBlessureSportive === 'function') await sbAppliquerBlessureSportive(item.joueur, item.blessure, item.degatsPV).catch(() => {});
    return;
  }
  if (item.type === 'recompense') {
    if (item.montant > 0 && typeof sbAppliquerSalaire === 'function') await sbAppliquerSalaire(item.nom, item.montant).catch(() => {});
    if (item.gainPop && typeof sbAjusterPopularite === 'function') await sbAjusterPopularite(item.nom, item.gainPop).catch(() => {});
    if (typeof sbSendMail === 'function') await sbSendMail('Ligue Officielle', item.nom, item.sujet, item.corps, formatDateHeureJeu()).catch(() => {});
    return;
  }
  if (item.type === 'budget_club') {
    if (typeof crediterBudgetClub === 'function') await crediterBudgetClub(item.clubId, -item.montant, item.motif).catch(() => {});
    return;
  }
}

// Localise, dans une saison DEJA CHARGEE, le tout premier effet en attente (n'importe quel match,
// n'importe quelle journee -- couvre aussi bien le match qui vient d'etre finalise ce tick qu'un
// effet laisse en plan par un client disparu il y a plusieurs ticks).
function trouverProchainEffetRestant(saison) {
  for (const j of saison.calendrier) {
    for (let i = 0; i < j.matchs.length; i++) {
      const m = j.matchs[i];
      if (m.live?.effetsRestants?.length) return { journeeNumero: j.numero, matchIdx: i, item: m.live.effetsRestants[0] };
    }
  }
  return null;
}

// Revendique puis applique, un par un, jusqu'a maxItems effets en attente. Chaque iteration relit
// l'etat frais (un autre client a pu progresser entre-temps), ce qui rend la fonction sure a
// rappeler depuis n'importe quel tick, par n'importe quel client, aussi souvent que necessaire.
async function drainerEffetsRestants(maxItems) {
  let traites = 0;
  while (traites < maxItems) {
    const charge = await chargerChampionnatAvecVersion();
    if (!charge) break;
    const { saison, version } = charge;
    const cible = trouverProchainEffetRestant(saison);
    if (!cible) break;
    const journee = saison.calendrier.find(j => j.numero === cible.journeeNumero);
    const m = journee.matchs[cible.matchIdx];
    m.live.effetsRestants = m.live.effetsRestants.filter(it => it.id !== cible.item.id);
    const cas = await ecrireChampionnatCAS(saison, version);
    if (!cas.ok) continue; // un autre client vient d'ecrire -- retente immediatement sur l'etat frais
    await appliquerEffetRestant(cible.item);
    traites++;
  }
  return traites;
}

async function chargerChampionnatAvecVersion() {
  const rows = await sbGet('championnat', 'id=eq.1').catch(() => null);
  if (!rows || !rows.length) return null;
  return { saison: rows[0].data, version: rows[0].updated_at };
}

// Compare-and-swap PostgREST natif : PATCH conditionne sur l'updated_at lu au debut du tick.
// Si un autre client a ecrit entre-temps, la clause WHERE ne correspond plus a aucune ligne --
// PostgREST (Prefer: return=representation) renvoie alors un tableau VIDE, jamais une erreur.
async function ecrireChampionnatCAS(saison, versionAttendue) {
  const nouvelleVersion = new Date().toISOString();
  const res = await sbUpdate('championnat', 'id=eq.1&updated_at=eq.' + encodeURIComponent(versionAttendue), { data: saison, updated_at: nouvelleVersion }).catch(() => null);
  return (res && res.length > 0) ? { ok: true } : { ok: false };
}

// Point d'entree unique du moteur live regulier (journee courante uniquement -- les playoffs
// restent geres a l'identique par jouerMatchsTour/progresserPlayoffs, hors perimetre de ce
// chantier, voir rapport final). Idempotent, rejouable par n'importe quel client, aussi souvent
// que necessaire : deux phases strictement separees (PURE puis EFFETS), voir commentaire d'entete.
async function avancerFootballLive() {
  const charge = await chargerChampionnatAvecVersion();
  if (!charge || !charge.saison) return null;
  const { saison, version } = charge;
  if (saison.phase !== 'reguliere') return null;

  const prochaine = saison.calendrier.find(j => !j.matchs.every(m => m.played));
  if (!prochaine) return null;

  const kickoff = calculerKickoffJournee(saison, prochaine.numero);
  const phaseInfo = phaseMatchActuelle(kickoff, new Date());
  if (phaseInfo.statut === 'a_venir') return null;

  const finalisationsLegacy = [];
  let modifie = false;

  for (const m of prochaine.matchs) {
    if (m.played) continue;
    const clubHome = getClub(m.home), clubAway = getClub(m.away);

    // Interdiction ministerielle (systeme existant, genererDemandesManifestationMatchs) :
    // forfait immediat, prioritaire sur tout le pipeline live -- inchange par ce chantier.
    const demandeMatch = m.demandeManifId ? await sbGetDemandeManifestationParId(m.demandeManifId).catch(() => null) : null;
    if (demandeMatch?.statut === 'interdite') {
      Object.assign(m, { scoreHome: 0, scoreAway: 1, recit: 'Match interdit par le Ministère de l\'Intérieur — victoire par forfait de ' + clubAway.nom + ' (0-1).', evenements: [], played: true });
      modifie = true;
      if (typeof addExternalEvent === 'function') addExternalEvent('🚫 Le match ' + clubHome.nom + ' vs ' + clubAway.nom + ' est interdit par le Ministère de l\'Intérieur. Victoire par forfait de ' + clubAway.nom + '.');
      continue;
    }

    if (phaseInfo.statut === 'termine' && !m.live) {
      // Fenetre de 30 minutes entierement ecoulee sans qu'aucun client ne l'ait jamais tickee --
      // repli garanti sur l'ancienne resolution instantanee (aucun match ne reste jamais bloque).
      // Chemin historique, hors perimetre du correctif "reprise post-CAS" (voir rapport).
      const [contribHome, contribAway] = await Promise.all([calculerContributionEquipe(clubHome), calculerContributionEquipe(clubAway)]);
      const res = simulerMatch(m.home, m.away, contribHome.bonus, contribAway.bonus, m.boycotte);
      Object.assign(m, {
        scoreHome: res.scoreHome, scoreAway: res.scoreAway, recit: res.recit, evenements: res.evenements, played: true,
        compositions: {
          home: { titulaires: contribHome.titulaires.map(t => t.nom), remplacants: contribHome.remplacants.map(t => t.nom) },
          away: { titulaires: contribAway.titulaires.map(t => t.nom), remplacants: contribAway.remplacants.map(t => t.nom) }
        }
      });
      modifie = true;
      finalisationsLegacy.push({ club: clubHome, contrib: contribHome, butsPour: res.scoreHome, butsContre: res.scoreAway });
      finalisationsLegacy.push({ club: clubAway, contrib: contribAway, butsPour: res.scoreAway, butsContre: res.scoreHome });
      continue;
    }

    const chg = await progresserMatchLive(clubHome, clubAway, m, kickoff, phaseInfo);
    if (chg) modifie = true;
    if (m.live && m.live.statut === 'termine' && !m.played) {
      const home = clubHome, away = clubAway;
      const recit = m.live.scoreHome > m.live.scoreAway
        ? home.nom + ' s\'impose ' + m.live.scoreHome + '-' + m.live.scoreAway + ' face à ' + away.nom
        : (m.live.scoreAway > m.live.scoreHome
          ? away.nom + ' s\'impose ' + m.live.scoreAway + '-' + m.live.scoreHome + ' sur la pelouse de ' + home.nom
          : 'Match nul ' + m.live.scoreHome + '-' + m.live.scoreAway + ' entre ' + home.nom + ' et ' + away.nom);
      // Construit la liste des effets dus (PURE, lectures seules) AVANT le CAS -- voir
      // construireEffetsRestantsMatch : elle sera ainsi ecrite atomiquement avec played:true,
      // jamais perdue meme si ce client disparait juste apres avoir gagne le CAS ci-dessous.
      await construireEffetsRestantsMatch(m, clubHome, clubAway);
      Object.assign(m, {
        scoreHome: m.live.scoreHome, scoreAway: m.live.scoreAway, recit, evenements: m.live.evenements, played: true,
        compositions: {
          home: { titulaires: m.live.compositionFigee.home.titulaires.map(t => t.nom), remplacants: m.live.compositionFigee.home.remplacants },
          away: { titulaires: m.live.compositionFigee.away.titulaires.map(t => t.nom), remplacants: m.live.compositionFigee.away.remplacants }
        }
      });
    }
  }

  let casGagne = !modifie; // rien a revendiquer -> ne bloque pas la reprise ci-dessous
  if (modifie) {
    // Revendication (CAS) AVANT tout effet externe -- voir commentaire d'entete du chantier.
    const cas = await ecrireChampionnatCAS(saison, version);
    casGagne = cas.ok;
    if (cas.ok) {
      for (const f of finalisationsLegacy) {
        await notifierCompositionsEtBlessures(f.club, f.contrib, f.butsPour, f.butsContre).catch(() => {});
      }
      if (prochaine.matchs.every(m => m.played)) {
        await publierResultatsJourneeSurForum(saison.numero, prochaine).catch(() => {});
        await resoudreParisJournee(saison.numero, prochaine).catch(() => {});
      }
    }
    // course perdue (cas.ok===false) : un autre client a deja avance l'etat -- ne pas retenter
    // cette progression precise ici, mais NE JAMAIS sauter la reprise ci-dessous pour autant, elle
    // est independante de ce qui vient d'echouer.
  }

  // Reprise post-CAS (toujours tentee, meme si rien d'autre n'a change ce tick, meme si le CAS de
  // progression ci-dessus a ete perdu) : un client precedent a pu gagner un CAS de finalisation
  // puis disparaitre avant d'avoir applique tous les
  // effets externes dus (POP/salaire/blessure/mail) -- voir entete "REPRISE POST-CAS" plus haut.
  await drainerEffetsRestants(40);

  // saison n'est fiable a renvoyer que si CE client a reellement gagne l'ecriture de sa propre
  // progression (ou n'avait rien a ecrire) -- une course perdue laisse cette copie locale perimee.
  return casGagne ? saison : null;
}

// Determine, de facon SYNCHRONE, si `nomJoueur` est actuellement titulaire d'un match en fenetre
// [kickoff-5min, kickoff+25min] dans une saison DEJA CHARGEE (aucun appel reseau ici -- reserve a
// une consommation depuis un cache recent, voir rafraichirVerrouFootball/tickFootballLive).
function trouverVerrouMatchPourJoueur(saison, nomJoueur) {
  if (!saison || saison.phase !== 'reguliere' || !nomJoueur) return null;
  const maintenant = new Date();
  for (const j of saison.calendrier) {
    for (const m of j.matchs) {
      if (m.played || !m.live || !m.live.compositionFigee) continue;
      const kickoff = new Date(m.live.kickoffAt);
      const phaseInfo = phaseMatchActuelle(kickoff, maintenant);
      if (phaseInfo.statut === 'a_venir' || phaseInfo.statut === 'termine') continue;
      const estHome = m.live.compositionFigee.home.titulaires.some(t => t.nom === nomJoueur);
      const estAway = !estHome && m.live.compositionFigee.away.titulaires.some(t => t.nom === nomJoueur);
      if (!estHome && !estAway) continue;
      const club = getClub(estHome ? m.home : m.away);
      const adversaire = getClub(estHome ? m.away : m.home);
      return { matchKey: j.numero + '-' + m.home + '-' + m.away, journeeNumero: j.numero, matchIdx: j.matchs.indexOf(m),
        club, adversaire, kickoffAt: kickoff, finPrevue: finPrevueMatch(kickoff), statutPhase: phaseInfo.statut };
    }
  }
  return null;
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

// Moyenne de groupe (9 aout 2026) : valeurs disponibles pour <stat> parmi le joueur + ses
// employes actuellement inGroupe (meme perimetre que rejoindreJeremy/quitterJeremy/
// organiser_blocus, PAS state.group.members qui est un mecanisme distinct pour rejoindre
// le groupe d'un AUTRE joueur/PNJ). Un employe sans valeur pour cette stat precise (les PNJ
// n'ont que FOR/CHA/DUP/INT via PNJ_STATS_PAR_JOB, jamais VOL/ENT, sauf override explicite
// comme le PER d'un informateur fixe a son recrutement) est simplement absent du tableau -
// ni compte ni traite comme 0, pour ne pas fausser la moyenne vers le bas artificiellement.
function getMembresGroupeAvecStat(stat) {
  const valeurs = [];
  const valeurJoueur = state.char?.stats?.[stat];
  if (valeurJoueur !== undefined && valeurJoueur !== null) valeurs.push(valeurJoueur);
  (typeof getEmployes === 'function' ? getEmployes() : (state.employes || []))
    .filter(e => e.inGroupe)
    .forEach(e => {
      const v = e.stats?.[stat] ?? (typeof PNJ_STATS_PAR_JOB !== 'undefined' ? PNJ_STATS_PAR_JOB[e.job]?.[stat] : undefined);
      if (v !== undefined && v !== null) valeurs.push(v);
    });
  return valeurs;
}

// Renvoie la valeur EFFECTIVE d'une caracteristique, en tenant compte de la moyenne de
// groupe (9 aout 2026 : remplace la simple valeur du joueur - un groupe bien compose peut
// faire monter le taux de reussite d'un ordre, un groupe mal compose peut le faire baisser),
// puis d'un eventuel bonus de formation temporaire (voir doSeFormer) et de l'affaiblissement
// lie aux HP. A utiliser partout ou une stat compte (CHA pour se defendre, etc.) au lieu de
// lire state.char.stats directement. Retrocompatible : joueur seul (aucun employe inGroupe)
// -> moyenne d'un seul element = sa propre valeur, comportement strictement identique a avant.
// Bonus ENT local (Lot 2, objets d'integration -- 23 aout 2026) : +1 non cumulable tant qu'au
// moins un objet familleProduitMarche:'integration_locale' de l'inventaire a
// bonusIntegrationVille === state.currentCity. Fonction independante (jamais fusionnee dans
// getStatEffective directement) : reutilisee telle quelle par l'affichage ENT (plateau-core.js)
// sans jamais entrainer la logique de moyenne de groupe -- seule getStatEffective doit tenir
// compte du groupe, pas ce bonus purement personnel. Relit l'inventaire a chaque appel, aucun
// etat mis en cache : deposer/donner/detruire l'objet fait donc disparaitre le bonus des le
// prochain appel, sans code supplementaire. Jamais d'ecriture dans state.char.stats.
function bonusEntIntegrationLocale() {
  return (state.inventory || []).some(i =>
    i && i.familleProduitMarche === 'integration_locale' && i.bonusIntegrationVille === state.currentCity
  ) ? 1 : 0;
}

function getStatEffective(stat) {
  const valeursGroupe = getMembresGroupeAvecStat(stat);
  const base = valeursGroupe.length > 0
    ? valeursGroupe.reduce((s, v) => s + v, 0) / valeursGroupe.length
    : (state.char?.stats?.[stat] ?? 8);
  const bonus = (state.char?.bonusFormation?.stat === stat) ? (state.char.bonusFormation.valeur || 0) : 0;
  // Bonus ENT local (Lot 2) : n'affecte QUE stat==='ENT', court-circuite avant tout appel a
  // bonusEntIntegrationLocale() pour les 5 autres caracteristiques -- comportement et cout
  // strictement inchanges pour tous les autres appelants de cette fonction.
  const bonusLocal = (stat === 'ENT') ? bonusEntIntegrationLocale() : 0;
  // Malus d'excommunication (lot "carriere religieuse Republia", lot 2, 26 aout 2026) : -2 CHA
  // reversible tant que state.char.excommunie est actif (personnages.excommunie, JSONB nullable).
  // N'affecte QUE CHA, meme doctrine que le bonus ENT local ci-dessus -- ne modifie jamais
  // state.char.stats.CHA (la caracteristique de base), disparait des la levee (excommunie remis
  // a null) sans aucune trace residuelle.
  const malusExcommunication = (stat === 'CHA' && state.char?.excommunie) ? -2 : 0;
  const valeurNormale = base + bonus + bonusLocal + malusExcommunication;
  if (state.statsAffaiblies && state.statsAffaiblies[stat] !== undefined) {
    const fraction = Math.max(0, Math.min(1, (state.hp || 0) / 100));
    return Math.max(1, Math.round(valeurNormale * fraction));
  }
  return Math.round(valeurNormale);
}

// SUIVRE UNE FORMATION (Universite, amphi) — bonus TEMPORAIRE (+2, jusqu'au prochain sommeil),
// max 1 formation par jour, cout 100 FR.
function doSeFormer(pa, cost) {
  if (state.char?.dernierFormationJour === state.day) {
    showToast('Déjà formé aujourd\'hui', 'Une seule formation par jour.', false);
    return;
  }
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  const stats = ['INT','CHA','VOL','PER','DUP','ENT'];
  document.getElementById('postes-modal-title').textContent = 'Suivre une formation';
  let html = '<div style="padding:1rem"><div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Choisir la caractéristique à booster pour la journée (+2, effet jusqu\'à votre prochain sommeil) :</div>';
  stats.forEach(s => {
    html += '<button onclick="appliquerFormation(\'' + s + '\',' + pa + ',' + cost + ')" style="display:block;width:100%;text-align:left;padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;color:#c0b090;cursor:pointer;font-family:Crimson Pro,serif;font-size:.85rem;margin-bottom:.3rem">' + s + ' (actuel : ' + getStatEffective(s) + ')</button>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function appliquerFormation(stat, pa, cost) {
  if (!state.char) return;
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }
  document.getElementById('modal-postes').classList.remove('open');
  state.char.dernierFormationJour = state.day;
  state.char.bonusFormation = { stat, valeur: 2 };
  sauvegarderPersonnageImmediat();
  updateUI();
  showToast('Formation terminée', '+2 ' + stat + ' jusqu\'à votre prochain sommeil.', true, true);
  addJournalEntry('Formation suivie à l\'université : +2 ' + stat + ' (temporaire).', 'event-good');
}

// STAGE A LA CASERNE (Corps de Garde) — regenere la Volonte, ouvert a tout PJ (pas reserve aux
// militaires). +5 VOL, 1 fois par jour, max 3 jours CONSECUTIFS puis 7 jours de repos avant de
// pouvoir recommencer. Rater un jour (pas de stage la veille) relance un nouveau cycle de 3 a
// zero, sans cooldown -- seule une serie ininterrompue de 3 jours declenche le repos force.
// PA/cout preleves via deduireCoutOrdre (Phase K, migre depuis une deduction hardcodee) : les
// handlers dedies (routes via un cas special de doOrder, voir plateau-router.js) ne beneficient
// PAS de la deduction generique de PA/cout, qui ne s'applique qu'aux ordres sans handler dedie.
async function doStageCaserne(pa, cost) {
  if (!state.char) return;
  const suivi = state.char.stageCaserne || {};

  if (suivi.cooldownJusqua && state.day < suivi.cooldownJusqua) {
    showToast('Repos obligatoire', 'Trois jours de stage d\'affilée, place au repos. Revenez au jour ' + suivi.cooldownJusqua + '.', false);
    return;
  }
  if (suivi.dernierJour === state.day) {
    showToast('Déjà fait aujourd\'hui', 'Un seul stage par jour.', false);
    return;
  }

  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', 'Il vous manque des PA pour ce stage.', false); return; }

  const streak = (suivi.dernierJour === state.day - 1) ? (suivi.streak || 0) + 1 : 1;

  if (!state.char.stats) state.char.stats = {};
  state.char.stats.VOL = (state.char.stats.VOL || 0) + 5;

  const nouveauSuivi = { dernierJour: state.day, streak };
  if (streak >= 3) {
    nouveauSuivi.streak = 0;
    nouveauSuivi.cooldownJusqua = state.day + 7;
  }
  state.char.stageCaserne = nouveauSuivi;

  if (typeof sauvegarderPersonnageImmediat === 'function') sauvegarderPersonnageImmediat();
  updateUI();
  showToast('Stage terminé !', '"Il faut le vouloir pour remonter sa Volonté !" — +5 Volonté.', true, true);
  addJournalEntry('Stage à la Caserne. +5 Volonté (' + streak + '/3 jours consécutifs).', 'event-good');
}

// RECRUTER DES MILITANTS (Universite, amphi) — conditionne a l'adhesion a un syndicat actif,
// 1 recrutement/jour, plafond de 2 militants par joueur. Prepare les futures manifestations.
async function doRecruterMilitants(pa, cost) {
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
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }
  const noms = ['Sacha Fervent', 'Lila Combattante', 'Noé Insurgé', 'Maya Debout', 'Théo Rebelle', 'Zoé Militante'];
  const nomPnj = noms[Math.floor(Math.random() * noms.length)] + ' (PNJ)';

  state.char.dernierRecrutementMilitant = state.day;
  sauvegarderPersonnageImmediat();
  if (typeof sbRecruterMilitant === 'function') {
    await sbRecruterMilitant(state.country, state.char?.name, nomPnj).catch(() => {});
  }
  // Comptabiliser le militant comme adherent du syndicat
  if (!syndicat.membres) syndicat.membres = [];
  syndicat.membres.push({ nom: nomPnj, grade: 'Militant (PNJ)', rejointLe: state.day || 1, estPnj: true, recruteur: state.char?.name });
  sauvegarderOrga(syndicat);
  updateUI();
  showToast('Militant recruté !', nomPnj + ' rejoint votre réseau (' + (mesMilitants.length + 1) + '/2).', true);
  addJournalEntry('Recrutement d\'un militant étudiant : ' + nomPnj + ' (syndicat : ' + syndicat.nom + ').', 'event-good');

  // Retour visuel immediat, SANS muter l'objet BUILDINGS global (partage par tous les
  // joueurs). La reapparition fiable et multi-session du militant est deja assuree par
  // enterRoom() (plateau-navigation.js), qui le recharge depuis Supabase a chaque entree
  // dans un batiment "universite". Ecrire ici en plus dans room.persons dupliquait cette
  // logique et laissait une entree fantome permanente, visible de tous, jamais nettoyee.
  const room = BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom];
  if (room && typeof renderPersonsList === 'function') {
    const apercu = [
      {
        name: nomPnj,
        role: 'Militant recruté (lié à ' + (state.char?.name || 'vous') + ')',
        rel: 'ally',
        job: 'militant'
      },
      ...(room.persons || [])
    ];
    renderPersonsList(apercu);
  }
}

// =====================
// BLOCUS SYNDICAL — reserve au Secretaire General et au Secretaire General Adjoint
// (gradeIdx 1 ou 2 sur la hierarchie syndicale republic ['Adherent','Secretaire General
// Adjoint','Secretaire General','Confederal']). Cible n'importe quel batiment (pas
// seulement les chantiers) : bloque les ordres legaux, favorise les illegaux, tant qu'un
// des deux leaders le renouvelle chaque jour. Delogeable par la police (doMobiliserPolice).
// =====================

// Puissance syndicale (0-100) : militants recrutes + demonstration de force en cours +
// palmares de blocus reussis + sympathie gagnee en cas de repression violente subie.
// Utilisee pour ameliorer les futurs blocus, et pour peser sur les indices de ville et la
// popularite du maire tant qu'un blocus est actif (voir cron serveur).
function calculerPuissanceSyndicale(syndicat, blocusActifQuelquePart) {
  if (!syndicat) return 0;
  const militants = (syndicat.membres || []).filter(m => m.estPnj).length;
  let puissance = militants * 3;
  if (blocusActifQuelquePart) puissance += 15;
  puissance += (syndicat.blocusReussis || 0) * 5;
  puissance += (syndicat.repressionsSubies || 0) * 8;
  return Math.max(0, Math.min(100, Math.round(puissance)));
}

function getMonSyndicatEtGrade() {
  const orgas = (typeof chargerOrgas === 'function') ? chargerOrgas() : (state.orgas || []);
  const syndicat = orgas.find(o => o.type === 'syndicale' && o.membres?.some(m => m.nom === state.char?.name));
  if (!syndicat) return null;
  const membre = syndicat.membres.find(m => m.nom === state.char?.name);
  return { syndicat, gradeIdx: membre?.gradeIdx ?? -1 };
}

async function doOrganiserBlocusSyndical() {
  const infos = getMonSyndicatEtGrade();
  if (!infos || infos.gradeIdx < 1 || infos.gradeIdx > 2) {
    showToast('Accès refusé', "Réservé au Secrétaire Général et au Secrétaire Général Adjoint d'un syndicat.", false);
    return;
  }
  const { syndicat } = infos;
  const militants = (syndicat.membres || []).filter(m => m.estPnj);
  if (militants.length < 2) {
    showToast('Effectifs insuffisants', 'Il faut au moins 2 militants recrutés pour organiser un blocus.', false);
    return;
  }

  const etatActuel = (typeof sbGetBatimentEtat === 'function') ? await sbGetBatimentEtat(state.country, state.currentCity, state.currentBuilding) : {};
  if (etatActuel?.blocus) {
    showToast('Déjà bloqué', 'Un blocus est déjà en cours ici.', false);
    return;
  }

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;margin-bottom:.6rem">Militants disponibles : ' + militants.length + '. Plus vous en mobilisez, plus le blocus a de chances de réussir et sera intense.</div>';
  html += '<input id="blocus-nb-militants" type="number" min="2" max="' + militants.length + '" value="' + militants.length + '" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-size:.85rem;margin-bottom:.6rem" />';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.4rem">REVENDICATION SYNDICALE</div>';
  html += '<textarea id="blocus-revendication" rows="2" placeholder="Ex: Contre la précarité des travailleurs du bâtiment..." style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-size:.82rem;box-sizing:border-box"></textarea>';
  html += '<button class="pnj-action-btn" onclick="confirmerOrganiserBlocus(\'' + syndicat.id + '\')" style="margin-top:.6rem">Organiser le blocus</button>';
  html += '</div>';

  document.getElementById('postes-modal-title').textContent = 'Organiser un blocus';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerOrganiserBlocus(syndicatId) {
  const nbMilitants = parseInt(document.getElementById('blocus-nb-militants')?.value || 2);
  const revendication = (document.getElementById('blocus-revendication')?.value || 'Revendications non précisées.').trim();

  const infos = getMonSyndicatEtGrade();
  const syndicat = infos?.syndicat;
  const puissance = calculerPuissanceSyndicale(syndicat, false);
  const taux = Math.min(90, 10 + nbMilitants * 6 + Math.round(puissance / 5)); // la puissance du syndicat facilite les futurs blocus
  const intensite = Math.min(90, 10 + nbMilitants * 6); // l'intensite reste liee aux seuls militants mobilises, pas au bonus de puissance

  const roll = Math.floor(Math.random() * 100) + 1;
  document.getElementById('modal-postes')?.classList.remove('open');

  if (roll > taux) {
    showToast('Blocus raté', 'Les militants n\'ont pas réussi à s\'organiser cette fois-ci.', false);
    addJournalEntry('Tentative de blocus syndical ratée.', 'event-bad');
    return;
  }

  // Palmares : chaque blocus reussi renforce durablement la puissance syndicale
  syndicat.blocusReussis = (syndicat.blocusReussis || 0) + 1;
  if (typeof sauvegarderOrga === 'function') sauvegarderOrga(syndicat);

  const patch = {
    blocus: {
      syndicatId: syndicatId,
      syndicatNom: syndicat?.nom || 'Syndicat',
      revendication: revendication,
      nbMilitants: nbMilitants,
      intensite: intensite,
      leaderActuel: state.char?.name,
      lanceLe: Date.now(),
      dernierRenouvellementTimestamp: Date.now() // horodatage reel, verifie par le cron (pas un numero de jour, peu fiable pour un calcul de duree ecoulee)
    }
  };
  if (typeof sbSetBatimentEtat === 'function') await sbSetBatimentEtat(state.country, state.currentCity, state.currentBuilding, patch).catch(() => {});

  updateUI();
  showToast('Blocus organisé !', 'Le bâtiment est maintenant bloqué. Renouvelez chaque jour pour le maintenir.', true, true);
  addJournalEntry('Blocus syndical organisé (' + nbMilitants + ' militants) : "' + revendication + '"', 'event-good');
  if (typeof addExternalEvent === 'function') {
    addExternalEvent('✊ Un blocus syndical a été organisé dans un bâtiment de la ville : "' + revendication + '"', 'local');
  }
}

async function doRenouvelerBlocusSyndical() {
  const infos = getMonSyndicatEtGrade();
  if (!infos || infos.gradeIdx < 1 || infos.gradeIdx > 2) {
    showToast('Accès refusé', "Réservé au Secrétaire Général et au Secrétaire Général Adjoint.", false);
    return;
  }
  const etatActuel = (typeof sbGetBatimentEtat === 'function') ? await sbGetBatimentEtat(state.country, state.currentCity, state.currentBuilding) : {};
  if (!etatActuel?.blocus) {
    showToast('Rien à renouveler', "Aucun blocus en cours ici.", false);
    return;
  }
  if (etatActuel.blocus.syndicatId !== infos.syndicat.id) {
    showToast('Impossible', "Ce blocus n'est pas celui de votre syndicat.", false);
    return;
  }

  const patch = { blocus: { ...etatActuel.blocus, dernierRenouvellementTimestamp: Date.now(), leaderActuel: state.char?.name } };
  if (typeof sbSetBatimentEtat === 'function') await sbSetBatimentEtat(state.country, state.currentCity, state.currentBuilding, patch).catch(() => {});

  showToast('Blocus renouvelé', 'Le blocus se poursuit pour au moins un jour de plus.', true);
  addJournalEntry('Blocus syndical renouvelé.', 'event-info');
}

// Verification a l'entree d'un batiment : met en cache l'etat du blocus (async, sur
// state.blocusActifIci) pour une lecture synchrone ulterieure par doOrder(), et affiche la
// popup si un blocus non encore tranche pour cette visite est actif.
async function verifierBlocusEntree(buildingId, roomId) {
  if (typeof sbGetBatimentEtat !== 'function') return;
  const etat = await sbGetBatimentEtat(state.country, state.currentCity, buildingId).catch(() => null);
  state.blocusActifIci = etat?.blocus || null;

  if (!state.blocusActifIci) return;
  if (state.blocusEntreeResolueBuildingId === buildingId) return; // deja tranche pour cette visite
  if (state.currentBuilding !== buildingId) return; // le joueur a change de piece entre temps

  afficherPopupBlocusEntree(buildingId);
}

function afficherPopupBlocusEntree(buildingId) {
  const b = state.blocusActifIci;
  if (!b) return;
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.85rem;color:#c0b090;margin-bottom:.6rem"><strong>' + (b.syndicatNom || 'Un syndicat') + '</strong> bloque l\'accès à ce bâtiment.</div>';
  html += '<div style="font-size:.82rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">"' + b.revendication + '"</div>';
  html += '<div style="font-size:.75rem;color:#6a5a30;margin-bottom:.8rem">Les démarches administratives sont bloquées ici. Les activités illégales y sont facilitées.</div>';
  html += '<div style="display:flex;gap:.5rem">';
  html += '<button class="pnj-action-btn" onclick="doForcerBlocus(\'' + buildingId + '\')">Forcer le passage</button>';
  html += '<button class="pnj-action-btn" onclick="sortirBatiment()" style="opacity:.8">Repartir</button>';
  html += '</div></div>';
  document.getElementById('postes-modal-title').textContent = 'Blocus en cours';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function doForcerBlocus(buildingId) {
  document.getElementById('modal-postes')?.classList.remove('open');
  // FOR fantome retire (bêta) : le joueur n'a jamais eu de FOR (toujours undefined, repli fixe
  // a 8) -- (forStat-10)*3 valait donc TOUJOURS -6, un malus constant et silencieux applique a
  // tous les joueurs sans exception. VOL est deja un second facteur reel de cette meme formule,
  // pas besoin d'une seconde caracteristique pour ce jet.
  const volStat = getStatEffective('VOL');
  const intensite = state.blocusActifIci?.intensite || 40;
  const taux = Math.max(5, Math.min(90, Math.round(40 + (volStat - 10) * 3 - intensite / 2)));
  const roll = Math.floor(Math.random() * 100) + 1;

  if (roll <= taux) {
    state.blocusEntreeResolueBuildingId = buildingId;
    state.blocusModificateurLegal = 20; // bonus applique aux ordres legaux pendant cette visite (compense en partie le malus du blocus)
    showToast('Passage forcé !', 'Vous entrez malgré le blocus.', true);
    addJournalEntry('Passage forcé à travers un blocus syndical.', 'event-good');
    if (typeof updateUI === 'function') updateUI();
  } else {
    showToast('Refoulé', 'Les militants vous repoussent.', false);
    addJournalEntry('Tentative de passage en force repoussée par des militants.', 'event-bad');
    if (typeof sortirBatiment === 'function') sortirBatiment();
  }
}

// SE RENSEIGNER (halls de Centre d'Affaires / Centre Commercial / Travées du Centre Artisanal)
// Liste les locaux du batiment courant : loue ou libre, et l'organisation domiciliee si elle
// n'est pas secrete (case cochee par le fondateur, ou type d'organisation secret par defaut).
function doSeRenseigner() {
  const b = BUILDINGS[state.currentBuilding];
  if (!b) return;
  const locaux = Object.entries(b.rooms || {}).filter(([, r]) => r.isLocationRoom);

  document.getElementById('postes-modal-title').textContent = 'Se renseigner';
  let html = '<div style="padding:1rem">';
  if (locaux.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Rien de particulier à signaler ici.</div>';
  } else {
    locaux.forEach(([roomId, room]) => {
      // Scope ville ajoute le 2026-08-16 (locations sans city toutes migrees)
      const location = (state.locationsActives || []).find(l =>
        l.buildingId === state.currentBuilding && l.roomId === roomId && l.city === state.currentCity
      );
      html += '<div style="padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem">';
      html += '<div style="display:flex;justify-content:space-between;align-items:center">';
      html += '<div style="font-size:.82rem;color:#c0b090">' + (room.locationData?.label || room.name) + '</div>';
      if (!location) {
        html += '<div style="font-size:.7rem;color:#4a8a4a">Libre</div>';
      } else {
        html += '<div style="font-size:.7rem;color:#8a6a20">Loué</div>';
      }
      html += '</div>';
      if (location) {
        const orga = (state.organisations || []).find(o => o.id === location.orgaId);
        if (orga && orga.visible) {
          html += '<div style="font-size:.72rem;color:#a89870;margin-top:.2rem">Domicilié ici : ' + orga.nom + '</div>';
        } else {
          // orga secrete (orga && !orga.visible) : le siege ne doit pas etre revele ici --
          // rendu identique a un local loue par un particulier sans organisation, pour ne
          // laisser filtrer aucun indice reliant ce local a une organisation secrete.
          html += '<div style="font-size:.72rem;color:#6a5a30;font-style:italic;margin-top:.2rem">Loué par ' + (location.locataire || 'un particulier') + ', sans organisation associée.</div>';
        }
      }
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// Statut effectif d'une licence sportive -- back-compat : une licence achetee avant le lot du 25
// aout 2026 (saisonnalite des licences) n'a pas de champ 'statut' du tout, elle est consideree
// 'active' par defaut (comportement historique inchange). null si aucune licence.
function statutLicenceSportive() {
  const lic = state.char?.licenceSportive;
  if (!lic) return null;
  return lic.statut || 'active';
}

// Lecture fraiche OBLIGATOIRE de licence_sportive avant toute garde d'action locale (lot du 25
// aout 2026, suite a l'incident production Arnie) : state.char n'est reconcilie avec Supabase
// qu'UNE SEULE FOIS, au demarrage de la page (loadCharacter, plateau-core.js) -- jamais pendant
// la suite de la session. Un onglet reste donc ouvert indefiniment avec un licenceSportive
// perime des qu'une correction est faite directement en base (ou, plus generalement, des qu'un
// autre mecanisme -- transfert accepte ailleurs, renouvellement de saison par le cron -- change
// la licence sans que CE client ne soit informe). Une garde qui ne compare que des valeurs
// locales (licenceSportive.clubId === club visite) peut donc rester juste EN APPARENCE tout en
// autorisant une action sur la base d'un club qui n'est plus le vrai club du personnage --
// exactement le mecanisme qui a permis l'annulation d'un non-renouvellement a PSM alors que la
// licence reelle etait a Luthecia. Echoue silencieusement vers l'etat local actuel en cas de
// probleme reseau (jamais un blocage plus severe qu'avant ce correctif).
async function rafraichirLicenceSportiveDepuisServeur() {
  if (!state.char?.name || typeof sbGet !== 'function') return state.char?.licenceSportive || null;
  try {
    const rows = await sbGet('personnages', 'name=eq.' + encodeURIComponent(state.char.name) + '&select=licence_sportive');
    if (rows && rows[0] && state.char) state.char.licenceSportive = rows[0].licence_sportive || null;
  } catch (e) {}
  return state.char?.licenceSportive || null;
}

// Prix ramene de 300 a 150 FR (lot du 25 aout 2026, licences saisonnieres). La licence n'est
// plus permanente : elle vaut une saison et se renouvelle tacitement au meme club au changement
// de saison (voir traiterLicencesSportivesSaison, api/cron-minuit.js -- seul point qui debite le
// renouvellement, jamais le client). derniereSaisonTraitee aligne cette premiere prise sur la
// saison en cours, pour que le cron ne la traite pas comme "a renouveler" avant la VRAIE fin de
// saison.
const COUT_LICENCE_SPORTIVE = 150;

async function doPrendreLicenceSportive(pa, cost) {
  const clubLocal = getClubLocal();
  if (!clubLocal) { showToast('Indisponible', 'Aucun club local ici.', false); return; }

  await rafraichirLicenceSportiveDepuisServeur();
  const lic = state.char?.licenceSportive;
  const statutActuel = statutLicenceSportive();

  // Regle validee (lot du 25 aout 2026) : le transfert reste la SEULE facon de changer de club
  // tant qu'une licence est active. Une licence active ailleurs bloque toute prise directe ici.
  if (statutActuel === 'active') {
    if (lic.clubId === clubLocal.id) { showToast('Déjà licencié(e)', 'Vous avez déjà votre licence pour ' + clubLocal.nom + '.', false); return; }
    showToast('Déjà licencié ailleurs', 'Vous êtes licencié(e) à ' + (getClub(lic.clubId)?.nom || 'un autre club') + '. Seul un transfert permet de changer de club tant que votre licence est active.', false);
    return;
  }
  // Licence impayee : rattachement conserve au club d'origine -- reprise possible UNIQUEMENT
  // dans ce meme club (regle explicite, evite qu'un impaye devienne joueur libre gratuitement).
  if (statutActuel === 'impaye') {
    if (lic.clubId !== clubLocal.id) {
      showToast('Rattaché à un autre club', 'Votre licence impayée vous rattache toujours à ' + (getClub(lic.clubId)?.nom || 'votre club') + '. Vous ne pouvez la reprendre que là-bas, ou passer par un transfert.', false);
      return;
    }
    // sinon : reprise autorisee ci-dessous, meme parcours d'achat que d'habitude.
  }
  if (statutActuel === 'anneeBlanche') {
    showToast('Année blanche', 'Vous ne pouvez prendre aucune licence tant que votre année blanche n\'est pas terminée.', false);
    return;
  }

  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('Fonds insuffisants', '', false); return; }
  if (!state.char) return;
  const saison = await chargerOuInitialiserSaison();
  state.char.licenceSportive = { clubId: clubLocal.id, dateAchat: state.day || 1, statut: 'active', derniereSaisonTraitee: saison?.numero || 1, nonRenouvellement: false };
  sauvegarderPersonnageImmediat();
  updateUI();
  showToast('Licence obtenue !', 'Vous pouvez désormais vous entraîner et jouer pour ' + clubLocal.nom + '.', true, true);
  addJournalEntry('Licence sportive prise pour ' + clubLocal.nom + ' (-' + COUT_LICENCE_SPORTIVE + ' FR).', 'event-good');
  // Correctif du 25 aout 2026 (bug UX v79) : updateUI() ne rafraichit jamais actions-row-bat
  // (renderRoomActions est un rendu ponctuel, fait uniquement a l'entree dans une piece, voir
  // enterRoom) -- sans ce rappel, le bouton "Prendre sa licence sportive" (et tout autre ordre
  // dont l'etat grise/infobulle depend de licenceSportive) restait affiche tel qu'au moment de
  // l'entree dans la piece, meme apres que cette licence vienne de changer. Meme idiome deja
  // utilise ailleurs (confirmerLocation/resilierBox) pour rafraichir la piece courante.
  if (state.currentRoom) enterRoom(state.currentBuilding, state.currentRoom, null);
}

// Demande de non-renouvellement (lot du 25 aout 2026, §3) : ne resilie JAMAIS la licence dans
// l'instant -- le joueur termine normalement sa saison. C'est traiterLicencesSportivesSaison
// (api/cron-minuit.js), au VRAI changement de saison, qui lit ce flag et fait basculer la
// licence en annee blanche sans prelevement. Un transfert accepte pendant que ce flag est actif
// l'annule automatiquement (repondreTransfertJoueur cree une toute nouvelle licenceSportive,
// nonRenouvellement:false par construction).
async function doDemanderNonRenouvellementLicence(pa, cost) {
  const clubLocal = getClubLocal();
  await rafraichirLicenceSportiveDepuisServeur();
  const msgLicence = messageLicenceInvalidePourClub(clubLocal, 'gérer votre licence');
  if (msgLicence) { showToast('Licence requise', msgLicence, false); return; }
  if (state.char.licenceSportive.nonRenouvellement) { showToast('Déjà demandé', 'Vous avez déjà demandé à ne pas renouveler votre licence.', false); return; }

  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }

  state.char.licenceSportive.nonRenouvellement = true;
  sauvegarderPersonnageImmediat();
  updateUI();
  showToast('Demande enregistrée', 'Vous terminez la saison normalement à ' + clubLocal.nom + '. Votre licence ne sera pas renouvelée à la prochaine saison.', true, true);
  addJournalEntry('Demande de non-renouvellement de la licence sportive à ' + clubLocal.nom + '.', 'event-info');
  if (state.currentRoom) enterRoom(state.currentBuilding, state.currentRoom, null);
}

async function doAnnulerNonRenouvellementLicence() {
  const clubLocal = getClubLocal();
  await rafraichirLicenceSportiveDepuisServeur();
  const msgLicence = messageLicenceInvalidePourClub(clubLocal, 'gérer votre licence');
  if (msgLicence) { showToast('Licence requise', msgLicence, false); return; }
  if (!state.char.licenceSportive.nonRenouvellement) { showToast('Aucune demande en cours', '', false); return; }

  state.char.licenceSportive.nonRenouvellement = false;
  sauvegarderPersonnageImmediat();
  updateUI();
  showToast('Demande annulée', 'Votre licence à ' + clubLocal.nom + ' sera de nouveau renouvelée tacitement au changement de saison.', true, true);
  addJournalEntry('Annulation de la demande de non-renouvellement à ' + clubLocal.nom + '.', 'event-info');
  if (state.currentRoom) enterRoom(state.currentBuilding, state.currentRoom, null);
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

// Garde commune entraînement/conseil (correctif du 25 aout 2026, audit comparatif des 3 clubs) :
// avant ce correctif, seule la PRESENCE d'une licenceSportive etait verifiee, jamais son club --
// un PJ licencie a Luthecia pouvait s'entrainer et recevoir des conseils a PSM/Montrouge. Renvoie
// un message dedie par cas (licence absente / mauvais club / impayee / annee blanche) ; null si
// tout est en ordre.
function messageLicenceInvalidePourClub(clubLocal, verbe) {
  const lic = state.char?.licenceSportive;
  const statutActuel = statutLicenceSportive();
  if (!lic) return 'Prenez votre licence sportive avant de ' + verbe + '.';
  if (statutActuel === 'anneeBlanche') return 'Vous êtes en année blanche : impossible de ' + verbe + ' pour l\'instant.';
  if (statutActuel === 'impaye') return 'Votre licence à ' + (getClub(lic.clubId)?.nom || 'votre club') + ' n\'a pas été renouvelée. Reprenez-la pour pouvoir ' + verbe + '.';
  if (lic.clubId !== clubLocal?.id) return 'Vous êtes licencié(e) à ' + (getClub(lic.clubId)?.nom || 'un autre club') + '. Vous ne pouvez ' + verbe + ' que dans ce club (un transfert est nécessaire pour en changer).';
  return null;
}

async function doTenueEntrainement(pa, cost) {
  const clubLocal = getClubLocal();
  await rafraichirLicenceSportiveDepuisServeur();
  const msgLicence = messageLicenceInvalidePourClub(clubLocal, 'vous entraîner');
  if (msgLicence) { showToast('Licence requise', msgLicence, false); return; }
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
    html += '<button ' + (nb >= 2 ? 'disabled' : '') + ' onclick="confirmerEntrainement(\'' + stat + '\',' + pa + ',' + cost + ')" style="font-family:Bebas Neue,sans-serif;font-size:.7rem;padding:.3rem .6rem;border:1px solid #4a3a1a;background:transparent;color:' + (nb>=2?'#5a5040':'#C9A84C') + ';cursor:' + (nb>=2?'default':'pointer') + '">S\'entraîner</button>';
    html += '</div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerEntrainement(stat, pa, cost) {
  verifierEtResetEntrainementsJour();
  if ((state.char.entrainementsJour?.nb || 0) >= 2) { showToast('Limite atteinte', 'Maximum 2 entraînements par jour.', false); return; }
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }
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
  doTenueEntrainement(pa, cost);
}

async function doConseilEntraineurAdjoint() {
  const clubLocal = getClubLocal();
  if (!clubLocal) { showToast('Indisponible', 'Aucun club local ici.', false); return; }
  await rafraichirLicenceSportiveDepuisServeur();
  const msgLicence = messageLicenceInvalidePourClub(clubLocal, 'recevoir des conseils');
  if (msgLicence) { showToast('Licence requise', msgLicence, false); return; }

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

// =====================================================================
// FOOTBALL LIVE — INTERFACE (chantier "match reel 30 minutes", 28 aout 2026)
// Remplace l'ancien doRegarderLive/afficherLiveMatch (replay statique d'un match deja termine,
// 1 PA). Desormais : A) un match reellement en cours (echauffement/mt1/mitemps/mt2) ouvre le VRAI
// live, synchronise pour tous les spectateurs via l'etat persiste (championnat.data) -- jamais un
// simple affichage local ; B) un match termine ouvre un resume clairement etiquete comme tel.
// Gratuit (0 PA) dans les deux cas : regarder un evenement sportif ne consomme plus de PA.
// =====================================================================

let _liveViewerInterval = null;
let _liveViewerRef = null; // {journeeNumero, matchIdx}
let _liveViewerNbEvenementsConnus = 0;

// =====================================================================
// MOTEUR VISUEL DU MATCH (chantier "V1 moteur visuel", 28 aout 2026)
// =====================================================================
// Couche STRICTEMENT locale/decorative. N'ecrit jamais dans championnat.data, ne modifie jamais
// live.scoreHome/Away/evenements/compositionFigee, ne relit jamais une donnee sportive qui
// n'existe pas deja cote client. avancerFootballLive/avancerEvenementsJusqua/progresserMatchLive
// ne sont ni appeles differemment ni modifies par ce chantier -- uniquement leurs SORTIES deja
// lues par rafraichirLiveMatchReel (live.evenements, live.scoreHome/Away, live.compositionFigee,
// live.kickoffAt, live.statut) et les fonctions pures deja existantes (phaseMatchActuelle,
// calculerKickoffJournee, DUREE_*) sont reutilisees en LECTURE SEULE pour deriver l'horloge et
// les limites de phase -- jamais une deuxieme horloge sportive.
// =====================================================================
let _liveViewerTickVisuel = null;          // setInterval 500ms, purement local
let _liveViewerSceneEtat = null;           // {live, home, away, matchKey} -- alimente par rafraichirLiveMatchReel, lu par le tick visuel
let _liveViewerSceneMatchKey = null;       // matchKey du shell DOM actuellement monte (pour savoir s'il faut le reconstruire)
let _liveViewerScenarioCache = {};         // { 'matchKey-phase': [...instants deterministes] }
let _liveViewerDernierInstantAffiche = null;
let _liveViewerFileCanonique = [];         // evenements canoniques nouveaux, en attente d'affichage prioritaire
let _liveViewerAfficheCanoniqueEnCours = false;
let _liveViewerPremierRafraichissement = true; // evite de "rejouer" en insert tous les evenements deja passes a l'ouverture
let _liveViewerTimeoutsAnimation = [];     // setTimeout d'animation en cours, nettoyes a la fermeture
let _liveViewerPortraitsCache = {};        // { matchKey: { nom: photoUrl|null } }
let _liveViewerNomsSupportersConnus = { home: [], away: [] };

function fermerLiveMatchReel() {
  if (_liveViewerInterval) { clearInterval(_liveViewerInterval); _liveViewerInterval = null; }
  arreterTickVisuel();
  _liveViewerTimeoutsAnimation.forEach(id => clearTimeout(id));
  _liveViewerTimeoutsAnimation = [];
  _liveViewerRef = null;
  _liveViewerNbEvenementsConnus = 0;
  _liveViewerSceneEtat = null;
  _liveViewerSceneMatchKey = null;
  _liveViewerDernierInstantAffiche = null;
  _liveViewerFileCanonique = [];
  _liveViewerAfficheCanoniqueEnCours = false;
  _liveViewerPremierRafraichissement = true;
  _liveViewerNomsSupportersConnus = { home: [], away: [] };
}

// ---- Generateur deterministe (mulberry32) -- jamais utilise pour un calcul sportif, uniquement
// pour choisir QUAND et QUEL TYPE de micro-action decorative afficher. ----
function hashChaineVersUint32(str) {
  let h = 2166136261 >>> 0;
  for (let i = 0; i < str.length; i++) { h ^= str.charCodeAt(i); h = Math.imul(h, 16777619); }
  return h >>> 0;
}
function creerPRNGDeterministe(seedUint32) {
  let a = seedUint32 >>> 0;
  return function () {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// ---- Catalogue V1 des micro-actions narratives (section 7) -- purement visuel, jamais ecrit. ----
// trajet : indices dans ZONES_TERRAIN (0=but de l'equipe agissante, 6=but adverse), toujours
// exprimes du point de vue de l'equipe qui agit (miroir applique a l'affichage selon le cote).
const CLES_ZONES_TERRAIN = ['but-propre', 'defense', 'milieu-recul', 'centre', 'milieu-avance', 'attaque', 'but-adverse'];
const CATALOGUE_MICRO_ACTIONS = {
  circulation:  { label: 'Circulation du ballon', trajet: [2, 3, 4],    duree: 2400 },
  duel:         { label: 'Duel au sol',           trajet: [3],          duree: 1700 },
  interception: { label: 'Interception',          trajet: [3, 2],       duree: 1500 },
  course:       { label: 'Course offensive',      trajet: [3, 4, 5],    duree: 2600 },
  degagement:   { label: 'Dégagement',            trajet: [1, 2, 3],    duree: 1400 },
  sortie:       { label: 'Ballon sorti',          trajet: [4],          duree: 1100 },
  touche:       { label: 'Touche',                trajet: [4],          duree: 1500 },
  remise:       { label: 'Remise en jeu',         trajet: [4, 3],       duree: 1800 },
  centre:       { label: 'Centre',                trajet: [5, 6],       duree: 1700 },
  frappe:       { label: 'Frappe !',              trajet: [6],          duree: 1300 },
  arret:        { label: 'Arrêt du gardien',      trajet: [6],          duree: 1300 }
};
const CLES_TYPES_MICRO_ACTION = Object.keys(CATALOGUE_MICRO_ACTIONS);

// =====================================================================
// REALISATEUR AUTOMATIQUE (chantier "realisateur automatique" du 28 aout 2026, architecture
// multi-plans/signatures de ville du 29 aout 2026)
// =====================================================================
// Couche STRICTEMENT decorative, branchee UNIQUEMENT sur les micro-actions narratives locales
// (jouerMicroAction). Ne touche ni live.evenements ni afficherInsertCanonique. Deux familles de
// plans distinctes, jamais confondues :
//  - 'terrain' : pilote le mini-terrain DOM deja existant (cadrage/zoom/travelling/vitesse via
//    transform + transition-duration, purement CSS/JS leger, aucun asset) ;
//  - 'illustre' : pilote une zone d'insert separee (#live-realisateur-illustre, meme langage
//    visuel que le placeholder canonique #live-insert-bd mais un id distinct -- jamais le meme
//    element, pour ne jamais interferer avec un insert d'evenement canonique en cours ou a venir).
// Une sequence = un NOMBRE QUELCONQUE de plans (1, 2, 3, 4... aucune branche speciale dans
// executerSequenceRealisation selon leur nombre -- la sequence experimentale a 3 angles,
// SEQUENCE_PREVIEW_3_ANGLES plus bas, sert de preuve que l'architecture generique sait deja
// executer plusieurs assets/angles successifs), generes une seule fois par instant deterministe
// (meme seed que genererScenarioNarratifPhase : matchKey+phase+instant.t) donc identiques pour
// tous les spectateurs. Ne lit JAMAIS live.evenements : le montage ne peut donc jamais "trahir" un
// evenement canonique futur (meme garantie que le scenario narratif lui-meme).
// =====================================================================

const CADRAGE_SCALE_REALISATEUR = { large: 1, moyen: 1.12, serre: 1.26 };
const ICONES_MICRO_ACTION_REALISATEUR = {
  circulation: '🔄', duel: '⚔️', interception: '🛡️', course: '🏃', degagement: '👢',
  sortie: '↪️', touche: '🥅', remise: '🤾', centre: '➰', frappe: '🎯', arret: '🧤'
};

// Gabarits de montage (section F) : plusieurs rythmes possibles, tires au hasard deterministe --
// jamais le meme enchainement a chaque micro-action. Duree courtes (rythme du live). "large"
// apparait deux fois (frequence legerement plus elevee, cas le plus simple/sur).
const GABARITS_MONTAGE_REALISATEUR = [
  [{ type: 'terrain', cadrage: 'large', dureeBase: 900, dureeVariable: 500, effets: ['travelling', 'accelere'], probaEffet: .35 }],
  [{ type: 'terrain', cadrage: 'large', dureeBase: 800, dureeVariable: 400, effets: null, probaEffet: 0 }],
  [
    { type: 'terrain', cadrage: 'moyen', dureeBase: 650, dureeVariable: 350, effets: ['zoom'], probaEffet: .4 },
    { type: 'terrain', cadrage: 'serre', dureeBase: 550, dureeVariable: 350, effets: ['ralenti', 'vibration'], probaEffet: .35 }
  ],
  [
    { type: 'terrain', cadrage: 'moyen', dureeBase: 550, dureeVariable: 300, effets: ['accelere'], probaEffet: .3 },
    { type: 'illustre', dureeBase: 850, dureeVariable: 400 },
    { type: 'terrain', cadrage: 'large', dureeBase: 450, dureeVariable: 250, effets: null, probaEffet: 0 }
  ],
  [
    { type: 'terrain', cadrage: 'moyen', dureeBase: 650, dureeVariable: 300, effets: ['zoom', 'travelling'], probaEffet: .4 },
    { type: 'illustre', dureeBase: 950, dureeVariable: 450 }
  ],
  [
    { type: 'terrain', cadrage: 'large', dureeBase: 450, dureeVariable: 200, effets: null, probaEffet: 0 },
    { type: 'terrain', cadrage: 'serre', dureeBase: 600, dureeVariable: 350, effets: ['vibration', 'ralenti'], probaEffet: .4 },
    { type: 'terrain', cadrage: 'large', dureeBase: 450, dureeVariable: 200, effets: null, probaEffet: 0 }
  ]
];

// =====================================================================
// CHOREGRAPHIE DES PLAN_ILLUSTRE (crash-test "ras du sol", 28 aout 2026)
// =====================================================================
// Un plan illustre porte desormais plan.couches (tableau -- V1 : toujours une seule entree, le
// placeholder actuel). Chaque couche a un `nom` (reserve pour une future distinction
// fond/sujet/premier_plan -- section "parallaxe future" : ajouter une couche = ajouter une entree
// ici + une cible DOM dediee, l'executeur/jouerChoreographieCouche ne changent pas) et :
//  - mouvement: 'fixe' (aucune transformation, l'image reste immobile pendant dureeMs -- le
//    roman-photo est un choix de realisation a part entiere, pas un defaut) ou 'dynamique' ;
//  - etapes (uniquement si 'dynamique') : cadrages successifs {t (0..1 du plan), cadrage:
//    {scale,x,y,rotation}, easing}, enchaines par des transitions CSS independantes (une par
//    segment) -- permet un mouvement en plusieurs temps (ex. acceleration puis bref ralenti) sans
//    aucune bibliotheque d'animation ;
//  - vibrationAuMoment (0..1, optionnel) : impact ponctuel a un instant du plan.
// COUCHE_ILLUSTRE_FIXE_DEFAUT est exactement ce que produisent aujourd'hui les deux gabarits
// "illustre" existants ci-dessus (aucun changement de comportement pour eux).
const COUCHE_ILLUSTRE_FIXE_DEFAUT = [{ nom: 'placeholder', mouvement: 'fixe' }];

// Gabarit EXPERIMENTAL clairement identifie (section "crash-test ras du sol") : cadrage large ->
// zoom+pan avant simulant une vitesse rapide (acceleration, easing ease-in) -> tres bref
// ralentissement final (easing ease-out) -> micro-vibration d'impact -> sortie CUT. Duree cible
// 1 a 1.5s (dureeBase+dureeVariable = [1000,1400]). Reserve aux micro-actions decoratives neutres
// (duel/course/remise) -- jamais associe a frappe/but/carton/blessure, donc jamais un signal
// annoncant un evenement canonique. Ne lit AUCUNE donnee sportive (meme garantie que le reste du
// realisateur). `asset` (29 aout 2026) : premier vrai visuel du realisateur -- SEULE couche a
// porter ce champ dans tout le fichier ; appliquerPlanIllustreRealisation bascule sur le rendu
// image UNIQUEMENT quand couche.asset est present, donc les autres gabarits illustre (couches
// sans asset, cf. COUCHE_ILLUSTRE_FIXE_DEFAUT) gardent exactement leur rendu pictogramme actuel.
const GABARIT_CRASH_TEST_RAS_DU_SOL = [
  {
    type: 'illustre', dureeBase: 1000, dureeVariable: 400,
    transitionEntree: 'cut', transitionSortie: 'cut',
    couches: [{
      nom: 'placeholder',
      asset: 'images/football-plan-ras-du-sol-01.png',
      mouvement: 'dynamique',
      etapes: [
        { t: 0,   cadrage: { scale: 1,    x: 0, y: 0,  rotation: 0 },    easing: 'linear' },
        { t: .78, cadrage: { scale: 1.5,  x: 0, y: -4, rotation: -1.5 }, easing: 'ease-in' },
        { t: 1,   cadrage: { scale: 1.62, x: 0, y: -5, rotation: -1.5 }, easing: 'ease-out' }
      ],
      vibrationAuMoment: .92
    }]
  }
];

// Pool pondere + filtrable par micro-action : les 6 gabarits existants restent equiprobables
// (poids 1 chacun) ; le crash-test est rare PAR CONSTRUCTION (poids tres faible ET reserve a un
// sous-ensemble de micro-actions) -- jamais mele au reste sans discipline de rythme (section
// "IMPORTANT POUR LE RYTHME"). `id` (chantier "architecture multi-plans / signatures de ville",
// 29 aout 2026) : chaque entree porte desormais un identifiant stable -- c'est ce qui permet a
// UNE MEME famille d'action (ex. 'duel', deja compatible avec les 6 gabarits par defaut ET le
// crash-test, soit 7 gabarits disponibles) de recevoir plusieurs gabarits differents ; ajouter un
// futur gabarit a une famille = ajouter une entree ici avec le bon `microActionsCompatibles`,
// jamais une modification de genererSequenceRealisation/executerSequenceRealisation.
const POOL_GABARITS_REALISATEUR = GABARITS_MONTAGE_REALISATEUR
  .map((gabarit, i) => ({ id: 'gabarit_montage_' + i, gabarit, poids: 1, microActionsCompatibles: null }))
  .concat([{ id: 'crash_test_ras_du_sol', gabarit: GABARIT_CRASH_TEST_RAS_DU_SOL, poids: .3, microActionsCompatibles: ['duel', 'course', 'remise'] }]);

// =====================================================================
// PROFIL DE REALISATION PAR VILLE HOTE (chantier "architecture multi-plans / signatures de
// ville", 29 aout 2026)
// =====================================================================
// Reserve UNIQUEMENT l'architecture -- AUCUN style artistique n'est arbitre ici (pas de manga, pas
// d'Acid Ink, pas de BD europeenne, rien). PROFILS_REALISATION_VILLE est volontairement VIDE :
// tant qu'aucune entree n'y est ajoutee, profilRealisationVille() renvoie toujours
// PROFIL_REALISATION_DEFAUT, dont le `pool` contient EXACTEMENT les memes entrees que
// POOL_GABARITS_REALISATEUR (memes objets gabarit/poids/microActionsCompatibles, memes
// probabilites) -- donc AUCUN changement de comportement du live reel tant que ce chantier reste
// en l'etat (section 17 : "aucun changement artistique visible du match reel"). `.slice()`
// (correctif du 29 aout 2026) : le TABLEAU lui-meme est une copie distincte de
// POOL_GABARITS_REALISATEUR, pour qu'un futur profil de ville ne puisse jamais, par une simple
// mutation en place (push/splice/etc. sur profil.pool), corrompre le pool global partage -- les
// entrees qu'il contient restent des references partagees (jamais mutees nulle part dans ce
// fichier), donc aucun cout, aucun changement de probabilite.
// Cle de resolution : country+'.'+city de la ville HOTE, TOUJOURS celle du club home (un club
// joue toujours dans sa propre ville) -- concept STRICTEMENT separe de l'identite visuelle des
// clubs (identiteVisuelleClub reste couleurs/maillot/finition, jamais camera/montage/rythme,
// section "distinction identite club / realisation ville").
const PROFIL_REALISATION_DEFAUT = {
  id: 'defaut',
  pool: POOL_GABARITS_REALISATEUR.slice(),
  rythmeMoyen: 1,                // multiplicateur neutre -- 1 = comportement actuel, jamais applique tant qu'inutilise
  frequenceFixe: null,           // reserve : biais futur vers mouvement:'fixe'
  frequenceMultiAngle: null,     // reserve : biais futur vers les sequences multi-plans/angles
  transitionsPrivilegiees: null, // reserve : ex. forcer davantage de cuts/fondus selon la ville
  amplitudeCameraMax: null,      // reserve : ex. limiter/etendre le scale max des cadrages
  plansSignature: [],            // reserve : futurs gabarits exclusifs a une ville
  traitement: null               // reserve : futur filtre/texture visuel -- jamais applique aujourd'hui
};
const PROFILS_REALISATION_VILLE = {}; // volontairement vide -- aucune signature de ville arbitree pour l'instant
function profilRealisationVille(country, city) {
  return PROFILS_REALISATION_VILLE[country + '.' + city] || PROFIL_REALISATION_DEFAUT;
}

// Clone superficiel-suffisant (donnees plates, jamais de fonction/Date) : chaque plan genere garde
// sa PROPRE copie de couches, jamais une reference partagee vers la constante du gabarit.
function clonerCouches(couches) {
  return JSON.parse(JSON.stringify(couches));
}

// Duree totale d'une sequence (section 4, "duree totale calculable"), a partir de n'importe quelle
// liste de plans -- reutilisable aussi bien par genererSequenceRealisation que par une sequence
// construite a la main (ex. SEQUENCE_PREVIEW_3_ANGLES, plus bas).
function dureeTotaleSequence(sequence) {
  return sequence.plans.reduce((s, p) => s + p.dureeMs, 0);
}

// Fonction PURE et deterministe (section B) : meme (seed, contexte, profil) => toujours la meme
// sequence. Le seed est construit par l'appelant a partir de la meme identite stable que le
// scenario narratif (jamais recalcule differemment ici) -- donc tous les spectateurs d'un match
// obtiennent la meme sequence pour le meme instant, sans aucune ecriture reseau. Ne lit ni live ni
// contexte sportif : contexte se limite a {microAction, cote}, deja purement decoratifs -- le
// filtrage du pool par micro-action est donc lui aussi sans aucune connaissance de la verite
// sportive, juste de l'identite deja connue de l'instant narratif local.
// `profil` (chantier "architecture multi-plans / signatures de ville", 29 aout 2026) : parametre
// OPTIONNEL -- absent (tous les appels existants), il vaut PROFIL_REALISATION_DEFAUT dont le pool
// est exactement POOL_GABARITS_REALISATEUR (meme reference) : comportement rigoureusement
// identique a avant ce chantier. Un futur profil de ville n'aura qu'a fournir son propre `pool`
// (memes gabarits reutilises, filtres/reponderes, ou nouveaux gabarits exclusifs) -- aucune autre
// ligne de cette fonction n'a besoin de changer.
function genererSequenceRealisation(seed, contexte, profil) {
  const poolActif = (profil || PROFIL_REALISATION_DEFAUT).pool;
  const rng = creerPRNGDeterministe(hashChaineVersUint32('realisateur-' + seed));
  const poolEligible = poolActif.filter(e =>
    !e.microActionsCompatibles || e.microActionsCompatibles.includes(contexte.microAction));
  const totalPoids = poolEligible.reduce((s, e) => s + e.poids, 0);
  let r = rng() * totalPoids;
  let entree = poolEligible[poolEligible.length - 1];
  for (const e of poolEligible) { r -= e.poids; if (r <= 0) { entree = e; break; } }
  const plans = entree.gabarit.map((squelette, i) => {
    const dureeMs = Math.round(squelette.dureeBase + rng() * squelette.dureeVariable);
    const plan = {
      type: squelette.type, dureeMs,
      transition: squelette.transitionEntree || (i === 0 ? 'cut' : (rng() < .5 ? 'fondu' : 'cut')),
      // Section 3 : "equipe/joueur mis en valeur si utile" -- champs reserves, non consommes par le
      // rendu aujourd'hui (aucun gabarit actuel ne cible un joueur precis en decoratif -- seuls les
      // evenements canoniques le font, via evenement.joueur, deja gere ailleurs/inchangeant).
      equipeMiseEnValeur: contexte.cote || 'neutre',
      joueurMisEnValeur: null
    };
    if (squelette.type === 'terrain') {
      plan.cadrage = squelette.cadrage;
      plan.effet = (squelette.effets && rng() < squelette.probaEffet)
        ? squelette.effets[Math.floor(rng() * squelette.effets.length)]
        : null;
      if (plan.effet === 'travelling') plan.travellingDx = rng() < .5 ? -3 : 3; // sens deterministe, jamais Math.random
    } else {
      plan.variante = Math.floor(rng() * 3); // reserve pour de futures variantes graphiques (section 4), non rendu en V1
      plan.transitionSortie = squelette.transitionSortie || (rng() < .5 ? 'fondu' : 'cut');
      plan.couches = clonerCouches(squelette.couches || COUCHE_ILLUSTRE_FIXE_DEFAUT);
    }
    return plan;
  });
  // Section 4 : metadonnees de sequence (identifiant de gabarit, duree totale calculable, joueur
  // eventuel, caractere decoratif) -- genererSequenceRealisation ne produit AUJOURD'HUI que des
  // sequences decoratives (`decoratif: true` toujours) ; une sequence canonique n'existe pas et
  // n'est pas construite par ce chantier (section 12/13).
  return {
    gabaritId: entree.id, plans, microAction: contexte.microAction, cote: contexte.cote,
    dureeMs: dureeTotaleSequence({ plans }), joueur: null, decoratif: true
  };
}

// Reechantillonne le trajet (relatif au point de vue de l'equipe qui agit) sur le nombre de plans
// "terrain" de la sequence -- un point par plan terrain, dans l'ordre, mirroir applique pour
// l'equipe away (meme convention que l'ancien code : zoneAbsolue = idxRel pour home, 6-idxRel
// pour away).
function zonesTerrainPourSequence(trajetRelatif, cote, nbPlansTerrain) {
  const n = Math.max(1, nbPlansTerrain);
  const zones = [];
  for (let k = 0; k < n; k++) {
    const idxRel = n === 1
      ? trajetRelatif[trajetRelatif.length - 1]
      : trajetRelatif[Math.round(k * (trajetRelatif.length - 1) / (n - 1))];
    zones.push(cote === 'home' ? idxRel : (6 - idxRel));
  }
  return zones;
}

// Applique le cadrage/l'effet d'UN plan terrain sur le mini-terrain deja existant : transform
// (scale/translate) sur .live-pelouse (jamais un redimensionnement reel, jamais de reflow) +
// transition-duration sur ballon/joueurs pour accelere/ralenti. Toujours reinitialise en entier
// (jamais d'accumulation d'un plan a l'autre).
function appliquerCadrageTerrain(plan) {
  const pelouse = document.querySelector('#live-mini-terrain .live-pelouse');
  if (pelouse) {
    let scale = CADRAGE_SCALE_REALISATEUR[plan.cadrage] || 1;
    if (plan.effet === 'zoom') scale *= 1.08;
    let transform = 'scale(' + scale.toFixed(3) + ')';
    if (plan.effet === 'travelling') transform += ' translateX(' + plan.travellingDx + '%)';
    pelouse.style.transition = 'transform .4s ease';
    pelouse.style.transform = transform;
    pelouse.classList.remove('live-pelouse--vibration');
    if (plan.effet === 'vibration') {
      void pelouse.offsetWidth; // force le reflow pour pouvoir rejouer l'animation (meme patron que afficherMessageTribune)
      pelouse.classList.add('live-pelouse--vibration');
    }
  }
  const dureeMs = plan.effet === 'accelere' ? 250 : (plan.effet === 'ralenti' ? 1100 : null);
  ['live-ballon', 'live-joueur-home', 'live-joueur-away'].forEach(id => {
    const el = document.getElementById(id);
    if (el) el.style.transitionDuration = dureeMs ? dureeMs + 'ms' : '';
  });
}

// Formate un cadrage {scale,x,y,rotation} en chaine CSS transform (x/y en %, rotation en degres).
function transformCssDepuisCadrage(cadrage) {
  return 'scale(' + cadrage.scale + ') translate(' + cadrage.x + '%, ' + cadrage.y + '%) rotate(' + cadrage.rotation + 'deg)';
}

// Joue la choregraphie d'UNE couche sur l'overlay illustre (V1 : toujours la seule couche du
// placeholder actuel -- une future couche 'fond'/'sujet'/'premier_plan' ajouterait juste une
// entree ici + sa propre cible DOM, cette fonction n'a pas besoin d'etre reecrite). 'fixe' :
// aucune transformation (immobilite assumee, cut/fondu d'entree-sortie restent independants).
// 'dynamique' : enchaine les etapes via le patron reflow-puis-transition deja utilise ailleurs
// dans ce fichier (afficherMessageTribune) -- une transition CSS par segment, chacune avec son
// propre easing, jamais de requestAnimationFrame ni de nouveau mecanisme de timer : les segments
// suivants (i>=1) sont de simples setTimeout, geres comme tous les autres timers d'animation.
function jouerChoreographieCouche(couche, overlay, dureeMs) {
  if (!couche || couche.mouvement !== 'dynamique' || !couche.etapes || couche.etapes.length < 2) {
    overlay.style.transition = 'none';
    overlay.style.transform = (couche && couche.etapes && couche.etapes[0]) ? transformCssDepuisCadrage(couche.etapes[0].cadrage) : '';
    return;
  }
  const etapes = couche.etapes;
  overlay.style.transition = 'none';
  overlay.style.transform = transformCssDepuisCadrage(etapes[0].cadrage);
  void overlay.offsetWidth; // force le reflow : le cadrage initial est peint avant toute transition
  for (let i = 1; i < etapes.length; i++) {
    const etapePrecedente = etapes[i - 1];
    const etape = etapes[i];
    const segMs = Math.max(30, Math.round((etape.t - etapePrecedente.t) * dureeMs));
    const idEtape = setTimeout(() => {
      if (_liveViewerAfficheCanoniqueEnCours) return;
      overlay.style.transition = 'transform ' + (segMs / 1000).toFixed(3) + 's ' + (etape.easing || 'linear');
      overlay.style.transform = transformCssDepuisCadrage(etape.cadrage);
    }, Math.round(etapePrecedente.t * dureeMs));
    _liveViewerTimeoutsAnimation.push(idEtape);
  }
  if (couche.vibrationAuMoment != null) {
    const idVib = setTimeout(() => {
      if (_liveViewerAfficheCanoniqueEnCours) return;
      void overlay.offsetWidth;
      overlay.classList.add('live-realisateur-vibration-appliquee');
      const idVibFin = setTimeout(() => overlay.classList.remove('live-realisateur-vibration-appliquee'), 300);
      _liveViewerTimeoutsAnimation.push(idVibFin);
    }, Math.round(couche.vibrationAuMoment * dureeMs));
    _liveViewerTimeoutsAnimation.push(idVib);
  }
}

// Affiche UN plan illustre : reutilise le placeholder existant (memes classes CSS que
// #live-insert-bd, id different -- jamais le meme element qu'un insert canonique). Remet
// systematiquement le cadrage du terrain a plat pour que l'insert ne soit jamais deforme par un
// zoom/travelling laisse par un plan terrain precedent de la MEME sequence. transition==='cut' :
// apparition instantanee (classe live-insert-bd-instant, desactive le fondu d'entree existant) ;
// sinon fondu existant inchange. Premier vrai asset (29 aout 2026) : si couche.asset est present,
// la choregraphie s'applique a l'<img> dediee (object-fit:cover, jamais de deformation, contenue
// par l'overflow:hidden de .live-insert-bd) plutot qu'a l'overlay entier, et le pictogramme est
// masque -- sinon (toutes les autres couches illustre, aucune ne porte `asset`) comportement
// STRICTEMENT inchange : pictogramme + choregraphie sur l'overlay comme avant. jouerChoreographieCouche
// lui-meme n'est pas modifie, seule sa CIBLE varie.
function appliquerPlanIllustreRealisation(plan, instant, def, club) {
  const pelouse = document.querySelector('#live-mini-terrain .live-pelouse');
  if (pelouse) pelouse.style.transform = 'scale(1)';
  const overlay = document.getElementById('live-realisateur-illustre');
  if (!overlay) return;
  const actionEl = overlay.querySelector('.live-insert-bd-action');
  const texteEl = overlay.querySelector('.live-insert-bd-texte');
  const imageEl = document.getElementById('live-realisateur-illustre-image');
  const couche = (plan.couches && plan.couches[0]) || null;

  if (couche && couche.asset) {
    if (imageEl) { imageEl.src = couche.asset; imageEl.style.display = 'block'; }
    if (actionEl) actionEl.textContent = ''; // l'asset reel remplace le pictogramme-placeholder
  } else {
    if (imageEl) { imageEl.style.display = 'none'; imageEl.removeAttribute('src'); }
    if (actionEl) actionEl.textContent = ICONES_MICRO_ACTION_REALISATEUR[instant.type] || 'ℹ️';
  }
  // plan.cartouche (correctif du 29 aout 2026, defaut true -- absent sur tous les plans existants
  // donc aucun changement de comportement pour A/B/le vrai live) : un plan illustre peut demander
  // explicitement `cartouche:false` pour rester PUREMENT visuel, sans texte narratif superpose --
  // reutilisable plus tard par le realisateur reel pour distinguer un plan narratif (cartouche) d'un
  // plan de mise en scene pure (sans cartouche), sans hack CSS ni structure parallele.
  if (texteEl) texteEl.textContent = (plan.cartouche === false) ? '' : (def.label || '') + ' — ' + club.nom;

  overlay.className = 'live-insert-bd live-insert-bd-visible' + (plan.transition === 'cut' ? ' live-insert-bd-instant' : '');
  const cible = (couche && couche.asset && imageEl) ? imageEl : overlay;
  jouerChoreographieCouche(couche, cible, plan.dureeMs);
}

// sortieCut=true : masque instantanement (aucun fondu de sortie), pour un plan dont
// transitionSortie==='cut' (ex. crash-test ras du sol). Par defaut (false/undefined) : fondu
// existant inchange (transition CSS .3s deja definie sur .live-insert-bd). Reinitialise aussi
// l'<img> (transform/affichage/src) pour ne jamais laisser un cadrage ou une image residuelle
// avant le prochain plan illustre de la MEME session de live.
function masquerPlanIllustreRealisation(sortieCut) {
  const overlay = document.getElementById('live-realisateur-illustre');
  const imageEl = document.getElementById('live-realisateur-illustre-image');
  if (!overlay) return;
  if (sortieCut) {
    overlay.style.transition = 'none';
    overlay.className = 'live-insert-bd';
    void overlay.offsetWidth;
    overlay.style.transition = '';
  } else {
    overlay.className = 'live-insert-bd';
  }
  overlay.style.transform = '';
  if (imageEl) {
    imageEl.style.transition = ''; imageEl.style.transform = '';
    imageEl.style.display = 'none'; imageEl.removeAttribute('src');
  }
}

// Remet la scene a plat a la fin d'une sequence de realisation -- strictement equivalent a
// l'ancien retour a l'etat neutre de jouerMicroAction (meme positions, meme label vide), plus la
// remise a plat du cadrage/de la vitesse/de l'insert illustre introduits par ce chantier.
// sortieCut : transmis a masquerPlanIllustreRealisation si le DERNIER plan illustre programme de
// la sequence demandait une sortie en cut (jamais un fondu par defaut dans ce cas).
function reinitialiserSceneApresSequenceRealisation(sortieCut) {
  masquerPlanIllustreRealisation(sortieCut);
  const pelouse = document.querySelector('#live-mini-terrain .live-pelouse');
  if (pelouse) { pelouse.style.transform = 'scale(1)'; pelouse.classList.remove('live-pelouse--vibration'); }
  ['live-ballon', 'live-joueur-home', 'live-joueur-away'].forEach(id => {
    const el = document.getElementById(id);
    if (el) el.style.transitionDuration = '';
  });
  positionnerBallon(3); positionnerJoueur('home', 2); positionnerJoueur('away', 4);
  const l = document.getElementById('live-action-label');
  if (l) l.textContent = '';
}

// Executeur commun (section D) : enchaine un nombre QUELCONQUE de plans deja generes (sequence.plans.forEach,
// aucune branche speciale pour 1, 2, 3 ou 4 plans -- verifie explicitement dans le chantier
// "architecture multi-plans" du 29 aout 2026), purement par affichage.
// A CHAQUE callback, verifie qu'aucun insert canonique n'est en cours (_liveViewerAfficheCanoniqueEnCours,
// deja utilise par tickVisuelScene) -- si un evenement canonique a pris la priorite entre-temps, ce
// plan est simplement saute, jamais de conflit visuel avec afficherInsertCanonique. Tous les
// setTimeout sont pousses dans _liveViewerTimeoutsAnimation (meme tableau que le reste du moteur
// visuel) donc nettoyes par fermerLiveMatchReel comme n'importe quel autre timer -- aucun timer
// residuel possible a la fermeture.
function executerSequenceRealisation(sequence, instant, def, club) {
  const terrainPlans = sequence.plans.filter(p => p.type === 'terrain');
  const zonesTerrain = zonesTerrainPourSequence(def.trajet, instant.cote, terrainPlans.length);
  const planTerrainUnique = terrainPlans.length === 1;
  let offset = 0;
  let kTerrain = 0;
  let sortieCutAttendue = false; // sortie du DERNIER plan illustre programme -- lue par le plan suivant, ou par idFin
  sequence.plans.forEach(plan => {
    const debutPlan = offset;
    if (plan.type === 'terrain') {
      const zoneCible = zonesTerrain[kTerrain];
      const sortiePrecedente = sortieCutAttendue;
      const idT = setTimeout(() => {
        if (_liveViewerAfficheCanoniqueEnCours) return;
        masquerPlanIllustreRealisation(sortiePrecedente);
        appliquerCadrageTerrain(plan);
        if (planTerrainUnique && def.trajet.length > 1) {
          // Sequence a un seul plan terrain (cas le plus frequent) : on conserve la marche fluide
          // historique en sous-etapant le trajet complet DANS la fenetre de ce plan.
          const pas = plan.dureeMs / def.trajet.length;
          def.trajet.forEach((idxRel, i) => {
            const idSub = setTimeout(() => {
              if (_liveViewerAfficheCanoniqueEnCours) return;
              const zoneAbs = instant.cote === 'home' ? idxRel : (6 - idxRel);
              positionnerBallon(zoneAbs);
              positionnerJoueur(instant.cote, zoneAbs);
            }, i * pas);
            _liveViewerTimeoutsAnimation.push(idSub);
          });
        } else if (plan.effet !== 'pause') {
          positionnerBallon(zoneCible);
          positionnerJoueur(instant.cote, zoneCible);
        }
      }, debutPlan);
      _liveViewerTimeoutsAnimation.push(idT);
      kTerrain++;
    } else {
      sortieCutAttendue = plan.transitionSortie === 'cut';
      const idT = setTimeout(() => {
        if (_liveViewerAfficheCanoniqueEnCours) return;
        appliquerPlanIllustreRealisation(plan, instant, def, club);
      }, debutPlan);
      _liveViewerTimeoutsAnimation.push(idT);
    }
    offset += plan.dureeMs;
  });

  const idFin = setTimeout(() => {
    if (_liveViewerAfficheCanoniqueEnCours) return;
    reinitialiserSceneApresSequenceRealisation(sortieCutAttendue);
  }, offset);
  _liveViewerTimeoutsAnimation.push(idFin);
}

// =====================================================================
// PREVIEW REALISATEUR -- BANC D'ESSAI VISUEL (outil de mise au point, 29 aout 2026, etendu en
// banc d'essai declaratif le meme jour)
// =====================================================================
// Outil de developpement STRICTEMENT local/decoratif, actif UNIQUEMENT si l'URL contient
// ?footballPreview=1 (une seule verification a DOMContentLoaded, aucun autre branchement --
// absent du parametre, cette section entiere ne fait strictement rien). Reutilise TEL QUEL le
// vrai executeur (executerSequenceRealisation) et le vrai generateur (genererSequenceRealisation)
// -- aucune imitation parallele. Le shell DOM est construit via la VRAIE construireSceneMiniTerrain
// (memes ids/classes que le live reel), avec deux clubs REELS (getClub), jamais de donnee
// fictive. Aucune lecture/ecriture championnat, aucun appel Supabase, aucun PA, aucun effet
// canonique -- tout se joue en memoire/DOM, exactement comme la couche decorative existante. Les
// scenarios de test sont declares dans SCENARIOS_PREVIEW_REALISATEUR (plus bas) -- le panneau
// construit ses boutons depuis cette liste, jamais de bouton code en dur.
function trouverSequenceCrashTestRasDuSol(instant) {
  // genererSequenceRealisation est pure (aucun effet de bord) : on peut l'appeler a blanc autant
  // de fois que necessaire pour retomber sur le gabarit voulu -- jamais une modification du pool
  // ni de ses probabilites, seulement une recherche du seed adequat parmi ceux deja possibles en
  // production. Identification par gabaritId (stable, chantier "architecture multi-plans" du 29
  // aout 2026) plutot que par sniffing structurel.
  for (let i = 0; i < 500; i++) {
    const sequence = genererSequenceRealisation('preview-crash-test-' + i, { microAction: instant.type, cote: instant.cote });
    if (sequence.gabaritId === 'crash_test_ras_du_sol') return sequence;
  }
  return null; // ne devrait jamais arriver (~4.7% de chances par tirage, 500 essais tres largement suffisants)
}

// Sequence B "3 angles" (test de montage, 29 aout 2026) : hypothese testee, le spectaculaire
// vient du montage/changement d'angle plus que du seul mouvement dans une image fixe.
// EXCLUSIVEMENT dans la preview -- volontairement absente de GABARITS_MONTAGE_REALISATEUR/
// POOL_GABARITS_REALISATEUR, donc jamais selectionnable en match reel par genererSequenceRealisation.
// Construite DIRECTEMENT avec les memes champs qu'un plan produit par genererSequenceRealisation
// (type/dureeMs/transition/transitionSortie/couches), executee par la VRAIE
// executerSequenceRealisation -- aucun second moteur d'animation. Chaque plan coupe EN PLEIN
// MOUVEMENT (derniere etape jamais "posee"), sauf le dernier (C) qui suspend brievement + vibre
// juste avant le cut de sortie -- pour donner l'illusion d'une action continue malgre le
// changement brutal d'angle/d'image. Duree totale : 700+650+900 = 2250ms (ajustee le 29 aout
// 2026 -- rythme initial de 1250ms juge trop rapide ; les etapes de choregraphie sont deja
// exprimees en fractions relatives (t: 0..1), donc elles s'adaptent naturellement a ces nouvelles
// durees sans aucune autre modification : A reste en acceleration au cut, B reste en travelling
// au cut, C conserve son ralentissement/suspension final + micro-impact).
// executerSequenceRealisation/jouerChoreographieCouche ne lisent jamais ces objets, ils sont en
// lecture seule pour ce chantier -- reutilisable tel quel sans clonage entre deux relances.
// Metadonnees de sequence (section 4) ajoutees pour coherence de schema avec genererSequenceRealisation
// -- non lues par l'executeur, purement documentaires/preuve de la grammaire commune.
const SEQUENCE_PREVIEW_3_ANGLES = {
  gabaritId: 'preview_3_angles', microAction: 'duel', cote: 'home', joueur: null, decoratif: true,
  plans: [
    { // PLAN A -- camera ras-du-sol frontale, mouvement rapide vers l'action, cut en plein mouvement.
      type: 'illustre', dureeMs: 700, transition: 'cut', transitionSortie: 'cut', equipeMiseEnValeur: 'neutre',
      couches: [{
        nom: 'placeholder', asset: 'images/football-plan-ras-du-sol-01.png', mouvement: 'dynamique',
        etapes: [
          { t: 0, cadrage: { scale: 1,    x: 0, y: 0,  rotation: 0 },  easing: 'linear' },
          { t: 1, cadrage: { scale: 1.35, x: 0, y: -3, rotation: -1 }, easing: 'ease-in' }
        ]
      }]
    },
    { // PLAN B -- angle lateral tres bas, travelling horizontal rapide, part deja "en mouvement"
      // (scale/pan de depart superieurs a l'etat neutre) pour prolonger la sensation du plan A.
      type: 'illustre', dureeMs: 650, transition: 'cut', transitionSortie: 'cut', equipeMiseEnValeur: 'neutre',
      couches: [{
        nom: 'placeholder', asset: 'images/football-duel-angle-02.png', mouvement: 'dynamique',
        etapes: [
          { t: 0, cadrage: { scale: 1.15, x: -4, y: 0, rotation: 0 },  easing: 'linear' },
          { t: 1, cadrage: { scale: 1.3,  x: 10, y: 0, rotation: .5 }, easing: 'ease-in' }
        ]
      }]
    },
    { // PLAN C -- tres proche du ballon/des jambes, mouvement plus court, tres bref ralentissement/
      // suspension (ease-out sur le dernier segment) + micro-vibration d'impact avant le cut de sortie.
      type: 'illustre', dureeMs: 900, transition: 'cut', transitionSortie: 'cut', equipeMiseEnValeur: 'neutre',
      couches: [{
        nom: 'placeholder', asset: 'images/football-duel-angle-03.png', mouvement: 'dynamique',
        etapes: [
          { t: 0,  cadrage: { scale: 1.4,  x: 0, y: -2, rotation: 0 },   easing: 'linear' },
          { t: .7, cadrage: { scale: 1.55, x: 0, y: -3, rotation: -.5 }, easing: 'ease-in' },
          { t: 1,  cadrage: { scale: 1.6,  x: 0, y: -3, rotation: -.5 }, easing: 'ease-out' }
        ],
        vibrationAuMoment: .9
      }]
    }
  ]
};
SEQUENCE_PREVIEW_3_ANGLES.dureeMs = dureeTotaleSequence(SEQUENCE_PREVIEW_3_ANGLES); // 700+650+900 = 2250ms

// Sequence C "stop motion" (premier test le 29 aout 2026, mise en scene "rupture frame 06" le meme
// jour) : 7 poses fixes distinctes (01-05, 07-08) cut franc entre chacune -- AUCUNE animation
// continue sur ces 7-la (mouvement:'fixe', aucun cadrage/zoom, pour eviter que la sequence ne se
// lise comme un montage multi-angle façon B). Le mouvement perçu y vient UNIQUEMENT du changement
// brutal de pose, jamais d'un deplacement de camera. La frame 06 (projection/arret visuel) est la
// SEULE rupture de langage : couche mouvement:'dynamique', memes primitives que le plan A/crash-
// test ras-du-sol (etapes scale/pan/rotation + vibrationAuMoment) -- aucun nouveau mecanisme, la
// vibration y est reutilisable proprement (contrairement a une pose fixe, cf. l'historique de ce
// fichier) puisque mouvement:'dynamique' a bien >=2 etapes. Aucun effet graphique supplementaire
// (flash/radiales) ajoute : aurait exige du code neuf specifique a C, hors perimetre demande --
// zoom + vibration existante suffisent au test. Rythme volontairement irregulier et asymetrique :
// ce sont des durees de mise en scene, pas des evenements sportifs. EXCLUSIVEMENT dans la preview
// -- volontairement absente de GABARITS_MONTAGE_REALISATEUR/POOL_GABARITS_REALISATEUR, comme B.
const FRAMES_STOP_MOTION_DUEL = [
  { asset: 'images/football-stopmotion-duel-frame-01.png', dureeMs: 380 }, // duel / approche
  { asset: 'images/football-stopmotion-duel-frame-02.png', dureeMs: 220 }, // declenchement du tacle
  { asset: 'images/football-stopmotion-duel-frame-03.png', dureeMs: 170 }, // tacle engage
  { asset: 'images/football-stopmotion-duel-frame-04.png', dureeMs: 150 }, // glissade avancee
  { asset: 'images/football-stopmotion-duel-frame-05.png', dureeMs: 260 }, // contact / rupture
  {
    asset: 'images/football-stopmotion-duel-frame-06.png', dureeMs: 750, // projection / arret visuel -- seule rupture animee
    couche: {
      mouvement: 'dynamique',
      etapes: [
        { t: 0,   cadrage: { scale: 1,    x: 0, y: 0,  rotation: 0 },  easing: 'linear' },
        { t: .55, cadrage: { scale: 1.55, x: 0, y: -4, rotation: -1 }, easing: 'ease-in' },
        { t: 1,   cadrage: { scale: 1.68, x: 0, y: -5, rotation: -1 }, easing: 'ease-out' }
      ],
      vibrationAuMoment: .88
    }
  },
  { asset: 'images/football-stopmotion-duel-frame-07.png', dureeMs: 420 }, // joueurs au sol
  { asset: 'images/football-stopmotion-duel-frame-08.png', dureeMs: 520 }  // debut du relevage
];
const SEQUENCE_PREVIEW_STOP_MOTION = {
  gabaritId: 'preview_stop_motion', microAction: 'duel', cote: 'home', joueur: null, decoratif: true,
  plans: FRAMES_STOP_MOTION_DUEL.map(frame => ({
    // cartouche:false (correctif du 29 aout 2026) : sequence purement visuelle, aucun texte
    // narratif ne doit recouvrir les 8 poses -- voir appliquerPlanIllustreRealisation.
    type: 'illustre', dureeMs: frame.dureeMs, transition: 'cut', transitionSortie: 'cut', equipeMiseEnValeur: 'neutre',
    cartouche: false,
    // frame.couche (uniquement frame 06) surcharge mouvement/etapes/vibrationAuMoment sur la base
    // par defaut {nom, asset, mouvement:'fixe'} -- les 7 autres frames restent inchangees.
    couches: [Object.assign({ nom: 'placeholder', asset: frame.asset, mouvement: 'fixe' }, frame.couche || {})]
  }))
};
SEQUENCE_PREVIEW_STOP_MOTION.dureeMs = dureeTotaleSequence(SEQUENCE_PREVIEW_STOP_MOTION); // 380+220+170+150+260+750+420+520 = 2870ms

// =====================================================================
// BANC D'ESSAI VISUEL -- liste declarative des scenarios de preview (chantier "banc d'essai
// visuel", 29 aout 2026, complete avec le scenario stop motion le meme jour)
// =====================================================================
// Le panneau construit ses boutons a partir de CETTE liste (aucun bouton code en dur) --
// ajouter un futur scenario = ajouter une entree ici, jamais toucher initPreviewRealisateur.
// `disponible` (defaut true) : un scenario dont les assets ne sont pas encore livres peut etre
// declare avec `disponible:false`, le panneau ne l'affiche alors pas -- "le panneau ne doit
// afficher que les scenarios disposant reellement de leurs assets" (section 6). Aucun scenario
// factice n'est ajoute ici : A, B et desormais C disposent tous de vrais assets.
//
// MIXTE (section 6, PAS implemente ici -- pas encore demande) : un futur scenario "mixte"
// (terrain -> illustre fixe -> stop motion -> illustre anime -> terrain) resterait, lui aussi, une
// simple sequence.plans plus longue -- aucune reecriture d'executerSequenceRealisation/
// jouerChoreographieCouche necessaire, exactement comme B et C le demontrent deja.
//
// MICRO-ANIMATION COURTE (GIF/WebP anime, section 5, PAS implemente -- aucun asset) : verifie,
// aucune adaptation necessaire. appliquerPlanIllustreRealisation assigne l'asset via
// `imageEl.src = couche.asset` sur un <img> standard (voir plus haut) -- un navigateur anime
// nativement un GIF/WebP anime affecte a `<img src>`, independamment du transform CSS de
// jouerChoreographieCouche (camera et animation intrinseque du fichier sont orthogonales). Rien a
// changer ici tant qu'aucun tel asset n'existe.
const SCENARIOS_PREVIEW_REALISATEUR = [
  {
    id: 'plan_unique',
    label: 'A — Plan unique',
    disponible: true,
    construireSequence: instant => trouverSequenceCrashTestRasDuSol(instant)
  },
  {
    id: 'multi_angle',
    label: 'B — Multi-angle — ' + (SEQUENCE_PREVIEW_3_ANGLES.dureeMs / 1000).toFixed(2).replace('.', ',') + ' s',
    disponible: true,
    construireSequence: () => SEQUENCE_PREVIEW_3_ANGLES
  },
  {
    id: 'stop_motion',
    label: 'C — Stop motion',
    disponible: true,
    construireSequence: () => SEQUENCE_PREVIEW_STOP_MOTION
  }
];

// Declenche une sequence (n'importe quel scenario du banc d'essai) via la VRAIE
// executerSequenceRealisation, avec le meme nettoyage-avant-relance que fermerLiveMatchReel
// (jamais de timer orphelin entre deux clics, quel que soit le scenario). Deja generique (prend
// n'importe quelle `sequence` conforme au schema plan/couches) : ajouter un futur scenario de test
// ne demande qu'une entree dans SCENARIOS_PREVIEW_REALISATEUR -- jamais un nouveau moteur de preview.
function lancerSequencePreview(sequence, def, club, instant) {
  if (!sequence) return;
  _liveViewerTimeoutsAnimation.forEach(id => clearTimeout(id));
  _liveViewerTimeoutsAnimation = [];
  const label = document.getElementById('live-action-label');
  if (label) label.textContent = def.label + ' — ' + club.nom; // meme habillage que jouerMicroAction
  executerSequenceRealisation(sequence, instant, def, club);
}

function initPreviewRealisateur() {
  if (new URLSearchParams(window.location.search).get('footballPreview') !== '1') return;
  if (document.getElementById('live-mini-terrain')) return; // un live reel est deja monte sur cette page, on n'interfere pas

  const home = getClub('olympique-luthecia');
  const away = getClub('cheminote-montrouge');
  const def = CATALOGUE_MICRO_ACTIONS['duel'];
  const instant = { type: 'duel', cote: 'home' };

  // Boutons construits depuis SCENARIOS_PREVIEW_REALISATEUR (banc d'essai, section 2/6) -- seuls
  // les scenarios `disponible !== false` sont affiches (aucun placeholder pour un scenario dont
  // les assets ne sont pas encore livres).
  const scenariosVisibles = SCENARIOS_PREVIEW_REALISATEUR.filter(s => s.disponible !== false);
  const boutonsHtml = scenariosVisibles.map(s =>
    '<button id="preview-realisateur-btn-' + s.id + '" style="width:100%;margin-top:.4rem;font-family:\'Bebas Neue\',sans-serif;font-size:.8rem;letter-spacing:.08em;padding:.5rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">▶ ' + s.label + '</button>'
  ).join('');

  // Boutons du mode grand ecran (memes scenarios, memes ids de gabarit, prefixe "grand" pour
  // eviter toute collision avec les boutons du petit panneau).
  const boutonsGrandHtml = scenariosVisibles.map(s =>
    '<button id="preview-realisateur-grand-btn-' + s.id + '" style="font-family:\'Bebas Neue\',sans-serif;font-size:.8rem;letter-spacing:.08em;padding:.5rem 1rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">▶ ' + s.label + '</button>'
  ).join('');

  const panneau = document.createElement('div');
  panneau.id = 'preview-realisateur-panneau';
  panneau.style.cssText = 'position:fixed;top:1rem;right:1rem;z-index:500;width:340px;max-width:90vw;background:#0d0b05;border:1px solid #8a6a20;padding:.9rem;font-family:inherit;box-shadow:0 4px 20px rgba(0,0,0,.6)';
  panneau.innerHTML =
    '<div style="font-family:\'Bebas Neue\',sans-serif;letter-spacing:.08em;color:#C9A84C;font-size:.85rem;margin-bottom:.6rem">🎬 PREVIEW RÉALISATEUR — banc d\'essai</div>' +
    '<div id="preview-realisateur-mont"></div>' +
    boutonsHtml +
    '<button id="preview-realisateur-btn-grand-ecran" style="width:100%;margin-top:.6rem;font-family:\'Bebas Neue\',sans-serif;font-size:.8rem;letter-spacing:.08em;padding:.5rem;border:1px solid #7a6a48;background:transparent;color:#c0b090;cursor:pointer">⛶ Grand écran</button>' +
    '<div style="font-size:.68rem;color:#7a6a48;margin-top:.5rem">Outil de mise au point — aucune écriture championnat, aucun PA, aucun effet canonique. Aucun scénario de preview n\'apparaît en match réel.</div>';
  document.body.appendChild(panneau);

  // Overlay grand format (chantier "grand ecran", 29 aout 2026) : NE construit PAS un second
  // moteur de preview -- au clic, le shell DOM existant (#live-mini-terrain, construit UNE SEULE
  // FOIS ci-dessus par construireSceneMiniTerrain) est simplement DEPLACE (Node.appendChild sur un
  // noeud deja existant le detache et le rattache, sans clone ni nouveaux ids) depuis le petit
  // support vers ce grand support, puis inversement a la fermeture. executerSequenceRealisation/
  // jouerChoreographieCouche continuent de cibler les memes ids partout ou se trouve le noeud.
  const grandEcran = document.createElement('div');
  grandEcran.id = 'preview-realisateur-grand-ecran';
  grandEcran.style.cssText = 'display:none;position:fixed;inset:0;z-index:600;background:rgba(0,0,0,.96);flex-direction:column;align-items:center;justify-content:center;padding:2rem;box-sizing:border-box';
  grandEcran.innerHTML =
    '<div style="width:100%;max-width:1600px;display:flex;justify-content:space-between;align-items:center;margin-bottom:.8rem">' +
    '<div style="font-family:\'Bebas Neue\',sans-serif;letter-spacing:.08em;color:#C9A84C;font-size:1rem">🎬 GRAND ÉCRAN — banc d\'essai</div>' +
    '<button id="preview-realisateur-grand-fermer" style="font-family:\'Bebas Neue\',sans-serif;font-size:.8rem;letter-spacing:.08em;padding:.4rem .9rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">✕ Fermer (Échap)</button>' +
    '</div>' +
    '<div id="preview-realisateur-grand-mont" style="width:min(92vw,1600px);max-height:76vh;overflow:auto"></div>' +
    '<div style="display:flex;gap:.6rem;margin-top:1rem;flex-wrap:wrap;justify-content:center">' + boutonsGrandHtml + '</div>';
  document.body.appendChild(grandEcran);

  document.getElementById('preview-realisateur-mont').innerHTML = construireSceneMiniTerrain('preview-crash-test', home, away);

  scenariosVisibles.forEach(s => {
    document.getElementById('preview-realisateur-btn-' + s.id).addEventListener('click', () => {
      lancerSequencePreview(s.construireSequence(instant), def, home, instant);
    });
    document.getElementById('preview-realisateur-grand-btn-' + s.id).addEventListener('click', () => {
      lancerSequencePreview(s.construireSequence(instant), def, home, instant);
    });
  });

  // Deplace le shell existant (jamais de clone) du petit support vers le grand, et inversement --
  // ouverture ne touche jamais aux timers en cours (la sequence en train de jouer continue) ;
  // fermeture nettoie systematiquement (memes primitives que lancerSequencePreview) pour ne
  // jamais laisser un cadrage/zoom fige avant la prochaine ouverture.
  function ouvrirGrandEcran() {
    const scene = document.getElementById('live-mini-terrain');
    const grandMont = document.getElementById('preview-realisateur-grand-mont');
    if (!scene || !grandMont) return;
    grandMont.appendChild(scene);
    document.getElementById('preview-realisateur-grand-ecran').style.display = 'flex';
  }
  function fermerGrandEcran() {
    const overlay = document.getElementById('preview-realisateur-grand-ecran');
    if (!overlay || overlay.style.display === 'none') return;
    _liveViewerTimeoutsAnimation.forEach(id => clearTimeout(id));
    _liveViewerTimeoutsAnimation = [];
    reinitialiserSceneApresSequenceRealisation(true);
    const scene = document.getElementById('live-mini-terrain');
    const petitMont = document.getElementById('preview-realisateur-mont');
    if (scene && petitMont) petitMont.appendChild(scene);
    overlay.style.display = 'none';
  }
  document.getElementById('preview-realisateur-btn-grand-ecran').addEventListener('click', ouvrirGrandEcran);
  document.getElementById('preview-realisateur-grand-fermer').addEventListener('click', fermerGrandEcran);
  document.addEventListener('keydown', e => { if (e.key === 'Escape') fermerGrandEcran(); });
}
window.addEventListener('DOMContentLoaded', initPreviewRealisateur);

// Genere UNE FOIS (puis met en cache) la chronologie deterministe d'une phase de jeu (mt1/mt2) --
// jamais un metronome fixe (intervalles irreguliers), jamais recalculee differemment pour deux
// spectateurs (seed = identite stable matchKey+phase, jamais une tranche de temps arrondie).
// Un spectateur qui ouvre en cours de periode calcule EXACTEMENT la meme chronologie et se
// positionne simplement a l'instant present -- jamais une animation qui repart de zero.
function genererScenarioNarratifPhase(matchKey, phaseKey, dureePhaseSec) {
  const cle = matchKey + '-' + phaseKey;
  if (_liveViewerScenarioCache[cle]) return _liveViewerScenarioCache[cle];
  const rng = creerPRNGDeterministe(hashChaineVersUint32(cle));
  const scenario = [];
  let t = 1 + rng() * 3;
  while (t < dureePhaseSec - 2) {
    const cote = rng() < 0.5 ? 'home' : 'away';
    const type = CLES_TYPES_MICRO_ACTION[Math.floor(rng() * CLES_TYPES_MICRO_ACTION.length)];
    scenario.push({ t, type, cote });
    // Une remise en jeu se raconte en plusieurs temps (section 7) : ballon sorti -> touche ->
    // remise, enchaines naturellement plutot que trois tirages independants.
    if (type === 'sortie') {
      t += 1.1 + rng() * 0.6; scenario.push({ t, type: 'touche', cote });
      t += 1.4 + rng() * 0.8; scenario.push({ t, type: 'remise', cote });
    }
    // Une frappe narrative peut se resoudre par un arret local -- jamais garanti, jamais un signal
    // fiable qu'un but canonique va suivre (section 8 : pas de "grammaire qui trahit le futur").
    if (type === 'frappe' && rng() < 0.6) {
      t += 0.9 + rng() * 0.5; scenario.push({ t, type: 'arret', cote: cote === 'home' ? 'away' : 'home' });
    }
    t += 2 + rng() * 7; // intervalle irregulier avant la sequence suivante
  }
  _liveViewerScenarioCache[cle] = scenario;
  return scenario;
}

// Dernier instant du scenario dont le temps ecoule (t) est deja atteint -- purement une lecture
// de l'horloge reelle, jamais un evenement futur montre en avance.
function trouverInstantNarratifActuel(scenario, tEcouleSec) {
  let courant = null;
  for (const instant of scenario) {
    if (instant.t > tEcouleSec) break;
    courant = instant;
  }
  return courant;
}

// Limites reelles d'une phase, deduites UNIQUEMENT de live.kickoffAt (horloge canonique unique)
// et des constantes de duree deja existantes (DUREE_ECHAUFFEMENT_MS/DUREE_MT1_MS/DUREE_PAUSE_MS/
// DUREE_MT2_MS, definies plus haut dans ce fichier pour le moteur -- jamais redefinies ici).
function calculerLimitesPhase(kickoffAtDate, statut) {
  const k = kickoffAtDate.getTime();
  if (statut === 'echauffement') return { debut: k - DUREE_ECHAUFFEMENT_MS, duree: DUREE_ECHAUFFEMENT_MS };
  if (statut === 'mt1') return { debut: k, duree: DUREE_MT1_MS };
  if (statut === 'mitemps') return { debut: k + DUREE_MT1_MS, duree: DUREE_PAUSE_MS };
  if (statut === 'mt2') return { debut: k + DUREE_MT1_MS + DUREE_PAUSE_MS, duree: DUREE_MT2_MS };
  return { debut: k + DUREE_MT1_MS + DUREE_PAUSE_MS + DUREE_MT2_MS, duree: 0 };
}

// ---- Tick visuel (section 3) : intervalle local uniquement, jamais un appel reseau -- fait
// progresser le chrono affiche et la narration entre deux refresh de rafraichirLiveMatchReel
// (6s). Demarre/arrete avec la fenetre de live, jamais laisse tourner apres fermeture. ----
function demarrerTickVisuel() {
  arreterTickVisuel();
  _liveViewerTickVisuel = setInterval(tickVisuelScene, 500);
  tickVisuelScene();
}
function arreterTickVisuel() {
  if (_liveViewerTickVisuel) { clearInterval(_liveViewerTickVisuel); _liveViewerTickVisuel = null; }
}

function formaterChronoLive(phaseInfo) {
  if (phaseInfo.statut === 'echauffement') return 'ÉCHAUFFEMENT';
  if (phaseInfo.statut === 'mitemps') return 'MI-TEMPS';
  if (phaseInfo.statut === 'termine') return 'TERMINÉ';
  const m = phaseInfo.minuteFictive != null ? phaseInfo.minuteFictive : 0;
  return m + "'";
}

// Positions (%) des 7 zones le long du terrain, du but propre (0%) au but adverse (100%) --
// purement decoratif.
const POSITIONS_ZONES_POURCENT = [8, 22, 36, 50, 64, 78, 92];

function positionnerBallon(indexZoneAbsolu) {
  const ballon = document.getElementById('live-ballon');
  if (!ballon) return;
  const pct = POSITIONS_ZONES_POURCENT[Math.max(0, Math.min(6, indexZoneAbsolu))];
  ballon.style.left = pct + '%';
  ballon.style.top = (28 + Math.random() * 44) + '%'; // leger flottement vertical, purement esthetique
}
function positionnerJoueur(cote, indexZoneAbsolu) {
  const el = document.getElementById('live-joueur-' + cote);
  if (!el) return;
  const pct = POSITIONS_ZONES_POURCENT[Math.max(0, Math.min(6, indexZoneAbsolu))];
  el.style.left = pct + '%';
}

// Joue UNE sequence narrative locale : delegue au realisateur automatique -- genere une sequence
// d'un nombre quelconque de plans terrain/illustre (l'executeur n'a aucune branche speciale selon
// le nombre de plans, chantier "architecture multi-plans" du 29 aout 2026), deterministe (seed =
// matchKey+phase+instant.t, identite stable partagee par tous les spectateurs), puis l'execute.
// Purement visuel -- aucune donnee sportive lue ni ecrite ici.
function jouerMicroAction(instant, home, away, matchKey, phaseKey) {
  const def = CATALOGUE_MICRO_ACTIONS[instant.type];
  if (!def) return;
  const club = instant.cote === 'home' ? home : away;
  const label = document.getElementById('live-action-label');
  if (label) label.textContent = def.label + ' — ' + club.nom;

  const scene = document.getElementById('live-mini-terrain');
  if (scene) { scene.classList.add('live-mini-terrain--actif'); scene.classList.remove('live-mini-terrain--echauffement', 'live-mini-terrain--mitemps'); }

  // Ville HOTE = toujours celle du club home (un club joue toujours dans sa propre ville) --
  // signature de realisation resolue ici, jamais melangee a l'identite visuelle des clubs
  // (identiteVisuelleClub reste couleurs/maillot, un concept totalement separe). Aucun profil de
  // ville n'etant encore defini (PROFILS_REALISATION_VILLE vide), ceci renvoie toujours
  // PROFIL_REALISATION_DEFAUT -- zero changement de comportement tant qu'aucun profil artistique
  // n'est configure.
  const profil = profilRealisationVille(home.country, home.city);
  const seed = matchKey + '-' + phaseKey + '-' + instant.t;
  const sequence = genererSequenceRealisation(seed, { microAction: instant.type, cote: instant.cote }, profil);
  executerSequenceRealisation(sequence, instant, def, club);
}

// Ambiance hors phase de jeu (section 13) : echauffement calme, mi-temps arretee (aucune
// narration sportive, n'interfere ni avec la buvette ni avec le systeme supporters), fin figee.
function afficherAmbiancePhase(statut) {
  const label = document.getElementById('live-action-label');
  const scene = document.getElementById('live-mini-terrain');
  if (!scene) return;
  scene.classList.remove('live-mini-terrain--actif');
  if (statut === 'echauffement') {
    scene.classList.add('live-mini-terrain--echauffement');
    scene.classList.remove('live-mini-terrain--mitemps');
    if (label) label.textContent = "Échauffement…";
    positionnerBallon(3); positionnerJoueur('home', 2); positionnerJoueur('away', 4);
  } else if (statut === 'mitemps') {
    scene.classList.add('live-mini-terrain--mitemps');
    scene.classList.remove('live-mini-terrain--echauffement');
    if (label) label.textContent = 'Pause — les joueurs regagnent les vestiaires.';
  } else if (statut === 'termine') {
    if (label) label.textContent = 'Match terminé.';
  }
}

// Point d'entree du tick 500ms. File d'attente des evenements canoniques TOUJOURS prioritaire sur
// la narration locale (section 8/9) -- jamais l'inverse, jamais de melange des deux en meme temps.
function tickVisuelScene() {
  if (!_liveViewerRef || !_liveViewerSceneEtat) return;
  const { live, home, away, matchKey } = _liveViewerSceneEtat;
  const kickoff = new Date(live.kickoffAt);
  const phaseInfo = phaseMatchActuelle(kickoff, new Date());

  const chronoEl = document.getElementById('live-chrono');
  if (chronoEl) chronoEl.textContent = formaterChronoLive(phaseInfo);

  if (_liveViewerFileCanonique.length && !_liveViewerAfficheCanoniqueEnCours) {
    const ev = _liveViewerFileCanonique.shift();
    afficherInsertCanonique(ev, matchKey);
    return;
  }
  if (_liveViewerAfficheCanoniqueEnCours) return; // laisse l'insert en cours se terminer avant toute narration

  if (phaseInfo.statut !== 'mt1' && phaseInfo.statut !== 'mt2') {
    afficherAmbiancePhase(phaseInfo.statut);
    return;
  }

  const limites = calculerLimitesPhase(kickoff, phaseInfo.statut);
  const tEcouleSec = (Date.now() - limites.debut) / 1000;
  if (tEcouleSec < 0) return; // pas encore dans cette phase
  const scenario = genererScenarioNarratifPhase(matchKey, phaseInfo.statut, limites.duree / 1000);
  const instant = trouverInstantNarratifActuel(scenario, tEcouleSec);
  if (instant && instant !== _liveViewerDernierInstantAffiche) {
    _liveViewerDernierInstantAffiche = instant;
    jouerMicroAction(instant, home, away, matchKey, phaseInfo.statut);
  }
}

const LABELS_PHASE_LIVE = {
  echauffement: 'ÉCHAUFFEMENT', mt1: '1ʳᵉ PÉRIODE', mitemps: 'MI-TEMPS', mt2: '2ᵉ PÉRIODE', termine: 'TERMINÉ'
};
const ICONES_EVENEMENT_LIVE = {
  composition: '📋', debut: '🟢', but: '⚽', occasion: '💥', carton: '🟨', action: 'ℹ️',
  blessure: '🚑', mitemps: '⏸️', reprise: '🔄', fin: '🏁'
};

// ---- Portraits PJ (section 11) : reutilise personnages.photo_url (colonne existante, deja lue
// ailleurs dans le jeu -- getPnjAvatar/sbSavePersonnage). Meme patron que sbListJoueursLicencies
// (lecture large filtree cote client, jamais un champ prive comme performance_sportive). Cache
// par match : une seule lecture reseau, jamais relue a chaque tick 6s. ----
async function chargerPortraitsMatch(matchKey, live) {
  if (_liveViewerPortraitsCache[matchKey]) return _liveViewerPortraitsCache[matchKey];
  const cache = {};
  const noms = [
    ...(live.compositionFigee?.home?.titulaires || []).map(t => t.nom),
    ...(live.compositionFigee?.away?.titulaires || []).map(t => t.nom)
  ];
  if (typeof sbGet === 'function' && noms.length) {
    // Correctif du 28 aout 2026 : cible desormais UNIQUEMENT les ~22 titulaires de CE match (OR de
    // name.eq., chaque valeur encodee individuellement -- meme patron que name=eq.${encodeURIComponent(...)}
    // deja utilise partout ailleurs dans ce fichier, jamais un in.() quote a la main), au lieu de
    // lire tous les joueurs licencies puis filtrer cote client. select limite a name,photo_url.
    const filtre = 'or=(' + noms.map(n => 'name.eq.' + encodeURIComponent(n)).join(',') + ')&select=name,photo_url';
    const rows = await sbGet('personnages', filtre).catch(() => []);
    (rows || []).forEach(r => { cache[r.name] = r.photo_url || null; });
  }
  _liveViewerPortraitsCache[matchKey] = cache;
  return cache;
}

// Rendu d'un portrait -- fallback generique propre si aucune photo, jamais de tentative
// d'attribuer une photo a un nom fictif (club.vedettes) : ces noms n'apparaissent jamais dans le
// cache (construit uniquement a partir de compositionFigee, jamais des vedettes de repli).
function rendrePortraitJoueur(nom, matchKey, taillePx) {
  const taille = taillePx || 32;
  const url = (_liveViewerPortraitsCache[matchKey] || {})[nom];
  if (url) {
    return '<img src="' + url + '" class="live-portrait-joueur" style="width:' + taille + 'px;height:' + taille + 'px" alt="' + nom.replace(/"/g, '') + '"/>';
  }
  return '<div class="live-portrait-joueur live-portrait-fallback" style="width:' + taille + 'px;height:' + taille + 'px"><i class="ti ti-user"></i></div>';
}

// ---- Insert "BD" (section 10) : conteneur en couches (fond/action/portrait/texte), CACHE par
// defaut. Affiche un PLACEHOLDER esthetique et clairement identifiable par type d'evenement
// canonique -- aucune illustration definitive ; le futur asset remplacera le fond/l'action sans
// changement de structure (mêmes ids, mêmes couches). ----
function afficherInsertCanonique(evenement, matchKey) {
  _liveViewerAfficheCanoniqueEnCours = true;
  const insert = document.getElementById('live-insert-bd');
  if (!insert) { _liveViewerAfficheCanoniqueEnCours = false; return; }
  const actionEl = document.getElementById('live-insert-bd-action');
  const portraitEl = document.getElementById('live-insert-bd-portrait');
  const texteEl = document.getElementById('live-insert-bd-texte');

  const icone = ICONES_EVENEMENT_LIVE[evenement.type] || '⚽';
  if (actionEl) actionEl.textContent = icone;
  if (texteEl) texteEl.textContent = evenement.texte || '';
  if (portraitEl) portraitEl.innerHTML = evenement.joueur ? rendrePortraitJoueur(evenement.joueur, matchKey, 64) : '';

  const label = document.getElementById('live-action-label');
  if (label) label.textContent = '';

  insert.className = 'live-insert-bd live-insert-bd-visible live-insert-bd-' + evenement.type;

  const idT = setTimeout(() => {
    insert.classList.remove('live-insert-bd-visible');
    insert.className = 'live-insert-bd';
    _liveViewerAfficheCanoniqueEnCours = false;
  }, 3400);
  _liveViewerTimeoutsAnimation.push(idT);
}

// ---- Tribunes visuelles (section 12) : densite + message discret d'arrivee, purement
// decoratifs. compterSupportersActifs() reste l'unique source (deja existante, mecanique
// sportive inchangee) -- ici uniquement un diff LOCAL de deux instantanes successifs pour
// detecter une arrivee, jamais une nouvelle persistance. ----
function mettreAJourTribunesVisuelles(supporters, home, away) {
  const identites = { home: home ? identiteVisuelleClub(home.id) : null, away: away ? identiteVisuelleClub(away.id) : null };
  ['home', 'away'].forEach(cote => {
    const dotsEl = document.getElementById('live-tribune-' + cote + '-dots');
    if (dotsEl) {
      const n = Math.min(supporters[cote].count, 24);
      const identite = identites[cote];
      const styleDot = identite ? ' style="background:' + identite.colorPrimaire + '"' : '';
      dotsEl.innerHTML = ('<span class="live-tribune-dot"' + styleDot + '></span>').repeat(n);
    }
    if (!_liveViewerPremierRafraichissement) {
      const anciens = _liveViewerNomsSupportersConnus[cote] || [];
      const arrivee = supporters[cote].noms.find(n => !anciens.includes(n));
      if (arrivee) afficherMessageTribune(arrivee + ' rejoint les tribunes ' + (cote === 'home' ? 'domicile' : 'extérieur') + ' !');
    }
    _liveViewerNomsSupportersConnus[cote] = supporters[cote].noms;
  });
}
function afficherMessageTribune(texte) {
  const el = document.getElementById('live-message-tribune');
  if (!el) return;
  el.textContent = texte;
  el.classList.remove('live-message-tribune-visible');
  void el.offsetWidth; // force le reflow pour pouvoir rejouer l'animation d'entree
  el.classList.add('live-message-tribune-visible');
}

function classeEvenementLive(type) {
  if (type === 'but') return 'live-event live-event-but';
  if (type === 'carton') return 'live-event live-event-carton';
  if (type === 'blessure') return 'live-event live-event-blessure';
  if (type === 'mitemps' || type === 'reprise' || type === 'fin' || type === 'debut') return 'live-event live-event-marqueur';
  if (type === 'occasion') return 'live-event live-event-occasion';
  return 'live-event';
}

function renderCarteEvenementLive(e, estNouveau) {
  const icone = ICONES_EVENEMENT_LIVE[e.type] || '•';
  const cls = classeEvenementLive(e.type) + (estNouveau ? ' live-event-nouveau' : '');
  const minuteTxt = (e.minute != null && e.type !== 'composition') ? '<span class="live-event-minute">' + e.minute + "'</span>" : '';
  return '<div class="' + cls + '">' + minuteTxt + '<span class="live-event-icone">' + icone + '</span><span class="live-event-texte">' + e.texte + '</span></div>';
}

function renderEnTeteLive(home, away, scoreHome, scoreAway, phaseInfo) {
  let html = '<div class="live-entete">';
  html += '<div class="live-phase-badge live-phase-' + phaseInfo.statut + '">' + (LABELS_PHASE_LIVE[phaseInfo.statut] || '') + (phaseInfo.minuteFictive != null ? ' · ' + phaseInfo.minuteFictive + "'" : '') + '</div>';
  html += '<div class="live-score-ligne">';
  html += '<span class="live-club-nom">' + home.nom + '</span>';
  html += '<span class="live-score">' + scoreHome + ' - ' + scoreAway + '</span>';
  html += '<span class="live-club-nom">' + away.nom + '</span>';
  html += '</div></div>';
  return html;
}

// Trouve, dans la saison DEJA CHARGEE, la journee dont le coup d'envoi est en fenetre "live"
// (echauffement -> termine inclus, pour laisser le temps a l'ecran de detecter la toute fin) --
// utilise a la fois par le badge et par doRegarderLiveOuResume.
function trouverJourneeLiveActuelle(saison) {
  if (!saison || saison.phase !== 'reguliere') return null;
  const prochaine = saison.calendrier.find(j => !j.matchs.every(m => m.played));
  if (!prochaine) return null;
  const kickoff = calculerKickoffJournee(saison, prochaine.numero);
  const phaseInfo = phaseMatchActuelle(kickoff, new Date());
  if (phaseInfo.statut === 'a_venir') return null;
  return { journee: prochaine, kickoff, phaseInfo };
}

async function doRegarderLiveOuResume() {
  document.getElementById('postes-modal-title').textContent = 'Football';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const saison = await chargerOuInitialiserSaison();
  const actuel = trouverJourneeLiveActuelle(saison);
  if (actuel && actuel.phaseInfo.statut !== 'termine') {
    const idx = actuel.journee.matchs.findIndex(m => !m.played);
    if (idx >= 0) { ouvrirLiveMatchReel(actuel.journee.numero, idx); return; }
  }

  let derniereJournee = null;
  for (let i = saison.calendrier.length - 1; i >= 0; i--) {
    if (saison.calendrier[i].matchs.every(m => m.played)) { derniereJournee = saison.calendrier[i]; break; }
  }
  if (!derniereJournee) {
    document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#5a5040;font-style:italic">Aucun match joué pour l\'instant. Revenez après la première journée.</div>';
    return;
  }

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;margin-bottom:.6rem">Résumés — Journée ' + derniereJournee.numero + '</div>';
  derniereJournee.matchs.forEach((m, idx) => {
    html += '<button onclick="ouvrirResumeMatch(' + derniereJournee.numero + ',' + idx + ')" style="width:100%;text-align:left;margin-bottom:.4rem;padding:.55rem .7rem;border:1px solid #2a2010;background:transparent;color:#c0b090;cursor:pointer;font-size:.8rem">' + getClub(m.home).nom + ' <b style="color:#C9A84C">' + m.scoreHome + ' - ' + m.scoreAway + '</b> ' + getClub(m.away).nom + '</button>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

// Resume d'un match DEJA TERMINE (played:true) -- ancien afficherLiveMatch, renomme et clairement
// etiquete comme tel (jamais presente comme un live). Fonctionne a l'identique pour un match
// resolu par l'ancien systeme (evenements generes en bloc) ou par le nouveau moteur live
// (evenements deja tous presents, car m.evenements est copie depuis m.live.evenements a la
// finalisation) -- aucune distinction necessaire cote affichage, retro-compatibilite totale.
function ouvrirResumeMatch(numeroJournee, matchIdx) {
  fermerLiveMatchReel();
  chargerOuInitialiserSaison().then(saison => {
    const journee = saison.calendrier.find(j => j.numero === numeroJournee);
    const m = journee?.matchs?.[matchIdx];
    if (!m) return;
    const home = getClub(m.home), away = getClub(m.away);
    const evenements = m.evenements || genererEvenementsMatch(home, away, m.scoreHome, m.scoreAway);

    document.getElementById('postes-modal-title').textContent = home.nom + ' vs ' + away.nom;
    let html = '<div class="live-container">';
    html += '<div class="live-resume-etiquette">RÉSUMÉ DU MATCH</div>';
    html += renderEnTeteLive(home, away, m.scoreHome, m.scoreAway, { statut: 'termine', minuteFictive: null });
    html += '<div class="live-fil-evenements">';
    evenements.forEach(e => { html += renderCarteEvenementLive(e, false); });
    html += '</div></div>';
    document.getElementById('postes-body').innerHTML = html;
  });
}

// Construit UNE FOIS le shell persistant du mini-terrain (section 5) : pelouse, ballon, jetons
// joueurs, tribunes symboliques, insert BD (placeholder), chrono/libelle d'action. N'est plus
// jamais recree tant que le match regarde reste le meme -- rafraichirLiveMatchReel ne fait ensuite
// que des mises a jour CIBLEES de ses sous-elements (textContent/className/style), jamais un
// remplacement d'innerHTML de ce bloc.
function construireSceneMiniTerrain(matchKey, home, away) {
  // Habillage automatique par match (section 4, chantier identites visuelles) : les jetons
  // joueurs reprennent la couleur principale du club reellement domicile/exterieur de CETTE
  // rencontre (resolue via identiteVisuelleClub(home.id)/identiteVisuelleClub(away.id)), jamais
  // une couleur fixe Luthecia/Republia. Repli sur les couleurs generiques existantes (CSS) si un
  // club n'a exceptionnellement pas d'identite definie.
  const identiteHome = identiteVisuelleClub(home.id);
  const identiteAway = identiteVisuelleClub(away.id);
  const styleJoueurHome = identiteHome ? ' style="background:' + identiteHome.colorPrimaire + '"' : '';
  const styleJoueurAway = identiteAway ? ' style="background:' + identiteAway.colorPrimaire + '"' : '';

  let html = '<div class="live-mini-terrain" id="live-mini-terrain">';
  html += '<div class="live-mini-terrain-entete">';
  html += '<div class="live-phase-badge" id="live-phase-badge"></div>';
  html += '<div class="live-chrono" id="live-chrono"></div>';
  html += '</div>';
  html += '<div class="live-mini-terrain-score">';
  html += '<span class="live-club-nom">' + home.nom + '</span>';
  html += '<span class="live-score" id="live-score-mini">0 - 0</span>';
  html += '<span class="live-club-nom">' + away.nom + '</span>';
  html += '</div>';
  html += '<div class="live-pelouse">';
  html += '<div class="live-pelouse-lignes"></div>';
  html += '<div class="live-but live-but-home"></div><div class="live-but live-but-away"></div>';
  html += '<div class="live-joueur live-joueur-home" id="live-joueur-home"' + styleJoueurHome + '></div>';
  html += '<div class="live-joueur live-joueur-away" id="live-joueur-away"' + styleJoueurAway + '></div>';
  html += '<div class="live-ballon" id="live-ballon">⚽</div>';
  html += '<div class="live-insert-bd" id="live-insert-bd">';
  html += '<div class="live-insert-bd-fond"></div>';
  html += '<div class="live-insert-bd-action" id="live-insert-bd-action"></div>';
  html += '<div class="live-insert-bd-portrait" id="live-insert-bd-portrait"></div>';
  html += '<div class="live-insert-bd-texte" id="live-insert-bd-texte"></div>';
  html += '</div>';
  // Plan illustre du realisateur automatique (chantier "premiere passe du realisateur", 28 aout
  // 2026) : meme langage visuel que l'insert canonique ci-dessus, id DISTINCT expres -- jamais le
  // meme element, pour ne jamais interferer avec un insert d'evenement canonique (afficherInsertCanonique
  // reste seul proprietaire de #live-insert-bd, intouche par ce chantier).
  html += '<div class="live-insert-bd" id="live-realisateur-illustre">';
  html += '<div class="live-insert-bd-fond"></div>';
  // Premier vrai asset du realisateur (29 aout 2026) : <img> persistante, masquee par defaut
  // (display:none) et sans src -- appliquerPlanIllustreRealisation ne la montre que pour les
  // couches qui portent explicitement `asset` (aujourd'hui : uniquement GABARIT_CRASH_TEST_RAS_DU_SOL).
  html += '<img class="live-insert-bd-image" id="live-realisateur-illustre-image" alt="" />';
  html += '<div class="live-insert-bd-action"></div>';
  html += '<div class="live-insert-bd-texte"></div>';
  html += '</div>';
  html += '</div>';
  html += '<div class="live-action-label" id="live-action-label"></div>';
  html += '<div class="live-tribunes-symboliques">';
  html += '<div class="live-tribune-symbolique"><div class="live-tribune-dots" id="live-tribune-home-dots"></div><div class="live-tribune-symbolique-nom">' + home.nom + '</div></div>';
  html += '<div class="live-tribune-symbolique"><div class="live-tribune-dots" id="live-tribune-away-dots"></div><div class="live-tribune-symbolique-nom">' + away.nom + '</div></div>';
  html += '</div>';
  html += '<div class="live-message-tribune" id="live-message-tribune"></div>';
  html += '</div>';
  return html;
}

// VRAI live, synchronise pour tous les spectateurs : chaque rafraichissement relit (et fait
// avancer, si personne d'autre ne l'a deja fait) l'etat AUTORITAIRE persiste -- jamais de
// pre-calcul local, jamais d'evenement invente cote client. Un joueur qui ouvre en cours de match
// recoit directement la phase/le score/les evenements deja survenus ; fermer puis rouvrir relit
// simplement le meme etat, rien n'est jamais rejoue depuis le debut.
async function ouvrirLiveMatchReel(numeroJournee, matchIdx) {
  fermerLiveMatchReel();
  _liveViewerRef = { journeeNumero: numeroJournee, matchIdx };
  _liveViewerNbEvenementsConnus = 0;
  document.getElementById('postes-modal-title').textContent = 'Live';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Connexion au direct...</div>';
  document.getElementById('modal-postes').classList.add('open');

  await rafraichirLiveMatchReel();
  _liveViewerInterval = setInterval(rafraichirLiveMatchReel, 6000);
}

async function rafraichirLiveMatchReel() {
  if (!_liveViewerRef) return;
  if (typeof avancerFootballLive === 'function') await avancerFootballLive().catch(() => {});
  const saison = await chargerOuInitialiserSaison();
  const journee = saison?.calendrier?.find(j => j.numero === _liveViewerRef.journeeNumero);
  const m = journee?.matchs?.[_liveViewerRef.matchIdx];
  if (!m) { fermerLiveMatchReel(); return; }

  const home = getClub(m.home), away = getClub(m.away);
  const matchKey = _liveViewerRef.journeeNumero + '-' + m.home + '-' + m.away;

  if (m.played) {
    // Le match vient de se terminer (ou etait deja termine) : bascule silencieusement sur le
    // resume, meme fenetre, jamais de rechargement de la page.
    fermerLiveMatchReel();
    ouvrirResumeMatch(_liveViewerRef ? _liveViewerRef.journeeNumero : journee.numero, journee.matchs.indexOf(m));
    return;
  }

  const live = m.live;
  if (!live || !live.compositionFigee) {
    arreterTickVisuel();
    _liveViewerSceneMatchKey = null;
    document.getElementById('postes-modal-title').textContent = home.nom + ' vs ' + away.nom;
    document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060;font-style:italic">Les compositions ne sont pas encore annoncées. Revenez juste avant l\'échauffement.</div>';
    return;
  }
  const kickoff = new Date(live.kickoffAt);
  const phaseInfo = phaseMatchActuelle(kickoff, new Date());

  document.getElementById('postes-modal-title').textContent = home.nom + ' vs ' + away.nom;

  // Shell PERSISTANT construit une seule fois (a l'ouverture, ou si on bascule sur un autre
  // match) -- jamais recree a chaque refresh 6s (section 5).
  if (_liveViewerSceneMatchKey !== matchKey) {
    document.getElementById('postes-body').innerHTML =
      '<div class="live-container">' + construireSceneMiniTerrain(matchKey, home, away) + '<div id="live-donnees-dynamiques"></div></div>';
    _liveViewerSceneMatchKey = matchKey;
    _liveViewerDernierInstantAffiche = null;
    demarrerTickVisuel();
  }
  _liveViewerSceneEtat = { live, home, away, matchKey };

  // Detection des evenements canoniques NOUVEAUX -- jamais ceux deja connus a l'ouverture (pas de
  // rejeu en insert de tout l'historique quand on rejoint en cours de match, section 2/9).
  if (!_liveViewerPremierRafraichissement) {
    for (let i = _liveViewerNbEvenementsConnus; i < live.evenements.length; i++) {
      const e = live.evenements[i];
      if (['but', 'occasion', 'carton', 'blessure', 'debut', 'mitemps', 'reprise', 'fin'].includes(e.type)) {
        _liveViewerFileCanonique.push(e);
      }
    }
  }

  // Dernier joueur mis en evidence : le plus recent evenement NOUVEAU (jamais encore rendu) qui
  // implique un vrai PJ -- purement cosmetique, section 9.
  let joueurEnEvidence = null;
  for (let i = live.evenements.length - 1; i >= _liveViewerNbEvenementsConnus; i--) {
    if (live.evenements[i].joueur) { joueurEnEvidence = live.evenements[i].joueur; break; }
  }

  await chargerPortraitsMatch(matchKey, live);

  // Mises a jour CIBLEES du shell persistant (jamais un remplacement complet de son innerHTML).
  const badge = document.getElementById('live-phase-badge');
  if (badge) { badge.textContent = LABELS_PHASE_LIVE[phaseInfo.statut] || ''; badge.className = 'live-phase-badge live-phase-' + phaseInfo.statut; }
  const scoreMini = document.getElementById('live-score-mini');
  if (scoreMini) scoreMini.textContent = live.scoreHome + ' - ' + live.scoreAway;

  const supporters = await compterSupportersActifs(home, away, live).catch(() => ({ home: { count: 0, noms: [] }, away: { count: 0, noms: [] } }));
  mettreAJourTribunesVisuelles(supporters, home, away);

  // Choix de camp : propose uniquement a un vrai spectateur (jamais a un titulaire, deja engage
  // sportivement) n'ayant pas encore choisi pour CE match -- immuable une fois fait.
  const moi = state.char?.name;
  const jeSuisTitulaire = moi && (
    live.compositionFigee.home.titulaires.some(t => t.nom === moi) ||
    live.compositionFigee.away.titulaires.some(t => t.nom === moi)
  );
  let htmlDonnees = '';
  if (moi && !jeSuisTitulaire && !(live.supportersChoix && live.supportersChoix[moi])) {
    htmlDonnees += renderChoixCamp(_liveViewerRef.journeeNumero, _liveViewerRef.matchIdx, home, away);
  }
  htmlDonnees += renderPanneauTribunes(supporters, home, away);
  htmlDonnees += renderPanneauTerrain(live, home, away, joueurEnEvidence);
  htmlDonnees += '<div class="live-fil-evenements" id="live-fil-evenements">';
  live.evenements.forEach((e, i) => { htmlDonnees += renderCarteEvenementLive(e, i >= _liveViewerNbEvenementsConnus); });
  htmlDonnees += '</div>';
  const zoneDynamique = document.getElementById('live-donnees-dynamiques');
  if (zoneDynamique) zoneDynamique.innerHTML = htmlDonnees;

  _liveViewerNbEvenementsConnus = live.evenements.length;
  _liveViewerPremierRafraichissement = false;
}

function renderChoixCamp(journeeNumero, matchIdx, home, away) {
  let html = '<div class="live-choix-camp">';
  html += '<div class="live-choix-camp-titre">Quel camp soutenez-vous ?</div>';
  html += '<div class="live-choix-camp-boutons">';
  html += '<button onclick="confirmerChoixCampSupporter(' + journeeNumero + ',' + matchIdx + ',\'home\')">' + home.nom + '</button>';
  html += '<button onclick="confirmerChoixCampSupporter(' + journeeNumero + ',' + matchIdx + ',\'away\')">' + away.nom + '</button>';
  html += '<button onclick="confirmerChoixCampSupporter(' + journeeNumero + ',' + matchIdx + ',\'neutre\')">Spectateur neutre</button>';
  html += '</div></div>';
  return html;
}

async function confirmerChoixCampSupporter(journeeNumero, matchIdx, choix) {
  await choisirCampSupporter(journeeNumero, matchIdx, choix);
  await rafraichirLiveMatchReel();
}

// Effectifs des tribunes -- affiche les NOMBRES ET LES NOMS (jamais la formule/le calcul interne,
// section 7/8).
function renderPanneauTribunes(supporters, home, away) {
  let html = '<div class="live-panneau">';
  html += '<div class="live-panneau-titre">TRIBUNES</div>';
  html += '<div class="live-tribunes-grille">';
  [{ club: home, s: supporters.home }, { club: away, s: supporters.away }].forEach(cote => {
    html += '<div class="live-tribune-camp">';
    html += '<div class="live-tribune-entete"><span>' + cote.club.nom + '</span><b>' + cote.s.count + ' supporter' + (cote.s.count > 1 ? 's' : '') + '</b></div>';
    if (cote.s.noms.length) {
      html += '<div class="live-tribune-noms">' + cote.s.noms.map(n => '<span class="live-tribune-nom">' + n + '</span>').join('') + '</div>';
    }
    html += '</div>';
  });
  html += '</div></div>';
  return html;
}

// Vrais titulaires de la composition figee, identifiables par leur nom -- jamais de caracteristique
// privee affichee, uniquement les evenements du match auquel ils ont deja ete meles (section 9).
function renderPanneauTerrain(live, home, away, joueurEnEvidence) {
  function icones(nom) {
    let but = 0, carton = 0, blessure = 0;
    (live.evenements || []).forEach(e => {
      if (e.joueur !== nom) return;
      if (e.type === 'but') but++; else if (e.type === 'carton') carton++; else if (e.type === 'blessure') blessure++;
    });
    let s = '';
    if (but) s += ' ' + '⚽'.repeat(Math.min(but, 3));
    if (carton) s += ' 🟨';
    if (blessure) s += ' 🚑';
    return s;
  }
  function listeCote(titulaires) {
    return (titulaires || []).map(t =>
      '<div class="live-terrain-joueur' + (t.nom === joueurEnEvidence ? ' live-terrain-joueur-actif' : '') + '">' + t.nom + icones(t.nom) + '</div>'
    ).join('');
  }
  let html = '<div class="live-panneau">';
  html += '<div class="live-panneau-titre">SUR LE TERRAIN</div>';
  html += '<div class="live-terrain-equipes">';
  html += '<div class="live-terrain-camp"><div class="live-terrain-club">' + home.nom + '</div>' + listeCote(live.compositionFigee.home.titulaires) + '</div>';
  html += '<div class="live-terrain-camp"><div class="live-terrain-club">' + away.nom + '</div>' + listeCote(live.compositionFigee.away.titulaires) + '</div>';
  html += '</div></div>';
  return html;
}

// "SOIR DE MATCH !" (chantier "football live", 28 aout 2026, section 9) -- ouverte automatiquement
// (voir tickFootballLive) au tout debut de l'echauffement pour un PJ effectivement titulaire et
// connecte a cet instant. Fermer cette fenetre ne change rien a l'immobilisation (voir le verrou
// central dans doOrder, plateau-router.js) : #soir-de-match-animation-zone est un point d'insertion
// prepare pour une future animation/media personnalise (chantier separe, non traite ici) --
// actuellement un simple accessoire CSS generique, jamais une "personnalisation" au sens demande.
function ouvrirSoirDeMatch(verrou) {
  const heureFin = verrou.finPrevue.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
  document.getElementById('postes-modal-title').textContent = 'Football';
  let html = '<div class="soir-de-match">';
  html += '<div class="soir-de-match-titre">SOIR DE MATCH !</div>';
  html += '<div class="soir-de-match-texte">Vous êtes titulaire et vous vous échauffez.</div>';
  html += '<div class="soir-de-match-infos">' + verrou.club.nom + ' vs ' + verrou.adversaire.nom + ' — fin prévue à ' + heureFin + '.</div>';
  html += '<div id="soir-de-match-animation-zone" class="soir-de-match-animation-zone"><div class="soir-de-match-animation-placeholder">⚽</div></div>';
  html += '<button onclick="ouvrirLiveDepuisVerrou()" class="soir-de-match-bouton">Rejoindre le direct</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function ouvrirLiveDepuisVerrou() {
  if (!state.matchEnCoursTitulaire) return;
  ouvrirLiveMatchReel(state.matchEnCoursTitulaire.journeeNumero, state.matchEnCoursTitulaire.matchIdx);
}

// Point d'entree unique du "tick" football rapide (voir plateau-core.js, intervalle dedie) :
// fait avancer le moteur live, rafraichit le verrou d'immobilisation du joueur courant, declenche
// "SOIR DE MATCH !" une seule fois par match, et met a jour le badge persistant de reouverture.
async function tickFootballLive() {
  if (typeof avancerFootballLive === 'function') await avancerFootballLive().catch(() => {});
  if (typeof chargerOuInitialiserSaison !== 'function') return;
  const saison = await chargerOuInitialiserSaison().catch(() => null);
  if (!saison) return;

  const verrou = state.char?.name ? trouverVerrouMatchPourJoueur(saison, state.char.name) : null;
  state.matchEnCoursTitulaire = verrou;

  if (verrou && verrou.statutPhase === 'echauffement') {
    if (state._soirDeMatchAffichePour !== verrou.matchKey) {
      state._soirDeMatchAffichePour = verrou.matchKey;
      ouvrirSoirDeMatch(verrou);
    }
  } else if (!verrou) {
    state._soirDeMatchAffichePour = null;
  }

  verifierPopupRepriseStade(saison);
  renderBadgeFootballLive(verrou, saison);
}

// "LE MATCH REPREND !" (section 6, chantier "supporters", 28 aout 2026) -- des que la seconde
// periode commence, tout PJ actuellement dans l'enceinte du Stade (n'importe quelle piece : la
// buvette y compris, section 5) de la ville hote reçoit cette pop-up une seule fois par match
// (garde state._repriseAffichePour). Fermer la fenetre ne bloque rien -- juste une invitation.
function verifierPopupRepriseStade(saison) {
  const actuel = trouverJourneeLiveActuelle(saison);
  if (!actuel || actuel.phaseInfo.statut !== 'mt2') return;
  if (!state.char?.name || !state.currentBuilding || !state.currentCity) return;

  for (let idx = 0; idx < actuel.journee.matchs.length; idx++) {
    const m = actuel.journee.matchs[idx];
    if (m.played || !m.live || m.live.statut !== 'mt2') continue;
    const clubHome = getClub(m.home);
    const matchKey = actuel.journee.numero + '-' + m.home + '-' + m.away;
    if (state._repriseAffichePour === matchKey) continue;
    const dansEnceinte = state.country === clubHome.country && state.currentCity === clubHome.city
      && state.currentBuilding === (clubHome.stadeBuilding || 'stade');
    if (!dansEnceinte) continue;
    state._repriseAffichePour = matchKey;
    ouvrirPopupRepriseStade(actuel.journee.numero, idx);
    return;
  }
}

function ouvrirPopupRepriseStade(journeeNumero, matchIdx) {
  document.getElementById('postes-modal-title').textContent = 'Football';
  let html = '<div class="soir-de-match">';
  html += '<div class="soir-de-match-titre" style="font-size:1.5rem">LE MATCH REPREND !</div>';
  html += '<div class="soir-de-match-texte">Videz vos verres, le match reprend.<br>On a besoin de vous !</div>';
  html += '<button onclick="ouvrirLiveMatchReel(' + journeeNumero + ',' + matchIdx + ')" class="soir-de-match-bouton">Retourner en tribune</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// Badge persistant (topbar) -- accessible, jamais cache/obscur (section 10) : visible pour un
// titulaire immobilise (rejoint directement SON match) OU pour n'importe quel spectateur des
// qu'un match est en cours (le live reste consultable sans etre titulaire, section 19).
function renderBadgeFootballLive(verrou, saison) {
  const badge = document.getElementById('football-live-badge');
  if (!badge) return;
  if (verrou) {
    badge.style.display = '';
    badge.textContent = '⚽ ' + verrou.club.nom + ' — ' + (LABELS_PHASE_LIVE[verrou.statutPhase] || '');
    badge.onclick = function () { ouvrirLiveMatchReel(verrou.journeeNumero, verrou.matchIdx); };
    return;
  }
  const actuel = trouverJourneeLiveActuelle(saison);
  if (actuel && actuel.phaseInfo.statut !== 'termine') {
    const idx = actuel.journee.matchs.findIndex(m => !m.played);
    if (idx >= 0) {
      badge.style.display = '';
      badge.textContent = '⚽ Match en direct';
      badge.onclick = function () { ouvrirLiveMatchReel(actuel.journee.numero, idx); };
      return;
    }
  }
  badge.style.display = 'none';
}

// Correctif du 25 aout 2026 (audit comparatif des 3 clubs, anomalie §1) : le chef/fondateur par
// defaut d'un club de supporters etait code en dur sur 'Alfredo Mifassole (PNJ)', le meneur de
// Luthecia -- correct pour Luthecia mais errone a PSM/Montrouge, ou ce nom n'apparait nulle part.
// Derive desormais le PNJ REELLEMENT affiche dans la room siege_supporters de cette ville : le
// roomOverride specifique s'il existe (Luthecia -> Alfredo Mifassole, inchange), sinon le PNJ
// generique de la definition de base partagee (BUILDINGS.stade -- 'Meneur des Supporters (PNJ)',
// deja ce qui est visuellement affiche a PSM/Montrouge aujourd'hui, faute de PNJ dedie dans les
// donnees). N'invente aucune nouvelle identite : si aucune donnee ne permet de determiner un PNJ
// precis, le repli generique deja existant est utilise tel quel.
function getMeneurSupportersLocal() {
  const ctx = typeof getBuildingContext === 'function' ? getBuildingContext('stade') : null;
  const personsOverride = ctx?.roomOverrides?.siege_supporters?.persons;
  if (personsOverride && personsOverride.length > 0) return personsOverride[0].name;
  const personsBase = (typeof BUILDINGS !== 'undefined') ? BUILDINGS?.stade?.rooms?.siege_supporters?.persons : null;
  return (personsBase && personsBase[0]?.name) || 'Meneur des Supporters (PNJ)';
}

async function doRejoindreClubSupporters(pa, cost) {
  if (!state.organisations) state.organisations = [];
  const pays = state.country || 'republic';
  const ville = state.currentCity || 'capitale';
  const clubLocal = getClubLocal();
  if (!clubLocal) { showToast('Indisponible', 'Aucun club local ici.', false); return; }

  let orga = state.organisations.find(o => o.type === 'supporters' && o.country === pays && o.city === ville);

  const dejaMembre = orga?.membres?.some(m => m.nom === state.char?.name);
  if (dejaMembre) { showToast('Déjà membre', 'Vous êtes déjà membre du club de supporters de ' + clubLocal.nom + '.', false); return; }

  // Avant Phase K, le PA (1) etait deduit ici sans jamais respecter TEST_MODE (bug decouvert
  // lors de la migration -- seul le cout (alors 150 FR) etait correctement verifie). Cout ramene
  // a 50 FR le 25 aout 2026 (lot logistique portuaire, §13, "cotisations non eternelles") pour
  // s'aligner sur le meme principe d'adhesion que le Syndicat des Dockers de PSM -- desormais
  // jamais eternelle, voir renouvellerCotisationsOrganisations (api/cron-minuit.js).
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('Fonds insuffisants', '50 FR requis pour l\'adhésion.', false); return; }

  const def = TYPES_ORGANISATIONS.supporters;
  const grades = def?.grades?.[pays] || ['Sympathisant', 'Membre', 'Ultra', 'Meneur'];
  const saison = await chargerOuInitialiserSaison();

  if (!orga) {
    const meneurLocal = getMeneurSupportersLocal();
    orga = {
      id: 'orga_supporters_' + pays + '_' + ville,
      type: 'supporters',
      nom: 'Club de Supporters — ' + clubLocal.nom,
      desc: 'Les fidèles du ' + clubLocal.nom + '.',
      fondateur: meneurLocal, chef: meneurLocal, chefEstPnj: true,
      country: pays, city: ville, country_origine: pays,
      creeLe: state.day || 1,
      membres: [], demandesAdhesion: [],
      bonusLocaux: { pop:0, inf:0, dis:0 }, caisse: 0,
      election: null,
      visible: true
    };
    state.organisations.push(orga);
  }

  orga.membres.push({ nom: state.char?.name, grade: grades[0], gradeIdx: 0, rejointLe: state.day || 1, derniereCotisationSaison: saison.numero });
  sauvegarderOrga(orga);

  document.getElementById('modal-postes')?.classList.remove('open');
  updateUI();
  showToast('Bienvenue !', 'Vous êtes désormais ' + grades[0] + ' du club de supporters — ' + clubLocal.nom + '.', true, true);
  addJournalEntry('Adhésion au club de supporters du ' + clubLocal.nom + ' (-50 FR).', 'event-good');
  await crediterBudgetClub(clubLocal.id, cost, 'Cotisation supporter');

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

// Syndicat des Dockers de Port-Sainte-Marie (lot du 25 aout 2026, correctif blocus_portuaire).
// Etienne Dantafasse ("President du Syndicat des Dockers de Port-Sainte-Marie", data.js) etait
// purement decoratif jusqu'ici -- job:null, aucune organisation reelle ne le referencait, aucun
// PJ ne pouvait donc jamais en etre reellement "le chef". Cree paresseusement selon exactement
// le meme principe que le club de supporters ci-dessus (doRejoindreClubSupporters, id
// deterministe, chef PNJ par defaut) au lieu d'une nouvelle organisation permanente pre-semee :
// meme table state.organisations, meme sauvegarderOrga(), meme mecanisme d'election generique
// et deja type-agnostique (verifierElectionsOrganisations) -- aucun nouveau systeme de
// permission. Seule vraie difference avec le club de supporters : la creation est declenchee par
// une simple visite de la room (voir enterRoom, plateau-navigation.js), pas par un order
// d'adhesion dedie (aucune UI de membres pour ce lot, hors perimetre).
function getSyndicatDockersPSM() {
  return (state.organisations || []).find(o => o.id === 'orga_syndicat_dockers_republic_ville_a') || null;
}

function getChefSyndicatDockersPSM() {
  return getSyndicatDockersPSM()?.chef || null;
}

async function chargerOuCreerSyndicatDockersPSM() {
  let orga = getSyndicatDockersPSM();
  if (orga) return orga;
  if (!state.organisations) state.organisations = [];
  orga = {
    id: 'orga_syndicat_dockers_republic_ville_a',
    type: 'syndicale',
    nom: 'Syndicat des Dockers de Port-Sainte-Marie',
    desc: 'Le syndicat des dockers du Port industriel de Port-Sainte-Marie.',
    fondateur: 'Étienne Dantafasse (PNJ)', chef: 'Étienne Dantafasse (PNJ)', chefEstPnj: true,
    country: 'republic', city: 'ville_a', country_origine: 'republic',
    creeLe: state.day || 1,
    membres: [], demandesAdhesion: [],
    bonusLocaux: { pop:0, inf:0, dis:0 }, caisse: 0,
    election: null,
    visible: true
  };
  state.organisations.push(orga);
  if (typeof sauvegarderOrga === 'function') sauvegarderOrga(orga);
  return orga;
}

// ---- ADHÉSION (lot logistique portuaire, 25 aout 2026, §12) ----
// Meme structure que doRejoindreClubSupporters ci-dessus (1 PA, seul precedent d'adhesion a une
// organisation existant dans le jeu -- aucun precedent 0 PA trouve, reutilise plutot qu'invente),
// 50 FR credites a la caisse propre du syndicat (orga.caisse, pas de "budget club" equivalent
// ici puisqu'il n'y a pas de club sportif a financer).
async function doRejoindreSyndicatDockers(pa, cost) {
  const orga = await chargerOuCreerSyndicatDockersPSM();
  if (!orga) { showToast('Indisponible', '', false); return; }
  const dejaMembre = orga.membres?.some(m => m.nom === state.char?.name);
  if (dejaMembre) { showToast('Déjà syndiqué', 'Vous êtes déjà membre du Syndicat des Dockers de Port-Sainte-Marie.', false); return; }

  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('Fonds insuffisants', '50 FR requis pour l\'adhésion.', false); return; }

  const def = TYPES_ORGANISATIONS.syndicale;
  const grades = def?.grades?.[orga.country] || ['Adherent', 'Delegue', 'Secretaire Adjoint', 'Secretaire General'];
  // derniereCotisationDate (pas state.day, compteur propre a chaque personnage cote client, voir
  // renouvellerCotisationsOrganisations/api/cron-minuit.js) : date reelle, base du renouvellement
  // tous les 3 mois calendaires.
  orga.membres.push({ nom: state.char?.name, grade: grades[0], gradeIdx: 0, rejointLe: state.day || 1, derniereCotisationDate: new Date().toISOString() });
  orga.caisse = (orga.caisse || 0) + cost;
  sauvegarderOrga(orga);

  document.getElementById('modal-postes')?.classList.remove('open');
  updateUI();
  showToast('Bienvenue au syndicat !', 'Vous êtes désormais ' + grades[0] + ' du Syndicat des Dockers de Port-Sainte-Marie.', true, true);
  addJournalEntry('Adhésion au Syndicat des Dockers de Port-Sainte-Marie (-50 FR).', 'event-good');
  if (document.getElementById('vue-self')?.classList.contains('active')) switchSelfTab('orgas', null);
}

// ---- ÉLECTION (reutilise integralement le moteur generique deja type-agnostique) ----
function doDeclencherElectionSyndicat(pa, cost) {
  const orga = getSyndicatDockersPSM();
  if (!orga) { showToast('Indisponible', 'Aucun syndicat ici.', false); return; }
  const estMembre = orga.membres?.some(m => m.nom === state.char?.name);
  if (!estMembre) { showToast('Réservé aux membres', 'Syndiquez-vous pour déclencher une élection.', false); return; }
  if (orga.election?.enCours) { showToast('Élection en cours', 'Une élection est déjà en cours pour ce syndicat.', false); return; }
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
  html += '<button onclick="confirmerDeclenchementElection(\'' + orga.id + '\',' + pa + ',' + cost + ')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.55rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Déclencher l\'élection</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// ---- MANIFESTATION (meme modele securise que le club de supporters : garde UI via
// requiresChefSyndicatDockers dans data.js + revalidation independante ici cote handler,
// reutilise integralement ouvrirDemandeAutorisationManifester deja type-agnostique) ----
function doOrganiserManifestationSyndicat() {
  const orga = getSyndicatDockersPSM();
  if (!orga) { showToast('Indisponible', 'Aucun syndicat ici.', false); return; }
  const estChef = orga.chef === state.char?.name;
  if (!estChef) { showToast('Réservé au chef', 'Seul le chef du Syndicat des Dockers peut organiser une manifestation.', false); return; }
  ouvrirDemandeAutorisationManifester(orga.id);
}

function doDeclencherElectionClub(pa, cost) {
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
  html += '<button onclick="confirmerDeclenchementElection(\'' + orga.id + '\',' + pa + ',' + cost + ')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.55rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Déclencher l\'élection</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerDeclenchementElection(orgaId, pa, cost) {
  const orga = getOrgaById(orgaId);
  if (!orga) return;
  const motivation = document.getElementById('election-motivation')?.value?.trim();
  if (!motivation) { showToast('Motivation requise', '', false); return; }
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }

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

// Rendu generique de l'organigramme d'une organisation (chef/membres/election en cours),
// extrait le 25 aout 2026 (lot logistique portuaire, §12) pour etre reutilise a la fois par le
// club de supporters (doConsulterOrganigrammeSupporters, comportement inchange) et par le
// Syndicat des Dockers de PSM (doConsulterOrganigrammeSyndicat, nouveau) -- aucune donnee/moteur
// d'election dupliques, seul l'affichage etait jusqu'ici code en dur pour les supporters.
// retourFn : nom (string) de la fonction globale a rappeler pour revenir de la fiche membre.
function afficherOrganigrammeOrga(orga, retourFn) {
  window._orgaOrganigrammeCourante = orga;
  window._orgaOrganigrammeRetourFn = retourFn;
  // Retour a la vue liste : plus aucun membre "courant" (evite qu'un rafraichissement de cache
  // photos arrive apres coup et rouvre a tort la fiche du dernier membre consulte).
  window._orgaOrganigrammeMembreCourant = null;

  const titreChef = typeof titreChefOrga === 'function' ? titreChefOrga(orga.type) : 'Chef';

  document.getElementById('postes-modal-title').textContent = 'Organigramme — ' + orga.nom;
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:1rem;color:#C9A84C;font-family:Bebas Neue,sans-serif;letter-spacing:.06em;margin-bottom:.25rem">' + orga.nom + (orga.chefEstPnj ? ' (poste vacant — assuré par PNJ)' : '') + '</div>';
  html += '<div style="font-size:.85rem;color:#8a8060;margin-bottom:.9rem">' + titreChef + ' actuel : ' + orga.chef + '</div>';

  const membresTries = [...(orga.membres || [])].sort((a, b) => (b.gradeIdx || 0) - (a.gradeIdx || 0));
  html += '<div style="max-height:280px;overflow-y:auto;display:flex;flex-direction:column;gap:.35rem">';
  if (membresTries.length === 0) {
    html += '<div style="font-size:.85rem;color:#5a5040;font-style:italic">Aucun membre pour l\'instant.</div>';
  }
  membresTries.forEach(m => {
    const estChef = m.nom === orga.chef;
    const nomEchap = m.nom.replace(/'/g, "\\'");
    html += '<div onclick="afficherDetailMembreOrga(\'' + nomEchap + '\')" style="cursor:pointer;display:flex;justify-content:space-between;align-items:center;padding:.5rem .6rem;border:1px solid #2a2010;font-size:.9rem;color:' + (estChef ? '#C9A84C' : '#c0b090') + '"><span>' + m.nom + (estChef ? ' 👑' : '') + '</span><span>' + m.grade + '</span></div>';
  });
  html += '</div>';

  if (orga.election?.enCours) {
    html += '<div style="margin-top:1rem;padding:.6rem;border:1px solid #4a3a1a;background:#0f0d05">';
    html += '<div style="font-size:.82rem;color:#C9A84C;font-family:Bebas Neue,sans-serif;letter-spacing:.06em">ÉLECTION EN COURS — ' + (orga.election.phase === 'candidatures' ? 'Candidatures ouvertes' : 'Vote en cours') + '</div>';
    html += '<div style="font-size:.8rem;color:#8a8060;margin-top:.3rem;font-style:italic">« ' + orga.election.motivation + ' » — ' + orga.election.motivateur + '</div>';
    if (orga.election.candidats.length > 0) {
      html += '<div style="font-size:.82rem;color:#c0b090;margin-top:.5rem">Candidats : ' + orga.election.candidats.map(c => c.nom).join(', ') + '</div>';
    }
    html += '</div>';
  }
  html += '</div>';
  const bodyEl = document.getElementById('postes-body');
  bodyEl.innerHTML = html;
  bodyEl.dataset.vue = 'liste';
  document.getElementById('modal-postes').classList.add('open');
}

// Compteur d'ouverture + nom du membre actuellement affiche (correctif du 25 aout 2026, apres
// retour de test production : la version precedente rappelait doConsulterOrganigrammeX() depuis
// le .then() de rafraichirCachePhotosJoueurs(), qui elle-meme relancait un nouveau cycle a
// chaque fois -- boucle de microtaches infinie tant que la vue restait "liste", puisque
// afficherOrganigrammeOrga() remet toujours dataset.vue='liste'. Meme defaut present a
// l'identique dans doConsulterOrganigrammeSupporters depuis v70 (confirme par comparaison avec
// aa13990) : pas une regression propre au Syndicat, un bug latent partage par tous les
// organigrammes, corrige ici une seule fois pour les deux.
let _orgaOrganigrammeOuvertureId = 0;

// Rafraichit UNIQUEMENT la vue deja affichee (liste ou fiche membre), sans jamais rappeler
// doConsulterOrganigrammeX() ni relancer rafraichirCachePhotosJoueurs() -- appelee au plus une
// fois par ouverture, apres resolution du chargement des photos. idOuverture capture au moment
// de l'ouverture : si l'utilisateur a referme/rouvert un organigramme entretemps (nouvel id) ou
// si la modale n'est plus ouverte, ce re-render est abandonne silencieusement (jamais de
// reouverture forcee de la modale).
function rerenderVueOrganigrammeCourante(idOuverture) {
  if (idOuverture !== _orgaOrganigrammeOuvertureId) return;
  if (!document.getElementById('modal-postes')?.classList.contains('open')) return;
  if (window._orgaOrganigrammeMembreCourant) {
    afficherDetailMembreOrga(window._orgaOrganigrammeMembreCourant);
  } else if (window._orgaOrganigrammeCourante) {
    afficherOrganigrammeOrga(window._orgaOrganigrammeCourante, window._orgaOrganigrammeRetourFn);
  }
}

// Correctif du 25 aout 2026 (audit comparatif des 3 clubs, anomalie §1) : l'ancien comportement
// (un simple showToast) donnait l'impression d'un ordre non branché, en particulier a PSM/
// Montrouge ou le club de supporters n'a pas encore ete cree (creation paresseuse a la premiere
// adhesion, doRejoindreClubSupporters -- ce n'est PAS un bug de cablage, voir rapport d'audit).
// Ouvre desormais la MEME modale que l'organigramme normal, avec une explication persistante et
// actionnable, au lieu d'un toast transitoire. Ne touche ni _orgaOrganigrammeOuvertureId ni
// window._orgaOrganigrammeCourante dans cette branche (aucun risque de reintroduire la boucle
// recursive deja corrigee -- voir le commentaire dedie plus haut -- puisqu'aucun appel a
// rafraichirCachePhotosJoueurs n'a lieu ici, il n'y a aucun membre a photographier).
function doConsulterOrganigrammeSupporters() {
  const clubLocal = typeof getClubLocal === 'function' ? getClubLocal() : null;
  const orga = getClubSupportersLocal();
  if (!orga) {
    document.getElementById('postes-modal-title').textContent = 'Organigramme — Club de Supporters';
    document.getElementById('postes-body').innerHTML =
      '<div style="padding:1.5rem;text-align:center;color:#8a8060;font-style:italic">Aucun club de supporters n\'a encore été fondé ici' + (clubLocal ? ' pour ' + clubLocal.nom : '') + '. Rejoignez-le en premier (« Rejoindre le club de supporters ») pour le créer officiellement et faire apparaître son organigramme.</div>';
    document.getElementById('modal-postes').classList.add('open');
    return;
  }
  const idOuverture = ++_orgaOrganigrammeOuvertureId;
  afficherOrganigrammeOrga(orga, 'doConsulterOrganigrammeSupporters');
  if (typeof rafraichirCachePhotosJoueurs === 'function') {
    rafraichirCachePhotosJoueurs().then(() => rerenderVueOrganigrammeCourante(idOuverture)).catch(() => {});
  }
}

// Syndicat des Dockers de PSM (lot logistique portuaire, 25 aout 2026, §12) : meme rendu que le
// club de supporters (afficherOrganigrammeOrga ci-dessus), meme moteur d'election generique
// (deja type-agnostique, verifierElectionsOrganisations). chargerOuCreerSyndicatDockersPSM cree
// paresseusement l'organisation si elle n'existe pas encore (meme garde que le blocus).
async function doConsulterOrganigrammeSyndicat() {
  const orga = await chargerOuCreerSyndicatDockersPSM();
  if (!orga) { showToast('Indisponible', 'Aucun syndicat ici.', false); return; }
  const idOuverture = ++_orgaOrganigrammeOuvertureId;
  afficherOrganigrammeOrga(orga, 'doConsulterOrganigrammeSyndicat');
  if (typeof rafraichirCachePhotosJoueurs === 'function') {
    rafraichirCachePhotosJoueurs().then(() => rerenderVueOrganigrammeCourante(idOuverture)).catch(() => {});
  }
}

// Fiche detail d'un membre d'une organisation (club de supporters ou syndicat) : photo (si
// connue), grade, et un bouton pour lui ecrire directement (ouvre la messagerie avec son nom
// deja rempli en destinataire). Generalisee le 25 aout 2026 (etait afficherDetailMembreSupporters,
// couplee en dur au club de supporters -- meme extraction que afficherOrganigrammeOrga ci-dessus).
function afficherDetailMembreOrga(nom) {
  window._orgaOrganigrammeMembreCourant = nom;
  const orga = window._orgaOrganigrammeCourante;
  const membre = orga?.membres?.find(m => m.nom === nom);
  const avatar = (typeof getAvatarHtmlPourNom === 'function') ? getAvatarHtmlPourNom(nom, 72, '#C9A84C') : '';
  const nomEchap = nom.replace(/'/g, "\\'");

  let html = '<div style="padding:1.2rem;display:flex;flex-direction:column;align-items:center;gap:.6rem">';
  html += avatar;
  html += '<div style="font-size:1rem;color:#f0ead6;font-family:Bebas Neue,sans-serif;letter-spacing:.04em">' + nom + '</div>';
  if (membre) html += '<div style="font-size:.85rem;color:#8a8060">' + membre.grade + '</div>';
  html += '<button class="pnj-action-btn" onclick="ecrireAMembre(\'' + nomEchap + '\')" style="margin-top:.6rem"><i class="ti ti-mail" style="font-size:.85rem"></i> Écrire à ' + nom + '</button>';
  html += '<button class="pnj-action-btn" onclick="' + (window._orgaOrganigrammeRetourFn || 'doConsulterOrganigrammeSupporters') + '()" style="margin-top:.3rem;opacity:.8"><i class="ti ti-arrow-left" style="font-size:.85rem"></i> Retour à l\'organigramme</button>';
  html += '</div>';

  const bodyEl = document.getElementById('postes-body');
  bodyEl.innerHTML = html;
  bodyEl.dataset.vue = 'membre';
}

// Ouvre la messagerie directement en mode redaction, destinataire pre-rempli.
function ecrireAMembre(nom) {
  document.getElementById('modal-postes')?.classList.remove('open');
  document.getElementById('modal-forum')?.classList.add('open');
  if (typeof forumView !== 'undefined') forumView = 'mail';
  if (typeof mailView !== 'undefined') mailView = 'compose';
  if (typeof renderMailCompose === 'function') renderMailCompose(nom);
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

function doSponsoriserClub(pa, cost) {
  const clubLocal = getClubLocal();
  if (!clubLocal) { showToast('Indisponible', 'Aucun club local ici.', false); return; }

  document.getElementById('postes-modal-title').textContent = 'Sponsoriser ' + clubLocal.nom;
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;margin-bottom:.8rem">Votre nom sera associé au club — visibilité en échange de votre soutien financier.</div>';
  PALIERS_SPONSORING.forEach(p => {
    html += '<button onclick="confirmerSponsoring(' + p.montant + ',\'' + p.label + '\',' + p.inf + ',' + pa + ',' + cost + ')" style="display:flex;justify-content:space-between;width:100%;margin-bottom:.4rem;padding:.55rem .7rem;border:1px solid #2a2010;background:transparent;color:#c0b090;cursor:pointer;font-size:.8rem">';
    html += '<span>' + p.label + '</span><span style="color:#C9A84C">' + p.montant.toLocaleString('fr-FR') + ' FR · +' + p.inf + ' INF</span></button>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerSponsoring(montant, label, inf, pa, cost) {
  const clubLocal = getClubLocal();
  document.getElementById('modal-postes')?.classList.remove('open');
  if (getFondsDisponiblesOrdinaires() < montant) { showToast('Fonds insuffisants', montant + ' FR requis.', false); return; }
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }
  const debitSponsoring = await debiterFondsOrdinaires(montant);
  if (!debitSponsoring.ok) { showToast('Fonds insuffisants', montant + ' FR requis.', false); return; }
  state.inf = Math.min(100, (state.inf || 0) + inf);
  clubLocal.sponsorActuel = state.char?.name || null;
  updateUI();
  showToast(label + ' !', 'Votre nom est désormais associé à ' + clubLocal.nom + '. +' + inf + ' INF.', true, true);
  addJournalEntry(label + ' de ' + clubLocal.nom + ' (-' + montant + ' FR, +' + inf + ' INF).', 'event-good');
  await crediterBudgetClub(clubLocal.id, montant, label + ' — ' + (state.char?.name || 'Anonyme'));
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
async function doOrganiserBoycott(pa, cost) {
  const orga = getClubSupportersLocal();
  const clubLocal = getClubLocal();
  if (!orga || !clubLocal) { showToast('Indisponible', '', false); return; }
  const estChef = orga.chef === state.char?.name;
  if (!estChef) { showToast('Réservé au président', 'Seul le président du club de supporters peut décider d\'un boycott.', false); return; }

  const saison = await chargerOuInitialiserSaison();
  const prochaineJournee = saison.calendrier.find(j => j.matchs.some(m => !m.played && m.home === clubLocal.id));
  if (!prochaineJournee) { showToast('Aucun match à domicile', 'Pas de prochain match à domicile pour ce club.', false); return; }
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }
  const match = prochaineJournee.matchs.find(m => !m.played && m.home === clubLocal.id);
  match.boycotte = true;
  if (typeof sbSaveChampionnat === 'function') await sbSaveChampionnat(saison).catch(() => {});

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
    const midSaison = (saison.dateDebut ? joursEcoulesDepuis(saison.dateDebut) : 0) ;
    if (data.dateElection && (jour - data.dateElection) < 8) { // ~mi-saison (saison=11 journees, protection ~ 5-6 sem)
      showToast('Poste protégé', 'Le président en poste ne peut pas être remis en question avant la mi-saison.', false);
      return;
    }
  }

  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }

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
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }

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
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }
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
  return kickoff.toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit', year: 'numeric' }) +
    ' à ' + kickoff.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
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

async function doParierMatch(pa, cost) {
  const saison = await verifierEtJouerJournees();

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
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }

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
