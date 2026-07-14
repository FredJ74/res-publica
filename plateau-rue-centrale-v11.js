// Point d'entree par ville — sert a savoir si cette ville utilise la nouvelle navigation par scenes
const RUE_CENTRALE_DEPART = {
  republic: { capitale: 'luthecia-palais-presidentiel' }
  // Autres villes/empires a ajouter au fur et a mesure des images produites
};

/* ===========================================================
   RES PUBLICA — PLATEAU-RUE-CENTRALE.JS
   Navigation par scenes de rue (zoom/fondu), en remplacement
   de l'image statique centrale + liste de batiments a droite.
   =========================================================== */

// =====================
// DONNEES — Luthecia (capitale de Republia)
// Deux boucles qui se rejoignent aux deux bouts de la grande rue des institutions.
// IMPORTANT : remplacer les URLs par les vraies une fois les images hebergees sur GitHub
// (dossier images/), et ajuster les xPct une fois les coordonnees exactes confirmees.
// =====================
const RUE_CENTRALE_NOEUDS = {
  republic: {

    // ---- GRANDE RUE DES INSTITUTIONS (deplacement lateral) ----

    'luthecia-palais-presidentiel': {
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-palais-presidentiel.png',
      zones: [
        { xPct: [0, 22],  nom: 'Palais Présidentiel', type: 'batiment', buildingId: 'palais-presidentiel' },
        { xPct: [22, 48], nom: 'Palais Gouvernemental', type: 'batiment', buildingId: 'palais-gouvernement' },
        { xPct: [48, 74], nom: 'Assemblée Nationale', type: 'batiment', buildingId: 'assemblee' },
        { xPct: [74, 100],nom: 'Tribunal', type: 'batiment', buildingId: 'tribunal' }
      ],
      liens: { gauche: 'luthecia-tabernacle-impots', droite: 'luthecia-hotel-de-ville', toutDroit: null, arriere: null }
    },

    'luthecia-hotel-de-ville': {
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-hotel-de-ville.png',
      zones: [
        { xPct: [0, 25],  nom: 'Hôtel de Ville', type: 'batiment', buildingId: 'mairie-capitale' },
        { xPct: [25, 50], nom: 'Office Notarial', type: 'batiment', buildingId: 'office-notarial' },
        { xPct: [50, 75], nom: 'Hôtel-Restaurant La Républia', type: 'batiment', buildingId: 'hotel-republica' },
        { xPct: [75, 100],nom: 'Banque Nationale de République', type: 'batiment', buildingId: 'banque-nationale' }
      ],
      liens: { gauche: 'luthecia-palais-presidentiel', droite: 'luthecia-loge', toutDroit: null, arriere: null }
    },

    'luthecia-loge': {
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-loge.png',
      zones: [
        { xPct: [0, 25],  nom: 'Banque Privée Helvétia', type: 'batiment', buildingId: 'banque-privee' },
        { xPct: [25, 50], nom: 'Clinique Privée Saint-Luc', type: 'batiment', buildingId: 'clinique-privee' },
        { xPct: [50, 75], nom: 'Loge Maçonnique', type: 'batiment', buildingId: 'loge-maconnique' },
        { xPct: [75, 100],nom: 'Commissariat de Luthécia', type: 'batiment', buildingId: 'commissariat' }
      ],
      liens: { gauche: 'luthecia-hotel-de-ville', droite: 'luthecia-imprimerie', toutDroit: null, arriere: null }
    },

    'luthecia-imprimerie': {
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-imprimerie.png',
      zones: [
        // xPct recalibres en mesurant les vraies limites des facades sur l'image (grille de reperes) :
        // Universite 0-27%, Dispensaire 27-55%, Imprimerie 55-68%.
        // 68-100% = la rue qui s'ouvre vers les gratte-ciels, ce n'est PAS un batiment cliquable.
        { xPct: [0, 27],  nom: 'Université de Luthécia', type: 'batiment', buildingId: 'universite' },
        { xPct: [27, 55], nom: 'Dispensaire Public', type: 'batiment', buildingId: 'dispensaire-public' },
        { xPct: [55, 68], nom: 'Imprimerie — L\'Autruche Entravée', type: 'batiment', buildingId: 'la-tribune' }
      ],
      liens: { gauche: 'luthecia-loge', droite: null, toutDroit: 'luthecia-intersection-stade-commercial', arriere: null }
    },

    // ---- INTERSECTION VERS STADE / COMMERCE ----

    'luthecia-intersection-stade-commercial': {
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-intersection-stade-commercial.png',
      zones: [],
      liens: { gauche: 'luthecia-centre-commercial', droite: 'luthecia-stade-multimodal', toutDroit: 'luthecia-quartier-ambassades', arriere: 'luthecia-imprimerie' },
      flechesStyle: {
        arriere:   'bottom:10px; left:50%; transform:translateX(-50%);',
        toutDroit: 'top:10px; left:50%; transform:translateX(-50%);'
      }
    },

    // ---- QUARTIER DES AMBASSADES ----
    'luthecia-quartier-ambassades': {
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-quartier-ambassades.png',
      zones: [
        { xPct: [0, 100], nom: 'Quartier des Ambassades', type: 'batiment', buildingId: 'quartier-ambassades' }
      ],
      // droite (aeroport) reste en position par defaut (a droite, centre vertical) — deja ce qui est demande.
      liens: { gauche: 'luthecia-terrains-artisanal', droite: 'luthecia-centre-multimodal', toutDroit: null, arriere: 'luthecia-intersection-stade-commercial' },
      flechesStyle: {
        arriere: 'bottom:10px; left:50%; transform:translateX(-50%);'
      }
    },

    // ---- BRANCHE STADE / MULTIMODAL ----

    'luthecia-stade-multimodal': {
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-stade-multimodal.png',
      zones: [
        { xPct: [0, 45], nom: 'Stade de Luthécia', type: 'batiment', buildingId: 'stade' }
        // Le Centre Multimodal est visible au fond mais son entree reelle se fait au noeud suivant
      ],
      liens: { gauche: null, droite: null, toutDroit: 'luthecia-centre-multimodal', arriere: 'luthecia-intersection-stade-commercial' },
      flechesStyle: {
        arriere:   'bottom:10px; left:50%; transform:translateX(-50%);',
        toutDroit: 'top:10px; left:50%; transform:translateX(-50%);'
      }
    },

    'luthecia-centre-multimodal': {
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-centre-multimodal.png',
      zones: [
        { xPct: [0, 100], nom: 'Centre Multimodal de Luthécia', type: 'batiment', buildingId: 'centre-multinodal-luthecia' }
      ],
      liens: { gauche: null, droite: 'luthecia-imprimerie', toutDroit: null, arriere: 'luthecia-stade-multimodal' },
      flechesStyle: {
        arriere: 'bottom:10px; left:50%; transform:translateX(-50%);'
      }
    },

    // ---- BRANCHE COMMERCE / ARTISANAT / TERRAINS ----

    'luthecia-centre-commercial': {
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-centre-commercial.png',
      zones: [
        // Ordre corrige : Centre Commercial en premier, Centre d'Affaires juste apres,
        // tous deux du meme cote de la rue (partie droite de l'image — la partie gauche
        // avec les immeubles haussmanniens n'est pas cliquable). xPct estimes a l'oeil,
        // a ajuster si besoin.
        { xPct: [40, 70],  nom: 'Centre d\'Affaires',          buildingId: 'centre-affaires' },
        { xPct: [70, 100], nom: 'Centre Commercial Luthécia', type: 'batiment', buildingId: 'centre-commercial' }
      ],
      liens: { gauche: null, droite: null, toutDroit: 'luthecia-terrains-artisanal', arriere: 'luthecia-intersection-stade-commercial' },
      // Disposition personnalisee pour cette scene : retour en bas, tout droit en haut
      // (au lieu du centre, disposition par defaut)
      flechesStyle: {
        arriere:   'bottom:10px; left:50%; transform:translateX(-50%);',
        toutDroit: 'top:10px; left:50%; transform:translateX(-50%);'
      }
    },

    'luthecia-terrains-artisanal': {
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-terrains-artisanal.png',
      zones: [
        // Debut de zone decale de 0 a 8% pour laisser un espace libre a la fleche gauche
        { xPct: [8, 60],   nom: 'Terrains à Bâtir',            type: 'noeud', noeudId: 'luthecia-terrains-lots' },
        { xPct: [60, 100], nom: 'Centre Artisanal de Luthécia', type: 'batiment', buildingId: 'centre-artisanal' }
      ],
      liens: { gauche: 'luthecia-armurerie', droite: 'luthecia-quartier-ambassades', toutDroit: null, arriere: 'luthecia-centre-commercial' },
      flechesStyle: {
        arriere: 'bottom:10px; left:50%; transform:translateX(-50%);'
      }
    },

    // Vue rapprochee des 5 lots, atteinte en cliquant sur "Terrains a Batir" depuis la vue large ci-dessus
    'luthecia-terrains-lots': {
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-terrains-lots-detail.png',
      zones: [
        { xPct: [0, 20],   nom: 'Lot 1 (2150 m²)', type: 'batiment', buildingId: 'terrain-a-batir-1' },
        { xPct: [20, 40],  nom: 'Lot 2 (2300 m²)', type: 'batiment', buildingId: 'terrain-a-batir-4' },
        { xPct: [40, 60],  nom: 'Lot 3 (2300 m²)', type: 'batiment', buildingId: 'terrain-a-batir-5' },
        { xPct: [60, 80],  nom: 'Lot 4 (1850 m²)', type: 'batiment', buildingId: 'terrain-a-batir-6' },
        { xPct: [80, 100], nom: 'Lot 5 (2750 m²)', type: 'batiment', buildingId: 'terrain-a-batir-7' }
      ],
      liens: { gauche: null, droite: null, toutDroit: null, arriere: 'luthecia-terrains-artisanal' }
    },

    'luthecia-armurerie': {
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-armurerie.png',
      zones: [
        // Seule la facade de l'Armurerie Martinon (partie gauche de l'image) est cliquable —
        // le reste de la scene (place, panneaux, marche au fond) ne mene nulle part.
        // xPct estime a l'oeil sur l'image fournie : a ajuster si le clic tombe a cote a l'usage.
        { xPct: [0, 27], nom: 'Armurerie Martinon', type: 'batiment', buildingId: 'armurerie' }
      ],
      // L'ancienne fleche "droite" menait en realite en arriere vers terrains-artisanal —
      // remplacee par une vraie fleche retour, repositionnee en bas.
      liens: { gauche: null, droite: null, toutDroit: 'luthecia-tabernacle-impots', arriere: 'luthecia-terrains-artisanal' },
      flechesStyle: {
        toutDroit: 'top:10px; left:50%; transform:translateX(-50%);',
        arriere:   'bottom:10px; left:50%; transform:translateX(-50%);'
      }
    },

    // ---- TABERNACLE (referme la seconde boucle sur le Palais Présidentiel) ----

    'luthecia-tabernacle-impots': {
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-tabernacle-impots.png',
      zones: [
        // Position du Marche corrigee : il est visible a DROITE de l'image (stands, camion
        // "Ferme du Belvedere", banniere "Marche Fermier de Luthecia"), pas a gauche comme
        // code precedemment par erreur. xPct estimes a l'oeil, a ajuster si besoin.
        { xPct: [33, 68],  nom: 'Le Tabernacle des Impôts', type: 'batiment', buildingId: 'tabernacle-impots' },
        { xPct: [78, 100], nom: 'Marché de Luthécia', type: 'batiment', buildingId: 'marche' }
      ],
      // gauche menait avant vers l'armurerie (= un retour) ; c'est desormais une vraie
      // fleche retour, en bas. gauche ferme maintenant la boucle vers le Palais Presidentiel.
      // droite supprimee (elle menait au meme endroit que gauche avant, de facon confuse).
      liens: { gauche: 'luthecia-palais-presidentiel', droite: null, toutDroit: null, arriere: 'luthecia-armurerie' },
      flechesStyle: {
        arriere: 'bottom:10px; left:50%; transform:translateX(-50%);'
      }
    }
  }
};

