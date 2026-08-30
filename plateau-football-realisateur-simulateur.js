// =====================================================================
// REALISATEUR — SIMULATEUR HEADLESS (LOTS 10/11/12/13/20/23, chantier "industrialisation du
// realisateur", nuit du 30 aout 2026)
// =====================================================================
// OUTIL DE DEVELOPPEMENT, jamais charge par plateau.html ni execute en production. Sert
// exclusivement a tester le SELECTEUR de plateau-football-realisateur-ia.js sans attendre 30
// minutes reelles et sans navigateur -- il ne teste QUE la logique de selection (candidats,
// rejets, rarete, intensite), jamais le rendu visuel (aucune inspection visuelle n'est possible
// depuis ce script, voir RAPPORT final section M pour ce qui a et n'a pas ete verifie
// visuellement).
//
// Genere des matchs SYNTHETIQUES (jamais le vrai moteur canonique, jamais Supabase, jamais
// championnat.data) et fait tourner le vrai selecteur dessus. Executable :
//   node plateau-football-realisateur-simulateur.js [--matchs=1000] [--seed=campagne-1] [--json]
//
// Aucune dependance a Node specifique au-dela de require() -- charge uniquement
// plateau-football-realisateur-ia.js (module pur, sans DOM).
'use strict';
const RealisateurIA = require('./plateau-football-realisateur-ia.js');

// ---------------------------------------------------------------------
// 1. GENERATION DE MATCHS SYNTHETIQUES (LOT 10)
// ---------------------------------------------------------------------
// Chaque profil produit une timeline de "situations" (meme forme que celles construites par
// l'appelant reel : microAction / canonique / coupFrancEtape+coupFrancResultat). Le RNG utilise
// est le MEME PRNG deterministe que le selecteur (mulberry32), seede par match -- reproductible.
const MICRO_ACTIONS_CALMES = ['circulation', 'degagement', 'sortie', 'touche', 'remise'];
const MICRO_ACTIONS_VIVES = ['duel', 'interception', 'course', 'centre', 'frappe'];
const TOUTES_MICRO_ACTIONS = MICRO_ACTIONS_CALMES.concat(MICRO_ACTIONS_VIVES);

function piocher(rng, liste) { return liste[Math.floor(rng() * liste.length)]; }

function situationMicroAction(rng, minute, cote, ecartScore, pressionRecente) {
  return {
    microAction: piocher(rng, TOUTES_MICRO_ACTIONS.length ? TOUTES_MICRO_ACTIONS : ['circulation']),
    cote: cote, minute: minute, ecartScore: ecartScore, pressionRecente: pressionRecente
  };
}

// Chaine coup franc D-E-F1/F2 : jamais de coupFrancResultat sur les etapes tension/trajectoire
// (le moteur canonique ne s'est pas encore prononce a ce moment -- meme garantie que le vrai
// code, cf. cartographie section 9), UNIQUEMENT sur l'etape "arret"/"but" elle-meme et les
// situations qui suivent.
function situationsCoupFranc(minuteBase, resultat) {
  return [
    { coupFrancEtape: 'tension', minute: minuteBase },
    { coupFrancEtape: 'trajectoire', minute: minuteBase },
    { coupFrancEtape: resultat, coupFrancResultat: resultat, minute: minuteBase }
  ];
}

// `nonDecisionnelle` (correctif du 30 aout 2026, cf. commentaire du registre sur `declencheurs`) :
// un evenement canonique NU (but en jeu ouvert, occasion, debut/mitemps/reprise/fin) n'est PAS
// aujourd'hui mis en scene par le selecteur decoratif -- il est deja affiche par
// afficherInsertCanonique/afficherAmbiancePhase (mecanisme existant, non touche par ce chantier,
// hors champ du registre de grammaires). Le simulateur ne l'envoie donc PAS au selecteur (ce
// serait tester un cas que l'integration reelle ne presente jamais), sauf carton/blessure,
// envoyes eux VOLONTAIREMENT en test adversarial (LOT 12) pour verifier a grande echelle que la
// regle R1 tient meme sous sollicitation repetee.
function situationCanonique(type, minute, joueur) {
  const adversarial = (type === 'carton' || type === 'blessure');
  return { canonique: { type: type, joueur: joueur || null }, minute: minute, nonDecisionnelle: !adversarial };
}

