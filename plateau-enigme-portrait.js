// plateau-enigme-portrait.js
// Enigme freemium n°1 de Luthecia — Le Portrait Disparu.
// Etat sauvegarde sur le personnage : state.char.enigme1 = { etape, variante, dateDeclenchement }
//
// Etapes :
//   (absent / non_commencee) -> pas encore declenchee (personnage cree il y a moins de 3 jours)
//   declenchee               -> le mystere a ete annonce dans le journal, le joueur peut aller au musee
//   relancee                 -> relance unique a J+6 si le joueur n'a toujours rien fait
//   (suite a coder : resolution de l'enquete)

const ENIGME1_VARIANTES = ['maire', 'criminel', 'entrepreneur', 'plume'];

const ENIGME1_RUMEURS = {
  maire:        "Une rumeur circule en ville : il paraît qu'on chuchote des choses étranges sur d'anciens édiles, à la mairie...",
  criminel:     "Une rumeur circule en ville : un vieux fait divers refait surface, à ce qu'on raconte...",
  entrepreneur: "Une rumeur circule en ville : des rumeurs circulent sur les grandes fortunes d'autrefois...",
  plume:        "Une rumeur circule en ville : on dit que certains articles de presse cachaient bien des choses, jadis..."
};

// Une fois l'enigme declenchee (et tant qu'elle n'est pas resolue), les 4 salles du musee de
// la ville affichent un cadre vide — quel que soit le tirage de variante du joueur (qui ne
// sert qu'a varier le texte de la rumeur ci-dessus).
const ENIGME1_SALLES_CADRE_VIDE = {
  salle_maires: {
    imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-maires-cadre-vide-luthecia.png',
    imageGrosPlan: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/cadre-vide-torcieu-maire.png',
    personnage: 'Marcel Torcieu',
    dates: '1895–1958',
    texteAccroche: "Étrange qu'un portrait manque justement ici... Les archives de la Mairie permettraient sans doute d'en apprendre davantage sur cet homme."
  },
  salle_criminels: {
    imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-criminels-cadre-vide-luthecia.png',
    imageGrosPlan: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/cadre-vide-caillon-criminel.png',
    personnage: 'Maurice Caillon',
    dates: '1901–1954',
    texteAccroche: "Étrange qu'un portrait manque justement ici... Le Commissariat permettrait sans doute d'en apprendre davantage sur cet homme."
  },
  salle_entrepreneurs: {
    imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-entrepreneurs-cadre-vide-luthecia.png',
    imageGrosPlan: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/cadre-vide-moulin-entrepreneur.png',
    personnage: 'Jacques Moulin',
    dates: '1897–1965',
    texteAccroche: "Étrange qu'un portrait manque justement ici... L'Étude Notariale permettrait sans doute d'en apprendre davantage sur cet homme."
  },
  salle_plumes: {
    imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-plumes-cadre-vide-luthecia.png',
    imageGrosPlan: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/cadre-vide-tintabin-plume.png',
    personnage: 'Étienne Tintabin',
    dates: '1898–1969',
    texteAccroche: "Étrange qu'un portrait manque justement ici... L'Imprimerie L'Autruche Entravée permettrait sans doute d'en apprendre davantage sur cet homme."
  }
};

// L'enigme est "active" (cadres vides visibles) tant qu'elle a ete declenchee et n'est pas
// encore marquee comme resolue (etape future, non geree ici).
function enigme1EtapeActive() {
  return typeof state !== 'undefined' && state.char && state.char.enigme1 &&
    (state.char.enigme1.etape === 'declenchee' || state.char.enigme1.etape === 'relancee');
}

// Renvoie l'image "cadre vide" a afficher pour cette piece, ou null si non concernee.
// Appelee depuis la chaine de priorite d'image dans enterRoom (plateau-navigation.js).
function enigme1ImageSalleVide(buildingId, roomId) {
  if (buildingId !== 'musee-ville-luthecia') return null;
  if (!enigme1EtapeActive()) return null;
  const info = ENIGME1_SALLES_CADRE_VIDE[roomId];
  return info ? info.imageUrl : null;
}

