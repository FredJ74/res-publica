// =====================
// PLATEAU-POLITIQUE.JS
// Votes, postes, calendrier electoral, moteur electoral, alliances, objectifs secrets,
// journal du matin, meteo politique
// =====================

// =====================
// MARCHANDER UN VOTE
// =====================
function openMarchanderVoteModal() {
  const votes = state.votesEnCours || [];
  if (votes.length === 0) {
    showToast('Aucun vote en cours', "Aucun vote en cours a l'Assemblee.", false);
    return;
  }
  const bonusInf = Math.floor((state.inf / 100) * 10);
  const tauxFinal = Math.min(90, 40 + bonusInf);
  document.getElementById('postes-modal-title').textContent = 'Marchander un vote';
  let html = '<div style="padding:1rem"><div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Taux : ' + tauxFinal + '% (base 40% + ' + bonusInf + '% INF). Cout : 200 FR + 1 PA si succes.</div>';
  votes.forEach(function(v, i) {
    html += '<div style="padding:.7rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.5rem">';
    html += '<div style="font-family:Playfair Display,serif;font-size:.88rem;color:#E8C97A;margin-bottom:.2rem">' + (v.titre || 'Vote ' + i) + '</div>';
    html += '<div style="font-size:.72rem;color:#6a5a30">Pour : ' + (v.pour||0) + ' | Contre : ' + (v.contre||0) + '</div>';
    html += '<button onclick="state._voteIdx=' + i + ';soumettreVoteMarchande(' + tauxFinal + ')" style="margin-top:.4rem;font-family:Bebas Neue,sans-serif;font-size:.72rem;padding:.3rem .7rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Marchander ce vote</button>';
    html += '</div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function soumettreVoteMarchande(taux) {
  const voteId = state._voteIdx !== undefined ? (state.votesEnCours || [])[state._voteIdx]?.id : null;
  document.getElementById('modal-postes').classList.remove('open');
  const cur = COUNTRIES[state.char && state.char.country ? state.char.country : 'republic'] && COUNTRIES[state.char.country].cur ? COUNTRIES[state.char.country].cur : 'FR';
  if (state.arg < 200) { showToast('Fonds insuffisants', '200 ' + cur + ' requis.', false); return; }
  const roll = Math.floor(Math.random() * 100) + 1;
  const vote = (state.votesEnCours || []).find(function(v) { return v.id === voteId; });
  if (roll <= taux) {
    state.arg -= 200; state.pa = Math.max(0, state.pa - 1); state.inf = Math.min(100, state.inf + 3);
    if (vote) vote.pour = (vote.pour || 0) + 1;
    updateUI();
    showToast('Vote marchande !', 'Un depute a vote dans votre sens. -200 ' + cur + ' -1 PA +3 INF.', true, true);
    addJournalEntry('Vote marchande avec succes : ' + (vote && vote.titre ? vote.titre : voteId), 'event-good');
  } else {
    showToast('Refuse !', "Le depute n' pas accepte.", false);
    addJournalEntry('Tentative corruption depute echouee.', 'event-bad');
  }
}

// =====================
// POSTES MODAL
// =====================
function openPostesModal() {
  const postes = POSTES[state.country];
  if (!postes) return;

  const world = WORLD[state.country];
  const city = world?.[state.currentCity];
  const co = COUNTRIES[state.country];

  let allPostes = [];
  if (city?.isCapitale) {
    allPostes = [...(postes.capitale || []), ...(postes.assemblee || [])];
  } else {
    allPostes = postes[state.currentCity] || [];
  }

  const available = allPostes.filter(p => !p.holder || p.holder.startsWith('PNJ'));

  document.getElementById('postes-body').innerHTML = `
    <div style="padding:.8rem 1rem;font-size:.8rem;color:#8a8060;border-bottom:1px solid #1a1810;font-style:italic">
      ${available.length} poste(s) disponible(s) a ${city?.name || 'cette ville'}.
    </div>
    ${allPostes.map(p => `
      <div class="poste-item">
        <div>
          <div class="poste-name">${p.name}</div>
          <div class="poste-holder">${p.holder ? (p.holder.startsWith('PNJ') ? 'Occupe par un PNJ (delogeable)' : `Occupe par ${p.holder}`) : 'Poste vacant'}</div>
        </div>
        ${!p.holder
          ? `<button class="poste-btn" onclick="postulerPoste('${p.id}','${p.name}')">Postuler</button>`
          : p.holder === state.char?.name
            ? `<button class="poste-btn" style="opacity:.4;cursor:default;color:#C9A84C">Votre poste</button>`
            : p.holder.startsWith('PNJ')
              ? `<button class="poste-btn pnj" onclick="postulerPoste('${p.id}','${p.name}')">Deloger le PNJ</button>`
              : `<button class="poste-btn" style="opacity:.4;cursor:default">Occupe</button>`
        }
      </div>`).join('')}
  `;

  document.getElementById('modal-postes').classList.add('open');
}




// =====================
// =====================
// CALENDRIER ÉLECTORAL
// =====================
function ouvrirCalendrierElectoral() {
  const country = state.country;
  const co = COUNTRIES[country];
  const now = Date.now();
  const semaine = 7 * 24 * 60 * 60 * 1000;
  const villeCourante = state.currentCity || 'capitale';
  const villeNom = WORLD[country]?.[villeCourante]?.name || villeCourante;

  const formatDate = ts => {
    const d = new Date(ts);
    return d.toLocaleDateString('fr-FR', { weekday:'short', day:'numeric', month:'short' }) +
      ' à ' + d.toLocaleTimeString('fr-FR', { hour:'2-digit', minute:'2-digit' });
  };

  const diffJours = ts => {
    const diff = ts - now;
    if (diff < 0) return '<span style="color:#8a3a2a">Passé</span>';
    const j = Math.floor(diff / 86400000);
    const h = Math.floor((diff % 86400000) / 3600000);
    if (j > 0) return '<span style="color:#4a8a4a">Dans ' + j + 'j ' + h + 'h</span>';
    return '<span style="color:#C9A84C">Dans ' + h + 'h</span>';
  };

  const postes = [
    ...POSTES_ELECTIFS.national,
    ...POSTES_ELECTIFS.departemental,
    ...POSTES_ELECTIFS.local
  ];

  // Initialiser les cycles manquants
  if (!CYCLES_ELECTORAUX[country]) CYCLES_ELECTORAUX[country] = {};
  postes.forEach(p => {
    const city = posteEstLocal(p.id) ? villeCourante : null;
    const cle = getCleCycle(p.id, city);
    if (!CYCLES_ELECTORAUX[country][cle]) initCycleElectoral(country, p.id, city);
  });

  const lignes = postes.map(p => {
    const estLocal = posteEstLocal(p.id);
    const city = estLocal ? villeCourante : null;
    const cle = getCleCycle(p.id, city);
    const cycle = CYCLES_ELECTORAUX[country][cle];
    const phase = getPhaseActuelle(country, p.id, city);
    const nbCandidats = cycle?.candidats?.length || 0;
    const titulaire = cycle?.eluId || (state.postes?.[country]?.[p.id]) || null;
    const labelPoste = p.name + (estLocal ? ' — ' + villeNom : '');

    const phaseStyle = {
      [PHASES_ELECTORALES.CANDIDATURES]: { col: '#4a6aaa', label: 'Candidatures' },
      [PHASES_ELECTORALES.CAMPAGNE]:     { col: '#aa8a4a', label: 'Campagne' },
      [PHASES_ELECTORALES.VOTE]:         { col: '#4a8a4a', label: '🗳 Vote' },
      [PHASES_ELECTORALES.SECOND_TOUR]:  { col: '#8a6a4a', label: 'Campagne 2nd tour' },
      [PHASES_ELECTORALES.VOTE2]:        { col: '#4a8a4a', label: '🗳 2nd tour' },
      [PHASES_ELECTORALES.VACANT]:       { col: '#8a3a2a', label: 'Vacant' },
    }[phase] || { col: '#6a5a30', label: '?' };

    // Prochaines échéances
    const echeances = [];
    if (cycle) {
      if (cycle.dateDebutCandidatures && cycle.dateDebutCandidatures > now)
        echeances.push({ label: 'Ouverture candidatures', date: cycle.dateDebutCandidatures });
      if (cycle.dateDebutCampagne && cycle.dateDebutCampagne > now)
        echeances.push({ label: 'Début campagne', date: cycle.dateDebutCampagne });
      if (cycle.dateVote && cycle.dateVote > now)
        echeances.push({ label: '🗳 Vote', date: cycle.dateVote });
      if (cycle.dateResultats && cycle.dateResultats > now)
        echeances.push({ label: 'Résultats', date: cycle.dateResultats });
    }
    const prochaine = echeances.length > 0 ? echeances[0] : null;

    return '<div style="padding:.6rem .4rem;border-bottom:1px solid #1a1810">' +
      '<div style="display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:.3rem">' +
        '<div>' +
          '<div style="font-family:Bebas Neue,sans-serif;font-size:.82rem;color:#c0b090">' + labelPoste + '</div>' +
          '<div style="font-size:.65rem;color:#6a5a30">' +
            (titulaire ? '✦ ' + titulaire : 'Poste vacant') +
          '</div>' +
        '</div>' +
        '<div style="text-align:right">' +
          '<div style="font-size:.68rem;font-family:Bebas Neue,sans-serif;color:' + phaseStyle.col + ';letter-spacing:.06em">' + phaseStyle.label + '</div>' +
          '<div style="font-size:.62rem;color:#4a4030">' + nbCandidats + ' candidat(s)</div>' +
        '</div>' +
      '</div>' +
      // Échéances
      (echeances.length > 0
        ? '<div style="background:#0a0907;border:1px solid #1a1810;border-radius:3px;padding:.35rem .5rem;margin-top:.3rem">' +
          echeances.slice(0,3).map(e =>
            '<div style="display:flex;justify-content:space-between;font-size:.65rem;margin-bottom:.15rem">' +
              '<span style="color:#8a8060">' + e.label + '</span>' +
              '<span>' + diffJours(e.date) + ' <span style="color:#4a4030">(' + formatDate(e.date) + ')</span></span>' +
            '</div>'
          ).join('') +
          '</div>'
        : '') +
      // Boutons action
      '<div style="display:flex;gap:.4rem;margin-top:.4rem">' +
        '<button onclick="ouvrirBureauDeVoteBtn(this)" data-poste="' + p.id + '" data-country="' + country + '" data-city="' + (city||'') + '" style="font-size:.62rem;font-family:Bebas Neue,sans-serif;padding:.2rem .5rem;border:1px solid #2a2010;background:transparent;color:#8a8060;cursor:pointer">Détails →</button>' +
        (phase === PHASES_ELECTORALES.CANDIDATURES
          ? '<button onclick="deposerCandidatureBtn2Btn(this)" data-poste="' + p.id + '" data-country="' + country + '" data-city="' + (city||'') + '" style="font-size:.62rem;font-family:Bebas Neue,sans-serif;padding:.2rem .5rem;border:1px solid #4a6aaa;background:transparent;color:#6a8aca;cursor:pointer">📋 Candidater</button>'
          : '') +
      '</div>' +
    '</div>';
  }).join('');

  document.getElementById('postes-modal-title').textContent = '📅 Calendrier Électoral — ' + (co?.n || country);
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.2rem .4rem">' +
    '<div style="font-size:.65rem;color:#4a4030;padding:.3rem .4rem;margin-bottom:.3rem;font-style:italic">' +
      'Mandat : 5-6 semaines · Candidatures : J-7 avant campagne · Second tour si aucun candidat ne dépasse 50%+1' +
    '</div>' +
    lignes +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

function deposerCandidatureBtn2Btn(el) { deposerCandidatureBtn2(el.dataset.poste, el.dataset.country, el.dataset.city); }
function deposerCandidatureBtn2(posteId, country, city) {
  fermerModalPostes();
  deposerCandidature(posteId, country, city || state.currentCity);
}



// =====================
// PNJ ADMINISTRATEUR (poste vacant)
// =====================
const PNJ_ADMINISTRATEURS = {
  president: {
    republic: { name: 'Gaston Intérim',     role: 'Président par intérim', trait: 'Nommé faute de candidat. Signe des décrets sans les lire. Facile à déloger.' },
    narco:    { name: 'Don Provisional',    role: 'Président par intérim', trait: 'Personne ne sait comment il est arrivé là. Donne des ordres au hasard.' },
    soviet:   { name: 'Camarade Provisoire',role: 'Administrateur du Parti',trait: 'Le Parti l\'a nommé. Le Parti peut l\'enlever. Très facile à déloger.' },
    khalija:  { name: 'Wali Al-Niyaba',     role: 'Régent intérimaire',    trait: 'Nommé par le Palais en attendant mieux. N\'a aucune ambition personnelle.' },
  },
  maire: {
    republic: { name: 'Hubert Gestionnaire', role: 'Maire administrateur', trait: 'Ancien chef de bureau. Gère les poubelles. Rien d\'autre.' },
    narco:    { name: 'El Temporal',         role: 'Maire par défaut',     trait: 'Là par accident. Part dès qu\'on lui demande.' },
    soviet:   { name: 'Camarade Local',      role: 'Administrateur local', trait: 'Nommé d\'office. Applique les directives. Toutes les directives.' },
    khalija:  { name: 'Moudir Al-Waqt',      role: 'Administrateur royal', trait: 'Le Palais gère directement. Pour l\'instant.' },
  },
  depute: {
    republic: { name: 'Suppléant Dubois',    role: 'Député suppléant',     trait: 'Remplace le siège vide. Vote blanc à chaque session.' },
    narco:    { name: 'El Suplente',         role: 'Député intérimaire',   trait: 'Là pour les apparences.' },
    soviet:   { name: 'Délégué du Peuple',   role: 'Représentant collectif',trait: 'Le Parti représente déjà le peuple. C\'est une formalité.' },
    khalija:  { name: 'Wakil Al-Sha\'b',    role: 'Représentant intérimaire',trait: 'Nommé par le Cheikh en attendant.' },
  }
};

function nommerAdministrateurSiVacant(country, posteId) {
  if (!CYCLES_ELECTORAUX[country]?.[posteId]) return;
  const cycle = CYCLES_ELECTORAUX[country][posteId];

  // Ne nommer que si poste vraiment vacant (pas d'élu, phase VACANT)
  if (cycle.eluId || cycle.administrateur) return;
  if (getPhaseActuelle(country, posteId) !== PHASES_ELECTORALES.VACANT) return;

  const adminDef = PNJ_ADMINISTRATEURS[posteId]?.[country];
  if (!adminDef) return;

  cycle.administrateur = {
    ...adminDef,
    nommeLeJour: state.day || 1,
    facileADeloger: true
  };
  cycle.eluId = adminDef.name + ' (Admin)';

  addJournalEntry('🏛 ' + adminDef.name + ' nommé ' + adminDef.role + ' — poste vacant.', 'event-info');
  addExternalEvent('🏛 ' + adminDef.name + ' prend les rênes de ' + (POSTES_ELECTIFS.national.concat(POSTES_ELECTIFS.local).find(p=>p.id===posteId)?.name || posteId) + ' à ' + (COUNTRIES[country]?.n || country) + '.');

  // Publier sur le forum
  if (typeof sbCreateTopic === 'function') {
    sbCreateTopic('local',
      '🏛 Nomination : ' + adminDef.name,
      'Faute de candidat, ' + adminDef.name + ' est nommé ' + adminDef.role + '.\n\n"' + adminDef.trait + '"\n\nIl peut être destitué par un vote de l\'assemblée ou une candidature au prochain cycle.',
      'Système'
    );
  }
}

// Vérifier tous les postes vacants au chargement et au réveil
function verifierPostesVacants() {
  const country = state.country;
  if (!CYCLES_ELECTORAUX[country]) return;
  Object.keys(CYCLES_ELECTORAUX[country]).forEach(posteId => {
    nommerAdministrateurSiVacant(country, posteId);
  });
}

// =====================
// PERSISTANCE ÉLECTORALE SUPABASE
// =====================
async function sbSaveCycleElectoral(country, posteId, cycle, city) {
  if (typeof sbInsert !== 'function') return;
  const cle = getCleCycle(posteId, city);
  try {
    await sbInsert('cycles_electoraux', {
      id: country + '_' + cle,
      country, poste_id: posteId, city: posteEstLocal(posteId) ? (city || null) : null,
      data: JSON.stringify(cycle),
      updated_at: new Date().toISOString()
    });
  } catch(e) {}
}

async function sbLoadCyclesElectoraux(country) {
  if (typeof sbGet !== 'function') return null;
  try {
    const rows = await sbGet('cycles_electoraux', 'country=eq.' + country);
    if (!rows || !rows.length) return null;
    const result = {};
    rows.forEach(r => {
      const cle = getCleCycle(r.poste_id, r.city);
      result[cle] = JSON.parse(r.data);
    });
    return result;
  } catch(e) { return null; }
}

async function sbVoterPour(country, posteId, votant, candidat, city) {
  if (typeof sbInsert !== 'function') return;
  const cle = getCleCycle(posteId, city);
  try {
    await sbInsert('votes_electoraux', {
      id: country + '_' + cle + '_' + votant,
      country, poste_id: posteId, city: posteEstLocal(posteId) ? (city || null) : null,
      votant, candidat,
      created_at: new Date().toISOString()
    });
  } catch(e) {}
}

async function sbGetVotes(country, posteId, city) {
  if (typeof sbGet !== 'function') return [];
  try {
    let filtre = 'country=eq.' + country + '&poste_id=eq.' + posteId;
    if (posteEstLocal(posteId) && city) filtre += '&city=eq.' + city;
    return await sbGet('votes_electoraux', filtre) || [];
  } catch(e) { return []; }
}

async function sbDeposerCandidature(country, posteId, candidat, city) {
  if (typeof sbInsert !== 'function') return;
  const cle = getCleCycle(posteId, city);
  try {
    await sbInsert('candidatures', {
      id: country + '_' + cle + '_' + candidat.nom,
      country, poste_id: posteId, city: posteEstLocal(posteId) ? (city || null) : null,
      nom: candidat.nom, programme: candidat.programme,
      archetype: candidat.archetype,
      created_at: new Date().toISOString()
    });
  } catch(e) {}
}

async function sbGetCandidatures(country, posteId, city) {
  if (typeof sbGet !== 'function') return [];
  try {
    let filtre = 'country=eq.' + country + '&poste_id=eq.' + posteId;
    if (posteEstLocal(posteId) && city) filtre += '&city=eq.' + city;
    return await sbGet('candidatures', filtre) || [];
  } catch(e) { return []; }
}

async function syncCyclesDepuisSupabase() {
  const country = state.country;
  const cycles = await sbLoadCyclesElectoraux(country);
  if (cycles) {
    CYCLES_ELECTORAUX[country] = { ...(CYCLES_ELECTORAUX[country]||{}), ...cycles };
  }
  // Charger votes et candidatures pour les postes pertinents (national + ceux de la ville courante)
  const postes = [...POSTES_ELECTIFS.national, ...POSTES_ELECTIFS.departemental, ...POSTES_ELECTIFS.local];
  for (const p of postes) {
    const city = posteEstLocal(p.id) ? state.currentCity : null;
    const cle = getCleCycle(p.id, city);
    if (!CYCLES_ELECTORAUX[country]?.[cle]) continue;
    const votes = await sbGetVotes(country, p.id, city);
    const candidatures = await sbGetCandidatures(country, p.id, city);
    if (votes.length) {
      CYCLES_ELECTORAUX[country][cle].votes = {};
      votes.forEach(v => { CYCLES_ELECTORAUX[country][cle].votes[v.votant] = v.candidat; });
    }
    if (candidatures.length) {
      CYCLES_ELECTORAUX[country][cle].candidats = candidatures.map(c => ({
        nom: c.nom, programme: c.programme, archetype: c.archetype,
        prospectusDistribues: 0
      }));
    }
  }
}

// =====================
// MOTEUR ÉLECTORAL
// =====================

// Initialiser le cycle électoral pour un empire/poste
// Détermine si un poste est local (niveau ville) ou national
function posteEstLocal(posteId) {
  const poste = [...(POSTES_ELECTIFS.national||[]), ...(POSTES_ELECTIFS.departemental||[]), ...(POSTES_ELECTIFS.local||[])]
    .find(p => p.id === posteId);
  return poste?.niveau === 'ville';
}

// Clé effective du cycle — inclut la ville pour les postes locaux (maire, depute)
function getCleCycle(posteId, city) {
  if (posteEstLocal(posteId) && city) return posteId + '_' + city;
  return posteId;
}

function initCycleElectoral(country, posteId, city) {
  const cle = getCleCycle(posteId, city);
  if (!CYCLES_ELECTORAUX[country]) CYCLES_ELECTORAUX[country] = {};
  if (CYCLES_ELECTORAUX[country][cle]) return;

  const now = Date.now();
  const semaine = 7 * 24 * 60 * 60 * 1000;
  CYCLES_ELECTORAUX[country][cle] = {
    posteId, city: posteEstLocal(posteId) ? (city || null) : null,
    phase: PHASES_ELECTORALES.CANDIDATURES,
    dateDebutCandidatures: now,
    dateDebutCampagne: now + semaine,
    dateVote: now + 2 * semaine,
    dateResultats: now + 2 * semaine + 24 * 60 * 60 * 1000,
    candidats: [],
    votes: {},       // { nomPJ: nomCandidat }
    votesPNJ: {},    // { pnjId: nomCandidat }
    tour: 1,
    eluId: null,
  };
}

// Obtenir la phase actuelle d'un cycle
function getPhaseActuelle(country, posteId, city) {
  const cle = getCleCycle(posteId, city);
  const cycle = CYCLES_ELECTORAUX[country]?.[cle];
  if (!cycle) return null;
  const now = Date.now();
  if (now < cycle.dateDebutCampagne) return PHASES_ELECTORALES.CANDIDATURES;
  if (now < cycle.dateVote) return PHASES_ELECTORALES.CAMPAGNE;
  if (now < cycle.dateResultats) return PHASES_ELECTORALES.VOTE;
  return PHASES_ELECTORALES.VACANT;
}

// Déposer une candidature
function deposerCandidature(posteId, country, city) {
  const nom = state.char?.name;
  if (!nom) return;

  // Vérifier domiciliation
  const domicile = state.domicile;
  if (!domicile || domicile.country !== (country || state.country)) {
    showToast('Non domicilié', 'Vous devez être domicilié dans cet empire pour vous présenter.', false);
    return;
  }

  const poste = [...(POSTES_ELECTIFS.national), ...(POSTES_ELECTIFS.departemental), ...(POSTES_ELECTIFS.local)]
    .find(p => p.id === posteId);
  if (!poste) return;

  // Vérifier niveau d'influence requis
  if ((state.inf || 0) < (poste.minInf || 0)) {
    showToast('Influence insuffisante', 'Il faut ' + poste.minInf + ' INF minimum pour ce poste.', false);
    return;
  }

  // Vérifier cumul des mandats
  if (state.poste && state.poste.id !== posteId) {
    const interdits = [['president','maire'],['president','depute'],['maire','depute']];
    const conflict = interdits.some(pair =>
      pair.includes(state.poste.id) && pair.includes(posteId)
    );
    if (conflict) {
      showToast('Cumul interdit', 'Vous ne pouvez pas cumuler ' + state.poste.name + ' et ' + poste.name + '.', false);
      return;
    }
  }

  const c = country || state.country;
  const cle = getCleCycle(posteId, city);
  if (!CYCLES_ELECTORAUX[c]) CYCLES_ELECTORAUX[c] = {};
  if (!CYCLES_ELECTORAUX[c][cle]) initCycleElectoral(c, posteId, city);

  const cycle = CYCLES_ELECTORAUX[c][cle];
  if (getPhaseActuelle(c, posteId, city) !== PHASES_ELECTORALES.CANDIDATURES) {
    showToast('Hors délai', 'Les candidatures ne sont pas ouvertes pour ce poste.', false);
    return;
  }

  if (cycle.candidats.find(ca => ca.nom === nom)) {
    showToast('Déjà candidat', 'Vous êtes déjà candidat à ce poste.', false);
    return;
  }

  // Ouvrir modal pour programme
  ouvrirModalCandidature(posteId, c, poste, cycle, city);
}

function ouvrirModalCandidature(posteId, country, poste, cycle, city) {
  const nom = state.char?.name;
  document.getElementById('postes-modal-title').textContent = '🗳️ Candidature — ' + poste.name;
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +
    '<div style="font-size:.78rem;color:#c0b090;margin-bottom:.8rem">Présentez votre programme en quelques mots. Il sera visible de tous les électeurs.</div>' +
    '<textarea id="prog-texte" rows="4" placeholder="Mon programme..." ' +
    'style="width:100%;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,Georgia,serif;font-size:.85rem;box-sizing:border-box;resize:vertical"></textarea>' +
    '<div style="display:flex;gap:.5rem;margin-top:.6rem">' +
    '<button onclick="confirmerCandidature(this)" data-poste="' + posteId + '" data-country="' + country + '" data-city="' + (city||'') + '" ' +
    'style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">' +
    '🗳️ Déposer ma candidature</button>' +
    '<button onclick="fermerModalPostes()" ' +
    'style="font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem .8rem;border:1px solid #2a2010;background:transparent;color:#6a5a30;cursor:pointer">Annuler</button>' +
    '</div></div>';
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerCandidature(el) {
  const posteId = el?.dataset?.poste || el;
  const country = el?.dataset?.country || arguments[1];
  const city = el?.dataset?.city || arguments[2] || null;
  const nom = state.char?.name;
  const programme = document.getElementById('prog-texte')?.value?.trim() || '';
  if (!programme) { showToast('Programme requis', 'Décrivez votre programme.', false); return; }

  const cle = getCleCycle(posteId, city);
  const cycle = CYCLES_ELECTORAUX[country][cle];
  const nouveauCandidat = {
    nom, programme,
    archetype: state.char?.archetype,
    posteActuel: state.poste?.name || null,
    prospectusDistribues: 0,
    dateInscription: Date.now(),
  };
  cycle.candidats.push(nouveauCandidat);
  // Persister en Supabase
  sbDeposerCandidature(country, posteId, nouveauCandidat, city).catch(() => {});
  sbSaveCycleElectoral(country, posteId, cycle, city).catch(() => {});

  document.getElementById('modal-postes').classList.remove('open');
  showToast('Candidature enregistrée !', 'Vous êtes candidat à ' + posteId + (city ? ' (' + city + ')' : '') + '.', true);
  addJournalEntry('📋 Candidature déposée au poste : ' + posteId + (city ? ' — ' + city : '') + '.', 'event-info');

  // Publier sur le forum
  if (typeof sbCreateTopic === 'function') {
    sbCreateTopic('local',
      '🗳️ Candidature de ' + nom + ' — ' + POSTES_ELECTIFS.national.concat(POSTES_ELECTIFS.local).concat(POSTES_ELECTIFS.departemental).find(p=>p.id===posteId)?.name,
      nom + ' se présente aux élections.\n\nProgramme :\n' + programme,
      nom
    );
  }
}

// Vote PJ
function voterPour(candidatNom, posteId, country, city) {
  const votant = state.char?.name;
  if (!votant) return;

  const domicile = state.domicile;
  if (!domicile || domicile.country !== country) {
    showToast('Non domicilié', 'Vous ne pouvez pas voter dans cet empire.', false);
    return;
  }

  const cle = getCleCycle(posteId, city);
  const cycle = CYCLES_ELECTORAUX[country]?.[cle];
  if (!cycle) return;

  if (getPhaseActuelle(country, posteId, city) !== PHASES_ELECTORALES.VOTE &&
      getPhaseActuelle(country, posteId, city) !== PHASES_ELECTORALES.VOTE2) {
    showToast('Vote fermé', 'Le vote n\'est pas ouvert actuellement.', false);
    return;
  }

  if (cycle.votes[votant]) {
    showToast('Déjà voté', 'Vous avez déjà voté pour ce poste.', false);
    return;
  }

  cycle.votes[votant] = candidatNom;
  // Persister en Supabase
  sbVoterPour(country, posteId, votant, candidatNom, city).catch(() => {});
  sbSaveCycleElectoral(country, posteId, cycle, city).catch(() => {});
  showToast('Vote enregistré !', 'Vous avez voté pour ' + candidatNom + '.', true);
  addJournalEntry('🗳️ Vote enregistré pour ' + candidatNom + (city ? ' (' + city + ')' : '') + '.', 'event-info');
}

// Distribuer un prospectus à un PNJ
function distribuerProspectus(pnjId, candidatNom, posteId, country, city) {
  const cle = getCleCycle(posteId, city);
  const cycle = CYCLES_ELECTORAUX[country]?.[cle];
  if (!cycle) return;

  if (state.pa < 1) { showToast('PA insuffisants', '1 PA requis.', false); return; }
  if (state.arg < 50) { showToast('Fonds insuffisants', '50 FR requis par prospectus.', false); return; }

  // Un PNJ ne peut recevoir qu'un seul prospectus
  if (cycle.votesPNJ[pnjId]) {
    showToast('Déjà converti', 'Ce PNJ a déjà reçu un prospectus.', false);
    return;
  }

  const phase = getPhaseActuelle(country, posteId, city);
  if (phase !== PHASES_ELECTORALES.CAMPAGNE && phase !== PHASES_ELECTORALES.CAMPAGNE) {
    showToast('Hors campagne', 'Les prospectus ne se distribuent que pendant la campagne.', false);
    return;
  }

  state.pa -= 1;
  state.arg -= 50;
  cycle.votesPNJ[pnjId] = candidatNom;

  // Trouver le candidat et incrémenter son compteur
  const candidat = cycle.candidats.find(c => c.nom === candidatNom);
  if (candidat) candidat.prospectusDistribues++;

  updateUI();
  showToast('Prospectus distribué !', pnjId + ' votera pour ' + candidatNom + '. -1 PA · -50 FR', true);
  addJournalEntry('📄 Prospectus distribué à ' + pnjId + ' pour ' + candidatNom + '.', 'event-info');
}

// Calculer les résultats
function calculerResultats(posteId, country) {
  const cycle = CYCLES_ELECTORAUX[country]?.[posteId];
  if (!cycle) return null;

  const scores = {};
  cycle.candidats.forEach(c => { scores[c.nom] = 0; });

  // Votes PJ
  Object.values(cycle.votes).forEach(nom => {
    if (scores[nom] !== undefined) scores[nom]++;
  });

  // Votes PNJ
  Object.values(cycle.votesPNJ).forEach(nom => {
    if (scores[nom] !== undefined) scores[nom]++;
  });

  const totalVoix = Object.values(scores).reduce((s, v) => s + v, 0);
  if (totalVoix === 0) return { scores, totalVoix: 0, elu: null, secondTour: [] };

  // Vérifier majorité absolue
  const sorted = Object.entries(scores).sort((a, b) => b[1] - a[1]);
  const premier = sorted[0];

  if (premier[1] > totalVoix / 2) {
    return { scores, totalVoix, elu: premier[0], secondTour: [] };
  }

  // Second tour — candidats > 15%
  const qualifies = sorted.filter(([, v]) => v / totalVoix >= 0.15).map(([n]) => n);
  return { scores, totalVoix, elu: null, secondTour: qualifies };
}

// Afficher le bureau de vote
function ouvrirBureauDeVote(posteId, country, city) {
  const cle = getCleCycle(posteId, city);
  const cycle = CYCLES_ELECTORAUX[country]?.[cle];
  if (!cycle || !cycle.candidats.length) {
    showToast('Aucun candidat', 'Personne ne s\'est présenté.', false);
    return;
  }

  const phase = getPhaseActuelle(country, posteId, city);
  const poste = [...POSTES_ELECTIFS.national, ...POSTES_ELECTIFS.local, ...POSTES_ELECTIFS.departemental]
    .find(p => p.id === posteId);
  const monVote = cycle.votes[state.char?.name];
  const co = COUNTRIES[country];
  const villeNom = city ? (WORLD[country]?.[city]?.name || city) : null;

  const candidatsHtml = cycle.candidats.map(ca => {
    const aVote = monVote === ca.nom;
    return '<div style="padding:.6rem .4rem;border-bottom:1px solid #1a1810">' +
      '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:.3rem">' +
        '<div style="font-family:Bebas Neue,sans-serif;font-size:.82rem;color:' + (aVote ? '#C9A84C' : '#c0b090') + '">' +
          ca.nom + (aVote ? ' ✦ (votre vote)' : '') +
        '</div>' +
        (phase === PHASES_ELECTORALES.VOTE || phase === PHASES_ELECTORALES.VOTE2
          ? (!monVote
            ? '<button onclick="voterPourCandidat(this)" data-nom="' + ca.nom + '" data-poste="' + posteId + '" data-country="' + country + '" data-city="' + (city||'') + '" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;letter-spacing:.08em;padding:.25rem .6rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">Voter</button>'
            : '') : '') +
      '</div>' +
      '<div style="font-size:.72rem;color:#8a8060;font-style:italic;margin-bottom:.2rem">' + ca.programme + '</div>' +
      (phase === PHASES_ELECTORALES.CAMPAGNE || phase === PHASES_ELECTORALES.SECOND_TOUR
        ? '<button onclick="distribuerProspectusModalBtn(this)" data-nom="' + ca.nom + '" data-poste="' + posteId + '" data-country="' + country + '" data-city="' + (city||'') + '" style="font-size:.65rem;font-family:Bebas Neue,sans-serif;letter-spacing:.06em;padding:.2rem .5rem;border:1px solid #3a5a3a;background:transparent;color:#4a8a4a;cursor:pointer">📄 Distribuer prospectus (1 PA · 50 ' + (co?.cur||'FR') + ')</button>'
        : '') +
    '</div>';
  }).join('');

  const phaseLabel = {
    [PHASES_ELECTORALES.CANDIDATURES]: '📋 Candidatures ouvertes',
    [PHASES_ELECTORALES.CAMPAGNE]:     '📢 Campagne électorale',
    [PHASES_ELECTORALES.VOTE]:         '🗳️ Vote en cours',
    [PHASES_ELECTORALES.SECOND_TOUR]:  '📢 Campagne — Second tour',
    [PHASES_ELECTORALES.VOTE2]:        '🗳️ Second tour',
  }[phase] || '❓ Phase inconnue';

  document.getElementById('postes-modal-title').textContent = '🗳️ ' + (poste?.name || posteId) + (villeNom ? ' — ' + villeNom : '') + ' — ' + (co?.n || country);
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.6rem 1rem">' +
    '<div style="font-family:Bebas Neue,sans-serif;font-size:.68rem;letter-spacing:.1em;color:#6a8a6a;margin-bottom:.6rem">' + phaseLabel + '</div>' +
    candidatsHtml +
    (phase === PHASES_ELECTORALES.CANDIDATURES
      ? '<button onclick="deposerCandidatureBtn(this)" data-poste="' + posteId + '" data-country="' + country + '" data-city="' + (city||'') + '" style="width:100%;margin-top:.8rem;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">📋 Déposer ma candidature</button>'
      : '') +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

function distribuerProspectusModal(candidatNom, posteId, country, city) {
  // Récupérer les PNJ présents dans la pièce courante
  const room = BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom];
  const persons = room?.persons || [];
  if (!persons.length) {
    showToast('Personne ici', 'Aucun PNJ à qui distribuer un prospectus.', false);
    return;
  }

  const cle = getCleCycle(posteId, city);
  const cycle = CYCLES_ELECTORAUX[country]?.[cle];
  const disponibles = persons.filter(p => !cycle?.votesPNJ[p.name]);

  if (!disponibles.length) {
    showToast('Déjà convaincus', 'Tous les PNJ présents ont déjà reçu un prospectus.', false);
    return;
  }

  const html = disponibles.map(p =>
    '<div style="display:flex;justify-content:space-between;align-items:center;padding:.4rem .2rem;border-bottom:1px solid #1a1810">' +
    '<span style="font-size:.78rem;color:#c0b090">' + p.name.replace(' (PNJ)','') + '</span>' +
    '<button onclick="distribuerProspectusBtn(this)" data-pnj="' + p.name + '" data-nom="' + candidatNom + '" data-poste="' + posteId + '" data-country="' + country + '" data-city="' + (city||'') + '" ' +
    'style="font-size:.65rem;font-family:Bebas Neue,sans-serif;padding:.2rem .5rem;border:1px solid #3a5a3a;background:transparent;color:#4a8a4a;cursor:pointer">Distribuer</button>' +
    '</div>'
  ).join('');

  document.getElementById('postes-modal-title').textContent = '📄 Distribuer pour ' + candidatNom;
  document.getElementById('postes-body').innerHTML = '<div style="padding:.6rem 1rem">' + html + '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

// Consulter les résultats via informateur
function consulterResultatsInformateur(posteId, country) {
  if (!state.informateurs?.length) {
    showToast('Informateur requis', 'Recrutez un informateur pour connaître les résultats en temps réel.', false);
    return;
  }

  const res = calculerResultats(posteId, country);
  if (!res) return;

  const sorted = Object.entries(res.scores).sort((a,b) => b[1]-a[1]);
  const html = sorted.map(([nom, voix]) => {
    const pct = res.totalVoix > 0 ? Math.round(voix/res.totalVoix*100) : 0;
    return '<div style="margin-bottom:.4rem">' +
      '<div style="display:flex;justify-content:space-between;font-size:.78rem;color:#c0b090;margin-bottom:.15rem">' +
        '<span>' + nom + '</span><span>' + voix + ' voix (' + pct + '%)</span>' +
      '</div>' +
      '<div style="height:4px;background:#1a1810;border-radius:2px">' +
        '<div style="height:100%;width:' + pct + '%;background:#C9A84C;border-radius:2px"></div>' +
      '</div></div>';
  }).join('');

  document.getElementById('postes-modal-title').textContent = '🕵️ Résultats en temps réel';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.6rem 1rem">' +
    '<div style="font-size:.68rem;color:#6a5a30;margin-bottom:.6rem;font-style:italic">Source : informateur. ' + res.totalVoix + ' voix comptabilisées.</div>' +
    html +
    (res.elu ? '<div style="margin-top:.6rem;font-size:.78rem;color:#4a8a4a">→ Majorité atteinte : ' + res.elu + ' élu(e) si le vote clôture maintenant.</div>' : '') +
    (res.secondTour.length ? '<div style="margin-top:.6rem;font-size:.78rem;color:#aa8a4a">→ Second tour probable entre : ' + res.secondTour.join(', ') + '.</div>' : '') +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

// Afficher le tableau de bord électoral complet
function ouvrirTableauElectoral() {
  const country = state.country;
  const co = COUNTRIES[country];
  const villeCourante = state.currentCity || 'capitale';
  const villeNom = WORLD[country]?.[villeCourante]?.name || villeCourante;

  if (!CYCLES_ELECTORAUX[country]) {
    POSTES_ELECTIFS.national.forEach(p => initCycleElectoral(country, p.id));
  }

  const postes = [...POSTES_ELECTIFS.national, ...POSTES_ELECTIFS.departemental, ...POSTES_ELECTIFS.local];
  const html = postes.map(p => {
    const estLocal = posteEstLocal(p.id);
    const city = estLocal ? villeCourante : null;
    const cle = getCleCycle(p.id, city);
    const cycle = CYCLES_ELECTORAUX[country]?.[cle];
    const phase = cycle ? getPhaseActuelle(country, p.id, city) : 'Non initialisé';
    const nbCandidats = cycle?.candidats.length || 0;
    const titulaire = state.postes?.[country]?.[p.id] || 'Vacant';
    const labelPoste = p.name + (estLocal ? ' — ' + villeNom : '');

    const phaseCol = {
      [PHASES_ELECTORALES.CANDIDATURES]: '#4a6aaa',
      [PHASES_ELECTORALES.CAMPAGNE]:     '#aa8a4a',
      [PHASES_ELECTORALES.VOTE]:         '#4a8a4a',
      [PHASES_ELECTORALES.SECOND_TOUR]:  '#8a6a4a',
      [PHASES_ELECTORALES.VOTE2]:        '#4a8a4a',
      [PHASES_ELECTORALES.VACANT]:       '#8a3a2a',
    }[phase] || '#6a5a30';

    return '<div style="padding:.5rem .4rem;border-bottom:1px solid #1a1810">' +
      '<div style="display:flex;justify-content:space-between;align-items:center">' +
        '<div>' +
          '<div style="font-family:Bebas Neue,sans-serif;font-size:.78rem;color:#c0b090">' + labelPoste + '</div>' +
          '<div style="font-size:.65rem;color:#6a5a30">' + titulaire + '</div>' +
        '</div>' +
        '<div style="text-align:right">' +
          '<div style="font-size:.65rem;color:' + phaseCol + ';font-family:Bebas Neue,sans-serif">' + (phase || 'N/A') + '</div>' +
          '<div style="font-size:.62rem;color:#4a4030">' + nbCandidats + ' candidat(s)</div>' +
        '</div>' +
      '</div>' +
    '<button onclick="ouvrirBureauDeVoteBtn(this)" data-poste="' + p.id + '" data-country="' + country + '" data-city="' + (city||'') + '" ' +
      'style="margin-top:.3rem;font-size:.65rem;font-family:Bebas Neue,sans-serif;letter-spacing:.06em;padding:.2rem .5rem;border:1px solid #2a2010;background:transparent;color:#8a8060;cursor:pointer">Voir détails →</button>' +
    '</div>';
  }).join('');

  document.getElementById('postes-modal-title').textContent = '🗳️ Élections — ' + (co?.n || country);
  document.getElementById('postes-body').innerHTML = '<div style="padding:.4rem .6rem">' + html + '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

// Changer de domicile (depuis la mairie)
function changerDomicile(newCountry, newCity) {
  const co = COUNTRIES[newCountry];
  const cur = co?.cur || 'FR';
  const cout = 200;

  if (state.arg < cout) {
    showToast('Fonds insuffisants', cout + ' ' + cur + ' requis pour changer de domicile.', false);
    return;
  }

  state.arg -= cout;
  const ancienDomicile = state.domicile;
  state.domicile = { country: newCountry, city: newCity, depuis: state.day || 1 };

  // Perdre les postes liés à l'ancienne domiciliation
  if (state.poste) {
    const postesLocaux = ['maire', 'depute'];
    if (postesLocaux.includes(state.poste.id)) {
      addJournalEntry('⚠️ Changement de domicile : vous perdez votre poste de ' + state.poste.name + '.', 'event-bad');
      state.poste = null;
    if (state.char) state.char.poste = null;
    }
  }

  updateUI();
  showToast('Domicile changé !', newCity + ', ' + co?.n + '. -' + cout + ' ' + cur, true);
  addJournalEntry('🏠 Nouveau domicile : ' + newCity + ', ' + (co?.n || newCountry) + '.', 'event-info');
}



function confirmerCreationOrgaBtn(el) { confirmerCreationOrga(el.dataset.type); }
function ouvrirForumOrgaBtn(el) { ouvrirForumOrga(el.dataset.id); }
function ouvrirGestionOrgaBtn(el) { ouvrirGestionOrga(el.dataset.id); }
function posterMessageOrgaBtn(el) { posterMessageOrga(el.dataset.id); }
function ouvrirCreationOrgaBtn(el) { ouvrirCreationOrga(el.dataset.type); }


// =====================
// ALLIANCES ENTRE PJ
// =====================
function ouvrirMenuAlliances() {
  if (typeof sbListPersonnages !== 'function') {
    showToast('Indisponible', 'Connexion Supabase requise.', false);
    return;
  }

  const alliances = state.alliances || [];
  const demandesRecues = state.demandes_alliance || [];

  sbListPersonnages().then(joueurs => {
    const autres = (joueurs || []).filter(j => j.name !== state.char?.name);
    const cur = COUNTRIES[state.country]?.cur || 'FR';

    const alliancesHtml = alliances.length > 0
      ? '<div style="margin-bottom:.8rem">' +
        '<div style="font-family:Bebas Neue,sans-serif;font-size:.65rem;letter-spacing:.12em;color:#4a8a4a;margin-bottom:.4rem">VOS ALLIANCES ACTIVES</div>' +
        alliances.map(a =>
          '<div style="display:flex;justify-content:space-between;align-items:center;padding:.3rem .4rem;border-bottom:1px solid #1a1810">' +
          '<span style="font-size:.78rem;color:#c0b090">' + a.nom + '</span>' +
          '<span style="font-size:.65rem;color:#4a8a4a">' + a.type + '</span>' +
          '<button onclick="rompreAlliance(this)" data-nom="' + a.nom + '" style="font-size:.6rem;color:#8a3a2a;background:none;border:none;cursor:pointer">Rompre</button>' +
          '</div>'
        ).join('') +
        '</div>'
      : '<div style="font-size:.72rem;color:#4a4030;margin-bottom:.8rem;font-style:italic">Aucune alliance active.</div>';

    const demandesHtml = demandesRecues.length > 0
      ? '<div style="margin-bottom:.8rem">' +
        '<div style="font-family:Bebas Neue,sans-serif;font-size:.65rem;letter-spacing:.12em;color:#C9A84C;margin-bottom:.4rem">DEMANDES REÇUES</div>' +
        demandesRecues.map(d =>
          '<div style="display:flex;justify-content:space-between;align-items:center;padding:.3rem .4rem;border-bottom:1px solid #1a1810">' +
          '<span style="font-size:.78rem;color:#c0b090">' + d.de + ' → ' + d.type + '</span>' +
          '<div style="display:flex;gap:.4rem">' +
          '<button onclick="accepterAlliance(this)" data-de="' + d.de + '" data-type="' + d.type + '" style="font-size:.65rem;color:#4a8a4a;background:none;border:1px solid #2a5a2a;padding:.2rem .4rem;cursor:pointer">✓ Accepter</button>' +
          '<button onclick="refuserAlliance(this)" data-de="' + d.de + '" style="font-size:.65rem;color:#8a3a2a;background:none;border:1px solid #5a2a2a;padding:.2rem .4rem;cursor:pointer">✗ Refuser</button>' +
          '</div></div>'
        ).join('') +
        '</div>'
      : '';

    const proposerHtml = autres.length > 0
      ? '<div>' +
        '<div style="font-family:Bebas Neue,sans-serif;font-size:.65rem;letter-spacing:.12em;color:#6a5a30;margin-bottom:.4rem">PROPOSER UNE ALLIANCE</div>' +
        '<select id="alliance-joueur" style="width:100%;background:#0a0a07;border:1px solid #2a2010;color:#c0b090;padding:.3rem;margin-bottom:.4rem;font-family:Crimson Pro,Georgia,serif">' +
        autres.map(j => '<option value="' + j.name + '">' + j.name + '</option>').join('') +
        '</select>' +
        '<select id="alliance-type" style="width:100%;background:#0a0a07;border:1px solid #2a2010;color:#c0b090;padding:.3rem;margin-bottom:.4rem;font-family:Crimson Pro,Georgia,serif">' +
        '<option value="Non-agression">Pacte de non-agression</option>' +
        '<option value="Coalition électorale">Coalition électorale</option>' +
        '<option value="Partage d\'informateurs">Partage d\'informateurs</option>' +
        '<option value="Alliance économique">Alliance économique</option>' +
        '</select>' +
        '<button onclick="proposerAlliance()" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.4rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">Envoyer la proposition</button>' +
        '</div>'
      : '<div style="font-size:.72rem;color:#4a4030;font-style:italic">Aucun autre joueur disponible.</div>';

    document.getElementById('postes-modal-title').textContent = '🤝 Alliances';
    document.getElementById('postes-body').innerHTML =
      '<div style="padding:.6rem 1rem">' + alliancesHtml + demandesHtml + proposerHtml + '</div>';
    document.getElementById('modal-postes').classList.add('open');
  }).catch(() => showToast('Erreur', 'Impossible de charger les joueurs.', false));
}

async function proposerAlliance() {
  const joueur = document.getElementById('alliance-joueur')?.value;
  const type   = document.getElementById('alliance-type')?.value;
  if (!joueur || !type) return;

  const from = state.char?.name || 'Anonyme';
  const sujet = '🤝 Proposition d\'alliance : ' + type;
  const corps = from + ' vous propose une alliance de type <strong>' + type + '</strong>.<br><br>' +
    'Pour accepter, répondez à ce mail avec "J\'accepte". Pour refuser, répondez "Je refuse".';

  if (typeof sendMail === 'function') await sendMail(joueur, sujet, corps);
  document.getElementById('modal-postes').classList.remove('open');
  showToast('Proposition envoyée !', joueur + ' a reçu votre demande d\'alliance.', true);
  addJournalEntry('Proposition d\'alliance (' + type + ') envoyée à ' + joueur + '.', 'event-info');
}

function accepterAlliance(el) {
  const de = el?.dataset?.de || el;
  const type = el?.dataset?.type || arguments[1];
  if (!state.alliances) state.alliances = [];
  state.alliances.push({ nom: de, type: type, depuis: state.day || 1 });
  state.demandes_alliance = (state.demandes_alliance || []).filter(d => d.de !== de);
  if (typeof sendMail === 'function') {
    sendMail(de, '✅ Alliance acceptée', state.char?.name + ' accepte votre proposition d\'alliance : ' + type + '.');
  }
  document.getElementById('modal-postes').classList.remove('open');
  showToast('Alliance conclue !', 'Avec ' + de + ' — ' + type, true);
  addJournalEntry('Alliance conclue avec ' + de + ' : ' + type + '.', 'event-good');
}

function refuserAlliance(el) {
  const de = el?.dataset?.de || el;
  state.demandes_alliance = (state.demandes_alliance || []).filter(d => d.de !== de);
  if (typeof sendMail === 'function') {
    sendMail(de, '❌ Alliance refusée', state.char?.name + ' décline votre proposition d\'alliance.');
  }
  ouvrirMenuAlliances();
}

function rompreAlliance(el) {
  const nom = el?.dataset?.nom || el;
  state.alliances = (state.alliances || []).filter(a => a.nom !== nom);
  if (typeof sendMail === 'function') {
    sendMail(nom, '⚠️ Alliance rompue', state.char?.name + ' met fin à votre alliance.');
  }
  showToast('Alliance rompue', 'Avec ' + nom, false);
  addJournalEntry('Alliance rompue avec ' + nom + '.', 'event-bad');
  ouvrirMenuAlliances();
}

// =====================
// OBJECTIFS SECRETS PAR ARCHÉTYPE
// =====================
const OBJECTIFS_SECRETS = {
  ambitieux: {
    label: 'L\'Ambitieux',
    objectifs: [
      { id: 'obj_president',   desc: 'Devenir Président de votre empire',          condition: s => s.poste?.id === 'president',                                          points: 50 },
      { id: 'obj_inf80',       desc: 'Atteindre 80 points d\'Influence',           condition: s => (s.inf||0) >= 80,                                                     points: 20 },
      { id: 'obj_poste_haut',  desc: 'Occuper un poste ministériel',               condition: s => s.poste && !['citoyen','depute'].includes(s.poste.id),                 points: 15 },
      { id: 'obj_argent_50k',  desc: 'Accumuler 50 000 FR en banque',              condition: s => (s.banque||0) >= 50000,                                               points: 25 },
    ]
  },
  criminel: {
    label: 'Le Criminel',
    objectifs: [
      { id: 'obj_blanchir',    desc: 'Blanchir 20 000 FR via des activités louches', condition: s => (s.argent_blanchi||0) >= 20000,                                    points: 40 },
      { id: 'obj_dis90',       desc: 'Maintenir une Discrétion supérieure à 90',  condition: s => (s.dis||0) >= 90,                                                      points: 20 },
      { id: 'obj_informateur', desc: 'Recruter 2 informateurs simultanément',      condition: s => (s.informateurs||[]).length >= 2,                                     points: 15 },
      { id: 'obj_jamais_arrete',desc: 'Ne jamais être arrêté pendant 10 jours',   condition: s => (s.jours_libres||0) >= 10,                                            points: 30 },
    ]
  },
  journaliste: {
    label: 'Le Journaliste',
    objectifs: [
      { id: 'obj_scandales',   desc: 'Publier 5 scandales sur le forum',           condition: s => (s.scandales_publies||0) >= 5,                                        points: 30 },
      { id: 'obj_sondages',    desc: 'Commander 3 sondages absurdes',              condition: s => (s.sondages_commandes||0) >= 3,                                       points: 15 },
      { id: 'obj_micro',       desc: 'Interviewer 5 PNJ différents',               condition: s => (s.pnj_interviewes||[]).length >= 5,                                  points: 20 },
      { id: 'obj_forum_actif', desc: 'Publier 10 posts sur le forum',              condition: s => (s.posts_forum||0) >= 10,                                             points: 25 },
    ]
  },
  fonctionnaire: {
    label: 'Le Fonctionnaire',
    objectifs: [
      { id: 'obj_poste_stable', desc: 'Conserver le même poste 7 jours',           condition: s => (s.jours_meme_poste||0) >= 7,                                        points: 25 },
      { id: 'obj_formulaires',  desc: 'Remplir 10 demandes administratives',       condition: s => (s.formulaires_remplis||0) >= 10,                                    points: 15 },
      { id: 'obj_corruption',   desc: 'Corrompre 3 fonctionnaires',                condition: s => (s.fonctionnaires_corrompus||0) >= 3,                                 points: 20 },
      { id: 'obj_banque_stable', desc: 'Avoir 15 000 FR en banque pendant 5 jours',condition: s => (s.jours_banque_15k||0) >= 5,                                        points: 30 },
    ]
  },
  militaire: {
    label: 'Le Militaire',
    objectifs: [
      { id: 'obj_caserne',      desc: 'Visiter la caserne 5 fois',                 condition: s => (s.visites_caserne||0) >= 5,                                         points: 15 },
      { id: 'obj_ordre',        desc: 'Faire appel à la police 3 fois',            condition: s => (s.appels_police||0) >= 3,                                           points: 20 },
      { id: 'obj_hp_max',       desc: 'Maintenir 100 HP pendant 5 jours',          condition: s => (s.jours_hp_max||0) >= 5,                                            points: 25 },
      { id: 'obj_ministre_def', desc: 'Devenir Ministre de la Défense',            condition: s => s.poste?.id === 'ministre_defense',                                  points: 40 },
    ]
  },
  religieux: {
    label: 'Le Religieux',
    objectifs: [
      { id: 'obj_pop80',        desc: 'Atteindre 80 de Popularité',                condition: s => (s.pop||0) >= 80,                                                    points: 25 },
      { id: 'obj_moral_max',    desc: 'Maintenir 100 de Moral pendant 5 jours',   condition: s => (s.jours_moral_max||0) >= 5,                                         points: 20 },
      { id: 'obj_pelerinage',   desc: 'Visiter 3 empires différents',              condition: s => (s.empires_visites||[]).length >= 3,                                  points: 30 },
      { id: 'obj_sermons',      desc: 'Publier 5 messages inspirants sur le forum',condition: s => (s.sermons_publies||0) >= 5,                                         points: 20 },
    ]
  }
};

function afficherObjectifsSecrets() {
  const archetype = state.char?.archetype || 'ambitieux';
  const obj = OBJECTIFS_SECRETS[archetype] || OBJECTIFS_SECRETS.ambitieux;
  const completed = state.objectifs_completes || [];

  // Vérifier nouvelles complétion
  obj.objectifs.forEach(o => {
    if (!completed.includes(o.id) && o.condition(state)) {
      completed.push(o.id);
      state.objectifs_completes = completed;
      state.inf = Math.min(100, (state.inf||0) + Math.floor(o.points/5));
      showToast('🎯 Objectif accompli !', o.desc + ' (+' + o.points + ' pts)', true);
      addJournalEntry('🎯 Objectif secret accompli : ' + o.desc, 'event-good');
    }
  });

  const totalPoints = obj.objectifs.reduce((s,o) => s + (completed.includes(o.id) ? o.points : 0), 0);
  const maxPoints   = obj.objectifs.reduce((s,o) => s + o.points, 0);

  const html = obj.objectifs.map(o => {
    const done = completed.includes(o.id);
    return '<div style="display:flex;align-items:center;gap:.6rem;padding:.5rem .4rem;border-bottom:1px solid #1a1810">' +
      '<div style="font-size:1rem">' + (done ? '✅' : '⬜') + '</div>' +
      '<div style="flex:1">' +
        '<div style="font-size:.78rem;color:' + (done ? '#4a8a4a' : '#c0b090') + '">' + o.desc + '</div>' +
        '<div style="font-size:.65rem;color:#8a7050">' + o.points + ' points</div>' +
      '</div>' +
    '</div>';
  }).join('');

  document.getElementById('postes-modal-title').textContent = '🎯 Objectifs — ' + obj.label;
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.6rem 1rem">' +
    '<div style="font-size:.7rem;color:#C9A84C;font-family:Bebas Neue,sans-serif;letter-spacing:.08em;margin-bottom:.6rem">' +
      'Score : ' + totalPoints + ' / ' + maxPoints + ' points' +
    '</div>' +
    html +
    '<div style="font-size:.65rem;color:#8a7050;margin-top:.6rem;font-style:italic">Ces objectifs sont secrets — les autres joueurs ne les voient pas.</div>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

// Vérifier objectifs à chaque updateUI
let _verifyingObjectifs = false;
function verifierObjectifs() {
  if (_verifyingObjectifs) return;
  const archetype = state.char?.archetype;
  if (!archetype || !OBJECTIFS_SECRETS[archetype]) return;
  const obj = OBJECTIFS_SECRETS[archetype];
  const completed = state.objectifs_completes || [];
  let changed = false;
  obj.objectifs.forEach(o => {
    try {
      if (!completed.includes(o.id) && o.condition(state)) {
        completed.push(o.id);
        state.objectifs_completes = completed;
        changed = true;
        showToast('🎯 Objectif accompli !', o.desc, true);
        addJournalEntry('🎯 ' + o.desc, 'event-good');
      }
    } catch(e) {} // Condition peut échouer si state incomplet
  });
  if (changed) {
    _verifyingObjectifs = true;
    state.inf = Math.min(100, (state.inf||0) + 2);
    _verifyingObjectifs = false;
  }
}

// =====================
// JOURNAL DU MATIN
// =====================
async function afficherJournalDuMatin() {
  const today = state.day || 1;
  const sessionKey = 'journal_matin_day_' + today;
  if (sessionStorage.getItem(sessionKey)) return;
  sessionStorage.setItem(sessionKey, '1');

  const co = COUNTRIES[state.country];
  const empireStyle = EMPIRE_STYLES?.[state.country] || { tone: 'parodique', religion: 'la Foi Locale', leader: 'le Chef' };
  // Récupérer la vraie situation politique depuis Supabase
  let presidentNom = 'Poste vacant';
  let autresPostes = [];
  let resumeActions = '';
  let topics = '';

  if (typeof sbListPersonnages === 'function') {
    try {
      const joueurs = await sbListPersonnages() || [];
      const memeEmpire = joueurs.filter(j => j.country === state.country);
      const president = memeEmpire.find(j => j.poste && j.poste.id === 'president');
      presidentNom = president?.name || 'Poste vacant';
      autresPostes = memeEmpire
        .filter(j => j.poste && j.poste.id !== 'president' && j.name !== state.char?.name)
        .map(j => j.name + ' (' + j.poste.name + ')')
        .slice(0, 3);
      const autres = joueurs.filter(j => j.name !== state.char?.name);
      if (autres.length > 0) {
        resumeActions = autres.slice(0,3).map(j => j.name + ' vu à ' + (j.current_city || 'lieu inconnu')).join(', ');
      }
    } catch(e) {}
  }

  if (typeof FORUM_TOPICS !== 'undefined') {
    topics = (FORUM_TOPICS['local'] || []).slice(0, 3).map(t => '"' + t.title + '" (par ' + t.author + ')').join(', ');
  }

  // Mentionner la quete active, le cas echeant
  let queteInfo = '';
  if (typeof sbGetQueteActive === 'function') {
    try {
      const quete = await sbGetQueteActive(state.country);
      if (quete) queteInfo = 'Une affaire est en cours : "' + quete.titre + '" (' + quete.description + ').';
    } catch(e) {}
  }

  const contextePolitique = presidentNom !== 'Poste vacant'
    ? presidentNom + ' occupe la présidence.'
    : 'Le fauteuil présidentiel est vacant.';
  const contextPostes = autresPostes.length > 0 ? 'Autres postes : ' + autresPostes.join(', ') + '.' : '';

  const prompt = 'Tu es le rédacteur du journal du matin dans ' + (co?.n || 'l\'empire') + ', jeu politique parodique. ' +
    'Style : ' + empireStyle.tone + '. Religion : ' + empireStyle.religion + '. ' +
    'SITUATION RÉELLE DU JOUR : ' + contextePolitique + ' ' + contextPostes + ' ' +
    (resumeActions ? 'Joueurs actifs : ' + resumeActions + '. ' : '') +
    (topics ? 'Sujets du forum : ' + topics + '. ' : '') +
    (queteInfo ? queteInfo + ' Mentionne cette affaire dans une des breves. ' : '') +
    'Jour ' + today + '. ' +
    'Rédige un bref journal du matin parodique COHÉRENT avec cette situation réelle : 1 titre + 3 brèves drôles. ' +
    'Si un président est nommé, ne dis PAS que le fauteuil est vide. Pas de vrais dieux. Max 6 lignes.';

  try {
    const resp = await fetch('/api/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ model: 'claude-sonnet-4-5', max_tokens: 200, messages: [{ role: 'user', content: prompt }] })
    });
    const data = await resp.json();
    const journal = data.content?.[0]?.text;
    if (!journal) return;

    // Afficher dans un modal dédié
    document.getElementById('postes-modal-title').textContent = '📰 Journal du Matin — Jour ' + today;
    document.getElementById('postes-body').innerHTML =
      '<div style="padding:.8rem 1rem">' +
      '<div style="font-size:.7rem;color:#6a5a30;margin-bottom:.6rem;font-family:Bebas Neue,sans-serif;letter-spacing:.08em">' +
        co?.n?.toUpperCase() + ' · ÉDITION DU JOUR ' + today +
      '</div>' +
      '<div style="font-size:.85rem;color:#c0b090;line-height:1.9;white-space:pre-line;font-family:Crimson Pro,Georgia,serif;border-left:2px solid #3a2a10;padding-left:.8rem">' +
        journal +
      '</div>' +
      '<div style="margin-top:.8rem;display:flex;gap:.5rem">' +
        '<button onclick="publierJournal(this.dataset.txt)" data-txt="' + journal.replace(/"/g,'&quot;') + '" ' +
        'style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.4rem .8rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">' +
        '<i class="ti ti-news" style="font-size:.7rem"></i> Publier sur le forum</button>' +
        '<button onclick="document.getElementById(\'modal-postes\').classList.remove(\'open\')" ' +
        'style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.4rem .8rem;border:1px solid #3a2a10;background:transparent;color:#6a5a30;cursor:pointer">Fermer</button>' +
      '</div></div>';
    document.getElementById('modal-postes').classList.add('open');

    addJournalEntry('📰 Journal du matin disponible — Jour ' + today, 'event-info');
  } catch(e) {}
}

async function publierJournal(texte) {
  document.getElementById('modal-postes').classList.remove('open');
  if (typeof sbCreateTopic === 'function') {
    const from = state.char?.name || 'Rédaction';
    await sbCreateTopic('local', '📰 Journal du Matin — Jour ' + (state.day||1), texte, from);
    showToast('Journal publié !', 'Visible sur le forum local.', true);
  }
}

// =====================
// MÉTÉO POLITIQUE QUOTIDIENNE
