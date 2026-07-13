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
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-palais-presidentiel.jpg',
      zones: [
        { xPct: [0, 22],  nom: 'Palais Présidentiel',   buildingId: 'palais-presidentiel' },
        { xPct: [22, 48], nom: 'Palais Gouvernemental', buildingId: 'palais-gouvernement' },
        { xPct: [48, 74], nom: 'Assemblée Nationale',   buildingId: 'assemblee' },
        { xPct: [74, 100],nom: 'Tribunal',               buildingId: 'tribunal' }
      ],
      liens: { gauche: 'luthecia-tabernacle-impots', droite: 'luthecia-hotel-de-ville', toutDroit: null, arriere: null }
    },

    'luthecia-hotel-de-ville': {
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-hotel-de-ville.jpg',
      zones: [
        { xPct: [0, 25],  nom: 'Hôtel de Ville',          buildingId: 'mairie-capitale' },
        { xPct: [25, 50], nom: 'Office Notarial',          buildingId: 'office-notarial' },
        { xPct: [50, 75], nom: 'Hôtel-Restaurant La Républia', buildingId: 'hotel-republica' },
        { xPct: [75, 100],nom: 'Banque Nationale de République', buildingId: 'banque-nationale' }
      ],
      liens: { gauche: 'luthecia-palais-presidentiel', droite: 'luthecia-loge', toutDroit: null, arriere: null }
    },

    'luthecia-loge': {
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-loge.jpg',
      zones: [
        { xPct: [0, 25],  nom: 'Banque Privée Helvétia',  buildingId: 'banque-privee' },
        { xPct: [25, 50], nom: 'Clinique Privée Saint-Luc', buildingId: 'clinique-privee' },
        { xPct: [50, 75], nom: 'Loge Maçonnique',          buildingId: 'loge-maconnique' },
        { xPct: [75, 100],nom: 'Commissariat de Luthécia', buildingId: 'commissariat' }
      ],
      liens: { gauche: 'luthecia-hotel-de-ville', droite: 'luthecia-imprimerie', toutDroit: null, arriere: null }
    },

    'luthecia-imprimerie': {
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-imprimerie.jpg',
      zones: [
        { xPct: [0, 33],   nom: 'Université de Luthécia', buildingId: 'universite' },
        { xPct: [33, 66],  nom: 'Dispensaire Public',       buildingId: 'dispensaire-public' },
        { xPct: [66, 100], nom: 'Imprimerie — L\'Autruche Entravée', buildingId: 'la-tribune' }
      ],
      liens: { gauche: 'luthecia-loge', droite: null, toutDroit: 'luthecia-intersection-stade-commercial', arriere: null }
    },

    // ---- INTERSECTION VERS STADE / COMMERCE ----

    'luthecia-intersection-stade-commercial': {
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-intersection-stade-commercial.jpg',
      zones: [],
      liens: { gauche: 'luthecia-centre-commercial', droite: 'luthecia-stade-multimodal', toutDroit: null, arriere: 'luthecia-imprimerie' }
    },

    // ---- BRANCHE STADE / MULTIMODAL ----

    'luthecia-stade-multimodal': {
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-stade-multimodal.jpg',
      zones: [
        { xPct: [0, 45], nom: 'Stade de Luthécia', buildingId: 'stade' }
        // Le Centre Multimodal est visible au fond mais son entree reelle se fait au noeud suivant
      ],
      liens: { gauche: null, droite: null, toutDroit: 'luthecia-centre-multimodal', arriere: 'luthecia-intersection-stade-commercial' }
    },

    'luthecia-centre-multimodal': {
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-centre-multimodal.jpg',
      zones: [
        { xPct: [0, 100], nom: 'Centre Multimodal de Luthécia', buildingId: 'centre-multinodal-luthecia' }
      ],
      liens: { gauche: null, droite: 'luthecia-imprimerie', toutDroit: null, arriere: 'luthecia-stade-multimodal' }
    },

    // ---- BRANCHE COMMERCE / ARTISANAT / TERRAINS ----

    'luthecia-centre-commercial': {
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-centre-commercial.jpg',
      zones: [
        { xPct: [0, 50],   nom: 'Centre d\'Affaires',        buildingId: 'centre-affaires' },
        { xPct: [50, 100], nom: 'Centre Commercial Luthécia', buildingId: 'centre-commercial' }
      ],
      liens: { gauche: null, droite: null, toutDroit: 'luthecia-terrains-artisanal', arriere: 'luthecia-intersection-stade-commercial' }
    },

    'luthecia-terrains-artisanal': {
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-terrains-artisanal.jpg',
      zones: [
        { xPct: [0, 12],   nom: 'Terrain à Bâtir — Lot 1 (2150 m²)', buildingId: 'terrain-a-batir-1' },
        { xPct: [12, 24],  nom: 'Terrain à Bâtir — Lot 2 (2300 m²)', buildingId: 'terrain-a-batir-4' },
        { xPct: [24, 36],  nom: 'Terrain à Bâtir — Lot 3 (2300 m²)', buildingId: 'terrain-a-batir-5' },
        { xPct: [36, 48],  nom: 'Terrain à Bâtir — Lot 4 (1850 m²)', buildingId: 'terrain-a-batir-6' },
        { xPct: [48, 60],  nom: 'Terrain à Bâtir — Lot 5 (2750 m²)', buildingId: 'terrain-a-batir-7' },
        { xPct: [60, 100], nom: 'Centre Artisanal de Luthécia',       buildingId: 'centre-artisanal' }
      ],
      liens: { gauche: 'luthecia-armurerie', droite: null, toutDroit: null, arriere: 'luthecia-centre-commercial' }
    },

    'luthecia-armurerie': {
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-armurerie.jpg',
      zones: [
        { xPct: [0, 100], nom: 'Armurerie de Luthécia', buildingId: 'armurerie' }
      ],
      liens: { gauche: null, droite: 'luthecia-terrains-artisanal', toutDroit: 'luthecia-tabernacle-impots', arriere: null }
    },

    // ---- TABERNACLE (referme la seconde boucle sur le Palais Présidentiel) ----

    'luthecia-tabernacle-impots': {
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-tabernacle-impots.jpg',
      zones: [
        { xPct: [0, 15],   nom: 'Marché de Luthécia',        buildingId: 'marche' },
        { xPct: [30, 70],  nom: 'Le Tabernacle des Impôts',   buildingId: 'tabernacle-impots' }
      ],
      liens: { gauche: 'luthecia-armurerie', droite: 'luthecia-palais-presidentiel', toutDroit: null, arriere: null }
    }
  }
};