// =====================
// ETAT + RENDU
// =====================
let rueCentraleNoeudActuel = null;

// Memorise le dernier noeud de rue visite, par pays+ville, pour que showVueRue()
// (dans plateau-navigation.js) puisse y revenir en sortant d'un batiment au lieu
// de toujours repartir du noeud de depart (RUE_CENTRALE_DEPART). C'etait la cause
// du bug "je me retrouve toujours devant le Palais Presidentiel en sortant".
let rueCentraleDerniersNoeuds = {};

function obtenirNoeudRueCentraleMemorise(pays, ville, noeudDepartParDefaut) {
  // Priorite 1 : memoire de la session en cours (evite une lecture localStorage inutile)
  if (rueCentraleDerniersNoeuds[pays + '|' + ville]) return rueCentraleDerniersNoeuds[pays + '|' + ville];
  // Priorite 2 : localStorage — survit a un vrai rafraichissement de page (qui reinitialise
  // toutes les variables JS, y compris rueCentraleDerniersNoeuds ci-dessus).
  try {
    const cle = 'respublica_ruecentrale_' + (typeof state !== 'undefined' && state.char?.name || 'default');
    const saved = JSON.parse(localStorage.getItem(cle) || 'null');
    if (saved && saved.pays === pays && saved.ville === ville && saved.noeudId) return saved.noeudId;
  } catch (e) {}
  return noeudDepartParDefaut;
}

