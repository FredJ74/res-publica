function genererStatsHtml() {
  const co = COUNTRIES[state.country];
  const cur = co?.cur || 'FR';
  const char = state.char;
  const ar = ARCHETYPES.find(x => x.id === char?.archetype);

  const stats = [
    { label: 'Influence',   val: state.inf  || 0, max: 100, col: '#4a6aaa', icon: 'ti-crown',       desc: 'Poids politique et réseau' },
    { label: 'Popularité',  val: state.pop  || 0, max: 100, col: '#aa6a4a', icon: 'ti-speakerphone', desc: 'Soutien de la population' },
    { label: 'Discrétion',  val: state.dis  || 0, max: 100, col: '#8a4aaa', icon: 'ti-eye-off',      desc: 'Capacité à agir sans être détecté' },
    { label: 'Santé',       val: state.hp   || 0, max: 100, col: '#aa4a4a', icon: 'ti-heart',        desc: 'État physique' },
    { label: 'Moral',       val: state.moral|| 0, max: 100, col: '#6a8aaa', icon: 'ti-brain',        desc: 'Résistance psychologique' },
  ];

  const persoStats = char?.stats || {};
  const STAT_DEFS_LOCAL = [
    { k:'INT', n:'Intelligence', col:'#6a8aaa', i:'ti-brain' },
    { k:'CHA', n:'Charisme',     col:'#aa8a4a', i:'ti-speakerphone' },
    { k:'VOL', n:'Volonté',      col:'#4a8a6a', i:'ti-flame' },
    { k:'PER', n:'Perception',   col:'#4a6aaa', i:'ti-eye' },
    { k:'DUP', n:'Duplicité',    col:'#8a4a8a', i:'ti-masks-theater' },
    { k:'ENT', n:'Entregent',    col:'#8a6a4a', i:'ti-network' },
  ];

  const barsHtml = stats.map(s => {
    const pct = Math.round(s.val);
    return '<div style="margin-bottom:.5rem">' +
      '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:.2rem">' +
        '<div style="display:flex;align-items:center;gap:.4rem">' +
          '<i class="ti ' + s.icon + '" style="font-size:.75rem;color:' + s.col + '"></i>' +
          '<span style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;color:#a09060">' + s.label + '</span>' +
        '</div>' +
        '<span style="font-family:Bebas Neue,sans-serif;font-size:.82rem;color:' + s.col + '">' + pct + '</span>' +
      '</div>' +
      '<div style="height:4px;background:#1a1810;border-radius:2px">' +
        '<div style="height:100%;width:' + pct + '%;background:' + s.col + ';border-radius:2px;transition:width .3s"></div>' +
      '</div>' +
      '<div style="font-size:.6rem;color:#9a8a68;margin-top:.1rem">' + s.desc + '</div>' +
    '</div>';
  }).join('');

  const persoHtml = STAT_DEFS_LOCAL.map(s => {
    const val = persoStats[s.k] || 0;
    return '<div style="text-align:center">' +
      '<div style="font-size:.62rem;color:' + s.col + ';font-family:Bebas Neue,sans-serif;letter-spacing:.06em">' + s.k + '</div>' +
      '<div style="font-size:1rem;color:#f0ead6;font-family:Bebas Neue,sans-serif">' + val + '</div>' +
      '<div style="font-size:.58rem;color:#9a8a68">' + s.n + '</div>' +
    '</div>';
  }).join('');

  return '<div style="padding:.6rem 1rem">' +
      '<div style="font-size:.7rem;color:#8a8060;margin-bottom:.8rem;font-style:italic">' +
        (ar?.name || '') + ' · ' + (co?.n || '') +
        (state.poste?.name ? ' · ' + state.poste.name : '') +
      '</div>' +
      '<div style="font-family:Bebas Neue,sans-serif;font-size:.65rem;letter-spacing:.15em;color:#9a8a68;margin-bottom:.5rem">INDICES</div>' +
      barsHtml +
      '<div style="border-top:1px solid #2a2010;margin:.6rem 0"></div>' +
      '<div style="font-family:Bebas Neue,sans-serif;font-size:.65rem;letter-spacing:.15em;color:#9a8a68;margin-bottom:.5rem">ATTRIBUTS PERSONNELS</div>' +
      '<div style="display:grid;grid-template-columns:repeat(6,1fr);gap:.4rem">' + persoHtml + '</div>' +
      '<div style="border-top:1px solid #2a2010;margin:.6rem 0"></div>' +
      '<div style="display:flex;justify-content:space-between;font-size:.72rem;color:#8a8060">' +
        '<span>💰 Liquide : <strong style="color:#C9A84C">' + (state.liquide||0).toLocaleString('fr-FR') + ' ' + cur + '</strong></span>' +
        '<span>🏦 Banque : <strong style="color:#C9A84C">' + (state.banque||0).toLocaleString('fr-FR') + ' ' + cur + '</strong></span>' +
      '</div>' +
    '</div>';
}

function ouvrirStatsPerso() {
  const char = state.char;
  document.getElementById('postes-modal-title').textContent = 'Statistiques — ' + (char?.name || 'Mon Personnage');
  document.getElementById('postes-body').innerHTML = genererStatsHtml();
  document.getElementById('modal-postes').classList.add('open');
}

function getPnjAvatar(pnj, empireColor) {
  // Photo escort selon empire si pas de photoUrl
  if (!pnj.photoUrl && pnj.job === 'escort') {
    const escortPhotos = {
      republic: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/escort-republic.png',
      narco:    'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/escort-narco.png',
      soviet:   'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/escort-soviet.png',
      khalija:  'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/escort-khalija.png',
    };
    pnj.photoUrl = escortPhotos[state.country] || '';
    pnj.photoPos = '50% 10%';
  }
    if (pnj.photoUrl) {
    const col = empireColor || '#C9A84C';
    const safeName = (pnj.name || '').replace(' (PNJ)', '');
    return '<div style="flex-shrink:0;text-align:center">' +
      '<div onclick="ouvrirPhotoPleinEcran(this)" data-url="' + pnj.photoUrl + '" data-nom="' + safeName + '" ' +
      'style="width:90px;height:90px;border-radius:6px;border:2px solid ' + col + ';overflow:hidden;cursor:pointer;position:relative">' +
      '<img src="' + pnj.photoUrl + '" style="width:100%;height:100%;object-fit:cover;object-position:' + (pnj.photoPos || '50% 15%') + '"/>' +
      '<div style="position:absolute;bottom:0;right:0;background:rgba(0,0,0,.6);padding:2px 4px;font-size:9px;color:' + col + '">🔍</div>' +
      '</div></div>';
  }
  const av = PNJ_AVATAR[pnj.job] || PNJ_AVATAR.default;
  const col = empireColor || av.color;
  return '<div style="width:56px;height:56px;border-radius:50%;border:2px solid ' + col + ';background:rgba(0,0,0,0.3);display:flex;align-items:center;justify-content:center;flex-shrink:0">' +
    '<i class="ti ' + av.icon + '" style="font-size:1.4rem;color:' + col + '"></i>' +
    '</div>';
}

function ouvrirPhotoPleinEcran(el) {
  const url = el.dataset?.url || el;
  const nom = el.dataset?.nom || '';
  // Créer overlay plein écran
  const overlay = document.createElement('div');
  overlay.id = 'photo-overlay';
  overlay.onclick = () => overlay.remove();
  overlay.style.cssText = 'position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,0.92);z-index:99999;display:flex;flex-direction:column;align-items:center;justify-content:center;cursor:pointer';
  overlay.innerHTML =
    '<div style="font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;color:#C9A84C;margin-bottom:.8rem">' + nom.replace(' (PNJ)','') + '</div>' +
    '<img src="' + url + '" style="max-width:90vw;max-height:85vh;object-fit:contain;border:1px solid #3a2a10"/>' +
    '<div style="font-size:.65rem;color:#4a4030;margin-top:.6rem">Cliquer pour fermer</div>';
  document.body.appendChild(overlay);
}

