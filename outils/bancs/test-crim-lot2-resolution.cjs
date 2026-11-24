'use strict';
// Criminalité, lot 2 : résolution commune des crimes et Neutraliser (GAME-DESIGN-CRIMINALITE.md §§ 2, 3, 6).
// Trois niveaux, sans se faire passer l'un pour l'autre :
//  1. formules du document recalculées ici et comparées aux valeurs RENDUES PAR LA PRODUCTION lors des essais annulés du 19/11
//     (crim_combat_taux_interne, crim_detection_taux_interne, crim_neutraliser_taux_interne, crim_peine_jours_interne,
//     crim_message_interne, crim_resoudre_interne avec jets imposés, crime_neutraliser réel) : relevé recopié ci-dessous ;
//  2. lecture de la migration (fragments attendus : bornes, échec critique, une seule dissuasion, raccords du combat) ;
//  3. module d'écran chargé dans une machine virtuelle (cible masquée visée par jeton, aucun calcul de taux).
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const racine = path.join(__dirname, '../..');
const sql = fs.readFileSync(path.join(racine, 'migrations/20261119160000_crim_lot2_resolution_commune_neutraliser.sql'), 'utf8');
const js = fs.readFileSync(path.join(racine, 'plateau-criminalite.js'), 'utf8');
const ill = fs.readFileSync(path.join(racine, 'plateau-actions-illegales-rumeurs.js'), 'utf8');
const pnj = fs.readFileSync(path.join(racine, 'plateau-pnj.js'), 'utf8');
const multi = fs.readFileSync(path.join(racine, 'plateau-multijoueur.js'), 'utf8');

// Formules du document.
const borne = (v, a, b) => Math.max(a, Math.min(b, v));
const combat = (per, garde, cache) => borne(10 + 2 * Math.max(0, per - 10) + (garde ? 15 : 0) - (cache ? 10 : 0), 2, 40);
const detection = (base, mode, min = 5) => Math.min(100, Math.max(min, base - (/cache/.test(mode) ? 20 : 0) - (/masque/.test(mode) ? 10 : 0)));
const neutraliser = (mode, stat, criminel, per, cache, gilet) => Math.round({ mains: 15, arme: 25, feu: 35 }[mode] + 2 * stat + (criminel ? 15 : 0)
  - per / 2 + (cache ? 10 : 0) - (gilet ? (mode === 'feu' ? 20 : 5) : 0));
const echecCritique = (u, taux, part = 2) => u >= taux && u >= 100 - (100 - taux) * part / 100;
const designation = (mode, nom, forme) => /masque/.test(mode) ? (forme === 'sujet' ? 'Un individu masqué' : 'un individu masqué')
  : mode === 'cache' ? (forme === 'sujet' ? 'Quelqu\'un' : 'un inconnu') : nom;

// Relevé des essais en production (transactions annulées, 19/11/2026).
const RELEVE = {
  combat: [[10, false, false, 10], [20, true, false, 40], [8, false, true, 2], [15, false, false, 20], [12, true, true, 19]],
  detection: [[30, 'cache_masque', 5, 5], [60, 'masque', 5, 50], [40, 'cache', 5, 20], [30, 'decouvert', 5, 30], [65, 'cache_masque', 30, 35]],
  peines: { assassinat_republic: 2, assassinat_soviet: 2, tentative_narco: 2, bareme_assassinat_soviet: 2, bareme_vol_republic: 1 },
  neutraliser: [['mains', 8, false, 10, false, false, 26], ['feu', 10, true, 10, true, true, 55], ['arme', 9, false, 8, false, true, 34]],
  messages: ["Quelqu'un a tenté de vous neutraliser.", 'Neutralisé(e) par un individu masqué.', 'Arnie / Arnie'],
  // crim_resoudre_interne, jets imposés (taux 50, dissuasion coupée).
  scenarios: {
    reussite_decouvert_detectee: { issue: 'reussite', identifie: true, detecte: true, taux_detection: 30, peine_jours: 2, victime_prevenue: true },
    reussite_decouvert_non_detectee: { identifie: true, detecte: false, peine_jours: 2 },
    echec_critique_cache: { jet: 99.5, issue: 'echec', echec_critique: true, identifie: true, peine_jours: 2, moral_perdu: 15, taux_combat: 2 },
    echec_critique_masque: { jet: 99.5, issue: 'echec', echec_critique: true, identifie: false },
    echec_decouvert: { jet: 60, issue: 'echec', identifie: true, peine_jours: 2 },
    echec_cache_remarque: { jet: 60, issue: 'echec', identifie: false, remarque: true },
    combat_vaincu: { jet: 98.9, issue: 'combat', echec_critique: false, suite: 'combat_perdu', identifie: true },
    combat_gagne_decouvert: { suite: 'combat_gagne', identifie: true, peine_jours: 2, taux_detection: 30 },
    combat_sans_ouverture_masque: { suite: 'echec', identifie: false },
    reussite_masquee_detectee: { detecte: true, identifie: false, trace: true, taux_detection: 20 },
    reussite_critique_vol: { reussite_critique: true, detecte: false, remarque: false },
    bornes_vol: { taux_demande: 99, taux: 85, reussi: false, echec_critique: false, remarque: false }
  },
  // crime_neutraliser réel (JWT Arnie → Jean Jaaj, mains nues).
  ordre: { ok: true, taux: 28, pa_paye: 2, issue_reussite_pa_cible: 0, ancien: 'requete_requise', combat_direct: 'neutraliser_requis',
           combat_force: { taux: 0, issue: 'combat', taux_combat: 100, bataille: true, contexte_crim_affaire: true } }
};

