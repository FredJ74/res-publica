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
  gardeBienveillant: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/garde-bienveillant-luthecia.png',
  jeremy: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/jeremy-stagiaire-mairie.png'
};

// Reponse acceptee/refusee a la proposition d'aide de Jeremy (declenchee depuis plateau-pnj.js
// quand le joueur repond "je suis nouveau" au Secretaire Municipal Petit).
function queteAccueilAccepterJeremy() {
  state.char.queteAccueil = { etape: 'jeremy_groupe' };
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
  if (typeof rejoindreJeremy === 'function') rejoindreJeremy();

  afficherPopupQueteAccueil({
    image: QUETE_ACCUEIL_IMAGES.jeremy,
    titre: 'Jérémy',
    texte: "Bonjour, je suis Jérémy, le stagiaire à tout faire de ce maudit Hôtel de Ville. Je suis bien content de pouvoir vous guider, le secrétaire n'arrête pas de me demander de lui faire du café et des photocopies. On va commencer par aller dans un endroit plus calme. On va aller dans la salle des élections.",
    suivant: function() {
      state.char.queteAccueil = { etape: 'guide_salle_elections' };
      if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
      queteAccueilSurbrillance('.piece-tab[onclick*="salle_elections"]', 12000);
    }
  });
}

// =====================
// GUIDAGE SUR DE VRAIS ELEMENTS D'INTERFACE (surbrillance doree, pas une image)
// =====================

// Ajoute une surbrillance doree pulsante sur le(s) element(s) correspondant au selecteur,
// pendant la duree donnee (ou 10s par defaut). Utilise pour les boutons reels de l'interface
// (onglets de piece, bouton Sortir...) plutot que l'image sepia utilisee pour la rue.
function queteAccueilSurbrillance(selector, dureeMs) {
  const els = document.querySelectorAll(selector);
  if (!els.length) return;
  els.forEach(function(el) {
    el.classList.add('quete-accueil-surbrillance');
    // Retire la surbrillance des qu'on clique reellement dessus, plutot que d'attendre
    // un delai fixe qui pouvait disparaitre avant meme que le joueur ait eu le temps de cliquer.
    const retirerAuClic = function() {
      el.classList.remove('quete-accueil-surbrillance');
      el.removeEventListener('click', retirerAuClic);
    };
    el.addEventListener('click', retirerAuClic, { once: true });
  });
  // Filet de securite si le joueur ne clique jamais : on retire quand meme apres un delai.
  setTimeout(function() {
    els.forEach(function(el) { el.classList.remove('quete-accueil-surbrillance'); });
  }, dureeMs || 10000);
}

// Declenche depuis le hook ajoute dans enterRoom() (plateau-navigation.js).
// Declenchee depuis le hook ajoute dans closeCharSheet() (plateau-personnage.js).
function queteAccueilApresFichePersonnage() {
  if (typeof state === 'undefined' || !state.char || !state.char.queteAccueil) return;
  if (state.char.queteAccueil.etape !== 'attente_fiche_personnage') return;

  state.char.queteAccueil = { etape: 'attente_hotel' };
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

  afficherPopupQueteAccueil({
    image: QUETE_ACCUEIL_IMAGES.jeremy,
    titre: 'Jérémy',
    texte: "Donc une bonne chambre, c'est primordial, mais un bon repas aussi. Il y a tout ça à l'hôtel-restaurant. On y va ?<br><br>C'est le deuxième bâtiment après l'Hôtel de Ville. Vous vous souvenez où c'est ? On en vient. Il faut sortir du bâtiment et aller à droite.",
    suivant: null
  });
}

// Deuxieme fenetre du dispensaire (sujet distinct : sommeil/recuperation), affichee a la
// fermeture de la premiere (qui ne parle que du lieu). Un sujet par fenetre plutot qu'un
// unique pave qui melangeait les deux.
function afficherPopupQueteAccueilSommeil() {
  afficherPopupQueteAccueil({
    image: QUETE_ACCUEIL_IMAGES.jeremy,
    titre: 'Jérémy',
    texte: "Chaque jour, on se fatigue au travail. Il est important de se reposer en dormant. Une fois par jour seulement.<br><br>Idéalement, il vaut mieux dormir dans une chambre, on récupère mieux que si on dort n'importe où. Je vous montrerai juste après.",
    suivant: function() {
      queteAccueilSurbrillance('[onclick*="openSelfView"]', 15000);
    }
  });
}

