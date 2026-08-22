// =====================
// PLATEAU-ACTIONS-ILLEGALES-RUMEURS.JS
// Vol, assassinat, empoisonnement, informateurs, traçage actions, rumeurs vraies/fausses,
// fuites, scandales
// =====================

// TRACAGE DES ACTIONS (pour le systeme de rumeurs vraies)
// =====================
function tracerActionPourRumeur(typeAction, cibleNom) {
  if (typeof sbTracerAction !== 'function') return;
  const action = {
    id: 'action-' + Date.now() + '-' + Math.floor(Math.random()*1000),
    auteur: state.char?.name || 'Anonyme',
    cible: cibleNom || null,
    type_action: typeAction,
    country: state.country,
    city: state.currentCity,
    jour: state.day || 1,
    jour_expiration: (state.day || 1) + 7
  };
  sbTracerAction(action).catch(() => {});
}


function ouvrirModalVoler(encodedCible) {
  let cible;
  try { cible = JSON.parse(decodeURIComponent(encodedCible)); } catch(e) { return; }

  const char = state.char;
  const per = getStatEffective('PER');
  const cha = getStatEffective('CHA');
  const bonusCarriere = BONUS_CARRIERE_VOL[char?.career] || 0;
  const isPays = (typeof getIndiceVille === 'function') ? getIndiceVille(state.country, state.currentCity || 'capitale', 'isn') : (INDICES_NATIONAUX[state.country]?.ISN || 30);

  // Stats de la cible — si PJ reel on n'a que des stats par defaut raisonnables (PNJ ont parfois des stats definies)
  const perCible = cible.stats?.PER || 9;
  const intCible = cible.stats?.INT || 9;

  const tauxReussite = Math.max(5, Math.min(95, Math.round(
    50 + (per + cha) - (perCible + intCible) + bonusCarriere - (isPays / 3)
  )));
  const seuilVisibilite = 90;

  document.getElementById('postes-modal-title').textContent = 'Voler — ' + cible.name;
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.82rem;color:#aa7a30;font-style:italic;margin-bottom:1rem;padding:.5rem;background:#0f0d05;border:1px solid #3a2810">Acte illegal. En cas d\'echec, des consequences variables selon l\'empire s\'appliquent.</div>';
  html += '<div style="font-size:.78rem;color:#8a8060;margin-bottom:.8rem">Chances de reussite estimees : <strong style="color:#C9A84C">' + tauxReussite + '%</strong></div>';
  html += '<button onclick="confirmerVol(\'' + encodedCible + '\',' + tauxReussite + ',' + seuilVisibilite + ')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #aa7a30;background:transparent;color:#C9A84C;cursor:pointer">🤏 Tenter le vol (2 PA)</button>';
  html += '</div>';

  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

const CONSEQUENCES_VOL_ECHEC = {
  republic: (nomCible) => {
    const amende = 300;
    state.arg = Math.max(0, state.arg - amende);
    if (!state.historiqueCrimes) state.historiqueCrimes = [];
    state.historiqueCrimes.push({ acte: 'vol', cible: nomCible, jour: state.day, expireJour: state.day + 8 });
    return 'Un agent vous verbalise sur-le-champ. -' + amende + ' FR. Inscrit au registre administratif.';
  },
  narco: (nomCible) => {
    const perte = Math.floor((state.arg || 0) * 0.5);
    state.arg = Math.max(0, state.arg - perte);
    return 'Deux messieurs interviennent sans discussion. Vous perdez ' + perte + ' liquide. "La prochaine fois, on sera moins gentils."';
  },
  soviet: (nomCible) => {
    state.pop = Math.max(0, (state.pop || 0) - 10);
    const amende = 100;
    state.arg = Math.max(0, state.arg - amende);
    return 'Le collectif vous denonce publiquement. -10 POP, -' + amende + ' FR (amende symbolique).';
  },
  khalija: (nomCible) => {
    if (!state.historiqueCrimes) state.historiqueCrimes = [];
    state.historiqueCrimes.push({ acte: 'vol', cible: nomCible, jour: state.day, expireJour: state.day + 15 });
    return 'Sanction par decret. Affaire consignee pour 15 jours — la memoire du Sheikh est longue.';
  }
};

async function confirmerVol(encodedCible, tauxReussite, seuilVisibilite) {
  let cible;
  try { cible = JSON.parse(decodeURIComponent(encodedCible)); } catch(e) { return; }
  document.getElementById('modal-postes').classList.remove('open');
  // Consomme la benediction ici (resolution reelle), pas dans ouvrirModalVoler -- sinon un
  // joueur qui ouvre le modal puis renonce perdrait le bonus pour rien.
  tauxReussite = (typeof consommerBonusBenediction === 'function') ? Math.min(95, consommerBonusBenediction(tauxReussite)) : tauxReussite;

  const nomCible = cible.name.replace(' (PNJ)', '');
  const roll = Math.random() * 100;

  if (roll > tauxReussite) {
    // ECHEC
    const consequence = CONSEQUENCES_VOL_ECHEC[state.country] || CONSEQUENCES_VOL_ECHEC.republic;
    const msg = consequence(nomCible);
    updateUI();
    showToast('Vol échoué !', msg, false, true);
    addJournalEntry('Tentative de vol sur ' + nomCible + ' échouée. ' + msg, 'event-bad');
    return;
  }

  // REUSSITE — determiner le butin
  const voitButin = roll <= (tauxReussite * seuilVisibilite / 100);

  if (cible.isPJ) {
    // Vol sur un vrai joueur — montant aleatoire d'argent liquide (50-200), applique a sa prochaine connexion
    const montantVole = Math.floor(Math.random() * 150) + 50;
    const vol = {
      id: 'vol-' + Date.now(),
      victime: nomCible,
      voleur: state.char?.name || 'Anonyme',
      type_butin: 'argent',
      montant: montantVole,
      objet_id: null,
      traite: false
    };
    if (typeof sbDeposerVol === 'function') {
      await sbDeposerVol(vol).catch(() => {});
    }
    state.arg = (state.arg || 0) + montantVole;
    updateUI();
    showToast('Vol réussi !', '+' + montantVole + ' FR dérobés à ' + nomCible + '.', true, true);
    addJournalEntry('Vol réussi sur ' + nomCible + '. +' + montantVole + ' FR.', 'event-good');
    tracerActionPourRumeur('vol', nomCible);

    if (typeof sbSendMail === 'function') {
      const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : 'Jour ' + (state.day || 1);
      sbSendMail('Système', nomCible, 'Vous avez été volé(e)', 'Quelqu\'un vous a discrètement dérobé ' + montantVole + ' FR. Le montant a été déduit de votre trésorerie.', time).catch(() => {});
    }
  } else {
    // Vol sur un PNJ — effet immediat possible
    const butinArgent = Math.floor(Math.random() * 200) + 50;
    state.arg = (state.arg || 0) + butinArgent;
    updateUI();
    showToast('Vol réussi !', '+' + butinArgent + ' FR dérobés à ' + nomCible + '.', true, true);
    addJournalEntry('Vol réussi sur ' + nomCible + ' (PNJ). +' + butinArgent + ' FR.', 'event-good');
  }
}


function ouvrirModalAssassinat(encodedCible) {
  let cible;
  try { cible = JSON.parse(decodeURIComponent(encodedCible)); } catch(e) { return; }

  const char = state.char;
  const armes = (state.inventory||[]).filter(i => i.type === 'arme');
  const hasBlade = armes.some(a => a.sousType === 'blanche');
  const hasGun   = armes.some(a => a.sousType === 'poing' || a.sousType === 'carabine');

  const vol = getStatEffective('VOL');
  const per = getStatEffective('PER');
  const dup = getStatEffective('DUP');

  const tauxMains = Math.min(60, 20 + Math.floor(vol * 1.5));
  const tauxArme  = Math.min(75, 40 + Math.floor(dup * 1.2));
  const tauxFeu   = Math.min(85, 60 + Math.floor(per * 1.0));

  document.getElementById('postes-modal-title').textContent = 'Assassiner — ' + cible.name;
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.82rem;color:#cc4444;font-style:italic;margin-bottom:1rem;padding:.5rem;background:#0f0505;border:1px solid #3a1010">Acte criminel. Peine : 7 jours QHS si echec. 15 jours si decouvert ulterieurement.</div>';

  // Options
  html += '<div style="display:flex;flex-direction:column;gap:.5rem">';

  html += '<button onclick="confirmerAssassinatArme(\'' + encodedCible + '\',\'mains\',' + tauxMains + ')" style="display:flex;justify-content:space-between;align-items:center;padding:.6rem 1rem;border:1px solid #3a2010;background:#0f0805;color:#c0a080;cursor:pointer;font-family:Crimson Pro,serif;font-size:.85rem">' +
    '<span>A mains nues</span><span style="font-family:Bebas Neue,sans-serif;font-size:.75rem;color:#8a6040">' + tauxMains + '% · 2 PA</span></button>';

  html += '<button onclick="confirmerAssassinatArme(\'' + encodedCible + '\',\'arme\',' + tauxArme + ')" ' +
    (!hasBlade ? 'disabled style="opacity:.4;cursor:not-allowed;' : 'style="cursor:pointer;') +
    'display:flex;justify-content:space-between;align-items:center;padding:.6rem 1rem;border:1px solid #4a1a08;background:#0f0805;color:' + (hasBlade ? '#c06040' : '#4a3020') + ';font-family:Crimson Pro,serif;font-size:.85rem">' +
    '<span>Arme blanche ' + (!hasBlade ? '(aucune en inventaire)' : '') + '</span>' +
    '<span style="font-family:Bebas Neue,sans-serif;font-size:.75rem;color:#8a5030">' + tauxArme + '% · 2 PA</span></button>';

  html += '<button onclick="confirmerAssassinatArme(\'' + encodedCible + '\',\'feu\',' + tauxFeu + ')" ' +
    (!hasGun ? 'disabled style="opacity:.4;cursor:not-allowed;' : 'style="cursor:pointer;') +
    'display:flex;justify-content:space-between;align-items:center;padding:.6rem 1rem;border:1px solid #5a1a08;background:#0f0805;color:' + (hasGun ? '#cc4444' : '#4a2020') + ';font-family:Crimson Pro,serif;font-size:.85rem">' +
    '<span>Arme a feu ' + (!hasGun ? '(aucune en inventaire)' : '') + ' — bruit !</span>' +
    '<span style="font-family:Bebas Neue,sans-serif;font-size:.75rem;color:#8a3030">' + tauxFeu + '% · 3 PA · -20 DIS</span></button>';

  html += '</div></div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerAssassinatArme(encodedCible, mode, taux) {
  document.getElementById('modal-postes').classList.remove('open');
  let cible;
  try { cible = JSON.parse(decodeURIComponent(encodedCible)); } catch(e) { return; }

  const paCost = mode === 'feu' ? 3 : 2;
  // Deduction PA centralisee (Lot 2A) -- deduireCoutOrdre() est l'AUTORITE UNIQUE sur la
  // disponibilite des PA (poche historique jamais migree au Lot 1). Appelee ICI, avant toute
  // mutation (DIS, historique d'assassinats, ecriture Supabase d'impact) : fail-closed.
  const rPa = await deduireCoutOrdre({ pa: paCost, cost: 0 });
  if (!rPa.ok) { showToast('PA insuffisants', paCost + ' PA requis.', false); return; }

  const roll = Math.floor(Math.random() * 100) + 1;

  // 4 paliers de resultat, repartis sur l'echelle du taux de reussite
  // roll <= taux/2            -> reussite totale (PV a 0)
  // taux/2 < roll <= taux     -> reussite partielle (PV a 25)
  // taux < roll <= taux + (100-taux)/2  -> echec partiel, demasque (PV a 50)
  // au-dela                  -> echec total, demasque (pas de perte de PV)
  const seuilReussiteTotale = taux / 2;
  const seuilReussitePartielle = taux;
  const seuilEchecPartiel = taux + (100 - taux) / 2;

  let palier, pvCible, reussi;
  if (roll <= seuilReussiteTotale) { palier = 'totale'; pvCible = 0; reussi = true; }
  else if (roll <= seuilReussitePartielle) { palier = 'partielle'; pvCible = 25; reussi = true; }
  else if (roll <= seuilEchecPartiel) { palier = 'echec_partiel'; pvCible = 50; reussi = false; }
  else { palier = 'echec_total'; pvCible = null; reussi = false; }

  if (mode === 'feu') state.dis = Math.max(0, state.dis - 20);

  if (reussi) {
    // Marquer la cible comme attaquee (cote attaquant, pour son propre suivi)
    if (!state.assassinats) state.assassinats = [];
    state.assassinats.push({ cible: cible.name, jour: state.day, mode, palier, decouvert: false });

    // Transmission REELLE des PV a la victime
    // - PJ simule : effet direct
    // - Vrai PJ : passe par le systeme d'impact differe (applique a sa prochaine connexion)
    const pjSimule = state.pjSimules?.find(p => p.name === cible.name);
    if (pjSimule) {
      pjSimule.resources.hp = pvCible;
      pjSimule.estAssassine = { jour: state.day, ville: state.currentCity };
    } else if (cible.isPJ && typeof sbDeposerImpactIndice === 'function') {
      await sbDeposerImpactIndice({
        id: 'agression-' + Date.now(),
        victime: cible.name,
        indice: 'hp_set',
        delta: pvCible,
        palier: palier,
        traite: false
      }).catch(() => {});
    }

    // Reduction population si PNJ
    if (!cible.isPJ) {
      const pop = CITY_POPULATION[state.country]?.[state.currentCity];
      if (pop) pop.total = Math.max(0, pop.total - 1);
    }

    const messagePalier = palier === 'totale'
      ? cible.name + ' s\'effondre, gravement blesse(e). Vous n\'etes pas identifie(e).'
      : cible.name + ' est blesse(e) mais reste consciente. Vous n\'etes pas identifie(e).';
    showToast('Acte commis', messagePalier, false);
    addJournalEntry('Vous avez attaque ' + cible.name + ' (' + mode + ', reussite ' + palier + '). Non identifie(e) pour l\'instant.', 'event-bad');
    tracerActionPourRumeur('assassinat', cible.name.replace(' (PNJ)',''));

    // Detection potentielle (peut mener a une enquete et une detention preventive en cas de decouverte)
    checkDetection('assassiner_' + mode, 'success');

  } else {
    if (palier === 'echec_partiel' && cible.isPJ && typeof sbDeposerImpactIndice === 'function') {
      // Echec partiel : la cible est quand meme legerement blessee, meme si l'attaque echoue globalement
      await sbDeposerImpactIndice({
        id: 'agression-' + Date.now(),
        victime: cible.name,
        indice: 'hp_set',
        delta: pvCible,
        palier: palier,
        traite: false
      }).catch(() => {});
    }
    // Echec — identifie sur le coup, arrestation immediate (pas de detention preventive ici,
    // c'est une prise sur le fait, pas une enquete ulterieure)
    addExternalEvent('Tentative d\'homicide sur ' + cible.name + ' ! Vous avez ete identifie(e). Arrestation imminente.');
    state.recherche = [{ acte: 'tentative_homicide', type: 'crime', jour: state.day }];
    setTimeout(() => ouvrirModalArrestation('crime'), 800);
  }
  updateUI();
}

// =====================

// ECOUTER LES RUMEURS (IA)
// =====================
// Formulations evasives par type d'action tracee (jamais de detail precis : montant, raison, etc.)
const FORMULATIONS_RUMEUR_VRAIE = {
  don:        (a, c) => 'On a vu ' + a + ' donner quelque chose discrètement à ' + c + '.',
  don_objet:  (a, c) => 'On raconte que ' + a + ' a remis un objet en mains propres à ' + c + ', loin des regards.',
  vol:        (a, c) => 'Un témoin jure avoir vu ' + a + ' s\'approcher un peu trop près des affaires de ' + c + '.',
  assassinat: (a, c) => 'On a aperçu ' + a + ' avec ' + c + ' juste avant que ce dernier ne se fasse agresser.',
  corruption: (a, c) => 'Des rumeurs courent sur ' + a + ' qui aurait \'arrangé\' une affaire administrative contre quelques billets.',
  escort:     (a, c) => 'Il paraîtrait que ' + a + ' fréquente assidûment certains établissements... discrets.',
  achat_arme_illegal:     (a, c) => 'Un indic murmure que ' + a + ' se serait procuré une arme par des voies peu recommandables.',
  acheter_bombe_illegale: (a, c) => 'On chuchote que ' + a + ' aurait mis la main sur du matériel explosif, sans qu\'on sache pourquoi.',
  incendier:              (a, c) => 'Des témoins évoquent la silhouette de ' + a + ' rôdant près de ' + c + ' juste avant l\'incendie.',
  utiliser_explosifs:     (a, c) => 'On raconte qu\'une explosion près de ' + c + ' ne devrait rien au hasard — et que ' + a + ' y serait pour quelque chose.',
  empoisonnement:         (a, c) => 'Une rumeur tenace prête à ' + a + ' un geste discret dans le verre ou l\'assiette de ' + c + '.',
  hooliganisme:           (a, c) => 'On dit que ' + a + ' aurait pris part à des débordements violents lors d\'un récent rassemblement.',
  torture_qhs:            (a, c) => 'Des bruits de couloir évoquent des méthodes brutales employées par ' + a + ' envers un détenu du QHS.',
  diner_affaires_accepte: (a, c) => a + ' a déjeuné avec ' + c + '. Que se sont-ils dit... ?',
  diner_affaires_refuse:  (a, c) => 'On raconte que ' + a + ' aurait tenté d\'inviter ' + c + ' à dîner... sans succès.',
  boire_verre_accepte:    (a, c) => 'On a vu ' + a + ' et ' + c + ' trinquer ensemble au bar. Ambiance cordiale... ou complice ?',
  boire_verre_refuse:     (a, c) => a + ' aurait tenté d\'offrir un verre à ' + c + ', qui a décliné sans un mot.',
  nuit_escort:            (a, c) => 'Des mauvaises langues jurent avoir vu ' + a + ' quitter discrètement une chambre en compagnie d\'une professionnelle de l\'Agence Roxane Velours.',
  plainte_sans_suite:     (a, c) => 'Une rumeur evoque une plainte deposee par ' + a + ' contre ' + c + ', finalement classee sans suite.',
  plainte_enquete:        (a, c) => 'Une enquete viserait ' + c + ', dit-on, suite a une plainte deposee par ' + a + '.',
  plainte_confirmee:      (a, c) => 'La rumeur veut que ' + c + ' ait ete place en garde a vue suite a une plainte de ' + a + '.',
  cellules_fragilisees:   (a, c) => 'On raconte que les cellules de garde a vue de ' + c + ' se fragiliseraient, suite a des incidents recents.'
};

async function ecouterRumeurs(successRate, pa, cost) {
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }
  const ville = WORLD[state.country]?.[state.currentCity]?.name || 'la ville';
  const char = state.char;
  const room = BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom];
  const ordreEcoute = room?.orders?.find(o => o.fn === 'ecouter_rumeurs');
  const pnjPresents = ordreEcoute?.sourceOverride ? [ordreEcoute.sourceOverride] : ['Le Commissaire', 'Un député', 'Un journaliste', 'Un commerçant', 'Un inconnu'];
  const source = pnjPresents[Math.floor(Math.random() * pnjPresents.length)];

  showToast('Vous tendez l\'oreille...', 'En attente d\'une information.', false);

  const roll = Math.random() * 100;
  const succes = roll < (successRate ?? 70);

  // Rumeurs VRAIES uniquement, basees sur une action reellement tracee.
  // Aucun repli IA/invente : si le jet echoue ou qu'il n'y a rien a reveler,
  // le joueur repart simplement bredouille.
  let actionsDisponibles = [];
  if (succes && typeof sbGetActionsTracables === 'function') {
    try {
      actionsDisponibles = await sbGetActionsTracables(state.country, state.currentCity, state.day || 1);
      // Ne jamais reveler sa propre action a soi-meme
      actionsDisponibles = actionsDisponibles.filter(a => a.auteur !== char?.name);
    } catch(e) {}
  }

  if (succes && actionsDisponibles.length > 0) {
    const action = actionsDisponibles[Math.floor(Math.random() * actionsDisponibles.length)];
    const formulateur = FORMULATIONS_RUMEUR_VRAIE[action.type_action];
    if (formulateur) {
      const texte = formulateur(action.auteur, action.cible || 'quelqu\'un');
      document.getElementById('postes-modal-title').textContent = source + ' vous glisse à l\'oreille...';
      document.getElementById('postes-body').innerHTML =
        '<div style="padding:1.2rem">' +
        '<div style="font-size:.85rem;color:#c0b090;font-style:italic;line-height:1.7;font-family:Crimson Pro,serif">"' + texte + '"</div>' +
        '<div style="font-size:.68rem;color:#9a8a68;margin-top:.8rem">Source : ' + source + ' · Information vérifiée</div>' +
        '</div>';
      document.getElementById('modal-postes').classList.add('open');
      state.inf = Math.min(100, state.inf + 1);
      updateUI();
      addJournalEntry('Rumeur entendue à ' + ville, 'event-info');
      return;
    }
  }

  // Echec du jet ou aucune rumeur vraie disponible
  document.getElementById('postes-modal-title').textContent = source + '...';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1.2rem">' +
    '<div style="font-size:.85rem;color:#8a8060;font-style:italic;line-height:1.7;font-family:Crimson Pro,serif">Rien de croustillant à se mettre sous la dent aujourd\'hui.</div>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function solliciterAudiencePresident() {
  const char = state.char;
  if (state.poste?.id === 'president') {
    showToast('Indisponible', 'Vous êtes déjà le/la président(e) — inutile de solliciter votre propre audience.', false);
    return;
  }
  const nomDemandeur = char?.name || 'Anonyme';
  // Message automatique au demandeur
  showToast(
    'Demande transmise',
    'Je transmets votre demande à Monsieur le Président. Il vous contactera dès qu\'il en aura pris connaissance.',
    true
  );
  addJournalEntry('Vous avez sollicite une audience presidentielle.', 'event-info');
  // Mail au President (vrai titulaire recherche via Supabase — silencieux si PNJ/vacant, comme avant)
  const presidentInfo = await getTitulaireActuel('president');
  const titulaire = presidentInfo?.estPJ ? presidentInfo.nom : null;
  await envoyerNotificationVraiJoueur(titulaire, 'Demande d\'audience de ' + nomDemandeur,
    nomDemandeur + ' sollicite une audience presidentielle. Vous pouvez lui repondre directement par mail.');
}

// =====================

// PRODUIRE UNE FUITE
// =====================
async function ouvrirProduireFuite(pa, cost) {
  const contacts = state.contacts || [];
  if (contacts.length === 0) {
    showToast('Repertoire vide', 'Ajoutez des contacts pour cibler une fuite.', false);
    return;
  }
  document.getElementById('postes-modal-title').textContent = 'Produire une fuite';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#cc4444;font-style:italic;margin-bottom:.8rem">Acte illegal. Taux 55%. Si succes : rumeur dans le journal + mail a la cible (-10 INF -10 POP).</div>';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">CIBLE</div>';
  html += '<select id="fuite-cible" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.8rem">';
  contacts.forEach(c => { html += '<option value="' + c.name + '">' + c.name + '</option>'; });
  html += '</select>';
  html += '<button onclick="confirmerFuite(' + pa + ',' + cost + ')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Lancer la fuite</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerFuite(pa, cost) {
  const cible = document.getElementById('fuite-cible')?.value;
  if (!cible) return;
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }
  document.getElementById('modal-postes').classList.remove('open');

  const roll = Math.floor(Math.random() * 100) + 1;
  const taux = Math.max(5, 55 - getMalusISN());

  if (roll <= taux) {
    // Generer la rumeur via IA
    try {
      const resp = await fetch('/api/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: 'claude-sonnet-4-5',
          max_tokens: 150,
          messages: [{
            role: 'user',
            content: 'Tu es le narrateur d\'un jeu politique parodique. Génère une courte rumeur compromettante (2 phrases max) concernant ' + cible + ', un personnage politique fictif. Ton satirique. Commence directement par la rumeur sans introduction.'
          }]
        })
      });
      const data = await resp.json();
      const rumeur = data.content?.[0]?.text || 'Des informations compromettantes circulent sur ' + cible + '.';

      addExternalEvent('FUITE : ' + rumeur);
      addMailNotification('Source anonyme', 'Information vous concernant', 'Des informations vous concernant ont ete divulguees : "' + rumeur + '". Votre reputation en patit. -10 INF -10 POP.');
      showToast('Fuite reussie !', 'Rumeur publiee dans le journal des evenements.', true, true);
      addJournalEntry('Fuite produite contre ' + cible + '.', 'event-bad');
      checkDetection('produire_fuite', 'success');

    } catch(e) {
      addExternalEvent('FUITE : Des informations compromettantes sur ' + cible + ' circulent dans les couloirs du pouvoir.');
      showToast('Fuite reussie !', 'Rumeur publiee.', true);
    }
  } else {
    showToast('Echec', 'La fuite n\'a pas pu etre organisee.', false);
    checkDetection('produire_fuite', 'fail');
  }
}

// =====================
// FABRIQUER UN SCANDALE
// =====================
function ouvrirFabrquerScandale(pa, cost) {
  const contacts = state.contacts || [];
  if (contacts.length === 0) {
    showToast('Repertoire vide', 'Ajoutez des contacts pour cibler un scandale.', false);
    return;
  }
  const isJournaliste = state.char?.career === 'press';
  const isMinInfo = state.poste?.id === 'min_info';
  const bonusCarriere = isJournaliste ? 15 : isMinInfo ? 10 : 0;
  const taux = 35 + bonusCarriere;

  document.getElementById('postes-modal-title').textContent = 'Fabriquer un scandale';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#cc4444;font-style:italic;margin-bottom:.8rem">Acte illegal. Taux ' + taux + '%' + (bonusCarriere > 0 ? ' (bonus ' + (isJournaliste ? 'journaliste' : 'MInfo') + ' +' + bonusCarriere + '%)' : '') + '. Si decouvert : Recherche pour diffamation.</div>';

  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">CIBLE</div>';
  html += '<select id="scandale-cible" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.6rem">';
  contacts.forEach(c => { html += '<option value="' + c.name + '">' + c.name + '</option>'; });
  html += '</select>';

  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">CONTENU DU SCANDALE</div>';
  html += '<textarea id="scandale-contenu" rows="4" placeholder="Decrivez le scandale fabrique..." style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;resize:none;margin-bottom:.8rem"></textarea>';
  html += '<button onclick="confirmerScandale(' + taux + ',' + pa + ',' + cost + ')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Publier le scandale</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerScandale(taux, pa, cost) {
  const cible = document.getElementById('scandale-cible')?.value;
  const contenu = document.getElementById('scandale-contenu')?.value?.trim();
  if (!cible || !contenu) { showToast('Champs requis', '', false); return; }
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }
  document.getElementById('modal-postes').classList.remove('open');

  const roll = Math.floor(Math.random() * 100) + 1;
  const tauxFinal = Math.max(5, taux - getMalusISN());

  if (roll <= tauxFinal) {
    // Publier dans le forum national
    if (!FORUM_TOPICS['national']) FORUM_TOPICS['national'] = [];
    const timeScandale = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : 'Jour ' + state.day;
    FORUM_TOPICS['national'].unshift({
      id: 'scandale-' + Date.now(),
      title: '[SCANDALE] Revelations sur ' + cible,
      author: 'Source anonyme',
      time: timeScandale,
      posts: [{ author: 'Source anonyme', time: timeScandale, content: contenu }]
    });

    // Mail a la cible
    addMailNotification('Redaction anonyme', 'Scandale vous concernant', 'Un article compromettant vous concernant vient d\'etre publie dans le forum national. -15 INF -15 POP -10 Moral.');
    addExternalEvent('SCANDALE : Revelations compromettantes sur ' + cible + ' publiees dans le forum national !');
    showToast('Scandale publie !', 'Article dans le forum national. -15 INF -15 POP -10 Moral sur ' + cible, true, true);
    addJournalEntry('Scandale fabrique contre ' + cible, 'event-bad');

    // Enregistrement partage : rend la rumeur dementable par la cible (ou son entourage) plus tard
    if (typeof sbCreerRumeurPolitique === 'function') {
      sbCreerRumeurPolitique({ cible, contenu, auteur: state.char?.name || 'Anonyme', jour: state.day || 1, popPerdu: 15 }).catch(() => {});
    }

    // Risque de decouverte (30%)
    const rollDecouv = Math.floor(Math.random() * 100) + 1;
    if (rollDecouv <= 30) {
      setTimeout(() => {
        state.recherche = [{ acte: 'diffamation', type: 'delit_grave', jour: state.day }];
        addExternalEvent('RETOUR DE BATON : Vous avez ete identifie(e) comme l\'auteur du scandale ! Recherche pour diffamation.');
        showToast('Decouvert !', 'Vous etes recherche(e) pour diffamation. -20 POP -15 INF.', false);
        state.pop = Math.max(0, state.pop - 20);
        state.inf = Math.max(0, state.inf - 15);
        updateUI();
      }, 1500);
    }
    checkDetection('fabriquer_scandale', 'success');
  } else {
    showToast('Echec', 'Le scandale n\'a pas pris. Personne ne l\'a cru.', false);
    checkDetection('fabriquer_scandale', 'fail');
  }
}

// =====================

// OBJETS POISON
// =====================
const POISON_OBJETS = {
  parapluie: { name:'Parapluie républien', icon:'ti-umbrella',   cout:400, empire:'republic', msg:'Un accessoire élégant. Discret. La pointe contient... quelque chose.' },
  ghb:       { name:'GHB de contrebande', icon:'ti-flask',       cout:300, empire:'narco',    msg:'Un flacon transparent. Inodore, incolore. À manier avec précaution.' },
  polonium:  { name:'Fiole de Polonium',  icon:'ti-radioactive', cout:600, empire:'soviet',   msg:'Un petit contenant blindé. Ne pas ouvrir sans combinaison.' },
  vipere:    { name:'Vipère des sables',  icon:'ti-bug',         cout:350, empire:'khalija',  msg:'Une petite boîte percée. On entend un léger sifflement.' }
};

// Descriptions parodiques etendues par objet pour le modal d'achat
const POISON_DESC_PARODIQUE = {
  parapluie: 'Roger Détente pose l\'objet sur le comptoir sans un mot. Il a la discrétion d\'un homme qui a tout vu, tout su, et surtout tout oublié. Le parapluie est noir, orné de petites têtes de mort dorées — pour le style, précise-t-il. La pointe, elle, ne se commente pas. Usage unique. Garantie non incluse.',
  polonium: 'Camarade Kalachnikov sort le contenant d\'un tiroir blindé avec des gants en plomb. Il vous regarde avec l\'expression d\'un homme qui sait exactement ce que vous allez en faire. Il approuve. Il sourit même, légèrement. Pour la gloire du Parti, murmure-t-il. Ne pas secouer. Ne pas ouvrir. Ne pas mettre dans la même poche que votre téléphone.',
  ghb: 'Carlos glisse le petit flacon sous le comptoir avec la dextérité d\'un prestidigitateur et l\'innocence d\'un pharmacien. Inodore. Incolore. Et surtout : parfaitement introuvable dans un verre de sangria. Il ne pose aucune question. Vous non plus. C\'est ce qui fait de vous deux de bonnes personnes.',
  vipere: 'Hassan vous tend la boîte en carton avec un sourire aussi large que son ignorance des lois sanitaires. On entend un léger sifflement de l\'intérieur. Elle a mangé ce matin, précise-t-il en guise de garantie. Ne pas mettre dans votre poche. Ne pas laisser sans surveillance. Ne pas appeler le service après-vente.'
};

// =====================
// CATALOGUE D'ARMES PAR EMPIRE
// =====================
const ARMES_CATALOGUE = {
  republic: [
    {
      id: 'couteau',
      name: 'Couteau de poche',
      type: 'blanche',
      prix: 250,
      icon: 'ti-tools-kitchen-2',
      desc: 'Légal pour la chasse. Roger ne demande pas à qui.',
      bonus: { stat: 'VOL', val: 5 },
      imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-couteau-republic.png'
    },
    {
      id: 'revolver',
      name: 'Revolver .38',
      type: 'poing',
      prix: 800,
      icon: 'ti-crosshair',
      desc: 'Fiable, discret, classique. Trois balles suffisent généralement.',
      bonus: { stat: 'PER', val: 8 },
      imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-fusil-republic.png'
    },
    {
      id: 'carabine_chasse',
      name: 'Carabine de chasse',
      type: 'carabine',
      prix: 1800,
      icon: 'ti-target-arrow',
      desc: 'Pour le gibier. Gros gibier.',
      bonus: { stat: 'PER', val: 15 },
      imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-revolver-republic.png'
    }
  ],
  narco: [
    {
      id: 'machette',
      name: 'Machette',
      type: 'blanche',
      prix: 200,
      icon: 'ti-tools-kitchen-2',
      desc: "L'outil universel. Multi-usages.",
      bonus: { stat: 'VOL', val: 5 },
      imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-machette-narco.png'
    },
    {
      id: 'desert_eagle',
      name: 'Desert Eagle',
      type: 'poing',
      prix: 1200,
      icon: 'ti-crosshair',
      desc: 'El Don lui-même en possède trois.',
      bonus: { stat: 'PER', val: 10 },
      imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-deserteagle-narco.png'
    },
    {
      id: 'ak47',
      name: 'AK-47',
      type: 'carabine',
      prix: 2500,
      icon: 'ti-target-arrow',
      desc: "Origine : inconnue. État : parfait.",
      bonus: { stat: 'PER', val: 18 },
      imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-ak47-narco.png'
    }
  ],
  soviet: [
    {
      id: 'baionnette',
      name: 'Baïonnette',
      type: 'blanche',
      prix: 300,
      icon: 'ti-tools-kitchen-2',
      desc: 'Propriété du Peuple. Empruntée indéfiniment.',
      bonus: { stat: 'VOL', val: 5 },
      imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-baionnette-soviet.png'
    },
    {
      id: 'makarov',
      name: 'Makarov',
      type: 'poing',
      prix: 700,
      icon: 'ti-crosshair',
      desc: 'Standard réglementaire. Camarade Kalachnikov détourne le regard.',
      bonus: { stat: 'PER', val: 8 },
      imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-makarov-soviet.png'
    },
    {
      id: 'kalachnikov',
      name: 'Kalachnikov',
      type: 'carabine',
      prix: 2000,
      icon: 'ti-target-arrow',
      desc: 'Pour la défense de la Patrie. Usage personnel toléré.',
      bonus: { stat: 'PER', val: 16 },
      imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-kalachnikov-soviet.png'
    }
  ],
  khalija: [
    {
      id: 'jambiya',
      name: 'Jambiya',
      type: 'blanche',
      prix: 350,
      icon: 'ti-tools-kitchen-2',
      desc: 'Lame recourbée, tradition millénaire. Hassan l\'a aiguisée ce matin.',
      bonus: { stat: 'VOL', val: 6 },
      imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-jambiya-khalija.png'
    },
    {
      id: 'pistolet_dore',
      name: 'Pistolet doré',
      type: 'poing',
      prix: 1000,
      icon: 'ti-crosshair',
      desc: 'Serti de nacre. L\'élégance n\'exclut pas l\'efficacité.',
      bonus: { stat: 'PER', val: 9 },
      imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-pistolet-khalija.png'
    },
    {
      id: 'carabine_precision',
      name: 'Carabine de précision',
      type: 'carabine',
      prix: 2200,
      icon: 'ti-target-arrow',
      desc: 'Pour la chasse au faucon. Très grands faucons.',
      bonus: { stat: 'PER', val: 17 },
      imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-fusil-khalija.png'
    }
  ]
};