test('Passage au combat : 10 % + 2/PER > 10, +15 garde, −10 caché, bornes 2-40 (formule = relevé serveur)', () => {
  for (const [per, garde, cache, attendu] of RELEVE.combat) assert.equal(combat(per, garde, cache), attendu, `PER ${per}`);
  assert.equal(combat(30, true, false), 40);
  assert.equal(combat(0, false, true), 2);
  for (const f of ["('combat_base', 10)", "('combat_par_per', 2)", "('combat_per_seuil', 10)", "('combat_garde', 15)", "('combat_cache', 10)",
    "('combat_min', 2), ('combat_max', 40)"]) assert.ok(sql.includes(f), f);
});

test('Détection : base de l’acte, −20 caché, −10 masqué, plancher (formule = relevé serveur) ; neutraliser 30/40/60, min 5', () => {
  for (const [base, mode, min, attendu] of RELEVE.detection) assert.equal(detection(base, mode, min), attendu, `${base} ${mode}`);
  assert.match(sql, /'detection_base', coalesce\(v_det, CASE p_mode WHEN 'mains' THEN 30 WHEN 'arme' THEN 40 ELSE 60 END\), 'detection_min', 5/);
  // Avec masque : trace sans nom ; sans masque : identifié.
  assert.match(sql, /IF f\.mode IN \('masque', 'cache_masque'\) THEN\s+UPDATE public\.crim_affaires SET detecte = true, trace = true/);
  const s = RELEVE.scenarios;
  assert.equal(s.reussite_masquee_detectee.identifie, false);
  assert.equal(s.reussite_masquee_detectee.trace, true);
  assert.equal(s.reussite_masquee_detectee.taux_detection, detection(30, 'masque'));
});

test('Neutraliser : formule historique conservée, +10 cachette, gilet −20 feu / −5 sinon, plafonds 65/75/85, PA 2/2/3', () => {
  for (const [mode, stat, crim, per, cache, gilet, attendu] of RELEVE.neutraliser)
    assert.equal(neutraliser(mode, stat, crim, per, cache, gilet), attendu, mode);
  assert.match(sql, /WHEN 'mains' THEN v_stat := 'FOR'; v_cap := 65; v_pa := 2;/);
  assert.match(sql, /WHEN 'arme'  THEN v_stat := 'DUP'; v_cap := 75; v_pa := 2;/);
  assert.match(sql, /WHEN 'feu'   THEN v_stat := 'PER'; v_cap := 85; v_pa := 3;/);
  assert.match(sql, /'taux', v_taux, 'min', 0, 'max', v_cap, 'combat', true/);
  assert.match(sql, /\('neutraliser_cache', 10\), \('neutraliser_gilet_feu', 20\), \('neutraliser_gilet_autre', 5\), \('neutraliser_carriere', 15\)/);
  // Gilet seulement revêtu (helper du lot 1) ; cible PNJ : PER réel, sinon 8.
  assert.match(sql, /v_gilet := \(ci ->> 'pj'\)::boolean AND public\.crim_objet_porte_interne\(ci ->> 'nom', 'gilet'\)/);
  assert.match(sql, /'per', coalesce\(v_pnj\.car_per, public\.crim_param_interne\('neutraliser_per_pnj', 8\)\)/);
  assert.equal(RELEVE.ordre.taux, neutraliser('mains', 8, false, 7, false, false));   // Arnie (FOR absent → 8) contre Jean Jaaj (PER 7)
});

