// plateau-quete-accueil.js
// Systeme de quete d'accueil pour les nouveaux joueurs de Res Publica.
// Etat sauvegarde sur le personnage : state.char.queteAccueil = { etape: '...' }
//
// Etapes de ce fichier :
//   non_commencee        -> pas encore declenchee (personnage cree apres la mise en place de la quete)
//   garde_en_cours        -> dialogue du garde presidentiel en cours
//   guide_carrefour        -> garde termine, en attente d'arrivee au carrefour (luthecia-imprimerie)
//   guide_hdv              -> en attente d'arrivee rue de la mairie (luthecia-hotel-de-ville)
//   attente_entree_mairie -> guidage termine, joueur libre d'entrer dans le bon batiment
//   (suite a coder : detection du Secretaire Petit, Jeremy, etc.)

const QUETE_ACCUEIL_IMAGES = {
  gardeMenacant: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/garde-menacant-luthecia.png',
  gardeBienveillant: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/garde-bienveillant-luthecia.png'
};

const QUETE_ACCUEIL_STYLES_FLECHES = {
  arriere:   'top:10px; left:50%; transform:translateX(-50%);',
  gauche:    'top:50%; left:14px; transform:translateY(-50%);',
  toutDroit: 'top:50%; left:80%; transform:translate(-50%,-50%);',
  droite:    'top:50%; right:14px; transform:translateY(-50%);'
};

const QUETE_ACCUEIL_ICONES_FLECHES = {
  arriere: '↓', gauche: '←', toutDroit: '↑', droite: '→'
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
  state.char.queteAccueil = { etape: 'guide_carrefour' };
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
  afficherGuidageFleche('luthecia-palais-presidentiel', 'droite');
}

function queteAccueilVerifierGuidage(pays, noeudId) {
  if (pays !== 'republic') return;
  if (typeof state === 'undefined' || !state.char || !state.char.queteAccueil) return;
  const etape = state.char.queteAccueil.etape;

  if (etape === 'guide_carrefour' && noeudId === 'luthecia-imprimerie') {
    state.char.queteAccueil = { etape: 'guide_hdv' };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
    afficherGuidageFleche('luthecia-imprimerie', 'droite');
    return;
  }

  if (etape === 'guide_hdv' && noeudId === 'luthecia-hotel-de-ville') {
    state.char.queteAccueil = { etape: 'attente_entree_mairie' };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
    afficherGuidageBatiments('luthecia-hotel-de-ville');
    return;
  }
}

function afficherGuidageFleche(noeudId, direction) {
  const noeud = (typeof RUE_CENTRALE_NOEUDS !== 'undefined') ? RUE_CENTRALE_NOEUDS.republic?.[noeudId] : null;
  if (!noeud) return;
  const image = noeud.image;
  const stylePos = (noeud.flechesStyle && noeud.flechesStyle[direction]) || QUETE_ACCUEIL_STYLES_FLECHES[direction];
  const icone = QUETE_ACCUEIL_ICONES_FLECHES[direction] || '→';

  const guidageHtml =
    '<img src="' + image + '" style="width:100%;display:block;filter:sepia(0.9) contrast(1.05) brightness(0.85)" />' +
    '<div style="position:absolute; ' + stylePos + '">' +
    '<div style="width:44px;height:44px;border-radius:50%;' +
    'background:radial-gradient(circle,#f0d488,#b8860b);border:2px solid #fff8dc;' +
    'display:flex;align-items:center;justify-content:center;font-size:1.4rem;color:#241608;' +
    'box-shadow:0 0 16px 6px rgba(230,190,90,0.75);animation:queteAccueilPulse 1.4s ease-in-out infinite;">' +
    icone + '</div></div>';

  afficherPopupQueteAccueil({
    guidageHtml: guidageHtml,
    titre: 'Suivez la route',
    texte: "Continuez dans cette direction.",
    suivant: null
  });
}

function afficherGuidageBatiments(noeudId) {
  const noeud = (typeof RUE_CENTRALE_NOEUDS !== 'undefined') ? RUE_CENTRALE_NOEUDS.republic?.[noeudId] : null;
  if (!noeud) return;
  const image = noeud.image;
  const zones = noeud.zones || [];

  const labelsHtml = zones.map(function(z) {
    const centre = (z.xPct[0] + z.xPct[1]) / 2;
    return '<div style="position:absolute; top:8px; left:' + centre + '%; transform:translateX(-50%);' +
      'max-width:23%; text-align:center; font-size:.68rem; font-weight:bold; color:#f0d488;' +
      'text-shadow:0 0 4px #000, 0 0 8px #000; line-height:1.2;">' + z.nom + '</div>';
  }).join('');

  const guidageHtml =
    '<img src="' + image + '" style="width:100%;display:block;filter:sepia(0.9) contrast(1.05) brightness(0.85)" />' +
    labelsHtml;

  afficherPopupQueteAccueil({
    guidageHtml: guidageHtml,
    titre: "Vous voici rue de l'Hotel de Ville",
    texte: "Cliquez sur le bon batiment.",
    suivant: null
  });
}

function afficherPopupQueteAccueil(opts) {
  const modal = document.getElementById('modal-quete-accueil');
  if (!modal) return;
  const imgEl = document.getElementById('quete-accueil-image');
  const guidageEl = document.getElementById('quete-accueil-guidage');
  const titreEl = document.getElementById('quete-accueil-titre');
  const texteEl = document.getElementById('quete-accueil-texte');

  if (opts.guidageHtml) {
    if (guidageEl) { guidageEl.innerHTML = opts.guidageHtml; guidageEl.style.display = ''; }
    if (imgEl) imgEl.style.display = 'none';
  } else {
    if (guidageEl) { guidageEl.style.display = 'none'; guidageEl.innerHTML = ''; }
    if (imgEl) {
      if (opts.image) { imgEl.src = opts.image; imgEl.style.display = ''; }
      else { imgEl.style.display = 'none'; }
    }
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

(function injecterStyleQueteAccueil() {
  if (document.getElementById('quete-accueil-style')) return;
  const style = document.createElement('style');
  style.id = 'quete-accueil-style';
  style.textContent = '@keyframes queteAccueilPulse { 0%,100% { transform:scale(1); } 50% { transform:scale(1.15); } }' +
    '#quete-accueil-guidage div[style*="border-radius:50%"] { transform-origin:center; }';
  document.head.appendChild(style);
})();
