// =====================================================================
// REALISATEUR — COUCHE IA / SELECTION (chantier "industrialisation du realisateur",
// nuit du 30 aout 2026)
// =====================================================================
// OBJECTIF DE CE FICHIER : transformer les briques visuelles deja validees du realisateur
// football (voir plateau-organisations-quetes.js, section "REALISATEUR AUTOMATIQUE" et banc
// d'essai `?footballPreview=1`) en un vrai pipeline industrialise :
//
//     EVENEMENT CANONIQUE / SITUATION VISUELLE
//             |
//     INTENTION DRAMATIQUE
//             |
//     CHOIX D'UNE GRAMMAIRE DE REALISATION COMPATIBLE (matrice de compatibilite)
//             |
//     PLAN DE REALISATION (inspectable, deterministe si seed fourni)
//
// CE FICHIER NE CONTIENT AUCUN ACCES DOM. C'est deliberement une couche de DONNEES + LOGIQUE
// PURE : meme code utilisable (a) dans le navigateur, charge en <script> normal avant
// plateau-organisations-quetes.js, qui l'utilise pour choisir QUELLE sequence deja existante
// declencher ; (b) dans Node, sans aucun shim DOM, pour le simulateur headless
// (plateau-football-realisateur-simulateur.js) et les tests (plateau-football-realisateur-tests.js).
// Aucune des deux utilisations ne modifie ni ne lit jamais une donnee sportive reelle
// (championnat.data, live.scoreHome/Away/evenements, PA, Sante, Popularite, salaires...) : ce
// fichier ne connait le sport qu'a travers les CHAMPS EXPLICITES d'un objet `situation` que
// l'appelant construit lui-meme a partir de donnees deja connues AU MOMENT de la decision
// (jamais un evenement pas encore survenu -- voir section 5, "jamais le futur").
//
// CE FICHIER NE REINVENTE AUCUNE SEQUENCE VISUELLE EXISTANTE. Le registre de grammaires
// (section 3) decrit les sequences deja codees dans plateau-organisations-quetes.js (gabarits de
// montage, banc d'essai A/B/C, chaine coup franc D/E/F1/F2, les 4 effets "Drone Dive",
// "Freeze + Follow Ball", "Orbit Freeze", "Time Ramp") -- il les REFERENCE par id/famille pour
// que le selecteur puisse raisonner sur elles, mais la resolution finale vers la VRAIE sequence
// DOM (SCENARIOS_PREVIEW_REALISATEUR / POOL_GABARITS_REALISATEUR) reste faite exclusivement cote
// navigateur, dans plateau-organisations-quetes.js (section "PONT INTEGRATION IA -> EXECUTEUR
// EXISTANT"). Zero duplication de choregraphie ici.
//
// STATUT DE CE CHANTIER (a lire avant toute integration future -- voir aussi RAPPORT dans
// JOURNAL-SESSION.md du 30 aout 2026) : ce module est branche ce soir UNIQUEMENT sur le banc
// d'essai preview (bouton debug additif, jamais les boutons existants) et sur le simulateur
// headless. Il N'EST PAS branche sur `jouerMicroAction` (point d'entree du vrai match live) --
// remplacer la selection actuelle de `jouerMicroAction` (deja centralisee et deterministe via
// `genererSequenceRealisation`) par ce nouveau selecteur est un choix reversible mais VISIBLE par
// les joueurs, qui merite une verification visuelle reelle avant bascule. C'est un point a
// arbitrer, pas une decision technique implicite (voir rapport final, section "points a
// arbitrer").
// =====================================================================

