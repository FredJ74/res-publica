// Point d'entree par ville — sert a savoir si cette ville utilise la nouvelle navigation par scenes
const RUE_CENTRALE_DEPART = {
  republic: { capitale: 'luthecia-palais-presidentiel', ville_a: 'psm-centre-multimodal', ville_b: 'montrouge-vue-3', caserne: 'caserne-exterieur', qhs: 'qhs-exterieur' }
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
      liens: { gauche: 'luthecia-tabernacle-impots', droite: 'luthecia-imprimerie', toutDroit: null, arriere: null }
    },

    'luthecia-hotel-de-ville': {
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-hotel-de-ville.png',
      zones: [
        { xPct: [0, 25],  nom: 'Hôtel de Ville', type: 'batiment', buildingId: 'mairie-capitale' },
        { xPct: [25, 50], nom: 'Office Notarial', type: 'batiment', buildingId: 'office-notarial' },
        { xPct: [50, 75], nom: 'Hôtel-Restaurant La Républia', type: 'batiment', buildingId: 'hotel-republica' },
        { xPct: [75, 100],nom: 'Banque Nationale de République', type: 'batiment', buildingId: 'banque-nationale' }
      ],
      liens: { gauche: 'luthecia-imprimerie', droite: 'luthecia-loge', toutDroit: null, arriere: null }
    },

    'luthecia-loge': {
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-loge.png',
      zones: [
        { xPct: [0, 25],  nom: 'Banque Privée Helvétia', type: 'batiment', buildingId: 'banque-privee' },
        { xPct: [25, 50], nom: 'Clinique Privée Saint-Luc', type: 'batiment', buildingId: 'clinique-privee' },
        { xPct: [50, 75], nom: 'Loge Maçonnique', type: 'batiment', buildingId: 'loge-maconnique' },
        { xPct: [75, 100],nom: 'Commissariat de Luthécia', type: 'batiment', buildingId: 'commissariat' }
      ],
      liens: { gauche: 'luthecia-hotel-de-ville', droite: 'luthecia-entrepot-logistique', toutDroit: null, arriere: null }
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
      liens: { gauche: 'luthecia-palais-presidentiel', droite: 'luthecia-hotel-de-ville', toutDroit: 'luthecia-intersection-stade-commercial', arriere: null }
    },

    // ---- INTERSECTION VERS STADE / COMMERCE ----

    'luthecia-intersection-stade-commercial': {
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-intersection-stade-commercial.png',
      zones: [],
      liens: { gauche: 'luthecia-centre-commercial', droite: 'luthecia-stade-multimodal', toutDroit: 'luthecia-musees', arriere: 'luthecia-imprimerie' },
      flechesStyle: {
        arriere:   'bottom:10px; left:50%; transform:translateX(-50%);',
        toutDroit: 'top:10px; left:50%; transform:translateX(-50%);'
      }
    },

    // ---- MUSEES (Ville de Luthecia + National de Republia, face a face) ----
    'luthecia-musees': {
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-musees-luthecia.png',
      zones: [
        { xPct: [0, 45],   nom: 'Musée de la Ville de Luthécia', type: 'batiment', buildingId: 'musee-ville-luthecia' },
        { xPct: [28, 52],  yPct: [20, 78], nom: 'Parc Botanique National', type: 'batiment', buildingId: 'parc-botanique-national' },
        { xPct: [55, 100], nom: 'Musée National de Republia',    type: 'batiment', buildingId: 'musee-national-republia' }
      ],
      liens: { toutDroit: 'luthecia-quartier-ambassades', arriere: 'luthecia-intersection-stade-commercial' },
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
      persons: [
        { name: 'Jean Bonde', role: 'Espion', rel: 'neutral', job: 'inspecteur' }
      ],
      // droite (aeroport) reste en position par defaut (a droite, centre vertical) — deja ce qui est demande.
      liens: { gauche: 'luthecia-bureau-emploi', droite: 'luthecia-usine-pharmaceutique', toutDroit: null, arriere: 'luthecia-musees' },
      flechesStyle: {
        arriere: 'bottom:10px; left:50%; transform:translateX(-50%);'
      }
    },

    // ---- BRANCHE STADE / MULTIMODAL ----

    'luthecia-stade-multimodal': {
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-stade-multimodal.png',
      zones: [
        { xPct: [0, 45], nom: 'Stade de Luthécia', type: 'batiment', buildingId: 'stade' },
        { xPct: [55, 100], nom: 'Place du Formulaire de la Liberté', type: 'batiment', buildingId: 'place-formulaire-liberte' }
        // Le Centre Multimodal est visible au fond mais son entree reelle se fait au noeud suivant
      ],
      liens: { gauche: null, droite: null, toutDroit: 'luthecia-centre-multimodal', arriere: 'luthecia-intersection-stade-commercial' },
      flechesStyle: {
        arriere:   'bottom:10px; left:50%; transform:translateX(-50%);',
        toutDroit: 'top:10px; left:50%; transform:translateX(-50%);'
      }
    },

    'luthecia-usine-pharmaceutique': {
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/usine-pharmaceutique-luthecia.png',
      zones: [
        { xPct: [0, 100], nom: 'Usine Pharmaceutique Impériale de Républia', type: 'batiment', buildingId: 'usine-pharmaceutique-luthecia' }
      ],
      liens: { gauche: 'luthecia-quartier-ambassades', droite: 'luthecia-centre-multimodal', toutDroit: null, arriere: null }
    },

    'luthecia-entrepot-logistique': {
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/entrepot-logistique-luthecia.png',
      zones: [
        { xPct: [0, 100], nom: 'Entrepôt Logistique de Luthécia', type: 'batiment', buildingId: 'entrepot-logistique-luthecia' }
      ],
      liens: { gauche: 'luthecia-centre-multimodal', droite: 'luthecia-loge', toutDroit: null, arriere: null }
    },

    'luthecia-centre-multimodal': {
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-centre-multimodal.png',
      zones: [
        { xPct: [0, 100], nom: 'Centre Multimodal de Luthécia', type: 'batiment', buildingId: 'centre-multinodal-luthecia' }
      ],
      liens: { gauche: 'luthecia-usine-pharmaceutique', droite: 'luthecia-entrepot-logistique', toutDroit: null, arriere: 'luthecia-stade-multimodal' },
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

    'luthecia-bureau-emploi': {
      // Fix regression du 9 aout 2026 : ce noeud et la salle d'accueil du batiment (data.js)
      // partageaient le meme fichier image depuis la creation du batiment. Ca ne posait pas
      // de probleme tant que ce fichier contenait une photo de rue (facade + trottoir) qui
      // convenait a peu pres aux deux usages, mais le remplacement de l'image d'accueil par
      // une vraie photo d'interieur (hall de reception) a silencieusement ecrase la photo de
      // rue ici aussi. Ancienne photo de facade recuperee depuis l'historique git (commit
      // ff7dd49^) et remise sur un fichier dedie, separe de l'accueil.
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-bureau-national-emploi-luthecia.png',
      zones: [
        { xPct: [0, 100], nom: "Bureau National de l'Emploi", type: 'batiment', buildingId: 'bureau-national-emploi' }
      ],
      liens: { gauche: null, droite: null, toutDroit: 'luthecia-quartier-ambassades', arriere: 'luthecia-terrains-artisanal' },
      // Positions par defaut inadaptees a cette photo (toutDroit tombait sur la facade/enseigne
      // du batiment ; arriere, par defaut en haut aussi, se confondait visuellement avec
      // toutDroit). Repositionnees explicitement en haut/bas, toutes deux centrees, pour rester
      // lisibles : fleche du haut (toutDroit, icone vers le haut) -> Quartier des Ambassades,
      // fleche du bas (arriere, icone vers le bas) -> Centre Artisanal (via terrains-artisanal).
      flechesStyle: {
        toutDroit: 'top:14px; left:50%; transform:translateX(-50%);',
        arriere:   'bottom:14px; left:50%; transform:translateX(-50%);'
      }
    },

    'luthecia-terrains-artisanal': {
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-terrains-artisanal.png',
      zones: [
        // Debut de zone decale de 0 a 8% pour laisser un espace libre a la fleche gauche
        { xPct: [8, 60],   nom: 'Terrains à Bâtir',            type: 'noeud', noeudId: 'luthecia-terrains-lots' },
        { xPct: [60, 100], nom: 'Centre Artisanal de Luthécia', type: 'batiment', buildingId: 'centre-artisanal' }
      ],
      liens: { gauche: 'luthecia-armurerie', droite: 'luthecia-bureau-emploi', toutDroit: null, arriere: 'luthecia-centre-commercial' },
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
    },

    // ==================================================
    // DONNEES — Port-Sainte-Marie (PSM)
    // ==================================================

    'psm-carrefour-musee': {
      // Carrefour central de PSM : Musee, Centre Commercial, Centre d'Affaires.
      // 4 images differentes selon la direction d'arrivee (imagesParArrivee), avec zones
      // cliquables et fleches qui varient egalement selon l'arrivee (zonesParArrivee,
      // liensParArrivee). Les IDs 'psm-carrefour-artisanal-scierie', 'psm-ecole-phare', 'psm-tribunal-banque',
      // 'psm-eglise-cimetiere' sont des PLACEHOLDERS : a relier aux vrais noeuds une fois ces
      // scenes codees (voir JOURNAL-SESSION.md, scenes du 27 juillet).
      // xPct estimes a l'oeil sur chaque image : a ajuster si le clic tombe a cote.
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-carrefour-musee-depuis-artisanal.png',
      imagesParArrivee: {
        'psm-carrefour-artisanal-scierie': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-carrefour-musee-depuis-artisanal.png',
        'psm-ecole-phare':            'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-carrefour-musee-depuis-phare.png',
        'psm-eglise-cimetiere': 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-carrefour-musee-depuis-phare.png',
        'psm-tribunal-banque':         'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-carrefour-musee-depuis-tribunal.png',
        'psm-eglise-cimetiere':           'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-carrefour-musee-depuis-eglise.png'
      },
      zones: [
        { xPct: [0, 22],   nom: 'Musée de Port Sainte Marie', type: 'batiment', buildingId: 'musee-port-sainte-marie' },
        { xPct: [38, 60],  nom: 'Centre Commercial',          type: 'batiment', buildingId: 'centre-commercial' },
        { xPct: [78, 100], nom: 'Centre d\'Affaires',         type: 'batiment', buildingId: 'centre-affaires' }
      ],
      zonesParArrivee: {
        'psm-carrefour-artisanal-scierie': [
          { xPct: [0, 22],   nom: 'Musée de Port Sainte Marie', type: 'batiment', buildingId: 'musee-port-sainte-marie' },
          { xPct: [38, 60],  nom: 'Centre Commercial',          type: 'batiment', buildingId: 'centre-commercial' },
          { xPct: [78, 100], nom: 'Centre d\'Affaires',         type: 'batiment', buildingId: 'centre-affaires' }
        ],
        'psm-ecole-phare': [
          { xPct: [0, 35],   nom: 'Centre d\'Affaires',         type: 'batiment', buildingId: 'centre-affaires' },
          { xPct: [42, 58],  nom: 'Musée de Port Sainte Marie', type: 'batiment', buildingId: 'musee-port-sainte-marie' },
          { xPct: [65, 100], nom: 'Centre Commercial',          type: 'batiment', buildingId: 'centre-commercial' }
        ],
        'psm-eglise-cimetiere': [
          { xPct: [0, 35],   nom: 'Centre d\'Affaires',         type: 'batiment', buildingId: 'centre-affaires' },
          { xPct: [42, 58],  nom: 'Musée de Port Sainte Marie', type: 'batiment', buildingId: 'musee-port-sainte-marie' },
          { xPct: [65, 100], nom: 'Centre Commercial',          type: 'batiment', buildingId: 'centre-commercial' }
        ],
        'psm-tribunal-banque': [
          { xPct: [0, 30], yPct: [22, 75],  nom: 'Centre Commercial',          type: 'batiment', buildingId: 'centre-commercial' },
          { xPct: [40, 55], yPct: [22, 55], nom: 'Centre d\'Affaires', type: 'batiment', buildingId: 'centre-affaires' },
          { xPct: [68, 100], yPct: [22, 75], nom: 'Musée de Port Sainte Marie', type: 'batiment', buildingId: 'musee-port-sainte-marie' }
        ],
        'psm-eglise-cimetiere': [
          { xPct: [0, 32],   nom: 'Centre d\'Affaires',         type: 'batiment', buildingId: 'centre-affaires' },
          { xPct: [50, 65],  nom: 'Musée de Port Sainte Marie', type: 'batiment', buildingId: 'musee-port-sainte-marie' },
          { xPct: [70, 100], nom: 'Centre Commercial',          type: 'batiment', buildingId: 'centre-commercial' }
        ]
      },
      liens: { gauche: 'psm-ecole-phare', droite: 'psm-eglise-cimetiere', toutDroit: 'psm-tribunal-banque', arriere: 'psm-carrefour-artisanal-scierie' },
      liensParArrivee: {
        'psm-carrefour-artisanal-scierie': { gauche: 'psm-ecole-phare',            droite: 'psm-eglise-cimetiere',           toutDroit: 'psm-tribunal-banque',         arriere: 'psm-carrefour-artisanal-scierie' },
        'psm-ecole-phare':            { gauche: 'psm-tribunal-banque',         droite: 'psm-carrefour-artisanal-scierie', toutDroit: 'psm-eglise-cimetiere',           arriere: 'psm-ecole-phare' },
        'psm-tribunal-banque':         { gauche: 'psm-eglise-cimetiere',           droite: 'psm-ecole-phare',            toutDroit: 'psm-carrefour-artisanal-scierie', arriere: 'psm-tribunal-banque' },
        'psm-eglise-cimetiere':           { gauche: 'psm-carrefour-artisanal-scierie', droite: 'psm-tribunal-banque',         toutDroit: 'psm-ecole-phare',            arriere: 'psm-eglise-cimetiere' }
      },
      flechesStyle: { arriere: 'bottom:10px; left:50%; transform:translateX(-50%);', toutDroit: 'top:10px; left:50%; transform:translateX(-50%);' }
    },

    'psm-carrefour-artisanal-scierie': {
      // Carrefour Centre Artisanal / Scierie. Une seule photo (la vue ne change pas selon la
      // provenance). DEUX entrees reelles depuis le 9 aout 2026 : depuis le carrefour Musee
      // (au sud, via son lien toutDroit quand on arrive du Tribunal) ET depuis
      // psm-pole-tabac-entrepot (a l'ouest, via son lien toutDroit). "arriere" est fixe sur
      // l'ouest (pas de liensParArrivee ici : ce mecanisme lit rueCentraleDepuisNoeud, qui est
      // remis a null par showVueRue()/initialiserRueCentrale() a CHAQUE sortie de batiment —
      // or ce carrefour a deux batiments cliquables, donc quasiment aucun joueur ne conserve
      // sa provenance jusqu'au clic sur la fleche. liensParArrivee essaye ici le 9 aout 2026,
      // ne se declenchait quasiment jamais en jeu reel, retire). "droite" reste la route vers
      // le sud (carrefour Musee) pour qui arrive par le sud et veut y retourner.
      // 'psm-centre-multimodal' n'est plus un placeholder, deja code.
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-carrefour-artisanal-scierie.png',
      zones: [
        { xPct: [0, 26],   nom: 'Centre Artisanal',       type: 'batiment', buildingId: 'centre-artisanal' },
        { xPct: [74, 100], nom: 'Scierie Guy Tarembois',  type: 'batiment', buildingId: 'zone-production' }
      ],
      liens: { toutDroit: 'psm-centre-multimodal', droite: 'psm-carrefour-musee', arriere: 'psm-pole-tabac-entrepot' },
      flechesStyle: { arriere: 'bottom:10px; left:50%; transform:translateX(-50%);', toutDroit: 'top:10px; left:50%; transform:translateX(-50%);' }
    },

    'psm-centre-multimodal': {
      // Point de depart officiel de la navigation exterieure de PSM (arrivee par transport).
      // Pas de fleche arriere (entree de ville). 'psm-ecole-phare' est un PLACEHOLDER
      // (scene Ecole/Phare, image deja recue de Fred mais pas encore codee).
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-centre-multimodal-psm.png',
      zones: [
        { xPct: [0, 20],   nom: 'Stade de la Brise Mariannaise', type: 'batiment', buildingId: 'stade' },
        { xPct: [20, 78],  nom: 'Centre Multimodal',             type: 'batiment', buildingId: 'centre-multinodal-port-sainte-marie' },
        { xPct: [80, 100], nom: 'Port Industriel',               type: 'batiment', buildingId: 'port-sainte-marie' }
      ],
      liens: { gauche: 'psm-carrefour-artisanal-scierie', droite: 'psm-ecole-phare' }
    },

    'psm-ecole-phare': {
      // Le Dispensaire est visible au loin mais pas encore cliquable ici (le sera sur la scene suivante).
      // 'psm-dispensaire-port-plaisance' est un PLACEHOLDER (scene pas encore codee).
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-ecole-phare-psm.png',
      zones: [
        { xPct: [22, 62], nom: 'École de Marine', type: 'batiment', buildingId: 'ecole-marine' },
        // Zone recalibree sur la silhouette reelle du phare (mesuree sur l'image, verifiee
        // identique en production) -- l'ancienne zone [65,82] etait etroite et decalee a gauche
        // de la tour reelle (qui commence vers 85%). Couvre desormais confortablement tour +
        // lanterne + base/jetee, sans chevaucher l'Ecole de Marine (fin a 62%) ni la fleche
        // toutDroit (repositionnee en haut, voir flechesStyle ci-dessous).
        { xPct: [79, 97], yPct: [16, 64], nom: 'Phare', type: 'batiment', buildingId: 'phare-psm' }
      ],
      liens: { gauche: 'psm-carrefour-musee', toutDroit: 'psm-centre-multimodal', arriere: 'psm-dispensaire-port-plaisance' },
      // toutDroit repositionnee en haut du ciel (meme pattern que la majorite des autres scenes,
      // ex. psm-carrefour-artisanal-scierie ci-dessus) : la position par defaut (top:50%,
      // left:80%) tombait en plein sur la zone du phare et genait le clic.
      flechesStyle: { arriere: 'bottom:10px; left:50%; transform:translateX(-50%);', toutDroit: 'top:10px; left:50%; transform:translateX(-50%);' }
    },

    'psm-dispensaire-port-plaisance': {
      // 'psm-tribunal-banque' est un PLACEHOLDER (scene pas encore codee).
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-dispensaire-port-plaisance-psm.png',
      zones: [
        { xPct: [0, 30],   nom: 'Dispensaire des Marins Mariannais', type: 'batiment', buildingId: 'dispensaire-public-v' },
        { xPct: [65, 100], nom: 'Port de Plaisance',                 type: 'batiment', buildingId: 'port-plaisance-psm' }
      ],
      liens: { toutDroit: 'psm-ecole-phare', gauche: 'psm-tribunal-banque' }
    },

    'psm-tribunal-banque': {
      // 'psm-bar-imprimerie-commissariat' est un PLACEHOLDER (scene pas encore codee).
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-tribunal-banque-psm.png',
      zones: [
        { xPct: [15, 55],  nom: 'Tribunal de Port Sainte Marie', type: 'batiment', buildingId: 'tribunal-local' },
        { xPct: [58, 85],  nom: 'Banque Mariannaise',            type: 'batiment', buildingId: 'banque-locale' }
      ],
      liens: { droite: 'psm-dispensaire-port-plaisance', gauche: 'psm-bar-imprimerie-commissariat', toutDroit: 'psm-carrefour-musee' },
      flechesStyle: { toutDroit: 'top:10px; left:50%; transform:translateX(-50%);' }
    },

    'psm-bar-imprimerie-commissariat': {
      // 'psm-marche-resto-chasse' est un PLACEHOLDER (scene Capitaine Sauvage/Marche/Chasse&Peche, pas encore codee).
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-bar-imprimerie-commissariat-psm.png',
      zones: [
        { xPct: [0, 32],   nom: 'Le Bar des Pêcheurs',       type: 'batiment', buildingId: 'bar-des-pecheurs' },
        { xPct: [35, 65],  nom: "L'Encre Mariannaise",       type: 'batiment', buildingId: 'imprimerie-librairie' },
        { xPct: [68, 100], nom: 'Commissariat de Police',    type: 'batiment', buildingId: 'commissariat-local' }
      ],
      liens: { droite: 'psm-tribunal-banque', gauche: 'psm-marche-resto-chasse' }
    },

    'psm-marche-resto-chasse': {
      // 'psm-hotel-mairie-place' et 'psm-eglise-cimetiere' sont des PLACEHOLDERS (scenes pas encore codees).
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-marche-resto-chasse-psm.png',
      zones: [
        { xPct: [0, 30],   nom: 'Capitaine Sauvage',        type: 'batiment', buildingId: 'capitaine-sauvage' },
        { xPct: [33, 62],  nom: 'Marché',                   type: 'batiment', buildingId: 'marche-psm' },
        { xPct: [65, 100], nom: 'Chasse & Pêche',           type: 'batiment', buildingId: 'chasse-peche-psm' }
      ],
      liens: { droite: 'psm-bar-imprimerie-commissariat', gauche: 'psm-hotel-mairie-place' }
    },

    'psm-hotel-mairie-place': {
      // 'psm-eglise-cimetiere' est reutilise (deja pose en placeholder depuis la scene Marche/Resto/Chasse,
      // ou la zone 'Marche' menait vers ce meme noeud).
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-hotel-mairie-place-psm.png',
      zones: [
        { xPct: [0, 30],   nom: "Place d'Armes",     type: 'batiment', buildingId: 'place-armes-psm' },
        { xPct: [33, 62],  nom: "Mairie",            type: 'batiment', buildingId: 'mairie' },
        { xPct: [65, 100], nom: 'Hôtel du Port',     type: 'batiment', buildingId: 'hotel-port' }
      ],
      liens: { droite: 'psm-marche-resto-chasse', gauche: 'psm-eglise-cimetiere' }
    },

    'psm-eglise-cimetiere': {
      // 'psm-chantier-naval' est un PLACEHOLDER (scene pas encore codee).
      // Le retour en arriere reutilise volontairement la vue "depuis le Phare" du carrefour Musee
      // (l'eglise y est visible au loin), voir duplication dans imagesParArrivee/zonesParArrivee/liensParArrivee ci-dessous.
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-eglise-cimetiere-psm.png',
      zones: [
        { xPct: [15, 85], nom: 'Notre-Dame de la Mer & Cimetière Marin', type: 'batiment', buildingId: 'notre-dame-mer' }
      ],
      liens: { droite: 'psm-chantier-naval', gauche: 'psm-hotel-mairie-place', arriere: 'psm-carrefour-musee' },
      flechesStyle: { arriere: 'bottom:10px; left:50%; transform:translateX(-50%);' }
    },

    'psm-chantier-naval': {
      // 'psm-terrains-vente' est un PLACEHOLDER (scene pas encore codee).
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-chantier-naval-psm.png',
      zones: [
        { xPct: [15, 85], nom: 'Chantier Naval', type: 'batiment', buildingId: 'chantier-naval' }
      ],
      liens: { toutDroit: 'psm-terrains-vente', arriere: 'psm-eglise-cimetiere' },
      flechesStyle: { arriere: 'bottom:10px; left:50%; transform:translateX(-50%);', toutDroit: 'top:16px; right:16px;' }
    },

    'psm-terrains-vente': {
      // 'psm-terrains-lots' est un PLACEHOLDER (sous-scene des 5 lots, pas encore codee,
      // sur le modele de 'luthecia-terrains-lots').
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-terrains-vente-psm.png',
      zones: [
        { xPct: [55, 95], nom: 'Terrains à Bâtir', type: 'noeud', noeudId: 'psm-terrains-lots' }
      ],
      liens: { droite: 'psm-pole-tabac-entrepot', arriere: 'psm-chantier-naval' },
      flechesStyle: { arriere: 'bottom:10px; left:50%; transform:translateX(-50%);' }
    },

    'psm-pole-tabac-entrepot': {
      // Vue en perspective d'une route qui part vers l'horizon (Centre Multimodal/Stade visibles
      // au fond) : c'est un couloir nord-sud, pas est-ouest — gauche/droite n'avait pas de sens
      // ici (bug remonte par Fred le 9 aout 2026, teste en jeu reel). Corrige en toutDroit/arriere :
      // Pole Tabac occupe la moitie gauche du cadre, Entrepot Logistique la moitie droite (zones
      // xPct inchangees, la vue elle-meme ne bouge pas), mais la marche se fait tout droit vers le
      // carrefour Scierie/Artisanal, retour vers les Terrains a batir.
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/entrepot-pole-tabac-psm.png',
      zones: [
        { xPct: [0, 45],   nom: 'Pôle Tabac & Alcools Sainte-Mariannaise', type: 'batiment', buildingId: 'pole-tabac-alcools-psm' },
        { xPct: [55, 100], nom: 'Entrepôt Logistique de Sainte-Marie',     type: 'batiment', buildingId: 'entrepot-logistique-psm' }
      ],
      liens: { gauche: null, droite: null, toutDroit: 'psm-carrefour-artisanal-scierie', arriere: 'psm-terrains-vente' },
      flechesStyle: {
        toutDroit: 'top:10px; left:50%; transform:translateX(-50%);',
        arriere:   'bottom:10px; left:50%; transform:translateX(-50%);'
      }
    },

    'psm-terrains-lots': {
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-terrains-lots-detail-psm.png',
      zones: [
        { xPct: [10, 25], nom: 'Lot 1 (1650 m²)', type: 'batiment', buildingId: 'terrain-a-batir-2' },
        { xPct: [30, 45], nom: 'Lot 2 (2200 m²)', type: 'batiment', buildingId: 'terrain-a-batir-8' },
        { xPct: [58, 68], nom: 'Lot 3 (3100 m²)', type: 'batiment', buildingId: 'terrain-a-batir-9' },
        { xPct: [48, 58], nom: 'Lot 4 (4200 m²)', type: 'batiment', buildingId: 'terrain-a-batir-10' },
        { xPct: [78, 92], nom: 'Lot 5 (5500 m²)', type: 'batiment', buildingId: 'terrain-a-batir-11' }
      ],
      liens: { arriere: 'psm-terrains-vente' }
    },

    // ---- CASERNE / QHS — scenes a noeud unique, un seul batiment chacune, accessibles
    // uniquement par taxi depuis le Centre Multinodal (pas de rue a parcourir, donc aucune
    // fleche directionnelle). Un seul batiment par image : toute l'image est cliquable
    // (xPct/yPct [0,100]), pas besoin de decouper une zone precise.
    'caserne-exterieur': {
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/caserne-luthecia-exterieur.png',
      zones: [
        { xPct: [0, 100], yPct: [0, 100], nom: 'Caserne Militaire', type: 'batiment', buildingId: 'caserne-militaire' }
      ],
      liens: {}
    },

    'qhs-exterieur': {
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/qhs-luthecia-exterieur.png',
      zones: [
        { xPct: [0, 100], yPct: [0, 100], nom: 'Quartier Haute Sécurité', type: 'batiment', buildingId: 'qhs-prison' }
      ],
      liens: {}
    },

    // ---- MONTROUGE — 13 vues fixes, connexions figees par Fred (voir prompt du 2026-08-16) ----
    // IMPORTANT : les directions (gauche/droite/toutDroit/arriere) sont celles VALIDEES,
    // pas une deduction geographique. Ne pas "corriger" en fonction de l'angle de camera.

    'montrouge-vue-1': {
      image: 'images/montrouge/montrouge-rue-hotel-armurerie-stade.jpg',
      zones: [
        { xPct: [0, 40],  nom: 'Hôtel de la Victoire', type: 'batiment', buildingId: 'hotel-mineur' },
        { xPct: [40, 58], nom: 'Armurerie-Quincaillerie de Montrouge', type: 'batiment', buildingId: 'armurerie' }
      ],
      liens: { gauche: 'montrouge-vue-5', toutDroit: 'montrouge-vue-6' },
      flechesStyle: { toutDroit: 'top:10px; left:50%; transform:translateX(-50%);' }
    },

    'montrouge-vue-2': {
      image: 'images/montrouge/montrouge-rue-commissariat-stade-raffinerie.jpg',
      zones: [
        { xPct: [0, 28],   nom: 'Commissariat de Montrouge', type: 'batiment', buildingId: 'commissariat-local' },
        { xPct: [82, 100], nom: 'Raffinerie de Montrouge', type: 'batiment', buildingId: 'raffinerie-montrouge' }
      ],
      liens: { toutDroit: 'montrouge-vue-5', arriere: 'montrouge-vue-3' },
      flechesStyle: {
        toutDroit: 'top:10px; left:50%; transform:translateX(-50%);',
        arriere:   'bottom:10px; left:50%; transform:translateX(-50%);'
      }
    },

    // Vue 3 — Place de la Gare : point d'arrivee / reference principale de Montrouge.
    'montrouge-vue-3': {
      image: 'images/montrouge/montrouge-place-gare.jpg',
      zones: [
        { xPct: [0, 14],   nom: 'Café de la Gare', type: 'batiment', buildingId: 'cafe-gare-montrouge' },
        { xPct: [27, 73],  nom: 'Gare de Montrouge', type: 'batiment', buildingId: 'centre-multinodal-montrouge' },
        { xPct: [84, 100], nom: 'Brasserie des Voyageurs', type: 'batiment', buildingId: 'brasserie-voyageurs-montrouge' }
      ],
      liens: { gauche: 'montrouge-vue-2', droite: 'montrouge-vue-4', arriere: 'montrouge-vue-13' },
      flechesStyle: { arriere: 'bottom:10px; left:50%; transform:translateX(-50%);' }
    },

    'montrouge-vue-4': {
      image: 'images/montrouge/montrouge-rue-entrepot-hopital.jpg',
      zones: [
        { xPct: [0, 35],   nom: 'Entrepôt logistique de Montrouge', type: 'batiment', buildingId: 'entrepot-logistique-montrouge' },
        { xPct: [68, 100], nom: 'Hôpital de Montrouge', type: 'batiment', buildingId: 'dispensaire-public-v' }
      ],
      liens: { toutDroit: 'montrouge-vue-12', arriere: 'montrouge-vue-3' },
      flechesStyle: {
        toutDroit: 'top:10px; left:50%; transform:translateX(-50%);',
        arriere:   'bottom:10px; left:50%; transform:translateX(-50%);'
      }
    },

    'montrouge-vue-5': {
      image: 'images/montrouge/montrouge-stade-marcel-cazenave-aerien.jpg',
      zones: [
        { xPct: [0, 100], yPct: [0, 100], nom: 'Stade Marcel Cazenave', type: 'batiment', buildingId: 'stade' }
      ],
      liens: { gauche: 'montrouge-vue-1', arriere: 'montrouge-vue-2' },
      flechesStyle: { arriere: 'bottom:10px; left:50%; transform:translateX(-50%);' }
    },

    'montrouge-vue-6': {
      image: 'images/montrouge/montrouge-rue-centre-commercial-affaires.jpg',
      zones: [
        { xPct: [0, 30],   nom: 'Centre commercial de Montrouge', type: 'batiment', buildingId: 'centre-commercial' },
        { xPct: [68, 100], nom: 'Centre d\'affaires de Montrouge', type: 'batiment', buildingId: 'centre-affaires' }
      ],
      liens: { gauche: 'montrouge-vue-1', toutDroit: 'montrouge-vue-7' },
      flechesStyle: { toutDroit: 'top:10px; left:50%; transform:translateX(-50%);' }
    },

    // Vue 7 — la place avec la locomotive au centre s'appelle "Place du Rail" ; c'est
    // desormais aussi un lieu cliquable (place-du-rail-montrouge), distinct de la facade
    // de la mairie (0-27%), sur le reste de l'image (locomotive + place + batiments en
    // arriere-plan, 28-100%).
    'montrouge-vue-7': {
      image: 'images/montrouge/montrouge-place-hotel-de-ville.jpg',
      zones: [
        { xPct: [0, 27], nom: 'Hôtel de Ville de Montrouge', type: 'batiment', buildingId: 'mairie' },
        { xPct: [28, 100], nom: 'Place du Rail', type: 'batiment', buildingId: 'place-du-rail-montrouge' }
      ],
      liens: { arriere: 'montrouge-vue-6', toutDroit: 'montrouge-vue-8' },
      flechesStyle: {
        arriere:   'bottom:10px; left:50%; transform:translateX(-50%);',
        toutDroit: 'top:10px; left:50%; transform:translateX(-50%);'
      }
    },

    'montrouge-vue-8': {
      image: 'images/montrouge/montrouge-rue-musee-banque-cheminote.jpg',
      zones: [
        { xPct: [0, 32],   nom: 'Musée de l\'Histoire de Montrouge — Autour du Rail', type: 'batiment', buildingId: 'musee-histoire-montrouge' },
        { xPct: [65, 100], nom: 'Banque Cheminote de Montrouge', type: 'batiment', buildingId: 'banque-locale' }
      ],
      liens: { arriere: 'montrouge-vue-7', toutDroit: 'montrouge-vue-9' },
      flechesStyle: {
        arriere:   'bottom:10px; left:50%; transform:translateX(-50%);',
        toutDroit: 'top:10px; left:50%; transform:translateX(-50%);'
      }
    },

    'montrouge-vue-9': {
      image: 'images/montrouge/montrouge-rue-loge-eglise.jpg',
      zones: [
        { xPct: [0, 22],   nom: 'Loge maçonnique de Montrouge', type: 'batiment', buildingId: 'loge-maconnique' },
        { xPct: [55, 100], nom: 'Église', type: 'batiment', buildingId: 'eglise-montrouge' }
      ],
      liens: { arriere: 'montrouge-vue-8', toutDroit: 'montrouge-vue-10' },
      flechesStyle: {
        arriere:   'bottom:10px; left:50%; transform:translateX(-50%);',
        toutDroit: 'top:10px; left:50%; transform:translateX(-50%);'
      }
    },

    'montrouge-vue-10': {
      image: 'images/montrouge/montrouge-rue-cinema-journal-lci.jpg',
      zones: [
        { xPct: [0, 27],   nom: 'Cinéma de Montrouge', type: 'batiment', buildingId: 'cinema-montrouge' },
        { xPct: [68, 100], nom: 'Le Cheminot Informé (LCI)', type: 'batiment', buildingId: 'la-tribune' }
      ],
      liens: { gauche: 'montrouge-vue-9', toutDroit: 'montrouge-vue-11' },
      flechesStyle: { toutDroit: 'top:10px; left:50%; transform:translateX(-50%);' }
    },

    'montrouge-vue-11': {
      image: 'images/montrouge/montrouge-rue-centre-artisanal-terrains.jpg',
      zones: [
        { xPct: [0, 22],   nom: 'Centre artisanal de Montrouge', type: 'batiment', buildingId: 'centre-artisanal' },
        { xPct: [78, 100], nom: 'Terrains à bâtir de Montrouge', type: 'sous-lieu' }
      ],
      liens: { arriere: 'montrouge-vue-10', gauche: 'montrouge-vue-12' },
      flechesStyle: { arriere: 'bottom:10px; left:50%; transform:translateX(-50%);' }
    },

    // Vue 12 — fichier mal nomme (montrouge-rue-jardins-ouvriers-entrepot.jpg) : le contenu
    // fonctionnel reel est Jardins ouvriers + Logements. Pas d'acces entrepot depuis cette vue
    // (confirme par Fred), meme si l'image affiche une facade "Entrepot Logistique".
    'montrouge-vue-12': {
      image: 'images/montrouge/montrouge-rue-jardins-ouvriers-entrepot.jpg',
      zones: [
        { xPct: [0, 25],   nom: 'Jardins ouvriers', type: 'batiment', buildingId: 'jardins-ouvriers-montrouge' },
        { xPct: [68, 100], nom: 'Logements', type: 'batiment', buildingId: 'logements-montrouge' }
      ],
      liens: { toutDroit: 'montrouge-vue-11', arriere: 'montrouge-vue-4' },
      flechesStyle: {
        toutDroit: 'top:10px; left:50%; transform:translateX(-50%);',
        arriere:   'bottom:10px; left:50%; transform:translateX(-50%);'
      }
    },

    // Vue 13 — Café des Cheminots et le Bar-Tabac sont un seul et meme etablissement (une zone).
    'montrouge-vue-13': {
      image: 'images/montrouge/montrouge-place-marche-tabac-cafe.jpg',
      zones: [
        { xPct: [0, 32],   nom: 'Marché de Montrouge', type: 'batiment', buildingId: 'marche' },
        { xPct: [75, 100], nom: 'Café des Cheminots — Bar-Tabac', type: 'batiment', buildingId: 'cafe-tabac-cheminots-montrouge' }
      ],
      liens: { toutDroit: 'montrouge-vue-3' },
      flechesStyle: { toutDroit: 'top:10px; left:50%; transform:translateX(-50%);' }
    }
  }
};

