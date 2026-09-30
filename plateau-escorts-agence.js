// =====================================================================
// PLATEAU-ESCORTS-AGENCE.JS — CHOISIR UNE PERSONNE (1er octobre 2026)
// =====================================================================
//
// CE QUE CE FICHIER REMPLACE. Le bar postait deux escorts nommees, et embaucher
// l'une d'elles en faisait apparaitre une autre, prenom tire au hasard dans une
// liste et portrait tire au hasard dans une autre -- le tout perdu au premier
// rechargement de page. Personne ne pouvait donc se souvenir de personne.
//
// CE QU'IL FAIT. Le comptoir devient un point d'acces : on s'adresse a l'agence,
// et l'agence presente SES GENS. Les identites viennent du catalogue, en base,
// filtrees par le serveur sur l'empire ou se trouve le joueur -- un casting
// n'existe jamais hors de son empire.
//
// LE CHOIX RESSEMBLE A UNE RENCONTRE, PAS A UNE SELECTION TECHNIQUE. C'est une
// exigence de game design, et elle commande la forme : un bandeau de visages,
// jamais une liste de noms. Chaque fiche porte donc sa vignette et son prenom.
//
// AUCUN ECRAN DE FICHE N'EST REECRIT ICI. Choisir quelqu'un ouvre la fiche PNJ
// ordinaire, celle de tout le jeu, construite depuis la ligne du catalogue. Les
// actions -- engager, kompromat, confidences -- restent ou elles etaient.

// Le catalogue ne change pas en cours de partie : on le relit une fois, puis on
// le garde. Vide au changement d'empire, puisque le casting en depend.
let RP_AGENCE = null;
// La confidente du joueur, relue en meme temps que le catalogue. Elle n'a rien a
// voir avec l'emploi : un joueur peut avoir une confidente qu'il n'emploie pas,
// et employer quatre personnes sans en avoir choisi aucune.
let RP_CONFIDENTE = null;

function escortsAgenceOublier() { RP_AGENCE = null; }

async function escortsAgenceCatalogue() {
  if (RP_AGENCE && RP_AGENCE.pays === state.country) return RP_AGENCE;
  if (typeof sbEscortsAgence !== 'function') return null;
  const r = await sbEscortsAgence().catch(function () { return null; });
  if (!r || r.ok !== true) return null;
  RP_AGENCE = r;
  if (typeof sbEscortSocialeActuelle === 'function') {
    const c = await sbEscortSocialeActuelle().catch(function () { return null; });
    RP_CONFIDENTE = (c && c.ok === true) ? (c.escort_id || null) : null;
  }
  return r;
}

function escortsAgenceEstConfidente(escortId) { return RP_CONFIDENTE === escortId; }

// ---------------------------------------------------------------------------
// DESIGNER SA CONFIDENTE
// ---------------------------------------------------------------------------
// UN ACTE EXPLICITE, jamais une consequence. C'est une ressource rare -- une
// seule par joueur -- et une designation implicite surprendrait au mauvais
// moment. Elle n'engage ni argent, ni PA, et ne depend pas de l'emploi.
async function escortsAgenceConfidente(escortId) {
  if (typeof sbEscortSocialeChoisir !== 'function') return;
  const r = await sbEscortSocialeChoisir(escortId).catch(function () { return null; });
  if (!r || r.ok !== true) {
    showToast('Refusé', 'Ce choix n\'a pas pu être enregistré.', false);
    return;
  }
  RP_CONFIDENTE = r.escort_id || escortId;
  if (r.inchange) return;
  if (r.precedente_nom) {
    showToast('Vous vous confiez désormais à ' + r.nom,
              r.precedente_nom + ' n\'était plus la bonne oreille.', true, true);
  } else {
    showToast('Vous vous confiez à ' + r.nom,
              'Elle se souviendra de vous, désormais.', true, true);
  }
  if (typeof addJournalEntry === 'function') {
    addJournalEntry('Vous vous confiez désormais à ' + r.nom + '.', 'event-info');
  }
  const m = document.getElementById('modal-pnj');
  if (m) m.classList.remove('open');
}