function memoriserNoeudRueCentrale(pays, ville, noeudId) {
  rueCentraleDerniersNoeuds[pays + '|' + ville] = noeudId;
  try {
    const cle = 'respublica_ruecentrale_' + (typeof state !== 'undefined' && state.char?.name || 'default');
    localStorage.setItem(cle, JSON.stringify({ pays, ville, noeudId }));
  } catch (e) {}
}

function initialiserRueCentrale(pays, noeudDepart) {
  rueCentraleNoeudActuel = noeudDepart;
  afficherNoeudRue(pays, noeudDepart);
}

function afficherNoeudRue(pays, noeudId) {
  const noeud = RUE_CENTRALE_NOEUDS[pays]?.[noeudId];
  if (!noeud) return;
  rueCentraleNoeudActuel = noeudId;
  if (typeof state !== 'undefined' && state.currentCity) {
    memoriserNoeudRueCentrale(pays, state.currentCity, noeudId);
  }

  const conteneur = document.getElementById('rue-centrale-conteneur');
  if (!conteneur) return;

  let html = '<div class="rc-scene" id="rc-scene">';
  html += '<img class="rc-image" id="rc-image" src="' + noeud.image + '">';

  // Fleches directionnelles — uniquement celles reellement disponibles a ce noeud.
  // Position par defaut pour chaque direction, sauf si le noeud definit un
  // "flechesStyle" personnalise (utile quand la disposition standard ne convient
  // pas a une scene precise, ex: flèche "tout droit" en haut plutot qu'au centre).
  const stylesParDefaut = {
    arriere:   'top:10px; left:50%; transform:translateX(-50%);',
    gauche:    'top:50%; left:14px; transform:translateY(-50%);',
    toutDroit: 'top:50%; left:80%; transform:translate(-50%,-50%);',
    droite:    'top:50%; right:14px; transform:translateY(-50%);'
  };
  const fleches = [
    { dir: 'arriere',   icon: 'ti-arrow-back-up' },
    { dir: 'gauche',    icon: 'ti-chevron-left'  },
    { dir: 'toutDroit', icon: 'ti-arrow-up'      },
    { dir: 'droite',    icon: 'ti-chevron-right' }
  ].map(f => ({ ...f, style: noeud.flechesStyle?.[f.dir] || stylesParDefaut[f.dir] }));
  fleches.forEach(f => {
    if (noeud.liens[f.dir]) {
      html += '<div class="rc-fleche" style="' + f.style + '" onclick="deplacerRueCentrale(\'' + pays + '\',\'' + f.dir + '\')">' +
        '<i class="ti ' + f.icon + '"></i></div>';
    }
  });

  html += '<div class="rc-overlay" id="rc-overlay"><div class="rc-texte" id="rc-texte"></div></div>';
  html += '</div>';
  conteneur.innerHTML = html;

  // Zones cliquables + tooltip
  const scene = document.getElementById('rc-scene');
  noeud.zones.forEach((z, i) => {
    const div = document.createElement('div');
    div.className = 'rc-zone';
    div.style.left = z.xPct[0] + '%';
    div.style.width = (z.xPct[1] - z.xPct[0]) + '%';
    div.addEventListener('mousemove', (e) => afficherTooltipRue(e, z.nom));
    div.addEventListener('mouseleave', masquerTooltipRue);
    // Zoom leger sur toute l'image, mais avec le point d'origine du zoom place au centre
    // horizontal du batiment survole, ce qui accentue visuellement ce batiment.
    const centreZone = (z.xPct[0] + z.xPct[1]) / 2;
    div.addEventListener('mouseenter', () => {
      const img = document.getElementById('rc-image');
      if (!img) return;
      img.style.transition = 'transform 0.4s ease';
      img.style.transformOrigin = centreZone + '% 50%';
      img.style.transform = 'scale(1.06)';
    });
    div.addEventListener('mouseleave', () => {
      const img = document.getElementById('rc-image');
      if (!img) return;
      img.style.transition = 'transform 0.4s ease';
      img.style.transform = 'scale(1)';
    });
    div.addEventListener('click', () => {
      if (z.type === 'noeud') naviguerVersNoeudRue(pays, z.noeudId, z.nom);
      else entrerDansBatimentRue(z.buildingId, z.nom);
    });
    scene.appendChild(div);
  });
}