// =====================
// ETAT + RENDU
// =====================
let rueCentraleNoeudActuel = null;
let rueCentraleDepuisNoeud = null; // memorise le noeud d'origine, pour liensParArrivee et zonesParArrivee

// Memorise le dernier noeud de rue visite, par pays+ville, pour que showVueRue()
// (dans plateau-navigation.js) puisse y revenir en sortant d'un batiment au lieu
// de toujours repartir du noeud de depart (RUE_CENTRALE_DEPART). C'etait la cause
// du bug "je me retrouve toujours devant le Palais Presidentiel en sortant".
let rueCentraleDerniersNoeuds = {};

// Retourne { noeudId, depuisNoeudId }. depuisNoeudId est necessaire pour que
// imagesParArrivee/zonesParArrivee/liensParArrivee continuent de fonctionner apres une
// visite de batiment (bug remonte le 9 aout 2026 : seul noeudId etait memorise avant, donc
// showVueRue() perdait systematiquement la provenance en sortant d'un batiment, ce qui
// reinitialisait silencieusement la scene sur son cas par defaut a chaque fois — visible
// sur tout noeud multi-entrees ayant au moins un batiment cliquable, ex: psm-carrefour-musee).
function obtenirNoeudRueCentraleMemorise(pays, ville, noeudDepartParDefaut) {
  // Priorite 1 : memoire de la session en cours (evite une lecture localStorage inutile)
  if (rueCentraleDerniersNoeuds[pays + '|' + ville]) return rueCentraleDerniersNoeuds[pays + '|' + ville];
  // Priorite 2 : localStorage — survit a un vrai rafraichissement de page (qui reinitialise
  // toutes les variables JS, y compris rueCentraleDerniersNoeuds ci-dessus).
  try {
    const cle = 'respublica_ruecentrale_' + (typeof state !== 'undefined' && state.char?.name || 'default');
    const saved = JSON.parse(localStorage.getItem(cle) || 'null');
    // saved.depuisNoeudId absent (anciennes sauvegardes, avant le 9 aout 2026) -> null,
    // comportement identique a avant (cas par defaut du noeud), pas de migration necessaire.
    if (saved && saved.pays === pays && saved.ville === ville && saved.noeudId) {
      return { noeudId: saved.noeudId, depuisNoeudId: saved.depuisNoeudId || null };
    }
  } catch (e) {}
  return { noeudId: noeudDepartParDefaut, depuisNoeudId: null };
}