function openPnjModal(encodedPnj) {
  let pnj;
  try { pnj = JSON.parse(decodeURIComponent(encodedPnj)); }
  catch(e) { return; }

  // Cadavre — photo plein écran uniquement, pas de dialogue
  if (pnj.terrainPnjId === 'cadavre') {
    ouvrirPhotoCadavre(JSON.stringify({
      photoUrl: pnj.photoUrl, photoPos: pnj.photoPos,
      role: pnj.role, trait: pnj.trait
    }));
    return;
  }

  const isPJ = pnj.isPJ === true;
  document.getElementById('modal-pnj').classList.add('open');
  document.getElementById('pnj-modal-title').textContent = pnj.name?.replace(' (PNJ)', '') || 'Inconnu';

  // Avatar CSS par type de PNJ
  const empireCol = COUNTRIES[state.country]?.col || '#C9A84C';
  const avatarHtml = typeof getPnjAvatar === 'function' ? getPnjAvatar(pnj, empireCol) : '';
  const avatarEl = document.getElementById('pnj-avatar-container');
  if (avatarEl) avatarEl.innerHTML = avatarHtml;

  // Rôle et trait de personnalité
  const roleEl = document.getElementById('pnj-role-display');
  if (roleEl) roleEl.textContent = pnj.role?.replace(' (PNJ)', '') || '';
  const traitEl = document.getElementById('pnj-trait-display');
  const pnjKey = pnj.name?.replace(' (PNJ)', '').trim();
  const perso = typeof PNJ_PERSONALITIES !== 'undefined' ? PNJ_PERSONALITIES[pnjKey] : null;
  if (traitEl) traitEl.textContent = perso?.trait || '';
  const speech = document.getElementById('pnj-speech');
  speech.innerHTML = '<div class="pnj-loading"><span class="spin"></span> En train de repondre...</div>';
  const enc = encodePnjSafe(pnj);

  let actionBtns = '';
  const pnjSafeName = pnj.name.replace(/'/g, '');
  const pnjSafeRole = (pnj.role||'').replace(/'/g, '');
  const pnjRel = pnj.rel || 'neutral';

  if (isPJ) {
    const inGroup = state.group && state.group.members && state.group.members.includes(pnj.name);
    const pnjJson = encodePnjSafe(pnj);
    actionBtns += '<button class="pnj-action-btn" onclick="document.getElementById(\'modal-pnj\').classList.remove(\'open\');ouvrirConversationAvec(\'' + pnjSafeName + '\')" style="color:#6ada6a;border-color:#2a5a2a"><i class="ti ti-message-circle" style="font-size:.85rem"></i> Parler</button>';
    actionBtns += (!inGroup
      ? '<button class="pnj-action-btn" onclick="rejoindrePJ(decodeURIComponent(\'' + pnjJson + '\'))"><i class="ti ti-users" style="font-size:.85rem"></i> Rejoindre ce joueur</button>'
      : '<button class="pnj-action-btn" onclick="quitterGroupe()"><i class="ti ti-user-minus" style="font-size:.85rem"></i> Quitter le groupe</button>');
    actionBtns += '<button class="pnj-action-btn" onclick="addContactByName(\'' + pnjSafeName + '\',\'' + pnjSafeRole + '\',\'' + pnjRel + '\')"><i class="ti ti-user-plus" style="font-size:.85rem"></i> Ajouter au repertoire</button>';
    actionBtns += '<button class="pnj-action-btn" onclick="document.getElementById(\'modal-pnj\').classList.remove(\'open\');composerMailPour(\'' + pnjSafeName + '\')"><i class="ti ti-mail" style="font-size:.85rem"></i> Envoyer un mail</button>';
  }

  if (!isPJ) {
    const dejaDansRep = (state.contacts || []).some(c => c.name === pnj.name);
    if (!dejaDansRep) {
      actionBtns += '<button class="pnj-action-btn" onclick="addContactByName(\'' + pnjSafeName + '\',\'' + pnjSafeRole + '\',\'' + pnjRel + '\')"><i class="ti ti-user-plus" style="font-size:.85rem"></i> Ajouter au repertoire</button>';
    }
  }

  actionBtns += '<button class="pnj-action-btn" onclick="ouvrirDonPnjModal(\'' + enc + '\')"><i class="ti ti-coins" style="font-size:.85rem"></i> Donner de l\'argent</button>';

  const objetsDispos = (state.inventory || []).filter(i => i.type !== 'acte_officiel');
  if (objetsDispos.length > 0) {
    actionBtns += '<button class="pnj-action-btn" onclick="ouvrirDonObjetPnjModal(\'' + enc + '\')"><i class="ti ti-package" style="font-size:.85rem"></i> Donner un objet</button>';
  }

  const tractsDispos = (state.inventory || []).filter(i => i.type === 'tract');
  if (tractsDispos.length > 0) {
    if (isPJ) {
      actionBtns += '<button class="pnj-action-btn" onclick="document.getElementById(\'modal-pnj\').classList.remove(\'open\');donnerTracts(\'' + pnjSafeName + '\')"><i class="ti ti-files" style="font-size:.85rem"></i> Donner des tracts</button>';
    } else {
      actionBtns += '<button class="pnj-action-btn" onclick="document.getElementById(\'modal-pnj\').classList.remove(\'open\');distribuerTractPNJ(\'' + pnjSafeName + '\')"><i class="ti ti-file-description" style="font-size:.85rem"></i> Distribuer un tract</button>';
    }
  }

  if (pnj.rel === 'enemy') {
    actionBtns += '<button class="pnj-action-btn" onclick="talkToPnj(\'' + enc + '\', \'confrontation\')"><i class="ti ti-sword" style="font-size:.85rem"></i> Confronter</button>';
  }


  // Recruter comme employé (tous PNJ sauf escort qui a son propre bouton)
  if (!isPJ && pnj.job !== 'escort') {
    const nomCourt = pnj.name.replace(' (PNJ)', '').replace(/'/g, '');
    const dejEmploye = (state.employes || []).some(e => e.nom === nomCourt);
    if (!dejEmploye) {
      actionBtns += '<button class="pnj-action-btn" onclick="ouvrirModalRecrutPnj(\'' + enc + '\')"><i class="ti ti-user-plus" style="font-size:.85rem"></i> Recruter comme employé</button>';
    } else {
      const empData = (state.employes || []).find(e => e.nom === nomCourt);
      if (empData && !empData.inGroupe && empData.buildingId === state.currentBuilding && empData.roomId === state.currentRoom) {
        actionBtns += '<button class="pnj-action-btn" onclick="recupererPnjDansGroupe(\'' + nomCourt + '\')"><i class="ti ti-users" style="font-size:.85rem"></i> Rejoindre le groupe</button>';
      }
      if (empData && empData.inGroupe) {
        actionBtns += '<button class="pnj-action-btn" onclick="laisserPnjEnPlace(\'' + nomCourt + '\')"><i class="ti ti-map-pin" style="font-size:.85rem"></i> Laisser ici</button>';
      }
    }
  }

  // Recruter escort
  if (pnj.job === 'escort') {
    const escortNom = pnj.name.replace(' (PNJ)', '').replace(/'/g, '');
    actionBtns += '<button class="pnj-action-btn" onclick="ouvrirRecrutementEscort(\'' + escortNom + '\')"><i class="ti ti-heart" style="font-size:.85rem"></i> Recruter comme escort</button>';
  }

  // Interroger l'hotesse des objets trouves sur ses souvenirs
  if (pnj.job === 'hotesse_objets_trouves') {
    actionBtns += '<button class="pnj-action-btn" onclick="document.getElementById(\'modal-pnj\').classList.remove(\'open\');ouvrirModalInterrogerAccueil()"><i class="ti ti-message-question" style="font-size:.85rem"></i> Demander des confidences</button>';
  }

  const encCible = encodePnjSafe(pnj);
  actionBtns += '<button class="pnj-action-btn" style="color:#aa7a30;border-color:#3a2810" onclick="document.getElementById(\'modal-pnj\').classList.remove(\'open\');ouvrirModalVoler(\'' + encCible + '\')"><i class="ti ti-fingerprint" style="font-size:.85rem"></i> Voler</button>';
  actionBtns += '<button class="pnj-action-btn" style="color:#cc4444;border-color:#3a1010" onclick="document.getElementById(\'modal-pnj\').classList.remove(\'open\');ouvrirModalAssassinat(\'' + encCible + '\')"><i class="ti ti-skull" style="font-size:.85rem"></i> Assassiner</button>';
  actionBtns += '<div id="quete-action-zone"></div>';
  // Verifier de facon non bloquante si ce PNJ correspond a une quete active
  if (!isPJ && typeof getQueteActivePourPnj === 'function') {
    const nomPnjPourQuete = pnj.name?.replace(' (PNJ)', '');
    getQueteActivePourPnj(nomPnjPourQuete).then(quete => {
      const zone = document.getElementById('quete-action-zone');
      if (zone && quete) {
        zone.innerHTML = '<button class="pnj-action-btn" style="color:#C9A84C;border-color:#8a6a20;font-weight:bold" onclick="progresserQuete(&quot;' + quete.id + '&quot;)"><i class="ti ti-search" style="font-size:.85rem"></i> 🔍 Suivre la piste (' + quete.titre + ')</button>';
      }
    }).catch(() => {});
  }
  document.getElementById('pnj-actions').innerHTML = actionBtns +
    (isPJ
      ? '<div style="margin-top:.6rem;font-size:.7rem;color:#6a5a30;font-style:italic">C\'est un vrai joueur — utilisez "Parler" (chat en temps réel) ou le mail (asynchrone). L\'IA ne répond jamais à sa place.</div>'
      : '<div style="display:flex;gap:.4rem;margin-top:.5rem">' +
        '<input id="pnj-question-libre" type="text" style="flex:1;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem .6rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none" placeholder="Posez votre question..." onkeydown="handlePnjKey(event)" />' +
        '<button onclick="envoyerQuestion()" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.4rem .7rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer"><i class="ti ti-send" style="font-size:.8rem"></i></button>' +
        '</div>');

  // Stocker l'enc pour envoyerQuestion
  state._currentPnjEnc = enc;

  // Recharger l'historique de la conversation du jour (uniquement pour les PNJ — jamais pour un vrai joueur)
  if (!isPJ) {
    const pnjNameClean = pnj.name?.replace(' (PNJ)', '').trim();
    const convKeyOpen = 'conv_' + (pnjNameClean||'pnj') + '_day' + (state.day||1);
    const histOpen = state.pnjConversations?.[convKeyOpen] || [];

    if (histOpen.length >= 2) {
      // Afficher le dernier échange
      const lastReply = histOpen.filter(h => h.role === 'assistant').slice(-1)[0];
      if (lastReply) {
        const speechEl = document.getElementById('pnj-speech');
        if (speechEl) speechEl.textContent = lastReply.content;
      }
    } else {
      talkToPnj(enc, 'bonjour');
    }
  } else {
    const speechEl = document.getElementById('pnj-speech');
    if (speechEl) speechEl.textContent = '';
  }
}

function handlePnjKey(event) {
  if (event.key === 'Enter') envoyerQuestion();
}

function envoyerQuestion(enc) {
  const input = document.getElementById('pnj-question-libre');
  if (!input) return;
  const q = input.value.trim();
  if (!q) return;
  input.value = '';
  const encToUse = enc || state._currentPnjEnc;
  if (encToUse) talkToPnj(encToUse, q);
}

async function talkToPnj(encodedPnj, action) {
  let pnj;
  try { pnj = JSON.parse(decodeURIComponent(encodedPnj)); }
  catch(e) { return; }

  if (!action || action.trim() === '') return;

  const speech = document.getElementById('pnj-speech');
  speech.innerHTML = '<div class="pnj-loading"><span class="spin"></span> En train de repondre...</div>';

  const char = state.char;
  const ar = ARCHETYPES.find(x => x.id === char?.archetype);
  const co = COUNTRIES[state.country];

  // Gestion speciale loge
  if (pnj.job === 'portier' && action === 'bonjour') {
    speech.textContent = 'Le portier vous devisage longuement a travers le judas. "Que voulez-vous ?"';
    document.getElementById('pnj-actions').innerHTML += `
      <div style="margin-top:.8rem;border-top:1px solid #2a2010;padding-top:.8rem">
        <div style="font-size:.72rem;color:#6a5a20;font-family:'Bebas Neue',sans-serif;letter-spacing:.1em;margin-bottom:.4rem">REPONDRE :</div>
        <button class="pnj-action-btn" onclick="logeDemanderResponsable()">
          <i class="ti ti-user-star" style="font-size:.85rem"></i> Je veux parler au responsable de la loge
        </button>
        <button class="pnj-action-btn" onclick="logeDemanderAdhesion()">
          <i class="ti ti-user-plus" style="font-size:.85rem"></i> Je veux faire partie des votres
        </button>
      </div>`;
    return;
  }

  // Actions predefinies
  const actionMap = {
    'bonjour':       'vous salue a son arrivee',
    'information':   'lui demande des informations sur la situation politique locale',
    'alliance':      'lui propose une alliance politique discrete',
    'confrontation': 'le confronte directement en lui reprochant ses actions'
  };
  const actionDesc = actionMap[action] || `lui pose la question suivante : "${action}"`;
  const isQuestion = !actionMap[action];

  // Si c'est un journaliste, générer une réaction au forum
  const pnjKey = pnj.name?.replace(' (PNJ)', '').trim();
  const isJournaliste = pnj.job === 'journaliste' || pnj.job === 'redacteur';
  if (isJournaliste && !action) {
    const reaction = await genererReactionJournaliste();
    if (reaction) {
      const speech = document.getElementById('pnj-speech');
      if (speech) speech.textContent = reaction.texte;
      return;
    }
  }

  // Fiche personnalité du PNJ
  const perso = PNJ_PERSONALITIES[pnjKey];
  const empireStyle = EMPIRE_STYLES[state.country] || EMPIRE_STYLES.republic;

  // Récupérer les derniers posts du forum local pour le contexte
  const recentPosts = (FORUM_TOPICS['local'] || []).slice(0, 2).map(t =>
    `"${t.title}" (par ${t.author})`).join(', ');
  const forumContext = recentPosts ? `Actualité du forum local : ${recentPosts}.` : '';

  // Événements politiques
  const politicalContext = state.poste
    ? `Le joueur occupe le poste de ${state.poste.name}.`
    : 'Le joueur n\'a pas de poste officiel.';
  const recherchéContext = state.recherche?.length > 0
    ? 'ATTENTION : le joueur est recherché par les autorités.'
    : '';

  const prompt = `Tu joues un personnage dans Res Publica, un jeu de rôle politique parodique et satirique.
L'empire est ${co?.n} (${empireStyle.tone}).
La religion locale est ${empireStyle.religion}. Le chef suprême est ${empireStyle.leader}.

Ton personnage : ${pnj.name?.replace(' (PNJ)', '')}, ${pnj.role}.
${perso ? `Ta personnalité : ${perso.trait}` : `Tu es un PNJ typique de ${co?.n}.`}
${perso ? `Ton style : ${perso.style}` : ''}
Relation avec le joueur : ${pnj.rel === 'ally' ? 'allié de confiance' : pnj.rel === 'enemy' ? 'ennemi déclaré' : 'neutre'}.

Le joueur : ${char?.name || 'Inconnu'}, ${ar?.name || 'citoyen'}.
${politicalContext} ${recherchéContext}
${forumContext}

${isQuestion ? `Le joueur te pose cette question : "${action}". Réponds en restant dans ton personnage.` : `Le joueur ${actionDesc}.`}

RÈGLES ABSOLUES :
- 2 phrases maximum, jamais plus
- Reste dans ton personnage parodique
- Intègre naturellement les éléments de l'empire (religion locale, monnaie ${empireStyle.currency}, ambiance)
- Jamais de vrais noms de dieux ou religions réelles
- Réponds UNIQUEMENT avec ta réplique, sans guillemets ni introduction`;

  // Récupérer l'historique de la conversation du jour
  const pnjKey2 = pnj.name?.replace(' (PNJ)', '').trim();
  const convKey = 'conv_' + (pnjKey2||'pnj') + '_day' + (state.day||1);
  if (!state.pnjConversations) state.pnjConversations = {};
  if (!state.pnjConversations[convKey]) state.pnjConversations[convKey] = [];
  const history = state.pnjConversations[convKey];

  // Construire les messages avec historique
  const messages = [
    { role: 'user', content: prompt }
  ];
  // Ajouter les échanges précédents (max 6 pour rester léger)
  const recentHistory = history.slice(-6);
  if (recentHistory.length > 0) {
    messages[0].content = prompt + '\n\nHistorique du jour :\n' +
      recentHistory.map(h => (h.role === 'user' ? 'Joueur: ' : pnjKey2 + ': ') + h.content).join('\n');
  }

  try {
    const resp = await fetch('/api/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: 'claude-haiku-4-5-20251001',
        max_tokens: 150,
        messages
      })
    });
    if (!resp.ok) throw new Error('HTTP ' + resp.status);
    const data = await resp.json();
    const text = data.content?.[0]?.text;
    if (text) {
      speech.textContent = text;
      // Sauvegarder dans l'historique
      history.push({ role: 'user', content: action });
      history.push({ role: 'assistant', content: text });
      state.pnjConversations[convKey] = history;
    } else { throw new Error('no text'); }
  } catch(e) {
    const fallbacks = {
      enemy:   ['Circulez, il n\'y a rien a vous dire.', 'Votre presence m\'importune.', 'Je n\'ai rien a declarer.'],
      ally:    ['Ah, vous voila ! On a des choses a discuter.', 'Je vous attendais justement.', 'Entrons dans le vif du sujet.'],
      neutral: ['Bonjour. Que puis-je faire pour vous ?', 'Oui ? J\'ecoute.', 'En quoi puis-je vous aider ?']
    };
    const list = fallbacks[pnj.rel] || fallbacks.neutral;
    speech.textContent = list[Math.floor(Math.random() * list.length)];
  }
}

function closePnjModal() {
  document.getElementById('modal-pnj').classList.remove('open');
}

function addContactByName(name, role, rel) {
  addContact({ name: name, role: role, rel: rel });
}

function addContact(pnj) {
  if (!state.contacts) state.contacts = [];
  const exists = state.contacts.find(c => c.name === pnj.name);
  if (exists) {
    showToast('Deja dans le repertoire', pnj.name + ' est deja dans vos contacts.', false);
    return;
  }
  state.contacts.push({ name: pnj.name, role: pnj.role, rel: pnj.rel });
  showToast('Contact ajoute', pnj.name + ' a ete ajoute a votre repertoire.', true);
  addJournalEntry(pnj.name + ' ajoute au repertoire.', '');
}

async function genererReactionJournaliste() {
  const journaliste = JOURNALISTES_PNJ[state.country];
  if (!journaliste) return null;

  // Récupérer les derniers topics du forum local
  const topics = FORUM_TOPICS[state.country === 'republic' ? 'local' : 'local'] || [];
  const recentTopics = topics.slice(0, 3);
  if (recentTopics.length === 0) return null;

  const topicsText = recentTopics.map(t =>
    `"${t.title}" (par ${t.author})`
  ).join(', ');

  const co = COUNTRIES[state.country];
  const empireStyle = EMPIRE_STYLES[state.country] || EMPIRE_STYLES.republic;

  const prompt = `Tu es ${journaliste.name}, journaliste de "${journaliste.journal}" dans l'empire ${co?.n}.
Ta personnalité : ${journaliste.trait}
Ton style : ${journaliste.style}
Religion locale : ${empireStyle.religion}. Chef suprême : ${empireStyle.leader}.

Sujets récents sur le forum local : ${topicsText}

Rédige UNE courte réaction journalistique (2-3 phrases max) à ces actualités.
Style parodique et satirique. Intègre les éléments de l'empire naturellement.
PAS de vrais dieux ou religions. Réponds UNIQUEMENT avec ta réaction, sans introduction.`;

  try {
    const resp = await fetch('/api/chat', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({
        model: 'claude-sonnet-4-5',
        max_tokens: 150,
        messages: [{ role: 'user', content: prompt }]
      })
    });
    if (!resp.ok) return null;
    const data = await resp.json();
    return { journaliste, texte: data.content?.[0]?.text };
  } catch(e) { return null; }
}

