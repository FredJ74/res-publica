// =====================================================================
// PLATEAU-SOCIAL-PNJ.JS — LES PNJ QUI SE SOUVIENNENT (29 septembre 2026)
// =====================================================================
//
// CE QUE CE FICHIER AJOUTE, ET CE QU'IL N'AJOUTE PAS.
//
// Il n'ajoute NI un second moteur conversationnel, NI un compteur de visites par
// piece, NI une jauge d'amitie. Un PNJ social parle exactement comme les 175
// autres -- meme RPC, meme prompt serveur, meme profil. Ce qui le distingue tient
// en une phrase : le serveur sait combien de fois il a vu ce joueur, et il le lui
// dit. Le reste -- reconnaissance, tutoiement, continuite -- en decoule tout seul.
//
// TROIS BRIQUES EXISTANTES, AUCUNE NOUVELLE.
//
//   1. declencherEntreeZone (plateau-navigation.js) — l'evenement d'entree est
//      deja pose, une fois, la ou la position du joueur devient canonique. On y
//      branche un consommateur de plus ; on n'en cree pas un.
//   2. Le patron de la quete d'accueil — l'etat avance AVANT que la fenetre ne
//      s'affiche. Ici c'est le serveur qui marque le jalon avant de le rendre :
//      un F5 entre les deux ne le rejoue pas.
//   3. Le dialogue PNJ ordinaire — cliquer sur Jean-Lou ouvre la meme fiche que
//      pour n'importe qui, et `talkToPnj` fait le reste.
//
// PAS DE JAUGE VISIBLE. Le joueur ne voit jamais un chiffre de familiarite ni de
// confiance. Il voit un vieux marin qui finit par le tutoyer, et c'est tout.

// Identifiants des PNJ sociaux — les MEMES que leurs profils serveur et que leurs
// regles de jalon. Un seul identifiant par personne, d'un bout a l'autre.
const RP_SOCIAL_LIEUX = {
  // ville / batiment / piece -> identifiant du PNJ social qui s'y tient
  'ville_a|bar-des-pecheurs|salle_bar':        'jean_lou_demer',
  'ville_a|capitaine-sauvage|salle_principale': 'marine_leroux',
  // Krasnov (Fred, 15/11/2026) : Kouzma à l'église et au tserkovny dom, Praskovia chez elle. Identifiants
  // propres à Sovarka (aucun de ces bâtiments n'existe en Républia) ; règle de jalon serveur inatteignable :
  // relation tenue, aucune interpellation automatique (migration 20261115120500).
  'ville_b|kolkhoze-spirituel|grange_sainte':     'kouzma_lapchine',
  'ville_b|maison-krasnov-eglise|piece_maison':   'kouzma_lapchine',
  'ville_b|maison-krasnov-bleue|piece_maison':    'praskovia_pakhomova',
  // Mission Novomirsk, bloc 3, point 26 (Fred, 23/11/2026) : habitants des petites maisons et résident de l'EHPAD de
  // Krasnov, PNJ sociaux (relation tenue, règle de jalon inatteignable : migration 20261123210000). Clés à quatre
  // parties (pays en tête) : l'EHPAD du gabarit existe aussi à Montrouge, en Républia.
  'soviet|ville_b|maison-krasnov|piece_maison':          'stepan_kouznetsov',
  'soviet|ville_b|maison-krasnov-bureaux|piece_maison':  'antonina_merkoulova',
  'soviet|ville_b|maison-krasnov-rouge|piece_maison':    'matvei_rybakov',
  'soviet|ville_b|maison-krasnov-terrains|piece_maison': 'ignat_lykov',
  'soviet|ville_a|maison-starovka|piece_maison':         'dolgor_tsybikova',
  'soviet|ville_b|dispensaire-public-v|ehpad':           'matvei_starikov'
};

// L'HABITUÉ DU BAR SEVER (bloc 3, point 25) : PNJ social à part. À l'entrée, le SERVEUR décide s'il offre le verre du
// jour (une fois par jour et par PJ, le verre compte dans la Santé) ou s'il accueille le PJ en se souvenant de lui
// (habitue_krasnov_accueillir, migration 20261123210000). Ce fichier ne dit que les phrases.
const RP_HABITUE_KRASNOV = { pays: 'soviet', ville: 'ville_b', batiment: 'cafe-tabac-cheminots-montrouge', piece: 'salle',
  pnj: 'L’habitué du Bar Sever' };
