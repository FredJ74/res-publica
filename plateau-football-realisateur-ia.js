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
// `etatSortie` (LOT "montage continu", 30 aout 2026 -- ajoute apres retour utilisateur : "le
// systeme varie bien les realisations mais les enchainements ne paraissent pas naturels"):
// descripteur LEGER et GROUNDE (audit direct des sequences reelles dans
// plateau-organisations-quetes.js, jamais invente) de ce que montre la DERNIERE portion de la
// grammaire avant que le reset universel (reinitialiserSceneApresSequenceRealisation, partage par
// TOUTES les sequences) ne remette la scene a plat :
//  - medium : 'miniature' (reste sur la camera CSS du terrain) | 'illustre_image' (bascule sur
//    l'overlay illustre, pictogramme ou photo fixe) | 'illustre_pictogram' (overlay SANS asset --
//    COUCHE_ILLUSTRE_FIXE_DEFAUT, rendu emoji, cf. gabarit_montage_4) | 'illustre_video' (dernier
//    plan est une <video>, avec son).
//  - reactionTerminale : true si le DERNIER plan est assume comme un plan de reaction/aftermath
//    (uniquement les 2 videos F1/F2 et les chaines qui se terminent dessus -- jamais suppose pour
//    une simple pose fixe).
//  - resolutionAssumee : true si la grammaire MONTRE une resolution (contrairement a D/E qui
//    s'arretent deliberement avant, cf. commentaires "s'arrete DELIBEREMENT avant toute resolution
//    sportive" / "aucun but/arret affirme" dans le fichier source).
//  - retourTerrainInclus : true si la grammaire elle-meme ramene la camera au mini-terrain avant sa
//    propre fin (raccord_coup_franc_*, tous les gabarits sauf gabarit_montage_4, match_miniature_v2,
//    les 4 effets) plutot que de compter uniquement sur le reset universel.
// `statut` (chantier "audit du catalogue visuel", 30 aout 2026, suite au retour de Fred : "A/B
// jamais vus, C vu une seule fois comme une image, deux glaives croises jamais valides") :
// EXISTER dans le registre NE SIGNIFIE PAS etre automatiquement autorise -- estAutoriseAutomatiquement()
// (section suivante) est la SEULE porte d'entree du pool automatique, jamais un filtre implicite
// ailleurs. Valeurs possibles, jamais declarees arbitrairement :
//  - VALIDATED_PRODUCTION : deja live en match reel via jouerMicroAction (gabarits + crash-test),
//    validation implicite par l'usage continu depuis le chantier du 28 aout 2026 -- PAS nommes
//    explicitement dans la liste "A/B/C/D/E/F/effets" de Fred (lignage de validation distinct).
//  - VALIDATED_BANC_ESSAI : nomme EXPLICITEMENT par Fred comme demonstration complete validee
//    (A/B/C/D/E/F1/F2/chaines/4 effets).
//  - VALIDATED_A_CONFIRMER : existe et fonctionne (match_miniature_v2), jamais nomme explicitement
//    par Fred -- reste autorise (rien de factuellement casse ne justifie de le retirer) mais
//    signale pour confirmation explicite plutot que suppose valide silencieusement.
// `nbPlansAttendu` / `dureeMsAttendueApprox` : mesures directement sur les constantes source
// (dureeTotaleSequence deja calculee et commentee dans le fichier pour les sequences fixes ;
// intervalle documente pour les gabarits a duree variable, aleatoire par construction) -- sert la
// verification d'identite SELECTED -> RESOLVED (section 11 de la consigne) : un ecart entre
// resolution.sequence.plans.length et nbPlansAttendu signale une resolution vers la mauvaise unite.
// `rolesNarratifs` (chantier "montage narratif", 30 aout 2026) : sous-ensemble de
// ROLES_NARRATIFS (section suivante) que cette grammaire peut remplir au sein d'un ARC -- champ
// PUREMENT DESCRIPTIF, jamais lu par la choregraphie reelle, jamais une nouvelle contrainte sur
// les regles R0-R5/MR1-MR3 deja existantes (une grammaire reste d'abord filtree par TOUTES ces
// regles, le role narratif est un filtre SUPPLEMENTAIRE, jamais un remplacement). Assignation
// groundee sur ce qui est deja documente (etatSortie/familleRarete/microActionsCompatibles),
// jamais une nouvelle affirmation visuelle.
const REGISTRE_GRAMMAIRES_REALISATEUR = [
  // ---- Gabarits deja utilises en match reel (POOL_GABARITS_REALISATEUR) ----
  { id: 'gabarit_montage_0', source: 'production', familleRarete: 'standard', declencheurs: ['micro'],
    statut: 'VALIDATED_PRODUCTION', nbPlansAttendu: 1, dureeMsAttendueApprox: '900-1400 (variable)',
    rolesNarratifs: ['SETUP', 'ACTION'],
    primitives: ['TRACK', 'FAST', 'FOLLOW'], microActionsCompatibles: null, canoniquesCompatibles: null,
    coupFrancEtapesCompatibles: null, resultatCanoniqueRequis: null,
    intentionsCompatibles: ['NEUTRE', 'CONSTRUCTION', 'PRESSION', 'ACCELERATION'], poidsBase: 1, spectaculaire: false,
    etatSortie: { medium: 'miniature', reactionTerminale: false, resolutionAssumee: false, retourTerrainInclus: true } },
  { id: 'gabarit_montage_1', source: 'production', familleRarete: 'standard', declencheurs: ['micro'],
    statut: 'VALIDATED_PRODUCTION', nbPlansAttendu: 1, dureeMsAttendueApprox: '800-1200 (variable)',
    rolesNarratifs: ['SETUP', 'ACTION', 'RETURN'],
    primitives: ['FOLLOW'], microActionsCompatibles: null, canoniquesCompatibles: null,
    coupFrancEtapesCompatibles: null, resultatCanoniqueRequis: null,
    // Gabarit generique "simple suivi" -- seul gabarit production a couvrir SOULAGEMENT/REACTION
    // pour une micro-action (degagement/interception/arret narratif) : sans lui, ces deux
    // intentions n'auraient AUCUNE realisation compatible pour une micro-action, cf. commentaire
    // du simulateur (LOT 11, "plan impossible" par lacune de vocabulaire plutot que par
    // conception -- corrige ici, jamais en truquant les poids).
    intentionsCompatibles: ['NEUTRE', 'RETOUR_CALME', 'CONSTRUCTION', 'SOULAGEMENT', 'REACTION'], poidsBase: 1, spectaculaire: false,
    etatSortie: { medium: 'miniature', reactionTerminale: false, resolutionAssumee: false, retourTerrainInclus: true } },
  { id: 'gabarit_montage_2', source: 'production', familleRarete: 'standard', declencheurs: ['micro'],
    statut: 'VALIDATED_PRODUCTION', nbPlansAttendu: 2, dureeMsAttendueApprox: '1200-1900 (variable)',
    rolesNarratifs: ['ACTION', 'RESOLUTION'],
    primitives: ['ZOOM', 'SLOW', 'SHAKE', 'FOLLOW'], microActionsCompatibles: null, canoniquesCompatibles: null,
    coupFrancEtapesCompatibles: null, resultatCanoniqueRequis: null,
    intentionsCompatibles: ['DUEL', 'TENSION', 'DANGER'], poidsBase: 1, spectaculaire: false,
    etatSortie: { medium: 'miniature', reactionTerminale: false, resolutionAssumee: false, retourTerrainInclus: true } },
  { id: 'gabarit_montage_3', source: 'production', familleRarete: 'standard', declencheurs: ['micro'],
    statut: 'VALIDATED_PRODUCTION', nbPlansAttendu: 3, dureeMsAttendueApprox: '1850-2800 (variable)',
    rolesNarratifs: ['SETUP', 'ACTION'],
    primitives: ['FAST', 'FOLLOW'], microActionsCompatibles: null, canoniquesCompatibles: null,
    coupFrancEtapesCompatibles: null, resultatCanoniqueRequis: null,
    intentionsCompatibles: ['ACCELERATION', 'CONSTRUCTION'], poidsBase: 1, spectaculaire: false,
    // 3 plans (terrain -> illustre pictogramme -> terrain) : revient DEJA au terrain lui-meme.
    etatSortie: { medium: 'miniature', reactionTerminale: false, resolutionAssumee: false, retourTerrainInclus: true } },
  { id: 'gabarit_montage_4', source: 'production', familleRarete: 'standard', declencheurs: ['micro'],
    // EXCLU du pool automatique (chantier "montage narratif", 30 aout 2026, decision de direction
    // artistique de Fred, section 10) : ce gabarit reste TECHNIQUEMENT documente et INCHANGE (il
    // continue de servir le match reel via jouerMicroAction/POOL_GABARITS_REALISATEUR, code non
    // touche par ce chantier -- "ne pas supprimer aveuglement, il sert ailleurs") mais son statut
    // n'est PLUS dans STATUTS_AUTORISES_POOL_AUTOMATIQUE : R0 le rejette desormais TOUJOURS pour
    // le nouveau selecteur/monteur narratif, donc son pictogramme de repli '⚔️' (glaives croises,
    // voir commentaire etatSortie ci-dessous) ne peut plus jamais y apparaitre. Correction MINIMALE
    // : un seul champ change (statut), rien d'autre n'est retire ni recode.
    statut: 'REJECTED_VISUEL_PICTOGRAMME_NON_APPROUVE',
    nbPlansAttendu: 2, dureeMsAttendueApprox: '1600-2350 (variable)',
    rolesNarratifs: [],
    primitives: ['ZOOM', 'TRACK', 'FOLLOW'], microActionsCompatibles: null, canoniquesCompatibles: null,
    coupFrancEtapesCompatibles: null, resultatCanoniqueRequis: null,
    intentionsCompatibles: ['PRESSION', 'CONSTRUCTION', 'DANGER'], poidsBase: 1, spectaculaire: false,
    // SEUL gabarit dont le DERNIER plan est 'illustre' (GABARITS_MONTAGE_REALISATEUR index 4,
    // sans asset -> pictogramme COUCHE_ILLUSTRE_FIXE_DEFAUT, ex. le glaives croises '⚔️' pour
    // instant.type==='duel' -- ICONES_MICRO_ACTION_REALISATEUR, commit c0c93283 du 28 aout 2026,
    // AVANT tout chantier de cette semaine). Comportement PRE-EXISTANT et documente comme accepte
    // dans le code source ("aucune adaptation necessaire" tant qu'aucun asset n'existe) -- jamais
    // introduit par le nouveau selecteur, seulement rendu ATTEIGNABLE par le pont debug depuis la
    // correction du 30 aout 2026 (trouverSequenceProductionAvecGabaritId), puis EXCLU par la
    // decision de direction artistique du meme jour (section 10). Ne revient PAS au terrain
    // lui-meme, compte entierement sur le reset universel.
    etatSortie: { medium: 'illustre_pictogram', reactionTerminale: false, resolutionAssumee: false, retourTerrainInclus: false } },
  { id: 'gabarit_montage_5', source: 'production', familleRarete: 'standard', declencheurs: ['micro'],
    statut: 'VALIDATED_PRODUCTION', nbPlansAttendu: 3, dureeMsAttendueApprox: '1500-2250 (variable)',
    rolesNarratifs: ['ACTION', 'RESOLUTION'],
    primitives: ['SHAKE', 'SLOW', 'FOLLOW'], microActionsCompatibles: null, canoniquesCompatibles: null,
    coupFrancEtapesCompatibles: null, resultatCanoniqueRequis: null,
    intentionsCompatibles: ['TENSION', 'DUEL', 'NEUTRE'], poidsBase: 1, spectaculaire: false,
    etatSortie: { medium: 'miniature', reactionTerminale: false, resolutionAssumee: false, retourTerrainInclus: true } },
  { id: 'crash_test_ras_du_sol', source: 'production', familleRarete: 'crash_test', declencheurs: ['micro'],
    statut: 'VALIDATED_PRODUCTION', nbPlansAttendu: 1, dureeMsAttendueApprox: '1000-1400 (variable)',
    rolesNarratifs: ['ACTION', 'CLIMAX'],
    // Meme visuel EXACT que le bouton preview 'A -- Plan unique' (trouverSequenceCrashTestRasDuSol
    // force ce meme gabaritId par recherche de seed) -- deux points d'entree, une seule grammaire.
    primitives: ['ZOOM', 'TRACK', 'SHAKE', 'CUT'], microActionsCompatibles: ['duel', 'course', 'remise'],
    canoniquesCompatibles: null, coupFrancEtapesCompatibles: null, resultatCanoniqueRequis: null,
    intentionsCompatibles: ['DUEL', 'ACCELERATION', 'IMPACT'], poidsBase: 0.3, spectaculaire: true,
    etatSortie: { medium: 'illustre_image', reactionTerminale: false, resolutionAssumee: false, retourTerrainInclus: false } },

  // ---- Banc d'essai preview -- jamais dans le pool de production (cf. cartographie §5.2) ----
  { id: 'multi_angle', source: 'preview-demo', familleRarete: 'multi_angle', declencheurs: ['micro'],
    statut: 'VALIDATED_BANC_ESSAI', nbPlansAttendu: 3, dureeMsAttendueApprox: 2250,
    rolesNarratifs: ['ACTION', 'CLIMAX'],
    primitives: ['CUT', 'ZOOM', 'FOLLOW'], microActionsCompatibles: ['duel', 'frappe', 'centre'],
    canoniquesCompatibles: null, coupFrancEtapesCompatibles: null, resultatCanoniqueRequis: null,
    intentionsCompatibles: ['DUEL', 'DANGER', 'TENSION'], poidsBase: 0.5, spectaculaire: true,
    etatSortie: { medium: 'illustre_image', reactionTerminale: false, resolutionAssumee: false, retourTerrainInclus: false } },
  { id: 'stop_motion', source: 'preview-demo', familleRarete: 'stop_motion', declencheurs: ['micro'],
    statut: 'VALIDATED_BANC_ESSAI', nbPlansAttendu: 8, dureeMsAttendueApprox: 3500,
    rolesNarratifs: ['ACTION', 'CLIMAX', 'RESOLUTION'],
    primitives: ['CUT', 'FREEZE'], microActionsCompatibles: ['duel'],
    canoniquesCompatibles: null, coupFrancEtapesCompatibles: null, resultatCanoniqueRequis: null,
    intentionsCompatibles: ['DUEL', 'IMPACT'], poidsBase: 0.4, spectaculaire: true,
    etatSortie: { medium: 'illustre_image', reactionTerminale: false, resolutionAssumee: false, retourTerrainInclus: false } },

  { id: 'tension', source: 'preview-demo', familleRarete: 'coup_franc', declencheurs: ['coupfranc'],
    statut: 'VALIDATED_BANC_ESSAI', nbPlansAttendu: 13, dureeMsAttendueApprox: 11740,
    rolesNarratifs: ['SETUP'],
    primitives: ['ZOOM', 'SLOW', 'FOCUS'], microActionsCompatibles: null, canoniquesCompatibles: null,
    coupFrancEtapesCompatibles: ['tension'], resultatCanoniqueRequis: null,
    intentionsCompatibles: ['TENSION'], poidsBase: 1, spectaculaire: false,
    // "s'arrete DELIBEREMENT avant toute resolution sportive" (commentaire source) -- cliffhanger
    // assume, continuation naturelle = 'trajectoire'.
    etatSortie: { medium: 'illustre_image', reactionTerminale: false, resolutionAssumee: false, retourTerrainInclus: false, suiteNaturelle: 'trajectoire' } },
  { id: 'trajectoire', source: 'preview-demo', familleRarete: 'coup_franc', declencheurs: ['coupfranc'],
    statut: 'VALIDATED_BANC_ESSAI', nbPlansAttendu: 3, dureeMsAttendueApprox: 2350,
    rolesNarratifs: ['ACTION'],
    primitives: ['TRACK', 'FOLLOW_BALL'], microActionsCompatibles: null, canoniquesCompatibles: null,
    coupFrancEtapesCompatibles: ['trajectoire'], resultatCanoniqueRequis: null,
    intentionsCompatibles: ['TENSION', 'DANGER'], poidsBase: 1, spectaculaire: false,
    // "aucun but/arret affirme" (commentaire source) -- cliffhanger assume egalement.
    etatSortie: { medium: 'illustre_image', reactionTerminale: false, resolutionAssumee: false, retourTerrainInclus: false } },
  { id: 'arret', source: 'preview-demo', familleRarete: 'coup_franc', declencheurs: ['coupfranc'],
    statut: 'VALIDATED_BANC_ESSAI', nbPlansAttendu: 4, dureeMsAttendueApprox: 6900,
    rolesNarratifs: ['RESOLUTION', 'REACTION'],
    primitives: ['CUT', 'FOCUS'], microActionsCompatibles: null, canoniquesCompatibles: null,
    coupFrancEtapesCompatibles: ['arret'], resultatCanoniqueRequis: 'arret',
    intentionsCompatibles: ['SOULAGEMENT', 'REACTION'], poidsBase: 1, spectaculaire: false,
    // Dernier plan = VIDEO (reaction de Taclojnou, son) -- reactionTerminale grounde dans le code.
    etatSortie: { medium: 'illustre_video', reactionTerminale: true, resolutionAssumee: true, retourTerrainInclus: false } },
  { id: 'but', source: 'preview-demo', familleRarete: 'coup_franc', declencheurs: ['coupfranc'],
    statut: 'VALIDATED_BANC_ESSAI', nbPlansAttendu: 3, dureeMsAttendueApprox: 6200,
    rolesNarratifs: ['RESOLUTION', 'REACTION'],
    primitives: ['CUT', 'FOCUS'], microActionsCompatibles: null, canoniquesCompatibles: null,
    coupFrancEtapesCompatibles: ['but'], resultatCanoniqueRequis: 'but',
    intentionsCompatibles: ['EXPLOSION', 'REACTION'], poidsBase: 1, spectaculaire: false,
    etatSortie: { medium: 'illustre_video', reactionTerminale: true, resolutionAssumee: true, retourTerrainInclus: false } },
  // coup_franc_arrete/but (chaine BRUTE, sans bookend terrain) : se termine sur la meme video que
  // F1/F2 puis retombe directement sur le reset universel -- exactement le raccord que Fred a
  // signale comme peu naturel. raccord_coup_franc_arrete/but couvrent le MEME contenu (memes
  // .plans, simple concat, cf. source) avec un retour terrain explicite en plus : deprioriser=true
  // (LOT montage, regle MR3) fait que le selecteur automatique prefere TOUJOURS la variante
  // raccordee quand elle est egalement eligible -- la chaine brute reste choisissable a la main
  // (bouton preview existant, inchange) et par le selecteur si, pour une raison quelconque, la
  // variante raccordee n'etait pas dans le pool eligible.
  { id: 'coup_franc_arrete', source: 'preview-demo', familleRarete: 'coup_franc_chaine', declencheurs: ['coupfranc'],
    statut: 'VALIDATED_BANC_ESSAI', nbPlansAttendu: 20, dureeMsAttendueApprox: 20990,
    rolesNarratifs: ['SETUP', 'ACTION', 'RESOLUTION', 'REACTION'],
    primitives: ['ZOOM', 'SLOW', 'FOCUS', 'TRACK', 'FOLLOW_BALL', 'CUT'], microActionsCompatibles: null,
    canoniquesCompatibles: null, coupFrancEtapesCompatibles: null, resultatCanoniqueRequis: 'arret',
    intentionsCompatibles: ['TENSION', 'SOULAGEMENT'], poidsBase: 1, spectaculaire: false, estChaineComplete: true,
    etatSortie: { medium: 'illustre_video', reactionTerminale: true, resolutionAssumee: true, retourTerrainInclus: false },
    deprioriserSiRaccordDisponible: 'raccord_coup_franc_arrete' },
  { id: 'coup_franc_but', source: 'preview-demo', familleRarete: 'coup_franc_chaine', declencheurs: ['coupfranc'],
    statut: 'VALIDATED_BANC_ESSAI', nbPlansAttendu: 19, dureeMsAttendueApprox: 20290,
    rolesNarratifs: ['SETUP', 'ACTION', 'RESOLUTION', 'REACTION'],
    primitives: ['ZOOM', 'SLOW', 'FOCUS', 'TRACK', 'FOLLOW_BALL', 'CUT'], microActionsCompatibles: null,
    canoniquesCompatibles: null, coupFrancEtapesCompatibles: null, resultatCanoniqueRequis: 'but',
    intentionsCompatibles: ['TENSION', 'EXPLOSION'], poidsBase: 1, spectaculaire: false, estChaineComplete: true,
    etatSortie: { medium: 'illustre_video', reactionTerminale: true, resolutionAssumee: true, retourTerrainInclus: false },
    deprioriserSiRaccordDisponible: 'raccord_coup_franc_but' },
  { id: 'raccord_coup_franc_arrete', source: 'preview-demo', familleRarete: 'coup_franc_chaine', declencheurs: ['coupfranc'],
    statut: 'VALIDATED_BANC_ESSAI', nbPlansAttendu: 24, dureeMsAttendueApprox: 24890,
    rolesNarratifs: ['SETUP', 'ACTION', 'RESOLUTION', 'REACTION', 'RETURN'],
    primitives: ['ZOOM', 'SLOW', 'FOCUS', 'TRACK', 'FOLLOW_BALL', 'CUT', 'FOLLOW'], microActionsCompatibles: null,
    canoniquesCompatibles: null, coupFrancEtapesCompatibles: null, resultatCanoniqueRequis: 'arret',
    intentionsCompatibles: ['TENSION', 'SOULAGEMENT'], poidsBase: 1, spectaculaire: false, estChaineComplete: true,
    // Se termine sur PHASE_TERRAIN_APRES_ARRET (type 'terrain', cf. source) -- retour terrain
    // DEJA ecrit dans la sequence elle-meme, pas seulement par le reset universel.
    etatSortie: { medium: 'miniature', reactionTerminale: false, resolutionAssumee: true, retourTerrainInclus: true } },
  { id: 'raccord_coup_franc_but', source: 'preview-demo', familleRarete: 'coup_franc_chaine', declencheurs: ['coupfranc'],
    statut: 'VALIDATED_BANC_ESSAI', nbPlansAttendu: 23, dureeMsAttendueApprox: 24190,
    rolesNarratifs: ['SETUP', 'ACTION', 'RESOLUTION', 'REACTION', 'RETURN'],
    primitives: ['ZOOM', 'SLOW', 'FOCUS', 'TRACK', 'FOLLOW_BALL', 'CUT', 'FOLLOW'], microActionsCompatibles: null,
    canoniquesCompatibles: null, coupFrancEtapesCompatibles: null, resultatCanoniqueRequis: 'but',
    intentionsCompatibles: ['TENSION', 'EXPLOSION'], poidsBase: 1, spectaculaire: false, estChaineComplete: true,
    etatSortie: { medium: 'miniature', reactionTerminale: false, resolutionAssumee: true, retourTerrainInclus: true } },

  { id: 'match_miniature_v2', source: 'preview-demo', familleRarete: 'ambiance_continue', declencheurs: ['micro'],
    statut: 'VALIDATED_A_CONFIRMER', nbPlansAttendu: 10, dureeMsAttendueApprox: 18800,
    rolesNarratifs: ['SETUP', 'RETURN'],
    primitives: ['FOLLOW', 'LEAD'], microActionsCompatibles: null, canoniquesCompatibles: null,
    coupFrancEtapesCompatibles: null, resultatCanoniqueRequis: null,
    intentionsCompatibles: ['NEUTRE', 'CONSTRUCTION', 'RETOUR_CALME'], poidsBase: 1, spectaculaire: false,
    etatSortie: { medium: 'miniature', reactionTerminale: false, resolutionAssumee: false, retourTerrainInclus: true } },

  // ---- Les 4 effets valides (camera-only, jamais d'overlay illustre -- cf. cartographie) ----
  { id: 'drone_dive_impact_freeze', source: 'preview-demo', familleRarete: 'effet_camera_lourd', declencheurs: ['micro'],
    statut: 'VALIDATED_BANC_ESSAI', nbPlansAttendu: 6, dureeMsAttendueApprox: 10800,
    rolesNarratifs: ['CLIMAX'],
    primitives: ['DRONE_DIVE', 'IMPACT_FREEZE', 'FOLLOW'], microActionsCompatibles: ['duel', 'frappe', 'interception'],
    canoniquesCompatibles: null, coupFrancEtapesCompatibles: null, resultatCanoniqueRequis: null,
    intentionsCompatibles: ['IMPACT', 'DUEL', 'DANGER'], poidsBase: 0.35, spectaculaire: true,
    etatSortie: { medium: 'miniature', reactionTerminale: false, resolutionAssumee: false, retourTerrainInclus: true } },
  { id: 'freeze_follow_ball', source: 'preview-demo', familleRarete: 'effet_camera_lourd', declencheurs: ['micro'],
    statut: 'VALIDATED_BANC_ESSAI', nbPlansAttendu: 6, dureeMsAttendueApprox: 11100,
    rolesNarratifs: ['CLIMAX', 'RESOLUTION'],
    primitives: ['FREEZE_SELECTIVE', 'FOLLOW_BALL', 'SLOW'], microActionsCompatibles: ['frappe', 'centre'],
    canoniquesCompatibles: null, coupFrancEtapesCompatibles: null, resultatCanoniqueRequis: null,
    intentionsCompatibles: ['TENSION', 'DANGER', 'IMPACT'], poidsBase: 0.35, spectaculaire: true,
    etatSortie: { medium: 'miniature', reactionTerminale: false, resolutionAssumee: false, retourTerrainInclus: true } },
  { id: 'orbit_freeze', source: 'preview-demo', familleRarete: 'effet_camera_lourd', declencheurs: ['micro'],
    statut: 'VALIDATED_BANC_ESSAI', nbPlansAttendu: 8, dureeMsAttendueApprox: 10900,
    rolesNarratifs: ['CLIMAX'],
    primitives: ['ORBIT_FREEZE', 'FREEZE'], microActionsCompatibles: ['duel', 'interception'],
    canoniquesCompatibles: null, coupFrancEtapesCompatibles: null, resultatCanoniqueRequis: null,
    intentionsCompatibles: ['DUEL', 'TENSION'], poidsBase: 0.3, spectaculaire: true,
    etatSortie: { medium: 'miniature', reactionTerminale: false, resolutionAssumee: false, retourTerrainInclus: true } },
  { id: 'time_ramp', source: 'preview-demo', familleRarete: 'time_ramp', declencheurs: ['micro'],
    statut: 'VALIDATED_BANC_ESSAI', nbPlansAttendu: 8, dureeMsAttendueApprox: 13150,
    rolesNarratifs: ['ACTION'],
    primitives: ['TIME_RAMP', 'FAST', 'SLOW', 'FOLLOW'], microActionsCompatibles: ['course', 'circulation', 'interception'],
    canoniquesCompatibles: null, coupFrancEtapesCompatibles: null, resultatCanoniqueRequis: null,
    intentionsCompatibles: ['ACCELERATION', 'CONSTRUCTION', 'PRESSION'], poidsBase: 0.5, spectaculaire: true,
    etatSortie: { medium: 'miniature', reactionTerminale: false, resolutionAssumee: false, retourTerrainInclus: true } }
];

