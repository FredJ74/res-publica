function doDonnerArgentPnj(pa, cost) {
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
    '<button onclick="confirmerDonArgent(' + pa + ',' + cost + ')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">💰 Donner</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerDonArgent(pa, cost) {
  const id = state.currentBuilding;
  const ts = getTerrainState(id);
  const pnj = ts.pnjData;
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const montant = parseInt(document.getElementById('don-montant')?.value || 0);
  const indices = INDICES_NATIONAUX?.[state.country] || { ISN:30, IE:50, IS:45 };
  const isn = indices.ISN || 30;

  if (!montant || montant <= 0) { showToast('Montant invalide', 'Entrez un montant.', false); return; }
  if (state.arg < montant) { showToast('Fonds insuffisants', montant + ' ' + cur + ' requis.', false); return; }
  const rDon = await deduireCoutOrdre({ pa, cost });
  if (!rDon.ok) { showToast('PA insuffisants', '', false); return; }

  const dup = getStatEffective('DUP');
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
      const cha = getStatEffective('CHA');
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

function doRacheterTerrain(pa, cost) {
  const building = state.currentBuilding;
  const b = BUILDINGS[building];
  if (!b) return;

  // Vérifier si le terrain appartient à quelqu'un (systeme unifie, source Supabase)
  const proprietaire = getTerrainState(building).proprietaire;
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
    '<button onclick="confirmerRachat(this,' + pa + ',' + cost + ')" data-building="' + building + '" data-proprio="' + proprietaire + '" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer;width:100%">Envoyer l\'offre</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerRachat(btn, pa, cost) {
  const buildingId = btn?.dataset?.building || btn;
  const proprietaire = btn?.dataset?.proprio;
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
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }

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

async function accepterRachat(acheteur, buildingId, prix) {
  if (typeof refuserSiGele === 'function' && await refuserSiGele('terrain', buildingId, 'Accepter ce rachat')) return;
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const b = BUILDINGS[buildingId];
  const localName = b?.shortName || b?.name || buildingId;

  // Transférer le terrain (systeme unifie : cache local + Supabase)
  const nouvelEtatRachat = setTerrainState(buildingId, { proprietaire: acheteur, coproprietaire: null });
  if (typeof sbSetTerrainState === 'function') {
    sbSetTerrainState(state.country, buildingId, nouvelEtatRachat).catch(() => {});
  }
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

async function doArreter(pa, cost) {
  const actif = typeof estEtatUrgenceActif === 'function' ? await estEtatUrgenceActif(state.country) : false;
  if (!actif) {
    showToast('Non autorise', "Cet ordre necessite que l'etat d'urgence soit en vigueur.", false);
    return;
  }
  const posteOk = ['president','min_just','min_int','juge'].includes(state.poste?.id);
  if (!posteOk) {
    showToast('Acces refuse', 'Reserve au President, au Ministre de la Justice, au Ministre de l\'Interieur ou a un Juge (Commissaire a venir).', false);
    return;
  }

  const contacts = state.contacts || [];
  const contactsSection = contacts.length === 0
    ? `<div style="font-size:.8rem;color:#7a5020;font-style:italic;padding:.5rem;background:#0f0805;border:1px solid #2a1810">Votre repertoire est vide. Enregistrez-y la personne visee au prealable.</div>`
    : contacts.map(c => `
        <label style="display:flex;align-items:center;gap:.5rem;font-size:.85rem;color:#c0b090;cursor:pointer;padding:.2rem 0">
          <input type="radio" name="arreter-cible" value="${c.name}" style="accent-color:#C9A84C"/>
          ${c.name} — ${c.role || ''}
        </label>`).join('');

  document.getElementById('postes-modal-title').textContent = 'Faire arreter quelqu\'un';
  document.getElementById('postes-body').innerHTML = `
    <div style="padding:1rem">
      <div style="font-size:.82rem;color:#8a3a2a;font-style:italic;margin-bottom:1rem">Mesure exceptionnelle sous etat d'urgence. Une arrestation infondee vous exposera a un lourd malus.</div>
      <div style="font-family:'Bebas Neue',sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.5rem">CIBLE (dans votre repertoire)</div>
      ${contactsSection}
      <div style="font-family:'Bebas Neue',sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin:1rem 0 .4rem">MOTIF DU DOSSIER</div>
      <textarea id="arreter-motif" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.6rem;font-family:'Crimson Pro',serif;font-size:.85rem;height:70px;outline:none;resize:none" placeholder="Faits reproches..."></textarea>
      <button onclick="confirmerArrestation(${pa},${cost})" style="margin-top:.8rem;font-family:'Bebas Neue',sans-serif;letter-spacing:.1em;font-size:.82rem;padding:.5rem 1.2rem;border:1px solid #8a3a2a;background:transparent;color:#c0503a;cursor:pointer">
        <i class="ti ti-handcuffs" style="font-size:.8rem"></i> Ordonner l'arrestation
      </button>
    </div>
  `;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerArrestation(pa, cost) {
  const cibleInput = document.querySelector('input[name="arreter-cible"]:checked');
  const motif = document.getElementById('arreter-motif')?.value?.trim();
  if (!cibleInput) { showToast('Cible requise', 'Choisissez une personne de votre repertoire.', false); return; }
  if (!motif) { showToast('Motif requis', 'Precisez le motif du dossier.', false); return; }
  const rArret = await deduireCoutOrdre({ pa, cost });
  if (!rArret.ok) { showToast('PA insuffisants', '', false); return; }
  const cible = cibleInput.value;
  document.getElementById('modal-postes').classList.remove('open');

  const from = state.char?.name || 'Autorite';
  const preuveReelle = await verifierPreuveReelle(state.country, cible, motif).catch(() => false);
  let roll = Math.floor(Math.random() * 100) + 1;
  if (preuveReelle) roll = Math.max(roll, 75);

  if (roll >= 50) {
    const jours = 2;
    const infoArrestation = { jours, jourFin: null, raison: 'Arrestation sur ordre de ' + from + ' (' + motif + ')' };
    if (typeof sbUpdate === 'function') {
      await sbUpdate('personnages', `name=eq.${encodeURIComponent(cible)}`, { est_emprisonne: JSON.stringify(infoArrestation) }).catch(() => {});
    }
    addExternalEvent('ARRESTATION : ' + cible + ' a ete place(e) en garde a vue sur ordre de ' + from + ', dans le cadre de l\'etat d\'urgence.', 'local');
    if (typeof tracerActionPourRumeur === 'function') tracerActionPourRumeur('arrestation_urgence', cible);
    addJournalEntry('Arrestation ordonnee contre ' + cible + '. Motif : ' + motif + '.', 'event-info');
    showToast('Arrestation executee', cible + ' a ete place(e) en garde a vue.', true);
  } else {
    state.pop = Math.max(0, (state.pop || 50) - 10);
    state.dis = Math.max(0, (state.dis || 0) - 8);
    updateUI();
    if (typeof tracerActionPourRumeur === 'function') tracerActionPourRumeur('arrestation_urgence_abusive', cible);
    addJournalEntry('Tentative d\'arrestation contre ' + cible + ' rejetee (dossier juge insuffisant). -10 POP, -8 DIS.', 'event-bad');
    showToast('Arrestation rejetee', 'Le dossier a ete juge insuffisant. -10 POP, -8 DIS.', false);
  }
}

function openPlainteModal(pa, cost) {
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
      <button onclick="soumettrePlaynte(${pa},${cost})" style="font-family:'Bebas Neue',sans-serif;letter-spacing:.1em;font-size:.82rem;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">
        <i class="ti ti-send" style="font-size:.8rem"></i> Deposer la plainte
      </button>
    </div>
  `;

  document.getElementById('postes-modal-title').textContent = 'Porter plainte';
  document.getElementById('postes-body').innerHTML = modalHtml;
  document.getElementById('modal-postes').classList.add('open');
}

async function soumettrePlaynte(pa, cost) {
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }
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

// Verifie si une accusation repose sur une action reellement tracee (ex: torture au QHS).
// Se base sur une simple detection du mot dans le motif — volontairement simple, en coherence
// avec le choix de ne pas creer d'ordre dedie "porter plainte pour X".
async function verifierPreuveReelle(country, accuse, motif) {
  const motifLower = (motif || '').toLowerCase();
  if (motifLower.includes('tortur')) {
    if (typeof sbGetActionsTracablesParAuteur === 'function') {
      const actions = await sbGetActionsTracablesParAuteur(country, accuse, 'torture_qhs', state.day || 1).catch(() => []);
      if (actions && actions.length > 0) return true;
    }
  }
  return false;
}

async function traiterPlaintes() {
  if (!state.plaintesEnCours) return;
  const traitees = state.plaintesEnCours.filter(p => p.day <= state.day && p.status === 'pending');
  for (const p of traitees) {
    p.status = 'done';
    let roll = Math.floor(Math.random() * 100) + 1;
    // Preuve reelle trouvee : le resultat est quasi automatiquement a charge, peu importe le
    // hasard du jet de base — une plainte gratuite sans preuve reste soumise a l'alea habituel.
    const preuveReelle = await verifierPreuveReelle(p.country || state.country, p.cible, p.motif);
    if (preuveReelle) roll = Math.max(roll, 80);
    let result = '';
    let notifierJoueurs = true;
    if (roll < 40) {
      result = `Classement sans suite. La plainte contre ${p.cible} n'a pas abouti.`;
      if (typeof tracerActionPourRumeur === 'function') tracerActionPourRumeur('plainte_sans_suite', p.cible);
      notifierJoueurs = false;
    } else if (roll < 75) {
      result = `Ouverture d'une enquete concernant ${p.cible}. Conclusions dans 24h.`;
      // Programmer le resultat de l'enquete (motif transporte pour le tribunal)
      if (!state.enquetesEnCours) state.enquetesEnCours = [];
      // city propagee depuis la plainte d'origine (A3 lot judiciaire) -- l'enquete concerne la
      // meme affaire, elle doit rester attachee a la meme ville.
      state.enquetesEnCours.push({ cible: p.cible, motif: p.motif, country: p.country || state.country, city: p.city, day: state.day + 1, status: 'pending' });
      if (typeof tracerActionPourRumeur === 'function') tracerActionPourRumeur('plainte_enquete', p.cible);
    } else {
      result = `Actes illegaux confirmes pour ${p.cible}. Mise en garde a vue. Proces dans 24h.`;
      addExternalEvent(`ACTION EXTERIEURE : ${p.cible} a ete place(e) en garde a vue suite a votre plainte. Proces prevu demain.`, 'local');
      if (typeof tracerActionPourRumeur === 'function') tracerActionPourRumeur('plainte_confirmee', p.cible);
      // Transmettre directement au tribunal — l'affaire est mure pour jugement
      transmettreAffaireAuTribunal(p.cible, p.motif || 'Plainte initiale confirmee par les forces de l\'ordre.', p.city);
    }
    if (notifierJoueurs) {
      // "Jour N" retire du sujet/corps (correctif du 21 aout 2026) : p.day reste utilise tel
      // quel plus haut dans cette fonction pour la logique de traitement, seul l'affichage change.
      addMailNotification('Commissariat Central', `RE: Votre plainte`, result);
      if (p.cible && p.cible !== 'X' && typeof envoyerNotificationVraiJoueur === 'function') {
        await envoyerNotificationVraiJoueur(p.cible, 'Convocation - Plainte a votre encontre', 'Une plainte a ete deposee contre vous, elle a evolue : ' + result);
      }
    }
    if (typeof sbSavePlainte === 'function') sbSavePlainte(p).catch(() => {});
  }
}

async function traiterEnquetes() {
  if (!state.enquetesEnCours) return;
  const traitees = state.enquetesEnCours.filter(e => e.day <= state.day && e.status === 'pending');
  for (const e of traitees) {
    e.status = 'done';
    let roll = Math.floor(Math.random() * 100) + 1;
    const preuveReelle = await verifierPreuveReelle(e.country || state.country, e.cible, e.motif);
    if (preuveReelle) roll = Math.max(roll, 60);
    let result = '';
    if (roll < 50) {
      result = `Enquete conclue : non-lieu pour ${e.cible}. Aucune preuve suffisante.`;
    } else {
      result = `Enquete conclue : actes illegaux confirmes pour ${e.cible}. Mise en garde a vue immediate. Affaire transmise au tribunal pour jugement.`;
      await enregistrerDetention(e.cible, 'Garde a vue suite a enquete', undefined, undefined, e.city);
      addExternalEvent(`${e.cible} a ete place(e) en garde a vue. Affaire transmise au tribunal.`, 'local');
      // Transmettre au tribunal pour jugement public
      transmettreAffaireAuTribunal(e.cible, e.motif || 'Enquete policiere ayant confirme des actes illegaux.', e.city);
    }
    addMailNotification('Brigade Criminelle', `Conclusions enquete : ${e.cible}`, result);
  }
}

// A3 (lot judiciaire, 16 aout 2026) : city desormais un parametre explicite -- une affaire
// appartient a la ville ou elle a ete constatee (plainte/enquete d'origine), jamais a
// state.currentCity du joueur qui declenche par hasard le traitement differe (minuit/dormir)
// ou qui execute cette fonction. Repli sur state.currentCity UNIQUEMENT si l'appelant ne
// connait vraiment aucune ville (compatibilite avec d'anciennes donnees sans city).
function transmettreAffaireAuTribunal(cible, motif, city) {
  const villeReelle = city || state.currentCity || 'capitale';
  const forumKey = 'tribunal_' + villeReelle;

  // Ajouter à la file d'attente du juge (statut lu par ouvrirRendreSentence) — visible par TOUS les juges via Supabase
  if (!state.plaintesEnCours) state.plaintesEnCours = [];
  const affaireTransmise = { id: 'affaire-' + Date.now(), country: state.country, city: villeReelle, cible, motif, jour: state.day, status: 'deposee' };
  state.plaintesEnCours.push(affaireTransmise);
  if (typeof sbSavePlainte === 'function') sbSavePlainte(affaireTransmise).catch(() => {});

  // Publier sur le forum tribunal local (visible de tous, transparence judiciaire)
  if (!FORUM_TOPICS[forumKey]) FORUM_TOPICS[forumKey] = [];
  const timeAffaire = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : 'Jour ' + (state.day || 1);
  FORUM_TOPICS[forumKey].unshift({
    id: 'affaire-' + Date.now(),
    title: '[AFFAIRE TRANSMISE] ' + cible,
    author: 'Brigade Criminelle',
    time: timeAffaire,
    replies: 0,
    isPlainte: true,
    cible,
    posts: [{
      author: 'Brigade Criminelle',
      time: timeAffaire,
      content: '**AFFAIRE TRANSMISE AU TRIBUNAL**\n\nMis en cause : ' + cible + '\n\nMotif :\n' + motif + '\n\n_En attente de jugement par un magistrat._'
    }]
  });

  // Publier aussi sur Supabase pour que tous les joueurs de la ville le voient
  if (typeof sbCreateTopic === 'function') {
    const auteur = 'Brigade Criminelle';
    const heure = timeAffaire;
    const textePost = '**AFFAIRE TRANSMISE AU TRIBUNAL**\n\nMis en cause : ' + cible + '\n\nMotif :\n' + motif + '\n\n_En attente de jugement par un magistrat._';
    sbCreateTopic(forumKey, '⚖️ [AFFAIRE] ' + cible, auteur, state.country, heure)
      .then(topicId => {
        if (topicId && typeof sbCreatePost === 'function') {
          sbCreatePost(topicId, auteur, textePost, heure);
        }
      }).catch(e => console.warn('Erreur transmission tribunal:', e));
  }
}

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
  const pire = state.recherche.reduce((max, r) => {
    const pMax = getPeineParActe(max.acte, false);
    const pR = getPeineParActe(r.acte, false);
    return pR.jours > pMax.jours ? r : max;
  }, state.recherche[0]);

  const roll = Math.floor(Math.random() * 100) + 1;
  const tauxInter = Math.max(5, 30 - Math.floor(state.dis / 5));

  if (roll <= tauxInter) {
    ouvrirModalArrestation(pire.acte);
  }
}

function checkArrestationAuReveil() {
  // Chance reduite d'arrestation pendant la nuit
  if (!state.recherche || state.recherche.length === 0) return;
  const roll = Math.floor(Math.random() * 100) + 1;
  if (roll <= 10) {
    const acteMax = state.recherche[state.recherche.length - 1]?.acte || 'delit_mineur';
    addExternalEvent('La police a retrouve votre trace. Vous avez ete arrete(e) dans la nuit.');
    procederArrestation(acteMax, false, false);
  }
}

// =====================
// SE JUSTIFIER (suite a convocation — ex: achat d'arme illegal echoue)
// =====================
function doSeJustifier(pa, cost) {
  const convocation = (state.convocations || []).find(c => !c.traitee);
  if (!convocation) {
    showToast('Rien à signaler', "Vous n'avez aucune convocation en attente.", false);
    return;
  }

  const motifLabel = {
    achat_arme_illegal: "tentative d'achat d'arme non enregistrée",
    possession_illegale_douane: "possession d'objets prohibés découverte au contrôle douanier"
  }[convocation.motif] || convocation.motif;

  document.getElementById('postes-modal-title').textContent = 'Convocation — Se justifier';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#a09070;line-height:1.7;font-style:italic;margin-bottom:1rem">Vous êtes entendu(e) au sujet de : ' + motifLabel + '. L\'entretien prend du temps.</div>';
  html += '<button onclick="confirmerSeJustifier(' + pa + ',' + cost + ')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Se présenter (2 PA)</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerSeJustifier(pa, cost) {
  document.getElementById('modal-postes').classList.remove('open');
  const convocation = (state.convocations || []).find(c => !c.traitee);
  if (!convocation) { showToast('Rien à signaler', '', false); return; }

  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', 'Il vous manque des PA pour vous présenter.', false); return; }

  convocation.traitee = true;

  // Lever l'avis de recherche lie a ce motif precis
  if (state.recherche) {
    state.recherche = state.recherche.filter(r => r.acte !== convocation.motif);
  }

  updateUI();
  showToast('Convocation traitée', 'Vous vous êtes justifié(e). Avis de recherche levé pour ce motif.', true, true);
  addJournalEntry('Vous vous êtes présenté(e) au commissariat suite à convocation.', 'event-info');
}

// Verification periodique (a minuit) : convocations non honorees dans le delai -> arrestation
function traiterConvocations() {
  if (!state.convocations) return;
  const enRetard = state.convocations.filter(c =>
    !c.traitee && (state.day > c.jourLimite || (state.day === c.jourLimite && (state.hour || 0) >= c.heureLimite))
  );
  if (enRetard.length === 0) return;

  enRetard.forEach(c => { c.traitee = true; });

  procederArrestation(enRetard[0].motif, false, false);
  addMailNotification('Commissariat', 'Non-présentation', "Vous ne vous êtes pas présenté(e) dans le délai imparti suite à votre convocation. Vous êtes arrêté(e).");
}

function ouvrirModalArrestation(acte) {
  const peine = getPeineParActe(acte, false);
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
    '<button onclick="procederArrestation(\'' + acte + '\',false,false);document.getElementById(\'modal-postes\').classList.remove(\'open\')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1rem;border:1px solid #4a6a4a;background:transparent;color:#6a9a6a;cursor:pointer"><i class="ti ti-check" style="font-size:.8rem"></i> Se rendre</button>' +
    '<button onclick="tenterCorruptionArrestation(\'' + acte + '\',' + cout + ',' + taux + ')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer"><i class="ti ti-coin" style="font-size:.8rem"></i> Corrompre l\'agent (' + cout + ' ' + cur + ' · ' + taux + '%)</button>' +
    '<button onclick="tenterFuite()" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1rem;border:1px solid #8a6a20;background:transparent;color:#8a8060;cursor:pointer"><i class="ti ti-run" style="font-size:.8rem"></i> Fuir (VOL+DIS)</button>' +
    '<button onclick="tenterResistance(\'' + acte + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1rem;border:1px solid #8a2020;background:transparent;color:#cc4444;cursor:pointer"><i class="ti ti-sword" style="font-size:.8rem"></i> Résister (très risqué)</button>' +
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
  const dup = getStatEffective('DUP');
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
    procederArrestation(peineType, true, false);
  }
}

function procederArrestation(acte, resistanceAggravante, demasque) {
  if (state.immuniteMilitaireActuelle) {
    showToast('Immunité militaire', 'En tant que militaire déployé en zone de guerre ou de mobilisation nationale, vous ne pouvez pas être poursuivi(e) pour cet acte.', true);
    addJournalEntry('Immunité militaire invoquée — aucune poursuite pour : ' + (ACTES_ILLEGAUX[acte]?.label || acte) + '.', 'event-info');
    return;
  }
  const peineCalc = getPeineParActe(acte, demasque);
  const jours = peineCalc.jours + (resistanceAggravante ? 2 : 0);
  const amende = peineCalc.amende;
  const typeBase = ACTES_ILLEGAUX[acte]?.type || acte;

  state.estEmprisonne = { jours, jourFin: state.day + jours, raison: peineCalc.label };
  state.recherche = [];
  if (amende > 0) state.arg = Math.max(0, state.arg - amende);
  if (state.poste && typeBase === 'crime') {
    addExternalEvent('Votre poste de ' + state.poste.name + ' vous a ete retire suite a votre arrestation.');
    state.poste = null;
    if (state.char) state.char.poste = null;
  }
  updateUI();
  addExternalEvent('Vous avez ete arrete(e) pour ' + peineCalc.label + '. ' + jours + ' jour(s) d\'emprisonnement. Amende : ' + amende.toLocaleString('fr-FR') + ' FR.');
  // Auto-referent : l'arrestation a lieu ici et maintenant, sur le joueur lui-meme -- city
  // explicite plutot qu'implicite (A3, lot judiciaire), meme comportement qu'avant.
  enregistrerDetention(state.char?.name, peineCalc.label, state.day + jours, undefined, state.currentCity).catch(() => {});

  // Teleportation en cellule de garde a vue
  state.currentBuilding = 'commissariat';
  state.currentRoom = 'prison';
  if (typeof enterBuilding === 'function' && document.getElementById('vue-batiment')) {
    enterBuilding('commissariat', true);
    if (typeof enterRoom === 'function') enterRoom('commissariat', 'prison', null);
  }
}

// Verification periodique (a minuit / au reveil) : liberation automatique en fin de peine
function verifierLiberationPrisonniers() {
  if (!state.estEmprisonne) return;
  if (state.day >= state.estEmprisonne.jourFin) {
    state.estEmprisonne = null;
    addMailNotification('Commissariat', 'Libération', 'Votre peine est purgée. Vous êtes libre de circuler.');
    addJournalEntry('Vous avez purgé votre peine et êtes libéré(e).', 'event-good');
    updateUI();
  }
}

function tenterFuite() {
  document.getElementById('modal-postes').classList.remove('open');
  const vol = getStatEffective('VOL');
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
    const peineType = state.recherche?.[0]?.acte || 'delit_mineur';
    procederArrestation(peineType, true, false);
  }
}

function tenterResistance(peineType) {
  document.getElementById('modal-postes').classList.remove('open');
  const vol = getStatEffective('VOL');
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
    procederArrestation(peineType, true, false);
    state.hp = Math.max(1, state.hp - 20);
    updateUI();
  }
}

// Resout la provenance d'un jugement vers son nom de ville affichable, en reutilisant
// exclusivement les donnees WORLD deja existantes (aucune table de correspondance codee en dur).
// j.country/j.city sont deja ecrits tels quels par appliquerSentence -> sbCreerJugement (voir
// plus bas) ; cette fonction ne fait que les relire pour l'affichage, aucune persistance touchee.
function libelleTribunalOrigine(j) {
  const pays = j.country || state.country || 'republic';
  const nomVille = WORLD[pays]?.[j.city]?.name;
  return nomVille ? ('Tribunal de ' + nomVille) : 'Tribunal (ville inconnue)';
}

async function ouvrirArchivesTribunal() {
  document.getElementById('postes-modal-title').textContent = 'Archives du Tribunal';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  if (typeof sbLoadJugements === 'function') {
    try {
      const tous = await sbLoadJugements(state.country);
      if (tous) state.archivesJugements = tous;
    } catch(e) {}
  }
  const jugements = state.archivesJugements || [];
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
      html += '<div style="font-size:.68rem;color:#8a6a20;margin-top:.15rem">' + libelleTribunalOrigine(j) + '</div>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

function ouvrirDetailJugement(idx) {
  const j = (state.archivesJugements||[])[idx];
  if (!j) return;
  document.getElementById('postes-modal-title').textContent = 'Jugement — ' + j.accuse;
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#6a5a30;margin-bottom:.5rem">Date : Jour ' + j.jour + ' · Juge : ' + (j.juge||'PNJ') + '</div>';
  html += '<div style="font-size:.78rem;color:#8a6a20;margin-bottom:.5rem">' + libelleTribunalOrigine(j) + '</div>';
  html += '<div style="font-size:.82rem;color:#c0b090;margin-bottom:.3rem">Motif : ' + j.motif + '</div>';
  html += '<div style="font-size:.82rem;color:#c0b090;margin-bottom:.3rem">Peine : ' + (j.peine||'N/A') + '</div>';
  if (j.executee !== undefined) html += '<div style="font-size:.78rem;color:' + (j.executee ? '#4a8a4a' : '#8a6a20') + '">' + (j.executee ? 'Peine executee' : 'Peine en cours ou amenagee') + '</div>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function ouvrirPorterPlainte(pa, cost) {
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }
  const ville = WORLD[state.country]?.[state.currentCity]?.name || 'la ville';
  document.getElementById('postes-modal-title').textContent = 'Affaires en cours — ' + ville;
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a8060;font-style:italic">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  // Charger depuis Supabase pour voir les affaires de TOUS les joueurs de la ville, pas juste les siennes
  if (typeof sbLoadPlaintes === 'function') {
    try {
      const toutes = await sbLoadPlaintes(state.country);
      state.plaintesEnCours = toutes;
    } catch(e) {}
  }
  const affaires = (state.plaintesEnCours || []).filter(p => p.city === state.currentCity);
  // Note : les enquetes en cours (state.enquetesEnCours) ne sont pour l'instant pas partagees
  // via Supabase — elles ne remontent donc que si VOUS etes a l'origine de la plainte qui a
  // ouvert l'enquete, pas celles des autres joueurs. A corriger dans un futur passage.
  const enquetes = (state.enquetesEnCours || []).filter(e => e.status === 'pending');

  const LIBELLES_STATUT = {
    pending: { texte: 'En attente de traitement', col: '#8a7040' },
    done:    { texte: 'Classée sans suite',        col: '#5a5040' },
    deposee: { texte: 'Transmise au tribunal — en attente de jugement', col: '#C9A84C' },
    jugee:   { texte: 'Jugée',                     col: '#6a8a4a' }
  };

  let html = '<div style="padding:1rem">';

  if (affaires.length === 0 && enquetes.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucune affaire en cours pour le moment.</div>';
  } else {
    affaires.forEach(a => {
      const statut = LIBELLES_STATUT[a.status] || { texte: a.status || 'Autre', col: '#8a8060' };
      html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem">';
      html += '<div style="display:flex;justify-content:space-between;align-items:center">';
      html += '<div style="font-family:Playfair Display,serif;font-size:.82rem;color:#c0b090">' + (a.cible || 'Affaire') + '</div>';
      html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.68rem;letter-spacing:.06em;color:' + statut.col + '">' + statut.texte + '</div>';
      html += '</div>';
      if (a.motif) html += '<div style="font-size:.7rem;color:#6a5a30;margin-top:.2rem">' + a.motif + '</div>';
      html += '<div style="font-size:.85rem;color:#9a8a68;margin-top:.3rem">Jour ' + a.jour + '</div>';
      html += '</div>';
    });
    enquetes.forEach(e => {
      html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem">';
      html += '<div style="display:flex;justify-content:space-between;align-items:center">';
      html += '<div style="font-family:Playfair Display,serif;font-size:.82rem;color:#c0b090">' + (e.cible || 'Affaire') + '</div>';
      html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.68rem;letter-spacing:.06em;color:#8a5a2a">Enquête en cours</div>';
      html += '</div>';
      if (e.motif) html += '<div style="font-size:.7rem;color:#6a5a30;margin-top:.2rem">' + e.motif + '</div>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

// SE DEFENDRE — formule validée avec Fred :
// Taux = 50 (base) + (CHA-8)*3 (bonus/malus charisme) - 35 si preuve reelle contre l'accuse.
// 4 resultats selon le jet : reussite critique (classe l'affaire), reussite simple
// (circonstance attenuante), echec simple (rien), echec critique >90 (aggravation).
async function doDefense(pa, cost) {
  const affaire = (state.plaintesEnCours || []).find(p => p.cible === state.char?.name && p.status === 'deposee');
  if (!affaire) {
    showToast('Aucune affaire', "Vous n'avez aucune affaire en attente de jugement pour le moment.", false);
    return;
  }
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('Fonds insuffisants', 'Vous défendre coûte ' + cost + ' ' + cur + '.', false); return; }

  const cha = getStatEffective('CHA');
  const bonusCha = (cha - 8) * 3;
  const preuveReelle = typeof verifierPreuveReelle === 'function'
    ? await verifierPreuveReelle(affaire.country || state.country, affaire.cible, affaire.motif).catch(() => false)
    : false;
  const malusPreuve = preuveReelle ? 35 : 0;
  const taux = Math.max(5, Math.min(90, 50 + bonusCha - malusPreuve));

  const roll = Math.floor(Math.random() * 100) + 1;
  let titre, message, journal, bon;

  if (roll <= taux - 30) {
    affaire.status = 'jugee';
    affaire.resultatDefense = 'reussite_critique';
    titre = 'Affaire classée !';
    message = 'Votre défense est si convaincante que l\'affaire est classée sur le champ.';
    journal = 'Défense réussie de façon éclatante — affaire classée (jet ' + roll + '/' + taux + '%).';
    bon = true;
  } else if (roll <= taux) {
    affaire.circonstanceAttenuante = true;
    titre = 'Défense entendue';
    message = 'Votre défense a porté. Le juge en tiendra compte (peine réduite si prison choisie).';
    journal = 'Défense réussie — circonstance atténuante enregistrée (jet ' + roll + '/' + taux + '%).';
    bon = true;
  } else if (roll > 90) {
    affaire.aggravation = true;
    titre = 'Aggravation';
    message = 'Votre défense s\'est retournée contre vous. Le juge en sera informé.';
    journal = 'Défense ratée de façon flagrante — aggravation enregistrée (jet ' + roll + '/' + taux + '%).';
    bon = false;
  } else {
    titre = 'Défense infructueuse';
    message = 'Votre défense n\'a pas convaincu. L\'affaire suit son cours normal.';
    journal = 'Défense infructueuse — l\'affaire suit son cours (jet ' + roll + '/' + taux + '%).';
    bon = false;
  }

  if (typeof sbSavePlainte === 'function') sbSavePlainte(affaire).catch(() => {});
  document.getElementById('modal-postes')?.classList.remove('open');
  showToast(titre, message, bon);
  addJournalEntry(journal, bon ? 'event-good' : 'event-bad');
  updateUI();
}

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

function doRequeteAvocat(pa, cost) {
  if (!state.estEmprisonne) {
    showToast('Inutile', "Vous n'êtes pas emprisonné(e) actuellement.", false);
    return;
  }
  if (state.estEmprisonne.avocatUtilise) {
    showToast('Déjà fait', 'Vous avez déjà consulté un avocat pour cette peine.', false);
    return;
  }
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cout = 800;

  document.getElementById('postes-modal-title').textContent = 'Requérir un avocat';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#a09070;line-height:1.7;font-style:italic;margin-bottom:1rem">Un avocat commis peut plaider un vice de procédure et faire réduire votre peine. Ses services ne sont pas gratuits, et le succès n\'est pas garanti. Une seule tentative par peine.</div>';
  html += '<div style="display:flex;justify-content:space-between;align-items:center;padding:.6rem;background:#0a0805;border:1px solid #2a2010;margin-bottom:.8rem">';
  html += '<span style="font-size:.75rem;color:#6a5a30">Honoraires</span>';
  html += '<span style="font-family:Bebas Neue,sans-serif;font-size:1rem;color:#C9A84C">' + cout.toLocaleString('fr-FR') + ' ' + cur + '</span>';
  html += '</div>';
  html += '<button onclick="confirmerRequeteAvocat(' + pa + ',' + cost + ')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Engager l\'avocat</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerRequeteAvocat(pa, cost) {
  document.getElementById('modal-postes').classList.remove('open');
  if (!state.estEmprisonne || state.estEmprisonne.avocatUtilise) return;
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cout = 800;
  if (state.arg < cout) { showToast('Fonds insuffisants', cout.toLocaleString('fr-FR') + ' ' + cur + ' requis.', false); return; }
  const rAvocat = await deduireCoutOrdre({ pa, cost: 0 });
  if (!rAvocat.ok) { showToast('PA insuffisants', '', false); return; }

  state.arg -= cout;
  state.estEmprisonne.avocatUtilise = true;

  const dup = getStatEffective('DUP');
  const taux = Math.min(85, 40 + Math.floor(dup * 1.5));
  const roll = Math.floor(Math.random() * 100) + 1;

  if (roll <= taux) {
    const joursRestants = Math.max(1, state.estEmprisonne.jourFin - (state.day || 1));
    const reduction = Math.max(1, Math.ceil(joursRestants / 2));
    state.estEmprisonne.jourFin = Math.max(state.day, state.estEmprisonne.jourFin - reduction);
    state.estEmprisonne.jours = Math.max(0, joursRestants - reduction);
    addMailNotification('Cabinet juridique', 'Réduction obtenue', 'Votre avocat a plaidé un vice de procédure. Votre peine est réduite de ' + reduction + ' jour(s).');

    if (state.estEmprisonne.jours <= 0 || state.day >= state.estEmprisonne.jourFin) {
      state.estEmprisonne = null;
      showToast('Libéré(e) !', 'La réduction de peine vous rend votre liberté.', true, true);
      addJournalEntry('Vous êtes libéré(e) suite à la réduction de peine obtenue par votre avocat.', 'event-good');
    } else {
      showToast('Réduction obtenue !', '-' + reduction + ' jour(s) de détention.', true, true);
      addJournalEntry('Votre avocat obtient une réduction de peine de ' + reduction + ' jour(s). -' + cout.toLocaleString('fr-FR') + ' ' + cur + '.', 'event-good');
    }
  } else {
    addMailNotification('Cabinet juridique', 'Requête rejetée', 'Le juge a rejeté la demande de votre avocat. Aucune réduction de peine.');
    showToast('Requête rejetée', "Le juge n'accorde aucune réduction.", false);
    addJournalEntry('La requête de votre avocat est rejetée. -' + cout.toLocaleString('fr-FR') + ' ' + cur + '.', 'event-bad');
  }
  updateUI();
}

function doGreveFaim() {
  state.hp = Math.max(1, state.hp - 5);
  state.pop = Math.min(100, state.pop + 3);
  updateUI();
  showToast('Greve de la faim', '-5 HP +3 POP. Pression politique sur l\'administration.', false);
  addExternalEvent((state.char?.name||'Un detenu') + ' entame une greve de la faim. Pression politique.');
}

// Actes pouvant faire l'objet d'une decouverte differee (succes non sanctionne sur le moment).
// Vol est volontairement exclu : ses echecs sont deja sanctionnes immediatement (verbalisation/amende sur le champ),
// et ses succes ne sont pas inscrits a l'historique — pas de risque de double sanction.
const ACTES_DECOUVRABLES = ['assassinat', 'empoisonnement', 'achat_arme_illegal', 'acheter_bombe_illegale', 'incendier', 'utiliser_explosifs', 'hooliganisme', 'corruption_fonctionnaire'];

function verifierDecouverteCrimesPasses() {
  if (!state.historiqueCrimes || state.historiqueCrimes.length === 0) return;
  const candidats = state.historiqueCrimes.filter(c =>
    ACTES_DECOUVRABLES.includes(c.acte) && c.expireJour > state.day
  );
  if (candidats.length === 0) return;

  for (const c of candidats) {
    const tauxDecouverte = ACTES_ILLEGAUX[c.acte]?.detectRate || 25;
    const roll = Math.floor(Math.random() * 100) + 1;
    if (roll <= tauxDecouverte) {
      // Retirer l'entree decouverte de l'historique
      state.historiqueCrimes = state.historiqueCrimes.filter(x => x !== c);
      addMailNotification('Brigade Criminelle', 'Affaire résolue', 'Une enquête a permis de vous identifier comme responsable de : ' + (getPeineParActe(c.acte, true).label) + '. Vous êtes arrêté(e).');
      procederArrestation(c.acte, false, true); // demasque = true -> peine doublee
      break; // Une seule arrestation a la fois, le reste sera reexamine au prochain cycle
    }
  }
}

// Une tentative d'evasion par jour maximum (bug de spam remonte le 4 aout 2026 : les PA
// illimites de la phase de test permettaient de retenter indefiniment). Taux de base 10%,
// modifie par DUP et l'indice de securite du pays — meme formule que le vol/cambriolage.
async function doTentativeEvasion(pa, cost) {
  if (!state.estEmprisonne) {
    showToast('Non emprisonne', 'Vous devez etre emprisonne pour tenter de vous evader.', false);
    return;
  }

  const jourActuel = state.day || 1;
  if (state.estEmprisonne.dernierJourEvasion === jourActuel) {
    showToast('Trop tôt', 'Une seule tentative d\'évasion par jour.', false);
    return;
  }
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }
  state.estEmprisonne.dernierJourEvasion = jourActuel;

  const pays = state.country;
  const dup = getStatEffective('DUP');
  const ville = state.currentCity || 'capitale';
  const isn = (typeof getIndiceVille === 'function') ? getIndiceVille(pays, ville, 'isn') : ((typeof INDICES_NATIONAUX !== 'undefined' && INDICES_NATIONAUX[pays]?.ISN) || 30);
  let taux = 10 + (dup - 10) * 2 - (isn - 45) / 3;
  taux = (typeof consommerBonusBenediction === 'function') ? consommerBonusBenediction(taux) : taux;
  taux = Math.max(2, Math.min(40, Math.round(taux)));

  const roll = Math.floor(Math.random() * 100) + 1;
  if (roll <= taux) {
    state.estEmprisonne = null;
    state.recherche = [];
    showToast('Evasion reussie !', 'Vous etes libre ! Restez discret.', true, true);
    addJournalEntry('Evasion reussie !', 'event-good');
  } else {
    const cur = COUNTRIES[state.country]?.cur || 'FR';
    if (state.estEmprisonne) {
      state.estEmprisonne.jours += 1;
      state.estEmprisonne.jourFin += 1;
    }
    state.arg = Math.max(0, (state.arg || 0) - 500);
    updateUI();
    showToast('Evasion echouee', 'Tentative echouee. +1 jour de detention, -500 ' + cur + '.', false);
    addJournalEntry('Tentative d\'evasion echouee. Peine aggravee de 1 jour, amende de 500 ' + cur + '.', 'event-bad');
  }
}

async function doSeRebeller(pa, cost) {
  if (!state.estEmprisonne) {
    showToast('Non emprisonne', 'Vous devez etre emprisonne pour vous rebeller.', false);
    return;
  }
  const rDeduc = await deduireCoutOrdre({ pa, cost });
  if (!rDeduc.ok) { showToast('PA insuffisants', '', false); return; }

  const pays = state.country;
  const ville = state.currentCity;
  const cur = COUNTRIES[pays]?.cur || 'FR';

  // FOR fantome corrige (bêta) : le joueur n'a jamais eu de caracteristique FOR (toujours
  // undefined, repli fixe a 8) -- VOL est deja la caracteristique de confrontation physique du
  // joueur ailleurs dans le code (tenterResistance, assassinat mains nues). codetenu.stats.FOR
  // reste inchange : un PNJ employe, avec sa propre FOR reelle (PNJ_STATS_PAR_JOB, data.js).
  const volBase = getStatEffective('VOL');
  const codetenu = (state.employes || []).find(e => e.job === 'codetenu');
  const bonusCodetenu = codetenu?.stats?.FOR ? Math.floor(codetenu.stats.FOR / 2) : 0;
  const taux = Math.min(60, volBase * 3 + bonusCodetenu);
  const roll = Math.floor(Math.random() * 100) + 1;

  const degats = Math.floor(Math.random() * 7) + 4;
  if (typeof endommagerGrillePrison === 'function') await endommagerGrillePrison(pays, ville, degats).catch(() => {});

  if (roll <= taux) {
    state.dis = Math.min(100, (state.dis || 0) + 6);
    if (typeof INDICES_NATIONAUX !== 'undefined' && INDICES_NATIONAUX[pays]) {
      INDICES_NATIONAUX[pays].POP = Math.max(0, (INDICES_NATIONAUX[pays].POP || 50) - 2);
    }
    state.hp = Math.max(1, (state.hp || 100) - 10);
    if (state.estEmprisonne) {
      state.estEmprisonne.jours += 1;
      state.estEmprisonne.jourFin += 1;
    }
    updateUI();
    showToast('Rebellion !', 'Vous avez tenu tete aux gardiens. +6 DIS, mais +1 jour de detention et -10 PV.', true, true);
    addJournalEntry('Rebellion en cellule reussie. Grilles endommagees (-' + degats + '). +1 jour de peine, -10 PV.', 'event-info');
    if (typeof tracerActionPourRumeur === 'function') tracerActionPourRumeur('rebellion_cellule', ville);
  } else {
    state.hp = Math.max(1, (state.hp || 100) - 25);
    state.dis = Math.max(0, (state.dis || 0) - 15);
    state.estEmprisonne = null;
    if (typeof sbCreerPrisonnierQHS === 'function') {
      await sbCreerPrisonnierQHS({ pays, nom: state.char?.name, raison: 'Rebellion en cellule', photoUrl: state.char?.photoUrl || null, jourDebut: state.day, jourFin: (state.day || 1) + 30 }).catch(() => {});
    }
    if (typeof sbUpdate === 'function') {
      await sbUpdate('personnages', `name=eq.${encodeURIComponent(state.char?.name)}`, { detention_qhs: JSON.stringify({ enQHS: true, paLimite1Jour: false }) }).catch(() => {});
    }
    updateUI();
    showToast('Rebellion matee', 'Transfere au QHS. -25 PV, -15 DIS.', false);
    addJournalEntry('Rebellion en cellule matee par les gardiens. Transfert au QHS. Grilles endommagees (-' + degats + ').', 'event-bad');
  }
}

async function ouvrirVisiterPrisonnier(pa, cost) {
  const pays = state.country || 'republic';
  document.getElementById('postes-modal-title').textContent = 'Visiter un détenu';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a8060;font-style:italic">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const prisonniers = await sbGetPrisonniersQHS(pays).catch(() => []);
  let html = '<div style="padding:1rem">';
  if (prisonniers.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucun détenu au QHS actuellement.</div>';
  } else {
    html += '<div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Choisir un détenu à visiter :</div>';
    prisonniers.forEach(p => {
      html += '<div onclick="confirmerVisitePrisonnier(\'' + p.id + '\',' + pa + ',' + cost + ')" style="display:flex;align-items:center;gap:.6rem;border:1px solid #2a2010;background:#0f0d05;padding:.5rem .7rem;margin-bottom:.4rem;cursor:pointer">';
      html += p.photoUrl ? '<img src="' + p.photoUrl + '" style="width:36px;height:36px;border-radius:50%;object-fit:cover;border:1px solid #4a3a1a"/>' : '<div style="width:36px;height:36px;border-radius:50%;background:#1a1610;display:flex;align-items:center;justify-content:center"><i class="ti ti-user" style="color:#5a5040"></i></div>';
      html += '<div><div style="font-size:.85rem;color:#e0d5b8">' + p.nom + '</div><div style="font-size:.7rem;color:#a89870">' + p.raison + '</div></div>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function confirmerVisitePrisonnier(prisonnierId, pa, cost) {
  const rows = await sbGet('prisonniers_qhs', `id=eq.${encodeURIComponent(prisonnierId)}`).catch(() => []);
  const row = rows?.[0];
  if (!row || row.statut !== 'detenu') { showToast('Détenu introuvable', 'Ce détenu n\'est plus détenu au QHS.', false); return; }
  const p = row.data;
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }
  document.getElementById('modal-postes').classList.remove('open');
  showToast('Visite effectuée', 'Vous avez rendu visite à ' + p.nom + ' au QHS.', true, true);
  addJournalEntry('Visite à ' + p.nom + ' au QHS.', 'event-info');
}

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

async function alimenterBudgets() {
  // Appele a minuit - distribue les recettes fiscales
  const pays = state.country || 'republic';
  const pop = CITY_POPULATION?.[pays];
  if (!pop) return;
  let recettesTotales = 0;
  Object.values(pop).forEach(ville => {
    recettesTotales += ville.dailyTaxRevenue || 0;
  });

  const budgetNat = typeof chargerBudgetNational === 'function' ? await chargerBudgetNational(pays) : null;
  const rep = budgetNat?.repartition || REPARTITION_DEFAULT;
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

async function doCampagneSecurite() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cost = 500;
  // Arbitrage de conception (correctif Lot 2C) : payeur exclusif = budget institutionnel de la
  // mairie (state.budgets.mairie via getBudgetInstitution), jamais l'argent personnel du joueur.
  // Debit du cout REEL de cet ordre (500 FR) -- pas le cout generique de
  // verifierBudgetInstitution (b.coutOrdre = 250 FR pour la mairie) : les deux ne se cumulent
  // plus, un seul debit de 500 FR sur le budget mairie. Verification AVANT toute deduction PA :
  // si le budget est insuffisant, ni PA ni FR ne sont debites.
  const budgetMairie = getBudgetInstitution('mairie');
  if (budgetMairie.solde < cost) {
    showToast('Budget insuffisant', 'Le budget de la mairie (' + cost + ' ' + cur + ' requis) est insuffisant. Le Ministre des Finances doit revoir la répartition budgétaire.', false);
    return;
  }
  // Deduction PA centralisee (Lot 2C) -- apres verification du budget mairie, avant toute mutation.
  const rPa = await deduireCoutOrdre({ pa: 2, cost: 0 });
  if (!rPa.ok) { showToast('PA insuffisants', '2 PA requis.', false); return; }
  budgetMairie.solde -= cost;
  const pays = state.country || 'republic';
  if (INDICES_NATIONAUX?.[pays]) INDICES_NATIONAUX[pays].ISN = Math.min(100, INDICES_NATIONAUX[pays].ISN + 10);
  state.pop = Math.max(0, state.pop - 3);
  updateUI();
  showToast('Campagne de sécurité', '+10 ISN local. -3 POP. ' + cost + ' ' + cur + ' prélevés sur le budget de la mairie.', false);
  addExternalEvent('MAIRIE : Campagne de sécurité lancée par le Maire. +10 ISN.');
}

function ouvrirActeOfficielMairie(pa, cost) {
  document.getElementById('postes-modal-title').textContent = 'Délivrer un acte officiel';
  let html = '<div style="padding:1rem"><div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Choisir l\'acte à délivrer :</div>';
  ACTES_OFFICIELS.forEach(acte => {
    html += '<div onclick="delivrerActe(\'' + acte.id + '\',' + pa + ',' + cost + ')" style="padding:.6rem .8rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;cursor:pointer" onmouseover="this.style.background=\'#151005\'" onmouseout="this.style.background=\'#0f0d05\'">';
    html += '<div style="font-size:.82rem;color:#c0b090">' + acte.name + '</div>';
    html += '<div style="font-size:.68rem;color:#5a4030">' + acte.desc + '</div>';
    html += '</div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function delivrerActe(acteId, pa, cost) {
  document.getElementById('modal-postes').classList.remove('open');
  const acte = ACTES_OFFICIELS.find(a => a.id === acteId);
  if (!acte) return;
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }
  if (!state.inventory) state.inventory = [];
  // Supprimer l'ancien acte du meme type si existant
  state.inventory = state.inventory.filter(i => i.acteId !== acteId);
  state.inventory.push({ type:'acte_officiel', name:acte.name, icon:'ti-file-certificate', legal:true, acteId, desc:acte.desc });
  updateUI();
  showToast('Acte délivré', acte.name + ' ajouté à votre inventaire.', true, true);
  addJournalEntry('Acte officiel délivré : ' + acte.name, 'event-info');
}

function ouvrirContesterResultats(pa, cost) {
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
      html += '<button onclick="soumettreConte(' + i + ',' + pa + ',' + cost + ')" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;padding:.3rem .7rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Contester</button>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function soumettreConte(idx, pa, cost) {
  const e = (state.electionsEnCours||[]).filter(el => el.phase === 'termine')[idx];
  const motif = document.getElementById('motif-contestation-' + idx)?.value?.trim();
  if (!motif) { showToast('Motif requis', '', false); return; }
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }
  document.getElementById('modal-postes').classList.remove('open');
  const ville = WORLD[state.country]?.[state.currentCity]?.name || 'la ville';
  const forumKey = 'tribunal_' + state.currentCity;
  if (!FORUM_TOPICS[forumKey]) FORUM_TOPICS[forumKey] = [];
  const timeContestation = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : 'Jour ' + state.day;
  FORUM_TOPICS[forumKey].unshift({
    id: 'contestation-' + Date.now(),
    title: '[CONTESTATION] ' + e.nom,
    author: state.char?.name || 'Anonyme',
    time: timeContestation,
    posts: [{ author: state.char?.name, time: timeContestation, content: 'RECOURS ELECTORAL\n\nElection contestée : ' + e.nom + '\nMotif : ' + motif + '\n\nLe juge est prié de statuer dans les 48 heures.' }]
  });
  showToast('Recours déposé', 'Contestation publiée dans le forum du Tribunal de ' + ville + '. Décision dans 48h.', true);
  addJournalEntry('Contestation électorale déposée : ' + e.nom, 'event-info');
  addExternalEvent('ELECTORAL : ' + (state.char?.name||'Anonyme') + ' conteste les résultats de l\'élection : ' + e.nom);
}

// doControlDouanes() : doublon exact retiré (bêta) -- la seule définition vivante (identique
// avant retrait, vérifiée par diff) reste dans plateau-navigation.js, déjà corrigée pour le
// même correctif DIS fantôme. Deux définitions du même nom en scope global classique : la
// seconde chargée écrasait silencieusement la première, aucun comportement perdu ici.
//
// doCorrompreDoanier() : MEME defaut retire ici le 25 aout 2026 (audit dedie, lot douanes PSM).
// Cette copie ne posait jamais state.douanePassee=true en cas de succes -- la version de
// plateau-navigation.js avait deja ete corrigee le 24 aout pour reparer exactement ce
// cul-de-sac (paiement de 300 FR sans deblocage reel de la zone d'embarquement), mais chargee
// AVANT ce fichier, elle etait silencieusement ecrasee par cette version obsolete au
// chargement du jeu. Seule definition vivante desormais : plateau-navigation.js.

// Decision de game design (avant Phase L) : le trajet en taxi lui-meme est desormais ouvert a
// TOUT PJ, sans condition de poste ni de laissez-passer -- la Caserne et le QHS ont tous deux
// une salle d'entree publique (corps_garde / entree_qhs), donc le taxi ne peut pas etre plus
// restrictif que la destination qu'il dessert. D'eventuelles restrictions (salles internes,
// ordres precis) seront traitees separement, au niveau de la salle/de l'ordre, jamais au niveau
// du trajet. Corrige un ancien bloc d'acces (ACCES_CASERNE/ACCES_QHS) qui, avant meme cette
// decision, etait de toute facon casse : ces deux constantes n'avaient jamais ete declarees
// nulle part dans le depot et faisaient planter systematiquement doTaxiSpecial des le premier
// appel, pour taxi_caserne ET taxi_qhs (bug preexistant, sans rapport avec la migration Phase K).
async function doTaxiSpecial(destination, pa, cost) {
  const label = destination === 'caserne' ? 'la Caserne' : 'le QHS';
  const cityKey = destination === 'caserne' ? 'caserne' : 'qhs';

  // Voyage OK
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('Fonds insuffisants', '', false); return; }
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  state.currentCity = cityKey;
  state.currentBuilding = null;
  state.currentRoom = null;
  if (state.char) {
    state.char.currentCity = cityKey;
    state.char.currentBuilding = null;
    state.char.currentRoom = null;
    try {
      localStorage.setItem('respublica_char_' + (state.char?.name || 'default'), JSON.stringify(state.char));
    } catch (e) {
      console.warn('Cache local personnage non sauvegarde (quota depasse) :', e);
    }
  }
  buildCityTabs();
  updateUI();
  forceRenderCity(cityKey);
  showToast('En route !', 'Vous arrivez à ' + label + '. -' + cost + ' ' + cur, true);
  addJournalEntry('Taxi vers ' + label, 'event-info');
}

function ouvrirFalsifierDocument(pa, cost) {
  document.getElementById('postes-modal-title').textContent = 'Falsifier un document';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#cc4444;font-style:italic;margin-bottom:.8rem">Acte illegal. Taux 45%. Echec : alerte possible. Document ajoute a votre inventaire si succes.</div>';
  DOCUMENTS_FALSIFIABLES.forEach(doc => {
    html += '<div onclick="confirmerFalsification(\'' + doc.id + '\',' + pa + ',' + cost + ')" style="padding:.6rem .8rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;cursor:pointer;transition:background .15s" onmouseover="this.style.background=\'#151005\'" onmouseout="this.style.background=\'#0f0d05\'">';
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

// Cout conditionnel (Phase K), meme logique que doCorrompreDoanier/doFalsifierManifeste : PA du
// des la tentative, FR uniquement en cas de reussite.
async function confirmerFalsification(docId, pa, cost) {
  document.getElementById('modal-postes').classList.remove('open');
  const doc = DOCUMENTS_FALSIFIABLES.find(d => d.id === docId);
  if (!doc) return;

  const rPa = await deduireCoutOrdre({ pa, cost: 0 });
  if (!rPa.ok) { showToast('PA insuffisants', '', false); return; }

  const roll = Math.floor(Math.random() * 100) + 1;
  const taux = Math.max(5, 45 - getMalusISN());

  if (roll <= taux) {
    const rCost = await deduireCoutOrdre({ pa: 0, cost });
    if (!rCost.ok) { showToast('Fonds insuffisants', '', false); return; }
    if (!state.inventory) state.inventory = [];
    state.inventory.push({
      type: 'document_falsifie',
      name: doc.name,
      icon: doc.icon,
      docId: doc.id,
      legal: false,
      desc: doc.desc
    });
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

async function ouvrirRendreSentence(pa, cost) {
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
      if (a.circonstanceAttenuante) {
        html += '<div style="font-size:.7rem;color:#6a9a6a;margin-bottom:.4rem;font-style:italic">✓ Défense réussie : circonstance atténuante (-1 jour si prison)</div>';
      }
      if (a.aggravation) {
        html += '<div style="font-size:.7rem;color:#cc4444;margin-bottom:.4rem;font-style:italic">⚠ Défense ratée de façon flagrante : aggravation (+2 jours si prison)</div>';
      }
      html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.68rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.4rem">SENTENCE</div>';
      html += '<div style="display:flex;flex-direction:column;gap:.3rem">';
      html += '<button onclick="appliquerSentence(&quot;' + a.id + '&quot;,\'amende\',' + pa + ',' + cost + ')" style="text-align:left;padding:.4rem .7rem;border:1px solid #2a4a20;background:#0a0d05;color:#6a9a6a;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem">Amende (montant + repartition)</button>';
      html += '<button onclick="appliquerSentence(&quot;' + a.id + '&quot;,\'prison\',' + pa + ',' + cost + ')" style="text-align:left;padding:.4rem .7rem;border:1px solid #3a2a10;background:#0a0d05;color:#9a8a4a;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem">Prison (max 7 jours)</button>';
      html += '<button onclick="appliquerSentence(&quot;' + a.id + '&quot;,\'amenagement\',' + pa + ',' + cost + ')" style="text-align:left;padding:.4rem .7rem;border:1px solid #2a3a4a;background:#0a0d05;color:#6a8aaa;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem">Amenagement de peine (pointage commissariat)</button>';
      html += '<button onclick="appliquerSentence(&quot;' + a.id + '&quot;,\'qhs\',' + pa + ',' + cost + ')" style="text-align:left;padding:.4rem .7rem;border:1px solid #4a1a10;background:#0a0d05;color:#9a4a3a;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem">Envoi au QHS</button>';
      if ((a.motif || '').toLowerCase().includes('tortur')) {
        html += '<button onclick="appliquerSentence(&quot;' + a.id + '&quot;,\'torture\',' + pa + ',' + cost + ')" style="text-align:left;padding:.4rem .7rem;border:1px solid #6a1010;background:#150505;color:#cc4444;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem">⚖ Sanction torture (prison + popularité à zéro, cumulable)</button>';
      }
      html += '</div></div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function appliquerSentence(affaireId, type, pa, cost) {
  const affaire = (state.plaintesEnCours||[]).find(p => p.id === affaireId);
  if (!affaire) return;
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }
  affaire.status = 'jugee';
  if (typeof sbSavePlainte === 'function') sbSavePlainte(affaire).catch(() => {});

  const cur = COUNTRIES[state.country]?.cur || 'FR';
  let details = '';

  if (type === 'amende') {
    const montant = 500;
    details = 'Amende de ' + montant + ' ' + cur;
  } else if (type === 'prison') {
    let duree = 3;
    let note = '';
    if (affaire.circonstanceAttenuante) { duree = Math.max(1, duree - 1); note = ' (circonstance atténuante : -1 jour)'; }
    if (affaire.aggravation) { duree = duree + 2; note = ' (aggravation : +2 jours)'; }
    details = 'Prison ' + duree + ' jours' + note;
    await enregistrerDetention(affaire.cible, affaire.motif, state.day + duree, undefined, affaire.city);
  } else if (type === 'amenagement') {
    details = 'Amenagement : pointage quotidien au commissariat';
  } else if (type === 'qhs') {
    details = 'Envoi au QHS';
    await enregistrerDetention(affaire.cible, affaire.motif, state.day + 30, true, affaire.city);
    if (typeof sbCreerPrisonnierQHS === 'function') {
      let photoUrl = null;
      if (typeof sbGet === 'function') {
        const rows = await sbGet('personnages', `name=eq.${encodeURIComponent(affaire.cible)}&select=photoUrl`).catch(() => []);
        photoUrl = rows?.[0]?.photoUrl || null;
      }
      await sbCreerPrisonnierQHS({ pays: state.country || 'republic', nom: affaire.cible, raison: affaire.motif, photoUrl, jourDebut: state.day, jourFin: state.day + 30 }).catch(() => {});
      if (typeof sbUpdate === 'function') await sbUpdate('personnages', `name=eq.${encodeURIComponent(affaire.cible)}`, { detention_qhs: JSON.stringify({ enQHS: true, paLimite1Jour: false }) }).catch(() => {});
    }
  } else if (type === 'torture') {
    // Cumul : compter les condamnations precedentes pour torture sur ce meme accuse
    // (enregistrees comme actions tracees "condamnation_torture", jour_expiration tres eloigne
    // pour qu'elles restent comptabilisables indefiniment).
    let nbPrecedentes = 0;
    if (typeof sbGetActionsTracablesParAuteur === 'function') {
      const precedentes = await sbGetActionsTracablesParAuteur(state.country, affaire.cible, 'condamnation_torture', state.day || 1).catch(() => []);
      nbPrecedentes = precedentes?.length || 0;
    }
    const duree = 3 * (nbPrecedentes + 1);
    details = 'Prison ' + duree + ' jours + popularité à zéro' + (nbPrecedentes > 0 ? ' (peine cumulée, ' + (nbPrecedentes + 1) + 'e condamnation)' : '');
    await enregistrerDetention(affaire.cible, affaire.motif, state.day + duree, undefined, affaire.city);
    // Perte totale de popularite appliquee directement au personnage reel (peut ne pas etre
    // le joueur actuellement connecte).
    if (typeof sbUpdate === 'function') {
      await sbUpdate('personnages', `name=eq.${encodeURIComponent(affaire.cible)}`, { pop: 0 }).catch(() => {});
    }
    // Enregistrer cette condamnation pour permettre le cumul des peines a l'avenir
    if (typeof sbTracerAction === 'function') {
      await sbTracerAction({
        id: 'condamnation-' + Date.now() + '-' + Math.floor(Math.random() * 1000),
        auteur: affaire.cible, cible: null, type_action: 'condamnation_torture',
        country: state.country, city: affaire.city || state.currentCity || 'capitale',
        jour: state.day || 1, jour_expiration: (state.day || 1) + 36500
      }).catch(() => {});
    }
  }

  if (!state.archivesJugements) state.archivesJugements = [];
  const nouveauJugement = {
    accuse: affaire.cible,
    motif: affaire.motif,
    peine: details,
    juge: state.char?.name || 'PNJ',
    jour: state.day,
    executee: false
  };
  state.archivesJugements.push(nouveauJugement);
  if (typeof sbCreerJugement === 'function') {
    await sbCreerJugement({
      country: state.country || 'republic',
      city: affaire.city || state.currentCity || 'capitale',
      accuse: nouveauJugement.accuse,
      motif: nouveauJugement.motif,
      peine: nouveauJugement.peine,
      juge: nouveauJugement.juge,
      jour: nouveauJugement.jour,
      executee: nouveauJugement.executee
    }).catch(() => {});
  }

  if (typeof sbSavePlainte === 'function') await sbSavePlainte(affaire).catch(() => {});

  document.getElementById('modal-postes').classList.remove('open');
  showToast('Sentence rendue', affaire.cible + ' : ' + details, true, true);
  addExternalEvent('JUGEMENT : ' + affaire.cible + ' condamne(e) a : ' + details + ' (Juge : ' + (state.char?.name||'PNJ') + ')');
  if (typeof sbSendMail === 'function') {
    const h = String(state.hour || 8).padStart(2,'0');
    const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : 'Jour ' + (state.day || 1) + ' · ' + h + 'h';
    sbSendMail('Tribunal', affaire.cible, 'Resultat de votre affaire', 'La sentence a ete rendue : ' + details, time).catch(() => {});
  }
}

function getLocationsActives() {
  if (!state.locationsActives) state.locationsActives = [];
  return state.locationsActives;
}

// Scope ajoute le 2026-08-16 (bug multi-ville : 'centre-affaires' etc. sont partages par
// plusieurs villes du meme pays). city = ville a verifier, par defaut la ville courante du
// joueur (tous les appelants existants operent deja sur state.currentBuilding/currentRoom,
// donc sur la ville ou se trouve le joueur). Les 7 locations persistees avant ce correctif
// ont ete migrees individuellement vers la cle buildingId:roomId:city (ville identifiee avec
// certitude via historique_deplacements/elimination structurelle, validee manuellement) --
// plus aucune location sans city en base, le repli de compatibilite est donc retire.
function getLocationPourRoom(buildingId, roomId, city = state.currentCity) {
  return getLocationsActives().find(l =>
    l.buildingId === buildingId && l.roomId === roomId && l.city === city
  );
}

// Charge toutes les locations actives depuis Supabase au demarrage (remplace l'ancien
// state.locationsActives purement local, perdu au rafraichissement).
async function chargerLocations() {
  if (typeof sbLoadLocations !== 'function') return;
  try {
    const locations = await sbLoadLocations(state.country);
    state.locationsActives = locations;
  } catch (e) { console.warn('chargerLocations error', e); }
}

function ouvrirModalLouerLocal(pa, cost) {
  const buildingId = state.currentBuilding;
  const roomId = state.currentRoom;
  if (!buildingId || !roomId) return;

  const room = BUILDINGS[buildingId]?.rooms?.[roomId];
  if (!room?.locationData) { showToast('Erreur', 'Local non trouvé.', false); return; }
  // roomOverride.desc a priorite sur room.desc si un override existe pour cette room precise
  // (meme priorite generique que dans enterRoom, plateau-navigation.js).
  const descAffichee = (typeof getBuildingContext === 'function' ? getBuildingContext(buildingId)?.roomOverrides?.[roomId]?.desc : null) || room.desc;

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

  let orgaSelect = '<div style="font-size:.72rem;color:#9a8a68;font-style:italic">Aucune organisation — fondez-en une pour bénéficier des bonus.</div>';
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
    '<div style="font-size:.78rem;color:#a09060;font-style:italic;margin-bottom:.7rem;border-left:2px solid #3a2a10;padding-left:.6rem">' + (descAffichee || '') + '</div>' +
    '<div style="display:grid;grid-template-columns:1fr 1fr;gap:.4rem;margin-bottom:.7rem">' +
      '<div style="background:#0a0805;border:1px solid #1a1810;padding:.5rem;text-align:center">' +
        '<div style="font-size:.82rem;color:#9a8a68">LOYER / JOUR</div>' +
        '<div style="font-family:Bebas Neue,sans-serif;font-size:1.1rem;color:#C9A84C">' + loc.prix.toLocaleString('fr-FR') + ' ' + cur + '</div>' +
      '</div>' +
      '<div style="background:#0a0805;border:1px solid #1a1810;padding:.5rem;text-align:center">' +
        '<div style="font-size:.82rem;color:#9a8a68">BONUS ORGANISATION</div>' +
        '<div style="font-size:.78rem;color:#4a8a4a;margin-top:.2rem">' + bonusStr + '</div>' +
      '</div>' +
    '</div>' +
    orgaSelect +
    '<div style="font-size:.7rem;color:#6a5a30;margin-bottom:.7rem">Le premier loyer est prélevé immédiatement. Ensuite, chaque réveil.</div>' +
    '<button onclick="confirmerLocation(' + pa + ',' + cost + ')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">🔑 Signer le bail</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerLocation(pa, cost) {
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
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }

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
    // Ajoute le 2026-08-16 : un batiment generique (ex. 'centre-affaires') est partage par
    // plusieurs villes du meme pays. Sans cette dimension, une location a Montrouge occupait
    // le meme local qu'a Luthecia/PSM. Les anciennes locations persistees (sans city) restent
    // gerees par un repli de compatibilite dans getLocationPourRoom -- voir ce commentaire la.
    city: state.currentCity,
    depuis: state.day || 1,
    visible: true
  });
  if (typeof sbSaveLocation === 'function') {
    sbSaveLocation(state.locationsActives[state.locationsActives.length - 1]).catch(() => {});
  }

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

function ouvrirModalChoixSuite() {
  const buildingId = state.currentBuilding;
  const b = BUILDINGS[buildingId];
  if (!b) return;
  const ctxSuites = typeof getBuildingContext === 'function' ? getBuildingContext(buildingId) : null;

  const suites = Object.entries(b.rooms || {}).filter(([, r]) => r.isLocationRoom && r.locationData?.suiteChoice);
  if (suites.length === 0) { showToast('Aucune suite', 'Aucune suite disponible ici.', false); return; }

  const cur = COUNTRIES[state.country]?.cur || 'FR';

  document.getElementById('postes-modal-title').textContent = '👑 Louer une suite';
  let html = '<div style="padding:.8rem 1rem">';
  suites.forEach(([roomId, room]) => {
    const loc = room.locationData;
    const dejaLoue = getLocationPourRoom(buildingId, roomId);
    const bonusParts = [];
    if (loc.bonusPOP > 0) bonusParts.push('+' + loc.bonusPOP + ' POP');
    if (loc.bonusINF > 0) bonusParts.push('+' + loc.bonusINF + ' INF');
    if (loc.bonusDIS > 0) bonusParts.push('+' + loc.bonusDIS + ' DIS');

    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.6rem;margin-bottom:.5rem">';
    // roomOverride.desc a priorite sur room.desc si un override existe pour cette room precise.
    const descSuite = ctxSuites?.roomOverrides?.[roomId]?.desc || room.desc;
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.9rem;color:#C9A84C">' + loc.label + '</div>';
    html += '<div style="font-size:.75rem;color:#a09060;margin:.2rem 0">' + (descSuite || '') + '</div>';
    html += '<div style="font-size:.78rem;color:#9a8a68">' + loc.prix.toLocaleString('fr-FR') + ' ' + cur + '/jour \u00b7 ' + (bonusParts.join(' \u00b7 ') || 'Aucun bonus') + '</div>';
    if (dejaLoue) {
      html += '<div style="font-size:.72rem;color:#8a6a20;margin-top:.4rem">D\u00e9j\u00e0 lou\u00e9e' + (dejaLoue.locataire === state.char?.name ? ' (par vous)' : '') + '.</div>';
    } else {
      html += '<button onclick="entrerEtLouerSuite(\'' + buildingId + '\',\'' + roomId + '\')" style="margin-top:.4rem;width:100%;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">\ud83d\udd11 Louer cette suite</button>';
    }
    html += '</div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function entrerEtLouerSuite(buildingId, roomId) {
  document.getElementById('modal-postes').classList.remove('open');
  enterRoom(buildingId, roomId, null);
  ouvrirModalLouerLocal();
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

  // orgaAutorisee (18 aout 2026, logements sociaux de Montrouge) : lu directement sur la
  // definition statique de la room (source de verite unique), jamais copie sur l'entree
  // dynamique de state.locationsActives -- fonctionne donc identiquement pour une location
  // auto-signee (confirmerLocation) ou attribuee par un tiers (attribuerLogementSocial).
  // Absent (toutes les locations commerciales existantes) => comportement inchange.
  const roomOrgaCheck = BUILDINGS[buildingId]?.rooms?.[roomId];
  const orgaAutorisee = roomOrgaCheck?.locationData?.orgaAutorisee !== false;

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
        '<div style="font-size:.82rem;color:#9a8a68">LOYER / JOUR</div>' +
        '<div style="font-family:Bebas Neue,sans-serif;font-size:1rem;color:#C9A84C">' + location.prix.toLocaleString('fr-FR') + ' ' + cur + '</div>' +
      '</div>' +
      '<div style="background:#0a0805;border:1px solid #1a1810;padding:.5rem;text-align:center">' +
        '<div style="font-size:.82rem;color:#9a8a68">BONUS ACTIFS</div>' +
        '<div style="font-size:.72rem;color:#4a8a4a;margin-top:.2rem">' + (bonusParts.join(' · ') || 'Aucun') + '</div>' +
      '</div>' +
    '</div>' +
    '<div style="font-size:.72rem;color:#6a5a30;margin-bottom:.4rem">Loué · ' + (location.batimentLabel || '') + '</div>' +
    '<div style="font-size:.72rem;color:' + (orgaActuelle ? '#4a8a4a' : '#6a5a30') + ';margin-bottom:.5rem">Organisation : ' + (orgaActuelle ? orgaActuelle.nom : 'Aucune') + '</div>' +
    orgaSelect +
    (orgaAutorisee ?
    '<div style="margin-bottom:.6rem">' +
      '<button onclick="ouvrirCreerOrga()" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.4rem;border:1px solid #4a6a4a;background:transparent;color:#6a9a6a;cursor:pointer"><i class=\"ti ti-building\" style=\"font-size:.8rem\"></i> Créer une organisation ici</button>' +
    '</div>' : '') +
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
  const ville = state.currentCity;
  const idx = (state.locationsActives || []).findIndex(l =>
    l.buildingId === buildingId && l.roomId === roomId && l.city === ville
  );
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
  // Correctif (18 aout 2026) : la resiliation ne supprimait jusqu'ici que l'entree locale --
  // la ligne correspondante de la table Supabase dediee "locations_actives" restait en base,
  // et pouvait donc reapparaitre pour d'autres joueurs (ou apres reconnexion) via
  // chargerLocations(). sbSupprimerLocation() existait deja (introduite pour la resiliation
  // automatique des logements sociaux) mais n'etait jusque-la jamais appelee ici.
  if (typeof sbSupprimerLocation === 'function') {
    sbSupprimerLocation(location.buildingId, location.roomId, location.city).catch(() => {});
  }
  document.getElementById('modal-postes').classList.remove('open');
  showToast('Bail résilié', location.localLabel + ' libéré.', false);
  addJournalEntry('Bail résilié : ' + location.localLabel + '.', 'event-info');
  if (state.currentRoom) enterRoom(state.currentBuilding, state.currentRoom, null);
}

function payerLocations() {
  const locations = state.locationsActives || [];
  if (locations.length === 0) return;

  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const pays = state.country || 'republic';
  const aTraiter = []; // { i, action: 'expulse' | 'legacyEntrepot' }

  locations.forEach((loc, i) => {
    if (loc.locataire !== state.char?.name) return; // Pas notre location
    // Chambres de la clinique privee (lot chambres, 20 aout 2026) : attribution medicale, pas une
    // location payante -- prix:0 est deja conserve pour la compatibilite du schema, mais on
    // l'exclut ici explicitement pour ne produire ni prelevement, ni message de loyer, ni
    // avertissement, ni resiliation. Ne concerne aucune autre location (logements sociaux,
    // appartements, locaux commerciaux...).
    if (loc.chambreClinique === true) return;

    // Box portuaire (lot du 25 aout 2026, §13-14) : l'ancien bail EXCLUSIF de l'entrepot
    // (isLocationRoom/locationData retires de data.js) est remplace par des box individuels
    // (isBox:true, voir ouvrirModalLouerBox plus bas). Toute location HERITEE de l'ancienne room
    // 'entrepot' (roomId LITTERAL, fait historique fige -- jamais ROOM_ID_BOX_PORTUAIRE_NAV, qui
    // peut bouger avec la navigation, voir correctif UX du 25 aout 2026 ci-dessous) mais sans le
    // flag isBox est l'ancien bail : resiliee ici sans frais ni penalite, ses bonus DIS/INF
    // disparaissant avec elle (§14 : "les anciens bonus DIS/INF ... doivent disparaitre") --
    // traitement one-shot, jamais reintroduit puisque plus aucun ordre ne peut recreer ce type
    // de bail.
    if (loc.buildingId === BUILDING_ID_PORT && loc.roomId === 'entrepot' && !loc.isBox) {
      aTraiter.push({ i, action: 'legacyEntrepot' });
      return;
    }

    if (state.arg >= loc.prix) {
      state.arg -= loc.prix;
      addJournalEntry('Loyer payé : ' + loc.localLabel + ' -' + loc.prix + ' ' + cur, 'event-info');

      // Appliquer les bonus à l'organisation associée
      if (loc.orgaId) {
        appliquerBonusLocation(loc);
      }
      // Box portuaire : le loyer alimente reellement la caisse du port (§14), contrairement aux
      // ~15 autres locations (loyer purement en pure perte, aucune caisse creditee -- confirme
      // par audit avant ce lot, comportement volontairement inchange pour elles).
      if (loc.isBox && typeof crediterCaisseBatiment === 'function') {
        crediterCaisseBatiment(loc.country || pays, loc.buildingId, loc.prix).catch(() => {});
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
        aTraiter.push({ i, action: 'expulse' });
      }
    }
  });

  // Traiter en ordre d'index decroissant (insensible a l'ordre de collecte des deux types).
  aTraiter.sort((a, b) => b.i - a.i).forEach(({ i, action }) => {
    if (action === 'legacyEntrepot') {
      const loc = state.locationsActives[i];
      state.locationsActives.splice(i, 1);
      if (typeof sbSupprimerLocation === 'function') sbSupprimerLocation(loc.buildingId, loc.roomId, loc.city).catch(() => {});
      addMailNotification('Administration Portuaire', 'Entrepôt reconverti',
        'L\'entrepôt portuaire a été réorganisé en box individuels. Votre ancien bail (' + (loc.localLabel || 'Entrepôt Portuaire') + ') est résilié sans frais, avec ses bonus associés ; un service de box est désormais disponible sur place.');
      addJournalEntry('Ancien bail de l\'entrepôt résilié sans frais (reconversion en box individuels).', 'event-info');
    } else {
      expulserLocataire(i);
    }
  });
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

function ouvrirMesLocations() {
  const locations = (state.locationsActives || []).filter(l => l.locataire === state.char?.name);
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  document.getElementById('postes-modal-title').textContent = '🏢 Mes Locations';

  if (locations.length === 0) {
    document.getElementById('postes-body').innerHTML =
      '<div style="padding:1rem;font-size:.85rem;color:#9a8a68;font-style:italic">Vous ne louez aucun local actuellement. Rendez-vous dans un Centre Commercial, Artisanal ou d\'Affaires.</div>';
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
          '<div style="font-size:.68rem;color:#6a5a30">' + (loc.batimentLabel || '') + ' · Location en cours</div>' +
        '</div>' +
        '<div style="text-align:right">' +
          '<div style="font-family:Bebas Neue,sans-serif;font-size:.82rem;color:#c0b090">' + loc.prix + ' ' + cur + '/jour</div>' +
          '<div style="font-size:.85rem;color:#4a8a4a">' + (bonusParts.join(' · ') || '') + '</div>' +
        '</div>' +
      '</div>' +
      '<div style="font-size:.68rem;color:' + (orga ? '#4a8a4a' : '#4a4030') + ';margin-bottom:.4rem">Organisation : ' + (orga ? orga.nom : 'Aucune') + '</div>' +
      '<button onclick="confirmerResiliation(' + i + ')" style="font-family:Bebas Neue,sans-serif;font-size:.85rem;padding:.2rem .5rem;border:1px solid #5a2a2a;background:transparent;color:#8a3a2a;cursor:pointer">Résilier</button>' +
      '</div>';
  }).join('');

  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.6rem 1rem">' +
    '<div style="font-size:.72rem;color:#8a6a20;margin-bottom:.6rem;font-family:Bebas Neue,sans-serif;letter-spacing:.08em">TOTAL LOYERS : ' + totalLoyer.toLocaleString('fr-FR') + ' ' + cur + '/JOUR</div>' +
    html + '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

// ---- BOX PORTUAIRE MULTI-TENANT (lot du 25 aout 2026, §13-14-15 ; correctif UX du 25 aout 2026,
// 2e passe : 'box_a_louer' est un onglet normal du port, comme suite_privee/suite_presidentielle
// a l'hotel-republica -- louer_box/gerer_box y vivent comme SEULS ordres, la navigation vers/
// depuis cette piece se fait par les onglets standard (enterRoom via piece-tab), sans fonction ni
// ordre dedies) ----
// Option B validee : structure dediee legere, PAS une reutilisation de getLocationPourRoom (qui
// reste a titulaire UNIQUE par piece pour les ~15 autres locations, totalement inchangee). Un
// box est une entree state.locationsActives normale (memes champs, meme sbLoadLocations au
// chargement), mais sa cle d'appartenance est (buildingId, city, locataire, isBox) -- SANS
// roomId, deliberement decouple de la room UX (la toute premiere version, avant meme le
// deplacement vers 'box_a_louer', vivait dans 'entrepot' ; getMaBoxPortuaire continue de
// retrouver ces box-la, qui portent encore l'ancien roomId 'entrepot', puisqu'il ne teste jamais
// roomId). ROOM_ID_BOX_PORTUAIRE_NAV n'est utilise QUE pour le rafraichissement de la piece apres
// location (meme precedent que confirmerLocation) ; le roomId reellement PERSISTE sur l'objet
// (BOX_PORTUAIRE_ID_PERSISTANCE) est une valeur stable, independante de la piece qui heberge
// l'ordre -- un futur deplacement UX n'aura donc plus jamais a se soucier de la persistance
// existante. Persistance dediee (sbSaveLocationBox/sbSupprimerLocationBox, supabase.js) :
// id = buildingId:roomId:city:locataire, pour eviter que deux locataires du meme box n'ecrasent
// la meme ligne (sbSaveLocation/sbSupprimerLocation generiques, sans locataire dans l'id,
// restent inchangees pour les ~15 autres locations). Aucun bonus DIS/INF (§14, contrairement a
// l'ancien bail exclusif retire de data.js) ; destination des loyers = caisse reelle du port
// (republic_port-sainte-marie), creditee dans payerLocations ci-dessus des que isBox===true.
// Totalement independant du fret prive (expedier_colis/receptionner_commande, §15) : aucun
// champ ni verification partagee.
const TARIF_BOX_PORTUAIRE_JOUR = 15;
const ROOM_ID_BOX_PORTUAIRE_NAV = 'box_a_louer'; // room UX reelle -- uniquement pour le rafraichissement post-location
const BOX_PORTUAIRE_ID_PERSISTANCE = 'box-portuaire'; // identifiant stable persiste, jamais lu pour la navigation

function getMaBoxPortuaire() {
  const moi = state.char?.name || '';
  return getLocationsActives().find(l =>
    l.buildingId === BUILDING_ID_PORT && l.city === VILLE_ID_PORT &&
    l.locataire === moi && l.isBox === true
  );
}

function ouvrirModalLouerBox(pa, cost) {
  if (getMaBoxPortuaire()) { ouvrirModalGererBox(); return; }

  const cur = COUNTRIES[state.country]?.cur || 'FR';
  document.getElementById('postes-modal-title').textContent = '📋 Louer un box portuaire';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +
    '<div style="font-size:.78rem;color:#a09060;font-style:italic;margin-bottom:.7rem;border-left:2px solid #3a2a10;padding-left:.6rem">Un box individuel de stockage, indépendant des autres locataires de l\'entrepôt. Aucun bonus DIS/INF associé.</div>' +
    '<div style="background:#0a0805;border:1px solid #1a1810;padding:.5rem;text-align:center;margin-bottom:.7rem">' +
      '<div style="font-size:.82rem;color:#9a8a68">LOYER / JOUR</div>' +
      '<div style="font-family:Bebas Neue,sans-serif;font-size:1.1rem;color:#C9A84C">' + TARIF_BOX_PORTUAIRE_JOUR + ' ' + cur + '</div>' +
    '</div>' +
    '<div style="font-size:.7rem;color:#6a5a30;margin-bottom:.7rem">Le premier loyer est prélevé immédiatement. Ensuite, chaque réveil.</div>' +
    '<button onclick="confirmerLocationBox(' + pa + ',' + cost + ')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">🔑 Louer ce box</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerLocationBox(pa, cost) {
  if (getMaBoxPortuaire()) { showToast('Déjà loué', 'Vous louez déjà un box.', false); return; }
  if ((state.arg || 0) < TARIF_BOX_PORTUAIRE_JOUR) {
    showToast('Fonds insuffisants', TARIF_BOX_PORTUAIRE_JOUR + ' FR requis pour le premier loyer.', false);
    return;
  }
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }

  state.arg -= TARIF_BOX_PORTUAIRE_JOUR;
  if (typeof crediterCaisseBatiment === 'function') await crediterCaisseBatiment('republic', BUILDING_ID_PORT, TARIF_BOX_PORTUAIRE_JOUR).catch(() => {});

  const box = {
    buildingId: BUILDING_ID_PORT, roomId: BOX_PORTUAIRE_ID_PERSISTANCE,
    localLabel: 'Box portuaire (' + (state.char?.name || '') + ')',
    batimentLabel: BUILDINGS[BUILDING_ID_PORT]?.shortName || BUILDING_ID_PORT,
    prix: TARIF_BOX_PORTUAIRE_JOUR,
    bonusPOP: 0, bonusINF: 0, bonusDIS: 0,
    orgaId: '',
    locataire: state.char?.name,
    country: state.country,
    city: VILLE_ID_PORT,
    depuis: state.day || 1,
    visible: false,
    isBox: true
  };
  getLocationsActives().push(box);
  if (typeof sbSaveLocationBox === 'function') sbSaveLocationBox(box).catch(() => {});

  document.getElementById('modal-postes').classList.remove('open');
  updateUI();
  showToast('Box loué !', 'Box portuaire loué. -' + TARIF_BOX_PORTUAIRE_JOUR + ' FR/jour.', true, true);
  addJournalEntry('Box portuaire loué au port de Port-Sainte-Marie. -' + TARIF_BOX_PORTUAIRE_JOUR + ' FR/jour.', 'event-good');
  if (state.currentRoom) enterRoom(BUILDING_ID_PORT, ROOM_ID_BOX_PORTUAIRE_NAV, null);
}

function ouvrirModalGererBox() {
  const box = getMaBoxPortuaire();
  if (!box) { showToast('Aucun box', 'Vous ne louez pas de box ici.', false); return; }
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  document.getElementById('postes-modal-title').textContent = '⚙️ Mon box portuaire';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +
    '<div style="background:#0a0805;border:1px solid #1a1810;padding:.5rem;text-align:center;margin-bottom:.6rem">' +
      '<div style="font-size:.82rem;color:#9a8a68">LOYER / JOUR</div>' +
      '<div style="font-family:Bebas Neue,sans-serif;font-size:1rem;color:#C9A84C">' + box.prix.toLocaleString('fr-FR') + ' ' + cur + '</div>' +
    '</div>' +
    '<div style="font-size:.72rem;color:#6a5a30;margin-bottom:.6rem">Loué depuis le jour ' + (box.depuis || 1) + '. Box individuel, indépendant des autres locataires de l\'entrepôt.</div>' +
    '<button onclick="resilierBox()" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.06em;padding:.4rem;border:1px solid #5a2a2a;background:transparent;color:#8a3a2a;cursor:pointer">❌ Résilier le box</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

function resilierBox() {
  const moi = state.char?.name || '';
  // Meme filtre decouple que getMaBoxPortuaire (pas de test sur roomId) : retrouve aussi bien un
  // box cree avant le correctif UX (roomId encore 'entrepot') qu'un box recent
  // (roomId===BOX_PORTUAIRE_ID_PERSISTANCE) -- sbSupprimerLocationBox ci-dessous est ensuite
  // appelee avec box.roomId, quelle que soit sa valeur reelle, pour cibler la bonne ligne.
  const idx = (state.locationsActives || []).findIndex(l =>
    l.buildingId === BUILDING_ID_PORT && l.city === VILLE_ID_PORT && l.locataire === moi && l.isBox === true
  );
  if (idx < 0) return;
  const box = state.locationsActives[idx];
  state.locationsActives.splice(idx, 1);
  if (typeof sbSupprimerLocationBox === 'function') sbSupprimerLocationBox(box.buildingId, box.roomId, box.city, moi).catch(() => {});
  document.getElementById('modal-postes').classList.remove('open');
  showToast('Box résilié', 'Box portuaire libéré.', false);
  addJournalEntry('Box portuaire résilié.', 'event-info');
  if (state.currentRoom) enterRoom(state.currentBuilding, state.currentRoom, null);
}

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
  document.getElementById('postes-modal-title').textContent = 'Donner à ' + pnj.name.replace(' (PNJ)', '');
  let html = '<div style="padding:.8rem 1rem">';
  html += '<div style="font-size:.78rem;color:#a09060;font-style:italic;margin-bottom:.7rem;border-left:2px solid #3a2a10;padding-left:.6rem">' + (jobLabels[job] || jobLabels.default) + '</div>';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">MONTANT (' + cur + ')</div>';
  html += '<input id="don-pnj-montant" type="number" min="10" step="50" placeholder="Ex: 200" style="width:100%;padding:.4rem .6rem;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;font-family:Crimson Pro,Georgia,serif;font-size:.9rem;box-sizing:border-box;margin-bottom:.7rem"/>';
  html += '<button onclick="confirmerDonPnj(\'' + encodedPnj + '\')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">💰 Donner de l\'argent</button>';

  // Donner un objet — reserve aux vrais joueurs (semantique non definie pour un PNJ non
  // employe). Pas de mail de confirmation (juste le journal), sur demande de Fred.
  if (pnj.isPJ && (state.inventory || []).length > 0) {
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.12em;color:#8a6a20;margin:.9rem 0 .4rem">OU DONNER UN OBJET</div>';
    html += '<div style="display:flex;flex-direction:column;gap:.3rem;max-height:200px;overflow-y:auto">';
    state.inventory.forEach((item, idx) => {
      const qte = item.qty || 1;
      html += '<button onclick="confirmerDonObjetPj(\'' + encodedPnj + '\',' + idx + ')" style="display:flex;justify-content:space-between;align-items:center;padding:.4rem .6rem;border:1px solid #2a2010;background:transparent;color:#c0b090;cursor:pointer;font-size:.8rem;text-align:left">';
      html += '<span><i class="ti ' + (item.icon||'ti-package') + '" style="margin-right:.3rem"></i>' + item.name + (qte > 1 ? ' (×' + qte + ')' : '') + '</span>';
      html += '</button>';
    });
    html += '</div>';
  }

  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// Donne un objet a un vrai joueur (jamais a un PNJ non employe — semantique non definie).
// Contrairement a donnerObjetAJoueur (fiche personnage), pas de mail de confirmation : le
// don est seulement note dans le journal, sur demande explicite de Fred le 7 aout 2026.
async function confirmerDonObjetPj(encodedPnj, idx) {
  let pnj;
  try { pnj = JSON.parse(decodeURIComponent(encodedPnj)); } catch(e) { return; }
  const item = state.inventory[idx];
  if (!item || !pnj.isPJ) return;

  // Colis secret (quete Pat Hounette/Brigitte Menottes) : destine uniquement a Brigitte, une
  // PNJ -- jamais transferable a un vrai joueur, pour ne pas perdre accidentellement l'objet de
  // quete hors de la chaine prevue (voir confirmerDonObjetPnj pour la remise reelle).
  if (item.type === 'colis_secret_pat') {
    showToast('Impossible', 'Ce colis est destiné à Brigitte Menottes, personne d\'autre.', false);
    return;
  }

  const cible = pnj.name.replace(' (PNJ)', '');
  state.inventory.splice(idx, 1);
  renderInventory();
  document.getElementById('modal-postes')?.classList.remove('open');

  // Persistance reelle cote destinataire (corrige un trou : l'objet disparaissait avant
  // sans jamais vraiment arriver chez l'autre joueur). Recupere a sa prochaine connexion.
  if (typeof sbDonnerObjetJoueur === 'function') {
    await sbDonnerObjetJoueur(item, cible, state.char?.name || 'Anonyme').catch(() => {});
  }

  showToast('Objet donné', '"' + item.name + '" donné à ' + cible + '.', true, true);
  addJournalEntry('Vous avez donné "' + item.name + '" à ' + cible + '.', 'event-info');
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
    const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : 'Jour ' + (state.day || 1) + ' · ' + h + 'h';
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
  const dup = getStatEffective('DUP');
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
    html += '<div onclick="confirmerDonObjetPnj('+idx+',\''+encodedPnj+'\')" style="display:flex;align-items:center;gap:.6rem;padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;cursor:pointer" onmouseover="this.style.background=\'#151005\'" onmouseout="this.style.background=\'#0f0d05\'"><i class="ti '+(obj.icon||'ti-package')+'" style="font-size:.9rem;color:#8a6a20"></i><div><div style="font-size:.8rem;color:#c0b090">'+obj.name+'</div><div style="font-size:.85rem;color:#9a8a68">'+(obj.desc||'')+'</div></div></div>';
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
  if (obj.type === 'colis_secret_pat') {
    // Quete Pat Hounette/Brigitte Menottes : ce colis n'est destine qu'a elle -- a tout autre
    // PNJ, transfert refuse plutot que de le laisser se perdre hors de la chaine de la quete
    // (voir queteCarriereObjectifActuel/section 18 : solution la plus simple pour la beta).
    if (nomCourt !== 'Brigitte Menottes') {
      showToast('Impossible', 'Ce colis est destiné à Brigitte Menottes, personne d\'autre.', false);
      return;
    }
    state.inventory.splice(objIdx, 1);
    updateUI();
    if (typeof remettreColisBrigitte === 'function') remettreColisBrigitte();
    return;
  }
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
  const dup = getStatEffective('DUP');
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

function doFalsifierDocs() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cost = 500;
  // Falsifier un document est une competence technique (INT), pas un numero de charme (DUP) --
  // reclasse par l'audit de refonte de la creation de personnage (bêta).
  const int = getStatEffective('INT');
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  state.arg -= cost;
  const taux = Math.min(75, 25 + Math.floor(int * 3));
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

// Doctrine V2 : montant libre (min 500, pas de max), immobilise 7 jours, resolu par le cron de
// minuit (meme mecanisme que pretDemande/attente_validation). Un seul investissement actif a
// la fois par joueur (verifie a l'ouverture ET a la confirmation contre une double-soumission).
async function ouvrirInvestir(pa, cost) {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  if (typeof sbGetInvestissementEnCours === 'function' && state.char?.name) {
    const existant = await sbGetInvestissementEnCours(state.char.name).catch(() => null);
    if (existant) {
      const joursRestants = Math.max(0, Math.ceil((new Date(existant.jour_resolution_at).getTime() - Date.now()) / 86400000));
      showToast('Investissement en cours', 'Vous avez deja ' + existant.montant_initial.toLocaleString('fr-FR') + ' ' + cur + ' places. Resultat dans ' + joursRestants + ' jour(s).', false);
      return;
    }
  }
  document.getElementById('postes-modal-title').textContent = 'Investir';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1rem">' +
    '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Capital immobilise 7 jours. Rendement entre -12% et +12% selon la conjoncture economique de votre ville a l\'echeance. Un seul investissement actif a la fois.</div>' +
    '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.4rem">MONTANT (min. 500 ' + cur + ')</div>' +
    '<input id="investir-montant" type="number" min="500" step="100" placeholder="Montant en ' + cur + '..." style="width:100%;padding:.4rem .6rem;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;font-family:Crimson Pro,serif;font-size:.85rem;box-sizing:border-box;margin-bottom:.8rem"/>' +
    '<button onclick="confirmerInvestir(' + pa + ',' + cost + ')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Placer les fonds</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerInvestir(pa, cost) {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const montant = parseInt(document.getElementById('investir-montant')?.value || 0);
  if (!montant || montant < 500) { showToast('Montant invalide', 'Minimum 500 ' + cur + '.', false); return; }
  if (montant > state.arg) { showToast('Fonds insuffisants', 'Vous n\'avez pas ' + montant + ' ' + cur + '.', false); return; }

  if (typeof sbGetInvestissementEnCours === 'function' && state.char?.name) {
    const existant = await sbGetInvestissementEnCours(state.char.name).catch(() => null);
    if (existant) { showToast('Investissement refusé', 'Vous avez déjà un investissement en cours.', false); return; }
  }
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }

  const pays = state.country || 'republic';
  const ville = state.currentCity || 'capitale';
  const intSnapshot = getStatEffective('INT'); // fige au moment de la mise (equipe actuelle)
  const maintenant = Date.now();

  state.arg -= montant;
  document.getElementById('modal-postes')?.classList.remove('open');
  updateUI();

  if (typeof sbInsert === 'function') {
    await sbInsert('investissements', {
      id: 'invest-' + maintenant,
      joueur: state.char?.name,
      pays, ville,
      montant_initial: montant,
      int_snapshot: intSnapshot,
      jour_placement_at: new Date(maintenant).toISOString(),
      jour_resolution_at: new Date(maintenant + 7 * 86400000).toISOString(),
      statut: 'en_cours'
    }).catch(() => {});
  }

  showToast('Investissement placé !', montant.toLocaleString('fr-FR') + ' ' + cur + ' immobilisés 7 jours.', true, true);
  addJournalEntry('Investissement de ' + montant.toLocaleString('fr-FR') + ' ' + cur + ' placé. Résultat dans 7 jours.', 'event-info');
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


// =====================
// SYSTEME DE CONSTRUCTION (sur un terrain deja achete avec permis)
// =====================
const PRIX_TERRAIN = 25000;
const NIVEAUX_CONSTRUCTION = {
  hangar:            { label: 'Hangar',             cout: 30000,  imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hangar-construction-terrain.png' },
  commerce_standard: { label: 'Commerce standard',  cout: 50000,  imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/commerce-standard-construction-terrain.png' },
  commerce_premium:  { label: 'Commerce premium',   cout: 70000,  imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/commerce-premium-construction-terrain.png' },
  building:          { label: 'Building',           cout: 100000, imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/building-construction-terrain.png' }
};

// Zonage fixe par ville — verrouille des la conception, pour que la justice ait un critere
// objectif face a un refus de permis du maire (voir obstruction). Pas de zonage cliquable :
// une seule valeur "palier maximum autorise" par ville, cohérente avec son folklore.
const PALIER_ORDRE = ['hangar', 'commerce_standard', 'commerce_premium', 'building'];

const ZONAGE_VILLES = {
  republic: {
    capitale: { maxPalier: 'commerce_premium' },
    ville_a:  { maxPalier: 'commerce_premium' }, // Port-Sainte-Marie — port de peche
    ville_b:  { maxPalier: 'building' }          // Montrouge — ville ouvriere/ferroviaire
  },
  narco: {
    capitale: { maxPalier: 'commerce_premium' },
    ville_a:  { maxPalier: 'commerce_premium' }, // Frontera Alta — poste-frontiere montagnard
    ville_b:  { maxPalier: 'building' }          // La Selva — exploitation forestiere lourde
  },
  soviet: {
    capitale: { maxPalier: 'commerce_premium' },
    ville_a:  { maxPalier: 'building' },         // Sibirsk-9 — ville miniere
    ville_b:  { maxPalier: 'building' }          // Kolkhoz-7 — collectif agro-industriel
  },
  khalija: {
    capitale: { maxPalier: 'commerce_premium' },
    ville_a:  { maxPalier: 'commerce_premium' }, // Oasis Al-Baraka — oasis caravaniere
    ville_b:  { maxPalier: 'building' }          // Port Al-Nour — site petrolier
  }
};

function palierAutorise(country, city, palierDemande) {
  const zone = ZONAGE_VILLES[country]?.[city];
  if (!zone) return true; // pas de restriction connue -> autorise par defaut
  const maxIdx = PALIER_ORDRE.indexOf(zone.maxPalier);
  const demandeIdx = PALIER_ORDRE.indexOf(palierDemande);
  if (maxIdx === -1 || demandeIdx === -1) return true;
  return demandeIdx <= maxIdx;
}

// Matieres premieres produites par ville — fondation pour les futures zones de production
// et le moteur d'entreprise. Les capitales restent des lieux de transformation, pas de matiere brute.
const MATIERES_PREMIERES_VILLE = {
  republic: {
    ville_a: ['Poisson'],                    // Port-Sainte-Marie
    ville_b: ['Charbon', 'Métal']             // Montrouge
  },
  narco: {
    ville_a: ['Bois', 'Cuir'],                // Frontera Alta
    ville_b: ['Bois exotique', 'Caoutchouc']  // La Selva
  },
  soviet: {
    ville_a: ['Minerai de fer', 'Charbon'],   // Sibirsk-9
    ville_b: ['Blé', 'Cuir']                  // Kolkhoz-7
  },
  khalija: {
    ville_a: ['Épices', 'Coton'],             // Oasis Al-Baraka
    ville_b: ['Pétrole', 'Poisson']           // Port Al-Nour
  }
};

function getMatieresPremieresVille(country, city) {
  return MATIERES_PREMIERES_VILLE[country]?.[city] || [];
}

// Cache locale synchrone de l'etat des terrains, alimentee depuis Supabase.
// Corrige un bug preexistant : ces deux fonctions etaient appelees partout mais n'existaient
// nulle part, ce qui faisait planter toute tentative de construction.
function getTerrainState(buildingId) {
  if (!state.terrainsState) state.terrainsState = {};
  return state.terrainsState[buildingId] || { proprietaire: null, niveau_construction: null, valeur_totale: PRIX_TERRAIN, constructionAutorisee: false, permis: null };
}

function setTerrainState(buildingId, patch) {
  if (!state.terrainsState) state.terrainsState = {};
  const actuel = { ...getTerrainState(buildingId), ...patch };
  state.terrainsState[buildingId] = actuel;
  return actuel;
}

async function chargerTerrainState(buildingId) {
  if (typeof sbGetTerrainState !== 'function') return getTerrainState(buildingId);
  const distant = await sbGetTerrainState(state.country, buildingId).catch(() => null);
  if (distant) {
    if (!state.terrainsState) state.terrainsState = {};
    state.terrainsState[buildingId] = distant;
  }
  if (distant?.permis?.statut === 'instruction' && (state.day || 1) >= distant.permis.dateInstructionTerminee) {
    await verifierInstructionPermis(buildingId);
  }
  return getTerrainState(buildingId);
}

// Revenu passif quotidien + bonus INF/POP/DIS par niveau de construction. Applique sans
// condition (contrairement aux bureaux loues, qui necessitent une organisation domiciliee) :
// c'est le proprietaire lui-meme qui en profite directement, chaque nuit.
const REVENU_CONSTRUCTION = { hangar: 50, commerce_standard: 150, commerce_premium: 300, building: 500 };
const BONUS_CONSTRUCTION = {
  hangar: {},
  commerce_standard: { inf: 3 },
  commerce_premium: { inf: 6, pop: 2 },
  building: { inf: 10, pop: 5, dis: 3 }
};

async function collecterRevenusConstructions() {
  if (typeof sbGetTerrainsPossedesPar !== 'function' || !state.char?.name) return;
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  let terrains;
  try {
    terrains = await sbGetTerrainsPossedesPar(state.country, state.char.name);
  } catch(e) { return; }

  (terrains || []).forEach(function(ts) {
    if (!ts.niveau_construction) return;
    // Si le batiment est divise, le revenu vient des loyers reels des locataires (voir
    // payerLoyersLotsLoues), pas d'un montant fixe — evite un double revenu.
    const revenu = (ts.subdivisions && ts.subdivisions.length > 0) ? 0 : (REVENU_CONSTRUCTION[ts.niveau_construction] || 0);
    const bonus = BONUS_CONSTRUCTION[ts.niveau_construction] || {};
    const label = NIVEAUX_CONSTRUCTION[ts.niveau_construction]?.label || ts.niveau_construction;

    if (revenu > 0) {
      state.arg = (state.arg || 0) + revenu;
      addJournalEntry('Revenu du ' + label + ' : +' + revenu + ' ' + cur, 'event-good');
    }
    if (bonus.pop) state.pop = Math.min(100, (state.pop || 0) + bonus.pop);
    if (bonus.inf) state.inf = Math.min(100, (state.inf || 0) + bonus.inf);
    if (bonus.dis) state.dis = Math.min(100, (state.dis || 50) + bonus.dis);
  });
}

// =====================
// ACTE DE VENTE — NOTAIRE (finalisation d'un compromis ou d'un achat direct avec rendez-vous)
// =====================
const TERRAINS_LUTHECIA = ['terrain-a-batir-1', 'terrain-a-batir-2', 'terrain-a-batir-3', 'terrain-a-batir-4', 'terrain-a-batir-5'];

// Pour filtrer les demandes de permis par ville (doTraiterDemandesPermis, 10 aout 2026) --
// terrains_etat ne stocke aucun champ city, seulement building_id, d'ou ce mapping construit a
// partir des listes buildings de chaque ville (data.js). Collision Luthecia/Montrouge (les deux
// utilisaient 'terrain-a-batir-3') corrigee le meme soir : Montrouge est passe sur
// 'terrain-a-batir-6', deja libre et deja defini (data.js), aucune donnee perdue (la ligne
// Supabase existante etait deja celle de Luthecia, jamais celle de Montrouge).
// ville_b (Montrouge) contient aussi, depuis le Lot 2D (19 aout 2026), les 5 nouveaux terrains
// 'terrain-a-batir-montrouge-*'. Cette meme liste EST la source unique de verite pour "ce
// batiment appartient au sous-lieu Terrains a batir de Montrouge", reutilisee telle quelle par
// ouvrirTerrainsMontrouge() (plateau-rue-centrale.js) et par sortirBatiment()
// (plateau-navigation.js) -- ne jamais dupliquer cette liste ailleurs.
const TERRAINS_PAR_VILLE = {
  capitale: TERRAINS_LUTHECIA,
  ville_a:  ['terrain-a-batir-8', 'terrain-a-batir-9', 'terrain-a-batir-10', 'terrain-a-batir-11'],
  ville_b:  ['terrain-a-batir-6', 'terrain-a-batir-montrouge-3', 'terrain-a-batir-montrouge-7', 'terrain-a-batir-montrouge-8', 'terrain-a-batir-montrouge-9', 'terrain-a-batir-montrouge-12']
};

// L'Office Notarial est unique et national (a Luthecia), mais doit traiter les compromis/rendez-
// vous de terrains de n'importe quelle ville -- contrairement aux permis (mairie, filtres par
// ville courante). A2, audit multi-ville du 16 aout 2026 : doActeVenteTerrain/
// doOuvrirTransfertCompromis/doValiderTransfertCompromis ne parcouraient que TERRAINS_LUTHECIA.
function getTousLesTerrainsPays() {
  return Object.values(TERRAINS_PAR_VILLE).flat();
}

// Ville reelle d'un terrain, par son id -- ne jamais deduire la ville d'un terrain de
// state.currentCity : le joueur signe toujours a l'Office Notarial de Luthecia, quelle que soit
// la ville du terrain concerne (cf. finaliserAchatTerrain, plateau-pnj.js).
function getVilleTerrain(id) {
  for (const [ville, ids] of Object.entries(TERRAINS_PAR_VILLE)) {
    if (ids.includes(id)) return ville;
  }
  return 'capitale';
}

// =====================
// GEL SUCCESSORAL (architecture Testament/Succession, 21 aout 2026) -- controle centralise
// UNIQUE, reutilise par tous les handlers capables de modifier la propriete/l'engagement d'un
// terrain ou d'une entreprise, plutot que de dupliquer une garde dans chacun (audit exhaustif des
// chemins de mutation, voir rapport d'architecture). Le champ succession_gel vit dans le JSONB
// deja existant (terrains_etat.data / entreprises.data), pose et retire exclusivement par le
// moteur de succession (ouvertureSuccession / le cron de reglement, plateau-personnage.js /
// api/cron-minuit.js) -- jamais par un handler metier.
// =====================

// Retourne l'id de succession qui gele cet actif, ou null si libre. type : 'terrain'|'entreprise'.
async function idSuccessionGelantActif(type, id) {
  if (type === 'terrain') {
    if (typeof chargerTerrainState === 'function' && typeof getTerrainState === 'function') {
      await chargerTerrainState(id);
      const ts = getTerrainState(id);
      return ts?.succession_gel || null;
    }
  } else if (type === 'entreprise') {
    if (typeof getEntrepriseRachetable === 'function') {
      const def = getEntrepriseRachetable(id);
      const data = def ? await def.charger().catch(() => null) : null;
      return data?.succession_gel || null;
    }
  }
  return null;
}

// A appeler en TOUTE PREMIERE ligne de tout handler pouvant modifier/vendre/transferer/preempter/
// construire/changer la propriete d'un terrain ou d'une entreprise (liste exhaustive dans le
// rapport d'architecture). Retourne true si l'action doit etre bloquee (toast standard deja
// affiche) ; false si l'actif est libre et que le handler peut continuer normalement.
async function refuserSiGele(type, id, libelleAction) {
  const gel = await idSuccessionGelantActif(type, id);
  if (!gel) return false;
  showToast('Succession en cours', (libelleAction || 'Cette action') + " est impossible : ce bien est actuellement gelé le temps du règlement d'une succession.", false);
  return true;
}

async function doActeVenteTerrain() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const nom = state.char?.name;

  // Trouver les terrains ou ce joueur a une reservation active (compromis ou achat direct)
  // -- toutes villes du pays, l'Office Notarial est national (A2).
  const candidats = [];
  for (const id of getTousLesTerrainsPays()) {
    await chargerTerrainState(id);
    const ts = getTerrainState(id);
    if (ts.compromis && ts.compromisPar === nom) candidats.push({ id, type: 'compromis', ts });
    else if (ts.achatDirect && ts.achatDirect.demandeur === nom) candidats.push({ id, type: 'achatDirect', ts });
  }

  if (candidats.length === 0) {
    showToast('Aucune réservation', "Vous n'avez ni compromis ni rendez-vous d'achat en cours sur un terrain.", false);
    return;
  }

  if (candidats.length === 1) { traiterActeVente(candidats[0]); return; }

  let html = '<div style="padding:1rem"><div style="display:flex;flex-direction:column;gap:.4rem">';
  candidats.forEach(function(c, i) {
    const nomBatiment = BUILDINGS[c.id]?.shortName || c.id;
    html += '<div onclick="traiterActeVenteParIndex(' + i + ')" style="cursor:pointer;padding:.6rem;border:1px solid #2a2010;background:#0f0d05">' + nomBatiment + ' (' + (c.type === 'compromis' ? 'compromis' : 'rendez-vous notarial') + ')</div>';
  });
  html += '</div></div>';
  window._candidatsActeVente = candidats;
  document.getElementById('postes-modal-title').textContent = 'Quel terrain ?';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function traiterActeVenteParIndex(i) {
  traiterActeVente(window._candidatsActeVente[i]);
}

async function traiterActeVente(candidat) {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const id = candidat.id;
  const ts = candidat.ts;
  if (typeof refuserSiGele === 'function' && await refuserSiGele('terrain', id, "Officialiser l'acte")) return;

  if (candidat.type === 'achatDirect') {
    const ad = ts.achatDirect;
    if (Date.now() < ad.dateAchat) {
      showToast('Trop tôt', 'Votre rendez-vous n\'est pas encore arrivé.', false);
      return;
    }
    if (Date.now() > ad.dateLimite) {
      showToast('Rendez-vous manqué', 'Le délai de rattrapage de 24h est dépassé. Le dépôt est perdu.', false);
      return;
    }
    const solde = ad.prix - ad.acompte;
    if (state.arg < solde) {
      showToast('Fonds insuffisants', solde.toLocaleString('fr-FR') + ' ' + cur + ' restants à payer.', false);
      return;
    }
    // Deduction PA+cout centralisee (Lot 2C) -- au moment ou l'acte est effectivement traite
    // (pas lors de la simple consultation/presentation des candidats dans doActeVenteTerrain),
    // avant la premiere mutation irreversible (finalisation de l'achat).
    const rAd = await deduireCoutOrdre({ pa: 1, cost: solde });
    if (!rAd.ok) { showToast(rAd.raison === 'pa_insuffisants' ? 'PA insuffisants' : 'Fonds insuffisants', rAd.raison === 'pa_insuffisants' ? '1 PA requis.' : solde.toLocaleString('fr-FR') + ' ' + cur + ' restants à payer.', false); return; }
    await finaliserAchatTerrain(id, ad.prix, ad.surface, false);
    setTerrainState(id, { achatDirect: null });
    if (typeof sbSetTerrainState === 'function') await sbSetTerrainState(state.country, id, { achatDirect: null }).catch(() => {});
    document.getElementById('modal-postes')?.classList.remove('open');
    showToast('Acte signé !', 'Propriétaire de ' + (BUILDINGS[id]?.shortName || id) + '.', true, true);
    return;
  }

  // Compromis
  const permisOk = !ts.permis || ts.permis.statut === 'valide';
  const pretOk = !ts.pretDemande || ts.pretDemande.statut === 'accorde' || ts.pretDemande.statut === undefined;
  const pretEnAttente = ts.pretDemande && ts.pretDemande.statut === 'attente_validation';
  const permisEnAttente = ts.permis && ts.permis.statut === 'attente_validation';
  const refuse = (ts.permis && ts.permis.statut === 'refuse') || (ts.pretDemande && ts.pretDemande.statut === 'refuse');

  if (refuse) {
    showToast('Compromis caduc', 'Une clause a été refusée. Votre acompte a normalement déjà été remboursé.', false);
    return;
  }
  if (permisEnAttente || pretEnAttente) {
    showToast('Clauses en attente', 'Le permis et/ou le prêt ne sont pas encore tranchés. Revenez après leur décision.', false);
    return;
  }

  const solde = ts.valeur_totale - (ts.acompte || 0);
  if (state.arg < solde) {
    showToast('Fonds insuffisants', solde.toLocaleString('fr-FR') + ' ' + cur + ' restants à payer.', false);
    return;
  }
  // Deduction PA+cout centralisee (Lot 2C) -- au moment ou l'acte est effectivement traite,
  // avant la premiere mutation irreversible (finalisation de l'achat).
  const rCompromis = await deduireCoutOrdre({ pa: 1, cost: solde });
  if (!rCompromis.ok) { showToast(rCompromis.raison === 'pa_insuffisants' ? 'PA insuffisants' : 'Fonds insuffisants', rCompromis.raison === 'pa_insuffisants' ? '1 PA requis.' : solde.toLocaleString('fr-FR') + ' ' + cur + ' restants à payer.', false); return; }
  await finaliserAchatTerrain(id, ts.valeur_totale, ts.surface, ts.constructionAutorisee);
  const clear = { compromis: null, compromisPar: null, acompte: null, compromisAt: null, compromisExpireAt: null };
  setTerrainState(id, clear);
  if (typeof sbSetTerrainState === 'function') await sbSetTerrainState(state.country, id, clear).catch(() => {});
  document.getElementById('modal-postes')?.classList.remove('open');
  showToast('Acte signé !', 'Propriétaire de ' + (BUILDINGS[id]?.shortName || id) + '. Acompte déduit du prix.', true, true);
}

// =====================
// SE RENSEIGNER SUR UN DOSSIER (Accueil du notaire, refonte du 20 aout 2026 -- audit Ordres)
// Consultation publique du secretariat : n'importe quel nom peut etre saisi, pas seulement celui
// du demandeur (delibere -- pas de garde nom===state.char?.name). Strictement informatif, aucune
// mutation. Agrege uniquement des dossiers reellement persistants deja identifies par l'audit --
// jamais de dossier fabrique par supposition :
//   - terrains_etat (compromis/achat direct/transfert propose), meme scan que doActeVenteTerrain
//     ci-dessus (getTousLesTerrainsPays/chargerTerrainState/getTerrainState)
//   - entreprises (compromis de rachat), meme scan que doRachatEntreprise/doActeRachatEntreprise
// Types volontairement exclus (architecture actuelle insuffisante, voir rapport d'audit) :
// preemption d'Etat (pas de lien nominatif clair a un PJ demandeur), offres de rachat de terrain
// par mail (aucun etat persistant hors la boite mail elle-meme), mariage/testament (aucun contrat
// reel n'existe encore, voir §9 du lot).
// =====================
function doConsulterDossierNotarial() {
  document.getElementById('postes-modal-title').textContent = 'Se renseigner sur un dossier';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.82rem;color:#8a8060;margin-bottom:.8rem">Indiquez le nom du personnage dont vous souhaitez consulter les dossiers notariaux en cours.</div>';
  html += '<input id="dossier-notarial-nom" type="text" placeholder="Nom du personnage..." style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem .6rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.6rem;box-sizing:border-box" />';
  html += '<button class="pnj-action-btn" onclick="rechercherDossierNotarial()"><i class="ti ti-search" style="font-size:.85rem"></i> Consulter</button>';
  html += '<div id="dossier-notarial-resultats" style="margin-top:.9rem"></div>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// Correctif du 21 aout 2026 (audit "Se renseigner sur un dossier" bloque sur "Recherche en
// cours...") : chaque lecture (terrain ou entreprise) est desormais protegee individuellement
// par son propre try/catch -- avant ce correctif, une seule lecture defaillante (rejet de
// promesse non intercepte) interrompait la fonction entiere sans jamais ecrire de resultat final,
// laissant l'interface figee indefiniment et perdant tous les dossiers deja trouves. Le
// deuxieme facteur (recursion chargerTerrainState/verifierInstructionPermis, vraie boucle sans
// fin plutot qu'une exception) est corrige separement, a la source, dans verifierInstructionPermis
// ci-dessus -- les deux correctifs sont complementaires. Strictement en lecture (aucune mutation,
// aucun cout, aucun jet -- inchange), recherche toujours possible sur un nom tiers quelconque
// (aucune garde nom===state.char?.name ajoutee, conforme au design voulu).
async function rechercherDossierNotarial() {
  const nom = (document.getElementById('dossier-notarial-nom')?.value || '').trim();
  const resultatsEl = document.getElementById('dossier-notarial-resultats');
  if (!resultatsEl) return;
  if (!nom) {
    resultatsEl.innerHTML = '<div style="font-size:.8rem;color:#8a3a20;font-style:italic">Indiquez un nom.</div>';
    return;
  }
  resultatsEl.innerHTML = '<div style="font-size:.8rem;color:#8a8060;font-style:italic">Recherche en cours...</div>';

  const dossiers = [];
  let lecturesEchouees = 0;

  // Terrains : compromis actif, achat direct (rendez-vous en attente), transfert de compromis
  // propose a ce nom -- meme source que doActeVenteTerrain/doOuvrirTransfertCompromis. Chaque
  // terrain est isole : une lecture qui echoue est journalisee et sautee, jamais fatale aux autres.
  if (typeof getTousLesTerrainsPays === 'function' && typeof chargerTerrainState === 'function' && typeof getTerrainState === 'function') {
    for (const id of getTousLesTerrainsPays()) {
      try {
        await chargerTerrainState(id);
        const ts = getTerrainState(id);
        if (!ts) continue;
        const nomBatiment = BUILDINGS[id]?.shortName || BUILDINGS[id]?.name || id;
        if (ts.compromis && ts.compromisPar === nom) {
          dossiers.push('Achat d\'un terrain (' + nomBatiment + ') — signature prévue avant le ' + formaterHorodatageJournal(ts.compromisExpireAt));
        }
        if (ts.achatDirect && ts.achatDirect.demandeur === nom) {
          dossiers.push('Achat direct d\'un terrain (' + nomBatiment + ') — rendez-vous notarial le ' + formaterHorodatageJournal(ts.achatDirect.dateAchat));
        }
        if (ts.transfertPropose === nom) {
          dossiers.push('Transfert de compromis proposé (' + nomBatiment + ') — en attente de validation');
        }
      } catch (e) {
        console.error('rechercherDossierNotarial : lecture terrain échouée', id, e);
        lecturesEchouees++;
      }
    }
  }

  // Entreprises : compromis de rachat actif -- meme source que doRachatEntreprise/doActeRachatEntreprise.
  // Meme isolation individuelle que les terrains ci-dessus.
  if (typeof getEntreprisesRachetables === 'function') {
    for (const def of getEntreprisesRachetables()) {
      try {
        const data = await def.charger();
        if (data && data.compromis && data.compromisPar === nom) {
          dossiers.push('Rachat de "' + def.label + '" — signature prévue avant le ' + formaterHorodatageJournal(data.compromisExpireAt));
        }
      } catch (e) {
        console.error('rechercherDossierNotarial : lecture entreprise échouée', def.id, e);
        lecturesEchouees++;
      }
    }
  }

  // Etat final TOUJOURS atteint desormais, quel que soit le nombre de lectures echouees : soit
  // des dossiers sont affiches, soit un message "aucun dossier" explicite -- jamais plus de
  // "Recherche en cours..." qui perdure. Un eventuel echec partiel est signale sans jamais
  // masquer les resultats deja valides trouves par ailleurs.
  let html;
  if (dossiers.length === 0) {
    html = '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucun dossier en cours à ce nom.</div>';
  } else {
    html = '<div style="font-size:.85rem;color:#c0b090;margin-bottom:.5rem">Vous avez ' + dossiers.length + ' dossier(s) en attente :</div>';
    html += '<div style="display:flex;flex-direction:column;gap:.3rem">';
    dossiers.forEach(texte => {
      html += '<div style="font-size:.82rem;color:#e0d8c0">• ' + texte + '</div>';
    });
    html += '</div>';
  }
  if (lecturesEchouees > 0) {
    html += '<div style="font-size:.72rem;color:#8a3a20;font-style:italic;margin-top:.6rem">' + lecturesEchouees + ' dossier(s) n\'ont pas pu être consultés (réessayez plus tard) — les résultats ci-dessus restent fiables.</div>';
  }
  resultatsEl.innerHTML = html;
}

// =====================
// TRANSFERT DE COMPROMIS — validé chez le notaire, presence des deux parties requise (le
// detenteur initie, le destinataire doit lui-meme venir valider). Le delai restant se
// poursuit (pas de remise a 7 jours). L'acompte suit le compromis ; le remboursement entre
// joueurs se negocie hors mecanique automatique.
// =====================

async function doOuvrirTransfertCompromis(pa, cost) {
  const nom = state.char?.name;
  const candidats = [];
  for (const id of getTousLesTerrainsPays()) {
    await chargerTerrainState(id);
    const ts = getTerrainState(id);
    if (ts.compromis && ts.compromisPar === nom) candidats.push({ id, ts });
  }

  if (candidats.length === 0) {
    showToast('Aucun compromis', "Vous ne détenez aucun compromis à transférer.", false);
    return;
  }

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#8a8060;margin-bottom:.8rem">Le délai restant se poursuit chez le nouveau détenteur (pas de remise à 7 jours). Réglez le remboursement de l\'acompte entre vous.</div>';
  candidats.forEach(function(c) {
    const nomBatiment = BUILDINGS[c.id]?.shortName || c.id;
    const joursRestants = Math.ceil((c.ts.compromisExpireAt - Date.now()) / 86400000);
    html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.5rem">';
    html += '<div style="font-size:.85rem;color:#c0b090;margin-bottom:.4rem">' + nomBatiment + ' — ' + joursRestants + ' jour(s) restant(s)</div>';
    html += '<input id="transfert-nom-' + c.id + '" type="text" placeholder="Nom du nouveau détenteur..." style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem .6rem;font-size:.78rem;outline:none;margin-bottom:.4rem" />';
    html += '<button class="pnj-action-btn" onclick="doInitierTransfertCompromis(\'' + c.id + '\',' + pa + ',' + cost + ')">Proposer le transfert</button>';
    html += '</div>';
  });
  html += '</div>';

  document.getElementById('postes-modal-title').textContent = 'Transférer un compromis';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function doInitierTransfertCompromis(id, pa, cost) {
  if (typeof refuserSiGele === 'function' && await refuserSiGele('terrain', id, 'Transférer ce compromis')) return;
  const destinataire = (document.getElementById('transfert-nom-' + id)?.value || '').trim();
  if (!destinataire) { showToast('Nom manquant', 'Indiquez le nom du nouveau détenteur.', false); return; }
  if (destinataire === state.char?.name) { showToast('Impossible', 'Vous ne pouvez pas vous transférer un compromis à vous-même.', false); return; }
  const rTransfert = await deduireCoutOrdre({ pa, cost });
  if (!rTransfert.ok) { showToast('PA insuffisants', '', false); return; }

  const ts = getTerrainState(id);
  const nouvelEtat = setTerrainState(id, { transfertPropose: destinataire, transfertProposePar: state.char?.name });
  if (typeof sbSetTerrainState === 'function') await sbSetTerrainState(state.country, id, nouvelEtat).catch(() => {});

  if (typeof sendMail === 'function') {
    await sendMail(destinataire, 'Office Notarial', 'Transfert de compromis proposé',
      state.char?.name + ' vous propose de reprendre son compromis de vente sur ' + (BUILDINGS[id]?.shortName || id) + '. Rendez-vous à l\'Office Notarial (Bureau des Contrats) pour valider le transfert. Le remboursement éventuel de l\'acompte est à régler entre vous.');
  }

  document.getElementById('modal-postes')?.classList.remove('open');
  showToast('Transfert proposé', destinataire + ' doit se présenter chez le notaire pour valider.', true);
}

async function doValiderTransfertCompromis(pa, cost) {
  const nom = state.char?.name;
  const candidats = [];
  for (const id of getTousLesTerrainsPays()) {
    await chargerTerrainState(id);
    const ts = getTerrainState(id);
    if (ts.transfertPropose === nom) candidats.push({ id, ts });
  }

  if (candidats.length === 0) {
    showToast('Aucune proposition', "Aucun transfert de compromis ne vous est proposé.", false);
    return;
  }

  let html = '<div style="padding:1rem">';
  candidats.forEach(function(c) {
    const nomBatiment = BUILDINGS[c.id]?.shortName || c.id;
    html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.5rem">';
    html += '<div style="font-size:.85rem;color:#c0b090;margin-bottom:.4rem">' + nomBatiment + ' — proposé par ' + c.ts.transfertProposePar + '</div>';
    html += '<button class="pnj-action-btn" onclick="doAccepterTransfertCompromis(\'' + c.id + '\',' + pa + ',' + cost + ')">Accepter le transfert</button>';
    html += '</div>';
  });
  html += '</div>';

  document.getElementById('postes-modal-title').textContent = 'Compromis proposé';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function doAccepterTransfertCompromis(id, pa, cost) {
  if (typeof refuserSiGele === 'function' && await refuserSiGele('terrain', id, 'Accepter ce transfert')) return;
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }

  const ts = getTerrainState(id);
  const nouveauDetenteur = state.char?.name;
  const ancienDetenteur = ts.compromisPar;

  const patch = {
    compromisPar: nouveauDetenteur,
    transfertPropose: null,
    transfertProposePar: null
  };
  // Le permis et le pret, s'ils existent, suivent le nouveau detenteur (c'est lui qui achetera)
  if (ts.permis) patch.permis = { ...ts.permis, demandeur: nouveauDetenteur };
  if (ts.pretDemande) patch.pretDemande = { ...ts.pretDemande, demandeur: nouveauDetenteur };

  const nouvelEtat = setTerrainState(id, patch);
  if (typeof sbSetTerrainState === 'function') await sbSetTerrainState(state.country, id, nouvelEtat).catch(() => {});

  document.getElementById('modal-postes')?.classList.remove('open');
  showToast('Transfert validé !', 'Vous détenez désormais le compromis sur ' + (BUILDINGS[id]?.shortName || id) + '.', true, true);
  addJournalEntry('Compromis repris de ' + ancienDetenteur + ' sur ' + (BUILDINGS[id]?.shortName || id) + '.', 'event-good');
}

// =====================
// ENTREPOT LOGISTIQUE — achat direct par le joueur (fenetre unique, quantites saisies par
// ressource, validation en bloc). Theorie complete validee avec Fred le 6-7 aout 2026.
// Ressources achetees creditees sur state.ressourcesPersonnelles (compteurs empilables,
// distincts de l'inventaire d'objets uniques). NOTE POUR FRED : a confirmer que ce choix
// (nouvelle reserve dediee plutot que l'inventaire classique) te convient avant de brancher
// ceci a un vrai ordre de salle.
// =====================

async function doOuvrirAchatEntrepot(pa, cost) {
  const buildingId = state.currentBuilding;
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const etat = (typeof sbGetBatimentEtat === 'function') ? await sbGetBatimentEtat(state.country, state.currentCity, buildingId) : {};
  const stock = etat.entrepot?.stock || {};
  const prixManuel = etat.entrepot?.prixManuel || {};

  let html = '<div style="padding:1.2rem">';
  html += '<div style="font-size:.96rem;color:#8a8060;margin-bottom:1rem">Indiquez la quantité souhaitée pour chaque produit (laissez vide pour ne rien acheter). Le prix affiché varie selon le niveau du stock.</div>';
  html += '<table style="width:100%;font-size:1rem;border-collapse:collapse">';
  html += '<tr style="color:#8a6a20;font-family:Bebas Neue,sans-serif;font-size:.93rem;letter-spacing:.05em;text-align:left"><th style="padding:.3rem 0">Produit</th><th>Stock</th><th>Prix actuel</th><th>Quantité</th></tr>';

  Object.entries(RESSOURCES_ECONOMIE).forEach(([cle, res]) => {
    const enStock = stock[cle] || 0;
    const prixActuel = prixManuel[cle] != null ? prixManuel[cle] : (typeof getPrixRessourceEntrepot === 'function' ? getPrixRessourceEntrepot(cle) : res.prixBase);
    html += '<tr style="border-top:1px solid #2a2010">';
    html += '<td style="padding:.55rem 0"><i class="ti ' + res.icon + '" style="margin-right:.4rem;font-size:1.1rem"></i>' + res.label + '</td>';
    html += '<td style="color:' + (enStock === 0 ? '#cc5540' : '#8a8060') + '">' + enStock + '</td>';
    html += '<td style="color:#C9A84C;font-weight:bold">' + prixActuel + ' ' + cur + '</td>';
    html += '<td><input type="number" min="0" max="' + enStock + '" id="achat-entrepot-' + cle + '" style="width:90px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-size:1rem" ' + (enStock === 0 ? 'disabled' : '') + ' /></td>';
    html += '</tr>';
  });
  html += '</table>';
  html += '<button class="pnj-action-btn" onclick="confirmerAchatEntrepot(\'' + buildingId + '\',' + pa + ',' + cost + ')" style="margin-top:1.2rem;font-size:1rem;padding:.7rem">Valider l\'achat</button>';
  html += '</div>';

  document.getElementById('postes-modal-title').textContent = 'Salle des Ventes';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerAchatEntrepot(buildingId, pa, cost) {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const etat = await sbGetBatimentEtat(state.country, state.currentCity, buildingId);
  const stock = etat.entrepot?.stock || {};
  const prixManuel = etat.entrepot?.prixManuel || {};

  // Premiere passe : lire les quantites demandees, calculer le total, verifier stock+argent
  const achats = {};
  let total = 0;
  for (const cle of Object.keys(RESSOURCES_ECONOMIE)) {
    const qte = parseInt(document.getElementById('achat-entrepot-' + cle)?.value || 0);
    if (!qte || qte <= 0) continue;
    const enStock = stock[cle] || 0;
    if (qte > enStock) {
      showToast('Stock insuffisant', 'Il ne reste que ' + enStock + ' unité(s) de ' + RESSOURCES_ECONOMIE[cle].label + '.', false);
      return;
    }
    const prix = prixManuel[cle] != null ? prixManuel[cle] : getPrixRessourceEntrepot(cle);
    achats[cle] = { qte, prix };
    total += qte * prix;
  }

  if (Object.keys(achats).length === 0) {
    showToast('Rien à acheter', 'Indiquez au moins une quantité.', false);
    return;
  }
  if (state.arg < total) {
    showToast('Fonds insuffisants', Math.round(total) + ' ' + cur + ' requis, vous avez ' + Math.round(state.arg) + ' ' + cur + '.', false);
    return;
  }
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }

  // Deuxieme passe : appliquer (deduire argent+stock, crediter l'inventaire du joueur —
  // plafonne globalement a 100 objets, voir addToInventory/plateau-divers.js). Si la place
  // manque en cours de route, le reste de l'achat est annule et rembourse au prorata.
  let totalReellementPaye = 0;
  for (const [cle, { qte, prix }] of Object.entries(achats)) {
    const res = RESSOURCES_ECONOMIE[cle];
    const qteAjoutee = addToInventory({
      name: res.label, icon: res.icon, stackable: true, stackKey: cle, qty: qte,
      desc: 'Ressource achetée à l\'entrepôt logistique.'
    });
    if (qteAjoutee > 0) {
      stock[cle] = (stock[cle] || 0) - qteAjoutee;
      totalReellementPaye += qteAjoutee * prix;
    }
  }
  state.arg -= totalReellementPaye;
  total = totalReellementPaye;

  // Revenu credite a la caisse de l'entrepot — corrige le 8 aout 2026 : jusque-la, l'argent
  // paye par le joueur disparaissait sans contrepartie, la caisse ne pouvant que baisser.
  etat.entrepot = { ...(etat.entrepot || {}), stock, caisse: (etat.entrepot?.caisse || 0) + totalReellementPaye };
  if (typeof sbSetBatimentEtat === 'function') await sbSetBatimentEtat(state.country, state.currentCity, buildingId, etat).catch(() => {});

  // Sauvegarde personnage immediate (correctif, 20 aout 2026) : l'argent est deja irreversiblement
  // debite de l'entrepot ci-dessus -- ne pas attendre le debounce de 3s de sbAutoSave() (via
  // updateUI() plus bas) pour que l'inventory recu survive a un refresh immediat. Aucune
  // transaction rejouee : seule l'ecriture de l'etat personnage deja mute est avancee.
  if (typeof sbSavePersonnage === 'function') await sbSavePersonnage(state).catch(() => {});

  document.getElementById('modal-postes')?.classList.remove('open');
  updateUI();
  showToast('Achat effectué !', '-' + Math.round(total) + ' ' + cur + '.', true, true);
  addJournalEntry('Achat à l\'entrepôt logistique : ' + Object.entries(achats).map(([cle, a]) => a.qte + ' ' + RESSOURCES_ECONOMIE[cle].label).join(', ') + '.', 'event-good');
}

// =====================
// VENDRE DU BOIS A L'IMPRIMERIE (La Tribune, Gustave Rotative) — 9 aout 2026
// =====================
// Le bois achete a l'entrepot arrive en inventaire sous forme empilable (stackable/stackKey,
// voir confirmerAchatEntrepot juste au-dessus) — different de la forme utilisee par la recolte/
// l'armurerie (type:'matiere_premiere'). C'est la seule source de bois pour un joueur a
// Luthecia : MATIERES_PREMIERES_VILLE ne definit aucune ressource recoltable pour 'capitale'.
async function ouvrirVendreBoisImprimerie(pa, cost) {
  const lot = (state.inventory || []).find(i => i.stackKey === 'bois' && (i.qty || 0) > 0);
  if (!lot) {
    showToast('Aucun bois', 'Vous n\'avez pas de bois à vendre — achetez-en à l\'Entrepôt Logistique.', false);
    return;
  }
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const etatEntrepot = await sbGetBatimentEtat(state.country, 'capitale', 'entrepot-logistique-luthecia');
  const stockBoisEntrepot = etatEntrepot.entrepot?.stock?.bois || 0;
  const prixUnitaire = Math.round((typeof getPrixRessourceEntrepot === 'function' ? getPrixRessourceEntrepot('bois') : 5) * 1.10 * 100) / 100;

  document.getElementById('postes-modal-title').textContent = 'Vendre du bois à Gustave';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1rem">' +
    '<div style="font-size:.78rem;color:#8a8060;margin-bottom:.7rem">Vous avez ' + lot.qty + ' bois. Gustave achète à ' + prixUnitaire + ' ' + cur + '/unité (cours actuel de l\'entrepôt +10%), dans la limite de sa caisse.</div>' +
    '<input type="number" id="vendre-bois-qte" min="1" max="' + lot.qty + '" value="' + lot.qty + '" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-size:.85rem;outline:none;margin-bottom:.7rem"/>' +
    '<button onclick="confirmerVendreBoisImprimerie(' + pa + ',' + cost + ')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #4a8a4a;background:transparent;color:#6ab858;cursor:pointer">Vendre</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerVendreBoisImprimerie(pa, cost) {
  const qteVoulue = parseInt(document.getElementById('vendre-bois-qte')?.value || '0');
  document.getElementById('modal-postes')?.classList.remove('open');
  if (!qteVoulue || qteVoulue <= 0) { showToast('Quantité invalide', '', false); return; }

  const lot = (state.inventory || []).find(i => i.stackKey === 'bois' && (i.qty || 0) > 0);
  if (!lot || lot.qty < qteVoulue) {
    showToast('Stock personnel insuffisant', 'Vous n\'avez pas ' + qteVoulue + ' bois.', false);
    return;
  }

  const cur = COUNTRIES[state.country]?.cur || 'FR';
  // Prix recalcule ici, pas celui affiche a l'ouverture du modal (le cours peut avoir bouge entre-temps)
  const etatEntrepot = await sbGetBatimentEtat(state.country, 'capitale', 'entrepot-logistique-luthecia');
  const stockBoisEntrepot = etatEntrepot.entrepot?.stock?.bois || 0;
  const prixUnitaire = Math.round((typeof getPrixRessourceEntrepot === 'function' ? getPrixRessourceEntrepot('bois') : 5) * 1.10 * 100) / 100;

  const etatImprimerie = await sbGetBatimentEtat(state.country, 'capitale', 'la-tribune');
  const caisse = etatImprimerie.imprimerie?.caisse || 0;
  const qteAchetable = Math.max(0, Math.min(qteVoulue, Math.floor(caisse / prixUnitaire)));
  if (qteAchetable <= 0) {
    showToast('Caisse vide', 'Gustave n\'a pas les moyens d\'acheter du bois pour le moment.', false);
    return;
  }
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }

  const montantPaye = Math.round(qteAchetable * prixUnitaire * 100) / 100;

  lot.qty -= qteAchetable;
  if (lot.qty <= 0) state.inventory = state.inventory.filter(i => i !== lot);

  etatImprimerie.imprimerie = {
    ...(etatImprimerie.imprimerie || {}),
    stockBois: (etatImprimerie.imprimerie?.stockBois || 0) + qteAchetable,
    caisse: caisse - montantPaye
  };
  if (typeof sbSetBatimentEtat === 'function') await sbSetBatimentEtat(state.country, 'capitale', 'la-tribune', etatImprimerie).catch(() => {});

  state.arg = (state.arg || 0) + montantPaye;
  updateUI();

  if (qteAchetable < qteVoulue) {
    showToast('Vente partielle', 'Gustave n\'avait de quoi acheter que ' + qteAchetable + ' bois (caisse limitée). +' + montantPaye + ' ' + cur + '.', true);
  } else {
    showToast('Vente effectuée', '+' + montantPaye + ' ' + cur + ' pour ' + qteAchetable + ' bois.', true, true);
  }
  addJournalEntry('Vente de ' + qteAchetable + ' bois à Gustave Rotative (+' + montantPaye + ' ' + cur + ').', 'event-good');
}

// =====================
// TABLEAU DE BORD DU DIRECTEUR D'ENTREPOT PJ — meme principe que le directeur d'usine
// (nomme par le Maire au lieu du Ministre des Finances, poste local via scope:'ville').
// Fixe le prix de vente de l'entrepot dans la meme fourchette ±40% que partout ailleurs.
// =====================
const ENTREPOT_PAR_VILLE = {
  capitale: 'entrepot-logistique-luthecia',
  ville_a:  'entrepot-logistique-psm',
  ville_b:  'entrepot-logistique-montrouge'
};

function getBuildingIdDirecteurEntrepot() {
  const ville = state.poste?.city;
  return ville ? ENTREPOT_PAR_VILLE[ville] : null;
}

async function doOuvrirFixerPrixAchatEntrepot(pa, cost) {
  const buildingIdAttendu = getBuildingIdDirecteurEntrepot();
  if (state.poste?.id !== 'directeur_entrepot' || state.currentBuilding !== buildingIdAttendu) {
    showToast('Accès refusé', 'Seul le directeur en poste peut fixer les prix de cet entrepôt.', false);
    return;
  }
  const buildingId = state.currentBuilding;
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const etat = (typeof sbGetBatimentEtat === 'function') ? await sbGetBatimentEtat(state.country, state.currentCity, buildingId) : {};
  const stock = etat.entrepot?.stock || {};
  const prixManuel = etat.entrepot?.prixManuel || {};

  let html = '<div style="padding:1.2rem">';
  html += '<div style="font-size:.96rem;color:#8a8060;margin-bottom:1rem">Prix fixé librement par produit (aucune fourchette imposée — vous pouvez brader votre stock pour dégager de la trésorerie, ou augmenter votre marge). Laissez vide pour revenir au prix automatique (marge fixe de 50%).</div>';
  html += '<table style="width:100%;font-size:1rem;border-collapse:collapse">';
  html += '<tr style="color:#8a6a20;font-family:Bebas Neue,sans-serif;font-size:.93rem;letter-spacing:.05em;text-align:left"><th style="padding:.3rem 0">Produit</th><th>Stock</th><th>Prix auto (marge 50%)</th><th>Prix fixé</th></tr>';

  Object.entries(RESSOURCES_ECONOMIE).forEach(([cle, res]) => {
    const enStock = stock[cle] || 0;
    const prixAuto = getPrixRessourceEntrepot(cle);
    const prixFixe = prixManuel[cle];
    html += '<tr style="border-top:1px solid #2a2010">';
    html += '<td style="padding:.55rem 0"><i class="ti ' + res.icon + '" style="margin-right:.4rem;font-size:1.1rem"></i>' + res.label + '</td>';
    html += '<td style="color:#8a8060">' + enStock + '</td>';
    html += '<td style="color:#6a5a30">' + prixAuto + ' ' + cur + '</td>';
    html += '<td><input type="number" min="0.01" step="0.5" id="prix-fixe-entrepot-' + cle + '" placeholder="auto" value="' + (prixFixe != null ? prixFixe : '') + '" style="width:100px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-size:1rem" /></td>';
    html += '</tr>';
  });
  html += '</table>';
  html += '<button class="pnj-action-btn" onclick="confirmerFixerPrixAchatEntrepot(\'' + buildingId + '\',' + pa + ',' + cost + ')" style="margin-top:1.2rem;font-size:1rem;padding:.7rem">Valider les prix</button>';
  html += '</div>';

  document.getElementById('postes-modal-title').textContent = "Fixer les prix d'achat";
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerFixerPrixAchatEntrepot(buildingId, pa, cost) {
  if (state.poste?.id !== 'directeur_entrepot' || buildingId !== getBuildingIdDirecteurEntrepot()) return;
  const etat = await sbGetBatimentEtat(state.country, state.currentCity, buildingId);
  const prixManuel = { ...(etat.entrepot?.prixManuel || {}) };

  // Liberte de prix du directeur PJ (arbitrage du 24 aout 2026) : plus aucune fourchette
  // economique (ni plancher ni plafond lie a prixBase) -- il peut brader son stock sous son
  // prix d'achat pour degager de la tresorerie, ou au contraire augmenter fortement sa marge.
  // Seules des protections techniques subsistent : nombre valide, fini, strictement positif.
  const nouvellesValeurs = {};
  for (const cle of Object.keys(RESSOURCES_ECONOMIE)) {
    const res = RESSOURCES_ECONOMIE[cle];
    const valeur = document.getElementById('prix-fixe-entrepot-' + cle)?.value;
    if (valeur === '' || valeur == null) continue;
    const prix = parseFloat(valeur);
    if (!isFinite(prix) || prix <= 0) {
      showToast('Prix invalide', res.label + ' doit être fixé à un montant positif.', false);
      return;
    }
    nouvellesValeurs[cle] = Math.round(prix * 100) / 100;
  }

  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }

  for (const cle of Object.keys(RESSOURCES_ECONOMIE)) {
    const valeur = document.getElementById('prix-fixe-entrepot-' + cle)?.value;
    if (valeur === '' || valeur == null) delete prixManuel[cle];
    else prixManuel[cle] = nouvellesValeurs[cle];
  }

  const nouvelEtat = { ...etat, entrepot: { ...(etat.entrepot || {}), prixManuel } };
  if (typeof sbSetBatimentEtat === 'function') await sbSetBatimentEtat(state.country, state.currentCity, buildingId, nouvelEtat).catch(() => {});

  document.getElementById('modal-postes')?.classList.remove('open');
  showToast('Prix mis à jour', 'Les nouveaux prix de vente sont actifs.', true, true);
  addJournalEntry("Prix d'achat de l'entrepôt ajustés en tant que directeur.", 'event-good');
}

// Salaire quotidien du directeur d'entrepot, plafonne par la caisse de son propre entrepot —
// meme montant et meme mecanique que le directeur d'usine (SALAIRE_DIRECTEUR, voir plus haut).
async function debiterCaisseEntrepotPlafonne(pays, city, buildingId, montantVise) {
  const etat = (typeof sbGetBatimentEtat === 'function') ? await sbGetBatimentEtat(pays, city, buildingId).catch(() => null) : null;
  const entrepot = etat?.entrepot || {};
  const solde = entrepot.caisse || 0;
  const montantVerse = Math.min(solde, montantVise);
  if (typeof sbSetBatimentEtat === 'function') {
    await sbSetBatimentEtat(pays, city, buildingId, { ...(etat || {}), entrepot: { ...entrepot, caisse: solde - montantVerse } }).catch(() => {});
  }
  return montantVerse;
}

async function verifierSalaireDirecteurEntrepot() {
  if (state.poste?.id !== 'directeur_entrepot') return;
  const buildingId = getBuildingIdDirecteurEntrepot();
  if (!buildingId) return;
  const jour = state.day || 1;
  if (!state.char) return;
  if (state.char.dernierSalaireDirecteurEntrepotJour === jour) return;

  const pays = state.country || 'republic';
  const montantVerse = await debiterCaisseEntrepotPlafonne(pays, state.poste.city, buildingId, SALAIRE_DIRECTEUR);

  state.arg = (state.arg || 0) + montantVerse;
  state.char.dernierSalaireDirecteurEntrepotJour = jour;
  updateUI();
  if (montantVerse > 0) {
    showToast('Salaire perçu', '+' + montantVerse.toLocaleString('fr-FR') + ' FR.' + (montantVerse < SALAIRE_DIRECTEUR ? ' (caisse insuffisante pour le montant complet)' : ''), true, true);
    addJournalEntry('Salaire de directeur perçu : ' + montantVerse + ' FR.', 'event-good');
  } else {
    showToast('Salaire impayé', 'La caisse de l\'entrepôt est vide aujourd\'hui.', false);
    addJournalEntry('Aucun salaire de directeur perçu : caisse de l\'entrepôt vide.', 'event-bad');
  }
}

// =====================
// VENTE DIRECTE DU TRANSFORMATEUR — mini-stock propre a l'usine (les 40% de production non
// redistribues aux entrepots), meme mecanique de prix dynamique. Revenu credite a la caisse
// de l'usine, pas a celle de l'entrepot.
// =====================

async function doOuvrirVenteDirecteUsine(pa, cost) {
  const buildingId = state.currentBuilding;
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const etat = (typeof sbGetBatimentEtat === 'function') ? await sbGetBatimentEtat(state.country, state.currentCity, buildingId) : {};
  const venteDirecte = etat.usine?.venteDirecte || {};
  const prixManuel = etat.usine?.prixManuel || {};
  const produits = produitsUsine(buildingId);

  if (produits.length === 0) {
    showToast('Rien à vendre', "Aucune production locale disponible pour l'instant.", false);
    return;
  }

  let html = '<div style="padding:1.2rem">';
  html += '<div style="font-size:.96rem;color:#8a8060;margin-bottom:1rem">Vente directe sur place. Indiquez la quantité souhaitée (laissez vide pour ne rien acheter).</div>';
  html += '<table style="width:100%;font-size:1rem;border-collapse:collapse">';
  html += '<tr style="color:#8a6a20;font-family:Bebas Neue,sans-serif;font-size:.93rem;letter-spacing:.05em;text-align:left"><th style="padding:.3rem 0">Produit</th><th>Stock</th><th>Prix mini-maxi</th><th>Prix actuel</th><th>Quantité</th></tr>';

  produits.forEach(cle => {
    const res = RESSOURCES_ECONOMIE[cle];
    if (!res) return;
    const enStock = venteDirecte[cle] || 0;
    const prixActuel = prixManuel[cle] != null ? prixManuel[cle] : getPrixRessource(cle, enStock);
    const prixMin = Math.round(res.prixBase * 0.6 * 100) / 100;
    const prixMax = Math.round(res.prixBase * 1.4 * 100) / 100;
    html += '<tr style="border-top:1px solid #2a2010">';
    html += '<td style="padding:.55rem 0"><i class="ti ' + res.icon + '" style="margin-right:.4rem;font-size:1.1rem"></i>' + res.label + '</td>';
    html += '<td style="color:' + (enStock === 0 ? '#cc5540' : '#8a8060') + '">' + enStock + '</td>';
    html += '<td style="color:#6a5a30">' + prixMin + '-' + prixMax + ' ' + cur + '</td>';
    html += '<td style="color:#C9A84C;font-weight:bold">' + prixActuel + ' ' + cur + '</td>';
    html += '<td><input type="number" min="0" max="' + enStock + '" id="vente-usine-' + cle + '" style="width:90px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-size:1rem" ' + (enStock === 0 ? 'disabled' : '') + ' /></td>';
    html += '</tr>';
  });
  html += '</table>';
  html += '<button class="pnj-action-btn" onclick="confirmerVenteDirecteUsine(\'' + buildingId + '\',' + pa + ',' + cost + ')" style="margin-top:1.2rem;font-size:1rem;padding:.7rem">Valider l\'achat</button>';
  html += '</div>';

  document.getElementById('postes-modal-title').textContent = 'Vente Directe';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerVenteDirecteUsine(buildingId, pa, cost) {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const etat = await sbGetBatimentEtat(state.country, state.currentCity, buildingId);
  const venteDirecte = etat.usine?.venteDirecte || {};
  const prixManuel = etat.usine?.prixManuel || {};

  const achats = {};
  let total = 0;
  for (const cle of produitsUsine(buildingId)) {
    const qte = parseInt(document.getElementById('vente-usine-' + cle)?.value || 0);
    if (!qte || qte <= 0) continue;
    const enStock = venteDirecte[cle] || 0;
    if (qte > enStock) {
      showToast('Stock insuffisant', 'Il ne reste que ' + enStock + ' unité(s) de ' + RESSOURCES_ECONOMIE[cle].label + '.', false);
      return;
    }
    const prix = prixManuel[cle] != null ? prixManuel[cle] : getPrixRessource(cle, enStock);
    achats[cle] = { qte, prix };
    total += qte * prix;
  }

  if (Object.keys(achats).length === 0) {
    showToast('Rien à acheter', 'Indiquez au moins une quantité.', false);
    return;
  }
  if (state.arg < total) {
    showToast('Fonds insuffisants', Math.round(total) + ' ' + cur + ' requis, vous avez ' + Math.round(state.arg) + ' ' + cur + '.', false);
    return;
  }
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }

  let totalReellementPaye = 0;
  for (const [cle, { prix }] of Object.entries(achats)) {
    const res = RESSOURCES_ECONOMIE[cle];
    const qteAjoutee = addToInventory({
      name: res.label, icon: res.icon, stackable: true, stackKey: cle, qty: achats[cle].qte,
      desc: 'Produit acheté en vente directe.'
    });
    if (qteAjoutee > 0) {
      venteDirecte[cle] = (venteDirecte[cle] || 0) - qteAjoutee;
      totalReellementPaye += qteAjoutee * prix;
    }
  }
  state.arg -= totalReellementPaye;

  const nouvelEtat = { ...etat, usine: { ...(etat.usine || {}), venteDirecte, caisse: (etat.usine?.caisse || 0) + totalReellementPaye } };
  if (typeof sbSetBatimentEtat === 'function') await sbSetBatimentEtat(state.country, state.currentCity, buildingId, nouvelEtat).catch(() => {});

  // Sauvegarde personnage immediate (correctif, 20 aout 2026) : meme raisonnement que
  // confirmerAchatEntrepot ci-dessus -- l'argent est deja irreversiblement debite de l'usine,
  // ne pas dependre du debounce de 3s pour que l'inventory recu survive a un refresh immediat.
  if (typeof sbSavePersonnage === 'function') await sbSavePersonnage(state).catch(() => {});

  document.getElementById('modal-postes')?.classList.remove('open');
  updateUI();
  showToast('Achat effectué !', '-' + Math.round(totalReellementPaye) + ' ' + cur + '.', true, true);
  addJournalEntry('Achat en vente directe : ' + Object.entries(achats).map(([cle, a]) => a.qte + ' ' + RESSOURCES_ECONOMIE[cle].label).join(', ') + '.', 'event-good');
}

// =====================
// PRODUCTION PJ DES USINES (10 aout 2026) — meme principe que produire_arme a l'Armurerie :
// travail remunere par PJ, un ordre par chaine (place dans la salle de production dediee de
// chaque usine, donc pas besoin de liste/choix comme produire_arme — la salle determine deja
// le produit). Consomme un vrai stock physique de matiere (usine.stockMatieres), alimente par
// la redirection d'une partie des livraisons de l'entrepot local (PART_REDIRECTION_USINE,
// api/cron-minuit.js) — pas un achat instantane sur la caisse. Salaire calibre pour ~10% de
// marge usine sur le prix de gros (RESSOURCES_ECONOMIE, prixAchatFournisseur) : Revenu = 10x
// prix produit, Cout matiere = 5x prix matiere, Salaire = 90%xRevenu - Cout matiere. Complete
// le mode PNJ automatique (produireTransformateursQuotidien, api/cron-minuit.js), reduit ce
// meme soir a 10% de son volume d'origine : un filet de securite, plus la source principale
// de production.
// =====================
const PA_PRODUCTION_USINE = 1;
const MATIERE_PAR_PA_USINE = 5;
const PRODUIT_PAR_PA_USINE = 10;
const PLAFOND_VENTE_DIRECTE_USINE = 50; // doit rester identique a PLAFOND_VENTE_DIRECTE, api/cron-minuit.js

const CHAINES_PRODUCTION_USINE = {
  medicaments:  { buildingId: 'usine-pharmaceutique-luthecia', city: 'capitale', matiere: 'plantes',  salairePA: 84 },
  alcool:       { buildingId: 'pole-tabac-alcools-psm',        city: 'ville_a',  matiere: 'cereales', salairePA: 55 },
  tabac:        { buildingId: 'pole-tabac-alcools-psm',        city: 'ville_a',  matiere: 'plantes',  salairePA: 66 },
  carburant:    { buildingId: 'raffinerie-montrouge',          city: 'ville_b',  matiere: 'petrole',  salairePA: 70 },
  // Filiere alcool->desinfectant (20 aout 2026, valeurs validees par Fred) : meme usine que
  // medicaments, seconde chaine independante -- aucun changement sur la chaine plantes/medicaments
  // existante. Approvisionnement en alcool volontairement NON automatique (aucune redirection
  // ajoutee a USINE_LOCALE_PAR_VILLE, api/cron-minuit.js) : seul le mecanisme generique
  // vendre_matiere_usine (ci-dessus) peut alimenter stockMatieres.alcool de cette usine, un joueur
  // devant physiquement "transporter" l'alcool depuis Port-Sainte-Marie.
  desinfectant: { buildingId: 'usine-pharmaceutique-luthecia', city: 'capitale', matiere: 'alcool',   salairePA: 70 }
};

async function doProduireUsine(produitId) {
  const c = CHAINES_PRODUCTION_USINE[produitId];
  if (!c) { showToast('Indisponible', '', false); return; }
  const cur = COUNTRIES[state.country || 'republic']?.cur || 'FR';
  const etat = (typeof sbGetBatimentEtat === 'function') ? await sbGetBatimentEtat(state.country, c.city, c.buildingId).catch(() => null) : null;
  const usine = etat?.usine || { caisse: 3000, venteDirecte: {}, stockMatieres: {} };
  const caisse = usine.caisse ?? 0;
  const venteDirecte = usine.venteDirecte || {};
  const stockMatieres = usine.stockMatieres || {};
  const stockActuel = venteDirecte[produitId] || 0;
  const stockMatiereActuel = stockMatieres[c.matiere] || 0;
  const matiereCfg = RESSOURCES_ECONOMIE[c.matiere];
  const produitCfg = RESSOURCES_ECONOMIE[produitId];

  document.getElementById('postes-modal-title').textContent = 'Produire — ' + produitCfg.label;
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.82rem;color:#8a8060;margin-bottom:.7rem">' + PA_PRODUCTION_USINE + ' PA consomme ' + MATIERE_PAR_PA_USINE + ' ' + matiereCfg.label + ' du stock de l\'usine et produit ' + PRODUIT_PAR_PA_USINE + ' ' + produitCfg.label + '. Salaire fixe : ' + c.salairePA + ' ' + cur + '.</div>';
  html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.8rem;font-size:.85rem;color:#8a8060">Stock de ' + matiereCfg.label + ' : ' + stockMatiereActuel + ' · Stock local de ' + produitCfg.label + ' : ' + stockActuel + '/' + PLAFOND_VENTE_DIRECTE_USINE + ' · Caisse de l\'usine : ' + Math.round(caisse) + ' ' + cur + '</div>';
  html += '<button onclick="confirmerProductionUsine(\'' + produitId + '\')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.9rem;letter-spacing:.1em;padding:.6rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Produire (' + PA_PRODUCTION_USINE + ' PA)</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerProductionUsine(produitId) {
  const c = CHAINES_PRODUCTION_USINE[produitId];
  if (!c) { document.getElementById('modal-postes')?.classList.remove('open'); return; }
  const cur = COUNTRIES[state.country || 'republic']?.cur || 'FR';

  const etat = (typeof sbGetBatimentEtat === 'function') ? await sbGetBatimentEtat(state.country, c.city, c.buildingId).catch(() => null) : null;
  if (!etat) { showToast('Indisponible', '', false); document.getElementById('modal-postes')?.classList.remove('open'); return; }
  const usine = etat.usine || { caisse: 3000, venteDirecte: {}, stockMatieres: {} };
  let caisse = usine.caisse ?? 0;
  const venteDirecte = usine.venteDirecte || {};
  const stockMatieres = usine.stockMatieres || {};

  const stockMatiereActuel = stockMatieres[c.matiere] || 0;
  if (stockMatiereActuel < MATIERE_PAR_PA_USINE) { showToast('Stock de matière insuffisant', 'Il manque du ' + RESSOURCES_ECONOMIE[c.matiere].label + ' en stock.', false); document.getElementById('modal-postes')?.classList.remove('open'); return; }

  if (caisse < c.salairePA) { showToast('Caisse insuffisante', "L'usine ne peut pas payer ce travail actuellement.", false); document.getElementById('modal-postes')?.classList.remove('open'); return; }

  const stockActuel = venteDirecte[produitId] || 0;
  const placeRestante = Math.max(0, PLAFOND_VENTE_DIRECTE_USINE - stockActuel);
  if (placeRestante <= 0) { showToast('Stock plein', 'Le stock local de ce produit est au maximum.', false); document.getElementById('modal-postes')?.classList.remove('open'); return; }

  // Deduction PA centralisee (Lot 1, correctif suite a revue) -- deduireCoutOrdre() est
  // desormais l'AUTORITE UNIQUE sur la disponibilite des PA (plus de garde manuelle
  // state.pa<... redondante, qui bloquait a tort meme sous TEST_MODE=true). Appelee ICI, AVANT
  // toute mutation de stock/caisse et avant l'ecriture Supabase : fail-closed, rien n'est mute
  // ni persiste si les PA manquent. cost:0 car le salaire est un GAIN verse au joueur
  // (state.arg += plus bas), pas un cout preleve par deduireCoutOrdre.
  const rPa = await deduireCoutOrdre({ pa: PA_PRODUCTION_USINE, cost: 0 });
  if (!rPa.ok) { showToast('PA insuffisants', PA_PRODUCTION_USINE + ' PA requis.', false); document.getElementById('modal-postes')?.classList.remove('open'); return; }

  const produitsAjoutes = Math.min(PRODUIT_PAR_PA_USINE, placeRestante);
  stockMatieres[c.matiere] = stockMatiereActuel - MATIERE_PAR_PA_USINE;
  caisse -= c.salairePA;
  venteDirecte[produitId] = stockActuel + produitsAjoutes;

  const nouvelEtat = { ...etat, usine: { ...usine, caisse, venteDirecte, stockMatieres } };
  if (typeof sbSetBatimentEtat === 'function') await sbSetBatimentEtat(state.country, c.city, c.buildingId, nouvelEtat).catch(() => {});

  state.arg = (state.arg || 0) + c.salairePA;
  updateUI();
  showToast('Production réussie !', RESSOURCES_ECONOMIE[produitId].label + ' produit(s). +' + c.salairePA + ' ' + cur + ' de salaire.', true, true);
  addJournalEntry('Production de ' + produitsAjoutes + ' ' + RESSOURCES_ECONOMIE[produitId].label + ' (+' + c.salairePA + ' ' + cur + ').', 'event-good');

  // Ne ferme pas le modal : rafraichit pour permettre d'enchainer, meme logique que produire_arme.
  doProduireUsine(produitId);
}

// =====================
// VENTE DE MATIERES PREMIERES A UNE USINE (lot filiere alcool->desinfectant, 20 aout 2026) --
// generique pour toute usine/toute chaine CHAINES_PRODUCTION_USINE, pas seulement l'usine
// pharmaceutique : construit une chaine industrielle inter-villes (une matiere achetee/produite
// ailleurs doit pouvoir etre revendue par un joueur a l'usine qui la transforme), sans aucun
// transfert automatique entre batiments -- le joueur est le seul vecteur de transport.
//
// Reutilise integralement crediterStockMatiereCommerce() (plateau-actions-illegales-rumeurs.js)
// pour la mise a jour stock/cout moyen pondere -- deja generique (ne connait ni commerce ni
// usine, seulement un objet {stockMatieres, coutMoyenMatieres}), aucune logique dupliquee. Le
// reste (verifications, debit de la caisse de l'usine, credit du joueur) suit le meme squelette
// que vendreMatiereCommerce SANS l'appeler directement : structure de donnees differente
// (etat.usine, pas une entreprise "commerce" avec parametres.stockMax/taxation).
//
// Prix : aucun systeme de prix fixe par un directeur pour l'achat de matieres par une usine
// n'existe encore (explicitement hors perimetre de ce lot) -- prixAchatFournisseur est utilise
// directement (meme repli que prixAchatMatiereCommerce en l'absence de prix manuel), sans aucune
// valeur inventee : c'est deja la valeur utilisee par l'entrepot pour racheter cette meme
// ressource aux fournisseurs.
// Plafond : RESSOURCES_ECONOMIE[matiere].plafond, meme convention que la redirection
// entrepot->usine existante (livrerEntrepotsQuotidien, api/cron-minuit.js) -- pas un stockMax
// distinct invente pour l'occasion.

// Matieres acceptees par une usine = union des matieres des chaines CHAINES_PRODUCTION_USINE
// configurees pour ce buildingId (jamais une liste codee en dur par usine) -- meme principe que
// matieresAccepteesParCommerce (union des materiaux de la carte), applique ici aux chaines de
// production. Tant qu'aucune chaine n'est configuree pour une matiere donnee sur ce batiment
// (ex. alcool pour l'usine pharmaceutique, avant l'ajout de la chaine alcool->desinfectant),
// cette matiere n'est pas acceptee -- comportement voulu, pas une limitation a lever.
function matieresAccepteesParUsine(buildingId) {
  return Object.values(CHAINES_PRODUCTION_USINE)
    .filter(c => c.buildingId === buildingId)
    .map(c => c.matiere);
}

// Produits vendables en vente directe par une usine = cles CHAINES_PRODUCTION_USINE dont le
// buildingId correspond (correctif, 20 aout 2026) -- meme principe generique que
// matieresAccepteesParUsine ci-dessus, applique cette fois aux produits finis plutot qu'aux
// matieres. Corrige la cause reelle de l'absence de desinfectant en vente directe : la liste
// affichee etait Object.keys(etat.usine.venteDirecte), qui ne contient une cle que si CE produit
// a deja ete produit au moins une fois -- une usine dont une nouvelle chaine vient d'etre ajoutee
// (ex. alcool->desinfectant) n'a jamais cette cle tant que personne n'a produit, meme si la
// chaine existe deja dans la config. Generique pour toute usine/chaine future, jamais un id
// code en dur.
function produitsUsine(buildingId) {
  return Object.keys(CHAINES_PRODUCTION_USINE)
    .filter(id => CHAINES_PRODUCTION_USINE[id].buildingId === buildingId);
}

async function vendreMatierePremiereUsine(buildingId, pays, ville, matiere, qte) {
  if (!matieresAccepteesParUsine(buildingId).includes(matiere)) return { ok: false, raison: 'matiere_non_acceptee' };
  if (!qte || qte <= 0) return { ok: false, raison: 'quantite_invalide' };

  const lot = (state.inventory || []).find(i => i.stackable && i.stackKey === matiere && (i.qty || 0) > 0);
  if (!lot || lot.qty < qte) return { ok: false, raison: 'stock_personnel_insuffisant' };

  const etat = (typeof sbGetBatimentEtat === 'function') ? await sbGetBatimentEtat(pays, ville, buildingId).catch(() => null) : null;
  if (!etat) return { ok: false, raison: 'introuvable' };
  const usine = etat.usine || { caisse: 3000, venteDirecte: {}, stockMatieres: {} };
  if (!usine.stockMatieres) usine.stockMatieres = {};

  const res = RESSOURCES_ECONOMIE[matiere];
  const stockActuel = usine.stockMatieres[matiere] || 0;
  const placeRestante = Math.max(0, res.plafond - stockActuel);
  if (placeRestante < qte) return { ok: false, raison: 'stock_plein', placeRestante };

  const prixUnitaire = res.prixAchatFournisseur;
  const total = prixUnitaire * qte;
  if ((usine.caisse || 0) < total) return { ok: false, raison: 'caisse_insuffisante' };

  lot.qty -= qte;
  if (lot.qty <= 0) state.inventory = state.inventory.filter(i => i !== lot);

  crediterStockMatiereCommerce(usine, matiere, qte, prixUnitaire);
  usine.caisse = (usine.caisse || 0) - total;
  state.arg = (state.arg || 0) + total;

  const nouvelEtat = { ...etat, usine };
  if (typeof sbSetBatimentEtat === 'function') await sbSetBatimentEtat(pays, ville, buildingId, nouvelEtat).catch(() => {});

  return { ok: true, total, prixUnitaire, qte };
}

function doVendreMatierePremiereUsineGenerique(pa, cost) {
  const buildingId = state.currentBuilding;
  if (!buildingId) { showToast('Indisponible', '', false); return; }
  doOuvrirVendreMatierePremiereUsine(buildingId, pa, cost);
}

async function doOuvrirVendreMatierePremiereUsine(buildingId, pa, cost) {
  const pays = state.country || 'republic';
  const ville = state.currentCity || 'capitale';
  const cur = COUNTRIES[state.country || 'republic']?.cur || 'FR';
  const etat = (typeof sbGetBatimentEtat === 'function') ? await sbGetBatimentEtat(pays, ville, buildingId).catch(() => null) : null;
  const usine = etat?.usine || { caisse: 3000, venteDirecte: {}, stockMatieres: {} };
  const matieres = matieresAccepteesParUsine(buildingId);
  const disponibles = matieres.filter(m => (state.inventory || []).some(i => i.stackable && i.stackKey === m && (i.qty || 0) > 0));

  document.getElementById('postes-modal-title').textContent = "Vendre des matières à l'usine";
  let html = '<div style="padding:1rem">';
  if (disponibles.length === 0) {
    html += '<div style="font-size:.9rem;color:#8a8060">Vous ne possédez aucune matière utilisée par cette usine' + (matieres.length ? ' (' + matieres.map(m => (RESSOURCES_ECONOMIE[m]?.label || m)).join(', ') + ')' : '') + '.</div>';
  } else {
    html += '<div style="font-size:.82rem;color:#8a8060;margin-bottom:.7rem">Prix d\'achat au tarif fournisseur en vigueur.</div>';
  }
  disponibles.forEach(m => {
    const lot = (state.inventory || []).find(i => i.stackable && i.stackKey === m && (i.qty || 0) > 0);
    const qteDispo = lot?.qty || 0;
    const res = RESSOURCES_ECONOMIE[m];
    const prixUnitaire = res.prixAchatFournisseur;
    const stockActuel = usine.stockMatieres[m] || 0;
    const placeRestante = Math.max(0, res.plafond - stockActuel);
    const qteInitiale = Math.max(1, Math.min(qteDispo, placeRestante));
    html += '<div style="display:flex;align-items:center;gap:.5rem;margin-bottom:.5rem">';
    html += '<span style="flex:1;font-size:.88rem;color:#c0b090">' + res.label + ' (' + prixUnitaire.toLocaleString('fr-FR') + ' ' + cur + '/unité) — vous en avez ' + qteDispo + ', capacité restante ' + placeRestante + '</span>';
    html += '<input type="number" id="vendre-usine-qte-' + m + '" min="1" max="' + qteDispo + '" value="' + qteInitiale + '" style="width:70px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.3rem;font-size:.88rem;outline:none"/>';
    html += '<button ' + (placeRestante === 0 ? 'disabled style="padding:.3rem .6rem;border:1px solid #3a2a20;background:transparent;color:#5a5040;cursor:default;font-size:.82rem"' : 'onclick="confirmerVendreMatierePremiereUsineUI(\'' + buildingId + '\',\'' + m + '\')" style="padding:.3rem .6rem;border:1px solid #4a8a4a;background:transparent;color:#6ab858;cursor:pointer;font-size:.82rem"') + '>Vendre</button>';
    html += '</div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerVendreMatierePremiereUsineUI(buildingId, matiere) {
  const pays = state.country || 'republic';
  const ville = state.currentCity || 'capitale';
  const qte = parseInt(document.getElementById('vendre-usine-qte-' + matiere)?.value || '0');
  document.getElementById('modal-postes')?.classList.remove('open');
  if (!qte || qte <= 0) { showToast('Quantité invalide', '', false); return; }

  const res = await vendreMatierePremiereUsine(buildingId, pays, ville, matiere, qte);
  const label = RESSOURCES_ECONOMIE[matiere]?.label || matiere;
  if (!res.ok) {
    const messages = {
      introuvable: '',
      matiere_non_acceptee: "Cette usine n'utilise pas cette matière.",
      quantite_invalide: '',
      stock_personnel_insuffisant: 'Vous n\'avez pas ' + qte + ' unité(s) de ' + label + '.',
      stock_plein: 'Le stock maximum de cette matière est atteint pour cette usine.',
      caisse_insuffisante: "L'usine ne peut pas acheter cette quantité actuellement."
    };
    showToast('Vente refusée', messages[res.raison] || '', false);
    return;
  }
  updateUI();
  showToast('Vente effectuée', '+' + res.total.toLocaleString('fr-FR') + ' FR pour ' + res.qte + ' ' + label + '.', true, true);
  addJournalEntry('Vente de ' + res.qte + ' ' + label + " à l'usine (+" + res.total.toLocaleString('fr-FR') + ' FR).', 'event-good');
  doOuvrirVendreMatierePremiereUsine(buildingId, 0, 0); // rafraichit, meme pattern que vendre_matiere_commerce
}

// =====================
// TABLEAU DE BORD DU DIRECTEUR PJ — le directeur choisit le prix de vente directe (dans la
// meme fourchette ±40% que les entrepots) et la repartition entrepots/vente directe de sa
// propre usine (voir note du 7 aout 2026 dans api/cron-minuit.js). Reserve au titulaire du
// poste, dans son propre batiment.
// =====================
const DIRECTEUR_USINE_INFO = {
  directeur_pharma:        { city: 'capitale', buildingId: 'usine-pharmaceutique-luthecia', produits: ['medicaments', 'desinfectant'] },
  directeur_tabac_alcools: { city: 'ville_a',   buildingId: 'pole-tabac-alcools-psm',        produits: ['alcool', 'tabac'] },
  directeur_raffinerie:    { city: 'ville_b',   buildingId: 'raffinerie-montrouge',          produits: ['carburant'] }
};

// =====================
// VIREMENT USINE -> MINISTERE (lot du 24 aout 2026) — le directeur ne peut jamais prelever dans
// la caisse du Ministere : il peut seulement VERSER depuis la caisse de SA propre usine.
// DIRECTEUR_USINE_INFO garantit deja qu'un poste de directeur ne correspond qu'a une seule usine
// precise -- aucune selection d'une autre usine n'est possible, donc aucun risque qu'un directeur
// transfere l'argent d'une usine qu'il ne dirige pas. Symmetrique de doOuvrirVirementMinistereUsine
// (plateau-politique.js), memes primitives (debiterCaisseEtatBatimentAtomique/
// crediterCaisseBatiment, ci-dessus).
// =====================
function doOuvrirVirementUsineMinistere(pa, cost) {
  const cfg = DIRECTEUR_USINE_INFO[state.poste?.id];
  if (!cfg || state.currentBuilding !== cfg.buildingId) {
    showToast('Accès refusé', 'Seul le directeur en poste peut ordonner ce virement, depuis sa propre usine.', false);
    return;
  }
  document.getElementById('postes-modal-title').textContent = 'Virement vers le Ministère';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#8a8060;margin-bottom:.8rem">Prélevé sur la caisse de cette usine, versé à la caisse du Ministère des Finances.</div>';
  html += '<label style="font-size:.72rem;color:#8a8060;display:block;margin-bottom:.3rem">Montant (FR)</label>';
  html += '<input id="virement-ministere-montant" type="number" min="1" step="1" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-size:.85rem;outline:none;margin-bottom:.8rem"/>';
  html += '<button onclick="confirmerVirementUsineMinistere(' + pa + ',' + cost + ')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.55rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Virer</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerVirementUsineMinistere(pa, cost) {
  // Re-verification complete du poste ET du batiment courant (pas seulement a l'ouverture du
  // modal) : c'est ici, a la confirmation, que la mutation reelle a lieu.
  const cfg = DIRECTEUR_USINE_INFO[state.poste?.id];
  if (!cfg || state.currentBuilding !== cfg.buildingId) {
    showToast('Accès refusé', 'Seul le directeur en poste peut ordonner ce virement, depuis sa propre usine.', false);
    return;
  }
  const montant = Math.floor(Number(document.getElementById('virement-ministere-montant')?.value));
  if (!isFinite(montant) || montant <= 0) { showToast('Montant invalide', 'Le montant doit être un nombre entier positif.', false); return; }

  const pays = state.country || 'republic';
  const cur = COUNTRIES[pays]?.cur || 'FR';

  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }

  // Debit atomique de la caisse de l'usine EN PREMIER (jamais de decouvert) ; le credit au
  // Ministere n'est tente que si ce debit a reellement reussi.
  const montantPreleve = await debiterCaisseEtatBatimentAtomique(pays, cfg.city, cfg.buildingId, 'usine', montant);
  if (montantPreleve <= 0) {
    showToast('Caisse insuffisante', "La caisse de l'usine ne peut pas couvrir ce virement.", false);
    return;
  }
  if (typeof crediterCaisseBatiment === 'function') await crediterCaisseBatiment(pays, 'gouvernement-min_fin', montantPreleve);

  document.getElementById('modal-postes')?.classList.remove('open');
  updateUI();
  showToast('Virement effectué', montantPreleve.toLocaleString('fr-FR') + ' ' + cur + ' versés au Ministère des Finances.', true, true);
  addJournalEntry("Virement de l'usine vers le Ministère des Finances (" + montantPreleve + ' FR).', 'event-good');
}

async function doOuvrirFixerPrixVenteDirecte(pa, cost) {
  const posteId = state.poste?.id;
  const cfg = DIRECTEUR_USINE_INFO[posteId];
  if (!cfg || state.currentBuilding !== cfg.buildingId) {
    showToast('Accès refusé', 'Seul le directeur en poste peut fixer les prix de cette usine.', false);
    return;
  }
  const buildingId = state.currentBuilding;
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const etat = (typeof sbGetBatimentEtat === 'function') ? await sbGetBatimentEtat(state.country, state.currentCity, buildingId) : {};
  const venteDirecte = etat.usine?.venteDirecte || {};
  const prixManuel = etat.usine?.prixManuel || {};

  let html = '<div style="padding:1.2rem">';
  html += '<div style="font-size:.96rem;color:#8a8060;margin-bottom:1rem">Prix fixé par produit, dans la fourchette autorisée. Laissez vide pour revenir au prix automatique (fonction du stock).</div>';
  html += '<table style="width:100%;font-size:1rem;border-collapse:collapse">';
  html += '<tr style="color:#8a6a20;font-family:Bebas Neue,sans-serif;font-size:.93rem;letter-spacing:.05em;text-align:left"><th style="padding:.3rem 0">Produit</th><th>Stock</th><th>Prix mini-maxi</th><th>Prix auto</th><th>Prix fixé</th></tr>';

  cfg.produits.forEach(cle => {
    const res = RESSOURCES_ECONOMIE[cle];
    if (!res) return;
    const enStock = venteDirecte[cle] || 0;
    const prixAuto = getPrixRessource(cle, enStock);
    const prixMin = Math.round(res.prixBase * 0.6 * 100) / 100;
    const prixMax = Math.round(res.prixBase * 1.4 * 100) / 100;
    const prixFixe = prixManuel[cle];
    html += '<tr style="border-top:1px solid #2a2010">';
    html += '<td style="padding:.55rem 0"><i class="ti ' + res.icon + '" style="margin-right:.4rem;font-size:1.1rem"></i>' + res.label + '</td>';
    html += '<td style="color:#8a8060">' + enStock + '</td>';
    html += '<td style="color:#6a5a30">' + prixMin + '-' + prixMax + ' ' + cur + '</td>';
    html += '<td style="color:#6a5a30">' + prixAuto + ' ' + cur + '</td>';
    html += '<td><input type="number" min="' + prixMin + '" max="' + prixMax + '" step="0.5" id="prix-fixe-' + cle + '" placeholder="auto" value="' + (prixFixe != null ? prixFixe : '') + '" style="width:100px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-size:1rem" /></td>';
    html += '</tr>';
  });
  html += '</table>';
  html += '<button class="pnj-action-btn" onclick="confirmerFixerPrixVenteDirecte(\'' + buildingId + '\',' + pa + ',' + cost + ')" style="margin-top:1.2rem;font-size:1rem;padding:.7rem">Valider les prix</button>';
  html += '</div>';

  document.getElementById('postes-modal-title').textContent = 'Fixer les prix de vente';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerFixerPrixVenteDirecte(buildingId, pa, cost) {
  const posteId = state.poste?.id;
  const cfg = DIRECTEUR_USINE_INFO[posteId];
  if (!cfg || buildingId !== cfg.buildingId) return;
  const etat = await sbGetBatimentEtat(state.country, state.currentCity, buildingId);
  const prixManuel = { ...(etat.usine?.prixManuel || {}) };

  // Meme fourchette que la vente directe des entrepots (±40% du prix de base) — le
  // directeur choisit ou se placer dans cette fourchette, pas une liberte totale.
  const nouvellesValeurs = {};
  for (const cle of cfg.produits) {
    const res = RESSOURCES_ECONOMIE[cle];
    const valeur = document.getElementById('prix-fixe-' + cle)?.value;
    if (valeur === '' || valeur == null) continue;
    const prix = parseFloat(valeur);
    const prixMin = Math.round(res.prixBase * 0.6 * 100) / 100;
    const prixMax = Math.round(res.prixBase * 1.4 * 100) / 100;
    if (isNaN(prix) || prix < prixMin || prix > prixMax) {
      showToast('Prix hors fourchette', res.label + ' doit être fixé entre ' + prixMin + ' et ' + prixMax + '.', false);
      return;
    }
    nouvellesValeurs[cle] = Math.round(prix * 100) / 100;
  }

  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }

  for (const cle of cfg.produits) {
    const valeur = document.getElementById('prix-fixe-' + cle)?.value;
    if (valeur === '' || valeur == null) delete prixManuel[cle];
    else prixManuel[cle] = nouvellesValeurs[cle];
  }

  const nouvelEtat = { ...etat, usine: { ...(etat.usine || {}), prixManuel } };
  if (typeof sbSetBatimentEtat === 'function') await sbSetBatimentEtat(state.country, state.currentCity, buildingId, nouvelEtat).catch(() => {});

  document.getElementById('modal-postes')?.classList.remove('open');
  showToast('Prix mis à jour', 'Les nouveaux prix de vente directe sont actifs.', true, true);
  addJournalEntry('Prix de vente directe ajustés en tant que directeur.', 'event-good');
}

async function doOuvrirFixerRepartitionProduction(pa, cost) {
  const posteId = state.poste?.id;
  const cfg = DIRECTEUR_USINE_INFO[posteId];
  if (!cfg || state.currentBuilding !== cfg.buildingId) {
    showToast('Accès refusé', 'Seul le directeur en poste peut répartir la production de cette usine.', false);
    return;
  }
  const buildingId = state.currentBuilding;
  const etat = (typeof sbGetBatimentEtat === 'function') ? await sbGetBatimentEtat(state.country, state.currentCity, buildingId) : {};
  const repartitionActuelle = etat.usine?.repartitionEntrepots != null ? Math.round(etat.usine.repartitionEntrepots * 100) : 60;

  let html = '<div style="padding:1.2rem">';
  html += '<div style="font-size:.96rem;color:#8a8060;margin-bottom:1rem">Part de la production quotidienne envoyée aux entrepôts publics (répartie entre les 3 villes). Le reste reste ici, en vente directe.</div>';
  html += '<div style="text-align:center;margin:1.2rem 0">';
  html += '<input type="number" min="0" max="100" step="5" id="repartition-entrepots" value="' + repartitionActuelle + '" style="width:100px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-size:1.2rem;text-align:center" /> %';
  html += '<div style="font-size:.9rem;color:#6a5a30;margin-top:.5rem">vers les entrepôts — le reste part en vente directe sur place.</div>';
  html += '</div>';
  html += '<button class="pnj-action-btn" onclick="confirmerFixerRepartitionProduction(\'' + buildingId + '\',' + pa + ',' + cost + ')" style="margin-top:.5rem;font-size:1rem;padding:.7rem">Valider la répartition</button>';
  html += '</div>';

  document.getElementById('postes-modal-title').textContent = 'Répartir la production';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerFixerRepartitionProduction(buildingId, pa, cost) {
  const posteId = state.poste?.id;
  const cfg = DIRECTEUR_USINE_INFO[posteId];
  if (!cfg || buildingId !== cfg.buildingId) return;
  const valeur = parseFloat(document.getElementById('repartition-entrepots')?.value);
  if (isNaN(valeur) || valeur < 0 || valeur > 100) {
    showToast('Valeur invalide', 'Indiquez un pourcentage entre 0 et 100.', false);
    return;
  }
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }
  const etat = await sbGetBatimentEtat(state.country, state.currentCity, buildingId);
  const nouvelEtat = { ...etat, usine: { ...(etat.usine || {}), repartitionEntrepots: valeur / 100 } };
  if (typeof sbSetBatimentEtat === 'function') await sbSetBatimentEtat(state.country, state.currentCity, buildingId, nouvelEtat).catch(() => {});

  document.getElementById('modal-postes')?.classList.remove('open');
  showToast('Répartition mise à jour', valeur + '% de la production ira désormais aux entrepôts.', true, true);
  addJournalEntry('Répartition de la production ajustée en tant que directeur.', 'event-good');
}

// Salaire quotidien du directeur, plafonne par la caisse de sa propre usine — meme principe
// que verifierSalairePolitique, mais la caisse de l'usine vit dans sbGetBatimentEtat (etat.usine.caisse)
// plutot que dans le systeme sbGetCaisseBatiment des institutions politiques.
const SALAIRE_DIRECTEUR = 500;

async function debiterCaisseUsinePlafonne(pays, city, buildingId, montantVise) {
  const etat = (typeof sbGetBatimentEtat === 'function') ? await sbGetBatimentEtat(pays, city, buildingId).catch(() => null) : null;
  const usine = etat?.usine || {};
  const solde = usine.caisse || 0;
  const montantVerse = Math.min(solde, montantVise);
  if (typeof sbSetBatimentEtat === 'function') {
    await sbSetBatimentEtat(pays, city, buildingId, { ...(etat || {}), usine: { ...usine, caisse: solde - montantVerse } }).catch(() => {});
  }
  return montantVerse;
}

async function verifierSalaireDirecteur() {
  const posteId = state.poste?.id;
  const cfg = DIRECTEUR_USINE_INFO[posteId];
  if (!cfg) return;
  const jour = state.day || 1;
  if (!state.char) return;
  if (state.char.dernierSalaireDirecteurJour === jour) return;

  const pays = state.country || 'republic';
  const montantVerse = await debiterCaisseUsinePlafonne(pays, cfg.city, cfg.buildingId, SALAIRE_DIRECTEUR);

  state.arg = (state.arg || 0) + montantVerse;
  state.char.dernierSalaireDirecteurJour = jour;
  updateUI();
  if (montantVerse > 0) {
    showToast('Salaire perçu', '+' + montantVerse.toLocaleString('fr-FR') + ' FR.' + (montantVerse < SALAIRE_DIRECTEUR ? ' (caisse insuffisante pour le montant complet)' : ''), true, true);
    addJournalEntry('Salaire de directeur perçu : ' + montantVerse + ' FR.', 'event-good');
  } else {
    showToast('Salaire impayé', 'La caisse de l\'usine est vide aujourd\'hui.', false);
    addJournalEntry('Aucun salaire de directeur perçu : caisse de l\'usine vide.', 'event-bad');
  }
}

// =====================
// SUBDIVISION DES COMMERCES PREMIUM / BUILDING
// =====================
const SURFACE_MIN_SUBDIVISION = { commerce_premium: 600, building: 300 };

function peutDiviser(ts) {
  return ts.niveau_construction === 'commerce_premium' || ts.niveau_construction === 'building';
}

async function doOuvrirDivisionTerrain() {
  const id = state.currentBuilding;
  await chargerTerrainState(id);
  const ts = getTerrainState(id);

  if (ts.proprietaire !== state.char?.name) {
    showToast('Accès refusé', "Vous n'êtes pas propriétaire de ce terrain.", false);
    return;
  }
  if (!peutDiviser(ts)) {
    showToast('Impossible', 'Seuls les Commerces Premium et les Buildings peuvent être divisés.', false);
    return;
  }

  const surfaceMin = SURFACE_MIN_SUBDIVISION[ts.niveau_construction];
  const subdivisions = ts.subdivisions || [];
  const surfaceUtilisee = subdivisions.reduce(function(s, l) { return s + l.surface; }, 0);
  const surfaceRestante = (ts.surface || 0) - surfaceUtilisee;

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#8a8060;margin-bottom:.8rem">Surface totale : ' + (ts.surface || 0) + ' m² · Surface restante à diviser : ' + surfaceRestante + ' m² · Minimum par lot : ' + surfaceMin + ' m².</div>';

  if (subdivisions.length > 0) {
    html += '<div style="display:flex;flex-direction:column;gap:.3rem;margin-bottom:.8rem">';
    const yATilDesLotsVides = subdivisions.some(function(l) { return !l.locataire; });
    subdivisions.forEach(function(l, i) {
      html += '<div style="padding:.5rem .6rem;border:1px solid #2a2010;background:#0f0d05;display:flex;justify-content:space-between;align-items:center">';
      html += '<span style="font-size:.82rem;color:#c0b090">' + l.label + ' — ' + l.surface + ' m²' + (l.locataire ? ' (loué par ' + l.locataire + ')' : ' (libre)') + '</span>';
      html += '<div style="display:flex;gap:.5rem">';
      if (l.locataire && yATilDesLotsVides) {
        html += '<button onclick="doOuvrirAgrandirLot(' + i + ')" style="font-size:.68rem;color:#4a9a6a;background:transparent;border:none;cursor:pointer">Agrandir</button>';
      }
      html += '<button onclick="doSupprimerSubdivision(' + i + ')" style="font-size:.68rem;color:#cc5540;background:transparent;border:none;cursor:pointer">Retirer</button>';
      html += '</div>';
      html += '</div>';
    });
    html += '</div>';
  }

  html += '<div style="display:flex;gap:.4rem;margin-bottom:.4rem">';
  html += '<input id="subdiv-label" type="text" placeholder="Nom du lot..." style="flex:1;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem .6rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none" />';
  html += '<input id="subdiv-surface" type="number" placeholder="Surface m²..." style="width:120px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem .6rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none" />';
  html += '<input id="subdiv-loyer" type="number" placeholder="Loyer/jour..." style="width:120px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem .6rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none" />';
  html += '</div>';
  html += '<button class="pnj-action-btn" onclick="doAjouterSubdivision()">+ Ajouter ce lot</button>';
  html += '</div>';

  document.getElementById('postes-modal-title').textContent = 'Diviser le bâtiment';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function doAjouterSubdivision() {
  const id = state.currentBuilding;
  if (typeof refuserSiGele === 'function' && await refuserSiGele('terrain', id, 'Diviser ce bien')) return;
  const ts = getTerrainState(id);
  const surfaceMin = SURFACE_MIN_SUBDIVISION[ts.niveau_construction];
  const label = (document.getElementById('subdiv-label')?.value || '').trim();
  const surface = parseInt(document.getElementById('subdiv-surface')?.value || 0);
  const loyer = parseInt(document.getElementById('subdiv-loyer')?.value || 0);

  if (!label) { showToast('Nom manquant', 'Donnez un nom à ce lot.', false); return; }
  if (!surface || surface < surfaceMin) { showToast('Surface trop petite', 'Chaque lot doit faire au moins ' + surfaceMin + ' m².', false); return; }
  if (!loyer || loyer < 1) { showToast('Loyer manquant', 'Indiquez un loyer journalier.', false); return; }

  const subdivisions = ts.subdivisions || [];
  const surfaceUtilisee = subdivisions.reduce(function(s, l) { return s + l.surface; }, 0);
  if (surfaceUtilisee + surface > (ts.surface || 0)) {
    showToast('Surface insuffisante', 'Il ne reste que ' + ((ts.surface || 0) - surfaceUtilisee) + ' m² disponibles.', false);
    return;
  }

  subdivisions.push({ id: 'lot-' + Date.now(), label: label, surface: surface, locataire: null, loyer: loyer });
  const nouvelEtat = setTerrainState(id, { subdivisions: subdivisions });
  if (typeof sbSetTerrainState === 'function') await sbSetTerrainState(state.country, id, nouvelEtat).catch(function() {});

  showToast('Lot ajouté', label + ' (' + surface + ' m²) créé.', true);
  doOuvrirDivisionTerrain();
}

async function doSupprimerSubdivision(idx) {
  const id = state.currentBuilding;
  if (typeof refuserSiGele === 'function' && await refuserSiGele('terrain', id, 'Modifier ce lot')) return;
  const ts = getTerrainState(id);
  const subdivisions = ts.subdivisions || [];
  const lot = subdivisions[idx];
  if (!lot) return;

  if (lot.locataire) {
    const indemnite = (lot.loyer || 0) * 365;
    if (state.arg < indemnite) {
      showToast('Fonds insuffisants', "L'indemnité d'éviction (1 an de loyer, " + indemnite.toLocaleString('fr-FR') + " FR) doit être payée pour retirer ce lot.", false);
      return;
    }
    state.arg -= indemnite;
    if (typeof sbGet === 'function' && typeof sbUpdate === 'function') {
      const rows = await sbGet('personnages', `name=eq.${encodeURIComponent(lot.locataire)}`).catch(function() { return null; });
      const locPerso = rows && rows[0];
      if (locPerso) {
        await sbUpdate('personnages', `name=eq.${encodeURIComponent(lot.locataire)}`, { arg: (locPerso.arg || 0) + indemnite }).catch(function() {});
      }
    }
    if (typeof sendMail === 'function') {
      await sendMail(lot.locataire, "Éviction — indemnité versée", "Le propriétaire a repris le lot « " + lot.label + " ». Une indemnité d'éviction d'un an de loyer (" + indemnite.toLocaleString('fr-FR') + " FR) vous a été versée.");
    }
    showToast('Indemnité versée', indemnite.toLocaleString('fr-FR') + ' FR versés à ' + lot.locataire + '.', true);
  }

  subdivisions.splice(idx, 1);
  const nouvelEtat = setTerrainState(id, { subdivisions: subdivisions });
  if (typeof sbSetTerrainState === 'function') await sbSetTerrainState(state.country, id, nouvelEtat).catch(function() {});
  doOuvrirDivisionTerrain();
}

function doOuvrirAgrandirLot(idxOccupe) {
  const id = state.currentBuilding;
  const ts = getTerrainState(id);
  const subdivisions = ts.subdivisions || [];
  const lotOccupe = subdivisions[idxOccupe];
  if (!lotOccupe) return;

  const lotsVides = subdivisions
    .map(function(l, i) { return { l: l, i: i }; })
    .filter(function(x) { return !x.l.locataire && x.i !== idxOccupe; });

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.82rem;color:#8a8060;margin-bottom:.8rem">Agrandir « ' + lotOccupe.label + ' » (' + lotOccupe.surface + ' m², loué par ' + lotOccupe.locataire + ') en y fusionnant un lot vide. Le locataire n\'est pas affecté.</div>';
  html += '<div style="display:flex;flex-direction:column;gap:.3rem">';
  lotsVides.forEach(function(x) {
    html += '<div onclick="doFusionnerLot(' + idxOccupe + ',' + x.i + ')" style="cursor:pointer;padding:.5rem .6rem;border:1px solid #2a2010;background:#0f0d05">';
    html += '<span style="font-size:.82rem;color:#c0b090">' + x.l.label + ' — ' + x.l.surface + ' m² (libre)</span>';
    html += '</div>';
  });
  html += '</div>';
  html += '<button class="pnj-action-btn" onclick="doOuvrirDivisionTerrain()" style="margin-top:1rem;opacity:.8">Annuler</button>';
  html += '</div>';

  document.getElementById('postes-body').innerHTML = html;
}

// L'agrandissement necessite le consentement du locataire concerne : le proprietaire
// propose, le locataire accepte ou refuse (voir doAccepterFusionLot/doRefuserFusionLot,
// consultables via 'Gérer mon local loué').
async function doFusionnerLot(idxOccupe, idxVide) {
  const id = state.currentBuilding;
  if (typeof refuserSiGele === 'function' && await refuserSiGele('terrain', id, 'Fusionner ces lots')) return;
  const ts = getTerrainState(id);
  const subdivisions = ts.subdivisions || [];
  const lotOccupe = subdivisions[idxOccupe];
  const lotVide = subdivisions[idxVide];
  if (!lotOccupe || !lotVide || lotVide.locataire) return;

  lotOccupe.propositionAgrandissement = { idxVide: idxVide, surfaceAjoutee: lotVide.surface, labelVide: lotVide.label };
  const nouvelEtat = setTerrainState(id, { subdivisions: subdivisions });
  if (typeof sbSetTerrainState === 'function') await sbSetTerrainState(state.country, id, nouvelEtat).catch(function() {});

  if (typeof sendMail === 'function') {
    await sendMail(lotOccupe.locataire, "Proposition d'agrandissement — " + lotOccupe.label,
      "Le propriétaire vous propose d'agrandir votre local « " + lotOccupe.label + " » de " + lotVide.surface + " m² (" + lotVide.label + "), sans changement de loyer. Rendez-vous sur place, rubrique « Gérer mon local loué », pour accepter ou refuser.");
  }

  showToast('Proposition envoyée', lotOccupe.locataire + ' doit accepter avant que la fusion ne soit effective.', true);
  doOuvrirDivisionTerrain();
}

async function doAccepterFusionLot(idxOccupe) {
  const id = state.currentBuilding;
  if (typeof refuserSiGele === 'function' && await refuserSiGele('terrain', id, "Accepter l'agrandissement")) return;
  const ts = getTerrainState(id);
  const subdivisions = ts.subdivisions || [];
  const lotOccupe = subdivisions[idxOccupe];
  const prop = lotOccupe && lotOccupe.propositionAgrandissement;
  if (!prop) return;

  lotOccupe.surface += prop.surfaceAjoutee;
  delete lotOccupe.propositionAgrandissement;
  subdivisions.splice(prop.idxVide, 1);

  const nouvelEtat = setTerrainState(id, { subdivisions: subdivisions });
  if (typeof sbSetTerrainState === 'function') await sbSetTerrainState(state.country, id, nouvelEtat).catch(function() {});

  showToast('Agrandissement accepté', lotOccupe.label + ' fait désormais ' + lotOccupe.surface + ' m².', true);
  if (typeof addJournalEntry === 'function') addJournalEntry('Vous avez accepté l\'agrandissement de ' + lotOccupe.label + '.', 'event-good');
}

async function doRefuserFusionLot(idxOccupe) {
  const id = state.currentBuilding;
  if (typeof refuserSiGele === 'function' && await refuserSiGele('terrain', id, "Refuser l'agrandissement")) return;
  const ts = getTerrainState(id);
  const subdivisions = ts.subdivisions || [];
  const lotOccupe = subdivisions[idxOccupe];
  if (!lotOccupe || !lotOccupe.propositionAgrandissement) return;

  delete lotOccupe.propositionAgrandissement;
  const nouvelEtat = setTerrainState(id, { subdivisions: subdivisions });
  if (typeof sbSetTerrainState === 'function') await sbSetTerrainState(state.country, id, nouvelEtat).catch(function() {});

  showToast('Proposition refusée', "L'agrandissement n'aura pas lieu.", false);
}

// =====================
// LOCATION D'UN LOT (visiteur) + GESTION DU LOCATAIRE
// =====================

async function doOuvrirLouerLot(pa, cost) {
  const id = state.currentBuilding;
  await chargerTerrainState(id);
  const ts = getTerrainState(id);
  const subdivisions = ts.subdivisions || [];
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  if (ts.proprietaire === state.char?.name) {
    showToast('Impossible', "Vous êtes déjà propriétaire de ce terrain — utilisez « Diviser / gérer les lots ».", false);
    return;
  }
  const lotsLibres = subdivisions.filter(function(l) { return !l.locataire; });
  if (lotsLibres.length === 0) {
    showToast('Aucun lot disponible', "Ce terrain n'a pas (encore) été divisé, ou tous les lots sont déjà loués.", false);
    return;
  }

  let html = '<div style="padding:1rem">';
  html += '<div style="display:flex;flex-direction:column;gap:.4rem">';
  lotsLibres.forEach(function(l) {
    html += '<div onclick="doLouerCeLot(\'' + l.id + '\',' + pa + ',' + cost + ')" style="cursor:pointer;padding:.6rem;border:1px solid #2a2010;background:#0f0d05">';
    html += '<span style="font-size:.85rem;color:#c0b090">' + l.label + '</span> — ' + l.surface + ' m² — <span style="color:#4a9a6a">' + l.loyer + ' ' + cur + '/jour</span>';
    html += '</div>';
  });
  html += '</div></div>';

  document.getElementById('postes-modal-title').textContent = 'Louer un lot';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function doLouerCeLot(lotId, pa, cost) {
  const id = state.currentBuilding;
  if (typeof refuserSiGele === 'function' && await refuserSiGele('terrain', id, 'Louer ce lot')) return;
  const ts = getTerrainState(id);
  const subdivisions = ts.subdivisions || [];
  const lot = subdivisions.find(function(l) { return l.id === lotId; });
  if (!lot || lot.locataire) { showToast('Indisponible', 'Ce lot vient d\'être loué par quelqu\'un d\'autre.', false); return; }

  const cur = COUNTRIES[state.country]?.cur || 'FR';
  if (state.arg < lot.loyer) {
    showToast('Fonds insuffisants', lot.loyer + ' ' + cur + ' requis pour le premier loyer.', false);
    return;
  }
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }

  state.arg -= lot.loyer;
  lot.locataire = state.char?.name;

  const nouvelEtat = setTerrainState(id, { subdivisions: subdivisions });
  if (typeof sbSetTerrainState === 'function') await sbSetTerrainState(state.country, id, nouvelEtat).catch(function() {});

  document.getElementById('modal-postes').classList.remove('open');
  updateUI();
  showToast('Bail signé !', lot.label + ' loué. -' + lot.loyer + ' ' + cur + '/jour.', true, true);
  addJournalEntry('Location signée : ' + lot.label + ' (' + (BUILDINGS[id]?.shortName || id) + '). -' + lot.loyer + ' ' + cur + '/jour.', 'event-good');
}

async function doGererLotLoue() {
  const id = state.currentBuilding;
  await chargerTerrainState(id);
  const ts = getTerrainState(id);
  const subdivisions = ts.subdivisions || [];
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  const mesLots = subdivisions
    .map(function(l, i) { return { l: l, i: i }; })
    .filter(function(x) { return x.l.locataire === state.char?.name; });

  if (mesLots.length === 0) {
    showToast('Aucun local', "Vous ne louez aucun lot sur ce terrain.", false);
    return;
  }

  let html = '<div style="padding:1rem">';
  mesLots.forEach(function(x) {
    html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.5rem">';
    html += '<div style="font-size:.85rem;color:#c0b090">' + x.l.label + ' — ' + x.l.surface + ' m² — ' + x.l.loyer + ' ' + cur + '/jour</div>';
    if (x.l.propositionAgrandissement) {
      html += '<div style="margin-top:.5rem;font-size:.8rem;color:#e0d8c0">Le propriétaire propose d\'agrandir ce local de ' + x.l.propositionAgrandissement.surfaceAjoutee + ' m² (' + x.l.propositionAgrandissement.labelVide + '), sans changement de loyer.</div>';
      html += '<div style="display:flex;gap:.5rem;margin-top:.4rem">';
      html += '<button onclick="doAccepterFusionLot(' + x.i + ')" style="font-size:.75rem;color:#4a9a6a;background:transparent;border:1px solid #4a9a6a;padding:.3rem .6rem;cursor:pointer">Accepter</button>';
      html += '<button onclick="doRefuserFusionLot(' + x.i + ')" style="font-size:.75rem;color:#cc5540;background:transparent;border:1px solid #cc5540;padding:.3rem .6rem;cursor:pointer">Refuser</button>';
      html += '</div>';
    }
    html += '</div>';
  });
  html += '</div>';

  document.getElementById('postes-modal-title').textContent = 'Mon local loué';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// NOTE : le paiement des loyers de lots subdivises se fait desormais cote serveur
// (preleverLoyersLots, api/cron-minuit.js), pas ici — voir patch du 3 aout 2026.

function getValeurTotaleBien(ts) {
  if (!ts) return PRIX_TERRAIN;
  const base = ts.valeur_totale || PRIX_TERRAIN; // prix reel au m2 paye a l'achat, si connu
  const niveau = NIVEAUX_CONSTRUCTION[ts.niveau_construction];
  return base + (niveau ? niveau.cout : 0);
}

async function ouvrirModalConstruire() {
  const id = state.currentBuilding;
  await chargerTerrainState(id);
  const ts = getTerrainState(id);
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  if (ts.proprietaire !== state.char?.name) {
    showToast('Accès refusé', 'Vous n\'êtes pas propriétaire de ce terrain.', false);
    return;
  }
  if (!ts.constructionAutorisee) {
    showToast('Permis requis', 'La construction n\'est pas autorisée sur ce terrain (permis manquant).', false);
    return;
  }
  if (ts.niveau_construction) {
    showToast('Déjà construit', 'Un bâtiment de type "' + (NIVEAUX_CONSTRUCTION[ts.niveau_construction]?.label||'') + '" existe déjà ici.', false);
    return;
  }

  document.getElementById('postes-modal-title').textContent = 'Construire sur ce terrain';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Choisissez le type de construction. Le coût s\'ajoute à la valeur de votre terrain (' + PRIX_TERRAIN.toLocaleString('fr-FR') + ' ' + cur + ').</div>';
  Object.entries(NIVEAUX_CONSTRUCTION).forEach(([key, niv]) => {
    html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;display:flex;justify-content:space-between;align-items:center">';
    html += '<div><div style="font-size:.85rem;color:#c0b090">' + niv.label + '</div><div style="font-size:.68rem;color:#6a5a30">' + niv.cout.toLocaleString('fr-FR') + ' ' + cur + '</div></div>';
    html += '<button onclick="confirmerConstruction(&quot;' + key + '&quot;)" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;padding:.3rem .6rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Construire</button>';
    html += '</div>';
  });
  html += '<button onclick="ouvrirModalPretBancaire(&quot;nationale&quot;,&quot;travaux&quot;)" style="width:100%;margin-top:.6rem;font-family:Bebas Neue,sans-serif;font-size:.7rem;padding:.5rem;border:1px solid #4a6a8a;background:transparent;color:#6a9aca;cursor:pointer">🏦 Faire un prêt travaux</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// Duree de chantier (jours) par niveau — nombres pairs pour un vrai palier de mi-chantier.
const DUREE_CHANTIER_JOURS = { hangar: 6, commerce_standard: 12, commerce_premium: 18, building: 24 };

async function confirmerConstruction(niveauKey) {
  const id = state.currentBuilding;
  if (typeof refuserSiGele === 'function' && await refuserSiGele('terrain', id, 'Construire ici')) return;
  const niveau = NIVEAUX_CONSTRUCTION[niveauKey];
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  if (!niveau) return;

  const dureeJours = DUREE_CHANTIER_JOURS[niveauKey] || 6;
  const montant35 = Math.round(niveau.cout * 0.35);
  const montant30 = niveau.cout - 2 * montant35; // reste, evite les arrondis qui derapent

  if (state.arg < montant35) {
    showToast('Fonds insuffisants', montant35.toLocaleString('fr-FR') + ' ' + cur + ' requis pour le premier versement (35%). Pensez au prêt de construction.', false);
    return;
  }

  state.arg -= montant35;
  const maintenant = Date.now();
  const dateFinTheorique = maintenant + dureeJours * 86400000;

  const nouvelEtat = setTerrainState(id, {
    chantier: {
      niveau: niveauKey,
      dureeJours: dureeJours,
      dateDebut: maintenant,
      dateFinTheorique: dateFinTheorique, // fixe — reference pour le demarrage du remboursement du pret
      dateFinPrevue: dateFinTheorique,     // evolue avec les aleas/corruption
      montantTotal: niveau.cout,
      montant35: montant35,
      montant30: montant30,
      palierPaye: 1,
      enAttentePaiement: false,
      joursImpayes: 0,
      evenements: []
    }
  });

  if (typeof sbSetTerrainState === 'function') {
    await sbSetTerrainState(state.country, id, nouvelEtat).catch(() => {});
  }

  document.getElementById('modal-postes').classList.remove('open');
  updateUI();
  const dateTxt = new Date(dateFinTheorique).toLocaleDateString('fr-FR', { day: 'numeric', month: 'long' });
  addJournalEntry('Chantier démarré : ' + niveau.label + '. Premier versement (35%, ' + montant35.toLocaleString('fr-FR') + ' ' + cur + ') payé. Livraison prévue le ' + dateTxt + '.', 'event-good');
  showToast('Chantier démarré !', 'Livraison prévue le ' + dateTxt + '.', true, true);
}

async function doPayerVersementChantier() {
  const id = state.currentBuilding;
  if (typeof refuserSiGele === 'function' && await refuserSiGele('terrain', id, 'Payer le versement')) return;
  await chargerTerrainState(id);
  const ts = getTerrainState(id);
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const ch = ts.chantier;

  if (!ch || !ch.enAttentePaiement) {
    showToast('Rien à payer', "Aucun versement n'est en attente sur ce chantier.", false);
    return;
  }

  const montantDu = ch.palierPaye === 1 ? ch.montant35 : ch.montant30;
  if (state.arg < montantDu) {
    showToast('Fonds insuffisants', montantDu.toLocaleString('fr-FR') + ' ' + cur + ' requis.', false);
    return;
  }

  state.arg -= montantDu;
  ch.palierPaye += 1;
  ch.enAttentePaiement = false;
  ch.joursImpayes = 0;

  const nouvelEtat = setTerrainState(id, { chantier: ch });
  if (typeof sbSetTerrainState === 'function') await sbSetTerrainState(state.country, id, nouvelEtat).catch(() => {});

  updateUI();
  addJournalEntry('Versement de chantier payé (' + montantDu.toLocaleString('fr-FR') + ' ' + cur + '). Le chantier reprend.', 'event-good');
  showToast('Versement payé !', 'Le chantier reprend.', true);
}

async function doCorrompreChantier(pa, cost) {
  const id = state.currentBuilding;
  if (typeof refuserSiGele === 'function' && await refuserSiGele('terrain', id, 'Accélérer le chantier')) return;
  await chargerTerrainState(id);
  const ts = getTerrainState(id);
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const ch = ts.chantier;

  if (!ch) { showToast('Impossible', "Aucun chantier en cours ici.", false); return; }
  if (ch.enAttentePaiement) { showToast('Impossible', 'Un versement est en attente — payez-le avant d\'accélérer.', false); return; }

  const maintenant = Date.now();
  const restant = ch.dateFinPrevue - maintenant;
  if (restant <= 0) { showToast('Inutile', 'Le chantier est déjà arrivé à échéance.', false); return; }

  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  ch.dateFinPrevue = maintenant + Math.floor(restant / 2);

  const nouvelEtat = setTerrainState(id, { chantier: ch });
  if (typeof sbSetTerrainState === 'function') await sbSetTerrainState(state.country, id, nouvelEtat).catch(() => {});

  const dateTxt = new Date(ch.dateFinPrevue).toLocaleDateString('fr-FR', { day: 'numeric', month: 'long' });
  updateUI();
  addJournalEntry('Chantier accéléré par corruption (-' + cost + ' ' + cur + '). Nouvelle livraison prévue le ' + dateTxt + '.', 'event-info');
  showToast('Chantier accéléré', 'Nouvelle livraison : ' + dateTxt + '.', true);
}

// =====================
// PRET BANCAIRE
// =====================
function getTauxPret(typeBanque) {
  const ie = typeof getIndiceNationalCalcule === 'function' ? getIndiceNationalCalcule(state.country, 'ie') : (INDICES_NATIONAUX?.[state.country]?.IE || 40);
  return typeBanque === 'privee' ? (12 + ie / 10) : (5 + ie / 10);
}

// Trois types de prets, chacun avec sa propre limite d'un seul actif a la fois (pas une
// limite globale — un joueur peut avoir un pret Travaux ET un pret Consommation en meme
// temps, mais pas deux Travaux). Immobilier reste exclusivement accessible via le compromis
// de vente de terrain (voir plateau-pnj.js, doConfirmerCompromis) — pas d'acces direct ici
// tant que la revente de biens entre joueurs n'existe pas.
const TYPES_PRET = {
  travaux:      { label: 'Travaux',      desc: 'Financer la construction sur un terrain possédé.' },
  consommation: { label: 'Consommation', desc: 'Petite somme, remboursement rapide, taux élevé.', montantMax: 10000, tauxFixe: 12, dureeMax: 30 }
};

async function ouvrirModalPretBancaire(typeBanque, typePret, pa) {
  typeBanque = typeBanque || 'nationale';

  if (!typePret) {
    let html = '<div style="padding:1rem"><div style="display:flex;flex-direction:column;gap:.4rem">';
    Object.entries(TYPES_PRET).forEach(([key, t]) => {
      html += '<div onclick="ouvrirModalPretBancaire(\'' + typeBanque + '\',\'' + key + '\',' + pa + ')" style="cursor:pointer;padding:.7rem;border:1px solid #2a2010;background:#0f0d05">';
      html += '<div style="font-size:.85rem;color:#c0b090">' + t.label + '</div>';
      html += '<div style="font-size:.7rem;color:#6a5a30;margin-top:.2rem">' + t.desc + '</div>';
      html += '</div>';
    });
    html += '</div></div>';
    document.getElementById('postes-modal-title').textContent = typeBanque === 'privee' ? 'Prêt — Banque Privée Helvetia' : 'Prêt — Banque Nationale';
    document.getElementById('postes-body').innerHTML = html;
    document.getElementById('modal-postes').classList.add('open');
    return;
  }

  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const infosType = TYPES_PRET[typePret];
  const estPrivee = typeBanque === 'privee';
  const estConso = typePret === 'consommation';
  const taux = estConso ? infosType.tauxFixe : getTauxPret(typeBanque);

  document.getElementById('postes-modal-title').textContent = (estPrivee ? 'Prêt — Banque Privée Helvetia' : 'Prêt — Banque Nationale') + ' · ' + infosType.label;
  let html = '<div style="padding:1rem">';
  if (estPrivee) {
    html += '<div style="font-size:.78rem;color:#aa7a30;font-style:italic;margin-bottom:.8rem;padding:.5rem;background:#0f0d05;border:1px solid #3a2810">Aucune vérification. Discrétion garantie. En cas d\'impayé prolongé, la méthode de recouvrement est... directe.</div>';
  }
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Taux applicable : ' + taux.toFixed(1) + '% sur la durée totale du prêt.' + (estConso ? ' Montant max ' + infosType.montantMax.toLocaleString('fr-FR') + ' ' + cur + ', durée max ' + infosType.dureeMax + ' jours.' : '') + '</div>';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.4rem">MONTANT EMPRUNTÉ</div>';
  html += '<input id="pret-montant" type="number" min="1000" ' + (estConso ? 'max="' + infosType.montantMax + '"' : '') + ' step="1000" placeholder="Montant en ' + cur + '..." style="width:100%;padding:.4rem .6rem;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;font-family:Crimson Pro,serif;font-size:.85rem;box-sizing:border-box;margin-bottom:.6rem"/>';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.4rem">DURÉE DE REMBOURSEMENT</div>';
  html += '<select id="pret-duree" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.8rem">';
  const dureesDispo = estConso ? [5,10,15,20,25,30] : [10,15,20,25,30];
  dureesDispo.forEach(d => { html += '<option value="' + d + '">' + d + ' jours</option>'; });
  html += '</select>';
  html += '<button onclick="confirmerPretBancaire(&quot;' + typeBanque + '&quot;,&quot;' + typePret + '&quot;,' + pa + ')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #4a6a8a;background:transparent;color:#6a9aca;cursor:pointer">Contracter le prêt</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerPretBancaire(typeBanque, typePret, pa) {
  const montant = parseInt(document.getElementById('pret-montant')?.value || 0);
  const duree = parseInt(document.getElementById('pret-duree')?.value || 10);
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const infosType = TYPES_PRET[typePret] || TYPES_PRET.travaux;
  const estConso = typePret === 'consommation';

  if (!montant || montant < 1000) { showToast('Montant invalide', 'Minimum 1000 ' + cur + '.', false); return; }
  if (estConso && montant > infosType.montantMax) {
    showToast('Montant trop élevé', 'Le prêt consommation est plafonné à ' + infosType.montantMax.toLocaleString('fr-FR') + ' ' + cur + '.', false);
    return;
  }
  if (estConso && duree > infosType.dureeMax) {
    showToast('Durée trop longue', 'Le prêt consommation est plafonné à ' + infosType.dureeMax + ' jours.', false);
    return;
  }

  // Un seul pret actif PAR TYPE (pas une limite globale — Travaux et Consommation peuvent
  // coexister, mais pas deux Travaux en meme temps). Bug de spam remonte le 5 aout 2026.
  if (typeof sbGetPretsEnCours === 'function' && state.char?.name) {
    const pretsActifs = await sbGetPretsEnCours(state.char.name).catch(() => []);
    const dejaActif = (pretsActifs || []).some(p => (p.type_pret || 'travaux') === typePret);
    if (dejaActif) {
      showToast('Prêt refusé', 'Vous avez déjà un prêt ' + infosType.label.toLowerCase() + ' en cours. Soldez-le avant d\'en contracter un nouveau.', false);
      return;
    }
  }

  const r = await deduireCoutOrdre({ pa, cost: 0 });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }

  const taux = estConso ? infosType.tauxFixe : getTauxPret(typeBanque);
  const montantTotal = Math.round(montant * (1 + taux / 100));
  const mensualite = Math.ceil(montantTotal / duree);

  const pret = {
    id: 'pret-' + Date.now(),
    emprunteur: state.char?.name || 'Anonyme',
    country: state.country,
    building_id: state.currentBuilding || 'non_specifie',
    type_banque: typeBanque || 'nationale',
    type_pret: typePret || 'travaux',
    montant_initial: montant,
    montant_restant: montantTotal,
    duree_jours: duree,
    mensualite,
    jours_impayes: 0,
    jour_dernier_prelevement: state.day || 1,
    statut: 'en_cours'
  };

  if (typeof sbCreerPret === 'function') {
    await sbCreerPret(pret).catch(() => {});
  }

  state.arg = (state.arg || 0) + montant;
  document.getElementById('modal-postes').classList.remove('open');
  updateUI();
  showToast('Prêt accordé !', '+' + montant.toLocaleString('fr-FR') + ' ' + cur + '. Mensualité : ' + mensualite.toLocaleString('fr-FR') + ' ' + cur + '/jour sur ' + duree + ' jours.', true, true);
  addJournalEntry('Prêt ' + infosType.label.toLowerCase() + ' de ' + montant.toLocaleString('fr-FR') + ' ' + cur + ' contracté (taux ' + taux.toFixed(1) + '%) — ' + (typeBanque === 'privee' ? 'Banque Privée' : 'Banque Nationale') + '.', 'event-info');
}

// Prelevement quotidien des prets en cours (appele au reveil, doDormir)
// NOTE : preleverPretsBancaires a ete retiree — le prelevement se fait desormais cote
// serveur (preleverPretsBancairesServeur, api/cron-minuit.js), a heure fixe, que le joueur
// dorme ou non. Voir patch du 5 aout 2026.


// =====================
// PERMIS DE CONSTRUIRE
// =====================
const DUREE_INSTRUCTION_PERMIS = {
  hangar: 2,
  commerce_standard: 4,
  commerce_premium: 6,
  building: 10
};

async function doDeposerDemandePermis(pa, cost) {
  const id = state.currentBuilding;
  await chargerTerrainState(id);
  const ts = getTerrainState(id);
  if (ts.proprietaire !== state.char?.name) { showToast('Accès refusé', 'Vous n\'êtes pas propriétaire de ce terrain.', false); return; }
  if (ts.niveau_construction) { showToast('Déjà construit', '', false); return; }
  if (ts.permis?.statut === 'instruction' || ts.permis?.statut === 'attente_validation') { showToast('Demande en cours', 'Une demande de permis est déjà en instruction.', false); return; }

  document.getElementById('postes-modal-title').textContent = 'Déposer une demande de permis';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;margin-bottom:.8rem">Le permis est toujours obtenu à terme — seule la durée d\'instruction varie selon l\'ampleur du projet.</div>';
  Object.entries(NIVEAUX_CONSTRUCTION).forEach(([key, niv]) => {
    const duree = DUREE_INSTRUCTION_PERMIS[key];
    html += '<button onclick="confirmerDepotPermis(\'' + key + '\',' + pa + ',' + cost + ')" style="display:flex;justify-content:space-between;width:100%;margin-bottom:.4rem;padding:.6rem .7rem;border:1px solid #2a2010;background:transparent;color:#c0b090;cursor:pointer;font-size:.8rem">';
    html += '<span>' + niv.label + '</span><span style="color:#8a8060">' + duree + ' jour(s) d\'instruction</span></button>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerDepotPermis(palierDemande, pa, cost) {
  const id = state.currentBuilding;
  if (typeof refuserSiGele === 'function' && await refuserSiGele('terrain', id, 'Déposer ce permis')) return;
  const ts = getTerrainState(id);
  const jour = state.day || 1;
  const duree = DUREE_INSTRUCTION_PERMIS[palierDemande];

  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }

  const nouvelEtat = setTerrainState(id, {
    permis: {
      demandeur: state.char?.name,
      palierDemande,
      dateDepot: jour,
      dureeInstruction: duree,
      dateInstructionTerminee: jour + duree,
      statut: 'instruction'
    }
  });
  if (typeof sbSetTerrainState === 'function') await sbSetTerrainState(state.country, id, nouvelEtat).catch(() => {});

  document.getElementById('modal-postes')?.classList.remove('open');
  showToast('Demande déposée', 'Instruction en cours (' + duree + ' jour(s)).', true, true);
  addJournalEntry('Demande de permis de construire déposée (' + NIVEAUX_CONSTRUCTION[palierDemande].label + ').', 'event-good');
}

// A appeler en entrant sur le terrain : fait passer une demande en instruction vers l'attente de validation du maire
// Correctif recursion (verification d'idempotence/audit du 21 aout 2026) : cette fonction avait
// pour habitude de rappeler chargerTerrainState(buildingId) en entree -- or son SEUL appelant
// reel (verifie exhaustivement, un seul site d'appel dans tout le code : chargerTerrainState()
// elle-meme, juste apres avoir ecrit state.terrainsState[buildingId] = distant) garantit deja que
// l'etat local est frais au moment de l'appel. Rappeler chargerTerrainState() ici relisait les
// MEMES donnees non mutees (la mutation ts.permis.statut='attente_validation' n'intervient qu'
// apres, plus bas) et rentrait dans chargerTerrainState(), qui rappelait cette fonction, etc. --
// boucle de promesses ne se resolvant jamais (pas un stack overflow, un veritable blocage
// asynchrone : chaque tour reemet une requete reseau). Se declenchait des qu'un seul terrain,
// n'importe ou, avait un permis 'instruction' dont le delai etait echu -- bloquait notamment
// rechercherDossierNotarial() (balaie tous les terrains du pays) et ouvrirSuccession() (gel d'un
// terrain du defunt dans cet etat). Correctif strictement local a cette ligne : utiliser l'etat
// deja charge par l'appelant (getTerrainState(), synchrone, aucune requete) au lieu de le
// rerequeter -- aucune regle metier des permis (duree/resultat/validation/corruption/couts/
// notifications) n'est modifiee ci-dessous.
async function verifierInstructionPermis(buildingId) {
  const ts = getTerrainState(buildingId);
  // Verification directe du champ (pas refuserSiGele()) : cette fonction est elle-meme appelee
  // DEPUIS chargerTerrainState() -- passer par idSuccessionGelantActif(), qui rappelle
  // chargerTerrainState(), creerait une recursion. Controle silencieux (pas de toast) : ce
  // traitement est automatique/passif (declenche a l'entree dans la piece), pas une action du
  // joueur -- un permis ne doit simplement plus evoluer pendant le gel (section 2 du lot).
  if (ts.succession_gel) return;
  if (!ts.permis || ts.permis.statut !== 'instruction') return;
  const jour = state.day || 1;
  if (jour < ts.permis.dateInstructionTerminee) return;

  ts.permis.statut = 'attente_validation';
  ts.permis.dateEntreeAttente = Date.now();
  if (typeof sbSetTerrainState === 'function') await sbSetTerrainState(state.country, buildingId, ts).catch(() => {});

  const maireInfo = await getTitulaireActuel('maire', state.currentCity);
  const maireNom = maireInfo?.estPJ ? maireInfo.nom : null;
  const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : '';
  if (maireNom && typeof sbSendMail === 'function') {
    await sbSendMail('Services municipaux', maireNom, 'Permis de construire à valider',
      ts.permis.demandeur + ' demande un permis de construire (' + NIVEAUX_CONSTRUCTION[ts.permis.palierDemande].label + '). Rendez-vous à la mairie pour traiter les demandes.', time).catch(() => {});
  }
}

// Transfert complet au Maire Adjoint le 10 aout 2026 (verification stricte, plus partage avec
// le Maire) + fix du filtrage : chargeait auparavant TOUS les permis du pays, pas seulement
// ceux de la ville courante -- un maire/adjoint voyait et traitait les demandes des 2 autres
// villes.
async function doTraiterDemandesPermis(pa, cost) {
  if (state.poste?.id !== 'maire_adjoint') { showToast('Réservé au maire adjoint', '', false); return; }

  document.getElementById('postes-modal-title').textContent = 'Demandes de permis à traiter';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const terrainsVille = TERRAINS_PAR_VILLE[state.currentCity] || [];
  const rows = await sbGet('terrains_etat', `country=eq.${encodeURIComponent(state.country)}`).catch(() => []);
  const demandes = [];
  (rows || []).forEach(r => {
    if (!terrainsVille.includes(r.building_id)) return; // filtre par ville
    try {
      const etat = JSON.parse(r.data);
      if (etat.permis?.statut === 'attente_validation') demandes.push({ buildingId: r.building_id, etat });
    } catch(e) {}
  });

  let html = '<div style="padding:1rem">';
  if (demandes.length === 0) {
    html += '<div style="font-size:.8rem;color:#5a5040;font-style:italic">Aucune demande en attente.</div>';
  } else {
    demandes.forEach(d => {
      const zoneOk = typeof palierAutorise === 'function' ? palierAutorise(state.country, state.currentCity, d.etat.permis.palierDemande) : true;
      html += '<div style="border:1px solid #2a2010;padding:.6rem;margin-bottom:.6rem">';
      html += '<div style="font-size:.8rem;color:#c0b090">' + d.etat.permis.demandeur + ' — ' + NIVEAUX_CONSTRUCTION[d.etat.permis.palierDemande].label + '</div>';
      if (!zoneOk) html += '<div style="font-size:.7rem;color:#cc6a44;margin-top:.2rem">⚠ Hors zonage autorisé ici — un refus serait légitime.</div>';
      html += '<div style="display:flex;gap:.4rem;margin-top:.4rem">';
      html += '<button onclick="traiterPermis(\'' + d.buildingId + '\',true,' + pa + ',' + cost + ')" style="flex:1;padding:.35rem;border:1px solid #4a8a4a;background:transparent;color:#6ab858;cursor:pointer;font-size:.7rem">Valider</button>';
      html += '<button onclick="traiterPermis(\'' + d.buildingId + '\',false,' + pa + ',' + cost + ')" style="flex:1;padding:.35rem;border:1px solid #8a4a4a;background:transparent;color:#cc6a44;cursor:pointer;font-size:.7rem">Refuser</button>';
      html += '</div></div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function traiterPermis(buildingId, valide, pa, cost) {
  if (typeof refuserSiGele === 'function' && await refuserSiGele('terrain', buildingId, 'Traiter ce permis')) return;
  const etat = await sbGetTerrainState(state.country, buildingId).catch(() => null);
  if (!etat?.permis) return;
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }

  const zoneOk = typeof palierAutorise === 'function' ? palierAutorise(state.country, state.currentCity, etat.permis.palierDemande) : true;
  etat.permis.statut = valide ? 'valide' : 'refuse';
  etat.permis.refusLegitime = !valide ? zoneOk : null;
  if (valide) etat.constructionAutorisee = true;
  await sbSetTerrainState(state.country, buildingId, etat).catch(() => {});

  const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : '';
  if (typeof sbSendMail === 'function') {
    const msg = valide
      ? 'Votre permis de construire (' + NIVEAUX_CONSTRUCTION[etat.permis.palierDemande].label + ') a été validé. Vous pouvez construire.'
      : 'Votre permis de construire (' + NIVEAUX_CONSTRUCTION[etat.permis.palierDemande].label + ') a été refusé' + (zoneOk ? ' sans motif de zonage — un recours pour obstruction est possible.' : ' (zonage non conforme, refus légitime).');
    await sbSendMail('Mairie', etat.permis.demandeur, valide ? 'Permis validé' : 'Permis refusé', msg, time).catch(() => {});
  }

  document.getElementById('modal-postes')?.classList.remove('open');
  showToast(valide ? 'Permis validé' : 'Permis refusé', '', true, true);
  addJournalEntry((valide ? 'Permis de construire validé' : 'Permis de construire refusé') + ' pour ' + etat.permis.demandeur + '.', valide ? 'event-good' : 'event-bad');
}

async function doPlainteObstruction(pa, cost) {
  const id = state.currentBuilding;
  if (typeof refuserSiGele === 'function' && await refuserSiGele('terrain', id, 'Contester ce refus')) return;
  await chargerTerrainState(id);
  const ts = getTerrainState(id);
  if (!ts.permis || ts.permis.statut !== 'refuse') { showToast('Indisponible', 'Aucun refus de permis à contester ici.', false); return; }
  if (ts.permis.refusLegitime) { showToast('Refus légitime', 'Le zonage justifiait ce refus — pas de recours possible.', false); return; }
  if (ts.permis.plainteDeposee) { showToast('Plainte déjà déposée', '', false); return; }

  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }

  const maireInfoObstruction = await getTitulaireActuel('maire', state.currentCity);
  const maireNom = maireInfoObstruction?.estPJ ? maireInfoObstruction.nom : null;
  if (maireNom && typeof sbGet === 'function') {
    const rows = await sbGet('personnages', `name=eq.${encodeURIComponent(maireNom)}&select=pop,dis`).catch(() => []);
    const pop = rows?.[0]?.pop ?? 50, dis = rows?.[0]?.dis ?? 50;
    await sbUpdate('personnages', `name=eq.${encodeURIComponent(maireNom)}`, {
      pop: Math.max(0, pop - 8), dis: Math.max(0, dis - 10)
    }).catch(() => {});
  }

  ts.permis.plainteDeposee = true;
  await sbSetTerrainState(state.country, id, ts).catch(() => {});

  document.getElementById('modal-postes')?.classList.remove('open');
  showToast('Plainte déposée', 'La justice reconnaît l\'obstruction — le maire en subit les conséquences, mais le permis reste refusé.', true, true);
  addJournalEntry('Plainte pour obstruction déposée contre le maire.', 'event-bad');
  addExternalEvent('⚖️ Le maire est reconnu coupable d\'obstruction à un permis de construire légitime.');
}

async function doCorrompreFonctionnairePermis(pa, cost) {
  const id = state.currentBuilding;
  if (typeof refuserSiGele === 'function' && await refuserSiGele('terrain', id, 'Corrompre le fonctionnaire')) return;
  await chargerTerrainState(id);
  const ts = getTerrainState(id);
  if (!ts.permis || ts.permis.statut !== 'instruction') { showToast('Indisponible', 'Aucune instruction en cours ici.', false); return; }

  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('Fonds insuffisants', cost + ' FR requis.', false); return; }

  const decouvert = Math.random() < 0.25;

  if (decouvert) {
    if (!state.historiqueCrimes) state.historiqueCrimes = [];
    state.historiqueCrimes.push({ acte: 'corruption_fonctionnaire', cible: null, jour: state.day, expireJour: (state.day||1) + 8 });
    updateUI();
    showToast('Corruption découverte !', 'Le fonctionnaire vous dénonce.', false);
    if (typeof procederArrestation === 'function') procederArrestation('corruption_fonctionnaire', false, false);
    return;
  }

  ts.permis.dureeInstruction = Math.max(1, Math.floor(ts.permis.dureeInstruction / 2));
  ts.permis.dateInstructionTerminee = ts.permis.dateDepot + ts.permis.dureeInstruction;
  await sbSetTerrainState(state.country, id, ts).catch(() => {});

  updateUI();
  document.getElementById('modal-postes')?.classList.remove('open');
  showToast('Dossier accéléré', 'Le fonctionnaire a fait remonter votre dossier. Instruction raccourcie.', true, true);
  addJournalEntry('Corruption d\'un fonctionnaire pour accélérer un permis de construire (-' + cost + ' FR).', 'event-bad');
}


// =====================
// SYSTEME FISCAL — caisses de batiment, taxes locale+nationale, salaires politiques
// Republia uniquement pour l'instant. Les autres empires auront leurs propres subtilites
// (ex: prix fixes par decret a Sovarka) a traiter au cas par cas plus tard.
// =====================
const TAUX_TAXE_DEFAUT = 5; // %, local et national

const SALAIRES_POLITIQUES = {
  president: 800, pm: 600, min_int: 500, min_fin: 500, min_just: 500,
  min_def: 500, min_info: 500, min_ae: 500, maire: 400
};

const CAISSE_BATIMENT_POSTE = {
  president: 'palais-presidentiel', pm: 'gouvernement-pm',
  min_int: 'gouvernement-min_int', min_fin: 'gouvernement-min_fin', min_just: 'gouvernement-min_just',
  min_def: 'gouvernement-min_def', min_info: 'gouvernement-min_info', min_ae: 'gouvernement-min_ae',
  maire: 'mairie-capitale'
};

// Part quotidienne de la reserve fiscale (dailyTaxRevenue + taxes accumulees) attribuee a chaque caisse publique
// Chaque poste a sa propre caisse dediee, alimentee par sa part de la repartition nationale (min_fin)
// commissariat/tribunal ajoutes (correctif du 24 aout 2026, audit fiscal) : REPARTITION_DEFAULT
// leur allouait deja 8%/6% mais aucune caisse de destination n'existait ici, donc ces parts
// n'etaient jamais creditees nulle part (calculees puis perdues). mairie souffrait d'un probleme
// distinct mais equivalent une fois verifie (credit systematique de villeFiscale, arbitraire
// selon le declencheur) -- corrige le meme jour, meme mecanisme. Les valeurs ci-dessous
// ('..._capitale'/'mairie-capitale') ne sont plus lues du tout a l'execution pour ces trois
// cles : la part nationale de chacune est desormais repartie sur les 3 villes au prorata de leur
// dailyTaxRevenue (distribuerMontantParVilleAuProrataFiscal, plus bas dans ce fichier),
// strictement independante de villeFiscale/state.currentCity -- gardees ici uniquement pour que
// Object.keys(CAISSE_PAR_POSTE_BUDGET) reste la liste complete et documentee de tous les postes
// de REPARTITION_DEFAULT reellement distribues, la boucle principale les ignorant desormais
// explicitement (continue).
// assemblee/reserve ajoutes (arbitrage utilisateur du 24 aout 2026, apres STOP signale dans
// l'audit) : deux caisses nationales dediees, creees uniquement comme destinations de la
// redistribution fiscale -- aucun ordre de retrait/depense/transfert ni prerogative politique
// n'est ajoute dans ce lot, ni pour l'une ni pour l'autre. 'assemblee' reutilise le vrai
// buildingId de navigation deja existant (BUILDINGS['assemblee'], meme convention que
// 'palais-presidentiel'/'gouvernement-pm' ci-dessus). 'reserve' n'a aucun batiment de
// navigation associe (explicitement demande distinct de budgetNat.reserveJour, qui est un
// accumulateur temporaire remis a 0 chaque jour, pas une reserve) -- 'reserve-nationale' est un
// simple identifiant de caisse (aucune collision verifiee), au meme titre que 'caserne-militaire'
// ou 'qhs-prison' qui ne correspondent pas non plus a un poste nomme.
const CAISSE_PAR_POSTE_BUDGET = {
  presidence: 'palais-presidentiel', pm: 'gouvernement-pm',
  min_int: 'gouvernement-min_int', min_fin: 'gouvernement-min_fin', min_just: 'gouvernement-min_just',
  min_def: 'gouvernement-min_def', min_info: 'gouvernement-min_info', min_ae: 'gouvernement-min_ae', mairie: 'mairie-capitale',
  commissariat: 'commissariat_capitale', tribunal: 'tribunal_capitale',
  assemblee: 'assemblee', reserve: 'reserve-nationale'
};

const COUT_REPARATION_GRILLE = 200; // FR par point regenere
const REGEN_GRILLE_PAR_JOUR = 4; // points vises par jour, plafonne par le budget dispo

// A3 (lot caisses locales, 16 aout 2026) : cette fonction (et Dispensaire/Tribunal ci-dessous)
// n'identifie QUE des caisses (verifie exhaustivement : tous les appelants s'en servent comme
// cle de caisses_batiments -- subvention, financement communal, paiement d'enquete/filature,
// cambriolage, consultation -- jamais comme buildingId de navigation reel). Retournait
// auparavant le meme id pour Port-Sainte-Marie ET Montrouge ('commissariat-local', partage),
// fusionnant leurs deux caisses. Delegue desormais a getCaisseLocaleId, qui distingue chaque
// ville reellement.
function getBuildingIdCommissariat(ville) {
  return getCaisseLocaleId('commissariat', ville);
}

// =====================
// POLICIERS PNJ (lot du 24 aout 2026)
// =====================
// Systeme generique par (pays, ville) -- aucun handler duplique par ville, fonctionne a
// l'identique pour Luthecia/Montrouge/PSM. Persistance dans batiments_etat (deja generique,
// deja documente comme reutilisable pour des mecaniques futures liees a un batiment precis,
// voir supabase.js) sous la cle 'effectifsPolice', propre au VRAI buildingId de navigation du
// commissariat de la ville (distinct de getBuildingIdCommissariat ci-dessus, qui identifie la
// CAISSE, pas la piece).

const COUT_ENTRETIEN_POLICIER_JOUR = 50; // FR/policier/jour, arbitrage valide
const PER_GROUPE_BONUS_PAR_MEMBRE = 1;   // PER groupe = moyenne + (nombre-1), arbitrage valide
const DILUTION_RUE_PER_POLICE = 2;       // malus fixe en rue, arbitrage valide

// buildingId de NAVIGATION du commissariat d'une ville (distinct de la caisse ci-dessus) :
// Luthecia utilise son propre template riche 'commissariat', Montrouge/PSM partagent le
// template pauvre 'commissariat-local' (voir audit dedie, meme buildingId, isolation garantie
// par la ville dans la cle de persistance).
function getBuildingIdCommissariatNavigation(ville) {
  return ville === 'capitale' ? 'commissariat' : 'commissariat-local';
}

async function chargerEffectifsPolice(pays, ville) {
  const buildingId = getBuildingIdCommissariatNavigation(ville);
  const etat = await sbGetBatimentEtat(pays, ville, buildingId).catch(() => ({}));
  return etat?.effectifsPolice || { policiers: [], dernierPaiementJour: null };
}

async function sauvegarderEffectifsPolice(pays, ville, effectifs) {
  const buildingId = getBuildingIdCommissariatNavigation(ville);
  if (typeof sbSetBatimentEtat === 'function') {
    await sbSetBatimentEtat(pays, ville, buildingId, { effectifsPolice: effectifs }).catch(() => {});
  }
}

// Verifie que le PJ courant est bien commissaire ET dans la ville de son propre commissariat
// (jamais celle d'une autre ville visitee en simple deplacement) -- condition testee ici une
// seule fois, reutilisee par tous les ordres de gestion des effectifs.
function commissaireLocalValide() {
  if (state.poste?.id !== 'commissaire') return { ok: false, raison: 'poste' };
  const ville = state.poste.city;
  if (!ville || state.currentCity !== ville) return { ok: false, raison: 'juridiction' };
  return { ok: true, ville };
}

// PER groupe = moyenne PER + (nombre-1). Dilution rue (-2) appliquee separement par l'appelant,
// jamais ici, pour rester reutilisable tel quel dans les deux contextes (piece/rue).
function calculerPerGroupePolice(policiers) {
  if (!policiers || policiers.length === 0) return 0;
  const moyenne = policiers.reduce((s, p) => s + (p.stats?.PER || 0), 0) / policiers.length;
  return moyenne + (policiers.length - 1) * PER_GROUPE_BONUS_PAR_MEMBRE;
}

// VOL groupe = simple moyenne, aucun bonus d'effectif (regle explicite, distincte de PER).
function calculerVolGroupePolice(policiers) {
  if (!policiers || policiers.length === 0) return 0;
  return policiers.reduce((s, p) => s + (p.stats?.VOL || 0), 0) / policiers.length;
}

// ---- RECRUTEMENT ----
async function doRecruterPolicier(pa, cost) {
  const check = commissaireLocalValide();
  if (!check.ok) {
    showToast(check.raison === 'poste' ? 'Réservé au Commissaire' : 'Hors juridiction',
      check.raison === 'juridiction' ? 'Vous ne pouvez recruter que dans le commissariat de votre propre ville.' : '', false);
    return;
  }
  const pays = state.country || 'republic';
  const ville = check.ville;
  const r = await deduireCoutOrdre({ pa, cost: 0 });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }

  const effectifs = await chargerEffectifsPolice(pays, ville);
  const matricule = 'POL-' + ville + '-' + Date.now();
  effectifs.policiers.push({ matricule, type: 'standard', stats: { PER: 12, VOL: 12 }, buildingId: null, roomId: null, rueNoeudId: null, recruteLe: Date.now() });
  await sauvegarderEffectifsPolice(pays, ville, effectifs);

  updateUI();
  showToast('Policier recruté', 'PER 12, VOL 12. Entretien : ' + COUT_ENTRETIEN_POLICIER_JOUR + ' FR/jour prélevés sur la caisse du commissariat.', true, true);
  addJournalEntry('Recrutement d\'un policier (matricule ' + matricule + ').', 'event-good');
}

// Cout journalier reel d'un policier, en fonction de son type -- unite cynophile (maitre-chien +
// chien anti-stupefiants, lot du 25 aout 2026, §8) = 2x le tarif standard, derive de
// COUT_ENTRETIEN_POLICIER_JOUR (jamais un chiffre en dur separe). Meme convention que
// coutJournalierDouanier plus bas dans ce fichier.
function coutJournalierPolicier(agent) {
  return agent?.type === 'cynophile' ? COUT_ENTRETIEN_POLICIER_JOUR * 2 : COUT_ENTRETIEN_POLICIER_JOUR;
}

// ---- UNITE CYNOPHILE POLICE (maitre-chien + chien anti-stupefiants, lot du 25 aout 2026, §8) ----
// Membre a part entiere du groupe police, sous les regles habituelles INCHANGEES
// (calculerPerGroupePolice/calculerVolGroupePolice ne distinguent pas les types -- une unite
// cynophile compte comme un policier normal dans la moyenne du groupe, exactement comme n'importe
// quel autre membre). Seul le cout journalier differe (coutJournalierPolicier). Son bonus
// specialise +3 PER anti-stupefiants n'est PAS cable ici : aucune action policiere existante ne
// consiste reellement a rechercher des stupefiants (verifierSurveillancePolicePJ/
// resoudreControlePoliceAutomatique est un controle d'identite generique qui fouille TOUT objet
// illegal reconnu, pas une recherche ciblee anti-drogue) -- voir rapport final, §B.
async function doRecruterPolicierCynophile(pa, cost) {
  const check = commissaireLocalValide();
  if (!check.ok) {
    showToast(check.raison === 'poste' ? 'Réservé au Commissaire' : 'Hors juridiction',
      check.raison === 'juridiction' ? 'Vous ne pouvez recruter que dans le commissariat de votre propre ville.' : '', false);
    return;
  }
  const pays = state.country || 'republic';
  const ville = check.ville;
  const r = await deduireCoutOrdre({ pa, cost: 0 });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }

  const effectifs = await chargerEffectifsPolice(pays, ville);
  const matricule = 'POL-CYNO-' + ville + '-' + Date.now();
  effectifs.policiers.push({
    matricule, type: 'cynophile',
    maitreNom: 'Maître-chien ' + matricule.slice(-4),
    chienNom: 'Chien ' + matricule.slice(-4),
    stats: { PER: 12, VOL: 12 }, buildingId: null, roomId: null, rueNoeudId: null, recruteLe: Date.now()
  });
  await sauvegarderEffectifsPolice(pays, ville, effectifs);

  updateUI();
  showToast('Unité cynophile recrutée', 'PER 12, VOL 12. Entretien : ' + (COUT_ENTRETIEN_POLICIER_JOUR * 2) + ' FR/jour prélevés sur la caisse du commissariat.', true, true);
  addJournalEntry('Recrutement d\'une unité cynophile de police (matricule ' + matricule + ').', 'event-good');
}

// ---- GESTION / AFFECTATION ----
async function ouvrirGererEffectifsPolice() {
  const check = commissaireLocalValide();
  if (!check.ok) {
    showToast(check.raison === 'poste' ? 'Réservé au Commissaire' : 'Hors juridiction', '', false);
    return;
  }
  const pays = state.country || 'republic';
  const ville = check.ville;
  const effectifs = await chargerEffectifsPolice(pays, ville);

  document.getElementById('postes-modal-title').textContent = 'Gérer mes effectifs';
  let html = '<div style="padding:1rem">';
  if (effectifs.policiers.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060">Aucun policier recruté pour l\'instant.</div>';
  } else {
    effectifs.policiers.forEach(p => {
      let affectation = 'Disponible (au commissariat)';
      if (p.buildingId && p.roomId) affectation = 'Affecté — ' + (BUILDINGS[p.buildingId]?.shortName || p.buildingId) + ' / ' + (resoudreNomRoomAffectation(p.buildingId, p.roomId) || p.roomId);
      else if (p.rueNoeudId) affectation = 'Affecté — rue (' + p.rueNoeudId + ')';
      html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.6rem .7rem;margin-bottom:.5rem">';
      html += '<div style="font-size:.82rem;color:#c0b090;margin-bottom:.3rem">' + p.matricule + ' — PER ' + p.stats.PER + ', VOL ' + p.stats.VOL + (p.type === 'cynophile' ? ' — Unité cynophile (' + p.maitreNom + ' & ' + p.chienNom + ')' : '') + '</div>';
      html += '<div style="font-size:.78rem;color:#8a8060;margin-bottom:.4rem">' + affectation + '</div>';
      html += '<div style="display:flex;gap:.4rem">';
      html += '<button onclick="doOuvrirAffectationRoom(\'' + p.matricule + '\')" style="flex:1;font-size:.72rem;padding:.35rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Affecter (pièce)</button>';
      html += '<button onclick="doOuvrirAffectationRue(\'' + p.matricule + '\')" style="flex:1;font-size:.72rem;padding:.35rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Affecter (rue)</button>';
      if (p.buildingId || p.rueNoeudId) html += '<button onclick="doRappelerPolicier(\'' + p.matricule + '\')" style="flex:1;font-size:.72rem;padding:.35rem;border:1px solid #4a6a8a;background:transparent;color:#5a8ad0;cursor:pointer">Rappeler</button>';
      html += '</div></div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function doOuvrirAffectationRoom(matricule) {
  const check = commissaireLocalValide();
  if (!check.ok) return;
  const pays = state.country || 'republic';
  const ville = check.ville;
  const buildings = (WORLD[pays]?.[ville]?.buildings || []);

  document.getElementById('postes-modal-title').textContent = 'Affecter ' + matricule + ' à une pièce';
  let html = '<div style="padding:1rem">';
  html += '<label style="font-size:.72rem;color:#8a8060;display:block;margin-bottom:.3rem">Bâtiment</label>';
  html += '<select id="affect-building" onchange="majSelectRoomsAffectation()" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-size:.85rem;outline:none;margin-bottom:.6rem">';
  buildings.forEach(bId => { if (BUILDINGS[bId]) html += '<option value="' + bId + '">' + (BUILDINGS[bId].shortName || BUILDINGS[bId].name) + '</option>'; });
  html += '</select>';
  html += '<label style="font-size:.72rem;color:#8a8060;display:block;margin-bottom:.3rem">Pièce</label>';
  html += '<select id="affect-room" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-size:.85rem;outline:none;margin-bottom:.8rem"></select>';
  html += '<button onclick="confirmerAffectationRoom(\'' + matricule + '\')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.55rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Affecter</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
  majSelectRoomsAffectation();
}

// Fusionne BUILDINGS[bId].rooms avec les rooms ajoutees localement via
// buildingContext.roomsExtra (meme resolution que le reste du jeu, voir getBuildingContext
// ci-dessus) -- corrige un picker qui ne listait avant que les rooms du template de base et
// excluait les pieces ajoutees par ville (ex. Encre Marianaise/atelier a PSM).
function resoudreNomRoomAffectation(buildingId, roomId) {
  if (!buildingId || !roomId || !BUILDINGS[buildingId]) return null;
  const roomsExtra = (typeof getBuildingContext === 'function' ? getBuildingContext(buildingId)?.roomsExtra : null) || {};
  const room = BUILDINGS[buildingId].rooms?.[roomId] || roomsExtra[roomId];
  return room?.name || null;
}

function majSelectRoomsAffectation() {
  const bId = document.getElementById('affect-building')?.value;
  const roomSelect = document.getElementById('affect-room');
  if (!roomSelect || !bId || !BUILDINGS[bId]) return;
  const roomsExtra = (typeof getBuildingContext === 'function' ? getBuildingContext(bId)?.roomsExtra : null) || {};
  const rooms = { ...(BUILDINGS[bId].rooms || {}), ...roomsExtra };
  roomSelect.innerHTML = Object.keys(rooms).map(rId => '<option value="' + rId + '">' + (rooms[rId].name || rId) + '</option>').join('');
}

async function confirmerAffectationRoom(matricule) {
  const buildingId = document.getElementById('affect-building')?.value;
  const roomId = document.getElementById('affect-room')?.value;
  document.getElementById('modal-postes')?.classList.remove('open');
  const check = commissaireLocalValide();
  if (!check.ok || !buildingId || !roomId) return;
  const pays = state.country || 'republic';
  const ville = check.ville;
  const effectifs = await chargerEffectifsPolice(pays, ville);
  const p = effectifs.policiers.find(x => x.matricule === matricule);
  if (!p) return;
  p.buildingId = buildingId; p.roomId = roomId; p.rueNoeudId = null;
  await sauvegarderEffectifsPolice(pays, ville, effectifs);
  updateUI();
  showToast('Policier affecté', matricule + ' surveille désormais ' + (resoudreNomRoomAffectation(buildingId, roomId) || roomId) + '.', true, true);
  addJournalEntry('Policier ' + matricule + ' affecté à ' + (BUILDINGS[buildingId]?.shortName || buildingId) + '.', 'event-info');
}

// Prefixes d'id de noeuds de rue par ville (republic uniquement, seul empire couvert par
// RUE_CENTRALE_NOEUDS a ce jour -- voir plateau-rue-centrale.js) -- derives directement de la
// convention de nommage deja en place, aucune nouvelle donnee inventee.
const PREFIXE_RUE_PAR_VILLE = { capitale: 'luthecia-', ville_a: 'psm-', ville_b: 'montrouge-' };

async function doOuvrirAffectationRue(matricule) {
  const check = commissaireLocalValide();
  if (!check.ok) return;
  const ville = check.ville;
  const prefixe = PREFIXE_RUE_PAR_VILLE[ville];
  const noeuds = (typeof RUE_CENTRALE_NOEUDS !== 'undefined' && prefixe)
    ? Object.keys(RUE_CENTRALE_NOEUDS.republic || {}).filter(id => id.startsWith(prefixe))
    : [];

  document.getElementById('postes-modal-title').textContent = 'Affecter ' + matricule + ' à une rue';
  let html = '<div style="padding:1rem">';
  if (noeuds.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060">Aucune vue de rue disponible pour cette ville.</div>';
  } else {
    html += '<select id="affect-rue" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-size:.85rem;outline:none;margin-bottom:.8rem">';
    noeuds.forEach(id => { html += '<option value="' + id + '">' + id + '</option>'; });
    html += '</select>';
    html += '<button onclick="confirmerAffectationRue(\'' + matricule + '\')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.55rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Affecter</button>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerAffectationRue(matricule) {
  const rueNoeudId = document.getElementById('affect-rue')?.value;
  document.getElementById('modal-postes')?.classList.remove('open');
  const check = commissaireLocalValide();
  if (!check.ok || !rueNoeudId) return;
  const pays = state.country || 'republic';
  const ville = check.ville;
  const effectifs = await chargerEffectifsPolice(pays, ville);
  const p = effectifs.policiers.find(x => x.matricule === matricule);
  if (!p) return;
  p.buildingId = null; p.roomId = null; p.rueNoeudId = rueNoeudId;
  await sauvegarderEffectifsPolice(pays, ville, effectifs);
  updateUI();
  showToast('Policier affecté', matricule + ' patrouille désormais cette rue.', true, true);
  addJournalEntry('Policier ' + matricule + ' affecté en patrouille de rue.', 'event-info');
}

async function doRappelerPolicier(matricule) {
  const check = commissaireLocalValide();
  if (!check.ok) return;
  const pays = state.country || 'republic';
  const ville = check.ville;
  const effectifs = await chargerEffectifsPolice(pays, ville);
  const p = effectifs.policiers.find(x => x.matricule === matricule);
  if (!p) return;
  p.buildingId = null; p.roomId = null; p.rueNoeudId = null;
  await sauvegarderEffectifsPolice(pays, ville, effectifs);
  updateUI();
  showToast('Policier rappelé', matricule + ' revient disponible au commissariat.', true, true);
}

// ---- AFFICHAGE DE PRESENCE (piece / rue) ----
// Gabarit directement calque sur getAffichageDetachementPiece (detachements militaires,
// plateau-politique.js) -- structure de retour volontairement minimale (nombre uniquement) :
// ne revele ni PER/VOL effectifs ni calculs internes (regle explicite du lot).
async function getAffichagePolicePiece(pays, ville, buildingId, roomId) {
  const effectifs = await chargerEffectifsPolice(pays, ville);
  const presents = effectifs.policiers.filter(p => p.buildingId === buildingId && p.roomId === roomId);
  if (presents.length === 0) return null;
  return { nombre: presents.length };
}

async function getAffichagePoliceRue(pays, ville, rueNoeudId) {
  const effectifs = await chargerEffectifsPolice(pays, ville);
  const presents = effectifs.policiers.filter(p => p.rueNoeudId === rueNoeudId);
  if (presents.length === 0) return null;
  return { nombre: presents.length };
}

// ---- ENTRETIEN QUOTIDIEN (caisse du commissariat) ----
// Regle de game design validee (arbitrage du 24 aout 2026, remplace l'ancienne convention
// "paiement partiel sans consequence") : un policier qui ne peut pas etre paye quitte son
// emploi et disparait DEFINITIVEMENT de l'effectif persistant -- aucune dette, aucun salaire
// differe, aucun agent maintenu gratuitement, aucune desactivation temporaire. Le nombre
// d'agents effectivement payables est determine par un debit PLAFONNE sur la caisse du
// commissariat (debiterCaisseBatimentPlafonne, meme primitive que precedemment). Depuis l'unite
// cynophile (lot du 25 aout 2026, §8), le cout n'est plus uniforme (coutJournalierPolicier varie
// selon le type) : accumulation gloutonne du plus ancien au plus recent jusqu'a epuisement du
// budget verse, au lieu d'une simple division. Ordre de suppression : l'array effectifs.policiers
// est deja, par construction (doRecruterPolicier/doRecruterPolicierCynophile ne font que .push()),
// classe par ordre de recrutement -- convention deja neutre et deterministe fournie par la
// persistance elle-meme, aucun choix de conception supplementaire necessaire. Les derniers
// recrutes (fin de tableau) sont ceux qui partent en premier faute de budget ; leur affectation
// (buildingId/roomId/rueNoeudId) disparait naturellement avec eux puisque l'objet entier est
// retire du tableau.
async function payerEffectifsPoliceQuotidien(pays, ville) {
  const effectifs = await chargerEffectifsPolice(pays, ville);
  if (!effectifs.policiers.length) return;
  const jour = state.day || 1;
  if (effectifs.dernierPaiementJour === jour) return; // deja paye aujourd'hui (garde-fou multi-connexion)

  const buildingIdCaisse = getBuildingIdCommissariat(ville);
  const coutTotal = effectifs.policiers.reduce((s, p) => s + coutJournalierPolicier(p), 0);
  const montantVerse = await debiterCaisseBatimentPlafonne(pays, buildingIdCaisse, coutTotal);

  effectifs.dernierPaiementJour = jour;
  let nbPartis = 0;
  if (montantVerse < coutTotal) {
    let cumul = 0, nbGardes = 0;
    for (let i = 0; i < effectifs.policiers.length; i++) {
      const c = coutJournalierPolicier(effectifs.policiers[i]);
      if (cumul + c > montantVerse) break;
      cumul += c;
      nbGardes++;
    }
    nbPartis = effectifs.policiers.length - nbGardes;
    effectifs.policiers = effectifs.policiers.slice(0, nbGardes);
  }
  await sauvegarderEffectifsPolice(pays, ville, effectifs);

  if (nbPartis > 0 && typeof addJournalEntry === 'function' && state.currentCity === ville) {
    showToast('Effectifs réduits', nbPartis + ' policier(s) n\'ont pas pu être payés et ont quitté le commissariat.', false, true);
    addJournalEntry(nbPartis + ' policier(s) de ' + ville + ' quittent le service faute de paiement (caisse insuffisante).', 'event-bad');
  }
}

// =====================
// DOUANIERS PNJ — SERVICE DES DOUANES DU PORT (lot du 24 aout 2026)
// =====================
// Reutilise l'architecture des policiers PNJ (persistance batiments_etat, fiche
// {matricule,stats,...}, calcul de groupe calculerPerGroupePolice/calculerVolGroupePolice --
// deja generiques, reutilises tels quels ci-dessous sans duplication) SANS le systeme de
// patrouille de rue : les douaniers ne controlent pas les passants, ils constituent l'effectif
// fixe du service des douanes du port, rattache en dur a port-sainte-marie/douanes (aucune
// affectation a choisir, contrairement aux policiers qui peuvent etre positionnes dans
// n'importe quelle piece/rue de leur ville). Un seul port existe dans tout le jeu -- pas de
// scope ville a verifier, contrairement a commissaireLocalValide().
//
// Effectif PNJ initial et salaire : arbitrage valide le 24 aout 2026 (4 douaniers, 50 FR/jour/
// douanier -- meme tarif que les policiers, mais debite sur gouvernement-min_int, aucune caisse
// propre aux douanes). Ville 'ville_a' = Port-Sainte-Marie (seule ville dotee d'un port, cf.
// data.js CITIES.ville_a.buildings qui liste 'port-sainte-marie').
const BUILDING_ID_PORT = 'port-sainte-marie';
const ROOM_ID_DOUANES = 'douanes';
const VILLE_ID_PORT = 'ville_a';
const EFFECTIF_DOUANE_INITIAL = 4;
const COUT_ENTRETIEN_DOUANIER_JOUR = 50; // FR/douanier/jour, arbitrage valide -- debite sur gouvernement-min_int

function creerDouanierPnjInitial(numero) {
  return { matricule: 'DOU-PNJ-' + numero, type: 'standard', stats: { PER: 12, VOL: 12 }, buildingId: BUILDING_ID_PORT, roomId: ROOM_ID_DOUANES, recruteLe: Date.now() };
}

// Cout journalier reel d'un agent des douanes, en fonction de son type -- unite cynophile
// (maitre-chien + chien anti-stupefiants, lot du 25 aout 2026, §6-7) = 2x le tarif standard,
// derive de COUT_ENTRETIEN_DOUANIER_JOUR (jamais un chiffre en dur separe). Utilise par le
// recrutement ET par la paye quotidienne (payerEffectifsDouaneQuotidien plus bas).
function coutJournalierDouanier(agent) {
  return agent?.type === 'cynophile' ? COUT_ENTRETIEN_DOUANIER_JOUR * 2 : COUT_ENTRETIEN_DOUANIER_JOUR;
}

// Initialise l'effectif PNJ de depart (4 douaniers, arbitrage valide) UNE SEULE FOIS, seulement
// si effectifsDouane n'a jamais ete persiste (etat.effectifsDouane === undefined). Une fois
// persiste -- meme reduit a 0 par la suite (licenciement/impayes) -- ce chemin ne se redeclenche
// plus jamais : l'effectif n'est JAMAIS reconstitue automatiquement a 4.
async function chargerEffectifsDouane(pays) {
  const etat = await sbGetBatimentEtat(pays, VILLE_ID_PORT, BUILDING_ID_PORT).catch(() => ({}));
  if (etat && etat.effectifsDouane) return etat.effectifsDouane;
  const numeros = Array.from({ length: EFFECTIF_DOUANE_INITIAL }, (_, i) => i + 1);
  const effectifsInitiaux = { douaniers: numeros.map(creerDouanierPnjInitial), dernierPaiementJour: null };
  await sauvegarderEffectifsDouane(pays, effectifsInitiaux);
  return effectifsInitiaux;
}

async function sauvegarderEffectifsDouane(pays, effectifs) {
  if (typeof sbSetBatimentEtat === 'function') {
    await sbSetBatimentEtat(pays, VILLE_ID_PORT, BUILDING_ID_PORT, { effectifsDouane: effectifs }).catch(() => {});
  }
}

// Verifie que le PJ courant occupe bien le poste national de Chef des Douanes.
function chefDouanesValide() {
  return state.poste?.id === 'chef_douanes' ? { ok: true } : { ok: false };
}

// ---- RECRUTEMENT ----
// Memes stats de depart que les policiers (PER 12, VOL 12) -- precedent direct, pas invente.
// Affectation FIXE a port-sainte-marie/douanes des la creation : aucune etape de choix,
// contrairement a doRecruterPolicier (les douaniers ne patrouillent jamais ailleurs).
async function doRecruterDouanier(pa, cost) {
  const check = chefDouanesValide();
  if (!check.ok) { showToast('Réservé au Chef des Douanes', '', false); return; }
  const pays = state.country || 'republic';
  const r = await deduireCoutOrdre({ pa, cost: 0 });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }

  const effectifs = await chargerEffectifsDouane(pays);
  const matricule = 'DOU-' + Date.now();
  effectifs.douaniers.push({ matricule, type: 'standard', stats: { PER: 12, VOL: 12 }, buildingId: BUILDING_ID_PORT, roomId: ROOM_ID_DOUANES, recruteLe: Date.now() });
  await sauvegarderEffectifsDouane(pays, effectifs);

  updateUI();
  showToast('Douanier recruté', 'PER 12, VOL 12. Rattaché au service des douanes du port. Payé directement par le Ministère de l\'Intérieur.', true, true);
  addJournalEntry('Recrutement d\'un douanier (matricule ' + matricule + ').', 'event-good');
}

// ---- UNITE CYNOPHILE (maitre-chien + chien anti-stupefiants, lot du 25 aout 2026, §6-7) ----
// Membre a part entiere de l'effectif standard (compte dans le nombre de douaniers pour
// PER_SERVICE_DOUANES, +1 comme n'importe quel agent) -- distingue seulement par son
// type:'cynophile', jamais par son nom (identite generique, non fonctionnelle : maitreNom/
// chienNom sont de simples champs d'affichage). Cout double (2x COUT_ENTRETIEN_DOUANIER_JOUR),
// bonus specialise (+3 PER_SERVICE_DOUANES si la caisse controlee contient reellement des
// stupefiants) applique uniquement au moment de la resolution du controle (doControlerCaisseFret,
// plus bas), jamais ici au recrutement.
async function doRecruterDouanierCynophile(pa, cost) {
  const check = chefDouanesValide();
  if (!check.ok) { showToast('Réservé au Chef des Douanes', '', false); return; }
  const pays = state.country || 'republic';
  const r = await deduireCoutOrdre({ pa, cost: 0 });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }

  const effectifs = await chargerEffectifsDouane(pays);
  const matricule = 'DOU-CYNO-' + Date.now();
  effectifs.douaniers.push({
    matricule, type: 'cynophile',
    maitreNom: 'Maître-chien ' + matricule.slice(-4),
    chienNom: 'Chien ' + matricule.slice(-4),
    stats: { PER: 12, VOL: 12 },
    buildingId: BUILDING_ID_PORT, roomId: ROOM_ID_DOUANES, recruteLe: Date.now()
  });
  await sauvegarderEffectifsDouane(pays, effectifs);

  updateUI();
  showToast('Unité cynophile recrutée', 'Rattachée au service des douanes du port (' + (COUT_ENTRETIEN_DOUANIER_JOUR * 2) + ' FR/jour). Payée directement par le Ministère de l\'Intérieur.', true, true);
  addJournalEntry('Recrutement d\'une unité cynophile (matricule ' + matricule + ').', 'event-good');
}

// ---- GESTION (Chef des Douanes uniquement — garde UI via requiresPost dans data.js + garde
// handler independante chefDouanesValide() ci-dessous) ----
// Regroupe recrutement + licenciement dans un seul ecran (lot du 25 aout 2026, §11). Pas
// d'affectation room/rue a choisir (contrairement a ouvrirGererEffectifsPolice) : les douaniers
// sont toujours au port, rien a reaffecter ni a rappeler. Licenciement gratuit (0 PA), meme
// convention que licencierPnj (plateau-multijoueur.js) : une action de gestion a l'interieur d'un
// panneau deja verrouille par le PA de l'order qui l'ouvre (ici 0, comme gerer_effectifs_douane
// l'a toujours ete), pas une nouvelle depense.
async function ouvrirGererEffectifsDouane() {
  const check = chefDouanesValide();
  if (!check.ok) { showToast('Réservé au Chef des Douanes', '', false); return; }
  const pays = state.country || 'republic';
  const effectifs = await chargerEffectifsDouane(pays);

  document.getElementById('postes-modal-title').textContent = 'Gérer les effectifs douaniers';
  let html = '<div style="padding:1rem">';
  html += '<button onclick="doRecruterDouanier(1,0)" style="display:block;width:100%;text-align:center;padding:.55rem;border:1px solid #6a5a20;background:#1a1508;color:#e0c060;cursor:pointer;font-family:Bebas Neue,sans-serif;letter-spacing:.08em;font-size:.8rem;margin-bottom:.5rem">RECRUTER UN DOUANIER (1 PA · ' + COUT_ENTRETIEN_DOUANIER_JOUR + ' FR/jour)</button>';
  html += '<button onclick="doRecruterDouanierCynophile(1,0)" style="display:block;width:100%;text-align:center;padding:.55rem;border:1px solid #6a5a20;background:#1a1508;color:#e0c060;cursor:pointer;font-family:Bebas Neue,sans-serif;letter-spacing:.08em;font-size:.8rem;margin-bottom:.8rem">RECRUTER UNE UNITÉ CYNOPHILE (1 PA · ' + (COUT_ENTRETIEN_DOUANIER_JOUR * 2) + ' FR/jour)</button>';
  if (effectifs.douaniers.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060">Aucun douanier recruté pour l\'instant.</div>';
  } else {
    effectifs.douaniers.forEach(d => {
      const estCynophile = d.type === 'cynophile';
      html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.6rem .7rem;margin-bottom:.5rem">';
      if (estCynophile) {
        html += '<div style="font-size:.82rem;color:#c0b090">' + d.matricule + ' — Unité cynophile (' + d.maitreNom + ' &amp; ' + d.chienNom + ')</div>';
        html += '<div style="font-size:.78rem;color:#8a8060;margin-bottom:.4rem">Rattachée au service des douanes du port — ' + (COUT_ENTRETIEN_DOUANIER_JOUR * 2) + ' FR/jour</div>';
      } else {
        html += '<div style="font-size:.82rem;color:#c0b090">' + d.matricule + ' — PER ' + d.stats.PER + ', VOL ' + d.stats.VOL + '</div>';
        html += '<div style="font-size:.78rem;color:#8a8060;margin-bottom:.4rem">Rattaché au service des douanes du port — ' + COUT_ENTRETIEN_DOUANIER_JOUR + ' FR/jour</div>';
      }
      html += '<button onclick="doLicencierDouanier(\'' + d.matricule + '\')" style="width:100%;font-size:.72rem;padding:.35rem;border:1px solid #8a3a2a;background:transparent;color:#8a3a2a;cursor:pointer">Licencier</button>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function doLicencierDouanier(matricule) {
  const check = chefDouanesValide();
  if (!check.ok) { showToast('Réservé au Chef des Douanes', '', false); return; }
  const pays = state.country || 'republic';
  const effectifs = await chargerEffectifsDouane(pays);
  const idx = effectifs.douaniers.findIndex(d => d.matricule === matricule);
  if (idx < 0) return;
  effectifs.douaniers.splice(idx, 1);
  await sauvegarderEffectifsDouane(pays, effectifs);
  showToast('Douanier licencié', matricule + ' quitte le service des douanes.', true);
  addJournalEntry('Licenciement du douanier ' + matricule + '.', 'event-info');
  ouvrirGererEffectifsDouane();
}

// ---- CONSULTATION PUBLIQUE (visible/accessible a tout PJ, 0 PA/0 FR — n'affiche jamais PER/VOL,
// info non administrative, seul le Chef des Douanes les voit dans ouvrirGererEffectifsDouane
// ci-dessus) ----
async function ouvrirConsulterEffectifsDouane() {
  const pays = state.country || 'republic';
  const effectifs = await chargerEffectifsDouane(pays);

  document.getElementById('postes-modal-title').textContent = 'Effectifs des douanes';
  let html = '<div style="padding:1rem">';
  if (effectifs.douaniers.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060">Aucun douanier en service pour l\'instant.</div>';
  } else {
    html += '<div style="font-size:.8rem;color:#c0b090;margin-bottom:.6rem">' + effectifs.douaniers.length + ' douanier(s) en service, rattachés au service des douanes du port.</div>';
    effectifs.douaniers.forEach(d => {
      const label = d.type === 'cynophile' ? (d.matricule + ' — Unité cynophile (' + d.maitreNom + ' & ' + d.chienNom + ')') : d.matricule;
      html += '<div style="font-size:.8rem;color:#8a8060;margin-bottom:.2rem">' + label + '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// ---- ENTRETIEN QUOTIDIEN ----
// Reprend a l'identique le comportement de payerEffectifsPoliceQuotidien : debit plafonne sur la
// caisse reelle (ici gouvernement-min_int -- aucune caisse propre aux douanes), aucun decouvert
// possible, les derniers recrutes (fin de tableau, ordre deterministe de creation/recrutement)
// partent en premier faute de budget. Depuis l'unite cynophile (lot du 25 aout 2026, §6-7), le
// cout n'est plus uniforme (coutJournalierDouanier varie selon le type) : accumulation gloutonne
// du plus ancien au plus recent jusqu'a epuisement du budget verse, au lieu d'une simple division.
// Service national unique (un seul port dans tout le jeu), donc pas de parametre ville
// contrairement a la police -- appele une seule fois par jour et par pays, quelle que soit la
// ville ou se trouve le joueur qui declenche doDormir().
async function payerEffectifsDouaneQuotidien(pays) {
  const effectifs = await chargerEffectifsDouane(pays);
  if (!effectifs.douaniers.length) return;
  const jour = state.day || 1;
  if (effectifs.dernierPaiementJour === jour) return; // deja paye aujourd'hui (garde-fou multi-connexion)

  const coutTotal = effectifs.douaniers.reduce((s, d) => s + coutJournalierDouanier(d), 0);
  const montantVerse = await debiterCaisseBatimentPlafonne(pays, 'gouvernement-min_int', coutTotal);

  effectifs.dernierPaiementJour = jour;
  let nbPartis = 0;
  if (montantVerse < coutTotal) {
    let cumul = 0, nbGardes = 0;
    for (let i = 0; i < effectifs.douaniers.length; i++) {
      const c = coutJournalierDouanier(effectifs.douaniers[i]);
      if (cumul + c > montantVerse) break;
      cumul += c;
      nbGardes++;
    }
    nbPartis = effectifs.douaniers.length - nbGardes;
    effectifs.douaniers = effectifs.douaniers.slice(0, nbGardes);
  }
  await sauvegarderEffectifsDouane(pays, effectifs);

  if (nbPartis > 0 && typeof addJournalEntry === 'function' && state.currentCity === VILLE_ID_PORT) {
    showToast('Effectifs réduits', nbPartis + ' douanier(s) n\'ont pas pu être payés et ont quitté le service.', false, true);
    addJournalEntry(nbPartis + ' douanier(s) du port quittent le service faute de paiement (caisse du Ministère de l\'Intérieur insuffisante).', 'event-bad');
  }
}

// =====================
// PORT INDUSTRIEL — LOGISTIQUE NATIONALE (lot du 25 aout 2026)
// =====================
// Stock institutionnel du port (etat.port, meme cle batiments_etat que effectifsDouane
// ci-dessus -- reutilise BUILDING_ID_PORT/VILLE_ID_PORT plutot que d'en redeclarer). Alimente
// uniquement par le cron quotidien (livrerEntrepotsQuotidien / traiterExportationsPortQuotidien,
// api/cron-minuit.js -- duplique cote serveur, jamais partage avec le client, meme convention que
// le reste du fichier cron). Ce layer client ne fait que LIRE l'etat et laisser le Commandant
// reparametrer repartition[cle] par pourcentages ; le calcul de distribution reel (arrondi
// Hamilton, jamais plus que le stock disponible, reliquat conserve) reste entierement cote cron.
// Concurrence (§18 du lot) : sbSetBatimentEtat fusionne au niveau du top-level du blob seulement
// (voir sa definition, supabase.js) -- toute ecriture de repartition[] doit donc reecrire l'objet
// port entier tel que relu a l'instant T, exactement comme le fait deja le cron. Le seul risque
// residuel est une nomination/modification de repartition qui tomberait pile au meme instant que
// le passage du cron (minuit) ; non traite ici (pas de nouvelle primitive atomique sans
// validation), risque juge marginal et identique a celui deja accepte ailleurs dans le blob.
const RESSOURCES_PORT_IMPORTEES = ['bois', 'petrole', 'produits_exotiques'];
// Ressources vendables a la Criee (regle fonctionnelle validee le 25 aout 2026, §7-8 du lot
// entrepot/fret/criee) : la Criee de PSM est une criee AUX POISSONS, elle ne vend jamais les
// matieres premieres internationales (bois/petrole/produits exotiques) au detail -- celles-ci
// restent gerees uniquement via la repartition nationale du Commandant (RESSOURCES_PORT_
// IMPORTEES, administration du port/manifeste). Le poisson n'a pas d'origine etrangere
// (ORIGINE_IMPORTS_PORT/RESSOURCES_REROUTEES_PORT, api/cron-minuit.js, inchanges) : il arrive
// directement dans port.criee.stock via l'arrivage de peche quotidien dedie
// (genererArrivagePoissonCriee, api/cron-minuit.js, v72 -- 40 a 80 unites/jour, plafond 125).
const RESSOURCES_CRIEE_VENDABLES = ['poisson'];
const EXPORTATIONS_PORT_INFOS = {
  cereales: { label: 'Céréales', destination: 'Al-Khalija' },
  viande:   { label: 'Viande',   destination: 'Al-Khalija' }
};
const ENTREPOTS_PORT_INFOS = [
  { city: 'capitale', buildingId: 'entrepot-logistique-luthecia',  nom: 'Luthécia' },
  { city: 'ville_a',  buildingId: 'entrepot-logistique-psm',       nom: 'Port-Sainte-Marie' },
  { city: 'ville_b',  buildingId: 'entrepot-logistique-montrouge', nom: 'Montrouge' }
];
const REPARTITION_PORT_DEFAUT = { capitale: 100 / 3, ville_a: 100 / 3, ville_b: 100 / 3 };

async function getEtatPort() {
  const etat = await sbGetBatimentEtat('republic', VILLE_ID_PORT, BUILDING_ID_PORT).catch(() => ({}));
  return (etat && etat.port) || { stock: {}, repartition: {}, arrivages: [], exportations: {} };
}

// Verifie que le PJ courant occupe bien le poste national de Commandant du Port.
function commandantPortValide() {
  return state.poste?.id === 'capitaine_port' ? { ok: true } : { ok: false };
}

function arrondiPct(v) { return Math.round((v || 0) * 100) / 100; }

// ---- CONSULTATION (visible/utilisable par tout visiteur de administration_portuaire, lecture
// seule -- seule la modification de repartition ci-dessous est reservee au Commandant, pattern
// "visible mais bloque" applique a l'interieur meme du panneau plutot qu'a l'order lui-meme,
// puisque la consultation elle-meme doit rester ouverte a tous, §4 du lot) ----
async function ouvrirConsulterPort() {
  const port = await getEtatPort();
  const estCommandant = commandantPortValide().ok;

  document.getElementById('postes-modal-title').textContent = 'Administration du Port';
  let html = '<div style="padding:1rem;max-height:70vh;overflow-y:auto">';

  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">STOCK INSTITUTIONNEL DU PORT</div>';
  const clesStock = RESSOURCES_PORT_IMPORTEES.filter(cle => (port.stock?.[cle] || 0) > 0);
  if (clesStock.length === 0) {
    html += '<div style="font-size:.8rem;color:#8a8060;margin-bottom:.7rem">Aucun stock en attente de répartition.</div>';
  } else {
    clesStock.forEach(cle => {
      const res = RESSOURCES_ECONOMIE[cle];
      html += '<div style="font-size:.8rem;color:#c0b090">' + (res?.label || cle) + ' : ' + Math.round(port.stock[cle]) + '</div>';
    });
    html += '<div style="margin-bottom:.7rem"></div>';
  }

  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">ORIGINE DES MATIÈRES</div>';
  html += '<div style="font-size:.78rem;color:#8a8060;margin-bottom:.7rem">Bois : 50% Républia (direct), 50% Sovarka (via le port) — Pétrole brut : 2/3 Al-Khalija, 1/3 Sovarka — Produits exotiques : 100% El Estado.</div>';

  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">RÉPARTITION NATIONALE ACTUELLE</div>';
  RESSOURCES_PORT_IMPORTEES.forEach(cle => {
    const res = RESSOURCES_ECONOMIE[cle];
    const rep = port.repartition?.[cle] || REPARTITION_PORT_DEFAUT;
    html += '<div style="font-size:.8rem;color:#c0b090;margin-bottom:.2rem">' + (res?.label || cle) + ' — Luthécia ' + arrondiPct(rep.capitale) + '% / Port-Sainte-Marie ' + arrondiPct(rep.ville_a) + '% / Montrouge ' + arrondiPct(rep.ville_b) + '%</div>';
  });
  html += '<div style="margin-bottom:.5rem"></div>';

  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin:.7rem 0 .4rem">ARRIVAGES RÉCENTS</div>';
  const arrivages = (port.arrivages || []).slice(0, 10);
  if (arrivages.length === 0) {
    html += '<div style="font-size:.76rem;color:#8a8060;margin-bottom:.5rem">Aucun arrivage enregistré pour l\'instant.</div>';
  } else {
    arrivages.forEach(a => {
      const res = RESSOURCES_ECONOMIE[a.resource];
      const date = new Date(a.jour);
      html += '<div style="font-size:.76rem;color:#8a8060">' + date.toLocaleDateString('fr-FR') + ' — ' + (res?.label || a.resource) + ' : +' + Math.round(a.qte) + '</div>';
    });
  }

  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin:.7rem 0 .4rem">EXPORTATIONS</div>';
  Object.entries(EXPORTATIONS_PORT_INFOS).forEach(([cle, infos]) => {
    const exp = port.exportations?.[cle];
    if (!exp) { html += '<div style="font-size:.76rem;color:#8a8060">' + infos.label + ' vers ' + infos.destination + ' : aucune donnée pour l\'instant.</div>'; return; }
    html += '<div style="font-size:.8rem;color:#c0b090">' + infos.label + ' vers ' + infos.destination + ' : ' + Math.round(exp.envoye) + '/' + exp.contrat + ' (' + exp.satisfactionPct + '% satisfait)</div>';
  });

  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin:.7rem 0 .4rem">STOCKS DES ENTREPÔTS</div>';
  for (const v of ENTREPOTS_PORT_INFOS) {
    const etatE = await sbGetBatimentEtat('republic', v.city, v.buildingId).catch(() => null);
    const stock = etatE?.entrepot?.stock || {};
    html += '<div style="font-size:.78rem;color:#8a8060;margin-bottom:.2rem">' + v.nom + ' : ' + RESSOURCES_PORT_IMPORTEES.map(cle => (RESSOURCES_ECONOMIE[cle]?.label || cle) + ' ' + Math.round(stock[cle] || 0)).join(', ') + '</div>';
  }

  const caissePort = await chargerCaisseBatiment('republic', BUILDING_ID_PORT).catch(() => ({ solde: 0 }));
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin:.7rem 0 .4rem">CAISSE DU PORT</div>';
  html += '<div style="font-size:.8rem;color:#c0b090;margin-bottom:.7rem">' + Math.round(caissePort.solde || 0) + ' FR</div>';

  // Correctif UX (25 aout 2026, apres retour de test) : le bouton de modification n'est plus
  // duplique ici -- il vit desormais dans son propre order de salle, "Gérer la logistique
  // nationale" (requiresPost:'capitaine_port', data.js), visible mais grise pour les non-
  // Commandant selon la meme convention que gerer_effectifs_douane/blocus_portuaire, alors que
  // ce panneau de consultation reste volontairement neutre (accessible a tous, aucune action).
  // ouvrirModifierRepartitionPort()/confirmerModifierRepartitionPort() ne sont pas dupliquees :
  // c'est le nouvel order qui les appelle directement (plateau-router.js).
  html += '<div style="margin-top:.5rem;font-size:.76rem;color:#6a5a30;font-style:italic">' +
    (estCommandant
      ? 'Utilisez « Gérer la logistique nationale » (visible dans cette salle) pour modifier la répartition.'
      : 'Seul le Commandant du Port peut modifier la répartition, via « Gérer la logistique nationale ».') +
    '</div>';

  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// ---- MODIFICATION DE LA RÉPARTITION (Commandant uniquement — garde UI + garde handler
// independantes, la garde UI n'etant qu'un confort puisque le bouton n'est deja affiche qu'au
// Commandant ci-dessus) ----
function ouvrirModifierRepartitionPort() {
  const check = commandantPortValide();
  if (!check.ok) { showToast('Réservé au Commandant du Port', '', false); return; }

  document.getElementById('postes-modal-title').textContent = 'Modifier la répartition — choisir la matière';
  let html = '<div style="padding:1rem">';
  RESSOURCES_PORT_IMPORTEES.forEach(cle => {
    const res = RESSOURCES_ECONOMIE[cle];
    html += '<button onclick="ouvrirFormulaireRepartitionPort(\'' + cle + '\')" style="display:block;width:100%;text-align:left;padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;color:#c0b090;cursor:pointer;font-family:Crimson Pro,serif;font-size:.85rem;margin-bottom:.4rem">' + (res?.label || cle) + '</button>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function ouvrirFormulaireRepartitionPort(cle) {
  const check = commandantPortValide();
  if (!check.ok) { showToast('Réservé au Commandant du Port', '', false); return; }
  const port = await getEtatPort();
  const rep = port.repartition?.[cle] || REPARTITION_PORT_DEFAUT;
  const res = RESSOURCES_ECONOMIE[cle];

  document.getElementById('postes-modal-title').textContent = 'Répartition — ' + (res?.label || cle);
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Pourcentages à répartir entre les 3 villes. La somme doit faire 100.</div>';
  html += '<label style="display:block;font-size:.8rem;color:#c0b090;margin-bottom:.2rem">Luthécia (%)</label>';
  html += '<input type="number" id="rep-port-capitale" value="' + arrondiPct(rep.capitale) + '" min="0" max="100" step="0.01" style="width:100%;padding:.4rem;margin-bottom:.6rem;background:#0f0d05;border:1px solid #2a2010;color:#e0d0a0">';
  html += '<label style="display:block;font-size:.8rem;color:#c0b090;margin-bottom:.2rem">Port-Sainte-Marie (%)</label>';
  html += '<input type="number" id="rep-port-ville_a" value="' + arrondiPct(rep.ville_a) + '" min="0" max="100" step="0.01" style="width:100%;padding:.4rem;margin-bottom:.6rem;background:#0f0d05;border:1px solid #2a2010;color:#e0d0a0">';
  html += '<label style="display:block;font-size:.8rem;color:#c0b090;margin-bottom:.2rem">Montrouge (%)</label>';
  html += '<input type="number" id="rep-port-ville_b" value="' + arrondiPct(rep.ville_b) + '" min="0" max="100" step="0.01" style="width:100%;padding:.4rem;margin-bottom:.8rem;background:#0f0d05;border:1px solid #2a2010;color:#e0d0a0">';
  html += '<button onclick="confirmerModifierRepartitionPort(\'' + cle + '\')" style="display:block;width:100%;text-align:center;padding:.6rem;border:1px solid #6a5a20;background:#1a1508;color:#e0c060;cursor:pointer;font-family:Bebas Neue,sans-serif;letter-spacing:.08em;font-size:.85rem">VALIDER (1 PA)</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function confirmerModifierRepartitionPort(cle) {
  const check = commandantPortValide();
  if (!check.ok) { showToast('Réservé au Commandant du Port', '', false); return; }
  const capitale = parseFloat(document.getElementById('rep-port-capitale')?.value);
  const ville_a  = parseFloat(document.getElementById('rep-port-ville_a')?.value);
  const ville_b  = parseFloat(document.getElementById('rep-port-ville_b')?.value);
  if (![capitale, ville_a, ville_b].every(v => Number.isFinite(v) && v >= 0)) {
    showToast('Valeurs invalides', '', false);
    return;
  }
  const somme = capitale + ville_a + ville_b;
  if (Math.abs(somme - 100) > 0.1) {
    showToast('La somme doit faire 100%', 'Actuellement : ' + Math.round(somme * 100) / 100 + '%', false);
    return;
  }
  // 1 PA, meme cout que les autres ordres d'allocation deja valides du jeu (fixer_repartition_
  // production, fixer_prix_achat_entrepot, fixer_prix_vente_directe) -- reutilise plutot
  // qu'invente, la consultation elle-meme (consulter_administration_port) restant gratuite.
  const r = await deduireCoutOrdre({ pa: 1, cost: 0 });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }

  const etat = await sbGetBatimentEtat('republic', VILLE_ID_PORT, BUILDING_ID_PORT).catch(() => ({}));
  const port = (etat && etat.port) || { stock: {}, repartition: {}, arrivages: [], exportations: {} };
  const repartition = { ...(port.repartition || {}), [cle]: { capitale, ville_a, ville_b } };
  await sbSetBatimentEtat('republic', VILLE_ID_PORT, BUILDING_ID_PORT, { ...(etat || {}), port: { ...port, repartition } }).catch(() => {});

  document.getElementById('modal-postes')?.classList.remove('open');
  const res = RESSOURCES_ECONOMIE[cle];
  showToast('Répartition mise à jour', (res?.label || cle) + ' : Luthécia ' + capitale + '% / Port-Sainte-Marie ' + ville_a + '% / Montrouge ' + ville_b + '%', true, true);
  addJournalEntry('Le Commandant du Port modifie la répartition de ' + (res?.label || cle).toLowerCase() + '.', 'event-info');
}

// ---- VENTE A LA CRIÉE (tout PJ — achat reel du poisson issu de l'arrivage quotidien dedie de
// la Criee, v72 : capacite d'inventaire verifiee, stock reellement decremente, FR reellement
// debites du PJ et credites dans la caisse du port (republic_port-sainte-marie). Jamais de stock
// cree au clic. Meme moteur que confirmerAchatEntrepot (double passe : verification puis
// application au prorata de ce que l'inventaire peut reellement absorber).
//
// "Affecter du stock à la Criée" (Commandant, transfert port.stock -> port.criee.stock) retiree
// le 25 aout 2026 : reliquat de la 1ere implementation v71, devenu incoherent depuis que la
// Criee a son propre arrivage de poisson independant (v72, genererArrivagePoissonCriee,
// api/cron-minuit.js) -- une criee aux poissons ne doit pas vendre du bois/petrole/produits
// exotiques au detail. Le Commandant continue de piloter la repartition nationale des
// importations (ouvrirModifierRepartitionPort, inchange), mais n'alimente plus la Criee.
// RESSOURCES_PORT_IMPORTEES reste utilisee ailleurs (administration du port, manifeste) pour ces
// memes 3 matieres -- seule la vente au detail de la Criee en est desormais exclue. ----
async function ouvrirAcheterCriee(pa, cost) {
  const port = await getEtatPort();
  const stock = port.criee?.stock || {};
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  let html = '<div style="padding:1.2rem">';
  const clesDispo = RESSOURCES_CRIEE_VENDABLES.filter(cle => (stock[cle] || 0) > 0);
  if (clesDispo.length === 0) {
    html += '<div style="font-size:.9rem;color:#8a8060">Aucune marchandise en vente à la Criée pour l\'instant.</div>';
  } else {
    html += '<div style="font-size:.9rem;color:#8a8060;margin-bottom:1rem">Poisson pêché quotidiennement, vendu directement aux joueurs.</div>';
    html += '<table style="width:100%;font-size:1rem;border-collapse:collapse">';
    html += '<tr style="color:#8a6a20;font-family:Bebas Neue,sans-serif;font-size:.9rem;letter-spacing:.05em;text-align:left"><th style="padding:.3rem 0">Produit</th><th>Stock</th><th>Prix</th><th>Quantité</th></tr>';
    clesDispo.forEach(cle => {
      const res = RESSOURCES_ECONOMIE[cle];
      const enStock = Math.round(stock[cle]);
      const prix = getPrixRessourceEntrepot(cle);
      html += '<tr style="border-top:1px solid #2a2010">';
      html += '<td style="padding:.5rem 0">' + res.label + '</td>';
      html += '<td style="color:#8a8060">' + enStock + '</td>';
      html += '<td style="color:#C9A84C;font-weight:bold">' + prix + ' ' + cur + '</td>';
      html += '<td><input type="number" min="0" max="' + enStock + '" id="achat-criee-' + cle + '" style="width:90px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem" /></td>';
      html += '</tr>';
    });
    html += '</table>';
    html += '<button class="pnj-action-btn" onclick="confirmerAcheterCriee(' + pa + ',' + cost + ')" style="margin-top:1.2rem;font-size:1rem;padding:.7rem">Valider l\'achat</button>';
  }
  html += '</div>';
  document.getElementById('postes-modal-title').textContent = 'Criée';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerAcheterCriee(pa, cost) {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const etat = await sbGetBatimentEtat('republic', VILLE_ID_PORT, BUILDING_ID_PORT).catch(() => ({}));
  const port = (etat && etat.port) || { stock: {}, repartition: {}, arrivages: [], exportations: {}, criee: {} };
  const stock = { ...(port.criee?.stock || {}) };

  const achats = {};
  let total = 0;
  for (const cle of RESSOURCES_CRIEE_VENDABLES) {
    const qte = parseInt(document.getElementById('achat-criee-' + cle)?.value || 0);
    if (!qte || qte <= 0) continue;
    const enStock = stock[cle] || 0;
    if (qte > enStock) {
      showToast('Stock insuffisant', 'Il ne reste que ' + Math.round(enStock) + ' unité(s) de ' + RESSOURCES_ECONOMIE[cle].label + ' à la Criée.', false);
      return;
    }
    const prix = getPrixRessourceEntrepot(cle);
    achats[cle] = { qte, prix };
    total += qte * prix;
  }
  if (Object.keys(achats).length === 0) { showToast('Rien à acheter', 'Indiquez au moins une quantité.', false); return; }
  if (state.arg < total) {
    showToast('Fonds insuffisants', Math.round(total) + ' ' + cur + ' requis, vous avez ' + Math.round(state.arg) + ' ' + cur + '.', false);
    return;
  }
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }

  let totalReellementPaye = 0;
  for (const [cle, { qte, prix }] of Object.entries(achats)) {
    const res = RESSOURCES_ECONOMIE[cle];
    const qteAjoutee = addToInventory({
      name: res.label, icon: res.icon, stackable: true, stackKey: cle, qty: qte,
      desc: 'Marchandise achetée à la Criée du Port de Port-Sainte-Marie.'
    });
    if (qteAjoutee > 0) {
      stock[cle] = (stock[cle] || 0) - qteAjoutee;
      totalReellementPaye += qteAjoutee * prix;
    }
  }
  if (totalReellementPaye <= 0) {
    showToast('Inventaire plein', 'Aucune marchandise n\'a pu être récupérée.', false);
    return;
  }
  state.arg -= totalReellementPaye;

  await sbSetBatimentEtat('republic', VILLE_ID_PORT, BUILDING_ID_PORT, { ...(etat || {}), port: { ...port, criee: { ...(port.criee || {}), stock } } }).catch(() => {});
  await crediterCaisseBatiment('republic', BUILDING_ID_PORT, totalReellementPaye).catch(() => {});
  if (typeof sbSavePersonnage === 'function') await sbSavePersonnage(state).catch(() => {});

  document.getElementById('modal-postes')?.classList.remove('open');
  updateUI();
  showToast('Achat effectué !', '-' + Math.round(totalReellementPaye) + ' ' + cur + '.', true, true);
  addJournalEntry('Achat à la Criée du port : ' + Object.entries(achats).map(([cle, a]) => a.qte + ' ' + RESSOURCES_ECONOMIE[cle].label).join(', ') + '.', 'event-good');
}

// ---- MANIFESTE (registre administratif persistant, 0 PA / 0 FR, accessible a tout PJ — lot du
// 25 aout 2026, §9/§10) ----
// Remplace l'ancien consulter_manifeste (jet INT abstrait sans donnee reelle) et supprime
// falsifier_manifeste (jet abstrait sans effet reel sur une caisse, retire de data.js/
// plateau-router.js/plateau-navigation.js -- seul empire qui l'exposait, aucun autre order/room
// ne le referencait, verifie avant suppression). Reutilise integralement les donnees deja
// persistees plutot que de dupliquer un historique : caisses_fret (table dediee, definie plus
// bas dans ce fichier) pour le fret prive -- jamais le contenu reel (contenu_caisses_fret) --, et
// etat.port (getEtatPort ci-dessus) pour les flux institutionnels.
async function doConsulterManifeste() {
  const [origines, destinations] = await Promise.all([
    sbGet('caisses_fret', 'building_origine=eq.' + encodeURIComponent(BUILDING_ID_PORT)).catch(() => []),
    sbGet('caisses_fret', 'building_destination=eq.' + encodeURIComponent(BUILDING_ID_PORT)).catch(() => [])
  ]);
  const parId = {};
  (origines || []).forEach(c => { parId[c.id] = c; });
  (destinations || []).forEach(c => { parId[c.id] = c; });
  const caisses = Object.values(parId)
    .sort((a, b) => new Date(b.date_depart || 0) - new Date(a.date_depart || 0))
    .slice(0, 20);

  const port = await getEtatPort();

  document.getElementById('postes-modal-title').textContent = 'Manifeste du Port';
  let html = '<div style="padding:1rem;max-height:70vh;overflow-y:auto">';

  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">FRET PRIVÉ DÉCLARÉ</div>';
  if (caisses.length === 0) {
    html += '<div style="font-size:.8rem;color:#8a8060;margin-bottom:.7rem">Aucune caisse enregistrée pour l\'instant.</div>';
  } else {
    caisses.forEach(c => {
      const dep = c.date_depart ? new Date(c.date_depart).toLocaleDateString('fr-FR') : 'non partie';
      html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.5rem .6rem;margin-bottom:.4rem;font-size:.76rem;color:#8a8060">';
      html += '<div style="color:#c0b090">Expéditeur : ' + (c.leader || '—') + ' — Destinataire : ' + (c.destinataire || 'non déclaré') + '</div>';
      html += '<div>Origine : ' + (c.ville_origine || '—') + ' — Destination : ' + (c.pays_destination || '—') + '</div>';
      html += '<div>Déclaration douanière : ' + (c.declaration_douaniere || 'non déclarée') + ' — Valeur déclarée : ' + (c.valeur_declaree != null ? Math.round(c.valeur_declaree) + ' FR' : '—') + '</div>';
      html += '<div>Statut : ' + (c.statut || '—') + ' — Départ : ' + dep + '</div>';
      html += '</div>';
    });
  }

  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin:.8rem 0 .4rem">FLUX INSTITUTIONNELS</div>';
  const arrivages = (port.arrivages || []).slice(0, 10);
  if (arrivages.length === 0) {
    html += '<div style="font-size:.78rem;color:#8a8060;margin-bottom:.5rem">Aucun arrivage institutionnel enregistré pour l\'instant.</div>';
  } else {
    arrivages.forEach(a => {
      const res = RESSOURCES_ECONOMIE[a.resource];
      const date = new Date(a.jour);
      html += '<div style="font-size:.76rem;color:#8a8060">' + date.toLocaleDateString('fr-FR') + ' — arrivage ' + (res?.label || a.resource) + ' : +' + Math.round(a.qte) + '</div>';
    });
  }
  RESSOURCES_PORT_IMPORTEES.forEach(cle => {
    const res = RESSOURCES_ECONOMIE[cle];
    const rep = port.repartition?.[cle] || REPARTITION_PORT_DEFAUT;
    html += '<div style="font-size:.76rem;color:#8a8060;margin-top:.2rem">Répartition ' + (res?.label || cle) + ' — Luthécia ' + arrondiPct(rep.capitale) + '% / Port-Sainte-Marie ' + arrondiPct(rep.ville_a) + '% / Montrouge ' + arrondiPct(rep.ville_b) + '%</div>';
  });
  Object.entries(EXPORTATIONS_PORT_INFOS).forEach(([cle, infos]) => {
    const exp = port.exportations?.[cle];
    if (!exp) return;
    html += '<div style="font-size:.76rem;color:#8a8060;margin-top:.2rem">Exportation ' + infos.label + ' vers ' + infos.destination + ' : ' + Math.round(exp.envoye) + '/' + exp.contrat + ' (' + exp.satisfactionPct + '%)</div>';
  });

  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// =====================
// FRET MARITIME INTERNATIONAL — CAISSES PERSISTANTES MULTI-OBJETS (lot du 24 aout 2026)
// =====================
// Remplace integralement l'ancien systeme expedier_colis/receptionner_commande (colisEnCours,
// plateau-navigation.js) : etat 100% client jamais persiste, destinataire ne recevant jamais
// rien en pratique. Modele final (2 iterations d'arbitrage) : une CAISSE partagee (500 unites
// max, plusieurs objets, plusieurs deposants) plutot qu'un objet unique par envoi. Persistance
// dans 2 tables Supabase dediees (caisses_fret + contenu_caisses_fret, migration fournie
// separement, PAS executee) -- table dediee plutot qu'un blob batiments_etat partage par tous
// les pays (meme raisonnement que pour le premier prototype : recherche par destinataire,
// eviter la contention d'ecriture).
//
// Les 2 order existants (expedier_colis/receptionner_commande, memes fn dans les 4 ports,
// data.js) sont conserves comme points d'entree UI ; toute la logique ci-dessous les remplace.
//
// Modele generique (portee internationale) : PORTS_FRET liste tous les ports capables de
// RECEVOIR du fret, un seul est peuple pour l'instant (Republia/PSM).
const PORTS_FRET = {
  republic: { ville: 'ville_a', buildingId: 'port-sainte-marie' }
};
// Deplacee de 'quai_principal' vers 'entrepot' (lot du 25 aout 2026, §6) en meme temps que les
// orders expedier_colis/receptionner_commande (data.js, room port-sainte-marie) -- garde de
// presence physique (jeSuisPresentDansRoomFret ci-dessous) doit toujours pointer vers la room ou
// vivent reellement les boutons, sinon le depot/retrait sur une caisse aurait echoue apres le
// deplacement UX ("vous devez etre physiquement present au port"). Seul Republia/PSM a un port
// de fret reellement peuple (PORTS_FRET plus bas) : le seul id de room qui compte en pratique
// est celui de PSM ('entrepot', ex-'quai_principal') -- les 3 autres empires n'ont jamais eu de
// room correspondant exactement a cette constante de toute facon (quai_sovarka/quai_el_estado/
// quai_al_khalija), leur fret n'etant pas fonctionnel independamment de ce changement.
const ROOM_CHARGEMENT_FRET = 'entrepot';

// Arbitrages valides (24 aout 2026, 2 tours) :
const CAPACITE_MAX_CAISSE_FRET = 500;
const DUREE_TRANSPORT_FRET_JOURS = 1;
const TAUX_DOUANE_FRET = 10;                // % de valeur_declaree, du au premier dedouanement
const TAUX_GARDIENNAGE_FRET_JOUR = 1;       // %/jour de valeur_declaree, a partir du 8e jour
const JOURS_FRANCHISE_GARDIENNAGE_FRET = 7;
const JOUR_MISE_EN_VENTE_FRET = 15;
const RATIO_PRIX_LIQUIDATION_FRET = 0.5;    // prix PNJ = 50% de la valeur administrative restante

// ---- BLACKLIST TECHNIQUE (objets non transferables par construction -- PAS lie a la legalite :
// armes/poisons/drogues/contrebande/kompromat restent transferables, leur illegalite sera geree
// plus tard par les douanes, cf. arbitrage explicite du 24 aout 2026) ----
// 'relique' ajoutee le 24 aout 2026 (arbitrage explicite) : raison purement fonctionnelle, pas
// legale -- le bonus +10 IP de doAcheterRelique() (plateau-divers.js) est attribue
// definitivement a l'achat (modifierIP(10), one-shot) et ne suit jamais l'objet dans
// l'inventaire (audit confirme : le champ effet:'ip+10' n'est lu nulle part). Transferer la
// relique donnerait une representation trompeuse de la mecanique. Le fonctionnement des
// reliques elles-memes (achat, bonus one-shot) reste totalement inchange.
const BLACKLIST_TYPES_FRET = new Set(['acte_officiel', 'colis_secret_pat', 'relique']);
const BLACKLIST_IDS_EXACTS_FRET = new Set(['cle-debarras-musee']);
function estObjetInterditFret(item) {
  if (!item) return true;
  if (BLACKLIST_TYPES_FRET.has(item.type)) return true;
  if (item.id && BLACKLIST_IDS_EXACTS_FRET.has(item.id)) return true;
  if (item.calepinEnigme1) return true;
  if (typeof item.id === 'string' && item.id.indexOf('fiche-etat-civil-') === 0) return true;
  return false;
}

// ---- HELPERS ----
async function jeSuisPresentDansRoomFret(pays, ville, buildingId) {
  if (typeof sbGetPresencesInRoom !== 'function') return true; // repli permissif si le service est indisponible
  const moi = state.char?.name || '';
  const presents = await sbGetPresencesInRoom(pays, ville, buildingId, ROOM_CHARGEMENT_FRET).catch(() => []);
  return (presents || []).some(p => p.name === moi);
}

function calculerDroitsDouaneCaisseFret(caisse) {
  return Math.round((caisse.valeur_declaree || 0) * TAUX_DOUANE_FRET / 100);
}

// Deterministe depuis date_arrivee_reelle, calcule UNE SEULE FOIS au moment du dedouanement
// (pas a chaque consultation, pas a chaque retrait ulterieur -- "Une fois dedouanee, les
// retraits collectifs sont libres sans nouveau paiement", arbitrage explicite).
function calculerGardiennageCaisseFret(caisse, maintenantMs) {
  if (!caisse.date_arrivee_reelle) return 0;
  const joursEcoules = Math.floor((maintenantMs - new Date(caisse.date_arrivee_reelle).getTime()) / 86400000);
  const joursFactures = Math.max(0, joursEcoules - JOURS_FRANCHISE_GARDIENNAGE_FRET);
  if (joursFactures <= 0) return 0;
  return Math.round((caisse.valeur_declaree || 0) * TAUX_GARDIENNAGE_FRET_JOUR / 100 * joursFactures);
}

async function chargerContenuCaisseFret(caisseId) {
  if (typeof sbGet !== 'function') return [];
  return await sbGet('contenu_caisses_fret', 'caisse_id=eq.' + encodeURIComponent(caisseId) + '&order=date_depot.asc').catch(() => []) || [];
}

function totalContenuFret(lignes) {
  return (lignes || []).reduce((s, l) => s + (l.quantite || 0), 0);
}

// ---- EXPEDITION (cote leader, port d'origine) ----
async function ouvrirExpedierColis(pa, cost) {
  const pays = state.country || 'republic';
  const ville = state.currentCity;
  const buildingId = state.currentBuilding;
  const moi = state.char?.name || '';

  document.getElementById('postes-modal-title').textContent = 'Fret maritime — Expédition';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const caisses = typeof sbGet === 'function'
    ? await sbGet('caisses_fret', 'leader=eq.' + encodeURIComponent(moi) + '&building_origine=eq.' + encodeURIComponent(buildingId) + '&statut=eq.ouverte').catch(() => [])
    : [];

  if (!caisses || caisses.length === 0) {
    let html = '<div style="padding:1rem">';
    html += '<div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">' + pa + ' PA · ' + cost + ' FR. Réserve une caisse de fret (500 unités max, transport 1 jour). Vous pourrez y déposer plusieurs marchandises et inviter des chargeurs avant de la fermer et l\'expédier.</div>';
    html += '<button onclick="confirmerReservationCaisseFret(' + pa + ',' + cost + ')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Réserver une caisse</button>';
    html += '</div>';
    document.getElementById('postes-body').innerHTML = html;
    window._fretPaysOrigine = pays; window._fretVilleOrigine = ville; window._fretBuildingOrigine = buildingId;
    return;
  }
  await afficherGestionCaisseOuverteFret(caisses[0].id);
}

async function confirmerReservationCaisseFret(pa, cost) {
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('Fonds insuffisants', '', false); return; }
  const caisse = {
    leader: state.char?.name || 'Inconnu',
    pays_origine: window._fretPaysOrigine || state.country || 'republic',
    ville_origine: window._fretVilleOrigine || state.currentCity,
    building_origine: window._fretBuildingOrigine || state.currentBuilding,
    statut: 'ouverte',
    chargeurs_autorises: [],
    receptionnaires_autorises: [],
    dedouanee: false
  };
  const rows = typeof sbInsert === 'function' ? await sbInsert('caisses_fret', caisse).catch(() => null) : null;
  const nouvelle = rows && rows[0];
  if (!nouvelle) { showToast('Erreur', 'Impossible de réserver la caisse.', false); return; }
  showToast('Caisse réservée', 'Vous pouvez maintenant y déposer des marchandises.', true, true);
  addJournalEntry('Caisse de fret réservée au port.', 'event-info');
  await afficherGestionCaisseOuverteFret(nouvelle.id);
}

async function afficherGestionCaisseOuverteFret(caisseId) {
  const moi = state.char?.name || '';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement...</div>';

  const rows = typeof sbGet === 'function' ? await sbGet('caisses_fret', 'id=eq.' + encodeURIComponent(caisseId)).catch(() => []) : [];
  const caisse = rows && rows[0];
  if (!caisse || caisse.statut !== 'ouverte') { showToast('Caisse indisponible', '', false); return; }

  const estLeader = caisse.leader === moi;
  const estChargeur = (caisse.chargeurs_autorises || []).includes(moi);
  if (!estLeader && !estChargeur) { showToast('Accès refusé', 'Vous n\'êtes pas autorisé à charger cette caisse.', false); return; }
  const presentIci = await jeSuisPresentDansRoomFret(caisse.pays_origine, caisse.ville_origine, caisse.building_origine);
  if (!presentIci) { showToast('Absent du port', 'Vous devez être physiquement présent au port pour agir sur cette caisse.', false); return; }

  const lignes = await chargerContenuCaisseFret(caisseId);
  const total = totalContenuFret(lignes);

  const eligibles = (state.inventory || []).filter(i => !estObjetInterditFret(i));

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.6rem">Remplissage : ' + total + ' / ' + CAPACITE_MAX_CAISSE_FRET + ' unités.</div>';

  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">CONTENU ACTUEL</div>';
  if (lignes.filter(l => l.quantite > 0).length === 0) {
    html += '<div style="font-size:.82rem;color:#8a8060;font-style:italic;margin-bottom:.6rem">Caisse vide.</div>';
  } else {
    lignes.filter(l => l.quantite > 0).forEach(l => {
      html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.5rem .7rem;margin-bottom:.4rem;display:flex;align-items:center;justify-content:space-between">';
      html += '<div><div style="font-size:.8rem;color:#c0b090">' + l.quantite + ' × ' + (l.objet?.name || '?') + '</div><div style="font-size:.68rem;color:#5a4030">Déposé par ' + l.deposant + '</div></div>';
      if (l.deposant === moi) {
        html += '<button onclick="reprendreDeCaisseFret(\'' + caisseId + '\',\'' + l.id + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.65rem;padding:.25rem .5rem;border:1px solid #8a4020;background:transparent;color:#cc6a44;cursor:pointer">Reprendre</button>';
      }
      html += '</div>';
    });
  }

  if (eligibles.length > 0) {
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin:.8rem 0 .4rem">DÉPOSER</div>';
    html += '<select id="fret-depot-objet" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.4rem">';
    eligibles.forEach((obj, i) => { html += '<option value="' + i + '">' + obj.name + ' (x' + (obj.qty || 1) + ')</option>'; });
    html += '</select>';
    html += '<input type="number" id="fret-depot-qty" value="1" min="1" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.5rem">';
    html += '<button onclick="deposerDansCaisseFret(\'' + caisseId + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.74rem;padding:.4rem .9rem;border:1px solid #4a8a4a;background:transparent;color:#4a8a4a;cursor:pointer">Déposer</button>';
    window._fretEligiblesDepot = eligibles;
  }

  if (estLeader) {
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin:.8rem 0 .4rem">CHARGEURS AUTORISÉS</div>';
    (caisse.chargeurs_autorises || []).forEach(nom => {
      html += '<div style="font-size:.78rem;color:#c0b090;margin-bottom:.2rem">' + nom + ' <a href="#" onclick="retirerChargeurFret(\'' + caisseId + '\',\'' + nom + '\');return false" style="color:#cc6a44;font-size:.7rem">retirer</a></div>';
    });
    html += '<input type="text" id="fret-nouveau-chargeur" placeholder="Nom du joueur" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-family:Crimson Pro,serif;font-size:.8rem;outline:none;margin:.3rem 0">';
    html += '<button onclick="ajouterChargeurFret(\'' + caisseId + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;padding:.3rem .6rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Autoriser</button>';

    html += '<div style="margin-top:1rem;padding-top:.8rem;border-top:1px solid #2a2010">';
    html += '<button onclick="ouvrirFermerCaisseFret(\'' + caisseId + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">Fermer et déclarer</button>';
    html += '</div>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  window._fretCaisseOuverteActuelle = caisseId;
}

async function deposerDansCaisseFret(caisseId) {
  const idx = parseInt(document.getElementById('fret-depot-objet')?.value || '0');
  const qte = Math.max(1, parseInt(document.getElementById('fret-depot-qty')?.value || '1'));
  const obj = (window._fretEligiblesDepot || [])[idx];
  if (!obj) { showToast('Sélection invalide', '', false); return; }

  const itemActuel = (state.inventory || []).find(i => i === obj);
  if (!itemActuel || (itemActuel.qty || 1) < qte) { showToast('Quantité indisponible', 'Votre inventaire a changé.', false); return; }

  const lignes = await chargerContenuCaisseFret(caisseId);
  const totalActuel = totalContenuFret(lignes);
  if (totalActuel + qte > CAPACITE_MAX_CAISSE_FRET) {
    showToast('Caisse pleine', 'Capacité restante : ' + (CAPACITE_MAX_CAISSE_FRET - totalActuel) + ' unité(s).', false);
    return;
  }

  const { qty, ...objetSansQty } = itemActuel;
  if ((itemActuel.qty || 1) <= qte) {
    state.inventory = state.inventory.filter(i => i !== itemActuel);
  } else {
    itemActuel.qty -= qte;
  }
  if (typeof sbSavePersonnage === 'function') await sbSavePersonnage(state).catch(() => {});
  updateUI();

  const inserted = typeof sbInsert === 'function'
    ? await sbInsert('contenu_caisses_fret', {
        caisse_id: caisseId, deposant: state.char?.name || 'Inconnu', objet: objetSansQty, quantite: qte
      }).catch(() => null)
    : null;
  const nouvelleLigne = inserted && inserted[0];

  // Re-verification post-insertion : la caisse n'a ni verrou ni contrainte au niveau base
  // (INSERT, pas de compare-and-swap possible sur une SOMME multi-lignes comme pour un simple
  // retrait). Si deux depots concurrents ont chacun valide "totalActuel + qte <= 500" avant
  // d'inserer, le total reel apres peut depasser 500. Chaque depot annule alors UNIQUEMENT SA
  // PROPRE ligne (jamais celle d'un autre PJ) et rembourse son propre inventaire -- garantit
  // que la capacite ne reste jamais durablement depassee, sans nouvelle migration/verrou DB.
  if (nouvelleLigne) {
    const lignesApres = await chargerContenuCaisseFret(caisseId);
    if (totalContenuFret(lignesApres) > CAPACITE_MAX_CAISSE_FRET) {
      if (typeof sbUpdate === 'function') await sbUpdate('contenu_caisses_fret', 'id=eq.' + encodeURIComponent(nouvelleLigne.id), { quantite: 0 }).catch(() => {});
      if (typeof addToInventory === 'function') addToInventory({ ...objetSansQty, qty: qte });
      else { state.inventory = state.inventory || []; state.inventory.push({ ...objetSansQty, qty: qte }); }
      if (typeof sbSavePersonnage === 'function') await sbSavePersonnage(state).catch(() => {});
      updateUI();
      showToast('Dépôt annulé', 'La caisse a atteint sa capacité maximale entre-temps (dépôt concurrent). Votre marchandise a été restituée.', false);
      await afficherGestionCaisseOuverteFret(caisseId);
      return;
    }
  }

  showToast('Déposé', qte + ' × ' + objetSansQty.name + ' déposé(e) dans la caisse.', true, true);
  await afficherGestionCaisseOuverteFret(caisseId);
}

async function reprendreDeCaisseFret(caisseId, contenuId) {
  const moi = state.char?.name || '';
  const rows = typeof sbGet === 'function' ? await sbGet('contenu_caisses_fret', 'id=eq.' + encodeURIComponent(contenuId)).catch(() => []) : [];
  const ligne = rows && rows[0];
  if (!ligne || ligne.caisse_id !== caisseId || ligne.deposant !== moi || ligne.quantite <= 0) {
    showToast('Reprise impossible', 'Vous ne pouvez reprendre que vos propres dépôts.', false);
    return;
  }
  // Meme verrou optimiste que retirerDeCaisseFret : le PATCH ne reussit que si la ligne vaut
  // toujours ce qu'on vient de lire (double-clic, ou reprise concurrente improbable mais non
  // exclue puisque deposant est toujours le meme nom -- pas de faux negatif possible).
  const maj = typeof sbUpdate === 'function'
    ? await sbUpdate('contenu_caisses_fret', 'id=eq.' + encodeURIComponent(contenuId) + '&quantite=eq.' + ligne.quantite, { quantite: 0 }).catch(() => null)
    : null;
  if (!maj || maj.length === 0) { showToast('Conflit', 'Cette ligne vient d\'être modifiée. Réessayez.', false); return; }

  if (typeof addToInventory === 'function') addToInventory({ ...ligne.objet, qty: ligne.quantite });
  else { state.inventory = state.inventory || []; state.inventory.push({ ...ligne.objet, qty: ligne.quantite }); }
  if (typeof sbSavePersonnage === 'function') await sbSavePersonnage(state).catch(() => {});
  updateUI();
  showToast('Repris', ligne.quantite + ' × ' + (ligne.objet?.name || '') + ' repris(e) dans votre inventaire.', true, true);
  await afficherGestionCaisseOuverteFret(caisseId);
}

async function ajouterChargeurFret(caisseId) {
  const nom = document.getElementById('fret-nouveau-chargeur')?.value?.trim();
  if (!nom) return;
  const rows = typeof sbGet === 'function' ? await sbGet('caisses_fret', 'id=eq.' + encodeURIComponent(caisseId)).catch(() => []) : [];
  const caisse = rows && rows[0];
  if (!caisse || caisse.leader !== (state.char?.name || '')) return;
  const liste = Array.from(new Set([...(caisse.chargeurs_autorises || []), nom]));
  if (typeof sbUpdate === 'function') await sbUpdate('caisses_fret', 'id=eq.' + encodeURIComponent(caisseId), { chargeurs_autorises: liste }).catch(() => {});
  await afficherGestionCaisseOuverteFret(caisseId);
}

async function retirerChargeurFret(caisseId, nom) {
  const rows = typeof sbGet === 'function' ? await sbGet('caisses_fret', 'id=eq.' + encodeURIComponent(caisseId)).catch(() => []) : [];
  const caisse = rows && rows[0];
  if (!caisse || caisse.leader !== (state.char?.name || '')) return;
  const liste = (caisse.chargeurs_autorises || []).filter(n => n !== nom);
  if (typeof sbUpdate === 'function') await sbUpdate('caisses_fret', 'id=eq.' + encodeURIComponent(caisseId), { chargeurs_autorises: liste }).catch(() => {});
  await afficherGestionCaisseOuverteFret(caisseId);
}

// ---- FERMETURE + DECLARATION (leader uniquement) ----
async function ouvrirFermerCaisseFret(caisseId) {
  const moi = state.char?.name || '';
  const rows = typeof sbGet === 'function' ? await sbGet('caisses_fret', 'id=eq.' + encodeURIComponent(caisseId)).catch(() => []) : [];
  const caisse = rows && rows[0];
  if (!caisse || caisse.leader !== moi || caisse.statut !== 'ouverte') { showToast('Action impossible', '', false); return; }
  const lignes = await chargerContenuCaisseFret(caisseId);
  const total = totalContenuFret(lignes);
  if (total <= 0) { showToast('Caisse vide', 'Déposez au moins une unité avant de fermer la caisse.', false); return; }

  document.getElementById('postes-modal-title').textContent = 'Fermer et déclarer la caisse';
  let joueurs = [];
  if (typeof sbListPersonnages === 'function') joueurs = (await sbListPersonnages().catch(() => []) || []).filter(j => j.name && j.name !== moi);

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Une fois fermée, plus aucun dépôt ni retrait n\'est possible. La déclaration (destinataire, nature, valeur) est indépendante du contenu réel — elle sera la seule base des droits de douane futurs.</div>';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">DESTINATAIRE</div>';
  html += '<select id="fret-fermeture-dest" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.6rem">';
  joueurs.forEach(j => { html += '<option value="' + j.name + '">' + j.name + ' — ' + (typeof COUNTRIES !== 'undefined' ? (COUNTRIES[j.country]?.n || j.country) : j.country) + '</option>'; });
  html += '</select>';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">DÉCLARATION DOUANIÈRE (nature/qualité déclarée)</div>';
  html += '<input type="text" id="fret-fermeture-declaration" placeholder="Ex. denrées diverses" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.6rem">';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">VALEUR DÉCLARÉE (FR)</div>';
  html += '<input type="number" id="fret-fermeture-valeur" value="0" min="0" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.8rem">';
  html += '<button onclick="confirmerFermetureCaisseFret(\'' + caisseId + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">Fermer la caisse</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  window._fretJoueursFermeture = joueurs;
}

// ---- DISSIMULATION DES CAISSES DE FRET (lot du 25 aout 2026, §4-5) ----
// Audit prealable (§4) : caisses_fret/contenu_caisses_fret sont de VRAIES tables Postgres a
// schema fixe (migration executee manuellement, voir git show 2542984) -- aucune colonne de
// dissimulation n'existe aujourd'hui et en ajouter une exigerait une nouvelle migration SQL.
// Pour eviter ce blocage (§17), la difficulte de dissimulation est persistee a cote, dans le
// meme store generique flexible batiments_etat deja reutilise pour le BNE/les prets/le blocus
// (sbGetBatimentEtat/sbSetBatimentEtat, voir supabase.js) -- une entree globale unique et
// partagee (meme convention que sbGetEtatBNE/sbSetEtatBNE), car une caisse peut relier deux pays
// differents (pays_origine != pays_destination) et son id est deja une cle globalement unique
// (uuid Postgres reel) : aucune partition par pays/ville necessaire.
// Valeur persistee UNE SEULE FOIS, au moment de la fermeture+declaration
// (confirmerFermetureCaisseFret, juste apres -- seul point ou le contenu est fige et ou le leader
// agit encore en son nom propre) : la DIS EFFECTIVE du leader a cet instant
// (calculerDisEffective(), meme normalisation 8-18 deja utilisee partout ailleurs pour comparer
// une DIS a un PER via calculerChancePJ -- pas le state.dis brut 0-100, qui n'est pas sur la
// meme echelle que PER_SERVICE_DOUANES). Jamais recalculee ni relue depuis le personnage au
// moment du controle (§5 : la difficulte reste attachee a la caisse, independante de la DIS
// courante de son auteur au moment ou le Chef controle).
async function chargerDissimulationCaissesFret() {
  const etat = await sbGetBatimentEtat('global', 'national', 'dissimulation-fret').catch(() => ({}));
  return etat?.parCaisse || {};
}

async function sauvegarderDissimulationCaisseFret(caisseId, valeur) {
  const parCaisse = await chargerDissimulationCaissesFret();
  parCaisse[caisseId] = valeur;
  if (typeof sbSetBatimentEtat === 'function') {
    await sbSetBatimentEtat('global', 'national', 'dissimulation-fret', { parCaisse }).catch(() => {});
  }
}

// Meme bucket global partage (cle 'controles', voisine de 'parCaisse' ci-dessus, fusion
// superficielle deja geree par sbSetBatimentEtat) : une caisse ne peut etre ciblee qu'une seule
// fois par le Chef des Douanes (evite le grinding d'une meme caisse jusqu'a un jet favorable).
async function chargerControlesCaissesFret() {
  const etat = await sbGetBatimentEtat('global', 'national', 'dissimulation-fret').catch(() => ({}));
  return etat?.controles || {};
}

async function marquerCaisseControleeFret(caisseId, resultat) {
  const controles = await chargerControlesCaissesFret();
  controles[caisseId] = { resultat, controleeLe: Date.now() };
  if (typeof sbSetBatimentEtat === 'function') {
    await sbSetBatimentEtat('global', 'national', 'dissimulation-fret', { controles }).catch(() => {});
  }
}

// ---- CONTROLE DOUANIER D'UNE CAISSE (lot du 25 aout 2026, §2-3-5-6-10) ----
// Philosophie validee (§1) : aucun PJ douanier, seul le Chef des Douanes decide. Il consulte le
// manifeste (doConsulterManifeste, deja existant, ne montre jamais le contenu reel -- seulement
// la declaration douaniere auto-declaree, potentiellement fausse) et cible UNE caisse precise,
// arrivee ou en instance de depart au port de PSM. Formule validee (§3, explicitement PAS une
// moyenne) : PER_SERVICE_DOUANES = PER effectif du Chef + nombre de douaniers PNJ (chacun +1,
// unite cynophile comprise -- §6). Bonus specialise +3 UNIQUEMENT si (a) une unite cynophile est
// presente ET (b) la caisse contient reellement des stupefiants -- jamais revele avant la
// resolution (aucun texte d'interface ne mentionne la presence de stupefiants ni le bonus avant
// cet instant). "Stupefiants" = type:'poison' (seul type d'objet du jeu couvrant cette famille,
// aucun type dedie n'existe -- interpretation explicitement signalee au rapport). Chance de
// decouverte : clamp(50 + 5*(PER_service - DIS_caisse), 10, 90), meme famille de formule que
// calculerChancePJ (non reutilisee telle quelle car ses deux arguments ne sont pas dans le meme
// ordre/sens ici -- DIS_caisse est un desavantage pour la douane, pas un avantage pour son
// adversaire absent). Consequence d'un controle positif (§10) : reutilise integralement le
// pipeline convocation existant (state.convocations / motif 'possession_illegale_douane', meme
// structure que doPasserDouanesAeroport, plateau-navigation.js) et la vraie table mails
// (sbSendMail) -- AUCUN second systeme de justice cree. Le ou les deposants fautifs peuvent etre
// des PJ hors ligne : ecriture directe sur leur ligne personnages (lecture/fusion/ecriture),
// jamais via state (meme doctrine que la sanction POP/DIS du maire pour obstruction de permis,
// deja presente dans ce fichier). Chaque objet illegal garde son deposant exact par ligne
// (contenu_caisses_fret.deposant), donc l'attribution n'est jamais ambigue meme si plusieurs
// personnes ont deposé dans la meme caisse.
const CAISSE_FRET_TYPES_ILLEGAUX_CONTROLES = ['arme', 'poison', 'tract_calomnieux'];

async function ouvrirControlerCaisseDouane(pa, cost) {
  const check = chefDouanesValide();
  if (!check.ok) { showToast('Réservé au Chef des Douanes', '', false); return; }

  document.getElementById('postes-modal-title').textContent = 'Contrôle douanier — cibler une caisse';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const [sortantes, arrivees] = await Promise.all([
    sbGet('caisses_fret', 'building_origine=eq.' + encodeURIComponent(BUILDING_ID_PORT) + '&statut=eq.fermee').catch(() => []),
    sbGet('caisses_fret', 'building_destination=eq.' + encodeURIComponent(BUILDING_ID_PORT) + '&statut=eq.arrivee').catch(() => [])
  ]);
  const controles = await chargerControlesCaissesFret();
  const ciblables = [...(sortantes || []), ...(arrivees || [])].filter(c => !controles[c.id]);

  let html = '<div style="padding:1rem;max-height:70vh;overflow-y:auto">';
  html += '<div style="font-size:.76rem;color:#8a8060;margin-bottom:.7rem;font-style:italic">Le manifeste ne révèle jamais le contenu réel d\'une caisse — uniquement sa déclaration. Le contrôle est exécuté par le service ; son issue dépend de l\'effectif et de la difficulté de dissimulation de la caisse.</div>';
  if (ciblables.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060">Aucune caisse contrôlable pour l\'instant.</div>';
  } else {
    ciblables.forEach(c => {
      const sens = c.building_origine === BUILDING_ID_PORT ? 'Sortante' : 'Entrante';
      html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.6rem .7rem;margin-bottom:.5rem">';
      html += '<div style="font-size:.8rem;color:#c0b090">' + sens + ' — Expéditeur : ' + (c.leader || '—') + ' — Destinataire : ' + (c.destinataire || 'non déclaré') + '</div>';
      html += '<div style="font-size:.76rem;color:#8a8060;margin-bottom:.4rem">Déclaration : ' + (c.declaration_douaniere || 'non déclarée') + '</div>';
      html += '<button onclick="confirmerControleCaisseFret(\'' + c.id + '\',' + pa + ')" style="width:100%;font-size:.72rem;padding:.4rem;border:1px solid #8a3a2a;background:transparent;color:#cc4444;cursor:pointer">Ordonner le contrôle</button>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function confirmerControleCaisseFret(caisseId, pa) {
  const check = chefDouanesValide();
  if (!check.ok) { showToast('Réservé au Chef des Douanes', '', false); return; }

  const controlesAvant = await chargerControlesCaissesFret();
  if (controlesAvant[caisseId]) { showToast('Déjà contrôlée', 'Cette caisse a déjà fait l\'objet d\'un contrôle.', false); return; }

  const rows = await sbGet('caisses_fret', 'id=eq.' + encodeURIComponent(caisseId)).catch(() => []);
  const caisse = rows && rows[0];
  const cibleValide = caisse && (
    (caisse.building_origine === BUILDING_ID_PORT && caisse.statut === 'fermee') ||
    (caisse.building_destination === BUILDING_ID_PORT && caisse.statut === 'arrivee')
  );
  if (!cibleValide) { showToast('Cible invalide', 'Cette caisse n\'est plus contrôlable (déjà expédiée, retirée, ou introuvable).', false); return; }

  const r = await deduireCoutOrdre({ pa, cost: 0 });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }

  const pays = state.country || 'republic';
  const effectifs = await chargerEffectifsDouane(pays);
  const nbDouaniers = effectifs.douaniers.length;
  const aUneUniteCynophile = effectifs.douaniers.some(d => d.type === 'cynophile');
  const disCaisse = (await chargerDissimulationCaissesFret())[caisseId] ?? 13; // 13 = calculerDisEffective() a DIS neutre (50), repli si anomalie de persistance

  const lignes = await chargerContenuCaisseFret(caisseId);
  const lignesIllegales = lignes.filter(l => CAISSE_FRET_TYPES_ILLEGAUX_CONTROLES.includes(l.objet?.type) && l.objet?.legal === false && (l.quantite || 0) > 0);
  const contientStupefiants = lignesIllegales.some(l => l.objet?.type === 'poison');

  let perService = getStatEffective('PER') + nbDouaniers;
  if (aUneUniteCynophile && contientStupefiants) perService += 3;

  const chance = Math.max(10, Math.min(90, 50 + 5 * (perService - disCaisse)));
  const tirage = Math.floor(Math.random() * 100) + 1;
  const succes = tirage <= chance;

  await marquerCaisseControleeFret(caisseId, succes ? 'positif' : 'negatif');

  document.getElementById('modal-postes').classList.remove('open');

  if (!succes) {
    showToast('Contrôle infructueux', 'Rien de suspect n\'a été relevé sur cette caisse.', false, true);
    addJournalEntry('Contrôle douanier d\'une caisse de fret : rien trouvé.', 'event-info');
    return;
  }

  if (lignesIllegales.length === 0) {
    showToast('Contrôle terminé', 'La caisse a été ouverte : aucun contenu illicite reconnu à l\'intérieur.', true, true);
    addJournalEntry('Contrôle douanier d\'une caisse de fret : ouverte, rien d\'illicite trouvé.', 'event-info');
    return;
  }

  const parDeposant = {};
  lignesIllegales.forEach(l => { (parDeposant[l.deposant] = parDeposant[l.deposant] || []).push(l); });

  for (const [deposant, ses] of Object.entries(parDeposant)) {
    for (const l of ses) {
      await sbUpdate('contenu_caisses_fret', 'id=eq.' + encodeURIComponent(l.id) + '&quantite=eq.' + l.quantite, { quantite: 0 }).catch(() => {});
    }
    const noms = ses.map(l => l.objet?.name || l.objet?.type).join(', ');
    const nouvelleConvocation = {
      motif: 'possession_illegale_douane',
      jourEmission: state.day || 1,
      heureEmission: state.hour || 8,
      jourLimite: (state.day || 1) + 1,
      heureLimite: state.hour || 8,
      traitee: false
    };

    // Ecriture DIRECTE en base UNIQUEMENT pour un tiers (deposant potentiellement hors ligne) --
    // pour le Chef lui-meme (deposant === moi), state.convocations est deja la source de verite
    // vivante de CETTE session et sera persistee par le cycle de sauvegarde habituel
    // (sbSavePersonnage) comme n'importe quelle autre mutation de state ; ecrire aussi en base ici
    // l'exposerait a etre silencieusement ecrasee par le prochain sbSavePersonnage (qui reecrit
    // convocations en entier depuis state, sans le connaitre).
    if (deposant === (state.char?.name || '')) {
      state.convocations = state.convocations || [];
      state.convocations.push(nouvelleConvocation);
    } else {
      const perso = await sbGet('personnages', 'name=eq.' + encodeURIComponent(deposant)).catch(() => []);
      const ligne = perso && perso[0];
      if (ligne) {
        const convocationsActuelles = ligne.convocations || [];
        convocationsActuelles.push(nouvelleConvocation);
        await sbUpdate('personnages', 'name=eq.' + encodeURIComponent(deposant), { convocations: convocationsActuelles }).catch(() => {});
      }
    }
    if (typeof sbSendMail === 'function') {
      await sbSendMail('Chef des Douanes', deposant, 'Convocation officielle',
        'Un contrôle douanier a détecté et confisqué du contenu prohibé dans une caisse de fret que vous avez approvisionnée (' + noms + '). Présentez-vous au commissariat sous 24h pour vous justifier, faute de quoi vous serez arrêté(e).',
        typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : '').catch(() => {});
    }
  }

  showToast('Contrôle positif !', 'Contenu prohibé découvert et confisqué. Le ou les responsables ont été convoqués.', true, true);
  addJournalEntry('Contrôle douanier positif sur une caisse de fret : contenu illicite confisqué, convocation(s) émise(s).', 'event-good');
  updateUI();
}

async function confirmerFermetureCaisseFret(caisseId) {
  const moi = state.char?.name || '';
  // Identite/statut reverifies cote handler (pas seulement via l'affichage conditionnel du
  // formulaire) -- meme principe que partout ailleurs dans ce lot : le filtre supplementaire
  // sur le PATCH lui-meme (leader=eq./statut=eq.) empeche aussi une double-fermeture concurrente.
  const rows = typeof sbGet === 'function' ? await sbGet('caisses_fret', 'id=eq.' + encodeURIComponent(caisseId)).catch(() => []) : [];
  const caisse = rows && rows[0];
  if (!caisse || caisse.leader !== moi || caisse.statut !== 'ouverte') { showToast('Action impossible', '', false); return; }

  const destNom = document.getElementById('fret-fermeture-dest')?.value;
  const declaration = document.getElementById('fret-fermeture-declaration')?.value?.trim() || '';
  const valeur = Math.max(0, parseFloat(document.getElementById('fret-fermeture-valeur')?.value || '0'));
  const destJoueur = (window._fretJoueursFermeture || []).find(j => j.name === destNom);
  if (!destJoueur) { showToast('Destinataire invalide', '', false); return; }
  const portDest = PORTS_FRET[destJoueur.country];
  if (!portDest) { showToast('Port indisponible', 'Aucun port de fret n\'est encore opérationnel dans l\'empire de ce destinataire.', false); return; }

  const maj = typeof sbUpdate === 'function' ? await sbUpdate('caisses_fret', 'id=eq.' + encodeURIComponent(caisseId) + '&leader=eq.' + encodeURIComponent(moi) + '&statut=eq.ouverte', {
    statut: 'fermee',
    destinataire: destJoueur.name,
    pays_destination: destJoueur.country,
    ville_destination: portDest.ville,
    building_destination: portDest.buildingId,
    declaration_douaniere: declaration,
    valeur_declaree: valeur,
    date_fermeture: new Date().toISOString()
  }).catch(() => null) : null;
  if (!maj || maj.length === 0) { showToast('Action impossible', 'La caisse a peut-être déjà été fermée.', false); return; }

  await sauvegarderDissimulationCaisseFret(caisseId, calculerDisEffective());

  document.getElementById('modal-postes').classList.remove('open');
  showToast('Caisse fermée', 'Vous pouvez maintenant l\'expédier.', true, true);
  addJournalEntry('Caisse de fret fermée, destinée à ' + destJoueur.name + '.', 'event-info');
}

async function expedierCaisseFret(caisseId) {
  const moi = state.char?.name || '';
  const rows = typeof sbGet === 'function' ? await sbGet('caisses_fret', 'id=eq.' + encodeURIComponent(caisseId)).catch(() => []) : [];
  const caisse = rows && rows[0];
  if (!caisse || caisse.leader !== moi || caisse.statut !== 'fermee' || !caisse.destinataire || !caisse.pays_destination) {
    showToast('Expédition impossible', '', false);
    return;
  }
  const lignes = await chargerContenuCaisseFret(caisseId);
  const total = totalContenuFret(lignes);
  if (total <= 0) { showToast('Caisse vide', '', false); return; }

  const maintenant = new Date();
  const dateArriveePrevue = new Date(maintenant.getTime() + DUREE_TRANSPORT_FRET_JOURS * 86400000);
  if (typeof sbUpdate === 'function') {
    await sbUpdate('caisses_fret', 'id=eq.' + encodeURIComponent(caisseId), {
      statut: 'en_transit',
      date_depart: maintenant.toISOString(),
      date_arrivee_prevue: dateArriveePrevue.toISOString()
    }).catch(() => {});
  }
  showToast('Caisse expédiée !', 'Arrivée sous ' + DUREE_TRANSPORT_FRET_JOURS + ' jour à destination.', true, true);
  addJournalEntry('Caisse de fret expédiée vers ' + caisse.destinataire + '.', 'event-info');
  if (typeof addMailNotification === 'function') addMailNotification('Administration Portuaire', 'Caisse en route', 'Une caisse de fret vous a été expédiée par ' + moi + '. Elle sera à retirer au port sous ' + DUREE_TRANSPORT_FRET_JOURS + ' jour.');
}

// ---- RECEPTION (cote destinataire, port de destination) ----
async function ouvrirReceptionnerCommande(pa, cost) {
  const pays = state.country || 'republic';
  const moi = state.char?.name || '';
  document.getElementById('postes-modal-title').textContent = 'Fret maritime — Réception';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  let caisses = [];
  if (typeof sbGet === 'function') {
    const commeDestinataire = await sbGet('caisses_fret', 'destinataire=eq.' + encodeURIComponent(moi) + '&pays_destination=eq.' + encodeURIComponent(pays) + '&statut=eq.arrivee').catch(() => []) || [];
    const commeReceptionnaire = await sbGet('caisses_fret', 'pays_destination=eq.' + encodeURIComponent(pays) + '&statut=eq.arrivee&receptionnaires_autorises=cs.{' + encodeURIComponent(moi) + '}').catch(() => []) || [];
    const parId = {};
    [...commeDestinataire, ...commeReceptionnaire].forEach(c => { parId[c.id] = c; });
    caisses = Object.values(parId);
  }

  if (caisses.length === 0) {
    document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060;font-style:italic">Aucune caisse en attente pour vous à ce port.</div>';
    return;
  }
  if (caisses.length === 1) { await afficherCaisseArriveeFret(caisses[0].id, pa); return; }

  let html = '<div style="padding:1rem">';
  caisses.forEach(c => {
    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.6rem .7rem;margin-bottom:.4rem;display:flex;align-items:center;justify-content:space-between">';
    html += '<div style="font-size:.8rem;color:#c0b090">Caisse de ' + c.leader + ' (' + (c.declaration_douaniere || 'sans déclaration') + ')</div>';
    html += '<button onclick="afficherCaisseArriveeFret(\'' + c.id + '\',' + pa + ')" style="font-family:Bebas Neue,sans-serif;font-size:.65rem;padding:.25rem .5rem;border:1px solid #4a8a4a;background:transparent;color:#4a8a4a;cursor:pointer">Ouvrir</button>';
    html += '</div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function afficherCaisseArriveeFret(caisseId, pa) {
  const moi = state.char?.name || '';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement...</div>';

  const rows = typeof sbGet === 'function' ? await sbGet('caisses_fret', 'id=eq.' + encodeURIComponent(caisseId)).catch(() => []) : [];
  const caisse = rows && rows[0];
  if (!caisse || caisse.statut !== 'arrivee') { showToast('Caisse indisponible', '', false); return; }

  const estDestinataire = caisse.destinataire === moi;
  const estReceptionnaire = (caisse.receptionnaires_autorises || []).includes(moi);
  if (!estDestinataire && !estReceptionnaire) { showToast('Accès refusé', '', false); return; }
  const presentIci = await jeSuisPresentDansRoomFret(caisse.pays_destination, caisse.ville_destination, caisse.building_destination);
  if (!presentIci) { showToast('Absent du port', 'Vous devez être physiquement présent au port pour agir sur cette caisse.', false); return; }

  let html = '<div style="padding:1rem">';

  if (!caisse.dedouanee) {
    const douane = calculerDroitsDouaneCaisseFret(caisse);
    const gardiennage = calculerGardiennageCaisseFret(caisse, Date.now());
    const total = douane + gardiennage;
    html += '<div style="font-size:.82rem;color:#c0b090;margin-bottom:.4rem">Caisse non dédouanée. Droits de douane : ' + douane + ' FR' + (gardiennage > 0 ? ' · Gardiennage : ' + gardiennage + ' FR' : '') + ' · <strong>Total : ' + total + ' FR</strong>.</div>';
    if (estDestinataire) {
      html += '<button onclick="dedouanerCaisseFret(\'' + caisseId + '\',' + pa + ')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">Payer et dédouaner</button>';
    } else {
      html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic">Seul le destinataire officiel (' + caisse.destinataire + ') peut dédouaner cette caisse.</div>';
    }
    html += '</div>';
    document.getElementById('postes-body').innerHTML = html;
    return;
  }

  const lignes = await chargerContenuCaisseFret(caisseId);
  const disponibles = lignes.filter(l => l.quantite > 0);
  html += '<div style="font-size:.78rem;color:#4a8a4a;margin-bottom:.6rem">Dédouanée. Retraits libres.</div>';
  if (disponibles.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Caisse vide.</div>';
  } else {
    disponibles.forEach(l => {
      html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.5rem .7rem;margin-bottom:.4rem;display:flex;align-items:center;justify-content:space-between">';
      html += '<div><div style="font-size:.8rem;color:#c0b090">' + l.quantite + ' × ' + (l.objet?.name || '?') + '</div><div style="font-size:.68rem;color:#5a4030">Déposé par ' + l.deposant + '</div></div>';
      html += '<div style="display:flex;gap:.3rem;align-items:center">';
      html += '<input type="number" id="fret-retrait-qty-' + l.id + '" value="1" min="1" max="' + l.quantite + '" style="width:60px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.3rem;font-size:.8rem">';
      html += '<button onclick="retirerDeCaisseFret(\'' + caisseId + '\',\'' + l.id + '\',' + pa + ')" style="font-family:Bebas Neue,sans-serif;font-size:.65rem;padding:.3rem .5rem;border:1px solid #4a8a4a;background:transparent;color:#4a8a4a;cursor:pointer">Retirer</button>';
      html += '</div></div>';
    });
  }

  if (estDestinataire) {
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin:.8rem 0 .4rem">RÉCEPTIONNAIRES AUTORISÉS</div>';
    (caisse.receptionnaires_autorises || []).forEach(nom => {
      html += '<div style="font-size:.78rem;color:#c0b090;margin-bottom:.2rem">' + nom + ' <a href="#" onclick="retirerReceptionnaireFret(\'' + caisseId + '\',\'' + nom + '\');return false" style="color:#cc6a44;font-size:.7rem">retirer</a></div>';
    });
    html += '<input type="text" id="fret-nouveau-receptionnaire" placeholder="Nom du joueur" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-family:Crimson Pro,serif;font-size:.8rem;outline:none;margin:.3rem 0">';
    html += '<button onclick="ajouterReceptionnaireFret(\'' + caisseId + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;padding:.3rem .6rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Autoriser</button>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function dedouanerCaisseFret(caisseId, pa) {
  const moi = state.char?.name || '';
  const rows = typeof sbGet === 'function' ? await sbGet('caisses_fret', 'id=eq.' + encodeURIComponent(caisseId)).catch(() => []) : [];
  const caisse = rows && rows[0];
  if (!caisse || caisse.destinataire !== moi || caisse.dedouanee || caisse.statut !== 'arrivee') { showToast('Action impossible', '', false); return; }

  const douane = calculerDroitsDouaneCaisseFret(caisse);
  const gardiennage = calculerGardiennageCaisseFret(caisse, Date.now());
  const total = douane + gardiennage;

  const r = await deduireCoutOrdre({ pa, cost: 0 });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }
  if ((state.arg || 0) < total) { showToast('Fonds insuffisants', 'Il vous faut ' + total + ' FR (douane + gardiennage).', false); return; }

  // Filtre &dedouanee=eq.false : evite un double paiement en cas de double-clic rapide (le
  // second appel ne matche plus aucune ligne une fois le premier passe a true).
  const maj = typeof sbUpdate === 'function'
    ? await sbUpdate('caisses_fret', 'id=eq.' + encodeURIComponent(caisseId) + '&dedouanee=eq.false', { dedouanee: true, date_dedouanement: new Date().toISOString() }).catch(() => null)
    : null;
  if (!maj || maj.length === 0) { showToast('Déjà dédouanée', '', false); return; }

  state.arg -= total;
  if (typeof crediterCaisseBatiment === 'function') await crediterCaisseBatiment(caisse.pays_destination, caisse.building_destination, total).catch(() => {});
  if (typeof sbSavePersonnage === 'function') await sbSavePersonnage(state).catch(() => {});

  updateUI();
  showToast('Caisse dédouanée', total + ' FR versés à la caisse du port. Retraits libres.', true, true);
  addJournalEntry('Caisse de fret dédouanée (' + total + ' FR versés à la caisse du port).', 'event-good');
  await afficherCaisseArriveeFret(caisseId, pa);
}

async function retirerDeCaisseFret(caisseId, contenuId, pa) {
  const moi = state.char?.name || '';
  const caisseRows = typeof sbGet === 'function' ? await sbGet('caisses_fret', 'id=eq.' + encodeURIComponent(caisseId)).catch(() => []) : [];
  const caisse = caisseRows && caisseRows[0];
  if (!caisse || caisse.statut !== 'arrivee' || !caisse.dedouanee) { showToast('Retrait impossible', '', false); return; }
  const estAutorise = caisse.destinataire === moi || (caisse.receptionnaires_autorises || []).includes(moi);
  if (!estAutorise) { showToast('Accès refusé', '', false); return; }
  const presentIci = await jeSuisPresentDansRoomFret(caisse.pays_destination, caisse.ville_destination, caisse.building_destination);
  if (!presentIci) { showToast('Absent du port', '', false); return; }

  const ligneRows = typeof sbGet === 'function' ? await sbGet('contenu_caisses_fret', 'id=eq.' + encodeURIComponent(contenuId)).catch(() => []) : [];
  const ligne = ligneRows && ligneRows[0];
  if (!ligne || ligne.caisse_id !== caisseId || ligne.quantite <= 0) { showToast('Ligne indisponible', '', false); return; }

  const qteDemandee = Math.max(1, parseInt(document.getElementById('fret-retrait-qty-' + contenuId)?.value || '1'));
  const qte = Math.min(qteDemandee, ligne.quantite);

  const placeDisponible = (typeof PLAFOND_INVENTAIRE_EMPILABLE !== 'undefined' ? PLAFOND_INVENTAIRE_EMPILABLE : 100) - (typeof getTotalInventaire === 'function' ? getTotalInventaire() : 0);
  if (placeDisponible < qte) { showToast('Inventaire plein', 'Libérez de la place avant de retirer.', false); return; }

  const r = await deduireCoutOrdre({ pa, cost: 0 });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }

  // Verrouillage optimiste (compare-and-swap applicatif) : le PATCH ne reussit que si
  // 'quantite' vaut toujours EXACTEMENT ce qu'on vient de lire. Si un autre PJ a deja retire
  // sur cette meme ligne entre notre lecture et cet appel, le filtre ne matche plus aucune
  // ligne (0 resultat) -- on annule tout AVANT de toucher a l'inventaire, jamais apres. Evite
  // deux retraits concurrents de recreer ou dupliquer les memes unites (perte de mise a jour
  // classique sur un simple PATCH inconditionnel).
  const nouvelleQte = ligne.quantite - qte;
  const maj = typeof sbUpdate === 'function'
    ? await sbUpdate('contenu_caisses_fret', 'id=eq.' + encodeURIComponent(contenuId) + '&quantite=eq.' + ligne.quantite, { quantite: nouvelleQte }).catch(() => null)
    : null;
  if (!maj || maj.length === 0) {
    showToast('Conflit de retrait', 'Cette ligne vient d\'être modifiée par quelqu\'un d\'autre. Réessayez.', false);
    return;
  }

  if (typeof addToInventory === 'function') addToInventory({ ...ligne.objet, qty: qte });
  else { state.inventory = state.inventory || []; state.inventory.push({ ...ligne.objet, qty: qte }); }
  if (typeof sbSavePersonnage === 'function') await sbSavePersonnage(state).catch(() => {});

  // Passage a 'videe' si le contenu total de la caisse atteint 0 -- transition evenementielle
  // (declenchee par l'action elle-meme), pas temporelle : pas besoin de cron ici.
  const lignesRestantes = await chargerContenuCaisseFret(caisseId);
  if (totalContenuFret(lignesRestantes) <= 0 && typeof sbUpdate === 'function') {
    await sbUpdate('caisses_fret', 'id=eq.' + encodeURIComponent(caisseId), { statut: 'videe' }).catch(() => {});
  }

  updateUI();
  showToast('Retiré', qte + ' × ' + (ligne.objet?.name || '') + ' ajouté(e) à votre inventaire.', true, true);
  addJournalEntry('Marchandise retirée au port : ' + qte + ' × ' + (ligne.objet?.name || '') + '.', 'event-good');
  await afficherCaisseArriveeFret(caisseId, pa);
}

async function ajouterReceptionnaireFret(caisseId) {
  const nom = document.getElementById('fret-nouveau-receptionnaire')?.value?.trim();
  if (!nom) return;
  const rows = typeof sbGet === 'function' ? await sbGet('caisses_fret', 'id=eq.' + encodeURIComponent(caisseId)).catch(() => []) : [];
  const caisse = rows && rows[0];
  if (!caisse || caisse.destinataire !== (state.char?.name || '')) return;
  const liste = Array.from(new Set([...(caisse.receptionnaires_autorises || []), nom]));
  if (typeof sbUpdate === 'function') await sbUpdate('caisses_fret', 'id=eq.' + encodeURIComponent(caisseId), { receptionnaires_autorises: liste }).catch(() => {});
  await afficherCaisseArriveeFret(caisseId, 1);
}

async function retirerReceptionnaireFret(caisseId, nom) {
  const rows = typeof sbGet === 'function' ? await sbGet('caisses_fret', 'id=eq.' + encodeURIComponent(caisseId)).catch(() => []) : [];
  const caisse = rows && rows[0];
  if (!caisse || caisse.destinataire !== (state.char?.name || '')) return;
  const liste = (caisse.receptionnaires_autorises || []).filter(n => n !== nom);
  if (typeof sbUpdate === 'function') await sbUpdate('caisses_fret', 'id=eq.' + encodeURIComponent(caisseId), { receptionnaires_autorises: liste }).catch(() => {});
  await afficherCaisseArriveeFret(caisseId, 1);
}

// ---- LIQUIDATION J15 (room Entrepots du port) ----
async function ouvrirMarchandisesNonReclamees() {
  const pays = state.country || 'republic';
  document.getElementById('postes-modal-title').textContent = 'Marchandises non réclamées';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const caisses = typeof sbGet === 'function'
    ? await sbGet('caisses_fret', 'pays_destination=eq.' + encodeURIComponent(pays) + '&statut=eq.a_vendre').catch(() => [])
    : [];

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Caisses jamais vidées par leur destinataire (15 jours après arrivée). Chaque caisse est vendue en un seul lot, au profit de la caisse du port.</div>';
  if (!caisses || caisses.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucune caisse non réclamée pour l\'instant.</div>';
  } else {
    for (const c of caisses) {
      const lignes = await chargerContenuCaisseFret(c.id);
      const restant = totalContenuFret(lignes);
      if (restant <= 0) continue;
      const valeurAdmin = (c.valeur_declaree || 0) * (restant / (c.quantite_arrivee || restant || 1));
      const prix = Math.round(valeurAdmin * RATIO_PRIX_LIQUIDATION_FRET);
      html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.7rem;margin-bottom:.5rem;display:flex;align-items:center;justify-content:space-between">';
      html += '<div><div style="font-size:.82rem;color:#c0b090">Lot de ' + c.leader + ' — ' + restant + ' unité(s), ' + lignes.filter(l=>l.quantite>0).length + ' type(s) d\'objet</div>';
      html += '<div style="font-size:.7rem;color:#5a4030">' + prix + ' FR</div></div>';
      html += '<button onclick="acheterLotNonReclameeFret(\'' + c.id + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;padding:.3rem .6rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Acheter le lot</button>';
      html += '</div>';
    }
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function acheterLotNonReclameeFret(caisseId) {
  const rows = typeof sbGet === 'function' ? await sbGet('caisses_fret', 'id=eq.' + encodeURIComponent(caisseId)).catch(() => []) : [];
  const caisse = rows && rows[0];
  if (!caisse || caisse.statut !== 'a_vendre' || caisse.pays_destination !== (state.country || 'republic')) {
    showToast('Indisponible', '', false);
    return;
  }
  const lignes = await chargerContenuCaisseFret(caisseId);
  const disponibles = lignes.filter(l => l.quantite > 0);
  const restant = totalContenuFret(disponibles);
  if (restant <= 0) { showToast('Lot déjà vendu', '', false); return; }

  // Le lot est indivisible (achat en bloc du contenu restant) : si la capacite individuelle ne
  // suffit pas, STOP plutot que de fractionner/supprimer silencieusement des objets (exigence
  // explicite du 24 aout 2026).
  const placeDisponible = (typeof PLAFOND_INVENTAIRE_EMPILABLE !== 'undefined' ? PLAFOND_INVENTAIRE_EMPILABLE : 100) - (typeof getTotalInventaire === 'function' ? getTotalInventaire() : 0);
  if (placeDisponible < restant) {
    showToast('Capacité insuffisante', 'Ce lot contient ' + restant + ' unité(s) ; il ne peut être vendu qu\'en bloc. Libérez au moins ' + (restant - placeDisponible) + ' place(s) avant d\'acheter.', false);
    return;
  }

  const valeurAdmin = (caisse.valeur_declaree || 0) * (restant / (caisse.quantite_arrivee || restant || 1));
  const prix = Math.round(valeurAdmin * RATIO_PRIX_LIQUIDATION_FRET);
  if ((state.arg || 0) < prix) { showToast('Fonds insuffisants', '', false); return; }

  // Reservation optimiste (meme tolerance de course que le reste du jeu) : on marque 'vendue'
  // avant de crediter/transferer, la relecture ci-dessus limite le risque de double-achat.
  const maj = typeof sbUpdate === 'function' ? await sbUpdate('caisses_fret', 'id=eq.' + encodeURIComponent(caisseId) + '&statut=eq.a_vendre', { statut: 'vendue' }).catch(() => null) : null;
  if (!maj || maj.length === 0) { showToast('Indisponible', 'Ce lot vient d\'être acheté par quelqu\'un d\'autre.', false); return; }

  state.arg -= prix;
  if (typeof crediterCaisseBatiment === 'function') await crediterCaisseBatiment(caisse.pays_destination, caisse.building_destination, prix).catch(() => {});
  for (const l of disponibles) {
    if (typeof addToInventory === 'function') addToInventory({ ...l.objet, qty: l.quantite });
    else { state.inventory = state.inventory || []; state.inventory.push({ ...l.objet, qty: l.quantite }); }
    if (typeof sbUpdate === 'function') await sbUpdate('contenu_caisses_fret', 'id=eq.' + encodeURIComponent(l.id), { quantite: 0 }).catch(() => {});
  }
  if (typeof sbSavePersonnage === 'function') await sbSavePersonnage(state).catch(() => {});

  updateUI();
  document.getElementById('modal-postes').classList.remove('open');
  showToast('Lot acheté !', restant + ' unité(s) ajoutée(s) à votre inventaire.', true, true);
  addJournalEntry('Achat d\'un lot de marchandises non réclamées au port (' + prix + ' FR versés à la caisse du port).', 'event-good');
}

// ---- FOUILLE GENERIQUE (inventaire) ----
// Detection generique : tout objet legal:false est repere (reutilise le flag deja universel du
// jeu). Seuls les types deja dotes d'un vrai traitement de confiscation ailleurs dans le jeu
// (whitelist deja utilisee par les douanes, doPasserDouanesAeroport, plateau-navigation.js)
// declenchent une consequence reelle -- ne pas etendre cette liste sans decision explicite de
// peine pour les autres types legal:false existants (kompromat, contrebande, document_falsifie,
// tract, photo_compromettante, explosif, loukoum_contrebande).
const OBJET_ILLEGAL_PEINE_CONNUE = { arme: true, poison: true, tract_calomnieux: true };

function identifierObjetsIllegaux(inventory) {
  return (inventory || []).filter(i => i && i.legal === false);
}

function separerObjetsIllegauxConnus(objets) {
  return {
    connus: objets.filter(o => OBJET_ILLEGAL_PEINE_CONNUE[o.type]),
    nonReconnus: objets.filter(o => !OBJET_ILLEGAL_PEINE_CONNUE[o.type])
  };
}

// Retire purement et simplement les objets confisques de l'inventaire local (aucune convocation,
// aucune peine -- ces consequences sont ajoutees separement par chaque appelant ci-dessous, qui
// ont des besoins differents : soumission = convocation deferee, fuite ratee = peine immediate).
function confisquerObjets(objetsConnus) {
  if (!objetsConnus || objetsConnus.length === 0) return '';
  const noms = objetsConnus.map(o => o.name).join(', ');
  state.inventory = (state.inventory || []).filter(i => !objetsConnus.includes(i));
  return noms;
}

// Se soumettre au controle : confiscation + convocation deferee, EXACTEMENT la meme consequence
// que le controle douanier (motif possession_illegale_douane reutilise tel quel, aucune peine
// inventee).
function appliquerConsequencesSoumissionFouille(objetsConnus) {
  const noms = confisquerObjets(objetsConnus);
  if (!noms) return;

  if (!state.convocations) state.convocations = [];
  state.convocations.push({
    motif: 'possession_illegale_douane',
    jourEmission: state.day || 1,
    heureEmission: state.hour || 8,
    jourLimite: (state.day || 1) + 1,
    heureLimite: state.hour || 8,
    traitee: false
  });
  updateUI();
  showToast('Objets confisqués', noms + ' confisqué(s). Convocation au commissariat sous 24h.', false, true);
  addJournalEntry('Contrôle policier : objets prohibés confisqués (' + noms + '). Convocation reçue.', 'event-bad');
}

// Fuite ratee : confiscation + peine IMMEDIATE (procederArrestation, meme motif
// possession_illegale_douane que la convocation deferee ci-dessus -- aucune peine inventee) puis
// +1 jour cumulatif (ajouterJourFuiteRatee, precedent additif existant). La peine immediate est
// necessaire ici : sans elle, ajouterJourFuiteRatee n'aurait aucune detention de base sur
// laquelle cumuler (state.estEmprisonne serait absent).
function appliquerConsequencesFuiteRatee(objetsConnus) {
  const noms = confisquerObjets(objetsConnus);
  if (typeof procederArrestation === 'function') procederArrestation('possession_illegale_douane', false, false);
  ajouterJourFuiteRatee();
  updateUI();
  showToast('Fuite ratée', (noms ? noms + ' confisqué(s). ' : '') + 'Vous êtes arrêté(e) et écroué(e).', false, true);
  addJournalEntry('Fuite ratée face à un contrôle policier' + (noms ? ' — objets confisqués (' + noms + ')' : '') + '.', 'event-bad');
}

// Echec de fuite : +1 jour de detention CUMULATIF (jamais substitutif). Reutilise l'unique
// precedent additif existant du jeu (evasion ratee/rebellion reussie, memes lignes plus haut
// dans ce fichier -- state.estEmprisonne.jours += 1 uniquement si une peine est deja active).
// A appeler APRES que la peine de base (procederArrestation) ait ete posee dans le meme flux.
function ajouterJourFuiteRatee() {
  if (state.estEmprisonne) {
    state.estEmprisonne.jours += 1;
    state.estEmprisonne.jourFin += 1;
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
  }
}

// ---- FORMULE COMMUNE DES JETS OPPOSES (arbitrage valide du 24 aout 2026) ----
// chancePJ = clamp(50 + 5*(caracPJ - caracAdversaire), 10, 90). Tirage 1-100, succes PJ si
// tirage <= chancePJ. Utilisee identiquement pour DIS vs PER (surveillance), DUP vs PER
// (controle) et VOL vs VOL (fuite) -- seule la paire de caracteristiques change.
function calculerChancePJ(caracPJ, caracAdversaire) {
  return Math.max(10, Math.min(90, 50 + 5 * (caracPJ - caracAdversaire)));
}

// Normalisation de la Discretion (ressource 0-100, pas une caracteristique sur l'echelle
// habituelle) : DIS_effective = 8 + (state.dis/10). Arbitrage valide, verifie sur les 3 exemples
// de controle fournis (DIS 0/50/100 -> 8/13/18).
function calculerDisEffective() {
  return 8 + (state.dis || 0) / 10;
}

// ---- HOOKS SECURITE/SOCIAL/POP EN ATTENTE (aucune valeur arretee, ne pas inventer) ----
// Deux effets prevus par le cahier des charges restent volontairement NON cables faute de
// chiffres valides (les 3 autres -- SOCIAL/POP lies au controle direct du commissaire -- sont
// hors perimetre de ce lot, voir le controle direct PJ->PJ traite separement) :
//  - SECURITE gagnee par policier deploye (ici, dans verifierSurveillancePolicePJ, a chaque
//    fois qu'une patrouille est presente -- pas encore d'index SECURITE local a incrementer) ;
//  - SOCIAL perdu par policier deploye (meme point d'ancrage).
// Ne pas cabler de chiffre ici sans arbitrage explicite.

// ---- CHAINE AUTOMATIQUE : surveillance -> controle -> fouille -> soumission/fuite ----
// Point d'entree appele depuis enterRoom (plateau-navigation.js) et afficherNoeudRue
// (plateau-rue-centrale.js) a chaque fois que le PJ ARRIVE dans une piece/rue. Ne concerne QUE
// le joueur local agissant (son propre inventaire, son propre etat). Le controle direct du
// commissaire sur un autre PJ (complexite multi-joueur reelle : pas de canal live vers le
// client cible) est explicitement HORS PERIMETRE de ce lot et traite separement.
async function verifierSurveillancePolicePJ(buildingId, roomId, rueNoeudId) {
  if (state.estEmprisonne) return; // deja incarcere, rien a controler
  const pays = state.country || 'republic';
  const ville = state.currentCity;
  if (!ville) return;

  const effectifs = await chargerEffectifsPolice(pays, ville).catch(() => null);
  if (!effectifs || !effectifs.policiers.length) return;

  const enRue = !!rueNoeudId;
  const presents = enRue
    ? effectifs.policiers.filter(p => p.rueNoeudId === rueNoeudId)
    : effectifs.policiers.filter(p => p.buildingId === buildingId && p.roomId === roomId);
  if (presents.length === 0) return;

  let perGroupe = calculerPerGroupePolice(presents);
  if (enRue) perGroupe -= DILUTION_RUE_PER_POLICE; // dilution rue uniquement, jamais en piece

  const disEff = calculerDisEffective();
  const chanceDetection = calculerChancePJ(disEff, perGroupe);
  const tirage = Math.floor(Math.random() * 100) + 1;
  if (tirage <= chanceDetection) return; // PJ passe inapercu, aucune trace, silence total

  const volGroupe = calculerVolGroupePolice(presents);
  resoudreControlePoliceAutomatique(perGroupe, volGroupe);
}

// Etape 2 : controle (DUP PJ vs PER groupe police). Succes PJ = relache sans fouille. Echec =
// fouille (aucun jet supplementaire, la fouille elle-meme est automatique et certaine une fois
// le controle perdu -- seule la decouverte d'objets reconnus declenche une suite).
function resoudreControlePoliceAutomatique(perGroupe, volGroupe) {
  showToast('Contrôle de police', 'Une patrouille vous arrête pour un contrôle d\'identité.', false);
  addJournalEntry('Contrôlé(e) par une patrouille de police.', 'event-bad');

  const dup = getStatEffective('DUP');
  const chanceConvaincre = calculerChancePJ(dup, perGroupe);
  const tirage = Math.floor(Math.random() * 100) + 1;
  if (tirage <= chanceConvaincre) {
    showToast('Contrôle terminé', 'Vous convainquez la patrouille de vous laisser repartir.', true, true);
    addJournalEntry('Contrôle de police évité par la persuasion.', 'event-good');
    return;
  }

  const { connus } = separerObjetsIllegauxConnus(identifierObjetsIllegaux(state.inventory));
  if (connus.length === 0) {
    showToast('Fouille effectuée', 'Rien d\'illégal trouvé sur vous. Vous êtes relâché(e).', true, true);
    addJournalEntry('Fouille policière : rien trouvé.', '');
    return;
  }

  ouvrirChoixSoumissionFuite(connus, volGroupe);
}

// Etape 3 : choix explicite du joueur (jamais automatique) -- reutilise le gabarit du modal
// d'interception existant (memes ids #postes-modal-title/#postes-body/#modal-postes, voir
// l'arrestation classique un peu plus haut dans ce fichier). L'etat transitoire (objets trouves,
// VOL adverse) est stocke le temps du choix dans une variable de module dediee, aucune autre
// fonction ne le lit.
let _policeFouilleEnCours = null;
function ouvrirChoixSoumissionFuite(objetsConnus, volAdversaire) {
  _policeFouilleEnCours = { objetsConnus, volAdversaire };
  const noms = objetsConnus.map(o => o.name).join(', ');
  document.getElementById('postes-modal-title').textContent = 'Fouille policière';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1rem">' +
    '<div style="font-size:.85rem;color:#cc4444;margin-bottom:.8rem">Objets prohibés découverts : ' + noms + '</div>' +
    '<div style="display:flex;flex-direction:column;gap:.5rem">' +
    '<button onclick="doSeSoumettrePolice()" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1rem;border:1px solid #4a6a4a;background:transparent;color:#6a9a6a;cursor:pointer"><i class="ti ti-check" style="font-size:.8rem"></i> Se soumettre</button>' +
    '<button onclick="doTenterFuitePolice()" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1rem;border:1px solid #8a6a20;background:transparent;color:#8a8060;cursor:pointer"><i class="ti ti-run" style="font-size:.8rem"></i> Tenter de fuir</button>' +
    '</div></div>';
  document.getElementById('modal-postes').classList.add('open');
}

function doSeSoumettrePolice() {
  document.getElementById('modal-postes')?.classList.remove('open');
  if (!_policeFouilleEnCours) return;
  appliquerConsequencesSoumissionFouille(_policeFouilleEnCours.objetsConnus);
  _policeFouilleEnCours = null;
}

// Etape 4 (si fuite choisie) : VOL PJ vs VOL groupe police, AUCUN bonus d'effectif (regle
// explicite, distincte de PER). Fuite reussie = le PJ garde tout, aucune trace/enquete inventee.
// Fuite ratee = confiscation + peine immediate + jour cumulatif (appliquerConsequencesFuiteRatee).
function doTenterFuitePolice() {
  document.getElementById('modal-postes')?.classList.remove('open');
  if (!_policeFouilleEnCours) return;
  const { objetsConnus, volAdversaire } = _policeFouilleEnCours;
  _policeFouilleEnCours = null;

  const vol = getStatEffective('VOL');
  const chanceFuite = calculerChancePJ(vol, volAdversaire);
  const tirage = Math.floor(Math.random() * 100) + 1;
  if (tirage <= chanceFuite) {
    showToast('Fuite réussie !', 'Vous échappez à la patrouille avec vos objets.', true, true);
    addJournalEntry('Fuite réussie face à un contrôle policier.', 'event-good');
    return;
  }
  appliquerConsequencesFuiteRatee(objetsConnus);
}

function getBuildingIdCentreMultimodal(ville, pays) {
  // BUG CORRIGE LE 8 AOUT 2026 : la map utilisait 'port-sainte-marie'/'montrouge' comme cles,
  // mais les appelants (VILLES_PAR_EMPIRE, confirmerTransport/executerVoyage) passent toujours
  // le vrai id de ville 'ville_a'/'ville_b' -> aucune correspondance, repli silencieux sur
  // 'centre-multinodal-ville_a', batiment inexistant.
  if (ville === 'capitale') return 'centre-multinodal-luthecia'; // hub partage, contenu par buildingContext selon l'empire
  // Les hubs des villes secondaires ne sont construits que pour Republia pour l'instant (voir
  // meme choix deja fait pour le systeme fiscal/electoral). Sans ce garde-fou, un joueur d'un
  // autre empire se retrouvait a entrer dans le Centre Multimodal de Port-Sainte-Marie (le
  // batiment existe globalement, meme s'il n'a de sens que pour Republia) plutot que de
  // simplement rester dans sa propre rue faute d'equivalent construit.
  if (pays && pays !== 'republic') return null;
  const map = { 'ville_a': 'centre-multinodal-port-sainte-marie', 'ville_b': 'centre-multinodal-montrouge' };
  return map[ville] || null;
}

function getBuildingIdDispensaire(ville) {
  return getCaisseLocaleId('dispensaire', ville);
}

function getBuildingIdTribunal(ville) {
  return getCaisseLocaleId('tribunal', ville);
}

// A3 (lot finition financiere locale, 17 aout 2026) : contrairement a Commissariat/Dispensaire/
// Tribunal ci-dessus, la capitale a deja une caisse 'mairie-capitale' active (solde reel, affichee
// en en-tete via ROOMS_AVEC_CAISSE) -- lui appliquer getCaisseLocaleId directement migrerait
// silencieusement vers la cle 'mairie_capitale', orphelinant l'argent existant et figeant
// l'affichage. La capitale garde donc son id historique ; seules PSM/Montrouge (qui n'ont jamais
// eu de caisse mairie propre) recoivent une cle locale generique.
function getBuildingIdMairie(ville) {
  return (!ville || ville === 'capitale') ? 'mairie-capitale' : getCaisseLocaleId('mairie', ville);
}

// ---- FINANCEMENT COMMUNAL (Maire Adjoint depuis le 10 aout 2026 -- transfert complet, plus
// partage avec le Maire) : virement instantane depuis la caisse municipale ----
async function ouvrirModalFinancerCommunal(pa, cost) {
  if (state.poste?.id !== 'maire_adjoint') {
    showToast('Acces refuse', 'Reserve au Maire Adjoint.', false);
    return;
  }
  const ville = state.currentCity;
  const budgetMuni = await chargerBudgetMunicipal();
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  // Stade/Marche : id codes en dur auparavant, sans ville -- une subvention votee depuis
  // Montrouge creditait la meme caisse que Luthecia (A3, lot caisses locales, 16 aout 2026).
  const options = [
    { id: getBuildingIdCommissariat(ville), label: 'Commissariat' },
    { id: getBuildingIdCentreMultimodal(ville), label: 'Centre Multimodal' },
    { id: getCaisseLocaleId('stade', ville), label: 'Stade' },
    { id: getCaisseLocaleId('marche', ville), label: 'Marche' },
    { id: getBuildingIdDispensaire(ville), label: 'Dispensaire' },
    { id: getBuildingIdTribunal(ville), label: 'Tribunal' }
  ];

  document.getElementById('postes-modal-title').textContent = 'Financer un batiment communal';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Caisse municipale disponible : <strong style="color:#C9A84C">' + (budgetMuni?.caisse || 0).toLocaleString('fr-FR') + ' ' + cur + '</strong></div>';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">BATIMENT</div>';
  html += '<select id="financer-batiment-id" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.7rem">';
  options.forEach(o => { html += '<option value="' + o.id + '">' + o.label + '</option>'; });
  html += '</select>';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">MONTANT (' + cur + ')</div>';
  html += '<input type="number" id="financer-montant" min="0" value="500" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.8rem"/>';
  html += '<button onclick="confirmerFinancementCommunal(' + pa + ',' + cost + ')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Virer les fonds</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerFinancementCommunal(pa, cost) {
  const buildingId = document.getElementById('financer-batiment-id')?.value;
  const montant = Math.max(0, parseInt(document.getElementById('financer-montant')?.value || '0'));
  document.getElementById('modal-postes').classList.remove('open');
  if (!buildingId || montant <= 0) return;

  const budgetMuni = await chargerBudgetMunicipal();
  if (!budgetMuni || (budgetMuni.caisse || 0) < montant) {
    showToast('Fonds insuffisants', 'La caisse municipale ne couvre pas ce montant.', false);
    return;
  }
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }
  budgetMuni.caisse -= montant;
  if (typeof sbSaveBudgetMunicipal === 'function') await sbSaveBudgetMunicipal(budgetMuni.key, budgetMuni).catch(() => {});
  await crediterCaisseBatiment(state.country, buildingId, montant);

  const cur = COUNTRIES[state.country]?.cur || 'FR';
  showToast('Virement effectue', montant.toLocaleString('fr-FR') + ' ' + cur + ' verses.', true, true);
  addJournalEntry('Virement de ' + montant.toLocaleString('fr-FR') + ' ' + cur + ' de la caisse municipale vers ' + buildingId + '.', 'event-good');
}

// ---- SUBVENTION MINISTERIELLE (Ministre de l'Interieur) : commissariat de n'importe
//      quelle ville + QHS, depuis la caisse du Ministere ----
async function ouvrirModalFinancerMinInt(pa, cost) {
  if (state.poste?.id !== 'min_int') {
    showToast('Acces refuse', "Reserve au Ministre de l'Interieur.", false);
    return;
  }
  // Une entree par ville reelle du pays (A3, lot caisses locales, 16 aout 2026) -- remplace
  // l'ancienne option unique "Commissariat (Port-Sainte-Marie / Montrouge)" qui fusionnait deux
  // villes sous un id code en dur, sans jamais passer par getBuildingIdCommissariat (deja
  // corrigee, mais court-circuitee ici). 'qhs' reste inchange, infrastructure nationale unique.
  const villesCommissariat = typeof getVillesReelles === 'function' ? getVillesReelles(state.country) : ['capitale'];
  const options = villesCommissariat.map(v => ({
    id: getBuildingIdCommissariat(v),
    label: 'Commissariat de ' + (WORLD[state.country]?.[v]?.name || v)
  }));
  options.push({ id: 'qhs', label: 'QHS' });
  const caisse = await chargerCaisseBatiment(state.country, 'gouvernement-min_int');
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  document.getElementById('postes-modal-title').textContent = 'Allouer une subvention';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Caisse du Ministere disponible : <strong style="color:#C9A84C">' + (caisse?.solde || 0).toLocaleString('fr-FR') + ' ' + cur + '</strong></div>';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">DESTINATION</div>';
  html += '<select id="subvention-batiment-id" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.7rem">';
  options.forEach(o => { html += '<option value="' + o.id + '">' + o.label + '</option>'; });
  html += '</select>';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">MONTANT (' + cur + ')</div>';
  html += '<input type="number" id="subvention-montant" min="0" value="500" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.8rem"/>';
  html += '<button onclick="confirmerSubventionMinInt(' + pa + ',' + cost + ')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Verser la subvention</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerSubventionMinInt(pa, cost) {
  const buildingId = document.getElementById('subvention-batiment-id')?.value;
  const montant = Math.max(0, parseInt(document.getElementById('subvention-montant')?.value || '0'));
  document.getElementById('modal-postes').classList.remove('open');
  if (!buildingId || montant <= 0) return;
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }

  const montantVerse = await debiterCaisseBatimentPlafonne(state.country, 'gouvernement-min_int', montant);
  if (montantVerse <= 0) {
    showToast('Fonds insuffisants', "La caisse du Ministere ne couvre pas ce montant.", false);
    return;
  }
  await crediterCaisseBatiment(state.country, buildingId, montantVerse);

  const cur = COUNTRIES[state.country]?.cur || 'FR';
  showToast('Subvention versee', montantVerse.toLocaleString('fr-FR') + ' ' + cur + ' verses.', true, true);
  addJournalEntry('Subvention de ' + montantVerse.toLocaleString('fr-FR') + ' ' + cur + " du Ministere de l'Interieur vers " + buildingId + '.', 'event-good');
}

// A3 (lot judiciaire, 16 aout 2026) : city desormais un parametre explicite (5e, en fin de
// liste pour ne rien casser des appelants qui l'ignoreraient encore) -- la ville d'une
// detention est celle de l'affaire/enquete/arrestation qui la motive, jamais automatiquement
// la ville du joueur/agent qui execute ce code a cet instant. Repli sur state.currentCity
// UNIQUEMENT si l'appelant ne connait vraiment aucune ville (compatibilite), jamais si la
// vraie ville est connue.
async function enregistrerDetention(nom, raison, jourFin, qhs, city) {
  if (!state.prisonniers) state.prisonniers = [];
  const entree = { nom, depuis: 'Jour ' + (state.day || 1), raison };
  if (jourFin !== undefined && jourFin !== null) entree.jourFin = jourFin;
  if (qhs) entree.qhs = true;
  state.prisonniers.push(entree);

  if (typeof sbCreerDetention === 'function') {
    await sbCreerDetention({
      country: state.country || 'republic',
      city: city || state.currentCity || 'capitale',
      nom, raison,
      jour_debut: state.day || 1,
      jour_fin: jourFin !== undefined ? jourFin : null,
      qhs: !!qhs
    }).catch(() => {});
  }
}

function doMenerEnquete(pa, cost) {
  const contacts = state.contacts || [];
  const contactsSection = contacts.length === 0
    ? '<div style="font-size:.8rem;color:#7a5020;font-style:italic;padding:.5rem;background:#0f0805;border:1px solid #2a1810">Votre repertoire est vide. Enregistrez la personne visee au prealable.</div>'
    : contacts.map(c => '<label style="display:flex;align-items:center;gap:.5rem;font-size:.85rem;color:#c0b090;cursor:pointer;padding:.2rem 0"><input type="radio" name="enquete-cible" value="' + c.name + '" style="accent-color:#C9A84C"/> ' + c.name + ' — ' + (c.role || '') + '</label>').join('');

  document.getElementById('postes-modal-title').textContent = "Mener l'enquete";
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1rem">' +
    '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:1rem">Cout : 250 FR, preleves sur la caisse du commissariat. Fouille le passe recent de la cible.</div>' +
    '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.5rem">CIBLE</div>' +
    contactsSection +
    '<button onclick="confirmerMenerEnquete(' + pa + ',' + cost + ')" style="margin-top:1rem;font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Ouvrir l enquete</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerMenerEnquete(pa, cost) {
  const cibleInput = document.querySelector('input[name="enquete-cible"]:checked');
  if (!cibleInput) { showToast('Cible requise', 'Choisissez une personne du repertoire.', false); return; }
  const cible = cibleInput.value;
  document.getElementById('modal-postes').classList.remove('open');

  const pays = state.country;
  const ville = state.currentCity;
  const buildingId = typeof getBuildingIdCommissariat === 'function' ? getBuildingIdCommissariat(ville) : 'commissariat';
  const rEnquete = await deduireCoutOrdre({ pa, cost, payeur: { type: 'institution', pays, buildingId } });
  if (!rEnquete.ok) {
    showToast(rEnquete.raison === 'pa_insuffisants' ? 'PA insuffisants' : 'Caisse insuffisante',
      rEnquete.raison === 'pa_insuffisants' ? '' : 'La caisse du commissariat ne couvre pas le cout de l enquete.', false);
    return;
  }

  const perCommissaire = getStatEffective('PER');
  const infCommissaire = state.inf || 0;
  const cibleInfos = typeof sbGetStatsInfluenceJoueur === 'function' ? await sbGetStatsInfluenceJoueur(cible) : { per: 8, inf: 0 };
  const isn = (typeof getIndiceVille === 'function') ? getIndiceVille(pays, ville, 'isn') : ((typeof INDICES_NATIONAUX !== 'undefined' && INDICES_NATIONAUX[pays]?.ISN) || 30);

  let taux = 35 + (perCommissaire - cibleInfos.per) * 2 + (infCommissaire - cibleInfos.inf) * 0.3 + (isn - 45) / 5;
  taux = (typeof consommerBonusBenediction === 'function') ? consommerBonusBenediction(taux) : taux;
  taux = Math.max(10, Math.min(90, Math.round(taux)));

  const toutes = typeof sbGetActionsTracables === 'function' ? await sbGetActionsTracables(pays, ville, state.day || 1).catch(() => []) : [];
  const candidats = (toutes || []).filter(a => a.auteur === cible && !a.decouvert);

  if (candidats.length === 0) {
    addJournalEntry('Enquete menee contre ' + cible + ' : rien de compromettant trouve. -250 FR.', 'event-info');
    showToast('Enquete infructueuse', 'Rien de compromettant trouve sur ' + cible + '.', false);
    return;
  }

  const roll = Math.floor(Math.random() * 100) + 1;
  if (roll > taux) {
    addJournalEntry('Enquete menee contre ' + cible + ' : indices insuffisants pour aboutir. -250 FR.', 'event-info');
    showToast('Enquete infructueuse', 'Le dossier n a pas abouti cette fois (' + taux + '% de chances).', false);
    return;
  }

  const action = candidats[0];
  if (typeof sbUpdate === 'function') {
    await sbUpdate('actions_tracables', 'id=eq.' + encodeURIComponent(action.id), { decouvert: true }).catch(() => {});
  }
  // Enquete menee par un commissaire depuis sa propre ville (le journal d'actions tracables
  // fouille est deja filtre sur "ville" ci-dessus, A3 lot judiciaire) : l'affaire appartient
  // donc reellement a cette ville, pas seulement par defaut.
  if (typeof enregistrerDetention === 'function') enregistrerDetention(cible, action.type_action || 'Acte illegal decouvert par enquete', (state.day || 1) + 2, undefined, ville).catch(() => {});
  if (typeof transmettreAffaireAuTribunal === 'function') transmettreAffaireAuTribunal(cible, action.type_action || 'Acte illegal decouvert par enquete', ville);
  if (typeof envoyerNotificationVraiJoueur === 'function') {
    await envoyerNotificationVraiJoueur(cible, 'Enquete de police', 'Une enquete a mis en evidence un acte illegal vous concernant. Vous avez ete place en garde a vue.');
  }
  addExternalEvent('ENQUETE : ' + cible + ' a ete demasque(e) et place(e) en garde a vue.', 'local');
  addJournalEntry('Enquete reussie contre ' + cible + ' (' + taux + '% de chances). Affaire transmise au tribunal. -250 FR.', 'event-good');
  showToast('Enquete reussie', cible + ' a ete demasque(e) et place(e) en garde a vue.', true, true);
}

function doOrganiserFilature(pa, cost) {
  const contacts = (state.contacts || []).filter(c => c.isPJ);
  const contactsSection = contacts.length === 0
    ? '<div style="font-size:.8rem;color:#7a5020;font-style:italic;padding:.5rem;background:#0f0805;border:1px solid #2a1810">Aucun PJ enregistre dans votre repertoire.</div>'
    : contacts.map(c => '<label style="display:flex;align-items:center;gap:.5rem;font-size:.85rem;color:#c0b090;cursor:pointer;padding:.2rem 0"><input type="radio" name="filature-cible" value="' + c.name + '" style="accent-color:#C9A84C"/> ' + c.name + '</label>').join('');

  document.getElementById('postes-modal-title').textContent = 'Organiser une filature';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1rem">' +
    '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:1rem">Cout : 150 FR, preleves sur la caisse du commissariat. Rapport des deplacements des dernieres 24h si reussite.</div>' +
    '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.5rem">CIBLE</div>' +
    contactsSection +
    '<button onclick="confirmerOrganiserFilature(' + pa + ',' + cost + ')" style="margin-top:1rem;font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Lancer la filature</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerOrganiserFilature(pa, cost) {
  const cibleInput = document.querySelector('input[name="filature-cible"]:checked');
  if (!cibleInput) { showToast('Cible requise', 'Choisissez un PJ du repertoire.', false); return; }
  const cible = cibleInput.value;
  document.getElementById('modal-postes').classList.remove('open');

  const pays = state.country;
  const ville = state.currentCity;
  const buildingId = typeof getBuildingIdCommissariat === 'function' ? getBuildingIdCommissariat(ville) : 'commissariat';
  const rFilature = await deduireCoutOrdre({ pa, cost, payeur: { type: 'institution', pays, buildingId } });
  if (!rFilature.ok) {
    showToast(rFilature.raison === 'pa_insuffisants' ? 'PA insuffisants' : 'Caisse insuffisante',
      rFilature.raison === 'pa_insuffisants' ? '' : 'La caisse du commissariat ne couvre pas le cout de la filature.', false);
    return;
  }

  // Doctrine V2, formule validee : P = Base(50) + 2*(PER_groupe-13) - (PER_cible-13)
  // + (Securite_ville-50)/5 + (INF_commissaire-INF_cible)*0.3
  const perCommissaire = getStatEffective('PER');
  const infCommissaire = state.inf || 0;
  const cibleInfos = typeof sbGetStatsInfluenceJoueur === 'function' ? await sbGetStatsInfluenceJoueur(cible) : { per: 8, inf: 0 };
  const isnVille = (typeof getIndiceVille === 'function') ? getIndiceVille(pays, ville, 'isn') : 30;

  let taux = 50 + 2 * (perCommissaire - 13) - (cibleInfos.per - 13) + (isnVille - 50) / 5 + (infCommissaire - cibleInfos.inf) * 0.3;
  taux = (typeof consommerBonusBenediction === 'function') ? consommerBonusBenediction(taux) : taux;
  taux = Math.max(10, Math.min(90, Math.round(taux)));

  const roll = Math.floor(Math.random() * 100) + 1;

  if (roll > taux) {
    addJournalEntry('Filature de ' + cible + ' : la cible a seme la filature. -150 FR.', 'event-info');
    showToast('Filature echouee', 'Vous avez perdu la trace de ' + cible + ' (' + taux + '% de chances).', false);
    return;
  }

  const jourMin = Math.max(1, (state.day || 1) - 1);
  const historique = typeof sbGetHistoriqueDeplacements === 'function' ? await sbGetHistoriqueDeplacements(cible, jourMin).catch(() => []) : [];

  document.getElementById('postes-modal-title').textContent = 'Rapport de filature — ' + cible;
  let html = '<div style="padding:1rem">';
  if (!historique || historique.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucun deplacement enregistre sur les dernieres 24h.</div>';
  } else {
    historique.forEach(h => {
      html += '<div style="padding:.4rem .6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.3rem;font-size:.78rem;color:#c0b090">Jour ' + h.jour + ' ' + (h.heure || '') + ' — ' + (h.building_id || '?') + ' / ' + (h.room_id || '?') + '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');

  addJournalEntry('Filature reussie contre ' + cible + ' (' + taux + '% de chances). -150 FR.', 'event-good');
}

function doOrganiserChasseHomme(pa, cost) {
  const contacts = (state.contacts || []).filter(c => c.isPJ);
  const contactsSection = contacts.length === 0
    ? '<div style="font-size:.8rem;color:#7a5020;font-style:italic;padding:.5rem;background:#0f0805;border:1px solid #2a1810">Aucun PJ enregistre dans votre repertoire.</div>'
    : contacts.map(c => '<label style="display:flex;align-items:center;gap:.5rem;font-size:.85rem;color:#c0b090;cursor:pointer;padding:.2rem 0"><input type="radio" name="chasse-cible" value="' + c.name + '" style="accent-color:#C9A84C"/> ' + c.name + '</label>').join('');

  document.getElementById('postes-modal-title').textContent = "Organiser une chasse a l'homme";
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1rem">' +
    '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:1rem">Cout : 300 FR, preleves sur la caisse du commissariat. La cible doit faire l objet d un avis de recherche actif.</div>' +
    '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.5rem">CIBLE</div>' +
    contactsSection +
    '<button onclick="confirmerOrganiserChasseHomme(' + pa + ',' + cost + ')" style="margin-top:1rem;font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Lancer la chasse</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerOrganiserChasseHomme(pa, cost) {
  const cibleInput = document.querySelector('input[name="chasse-cible"]:checked');
  if (!cibleInput) { showToast('Cible requise', 'Choisissez un PJ du repertoire.', false); return; }
  const cible = cibleInput.value;
  document.getElementById('modal-postes').classList.remove('open');

  const rechercheRows = typeof sbGet === 'function' ? await sbGet('personnages', `name=eq.${encodeURIComponent(cible)}&select=recherche`).catch(() => []) : [];
  const recherche = rechercheRows?.[0]?.recherche || [];
  if (!recherche || recherche.length === 0) {
    showToast('Pas recherche', cible + " ne fait l'objet d'aucun avis de recherche actif.", false);
    return;
  }

  const pays = state.country;
  const ville = state.currentCity;
  const buildingId = typeof getBuildingIdCommissariat === 'function' ? getBuildingIdCommissariat(ville) : 'commissariat';
  const rChasse = await deduireCoutOrdre({ pa, cost, payeur: { type: 'institution', pays, buildingId } });
  if (!rChasse.ok) {
    showToast(rChasse.raison === 'pa_insuffisants' ? 'PA insuffisants' : 'Caisse insuffisante',
      rChasse.raison === 'pa_insuffisants' ? '' : 'La caisse du commissariat ne couvre pas le cout de la chasse a l homme.', false);
    return;
  }

  const perCommissaire = getStatEffective('PER');
  const infCommissaire = state.inf || 0;
  const cibleInfos = typeof sbGetStatsInfluenceJoueur === 'function' ? await sbGetStatsInfluenceJoueur(cible) : { per: 8, inf: 0 };
  const isn = (typeof getIndiceVille === 'function') ? getIndiceVille(pays, ville, 'isn') : ((typeof INDICES_NATIONAUX !== 'undefined' && INDICES_NATIONAUX[pays]?.ISN) || 30);

  let taux = 45 + (perCommissaire - cibleInfos.per) * 2 + (infCommissaire - cibleInfos.inf) * 0.3 + (isn - 45) / 5;
  taux = (typeof consommerBonusBenediction === 'function') ? consommerBonusBenediction(taux) : taux;
  taux = Math.max(10, Math.min(90, Math.round(taux)));

  const roll = Math.floor(Math.random() * 100) + 1;

  if (roll > taux) {
    addJournalEntry('Chasse a l homme contre ' + cible + ' : localisation echouee (' + taux + '% de chances). -300 FR.', 'event-info');
    showToast('Chasse infructueuse', cible + ' reste introuvable pour l instant.', false);
    return;
  }

  const motif = recherche[0]?.acte || 'Avis de recherche';
  // Chasse a l'homme organisee depuis le commissariat du chasseur (meme raisonnement que
  // confirmerMenerEnquete, A3 lot judiciaire) : la cible est ramenee/detenue dans cette ville.
  if (typeof enregistrerDetention === 'function') await enregistrerDetention(cible, motif, (state.day || 1) + 3, undefined, ville);
  if (typeof sbUpdate === 'function') await sbUpdate('personnages', `name=eq.${encodeURIComponent(cible)}`, { recherche: [] }).catch(() => {});
  if (typeof envoyerNotificationVraiJoueur === 'function') {
    await envoyerNotificationVraiJoueur(cible, 'Arrestation', 'Vous avez ete localise(e) et arrete(e) suite a un avis de recherche.');
  }
  addExternalEvent('CHASSE A L HOMME : ' + cible + ' a ete localise(e) et arrete(e).', 'local');
  addJournalEntry('Chasse a l homme reussie contre ' + cible + ' (' + taux + '% de chances). -300 FR.', 'event-good');
  showToast('Chasse reussie', cible + ' a ete localise(e) et arrete(e).', true, true);
}

async function chargerNiveauPrison(pays, ville) {
  const key = pays + '_' + ville;
  if (typeof sbGetNiveauPrison !== 'function') return { key, niveau: 100 };
  let data = await sbGetNiveauPrison(key).catch(() => null);
  if (!data) {
    data = { niveau: 100 };
    await sbSaveNiveauPrison(key, data).catch(() => {});
  }
  return { key, niveau: 100, ...data };
}

async function endommagerGrillePrison(pays, ville, degats) {
  const n = await chargerNiveauPrison(pays, ville);
  n.niveau = Math.max(0, n.niveau - degats);
  if (typeof sbSaveNiveauPrison === 'function') await sbSaveNiveauPrison(n.key, { niveau: n.niveau }).catch(() => {});
  await verifierSeuilsGrillePrison(pays, ville, n.niveau);
  return n.niveau;
}

// Regeneration quotidienne : puise sur la caisse du commissariat de la ville, s'arrete
// des que le budget ne suffit plus (jamais de regeneration a credit).
async function regenererGrillesPrison(pays, ville) {
  const n = await chargerNiveauPrison(pays, ville);
  if (n.niveau >= 100) return;
  const pointsVises = Math.min(REGEN_GRILLE_PAR_JOUR, 100 - n.niveau);
  const coutVise = pointsVises * COUT_REPARATION_GRILLE;
  const buildingId = getBuildingIdCommissariat(ville);
  const montantVerse = await debiterCaisseBatimentPlafonne(pays, buildingId, coutVise);
  const pointsReels = Math.floor(montantVerse / COUT_REPARATION_GRILLE);
  if (pointsReels <= 0) return;
  n.niveau = Math.min(100, n.niveau + pointsReels);
  if (typeof sbSaveNiveauPrison === 'function') await sbSaveNiveauPrison(n.key, { niveau: n.niveau }).catch(() => {});
}

async function verifierSeuilsGrillePrison(pays, ville, niveau) {
  const nomVille = (typeof WORLD !== 'undefined' && WORLD[pays]?.[ville]?.name) || ville;
  if (niveau <= 0) {
    if (typeof addExternalEvent === 'function') {
      addExternalEvent('INSURRECTION : les grilles des cellules de ' + nomVille + ' cedent sous la pression des detenus. Evasion collective en cours.', 'local');
    }
    if (typeof INDICES_NATIONAUX !== 'undefined' && INDICES_NATIONAUX[pays]) {
      INDICES_NATIONAUX[pays].POP = Math.max(0, (INDICES_NATIONAUX[pays].POP || 50) - 10);
      INDICES_NATIONAUX[pays].INF = Math.min(100, (INDICES_NATIONAUX[pays].INF || 0) + 10);
    }
    const key = pays + '_' + ville;
    if (typeof sbSaveNiveauPrison === 'function') await sbSaveNiveauPrison(key, { niveau: 100 }).catch(() => {});
  } else if (niveau <= 25) {
    if (typeof addExternalEvent === 'function') {
      addExternalEvent('Tensions carcerales a ' + nomVille + ' : les grilles des cellules menacent de ceder.', 'local');
    }
  } else if (niveau <= 50) {
    if (typeof tracerActionPourRumeur === 'function') tracerActionPourRumeur('cellules_fragilisees', nomVille);
  }
}

// Fonction generique et reutilisable : affiche le solde de la caisse d'un batiment
// public quelconque. Utilisable pour n'importe quel batiment ayant une caisse.
// ---- REPUTATION CRIMINELLE ----
function getPalierCriminel(rep) {
  if (rep >= 70) return { label: 'Parrain', bonus: 15 };
  if (rep >= 40) return { label: 'Caid', bonus: 10 };
  if (rep >= 20) return { label: 'Malfaiteur reconnu', bonus: 5 };
  return { label: 'Petit delinquant', bonus: 0 };
}

function getBonusReputationCriminelle() {
  return getPalierCriminel(state.reputationCriminelle || 0).bonus;
}

function augmenterReputationCriminelle(montant) {
  const avant = getPalierCriminel(state.reputationCriminelle || 0).label;
  state.reputationCriminelle = Math.max(0, Math.min(100, (state.reputationCriminelle || 0) + montant));
  const apres = getPalierCriminel(state.reputationCriminelle).label;
  if (apres !== avant) {
    showToast('Reputation criminelle', 'Vous etes desormais considere(e) comme : ' + apres + '.', true);
  }
}

// ---- CAMBRIOLAGE DE CAISSE (generique, reutilisable pour n'importe quel batiment) ----
function doCambriolerCaisse(buildingId, buildingLabel) {
  document.getElementById('postes-modal-title').textContent = 'Cambrioler la caisse — ' + buildingLabel;
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1rem">' +
    '<div style="font-size:.82rem;color:#a09060;margin-bottom:1rem">Tentative risquee et difficile. En cas d echec critique, vous serez demasque(e) immediatement.</div>' +
    '<button onclick="confirmerCambriolerCaisse(\'' + buildingId + '\',\'' + buildingLabel.replace(/'/g,'') + '\')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem;border:1px solid #8a2020;background:transparent;color:#cc4444;cursor:pointer">Tenter le cambriolage</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerCambriolerCaisse(buildingId, buildingLabel) {
  document.getElementById('modal-postes').classList.remove('open');
  // Deduction PA centralisee (Lot 2C) -- deduireCoutOrdre() est l'AUTORITE UNIQUE. Appelee ICI,
  // avant tout calcul et toute mutation (jet, caisse, reputation, recherche) : fail-closed. Cout
  // du que le cambriolage reussisse ou non, comme pour les actes illegaux deja migres au Lot 2A.
  const rPa = await deduireCoutOrdre({ pa: 3, cost: 0 });
  if (!rPa.ok) { showToast('PA insuffisants', '3 PA requis.', false); return; }
  const pays = state.country;
  const dup = getStatEffective('DUP');
  const ville = state.currentCity || 'capitale';
  const isn = (typeof getIndiceVille === 'function') ? getIndiceVille(pays, ville, 'isn') : ((typeof INDICES_NATIONAUX !== 'undefined' && INDICES_NATIONAUX[pays]?.ISN) || 30);
  const bonusReputation = getBonusReputationCriminelle();

  let taux = 20 + (dup - 10) * 2 - (isn - 45) / 3 + bonusReputation;
  taux = (typeof consommerBonusBenediction === 'function') ? consommerBonusBenediction(taux) : taux;
  taux = Math.max(5, Math.min(60, Math.round(taux)));

  const roll = Math.floor(Math.random() * 100) + 1;

  if (roll <= taux) {
    const caisse = typeof chargerCaisseBatiment === 'function' ? await chargerCaisseBatiment(pays, buildingId) : { solde: 0 };
    const pct = 0.10 + Math.random() * 0.15;
    const montantVole = Math.floor((caisse?.solde || 0) * pct);
    if (montantVole <= 0) {
      showToast('Caisse vide', "Il n'y avait rien a voler.", false);
      return;
    }
    if (typeof debiterCaisseBatimentPlafonne === 'function') await debiterCaisseBatimentPlafonne(pays, buildingId, montantVole);
    state.arg = (state.arg || 0) + montantVole;
    augmenterReputationCriminelle(8);
    updateUI();
    showToast('Cambriolage reussi !', '+' + montantVole.toLocaleString('fr-FR') + ' FR voles dans la caisse.', true, true);
    addJournalEntry('Cambriolage reussi contre la caisse du ' + buildingLabel + '. +' + montantVole.toLocaleString('fr-FR') + ' FR.', 'event-good');
    return;
  }

  const critique = (Math.floor(Math.random() * 100) + 1) <= 25;
  if (critique) {
    if (!state.recherche) state.recherche = [];
    state.recherche.push({ acte: 'cambriolage_caisse', type: 'delit_grave', jour: state.day || 1 });
    addExternalEvent((state.char?.name || 'Quelqu\'un') + ' a ete pris en flagrant delit de tentative de vol dans la caisse du ' + buildingLabel + ' !', 'local');
    addJournalEntry('Cambriolage rate et decouvert immediatement. Avis de recherche emis contre vous.', 'event-bad');
    showToast('Demasque !', 'Vous avez ete pris en flagrant delit. Avis de recherche emis.', false);
  } else {
    if (typeof sbTracerAction === 'function') {
      await sbTracerAction({
        id: 'cambriolage-' + Date.now() + '-' + Math.floor(Math.random() * 1000),
        auteur: state.char?.name, cible: null, type_action: 'cambriolage_caisse',
        country: pays, city: state.currentCity,
        jour: state.day || 1, jour_expiration: (state.day || 1) + 15
      }).catch(() => {});
    }
    addExternalEvent("Quelqu'un a tente de voler dans la caisse du " + buildingLabel + ', sans succes.', 'local');
    addJournalEntry('Cambriolage rate contre la caisse du ' + buildingLabel + '.', 'event-info');
    showToast('Cambriolage echoue', "Vous avez echappe a la detection pour l'instant.", false);
  }
}

// Vol de materiel de chantier — meme principe que le cambriolage de caisse (formule DUP +
// indice + reputation), mais base 60% (plus facile, materiel non surveille comme une
// caisse). Le proprietaire lui-meme peut voler son propre chantier (auto-victimisation
// parodique) : l'argent se neutralise financierement, seul le bonus de sympathie publique
// et le RP restent un vrai gain. Toujours tracable sur enquete, meme en cas de reussite.
async function doVolerMaterielChantier(pa, cost) {
  const id = state.currentBuilding;
  if (typeof refuserSiGele === 'function' && await refuserSiGele('terrain', id, 'Voler du matériel')) return;
  await chargerTerrainState(id);
  const ts = getTerrainState(id);
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const pays = state.country;
  const ville = state.currentCity || 'capitale';

  if (!ts.chantier) { showToast('Impossible', 'Aucun chantier en cours ici.', false); return; }

  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }

  document.getElementById('modal-postes')?.classList.remove('open');
  const dup = getStatEffective('DUP');
  const isn = (typeof getIndiceVille === 'function') ? getIndiceVille(pays, ville, 'isn') : ((typeof INDICES_NATIONAUX !== 'undefined' && INDICES_NATIONAUX[pays]?.ISN) || 30);
  const bonusReputation = typeof getBonusReputationCriminelle === 'function' ? getBonusReputationCriminelle() : 0;

  let taux = 60 + (dup - 10) * 2 - (isn - 45) / 3 + bonusReputation;
  taux = (typeof consommerBonusBenediction === 'function') ? consommerBonusBenediction(taux) : taux;
  taux = Math.max(15, Math.min(90, Math.round(taux)));

  const roll = Math.floor(Math.random() * 100) + 1;

  if (roll <= taux) {
    const montant = Math.floor(ts.chantier.montantTotal * 0.10);
    const estAutoVol = ts.proprietaire === state.char?.name;

    state.arg = (state.arg || 0) + montant;
    if (estAutoVol) {
      state.arg -= montant; // s'annule financierement : seul le bonus de sympathie compte
    } else if (typeof sbGet === 'function' && typeof sbUpdate === 'function') {
      const rows = await sbGet('personnages', `name=eq.${encodeURIComponent(ts.proprietaire)}`).catch(() => null);
      const proprio = rows && rows[0];
      if (proprio) await sbUpdate('personnages', `name=eq.${encodeURIComponent(ts.proprietaire)}`, { arg: (proprio.arg || 0) - montant }).catch(() => {});
    }

    ts.chantier.dateFinPrevue += 2 * 86400000;
    if (typeof modifierIndiceVille === 'function') modifierIndiceVille(pays, ville, 'social', -1);
    if (typeof INDICES_NATIONAUX !== 'undefined' && INDICES_NATIONAUX[pays]) {
      INDICES_NATIONAUX[pays].IS = Math.max(0, (INDICES_NATIONAUX[pays].IS || 45) - 1);
    }

    const nouvelEtat = setTerrainState(id, { chantier: ts.chantier });
    if (typeof sbSetTerrainState === 'function') await sbSetTerrainState(pays, id, nouvelEtat).catch(() => {});

    // Toujours tracable, meme en cas de reussite (Fred : "reste detectable sur enquete")
    if (typeof sbTracerAction === 'function') {
      await sbTracerAction({
        id: 'vol-chantier-' + Date.now() + '-' + Math.floor(Math.random() * 1000),
        auteur: state.char?.name, cible: ts.proprietaire, type_action: 'vol_materiel_chantier',
        country: pays, city: ville,
        jour: state.day || 1, jour_expiration: (state.day || 1) + 15
      }).catch(() => {});
    }
    if (typeof addExternalEvent === 'function') {
      addExternalEvent('Du matériel a disparu sur un chantier de la ville. Les curieux s\'interrogent sur qui a bien pu faire le coup.', 'local');
    }
    if (typeof sendMail === 'function' && !estAutoVol) {
      await sendMail(ts.proprietaire, 'Chef de Chantier', 'Vol de matériel !',
        'Du matériel a été volé sur votre chantier cette nuit. Perte estimée : ' + montant.toLocaleString('fr-FR') + ' ' + cur + '. Le chantier a pris 2 jours de retard. L\'opinion publique semble vous soutenir face à cette épreuve.');
    }

    updateUI();
    showToast('Vol réussi !', '+' + montant.toLocaleString('fr-FR') + ' ' + cur + (estAutoVol ? ' (auto-annulé financièrement, mais sympathie publique gagnée)' : ''), true, true);
    addJournalEntry((estAutoVol ? 'Vous mettez en scène le vol de votre propre chantier' : 'Vol de matériel sur un chantier réussi') + '. +' + montant.toLocaleString('fr-FR') + ' ' + cur + '. Chantier retardé de 2 jours.', 'event-good');
    return;
  }

  const critique = (Math.floor(Math.random() * 100) + 1) <= 25;
  if (critique) {
    if (!state.recherche) state.recherche = [];
    state.recherche.push({ acte: 'vol_materiel_chantier', type: 'delit', jour: state.day || 1, peineMaxJours: 2 });
    if (typeof addExternalEvent === 'function') {
      addExternalEvent((state.char?.name || 'Quelqu\'un') + ' a été pris en flagrant délit de vol de matériel sur un chantier !', 'local');
    }
    addJournalEntry('Vol raté et découvert immédiatement. Avis de recherche émis contre vous (peine max 2 jours).', 'event-bad');
    showToast('Démasqué !', 'Avis de recherche émis (peine max 2 jours).', false);
  } else {
    if (typeof sbTracerAction === 'function') {
      await sbTracerAction({
        id: 'voltentative-' + Date.now() + '-' + Math.floor(Math.random() * 1000),
        auteur: state.char?.name, cible: ts.proprietaire, type_action: 'tentative_vol_materiel_chantier',
        country: pays, city: ville,
        jour: state.day || 1, jour_expiration: (state.day || 1) + 15
      }).catch(() => {});
    }
    addJournalEntry('Tentative de vol de matériel ratée sur un chantier.', 'event-info');
    showToast('Vol échoué', "Vous avez échappé à la détection pour l'instant.", false);
  }
}

function doCambriolerCaisseCommissariat() {
  const buildingId = typeof getBuildingIdCommissariat === 'function' ? getBuildingIdCommissariat(state.currentCity) : 'commissariat';
  doCambriolerCaisse(buildingId, 'Commissariat');
}

async function doConsulterCaisseBatimentGenerique(buildingId, buildingLabel) {
  const pays = state.country;
  const cur = COUNTRIES[pays]?.cur || 'FR';
  document.getElementById('postes-modal-title').textContent = 'Caisse — ' + buildingLabel;
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const caisse = typeof chargerCaisseBatiment === 'function' ? await chargerCaisseBatiment(pays, buildingId) : { solde: 0 };
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1rem;text-align:center">' +
    '<div style="font-family:Bebas Neue,sans-serif;font-size:1.4rem;color:#C9A84C">' + (caisse?.solde || 0).toLocaleString('fr-FR') + ' ' + cur + '</div>' +
    '<div style="font-size:.78rem;color:#8a8060;margin-top:.4rem">Solde actuel de la caisse.</div>' +
    '</div>';
}

async function doConsulterCaisseCommissariat() {
  const buildingId = typeof getBuildingIdCommissariat === 'function' ? getBuildingIdCommissariat(state.currentCity) : 'commissariat';
  await doConsulterCaisseBatimentGenerique(buildingId, 'Commissariat');
}

// A3 (lot caisses locales, 16 aout 2026) : identifiant de caisse LOCALE, distinct du buildingId
// de navigation qui peut etre partage entre plusieurs villes (meme principe que l'armurerie :
// le buildingId de navigation reste partage intentionnellement -- 'commissariat-local'/
// 'marche'/'stade' restent les memes pieces navigables -- mais l'etat financier doit rester
// local par ville). 'categorie' est un nom stable (commissariat/tribunal/dispensaire/marche/
// stade/stade-buvette/...), 'ville' la ville reelle du batiment physique concerne. Generique :
// fonctionne pour toute categorie et toute ville de tout empire, sans exception codee en dur.
function getCaisseLocaleId(categorie, ville) {
  return categorie + '_' + (ville || 'capitale');
}

// Villes reelles d'un pays (hors zones speciales caserne/qhs, isSpecial:true) -- generique,
// fonctionne pour tout empire des qu'il possede plusieurs villes actives (A3, lot caisses
// locales, 16 aout 2026).
function getVillesReelles(country) {
  const monde = WORLD[country];
  if (!monde) return ['capitale'];
  return Object.keys(monde).filter(v => monde[v] && !monde[v].isSpecial);
}

// Repartit un montant entre les villes reelles d'un pays au prorata de leur dailyTaxRevenue
// (CITY_POPULATION[pays][ville], calcule dynamiquement -- aucun pourcentage de ville code en
// dur), independamment de villeFiscale/state.currentCity (arbitrage du 24 aout 2026, suite a la
// verification confirmant que verifierEffetsEtDistributionFiscale() creditait auparavant une
// seule ville arbitraire -- celle du PJ declencheur -- pour tribunal/commissariat). Methode du
// plus fort reste (Hamilton) pour l'arrondi : chaque ville recoit Math.floor(sa part exacte),
// puis le reliquat (montantTotal - somme des planchers) est distribue 1 FR a la fois aux villes
// ayant la plus grande partie decimale perdue (egalite departagee par l'ordre de
// getVillesReelles, fixe et deterministe) -- garantit que la somme creditee est exactement egale
// a montantTotal, jamais de FR perdu par arrondi, et un resultat 100% reproductible quel que
// soit le declencheur.
async function distribuerMontantParVilleAuProrataFiscal(pays, montantTotal, resolveBuildingId) {
  if (montantTotal <= 0) return;
  const villes = getVillesReelles(pays);
  const poids = villes.map(v => CITY_POPULATION?.[pays]?.[v]?.dailyTaxRevenue || 0);
  const totalPoids = poids.reduce((s, p) => s + p, 0);
  // Repli deterministe (parts egales) si aucun poids fiscal connu pour ce pays -- evite une
  // division par zero, ne devrait plus survenir pour Republia depuis le correctif
  // CITY_POPULATION.republic du 24 aout 2026.
  const parts = totalPoids > 0
    ? poids.map(p => montantTotal * p / totalPoids)
    : villes.map(() => montantTotal / villes.length);
  const planchers = parts.map(p => Math.floor(p));
  let reliquat = montantTotal - planchers.reduce((s, p) => s + p, 0);
  const ordreReliquat = parts
    .map((p, i) => ({ i, frac: p - planchers[i] }))
    .sort((a, b) => b.frac - a.frac || a.i - b.i);
  const montants = [...planchers];
  for (let k = 0; k < ordreReliquat.length && reliquat > 0; k++) {
    montants[ordreReliquat[k].i]++;
    reliquat--;
  }
  for (let i = 0; i < villes.length; i++) {
    if (montants[i] > 0) await crediterCaisseBatiment(pays, resolveBuildingId(villes[i]), montants[i]);
  }
}

async function chargerCaisseBatiment(pays, buildingId) {
  const key = pays + '_' + buildingId;
  if (typeof sbGetCaisseBatiment !== 'function') return { key, solde: 0 };
  let data = await sbGetCaisseBatiment(key).catch(() => null);
  if (!data) {
    data = { solde: 0 };
    await sbSaveCaisseBatiment(key, data).catch(() => {});
  }
  return { key, ...data };
}

async function crediterCaisseBatiment(pays, buildingId, montant) {
  const c = await chargerCaisseBatiment(pays, buildingId);
  c.solde = Math.max(0, (c.solde || 0) + montant);
  if (typeof sbSaveCaisseBatiment === 'function') await sbSaveCaisseBatiment(c.key, { solde: c.solde }).catch(() => {});
  return c.solde;
}

// Verse au maximum montantVise, plafonne par ce qui est reellement disponible (jamais de negatif)
async function debiterCaisseBatimentPlafonne(pays, buildingId, montantVise) {
  const c = await chargerCaisseBatiment(pays, buildingId);
  const montantVerse = Math.min(c.solde || 0, montantVise);
  c.solde = (c.solde || 0) - montantVerse;
  if (typeof sbSaveCaisseBatiment === 'function') await sbSaveCaisseBatiment(c.key, { solde: c.solde }).catch(() => {});
  return montantVerse;
}

// Debit TOUT-OU-RIEN pour les couts institutionnels fixes (deduireCoutOrdre, plateau-core.js).
// Contrairement a debiterCaisseBatimentPlafonne (versement partiel volontaire, utilise ailleurs
// pour les virements/salaires/reparations qui tolerent un montant reduit), cette fonction ne
// touche JAMAIS la caisse si le solde est insuffisant : renvoie 0 sans effet de bord, ou le
// montant demande en entier. Audit Phase K (8/8) : 12 sites appelaient deja
// debiterCaisseBatimentPlafonne pour un cout FIXE en annulant l'action apres coup si le montant
// verse etait insuffisant, perdant silencieusement le montant partiel deja preleve -- ces sites
// ne sont pas corriges ici (dette technique consignee pour la Phase K-bis), mais tout nouvel
// appelant a cout fixe doit utiliser debiterCaisseBatimentAtomique, jamais Plafonne.
async function debiterCaisseBatimentAtomique(pays, buildingId, montant) {
  const c = await chargerCaisseBatiment(pays, buildingId);
  if ((c.solde || 0) < montant) return 0;
  c.solde = (c.solde || 0) - montant;
  if (typeof sbSaveCaisseBatiment === 'function') await sbSaveCaisseBatiment(c.key, { solde: c.solde }).catch(() => {});
  return montant;
}

// =====================
// VIREMENTS INSTITUTIONNELS GENERIQUES (lot du 24 aout 2026) — pendant de
// debiterCaisseBatimentAtomique/crediterCaisseBatiment ci-dessus, mais pour les caisses qui ne
// vivent pas dans caisses_batiments (systeme "classique") mais dans le blob JSON generique de
// sbGetBatimentEtat (usines : etat.usine.caisse, entrepots : etat.entrepot.caisse, et bientot le
// port : etat.port.caisse). Parametrees par sousCle pour rester reutilisables sans duplication
// le jour ou l'economie du port sera creee. Meme semantique tout-ou-rien (jamais de decouvert,
// aucun effet de bord si le solde est insuffisant) que debiterCaisseBatimentAtomique.
async function debiterCaisseEtatBatimentAtomique(pays, ville, buildingId, sousCle, montant) {
  const etat = (typeof sbGetBatimentEtat === 'function') ? await sbGetBatimentEtat(pays, ville, buildingId).catch(() => null) : null;
  const sousEtat = etat?.[sousCle] || {};
  const solde = sousEtat.caisse || 0;
  if (solde < montant) return 0;
  const nouvelEtat = { ...(etat || {}), [sousCle]: { ...sousEtat, caisse: solde - montant } };
  if (typeof sbSetBatimentEtat === 'function') await sbSetBatimentEtat(pays, ville, buildingId, nouvelEtat).catch(() => {});
  return montant;
}

async function crediterCaisseEtatBatiment(pays, ville, buildingId, sousCle, montant) {
  const etat = (typeof sbGetBatimentEtat === 'function') ? await sbGetBatimentEtat(pays, ville, buildingId).catch(() => null) : null;
  const sousEtat = etat?.[sousCle] || {};
  const solde = Math.max(0, (sousEtat.caisse || 0) + montant);
  const nouvelEtat = { ...(etat || {}), [sousCle]: { ...sousEtat, caisse: solde } };
  if (typeof sbSetBatimentEtat === 'function') await sbSetBatimentEtat(pays, ville, buildingId, nouvelEtat).catch(() => {});
  return solde;
}

async function chargerBudgetNational(pays) {
  if (typeof sbGetBudgetNational !== 'function') return { tauxNational: TAUX_TAXE_DEFAUT, reserveJour: 0 };
  let data = await sbGetBudgetNational(pays).catch(() => null);
  if (!data) {
    data = { tauxNational: TAUX_TAXE_DEFAUT, reserveJour: 0, derniereDistribJour: state.day || 1 };
    await sbSaveBudgetNational(pays, data).catch(() => {});
  }
  if (data.tauxNational === undefined) data.tauxNational = TAUX_TAXE_DEFAUT;
  return data;
}

// Calcule le montant net d'une vente legale apres taxe locale+nationale, alimente les deux reserves.
// A appeler pour toute transaction commerciale legale (le gris et l'illegal ne sont jamais taxes).
async function appliquerTaxeTransaction(montantBrut) {
  const pays = state.country || 'republic';
  const budgetMuni = await chargerBudgetMunicipal();
  const budgetNat = await chargerBudgetNational(pays);
  const tauxLocal = budgetMuni.tauxLocal ?? TAUX_TAXE_DEFAUT;
  const tauxNational = budgetNat.tauxNational ?? TAUX_TAXE_DEFAUT;

  const taxeLocale = Math.round(montantBrut * tauxLocal / 100);
  const taxeNationale = Math.round(montantBrut * tauxNational / 100);
  const net = montantBrut - taxeLocale - taxeNationale;

  budgetMuni.caisse = (budgetMuni.caisse || 0) + taxeLocale;
  if (typeof sbSaveBudgetMunicipal === 'function') await sbSaveBudgetMunicipal(budgetMuni.key, budgetMuni).catch(() => {});

  budgetNat.reserveJour = (budgetNat.reserveJour || 0) + taxeNationale;
  if (typeof sbSaveBudgetNational === 'function') await sbSaveBudgetNational(pays, budgetNat).catch(() => {});

  return { net, taxeLocale, taxeNationale, tauxLocal, tauxNational };
}

// Verifie une fois par jour : effets du taux d'imposition total sur IS/ISN, distribution aux caisses publiques
async function verifierEffetsEtDistributionFiscale() {
  const pays = state.country || 'republic';
  const budgetNat = await chargerBudgetNational(pays);
  const jour = state.day || 1;
  if (budgetNat.derniereDistribJour === jour) return;

  const budgetMuni = await chargerBudgetMunicipal();
  const tauxLocal = budgetMuni.tauxLocal ?? TAUX_TAXE_DEFAUT;
  const tauxTotal = tauxLocal + (budgetNat.tauxNational ?? TAUX_TAXE_DEFAUT);

  // Effets sur les indices de la ville concernee (tauxLocal est deja specifique a cette ville
  // via chargerBudgetMunicipal/getVilleKey) : Social baisse au-dela d'un taux neutre (~15-20%),
  // Securite se degrade au-dela de 25% (marche noir). Repli national inchange hors Republia.
  const villeFiscale = state.currentCity || 'capitale';
  if (typeof modifierIndiceVille === 'function') {
    if (tauxTotal > 18) await modifierIndiceVille(pays, villeFiscale, 'social', -Math.min(5, Math.floor((tauxTotal - 18) * 0.5))).catch(() => {});
    if (tauxTotal > 25) await modifierIndiceVille(pays, villeFiscale, 'isn', -Math.min(5, Math.floor((tauxTotal - 25) * 0.6))).catch(() => {});
  }

  // Distribution quotidienne : chaque poste recoit sa propre part dans sa propre caisse.
  // 'mairie'/'commissariat'/'tribunal' sont des caisses PAR VILLE (3 destinations reelles
  // possibles), contrairement aux caisses nationales uniques (min_int, min_fin, etc.). Toutes
  // trois creditaient auparavant systematiquement villeFiscale = state.currentCity du PJ qui
  // declenche le traitement -- credit arbitraire d'une seule ville sur les trois chaque jour,
  // different selon le declencheur. Corrige pour tribunal/commissariat le 24 aout 2026 (audit
  // fiscal), puis pour 'mairie' ce meme jour (meme constat, meme correction) : les 3 categories
  // sont desormais explicitement exclues de cette boucle (continue ci-dessous) et reparties sur
  // les 3 villes au prorata de leur dailyTaxRevenue via distribuerMontantParVilleAuProrataFiscal,
  // totalement independamment de villeFiscale/state.currentCity.
  const dailyBase = Object.values(CITY_POPULATION?.[pays] || {}).reduce((s, v) => s + (v.dailyTaxRevenue || 0), 0);
  const totalDisponible = dailyBase + (budgetNat.reserveJour || 0);
  const repartition = budgetNat.repartition || REPARTITION_DEFAULT;
  for (const [posteId, buildingId] of Object.entries(CAISSE_PAR_POSTE_BUDGET)) {
    if (posteId === 'commissariat' || posteId === 'tribunal' || posteId === 'mairie') continue; // traites separement ci-dessous, repartis sur les 3 villes
    const part = (repartition[posteId] || 0) / 100;
    await crediterCaisseBatiment(pays, buildingId, Math.floor(totalDisponible * part));
  }
  const montantTribunalNational = Math.floor(totalDisponible * ((repartition.tribunal || 0) / 100));
  await distribuerMontantParVilleAuProrataFiscal(pays, montantTribunalNational, getBuildingIdTribunal);
  const montantCommissariatNational = Math.floor(totalDisponible * ((repartition.commissariat || 0) / 100));
  await distribuerMontantParVilleAuProrataFiscal(pays, montantCommissariatNational, getBuildingIdCommissariat);
  const montantMairieNational = Math.floor(totalDisponible * ((repartition.mairie || 0) / 100));
  await distribuerMontantParVilleAuProrataFiscal(pays, montantMairieNational, getBuildingIdMairie);
  // Le virement journalier automatique vers la caserne, fixe par le MG, est traite separement (voir traiterVirementJournalierCaserne)
  // 'assemblee' et 'reserve' sont desormais credites eux aussi (arbitrage utilisateur du 24 aout
  // 2026, cf. CAISSE_PAR_POSTE_BUDGET ci-dessus) : les 100% de REPARTITION_DEFAULT aboutissent
  // maintenant tous dans une caisse reelle, plus aucune part perdue.
  // villeFiscale (ci-dessus) n'a plus aucun usage dans cette redistribution : sa seule
  // dependance restante et legitime est l'effet sur les indices Social/ISN de la ville
  // courante (juste au-dessus), qui reflete deja intentionnellement le taux local reel de
  // CETTE ville (tauxLocal via chargerBudgetMunicipal) -- un effet de jeu local au declencheur,
  // pas une destination de redistribution nationale.

  budgetNat.reserveJour = 0;
  budgetNat.derniereDistribJour = jour;
  await sbSaveBudgetNational(pays, budgetNat).catch(() => {});
}

// Verifie et verse le salaire politique du jour, plafonne par la caisse de l'institution
async function verifierSalairePolitique() {
  const posteId = state.poste?.id;
  if (!posteId || !SALAIRES_POLITIQUES[posteId]) return;
  const jour = state.day || 1;
  if (!state.char) return;
  if (state.char.dernierSalairePolitiqueJour === jour) return;

  const pays = state.country || 'republic';
  // Poste municipal (city renseignee sur state.poste par reconcilierPosteElu, ex. maire) :
  // caisse de la VILLE REELLE du poste, jamais une ville codee en dur (A3, lot finition
  // financiere locale, 17 aout 2026) -- CAISSE_BATIMENT_POSTE reste la source pour les postes
  // nationaux (president/pm/ministres), qui n'ont pas de city sur state.poste.
  const buildingId = state.poste?.city
    ? getBuildingIdMairie(state.poste.city)
    : CAISSE_BATIMENT_POSTE[posteId];
  const montantVise = SALAIRES_POLITIQUES[posteId];
  const montantVerse = await debiterCaisseBatimentPlafonne(pays, buildingId, montantVise);

  state.arg = (state.arg || 0) + montantVerse;
  state.char.dernierSalairePolitiqueJour = jour;
  updateUI();
  if (montantVerse > 0) {
    showToast('Salaire perçu', '+' + montantVerse.toLocaleString('fr-FR') + ' FR.' + (montantVerse < montantVise ? ' (caisse insuffisante pour le montant complet)' : ''), true, true);
    addJournalEntry('Salaire politique perçu : ' + montantVerse + ' FR.', 'event-good');
  } else {
    showToast('Salaire impayé', 'La caisse de l\'institution est vide aujourd\'hui.', false);
    addJournalEntry('Aucun salaire perçu : caisse de l\'institution vide.', 'event-bad');
  }
}

// =====================
// Reconstruction des ordres fiscaux existants (etaient locaux/casses) — Ministre des Finances et Maire
// =====================
async function ouvrirFixerImpotsLocauxReel(pa, cost) {
  const budgetMuni = await chargerBudgetMunicipal();
  const taux = budgetMuni.tauxLocal ?? TAUX_TAXE_DEFAUT;
  document.getElementById('postes-modal-title').textContent = 'Fixer les impôts locaux';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Taux actuel : ' + taux + '%. S\'applique à toutes les transactions légales de la ville, en plus de la taxe nationale.</div>';
  html += '<input id="taux-local-input" type="range" min="0" max="40" value="' + taux + '" oninput="document.getElementById(\'taux-local-val\').textContent=this.value+\'%\'" style="width:100%;margin-bottom:.3rem">';
  html += '<div id="taux-local-val" style="font-family:Bebas Neue,sans-serif;font-size:1.2rem;color:#C9A84C;text-align:center;margin-bottom:.6rem">' + taux + '%</div>';
  html += '<div style="font-size:.72rem;color:#5a5040;margin-bottom:.8rem">Au-delà de 18-20% (total local+national), le climat social se dégrade. Au-delà de 25%, la sécurité en pâtit aussi (marché noir).</div>';
  html += '<button onclick="validerImpotsLocauxReel(\'' + budgetMuni.key + '\',' + pa + ',' + cost + ')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Appliquer</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function validerImpotsLocauxReel(key, pa, cost) {
  const nouveauTaux = parseInt(document.getElementById('taux-local-input')?.value || '5');
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }
  const budgetMuni = await sbGetBudgetMunicipal(key);
  budgetMuni.tauxLocal = nouveauTaux;
  await sbSaveBudgetMunicipal(key, budgetMuni);
  document.getElementById('modal-postes')?.classList.remove('open');
  showToast('Impôts locaux fixés', 'Nouveau taux : ' + nouveauTaux + '%.', true, true);
  addExternalEvent('MAIRIE : Le taux d\'imposition local est fixé à ' + nouveauTaux + '%.');
}

async function ouvrirFixerImpotNational(pa, cost) {
  if (state.poste?.id !== 'min_fin') { showToast('Réservé au Ministre des Finances', '', false); return; }
  const pays = state.country || 'republic';
  const budgetNat = await chargerBudgetNational(pays);
  const taux = budgetNat.tauxNational ?? TAUX_TAXE_DEFAUT;

  document.getElementById('postes-modal-title').textContent = 'Fixer le taux d\'imposition national';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Taux actuel : ' + taux + '%. S\'applique à toutes les transactions légales du pays, en plus de la taxe locale de chaque ville.</div>';
  html += '<input id="taux-national-input" type="range" min="0" max="40" value="' + taux + '" oninput="document.getElementById(\'taux-national-val\').textContent=this.value+\'%\'" style="width:100%;margin-bottom:.3rem">';
  html += '<div id="taux-national-val" style="font-family:Bebas Neue,sans-serif;font-size:1.2rem;color:#C9A84C;text-align:center;margin-bottom:.6rem">' + taux + '%</div>';
  html += '<div style="font-size:.72rem;color:#8a8060;margin-bottom:.8rem">Au-delà de 18-20% (total local+national), le climat social se dégrade. Au-delà de 25%, la sécurité en pâtit aussi (marché noir).</div>';
  html += '<button onclick="validerImpotNational(\'' + pays + '\',' + pa + ',' + cost + ')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.55rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Appliquer</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function validerImpotNational(pays, pa, cost) {
  const nouveauTaux = parseInt(document.getElementById('taux-national-input')?.value || '5');
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }
  const budgetNat = await chargerBudgetNational(pays);
  budgetNat.tauxNational = nouveauTaux;
  await sbSaveBudgetNational(pays, budgetNat);
  document.getElementById('modal-postes')?.classList.remove('open');
  showToast('Impôts nationaux fixés', 'Nouveau taux : ' + nouveauTaux + '%.', true, true);
  addJournalEntry('Taux d\'imposition national fixé à ' + nouveauTaux + '% par le Ministre des Finances.', 'event-info');
  addExternalEvent('FINANCES : Le taux d\'imposition national est fixé à ' + nouveauTaux + '%.');
}

// =====================
// BUREAU NATIONAL DE L'EMPLOI (BNE) — 9 aout 2026
// =====================
// Donne un revenu regulier a un PJ sans poste politique. Incompatible avec state.poste
// (verifie a la postulation) — un vrai poste politique prime toujours. L'occupation reelle
// des offres (OFFRES_EMPLOI_BNE, data.js) vit dans Supabase via sbGetEtatBNE/sbSetEtatBNE
// (supabase.js), pas dans un nouveau champ sur la table personnages (aucune colonne
// supplementaire possible avec la cle anon) : state.emploiBNE n'est qu'un cache local,
// rafraichi au chargement du personnage (plateau-core.js) et apres chaque action BNE.
//
// Regle de conflit (demandee par Fred le 9 aout 2026) : une situation deja active (emploi
// BNE OU poste politique) n'est jamais ecrasee automatiquement par une nouvelle candidature.
// - Postuler alors qu'on tient deja un AUTRE emploi BNE : la nouvelle offre est reservee en
//   'en_attente_arbitrage' (comptee dans les places, invisible aux autres), un mail part avec
//   les deux choix, l'emploi actuel reste actif tant que le joueur n'a pas tranche.
// - Obtenir un poste politique en gardant un emploi BNE actif : detecte par le cron nocturne
//   (verifierConflitsEmploiBNE, api/cron-minuit.js), meme mail, meme mecanique de tranchage
//   (trancherEmploiBNE), cote poste politique celui-ci n'est jamais touche automatiquement.

function trouverEmploiActuelBNE(offresBlob, pjNom) {
  for (const [offreId, occupants] of Object.entries(offresBlob || {})) {
    const entry = (occupants || []).find(o => o.pjNom === pjNom && o.statut === 'actif');
    if (entry) return { offreId, entry };
  }
  return null;
}

function trouverReservationEnAttenteBNE(offresBlob, pjNom) {
  for (const [offreId, occupants] of Object.entries(offresBlob || {})) {
    const entry = (occupants || []).find(o => o.pjNom === pjNom && o.statut === 'en_attente_arbitrage');
    if (entry) return { offreId, entry };
  }
  return null;
}

function compterPlacesPrisesBNE(offresBlob, offreId) {
  return ((offresBlob || {})[offreId] || []).length;
}

// Rafraichit le cache local state.emploiBNE depuis Supabase — appelee au chargement du
// personnage (plateau-core.js) et apres chaque action BNE, jamais suppose fiable seul.
async function rafraichirCacheEmploiBNE() {
  if (!state.char?.name || typeof sbGetEtatBNE !== 'function') return;
  try {
    const etat = await sbGetEtatBNE(state.country);
    const actuel = trouverEmploiActuelBNE(etat.offres, state.char.name);
    state.emploiBNE = actuel ? { offreId: actuel.offreId } : null;
  } catch(e) {}
}

async function doInscrireDemandeurEmploi(pa, cost) {
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }
  state.demandeurEmploi = true;
  showToast('Inscription enregistrée', 'Vous êtes désormais demandeur d\'emploi. Consultez les offres disponibles.', true);
  addJournalEntry('Inscription comme demandeur d\'emploi au Bureau National de l\'Emploi.', 'event-info');
}

async function ouvrirOffresEmploiBNE() {
  if (!state.demandeurEmploi) {
    showToast('Inscription requise', 'Inscrivez-vous comme demandeur d\'emploi avant de consulter les offres.', false);
    return;
  }
  document.getElementById('postes-modal-title').textContent = "Offres d'emploi — Bureau National de l'Emploi";
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060;font-style:italic">Chargement des offres...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const etat = await sbGetEtatBNE(state.country);
  const villeCourante = state.currentCity || 'capitale';
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const pjNom = state.char?.name;
  const emploiActuel = trouverEmploiActuelBNE(etat.offres, pjNom);
  const reservationEnAttente = trouverReservationEnAttenteBNE(etat.offres, pjNom);

  const offresVisibles = Object.entries(OFFRES_EMPLOI_BNE).filter(([, o]) =>
    o.portee !== 'locale' || o.ville === villeCourante
  );

  const portéeLabel = { locale: 'Locale', nationale: 'Nationale', internationale: 'Internationale' };

  let html = '<div style="padding:1rem">';
  if (reservationEnAttente) {
    html += '<div style="font-size:.78rem;color:#c08a3a;font-style:italic;margin-bottom:.8rem;border:1px solid #6a4a1a;padding:.5rem">Une candidature est en attente d\'arbitrage — consultez votre messagerie pour trancher avant d\'en déposer une nouvelle.</div>';
  }
  html += offresVisibles.map(([offreId, o]) => {
    const placesPrises = compterPlacesPrisesBNE(etat.offres, offreId);
    const complet = placesPrises >= o.places;
    const estMonEmploi = emploiActuel?.offreId === offreId;
    let bouton;
    if (estMonEmploi) {
      bouton = '<span style="font-size:.7rem;color:#4a8a4a">Votre emploi actuel</span>';
    } else if (reservationEnAttente) {
      bouton = '<span style="font-size:.7rem;color:#5a5040">Candidature en attente</span>';
    } else if (complet) {
      bouton = '<span style="font-size:.7rem;color:#5a5040">Complet</span>';
    } else {
      bouton = '<button onclick="postulerOffreEmploiBNE(\'' + offreId + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.08em;padding:.3rem .7rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">Postuler</button>';
    }
    return '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.7rem;margin-bottom:.5rem;display:flex;justify-content:space-between;align-items:center">' +
      '<div>' +
        '<div style="font-family:Playfair Display,serif;font-size:.85rem;color:#E8C97A">' + o.label + '</div>' +
        '<div style="font-size:.68rem;color:#6a5a30;margin-top:.15rem">' + portéeLabel[o.portee] + ' · ' + o.salaire.toLocaleString('fr-FR') + ' ' + cur + '/jour · ' + placesPrises + '/' + o.places + ' places prises</div>' +
      '</div>' + bouton +
    '</div>';
  }).join('');
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function postulerOffreEmploiBNE(offreId) {
  const offre = OFFRES_EMPLOI_BNE[offreId];
  if (!offre) return;
  if (state.poste) {
    showToast('Poste politique en cours', 'Vous occupez déjà un poste politique, incompatible avec un emploi du BNE.', false);
    return;
  }
  const pjNom = state.char?.name;
  const etat = await sbGetEtatBNE(state.country);
  const reservationEnAttente = trouverReservationEnAttenteBNE(etat.offres, pjNom);
  if (reservationEnAttente) {
    showToast('Candidature en attente', 'Tranchez d\'abord la candidature en attente reçue par mail.', false);
    return;
  }
  const placesPrises = compterPlacesPrisesBNE(etat.offres, offreId);
  if (placesPrises >= offre.places) {
    showToast('Poste complet', 'Il n\'y a plus de place disponible pour cette offre.', false);
    return;
  }

  const emploiActuel = trouverEmploiActuelBNE(etat.offres, pjNom);
  const offres = { ...etat.offres };

  if (!emploiActuel) {
    // Aucune situation en cours : prise immediate
    offres[offreId] = [...(offres[offreId] || []), { pjNom, statut: 'actif' }];
    await sbSetEtatBNE(state.country, offres);
    state.emploiBNE = { offreId };
    document.getElementById('modal-postes')?.classList.remove('open');
    showToast('Poste obtenu !', 'Vous occupez désormais : ' + offre.label + '. Salaire versé chaque jour à l\'ordre Dormir.', true, true);
    addJournalEntry('Poste obtenu au Bureau National de l\'Emploi : ' + offre.label + '.', 'event-good');
    return;
  }

  // Situation deja en cours (autre emploi BNE) : reservation + mail d'arbitrage, rien n'est ecrase
  const ancienneOffre = OFFRES_EMPLOI_BNE[emploiActuel.offreId];
  offres[offreId] = [...(offres[offreId] || []), { pjNom, statut: 'en_attente_arbitrage' }];
  await sbSetEtatBNE(state.country, offres);

  const corps = 'Vous occupez déjà le poste de <strong>' + (ancienneOffre?.label || emploiActuel.offreId) + '</strong> et avez postulé pour <strong>' + offre.label + '</strong>.<br><br>' +
    'Votre poste actuel reste actif tant que vous n\'avez pas tranché. La nouvelle offre vous est réservée en attendant votre réponse.<br><br>' +
    '<button onclick="trancherEmploiBNE(true,\'' + emploiActuel.offreId + '\',\'' + offreId + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.4rem .8rem;border:1px solid #6a5a30;background:transparent;color:#c0b090;cursor:pointer;margin-right:.5rem">Garder mon poste actuel</button>' +
    '<button onclick="trancherEmploiBNE(false,\'' + emploiActuel.offreId + '\',\'' + offreId + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.4rem .8rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">Prendre le nouveau poste</button>';

  if (typeof sbSendMail === 'function') {
    const h = String(state.hour || 8).padStart(2, '0');
    const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : 'Jour ' + (state.day || 1) + ' · ' + h + 'h';
    await sbSendMail('Bureau National de l\'Emploi', pjNom, 'Deux postes en même temps ?', corps, time).catch(() => {});
  }
  document.getElementById('modal-postes')?.classList.remove('open');
  showToast('Candidature enregistrée', 'Vous occupez déjà un poste — consultez votre messagerie pour trancher.', true);
  addJournalEntry('Candidature déposée pour ' + offre.label + ', en attente d\'arbitrage (poste actuel conservé).', 'event-info');
}

// Appelee depuis les 2 boutons du mail d'arbitrage (postulerOffreEmploiBNE et
// verifierConflitsEmploiBNE cote cron envoient le meme format de mail).
async function trancherEmploiBNE(garderActuel, ancienOffreId, nouvelOffreId) {
  const pjNom = state.char?.name;
  const etat = await sbGetEtatBNE(state.country);
  const offres = { ...etat.offres };

  if (garderActuel) {
    // Libere juste la reservation en attente sur la nouvelle offre
    offres[nouvelOffreId] = (offres[nouvelOffreId] || []).filter(o => !(o.pjNom === pjNom && o.statut === 'en_attente_arbitrage'));
    await sbSetEtatBNE(state.country, offres);
    state.emploiBNE = ancienOffreId ? { offreId: ancienOffreId } : null;
    showToast('Poste conservé', 'Vous gardez votre poste actuel.', true);
    addJournalEntry('Arbitrage BNE : poste actuel conservé.', 'event-info');
  } else {
    // Retire l'ancien poste (si emploi BNE), confirme le nouveau
    if (ancienOffreId && OFFRES_EMPLOI_BNE[ancienOffreId]) {
      offres[ancienOffreId] = (offres[ancienOffreId] || []).filter(o => !(o.pjNom === pjNom && o.statut === 'actif'));
    }
    offres[nouvelOffreId] = (offres[nouvelOffreId] || []).map(o =>
      (o.pjNom === pjNom && o.statut === 'en_attente_arbitrage') ? { ...o, statut: 'actif' } : o
    );
    await sbSetEtatBNE(state.country, offres);
    state.emploiBNE = { offreId: nouvelOffreId };
    const offre = OFFRES_EMPLOI_BNE[nouvelOffreId];
    showToast('Nouveau poste confirmé', 'Vous occupez désormais : ' + (offre?.label || nouvelOffreId) + '.', true, true);
    addJournalEntry('Arbitrage BNE : nouveau poste confirmé (' + (offre?.label || nouvelOffreId) + ').', 'event-good');
  }
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
  updateUI();
}

async function demissionnerEmploiBNE() {
  const pjNom = state.char?.name;
  const etat = await sbGetEtatBNE(state.country);
  const emploiActuel = trouverEmploiActuelBNE(etat.offres, pjNom);
  if (!emploiActuel) {
    showToast('Aucun emploi', 'Vous n\'occupez actuellement aucun poste du BNE.', false);
    return;
  }
  const offres = { ...etat.offres };
  offres[emploiActuel.offreId] = (offres[emploiActuel.offreId] || []).filter(o => !(o.pjNom === pjNom && o.statut === 'actif'));
  await sbSetEtatBNE(state.country, offres);
  state.emploiBNE = null;
  const offre = OFFRES_EMPLOI_BNE[emploiActuel.offreId];
  showToast('Démission effective', 'Vous ne travaillez plus comme ' + (offre?.label || emploiActuel.offreId) + '.', true);
  addJournalEntry('Démission du poste : ' + (offre?.label || emploiActuel.offreId) + '.', 'event-info');
}