// Genere une timeline complete pour un profil de match donne. `nbSituations` approx. le nombre
// d'instants narratifs d'un vrai match (cf. cartographie : ~1 micro-action toutes les ~13-20s sur
// 20 min utiles => grossierement 60 a 100 instants, ordre de grandeur choisi ici pour rester
// rapide en campagne massive sans etre irrealiste).
function genererMatchSynthetique(profil, rng) {
  const situations = [];
  situations.push(situationCanonique('debut', 0));
  const nbInstantsMt1 = 30, nbInstantsMt2 = 30;
  let ecartScore = 0;

  function remplirPhase(nbInstants, minuteDebut) {
    let pression = 0;
    for (let i = 0; i < nbInstants; i++) {
      const minute = minuteDebut + i;
      const cote = rng() < 0.5 ? 'home' : 'away';
      switch (profil) {
        case 'calme':
          pression = 0;
          situations.push(situationMicroActionParmi(rng, minute, cote, ecartScore, pression, MICRO_ACTIONS_CALMES));
          break;
        case 'longue_periode_sans_evenement':
          pression = 0;
          situations.push(situationMicroActionParmi(rng, minute, cote, ecartScore, pression, MICRO_ACTIONS_CALMES.concat(['interception'])));
          break;
        case 'pression':
          pression = Math.min(3, pression + 1);
          situations.push(situationMicroActionParmi(rng, minute, cote, ecartScore, pression, MICRO_ACTIONS_VIVES));
          break;
        case 'riche':
        case 'plusieurs_buts':
        case 'avec_but':
        case 'zero_zero':
        case 'arret':
        case 'coup_franc_arrete':
        case 'coup_franc_but':
        default:
          pression = rng() < 0.4 ? Math.min(3, pression + 1) : Math.max(0, pression - 1);
          situations.push(situationMicroActionParmi(rng, minute, cote, ecartScore, pression, TOUTES_MICRO_ACTIONS));
          if (rng() < 0.08) situations.push(situationCanonique('occasion', minute, null));
          if (rng() < 0.015) situations.push(situationCanonique('carton', minute, 'Joueur Test'));
          if (rng() < 0.008) situations.push(situationCanonique('blessure', minute, 'Joueur Test'));
          break;
      }
    }
  }

  remplirPhase(nbInstantsMt1, 5);
  situations.push(situationCanonique('mitemps', 25));

  // Insertion d'evenements canoniques specifiques au profil, au milieu de la 2e mi-temps.
  if (profil === 'avec_but') {
    situations.push(situationCanonique('but', 33, null));
    ecartScore = 1;
  } else if (profil === 'plusieurs_buts') {
    situations.push(situationCanonique('but', 32, null)); ecartScore = 1;
  }
  if (profil === 'arret' || profil === 'coup_franc_arrete') {
    situationsCoupFranc(34, 'arret').forEach(function (s) { situations.push(s); });
  }
  if (profil === 'coup_franc_but') {
    situationsCoupFranc(34, 'but').forEach(function (s) { situations.push(s); });
    ecartScore = 1;
  }

  remplirPhase(nbInstantsMt2, 35);

  if (profil === 'plusieurs_buts') {
    situations.push(situationCanonique('but', 55, null)); ecartScore = 2;
    situationsCoupFranc(60, 'but').forEach(function (s) { situations.push(s); }); ecartScore = 3;
    situations.push(situationCanonique('but', 65, null)); ecartScore = 4;
  }

  situations.push(situationCanonique('fin', 70));
  return situations;
}

function situationMicroActionParmi(rng, minute, cote, ecartScore, pression, liste) {
  return { microAction: piocher(rng, liste), cote: cote, minute: minute, ecartScore: ecartScore, pressionRecente: pression };
}

const PROFILS_MATCH_SYNTHETIQUE = [
  'calme', 'riche', 'zero_zero', 'avec_but', 'plusieurs_buts',
  'arret', 'coup_franc_arrete', 'coup_franc_but', 'pression', 'longue_periode_sans_evenement'
];