// Conclusion exacte décidée par Fred (point 25).
const RP_HABITUE_CONCLUSION = 'Ce verre m’a donné soif ! Et je ne dis pas ça pour que tu m’en offres un en retour, mais je ne te dirais pas non si tu le fais.';
const RP_HABITUE_TEXTES = {
  verreInconnu: 'Hé, toi ! Oui, toi, le nouveau. Au Bar Sever, on ne laisse personne boire seul. Grigori, un verre pour mon ami ! Na zdorovie !',
  verreConnu: 'Te revoilà, {nom} ! Je me souviens de toi, va. Grigori, la même chose pour mon ami ! Na zdorovie !',
  souvenir: 'Ah, {nom} ! Encore toi ! Ton verre, tu l’as déjà eu aujourd’hui, camarade. Mais assieds-toi, on causera.',
  journalVerre: 'L’habitué du Bar Sever vous offre un verre.',
  journalSouvenir: 'L’habitué du Bar Sever vous reconnaît.'
};
function habitueTexte(cle, v) {
  return String(RP_HABITUE_TEXTES[cle] || '').replace(/\{(\w+)\}/g, (m, k) => (v && k in v) ? String(v[k]) : m);
}
async function habitueKrasnovEntree(buildingId, roomId) {
  if (typeof sbRpc !== 'function') return;
  const brut = await sbRpc('habitue_krasnov_accueillir', {}).catch(function () { return null; });
  const r = Array.isArray(brut) ? brut[0] : brut;
  if (!r || r.ok !== true || !r.mode) return;
  if (state.currentBuilding !== buildingId || state.currentRoom !== roomId) return;
  // Le verre est déjà bu au serveur : la Santé affichée suit la sienne.
  if (r.mode === 'verre' && typeof r.sante === 'number') {
    state.hp = r.sante;
    if (typeof sbFicheBaseAdopter === 'function') sbFicheBaseAdopter({ hp: r.sante });
    if (typeof updateUI === 'function') updateUI();
  }
  const nom = r.nom || (state.char && state.char.name) || '';
  const texte = r.mode === 'verre'
    ? habitueTexte(r.connu ? 'verreConnu' : 'verreInconnu', { nom }) + '\n\n' + RP_HABITUE_CONCLUSION
    : habitueTexte('souvenir', { nom });
  if (!socialOuvrirFiche(RP_HABITUE_KRASNOV.pnj, buildingId, roomId, texte)) return;
  if (typeof addJournalEntry === 'function') addJournalEntry(habitueTexte(r.mode === 'verre' ? 'journalVerre' : 'journalSouvenir'), 'event-info');
}

// Ce que chaque jalon dit, et de qui. Le SERVEUR decide QUAND ; ce fichier sait
// QUOI. C'est la separation qui permet d'ajouter les sept autres PNJ sociaux sans
// toucher au serveur autrement qu'en donnees.
const RP_SOCIAL_JALONS = {
  abordage_deuxieme_visite: {
    pnj: 'Jean-Lou Demer',
    portrait: 'images/port-sainte-marie-bar-pecheurs-jean-lou-demer.webp',
    // Texte EXACT, « moussaillon » avec deux S.
    texte: function () {
      const original = 'Alors moussaillon, on apprécie l\'endroit ? C\'est la deuxième fois que je vous vois venir ici.';
      return (typeof window !== 'undefined' && window.RPSocialPnjI18n?.format?.('jeanLou', {}, original)) || original;
    }
  },
  accueil_premiere_visite: {
    pnj: 'Marine Leroux',
    portrait: 'images/port-sainte-marie-pnj-marine-leroux.webp',
    // TROIS BRANCHES, UNE SEULE VIVANTE AUJOURD'HUI. Le jeu n'enregistre nulle part
    // le genre d'un personnage joueur : verifie en base et dans tout le code, il
    // n'existe que pour les PNJ. La branche neutre est donc celle qui s'applique,
    // et c'est le comportement attendu. Les deux autres sont conservees, sans effet
    // de bord, pour le jour ou cette donnee existera -- on ne devine JAMAIS.
    texte: function (nom) {
      const g = socialGenreJoueur();
      const civilite = g === 'H' ? 'Monsieur ' : (g === 'F' ? 'Madame ' : '');
      const original = 'Bonjour ' + civilite + nom + ', bienvenue dans notre restaurant Capitaine Sauvage. '
           + 'N\'ayez crainte, c\'est le surnom de mon Papa, mais il est très gentil.';
      return (typeof window !== 'undefined' && window.RPSocialPnjI18n?.format?.('marine', {name: nom}, original)) || original;
    }
  }
};