async function afficherReactionJournaliste() {
  const reaction = await genererReactionJournaliste();
  if (!reaction) return;

  // Afficher dans le journal des événements
  addJournalEntry(
    `📰 ${reaction.journaliste.journal} — ${reaction.journaliste.name} : "${reaction.texte}"`,
    'event-info'
  );
}

function getAllPJsAndPNJs() {
  const result = [];
  // PJ connus (depuis state.pjConnus ou contacts)
  const pjConnus = state.pjConnus || [];
  pjConnus.forEach(nom => {
    if (!result.some(r => r.name === nom)) {
      result.push({ name: nom, role: 'Joueur', isPJ: true });
    }
  });
  // Contacts du répertoire
  (state.contacts || []).forEach(c => {
    if (!result.some(r => r.name === c.name)) {
      result.push({ name: c.name, role: c.role || 'Contact', isPJ: false });
    }
  });
  // PNJ du bâtiment actuel
  if (state.currentBuilding && state.currentRoom) {
    const room = BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom];
    (room?.persons || []).forEach(p => {
      if (!result.some(r => r.name === p.name)) {
        result.push({ name: p.name, role: p.role || 'PNJ', isPJ: false });
      }
    });
  }
  // Si toujours vide, retourner une cible générique
  if (result.length === 0) {
    result.push({ name: 'Un notable local', role: 'Personnage politique', isPJ: false });
  }
  return result;
}