// ---------------------------------------------------------------------
// 2. MODE HEADLESS : execute un match synthetique a travers le VRAI selecteur (LOT 11)
// ---------------------------------------------------------------------
function jouerMatchHeadless(profil, seedMatch) {
  const rngGeneration = RealisateurIA.creerPRNGDeterministeRia(RealisateurIA.hashChaineVersUint32Ria('gen-' + seedMatch));
  const situations = genererMatchSynthetique(profil, rngGeneration);
  const memoire = RealisateurIA.creerMemoireRealisateur();

  const resultatMatch = {
    profil: profil, seedMatch: seedMatch, situations: 0, evenementsCanoniquesObserves: 0,
    plans: 0, respirations: 0, plansImpossibles: 0, rejetsCarton: 0,
    parFamille: {}, parPrimitive: {}, parIntensiteBucket: { basse: 0, moyenne: 0, haute: 0 },
    effetsValides: { drone_dive_impact_freeze: 0, freeze_follow_ball: 0, orbit_freeze: 0, time_ramp: 0 },
    repetitionsImmediates: 0, repetitionsFenetreCourte: 0,
    violationsCanoniques: [], violationsRaccord: [],
    dernierId: null, historiqueCourt: []
  };

  // Re-controle INDEPENDANT des regles de raccord (memes principes que les violations canoniques
  // ci-dessous : ne fait jamais confiance a la propre comptabilite du selecteur). idxDernierSpectaculaire
  // et attenteRespirationApresReaction sont recalcules ici a partir des PLANS REELLEMENT choisis
  // (jamais a partir de memoire.situationsDepuisSpectaculaire, pour detecter un bug du selecteur et
  // non le confirmer aveuglement).
  let idxDernierSpectaculaire = -Infinity;
  let attenteRespirationApresReaction = false;

  situations.forEach(function (situation, idx) {
    // Evenement canonique nu (but en jeu ouvert, occasion, debut/mitemps/reprise/fin) : deja pris
    // en charge par afficherInsertCanonique/afficherAmbiancePhase (existant, hors perimetre) --
    // jamais envoye au selecteur, seulement comptabilise (cf. commentaire de situationCanonique).
    if (situation.nonDecisionnelle) { resultatMatch.evenementsCanoniquesObserves++; return; }

    resultatMatch.situations++;
    const seed = seedMatch + '-' + idx;
    const { plan, trace } = RealisateurIA.selectionnerRealisation({ situation: situation, seed: seed, memoire: memoire });

    if (plan && plan.isRespiration) {
      resultatMatch.plans++;
      resultatMatch.respirations++;
      attenteRespirationApresReaction = false; // la respiration EST la pause attendue
      return;
    }

    // VERIFICATION INDEPENDANTE anti-violation canonique (LOT 12) : re-controle, en dehors du
    // selecteur lui-meme, que le plan choisi respecte les regles dures -- detecte un futur bug
    // du selecteur plutot que de lui faire confiance aveuglement.
    if (plan) {
      const g = RealisateurIA.REGISTRE_GRAMMAIRES_REALISATEUR.find(function (x) { return x.id === plan.selectedGrammar; });
      if (!g) {
        resultatMatch.violationsCanoniques.push({ idx: idx, motif: 'grammaire choisie introuvable dans le registre : ' + plan.selectedGrammar });
      } else {
        if (g.resultatCanoniqueRequis) {
          const resolu = situation.coupFrancResultat || (situation.canonique && situation.canonique.type === 'but' ? 'but' : null);
          if (resolu !== g.resultatCanoniqueRequis) {
            resultatMatch.violationsCanoniques.push({ idx: idx, motif: 'grammaire "' + g.id + '" choisie sans resultat canonique confirme' });
          }
        }
        if (situation.canonique && (situation.canonique.type === 'carton' || situation.canonique.type === 'blessure')) {
          resultatMatch.violationsCanoniques.push({ idx: idx, motif: 'plan non-null sur un carton/blessure' });
        }
        // MR1 re-controle : spectacle -> spectacle sans respiration suffisante.
        if (g.spectaculaire && (idx - idxDernierSpectaculaire) <= RealisateurIA.PARAMETRES_RACCORD.respirationApresSpectaculaireNb) {
          resultatMatch.violationsRaccord.push({ idx: idx, motif: 'spectacle "' + g.id + '" choisi ' + (idx - idxDernierSpectaculaire) + ' situation(s) apres un spectacle precedent, sans respiration (MR1)' });
        }
        // MR2 re-controle : spectacle choisi juste apres une reaction terminale non respiree.
        if (g.spectaculaire && attenteRespirationApresReaction) {
          resultatMatch.violationsRaccord.push({ idx: idx, motif: 'spectacle "' + g.id + '" choisi immediatement apres une reaction terminale, sans respiration (MR2)' });
        }
        // MR3 re-controle : chaine brute choisie alors que sa variante raccordee etait eligible.
        if (g.deprioriserSiRaccordDisponible) {
          const eligibiliteMR3 = RealisateurIA.grammairesEligibles(situation, plan.intention).candidats;
          if (eligibiliteMR3.some(function (c) { return c.id === g.deprioriserSiRaccordDisponible; })) {
            resultatMatch.violationsRaccord.push({ idx: idx, motif: 'chaine brute "' + g.id + '" choisie alors que "' + g.deprioriserSiRaccordDisponible + '" etait eligible (MR3)' });
          }
        }
        if (g.spectaculaire) idxDernierSpectaculaire = idx;
        attenteRespirationApresReaction = !!(g.etatSortie && g.etatSortie.reactionTerminale);
      }
      resultatMatch.plans++;
      if (plan.spectaculaire) resultatMatch.spectaculaires = (resultatMatch.spectaculaires || 0) + 1;
      resultatMatch.parFamille[plan.familleRarete] = (resultatMatch.parFamille[plan.familleRarete] || 0) + 1;
      plan.primitives.forEach(function (p) { resultatMatch.parPrimitive[p] = (resultatMatch.parPrimitive[p] || 0) + 1; });
      if (resultatMatch.effetsValides.hasOwnProperty(plan.selectedGrammar)) resultatMatch.effetsValides[plan.selectedGrammar]++;
      if (plan.intensity < 0.34) resultatMatch.parIntensiteBucket.basse++;
      else if (plan.intensity < 0.67) resultatMatch.parIntensiteBucket.moyenne++;
      else resultatMatch.parIntensiteBucket.haute++;

      if (resultatMatch.dernierId === plan.selectedGrammar) resultatMatch.repetitionsImmediates++;
      if (resultatMatch.historiqueCourt.indexOf(plan.selectedGrammar) !== -1) resultatMatch.repetitionsFenetreCourte++;
      resultatMatch.historiqueCourt.push(plan.selectedGrammar);
      if (resultatMatch.historiqueCourt.length > RealisateurIA.PARAMETRES_RARETE_REALISATEUR.memoireTailleMax) resultatMatch.historiqueCourt.shift();
      resultatMatch.dernierId = plan.selectedGrammar;
    } else {
      if (trace.rejetGlobal && trace.rejetGlobal.indexOf('carton/blessure') === 0) resultatMatch.rejetsCarton++;
      else resultatMatch.plansImpossibles++;
    }
  });

  return resultatMatch;
}

