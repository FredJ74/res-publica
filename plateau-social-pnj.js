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
  'ville_a|capitaine-sauvage|salle_principale': 'marine_leroux'
};

// Ce que chaque jalon dit, et de qui. Le SERVEUR decide QUAND ; ce fichier sait
// QUOI. C'est la separation qui permet d'ajouter les sept autres PNJ sociaux sans
// toucher au serveur autrement qu'en donnees.
const RP_SOCIAL_JALONS = {
  abordage_deuxieme_visite: {
    pnj: 'Jean-Lou Demer',
    portrait: 'images/port-sainte-marie-bar-pecheurs-jean-lou-demer.png',
    // Texte EXACT, « moussaillon » avec deux S.
    texte: function () {
      return 'Alors moussaillon, on apprécie l\'endroit ? C\'est la deuxième fois que je vous vois venir ici.';
    }
  },
  accueil_premiere_visite: {
    pnj: 'Marine Leroux',
    portrait: 'images/port-sainte-marie-pnj-marine-leroux.png',
    // TROIS BRANCHES, UNE SEULE VIVANTE AUJOURD'HUI. Le jeu n'enregistre nulle part
    // le genre d'un personnage joueur : verifie en base et dans tout le code, il
    // n'existe que pour les PNJ. La branche neutre est donc celle qui s'applique,
    // et c'est le comportement attendu. Les deux autres sont conservees, sans effet
    // de bord, pour le jour ou cette donnee existera -- on ne devine JAMAIS.
    texte: function (nom) {
      const g = socialGenreJoueur();
      const civilite = g === 'H' ? 'Monsieur ' : (g === 'F' ? 'Madame ' : '');
      return 'Bonjour ' + civilite + nom + ', bienvenue dans notre restaurant Capitaine Sauvage. '
           + 'N\'ayez crainte, c\'est le surnom de mon Papa, mais il est très gentil.';
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
  return RP_SOCIAL_LIEUX[[ville, buildingId, roomId].join('|')] || null;
}

// ---------------------------------------------------------------------------
// ENTREE DANS LE LIEU D'UN PNJ SOCIAL
// ---------------------------------------------------------------------------
// Appelee par declencherEntreeZone. No-op immediat partout ailleurs : deux
// comparaisons de chaines, aucun appel reseau.
async function pnjSocialEntreeZone(buildingId, roomId) {
  if (typeof state === 'undefined' || !state.char) return;
  const pnjId = socialPnjDuLieu(state.currentCity, buildingId, roomId);
  if (!pnjId) return;
  if (typeof sbPnjSocialEntrer !== 'function') return;

  const r = await sbPnjSocialEntrer(pnjId).catch(function () { return null; });
  if (!r || r.ok !== true || r.social !== true || !r.jalon) return;
  // Le joueur a pu quitter la piece pendant l'aller-retour reseau.
  if (state.currentBuilding !== buildingId || state.currentRoom !== roomId) return;

  socialAfficherJalon(r.jalon);
}

// ---------------------------------------------------------------------------
// LA FENETRE D'INTERVENTION
// ---------------------------------------------------------------------------
// Reutilise la modale commune du jeu (#modal-postes), comme la quete d'accueil et
// les ecrans de commerce. Aucun composant nouveau, aucune refonte graphique.
function socialAfficherJalon(jalon) {
  const j = RP_SOCIAL_JALONS[jalon];
  if (!j) return;
  const nom = (state.char && state.char.name) || '';
  const ech = (t) => (typeof escapeHtmlText === 'function') ? escapeHtmlText(String(t == null ? '' : t)) : String(t == null ? '' : t);

  let html = '<div style="padding:1.1rem">';
  html += '<div style="display:flex;gap:.9rem;align-items:flex-start">';
  html += '<div style="width:88px;height:88px;flex-shrink:0;border:1px solid #3a2a10;overflow:hidden;background:#0d0b05">' +
    '<img src="' + j.portrait + '" alt="" style="width:100%;height:100%;object-fit:cover;object-position:50% 15%"/></div>';
  html += '<div style="flex:1;min-width:0">';
  html += '<div style="font-family:Playfair Display,serif;color:#E8C97A;margin-bottom:.45rem">' + ech(j.pnj) + '</div>';
  html += '<div style="font-size:.9rem;color:#c0b090;line-height:1.65;font-family:Crimson Pro,serif;font-style:italic">« ' +
    ech(j.texte(nom)) + ' »</div>';
  html += '</div></div>';
  html += '<div style="margin-top:1rem;font-size:.78rem;color:#6a6050">' +
    ech('Vous pouvez lui répondre en cliquant sur lui dans la liste des personnes présentes.') + '</div>';
  html += '</div>';

  const titre = document.getElementById('postes-modal-title');
  const corps = document.getElementById('postes-body');
  const modale = document.getElementById('modal-postes');
  if (!titre || !corps || !modale) return;
  titre.textContent = j.pnj;
  corps.innerHTML = html;
  modale.classList.add('open');

  if (typeof addJournalEntry === 'function') {
    addJournalEntry(j.pnj + ' vous adresse la parole.', 'event-info');
  }
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
function pnjSocialNoterConversation(pnjId) {
  if (!pnjId || typeof sbPnjSocialNoter !== 'function') return;
  if (!Object.prototype.hasOwnProperty.call(RP_SOCIAL_JALONS_PAR_PNJ, pnjId)) return;
  sbPnjSocialNoter(pnjId, 'conversation').catch(function () {});
}

// Les PNJ qui tiennent une memoire, deduits de la table des lieux : on evite un
// aller-retour reseau pour les 175 autres a chaque phrase echangee.
const RP_SOCIAL_JALONS_PAR_PNJ = (function () {
  const t = {};
  Object.keys(RP_SOCIAL_LIEUX).forEach(function (k) { t[RP_SOCIAL_LIEUX[k]] = true; });
  return t;
})();