// Whitelist EXPLICITE (section 9 de la consigne du 30 aout 2026) : EXISTER dans le registre ne
// signifie pas etre autorise dans le pool automatique. Aujourd'hui, les 22 entrees ont TOUTES un
// statut VALIDATED_* (aucune n'a ete factuellement identifiee comme INTERNAL/DEBUG/LEGACY lors de
// l'audit -- voir rapport, section H/I) -- cette fonction n'exclut donc rien MAINTENANT, mais
// devient la porte unique pour toute FUTURE entree qui ne serait pas encore validee.
const STATUTS_AUTORISES_POOL_AUTOMATIQUE = ['VALIDATED_PRODUCTION', 'VALIDATED_BANC_ESSAI', 'VALIDATED_A_CONFIRMER'];
function estAutoriseAutomatiquement(grammaire) {
  return STATUTS_AUTORISES_POOL_AUTOMATIQUE.includes(grammaire.statut);
}

// Candidat synthetique "RESPIRATION" (section 6 de la consigne : "le mini-terrain est la couche
// de continuite, les inserts/effets sont des ponctuations") -- PAS une grammaire visuelle, un
// troisieme type d'issue a part entiere du selecteur : "ne rien lancer, laisser le mini-terrain
// courant continuer". Seulement propose pour une situation de forme 'micro' (interrompre un coup
// franc en cours par du vide serait, lui, un vrai defaut). Poids BOOSTE dynamiquement dans
// ponderationRaccord selon l'etat de sortie precedent (reaction terminale ou spectaculaire recent).
const POIDS_RESPIRATION_BASE = 0.6;
const ID_RESPIRATION = '__respiration__';

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