// Le genre n'est lu QUE s'il existe reellement. Aucune deduction depuis le prenom,
// l'archetype ou la photo : on rend null, et la formulation neutre s'applique.
function socialGenreJoueur() {
  const c = (typeof state !== 'undefined' && state.char) ? state.char : null;
  if (!c) return null;
  // `stats.genre` EST LA SOURCE (2 octobre 2026) : c'est la ou la creation de personnage l'ecrit,
  // et la ou le serveur le lit (pnj_social_entrer : stats->>'genre'). Les deux autres lectures
  // sont conservees pour un personnage qui porterait la donnee autrement -- elles ne couteront
  // jamais rien et evitent un cas particulier le jour ou une autre porte l'ecrira.
  const g = c.stats?.genre || c.genre || c.sexe || null;
  return (g === 'H' || g === 'F') ? g : null;
}

function socialPnjDuLieu(ville, buildingId, roomId) {
  const pays = (typeof state !== 'undefined' && state) ? state.country : null;
  return RP_SOCIAL_LIEUX[[pays, ville, buildingId, roomId].join('|')]
    || RP_SOCIAL_LIEUX[[ville, buildingId, roomId].join('|')] || null;
}

// ---------------------------------------------------------------------------
// ENTREE DANS LE LIEU D'UN PNJ SOCIAL
// ---------------------------------------------------------------------------
// Appelee par declencherEntreeZone. No-op immediat partout ailleurs : deux
// comparaisons de chaines, aucun appel reseau.
async function pnjSocialEntreeZone(buildingId, roomId) {
  if (typeof state === 'undefined' || !state.char) return;
  const h = RP_HABITUE_KRASNOV;
  if (state.country === h.pays && state.currentCity === h.ville && buildingId === h.batiment && roomId === h.piece) {
    return habitueKrasnovEntree(buildingId, roomId);
  }
  const pnjId = socialPnjDuLieu(state.currentCity, buildingId, roomId);
  if (!pnjId) return;
  if (typeof sbPnjSocialEntrer !== 'function') return;

  const r = await sbPnjSocialEntrer(pnjId).catch(function () { return null; });
  if (!r || r.ok !== true || r.social !== true || !r.jalon) return;
  // Le joueur a pu quitter la piece pendant l'aller-retour reseau.
  if (state.currentBuilding !== buildingId || state.currentRoom !== roomId) return;

  socialAfficherJalon(r.jalon, buildingId, roomId);
}

// ---------------------------------------------------------------------------
// LA FENETRE D'INTERVENTION
// ---------------------------------------------------------------------------
// Reutilise directement la modale de conversation (#modal-pnj), avec le meme
// champ de reponse et la meme porte IA que lors d'un clic sur le personnage.
// L'interpellation est la premiere phrase de la conversation ordinaire :
// le joueur repond immediatement avec le textarea PNJ et le moteur serveur existant.
// Le serveur social choisit le jalon ; la definition du personnage est lue dans la
// piece actuelle, pas reconstruite a partir d'un nom ou d'un portrait.
function socialAfficherJalon(jalon, buildingId, roomId) {
  const j = RP_SOCIAL_JALONS[jalon];
  if (!j) return;
  const texte = j.texte((state.char && state.char.name) || '');
  if (!socialOuvrirFiche(j.pnj, buildingId, roomId, texte)) return;

  if (typeof addJournalEntry === 'function') {
    addJournalEntry(j.pnj + ' vous adresse la parole.', 'event-info');
  }
}