// ---------------------------------------------------------------------
// 2bis. MODE HEADLESS NARRATIF (chantier "du jukebox a la narration", 30 aout 2026, section 21)
// ---------------------------------------------------------------------
// Meme generation de matchs synthetiques que jouerMatchHeadless (genererMatchSynthetique,
// INCHANGEE) mais route chaque situation decisionnelle par construireArcNarratif au lieu de
// selectionnerRealisation seul -- mesure les FAMILLES/ARCS/BEATS, pas seulement les grammaires
// individuelles. "Temps mini-terrain" vs "temps sequence" est une ESTIMATION (aucun timer reel en
// mode headless) : une situation dont l'arc ne joue QUE de la respiration (ou aucun beat) est
// comptee comme du temps mini-terrain (TEMPS_MINITERRAIN_BASE_MS, moyenne grossiere des durees
// reelles de CATALOGUE_MICRO_ACTIONS, 1100-2600ms) ; une situation dont l'arc joue au moins un
// beat visuel reel est comptee pour son dureeMsTotaleApprox (LOT 18).
const TEMPS_MINITERRAIN_BASE_MS = 1800;

function jouerMatchNarratifHeadless(profil, seedMatch) {
  const rngGeneration = RealisateurIA.creerPRNGDeterministeRia(RealisateurIA.hashChaineVersUint32Ria('gen-' + seedMatch));
  const situations = genererMatchSynthetique(profil, rngGeneration);
  const memoire = RealisateurIA.creerMemoireRealisateur();

  const resultat = {
    profil: profil, seedMatch: seedMatch, situations: 0, evenementsCanoniquesObserves: 0,
    sequencesNarratives: 0, situationsSansBeat: 0, situationsImpossibles: 0,
    tempsMiniTerrainMs: 0, tempsSequencesMs: 0, tempsMsParFamille: {},
    tempsEcranMiniTerrainMs: 0, tempsEcranCoupureMs: 0,
    parFamille: {}, parLongueurArc: {}, beatsSpectaculaires: 0, beatsTotal: 0,
    violationsCanoniques: [], violationsWhitelist: [],
    repetitionsImmediatesGrammaire: [], dernierIdJoue: null,
    grammairesVuesZeroZero: {}
  };

  // IMPORTANT (trouve par diagnostic AVANT toute correction, jamais suppose) : le compteur interne
  // du selecteur (memoire.situationsDepuisSpectaculaire, MR1) avance de UN PAR APPEL A
  // selectionnerRealisation -- soit UN PAR BEAT TENTE (trace.beatsPrevus.length), PAS un par
  // situation exterieure. Un arc a 5 beats consomme 5 "ticks" internes en une seule situation. Un
  // premier re-controle base sur l'index de situation (comme dans jouerMatchHeadless, correct
  // LA-BAS car 1 situation = 1 appel) produisait ici ~130 "violations" sur 20 matchs des qu'un arc
  // multi-beats etait implique -- verifie manuellement (node -e, memoire.situationsDepuisSpectaculaire
  // observe apres chaque arc) : le selecteur respectait deja correctement son propre compteur
  // interne, c'etait le RE-CONTROLE qui mesurait la mauvaise unite. Corrige en faisant avancer
  // compteurTicks du meme pas que le vrai compteur (trace.beatsPrevus.length), jamais de l'index de
  // situation.
  let compteurTicks = 0;
  let tickDernierSpectaculaire = -Infinity;

  situations.forEach(function (situation, idx) {
    if (situation.nonDecisionnelle) { resultat.evenementsCanoniquesObserves++; return; }
    resultat.situations++;

    const { arcPlan, trace } = RealisateurIA.construireArcNarratif({ situation: situation, seed: seedMatch + '-arc-' + idx, memoire: memoire });
    resultat.parFamille[trace.famille] = (resultat.parFamille[trace.famille] || 0) + 1;
    const tickDebutSituation = compteurTicks;
    compteurTicks += trace.beatsPrevus.length;

    const longueur = arcPlan.beats.length;
    resultat.parLongueurArc[longueur] = (resultat.parLongueurArc[longueur] || 0) + 1;

    if (longueur === 0) {
      resultat.situationsSansBeat++;
      // EVENEMENT_CANONIQUE nu (but/occasion/carton/blessure/debut/mitemps/fin) : arc vide ATTENDU
      // (aucune grammaire ne couvre ces situations, cf. audit du 30 aout) -- jamais compte comme
      // "impossible", c'est le comportement CORRECT et voulu (section 4 : rien invente).
      if (trace.famille !== 'EVENEMENT_CANONIQUE') resultat.situationsImpossibles++;
      resultat.tempsMiniTerrainMs += TEMPS_MINITERRAIN_BASE_MS;
      resultat.tempsEcranMiniTerrainMs += TEMPS_MINITERRAIN_BASE_MS;
      return;
    }

    const seulementRespiration = arcPlan.beats.every(function (b) { return b.plan.isRespiration; });
    if (seulementRespiration) {
      resultat.tempsMiniTerrainMs += TEMPS_MINITERRAIN_BASE_MS;
      resultat.tempsEcranMiniTerrainMs += TEMPS_MINITERRAIN_BASE_MS;
      return;
    }

    resultat.sequencesNarratives++;
    resultat.tempsSequencesMs += arcPlan.dureeMsTotaleApprox;
    // Ventilation du temps sequence PAR FAMILLE (LOT 21) : necessaire pour comprendre QUI pese
    // dans la proportion globale mini-terrain/sequences -- une moyenne unique masquerait que
    // COUP_FRANC (D-E-F, durees deja validees et volontairement NON touchees) pese tres lourd a
    // lui seul par rapport a sa frequence (voir rapport, section 14).
    resultat.tempsMsParFamille[trace.famille] = (resultat.tempsMsParFamille[trace.famille] || 0) + arcPlan.dureeMsTotaleApprox;

    // METRIQUE PLUS FIDELE (ajoutee apres diagnostic : la premiere version comptait
    // match_miniature_v2 et les 4 effets camera-only comme "hors mini-terrain" alors qu'ils
    // restent VISUELLEMENT sur la camera CSS du terrain, cf. etatSortie.medium -- seul un beat
    // dont le medium N'EST PAS 'miniature' (illustre_image/illustre_pictogram/illustre_video)
    // fait reellement quitter l'ecran du mini-terrain, section 12 de la consigne).
    arcPlan.beats.forEach(function (b) {
      const dureeBeat = b.plan.isRespiration ? RealisateurIA.DUREE_DEFAUT_RESPIRATION_MS : RealisateurIA.dureeApproxDepuisRegistre(b.plan.selectedGrammar);
      const g = RealisateurIA.REGISTRE_GRAMMAIRES_REALISATEUR.find(function (x) { return x.id === b.plan.selectedGrammar; });
      const medium = b.plan.isRespiration ? 'miniature' : (g && g.etatSortie ? g.etatSortie.medium : 'inconnu');
      if (medium === 'miniature') resultat.tempsEcranMiniTerrainMs += dureeBeat;
      else resultat.tempsEcranCoupureMs += dureeBeat;
    });

    if (profil === 'zero_zero') {
      arcPlan.beats.forEach(function (b) { resultat.grammairesVuesZeroZero[b.plan.selectedGrammar] = true; });
    }

    // Parcourt trace.beatsPrevus (TOUS les appels tentes, y compris les beats retombes a
    // plan:null) plutot que arcPlan.beats (seulement les jouables) : c'est la SEULE facon de
    // retrouver le tick exact de chaque appel reel a selectionnerRealisation (position i dans ce
    // tableau = tickDebutSituation + i), condition necessaire pour comparer a la bonne unite.
    trace.beatsPrevus.forEach(function (bp, i) {
      if (!bp.plan || bp.plan.isRespiration) return;
      const tick = tickDebutSituation + i;
      const b = bp;
      resultat.beatsTotal++;
      const g = RealisateurIA.REGISTRE_GRAMMAIRES_REALISATEUR.find(function (x) { return x.id === b.plan.selectedGrammar; });
      if (!g || !RealisateurIA.estAutoriseAutomatiquement(g)) {
        resultat.violationsWhitelist.push({ idx: idx, motif: 'beat "' + b.role + '" a choisi une grammaire hors whitelist : ' + b.plan.selectedGrammar });
        return;
      }
      if (g.resultatCanoniqueRequis) {
        const resolu = situation.coupFrancResultat || (situation.canonique && situation.canonique.type === 'but' ? 'but' : null);
        if (resolu !== g.resultatCanoniqueRequis) resultat.violationsCanoniques.push({ idx: idx, motif: 'beat "' + b.role + '" : "' + g.id + '" sans resultat canonique confirme' });
      }
      if (situation.canonique && (situation.canonique.type === 'carton' || situation.canonique.type === 'blessure')) {
        resultat.violationsCanoniques.push({ idx: idx, motif: 'beat non-vide sur un carton/blessure' });
      }
      if (g.spectaculaire) {
        resultat.beatsSpectaculaires++;
        if ((tick - tickDernierSpectaculaire) <= RealisateurIA.PARAMETRES_RACCORD.respirationApresSpectaculaireNb) {
          resultat.violationsWhitelist.push({ idx: idx, motif: 'MR1 : spectacle "' + g.id + '" trop rapproche du precedent (' + (tick - tickDernierSpectaculaire) + ' ticks, arc)' });
        }
        tickDernierSpectaculaire = tick;
      }
      if (resultat.dernierIdJoue === g.id) resultat.repetitionsImmediatesGrammaire.push({ idx: idx, id: g.id });
      resultat.dernierIdJoue = g.id;
    });
  });

  return resultat;
}