// =====================
// MODAL TRIPTIQUE D'ACHAT D'ARME
// =====================
// Correctif 2026-08-16 (audit "double circuit d'achat") : Acheter une arme est desormais
// l'UNIQUE porte d'entree d'achat au comptoir, legal ou marche noir, et les deux modalites
// puisent dans le meme stock reel (data.stockProduits, alimente par confirmerProduction).
// Plus aucune arme n'est generee ex-nihilo depuis ARMES_CATALOGUE : le catalogue ne fournit
// plus que les proprietes (nom/desc/bonus/image/type), la disponibilite et le prix viennent
// de l'entreprise armurerie-<pays> (meme circuit que l'ancien "Acheter en stock", desormais
// supprime de l'interface -- voir doAcheterProduitStock/confirmerAchatStock, retires).
async function ouvrirModalAcheterArme() {
  const pays = state.country || 'republic';
  const cur = COUNTRIES[pays]?.cur || 'FR';
  const armes = ARMES_CATALOGUE[pays] || ARMES_CATALOGUE.republic;
  const data = await chargerArmurerieLocale();
  if (!data) { showToast('Indisponible', '', false); return; }

  document.getElementById('postes-modal-title').textContent = 'Choisissez votre arme';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:1rem">Achat légal : enregistré au registre de vente, prix normal. Marché noir : non enregistré, 3x le prix, risque de dénonciation par l\'armurier. Seules les armes réellement en stock (produites par les employés de l\'armurerie) sont disponibles.</div>';
  html += '<div style="display:grid;grid-template-columns:repeat(3,1fr);gap:.6rem">';

  armes.forEach((arme) => {
    const stock = data.stockProduits[arme.id] || 0;
    const prixVente = data.parametres.prixVente[arme.id] || arme.prix;
    const prixIllegal = prixVente * 3;
    const rupture = stock <= 0;
    const typeLabel = { blanche: 'Arme blanche', poing: 'Arme de poing', carabine: 'Carabine' }[arme.type] || arme.type;
    html += '<div style="border:1px solid #2a2010;background:#0a0805;overflow:hidden;display:flex;flex-direction:column;height:100%' + (rupture ? ';opacity:.55' : '') + '">';
    // Image
    html += '<div style="width:100%;height:120px;overflow:hidden;background:#050503;flex-shrink:0">';
    if (arme.imageUrl) {
      html += '<img src="' + arme.imageUrl + '" style="width:100%;height:100%;object-fit:cover;opacity:.85"/>';
    } else {
      html += '<div style="width:100%;height:100%;display:flex;align-items:center;justify-content:center"><i class="ti ' + arme.icon + '" style="font-size:2rem;color:#3a2a10"></i></div>';
    }
    html += '</div>';
    // Infos
    html += '<div style="padding:.5rem;display:flex;flex-direction:column;flex:1">';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.08em;color:#c0b090;margin-bottom:.25rem">' + arme.name + '</div>';
    html += '<div style="font-size:.76rem;color:#b0a488;font-style:italic;margin-bottom:.5rem;line-height:1.45">' + arme.desc + '</div>';
    html += '<div style="font-size:.72rem;color:#6ab858;margin-bottom:.3rem">+' + arme.bonus.val + ' ' + arme.bonus.stat + ' · ' + typeLabel + '</div>';
    html += '<div style="font-size:.7rem;margin-bottom:.6rem;color:' + (rupture ? '#8a5a5a' : '#7a9a68') + '">' + (rupture ? 'Rupture de stock' : ('En stock : ' + stock)) + '</div>';
    html += '<div style="margin-top:auto">';
    if (rupture) {
      html += '<button disabled style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.06em;padding:.4rem;border:1px solid #3a2a20;background:transparent;color:#5a5040;cursor:default">Rupture de stock</button>';
    } else {
      html += '<button onclick="confirmerAchatArme(\'' + arme.id + '\')" style="width:100%;margin-bottom:.35rem;font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.06em;padding:.4rem;border:1px solid #4a7a3a;background:transparent;color:#7ab868;cursor:pointer" onmouseover="this.style.background=\'#0e1a0a\'" onmouseout="this.style.background=\'transparent\'">Achat légal — ' + prixVente.toLocaleString('fr-FR') + ' ' + cur + '</button>';
      html += '<button onclick="confirmerAchatArmeIllegal(\'' + arme.id + '\')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.06em;padding:.4rem;border:1px solid #8a3a3a;background:transparent;color:#cc6a6a;cursor:pointer" onmouseover="this.style.background=\'#1a0a0a\'" onmouseout="this.style.background=\'transparent\'">Marché noir — ' + prixIllegal.toLocaleString('fr-FR') + ' ' + cur + '</button>';
    }
    html += '</div>';
    html += '</div></div>';
  });

  html += '</div>';
  html += '<button onclick="document.getElementById(\'modal-postes\').classList.remove(\'open\')" style="margin-top:.8rem;width:100%;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.1em;padding:.4rem;border:1px solid #2a2010;background:transparent;color:#9a8a68;cursor:pointer">Renoncer à l\'achat</button>';
  html += '</div>';

  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerAchatArme(armeId) {
  const pays = state.country || 'republic';
  const cur = COUNTRIES[pays]?.cur || 'FR';
  const armes = ARMES_CATALOGUE[pays] || ARMES_CATALOGUE.republic;
  const arme = armes.find(a => a.id === armeId);
  if (!arme) return;

  const data = await chargerArmurerieLocale();
  if (!data) { showToast('Indisponible', '', false); return; }
  if ((data.stockProduits[armeId] || 0) <= 0) {
    showToast('Rupture de stock', 'Cette arme n\'est plus disponible pour le moment.', false);
    return;
  }

  const prixVente = data.parametres.prixVente[armeId] || arme.prix;
  const prixApplique = state.mobilisationNationaleCache ? Math.round(prixVente / 2) : prixVente;
  if (state.arg < prixApplique) {
    showToast('Fonds insuffisants', prixApplique.toLocaleString('fr-FR') + ' ' + cur + ' requis.', false);
    return;
  }

  // Deduction PA+cout centralisee (Lot 2C) -- avant toute mutation de stock/caisse.
  const r = await deduireCoutOrdre({ pa: 1, cost: prixApplique });
  if (!r.ok) { showToast(r.raison === 'pa_insuffisants' ? 'PA insuffisants' : 'Fonds insuffisants', r.raison === 'pa_insuffisants' ? '1 PA requis.' : prixApplique.toLocaleString('fr-FR') + ' ' + cur + ' requis.', false); return; }
  data.stockProduits[armeId] -= 1;
  const { net } = typeof appliquerTaxeTransaction === 'function' ? await appliquerTaxeTransaction(prixApplique) : { net: prixApplique };
  data.caisse = (data.caisse || 0) + net;
  ajouterHistoriqueEntreprise(data, net, 'Vente au comptoir — ' + arme.name);
  await sbSaveEntreprise(data.id, data);

  if (!state.inventory) state.inventory = [];
  state.inventory.push({
    id: 'arme-' + Date.now(),
    type: 'arme',
    sousType: arme.type,
    name: arme.name,
    icon: arme.icon,
    desc: arme.desc,
    legal: true,
    bonus: arme.bonus,
    imageUrl: arme.imageUrl
  });

  // Inscription au registre officiel de vente d'armes — systematique pour tout achat legal.
  // Registre local par armurerie (A2, 16 aout 2026) : city = ville reelle de l'armurerie ou la
  // vente a lieu (achat toujours effectue physiquement sur place, meme raisonnement que
  // chargerArmurerieLocale).
  if (typeof sbEnregistrerVenteArme === 'function') {
    sbEnregistrerVenteArme({
      joueur: state.char?.name || 'Anonyme',
      arme: arme.name,
      prix: prixApplique,
      pays: pays,
      city: state.currentCity || 'capitale',
      jour: state.day || 1,
      heure: state.hour || 8
    }).catch(() => {});
  }

  updateUI();
  addJournalEntry('Achat légal : ' + arme.name + ' (-' + prixApplique.toLocaleString('fr-FR') + ' ' + cur + '). Inscrit au registre.', 'event-bad');

  // Modal de confirmation "reçu officiel" avec le registre en illustration
  document.getElementById('postes-modal-title').textContent = 'Vente enregistrée';
  let html = '<div style="padding:0">';
  html += '<div style="width:100%;height:200px;overflow:hidden;background:#0a0805">';
  html += '<img src="https://raw.githubusercontent.com/FredJ74/res-publica/main/images/registre-vente-armes.png" style="width:100%;height:100%;object-fit:cover;opacity:.9"/>';
  html += '</div>';
  html += '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#a09070;line-height:1.7;font-style:italic;margin-bottom:1rem">' + arme.name + ' consignée au registre officiel des ventes. Gérard tamponne le formulaire sans lever les yeux.</div>';
  html += '<button onclick="document.getElementById(\'modal-postes\').classList.remove(\'open\')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.6rem;border:1px solid #4a7a3a;background:transparent;color:#7ab868;cursor:pointer">Fermer</button>';
  html += '</div></div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerAchatArmeIllegal(armeId) {
  const pays = state.country || 'republic';
  const cur = COUNTRIES[pays]?.cur || 'FR';
  const armes = ARMES_CATALOGUE[pays] || ARMES_CATALOGUE.republic;
  const arme = armes.find(a => a.id === armeId);
  if (!arme) return;

  const data = await chargerArmurerieLocale();
  if (!data) { showToast('Indisponible', '', false); return; }
  if ((data.stockProduits[armeId] || 0) <= 0) {
    showToast('Rupture de stock', 'Cette arme n\'est plus disponible pour le moment.', false);
    return;
  }

  const prixVente = data.parametres.prixVente[armeId] || arme.prix;
  const prixIllegal = prixVente * 3;
  if (state.arg < prixIllegal) {
    showToast('Fonds insuffisants', prixIllegal.toLocaleString('fr-FR') + ' ' + cur + ' requis (marché noir).', false);
    return;
  }

  document.getElementById('modal-postes').classList.remove('open');

  // Jet de reussite — meme logique que le vol (adapte : pas de cible, achat aupres du PNJ armurier)
  const char = state.char;
  const bonusCarriere = BONUS_CARRIERE_VOL[char?.career] || 0;
  const isPays = (typeof getIndiceVille === 'function') ? getIndiceVille(pays, state.currentCity || 'capitale', 'isn') : (INDICES_NATIONAUX[pays]?.ISN || 30);
  let tauxReussite = 50 + bonusCarriere - (isPays / 3);
  tauxReussite = (typeof consommerBonusBenediction === 'function') ? consommerBonusBenediction(tauxReussite) : tauxReussite;
  tauxReussite = Math.max(5, Math.min(95, Math.round(tauxReussite)));
  const roll = Math.random() * 100;

  if (roll > tauxReussite) {
    // ECHEC — l'armurier refuse et denonce. Rien n'a ete vendu : le stock n'est pas touche.
    if (!state.recherche) state.recherche = [];
    state.recherche.push({ acte: 'achat_arme_illegal', type: 'delit_mineur', jour: state.day });

    // Convocation au commissariat — delai fixe 24h (jour+1, meme heure)
    if (!state.convocations) state.convocations = [];
    state.convocations.push({
      motif: 'achat_arme_illegal',
      jourEmission: state.day || 1,
      heureEmission: state.hour || 8,
      jourLimite: (state.day || 1) + 1,
      heureLimite: state.hour || 8,
      traitee: false
    });

    const commissairePays = { republic:'Raoul Toufaud', narco:'El Capitan Gordo', soviet:'Camarade Borodine', khalija:'Chambellan Ibn Protocole' }[pays] || 'Le Commissariat';
    addMailNotification(commissairePays, 'Convocation officielle', 'L\'armurier a refusé la vente et vous a dénoncé. Présentez-vous au commissariat sous 24h pour vous justifier, faute de quoi vous serez arrêté(e).');

    updateUI();
    showToast('Vente refusée !', 'L\'armurier vous dénonce. Convocation au commissariat sous 24h.', false, true);
    addJournalEntry('Tentative d\'achat d\'arme au marché noir échouée. Dénoncé(e) par l\'armurier.', 'event-bad');
    return;
  }

  // REUSSITE — arme livree, non enregistree au registre, mais bien consommee du stock reel
  // Deduction PA+cout centralisee (Lot 2C) -- cout du uniquement en cas de reussite (comme deja
  // pour l'argent), AVANT toute mutation de stock/Supabase : fail-closed.
  const r = await deduireCoutOrdre({ pa: 1, cost: prixIllegal });
  if (!r.ok) { showToast(r.raison === 'pa_insuffisants' ? 'PA insuffisants' : 'Fonds insuffisants', r.raison === 'pa_insuffisants' ? '1 PA requis.' : prixIllegal.toLocaleString('fr-FR') + ' ' + cur + ' requis (marché noir).', false); return; }
  data.stockProduits[armeId] -= 1;
  await sbSaveEntreprise(data.id, data);

  if (!state.inventory) state.inventory = [];
  state.inventory.push({
    id: 'arme-' + Date.now(),
    type: 'arme',
    sousType: arme.type,
    name: arme.name,
    icon: arme.icon,
    desc: arme.desc,
    legal: false,
    bonus: arme.bonus,
    imageUrl: arme.imageUrl
  });

  if (!state.historiqueCrimes) state.historiqueCrimes = [];
  state.historiqueCrimes.push({ acte: 'achat_arme_illegal', cible: null, jour: state.day, expireJour: state.day + 8 });
  tracerActionPourRumeur('achat_arme_illegal', null);

  updateUI();
  showToast('Arme acquise (marché noir)', arme.name + ' obtenue discrètement. Non enregistrée au registre.', true, true);
  addJournalEntry('Achat clandestin : ' + arme.name + ' (-' + prixIllegal.toLocaleString('fr-FR') + ' ' + cur + ').', 'event-bad');
}


async function doConsulterRegistre() {
  const posteId = state.poste?.id;
  const posteHabilite = ['president', 'maire', 'min_int', 'min_just', 'commissaire'].includes(posteId);
  const pays = state.country || 'republic';

  if (!posteHabilite) {
    ouvrirModalCorruptionRegistre();
    return;
  }

  // Registre local (A2, 16 aout 2026) : meme une fonction nationale (president, min_int,
  // min_just) ne voit que le registre de l'armurerie ou elle se trouve physiquement -- aucune
  // vue nationale agregee.
  await afficherRegistreArmes(pays, state.currentCity || 'capitale', false);
}

function ouvrirModalCorruptionRegistre() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  document.getElementById('postes-modal-title').textContent = 'Registre de vente d\'armes';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#a09070;line-height:1.7;font-style:italic;margin-bottom:1rem">Vous n\'êtes pas habilité(e) à consulter ce registre. Vous pouvez tenter de soudoyer l\'armurier pour y avoir accès quand même — à vos risques.</div>';
  html += '<div style="display:flex;justify-content:space-between;align-items:center;padding:.6rem;background:#0a0805;border:1px solid #2a2010;margin-bottom:.8rem">';
  html += '<span style="font-size:.75rem;color:#6a5a30">Pot-de-vin</span>';
  html += '<span style="font-family:Bebas Neue,sans-serif;font-size:1rem;color:#C9A84C">100 ' + cur + '</span>';
  html += '</div>';
  html += '<button onclick="confirmerCorruptionRegistre()" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Tenter la corruption</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerCorruptionRegistre() {
  document.getElementById('modal-postes').classList.remove('open');
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cout = 100;
  if (state.arg < cout) { showToast('Fonds insuffisants', cout.toLocaleString('fr-FR') + ' ' + cur + ' requis.', false); return; }

  const roll = Math.floor(Math.random() * 100) + 1;
  if (roll <= 30) {
    state.arg -= cout;
    state.inf = Math.min(100, (state.inf || 0) + 5);
    state.pop = Math.min(100, (state.pop || 0) + 5);
    updateUI();
    showToast('Corruption réussie', 'L\'armurier accepte. +5 INF, +5 POP.', true);
    addJournalEntry('Registre consulté après corruption de l\'armurier. -' + cout.toLocaleString('fr-FR') + ' ' + cur + '.', 'event-info');
    // Corruption locale : ne donne acces qu'au registre de l'armurerie ou elle est tentee.
    await afficherRegistreArmes(state.country || 'republic', state.currentCity || 'capitale', true);
  } else {
    state.inf = Math.max(0, (state.inf || 0) - 5);
    state.pop = Math.max(0, (state.pop || 0) - 5);
    updateUI();
    showToast('Refusé !', 'L\'armurier refuse et le fait savoir. -5 INF, -5 POP.', false);
    addJournalEntry('Tentative de corruption de l\'armurier échouée. -5 INF, -5 POP.', 'event-bad');
  }
}

async function afficherRegistreArmes(pays, city, viaCorruption) {
  let ventes = [];
  if (typeof sbConsulterRegistreArmes === 'function') {
    ventes = await sbConsulterRegistreArmes(pays, city).catch(() => []);
  }

  const nomVille = WORLD[pays]?.[city]?.name || city;
  document.getElementById('postes-modal-title').textContent = 'Registre de vente d\'armes — ' + nomVille + (viaCorruption ? ' (obtenu sous le manteau)' : '');
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:1rem">Ventes légales enregistrées. Les ventes du marché noir n\'y figurent jamais.</div>';

  if (!ventes || ventes.length === 0) {
    html += '<div style="font-size:.8rem;color:#5a5040;text-align:center;padding:1.5rem 0">Aucune vente enregistrée.</div>';
  } else {
    html += '<div style="display:flex;flex-direction:column;gap:.4rem;max-height:320px;overflow-y:auto">';
    ventes.forEach(v => {
      html += '<div style="border:1px solid #2a2010;background:#0a0805;padding:.6rem;display:flex;justify-content:space-between;align-items:center">';
      html += '<div><div style="font-size:.8rem;color:#c0b090">' + v.joueur + '</div><div style="font-size:.68rem;color:#5a5040">' + v.arme + ' — Jour ' + v.jour + '</div></div>';
      html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.8rem;color:#C9A84C">' + (v.prix || 0).toLocaleString('fr-FR') + '</div>';
      html += '</div>';
    });
    html += '</div>';
  }

  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// =====================
// GILET PARE-BALLES (achat legal, modal avec image, comme le parapluie)
// =====================
function doAcheterGilet() {
  const pays = state.country || 'republic';
  const cur = COUNTRIES[pays]?.cur || 'FR';
  const prix = 600;
  const imageUrl = 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-gilet-republic.png';

  document.getElementById('postes-modal-title').textContent = 'Gilet pare-balles';
  let html = '<div style="padding:0">';
  html += '<div style="width:100%;height:200px;overflow:hidden;background:#0a0805">';
  html += '<img src="' + imageUrl + '" style="width:100%;height:100%;object-fit:cover;opacity:.9"/>';
  html += '</div>';
  html += '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#a09070;line-height:1.7;font-style:italic;margin-bottom:1rem">Protection physique standard. Vente légale, enregistrée au registre.</div>';
  html += '<div style="display:flex;justify-content:space-between;align-items:center;padding:.6rem;background:#0a0805;border:1px solid #2a2010;margin-bottom:.8rem">';
  html += '<span style="font-size:.75rem;color:#6a5a30">Prix</span>';
  html += '<span style="font-family:Bebas Neue,sans-serif;font-size:1rem;color:#C9A84C">' + prix.toLocaleString('fr-FR') + ' ' + cur + '</span>';
  html += '</div>';
  html += '<div style="display:flex;gap:.5rem">';
  html += '<button onclick="confirmerAchatGilet()" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.6rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Acheter</button>';
  html += '<button onclick="document.getElementById(&quot;modal-postes&quot;).classList.remove(&quot;open&quot;)" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.6rem;border:1px solid #3a2a10;background:transparent;color:#9a8a68;cursor:pointer">Renoncer</button>';
  html += '</div></div></div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerAchatGilet() {
  const pays = state.country || 'republic';
  const cur = COUNTRIES[pays]?.cur || 'FR';
  const prix = 600;
  document.getElementById('modal-postes').classList.remove('open');

  if (state.arg < prix) { showToast('Fonds insuffisants', prix.toLocaleString('fr-FR') + ' ' + cur + ' requis.', false); return; }

  // Deduction PA+cout centralisee (Lot 2C) -- avant toute mutation.
  const r = await deduireCoutOrdre({ pa: 1, cost: prix });
  if (!r.ok) { showToast(r.raison === 'pa_insuffisants' ? 'PA insuffisants' : 'Fonds insuffisants', r.raison === 'pa_insuffisants' ? '1 PA requis.' : prix.toLocaleString('fr-FR') + ' ' + cur + ' requis.', false); return; }
  if (!state.inventory) state.inventory = [];
  state.inventory.push({
    type: 'protection', name: 'Gilet pare-balles', icon: 'ti-shield-check', legal: true,
    desc: 'Protection physique. Enregistré dans le registre.',
    imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-gilet-republic.png'
  });
  updateUI();
  showToast('Objet acquis', 'Gilet pare-balles ajouté à votre inventaire.', true, true);
  addJournalEntry('Achat légal : Gilet pare-balles (-' + prix.toLocaleString('fr-FR') + ' ' + cur + ').', 'event-info');
}

// =====================
// EXPLOSIFS (marche noir, modal avec image, comme le parapluie)
// =====================
// Explosifs reglementaires, reserves au Ministre de la Defense — traçables (contrairement
// a la version marche noir), pas de risque ni de cout : ordre defini dans data.js
// (acheter_bombe_mil) mais jamais routee. Corrige le 5 aout 2026.
async function doObtenirExplosifsMilitaires(pa, cost) {
  if (state.poste?.id !== 'min_def') {
    showToast('Accès refusé', 'Réservé au Ministre de la Défense.', false);
    return;
  }
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }
  if (!state.inventory) state.inventory = [];
  state.inventory.push({
    type: 'explosif', name: 'Explosifs militaires réglementaires', icon: 'ti-bomb', legal: true,
    desc: 'Explosifs traçables, obtenus légalement par le Ministère de la Défense. Usage unique.',
    imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/explosifs-marche-noir.png'
  });
  updateUI();
  showToast('Explosifs obtenus', 'Explosifs réglementaires ajoutés à votre inventaire.', true, true);
  addJournalEntry('Explosifs militaires réglementaires obtenus (Ministère de la Défense).', 'event-info');
}

// =====================
// MARCHE NOIR — regroupe, a l'endroit ou il se trouve deja pour chaque empire (Armurerie pour
// republic/soviet, Marche pour narco/khalija — meme vendeur, pas de deplacement de lieu),
// l'achat d'explosifs et le poison local unique a cet empire (POISON_OBJETS). Peaufinage
// Armurerie du 9 aout 2026 : plus de catalogue transversal, chaque empire garde son marche
// noir cloisonne.
// =====================
function doMarcheNoir() {
  const pays = state.country || 'republic';
  const cur = COUNTRIES[pays]?.cur || 'FR';
  const poisonType = Object.keys(POISON_OBJETS).find(k => POISON_OBJETS[k].empire === pays);
  const poison = poisonType ? POISON_OBJETS[poisonType] : null;

  document.getElementById('postes-modal-title').textContent = 'Marché Noir';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.75rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Rien de tout cela n\'est enregistré nulle part. À vos risques.</div>';

  html += '<div onclick="doAcheterExplosifs(2,0)" style="cursor:pointer;display:flex;justify-content:space-between;align-items:center;padding:.7rem;border:1px solid #2a2010;background:#0a0805;margin-bottom:.5rem" onmouseover="this.style.background=\'#140a0a\'" onmouseout="this.style.background=\'#0a0805\'">';
  html += '<span style="font-size:.85rem;color:#c0b090"><i class="ti ti-bomb" style="margin-right:.5rem;color:#cc6a6a"></i>Explosifs</span>';
  html += '<span style="font-family:Bebas Neue,sans-serif;font-size:.9rem;color:#C9A84C">1 200 ' + cur + '</span>';
  html += '</div>';

  if (poison) {
    // PA declares par type dans data.js (acheter_ghb:1, acheter_polonium:2, acheter_vipere:1) --
    // pas de valeur unique commune, cf. correctif marche-noir/emprunts du 9 aout 2026.
    const poisonPaParType = { ghb: 1, polonium: 2, vipere: 1 };
    const poisonPa = poisonPaParType[poisonType];
    html += '<div onclick="doAcheterPoisonObjet(&quot;' + poisonType + '&quot;,' + poisonPa + ',' + poison.cout + ')" style="cursor:pointer;display:flex;justify-content:space-between;align-items:center;padding:.7rem;border:1px solid #2a2010;background:#0a0805" onmouseover="this.style.background=\'#140a0a\'" onmouseout="this.style.background=\'#0a0805\'">';
    html += '<span style="font-size:.85rem;color:#c0b090"><i class="ti ' + poison.icon + '" style="margin-right:.5rem;color:#cc6a6a"></i>' + poison.name + '</span>';
    html += '<span style="font-family:Bebas Neue,sans-serif;font-size:.9rem;color:#C9A84C">' + poison.cout.toLocaleString('fr-FR') + ' ' + cur + '</span>';
    html += '</div>';
  }

  html += '<button onclick="document.getElementById(\'modal-postes\').classList.remove(\'open\')" style="margin-top:.8rem;width:100%;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.1em;padding:.5rem;border:1px solid #2a2010;background:transparent;color:#9a8a68;cursor:pointer">Fermer</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function doAcheterExplosifs(pa, cost) {
  const pays = state.country || 'republic';
  const cur = COUNTRIES[pays]?.cur || 'FR';
  const prix = 1200;
  const imageUrl = 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/explosifs-marche-noir.png';

  document.getElementById('postes-modal-title').textContent = 'Explosifs (marché noir)';
  let html = '<div style="padding:0">';
  html += '<div style="width:100%;height:200px;overflow:hidden;background:#0a0805">';
  html += '<img src="' + imageUrl + '" style="width:100%;height:100%;object-fit:cover;opacity:.9"/>';
  html += '</div>';
  html += '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#a09070;line-height:1.7;font-style:italic;margin-bottom:1rem">Non enregistré. Le vendeur reste prudent — tout dépend de votre réputation et du régime en place. En cas de méfiance, il alerte la police.</div>';
  html += '<div style="display:flex;justify-content:space-between;align-items:center;padding:.6rem;background:#0a0805;border:1px solid #2a2010;margin-bottom:.8rem">';
  html += '<span style="font-size:.75rem;color:#6a5a30">Prix</span>';
  html += '<span style="font-family:Bebas Neue,sans-serif;font-size:1rem;color:#C9A84C">' + prix.toLocaleString('fr-FR') + ' ' + cur + '</span>';
  html += '</div>';
  html += '<div style="display:flex;gap:.5rem">';
  html += '<button onclick="confirmerAchatExplosifs(' + pa + ',' + cost + ')" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.6rem;border:1px solid #8a3a3a;background:transparent;color:#cc6a6a;cursor:pointer">Acheter</button>';
  html += '<button onclick="document.getElementById(&quot;modal-postes&quot;).classList.remove(&quot;open&quot;)" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.6rem;border:1px solid #3a2a10;background:transparent;color:#9a8a68;cursor:pointer">Renoncer</button>';
  html += '</div></div></div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerAchatExplosifs(pa, cost) {
  const pays = state.country || 'republic';
  const cur = COUNTRIES[pays]?.cur || 'FR';
  const prix = 1200;
  document.getElementById('modal-postes').classList.remove('open');

  if (state.arg < prix) { showToast('Fonds insuffisants', prix.toLocaleString('fr-FR') + ' ' + cur + ' requis.', false); return; }

  const r = await deduireCoutOrdre({ pa, cost: 0 });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }

  const roll = Math.floor(Math.random() * 100) + 1;
  const empMod = { republic:0, narco:20, soviet:-10, khalija:0 }[pays] || 0;
  const careerBonus = state.char?.career === 'criminel' ? 15 : 0;
  const taux = Math.max(5, Math.min(95, 35 + empMod + careerBonus - getMalusISN()));

  if (roll > taux) {
    // ECHEC — le vendeur alerte la police, pas de debit
    if (!state.recherche) state.recherche = [];
    state.recherche.push({ acte: 'acheter_bombe_illegale', type: 'crime', jour: state.day });
    updateUI();
    showToast('Vente refusée !', 'Le vendeur se méfie et alerte la police. Vous êtes recherché(e).', false, true);
    addJournalEntry('Tentative d\'achat d\'explosifs échouée. Alerte donnée par le vendeur.', 'event-bad');
    return;
  }

  // REUSSITE
  state.arg -= prix;
  if (!state.inventory) state.inventory = [];
  state.inventory.push({
    type: 'explosif', name: 'Explosifs de chantier', icon: 'ti-bomb', legal: false,
    desc: 'Non enregistré. Usage unique.',
    imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/explosifs-marche-noir.png'
  });

  if (!state.historiqueCrimes) state.historiqueCrimes = [];
  state.historiqueCrimes.push({ acte: 'acheter_bombe_illegale', cible: null, jour: state.day, expireJour: state.day + 8 });
  tracerActionPourRumeur('acheter_bombe_illegale', null);

  updateUI();
  showToast('Explosifs acquis', 'Livraison discrète effectuée. Non enregistrée.', true, true);
  addJournalEntry('Achat clandestin : Explosifs (-' + prix.toLocaleString('fr-FR') + ' ' + cur + ').', 'event-bad');
}

// =====================
// INCENDIER (bâtiment courant)
// =====================
function doIncendier() {
  const b = BUILDINGS[state.currentBuilding];
  if (!b) { showToast('Impossible', 'Vous devez être dans un bâtiment pour tenter ceci.', false); return; }

  const malusCentre = BATIMENTS_CENTRES_POUVOIR.includes(state.currentBuilding) ? MALUS_CENTRE_POUVOIR : 0;

  document.getElementById('postes-modal-title').textContent = 'Incendier — ' + b.name;
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.82rem;color:#cc4444;font-style:italic;margin-bottom:1rem;padding:.5rem;background:#0f0505;border:1px solid #3a1010">Acte criminel. Un incendie ravage ce bâtiment, le fermant temporairement (1 à 3 jours selon la réussite).' + (malusCentre ? ' Bâtiment stratégique : surveillance renforcée, malus important.' : '') + '</div>';
  html += '<button onclick="confirmerIncendier()" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a3a20;background:transparent;color:#cc6a44;cursor:pointer">🔥 Mettre le feu (3 PA)</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerIncendier() {
  document.getElementById('modal-postes').classList.remove('open');
  const buildingId = state.currentBuilding;
  const b = BUILDINGS[buildingId];
  if (!b) return;
  // Deduction PA centralisee (Lot 2A) -- deduireCoutOrdre() est l'AUTORITE UNIQUE sur la
  // disponibilite des PA (poche historique jamais migree au Lot 1). Appelee ICI, avant toute
  // mutation (fermeture du batiment, historique de crimes) : fail-closed.
  const rPa = await deduireCoutOrdre({ pa: 3, cost: 0 });
  if (!rPa.ok) { showToast('PA insuffisants', '3 PA requis.', false); return; }

  const malusISN = getMalusISN();
  const careerBonus = state.char?.career === 'criminel' ? 15 : 0;
  const malusCentre = BATIMENTS_CENTRES_POUVOIR.includes(buildingId) ? MALUS_CENTRE_POUVOIR : 0;
  const taux = Math.max(5, 30 + careerBonus - malusISN - malusCentre);
  const roll = Math.floor(Math.random() * 100) + 1;

  let joursFermeture = 0;
  if (roll <= taux * 0.5) joursFermeture = 3;
  else if (roll <= taux * 0.8) joursFermeture = 2;
  else if (roll <= taux) joursFermeture = 1;

  if (joursFermeture > 0) {
    const jourFin = state.day + joursFermeture;
    const fermeture = { pays: state.country, ville: state.currentCity, batiment_id: buildingId, jour_fin: jourFin, motif: 'incendie', auteur: state.char?.name || 'Anonyme' };
    if (typeof sbFermerBatiment === 'function') sbFermerBatiment(fermeture).catch(() => {});
    if (!state.batimentsFermesCache) state.batimentsFermesCache = [];
    state.batimentsFermesCache.push(fermeture);

    addExternalEvent('INCENDIE : ' + b.name + ' ravagé par les flammes. Fermé ' + joursFermeture + ' jour(s).');
    showToast('Incendie déclenché', b.name + ' fermé ' + joursFermeture + ' jour(s).', true, true);
    addJournalEntry('Incendie déclenché sur ' + b.name + '. Fermeture : ' + joursFermeture + ' jour(s).', 'event-bad');
  } else {
    showToast('Incendie raté', 'Le feu ne prend pas. Rien ne se passe.', false);
    addJournalEntry('Tentative d\'incendie ratée sur ' + b.name + '.', 'event-bad');
  }

  // Risque d'etre repere sur le fait, independamment du resultat de l'incendie
  const detectRate = ACTES_ILLEGAUX['incendier']?.detectRate || 70;
  const repere = (Math.floor(Math.random() * 100) + 1) <= detectRate;
  if (repere) {
    if (!state.recherche) state.recherche = [];
    state.recherche.push({ acte: 'incendier', type: 'crime', jour: state.day });
    addExternalEvent('ALERTE : un témoin vous a reconnu près de l\'incendie.');
  } else if (joursFermeture > 0) {
    // Reussi et non repere sur le champ -> reste decouvrable plus tard via enquete
    if (!state.historiqueCrimes) state.historiqueCrimes = [];
    state.historiqueCrimes.push({ acte: 'incendier', cible: buildingId, jour: state.day, expireJour: state.day + 8 });
    tracerActionPourRumeur('incendier', b.name);
  }
  updateUI();
}