async function doEscortInfos() {
  const cibles = getAllPJsAndPNJs().filter(c => c.name !== state.char?.name);
  if (cibles.length === 0) { showToast('Personne à cibler', 'Aucune cible disponible.', false); return; }

  const co = COUNTRIES[state.country];
  const cur = co?.cur || 'FR';

  if (state.arg < 300) { showToast('Fonds insuffisants', `300 ${cur} requis.`, false); return; }
  state.arg -= 300;

  // Choisir une cible au hasard parmi les PJ/PNJ connus
  const cible = cibles[Math.floor(Math.random() * Math.min(3, cibles.length))];

  const prompt = `Tu joues dans Res Publica, jeu politique parodique.
Une escort de luxe (${state.country === 'republic' ? 'Roxane Velours' : state.country === 'narco' ? 'Lola Discreta' : 'Natasha Privilege'}) a recueilli des informations compromettantes sur ${cible.name} (${cible.role || 'personnage politique'}) dans l'empire ${co?.n}.
Génère UNE révélation compromettante, parodique et drôle (2 phrases max). Style scandale politique. Pas de vrais noms de personnes réelles. Pas de religions réelles.`;

  try {
    const resp = await fetch('/api/chat', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({ model: 'claude-haiku-4-5-20251001', max_tokens: 60, messages: [{ role: 'user', content: prompt }] })
    });
    const data = await resp.json();
    const info = data.content?.[0]?.text?.trim() || 'Information confidentielle obtenue.';

    // Créer un kompromat dans l'inventaire
    addToInventory({
      id: 'kompromat-' + Date.now(),
      name: 'Kompromat sur ' + cible.name,
      icon: 'ti-file-shredder',
      desc: info,
      type: 'kompromat',
      cible: cible.name,
      legal: false
    });

    state.inf = Math.min(100, (state.inf || 0) + 5);
    updateUI();
    addJournalEntry('Kompromat obtenu sur ' + cible.name + '. Ajouté à l\'inventaire.', 'event-info');
    showToast('Information obtenue !', info.substring(0, 100) + (info.length > 100 ? '...' : ''), true, true);

  } catch(e) {
    showToast('Erreur', 'Impossible d\'obtenir l\'information.', false);
  }
}

function doEscortPiege() {
  const co = COUNTRIES[state.country];
  const cur = co?.cur || 'FR';
  const cost = 800;

  // Sélectionner une cible PJ dans le répertoire
  const pjContacts = (state.contacts || []).filter(c => c.isPJ || c.type === 'pj');
  if (pjContacts.length === 0) {
    showToast('Aucune cible', 'Vous devez avoir des PJ dans votre répertoire pour organiser un piège.', false);
    return;
  }
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }

  // Modal de sélection de cible
  document.getElementById('postes-modal-title').textContent = '🕵 Choisir une cible';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +
    '<div style="font-size:.75rem;color:#8a8060;font-style:italic;margin-bottom:.7rem">Sélectionnez le PJ à piéger. Coût : ' + cost + ' ' + cur + '.</div>' +
    pjContacts.map(c =>
      '<div onclick="confirmerEscortPiege(\'' + c.name.replace(/'/g,'') + '\')" style="display:flex;align-items:center;gap:.6rem;padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;cursor:pointer" onmouseover="this.style.background=\'#1a1005\'" onmouseout="this.style.background=\'#0f0d05\'">' +
        '<i class="ti ti-user" style="font-size:.9rem;color:#8a6a20"></i>' +
        '<div><div style="font-size:.82rem;color:#c0b090">' + c.name + '</div>' +
        '<div style="font-size:.65rem;color:#4a4030">' + (c.role||'PJ') + '</div></div>' +
      '</div>'
    ).join('') +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerEscortPiege(nomCible) {
  const co = COUNTRIES[state.country];
  const cur = co?.cur || 'FR';
  const cost = 800;

  document.getElementById('modal-postes').classList.remove('open');

  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  state.arg -= cost;

  // Stats commanditaire
  const dup = state.char?.stats?.DUP || 8;
  const dis = state.dis || 50;

  // On simule les stats de la cible (on ne les a pas côté client)
  const cibleDUP = Math.floor(Math.random() * 6) + 6; // entre 6 et 12
  const cibleDIS = Math.floor(Math.random() * 40) + 30; // entre 30 et 70

  // Jet de succès
  const taux = Math.min(80, 30 + Math.floor(dup * 2) - Math.floor(cibleDUP * 1.5));
  const roll = Math.floor(Math.random() * 100) + 1;

  if (roll <= taux) {
    // SUCCÈS
    const prompt = 'Res Publica, jeu politique parodique. ' + nomCible + ' vient d\'être piégé(e) par une escort dans un scandale compromettant. Génère UN titre de scandale parodique (1 phrase max, style journal à scandales).';
    let scandale = nomCible + ' impliqué(e) dans un scandale compromettant avec une escort.';
    try {
      const resp = await fetch('/api/chat', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({ model: 'claude-haiku-4-5-20251001', max_tokens: 60, messages: [{ role: 'user', content: prompt }] })
      });
      const data = await resp.json();
      scandale = data.content?.[0]?.text?.trim() || scandale;
    } catch(e) {}

    // Effets sur commanditaire
    state.inf = Math.min(100, (state.inf||0) + 10);
    state.pop = Math.min(100, (state.pop||0) + 5);

    // Kompromat généré
    addToInventory({
      name: 'Kompromat sur ' + nomCible,
      icon: 'ti-file-shredder',
      type: 'kompromat',
      cible: nomCible,
      desc: scandale,
      legal: false,
      expireDay: (state.day||1) + 10
    });

    updateUI();
    addExternalEvent('📰 SCANDALE : ' + scandale);
    addJournalEntry('Piège réussi sur ' + nomCible + '. Scandale : "' + scandale.substring(0,60) + '"', 'event-good');
    showToast('Piège réussi !', scandale, true, true);

  } else {
    // ÉCHEC — argent perdu, la cible peut enquêter
    updateUI();
    addJournalEntry('Piège raté sur ' + nomCible + '. -' + cost + ' ' + cur + ' perdus.', 'event-bad');
    showToast('Piège raté', nomCible + ' a éventé la manœuvre. Argent perdu.', false);

    // Jet d\'enquête de la cible contre le commanditaire
    const tauxEnquete = Math.min(70, Math.floor(cibleDUP * 4) + Math.floor(cibleDIS / 10));
    const rollEnquete = Math.floor(Math.random() * 100) + 1;
    if (rollEnquete <= tauxEnquete) {
      // Cible trouve le commanditaire
      const tauxIdentif = Math.min(80, tauxEnquete - Math.floor(dup * 2) - Math.floor(dis / 10));
      const rollIdentif = Math.floor(Math.random() * 100) + 1;
      if (rollIdentif <= tauxIdentif) {
        state.pop = Math.max(0, (state.pop||0) - 15);
        state.dis = Math.max(0, (state.dis||50) - 10);
        updateUI();
        addExternalEvent('📰 ' + nomCible + ' révèle avoir été la cible d\'un complot orchestré par ' + (state.char?.name||'un personnage politique') + ' !');
        addJournalEntry('Enquête de ' + nomCible + ' : vous avez été identifié(e). -15 POP -10 DIS.', 'event-bad');
        showToast('Identifié(e) !', nomCible + ' vous a démasqué(e). -15 POP -10 DIS.', false);
      } else {
        addJournalEntry('La cible enquête mais ne vous retrouve pas.', 'event-info');
      }
    }
  }
}

