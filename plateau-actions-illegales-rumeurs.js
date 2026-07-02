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
  const per = char?.stats?.PER || 8;
  const cha = char?.stats?.CHA || 8;
  const bonusCarriere = BONUS_CARRIERE_VOL[char?.career] || 0;
  const isPays = INDICES_NATIONAUX[state.country]?.IS || 40;

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
      const h = String(state.hour || 8).padStart(2,'0');
      const time = 'Jour ' + (state.day || 1) + ' · ' + h + 'h';
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
  const hasBlade = armes.some(a => a.name.toLowerCase().includes('couteau') || a.name.toLowerCase().includes('arme blanche'));
  const hasGun   = armes.some(a => a.name.toLowerCase().includes('pistolet') || a.name.toLowerCase().includes('feu'));

  const vol = char?.stats?.VOL || 8;
  const per = char?.stats?.PER || 8;
  const dup = char?.stats?.DUP || 8;

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
  if (!TEST_MODE) state.pa = Math.max(0, state.pa - paCost);

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
  escort:     (a, c) => 'Il paraîtrait que ' + a + ' fréquente assidûment certains établissements... discrets.'
};

async function ecouterRumeurs() {
  const ville = WORLD[state.country]?.[state.currentCity]?.name || 'la ville';
  const char = state.char;
  const pnjPresents = ['Le Commissaire', 'Un député', 'Un journaliste', 'Un commerçant', 'Un inconnu'];
  const source = pnjPresents[Math.floor(Math.random() * pnjPresents.length)];

  showToast('Vous tendez l\'oreille...', 'En attente d\'une information.', false);

  // 1. Tenter d'abord une VRAIE rumeur basee sur une action reellement tracee
  let actionsDisponibles = [];
  if (typeof sbGetActionsTracables === 'function') {
    try {
      actionsDisponibles = await sbGetActionsTracables(state.country, state.currentCity, state.day || 1);
      // Ne jamais reveler sa propre action a soi-meme
      actionsDisponibles = actionsDisponibles.filter(a => a.auteur !== char?.name);
    } catch(e) {}
  }

  if (actionsDisponibles.length > 0 && Math.random() < 0.6) {
    const action = actionsDisponibles[Math.floor(Math.random() * actionsDisponibles.length)];
    const formulateur = FORMULATIONS_RUMEUR_VRAIE[action.type_action];
    if (formulateur) {
      const texte = formulateur(action.auteur, action.cible || 'quelqu\'un');
      document.getElementById('postes-modal-title').textContent = source + ' vous glisse à l\'oreille...';
      document.getElementById('postes-body').innerHTML =
        '<div style="padding:1.2rem">' +
        '<div style="font-size:.85rem;color:#c0b090;font-style:italic;line-height:1.7;font-family:Crimson Pro,serif">"' + texte + '"</div>' +
        '<div style="font-size:.68rem;color:#4a4030;margin-top:.8rem">Source : ' + source + ' · Information vérifiée</div>' +
        '</div>';
      document.getElementById('modal-postes').classList.add('open');
      state.inf = Math.min(100, state.inf + 1);
      updateUI();
      addJournalEntry('Rumeur entendue à ' + ville, 'event-info');
      return;
    }
  }

  // 2. Fallback — generation IA generique si aucune vraie action disponible
  const context = 'Empire : ' + (COUNTRIES[state.country]?.n || 'Républia') +
    '. Ville : ' + ville +
    '. Votre personnage : ' + (char?.name || 'Anonyme') +
    (state.poste ? ', ' + state.poste.name : '') +
    '. Jour ' + state.day + '.' +
    (state.guerres?.length ? ' Guerre en cours contre : ' + state.guerres.map(g=>g.nom).join(', ') + '.' : '') +
    (state.electionsEnCours?.length ? ' Elections en cours.' : '');

  try {
    const resp = await fetch('/api/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: 'claude-sonnet-4-5',
        max_tokens: 200,
        messages: [{
          role: 'user',
          content: 'Tu es le narrateur d\'un jeu de rôle politique parodique et satirique. Contexte : ' + context + '. Génère UNE rumeur courte (2-3 phrases max) que "' + source + '" chuchote à l\'oreille du joueur. La rumeur doit être crédible, légèrement compromettante pour un personnage politique ou une institution, et adaptée au contexte. Ton satirique et cynique. Réponds UNIQUEMENT avec la rumeur, sans introduction.'
        }]
      })
    });
    const data = await resp.json();
    const rumeur = data.content?.[0]?.text || 'Rien d\'intéressant à rapporter aujourd\'hui.';

    document.getElementById('postes-modal-title').textContent = source + ' vous glisse à l\'oreille...';
    document.getElementById('postes-body').innerHTML =
      '<div style="padding:1.2rem">' +
      '<div style="font-size:.85rem;color:#c0b090;font-style:italic;line-height:1.7;font-family:Crimson Pro,serif">"' + rumeur + '"</div>' +
      '<div style="font-size:.68rem;color:#4a4030;margin-top:.8rem">Source : ' + source + ' · Fiabilité incertaine</div>' +
      '</div>';
    document.getElementById('modal-postes').classList.add('open');

    state.inf = Math.min(100, state.inf + 1);
    updateUI();
    addJournalEntry('Rumeur entendue à ' + ville, 'event-info');

  } catch(e) {
    showToast('Silence', 'Personne ne parle aujourd\'hui.', false);
  }
}