function afficherTooltipRue(e, nom) {
  let tip = document.getElementById('rc-tooltip');
  if (!tip) {
    tip = document.createElement('div');
    tip.id = 'rc-tooltip';
    tip.className = 'rc-tooltip';
    document.body.appendChild(tip);
  }
  tip.textContent = 'Entrer dans : ' + nom;
  tip.style.left = (e.pageX + 16) + 'px';
  tip.style.top = (e.pageY - 10) + 'px';
  tip.classList.add('visible');
}

function masquerTooltipRue() {
  document.getElementById('rc-tooltip')?.classList.remove('visible');
}

// Deplacement d'un noeud de rue a l'autre (fondu, sans zoom — mouvement lateral/longitudinal)
function deplacerRueCentrale(pays, direction) {
  const noeud = RUE_CENTRALE_NOEUDS[pays]?.[rueCentraleNoeudActuel];
  const destination = noeud?.liens?.[direction];
  if (!destination) return;

  const overlay = document.getElementById('rc-overlay');
  overlay.classList.add('actif');
  setTimeout(() => {
    afficherNoeudRue(pays, destination);
    document.getElementById('rc-overlay')?.classList.add('actif');
    requestAnimationFrame(() => document.getElementById('rc-overlay')?.classList.remove('actif'));
  }, 550);
}