// Injecte (ou retire) une zone cliquable generreuse sur la bande des portraits, permettant
// d'examiner le cadre vide. Appelee juste apres l'affichage de l'image de la piece.
function enigme1InjecterZoneCliquable(buildingId, roomId) {
  const pieceImg = document.getElementById('piece-image');
  if (!pieceImg) return;
  pieceImg.querySelectorAll('.enigme1-zone-cadre').forEach(function(el) { el.remove(); });

  if (buildingId !== 'musee-ville-luthecia') return;
  if (!enigme1EtapeActive()) return;
  const info = ENIGME1_SALLES_CADRE_VIDE[roomId];
  if (!info) return;

  pieceImg.style.position = pieceImg.style.position || 'relative';
  const div = document.createElement('div');
  div.className = 'enigme1-zone-cadre';
  div.style.cssText = 'position:absolute;left:0;right:0;top:25%;height:45%;cursor:pointer;';
  div.title = 'Examiner les portraits';
  div.onclick = function() { enigme1AfficherPopupCadreVide(roomId); };
  pieceImg.appendChild(div);
}

// Affiche la pop-up du cadre vide (reutilise le modal generique #modal-postes).
function enigme1AfficherPopupCadreVide(roomId) {
  const info = ENIGME1_SALLES_CADRE_VIDE[roomId];
  if (!info) return;

  let html = '<div style="padding:1.2rem">';
  if (info.imageGrosPlan) {
    html += '<img src="' + info.imageGrosPlan + '" style="width:100%;border-radius:4px;margin-bottom:.9rem;display:block" />';
  }
  html += '<div style="font-size:1rem;color:#C9A84C;font-family:Bebas Neue,sans-serif;letter-spacing:.05em;margin-bottom:.3rem">Un cadre vide</div>';
  html += '<div style="font-size:.9rem;color:#e0d8c0;margin-bottom:.5rem">Seule la plaque subsiste : <strong>' + info.personnage + '</strong> (' + info.dates + ').</div>';
  html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic;line-height:1.5">' + info.texteAccroche + '</div>';
  html += '</div>';

  document.getElementById('postes-modal-title').textContent = 'Cadre vide';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}
const ENIGME1_DELAI_DECLENCHEMENT_JOURS = 3;
const ENIGME1_DELAI_RELANCE_JOURS = 6; // 3 jours apres le declenchement

// Appelee a chaque synchronisation du personnage (hook dans plateau-core.js). Verifie si le
// delai est ecoule et declenche/relance le mystere du musee si besoin. Base sur la vraie date
// de creation du personnage (createdAt), pas sur un minuteur JS ni sur state.day (qui pourrait
// etre partage/different selon le contexte).
function enigme1VerifierDeclenchement() {
  if (typeof state === 'undefined' || !state.char || !state.char.createdAt) return;

  if (!state.char.enigme1) {
    state.char.enigme1 = { etape: 'non_commencee', variante: null };
  }
  const e = state.char.enigme1;

  const maintenant = Date.now();
  const creation = new Date(state.char.createdAt).getTime();
  const joursEcoules = (maintenant - creation) / (1000 * 60 * 60 * 24);

  if (e.etape === 'non_commencee' && joursEcoules >= ENIGME1_DELAI_DECLENCHEMENT_JOURS) {
    // Tirage aleatoire de la variante — fixe definitivement pour ce joueur. Ne change RIEN
    // aux salles affichees (les 4 sont toujours vides pour un joueur concerne) : sert
    // uniquement a varier le texte de la rumeur/du journal, pour alimenter les echanges
    // entre joueurs sans changer la mecanique de jeu.
    const variante = ENIGME1_VARIANTES[Math.floor(Math.random() * ENIGME1_VARIANTES.length)];
    state.char.enigme1 = { etape: 'declenchee', variante: variante, dateDeclenchement: new Date().toISOString() };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
    if (typeof addJournalEntry === 'function') {
      const rumeur = ENIGME1_RUMEURS[variante] || ENIGME1_RUMEURS.maire;
      addJournalEntry(rumeur, 'event-secret');
    }
    return;
  }

  if (e.etape === 'declenchee' && joursEcoules >= ENIGME1_DELAI_RELANCE_JOURS) {
    state.char.enigme1.etape = 'relancee';
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
    if (typeof addJournalEntry === 'function') {
      addJournalEntry("La rumeur persiste : le mystère du musée de la ville n'est toujours pas éclairci...", 'event-secret');
    }
  }
}