function memoriserNoeudRueCentrale(pays, ville, noeudId, depuisNoeudId) {
  rueCentraleDerniersNoeuds[pays + '|' + ville] = { noeudId, depuisNoeudId: depuisNoeudId || null };
  try {
    const cle = 'respublica_ruecentrale_' + (typeof state !== 'undefined' && state.char?.name || 'default');
    localStorage.setItem(cle, JSON.stringify({ pays, ville, noeudId, depuisNoeudId: depuisNoeudId || null }));
  } catch (e) {}
}

// Retrouve le noeud de rue centrale dont une zone pointe vers ce batiment (ex: le Centre
// Multimodal d'une ville) — utilise a l'arrivee d'un voyage pour repositionner le souvenir
// de rue centrale (memoriserNoeudRueCentrale) sur le bon endroit, plutot que de laisser le
// joueur retomber sur la derniere scene visitee dans cette ville, parfois perimee de
// plusieurs jours (bug remonte le 8 aout 2026). Derive des donnees existantes (zones des
// noeuds) plutot qu'une table separee "ville -> noeud d'arrivee" a maintenir en double.
function trouverNoeudRueCentralePourBatiment(pays, buildingId) {
  const noeuds = typeof RUE_CENTRALE_NOEUDS !== 'undefined' ? RUE_CENTRALE_NOEUDS[pays] : null;
  if (!noeuds || !buildingId) return null;
  for (const [noeudId, noeud] of Object.entries(noeuds)) {
    const zonesAVerifier = [
      ...(noeud.zones || []),
      ...Object.values(noeud.zonesParArrivee || {}).flat()
    ];
    if (zonesAVerifier.some(z => z.buildingId === buildingId)) return noeudId;
  }
  return null;
}

