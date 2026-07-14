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
              ? `<button class="poste-btn pnj" onclick="postulerPoste('${p.id}','${p.name}')">${['pm','min_int','min_fin','min_just','min_def','min_info','min_ae'].includes(p.id) ? 'Envoyer ma demande' : 'Deloger le PNJ'}</button>`
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
async function ouvrirCalendrierElectoral() {
  const country = state.country;
  const co = COUNTRIES[country];
  const villeCourante = state.currentCity || 'capitale';

  document.getElementById('postes-modal-title').textContent = '📅 Calendrier Électoral — ' + (co?.n || country);
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement du calendrier électoral...</div>';
  document.getElementById('modal-postes').classList.add('open');

  // Charger l'etat reel depuis Supabase avant toute initialisation locale — evite d'ecraser un cycle deja en cours
  if (typeof syncCyclesDepuisSupabase === 'function') await syncCyclesDepuisSupabase();

  const now = Date.now();
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

  // Initialiser les cycles manquants (seulement s'ils n'existent vraiment nulle part, ni localement ni sur Supabase)
  if (!CYCLES_ELECTORAUX[country]) CYCLES_ELECTORAUX[country] = {};
  for (const p of postes) {
    const city = posteEstLocal(p.id) ? villeCourante : null;
    const cle = getCleCycle(p.id, city);
    if (!CYCLES_ELECTORAUX[country][cle]) await initCycleElectoral(country, p.id, city);
  }

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
          '<div style="font-family:Bebas Neue,sans-serif;font-size:.9rem;color:#e0d5b8">' + labelPoste + '</div>' +
          '<div style="font-size:.75rem;color:#a89870">' +
            (titulaire ? '✦ ' + titulaire : 'Poste vacant') +
          '</div>' +
        '</div>' +
        '<div style="text-align:right">' +
          '<div style="font-size:.75rem;font-family:Bebas Neue,sans-serif;color:' + phaseStyle.col + ';letter-spacing:.06em">' + phaseStyle.label + '</div>' +
          '<div style="font-size:.72rem;color:#a89870">' + nbCandidats + ' candidat(s)</div>' +
        '</div>' +
      '</div>' +
      // Échéances
      (echeances.length > 0
        ? '<div style="background:#0a0907;border:1px solid #1a1810;border-radius:3px;padding:.35rem .5rem;margin-top:.3rem">' +
          echeances.slice(0,3).map(e =>
            '<div style="display:flex;justify-content:space-between;font-size:.72rem;margin-bottom:.15rem">' +
              '<span style="color:#b0a080">' + e.label + '</span>' +
              '<span style="color:#d0c5a8">' + diffJours(e.date) + ' <span style="color:#8a8060">(' + formatDate(e.date) + ')</span></span>' +
            '</div>'
          ).join('') +
          '</div>'
        : '') +
      // Boutons action
      '<div style="display:flex;gap:.4rem;margin-top:.4rem">' +
        '<button onclick="ouvrirBureauDeVoteBtn(this)" data-poste="' + p.id + '" data-country="' + country + '" data-city="' + (city||'') + '" style="font-size:.7rem;font-family:Bebas Neue,sans-serif;padding:.25rem .6rem;border:1px solid #4a3a20;background:transparent;color:#b0a080;cursor:pointer">Détails →</button>' +
        (phase === PHASES_ELECTORALES.CANDIDATURES
          ? '<button onclick="deposerCandidatureBtn2Btn(this)" data-poste="' + p.id + '" data-country="' + country + '" data-city="' + (city||'') + '" style="font-size:.7rem;font-family:Bebas Neue,sans-serif;padding:.25rem .6rem;border:1px solid #5a7aca;background:transparent;color:#8aaaea;cursor:pointer">📋 Candidater</button>'
          : '') +
      '</div>' +
    '</div>';
  }).join('');

  document.getElementById('postes-modal-title').textContent = '📅 Calendrier Électoral — ' + (co?.n || country);
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.2rem .4rem">' +
    '<div style="font-size:.72rem;color:#8a8060;padding:.3rem .4rem;margin-bottom:.3rem;font-style:italic">' +
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
    const h = String(state.hour || 8).padStart(2, '0');
    const m = String(state.minute || 0).padStart(2, '0');
    const time = `Jour ${state.day} · ${h}h${m}`;
    const titre = '🏛 Nomination : ' + adminDef.name;
    const texte = 'Faute de candidat, ' + adminDef.name + ' est nommé ' + adminDef.role + '.\n\n"' + adminDef.trait + '"\n\nIl peut être destitué par un vote de l\'assemblée ou une candidature au prochain cycle.';
    sbCreateTopic('local', titre, 'Système', country, time).then(topicId => {
      if (topicId && typeof sbCreatePost === 'function') sbCreatePost(topicId, 'Système', texte, time);
      if (!FORUM_TOPICS['local']) FORUM_TOPICS['local'] = [];
      FORUM_TOPICS['local'].unshift({
        id: topicId || 'topic-' + Date.now(), title: titre, author: 'Système',
        time, views: 1, replies: 0, lastPostAuthor: 'Système', lastPostTime: time,
        posts: [{ id: 'p-' + Date.now(), author: 'Système', time, content: texte }]
      });
    }).catch(() => {});
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
  if (typeof sbInsert !== 'function' || typeof sbGet !== 'function') return;
  const cle = getCleCycle(posteId, city);
  const id = country + '_' + cle;
  try {
    const existing = await sbGet('cycles_electoraux', `id=eq.${encodeURIComponent(id)}`);
    const payload = {
      id, country, poste_id: posteId, city: posteEstLocal(posteId) ? (city || null) : null,
      data: JSON.stringify(cycle),
      updated_at: new Date().toISOString()
    };
    if (existing && existing.length > 0) {
      await sbUpdate('cycles_electoraux', `id=eq.${encodeURIComponent(id)}`, payload);
    } else {
      await sbInsert('cycles_electoraux', payload);
    }
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

async function initCycleElectoral(country, posteId, city) {
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
  if (typeof sbSaveCycleElectoral === 'function') {
    await sbSaveCycleElectoral(country, posteId, CYCLES_ELECTORAUX[country][cle], city).catch(() => {});
  }
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
async function deposerCandidature(posteId, country, city) {
  const nom = state.char?.name;
  if (!nom) return;

  // Vérifier domiciliation
  const domicile = state.domicile;
  const domicilePays = domicile?.country || state.country;
  if (domicilePays !== (country || state.country)) {
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
  if (!CYCLES_ELECTORAUX[c][cle]) await initCycleElectoral(c, posteId, city);

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

  // Publier sur le forum — national pour un poste national, local pour un poste de ville
  if (typeof sbCreateTopic === 'function') {
    const h = String(state.hour || 8).padStart(2, '0');
    const m = String(state.minute || 0).padStart(2, '0');
    const time = `Jour ${state.day} · ${h}h${m}`;
    const forumCible = posteEstLocal(posteId) ? 'local' : 'national';
    const titre = '🗳️ Candidature de ' + nom + ' — ' + POSTES_ELECTIFS.national.concat(POSTES_ELECTIFS.local).concat(POSTES_ELECTIFS.departemental).find(p=>p.id===posteId)?.name;
    const texte = nom + ' se présente aux élections.\n\nProgramme :\n' + programme;
    sbCreateTopic(forumCible, titre, nom, country, time).then(topicId => {
      if (topicId && typeof sbCreatePost === 'function') sbCreatePost(topicId, nom, texte, time);
      if (!FORUM_TOPICS[forumCible]) FORUM_TOPICS[forumCible] = [];
      FORUM_TOPICS[forumCible].unshift({
        id: topicId || 'topic-' + Date.now(), title: titre, author: nom,
        time, views: 1, replies: 0, lastPostAuthor: nom, lastPostTime: time,
        posts: [{ id: 'p-' + Date.now(), author: nom, time, content: texte }]
      });
    }).catch(() => {});
  }
}

// Vote PJ
function voterPour(candidatNom, posteId, country, city) {
  const votant = state.char?.name;
  if (!votant) return;

  const domicile = state.domicile;
  const domicilePays = domicile?.country || state.country;
  if (domicilePays !== country) {
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
async function ouvrirTableauElectoral() {
  const country = state.country;
  const co = COUNTRIES[country];
  const villeCourante = state.currentCity || 'capitale';
  const villeNom = WORLD[country]?.[villeCourante]?.name || villeCourante;

  document.getElementById('postes-modal-title').textContent = '🗳 Tableau Électoral — ' + (co?.n || country);
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  if (typeof syncCyclesDepuisSupabase === 'function') await syncCyclesDepuisSupabase();

  const postesTous = [...POSTES_ELECTIFS.national, ...POSTES_ELECTIFS.departemental, ...POSTES_ELECTIFS.local];
  if (!CYCLES_ELECTORAUX[country]) CYCLES_ELECTORAUX[country] = {};
  for (const p of postesTous) {
    const city = posteEstLocal(p.id) ? villeCourante : null;
    const cle = getCleCycle(p.id, city);
    if (!CYCLES_ELECTORAUX[country][cle]) await initCycleElectoral(country, p.id, city);
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
    }[phase] || '#a89870';

    return '<div style="padding:.5rem .4rem;border-bottom:1px solid #1a1810">' +
      '<div style="display:flex;justify-content:space-between;align-items:center">' +
        '<div>' +
          '<div style="font-family:Bebas Neue,sans-serif;font-size:.85rem;color:#e0d5b8">' + labelPoste + '</div>' +
          '<div style="font-size:.72rem;color:#a89870">' + titulaire + '</div>' +
        '</div>' +
        '<div style="text-align:right">' +
          '<div style="font-size:.72rem;color:' + phaseCol + ';font-family:Bebas Neue,sans-serif">' + (phase || 'N/A') + '</div>' +
          '<div style="font-size:.7rem;color:#a89870">' + nbCandidats + ' candidat(s)</div>' +
        '</div>' +
      '</div>' +
    '<button onclick="ouvrirBureauDeVoteBtn(this)" data-poste="' + p.id + '" data-country="' + country + '" data-city="' + (city||'') + '" ' +
      'style="margin-top:.3rem;font-size:.7rem;font-family:Bebas Neue,sans-serif;letter-spacing:.06em;padding:.25rem .6rem;border:1px solid #4a3a20;background:transparent;color:#b0a080;cursor:pointer">Voir détails →</button>' +
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
  const from = state.char?.name || 'Rédaction';
  const h = String(state.hour || 8).padStart(2, '0');
  const m = String(state.minute || 0).padStart(2, '0');
  const time = `Jour ${state.day} · ${h}h${m}`;
  const titre = '📰 Journal du Matin — Jour ' + (state.day||1);

  let topicId = null;
  if (typeof sbCreateTopic === 'function') {
    topicId = await sbCreateTopic('local', titre, from, state.country, time);
    if (topicId && typeof sbCreatePost === 'function') await sbCreatePost(topicId, from, texte, time);
  }
  if (!FORUM_TOPICS['local']) FORUM_TOPICS['local'] = [];
  FORUM_TOPICS['local'].unshift({
    id: topicId || 'topic-' + Date.now(), title: titre, author: from,
    time, views: 1, replies: 0, lastPostAuthor: from, lastPostTime: time,
    posts: [{ id: 'p-' + Date.now(), author: from, time, content: texte }]
  });
  showToast('Journal publié !', 'Visible sur le forum local.', true);
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

  // Fusionner avec les ordres du buildingContext (specifiques a l'empire courant)
  const world = WORLD[state.country];
  const city = world?.[state.currentCity];
  const ctx = city?.buildingContext?.[buildingId];
  const ctxOrders = (ctx?.orders || []);

  // Plus d'ordres communs ici — se_cacher/blocus/incendier sont dans la fiche personnage
  const allOrders = [...orders, ...ctxOrders];

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
  const from = state.char?.name || 'Le Président';
  const h = String(state.hour || 8).padStart(2, '0');
  const m = String(state.minute || 0).padStart(2, '0');
  const time = `Jour ${state.day} · ${h}h${m}`;

  let topicId = null;
  if (typeof sbCreateTopic === 'function') {
    topicId = await sbCreateTopic('local', '📜 Décret Présidentiel', from, state.country, time);
    if (topicId && typeof sbCreatePost === 'function') {
      await sbCreatePost(topicId, from, texte, time);
    }
  }

  if (!FORUM_TOPICS['local']) FORUM_TOPICS['local'] = [];
  FORUM_TOPICS['local'].unshift({
    id: topicId || 'topic-' + Date.now(), title: '📜 Décret Présidentiel', author: from,
    time, views: 1, replies: 0, lastPostAuthor: from, lastPostTime: time,
    posts: [{ id: 'p-' + Date.now(), author: from, time, content: texte }]
  });

  showToast('Décret publié !', 'Visible sur le forum national.', true);
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
async function ouvrirOrganigramme() {
  const postes = POSTES[state.country];
  if (!postes) return;
  const co = COUNTRIES[state.country];
  const myName = state.char?.name || '';

  // Lire les vrais titulaires depuis Supabase (source de verite partagee)
  let joueurs = [];
  if (typeof sbListPersonnages === 'function') {
    try { joueurs = (await sbListPersonnages() || []).filter(j => j.country === state.country); } catch(e) {}
  }

  const getTitulaire = (posteId) => {
    if (state.poste?.id === posteId) return myName; // moi-meme
    const j = joueurs.find(j => {
      let p = null;
      try { p = typeof j.poste === 'string' ? JSON.parse(j.poste) : j.poste; } catch(e) {}
      return p?.id === posteId;
    });
    return j?.name || null;
  };

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
      const holderName = getTitulaire(p.id);
      const isMe = holderName === myName;
      const holderLabel = !holderName
        ? '<span style="color:#4a4030;font-style:italic">Vacant</span>'
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

  // Postes nommes en cascade : le President nomme le PM, le PM nomme ses ministres
  const posteRequiertPM = ['pm'];
  const posteRequiertNominationParPM = ['min_int','min_fin','min_just','min_def','min_info','min_ae'];

  if (posteRequiertPM.includes(posteId) || posteRequiertNominationParPM.includes(posteId)) {
    const estPosteMinistre = posteRequiertNominationParPM.includes(posteId);
    const idValideur = estPosteMinistre ? 'pm' : 'president';
    const labelValideur = estPosteMinistre ? 'Premier Ministre' : 'Président de la République';

    const nomValideur = (typeof getTitulairePoste === 'function') ? await getTitulairePoste(idValideur) : null;

    if (!nomValideur) {
      showToast('Poste vacant', `Le poste de ${labelValideur} est actuellement vacant. Votre candidature ne peut pas etre transmise pour le moment.`, false);
      return;
    }

    const candidatNom = state.char?.name || 'Anonyme';
    const sujet = 'Candidature au poste de ' + posteName;
    const corps = candidatNom + ' postule au poste de <strong>' + posteName + '</strong>.<br><br>' +
      '<button onclick="accepterCandidaturePoste(\'' + posteId + '\',\'' + posteName.replace(/'/g,'') + '\',\'' + candidatNom.replace(/'/g,'') + '\')" ' +
      'style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer;margin-top:.5rem">✓ Accepter la candidature</button>';

    if (typeof sbSendMail === 'function') {
      const h = String(state.hour || 8).padStart(2,'0');
      const time = 'Jour ' + (state.day || 1) + ' · ' + h + 'h';
      await sbSendMail(candidatNom, nomValideur, sujet, corps, time).catch(() => {});
    }

    showToast('Demande transmise', `Votre candidature au poste de ${posteName} a ete transmise a ${nomValideur} (${labelValideur}).`, true);
    addJournalEntry(`Demande de poste envoyee a ${nomValideur} : ${posteName}. En attente de reponse.`, 'event-info');
    return;
  }

  // Verifier si le joueur n'a pas deja ce poste
  if (state.poste?.id === posteId) {
    showToast('Poste deja occupe', `Vous occupez deja le poste de ${posteName}.`, false);
    return;
  }

  const postes = POSTES[state.country];
  const allPostes = [
    ...(postes?.capitale || []),
    ...(postes?.assemblee || []),
    ...(postes?.[state.currentCity] || [])
  ];
  const poste = allPostes.find(p => p.id === posteId);
  const isVacant = !poste?.holder;
  const isPnjHolder = poste?.holder?.startsWith('PNJ');

  const successRate = isVacant ? 90 : isPnjHolder ? 65 : 0;
  if (successRate === 0) {
    showToast('Poste occupe', `Ce poste est occupe par un autre joueur.`, false);
    return;
  }

  const roll = Math.floor(Math.random() * 100) + 1;
  if (roll <= successRate) {
    // Marquer le poste comme pris dans POSTES
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

async function publierMessagePresidentiel(type) {
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
  const auteur = state.char?.name || 'Le Président';
  const time = formatDateHeureJeu();

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
  } else {
    titre = document.getElementById('pres-msg-titre')?.value?.trim();
    contenu = document.getElementById('pres-msg-contenu')?.value?.trim();
    if (!titre || !contenu) { showToast('Champs requis', 'Titre et contenu obligatoires.', false); return; }
  }

  const titrePrefixe = '[' + (type === 'referendum' ? 'RÉFÉRENDUM' : type.toUpperCase()) + '] ' + titre;

  // Persistance reelle sur Supabase — visible par tous, pas seulement localement
  let topicId = null;
  if (typeof sbCreateTopic === 'function') {
    topicId = await sbCreateTopic('presidence', titrePrefixe, auteur, pays, time);
    if (topicId && typeof sbCreatePost === 'function') await sbCreatePost(topicId, auteur, contenu, time);
  }

  if (!FORUM_TOPICS['presidence']) FORUM_TOPICS['presidence'] = [];
  FORUM_TOPICS['presidence'].unshift({
    id: topicId || 'pres-' + Date.now(), title: titrePrefixe,
    author: auteur, time, views: 1, replies: 0,
    lastPostAuthor: auteur, lastPostTime: time,
    isReferendum: type === 'referendum',
    reponses: type === 'referendum' ? state.referendums[state.referendums.length-1].reponses : undefined,
    posts: [{ author: auteur, time, content: contenu }]
  });

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
    views: 1, replies: 0, lastPostAuthor: state.char?.name || 'Député', lastPostTime: 'Jour ' + jourDepot,
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

// Appelee quand le President/PM clique "Accepter la candidature" dans le mail
async function accepterCandidaturePoste(posteId, posteName, candidatNom) {
  document.getElementById('modal-pnj')?.classList.remove('open');

  // Deposer une "nomination en attente" pour le candidat, appliquee a sa prochaine connexion
  if (typeof sbDeposerNominationPoste === 'function') {
    await sbDeposerNominationPoste({
      id: 'nomination-' + Date.now(),
      destinataire: candidatNom,
      poste_id: posteId,
      poste_name: posteName,
      country: state.country,
      traite: false
    }).catch(() => {});
  }

  // Notifier le candidat par mail (en plus de l'application directe a sa prochaine connexion)
  if (typeof sbSendMail === 'function') {
    const h = String(state.hour || 8).padStart(2,'0');
    const time = 'Jour ' + (state.day || 1) + ' · ' + h + 'h';
    await sbSendMail(state.char?.name || 'Anonyme', candidatNom, 'Candidature acceptée !',
      'Votre candidature au poste de ' + posteName + ' a été acceptée. Le poste sera effectif à votre prochaine connexion.', time).catch(() => {});
  }

  showToast('Candidature acceptée', candidatNom + ' devient ' + posteName + '.', true, true);
  addJournalEntry('Vous avez accepté la candidature de ' + candidatNom + ' au poste de ' + posteName + '.', 'event-good');
  addExternalEvent('🏛 ' + candidatNom + ' est nommé(e) ' + posteName + '.', 'national');
}

// Applique une nomination en attente au chargement du jeu (comme la naturalisation)
// Gere aussi le cas special DEMISSION_FORCEE (motion de censure adoptee contre le PM)
async function appliquerNominationPosteEnAttente() {
  if (typeof sbGetNominationsPosteEnAttente !== 'function' || !state.char?.name) return;
  try {
    const nominations = await sbGetNominationsPosteEnAttente(state.char.name);
    if (!nominations || nominations.length === 0) return;
    const nomination = nominations[0];

    if (nomination.poste_id === 'DEMISSION_FORCEE') {
      const ancienPoste = state.poste?.name || 'votre poste';
      state.poste = null;
      if (state.char) state.char.poste = null;

      if (typeof sbMarquerNominationTraitee === 'function') {
        await sbMarquerNominationTraitee(nomination.id).catch(() => {});
      }
      if (typeof sbSavePersonnage === 'function') {
        await sbSavePersonnage(state).catch(() => {});
      }

      updateUI();
      showToast('Censure adoptée', 'L\'Assemblée a retiré sa confiance. Vous avez démissionné de ' + ancienPoste + '.', false, true);
      addJournalEntry('Motion de censure adoptée contre vous. Démission forcée de ' + ancienPoste + '.', 'event-bad');
      return;
    }

    state.poste = { id: nomination.poste_id, name: nomination.poste_name };
    if (state.char) state.char.poste = state.poste;
    state.salaireTouche = false;

    if (typeof sbMarquerNominationTraitee === 'function') {
      await sbMarquerNominationTraitee(nomination.id).catch(() => {});
    }
    if (typeof sbSavePersonnage === 'function') {
      await sbSavePersonnage(state).catch(() => {});
    }

    updateUI();
    showToast('Nomination effective !', 'Vous êtes désormais ' + nomination.poste_name + '.', true, true);
    addJournalEntry('Votre nomination au poste de ' + nomination.poste_name + ' est effective.', 'event-good');
  } catch(e) { console.warn('appliquerNominationPosteEnAttente error', e); }
}



// =====================
// MARIAGE ENTRE DEUX PJ
// =====================
async function ouvrirModalDemandeMariage() {
  if (typeof sbGetMariageActif === 'function') {
    const mariageActuel = await sbGetMariageActif(state.char?.name);
    if (mariageActuel) {
      const conjoint = mariageActuel.conjoint1 === state.char?.name ? mariageActuel.conjoint2 : mariageActuel.conjoint1;
      showToast('Déjà marié(e)', 'Vous êtes déjà marié(e) avec ' + conjoint + '.', false);
      return;
    }
  }

  let presents = [];
  if (typeof sbGetPresencesInRoom === 'function' && state.currentBuilding && state.currentRoom) {
    try {
      const tous = await sbGetPresencesInRoom(state.country, state.currentCity, state.currentBuilding, state.currentRoom);
      presents = (tous || []).filter(p => p.name !== state.char?.name);
    } catch(e) {}
  }

  let joueurs = [];
  if (typeof sbListPersonnages === 'function') {
    try { joueurs = (await sbListPersonnages() || []).filter(j => j.name !== state.char?.name); } catch(e) {}
  }
  const liste = presents.length > 0 ? presents : joueurs;

  document.getElementById('postes-modal-title').textContent = 'Demande en mariage';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Une demande romantique sera envoyée par mail. Si elle est acceptée, vous devrez tous deux vous rendre ensemble à la mairie pour officialiser l\'union.</div>';

  if (liste.length === 0) {
    html += '<div style="font-size:.85rem;color:#5a5040">Aucun habitant connu pour le moment.</div>';
  } else {
    html += '<select id="mariage-destinataire-select" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.8rem">';
    liste.forEach(j => { html += '<option value="' + j.name + '">' + j.name + '</option>'; });
    html += '</select>';
    html += '<button onclick="confirmerDemandeMariage()" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">💍 Envoyer la demande</button>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerDemandeMariage() {
  const destinataire = document.getElementById('mariage-destinataire-select')?.value;
  document.getElementById('modal-postes').classList.remove('open');
  if (!destinataire) return;

  const demande = {
    id: 'demande-mariage-' + Date.now(),
    demandeur: state.char?.name || 'Anonyme',
    destinataire,
    country: state.country,
    statut: 'en_attente'
  };

  if (typeof sbCreerDemandeMariage === 'function') {
    await sbCreerDemandeMariage(demande).catch(() => {});
  }

  if (typeof sbSendMail === 'function') {
    const h = String(state.hour || 8).padStart(2,'0');
    const time = 'Jour ' + (state.day || 1) + ' · ' + h + 'h';
    const corps = (state.char?.name || 'Quelqu\'un') + ' vous demande en mariage !<br><br>' +
      '<button onclick="accepterDemandeMariage(&quot;' + demande.id + '&quot;)" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;padding:.4rem .8rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer;margin-right:.5rem">💍 Accepter</button>' +
      '<button onclick="refuserDemandeMariage(&quot;' + demande.id + '&quot;)" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;padding:.4rem .8rem;border:1px solid #6a2a20;background:transparent;color:#cc4444;cursor:pointer">Refuser</button>';
    await sbSendMail(state.char?.name || 'Anonyme', destinataire, 'Demande en mariage 💍', corps, time).catch(() => {});
  }

  showToast('Demande envoyée', 'Votre demande en mariage a été envoyée à ' + destinataire + '.', true, true);
  addJournalEntry('Demande en mariage envoyée à ' + destinataire + '.', 'event-info');
}

async function accepterDemandeMariage(demandeId) {
  document.getElementById('modal-pnj')?.classList.remove('open');
  if (typeof sbUpdateDemandeMariage === 'function') {
    await sbUpdateDemandeMariage(demandeId, 'acceptee').catch(() => {});
  }
  showToast('Demande acceptée !', 'Rendez-vous tous les deux à la mairie pour officialiser votre union.', true, true);
  addJournalEntry('Vous avez accepté la demande en mariage. Rendez-vous à la mairie pour officialiser.', 'event-good');
}

async function refuserDemandeMariage(demandeId) {
  document.getElementById('modal-pnj')?.classList.remove('open');
  if (typeof sbUpdateDemandeMariage === 'function') {
    await sbUpdateDemandeMariage(demandeId, 'refusee').catch(() => {});
  }
  showToast('Demande refusée', '', false);
  addJournalEntry('Vous avez refusé une demande en mariage.', '');
}

// Officialiser : necessite que les DEUX futurs epoux soient physiquement presents dans la meme piece
async function ouvrirOfficialiserMariage() {
  if (!state.char?.name) return;

  let demandesAcceptees = [];
  if (typeof sbGetDemandesMariagePour === 'function') {
    // Chercher les demandes ou JE suis le demandeur ET acceptees (sbGetDemandesMariagePour filtre par destinataire,
    // donc on verifie aussi dans l'autre sens via une recherche large)
    try {
      const enAttentePourMoi = await sbGetDemandesMariagePour(state.char.name);
      demandesAcceptees = enAttentePourMoi; // securite, normalement vide ici car deja traitees
    } catch(e) {}
  }

  // Verifier qui est present dans la piece et a une demande acceptee avec moi
  let presents = [];
  if (typeof sbGetPresencesInRoom === 'function' && state.currentBuilding && state.currentRoom) {
    try {
      const tous = await sbGetPresencesInRoom(state.country, state.currentCity, state.currentBuilding, state.currentRoom);
      presents = (tous || []).filter(p => p.name !== state.char?.name);
    } catch(e) {}
  }

  if (presents.length === 0) {
    showToast('Personne ici', 'Votre futur(e) époux/épouse doit être présent(e) dans cette pièce.', false);
    return;
  }

  document.getElementById('postes-modal-title').textContent = 'Officialiser le mariage';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Sélectionnez votre futur(e) époux/épouse présent(e). Une demande acceptée entre vous deux est requise.</div>';
  html += '<select id="mariage-officialiser-select" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.8rem">';
  presents.forEach(p => { html += '<option value="' + p.name + '">' + p.name + '</option>'; });
  html += '</select>';
  html += '<button onclick="confirmerOfficialisationMariage()" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">💍 Célébrer l\'union (200 FR)</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerOfficialisationMariage() {
  const conjoint = document.getElementById('mariage-officialiser-select')?.value;
  if (!conjoint) return;

  const cout = 200;
  if (state.arg < cout) { showToast('Fonds insuffisants', cout + ' requis.', false); return; }

  state.arg -= cout;
  document.getElementById('modal-postes').classList.remove('open');

  const mariage = {
    id: 'mariage-' + Date.now(),
    conjoint1: state.char?.name,
    conjoint2: conjoint,
    country: state.country,
    statut: 'actif',
    jour_union: state.day || 1
  };

  if (typeof sbCreerMariage === 'function') {
    await sbCreerMariage(mariage).catch(() => {});
  }

  updateUI();
  showToast('Félicitations !', 'Vous êtes désormais marié(e) à ' + conjoint + ' !', true, true);
  addJournalEntry('💍 Mariage célébré avec ' + conjoint + ' !', 'event-good');
  addExternalEvent('💍 ' + (state.char?.name||'') + ' et ' + conjoint + ' se sont mariés !', 'local');

  if (typeof sbSendMail === 'function') {
    const h = String(state.hour || 8).padStart(2,'0');
    const time = 'Jour ' + (state.day || 1) + ' · ' + h + 'h';
    await sbSendMail('Mairie', conjoint, 'Mariage célébré !', 'Votre mariage avec ' + (state.char?.name||'') + ' a été officialisé. Félicitations !', time).catch(() => {});
  }
}


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

async function ouvrirEtatNation() {
  const pays = state.country || 'republic';
  const idx = INDICES_NATIONAUX[pays] || { ISN:30, IE:50, ID:40, IS:45 };
  document.querySelectorAll('.vue').forEach(v => v.classList.remove('active'));
  const el = document.getElementById('vue-self');
  if (!el) return;
  el.classList.add('active');
  document.getElementById('self-view-name').textContent = 'Etat de la Nation';
  document.getElementById('self-view-role').textContent = COUNTRIES[pays]?.n || '';
  const content = document.getElementById('self-content');
  content.innerHTML = '<div style="padding:1.5rem;color:#8a8060;font-style:italic">Chargement...</div>';

  const guerres = typeof sbGetGuerresPays === 'function' ? await sbGetGuerresPays(pays).catch(() => []) : [];

  const indices = [
    { k:'ISN', label:'Securite Nationale',    val:idx.ISN, col:'#6ab858', desc:'Impact sur les actes illegaux et leur detection.' },
    { k:'IE',  label:'Economique',            val:idx.IE,  col:'#C9A84C', desc:'Impact sur les revenus fiscaux et les salaires.' },
    { k:'ID',  label:'Diplomatique',          val:idx.ID,  col:'#5a8ad0', desc:'Impact sur les relations inter-empires et voyages.' },
    { k:'IS',  label:'Social',               val:idx.IS,  col:'#d4886a', desc:'Impact sur la popularite des elus et risques de greve.' }
  ];

  let html = '<div style="padding:1.5rem;max-width:650px">';
  html += '<div style="font-family:Playfair Display,serif;font-size:1.1rem;color:#C9A84C;margin-bottom:1.2rem">Indices de la Nation — ' + (COUNTRIES[pays]?.n||'') + '</div>';

  // Statut diplomatique : guerre/treve, ou paix par defaut
  html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.7rem;margin-bottom:1rem">';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.8rem;color:#e0d5b8;letter-spacing:.08em;margin-bottom:.4rem">STATUT DIPLOMATIQUE</div>';
  if (guerres.length === 0) {
    html += '<div style="font-size:.85rem;color:#6ab858">En paix avec tous les empires.</div>';
  } else {
    guerres.forEach(g => {
      const adversaire = g.attaquant === pays ? g.attaque : g.attaquant;
      const nomAdv = COUNTRIES[adversaire]?.n || adversaire;
      if (g.ceasefire?.actifPar?.[pays] || g.ceasefire?.actifPar?.[adversaire]) {
        html += '<div style="font-size:.85rem;color:#d4a850">🕊 En trêve avec ' + nomAdv + (g.ceasefire.actifPar[pays] && !g.ceasefire.actifPar[adversaire] ? ' (activée de notre côté seulement)' : '') + '</div>';
      } else {
        html += '<div style="font-size:.85rem;color:#cc4444">⚔ En guerre avec ' + nomAdv + '</div>';
      }
    });
  }
  html += '</div>';

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
    html += '<div style="font-size:.72rem;color:#8a8060">' + ind.desc + '</div>';
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

// =====================
// FILE D'ATTENTE DIPLOMATIQUE GENERIQUE
// Reutilisee par : signer un traite, ouvrir des negociations. Schema commun :
// proposer -> mail a l'homologue -> il accepte ou refuse -> effet bilateral (ID).
// =====================
const DIPLOMATIE_CONFIG = {
  traite: {
    label: 'Traité',
    gainAccepte: 12,
    perteRefus: 12,
    genereForumSujet: false
  },
  negociation: {
    label: 'Négociations diplomatiques',
    gainAccepte: 8,
    perteRefus: 8,
    genereForumSujet: true
  }
};

async function proposerDiplomatie(type, empireCibleId, empireCibleName, details) {
  const pays = state.country || 'republic';
  const config = DIPLOMATIE_CONFIG[type];
  if (!config) return;

  const proposeur = state.char?.name || 'Le Ministre';
  const empireProposeurNom = COUNTRIES[pays]?.n || pays;
  const maeAdversaire = await getTitulairePoste('min_ae', null, empireCibleId);

  const data = {
    type,
    empireProposeur: pays,
    empireCible: empireCibleId,
    empireCibleNom: empireCibleName,
    empireProposeurNom,
    proposeur,
    details: details || '',
    jour: state.day || 1
  };
  if (typeof sbCreerPropositionDiplomatique === 'function') await sbCreerPropositionDiplomatique(data).catch(() => {});

  if (typeof sbSendMail === 'function') {
    await sbSendMail('Ministère des Affaires Étrangères', maeAdversaire || 'PNJ-MAE',
      config.label + ' proposé(e)',
      proposeur + ' (' + empireProposeurNom + ') propose : ' + config.label + '. Rendez-vous à votre ministère pour répondre.',
      typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : '').catch(() => {});
  }

  // Sujet forum international pour les negociations — visibilite publique de la demarche
  if (config.genereForumSujet) {
    const forumKey = 'international';
    if (!FORUM_TOPICS[forumKey]) FORUM_TOPICS[forumKey] = [];
    FORUM_TOPICS[forumKey].unshift({
      id: 'diplo-forum-' + Date.now(),
      title: '[NÉGOCIATIONS] ' + empireProposeurNom + ' ↔ ' + empireCibleName,
      author: 'Ministère des Affaires Étrangères',
      time: 'Jour ' + (state.day || 1),
      content: proposeur + ' (' + empireProposeurNom + ') ouvre des négociations diplomatiques avec ' + empireCibleName + '.'
    });
  }

  showToast(config.label + ' proposé(e)', 'En attente de la réponse de ' + empireCibleName + '.', true, true);
  addJournalEntry(config.label + ' proposé(e) à ' + empireCibleName + '.', 'event-info');
}

async function ouvrirReponsesDiplomatiques() {
  if (state.poste?.id !== 'min_ae') { showToast('Réservé au Ministre des Affaires Étrangères', '', false); return; }
  const pays = state.country || 'republic';
  document.getElementById('postes-modal-title').textContent = 'Propositions diplomatiques';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a8060;font-style:italic">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const propositions = typeof sbGetPropositionsDiplomatiques === 'function' ? await sbGetPropositionsDiplomatiques(pays).catch(() => []) : [];
  const recues = propositions.filter(p => p.empireCible === pays);

  let html = '<div style="padding:1rem">';
  if (recues.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucune proposition en attente.</div>';
  } else {
    recues.forEach(p => {
      const config = DIPLOMATIE_CONFIG[p.type] || { label: p.type };
      html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.7rem;margin-bottom:.5rem">';
      html += '<div style="font-family:Playfair Display,serif;font-size:.85rem;color:#E8C97A;margin-bottom:.3rem">' + config.label + ' — ' + p.empireProposeurNom + '</div>';
      if (p.details) html += '<div style="font-size:.72rem;color:#8a8060;margin-bottom:.5rem">' + p.details + '</div>';
      html += '<div style="display:flex;gap:.4rem">';
      html += '<button onclick="repondreDiplomatie(&quot;' + p.id + '&quot;,true)" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.72rem;padding:.4rem;border:1px solid #4a8a4a;background:transparent;color:#6ab858;cursor:pointer">Accepter</button>';
      html += '<button onclick="repondreDiplomatie(&quot;' + p.id + '&quot;,false)" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.72rem;padding:.4rem;border:1px solid #8a2020;background:transparent;color:#cc4444;cursor:pointer">Refuser</button>';
      html += '</div></div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function repondreDiplomatie(propositionId, accepte) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const rows = typeof sbGet === 'function' ? await sbGet('propositions_diplomatiques', `id=eq.${encodeURIComponent(propositionId)}`).catch(() => []) : [];
  const p = rows?.[0]?.data;
  if (!p) return;
  const config = DIPLOMATIE_CONFIG[p.type] || { gainAccepte: 0, perteRefus: 0, label: p.type };

  if (typeof sbMajPropositionDiplomatique === 'function') {
    await sbMajPropositionDiplomatique(propositionId, { statut: accepte ? 'acceptee' : 'refusee' });
  }

  if (accepte) {
    INDICES_NATIONAUX[p.empireProposeur] = INDICES_NATIONAUX[p.empireProposeur] || {};
    INDICES_NATIONAUX[p.empireCible] = INDICES_NATIONAUX[p.empireCible] || {};
    INDICES_NATIONAUX[p.empireProposeur].ID = Math.min(100, (INDICES_NATIONAUX[p.empireProposeur].ID || 50) + config.gainAccepte);
    INDICES_NATIONAUX[p.empireCible].ID = Math.min(100, (INDICES_NATIONAUX[p.empireCible].ID || 50) + config.gainAccepte);
    if (p.type === 'traite') {
      if (!state.traites) state.traites = [];
      state.traites.push({ empire: p.empireProposeur, type: p.details, jour: state.day });
    }
    showToast(config.label + ' accepté(e)', '+' + config.gainAccepte + ' ID pour les deux camps.', true, true);
    addExternalEvent(config.label.toUpperCase() + ' : accord conclu entre ' + p.empireProposeurNom + ' et ' + (COUNTRIES[p.empireCible]?.n || p.empireCible) + '.');
  } else {
    INDICES_NATIONAUX[p.empireCible] = INDICES_NATIONAUX[p.empireCible] || {};
    INDICES_NATIONAUX[p.empireCible].ID = Math.max(0, (INDICES_NATIONAUX[p.empireCible].ID || 50) - config.perteRefus);
    showToast(config.label + ' refusé(e)', '-' + config.perteRefus + ' ID.', false);
    addJournalEntry(config.label + ' refusée avec ' + p.empireProposeurNom + '. -' + config.perteRefus + ' ID.', 'event-bad');
  }

  if (typeof sbSendMail === 'function') {
    await sbSendMail('Ministère des Affaires Étrangères', p.proposeur,
      config.label + ' : réponse reçue',
      (COUNTRIES[p.empireCible]?.n || p.empireCible) + ' a ' + (accepte ? 'accepté' : 'refusé') + ' votre proposition.',
      typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : '').catch(() => {});
  }
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

// Juge PNJ par defaut, tant qu'aucun PJ n'a ete nomme — regle les affaires sur des criteres parodiques
const JUGE_PNJ_DEFAUT = { republic: 'Juge Sévère Lapeine' };

async function getJugeActuel(pays) {
  const titulaire = await getTitulairePoste('juge', null, pays);
  return titulaire || JUGE_PNJ_DEFAUT[pays] || 'Juge (poste vacant)';
}

async function ouvrirProposerGrace() {
  if (state.poste?.id !== 'min_just') { showToast('Réservé au Ministre de la Justice', '', false); return; }
  const condamnes = state.prisonniers?.filter(p => p.jourFin > state.day) || [];
  document.getElementById('postes-modal-title').textContent = 'Proposer une grâce au Président';
  let html = '<div style="padding:1rem">';
  if (condamnes.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucun condamné actuellement en détention.</div>';
  } else {
    condamnes.forEach((p, i) => {
      html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;display:flex;justify-content:space-between;align-items:center">';
      html += '<div><div style="font-family:Playfair Display,serif;font-size:.85rem;color:#e0d5b8">' + p.nom + '</div>';
      html += '<div style="font-size:.72rem;color:#a89870">' + p.raison + ' · libération prévue Jour ' + p.jourFin + '</div></div>';
      html += '<button onclick="confirmerPropositionGrace(' + i + ')" style="font-family:Bebas Neue,sans-serif;font-size:.7rem;padding:.25rem .6rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Proposer</button>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerPropositionGrace(idx) {
  const condamnes = state.prisonniers?.filter(p => p.jourFin > state.day) || [];
  const condamne = condamnes[idx];
  if (!condamne) return;
  document.getElementById('modal-postes')?.classList.remove('open');

  const pays = state.country || 'republic';
  const cout = 300;
  const montantVerse = typeof debiterCaisseBatimentPlafonne === 'function' ? await debiterCaisseBatimentPlafonne(pays, 'gouvernement-min_just', cout) : 0;
  if (montantVerse < cout) { showToast('Caisse insuffisante', 'La caisse du gouvernement ne peut pas couvrir les frais de dossier (' + cout + ' FR).', false); return; }

  await sbCreerDemandeGrace({ pays, nomCondamne: condamne.nom, raison: condamne.raison, jourFin: condamne.jourFin, proposePar: state.char?.name });

  const presidentNom = await getTitulairePoste('president');
  if (presidentNom && typeof sbSendMail === 'function') {
    await sbSendMail('Ministère de la Justice', presidentNom, 'Recommandation de grâce',
      'Le Ministre de la Justice recommande la grâce de ' + condamne.nom + ' (' + condamne.raison + '). Rendez-vous au palais pour traiter les demandes.', typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : '').catch(() => {});
  }
  showToast('Recommandation envoyée', 'Le Président a été notifié. -' + cout + ' FR (frais de dossier).', true, true);
  addJournalEntry('Grâce de ' + condamne.nom + ' recommandée au Président.', 'event-info');
}

async function ouvrirModalGracier() {
  if (state.poste?.id !== 'president') { showToast('Réservé au Président', '', false); return; }
  document.getElementById('postes-modal-title').textContent = 'Demandes de grâce en attente';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a8060;font-style:italic">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const pays = state.country || 'republic';
  const demandes = typeof sbGetDemandesGracePays === 'function' ? await sbGetDemandesGracePays(pays).catch(() => []) : [];

  let html = '<div style="padding:1rem">';
  if (demandes.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucune recommandation de grâce en attente.</div>';
  } else {
    demandes.forEach(d => {
      html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem">';
      html += '<div style="font-family:Playfair Display,serif;font-size:.85rem;color:#e0d5b8">' + d.nomCondamne + '</div>';
      html += '<div style="font-size:.72rem;color:#a89870">' + d.raison + ' · recommandé par ' + d.proposePar + '</div>';
      html += '<div style="display:flex;gap:.4rem;margin-top:.4rem">';
      html += '<button onclick="confirmerGrace(&quot;' + d.id + '&quot;,&quot;' + d.nomCondamne + '&quot;,true)" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.7rem;padding:.3rem;border:1px solid #4a8a4a;background:transparent;color:#6ab858;cursor:pointer">Accepter</button>';
      html += '<button onclick="confirmerGrace(&quot;' + d.id + '&quot;,&quot;' + d.nomCondamne + '&quot;,false)" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.7rem;padding:.3rem;border:1px solid #8a4a4a;background:transparent;color:#cc6a44;cursor:pointer">Refuser</button>';
      html += '</div></div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function confirmerGrace(demandeId, nomCondamne, accepte) {
  document.getElementById('modal-postes')?.classList.remove('open');
  await sbMajDemandeGrace(demandeId, accepte ? 'acceptee' : 'refusee');

  if (accepte) {
    const condamne = (state.prisonniers || []).find(p => p.nom === nomCondamne);
    if (condamne) condamne.jourFin = state.day;
    const popBonus = state.pop > 50 ? 5 : -2;
    state.pop = Math.min(100, state.pop + popBonus);
    updateUI();
    showToast('Grâce accordée', nomCondamne + ' est libéré(e). ' + (popBonus > 0 ? '+' : '') + popBonus + ' POP.', true, true);
    addExternalEvent('⚖️ GRÂCE PRÉSIDENTIELLE : ' + nomCondamne + ' a été gracié(e) par le Président.');
  } else {
    showToast('Grâce refusée', 'La recommandation du Ministre de la Justice a été rejetée.', false);
    addJournalEntry('Grâce de ' + nomCondamne + ' refusée par le Président.', 'event-info');
  }
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

async function debiterCitoyenPlafonne(nomCible, montantVise) {
  if (nomCible === state.char?.name) {
    const preleve = Math.min(state.arg || 0, montantVise);
    state.arg -= preleve;
    updateUI();
    return preleve;
  }
  if (typeof sbGet !== 'function') return 0;
  const rows = await sbGet('personnages', `name=eq.${encodeURIComponent(nomCible)}&select=arg`).catch(() => []);
  const argActuel = rows?.[0]?.arg ?? 0;
  const preleve = Math.min(argActuel, montantVise);
  await sbUpdate('personnages', `name=eq.${encodeURIComponent(nomCible)}`, { arg: argActuel - preleve }).catch(() => {});
  return preleve;
}

// =====================
// CIBLAGE FISCAL ÉTENDU — citoyens, clubs sportifs, entreprises, organisations
// =====================
function ouvrirChoixTypeCibleFiscale(action, titre) {
  document.getElementById('postes-modal-title').textContent = titre;
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Choisir le type de cible :</div>';
  const types = [
    { id: 'citoyen', label: 'Un citoyen', icon: 'ti-user' },
    { id: 'club_sportif', label: 'Un club sportif', icon: 'ti-ball-football' },
    { id: 'entreprise', label: 'Une entreprise', icon: 'ti-building-store' },
    { id: 'organisation', label: 'Une organisation', icon: 'ti-building-community' }
  ];
  types.forEach(t => {
    html += '<button onclick="ouvrirCiblageFiscalType(\'' + action + '\',\'' + t.id + '\',\'' + titre.replace(/'/g,"\\'") + '\')" style="display:block;width:100%;text-align:left;margin-bottom:.4rem;padding:.6rem .7rem;border:1px solid #2a2010;background:transparent;color:#c0b090;cursor:pointer;font-size:.82rem"><i class="ti ' + t.icon + '" style="margin-right:.4rem;color:#8a6a20"></i>' + t.label + '</button>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function ouvrirCiblageFiscalType(action, typeCible, titre) {
  const pays = state.country || 'republic';
  document.getElementById('postes-modal-title').textContent = titre;
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a8060;font-style:italic">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  let html = '<div style="padding:1rem">';

  if (typeCible === 'citoyen') {
    let joueurs = [];
    if (typeof sbListPersonnages === 'function') { try { joueurs = await sbListPersonnages() || []; } catch(e) {} }
    const myName = state.char?.name;
    const cibles = joueurs.filter(j => {
      const domicilePays = j.domicile?.country || j.country;
      return (domicilePays === pays || j.country === pays) && j.name !== myName;
    });
    if (cibles.length === 0) html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucun autre citoyen pour l\'instant.</div>';
    cibles.forEach(c => {
      const domicilie = (c.domicile?.country || c.country) === pays;
      html += '<div onclick="executerOrdreFiscalCible(\'' + action + '\',\'citoyen\',\'' + c.name + '\')" style="padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.3rem;cursor:pointer">';
      html += '<div style="font-size:.85rem;color:#e0d5b8">' + c.name + '</div><div style="font-size:.7rem;color:#a89870">' + (domicilie ? 'Domicilié(e)' : 'De passage') + '</div></div>';
    });
  } else if (typeCible === 'club_sportif') {
    const clubs = (CLUBS_SPORTIFS || []).filter(c => c.country === pays);
    clubs.forEach(c => {
      html += '<div onclick="executerOrdreFiscalCible(\'' + action + '\',\'club_sportif\',\'' + c.id + '\')" style="padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.3rem;cursor:pointer">';
      html += '<div style="font-size:.85rem;color:#e0d5b8">' + c.nom + '</div></div>';
    });
  } else if (typeCible === 'entreprise') {
    const id = getEntrepriseIdArmurerie(pays);
    html += '<div onclick="executerOrdreFiscalCible(\'' + action + '\',\'entreprise\',\'' + id + '\')" style="padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.3rem;cursor:pointer">';
    html += '<div style="font-size:.85rem;color:#e0d5b8">Armurerie</div></div>';
  } else if (typeCible === 'organisation') {
    const orgas = (state.organisations || []).filter(o => o.country === pays);
    if (orgas.length === 0) html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucune organisation connue pour l\'instant.</div>';
    orgas.forEach(o => {
      html += '<div onclick="executerOrdreFiscalCible(\'' + action + '\',\'organisation\',\'' + o.id + '\')" style="padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.3rem;cursor:pointer">';
      html += '<div style="font-size:.85rem;color:#e0d5b8">' + o.nom + '</div><div style="font-size:.7rem;color:#a89870">Chef : ' + (o.chef||'?') + '</div></div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

// Lit le solde actuel d'une cible, quel que soit son type
async function getSoldeCibleFiscale(typeCible, idCible) {
  const pays = state.country || 'republic';
  if (typeCible === 'citoyen') {
    if (idCible === state.char?.name) return state.arg || 0;
    const rows = await sbGet('personnages', `name=eq.${encodeURIComponent(idCible)}&select=arg`).catch(() => []);
    return rows?.[0]?.arg ?? 0;
  }
  if (typeCible === 'club_sportif') { const b = await chargerBudgetClub(idCible); return b?.caisse || 0; }
  if (typeCible === 'entreprise') { const e = await chargerEntreprise(idCible, () => defautArmurerie(pays)); return e?.caisse || 0; }
  if (typeCible === 'organisation') { const o = (state.organisations || []).find(x => x.id === idCible); return o?.caisse || 0; }
  return 0;
}

// Ajuste le solde d'une cible (delta positif ou negatif), quel que soit son type. Retourne le montant reel applique.
async function ajusterSoldeCibleFiscale(typeCible, idCible, delta) {
  const pays = state.country || 'republic';
  const soldeActuel = await getSoldeCibleFiscale(typeCible, idCible);
  const montantReel = delta >= 0 ? delta : -Math.min(soldeActuel, -delta);

  if (typeCible === 'citoyen') {
    if (idCible === state.char?.name) { state.arg = (state.arg||0) + montantReel; updateUI(); }
    else await sbUpdate('personnages', `name=eq.${encodeURIComponent(idCible)}`, { arg: soldeActuel + montantReel }).catch(() => {});
  } else if (typeCible === 'club_sportif') {
    await crediterBudgetClub(idCible, montantReel, montantReel >= 0 ? 'Subvention ministérielle' : 'Redressement fiscal');
  } else if (typeCible === 'entreprise') {
    const e = await chargerEntreprise(idCible, () => defautArmurerie(pays));
    e.caisse = (e.caisse||0) + montantReel;
    await sbSaveEntreprise(idCible, e).catch(() => {});
  } else if (typeCible === 'organisation') {
    const o = (state.organisations || []).find(x => x.id === idCible);
    if (o) { o.caisse = Math.max(0, (o.caisse||0) + montantReel); sauvegarderOrga(o); }
  }
  return montantReel;
}

function nomAffichageCible(typeCible, idCible) {
  if (typeCible === 'club_sportif') return getClub(idCible)?.nom || idCible;
  if (typeCible === 'entreprise') return 'l\'armurerie';
  if (typeCible === 'organisation') return (state.organisations || []).find(x => x.id === idCible)?.nom || idCible;
  return idCible;
}

async function executerOrdreFiscalCible(action, typeCible, idCible) {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const nomCible = nomAffichageCible(typeCible, idCible);

  if (action === 'ouvrir_enquete') {
    document.getElementById('modal-postes')?.classList.remove('open');
    const pays = state.country || 'republic';
    const cout = 400;
    const montantVerse = typeof debiterCaisseBatimentPlafonne === 'function' ? await debiterCaisseBatimentPlafonne(pays, 'gouvernement-min_just', cout) : 0;
    if (montantVerse < cout) { showToast('Caisse insuffisante', 'La caisse du gouvernement ne peut pas couvrir les frais d\'enquête (' + cout + ' FR).', false); return; }

    const reussite = Math.random() < 0.9;
    updateUI();
    if (reussite) {
      showToast('Enquête ouverte', 'Une enquête judiciaire est ouverte sur ' + nomCible + '. -' + cout + ' FR.', true, true);
      addJournalEntry('Enquête judiciaire ouverte sur ' + nomCible + ' (-' + cout + ' FR).', 'event-info');
      addExternalEvent('🔍 Le Ministère de la Justice ouvre une enquête sur ' + nomCible + '.');
      if (typeCible === 'citoyen' && typeof sbSendMail === 'function') sbSendMail('Ministère de la Justice', idCible, 'Enquête ouverte', 'Une enquête judiciaire a été ouverte à votre sujet.', typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : '').catch(() => {});
    } else {
      showToast('Enquête classée sans suite', 'Aucune charge retenue contre ' + nomCible + '. -' + cout + ' FR.', false);
      addJournalEntry('Enquête sur ' + nomCible + ' classée sans suite (-' + cout + ' FR).', 'event-info');
    }
    return;
  }

  if (action === 'redressement_fiscal') {
    document.getElementById('modal-postes')?.classList.remove('open');
    const montantVise = 2000;
    const montantPreleve = -(await ajusterSoldeCibleFiscale(typeCible, idCible, -montantVise));
    const budgetNat = await chargerBudgetNational(state.country);
    budgetNat.reserveJour = (budgetNat.reserveJour || 0) + montantPreleve;
    await sbSaveBudgetNational(state.country, budgetNat).catch(() => {});
    INDICES_NATIONAUX[state.country].IE = Math.max(0, INDICES_NATIONAUX[state.country].IE - 3);
    updateUI();
    showToast('Redressement', 'Redressement fiscal contre ' + nomCible + ' : ' + montantPreleve.toLocaleString('fr-FR') + ' ' + cur + ' prélevés pour le Trésor. -3 IE.', true, true);
    addJournalEntry('Redressement fiscal contre ' + nomCible + ' (+' + montantPreleve + ' FR pour l\'État).', 'event-info');
    if (typeCible === 'citoyen' && typeof sbSendMail === 'function') sbSendMail('Ministère des Finances', idCible, 'Redressement fiscal', 'Un redressement fiscal de ' + montantPreleve.toLocaleString('fr-FR') + ' ' + cur + ' vous a été notifié et prélevé.', typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : '').catch(() => {});
    return;
  }

  if (action === 'subvention') {
    document.getElementById('postes-modal-title').textContent = 'Montant de la subvention';
    const plafond = 5000;
    let html = '<div style="padding:1rem">';
    html += '<div style="font-size:.8rem;color:#8a8060;margin-bottom:.8rem">Bénéficiaire : ' + nomCible + '. Gratuit pour vous — prélevé sur la caisse du Palais du Gouvernement. Plafond : ' + plafond.toLocaleString('fr-FR') + ' ' + cur + '.</div>';
    html += '<input id="montant-subvention" type="number" min="1" max="' + plafond + '" value="500" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-size:.9rem;outline:none;box-sizing:border-box;margin-bottom:.8rem"/>';
    html += '<button onclick="confirmerSubventionMontant(\'' + typeCible + '\',\'' + idCible + '\',' + plafond + ')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.55rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Verser</button>';
    html += '</div>';
    document.getElementById('postes-body').innerHTML = html;
  }
}

async function confirmerSubventionMontant(typeCible, idCible, plafond) {
  const montant = Math.max(1, Math.min(plafond, parseInt(document.getElementById('montant-subvention')?.value || '0')));
  document.getElementById('modal-postes')?.classList.remove('open');
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const nomCible = nomAffichageCible(typeCible, idCible);
  const pays = state.country || 'republic';

  const montantVerse = typeof debiterCaisseBatimentPlafonne === 'function' ? await debiterCaisseBatimentPlafonne(pays, 'gouvernement-min_fin', montant) : 0;
  if (montantVerse <= 0) { showToast('Caisse insuffisante', 'Le budget du gouvernement ne peut pas financer cette subvention actuellement.', false); return; }

  await ajusterSoldeCibleFiscale(typeCible, idCible, montantVerse);
  INDICES_NATIONAUX[pays].IS = Math.min(100, INDICES_NATIONAUX[pays].IS + 3);
  updateUI();
  showToast('Subvention accordée', montantVerse.toLocaleString('fr-FR') + ' ' + cur + ' versés à ' + nomCible + '. +3 IS.', true, true);
  addJournalEntry('Subvention de ' + montantVerse + ' FR accordée à ' + nomCible + '.', 'event-good');
  if (typeCible === 'citoyen' && typeof sbSendMail === 'function') sbSendMail('Ministère des Finances', idCible, 'Subvention accordée', 'Vous avez reçu une subvention de ' + montantVerse.toLocaleString('fr-FR') + ' ' + cur + ' du Ministre des Finances.', typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : '').catch(() => {});
}

async function ouvrirCiblageFiscal(action, titre) {
  document.getElementById('postes-modal-title').textContent = titre;
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a8060;font-style:italic">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const pays = state.country || 'republic';
  let joueurs = [];
  if (typeof sbListPersonnages === 'function') {
    try { joueurs = await sbListPersonnages() || []; } catch(e) {}
  }
  const myName = state.char?.name;
  const cibles = joueurs.filter(j => {
    const domicilePays = j.domicile?.country || j.country;
    return (domicilePays === pays || j.country === pays) && j.name !== myName;
  });

  let html = '<div style="padding:1rem">';
  if (cibles.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucun autre citoyen domicilié ou présent sur le territoire pour l\'instant.</div>';
  } else {
    html += '<div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Citoyens domiciliés ou présents sur le territoire :</div>';
    cibles.forEach(c => {
      const domicilie = (c.domicile?.country || c.country) === pays;
      html += '<div onclick="executerOrdreContact(\'' + action + '\',\'' + c.name + '\')" style="padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.3rem;cursor:pointer">';
      html += '<div style="font-family:Playfair Display,serif;font-size:.85rem;color:#e0d5b8">' + c.name + '</div>';
      html += '<div style="font-size:.7rem;color:#a89870">' + (domicilie ? 'Domicilié(e)' : 'De passage') + (c.current_city ? ' · ' + c.current_city : '') + '</div></div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
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
    document.getElementById('modal-postes')?.classList.remove('open');
    debiterCitoyenPlafonne(nomCible, montant).then(async (montantPreleve) => {
      const budgetNat = await chargerBudgetNational(state.country);
      budgetNat.reserveJour = (budgetNat.reserveJour || 0) + montantPreleve;
      await sbSaveBudgetNational(state.country, budgetNat).catch(() => {});
      INDICES_NATIONAUX[state.country].IE = Math.max(0, INDICES_NATIONAUX[state.country].IE - 3);
      updateUI();
      showToast('Redressement', 'Redressement fiscal contre ' + nomCible + ' : ' + montantPreleve.toLocaleString('fr-FR') + ' ' + cur + ' prélevés pour le Trésor. -3 IE.', true, true);
      addJournalEntry('Redressement fiscal contre ' + nomCible + ' (+' + montantPreleve + ' FR pour l\'État).', 'event-info');
      if (typeof sbSendMail === 'function') sbSendMail('Ministère des Finances', nomCible, 'Redressement fiscal', 'Un redressement fiscal de ' + montantPreleve.toLocaleString('fr-FR') + ' ' + cur + ' vous a été notifié et prélevé par le Ministre des Finances.', typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : '').catch(() => {});
    });
  } else if (action === 'subvention') {
    const montant = 500;
    document.getElementById('modal-postes')?.classList.remove('open');
    const pays = state.country || 'republic';
    (async () => {
      const montantVerse = typeof debiterCaisseBatimentPlafonne === 'function'
        ? await debiterCaisseBatimentPlafonne(pays, 'gouvernement-min_fin', montant)
        : 0;
      if (montantVerse <= 0) { showToast('Caisse insuffisante', 'Le budget du gouvernement ne peut pas financer cette subvention actuellement.', false); return; }
      if (typeof sbAppliquerSalaire === 'function') await sbAppliquerSalaire(nomCible, montantVerse).catch(() => {});
      INDICES_NATIONAUX[pays].IS = Math.min(100, INDICES_NATIONAUX[pays].IS + 3);
      updateUI();
      showToast('Subvention accordée', montantVerse.toLocaleString('fr-FR') + ' ' + cur + ' versés à ' + nomCible + '. +3 IS.', true, true);
      addJournalEntry('Subvention de ' + montantVerse + ' FR accordée à ' + nomCible + '.', 'event-good');
      if (typeof sbSendMail === 'function') sbSendMail('Ministère des Finances', nomCible, 'Subvention accordée', 'Vous avez reçu une subvention de ' + montantVerse.toLocaleString('fr-FR') + ' ' + cur + ' du Ministre des Finances.', typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : '').catch(() => {});
    })();
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
  const titre = mode === 'annuler' ? 'Classer une plainte' : 'Gestion judiciaire';
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
      const pays = state.country || 'republic';
      const cout = 250;
      const montantVerse = typeof debiterCaisseBatimentPlafonne === 'function' ? await debiterCaisseBatimentPlafonne(pays, 'gouvernement-min_just', cout) : 0;
      if (montantVerse < cout) { showToast('Caisse insuffisante', 'La caisse du gouvernement ne peut pas couvrir les frais de dossier (' + cout + ' FR).', false); return; }

      affaire.status = 'annulee';
      if (typeof sbSavePlainte === 'function') await sbSavePlainte(affaire).catch(() => {});
      showToast('Plainte classée', 'La procédure a été classée. -' + cout + ' FR.', false, true);
      addJournalEntry('Classement d\'une plainte par le Ministre de la Justice (-' + cout + ' FR).', 'event-info');
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
  if (state.poste?.id !== 'min_def') { showToast('Réservé au Ministre de la Défense', '', false); return; }
  const empires = Object.entries(COUNTRIES).filter(([k]) => k !== state.country);
  document.getElementById('postes-modal-title').textContent = 'Opération de renseignement militaire';
  let html = '<div style="padding:1rem"><div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Empire à espionner. Le taux de réussite dépend de votre localisation actuelle, de la Sécurité Nationale des deux camps, et de la Perception/Intelligence du Ministre.</div>';
  empires.forEach(([k, co]) => {
    html += '<button onclick="confirmerRenseignement(\'' + k + '\',\'' + co.n.replace(/'/g,"\\'") + '\')" style="display:flex;align-items:center;gap:.5rem;width:100%;padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;color:#c0b090;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem;margin-bottom:.3rem"><i class="ti ' + co.icon + '" style="color:' + co.col + '"></i> ' + co.n + '</button>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerRenseignement(empireCible, nomCible) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const pays = state.country || 'republic';
  const cout = 500;
  const montantVerse = typeof debiterCaisseBatimentPlafonne === 'function' ? await debiterCaisseBatimentPlafonne(pays, 'caserne-militaire', cout) : 0;
  if (montantVerse < cout) { showToast('Budget insuffisant', 'La caisse de la caserne ne couvre pas le coût de l\'opération (' + cout + ' FR).', false); return; }

  // Choisir la section adverse ciblee AVANT le jet, puisque le jet depend des indices de son lieutenant
  const compagniesCible = await sbGetCompagnies(empireCible).catch(() => []);
  const sectionsPourvues = [];
  compagniesCible.forEach(c => (c.sections||[]).forEach(s => { if (s.lieutenantNom && s.soldats.length > 0) sectionsPourvues.push(s); }));
  if (sectionsPourvues.length === 0) { showToast('Opération annulée', 'Aucune section ennemie identifiable pour l\'instant.', false); return; }
  const section = sectionsPourvues[Math.floor(Math.random() * sectionsPourvues.length)];

  // Choisir un de nos propres lieutenants pour mener l'operation
  const compagniesNous = await sbGetCompagnies(pays).catch(() => []);
  const nosLieutenants = [];
  compagniesNous.forEach(c => (c.sections||[]).forEach(s => { if (s.lieutenantNom) nosLieutenants.push(s.lieutenantNom); }));
  if (nosLieutenants.length === 0) { showToast('Opération impossible', 'Aucun lieutenant disponible pour mener l\'opération.', false); return; }
  const notreLieutenantNom = nosLieutenants[Math.floor(Math.random() * nosLieutenants.length)];

  const rows1 = typeof sbGet === 'function' ? await sbGet('personnages', `name=eq.${encodeURIComponent(notreLieutenantNom)}&select=per,int`).catch(() => []) : [];
  const rows2 = typeof sbGet === 'function' ? await sbGet('personnages', `name=eq.${encodeURIComponent(section.lieutenantNom)}&select=per,int`).catch(() => []) : [];
  const notreLt = rows1?.[0] || { per:0, int:0 };
  const leurLt = rows2?.[0] || { per:0, int:0 };

  const base = state.country === empireCible ? 30 : 45;
  const notreScore = (INDICES_NATIONAUX[pays]?.ISN || 0) + (notreLt.per||0) + (notreLt.int||0);
  const leurScore = (INDICES_NATIONAUX[empireCible]?.ISN || 0) + (leurLt.per||0) + (leurLt.int||0);
  const tauxFinal = Math.max(5, Math.min(95, Math.round(base + (notreScore - leurScore) / 10)));

  const roll = Math.floor(Math.random() * 100) + 1;
  if (roll > tauxFinal) {
    showToast('Opération échouée', 'Aucune information exploitable n\'a pu être obtenue sur ' + nomCible + ' (taux : ' + tauxFinal + '%).', false);
    addJournalEntry('Opération de renseignement ratée contre ' + nomCible + '.', 'event-bad');
    if (typeof sbSendMail === 'function') sbSendMail('Ministère de la Défense', notreLieutenantNom, 'Opération de renseignement échouée', 'Votre opération contre ' + nomCible + ' n\'a rien donné.', typeof formatDateHeureJeu==='function'?formatDateHeureJeu():'').catch(()=>{});
    return;
  }

  const demiSection = [...section.soldats].sort(() => Math.random() - 0.5).slice(0, 12);
  let contenu = 'Section identifiée : Lieutenant ' + section.lieutenantNom + ' (' + nomCible + '). Indices du Lieutenant adverse — Perception : ' + (leurLt.per??'?') + ' · Intelligence : ' + (leurLt.int??'?') + '.<br><br>';
  demiSection.forEach(s => { contenu += s.matricule + ' — FOR ' + s.formation.force + ' · END ' + s.formation.endurance + ' · TIR ' + s.formation.tir + '<br>'; });

  if (typeof sbCreerRapportRenseignement === 'function') {
    await sbCreerRapportRenseignement({ pays, lieutenantNom: notreLieutenantNom, empireCible, nomCible, contenu, remonte: false });
  }
  if (typeof sbSendMail === 'function') {
    await sbSendMail('Ministère de la Défense', notreLieutenantNom, 'Rapport de renseignement — ' + nomCible,
      contenu + '<br><br><em>À vous de faire remonter ce rapport à votre Capitaine.</em>', typeof formatDateHeureJeu==='function'?formatDateHeureJeu():'').catch(()=>{});
  }
  showToast('Opération réussie', 'Le rapport a été transmis au Lieutenant ' + notreLieutenantNom + ' (taux : ' + tauxFinal + '%).', true, true);
  addJournalEntry('Opération de renseignement réussie contre ' + nomCible + ', transmise à ' + notreLieutenantNom + '.', 'event-good');
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

function ouvrirBanquetDiplomatique() {
  const contacts = state.contacts || [];
  if (contacts.length === 0) {
    showToast('Répertoire vide', 'Enregistrez des contacts pour pouvoir les inviter.', false);
    return;
  }
  document.getElementById('postes-modal-title').textContent = 'Banquet diplomatique';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.72rem;color:#8a8060;margin-bottom:.8rem">Sélectionnez 1 à 3 invités. Chacun a une chance de ne pas se présenter — un banquet déserté est un fiasco.</div>';
  html += '<div style="display:flex;flex-direction:column;gap:.4rem;margin-bottom:.8rem">';
  contacts.forEach((c, i) => {
    html += '<label style="display:flex;align-items:center;gap:.5rem;font-size:.8rem;color:#c0b090"><input type="checkbox" class="banquet-invite" value="' + c.name + '"/> ' + c.name + '</label>';
  });
  html += '</div>';
  html += '<button onclick="confirmerBanquetDiplomatique()" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.55rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Organiser le banquet (2000 FR)</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerBanquetDiplomatique() {
  const invites = Array.from(document.querySelectorAll('.banquet-invite:checked')).map(el => el.value);
  if (invites.length === 0) { showToast('Aucun invité sélectionné', '', false); return; }
  document.getElementById('modal-postes')?.classList.remove('open');

  if (!verifierBudgetInstitution('presidence')) return;

  const venus = invites.filter(() => Math.random() < 0.7); // 70% de chance de presence par invite
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  if (venus.length === invites.length) {
    state.pop = Math.min(100, state.pop + 15);
    state.inf = Math.min(100, state.inf + 12);
    state.moral = Math.min(100, state.moral + 5);
    INDICES_NATIONAUX[state.country].ID = Math.min(100, INDICES_NATIONAUX[state.country].ID + 8);
    updateUI();
    showToast('Banquet réussi !', 'Tous les invités sont venus. +15 POP +12 INF +5 Moral +8 ID.', true, true);
    addJournalEntry('Banquet diplomatique réussi — tous les invités présents.', 'event-good');
  } else if (venus.length > 0) {
    state.pop = Math.min(100, state.pop + 5);
    state.inf = Math.min(100, state.inf + 5);
    updateUI();
    showToast('Banquet mitigé', 'Seuls ' + venus.length + '/' + invites.length + ' invités sont venus. +5 POP +5 INF.', true);
    addJournalEntry('Banquet diplomatique mitigé (' + venus.length + '/' + invites.length + ' présents).', 'event-info');
  } else {
    state.pop = Math.max(0, state.pop - 25);
    state.inf = Math.max(0, state.inf - 20);
    state.moral = Math.max(0, state.moral - 10);
    updateUI();
    showToast('Fiasco !', 'Aucun invité ne s\'est présenté. -25 POP -20 INF -10 Moral.', false);
    addJournalEntry('Fiasco du banquet diplomatique — aucun invité présent.', 'event-bad');
    addExternalEvent('HUMILIATION : Le banquet diplomatique du Président s\'est tenu... sans aucun invité.');
  }
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

const DOSSIERS_GOUVERNEMENTAUX = [
  "Note confidentielle du Ministere des Finances : les reserves de change couvrent 4,2 mois d'importations, en baisse constante depuis 3 trimestres.",
  "Rapport classifie des services de renseignement : activite diplomatique inhabituelle detectee a la frontiere.",
  "Synthese interne : trois hauts fonctionnaires suspectes de conflits d'interets dans l'attribution de marches publics.",
  "Memo du cabinet : la cote de confiance du gouvernement aupres des grands industriels s'est degradee ce trimestre.",
  "Dossier sensible : un ancien ministre aurait conserve des documents classifies apres son depart.",
  "Rapport d'audit interne : des irregularites mineures ont ete relevees dans la gestion de deux budgets ministeriels."
];

function doConsulterDossiersGouv() {
  const dossier = DOSSIERS_GOUVERNEMENTAUX[Math.floor(Math.random() * DOSSIERS_GOUVERNEMENTAUX.length)];
  document.getElementById('postes-modal-title').textContent = 'Dossier confidentiel';
  const html = '<div style="padding:1rem;font-size:.85rem;color:#c0b090;line-height:1.6;font-style:italic">« ' + dossier + ' »</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
  state.inf = Math.min(100, (state.inf || 0) + 2);
  updateUI();
  addJournalEntry('Consultation d\'un dossier confidentiel du gouvernement. +2 INF.', 'event-info');
}

function doMobiliserPolice() {
  const options = [
    { id: 'blocus', label: 'Disperser un blocus routier', isn: 8, pop: -8 },
    { id: 'encadrer', label: 'Encadrer un rassemblement (prévention)', isn: 3, pop: -2 },
    { id: 'quartier', label: 'Renforcer un quartier sensible', isn: 5, pop: 0 },
    { id: 'reprimer', label: 'Réprimer un rassemblement par la force', isn: 10, pop: -15 }
  ];
  document.getElementById('postes-modal-title').textContent = "Faire intervenir les forces de l'ordre";
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.72rem;color:#8a8060;margin-bottom:.7rem">Chaque type d\'intervention a un impact different sur la securite nationale et la popularite.</div>';
  options.forEach(o => {
    html += '<button onclick="confirmerMobilisationPolice(\'' + o.id + '\',\'' + o.label.replace(/'/g,"\\'") + '\',' + o.isn + ',' + o.pop + ')" style="display:flex;justify-content:space-between;width:100%;margin-bottom:.4rem;padding:.6rem .7rem;border:1px solid #2a2010;background:transparent;color:#c0b090;cursor:pointer;font-size:.78rem">';
    html += '<span>' + o.label + '</span><span style="color:#8a8060">+' + o.isn + ' ISN · ' + (o.pop<=0?o.pop:'+'+o.pop) + ' POP</span></button>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerMobilisationPolice(id, label, isn, pop) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const pays = state.country || 'republic';
  if (INDICES_NATIONAUX[pays]) INDICES_NATIONAUX[pays].ISN = Math.min(100, INDICES_NATIONAUX[pays].ISN + isn);
  state.pop = Math.max(0, Math.min(100, state.pop + pop));
  updateUI();
  showToast('Intervention menée', label + ' — +' + isn + ' ISN, ' + (pop<=0?pop:'+'+pop) + ' POP.', pop >= 0, true);
  addJournalEntry('Intervention des forces de l\'ordre : ' + label + '.', pop < -5 ? 'event-bad' : 'event-info');
  addExternalEvent('🚔 Intervention des forces de l\'ordre : ' + label + '.');
}

async function doTraiterManifestations() {
  if (state.poste?.id !== 'min_int') { showToast('Réservé au Ministre de l\'Intérieur', '', false); return; }

  document.getElementById('postes-modal-title').textContent = 'Demandes de manifestation';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  await verifierAutoValidationManifestations(state.country);
  const demandes = typeof sbGetDemandesManifestationPays === 'function' ? await sbGetDemandesManifestationPays(state.country).catch(() => []) : [];

  let html = '<div style="padding:1rem">';
  if (demandes.length === 0) {
    html += '<div style="font-size:.85rem;color:#5a5040;font-style:italic">Aucune demande en attente.</div>';
  } else {
    const maintenant = Date.now();
    demandes.sort((a, b) => new Date(a.dateEvenement) - new Date(b.dateEvenement));
    demandes.forEach(d => {
      const heuresRestantes = Math.max(0, Math.round((new Date(d.dateEvenement) - maintenant) / (1000*60*60)));
      const heuresAvantAutoval = Math.max(0, heuresRestantes - DELAI_AUTOVALIDATION_H);
      html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.5rem">';
      html += '<div style="font-size:.8rem;color:#c0b090">' + d.orgaNom + '</div>';
      html += '<div style="font-size:.75rem;color:#8a8060;margin:.2rem 0">« ' + d.sujet + ' »</div>';
      html += '<div style="font-size:.7rem;color:#6a5a30">Prévue le ' + new Date(d.dateEvenement).toLocaleString('fr-FR') + ' · Auto-validée dans ' + heuresAvantAutoval + 'h</div>';
      html += '<div style="display:flex;gap:.4rem;margin-top:.4rem">';
      html += '<button onclick="traiterDemandeManifestation(&quot;' + d.id + '&quot;,true)" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.7rem;padding:.3rem;border:1px solid #2a4a20;background:transparent;color:#6a9a6a;cursor:pointer">Autoriser</button>';
      html += '<button onclick="traiterDemandeManifestation(&quot;' + d.id + '&quot;,false)" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.7rem;padding:.3rem;border:1px solid #4a2010;background:transparent;color:#cc4444;cursor:pointer">Interdire</button>';
      html += '</div></div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

const DELAI_EFFET_APRES_DEBUT_MIN = 90; // 1h30 apres le debut de l'evenement pour les manifestations autorisees

async function traiterDemandeManifestation(id, autorise) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const demande = await sbGetDemandeManifestationParId(id);
  if (!demande) return;

  await sbMajDemandeManifestation(id, autorise ? 'autorisee' : 'interdite', {});

  if (autorise) {
    showToast('Manifestation autorisée', demande.sujet + ' — effet connu 1h30 après le début.', true, true);
    addJournalEntry('Autorisation de manifestation accordée : ' + demande.sujet, 'event-good');
  } else {
    const pays = state.country || 'republic';
    if (INDICES_NATIONAUX[pays]) INDICES_NATIONAUX[pays].IS = Math.max(0, INDICES_NATIONAUX[pays].IS - 5);
    // Malus sur le Ministre de l'Interieur lui-meme (refuser un rassemblement legitime a un cout politique)
    const minIntNom = POSTES?.[pays]?.min_int?.titulaire;
    if (minIntNom) {
      if (minIntNom === state.char?.name) {
        state.pop = Math.max(0, (state.pop||0) - 8);
        state.dis = Math.max(0, (state.dis||0) - 5);
        updateUI();
      } else if (typeof sbGet === 'function') {
        const rows = await sbGet('personnages', `name=eq.${encodeURIComponent(minIntNom)}&select=pop,dis`).catch(() => []);
        const r = rows?.[0] || {};
        await sbUpdate('personnages', `name=eq.${encodeURIComponent(minIntNom)}`, {
          pop: Math.max(0, (r.pop??50) - 8), dis: Math.max(0, (r.dis??50) - 5)
        }).catch(() => {});
      }
    }
    updateUI();
    showToast('Manifestation interdite', demande.sujet + (demande.orgaType === 'sportive' ? ' — défaite par forfait (0-1).' : '') + ' -5 IS, -8 POP/-5 DIS pour le Ministre.', false);
    addJournalEntry('Interdiction de manifestation : ' + demande.sujet, 'event-bad');
    addExternalEvent('🚫 INTERDICTION : Le Ministère de l\'Intérieur interdit "' + demande.sujet + '".');
  }
}

// Verifie toutes les demandes en attente pour ce pays et auto-valide celles arrivees a 12h de l'evenement
async function verifierAutoValidationManifestations(pays) {
  if (typeof sbGetDemandesManifestationPays !== 'function') return;
  const demandes = await sbGetDemandesManifestationPays(pays).catch(() => []);
  const maintenant = Date.now();
  for (const d of demandes) {
    const heuresRestantes = (new Date(d.dateEvenement) - maintenant) / (1000*60*60);
    if (heuresRestantes <= DELAI_AUTOVALIDATION_H) {
      await sbMajDemandeManifestation(d.id, 'autorisee', {});
    }
  }
}

// Applique l'effet des manifestations autorisees dont l'evenement a debute depuis plus de 1h30, une seule fois
async function verifierEffetsManifestationsEcoulees(pays) {
  if (typeof sbGetDemandesManifestationAutorisees !== 'function') return;
  const demandes = await sbGetDemandesManifestationAutorisees(pays).catch(() => []);
  const maintenant = Date.now();
  for (const d of demandes) {
    if (d.effetApplique) continue;
    const minutesEcoulees = (maintenant - new Date(d.dateEvenement).getTime()) / (1000*60);
    if (minutesEcoulees >= DELAI_EFFET_APRES_DEBUT_MIN) {
      await appliquerEffetManifestationValidee(d);
      await sbMajDemandeManifestation(d.id, 'autorisee', { effetApplique: true });
    }
  }
}

async function doDementiOfficiel() {
  const postesAutorisesDementi = ['president', 'pm', 'min_int', 'min_fin', 'min_just', 'min_def', 'min_info', 'min_ae'];
  if (!postesAutorisesDementi.includes(state.poste?.id)) { showToast('Réservé au gouvernement', 'Seuls le président et les membres du gouvernement peuvent démentir officiellement.', false); return; }

  document.getElementById('postes-modal-title').textContent = 'Démenti officiel';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement des rumeurs en cours...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const postesGouvernement = ['president', 'pm', 'min_int', 'min_fin', 'min_just', 'min_def', 'min_info', 'min_ae'];
  const cibles = [state.char?.name].filter(Boolean);
  postesGouvernement.forEach(id => {
    const titulaire = POSTES?.[state.country]?.[id]?.titulaire;
    if (titulaire && !cibles.includes(titulaire)) cibles.push(titulaire);
  });

  let toutesRumeurs = [];
  for (const cible of cibles) {
    if (typeof sbGetRumeursActivesCible !== 'function') break;
    const rumeurs = await sbGetRumeursActivesCible(cible).catch(() => []);
    toutesRumeurs.push(...rumeurs);
  }

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.72rem;color:#8a8060;margin-bottom:.8rem">Rumeurs actives concernant le président et le gouvernement. Un démenti réussi efface la rumeur et rétablit la popularité perdue ; un échec double la perte.</div>';
  if (toutesRumeurs.length === 0) {
    html += '<div style="font-size:.8rem;color:#5a5040;font-style:italic">Aucune rumeur active pour l\'instant.</div>';
  } else {
    toutesRumeurs.forEach(r => {
      html += '<div style="border:1px solid #2a2010;padding:.6rem;margin-bottom:.5rem">';
      html += '<div style="font-size:.78rem;color:#c0b090">Concernant <b>' + r.cible + '</b></div>';
      html += '<div style="font-size:.72rem;color:#8a8060;font-style:italic;margin:.3rem 0">« ' + r.contenu.substring(0, 100) + (r.contenu.length > 100 ? '…' : '') + ' »</div>';
      html += '<button onclick="confirmerDementi(\'' + r.id + '\',\'' + r.cible + '\',' + (r.popPerdu||15) + ')" style="width:100%;padding:.4rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer;font-size:.72rem">Démentir cette rumeur</button>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function confirmerDementi(rumeurId, cible, popPerdu) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const roll = Math.floor(Math.random() * 100) + 1;
  const taux = 80; // successRate declare sur l'ordre

  if (roll <= taux) {
    if (typeof sbResoudreRumeur === 'function') await sbResoudreRumeur(rumeurId).catch(() => {});
    const nouveauPop = typeof sbAjusterPopJoueur === 'function' ? await sbAjusterPopJoueur(cible, popPerdu).catch(() => null) : null;
    if (cible === state.char?.name && nouveauPop !== null) { state.pop = nouveauPop; updateUI(); }
    showToast('Démenti réussi !', 'La rumeur est effacée, la popularité de ' + cible + ' est rétablie.', true, true);
    addJournalEntry('Démenti officiel réussi concernant ' + cible + '.', 'event-good');
    addExternalEvent('📢 La présidence dément officiellement les rumeurs concernant ' + cible + '.');
  } else {
    const nouveauPop = typeof sbAjusterPopJoueur === 'function' ? await sbAjusterPopJoueur(cible, -(popPerdu * 2)).catch(() => null) : null;
    if (cible === state.char?.name && nouveauPop !== null) { state.pop = nouveauPop; updateUI(); }
    showToast('Démenti raté !', 'L\'opération se retourne contre ' + cible + '. Perte de popularité doublée.', false);
    addJournalEntry('Démenti officiel raté, la situation s\'aggrave pour ' + cible + '.', 'event-bad');
    addExternalEvent('📢 Le démenti officiel de la présidence échoue, aggravant les soupçons sur ' + cible + '.');
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




// =====================
// VOTE DE CONFIANCE (declenchee par le PM, soumise a l'Assemblee Nationale)
// =====================
async function ouvrirDeclencherVoteConfiance() {
  if (state.poste?.id !== 'pm') {
    showToast('Accès refusé', 'Seul le Premier Ministre peut déclencher un vote de confiance.', false);
    return;
  }

  const voteExistant = (typeof sbGetVoteConfianceEnCours === 'function') ? await sbGetVoteConfianceEnCours(state.country) : null;
  if (voteExistant) {
    showToast('Vote déjà en cours', 'Un vote de confiance est déjà en cours à l\'Assemblée.', false);
    return;
  }

  document.getElementById('postes-modal-title').textContent = 'Déclencher un vote de confiance';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1rem">' +
    '<div style="font-size:.85rem;color:#c0b090;margin-bottom:1rem">Vous engagez la responsabilité de votre gouvernement devant l\'Assemblée Nationale. Les 25 députés voteront sous 48h. Si la confiance n\'est pas accordée (majorité simple requise), vous devrez démissionner immédiatement.</div>' +
    '<button onclick="confirmerDeclenchementVoteConfiance()" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">Engager la responsabilité du gouvernement</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerDeclenchementVoteConfiance() {
  document.getElementById('modal-postes').classList.remove('open');

  const vote = {
    id: 'voteconf-' + Date.now(),
    country: state.country,
    pm_nom: state.char?.name || 'Anonyme',
    jour_lancement: state.day || 1,
    jour_cloture: (state.day || 1) + 2, // 48h = 2 jours en jeu
    statut: 'en_cours',
    resultat: null
  };

  if (typeof sbCreerVoteConfiance === 'function') {
    await sbCreerVoteConfiance(vote).catch(() => {});
  }

  showToast('Vote de confiance déclenché', 'L\'Assemblée se prononcera dans 48h.', true, true);
  addJournalEntry('Vote de confiance déclenché par le Premier Ministre.', 'event-info');
  addExternalEvent('🏛 Le Premier Ministre ' + (state.char?.name||'') + ' engage la responsabilité de son gouvernement devant l\'Assemblée Nationale.', 'national');

  // Notifier tous les deputes PJ pour qu'ils puissent voter
  await notifierDeputesPourVoteConfiance(vote);
}

async function notifierDeputesPourVoteConfiance(vote) {
  if (typeof sbListPersonnages !== 'function' || typeof sbSendMail !== 'function') return;
  try {
    const joueurs = await sbListPersonnages() || [];
    const deputesPJ = joueurs.filter(j => j.country === vote.country && j.poste?.id?.startsWith('depute_'));

    const h = String(state.hour || 8).padStart(2,'0');
    const time = 'Jour ' + (state.day || 1) + ' · ' + h + 'h';
    const sujet = 'Vote de confiance — Assemblée Nationale';
    const corps = 'Le Premier Ministre ' + vote.pm_nom + ' engage la responsabilité de son gouvernement. ' +
      'Votez avant 48h.<br><br>' +
      '<button onclick="voterConfiance(&quot;' + vote.id + '&quot;,&quot;pour&quot;)" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;padding:.4rem .8rem;border:1px solid #2a4a20;background:transparent;color:#6a9a6a;cursor:pointer;margin-right:.5rem">✓ Confiance</button>' +
      '<button onclick="voterConfiance(&quot;' + vote.id + '&quot;,&quot;contre&quot;)" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;padding:.4rem .8rem;border:1px solid #4a2010;background:transparent;color:#cc4444;cursor:pointer">✗ Censure</button>';

    for (const dep of deputesPJ) {
      await sbSendMail('Assemblée Nationale', dep.name, sujet, corps, time).catch(() => {});
    }
  } catch(e) { console.warn('notifierDeputesPourVoteConfiance error', e); }
}

// Appelee quand un depute PJ clique Pour/Contre dans le mail
async function voterConfiance(voteId, choix) {
  document.getElementById('modal-pnj')?.classList.remove('open');

  if (!state.poste?.id?.startsWith('depute_')) {
    showToast('Accès refusé', 'Seuls les députés peuvent voter.', false);
    return;
  }

  const bulletin = {
    id: 'bulletin-' + Date.now() + '-' + Math.floor(Math.random()*1000),
    vote_id: voteId,
    votant: state.char?.name || 'Anonyme',
    choix
  };

  if (typeof sbDeposerBulletinConfiance === 'function') {
    await sbDeposerBulletinConfiance(bulletin).catch(() => {});
  }

  showToast('Vote enregistré', 'Votre vote (' + (choix === 'pour' ? 'Confiance' : 'Censure') + ') a été pris en compte.', true);
  addJournalEntry('Vous avez voté ' + (choix === 'pour' ? 'la confiance' : 'la censure') + ' au gouvernement.', 'event-info');
}

// Calcule et applique le resultat final d'un vote de confiance arrive a echeance (appele par le cron)
async function cloturerVoteConfiance(vote) {
  if (typeof sbListPersonnages !== 'function' || typeof sbGetBulletinsConfiance !== 'function') return;

  const joueurs = await sbListPersonnages().catch(() => []) || [];
  const deputesPJ = joueurs.filter(j => j.country === vote.country && j.poste?.id?.startsWith('depute_'));
  const bulletinsPJ = await sbGetBulletinsConfiance(vote.id).catch(() => []) || [];

  const isn = INDICES_NATIONAUX?.[vote.country]?.ISN || 30;
  const chanceContrePnj = Math.min(85, 30 + isn / 2);

  let pour = 0, contre = 0;
  const votantsPJ = new Set(bulletinsPJ.map(b => b.votant));

  bulletinsPJ.forEach(b => { if (b.choix === 'pour') pour++; else contre++; });

  // Sieges PNJ ou PJ n'ayant pas vote -> tirage aleatoire pondere par ISN
  const siegesRestants = 25 - votantsPJ.size;
  for (let i = 0; i < siegesRestants; i++) {
    if (Math.random() * 100 < chanceContrePnj) contre++; else pour++;
  }

  const confianceAccordee = pour > contre;
  const resultat = confianceAccordee ? 'confiance' : 'censure';

  if (typeof sbClorVoteConfiance === 'function') {
    await sbClorVoteConfiance(vote.id, 'termine', resultat).catch(() => {});
  }

  if (typeof addExternalEvent === 'function') {
    addExternalEvent('🏛 Vote de confiance : ' + pour + ' POUR / ' + contre + ' CONTRE. ' +
      (confianceAccordee ? 'Le gouvernement de ' + vote.pm_nom + ' obtient la confiance.' : 'Le gouvernement de ' + vote.pm_nom + ' est CENSURÉ et doit démissionner.'), 'national');
  }

  if (!confianceAccordee && typeof sbSendMail === 'function') {
    const time = 'Résultat du vote';
    await sbSendMail('Assemblée Nationale', vote.pm_nom, 'Motion de censure adoptée',
      'L\'Assemblée Nationale a retiré sa confiance à votre gouvernement (' + pour + ' pour / ' + contre + ' contre). Vous devez démissionner immédiatement.', time).catch(() => {});
    // Deposer une "censure en attente" pour forcer la demission a la prochaine connexion du PM
    if (typeof sbDeposerNominationPoste === 'function') {
      await sbDeposerNominationPoste({
        id: 'censure-' + Date.now(),
        destinataire: vote.pm_nom,
        poste_id: 'DEMISSION_FORCEE',
        poste_name: '',
        country: vote.country,
        traite: false
      }).catch(() => {});
    }
  }
}


// =====================
// DEMISSION D'UN POSTE
// =====================
async function demissionnerDuPoste() {
  if (!state.poste) {
    showToast('Aucun poste', 'Vous n\'occupez actuellement aucun poste.', false);
    return;
  }

  const ancienPosteNom = state.poste.name;
  state.poste = null;
  if (state.char) state.char.poste = null;
  updateUI();

  if (typeof sbSavePersonnage === 'function') {
    await sbSavePersonnage(state).catch(() => {});
  }

  showToast('Démission effective', 'Vous avez quitté le poste de ' + ancienPosteNom + '.', true, true);
  addJournalEntry('Démission du poste de ' + ancienPosteNom + '.', 'event-info');
  addExternalEvent('📜 ' + (state.char?.name || 'Quelqu\'un') + ' démissionne du poste de ' + ancienPosteNom + '.', 'national');
}

function ouvrirConfirmationDemission() {
  if (!state.poste) {
    showToast('Aucun poste', 'Vous n\'occupez actuellement aucun poste.', false);
    return;
  }
  document.getElementById('postes-modal-title').textContent = 'Démissionner';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1rem">' +
    '<div style="font-size:.85rem;color:#c0b090;margin-bottom:1rem">Êtes-vous sûr(e) de vouloir démissionner du poste de <strong>' + state.poste.name + '</strong> ? Cette action est immédiate et irréversible.</div>' +
    '<button onclick="demissionnerDuPoste();document.getElementById(\'modal-postes\').classList.remove(\'open\')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a3020;background:transparent;color:#cc4444;cursor:pointer">Confirmer la démission</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}


// =====================
// INDICES LOCAUX & BUDGET MUNICIPAL
// =====================
const CATEGORIES_BUDGET_MAIRIE = ['securite', 'associatif', 'ecoles', 'espaces_verts'];
const LABELS_BUDGET_MAIRIE = { securite: 'Sécurité', associatif: 'Associations sportives et culturelles', ecoles: 'Écoles', espaces_verts: 'Espaces verts' };
const LABELS_INDICES_LOCAUX = { securite: 'Sécurité locale', associatif: 'Vie associative & sportive', ecoles: 'Éducation', espaces_verts: 'Cadre de vie' };

function getVilleKey() {
  return (state.country || 'republic') + '_' + (state.currentCity || 'capitale');
}

async function chargerBudgetMunicipal() {
  if (typeof sbGetBudgetMunicipal !== 'function') return null;
  const key = getVilleKey();
  let data = await sbGetBudgetMunicipal(key).catch(() => null);
  if (!data) {
    data = {
      key,
      allocation: { securite: 25, associatif: 25, ecoles: 25, espaces_verts: 25 },
      indices: { securite: 50, associatif: 50, ecoles: 50, espaces_verts: 50 },
      derniereMaj: state.day || 1
    };
    if (typeof sbSaveBudgetMunicipal === 'function') await sbSaveBudgetMunicipal(key, data).catch(() => {});
  }
  return data;
}

// Fait deriver les indices locaux vers leur cible (allocation x2) au fil des jours ecoules.
// Appelee par n'importe quel joueur au chargement, comme le championnat et les elections.
async function verifierDeriveIndicesLocaux() {
  const data = await chargerBudgetMunicipal();
  if (!data) return null;
  const jour = state.day || 1;
  const joursEcoules = jour - (data.derniereMaj || jour);
  if (joursEcoules <= 0) return data;

  CATEGORIES_BUDGET_MAIRIE.forEach(cat => {
    const cibleIndice = Math.min(100, (data.allocation[cat] || 0) * 2);
    for (let i = 0; i < Math.min(joursEcoules, 30); i++) { // plafond de rattrapage pour eviter une boucle demesuree
      if (data.indices[cat] < cibleIndice) data.indices[cat] = Math.min(cibleIndice, data.indices[cat] + 2);
      else if (data.indices[cat] > cibleIndice) data.indices[cat] = Math.max(cibleIndice, data.indices[cat] - 2);
    }
  });
  data.derniereMaj = jour;
  if (typeof sbSaveBudgetMunicipal === 'function') await sbSaveBudgetMunicipal(data.key, data).catch(() => {});
  return data;
}

async function doConsulterIndicesLocaux() {
  document.getElementById('postes-modal-title').textContent = 'Indices locaux — ' + (WORLD[state.country]?.[state.currentCity]?.name || state.currentCity);
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const data = await verifierDeriveIndicesLocaux();
  if (!data) { document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a8060">Indisponible.</div>'; return; }

  let html = '<div style="padding:1rem">';
  CATEGORIES_BUDGET_MAIRIE.forEach(cat => {
    const val = data.indices[cat];
    const col = val >= 60 ? '#6ab858' : val >= 35 ? '#C9A84C' : '#cc6a44';
    html += '<div style="margin-bottom:.7rem">';
    html += '<div style="display:flex;justify-content:space-between;font-size:.78rem;color:#c0b090;margin-bottom:.2rem"><span>' + LABELS_INDICES_LOCAUX[cat] + '</span><span style="color:' + col + '">' + val + '/100</span></div>';
    html += '<div style="height:6px;background:#1a1208;border-radius:3px;overflow:hidden"><div style="height:100%;width:' + val + '%;background:' + col + '"></div></div>';
    html += '</div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function doRepartirBudgetMunicipal() {
  document.getElementById('postes-modal-title').textContent = 'Répartir le budget municipal';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const data = await chargerBudgetMunicipal();
  if (!data) return;

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;margin-bottom:.8rem">Répartissez 100% du budget entre les 4 postes. Un poste négligé verra son indice se dégrader avec le temps.</div>';
  CATEGORIES_BUDGET_MAIRIE.forEach(cat => {
    html += '<div style="margin-bottom:.6rem">';
    html += '<label style="font-size:.75rem;color:#c0b090;display:block;margin-bottom:.2rem">' + LABELS_BUDGET_MAIRIE[cat] + '</label>';
    html += '<input type="number" id="budget-' + cat + '" value="' + data.allocation[cat] + '" min="0" max="100" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;box-sizing:border-box"/>';
    html += '</div>';
  });
  html += '<div id="budget-total-warning" style="font-size:.72rem;color:#cc6a44;margin-bottom:.6rem"></div>';
  html += '<button onclick="confirmerRepartitionBudget(\'' + data.key + '\')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.55rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Valider la répartition</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function confirmerRepartitionBudget(key) {
  const allocation = {};
  let total = 0;
  CATEGORIES_BUDGET_MAIRIE.forEach(cat => {
    const v = Math.max(0, parseInt(document.getElementById('budget-' + cat)?.value || '0'));
    allocation[cat] = v;
    total += v;
  });
  if (total !== 100) {
    document.getElementById('budget-total-warning').textContent = 'Le total doit être exactement 100% (actuellement ' + total + '%).';
    return;
  }
  const data = await sbGetBudgetMunicipal(key).catch(() => null) || await chargerBudgetMunicipal();
  data.allocation = allocation;
  await sbSaveBudgetMunicipal(key, data).catch(() => {});
  document.getElementById('modal-postes').classList.remove('open');
  showToast('Budget mis à jour', 'La nouvelle répartition s\'appliquera progressivement.', true, true);
  addJournalEntry('Nouvelle répartition du budget municipal validée.', 'event-good');
}

// =====================
// SYSTEME MILITAIRE — guerre partagee, chaine de commandement, compagnies, detachements
// =====================
const EFFECTIF_SECTION = 24; // + 1 lieutenant = 25 par section
const NB_SECTIONS_COMPAGNIE = 4; // 100 hommes par compagnie
const COUT_COMPAGNIE = 20000; // preleve sur la caisse de la caserne

// ---- GUERRE PARTAGEE ----
async function ouvrirModalGuerreEmpire() {
  const pays = state.country || 'republic';
  const empires = Object.entries(COUNTRIES).filter(([k]) => k !== pays);
  document.getElementById('postes-modal-title').textContent = 'Déclarer la guerre';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a8060;font-style:italic">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const guerresActives = typeof sbGetGuerresPays === 'function' ? await sbGetGuerresPays(pays).catch(() => []) : [];

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#cc4444;font-style:italic;margin-bottom:.8rem">-20 POP +10 INF · Nation : -20 ID +15 ISN. Visible de tous, y compris l\'empire visé.</div>';
  empires.forEach(([k, co]) => {
    const guerre = guerresActives.find(g => (g.attaquant === pays && g.attaque === k) || (g.attaquant === k && g.attaque === pays));
    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.7rem;margin-bottom:.5rem;display:flex;align-items:center;justify-content:space-between">';
    html += '<div><div style="font-family:Playfair Display,serif;font-size:.85rem;color:#e0d5b8">' + co.n + '</div>';
    html += '<div style="font-size:.7rem;color:' + (guerre ? '#cc4444' : '#a89870') + '">' + (guerre ? 'En guerre depuis Jour ' + guerre.jourDebut : 'En paix') + '</div></div>';
    if (!guerre) {
      html += '<button onclick="confirmerGuerreEmpire(\'' + k + '\',\'' + co.n + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.7rem;padding:.3rem .7rem;border:1px solid #8a2020;background:transparent;color:#cc4444;cursor:pointer">Déclarer</button>';
    }
    html += '</div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function confirmerGuerreEmpire(empireId, empireName) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const pays = state.country || 'republic';
  await sbCreerGuerre({ attaquant: pays, attaque: empireId, jourDebut: state.day || 1, ceasefire: null });
  state.pop = Math.max(0, (state.pop||0) - 20);
  state.inf = Math.min(100, (state.inf||0) + 10);
  INDICES_NATIONAUX[pays].ID = Math.max(0, INDICES_NATIONAUX[pays].ID - 20);
  INDICES_NATIONAUX[pays].ISN = Math.min(100, INDICES_NATIONAUX[pays].ISN + 15);
  updateUI();
  addExternalEvent('⚔️ GUERRE DÉCLARÉE : ' + (COUNTRIES[pays]?.n||'') + ' déclare la guerre à ' + empireName + ' !');
  showToast('Guerre déclarée !', 'Conflit ouvert avec ' + empireName + '. Visible par tous.', false, true);
  addJournalEntry('Guerre déclarée contre ' + empireName + '.', 'event-bad');
}

// Etape 1 : le MAE propose une treve a son homologue
async function ouvrirProposerTreve() {
  if (state.poste?.id !== 'min_ae') { showToast('Réservé au Ministre des Affaires Étrangères', '', false); return; }
  const pays = state.country || 'republic';
  const guerres = await sbGetGuerresPays(pays).catch(() => []);
  const enCours = guerres.filter(g => g.statut === 'active' && !g.ceasefire);
  document.getElementById('postes-modal-title').textContent = 'Proposer une trêve';
  let html = '<div style="padding:1rem">';
  if (enCours.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucun conflit actif nécessitant une trêve.</div>';
  } else {
    enCours.forEach(g => {
      const adversaire = g.attaquant === pays ? g.attaque : g.attaquant;
      html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;display:flex;justify-content:space-between;align-items:center">';
      html += '<div style="font-size:.85rem;color:#e0d5b8">' + (COUNTRIES[adversaire]?.n||adversaire) + '</div>';
      html += '<button onclick="confirmerPropositionTreve(\'' + g.id + '\',\'' + adversaire + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.7rem;padding:.3rem .6rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Proposer</button>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerPropositionTreve(guerreId, adversaire) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const maeAdversaire = await getTitulairePoste('min_ae', null, adversaire);
  if (typeof sbSendMail === 'function') {
    await sbSendMail('Ministère des Affaires Étrangères', maeAdversaire || 'PNJ-MAE',
      'Proposition de trêve', (state.char?.name||'Le Ministre') + ' propose une trêve. Répondez pour l\'accepter.',
      typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : '').catch(() => {});
  }
  await sbMajGuerre(guerreId, { ceasefire: { proposePar: state.char?.name, accepteePar: null, actifPar: {} } });
  showToast('Trêve proposée', 'En attente de la réponse de l\'homologue.', true, true);
  addJournalEntry('Trêve proposée à ' + (COUNTRIES[adversaire]?.n||adversaire) + '.', 'event-info');
}

async function accepterTreve(guerreId) {
  await sbMajGuerre(guerreId, { ceasefire: { accepteePar: state.char?.name, actifPar: {} } });
  showToast('Trêve acceptée', 'Chaque Ministre de la Défense doit maintenant activer le cessez-le-feu de son côté.', true, true);
  addExternalEvent('🕊️ Une trêve a été négociée entre les deux Ministères des Affaires Étrangères.');
}

// Etape 2 : chaque MG active independamment le cessez-le-feu de son cote
async function ouvrirActiverCessezLeFeu() {
  if (state.poste?.id !== 'min_def') { showToast('Réservé au Ministre de la Défense', '', false); return; }
  const pays = state.country || 'republic';
  const guerres = await sbGetGuerresPays(pays).catch(() => []);
  const negociees = guerres.filter(g => g.ceasefire?.accepteePar);
  document.getElementById('postes-modal-title').textContent = 'Activer le cessez-le-feu';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.75rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Chaque camp doit activer le cessez-le-feu de son côté — un décalage entre les deux est possible et source de confusion.</div>';
  if (negociees.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucune trêve négociée par la diplomatie pour l\'instant.</div>';
  } else {
    negociees.forEach(g => {
      const adversaire = g.attaquant === pays ? g.attaque : g.attaquant;
      const dejaActif = g.ceasefire?.actifPar?.[pays];
      html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;display:flex;justify-content:space-between;align-items:center">';
      html += '<div style="font-size:.85rem;color:#e0d5b8">' + (COUNTRIES[adversaire]?.n||adversaire) + '<div style="font-size:.7rem;color:#a89870">' + (g.ceasefire?.actifPar?.[adversaire] ? 'Adversaire : activé' : 'Adversaire : pas encore activé') + '</div></div>';
      html += dejaActif
        ? '<span style="font-size:.7rem;color:#6ab858">Activé de votre côté</span>'
        : '<button onclick="confirmerActivationCessezLeFeu(\'' + g.id + '\',\'' + adversaire + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.7rem;padding:.3rem .6rem;border:1px solid #4a8a4a;background:transparent;color:#6ab858;cursor:pointer">Activer</button>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerActivationCessezLeFeu(guerreId, adversaire) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const pays = state.country || 'republic';
  const rows = await sbGet('guerres', `id=eq.${encodeURIComponent(guerreId)}`);
  const g = rows?.[0]?.data;
  if (!g) return;
  const actifPar = { ...(g.ceasefire?.actifPar || {}), [pays]: true };
  const tousActifs = actifPar[g.attaquant] && actifPar[g.attaque];
  await sbMajGuerre(guerreId, { ceasefire: { ...g.ceasefire, actifPar }, statut: tousActifs ? 'terminee' : 'active' });

  INDICES_NATIONAUX[pays].ID = Math.min(100, INDICES_NATIONAUX[pays].ID + 10);
  updateUI();
  if (tousActifs) {
    showToast('Cessez-le-feu total !', 'Les deux camps ont activé le cessez-le-feu. Le conflit est terminé.', true, true);
    addExternalEvent('🕊️ Cessez-le-feu total entre ' + (COUNTRIES[pays]?.n) + ' et ' + (COUNTRIES[adversaire]?.n) + '.');
  } else {
    showToast('Cessez-le-feu activé de votre côté', 'L\'adversaire n\'a pas encore fait de même — confusion sur le terrain probable.', true, true);
    addExternalEvent('⚠️ ' + (COUNTRIES[pays]?.n) + ' active unilatéralement le cessez-le-feu avec ' + (COUNTRIES[adversaire]?.n) + ' — l\'autre camp n\'a pas suivi.');
  }
}

function estEnGuerreAvec(pays1, pays2, guerresCache) {
  return (guerresCache || []).some(g => g.statut === 'active' && ((g.attaquant === pays1 && g.attaque === pays2) || (g.attaquant === pays2 && g.attaque === pays1)));
}

// ---- CHAINE DE COMMANDEMENT ----
async function ouvrirNommerCommandant() {
  if (state.poste?.id !== 'min_def') { showToast('Réservé au Ministre de la Défense', '', false); return; }
  const pays = state.country || 'republic';
  const habitants = typeof listerHabitantsEligibles === 'function' ? await listerHabitantsEligibles('commandant') : [];
  document.getElementById('postes-modal-title').textContent = 'Nommer le Commandant de la Caserne';
  let html = '<div style="padding:1rem">';
  if (habitants.length === 0) {
    html += '<div style="font-size:.85rem;color:#5a5040">Aucun habitant éligible trouvé.</div>';
  } else {
    html += '<select id="nomme-commandant" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-size:.85rem;outline:none;margin-bottom:.8rem">';
    habitants.forEach(h => html += '<option value="' + h.name + '">' + h.name + '</option>');
    html += '</select>';
    html += '<button onclick="envoyerNominationCommandant()" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Envoyer la nomination</button>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function envoyerNominationCommandant() {
  const destinataire = document.getElementById('nomme-commandant')?.value;
  if (!destinataire) return;
  document.getElementById('modal-postes')?.classList.remove('open');
  const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : '';
  const corps = (state.char?.name||'Le Ministre') + ' vous propose le poste de <strong>Commandant de la Caserne</strong>.<br><br>' +
    '<button onclick="accepterNominationPosteNomme(\'commandant\',\'\',\'' + state.country + '\',\'' + (state.char?.name||'').replace(/'/g,'') + '\')" ' +
    'style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">✓ Accepter le poste</button>';
  if (typeof sbSendMail === 'function') await sbSendMail(state.char?.name || 'Anonyme', destinataire, 'Nomination au poste de Commandant', corps, time).catch(() => {});
  showToast('Nomination envoyée', destinataire + ' a reçu votre proposition.', true, true);
}

async function ouvrirNommerCapitaine() {
  if (state.poste?.id !== 'commandant') { showToast('Réservé au Commandant de la Caserne', '', false); return; }
  const pays = state.country || 'republic';
  const compagnies = await sbGetCompagnies(pays).catch(() => []);
  const dispo = compagnies.filter(c => !c.capitaineNom);
  if (dispo.length === 0) { showToast('Aucune compagnie disponible', 'Toutes les compagnies ont déjà un capitaine, ou aucune n\'existe.', false); return; }
  const habitants = typeof listerHabitantsEligibles === 'function' ? await listerHabitantsEligibles('capitaine') : [];

  document.getElementById('postes-modal-title').textContent = 'Nommer un Capitaine';
  let html = '<div style="padding:1rem">';
  html += '<label style="font-size:.72rem;color:#8a8060;display:block;margin-bottom:.3rem">Compagnie</label>';
  html += '<select id="nomme-capitaine-compagnie" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-size:.85rem;outline:none;margin-bottom:.6rem">';
  dispo.forEach(c => html += '<option value="' + c.id + '">' + c.id + '</option>');
  html += '</select>';
  html += '<label style="font-size:.72rem;color:#8a8060;display:block;margin-bottom:.3rem">Candidat</label>';
  html += '<select id="nomme-capitaine-nom" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-size:.85rem;outline:none;margin-bottom:.8rem">';
  habitants.forEach(h => html += '<option value="' + h.name + '">' + h.name + '</option>');
  html += '</select>';
  html += '<button onclick="envoyerNominationCapitaine()" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Envoyer la nomination</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function envoyerNominationCapitaine() {
  const compagnieId = document.getElementById('nomme-capitaine-compagnie')?.value;
  const destinataire = document.getElementById('nomme-capitaine-nom')?.value;
  if (!compagnieId || !destinataire) return;
  document.getElementById('modal-postes')?.classList.remove('open');
  const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : '';
  const corps = (state.char?.name||'Le Commandant') + ' vous propose le poste de <strong>Capitaine</strong> de la compagnie ' + compagnieId + '.<br><br>' +
    '<button onclick="accepterNominationCapitaine(\'' + compagnieId + '\',\'' + (state.char?.name||'').replace(/'/g,'') + '\')" ' +
    'style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">✓ Accepter le poste</button>';
  if (typeof sbSendMail === 'function') await sbSendMail(state.char?.name || 'Anonyme', destinataire, 'Nomination au poste de Capitaine', corps, time).catch(() => {});
  showToast('Nomination envoyée', '', true, true);
}

async function accepterNominationCapitaine(compagnieId, nommeurNom) {
  const compagnie = (await sbGetCompagnies(state.country).catch(() => [])).find(c => c.id === compagnieId);
  if (!compagnie) return;
  compagnie.capitaineNom = state.char?.name;
  await sbSaveCompagnie(compagnieId, compagnie);
  state.poste = { id: 'capitaine', name: 'Capitaine', compagnieId };
  if (state.char) state.char.poste = state.poste;
  updateUI();
  showToast('Poste accepté !', 'Vous êtes désormais Capitaine de la compagnie ' + compagnieId + '.', true, true);
  addExternalEvent('🎖 ' + (state.char?.name||'Un officier') + ' est nommé Capitaine.');
}

async function ouvrirNommerLieutenant() {
  if (state.poste?.id !== 'capitaine') { showToast('Réservé à un Capitaine', '', false); return; }
  const compagnie = (await sbGetCompagnies(state.country).catch(() => [])).find(c => c.id === state.poste.compagnieId);
  if (!compagnie) return;
  const dispo = (compagnie.sections || []).filter(s => !s.lieutenantNom);
  if (dispo.length === 0) { showToast('Aucune section disponible', 'Toutes les sections de votre compagnie ont déjà un lieutenant.', false); return; }
  const habitants = typeof listerHabitantsEligibles === 'function' ? await listerHabitantsEligibles('lieutenant') : [];

  document.getElementById('postes-modal-title').textContent = 'Nommer un Lieutenant';
  let html = '<div style="padding:1rem">';
  html += '<label style="font-size:.72rem;color:#8a8060;display:block;margin-bottom:.3rem">Section</label>';
  html += '<select id="nomme-lieutenant-section" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-size:.85rem;outline:none;margin-bottom:.6rem">';
  dispo.forEach(s => html += '<option value="' + s.id + '">' + s.id + '</option>');
  html += '</select>';
  html += '<label style="font-size:.72rem;color:#8a8060;display:block;margin-bottom:.3rem">Candidat</label>';
  html += '<select id="nomme-lieutenant-nom" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-size:.85rem;outline:none;margin-bottom:.8rem">';
  habitants.forEach(h => html += '<option value="' + h.name + '">' + h.name + '</option>');
  html += '</select>';
  html += '<button onclick="envoyerNominationLieutenant(\'' + compagnie.id + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Envoyer la nomination</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function envoyerNominationLieutenant(compagnieId) {
  const sectionId = document.getElementById('nomme-lieutenant-section')?.value;
  const destinataire = document.getElementById('nomme-lieutenant-nom')?.value;
  if (!sectionId || !destinataire) return;
  document.getElementById('modal-postes')?.classList.remove('open');
  const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : '';
  const corps = (state.char?.name||'Le Capitaine') + ' vous propose le poste de <strong>Lieutenant</strong> de la section ' + sectionId + '.<br><br>' +
    '<button onclick="accepterNominationLieutenant(\'' + compagnieId + '\',\'' + sectionId + '\')" ' +
    'style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">✓ Accepter le poste</button>';
  if (typeof sbSendMail === 'function') await sbSendMail(state.char?.name || 'Anonyme', destinataire, 'Nomination au poste de Lieutenant', corps, time).catch(() => {});
  showToast('Nomination envoyée', '', true, true);
}

async function accepterNominationLieutenant(compagnieId, sectionId) {
  const compagnie = (await sbGetCompagnies(state.country).catch(() => [])).find(c => c.id === compagnieId);
  if (!compagnie) return;
  const section = (compagnie.sections || []).find(s => s.id === sectionId);
  if (!section) return;
  section.lieutenantNom = state.char?.name;
  await sbSaveCompagnie(compagnieId, compagnie);
  state.poste = { id: 'lieutenant', name: 'Lieutenant', compagnieId, sectionId };
  if (state.char) state.char.poste = state.poste;
  updateUI();
  showToast('Poste accepté !', 'Vous êtes désormais Lieutenant de la section "' + (state.char?.name) + '".', true, true);
  addExternalEvent('🎖 ' + (state.char?.name||'Un officier') + ' est nommé Lieutenant.');
}

// ---- RECRUTEMENT (a la compagnie) ----
const COEF_ARME_MILITAIRE = { corps_a_corps: 1, arme_de_poing: 2.5, mitraillette: 4 };
const PA_MAX_SOLDAT = 12;
const PA_BASE_ROUND = 2;
const CAP_ENTRAINEMENT_PAR_SESSION = 12;

function genererMatriculesSection(numeroSection) {
  const now = new Date();
  const aaaamm = now.getFullYear() + String(now.getMonth() + 1).padStart(2, '0');
  const ss = String(numeroSection).padStart(2, '0');
  return Array.from({ length: EFFECTIF_SECTION }, (_, i) => aaaamm + '-' + ss + '-' + String(i + 1).padStart(3, '0'));
}

function creerSoldatsSection(numeroSection) {
  return genererMatriculesSection(numeroSection).map(matricule => ({
    matricule, formation: { force: 0, endurance: 0, tir: 0 }, arme: 'corps_a_corps',
    buildingId: 'caserne-militaire', roomId: 'corps_garde', pa: PA_MAX_SOLDAT
  }));
}

async function doRecruterCompagnie() {
  if (state.poste?.id !== 'min_def') { showToast('Réservé au Ministre de la Défense', '', false); return; }
  const pays = state.country || 'republic';
  const montantVerse = typeof debiterCaisseBatimentPlafonne === 'function' ? await debiterCaisseBatimentPlafonne(pays, 'caserne-militaire', COUT_COMPAGNIE) : 0;
  if (montantVerse < COUT_COMPAGNIE) { showToast('Budget insuffisant', 'La caisse de la caserne ne couvre pas le coût d\'une compagnie (' + COUT_COMPAGNIE.toLocaleString('fr-FR') + ' FR).', false); return; }

  const id = 'compagnie-' + pays + '-' + Date.now();
  const sections = Array.from({ length: NB_SECTIONS_COMPAGNIE }, (_, i) => ({
    id: id + '-s' + (i + 1), numero: i + 1, lieutenantNom: null,
    soldats: creerSoldatsSection(i + 1)
  }));
  await sbSaveCompagnie(id, { id, pays, capitaineNom: null, sections });
  showToast('Compagnie recrutée !', '100 soldats (4 sections) rejoignent la caserne. -' + COUT_COMPAGNIE.toLocaleString('fr-FR') + ' FR.', true, true);
  addJournalEntry('Recrutement d\'une nouvelle compagnie (' + COUT_COMPAGNIE + ' FR).', 'event-good');
}

// Recompletement d'une seule section vidée (moins cher qu'une compagnie complète)
const COUT_SECTION = Math.round(COUT_COMPAGNIE / NB_SECTIONS_COMPAGNIE);
async function doRecruterSection(compagnieId, sectionId) {
  if (state.poste?.id !== 'commandant') { showToast('Réservé au Commandant', '', false); return; }
  const pays = state.country || 'republic';
  const compagnie = (await sbGetCompagnies(pays).catch(() => [])).find(c => c.id === compagnieId);
  const section = compagnie?.sections.find(s => s.id === sectionId);
  if (!section || section.soldats.length > 0) { showToast('Section non vide ou introuvable', '', false); return; }

  const montantVerse = await debiterCaisseBatimentPlafonne(pays, 'caserne-militaire', COUT_SECTION);
  if (montantVerse < COUT_SECTION) { showToast('Budget insuffisant', 'La caisse de la caserne ne couvre pas le recomplètement (' + COUT_SECTION.toLocaleString('fr-FR') + ' FR).', false); return; }

  section.soldats = creerSoldatsSection(section.numero);
  await sbSaveCompagnie(compagnieId, compagnie);
  showToast('Section recomplétée', '24 nouvelles recrues sans expérience rejoignent la section.', true, true);
  addJournalEntry('Section ' + sectionId + ' recomplétée (-' + COUT_SECTION + ' FR).', 'event-info');
}

// ---- DETACHEMENTS DE SOLDATS ----
// Recupere le detachement present dans la piece courante pour la section du lieutenant connecte
function getSectionDuLieutenant(compagnie) {
  return (compagnie?.sections || []).find(s => s.lieutenantNom === state.char?.name);
}

const ROOM_AVEC_LIEUTENANT = '__avec_lieutenant__';

async function doGererDetachement() {
  if (state.poste?.id !== 'lieutenant') { showToast('Réservé à un Lieutenant', '', false); return; }
  const compagnie = (await sbGetCompagnies(state.country).catch(() => [])).find(c => c.id === state.poste.compagnieId);
  const section = getSectionDuLieutenant(compagnie);
  if (!section) return;

  const ici = section.soldats.filter(s => s.buildingId === state.currentBuilding && s.roomId === state.currentRoom).length;
  const avecMoi = section.soldats.filter(s => s.roomId === ROOM_AVEC_LIEUTENANT).length;
  const ailleurs = section.soldats.length - ici - avecMoi;

  document.getElementById('postes-modal-title').textContent = 'Gérer mon détachement';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#8a8060;margin-bottom:.8rem">Ici : ' + ici + ' · Avec vous (en déplacement) : ' + avecMoi + ' · Ailleurs : ' + ailleurs + ' soldats.</div>';
  html += '<label style="font-size:.72rem;color:#8a8060;display:block;margin-bottom:.3rem">Nombre à déposer ici (depuis votre groupe)</label>';
  html += '<input id="nb-deposer" type="number" min="0" max="' + avecMoi + '" value="0" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-size:.85rem;outline:none;box-sizing:border-box;margin-bottom:.6rem"/>';
  html += '<button onclick="deposerSoldats(\'' + compagnie.id + '\',\'' + section.id + '\')" style="width:100%;margin-bottom:.8rem;font-family:Bebas Neue,sans-serif;font-size:.75rem;padding:.5rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Déposer</button>';
  html += '<label style="font-size:.72rem;color:#8a8060;display:block;margin-bottom:.3rem">Nombre à récupérer ici (rejoint votre groupe)</label>';
  html += '<input id="nb-recuperer" type="number" min="0" max="' + ici + '" value="0" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-size:.85rem;outline:none;box-sizing:border-box;margin-bottom:.6rem"/>';
  html += '<button onclick="recupererSoldats(\'' + compagnie.id + '\',\'' + section.id + '\')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.75rem;padding:.5rem;border:1px solid #4a6a8a;background:transparent;color:#5a8ad0;cursor:pointer">Récupérer</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function deposerSoldats(compagnieId, sectionId) {
  const nb = parseInt(document.getElementById('nb-deposer')?.value || '0');
  document.getElementById('modal-postes')?.classList.remove('open');
  if (nb <= 0) return;
  const compagnie = (await sbGetCompagnies(state.country).catch(() => [])).find(c => c.id === compagnieId);
  const section = compagnie?.sections.find(s => s.id === sectionId);
  if (!section) return;

  const disponibles = section.soldats.filter(s => s.roomId === ROOM_AVEC_LIEUTENANT);
  if (disponibles.length < nb) { showToast('Pas assez de soldats avec vous', '', false); return; }
  disponibles.slice(0, nb).forEach(s => { s.buildingId = state.currentBuilding; s.roomId = state.currentRoom; });

  await sbSaveCompagnie(compagnieId, compagnie);
  showToast('Soldats déposés', nb + ' soldats de la section "' + section.lieutenantNom + '" restent ici.', true, true);
  if (typeof verifierCombatAutomatique === 'function') verifierCombatAutomatique(state.currentBuilding, state.currentRoom).catch(() => {});
}

async function recupererSoldats(compagnieId, sectionId) {
  const nb = parseInt(document.getElementById('nb-recuperer')?.value || '0');
  document.getElementById('modal-postes')?.classList.remove('open');
  if (nb <= 0) return;
  const compagnie = (await sbGetCompagnies(state.country).catch(() => [])).find(c => c.id === compagnieId);
  const section = compagnie?.sections.find(s => s.id === sectionId);
  const ici = section?.soldats.filter(s => s.buildingId === state.currentBuilding && s.roomId === state.currentRoom) || [];
  if (ici.length < nb) { showToast('Effectif insuffisant ici', '', false); return; }
  ici.slice(0, nb).forEach(s => { s.buildingId = null; s.roomId = ROOM_AVEC_LIEUTENANT; });
  await sbSaveCompagnie(compagnieId, compagnie);
  showToast('Soldats récupérés', nb + ' soldats rejoignent votre groupe.', true, true);
}

// Retourne le libelle a afficher dans une piece pour un detachement present, ou null
async function getAffichageDetachementPiece(pays, buildingId, roomId) {
  const compagnies = await sbGetCompagnies(pays).catch(() => []);
  for (const c of compagnies) {
    for (const s of (c.sections || [])) {
      const presents = s.soldats.filter(sol => sol.buildingId === buildingId && sol.roomId === roomId);
      if (presents.length > 0) return { nom: 'Soldats section "' + (s.lieutenantNom || '?') + '"', lieutenantNom: s.lieutenantNom, nombre: presents.length, mission: s.mission, sectionId: s.id, compagnieId: c.id, pays: c.pays };
    }
  }
  return null;
}

// ---- MISSIONS DES DETACHEMENTS ----
const MISSIONS_DETACHEMENT = [
  { id: 'bloquer_acces', label: 'Bloquer l\'accès au bâtiment' },
  { id: 'securiser', label: 'Sécuriser la pièce (malus actes illégaux)' },
  { id: 'assassiner', label: 'Assassiner toute personne entrant' },
  { id: 'arreter', label: 'Arrêter toute personne entrant' },
  { id: 'surveiller', label: 'Surveiller (rapport passif)' },
  { id: 'escorter', label: 'Escorter une personne précise' }
];

async function doAssignerMission() {
  if (state.poste?.id !== 'lieutenant') { showToast('Réservé à un Lieutenant', '', false); return; }
  const compagnie = (await sbGetCompagnies(state.country).catch(() => [])).find(c => c.id === state.poste.compagnieId);
  const section = getSectionDuLieutenant(compagnie);
  const iciCount = section?.soldats.filter(s => s.buildingId === state.currentBuilding && s.roomId === state.currentRoom).length || 0;
  if (iciCount <= 0) { showToast('Aucun soldat ici', '', false); return; }

  document.getElementById('postes-modal-title').textContent = 'Attribuer une mission';
  let html = '<div style="padding:1rem">';
  MISSIONS_DETACHEMENT.forEach(m => {
    html += '<button onclick="confirmerMission(\'' + compagnie.id + '\',\'' + section.id + '\',\'' + m.id + '\')" style="display:block;width:100%;text-align:left;margin-bottom:.4rem;padding:.6rem .7rem;border:1px solid ' + (section.mission===m.id?'#8a6a20':'#2a2010') + ';background:transparent;color:#c0b090;cursor:pointer;font-size:.82rem">' + m.label + '</button>';
  });
  if (MISSIONS_DETACHEMENT.find(m=>m.id==='escorter')) {
    html += '<input id="mission-escorte-cible" type="text" placeholder="Nom de la personne à escorter (si mission Escorter)" style="width:100%;margin-top:.4rem;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-size:.8rem;outline:none;box-sizing:border-box"/>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerMission(compagnieId, sectionId, missionId) {
  const cibleEscorte = document.getElementById('mission-escorte-cible')?.value?.trim() || null;
  document.getElementById('modal-postes')?.classList.remove('open');
  const compagnie = (await sbGetCompagnies(state.country).catch(() => [])).find(c => c.id === compagnieId);
  const section = compagnie?.sections.find(s => s.id === sectionId);
  if (!section) return;
  section.mission = missionId;
  section.cibleEscorte = missionId === 'escorter' ? cibleEscorte : null;
  await sbSaveCompagnie(compagnieId, compagnie);
  showToast('Mission attribuée', MISSIONS_DETACHEMENT.find(m=>m.id===missionId)?.label, true, true);
}

// ---- MOBILISATION ----
async function doMobiliserArmee() {
  if (state.poste?.id !== 'min_def') { showToast('Réservé au Ministre de la Défense', '', false); return; }
  document.getElementById('postes-modal-title').textContent = 'Mobiliser l\'armée';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.75rem;color:#8a8060;margin-bottom:.7rem">La feuille de route reste secrète — seul le Commandant de la Caserne en aura connaissance.</div>';
  html += '<label style="font-size:.72rem;color:#8a8060;display:block;margin-bottom:.3rem">Empire de destination</label>';
  html += '<select id="mobil-empire" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-size:.85rem;outline:none;margin-bottom:.6rem">';
  Object.entries(COUNTRIES).forEach(([k, co]) => html += '<option value="' + k + '">' + co.n + '</option>');
  html += '</select>';
  html += '<label style="font-size:.72rem;color:#8a8060;display:block;margin-bottom:.3rem">Ville de destination</label>';
  html += '<input id="mobil-ville" type="text" placeholder="ex: capitale" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-size:.85rem;outline:none;box-sizing:border-box;margin-bottom:.6rem"/>';
  html += '<label style="font-size:.72rem;color:#8a8060;display:block;margin-bottom:.3rem">Feuille de route (secrète)</label>';
  html += '<textarea id="mobil-route" rows="4" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-size:.85rem;outline:none;box-sizing:border-box;margin-bottom:.8rem"></textarea>';
  html += '<button onclick="confirmerMobilisation()" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.55rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Donner l\'ordre de mobilisation</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerMobilisation() {
  const empireCible = document.getElementById('mobil-empire')?.value;
  const villeCible = document.getElementById('mobil-ville')?.value?.trim();
  const route = document.getElementById('mobil-route')?.value?.trim();
  if (!empireCible || !villeCible || !route) { showToast('Champs requis', '', false); return; }
  document.getElementById('modal-postes')?.classList.remove('open');

  const pays = state.country || 'republic';
  INDICES_NATIONAUX[pays].ISN = Math.min(100, INDICES_NATIONAUX[pays].ISN + 10);
  Object.keys(INDICES_NATIONAUX).forEach(p => { if (p !== pays) INDICES_NATIONAUX[p].ID = Math.max(0, INDICES_NATIONAUX[p].ID - 5); });
  updateUI();

  if (empireCible === pays) {
    const budgetNat = await chargerBudgetNational(pays);
    budgetNat.mobilisationNationaleActive = true;
    await sbSaveBudgetNational(pays, budgetNat).catch(() => {});
  }

  const commandantNom = await getTitulairePoste('commandant');
  if (commandantNom && typeof sbSendMail === 'function') {
    await sbSendMail('Ministère de la Défense', commandantNom, 'ORDRE DE MOBILISATION — CONFIDENTIEL',
      'Destination : ' + (COUNTRIES[empireCible]?.n||empireCible) + ' — ' + villeCible + '.<br><br>Feuille de route :<br>' + route.replace(/\n/g,'<br>'),
      typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : '').catch(() => {});
  }
  // Rumeur rare et peu precise, jamais la feuille de route elle-meme
  if (Math.random() < 0.15) {
    addExternalEvent('🔍 Rumeur : des mouvements de troupes inhabituels auraient été observés près de la frontière...');
  }
  showToast('Ordre de mobilisation donné', commandantNom ? 'Transmis au Commandant.' : 'Aucun Commandant en poste actuellement — l\'ordre reste sans destinataire.', true, true);
  addJournalEntry('Ordre de mobilisation donné (destination confidentielle).', 'event-info');
}

// ---- IMMUNITE MILITAIRE ----
// A appeler depuis le systeme d'arrestation/plainte : renvoie true si le joueur est immunise
async function estImmuniteMilitaire() {
  const posteId = state.poste?.id;
  if (!['lieutenant', 'capitaine', 'commandant'].includes(posteId)) return false;
  const monEmpire = state.domicile?.country || state.country || 'republic'; // l'empire dont je sers l'armee
  const iciEmpire = state.country || 'republic'; // le territoire ou je me trouve physiquement en ce moment
  const guerres = await sbGetGuerresPays(monEmpire).catch(() => []);
  const enGuerreIci = guerres.some(g => g.statut === 'active' && (
    (g.attaquant === monEmpire && g.attaque === iciEmpire) || (g.attaque === monEmpire && g.attaquant === iciEmpire)
  ));
  const budgetNat = await chargerBudgetNational(monEmpire).catch(() => null);
  const mobilisationNationale = iciEmpire === monEmpire && budgetNat?.mobilisationNationaleActive;
  return enGuerreIci || !!mobilisationNationale;
}

// Rafraichit le cache synchrone d'immunite, consulte par procederArrestation (qui n'est pas asynchrone)
async function rafraichirCacheImmuniteMilitaire() {
  state.immuniteMilitaireActuelle = await estImmuniteMilitaire().catch(() => false);
  // Malus "securiser" applicable dans la piece courante (cache pour un usage synchrone dans doOrder)
  if (typeof getAffichageDetachementPiece === 'function') {
    const det = await getAffichageDetachementPiece(state.country || 'republic', state.currentBuilding, state.currentRoom).catch(() => null);
    state.malusSecuriteMilitaire = (det?.mission === 'securiser') ? Math.min(40, 10 + det.nombre) : 0;
  }
  const budgetNat = await chargerBudgetNational(state.country || 'republic').catch(() => null);
  state.mobilisationNationaleCache = !!budgetNat?.mobilisationNationaleActive;
}

// Verifie si un detachement hostile bloque/attaque l'entree d'un joueur. Retourne true si l'entree doit etre annulee.
async function verifierMissionMilitaireEntree(buildingId, roomId) {
  if (typeof getAffichageDetachementPiece !== 'function') return false;
  const det = await getAffichageDetachementPiece(state.country || 'republic', buildingId, roomId);
  if (!det || !det.mission) return false;

  // Exemption : la chaine de commandement de la meme section n'est jamais bloquee/attaquee par ses propres troupes
  if (['lieutenant', 'capitaine', 'commandant', 'min_def'].includes(state.poste?.id)) return false;

  if (det.mission === 'bloquer_acces') {
    showToast('Accès bloqué', 'Un détachement militaire (' + det.nombre + ' soldats) interdit l\'accès.', false);
    return true;
  }
  if (det.mission === 'surveiller' && det.lieutenantNom && typeof sbSendMail === 'function') {
    sbSendMail('Détachement militaire', det.lieutenantNom, 'Rapport de surveillance',
      (state.char?.name || 'Une personne') + ' a été vue dans la zone surveillée.', typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : '').catch(() => {});
    return false;
  }
  if (det.mission === 'assassiner' || det.mission === 'arreter') {
    const chance = Math.min(90, 30 + det.nombre * 2); // plus le detachement est nombreux, plus le jet est favorable aux soldats
    const roll = Math.floor(Math.random() * 100) + 1;
    if (roll <= chance) {
      if (det.mission === 'assassiner' && typeof sbDeposerImpactIndice === 'function') {
        const palier = roll <= chance * 0.5 ? 'totale' : 'partielle';
        const pv = palier === 'totale' ? 0 : 25;
        state.hp = pv;
        state.hospitalisation = { jourDebut: state.day, palier, lieu: 'dispensaire', jourFin: state.day + (palier === 'totale' ? 3 : 2) };
        updateUI();
        showToast('Neutralisé(e) !', 'Le détachement militaire vous a pris pour cible. PV : ' + pv + '.', false);
      } else if (det.mission === 'arreter' && typeof procederArrestation === 'function') {
        showToast('Arrêté(e) !', 'Le détachement militaire vous a intercepté.', false);
        procederArrestation('intrusion_zone_militaire', false, false);
      }
      return true;
    }
  }
  return false;
}

// ---- BUDGET DE LA CASERNE (alloue par le MG) ----
async function ouvrirGererBudgetMilitaire() {
  if (state.poste?.id !== 'min_def') { showToast('Réservé au Ministre de la Défense', '', false); return; }
  const pays = state.country || 'republic';
  const maCaisse = typeof chargerCaisseBatiment === 'function' ? await chargerCaisseBatiment(pays, 'gouvernement-min_def') : { solde: 0 };
  const caisseCaserne = typeof chargerCaisseBatiment === 'function' ? await chargerCaisseBatiment(pays, 'caserne-militaire') : { solde: 0 };
  const budgetNat = await chargerBudgetNational(pays);
  const virementActuel = budgetNat.virementJournalierCaserne || 0;

  document.getElementById('postes-modal-title').textContent = 'Budget militaire';
  let html = '<div style="padding:1rem">';
  html += '<div style="display:flex;justify-content:space-between;margin-bottom:1rem;font-family:Bebas Neue,sans-serif;font-size:.95rem">';
  html += '<span style="color:#C9A84C">Ma caisse (Ministère) : ' + (maCaisse.solde||0).toLocaleString('fr-FR') + ' FR</span>';
  html += '<span style="color:#8a8060">Caisse de la Caserne : ' + (caisseCaserne.solde||0).toLocaleString('fr-FR') + ' FR</span>';
  html += '</div>';

  html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.7rem;margin-bottom:.7rem">';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.78rem;color:#e0d5b8;margin-bottom:.4rem">VIREMENT JOURNALIER AUTOMATIQUE</div>';
  html += '<div style="font-size:.72rem;color:#8a8060;margin-bottom:.5rem">Actuellement : ' + virementActuel.toLocaleString('fr-FR') + ' FR/jour, prélevé automatiquement chaque nuit sur votre caisse.</div>';
  html += '<input id="montant-virement-journalier" type="number" min="0" value="' + virementActuel + '" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-size:.85rem;outline:none;box-sizing:border-box;margin-bottom:.5rem"/>';
  html += '<button onclick="confirmerVirementJournalier()" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.72rem;padding:.4rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Fixer ce montant</button>';
  html += '</div>';

  html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.7rem;margin-bottom:.7rem">';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.78rem;color:#e0d5b8;margin-bottom:.4rem">VIREMENT PONCTUEL</div>';
  html += '<input id="montant-virement-ponctuel" type="number" min="0" value="0" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-size:.85rem;outline:none;box-sizing:border-box;margin-bottom:.5rem"/>';
  html += '<button onclick="confirmerVirementPonctuel()" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.72rem;padding:.4rem;border:1px solid #5a8ad0;background:transparent;color:#5a8ad0;cursor:pointer">Transférer maintenant</button>';
  html += '</div>';

  html += '<button onclick="ouvrirRechercheMilitaireDepuisMinistere()" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.06em;padding:.5rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Financer directement la recherche militaire</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerVirementJournalier() {
  const montant = Math.max(0, parseInt(document.getElementById('montant-virement-journalier')?.value || '0'));
  document.getElementById('modal-postes')?.classList.remove('open');
  const pays = state.country || 'republic';
  const budgetNat = await chargerBudgetNational(pays);
  budgetNat.virementJournalierCaserne = montant;
  await sbSaveBudgetNational(pays, budgetNat);
  showToast('Virement journalier fixé', montant.toLocaleString('fr-FR') + ' FR/jour vers la caserne, à partir de demain.', true, true);
  addJournalEntry('Virement journalier vers la caserne fixé à ' + montant + ' FR.', 'event-info');
}

async function confirmerVirementPonctuel() {
  const montant = Math.max(0, parseInt(document.getElementById('montant-virement-ponctuel')?.value || '0'));
  document.getElementById('modal-postes')?.classList.remove('open');
  if (montant <= 0) return;
  const pays = state.country || 'republic';
  const montantVerse = await debiterCaisseBatimentPlafonne(pays, 'gouvernement-min_def', montant);
  if (montantVerse <= 0) { showToast('Caisse insuffisante', '', false); return; }
  await crediterCaisseBatiment(pays, 'caserne-militaire', montantVerse);
  showToast('Virement effectué', montantVerse.toLocaleString('fr-FR') + ' FR transférés vers la caserne.', true, true);
  addJournalEntry('Virement ponctuel de ' + montantVerse + ' FR vers la caserne.', 'event-good');
}

// Traite le virement journalier automatique fixe par le MG (a appeler a minuit)
async function traiterVirementJournalierCaserne(pays) {
  const budgetNat = await chargerBudgetNational(pays).catch(() => null);
  const montant = budgetNat?.virementJournalierCaserne || 0;
  if (montant <= 0) return;
  const montantVerse = await debiterCaisseBatimentPlafonne(pays, 'gouvernement-min_def', montant);
  if (montantVerse > 0) await crediterCaisseBatiment(pays, 'caserne-militaire', montantVerse);
}



// ---- SOLDE QUOTIDIENNE DES SOLDATS (versee chaque nuit, juste apres que le MG touche sa part) ----
async function payerSoldeQuotidienne(pays) {
  const compagnies = await sbGetCompagnies(pays).catch(() => []);
  const coutParSoldat = 20; // FR/jour/soldat
  let totalDu = 0;
  compagnies.forEach(c => (c.sections||[]).forEach(s => { totalDu += (s.effectifTotal||0) * coutParSoldat; }));
  if (totalDu <= 0) return;
  const montantVerse = typeof debiterCaisseBatimentPlafonne === 'function' ? await debiterCaisseBatimentPlafonne(pays, 'caserne-militaire', totalDu) : 0;
  if (montantVerse < totalDu) {
    addExternalEvent('⚠️ La solde des troupes de ' + (COUNTRIES[pays]?.n||pays) + ' n\'a pu être versée qu\'en partie faute de budget suffisant.');
  }
}

// ---- FICHE DE SECTION (reservee au lieutenant) ----
async function ouvrirRecruterSection() {
  if (state.poste?.id !== 'commandant') { showToast('Réservé au Commandant', '', false); return; }
  const pays = state.country || 'republic';
  const compagnies = await sbGetCompagnies(pays).catch(() => []);
  const vides = [];
  compagnies.forEach(c => (c.sections || []).forEach(s => { if (s.soldats.length === 0) vides.push({ compagnieId: c.id, section: s }); }));

  document.getElementById('postes-modal-title').textContent = 'Recompléter une section';
  let html = '<div style="padding:1rem">';
  if (vides.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucune section vide actuellement.</div>';
  } else {
    vides.forEach(v => {
      html += '<div style="display:flex;justify-content:space-between;align-items:center;border:1px solid #2a2010;background:#0f0d05;padding:.5rem .7rem;margin-bottom:.4rem">';
      html += '<span style="font-size:.85rem;color:#e0d5b8">' + v.section.id + ' (vide)</span>';
      html += '<button onclick="doRecruterSection(\'' + v.compagnieId + '\',\'' + v.section.id + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.7rem;padding:.3rem .6rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Recompléter (' + COUT_SECTION.toLocaleString('fr-FR') + ' FR)</button>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function doVoirMaSection() {
  if (state.poste?.id !== 'lieutenant') { showToast('Réservé à un Lieutenant', '', false); return; }
  const compagnie = (await sbGetCompagnies(state.country).catch(() => [])).find(c => c.id === state.poste.compagnieId);
  const section = getSectionDuLieutenant(compagnie);
  if (!section) return;

  document.getElementById('postes-modal-title').textContent = 'Ma section — ' + section.soldats.length + ' soldats';
  let html = '<div style="padding:1rem;max-height:60vh;overflow-y:auto">';
  const armesLabels = { corps_a_corps: 'Corps à corps', arme_de_poing: 'Arme de poing', mitraillette: 'Mitraillette' };
  section.soldats.forEach(s => {
    const localisation = s.roomId === ROOM_AVEC_LIEUTENANT ? 'Avec vous' : (s.buildingId ? (BUILDINGS[s.buildingId]?.name || s.buildingId) : 'Caserne');
    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.5rem .7rem;margin-bottom:.35rem;font-size:.75rem">';
    html += '<div style="color:#e0d5b8;font-family:monospace">' + s.matricule + '</div>';
    html += '<div style="color:#a89870">FOR ' + s.formation.force + ' · END ' + s.formation.endurance + ' · TIR ' + s.formation.tir + ' · ' + armesLabels[s.arme] + ' · PA ' + s.pa + '/' + PA_MAX_SOLDAT + ' · ' + localisation + '</div>';
    html += '</div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// ---- ENTRAINEMENT (comme le foot : pas de plafond, assiduite recompensee, 12/24 max par session) ----
async function doEntrainerSection() {
  if (state.poste?.id !== 'lieutenant') { showToast('Réservé à un Lieutenant', '', false); return; }
  const compagnie = (await sbGetCompagnies(state.country).catch(() => [])).find(c => c.id === state.poste.compagnieId);
  const section = getSectionDuLieutenant(compagnie);
  if (!section) return;

  document.getElementById('postes-modal-title').textContent = 'Entraîner la section';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.75rem;color:#8a8060;margin-bottom:.8rem">Choisissez la compétence à travailler. ' + CAP_ENTRAINEMENT_PAR_SESSION + ' soldats maximum par session (les moins entraînés dans cette compétence sont sélectionnés en priorité).</div>';
  ['force','endurance','tir'].forEach(stat => {
    const label = { force:'Force', endurance:'Endurance', tir:'Tir' }[stat];
    html += '<button onclick="confirmerEntrainementSection(\'' + compagnie.id + '\',\'' + section.id + '\',\'' + stat + '\')" style="display:block;width:100%;text-align:left;margin-bottom:.4rem;padding:.6rem .7rem;border:1px solid #2a2010;background:transparent;color:#c0b090;cursor:pointer;font-size:.82rem">' + label + '</button>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerEntrainementSection(compagnieId, sectionId, stat) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const compagnie = (await sbGetCompagnies(state.country).catch(() => [])).find(c => c.id === compagnieId);
  const section = compagnie?.sections.find(s => s.id === sectionId);
  if (!section) return;

  const tries = [...section.soldats].sort((a, b) => a.formation[stat] - b.formation[stat]).slice(0, CAP_ENTRAINEMENT_PAR_SESSION);
  tries.forEach(s => { s.formation[stat] = Math.min(100, s.formation[stat] + 3); });
  await sbSaveCompagnie(compagnieId, compagnie);
  showToast('Entraînement terminé', tries.length + ' soldats ont progressé en ' + stat + '.', true, true);
  addJournalEntry('Entraînement de la section "' + section.lieutenantNom + '" en ' + stat + ' (' + tries.length + ' soldats).', 'event-good');
}

// ---- EQUIPEMENT INDIVIDUEL ----
async function doEquiperSection() {
  if (state.poste?.id !== 'lieutenant') { showToast('Réservé à un Lieutenant', '', false); return; }
  const compagnie = (await sbGetCompagnies(state.country).catch(() => [])).find(c => c.id === state.poste.compagnieId);
  const section = getSectionDuLieutenant(compagnie);
  const ici = section?.soldats.filter(s => s.buildingId === state.currentBuilding && s.roomId === state.currentRoom) || [];
  if (ici.length === 0) { showToast('Aucun soldat ici', '', false); return; }

  document.getElementById('postes-modal-title').textContent = 'Équiper les soldats présents ici';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.75rem;color:#8a8060;margin-bottom:.8rem">' + ici.length + ' soldats présents ici recevront cet équipement.</div>';
  const armes = [{id:'corps_a_corps',label:'Corps à corps (coef. 1)'},{id:'arme_de_poing',label:'Arme de poing (coef. 2,5)'},{id:'mitraillette',label:'Mitraillette (coef. 4)'}];
  armes.forEach(a => {
    html += '<button onclick="confirmerEquipementSection(\'' + compagnie.id + '\',\'' + section.id + '\',\'' + a.id + '\')" style="display:block;width:100%;text-align:left;margin-bottom:.4rem;padding:.6rem .7rem;border:1px solid #2a2010;background:transparent;color:#c0b090;cursor:pointer;font-size:.82rem">' + a.label + '</button>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerEquipementSection(compagnieId, sectionId, arme) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const compagnie = (await sbGetCompagnies(state.country).catch(() => [])).find(c => c.id === compagnieId);
  const section = compagnie?.sections.find(s => s.id === sectionId);
  if (!section) return;
  const ici = section.soldats.filter(s => s.buildingId === state.currentBuilding && s.roomId === state.currentRoom);
  ici.forEach(s => { s.arme = arme; });
  await sbSaveCompagnie(compagnieId, compagnie);
  showToast('Équipement distribué', ici.length + ' soldats équipés.', true, true);
}

// ---- COMBAT AUTOMATIQUE ENTRE TROUPES DE PAYS EN GUERRE ----
function calculerPointsGroupe(soldats, coefsArmes) {
  const coefs = coefsArmes || COEF_ARME_MILITAIRE;
  const force = soldats.reduce((s, sol) => s + sol.formation.force, 0);
  const tir = soldats.reduce((s, sol) => s + sol.formation.tir * (coefs[sol.arme] || 1), 0);
  const endurance = soldats.reduce((s, sol) => s + sol.formation.endurance, 0);
  return { force, tir, endurance, points: force * 3 + tir };
}

async function getCoefsArmesPays(pays) {
  const coefs = { ...COEF_ARME_MILITAIRE };
  const budgetNat = await chargerBudgetNational(pays).catch(() => null);
  Object.entries(budgetNat?.coefficientsArmesAcquis || {}).forEach(([arme, bonus]) => { coefs[arme] = (coefs[arme]||1) + bonus; });
  return coefs;
}

// A appeler apres tout depot de troupes dans une piece (deposerSoldats) : verifie une rencontre hostile et resout le combat
async function verifierCombatAutomatique(buildingId, roomId) {
  const compagniesRepublic = []; // toutes compagnies, tous pays, pour verifier les rencontres inter-empires
  const paysListe = Object.keys(COUNTRIES);
  let sectionsIci = [];
  for (const p of paysListe) {
    const compagnies = await sbGetCompagnies(p).catch(() => []);
    compagnies.forEach(c => (c.sections || []).forEach(s => {
      const presents = s.soldats.filter(sol => sol.buildingId === buildingId && sol.roomId === roomId);
      if (presents.length > 0) sectionsIci.push({ pays: p, compagnieId: c.id, section: s, presents });
    }));
  }
  if (sectionsIci.length < 2) return;

  // Chercher une paire de pays effectivement en guerre parmi les sections presentes
  for (let i = 0; i < sectionsIci.length; i++) {
    for (let j = i + 1; j < sectionsIci.length; j++) {
      const A = sectionsIci[i], B = sectionsIci[j];
      if (A.pays === B.pays) continue;
      const guerres = await sbGetGuerresPays(A.pays).catch(() => []);
      const enGuerre = guerres.some(g => g.statut === 'active' && ((g.attaquant===A.pays&&g.attaque===B.pays)||(g.attaque===A.pays&&g.attaquant===B.pays)));
      if (enGuerre) { await resoudreCombat(A, B); return; }
    }
  }
}

async function construireCivilsCombat(section) {
  const affectes = (section.civilsRequisitionnes || []).filter(c => c.statut === 'affecte');
  const civils = [];
  for (const c of affectes) {
    let stats = { int: 10, vol: 10, per: 10 };
    if (typeof sbGet === 'function') {
      const rows = await sbGet('personnages', `name=eq.${encodeURIComponent(c.nom)}&select=int,vol,per`).catch(() => []);
      if (rows?.[0]) stats = rows[0];
    }
    civils.push({
      matricule: 'CIVIL-' + c.nom,
      formation: { force: stats.int || 0, endurance: stats.vol || 0, tir: stats.per || 0 },
      arme: 'corps_a_corps', pa: PA_MAX_SOLDAT, civil: true, nom: c.nom
    });
  }
  return civils;
}

async function resoudreCombat(A, B) {
  const civilsA = await construireCivilsCombat(A.section);
  const civilsB = await construireCivilsCombat(B.section);
  let soldatsA = [...A.presents, ...civilsA], soldatsB = [...B.presents, ...civilsB];
  const coefsA = await getCoefsArmesPays(A.pays);
  const coefsB = await getCoefsArmesPays(B.pays);
  let round = 0;
  while (soldatsA.length > 0 && soldatsB.length > 0 && round < 100) {
    round++;
    const ptsA = calculerPointsGroupe(soldatsA, coefsA);
    const ptsB = calculerPointsGroupe(soldatsB, coefsB);

    // Degats : mes points de groupe = dommages infliges au PA adverse
    const paTotalA = soldatsA.reduce((s, sol) => s + sol.pa, 0) - ptsB.points;
    const paTotalB = soldatsB.reduce((s, sol) => s + sol.pa, 0) - ptsA.points;

    // Attrition d'endurance : base 2 PA/round/soldat, reduite selon l'avantage relatif d'endurance
    const ecartA = ptsB.endurance > 0 ? (ptsA.endurance - ptsB.endurance) / ptsB.endurance : 0;
    const ecartB = ptsA.endurance > 0 ? (ptsB.endurance - ptsA.endurance) / ptsA.endurance : 0;
    const attritionA = Math.max(0, PA_BASE_ROUND * soldatsA.length * (1 - Math.max(0, ecartA)));
    const attritionB = Math.max(0, PA_BASE_ROUND * soldatsB.length * (1 - Math.max(0, ecartB)));

    const paFinalA = paTotalA - attritionA;
    const paFinalB = paTotalB - attritionB;

    if (paFinalA <= 0) { soldatsA = []; }
    if (paFinalB <= 0) { soldatsB = []; }
    if (paFinalA > 0 && paFinalB > 0) {
      // Repartir les PA restants proportionnellement (simplification : pas de suivi individuel round par round)
      const ratioA = paFinalA / (soldatsA.reduce((s, sol) => s + sol.pa, 0) || 1);
      const ratioB = paFinalB / (soldatsB.reduce((s, sol) => s + sol.pa, 0) || 1);
      soldatsA.forEach(s => s.pa = Math.max(0, s.pa * ratioA));
      soldatsB.forEach(s => s.pa = Math.max(0, s.pa * ratioB));
    }
  }

  const compagnieA = (await sbGetCompagnies(A.pays).catch(() => [])).find(c => c.id === A.compagnieId);
  const sectionA = compagnieA?.sections.find(s => s.id === A.section.id);
  const compagnieB = (await sbGetCompagnies(B.pays).catch(() => [])).find(c => c.id === B.compagnieId);
  const sectionB = compagnieB?.sections.find(s => s.id === B.section.id);

  const matriculesMortsA = A.presents.filter(s => soldatsA.length === 0).map(s => s.matricule);
  const matriculesMortsB = B.presents.filter(s => soldatsB.length === 0).map(s => s.matricule);
  const civilsMortsA = civilsA.length > 0 && soldatsA.length === 0 ? civilsA.length : 0;
  const civilsMortsB = civilsB.length > 0 && soldatsB.length === 0 ? civilsB.length : 0;

  if (soldatsA.length === 0 && sectionA) {
    sectionA.soldats = sectionA.soldats.filter(s => !A.presents.some(p => p.matricule === s.matricule));
    if (sectionA.civilsRequisitionnes) sectionA.civilsRequisitionnes = sectionA.civilsRequisitionnes.filter(c => c.statut !== 'affecte');
  }
  if (soldatsB.length === 0 && sectionB) {
    sectionB.soldats = sectionB.soldats.filter(s => !B.presents.some(p => p.matricule === s.matricule));
    if (sectionB.civilsRequisitionnes) sectionB.civilsRequisitionnes = sectionB.civilsRequisitionnes.filter(c => c.statut !== 'affecte');
  }

  if (compagnieA) await sbSaveCompagnie(A.compagnieId, compagnieA);
  if (compagnieB) await sbSaveCompagnie(B.compagnieId, compagnieB);

  const resultat = soldatsA.length === 0 && soldatsB.length === 0 ? 'Anéantissement mutuel'
    : soldatsA.length === 0 ? (COUNTRIES[B.pays]?.n||B.pays) + ' l\'emporte' : (COUNTRIES[A.pays]?.n||A.pays) + ' l\'emporte';

  addExternalEvent('⚔️ COMBAT : affrontement entre les troupes de ' + (COUNTRIES[A.pays]?.n||A.pays) + ' et ' + (COUNTRIES[B.pays]?.n||B.pays) + ' — ' + resultat + ' (' + round + ' rounds).');

  if (typeof sbCreerFaitArmes === 'function') {
    await sbCreerFaitArmes({
      jour: state.day || 1,
      campA: { pays: A.pays, sectionId: A.section.id, lieutenantNom: A.section.lieutenantNom, effectifEngage: A.presents.length + civilsA.length, pertes: matriculesMortsA.length + civilsMortsA },
      campB: { pays: B.pays, sectionId: B.section.id, lieutenantNom: B.section.lieutenantNom, effectifEngage: B.presents.length + civilsB.length, pertes: matriculesMortsB.length + civilsMortsB },
      resultat, rounds: round
    }).catch(() => {});
  }
  if (A.section.lieutenantNom && typeof sbSendMail === 'function') sbSendMail('État-Major', A.section.lieutenantNom, 'Rapport de combat', resultat + '. Pertes : ' + matriculesMortsA.length + ' soldats.', typeof formatDateHeureJeu==='function'?formatDateHeureJeu():'').catch(()=>{});
  if (B.section.lieutenantNom && typeof sbSendMail === 'function') sbSendMail('État-Major', B.section.lieutenantNom, 'Rapport de combat', resultat + '. Pertes : ' + matriculesMortsB.length + ' soldats.', typeof formatDateHeureJeu==='function'?formatDateHeureJeu():'').catch(()=>{});

  if (soldatsA.length === 0 && sectionA?.soldats.length === 0 && A.section.lieutenantNom) {
    const commandantNom = await getTitulairePoste('commandant', null, A.pays);
    if (commandantNom) await sbSendMail('État-Major', commandantNom, 'Section anéantie', 'La section de ' + A.section.lieutenantNom + ' a été anéantie et doit être recomplétée.', typeof formatDateHeureJeu==='function'?formatDateHeureJeu():'').catch(()=>{});
  }
  if (soldatsB.length === 0 && sectionB?.soldats.length === 0 && B.section.lieutenantNom) {
    const commandantNom = await getTitulairePoste('commandant', null, B.pays);
    if (commandantNom) await sbSendMail('État-Major', commandantNom, 'Section anéantie', 'La section de ' + B.section.lieutenantNom + ' a été anéantie et doit être recomplétée.', typeof formatDateHeureJeu==='function'?formatDateHeureJeu():'').catch(()=>{});
  }
}

// ---- LE CAPITAINE PEUT DEMETTRE UN LIEUTENANT ----
async function doDemettreLieutenant() {
  if (state.poste?.id !== 'capitaine') { showToast('Réservé à un Capitaine', '', false); return; }
  const compagnie = (await sbGetCompagnies(state.country).catch(() => [])).find(c => c.id === state.poste.compagnieId);
  const pourvues = (compagnie?.sections || []).filter(s => s.lieutenantNom);
  document.getElementById('postes-modal-title').textContent = 'Démettre un Lieutenant';
  let html = '<div style="padding:1rem">';
  if (pourvues.length === 0) html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucun lieutenant en poste actuellement.</div>';
  pourvues.forEach(s => {
    html += '<div style="display:flex;justify-content:space-between;align-items:center;border:1px solid #2a2010;background:#0f0d05;padding:.5rem .7rem;margin-bottom:.4rem">';
    html += '<span style="font-size:.85rem;color:#e0d5b8">' + s.lieutenantNom + ' (Section ' + s.numero + ')</span>';
    html += '<button onclick="confirmerDemissionLieutenant(\'' + compagnie.id + '\',\'' + s.id + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.7rem;padding:.3rem .6rem;border:1px solid #8a2020;background:transparent;color:#cc4444;cursor:pointer">Démettre</button>';
    html += '</div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerDemissionLieutenant(compagnieId, sectionId) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const compagnie = (await sbGetCompagnies(state.country).catch(() => [])).find(c => c.id === compagnieId);
  const section = compagnie?.sections.find(s => s.id === sectionId);
  if (!section) return;
  const ancien = section.lieutenantNom;
  section.lieutenantNom = null;
  await sbSaveCompagnie(compagnieId, compagnie);
  showToast('Lieutenant démis', ancien + ' n\'est plus en poste.', false, true);
  addJournalEntry(ancien + ' démis de son poste de Lieutenant.', 'event-bad');
}

// ---- SALLE DES FAITS D'ARMES — met en scene les meilleurs combats, section par section ----
async function ouvrirConsulterFaitsArmes() {
  document.getElementById('postes-modal-title').textContent = "Salle des Faits d'Armes";
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement des archives...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const combats = typeof sbGetFaitsArmes === 'function' ? await sbGetFaitsArmes().catch(() => []) : [];

  let html = '<div style="padding:1rem;max-height:65vh;overflow-y:auto">';
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:1rem">Le numéro de section porte la mémoire de ses batailles, transmise d\'un lieutenant à l\'autre au fil des affectations.</div>';

  if (combats.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucun combat consigné pour l\'instant. Que l\'Histoire commence.</div>';
  } else {
    // Trie par ampleur (effectif engage + pertes) pour mettre en avant les batailles marquantes
    const tries = [...combats].sort((a, b) =>
      (b.campA.effectifEngage + b.campB.effectifEngage + b.campA.pertes + b.campB.pertes) -
      (a.campA.effectifEngage + a.campB.effectifEngage + a.campA.pertes + a.campB.pertes)
    );
    tries.forEach(c => {
      html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.7rem;margin-bottom:.6rem">';
      html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.8rem;color:#C9A84C;letter-spacing:.06em;margin-bottom:.3rem">JOUR ' + c.jour + ' — ' + c.rounds + ' ROUNDS</div>';
      html += '<div style="font-size:.82rem;color:#e0d5b8;margin-bottom:.3rem">' + (COUNTRIES[c.campA.pays]?.n||c.campA.pays) + ' (Section ' + c.campA.sectionId.split('-').pop() + ', Lt. ' + (c.campA.lieutenantNom||'?') + ') vs ' + (COUNTRIES[c.campB.pays]?.n||c.campB.pays) + ' (Section ' + c.campB.sectionId.split('-').pop() + ', Lt. ' + (c.campB.lieutenantNom||'?') + ')</div>';
      html += '<div style="font-size:.75rem;color:#a89870">Effectifs engagés : ' + c.campA.effectifEngage + ' vs ' + c.campB.effectifEngage + ' · Pertes : ' + c.campA.pertes + ' / ' + c.campB.pertes + '</div>';
      html += '<div style="font-size:.78rem;color:#6ab858;margin-top:.3rem">' + c.resultat + '</div>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

// =====================
// COUVRE-FEU — 20h-6h, 2 jours max, exemption militaires/requisitionnes
// =====================
async function ouvrirGererCouvreFeu() {
  if (state.poste?.id !== 'min_int') { showToast('Réservé au Ministre de l\'Intérieur', '', false); return; }
  const pays = state.country || 'republic';
  const budgetNat = await chargerBudgetNational(pays);
  const cf = budgetNat.couvreFeu;

  document.getElementById('postes-modal-title').textContent = 'Couvre-feu';
  let html = '<div style="padding:1rem">';
  if (cf?.actif) {
    html += '<div style="font-size:.85rem;color:#cc4444;margin-bottom:.8rem">Couvre-feu actif (20h-6h) jusqu\'au Jour ' + cf.jourFin + '.</div>';
    html += '<button onclick="confirmerCouvreFeu(false)" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.78rem;padding:.5rem;border:1px solid #8a2020;background:transparent;color:#cc4444;cursor:pointer">Lever le couvre-feu</button>';
  } else {
    html += '<div style="font-size:.8rem;color:#8a8060;margin-bottom:.8rem">Actif de 20h à 6h, 2 jours maximum. Dégrade IS et POP du gouvernement chaque jour tant qu\'il dure. Militaires et civils réquisitionnés en sont exemptés.</div>';
    html += '<button onclick="confirmerCouvreFeu(true)" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.78rem;padding:.5rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Instaurer le couvre-feu</button>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerCouvreFeu(activer) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const pays = state.country || 'republic';
  const budgetNat = await chargerBudgetNational(pays);
  if (activer) {
    budgetNat.couvreFeu = { actif: true, jourDebut: state.day || 1, jourFin: (state.day || 1) + 2, dateFin: Date.now() + 2 * 86400000 };
    await sbSaveBudgetNational(pays, budgetNat);
    showToast('Couvre-feu instauré', '20h-6h, jusqu\'au Jour ' + budgetNat.couvreFeu.jourFin + '.', false, true);
    addExternalEvent('🌙 COUVRE-FEU instauré par le Ministère de l\'Intérieur, de 20h à 6h.');
  } else {
    budgetNat.couvreFeu = { actif: false };
    await sbSaveBudgetNational(pays, budgetNat);
    showToast('Couvre-feu levé', '', true, true);
    addExternalEvent('🌙 Le couvre-feu est levé.');
  }
}

// Verifie si le joueur est exempte de couvre-feu (militaire ou civil requisitionne)
function estExempteCouvreFeu() {
  if (['lieutenant', 'capitaine', 'commandant', 'min_def'].includes(state.poste?.id)) return true;
  if (state.char?.requisition?.statut === 'convoque' || state.char?.requisition?.statut === 'affecte') return true;
  return false;
}

// A appeler a chaque changement de batiment : verifie et applique une eventuelle violation de couvre-feu
async function verifierCouvreFeu() {
  const pays = state.country || 'republic';
  const budgetNat = await chargerBudgetNational(pays).catch(() => null);
  if (!budgetNat?.couvreFeu?.actif) return;
  if (state.day > budgetNat.couvreFeu.jourFin) {
    budgetNat.couvreFeu.actif = false;
    await sbSaveBudgetNational(pays, budgetNat).catch(() => {});
    return;
  }
  const heure = state.hour ?? 12;
  const enCouvreFeu = heure >= 20 || heure < 6;
  if (!enCouvreFeu || estExempteCouvreFeu()) return;

  const chancePatrouille = 0.45;
  if (Math.random() < chancePatrouille) {
    const recidive = state.char?.violationsCouvreFeu > 0;
    state.char.violationsCouvreFeu = (state.char?.violationsCouvreFeu || 0) + 1;
    const dureeHeures = recidive ? 24 : null; // null = jusqu'a la fin du couvre-feu (6h)
    if (typeof procederArrestation === 'function') {
      showToast('Interpellé(e) !', 'Violation du couvre-feu' + (recidive ? ' (récidive, 24h de détention)' : ' (jusqu\'à la fin du couvre-feu)') + '.', false);
      procederArrestation('violation_couvre_feu', false, false);
    }
  }
}

// Applique la degradation quotidienne d'IS/POP tant que le couvre-feu est actif
async function verifierEffetsCouvreFeuQuotidien(pays) {
  const budgetNat = await chargerBudgetNational(pays).catch(() => null);
  if (!budgetNat?.couvreFeu?.actif) return;
  if (INDICES_NATIONAUX[pays]) INDICES_NATIONAUX[pays].IS = Math.max(0, INDICES_NATIONAUX[pays].IS - 3);
  const postesGouv = ['president','pm','min_int','min_fin','min_just','min_def','min_info','min_ae'];
  for (const posteId of postesGouv) {
    const nom = await getTitulairePoste(posteId, null, pays);
    if (!nom) continue;
    if (nom === state.char?.name) { state.pop = Math.max(0, (state.pop||0) - 2); }
    else if (typeof sbGet === 'function') {
      const rows = await sbGet('personnages', `name=eq.${encodeURIComponent(nom)}&select=pop`).catch(() => []);
      const pop = rows?.[0]?.pop ?? 50;
      await sbUpdate('personnages', `name=eq.${encodeURIComponent(nom)}`, { pop: Math.max(0, pop - 2) }).catch(() => {});
    }
  }
  updateUI();
}

// =====================
// RECHERCHE MILITAIRE — commanditee par le Commandant, associe un chercheur civil PNJ (en attendant l'universite)
// =====================
const DUREE_RECHERCHE_JOURS = 3;
const COUT_RECHERCHE = 8000;
const GAIN_COEF_RECHERCHE = 0.5;

async function ouvrirRechercheMilitaire() {
  if (state.poste?.id !== 'commandant') { showToast('Réservé au Commandant', '', false); return; }
  const pays = state.country || 'republic';
  const budgetNat = await chargerBudgetNational(pays);
  const enCours = budgetNat.rechercheMilitaire?.enCours;

  document.getElementById('postes-modal-title').textContent = 'Recherche militaire';
  let html = '<div style="padding:1rem">';
  if (enCours) {
    html += '<div style="font-size:.85rem;color:#8a8060">Recherche en cours sur : <strong style="color:#C9A84C">' + enCours.arme + '</strong>, achèvement Jour ' + enCours.jourFin + '.</div>';
  } else {
    html += '<div style="font-size:.78rem;color:#8a8060;margin-bottom:.8rem">En collaboration avec un chercheur civil, améliore durablement le coefficient de tir d\'un type d\'arme pour tout le pays. ' + DUREE_RECHERCHE_JOURS + ' jours, ' + COUT_RECHERCHE.toLocaleString('fr-FR') + ' FR (caisse de la caserne).</div>';
    const armes = [{id:'corps_a_corps',label:'Corps à corps'},{id:'arme_de_poing',label:'Arme de poing'},{id:'mitraillette',label:'Mitraillette'}];
    armes.forEach(a => {
      html += '<button onclick="confirmerRechercheMilitaire(\'' + a.id + '\')" style="display:block;width:100%;text-align:left;margin-bottom:.4rem;padding:.6rem .7rem;border:1px solid #2a2010;background:transparent;color:#c0b090;cursor:pointer;font-size:.82rem">' + a.label + '</button>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerRechercheMilitaire(arme) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const pays = state.country || 'republic';
  const montantVerse = await debiterCaisseBatimentPlafonne(pays, 'caserne-militaire', COUT_RECHERCHE);
  if (montantVerse < COUT_RECHERCHE) { showToast('Budget insuffisant', 'La caisse de la caserne ne couvre pas le coût de la recherche.', false); return; }

  const budgetNat = await chargerBudgetNational(pays);
  budgetNat.rechercheMilitaire = { enCours: { arme, jourDebut: state.day, jourFin: state.day + DUREE_RECHERCHE_JOURS, dateFin: Date.now() + DUREE_RECHERCHE_JOURS * 86400000 } };
  await sbSaveBudgetNational(pays, budgetNat);
  showToast('Recherche lancée', 'Un chercheur civil rejoint l\'effort. Achèvement dans ' + DUREE_RECHERCHE_JOURS + ' jours.', true, true);
  addJournalEntry('Recherche militaire lancée sur : ' + arme + ' (-' + COUT_RECHERCHE + ' FR).', 'event-info');
  addExternalEvent('🔬 Le chercheur civil Prof. ' + PRENOMS_CHERCHEUR_MIL[Math.floor(Math.random()*PRENOMS_CHERCHEUR_MIL.length)] + ' rejoint l\'effort de recherche militaire.');
}

const PRENOMS_CHERCHEUR_MIL = ['Adalbert Cossinus', 'Hortense Ballistik', 'Théodule Percussion'];

// Retourne le coefficient de tir actuel d'une arme pour un pays (defaut + ameliorations acquises)
async function getCoefArmeMilitaire(pays, arme) {
  const budgetNat = await chargerBudgetNational(pays).catch(() => null);
  const bonus = budgetNat?.coefficientsArmesAcquis?.[arme] || 0;
  return (COEF_ARME_MILITAIRE[arme] || 1) + bonus;
}

// Verifie chaque jour si une recherche militaire en cours est terminee
async function verifierRechercheMilitaireQuotidien(pays) {
  const budgetNat = await chargerBudgetNational(pays).catch(() => null);
  const enCours = budgetNat?.rechercheMilitaire?.enCours;
  if (!enCours || state.day < enCours.jourFin) return;

  if (!budgetNat.coefficientsArmesAcquis) budgetNat.coefficientsArmesAcquis = {};
  budgetNat.coefficientsArmesAcquis[enCours.arme] = (budgetNat.coefficientsArmesAcquis[enCours.arme] || 0) + GAIN_COEF_RECHERCHE;
  budgetNat.rechercheMilitaire.enCours = null;
  await sbSaveBudgetNational(pays, budgetNat);
  addExternalEvent('🔬 Recherche militaire achevée : le coefficient de tir de "' + enCours.arme + '" est amélioré pour toute la nation.');
  const commandantNom = await getTitulairePoste('commandant', null, pays);
  if (commandantNom && typeof sbSendMail === 'function') sbSendMail('Chercheurs Civils', commandantNom, 'Recherche achevée', 'Le programme de recherche sur "' + enCours.arme + '" est terminé. Coefficient amélioré.', typeof formatDateHeureJeu==='function'?formatDateHeureJeu():'').catch(()=>{});
}

// Deplace automatiquement les soldats d'une section en mission "escorter" quand leur protege change de batiment
async function suivreEscorteAvecMoi(nouveauBuildingId) {
  const moi = state.char?.name;
  if (!moi) return;
  const pays = state.country || 'republic';
  const compagnies = await sbGetCompagnies(pays).catch(() => []);
  for (const c of compagnies) {
    for (const s of (c.sections || [])) {
      if (s.mission === 'escorter' && s.cibleEscorte === moi && s.soldats.length > 0) {
        const premiereRoom = Object.keys(BUILDINGS[nouveauBuildingId]?.rooms || {})[0] || null;
        s.soldats.forEach(sol => { sol.buildingId = nouveauBuildingId; sol.roomId = premiereRoom; });
        await sbSaveCompagnie(c.id, c);
      }
    }
  }
}

// =====================
// REQUISITION CIVILE — loterie aleatoire, doublement d'effectif, desertion publique
// =====================
const DELAI_REQUISITION_HEURES = 36;

async function ouvrirRequisitionCivile() {
  if (state.poste?.id !== 'min_def') { showToast('Réservé au Ministre de la Défense', '', false); return; }
  const pays = state.country || 'republic';
  const budgetNat = await chargerBudgetNational(pays);
  if (!budgetNat.mobilisationNationaleActive) { showToast('Aucune mobilisation nationale active', 'La réquisition n\'est possible que pendant une mobilisation nationale.', false); return; }

  const compagnies = await sbGetCompagnies(pays).catch(() => []);
  const sections = [];
  compagnies.forEach(c => (c.sections||[]).forEach(s => { if (s.lieutenantNom && !s.civilsRequisitionnes?.length) sections.push({ compagnieId: c.id, section: s }); }));

  document.getElementById('postes-modal-title').textContent = 'Réquisition civile';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.75rem;color:#8a8060;margin-bottom:.8rem">Tire au sort 24 citoyens domiciliés parmi toute la population pour doubler l\'effectif de la section choisie. Absence après ' + DELAI_REQUISITION_HEURES + 'h ⇒ statut de déserteur, public et recherché.</div>';
  if (sections.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucune section éligible (déjà réquisitionnée, ou aucune section pourvue).</div>';
  } else {
    sections.forEach(s => {
      html += '<div style="display:flex;justify-content:space-between;align-items:center;border:1px solid #2a2010;background:#0f0d05;padding:.5rem .7rem;margin-bottom:.4rem">';
      html += '<span style="font-size:.85rem;color:#e0d5b8">Section ' + s.section.numero + ' (Lt. ' + s.section.lieutenantNom + ')</span>';
      html += '<button onclick="confirmerRequisitionCivile(\'' + s.compagnieId + '\',\'' + s.section.id + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.7rem;padding:.3rem .6rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Réquisitionner</button>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerRequisitionCivile(compagnieId, sectionId) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const pays = state.country || 'republic';
  const compagnie = (await sbGetCompagnies(pays).catch(() => [])).find(c => c.id === compagnieId);
  const section = compagnie?.sections.find(s => s.id === sectionId);
  if (!section) return;

  let civils = [];
  if (typeof sbListPersonnages === 'function') {
    const tous = await sbListPersonnages().catch(() => []);
    civils = tous.filter(j => (j.domicile?.country || j.country) === pays && !['lieutenant','capitaine','commandant','min_def','president','pm','min_int','min_fin','min_just','min_info','min_ae','maire'].includes(j.poste?.id));
  }
  const tires = [...civils].sort(() => Math.random() - 0.5).slice(0, 24);
  const deadline = Date.now() + DELAI_REQUISITION_HEURES * 3600000;

  section.civilsRequisitionnes = tires.map(c => ({ nom: c.name, statut: 'convoque', deadline }));
  await sbSaveCompagnie(compagnieId, compagnie);

  for (const c of tires) {
    if (typeof sbSendMail === 'function') {
      await sbSendMail('Ministère de la Défense', c.name, 'CONVOCATION — Réquisition civile',
        'Vous êtes réquisitionné(e) pour rejoindre la Section ' + section.numero + ' (Lt. ' + section.lieutenantNom + ') dans le cadre de la mobilisation nationale. Présentez-vous sous ' + DELAI_REQUISITION_HEURES + 'h, faute de quoi vous serez déclaré(e) déserteur(se).',
        typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : '').catch(() => {});
    }
    if (typeof sbUpdate === 'function') {
      await sbUpdate('personnages', `name=eq.${encodeURIComponent(c.name)}`, {
        requisition: JSON.stringify({ compagnieId, sectionId, deadline, statut: 'convoque' })
      }).catch(() => {});
    }
  }
  showToast('Réquisition lancée', '24 citoyens tirés au sort et convoqués.', true, true);
  addExternalEvent('📯 Réquisition civile : 24 citoyens ont été convoqués pour renforcer la Section ' + section.numero + '.');
}

// Le civil convoque se presente a son affectation (doit etre physiquement a la caserne, avant le delai)
async function doSePresenterAffectation() {
  const req = state.char?.requisition ? (typeof state.char.requisition === 'string' ? JSON.parse(state.char.requisition) : state.char.requisition) : null;
  if (!req || req.statut !== 'convoque') { showToast('Aucune convocation en attente', '', false); return; }
  if (Date.now() > req.deadline) { showToast('Trop tard', 'Le délai de présentation est dépassé.', false); return; }
  if (state.currentBuilding !== 'caserne-militaire') { showToast('Présentez-vous à la caserne', '', false); return; }

  const pays = state.country || 'republic';
  const compagnie = (await sbGetCompagnies(pays).catch(() => [])).find(c => c.id === req.compagnieId);
  const section = compagnie?.sections.find(s => s.id === req.sectionId);
  const entree = section?.civilsRequisitionnes?.find(c => c.nom === state.char.name);
  if (entree) entree.statut = 'affecte';
  if (compagnie) await sbSaveCompagnie(req.compagnieId, compagnie);

  req.statut = 'affecte';
  state.char.requisition = req;
  if (typeof sbUpdate === 'function') await sbUpdate('personnages', `name=eq.${encodeURIComponent(state.char.name)}`, { requisition: JSON.stringify(req) }).catch(() => {});
  showToast('Affectation confirmée', 'Vous rejoignez la Section ' + (section?.numero||'?') + ' pour la durée de la mobilisation.', true, true);
  addJournalEntry('Présenté(e) à mon affectation militaire (réquisition civile).', 'event-good');
}

// Verifie chaque jour les convocations expirees non honorees ⇒ desertion publique
async function verifierDesertionsQuotidien(pays) {
  const compagnies = await sbGetCompagnies(pays).catch(() => []);
  for (const c of compagnies) {
    for (const s of (c.sections || [])) {
      for (const entree of (s.civilsRequisitionnes || [])) {
        if (entree.statut === 'convoque' && Date.now() > entree.deadline) {
          entree.statut = 'deserteur';
          await sbSaveCompagnie(c.id, c);
          if (typeof sbUpdate === 'function') {
            await sbUpdate('personnages', `name=eq.${encodeURIComponent(entree.nom)}`, {
              requisition: JSON.stringify({ compagnieId: c.id, sectionId: s.id, statut: 'deserteur' })
            }).catch(() => {});
          }
          addExternalEvent('🚨 ' + entree.nom + ' a été déclaré(e) DÉSERTEUR(SE) pour ne pas s\'être présenté(e) à sa réquisition.');
        }
      }
    }
  }
}

// ---- LE LIEUTENANT FAIT REMONTER SON RAPPORT DE RENSEIGNEMENT AU CAPITAINE ----
async function ouvrirRemonterRenseignement() {
  if (state.poste?.id !== 'lieutenant') { showToast('Réservé à un Lieutenant', '', false); return; }
  const rapports = typeof sbGetRapportsRenseignementNonRemontes === 'function' ? await sbGetRapportsRenseignementNonRemontes(state.char?.name).catch(() => []) : [];

  document.getElementById('postes-modal-title').textContent = 'Rapports de renseignement à transmettre';
  let html = '<div style="padding:1rem">';
  if (rapports.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucun rapport en attente de transmission.</div>';
  } else {
    rapports.forEach(r => {
      html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.6rem;margin-bottom:.5rem">';
      html += '<div style="font-size:.82rem;color:#e0d5b8;margin-bottom:.4rem">Rapport sur ' + r.nomCible + '</div>';
      html += '<button onclick="confirmerRemonteeRenseignement(\'' + r.id + '\')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.72rem;padding:.35rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Transmettre à mon Capitaine</button>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerRemonteeRenseignement(rapportId) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const compagnie = (await sbGetCompagnies(state.country).catch(() => [])).find(c => c.id === state.poste.compagnieId);
  const capitaineNom = compagnie?.capitaineNom;
  if (!capitaineNom) { showToast('Aucun Capitaine en poste', 'Impossible de transmettre pour l\'instant.', false); return; }

  const rows = await sbGet('rapports_renseignement', `id=eq.${encodeURIComponent(rapportId)}`).catch(() => []);
  const rapport = rows?.[0]?.data;
  if (rapport && typeof sbSendMail === 'function') {
    await sbSendMail(state.char?.name || 'Lieutenant', capitaineNom, 'Rapport de renseignement transmis — ' + rapport.nomCible,
      rapport.contenu, typeof formatDateHeureJeu==='function'?formatDateHeureJeu():'').catch(()=>{});
  }
  await sbMarquerRapportRemonte(rapportId);
  showToast('Rapport transmis', 'Votre Capitaine a été informé.', true, true);
  addJournalEntry('Rapport de renseignement transmis à mon Capitaine.', 'event-info');
}

// =====================
// ENGAGEMENT VOLONTAIRE COMME OFFICIER — PJ -> validation Commandant (compagnie) -> affectation Capitaine (section)
// =====================
async function doEngagerOfficier() {
  if (['lieutenant','capitaine','commandant'].includes(state.poste?.id)) { showToast('Déjà officier', 'Vous occupez déjà un poste militaire.', false); return; }
  const pays = state.country || 'republic';
  const id = await sbCreerEngagement({ pays, nom: state.char?.name, jour: state.day || 1 });
  const commandantNom = await getTitulairePoste('commandant', null, pays);
  if (commandantNom && typeof sbSendMail === 'function') {
    await sbSendMail(state.char?.name || 'Un citoyen', commandantNom, 'Demande d\'engagement comme officier',
      state.char?.name + ' souhaite s\'engager comme officier. Rendez-vous à la Salle de Commandement pour traiter les engagements en attente.',
      typeof formatDateHeureJeu==='function'?formatDateHeureJeu():'').catch(()=>{});
  }
  showToast('Demande envoyée', commandantNom ? 'Le Commandant a été notifié.' : 'Aucun Commandant en poste actuellement — votre demande reste en attente.', true, true);
  addJournalEntry('Demande d\'engagement comme officier envoyée.', 'event-info');
}

// Le Commandant traite les demandes d'engagement : choisit la compagnie d'affectation
async function ouvrirTraiterEngagements() {
  if (state.poste?.id !== 'commandant') { showToast('Réservé au Commandant', '', false); return; }
  const pays = state.country || 'republic';
  const engagements = await sbGetEngagementsPays(pays, 'attente_commandant').catch(() => []);
  const compagnies = await sbGetCompagnies(pays).catch(() => []);

  document.getElementById('postes-modal-title').textContent = 'Engagements en attente';
  let html = '<div style="padding:1rem">';
  if (engagements.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucune demande d\'engagement en attente.</div>';
  } else if (compagnies.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucune compagnie existante pour affecter ces engagements.</div>';
  } else {
    engagements.forEach(e => {
      html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.6rem;margin-bottom:.5rem">';
      html += '<div style="font-size:.85rem;color:#e0d5b8;margin-bottom:.4rem">' + e.nom + '</div>';
      html += '<select id="compagnie-' + e.id + '" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-size:.8rem;outline:none;margin-bottom:.4rem">';
      compagnies.forEach(c => html += '<option value="' + c.id + '">' + c.id + (c.capitaineNom ? ' (Cap. ' + c.capitaineNom + ')' : ' (sans capitaine)') + '</option>');
      html += '</select>';
      html += '<button onclick="confirmerAffectationCompagnie(\'' + e.id + '\')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.72rem;padding:.35rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Affecter à cette compagnie</button>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerAffectationCompagnie(engagementId) {
  const compagnieId = document.getElementById('compagnie-' + engagementId)?.value;
  if (!compagnieId) return;
  document.getElementById('modal-postes')?.classList.remove('open');
  const pays = state.country || 'republic';
  const compagnie = (await sbGetCompagnies(pays).catch(() => [])).find(c => c.id === compagnieId);
  const rows = await sbGet('engagements_militaires', `id=eq.${encodeURIComponent(engagementId)}`).catch(() => []);
  const engagement = rows?.[0]?.data;
  if (!engagement) return;

  await sbMajEngagement(engagementId, 'attente_capitaine', { compagnieId });
  if (compagnie?.capitaineNom && typeof sbSendMail === 'function') {
    await sbSendMail('Commandement', compagnie.capitaineNom, 'Nouvel engagé à affecter',
      engagement.nom + ' vous est affecté par le Commandant. Rendez-vous au Corps de Garde pour l\'installer dans une section.',
      typeof formatDateHeureJeu==='function'?formatDateHeureJeu():'').catch(()=>{});
  }
  showToast('Engagé affecté à la compagnie', compagnie?.capitaineNom ? 'Le Capitaine a été notifié.' : 'Cette compagnie n\'a pas encore de Capitaine — en attente.', true, true);
  addJournalEntry(engagement.nom + ' affecté à la compagnie ' + compagnieId + '.', 'event-info');
}

// Le Capitaine installe un engage affecte a sa compagnie comme lieutenant d'une section
async function ouvrirAffecterEngage() {
  if (state.poste?.id !== 'capitaine') { showToast('Réservé à un Capitaine', '', false); return; }
  const pays = state.country || 'republic';
  const engagements = await sbGetEngagementsPays(pays, 'attente_capitaine').catch(() => []);
  const mesEngagements = engagements.filter(e => e.compagnieId === state.poste.compagnieId);
  const compagnie = (await sbGetCompagnies(pays).catch(() => [])).find(c => c.id === state.poste.compagnieId);
  const sectionsVacantes = (compagnie?.sections || []).filter(s => !s.lieutenantNom);

  document.getElementById('postes-modal-title').textContent = 'Affecter un engagé';
  let html = '<div style="padding:1rem">';
  if (mesEngagements.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucun engagé en attente pour votre compagnie.</div>';
  } else if (sectionsVacantes.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Toutes vos sections ont déjà un lieutenant.</div>';
  } else {
    mesEngagements.forEach(e => {
      html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.6rem;margin-bottom:.5rem">';
      html += '<div style="font-size:.85rem;color:#e0d5b8;margin-bottom:.4rem">' + e.nom + '</div>';
      html += '<select id="section-' + e.id + '" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-size:.8rem;outline:none;margin-bottom:.4rem">';
      sectionsVacantes.forEach(s => html += '<option value="' + s.id + '">' + s.id + '</option>');
      html += '</select>';
      html += '<button onclick="confirmerAffectationSection(\'' + e.id + '\')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.72rem;padding:.35rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Nommer Lieutenant de cette section</button>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerAffectationSection(engagementId) {
  const sectionId = document.getElementById('section-' + engagementId)?.value;
  if (!sectionId) return;
  document.getElementById('modal-postes')?.classList.remove('open');
  const pays = state.country || 'republic';
  const rows = await sbGet('engagements_militaires', `id=eq.${encodeURIComponent(engagementId)}`).catch(() => []);
  const engagement = rows?.[0]?.data;
  if (!engagement) return;

  const compagnie = (await sbGetCompagnies(pays).catch(() => [])).find(c => c.id === engagement.compagnieId);
  const section = compagnie?.sections.find(s => s.id === sectionId);
  if (!section) return;
  section.lieutenantNom = engagement.nom;
  await sbSaveCompagnie(engagement.compagnieId, compagnie);
  await sbMajEngagement(engagementId, 'affecte', {});

  if (typeof sbSendMail === 'function') {
    await sbSendMail('Commandement', engagement.nom, 'Nomination confirmée',
      'Vous êtes désormais Lieutenant de la section ' + sectionId + '.', typeof formatDateHeureJeu==='function'?formatDateHeureJeu():'').catch(()=>{});
  }
  showToast('Engagé affecté', engagement.nom + ' est nommé Lieutenant de la section ' + sectionId + '.', true, true);
  addExternalEvent('🎖 ' + engagement.nom + ' est nommé Lieutenant après engagement volontaire.');
}

async function ouvrirRechercheMilitaireDepuisMinistere() {
  if (state.poste?.id !== 'min_def') { showToast('Réservé au Ministre de la Défense', '', false); return; }
  const pays = state.country || 'republic';
  const budgetNat = await chargerBudgetNational(pays);
  const enCours = budgetNat.rechercheMilitaire?.enCours;

  document.getElementById('postes-modal-title').textContent = 'Financer la recherche militaire';
  let html = '<div style="padding:1rem">';
  if (enCours) {
    html += '<div style="font-size:.85rem;color:#8a8060">Recherche déjà en cours sur : <strong style="color:#C9A84C">' + enCours.arme + '</strong>, achèvement Jour ' + enCours.jourFin + '.</div>';
  } else {
    html += '<div style="font-size:.78rem;color:#8a8060;margin-bottom:.8rem">Financé directement depuis votre caisse ministérielle (sans passer par la caserne). ' + DUREE_RECHERCHE_JOURS + ' jours, ' + COUT_RECHERCHE.toLocaleString('fr-FR') + ' FR.</div>';
    const armes = [{id:'corps_a_corps',label:'Corps à corps'},{id:'arme_de_poing',label:'Arme de poing'},{id:'mitraillette',label:'Mitraillette'}];
    armes.forEach(a => {
      html += '<button onclick="confirmerRechercheMilitaireDepuisMinistere(\'' + a.id + '\')" style="display:block;width:100%;text-align:left;margin-bottom:.4rem;padding:.6rem .7rem;border:1px solid #2a2010;background:transparent;color:#c0b090;cursor:pointer;font-size:.82rem">' + a.label + '</button>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerRechercheMilitaireDepuisMinistere(arme) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const pays = state.country || 'republic';
  const montantVerse = await debiterCaisseBatimentPlafonne(pays, 'gouvernement-min_def', COUT_RECHERCHE);
  if (montantVerse < COUT_RECHERCHE) { showToast('Budget insuffisant', 'Votre caisse ministérielle ne couvre pas le coût de la recherche.', false); return; }

  const budgetNat = await chargerBudgetNational(pays);
  budgetNat.rechercheMilitaire = { enCours: { arme, jourDebut: state.day, jourFin: state.day + DUREE_RECHERCHE_JOURS, dateFin: Date.now() + DUREE_RECHERCHE_JOURS * 86400000 } };
  await sbSaveBudgetNational(pays, budgetNat);
  showToast('Recherche lancée', 'Financée directement par le Ministère. Achèvement dans ' + DUREE_RECHERCHE_JOURS + ' jours.', true, true);
  addJournalEntry('Recherche militaire financée par le Ministère sur : ' + arme + ' (-' + COUT_RECHERCHE + ' FR).', 'event-info');
}

// =====================
// GESTION DU QHS — budget dedie, liste des prisonniers, actions (transfert/conditions/torture)
// =====================
async function ouvrirGestionQHS() {
  if (state.poste?.id !== 'min_just') { showToast('Réservé au Ministre de la Justice', '', false); return; }
  document.getElementById('postes-modal-title').textContent = 'Gestion du QHS';
  let html = '<div style="padding:1rem">';
  html += '<button onclick="ouvrirBudgetQHS()" style="width:100%;margin-bottom:.5rem;font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.06em;padding:.55rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Budget du QHS</button>';
  html += '<button onclick="ouvrirListePrisonniersQHS()" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.06em;padding:.55rem;border:1px solid #5a8ad0;background:transparent;color:#5a8ad0;cursor:pointer">Liste des prisonniers</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function ouvrirBudgetQHS() {
  const pays = state.country || 'republic';
  const maCaisse = await chargerCaisseBatiment(pays, 'gouvernement-min_just');
  const caisseQHS = await chargerCaisseBatiment(pays, 'qhs-prison');
  const budgetNat = await chargerBudgetNational(pays);
  const virementActuel = budgetNat.virementJournalierQHS || 0;

  document.getElementById('postes-modal-title').textContent = 'Budget du QHS';
  let html = '<div style="padding:1rem">';
  html += '<div style="display:flex;justify-content:space-between;margin-bottom:1rem;font-family:Bebas Neue,sans-serif;font-size:.9rem">';
  html += '<span style="color:#C9A84C">Ma caisse (Ministère) : ' + (maCaisse.solde||0).toLocaleString('fr-FR') + ' FR</span>';
  html += '<span style="color:#8a8060">Caisse du QHS : ' + (caisseQHS.solde||0).toLocaleString('fr-FR') + ' FR</span>';
  html += '</div>';

  html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.7rem;margin-bottom:.7rem">';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.76rem;color:#e0d5b8;margin-bottom:.4rem">VIREMENT JOURNALIER AUTOMATIQUE</div>';
  html += '<div style="font-size:.7rem;color:#8a8060;margin-bottom:.5rem">Actuellement : ' + virementActuel.toLocaleString('fr-FR') + ' FR/jour.</div>';
  html += '<input id="montant-virement-qhs-j" type="number" min="0" value="' + virementActuel + '" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-size:.85rem;outline:none;box-sizing:border-box;margin-bottom:.5rem"/>';
  html += '<button onclick="confirmerVirementJournalierQHS()" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.72rem;padding:.4rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Fixer ce montant</button>';
  html += '</div>';

  html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.7rem">';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.76rem;color:#e0d5b8;margin-bottom:.4rem">VIREMENT PONCTUEL</div>';
  html += '<input id="montant-virement-qhs-p" type="number" min="0" value="0" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-size:.85rem;outline:none;box-sizing:border-box;margin-bottom:.5rem"/>';
  html += '<button onclick="confirmerVirementPonctuelQHS()" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.72rem;padding:.4rem;border:1px solid #5a8ad0;background:transparent;color:#5a8ad0;cursor:pointer">Transférer maintenant</button>';
  html += '</div></div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerVirementJournalierQHS() {
  const montant = Math.max(0, parseInt(document.getElementById('montant-virement-qhs-j')?.value || '0'));
  document.getElementById('modal-postes')?.classList.remove('open');
  const pays = state.country || 'republic';
  const budgetNat = await chargerBudgetNational(pays);
  budgetNat.virementJournalierQHS = montant;
  await sbSaveBudgetNational(pays, budgetNat);
  showToast('Virement journalier fixé', montant.toLocaleString('fr-FR') + ' FR/jour vers le QHS.', true, true);
}

async function confirmerVirementPonctuelQHS() {
  const montant = Math.max(0, parseInt(document.getElementById('montant-virement-qhs-p')?.value || '0'));
  document.getElementById('modal-postes')?.classList.remove('open');
  if (montant <= 0) return;
  const pays = state.country || 'republic';
  const montantVerse = await debiterCaisseBatimentPlafonne(pays, 'gouvernement-min_just', montant);
  if (montantVerse <= 0) { showToast('Caisse insuffisante', '', false); return; }
  await crediterCaisseBatiment(pays, 'qhs-prison', montantVerse);
  showToast('Virement effectué', montantVerse.toLocaleString('fr-FR') + ' FR transférés vers le QHS.', true, true);
}

async function ouvrirListePrisonniersQHS() {
  const pays = state.country || 'republic';
  document.getElementById('postes-modal-title').textContent = 'Prisonniers du QHS';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a8060;font-style:italic">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const prisonniers = await sbGetPrisonniersQHS(pays).catch(() => []);
  let html = '<div style="padding:1rem">';
  if (prisonniers.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucun détenu au QHS actuellement.</div>';
  } else {
    prisonniers.forEach(p => {
      html += '<div onclick="ouvrirFichePrisonnierQHS(\'' + p.id + '\')" style="display:flex;align-items:center;gap:.6rem;border:1px solid #2a2010;background:#0f0d05;padding:.5rem .7rem;margin-bottom:.4rem;cursor:pointer">';
      html += p.photoUrl ? '<img src="' + p.photoUrl + '" style="width:36px;height:36px;border-radius:50%;object-fit:cover;border:1px solid #4a3a1a"/>' : '<div style="width:36px;height:36px;border-radius:50%;background:#1a1610;display:flex;align-items:center;justify-content:center"><i class="ti ti-user" style="color:#5a5040"></i></div>';
      html += '<div><div style="font-size:.85rem;color:#e0d5b8">' + p.nom + '</div><div style="font-size:.7rem;color:#a89870">' + p.raison + '</div></div>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function ouvrirFichePrisonnierQHS(prisonnierId) {
  const rows = await sbGet('prisonniers_qhs', `id=eq.${encodeURIComponent(prisonnierId)}`).catch(() => []);
  const p = rows?.[0]?.data;
  if (!p) return;

  document.getElementById('postes-modal-title').textContent = p.nom;
  let html = '<div style="padding:1rem;text-align:center">';
  html += p.photoUrl ? '<img src="' + p.photoUrl + '" style="width:90px;height:90px;border-radius:50%;object-fit:cover;border:2px solid #4a3a1a;margin-bottom:.7rem"/>' : '<div style="width:90px;height:90px;border-radius:50%;background:#1a1610;display:flex;align-items:center;justify-content:center;margin:0 auto .7rem"><i class="ti ti-user" style="font-size:2rem;color:#5a5040"></i></div>';
  html += '<div style="font-size:.85rem;color:#c0b090;margin-bottom:1rem">Motif : ' + p.raison + '</div>';
  html += '<button onclick="doTransfererPrisonNormale(\'' + prisonnierId + '\')" style="width:100%;margin-bottom:.4rem;font-family:Bebas Neue,sans-serif;font-size:.75rem;padding:.5rem;border:1px solid #5a8ad0;background:transparent;color:#5a8ad0;cursor:pointer">Transférer vers une prison normale</button>';
  html += '<button onclick="doAmeliorerConditionsQHS(\'' + prisonnierId + '\')" style="width:100%;margin-bottom:.4rem;font-family:Bebas Neue,sans-serif;font-size:.75rem;padding:.5rem;border:1px solid #4a8a4a;background:transparent;color:#6ab858;cursor:pointer">Améliorer ses conditions de détention</button>';
  html += '<button onclick="doTorturerPrisonnierQHS(\'' + prisonnierId + '\')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.75rem;padding:.5rem;border:1px solid #8a2020;background:transparent;color:#cc4444;cursor:pointer">Le faire torturer</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

// ---- Transfert vers une prison normale (pas de reduction de peine, ouvre droit a un bonus avocat futur) ----
async function doTransfererPrisonNormale(prisonnierId) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const rows = await sbGet('prisonniers_qhs', `id=eq.${encodeURIComponent(prisonnierId)}`).catch(() => []);
  const p = rows?.[0]?.data;
  if (!p) return;
  await sbMajPrisonnierQHS(prisonnierId, 'transfere', {});
  if (typeof sbUpdate === 'function') await sbUpdate('personnages', `name=eq.${encodeURIComponent(p.nom)}`, { detention_qhs: JSON.stringify({ enQHS: false, eligibleBonusAvocat: true }) }).catch(() => {});
  showToast('Transfert effectué', p.nom + ' est transféré(e) vers une prison normale. Éligible à un bonus de réduction de peine via avocat.', true, true);
  addJournalEntry(p.nom + ' transféré(e) du QHS vers une prison normale.', 'event-info');
}

// ---- Ameliorer les conditions de detention ----
async function doAmeliorerConditionsQHS(prisonnierId) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const pays = state.country || 'republic';
  const cout = 500;
  const montantVerse = await debiterCaisseBatimentPlafonne(pays, 'qhs-prison', cout);
  if (montantVerse < cout) { showToast('Caisse insuffisante', 'La caisse du QHS ne couvre pas ce coût (' + cout + ' FR).', false); return; }

  const rows = await sbGet('prisonniers_qhs', `id=eq.${encodeURIComponent(prisonnierId)}`).catch(() => []);
  const p = rows?.[0]?.data;
  if (!p) return;

  const persoRows = await sbGet('personnages', `name=eq.${encodeURIComponent(p.nom)}&select=moral`).catch(() => []);
  const moralActuel = persoRows?.[0]?.moral ?? 50;
  await sbUpdate('personnages', `name=eq.${encodeURIComponent(p.nom)}`, {
    moral: Math.min(100, moralActuel + 15),
    detention_qhs: JSON.stringify({ enQHS: true, paLimite1Jour: false, conditionsAmeliorees: true })
  }).catch(() => {});
  showToast('Conditions améliorées', p.nom + ' bénéficie de meilleures conditions. +15 Moral, PA de récupération relevés. -' + cout + ' FR.', true, true);
  addJournalEntry('Conditions de détention améliorées pour ' + p.nom + ' (-' + cout + ' FR).', 'event-good');
}

// ---- Torture : information extraite au prix de consequences reelles pour le detenu ET le MJ ----
async function doTorturerPrisonnierQHS(prisonnierId) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const rows = await sbGet('prisonniers_qhs', `id=eq.${encodeURIComponent(prisonnierId)}`).catch(() => []);
  const p = rows?.[0]?.data;
  if (!p) return;
  const pays = state.country || 'republic';
  const mjNom = state.char?.name;

  // Consequences sur le detenu : perte de tous ses indices, PA plafonnes a 1 le lendemain uniquement
  await sbUpdate('personnages', `name=eq.${encodeURIComponent(p.nom)}`, {
    inf: 0, pop: 0, dis: 0, moral: 0,
    detention_qhs: JSON.stringify({ enQHS: true, paLimite1Jour: true })
  }).catch(() => {});

  // Sanction immediate et automatique sur le MJ : POP et INF a 10
  state.pop = 10; state.inf = 10;
  updateUI();

  // Trace exploitable par les rumeurs et les enquetes
  if (typeof tracerActionPourRumeur === 'function') tracerActionPourRumeur('torture_qhs', p.nom);
  if (typeof sbCreerRumeurPolitique === 'function') {
    await sbCreerRumeurPolitique({ cible: mjNom, contenu: 'Le Ministre de la Justice ferait torturer des détenus au QHS.', auteur: 'Anonyme', jour: state.day || 1, popPerdu: 40 }).catch(() => {});
  }

  // Alerte automatique au president et au premier ministre si le MJ est toujours en poste
  const presidentNom = await getTitulairePoste('president', null, pays);
  const pmNom = await getTitulairePoste('pm', null, pays);
  const alerte = 'Le Ministre de la Justice (' + mjNom + ') est empêtré(e) dans une affaire de torture au QHS. Sa popularité et sa légitimité sont au plus bas. À vous de décider s\'il faut le/la démettre.';
  if (presidentNom && typeof sbSendMail === 'function') await sbSendMail('Alerte confidentielle', presidentNom, 'Affaire de torture au QHS', alerte, typeof formatDateHeureJeu==='function'?formatDateHeureJeu():'').catch(()=>{});
  if (pmNom && typeof sbSendMail === 'function') await sbSendMail('Alerte confidentielle', pmNom, 'Affaire de torture au QHS', alerte, typeof formatDateHeureJeu==='function'?formatDateHeureJeu():'').catch(()=>{});

  showToast('Torture ordonnée', p.nom + ' perd tous ses indices. Votre POP/INF chutent à 10. Une trace reste exploitable.', false);
  addJournalEntry('Torture ordonnée contre ' + p.nom + ' — conséquences lourdes.', 'event-bad');
}
