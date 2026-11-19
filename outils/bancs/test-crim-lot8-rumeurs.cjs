'use strict';
// Criminalité, lot 8 : délits d'information — rumeurs, tracts calomnieux, bouche-à-oreille (GAME-DESIGN-CRIMINALITE.md § 13).
// Trois niveaux, sans se faire passer l'un pour l'autre :
//  1. règles du document recalculées ici et comparées aux valeurs RENDUES PAR LA PRODUCTION lors des essais annulés du 20/11/2026
//     (Arnie placé au restaurant de l'hôtel Republica le temps de l'essai, DIS 80, CHA 16, POP 50 ; cible Bartesto Chevara ;
//     jets imposés par rp.crim_jets ; tout annulé par RAISE EXCEPTION) : relevé recopié ci-dessous ;
//  2. lecture de la migration (résolution commune, plus de crime_detecter_interne, barème des tracts, bouche-à-oreille) ;
//  3. écran : plateau-criminalite.js chargé dans une machine virtuelle (affichage de la réponse, aucun calcul), pop-up cpj-*,
//     plus aucun Math.random dans plateau-actions-illegales-rumeurs.js.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const racine = path.join(__dirname, '../..');
const lire = (f) => fs.readFileSync(path.join(racine, f), 'utf8');
const sql = lire('migrations/20261120070000_crim_lot8_rumeurs.sql');
const js = lire('plateau-criminalite.js');
const pnj = lire('plateau-pnj.js');
const rumeurs = lire('plateau-actions-illegales-rumeurs.js');
const comm = lire('plateau-communication.js');
const routeur = lire('plateau-router.js');

// Règles du document (§ 13).
const tauxRumeur = (dis, cha) => 60 + Math.floor(Math.max(0, dis - 50) / 3) + 2 * Math.max(0, cha - 8);
const borne = (t, dissuasion = 0) => Math.max(10, Math.min(90, t - dissuasion));
const detection = (dis) => Math.max(5, 15 - Math.floor(dis / 10));
const seuilCritique = (taux, part = 10) => 100 - (100 - taux) * part / 100;   // jet ≥ seuil = échec critique

// Relevé des essais en production (transactions annulées, 20/11/2026).
const RELEVE = {
  taux_formule: 86, taux_bornes_brutes: [60, 120], dissuasion_lieu: 0,
  ok1: { reussi: true, taux: 86, perte: 12, detecte: false, identifie: false, peine_jours: null, echec_critique: false, pa: 29 },
  aff1: { cible: 'Bartesto Chevara', mode: 'decouvert', issue: 'reussite', det: 0, taux: 86 }, pop_cible: 38, trace1: 1,
  det2: { reussi: true, detecte: true, identifie: true, repere: true, peine: 1, dis: 70 }, jug2: 1,
  crit: { crit: true, identifie: true, repere: true, peine: 1, pop: 45, perte: 5, rech: 1 }, mail: 1, annonce: 1, moral: 50,
  jug_crit: [{ motif: 'Delit mineur', peine: '1 jour' }],
  ech4: { reussi: false, crit: false, identifie: false, peine: null },
  bouche5: { type_action: 'tract_calomnieux', auteur: 'Ben', cible: 'Jean Jaaj', bouche_oreille: true },
  tract_ok: { reussi: true, taux: 67, jet: 1, dissuasion: 0, pop: 33, inf: 22 }, trace_tract: 1,
  tract_crit: { critique: true, poursuite: 'flagrant_delit', jet: 100, arr_ok: true, arr_jours: 1 }, aff_tract: { identifie: true },
  mandat: { poursuite: 'mandat', jours: 1, country: 'republic' },
  lot4: { crit: true, identifie: false }, defaut: { crit: true, identifie: true, peine: 1 }, moral_defaut: 35
};

