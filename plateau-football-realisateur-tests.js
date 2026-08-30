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
// ---- LOT "audit du catalogue visuel" (30 aout 2026) : whitelist et identite SELECTED/RESOLVED ----
// Corrige le 30 aout 2026 (chantier "montage narratif", section 10) : gabarit_montage_4 est
// desormais VOLONTAIREMENT hors whitelist (decision de direction artistique -- glaives ⚔️ jamais
// autorises) -- seule exception explicite et nommee, jamais un relachement general du test.
test('registre : chaque grammaire a un nbPlansAttendu positif ; toutes SAUF gabarit_montage_4 (exclusion volontaire ⚔️) ont un statut whitelistable', function () {
  RealisateurIA.REGISTRE_GRAMMAIRES_REALISATEUR.forEach(function (g) {
    if (g.id !== 'gabarit_montage_4') {
      assert.ok(RealisateurIA.STATUTS_AUTORISES_POOL_AUTOMATIQUE.includes(g.statut), g.id + ' : statut "' + g.statut + '" absent de la whitelist');
    }
    assert.ok(Number.isInteger(g.nbPlansAttendu) && g.nbPlansAttendu > 0, g.id + ' : nbPlansAttendu invalide');
  });
});
test('gabarit_montage_4 (glaives ⚔️) : statut explicitement REJETE, jamais autorise automatiquement', function () {
  const g = RealisateurIA.REGISTRE_GRAMMAIRES_REALISATEUR.find(function (x) { return x.id === 'gabarit_montage_4'; });
  assert.strictEqual(RealisateurIA.estAutoriseAutomatiquement(g), false);
  assert.ok(!RealisateurIA.STATUTS_AUTORISES_POOL_AUTOMATIQUE.includes(g.statut));
});
test('gabarit_montage_4 (glaives ⚔️) : jamais selectionne sur 500 situations qui l\'auraient rendu eligible avant sa mise a l\'ecart', function () {
  for (let i = 0; i < 500; i++) {
    const situation = { microAction: 'duel', cote: 'home', minute: 30, ecartScore: 0, pressionRecente: 2 };
    const r = RealisateurIA.selectionnerRealisation({ situation: situation, seed: 'glaive-' + i, memoire: RealisateurIA.creerMemoireRealisateur() });
    if (r.plan) assert.notStrictEqual(r.plan.selectedGrammar, 'gabarit_montage_4');
  }
});
test('R0 whitelist : une grammaire au statut non autorise (ex. INTERNAL) est toujours rejetee, quel que soit le reste', function () {
  const g = Object.assign({}, RealisateurIA.REGISTRE_GRAMMAIRES_REALISATEUR.find(function (x) { return x.id === 'gabarit_montage_0'; }), { statut: 'INTERNAL' });
  const verdict = RealisateurIA.validerCompatibiliteGrammaire(g, { microAction: 'duel', cote: 'home' }, 'NEUTRE');
  assert.strictEqual(verdict.ok, false);
  assert.ok(verdict.motif.indexOf('R0') !== -1, verdict.motif);
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
// Corrige le 30 aout 2026 (chantier "montage continu") : la respiration (__respiration__) est
// INTENTIONNELLEMENT exemptee de cette regle -- repeter "ne rien montrer de nouveau" n'est jamais
// un defaut de montage, contrairement a repeter une VRAIE grammaire. Seules les grammaires reelles
// (r.plan.isRespiration !== true) sont soumises au test.
test('anti-repetition : pas de repetition immediate de grammaire REELLE quand une alternative existe (1000 tirages)', function () {
  const memoire = RealisateurIA.creerMemoireRealisateur();
  let dernierReel = null, repetitionsAlorsQuAlternativeExistait = 0;
  for (let i = 0; i < 1000; i++) {
    const situation = { microAction: 'duel', cote: 'home', minute: i % 45, ecartScore: 0, pressionRecente: 1 };
    const r = RealisateurIA.selectionnerRealisation({ situation: situation, seed: 'rar-' + i, memoire: memoire });
    if (r.plan && !r.plan.isRespiration) {
      const nbCandidats = RealisateurIA.grammairesEligibles(situation, r.trace.intention).candidats.length;
      if (dernierReel === r.plan.selectedGrammar && nbCandidats > 1) repetitionsAlorsQuAlternativeExistait++;
      dernierReel = r.plan.selectedGrammar;
    }
  }
  assert.strictEqual(repetitionsAlorsQuAlternativeExistait, 0);
});

// ---- LOT "montage continu" (30 aout 2026) : regles de raccord MR1/MR2/MR3 ----
test('registre : chaque grammaire declare un etatSortie complet (medium/reactionTerminale/resolutionAssumee/retourTerrainInclus)', function () {
  RealisateurIA.REGISTRE_GRAMMAIRES_REALISATEUR.forEach(function (g) {
    assert.ok(g.etatSortie, g.id + ' : etatSortie manquant');
    ['medium', 'reactionTerminale', 'resolutionAssumee', 'retourTerrainInclus'].forEach(function (champ) {
      assert.ok(g.etatSortie[champ] !== undefined, g.id + '.etatSortie.' + champ + ' manquant');
    });
  });
});
test('MR1 : jamais deux realisations spectaculaires sans respiration suffisante entre elles (2000 tirages)', function () {
  const memoire = RealisateurIA.creerMemoireRealisateur();
  let idxDernierSpectaculaire = -Infinity, violations = 0;
  for (let i = 0; i < 2000; i++) {
    const situation = { microAction: ['duel', 'frappe', 'centre', 'interception'][i % 4], cote: 'home', minute: i % 45, ecartScore: 0, pressionRecente: 3 };
    const r = RealisateurIA.selectionnerRealisation({ situation: situation, seed: 'mr1-' + i, memoire: memoire });
    if (r.plan && !r.plan.isRespiration && r.plan.spectaculaire) {
      if ((i - idxDernierSpectaculaire) <= RealisateurIA.PARAMETRES_RACCORD.respirationApresSpectaculaireNb) violations++;
      idxDernierSpectaculaire = i;
    }
  }
  assert.strictEqual(violations, 0);
});
test('MR2 : jamais une realisation spectaculaire immediatement apres une reaction terminale (2000 tirages)', function () {
  const memoire = RealisateurIA.creerMemoireRealisateur();
  let attenteRespiration = false, violations = 0;
  for (let i = 0; i < 2000; i++) {
    const situation = { microAction: ['duel', 'frappe', 'centre', 'interception'][i % 4], cote: 'home', minute: i % 45, ecartScore: 0, pressionRecente: 2 };
    const r = RealisateurIA.selectionnerRealisation({ situation: situation, seed: 'mr2-' + i, memoire: memoire });
    if (r.plan && r.plan.isRespiration) { attenteRespiration = false; continue; }
    if (r.plan) {
      if (r.plan.spectaculaire && attenteRespiration) violations++;
      attenteRespiration = !!(r.plan.etatSortie && r.plan.etatSortie.reactionTerminale);
    }
  }
  assert.strictEqual(violations, 0);
});
test('MR3 : la chaine coup franc BRUTE (video puis reset sec) n\'est jamais choisie quand sa variante raccordee (retour terrain explicite) est eligible', function () {
  const situationArret = { coupFrancEtape: 'arret', coupFrancResultat: 'arret', minute: 40 };
  for (let i = 0; i < 300; i++) {
    const r = RealisateurIA.selectionnerRealisation({ situation: situationArret, seed: 'mr3-' + i, memoire: RealisateurIA.creerMemoireRealisateur() });
    if (r.plan) assert.notStrictEqual(r.plan.selectedGrammar, 'coup_franc_arrete', 'raccord_coup_franc_arrete etait eligible, la chaine brute n\'aurait pas du etre choisie');
  }
  const situationBut = { coupFrancEtape: 'but', coupFrancResultat: 'but', minute: 41 };
  for (let i = 0; i < 300; i++) {
    const r = RealisateurIA.selectionnerRealisation({ situation: situationBut, seed: 'mr3b-' + i, memoire: RealisateurIA.creerMemoireRealisateur() });
    if (r.plan) assert.notStrictEqual(r.plan.selectedGrammar, 'coup_franc_but');
  }
});
test('respiration : jamais proposee pour une situation de forme coupfranc ou canonique', function () {
  for (let i = 0; i < 200; i++) {
    const r1 = RealisateurIA.selectionnerRealisation({ situation: { coupFrancEtape: 'tension', minute: 40 }, seed: 'resp-cf-' + i });
    if (r1.plan) assert.notStrictEqual(r1.plan.selectedGrammar, RealisateurIA.ID_RESPIRATION);
  }
});
// Test COMPARATIF (jamais un seuil absolu arbitraire) : le poids de respiration change reellement
// selon le contexte (PARAMETRES_RACCORD.poidsRespirationApresReaction = 4x le poids de base) --
// verifie que le taux observe AVEC reaction terminale est nettement superieur au taux SANS,
// plutot que de fixer un pourcentage absolu qui dependrait du nombre de candidats concurrents
// (ici NEUTRE/circulation a 4 gabarits concurrents a poids 1 -- la math exacte est documentee
// dans le commentaire de POIDS_RESPIRATION_BASE, pas re-derivee ici).
test('respiration : taux nettement plus eleve juste apres une reaction terminale que sans (comparatif, 500+500 tirages)', function () {
  function tauxRespiration(dernierEtatSortie) {
    let n = 0;
    for (let i = 0; i < 500; i++) {
      const memoire = RealisateurIA.creerMemoireRealisateur();
      memoire.dernierEtatSortie = dernierEtatSortie;
      if (dernierEtatSortie) memoire.historique.push({ id: 'arret', familleRarete: 'coup_franc', spectaculaire: false });
      const r = RealisateurIA.selectionnerRealisation({ situation: { microAction: 'circulation', cote: 'home', minute: 41 }, seed: 'resp-cmp-' + i, memoire: memoire });
      if (r.plan && r.plan.isRespiration) n++;
    }
    return n;
  }
  const avecReaction = tauxRespiration({ medium: 'illustre_video', reactionTerminale: true, resolutionAssumee: true, retourTerrainInclus: false });
  const sansReaction = tauxRespiration(null);
  console.log('     (respiration avec reaction terminale : ' + avecReaction + '/500, sans : ' + sansReaction + '/500)');
  assert.ok(avecReaction > sansReaction * 2, 'le boost de respiration apres reaction terminale devrait au moins doubler le taux de base -- observe avec=' + avecReaction + ' sans=' + sansReaction);
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

// ---- LOT "montage narratif" (30 aout 2026) : tests structurels demandes section 20 ----
test('narratif : meme seed + meme memoire fraiche => meme arc (determinisme, 300 situations)', function () {
  const situations = [
    { microAction: 'circulation', cote: 'home', minute: 10, ecartScore: 0, pressionRecente: 0 },
    { microAction: 'duel', cote: 'home', minute: 20, ecartScore: 0, pressionRecente: 2 },
    { microAction: 'frappe', cote: 'away', minute: 30, ecartScore: 1, pressionRecente: 3 },
    { coupFrancEtape: 'tension', minute: 40 }
  ];
  for (let i = 0; i < 300; i++) {
    const situation = situations[i % situations.length];
    const a = RealisateurIA.construireArcNarratif({ situation: situation, seed: 'det-arc-' + i, memoire: RealisateurIA.creerMemoireRealisateur() });
    const b = RealisateurIA.construireArcNarratif({ situation: situation, seed: 'det-arc-' + i, memoire: RealisateurIA.creerMemoireRealisateur() });
    assert.deepStrictEqual(a.arcPlan, b.arcPlan);
  }
});
test('narratif : aucun evenement canonique invente -- but/carton/blessure canoniques nus ne produisent jamais de beat jouable', function () {
  ['but', 'carton', 'blessure', 'occasion', 'debut', 'mitemps', 'fin'].forEach(function (type) {
    for (let i = 0; i < 50; i++) {
      const r = RealisateurIA.construireArcNarratif({ situation: { canonique: { type: type, joueur: 'Quelquun' }, minute: 30 }, seed: 'canon-' + type + '-' + i, memoire: RealisateurIA.creerMemoireRealisateur() });
      assert.strictEqual(r.arcPlan.beats.length, 0, type + ' a produit un beat jouable, cf. ' + JSON.stringify(r.arcPlan));
    }
  });
});
test('narratif : aucun plan ne porte jamais un nom de joueur (auteur canonique jamais invente/reattribue)', function () {
  const memoire = RealisateurIA.creerMemoireRealisateur();
  for (let i = 0; i < 500; i++) {
    const situation = { microAction: ['duel', 'frappe', 'centre', 'course'][i % 4], cote: 'home', minute: i % 45, ecartScore: 0, pressionRecente: i % 4 };
    const r = RealisateurIA.construireArcNarratif({ situation: situation, seed: 'auteur-' + i, memoire: memoire });
    r.arcPlan.beats.forEach(function (b) { assert.ok(!b.plan.joueur && !b.plan.auteur, JSON.stringify(b)); });
  }
});
test('narratif : aucune grammaire hors whitelist (gabarit_montage_4/⚔️ compris) n\'apparait jamais dans un arc (2000 situations)', function () {
  const memoire = RealisateurIA.creerMemoireRealisateur();
  for (let i = 0; i < 2000; i++) {
    const situation = { microAction: ['circulation', 'duel', 'frappe', 'centre', 'course', 'interception', 'degagement'][i % 7], cote: 'home', minute: i % 45, ecartScore: 0, pressionRecente: i % 4 };
    const r = RealisateurIA.construireArcNarratif({ situation: situation, seed: 'whitelist-arc-' + i, memoire: memoire });
    r.arcPlan.beats.forEach(function (b) {
      assert.notStrictEqual(b.plan.selectedGrammar, 'gabarit_montage_4');
      if (!b.plan.isRespiration) {
        const g = RealisateurIA.REGISTRE_GRAMMAIRES_REALISATEUR.find(function (x) { return x.id === b.plan.selectedGrammar; });
        assert.ok(g && RealisateurIA.estAutoriseAutomatiquement(g), b.plan.selectedGrammar + ' hors whitelist dans un arc');
      }
    });
  }
});
test('narratif : D-E-F reste une unite intacte -- famille COUP_FRANC produit toujours exactement 1 beat, jamais decompose', function () {
  const memoire = RealisateurIA.creerMemoireRealisateur();
  ['tension', 'trajectoire'].forEach(function (etape) {
    for (let i = 0; i < 50; i++) {
      const r = RealisateurIA.construireArcNarratif({ situation: { coupFrancEtape: etape, minute: 40 }, seed: 'def-' + etape + '-' + i, memoire: memoire });
      assert.deepStrictEqual(r.arcPlan.arc, ['COUP_FRANC_UNITE']);
      assert.ok(r.arcPlan.beats.length <= 1);
    }
  });
});
test('narratif : sequences courtes (<=2 beats) disponibles et frequentes pour les familles non-coup-franc', function () {
  const memoire = RealisateurIA.creerMemoireRealisateur();
  let courtes = 0, total = 0;
  for (let i = 0; i < 1000; i++) {
    const situation = { microAction: ['circulation', 'duel', 'course', 'interception'][i % 4], cote: 'home', minute: i % 45, ecartScore: 0, pressionRecente: i % 3 };
    const r = RealisateurIA.construireArcNarratif({ situation: situation, seed: 'court-' + i, memoire: memoire });
    total++;
    if (r.arcPlan.arc.length <= 2) courtes++;
  }
  assert.ok(courtes / total > 0.5, 'les arcs courts devraient rester majoritaires pour ces familles, observe : ' + courtes + '/' + total);
});
test('narratif : robustesse -- situation partielle/inconnue (club/acteur absent) ne fait jamais planter construireArcNarratif', function () {
  const situationsAtypiques = [
    { microAction: 'duel' }, // sans cote/minute/ecartScore
    { microAction: 'frappe', cote: 'club-inconnu-xyz', minute: 999, pressionRecente: 50 },
    { canonique: { type: 'but' } }, // sans joueur
    { coupFrancEtape: 'arret', coupFrancResultat: 'arret' }, // sans minute
    {} // situation totalement vide
  ];
  situationsAtypiques.forEach(function (situation, i) {
    assert.doesNotThrow(function () {
      RealisateurIA.construireArcNarratif({ situation: situation, seed: 'atypique-' + i, memoire: RealisateurIA.creerMemoireRealisateur() });
    }, 'situation atypique #' + i + ' a fait planter le monteur : ' + JSON.stringify(situation));
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