function queteAccueilVerifierEtapeBatiment(buildingId, roomId) {
  if (typeof queteAccueilVerifierDepartJeremy === 'function') queteAccueilVerifierDepartJeremy();
  if (typeof state === 'undefined' || !state.char || !state.char.queteAccueil) return;
  const etape = state.char.queteAccueil.etape;

  // Filet de securite : si le joueur atteint l'Hotel de Ville par un autre chemin que le
  // nœud de rue prevu (ex: navigation directe), on effectue quand meme la transition ici,
  // plutot que de laisser la quete bloquee sur 'guide_hdv' indefiniment (bug remonte par
  // l'audit ChatGPT du 4 aout 2026 : Petit ne reconnaissait jamais "je suis nouveau").
  if (etape === 'guide_hdv' && buildingId === 'mairie-capitale') {
    state.char.queteAccueil = { etape: 'attente_entree_mairie' };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
    if (typeof afficherGuidageBatiments === 'function') afficherGuidageBatiments('luthecia-hotel-de-ville');
    queteAccueilSurbrillance('.person-card[data-enc*="Petit"]', 15000);
    return;
  }

  if (etape === 'attente_entree_mairie' && buildingId === 'mairie-capitale' && roomId === 'hall_mairie') {
    queteAccueilSurbrillance('.person-card[data-enc*="Petit"]', 15000);
  }

  if (etape === 'attente_hotel' && buildingId === 'hotel-republica') {
    state.char.queteAccueil = { etape: 'attente_bar' };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

    afficherPopupQueteAccueil({
      image: QUETE_ACCUEIL_IMAGES.jeremy,
      titre: 'Jérémy',
      texte: "Ici vous pouvez réserver une chambre, ou si vous avez les moyens, louer une suite. Une bonne nuit ici, c'est plus d'énergie pour le lendemain.",
      suivant: function() {
        queteAccueilSurbrillance('.action-btn[onclick*="reserver_chambre_hotel"]', 12000);
      }
    });
    return;
  }

  if ((etape === 'attente_bar' || etape === 'attente_bar_apres_chambre') && buildingId === 'hotel-republica' && roomId === 'bar') {
    state.char.queteAccueil = { etape: 'attente_offre_verre' };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

    afficherPopupQueteAccueil({
      image: QUETE_ACCUEIL_IMAGES.jeremy,
      titre: 'Jérémy',
      texte: "Ici c'est un lieu un peu spécial, pas toujours bien fréquenté...<br><br>Enfin, c'est ce qu'on m'a dit, je n'ai pas le droit de venir seul ici, seulement avec des adultes.<br><br>Vous pouvez m'offrir un verre ? J'ai très soif à force de parler.",
      suivant: function() {
        queteAccueilSurbrillance('.action-btn[onclick*="boire_verre"]', 12000);
      }
    });
    return;
  }

  if (etape === 'stade_libre' && buildingId === 'stade') {
    // On arme le minuteur une seule fois (passage a 'stade_libre_minuteur' pour ne pas le
    // reclencher a chaque changement de piece a l'interieur du stade). minuteurDebut est un
    // horodatage reel (pas seulement un setTimeout en memoire) pour survivre a un
    // rafraichissement de page — bug remonte par l'audit ChatGPT du 5 aout 2026.
    state.char.queteAccueil = { etape: 'stade_libre_minuteur', minuteurDebut: Date.now() };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
    setTimeout(function() {
      if (typeof state === 'undefined' || !state.char || !state.char.queteAccueil) return;
      if (state.char.queteAccueil.etape !== 'stade_libre_minuteur') return; // le joueur a deja avance autrement
      afficherRepriseContactJeremy();
    }, 60000);
    return;
  }

  // Filet de securite : si le joueur revient dans un batiment (ou recharge la page) alors
  // que le minuteur du stade est toujours en attente, on verifie l'horodatage reel plutot
  // que de compter sur le setTimeout d'origine (perdu au rafraichissement). Si les 60
  // secondes sont deja ecoulees, on declenche immediatement ; sinon on rearme le temps
  // restant exact.
  if (etape === 'stade_libre_minuteur' && state.char.queteAccueil.minuteurDebut) {
    const ecoule = Date.now() - state.char.queteAccueil.minuteurDebut;
    if (ecoule >= 60000) {
      afficherRepriseContactJeremy();
    } else if (!state.char.queteAccueil.minuteurRearme) {
      state.char.queteAccueil.minuteurRearme = true; // evite de rearmer plusieurs fois par entrees successives
      setTimeout(function() {
        if (typeof state === 'undefined' || !state.char || !state.char.queteAccueil) return;
        if (state.char.queteAccueil.etape !== 'stade_libre_minuteur') return;
        afficherRepriseContactJeremy();
      }, 60000 - ecoule);
    }
  }

  if (etape === 'guide_stade' && buildingId === 'stade') {
    state.char.queteAccueil = { etape: 'stade_attente_action' };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

    afficherPopupQueteAccueil({
      image: QUETE_ACCUEIL_IMAGES.jeremy,
      titre: 'Jérémy',
      texte: "Ça c'est le stade de notre équipe de Luthécia ! On y est tous très attaché.<br><br>Il y a 12 clubs qui s'affrontent pour savoir qui sera le meilleur. Pour connaître le classement, il suffit de le consulter.<br><br>Si vous voulez intégrer l'équipe, il faut prendre sa licence dans le vestiaire et vous entraîner jusqu'à faire partie des 15 meilleurs joueurs du club. Demandez conseil à l'entraîneur adjoint, il est là pour ça.<br><br>On peut boire un coup, acheter des accessoires du club, parier sur les matchs, ou encore rejoindre le club des supporters.<br><br>Attention, il ne faut pas croire mais c'est bien plus qu'un endroit où l'on fait du sport. Vous verrez à l'usage, mais ici des maires ont perdu leur poste ou à l'inverse ont été réélus selon l'humeur des supporters...<br><br>Allez-y, jetez un œil, essayez quelque chose !",
      suivant: null
    });
    return;
  }

  if (etape === 'attente_entree_dispensaire' && buildingId === 'dispensaire-public') {
    state.char.queteAccueil = { etape: 'attente_fiche_personnage' };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

    afficherPopupQueteAccueil({
      image: QUETE_ACCUEIL_IMAGES.jeremy,
      titre: 'Jérémy',
      texte: "Ici c'est le dispensaire. On peut se faire soigner gratuitement, ou à moindre frais. Bien sûr, si vous êtes riche, vous pouvez aller en hôpital privé pour de meilleurs soins.<br><br>Il y a aussi nos anciens, ici, à l'EHPAD. Ils sont un peu la mémoire de la ville, vous savez.<br><br>N'hésitez pas à venir leur parler.",
      suivant: afficherPopupQueteAccueilSommeil
    });
    return;
  }

  if (etape === 'guide_salle_elections' && buildingId === 'mairie-capitale' && roomId === 'salle_elections') {
    state.char.queteAccueil = { etape: 'guide_sortie' };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

    afficherPopupQueteAccueil({
      image: QUETE_ACCUEIL_IMAGES.jeremy,
      titre: 'Jérémy',
      texte: "Ici on est au cœur du système électoral car c'est ici qu'on vote.<br><br>On peut aussi voir qui est candidat aux élections par exemple.<br><br>Chaque pièce est dédiée à un usage.<br><br>À présent, on va aller en ville. On va déjà sortir de l'Hôtel de Ville.",
      suivant: function() {
        // Les deux boutons reels concernes sont mis en surbrillance en meme temps :
        // "Voir les candidats" (bouton d'ordre de la piece) et "Sortir" (bouton de batiment).
        queteAccueilSurbrillance('.action-btn[onclick*="consulter_elections"]', 12000);
        queteAccueilSurbrillance('.sortir-btn', 12000);
      }
    });
  }
}