function executerCampagneNarrative(nbMatchs, seedBase) {
  const t0 = Date.now();
  const stats = {
    matchs: 0, situations: 0, sequencesNarratives: 0, situationsSansBeat: 0, situationsImpossibles: 0,
    tempsMiniTerrainMs: 0, tempsSequencesMs: 0, tempsMsParFamille: {},
    tempsEcranMiniTerrainMs: 0, tempsEcranCoupureMs: 0, beatsTotal: 0, beatsSpectaculaires: 0,
    parFamille: {}, parLongueurArc: {}, violationsCanoniques: [], violationsWhitelist: [],
    repetitionsImmediatesGrammaire: 0, erreurs: [], seedsNonReproductibles: [],
    diversiteZeroZero: {}
  };
  for (let m = 0; m < nbMatchs; m++) {
    const profil = PROFILS_MATCH_SYNTHETIQUE[m % PROFILS_MATCH_SYNTHETIQUE.length];
    const seedMatch = seedBase + '-m' + m + '-' + profil;
    let resultat;
    try { resultat = jouerMatchNarratifHeadless(profil, seedMatch); }
    catch (e) { stats.erreurs.push({ match: m, profil: profil, message: e.message }); continue; }

    let rejoue;
    try {
      rejoue = jouerMatchNarratifHeadless(profil, seedMatch);
      if (JSON.stringify(rejoue) !== JSON.stringify(resultat)) stats.seedsNonReproductibles.push(seedMatch);
    } catch (e) { stats.erreurs.push({ match: m, profil: profil, message: 'rejoue: ' + e.message }); }

    stats.matchs++;
    stats.situations += resultat.situations;
    stats.sequencesNarratives += resultat.sequencesNarratives;
    stats.situationsSansBeat += resultat.situationsSansBeat;
    stats.situationsImpossibles += resultat.situationsImpossibles;
    stats.tempsMiniTerrainMs += resultat.tempsMiniTerrainMs;
    stats.tempsSequencesMs += resultat.tempsSequencesMs;
    stats.tempsEcranMiniTerrainMs += resultat.tempsEcranMiniTerrainMs;
    stats.tempsEcranCoupureMs += resultat.tempsEcranCoupureMs;
    fusionnerCompteur(stats.tempsMsParFamille, resultat.tempsMsParFamille);
    stats.beatsTotal += resultat.beatsTotal;
    stats.beatsSpectaculaires += resultat.beatsSpectaculaires;
    fusionnerCompteur(stats.parFamille, resultat.parFamille);
    fusionnerCompteur(stats.parLongueurArc, resultat.parLongueurArc);
    stats.violationsCanoniques = stats.violationsCanoniques.concat(resultat.violationsCanoniques.map(function (v) { return Object.assign({ match: m }, v); }));
    stats.violationsWhitelist = stats.violationsWhitelist.concat(resultat.violationsWhitelist.map(function (v) { return Object.assign({ match: m }, v); }));
    stats.repetitionsImmediatesGrammaire += resultat.repetitionsImmediatesGrammaire.length;
    if (profil === 'zero_zero') {
      Object.keys(resultat.grammairesVuesZeroZero).forEach(function (id) { stats.diversiteZeroZero[id] = (stats.diversiteZeroZero[id] || 0) + 1; });
    }
  }
  stats.dureeMs = Date.now() - t0;
  stats.dureeMsParMatch = stats.matchs ? +(stats.dureeMs / stats.matchs).toFixed(3) : null;
  stats.proportionTempsMiniTerrain = (stats.tempsMiniTerrainMs + stats.tempsSequencesMs) > 0
    ? +(stats.tempsMiniTerrainMs / (stats.tempsMiniTerrainMs + stats.tempsSequencesMs)).toFixed(4) : null;
  // Metrique PLUS FIDELE (voir commentaire dans jouerMatchNarratifHeadless) : proportion du temps
  // ou l'ecran reste VISUELLEMENT sur la camera du mini-terrain (gabarits/4 effets/
  // match_miniature_v2/respiration inclus, medium==='miniature') contre le temps ou il en sort
  // reellement (illustre_image/illustre_pictogram/illustre_video).
  const tempsEcranTotal = stats.tempsEcranMiniTerrainMs + stats.tempsEcranCoupureMs;
  stats.proportionEcranMiniTerrain = tempsEcranTotal > 0 ? +(stats.tempsEcranMiniTerrainMs / tempsEcranTotal).toFixed(4) : null;
  return stats;
}