function genererPnjTerrain(buildingId) {
  const country = state.country || 'republic';
  const profiles = (typeof TERRAIN_PNJ_PROFILES !== 'undefined')
    ? TERRAIN_PNJ_PROFILES[country] || TERRAIN_PNJ_PROFILES.republic
    : [];
  if (!profiles.length) return null;

  // Indices impériaux modifient les probabilités
  const indices = INDICES_NATIONAUX?.[country] || { ISN:30, IE:50, ID:40, IS:45 };
  const isn = indices.ISN || 30;
  const ie  = indices.IE  || 50;
  const id  = indices.ID  || 40;
  const is  = indices.IS  || 45;

  // Ajuster les probabilités selon indices
  const adjustedProfiles = profiles.map(p => {
    let prob = p.prob;
    if (p.id === 'squatter_agr')  prob = Math.max(0.01, prob - isn/200 - is/200);
    if (p.id === 'squatter_cool') prob = Math.max(0.02, prob - isn/300);
    if (p.id === 'cadavre')       prob = Math.max(0.005, prob + (100-id)/500);
    if (p.id === 'promoteur')     prob = Math.max(0.03, prob + ie/400);
    if (p.id === 'inspecteur')    prob = Math.max(0.05, prob + isn/300);
    if (p.id === 'vide')          prob = Math.max(0.05, prob + isn/200);
    return { ...p, prob };
  });

  // Normaliser et tirer au sort
  const total = adjustedProfiles.reduce((s, p) => s + p.prob, 0);
  let roll = Math.random() * total;
  for (const p of adjustedProfiles) {
    roll -= p.prob;
    if (roll <= 0) return p.id === 'vide' ? null : p;
  }
  return null;
}

async function interagirPnjTerrain(pnjId) {
  const country = state.country || 'republic';
  const profiles = TERRAIN_PNJ_PROFILES?.[country] || TERRAIN_PNJ_PROFILES?.republic || [];
  const pnj = profiles.find(p => p.id === pnjId);
  if (!pnj) return;

  const indices = INDICES_NATIONAUX?.[country] || { ISN:30, IE:50, ID:40, IS:45 };
  const is = indices.IS || 45;
  const cha = state.char?.stats?.CHA || 8;
  const cur = COUNTRIES[country]?.cur || 'FR';

  // Squatteurs agressifs — jet CHA + IS
  if (pnj.agressif) {
    const bonusCHA = Math.floor(cha / 2);
    const bonusIS  = Math.floor(is / 10);
    const taux = Math.min(80, 20 + bonusCHA + bonusIS);
    const roll = Math.floor(Math.random() * 100) + 1;

    if (roll <= taux) {
      // Succès — CHA évite l'agression
      state.inf = Math.min(100, (state.inf||0) + 2);
      updateUI();
      addJournalEntry('Vous avez calmé les squatteurs par votre charisme. +2 INF.', 'event-good');
      showToast('Tension désamorcée !', 'Votre charisme a évité la bagarre. (Jet ' + roll + '/' + taux + '%)', true);
    } else {
      // Échec — bagarre
      const degats = Math.floor(Math.random() * 15) + 10;
      state.hp = Math.max(0, (state.hp||100) - degats);
      state.dis = Math.max(0, (state.dis||50) - 5);
      updateUI();
      addJournalEntry('Vous avez été attaqué par des squatteurs. -' + degats + ' HP. -5 DIS.', 'event-bad');
      showToast('Bagarre !', '-' + degats + ' HP · -5 DIS (Jet ' + roll + '/' + taux + '%)', false);
    }
    return;
  }

  // Squatteurs cools — bière et côtelette
  if (pnj.id === 'squatter_cool') {
    const hpBonus = Math.floor(Math.random() * 8) + 5;
    const moralBonus = Math.floor(Math.random() * 8) + 5;
    state.hp = Math.min(100, (state.hp||100) + hpBonus);
    state.moral = Math.min(100, (state.moral||50) + moralBonus);
    // Info gratuite parfois
    const infoBonus = Math.random() > 0.5;
    if (infoBonus) state.inf = Math.min(100, (state.inf||0) + 3);
    updateUI();
    addJournalEntry('Les squatteurs vous offrent bière et côtelette. +' + hpBonus + ' HP · +' + moralBonus + ' Moral' + (infoBonus ? ' · +3 INF' : '') + '.', 'event-good');
    showToast('Accueil chaleureux !', '+' + hpBonus + ' HP · +' + moralBonus + ' Moral' + (infoBonus ? ' · +3 INF (tuyau)' : ''), true);
    return;
  }

  // Cadavre — blocage administratif
  if (pnj.id === 'cadavre') {
    const id_idx = indices.ID || 40;
    const delai = Math.max(1, Math.round(5 - id_idx/25));
    state.dis = Math.max(0, (state.dis||50) - 10);
    updateUI();
    addJournalEntry('Cadavre découvert sur le terrain ! Enquête obligatoire. Blocage administratif : ' + delai + ' jour(s). -10 DIS.', 'event-bad');
    showToast('Cadavre découvert !', 'Enquête requise. Formalités bloquées ' + delai + ' jour(s). -10 DIS.', false);
    // Signaler à la police
    if (!state.recherche) state.recherche = [];
    addExternalEvent('🚨 Cadavre découvert sur un terrain à ' + (WORLD[country]?.[state.currentCity]?.name || 'la ville') + '. Enquête en cours.');
    return;
  }

  // Promoteur — propose rachat à prix gonflé
  if (pnj.id === 'promoteur') {
    const prixGonfle = Math.floor(Math.random() * 5000) + 6000;
    addJournalEntry(pnj.name + ' vous propose de racheter ce terrain pour ' + prixGonfle.toLocaleString('fr-FR') + ' ' + cur + '.', 'event-info');
    showToast(pnj.name, 'Offre de rachat : ' + prixGonfle.toLocaleString('fr-FR') + ' ' + cur + '. Intéressant ?', true);
    return;
  }

  // Gardien — peut être soudoyé
  if (pnj.id === 'gardien') {
    const pot = Math.floor(isn / 5) * 10 + 100;
    document.getElementById('postes-modal-title').textContent = pnj.name + ' — Gardien';
    document.getElementById('postes-body').innerHTML =
      '<div style="padding:1rem">' +
      '<div style="font-size:.82rem;color:#a09060;margin-bottom:.8rem;font-style:italic">"' + (pnj.trait || (pnj.job === 'escort' ? 'Je connais tous les secrets de cette ville. Mon tarif : 500 ' + (COUNTRIES[state.country]?.cur || 'FR') + '/réveil.' : 'Un personnage discret.')) + '"</div>' +
      '<button onclick="soudoyerGardienTerrain(' + pot + ');document.getElementById(\'modal-postes\').classList.remove(\'open\')" ' +
      'style="font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem .8rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer;display:block;margin-bottom:.4rem;width:100%">' +
      '<i class="ti ti-coin"></i> Soudoyer (' + pot + ' ' + cur + ')</button>' +
      '<button onclick="document.getElementById(\'modal-postes\').classList.remove(\'open\')" ' +
      'style="font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem .8rem;border:1px solid #2a2010;background:transparent;color:#6a5a30;cursor:pointer;width:100%">Partir</button>' +
      '</div>';
    document.getElementById('modal-postes').classList.add('open');
    return;
  }

  // Inspecteur — vérifie les permis
  if (pnj.id === 'inspecteur') {
    const aPermis = state.inventory?.find(i => i.type === 'permis' && i.building === state.currentBuilding);
    if (aPermis) {
      addJournalEntry(pnj.name + ' vérifie vos permis. Tout est en ordre.', 'event-info');
      showToast('Contrôle passé', 'Vos permis sont valides.', true);
    } else {
      state.dis = Math.max(0, (state.dis||50) - 8);
      updateUI();
      addJournalEntry(pnj.name + ' vous demande un permis de construire. Vous n\'en avez pas. -8 DIS.', 'event-bad');
      showToast('Contrôle raté !', 'Permis manquant. -8 DIS.', false);
    }
    return;
  }

  // Par défaut — juste parler
  showToast(pnj.name, pnj.trait || 'Un personnage mystérieux.', true);
}