// =====================
// UTILISER DES EXPLOSIFS (bâtiment + occupants de la pièce)
// =====================
function doUtiliserExplosifs() {
  const explosifIdx = (state.inventory || []).findIndex(i => i.type === 'explosif');
  if (explosifIdx === -1) {
    showToast('Objet manquant', 'Vous n\'avez pas d\'explosifs dans votre inventaire. Procurez-vous en à l\'armurerie.', false);
    return;
  }
  const b = BUILDINGS[state.currentBuilding];
  if (!b) { showToast('Impossible', 'Vous devez être dans un bâtiment pour tenter ceci.', false); return; }

  const malusCentre = BATIMENTS_CENTRES_POUVOIR.includes(state.currentBuilding) ? MALUS_CENTRE_POUVOIR : 0;
  const autresPresents = getCurrentRoomPersons().filter(p => p.isPJ && p.name !== state.char?.name);

  document.getElementById('postes-modal-title').textContent = 'Utiliser les explosifs — ' + b.name;
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.82rem;color:#cc4444;font-style:italic;margin-bottom:1rem;padding:.5rem;background:#0f0505;border:1px solid #3a1010">Acte criminel grave. Fermeture du bâtiment 5 jours en cas de réussite. Toute personne présente dans la pièce (hormis vous) sera blessée.' + (autresPresents.length ? ' Actuellement présent(s) : ' + autresPresents.map(p=>p.name).join(', ') + '.' : ' Personne d\'autre présent pour le moment.') + (malusCentre ? ' Bâtiment stratégique : surveillance renforcée, malus important.' : '') + ' En cas d\'échec, seul(e) vous serez blessé(e), progressivement.</div>';
  html += '<button onclick="confirmerUtiliserExplosifs()" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a3a20;background:transparent;color:#cc6a44;cursor:pointer">💣 Déclencher (3 PA)</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerUtiliserExplosifs() {
  document.getElementById('modal-postes').classList.remove('open');
  const explosifIdx = (state.inventory || []).findIndex(i => i.type === 'explosif');
  if (explosifIdx === -1) return;
  const buildingId = state.currentBuilding;
  const b = BUILDINGS[buildingId];
  if (!b) return;

  // Deduction PA centralisee (Lot 2A, correctif suite a revue Lot 1) -- deduireCoutOrdre() est
  // l'AUTORITE UNIQUE sur la disponibilite des PA. Appelee ICI, AVANT la consommation de
  // l'objet (mutation irreversible de l'inventaire, jusqu'ici prealable a la deduction PA) :
  // fail-closed, l'explosif reste en inventaire si les PA manquent.
  const rPa = await deduireCoutOrdre({ pa: 3, cost: 0 });
  if (!rPa.ok) { showToast('PA insuffisants', '3 PA requis.', false); return; }

  // Consommer l'objet (usage unique)
  state.inventory.splice(explosifIdx, 1);

  const malusISN = getMalusISN();
  const careerBonus = state.char?.career === 'criminel' ? 15 : 0;
  const malusCentre = BATIMENTS_CENTRES_POUVOIR.includes(buildingId) ? MALUS_CENTRE_POUVOIR : 0;
  const taux = Math.max(5, 35 + careerBonus - malusISN - malusCentre);
  const roll = Math.floor(Math.random() * 100) + 1;
  const reussi = roll <= taux;

  const autresPresents = getCurrentRoomPersons().filter(p => p.isPJ && p.name !== state.char?.name);

  if (reussi) {
    const jourFin = state.day + 5;
    const fermeture = { pays: state.country, ville: state.currentCity, batiment_id: buildingId, jour_fin: jourFin, motif: 'explosifs', auteur: state.char?.name || 'Anonyme' };
    if (typeof sbFermerBatiment === 'function') sbFermerBatiment(fermeture).catch(() => {});
    if (!state.batimentsFermesCache) state.batimentsFermesCache = [];
    state.batimentsFermesCache.push(fermeture);

    // Victimes : toutes les personnes reelles presentes dans la piece, sauf l'auteur
    for (const p of autresPresents) {
      if (typeof sbDeposerImpactIndice === 'function') {
        await sbDeposerImpactIndice({
          id: 'explosion-' + Date.now() + '-' + Math.floor(Math.random()*1000),
          victime: p.name,
          indice: 'hp_set',
          delta: 15,
          traite: false
        }).catch(() => {});
      }
      if (typeof sbSendMail === 'function') {
        sbSendMail('Événement', p.name, 'Explosion !', 'Une explosion s\'est produite dans la pièce où vous vous trouviez. Vous êtes gravement blessé(e).', formatJourHeure()).catch(() => {});
      }
    }

    addExternalEvent('EXPLOSION : ' + b.name + ' dévasté par un attentat à l\'explosif. Fermé 5 jours.' + (autresPresents.length ? ' ' + autresPresents.length + ' blessé(s).' : ''));
    showToast('Explosifs déclenchés', b.name + ' fermé 5 jours.' + (autresPresents.length ? ' ' + autresPresents.length + ' victime(s).' : ''), true, true);
    addJournalEntry('Explosifs utilisés sur ' + b.name + '. Fermeture : 5 jours.', 'event-bad');
  } else {
    // Echec : l'auteur seul est blesse, progressivement (a partir du prochain dormir)
    state.explosifBlesse = { jourDebut: state.day };
    showToast('Explosifs ratés', 'Le dispositif vous explose entre les mains. Vous êtes blessé(e).', false);
    addJournalEntry('Tentative ratée d\'utilisation d\'explosifs sur ' + b.name + '. Vous êtes blessé(e).', 'event-bad');
  }

  // Risque d'etre repere sur le fait, independamment du resultat
  const detectRate = ACTES_ILLEGAUX['utiliser_explosifs']?.detectRate || 65;
  const repere = (Math.floor(Math.random() * 100) + 1) <= detectRate;
  if (repere) {
    if (!state.recherche) state.recherche = [];
    state.recherche.push({ acte: 'utiliser_explosifs', type: 'crime', jour: state.day });
    addExternalEvent('ALERTE : un témoin vous a reconnu près de l\'explosion.');
  } else if (reussi) {
    if (!state.historiqueCrimes) state.historiqueCrimes = [];
    state.historiqueCrimes.push({ acte: 'utiliser_explosifs', cible: buildingId, jour: state.day, expireJour: state.day + 8 });
    tracerActionPourRumeur('utiliser_explosifs', b.name);
  }
  updateUI();
}

function doAcheterPoisonObjet(type, pa, cost) {
  const obj = POISON_OBJETS[type];
  if (!obj) return;
  const pays = state.country || 'republic';
  const cur = COUNTRIES[pays]?.cur || 'FR';

  // Afficher le modal d'achat avec image et description parodique
  const desc = POISON_DESC_PARODIQUE[type] || obj.msg;
  const imageUrl = {
    parapluie: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/parapluie-republicain.png',
    polonium:  'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/polonium-sovarka.png',
    ghb:       'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/ghb-narco.jpg',
    vipere:    'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/vipere-des-sables-khalija.png'
  }[type] || '';

  document.getElementById('postes-modal-title').textContent = obj.name;
  let html = '<div style="padding:0">';
  if (imageUrl) {
    html += '<div style="width:100%;height:200px;overflow:hidden;background:#0a0805">';
    html += '<img src="' + imageUrl + '" style="width:100%;height:100%;object-fit:cover;opacity:.9"/>';
    html += '</div>';
  }
  html += '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#a09070;line-height:1.7;font-style:italic;margin-bottom:1rem">' + desc + '</div>';
  html += '<div style="display:flex;justify-content:space-between;align-items:center;padding:.6rem;background:#0a0805;border:1px solid #2a2010;margin-bottom:.8rem">';
  html += '<span style="font-size:.75rem;color:#6a5a30">Prix</span>';
  html += '<span style="font-family:Bebas Neue,sans-serif;font-size:1rem;color:#C9A84C">' + obj.cout.toLocaleString('fr-FR') + ' ' + cur + '</span>';
  html += '</div>';
  html += '<div style="display:flex;gap:.5rem">';
  html += '<button onclick="confirmerAchatPoison(&quot;' + type + '&quot;,' + pa + ',' + cost + ')" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.6rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Acheter</button>';
  html += '<button onclick="document.getElementById(&quot;modal-postes&quot;).classList.remove(&quot;open&quot;)" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.6rem;border:1px solid #3a2a10;background:transparent;color:#9a8a68;cursor:pointer">Renoncer</button>';
  html += '</div></div></div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerAchatPoison(type, pa, cost) {
  const obj = POISON_OBJETS[type];
  if (!obj) return;
  const pays = state.country || 'republic';
  const cur = COUNTRIES[pays]?.cur || 'FR';

  document.getElementById('modal-postes').classList.remove('open');

  if (state.arg < obj.cout) { showToast('Fonds insuffisants', obj.cout + ' ' + cur + ' requis.', false); return; }

  const r = await deduireCoutOrdre({ pa, cost: 0 });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }

  state.arg -= obj.cout;
  if (!state.inventory) state.inventory = [];
  state.inventory.push({
    type: 'poison', name: obj.name, icon: obj.icon,
    poisonType: type, legal: false, usageUnique: true,
    desc: obj.msg,
    imageUrl: {
      parapluie: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/parapluie-republicain.png',
      polonium:  'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/polonium-sovarka.png',
      ghb:       'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/ghb-narco.jpg',
      vipere:    'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/vipere-des-sables-khalija.png'
    }[type] || ''
  });
  updateUI();
  showToast('Objet acquis', obj.name + ' ajouté à votre inventaire. Usage unique.', true, true);
  addJournalEntry('Achat : ' + obj.name, 'event-bad');
}