function validerCompatibiliteGrammaire(grammaire, situation, intention, roleNarratifRequis) {
  // R0 (chantier "audit du catalogue visuel", 30 aout 2026) : whitelist EXPLICITE, verifiee EN
  // PREMIER -- une grammaire non VALIDATED_* n'entre jamais dans la suite du raisonnement, jamais
  // un filtre implicite ailleurs. Voir estAutoriseAutomatiquement() et le commentaire du registre.
  if (!estAutoriseAutomatiquement(grammaire)) {
    return { ok: false, motif: 'statut "' + grammaire.statut + '" non autorise dans le pool automatique (R0)' };
  }
  // R6 (chantier "montage narratif", 30 aout 2026) : filtre SUPPLEMENTAIRE, jamais un remplacement
  // des regles R1-R5 ci-dessous -- une grammaire doit d'abord passer TOUTES les regles existantes,
  // puis en plus remplir le role narratif demande par le beat courant (si l'appelant en demande
  // un ; un appel sans roleNarratifRequis, cf. usages historiques, se comporte exactement comme
  // avant ce chantier).
  if (roleNarratifRequis && !(grammaire.rolesNarratifs || []).includes(roleNarratifRequis)) {
    return { ok: false, motif: 'role narratif "' + roleNarratifRequis + '" non rempli par cette grammaire (R6)' };
  }
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

function grammairesEligibles(situation, intention, roleNarratifRequis) {
  const candidats = [];
  const rejets = [];
  REGISTRE_GRAMMAIRES_REALISATEUR.forEach(function (g) {
    const verdict = validerCompatibiliteGrammaire(g, situation, intention, roleNarratifRequis);
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
  // dernierEtatSortie (chantier "montage continu") : etatSortie de la DERNIERE grammaire reellement
  // jouee (jamais mis a jour par une respiration ou un plan null -- "rien montre" ne change pas ce
  // que le spectateur regarde encore a l'ecran). situationsDepuisSpectaculaire : compteur d'appels
  // au selecteur depuis la derniere realisation spectaculaire, Infinity tant qu'aucune n'a eu lieu.
  return { historique: [], dernierEtatSortie: null, situationsDepuisSpectaculaire: Infinity };
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

function enregistrerRealisationMemoire(memoire, grammaire, etatSortie) {
  memoire.historique.push({ id: grammaire.id, familleRarete: grammaire.familleRarete, spectaculaire: !!grammaire.spectaculaire });
  if (memoire.historique.length > PARAMETRES_RARETE_REALISATEUR.memoireTailleMax * 3) {
    memoire.historique = memoire.historique.slice(-PARAMETRES_RARETE_REALISATEUR.memoireTailleMax * 3);
  }
  memoire.dernierEtatSortie = etatSortie;
}

// =====================================================================
// 6bis. RACCORD / MONTAGE CONTINU (chantier "montage continu", 30 aout 2026)
// =====================================================================
// Ajoute apres retour utilisateur en production : le selecteur varie bien les realisations, mais
// enchaine deux realisations sans savoir ce que la precedente vient de montrer -- exactement le
// "il manque un etage entre CHOISIR et JOUER" decrit dans la consigne. Cette section n'invente
// AUCUN nouvel effet/asset : elle choisit UNIQUEMENT, parmi les grammaires deja eligibles (matrice
// LOT 4 inchangee), lesquelles constituent un enchainement acceptable compte tenu de
// `memoire.dernierEtatSortie` (calcule a partir du champ etatSortie, deja grounde dans l'audit des
// sequences reelles, section precedente).
//
// Regles de montage (jamais des regles sportives) :
//  MR1 -- spectacle -> spectacle sans respiration : si la derniere realisation etait spectaculaire
//         ET intervenue recemment (moins de PARAMETRES_RACCORD.respirationApresSpectaculaireNb
//         situations), les candidats spectaculaires sont ecartes -- SAUF si cela viderait
//         entierement la liste (jamais un blocage total, meme philosophie que LOT 6).
//  MR2 -- reaction terminale non respiree : si la derniere realisation se terminait sur un plan de
//         reaction assumee (etatSortie.reactionTerminale), la situation SUIVANTE de forme 'micro'
//         doit d'abord passer par une respiration ou une famille douce ('standard',
//         'ambiance_continue') -- les candidats spectaculaires sont ecartes (meme filet de
//         securite anti-blocage que MR1).
//  MR3 -- chaine coup-franc brute vs raccordee : si une grammaire porte
//         `deprioriserSiRaccordDisponible` et que l'id qu'elle designe est LUI AUSSI dans le pool
//         eligible courant, la variante brute est retiree (la variante raccordee, strictement
//         superieure car elle revient au terrain au lieu de couper sec sur le reset universel, est
//         seule conservee).
// Aucune regle ne bloque le tirage si elle viderait le pool -- cf. `retenus.length` teste apres
// chaque etape, jamais avant.
const PARAMETRES_RACCORD = {
  respirationApresSpectaculaireNb: 3,   // nb de situations pendant lesquelles un spectacle recent decourage un nouveau spectacle
  poidsRespirationApresReaction: POIDS_RESPIRATION_BASE * 4,
  poidsRespirationApresSpectaculaire: POIDS_RESPIRATION_BASE * 2.5
};

function appliquerReglesRaccord(candidats, dernierEtatSortie) {
  const rejetsRaccord = [];
  let retenus = candidats;

  // MR3 (avant tout : c'est une preference de CONTENU, pas de rythme -- s'applique toujours).
  const idsPresents = retenus.map(function (g) { return g.id; });
  const apresMR3 = retenus.filter(function (g) {
    if (g.deprioriserSiRaccordDisponible && idsPresents.includes(g.deprioriserSiRaccordDisponible)) {
      rejetsRaccord.push({ id: g.id, motif: 'variante raccordee "' + g.deprioriserSiRaccordDisponible + '" disponible et preferee (MR3)' });
      return false;
    }
    return true;
  });
  if (apresMR3.length) retenus = apresMR3;

  if (dernierEtatSortie) {
    // MR2 -- priorite sur MR1 (une reaction terminale est un signal plus fort qu'un simple
    // cooldown de famille spectaculaire).
    if (dernierEtatSortie.reactionTerminale) {
      const apresMR2 = retenus.filter(function (g) { return !g.spectaculaire; });
      if (apresMR2.length) {
        retenus.filter(function (g) { return g.spectaculaire; }).forEach(function (g) {
          rejetsRaccord.push({ id: g.id, motif: 'realisation precedente terminee sur une reaction assumee -- respiration attendue avant un nouveau spectacle (MR2)' });
        });
        retenus = apresMR2;
      }
    } else if (dernierEtatSortie.spectaculaireRecence != null && dernierEtatSortie.spectaculaireRecence <= PARAMETRES_RACCORD.respirationApresSpectaculaireNb) {
      const apresMR1 = retenus.filter(function (g) { return !g.spectaculaire; });
      if (apresMR1.length) {
        retenus.filter(function (g) { return g.spectaculaire; }).forEach(function (g) {
          rejetsRaccord.push({ id: g.id, motif: 'spectacle recent (il y a ' + dernierEtatSortie.spectaculaireRecence + ' situation(s)) -- pas de spectacle -> spectacle sans respiration (MR1)' });
        });
        retenus = apresMR1;
      }
    }
  }

  return { retenus: retenus, rejetsRaccord: rejetsRaccord };
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

  // Snapshot AVANT toute decision de cet appel -- c'est ce que le spectateur regarde encore a cet
  // instant (LOT "montage continu", section 9 : "etat visuel de sortie precedent").
  const dernierReel = memoire.historique[memoire.historique.length - 1] || null;
  const etatSortiePrecedent = memoire.dernierEtatSortie;
  const spectaculaireRecenceAvant = memoire.situationsDepuisSpectaculaire == null ? Infinity : memoire.situationsDepuisSpectaculaire;
  memoire.situationsDepuisSpectaculaire = spectaculaireRecenceAvant === Infinity ? Infinity : spectaculaireRecenceAvant + 1;

  const trace = {
    situation: situation, seed: seed, rejets: [], rejetsRaccord: [], candidatsPonderes: [],
    realisationPrecedente: dernierReel ? dernierReel.id : null, etatSortiePrecedent: etatSortiePrecedent
  };

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

  const roleNarratifRequis = entree.roleNarratifRequis || null;
  trace.roleNarratifRequis = roleNarratifRequis;
  const eligibilite = grammairesEligibles(situation, intention, roleNarratifRequis);
  trace.rejets = eligibilite.rejets;

  let candidats = eligibilite.candidats;
  // Repetition immediate : on la retire si une alternative existe (LOT 6, "eviter deux
  // realisations identiques successives lorsque des alternatives compatibles existent").
  if (dernierReel && candidats.length > 1) {
    const sansRepetition = candidats.filter(function (g) { return g.id !== dernierReel.id; });
    if (sansRepetition.length) candidats = sansRepetition;
  }

  // Injection de la respiration (chantier "montage continu", etendue au chantier "montage
  // narratif" du 30 aout 2026 au beat RETURN) : uniquement pour une situation de forme 'micro' --
  // interrompre un coup franc en cours par du vide serait, lui, un vrai defaut de montage. Un beat
  // demandant explicitement un role narratif AUTRE que RETURN ne doit jamais se degrader en
  // respiration (un ACTION qui ne trouve rien doit rester un ACTION manquant, pas devenir un
  // retour au calme deguise -- l'orchestrateur d'arc gere lui-meme l'absence de beat, section
  // suivante). Poids contextuel : plus fort juste apres une reaction terminale ou un spectacle
  // recent (section 6 de la consigne : "le mini-terrain est la couche de continuite").
  if (formeSituation(situation) === 'micro' && (!roleNarratifRequis || roleNarratifRequis === 'RETURN')) {
    let poidsRespiration = POIDS_RESPIRATION_BASE;
    if (etatSortiePrecedent && etatSortiePrecedent.reactionTerminale) poidsRespiration = PARAMETRES_RACCORD.poidsRespirationApresReaction;
    else if (spectaculaireRecenceAvant <= PARAMETRES_RACCORD.respirationApresSpectaculaireNb) poidsRespiration = PARAMETRES_RACCORD.poidsRespirationApresSpectaculaire;
    candidats = candidats.concat([{ id: ID_RESPIRATION, familleRarete: 'respiration', spectaculaire: false, poidsBase: poidsRespiration, primitives: ['FOLLOW'], source: 'respiration' }]);
  }

  if (!candidats.length) {
    trace.rejetGlobal = 'aucune grammaire eligible pour cette situation/intention';
    return { plan: null, trace: trace };
  }

  // Regles de raccord/montage (MR1/MR2/MR3) -- appliquees APRES la matrice de compatibilite (LOT
  // 4, jamais touchee), jamais un blocage total si elles videraient le pool.
  const raccord = appliquerReglesRaccord(candidats, { reactionTerminale: etatSortiePrecedent && etatSortiePrecedent.reactionTerminale, spectaculaireRecence: spectaculaireRecenceAvant });
  trace.rejetsRaccord = raccord.rejetsRaccord;
  candidats = raccord.retenus;

  if (!candidats.length) {
    trace.rejetGlobal = 'aucune grammaire eligible apres application des regles de raccord';
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

  if (choisi.id === ID_RESPIRATION) {
    // Respiration : rien de nouveau montre -- ne touche NI memoire.historique (pas une grammaire a
    // rarefier) NI memoire.dernierEtatSortie (le spectateur regarde toujours la meme chose).
    trace.etatSortieChoisi = 'respiration (mini-terrain courant inchange)';
    const plan = {
      intention: intention, intensity: intensite, selectedGrammar: ID_RESPIRATION, isRespiration: true,
      primitives: ['FOLLOW'], source: 'respiration', familleRarete: 'respiration', spectaculaire: false,
      insert: null, reaction: null, returnMode: 'respiration-miniature'
    };
    return { plan: plan, trace: trace };
  }

  enregistrerRealisationMemoire(memoire, choisi, choisi.etatSortie);
  if (choisi.spectaculaire) memoire.situationsDepuisSpectaculaire = 0;
  trace.etatSortieChoisi = choisi.etatSortie;

  const plan = {
    intention: intention,
    intensity: intensite,
    selectedGrammar: choisi.id,
    primitives: choisi.primitives.slice(),
    source: choisi.source,
    familleRarete: choisi.familleRarete,
    spectaculaire: !!choisi.spectaculaire,
    etatSortie: choisi.etatSortie,
    insert: situation.canonique ? 'canonique-existant' : null,
    reaction: (intention === 'EXPLOSION' || intention === 'REACTION') ? 'reaction-generique' : null,
    returnMode: 'retour-mini-terrain-standard'
  };
  return { plan: plan, trace: trace };
}

// =====================================================================
// 7bis. MONTAGE NARRATIF (chantier "du jukebox a la narration", 30 aout 2026)
// =====================================================================
// Reponse au constat de Fred : le selecteur (section 7) choisit deja correctement des
// realisations COMPLETES (audit du catalogue, 30 aout), mais s'enchaine encore comme un jukebox
// d'effets independants -- rien ne represente "la situation en train d'etre racontee". Cette
// section ajoute l'etage manquant SANS reecrire le selecteur ni le raccord : elle les appelle,
// UNE FOIS PAR BEAT, avec un filtre de role supplementaire (R6, section 4). D-E-F (famille
// COUP_FRANC) n'est PAS reecrit en beats : c'est deja une unite narrative complete et validee
// (chaine ou etapes individuelles), simplement etiquetee et passee telle quelle (voir
// construireArcNarratif ci-dessous, branche COUP_FRANC).
//
// 6 ROLES DE BEAT (section 6 de la consigne) -- jamais tous obligatoires dans un arc.
const ROLES_NARRATIFS = ['SETUP', 'ACTION', 'CLIMAX', 'RESOLUTION', 'REACTION', 'RETURN'];

// 6 FAMILLES V1 MAXIMUM (section 7 de la consigne).
const FAMILLES_NARRATIVES = [
  'CONSTRUCTION_ATTAQUE', 'DUEL_RECUPERATION', 'OCCASION_TIR',
  'COUP_FRANC', 'EVENEMENT_CANONIQUE', 'RESPIRATION_AMBIANCE'
];

// Classification par micro-action (groundee sur CATALOGUE_MICRO_ACTIONS, jamais une nouvelle
// donnee de situation). 'remise' et 'degagement' rejoignent RESPIRATION_AMBIANCE : ce sont par
// nature de tres courtes remises en jeu (section 3 de la consigne, exemple explicite "remise en
// jeu -> 2 a 4s -> retour"), pas des situations construites.
const MAPPING_FAMILLE_PAR_MICRO_ACTION = {
  circulation: 'RESPIRATION_AMBIANCE', touche: 'RESPIRATION_AMBIANCE', sortie: 'RESPIRATION_AMBIANCE',
  remise: 'RESPIRATION_AMBIANCE', degagement: 'RESPIRATION_AMBIANCE',
  course: 'CONSTRUCTION_ATTAQUE',
  duel: 'DUEL_RECUPERATION', interception: 'DUEL_RECUPERATION',
  centre: 'OCCASION_TIR', frappe: 'OCCASION_TIR', arret: 'OCCASION_TIR'
};

// Situation deja connue (jamais le futur) -> famille. coupFrancEtape et canonique priment
// toujours sur microAction (une situation ne porte jamais les deux a la fois en pratique, cf.
// formeSituation, mais l'ordre de test reste explicite et sans ambiguite).
function classifierFamilleNarrative(situation) {
  if (situation.coupFrancEtape) return 'COUP_FRANC';
  if (situation.canonique) return 'EVENEMENT_CANONIQUE';
  if (situation.microAction) return MAPPING_FAMILLE_PAR_MICRO_ACTION[situation.microAction] || 'RESPIRATION_AMBIANCE';
  return 'RESPIRATION_AMBIANCE';
}

// Formes d'arc possibles par famille (poids de PROTOTYPE, ajustables sans toucher au reste --
// section 22, "minimum d'abstraction necessaire"). COUP_FRANC et EVENEMENT_CANONIQUE-carton/
// blessure n'ont PAS de table : ce sont des passe-plats directs (voir construireArcNarratif).
// EVENEMENT_CANONIQUE (bare, hors coup franc : but en jeu ouvert/occasion/debut/mitemps/fin)
// garde un arc [RETURN] uniquement -- aucune grammaire du registre ne couvre aujourd'hui les
// situations canoniques nues (audit du 30 aout : "gere par afficherInsertCanonique, hors
// perimetre du selecteur"), donc ce beat se resoudra honnetement a `plan:null` -- jamais un but/
// carton/blessure invente pour "faire joli" (section 4, regle fondamentale).
const ARCS_PAR_FAMILLE = {
  RESPIRATION_AMBIANCE: [
    { beats: ['RETURN'], poids: 1 }
  ],
  CONSTRUCTION_ATTAQUE: [
    { beats: ['ACTION', 'RETURN'], poids: 3 },
    { beats: ['SETUP', 'ACTION', 'RETURN'], poids: 1 }
  ],
  DUEL_RECUPERATION: [
    { beats: ['ACTION', 'RETURN'], poids: 3 },
    { beats: ['SETUP', 'ACTION', 'RESOLUTION', 'RETURN'], poids: 1 }
  ],
  OCCASION_TIR: [
    { beats: ['ACTION', 'RESOLUTION', 'RETURN'], poids: 2 },
    { beats: ['SETUP', 'ACTION', 'CLIMAX', 'RESOLUTION', 'RETURN'], poids: 1 },
    { beats: ['SETUP', 'ACTION', 'CLIMAX', 'RESOLUTION', 'REACTION', 'RETURN'], poids: 0.4 }
  ],
  EVENEMENT_CANONIQUE: [
    { beats: ['RETURN'], poids: 1 }
  ]
};

// Poids d'une forme d'arc pondere par l'intensite (jamais le futur, memes signaux que
// calculerIntensiteRealisation) : favorise les arcs courts a faible intensite, les arcs longs a
// forte intensite, neutre entre les deux -- heuristique de PROTOTYPE explicitement documentee
// comme telle (section 22), pas un equilibrage definitif.
function poidsArcSelonIntensite(forme, intensite) {
  const n = forme.beats.length;
  if (n <= 2) return forme.poids * (1.4 - 0.6 * intensite);
  if (n >= 5) return forme.poids * (0.3 + 1.2 * intensite);
  return forme.poids;
}

function choisirFormeArc(famille, intensite, rng) {
  const formes = ARCS_PAR_FAMILLE[famille];
  if (!formes || !formes.length) return null;
  const pondere = formes.map(function (f) { return { f: f, poids: Math.max(0.001, poidsArcSelonIntensite(f, intensite)) }; });
  const total = pondere.reduce(function (s, p) { return s + p.poids; }, 0);
  let r = rng() * total, choisi = pondere[pondere.length - 1].f;
  for (let i = 0; i < pondere.length; i++) { r -= pondere[i].poids; if (r <= 0) { choisi = pondere[i].f; break; } }
  return choisi;
}

// Extrait une duree approximative NUMERIQUE de dureeMsAttendueApprox (nombre fixe, ou chaine
// "900-1400 (variable)" pour les gabarits a duree aleatoire -- on retient alors la borne basse,
// jamais une invention) -- usage OBSERVABILITE/orchestration du retour a l'etat normal, jamais
// une donnee lue par la choregraphie reelle.
function dureeApproxDepuisRegistre(idGrammaire) {
  const g = REGISTRE_GRAMMAIRES_REALISATEUR.find(function (x) { return x.id === idGrammaire; });
  if (!g) return 0;
  if (typeof g.dureeMsAttendueApprox === 'number') return g.dureeMsAttendueApprox;
  const m = /\d+/.exec(String(g.dureeMsAttendueApprox));
  return m ? parseInt(m[0], 10) : 0;
}
const DUREE_DEFAUT_RESPIRATION_MS = 400; // simple continuite du mini-terrain, jamais un nouveau plan

// Construit un ARC NARRATIF complet pour UNE situation : famille -> forme d'arc -> un appel a
// selectionnerRealisation PAR BEAT (memoire partagee, donc rarete/raccord/MR1-MR3 continuent de
// s'appliquer NORMALEMENT y compris ENTRE deux beats du meme arc -- jamais un passe-droit interne
// a l'arc). Un beat dont l'appel renvoie `plan:null` (role non disponible pour cette situation,
// cf. LOT 11 "plan impossible", cas legitime) est simplement OMIS de la sequence jouable -- jamais
// un blocage de l'arc entier (section 20, "absence d'acteur/de brique ne bloque jamais").
// Entree : { situation, seed, memoire }. Sortie : { arcPlan, trace } -- arcPlan.beats est la liste
// des beats REELLEMENT jouables (plan non-null), dans l'ordre ; trace.beatsPrevus conserve la
// liste THEORIQUE complete (y compris les beats tombes a plan:null) pour l'observabilite (LOT 18).
function construireArcNarratif(entree) {
  const situation = entree.situation;
  const memoire = entree.memoire || creerMemoireRealisateur();
  const seedBase = entree.seed != null ? String(entree.seed) : String(Math.random());
  const rng = creerPRNGDeterministeRia(hashChaineVersUint32Ria('arc-narratif-' + seedBase));

  const famille = classifierFamilleNarrative(situation);
  const intensite = calculerIntensiteRealisation({
    microAction: situation.microAction, canoniqueType: situation.canonique && situation.canonique.type,
    coupFrancEtape: situation.coupFrancEtape, pressionRecente: situation.pressionRecente,
    ecartScore: situation.ecartScore, minute: situation.minute
  });

  const trace = { situation: situation, famille: famille, intensite: intensite, seed: seedBase, beatsPrevus: [] };

  // COUP_FRANC : PASSE-PLAT DIRECT -- D-E-F (etapes individuelles ou chaines/raccords deja
  // composes) est une unite narrative complete et validee, jamais reecrite en beats generiques
  // (consigne section 9/10 : "ne pas rejouer D-E-F s'il fonctionne"). Un seul appel, identique a
  // avant ce chantier.
  if (famille === 'COUP_FRANC') {
    const resultat = selectionnerRealisation({ situation: situation, seed: seedBase, memoire: memoire });
    trace.beatsPrevus.push({ role: 'COUP_FRANC_UNITE', plan: resultat.plan, sousTrace: resultat.trace });
    const beats = resultat.plan ? [{ role: 'COUP_FRANC_UNITE', plan: resultat.plan }] : [];
    return {
      arcPlan: {
        famille: famille, arc: ['COUP_FRANC_UNITE'], beats: beats,
        dureeMsTotaleApprox: resultat.plan ? dureeApproxDepuisRegistre(resultat.plan.selectedGrammar) : 0
      },
      trace: trace
    };
  }

  const formeArc = choisirFormeArc(famille, intensite, rng);
  trace.arcChoisi = formeArc ? formeArc.beats.slice() : null;
  if (!formeArc) {
    trace.rejetGlobal = 'aucune forme d\'arc definie pour la famille "' + famille + '"';
    return { arcPlan: { famille: famille, arc: [], beats: [], dureeMsTotaleApprox: 0 }, trace: trace };
  }

  const beatsJouables = [];
  let dureeMsTotaleApprox = 0;
  formeArc.beats.forEach(function (role, idx) {
    const seedBeat = seedBase + '-beat' + idx + '-' + role;
    const resultatBeat = selectionnerRealisation({ situation: situation, seed: seedBeat, memoire: memoire, roleNarratifRequis: role });
    trace.beatsPrevus.push({ role: role, plan: resultatBeat.plan, sousTrace: resultatBeat.trace });
    if (resultatBeat.plan) {
      beatsJouables.push({ role: role, plan: resultatBeat.plan });
      dureeMsTotaleApprox += resultatBeat.plan.isRespiration ? DUREE_DEFAUT_RESPIRATION_MS : dureeApproxDepuisRegistre(resultatBeat.plan.selectedGrammar);
    }
    // beat sans plan : omis de beatsJouables, conserve dans trace.beatsPrevus (LOT 18,
    // "raison d'un fallback eventuel" -- resultatBeat.trace.rejetGlobal/rejets porte le motif).
  });

  return {
    arcPlan: { famille: famille, arc: formeArc.beats.slice(), beats: beatsJouables, dureeMsTotaleApprox: dureeMsTotaleApprox },
    trace: trace
  };
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
  PARAMETRES_RACCORD: PARAMETRES_RACCORD,
  ID_RESPIRATION: ID_RESPIRATION,
  intentionsAutoriseesPourSituation: intentionsAutoriseesPourSituation,
  formeSituation: formeSituation,
  validerCompatibiliteGrammaire: validerCompatibiliteGrammaire,
  grammairesEligibles: grammairesEligibles,
  estAutoriseAutomatiquement: estAutoriseAutomatiquement,
  STATUTS_AUTORISES_POOL_AUTOMATIQUE: STATUTS_AUTORISES_POOL_AUTOMATIQUE,
  appliquerReglesRaccord: appliquerReglesRaccord,
  calculerIntensiteRealisation: calculerIntensiteRealisation,
  creerMemoireRealisateur: creerMemoireRealisateur,
  ponderationRarete: ponderationRarete,
  enregistrerRealisationMemoire: enregistrerRealisationMemoire,
  selectionnerRealisation: selectionnerRealisation,
  ROLES_NARRATIFS: ROLES_NARRATIFS,
  FAMILLES_NARRATIVES: FAMILLES_NARRATIVES,
  MAPPING_FAMILLE_PAR_MICRO_ACTION: MAPPING_FAMILLE_PAR_MICRO_ACTION,
  ARCS_PAR_FAMILLE: ARCS_PAR_FAMILLE,
  classifierFamilleNarrative: classifierFamilleNarrative,
  choisirFormeArc: choisirFormeArc,
  dureeApproxDepuisRegistre: dureeApproxDepuisRegistre,
  construireArcNarratif: construireArcNarratif,
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