function initialiserRueCentrale(pays, noeudDepart, depuisNoeud) {
  rueCentraleNoeudActuel = noeudDepart;
  afficherNoeudRue(pays, noeudDepart, depuisNoeud);
}

function afficherNoeudRue(pays, noeudId, depuisNoeudId) {
  const noeud = RUE_CENTRALE_NOEUDS[pays]?.[noeudId];
  if (!noeud) return;
  rueCentraleNoeudActuel = noeudId;
  rueCentraleDepuisNoeud = depuisNoeudId || null;
  if (typeof state !== 'undefined' && state.currentCity) {
    memoriserNoeudRueCentrale(pays, state.currentCity, noeudId, rueCentraleDepuisNoeud);
  }

  if (typeof queteAccueilDoitDemarrer === 'function' && queteAccueilDoitDemarrer(pays, noeudId)) {
    demarrerQueteAccueil();
  }
  if (typeof queteAccueilVerifierGuidage === 'function') {
    queteAccueilVerifierGuidage(pays, noeudId);
  }

  const conteneur = document.getElementById('rue-centrale-conteneur');
  if (!conteneur) return;

  const imageAffichee = (noeud.imagesParArrivee && rueCentraleDepuisNoeud && noeud.imagesParArrivee[rueCentraleDepuisNoeud]) || noeud.image;
  const zonesAffichees = (noeud.zonesParArrivee && rueCentraleDepuisNoeud && noeud.zonesParArrivee[rueCentraleDepuisNoeud]) || noeud.zones;
  const liensActuels = (noeud.liensParArrivee && rueCentraleDepuisNoeud && noeud.liensParArrivee[rueCentraleDepuisNoeud]) || noeud.liens;

  let html = '<div class="rc-scene" id="rc-scene">';
  html += '<img class="rc-image" id="rc-image" src="' + imageAffichee + '">';

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
    { dir: 'arriere',   icon: 'ti-arrow-down' },
    { dir: 'gauche',    icon: 'ti-chevron-left'  },
    { dir: 'toutDroit', icon: 'ti-arrow-up'      },
    { dir: 'droite',    icon: 'ti-chevron-right' }
  ].map(f => ({ ...f, style: noeud.flechesStyle?.[f.dir] || stylesParDefaut[f.dir] }));
  fleches.forEach(f => {
    if (liensActuels[f.dir]) {
      html += '<div class="rc-fleche" style="' + f.style + '" onclick="deplacerRueCentrale(\'' + pays + '\',\'' + f.dir + '\')">' +
        '<i class="ti ' + f.icon + '"></i></div>';
    }
  });

  html += '<div class="rc-overlay" id="rc-overlay"><div class="rc-texte" id="rc-texte"></div></div>';
  html += '</div>';
  conteneur.innerHTML = html;

  // Personnes presentes dans cette scene de rue (meme systeme que dans les batiments,
  // mais cible le conteneur dedie a la rue et utilise un buildingId synthetique 'rue-centrale')
  if (typeof renderPersonsList === 'function') {
    renderPersonsList(noeud.persons || [], 'persons-list-rue');
  }
  if (typeof sbUpdatePresence === 'function' && state.char?.name) {
    sbUpdatePresence(state.char.name, pays, state.currentCity, 'rue-centrale', noeudId).catch(() => {});
  }
  if (typeof chargerVraisJoueursPresents === 'function') {
    chargerVraisJoueursPresents('rue-centrale', noeudId, 'persons-list-rue');
  }
  // Patrouille de police eventuellement affectee a cette rue (lot policiers PNJ, 24 aout 2026) --
  // aucun equivalent n'existait ici pour les detachements militaires (jamais deployables sur une
  // rue, buildingId/roomId toujours nuls hors batiment), donc pas de risque de collision de
  // rendu comme dans enterRoom.
  if (typeof getAffichagePoliceRue === 'function') {
    getAffichagePoliceRue(pays, state.currentCity, noeudId).then(pol => {
      if (pol && rueCentraleNoeudActuel === noeudId) {
        renderPersonsList([...(noeud.persons || []), { name: 'Patrouille de police', role: pol.nombre + ' policier(s) en patrouille', rel: 'neutral', job: 'policier' }], 'persons-list-rue');
      }
    }).catch(() => {});
  }
  if (typeof verifierSurveillancePolicePJ === 'function') {
    verifierSurveillancePolicePJ(null, null, noeudId);
  }

  // Zones cliquables + tooltip
  const scene = document.getElementById('rc-scene');
  zonesAffichees.forEach((z, i) => {
    const div = document.createElement('div');
    div.className = 'rc-zone';
    div.style.left = z.xPct[0] + '%';
    div.style.width = (z.xPct[1] - z.xPct[0]) + '%';
    if (z.yPct) {
      div.style.top = z.yPct[0] + '%';
      div.style.height = (z.yPct[1] - z.yPct[0]) + '%';
    }
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
      else if (z.type === 'sous-lieu') ouvrirTerrainsMontrouge();
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
  const noeudOrigine = rueCentraleNoeudActuel;
  const noeud = RUE_CENTRALE_NOEUDS[pays]?.[rueCentraleNoeudActuel];
  const liensActuels = (noeud?.liensParArrivee && rueCentraleDepuisNoeud && noeud.liensParArrivee[rueCentraleDepuisNoeud]) || noeud?.liens;
  const destination = liensActuels?.[direction];
  if (!destination) return;

  const overlay = document.getElementById('rc-overlay');
  overlay.classList.add('actif');
  setTimeout(() => {
    afficherNoeudRue(pays, destination, noeudOrigine);
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
  const noeudOrigine = rueCentraleNoeudActuel;
  const img = document.getElementById('rc-image');
  const overlay = document.getElementById('rc-overlay');
  const texte = document.getElementById('rc-texte');

  img.style.transition = 'transform 1.1s ease';
  img.style.transform = 'scale(1.4)';
  setTimeout(() => {
    overlay.classList.add('actif');
  }, 500);
  setTimeout(() => {
    afficherNoeudRue(pays, noeudId, noeudOrigine);
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

// Vue generale "Terrains a batir de Montrouge" (correctif UX, 19 aout 2026 -- remplace l'ancien
// modal-postes, juge trop reduit/pas integre au plateau). Reutilise EXACTEMENT le meme squelette
// DOM que enterBuilding()/enterRoom() (vue-batiment, pieces-tabs avec la classe .piece-tab deja
// stylee partout ailleurs, piece-image en grand) pour une interface visuellement identique aux
// autres batiments -- sans jamais appeler enterBuilding()/enterRoom() elles-memes et sans creer
// de nouvelle entree BUILDINGS : ce n'est ni un vrai batiment ni une vraie piece.
// state.currentBuilding reste volontairement null pendant l'affichage de cette vue : le bouton
// "Sortir" deja present dans le template (sortir-btn, onclick="sortirBatiment()") fonctionne donc
// SANS AUCUNE MODIFICATION -- sortirBatiment() ne trouvant aucun batiment courant (null n'est
// jamais dans TERRAINS_PAR_VILLE.ville_b), renvoie simplement et normalement a la rue. Chaque
// onglet appelle directement enterBuilding(idReel) -- le meme point d'entree que partout
// ailleurs, sur un vrai buildingId independant, aucun etat immobilier n'est duplique ni partage
// entre les 6 terrains. Liste des terrains ET superficies issues de TERRAINS_PAR_VILLE.ville_b /
// SURFACE_TERRAINS (plateau-justice-economie.js / plateau-pnj.js), sources uniques de verite,
// jamais dupliquees ici. Le lot 6 n'a volontairement aucune entree dans SURFACE_TERRAINS (sa
// superficie n'a jamais ete officiellement fixee) : son onglet affiche donc juste "Lot 6", sans
// "m²" invente.
function ouvrirTerrainsMontrouge() {
  const ids = (typeof TERRAINS_PAR_VILLE !== 'undefined') ? TERRAINS_PAR_VILLE.ville_b : [];

  document.getElementById('vue-rue').classList.remove('active');
  document.getElementById('vue-batiment').classList.add('active');
  const ancienConteneurRue = document.getElementById('rue-centrale-conteneur');
  if (ancienConteneurRue) ancienConteneurRue.remove();

  document.getElementById('bat-nom').textContent = 'Terrains à bâtir de Montrouge';
  document.getElementById('bat-cat').textContent = 'Immobilier';
  const elCaisse = document.getElementById('bat-caisse');
  const elStock = document.getElementById('bat-stock');
  const elDirecteur = document.getElementById('bat-directeur');
  if (elCaisse) { elCaisse.style.display = 'none'; elCaisse.onclick = null; elCaisse.style.cursor = 'default'; }
  if (elStock) elStock.style.display = 'none';
  if (elDirecteur) elDirecteur.style.display = 'none';

  document.getElementById('pieces-tabs').innerHTML = ids.map(id => {
    const numero = id.split('-').pop();
    const surface = (typeof SURFACE_TERRAINS !== 'undefined') ? SURFACE_TERRAINS[id] : null;
    const label = 'Lot ' + numero + (surface ? ' — ' + surface.toLocaleString('fr-FR') + ' m²' : '');
    return '<div class="piece-tab" onclick="enterBuilding(\'' + id + '\')">' + label + '</div>';
  }).join('');

  const pieceImg = document.getElementById('piece-image');
  pieceImg.style.background = "linear-gradient(180deg, rgba(0,0,0,0) 0%, rgba(0,0,0,0) 65%, rgba(0,0,0,0.18) 100%), url('images/montrouge/montrouge-terrains-vue-ensemble.jpg') center/cover no-repeat";
  document.getElementById('piece-nom').textContent = 'Terrains à bâtir de Montrouge';
  document.getElementById('piece-desc').textContent = 'Six parcelles disponibles autour de la ville. Choisissez un lot ci-dessus pour vous y rendre.';

  renderPersonsList([]);
  document.getElementById('action-context-bat').textContent = 'TERRAINS À BÂTIR DE MONTROUGE — CHOISISSEZ UNE PARCELLE';
  document.getElementById('actions-row-bat').innerHTML = '';

  document.getElementById('loc-name').textContent = 'Montrouge';
  document.getElementById('loc-sub').textContent = 'Terrains à bâtir de Montrouge';
}
