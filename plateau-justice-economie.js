// =====================
// PLATEAU-JUSTICE-ECONOMIE.JS
// Plaintes, tribunal, prison, terrains, locations, budget, dons, falsification
// =====================

// DONNER DE L'ARGENT À UN PNJ
// =====================
function doDonnerArgentPnj() {
  const id = state.currentBuilding;
  const ts = getTerrainState(id);
  const pnj = ts.pnjData;
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  if (!pnj) {
    showToast('Personne ici', 'Aucun PNJ à qui donner quelque chose.', false);
    return;
  }

  const indices = INDICES_NATIONAUX?.[state.country] || { ISN:30, IE:50, ID:40, IS:45 };
  const isn = indices.ISN || 30;

  // Seuil minimum selon type de PNJ et ISN
  const seuils = {
    inspecteur: Math.floor(100 + isn * 2),
    gardien: Math.floor(50 + isn),
    squatter_agr: 500,
    squatter_cool: 0,
    promoteur: 0,
    cadavre: 0,
    default: 0
  };
  const seuilMin = seuils[pnj.id] || seuils.default;

  // PNJ incorruptibles selon ISN (inspecteur en Sovarka)
  const tauxRefus = Math.max(0, isn - 50) / 2;

  document.getElementById('postes-modal-title').textContent = 'Donner à ' + (pnj.name || 'ce PNJ');
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +
    '<div style="font-size:.78rem;color:#c0b090;margin-bottom:.6rem;font-style:italic">"' + (pnj.trait || '') + '"</div>' +
    (seuilMin > 0
      ? '<div style="font-size:.7rem;color:#8a6a30;margin-bottom:.5rem">Montant minimum suggéré : ' + seuilMin + ' ' + cur + '</div>'
      : '') +
    (tauxRefus > 0
      ? '<div style="font-size:.68rem;color:#8a3a2a;margin-bottom:.5rem">Risque de refus : ' + Math.round(tauxRefus) + '% (empire sécurisé)</div>'
      : '') +
    '<input id="don-montant" type="number" min="0" step="50" placeholder="Montant en ' + cur + '..." ' +
    'style="width:100%;padding:.4rem .6rem;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;font-family:Crimson Pro,Georgia,serif;font-size:.85rem;box-sizing:border-box;margin-bottom:.6rem"/>' +
    '<button onclick="confirmerDonArgent()" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">💰 Donner</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerDonArgent() {
  const id = state.currentBuilding;
  const ts = getTerrainState(id);
  const pnj = ts.pnjData;
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const montant = parseInt(document.getElementById('don-montant')?.value || 0);
  const indices = INDICES_NATIONAUX?.[state.country] || { ISN:30, IE:50, IS:45 };
  const isn = indices.ISN || 30;

  if (!montant || montant <= 0) { showToast('Montant invalide', 'Entrez un montant.', false); return; }
  if (state.arg < montant) { showToast('Fonds insuffisants', montant + ' ' + cur + ' requis.', false); return; }

  const dup = state.char?.stats?.DUP || 8;
  const dis = state.dis || 50;

  // Jet de refus selon ISN
  const tauxRefus = Math.max(0, isn - 50) / 2;
  const rollRefus = Math.floor(Math.random() * 100) + 1;

  document.getElementById('modal-postes').classList.remove('open');

  if (rollRefus <= tauxRefus) {
    // Refus — pénalité DIS
    state.dis = Math.max(0, (state.dis || 50) - 10);
    updateUI();
    addJournalEntry('Don refusé par ' + (pnj?.name || 'le PNJ') + '. -10 DIS. (Refus ' + rollRefus + '/' + Math.round(tauxRefus) + '%)', 'event-bad');
    showToast('Refus !', (pnj?.name || 'Le PNJ') + ' a refusé avec indignation. -10 DIS.', false);
    return;
  }

  // Don accepté — effets selon type de PNJ
  state.arg -= montant;

  const effets = {
    inspecteur: () => {
      // Corruption inspecteur — ferme les yeux sur les manquements
      const taux = Math.min(85, Math.floor(dup * 3 + montant / 50));
      const roll = Math.floor(Math.random() * 100) + 1;
      if (roll <= taux) {
        setTerrainState(id, { inspecteurCorrompu: true, permisImplicite: true });
        state.dis = Math.max(0, (state.dis || 50) - 5);
        updateUI();
        addJournalEntry('Inspecteur corrompu pour ' + montant + ' ' + cur + '. Manquements ignorés. -5 DIS.', 'event-good');
        showToast('Arrangement conclu !', 'L\'inspecteur regarde ailleurs. -5 DIS.', true);
        // Retirer le PNJ
        setTerrainState(id, { pnj: null, pnjData: null });
        sessionStorage.removeItem('terrain_pnj_' + id);
        if (state.currentRoom) enterRoom(state.currentBuilding, state.currentRoom);
      } else {
        state.dis = Math.max(0, (state.dis || 50) - 15);
        updateUI();
        addJournalEntry('Tentative de corruption échouée. -' + montant + ' ' + cur + ' · -15 DIS.', 'event-bad');
        showToast('Refus indigné !', 'L\'inspecteur menace de faire un rapport. -15 DIS.', false);
      }
    },
    gardien: () => {
      setTerrainState(id, { pnj: null, pnjData: null });
      sessionStorage.removeItem('terrain_pnj_' + id);
      state.dis = Math.min(100, (state.dis || 50) + 3);
      updateUI();
      addJournalEntry('Gardien soudoyé pour ' + montant + ' ' + cur + '. +3 DIS.', 'event-good');
      showToast('Gardien convaincu !', 'Il regarde ailleurs. +3 DIS.', true);
      if (state.currentRoom) enterRoom(state.currentBuilding, state.currentRoom);
    },
    squatter_cool: () => {
      const bonus = Math.min(40, Math.floor(montant / 100));
      const cha = state.char?.stats?.CHA || 8;
      const taux = Math.min(85, cha * 3 + bonus);
      const roll = Math.floor(Math.random() * 100) + 1;
      if (roll <= taux) {
        setTerrainState(id, { pnj: null, pnjData: null });
        sessionStorage.removeItem('terrain_pnj_' + id);
        updateUI();
        addJournalEntry('Squatteurs partis pour ' + montant + ' ' + cur + '. Jet ' + roll + '/' + taux + '%.', 'event-good');
        showToast('Ils s\'en vont !', '"Ok on se casse. Ciao." -' + montant + ' ' + cur, true);
        if (state.currentRoom) enterRoom(state.currentBuilding, state.currentRoom);
      } else {
        updateUI();
        showToast('Ils prennent l\'argent mais restent...', '-' + montant + ' ' + cur, false);
        addJournalEntry('Squatteurs ont pris ' + montant + ' ' + cur + ' mais refusent de partir. Jet ' + roll + '/' + taux + '%.', 'event-bad');
      }
    },
    squatter_agr: () => {
      if (montant < 500) {
        state.arg += montant; // Rembourser
        showToast('Insulté !', 'Ils ont jeté vos billets. Minimum 500 ' + cur + '.', false);
        return;
      }
      const bonus = Math.min(40, Math.floor(montant / 100));
      const taux = Math.min(70, 15 + bonus);
      const roll = Math.floor(Math.random() * 100) + 1;
      if (roll <= taux) {
        setTerrainState(id, { pnj: null, pnjData: null });
        sessionStorage.removeItem('terrain_pnj_' + id);
        updateUI();
        addJournalEntry('Squatteurs agressifs partis pour ' + montant + ' ' + cur + '. Jet ' + roll + '/' + taux + '%.', 'event-good');
        showToast('Ils partent !', '"On se casse. Cette fois." -' + montant + ' ' + cur, true);
        if (state.currentRoom) enterRoom(state.currentBuilding, state.currentRoom);
      } else {
        state.hp = Math.max(0, (state.hp || 100) - 10);
        updateUI();
        addJournalEntry('Squatteurs ont pris ' + montant + ' ' + cur + ' et vous ont frappé. -10 HP.', 'event-bad');
        showToast('Volés et tabassés !', '-' + montant + ' ' + cur + ' · -10 HP.', false);
      }
    },
    promoteur: () => {
      // Le promoteur révèle des infos
      state.inf = Math.min(100, (state.inf || 0) + 5);
      updateUI();
      addJournalEntry('Gérard Spéculos vous donne des infos sur le marché pour ' + montant + ' ' + cur + '. +5 INF.', 'event-good');
      showToast('Info obtenue !', '+5 INF. Il sait des choses sur ce quartier.', true);
    },
    default: () => {
      updateUI();
      addJournalEntry('Don de ' + montant + ' ' + cur + ' accepté.', 'event-info');
      showToast('Don accepté', (pnj?.name || 'Le PNJ') + ' apprécie le geste.', true);
    }
  };

  (effets[pnj?.id] || effets.default)();
}

// Expulsion légale via police (sans soudoiement)
function doExpulsionLegale() {
  const id = state.currentBuilding;
  const ts = getTerrainState(id);
  const indices = INDICES_NATIONAUX?.[state.country] || { ISN:30 };
  const isn = indices.ISN || 30;

  // Délai selon ISN — plus ISN est élevé, plus c'est rapide
  const delaiH = Math.max(6, Math.round(96 - isn * 0.6));
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  // Ajouter l'inspecteur de police comme PNJ visible
  const pnjPolice = (TERRAIN_PNJ_PROFILES?.[state.country] || TERRAIN_PNJ_PROFILES?.republic || [])
    .find(p => p.id === 'inspecteur_police') || {
      name: 'L\'Inspecteur', role: 'Inspecteur de police', job: 'commissaire',
      rel: 'neutral', trait: 'Arrive quand on l\'appelle. Prend note. Repart.'
    };

  // Stocker la demande d'expulsion
  setTerrainState(id, {
    expulsionDemandeeAt: Date.now(),
    expulsionAt: Date.now() + delaiH * 3600000,
    pnjPolice: pnjPolice
  });

  // Afficher l'inspecteur de police dans la pièce temporairement
  const pnjPoliceSession = {
    name: pnjPolice.name + ' (PNJ)',
    role: pnjPolice.role,
    job: pnjPolice.job,
    rel: pnjPolice.rel,
    trait: pnjPolice.trait,
    photoUrl: pnjPolice.photoUrl,
    photoPos: pnjPolice.photoPos,
    terrainPnjId: 'inspecteur_police'
  };
  sessionStorage.setItem('terrain_pnj_police_' + id, JSON.stringify(pnjPoliceSession));

  addJournalEntry('Expulsion légale demandée. L\'inspecteur est sur place. Résolution dans ' + delaiH + 'h.', 'event-info');
  showToast('Police sur place', 'Expulsion dans ' + delaiH + 'h. Soudoyez l\'inspecteur pour accélérer.', true);

  if (state.currentRoom) enterRoom(state.currentBuilding, state.currentRoom);
}

// =====================
// RACHAT DE TERRAIN ENTRE PJ
// =====================
function doRacheterTerrain() {
  const building = state.currentBuilding;
  const b = BUILDINGS[building];
  if (!b) return;

  // Vérifier si le terrain appartient à quelqu'un
  const proprietaire = state.terrainsAchetes?.[building];
  if (!proprietaire) {
    showToast('Terrain libre', 'Ce terrain n\'est pas encore propriété privée. Vous pouvez l\'acheter directement.', false);
    return;
  }
  if (proprietaire === state.char?.name) {
    showToast('Votre terrain', 'Ce terrain vous appartient déjà.', false);
    return;
  }

  const cur = COUNTRIES[state.country]?.cur || 'FR';

  // Ouvrir modal pour saisir le prix
  document.getElementById('postes-modal-title').textContent = 'Offre de rachat';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1rem">' +
    '<div style="font-size:.82rem;color:#a09060;margin-bottom:.8rem">Ce terrain appartient à <strong style="color:#C9A84C">' + proprietaire + '</strong>.<br>Proposez un prix de rachat. Un mail lui sera envoyé automatiquement.</div>' +
    '<input id="rachat-prix" type="number" min="1000" step="500" placeholder="Prix proposé en ' + cur + '..." style="width:100%;padding:.4rem .6rem;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;font-family:Crimson Pro,Georgia,serif;font-size:.85rem;box-sizing:border-box;margin-bottom:.6rem"/>' +
    '<button onclick="confirmerRachat(this)" data-building="' + building + '" data-proprio="' + proprietaire + '" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer;width:100%">Envoyer l\'offre</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerRachat(btn) {
  const buildingId = btn?.dataset?.building || btn;
  const proprietaire = btn?.dataset?.proprio || arguments[1];
  const prix = parseInt(document.getElementById('rachat-prix')?.value || 0);
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const b = BUILDINGS[buildingId];
  const localName = b?.shortName || b?.name || buildingId;

  if (!prix || prix < 1000) {
    showToast('Prix invalide', 'Proposez au moins 1000 ' + cur + '.', false);
    return;
  }
  if (state.arg < prix) {
    showToast('Fonds insuffisants', 'Vous n\'avez pas ' + prix.toLocaleString('fr-FR') + ' ' + cur + '.', false);
    return;
  }

  // Envoyer un mail au propriétaire
  const from = state.char?.name || 'Anonyme';
  const subject = 'Offre de rachat — ' + localName;
  const body = from + ' vous propose de racheter votre terrain "' + localName + '" pour <strong>' + prix.toLocaleString('fr-FR') + ' ' + cur + '</strong>.<br><br>Pour accepter, répondez à ce mail en indiquant "J\'accepte". Le transfert sera effectué par la mairie.';

  if (typeof sendMail === 'function') {
    await sendMail(proprietaire, subject, body);
  }

  document.getElementById('modal-postes').classList.remove('open');
  addJournalEntry('Offre de rachat envoyée à ' + proprietaire + ' pour ' + prix.toLocaleString('fr-FR') + ' ' + cur + '.', 'event-info');
  showToast('Offre envoyée !', proprietaire + ' a reçu votre proposition.', true);
}

function accepterRachat(acheteur, buildingId, prix) {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const b = BUILDINGS[buildingId];
  const localName = b?.shortName || b?.name || buildingId;

  // Transférer le terrain
  if (!state.terrainsAchetes) state.terrainsAchetes = {};
  state.terrainsAchetes[buildingId] = acheteur;
  state.arg += prix;
  updateUI();

  addJournalEntry('Terrain "' + localName + '" vendu à ' + acheteur + ' pour ' + prix.toLocaleString('fr-FR') + ' ' + cur + '.', 'event-good');
  showToast('Terrain vendu !', '+' + prix.toLocaleString('fr-FR') + ' ' + cur, true);

  // Notifier l'acheteur
  if (typeof sendMail === 'function') {
    sendMail(acheteur, 'Transfert de propriété — ' + localName,
      'Votre offre a été acceptée. Le terrain "' + localName + '" vous appartient désormais.');
  }
}

// =====================