(function (root) {
'use strict';

// =====================================================================
// 0. PRNG DETERMINISTE
// =====================================================================
// Duplique VOLONTAIREMENT le meme algorithme que hashChaineVersUint32/creerPRNGDeterministe de
// plateau-organisations-quetes.js (FNV-1a puis mulberry32) -- une dizaine de lignes, jamais
// modifiees depuis leur creation. La duplication est un choix assume : ce fichier doit rester
// chargeable seul (Node, tests, simulateur) sans dependre du fichier du live reel. Memes seeds,
// memes resultats des deux cotes -- ce n'est PAS un nouvel algorithme.
function hashChaineVersUint32Ria(str) {
  let h = 0x811c9dc5;
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  return h >>> 0;
}
function creerPRNGDeterministeRia(seedUint32) {
  let a = seedUint32 >>> 0;
  return function () {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// =====================================================================
// 1. VOCABULAIRE DE PRIMITIVES (LOT 2)
// =====================================================================
// Catalogue DESCRIPTIF des mecanismes visuels reellement presents dans
// plateau-organisations-quetes.js. Ce n'est PAS du code executable : chaque entree documente un
// mecanisme deja implemente (champ `implementePar`) et le referme dans un vocabulaire commun,
// pour que le selecteur/la matrice de compatibilite puissent raisonner dessus sans connaitre le
// detail CSS/DOM. `grounded:false` = primitive citee dans le vocabulaire cible mais qui n'existe
// aujourd'hui QUE comme sous-composant d'une primitive composite (jamais invocable seule) --
// signale honnetement plutot que de coder une fausse independance.
const PRIMITIVES_REALISATEUR = {
  CUT: {
    grounded: true,
    description: 'Coupe seche entre deux plans, sans transition.',
    implementePar: 'plan.transition === "cut" / plan.transitionSortie === "cut" (executerSequenceRealisation)',
    interruptible: true, dureeTypiqueMs: 0
  },
  ZOOM: {
    grounded: true,
    description: 'Resserrement ponctuel du cadrage terrain (bump de scale).',
    implementePar: 'effet "zoom" dans appliquerCadrageTerrain (scale *= 1.08) + CADRAGE_SCALE_REALISATEUR.serre',
    interruptible: true, dureeTypiqueMs: 400
  },
  TRACK: {
    grounded: true,
    description: 'Travelling lateral (translation caméra pendant le plan).',
    implementePar: 'effet "travelling" + plan.travellingDx dans appliquerCadrageTerrain',
    interruptible: true, dureeTypiqueMs: 400
  },
  LEAD: {
    grounded: true,
    description: 'Camera V1.5 : anticipe legerement la direction du porteur (regarde devant lui).',
    implementePar: 'CAMERA_ANTICIPATION_* + calculerCadrageCameraMatchMiniature',
    interruptible: true, dureeTypiqueMs: 2600
  },
  DIVE: {
    grounded: false,
    description: 'Plongee caméra isolee (non invocable seule aujourd\'hui).',
    implementePar: 'uniquement comme premiere moitie de DRONE_DIVE (etats "vue_generale_dd" -> "approche_contact_dd")',
    interruptible: false, dureeTypiqueMs: null
  },
  DRONE_DIVE: {
    grounded: true,
    description: 'Plongee caméra progressive vers la zone de contact (bac a sable effet 1).',
    implementePar: 'ETATS_DRONE_DIVE_IMPACT_FREEZE + appliquerCameraSpectaculairePreview (DD_DIVE_SCALE=1.85)',
    interruptible: false, dureeTypiqueMs: 10800
  },
  ORBIT: {
    grounded: false,
    description: 'Rotation de micro-cadrages autour d\'une action (non invocable seule).',
    implementePar: 'uniquement comme composant de ORBIT_FREEZE (etats orbit_a/b/c)',
    interruptible: false, dureeTypiqueMs: null
  },
  SHAKE: {
    grounded: true,
    description: 'Vibration ponctuelle d\'impact.',
    implementePar: 'effet "vibration" (classe .live-pelouse--vibration / .live-realisateur-vibration-appliquee)',
    interruptible: false, dureeTypiqueMs: 280
  },
  FREEZE: {
    grounded: true,
    description: 'Monde fige : aucun nouveau changement de position programme (donc aucune transition CSS ne se declenche).',
    implementePar: 'mecanisme implicite (absence de nouvelle position) utilise par DRONE_DIVE (impact) et ORBIT_FREEZE (monde entier)',
    interruptible: false, dureeTypiqueMs: null
  },
  FREEZE_SELECTIVE: {
    grounded: true,
    description: 'Acteurs figes, ballon NON fige (poursuit sa trajectoire propre).',
    implementePar: 'bac a sable effet 2 (ETATS_FREEZE_FOLLOW_BALL, FB_FREEZE_DUREE_MS=1100)',
    interruptible: false, dureeTypiqueMs: 1100
  },
  SLOW: {
    grounded: true,
    description: 'Ralenti (duree de transition CSS allongee).',
    implementePar: 'effet "ralenti" (1100ms, appliquerCadrageTerrain) / TR_VITESSE_SLOW (2400ms, Time Ramp)',
    interruptible: true, dureeTypiqueMs: 1100
  },
  FAST: {
    grounded: true,
    description: 'Accelere (duree de transition CSS raccourcie).',
    implementePar: 'effet "accelere" (250ms, appliquerCadrageTerrain) / TR_VITESSE_FAST (1100ms, Time Ramp)',
    interruptible: true, dureeTypiqueMs: 250
  },
  TIME_RAMP: {
    grounded: true,
    description: 'Enchainement de regimes de vitesse (normal -> accelere -> ralenti -> normal) sans freeze complet.',
    implementePar: 'bac a sable effet 4 (ETATS_TIME_RAMP, TR_VITESSE_*)',
    interruptible: true, dureeTypiqueMs: 10900
  },
  FOCUS: {
    grounded: true,
    description: 'Cadrage resserre sur le porteur/la zone active (pondere par CAMERA_POIDS_PORTEUR).',
    implementePar: 'calculerCadrageCameraMatchMiniature (composante de base de la Camera V1.5)',
    interruptible: true, dureeTypiqueMs: 2600
  },
  FOLLOW: {
    grounded: true,
    description: 'Suivi continu du porteur/groupe actif par la camera (comportement de base).',
    implementePar: 'Camera V1.5, calculerCadrageCameraMatchMiniature + appliquerCameraMatchMiniaturePreview',
    interruptible: true, dureeTypiqueMs: 2600
  },
  FOLLOW_BALL: {
    grounded: true,
    description: 'La camera se detache du porteur pour suivre le ballon seul.',
    implementePar: 'bac a sable effet 2 (etat "ballon_ralenti_fb", ballonXY manuel + FB_FOLLOW_SCALE=1.48)',
    interruptible: false, dureeTypiqueMs: null
  },
  IMPACT_FREEZE: {
    grounded: true,
    description: 'Freeze bref au moment de l\'impact, la camera pouvant continuer d\'evoluer pendant le freeze.',
    implementePar: 'bac a sable effet 1 (etat "impact_freeze_dd", DD_FREEZE_DUREE_MS=400)',
    interruptible: false, dureeTypiqueMs: 400
  },
  ORBIT_FREEZE: {
    grounded: true,
    description: 'Monde entier fige + 2-3 micro-cadrages camera successifs autour de l\'action (faux bullet-time 2D).',
    implementePar: 'bac a sable effet 3 (ETATS_ORBIT_FREEZE, ORBIT_SOUS_PLAN_MS=500, ORBIT_ROTATION_MAX_DEG=2)',
    interruptible: false, dureeTypiqueMs: 10900
  }
};

// =====================================================================
// 2. INTENTIONS DRAMATIQUES (LOT 3)
// =====================================================================
// Metadonnees de mise en scene -- PAS de nouveaux evenements sportifs. Une intention decrit
// l'ETAT DRAMATIQUE local d'un instant deja connu (micro-action ou evenement canonique deja
// survenu), jamais une prediction. `INTENTIONS_AUTORISEES` mappe un type d'evenement/situation
// vers les intentions qu'il peut raisonnablement porter -- c'est la PREMIERE etape de la matrice
// de compatibilite (LOT 4 affine ensuite intention -> grammaires).
const INTENTIONS_REALISATEUR = [
  'NEUTRE', 'CONSTRUCTION', 'PRESSION', 'ACCELERATION', 'DUEL', 'DANGER',
  'TENSION', 'IMPACT', 'SOULAGEMENT', 'EXPLOSION', 'REACTION', 'RETOUR_CALME'
];

// Cle = 'micro:<type>' (types de CATALOGUE_MICRO_ACTIONS) ou 'canonique:<type>' (types de
// live.evenements : but/occasion/carton/blessure/debut/mitemps/reprise/fin) ou 'coupfranc:<etape>'
// (tension/trajectoire/arret/but -- la chaine D/E/F1/F2 a un typage a part car elle ne correspond
// a aucune micro-action du catalogue V1 ni a un evenement canonique direct, cf. cartographie
// section 9 : ces scenarios sont scriptes a la main, jamais generes par jouerMicroAction).
const INTENTIONS_AUTORISEES_PAR_EVENEMENT = {
  'micro:circulation':  ['NEUTRE', 'CONSTRUCTION', 'RETOUR_CALME'],
  'micro:duel':         ['DUEL', 'TENSION'],
  'micro:interception': ['DUEL', 'ACCELERATION', 'REACTION'],
  'micro:course':       ['CONSTRUCTION', 'ACCELERATION', 'PRESSION'],
  'micro:degagement':   ['NEUTRE', 'SOULAGEMENT'],
  'micro:sortie':       ['NEUTRE', 'RETOUR_CALME'],
  'micro:touche':       ['NEUTRE', 'RETOUR_CALME'],
  'micro:remise':       ['NEUTRE', 'CONSTRUCTION'],
  'micro:centre':       ['PRESSION', 'DANGER', 'TENSION'],
  'micro:frappe':       ['DANGER', 'TENSION', 'IMPACT'],
  'micro:arret':        ['SOULAGEMENT', 'REACTION'],

  'canonique:but':      ['EXPLOSION', 'REACTION'],
  'canonique:occasion': ['DANGER', 'TENSION', 'SOULAGEMENT'],
  'canonique:carton':   ['TENSION', 'REACTION'],
  'canonique:blessure': ['TENSION', 'REACTION'],
  'canonique:debut':    ['NEUTRE'],
  'canonique:mitemps':  ['RETOUR_CALME'],
  'canonique:reprise':  ['NEUTRE'],
  'canonique:fin':      ['RETOUR_CALME'],

  'coupfranc:tension':    ['TENSION'],
  'coupfranc:trajectoire':['TENSION', 'DANGER'],
  'coupfranc:arret':      ['SOULAGEMENT', 'REACTION'],
  'coupfranc:but':        ['EXPLOSION', 'REACTION']
};

function cleEvenement(situation) {
  if (situation.coupFrancEtape) return 'coupfranc:' + situation.coupFrancEtape;
  if (situation.canonique) return 'canonique:' + situation.canonique.type;
  if (situation.microAction) return 'micro:' + situation.microAction;
  return null;
}

function intentionsAutoriseesPourSituation(situation) {
  const cle = cleEvenement(situation);
  return (cle && INTENTIONS_AUTORISEES_PAR_EVENEMENT[cle]) || ['NEUTRE'];
}

// =====================================================================
// 3. REGISTRE DE GRAMMAIRES (LOT 8 — composition des briques existantes)
// =====================================================================
// Chaque entree decrit UNE sequence deja existante (jamais recodee ici). `id` correspond, quand
// la sequence appartient au banc d'essai preview, a l'id reel dans SCENARIOS_PREVIEW_REALISATEUR
// (plateau-organisations-quetes.js) ; pour les gabarits deja utilises en match reel, `id`
// correspond a l'id reel dans POOL_GABARITS_REALISATEUR. Le pont d'integration cote navigateur
// (section "PONT INTEGRATION IA -> EXECUTEUR EXISTANT" de plateau-organisations-quetes.js) est
// seul responsable de resoudre `id` vers la vraie sequence -- ce fichier ne fabrique et n'importe
// aucun DOM.
//
// `primitives` : sous-ensemble de PRIMITIVES_REALISATEUR reellement mises en oeuvre par cette
// grammaire (traçabilite descriptive, pas une dependance executee).
// `microActionsCompatibles` : null = n'importe quelle micro-action (comme dans
// POOL_GABARITS_REALISATEUR), tableau = liste fermee.
// `canoniquesCompatibles` / `coupFrancEtapesCompatibles` : idem, pour les situations canoniques /
// la chaine coup franc.
// `resultatCanoniqueRequis` : null | 'arret' | 'but' -- gate dur (LOT 4) : cette grammaire ne peut
// etre choisie que si la resolution canonique CORRESPONDANTE a deja eu lieu (jamais avant).
// `familleRarete` : regroupe les grammaires qui doivent se raréfier ENTRE ELLES (LOT 6).
// `declencheurs` (LOT 4, correctif "fuite de forme" decouvert par simulation, 30 aout 2026) :
// sous-ensemble EXPLICITE et FERME de ['micro', 'coupfranc', 'canonique'] -- une grammaire n'est
// JAMAIS eligible pour une situation dont la forme (micro-action / etape coup franc / evenement
// canonique nu) n'apparait pas dans sa propre liste, meme si son intention correspondrait par
// ailleurs. Sans ce champ, un `microActionsCompatibles:null` (= "n'importe quelle micro-action")
// se comportait par erreur comme un joker aussi pour les situations canoniques nues/coup-franc
// (silence du garde-fou plutot qu'un rejet), exactement le genre de frontiere implicite que LOT 4
// est cense interdire. Verifie par le simulateur headless (LOT 12, "violations canoniques" +
// diagnostic manuel qui a revele la fuite) avant d'ecrire cette version.
const REGISTRE_GRAMMAIRES_REALISATEUR = [
  // ---- Gabarits deja utilises en match reel (POOL_GABARITS_REALISATEUR) ----
  { id: 'gabarit_montage_0', source: 'production', familleRarete: 'standard', declencheurs: ['micro'],
    primitives: ['TRACK', 'FAST', 'FOLLOW'], microActionsCompatibles: null, canoniquesCompatibles: null,
    coupFrancEtapesCompatibles: null, resultatCanoniqueRequis: null,
    intentionsCompatibles: ['NEUTRE', 'CONSTRUCTION', 'PRESSION', 'ACCELERATION'], poidsBase: 1, spectaculaire: false },
  { id: 'gabarit_montage_1', source: 'production', familleRarete: 'standard', declencheurs: ['micro'],
    primitives: ['FOLLOW'], microActionsCompatibles: null, canoniquesCompatibles: null,
    coupFrancEtapesCompatibles: null, resultatCanoniqueRequis: null,
    // Gabarit generique "simple suivi" -- seul gabarit production a couvrir SOULAGEMENT/REACTION
    // pour une micro-action (degagement/interception/arret narratif) : sans lui, ces deux
    // intentions n'auraient AUCUNE realisation compatible pour une micro-action, cf. commentaire
    // du simulateur (LOT 11, "plan impossible" par lacune de vocabulaire plutot que par
    // conception -- corrige ici, jamais en truquant les poids).
    intentionsCompatibles: ['NEUTRE', 'RETOUR_CALME', 'CONSTRUCTION', 'SOULAGEMENT', 'REACTION'], poidsBase: 1, spectaculaire: false },
  { id: 'gabarit_montage_2', source: 'production', familleRarete: 'standard', declencheurs: ['micro'],
    primitives: ['ZOOM', 'SLOW', 'SHAKE', 'FOLLOW'], microActionsCompatibles: null, canoniquesCompatibles: null,
    coupFrancEtapesCompatibles: null, resultatCanoniqueRequis: null,
    intentionsCompatibles: ['DUEL', 'TENSION', 'DANGER'], poidsBase: 1, spectaculaire: false },
  { id: 'gabarit_montage_3', source: 'production', familleRarete: 'standard', declencheurs: ['micro'],
    primitives: ['FAST', 'FOLLOW'], microActionsCompatibles: null, canoniquesCompatibles: null,
    coupFrancEtapesCompatibles: null, resultatCanoniqueRequis: null,
    intentionsCompatibles: ['ACCELERATION', 'CONSTRUCTION'], poidsBase: 1, spectaculaire: false },
  { id: 'gabarit_montage_4', source: 'production', familleRarete: 'standard', declencheurs: ['micro'],
    primitives: ['ZOOM', 'TRACK', 'FOLLOW'], microActionsCompatibles: null, canoniquesCompatibles: null,
    coupFrancEtapesCompatibles: null, resultatCanoniqueRequis: null,
    intentionsCompatibles: ['PRESSION', 'CONSTRUCTION', 'DANGER'], poidsBase: 1, spectaculaire: false },
  { id: 'gabarit_montage_5', source: 'production', familleRarete: 'standard', declencheurs: ['micro'],
    primitives: ['SHAKE', 'SLOW', 'FOLLOW'], microActionsCompatibles: null, canoniquesCompatibles: null,
    coupFrancEtapesCompatibles: null, resultatCanoniqueRequis: null,
    intentionsCompatibles: ['TENSION', 'DUEL', 'NEUTRE'], poidsBase: 1, spectaculaire: false },
  { id: 'crash_test_ras_du_sol', source: 'production', familleRarete: 'crash_test', declencheurs: ['micro'],
    primitives: ['ZOOM', 'TRACK', 'SHAKE', 'CUT'], microActionsCompatibles: ['duel', 'course', 'remise'],
    canoniquesCompatibles: null, coupFrancEtapesCompatibles: null, resultatCanoniqueRequis: null,
    intentionsCompatibles: ['DUEL', 'ACCELERATION', 'IMPACT'], poidsBase: 0.3, spectaculaire: true },

  // ---- Banc d'essai preview -- jamais dans le pool de production (cf. cartographie §5.2) ----
  { id: 'multi_angle', source: 'preview-demo', familleRarete: 'multi_angle', declencheurs: ['micro'],
    primitives: ['CUT', 'ZOOM', 'FOLLOW'], microActionsCompatibles: ['duel', 'frappe', 'centre'],
    canoniquesCompatibles: null, coupFrancEtapesCompatibles: null, resultatCanoniqueRequis: null,
    intentionsCompatibles: ['DUEL', 'DANGER', 'TENSION'], poidsBase: 0.5, spectaculaire: true },
  { id: 'stop_motion', source: 'preview-demo', familleRarete: 'stop_motion', declencheurs: ['micro'],
    primitives: ['CUT', 'FREEZE'], microActionsCompatibles: ['duel'],
    canoniquesCompatibles: null, coupFrancEtapesCompatibles: null, resultatCanoniqueRequis: null,
    intentionsCompatibles: ['DUEL', 'IMPACT'], poidsBase: 0.4, spectaculaire: true },

  { id: 'tension', source: 'preview-demo', familleRarete: 'coup_franc', declencheurs: ['coupfranc'],
    primitives: ['ZOOM', 'SLOW', 'FOCUS'], microActionsCompatibles: null, canoniquesCompatibles: null,
    coupFrancEtapesCompatibles: ['tension'], resultatCanoniqueRequis: null,
    intentionsCompatibles: ['TENSION'], poidsBase: 1, spectaculaire: false },
  { id: 'trajectoire', source: 'preview-demo', familleRarete: 'coup_franc', declencheurs: ['coupfranc'],
    primitives: ['TRACK', 'FOLLOW_BALL'], microActionsCompatibles: null, canoniquesCompatibles: null,
    coupFrancEtapesCompatibles: ['trajectoire'], resultatCanoniqueRequis: null,
    intentionsCompatibles: ['TENSION', 'DANGER'], poidsBase: 1, spectaculaire: false },
  { id: 'arret', source: 'preview-demo', familleRarete: 'coup_franc', declencheurs: ['coupfranc'],
    primitives: ['CUT', 'FOCUS'], microActionsCompatibles: null, canoniquesCompatibles: null,
    coupFrancEtapesCompatibles: ['arret'], resultatCanoniqueRequis: 'arret',
    intentionsCompatibles: ['SOULAGEMENT', 'REACTION'], poidsBase: 1, spectaculaire: false },
  { id: 'but', source: 'preview-demo', familleRarete: 'coup_franc', declencheurs: ['coupfranc'],
    primitives: ['CUT', 'FOCUS'], microActionsCompatibles: null, canoniquesCompatibles: null,
    coupFrancEtapesCompatibles: ['but'], resultatCanoniqueRequis: 'but',
    intentionsCompatibles: ['EXPLOSION', 'REACTION'], poidsBase: 1, spectaculaire: false },
  { id: 'coup_franc_arrete', source: 'preview-demo', familleRarete: 'coup_franc_chaine', declencheurs: ['coupfranc'],
    primitives: ['ZOOM', 'SLOW', 'FOCUS', 'TRACK', 'FOLLOW_BALL', 'CUT'], microActionsCompatibles: null,
    canoniquesCompatibles: null, coupFrancEtapesCompatibles: null, resultatCanoniqueRequis: 'arret',
    intentionsCompatibles: ['TENSION', 'SOULAGEMENT'], poidsBase: 1, spectaculaire: false, estChaineComplete: true },
  { id: 'coup_franc_but', source: 'preview-demo', familleRarete: 'coup_franc_chaine', declencheurs: ['coupfranc'],
    primitives: ['ZOOM', 'SLOW', 'FOCUS', 'TRACK', 'FOLLOW_BALL', 'CUT'], microActionsCompatibles: null,
    canoniquesCompatibles: null, coupFrancEtapesCompatibles: null, resultatCanoniqueRequis: 'but',
    intentionsCompatibles: ['TENSION', 'EXPLOSION'], poidsBase: 1, spectaculaire: false, estChaineComplete: true },
  { id: 'raccord_coup_franc_arrete', source: 'preview-demo', familleRarete: 'coup_franc_chaine', declencheurs: ['coupfranc'],
    primitives: ['ZOOM', 'SLOW', 'FOCUS', 'TRACK', 'FOLLOW_BALL', 'CUT', 'FOLLOW'], microActionsCompatibles: null,
    canoniquesCompatibles: null, coupFrancEtapesCompatibles: null, resultatCanoniqueRequis: 'arret',
    intentionsCompatibles: ['TENSION', 'SOULAGEMENT'], poidsBase: 1, spectaculaire: false, estChaineComplete: true },
  { id: 'raccord_coup_franc_but', source: 'preview-demo', familleRarete: 'coup_franc_chaine', declencheurs: ['coupfranc'],
    primitives: ['ZOOM', 'SLOW', 'FOCUS', 'TRACK', 'FOLLOW_BALL', 'CUT', 'FOLLOW'], microActionsCompatibles: null,
    canoniquesCompatibles: null, coupFrancEtapesCompatibles: null, resultatCanoniqueRequis: 'but',
    intentionsCompatibles: ['TENSION', 'EXPLOSION'], poidsBase: 1, spectaculaire: false, estChaineComplete: true },

  { id: 'match_miniature_v2', source: 'preview-demo', familleRarete: 'ambiance_continue', declencheurs: ['micro'],
    primitives: ['FOLLOW', 'LEAD'], microActionsCompatibles: null, canoniquesCompatibles: null,
    coupFrancEtapesCompatibles: null, resultatCanoniqueRequis: null,
    intentionsCompatibles: ['NEUTRE', 'CONSTRUCTION', 'RETOUR_CALME'], poidsBase: 1, spectaculaire: false },

  // ---- Les 4 effets valides ----
  { id: 'drone_dive_impact_freeze', source: 'preview-demo', familleRarete: 'effet_camera_lourd', declencheurs: ['micro'],
    primitives: ['DRONE_DIVE', 'IMPACT_FREEZE', 'FOLLOW'], microActionsCompatibles: ['duel', 'frappe', 'interception'],
    canoniquesCompatibles: null, coupFrancEtapesCompatibles: null, resultatCanoniqueRequis: null,
    intentionsCompatibles: ['IMPACT', 'DUEL', 'DANGER'], poidsBase: 0.35, spectaculaire: true },
  { id: 'freeze_follow_ball', source: 'preview-demo', familleRarete: 'effet_camera_lourd', declencheurs: ['micro'],
    primitives: ['FREEZE_SELECTIVE', 'FOLLOW_BALL', 'SLOW'], microActionsCompatibles: ['frappe', 'centre'],
    canoniquesCompatibles: null, coupFrancEtapesCompatibles: null, resultatCanoniqueRequis: null,
    intentionsCompatibles: ['TENSION', 'DANGER', 'IMPACT'], poidsBase: 0.35, spectaculaire: true },
  { id: 'orbit_freeze', source: 'preview-demo', familleRarete: 'effet_camera_lourd', declencheurs: ['micro'],
    primitives: ['ORBIT_FREEZE', 'FREEZE'], microActionsCompatibles: ['duel', 'interception'],
    canoniquesCompatibles: null, coupFrancEtapesCompatibles: null, resultatCanoniqueRequis: null,
    intentionsCompatibles: ['DUEL', 'TENSION'], poidsBase: 0.3, spectaculaire: true },
  { id: 'time_ramp', source: 'preview-demo', familleRarete: 'time_ramp', declencheurs: ['micro'],
    primitives: ['TIME_RAMP', 'FAST', 'SLOW', 'FOLLOW'], microActionsCompatibles: ['course', 'circulation', 'interception'],
    canoniquesCompatibles: null, coupFrancEtapesCompatibles: null, resultatCanoniqueRequis: null,
    intentionsCompatibles: ['ACCELERATION', 'CONSTRUCTION', 'PRESSION'], poidsBase: 0.5, spectaculaire: true }
];

// Invariant teste explicitement (LOT 4, "un joueur ne doit pas recevoir visuellement le merite
// d'un but marque par un autre") : aucune grammaire du registre ne doit porter de champ nommant
// un joueur precis -- verifie au chargement (echoue vite si un futur ajout casse la regle).
REGISTRE_GRAMMAIRES_REALISATEUR.forEach(function (g) {
  if (g.joueur || g.joueurCible) {
    throw new Error('REGISTRE_GRAMMAIRES_REALISATEUR : la grammaire "' + g.id + '" ne doit jamais nommer un joueur precis.');
  }
});

// =====================================================================
// 4. MATRICE DE COMPATIBILITE (LOT 4)
// =====================================================================
// `validerCompatibiliteGrammaire` est LA porte unique : toute grammaire qui la franchit peut
// legitimement etre proposee au tirage pondere. Chaque rejet porte un motif explicite (LOT 14,
// observabilite). Regles dures ecrites ici (jamais dispersees ailleurs) :
//   R1. Un carton ou une blessure ne sont JAMAIS mis en scene par le realisateur decoratif --
//       gate globale AVANT meme de consulter le registre (voir garde dans selectionnerRealisation).
//   R2. Une grammaire avec resultatCanoniqueRequis:'but' ne peut etre choisie que si la situation
//       porte un canonique.type==='but' OU une resolution de coup franc coupFrancResultat==='but'
//       DEJA CONNUE -- jamais avant.
//   R3. Symetrique pour resultatCanoniqueRequis:'arret'. R2/R3 sont mutuellement exclusives par
//       construction (une situation ne peut jamais satisfaire les deux a la fois).
//   R4. L'intention choisie doit figurer dans grammaire.intentionsCompatibles.
//   R5. Le type de declenchement (micro-action / coup-franc-etape) doit etre compatible.
// Determine la FORME d'une situation -- une seule forme a la fois, jamais ambigue (reflete
// exactement la maniere dont le vrai code appelle les choses : jouerMicroAction xor la chaine
// coup-franc xor un evenement canonique nu affiche par afficherInsertCanonique, jamais un melange).
function formeSituation(situation) {
  if (situation.coupFrancEtape) return 'coupfranc';
  if (situation.microAction) return 'micro';
  if (situation.canonique) return 'canonique';
  return null;
}

function validerCompatibiliteGrammaire(grammaire, situation, intention) {
  if (situation.canonique && (situation.canonique.type === 'carton' || situation.canonique.type === 'blessure')) {
    return { ok: false, motif: 'carton/blessure : jamais mis en scene par le realisateur decoratif (R1)' };
  }
  if (grammaire.resultatCanoniqueRequis) {
    const resolu = situation.coupFrancResultat || (situation.canonique && situation.canonique.type === 'but' ? 'but' : null);
    if (resolu !== grammaire.resultatCanoniqueRequis) {
      return { ok: false, motif: 'resultat canonique requis ("' + grammaire.resultatCanoniqueRequis + '") non confirme (R2/R3)' };
    }
  }
  if (!grammaire.intentionsCompatibles.includes(intention)) {
    return { ok: false, motif: 'intention "' + intention + '" non autorisee pour cette grammaire (R4)' };
  }
  const forme = formeSituation(situation);
  if (!forme || !grammaire.declencheurs.includes(forme)) {
    return { ok: false, motif: 'forme de situation "' + forme + '" non couverte par cette grammaire (declencheurs=' + grammaire.declencheurs.join(',') + ') (R5)' };
  }
  if (forme === 'coupfranc') {
    if (grammaire.coupFrancEtapesCompatibles && !grammaire.coupFrancEtapesCompatibles.includes(situation.coupFrancEtape)) {
      return { ok: false, motif: 'etape coup franc "' + situation.coupFrancEtape + '" non compatible (R5)' };
    }
  } else if (forme === 'micro') {
    if (grammaire.microActionsCompatibles && !grammaire.microActionsCompatibles.includes(situation.microAction)) {
      return { ok: false, motif: 'micro-action "' + situation.microAction + '" non compatible (R5)' };
    }
  } else if (forme === 'canonique') {
    if (!grammaire.canoniquesCompatibles || !grammaire.canoniquesCompatibles.includes(situation.canonique.type)) {
      return { ok: false, motif: 'evenement canonique "' + situation.canonique.type + '" non couvert par une grammaire decorative (R5) -- gere par afficherInsertCanonique, hors perimetre du selecteur' };
    }
  }
  return { ok: true, motif: null };
}

function grammairesEligibles(situation, intention) {
  const candidats = [];
  const rejets = [];
  REGISTRE_GRAMMAIRES_REALISATEUR.forEach(function (g) {
    const verdict = validerCompatibiliteGrammaire(g, situation, intention);
    if (verdict.ok) candidats.push(g); else rejets.push({ id: g.id, motif: verdict.motif });
  });
  return { candidats: candidats, rejets: rejets };
}

// =====================================================================
// 5. INTENSITE DRAMATIQUE (LOT 7)
// =====================================================================
// Signature volontairement fermee (`signaux` liste explicitement les seuls champs acceptes) :
// c'est une garde structurelle contre une fuite du futur -- ajouter un champ non prevu ici pour y
// glisser une information future obligerait a modifier cette fonction, jamais un simple appel
// silencieux. Sortie normalisee 0..1.
function calculerIntensiteRealisation(signaux) {
  const s = signaux || {};
  let intensite = 0.2; // base neutre
  const poidsEvenement = {
    frappe: 0.55, centre: 0.4, duel: 0.35, interception: 0.3, course: 0.3,
    circulation: 0.1, remise: 0.1, degagement: 0.15, sortie: 0.1, touche: 0.1, arret: 0.45
  };
  if (s.microAction && poidsEvenement[s.microAction] != null) intensite = poidsEvenement[s.microAction];
  if (s.canoniqueType === 'occasion') intensite = Math.max(intensite, 0.7);
  if (s.canoniqueType === 'but') intensite = 1;
  if (s.coupFrancEtape === 'tension') intensite = Math.max(intensite, 0.6);
  if (s.coupFrancEtape === 'trajectoire') intensite = Math.max(intensite, 0.75);
  if (s.coupFrancEtape === 'arret' || s.coupFrancEtape === 'but') intensite = 1;
  if (s.pressionRecente) intensite = Math.min(1, intensite + 0.15 * Math.min(3, s.pressionRecente));
  if (typeof s.ecartScore === 'number' && s.ecartScore === 0 && typeof s.minute === 'number' && s.minute >= 25) {
    intensite = Math.min(1, intensite + 0.1); // match serre, fin de periode -- tension ambiante
  }
  return Math.max(0, Math.min(1, intensite));
}

// =====================================================================
// 6. RARETE / ANTI-REPETITION (LOT 6)
// =====================================================================
// Parametres de PROTOTYPE, centralises et documentes comme tels (valeurs a ajuster demain,
// jamais un equilibrage artistique definitif -- LOT 6, consigne explicite).
const PARAMETRES_RARETE_REALISATEUR = {
  memoireTailleMax: 10,             // nombre de realisations recentes memorisees
  cooldownFamilleSpectaculaire: 4,  // nb de situations mini avant de reproposer la MEME famille spectaculaire
  cooldownIdExact: 2,               // nb de situations mini avant de reproposer EXACTEMENT le meme id
  malusRepetitionImmediate: 0.05,   // poids residuel si repetition immediate malgre tout (jamais 0 : evite un blocage total)
  malusParOccurrenceRecente: 0.35   // multiplicateur applique par occurrence recente dans la fenetre memoire
};

function creerMemoireRealisateur() {
  return { historique: [] }; // [{id, familleRarete, spectaculaire}], plus recent en fin de tableau
}

function ponderationRarete(memoire, grammaire, params) {
  const p = params || PARAMETRES_RARETE_REALISATEUR;
  const hist = memoire.historique;
  const dernier = hist[hist.length - 1];
  if (dernier && dernier.id === grammaire.id) {
    // Repetition immediate : bloquee si une alternative existe (le sélecteur retire ce candidat
    // seulement quand au moins un autre candidat est disponible -- voir selectionnerRealisation).
    return grammaire.poidsBase * p.malusRepetitionImmediate;
  }
  let poids = grammaire.poidsBase;
  const fenetre = hist.slice(-p.memoireTailleMax);
  const occurrencesId = fenetre.filter(function (h) { return h.id === grammaire.id; }).length;
  poids *= Math.pow(p.malusParOccurrenceRecente, occurrencesId);
  if (grammaire.spectaculaire) {
    const depuisDerniereFamille = (function () {
      for (let i = fenetre.length - 1; i >= 0; i--) {
        if (fenetre[i].familleRarete === grammaire.familleRarete) return fenetre.length - i;
      }
      return Infinity;
    })();
    if (depuisDerniereFamille <= p.cooldownFamilleSpectaculaire) {
      poids *= (depuisDerniereFamille / (p.cooldownFamilleSpectaculaire + 1));
    }
  }
  return Math.max(0, poids);
}

function enregistrerRealisationMemoire(memoire, grammaire) {
  memoire.historique.push({ id: grammaire.id, familleRarete: grammaire.familleRarete, spectaculaire: !!grammaire.spectaculaire });
  if (memoire.historique.length > PARAMETRES_RARETE_REALISATEUR.memoireTailleMax * 3) {
    memoire.historique = memoire.historique.slice(-PARAMETRES_RARETE_REALISATEUR.memoireTailleMax * 3);
  }
}

// =====================================================================
// 7. SELECTEUR CENTRALISE (LOT 5)
// =====================================================================
// Entree : { situation, seed, memoire, intentionForcee? }. `situation` decrit un instant DEJA
// CONNU (jamais un futur) -- voir section 5 pour les champs acceptes par le calcul d'intensite ;
// `situation` peut porter en plus microAction / canonique{type,joueur} / coupFrancEtape /
// coupFrancResultat, tous deja etablis par l'appelant AVANT l'appel (jamais devines ici).
// Sortie : { plan, trace }. `plan` est null si aucune grammaire n'est eligible (LOT 11, "plans
// sans realisation disponible" -- un cas legitime, pas une erreur). `trace` est TOUJOURS
// renseignee (LOT 14, observabilite), meme quand `plan` est null.
function selectionnerRealisation(entree) {
  const situation = entree.situation;
  const memoire = entree.memoire || creerMemoireRealisateur();
  const seed = entree.seed != null ? String(entree.seed) : String(Math.random());
  const rng = creerPRNGDeterministeRia(hashChaineVersUint32Ria('selecteur-realisateur-' + seed));

  const trace = { situation: situation, seed: seed, rejets: [], candidatsPonderes: [] };

  if (situation.canonique && (situation.canonique.type === 'carton' || situation.canonique.type === 'blessure')) {
    trace.rejetGlobal = 'carton/blessure jamais mis en scene par le realisateur decoratif -- route directe vers afficherInsertCanonique (R1)';
    return { plan: null, trace: trace };
  }

  const intentionsPossibles = entree.intentionForcee ? [entree.intentionForcee] : intentionsAutoriseesPourSituation(situation);
  const intention = intentionsPossibles.length === 1
    ? intentionsPossibles[0]
    : intentionsPossibles[Math.floor(rng() * intentionsPossibles.length)];
  trace.intention = intention;

  const intensite = calculerIntensiteRealisation({
    microAction: situation.microAction, canoniqueType: situation.canonique && situation.canonique.type,
    coupFrancEtape: situation.coupFrancEtape, pressionRecente: situation.pressionRecente,
    ecartScore: situation.ecartScore, minute: situation.minute
  });
  trace.intensite = intensite;

  const eligibilite = grammairesEligibles(situation, intention);
  trace.rejets = eligibilite.rejets;

  let candidats = eligibilite.candidats;
  // Repetition immediate : on la retire si une alternative existe (LOT 6, "eviter deux
  // realisations identiques successives lorsque des alternatives compatibles existent").
  const dernier = memoire.historique[memoire.historique.length - 1];
  if (dernier && candidats.length > 1) {
    const sansRepetition = candidats.filter(function (g) { return g.id !== dernier.id; });
    if (sansRepetition.length) candidats = sansRepetition;
  }

  if (!candidats.length) {
    trace.rejetGlobal = 'aucune grammaire eligible pour cette situation/intention';
    return { plan: null, trace: trace };
  }

  const pondere = candidats.map(function (g) { return { g: g, poids: ponderationRarete(memoire, g) }; });
  trace.candidatsPonderes = pondere.map(function (p) { return { id: p.g.id, poids: Number(p.poids.toFixed(4)) }; });
  const totalPoids = pondere.reduce(function (s, p) { return s + p.poids; }, 0);
  let choisi = pondere[pondere.length - 1].g;
  if (totalPoids > 0) {
    let r = rng() * totalPoids;
    for (let i = 0; i < pondere.length; i++) {
      r -= pondere[i].poids;
      if (r <= 0) { choisi = pondere[i].g; break; }
    }
  }
  trace.choisi = choisi.id;

  enregistrerRealisationMemoire(memoire, choisi);

  const plan = {
    intention: intention,
    intensity: intensite,
    selectedGrammar: choisi.id,
    primitives: choisi.primitives.slice(),
    source: choisi.source,
    familleRarete: choisi.familleRarete,
    spectaculaire: !!choisi.spectaculaire,
    insert: situation.canonique ? 'canonique-existant' : null,
    reaction: (intention === 'EXPLOSION' || intention === 'REACTION') ? 'reaction-generique' : null,
    returnMode: 'retour-mini-terrain-standard'
  };
  return { plan: plan, trace: trace };
}

// =====================================================================
// 8. EXPORT (compatible Node ET navigateur, sans dependance croisee)
// =====================================================================
const RealisateurIA = {
  PRIMITIVES_REALISATEUR: PRIMITIVES_REALISATEUR,
  INTENTIONS_REALISATEUR: INTENTIONS_REALISATEUR,
  INTENTIONS_AUTORISEES_PAR_EVENEMENT: INTENTIONS_AUTORISEES_PAR_EVENEMENT,
  REGISTRE_GRAMMAIRES_REALISATEUR: REGISTRE_GRAMMAIRES_REALISATEUR,
  PARAMETRES_RARETE_REALISATEUR: PARAMETRES_RARETE_REALISATEUR,
  intentionsAutoriseesPourSituation: intentionsAutoriseesPourSituation,
  formeSituation: formeSituation,
  validerCompatibiliteGrammaire: validerCompatibiliteGrammaire,
  grammairesEligibles: grammairesEligibles,
  calculerIntensiteRealisation: calculerIntensiteRealisation,
  creerMemoireRealisateur: creerMemoireRealisateur,
  ponderationRarete: ponderationRarete,
  enregistrerRealisationMemoire: enregistrerRealisationMemoire,
  selectionnerRealisation: selectionnerRealisation,
  hashChaineVersUint32Ria: hashChaineVersUint32Ria,
  creerPRNGDeterministeRia: creerPRNGDeterministeRia
};

if (typeof module !== 'undefined' && module.exports) {
  module.exports = RealisateurIA;
}
if (root) {
  root.RealisateurIA = RealisateurIA;
}
})(typeof window !== 'undefined' ? window : (typeof globalThis !== 'undefined' ? globalThis : null));
