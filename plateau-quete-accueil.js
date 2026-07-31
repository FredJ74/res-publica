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
  els.forEach(function(el) { el.classList.add('quete-accueil-surbrillance'); });
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
    texte: "Donc une bonne chambre, c'est primordial, mais un bon repas aussi. On va à l'hôtel-restaurant ? C'est le deuxième bâtiment après l'Hôtel de Ville.",
    suivant: null
  });
}

function queteAccueilVerifierEtapeBatiment(buildingId, roomId) {
  if (typeof state === 'undefined' || !state.char || !state.char.queteAccueil) return;
  const etape = state.char.queteAccueil.etape;

  if (etape === 'attente_hotel' && buildingId === 'hotel-republica') {
    state.char.queteAccueil = { etape: 'attente_bar' };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

    afficherPopupQueteAccueil({
      image: QUETE_ACCUEIL_IMAGES.jeremy,
      titre: 'Jérémy',
      texte: "Ici vous pouvez réserver une chambre, ou si vous avez les moyens, louer une suite. Une bonne nuit ici, c'est plus de PA récupérés en dormant le lendemain.",
      suivant: function() {
        queteAccueilSurbrillance('.action-btn[onclick*="reserver_chambre_hotel"]', 12000);
      }
    });
    return;
  }

  if (etape === 'attente_bar' && buildingId === 'hotel-republica' && roomId === 'bar') {
    state.char.queteAccueil = { etape: 'guide_stade' };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

    afficherPopupQueteAccueil({
      image: QUETE_ACCUEIL_IMAGES.jeremy,
      titre: 'Jérémy',
      texte: "Ici c'est un lieu un peu spécial, pas toujours bien fréquenté... Enfin, c'est ce qu'on m'a dit, je n'ai pas le droit de venir seul ici, seulement avec des adultes. Vous pouvez m'offrir un verre ? J'ai très soif à force de parler.",
      suivant: function() {
        queteAccueilSurbrillance('.action-btn[onclick*="boire_verre"]', 12000);
        afficherPopupQueteAccueil({
          image: QUETE_ACCUEIL_IMAGES.jeremy,
          titre: 'Jérémy',
          texte: "On va aller dans un super endroit : le stade de foot ! Pour ça il faut sortir puis aller sur la gauche, et ensuite, prendre la route perpendiculaire, puis tourner à droite. Au pire, si vous êtes perdu, vous pouvez consulter le plan, en haut à droite.",
          suivant: function() {
            queteAccueilSurbrillance('button[onclick*="ouvrirPlanVille"]', 12000);
          }
        });
      }
    });
    return;
  }

  if (etape === 'stade_libre' && buildingId === 'stade') {
    // On arme le minuteur une seule fois (passage a 'stade_libre_minuteur' pour ne pas le
    // reclencher a chaque changement de piece a l'interieur du stade).
    state.char.queteAccueil = { etape: 'stade_libre_minuteur' };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
    setTimeout(function() {
      if (typeof state === 'undefined' || !state.char || !state.char.queteAccueil) return;
      if (state.char.queteAccueil.etape !== 'stade_libre_minuteur') return; // le joueur a deja avance autrement
      afficherRepriseContactJeremy();
    }, 90000);
    return;
  }

  if (etape === 'guide_stade' && buildingId === 'stade') {
    state.char.queteAccueil = { etape: 'stade_libre' };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

    afficherPopupQueteAccueil({
      image: QUETE_ACCUEIL_IMAGES.jeremy,
      titre: 'Jérémy',
      texte: "Ça c'est le stade de notre équipe de Luthécia ! On y est tous très attaché. Il y a 12 clubs qui s'affrontent pour savoir qui sera le meilleur. Pour connaître le classement, il suffit de le consulter. Si vous voulez intégrer l'équipe, il faut prendre sa licence dans le vestiaire et s'entraîner jusqu'à faire partie des 15 meilleurs joueurs du club. Demandez conseil à l'entraîneur adjoint, il est là pour ça. On peut boire un coup, acheter des accessoires du club, parier sur les matchs, ou encore rejoindre le club des supporters. Attention, il ne faut pas croire mais c'est bien plus qu'un endroit où l'on fait du sport. Vous verrez à l'usage, mais ici des maires ont perdu leur poste ou à l'inverse ont été réélus selon l'humeur des supporters...",
      suivant: afficherConseilArchetypeJeremy
    });
    return;
  }

  if (etape === 'attente_entree_dispensaire' && buildingId === 'dispensaire-public') {
    state.char.queteAccueil = { etape: 'attente_fiche_personnage' };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

    afficherPopupQueteAccueil({
      image: QUETE_ACCUEIL_IMAGES.jeremy,
      titre: 'Jérémy',
      texte: "Ici c'est le dispensaire. On peut se faire soigner gratuitement, ou à moindre frais. Bien sûr, si vous êtes riche, vous pouvez aller en hôpital privé. Chaque jour, on se fatigue au travail. Il est important de se reposer en dormant. Une fois par jour seulement. Idéalement, il vaut mieux dormir dans une chambre, on récupère mieux que si on dort n'importe où.",
      suivant: function() {
        queteAccueilSurbrillance('.char-card', 15000);
      }
    });
    return;
  }

  if (etape === 'guide_salle_elections' && buildingId === 'mairie-capitale' && roomId === 'salle_elections') {
    state.char.queteAccueil = { etape: 'guide_sortie' };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

    afficherPopupQueteAccueil({
      image: QUETE_ACCUEIL_IMAGES.jeremy,
      titre: 'Jérémy',
      texte: "Ici on sera tranquille, en plus le responsable électoral est malentendant. Ici on est au cœur du système électoral car c'est ici qu'on vote. On peut aussi voir qui est candidat aux élections par exemple. Chaque pièce est dédiée à un usage. À présent, on va aller en ville. On va déjà sortir de l'Hôtel de Ville.",
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

// Reaction de Jeremy selon l'archetype deja choisi a la creation du personnage (state.char.archetype).
// Oriente vers le(s) type(s) d'organisation pertinent(s), sans poser de question ouverte au joueur.
const QUETE_ACCUEIL_CONSEILS_ARCHETYPE = {
  politician:     "Ambitieux, à ce qu'on dit sur vous... Vous comptez fonder votre propre parti, ou plutôt rejoindre une formation déjà en place ? J'en connais quelques-unes, si ça vous intéresse. Regardez du côté des organisations politiques.",
  authoritarian:  "Ordre et discipline, à ce qu'on m'a dit ! Vous devriez tenter votre chance du côté de la Caserne — on y grimpe les échelons, de simple soldat à officier, avec une vraie hiérarchie à respecter. Sinon, il paraît qu'il existe aussi une Loge assez stricte sur les principes, si la discipline version secrète vous tente davantage.",
  oligarch:       "Capitaliste ! L'argent avant tout, c'est ça ? Il existe des organisations économiques qui pourraient vous intéresser, on y parle chiffres et contrats toute la journée.",
  informer:       "Vous aimez faire circuler l'information, on dirait. Le journal du coin recrute peut-être, ou alors une organisation médiatique, si vous préférez rester dans l'ombre du micro.",
  legalist:       "Légaliste... vous devez adorer les formulaires, alors ! Ça tombe bien, on en a beaucoup ici. Sinon, la politique ou la Loge, ça vous dit ? On y respecte scrupuleusement les procédures.",
  believer:       "Une conviction profonde, à ce qu'on raconte. Vous devriez faire un tour du côté d'une organisation religieuse, ça pourrait vous parler.",
  shadow:         "Un homme de l'ombre, hein ? Discret, discret... Je ne devrais peut-être pas vous en parler, mais il existe une Loge, très discrète justement. Ou pire encore, si vous voyez ce que je veux dire.",
  anticapitalist: "Anti-capitaliste ! Vous devriez faire un tour du côté du syndicat, ils cherchent toujours du monde pour la prochaine manifestation.",
  criminal:       "Un criminel, vous ? Ne le répétez à personne, mais je m'en doutais un peu... Vous comptez travailler seul, ou plutôt rejoindre une organisation bien établie ? Il y en a une, justement, très active en ville."
};
const QUETE_ACCUEIL_CONSEIL_DEFAUT =
  "Quel que soit votre chemin, sachez qu'il existe plusieurs organisations en ville. Ça vaut le coup d'y jeter un œil.";

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

function afficherConseilArchetypeJeremy() {
  const archetype = state.char && state.char.archetype;
  const conseil = QUETE_ACCUEIL_CONSEILS_ARCHETYPE[archetype] || QUETE_ACCUEIL_CONSEIL_DEFAUT;
  afficherPopupQueteAccueil({
    image: QUETE_ACCUEIL_IMAGES.jeremy,
    titre: 'Jérémy',
    texte: conseil,
    suivant: function() {
      afficherPopupQueteAccueil({
        image: QUETE_ACCUEIL_IMAGES.jeremy,
        titre: 'Jérémy',
        texte: "Je vous laisse découvrir. Si vous avez des questions pendant la visite, n'hésitez pas à me les poser.",
        suivant: null
      });
    }
  });
}

function afficherRepriseContactJeremy() {
  state.char.queteAccueil = { etape: 'reprise_contact' };
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

  afficherPopupQueteAccueil({
    image: QUETE_ACCUEIL_IMAGES.jeremy,
    titre: 'Jérémy',
    texte: "Dites, vous avez encore besoin de moi pour découvrir la ville, ou vous vous sentez de continuer seul(e) ?",
    suivant: null,
    actionsHtml:
      '<button class="pnj-action-btn" onclick="document.getElementById(\'modal-quete-accueil\').classList.remove(\'open\'); queteAccueilRepriseOui();">' +
      '<i class="ti ti-check" style="font-size:.85rem"></i> Oui, encore un peu d\'aide</button> ' +
      '<button class="pnj-action-btn" onclick="document.getElementById(\'modal-quete-accueil\').classList.remove(\'open\'); queteAccueilRepriseNon();">' +
      '<i class="ti ti-x" style="font-size:.85rem"></i> Non merci, ça ira</button>'
  });
}

function queteAccueilRepriseOui() {
  state.char.queteAccueil = { etape: 'choix_destination' };
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

  afficherPopupQueteAccueil({
    image: QUETE_ACCUEIL_IMAGES.jeremy,
    titre: 'Jérémy',
    texte: "Où voulez-vous aller ? Le marché, les terrains à bâtir, ou le centre multimodal ?",
    suivant: null,
    actionsHtml:
      '<button class="pnj-action-btn" onclick="document.getElementById(\'modal-quete-accueil\').classList.remove(\'open\'); queteAccueilDestination(\'marche\');">Le marché</button> ' +
      '<button class="pnj-action-btn" onclick="document.getElementById(\'modal-quete-accueil\').classList.remove(\'open\'); queteAccueilDestination(\'terrains\');">Les terrains à bâtir</button> ' +
      '<button class="pnj-action-btn" onclick="document.getElementById(\'modal-quete-accueil\').classList.remove(\'open\'); queteAccueilDestination(\'multimodal\');">Le centre multimodal</button>'
  });
}

const QUETE_ACCUEIL_TEXTES_DESTINATION = {
  marche: "Le marché ? C'est plutôt vers le centre, pas très loin d'ici. Regardez le plan si besoin, en haut à droite, ça vous montrera le chemin le plus sûr.",
  terrains: "Les terrains à bâtir sont plutôt excentrés. Consultez le plan pour vous y retrouver, c'est le plus simple.",
  multimodal: "Le centre multimodal, c'est là où vous êtes arrivé en arrivant en ville. Le plan vous montrera comment y retourner facilement."
};

function queteAccueilDestination(dest) {
  state.char.queteAccueil = { etape: 'quete_terminee_avec_aide' };
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

  afficherPopupQueteAccueil({
    image: QUETE_ACCUEIL_IMAGES.jeremy,
    titre: 'Jérémy',
    texte: (QUETE_ACCUEIL_TEXTES_DESTINATION[dest] || QUETE_ACCUEIL_TEXTES_DESTINATION.marche) + " Si vous avez des questions en chemin, n'hésitez pas à me demander.",
    suivant: function() {
      queteAccueilSurbrillance('button[onclick*="ouvrirPlanVille"]', 12000);
    }
  });
}

function queteAccueilRepriseNon() {
  state.char.queteAccueil = { etape: 'quete_terminee_sans_aide' };
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

  if (typeof addContactByName === 'function') {
    addContactByName('Jérémy', 'Ancien stagiaire de la Mairie', 'ally', false);
  }
  if (typeof quitterJeremy === 'function') quitterJeremy();

  afficherPopupQueteAccueil({
    image: QUETE_ACCUEIL_IMAGES.jeremy,
    titre: 'Jérémy',
    texte: "Alors nos chemins se séparent ici. Pour le moment, bien sûr ! Si vous avez besoin de moi, envoyez-moi un mail. Je vous ai ajouté à mes contacts.",
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