// ---------------------------------------------------------------------
// 3. CAMPAGNE MASSIVE (LOT 12/23) + REPRODUCTIBILITE DES SEEDS
// ---------------------------------------------------------------------
function fusionnerCompteur(cible, source) {
  Object.keys(source).forEach(function (k) { cible[k] = (cible[k] || 0) + source[k]; });
}

function executerCampagne(nbMatchs, seedBase, jsonSeul) {
  const t0 = Date.now();
  const stats = {
    matchs: 0, situations: 0, evenementsCanoniquesObserves: 0, plans: 0, respirations: 0, plansImpossibles: 0, rejetsCarton: 0,
    repetitionsImmediates: 0, repetitionsFenetreCourte: 0,
    parFamille: {}, parPrimitive: {}, parIntensiteBucket: { basse: 0, moyenne: 0, haute: 0 },
    effetsValides: { drone_dive_impact_freeze: 0, freeze_follow_ball: 0, orbit_freeze: 0, time_ramp: 0 },
    violationsCanoniques: [], violationsRaccord: [], erreurs: [], seedsNonReproductibles: [],
    parProfil: {}
  };

  for (let m = 0; m < nbMatchs; m++) {
    const profil = PROFILS_MATCH_SYNTHETIQUE[m % PROFILS_MATCH_SYNTHETIQUE.length];
    const seedMatch = seedBase + '-m' + m + '-' + profil;
    let resultat;
    try {
      resultat = jouerMatchHeadless(profil, seedMatch);
    } catch (e) {
      stats.erreurs.push({ match: m, profil: profil, message: e.message });
      continue;
    }

    // Controle de reproductibilite (LOT 12, "selection non deterministe en mode seede") : rejoue
    // le MEME match avec le MEME seed, doit produire un resultat structurellement identique.
    let rejoue;
    try {
      rejoue = jouerMatchHeadless(profil, seedMatch);
      if (JSON.stringify(rejoue) !== JSON.stringify(resultat)) {
        stats.seedsNonReproductibles.push(seedMatch);
      }
    } catch (e) {
      stats.erreurs.push({ match: m, profil: profil, message: 'rejoue: ' + e.message });
    }

    stats.matchs++;
    stats.situations += resultat.situations;
    stats.evenementsCanoniquesObserves += resultat.evenementsCanoniquesObserves;
    stats.plans += resultat.plans;
    stats.respirations += resultat.respirations;
    stats.plansImpossibles += resultat.plansImpossibles;
    stats.rejetsCarton += resultat.rejetsCarton;
    stats.repetitionsImmediates += resultat.repetitionsImmediates;
    stats.repetitionsFenetreCourte += resultat.repetitionsFenetreCourte;
    fusionnerCompteur(stats.parFamille, resultat.parFamille);
    fusionnerCompteur(stats.parPrimitive, resultat.parPrimitive);
    stats.parIntensiteBucket.basse += resultat.parIntensiteBucket.basse;
    stats.parIntensiteBucket.moyenne += resultat.parIntensiteBucket.moyenne;
    stats.parIntensiteBucket.haute += resultat.parIntensiteBucket.haute;
    fusionnerCompteur(stats.effetsValides, resultat.effetsValides);
    stats.violationsCanoniques = stats.violationsCanoniques.concat(resultat.violationsCanoniques.map(function (v) { return Object.assign({ match: m, profil: profil }, v); }));
    stats.violationsRaccord = stats.violationsRaccord.concat(resultat.violationsRaccord.map(function (v) { return Object.assign({ match: m, profil: profil }, v); }));

    if (!stats.parProfil[profil]) stats.parProfil[profil] = { matchs: 0, plans: 0, plansImpossibles: 0, spectaculaires: 0 };
    stats.parProfil[profil].matchs++;
    stats.parProfil[profil].plans += resultat.plans;
    stats.parProfil[profil].plansImpossibles += resultat.plansImpossibles;
    stats.parProfil[profil].spectaculaires += (resultat.spectaculaires || 0);
  }

  stats.dureeMs = Date.now() - t0;
  stats.dureeMsParMatch = stats.matchs ? +(stats.dureeMs / stats.matchs).toFixed(3) : null;
  return stats;
}

