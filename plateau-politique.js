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


// =====================
// COMPLEMENT POLITIQUE (room actions, decrets, organigramme, presidentiel, guerre, loi, assemblee, naturalisation, annuaire, nominations)
// =====================

// =====================
// ROOM ACTIONS
// =====================
function renderRoomActions(room, buildingId, roomId) {
  const orders = room.orders || [];
  const cur = COUNTRIES[state.char?.country || 'republic']?.cur || 'FR';

  document.getElementById('action-context-bat').textContent =
    room.name.toUpperCase() + ' — ACTIONS DISPONIBLES';

  // Plus d'ordres communs ici — se_cacher/blocus/incendier sont dans la fiche personnage
  const allOrders = [...orders];

  const buttons = allOrders.map(o => {
    // Verifier requiresPost : doit avoir le bon poste specifique
    let needsPost = false;
    if (o.requiresPost) {
      if (o.requiresPost === true) {
        // Juste avoir un poste
        needsPost = !state.poste;
      } else {
        // Verifier le poste specifique
        const posteId = state.poste?.id || '';
        const reqPost = o.requiresPost;
        if (reqPost === 'president') needsPost = posteId !== 'president';
        else if (reqPost === 'pm') needsPost = posteId !== 'pm';
        else if (reqPost === 'depute') needsPost = !posteId.startsWith('depute');
        else if (reqPost === 'juge') needsPost = posteId !== 'juge';
        else if (reqPost === 'magistrat') needsPost = !['juge','procureur'].includes(posteId);
        else if (reqPost === 'commissaire') needsPost = posteId !== 'commissaire';
        else needsPost = posteId !== reqPost;
      }
    }
    const paDisplay = TEST_MODE ? '0 PA' : o.pa + ' PA';
    // Appliquer malus ISN sur les actes illegaux
    let tauxAffiche = o.successRate || 70;
    if (o.type === 'illegal') {
      tauxAffiche = Math.max(5, tauxAffiche - getMalusISN());
    }
    const costDisplay = o.cost > 0 ? o.cost.toLocaleString('fr-FR') + ' ' + cur : 'gratuit';
    const ef = ORDER_EFFECTS[o.fn] || {};
    const gainParts = [];
    if (ef.hp > 0)    gainParts.push('+' + ef.hp + ' Sante');
    if (ef.moral > 0) gainParts.push('+' + ef.moral + ' Moral');
    if (ef.inf > 0)   gainParts.push('+' + ef.inf + ' INF');
    if (ef.pop > 0)   gainParts.push('+' + ef.pop + ' POP');
    if (ef.arg > 0)   gainParts.push('+' + ef.arg + ' ' + cur);
    const gainStr = gainParts.join(' · ');
    const riskParts = [];
    if (ef.dis < 0)   riskParts.push(ef.dis + ' DIS');
    if (ef.pop < 0)   riskParts.push(ef.pop + ' POP');
    const riskStr = riskParts.join(' · ');
    const rate = o.successRate || 70;
    const tooltipParts = [];
    if (o.desc) tooltipParts.push(o.desc);
    if (gainStr) tooltipParts.push('Gain: ' + gainStr);
    if (riskStr) tooltipParts.push('Risque: ' + riskStr);
    tooltipParts.push('Reussite: ' + rate + '%');
    const tooltip = tooltipParts.join(' | ');

    let onclickFn = '';
    if (needsPost) {
      // Message explicatif avec le poste requis
      const postesNoms = {
        president: 'Président de la République',
        pm: 'Premier Ministre',
        depute: 'Député',
        juge: 'Juge',
        magistrat: 'Magistrat',
        commissaire: 'Commissaire',
        min_int: "Ministre de l'Intérieur",
        min_fin: 'Ministre des Finances',
        min_just: 'Ministre de la Justice',
        min_def: 'Ministre de la Défense',
        min_info: "Ministre de l'Information",
        min_ae: 'Ministre des AE'
      };
      const posteRequisNom = o.requiresPost === true ? 'un poste institutionnel' : (postesNoms[o.requiresPost] || o.requiresPost);
      onclickFn = 'showPostRequired(' + JSON.stringify(posteRequisNom) + ')';
    } else if (o.fn === 'plainte_police') {
      onclickFn = 'openPlainteModal()';
    } else if (o.fn === 'gerer_finances') {
      onclickFn = 'openFinancesModal()';
    } else if (o.fn === 'postuler') {
      onclickFn = 'openPostesModal()';
    } else {
      const safeLabel = o.label.replace(/'/g, ' ');
      const safeDesc = (o.desc||'').replace(/'/g, ' ');
      onclickFn = "doOrder('" + o.fn + "'," + o.pa + "," + o.cost + ",'" + safeLabel + "','" + safeDesc + "'," + rate + ")";
    }

    const gainBadge = gainStr ? '<span class="action-gain">' + gainStr + '</span>' : '';
    const blockedCls = needsPost ? ' blocked' : '';
    return '<button class="action-btn ' + o.type + blockedCls + '" onclick="' + onclickFn + '" title="' + tooltip + '"><i class="ti ' + o.icon + '" style="font-size:.82rem"></i> ' + o.label + ' <span class="pa-cost">' + costDisplay + ' · ' + paDisplay + '</span>' + gainBadge + '</button>';
  });

  document.getElementById('actions-row-bat').innerHTML = buttons.join('') ||
    '<div style="font-size:.75rem;color:#3a3020;font-style:italic;padding:.3rem">Aucune action disponible ici.</div>';
}


// DÉCRETS PRÉSIDENTIELS
// =====================
async function signerDecretInutile() {
  if (state.poste?.id !== 'president') {
    showToast('Accès refusé', 'Seul le Président peut signer des décrets.', false);
    return;
  }

  const co = COUNTRIES[state.country];
  const cur = co?.cur || 'FR';
  const empireStyle = EMPIRE_STYLES?.[state.country] || { tone: 'parodique', religion: 'la Foi Locale', leader: 'le Chef' };

  const sujets = [
    'la couleur officielle des formulaires administratifs',
    'l\'heure légale de la sieste nationale',
    'l\'obligation de saluer le portrait du président en entrant dans les bâtiments',
    'la taxe sur les soupirs excessifs dans les couloirs officiels',
    'la nomination d\'un Commissaire aux Bonnes Nouvelles',
    'l\'interdiction des réunions se terminant sans conclusion',
    'la journée nationale du silence administratif',
    'l\'instauration d\'une prime à la loyauté inconditionnelle',
    'la mise en place d\'un formulaire pour contester les formulaires',
    'l\'obligation de finir chaque discours par une citation du Président'
  ];
  const sujet = sujets[Math.floor(Math.random() * sujets.length)];

  document.getElementById('postes-modal-title').textContent = 'Rédaction du Décret...';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060;font-style:italic">La plume présidentielle est à l\'œuvre...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const prompt = 'Tu es le rédacteur des décrets présidentiels dans ' + (co?.n || 'l\'empire') + ', jeu parodique. ' +
    'Style : ' + empireStyle.tone + '. Religion : ' + empireStyle.religion + '. ' +
    'Rédige un décret présidentiel ABSURDE et PARODIQUE sur : ' + sujet + '. ' +
    'Format : Titre officiel + Article 1 + Article 2 + Effet parodique sur la population. ' +
    'Max 6 lignes. Très drôle. Pas de vrais dieux ni religions réelles.';

  try {
    const resp = await fetch('/api/chat', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({ model: 'claude-sonnet-4-5', max_tokens: 250, messages: [{ role: 'user', content: prompt }] })
    });
    const data = await resp.json();
    const decret = data.content?.[0]?.text || 'Décret indisponible.';

    // Effets gameplay
    const popEffect = Math.floor(Math.random() * 20) - 5; // -5 à +15
    const infEffect = Math.floor(Math.random() * 10) + 2;
    state.pop = Math.max(0, Math.min(100, (state.pop || 50) + popEffect));
    state.inf = Math.min(100, (state.inf || 0) + infEffect);
    updateUI();

    document.getElementById('postes-modal-title').textContent = '📜 Décret Présidentiel';
    document.getElementById('postes-body').innerHTML =
      '<div style="padding:1rem">' +
      '<div style="font-size:.7rem;color:#6a5a30;margin-bottom:.6rem;border-bottom:1px solid #2a2010;padding-bottom:.4rem">Signé par ' + (state.char?.name || 'Le Président') + ' · Jour ' + (state.day || 1) + '</div>' +
      '<div style="font-size:.85rem;color:#c0a060;line-height:1.9;white-space:pre-line;font-family:Crimson Pro,Georgia,serif">' + decret + '</div>' +
      '<div style="margin-top:.8rem;font-size:.72rem;color:' + (popEffect >= 0 ? '#4a8a4a' : '#8a3a2a') + '">' +
        (popEffect >= 0 ? '+' : '') + popEffect + ' POP · +' + infEffect + ' INF</div>' +
      '<div style="margin-top:.6rem;display:flex;gap:.5rem">' +
      '<button onclick="publierDecret(this.dataset.txt)" data-txt="' + decret.replace(/"/g, '&quot;') + '" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.4rem .8rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer"><i class="ti ti-speakerphone" style="font-size:.7rem"></i> Publier</button>' +
      '<button onclick="document.getElementById(\'modal-postes\').classList.remove(\'open\')" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.4rem .8rem;border:1px solid #3a2a10;background:transparent;color:#6a5a30;cursor:pointer">Fermer</button>' +
      '</div></div>';

    addJournalEntry('📜 Décret signé sur : ' + sujet + '. ' + (popEffect >= 0 ? '+' : '') + popEffect + ' POP · +' + infEffect + ' INF.', 'event-info');

  } catch(e) {
    document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a3a20">Erreur de rédaction. La plume est fatiguée.</div>';
  }
}

async function publierDecret(texte) {
  document.getElementById('modal-postes').classList.remove('open');
  if (typeof sbCreateTopic === 'function') {
    const from = state.char?.name || 'Le Président';
    await sbCreateTopic('local', '📜 Décret Présidentiel', texte, from);
    showToast('Décret publié !', 'Visible sur le forum national.', true);
  }
}



function ouvrirCadavreListe(el) {
  const photo = el.dataset.photo;
  const pos   = el.dataset.pos || '50% 40%';
  const role  = el.dataset.role || 'Cadavre';
  const trait = el.dataset.trait || '';
  ouvrirPhotoCadavre(JSON.stringify({ photoUrl: photo, photoPos: pos, role, trait }));
}

function ouvrirPhotoCadavre(jsonStr) {
  try {
    const pnj = JSON.parse(jsonStr);
    const overlay = document.createElement('div');
    overlay.onclick = () => overlay.remove();
    overlay.style.cssText = 'position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,0.95);z-index:99999;display:flex;flex-direction:column;align-items:center;justify-content:center;cursor:pointer';
    const photoHtml = pnj.photoUrl
      ? '<img src="' + pnj.photoUrl + '" style="max-width:85vw;max-height:70vh;object-fit:contain;border:1px solid #3a2a10;margin-bottom:.8rem"/>'
      : '<div style="font-size:4rem;margin-bottom:.8rem">💀</div>';
    overlay.innerHTML = photoHtml +
      '<div style="font-family:Bebas Neue,sans-serif;font-size:.9rem;letter-spacing:.12em;color:#8a3a2a;margin-bottom:.4rem">' + (pnj.role || 'Cadavre') + '</div>' +
      '<div style="font-size:.78rem;color:#6a5a30;font-style:italic;max-width:400px;text-align:center;padding:0 1rem">' + (pnj.trait || '') + '</div>' +
      '<div style="font-size:.62rem;color:#3a3020;margin-top:1rem">Cliquer pour fermer</div>';
    document.body.appendChild(overlay);
  } catch(e) {}
}

// =====================

// ORGANIGRAMME
// =====================
function ouvrirOrganigramme() {
  const postes = POSTES[state.country];
  if (!postes) return;
  const co = COUNTRIES[state.country];
  const myName = state.char?.name || '';

  const sections = [
    { title: 'Exécutif', postes: postes.capitale || [] },
    { title: 'Assemblée', postes: postes.assemblee || [] },
    { title: 'Villes', postes: [
      ...(postes.ville_a || []),
      ...(postes.ville_b || [])
    ]}
  ].filter(s => s.postes.length > 0);

  document.getElementById('postes-modal-title').textContent = `Organigramme — ${co?.n || 'Empire'}`;
  document.getElementById('postes-body').innerHTML = sections.map(s => `
    <div style="padding:.5rem 1rem;font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.15em;color:#8a6a20;border-bottom:1px solid #2a2010;margin-top:.3rem">${s.title}</div>
    ${s.postes.map(p => {
      // Vérifier si le joueur courant occupe ce poste
      const isMe = state.poste?.id === p.id;
      const holderName = isMe ? myName : p.holder;
      const isPJ = holderName && !holderName.startsWith('PNJ');
      const holderLabel = !holderName
        ? '<span style="color:#4a4030;font-style:italic">Vacant</span>'
        : holderName.startsWith('PNJ')
          ? '<span style="color:#4a4030">PNJ</span>'
          : `<span style="color:${isMe ? '#C9A84C' : '#4a8a4a'}">${holderName}${isMe ? ' ✦' : ''}</span>`;
      return `<div style="display:flex;justify-content:space-between;align-items:center;padding:.4rem 1rem;border-bottom:1px solid #1a1810">
        <div style="font-size:.78rem;color:#c0b090">${p.name}</div>
        <div style="font-size:.75rem">${holderLabel}</div>
      </div>`;
    }).join('')}
  `).join('');

  document.getElementById('modal-postes').classList.add('open');
}

async function postulerPoste(posteId, posteName) {
  document.getElementById('modal-postes').classList.remove('open');

  // Verifier si c'est un poste ministeriel — necessite validation du President
  const postesMinisteriels = ['pm','min_int','min_fin','min_just','min_def','min_info','min_ae'];
  if (postesMinisteriels.includes(posteId)) {
    showToast('Demande transmise', `Votre candidature au poste de ${posteName} a ete transmise au President de la Republique. Vous aurez une reponse sous peu.`, true);
    addJournalEntry(`Demande de poste envoyee : ${posteName}. En attente de reponse presidentielle.`, 'event-info');
    // Stocker la demande en attente
    if (!state.pendingPostRequests) state.pendingPostRequests = [];
    state.pendingPostRequests.push({ posteId, posteName, date: `Jour ${state.day}` });
    return;
  }

  // Verifier si le joueur n'a pas deja ce poste
  if (state.poste?.id === posteId) {
    showToast('Poste deja occupe', `Vous occupez deja le poste de ${posteName}.`, false);
    return;
  }

  // VERIFICATION REELLE via Supabase — pas seulement l'etat local POTENTIELLEMENT PERIME
  showToast('Vérification...', 'Consultation du registre national...', true);
  const titulaireReel = (typeof getTitulairePoste === 'function') ? await getTitulairePoste(posteId) : null;

  if (titulaireReel) {
    showToast('Poste occupe', `Ce poste est deja occupe par ${titulaireReel}.`, false);
    return;
  }

  const postes = POSTES[state.country];
  const allPostes = [
    ...(postes?.capitale || []),
    ...(postes?.assemblee || []),
    ...(postes?.[state.currentCity] || [])
  ];
  const poste = allPostes.find(p => p.id === posteId);
  const isPnjHolder = poste?.holder?.startsWith('PNJ');

  const successRate = 90; // vacance confirmee par Supabase, taux eleve par defaut
  const successRateEffectif = isPnjHolder ? 65 : successRate;

  const roll = Math.floor(Math.random() * 100) + 1;
  if (roll <= successRateEffectif) {
    // Marquer le poste comme pris dans POSTES (etat local, pour affichage immediat)
    if (poste) poste.holder = state.char?.name || 'Joueur';
    // Libérer l'ancien poste si applicable
    if (state.poste?.id && state.poste.id !== posteId) {
      const oldPoste = [...(POSTES[state.country]?.capitale||[]), ...(POSTES[state.country]?.assemblee||[])].find(p => p.id === state.poste.id);
      if (oldPoste && oldPoste.holder === (state.char?.name || 'Joueur')) oldPoste.holder = null;
    }
    state.poste = { id: posteId, name: posteName };
    if (state.char) state.char.poste = state.poste;
    state.salaireTouche = false;
    state.inf = Math.min(100, state.inf + 15);
    updateUI();
    // Persister IMMEDIATEMENT sur Supabase pour que ce soit visible par les autres joueurs sans delai
    if (typeof sbSavePersonnage === 'function') {
      await sbSavePersonnage(state).catch(() => {});
    }
    showToast('Poste obtenu !', `Vous occupez desormais le poste de ${posteName}. +15 Influence.`, true, true);
    addJournalEntry(`Poste obtenu : ${posteName}. +15 Influence.`, 'event-good');
    // Mettre a jour l'affichage du personnage
    if (document.getElementById('char-arch-left')) {
      const ar = ARCHETYPES.find(x => x.id === state.char?.archetype);
      const co = COUNTRIES[state.country];
      document.getElementById('char-arch-left').textContent = `${posteName} · ${co?.n||''}`;
    }
  } else {
    showToast('Candidature refusee', `Votre demande pour le poste de ${posteName} a ete rejetee.`, false);
    addJournalEntry(`Candidature refusee : ${posteName}.`, 'event-bad');
  }
}

// =====================

// ORDRES PRESIDENTIELS
// =====================
// =====================
// FONCTIONS PRESIDENTIELLES V13
// =====================

// =====================
// FORUM NATIONAL SOUS-FORUM PRESIDENT
// =====================
function ouvrirForumNationalSousForumPresident(type) {
  // Ouvre le forum en vue centrale sur le sous-forum presidentiel
  document.querySelectorAll('.vue').forEach(v => v.classList.remove('active'));
  document.getElementById('vue-forum').classList.add('active');

  const titres = {
    conference: 'Conférence de Presse',
    annonce:    'Annonce Officielle',
    propagande: "Propagande d'État",
    dementi:    'Démenti Officiel',
    referendum: 'Référendum National',
    deuil:      'Décret de Deuil National'
  };
  const effets = {
    conference: { pop:15, inf:10, isn:0, ie:0, id:0, is:5 },
    annonce:    { pop:5,  inf:5,  isn:0, ie:0, id:0, is:2 },
    propagande: { pop:20, inf:0,  isn:0, ie:0, id:-5,is:8 },
    dementi:    { pop:8,  inf:5,  isn:0, ie:0, id:0, is:0 },
    referendum: { pop:10, inf:8,  isn:0, ie:0, id:3, is:5 },
    deuil:      { pop:15, inf:0,  isn:0, ie:-5,id:0, is:8 }
  };

  document.getElementById('forum-view-subtitle').textContent = 'Forum National — Forum Présidentiel';
  const body = document.getElementById('forum-view-body');
  const ef = effets[type] || {};
  const titre = titres[type] || 'Message Présidentiel';

  let efStr = [];
  if (ef.pop) efStr.push((ef.pop > 0 ? '+' : '') + ef.pop + ' POP');
  if (ef.inf) efStr.push((ef.inf > 0 ? '+' : '') + ef.inf + ' INF');
  if (ef.is)  efStr.push((ef.is  > 0 ? '+' : '') + ef.is  + ' IS');
  if (ef.id)  efStr.push((ef.id  > 0 ? '+' : '') + ef.id  + ' ID');
  if (type === 'deuil') efStr.push('Pas d\'impôts aujourd\'hui');

  let isRef = type === 'referendum';
  let html = '<div style="display:flex;flex-direction:column;width:100%;height:100%">';
  html += '<div style="padding:.6rem 1rem;background:#111208;border-bottom:1px solid #1a1810;display:flex;align-items:center;gap:.8rem">';
  html += '<button onclick="closeForumView()" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;padding:.2rem .5rem;border:1px solid #2a2010;background:transparent;color:#8a7040;cursor:pointer">← Annuler</button>';
  html += '<div style="font-family:Playfair Display,serif;font-size:.88rem;color:#E8D880">' + titre + '</div>';
  html += '<div style="margin-left:auto;font-size:.68rem;color:#4a8a4a">' + efStr.join(' · ') + '</div>';
  html += '</div>';
  html += '<div style="flex:1;overflow-y:auto;padding:1rem;max-width:700px">';

  if (isRef) {
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">QUESTION DU REFERENDUM</div>';
    html += '<input id="pres-ref-question" type="text" placeholder="Quelle est la question soumise au vote ?" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.6rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.6rem"/>';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">RÉPONSES (1 seul choix)</div>';
    html += '<input id="pres-ref-rep1" type="text" placeholder="Réponse 1 (ex: Oui)" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none;margin-bottom:.3rem"/>';
    html += '<input id="pres-ref-rep2" type="text" placeholder="Réponse 2 (ex: Non)" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none;margin-bottom:.3rem"/>';
    html += '<input id="pres-ref-rep3" type="text" placeholder="Réponse 3 (optionnel)" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none;margin-bottom:.5rem"/>';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.3rem">DURÉE DU VOTE</div>';
    html += '<select id="pres-ref-duree" style="background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none;margin-bottom:.8rem">';
    html += '<option value="3">3 jours</option><option value="5">5 jours</option><option value="7">7 jours</option></select>';
  } else {
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">TITRE</div>';
    html += '<input id="pres-msg-titre" type="text" placeholder="Titre de votre message officiel..." style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.6rem"/>';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">MESSAGE</div>';
    html += '<textarea id="pres-msg-contenu" rows="6" placeholder="Rédigez votre message officiel..." style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.6rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;resize:none;margin-bottom:.6rem"></textarea>';
  }

  html += '<button onclick="publierMessagePresidentiel(\'' + type + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.5rem 1.4rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Publier</button>';
  html += '</div></div>';
  body.innerHTML = html;
}

function publierMessagePresidentiel(type) {
  const effets = {
    conference: { pop:15, inf:10, is:5 },
    annonce:    { pop:5,  inf:5,  is:2 },
    propagande: { pop:20, inf:0,  is:8, id:-5 },
    dementi:    { pop:8,  inf:5  },
    referendum: { pop:10, inf:8,  is:5, id:3 },
    deuil:      { pop:15, is:8,   ie:-5 }
  };
  const ef = effets[type] || {};
  const pays = state.country || 'republic';

  let titre, contenu;
  if (type === 'referendum') {
    titre = document.getElementById('pres-ref-question')?.value?.trim();
    const rep1 = document.getElementById('pres-ref-rep1')?.value?.trim();
    const rep2 = document.getElementById('pres-ref-rep2')?.value?.trim();
    const rep3 = document.getElementById('pres-ref-rep3')?.value?.trim();
    const duree = parseInt(document.getElementById('pres-ref-duree')?.value || '5');
    if (!titre || !rep1 || !rep2) { showToast('Champs requis', 'Question et au moins 2 réponses.', false); return; }
    const reponses = [rep1, rep2, ...(rep3 ? [rep3] : [])].map(r => ({ label: r, voix: 0 }));
    if (!state.referendums) state.referendums = [];
    state.referendums.push({ question: titre, reponses, jourFin: state.day + duree, clos: false });
    contenu = 'Le Président soumet ce référendum au vote populaire. Vote ouvert pendant ' + duree + ' jour(s).';
    if (!FORUM_TOPICS['president']) FORUM_TOPICS['president'] = [];
    FORUM_TOPICS['president'].unshift({
      id: 'ref-' + Date.now(), title: '[REFERENDUM] ' + titre,
      author: state.char?.name || 'President', time: 'Jour ' + state.day,
      isReferendum: true, reponses,
      posts: [{ author: state.char?.name, time: 'Jour ' + state.day, content: contenu }]
    });
  } else {
    titre = document.getElementById('pres-msg-titre')?.value?.trim();
    contenu = document.getElementById('pres-msg-contenu')?.value?.trim();
    if (!titre || !contenu) { showToast('Champs requis', 'Titre et contenu obligatoires.', false); return; }
    if (!FORUM_TOPICS['president']) FORUM_TOPICS['president'] = [];
    FORUM_TOPICS['president'].unshift({
      id: 'pres-' + Date.now(), title: '[PRESIDENCE] ' + titre,
      author: state.char?.name || 'President', time: 'Jour ' + state.day,
      posts: [{ author: state.char?.name, time: 'Jour ' + state.day, content: contenu }]
    });
  }

  // Appliquer les effets
  if (ef.pop) state.pop = Math.min(100, state.pop + ef.pop);
  if (ef.inf) state.inf = Math.min(100, state.inf + ef.inf);
  if (ef.is && INDICES_NATIONAUX?.[pays]) INDICES_NATIONAUX[pays].IS = Math.min(100, INDICES_NATIONAUX[pays].IS + ef.is);
  if (ef.id && INDICES_NATIONAUX?.[pays]) INDICES_NATIONAUX[pays].ID = Math.max(0, INDICES_NATIONAUX[pays].ID + ef.id);
  if (ef.ie && INDICES_NATIONAUX?.[pays]) INDICES_NATIONAUX[pays].IE = Math.max(0, INDICES_NATIONAUX[pays].IE + ef.ie);
  if (type === 'deuil') state.deuil = state.day;

  updateUI();
  closeForumView();

  const efParts = [];
  if (ef.pop) efParts.push((ef.pop>0?'+':'')+ef.pop+' POP');
  if (ef.inf) efParts.push((ef.inf>0?'+':'')+ef.inf+' INF');
  showToast('Publié !', titre + (efParts.length ? ' · ' + efParts.join(' ') : ''), true, true);
  addJournalEntry('Publication présidentielle : ' + titre, 'event-good');
  addExternalEvent('PRESIDENCE : ' + titre + (type === 'deuil' ? ' — Journée de deuil national.' : ''));
}

// =====================
// DECLARER LA GUERRE
// =====================
function ouvrirModalGuerreEmpire() {
  const empires = Object.entries(COUNTRIES).filter(([k]) => k !== (state.country || 'republic'));
  const guerresActives = state.guerres || [];

  document.getElementById('postes-modal-title').textContent = 'Déclarer la guerre';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#cc4444;font-style:italic;margin-bottom:.8rem">-20 POP +10 INF · Nation : -20 ID +15 ISN. Irréversible sans cessez-le-feu.</div>';

  empires.forEach(([k, co]) => {
    const enGuerre = guerresActives.some(g => g.empire === k);
    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.7rem;margin-bottom:.5rem;display:flex;align-items:center;justify-content:space-between">';
    html += '<div style="display:flex;align-items:center;gap:.6rem">';
    html += '<i class="ti ' + (co.icon||'ti-flag') + '" style="font-size:1.1rem;color:' + (co.col||'#8a6a20') + '"></i>';
    html += '<div><div style="font-family:Playfair Display,serif;font-size:.85rem;color:#c0b090">' + co.n + '</div>';
    html += '<div style="font-size:.68rem;color:' + (enGuerre ? '#cc4444' : '#5a4030') + '">' + (enGuerre ? 'En guerre' : 'En paix') + '</div></div></div>';
    if (!enGuerre) {
      html += '<button onclick="confirmerGuerreEmpire(\'' + k + '\',\'' + co.n + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;padding:.3rem .7rem;border:1px solid #8a2020;background:transparent;color:#cc4444;cursor:pointer"><i class="ti ti-sword" style="font-size:.75rem"></i> Déclarer</button>';
    } else {
      html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.65rem;color:#6a2020">CONFLIT EN COURS</div>';
    }
    html += '</div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerGuerreEmpire(empireId, empireName) {
  document.getElementById('modal-postes').classList.remove('open');
  const pays = state.country || 'republic';
  if (!state.guerres) state.guerres = [];
  state.guerres.push({ empire: empireId, nom: empireName, depuis: 'Jour ' + state.day });
  state.pop = Math.max(0, state.pop - 20);
  state.inf = Math.min(100, state.inf + 10);
  if (INDICES_NATIONAUX?.[pays]) {
    INDICES_NATIONAUX[pays].ID = Math.max(0, INDICES_NATIONAUX[pays].ID - 20);
    INDICES_NATIONAUX[pays].ISN = Math.min(100, INDICES_NATIONAUX[pays].ISN + 15);
  }
  updateUI();
  showToast('Guerre déclarée !', 'Conflit ouvert avec ' + empireName + '. -20 POP +10 INF -20 ID +15 ISN.', false);
  addExternalEvent('GUERRE DÉCLARÉE : ' + (COUNTRIES[pays]?.n||'') + ' entre en guerre contre ' + empireName + ' !');
  addMailNotification('État-Major', 'Declaration de guerre', 'La guerre a ete declaree contre ' + empireName + '. L\'armee est en alerte maximale. +15 ISN.');
}

// =====================
// DEPOSER UN PROJET DE LOI
// =====================
function ouvrirDeposerProjet() {
  // Verifier que le PJ est depute
  const posteId = state.poste?.id;
  const estDepute = posteId && (posteId.startsWith('depute') || posteId === 'depute_1' || posteId === 'depute_2');

  if (!estDepute) {
    showToast('Accès refusé', 'Vous n\'êtes pas député(e). Seuls les députés peuvent déposer un projet de loi.', false);
    return;
  }

  // Ouvrir le forum parlementaire en vue centrale
  document.querySelectorAll('.vue').forEach(v => v.classList.remove('active'));
  document.getElementById('vue-forum').classList.add('active');
  document.getElementById('forum-view-subtitle').textContent = 'Forum Parlementaire — Déposer un projet';

  const body = document.getElementById('forum-view-body');
  let html = '<div style="display:flex;flex-direction:column;width:100%;height:100%">';
  html += '<div style="padding:.6rem 1rem;background:#111208;border-bottom:1px solid #1a1810;display:flex;align-items:center;gap:.8rem">';
  html += '<button onclick="closeForumView()" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;padding:.2rem .5rem;border:1px solid #2a2010;background:transparent;color:#8a7040;cursor:pointer">← Annuler</button>';
  html += '<div style="font-family:Playfair Display,serif;font-size:.88rem;color:#E8D880">Déposer un projet de loi</div>';
  html += '</div>';
  html += '<div style="flex:1;overflow-y:auto;padding:1rem;max-width:700px">';
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.8rem;padding:.5rem;background:#0a0a05;border:1px solid #1a1810">Le projet sera soumis au vote le mercredi suivant, à condition d\'avoir été déposé au moins 5 jours avant.</div>';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">TITRE DU PROJET</div>';
  html += '<input id="projet-titre" type="text" placeholder="Ex: Loi sur la transparence des finances publiques" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.6rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.6rem"/>';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">EXPOSÉ DES MOTIFS</div>';
  html += '<textarea id="projet-contenu" rows="6" placeholder="Décrivez votre projet, ses objectifs et ses impacts attendus..." style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.6rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;resize:none;margin-bottom:.6rem"></textarea>';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">IMPACT SOUHAITÉ</div>';
  html += '<input id="projet-impact" type="text" placeholder="Ex: +10 IE, -5 IS, augmentation budget commissariat..." style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none;margin-bottom:.8rem"/>';
  html += '<button onclick="soumettreProjetLoi()" style="font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.5rem 1.4rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Soumettre le projet</button>';
  html += '</div></div>';
  body.innerHTML = html;
}

function soumettreProjetLoi() {
  const titre = document.getElementById('projet-titre')?.value?.trim();
  const contenu = document.getElementById('projet-contenu')?.value?.trim();
  const impact = document.getElementById('projet-impact')?.value?.trim();
  if (!titre || !contenu) { showToast('Champs requis', 'Titre et exposé obligatoires.', false); return; }

  const jourDepot = state.day;
  const jourVoteMin = jourDepot + 5;

  if (!FORUM_TOPICS['parlement']) FORUM_TOPICS['parlement'] = [];
  const topic = {
    id: 'loi-' + Date.now(),
    title: '[PROJET] ' + titre,
    author: state.char?.name || 'Député',
    time: 'Jour ' + jourDepot,
    posts: [{
      author: state.char?.name,
      time: 'Jour ' + jourDepot,
      content: contenu + (impact ? '\n\nImpact attendu : ' + impact : '')
    }]
  };
  FORUM_TOPICS['parlement'].unshift(topic);

  if (!state.loisEnCours) state.loisEnCours = [];
  state.loisEnCours.push({
    id: topic.id, titre, auteur: state.char?.name,
    jourDepot, jourVoteMin, pret: false, votes: []
  });

  closeForumView();
  showToast('Projet soumis !', titre + ' · Vote possible à partir du Jour ' + jourVoteMin, true, true);
  addJournalEntry('Projet de loi soumis : ' + titre, 'event-good');
  addExternalEvent('FORUM PARLEMENTAIRE : Nouveau projet de loi déposé par ' + (state.char?.name||'Anonyme') + ' : "' + titre + '"');
  // Mail a tous les deputes (simulation)
  addMailNotification('Secrétariat de l\'Assemblée', 'Nouveau projet de loi', 'Un projet de loi a été déposé : "' + titre + '". Consultez le Forum Parlementaire pour le détail. Vote à partir du Jour ' + jourVoteMin + '.');
}

// =====================

// ASSEMBLEE NATIONALE
// =====================
function observerDebats() {
  const deputes = ['Depute Marchand (PNJ)', 'Depute Fontaine (PNJ)', 'Depute Rousseau (PNJ)', 'Depute Girard (PNJ)'];
  const positions = ['Pour', 'Contre', 'Abstention'];
  const loisEnCours = state.loisEnCours || [];

  document.getElementById('postes-modal-title').textContent = 'Observer les debats';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Vous observez discretement les echanges dans la salle.</div>';

  if (loisEnCours.length > 0) {
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">VOTES EN COURS</div>';
    loisEnCours.forEach(loi => {
      html += '<div style="padding:.5rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem">';
      html += '<div style="font-size:.82rem;color:#c0b090;margin-bottom:.3rem">' + loi.titre + '</div>';
      deputes.forEach(d => {
        const pos = positions[Math.floor(Math.random() * positions.length)];
        const col = pos === 'Pour' ? '#4a8a4a' : pos === 'Contre' ? '#8a3a2a' : '#6a6040';
        html += '<div style="font-size:.72rem;color:#6a6040">' + d + ' : <span style="color:' + col + '">' + pos + '</span></div>';
      });
      html += '</div>';
    });
  } else {
    html += '<div style="font-size:.82rem;color:#5a5030;font-style:italic">Aucune loi en cours de deliberation. La prochaine session est mercredi.</div>';
  }

  // Bonus journaliste
  if (state.char?.career === 'press') {
    state.inf = Math.min(100, state.inf + 1);
    updateUI();
    html += '<div style="font-size:.72rem;color:#C9A84C;margin-top:.5rem">+1 INF (bonus journaliste)</div>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function ouvrirVoteLoi() {
  const now = new Date();
  const isWednesday = now.getDay() === 3; // 0=dim, 3=mer
  const isBeforeDeadline = now.getHours() < 20;
  const loisEnCours = (state.loisEnCours || []).filter(l => l.pret);

  document.getElementById('postes-modal-title').textContent = 'Voter une loi';
  let html = '<div style="padding:1rem">';

  if (!isWednesday || !isBeforeDeadline) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Le vote se tient uniquement le mercredi jusqu\'a 20h. Prochaine session : mercredi prochain.</div>';
  } else if (loisEnCours.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucune loi en attente de vote pour cette session.</div>';
  } else {
    loisEnCours.forEach((loi, i) => {
      const dejaVote = state.votesLois?.[loi.id];
      html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.8rem;margin-bottom:.6rem">';
      html += '<div style="font-family:Playfair Display,serif;font-size:.85rem;color:#E8C97A;margin-bottom:.3rem">' + loi.titre + '</div>';
      html += '<div style="font-size:.72rem;color:#6a5a30;margin-bottom:.5rem">Depose par ' + loi.auteur + ' le Jour ' + loi.jourDepot + '</div>';
      if (dejaVote) {
        html += '<div style="font-size:.78rem;color:#4a6a4a">Vote exprime : <strong>' + dejaVote + '</strong></div>';
      } else {
        html += '<div style="display:flex;gap:.5rem">';
        ['Pour', 'Contre', 'Abstention'].forEach(choix => {
          const col = choix === 'Pour' ? '#4a8a4a' : choix === 'Contre' ? '#8a2020' : '#6a6040';
          html += '<button onclick="enregistrerVoteLoi(' + i + ',\'' + choix + '\')" style="flex:1;padding:.4rem;border:1px solid ' + col + ';background:transparent;color:' + col + ';cursor:pointer;font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em">' + choix + '</button>';
        });
        html += '</div>';
      }
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function enregistrerVoteLoi(loiIdx, choix) {
  const loi = (state.loisEnCours || []).filter(l => l.pret)[loiIdx];
  if (!loi) return;
  if (!state.votesLois) state.votesLois = {};
  state.votesLois[loi.id] = choix;
  if (!loi.votes) loi.votes = [];
  loi.votes.push({ depute: state.char?.name || 'Anonyme', choix });
  document.getElementById('modal-postes').classList.remove('open');
  showToast('Vote enregistre', choix + ' pour : ' + loi.titre, true, true);
  addJournalEntry('Vote : ' + choix + ' — ' + loi.titre, 'event-info');
}

function ouvrirArchivesLois() {
  const archives = state.archivesLois || [];
  document.getElementById('postes-modal-title').textContent = 'Archives de l\'Assemblee';
  let html = '<div style="padding:1rem">';
  if (archives.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucune loi votee pour le moment.</div>';
  } else {
    archives.forEach((loi, i) => {
      html += '<div onclick="ouvrirDetailLoi(' + i + ')" style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;cursor:pointer;transition:background .15s" onmouseover="this.style.background=\'#151005\'" onmouseout="this.style.background=\'#0f0d05\'">';
      html += '<div style="display:flex;justify-content:space-between;align-items:center">';
      html += '<div style="font-family:Playfair Display,serif;font-size:.82rem;color:#c0b090">' + loi.titre + '</div>';
      const col = loi.resultat === 'Adoptee' ? '#4a8a4a' : '#8a2020';
      html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;color:' + col + '">' + (loi.resultat||'En cours') + '</div>';
      html += '</div>';
      html += '<div style="font-size:.68rem;color:#5a4030">Jour ' + loi.jourVote + ' · ' + (loi.votes?.length||0) + ' votants</div>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function ouvrirDetailLoi(idx) {
  const loi = (state.archivesLois||[])[idx];
  if (!loi) return;
  document.getElementById('postes-modal-title').textContent = loi.titre;
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;margin-bottom:.6rem">Depose par ' + loi.auteur + ' · Vote Jour ' + loi.jourVote + '</div>';
  const col = loi.resultat === 'Adoptee' ? '#4a8a4a' : '#8a2020';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:1rem;color:' + col + ';margin-bottom:.8rem">' + (loi.resultat||'En cours') + '</div>';
  if (loi.votes?.length > 0) {
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">VOTES NOMINATIFS</div>';
    loi.votes.forEach(v => {
      const vc = v.choix === 'Pour' ? '#4a8a4a' : v.choix === 'Contre' ? '#8a2020' : '#5a5040';
      html += '<div style="display:flex;justify-content:space-between;font-size:.78rem;padding:.2rem 0;border-bottom:1px solid #1a1810">';
      html += '<span style="color:#c0b090">' + v.depute + '</span><span style="color:' + vc + '">' + v.choix + '</span></div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

// =====================
// CALENDRIER ELECTORAL

// DEMANDE DE NATURALISATION (changement d'empire)
// =====================
function ouvrirModalNaturalisation() {
  const empires = Object.keys(COUNTRIES).filter(c => c !== state.country);
  document.getElementById('postes-modal-title').textContent = 'Demande de naturalisation';

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Votre demande sera examinee par le Ministre de l\'Interieur de l\'empire vise, apres un delai de 48h. En cas de refus, 50% du montant sera remboursé.</div>';

  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">EMPIRE VISE</div>';
  html += '<select id="natu-empire-vise" onchange="majCoutNaturalisation()" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.6rem">';
  empires.forEach(c => { html += '<option value="' + c + '">' + (COUNTRIES[c]?.n || c) + '</option>'; });
  html += '</select>';

  html += '<div id="natu-cout-affiche" style="font-size:.85rem;color:#C9A84C;margin-bottom:.8rem"></div>';
  html += '<button onclick="confirmerDemandeNaturalisation()" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Déposer la demande</button>';
  html += '</div>';

  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
  majCoutNaturalisation();
}

function getCoutNaturalisation(paysVise) {
  const ie = INDICES_NATIONAUX[paysVise]?.IE || 40;
  return 2000 + ie * 30;
}

function majCoutNaturalisation() {
  const paysVise = document.getElementById('natu-empire-vise')?.value;
  if (!paysVise) return;
  const cout = getCoutNaturalisation(paysVise);
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  document.getElementById('natu-cout-affiche').textContent = 'Coût de la demande : ' + cout + ' ' + cur;
}

async function confirmerDemandeNaturalisation() {
  const paysVise = document.getElementById('natu-empire-vise')?.value;
  if (!paysVise) return;
  const cout = getCoutNaturalisation(paysVise);

  if (state.arg < cout) {
    showToast('Fonds insuffisants', cout + ' ' + (COUNTRIES[state.country]?.cur||'FR') + ' requis.', false);
    return;
  }

  state.arg -= cout;
  updateUI();
  document.getElementById('modal-postes').classList.remove('open');

  const maintenant = Date.now();
  const demande = {
    id: 'natu-' + maintenant,
    demandeur: state.char?.name || 'Anonyme',
    pays_origine: state.country,
    pays_vise: paysVise,
    montant: cout,
    date_demande: maintenant,
    date_traitement_possible: maintenant + 48 * 60 * 60 * 1000,
    statut: 'pending'
  };

  if (typeof sbCreerDemandeNaturalisation === 'function') {
    await sbCreerDemandeNaturalisation(demande).catch(() => {});
  }

  showToast('Demande déposée', 'Votre demande de naturalisation vers ' + (COUNTRIES[paysVise]?.n||paysVise) + ' a été transmise.', true, true);
  addJournalEntry('Demande de naturalisation déposée vers ' + (COUNTRIES[paysVise]?.n||paysVise) + ' (' + cout + ' ' + (COUNTRIES[state.country]?.cur||'FR') + ').', 'event-info');

  // Notifier le Ministre de l'Interieur du pays vise
  const ministre = (typeof sbListPersonnages === 'function')
    ? await sbListPersonnages().then(joueurs => (joueurs||[]).find(j => j.country === paysVise && j.poste?.id === 'min_int')).catch(() => null)
    : null;
  if (ministre && typeof sbSendMail === 'function') {
    const h = String(state.hour || 8).padStart(2,'0');
    const time = 'Jour ' + (state.day || 1) + ' · ' + h + 'h';
    sbSendMail('Service de l\'Immigration', ministre.name, 'Demande de naturalisation',
      (state.char?.name||'Un citoyen') + ' demande la naturalisation dans votre empire. Vous pouvez traiter sa demande depuis votre bureau, 48h apres le depot.', time).catch(() => {});
  }
}

// =====================
// TRAITEMENT DES DEMANDES PAR LE MINISTRE DE L'INTERIEUR
// =====================
async function ouvrirDemandesNaturalisation() {
  document.getElementById('postes-modal-title').textContent = 'Demandes de naturalisation';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a8060;font-style:italic">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  let demandes = [];
  if (typeof sbGetDemandesNaturalisationPour === 'function') {
    try { demandes = await sbGetDemandesNaturalisationPour(state.country) || []; } catch(e) {}
  }

  const maintenant = Date.now();
  let html = '<div style="padding:1rem">';
  if (demandes.length === 0) {
    html += '<div style="font-size:.85rem;color:#5a5040;font-style:italic">Aucune demande en attente.</div>';
  } else {
    demandes.forEach(d => {
      const traitablePossible = maintenant >= d.date_traitement_possible;
      const tempsRestant = Math.max(0, Math.ceil((d.date_traitement_possible - maintenant) / (60*60*1000)));
      html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.5rem">';
      html += '<div style="font-family:Playfair Display,serif;font-size:.85rem;color:#E8C97A">' + d.demandeur + '</div>';
      html += '<div style="font-size:.7rem;color:#8a8060;margin:.2rem 0">Origine : ' + (COUNTRIES[d.pays_origine]?.n||d.pays_origine) + ' · Montant versé : ' + d.montant + '</div>';
      if (!traitablePossible) {
        html += '<div style="font-size:.7rem;color:#6a5a30">Traitable dans ' + tempsRestant + 'h</div>';
      } else {
        html += '<div style="display:flex;gap:.4rem;margin-top:.4rem">';
        html += '<button onclick="traiterDemandeNaturalisation(&quot;' + d.id + '&quot;,true)" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.7rem;padding:.3rem;border:1px solid #2a4a20;background:transparent;color:#6a9a6a;cursor:pointer">Accepter</button>';
        html += '<button onclick="traiterDemandeNaturalisation(&quot;' + d.id + '&quot;,false)" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.7rem;padding:.3rem;border:1px solid #4a2010;background:transparent;color:#cc4444;cursor:pointer">Refuser</button>';
        html += '</div>';
      }
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function traiterDemandeNaturalisation(demandeId, accepter) {
  if (typeof sbGetDemandesNaturalisationPour !== 'function') return;
  const demandes = await sbGetDemandesNaturalisationPour(state.country).catch(() => []);
  const demande = (demandes || []).find(d => d.id === demandeId);
  if (!demande) { showToast('Introuvable', 'Cette demande n\'existe plus.', false); return; }

  const nouveauStatut = accepter ? 'acceptee' : 'refusee';
  if (typeof sbTraiterDemandeNaturalisation === 'function') {
    await sbTraiterDemandeNaturalisation(demandeId, nouveauStatut).catch(() => {});
  }

  const h = String(state.hour || 8).padStart(2,'0');
  const time = 'Jour ' + (state.day || 1) + ' · ' + h + 'h';

  if (accepter) {
    if (typeof sbSendMail === 'function') {
      sbSendMail('Service de l\'Immigration', demande.demandeur, 'Naturalisation acceptée',
        'Votre demande de naturalisation a été acceptée par le Ministre de l\'Intérieur. Vous êtes désormais citoyen de ' + (COUNTRIES[state.country]?.n||state.country) + '. Votre changement sera effectif à votre prochaine connexion.', time).catch(() => {});
    }
    showToast('Demande acceptée', demande.demandeur + ' devient citoyen de ' + (COUNTRIES[state.country]?.n||state.country) + '.', true, true);
    addExternalEvent('🛂 ' + demande.demandeur + ' obtient la nationalité ' + (COUNTRIES[state.country]?.n||state.country) + '.', 'national');
  } else {
    const remboursement = Math.floor(demande.montant * 0.5);
    if (typeof sbDeposerDon === 'function') {
      await sbDeposerDon(demande.demandeur, remboursement, 'Service de l\'Immigration').catch(() => {});
    }
    if (typeof sbSendMail === 'function') {
      sbSendMail('Service de l\'Immigration', demande.demandeur, 'Naturalisation refusée',
        'Votre demande de naturalisation a été refusée par le Ministre de l\'Intérieur. ' + remboursement + ' ' + (COUNTRIES[state.country]?.cur||'FR') + ' vous sont remboursés.', time).catch(() => {});
    }
    showToast('Demande refusée', demande.demandeur + ' a été notifié(e), remboursement partiel envoyé.', false, true);
  }

  ouvrirDemandesNaturalisation();
}

// Applique le changement de nationalite reellement au prochain chargement du joueur concerne
async function appliquerNaturalisationAcceptee() {
  if (typeof sbGetDemandesNaturalisationPour !== 'function' || !state.char?.name) return;
  // Chercher dans tous les empires si une demande du joueur courant a ete acceptee
  for (const c of Object.keys(COUNTRIES)) {
    try {
      const rows = await sbGet('demandes_naturalisation', `demandeur=eq.${encodeURIComponent(state.char.name)}&statut=eq.acceptee&pays_vise=eq.${c}`);
      if (rows && rows.length > 0) {
        state.country = c;
        state.poste = null;
        if (state.char) { state.char.poste = null; state.char.country = c; }
        await sbTraiterDemandeNaturalisation(rows[0].id, 'appliquee').catch(() => {});
        showToast('Naturalisation effective', 'Vous êtes désormais citoyen de ' + (COUNTRIES[c]?.n||c) + ' !', true, true);
        addJournalEntry('Votre naturalisation est effective. Vous êtes citoyen de ' + (COUNTRIES[c]?.n||c) + '.', 'event-good');
        updateUI();
        break;
      }
    } catch(e) {}
  }
}



// ANNUAIRE DES DEPUTES
// =====================
function consulterAnnuaireDeputes() {
  const country = state.country;
  const co = COUNTRIES[country];
  const titulairesConnus = state.postes?.[country] || {};

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">25 sieges a l\'Assemblee Nationale de ' + (co?.n||country) + '.</div>';
  for (let i = 1; i <= 25; i++) {
    const titulaire = titulairesConnus['depute_' + i] || 'Vacant (PNJ)';
    html += '<div style="display:flex;justify-content:space-between;padding:.4rem .2rem;border-bottom:1px solid #1a1810">';
    html += '<span style="font-size:.78rem;color:#6a5a30">Siege ' + i + '</span>';
    html += '<span style="font-size:.8rem;color:#c0b090">' + titulaire + '</span>';
    html += '</div>';
  }
  html += '</div>';
  document.getElementById('postes-modal-title').textContent = 'Annuaire des Députés';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// =====================

// SYSTÈME GÉNÉRIQUE — NOMINATION DE POSTES (juge, commissaire)
// =====================

// Vérifie si un PJ peut accepter ce poste (règles de cumul strict)
function peutAccepterPosteNomme(posteId) {
  const regle = POSTES_NOMMES_EXCLUSIFS[posteId];
  if (!regle) return { ok: true };
  if (!state.poste) return { ok: true };
  if (regle.compatibles.includes(state.poste.id)) return { ok: true };
  return { ok: false, raison: 'Vous occupez déjà le poste de ' + (state.poste.name || state.poste.id) + ', incompatible avec ' + regle.label + '.' };
}

// Liste des habitants éligibles — ville pour commissaire, pays entier pour juge
async function listerHabitantsEligibles(posteId) {
  if (typeof sbListPersonnages !== 'function') return [];
  const regle = POSTES_NOMMES_EXCLUSIFS[posteId];
  if (!regle) return [];
  try {
    const joueurs = await sbListPersonnages() || [];
    return joueurs.filter(j => {
      if (j.country !== state.country) return false;
      if (regle.scope === 'ville' && j.current_city !== state.currentCity) return false;
      return true;
    });
  } catch(e) { return []; }
}

// Ouvre le modal de sélection pour nommer un juge ou un commissaire
async function ouvrirNominerPosteNomme(posteId) {
  const regle = POSTES_NOMMES_EXCLUSIFS[posteId];
  if (!regle) return;

  document.getElementById('postes-modal-title').textContent = 'Nommer un ' + regle.label.toLowerCase();
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a8060;font-style:italic">Recherche des habitants éligibles...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const habitants = await listerHabitantsEligibles(posteId);
  const villeNom = regle.scope === 'ville' ? (WORLD[state.country]?.[state.currentCity]?.name || state.currentCity) : null;

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">' +
    (regle.scope === 'ville'
      ? 'Habitants domiciliés à ' + villeNom + '.'
      : 'Habitants domiciliés dans ' + (COUNTRIES[state.country]?.n || 'cet empire') + '.') +
    ' Le poste de ' + regle.label + ' est incompatible avec tout autre poste sauf Député.</div>';

  if (habitants.length === 0) {
    html += '<div style="font-size:.85rem;color:#5a5040">Aucun habitant éligible trouvé.</div>';
  } else {
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">CANDIDAT</div>';
    html += '<select id="nomme-poste-contact" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.8rem">';
    habitants.forEach(h => { html += '<option value="' + h.name + '">' + h.name + '</option>'; });
    html += '</select>';
    html += '<button onclick="envoyerNominationPosteNomme(\'' + posteId + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Envoyer la nomination</button>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

// Envoie le mail de nomination avec bouton d'acceptation intégré
async function envoyerNominationPosteNomme(posteId) {
  const regle = POSTES_NOMMES_EXCLUSIFS[posteId];
  const destinataire = document.getElementById('nomme-poste-contact')?.value;
  if (!destinataire || !regle) return;

  document.getElementById('modal-postes').classList.remove('open');

  const nommeurNom = state.char?.name || 'Anonyme';
  const villeNom = regle.scope === 'ville' ? (WORLD[state.country]?.[state.currentCity]?.name || state.currentCity) : null;
  const sujet = 'Nomination au poste de ' + regle.label;

  const corps = nommeurNom + ' vous propose le poste de <strong>' + regle.label + '</strong>' +
    (villeNom ? ' pour la ville de ' + villeNom : ' pour ' + (COUNTRIES[state.country]?.n || "l'empire")) + '.<br><br>' +
    '<em>Ce poste est incompatible avec tout autre poste, sauf Député.</em><br><br>' +
    '<button onclick="accepterNominationPosteNomme(\'' + posteId + '\',\'' + (villeNom ? state.currentCity : '') + '\',\'' + state.country + '\',\'' + nommeurNom.replace(/'/g,'') + '\')" ' +
    'style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer;margin-top:.5rem">✓ Accepter le poste</button>';

  if (typeof sbSendMail === 'function') {
    const h = String(state.hour || 8).padStart(2,'0');
    const time = 'Jour ' + (state.day || 1) + ' · ' + h + 'h';
    await sbSendMail(nommeurNom, destinataire, sujet, corps, time);
    showToast('Nomination envoyée', destinataire + ' a reçu votre proposition.', true);
    addJournalEntry('Nomination de ' + destinataire + ' au poste de ' + regle.label + ' proposée.', 'event-info');
  } else {
    showToast('Erreur', 'Système de mail indisponible.', false);
  }
}

// Appelée quand le destinataire clique "Accepter le poste" dans le mail
function accepterNominationPosteNomme(posteId, city, country, nommeurNom) {
  const regle = POSTES_NOMMES_EXCLUSIFS[posteId];
  if (!regle) return;

  const check = peutAccepterPosteNomme(posteId);
  if (!check.ok) {
    showToast('Impossible', check.raison, false);
    return;
  }

  state.poste = { id: posteId, name: regle.label, city: city || null };
  if (state.char) state.char.poste = state.poste;
  state.salaireTouche = false;
  updateUI();

  showToast('Poste accepté !', 'Vous êtes désormais ' + regle.label + (city ? ' de ' + (WORLD[country]?.[city]?.name || city) : '') + '.', true, true);
  addJournalEntry('Vous avez accepté le poste de ' + regle.label + '.', 'event-good');
  addExternalEvent('🏛 ' + (state.char?.name || 'Anonyme') + ' est nommé(e) ' + regle.label + (city ? ' de ' + (WORLD[country]?.[city]?.name || city) : '') + '.', city ? 'local' : 'national');

  // Notifier le nommeur
  if (typeof sbSendMail === 'function' && nommeurNom) {
    const h = String(state.hour || 8).padStart(2,'0');
    const time = 'Jour ' + (state.day || 1) + ' · ' + h + 'h';
    sbSendMail(state.char?.name || 'Anonyme', nommeurNom, 'Nomination acceptée',
      (state.char?.name || 'Le candidat') + ' a accepté le poste de ' + regle.label + '.', time).catch(() => {});
  }
}


document.querySelectorAll('.modal-overlay').forEach(m => {
  m.addEventListener('click', function(e) {
    if (e.target === this) this.classList.remove('open');
  });
});



// =====================
// CORRIGER POSTULER (postes, grace, nationalisation, ambassadeur, censure, nominations ministerielles)
// =====================

// CORRIGER POSTULER
// =====================
function ouvrirPostulerPoste() {
  const pays = state.country || 'republic';
  const ville = state.currentCity || 'capitale';
  const postes = POSTES[pays]?.[ville] || POSTES[pays]?.capitale || [];

  document.getElementById('postes-modal-title').textContent = 'Postuler a un poste';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Postes disponibles a ' + (WORLD[pays]?.[ville]?.name||ville) + ' :</div>';

  if (postes.length === 0) {
    html += '<div style="font-size:.85rem;color:#5a5040">Aucun poste disponible ici.</div>';
  } else {
    postes.forEach(poste => {
      const estOccupeParPJ = poste.holder && !poste.holder.startsWith('PNJ-');
      const estPresident = poste.id === 'president';
      const estPM = poste.id === 'pm';
      const isPJHolder = estOccupeParPJ;
      const moi = state.char?.name;

      // Ne pas afficher son propre poste
      if (poste.holder === moi) return;

      html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.7rem;margin-bottom:.5rem">';
      html += '<div style="display:flex;justify-content:space-between;align-items:center">';
      html += '<div><div style="font-family:Playfair Display,serif;font-size:.85rem;color:#E8C97A">' + poste.name + '</div>';
      html += '<div style="font-size:.7rem;color:#5a4030">Titulaire actuel : ' + (poste.holder || 'Vacant') + '</div></div>';

      if (estPresident && isPJHolder) {
        html += '<div style="font-size:.68rem;color:#6a3020;font-style:italic">Inaccessible</div>';
      } else if (estPM && isPJHolder) {
        html += '<div style="font-size:.68rem;color:#6a3020;font-style:italic">Inaccessible</div>';
      } else if (!isPJHolder) {
        // Poste PNJ - prise automatique
        html += '<button onclick="prendrePoste(\'' + poste.id + '\',\'' + poste.name + '\',false)" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;padding:.25rem .6rem;border:1px solid #4a8a4a;background:transparent;color:#4a8a4a;cursor:pointer">Prendre le poste</button>';
      } else {
        // Poste minister PJ - envoyer demande au PM
        html += '<button onclick="demanderPosteAuPM(\'' + poste.id + '\',\'' + poste.name + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;padding:.25rem .6rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Postuler</button>';
      }
      html += '</div></div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function prendrePoste(posteId, posteNom, isPJHolder) {
  document.getElementById('modal-postes').classList.remove('open');
  const pays = state.country || 'republic';
  const ville = state.currentCity || 'capitale';
  const postes = POSTES[pays]?.[ville] || POSTES[pays]?.capitale || [];
  const poste = postes.find(p => p.id === posteId);
  if (poste) poste.holder = state.char?.name;
  state.poste = { id: posteId, name: posteNom };
  if (state.char) state.char.poste = state.poste;
  updateUI();
  showToast('Poste pris !', 'Vous etes desormais ' + posteNom + '.', true, true);
  addJournalEntry('Prise de poste : ' + posteNom, 'event-good');
  addExternalEvent((state.char?.name||'Anonyme') + ' prend le poste de ' + posteNom + '.');
}

function demanderPosteAuPM(posteId, posteNom) {
  document.getElementById('modal-postes').classList.remove('open');
  addMailNotification(
    'Demande de poste',
    'Candidature : ' + posteNom,
    (state.char?.name||'Anonyme') + ' souhaite postuler au poste de ' + posteNom + '. Vous pouvez le/la nommer depuis votre bureau.'
  );
  showToast('Demande envoyee', 'Le Premier Ministre a ete informe de votre candidature au poste de ' + posteNom + '.', true);
  addJournalEntry('Candidature envoyee au PM pour : ' + posteNom, 'event-info');
}

function ouvrirEtatNation() {
  const pays = state.country || 'republic';
  const idx = INDICES_NATIONAUX[pays] || { ISN:30, IE:50, ID:40, IS:45 };
  document.querySelectorAll('.vue').forEach(v => v.classList.remove('active'));
  const el = document.getElementById('vue-self');
  if (!el) return;
  el.classList.add('active');
  document.getElementById('self-view-name').textContent = 'Etat de la Nation';
  document.getElementById('self-view-role').textContent = COUNTRIES[pays]?.n || '';
  const content = document.getElementById('self-content');

  const indices = [
    { k:'ISN', label:'Securite Nationale',    val:idx.ISN, col:'#4a8a4a', desc:'Impact sur les actes illegaux et leur detection.' },
    { k:'IE',  label:'Economique',            val:idx.IE,  col:'#C9A84C', desc:'Impact sur les revenus fiscaux et les salaires.' },
    { k:'ID',  label:'Diplomatique',          val:idx.ID,  col:'#4a6aaa', desc:'Impact sur les relations inter-empires et voyages.' },
    { k:'IS',  label:'Social',               val:idx.IS,  col:'#aa6a4a', desc:'Impact sur la popularite des elus et risques de greve.' }
  ];

  let html = '<div style="padding:1.5rem;max-width:650px">';
  html += '<div style="font-family:Playfair Display,serif;font-size:1.1rem;color:#C9A84C;margin-bottom:1.2rem">Indices de la Nation — ' + (COUNTRIES[pays]?.n||'') + '</div>';

  indices.forEach(ind => {
    const pct = ind.val;
    const niveau = pct <= 20 ? 'Critique' : pct <= 40 ? 'Faible' : pct <= 60 ? 'Moyen' : pct <= 80 ? 'Bon' : 'Excellent';
    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.8rem;margin-bottom:.6rem">';
    html += '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:.4rem">';
    html += '<div><span style="font-family:Bebas Neue,sans-serif;font-size:.85rem;color:' + ind.col + ';letter-spacing:.1em">Indice ' + ind.label + ' (' + ind.k + ')</span></div>';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:1.1rem;color:' + ind.col + '">' + pct + '/100 — ' + niveau + '</div>';
    html += '</div>';
    html += '<div style="height:8px;background:#1a1810;border-radius:4px;overflow:hidden;margin-bottom:.4rem">';
    html += '<div style="height:100%;width:' + pct + '%;background:' + ind.col + ';border-radius:4px;transition:width .5s"></div></div>';
    html += '<div style="font-size:.72rem;color:#5a5040">' + ind.desc + '</div>';
    html += '</div>';
  });

  // Malus illegal actuel
  const malus = getMalusIllegal ? getMalusIllegal(pays) : 0;
  const multDet = getMultDetection ? getMultDetection(pays) : 1;
  html += '<div style="padding:.7rem;background:#0a0805;border:1px solid #1a1810;font-size:.78rem;color:#6a5a30">';
  html += 'ISN actuel : malus de <strong style="color:#C9A84C">-' + malus + '%</strong> sur tous les actes illegaux · taux de detection x<strong style="color:#C9A84C">' + multDet + '</strong>';
  html += '</div>';
  html += '</div>';
  content.innerHTML = html;
}

function ouvrirModalEmpireCible(action, titre) {
  const empires = Object.entries(COUNTRIES).filter(([k]) => k !== state.country);
  document.getElementById('postes-modal-title').textContent = titre;
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.82rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Choisir un empire cible :</div>';
  empires.forEach(([k, co]) => {
    html += '<button onclick="executerOrdreEmpire(\'' + action + '\',\'' + k + '\',\'' + co.n + '\')" style="display:flex;align-items:center;gap:.6rem;width:100%;padding:.6rem .8rem;border:1px solid #2a2010;background:#0f0d05;color:#c0b090;cursor:pointer;font-family:Crimson Pro,serif;font-size:.85rem;margin-bottom:.4rem">';
    html += '<i class="ti ' + co.icon + '" style="font-size:1rem;color:' + co.col + '"></i> ' + co.n + '</button>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function executerOrdreEmpire(action, empireId, empireName) {
  document.getElementById('modal-postes').classList.remove('open');
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  if (action === 'declarer_guerre') {
    if (!state.guerres) state.guerres = [];
    state.guerres.push({ empire: empireId, nom: empireName, depuis: 'Jour ' + state.day });
    INDICES_NATIONAUX[state.country].ID = Math.max(0, INDICES_NATIONAUX[state.country].ID - 20);
    addExternalEvent('GUERRE DECLAREE : ' + (COUNTRIES[state.country]?.n||'') + ' declare la guerre a ' + empireName + ' !');
    addMailNotification('Etat-Major', 'Declaration de guerre', 'La guerre a ete declaree contre ' + empireName + '. L\'armee est en alerte maximale.');
    showToast('Guerre declaree !', 'Conflit ouvert avec ' + empireName + '. -20 ID.', false);
  } else if (action === 'cessez_le_feu') {
    if (state.guerres) state.guerres = state.guerres.filter(g => g.empire !== empireId);
    INDICES_NATIONAUX[state.country].ID = Math.min(100, INDICES_NATIONAUX[state.country].ID + 10);
    showToast('Cessez-le-feu', 'Negociation en cours avec ' + empireName + '. +10 ID.', true);
    addJournalEntry('Cessez-le-feu negocie avec ' + empireName, 'event-good');
  } else if (action === 'ouvrir_ambassade') {
    if (!state.ambassades) state.ambassades = [];
    state.ambassades.push({ empire: empireId, nom: empireName });
    INDICES_NATIONAUX[state.country].ID = Math.min(100, INDICES_NATIONAUX[state.country].ID + 8);
    state.arg -= 1000;
    updateUI();
    showToast('Ambassade ouverte', 'Representation diplomatique etablie a ' + empireName + '. +8 ID.', true);
  } else if (action === 'sanctions') {
    INDICES_NATIONAUX[state.country].ID = Math.max(0, INDICES_NATIONAUX[state.country].ID - 5);
    INDICES_NATIONAUX[empireId] = INDICES_NATIONAUX[empireId] || {};
    showToast('Sanctions imposees', 'Sanctions economiques contre ' + empireName + '. -5 ID.', false);
    addExternalEvent('Sanctions officielles imposees contre ' + empireName + '.');
  } else {
    showToast(action.replace(/_/g,' '), 'Action menee envers ' + empireName, true);
    addJournalEntry(action.replace(/_/g,' ') + ' : ' + empireName, 'event-info');
  }
}

function ouvrirModalGracier() {
  const condamnes = state.prisonniers?.filter(p => p.jourFin > state.day) || [];
  document.getElementById('postes-modal-title').textContent = 'Gracier un condamne';
  let html = '<div style="padding:1rem">';
  if (condamnes.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucun condamne actuellement en detention.</div>';
  } else {
    condamnes.forEach((p, i) => {
      html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;display:flex;justify-content:space-between;align-items:center">';
      html += '<div><div style="font-family:Playfair Display,serif;font-size:.85rem;color:#c0b090">' + p.nom + '</div>';
      html += '<div style="font-size:.7rem;color:#5a4030">' + p.raison + ' · liberation prevue Jour ' + p.jourFin + '</div></div>';
      html += '<button onclick="confirmerGrace(' + i + ')" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;padding:.25rem .6rem;border:1px solid #4a8a4a;background:transparent;color:#4a8a4a;cursor:pointer">Gracier</button>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerGrace(idx) {
  const condamnes = state.prisonniers?.filter(p => p.jourFin > state.day) || [];
  const condamne = condamnes[idx];
  if (!condamne) return;
  condamne.jourFin = state.day; // Liberation immediate
  document.getElementById('modal-postes').classList.remove('open');
  const popBonus = state.pop > 50 ? 5 : -2;
  state.pop = Math.min(100, state.pop + popBonus);
  updateUI();
  showToast('Grace accordee', condamne.nom + ' est libere(e). ' + (popBonus > 0 ? '+' : '') + popBonus + ' POP.', true);
  addExternalEvent('GRACE PRESIDENTIELLE : ' + condamne.nom + ' a ete gracie(e) par le President.');
}

function ouvrirForumPresidentCentral(type) {
  // Ouvre le forum presidentiel en vue centrale
  document.querySelectorAll('.vue').forEach(v => v.classList.remove('active'));
  document.getElementById('vue-mail').classList.add('active'); // Reutilise la vue mail
  document.getElementById('mail-view-subtitle').textContent = 'Forum Presidentiel';
  document.getElementById('mail-compose').style.display = 'none';

  const titres = {
    'referendum': 'Creer un Referendum',
    'deuil': 'Decret de Deuil National',
    'forum_president_conference': 'Conference de Presse',
    'forum_president_annonce': 'Annonce Officielle',
    'forum_president_propagande': "Propagande d'Etat",
    'forum_president_dementi': 'Dementi Officiel'
  };

  const titre = titres[type] || 'Forum Presidentiel';
  const content = document.getElementById('mail-content');

  let html = '<div style="padding:1.2rem;max-width:650px">';
  html += '<div style="font-family:Playfair Display,serif;font-size:1rem;color:#C9A84C;margin-bottom:1rem">' + titre + '</div>';

  if (type === 'referendum') {
    html += '<div style="margin-bottom:.8rem"><div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">QUESTION DU REFERENDUM</div>';
    html += '<input id="ref-question" type="text" placeholder="Quelle est la question soumise au vote ?" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.6rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.5rem"/></div>';
    html += '<div style="margin-bottom:.8rem"><div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">REPONSES POSSIBLES (1 seul choix)</div>';
    html += '<input id="ref-rep1" type="text" placeholder="Reponse 1 (ex: Oui)" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none;margin-bottom:.3rem"/>';
    html += '<input id="ref-rep2" type="text" placeholder="Reponse 2 (ex: Non)" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none;margin-bottom:.3rem"/>';
    html += '<input id="ref-rep3" type="text" placeholder="Reponse 3 (optionnel)" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none;margin-bottom:.5rem"/>';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">DUREE DU VOTE</div>';
    html += '<select id="ref-duree" style="background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none">';
    html += '<option value="3">3 jours</option><option value="5">5 jours</option><option value="7">7 jours</option></select></div>';
    html += '<button onclick="publierReferendum()" style="font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Publier le referendum</button>';
  } else {
    html += '<div style="margin-bottom:.8rem"><div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">TITRE</div>';
    html += '<input id="forum-pres-titre" type="text" placeholder="Titre de votre message..." style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.5rem"/></div>';
    html += '<div style="margin-bottom:.8rem"><div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">MESSAGE</div>';
    html += '<textarea id="forum-pres-message" rows="5" placeholder="Redigez votre message officiel..." style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;resize:none"></textarea></div>';
    html += '<button onclick="publierForumPresident(\'' + type + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Publier</button>';
  }

  html += '<button onclick="closeMailView()" style="margin-left:.5rem;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #3a2a10;background:transparent;color:#6a5a30;cursor:pointer">Annuler</button>';
  html += '</div>';
  content.innerHTML = html;
}

function publierReferendum() {
  const question = document.getElementById('ref-question')?.value?.trim();
  const rep1 = document.getElementById('ref-rep1')?.value?.trim();
  const rep2 = document.getElementById('ref-rep2')?.value?.trim();
  const rep3 = document.getElementById('ref-rep3')?.value?.trim();
  const duree = parseInt(document.getElementById('ref-duree')?.value || '5');
  if (!question || !rep1 || !rep2) { showToast('Champs requis', 'Question et au moins 2 reponses obligatoires.', false); return; }

  const reponses = [rep1, rep2, ...(rep3 ? [rep3] : [])].map(r => ({ label: r, voix: 0 }));
  if (!state.referendums) state.referendums = [];
  state.referendums.push({ question, reponses, jourFin: state.day + duree, clos: false, auteur: state.char?.name });

  // Publier dans le forum presidentiel
  if (!FORUM_TOPICS['national']) FORUM_TOPICS['national'] = [];
  FORUM_TOPICS['national'].unshift({
    id: 'ref-' + Date.now(), title: '[REFERENDUM] ' + question,
    author: state.char?.name || 'President',
    time: 'Jour ' + state.day, views: 0, replies: 0,
    isReferendum: true, reponses,
    posts: [{ author: state.char?.name, time: 'Jour ' + state.day, content: 'Le President soumet ce referendum au vote populaire. Vote ouvert pendant ' + duree + ' jours.' }]
  });

  state.pop = Math.min(100, state.pop + 8);
  updateUI();
  closeMailView();
  showToast('Referendum publie !', question + ' — Vote ouvert ' + duree + ' jours. +8 POP.', true, true);
  addExternalEvent('REFERENDUM : Le President soumet au vote : "' + question + '"');
}

function publierForumPresident(type) {
  const titre = document.getElementById('forum-pres-titre')?.value?.trim();
  const message = document.getElementById('forum-pres-message')?.value?.trim();
  if (!titre || !message) { showToast('Champs requis', 'Titre et message obligatoires.', false); return; }

  if (!FORUM_TOPICS['national']) FORUM_TOPICS['national'] = [];
  FORUM_TOPICS['national'].unshift({
    id: 'pres-' + Date.now(), title: '[PRESIDENCE] ' + titre,
    author: state.char?.name || 'President',
    time: 'Jour ' + state.day, views: 0, replies: 0,
    posts: [{ author: state.char?.name, time: 'Jour ' + state.day, content: message }]
  });

  const effets = {
    'forum_president_conference': { pop: 15, inf: 10 },
    'forum_president_annonce':    { pop: 5,  inf: 5  },
    'forum_president_propagande': { pop: 20, inf: 0  },
    'forum_president_dementi':    { pop: 8,  inf: 3  }
  };
  const ef = effets[type] || {};
  if (ef.pop) state.pop = Math.min(100, state.pop + ef.pop);
  if (ef.inf) state.inf = Math.min(100, state.inf + ef.inf);
  if (type === 'jour_deuil') {
    // Pas d'impots ce jour
    state.deuil = state.day;
    addExternalEvent('DEUIL NATIONAL : Journee chommee declaree par le President. Pas de recettes fiscales aujourd\'hui.');
  }
  updateUI();
  closeMailView();
  showToast('Publie !', titre + (ef.pop ? ' +' + ef.pop + ' POP' : '') + (ef.inf ? ' +' + ef.inf + ' INF' : ''), true, true);
  addJournalEntry('Publication presidentielle : ' + titre, 'event-good');
}

function ouvrirModalNationaliser() {
  const entreprises = ENTREPRISES_PRIVEES[state.country] || [];
  document.getElementById('postes-modal-title').textContent = 'Nationaliser une entreprise';
  let html = '<div style="padding:1rem">';
  if (entreprises.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucune entreprise privee recensee pour le moment. Les entreprises achetees par des PJ apparaitront ici.</div>';
  } else {
    entreprises.forEach((e, i) => {
      html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;display:flex;justify-content:space-between;align-items:center">';
      html += '<div style="font-size:.85rem;color:#c0b090">' + e.nom + ' <span style="font-size:.68rem;color:#5a4030">(propriete : ' + (e.proprio||'inconnu') + ')</span></div>';
      html += '<button onclick="confirmerNationalisation(' + i + ')" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;padding:.25rem .6rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">Nationaliser</button>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerNationalisation(idx) {
  const e = ENTREPRISES_PRIVEES[state.country]?.[idx];
  if (!e) return;
  e.nationalise = true;
  document.getElementById('modal-postes').classList.remove('open');
  INDICES_NATIONAUX[state.country].IE = Math.min(100, INDICES_NATIONAUX[state.country].IE + 5);
  showToast('Nationalisation', e.nom + ' est desormais propriete de l\'Etat. +5 IE.', true);
  addExternalEvent('NATIONALISATION : ' + e.nom + ' placee sous controle de l\'Etat par decret presidentiel.');
}

function ouvrirModalCibleRepertoire(action, titre) {
  const contacts = state.contacts || [];
  document.getElementById('postes-modal-title').textContent = titre;
  let html = '<div style="padding:1rem">';
  if (contacts.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Votre repertoire est vide. Enregistrez des contacts pour cibler des personnes.</div>';
  } else {
    html += '<div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Choisir la cible :</div>';
    contacts.forEach((c, i) => {
      html += '<div onclick="executerOrdreContact(\'' + action + '\',\'' + c.name + '\')" style="padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.3rem;cursor:pointer;transition:background .2s" onmouseover="this.style.background=\'#151005\'" onmouseout="this.style.background=\'#0f0d05\'">';
      html += '<div style="font-family:Playfair Display,serif;font-size:.82rem;color:#c0b090">' + c.name + '</div>';
      html += '<div style="font-size:.68rem;color:#5a4030">' + (c.role||'') + '</div></div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function executerOrdreContact(action, nomCible) {
  document.getElementById('modal-postes').classList.remove('open');
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  if (action === 'nommer_pm_confirm') {
    envoyerNotificationVraiJoueur(nomCible, 'Nomination au poste de Premier Ministre',
      'Par decision presidentielle, vous etes nomme(e) Premier Ministre. Prenez vos fonctions immediatement au Palais du Gouvernement.');
    addExternalEvent('NOMINATION : ' + nomCible + ' est nomme(e) Premier Ministre par le President.');
    showToast('PM nomme', nomCible + ' est le nouveau Premier Ministre.', true, true);
  } else if (action === 'redressement_fiscal') {
    const montant = 2000;
    state.arg += montant;
    INDICES_NATIONAUX[state.country].IE = Math.max(0, INDICES_NATIONAUX[state.country].IE - 3);
    updateUI();
    showToast('Redressement', 'Redressement fiscal contre ' + nomCible + '. +' + montant + ' ' + cur + ' -3 IE.', true);
    addJournalEntry('Redressement fiscal contre ' + nomCible, 'event-info');
    addMailNotification('Ministere des Finances', 'Notification de redressement', 'Un redressement fiscal vous a ete notifie par le Ministre des Finances.');
  } else if (action === 'subvention') {
    const montant = 500;
    if (state.arg < montant) { showToast('Fonds insuffisants', '', false); return; }
    state.arg -= montant;
    INDICES_NATIONAUX[state.country].IS = Math.min(100, INDICES_NATIONAUX[state.country].IS + 3);
    updateUI();
    showToast('Subvention accordee', 'Subvention de ' + montant + ' ' + cur + ' versee a ' + nomCible + '. +3 IS.', true);
  } else if (action === 'ouvrir_enquete') {
    const budget = getBudgetInstitution('tribunal');
    if (!depenseBudget('tribunal', 600)) return;
    if (!state.enquetesEnCours) state.enquetesEnCours = [];
    state.enquetesEnCours.push({ cible: nomCible, day: state.day + 1, status: 'pending', initiateur: 'Ministre Justice' });
    showToast('Enquete ouverte', 'Enquete judiciaire lancee contre ' + nomCible + '. Resultat dans 24h.', true);
    addJournalEntry('Enquete judiciaire ouverte contre ' + nomCible, 'event-info');
  } else {
    showToast(action.replace(/_/g,' '), 'Action menee sur ' + nomCible, true);
    addJournalEntry(action.replace(/_/g,' ') + ' : ' + nomCible, 'event-info');
  }
}

function ouvrirModalTexteLibre(action, titre, placeholder) {
  document.getElementById('postes-modal-title').textContent = titre;
  let html = '<div style="padding:1rem">';
  html += '<textarea id="texte-libre-input" rows="4" placeholder="' + placeholder + '" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.6rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;resize:none;margin-bottom:.7rem"></textarea>';
  html += '<button onclick="executerOrdreTexte(\'' + action + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Valider</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function executerOrdreTexte(action) {
  const texte = document.getElementById('texte-libre-input')?.value?.trim();
  if (!texte) { showToast('Champ requis', 'Veuillez remplir le champ.', false); return; }
  document.getElementById('modal-postes').classList.remove('open');
  if (action === 'interdire_manif') {
    INDICES_NATIONAUX[state.country].ISN = Math.min(100, INDICES_NATIONAUX[state.country].ISN + 5);
    state.pop = Math.max(0, state.pop - 5);
    updateUI();
    showToast('Manifestation interdite', texte + ' — +5 ISN -5 POP.', true);
    addExternalEvent('INTERDICTION : La manifestation "' + texte + '" a ete interdite par le Ministre de l\'Interieur.');
  } else if (action === 'reprimer_manif') {
    INDICES_NATIONAUX[state.country].ISN = Math.min(100, INDICES_NATIONAUX[state.country].ISN + 10);
    state.pop = Math.max(0, state.pop - 15);
    updateUI();
    showToast('Repression ordonnee', texte + ' — +10 ISN -15 POP.', false);
    addExternalEvent('REPRESSION : Ordre de dispersion force pour "' + texte + '".');
  } else if (action === 'commanditer_sondage') {
    state.inf = Math.min(100, state.inf + 5);
    updateUI();
    showToast('Sondage publie', '"' + texte + '" publie dans le forum national. +5 INF.', true);
  } else {
    showToast(action, texte, true);
    addJournalEntry(action + ' : ' + texte, 'event-info');
  }
}

function ouvrirModalSecteur() {
  document.getElementById('postes-modal-title').textContent = 'Allegement fiscal sectoriel';
  let html = '<div style="padding:1rem"><div style="font-size:.82rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Choisir le secteur beneficiaire :</div>';
  SECTEURS.forEach(s => {
    html += '<button onclick="appliquerAllegement(\'' + s + '\')" style="display:block;width:100%;text-align:left;padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;color:#c0b090;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem;margin-bottom:.3rem">' + s + '</button>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function appliquerAllegement(secteur) {
  document.getElementById('modal-postes').classList.remove('open');
  INDICES_NATIONAUX[state.country].IE = Math.min(100, INDICES_NATIONAUX[state.country].IE + 5);
  state.inf = Math.min(100, state.inf + 8);
  updateUI();
  showToast('Allegement accorde', secteur + ' : -taxes +5 IE +8 INF.', true);
  addJournalEntry('Allegement fiscal accorde au secteur : ' + secteur, 'event-info');
}

async function ouvrirModalAffaires(mode) {
  const titre = mode === 'annuler' ? 'Annuler des poursuites' : 'Gestion judiciaire';
  document.getElementById('postes-modal-title').textContent = titre;
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a8060;font-style:italic">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  if (typeof sbLoadPlaintes === 'function') {
    try { state.plaintesEnCours = await sbLoadPlaintes(state.country); } catch(e) {}
  }
  const affaires = state.plaintesEnCours?.filter(p => p.status === 'pending') || [];
  const condamnes = state.prisonniers?.filter(p => p.jourFin > state.day) || [];

  let html = '<div style="padding:1rem">';
  const liste = mode === 'annuler' ? affaires : condamnes;
  if (liste.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucune affaire en cours.</div>';
  } else {
    liste.forEach((a) => {
      const refId = a.id || a.nom; // prisonniers n'ont pas forcement d'id, fallback sur le nom
      html += '<div style="padding:.5rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;display:flex;justify-content:space-between;align-items:center">';
      html += '<div style="font-size:.82rem;color:#c0b090">' + (a.cible||a.nom||'Inconnu') + ' <span style="font-size:.68rem;color:#5a4030">— ' + (a.motif||a.raison||'') + '</span></div>';
      html += '<button onclick="annulerAffaire(&quot;' + refId + '&quot;,\'' + mode + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.65rem;padding:.2rem .5rem;border:1px solid #8a3020;background:transparent;color:#cc4a3a;cursor:pointer">Annuler</button>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function annulerAffaire(refId, mode) {
  document.getElementById('modal-postes').classList.remove('open');
  if (mode === 'annuler') {
    const affaire = (state.plaintesEnCours||[]).find(p => p.id === refId);
    if (affaire) {
      affaire.status = 'annulee';
      if (typeof sbSavePlainte === 'function') await sbSavePlainte(affaire).catch(() => {});
      showToast('Poursuites annulees', 'La procedure a ete classee.', false);
      addJournalEntry('Annulation de poursuites par le Ministre de la Justice.', 'event-info');
    }
  }
}

function ouvrirModalNommerJuge() {
  if (state.poste?.id !== 'min_just') {
    showToast('Accès refusé', 'Seul le Ministre de la Justice peut nommer un juge.', false);
    return;
  }
  ouvrirNominerPosteNomme('juge');
}

function ouvrirModalNommerCommissaire() {
  if (state.poste?.id !== 'maire') {
    showToast('Accès refusé', 'Seul le Maire peut nommer un commissaire.', false);
    return;
  }
  ouvrirNominerPosteNomme('commissaire');
}

function ouvrirModalRenseignement() {
  const contacts = state.contacts || [];
  const empires = Object.entries(COUNTRIES).filter(([k]) => k !== state.country);
  document.getElementById('postes-modal-title').textContent = 'Operation de renseignement';
  let html = '<div style="padding:1rem"><div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Cible : PJ suspect ou empire etranger ?</div>';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">EMPIRES</div>';
  empires.forEach(([k, co]) => {
    html += '<button onclick="executerOrdreEmpire(\'renseignement\',\'' + k + '\',\'' + co.n + '\')" style="display:flex;align-items:center;gap:.5rem;width:100%;padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;color:#c0b090;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem;margin-bottom:.3rem"><i class="ti ' + co.icon + '" style="color:' + co.col + '"></i> ' + co.n + '</button>';
  });
  if (contacts.length > 0) {
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin:.7rem 0 .4rem">PJ SUSPECTS (repertoire)</div>';
    contacts.forEach(c => {
      html += '<button onclick="executerOrdreContact(\'renseignement_pj\',\'' + c.name + '\')" style="display:block;width:100%;text-align:left;padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;color:#c0b090;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem;margin-bottom:.3rem">' + c.name + '</button>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function ouvrirModalMedia() {
  const medias = MEDIAS[state.country] || [];
  document.getElementById('postes-modal-title').textContent = 'Censurer un media';
  let html = '<div style="padding:1rem"><div style="font-size:.8rem;color:#cc4444;font-style:italic;margin-bottom:.8rem">Attention : la censure peut provoquer un scandale si elle est decouverte.</div>';
  medias.forEach((m, i) => {
    html += '<button onclick="censurer(\'' + m + '\')" style="display:block;width:100%;text-align:left;padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;color:#c0b090;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem;margin-bottom:.3rem">' + m + '</button>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function censurer(media) {
  document.getElementById('modal-postes').classList.remove('open');
  INDICES_NATIONAUX[state.country].IS = Math.max(0, INDICES_NATIONAUX[state.country].IS - 8);
  const roll = Math.floor(Math.random() * 100) + 1;
  if (roll <= 30) {
    addExternalEvent('SCANDALE : La censure de ' + media + ' a ete revelee ! -20 POP.');
    state.pop = Math.max(0, state.pop - 20);
    updateUI();
  } else {
    showToast('Media censure', media + ' suspendu. -8 IS.', false);
    addJournalEntry('Censure de ' + media, 'event-bad');
  }
}

function ouvrirModalTraite() {
  const empires = Object.entries(COUNTRIES).filter(([k]) => k !== state.country);
  const types = ['Commercial', 'De paix', "D'alliance militaire", 'Non-agression', 'Culturel'];
  document.getElementById('postes-modal-title').textContent = 'Signer un traite';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">EMPIRE</div>';
  html += '<select id="traite-empire" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.7rem">';
  empires.forEach(([k, co]) => { html += '<option value="' + k + '">' + co.n + '</option>'; });
  html += '</select>';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">TYPE DE TRAITE</div>';
  html += '<select id="traite-type" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.7rem">';
  types.forEach(t => { html += '<option value="' + t + '">' + t + '</option>'; });
  html += '</select>';
  html += '<button onclick="signerTraite()" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Signer</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function signerTraite() {
  const empireId = document.getElementById('traite-empire')?.value;
  const type = document.getElementById('traite-type')?.value;
  document.getElementById('modal-postes').classList.remove('open');
  const empireName = COUNTRIES[empireId]?.n || empireId;
  INDICES_NATIONAUX[state.country].ID = Math.min(100, INDICES_NATIONAUX[state.country].ID + 12);
  if (!state.traites) state.traites = [];
  state.traites.push({ empire: empireId, type, jour: state.day });
  showToast('Traite signe', 'Traite ' + type + ' avec ' + empireName + '. +12 ID.', true, true);
  addExternalEvent('TRAITE : Accord ' + type + ' signe entre ' + (COUNTRIES[state.country]?.n||'') + ' et ' + empireName + '.');
}

function ouvrirModalNommerAmbassadeur() {
  const contacts = state.contacts || [];
  const empires = Object.entries(COUNTRIES).filter(([k]) => k !== state.country);
  document.getElementById('postes-modal-title').textContent = 'Nommer un ambassadeur';
  let html = '<div style="padding:1rem">';
  if (contacts.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Repertoire vide.</div>';
  } else {
    html += '<select id="amb-contact" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;margin-bottom:.7rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none">';
    contacts.forEach(c => { html += '<option value="' + c.name + '">' + c.name + '</option>'; });
    html += '</select>';
    html += '<select id="amb-empire" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;margin-bottom:.7rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none">';
    empires.forEach(([k,co]) => { html += '<option value="' + k + '">' + co.n + '</option>'; });
    html += '</select>';
    html += '<button onclick="confirmerAmbassadeur()" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Nommer</button>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerAmbassadeur() {
  const contact = document.getElementById('amb-contact')?.value;
  const empireId = document.getElementById('amb-empire')?.value;
  document.getElementById('modal-postes').classList.remove('open');
  const empireName = COUNTRIES[empireId]?.n || empireId;
  envoyerNotificationVraiJoueur(contact, 'Nomination comme ambassadeur', 'Vous avez ete nomme(e) ambassadeur(rice) aupres de ' + empireName + ' par le Ministre des Affaires Etrangeres.');
  addExternalEvent('NOMINATION : ' + contact + ' nomme(e) ambassadeur(rice) aupres de ' + empireName + '.');
  showToast('Ambassadeur nomme', contact + ' → ' + empireName, true);
}

function doReceptionAvecBonus(fn, cost) {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  // Prelever sur le budget de la Presidence, pas sur l'argent personnel
  if (!verifierBudgetInstitution('presidence')) return;

  // Bonus/malus selon popularite
  const popBonus = state.pop > 20 ? Math.floor((state.pop - 20) * 1) : -Math.floor((20 - state.pop) * 1);
  const taux = Math.min(95, Math.max(5, 80 + Math.floor(popBonus / 2)));
  const roll = Math.floor(Math.random() * 100) + 1;

  if (roll <= taux) {
    state.pop = Math.min(100, state.pop + 10);
    state.inf = Math.min(100, state.inf + 8);
    state.moral = Math.min(100, state.moral + 5);
    INDICES_NATIONAUX[state.country].ID = Math.min(100, INDICES_NATIONAUX[state.country].ID + 5);
    updateUI();
    showToast(fn === 'reception_etat' ? 'Reception reussie !' : 'Banquet reussi !', '+10 POP +8 INF +5 Moral +5 ID.', true, true);
    addJournalEntry(fn === 'reception_etat' ? 'Reception d\'Etat reussie.' : 'Banquet diplomatique reussi.', 'event-good');
  } else {
    state.pop = Math.max(0, state.pop - 30);
    state.inf = Math.max(0, state.inf - 30);
    state.moral = Math.max(0, state.moral - 10);
    updateUI();
    showToast('Echec !', 'Les invites ont boude votre ' + (fn === 'reception_etat' ? 'reception' : 'banquet') + '. -30 POP -30 INF -10 Moral.', false);
    addExternalEvent('HUMILIATION : La ' + (fn === 'reception_etat' ? 'reception' : 'banquet diplomatique') + ' du President s\'est soldee par un echec cuisant. -30 POP -30 INF -10 Moral.');
  }
}

function ouvrirNommerMinistresModal() {
  const contacts = state.contacts || [];
  const postesMinisteriels = [
    { id:'min_int', name:"Ministre de l'Interieur" },
    { id:'min_fin', name:'Ministre des Finances' },
    { id:'min_just', name:'Ministre de la Justice' },
    { id:'min_def', name:'Ministre de la Defense' },
    { id:'min_info', name:"Ministre de l'Information" },
    { id:'min_ae', name:'Ministre des AE' }
  ];
  if (state.postesCustom?.ministre) postesMinisteriels.push({ id:'custom_ministre', name:state.postesCustom.ministre.nom });
  if (state.postesCustom?.comite) postesMinisteriels.push({ id:'custom_comite', name:state.postesCustom.comite.nom });

  document.getElementById('postes-modal-title').textContent = 'Nommer des ministres';
  let html = '<div style="padding:1rem">';
  if (contacts.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Repertoire vide. Enregistrez des contacts PJ.</div>';
  } else {
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">POSTE</div>';
    html += '<select id="nommer-min-poste" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.7rem">';
    postesMinisteriels.forEach(p => { html += '<option value="' + p.id + '">' + p.name + '</option>'; });
    html += '</select>';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">PJ A NOMMER</div>';
    html += '<select id="nommer-min-contact" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.8rem">';
    contacts.forEach(c => { html += '<option value="' + c.name + '">' + c.name + '</option>'; });
    html += '</select>';
    html += '<button onclick="validerNominationMinistre()" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Envoyer la nomination</button>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function validerNominationMinistre() {
  const posteId = document.getElementById('nommer-min-poste')?.value;
  const contact = document.getElementById('nommer-min-contact')?.value;
  const postesNoms = { min_int:"Ministre de l'Interieur", min_fin:'Ministre des Finances', min_just:'Ministre de la Justice', min_def:'Ministre de la Defense', min_info:"Ministre de l'Information", min_ae:'Ministre des AE' };
  const posteNom = postesNoms[posteId] || (state.postesCustom?.ministre?.nom) || (state.postesCustom?.comite?.nom) || posteId;
  document.getElementById('modal-postes').classList.remove('open');
  envoyerNotificationVraiJoueur(contact, 'Nomination ministerielle', 'Par decision du Premier Ministre, vous etes nomme(e) ' + posteNom + '. Prenez vos fonctions immediatement.');
  addExternalEvent('NOMINATION : ' + contact + ' est nomme(e) ' + posteNom + ' par le Premier Ministre.');
  showToast('Nomination envoyee', contact + ' → ' + posteNom, true, true);
}

// Appliquer malus ISN aux actes illegaux
function getMalusISN() {
  const isn = INDICES_NATIONAUX[state.country]?.ISN || 30;
  if (isn <= 20) return 0;
  if (isn <= 40) return 5;
  if (isn <= 60) return 10;
  if (isn <= 80) return 15;
  return 25;
}

function creerPosteMinistre() {
  if (!state.postesCustom) state.postesCustom = { ministre: null, comite: null };
  if (state.postesCustom.ministre) {
    showToast('Limite atteinte', 'Vous avez deja cree un poste ministeriel custom. Supprimez-le d\'abord.', false);
    return;
  }
  document.getElementById('postes-modal-title').textContent = 'Creer un poste ministeriel';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem">' +
    '<div style="font-size:.82rem;color:#8a8060;font-style:italic;margin-bottom:1rem">Vous pouvez creer 1 poste ministeriel et 1 comite. Salaire aligne sur les ministres (2800 FR/jour).</div>' +
    '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">INTITULE DU POSTE</div>' +
    '<input id="custom-poste-nom" type="text" placeholder="Ex: Ministre de la Transition Numerique" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.6rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.8rem"/>' +
    '<button onclick="validerCreationPoste(\'ministre\')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Creer ce poste</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

function creerComite() {
  if (!state.postesCustom) state.postesCustom = { ministre: null, comite: null };
  if (state.postesCustom.comite) {
    showToast('Limite atteinte', 'Vous avez deja cree un comite. Supprimez-le d\'abord.', false);
    return;
  }
  document.getElementById('postes-modal-title').textContent = 'Creer un comite';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem">' +
    '<div style="font-size:.82rem;color:#8a8060;font-style:italic;margin-bottom:1rem">Comite presidentiel special. Salaire aligne sur les ministres.</div>' +
    '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">INTITULE DU COMITE</div>' +
    '<input id="custom-poste-nom" type="text" placeholder="Ex: Comite pour la Modernisation de l\'Etat" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.6rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.8rem"/>' +
    '<button onclick="validerCreationPoste(\'comite\')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Creer ce comite</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

function validerCreationPoste(type) {
  const nom = document.getElementById('custom-poste-nom')?.value?.trim();
  if (!nom) { showToast('Nom requis', 'Donnez un nom a ce poste.', false); return; }
  if (!state.postesCustom) state.postesCustom = { ministre: null, comite: null };
  state.postesCustom[type] = { nom, salaire: 2800, createur: state.char?.name, jour: state.day };
  document.getElementById('modal-postes').classList.remove('open');
  showToast('Poste cree !', '"' + nom + '" a ete cree. Nommez quelqu\'un depuis votre bureau.', true, true);
  addJournalEntry('Nouveau poste cree par decret presidentiel : ' + nom, 'event-good');
  addExternalEvent('Le President a cree le poste de "' + nom + '" par decret.');
}

function supprimerPosteCustom() {
  if (!state.postesCustom || (!state.postesCustom.ministre && !state.postesCustom.comite)) {
    showToast('Aucun poste custom', 'Vous n\'avez pas cree de poste ou comite a supprimer.', false);
    return;
  }
  document.getElementById('postes-modal-title').textContent = 'Supprimer un poste';
  let html = '<div style="padding:1rem">';
  if (state.postesCustom.ministre) {
    html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.5rem;display:flex;justify-content:space-between;align-items:center">';
    html += '<div style="font-size:.85rem;color:#c0b090">' + state.postesCustom.ministre.nom + '</div>';
    html += '<button onclick="confirmerSupprPoste(\'ministre\')" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;padding:.25rem .6rem;border:1px solid #8a2020;background:transparent;color:#cc4444;cursor:pointer">Supprimer</button>';
    html += '</div>';
  }
  if (state.postesCustom.comite) {
    html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.5rem;display:flex;justify-content:space-between;align-items:center">';
    html += '<div style="font-size:.85rem;color:#c0b090">' + state.postesCustom.comite.nom + '</div>';
    html += '<button onclick="confirmerSupprPoste(\'comite\')" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;padding:.25rem .6rem;border:1px solid #8a2020;background:transparent;color:#cc4444;cursor:pointer">Supprimer</button>';
    html += '</div>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerSupprPoste(type) {
  const nom = state.postesCustom[type]?.nom || '';
  state.postesCustom[type] = null;
  document.getElementById('modal-postes').classList.remove('open');
  showToast('Poste supprime', '"' + nom + '" a ete supprime.', false);
  addJournalEntry('Poste supprime par decret : ' + nom, '');
}

// =====================
// FORUM
// =====================
// Forum gere par forum.js

// openForum delegue a forum.js
// Forum gere par forum.js — voir openForum() dans forum.js