// Ouvre la fiche ordinaire d'un PNJ réellement présent dans la pièce, sa première phrase déjà dite. La liste des
// personnes est celle qu'affiche la pièce (surcharge de ville, pièce ajoutée, gabarit) ; rien si le PNJ n'y est plus.
function socialOuvrirFiche(nomPnj, buildingId, roomId, texte) {
  if (typeof openPnjModal !== 'function' || typeof encodePnjSafe !== 'function') return false;
  if (state.currentBuilding !== buildingId || state.currentRoom !== roomId) return false;
  const ctx = (typeof getBuildingContext === 'function') ? getBuildingContext(buildingId) : null;
  const premiere = Object.keys(BUILDINGS?.[buildingId]?.rooms || {})[0] === roomId;
  const ro = ctx?.roomOverrides?.[roomId];
  const liste = (ro && ro.persons && ro.persons.length) ? ro.persons
    : (premiere && ctx?.persons && ctx.persons.length) ? ctx.persons
    : (ctx?.roomsExtra?.[roomId] || BUILDINGS?.[buildingId]?.rooms?.[roomId] || {}).persons || [];
  const pnj = liste.find(p => String(p.name || '').replace(/\s*\(PNJ\)\s*$/i, '').trim() === nomPnj);
  if (!pnj) return false; // Aucun dialogue si ce PNJ n'est plus reellement dans la piece.
  openPnjModal(encodePnjSafe(pnj), {initialSpeech: texte});
  return true;
}

// ---------------------------------------------------------------------------
// UNE CONVERSATION COMPTE
// ---------------------------------------------------------------------------
// Appelee par talkToPnj apres une reponse reellement obtenue. C'est elle qui
// empeche Jean-Lou d'aborder a la deuxieme visite quelqu'un a qui il a deja parle :
// le serveur refuse alors le jalon, sa regle exigeant zero conversation.
//
// No-op pour les 175 PNJ ordinaires -- le serveur rend `social:false` et rien
// n'est ecrit.
function pnjSocialNoterConversation(pnjId, paroleJoueur) {
  if (!pnjId || typeof sbPnjSocialNoter !== 'function') return;
  const identite = pnjId === 'jodie_moitout_autruche' ? 'jodie_moitout' : pnjId;
  if (!Object.prototype.hasOwnProperty.call(RP_SOCIAL_JALONS_PAR_PNJ, identite)) return;
  sbPnjSocialNoter(identite, 'conversation').catch(function () {});
  if (identite === 'jodie_moitout' && typeof sbRpc === 'function' && typeof paroleJoueur === 'string' && paroleJoueur.trim()) {
    sbRpc('jodie_enquete_contact', {p_action:'memoriser', p_reponse:paroleJoueur.slice(0,500)}).catch(function () {});
  }
  // Un seul souvenir de première conversation, depuis l'une ou l'autre adresse.
  // Le serveur vérifie la position réelle et ne dévoile jamais l'enquête avant J+3.
  if (identite === 'jodie_moitout' && typeof sbRpc === 'function'
      && state?.country === 'republic' && state.currentCity === 'capitale'
      && ['marche','la-tribune'].includes(state.currentBuilding)) {
    sbRpc('jodie_enquete_contact', { p_action:'rencontre', p_reponse:null }).catch(function () {});
  }
}

// Les PNJ qui tiennent une memoire, deduits de la table des lieux : on evite un
// aller-retour reseau pour les 175 autres a chaque phrase echangee.
const RP_SOCIAL_JALONS_PAR_PNJ = (function () {
  const t = {};
  Object.keys(RP_SOCIAL_LIEUX).forEach(function (k) { t[RP_SOCIAL_LIEUX[k]] = true; });
  t.jodie_moitout = true; // marché et rédaction : une seule relation serveur
  t.habitue_krasnov = true; // Bar Sever (bloc 3, point 25) : entrée gérée à part, conversations comptées comme les autres
  return t;
})();
