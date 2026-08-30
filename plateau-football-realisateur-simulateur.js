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
  const out = { matchs: 200, seed: 'campagne-defaut', json: false };
  argv.forEach(function (a) {
    const mMatchs = a.match(/^--matchs=(\d+)$/);
    const mSeed = a.match(/^--seed=(.+)$/);
    if (mMatchs) out.matchs = parseInt(mMatchs[1], 10);
    if (mSeed) out.seed = mSeed[1];
    if (a === '--json') out.json = true;
  });
  return out;
}

if (require.main === module) {
  const args = parseArgs(process.argv.slice(2));
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
  PROFILS_MATCH_SYNTHETIQUE: PROFILS_MATCH_SYNTHETIQUE
};
