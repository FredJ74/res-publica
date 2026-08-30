// =====================================================================
// REALISATEUR — TESTS (chantier "industrialisation du realisateur", nuit du 30 aout 2026)
// =====================================================================
// Suite d'assertions Node, aucune dependance externe (aucun framework de test installe dans ce
// depot -- voir RAPPORT final, section K, sur l'absence de Node/navigateur dans l'environnement
// de depart de ce chantier et l'installation locale au job pour pouvoir executer reellement ces
// tests plutot que de les laisser non executes). Executable : node plateau-football-realisateur-tests.js
'use strict';
const assert = require('assert');
const RealisateurIA = require('./plateau-football-realisateur-ia.js');
const { jouerMatchHeadless, executerCampagne, PROFILS_MATCH_SYNTHETIQUE } = require('./plateau-football-realisateur-simulateur.js');

let nbOk = 0, nbKo = 0;
function test(nom, fn) {
  try { fn(); nbOk++; console.log('OK   ' + nom); }
  catch (e) { nbKo++; console.log('FAIL ' + nom + ' -- ' + e.message); }
}

// ---- LOT 2/8 : invariants du registre ----
test('registre : aucune grammaire ne nomme un joueur precis', function () {
  RealisateurIA.REGISTRE_GRAMMAIRES_REALISATEUR.forEach(function (g) {
    assert.ok(!g.joueur && !g.joueurCible, g.id);
  });
});
test('registre : chaque grammaire declare au moins un declencheur et une intention', function () {
  RealisateurIA.REGISTRE_GRAMMAIRES_REALISATEUR.forEach(function (g) {
    assert.ok(Array.isArray(g.declencheurs) && g.declencheurs.length > 0, g.id + ' declencheurs');
    assert.ok(Array.isArray(g.intentionsCompatibles) && g.intentionsCompatibles.length > 0, g.id + ' intentions');
  });
});
test('vocabulaire : toute intention listee a au moins une grammaire compatible', function () {
  RealisateurIA.INTENTIONS_REALISATEUR.forEach(function (intention) {
    const trouve = RealisateurIA.REGISTRE_GRAMMAIRES_REALISATEUR.some(function (g) { return g.intentionsCompatibles.includes(intention); });
    assert.ok(trouve, intention + ' orpheline (aucune grammaire ne la sert)');
  });
});
test('vocabulaire : toute intention micro-action a au moins une grammaire de forme "micro" compatible', function () {
  Object.keys(RealisateurIA.INTENTIONS_AUTORISEES_PAR_EVENEMENT)
    .filter(function (k) { return k.indexOf('micro:') === 0; })
    .forEach(function (cle) {
      RealisateurIA.INTENTIONS_AUTORISEES_PAR_EVENEMENT[cle].forEach(function (intention) {
        const trouve = RealisateurIA.REGISTRE_GRAMMAIRES_REALISATEUR.some(function (g) {
          return g.declencheurs.includes('micro') && g.intentionsCompatibles.includes(intention) && !g.resultatCanoniqueRequis;
        });
        assert.ok(trouve, cle + ' -> ' + intention + ' : aucune grammaire micro-action ne couvre ce couple');
      });
    });
});

// ---- LOT 4 : matrice de compatibilite -- regles dures ----
test('R1 : un carton ne produit jamais de plan', function () {
  const r = RealisateurIA.selectionnerRealisation({ situation: { canonique: { type: 'carton', joueur: 'X' } }, seed: 's1' });
  assert.strictEqual(r.plan, null);
});
test('R1 : une blessure ne produit jamais de plan', function () {
  const r = RealisateurIA.selectionnerRealisation({ situation: { canonique: { type: 'blessure', joueur: 'X' } }, seed: 's2' });
  assert.strictEqual(r.plan, null);
});
test('R2 : "but" (coup franc) jamais choisi sans coupFrancResultat==="but"', function () {
  for (let i = 0; i < 500; i++) {
    const r = RealisateurIA.selectionnerRealisation({ situation: { coupFrancEtape: 'trajectoire', minute: 40 }, seed: 'r2-' + i });
    if (r.plan) assert.notStrictEqual(r.plan.selectedGrammar, 'but');
  }
});
test('R3 : "arret" jamais choisi sans coupFrancResultat==="arret"', function () {
  for (let i = 0; i < 500; i++) {
    const r = RealisateurIA.selectionnerRealisation({ situation: { coupFrancEtape: 'tension', minute: 40 }, seed: 'r3-' + i });
    if (r.plan) assert.notStrictEqual(r.plan.selectedGrammar, 'arret');
  }
});
test('R2/R3 mutuellement exclusives : une situation ne peut jamais satisfaire les deux gates', function () {
  RealisateurIA.REGISTRE_GRAMMAIRES_REALISATEUR.forEach(function (g) {
    if (g.resultatCanoniqueRequis === 'but') {
      const sit = { coupFrancEtape: 'arret', coupFrancResultat: 'arret' };
      assert.notStrictEqual(RealisateurIA.validerCompatibiliteGrammaire(g, sit, 'EXPLOSION').ok, true);
    }
  });
});
test('forme de situation : une grammaire "coupfranc" est rejetee pour une situation micro-action', function () {
  const g = RealisateurIA.REGISTRE_GRAMMAIRES_REALISATEUR.find(function (x) { return x.id === 'tension'; });
  const verdict = RealisateurIA.validerCompatibiliteGrammaire(g, { microAction: 'duel' }, 'TENSION');
  assert.strictEqual(verdict.ok, false);
});
test('forme de situation : une grammaire "micro" est rejetee pour un evenement canonique nu', function () {
  const g = RealisateurIA.REGISTRE_GRAMMAIRES_REALISATEUR.find(function (x) { return x.id === 'gabarit_montage_0'; });
  const verdict = RealisateurIA.validerCompatibiliteGrammaire(g, { canonique: { type: 'occasion' } }, 'DANGER');
  assert.strictEqual(verdict.ok, false);
});