test('Échec critique : 2 % des échecs ; sans masque identifié et −15 moral, avec masque −15 moral seulement', () => {
  assert.ok(echecCritique(99.5, 50) && !echecCritique(98.9, 50) && echecCritique(99.97, 98) && !echecCritique(99.95, 98));
  assert.equal(echecCritique(99.71, 85), true);
  assert.equal(echecCritique(99.69, 85), false);
  assert.match(sql, /v_crit_e := v_part > 0 AND v_u >= 100 - \(100 - v_taux\) \* v_part \/ 100\.0/);
  assert.match(sql, /IF NOT v_masque AND coalesce\(\(p ->> 'critique_identifie'\)::boolean, true\) THEN v_ident := true; END IF;/);
  const s = RELEVE.scenarios;
  assert.equal(s.echec_critique_cache.identifie, true);
  assert.equal(s.echec_critique_cache.moral_perdu, 15);
  assert.equal(s.echec_critique_masque.identifie, false);
  assert.equal(s.combat_vaincu.echec_critique, false);
});

test('Combat (moteur inchangé) : seulement sur un échec, vaincu = identifié, vainqueur = réussite ; perd la cachette, garde le masque', () => {
  const s = RELEVE.scenarios;
  assert.equal(s.combat_vaincu.issue, 'combat');
  assert.equal(s.combat_vaincu.suite, 'combat_perdu');
  assert.equal(s.combat_gagne_decouvert.suite, 'combat_gagne');
  assert.equal(s.combat_sans_ouverture_masque.suite, 'echec');
  assert.equal(RELEVE.ordre.combat_force.issue, 'combat');
  assert.equal(RELEVE.ordre.combat_direct, 'neutraliser_requis');
  assert.match(sql, /IF NOT v_reussi AND coalesce\(\(p ->> 'combat'\)::boolean, false\) AND p_cible IS NOT NULL THEN/);
  assert.match(sql, /PERFORM public\.crim_debusquer_interne\(a, 'combat'\);/);
  assert.match(sql, /crim_combat_issue_v1[\s\S]*CASE WHEN issue='defaite' THEN 'vaincu' ELSE 'vainqueur' END/);
  assert.match(sql, /crim_neutraliser_paye_v1/);
  assert.match(sql, /crim_neutraliser_jet_v1/);
  // Squatteurs, faune et gardes d'accès gardent l'affrontement direct.
  assert.match(sql, /IF terrain IS NULL AND \(cible IS NOT NULL OR \(pnj NOT LIKE 'faune:%' AND pnj NOT LIKE 'garde_acces:%'\)\)/);
  // Échec sans combat : la cachette n'est pas touchée (aucun DELETE de caches_pj hors combat).
  assert.equal((sql.match(/DELETE FROM public\.caches_pj/g) || []).length, 0);
});