function queteAccueilRefuserJeremy() {
  state.char.queteAccueil = { etape: 'refusee' };
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
}

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
    texte: "Hey, vous !<br><br>Vous n'êtes pas autorisé à rester ici ! Le Président va bientôt sortir !<br><br>Et puis vous êtes nouveau, on ne vous a jamais vu, je me trompe ? Allez vous présenter à l'Hôtel de Ville sinon c'est au commissariat que vous finirez.",
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
    texte: "Continuez sur cette rue, ensuite il y aura un croisement.<br><br>Continuez encore une fois sur la même rue, et vous trouverez l'Hôtel de Ville.<br><br>Adressez-vous au secrétaire municipal <strong>Petit</strong>.<br><br>Il vous parlera sûrement des impôts, mais répondez-lui simplement que <strong>vous êtes nouveau</strong>, cela devrait l'adoucir.",
    suivant: afficherPopupQueteAccueilEtape4
  });
}

function afficherPopupQueteAccueilEtape4() {
  afficherPopupQueteAccueil({
    image: (state.char && state.char.photoUrl) || null,
    titre: (state.char && state.char.name) || 'Vous',
    texte: "D'accord... merci... je lui dirai que je suis nouveau...",
    suivant: terminerEtapeGardeQueteAccueil
  });
}

function terminerEtapeGardeQueteAccueil() {
  state.char.queteAccueil = { etape: 'guide_carrefour' };
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
  afficherGuidageFleche('luthecia-palais-presidentiel', 'droite');
}

function queteAccueilVerifierGuidage(pays, noeudId) {
  if (typeof queteAccueilVerifierDepartJeremy === 'function') queteAccueilVerifierDepartJeremy();
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

  if (etape === 'guide_sortie' && noeudId === 'luthecia-hotel-de-ville') {
    state.char.queteAccueil = { etape: 'attente_gauche_dispensaire' };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
    afficherPopupQueteAccueil({
      image: QUETE_ACCUEIL_IMAGES.jeremy,
      titre: 'Jérémy',
      texte: "Allons sur la gauche, j'ai quelque chose à vous montrer.",
      suivant: null
    });
    return;
  }

  if (etape === 'attente_gauche_dispensaire' && noeudId === 'luthecia-imprimerie') {
    state.char.queteAccueil = { etape: 'attente_entree_dispensaire' };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
    afficherGuidageUnBatiment('luthecia-imprimerie', 'dispensaire-public', 'Entrons ici !');
    return;
  }
}