function soudoyerGardienTerrain(montant) {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  if (state.arg < montant) {
    showToast('Fonds insuffisants', montant + ' ' + cur + ' requis.', false);
    return;
  }
  const dup = state.char?.stats?.DUP || 8;
  const taux = Math.min(80, 40 + Math.floor(dup/2));
  const roll = Math.floor(Math.random() * 100) + 1;
  state.arg -= montant;
  if (roll <= taux) {
    state.dis = Math.min(100, (state.dis||50) + 5);
    updateUI();
    showToast('Gardien soudoyé !', 'Il regarde ailleurs. +5 DIS.', true);
    addJournalEntry('Gardien soudoyé pour ' + montant + ' ' + cur + '. -' + montant + ' ' + cur + ' · +5 DIS.', 'event-good');
  } else {
    state.dis = Math.max(0, (state.dis||50) - 10);
    updateUI();
    showToast('Refus !', 'Il n\'a pas accepté. -10 DIS.', false);
    addJournalEntry('Tentative de corruption du gardien refusée. -' + montant + ' ' + cur + ' · -10 DIS.', 'event-bad');
  }
}

function chargerPnjTerrain(buildingId) {
  if (!buildingId?.startsWith('terrain-a-batir')) return;

  // Vérifier si état persistant existe déjà
  const ts = getTerrainState(buildingId);

  // Si police est intervenue, vider le PNJ
  if (ts.policeInterventionAt && Date.now() > ts.policeInterventionAt && ts.pnj) {
    setTerrainState(buildingId, { pnj: null, pnjData: null, policeAppellee: null, policeInterventionAt: null });
    sessionStorage.removeItem('terrain_pnj_' + buildingId);
    showToast('Terrain libéré', 'La police est intervenue.', true);
    return;
  }

  // Utiliser le PNJ persistant si disponible
  if (ts.pnjData) {
    sessionStorage.setItem('terrain_pnj_' + buildingId, JSON.stringify({
      name: ts.pnjData.name + ' (PNJ)',
      role: ts.pnjData.role,
      job: ts.pnjData.job,
      rel: ts.pnjData.rel,
      trait: ts.pnjData.trait,
      photoUrl: ts.pnjData.photoUrl,
      photoPos: ts.pnjData.photoPos,
      terrainPnjId: ts.pnjData.id
    }));
    return;
  }

  // Générer automatiquement au premier passage
  const pnjObj = genererPnjTerrain(buildingId);
  if (pnjObj) {
    setTerrainState(buildingId, { pnj: pnjObj.id, pnjData: pnjObj, dateGeneration: Date.now() });
    sessionStorage.setItem('terrain_pnj_' + buildingId, JSON.stringify({
      name: pnjObj.name + ' (PNJ)', role: pnjObj.role, job: pnjObj.job,
      rel: pnjObj.rel, trait: pnjObj.trait, photoUrl: pnjObj.photoUrl,
      photoPos: pnjObj.photoPos, terrainPnjId: pnjObj.id
    }));
  } else {
    sessionStorage.removeItem('terrain_pnj_' + buildingId);
  }
}

async function getTerrainsVraimentLibres(country) {
  if (typeof sbGetTerrainsLibres !== 'function') return [];
  try {
    const tousLesEtats = await sbGetTerrainsLibres(country);
    const occupes = new Set(tousLesEtats.filter(t => t.proprietaire).map(t => t.building_id));

    const terrainsLibres = [];
    const villesDuPays = WORLD[country] || {};
    Object.entries(villesDuPays).forEach(([cityId, cityData]) => {
      (cityData.buildings || []).forEach(bId => {
        if (bId.startsWith('terrain-a-batir') && !occupes.has(bId)) {
          terrainsLibres.push({ buildingId: bId, cityId });
        }
      });
    });
    return terrainsLibres;
  } catch(e) { console.warn('getTerrainsVraimentLibres error', e); return []; }
}

function getTerrainState(buildingId) {
  const key = 'terrain_state_' + state.country + '_' + buildingId;
  try {
    const stored = localStorage.getItem(key);
    return stored ? JSON.parse(stored) : {};
  } catch(e) { return {}; }
}

function setTerrainState(buildingId, updates) {
  const key = 'terrain_state_' + state.country + '_' + buildingId;
  const current = getTerrainState(buildingId);
  const newState = { ...current, ...updates };
  try { localStorage.setItem(key, JSON.stringify(newState)); } catch(e) {}

  // Synchroniser avec Supabase si disponible
  if (typeof sbSetTerrainState === 'function') {
    sbSetTerrainState(state.country, buildingId, newState).catch(() => {});
  }
  return newState;
}

function terrainOrdreDisponible(fn, buildingId) {
  const ts = getTerrainState(buildingId);
  const pnj = ts.pnj; // PNJ persistant sur ce terrain

  // Ordres bloqués si cadavre présent
  if (pnj === 'cadavre') {
    const bloques = ['signer_compromis', 'permis_construire', 'permis_corrompu', 'acheter_terrain'];
    if (bloques.includes(fn)) return { ok: false, raison: 'Un cadavre bloque les démarches administratives. Résolvez la situation d\'abord.' };
  }

  // Ordres bloqués si squatteurs présents
  if (pnj === 'squatter_agr' || pnj === 'squatter_cool') {
    if (fn === 'signer_compromis') return { ok: false, raison: 'Des squatteurs occupent le terrain. Faites intervenir la police ou négociez leur départ.' };
  }

  // Ordre cadavre seulement si cadavre présent
  if (fn === 'faire_disparaitre_cadavre' && pnj !== 'cadavre')
    return { ok: false, raison: 'Aucun cadavre sur ce terrain.' };

  // Ordre négociation seulement si squatteurs présents
  if (fn === 'negocier_squatteurs' && pnj !== 'squatter_agr' && pnj !== 'squatter_cool')
    return { ok: false, raison: 'Aucun squatteur à négocier.' };

  // Compromis requis avant permis
  if (fn === 'permis_construire' || fn === 'permis_corrompu') {
    if (!ts.compromis) return { ok: false, raison: 'Signez d\'abord un compromis de vente.' };
  }

  return { ok: true };
}

function doVerifierTerrain() {
  const id = state.currentBuilding;
  let ts = getTerrainState(id);

  if (!ts.pnj) {
    // Générer et persister le PNJ
    const pnjObj = genererPnjTerrain(id);
    ts = setTerrainState(id, {
      pnj: pnjObj ? pnjObj.id : null,
      pnjData: pnjObj || null,
      dateGeneration: Date.now()
    });
    // Mettre à jour le sessionStorage aussi pour l'affichage
    if (pnjObj) {
      sessionStorage.setItem('terrain_pnj_' + id, JSON.stringify({
        name: pnjObj.name + ' (PNJ)', role: pnjObj.role, job: pnjObj.job,
        rel: pnjObj.rel, trait: pnjObj.trait, terrainPnjId: pnjObj.id,
        photoUrl: pnjObj.photoUrl, photoPos: pnjObj.photoPos
      }));
    } else {
      sessionStorage.removeItem('terrain_pnj_' + id);
    }
  }

  const pnj = ts.pnjData;
  if (!pnj) {
    addJournalEntry('Terrain inspecté. Rien à signaler.', 'event-info');
    showToast('Terrain libre', 'Aucun obstacle. Vous pouvez procéder aux démarches.', true);
  } else {
    addJournalEntry('Terrain inspecté. ' + (pnj.role || 'Présence') + ' détectée.', 'event-info');
    showToast(pnj.role || 'Obstacle détecté', pnj.trait || '', pnj.rel !== 'enemy');
  }

  // Recharger la pièce complète pour afficher le PNJ
  if (state.currentRoom && state.currentBuilding) {
    enterRoom(state.currentBuilding, state.currentRoom);
  }
}