async function solliciterAudiencePresident() {
  const char = state.char;
  const nomDemandeur = char?.name || 'Anonyme';
  // Message automatique au demandeur
  showToast(
    'Demande transmise',
    'Je transmets votre demande à Monsieur le Président. Il vous contactera dès qu\'il en aura pris connaissance.',
    true
  );
  addJournalEntry('Vous avez sollicite une audience presidentielle.', 'event-info');
  // Mail au President (vrai titulaire recherche via Supabase)
  const titulaire = await getTitulairePoste('president');
  await envoyerNotificationVraiJoueur(titulaire, 'Demande d\'audience de ' + nomDemandeur,
    nomDemandeur + ' sollicite une audience presidentielle. Vous pouvez lui repondre directement par mail.');
}

// =====================

// PRODUIRE UNE FUITE
// =====================
async function ouvrirProduireFuite() {
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
  html += '<button onclick="confirmerFuite()" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Lancer la fuite</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerFuite() {
  const cible = document.getElementById('fuite-cible')?.value;
  if (!cible) return;
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
function ouvrirFabrquerScandale() {
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
  html += '<button onclick="confirmerScandale(' + taux + ')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Publier le scandale</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerScandale(taux) {
  const cible = document.getElementById('scandale-cible')?.value;
  const contenu = document.getElementById('scandale-contenu')?.value?.trim();
  if (!cible || !contenu) { showToast('Champs requis', '', false); return; }
  document.getElementById('modal-postes').classList.remove('open');

  const roll = Math.floor(Math.random() * 100) + 1;
  const tauxFinal = Math.max(5, taux - getMalusISN());

  if (roll <= tauxFinal) {
    // Publier dans le forum national
    if (!FORUM_TOPICS['national']) FORUM_TOPICS['national'] = [];
    FORUM_TOPICS['national'].unshift({
      id: 'scandale-' + Date.now(),
      title: '[SCANDALE] Revelations sur ' + cible,
      author: 'Source anonyme',
      time: 'Jour ' + state.day,
      posts: [{ author: 'Source anonyme', time: 'Jour ' + state.day, content: contenu }]
    });

    // Mail a la cible
    addMailNotification('Redaction anonyme', 'Scandale vous concernant', 'Un article compromettant vous concernant vient d\'etre publie dans le forum national. -15 INF -15 POP -10 Moral.');
    addExternalEvent('SCANDALE : Revelations compromettantes sur ' + cible + ' publiees dans le forum national !');
    showToast('Scandale publie !', 'Article dans le forum national. -15 INF -15 POP -10 Moral sur ' + cible, true, true);
    addJournalEntry('Scandale fabrique contre ' + cible, 'event-bad');

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
      imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-revolver-republic.png'
    },
    {
      id: 'carabine_chasse',
      name: 'Carabine de chasse',
      type: 'carabine',
      prix: 1800,
      icon: 'ti-target-arrow',
      desc: 'Pour le gibier. Gros gibier.',
      bonus: { stat: 'PER', val: 15 },
      imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-fusil-republic.png'
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
function ouvrirModalAcheterArme() {
  const pays = state.country || 'republic';
  const cur = COUNTRIES[pays]?.cur || 'FR';
  const armes = ARMES_CATALOGUE[pays] || ARMES_CATALOGUE.republic;

  document.getElementById('postes-modal-title').textContent = 'Choisissez votre arme';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:1rem">Achat légal : enregistré au registre de vente, prix normal. Marché noir : non enregistré, 3x le prix, risque de dénonciation par l\'armurier.</div>';
  html += '<div style="display:grid;grid-template-columns:repeat(3,1fr);gap:.6rem">';

  armes.forEach((arme) => {
    const typeLabel = { blanche: 'Arme blanche', poing: 'Arme de poing', carabine: 'Carabine' }[arme.type] || arme.type;
    const prixIllegal = arme.prix * 3;
    html += '<div style="border:1px solid #2a2010;background:#0a0805;overflow:hidden">';
    // Image
    html += '<div style="width:100%;height:120px;overflow:hidden;background:#050503">';
    if (arme.imageUrl) {
      html += '<img src="' + arme.imageUrl + '" style="width:100%;height:100%;object-fit:cover;opacity:.85"/>';
    } else {
      html += '<div style="width:100%;height:100%;display:flex;align-items:center;justify-content:center"><i class="ti ' + arme.icon + '" style="font-size:2rem;color:#3a2a10"></i></div>';
    }
    html += '</div>';
    // Infos
    html += '<div style="padding:.5rem">';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.08em;color:#c0b090;margin-bottom:.2rem">' + arme.name + '</div>';
    html += '<div style="font-size:.68rem;color:#5a5040;font-style:italic;margin-bottom:.4rem;line-height:1.4">' + arme.desc + '</div>';
    html += '<div style="font-size:.65rem;color:#4a8a4a;margin-bottom:.5rem">+' + arme.bonus.val + ' ' + arme.bonus.stat + ' · ' + typeLabel + '</div>';
    html += '<button onclick="confirmerAchatArme(\'' + arme.id + '\')" style="width:100%;margin-bottom:.35rem;font-family:Bebas Neue,sans-serif;font-size:.68rem;letter-spacing:.06em;padding:.4rem;border:1px solid #4a7a3a;background:transparent;color:#7ab868;cursor:pointer" onmouseover="this.style.background=\'#0e1a0a\'" onmouseout="this.style.background=\'transparent\'">Achat légal — ' + arme.prix.toLocaleString('fr-FR') + ' ' + cur + '</button>';
    html += '<button onclick="confirmerAchatArmeIllegal(\'' + arme.id + '\')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.68rem;letter-spacing:.06em;padding:.4rem;border:1px solid #8a3a3a;background:transparent;color:#cc6a6a;cursor:pointer" onmouseover="this.style.background=\'#1a0a0a\'" onmouseout="this.style.background=\'transparent\'">Marché noir — ' + prixIllegal.toLocaleString('fr-FR') + ' ' + cur + '</button>';
    html += '</div></div>';
  });

  html += '</div>';
  html += '<button onclick="document.getElementById(\'modal-postes\').classList.remove(\'open\')" style="margin-top:.8rem;width:100%;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.1em;padding:.4rem;border:1px solid #2a2010;background:transparent;color:#4a4030;cursor:pointer">Renoncer à l\'achat</button>';
  html += '</div>';

  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerAchatArme(armeId) {
  const pays = state.country || 'republic';
  const cur = COUNTRIES[pays]?.cur || 'FR';
  const armes = ARMES_CATALOGUE[pays] || ARMES_CATALOGUE.republic;
  const arme = armes.find(a => a.id === armeId);
  if (!arme) return;

  if (state.arg < arme.prix) {
    showToast('Fonds insuffisants', arme.prix.toLocaleString('fr-FR') + ' ' + cur + ' requis.', false);
    return;
  }

  state.arg -= arme.prix;
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

  // Inscription au registre officiel de vente d'armes
  if (typeof sbEnregistrerVenteArme === 'function') {
    sbEnregistrerVenteArme({
      joueur: state.char?.name || 'Anonyme',
      arme: arme.name,
      prix: arme.prix,
      pays: pays,
      jour: state.day || 1,
      heure: state.hour || 8
    }).catch(() => {});
  }

  updateUI();
  addJournalEntry('Achat légal : ' + arme.name + ' (-' + arme.prix.toLocaleString('fr-FR') + ' ' + cur + '). Inscrit au registre.', 'event-bad');

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

function confirmerAchatArmeIllegal(armeId) {
  const pays = state.country || 'republic';
  const cur = COUNTRIES[pays]?.cur || 'FR';
  const armes = ARMES_CATALOGUE[pays] || ARMES_CATALOGUE.republic;
  const arme = armes.find(a => a.id === armeId);
  if (!arme) return;

  const prixIllegal = arme.prix * 3;
  if (state.arg < prixIllegal) {
    showToast('Fonds insuffisants', prixIllegal.toLocaleString('fr-FR') + ' ' + cur + ' requis (marché noir).', false);
    return;
  }

  document.getElementById('modal-postes').classList.remove('open');

  // Jet de reussite — meme logique que le vol (adapte : pas de cible, achat aupres du PNJ armurier)
  const char = state.char;
  const bonusCarriere = BONUS_CARRIERE_VOL[char?.career] || 0;
  const isPays = INDICES_NATIONAUX[pays]?.IS || 40;
  const tauxReussite = Math.max(5, Math.min(95, Math.round(50 + bonusCarriere - (isPays / 3))));
  const roll = Math.random() * 100;

  if (roll > tauxReussite) {
    // ECHEC — l'armurier refuse et denonce
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

    if (typeof sbSendMail === 'function') {
      const h = String(state.hour || 8).padStart(2,'0');
      const time = 'Jour ' + (state.day || 1) + ' · ' + h + 'h';
      sbSendMail('Commissariat', state.char?.name || '', 'Convocation officielle', 'L\'armurier a refusé la vente et vous a dénoncé. Présentez-vous au commissariat sous 24h pour vous justifier, faute de quoi vous serez arrêté(e).', time).catch(() => {});
    }

    updateUI();
    showToast('Vente refusée !', 'L\'armurier vous dénonce. Convocation au commissariat sous 24h.', false, true);
    addJournalEntry('Tentative d\'achat d\'arme au marché noir échouée. Dénoncé(e) par l\'armurier.', 'event-bad');
    return;
  }

  // REUSSITE — arme livree, non enregistree
  state.arg -= prixIllegal;
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

  if (!posteHabilite) {
    showToast('Accès refusé', 'Seuls le Commissaire, le Maire, le Ministre de la Justice, le Ministre de l\'Intérieur et le Président peuvent consulter le registre.', false);
    return;
  }

  const pays = state.country || 'republic';
  let ventes = [];
  if (typeof sbConsulterRegistreArmes === 'function') {
    ventes = await sbConsulterRegistreArmes(pays).catch(() => []);
  }

  document.getElementById('postes-modal-title').textContent = 'Registre de vente d\'armes';
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

function doAcheterPoisonObjet(type) {
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
  html += '<button onclick="confirmerAchatPoison(&quot;' + type + '&quot;)" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.6rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Acheter</button>';
  html += '<button onclick="document.getElementById(&quot;modal-postes&quot;).classList.remove(&quot;open&quot;)" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.6rem;border:1px solid #3a2a10;background:transparent;color:#4a4030;cursor:pointer">Renoncer</button>';
  html += '</div></div></div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerAchatPoison(type) {
  const obj = POISON_OBJETS[type];
  if (!obj) return;
  const pays = state.country || 'republic';
  const cur = COUNTRIES[pays]?.cur || 'FR';

  document.getElementById('modal-postes').classList.remove('open');

  if (state.arg < obj.cout) { showToast('Fonds insuffisants', obj.cout + ' ' + cur + ' requis.', false); return; }

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
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.65rem;color:#cc4444">ÉLIMINER</div>';
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
    // Transmission reelle des PV a la victime via impacts_indices_attente
    if (pvCible !== null && typeof sbDeposerImpactIndice === 'function') {
      await sbDeposerImpactIndice({
        id: 'poison-' + Date.now(),
        victime: cibleNom,
        indice: 'hp_set',
        delta: pvCible,
        traite: false
      }).catch(() => {});
    }

    // Notification narrative a la victime (mail)
    if (typeof sbSendMail === 'function') {
      const msg = (POISON_MESSAGES && POISON_MESSAGES[poisonType]) || 'Vous vous sentez soudainement très mal...';
      const h = String(state.hour || 8).padStart(2,'0');
      await sbSendMail('Événement mystérieux', cibleNom, 'Vous vous sentez mal...', msg, 'Jour ' + state.day + ' · ' + h + 'h').catch(() => {});
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

function ouvrirRecruterInformateur(niveau) {
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
    '<button onclick="confirmerRecrutementInformateur(' + niveau + ')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.4rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Recruter</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerRecrutementInformateur(niveau) {
  document.getElementById('modal-postes').classList.remove('open');
  const cfg = INFORMATEUR_NIVEAUX[niveau];
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  if (state.arg < cfg.cout) {
    showToast('Fonds insuffisants', cfg.cout + ' ' + cur + ' requis.', false);
    return;
  }
  state.arg -= cfg.cout;
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

function consulterInformateur(niveau) {
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
    '<div style="font-size:.68rem;color:#4a4030;margin-top:.8rem;border-top:1px solid #2a2010;padding-top:.6rem">' +
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
    '<div style="font-size:.68rem;color:#4a4030;margin-top:.8rem">+' + Math.ceil(niveau/2) + ' INF · ' + INFORMATEUR_NIVEAUX[niveau]?.label + '</div>' +
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
      html += '<button onclick="congediерInformateur(' + i + ')" style="font-family:Bebas Neue,sans-serif;font-size:.65rem;padding:.25rem .5rem;border:1px solid #8a3a2a;background:transparent;color:#8a3a2a;cursor:pointer">Congédier</button>';
      html += '</div>';
    });
  }
  html += '<div style="font-size:.7rem;color:#4a4030;margin-top:.8rem">Maximum 2 informateurs simultanés.</div>';
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
  const dis = state.char?.stats?.DIS || state.dis || 50;
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
  let html = '<div style="padding:1rem">';

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
    html += '<div style="font-size:.85rem;color:#5a5040;font-style:italic">Aucune élection en cours ou programmée.</div>';
  } else {
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.5rem">ÉLECTIONS EN COURS / À VENIR</div>';
    elections.forEach(e => {
      const phaseCol = { candidatures:'#4a8a4a', campagne:'#C9A84C', depouillement:'#aa6a4a', termine:'#4a4030' }[e.phase] || '#8a8060';
      const phaseLabel = { candidatures:'Candidatures ouvertes', campagne:'Campagne en cours', depouillement:'Dépouillement', termine:'Terminée' }[e.phase] || e.phase;
      html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.7rem;margin-bottom:.5rem">';
      html += '<div style="display:flex;justify-content:space-between;align-items:center">';
      html += '<div style="font-family:Playfair Display,serif;font-size:.85rem;color:#E8C97A">' + e.nom + '</div>';
      html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.65rem;color:' + phaseCol + ';border:1px solid;padding:.1rem .3rem">' + phaseLabel + '</div>';
      html += '</div>';
      html += '<div style="font-size:.7rem;color:#5a4030;margin-top:.2rem">Tour ' + (e.tour||1) + ' · Résultats : Jour ' + e.jourResultat + '</div>';
      if (e.phase === 'candidatures') {
        html += '<div style="font-size:.7rem;color:#4a8a4a;margin-top:.2rem">✓ Candidatures encore acceptées</div>';
      } else if (e.phase === 'campagne') {
        html += '<div style="font-size:.7rem;color:#cc4444;margin-top:.2rem">✗ Candidatures fermées — campagne en cours</div>';
      }
      html += '</div>';
    });
  }

  // Prochaines elections prevues
  html += '<div style="font-size:.68rem;color:#4a4030;font-style:italic;margin-top:.6rem">Les candidatures ferment au début de la semaine 4. Après cette date, il n\'est plus possible de se présenter.</div>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function ouvrirGestionBudget() {
  // Reserve au Ministre des Finances
  const rep = state.repartitionBudget || { ...REPARTITION_DEFAULT };
  const noms = {
    presidence:'Presidence', min_int:'Min. Interieur', min_fin:'Min. Finances',
    min_just:'Min. Justice', min_def:'Min. Defense', min_info:'Min. Information',
    min_ae:'Min. AE', assemblee:'Assemblee', tribunal:'Tribunal',
    commissariat:'Commissariat', mairie:'Mairie', reserve:'Reserve'
  };

  document.getElementById('postes-modal-title').textContent = 'Repartition budgetaire';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Fixez le pourcentage des recettes fiscales attribue a chaque institution. Total doit etre 100%.</div>';

  let total = Object.values(rep).reduce((s, v) => s + v, 0);
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;color:' + (total === 100 ? '#4a8a4a' : '#cc4444') + ';margin-bottom:.6rem">TOTAL : ' + total + '% (doit etre 100%)</div>';

  Object.keys(rep).forEach(inst => {
    html += '<div style="display:flex;align-items:center;gap:.5rem;margin-bottom:.4rem">';
    html += '<div style="font-size:.78rem;color:#c0b090;width:120px">' + (noms[inst]||inst) + '</div>';
    html += '<input type="number" min="0" max="50" value="' + rep[inst] + '" id="budget-' + inst + '" onchange="majTotalBudget()" style="width:55px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.3rem;font-size:.82rem;outline:none">';
    html += '<span style="font-size:.72rem;color:#4a4030">%</span>';
    if (state.budgets?.[inst]) html += '<span style="font-size:.68rem;color:#5a5040;margin-left:.3rem">Solde: ' + (state.budgets[inst].solde||0).toLocaleString('fr-FR') + ' FR</span>';
    html += '</div>';
  });

  html += '<button onclick="validerRepartitionBudget()" style="margin-top:.8rem;font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Valider la repartition</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function majTotalBudget() {
  const rep = state.repartitionBudget || { ...REPARTITION_DEFAULT };
  let total = 0;
  Object.keys(rep).forEach(inst => {
    const val = parseInt(document.getElementById('budget-' + inst)?.value || '0');
    total += val;
  });
  // Mettre a jour l'affichage du total
  document.getElementById('postes-modal-title').textContent = 'Repartition — Total : ' + total + '%';
}

function validerRepartitionBudget() {
  const rep = state.repartitionBudget || { ...REPARTITION_DEFAULT };
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
  state.repartitionBudget = newRep;
  document.getElementById('modal-postes').classList.remove('open');
  showToast('Repartition validee !', 'Les nouveaux taux s\'appliqueront a partir de minuit.', true, true);
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

const BONUS_CARRIERE_VOL = {
  criminal_c: 15, unemployed: 15, intel: 15, escort: 15,
  magistrat: -10, lawyer: -10, officer: -10, clergy: -10, civil: -10, doctor: -10
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