// Variante d'afficherGuidageBatiments qui ne met en evidence qu'UN SEUL batiment cible parmi
// les zones du noeud (au lieu de nommer les 4 facades). Utilise un marqueur dore pulsant,
// comme pour les fleches de rue, plutot qu'un simple nom au-dessus de la facade.
function afficherGuidageUnBatiment(noeudId, buildingIdCible, texteAccroche) {
  const noeud = (typeof RUE_CENTRALE_NOEUDS !== 'undefined') ? RUE_CENTRALE_NOEUDS.republic?.[noeudId] : null;
  if (!noeud) return;
  const image = noeud.image;
  const zone = (noeud.zones || []).find(function(z) { return z.buildingId === buildingIdCible; });
  if (!zone) return;
  const centre = (zone.xPct[0] + zone.xPct[1]) / 2;

  const guidageHtml =
    '<img src="' + image + '" style="width:100%;display:block;filter:sepia(0.9) contrast(1.05) brightness(0.85)" />' +
    '<div style="position:absolute; top:12px; left:' + centre + '%; transform:translateX(-50%);">' +
    '<div style="width:44px;height:44px;border-radius:50%;' +
    'background:radial-gradient(circle,#f0d488,#b8860b);border:2px solid #fff8dc;' +
    'display:flex;align-items:center;justify-content:center;font-size:1.4rem;color:#241608;' +
    'box-shadow:0 0 16px 6px rgba(230,190,90,0.75);animation:queteAccueilPulse 1.4s ease-in-out infinite;">' +
    '↓</div></div>' +
    '<div style="position:absolute; top:60px; left:' + centre + '%; transform:translateX(-50%);' +
    'max-width:40%; text-align:center; font-size:.7rem; font-weight:bold; color:#f0d488;' +
    'text-shadow:0 0 4px #000, 0 0 8px #000;">' + zone.nom + '</div>';

  afficherPopupQueteAccueil({
    guidageHtml: guidageHtml,
    titre: 'Jérémy',
    texte: texteAccroche || 'Entrons ici !',
    suivant: null
  });
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

// Declenchee depuis le hook ajoute au tout debut de doOrder() (plateau-router.js).
// Recoit le nom de l'ordre (fn) que le joueur vient de cliquer, quel qu'il soit.
function queteAccueilNotifierOrdre(fn) {
  if (typeof state === 'undefined' || !state.char || !state.char.queteAccueil) return;
  const etape = state.char.queteAccueil.etape;

  if (etape === 'attente_offre_verre' && fn === 'boire_verre') {
    state.char.queteAccueil = { etape: 'guide_stade' };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
    afficherPopupQueteAccueil({
      image: QUETE_ACCUEIL_IMAGES.jeremy,
      titre: 'Jérémy',
      texte: "On va aller dans un super endroit : le stade de foot !<br><br>Pour ça il faut sortir puis aller sur la gauche, et ensuite, prendre la route perpendiculaire, puis tourner à droite.<br><br>Au pire, si vous êtes perdu, vous pouvez consulter le plan, en haut à droite.",
      suivant: function() {
        queteAccueilSurbrillance('button[onclick*="ouvrirPlanVille"]', 12000);
      }
    });
    return;
  }

  if (etape === 'stade_attente_action' && state.currentBuilding === 'stade') {
    state.char.queteAccueil = { etape: 'stade_apres_action' };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
    afficherDecouverteStade();
    return;
  }
}

// Arme le minuteur de reprise de contact (90s). Appele a la fin de la sequence du stade,
// pas seulement a l'entree dans le batiment (le joueur peut ne pas changer de piece apres).
function queteAccueilArmerMinuteurStade() {
  state.char.queteAccueil = { etape: 'stade_libre_minuteur' };
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
  setTimeout(function() {
    if (typeof state === 'undefined' || !state.char || !state.char.queteAccueil) return;
    if (state.char.queteAccueil.etape !== 'stade_libre_minuteur') return;
    afficherRepriseContactJeremy();
  }, 60000);
}

// Affichee juste apres la premiere action du joueur au stade : ne pose plus la question de
// carriere ici (elle est deja posee, sous une meilleure forme avec choix cliquables, a la
// toute fin du tronc commun — voir queteAccueilProposerCarriere). On laisse simplement le
// joueur explorer, puis on arme le minuteur de reprise de contact.
function afficherDecouverteStade() {
  afficherPopupQueteAccueil({
    image: QUETE_ACCUEIL_IMAGES.jeremy,
    titre: 'Jérémy',
    texte: "Je vous laisse découvrir le stade. Si vous avez des questions pendant la visite, n'hésitez pas à me les poser.",
    suivant: queteAccueilArmerMinuteurStade
  });
}

// Declenchee depuis le hook ajoute dans doReserverChambreHotel() (plateau-personnage.js).
function queteAccueilApresReservationChambre() {
  if (typeof state === 'undefined' || !state.char || !state.char.queteAccueil) return;
  if (state.char.queteAccueil.etape !== 'attente_bar') return; // deja reagi, ou etape non concernee

  state.char.queteAccueil = { etape: 'attente_bar_apres_chambre' };
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

  afficherPopupQueteAccueil({
    image: QUETE_ACCUEIL_IMAGES.jeremy,
    titre: 'Jérémy',
    texte: "Parfait ! Maintenant, dès que vous passerez l'ordre Dormir dans cette chambre réservée, vous vous requinquerez bien mieux. Bon, en attendant, allons faire un tour au bar, juste à côté.",
    suivant: function() {
      queteAccueilSurbrillance(".piece-tab[onclick*=\",'bar',\"]", 15000);
    }
  });
}

// Le faux choix "Oui, encore un peu d'aide / Non merci" a ete retire (les deux menaient de
// toute facon a la meme question d'orientation juste apres) : afficherRepriseContactJeremy
// est desormais un simple alias de queteAccueilRepriseNon, conserve comme point d'entree
// pour ne pas toucher ses appelants (minuteur du stade, rappel).
function afficherRepriseContactJeremy() {
  queteAccueilRepriseNon();
}

function queteAccueilRepriseNon() {
  // On ne l'ajoute plus automatiquement au repertoire : on guide plutot le joueur pour qu'il
  // clique lui-meme sur Jeremy (dans Personnes Presentes) et utilise le bouton "Ajouter au
  // repertoire" qui apparait naturellement dans sa fiche, puis le bouton Messages/Forums.
  // Jeremy quitte reellement le groupe seulement au prochain deplacement (voir
  // queteAccueilVerifierDepartJeremy, appelee depuis les deux hooks de navigation) — sauf si
  // le joueur l'ajoute d'abord a son repertoire, auquel cas c'est ce qui fait avancer la
  // quete (voir addContact, plateau-pnj.js).
  state.char.queteAccueil = { etape: 'attente_depart_jeremy' };
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

  afficherPopupQueteAccueil({
    image: QUETE_ACCUEIL_IMAGES.jeremy,
    titre: 'Jérémy',
    texte: "Je vais vous laisser découvrir la ville seul(e). Nos chemins se séparent ici. Pour le moment, bien sûr !<br><br>Si vous avez besoin de moi, cliquez sur ma fiche pour m'ajouter à vos contacts, et utilisez ensuite le bouton Messages/Forums pour m'envoyer un mail.",
    suivant: function() {
      // La derniere question d'orientation n'est plus enchainee immediatement ici : le joueur
      // n'aurait pas le temps materiel de cliquer sur la fiche de Jeremy avant qu'elle
      // n'apparaisse. Elle attend desormais que Jeremy soit reellement ajoute au repertoire
      // (addContact, plateau-pnj.js), qui appelle queteAccueilProposerCarriere a ce moment-la.
      queteAccueilSurbrillance(".person-card[onclick*=\"openPnjModal('\"]", 15000);
      queteAccueilSurbrillance('#btn-messages', 15000);
    }
  });
}

// =====================
// QUETE CARRIERE — aiguillage de Jeremy vers un referent selon l'ambition choisie
// Etat sauvegarde : state.char.queteCarriere = { ambition, etape, resultat }
//   ambition: null | 'criminel' | 'politique' | 'entrepreneurial' | 'indecis'
//   etape:    null | 'a_rencontrer' | 'en_cours' | 'terminee'
//   resultat: null | 'succes' | 'echec' (rempli a la resolution de la mini-mission)
// Chainee a la toute fin des deux sorties existantes de la quete d'accueil (avec aide et
// sans aide) — c'est le tout dernier mot de Jeremy avant de se separer du joueur pour de bon.
// =====================
const QUETE_CARRIERE_REFERENTS = {
  criminel:        { nom: 'Pat Hounette',   lieu: 'la Place du Formulaire de la Liberté' },
  politique:       { nom: 'Jean-Lou Zeure', lieu: "le Bureau National de l'Emploi" },
  entrepreneurial: { nom: 'Laurent Barre',  lieu: 'la Banque Nationale' }
};

function queteAccueilProposerCarriere() {
  // Fix 9 aout 2026 (retour de test en jeu) : la sequence de cloture carriere n'etait jamais
  // raccordee au mecanisme de reprise existant (queteAccueilRappel) - fermer cette popup avant
  // d'avoir clique un bouton (accidentellement, ou via le bug de fermeture au clic exterieur,
  // corrige separement) ne laissait aucune trace recuperable. Chaque etape de la sequence
  // enregistre desormais la sienne, avec une entree correspondante dans les rappels.
  state.char.queteAccueil = { etape: 'proposition_carriere' };
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
  afficherPopupQueteAccueil({
    image: QUETE_ACCUEIL_IMAGES.jeremy,
    titre: 'Jérémy',
    texte: "Bon, une dernière chose... Vous commencez à connaître Luthécia. Mais visiter une ville, c'est une chose. S'y faire une place, c'en est une autre. Vous avez une idée de ce que vous aimeriez devenir ?",
    suivant: null,
    actionsHtml:
      '<button class="pnj-action-btn" onclick="document.getElementById(\'modal-quete-accueil\').classList.remove(\'open\'); queteAccueilChoisirAmbition(\'criminel\');">Plutôt du côté criminel</button> ' +
      '<button class="pnj-action-btn" onclick="document.getElementById(\'modal-quete-accueil\').classList.remove(\'open\'); queteAccueilChoisirAmbition(\'politique\');">Plutôt la politique</button> ' +
      '<button class="pnj-action-btn" onclick="document.getElementById(\'modal-quete-accueil\').classList.remove(\'open\'); queteAccueilChoisirAmbition(\'entrepreneurial\');">Plutôt entreprendre</button> ' +
      '<button class="pnj-action-btn" onclick="document.getElementById(\'modal-quete-accueil\').classList.remove(\'open\'); queteAccueilChoisirAmbition(\'indecis\');">Je ne sais pas encore</button>'
  });
}

function queteAccueilChoisirAmbition(ambition) {
  state.char.queteCarriere = {
    ambition: ambition,
    etape: ambition === 'indecis' ? null : 'a_rencontrer',
    resultat: null
  };
  state.char.queteAccueil = { etape: 'carriere_orientation' };
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

  const ref = QUETE_CARRIERE_REFERENTS[ambition];
  let texte = ref
    ? "Alors allez donc voir " + ref.nom + ". Vous le trouverez à " + ref.lieu + ". Dites-lui que c'est moi qui vous envoie."
    : "Je comprends, ce n'est pas facile de se déterminer. Continuez à arpenter la ville et rencontrer les habitants, ça vous aidera à vous faire une idée.";

  // Branche criminelle (lot Pat Hounette) : le tronc commun s'arrete ici, sans repasser par la
  // sequence de cloture generique (repertoire/recontact/conclusion — deja redondante avec ce
  // que le joueur vient d'apprendre en ajoutant Jeremy). L'idee "tout acte a des consequences"
  // de l'ancienne conclusion est fusionnee directement dans cette meme fenetre plutot que d'en
  // ouvrir une nouvelle. Politique/entrepreneurial gardent la sequence complete, inchangee.
  if (ambition === 'criminel') {
    texte += " Mais sachez que tout acte a des conséquences sur l'ensemble de la société, pas seulement pour vous.";
  }

  afficherPopupQueteAccueil({
    image: QUETE_ACCUEIL_IMAGES.jeremy,
    titre: 'Jérémy',
    texte: texte,
    suivant: ambition === 'criminel' ? fermerClotureCarriere : queteAccueilCarriereRepertoire
  });
}

function queteAccueilCarriereRepertoire() {
  state.char.queteAccueil = { etape: 'carriere_repertoire' };
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
  afficherPopupQueteAccueil({
    image: QUETE_ACCUEIL_IMAGES.jeremy,
    titre: 'Jérémy',
    texte: "Au fait, tant que j'y pense : dès que vous croisez quelqu'un d'intéressant, cliquez sur sa fiche et ajoutez-le à votre répertoire — ça vous servira pour porter plainte, lancer une rumeur ciblée, ou lui envoyer un mail plus tard.",
    suivant: queteAccueilCarriereRecontact
  });
}

function queteAccueilCarriereRecontact() {
  state.char.queteAccueil = { etape: 'carriere_recontact' };
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
  afficherPopupQueteAccueil({
    image: QUETE_ACCUEIL_IMAGES.jeremy,
    titre: 'Jérémy',
    texte: "Et si jamais vous avez encore besoin de moi après ça : ajoutez-moi au répertoire tant qu'on est encore ensemble, et envoyez-moi un mail via Messages/Forums quand vous voulez. Je vous répondrai où que je sois.",
    suivant: queteAccueilCarriereConclusion
  });
  queteAccueilSurbrillance(".person-card[onclick*=\"openPnjModal('\"]", 15000);
  queteAccueilSurbrillance('#btn-messages', 15000);
}

function queteAccueilCarriereConclusion() {
  state.char.queteAccueil = { etape: 'carriere_conclusion' };
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
  const ambition = state.char?.queteCarriere?.ambition;
  const ref = QUETE_CARRIERE_REFERENTS[ambition];
  const texte = ref
    ? ref.nom + " saura vous aider, mais sachez que tout acte a des conséquences sur l'ensemble de la société, pas seulement pour vous."
    : "Sachez en tout cas que tout acte a des conséquences sur l'ensemble de la société, pas seulement pour vous.";

  afficherPopupQueteAccueil({
    image: QUETE_ACCUEIL_IMAGES.jeremy,
    titre: 'Jérémy',
    texte: texte,
    suivant: fermerClotureCarriere
  });
}

// Jeremy quitte reellement le groupe ici (retire de state.employes + re-rendu immediat de la
// liste des personnes presentes, voir quitterJeremy) : c'est le tout dernier point de la
// sequence de cloture, pas juste une fermeture visuelle de popup.
function fermerClotureCarriere() {
  // Etape terminale : evite qu'une demande de rappel ulterieure a Jeremy ne rejoue la
  // conclusion indefiniment une fois la sequence reellement terminee.
  state.char.queteAccueil = { etape: 'carriere_terminee' };
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
  if (typeof quitterJeremy === 'function') quitterJeremy();
}

// Fait quitter Jeremy du groupe reellement, au premier deplacement (rue ou batiment) suivant
// la separation choisie par le joueur. Appelee au debut des deux hooks de navigation existants.
function queteAccueilVerifierDepartJeremy() {
  if (typeof state === 'undefined' || !state.char || !state.char.queteAccueil) return;
  if (state.char.queteAccueil.etape !== 'attente_depart_jeremy') return;
  state.char.queteAccueil = { etape: 'quete_terminee_sans_aide' };
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
  if (typeof quitterJeremy === 'function') quitterJeremy();
}

// Declenchee depuis le hook ajoute dans sendMail() (forum.js) quand le joueur ecrit a Jeremy.
// Genere une reponse IA, et fait "reapparaitre" Jeremy hors groupe au Marche : le joueur devra
// s'y rendre et cliquer sur "Rejoindre le groupe" comme pour n'importe quel employe retrouve.
async function queteAccueilGenererReponseMailJeremy(subjectRecu, bodyRecu) {
  if (typeof state === 'undefined' || !state.char) return;

  // Le fait de re-proposer Jeremy au Marche
  if (!state.employes) state.employes = [];
  const dejaLa = state.employes.find(function(e) { return e.nom === 'Jérémy'; });
  if (!dejaLa) {
    state.employes.push({
      nom: 'Jérémy',
      nomComplet: 'Jérémy (PNJ)',
      role: 'Stagiaire pistonné - Hôtel de Ville',
      job: 'stagiaire',
      photoUrl: (typeof QUETE_ACCUEIL_IMAGES !== 'undefined' && QUETE_ACCUEIL_IMAGES.jeremy) || null,
      photoPos: '50% 20%',
      inGroupe: false,
      cout: 0,
      buildingId: 'marche',
      roomId: 'marche_ext'
    });
  } else if (!dejaLa.inGroupe) {
    dejaLa.buildingId = 'marche';
    dejaLa.roomId = 'marche_ext';
  }

  const prompt = "Tu es Jeremy, jeune stagiaire un peu maladroit mais serviable de l'Hotel de Ville de Luthecia, dans le jeu Res Publica. Tu vouvoies toujours le joueur.\n" +
    "Le joueur, que tu as guide dans la ville il y a quelque temps, vient de t'envoyer un mail. Sujet : \"" + subjectRecu.replace(/"/g, "'") + "\". Message : \"" + bodyRecu.replace(/"/g, "'") + "\".\n" +
    "Reponds en 2 a 3 phrases, dans ton personnage, de facon coherente avec sa demande. Termine TOUJOURS ta reponse en indiquant que tu te trouves actuellement sur la Place du Marche Central de Luthecia, et que le joueur peut venir t'y retrouver puis cliquer sur \"Rejoindre le groupe\" pour que tu l'accompagnes de nouveau. Reponds UNIQUEMENT avec ta replique, sans guillemets ni introduction.";

  let reply = "Oh, vous avez besoin de moi ? Je suis sur la Place du Marché, venez me chercher !";
  try {
    const resp = await fetch('/api/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ model: 'claude-sonnet-4-20250514', max_tokens: 300, messages: [{ role: 'user', content: prompt }] })
    });
    const data = await resp.json();
    if (data.content && data.content[0] && data.content[0].text) reply = data.content[0].text;
  } catch (e) { /* on garde la reponse de secours */ }

  const sujetReponse = 'Re: ' + subjectRecu;
  const heure = (typeof formatDateHeureJeu === 'function') ? formatDateHeureJeu() : new Date().toISOString();

  // Fix : le mail etait envoye deux fois, via deux systemes differents (sbSendMail — le
  // vrai systeme Supabase — ET un ancien systeme local getMails/saveMails, visiblement un
  // reliquat d'avant la migration, jamais retire). Bug remonte par l'audit ChatGPT du 5 aout
  // 2026 ("corriger le double envoi du courrier").
  if (typeof sbSendMail === 'function') {
    sbSendMail('Jérémy', state.char.name, sujetReponse, reply, heure).catch(function() {});
  }
  if (typeof showToast === 'function') showToast('Nouveau mail', 'Jérémy vous a répondu !', true);
}

// Explique au joueur comment se separer d'un employe recupere (Jeremy ou n'importe quel
// autre plus tard), la premiere fois que ce cas se presente dans le cadre de la quete.
function queteAccueilExpliquerLicenciement() {
  afficherPopupQueteAccueil({
    image: QUETE_ACCUEIL_IMAGES.jeremy,
    titre: 'Jérémy',
    texte: "Me revoilà ! Au fait, si un jour vous voulez vous séparer de moi (ou de n'importe quel autre employé), il suffit de cliquer sur la petite croix à côté de sa carte, dans le panneau \"Mes Employés\", à gauche.",
    suivant: function() {
      queteAccueilSurbrillance('#panel-employes, .panel-employes', 15000);
    }
  });
}

// =====================
// "MES OBJECTIFS" — carnet de quete simple : action suivante a accomplir pour l'etape en
// cours du tronc commun. Lu par afficherObjectifsSecrets() (plateau-politique.js), qui
// l'affiche a la place des objectifs secrets d'archetype tant que ce tronc commun n'est pas
// termine. Couvre volontairement jusqu'a 'proposition_carriere' (la derniere question du
// tronc commun) seulement : au-dela, le choix d'orientation appartient aux branches
// specialisees, pas encore reecrites/alimentees dans ce lot.
// =====================
const QUETE_ACCUEIL_OBJECTIFS = {
  garde_en_cours: "Présentez-vous à l'Hôtel de Ville.",
  guide_carrefour: "Rendez-vous à l'Hôtel de Ville.",
  guide_hdv: "Rendez-vous à l'Hôtel de Ville.",
  attente_entree_mairie: "Entrez à l'Hôtel de Ville et parlez au secrétaire Petit.",
  jeremy_groupe: "Suivez Jérémy dans la salle des élections.",
  guide_salle_elections: "Rendez-vous dans la salle des élections.",
  guide_sortie: "Sortez de l'Hôtel de Ville avec Jérémy.",
  attente_gauche_dispensaire: "Suivez Jérémy sur la gauche.",
  attente_entree_dispensaire: "Rendez-vous au dispensaire avec Jérémy.",
  attente_fiche_personnage: "Consultez votre fiche personnage.",
  attente_hotel: "Rendez-vous à l'hôtel-restaurant.",
  attente_bar: "Réservez une chambre à l'hôtel-restaurant.",
  attente_bar_apres_chambre: "Allez faire un tour au bar avec Jérémy.",
  attente_offre_verre: "Offrez un verre à Jérémy au bar.",
  guide_stade: "Rendez-vous au stade.",
  stade_attente_action: "Découvrez le stade.",
  stade_apres_action: "Découvrez le stade.",
  stade_libre_minuteur: "Découvrez le stade.",
  attente_depart_jeremy: "Ajoutez Jérémy à vos contacts.",
  proposition_carriere: "Dites à Jérémy ce que vous aimeriez devenir."
};

function queteAccueilObjectifActuel() {
  if (typeof state === 'undefined' || !state.char || !state.char.queteAccueil) return null;
  return QUETE_ACCUEIL_OBJECTIFS[state.char.queteAccueil.etape] || null;
}

// =====================
// RAPPEL DE L'ETAPE EN COURS — parler a Jeremy (mot-cle) rejoue le meme message et la meme
// surbrillance que ceux affiches au demarrage de l'etape en cours, pour un joueur perdu
// (clic trop rapide, popup fermee sans lire...). Couvre les etapes a partir de
// 'jeremy_groupe' (avant, Jeremy n'est pas encore rencontre).
// =====================
function queteAccueilRappel() {
  if (typeof state === 'undefined' || !state.char || !state.char.queteAccueil) return false;
  const etape = state.char.queteAccueil.etape;

  const rappels = {
    jeremy_groupe: function() {
      afficherPopupQueteAccueil({ image: QUETE_ACCUEIL_IMAGES.jeremy, titre: 'Jérémy',
        texte: "On va dans la salle des élections, vous vous souvenez ?",
        suivant: function() { queteAccueilSurbrillance('.piece-tab[onclick*="salle_elections"]', 12000); } });
    },
    guide_salle_elections: function() {
      afficherPopupQueteAccueil({ image: QUETE_ACCUEIL_IMAGES.jeremy, titre: 'Jérémy',
        texte: "On va dans la salle des élections.",
        suivant: function() { queteAccueilSurbrillance('.piece-tab[onclick*="salle_elections"]', 12000); } });
    },
    guide_sortie: function() {
      afficherPopupQueteAccueil({ image: QUETE_ACCUEIL_IMAGES.jeremy, titre: 'Jérémy',
        texte: "On sort de l'Hôtel de Ville, vous vous souvenez ?",
        suivant: function() {
          queteAccueilSurbrillance('.action-btn[onclick*="consulter_elections"]', 12000);
          queteAccueilSurbrillance('.sortir-btn', 12000);
        } });
    },
    attente_gauche_dispensaire: function() {
      afficherPopupQueteAccueil({ image: QUETE_ACCUEIL_IMAGES.jeremy, titre: 'Jérémy',
        texte: "Allons sur la gauche, j'ai quelque chose à vous montrer.", suivant: null });
    },
    attente_entree_dispensaire: function() {
      afficherGuidageUnBatiment('luthecia-imprimerie', 'dispensaire-public', 'Entrons ici !');
    },
    attente_entree_mairie: function() {
      queteAccueilSurbrillance('.person-card[data-enc*="Petit"]', 15000);
    },
    attente_fiche_personnage: function() {
      afficherPopupQueteAccueil({ image: QUETE_ACCUEIL_IMAGES.jeremy, titre: 'Jérémy',
        texte: "Allez donc consulter votre fiche personnage, je vous montrerai la suite après.",
        suivant: function() { queteAccueilSurbrillance('[onclick*="openSelfView"]', 15000); } });
    },
    attente_hotel: function() {
      afficherPopupQueteAccueil({ image: QUETE_ACCUEIL_IMAGES.jeremy, titre: 'Jérémy',
        texte: "On va à l'hôtel-restaurant, vous vous souvenez ? C'est le deuxième bâtiment après l'Hôtel de Ville, sur la droite en sortant.",
        suivant: null });
    },
    attente_bar: function() {
      afficherPopupQueteAccueil({ image: QUETE_ACCUEIL_IMAGES.jeremy, titre: 'Jérémy',
        texte: "Allons faire un tour au bar, juste à côté.",
        suivant: function() { queteAccueilSurbrillance(".piece-tab[onclick*=\",'bar',\"]", 15000); } });
    },
    attente_bar_apres_chambre: function() {
      afficherPopupQueteAccueil({ image: QUETE_ACCUEIL_IMAGES.jeremy, titre: 'Jérémy',
        texte: "Allons faire un tour au bar, juste à côté.",
        suivant: function() { queteAccueilSurbrillance(".piece-tab[onclick*=\",'bar',\"]", 15000); } });
    },
    attente_offre_verre: function() {
      afficherPopupQueteAccueil({ image: QUETE_ACCUEIL_IMAGES.jeremy, titre: 'Jérémy',
        texte: "Vous pouvez m'offrir un verre ? J'ai très soif à force de parler.",
        suivant: function() { queteAccueilSurbrillance('.action-btn[onclick*="boire_verre"]', 12000); } });
    },
    guide_stade: function() {
      afficherPopupQueteAccueil({ image: QUETE_ACCUEIL_IMAGES.jeremy, titre: 'Jérémy',
        texte: "On va au stade de foot ! Sortez, allez à gauche, puis prenez la route perpendiculaire et tournez à droite. Le plan peut vous aider, en haut à droite.",
        suivant: function() { queteAccueilSurbrillance('button[onclick*="ouvrirPlanVille"]', 12000); } });
    },
    stade_attente_action: function() {
      afficherPopupQueteAccueil({ image: QUETE_ACCUEIL_IMAGES.jeremy, titre: 'Jérémy',
        texte: "Allez-y, jetez un œil, essayez quelque chose au stade !", suivant: null });
    },
    stade_apres_action: function() { afficherDecouverteStade(); },
    stade_libre_minuteur: function() {
      afficherPopupQueteAccueil({ image: QUETE_ACCUEIL_IMAGES.jeremy, titre: 'Jérémy',
        texte: "Je vous laisse découvrir le stade. Si vous avez des questions pendant la visite, n'hésitez pas à me les poser.", suivant: null });
    },
    attente_depart_jeremy: function() {
      afficherPopupQueteAccueil({ image: QUETE_ACCUEIL_IMAGES.jeremy, titre: 'Jérémy',
        texte: "Nos chemins se séparent ici, vous vous souvenez ? Si besoin, cliquez sur ma fiche pour m'ajouter à vos contacts, puis utilisez le bouton Messages/Forums.",
        suivant: function() {
          queteAccueilSurbrillance(".person-card[onclick*=\"openPnjModal('\"]", 15000);
          queteAccueilSurbrillance('#btn-messages', 15000);
        } });
    },
    // Sequence de cloture carriere (9 aout 2026) — chaque rappel rejoue simplement la meme
    // fonction d'affichage que celle appelee au demarrage naturel de cette etape.
    proposition_carriere: function() { queteAccueilProposerCarriere(); },
    carriere_orientation: function() { queteAccueilChoisirAmbition(state.char?.queteCarriere?.ambition || 'indecis'); },
    carriere_repertoire:  function() { queteAccueilCarriereRepertoire(); },
    carriere_recontact:   function() { queteAccueilCarriereRecontact(); },
    carriere_conclusion:  function() { queteAccueilCarriereConclusion(); }
  };

  if (rappels[etape]) { rappels[etape](); return true; }
  return false;
}

function afficherPopupQueteAccueil(opts) {
  const modal = document.getElementById('modal-quete-accueil');
  if (!modal) return;

  // Ne jamais ouvrir une pop-up de quete par-dessus une fenetre deja ouverte (ex: le minuteur
  // de reprise de contact de Jeremy qui se declenche pendant que le joueur discute avec un PNJ).
  // On reessaie regulierement jusqu'a ce que la voie soit libre.
  const pnjModalOuverte = document.getElementById('modal-pnj')?.classList.contains('open');
  const autreModaleOuverte = Array.from(document.querySelectorAll('.modal-overlay.open'))
    .some(m => m.id !== 'modal-quete-accueil');
  if (pnjModalOuverte || autreModaleOuverte) {
    setTimeout(function() { afficherPopupQueteAccueil(opts); }, 2000);
    return;
  }

  // Met brievement "Mes Objectifs" en surbrillance : chaque popup de la quete correspond a
  // une etape creee ou modifiee, donc le joueur doit pouvoir retrouver ou la suivre s'il se
  // perd. Reutilise le mecanisme de surbrillance existant (pas de nouveau timer).
  if (typeof queteAccueilSurbrillance === 'function') {
    queteAccueilSurbrillance('button[onclick*="afficherObjectifsSecrets"]', 6000);
  }

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
  if (texteEl) texteEl.innerHTML = opts.texte || '';

  const actionsEl = document.getElementById('quete-accueil-actions');
  if (actionsEl) actionsEl.innerHTML = opts.actionsHtml || '';

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
    '#quete-accueil-guidage div[style*="border-radius:50%"] { transform-origin:center; }' +
    '.quete-accueil-surbrillance { outline:3px solid #e6c34a !important; box-shadow:0 0 14px 4px rgba(230,195,74,0.85) !important; border-radius:6px; animation:queteAccueilPulseBtn 1.2s ease-in-out infinite; }' +
    '@keyframes queteAccueilPulseBtn { 0%,100% { box-shadow:0 0 10px 2px rgba(230,195,74,0.6); } 50% { box-shadow:0 0 22px 8px rgba(230,195,74,0.95); } }';
  document.head.appendChild(style);
})();