// ---------------------------------------------------------------------------
// LE BANDEAU
// ---------------------------------------------------------------------------
// Appele depuis openPnjModal quand on clique un point d'acces. `genre` vient du
// point d'acces clique, pas d'un choix du joueur : on s'adresse a l'hotesse ou a
// l'hote, et c'est son carnet qu'on ouvre.
async function escortsAgenceOuvrir(genre) {
  const titre = document.getElementById('postes-modal-title');
  const corps = document.getElementById('postes-body');
  const modale = document.getElementById('modal-postes');
  if (!titre || !corps || !modale) return;

  const ech = (t) => (typeof escapeHtmlText === 'function')
    ? escapeHtmlText(String(t == null ? '' : t)) : String(t == null ? '' : t);

  titre.textContent = 'Agence';
  corps.innerHTML = '<div style="padding:1.2rem;color:#8a8060;font-family:Crimson Pro,serif">Un instant…</div>';
  modale.classList.add('open');

  const cat = await escortsAgenceCatalogue();
  if (!cat) {
    corps.innerHTML = '<div style="padding:1.2rem;color:#8a8060;font-family:Crimson Pro,serif">'
      + 'L\'agence ne répond pas pour le moment.</div>';
    return;
  }

  titre.textContent = cat.agence || 'Agence';

  // UN EMPIRE SANS CASTING EST UN ETAT VALIDE, pas une panne : ses personnages
  // n'ont simplement pas encore ete ecrits, et on ne va pas lui preter ceux d'un
  // autre empire.
  const gens = (cat.escorts || []).filter(function (e) { return e.genre === genre; });
  if (!cat.agence || gens.length === 0) {
    corps.innerHTML = '<div style="padding:1.2rem;color:#8a8060;font-family:Crimson Pro,serif;line-height:1.6">'
      + 'L\'agence n\'a personne à vous présenter ici.</div>';
    return;
  }

  const employes = escortsAgenceEmployees();
  const places = escortsAgencePlacesRestantes();

  let h = '<div style="padding:1rem 1.1rem">';
  h += '<div style="font-size:.82rem;color:#a09060;font-family:Crimson Pro,serif;font-style:italic;'
    +  'line-height:1.6;margin-bottom:.9rem">'
    +  ech('« Prenez le temps de choisir. Elles ne se ressemblent pas. »')
    +  '</div>';

  h += '<div style="display:flex;flex-wrap:wrap;gap:.7rem">';
  gens.forEach(function (e) {
    const dejaLa = employes.indexOf(e.escort_id) !== -1;
    h += '<div onclick="escortsAgenceChoisir(\'' + e.escort_id + '\')" '
      +  'style="width:150px;cursor:pointer;border:1px solid ' + (dejaLa ? '#6a5a20' : '#2a2010') + ';'
      +  'background:#0d0b05;overflow:hidden">'
      +  '<div style="width:100%;height:100px;overflow:hidden;background:#000">'
      +  '<img src="' + e.vignette + '" alt="" loading="lazy" '
      +  'style="width:100%;height:100%;object-fit:cover;object-position:' + (e.cadrage || '50% 15%') + '"/>'
      +  '</div>'
      +  '<div style="padding:.4rem .5rem">'
      +  '<div style="font-family:Playfair Display,serif;font-size:.92rem;color:#E8C97A">' + ech(e.nom) + '</div>'
      +  (escortsAgenceEstConfidente(e.escort_id)
          ? '<div style="font-size:.7rem;color:#E8C97A;font-family:Crimson Pro,serif">votre confidente</div>'
          : (dejaLa
            ? '<div style="font-size:.7rem;color:#8a8060;font-family:Crimson Pro,serif">déjà avec vous</div>'
            : '<div style="font-size:.7rem;color:#6a6050;font-family:Crimson Pro,serif">libre</div>'))
      +  '</div></div>';
  });
  h += '</div>';

  // LE PLAFOND EST ANNONCE. Le chemin des escorts ne le verifiait nulle part cote
  // navigateur : un joueur fortune se faisait refuser par le serveur sans avoir
  // ete prevenu. Il l'est maintenant avant de cliquer.
  h += '<div style="margin-top:.9rem;font-size:.72rem;color:#6a5030;font-family:Crimson Pro,serif">'
    +  ech(places === null ? '' : (places > 0
          ? places + ' place(s) restante(s) parmi vos dix employés.'
          : 'Vous employez déjà dix personnes : il faudra en libérer une.'))
    +  '</div>';
  h += '</div>';

  corps.innerHTML = h;
}

// Les identites deja employees par CE joueur, pour le marquage du bandeau.
function escortsAgenceEmployees() {
  return (state.employes || [])
    .filter(function (e) { return e.job === 'escort' && e.escortId; })
    .map(function (e) { return e.escortId; });
}

// Resolution d'une identite par son nom affiche. Les anciens chemins -- kompromat,
// confidences, « faire l'amour » -- ne connaissent que le nom : ils restent justes
// depuis que les noms sont STABLES, ce qu'ils n'etaient pas quand ils sortaient
// d'un tirage. Ce passe-plat leur permet d'atteindre l'identite sans les reecrire.
function escortsAgenceIdParNom(nom) {
  if (!RP_AGENCE || !nom) return null;
  const n = String(nom).replace(' (PNJ)', '').trim();
  const e = (RP_AGENCE.escorts || []).find(function (x) { return x.nom === n; });
  return e ? e.escort_id : null;
}

function escortsAgencePlacesRestantes() {
  if (typeof state === 'undefined' || !state.employes) return null;
  return Math.max(0, 10 - state.employes.length);
}