// PLAINTE MODALE
// =====================
function openPlainteModal() {
  const contacts = state.contacts || [];

  const contactsSection = contacts.length === 0
    ? `<div style="font-size:.8rem;color:#7a5020;font-style:italic;padding:.5rem;background:#0f0805;border:1px solid #2a1810">
        Votre repertoire est vide. Veuillez prealablement enregistrer la personne que vous ciblez dans celui-ci.
       </div>`
    : contacts.map(c => `
        <label style="display:flex;align-items:center;gap:.5rem;font-size:.85rem;color:#c0b090;cursor:pointer;padding:.2rem 0">
          <input type="radio" name="plainte-cible" value="${c.name}" style="accent-color:#C9A84C"/>
          ${c.name} — ${c.role || ''}
        </label>`).join('');

  const modalHtml = `
    <div style="padding:1rem">
      <div style="font-size:.85rem;color:#8a8060;font-style:italic;margin-bottom:1rem">
        Vous deposez une plainte. Un resultat vous sera communique par mail dans 24h.
      </div>
      <div style="margin-bottom:1rem">
        <div style="font-family:'Bebas Neue',sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.5rem">CONTRE</div>
        <label style="display:flex;align-items:center;gap:.5rem;font-size:.85rem;color:#c0b090;cursor:pointer;margin-bottom:.6rem">
          <input type="radio" name="plainte-cible" value="X" checked style="accent-color:#C9A84C"/>
          Contre X (personne inconnue)
        </label>
        <div style="font-family:'Bebas Neue',sans-serif;font-size:.68rem;letter-spacing:.1em;color:#5a4a20;margin-bottom:.4rem">OU CONTRE UNE PERSONNE DE MON REPERTOIRE :</div>
        ${contactsSection}
      </div>
      <div style="margin-bottom:1rem">
        <div style="font-family:'Bebas Neue',sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">MOTIF</div>
        <textarea id="plainte-motif" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.6rem;font-family:'Crimson Pro',serif;font-size:.85rem;height:70px;outline:none;resize:none" placeholder="Decrivez les faits reproches..."></textarea>
      </div>
      <button onclick="soumettrePlaynte()" style="font-family:'Bebas Neue',sans-serif;letter-spacing:.1em;font-size:.82rem;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">
        <i class="ti ti-send" style="font-size:.8rem"></i> Deposer la plainte
      </button>
    </div>
  `;

  document.getElementById('postes-modal-title').textContent = 'Porter plainte';
  document.getElementById('postes-body').innerHTML = modalHtml;
  document.getElementById('modal-postes').classList.add('open');
}

function soumettrePlaynte() {
  const cible = document.querySelector('input[name="plainte-cible"]:checked')?.value || 'X';
  const motif = document.getElementById('plainte-motif')?.value?.trim() || 'Motif non precise';
  document.getElementById('modal-postes').classList.remove('open');

  const h = String(state.hour).padStart(2,'0');
  const m = String(state.minute||0).padStart(2,'0');
  const resultH = (state.hour + 24) % 24;

  addJournalEntry(`Plainte deposee contre ${cible}. Motif : ${motif}. Vous serez informe du resultat demain a ${String(resultH).padStart(2,'0')}h${m}.`, 'event-info');
  showToast('Plainte enregistree', `Resultat communique demain a ${String(resultH).padStart(2,'0')}h${m}.`, true);

  // Simuler le resultat 24h apres (en jeu = apres l'ordre dormir)
  if (!state.plaintesEnCours) state.plaintesEnCours = [];
  const nouvellePlainte = {
    id: 'plainte-' + Date.now(),
    country: state.country,
    city: state.currentCity,
    cible, motif,
    heure: `${String(resultH).padStart(2,'0')}h${m}`,
    day: state.day + 1,
    status: 'pending'
  };
  state.plaintesEnCours.push(nouvellePlainte);
  if (typeof sbSavePlainte === 'function') sbSavePlainte(nouvellePlainte).catch(() => {});
}

function traiterPlaintes() {
  if (!state.plaintesEnCours) return;
  const traitees = state.plaintesEnCours.filter(p => p.day <= state.day && p.status === 'pending');
  traitees.forEach(p => {
    p.status = 'done';
    const roll = Math.floor(Math.random() * 100) + 1;
    let result = '';
    if (roll < 40) {
      result = `Classement sans suite. La plainte contre ${p.cible} n'a pas abouti.`;
    } else if (roll < 75) {
      result = `Ouverture d'une enquete concernant ${p.cible}. Conclusions dans 24h.`;
      // Programmer le resultat de l'enquete (motif transporte pour le tribunal)
      if (!state.enquetesEnCours) state.enquetesEnCours = [];
      state.enquetesEnCours.push({ cible: p.cible, motif: p.motif, day: state.day + 1, status: 'pending' });
    } else {
      result = `Actes illegaux confirmes pour ${p.cible}. Mise en garde a vue. Proces dans 24h.`;
      addExternalEvent(`ACTION EXTERIEURE : ${p.cible} a ete place(e) en garde a vue suite a votre plainte. Proces prevu demain.`, 'local');
      // Transmettre directement au tribunal — l'affaire est mure pour jugement
      transmettreAffaireAuTribunal(p.cible, p.motif || 'Plainte initiale confirmee par les forces de l\'ordre.');
    }
    addMailNotification('Commissariat Central', `RE: Votre plainte du Jour ${p.day - 1}`, result);
    if (typeof sbSavePlainte === 'function') sbSavePlainte(p).catch(() => {});
  });
}

function traiterEnquetes() {
  if (!state.enquetesEnCours) return;
  const traitees = state.enquetesEnCours.filter(e => e.day <= state.day && e.status === 'pending');
  traitees.forEach(e => {
    e.status = 'done';
    const roll = Math.floor(Math.random() * 100) + 1;
    let result = '';
    if (roll < 50) {
      result = `Enquete conclue : non-lieu pour ${e.cible}. Aucune preuve suffisante.`;
    } else {
      result = `Enquete conclue : actes illegaux confirmes pour ${e.cible}. Mise en garde a vue immediate. Affaire transmise au tribunal pour jugement.`;
      if (!state.prisonniers) state.prisonniers = [];
      state.prisonniers.push({ nom: e.cible, depuis: `Jour ${state.day}`, raison: 'Garde a vue suite a enquete' });
      addExternalEvent(`${e.cible} a ete place(e) en garde a vue. Affaire transmise au tribunal.`, 'local');
      // Transmettre au tribunal pour jugement public
      transmettreAffaireAuTribunal(e.cible, e.motif || 'Enquete policiere ayant confirme des actes illegaux.');
    }
    addMailNotification('Brigade Criminelle', `Conclusions enquete : ${e.cible}`, result);
  });
}

// =====================
// PONT COMMISSARIAT → TRIBUNAL
// Transmet une affaire confirmee pour jugement public (forum + file d'attente du juge)
// =====================
function transmettreAffaireAuTribunal(cible, motif) {
  const ville = WORLD[state.country]?.[state.currentCity]?.name || 'la ville';
  const forumKey = 'tribunal_' + state.currentCity;

  // Ajouter à la file d'attente du juge (statut lu par ouvrirRendreSentence) — visible par TOUS les juges via Supabase
  if (!state.plaintesEnCours) state.plaintesEnCours = [];
  const affaireTransmise = { id: 'affaire-' + Date.now(), country: state.country, city: state.currentCity, cible, motif, jour: state.day, status: 'deposee' };
  state.plaintesEnCours.push(affaireTransmise);
  if (typeof sbSavePlainte === 'function') sbSavePlainte(affaireTransmise).catch(() => {});

  // Publier sur le forum tribunal local (visible de tous, transparence judiciaire)
  if (!FORUM_TOPICS[forumKey]) FORUM_TOPICS[forumKey] = [];
  FORUM_TOPICS[forumKey].unshift({
    id: 'affaire-' + Date.now(),
    title: '[AFFAIRE TRANSMISE] ' + cible,
    author: 'Brigade Criminelle',
    time: 'Jour ' + (state.day || 1),
    replies: 0,
    isPlainte: true,
    cible,
    posts: [{
      author: 'Brigade Criminelle',
      time: 'Jour ' + (state.day || 1),
      content: '**AFFAIRE TRANSMISE AU TRIBUNAL**\n\nMis en cause : ' + cible + '\n\nMotif :\n' + motif + '\n\n_En attente de jugement par un magistrat._'
    }]
  });

  // Publier aussi sur Supabase pour que tous les joueurs de la ville le voient
  if (typeof sbCreateTopic === 'function') {
    const auteur = 'Brigade Criminelle';
    const heure = 'Jour ' + (state.day || 1);
    const textePost = '**AFFAIRE TRANSMISE AU TRIBUNAL**\n\nMis en cause : ' + cible + '\n\nMotif :\n' + motif + '\n\n_En attente de jugement par un magistrat._';
    sbCreateTopic(forumKey, '⚖️ [AFFAIRE] ' + cible, auteur, state.country, heure)
      .then(topicId => {
        if (topicId && typeof sbCreatePost === 'function') {
          sbCreatePost(topicId, auteur, textePost, heure);
        }
      }).catch(e => console.warn('Erreur transmission tribunal:', e));
  }
}

// Ajouter evenement externe (rouge + gras + point clignotant)
// =====================
// MARCHE — ORDRES SPECIFIQUES
// =====================
async function doPoulsPopulaire() {
  addJournalEntry('Vous interrogez les passants du marche...', '');
  showToast('Sondage en cours', 'Les habitants parlent...', true);

  // Generer un sondage via IA
  const char = state.char;
  const co = COUNTRIES[state.country];
  const prompt = `Tu es un narrateur dans un jeu de role politique parodique (Res Publica, empire ${co?.n}).
Genere un court sondage d'opinion populaire (2-3 phrases) comme si tu etais un habitant du marche.
${state.electionsEnCours?.length > 0
  ? `Il y a des elections en cours avec ces candidats : ${state.electionsEnCours.map(e => e.candidats?.join(', ')).join(' | ')}. Donne un resultat en pourcentages.`
  : `Pas d'election en cours. Parle de la popularite des personnages politiques connus : ${state.pjConnus?.join(', ') || 'personne de particulier'}.`
}
Style : direct, populaire, parodique. Format : phrase construite du genre "D'apres ce qu'on entend, X serait le plus populaire..." Reponds uniquement avec le sondage.`;

  try {
    const resp = await fetch('/api/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ model: 'claude-sonnet-4-5', max_tokens: 150, messages: [{ role: 'user', content: prompt }] })
    });
    const data = await resp.json();
    const text = data.content?.[0]?.text;
    if (text) {
      showToast('Pouls de la population', text.substring(0, 100), true);
      addJournalEntry('Sondage : ' + text, 'event-info');
    }
  } catch(e) {
    const fallback = `D'apres les habitants, la situation politique est tendue. "On ne sait plus qui croire", dit une marchande.`;
    showToast('Pouls de la population', fallback, true);
    addJournalEntry('Sondage : ' + fallback, 'event-info');
  }
}

function doDistribuerTract() {
  const tracts = state.inventory.filter(i => i.type === 'tract');
  if (tracts.length === 0) {
    showToast('Aucun tract', 'Vous n\'avez pas de tract en inventaire. Faites-en imprimer a l\'imprimerie.', false);
    return;
  }
  const roll = Math.floor(Math.random() * 100) + 1;
  if (roll <= 70) {
    state.pop = Math.min(100, state.pop + 2);
    tracts[0].qty = (tracts[0].qty || 1) - 1;
    if (tracts[0].qty <= 0) state.inventory = state.inventory.filter(i => i !== tracts[0]);
    updateUI();
    addJournalEntry('Vous avez distribue des tracts. +2 POP.', 'event-good');
    showToast('Tracts distribues', '+2 Popularite. Les passants prennent vos tracts.', true);
  } else {
    addJournalEntry('Distribution de tracts peu efficace. Les passants ignorent vos tracts.', '');
    showToast('Distribution difficile', 'Les passants ne s\'y interessent pas beaucoup.', false);
  }
}

const BONUS_ARCHETYPE_FAUSSE_RUMEUR = {
  shadow: 15, criminal: 15, informer: 5
  // tous les autres archetypes : 0
};

function getCoutFausseRumeur() {
  const ie = INDICES_NATIONAUX[state.country]?.IE || 40;
  return 300 + ie * 5;
}

function getTauxFausseRumeur() {
  const dup = state.char?.stats?.DUP || 8;
  const bonusArch = BONUS_ARCHETYPE_FAUSSE_RUMEUR[state.char?.archetype] || 0;
  return Math.max(5, Math.min(90, 20 + dup * 2 + bonusArch));
}

