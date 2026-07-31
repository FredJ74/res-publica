// plateau-quete-accueil.js
// Systeme de quete d'accueil pour les nouveaux joueurs de Res Publica.
// Etat sauvegarde sur le personnage : state.char.queteAccueil = { etape: '...' }
// Etape 1 (ce fichier, version initiale) : dialogue du garde presidentiel a l'arrivee.

const QUETE_ACCUEIL_IMAGES = {
  gardeMenacant: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/garde-menacant-luthecia.png',
  gardeBienveillant: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/garde-bienveillant-luthecia.png'
};

function queteAccueilDoitDemarrer(pays, noeudId) {
  if (pays !== 'republic') return false;
  if (noeudId !== 'luthecia-palais-presidentiel') return false;
  if (typeof state === 'undefined' || !state.char) return false;
  if (!state.char.queteAccueil || state.char.queteAccueil.etape !== 'non_commencee') return false;
  return true;
}

function demarrerQueteAccueil() {
  state.char.queteAccueil = { etape: 'garde_en_cours' };
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

  afficherPopupQueteAccueil({
    image: QUETE_ACCUEIL_IMAGES.gardeMenacant,
    titre: 'Un garde presidentiel',
    texte: "Hey, vous ! Vous n'etes pas autorise a rester ici ! Le President va bientot sortir ! Et puis vous etes nouveau, on ne vous a jamais vu, je me trompe ? Allez vous presenter a l'Hotel de Ville sinon c'est au commissariat que vous finirez.",
    suivant: afficherPopupQueteAccueilEtape2
  });
}

function afficherPopupQueteAccueilEtape2() {
  afficherPopupQueteAccueil({
    image: (state.char && state.char.photoUrl) || null,
    titre: (state.char && state.char.name) || 'Vous',
    texte: "Je veux bien, mais ou est l'Hotel de Ville ?",
    suivant: afficherPopupQueteAccueilEtape3
  });
}

function afficherPopupQueteAccueilEtape3() {
  afficherPopupQueteAccueil({
    image: QUETE_ACCUEIL_IMAGES.gardeBienveillant,
    titre: 'Le garde presidentiel',
    texte: "Continuez sur cette rue, ensuite il y aura un croisement. Continuez encore une fois sur la meme rue, et vous trouverez l'Hotel de Ville. Adressez-vous au secretaire municipal. Il vous parlera surement des impots, mais repondez-lui simplement que vous etes nouveau, cela devrait l'adoucir.",
    suivant: afficherPopupQueteAccueilEtape4
  });
}

function afficherPopupQueteAccueilEtape4() {
  afficherPopupQueteAccueil({
    image: (state.char && state.char.photoUrl) || null,
    titre: (state.char && state.char.name) || 'Vous',
    texte: "D'accord... merci...",
    suivant: terminerEtapeGardeQueteAccueil
  });
}

function terminerEtapeGardeQueteAccueil() {
  state.char.queteAccueil = { etape: 'oriente_vers_mairie' };
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
}

function afficherPopupQueteAccueil(opts) {
  const modal = document.getElementById('modal-quete-accueil');
  if (!modal) return;
  const imgEl = document.getElementById('quete-accueil-image');
  const titreEl = document.getElementById('quete-accueil-titre');
  const texteEl = document.getElementById('quete-accueil-texte');

  if (imgEl) {
    if (opts.image) { imgEl.src = opts.image; imgEl.style.display = ''; }
    else { imgEl.style.display = 'none'; }
  }
  if (titreEl) titreEl.textContent = opts.titre || '';
  if (texteEl) texteEl.textContent = opts.texte || '';

  const closeBtn = document.getElementById('quete-accueil-close');
  if (closeBtn) {
    closeBtn.onclick = function() {
      modal.classList.remove('open');
      if (typeof opts.suivant === 'function') opts.suivant();
    };
  }
  modal.classList.add('open');
}