// Entree dans un batiment : zoom sur la facade + fondu, puis reprise du flux normal du jeu
// (enterBuilding gere deja la premiere piece et son image — rien a dupliquer ici)
// Navigue vers une sous-scene (ex: vue rapprochee des lots), avec le meme effet de zoom que l'entree dans un batiment,
// mais reste dans la rue centrale au lieu d'appeler enterBuilding()
function naviguerVersNoeudRue(pays, noeudId, nom) {
  masquerTooltipRue();
  const img = document.getElementById('rc-image');
  const overlay = document.getElementById('rc-overlay');
  const texte = document.getElementById('rc-texte');

  img.style.transition = 'transform 1.1s ease';
  img.style.transform = 'scale(1.4)';
  setTimeout(() => {
    overlay.classList.add('actif');
  }, 500);
  setTimeout(() => {
    afficherNoeudRue(pays, noeudId);
    document.getElementById('rc-overlay')?.classList.add('actif');
    requestAnimationFrame(() => document.getElementById('rc-overlay')?.classList.remove('actif'));
  }, 1000);
}

function entrerDansBatimentRue(buildingId, nom) {
  masquerTooltipRue();
  const img = document.getElementById('rc-image');
  const overlay = document.getElementById('rc-overlay');
  const texte = document.getElementById('rc-texte');

  img.style.transition = 'transform 1.1s ease';
  img.style.transform = 'scale(1.4)';
  setTimeout(() => {
    texte.textContent = 'Entrée : ' + nom.toUpperCase();
    overlay.classList.add('actif');
  }, 500);
  setTimeout(() => {
    if (typeof enterBuilding === 'function') enterBuilding(buildingId);
    // Si l'entree a ete refusee (prison, hospitalisation, batiment ferme, non-membre
    // d'une loge, etc.), enterBuilding() s'arrete sans jamais basculer vers vue-batiment.
    // On verifie donc ce basculement, et si il n'a pas eu lieu, on retire le voile noir
    // de transition pour ne pas rester bloque sur un ecran noir sans retour possible.
    setTimeout(() => {
      const vueBatiment = document.getElementById('vue-batiment');
      if (!vueBatiment || !vueBatiment.classList.contains('active')) {
        document.getElementById('rc-overlay')?.classList.remove('actif');
        if (img) img.style.transform = 'scale(1)';
      }
    }, 100);
  }, 1400);
}