test('Messages à la victime selon le mode : nom / « un inconnu » / « un individu masqué » (relevé serveur)', () => {
  assert.equal(RELEVE.messages[0], designation('cache', 'Arnie', 'sujet') + ' a tenté de vous neutraliser.');
  assert.equal(RELEVE.messages[1], 'Neutralisé(e) par ' + designation('cache_masque', 'Arnie', 'complement') + '.');
  assert.equal(RELEVE.messages[2], 'Arnie / Arnie');
  assert.match(sql, /'msg_reussite', 'Vous avez été neutralisé\(e\) par \{auteur\}\./);
  assert.match(sql, /'msg_echec', '\{Auteur\} a tenté de vous neutraliser\.'/);
  // PNJ : l'employeur est prévenu et porte plainte (contre X sauf visage découvert).
  assert.match(sql, /v_cible_plainte := CASE WHEN f\.mode = 'decouvert' THEN f\.auteur ELSE 'X' END;/);
  assert.match(sql, /'origine', 'crim_affaire', 'affaire', f\.id/);
});

test('Peines : identifié = recherché, 2 jours (Républia), paramètre par empire, barème des arrestations aligné', () => {
  const p = RELEVE.peines;
  assert.equal(p.assassinat_republic, 2);
  assert.equal(p.assassinat_soviet, 2);              // les autres empires reprennent Républia
  assert.equal(p.tentative_narco, 2);
  assert.equal(p.bareme_assassinat_soviet, 2);       // peine_acte_interne (arrestation) : 2 j au lieu de la catégorie « crime » 8 j
  assert.equal(p.bareme_vol_republic, 1);            // les autres actes ne bougent pas
  assert.match(sql, /\('peine_jours_assassinat_republic', 2\), \('peine_jours_tentative_assassinat_republic', 2\)/);
  assert.match(sql, /'acte_peine_reussite', 'assassinat', 'acte_peine_echec', 'tentative_assassinat'/);
  assert.match(sql, /crim_peine_empire_v1/);
  for (const k of ['reussite_decouvert_detectee', 'echec_critique_cache', 'echec_decouvert', 'combat_gagne_decouvert'])
    assert.equal(RELEVE.scenarios[k].peine_jours, 2, k);
});

test('Résolution commune : une seule fonction, dissuasion #135 une seule fois, bornes, réussite critique optionnelle', () => {
  assert.equal((sql.match(/CREATE OR REPLACE FUNCTION public\.crim_resoudre_interne\(/g) || []).length, 1);
  assert.equal((sql.match(/securite_malus_lieu_interne\(/g) || []).length, 1);
  assert.doesNotMatch(sql, /crime_detecter_interne\(/);
  assert.match(sql, /v_taux := greatest\(coalesce\(\(p ->> 'min'\)::numeric, 0\), least\(coalesce\(\(p ->> 'max'\)::numeric, 100\), \(p ->> 'taux'\)::numeric - v_dis\)\)::integer;/);
  const b = RELEVE.scenarios.bornes_vol;
  assert.equal(borne(b.taux_demande, 5, 85), b.taux);
  assert.equal(RELEVE.scenarios.reussite_critique_vol.detecte, false);
  assert.equal(RELEVE.scenarios.reussite_critique_vol.remarque, false);
  // Visage découvert : la victime connaît toujours son agresseur.
  assert.match(sql, /IF v_mode = 'decouvert' AND v_remarque AND NOT v_combat/);
  // Affaire enregistrée (lot 6) avec plafond d'identification 5 / 15 %.
  assert.match(sql, /\('plafond_enquete_reussite', 5\), \('plafond_enquete_echec', 15\)/);
  // Fonctions internes fermées aux joueurs ; seul crime_neutraliser est ouvert.
  assert.match(sql, /'crim_resoudre_interne\(text,text,text,jsonb\)', 'crim_resoudre_suite_interne\(bigint,text\)'/);
  assert.match(sql, /FOREACH f IN ARRAY ARRAY\['crime_neutraliser\(text,text,uuid\)', 'crime_neutraliser\(text,text,integer\)'\]/);
});

test('Écran : aucun calcul de taux pour Neutraliser ; cible masquée visée par son jeton', () => {
  assert.equal((js.match(/Math\.random/g) || []).length, 1);   // identifiant de requête de secours seulement
  assert.doesNotMatch(js, /neutraliserTaux/);
  assert.match(ill, /if \(!estDepute && !estSquatter && typeof ouvrirNeutraliser === 'function'\) \{ ouvrirNeutraliser\(encodedCible\); return; \}/);
  assert.match(multi, /\.\.\.\(masqueAnonyme\(p\) \? \{ masque: true, jeton: p\.jeton \|\| null \} : \{\}\)/);
  assert.match(pnj, /if \(pnj && pnj\.isPJ\) \{/);
  const appels = [];
  const ctx = { console, setTimeout() {}, setInterval() {}, NEUTRALISER_MODES: { mains: { label: 'À mains nues', paPJ: 2, sousTypes: null } },
    sbRpc: async (fn, p) => { appels.push([fn, p]); return { ok: true, issue: 'echec', identifie: false }; }, showToast() {} };
  ctx.globalThis = ctx; ctx.window = ctx;
  const el = () => ({ textContent: '', innerHTML: '', classList: { add() {}, remove() {} } });
  ctx.document = { getElementById: el, readyState: 'loading', addEventListener() {} };
  vm.createContext(ctx);
  vm.runInContext('var state = { country: "republic", char: { name: "Arnie" }, inventory: [] };', ctx);
  vm.runInContext(js, ctx);
  const C = ctx.RPCriminalite;
  const jeton = '0e1f2a3b-4c5d-4e6f-8a9b-0c1d2e3f4a5b';
  assert.equal(C.identifiantCible({ name: 'Individu masqué n°1', isPJ: true, masque: true, jeton }), jeton);
  assert.equal(C.identifiantCible({ name: 'Jean Jaaj', isPJ: true }), 'Jean Jaaj');
  assert.equal(C.identifiantCible({ name: 'Igor (PNJ)', socleId: 'employe-12' }), 'employe-12');
  const enc = encodeURIComponent(JSON.stringify({ name: 'Individu masqué n°1', isPJ: true, masque: true, jeton }));
  return ctx.crimNeutraliserConfirmer(enc, 'mains').then(() => {
    assert.equal(appels.length, 1);
    assert.equal(appels[0][0], 'crime_neutraliser');
    assert.equal(appels[0][1].p_cible, jeton);
    assert.equal(appels[0][1].p_mode, 'mains');
    assert.match(appels[0][1].p_requete, /^[0-9a-f-]{36}$/);
  });
});