// ---------------------------------------------------------------------------
// CHOISIR QUELQU'UN
// ---------------------------------------------------------------------------
// On ouvre la fiche PNJ ORDINAIRE, construite depuis la ligne du catalogue.
// L'identite voyage dans `escortId` : c'est elle, et jamais le nom affiche, que
// les actions transmettront au serveur.
function escortsAgenceChoisir(escortId) {
  const cat = RP_AGENCE;
  if (!cat) return;
  const e = (cat.escorts || []).find(function (x) { return x.escort_id === escortId; });
  if (!e) return;

  const pnj = {
    name: e.nom,
    role: 'Escort — ' + (cat.agence || 'Agence'),
    rel: 'neutral',
    job: 'escort',
    genre: e.genre,
    escortId: e.escort_id,
    photoUrl: e.portrait,
    photoPos: e.cadrage || '50% 15%'
  };

  const modale = document.getElementById('modal-postes');
  if (modale) modale.classList.remove('open');
  if (typeof openPnjModal === 'function' && typeof encodePnjSafe === 'function') {
    openPnjModal(encodePnjSafe(pnj));
  }
}

// ---------------------------------------------------------------------------
// ENGAGER
// ---------------------------------------------------------------------------
// LE SERVEUR DECIDE, ET LUI SEUL. Le navigateur ne transmet qu'une identite ;
// c'est la RPC qui resout l'empire, verifie le plafond, debite et ecrit. En cas
// de refus, rien n'a bouge -- ni argent, ni employe.
async function escortsAgenceRecruter(escortId) {
  if (typeof sbEscortRecruter !== 'function') {
    showToast('Indisponible', 'L\'agence ne répond pas.', false); return;
  }
  const r = await sbEscortRecruter(escortId).catch(function () { return null; });
  if (!r) { showToast('Action impossible', 'L\'agence ne répond pas.', false); return; }
  if (r.ok !== true) {
    const motifs = {
      plafond_employes: 'Vous employez déjà dix personnes.',
      deja_employee:    'Elle fait déjà partie de votre groupe.',
      escort_inconnue:  'L\'agence ne connaît personne de ce nom ici.',
      paiement_refuse:  'Fonds insuffisants pour la première journée.'
    };
    showToast('Refusé', motifs[r.raison] || 'L\'agence a décliné.', false);
    return;
  }

  // L'ETAT CLIENT N'EST QU'UNE PROJECTION de ce que le serveur vient d'ecrire.
  // `escortId` y figure : c'est ce qui permet au bandeau de savoir qui est deja
  // avec vous, et au paiement quotidien de rester rattache a une personne.
  const cat = RP_AGENCE;
  const e = cat ? (cat.escorts || []).find(function (x) { return x.escort_id === escortId; }) : null;

  // UNE ESCORT VIT DANS TROIS STRUCTURES, et il faut les trois.
  //   * escortActive : c'est ELLE que payerEscorts() parcourt au reveil, et elle
  //     seule porte les consequences du non-paiement -- plainte au tribunal,
  //     -20 POP, -15 DIS, article de presse, liberation au socle ;
  //   * employes     : le panneau « Mes Employés » et le compte du plafond ;
  //   * group.members: la presence dans le groupe.
  // payerEmployes() saute volontairement les `job === 'escort'` pour ne pas les
  // facturer deux fois. N'alimenter qu'`employes` reviendrait donc a ne JAMAIS
  // les payer -- et a leur faire echapper aux sanctions d'impaye. La dette des
  // trois structures reste entiere ; ce lot ne l'aggrave pas et ne la resout pas.
  if (!state.escortActive) state.escortActive = [];
  state.escortActive.push({
    nom: r.nom, pnjId: r.pnj_id, escortId: r.escort_id, tarif: r.cout_jour,
    depuis: state.day || 1, genre: r.genre, palier: 0,
    photoUrl: e ? e.portrait : null
  });
  if (!state.employes) state.employes = [];
  state.employes.push({
    nom: r.nom, pnjId: r.pnj_id, escortId: r.escort_id, job: 'escort',
    role: 'Escort — ' + (r.agence || 'Agence'), genre: r.genre,
    cout: r.cout_jour, depuis: state.day || 1, inGroupe: true,
    photoUrl: e ? e.portrait : null, photoPos: e ? e.cadrage : '50% 15%'
  });
  if (!state.group) state.group = { members: [] };
  if (!state.group.members) state.group.members = [];
  if (state.group.members.indexOf(r.nom) === -1) state.group.members.push(r.nom);

  if (typeof sauvegarderPersonnageImmediat === 'function') sauvegarderPersonnageImmediat();
  if (typeof updateUI === 'function') updateUI();
  showToast(r.nom + ' vous accompagne', '-' + r.cout_jour + ' / réveil.', true, true);
  if (typeof addJournalEntry === 'function') {
    addJournalEntry('Engagement : ' + r.nom + '. -' + r.cout_jour + ' par réveil.', 'event-info');
  }
  if (typeof addExternalEvent === 'function') {
    addExternalEvent('👀 ' + (state.char?.name || 'Anonyme') + ' est vu(e) accompagné(e) de ' + r.nom + '.');
  }
  const modale = document.getElementById('modal-pnj');
  if (modale) modale.classList.remove('open');
}