function doAppelerPoliceTerrain() {
  const id = state.currentBuilding;
  const ts = getTerrainState(id);
  const pnj = ts.pnjData;
  const indices = INDICES_NATIONAUX?.[state.country] || { ISN: 30 };
  const isn = indices.ISN || 30;
  const delaiH = Math.max(6, Math.round(96 - isn * 0.6));
  const delaiRapideH = Math.max(1, Math.round(delaiH / 4));
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const coutSoudoiement = Math.floor(100 + isn * 3);

  document.getElementById('postes-modal-title').textContent = '🚔 Appeler la police';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +
    '<div style="font-size:.78rem;color:#c0b090;margin-bottom:.8rem">' +
      (pnj ? 'Présence détectée : <strong>' + pnj.role + '</strong>.' : 'Terrain occupé.') +
    '</div>' +
    '<div style="display:flex;flex-direction:column;gap:.5rem">' +
    '<button onclick="doExpulsionLegale();fermerModalPostes()" ' +
    'style="text-align:left;padding:.6rem .8rem;border:1px solid #3a5a3a;background:#0a0f0a;color:#6ada6a;font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.06em;cursor:pointer">' +
    '⚖️ Expulsion légale — délai ' + delaiH + 'h (gratuit)</button>' +
    '<button onclick="doExpulsionAcceleree(' + coutSoudoiement + ');fermerModalPostes()" ' +
    'style="text-align:left;padding:.6rem .8rem;border:1px solid #5a5a20;background:#0a0f00;color:#C9A84C;font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.06em;cursor:pointer">' +
    '💰 Soudoyer l\'inspecteur — ' + coutSoudoiement + ' ' + cur + ' · délai ' + delaiRapideH + 'h</button>' +
    '<button onclick="fermerModalPostes()" ' +
    'style="padding:.4rem;border:1px solid #2a2010;background:transparent;color:#6a5a30;font-family:Bebas Neue,sans-serif;font-size:.68rem;cursor:pointer">Annuler</button>' +
    '</div></div>';
  document.getElementById('modal-postes').classList.add('open');
}

function doExpulsionAcceleree(cout) {
  const id = state.currentBuilding;
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const indices = INDICES_NATIONAUX?.[state.country] || { ISN: 30 };
  const isn = indices.ISN || 30;
  const delaiRapideH = Math.max(1, Math.round((96 - isn * 0.6) / 4));
  const dup = state.char?.stats?.DUP || 8;
  const taux = Math.min(80, 40 + Math.floor(dup * 2));
  const roll = Math.floor(Math.random() * 100) + 1;

  if (state.arg < cout) { showToast('Fonds insuffisants', cout + ' ' + cur + ' requis.', false); return; }

  state.arg -= cout;
  if (roll <= taux) {
    setTerrainState(id, {
      policeAppellee: Date.now(),
      policeInterventionAt: Date.now() + delaiRapideH * 3600000
    });
    state.dis = Math.max(0, (state.dis || 50) - 5);
    updateUI();
    addJournalEntry('Inspecteur soudoyé pour ' + cout + ' ' + cur + '. Expulsion dans ' + delaiRapideH + 'h. -5 DIS.', 'event-good');
    showToast('Arrangé !', 'Expulsion dans ' + delaiRapideH + 'h. -' + cout + ' ' + cur + ' · -5 DIS.', true);
  } else {
    state.dis = Math.max(0, (state.dis || 50) - 15);
    updateUI();
    addJournalEntry('Tentative de corruption refusée. -' + cout + ' ' + cur + ' · -15 DIS.', 'event-bad');
    showToast('Refus !', 'L\'inspecteur a refusé. -' + cout + ' ' + cur + ' · -15 DIS.', false);
  }
}

function doFaireDisparaitreCadavre() {
  const id = state.currentBuilding;
  const ts = getTerrainState(id);
  const indices = INDICES_NATIONAUX?.[state.country] || { ISN: 30, ID: 40 };
  const isn = indices.ISN || 30;
  const id_idx = indices.ID || 40;

  const dis = state.dis || 50;
  const cha = state.char?.stats?.CHA || 8;
  const bonusOrga = calculerBonusOrga();
  const taux = Math.min(85, Math.floor(dis/2 + cha/2) - Math.floor(isn/5) + (bonusOrga.dis || 0) / 3);
  const roll = Math.floor(Math.random() * 100) + 1;

  if (roll <= taux) {
    // Succès — cadavre disparu
    const prescriptionJours = Math.max(7, Math.round(id_idx * 0.6));
    setTerrainState(id, {
      pnj: null, pnjData: null,
      cadavreDisparuAt: Date.now(),
      prescriptionAt: Date.now() + prescriptionJours * 86400000,
      actesIllegaux: [...(ts.actesIllegaux || []), {
        type: 'cadavre_dissimule',
        auteur: state.char?.name,
        date: Date.now(),
        prescriptionAt: Date.now() + prescriptionJours * 86400000
      }]
    });
    sessionStorage.removeItem('terrain_pnj_' + id);
    state.dis = Math.max(0, (state.dis || 50) - 5);
    updateUI();
    addJournalEntry('Cadavre dissimulé avec succès. Jet ' + roll + '/' + taux + '%. Prescription dans ' + prescriptionJours + ' jours.', 'event-good');
    showToast('Cadavre dissimulé !', 'Terrain libre. Prescription dans ' + prescriptionJours + ' jours. -5 DIS.', true);
  } else {
    // Échec — garde à vue
    state.dis = Math.max(0, (state.dis || 50) - 20);
    state.hp = Math.max(0, (state.hp || 100) - 5);
    updateUI();
    addJournalEntry('Flagrant délit ! Garde à vue de 24h. Jet ' + roll + '/' + taux + '%. -20 DIS · -5 HP.', 'event-bad');
    showToast('Arrêté !', 'Garde à vue 24h. -20 DIS · -5 HP. (Jet ' + roll + '/' + taux + '%)', false);
    // Bloquer le joueur 24h
    if (!state.recherche) state.recherche = [];
    state.recherche.push({ type: 'suspicion_cadavre', terrain: id, debut: Date.now(), fin: Date.now() + 86400000 });
    addExternalEvent('🚨 ' + (state.char?.name) + ' a été arrêté pour suspicion de dissimulation de cadavre à ' + (WORLD[state.country]?.[state.currentCity]?.name || 'la ville') + '.');
  }
}

function doNegocierSquatteurs() {
  const id = state.currentBuilding;
  const ts = getTerrainState(id);
  const pnj = ts.pnjData;
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  const minMontant = pnj?.id === 'squatter_agr' ? 500 : 0;

  document.getElementById('postes-modal-title').textContent = 'Négocier le départ';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +
    '<div style="font-size:.78rem;color:#c0b090;margin-bottom:.6rem;font-style:italic">"' + (pnj?.trait || '') + '"</div>' +
    (minMontant > 0 ? '<div style="font-size:.7rem;color:#8a3a2a;margin-bottom:.5rem">Ces squatteurs refuseront toute offre inférieure à ' + minMontant + ' ' + cur + '.</div>' : '') +
    '<div style="font-size:.72rem;color:#8a8060;margin-bottom:.4rem">Chaque 100 ' + cur + ' supplémentaires améliorent vos chances de +1%.</div>' +
    '<input id="negoc-montant" type="number" min="' + minMontant + '" step="100" placeholder="Montant proposé..." ' +
    'style="width:100%;padding:.4rem .6rem;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;font-family:Crimson Pro,Georgia,serif;font-size:.85rem;box-sizing:border-box;margin-bottom:.6rem"/>' +
    '<button onclick="confirmerNegociation()" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">Négocier</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerNegociation() {
  const id = state.currentBuilding;
  const ts = getTerrainState(id);
  const pnj = ts.pnjData;
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const montant = parseInt(document.getElementById('negoc-montant')?.value || 0);
  const indices = INDICES_NATIONAUX?.[state.country] || { IS: 45 };
  const is = indices.IS || 45;

  if (!montant || montant < (pnj?.id === 'squatter_agr' ? 500 : 0)) {
    showToast('Montant insuffisant', 'Les squatteurs refusent.', false);
    return;
  }
  if (state.arg < montant) {
    showToast('Fonds insuffisants', 'Vous n\'avez pas ' + montant + ' ' + cur + '.', false);
    return;
  }

  const cha = state.char?.stats?.CHA || 8;
  const bonusArgent = Math.min(40, Math.floor(montant / 100));
  const bonusOrga2 = calculerBonusOrga();
  const taux = Math.min(90, Math.floor(cha * 3 + is / 5) + bonusArgent + (bonusOrga2.nego_cha || 0));
  const roll = Math.floor(Math.random() * 100) + 1;

  state.arg -= montant;
  document.getElementById('modal-postes').classList.remove('open');

  if (roll <= taux) {
    setTerrainState(id, { pnj: null, pnjData: null });
    sessionStorage.removeItem('terrain_pnj_' + id);
    updateUI();
    addJournalEntry('Squatteurs convaincus pour ' + montant + ' ' + cur + '. Jet ' + roll + '/' + taux + '%.', 'event-good');
    showToast('Terrain libéré !', 'Les squatteurs sont partis. -' + montant + ' ' + cur, true);
  } else {
    updateUI();
    addJournalEntry('Négociation échouée. ' + montant + ' ' + cur + ' perdus. Jet ' + roll + '/' + taux + '%.', 'event-bad');
    showToast('Refus !', 'Ils ont pris l\'argent mais restent. -' + montant + ' ' + cur, false);
  }
}