// ---------------------------------------------------------------------
// 4. CLI
// ---------------------------------------------------------------------
function parseArgs(argv) {
  const out = { matchs: 200, seed: 'campagne-defaut', json: false, narratif: false };
  argv.forEach(function (a) {
    const mMatchs = a.match(/^--matchs=(\d+)$/);
    const mSeed = a.match(/^--seed=(.+)$/);
    if (mMatchs) out.matchs = parseInt(mMatchs[1], 10);
    if (mSeed) out.seed = mSeed[1];
    if (a === '--json') out.json = true;
    if (a === '--narratif') out.narratif = true;
  });
  return out;
}

if (require.main === module) {
  const args = parseArgs(process.argv.slice(2));

  if (args.narratif) {
    const statsN = executerCampagneNarrative(args.matchs, args.seed);
    if (args.json) {
      console.log(JSON.stringify(statsN, null, 2));
    } else {
      console.log('=== CAMPAGNE REALISATEUR NARRATIF (headless) ===');
      console.log('matchs synthetiques      :', statsN.matchs, '(' + statsN.dureeMs + ' ms, ' + statsN.dureeMsParMatch + ' ms/match)');
      console.log('situations totales       :', statsN.situations);
      console.log('sequences narratives      :', statsN.sequencesNarratives);
      console.log('situations sans beat      :', statsN.situationsSansBeat, '(dont impossibles reelles :', statsN.situationsImpossibles, ')');
      console.log('proportion temps mini-terrain (estimee brute, sequence vs pas-sequence):', (statsN.proportionTempsMiniTerrain * 100).toFixed(1) + '%');
      console.log('proportion ECRAN reellement sur le mini-terrain (medium==miniature, gabarits/effets/ambiance inclus):', (statsN.proportionEcranMiniTerrain * 100).toFixed(1) + '%');
      console.log('beats joues / spectaculaires:', statsN.beatsTotal, '/', statsN.beatsSpectaculaires, '(' + (100 * statsN.beatsSpectaculaires / (statsN.beatsTotal || 1)).toFixed(1) + '%)');
      console.log('repetitions immediates (grammaire):', statsN.repetitionsImmediatesGrammaire);
      console.log('violations canoniques     :', statsN.violationsCanoniques.length);
      if (statsN.violationsCanoniques.length) console.log(JSON.stringify(statsN.violationsCanoniques.slice(0, 10), null, 2));
      console.log('violations whitelist/MR1  :', statsN.violationsWhitelist.length);
      if (statsN.violationsWhitelist.length) console.log(JSON.stringify(statsN.violationsWhitelist.slice(0, 10), null, 2));
      console.log('erreurs                   :', statsN.erreurs.length);
      if (statsN.erreurs.length) console.log(JSON.stringify(statsN.erreurs.slice(0, 10), null, 2));
      console.log('seeds non reproductibles  :', statsN.seedsNonReproductibles.length);
      console.log('--- par famille ---');
      console.log(statsN.parFamille);
      console.log('--- par longueur d\'arc (nb de beats joues) ---');
      console.log(statsN.parLongueurArc);
      console.log('--- temps sequence (ms) PAR FAMILLE (explique la proportion globale) ---');
      console.log(statsN.tempsMsParFamille);
      console.log('--- diversite des grammaires vues sur les matchs 0-0 ---');
      console.log(statsN.diversiteZeroZero);
    }
    process.exit(0);
  }

  const stats = executerCampagne(args.matchs, args.seed, args.json);
  if (args.json) {
    console.log(JSON.stringify(stats, null, 2));
  } else {
    console.log('=== CAMPAGNE REALISATEUR (headless) ===');
    console.log('matchs synthetiques   :', stats.matchs, '(' + stats.dureeMs + ' ms, ' + stats.dureeMsParMatch + ' ms/match)');
    console.log('situations totales    :', stats.situations);
    console.log('plans generes         :', stats.plans, '(dont respirations:', stats.respirations, ')');
    console.log('plans impossibles     :', stats.plansImpossibles);
    console.log('rejets carton/blessure:', stats.rejetsCarton, '(attendu : > 0, jamais mis en scene)');
    console.log('repetitions immediates:', stats.repetitionsImmediates);
    console.log('repetitions fenetre   :', stats.repetitionsFenetreCourte);
    console.log('violations canoniques :', stats.violationsCanoniques.length);
    if (stats.violationsCanoniques.length) console.log(JSON.stringify(stats.violationsCanoniques.slice(0, 10), null, 2));
    console.log('violations raccord    :', stats.violationsRaccord.length, '(MR1/MR2/MR3, re-controle independant du selecteur)');
    if (stats.violationsRaccord.length) console.log(JSON.stringify(stats.violationsRaccord.slice(0, 10), null, 2));
    console.log('erreurs               :', stats.erreurs.length);
    if (stats.erreurs.length) console.log(JSON.stringify(stats.erreurs.slice(0, 10), null, 2));
    console.log('seeds non reproductibles:', stats.seedsNonReproductibles.length);
    console.log('--- par famille ---');
    console.log(stats.parFamille);
    console.log('--- par primitive ---');
    console.log(stats.parPrimitive);
    console.log('--- intensite ---');
    console.log(stats.parIntensiteBucket);
    console.log('--- 4 effets valides ---');
    console.log(stats.effetsValides);
    console.log('--- par profil ---');
    console.log(stats.parProfil);
  }
}

module.exports = {
  genererMatchSynthetique: genererMatchSynthetique,
  jouerMatchHeadless: jouerMatchHeadless,
  executerCampagne: executerCampagne,
  jouerMatchNarratifHeadless: jouerMatchNarratifHeadless,
  executerCampagneNarrative: executerCampagneNarrative,
  PROFILS_MATCH_SYNTHETIQUE: PROFILS_MATCH_SYNTHETIQUE
};