// =====================
// ETAT + RENDU
// =====================
let rueCentraleNoeudActuel = null;

function initialiserRueCentrale(pays, noeudDepart) {
  rueCentraleNoeudActuel = noeudDepart;
  afficherNoeudRue(pays, noeudDepart);
}

function afficherNoeudRue(pays, noeudId) {
  const noeud = RUE_CENTRALE_NOEUDS[pays]?.[noeudId];
  if (!noeud) return;
  rueCentraleNoeudActuel = noeudId;

  const conteneur = document.getElementById('rue-centrale-conteneur');
  if (!conteneur) return;

  let html = '<div class="rc-scene" id="rc-scene">';
  html += '<img class="rc-image" id="rc-image" src="' + noeud.image + '">';

  // Fleches directionnelles — uniquement celles reellement disponibles a ce noeud
  const fleches = [
    { dir: 'arriere',   icon: 'ti-arrow-back-up', style: 'top:10px; left:50%; transform:translateX(-50%);' },
    { dir: 'gauche',    icon: 'ti-chevron-left',  style: 'top:50%; left:14px; transform:translateY(-50%);' },
    { dir: 'toutDroit', icon: 'ti-arrow-up',      style: 'top:50%; left:50%; transform:translate(-50%,-50%);' },
    { dir: 'droite',    icon: 'ti-chevron-right', style: 'top:50%; right:14px; transform:translateY(-50%);' }
  ];
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
  noeud.zones.forEach(z => {
    const div = document.createElement('div');
    div.className = 'rc-zone';
    div.style.left = z.xPct[0] + '%';
    div.style.width = (z.xPct[1] - z.xPct[0]) + '%';
    div.addEventListener('mousemove', (e) => afficherTooltipRue(e, z.nom));
    div.addEventListener('mouseleave', masquerTooltipRue);
    div.addEventListener('click', () => entrerDansBatimentRue(z.buildingId, z.nom));
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
  }, 1400);
}