// =====================
// ASSASSINER
// =====================
function ouvrirModalAssassiner() {
  // Verifier prérequis : se cacher réussi
  if (!state.estCache) {
    showToast('Prérequis manquant', 'Vous devez d\'abord réussir l\'ordre "Se cacher" dans cette pièce.', false);
    return;
  }
  const personnesPresentes = getCurrentRoomPersons().filter(p => p.isPJ && p.name !== state.char?.name);
  if (personnesPresentes.length === 0) {
    showToast('Personne à cibler', 'Aucun PJ dans cette pièce.', false);
    return;
  }

  document.getElementById('postes-modal-title').textContent = 'Assassiner';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#cc4444;font-style:italic;margin-bottom:.8rem">Acte illégal. Prérequis : Se cacher réussi. Taux base : 35% − PER cible/10 + Bonus empire + Bonus carrière criminel +15%.</div>';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">CIBLE</div>';
  personnesPresentes.forEach(p => {
    html += '<div onclick="confirmerAssassinat(\'' + p.name + '\')" style="padding:.7rem;border:1px solid #3a1010;background:#0f0505;margin-bottom:.4rem;cursor:pointer;display:flex;align-items:center;justify-content:space-between" onmouseover="this.style.background=\'#1a0808\'" onmouseout="this.style.background=\'#0f0505\'">';
    html += '<div style="font-size:.85rem;color:#c0b090">' + p.name + '</div>';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.85rem;color:#cc4444">ÉLIMINER</div>';
    html += '</div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerAssassinat(cibleNom) {
  document.getElementById('modal-postes').classList.remove('open');
  const pays = state.country || 'republic';
  const empMod = { republic:0, narco:20, soviet:-10, khalija:0 }[pays] || 0;
  const careerBonus = state.char?.career === 'criminel' ? 15 : 0;
  const perCible = 50; // Simulation PER cible - en vrai multijoueur on lirait le localStorage cible
  const taux = Math.max(5, 35 - Math.floor(perCible/10) + empMod + careerBonus - getMalusISN());
  const roll = Math.floor(Math.random() * 100) + 1;

  if (roll <= taux) {
    // Succes
    state.estCache = false;
    showToast('Assassinat réussi', cibleNom + ' est hors de combat. 0 PA 0 HP.', true, true);
    addJournalEntry('Assassinat de ' + cibleNom + ' réussi.', 'event-bad');
    addExternalEvent('ALERTE : ' + cibleNom + ' vient d\'être assassiné(e) ! Aucun témoin.');
    addMailNotification('Événement', 'Vous avez été assassiné(e)', 'Quelqu\'un vous a attaqué. Vous êtes à 0 PA et 0 HP. Passez l\'ordre Dormir pour récupérer.');
    // Enregistrer dans l'historique criminel (disparait apres 8 jours)
    if (!state.historiqueCrimes) state.historiqueCrimes = [];
    state.historiqueCrimes.push({ acte:'assassinat', cible:cibleNom, jour:state.day, expireJour: state.day + 8 });
  } else {
    // Echec
    state.estCache = false;
    state.recherche = [{ acte:'tentative_assassinat', type:'crime', jour:state.day, peine:2 }];
    showToast('Échec ! Vous êtes repéré(e)', 'Tentative d\'assassinat ratée. Recherché(e). 2 jours de prison.', false);
    addJournalEntry('Tentative d\'assassinat ratée. Statut : Recherché.', 'event-bad');
    addExternalEvent('ALERTE : Tentative d\'assassinat sur ' + cibleNom + ' ! L\'auteur est en fuite.');
    updateUI();
  }
}

// =====================
// EMPOISONNER
// =====================
const POISON_MESSAGES = {
  parapluie: 'Quelque chose vous pique dans le dos. Une douleur irradie dans tout votre corps et s\'intensifie d\'heure en heure. Était-ce en lien avec cette personne qui vous a touché avec le bout de son parapluie et s\'est excusée ? Vous perdez 2 PA.',
  ghb:       'Votre esprit devient confus. Vous avez la tête qui tourne et vos sens sont perturbés. Vous avez l\'impression d\'avoir été drogué(e), mais par qui ? Vous perdez 2 PA.',
  polonium:  'Vous vous sentez subitement faible. En passant la main dans vos cheveux, ils se décrochent par paquets de votre crâne, comme si vous aviez été mis(e) en contact avec quelque chose de radioactif. Vous perdez 2 PA.',
  vipere:    'Vous ressentez une violente douleur au niveau du mollet. Deux petits trous douloureux et rouges sont visibles. Un serpent vous aurait-il mordu(e) ? Vous perdez 2 PA.'
};

const POISON_STAT_PERDUE = {
  republic: 'VOL',
  narco:    'PER',
  soviet:   'INT',
  khalija:  'CHA'
};

function ouvrirModalEmpoisonner() {
  if (!state.estCache) {
    showToast('Prérequis manquant', 'Vous devez d\'abord réussir l\'ordre "Se cacher" dans cette pièce.', false);
    return;
  }
  const poisonInventaire = (state.inventory || []).find(i => i.type === 'poison');
  if (!poisonInventaire) {
    showToast('Objet manquant', 'Vous n\'avez pas d\'objet poison dans votre inventaire. Procurez-vous en dans votre empire.', false);
    return;
  }
  const personnesPresentes = getCurrentRoomPersons().filter(p => p.isPJ && p.name !== state.char?.name);
  if (personnesPresentes.length === 0) {
    showToast('Personne à cibler', 'Aucun PJ dans cette pièce.', false);
    return;
  }

  document.getElementById('postes-modal-title').textContent = 'Empoisonner';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#cc4444;font-style:italic;margin-bottom:.8rem">Acte illégal. Objet : ' + poisonInventaire.name + ' (usage unique). Effets progressifs sur 3 jours.</div>';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">CIBLE</div>';
  personnesPresentes.forEach(p => {
    html += '<div onclick="confirmerEmpoisonnement(\'' + p.name + '\')" style="padding:.7rem;border:1px solid #2a1a30;background:#0f050f;margin-bottom:.4rem;cursor:pointer" onmouseover="this.style.background=\'#1a0818\'" onmouseout="this.style.background=\'#0f050f\'">';
    html += '<div style="font-size:.85rem;color:#c0b090">' + p.name + '</div>';
    html += '</div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerEmpoisonnement(cibleNom) {
  document.getElementById('modal-postes').classList.remove('open');
  const pays = state.country || 'republic';
  const empMod = { republic:0, narco:20, soviet:-10, khalija:0 }[pays] || 0;
  const careerBonus = state.char?.career === 'criminel' ? 15 : 0;
  const perCible = 50;
  const taux = Math.max(5, 40 - Math.floor(perCible/10) + empMod + careerBonus - getMalusISN());
  const roll = Math.floor(Math.random() * 100) + 1;

  // Supprimer l'objet poison de l'inventaire (usage unique)
  const poisonObj = (state.inventory || []).find(i => i.type === 'poison');
  const poisonIdx = (state.inventory || []).findIndex(i => i.type === 'poison');
  if (poisonIdx >= 0) state.inventory.splice(poisonIdx, 1);

  const poisonType = poisonObj?.poisonType || 'parapluie';

  // 4 paliers identiques au systeme d'assassinat
  const seuilReussiteTotale = taux / 2;
  const seuilReussitePartielle = taux;
  const seuilEchecPartiel = taux + (100 - taux) / 2;

  let palier, pvCible;
  if (roll <= seuilReussiteTotale)       { palier = 'totale';       pvCible = 0;  }
  else if (roll <= seuilReussitePartielle) { palier = 'partielle';    pvCible = 25; }
  else if (roll <= seuilEchecPartiel)      { palier = 'echec_partiel'; pvCible = 50; }
  else                                     { palier = 'echec_total';   pvCible = null; }

  state.estCache = false;

  const reussi = palier === 'totale' || palier === 'partielle';

  if (reussi || palier === 'echec_partiel') {
    if (typeof sbDeposerImpactIndice === 'function') {
      const STATS_POSSIBLES = ['INT','CHA','VOL','PER','DUP','ENT'];
      const statsTouchees = STATS_POSSIBLES.slice().sort(() => Math.random() - 0.5).slice(0, 2);
      await sbDeposerImpactIndice({
        id: 'poison-' + Date.now(),
        victime: cibleNom,
        indice: 'poison_start',
        palier: palier,
        poisonType: poisonType,
        statsTouchees: statsTouchees,
        traite: false
      }).catch(() => {});
    }

    // Notification narrative a la victime (mail)
    if (typeof sbSendMail === 'function') {
      const msg = (POISON_MESSAGES && POISON_MESSAGES[poisonType]) || 'Vous vous sentez soudainement très mal...';
      const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : 'Jour ' + state.day;
      await sbSendMail('Événement mystérieux', cibleNom, 'Vous vous sentez mal...', msg, time).catch(() => {});
    }

    addExternalEvent('MYSTÈRE : ' + cibleNom + ' se sent soudainement très mal...');

    if (!state.historiqueCrimes) state.historiqueCrimes = [];
    state.historiqueCrimes.push({ acte:'empoisonnement', cible:cibleNom, jour:state.day, expireJour: state.day + 8 });
    tracerActionPourRumeur('empoisonnement', cibleNom);

    const msgPalier = reussi
      ? cibleNom + ' commence à ressentir les effets du poison. Objet utilisé.'
      : cibleNom + ' ressent une légère gêne mais l\'empoisonnement est partiel.';
    showToast('Poison administré', msgPalier, true, reussi);
    addJournalEntry('Empoisonnement de ' + cibleNom + ' (' + palier + '). Objet utilisé.', 'event-bad');

    // Detection potentielle
    checkDetection('empoisonnement', 'success');

  } else {
    // Echec total — identifie sur le coup
    state.recherche = [{ acte:'tentative_empoisonnement', type:'crime', jour:state.day }];
    showToast('Échec ! Repéré(e)', 'L\'empoisonnement a échoué. Objet perdu. Vous avez été identifié(e).', false);
    addJournalEntry('Tentative d\'empoisonnement échouée. Recherché(e).', 'event-bad');
    setTimeout(() => ouvrirModalArrestation('crime'), 800);
  }

  updateUI();
}

// =====================

// SYSTEME INFORMATEURS
// =====================
const INFORMATEUR_NIVEAUX = {
  1: { label:'Informateur de rue',      cout:150, lieux:['hotel-republica','marche','bar-des-pecheurs'], desc:'Localisation approximative, rumeurs locales.' },
  2: { label:'Informateur politique',   cout:400, lieux:['loge-maconnique','universite','siege-syndical'], desc:'Localisation précise, intentions vote, voyages.' },
  3: { label:'Informateur criminel',    cout:700, lieux:['port-sainte-marie','bar-des-pecheurs','contrebande'], desc:'Indice empire d\'origine d\'un crime, contrebandes.' },
  4: { label:'Taupe',                   cout:1500, lieux:['loge-maconnique'], desc:'Confessions, transactions, ordres passés 24h.' }
};

function getInfomateurInfo(niveau) {
  const pays = state.country || 'republic';
  const infos = {
    1: [
      (state.char?.name||'Anonyme') + ' a été aperçu(e) dans le quartier nord de la ville.',
      'Un PJ inconnu a été vu entrer et sortir rapidement du commissariat.',
      'Des rumeurs circulent sur une prochaine élection anticipée.',
      'Quelqu\'un cherche à recruter des partisans discrètement.'
    ],
    2: [
      'Un député a été vu entrer au Palais Présidentiel ce matin.',
      'Des tractations sont en cours pour une alliance électorale secrète.',
      'Un PJ influent a pris l\'avion hier soir vers un autre empire.',
      'Le vote de mercredi prochain semble déjà arrangé par deux députés.'
    ],
    3: [
      'L\'auteur du crime récent semble venir de ' + (['Républia','El Estado','Sovarka','Al-Khalija'][Math.floor(Math.random()*4)]) + '.',
      'Une cargaison suspecte est attendue au port dans les prochaines 24h.',
      'Des échanges d\'argent non déclarés ont eu lieu entre deux PJ.',
      'Un contrat a été passé dans les milieux criminels contre un élu.'
    ],
    4: [
      'Un PJ a confessé au Grand Prêtre avoir falsifié des documents électoraux.',
      'Une transaction de 5000 FR a été effectuée entre deux PJ hier soir.',
      'Dans les dernières 24h, un PJ a passé les ordres : Corrompre, Produire une fuite.',
      'Un ministre prépare sa démission et contacte l\'opposition en secret.'
    ]
  };
  const list = infos[niveau] || infos[1];
  return list[Math.floor(Math.random() * list.length)];
}

function ouvrirRecruterInformateur(niveau, pa) {
  const cfg = INFORMATEUR_NIVEAUX[niveau];
  if (!cfg) return;
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  // Verifier max 2 informateurs
  if (!state.informateurs) state.informateurs = [];
  if (state.informateurs.length >= 2) {
    showToast('Maximum atteint', 'Vous ne pouvez avoir que 2 informateurs simultanément.', false);
    return;
  }
  // Verifier si niveau deja actif
  if (state.informateurs.find(i => i.niveau === niveau)) {
    showToast('Déjà actif', 'Vous avez déjà un informateur de niveau ' + niveau + '.', false);
    return;
  }

  document.getElementById('postes-modal-title').textContent = 'Recruter un informateur — Niveau ' + niveau;
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1.2rem">' +
    '<div style="font-size:.85rem;color:#c0b090;line-height:1.7;font-family:Crimson Pro,serif;margin-bottom:.8rem">' + cfg.desc + '</div>' +
    '<div style="font-size:.75rem;color:#8a6a20;margin-bottom:1rem">Coût : <strong>' + cfg.cout + ' ' + cur + '/jour</strong> · Prélevé à chaque Dormir · Max 2 informateurs simultanés</div>' +
    '<button onclick="confirmerRecrutementInformateur(' + niveau + ',' + pa + ')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.4rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Recruter</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerRecrutementInformateur(niveau, pa) {
  document.getElementById('modal-postes').classList.remove('open');
  const cfg = INFORMATEUR_NIVEAUX[niveau];
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  if (state.arg < cfg.cout) {
    showToast('Fonds insuffisants', cfg.cout + ' ' + cur + ' requis.', false);
    return;
  }
  // Deduction PA+cout centralisee (Lot 2C) -- pa vient du dispatch (2 pour recruter_info_3,
  // 3 pour recruter_info_4, exactement les valeurs declarees dans data.js), debite une seule
  // fois. cout = le premier jour du salaire recurrent (deja preleve immediatement avant ce lot,
  // logique financiere inchangee).
  const r = await deduireCoutOrdre({ pa, cost: cfg.cout });
  if (!r.ok) { showToast(r.raison === 'pa_insuffisants' ? 'PA insuffisants' : 'Fonds insuffisants', r.raison === 'pa_insuffisants' ? pa + ' PA requis.' : cfg.cout + ' ' + cur + ' requis.', false); return; }
  if (!state.informateurs) state.informateurs = [];
  state.informateurs.push({ niveau, label: cfg.label, cout: cfg.cout, actif: true, joursActif: 0 });
  updateUI();
  showToast('Informateur recruté !', cfg.label + ' est maintenant actif. -' + cfg.cout + ' ' + cur + '/jour via Dormir.', true);
  addJournalEntry('Informateur niveau ' + niveau + ' recruté : ' + cfg.label, 'event-info');
}

function payerInformateurs() {
  if (!state.informateurs?.length) return;
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  let total = 0;
  state.informateurs = state.informateurs.filter(inf => {
    if (state.arg >= inf.cout) {
      state.arg -= inf.cout;
      total += inf.cout;
      inf.joursActif++;
      return true;
    } else {
      addJournalEntry('Votre informateur niveau ' + inf.niveau + ' (' + inf.label + ') a quitté faute de paiement.', 'event-bad');
      showToast('Informateur parti', inf.label + ' est parti — fonds insuffisants.', false);
      return false;
    }
  });
  if (total > 0) addJournalEntry('Salaires informateurs : -' + total + ' ' + cur, 'event-info');
}

async function consulterInformateur(niveau, pa) {
  if (!state.informateurs) state.informateurs = [];

  // Max 2 informateurs simultanés
  if (state.informateurs.length >= 2) {
    showToast('Limite atteinte', 'Vous avez deja 2 informateurs actifs. Licenciez-en un avant d\'en recruter un autre.', false);
    return;
  }

  // Vérifier si niveau déjà actif
  if (state.informateurs.find(i => i.niveau === niveau)) {
    showToast('Déjà actif', `Vous avez déjà un informateur de niveau ${niveau}.`, false);
    return;
  }

  const config = INFORMATEUR_NIVEAUX[niveau];
  if (!config) return;
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  // Vérifier les fonds pour le premier paiement
  if (state.arg < config.cout) {
    showToast('Fonds insuffisants', `${config.cout} ${cur} requis pour recruter cet informateur.`, false);
    return;
  }
  const r = await deduireCoutOrdre({ pa, cost: 0 });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }

  // Premier paiement immédiat
  state.arg -= config.cout;
  state.informateurs.push({ niveau, jourRecrutement: state.day || 1 });

  // Obtenir une info immédiatement
  const info = getInfomateurInfo(niveau);
  state.inf = Math.min(100, (state.inf || 0) + niveau);
  updateUI();

  addJournalEntry(`Informateur niveau ${niveau} recruté. -${config.cout} ${cur}.`, 'event-info');

  document.getElementById('postes-modal-title').textContent = `Informateur Niveau ${niveau} — ${config.label}`;
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1.2rem">' +
    '<div style="font-size:.75rem;color:#6a5a30;font-family:Bebas Neue,sans-serif;letter-spacing:.1em;margin-bottom:.6rem">INFORMATION REÇUE</div>' +
    '<div style="font-size:.88rem;color:#c0b090;font-style:italic;line-height:1.8;font-family:Crimson Pro,serif">"' + info + '"</div>' +
    '<div style="font-size:.68rem;color:#9a8a68;margin-top:.8rem;border-top:1px solid #2a2010;padding-top:.6rem">' +
    'Source : ' + config.label + ' · +' + niveau + ' INF · Coût : ' + config.cout + ' ' + cur + '/jour · Paye lors de l\'ordre Dormir</div>' +
    '<div style="margin-top:.8rem;display:flex;gap:.5rem">' +
    '<button onclick="licencierInformateur(' + niveau + ')" style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.08em;padding:.4rem .8rem;border:1px solid #8a3a2a;background:transparent;color:#8a3a2a;cursor:pointer">Licencier</button>' +
    '<button onclick="document.getElementById(&quot;modal-postes&quot;).classList.remove(&quot;open&quot;)" style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.08em;padding:.4rem .8rem;border:1px solid #4a4030;background:transparent;color:#8a8060;cursor:pointer">Fermer</button>' +
    '</div></div>';
  document.getElementById('modal-postes').classList.add('open');
}

function licencierInformateur(niveau) {
  if (!state.informateurs) return;
  state.informateurs = state.informateurs.filter(i => i.niveau !== niveau);
  document.getElementById('modal-postes').classList.remove('open');
  showToast('Informateur licencié', `Votre informateur niveau ${niveau} est congédié.`, true);
  addJournalEntry(`Informateur niveau ${niveau} licencié.`, 'event-info');
}

function interrogerInformateur(niveau) {
  // Obtenir une nouvelle info d'un informateur déjà recruté
  if (!state.informateurs?.find(i => i.niveau === niveau)) {
    showToast('Pas d\'informateur', `Vous n'vez pas d'nformateur de niveau ${niveau} actif.`, false);
    return;
  }
  const info = getInfomateurInfo(niveau);
  state.inf = Math.min(100, (state.inf || 0) + Math.ceil(niveau / 2));
  updateUI();

  document.getElementById('postes-modal-title').textContent = `Rapport — Informateur Niveau ${niveau}`;
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1.2rem">' +
    '<div style="font-size:.88rem;color:#c0b090;font-style:italic;line-height:1.8;font-family:Crimson Pro,serif">"' + info + '"</div>' +
    '<div style="font-size:.68rem;color:#9a8a68;margin-top:.8rem">+' + Math.ceil(niveau/2) + ' INF · ' + INFORMATEUR_NIVEAUX[niveau]?.label + '</div>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
  addJournalEntry(`Rapport reçu de votre informateur niveau ${niveau}.`, 'event-info');
}
function ouvrirGestionInformateurs() {
  const infos = state.informateurs || [];
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  document.getElementById('postes-modal-title').textContent = 'Mes Informateurs';
  let html = '<div style="padding:1rem">';
  if (infos.length === 0) {
    html += '<div style="font-size:.82rem;color:#6a6040;font-style:italic">Aucun informateur actif. Recrutez-en depuis les bâtiments appropriés.</div>';
  } else {
    infos.forEach((inf, i) => {
      html += '<div style="border:1px solid var(--border);background:var(--bg2);padding:.7rem;margin-bottom:.5rem;display:flex;align-items:center;justify-content:space-between">';
      html += '<div><div style="font-size:.82rem;color:#c0b090">Niveau ' + inf.niveau + ' — ' + inf.label + '</div>';
      html += '<div style="font-size:.68rem;color:#6a6040">-' + inf.cout + ' ' + cur + '/jour · Actif depuis ' + inf.joursActif + ' jour(s)</div></div>';
      html += '<button onclick="congediерInformateur(' + i + ')" style="font-family:Bebas Neue,sans-serif;font-size:.85rem;padding:.25rem .5rem;border:1px solid #8a3a2a;background:transparent;color:#8a3a2a;cursor:pointer">Congédier</button>';
      html += '</div>';
    });
  }
  html += '<div style="font-size:.7rem;color:#9a8a68;margin-top:.8rem">Maximum 2 informateurs simultanés.</div>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function congediерInformateur(idx) {
  if (!state.informateurs) return;
  const inf = state.informateurs[idx];
  if (!inf) return;
  state.informateurs.splice(idx, 1);
  document.getElementById('modal-postes').classList.remove('open');
  showToast('Informateur congédié', inf.label + ' ne travaille plus pour vous.', true);
  addJournalEntry('Informateur niveau ' + inf.niveau + ' congédié.', 'event-info');
}


function doSeCacher() {
  // DIS fantome corrige (bêta) : le premier terme (stats.DIS) n'a jamais existe, state.dis
  // (la vraie ressource) etait deja present en repli -- ne garder que lui.
  const dis = state.dis || 50;
  const taux = Math.max(5, 70 + Math.floor(dis/10) - getMalusISN() + 15); // +15 zone transport
  const roll = Math.floor(Math.random() * 100) + 1;
  if (roll <= taux) {
    state.estCache = true;
    showToast('Vous êtes caché(e)', 'Personne ne vous voit. Vous pouvez maintenant passer l\'ordre Assassiner ou Empoisonner.', true, true);
    addJournalEntry('Ordre Se cacher réussi. Prêt(e) pour action discrète.', 'event-info');
    // Se cache se reinitialise apres changement de piece
  } else {
    state.estCache = false;
    showToast('Échec', 'Vous n\'avez pas réussi à vous dissimuler suffisamment.', false);
  }
}

function getCurrentRoomPersons() {
  const building = BUILDINGS[state.currentBuilding];
  if (!building) return [];
  const room = building.rooms?.[state.currentRoom];
  const pnjStatiques = room?.persons || [];
  // Inclure les vrais joueurs presents (mis en cache par chargerVraisJoueursPresents)
  const vraisJoueurs = window._vraisJoueursPresents || [];
  return [...pnjStatiques, ...vraisJoueurs];
}

// Verifier effacement automatique des crimes
function checkEffacementCrimes() {
  if (!state.historiqueCrimes) return;
  const avant = state.historiqueCrimes.length;
  state.historiqueCrimes = state.historiqueCrimes.filter(c => c.expireJour > state.day);
  const apres = state.historiqueCrimes.length;
  if (avant > apres) {
    addJournalEntry('Les preuves matérielles de votre crime ont disparu. Vous ne pouvez plus être inquiété(e) pour ceci.', 'event-good');
  }
}

function ouvrirCalendrierElections() {
  const elections = state.electionsEnCours || [];
  document.getElementById('postes-modal-title').textContent = 'Calendrier électoral';
  let html = '<div style="padding:1rem;min-width:520px;max-width:640px">';

  // Cycle electoral
  html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.8rem;margin-bottom:.8rem">';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.5rem">CYCLE ÉLECTORAL (5-6 semaines)</div>';
  const phases = [
    { label: 'Semaines 1-3', desc: 'Mandat en cours', col: '#4a8a4a' },
    { label: 'Semaine 3', desc: 'Ouverture des candidatures', col: '#C9A84C' },
    { label: 'Semaines 4-5', desc: 'Campagne électorale — vote PJ + tracts', col: '#aa6a4a' },
    { label: 'Dimanche soir', desc: 'Résultats à minuit', col: '#6a8aaa' }
  ];
  phases.forEach(p => {
    html += '<div style="display:flex;gap:.6rem;align-items:center;margin-bottom:.3rem">';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.68rem;color:' + p.col + ';width:90px">' + p.label + '</div>';
    html += '<div style="font-size:.75rem;color:#8a8060">' + p.desc + '</div>';
    html += '</div>';
  });
  html += '</div>';

  // Elections en cours
  if (elections.length === 0) {
    html += '<div style="font-size:.85rem;color:#a89878;font-style:italic">Aucune élection en cours ou programmée.</div>';
  } else {
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.5rem">ÉLECTIONS EN COURS / À VENIR</div>';
    elections.forEach(e => {
      const phaseCol = { candidatures:'#4a8a4a', campagne:'#C9A84C', depouillement:'#aa6a4a', termine:'#4a4030' }[e.phase] || '#8a8060';
      const phaseLabel = { candidatures:'Candidatures ouvertes', campagne:'Campagne en cours', depouillement:'Dépouillement', termine:'Terminée' }[e.phase] || e.phase;
      html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.7rem;margin-bottom:.5rem">';
      html += '<div style="display:flex;justify-content:space-between;align-items:center">';
      html += '<div style="font-family:Playfair Display,serif;font-size:.85rem;color:#E8C97A">' + e.nom + '</div>';
      html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.85rem;color:' + phaseCol + ';border:1px solid;padding:.1rem .3rem">' + phaseLabel + '</div>';
      html += '</div>';
      html += '<div style="font-size:.7rem;color:#5a4030;margin-top:.2rem">Tour ' + (e.tour||1) + ' · Résultats à venir</div>';
      if (e.phase === 'candidatures') {
        html += '<div style="font-size:.7rem;color:#4a8a4a;margin-top:.2rem">✓ Candidatures encore acceptées</div>';
      } else if (e.phase === 'campagne') {
        html += '<div style="font-size:.7rem;color:#cc4444;margin-top:.2rem">✗ Candidatures fermées — campagne en cours</div>';
      }
      html += '</div>';
    });
  }

  // Prochaines elections prevues
  html += '<div style="font-size:.72rem;color:#a89060;font-style:italic;margin-top:.6rem">Les candidatures ferment au début de la semaine 4. Après cette date, il n\'est plus possible de se présenter.</div>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function ouvrirGestionBudget() {
  if (state.poste?.id !== 'min_fin') { showToast('Réservé au Ministre des Finances', '', false); return; }
  document.getElementById('postes-modal-title').textContent = 'Répartition budgétaire';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const pays = state.country || 'republic';
  const budgetNat = await chargerBudgetNational(pays);
  const rep = budgetNat.repartition || { ...REPARTITION_DEFAULT };
  const noms = {
    presidence:'Presidence', min_int:'Min. Interieur', min_fin:'Min. Finances',
    min_just:'Min. Justice', min_def:'Min. Defense', min_info:'Min. Information',
    min_ae:'Min. AE', assemblee:'Assemblee', tribunal:'Tribunal',
    commissariat:'Commissariat', mairie:'Mairie', reserve:'Reserve'
  };

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Fixez le pourcentage des recettes fiscales attribué à chaque institution. Total doit être 100%. Partagé entre tous les joueurs, appliqué chaque nuit.</div>';

  let total = Object.values(rep).reduce((s, v) => s + v, 0);
  html += '<div id="budget-total-label" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;color:' + (total === 100 ? '#6ab858' : '#cc6a44') + ';margin-bottom:.6rem">TOTAL : ' + total + '% (doit être 100%)</div>';

  Object.keys(rep).forEach(inst => {
    html += '<div style="display:flex;align-items:center;gap:.5rem;margin-bottom:.4rem">';
    html += '<div style="font-size:.8rem;color:#c0b090;width:120px">' + (noms[inst]||inst) + '</div>';
    html += '<input type="number" min="0" max="50" value="' + rep[inst] + '" id="budget-' + inst + '" onchange="majTotalBudget()" style="width:60px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.35rem;font-size:.85rem;outline:none">';
    html += '<span style="font-size:.75rem;color:#8a8060">%</span>';
    html += '</div>';
  });

  html += '<button onclick="validerRepartitionBudget(\'' + pays + '\')" style="margin-top:.8rem;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.55rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Valider la répartition</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

function majTotalBudget() {
  const rep = REPARTITION_DEFAULT;
  let total = 0;
  Object.keys(rep).forEach(inst => {
    const val = parseInt(document.getElementById('budget-' + inst)?.value || '0');
    total += val;
  });
  const label = document.getElementById('budget-total-label');
  if (label) {
    label.textContent = 'TOTAL : ' + total + '% (doit être 100%)';
    label.style.color = total === 100 ? '#6ab858' : '#cc6a44';
  }
}

async function validerRepartitionBudget(pays) {
  const rep = REPARTITION_DEFAULT;
  let total = 0;
  const newRep = {};
  Object.keys(rep).forEach(inst => {
    const val = parseInt(document.getElementById('budget-' + inst)?.value || '0');
    newRep[inst] = val;
    total += val;
  });
  if (total !== 100) {
    showToast('Total incorrect', 'Le total doit etre exactement 100%. Actuel : ' + total + '%.', false);
    return;
  }
  const budgetNat = await chargerBudgetNational(pays);
  budgetNat.repartition = newRep;
  await sbSaveBudgetNational(pays, budgetNat);
  document.getElementById('modal-postes').classList.remove('open');
  showToast('Répartition validée !', 'Les nouveaux taux s\'appliqueront à partir de minuit, pour tous les joueurs.', true, true);
  addJournalEntry('Repartition budgetaire modifiee par le Ministre des Finances.', 'event-info');
  addExternalEvent('FINANCES : Nouvelle repartition budgetaire fixee par le Ministre des Finances.');
}

// =====================

// SCANDALES ALEATOIRES
// =====================
function declencherScandale() {
  if (typeof SCANDALES_PREDEFINIS === 'undefined' || SCANDALES_PREDEFINIS.length === 0) return;
  const scandale = SCANDALES_PREDEFINIS[Math.floor(Math.random() * SCANDALES_PREDEFINIS.length)];
  addExternalEvent('🔴 SCANDALE : ' + scandale);
  showToast('Scandale !', scandale.substring(0, 80) + '...', false);
}

// Declencher un scandale aleatoire de temps en temps (a minuit, 15% de chance)
function checkScandale() {
  if (Math.random() < 0.15) {
    declencherScandale();
  }
}
// =====================
// CONSTANTE BONUS CARRIERE VOL (complement)
// =====================

// Remappee vers les 10 id de carriere actuels (bêta, consolidation 18->10 -- voir
// MIGRATION_CAREER_IDS, data.js). unemployed/lawyer/civil retires : ids disparus, plus jamais
// portes par un personnage charge (migres a la volee par migrerCareerId avant toute lecture de
// char.career) -- business/press/worker (Affaires/Medias/Monde ouvrier, les 3 nouvelles
// carrieres fusionnees sans equivalent direct dans cette table) restent neutres, aucun de
// leurs composants d'origine n'y figurait.
const BONUS_CARRIERE_VOL = {
  criminal_c: 15, intel: 15, escort: 15,
  magistrat: -10, officer: -10, clergy: -10, doctor: -10
  // toutes les autres carrieres : 0 (neutre)
};


function checkDetection(fn, resultType) {
  const acte = ACTES_ILLEGAUX[fn];
  if (!acte) return;
  if (resultType === 'fail' || resultType === 'crit-fail') return; // Pas d'acte = pas de detection

  // Immunite selon poste
  const posteId = state.poste?.id;
  if (posteId === 'president') return; // Immunite totale
  if (['pm','min_int','min_fin','min_just','min_def','min_info','min_ae'].includes(posteId)) {
    if (acte.type === 'delit_mineur') return; // Immunite partielle ministres
  }

  const roll = Math.floor(Math.random() * 100) + 1;
  const tauxDetect = Math.max(5, acte.detectRate - Math.floor(state.dis / 10));

  if (roll <= tauxDetect) {
    if (!state.recherche) state.recherche = [];
    state.recherche.push({ acte: fn, type: acte.type, jour: state.day });
    addExternalEvent('ALERTE : Votre activite illegale (' + fn.replace(/_/g,' ') + ') a ete detectee. Vous etes recherche(e).');
    state.dis = Math.max(0, state.dis - 10);
    updateUI();
  }
}

function checkArrestationAuDeplacement() {
  if (!state.recherche || state.recherche.length === 0) return;
  const alerteMax = state.recherche.reduce((max, r) => {
    const peine = PEINES[r.type];
    return peine && peine.jours > (PEINES[max]?.jours||0) ? r.type : max;
  }, 'delit_mineur');

  const roll = Math.floor(Math.random() * 100) + 1;
  const tauxInter = Math.max(5, 30 - Math.floor(state.dis / 5));

  if (roll <= tauxInter) {
    ouvrirModalArrestation(alerteMax);
  }
}

function doSesoigner() {
  const medocs = (state.inventory || []).filter(i => i.type === 'medicament');
  if (medocs.length === 0) { showToast('Aucun medicament', '', false); return; }
  const idx = state.inventory.indexOf(medocs[0]);
  state.inventory.splice(idx, 1);
  state.hp = Math.min(100, state.hp + 20);
  updateUI();
  showToast('Soins', '+20 Sante. ' + (state.inventory.filter(i=>i.type==='medicament').length) + ' medicament(s) restant(s).', true);
  switchSelfTab('inventaire', null);
}

// =====================
// MOTEUR D'ENTREPRISE PRIVEE (fondations)
// L'armurerie de Republia en est la premiere application concrete.
// Note pour Fred : ce systeme couvre pour l'instant l'armurerie de Republia uniquement.
// Les autres empires (narco/soviet/khalija) auront besoin des memes recettes/instances
// une fois ce premier exemple valide en jeu.
// =====================

const PA_PAR_UT = 4; // 1 Unite de Temps = 4 PA

const RECETTES_PRODUCTION = {
  // Republic
  couteau:            { ut: 1, materiaux: { metal: 1 },          label: 'Couteau de poche',         pays: 'republic' },
  revolver:           { ut: 2, materiaux: { metal: 2, bois: 1 }, label: 'Revolver',                  pays: 'republic' },
  carabine_chasse:    { ut: 3, materiaux: { metal: 2, bois: 2 }, label: 'Carabine de chasse',        pays: 'republic' },
  // Narco
  machette:           { ut: 1, materiaux: { metal: 1 },          label: 'Machette',                  pays: 'narco' },
  desert_eagle:       { ut: 2, materiaux: { metal: 2 },          label: 'Desert Eagle',               pays: 'narco' },
  ak47:               { ut: 3, materiaux: { metal: 3, bois: 1 }, label: 'AK-47',                      pays: 'narco' },
  // Soviet
  baionnette:         { ut: 1, materiaux: { metal: 1 },          label: 'Baïonnette',                pays: 'soviet' },
  makarov:            { ut: 2, materiaux: { metal: 2 },          label: 'Makarov',                    pays: 'soviet' },
  kalachnikov:        { ut: 3, materiaux: { metal: 3, bois: 1 }, label: 'Kalachnikov',                pays: 'soviet' },
  // Khalija
  jambiya:            { ut: 1, materiaux: { metal: 1 },          label: 'Jambiya',                   pays: 'khalija' },
  pistolet_dore:      { ut: 2, materiaux: { metal: 2 },          label: 'Pistolet doré',              pays: 'khalija' },
  carabine_precision: { ut: 3, materiaux: { metal: 2, bois: 2 }, label: 'Carabine de précision',      pays: 'khalija' }
};

function getRecettesPays(pays) {
  return Object.fromEntries(Object.entries(RECETTES_PRODUCTION).filter(([, r]) => r.pays === pays));
}

const PRIX_RACHAT_ARMURERIE = 130000;

// A2 (16 aout 2026) : id local par ville -- une armurerie de Republia n'est plus une entreprise
// unique par pays mais une entreprise par ville (Luthecia/Montrouge/PSM partageaient jusqu'ici
// la meme caisse/stock via 'armurerie-'+country). Generique pour tous les empires : narco/
// soviet/khalija n'ont qu'une seule armurerie (capitale) mais recoivent le meme format d'id des
// leur premiere instanciation, sans migration necessaire (aucune ligne 'armurerie-narco' etc.
// n'existait avant ce changement).
function getEntrepriseIdArmurerie(country, city) {
  return 'armurerie-' + country + '-' + city;
}

async function chargerEntreprise(id, defautFabrique) {
  if (typeof sbGetEntreprise !== 'function') return null;
  let data = await sbGetEntreprise(id).catch(() => null);
  if (!data) {
    data = defautFabrique();
    if (typeof sbSaveEntreprise === 'function') await sbSaveEntreprise(id, data).catch(() => {});
  }
  return data;
}

function defautArmurerie(pays, ville) {
  const recettes = getRecettesPays(pays || 'republic');
  const prixVenteDefaut = { 1: 300, 2: 800, 3: 1200 }; // par palier d'UT (simple/moyen/complexe)
  const prixVente = {}, stockMax = {};
  Object.entries(recettes).forEach(([id, r]) => {
    prixVente[id] = prixVenteDefaut[r.ut] || 500;
    stockMax[id] = r.ut === 1 ? 10 : (r.ut === 2 ? 5 : 5);
  });

  return {
    id: null,
    type: 'armurerie',
    // A2 (16 aout 2026) : country/city stockes explicitement dans les donnees (pas seulement
    // encodes dans l'id) -- evite tout parsing fragile de l'id cote cron (resoudreCompromis-
    // EntreprisesExpires en avait un, casse par l'ajout de la ville dans l'id).
    country: pays || 'republic',
    city: ville || 'capitale',
    // buildingId/roomId (17 aout 2026, generalisation commerces) : ajoutes pour aligner le
    // schema de l'armurerie sur celui des nouveaux commerces (getCommerceId ci-dessous) --
    // l'id Supabase de l'armurerie ('armurerie-<country>-<city>') reste lui inchange, aucune
    // migration necessaire, ces champs ne sont lus par aucun code existant.
    buildingId: 'armurerie',
    roomId: null,
    proprietaire: 'PNJ',
    caisse: 20000,
    stockMatieres: { metal: 20, bois: 10 },
    // coutMoyenMatieres (17 aout 2026) : cout moyen pondere du stock, alimente par
    // crediterStockMatiereCommerce a chaque achat de matiere premiere (confirmerVenteMatiere
    // ci-dessous). L'armurerie ne s'en sert pas pour son propre pricing (prixVente reste fixe,
    // choisi par le proprietaire) -- champ present pour un schema commun a tous les commerces,
    // sans effet sur le fonctionnement actuel de l'armurerie.
    coutMoyenMatieres: {},
    stockProduits: {},
    carte: [],
    parametres: {
      prixAchatMatiere: { metal: 20, bois: 10 }, // FR verses au vendeur de matiere premiere
      prixVente,
      stockMax
    },
    historique: []
  };
}

async function chargerEntrepriseParId(id, pays, ville) {
  const data = await chargerEntreprise(id, () => defautArmurerie(pays, ville));
  if (data) data.id = id;
  return data;
}

// =====================
// COMMERCES PRODUCTIFS GENERIQUES (17 aout 2026) -- generalisation du moteur d'entreprise
// pionnier par l'armurerie (ci-dessus), sans dupliquer son architecture. Un commerce
// alimentaire (restaurant/brasserie/cafe/bar/stand_marche/buvette) utilise la MEME table
// 'entreprises' et le MEME chargement (chargerEntreprise), avec un schema par defaut generique
// plutot qu'une deuxieme architecture parallele.
// =====================

// Convention d'id generique : <type>-<country>-<city>-<buildingId>[-<roomId>]. Localisation
// TOUJOURS stockee explicitement dans les donnees (country/city/buildingId/roomId, jamais
// deduite en parsant l'id -- meme lecon que le commentaire ci-dessus sur l'armurerie). Le
// roomId n'est ajoute que lorsqu'un meme buildingId heberge plusieurs commerces distincts
// (ex. hotel-republica : room 'restaurant' et room 'bar', deux entreprises differentes).
function getCommerceId(type, country, city, buildingId, roomId) {
  return type + '-' + country + '-' + city + '-' + buildingId + (roomId ? '-' + roomId : '');
}

function defautCommerce(type, pays, ville, buildingId, roomId) {
  return {
    id: null,
    type,
    country: pays || 'republic',
    city: ville || 'capitale',
    buildingId: buildingId || null,
    roomId: roomId || null,
    proprietaire: 'PNJ',
    caisse: 0,
    stockMatieres: {},
    coutMoyenMatieres: {},
    stockProduits: {},
    carte: [],       // sous-ensemble des recettes autorisees (RECETTES_ALIMENTAIRES) propose par ce commerce
    parametres: { prixVente: {}, stockMax: {} },
    historique: []
  };
}

// Rattrapage generique de dotation (correctif, 20 aout 2026) -- cause reelle de l'absence des 4
// boissons au Cafe de la Gare en production : DOTATIONS_COMMERCE_PILOTE n'est rejouee QUE lors de
// la toute premiere creation d'un commerce (chargerEntreprise, ci-dessous, n'appelle
// defautFabrique -- et donc la dotation -- que si sbGetEntreprise ne renvoie encore rien). Le
// commerce du Cafe de la Gare existait deja en base (premiere production de Boeuf bourguignon
// bien avant l'ajout des boissons a sa dotation), donc l'ajout des 4 recettes/2 matieres/prix a
// DOTATIONS_COMMERCE_PILOTE ne lui a jamais ete applique -- confirme en lisant sa ligne reelle en
// base (entreprises.data.carte = ["boeuf_bourguignon"] seul, stockMatieres sans
// fruits_legumes/produits_exotiques). Generique par construction (tous les commerces a dotation
// pilote, pas seulement celui-ci) : rejoue la dotation sur un commerce vierge de reference
// (defautCommerce, jamais lu ni ecrit) puis fusionne UNIQUEMENT les cles absentes du commerce
// reellement persiste dans carte/stockMatieres/coutMoyenMatieres/parametres.stockMax/prixVente --
// ne touche jamais une valeur deja existante (stock reellement consomme, prix ajuste par un
// proprietaire PJ, caisse accumulee), donc aucune perte de progression reelle.
function rattraperDotationCommerce(data, dotation, type, pays, ville, buildingId, roomId) {
  const reference = defautCommerce(type, pays, ville, buildingId, roomId);
  dotation(reference);
  let modifie = false;
  (reference.carte || []).forEach(recId => {
    if (!data.carte.includes(recId)) { data.carte.push(recId); modifie = true; }
  });
  ['stockMatieres', 'coutMoyenMatieres'].forEach(champ => {
    Object.entries(reference[champ] || {}).forEach(([cle, val]) => {
      if (!(cle in data[champ])) { data[champ][cle] = val; modifie = true; }
    });
  });
  ['prixVente', 'stockMax'].forEach(champ => {
    Object.entries((reference.parametres || {})[champ] || {}).forEach(([cle, val]) => {
      if (!(cle in data.parametres[champ])) { data.parametres[champ][cle] = val; modifie = true; }
    });
  });
  return modifie;
}

// Dotation de depart eventuelle par buildingId (meme principe que defautArmurerie : un commerce
// pilote ne demarre pas a zero) -- typeof DOTATIONS_COMMERCE_PILOTE en garde car cette const est
// declaree plus loin dans ce fichier (catalogue des commerces, rempli lot par lot) ; l'ordre de
// declaration n'a aucune importance ici, chargerCommerce n'est jamais appelee avant la fin du
// chargement du script.
async function chargerCommerce(type, pays, ville, buildingId, roomId) {
  const id = getCommerceId(type, pays, ville, buildingId, roomId);
  // Cle 'buildingId|roomId' prioritaire (batiment a plusieurs commerces distincts, ex. le stade
  // n'a qu'un commerce -- sa buvette -- pas tout le batiment), repli sur 'buildingId' seul pour
  // les commerces mono-piece (lots 3-4).
  const cleDotation = roomId ? buildingId + '|' + roomId : buildingId;
  const dotation = typeof DOTATIONS_COMMERCE_PILOTE !== 'undefined' ? (DOTATIONS_COMMERCE_PILOTE[cleDotation] || DOTATIONS_COMMERCE_PILOTE[buildingId]) : null;
  const data = await chargerEntreprise(id, () => {
    const d = defautCommerce(type, pays, ville, buildingId, roomId);
    if (dotation) dotation(d);
    return d;
  });
  if (data) {
    data.id = id;
    if (dotation && rattraperDotationCommerce(data, dotation, type, pays, ville, buildingId, roomId)) {
      if (typeof sbSaveEntreprise === 'function') await sbSaveEntreprise(id, data).catch(() => {});
    }
  }
  return data;
}

// Cout moyen pondere du stock d'une matiere premiere, mis a jour a chaque achat REEL (decision
// de Fred, releve economique du 17 aout 2026 : le cout de revient utilise le prix reellement
// paye par le commerce, pas un cours theorique). Generique -- utilise aussi bien par l'armurerie
// (confirmerVenteMatiere) que par les futurs commerces alimentaires, un seul mecanisme au lieu
// d'une logique dupliquee par type de commerce.
function crediterStockMatiereCommerce(data, matiere, qte, prixUnitairePaye) {
  if (!data.coutMoyenMatieres) data.coutMoyenMatieres = {};
  const stockAvant = data.stockMatieres[matiere] || 0;
  const coutMoyenAvant = data.coutMoyenMatieres[matiere] || 0;
  const nouveauStock = stockAvant + qte;
  data.coutMoyenMatieres[matiere] = nouveauStock > 0
    ? (stockAvant * coutMoyenAvant + qte * prixUnitairePaye) / nouveauStock
    : 0;
  data.stockMatieres[matiere] = nouveauStock;
}

// =====================
// COMMERCES ALIMENTAIRES -- moteur recettes/production/prix/taxe/carte (17 aout 2026, lot 2/6).
// Generique par construction : ne connait ni Montrouge ni un plat particulier, seulement le
// registre RECETTES_ALIMENTAIRES (rempli lot par lot avec les catalogues reels) et le schema
// de commerce genere par defautCommerce/chargerCommerce (lot 1).
// =====================

// Registre central des recettes -- rempli progressivement (lots 3-5). Chaque entree :
// { id, label, categorie, image, materiaux:{cle:qte}, pa, portions, effets:{hp,moral,paDiffere},
//   typesAutorises:[...], villesAutorisees:[...]|null, buildingsAutorises:[...]|null }
// villesAutorisees/buildingsAutorises null = recette commune, pas de verrou geographique.
const RECETTES_ALIMENTAIRES = {
  // Cafe de la Gare (Montrouge, lot 3/6) : restauration legere, un seul plat du jour pour
  // l'instant -- catalogue volontairement reduit (cf. consigne "ne donner au cafe qu'une
  // petite carte"). Image absente (aucun asset livre a ce jour) -- propriete deja lue par
  // doConsulterCarteCommerce (affichee des qu'un chemin est fourni), a completer par Fred.
  boeuf_bourguignon: {
    id: 'boeuf_bourguignon', label: 'Bœuf bourguignon — plat du jour', categorie: 'plat', image: null,
    materiaux: { cereales: 1, viande: 1 }, pa: 1, portions: 5,
    effets: { hp: 8, moral: 2 },
    typesAutorises: ['cafe', 'brasserie'], villesAutorisees: null, buildingsAutorises: null
  },

  // Brasserie des Voyageurs (Montrouge, lot 4/6) : vraie restauration, 3 plats. Carbonade-frites
  // est une specialite reellement verrouillee a Montrouge (decision ferme de Fred, tourisme
  // gastronomique) -- les deux autres restent communes, comme demande ("les effets exacts
  // peuvent rester modestes... et doivent etre configurables").
  carbonade_frites: {
    id: 'carbonade_frites', label: 'Carbonade-frites', categorie: 'plat',
    // Asset reel confirme present dans le depot (mini-lot de finition, 17 aout 2026).
    image: 'images/montrouge/montrouge-plat-carbonade.jpg',
    materiaux: { cereales: 1, viande: 1 }, pa: 1, portions: 5,
    effets: { hp: 8, moral: 3 },
    typesAutorises: ['brasserie'], villesAutorisees: ['ville_b'], buildingsAutorises: null
  },
  plat_de_poisson: {
    id: 'plat_de_poisson', label: 'Plat de poisson', categorie: 'plat', image: null,
    materiaux: { cereales: 1, poisson: 1 }, pa: 1, portions: 5,
    effets: { hp: 8, moral: 2 },
    typesAutorises: ['brasserie'], villesAutorisees: null, buildingsAutorises: null
  },
  saucisse_puree: {
    id: 'saucisse_puree', label: 'Saucisse-purée', categorie: 'plat', image: null,
    materiaux: { cereales: 1, viande: 1 }, pa: 1, portions: 5,
    effets: { hp: 8, moral: 2 },
    typesAutorises: ['brasserie'], villesAutorisees: null, buildingsAutorises: null
  },

  // Hotel Mineur (Montrouge, lot 4/6) : pas de restaurant, une petite offre de petit-dejeuner
  // uniquement, remplace l'ancien se_nourrir casse (10 FR/+3 Moral quel que soit le lieu, cf.
  // releve economique). Rendement "produit simple" (1 PA -> 10 portions, section 6).
  petit_dejeuner: {
    id: 'petit_dejeuner', label: 'Petit-déjeuner', categorie: 'petit_dej', image: null,
    materiaux: { cereales: 1 }, pa: 1, portions: 10,
    effets: { hp: 3, moral: 1 },
    typesAutorises: ['cafe'], villesAutorisees: null, buildingsAutorises: null
  },

  // Buvette de stade (lot 5/6) : alcool comme vraie matiere stockee, consommee a la commande
  // (section 15). typesAutorises inclut deja 'bar' par anticipation (aucun cout supplementaire,
  // simple entree de tableau) si le Bar des Pecheurs/Hotel Republica sont migres plus tard --
  // sans que cela ne les active prematurement (aucun commerce 'bar' n'existe encore).
  // Adaptee le 20 aout 2026 (lot boissons Cafe de la Gare) pour rejoindre le catalogue
  // Cafe/Jus de fruits/Biere/Vin : materiaux passe de alcool a cereales, portions 10->15,
  // effets uniformises a +2 moral seul (aucun avantage mecanique superieur alcoolise/non
  // alcoolise, decision explicite de Fred), 'cafe' ajoute a typesAutorises. La cle 'biere_pression'
  // n'est PAS renommee (seul son contenu change) pour ne rien casser des donnees deja persistees
  // (stockProduits/carte de la buvette du stade, qui reference deja ce meme id) -- son prix de
  // vente PNJ est recalcule automatiquement (prixVenteAutoPNJ), pas fige ici.
  biere_pression: {
    id: 'biere_pression', label: 'Bière', categorie: 'boisson', image: null,
    materiaux: { cereales: 1 }, pa: 1, portions: 15,
    effets: { moral: 2 },
    typesAutorises: ['buvette', 'bar', 'cafe'], villesAutorisees: null, buildingsAutorises: null
  },
  boisson_sans_alcool: {
    id: 'boisson_sans_alcool', label: 'Boisson sans alcool', categorie: 'boisson', image: null,
    // Pas de chaine industrielle complexe pour l'instant (section 17, cahier des charges) --
    // produit simple, aucune matiere premiere dediee inventee. Conservee telle quelle (lot
    // boissons du 20 aout 2026) : deja presente sur la carte de la buvette du stade, la retirer
    // ou la renommer casserait cette carte existante -- non redondante en pratique avec "Jus de
    // fruits" (celle-ci n'a aucune matiere premiere, contrairement a Jus de fruits qui en
    // consomme une reelle).
    materiaux: {}, pa: 1, portions: 10,
    effets: { moral: 1 },
    typesAutorises: ['buvette', 'bar', 'cafe'], villesAutorisees: null, buildingsAutorises: null
  },
  snack_buvette: {
    id: 'snack_buvette', label: 'Cacahuètes salées', categorie: 'snack', image: null,
    materiaux: { cereales: 1 }, pa: 1, portions: 15,
    effets: { hp: 2, moral: 1 },
    typesAutorises: ['buvette', 'bar'], villesAutorisees: null, buildingsAutorises: null
  },

  // Lot boissons - Cafe de la Gare (20 aout 2026) : 3 nouvelles recettes, memes regles pour les
  // 4 boissons du catalogue (1 matiere + 1 PA -> 15 consommations, +2 moral uniquement, aucun
  // hp/inf/ent/pa -- aucun avantage mecanique superieur pour l'alcoolise, decision explicite de
  // Fred). typesAutorises limite a 'cafe' pour ce lot (perimetre = Cafe de la Gare uniquement,
  // extension a d'autres types laissee pour plus tard, aucune donnee inventee au-dela du demande).
  cafe_boisson: {
    id: 'cafe_boisson', label: 'Café', categorie: 'boisson', image: null,
    materiaux: { produits_exotiques: 1 }, pa: 1, portions: 15,
    effets: { moral: 2 },
    typesAutorises: ['cafe'], villesAutorisees: null, buildingsAutorises: null
  },
  jus_de_fruits: {
    id: 'jus_de_fruits', label: 'Jus de fruits', categorie: 'boisson', image: null,
    materiaux: { fruits_legumes: 1 }, pa: 1, portions: 15,
    effets: { moral: 2 },
    typesAutorises: ['cafe'], villesAutorisees: null, buildingsAutorises: null
  },
  vin: {
    id: 'vin', label: 'Vin', categorie: 'boisson', image: null,
    materiaux: { fruits_legumes: 1 }, pa: 1, portions: 15,
    effets: { moral: 2 },
    // 'brasserie' ajoute (lot carte gastronomique Le Republica, 21 aout 2026) : le restaurant du
    // Republica (type 'brasserie', voir BUILDING_COMMERCE_TYPE) doit pouvoir produire du vin avec
    // cette meme recette (necessaire au diner d'affaires). N'ajoute PAS 'vin' a la carte de la
    // Brasserie des Voyageurs (Montrouge, egalement type 'brasserie') : elargir typesAutorises ne
    // rend une recette disponible que si elle figure aussi dans data.carte du commerce concerne
    // (DOTATIONS_COMMERCE_PILOTE) -- celle de Montrouge ne liste toujours que ses 3 plats.
    typesAutorises: ['cafe', 'brasserie'], villesAutorisees: null, buildingsAutorises: null
  },

  // Carte gastronomique Le Republica (21 aout 2026) -- remplace l'ancienne carte provisoire
  // (boeuf_bourguignon/plat_de_poisson/saucisse_puree). Aucune matiere nouvelle : chaque plat
  // nomme des 3 menus fournis par Fred est mappe sur son abstraction existante la plus proche
  // (cerf/chapon/foie gras -> viande ; Saint-Jacques/huitres/turbot -> poisson ; garnitures/
  // fruits/morilles -> fruits_legumes ; dessert sans correspondance directe -> cereales, meme
  // convention que petit_dejeuner), un plat = une unite de sa matiere, sommee par menu -- d'ou
  // des compositions volontairement differentes (Menu 2 tout poisson, Menu 3 tout viande) : cree
  // une vraie difference de consommation de stock entre menus, sans rendre aucun des 3
  // statistiquement superieur (memes portions/effets/prix). categorie:'menu' (nouvelle valeur,
  // aucun filtre existant n'y est sensible -- seul 'boisson' est teste ailleurs dans le moteur).
  // buildingsAutorises verrouille ces 3 menus a Le Republica (specialite maison nommee, meme
  // doctrine que carbonade_frites verrouillee a Montrouge), pas une carte generaliste
  // reutilisable par un futur commerce 'brasserie'. Images deja presentes dans le depot
  // (images/luthecia-restaurant-menu-1/2/3.jpg, fournies par Fred), jamais generees ici.
  menu_gastronomique_1: {
    id: 'menu_gastronomique_1',
    label: 'Menu 1 — Carpaccio de Saint-Jacques aux agrumes, Pavé de cerf sauce aux airelles, Omelette norvégienne',
    categorie: 'menu', image: 'images/luthecia-restaurant-menu-1.jpg',
    materiaux: { poisson: 1, viande: 1, cereales: 1 }, pa: 1, portions: 5,
    // +3 PA demande = paDiffere (champ deja existant du moteur, jamais utilise jusqu'ici par
    // aucune recette mais deja gere par commanderProduitCommerce() -> state.bonusPaProchainDormir).
    // Aucun mecanisme de PA immediat n'existe dans ce moteur de vente -- meme convention que
    // l'ancien repas_gastronomique ("+1 PA au prochain Dormir"), simplement portee a 3.
    effets: { hp: 10, moral: 1, paDiffere: 3 },
    // villesAutorisees ajoute (lot isolation des villes, 22 aout 2026) : buildingsAutorises seul
    // ne verrouille QUE le buildingId, jamais la ville -- 'hotel-republica' est partage par les 4
    // capitales (Luthecia/narco/soviet/khalija) ET par les Hotels de PSM/Montrouge (meme
    // buildingId, noms differents). Sans ce champ, ces 3 menus etaient donc techniquement
    // disponibles a Port-Sainte-Marie et Montrouge (bug de portee confirme par audit). 'capitale'
    // exclut bien PSM (ville_a) et Montrouge (ville_b) au sein de Republic -- residu non couvert :
    // aucun champ "pays autorise" n'existe dans ce moteur, donc les capitales des 3 AUTRES empires
    // (qui partagent aussi la cle de ville 'capitale') restent techniquement non exclues ; corriger
    // cela exigerait un nouveau champ de portee par pays, hors perimetre de ce lot (aucune nouvelle
    // architecture de scope creee ici, uniquement villesAutorisees deja existant et deja eprouve
    // par carbonade_frites).
    // paysAutorises ajoute (lot scope pays, 22 aout 2026) : ferme le residu signale au lot
    // precedent (les 4 capitales partagent la meme cle de ville 'capitale').
    typesAutorises: ['brasserie'], paysAutorises: ['republic'], villesAutorisees: ['capitale'], buildingsAutorises: ['hotel-republica'],
    // Prix strictement fixe (lot plafonds, 21 aout 2026) : jamais recalcule par
    // produireRecetteCommerce() malgre un proprietaire PNJ par defaut -- voir le nouveau
    // controle "!recette.prixFixe" ajoute a ce recalcul, plus bas dans ce fichier.
    prixFixe: true
  },
  menu_gastronomique_2: {
    id: 'menu_gastronomique_2',
    label: 'Menu 2 — Huîtres gratinées au four (origine Port-Sainte-Marie), Turbot sauce hollandaise, Soufflé au Grand Marnier',
    categorie: 'menu', image: 'images/luthecia-restaurant-menu-2.jpg',
    materiaux: { poisson: 2, cereales: 1 }, pa: 1, portions: 5,
    effets: { hp: 10, moral: 1, paDiffere: 3 },
    // villesAutorisees ajoute (lot isolation des villes, 22 aout 2026) : buildingsAutorises seul
    // ne verrouille QUE le buildingId, jamais la ville -- 'hotel-republica' est partage par les 4
    // capitales (Luthecia/narco/soviet/khalija) ET par les Hotels de PSM/Montrouge (meme
    // buildingId, noms differents). Sans ce champ, ces 3 menus etaient donc techniquement
    // disponibles a Port-Sainte-Marie et Montrouge (bug de portee confirme par audit). 'capitale'
    // exclut bien PSM (ville_a) et Montrouge (ville_b) au sein de Republic -- residu non couvert :
    // aucun champ "pays autorise" n'existe dans ce moteur, donc les capitales des 3 AUTRES empires
    // (qui partagent aussi la cle de ville 'capitale') restent techniquement non exclues ; corriger
    // cela exigerait un nouveau champ de portee par pays, hors perimetre de ce lot (aucune nouvelle
    // architecture de scope creee ici, uniquement villesAutorisees deja existant et deja eprouve
    // par carbonade_frites).
    // paysAutorises ajoute (lot scope pays, 22 aout 2026) : ferme le residu signale au lot
    // precedent (les 4 capitales partagent la meme cle de ville 'capitale').
    typesAutorises: ['brasserie'], paysAutorises: ['republic'], villesAutorisees: ['capitale'], buildingsAutorises: ['hotel-republica'],
    // Prix strictement fixe (lot plafonds, 21 aout 2026) : jamais recalcule par
    // produireRecetteCommerce() malgre un proprietaire PNJ par defaut -- voir le nouveau
    // controle "!recette.prixFixe" ajoute a ce recalcul, plus bas dans ce fichier.
    prixFixe: true
  },
  menu_gastronomique_3: {
    id: 'menu_gastronomique_3',
    label: 'Menu 3 — Foie gras et sa gelée de gewurztraminer, Chapon sauce aux morilles, Pavlova aux fruits rouges',
    categorie: 'menu', image: 'images/luthecia-restaurant-menu-3.jpg',
    materiaux: { viande: 2, fruits_legumes: 1 }, pa: 1, portions: 5,
    effets: { hp: 10, moral: 1, paDiffere: 3 },
    // villesAutorisees ajoute (lot isolation des villes, 22 aout 2026) : buildingsAutorises seul
    // ne verrouille QUE le buildingId, jamais la ville -- 'hotel-republica' est partage par les 4
    // capitales (Luthecia/narco/soviet/khalija) ET par les Hotels de PSM/Montrouge (meme
    // buildingId, noms differents). Sans ce champ, ces 3 menus etaient donc techniquement
    // disponibles a Port-Sainte-Marie et Montrouge (bug de portee confirme par audit). 'capitale'
    // exclut bien PSM (ville_a) et Montrouge (ville_b) au sein de Republic -- residu non couvert :
    // aucun champ "pays autorise" n'existe dans ce moteur, donc les capitales des 3 AUTRES empires
    // (qui partagent aussi la cle de ville 'capitale') restent techniquement non exclues ; corriger
    // cela exigerait un nouveau champ de portee par pays, hors perimetre de ce lot (aucune nouvelle
    // architecture de scope creee ici, uniquement villesAutorisees deja existant et deja eprouve
    // par carbonade_frites).
    // paysAutorises ajoute (lot scope pays, 22 aout 2026) : ferme le residu signale au lot
    // precedent (les 4 capitales partagent la meme cle de ville 'capitale').
    typesAutorises: ['brasserie'], paysAutorises: ['republic'], villesAutorisees: ['capitale'], buildingsAutorises: ['hotel-republica'],
    // Prix strictement fixe (lot plafonds, 21 aout 2026) : jamais recalcule par
    // produireRecetteCommerce() malgre un proprietaire PNJ par defaut -- voir le nouveau
    // controle "!recette.prixFixe" ajoute a ce recalcul, plus bas dans ce fichier.
    prixFixe: true
  },

  // Marche de Luthecia (lot Marche, 21 aout 2026) : production reelle de sandwiches, remplace
  // l'ancien se_nourrir generique/hors-stock a cet endroit. Rendement 1 PA -> 8 sandwiches (chiffre
  // demande, aucune valeur "souvenue" -- verifie qu'aucun autre rendement du moteur n'etait
  // suppose ici). Interpretation RP demandee : cereales=farine/pain, fruits_legumes=salade/tomate,
  // viande=jambon/poulet -- aucune des 3 n'est une matiere nouvelle. villesAutorisees verrouille a
  // la Capitale (Luthecia) : le type 'marche' est techniquement partage avec Montrouge/Khalija
  // (BUILDING_COMMERCE_TYPE), mais cette recette ne doit y etre disponible nulle part ailleurs.
  sandwich: {
    id: 'sandwich', label: 'Sandwich', categorie: 'plat', image: null,
    materiaux: { cereales: 1, fruits_legumes: 1, viande: 1 }, pa: 1, portions: 8,
    // +1 PA demande = paDiffere (meme convention que les menus du Republica ci-dessus,
    // aucun mecanisme de PA immediat disponible dans ce moteur de vente).
    effets: { hp: 5, moral: 1, paDiffere: 1 },
    typesAutorises: ['marche'], villesAutorisees: ['capitale'], buildingsAutorises: null,
    // Prix strictement fixe (lot correctif final, 21 aout 2026), meme attribut que les menus du
    // Republica -- beneficie automatiquement des deux controles generiques (produireRecetteCommerce
    // et confirmerFixerPrixCommerce), aucun code specifique au sandwich.
    prixFixe: true,
    // Libelle du bouton (lot mini-finition marche, 22 aout 2026) : un sandwich achete au marche
    // est consomme immediatement, "Commander" est contre-intuitif -- "Manger" via l'attribut
    // generique labelAction (doConsulterCarteCommerce ci-dessus), comportement de
    // commanderProduitCommerce() strictement inchange.
    labelAction: 'Manger'
  }
};

// Correspondance buildingId -> type de commerce (17 aout 2026, lot 3+) -- permet a un seul jeu
// d'ordres generiques (produire_commerce/consulter_carte_commerce, plateau-router.js) de
// s'appliquer a tout batiment : le type est lu ici plutot que duplique dans chaque room config.
// Cle 'buildingId' pour un commerce mono-piece (le batiment EST le commerce) ; cle
// 'buildingId|roomId' quand un meme buildingId partage entre plusieurs villes n'a qu'UNE de ses
// pieces qui est un commerce (le stade : sa buvette seulement, pas le terrain).
const BUILDING_COMMERCE_TYPE = {
  'cafe-gare-montrouge': 'cafe',
  'brasserie-voyageurs-montrouge': 'brasserie',
  'hotel-mineur': 'cafe',
  'stade|buvette': 'buvette',
  // Lot Le Republica (21 aout 2026) : migration anticipee par le commentaire de
  // RECETTES_ALIMENTAIRES.biere_pression (20 aout 2026, "si le Bar des Pecheurs/Hotel Republica
  // sont migres plus tard"). Cle room-scopee (hotel-republica heberge 2 commerces distincts,
  // meme principe que le stade) -- les autres pieces de l'hotel (accueil/chambres/suites) ne
  // sont pas concernees, resoudreCommerceActuel() n'a pas de repli buildingId seul ici.
  'hotel-republica|restaurant': 'brasserie',
  'hotel-republica|bar': 'bar',
  // Lot Marche de Luthecia (21 aout 2026) : cle buildingId seule (commerce mono-piece, une seule
  // room 'marche_ext' dans le template BUILDINGS['marche']). Ce buildingId est PARTAGE par
  // plusieurs villes/empires (Montrouge, Souk d'Al-Khalija...) -- resoudreCommerceActuel() n'a
  // aucune notion de ville/empire, donc cette entree resout techniquement un commerce partout ou
  // buildingId==='marche'. Sans consequence pratique ailleurs : aucun bouton commerce
  // (produire_commerce/consulter_carte_commerce/vendre_matiere_commerce) n'existe nulle part
  // ailleurs que dans le roomOverride de Luthecia (WORLD.republic.capitale.buildingContext.marche,
  // voir plus bas) -- sans bouton, aucun joueur ne peut jamais declencher ces fn a Montrouge ou au
  // Souk. La donnee reelle (stock/caisse) est de toute facon deja scopee par ville via
  // chargerCommerce(type, pays, ville, buildingId, roomId).
  'marche': 'marche'
};

// Types de commerce sans caisse autonome (paiement client/salaire de production routes vers la
// caisse INSTITUTIONNELLE du batiment dont ils dependent, jamais data.caisse) -- generalise le
// cas pionnier de la buvette du stade (lot 5) au marche (lot Marche de Luthecia, 21 aout 2026).
// Cle = data.type, valeur = categorie passee a getCaisseLocaleId(categorie, ville). La caisse
// "Marche" existe deja independamment de ce lot (Consulter les caisses communales / Repartir le
// budget municipal, mairie-capitale la suivent depuis le lot des caisses locales, 16 aout 2026) --
// ce lot ne fait qu'y raccorder une vraie vente, il ne cree aucune nouvelle caisse.
const COMMERCE_SANS_CAISSE_AUTONOME = { buvette: 'stade', marche: 'marche' };

// Plafond universel des stocks de detail (lot plafonds, 21 aout 2026) -- 20 unites maximum par
// type de matiere premiere ET par type de produit fini, PJ comme PNJ, pour tout commerce passant
// par ce moteur (defautCommerce/chargerCommerce/produireRecetteCommerce/commanderProduitCommerce/
// vendreMatiereCommerce -- cafe/brasserie/bar/buvette/marche). N'affecte jamais entrepots ni
// usines : ces deux architectures (plateau-justice-economie.js, CHAINES_PRODUCTION_USINE) ont
// leurs propres fonctions dediees et ne passent jamais par les 2 primitives ci-dessous. Un
// stockMax declare par commerce (parametres.stockMax) reste utilisable pour fixer un plafond PLUS
// bas que 20 si besoin -- jamais plus haut : le plafond effectif est toujours
// min(declare ?? 20, STOCK_MAX_COMMERCE). Un stock deja superieur a 20 lors de l'ajout de ce
// plafond n'est jamais tronque (aucune ecriture destructive introduite ici) : seule toute
// NOUVELLE entree au-dela de 20 est refusee, jusqu'a ce que la consommation le fasse redescendre.
const STOCK_MAX_COMMERCE = 20;

function plafondEffectifCommerce(data, cle) {
  const declare = data.parametres.stockMax ? data.parametres.stockMax[cle] : null;
  return declare != null ? Math.min(declare, STOCK_MAX_COMMERCE) : STOCK_MAX_COMMERCE;
}

// Resout le commerce (type + roomId) correspondant a l'endroit ou se trouve le joueur --
// verifie d'abord la cle room-scopee (batiment a commerces multiples), puis la cle batiment
// seul (commerce mono-piece). Retourne null si aucun commerce ici.
function resoudreCommerceActuel() {
  const buildingId = state.currentBuilding;
  const roomId = state.currentRoom;
  const cleRoom = buildingId + '|' + roomId;
  if (BUILDING_COMMERCE_TYPE[cleRoom]) return { type: BUILDING_COMMERCE_TYPE[cleRoom], buildingId, roomId };
  if (BUILDING_COMMERCE_TYPE[buildingId]) return { type: BUILDING_COMMERCE_TYPE[buildingId], buildingId, roomId: null };
  return null;
}

// =====================
// VENDRE DES MATIERES AU COMMERCE (correctif cible, 17 aout 2026) -- meme principe que
// doVendreMatiereArmurerie/confirmerVenteMatiere ci-dessous, generalise sans dupliquer :
// reutilise crediterStockMatiereCommerce (deja generique, deja teste). Ferme le chainon
// manquant identifie au rapport precedent : jusqu'ici seule la dotation de depart alimentait
// le stock matieres d'un commerce alimentaire, aucun ordre en jeu ne permettait a un PJ de le
// reapprovisionner.
// =====================

// Matieres acceptees = union des materiaux des recettes de la CARTE du commerce (jamais une
// liste codee en dur par etablissement) -- verifie correspondre exactement aux exemples donnes
// (cereales/viande pour le Cafe, +poisson pour la Brasserie, cereales seul pour l'Hotel Mineur,
// alcool+cereales pour la buvette dont un des 3 snacks utilise des cereales).
function matieresAccepteesParCommerce(data) {
  const cles = new Set();
  (data.carte || []).forEach(id => {
    const recette = RECETTES_ALIMENTAIRES[id];
    if (recette) Object.keys(recette.materiaux).forEach(m => cles.add(m));
  });
  return [...cles];
}

// Prix d'achat unitaire : parametres.prixAchatMatiere (meme champ que l'armurerie) si fixe
// manuellement (PJ, a cabler ulterieurement en UI -- le parametre existe et est deja lu),
// sinon repli automatique sur RESSOURCES_ECONOMIE[matiere].prixAchatFournisseur (PNJ) -- le prix
// deja defini dans le jeu comme "prix paye par l'entrepot A LA LIVRAISON", exactement la meme
// notion economique qu'un commerce payant un PJ pour une matiere livree. Aucune economie
// parallele inventee.
function prixAchatMatiereCommerce(data, matiere) {
  const manuel = data.parametres.prixAchatMatiere ? data.parametres.prixAchatMatiere[matiere] : null;
  if (manuel != null) return manuel;
  return (typeof RESSOURCES_ECONOMIE !== 'undefined' && RESSOURCES_ECONOMIE[matiere] ? RESSOURCES_ECONOMIE[matiere].prixAchatFournisseur : 0) || 0;
}

// Fourchette de prix d'achat autorisee pour un proprietaire PJ (correctif de finition, 17 aout
// 2026). L'armurerie (confirmerGestionArmurerie) n'a AUCUNE borne comparable pour son
// prixAchatMatiere -- seulement Math.max(0, ...), verifie exhaustivement avant d'ecrire cette
// fonction -- donc pas de regle existante a generaliser. Regle provisoire appliquee telle que
// demandee : ±50% autour de prixAchatFournisseur, coefficients centralises ci-dessous pour
// rester facilement ajustables.
const COEF_PRIX_ACHAT_MATIERE_MIN = 0.5;
const COEF_PRIX_ACHAT_MATIERE_MAX = 1.5;
function fourchettePrixAchatMatierePJ(matiere) {
  const base = (typeof RESSOURCES_ECONOMIE !== 'undefined' && RESSOURCES_ECONOMIE[matiere]) ? RESSOURCES_ECONOMIE[matiere].prixAchatFournisseur : 0;
  return {
    min: Math.round(base * COEF_PRIX_ACHAT_MATIERE_MIN * 100) / 100,
    max: Math.round(base * COEF_PRIX_ACHAT_MATIERE_MAX * 100) / 100
  };
}

// Reserve au proprietaire PJ -- fixe le prix auquel SON commerce achete une matiere aux
// vendeurs. La buvette n'a jamais de proprietaire PJ (exclue du rachat depuis le lot 6,
// institution municipale) : data.proprietaire y vaut toujours 'PNJ' par construction, donc deja
// refusee par le controle ci-dessous sans cas particulier a ecrire.
async function confirmerFixerPrixAchatMatiereCommerce(commerceType, pays, ville, buildingId, roomId, matiere, prixSaisi) {
  const data = await chargerCommerce(commerceType, pays, ville, buildingId, roomId);
  if (!data) return { ok: false, raison: 'introuvable' };
  if (data.proprietaire === 'PNJ' || data.proprietaire !== state.char?.name) return { ok: false, raison: 'reserve_proprietaire' };
  if (!matieresAccepteesParCommerce(data).includes(matiere)) return { ok: false, raison: 'matiere_non_acceptee' };

  const { min, max } = fourchettePrixAchatMatierePJ(matiere);
  const prix = parseFloat(prixSaisi);
  if (isNaN(prix) || prix < min || prix > max) return { ok: false, raison: 'hors_fourchette', min, max };

  if (!data.parametres.prixAchatMatiere) data.parametres.prixAchatMatiere = {};
  data.parametres.prixAchatMatiere[matiere] = Math.round(prix * 100) / 100;
  await sbSaveEntreprise(data.id, data);
  return { ok: true, prix: data.parametres.prixAchatMatiere[matiere] };
}

// Transaction pure (testable isolement) : matieres -> verification -> caisse -> stock -> cout
// moyen -> historique. Ordre securise : tout controle sans effet de bord (matiere acceptee,
// stock personnel, stock max du commerce) passe AVANT le seul point a effet de bord externe
// (debit de la caisse du stade pour une buvette, via debiterCaisseBatimentAtomique -- meme
// prudence d'ordonnancement que produireRecetteCommerce, meme raison : une vraie ecriture
// Supabase ne doit jamais se declencher si un controle ulterieur peut encore faire echouer la
// vente). Aucune taxe transactionnelle : la vente de matiere premiere a une entreprise n'a
// jamais ete taxee (confirmerVenteMatiere, armurerie, ne l'a jamais ete non plus) -- seule la
// vente finale au consommateur l'est (commanderProduitCommerce).
async function vendreMatiereCommerce(commerceType, pays, ville, buildingId, roomId, matiere, qte) {
  const data = await chargerCommerce(commerceType, pays, ville, buildingId, roomId);
  if (!data) return { ok: false, raison: 'introuvable' };
  if (!matieresAccepteesParCommerce(data).includes(matiere)) return { ok: false, raison: 'matiere_non_acceptee' };
  if (!qte || qte <= 0) return { ok: false, raison: 'quantite_invalide' };

  const lot = (state.inventory || []).find(i => i.stackable && i.stackKey === matiere && (i.qty || 0) > 0);
  if (!lot || lot.qty < qte) return { ok: false, raison: 'stock_personnel_insuffisant' };

  const stockMax = plafondEffectifCommerce(data, matiere);
  const stockActuel = data.stockMatieres[matiere] || 0;
  if (stockActuel + qte > stockMax) return { ok: false, raison: 'stock_plein', placeRestante: Math.max(0, stockMax - stockActuel) };

  const prixUnitaire = prixAchatMatiereCommerce(data, matiere);
  const total = prixUnitaire * qte;

  let coutOk;
  const categorieCaisseInstit = COMMERCE_SANS_CAISSE_AUTONOME[data.type];
  if (categorieCaisseInstit && typeof debiterCaisseBatimentAtomique === 'function' && typeof getCaisseLocaleId === 'function') {
    // Aucune caisse autonome (doctrine deja validee/codee, generalisee de la buvette au marche) :
    // le commerce paie le vendeur depuis sa caisse institutionnelle, comme il y verse deja ses
    // ventes et son salaire de production.
    coutOk = (await debiterCaisseBatimentAtomique(pays, getCaisseLocaleId(categorieCaisseInstit, ville), total)) === total;
  } else {
    coutOk = (data.caisse || 0) >= total;
  }
  if (!coutOk) return { ok: false, raison: 'caisse_insuffisante' };

  lot.qty -= qte;
  if (lot.qty <= 0) state.inventory = state.inventory.filter(i => i !== lot);

  crediterStockMatiereCommerce(data, matiere, qte, prixUnitaire);
  if (!categorieCaisseInstit) data.caisse -= total;
  state.arg = (state.arg || 0) + total;

  ajouterHistoriqueEntreprise(data, -total, 'Achat de matière première (' + matiere + ' x' + qte + ') — ' + (state.char?.name || 'Anonyme'));
  await sbSaveEntreprise(data.id, data);

  return { ok: true, total, prixUnitaire, qte };
}

function doVendreMatiereCommerceGenerique(pa, cost) {
  const c = resoudreCommerceActuel();
  if (!c) { showToast('Indisponible', '', false); return; }
  doVendreMatiereCommerce(c.type, c.buildingId, c.roomId, pa, cost);
}

async function doVendreMatiereCommerce(commerceType, buildingId, roomId, pa, cost) {
  const pays = state.country || 'republic';
  const ville = state.currentCity || 'capitale';
  const data = await chargerCommerce(commerceType, pays, ville, buildingId, roomId);
  if (!data) { showToast('Indisponible', '', false); return; }

  const cur = COUNTRIES[state.country || 'republic']?.cur || 'FR';
  const matieres = matieresAccepteesParCommerce(data);
  const disponibles = matieres.filter(m => (state.inventory || []).some(i => i.stackable && i.stackKey === m && (i.qty || 0) > 0));

  document.getElementById('postes-modal-title').textContent = 'Vendre des matières au commerce';
  let html = '<div style="padding:1rem">';
  if (disponibles.length === 0) {
    html += '<div style="font-size:.9rem;color:#8a8060">Vous ne possédez aucune matière que ce commerce accepte' + (matieres.length ? ' (' + matieres.map(m => (RESSOURCES_ECONOMIE[m]?.label || m)).join(', ') + ')' : '') + '.</div>';
  } else {
    html += '<div style="font-size:.82rem;color:#8a8060;margin-bottom:.7rem">Prix d\'achat fixés par le commerce.</div>';
  }
  disponibles.forEach(m => {
    const lot = (state.inventory || []).find(i => i.stackable && i.stackKey === m && (i.qty || 0) > 0);
    const qteDispo = lot?.qty || 0;
    const prixUnitaire = prixAchatMatiereCommerce(data, m);
    const stockMax = plafondEffectifCommerce(data, m);
    const stockActuel = data.stockMatieres[m] || 0;
    const placeRestante = Math.max(0, stockMax - stockActuel);
    const label = (typeof RESSOURCES_ECONOMIE !== 'undefined' && RESSOURCES_ECONOMIE[m]) ? RESSOURCES_ECONOMIE[m].label : m;
    const qteInitiale = Math.max(1, Math.min(qteDispo, placeRestante));
    html += '<div style="display:flex;align-items:center;gap:.5rem;margin-bottom:.5rem">';
    html += '<span style="flex:1;font-size:.88rem;color:#c0b090">' + label + ' (' + prixUnitaire.toLocaleString('fr-FR') + ' ' + cur + '/unité) — vous en avez ' + qteDispo + ', capacité restante ' + placeRestante + '</span>';
    html += '<input type="number" id="vendre-commerce-qte-' + m + '" min="1" max="' + Math.min(qteDispo, placeRestante) + '" value="' + qteInitiale + '" style="width:70px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.3rem;font-size:.88rem;outline:none"/>';
    html += '<button ' + (placeRestante === 0 ? 'disabled style="padding:.3rem .6rem;border:1px solid #3a2a20;background:transparent;color:#5a5040;cursor:default;font-size:.82rem"' : 'onclick="confirmerVendreMatiereCommerceUI(\'' + commerceType + '\',\'' + buildingId + '\',\'' + (roomId || '') + '\',\'' + m + '\')" style="padding:.3rem .6rem;border:1px solid #4a8a4a;background:transparent;color:#6ab858;cursor:pointer;font-size:.82rem"') + '>Vendre</button>';
    html += '</div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerVendreMatiereCommerceUI(commerceType, buildingId, roomId, matiere) {
  const pays = state.country || 'republic';
  const ville = state.currentCity || 'capitale';
  const roomIdReel = roomId || null;
  const qte = parseInt(document.getElementById('vendre-commerce-qte-' + matiere)?.value || '0');
  document.getElementById('modal-postes')?.classList.remove('open');
  if (!qte || qte <= 0) { showToast('Quantité invalide', '', false); return; }

  const res = await vendreMatiereCommerce(commerceType, pays, ville, buildingId, roomIdReel, matiere, qte);
  const label = (typeof RESSOURCES_ECONOMIE !== 'undefined' && RESSOURCES_ECONOMIE[matiere]) ? RESSOURCES_ECONOMIE[matiere].label : matiere;
  if (!res.ok) {
    const messages = {
      introuvable: '',
      matiere_non_acceptee: 'Ce commerce n\'achète pas cette matière.',
      quantite_invalide: '',
      stock_personnel_insuffisant: 'Vous n\'avez pas ' + qte + ' unité(s) de ' + label + '.',
      stock_plein: 'Le stock maximum de cette matière est atteint pour ce commerce.',
      caisse_insuffisante: 'Le commerce ne peut pas acheter cette quantité actuellement.'
    };
    showToast('Vente refusée', messages[res.raison] || '', false);
    return;
  }
  updateUI();
  showToast('Vente effectuée', '+' + res.total.toLocaleString('fr-FR') + ' FR pour ' + res.qte + ' ' + label + '.', true, true);
  addJournalEntry('Vente de ' + res.qte + ' ' + label + ' au commerce (+' + res.total.toLocaleString('fr-FR') + ' FR).', 'event-good');
  doVendreMatiereCommerce(commerceType, buildingId, roomIdReel, 0, 0); // rafraichit, meme pattern que les autres interfaces de commerce
}

// Dotations de depart par commerce pilote (meme principe que defautArmurerie : un commerce ne
// demarre pas a zero, comme l'entrepot/l'armurerie). Cle = buildingId, lue par chargerCommerce
// (definie plus haut dans ce fichier) au tout premier chargement d'un commerce.
const DOTATIONS_COMMERCE_PILOTE = {
  'cafe-gare-montrouge': function(data) {
    // caisse de depart (meme necessite que defautArmurerie : sans fonds, la toute premiere
    // production est bloquee par le controle "caisse insuffisante pour payer le salaire" --
    // trouve par test d'integration local, pas par relecture). Montant modeste, proportionne a
    // un petit cafe (pas les 20000 FR de l'armurerie) : ~40 productions a 50 FR de salaire.
    data.caisse = 2000;
    // Lot boissons (20 aout 2026) : fruits_legumes/produits_exotiques ajoutes au prix de base
    // courant (meme convention que cereales/viande ci-dessus), pour alimenter Cafe/Jus de
    // fruits/Vin des leur premiere production.
    data.stockMatieres = { cereales: 10, viande: 10, fruits_legumes: 10, produits_exotiques: 10 };
    data.coutMoyenMatieres = { cereales: 3, viande: 5, fruits_legumes: 4, produits_exotiques: 6 }; // au prix de base courant des matieres (releve economique)
    data.carte = ['boeuf_bourguignon', 'cafe_boisson', 'jus_de_fruits', 'vin', 'biere_pression'];
    // Valeurs plafonnees a 20 (lot plafonds universels commerces de detail, 21 aout 2026) --
    // etaient a 30, desormais alignees sur STOCK_MAX_COMMERCE (plus bas) pour que l'affichage
    // corresponde exactement a la capacite reellement appliquee par vendreMatiereCommerce/
    // produireRecetteCommerce.
    data.parametres.stockMax = { boeuf_bourguignon: 20, cafe_boisson: 20, jus_de_fruits: 20, vin: 20, biere_pression: 20 };
    // Prix initial fixe a 7 FR pour les 4 boissons (decision de Fred, 20 aout 2026) -- NOTE : ce
    // commerce est PNJ par defaut, donc produireRecetteCommerce() recalculera automatiquement ce
    // prix a chaque production via prixVenteAutoPNJ (le meme mecanisme deja en place pour
    // boeuf_bourguignon juste en dessous) : 7 FR ne restera donc affiche que jusqu'a la toute
    // premiere production de chaque boisson, puis convergera vers le cout de revient reel x2
    // (~7,07 FR biere, ~7,20 FR jus/vin, ~7,47 FR cafe avec les couts moyens ci-dessus).
    data.parametres.prixVente = {
      boeuf_bourguignon: prixVenteAutoPNJ(coutRevientPortionRecette(data, RECETTES_ALIMENTAIRES.boeuf_bourguignon)),
      cafe_boisson: 7,
      jus_de_fruits: 7,
      vin: 7,
      biere_pression: 7
    };
  },
  'brasserie-voyageurs-montrouge': function(data) {
    data.caisse = 3000; // vraie restauration, dotation superieure au petit cafe
    data.stockMatieres = { cereales: 15, viande: 15, poisson: 10 };
    data.coutMoyenMatieres = { cereales: 3, viande: 5, poisson: 4 };
    data.carte = ['carbonade_frites', 'plat_de_poisson', 'saucisse_puree'];
    data.parametres.stockMax = { carbonade_frites: 20, plat_de_poisson: 20, saucisse_puree: 20 };
    data.parametres.prixVente = {
      carbonade_frites: prixVenteAutoPNJ(coutRevientPortionRecette(data, RECETTES_ALIMENTAIRES.carbonade_frites)),
      plat_de_poisson: prixVenteAutoPNJ(coutRevientPortionRecette(data, RECETTES_ALIMENTAIRES.plat_de_poisson)),
      saucisse_puree: prixVenteAutoPNJ(coutRevientPortionRecette(data, RECETTES_ALIMENTAIRES.saucisse_puree))
    };
  },
  'hotel-mineur': function(data) {
    data.caisse = 1000; // offre minimale (petit-dejeuner seulement), dotation la plus modeste
    data.stockMatieres = { cereales: 10 };
    data.coutMoyenMatieres = { cereales: 3 };
    data.carte = ['petit_dejeuner'];
    data.parametres.stockMax = { petit_dejeuner: 20 }; // plafonne (lot plafonds, 21 aout 2026, etait 30)
    data.parametres.prixVente = { petit_dejeuner: prixVenteAutoPNJ(coutRevientPortionRecette(data, RECETTES_ALIMENTAIRES.petit_dejeuner)) };
  },
  'stade|buvette': function(data) {
    // AUCUNE caisse ici (data.caisse reste 0 en permanence) -- ni pour les ventes (deja routees
    // vers la caisse du stade, doctrine du lot precedent), ni pour la main-d'oeuvre de
    // production (routee vers la meme caisse du stade, voir produireRecetteCommerce ci-dessus).
    data.stockMatieres = { alcool: 10, cereales: 5 };
    data.coutMoyenMatieres = { alcool: 14, cereales: 3 }; // prix de base courant (releve economique)
    data.carte = ['biere_pression', 'boisson_sans_alcool', 'snack_buvette'];
    data.parametres.stockMax = { biere_pression: 20, boisson_sans_alcool: 20, snack_buvette: 20 }; // plafonne (lot plafonds, 21 aout 2026, etait 30)
    data.parametres.prixVente = {
      biere_pression: prixVenteAutoPNJ(coutRevientPortionRecette(data, RECETTES_ALIMENTAIRES.biere_pression)),
      boisson_sans_alcool: prixVenteAutoPNJ(coutRevientPortionRecette(data, RECETTES_ALIMENTAIRES.boisson_sans_alcool)),
      snack_buvette: prixVenteAutoPNJ(coutRevientPortionRecette(data, RECETTES_ALIMENTAIRES.snack_buvette))
    };
  },
  // Lot carte gastronomique Le Republica (21 aout 2026) -- remplace la carte provisoire
  // (boeuf_bourguignon/plat_de_poisson/saucisse_puree, plats generalistes reutilises tels quels
  // au lot precedent) par les 3 vrais menus gastronomiques (RECETTES_ALIMENTAIRES.menu_gastro-
  // nomique_1/2/3 ci-dessus) + 'vin' (recette deja existante, typesAutorises etendu a 'brasserie'
  // ci-dessus pour ce seul usage). fruits_legumes ajoute au stock de depart (necessaire au vin et
  // au Menu 3), memes ordres de grandeur que les autres commerces alimentaires.
  'hotel-republica|restaurant': function(data) {
    data.caisse = 3000;
    data.stockMatieres = { cereales: 15, viande: 15, poisson: 10, fruits_legumes: 10 };
    data.coutMoyenMatieres = { cereales: 3, viande: 5, poisson: 4, fruits_legumes: 4 };
    data.carte = ['menu_gastronomique_1', 'menu_gastronomique_2', 'menu_gastronomique_3', 'vin'];
    data.parametres.stockMax = { menu_gastronomique_1: 20, menu_gastronomique_2: 20, menu_gastronomique_3: 20, vin: 20 }; // vin plafonne (lot plafonds, 21 aout 2026, etait 30)
    data.parametres.prixVente = {
      // Prix fixe demande (les 3 menus valent volontairement la meme chose, aucun n'est
      // statistiquement superieur) -- PAS calcule via prixVenteAutoPNJ malgre le proprietaire PNJ
      // par defaut, meme convention que les boissons du Cafe de la Gare (prix initial fixe a 7 FR
      // le 20 aout 2026). A noter (comme pour tout commerce PNJ) : produireRecetteCommerce()
      // recalculera ce prix automatiquement des la premiere production de chaque menu, vers son
      // propre cout de revient x2 -- il ne restera pas fige a 120 indefiniment. Signale au rapport.
      menu_gastronomique_1: 120,
      menu_gastronomique_2: 120,
      menu_gastronomique_3: 120,
      vin: prixVenteAutoPNJ(coutRevientPortionRecette(data, RECETTES_ALIMENTAIRES.vin))
    };
  },
  'hotel-republica|bar': function(data) {
    data.caisse = 2000;
    data.stockMatieres = { cereales: 10 };
    data.coutMoyenMatieres = { cereales: 3 };
    data.carte = ['biere_pression', 'boisson_sans_alcool', 'snack_buvette'];
    data.parametres.stockMax = { biere_pression: 20, boisson_sans_alcool: 20, snack_buvette: 20 }; // plafonne (lot plafonds, 21 aout 2026, etait 30)
    data.parametres.prixVente = {
      biere_pression: prixVenteAutoPNJ(coutRevientPortionRecette(data, RECETTES_ALIMENTAIRES.biere_pression)),
      boisson_sans_alcool: prixVenteAutoPNJ(coutRevientPortionRecette(data, RECETTES_ALIMENTAIRES.boisson_sans_alcool)),
      snack_buvette: prixVenteAutoPNJ(coutRevientPortionRecette(data, RECETTES_ALIMENTAIRES.snack_buvette))
    };
  },
  // Marche de Luthecia (lot Marche, 21 aout 2026) -- meme doctrine "aucune caisse autonome" que
  // la buvette (data.caisse reste a 0 en permanence) : ventes et salaire de production routes
  // vers la caisse institutionnelle "Marche" deja existante (COMMERCE_SANS_CAISSE_AUTONOME.marche
  // = 'marche', voir plus haut), jamais vers Jean-Pierre Bidoche ou Ginette Legume (aucune caisse
  // individuelle creee pour eux, ils restent des PNJ d'ambiance).
  'marche': function(data) {
    data.stockMatieres = { cereales: 10, fruits_legumes: 10, viande: 10 };
    data.coutMoyenMatieres = { cereales: 3, fruits_legumes: 4, viande: 5 };
    data.carte = ['sandwich'];
    data.parametres.stockMax = { sandwich: 20 }; // plafonne (lot plafonds, 21 aout 2026, etait 40)
    // Prix fixe demande (15 FR), meme convention que les menus du Republica ci-dessus -- pas
    // calcule via prixVenteAutoPNJ. Meme mise en garde : produireRecetteCommerce() le recalculera
    // automatiquement des la premiere production (proprietaire PNJ par defaut).
    data.parametres.prixVente = { sandwich: 15 };
  }
};

function doProduireCommerceGenerique(pa, cost) {
  const c = resoudreCommerceActuel();
  if (!c) { showToast('Indisponible', '', false); return; }
  doProduireRecetteCommerce(c.type, c.buildingId, c.roomId, pa, cost);
}

function doConsulterCarteCommerceGenerique(pa, cost) {
  const c = resoudreCommerceActuel();
  if (!c) { showToast('Indisponible', '', false); return; }
  doConsulterCarteCommerce(c.type, c.buildingId, c.roomId, pa, cost);
}

// 1 PA de travail = 50 FR de main-d'oeuvre (regle validee, releve economique du 17 aout 2026,
// identique au flat de l'armurerie -- SALAIRE_PRODUCTION_ARMURERIE/PA_PRODUCTION_ARMURERIE
// ci-dessus, 100/2=50). Un PA produit plusieurs portions (recette.portions), contrairement a
// l'armurerie (1 PA fixe -> 1 objet) : le rendement usine (CHAINES_PRODUCTION_USINE,
// plateau-justice-economie.js, 1 PA -> plusieurs unites) est le bon precedent ici, pas l'armurerie.
const COUT_MAIN_OEUVRE_PA_ALIMENTAIRE = 50;

function recetteAutoriseePourCommerce(recette, commerce) {
  if (!recette || !commerce) return false;
  if (!recette.typesAutorises || !recette.typesAutorises.includes(commerce.type)) return false;
  // paysAutorises (lot scope pays, 22 aout 2026) : meme principe que villesAutorisees/
  // buildingsAutorises, generique -- absent = comportement inchange (aucune restriction),
  // present = compare a commerce.country (deja lu, jamais recalcule ici -- chargerCommerce()/
  // defautCommerce() le renseignent deja pour tout commerce). Comble le residu signale au lot
  // precedent : buildingId/ville seuls ne peuvent pas distinguer les 4 capitales, qui partagent
  // toutes la cle de ville 'capitale'.
  if (recette.paysAutorises && !recette.paysAutorises.includes(commerce.country)) return false;
  if (recette.villesAutorisees && !recette.villesAutorisees.includes(commerce.city)) return false;
  if (recette.buildingsAutorises && !recette.buildingsAutorises.includes(commerce.buildingId)) return false;
  return true;
}

// Cout de revient par portion = (cout matieres au cout moyen REELLEMENT paye par CE commerce +
// main-d'oeuvre) / portions -- decision ferme de Fred (releve economique du 17 aout 2026) :
// jamais un cours theorique (RESSOURCES_ECONOMIE/getPrixRessource), toujours coutMoyenMatieres.
function coutRevientPortionRecette(commerce, recette) {
  const coutMatieres = Object.entries(recette.materiaux).reduce((s, [m, q]) => {
    const coutUnitaire = (commerce.coutMoyenMatieres && commerce.coutMoyenMatieres[m]) || 0;
    return s + q * coutUnitaire;
  }, 0);
  const coutMainOeuvre = recette.pa * COUT_MAIN_OEUVRE_PA_ALIMENTAIRE;
  return (coutMatieres + coutMainOeuvre) / recette.portions;
}

// Arrondi a l'entier (regle validee par Fred, 20 aout 2026 : prix de vente automatique PNJ =
// cout de revient x2, arrondi a l'entier -- pas au centime). Primitive generique, tous les
// commerces PNJ passent par ici (boeuf_bourguignon, biere_pression, cafe_boisson, jus_de_fruits,
// vin, etc.) : correction centralisee, aucun bricolage specifique au Cafe de la Gare.
function prixVenteAutoPNJ(coutRevient) {
  return Math.round(coutRevient * 2);
}

// Fourchette autorisee pour un commerce tenu par un PJ (+10% a +80% du cout de revient) --
// meme principe que la fourchette ±40% deja utilisee par les usines/entrepots
// (confirmerFixerPrixVenteDirecte, confirmerFixerPrixAchatEntrepot, plateau-justice-economie.js),
// bornes differentes ici car validees specifiquement pour les commerces alimentaires.
function fourchettePrixPJ(coutRevient) {
  return {
    min: Math.round(coutRevient * 1.10 * 100) / 100,
    max: Math.round(coutRevient * 1.80 * 100) / 100
  };
}

// Reserve au proprietaire PJ d'un commerce -- fixe le prix d'une recette de sa carte, dans la
// fourchette. Aucun commerce pilote n'est encore possede par un PJ (rachat generalise = lot 6),
// mais l'engine doit deja le permettre (section 7 du cahier des charges) : fonction complete et
// testee, simplement pas encore reliee a un bouton en jeu tant qu'aucun commerce n'est rachetable.
async function confirmerFixerPrixCommerce(commerceType, pays, ville, buildingId, roomId, recetteId, prixSaisi) {
  const data = await chargerCommerce(commerceType, pays, ville, buildingId, roomId);
  const recette = RECETTES_ALIMENTAIRES[recetteId];
  if (!data || !recette) return { ok: false, raison: 'introuvable' };
  // Prix fixe (lot correctif final, 21 aout 2026) -- meme attribut de recette que le blocage du
  // recalcul PNJ automatique dans produireRecetteCommerce(), etendu ici au reglage manuel PJ.
  // Aucun ID hardcode : toute recette future declaree prixFixe:true en beneficie automatiquement.
  if (recette.prixFixe) return { ok: false, raison: 'prix_fixe' };
  if (data.proprietaire === 'PNJ' || data.proprietaire !== state.char?.name) return { ok: false, raison: 'reserve_proprietaire' };

  const coutRevient = coutRevientPortionRecette(data, recette);
  const { min, max } = fourchettePrixPJ(coutRevient);
  const prix = parseFloat(prixSaisi);
  if (isNaN(prix) || prix < min || prix > max) return { ok: false, raison: 'hors_fourchette', min, max };

  data.parametres.prixVente[recetteId] = Math.round(prix * 100) / 100;
  await sbSaveEntreprise(data.id, data);
  return { ok: true, prix: data.parametres.prixVente[recetteId] };
}

// Interface "Gerer mon commerce" (mini-lot de finition, 17 aout 2026) -- reservee au
// proprietaire PJ. N'invente aucune regle de calcul : delegue integralement a
// coutRevientPortionRecette/fourchettePrixPJ/confirmerFixerPrixCommerce (lot 2), deja ecrites et
// testees mais jusqu'ici sans point d'entree en jeu.
function doGererCommerceGenerique(pa, cost) {
  const c = resoudreCommerceActuel();
  if (!c) { showToast('Indisponible', '', false); return; }
  doGererCommerce(c.type, c.buildingId, c.roomId);
}

async function doGererCommerce(commerceType, buildingId, roomId) {
  const pays = state.country || 'republic';
  const ville = state.currentCity || 'capitale';
  const data = await chargerCommerce(commerceType, pays, ville, buildingId, roomId);
  if (!data) { showToast('Indisponible', '', false); return; }
  if (data.proprietaire === 'PNJ') { showToast('Réservé au propriétaire', 'Ce commerce appartient encore à un PNJ (rachetable au Bureau des Contrats).', false); return; }
  if (data.proprietaire !== state.char?.name) { showToast('Réservé au propriétaire', 'Ce commerce appartient à ' + data.proprietaire + '.', false); return; }

  const cur = COUNTRIES[state.country || 'republic']?.cur || 'FR';
  document.getElementById('postes-modal-title').textContent = 'Gérer mon commerce';
  let html = '<div style="padding:1rem">';
  html += '<div style="text-align:center;font-family:Bebas Neue,sans-serif;font-size:1.1rem;color:#C9A84C;margin-bottom:.8rem">Caisse : ' + (data.caisse || 0).toLocaleString('fr-FR') + ' ' + cur + '</div>';
  const carte = (data.carte || []).filter(id => RECETTES_ALIMENTAIRES[id]);
  if (carte.length === 0) {
    html += '<div style="font-size:.9rem;color:#8a8060">Aucun produit sur la carte de cet établissement.</div>';
  }
  carte.forEach(id => {
    const recette = RECETTES_ALIMENTAIRES[id];
    const prixActuel = data.parametres.prixVente[id];
    html += '<div style="padding:.6rem;border:1px solid #2a2010;margin-bottom:.5rem">';
    html += '<b style="font-size:.93rem;color:#c0b090">' + recette.label + '</b><br>';
    if (recette.prixFixe) {
      // Prix fixe (lot correctif final, 21 aout 2026) : aucune fourchette/coût de revient
      // affiché ni d'input propose -- ce prix n'est modifiable ni par le moteur PNJ
      // (produireRecetteCommerce) ni par le proprietaire PJ (confirmerFixerPrixCommerce).
      html += '<span style="font-size:.82rem;color:#6a5a30">Prix fixe : ' + (prixActuel != null ? prixActuel.toLocaleString('fr-FR') : 'non défini') + ' ' + cur + ' — non modifiable</span>';
    } else {
      const coutRevient = coutRevientPortionRecette(data, recette);
      const { min, max } = fourchettePrixPJ(coutRevient);
      html += '<span style="font-size:.82rem;color:#8a8060">Coût de revient actuel : ' + coutRevient.toFixed(2) + ' ' + cur + ' — Fourchette autorisée : ' + min.toFixed(2) + ' à ' + max.toFixed(2) + ' ' + cur + '</span><br>';
      html += '<span style="font-size:.82rem;color:#6a5a30">Prix actuel : ' + (prixActuel != null ? prixActuel.toLocaleString('fr-FR') : 'non défini') + ' ' + cur + '</span>';
      html += '<div style="display:flex;gap:.4rem;margin-top:.4rem">';
      html += '<input type="number" min="' + min + '" max="' + max + '" step="0.5" id="gere-commerce-prix-' + id + '" placeholder="Nouveau prix" style="flex:1;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.3rem;font-size:.85rem;outline:none"/>';
      html += '<button onclick="confirmerGererPrixCommerceUI(\'' + commerceType + '\',\'' + buildingId + '\',\'' + (roomId || '') + '\',\'' + id + '\')" style="padding:.3rem .6rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer;font-size:.82rem">Valider</button>';
      html += '</div>';
    }
    html += '</div>';
  });

  // Prix d'achat des matieres (correctif de finition, 17 aout 2026) : matieres determinees
  // generiquement a partir de la carte actuelle (matieresAccepteesParCommerce, deja utilisee par
  // le flux de vente joueur -> commerce) -- si une recette est retiree de la carte et que sa
  // matiere n'est plus utilisee ailleurs, elle disparait naturellement de cette liste, sans
  // toucher ni au stock deja present ni a un ancien prix stocke (juste plus affiche/proposable).
  html += '<div style="font-size:.9rem;color:#8a8060;margin:.9rem 0 .3rem;font-weight:bold">Prix d\'achat des matières</div>';
  const matieresAcceptees = matieresAccepteesParCommerce(data);
  if (matieresAcceptees.length === 0) {
    html += '<div style="font-size:.9rem;color:#8a8060">Aucune matière n\'est actuellement nécessaire aux produits de la carte.</div>';
  }
  matieresAcceptees.forEach(m => {
    const label = (typeof RESSOURCES_ECONOMIE !== 'undefined' && RESSOURCES_ECONOMIE[m]) ? RESSOURCES_ECONOMIE[m].label : m;
    const stockActuel = data.stockMatieres[m] || 0;
    const stockMax = plafondEffectifCommerce(data, m);
    const placeRestante = Math.max(0, stockMax - stockActuel);
    const prixReference = (typeof RESSOURCES_ECONOMIE !== 'undefined' && RESSOURCES_ECONOMIE[m]) ? RESSOURCES_ECONOMIE[m].prixAchatFournisseur : 0;
    const prixActuelAchat = prixAchatMatiereCommerce(data, m);
    const { min, max } = fourchettePrixAchatMatierePJ(m);
    html += '<div style="padding:.6rem;border:1px solid #2a2010;margin-bottom:.5rem">';
    html += '<b style="font-size:.93rem;color:#c0b090">' + label + '</b><br>';
    html += '<span style="font-size:.82rem;color:#8a8060">Stock actuel : ' + stockActuel + (placeRestante != null ? ' — Capacité restante : ' + placeRestante : '') + '</span><br>';
    html += '<span style="font-size:.82rem;color:#8a8060">Prix de référence (PNJ) : ' + prixReference.toLocaleString('fr-FR') + ' ' + cur + ' — Fourchette autorisée : ' + min.toFixed(2) + ' à ' + max.toFixed(2) + ' ' + cur + '</span><br>';
    html += '<span style="font-size:.82rem;color:#6a5a30">Prix actuellement proposé : ' + prixActuelAchat.toLocaleString('fr-FR') + ' ' + cur + '</span>';
    html += '<div style="display:flex;gap:.4rem;margin-top:.4rem">';
    html += '<input type="number" min="' + min + '" max="' + max + '" step="0.1" id="gere-commerce-achat-' + m + '" placeholder="Nouveau prix" style="flex:1;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.3rem;font-size:.85rem;outline:none"/>';
    html += '<button onclick="confirmerGererPrixAchatCommerceUI(\'' + commerceType + '\',\'' + buildingId + '\',\'' + (roomId || '') + '\',\'' + m + '\')" style="padding:.3rem .6rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer;font-size:.82rem">Valider</button>';
    html += '</div></div>';
  });

  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerGererPrixAchatCommerceUI(commerceType, buildingId, roomId, matiere) {
  const pays = state.country || 'republic';
  const ville = state.currentCity || 'capitale';
  const roomIdReel = roomId || null;
  const valeur = document.getElementById('gere-commerce-achat-' + matiere)?.value;
  const res = await confirmerFixerPrixAchatMatiereCommerce(commerceType, pays, ville, buildingId, roomIdReel, matiere, valeur);
  const label = (typeof RESSOURCES_ECONOMIE !== 'undefined' && RESSOURCES_ECONOMIE[matiere]) ? RESSOURCES_ECONOMIE[matiere].label : matiere;
  if (!res.ok) {
    const messages = {
      introuvable: '',
      reserve_proprietaire: 'Réservé au propriétaire de ce commerce.',
      matiere_non_acceptee: 'Ce commerce n\'achète pas ' + label + '.',
      hors_fourchette: 'Le prix doit être compris entre ' + (res.min != null ? res.min.toFixed(2) : '?') + ' et ' + (res.max != null ? res.max.toFixed(2) : '?') + ' ' + (COUNTRIES[state.country || 'republic']?.cur || 'FR') + '.'
    };
    showToast('Prix d\'achat refusé', messages[res.raison] || '', false);
    return;
  }
  showToast('Prix d\'achat mis à jour', res.prix.toLocaleString('fr-FR') + ' FR.', true, true);
  addJournalEntry('Prix d\'achat ajusté pour ' + label + ' — ' + res.prix.toLocaleString('fr-FR') + ' FR.', 'event-good');
  doGererCommerce(commerceType, buildingId, roomIdReel); // rafraichit, meme pattern que le reste de l'interface
}

async function confirmerGererPrixCommerceUI(commerceType, buildingId, roomId, recetteId) {
  const pays = state.country || 'republic';
  const ville = state.currentCity || 'capitale';
  const roomIdReel = roomId || null;
  const valeur = document.getElementById('gere-commerce-prix-' + recetteId)?.value;
  const res = await confirmerFixerPrixCommerce(commerceType, pays, ville, buildingId, roomIdReel, recetteId, valeur);
  if (!res.ok) {
    const messages = {
      introuvable: 'Produit introuvable.',
      prix_fixe: 'Le prix de ce produit est fixe et ne peut pas être modifié.',
      reserve_proprietaire: 'Réservé au propriétaire de ce commerce.',
      hors_fourchette: 'Le prix doit être compris entre ' + (res.min != null ? res.min.toFixed(2) : '?') + ' et ' + (res.max != null ? res.max.toFixed(2) : '?') + ' ' + (COUNTRIES[state.country || 'republic']?.cur || 'FR') + '.'
    };
    showToast('Prix refusé', messages[res.raison] || '', false);
    return;
  }
  showToast('Prix mis à jour', res.prix.toLocaleString('fr-FR') + ' FR.', true, true);
  addJournalEntry('Prix ajusté pour ' + (RECETTES_ALIMENTAIRES[recetteId]?.label || recetteId) + ' — ' + res.prix.toLocaleString('fr-FR') + ' FR.', 'event-good');
  doGererCommerce(commerceType, buildingId, roomIdReel); // rafraichit, meme pattern que produire/consulter
}

// Production generique : matieres -> PA -> lot -> portions, sur le modele exact de
// confirmerProduction (armurerie) mais parametre par recette au lieu d'un id d'arme fixe.
async function produireRecetteCommerce(commerceType, pays, ville, buildingId, roomId, recetteId) {
  const recette = RECETTES_ALIMENTAIRES[recetteId];
  const data = await chargerCommerce(commerceType, pays, ville, buildingId, roomId);
  if (!recette || !data) return { ok: false, raison: 'introuvable' };
  if (!recetteAutoriseePourCommerce(recette, data)) return { ok: false, raison: 'recette_non_autorisee' };

  const manque = Object.entries(recette.materiaux).find(([m, q]) => (data.stockMatieres[m] || 0) < q);
  if (manque) return { ok: false, raison: 'stock_matiere_insuffisant', matiere: manque[0] };

  // Plafond effectif (lot plafonds, 21 aout 2026) -- corrige au passage un defaut preexistant :
  // l'ancien controle ("stockActuel >= stockMax") ne bloquait qu'une fois le plafond DEJA atteint,
  // jamais une production qui l'aurait depasse (stock 18 + 5 portions = 23 passait avant ce
  // correctif). Compare desormais stock APRES production au plafond, avant toute mutation.
  const stockMax = plafondEffectifCommerce(data, recetteId);
  const stockActuel = data.stockProduits[recetteId] || 0;
  if (stockActuel + recette.portions > stockMax) return { ok: false, raison: 'stock_plein' };

  const coutMainOeuvre = recette.pa * COUT_MAIN_OEUVRE_PA_ALIMENTAIRE;
  // Buvette : aucune caisse autonome (doctrine deja validee/codee pour doConsommerBuvette), y
  // compris cote depense -- le net des ventes va deja a la caisse du stade, la main-d'oeuvre de
  // production en est donc symetriquement tiree, jamais de data.caisse (qui reste a 0 en
  // permanence pour ce type). debiterCaisseBatimentAtomique est tout-ou-rien (contrairement a
  // debiterCaisseBatimentPlafonne qui tolere un versement partiel, inadapte ici : un salaire de
  // production doit etre paye en entier ou pas du tout, comme pour tout autre commerce).
  //
  // Atomicite PA/caisse (Lot 1, correctif suite a revue) -- deduireCoutOrdre() est l'AUTORITE
  // UNIQUE sur la disponibilite des PA (aucune garde manuelle state.pa<...). Les deux branches
  // garantissent : soit PA et ressources sont debites ensemble et la production a lieu, soit
  // rien n'est mute (ni PA, ni caisse, ni stock) :
  //   - buvette : PA et cout main-d'oeuvre geres en UN SEUL appel a deduireCoutOrdre() via
  //     payeur:{type:'institution'}, qui delegue a debiterCaisseBatimentAtomique() en interne
  //     et ne deduit les PA (etape D) qu'apres le succes du debit institutionnel (etape B) --
  //     aucune fenetre entre les deux, contrairement a une lecture prealable separee. Le
  //     raison renvoye par la primitive ('caisse_institution_insuffisante') est remappe vers
  //     'caisse_insuffisante' pour preserver le contrat existant avec l'appelant UI
  //     (doProduireRecetteCommerceUI, qui ne connait que cette valeur).
  //   - commerce standard/restaurant : data.caisse n'est pas geree par
  //     debiterCaisseBatimentAtomique (caisse d'une entreprise, pas d'un batiment) ; verifiee en
  //     lecture seule AVANT deduireCoutOrdre(), puis debitee seulement APRES son succes -- rien
  //     n'est encore persiste a ce stade (sbSaveEntreprise plus bas).
  const categorieCaisseInstitProd = COMMERCE_SANS_CAISSE_AUTONOME[data.type];
  if (categorieCaisseInstitProd && typeof debiterCaisseBatimentAtomique === 'function' && typeof getCaisseLocaleId === 'function') {
    const r = await deduireCoutOrdre({ pa: recette.pa, cost: coutMainOeuvre, payeur: { type: 'institution', pays, buildingId: getCaisseLocaleId(categorieCaisseInstitProd, ville) } });
    if (!r.ok) return { ok: false, raison: r.raison === 'caisse_institution_insuffisante' ? 'caisse_insuffisante' : r.raison };
  } else {
    if (data.caisse < coutMainOeuvre) return { ok: false, raison: 'caisse_insuffisante' };
    const rPa = await deduireCoutOrdre({ pa: recette.pa, cost: 0 });
    if (!rPa.ok) return { ok: false, raison: 'pa_insuffisants' };
    data.caisse -= coutMainOeuvre;
  }

  Object.entries(recette.materiaux).forEach(([m, q]) => { data.stockMatieres[m] -= q; });
  data.stockProduits[recetteId] = stockActuel + recette.portions;

  // Prix auto recalcule a chaque production pour un commerce PNJ (le cout moyen des matieres
  // peut avoir bouge depuis le dernier lot) -- un commerce PJ garde le prix fixe par son
  // proprietaire (confirmerFixerPrixCommerce), jamais ecrase automatiquement ici. Exception
  // ajoutee (lot plafonds/menus fixes, 21 aout 2026) : une recette explicitement declaree
  // recette.prixFixe:true (menus gastronomiques du Republica) ignore ce recalcul, PNJ ou pas --
  // attribut propre a la recette, aucun ID hardcode ici.
  if (data.proprietaire === 'PNJ' && !recette.prixFixe) {
    data.parametres.prixVente[recetteId] = prixVenteAutoPNJ(coutRevientPortionRecette(data, recette));
  }

  ajouterHistoriqueEntreprise(data, -coutMainOeuvre, 'Production de ' + recette.label + ' (' + recette.portions + ' portions) — ' + (state.char?.name || 'Anonyme'));
  await sbSaveEntreprise(data.id, data);

  state.arg = (state.arg || 0) + coutMainOeuvre;
  return { ok: true, portions: recette.portions, salaire: coutMainOeuvre };
}

// Vente/consommation generique : carte -> Commander -> stock-1 -> taxe -> caisse -> effets.
// La buvette de stade n'a pas de caisse autonome (doctrine deja validee/codee pour
// doConsommerBuvette) : son net part directement dans la caisse du stade de sa ville.
async function commanderProduitCommerce(commerceType, pays, ville, buildingId, roomId, recetteId) {
  const recette = RECETTES_ALIMENTAIRES[recetteId];
  const data = await chargerCommerce(commerceType, pays, ville, buildingId, roomId);
  if (!recette || !data) return { ok: false, raison: 'introuvable' };

  const stock = data.stockProduits[recetteId] || 0;
  if (stock <= 0) return { ok: false, raison: 'rupture' };

  // Coherence prix PJ (mini-lot de finition, 17 aout 2026) : le cout moyen des matieres peut
  // avoir evolue depuis que le proprietaire a fixe son prix (confirmerFixerPrixCommerce), le
  // rendant obsolete hors de la fourchette courante. Plutot que de bloquer la vente (le commerce
  // deviendrait invendable sans intervention du proprietaire, potentiellement absent), le prix
  // est ramene proprement dans la fourchette actuelle -- meme regle de calcul que partout
  // ailleurs (fourchettePrixPJ), aucune duplication. Les commerces PNJ ne sont jamais concernes :
  // leur prix est deja recalcule a chaque production (produireRecetteCommerce), toujours a jour.
  if (data.proprietaire !== 'PNJ' && data.parametres.prixVente[recetteId] != null) {
    const { min, max } = fourchettePrixPJ(coutRevientPortionRecette(data, recette));
    const prixActuel = data.parametres.prixVente[recetteId];
    if (prixActuel < min || prixActuel > max) {
      data.parametres.prixVente[recetteId] = Math.round(Math.max(min, Math.min(max, prixActuel)) * 100) / 100;
    }
  }

  const prix = data.parametres.prixVente[recetteId];
  if (prix == null) return { ok: false, raison: 'prix_non_defini' };
  if ((state.arg || 0) < prix) return { ok: false, raison: 'fonds_insuffisants', prix };

  state.arg -= prix;
  data.stockProduits[recetteId] = stock - 1;

  let net = prix;
  if (typeof appliquerTaxeTransaction === 'function') {
    const t = await appliquerTaxeTransaction(prix);
    net = t.net;
  }

  const categorieCaisseInstitVente = COMMERCE_SANS_CAISSE_AUTONOME[data.type];
  if (categorieCaisseInstitVente && typeof getCaisseLocaleId === 'function' && typeof crediterCaisseBatiment === 'function') {
    await crediterCaisseBatiment(pays, getCaisseLocaleId(categorieCaisseInstitVente, ville), net).catch(() => {});
  } else {
    data.caisse = (data.caisse || 0) + net;
  }

  const effets = recette.effets || {};
  if (effets.hp) state.hp = Math.min(100, Math.max(0, (state.hp || 0) + effets.hp));
  if (effets.moral) state.moral = Math.min(100, Math.max(0, (state.moral || 0) + effets.moral));
  if (effets.pop) state.pop = Math.min(100, Math.max(0, (state.pop || 0) + effets.pop));
  if (effets.paDiffere) state.bonusPaProchainDormir = (state.bonusPaProchainDormir || 0) + effets.paDiffere;

  ajouterHistoriqueEntreprise(data, net, 'Vente — ' + recette.label + ' — ' + (state.char?.name || 'Anonyme'));
  await sbSaveEntreprise(data.id, data);

  return { ok: true, prix, net, effets };
}

// Interface "Consulter la carte" -- modele de l'achat d'armes (liste + bouton), sans registre
// ni notion de legalite. Ouvre le PA/cost de l'ordre de salle (browsing), chaque "Commander"
// est ensuite une transaction FR independante (meme principe que confirmerAchatEntrepot :
// un seul PA pour parcourir la salle, chaque ligne a son propre cout).
async function doConsulterCarteCommerce(commerceType, buildingId, roomId, pa, cost) {
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast(r.raison === 'pa_insuffisants' ? 'PA insuffisants' : 'Fonds insuffisants', '', false); return; }

  const pays = state.country || 'republic';
  const ville = state.currentCity || 'capitale';
  const data = await chargerCommerce(commerceType, pays, ville, buildingId, roomId);
  if (!data) { showToast('Indisponible', '', false); return; }

  document.getElementById('postes-modal-title').textContent = 'Carte';
  let html = '<div style="padding:1rem">';
  const carte = data.carte || [];
  const carteValide = carte.filter(id => RECETTES_ALIMENTAIRES[id]);
  if (carteValide.length === 0) {
    html += '<div style="font-size:.9rem;color:#8a8060">Aucun produit disponible pour le moment.</div>';
  }
  carteValide.forEach(id => {
    const recette = RECETTES_ALIMENTAIRES[id];
    const stock = data.stockProduits[id] || 0;
    const prix = data.parametres.prixVente[id];
    const composition = Object.entries(recette.materiaux).map(([m, q]) => q + ' ' + (typeof RESSOURCES_ECONOMIE !== 'undefined' && RESSOURCES_ECONOMIE[m] ? RESSOURCES_ECONOMIE[m].label : m)).join(', ');
    const effetsTxt = Object.entries(recette.effets || {}).map(([k, v]) => (v > 0 ? '+' : '') + v + ' ' + k.toUpperCase()).join(', ');
    const enRupture = stock <= 0;
    html += '<div style="display:flex;gap:.7rem;padding:.6rem;border:1px solid #2a2010;margin-bottom:.5rem;align-items:center;' + (enRupture ? 'opacity:.5' : '') + '">';
    if (recette.image) html += '<img src="' + recette.image + '" style="width:56px;height:56px;object-fit:cover;border-radius:4px;flex-shrink:0" />';
    html += '<div style="flex:1">';
    html += '<b style="font-size:.93rem;color:#c0b090">' + recette.label + '</b><br>';
    html += '<span style="font-size:.82rem;color:#8a8060">' + composition + '</span><br>';
    if (effetsTxt) html += '<span style="font-size:.82rem;color:#6ab858">' + effetsTxt + '</span><br>';
    html += '<span style="font-size:.85rem;color:#C9A84C">' + (prix != null ? prix.toLocaleString('fr-FR') + ' FR' : 'Prix non défini') + ' — Stock : ' + stock + '</span>';
    html += '</div>';
    // Libelle du bouton personnalisable par recette (lot mini-finition marche, 22 aout 2026) --
    // meme pattern deja utilise par prixFixe/buildingsAutorises/villesAutorisees/paysAutorises :
    // un attribut optionnel propre a la recette, jamais un id hardcode ici ni dans
    // commanderProduitCommerce() (logique metier intacte, seul l'intitule change). Absent partout
    // sauf sur 'sandwich' -- comportement inchange pour tous les autres commerces/recettes.
    const libelleAction = recette.labelAction || 'Commander';
    html += enRupture
      ? '<span style="font-size:.8rem;color:#5a5040;flex-shrink:0">Rupture</span>'
      : '<button onclick="doCommanderProduitCommerceUI(\'' + commerceType + '\',\'' + buildingId + '\',\'' + (roomId || '') + '\',\'' + id + '\')" style="flex-shrink:0;padding:.4rem .7rem;border:1px solid #4a8a4a;background:transparent;color:#6ab858;cursor:pointer;font-size:.82rem">' + libelleAction + '</button>';
    html += '</div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// Pont UI <-> logique (commanderProduitCommerce ci-dessus est pure/testable, celle-ci gere
// toasts/journal/rafraichissement, meme separation que confirmerProduction/doProduireArme).
async function doCommanderProduitCommerceUI(commerceType, buildingId, roomId, recetteId) {
  const pays = state.country || 'republic';
  const ville = state.currentCity || 'capitale';
  const recette = RECETTES_ALIMENTAIRES[recetteId];
  const res = await commanderProduitCommerce(commerceType, pays, ville, buildingId, roomId, recetteId);
  if (!res.ok) {
    const messages = { rupture: 'Ce produit est en rupture de stock.', fonds_insuffisants: (res.prix || 0) + ' FR requis.', prix_non_defini: 'Prix non défini pour ce produit.', introuvable: '' };
    showToast('Commande impossible', messages[res.raison] || '', false);
    return;
  }
  updateUI();
  showToast('Commande servie', recette.label + '.', true, true);
  addJournalEntry(recette.label + ' commandé(e) — ' + res.prix + ' FR.', 'event-good');
  // Rafraichit la carte pour permettre d'enchainer sans rouvrir (meme pattern que confirmerProduction/doProduireArme)
  doConsulterCarteCommerce(commerceType, buildingId, roomId, 0, 0);
}

// =====================
// CONSOMMER UNE BOISSON (lot boissons, 20 aout 2026) -- reutilise integralement
// commanderProduitCommerce() (prix/stock/argent/effets, deja fail-closed) : cet ordre n'ajoute
// AUCUNE logique de commande/consommation propre, seulement un ecran de choix filtre sur les
// produits categorie:'boisson' de la carte du commerce (deja generique : n'importe quel
// commerce dont la carte contient des recettes categorie:'boisson' en beneficie, aucun
// buildingId code en dur). Seule difference avec "Consulter la carte" : ferme la fenetre au lieu
// de la rafraichir apres un achat reussi (comportement explicitement demande), et n'affiche que
// les boissons plutot que la carte complete. Gratuit par construction (0 PA/0 cout a l'ouverture
// ET a la confirmation) : aucun appel a deduireCoutOrdre() nulle part dans cette chaine, seul le
// cout financier reste verifie par commanderProduitCommerce() (fonds_insuffisants -> refus net).
function doConsommerBoissonGenerique(pa, cost) {
  const c = resoudreCommerceActuel();
  if (!c) { showToast('Indisponible', '', false); return; }
  doConsommerBoisson(c.type, c.buildingId, c.roomId);
}

// =====================
// SE NOURRIR / REPAS GASTRONOMIQUE (Le Republica, lot finition boucle economique, 21 aout 2026)
// -- special-case appele par doOrder() (plateau-router.js) avant le moteur generique de jet
// (executerOrdreGenerique). PA et fonds du client deja verifies par doOrder() a ce stade (rien
// n'est encore mute) : ne reste qu'a verifier le stock du restaurant, condition supplementaire
// propre a cet ordre. Aucune mutation si rupture -- ni PA, ni argent, ni stock (symetrique a
// produireRecetteCommerce/commanderProduitCommerce : jamais de prestation sans stock disponible,
// jamais de mutation avant la derniere verification).
//
// Choix du plat servi (arbitrage minimal, aucun comportement canonique existant pour une
// consommation a prix/effets fixes independants du plat -- "Consulter la carte"/"Consommer une
// boisson" laissent toujours le joueur choisir explicitement, jamais un choix automatique) :
// premier plat de la carte du commerce (ordre de declaration dans DOTATIONS_COMMERCE_PILOTE) dont
// le stock est > 0. Sans consequence sur le jeu (les effets Sante/Moral restent ceux, inchanges,
// du roll generique existant -- jamais ceux, propres a la recette, de RECETTES_ALIMENTAIRES) : a
// signaler/ajuster si Fred souhaite une autre regle de selection.
//
// Le paiement (120 FR, deduit ensuite par executerOrdreGenerique comme avant ce lot) est traite
// comme une vraie vente de commerce : appliquerTaxeTransaction() puis credit du net a la caisse
// du restaurant -- jamais a une caisse institutionnelle, jamais au joueur -- exactement le meme
// mecanisme que commanderProduitCommerce() ci-dessus, sans le dupliquer.
async function doRepasGastronomiqueGenerique(pa, cost, label, desc, successRate) {
  const c = resoudreCommerceActuel();
  if (!c) { showToast('Indisponible', '', false); return; }
  const pays = state.country || 'republic';
  const ville = state.currentCity || 'capitale';
  const data = await chargerCommerce(c.type, pays, ville, c.buildingId, c.roomId);
  if (!data) { showToast('Indisponible', '', false); return; }

  const recetteId = (data.carte || []).find(id => (data.stockProduits[id] || 0) > 0);
  if (!recetteId) { showToast('Rupture de stock', 'Le restaurant n\'a rien à servir pour l\'instant.', false); return; }

  data.stockProduits[recetteId] -= 1;
  let net = cost;
  if (typeof appliquerTaxeTransaction === 'function') {
    const t = await appliquerTaxeTransaction(cost);
    net = t.net;
  }
  data.caisse = (data.caisse || 0) + net;
  const recette = RECETTES_ALIMENTAIRES[recetteId];
  ajouterHistoriqueEntreprise(data, net, 'Vente — ' + (recette ? recette.label : recetteId) + ' — ' + (state.char?.name || 'Anonyme'));
  await sbSaveEntreprise(data.id, data).catch(() => {});

  executerOrdreGenerique('repas_gastronomique', pa, cost, label, desc, successRate);
}

async function doConsommerBoisson(commerceType, buildingId, roomId) {
  const pays = state.country || 'republic';
  const ville = state.currentCity || 'capitale';
  const data = await chargerCommerce(commerceType, pays, ville, buildingId, roomId);
  if (!data) { showToast('Indisponible', '', false); return; }

  document.getElementById('postes-modal-title').textContent = 'Consommer une boisson';
  let html = '<div style="padding:1rem">';
  const carte = data.carte || [];
  const boissons = carte.filter(id => RECETTES_ALIMENTAIRES[id]?.categorie === 'boisson');
  if (boissons.length === 0) {
    html += '<div style="font-size:.9rem;color:#8a8060">Aucune boisson disponible pour le moment.</div>';
  }
  boissons.forEach(id => {
    const recette = RECETTES_ALIMENTAIRES[id];
    const stock = data.stockProduits[id] || 0;
    const prix = data.parametres.prixVente[id];
    const enRupture = stock <= 0;
    html += '<div style="display:flex;gap:.7rem;padding:.6rem;border:1px solid #2a2010;margin-bottom:.5rem;align-items:center;' + (enRupture ? 'opacity:.5' : '') + '">';
    html += '<div style="flex:1">';
    html += '<b style="font-size:.93rem;color:#c0b090">' + recette.label + '</b><br>';
    html += '<span style="font-size:.85rem;color:#C9A84C">' + (prix != null ? prix.toLocaleString('fr-FR') + ' FR' : 'Prix non défini') + ' — Stock : ' + stock + '</span>';
    html += '</div>';
    html += enRupture
      ? '<span style="font-size:.8rem;color:#5a5040;flex-shrink:0">Rupture</span>'
      : '<button onclick="confirmerConsommerBoissonUI(\'' + commerceType + '\',\'' + buildingId + '\',\'' + (roomId || '') + '\',\'' + id + '\')" style="flex-shrink:0;padding:.4rem .7rem;border:1px solid #4a8a4a;background:transparent;color:#6ab858;cursor:pointer;font-size:.82rem">Commander</button>';
    html += '</div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// Pont UI <-> logique, meme primitive pure que doCommanderProduitCommerceUI (commanderProduitCommerce)
// mais ferme la fenetre au lieu de la rafraichir -- comportement demande specifiquement pour cet
// ordre (retour a la salle apres consommation, pas d'enchainement de commandes).
async function confirmerConsommerBoissonUI(commerceType, buildingId, roomId, recetteId) {
  const pays = state.country || 'republic';
  const ville = state.currentCity || 'capitale';
  const recette = RECETTES_ALIMENTAIRES[recetteId];
  const res = await commanderProduitCommerce(commerceType, pays, ville, buildingId, roomId, recetteId);
  if (!res.ok) {
    const messages = { rupture: 'Cette boisson est en rupture de stock.', fonds_insuffisants: (res.prix || 0) + ' FR requis.', prix_non_defini: 'Prix non défini pour cette boisson.', introuvable: '' };
    showToast('Achat impossible', messages[res.raison] || '', false);
    return;
  }
  document.getElementById('modal-postes')?.classList.remove('open');
  updateUI();
  // Effets affiches derives de res.effets (retourne par commanderProduitCommerce), jamais
  // codes en dur -- reste correct si les effets d'une recette venaient a changer.
  const effetsTxt = Object.entries(res.effets || {}).filter(([, v]) => v).map(([k, v]) => (v > 0 ? '+' : '') + v + ' ' + ({hp:'Santé', moral:'Moral', inf:'INF', pop:'POP'}[k] || k.toUpperCase())).join(' ');
  showToast('Boisson servie', recette.label + (effetsTxt ? ' — ' + effetsTxt : '') + '. -' + res.prix + ' FR.', true, true);
  addJournalEntry(recette.label + ' consommé(e) — ' + res.prix + ' FR.', 'event-good');
}

// =====================
// OFFRIR UNE TOURNEE (lot tournees, 20 aout 2026) -- remplace boire_verre par une mecanique
// generique a cibles multiples (PJ et/ou PNJ), adossee au moteur commerce existant. Reutilise
// integralement chargerCommerce/RECETTES_ALIMENTAIRES/appliquerTaxeTransaction/
// crediterCaisseBatiment/ajouterHistoriqueEntreprise/sbSaveEntreprise (memes primitives que
// commanderProduitCommerce, jamais dupliquees ni bouclees N+1 fois) et appliquerGainENT (meme
// plafond/limite quotidienne que partout ailleurs). Persistance dans les tables "tournees"
// (etat partage : boisson, prix de reference, pa_debite, statut) et invitations_diner.tournee_id
// (une ligne par cible PJ) -- migration_tournees_boissons.sql, deja executee. Etat local
// (state._tourneeModalOuvert) sert uniquement a eviter d'ouvrir deux fois la meme modale de
// reponse, jamais source de verite sur l'existence/l'etat d'une tournee (toujours relu en base).
//
// Portee de ce lot (decision explicite de Fred, 20 aout 2026) : uniquement le Cafe de la Gare de
// Montrouge. L'ancien boire_verre de l'Hotel-Restaurant de Luthecia (bar, hotel-republica) reste
// INCHANGE -- ce batiment n'a aucun commerce (carte/stock/prix) adosse au moteur generique
// (BUILDING_COMMERCE_TYPE ne le liste pas), en construire un est hors perimetre de ce lot. Un lot
// dedie ulterieur ("raccordement bars/cafes/restaurants/buvettes de Republia au moteur commerce
// generique") branchera les etablissements restants, y compris celui-la, sans toucher au moteur
// tournee lui-meme (deja generique par construction : aucun buildingId code en dur ci-dessous).
// =====================

// Etape 1/3 : choix de la boisson (carte reelle du commerce, categorie:'boisson' uniquement --
// jamais d'id code en dur). Meme structure que doConsommerBoisson, un "Choisir" menant a l'etape
// suivante plutot qu'a une consommation immediate.
function doOffrirTourneeGenerique(pa, cost) {
  const c = resoudreCommerceActuel();
  if (!c) { showToast('Indisponible', '', false); return; }
  ouvrirModalOffrirTourneeBoisson(c.type, c.buildingId, c.roomId);
}

async function ouvrirModalOffrirTourneeBoisson(commerceType, buildingId, roomId) {
  const pays = state.country || 'republic';
  const ville = state.currentCity || 'capitale';
  const data = await chargerCommerce(commerceType, pays, ville, buildingId, roomId);
  if (!data) { showToast('Indisponible', '', false); return; }

  document.getElementById('postes-modal-title').textContent = '🍷 Offrir une tournée';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.82rem;color:#8a8060;margin-bottom:.7rem">Choisissez la boisson offerte à toute la tournée. Une seule boisson pour l\'ensemble des invités.</div>';
  const carte = data.carte || [];
  const boissons = carte.filter(id => RECETTES_ALIMENTAIRES[id]?.categorie === 'boisson');
  if (boissons.length === 0) {
    html += '<div style="font-size:.9rem;color:#8a8060">Aucune boisson disponible pour le moment.</div>';
  }
  boissons.forEach(id => {
    const recette = RECETTES_ALIMENTAIRES[id];
    const stock = data.stockProduits[id] || 0;
    const prix = data.parametres.prixVente[id];
    const enRupture = stock <= 0;
    html += '<div style="display:flex;gap:.7rem;padding:.6rem;border:1px solid #2a2010;margin-bottom:.5rem;align-items:center;' + (enRupture ? 'opacity:.5' : '') + '">';
    html += '<div style="flex:1">';
    html += '<b style="font-size:.93rem;color:#c0b090">' + recette.label + '</b><br>';
    html += '<span style="font-size:.85rem;color:#C9A84C">' + (prix != null ? prix.toLocaleString('fr-FR') + ' FR/pers.' : 'Prix non défini') + ' — Stock : ' + stock + '</span>';
    html += '</div>';
    html += enRupture
      ? '<span style="font-size:.8rem;color:#5a5040;flex-shrink:0">Rupture</span>'
      : '<button onclick="ouvrirModalOffrirTourneeCibles(\'' + commerceType + '\',\'' + buildingId + '\',\'' + (roomId || '') + '\',\'' + id + '\')" style="flex-shrink:0;padding:.4rem .7rem;border:1px solid #4a8a4a;background:transparent;color:#6ab858;cursor:pointer;font-size:.82rem">Choisir</button>';
    html += '</div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// Etape 2/3 : selection multiple des cibles (PJ presents, PNJ presents, PNJ du groupe -- memes 3
// sources qu'ouvrirModalInvitationSociale, plateau-pnj.js) + precontroles de lancement en lecture
// seule (section 4 du cahier des charges) : la selection proposee est plafonnee par le pire cas
// (M+1 boissons, tout le monde accepte), jamais une reservation -- argent/stock sont entierement
// relus a la resolution (resoudreTournee ci-dessous), independamment de ce qui est calcule ici.
async function ouvrirModalOffrirTourneeCibles(commerceType, buildingId, roomId, recetteId) {
  const pays = state.country || 'republic';
  const ville = state.currentCity || 'capitale';
  const data = await chargerCommerce(commerceType, pays, ville, buildingId, roomId);
  const recette = RECETTES_ALIMENTAIRES[recetteId];
  if (!data || !recette) { showToast('Indisponible', '', false); return; }
  const stock = data.stockProduits[recetteId] || 0;
  const prix = data.parametres.prixVente[recetteId];
  if (prix == null) { showToast('Prix non défini', '', false); return; }

  const presentsPJ = (window._vraisJoueursPresents || []).filter(p => p.name !== state.char?.name).map(p => ({ name: p.name, kind: 'pj', rel: '' }));
  const roomActuelle = BUILDINGS[buildingId]?.rooms?.[roomId];
  const presentsPNJ = (roomActuelle?.persons || []).filter(p => !p.isPJ).map(p => ({ name: p.name.replace(' (PNJ)', ''), kind: 'pnj', rel: p.rel || 'neutral' }));
  const monGroupePNJ = typeof getMonGroupePNJ === 'function' ? getMonGroupePNJ() : [];
  const presentsMonGroupe = monGroupePNJ
    .filter(g => !presentsPNJ.some(pp => pp.name === g.nom))
    .map(g => ({ name: g.nom, kind: 'groupe', rel: '' }));
  const presents = [...presentsPJ, ...presentsPNJ, ...presentsMonGroupe];

  if (presents.length === 0) {
    showToast('Personne à inviter', 'Aucun autre joueur ou PNJ n\'est présent dans cette pièce pour l\'instant.', false);
    return;
  }

  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const maxParStock = Math.max(0, stock - 1);
  const maxParArgent = Math.max(0, Math.floor((state.arg || 0) / prix) - 1);
  const maxSelectable = Math.min(presents.length, maxParStock, maxParArgent);

  document.getElementById('postes-modal-title').textContent = '🍷 Offrir une tournée — ' + recette.label;
  let html = '<div style="padding:.8rem 1rem">';
  if (maxSelectable <= 0) {
    html += '<div style="font-size:.88rem;color:#cc6644;font-style:italic">Vous ne pouvez inviter personne pour l\'instant : il faut au moins ' + (2 * prix).toLocaleString('fr-FR') + ' ' + cur + ' et 2 ' + recette.label + ' en stock (vous compris) pour lancer une tournée.</div>';
    html += '</div>';
    document.getElementById('postes-body').innerHTML = html;
    document.getElementById('modal-postes').classList.add('open');
    return;
  }
  html += '<div style="font-size:.82rem;color:#8a8060;margin-bottom:.7rem">' + prix.toLocaleString('fr-FR') + ' ' + cur + ' par personne (vous compris), à votre charge. Le coût réel n\'est prélevé qu\'à la fin, uniquement pour ceux qui auront réellement accepté. Sélectionnez jusqu\'à ' + maxSelectable + ' invité(s).</div>';
  html += '<div style="display:flex;flex-direction:column;gap:.4rem;margin-bottom:.8rem">';
  presents.forEach(p => {
    html += '<label style="display:flex;align-items:center;gap:.5rem;font-size:.9rem;color:#c0b090"><input type="checkbox" class="tournee-cible" value="' + p.name.replace(/"/g, '') + '|' + p.kind + '|' + p.rel + '"/> ' + p.name + (p.kind !== 'pj' ? ' <span style="color:#5a4a30;font-size:.8rem">(PNJ)</span>' : '') + '</label>';
  });
  html += '</div>';
  html += '<button onclick="confirmerOffrirTourneeUI(\'' + commerceType + '\',\'' + buildingId + '\',\'' + (roomId || '') + '\',\'' + recetteId + '\',' + maxSelectable + ')" style="width:100%;font-family:\'Bebas Neue\',sans-serif;font-size:.9rem;letter-spacing:.1em;padding:.55rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">OFFRIR LA TOURNÉE</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// Etape 3/3 : lancement. Precontrole final (relu, pas celui fige a l'ouverture de la modale) puis
// creation persistante (tournees + invitations_diner.tournee_id pour les cibles PJ). Les PNJ sont
// resolus immediatement (memes probabilites que l'ancien systeme : 95% groupe, 85/60/20 selon
// rel allie/neutre/ennemi) et figes dans pnj_resultats -- AUCUN bonus ni paiement a cet instant,
// pour eux comme pour les PJ (correction obligatoire de l'asymetrie de l'ancien systeme : les
// effets n'arrivent qu'a la resolution reussie, cf. resoudreTournee).
async function confirmerOffrirTourneeUI(commerceType, buildingId, roomId, recetteId, maxSelectable) {
  const cibles = Array.from(document.querySelectorAll('.tournee-cible:checked')).map(el => {
    const [name, kind, rel] = el.value.split('|');
    return { name, kind, rel };
  });
  if (cibles.length === 0) { showToast('Aucune cible sélectionnée', 'Sélectionnez au moins une personne à inviter.', false); return; }
  if (cibles.length > maxSelectable) {
    showToast('Sélection trop large', 'Vous ne pouvez inviter que ' + maxSelectable + ' personne(s) au maximum pour l\'instant (fonds/stock).', false);
    return;
  }

  const pays = state.country || 'republic';
  const ville = state.currentCity || 'capitale';
  const data = await chargerCommerce(commerceType, pays, ville, buildingId, roomId);
  const recette = RECETTES_ALIMENTAIRES[recetteId];
  if (!data || !recette) { showToast('Indisponible', '', false); return; }
  const stock = data.stockProduits[recetteId] || 0;
  const prix = data.parametres.prixVente[recetteId];
  if (prix == null) { showToast('Prix non défini', '', false); return; }

  const M = cibles.length;
  const besoinArgent = (M + 1) * prix;
  const besoinStock = M + 1;
  if ((state.arg || 0) < besoinArgent) {
    showToast('Fonds insuffisants', besoinArgent.toLocaleString('fr-FR') + ' FR nécessaires au maximum (si tout le monde accepte).', false);
    return;
  }
  if (stock < besoinStock) {
    showToast('Stock insuffisant', besoinStock + ' ' + recette.label + ' nécessaires au maximum, ' + stock + ' en stock.', false);
    return;
  }

  document.getElementById('modal-postes')?.classList.remove('open');

  const pnjResultats = cibles.filter(c => c.kind !== 'pj').map(c => {
    const chance = c.kind === 'groupe' ? 95 : (c.rel === 'ally' ? 85 : c.rel === 'enemy' ? 20 : 60);
    const roll = Math.floor(Math.random() * 100) + 1;
    return { nom: c.name, accepte: roll <= chance };
  });
  const ciblesPJ = cibles.filter(c => c.kind === 'pj');

  const tourneeId = 'tournee-' + Date.now() + '-' + Math.floor(Math.random() * 1000);
  const expiresAt = new Date(Date.now() + 5 * 60 * 1000).toISOString();

  if (typeof sbCreerTournee !== 'function') { showToast('Indisponible', '', false); return; }
  const tourneeCreee = await sbCreerTournee({
    id: tourneeId,
    country: pays,
    ville,
    offreur: state.char?.name,
    building_id: buildingId,
    room_id: roomId || null,
    commerce_type: commerceType,
    recette_id: recetteId,
    prix_unitaire_reference: prix,
    pnj_resultats: pnjResultats,
    statut: 'en_attente',
    pa_debite: false,
    expires_at: expiresAt
  }).catch(() => null);

  if (!tourneeCreee) {
    showToast('Erreur', 'Impossible de créer la tournée pour l\'instant. Réessayez.', false);
    return;
  }

  if (ciblesPJ.length > 0 && typeof sbCreerInvitationsTournee === 'function') {
    await sbCreerInvitationsTournee(ciblesPJ.map(c => ({
      inviteur: state.char?.name, invite: c.name, country: pays, city: ville,
      building_id: buildingId, room_id: roomId || null,
      statut: 'attente', cout: prix, type: 'tournee_boisson', tournee_id: tourneeId
    }))).catch(() => {});
  }

  showToast('Tournée lancée', 'En attente de la réponse de vos invités (5 min maximum)...', true);
  addJournalEntry('Tournée offerte (' + recette.label + ') à ' + M + ' personne(s).', 'event-info');

  // Si aucune cible PJ (donc rien a attendre, les PNJ sont deja tous resolus), tenter une
  // resolution immediate plutot que d'attendre le prochain tick de polling (confort, pas une
  // dependance : le polling periodique la resoudrait de toute facon dans les secondes suivantes).
  if (ciblesPJ.length === 0 && typeof verifierTourneesActivesOffreur === 'function') {
    verifierTourneesActivesOffreur();
  }
}

// Credit MORAL/ENT d'un invite ayant reellement accepte (section 13). Meme niveau de fiabilite
// que le seul precedent existant de mutation cross-joueur (debiterCitoyenPlafonne,
// plateau-politique.js:3841) : lecture puis ecriture non atomiques, dette transactionnelle
// acceptee explicitement par Fred pour ce lot (aucune RPC ajoutee). ENT reutilise le plafond dur
// de appliquerGainENT (20) mais PAS sa limite "une fois par jour" -- cette derniere repose sur
// state.char.dernierGainENTJour, un champ jamais persiste cote serveur (absent de
// sbSavePersonnage/sbLoadPersonnage, verifie) : il n'existe donc aucune donnee fiable a lire pour
// l'appliquer a un joueur distant. Seul le plafond dur (verifiable via stats.ENT, reellement
// persiste) est donc applique ici.
async function crediterTourneeInviteAcceptant(nomCible) {
  if (typeof sbGet !== 'function' || typeof sbUpdate !== 'function') return;
  const rows = await sbGet('personnages', `name=eq.${encodeURIComponent(nomCible)}&select=moral,stats`).catch(() => []);
  const row = rows?.[0];
  if (!row) return;
  const moralActuel = row.moral ?? 75;
  const stats = row.stats || {};
  const entActuel = stats.ENT || 0;
  const nouveauStats = entActuel < 20 ? { ...stats, ENT: Math.min(20, entActuel + 1) } : stats;
  await sbUpdate('personnages', `name=eq.${encodeURIComponent(nomCible)}`, {
    moral: Math.min(100, moralActuel + 2),
    stats: nouveauStats
  }).catch(() => {});
}

// Resolution tout-ou-rien (section 10) d'une tournee deja claim (statut en_resolution, voir
// verifierTourneesActivesOffreur ci-dessous qui seul appelle cette fonction, uniquement pour ses
// PROPRES tournees -- offreur === state.char.name garanti par construction de l'appelant, jamais
// revérifié ici). Relit systematiquement stock/prix/argent avant toute mutation, y compris lors
// d'une reprise apres crash (pa_debite=true) : le plafond calcule au lancement n'est jamais
// reutilise tel quel.
async function resoudreTournee(tournee) {
  const invitationsPJ = await sbGetInvitationsTournee(tournee.id);
  const pjAcceptants = invitationsPJ.filter(r => r.statut === 'acceptee');
  const pnjAcceptants = (tournee.pnj_resultats || []).filter(p => p.accepte);
  const N = pjAcceptants.length + pnjAcceptants.length;

  async function nettoyerInvitations() {
    for (const row of invitationsPJ) { await sbSupprimerInvitationDiner(row.id).catch(() => {}); }
  }

  const estMoi = tournee.offreur === state.char?.name;

  if (N === 0) {
    await nettoyerInvitations();
    await sbMarquerTourneeResolue(tournee.id, tournee.pa_debite === true);
    if (estMoi) {
      showToast('Tournée déclinée', 'Personne n\'a accepté votre offre.', false);
      addJournalEntry('Tournée proposée : personne n\'a accepté.', 'event-info');
    }
    return;
  }

  const recette = RECETTES_ALIMENTAIRES[tournee.recette_id];
  const data = await chargerCommerce(tournee.commerce_type, tournee.country, tournee.ville, tournee.building_id, tournee.room_id);
  const quantite = N + 1;
  const stockActuel = data ? (data.stockProduits[tournee.recette_id] || 0) : 0;
  const prixReel = data ? data.parametres.prixVente[tournee.recette_id] : null;
  const argentDispo = estMoi ? (state.arg || 0) : 0;

  // Echec total (section 10) : une seule ressource manquante suffit, aucun service partiel.
  if (!data || !recette || prixReel == null || stockActuel < quantite || argentDispo < prixReel * quantite) {
    await nettoyerInvitations();
    await sbMarquerTourneeResolue(tournee.id, tournee.pa_debite === true);
    if (estMoi) {
      showToast('Tournée annulée', 'Les ressources nécessaires ne sont plus réunies au moment de servir la tournée.', false);
      addJournalEntry('Tournée annulée à la résolution : stock, prix ou fonds insuffisants.', 'event-bad');
      updateUI();
    }
    return;
  }

  const montantTotal = prixReel * quantite;

  // PA (section 11) : 1 PA unique, quel que soit N. pa_debite ne sert jamais de verrou prealable
  // -- il ne passe a true qu'apres le succes reel de deduireCoutOrdre(), et permet ici de sauter
  // ce debit lors d'une reprise (le PA a deja ete preleve lors d'une tentative anterieure).
  if (!tournee.pa_debite) {
    const r = await deduireCoutOrdre({ pa: 1, cost: 0 });
    if (!r.ok) {
      await nettoyerInvitations();
      await sbMarquerTourneeResolue(tournee.id, false);
      if (estMoi) {
        showToast('Tournée annulée', 'Plus assez de PA pour offrir la tournée.', false);
        addJournalEntry('Tournée annulée à la résolution : PA insuffisants.', 'event-bad');
        updateUI();
      }
      return;
    }
    await sbMarquerTourneePaDebite(tournee.id).catch(() => {});
  }

  // Flux financier/stock (section 12) : memes primitives que commanderProduitCommerce, appliquees
  // UNE FOIS pour la quantite agregee (jamais une boucle N+1 fois, qui multiplierait a tort les
  // effets de la recette). La caisse du commerce est toujours CREDITEE (jamais debitee) : c'est
  // l'argent personnel de l'offreur qui paie, exactement comme une vente normale.
  state.arg -= montantTotal;
  data.stockProduits[tournee.recette_id] = stockActuel - quantite;
  let net = montantTotal;
  if (typeof appliquerTaxeTransaction === 'function') {
    const t = await appliquerTaxeTransaction(montantTotal);
    net = t.net;
  }
  const categorieCaisseInstitTournee = COMMERCE_SANS_CAISSE_AUTONOME[data.type];
  if (categorieCaisseInstitTournee && typeof getCaisseLocaleId === 'function' && typeof crediterCaisseBatiment === 'function') {
    await crediterCaisseBatiment(tournee.country, getCaisseLocaleId(categorieCaisseInstitTournee, tournee.ville), net).catch(() => {});
  } else {
    data.caisse = (data.caisse || 0) + net;
  }
  ajouterHistoriqueEntreprise(data, net, 'Tournée offerte — ' + recette.label + ' x' + quantite + ' — ' + (tournee.offreur || 'Anonyme'));
  await sbSaveEntreprise(data.id, data);

  // Effets (section 13) : offreur une seule fois, chaque invite PJ ayant reellement accepte de
  // meme -- jamais les PNJ (aucun personnage persiste a crediter). Traitement PUIS suppression de
  // chaque ligne d'invitation (et non une boucle de credit separee de la suppression) : c'est ce
  // qui rend une reprise apres crash idempotente sans colonne de suivi supplementaire -- une ligne
  // deja supprimee ne peut plus jamais etre recreditee lors d'une reprise ulterieure.
  state.moral = Math.min(100, (state.moral || 0) + 2);
  if (typeof appliquerGainENT === 'function') appliquerGainENT(1);

  for (const row of invitationsPJ) {
    if (row.statut === 'acceptee') await crediterTourneeInviteAcceptant(row.invite);
    await sbSupprimerInvitationDiner(row.id).catch(() => {});
  }

  await sbMarquerTourneeResolue(tournee.id, true);
  if (typeof sbSavePersonnage === 'function') await sbSavePersonnage(state).catch(() => {});
  updateUI();
  showToast('Tournée servie !', quantite + ' ' + recette.label + ' servi(e)s. -' + montantTotal.toLocaleString('fr-FR') + ' FR. +2 Moral +1 ENT.', true, true);
  addJournalEntry('Tournée offerte (' + recette.label + ') : ' + N + ' invité(s) sur ' + (invitationsPJ.length + (tournee.pnj_resultats || []).length) + ' ont accepté. -' + montantTotal + ' FR. +2 Moral +1 ENT.', 'event-good');
}

// Polling offreur (section 9) : retrouve les tournees encore actives EN BASE (jamais via un
// state local, qui ne survivrait pas a un refresh) et tente une resolution des qu'elle est prete
// -- soit tous les PJ ont repondu, soit expires_at est depasse. Machine a etats a claim
// conditionnel (PATCH PostgREST ?id=eq.X&statut=eq.en_attente) : un tableau vide en retour
// signifie qu'un autre onglet/appareil a deja pris la main, on passe simplement au suivant.
async function verifierTourneesActivesOffreur() {
  if (!state.char?.name || typeof sbGetTourneesActivesOffreur !== 'function') return;
  if (window._tourneeResolutionEnCours) return;
  let tournees = [];
  try { tournees = await sbGetTourneesActivesOffreur(state.char.name); } catch (e) { return; }

  for (const t of tournees) {
    if (t.statut === 'en_attente') {
      const invitationsPJ = await sbGetInvitationsTournee(t.id).catch(() => []);
      const expiree = t.expires_at && new Date(t.expires_at).getTime() <= Date.now();
      const tousRepondu = invitationsPJ.every(r => r.statut !== 'attente');
      if (!expiree && !tousRepondu) continue;
      const claim = await sbClaimResolutionTournee(t.id);
      if (!claim || claim.length === 0) continue;
      window._tourneeResolutionEnCours = true;
      try { await resoudreTournee(claim[0]); } finally { window._tourneeResolutionEnCours = false; }
    } else if (t.statut === 'en_resolution') {
      const debutMs = t.resolution_started_at ? new Date(t.resolution_started_at).getTime() : 0;
      if (Date.now() - debutMs < 30000) continue; // pas encore perime, laisser sa chance au claimant en cours
      const seuilIso = new Date(Date.now() - 30000).toISOString();
      const reclaim = await sbReclaimResolutionTourneeExpiree(t.id, seuilIso);
      if (!reclaim || reclaim.length === 0) continue;
      window._tourneeResolutionEnCours = true;
      try { await resoudreTournee(reclaim[0]); } finally { window._tourneeResolutionEnCours = false; }
    }
  }
}

// Polling invite (section 7) : ecran de reponse dedie a la tournee, distinct de l'ancien
// verifierInvitationsSocialesRecues (qui l'ignore desormais, cf. sbGetInvitationsDinerRecues).
// Reponse via sbRepondreInvitationDiner (meme primitive que l'ancien systeme, aucune duplication)
// -- AUCUN effet applique ici, ni pour un "oui" ni pour un "non" : c'est la correction obligatoire
// de l'asymetrie de l'ancien systeme, les bonus n'arrivent qu'a la resolution par l'offreur.
async function verifierTourneesRecues() {
  if (!state.char?.name || typeof sbGetInvitationsTourneeRecues !== 'function') return;
  if (state._tourneeModalOuvert) return;
  let rows = [];
  try { rows = await sbGetInvitationsTourneeRecues(state.char.name); } catch (e) { return; }
  if (!rows || rows.length === 0) return;
  const invitation = rows[0];
  const tournee = typeof sbGetTournee === 'function' ? await sbGetTournee(invitation.tournee_id).catch(() => null) : null;
  if (!tournee) return;
  const recette = RECETTES_ALIMENTAIRES[tournee.recette_id];

  state._tourneeModalOuvert = true;
  document.getElementById('postes-modal-title').textContent = '🍷 Tournée offerte';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1.2rem">' +
    '<div style="font-size:.85rem;color:#c0b090;margin-bottom:1rem">' + tournee.offreur + ' vous offre une tournée (' + (recette?.label || 'boisson') + '), à ses frais.</div>' +
    '<div style="display:flex;gap:.5rem">' +
      '<button onclick="repondreTournee(' + invitation.id + ',true)" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.5rem;border:1px solid #4a8a4a;background:transparent;color:#6a9a6a;cursor:pointer">✅ Accepter</button>' +
      '<button onclick="repondreTournee(' + invitation.id + ',false)" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.5rem;border:1px solid #5a2a2a;background:transparent;color:#8a3a2a;cursor:pointer">❌ Refuser</button>' +
    '</div></div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function repondreTournee(id, accepte) {
  document.getElementById('modal-postes')?.classList.remove('open');
  state._tourneeModalOuvert = false;
  if (typeof sbRepondreInvitationDiner === 'function') await sbRepondreInvitationDiner(id, accepte, null).catch(() => {});
  showToast(
    accepte ? 'Invitation acceptée' : 'Invitation déclinée',
    accepte ? 'Vous rejoignez la tournée. Elle sera servie une fois que tout le monde aura répondu (ou à expiration).' : 'Vous avez décliné la tournée.',
    accepte, false
  );
  addJournalEntry(accepte ? 'Vous avez accepté une tournée offerte.' : 'Vous avez décliné une tournée offerte.', accepte ? 'event-good' : 'event-info');
}

// Interface "Produire" -- meme modele que doProduireArme (armurerie), restreinte aux recettes
// de la carte du commerce (l'exploitant ne produit que ce qu'il vend, v1 du moteur).
async function doProduireRecetteCommerce(commerceType, buildingId, roomId, pa, cost) {
  const pays = state.country || 'republic';
  const ville = state.currentCity || 'capitale';
  const data = await chargerCommerce(commerceType, pays, ville, buildingId, roomId);
  if (!data) { showToast('Indisponible', '', false); return; }

  const recettesDispo = (data.carte || []).filter(id => recetteAutoriseePourCommerce(RECETTES_ALIMENTAIRES[id], data));

  document.getElementById('postes-modal-title').textContent = 'Produire';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.82rem;color:#8a8060;margin-bottom:.7rem">Main-d\'œuvre : ' + COUT_MAIN_OEUVRE_PA_ALIMENTAIRE + ' FR par PA travaillé.</div>';
  if (recettesDispo.length === 0) {
    html += '<div style="font-size:.9rem;color:#8a8060">Aucune recette disponible sur la carte de cet établissement.</div>';
  }
  recettesDispo.forEach(id => {
    const recette = RECETTES_ALIMENTAIRES[id];
    const materiauxTxt = Object.entries(recette.materiaux).map(([m, q]) => q + ' ' + (typeof RESSOURCES_ECONOMIE !== 'undefined' && RESSOURCES_ECONOMIE[m] ? RESSOURCES_ECONOMIE[m].label : m)).join(', ');
    const stockActuel = data.stockProduits[id] || 0;
    const stockMax = plafondEffectifCommerce(data, id);
    // Bouton PRODUIRE explicite (lot boissons, 20 aout 2026) -- la fiche recette redevient une
    // simple fiche informative (div, plus cliquable en elle-meme), l'action est desormais un
    // vrai bouton distinct. Meme handler qu'avant, doProduireRecetteCommerceUI(), aucune logique
    // dupliquee -- generique, s'applique a tous les commerces utilisant cette fenetre, pas
    // seulement le Cafe de la Gare.
    html += '<div style="margin-bottom:.5rem;padding:.6rem .7rem;border:1px solid #2a2010;background:transparent;color:#c0b090;font-size:.88rem">';
    html += '<b>' + recette.label + '</b> — ' + recette.pa + ' PA → ' + recette.portions + ' portions<br>';
    html += '<span style="color:#8a8060">Matériaux : ' + materiauxTxt + ' · Salaire : ' + (recette.pa * COUT_MAIN_OEUVRE_PA_ALIMENTAIRE) + ' FR · Stock : ' + stockActuel + (stockMax != null ? '/' + stockMax : '') + '</span><br>';
    html += '<button onclick="doProduireRecetteCommerceUI(\'' + commerceType + '\',\'' + buildingId + '\',\'' + (roomId || '') + '\',\'' + id + '\')" style="margin-top:.5rem;padding:.4rem 1rem;border:1px solid #4a8a4a;background:transparent;color:#6ab858;cursor:pointer;font-size:.82rem;font-family:\'Bebas Neue\',sans-serif;letter-spacing:.08em">PRODUIRE</button>';
    html += '</div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function doProduireRecetteCommerceUI(commerceType, buildingId, roomId, recetteId) {
  const pays = state.country || 'republic';
  const ville = state.currentCity || 'capitale';
  const recette = RECETTES_ALIMENTAIRES[recetteId];
  // Pas de garde PA manuelle ici (trouve en verification post-Lot 1 : ce wrapper bloquait
  // l'action a tort meme sous TEST_MODE=true, en amont de produireRecetteCommerce() qui est
  // elle-meme deja fail-closed via deduireCoutOrdre()). La raison 'pa_insuffisants' est deja
  // geree ci-dessous par le mapping `messages`.
  const res = await produireRecetteCommerce(commerceType, pays, ville, buildingId, roomId, recetteId);
  if (!res.ok) {
    const messages = {
      recette_non_autorisee: 'Cette recette n\'est pas autorisée pour cet établissement.',
      pa_insuffisants: recette.pa + ' PA requis.',
      stock_matiere_insuffisant: 'Il manque du ' + (typeof RESSOURCES_ECONOMIE !== 'undefined' && RESSOURCES_ECONOMIE[res.matiere] ? RESSOURCES_ECONOMIE[res.matiere].label : res.matiere) + ' en stock.',
      caisse_insuffisante: 'L\'établissement ne peut pas payer ce travail actuellement.',
      stock_plein: 'Le stock maximum de ce produit est atteint.',
      introuvable: ''
    };
    showToast('Production impossible', messages[res.raison] || '', false);
    document.getElementById('modal-postes')?.classList.remove('open');
    return;
  }

  updateUI();
  showToast('Production réussie !', recette.label + ' — ' + res.portions + ' portions. +' + res.salaire + ' FR de salaire.', true, true);
  addJournalEntry('Production de ' + recette.label + ' (' + res.portions + ' portions) à ' + (BUILDINGS[buildingId]?.name || buildingId) + '.', 'event-good');
  // Ne ferme pas le modal : rafraichit pour enchainer (meme pattern que confirmerProduction/doProduireArme)
  doProduireRecetteCommerce(commerceType, buildingId, roomId, 0, 0);
}

async function chargerArmurerieLocale() {
  const pays = state.country || 'republic';
  const ville = state.currentCity || 'capitale';
  return chargerEntrepriseParId(getEntrepriseIdArmurerie(pays, ville), pays, ville);
}

function ajouterHistoriqueEntreprise(data, montant, motif) {
  data.historique = data.historique || [];
  data.historique.push({ jour: state.day || 1, montant, motif });
  if (data.historique.length > 50) data.historique = data.historique.slice(-50);
}

// Main d'oeuvre de production (9 aout 2026, pilote sur l'armurerie) : tarif plat, identique
// pour toutes les recettes, pas de distinction qualifie/non-qualifie sur ce batiment (le
// travail qualifie est un sujet a part, pas applique ici). Remplace l'ancien systeme UT
// (recette.ut * PA_PAR_UT en cout, recette.ut * tarifHoraire reglable en salaire) - recette.ut
// reste utilise ailleurs (palier de prix de vente / stock max), juste plus pour le travail.
const PA_PRODUCTION_ARMURERIE = 2;
const SALAIRE_PRODUCTION_ARMURERIE = 100; // 2 PA x 50 FR/PA

async function doProduireArme() {
  const data = await chargerArmurerieLocale();
  if (!data) { showToast('Indisponible', '', false); return; }

  document.getElementById('postes-modal-title').textContent = 'Produire une arme';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.72rem;color:#8a8060;margin-bottom:.7rem">Salaire fixe : ' + SALAIRE_PRODUCTION_ARMURERIE + ' FR par arme (' + PA_PRODUCTION_ARMURERIE + ' PA), quel que soit le modèle.</div>';
  Object.entries(getRecettesPays(state.country || 'republic')).forEach(([id, r]) => {
    const materiauxTxt = Object.entries(r.materiaux).map(([m, q]) => q + ' ' + m).join(', ');
    const stockActuel = data.stockProduits[id] || 0;
    const stockMax = data.parametres.stockMax[id] || 0;
    html += '<button onclick="confirmerProduction(\'' + id + '\')" style="display:block;width:100%;text-align:left;margin-bottom:.5rem;padding:.6rem .7rem;border:1px solid #2a2010;background:transparent;color:#c0b090;cursor:pointer;font-size:.78rem">';
    html += '<b>' + r.label + '</b> — ' + PA_PRODUCTION_ARMURERIE + ' PA<br>';
    html += '<span style="color:#8a8060">Matériaux : ' + materiauxTxt + ' · Salaire : ' + SALAIRE_PRODUCTION_ARMURERIE + ' FR · Stock : ' + stockActuel + '/' + stockMax + '</span>';
    html += '</button>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerProduction(produitId) {
  const recette = RECETTES_PRODUCTION[produitId];
  const data = await chargerArmurerieLocale();
  if (!recette || !data) { document.getElementById('modal-postes')?.classList.remove('open'); return; }

  const manque = Object.entries(recette.materiaux).find(([m, q]) => (data.stockMatieres[m] || 0) < q);
  if (manque) { showToast('Stock de matière insuffisant', 'Il manque du ' + manque[0] + ' en stock.', false); document.getElementById('modal-postes')?.classList.remove('open'); return; }

  if (data.caisse < SALAIRE_PRODUCTION_ARMURERIE) { showToast('Caisse insuffisante', 'L\'entreprise ne peut pas payer ce travail actuellement.', false); document.getElementById('modal-postes')?.classList.remove('open'); return; }

  const stockActuel = data.stockProduits[produitId] || 0;
  const stockMax = data.parametres.stockMax[produitId] || 0;
  if (stockActuel >= stockMax) { showToast('Stock plein', 'Le stock maximum de ce produit est atteint.', false); document.getElementById('modal-postes')?.classList.remove('open'); return; }

  // Deduction PA centralisee (Lot 1, correctif suite a revue) -- deduireCoutOrdre() est
  // desormais l'AUTORITE UNIQUE sur la disponibilite des PA (plus de garde manuelle
  // state.pa<... redondante, qui bloquait a tort meme sous TEST_MODE=true). Appelee ICI, AVANT
  // toute mutation de stock/caisse et avant l'ecriture Supabase : fail-closed. cost:0 car le
  // salaire est un GAIN (state.arg += plus bas), pas un cout modelise par deduireCoutOrdre.
  const rPa = await deduireCoutOrdre({ pa: PA_PRODUCTION_ARMURERIE, cost: 0 });
  if (!rPa.ok) { showToast('PA insuffisants', PA_PRODUCTION_ARMURERIE + ' PA requis.', false); document.getElementById('modal-postes')?.classList.remove('open'); return; }

  // Consommer
  Object.entries(recette.materiaux).forEach(([m, q]) => { data.stockMatieres[m] -= q; });
  data.stockProduits[produitId] = stockActuel + 1;
  data.caisse -= SALAIRE_PRODUCTION_ARMURERIE;
  ajouterHistoriqueEntreprise(data, -SALAIRE_PRODUCTION_ARMURERIE, 'Salaire de production (' + recette.label + ') — ' + (state.char?.name||'Anonyme'));
  await sbSaveEntreprise(data.id, data);

  state.arg = (state.arg || 0) + SALAIRE_PRODUCTION_ARMURERIE;
  updateUI();
  showToast('Production réussie !', recette.label + ' fabriqué(e). +' + SALAIRE_PRODUCTION_ARMURERIE + ' FR de salaire.', true, true);
  addJournalEntry('Production d\'un(e) ' + recette.label + ' à l\'armurerie (+' + SALAIRE_PRODUCTION_ARMURERIE + ' FR).', 'event-good');

  // Ne ferme pas le modal : rafraichit la liste pour permettre d'enchainer sans le rouvrir a
  // chaque fois (production continue, cf regle 3 - seules les 3 ressources limitent, pas une
  // fermeture systematique de fenetre).
  doProduireArme();
}

// doAcheterProduitStock/confirmerAchatStock (ordre "Acheter en stock") retires le 2026-08-16 :
// creaient un objet arme appauvri (sans bonus/image/desc) sans jamais alimenter le registre
// des ventes d'armes -- contournement legal reel confirme par audit. Leur logique economique
// (stock reel, prixVente, caisse, historique, taxes) est desormais fusionnee dans
// confirmerAchatArme/confirmerAchatArmeIllegal ci-dessus, qui restent l'UNIQUE porte d'achat
// et alimentent systematiquement sbEnregistrerVenteArme() cote legal.

// Fix 9 aout 2026 (confirme par test en jeu) : ne reconnaissait que la forme d'inventoire de
// la recolte (type:'matiere_premiere'), jamais la forme empilable produite par un achat a
// l'entrepot (stackable/stackKey) - or l'Armurerie n'existe qu'a Luthecia, qui n'a aucune
// ressource recoltable localement (MATIERES_PREMIERES_VILLE n'a pas d'entree pour 'capitale').
// L'ordre etait donc inutilisable en pratique. Meme correctif que vendre_bois_imprimerie.
async function doVendreMatiereArmurerie() {
  const data = await chargerArmurerieLocale();
  if (!data) { showToast('Indisponible', '', false); return; }

  document.getElementById('postes-modal-title').textContent = 'Vendre des matières premières';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.72rem;color:#8a8060;margin-bottom:.7rem">Prix d\'achat fixés par le propriétaire de l\'armurerie.</div>';
  Object.entries(data.parametres.prixAchatMatiere).forEach(([m, prix]) => {
    const lot = (state.inventory || []).find(i => i.stackKey === m && (i.qty || 0) > 0);
    const qteDispo = lot?.qty || 0;
    html += '<div style="display:flex;align-items:center;gap:.5rem;margin-bottom:.5rem">';
    html += '<span style="flex:1;font-size:.78rem;color:#c0b090">' + m + ' (' + prix + ' FR/unité) — vous en avez ' + qteDispo + '</span>';
    html += '<input type="number" id="vendre-qte-' + m + '" min="1" max="' + qteDispo + '" value="' + (qteDispo > 0 ? qteDispo : 1) + '" style="width:70px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.3rem;font-size:.78rem;outline:none"/>';
    html += '<button onclick="confirmerVenteMatiere(\'' + m + '\')" ' + (qteDispo <= 0 ? 'disabled style="padding:.3rem .6rem;border:1px solid #3a2a20;background:transparent;color:#5a5040;cursor:default;font-size:.72rem"' : 'style="padding:.3rem .6rem;border:1px solid #4a8a4a;background:transparent;color:#6ab858;cursor:pointer;font-size:.72rem"') + '>Vendre</button>';
    html += '</div>';
  });
  html += '<div style="font-size:.7rem;color:#5a5040;font-style:italic;margin-top:.6rem">Nécessite d\'avoir ces matières dans votre inventaire (achetées à l\'Entrepôt Logistique).</div>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerVenteMatiere(matiere) {
  const qte = parseInt(document.getElementById('vendre-qte-' + matiere)?.value || '0');
  document.getElementById('modal-postes')?.classList.remove('open');
  if (!qte || qte <= 0) { showToast('Quantité invalide', '', false); return; }

  const lot = (state.inventory || []).find(i => i.stackKey === matiere && (i.qty || 0) > 0);
  if (!lot || lot.qty < qte) { showToast('Stock personnel insuffisant', 'Vous n\'avez pas ' + qte + ' unité(s) de ' + matiere + '.', false); return; }

  const data = await chargerArmurerieLocale();
  const prixUnitaire = data.parametres.prixAchatMatiere[matiere] || 0;
  const total = prixUnitaire * qte;
  if (data.caisse < total) { showToast('Caisse insuffisante', 'L\'entreprise ne peut pas acheter cette quantité actuellement.', false); return; }

  lot.qty -= qte;
  if (lot.qty <= 0) state.inventory = state.inventory.filter(i => i !== lot);

  // Met a jour stockMatieres ET coutMoyenMatieres en un seul appel (17 aout 2026, generalisation
  // commerces) -- meme effet qu'avant sur stockMatieres, coutMoyenMatieres alimente en plus sans
  // affecter le pricing de l'armurerie (prixVente reste fixe, non derive de ce cout).
  crediterStockMatiereCommerce(data, matiere, qte, prixUnitaire);
  data.caisse -= total;
  ajouterHistoriqueEntreprise(data, -total, 'Achat de matière première (' + matiere + ' x' + qte + ') — ' + (state.char?.name||'Anonyme'));
  await sbSaveEntreprise(data.id, data);

  state.arg = (state.arg || 0) + total;
  updateUI();
  showToast('Vente effectuée', '+' + total + ' FR pour ' + qte + ' ' + matiere + '.', true, true);
  addJournalEntry('Vente de ' + qte + ' ' + matiere + ' à l\'armurerie (+' + total + ' FR).', 'event-good');
}

// =====================
// RACHAT D'ENTREPRISE — registre generalise (Notaire, Bureau des Contrats). Les futures
// entreprises rachetables d'un autre type s'ajoutent ici par une simple ligne de config, a
// condition de suivre le meme modele proprietaire/PNJ (pas le modele directeur-nomme-par-le-
// maire des entrepots/usines actuels, table 'batiments_etat', qui n'a pas de notion de rachat).
//
// A2 (16 aout 2026) : rachat/compromis/preemption se signent TOUS a distance de l'armurerie
// elle-meme (Bureau des Contrats du Notaire, ou bureau du Ministre des Finances pour la
// preemption -- jamais dans l'armurerie), state.currentCity n'a donc aucun sens pour determiner
// QUELLE armurerie est ciblee ici (contrairement a chargerArmurerieLocale, correcte pour la
// production/l'achat/la gestion, actions qui se font physiquement sur place). La liste est donc
// generee dynamiquement, une entree par ville du pays courant possedant reellement une
// armurerie navigable -- generique pour tous les empires, aucune liste figee par pays.
function getVillesAvecArmurerie(country) {
  const monde = WORLD[country];
  if (!monde) return [];
  return Object.keys(monde).filter(v => {
    const c = monde[v];
    return c && Array.isArray(c.buildings) && c.buildings.includes('armurerie');
  });
}

// Prix de rachat des commerces alimentaires pilotes (17 aout 2026, lot 6/6) -- ordre de grandeur
// coherent avec leur dotation de depart (1000-3000 FR de tresorerie), nettement en dessous de
// l'armurerie (130000 FR, un commerce autrement plus etabli). Valeurs de lancement, ajustables.
// La buvette de stade (type 'buvette') est volontairement absente : institution municipale sans
// caisse propre (doctrine du lot 5), pas un commerce a proprietaire prive.
const PRIX_RACHAT_COMMERCE = {
  'cafe-gare-montrouge': 18000,
  'brasserie-voyageurs-montrouge': 28000,
  'hotel-mineur': 15000
};

// Meme forme {id,label,prix,charger} que l'armurerie ci-dessous -- doRachatEntreprise/
// traiterActeRachatEntreprise/ouvrirPreemptionEntreprise n'ont jamais suppose le type
// 'armurerie' nulle part (verifie exhaustivement), donc aucun changement necessaire a ces
// fonctions pour que le rachat/la preemption fonctionnent deja sur ces commerces.
function getCommercesAlimentairesRachetables() {
  const pays = state.country || 'republic';
  return Object.entries(PRIX_RACHAT_COMMERCE)
    .map(([buildingId, prix]) => {
      const villeReelle = Object.keys(WORLD[pays] || {}).find(v => WORLD[pays][v]?.buildings?.includes(buildingId));
      if (!villeReelle) return null; // batiment non construit dans ce pays (pilotes Republic-only pour l'instant)
      const type = BUILDING_COMMERCE_TYPE[buildingId];
      const id = getCommerceId(type, pays, villeReelle, buildingId, null);
      // Nom affiche : override de la ville reelle (villeReelle, pas forcement la ville courante
      // du joueur) en priorite, sinon nom canonique -- meme resolution que getBuildingContext()
      // (plateau-navigation.js) mais parametree par ville plutot que par state.currentCity,
      // necessaire ici puisque cette liste peut etre consultee depuis une autre ville que celle
      // du commerce (ex. Hotel de Montrouge "hotel-mineur", nomme differemment selon la ville --
      // corrige le 20 aout 2026 sans toucher au nom canonique, qui reste partage par 7 villes).
      const nomAffiche = WORLD[pays]?.[villeReelle]?.buildingContext?.[buildingId]?.name || BUILDINGS[buildingId]?.name || buildingId;
      return { id, label: nomAffiche, prix, charger: () => chargerCommerce(type, pays, villeReelle, buildingId, null) };
    })
    .filter(Boolean);
}

function getEntreprisesRachetables() {
  const pays = state.country || 'republic';
  const armureries = getVillesAvecArmurerie(pays).map(city => {
    const id = getEntrepriseIdArmurerie(pays, city);
    return {
      id,
      label: 'l\'Armurerie de ' + (WORLD[pays]?.[city]?.name || city),
      prix: PRIX_RACHAT_ARMURERIE,
      charger: () => chargerEntrepriseParId(id, pays, city)
    };
  });
  return armureries.concat(getCommercesAlimentairesRachetables());
}

function getEntrepriseRachetable(id) {
  return getEntreprisesRachetables().find(e => e.id === id) || null;
}

// Compromis actif = reserve, non expire. ACOMPTE_COMPROMIS (1000 FR, plateau-pnj.js) reutilise
// tel quel : meme acompte fixe que pour un terrain, independant du prix de l'entreprise.
function compromisEntrepriseActif(data) {
  return !!(data && data.compromis && data.compromisExpireAt && Date.now() < data.compromisExpireAt);
}

async function doRachatEntreprise() {
  const candidats = [];
  for (const def of getEntreprisesRachetables()) {
    const data = await def.charger();
    if (data && data.proprietaire === 'PNJ' && !compromisEntrepriseActif(data)) candidats.push({ type: def.id, def });
  }

  if (candidats.length === 0) {
    showToast('Aucune entreprise disponible', 'Aucune entreprise PNJ n\'est actuellement rachetable (ou déjà sous compromis).', false);
    return;
  }

  // Un seul candidat : on saute directement a l'ecran de compromis, comme l'acte de vente de
  // terrain (traiterActeVente) quand un seul compromis est en cours.
  if (candidats.length === 1) { doSignerCompromisEntreprise(candidats[0].type); return; }

  let html = '<div style="padding:1rem"><div style="display:flex;flex-direction:column;gap:.4rem">';
  candidats.forEach(c => {
    html += '<div onclick="doSignerCompromisEntreprise(&quot;' + c.type + '&quot;)" style="cursor:pointer;padding:.6rem;border:1px solid #2a2010;background:#0f0d05;display:flex;justify-content:space-between;align-items:center">';
    html += '<span style="font-size:.85rem;color:#c0b090">' + c.def.label + '</span>';
    html += '<span style="font-family:Bebas Neue,sans-serif;font-size:.85rem;color:#C9A84C">' + c.def.prix.toLocaleString('fr-FR') + ' FR</span>';
    html += '</div>';
  });
  html += '</div></div>';
  document.getElementById('postes-modal-title').textContent = 'Quelle entreprise ?';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function doSignerCompromisEntreprise(type) {
  const def = getEntrepriseRachetable(type);
  if (!def) return;
  const cur = COUNTRIES[state.country || 'republic']?.cur || 'FR';
  const data = await def.charger();
  if (!data || data.proprietaire !== 'PNJ' || compromisEntrepriseActif(data)) {
    showToast('Indisponible', 'Cette entreprise n\'est plus disponible au rachat.', false);
    return;
  }
  if (state.arg < ACOMPTE_COMPROMIS) {
    showToast('Fonds insuffisants', ACOMPTE_COMPROMIS.toLocaleString('fr-FR') + ' ' + cur + ' requis pour l\'acompte.', false);
    return;
  }

  document.getElementById('postes-modal-title').textContent = 'Compromis de rachat';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.85rem;color:#c0b090;margin-bottom:.6rem">' + def.label + ' — ' + def.prix.toLocaleString('fr-FR') + ' ' + cur + '</div>';
  html += '<div style="font-size:.8rem;color:#8a8060;margin-bottom:.8rem">Le compromis réserve cette entreprise 7 jours. À l\'échéance, si le rachat n\'est pas finalisé chez le notaire, l\'acompte est perdu et l\'entreprise redevient disponible.</div>';
  html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.6rem">';
  html += '<div style="font-size:.85rem;color:#c0b090">✓ Versement de l\'acompte</div>';
  html += '<div style="font-size:.72rem;color:#6a5a30">' + ACOMPTE_COMPROMIS.toLocaleString('fr-FR') + ' ' + cur + ' — déduits du prix final, ou perdus si le compromis expire sans finalisation.</div>';
  html += '</div>';

  // Clause pret bancaire, meme mecanisme que le compromis de terrain (doConfirmerCompromis,
  // plateau-pnj.js) : decision tranchee par le cron a l'echeance des 7 jours, pas a la demande.
  html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.8rem">';
  html += '<label style="display:flex;align-items:center;gap:.4rem;font-size:.85rem;color:#c0b090;cursor:pointer"><input type="checkbox" id="compromis-entreprise-pret-check" onchange="document.getElementById(\'compromis-entreprise-pret-champs\').style.display=this.checked?\'block\':\'none\'" /> Demander un prêt à la Banque Nationale</label>';
  html += '<div id="compromis-entreprise-pret-champs" style="display:none;margin-top:.5rem">';
  html += '<div style="display:flex;gap:.4rem">';
  html += '<input id="compromis-entreprise-pret-montant" type="number" placeholder="Montant (max ' + PLAFOND_PRET_COMPROMIS.toLocaleString('fr-FR') + ')" style="flex:1;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem .6rem;font-size:.78rem;outline:none" />';
  html += '<input id="compromis-entreprise-pret-duree" type="number" placeholder="Durée (jours)" value="30" style="width:120px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem .6rem;font-size:.78rem;outline:none" />';
  html += '</div>';
  html += '</div>';
  html += '</div>';

  html += '<button onclick="confirmerSignerCompromisEntreprise(&quot;' + type + '&quot;)" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.6rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Signer le compromis</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerSignerCompromisEntreprise(type) {
  const def = getEntrepriseRachetable(type);
  if (!def) return;
  if (typeof refuserSiGele === 'function' && await refuserSiGele('entreprise', type, 'Signer ce compromis')) return;
  const cur = COUNTRIES[state.country || 'republic']?.cur || 'FR';

  const demandePret = document.getElementById('compromis-entreprise-pret-check')?.checked;
  const montantPret = parseInt(document.getElementById('compromis-entreprise-pret-montant')?.value || 0);
  const dureePret = parseInt(document.getElementById('compromis-entreprise-pret-duree')?.value || 30);

  if (demandePret && (!montantPret || montantPret < 1000 || montantPret > PLAFOND_PRET_COMPROMIS)) {
    showToast('Montant invalide', 'Entre 1000 et ' + PLAFOND_PRET_COMPROMIS.toLocaleString('fr-FR') + ' ' + cur + '.', false);
    return;
  }

  document.getElementById('modal-postes')?.classList.remove('open');
  const data = await def.charger();
  if (!data || data.proprietaire !== 'PNJ') { showToast('Indisponible', 'Cette entreprise n\'est plus disponible.', false); return; }
  if (compromisEntrepriseActif(data)) { showToast('Déjà réservée', 'Un compromis est déjà en cours sur cette entreprise (' + data.compromisPar + ').', false); return; }
  if (state.arg < ACOMPTE_COMPROMIS) { showToast('Fonds insuffisants', ACOMPTE_COMPROMIS.toLocaleString('fr-FR') + ' ' + cur + ' requis.', false); return; }

  state.arg -= ACOMPTE_COMPROMIS;
  data.compromis = true;
  data.compromisPar = state.char?.name;
  data.acompte = ACOMPTE_COMPROMIS;
  data.compromisAt = Date.now();
  data.compromisExpireAt = Date.now() + 7 * 86400000;

  if (demandePret) {
    const taux = typeof getTauxPret === 'function' ? getTauxPret('nationale') : 5;
    const montantTotal = Math.round(montantPret * (1 + taux / 100));
    data.pretDemande = {
      demandeur: state.char?.name,
      montant: montantPret,
      montantTotal: montantTotal,
      duree: dureePret,
      mensualite: Math.ceil(montantTotal / dureePret),
      statut: 'attente_validation'
    };
  }

  await sbSaveEntreprise(data.id, data);
  updateUI();
  showToast('Compromis signé !', def.label + ' réservée 7 jours. -' + ACOMPTE_COMPROMIS.toLocaleString('fr-FR') + ' ' + cur, true);
  addJournalEntry('Compromis de rachat signé pour ' + def.label + ' (' + ACOMPTE_COMPROMIS.toLocaleString('fr-FR') + ' ' + cur + ' d\'acompte). Valable 7 jours.' + (demandePret ? ' Prêt demandé.' : ''), 'event-good');
}

// =====================
// ACTE DE RACHAT D'ENTREPRISE (Notaire, Bureau des Contrats) — finalise un compromis actif,
// sur le modele exact de acte_vente_terrain/traiterActeVente (doActeVenteTerrain,
// plateau-justice-economie.js).
// =====================
async function doActeRachatEntreprise(pa, cost) {
  const nom = state.char?.name;
  const candidats = [];
  for (const def of getEntreprisesRachetables()) {
    const data = await def.charger();
    if (data && data.compromis && data.compromisPar === nom) candidats.push({ type: def.id, def });
  }

  if (candidats.length === 0) {
    showToast('Aucune réservation', 'Vous n\'avez aucun compromis en cours sur une entreprise.', false);
    return;
  }

  if (candidats.length === 1) { traiterActeRachatEntreprise(candidats[0], pa, cost); return; }

  let html = '<div style="padding:1rem"><div style="display:flex;flex-direction:column;gap:.4rem">';
  candidats.forEach((c, i) => {
    html += '<div onclick="traiterActeRachatEntrepriseParIndex(' + i + ',' + pa + ',' + cost + ')" style="cursor:pointer;padding:.6rem;border:1px solid #2a2010;background:#0f0d05">' + c.def.label + '</div>';
  });
  html += '</div></div>';
  window._candidatsActeRachatEntreprise = candidats;
  document.getElementById('postes-modal-title').textContent = 'Quelle entreprise ?';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function traiterActeRachatEntrepriseParIndex(i, pa, cost) {
  traiterActeRachatEntreprise(window._candidatsActeRachatEntreprise[i], pa, cost);
}

async function traiterActeRachatEntreprise(candidat, pa, cost) {
  const cur = COUNTRIES[state.country || 'republic']?.cur || 'FR';
  const def = candidat.def;
  if (typeof refuserSiGele === 'function' && await refuserSiGele('entreprise', def.id, "Officialiser le rachat")) return;
  const data = await def.charger(); // relecture fraiche, evite tout etat perime
  if (!data || !data.compromis || data.compromisPar !== state.char?.name) {
    showToast('Compromis introuvable', 'Ce compromis n\'est plus valide (peut-être déjà expiré).', false);
    return;
  }
  if (data.pretDemande && data.pretDemande.statut === 'attente_validation') {
    showToast('Clause en attente', 'Le prêt demandé n\'est pas encore tranché par la banque. Revenez après sa décision.', false);
    return;
  }
  const solde = def.prix - (data.acompte || 0);
  if (state.arg < solde) {
    showToast('Fonds insuffisants', solde.toLocaleString('fr-FR') + ' ' + cur + ' restants à payer.', false);
    return;
  }
  const rRachat = await deduireCoutOrdre({ pa, cost });
  if (!rRachat.ok) { showToast('PA insuffisants', '', false); return; }

  state.arg -= solde;
  data.proprietaire = state.char?.name;
  delete data.compromis;
  delete data.compromisPar;
  delete data.acompte;
  delete data.compromisAt;
  delete data.compromisExpireAt;
  ajouterHistoriqueEntreprise(data, 0, 'Rachat de l\'entreprise par ' + state.char?.name + ' (acte notarié)');
  await sbSaveEntreprise(data.id, data);
  updateUI();
  document.getElementById('modal-postes')?.classList.remove('open');
  showToast('Acte signé !', 'Vous êtes désormais propriétaire de ' + def.label + '.', true, true);
  addJournalEntry('Rachat de ' + def.label + ' officialisé — ' + solde.toLocaleString('fr-FR') + ' ' + cur + ' de solde payé.', 'event-good');
}

// =====================
// PREEMPTION D'ETAT (Ministre des Finances, Bureau du Ministre des Finances) -- chemin
// parallele au rachat joueur ci-dessus, ne le court-circuite pas (champ preemptionEtat distinct
// de compromis/compromisPar). Une seule preemption active a la fois par pays, tant que son pret
// n'est pas solde (budgets_nationaux[pays].preemption, verifie a l'ouverture et a la confirmation).
// =====================
async function ouvrirPreemptionEntreprise() {
  const pays = state.country || 'republic';
  const cur = COUNTRIES[pays]?.cur || 'FR';
  const budgetNat = await chargerBudgetNational(pays);
  if (budgetNat.preemption) {
    const def = getEntrepriseRachetable(budgetNat.preemption.entrepriseType);
    showToast('Préemption en cours', 'Le prêt sur ' + (def?.label || budgetNat.preemption.entrepriseType) + ' n\'est pas encore soldé. Impossible d\'en lancer une nouvelle.', false);
    return;
  }

  const candidats = [];
  for (const def of getEntreprisesRachetables()) {
    const data = await def.charger();
    if (data && data.proprietaire === 'PNJ' && !compromisEntrepriseActif(data) && !data.preemptionEtat) candidats.push({ type: def.id, def });
  }

  if (candidats.length === 0) {
    showToast('Aucune entreprise disponible', 'Aucune entreprise PNJ n\'est actuellement préemptable.', false);
    return;
  }

  document.getElementById('postes-modal-title').textContent = 'Droit de préemption';
  let html = '<div style="padding:1rem"><div style="display:flex;flex-direction:column;gap:.4rem">';
  candidats.forEach(c => {
    html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;display:flex;justify-content:space-between;align-items:center">';
    html += '<span style="font-size:.85rem;color:#c0b090">' + c.def.label + '</span>';
    html += '<div style="display:flex;align-items:center;gap:.6rem"><span style="font-family:Bebas Neue,sans-serif;font-size:.85rem;color:#C9A84C">' + c.def.prix.toLocaleString('fr-FR') + ' ' + cur + '</span>';
    html += '<button onclick="ouvrirPretPreemption(&quot;' + c.type + '&quot;)" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;padding:.3rem .6rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">Préempter</button></div>';
    html += '</div>';
  });
  html += '</div></div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function ouvrirPretPreemption(type) {
  const def = getEntrepriseRachetable(type);
  if (!def) return;
  const cur = COUNTRIES[state.country || 'republic']?.cur || 'FR';
  document.getElementById('postes-modal-title').textContent = 'Prêt de préemption — ' + def.label;
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Prix à couvrir : ' + def.prix.toLocaleString('fr-FR') + ' ' + cur + '. Le prêt doit couvrir au moins ce montant (le surplus éventuel reste dans la caisse du Ministère). Automatique, aucun jet de risque, crédité immédiatement.</div>';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.4rem">MONTANT DU PRÊT</div>';
  html += '<input id="preemption-pret-montant" type="number" min="' + def.prix + '" step="1000" value="' + def.prix + '" style="width:100%;padding:.4rem .6rem;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;font-family:Crimson Pro,serif;font-size:.85rem;box-sizing:border-box;margin-bottom:.6rem"/>';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.4rem">DURÉE (JOURS)</div>';
  html += '<input id="preemption-pret-duree" type="number" min="5" step="5" value="30" style="width:100%;padding:.4rem .6rem;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;font-family:Crimson Pro,serif;font-size:.85rem;box-sizing:border-box;margin-bottom:.8rem"/>';
  html += '<button onclick="confirmerPreemption(&quot;' + type + '&quot;)" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Emprunter et préempter</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function confirmerPreemption(type) {
  const def = getEntrepriseRachetable(type);
  if (!def) return;
  if (typeof refuserSiGele === 'function' && await refuserSiGele('entreprise', type, 'Préempter cette entreprise')) return;
  const cur = COUNTRIES[state.country || 'republic']?.cur || 'FR';
  const pays = state.country || 'republic';
  const montant = parseInt(document.getElementById('preemption-pret-montant')?.value || 0);
  const duree = parseInt(document.getElementById('preemption-pret-duree')?.value || 30);

  if (!montant || montant < def.prix) {
    showToast('Montant insuffisant', 'Le prêt doit couvrir au moins ' + def.prix.toLocaleString('fr-FR') + ' ' + cur + '.', false);
    return;
  }

  const budgetNat = await chargerBudgetNational(pays);
  if (budgetNat.preemption) {
    showToast('Préemption en cours', 'Une préemption est déjà active.', false);
    return;
  }

  const data = await def.charger();
  if (!data || data.proprietaire !== 'PNJ' || compromisEntrepriseActif(data) || data.preemptionEtat) {
    showToast('Indisponible', 'Cette entreprise n\'est plus préemptable.', false);
    return;
  }

  document.getElementById('modal-postes')?.classList.remove('open');

  // Deduction PA centralisee (correctif Lot 2C) -- deduireCoutOrdre() est l'AUTORITE UNIQUE.
  // Appelee ICI, au dernier point sur avant la premiere mutation institutionnelle/Supabase
  // (crediterCaisseBatiment ci-dessous) : fail-closed. Aucun cout personnel (cost:0, voir
  // data.js : pa:2, cost:0 pour preempter_entreprise), seul le pret automatique de la Banque
  // Nationale finance l'operation.
  const rPa = await deduireCoutOrdre({ pa: 2, cost: 0 });
  if (!rPa.ok) { showToast('PA insuffisants', '2 PA requis.', false); return; }

  const taux = typeof getTauxPret === 'function' ? getTauxPret('nationale') : 5;
  const montantTotal = Math.round(montant * (1 + taux / 100));

  if (typeof crediterCaisseBatiment === 'function') await crediterCaisseBatiment(pays, 'gouvernement-min_fin', montant).catch(() => {});
  if (typeof debiterCaisseBatimentPlafonne === 'function') await debiterCaisseBatimentPlafonne(pays, 'gouvernement-min_fin', def.prix).catch(() => {});

  data.preemptionEtat = 'attente_acte';
  data.preemptionPar = state.char?.name || 'Le Ministre des Finances';
  await sbSaveEntreprise(data.id, data);

  budgetNat.preemption = {
    entrepriseType: type,
    montantInitial: montant,
    montantRestant: montantTotal,
    dureeJours: duree,
    mensualite: Math.ceil(montantTotal / duree),
    jourDebut: state.day || 1
  };
  await sbSaveBudgetNational(pays, budgetNat).catch(() => {});

  updateUI();
  showToast('Préemption engagée !', def.label + ' préemptée pour ' + def.prix.toLocaleString('fr-FR') + ' ' + cur + '. Reste à officialiser chez le notaire.', true, true);
  addExternalEvent('PRÉEMPTION : L\'État a exercé son droit de préemption sur ' + def.label + '.');
  addJournalEntry('Préemption engagée sur ' + def.label + ' — prêt de ' + montant.toLocaleString('fr-FR') + ' ' + cur + ' sur ' + duree + ' jours.', 'event-info');
}

// Finalisation chez le Notaire (Bureau des Contrats), reservee au Ministre des Finances --
// aucun paiement ici, deja couvert par le pret verse a la preemption.
async function doActeRachatEntreprisePreemption(pa, cost) {
  if (state.poste?.id !== 'min_fin') { showToast('Réservé au Ministre des Finances', '', false); return; }
  const candidats = [];
  for (const def of getEntreprisesRachetables()) {
    const data = await def.charger();
    if (data && data.preemptionEtat === 'attente_acte') candidats.push({ type: def.id, def });
  }

  if (candidats.length === 0) {
    showToast('Aucune préemption en attente', 'Aucune entreprise préemptée n\'attend d\'être officialisée.', false);
    return;
  }

  if (candidats.length === 1) { traiterActeRachatEntreprisePreemption(candidats[0], pa, cost); return; }

  let html = '<div style="padding:1rem"><div style="display:flex;flex-direction:column;gap:.4rem">';
  candidats.forEach((c, i) => {
    html += '<div onclick="traiterActeRachatEntreprisePreemptionParIndex(' + i + ',' + pa + ',' + cost + ')" style="cursor:pointer;padding:.6rem;border:1px solid #2a2010;background:#0f0d05">' + c.def.label + '</div>';
  });
  html += '</div></div>';
  window._candidatsActePreemption = candidats;
  document.getElementById('postes-modal-title').textContent = 'Quelle entreprise ?';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function traiterActeRachatEntreprisePreemptionParIndex(i, pa, cost) {
  traiterActeRachatEntreprisePreemption(window._candidatsActePreemption[i], pa, cost);
}

async function traiterActeRachatEntreprisePreemption(candidat, pa, cost) {
  const def = candidat.def;
  if (typeof refuserSiGele === 'function' && await refuserSiGele('entreprise', def.id, 'Officialiser la préemption')) return;
  const data = await def.charger();
  if (!data || data.preemptionEtat !== 'attente_acte') {
    showToast('Préemption introuvable', 'Cette préemption n\'est plus valide (peut-être déjà officialisée).', false);
    return;
  }
  const rPreemption = await deduireCoutOrdre({ pa, cost });
  if (!rPreemption.ok) { showToast('PA insuffisants', '', false); return; }
  const pays = state.country || 'republic';
  data.proprietaire = 'État (' + (COUNTRIES[pays]?.n || pays) + ')';
  delete data.preemptionEtat;
  delete data.preemptionPar;
  ajouterHistoriqueEntreprise(data, 0, 'Préemption par l\'État, officialisée par le Ministre des Finances');
  await sbSaveEntreprise(data.id, data);
  updateUI();
  document.getElementById('modal-postes')?.classList.remove('open');
  showToast('Acte signé !', def.label + ' appartient désormais à l\'État.', true, true);
  addJournalEntry('Préemption de ' + def.label + ' officialisée — propriété transférée à l\'État.', 'event-good');
}

async function doGererArmurerie() {
  const data = await chargerArmurerieLocale();
  if (!data) { showToast('Indisponible', '', false); return; }
  if (data.proprietaire !== state.char?.name) { showToast('Réservé au propriétaire', 'Cette armurerie appartient à ' + data.proprietaire + '.', false); return; }

  document.getElementById('postes-modal-title').textContent = 'Gérer mon armurerie';
  let html = '<div style="padding:1rem">';
  html += '<div style="text-align:center;font-family:Bebas Neue,sans-serif;font-size:1.1rem;color:#C9A84C;margin-bottom:.8rem">Caisse : ' + data.caisse.toLocaleString('fr-FR') + ' FR</div>';

  html += '<div style="font-size:.72rem;color:#6a5a30;font-style:italic;margin-bottom:.6rem">Salaire de production fixe : 100 FR par arme (2 PA), non réglable.</div>';

  html += '<div style="font-size:.72rem;color:#8a8060;margin-bottom:.3rem">Prix d\'achat des matières (FR/unité)</div>';
  Object.keys(data.parametres.prixAchatMatiere).forEach(m => {
    html += '<div style="display:flex;gap:.4rem;margin-bottom:.3rem"><span style="flex:1;font-size:.75rem;color:#c0b090">' + m + '</span><input id="gere-mat-' + m + '" type="number" value="' + data.parametres.prixAchatMatiere[m] + '" style="width:80px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.3rem;font-size:.75rem;outline:none"/></div>';
  });

  html += '<div style="font-size:.72rem;color:#8a8060;margin:.5rem 0 .3rem">Prix de vente et stock maximum</div>';
  Object.keys(getRecettesPays(state.country || 'republic')).forEach(id => {
    html += '<div style="display:flex;gap:.4rem;margin-bottom:.3rem;align-items:center">';
    html += '<span style="flex:1;font-size:.75rem;color:#c0b090">' + RECETTES_PRODUCTION[id].label + '</span>';
    html += '<input id="gere-prix-' + id + '" type="number" value="' + (data.parametres.prixVente[id]||0) + '" placeholder="Prix" style="width:70px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.3rem;font-size:.72rem;outline:none"/>';
    html += '<input id="gere-max-' + id + '" type="number" value="' + (data.parametres.stockMax[id]||0) + '" placeholder="Stock max" style="width:70px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.3rem;font-size:.72rem;outline:none"/>';
    html += '</div>';
  });

  html += '<button onclick="confirmerGestionArmurerie(\'' + data.id + '\')" style="width:100%;margin-top:.6rem;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.55rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Valider</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerGestionArmurerie(entrepriseId) {
  const data = await sbGetEntreprise(entrepriseId);
  if (!data) return;

  Object.keys(data.parametres.prixAchatMatiere).forEach(m => {
    data.parametres.prixAchatMatiere[m] = Math.max(0, parseInt(document.getElementById('gere-mat-' + m)?.value || '0'));
  });
  Object.keys(getRecettesPays(state.country || 'republic')).forEach(id => {
    data.parametres.prixVente[id] = Math.max(0, parseInt(document.getElementById('gere-prix-' + id)?.value || '0'));
    data.parametres.stockMax[id] = Math.max(0, parseInt(document.getElementById('gere-max-' + id)?.value || '0'));
  });

  await sbSaveEntreprise(entrepriseId, data);
  document.getElementById('modal-postes')?.classList.remove('open');
  showToast('Paramètres mis à jour', '', true, true);
}


// =====================
// ZONES DE PRODUCTION — recolte de matieres premieres locales
// =====================
function verifierEtResetRecoltesJour() {
  if (!state.char) return;
  if (state.char.recoltesJour?.jour !== state.day) {
    state.char.recoltesJour = { jour: state.day || 1, nb: 0 };
  }
}

async function doRecolterMatiere(pa, cost) {
  const pays = state.country || 'republic';
  const ville = state.currentCity || 'capitale';
  const matieres = typeof getMatieresPremieresVille === 'function' ? getMatieresPremieresVille(pays, ville) : [];
  if (!matieres.length) { showToast('Indisponible', 'Aucune ressource naturelle à récolter ici.', false); return; }

  verifierEtResetRecoltesJour();
  const nb = state.char.recoltesJour?.nb || 0;

  document.getElementById('postes-modal-title').textContent = 'Récolter';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.75rem;color:#8a8060;margin-bottom:.7rem">Récoltes aujourd\'hui : ' + nb + '/2</div>';
  matieres.forEach(m => {
    html += '<button ' + (nb >= 2 ? 'disabled' : '') + ' onclick="confirmerRecolte(\'' + m + '\',' + pa + ',' + cost + ')" style="display:block;width:100%;text-align:left;margin-bottom:.4rem;padding:.55rem .7rem;border:1px solid #2a2010;background:transparent;color:' + (nb>=2?'#5a5040':'#c0b090') + ';cursor:' + (nb>=2?'default':'pointer') + ';font-size:.8rem">' + m + '</button>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// Correspondance entre le libelle d'affichage de MATIERES_PREMIERES_VILLE et la cle canonique
// RESSOURCES_ECONOMIE, quand elle existe (17 aout 2026, releve economique + chantier commerces
// alimentaires). Le systeme entrepot/armurerie/commerces est Republic-only aujourd'hui --
// narco/soviet/khalija recoltent des matieres sans equivalent economique reel (Cuir, Bois
// exotique, Caoutchouc, Ble, Epices, Coton...), volontairement laissees au format legacy
// ci-dessous jusqu'a leur eventuelle integration (hors perimetre de ce chantier).
const MATIERE_RECOLTE_VERS_CLE = {
  'Métal': 'metal',
  'Poisson': 'poisson',
  'Charbon': 'charbon',
  'Bois': 'bois'
};

async function confirmerRecolte(matiere, pa, cost) {
  verifierEtResetRecoltesJour();
  if ((state.char.recoltesJour?.nb || 0) >= 2) { showToast('Limite atteinte', 'Maximum 2 récoltes par jour.', false); return; }
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }
  state.char.recoltesJour.nb = (state.char.recoltesJour.nb || 0) + 1;

  const quantite = 1 + Math.floor(Math.random() * 2); // 1 a 2 unites
  if (!state.inventory) state.inventory = [];

  // Format empilable (stackable/stackKey), identique aux matieres achetees a l'entrepot (A3,
  // chantier commerces alimentaires, 17 aout 2026) -- corrige la coupure auditee : la recolte
  // produisait auparavant un objet non empilable par unite, invendable a l'armurerie/aux
  // commerces qui lisent stackKey. Repli sur l'ancien format legacy pour toute matiere sans
  // equivalent RESSOURCES_ECONOMIE (aucune casse des objets deja en inventaire -- coexistence
  // pure, aucune migration).
  const cle = MATIERE_RECOLTE_VERS_CLE[matiere];
  const res = cle && typeof RESSOURCES_ECONOMIE !== 'undefined' ? RESSOURCES_ECONOMIE[cle] : null;
  if (res && typeof addToInventory === 'function') {
    addToInventory({ name: res.label, icon: res.icon, stackable: true, stackKey: cle, qty: quantite, desc: 'Récolté localement.' });
  } else {
    for (let i = 0; i < quantite; i++) {
      state.inventory.push({ type: 'matiere_premiere', matiere, name: matiere, icon: 'ti-package' });
    }
  }

  document.getElementById('modal-postes')?.classList.remove('open');
  updateUI();
  showToast('Récolte effectuée', '+' + quantite + ' ' + matiere + '.', true, true);
  addJournalEntry('Récolte de ' + quantite + ' ' + matiere + '.', 'event-good');
}

async function doConsommerBuvette(pa, cost) {
  const cout = 50;
  if (state.arg < cout) { showToast('Fonds insuffisants', cout + ' FR requis.', false); return; }
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }
  state.pop = Math.min(100, (state.pop || 0) + 2);

  if (typeof appliquerTaxeTransaction === 'function' && typeof crediterCaisseBatiment === 'function') {
    const { net } = await appliquerTaxeTransaction(cout);
    // Doctrine (A3, lot finition financiere locale, 17 aout 2026) : la buvette n'a pas de
    // caisse financiere autonome -- tout argent genere dans l'enceinte du stade appartient a
    // la caisse du stade de cette ville. La ligne legacy 'stade-buvette' (88 FR, origine non
    // demontrable avec certitude) reste intacte et ne recoit plus aucune nouvelle recette.
    const idCaisseStade = typeof getCaisseLocaleId === 'function' ? getCaisseLocaleId('stade', state.currentCity) : 'stade';
    await crediterCaisseBatiment(state.country || 'republic', idCaisseStade, net).catch(() => {});
  }

  updateUI();
  showToast('Un verre entre supporters', '+2 POP.', true, true);
  addJournalEntry('Un verre pris à la buvette (-' + cout + ' FR).', 'event-good');
}