// ---- LOT 5 : determinisme du selecteur ----
test('determinisme : meme situation + meme seed => meme plan, sur 200 seeds', function () {
  for (let i = 0; i < 200; i++) {
    const situation = { microAction: 'frappe', cote: 'home', minute: 40, ecartScore: 0, pressionRecente: 2 };
    const a = RealisateurIA.selectionnerRealisation({ situation: situation, seed: 'det-' + i });
    const b = RealisateurIA.selectionnerRealisation({ situation: situation, seed: 'det-' + i });
    assert.deepStrictEqual(a.plan, b.plan);
  }
});
test('intensite : signature fermee, jamais NaN/hors-bornes sur un balayage large', function () {
  const microActions = ['circulation','duel','interception','course','degagement','sortie','touche','remise','centre','frappe','arret'];
  microActions.forEach(function (m) {
    for (let p = 0; p <= 3; p++) {
      const v = RealisateurIA.calculerIntensiteRealisation({ microAction: m, pressionRecente: p, ecartScore: 0, minute: 30 });
      assert.ok(v >= 0 && v <= 1 && !Number.isNaN(v), m + '/' + p);
    }
  });
});

// ---- LOT 6 : rareté / anti-repetition ----
test('anti-repetition : pas de repetition immediate quand une alternative existe (1000 tirages)', function () {
  const memoire = RealisateurIA.creerMemoireRealisateur();
  let dernier = null, repetitionsAlorsQuAlternativeExistait = 0;
  for (let i = 0; i < 1000; i++) {
    const situation = { microAction: 'duel', cote: 'home', minute: i % 45, ecartScore: 0, pressionRecente: 1 };
    const r = RealisateurIA.selectionnerRealisation({ situation: situation, seed: 'rar-' + i, memoire: memoire });
    if (r.plan) {
      const nbCandidats = RealisateurIA.grammairesEligibles(situation, r.trace.intention).candidats.length;
      if (dernier === r.plan.selectedGrammar && nbCandidats > 1) repetitionsAlorsQuAlternativeExistait++;
      dernier = r.plan.selectedGrammar;
    }
  }
  assert.strictEqual(repetitionsAlorsQuAlternativeExistait, 0);
});

// ---- LOT 12 : campagne massive (execution reelle, pas simulee sur papier) ----
test('campagne 1200 matchs : zero violation canonique, zero plan impossible, zero seed non reproductible', function () {
  const stats = executerCampagne(1200, 'tests-auto-30aout2026');
  assert.strictEqual(stats.violationsCanoniques.length, 0, JSON.stringify(stats.violationsCanoniques.slice(0, 5)));
  assert.strictEqual(stats.plansImpossibles, 0);
  assert.strictEqual(stats.seedsNonReproductibles.length, 0);
  assert.strictEqual(stats.erreurs.length, 0, JSON.stringify(stats.erreurs.slice(0, 5)));
  assert.ok(stats.rejetsCarton > 0, 'aucun carton/blessure genere dans la campagne (generateur a verifier)');
});
test('les 4 effets valides sont bien atteignables par le selecteur (LOT 15)', function () {
  const stats = executerCampagne(400, 'tests-effets-30aout2026');
  ['drone_dive_impact_freeze', 'freeze_follow_ball', 'orbit_freeze', 'time_ramp'].forEach(function (id) {
    assert.ok(stats.effetsValides[id] > 0, id + ' jamais selectionne sur 400 matchs');
  });
});

// ---- LOT 20 : performance ----
test('performance : le selecteur reste sous 0.05ms/appel en moyenne sur 20000 appels', function () {
  const memoire = RealisateurIA.creerMemoireRealisateur();
  const t0 = Date.now();
  for (let i = 0; i < 20000; i++) {
    RealisateurIA.selectionnerRealisation({ situation: { microAction: 'duel', minute: i % 45, ecartScore: 0, pressionRecente: i % 4 }, seed: 'perf-' + i, memoire: memoire });
  }
  const ms = Date.now() - t0;
  console.log('     (20000 appels en ' + ms + 'ms, ' + (ms / 20000).toFixed(4) + 'ms/appel, memoire.historique.length=' + memoire.historique.length + ')');
  assert.ok(ms / 20000 < 0.05);
  assert.ok(memoire.historique.length <= RealisateurIA.PARAMETRES_RARETE_REALISATEUR.memoireTailleMax * 3, 'memoire non bornee');
});

console.log('\n=== ' + nbOk + ' OK / ' + nbKo + ' FAIL ===');
process.exit(nbKo ? 1 : 0);