function doSignerCompromis() {
  const id = state.currentBuilding;
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  const dispo = terrainOrdreDisponible('signer_compromis', id);
  if (!dispo.ok) { showToast('Impossible', dispo.raison, false); return; }

  setTerrainState(id, {
    compromis: true,
    compromisAt: Date.now(),
    compromisExpireAt: Date.now() + 7 * 86400000
  });
  state.arg -= 500;
  updateUI();
  addJournalEntry('Compromis de vente signé pour 500 ' + cur + '. Valable 7 jours.', 'event-good');
  showToast('Compromis signé !', 'Terrain réservé 7 jours. -500 ' + cur, true);
}

function doAcheterTerrain() {
  const id = state.currentBuilding;
  const ts = getTerrainState(id);
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const b = BUILDINGS[id];
  const localName = b?.shortName || b?.name || id;

  const dispo = terrainOrdreDisponible('acheter_terrain', id);
  if (!dispo.ok) { showToast('Impossible', dispo.raison, false); return; }

  const prix = 25000;
  if (state.arg < prix) { showToast('Fonds insuffisants', prix.toLocaleString('fr-FR') + ' ' + cur + ' requis. Pensez au prêt bancaire.', false); return; }

  state.arg -= prix;
  if (!state.terrainsAchetes) state.terrainsAchetes = {};
  state.terrainsAchetes[id] = state.char?.name;

  // Synchroniser aussi avec Supabase pour que le terrain soit reellement marque "occupe"
  // Si le joueur est marie, son conjoint devient automatiquement coproprietaire a 50%
  (async () => {
    let coproprietaire = null;
    if (typeof sbGetMariageActif === 'function') {
      try {
        const mariage = await sbGetMariageActif(state.char?.name);
        if (mariage) {
          coproprietaire = mariage.conjoint1 === state.char?.name ? mariage.conjoint2 : mariage.conjoint1;
        }
      } catch(e) {}
    }
    if (typeof sbSetTerrainState === 'function') {
      await sbSetTerrainState(state.country, id, { proprietaire: state.char?.name, coproprietaire }).catch(() => {});
    }
    if (coproprietaire) {
      showToast('Bien partagé', coproprietaire + ' devient copropriétaire à 50% de ce terrain.', true);
      addJournalEntry('Terrain acheté en copropriété avec ' + coproprietaire + ' (50/50).', 'event-good');
    }
  })();

  const aPermis = ts.permis;
  setTerrainState(id, {
    proprietaire: state.char?.name,
    acheteAt: Date.now(),
    constructionAutorisee: !!aPermis
  });

  updateUI();
  if (!aPermis) {
    addJournalEntry('Terrain ' + localName + ' acheté pour ' + prix + ' ' + cur + '. SANS permis — construction bloquée jusqu\'autorisation du maire.', 'event-info');
    showToast('Terrain acheté !', 'Sans permis : construction bloquée. Demandez l\'autorisation au maire.', true);
  } else {
    addJournalEntry('Terrain ' + localName + ' acheté pour ' + prix + ' ' + cur + '. Permis valide.', 'event-good');
    showToast('Terrain acheté !', 'Avec permis. Construction autorisée.', true);
  }
}

function initSimulation() {
  if (!state.pjSimules) {
    state.pjSimules = JSON.parse(JSON.stringify(PJ_SIMULES));
  }
}

function getSimulesPresents() {
  if (!state.pjSimules) initSimulation();
  return state.pjSimules.filter(p =>
    p.currentCity === state.currentCity &&
    p.currentBuilding === state.currentBuilding &&
    !p.estAssassine
  );
}

function ouvrirPanneauSimulation() {
  if (!state.pjSimules) initSimulation();
  document.getElementById('postes-modal-title').textContent = 'Joueurs Simules — Mode Test';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#6a5a30;font-style:italic;margin-bottom:.8rem;padding:.5rem;background:#0a0805;border:1px solid #1a1810">Mode simulation actif. Ces PJ fictifs permettent de tester les interactions multijoueur.</div>';

  state.pjSimules.forEach((p, i) => {
    const ar = ARCHETYPES.find(x => x.id === p.archetype);
    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.8rem;margin-bottom:.6rem">';
    html += '<div style="display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:.4rem">';
    html += '<div><div style="font-family:Playfair Display,serif;font-size:.9rem;color:#E8C97A">' + p.name + '</div>';
    html += '<div style="font-size:.72rem;color:#6a5a30">' + p.role + '</div>';
    html += (p.poste ? '<div style="font-size:.68rem;color:#C9A84C;margin-top:.15rem">' + p.poste.name + '</div>' : '') + '</div>';
    html += '<div style="font-size:.68rem;color:' + (p.estAssassine ? '#cc2020' : '#4a8a4a') + '">' + (p.estAssassine ? 'Hospitalise' : 'Actif') + '</div>';
    html += '</div>';

    // Position et deplacement
    const cityName = WORLD[p.country]?.[p.currentCity]?.name || p.currentCity;
    html += '<div style="font-size:.72rem;color:#5a5040;margin-bottom:.5rem">Position : ' + cityName + (p.currentBuilding ? ' · ' + (BUILDINGS[p.currentBuilding]?.shortName || p.currentBuilding) : ' · Rue') + '</div>';

    // Ressources
    html += '<div style="display:flex;gap:.4rem;flex-wrap:wrap;margin-bottom:.5rem">';
    [['INF',p.resources.inf,'#4a6aaa'],['POP',p.resources.pop,'#aa6a4a'],['DIS',p.resources.dis,'#8a4aaa'],['HP',p.resources.hp,'#aa4a4a']].forEach(([k,v,c]) => {
      html += '<div style="font-size:.65rem;padding:.15rem .4rem;background:#0a0805;border:1px solid #1a1810"><span style="color:#4a4030">' + k + '</span> <span style="color:' + c + ';font-family:Bebas Neue,sans-serif">' + v + '</span></div>';
    });
    html += '</div>';

    // Actions de deplacement
    html += '<div style="display:flex;gap:.3rem;flex-wrap:wrap">';
    Object.entries(WORLD[p.country] || {}).forEach(([cityId, city]) => {
      if (cityId !== p.currentCity) {
        html += '<button onclick="deplacerSimule(' + i + ',\'' + cityId + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.62rem;letter-spacing:.06em;padding:.2rem .4rem;border:1px solid #2a2010;background:transparent;color:#6a5a30;cursor:pointer">→ ' + city.name + '</button>';
      }
    });
    html += '<button onclick="deplacerSimuleBatiment(' + i + ')" style="font-family:Bebas Neue,sans-serif;font-size:.62rem;letter-spacing:.06em;padding:.2rem .4rem;border:1px solid #2a4a20;background:transparent;color:#4a7a4a;cursor:pointer">Entrer ici</button>';
    html += '</div>';
    html += '</div>';
  });

  html += '<button onclick="actualiserSimules()" style="width:100%;margin-top:.5rem;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.1em;padding:.4rem;border:1px solid #3a2a10;background:transparent;color:#8a7040;cursor:pointer">Actualiser les positions</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function deplacerSimule(idx, cityId) {
  if (!state.pjSimules?.[idx]) return;
  state.pjSimules[idx].currentCity = cityId;
  state.pjSimules[idx].currentBuilding = null;
  showToast('PJ deplace', state.pjSimules[idx].name + ' est maintenant a ' + (WORLD[state.pjSimules[idx].country]?.[cityId]?.name || cityId), true);
  ouvrirPanneauSimulation();
}

function deplacerSimuleBatiment(idx) {
  if (!state.pjSimules?.[idx]) return;
  state.pjSimules[idx].currentCity = state.currentCity;
  state.pjSimules[idx].currentBuilding = state.currentBuilding;
  showToast('PJ deplace', state.pjSimules[idx].name + ' entre dans ce batiment.', true);
  // Recharger les personnes presentes
  if (state.currentBuilding && state.currentRoom) {
    const b = BUILDINGS[state.currentBuilding];
    const room = b?.rooms?.[state.currentRoom];
    if (room) renderPersonsList(room.persons || []);
  }
  ouvrirPanneauSimulation();
}

function actualiserSimules() {
  ouvrirPanneauSimulation();
}