async function openRumeurModal() {
  const cout = getCoutFausseRumeur();
  const taux = getTauxFausseRumeur();
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  let joueurs = [];
  if (typeof sbListPersonnages === 'function') {
    try { joueurs = (await sbListPersonnages() || []).filter(j => j.name !== state.char?.name); } catch(e) {}
  }

  document.getElementById('postes-modal-title').textContent = 'Créer une fausse rumeur';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.82rem;color:#aa7a30;font-style:italic;margin-bottom:.8rem;padding:.5rem;background:#0f0d05;border:1px solid #3a2810">Acte illégal. Coût : ' + cout + ' ' + cur + '. Chances de réussite : ' + taux + '%. Détectable après enquête.</div>';

  if (joueurs.length === 0) {
    html += '<div style="font-size:.85rem;color:#5a5040">Aucun habitant connu pour le moment.</div>';
  } else {
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">CIBLE</div>';
    html += '<select id="fausse-rumeur-cible" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.8rem">';
    joueurs.forEach(j => { html += '<option value="' + j.name + '">' + j.name + '</option>'; });
    html += '</select>';
    html += '<button onclick="confirmerFausseRumeur(' + cout + ',' + taux + ')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #aa7a30;background:transparent;color:#C9A84C;cursor:pointer">Répandre la rumeur</button>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerFausseRumeur(cout, taux) {
  const cible = document.getElementById('fausse-rumeur-cible')?.value;
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  document.getElementById('modal-postes').classList.remove('open');
  if (!cible) { showToast('Sélectionnez une cible', '', false); return; }
  if (state.arg < cout) { showToast('Fonds insuffisants', cout + ' ' + cur + ' requis.', false); return; }

  state.arg -= cout;
  updateUI();

  const roll = Math.floor(Math.random() * 100) + 1;
  if (roll <= taux) {
    // SUCCES — la victime perd INF/POP, le lanceur en gagne un peu (discredit reussi)
    state.inf = Math.min(100, (state.inf || 0) + 3);
    state.pop = Math.min(100, (state.pop || 0) + 2);

    // Deposer l'impact negatif sur la victime (applique a sa prochaine connexion)
    if (typeof sbDeposerImpactIndice === 'function') {
      await sbDeposerImpactIndice({ id: 'impact-' + Date.now() + '-pop', victime: cible, indice: 'pop', delta: -6, raison: 'Rumeur compromettante', traite: false }).catch(() => {});
      await sbDeposerImpactIndice({ id: 'impact-' + Date.now() + '-inf', victime: cible, indice: 'inf', delta: -4, raison: 'Rumeur compromettante', traite: false }).catch(() => {});
    }

    if (typeof sbSendMail === 'function') {
      const h = String(state.hour || 8).padStart(2,'0');
      const time = 'Jour ' + (state.day || 1) + ' · ' + h + 'h';
      sbSendMail('Système', cible, 'Rumeur en circulation',
        'Une rumeur compromettante circule actuellement à votre sujet. Difficile de savoir qui en est à l\'origine. -6 POP, -4 INF.', time).catch(() => {});
    }
    updateUI();
    showToast('Rumeur lancée', 'La rumeur sur ' + cible + ' se répand. +3 INF, +2 POP pour vous ; -6 POP, -4 INF pour la victime.', true, true);
    addJournalEntry('Fausse rumeur lancée sur ' + cible + '. Succès.', 'event-good');
    checkDetection('fausse_rumeur', 'success');
  } else {
    showToast('Rumeur sans effet', 'Personne n\'a vraiment cru cette histoire.', false);
    addJournalEntry('Tentative de fausse rumeur sur ' + cible + '. Échec.', '');
    checkDetection('fausse_rumeur', 'fail');
  }
}

// =====================

// BUDGET INSTITUTIONS
// =====================


function depenseBudget(institution, montant) {
  const b = getBudgetInstitution(institution);
  if (!b) return true;
  if (b.solde < montant) {
    showToast('Budget insuffisant', institution + ' manque de fonds. Le ministre des Finances doit revoir la repartition.', false);
    addExternalEvent('L\'institution ' + institution + ' est sous-financee. Certains services sont suspendus.');
    return false;
  }
  b.solde -= montant;
  return true;
}

function mettreAJourBudgets() {
  if (!state.budgetsActuels) return;
  // Recettes fiscales allouees aux institutions
  const pop = CITY_POPULATION[state.country]?.[state.currentCity];
  if (!pop) return;
  const recettes = pop.dailyTaxRevenue || 0;
  const allocation = Math.floor(recettes * 0.4); // 40% des recettes aux institutions
  Object.keys(state.budgetsActuels).forEach(key => {
    if (key.startsWith(state.currentCity)) {
      state.budgetsActuels[key].budget = Math.min(
        state.budgetsActuels[key].budget + Math.floor(allocation / 3),
        20000
      );
    }
  });
}

// =====================
// POPULATION DYNAMIQUE
// =====================
function mettreAJourPopulation() {
  Object.keys(CITY_POPULATION[state.country] || {}).forEach(cityId => {
    const pop = CITY_POPULATION[state.country][cityId];
    if (!pop) return;
    // Regeneration lente : +0.1% par jour
    const regen = Math.floor(pop.total * 0.001);
    pop.total = Math.min(pop.totalMax || pop.total * 1.5, pop.total + regen);
    // Recalculer les impots
    pop.dailyTaxRevenue = Math.floor(pop.total * pop.taxRate / 365);
  });
}


// SYSTEME D'ARRESTATION
// =====================
const PEINES = {
  delit_mineur:   { jours: 2,  label: 'Delit mineur',   amendeBase: 500  },
  delit_grave:    { jours: 4,  label: 'Delit grave',     amendeBase: 1500 },
  crime:          { jours: 8,  label: 'Crime',           amendeBase: 5000 },
  crime_etat:     { jours: 30, label: "Crime d'Etat",    amendeBase: 0    }
};

const ACTES_ILLEGAUX = {
  corrompre_fonct:    { type: 'delit_mineur',  detectRate: 30 },
  corrompre_police:   { type: 'delit_mineur',  detectRate: 35 },
  corrompre_juge:     { type: 'delit_grave',   detectRate: 40 },
  corrompre_journaliste:{ type: 'delit_mineur',detectRate: 25 },
  blanchiment:        { type: 'delit_grave',   detectRate: 35 },
  societe_ecran:      { type: 'delit_mineur',  detectRate: 25 },
  falsifier_docs:     { type: 'delit_grave',   detectRate: 40 },
  acheter_arme_illegale:{ type: 'delit_mineur',detectRate: 20 },
  acheter_bombe_illegale:{ type: 'crime',      detectRate: 55 },
  fabriquer_bombe:    { type: 'crime',         detectRate: 60 },
  incendier:          { type: 'crime',         detectRate: 70 },
  arreter:            { type: 'delit_grave',   detectRate: 40 },
  fabriquer_scandale: { type: 'delit_grave',   detectRate: 45 },
  fuite_info:         { type: 'delit_grave',   detectRate: 40 },
  imprimer_clandestin:{ type: 'delit_mineur',  detectRate: 30 },
  tentative_evasion:  { type: 'crime',         detectRate: 90 },
  se_rebeller:        { type: 'delit_mineur',  detectRate: 60 },
  fausse_rumeur:      { type: 'delit_mineur',  detectRate: 35 },
  vol:                { type: 'delit_mineur',  detectRate: 30 }
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

function checkArrestationAuReveil() {
  // Chance reduite d'arrestation pendant la nuit
  if (!state.recherche || state.recherche.length === 0) return;
  const roll = Math.floor(Math.random() * 100) + 1;
  if (roll <= 10) {
    const alerteMax = state.recherche[state.recherche.length - 1]?.type || 'delit_mineur';
    addExternalEvent('La police a retrouve votre trace. Vous avez ete arrete(e) dans la nuit.');
    procederArrestation(alerteMax, false);
  }
}

function ouvrirModalArrestation(peineType) {
  const peine = PEINES[peineType] || PEINES.delit_mineur;
  const country = state.country || 'republic';

  // Répliques situationnelles par empire
  const repliques = {
    republic: [
      "Veuillez me suivre, s'il vous plaît. Formulaire 47-B à remplir au commissariat. En triple.",
      "Vous êtes en état d'arrestation. Votre droit au silence est garanti — personne ne vous écoutera de toute façon.",
      "J'ai un mandat. Enfin, j'ai quelque chose. C'est peut-être mon ticket de métro. Suivez-moi quand même."
    ],
    narco: [
      "Dura lex, cède ta Rolex. ¡Vámonos!",
      "El Don dit que la loi s'applique à tout le monde. Sauf à ceux qui paient. Vous payez ?",
      "Alto ! Police d'El Estado. Vos mains, votre portefeuille, dans l'ordre que vous préférez."
    ],
    soviet: [
      "Camarade, vous êtes en état d'arrestation révolutionnaire. Formulaire B-47 en quadruple exemplaire.",
      "Le Parti a été informé de vos activités déviantes. Veuillez nous suivre pour rééducation volontaire obligatoire.",
      "Halte au nom du Peuple ! Vos papiers, votre loyauté, votre betterave du jour."
    ],
    khalija: [
      "Que la grâce du Loukoum Divin soit sur vous, mais pas sur vos activités. Veuillez nous suivre.",
      "Le Sheikh, dans son infinie sagesse pâtissière, a ordonné votre arrestation. C'est un honneur.",
      "Par décret royal et au nom du Loukoum Sacré, vous êtes arrêté(e). Le protocole l'exige."
    ]
  };

  const replique = repliques[country][Math.floor(Math.random() * 3)];

  // Coût corruption selon empire
  const coutCorruption = { republic: 500, narco: 200, soviet: 800, khalija: 600 };
  const cout = coutCorruption[country] || 500;
  const cur = (window.COUNTRIES?.[country]?.cur) || 'FR';
  const tauxCorruption = { republic: 45, narco: 75, soviet: 20, khalija: 50 };
  const taux = tauxCorruption[country] || 45;

  document.getElementById('postes-modal-title').textContent = 'Interception policière !';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1rem">' +
    '<div style="font-size:.82rem;color:#8a8060;font-style:italic;font-family:Crimson Pro,Georgia,serif;border-left:2px solid #8a3a2a;padding-left:.6rem;margin-bottom:.8rem">"' + replique + '"</div>' +
    '<div style="font-size:.88rem;color:#cc4444;font-family:Playfair Display,serif;margin-bottom:.4rem">Chef d\'inculpation : ' + peine.label + '</div>' +
    '<div style="font-size:.78rem;color:#8a8060;margin-bottom:1rem">Peine encourue : ' + peine.jours + ' jour(s) d\'emprisonnement.</div>' +
    '<div style="display:flex;flex-direction:column;gap:.5rem">' +
    '<button onclick="procederArrestation(\'' + peineType + '\',false);document.getElementById(\'modal-postes\').classList.remove(\'open\')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1rem;border:1px solid #4a6a4a;background:transparent;color:#6a9a6a;cursor:pointer"><i class="ti ti-check" style="font-size:.8rem"></i> Se rendre</button>' +
    '<button onclick="tenterCorruptionArrestation(\'' + peineType + '\',' + cout + ',' + taux + ')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer"><i class="ti ti-coin" style="font-size:.8rem"></i> Corrompre l\'agent (' + cout + ' ' + cur + ' · ' + taux + '%)</button>' +
    '<button onclick="tenterFuite()" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1rem;border:1px solid #8a6a20;background:transparent;color:#8a8060;cursor:pointer"><i class="ti ti-run" style="font-size:.8rem"></i> Fuir (VOL+DIS)</button>' +
    '<button onclick="tenterResistance(\'' + peineType + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1rem;border:1px solid #8a2020;background:transparent;color:#cc4444;cursor:pointer"><i class="ti ti-sword" style="font-size:.8rem"></i> Résister (très risqué)</button>' +
    '</div></div>';
  document.getElementById('modal-postes').classList.add('open');
}

function tenterCorruptionArrestation(peineType, cout, taux) {
  const country = state.country || 'republic';
  const cur = (window.COUNTRIES?.[country]?.cur) || 'FR';

  if (state.arg < cout) {
    showToast('Fonds insuffisants', `Il vous faut ${cout} ${cur} pour corrompre l'gent.`, false);
    return;
  }

  state.arg -= cout;
  const dup = state.char?.stats?.DUP || 8;
  const bonus = Math.floor(dup / 10) * 5;
  const roll = Math.floor(Math.random() * 100) + 1;
  const tauxFinal = Math.min(85, taux + bonus);

  // Répliques succès/échec par empire
  const succesRepliques = {
    republic: "Très bien. Je n'ai rien vu. Je ne vois d'ailleurs jamais rien le mercredi.",
    narco:    "¡Excelente! El Don dit que la générosité est une vertu. Bonne journée, señor.",
    soviet:   "Le formulaire d'arrestation se sera... égaré. Ça arrive. Bonne journée, Camarade.",
    khalija:  "Que le Loukoum Divin bénisse votre générosité. Le Chambellan n'a rien remarqué."
  };
  const echecRepliques = {
    republic: "Comment osez-vous ? Ajoutez 'tentative de corruption' au dossier. Et doublez la mise.",
    narco:    "¡Dios mío! Vous croyez que je suis corruptible ? Doublez et on en reparle.",
    soviet:   "Trahison contre-révolutionnaire ! Formulaire de corruption en quadruple. Plus deux ans.",
    khalija:  "Ô impudent ! Ceci est une insulte au protocole royal. Et le montant était insuffisant."
  };

  document.getElementById('modal-postes').classList.remove('open');

  if (roll <= tauxFinal) {
    state.dis = Math.max(0, state.dis - 10);
    updateUI();
    const rep = succesRepliques[country] || succesRepliques.republic;
    showToast('Corruption réussie !', `"${rep}"`, true, true);
    addJournalEntry(`Corruption réussie. -${cout} ${cur} · -10 DIS. Vous êtes libre.`, 'event-good');
    // Effacer une infraction
    if (state.recherche?.length > 0) state.recherche.pop();
  } else {
    state.dis = Math.max(0, state.dis - 15);
    updateUI();
    const rep = echecRepliques[country] || echecRepliques.republic;
    showToast('Corruption ratée !', `"${rep}"`, false);
    addJournalEntry(`Tentative de corruption échouée. -${cout} ${cur} · -15 DIS. Arrestation aggravée.`, 'event-bad');
    procederArrestation(peineType, true);
  }
}

function procederArrestation(peineType, resistanceAggravante) {
  const peine = PEINES[peineType] || PEINES.delit_mineur;
  const jours = peine.jours + (resistanceAggravante ? 2 : 0);
  const amende = peine.amendeBase;

  state.estEmprisonne = { jours, jourFin: state.day + jours, raison: peine.label };
  state.recherche = [];
  if (amende > 0) state.arg = Math.max(0, state.arg - amende);
  if (state.poste && peineType === 'crime') {
    addExternalEvent('Votre poste de ' + state.poste.name + ' vous a ete retire suite a votre arrestation.');
    state.poste = null;
    if (state.char) state.char.poste = null;
  }
  updateUI();
  addExternalEvent('Vous avez ete arrete(e) pour ' + peine.label + '. ' + jours + ' jour(s) d\'emprisonnement. Amende : ' + amende.toLocaleString('fr-FR') + ' FR.');
  if (!state.prisonniers) state.prisonniers = [];
  state.prisonniers.push({ nom: state.char?.name, depuis: 'Jour ' + state.day, raison: peine.label, jourFin: state.day + jours });
}

function tenterFuite() {
  document.getElementById('modal-postes').classList.remove('open');
  const vol = state.char?.stats?.VOL || 8;
  const bonus = Math.floor(state.dis / 10) + Math.floor(vol / 2);
  const taux = Math.min(70, 30 + bonus);
  const roll = Math.floor(Math.random() * 100) + 1;

  if (roll <= taux) {
    state.dis = Math.max(0, state.dis - 20);
    updateUI();
    showToast('Fuite reussie !', 'Vous echappez aux policiers. -20 Discretion.', true, true);
    addJournalEntry('Vous avez pris la fuite face aux policiers. Votre discretion chute.', 'event-bad');
  } else {
    addExternalEvent('Tentative de fuite echouee. Arrestation avec circonstance aggravante.');
    const peineType = state.recherche?.[0]?.type || 'delit_mineur';
    procederArrestation(peineType, true);
  }
}

function tenterResistance(peineType) {
  document.getElementById('modal-postes').classList.remove('open');
  const vol = state.char?.stats?.VOL || 8;
  const taux = Math.min(30, vol * 2);
  const roll = Math.floor(Math.random() * 100) + 1;

  if (roll <= taux) {
    state.dis = Math.max(0, state.dis - 30);
    state.hp = Math.max(1, state.hp - 15);
    updateUI();
    showToast('Resistance reussie !', 'Vous vous echappez malgre tout. -30 DIS -15 HP.', true);
    addJournalEntry('Vous avez resiste violemment aux forces de l\'ordre. Fortement recherche(e).', 'event-bad');
    // Aggravation du statut
    if (!state.recherche) state.recherche = [];
    state.recherche.push({ acte: 'rebellion', type: 'delit_grave', jour: state.day });
  } else {
    addExternalEvent('Resistance aux forces de l\'ordre. Arrestation avec chef de rebellion.');
    procederArrestation(peineType, true);
    state.hp = Math.max(1, state.hp - 20);
    updateUI();
  }
}

function openRulesView() {
  document.querySelectorAll('.vue').forEach(v => v.classList.remove('active'));
  document.getElementById('vue-rules').classList.add('active');
  renderRulesContent('intro');
}

function closeRulesView() {
  document.getElementById('vue-rules').classList.remove('active');
  if (state.currentBuilding) {
    document.getElementById('vue-batiment').classList.add('active');
  } else {
    document.getElementById('vue-rue').classList.add('active');
  }
}

function renderRulesContent(section) {
  const regle = REGLES[section];
  if (!regle) return;

  document.querySelectorAll('.rules-tab').forEach(t => t.classList.remove('active'));
  document.querySelectorAll('.rules-tab').forEach(t => {
    if (t.dataset.section === section) t.classList.add('active');
  });

  const content = document.getElementById('rules-content');
  if (!content) return;
  content.innerHTML = '<div style="padding:1.5rem;max-width:700px">' +
    '<div style="font-family:Playfair Display,serif;font-size:1.3rem;color:#C9A84C;margin-bottom:1rem">' + regle.titre + '</div>' +
    '<div style="font-size:.88rem;color:#a0a080;line-height:1.9;white-space:pre-line">' + regle.contenu + '</div>' +
    '</div>';
}

// =====================

// TRIBUNAL
// =====================
function ouvrirArchivesTribunal() {
  const jugements = state.archivesJugements || [];
  document.getElementById('postes-modal-title').textContent = 'Archives du Tribunal';
  let html = '<div style="padding:1rem">';
  if (jugements.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucun jugement enregistre pour le moment.</div>';
  } else {
    jugements.forEach((j, i) => {
      html += '<div onclick="ouvrirDetailJugement(' + i + ')" style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;cursor:pointer" onmouseover="this.style.background=\'#151005\'" onmouseout="this.style.background=\'#0f0d05\'">';
      html += '<div style="display:flex;justify-content:space-between">';
      html += '<div style="font-family:Playfair Display,serif;font-size:.82rem;color:#c0b090">' + j.accuse + '</div>';
      html += '<div style="font-size:.7rem;color:#5a4030">Jour ' + j.jour + '</div>';
      html += '</div>';
      html += '<div style="font-size:.72rem;color:#6a5a30">' + j.motif + ' · ' + (j.peine||'En cours') + '</div>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function ouvrirDetailJugement(idx) {
  const j = (state.archivesJugements||[])[idx];
  if (!j) return;
  document.getElementById('postes-modal-title').textContent = 'Jugement — ' + j.accuse;
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#6a5a30;margin-bottom:.5rem">Date : Jour ' + j.jour + ' · Juge : ' + (j.juge||'PNJ') + '</div>';
  html += '<div style="font-size:.82rem;color:#c0b090;margin-bottom:.3rem">Motif : ' + j.motif + '</div>';
  html += '<div style="font-size:.82rem;color:#c0b090;margin-bottom:.3rem">Peine : ' + (j.peine||'N/A') + '</div>';
  if (j.executee !== undefined) html += '<div style="font-size:.78rem;color:' + (j.executee ? '#4a8a4a' : '#8a6a20') + '">' + (j.executee ? 'Peine executee' : 'Peine en cours ou amenagee') + '</div>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

// Le tribunal ne sert plus a deposer une plainte (role du commissariat),
// mais a CONSULTER les affaires transmises par la police et en attente de jugement.
async function ouvrirPorterPlainte() {
  const ville = WORLD[state.country]?.[state.currentCity]?.name || 'la ville';
  document.getElementById('postes-modal-title').textContent = 'Affaires du Tribunal de ' + ville;
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a8060;font-style:italic">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  // Charger depuis Supabase pour voir les affaires de TOUS les joueurs de la ville, pas juste les siennes
  if (typeof sbLoadPlaintes === 'function') {
    try {
      const toutes = await sbLoadPlaintes(state.country);
      state.plaintesEnCours = toutes;
    } catch(e) {}
  }
  const affairesEnAttente = (state.plaintesEnCours || []).filter(p => p.status === 'deposee' && p.city === state.currentCity);

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">' +
    'Pour porter plainte, rendez-vous au commissariat. Le tribunal ne traite que les affaires transmises par les forces de l\'ordre suite a une enquete concluante.</div>';

  if (affairesEnAttente.length === 0) {
    html += '<div style="font-size:.85rem;color:#5a5040">Aucune affaire en attente de jugement pour le moment.</div>';
  } else {
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">EN ATTENTE DE JUGEMENT</div>';
    affairesEnAttente.forEach(a => {
      html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem">';
      html += '<div style="font-family:Playfair Display,serif;font-size:.82rem;color:#c0b090">' + a.cible + '</div>';
      html += '<div style="font-size:.7rem;color:#6a5a30;margin-top:.2rem">' + (a.motif||'') + '</div>';
      html += '<div style="font-size:.65rem;color:#4a4030;margin-top:.3rem">Transmise le Jour ' + a.jour + '</div>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}



// =====================
// FONCTIONS COMPLEMENTAIRES V17
// =====================

function doCorruption(fn, cost) {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  if (state.arg < cost) { showToast('Fonds insuffisants', 'Il vous faut ' + cost + ' ' + cur, false); return; }
  const roll = Math.floor(Math.random() * 100) + 1;
  const taux = Math.max(5, 65 - getMalusISN());
  if (roll <= taux) {
    state.arg -= cost;
    state.dis = Math.max(0, state.dis - 5);
    updateUI();
    showToast('Corruption reussie', 'Le service a ete obtenu. -5 DIS.', true);
    addJournalEntry('Corruption : ' + fn.replace(/_/g,' '), 'event-bad');
    tracerActionPourRumeur('corruption', null);
    checkDetection(fn, 'success');
  } else {
    showToast('Echec', 'La tentative de corruption a echoue.', false);
    checkDetection(fn, 'fail');
  }
}

function doSeReposer(fn) {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  if (fn === 'se_nourrir') {
    const cost = 10;
    if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
    state.arg -= cost;
    state.moral = Math.min(100, state.moral + 3);
    updateUI();
    showToast('Verre pris', '+3 Moral. -' + cost + ' ' + cur + '.', true);
  } else {
    state.moral = Math.min(100, state.moral + 2);
    updateUI();
    showToast('Repos', '+2 Moral.', true);
  }
}

function doRequeteAvocat() {
  addMailNotification('Cabinet juridique', 'Prise en charge', 'Votre demande a ete enregistree. Un avocat vous assistera lors de votre comparution. Reduction de peine possible.');
  showToast('Avocat contacte', 'Un avocat prend votre dossier en charge. Reduction de peine possible.', true);
  addJournalEntry('Requete avocat deposee.', 'event-info');
}

function doGreveFaim() {
  state.hp = Math.max(1, state.hp - 5);
  state.pop = Math.min(100, state.pop + 3);
  updateUI();
  showToast('Greve de la faim', '-5 HP +3 POP. Pression politique sur l\'administration.', false);
  addExternalEvent((state.char?.name||'Un detenu') + ' entame une greve de la faim. Pression politique.');
}

function doTentativeEvasion() {
  const roll = Math.floor(Math.random() * 100) + 1;
  if (roll <= 5) {
    state.estEmprisonne = null;
    state.recherche = [];
    showToast('Evasion reussie !', 'Vous etes libre ! Restez discret.', true, true);
    addJournalEntry('Evasion reussie !', 'event-good');
  } else {
    if (state.estEmprisonne) state.estEmprisonne.jours += 7;
    showToast('Evasion echouee', 'Tentative echouee. +7 jours de detention.', false);
    addJournalEntry('Tentative d\'evasion echouee. Peine aggravee.', 'event-bad');
  }
}

function doVisiterPrisonnier() {
  ouvrirModalCibleRepertoire('visiter_prisonnier', 'Rendre visite a un detenu');
}

async function doSeRenseigner() {
  const co = COUNTRIES[state.country];
  const pjConnus = (state.pjConnus || []).join(', ') || 'des personnages politiques locaux';
  const ville = state.currentCity || 'la capitale';
  const prompt = 'Res Publica, jeu parodique politique. Empire : ' + (co?.n||'inconnu') + '. Ville : ' + ville + '. Le barman murmure une rumeur croustillante sur la vie politique locale, impliquant si possible un de ces personnages : ' + pjConnus + '. 1 phrase max, ton parodique et cynique.';
  try {
    const resp = await fetch('/api/chat', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({ model: 'claude-haiku-4-5-20251001', max_tokens: 60, messages: [{ role: 'user', content: prompt }] })
    });
    const data = await resp.json();
    const info = data.content?.[0]?.text?.trim() || 'Le barman hausse les épaules. Rien de neuf ce soir.';
    state.inf = Math.min(100, (state.inf||0) + 3);
    updateUI();
    showToast('Le barman murmure...', info, true, true);
    addJournalEntry('Barman : "' + info.substring(0,80) + '"', 'event-info');
    addExternalEvent('🍺 Une rumeur court dans les bars de ' + ville + ' : ' + info);
  } catch(e) {
    const infos = [
      'Un élu local aurait été vu sortir du casino à 4h du matin.',
      'Des rumeurs courent sur un remaniement imminent.',
      'Quelqu\'un cherche à acheter des votes dans le quartier.',
      'Une affaire financière menace d\'éclabousser le gouvernement.'
    ];
    const info = infos[Math.floor(Math.random() * infos.length)];
    state.inf = Math.min(100, (state.inf||0) + 2);
    updateUI();
    showToast('Le barman murmure...', info, true, true);
    addJournalEntry('Barman : "' + info + '"', 'event-info');
  }
}

function doReserver() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cost = 80;
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  state.arg -= cost;
  state.chambreReservee = state.currentBuilding;
  updateUI();
  showToast('Chambre reservee', 'Chambre reservee. -' + cost + ' ' + cur + '. Passez l\'ordre Dormir depuis votre fiche.', true);
  addJournalEntry('Chambre reservee. -' + cost + ' ' + cur + '.', 'event-info');
}

function doInterview() {
  const roll = Math.floor(Math.random() * 100) + 1;
  const impact = roll <= 50 ? 1 : -1;
  state.pop = Math.max(0, Math.min(100, state.pop + impact * 5));
  updateUI();
  showToast('Interview', (impact > 0 ? 'Bonne impression. +5 POP.' : 'Mauvaise impression. -5 POP.'), impact > 0);
  addExternalEvent((state.char?.name||'Un personnage') + ' s\'est exprime dans la presse. Impact : ' + (impact > 0 ? '+5 POP' : '-5 POP'));
}

function doArticle() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cost = 300;
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  state.arg -= cost;
  updateUI();
  ouvrirModalCibleRepertoire('article_favorable', 'Rediger un article favorable sur');
}

function doEtouffer() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cost = 800;
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  state.arg -= cost;
  updateUI();
  showToast('Ordre contact requis', 'Cliquez sur le journaliste cible pour etouffer un article.', false);
}

function doLogeInfo() {
  const infos = [
    'Les freres vous revelent qu\'un elu cache des fonds offshore.',
    'La Loge sait qui a commande l\'assassinat de la semaine derniere.',
    'Un ministre est en negociation secrete avec un empire etranger.',
    'Des elections anticipees se preparent dans l\'ombre.'
  ];
  const info = infos[Math.floor(Math.random() * infos.length)];
  state.inf = Math.min(100, state.inf + 5);
  updateUI();
  showToast('Information de la Loge', info, true, true);
  addJournalEntry('Information confidentielle obtenue de la Loge.', 'event-info');
}

function doSeFormer() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cost = 100;
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  state.arg -= cost;
  const stats = ['INT','CHA','VOL','PER','DUP','ENT'];
  document.getElementById('postes-modal-title').textContent = 'Suivre une formation';
  let html = '<div style="padding:1rem"><div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Choisir la caracteristique a ameliorer (+1 point) :</div>';
  stats.forEach(s => {
    html += '<button onclick="appliquerFormation(\'' + s + '\')" style="display:block;width:100%;text-align:left;padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;color:#c0b090;cursor:pointer;font-family:Crimson Pro,serif;font-size:.85rem;margin-bottom:.3rem">' + s + ' (actuel : ' + (state.char?.stats?.[s]||8) + ')</button>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function appliquerFormation(stat) {
  document.getElementById('modal-postes').classList.remove('open');
  if (!state.char) return;
  if (!state.char.stats) state.char.stats = {};
  state.char.stats[stat] = (state.char.stats[stat]||8) + 1;
  updateUI();
  showToast('Formation terminee', stat + ' : ' + state.char.stats[stat] + ' (+1)', true, true);
  addJournalEntry('Formation suivie : +1 ' + stat, 'event-good');
}

function doRecruterInfo() {
  const contacts = state.contacts || [];
  if (contacts.length === 0) { showToast('Repertoire vide', 'Ajoutez des contacts pour recruter.', false); return; }
  if (!state.informateurs) state.informateurs = [];
  document.getElementById('postes-modal-title').textContent = 'Recruter un informateur';
  let html = '<div style="padding:1rem"><div style="font-size:.8rem;color:#8a8060;margin-bottom:.8rem">L\'informateur enverra des mails reguliers avec des informations utiles.</div>';
  contacts.forEach(c => {
    html += '<button onclick="confirmerRecrutement(\'' + c.name + '\')" style="display:block;width:100%;text-align:left;padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;color:#c0b090;cursor:pointer;margin-bottom:.3rem;font-family:Crimson Pro,serif;font-size:.85rem">' + c.name + '</button>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerRecrutement(nom) {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cost = 150;
  document.getElementById('modal-postes').classList.remove('open');
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis pour recruter.', false); return; }
  // Vérifier pas déjà informateur
  if (!state.informateurs) state.informateurs = [];
  if (state.informateurs.some(i => i.nom === nom)) { showToast('Déjà informateur', nom + ' est déjà dans votre réseau.', false); return; }
  // Vérifier limite (max 2)
  if (state.informateurs.length >= 2) { showToast('Limite atteinte', 'Vous ne pouvez pas avoir plus de 2 informateurs simultanément.', false); return; }
  state.arg -= cost;
  state.informateurs.push({
    nom, niveau: 1,
    label: nom,
    cout: cost,
    coutJour: cost,
    depuis: state.day,
    joursActif: 0
  });
  updateUI();
  showToast('Informateur recrute', nom + ' rejoint votre reseau. -' + cost + ' ' + cur + '/jour.', true);
  addJournalEntry('Informateur recrute : ' + nom + ' (N1). -' + cost + ' ' + cur + '/jour.', 'event-info');
}

function doMobiliserPolice() {
  const pays = state.country || 'republic';
  if (INDICES_NATIONAUX?.[pays]) INDICES_NATIONAUX[pays].ISN = Math.min(100, INDICES_NATIONAUX[pays].ISN + 15);
  state.pop = Math.max(0, state.pop - 5);
  updateUI();
  showToast('Forces de l\'ordre mobilisees', '+15 ISN -5 POP.', false);
  addExternalEvent('Mobilisation des forces de l\'ordre. +15 ISN.');
}

function doMobiliserArmee() {
  const pays = state.country || 'republic';
  if (INDICES_NATIONAUX?.[pays]) INDICES_NATIONAUX[pays].ISN = Math.min(100, INDICES_NATIONAUX[pays].ISN + 20);
  updateUI();
  showToast('Armee mobilisee', '+20 ISN. Alerte maximale.', false);
  addExternalEvent('L\'armee est en etat d\'alerte maximale. +20 ISN.');
}

function doEtatUrgence() {
  const pays = state.country || 'republic';
  if (INDICES_NATIONAUX?.[pays]) {
    INDICES_NATIONAUX[pays].ISN = Math.min(100, INDICES_NATIONAUX[pays].ISN + 25);
    INDICES_NATIONAUX[pays].IS  = Math.max(0,   INDICES_NATIONAUX[pays].IS  - 10);
  }
  state.pop = Math.max(0, state.pop - 15);
  state.inf = Math.min(100, state.inf + 5);
  updateUI();
  showToast('Etat d\'urgence declare !', '+25 ISN -10 IS -15 POP +5 INF.', false);
  addExternalEvent('ETAT D\'URGENCE declare. Libertes civiles suspendues.');
}

function doInspecterTroupes() {
  state.inf = Math.min(100, state.inf + 3);
  const pays = state.country || 'republic';
  if (INDICES_NATIONAUX?.[pays]) INDICES_NATIONAUX[pays].ISN = Math.min(100, INDICES_NATIONAUX[pays].ISN + 2);
  updateUI();
  showToast('Inspection terminee', '+3 INF +2 ISN. Les troupes sont impressionnees.', true);
}

function doAugmenterImpots(augmenter) {
  const pays = state.country || 'republic';
  const delta = augmenter ? 5 : -5;
  state.pop = Math.max(0, Math.min(100, state.pop - (augmenter ? 8 : -5)));
  if (INDICES_NATIONAUX?.[pays]) INDICES_NATIONAUX[pays].IE = Math.max(0, Math.min(100, INDICES_NATIONAUX[pays].IE + (augmenter ? 5 : -5)));
  if (!state.tauxImposition) state.tauxImposition = 20;
  state.tauxImposition = Math.max(5, Math.min(50, state.tauxImposition + delta));
  updateUI();
  showToast(augmenter ? 'Impots augmentes' : 'Impots baisses', 'Taux : ' + state.tauxImposition + '% ' + (augmenter ? '-8 POP +5 IE' : '+5 POP -5 IE'), augmenter ? false : true);
  addExternalEvent('FINANCES : Taux d\'imposition fixe a ' + state.tauxImposition + '% par le Ministre des Finances.');
}

function doAutoriserManif() {
  const pays = state.country || 'republic';
  if (INDICES_NATIONAUX?.[pays]) INDICES_NATIONAUX[pays].ISN = Math.max(0, INDICES_NATIONAUX[pays].ISN - 5);
  state.pop = Math.min(100, state.pop + 5);
  updateUI();
  showToast('Manifestation autorisee', '+5 POP -5 ISN.', true);
}

function doDissoudreAssemblee() {
  state.pop = Math.max(0, state.pop - 10);
  state.inf = Math.max(0, state.inf - 5);
  const pays = state.country || 'republic';
  if (INDICES_NATIONAUX?.[pays]) {
    INDICES_NATIONAUX[pays].IS = Math.max(0, INDICES_NATIONAUX[pays].IS - 5);
    INDICES_NATIONAUX[pays].IE = Math.max(0, INDICES_NATIONAUX[pays].IE - 5);
  }
  updateUI();
  showToast('Assemblee dissoute !', 'Nouvelles elections declenchees. -10 POP -5 INF.', false);
  addExternalEvent('DISSOLUTION : L\'Assemblee Nationale est dissoute. Nouvelles elections convoquees.');
}

function doGrevePNJ() {
  const pays = state.country || 'republic';
  if (INDICES_NATIONAUX?.[pays]) INDICES_NATIONAUX[pays].IE = Math.max(0, INDICES_NATIONAUX[pays].IE - 5);
  updateUI();
  showToast('Greve declenchee', 'Les travailleurs cessent le travail. -5 IE.', false);
  addExternalEvent('GREVE : Mouvement social en cours. Impact economique.');
}

function doRecruterMilitants() {
  state.inf = Math.min(100, state.inf + 3);
  updateUI();
  showToast('Militants recrutes', '+3 INF. Votre base de soutien se renforce.', true);
  addJournalEntry('Recrutement de militants effectue.', 'event-info');
}

function doActeOfficiel() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cost = 50;
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  state.arg -= cost;
  if (!state.inventory) state.inventory = [];
  state.inventory.push({ type:'document', name:'Acte officiel de la mairie', icon:'ti-file-certificate', legal:true });
  updateUI();
  showToast('Acte delivre', 'Acte officiel ajoute a votre inventaire.', true);
}

// =====================
// SYSTEME DE BUDGET DES INSTITUTIONS
// =====================
const BUDGET_DEFAULT = {
  presidence: { solde: 50000, coutOrdre: 500 },
  min_int:    { solde: 30000, coutOrdre: 400 },
  min_fin:    { solde: 25000, coutOrdre: 300 },
  min_just:   { solde: 20000, coutOrdre: 350 },
  min_def:    { solde: 40000, coutOrdre: 600 },
  min_info:   { solde: 15000, coutOrdre: 250 },
  min_ae:     { solde: 20000, coutOrdre: 300 },
  assemblee:  { solde: 35000, coutOrdre: 200 },
  tribunal:   { solde: 20000, coutOrdre: 400 },
  commissariat:{ solde: 25000, coutOrdre: 350 },
  mairie:     { solde: 30000, coutOrdre: 250 }
};

// Repartition par defaut (%) - modifiable par le Ministre des Finances
const REPARTITION_DEFAULT = {
  presidence: 15, min_int: 8, min_fin: 6, min_just: 6,
  min_def: 10, min_info: 5, min_ae: 6,
  assemblee: 8, tribunal: 6, commissariat: 8, mairie: 12, reserve: 10
};

function getBudgetInstitution(inst) {
  if (!state.budgets) state.budgets = JSON.parse(JSON.stringify(BUDGET_DEFAULT));
  if (!state.budgets[inst]) state.budgets[inst] = { solde: 10000, coutOrdre: 300 };
  return state.budgets[inst];
}

function verifierBudgetInstitution(inst) {
  const b = getBudgetInstitution(inst);
  if (b.solde < b.coutOrdre) {
    const noms = {
      presidence:'la Presidence', min_fin:'le Ministere des Finances',
      min_int:'le Ministere de l\'Interieur', mairie:'la Mairie'
    };
    showToast('Budget insuffisant',
      'Le budget de ' + (noms[inst]||inst) + ' est insuffisant. Le Ministre des Finances doit revoir la repartition budgetaire.',
      false);
    return false;
  }
  b.solde -= b.coutOrdre;
  return true;
}

function alimenterBudgets() {
  // Appele a minuit - distribue les recettes fiscales
  const pays = state.country || 'republic';
  const pop = CITY_POPULATION?.[pays];
  if (!pop) return;
  let recettesTotales = 0;
  Object.values(pop).forEach(ville => {
    recettesTotales += ville.dailyTaxRevenue || 0;
  });

  const rep = state.repartitionBudget || REPARTITION_DEFAULT;
  if (!state.budgets) state.budgets = JSON.parse(JSON.stringify(BUDGET_DEFAULT));

  Object.keys(rep).forEach(inst => {
    if (inst === 'reserve') return;
    const montant = Math.floor(recettesTotales * (rep[inst] / 100));
    if (state.budgets[inst]) {
      state.budgets[inst].solde = Math.min(state.budgets[inst].solde + montant, 200000);
    }
  });

  // Reserve
  if (!state.reserve) state.reserve = 0;
  state.reserve += Math.floor(recettesTotales * ((rep.reserve || 10) / 100));
}

// =====================
// PREROGATIVES DU MAIRE
// =====================
function ouvrirFixerImpotsLocaux() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const taux = state.tauxImpositionLocal || 15;
  document.getElementById('postes-modal-title').textContent = 'Fixer les impôts locaux';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Taux actuel : ' + taux + '%. Impact direct sur les recettes municipales et la popularité.</div>';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">NOUVEAU TAUX (%)</div>';
  html += '<input id="taux-local-input" type="range" min="5" max="40" value="' + taux + '" oninput="document.getElementById(\'taux-local-val\').textContent=this.value+\'%\'" style="width:100%;margin-bottom:.3rem">';
  html += '<div id="taux-local-val" style="font-family:Bebas Neue,sans-serif;font-size:1.2rem;color:#C9A84C;text-align:center;margin-bottom:.6rem">' + taux + '%</div>';
  html += '<div style="font-size:.72rem;color:#5a5040;margin-bottom:.8rem">En dessous de 10% : budget serré mais populaire. Au dessus de 25% : recettes élevées mais impopulaire.</div>';
  html += '<button onclick="validerImpotsLocaux()" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Appliquer</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function validerImpotsLocaux() {
  const nouveauTaux = parseInt(document.getElementById('taux-local-input')?.value || '15');
  const ancienTaux = state.tauxImpositionLocal || 15;
  state.tauxImpositionLocal = nouveauTaux;
  const delta = nouveauTaux - ancienTaux;
  state.pop = Math.max(0, Math.min(100, state.pop - Math.floor(delta * 0.5)));
  document.getElementById('modal-postes').classList.remove('open');
  updateUI();
  showToast('Impôts locaux fixés', 'Taux : ' + nouveauTaux + '%. ' + (delta > 0 ? '-' + Math.floor(delta*0.5) + ' POP' : '+' + Math.floor(Math.abs(delta)*0.5) + ' POP'), delta > 0 ? false : true);
  addExternalEvent('MAIRIE : Le taux d\'imposition local est fixé à ' + nouveauTaux + '% par le Maire.');
}

function ouvrirRepartitionBudgetLocal() {
  const institutions = { commissariat: 40, dispensaire: 30, voirie: 20, services: 10 };
  const rep = state.budgetLocal || { ...institutions };
  document.getElementById('postes-modal-title').textContent = 'Budget municipal';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Répartition du budget entre les services municipaux. Total doit être 100%.</div>';
  const noms = { commissariat:'Commissariat', dispensaire:'Dispensaire', voirie:'Voirie', services:'Services municipaux' };
  Object.keys(rep).forEach(inst => {
    html += '<div style="display:flex;align-items:center;gap:.5rem;margin-bottom:.4rem">';
    html += '<div style="font-size:.78rem;color:#c0b090;width:130px">' + (noms[inst]||inst) + '</div>';
    html += '<input type="number" min="0" max="80" value="' + rep[inst] + '" id="bloc-' + inst + '" style="width:55px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.3rem;font-size:.82rem;outline:none">';
    html += '<span style="font-size:.72rem;color:#4a4030">%</span>';
    html += '</div>';
  });
  html += '<button onclick="validerBudgetLocal()" style="margin-top:.7rem;font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Valider</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function validerBudgetLocal() {
  const insts = ['commissariat','dispensaire','voirie','services'];
  let total = 0;
  const newRep = {};
  insts.forEach(inst => {
    const v = parseInt(document.getElementById('bloc-' + inst)?.value || '0');
    newRep[inst] = v;
    total += v;
  });
  if (total !== 100) { showToast('Total incorrect', 'Le total doit être 100%. Actuel : ' + total + '%.', false); return; }
  state.budgetLocal = newRep;
  document.getElementById('modal-postes').classList.remove('open');
  showToast('Budget validé', 'Nouvelle répartition municipale appliquée.', true);
  addJournalEntry('Répartition du budget municipal modifiée par le Maire.', 'event-info');
}

function doCampagneSecurite() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cost = 500;
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  state.arg -= cost;
  if (!verifierBudgetInstitution('mairie')) return;
  const pays = state.country || 'republic';
  if (INDICES_NATIONAUX?.[pays]) INDICES_NATIONAUX[pays].ISN = Math.min(100, INDICES_NATIONAUX[pays].ISN + 10);
  state.pop = Math.max(0, state.pop - 3);
  updateUI();
  showToast('Campagne de sécurité', '+10 ISN local. -3 POP. Prélevé sur budget mairie.', false);
  addExternalEvent('MAIRIE : Campagne de sécurité lancée par le Maire. +10 ISN.');
}

const ACTES_OFFICIELS = [
  { id:'acte_naissance',   name:'Acte de naissance fictif',       desc:'Identité alternative. Utile pour se fondre dans la masse.' },
  { id:'certif_residence', name:'Certificat de résidence',        desc:'+10% réussite ordres administratifs locaux.' },
  { id:'extrait_casier',   name:'Extrait de casier vierge',       desc:'Efface vos antécédents dans les archives locales.' },
  { id:'permis_exercer',   name:'Permis d\'exercer une activité', desc:'Autorise l\'exploitation d\'un commerce dans la ville.' },
  { id:'laissez_passer',   name:'Laissez-passer officiel',        desc:'+15 DIS dans la ville pendant 48h.' }
];

function ouvrirActeOfficielMairie() {
  document.getElementById('postes-modal-title').textContent = 'Délivrer un acte officiel';
  let html = '<div style="padding:1rem"><div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Choisir l\'acte à délivrer :</div>';
  ACTES_OFFICIELS.forEach(acte => {
    html += '<div onclick="delivrerActe(\'' + acte.id + '\')" style="padding:.6rem .8rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;cursor:pointer" onmouseover="this.style.background=\'#151005\'" onmouseout="this.style.background=\'#0f0d05\'">';
    html += '<div style="font-size:.82rem;color:#c0b090">' + acte.name + '</div>';
    html += '<div style="font-size:.68rem;color:#5a4030">' + acte.desc + '</div>';
    html += '</div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function delivrerActe(acteId) {
  document.getElementById('modal-postes').classList.remove('open');
  const acte = ACTES_OFFICIELS.find(a => a.id === acteId);
  if (!acte) return;
  if (!state.inventory) state.inventory = [];
  // Supprimer l'ancien acte du meme type si existant
  state.inventory = state.inventory.filter(i => i.acteId !== acteId);
  state.inventory.push({ type:'acte_officiel', name:acte.name, icon:'ti-file-certificate', legal:true, acteId, desc:acte.desc });
  updateUI();
  showToast('Acte délivré', acte.name + ' ajouté à votre inventaire.', true, true);
  addJournalEntry('Acte officiel délivré : ' + acte.name, 'event-info');
}

function ouvrirContesterResultats() {
  const elections = state.electionsEnCours?.filter(e => e.phase === 'termine') || [];
  document.getElementById('postes-modal-title').textContent = 'Contester des résultats';
  let html = '<div style="padding:1rem">';
  if (elections.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucune élection récente à contester.</div>';
  } else {
    html += '<div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Un recours sera déposé dans le sous-forum Tribunal. Le juge tranchera dans 48h.</div>';
    elections.forEach((e, i) => {
      html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.7rem;margin-bottom:.5rem">';
      html += '<div style="font-family:Playfair Display,serif;font-size:.85rem;color:#E8C97A">' + e.nom + '</div>';
      html += '<div style="font-size:.7rem;color:#5a4030">Élu : ' + (e.resultat?.elu || 'N/A') + '</div>';
      html += '<textarea id="motif-contestation-' + i + '" rows="3" placeholder="Motif de la contestation..." style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none;resize:none;margin:.4rem 0"></textarea>';
      html += '<button onclick="soumettreConte(' + i + ')" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;padding:.3rem .7rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Contester</button>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function soumettreConte(idx) {
  const e = (state.electionsEnCours||[]).filter(el => el.phase === 'termine')[idx];
  const motif = document.getElementById('motif-contestation-' + idx)?.value?.trim();
  if (!motif) { showToast('Motif requis', '', false); return; }
  document.getElementById('modal-postes').classList.remove('open');
  const ville = WORLD[state.country]?.[state.currentCity]?.name || 'la ville';
  const forumKey = 'tribunal_' + state.currentCity;
  if (!FORUM_TOPICS[forumKey]) FORUM_TOPICS[forumKey] = [];
  FORUM_TOPICS[forumKey].unshift({
    id: 'contestation-' + Date.now(),
    title: '[CONTESTATION] ' + e.nom,
    author: state.char?.name || 'Anonyme',
    time: 'Jour ' + state.day,
    posts: [{ author: state.char?.name, time: 'Jour ' + state.day, content: 'RECOURS ELECTORAL\n\nElection contestée : ' + e.nom + '\nMotif : ' + motif + '\n\nLe juge est prié de statuer dans les 48 heures.' }]
  });
  showToast('Recours déposé', 'Contestation publiée dans le forum du Tribunal de ' + ville + '. Décision dans 48h.', true);
  addJournalEntry('Contestation électorale déposée : ' + e.nom, 'event-info');
  addExternalEvent('ELECTORAL : ' + (state.char?.name||'Anonyme') + ' conteste les résultats de l\'élection : ' + e.nom);
}

// =====================

// TAXI SPECIAL — CASERNE / QHS
// =====================
const ACCES_CASERNE = ['president', 'min_def', 'commissaire'];
const ACCES_QHS = ['president', 'min_just', 'juge', 'commissaire', 'avocat'];

function doTaxiSpecial(destination) {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  if (state.arg < 200) { showToast('Fonds insuffisants', '200 ' + cur + ' requis.', false); return; }

  const label = destination === 'caserne' ? 'la Caserne' : 'le QHS';
  const cityKey = destination === 'caserne' ? 'caserne' : 'qhs';

  // Verifier acces
  const posteId = state.poste?.id || '';
  const accesLibres = destination === 'caserne' ? ACCES_CASERNE : ACCES_QHS;
  const aAccesLibre = accesLibres.some(p => posteId.includes(p));
  const aLaissezPasser = (state.inventory||[]).some(i =>
    i.acteId === 'laissez_passer' || i.acteId === 'acte_officiel' || i.type === 'document_falsifie'
  );

  if (!aAccesLibre && !aLaissezPasser) {
    showToast('Accès refusé', 'Vous n\'avez pas les autorisations pour vous rendre à ' + label + '. Procurez-vous un laissez-passer officiel ou un ordre de visite.', false);
    return;
  }

  // Si faux document — jet DUP
  const aVraiDoc = aAccesLibre || (state.inventory||[]).some(i => i.acteId === 'laissez_passer' && i.legal);
  if (!aVraiDoc && aLaissezPasser) {
    const dup = state.char?.stats?.DUP || 8;
    const roll = Math.floor(Math.random() * 100) + 1;
    const taux = Math.max(5, 50 + Math.floor(dup/10) - getMalusISN());
    if (roll > taux) {
      showToast('Faux document détecté !', 'La garde a reconnu le faux. Vous êtes arrêté(e).', false);
      state.recherche = [{ acte:'faux_document', type:'delit_grave', jour:state.day, peine:4 }];
      updateUI();
      addJournalEntry('Faux laissez-passer détecté à l\'entrée de ' + label + '. Arrestation.', 'event-bad');
      return;
    }
  }

  // Voyage OK
  state.arg -= 200;
  state.currentCity = cityKey;
  state.currentBuilding = null;
  state.currentRoom = null;
  if (state.char) {
    state.char.currentCity = cityKey;
    localStorage.setItem('respublica_char_' + (state.char?.name || 'default'), JSON.stringify(state.char));
  }
  buildCityTabs();
  updateUI();
  forceRenderCity(cityKey);
  showToast('En route !', 'Vous arrivez à ' + label + '. -200 ' + cur, true);
  addJournalEntry('Taxi vers ' + label, 'event-info');
}

// =====================

// FALSIFIER UN DOCUMENT
// =====================
const DOCUMENTS_FALSIFIABLES = [
  { id:'fausse_identite',   name:'Fausse identite',          desc:'Change votre nom affiche dans le jeu temporairement.',     icon:'ti-id-badge' },
  { id:'faux_casier',       name:'Faux casier judiciaire vierge', desc:'Efface vos antecedents judiciaires dans les archives.', icon:'ti-file-x' },
  { id:'faux_permis',       name:'Faux permis de construire', desc:'Permet de construire sans passer par la mairie.',          icon:'ti-building' },
  { id:'faux_contrat',      name:'Faux contrat commercial',   desc:'Legitime une transaction illegale ou un transfert.',       icon:'ti-file-text' },
  { id:'fausse_convocation',name:'Fausse convocation officielle', desc:'Attire un PJ dans un lieu de votre choix.',           icon:'ti-mail' }
];

function ouvrirFalsifierDocument() {
  document.getElementById('postes-modal-title').textContent = 'Falsifier un document';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#cc4444;font-style:italic;margin-bottom:.8rem">Acte illegal. Taux 45%. Echec : alerte possible. Document ajoute a votre inventaire si succes.</div>';
  DOCUMENTS_FALSIFIABLES.forEach(doc => {
    html += '<div onclick="confirmerFalsification(\'' + doc.id + '\')" style="padding:.6rem .8rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;cursor:pointer;transition:background .15s" onmouseover="this.style.background=\'#151005\'" onmouseout="this.style.background=\'#0f0d05\'">';
    html += '<div style="display:flex;align-items:center;gap:.6rem">';
    html += '<i class="ti ' + doc.icon + '" style="font-size:1rem;color:#8a6a20"></i>';
    html += '<div><div style="font-size:.82rem;color:#c0b090">' + doc.name + '</div>';
    html += '<div style="font-size:.68rem;color:#5a4030">' + doc.desc + '</div></div>';
    html += '</div></div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerFalsification(docId) {
  document.getElementById('modal-postes').classList.remove('open');
  const doc = DOCUMENTS_FALSIFIABLES.find(d => d.id === docId);
  if (!doc) return;

  const roll = Math.floor(Math.random() * 100) + 1;
  const taux = Math.max(5, 45 - getMalusISN());

  if (roll <= taux) {
    if (!state.inventory) state.inventory = [];
    state.inventory.push({
      type: 'document_falsifie',
      name: doc.name,
      icon: doc.icon,
      docId: doc.id,
      legal: false,
      desc: doc.desc
    });
    state.arg -= 300;
    updateUI();
    showToast('Document falsifie !', doc.name + ' ajoute a votre inventaire.', true, true);
    addJournalEntry('Falsification : ' + doc.name, 'event-bad');
    checkDetection('falsifier_document', 'success');
  } else {
    showToast('Echec !', 'La falsification a echoue. Vous etes peut-etre repere(e).', false);
    checkDetection('falsifier_document', 'fail');
    addJournalEntry('Tentative de falsification echouee.', 'event-bad');
  }
}

// =====================

// V28B — SYSTÈME DE LOCATION DE LOCAUX
// =====================

function getLocationsActives() {
  if (!state.locationsActives) state.locationsActives = [];
  return state.locationsActives;
}

function getLocationPourRoom(buildingId, roomId) {
  return getLocationsActives().find(l => l.buildingId === buildingId && l.roomId === roomId);
}

function ouvrirModalLouerLocal() {
  const buildingId = state.currentBuilding;
  const roomId = state.currentRoom;
  if (!buildingId || !roomId) return;

  const room = BUILDINGS[buildingId]?.rooms?.[roomId];
  if (!room?.locationData) { showToast('Erreur', 'Local non trouvé.', false); return; }

  const loc = room.locationData;
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  // Vérifier si déjà loué par quelqu'un
  const dejaLoue = getLocationPourRoom(buildingId, roomId);
  if (dejaLoue) {
    if (dejaLoue.locataire === state.char?.name) {
      ouvrirModalGererLocal();
    } else {
      showToast('Déjà loué', 'Ce local est occupé par ' + dejaLoue.locataire + '.', false);
    }
    return;
  }

  // Bonus formatés
  const bonusParts = [];
  if (loc.bonusPOP > 0) bonusParts.push('+' + loc.bonusPOP + ' POP');
  if (loc.bonusINF > 0) bonusParts.push('+' + loc.bonusINF + ' INF');
  if (loc.bonusDIS > 0) bonusParts.push('+' + loc.bonusDIS + ' DIS');
  const bonusStr = bonusParts.join(' · ') || 'Aucun bonus direct';

  // Organisations disponibles
  const mesOrgas = (getMesOrgasPays()).filter(o =>
    o.membres?.some(m => m.nom === state.char?.name)
  );

  let orgaSelect = '<div style="font-size:.72rem;color:#4a4030;font-style:italic">Aucune organisation — fondez-en une pour bénéficier des bonus.</div>';
  if (mesOrgas.length > 0) {
    orgaSelect = '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.3rem">ASSOCIER À UNE ORGANISATION</div>' +
      '<select id="loc-orga-select" style="width:100%;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;padding:.4rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.6rem">' +
      '<option value="">— Aucune organisation —</option>' +
      mesOrgas.map(o => '<option value="' + o.id + '">' + o.nom + '</option>').join('') +
      '</select>';
  }

  document.getElementById('postes-modal-title').textContent = '📋 Louer : ' + loc.label;
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +
    '<div style="font-size:.78rem;color:#a09060;font-style:italic;margin-bottom:.7rem;border-left:2px solid #3a2a10;padding-left:.6rem">' + (room.desc || '') + '</div>' +
    '<div style="display:grid;grid-template-columns:1fr 1fr;gap:.4rem;margin-bottom:.7rem">' +
      '<div style="background:#0a0805;border:1px solid #1a1810;padding:.5rem;text-align:center">' +
        '<div style="font-size:.62rem;color:#4a4030">LOYER / JOUR</div>' +
        '<div style="font-family:Bebas Neue,sans-serif;font-size:1.1rem;color:#C9A84C">' + loc.prix.toLocaleString('fr-FR') + ' ' + cur + '</div>' +
      '</div>' +
      '<div style="background:#0a0805;border:1px solid #1a1810;padding:.5rem;text-align:center">' +
        '<div style="font-size:.62rem;color:#4a4030">BONUS ORGANISATION</div>' +
        '<div style="font-size:.78rem;color:#4a8a4a;margin-top:.2rem">' + bonusStr + '</div>' +
      '</div>' +
    '</div>' +
    orgaSelect +
    '<div style="font-size:.7rem;color:#6a5a30;margin-bottom:.7rem">Le premier loyer est prélevé immédiatement. Ensuite, chaque réveil.</div>' +
    '<button onclick="confirmerLocation()" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">🔑 Signer le bail</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerLocation() {
  const buildingId = state.currentBuilding;
  const roomId = state.currentRoom;
  const room = BUILDINGS[buildingId]?.rooms?.[roomId];
  if (!room?.locationData) return;

  const loc = room.locationData;
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const orgaId = document.getElementById('loc-orga-select')?.value || '';

  if (state.arg < loc.prix) {
    showToast('Fonds insuffisants', loc.prix + ' ' + cur + ' requis pour le premier loyer.', false);
    return;
  }

  state.arg -= loc.prix;
  if (!state.locationsActives) state.locationsActives = [];

  state.locationsActives.push({
    buildingId, roomId,
    localLabel: loc.label,
    batimentLabel: BUILDINGS[buildingId]?.shortName || buildingId,
    prix: loc.prix,
    bonusPOP: loc.bonusPOP || 0,
    bonusINF: loc.bonusINF || 0,
    bonusDIS: loc.bonusDIS || 0,
    orgaId,
    locataire: state.char?.name,
    country: state.country,
    depuis: state.day || 1,
    visible: true
  });

  document.getElementById('modal-postes').classList.remove('open');
  updateUI();

  const bonusParts = [];
  if (loc.bonusPOP > 0) bonusParts.push('+' + loc.bonusPOP + ' POP');
  if (loc.bonusINF > 0) bonusParts.push('+' + loc.bonusINF + ' INF');
  if (loc.bonusDIS > 0) bonusParts.push('+' + loc.bonusDIS + ' DIS');

  showToast('Bail signé !', loc.label + ' loué. -' + loc.prix + ' ' + cur + '/jour.' + (bonusParts.length ? ' ' + bonusParts.join(' · ') : ''), true, true);
  addJournalEntry('Location signée : ' + loc.label + ' (' + (BUILDINGS[buildingId]?.shortName || buildingId) + '). -' + loc.prix + ' ' + cur + '/jour.', 'event-good');

  // Recharger la pièce pour afficher "Gérer mon local"
  if (state.currentRoom) enterRoom(buildingId, roomId, null);
}

function ouvrirModalGererLocal() {
  const buildingId = state.currentBuilding;
  const roomId = state.currentRoom;
  const location = getLocationPourRoom(buildingId, roomId);

  if (!location || location.locataire !== state.char?.name) {
    showToast('Non locataire', 'Vous ne louez pas ce local.', false);
    return;
  }

  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const mesOrgas = (getMesOrgasPays()).filter(o =>
    o.membres?.some(m => m.nom === state.char?.name)
  );

  const bonusParts = [];
  if (location.bonusPOP > 0) bonusParts.push('+' + location.bonusPOP + ' POP');
  if (location.bonusINF > 0) bonusParts.push('+' + location.bonusINF + ' INF');
  if (location.bonusDIS > 0) bonusParts.push('+' + location.bonusDIS + ' DIS');

  const orgaActuelle = mesOrgas.find(o => o.id === location.orgaId);

  let orgaSelect = '';
  if (mesOrgas.length > 0) {
    orgaSelect = '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.1em;color:#8a6a20;margin:.6rem 0 .3rem">ORGANISATION ASSOCIÉE</div>' +
      '<select id="gerer-orga-select" style="width:100%;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;padding:.4rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.5rem">' +
      '<option value="">— Aucune —</option>' +
      mesOrgas.map(o => '<option value="' + o.id + '"' + (o.id === location.orgaId ? ' selected' : '') + '>' + o.nom + '</option>').join('') +
      '</select>' +
      '<button onclick="changerOrgaLocation()" style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.08em;padding:.3rem .8rem;border:1px solid #4a6a4a;background:transparent;color:#6a9a6a;cursor:pointer;margin-bottom:.5rem">Mettre à jour</button>';
  }

  document.getElementById('postes-modal-title').textContent = '⚙️ ' + location.localLabel;
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +
    '<div style="display:grid;grid-template-columns:1fr 1fr;gap:.4rem;margin-bottom:.6rem">' +
      '<div style="background:#0a0805;border:1px solid #1a1810;padding:.5rem;text-align:center">' +
        '<div style="font-size:.62rem;color:#4a4030">LOYER / JOUR</div>' +
        '<div style="font-family:Bebas Neue,sans-serif;font-size:1rem;color:#C9A84C">' + location.prix.toLocaleString('fr-FR') + ' ' + cur + '</div>' +
      '</div>' +
      '<div style="background:#0a0805;border:1px solid #1a1810;padding:.5rem;text-align:center">' +
        '<div style="font-size:.62rem;color:#4a4030">BONUS ACTIFS</div>' +
        '<div style="font-size:.72rem;color:#4a8a4a;margin-top:.2rem">' + (bonusParts.join(' · ') || 'Aucun') + '</div>' +
      '</div>' +
    '</div>' +
    '<div style="font-size:.72rem;color:#6a5a30;margin-bottom:.4rem">Loué depuis le Jour ' + location.depuis + ' · ' + (location.batimentLabel || '') + '</div>' +
    '<div style="font-size:.72rem;color:' + (orgaActuelle ? '#4a8a4a' : '#6a5a30') + ';margin-bottom:.5rem">Organisation : ' + (orgaActuelle ? orgaActuelle.nom : 'Aucune') + '</div>' +
    orgaSelect +
    '<div style="margin-bottom:.6rem">' +
      '<button onclick="ouvrirCreerOrga()" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.4rem;border:1px solid #4a6a4a;background:transparent;color:#6a9a6a;cursor:pointer"><i class=\"ti ti-building\" style=\"font-size:.8rem\"></i> Créer une organisation ici</button>' +
    '</div>' +
    '<div style="display:flex;gap:.4rem;margin-top:.6rem">' +
      '<button onclick="toggleVisibiliteLocation()" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.06em;padding:.35rem;border:1px solid #3a4a5a;background:transparent;color:#6a8aaa;cursor:pointer">' +
        (location.visible ? '👁 Masquer' : '👁 Afficher') + ' sur le plan' +
      '</button>' +
      '<button onclick="resilierBail()" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.06em;padding:.35rem;border:1px solid #5a2a2a;background:transparent;color:#8a3a2a;cursor:pointer">❌ Résilier le bail</button>' +
    '</div>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

function changerOrgaLocation() {
  const buildingId = state.currentBuilding;
  const roomId = state.currentRoom;
  const location = getLocationPourRoom(buildingId, roomId);
  if (!location) return;
  const newOrgaId = document.getElementById('gerer-orga-select')?.value || '';
  location.orgaId = newOrgaId;
  const orga = getOrgaById(newOrgaId);
  showToast('Organisation mise à jour', orga ? orga.nom + ' associée à ce local.' : 'Aucune organisation associée.', true);
  addJournalEntry('Organisation du local ' + location.localLabel + ' mise à jour.', '');
}

function toggleVisibiliteLocation() {
  const buildingId = state.currentBuilding;
  const roomId = state.currentRoom;
  const location = getLocationPourRoom(buildingId, roomId);
  if (!location) return;
  location.visible = !location.visible;
  document.getElementById('modal-postes').classList.remove('open');
  showToast(location.visible ? 'Local visible' : 'Local masqué', location.visible ? 'Votre local apparaît sur le plan de ville.' : 'Votre local est discret.', true);
}

function resilierBail() {
  const buildingId = state.currentBuilding;
  const roomId = state.currentRoom;
  const idx = (state.locationsActives || []).findIndex(l => l.buildingId === buildingId && l.roomId === roomId);
  if (idx < 0) return;

  const location = state.locationsActives[idx];
  document.getElementById('modal-postes').classList.remove('open');

  // Confirmation
  document.getElementById('postes-modal-title').textContent = 'Résilier le bail ?';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1rem">' +
    '<div style="font-size:.85rem;color:#c0b090;margin-bottom:.8rem">Vous allez résilier votre bail sur <strong>' + location.localLabel + '</strong>. Cette action est irréversible.</div>' +
    '<div style="display:flex;gap:.5rem">' +
      '<button onclick="confirmerResiliation(' + idx + ')" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem;border:1px solid #8a3a2a;background:transparent;color:#cc4444;cursor:pointer">Confirmer la résiliation</button>' +
      '<button onclick="fermerModalPostes()" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem;border:1px solid #2a2010;background:transparent;color:#6a5a30;cursor:pointer">Annuler</button>' +
    '</div></div>';
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerResiliation(idx) {
  if (!state.locationsActives?.[idx]) return;
  const location = state.locationsActives[idx];
  state.locationsActives.splice(idx, 1);
  document.getElementById('modal-postes').classList.remove('open');
  showToast('Bail résilié', location.localLabel + ' libéré.', false);
  addJournalEntry('Bail résilié : ' + location.localLabel + '.', 'event-info');
  if (state.currentRoom) enterRoom(state.currentBuilding, state.currentRoom, null);
}

// Paiement des loyers au réveil
function payerLocations() {
  const locations = state.locationsActives || [];
  if (locations.length === 0) return;

  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const pays = state.country || 'republic';
  const toExpulse = [];

  locations.forEach((loc, i) => {
    if (loc.locataire !== state.char?.name) return; // Pas notre location

    if (state.arg >= loc.prix) {
      state.arg -= loc.prix;
      addJournalEntry('Loyer payé : ' + loc.localLabel + ' -' + loc.prix + ' ' + cur, 'event-info');

      // Appliquer les bonus à l'organisation associée
      if (loc.orgaId) {
        appliquerBonusLocation(loc);
      }
    } else {
      // Fonds insuffisants — mail d'avertissement J1, expulsion J2
      if (!loc.avertissement) {
        loc.avertissement = true;
        addMailNotification('Gestionnaire immobilier', 'Loyer impayé — ' + loc.localLabel,
          'Votre loyer de ' + loc.prix + ' ' + cur + ' pour ' + loc.localLabel + ' n\'a pas pu etre preleve. Regularisez sous 24h ou vous serez expulse(e).');
        addJournalEntry('⚠️ Loyer impayé : ' + loc.localLabel + '. Avertissement envoyé.', 'event-bad');
      } else {
        // Deuxième défaut → expulsion
        toExpulse.push(i);
      }
    }
  });

  // Traiter les expulsions en ordre inverse
  toExpulse.reverse().forEach(i => expulserLocataire(i));
}

function appliquerBonusLocation(loc) {
  const orga = getOrgaById(loc.orgaId);
  if (!orga) return;

  // Stocker les bonus dans l'orga
  if (!orga.bonusLocaux) orga.bonusLocaux = { pop: 0, inf: 0, dis: 0 };
  orga.bonusLocaux.pop = (orga.bonusLocaux.pop || 0) + (loc.bonusPOP || 0);
  orga.bonusLocaux.inf = (orga.bonusLocaux.inf || 0) + (loc.bonusINF || 0);
  orga.bonusLocaux.dis = (orga.bonusLocaux.dis || 0) + (loc.bonusDIS || 0);

  // Appliquer au joueur (fraction des bonus)
  const mult = 0.3; // 30% des bonus de l'orga profitent directement au chef
  const estChef = orga.chef === state.char?.name;
  if (estChef) {
    if (loc.bonusPOP > 0) state.pop = Math.min(100, (state.pop || 0) + Math.floor(loc.bonusPOP * mult));
    if (loc.bonusINF > 0) state.inf = Math.min(100, (state.inf || 0) + Math.floor(loc.bonusINF * mult));
    if (loc.bonusDIS > 0) state.dis = Math.min(100, (state.dis || 50) + Math.floor(loc.bonusDIS * mult));
  }
}

function expulserLocataire(idx) {
  if (!state.locationsActives?.[idx]) return;
  const loc = state.locationsActives[idx];
  const pays = state.country || 'republic';

  // Message d'expulsion selon empire
  const msgs = {
    republic: 'Maître Huissier Formulaire vous signifie votre expulsion du local "' + loc.localLabel + '". Vous avez quitté les lieux conformément à la procédure 47-B.',
    narco:    'Deux messieurs d\'El Don ont recupere les cles de "' + loc.localLabel + '". Sans discussion. Bonne journée.',
    soviet:   'Le Camarade Gestionnaire a redistribue votre local ' + loc.localLabel + ' au collectif. Loi du Parti.',
    khalija:  'Par decret du Sheikh, votre occupation de ' + loc.localLabel + ' prend fin immediatement.'
  };

  state.locationsActives.splice(idx, 1);
  addMailNotification('Gestionnaire immobilier', 'Expulsion — ' + loc.localLabel, msgs[pays] || msgs.republic);
  addExternalEvent('🏢 ' + (state.char?.name || 'Anonyme') + ' a été expulsé(e) de "' + loc.localLabel + '" pour loyer impayé.');
  addJournalEntry('Expulsion : ' + loc.localLabel + ' perdu pour loyer impayé.', 'event-bad');
}

// Vue d'ensemble des locations actives
function ouvrirMesLocations() {
  const locations = (state.locationsActives || []).filter(l => l.locataire === state.char?.name);
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  document.getElementById('postes-modal-title').textContent = '🏢 Mes Locations';

  if (locations.length === 0) {
    document.getElementById('postes-body').innerHTML =
      '<div style="padding:1rem;font-size:.85rem;color:#4a4030;font-style:italic">Vous ne louez aucun local actuellement. Rendez-vous dans un Centre Commercial, Artisanal ou d\'Affaires.</div>';
    document.getElementById('modal-postes').classList.add('open');
    return;
  }

  const totalLoyer = locations.reduce((s, l) => s + l.prix, 0);
  const html = locations.map((loc, i) => {
    const bonusParts = [];
    if (loc.bonusPOP > 0) bonusParts.push('+' + loc.bonusPOP + ' POP');
    if (loc.bonusINF > 0) bonusParts.push('+' + loc.bonusINF + ' INF');
    if (loc.bonusDIS > 0) bonusParts.push('+' + loc.bonusDIS + ' DIS');
    const orga = getOrgaById(loc.orgaId);

    return '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.7rem;margin-bottom:.5rem">' +
      '<div style="display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:.3rem">' +
        '<div>' +
          '<div style="font-family:Bebas Neue,sans-serif;font-size:.82rem;color:#C9A84C">' + loc.localLabel + '</div>' +
          '<div style="font-size:.68rem;color:#6a5a30">' + (loc.batimentLabel || '') + ' · Depuis Jour ' + loc.depuis + '</div>' +
        '</div>' +
        '<div style="text-align:right">' +
          '<div style="font-family:Bebas Neue,sans-serif;font-size:.82rem;color:#c0b090">' + loc.prix + ' ' + cur + '/jour</div>' +
          '<div style="font-size:.65rem;color:#4a8a4a">' + (bonusParts.join(' · ') || '') + '</div>' +
        '</div>' +
      '</div>' +
      '<div style="font-size:.68rem;color:' + (orga ? '#4a8a4a' : '#4a4030') + ';margin-bottom:.4rem">Organisation : ' + (orga ? orga.nom : 'Aucune') + '</div>' +
      '<button onclick="confirmerResiliation(' + i + ')" style="font-family:Bebas Neue,sans-serif;font-size:.65rem;padding:.2rem .5rem;border:1px solid #5a2a2a;background:transparent;color:#8a3a2a;cursor:pointer">Résilier</button>' +
      '</div>';
  }).join('');

  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.6rem 1rem">' +
    '<div style="font-size:.72rem;color:#8a6a20;margin-bottom:.6rem;font-family:Bebas Neue,sans-serif;letter-spacing:.08em">TOTAL LOYERS : ' + totalLoyer.toLocaleString('fr-FR') + ' ' + cur + '/JOUR</div>' +
    html + '</div>';
  document.getElementById('modal-postes').classList.add('open');
}


// =====================

// V27 — DON D'ARGENT A UN PNJ
// =====================
function ouvrirDonPnjModal(encodedPnj) {
  let pnj;
  try { pnj = JSON.parse(decodeURIComponent(encodedPnj)); } catch(e) { return; }
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const job = pnj.job || 'default';
  const jobLabels = {
    serveur:'Un pourboire genereux. Il pourrait vous glisser une info utile.',
    barman:'Il entend tout. Arroser le barman, c\'est investir dans le renseignement.',
    commissaire:'Risque. Mais parfois ca passe. Jet de DUP.',
    policier:'Risque. Mais parfois ca passe. Jet de DUP.',
    inspecteur:'Risque. Mais parfois ca passe. Jet de DUP.',
    journaliste:'Un geste editorial. Peut generer un article favorable.',
    banquier:'Un service discret. Il fera passer votre transaction sans questions.',
    medecin:'Des soins off-record. Pas de trace medicale.',
    commercant:'Ca fait du bien a la reputation locale.',
    juge:'Delicat. Un juge corruptible peut classer une affaire.',
    avocat:'L\'avocat peut faire accelerer une procedure.',
    loge:'Un don a la Loge. Le reseau se souviendra.',
    grand_pretre:'+IP et benediction.',
    escort:'Informations exclusives.',
    default:'Un geste de bonne volonte. Effets variables.'
  };
  // modal-pnj reste ouvert
  document.getElementById('postes-modal-title').textContent = 'Donner de l\'argent a ' + pnj.name.replace(' (PNJ)', '');
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +
    '<div style="font-size:.78rem;color:#a09060;font-style:italic;margin-bottom:.7rem;border-left:2px solid #3a2a10;padding-left:.6rem">' + (jobLabels[job] || jobLabels.default) + '</div>' +
    '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">MONTANT (' + cur + ')</div>' +
    '<input id="don-pnj-montant" type="number" min="10" step="50" placeholder="Ex: 200" style="width:100%;padding:.4rem .6rem;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;font-family:Crimson Pro,Georgia,serif;font-size:.9rem;box-sizing:border-box;margin-bottom:.7rem"/>' +
    '<button onclick="confirmerDonPnj(\'' + encodedPnj + '\')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">💰 Donner</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerDonPnj(encodedPnj) {
  let pnj;
  try { pnj = JSON.parse(decodeURIComponent(encodedPnj)); } catch(e) { return; }
  const montant = parseInt(document.getElementById('don-pnj-montant')?.value || 0);
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const job = pnj.job || 'default';
  const isn = INDICES_NATIONAUX?.[state.country]?.ISN || 30;
  if (!montant || montant <= 0) { showToast('Montant invalide', 'Entrez un montant.', false); return; }
  if (state.arg < montant) { showToast('Fonds insuffisants', montant + ' ' + cur + ' requis.', false); return; }
  document.getElementById('modal-postes').classList.remove('open');
  state.arg -= montant;
  updateUI();

  // Don a un VRAI joueur — depot reel via Supabase, credite automatiquement a sa prochaine connexion
  if (pnj.isPJ) {
    const nomCourt = pnj.name.replace(' (PNJ)','');
    const expediteur = state.char?.name || 'Anonyme';
    const h = String(state.hour || 8).padStart(2,'0');
    const time = 'Jour ' + (state.day || 1) + ' · ' + h + 'h';
    if (typeof sbDeposerDon === 'function') {
      await sbDeposerDon(nomCourt, montant, expediteur).catch(() => {});
    }
    if (typeof sbSendMail === 'function') {
      await sbSendMail(expediteur, nomCourt, 'Don d\'argent recu',
        expediteur + ' vous a fait don de ' + montant + ' ' + cur + '. La somme sera automatiquement creditee sur votre compte a votre prochaine connexion.', time).catch(() => {});
    }
    addJournalEntry('Vous avez donne ' + montant + ' ' + cur + ' a ' + nomCourt + '.', 'event-good');
    showToast('Don envoye', nomCourt + ' recevra ' + montant + ' ' + cur + ' automatiquement.', true, true);
    tracerActionPourRumeur('don', nomCourt);
    return;
  }
  const dup = state.char?.stats?.DUP || 8;
  const nomCourt = pnj.name.replace(' (PNJ)','');
  const jobsRisques = ['commissaire','policier','inspecteur','juge'];
  const tauxRefus = jobsRisques.includes(job) ? Math.max(0, isn - 30) / 2 : 0;
  const rollRefus = Math.floor(Math.random() * 100) + 1;
  if (tauxRefus > 0 && rollRefus <= tauxRefus) {
    state.arg += montant;
    state.dis = Math.max(0, (state.dis||50) - 15);
    updateUI();
    addJournalEntry('Don refuse par ' + nomCourt + '. -15 DIS.', 'event-bad');
    showToast('Refus indigne !', nomCourt + ' a refuse. -15 DIS.', false);
    return;
  }
  const effets = {
    serveur:     () => { state.moral=Math.min(100,(state.moral||50)+5); state.inf=Math.min(100,(state.inf||0)+2); showToast('Pourboire verse !','+5 Moral +2 INF.',true); addJournalEntry('Pourboire a '+nomCourt+'. +5 Moral +2 INF.','event-good'); },
    barman:      () => { state.inf=Math.min(100,(state.inf||0)+5); showToast('Le barman apprecie !','+5 INF.',true,true); addJournalEntry('Don barman. +5 INF.','event-good'); },
    commissaire: () => { const t=Math.min(70,30+Math.floor(dup*2)); const r=Math.floor(Math.random()*100)+1; if(r<=t){state.dis=Math.max(0,(state.dis||50)-5);showToast('Arrangement discret','-5 DIS.',true);addJournalEntry('Corruption commissaire. -5 DIS.','event-bad');}else{state.dis=Math.max(0,(state.dis||50)-20);showToast('Refus !','-20 DIS.',false);} },
    policier:    () => { const t=Math.min(65,25+Math.floor(dup*2)); const r=Math.floor(Math.random()*100)+1; if(r<=t){state.dis=Math.max(0,(state.dis||50)-3);showToast('Il regarde ailleurs.','-3 DIS.',true);}else{state.dis=Math.max(0,(state.dis||50)-15);showToast('Refus !','-15 DIS.',false);} },
    inspecteur:  () => { const t=Math.min(70,35+Math.floor(dup*2)); const r=Math.floor(Math.random()*100)+1; if(r<=t){state.dis=Math.max(0,(state.dis||50)-5);showToast('Inspecteur convaincu !','-5 DIS.',true);}else{state.dis=Math.max(0,(state.dis||50)-15);showToast('Refus !','-15 DIS.',false);} },
    journaliste: () => { state.inf=Math.min(100,(state.inf||0)+8); state.pop=Math.min(100,(state.pop||0)+5); showToast('Article favorable !','+8 INF +5 POP.',true,true); addExternalEvent((state.char?.name||'Anonyme')+' beneficie d\'une couverture favorable.'); },
    banquier:    () => { state.dis=Math.min(100,(state.dis||50)+5); showToast('Service discret.','+5 DIS.',true); },
    medecin:     () => { const s=Math.min(25,Math.floor(montant/10)); state.hp=Math.min(100,(state.hp||100)+s); showToast('Soins off-record !','+'+s+' HP.',true); },
    commercant:  () => { state.pop=Math.min(100,(state.pop||0)+4); state.inf=Math.min(100,(state.inf||0)+2); showToast('Reputation locale !','+4 POP +2 INF.',true); },
    juge:        () => { const t=Math.min(55,20+Math.floor(dup*2)); const r=Math.floor(Math.random()*100)+1; if(r<=t){state.dis=Math.max(0,(state.dis||50)-8);showToast('Le juge est comprehensif.','-8 DIS.',true,true);}else{state.dis=Math.max(0,(state.dis||50)-25);showToast('SCANDALE !','-25 DIS.',false);} },
    avocat:      () => { state.inf=Math.min(100,(state.inf||0)+5); showToast('L\'avocat note votre generosite.','+5 INF.',true); },
    loge:        () => { state.inf=Math.min(100,(state.inf||0)+8); showToast('Don a la Loge.','+8 INF.',true,true); },
    grand_pretre:() => { state.pop=Math.min(100,(state.pop||0)+5); state.moral=Math.min(100,(state.moral||50)+5); showToast('Don beni !','+5 POP +5 Moral.',true,true); },
    escort:      () => { state.inf=Math.min(100,(state.inf||0)+6); showToast('Information exclusive !','+6 INF.',true,true); },
  };
  const effet = effets[job];
  if (effet) { effet(); }
  else {
    const moralBonus = Math.min(8, Math.floor(montant / 50));
    state.moral = Math.min(100,(state.moral||50)+moralBonus);
    showToast('Don accepte.', nomCourt+' apprecie. +'+moralBonus+' Moral.', true);
    addJournalEntry('Don a '+nomCourt+'.','event-good');
  }
  updateUI();
}

// =====================
// V27 — DON D'OBJET A UN PNJ
// =====================
function ouvrirDonObjetPnjModal(encodedPnj) {
  let pnj;
  try { pnj = JSON.parse(decodeURIComponent(encodedPnj)); } catch(e) { return; }
  const objets = (state.inventory || []).filter(i => i.type !== 'acte_officiel');
  if (objets.length === 0) { showToast('Inventaire vide', 'Aucun objet a donner.', false); return; }
  // modal-pnj reste ouvert
  document.getElementById('postes-modal-title').textContent = 'Donner un objet a ' + pnj.name.replace(' (PNJ)', '');
  let html = '<div style="padding:.8rem 1rem"><div style="font-size:.75rem;color:#8a8060;font-style:italic;margin-bottom:.7rem">Choisir l\'objet a remettre :</div>';
  objets.forEach((obj, i) => {
    const idx = state.inventory.indexOf(obj);
    html += '<div onclick="confirmerDonObjetPnj('+idx+',\''+encodedPnj+'\')" style="display:flex;align-items:center;gap:.6rem;padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;cursor:pointer" onmouseover="this.style.background=\'#151005\'" onmouseout="this.style.background=\'#0f0d05\'"><i class="ti '+(obj.icon||'ti-package')+'" style="font-size:.9rem;color:#8a6a20"></i><div><div style="font-size:.8rem;color:#c0b090">'+obj.name+'</div><div style="font-size:.65rem;color:#4a4030">'+(obj.desc||'')+'</div></div></div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerDonObjetPnj(objIdx, encodedPnj) {
  let pnj;
  try { pnj = JSON.parse(decodeURIComponent(encodedPnj)); } catch(e) { return; }
  const obj = state.inventory[objIdx];
  if (!obj) return;
  const job = pnj.job || 'default';
  const nomCourt = pnj.name.replace(' (PNJ)','');
  document.getElementById('modal-postes').classList.remove('open');
  let msg = '', bon = true;
  if (obj.type === 'tract') {
    obj.quantite = (obj.quantite||1) - 1;
    if (obj.quantite <= 0) state.inventory.splice(objIdx, 1);
    state.pop = Math.min(100,(state.pop||0)+2);
    msg = nomCourt + ' prend le tract. +2 POP.';
    addJournalEntry('Tract remis a '+nomCourt+'.','event-good');
  } else if (obj.type === 'kompromat') {
    if (['journaliste','redacteur'].includes(job)) {
      state.inventory.splice(objIdx,1); state.inf=Math.min(100,(state.inf||0)+8); state.pop=Math.min(100,(state.pop||0)+5);
      const cible=obj.cible||'une personnalite';
      addExternalEvent('SCANDALE : Un kompromat sur '+cible+' a ete divulgue !');
      msg='Le journaliste s\'empare du dossier. +8 INF +5 POP.';
    } else {
      state.inventory.splice(objIdx,1); state.inf=Math.min(100,(state.inf||0)+3);
      msg=nomCourt+' prend le document. +3 INF.';
    }
  } else {
    state.inventory.splice(objIdx,1); state.moral=Math.min(100,(state.moral||50)+3); state.inf=Math.min(100,(state.inf||0)+2);
    msg=nomCourt+' accepte le cadeau. +3 Moral +2 INF.';
    addJournalEntry('Objet offert a '+nomCourt+'.','event-good');
  }
  updateUI();
  showToast(bon?'Don effectue !':'Action risquee.', msg, bon);
  if (pnj.isPJ) tracerActionPourRumeur('don_objet', nomCourt);
}


// =====================

// FONCTIONS MANQUANTES — avec prélèvement
// =====================

function doAcheterEntreprise() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cost = 8000;
  if (state.arg < cost) { showToast('Fonds insuffisants', cost.toLocaleString('fr-FR') + ' ' + cur + ' requis.', false); return; }
  state.arg -= cost;
  state.pop = Math.min(100, (state.pop||0) + 5);
  state.inf = Math.min(100, (state.inf||0) + 8);
  addToInventory({ name: "Acte d'acquisition d'entreprise", icon: 'ti-building-factory', type: 'acte_officiel', legal: true, desc: 'Vous êtes propriétaire d\'une entreprise locale.' });
  updateUI();
  showToast('Entreprise achetée !', '-' + cost.toLocaleString('fr-FR') + ' ' + cur + '. +5 POP +8 INF.', true);
  addJournalEntry('Achat entreprise. -' + cost.toLocaleString('fr-FR') + ' ' + cur + '.', 'event-good');
}

function doArreter() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cost = 500;
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  state.arg -= cost;
  const isn = INDICES_NATIONAUX?.[state.country]?.ISN || 30;
  INDICES_NATIONAUX[state.country] = INDICES_NATIONAUX[state.country] || {};
  INDICES_NATIONAUX[state.country].ISN = Math.min(100, isn + 5);
  updateUI();
  showToast('Arrestation ordonnée', '-' + cost + ' ' + cur + '. +5 ISN.', false);
  addJournalEntry('Ordre d\'arrestation. -' + cost + ' ' + cur + '.', 'event-bad');
}

function doCompteOffshore() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cost = 1000;
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  state.arg -= cost;
  state.dis = Math.min(100, (state.dis||50) + 10);
  updateUI();
  showToast('Compte offshore ouvert', '-' + cost + ' ' + cur + '. +10 DIS. Transactions discrètes activées.', true);
  addJournalEntry('Compte offshore ouvert. -' + cost + ' ' + cur + '.', 'event-info');
}

function doCorrompreGardien() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cost = 800;
  const dup = state.char?.stats?.DUP || 8;
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  state.arg -= cost;
  const taux = Math.min(80, 30 + Math.floor(dup * 3));
  const roll = Math.floor(Math.random() * 100) + 1;
  if (roll <= taux) {
    state.dis = Math.max(0, (state.dis||50) - 5);
    updateUI();
    showToast('Gardien corrompu !', 'Il regardera ailleurs. -5 DIS.', true);
    addJournalEntry('Gardien corrompu. -' + cost + ' ' + cur + '.', 'event-bad');
  } else {
    updateUI();
    showToast('Refus du gardien !', 'Il n\'a pas accepté. Argent perdu.', false);
    addJournalEntry('Corruption gardien échouée. -' + cost + ' ' + cur + '.', 'event-bad');
  }
}

function doDefense() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cost = 300;
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  state.arg -= cost;
  state.dis = Math.min(100, (state.dis||50) + 8);
  updateUI();
  showToast('Défense renforcée', '-' + cost + ' ' + cur + '. +8 DIS. Votre sécurité est accrue.', true);
  addJournalEntry('Défense renforcée. -' + cost + ' ' + cur + '.', 'event-good');
}

function doDinerAffaires() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cost = 120;
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  state.arg -= cost;
  state.inf = Math.min(100, (state.inf||0) + 4);
  state.moral = Math.min(100, (state.moral||50) + 3);
  updateUI();
  showToast('Dîner d\'affaires', '-' + cost + ' ' + cur + '. +4 INF +3 Moral.', true);
  addJournalEntry('Dîner d\'affaires. -' + cost + ' ' + cur + '.', 'event-good');
}

function doFalsifierDocs() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cost = 500;
  const dup = state.char?.stats?.DUP || 8;
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  state.arg -= cost;
  const taux = Math.min(75, 25 + Math.floor(dup * 3));
  const roll = Math.floor(Math.random() * 100) + 1;
  if (roll <= taux) {
    addToInventory({ name: 'Document falsifié', icon: 'ti-file-x', type: 'document_falsifie', legal: false, desc: 'Document officiel falsifié.' });
    updateUI();
    showToast('Documents falsifiés !', '-' + cost + ' ' + cur + '. Document ajouté à l\'inventaire.', true);
    addJournalEntry('Falsification docs réussie. -' + cost + ' ' + cur + '.', 'event-bad');
  } else {
    updateUI();
    showToast('Falsification ratée !', 'Le faussaire a échoué. Argent perdu.', false);
  }
}

function doImprimerClandestin() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cost = 300;
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  state.arg -= cost;
  state.dis = Math.max(0, (state.dis||50) - 5);
  addToInventory({ name: 'Publication clandestine', icon: 'ti-file-description', type: 'tract', legal: false, quantite: 20, desc: 'Pamphlet imprimé clandestinement.' });
  updateUI();
  showToast('Impression clandestine !', '-' + cost + ' ' + cur + '. 20 tracts clandestins. -5 DIS.', true);
  addJournalEntry('Impression clandestine. -' + cost + ' ' + cur + '.', 'event-bad');
}

function doImprimerLivre() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cost = 500;
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  state.arg -= cost;
  state.pop = Math.min(100, (state.pop||0) + 6);
  state.inf = Math.min(100, (state.inf||0) + 4);
  addToInventory({ name: 'Livre publié', icon: 'ti-book', type: 'document', legal: true, desc: 'Votre ouvrage, publié à compte d\'auteur.' });
  updateUI();
  showToast('Livre publié !', '-' + cost + ' ' + cur + '. +6 POP +4 INF.', true);
  addExternalEvent((state.char?.name||'Anonyme') + ' publie un ouvrage.');
  addJournalEntry('Publication livre. -' + cost + ' ' + cur + '.', 'event-good');
}

function doInvestir() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cost = 500;
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  state.arg -= cost;
  const roll = Math.floor(Math.random() * 100) + 1;
  const gain = roll > 40 ? Math.floor(cost * (0.5 + Math.random())) : 0;
  if (gain > 0) {
    state.arg += gain;
    updateUI();
    showToast('Investissement rentable !', '-' + cost + ' +' + gain + ' ' + cur + '. Bénéfice : ' + (gain-cost) + ' ' + cur + '.', true);
    addJournalEntry('Investissement réussi. +' + (gain-cost) + ' ' + cur + '.', 'event-good');
  } else {
    updateUI();
    showToast('Investissement raté', '-' + cost + ' ' + cur + '. Tout est perdu.', false);
    addJournalEntry('Investissement perdu. -' + cost + ' ' + cur + '.', 'event-bad');
  }
}

function doMarchander() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cost = 100;
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  state.arg -= cost;
  state.inf = Math.min(100, (state.inf||0) + 3);
  state.pop = Math.min(100, (state.pop||0) + 2);
  updateUI();
  showToast('Marchandage réussi', '-' + cost + ' ' + cur + '. +3 INF +2 POP.', true);
  addJournalEntry('Marchandage. -' + cost + ' ' + cur + '.', 'event-good');
}

function doReunionPrivee() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cost = 50;
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  state.arg -= cost;
  state.inf = Math.min(100, (state.inf||0) + 5);
  state.dis = Math.min(100, (state.dis||50) + 3);
  updateUI();
  showToast('Réunion discrète', '-' + cost + ' ' + cur + '. +5 INF +3 DIS.', true);
  addJournalEntry('Réunion privée. -' + cost + ' ' + cur + '.', 'event-info');
}

function doSocieteEcran() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cost = 500;
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  state.arg -= cost;
  state.dis = Math.min(100, (state.dis||50) + 12);
  updateUI();
  showToast('Société écran créée', '-' + cost + ' ' + cur + '. +12 DIS. Transactions masquées.', true);
  addJournalEntry('Société écran créée. -' + cost + ' ' + cur + '.', 'event-info');
}



function supprimerItemInventaire(idx) {
  if (!state.inventory[idx]) return;
  const item = state.inventory[idx];
  state.inventory.splice(idx, 1);
  renderInventory();
  showToast('Objet supprimé', item.name + ' retiré de l\'inventaire.', false);
}


// =====================

// =====================



// =====================
// RENDRE LA SENTENCE (complement tribunal)
// =====================

async function ouvrirRendreSentence() {
  document.getElementById('postes-modal-title').textContent = 'Rendre la sentence';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a8060;font-style:italic">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  // Charger depuis Supabase pour voir TOUTES les affaires transmises, par n'importe quel commissariat
  if (typeof sbLoadPlaintes === 'function') {
    try {
      const toutes = await sbLoadPlaintes(state.country);
      state.plaintesEnCours = toutes;
    } catch(e) {}
  }
  const affaires = state.plaintesEnCours?.filter(p => p.status === 'deposee') || [];

  let html = '<div style="padding:1rem">';
  if (affaires.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucune affaire en attente de jugement.</div>';
  } else {
    affaires.forEach((a) => {
      html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.8rem;margin-bottom:.6rem">';
      html += '<div style="font-family:Playfair Display,serif;font-size:.85rem;color:#E8C97A;margin-bottom:.3rem">Affaire : ' + a.cible + '</div>';
      html += '<div style="font-size:.72rem;color:#8a8060;margin-bottom:.6rem">' + a.motif + '</div>';
      html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.68rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.4rem">SENTENCE</div>';
      html += '<div style="display:flex;flex-direction:column;gap:.3rem">';
      html += '<button onclick="appliquerSentence(&quot;' + a.id + '&quot;,\'amende\')" style="text-align:left;padding:.4rem .7rem;border:1px solid #2a4a20;background:#0a0d05;color:#6a9a6a;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem">Amende (montant + repartition)</button>';
      html += '<button onclick="appliquerSentence(&quot;' + a.id + '&quot;,\'prison\')" style="text-align:left;padding:.4rem .7rem;border:1px solid #3a2a10;background:#0a0d05;color:#9a8a4a;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem">Prison (max 7 jours)</button>';
      html += '<button onclick="appliquerSentence(&quot;' + a.id + '&quot;,\'amenagement\')" style="text-align:left;padding:.4rem .7rem;border:1px solid #2a3a4a;background:#0a0d05;color:#6a8aaa;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem">Amenagement de peine (pointage commissariat)</button>';
      html += '<button onclick="appliquerSentence(&quot;' + a.id + '&quot;,\'qhs\')" style="text-align:left;padding:.4rem .7rem;border:1px solid #4a1a10;background:#0a0d05;color:#9a4a3a;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem">Envoi au QHS</button>';
      html += '</div></div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function appliquerSentence(affaireId, type) {
  const affaire = (state.plaintesEnCours||[]).find(p => p.id === affaireId);
  if (!affaire) return;
  affaire.status = 'jugee';

  const cur = COUNTRIES[state.country]?.cur || 'FR';
  let details = '';

  if (type === 'amende') {
    const montant = 500;
    details = 'Amende de ' + montant + ' ' + cur;
  } else if (type === 'prison') {
    const duree = 3;
    details = 'Prison ' + duree + ' jours';
    if (!state.prisonniers) state.prisonniers = [];
    state.prisonniers.push({ nom: affaire.cible, depuis: 'Jour ' + state.day, raison: affaire.motif, jourFin: state.day + duree });
  } else if (type === 'amenagement') {
    details = 'Amenagement : pointage quotidien au commissariat';
  } else if (type === 'qhs') {
    details = 'Envoi au QHS';
    if (!state.prisonniers) state.prisonniers = [];
    state.prisonniers.push({ nom: affaire.cible, depuis: 'Jour ' + state.day, raison: affaire.motif, jourFin: state.day + 30, qhs: true });
  }

  if (!state.archivesJugements) state.archivesJugements = [];
  state.archivesJugements.push({
    accuse: affaire.cible,
    motif: affaire.motif,
    peine: details,
    juge: state.char?.name || 'PNJ',
    jour: state.day,
    executee: false
  });

  if (typeof sbSavePlainte === 'function') await sbSavePlainte(affaire).catch(() => {});

  document.getElementById('modal-postes').classList.remove('open');
  showToast('Sentence rendue', affaire.cible + ' : ' + details, true, true);
  addExternalEvent('JUGEMENT : ' + affaire.cible + ' condamne(e) a : ' + details + ' (Juge : ' + (state.char?.name||'PNJ') + ')');
  if (typeof sbSendMail === 'function') {
    const h = String(state.hour || 8).padStart(2,'0');
    const time = 'Jour ' + (state.day || 1) + ' · ' + h + 'h';
    sbSendMail('Tribunal', affaire.cible, 'Resultat de votre affaire', 'La sentence a ete rendue : ' + details, time).catch(() => {});
  }
}

// =====================