test('Taux de la rumeur : 60 + 1/3 de DIS > 50 + 2/CHA > 8, bornes 10-90 (production : 86 pour DIS 80, CHA 16)', () => {
  assert.equal(tauxRumeur(80, 16), 86);
  assert.equal(RELEVE.taux_formule, tauxRumeur(80, 16));
  assert.equal(RELEVE.ok1.taux, borne(tauxRumeur(80, 16), RELEVE.dissuasion_lieu));
  assert.equal(tauxRumeur(50, 8), 60, 'plancher des stats : 60');
  assert.equal(tauxRumeur(40, 5), 60, 'DIS sous 50 et CHA sous 8 : aucun malus');
  assert.deepEqual(RELEVE.taux_bornes_brutes, [tauxRumeur(50, 8), tauxRumeur(100, 30)]);
  assert.equal(borne(tauxRumeur(100, 30)), 90, 'plafond 90 appliqué par la résolution commune');
  assert.equal(borne(60, 40), 20);
  assert.equal(borne(30, 40), 10, 'plancher 10');
  assert.match(sql, /'min', public\.crim_param_interne\('rumeur_taux_min', 10\), 'max', public\.crim_param_interne\('rumeur_taux_max', 90\)/);
});

test('Dissuasion #135 comptée une seule fois : résolution commune, plus de crime_detecter_interne', () => {
  const corps = sql.slice(sql.indexOf('FUNCTION public.rumeur_lancer'), sql.indexOf('FUNCTION public.calomnie_distribuer_interne'));
  assert.doesNotMatch(corps, /crime_detecter_interne|securite_malus_lieu_interne/);
  assert.match(corps, /crim_resoudre_interne\('fausse_rumeur'/);
  assert.doesNotMatch(corps, /'dissuasion', false/, 'la dissuasion reste active (une fois, dans la résolution commune)');
  assert.equal(RELEVE.aff1.det, RELEVE.dissuasion_lieu);
});

test('Échec critique : 10 % des échecs — identifié, la cible apprend son nom, annonce publique, perte de POP, peine au barème', () => {
  assert.equal(seuilCritique(86), 98.6);
  assert.equal(seuilCritique(10), 91);
  assert.match(sql, /'critique_echec_part', public\.crim_param_interne\('rumeur_echec_critique_part', 10\), 'critique_identifie', true, 'critique_moral', false/);
  assert.deepEqual(RELEVE.crit, { crit: true, identifie: true, repere: true, peine: 1, pop: 45, perte: 5, rech: 1 });
  assert.equal(RELEVE.crit.pop, 50 - RELEVE.crit.perte, 'POP de l’auteur 50 → 45');
  assert.equal(RELEVE.mail, 1, 'message « Arnie a tenté de répandre des calomnies » au PJ visé');
  assert.equal(RELEVE.annonce, 1, 'la rumeur se retourne contre lui (annonce publique)');
  assert.equal(RELEVE.moral, 50, 'pas de perte de moral (non prévue au § 13)');
  assert.deepEqual(RELEVE.jug_crit, [{ motif: 'Delit mineur', peine: '1 jour' }], 'peine d’office du barème (crim_identifier_interne)');
  assert.match(sql, /'msg_echec', '\{Auteur\} a tenté de répandre des calomnies sur votre compte\.'/);
});

test('Correctif de la résolution commune : critique_moral = false ne coupe plus l’identification', () => {
  assert.match(sql, /IF v_crit_e THEN IF coalesce\(\(p ->> 'critique_moral'\)::boolean, true\) \/\* crim_critique_moral_v1 \*\/ \/\* crim_critique_moral_v2 \*\/ THEN/);
  assert.deepEqual(RELEVE.lot4, { crit: true, identifie: false }, 'cambriolage (critique_identifie false) inchangé');
  assert.deepEqual(RELEVE.defaut, { crit: true, identifie: true, peine: 1 });
  assert.equal(RELEVE.moral_defaut, 35, '−15 moral par défaut, toujours');
});

test('Détection après une réussite seulement : 15 − DIS/10, minimum 5 % ; détecté = identifié, peine d’office', () => {
  assert.equal(detection(80), 7);
  assert.equal(detection(100), 5);
  assert.equal(detection(0), 15);
  assert.match(sql, /'detection_base', public\.crim_param_interne\('rumeur_detection_base', 15\) - floor\(v_dis \/ 10\),\s*'detection_min', public\.crim_param_interne\('rumeur_detection_min', 5\)/);
  assert.match(sql, /'mode', 'decouvert', 'decouvert_identifie', false/, 'ni cachette ni masque : pas de réduction de la détection');
  assert.deepEqual(RELEVE.det2, { reussi: true, detecte: true, identifie: true, repere: true, peine: 1, dis: 70 });
  assert.equal(RELEVE.jug2, 1);
  assert.equal(RELEVE.ok1.detecte, false);
  assert.equal(RELEVE.ech4.identifie, false, 'échec ordinaire : ni détection ni suite pénale');
  assert.equal(RELEVE.ech4.peine, null);
});

test('Effets sur la cible inchangés ; trace de rumeur et plainte contre X (affaire au nom du PJ visé)', () => {
  assert.ok(RELEVE.ok1.perte >= 5 && RELEVE.ok1.perte <= 20);
  assert.equal(RELEVE.pop_cible, 50 - RELEVE.ok1.perte);
  assert.match(sql, /v_perte := floor\(random\(\) \* 16\)::integer \+ 5;/);
  assert.equal(RELEVE.trace1, 1);
  assert.deepEqual(RELEVE.aff1, { cible: 'Bartesto Chevara', mode: 'decouvert', issue: 'reussite', det: 0, taux: 86 });
  assert.match(sql, /'msg_reussite', ''/, 'anonyme par défaut : aucun message à la cible après une réussite');
});

test('Tracts calomnieux : résolution commune, échec critique 10 %, flagrant délit et mandat au barème (plus de 1 jour en dur)', () => {
  assert.match(sql, /crim_resoudre_interne\('tracts_calomnieux', p_joueur, NULL/);
  assert.match(sql, /'critique_echec_part', public\.crim_param_interne\('tracts_echec_critique_part', 10\)/);
  assert.doesNotMatch(sql.slice(sql.indexOf('FUNCTION public.calomnie_distribuer_interne'), sql.indexOf('pg_temp.rp_raccorder(p_fn')), /random\(\)/);
  assert.match(sql, /crim_peine_jours_interne\('imprimer_tracts_calomnieux', \(SELECT country/);
  assert.match(sql, /'jours', public\.crim_peine_jours_interne\('imprimer_tracts_calomnieux', p_pays\)/);
  assert.equal(RELEVE.tract_ok.taux, 67);
  assert.equal(RELEVE.tract_ok.dissuasion, 0);
  assert.equal(RELEVE.trace_tract, 1, 'une distribution réussie laisse une trace pour le bouche-à-oreille');
  assert.deepEqual(RELEVE.tract_crit, { critique: true, poursuite: 'flagrant_delit', jet: 100, arr_ok: true, arr_jours: 1 });
  assert.deepEqual(RELEVE.mandat, { poursuite: 'mandat', jours: 1, country: 'republic' });
  assert.equal(RELEVE.aff_tract.identifie, true);
});

test('Bouche-à-oreille : 10 %, rumeurs et tracts, traces de la ville seulement par ce jet', () => {
  assert.match(sql, /<public\.crim_param_interne\('bouche_oreille_part',10\)/);
  assert.match(sql, /t\.type_action IN\('fausse_rumeur','tract_calomnieux'\)/);
  assert.match(sql, /t\.type_action NOT IN\('fausse_rumeur','tract_calomnieux'\)/);
  assert.deepEqual(RELEVE.bouche5, { type_action: 'tract_calomnieux', auteur: 'Ben', cible: 'Jean Jaaj', bouche_oreille: true });
  assert.match(rumeurs, /fausse_rumeur: \(a, c\) => 'On dit que c\\'est ' \+ a \+ ' qui fait courir ce bruit sur ' \+ c \+ '\.'/);
  assert.match(rumeurs, /tract_calomnieux: \(a, c\) => 'On dit que c\\'est ' \+ a \+ ' qui distribue des tracts contre ' \+ c \+ '\.'/);
});

test('Écran : aucun Math.random ni calcul dans plateau-actions-illegales-rumeurs.js ; pop-up de la rumeur en cpj-*', () => {
  assert.doesNotMatch(rumeurs, /Math\.random/);
  assert.doesNotMatch(pnj.slice(pnj.indexOf('function ouvrirModalLancerRumeur'), pnj.indexOf('function majTexteRumeur')), /successRate|75/);
  assert.match(pnj, /<div class="cpj-dialogue">' \+\s*'<p class="cpj-note">Acte illégal/);
  assert.match(pnj, /class="cpj-touche cpj-primaire" onclick="validerLancementRumeur\(\)"/);
  assert.match(pnj, /crimRumeurResultat\(v, type, cibleLabel, texte\)/);
  assert.match(routeur, /ouvrirModalLancerRumeur\(pa, cost\); return;/);
  assert.doesNotMatch(comm, /jours: 1, source: 'flagrant_delit'/);
  assert.match(comm, /crimTractFlagrant\(pnjName, joursTracts\)/);
});

test('Écran : crimRumeurResultat affiche la réponse du serveur (réussite, détection, échec, échec critique)', () => {
  const dom = { innerHTML: '', textContent: '', classList: { add() {}, remove() {} } };
  const toasts = []; const journal = [];
  const g = {
    document: { getElementById: () => dom, readyState: 'loading', addEventListener() {} },
    state: { country: 'republic', pa: 30, char: { name: 'Moi' } },
    showToast: (t, b, ok) => toasts.push([t, b, ok]), addJournalEntry: (t, c) => journal.push([t, c]),
    adopterJaugeServeur() {}, updateUI() {}
  };
  g.window = g; g.globalThis = g;
  vm.runInNewContext(js.replace(/\(typeof window !== 'undefined' \? window : globalThis\);\s*$/, '(globalThis);'), g);
  g.crimRumeurResultat({ ok: true, reussi: true, perte: 12, pa: 29, identifie: false, peine_jours: null }, 'pj', 'Bartesto', 'Il triche');
  assert.match(dom.innerHTML, /cpj-dialogue[\s\S]*« Il triche »[\s\S]*Cible : Bartesto/);
  assert.equal(g.state.pa, 29);
  assert.match(journal.at(-1)[0], /−12 POP pour Bartesto/);
  g.crimRumeurResultat({ ok: true, reussi: true, perte: 3, identifie: true, peine_jours: 1, recherche: [{ acte: 'fausse_rumeur' }] }, 'pays', 'Sovarka', 'x');
  assert.match(toasts.at(-1)[1], /reconnu\(e\)[\s\S]*1 jour\(s\) de prison/);
  assert.equal(g.state.recherche.length, 1);
  g.crimRumeurResultat({ ok: true, reussi: false, echec_critique: true, perte: 5, peine_jours: 1 }, 'pj', 'Bartesto', 'x');
  assert.equal(toasts.at(-1)[0], 'Calomniateur démasqué');
  assert.match(toasts.at(-1)[1], /calomnier Bartesto\. −5 POP ; recherché\(e\), 1 jour\(s\)/);
  g.crimRumeurResultat({ ok: true, reussi: false, echec_critique: false, perte: 0 }, 'pj', 'Bartesto', 'x');
  assert.match(toasts.at(-1)[1], /sans conséquence/);
  g.crimRumeurResultat({ ok: true, reussi: true, perte: 2, membres: 0 }, 'gouvernement', 'Sovarka', 'x');
  assert.match(journal.at(-1)[0], /aucun titulaire en poste/);
  const t = g.crimTractFlagrant('Gaston', 1);
  assert.match(t.corps, /Gaston alerte[\s\S]*1 jour\(s\) de détention/);
});
