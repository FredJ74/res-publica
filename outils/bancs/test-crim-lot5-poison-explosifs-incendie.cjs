'use strict';
// Criminalité, lot 5 : empoisonnement, explosifs, incendie (GAME-DESIGN-CRIMINALITE.md §§ 6, 9, 10, 11, 15) et brouillard
// (GAME-DESIGN-MALADIES-CLIMAT.md § 6). Trois niveaux, sans se faire passer l'un pour l'autre :
//  1. formules du document recalculées ici et comparées aux valeurs RENDUES PAR LA PRODUCTION lors de l'essai annulé du 19/11
//     (crime_empoisonner, crime_incendier, crime_explosifs réels sous JWT d'Angie Porcelana, victime Jean Jaaj, banque nationale
//     de la capitale, jets imposés, brouillard et orage insérés dans climat_evenements puis annulés) : relevé recopié ci-dessous ;
//  2. lecture de la migration (paramètres, résolution commune, raccords du brouillard, droits) ;
//  3. module d'écran chargé dans une machine virtuelle (aucun calcul, pop-ups cpj-*, appels RPC).
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const racine = path.join(__dirname, '../..');
const sql = fs.readFileSync(path.join(racine, 'migrations/20261120010000_crim_lot5_poison_explosifs_incendie.sql'), 'utf8');
const js = fs.readFileSync(path.join(racine, 'plateau-criminalite.js'), 'utf8');
const rumeurs = fs.readFileSync(path.join(racine, 'plateau-actions-illegales-rumeurs.js'), 'utf8');

// Formules du document.
const borne = (v, a, b) => Math.max(a, Math.min(b, v));
const dis3 = (dis) => Math.max(0, Math.trunc((dis - 50) / 3));
const POISON = { parapluie: 5, polonium: -10, vipere: 0 };
const poison = (dis, per, cache, carriere, type, aBu, pays) => 35 + dis3(dis) - 3 * (per - 8) + (cache ? 10 : 0) + (carriere === 'criminal_c' ? 15 : 0)
  + (type === 'ghb' ? (aBu ? 10 : -10) : POISON[type]) + ({ narco: 20, soviet: -10 }[pays] || 0);
const explosifs = (dis, int, cache, carriere, officiel) => 35 + dis3(dis) + 2 * (int - 8) + (cache ? 10 : 0) + (carriere === 'criminal_c' ? 15 : 0) - (officiel ? 30 : 0);
const incendie = (dis, cache, carriere, bidon, orage, canicule) => 30 + dis3(dis) + (cache ? 10 : 0) + (carriere === 'criminal_c' ? 15 : 0)
  + (bidon ? 15 : 0) - (orage ? 15 : 0) + (canicule ? 15 : 0);
const palier = (jet, taux) => jet < taux / 2 ? 'totale' : jet < taux ? 'partielle' : jet < taux + (100 - taux) / 2 ? 'echec_partiel' : 'echec_total';
const jours = (jet, taux) => jet >= taux ? 0 : jet < taux * 0.5 ? 3 : jet < taux * 0.8 ? 2 : 1;
const detection = (base, mode, min) => Math.max(min, base - (/cache/.test(mode) ? 20 : 0) - (/masque/.test(mode) ? 10 : 0));
// Échec critique : part haute des échecs (résolution commune).
const critique = (jet, taux, part) => jet >= 100 - (100 - taux) * part / 100;

// Relevé de l'essai en production (transaction annulée, 19/11/2026). Angie : DIS 95, INT 15, carrière intel, visage découvert,
// aucune dissuasion à la banque. Sa DIS baisse de 10 à chaque identification par détection (règle existante).
const RELEVE = {
  f_poison: [43, 63, 73, 15, 36], f_explo: [34, 56, 45], f_incendie: [60, 40, 64],
  paliers: ['totale', 'partielle', 'echec_partiel', 'echec_total'], jours: [3, 2, 1, 0], officiel: [true, false],
  anciennes: ['requete_requise', 'requete_requise', 'requete_requise'], dissuasion: 0, mode: 'decouvert',
  p1: { taux: 43, jet: 0, palier: 'totale', issue: 'reussite', taux_detection: 25, detecte: false, identifie: false, cible: 'Jean Jaaj', effet: true,
    mails: [{ t: 'Vous vous sentez mal...', c: 'Votre esprit devient confus. Vous avez l' }], impact: ['totale'],
    affaire: { acte: 'empoisonner', cible: 'Jean Jaaj', issue: 'reussite', remarque: true, identifie: false } },
  p2: { palier: 'echec_total', crit: true, ident: true, peine: 2, effet: false, moral_delta: 15, recherche: 'tentative_empoisonnement' },
  p3: { taux: 63, a_bu: true, palier: 'echec_partiel', effet: true, ident: false },
  p4_brouillard: { taux: 53, brouillard: true, td: 5, det: true, ident: true, detection_base_affaire: 5 },
  i1: { taux: 51, jet: 10, jours: 3, bidon: true, orage: true, brouillard: true, taux_detection: 50, identifie: true, peine_jours: 2, carburant_restant: 1, ferme: [{ j: 3, motif: 'incendie' }] },
  i2: { taux: 53, issue: 'echec', jours: 0, td: null, ident: false, bidon: true, crit: false },
  e1: { taux: 27, issue: 'echec', crit: false, ident: false, hp: 100, prem: false },
  e2: { issue: 'echec', crit: true, ident: true, hp: 15, prem: true, moral_delta: 15, jean_hp: 100, peine: 2 },
  e3: { issue: 'reussite', td: 65, det: false, victimes: 1, jean_hp: 15, ferme: [5] },
  flagrant: 0
};

test('Empoisonnement : 35 + DIS/3 > 50 − 3/PER > 8 (+3 en dessous) +10 caché +15 criminelle, poisons, pays, bornes 5-85', () => {
  const f = RELEVE.f_poison;
  assert.equal(poison(95, 7, false, 'intel', 'ghb', false, 'republic'), f[0]);
  assert.equal(poison(95, 7, false, 'intel', 'ghb', true, 'republic'), f[1]);
  assert.equal(poison(50, 12, true, 'criminal_c', 'parapluie', false, 'narco'), f[2]);
  assert.equal(poison(40, 8, false, 'x', 'polonium', false, 'soviet'), f[3]);
  assert.equal(poison(53, 8, false, 'x', 'vipere', false, 'khalija'), f[4]);
  assert.equal(borne(poison(100, 2, true, 'criminal_c', 'parapluie', true, 'narco'), 5, 85), 85);
  assert.equal(borne(poison(0, 20, false, 'x', 'polonium', false, 'soviet'), 5, 85), 5);
  assert.match(sql, /\('poison_base', 35\), \('poison_min', 5\), \('poison_max', 85\), \('poison_carriere', 15\), \('poison_cache', 10\)/);
  assert.match(sql, /\('poison_parapluie', 5\), \('poison_ghb_bu', 10\), \('poison_ghb_sobre', -10\),\s+\('poison_polonium', -10\), \('poison_vipere', 0\), \('poison_narco', 20\), \('poison_soviet', -10\)/);
  assert.equal(RELEVE.p1.taux, poison(95, 7, false, 'intel', 'ghb', false, 'republic'));
  assert.equal(RELEVE.p3.taux, poison(95, 7, false, 'intel', 'ghb', true, 'republic'));
});

test('GHB : « a bu dans la journée » = un verre compté aujourd’hui (verres_du_jour)', () => {
  assert.match(sql, /FROM public\.verres_du_jour WHERE nom = p_nom AND jour = \(now\(\) AT TIME ZONE 'Europe\/Paris'\)::date AND n > 0/);
  assert.equal(RELEVE.p3.a_bu, true);
  assert.equal(RELEVE.p3.taux - RELEVE.p1.taux, 20);
});

test('Empoisonnement : quatre paliers conservés, anonymat par nature, cachette = bonus (plus exigée)', () => {
  assert.deepEqual(RELEVE.paliers, [palier(10, 43), palier(30, 43), palier(60, 43), palier(80, 43)]);
  assert.equal(RELEVE.p1.palier, palier(0, 43));
  assert.equal(RELEVE.p3.palier, palier(70, 63));
  assert.equal(RELEVE.p3.effet, true);
  // Message mystérieux seulement, jamais de nom ; ni identification par la victime, ni échec remarqué.
  assert.deepEqual(RELEVE.p1.mails.map(m => m.t), ['Vous vous sentez mal...']);
  assert.equal(RELEVE.p1.affaire.identifie, false);
  assert.match(sql, /'remarque_echec', 0, 'decouvert_identifie', false, 'msg_reussite', '', 'msg_echec', ''/);
  assert.match(sql, /'MYSTÈRE : ' \|\| v_victime \|\| ' se sent soudainement très mal\.\.\.'/);
  assert.doesNotMatch(sql, /caches_pj/);
  assert.match(sql, /v_mode IN \('cache', 'cache_masque'\)/);
});

test('Fin du « recherché d’office » : échec critique 2 % des échecs (identifié sans masque, −15 moral), pas de flagrant délit', () => {
  assert.ok(critique(99.99, 43, 2));
  assert.ok(!critique(98, 43, 2));
  const p2 = RELEVE.p2;
  assert.equal(p2.crit, true); assert.equal(p2.ident, true); assert.equal(p2.moral_delta, 15); assert.equal(p2.peine, 2);
  assert.equal(p2.recherche, 'tentative_empoisonnement');
  assert.equal(RELEVE.p3.ident, false);
  assert.equal(RELEVE.flagrant, 0);
  assert.doesNotMatch(sql, /flagrant_delit_poser_interne|crime_rechercher_interne|crime_detecter_interne|securite_malus_lieu_interne/);
  assert.match(sql, /'acte_peine_reussite', 'empoisonnement', 'acte_peine_echec', 'tentative_empoisonnement', 'type_recherche', 'crime'/);
});

test('Détection après réussite : poison 25 (min 5), explosifs 65 (min 30), incendie 70 (min 20), −20 caché −10 masqué', () => {
  assert.equal(RELEVE.p1.taux_detection, detection(25, 'decouvert', 5));
  assert.equal(RELEVE.e3.td, detection(65, 'decouvert', 30));
  assert.equal(detection(65, 'cache_masque', 30), 35);
  assert.equal(detection(65, 'cache_masque', 30) - 20, 15); // brouillard : la borne de 30 reprend le dessus
  assert.equal(detection(70, 'cache_masque', 20), 40);
  assert.equal(detection(25, 'cache', 5), 5);
  assert.equal(RELEVE.i2.td, null);
  assert.match(sql, /\('explosifs_detection', 65\), \('explosifs_detection_min', 30\)/);
  assert.match(sql, /\('incendie_detection', 70\), \('incendie_detection_min', 20\)/);
  assert.match(sql, /\('poison_detection', 25\)/);
});

test('Explosifs : 35 + DIS/3 > 50 + 2/INT ± 8 +10 caché +15 criminelle −30 officiel, 5-75 ; explosion prématurée 10 % des échecs', () => {
  const f = RELEVE.f_explo;
  assert.equal(explosifs(95, 15, false, 'intel', true), f[0]);
  assert.equal(explosifs(50, 6, true, 'criminal_c', false), f[1]);
  assert.equal(explosifs(80, 8, false, 'x', false), f[2]);
  assert.equal(borne(explosifs(100, 20, true, 'criminal_c', false), 5, 75), 75);
  assert.equal(RELEVE.e1.taux, explosifs(75, 15, false, 'intel', true)); // DIS 95 − 2 × 10 après deux identifications
  assert.ok(critique(99, 27, 10)); assert.ok(!critique(80, 27, 10));
  assert.deepEqual([RELEVE.e1.crit, RELEVE.e1.ident, RELEVE.e1.hp], [false, false, 100]);
  const e2 = RELEVE.e2;
  assert.deepEqual([e2.crit, e2.prem, e2.ident, e2.hp, e2.moral_delta, e2.jean_hp], [true, true, true, 15, 15, 100]);
  const e3 = RELEVE.e3;
  assert.deepEqual([e3.issue, e3.jean_hp, e3.victimes, e3.ferme[0]], ['reussite', 15, 1, 5]);
  assert.match(sql, /\('explosifs_officiel', 30\), \('explosifs_critique_part', 10\)/);
  assert.match(sql, /'critique_echec_part', public\.crim_param_interne\('explosifs_critique_part', 10\)/);
});

test('Incendie : 30 + DIS/3 > 50 +10 caché +15 criminelle +15 bidon −15 orage +15 canicule, 5-80 ; fermeture 1-3 j selon le jet', () => {
  const f = RELEVE.f_incendie;
  assert.equal(incendie(95, false, 'intel', true, false, false), f[0]);
  assert.equal(incendie(50, true, 'criminal_c', false, true, false), f[1]);
  assert.equal(incendie(62, false, 'x', true, false, true), f[2]);
  assert.equal(borne(incendie(100, true, 'criminal_c', true, false, true), 5, 80), 80);
  assert.deepEqual(RELEVE.jours, [jours(10, 60), jours(40, 60), jours(55, 60), jours(60, 60)]);
  // Essai : orage + brouillard, bidon consommé (2 → 1), DIS 85.
  assert.equal(RELEVE.i1.taux, incendie(85, false, 'intel', true, true, false) + 10);
  assert.equal(RELEVE.i1.jours, jours(10, 51));
  assert.equal(RELEVE.i1.carburant_restant, 1);
  assert.equal(RELEVE.i2.taux, incendie(75, false, 'intel', true, false, false));
  assert.match(sql, /inventaire_retirer\(inventory, 'carburant', 1\)/);
  assert.match(sql, /crim_climat_actif_interne\('orage', m\.country, m\.current_city\)/);
  assert.match(sql, /crim_climat_actif_interne\('canicule', m\.country, m\.current_city\)/);
  assert.match(sql, /e\.type = p_type AND e\.pays = p_pays AND e\.ville = p_ville\s+AND NOT e\.annule AND e\.alerte_le IS NOT NULL AND now\(\) >= e\.debut AND now\(\) < e\.fin/);
});

test('Brouillard : +10 de réussite et −20 de détection dans la résolution commune (tous les actes)', () => {
  const p4 = RELEVE.p4_brouillard;
  assert.equal(p4.taux, poison(95, 7, false, 'intel', 'polonium', true, 'republic') + 10);
  assert.equal(p4.td, Math.max(5, 25 - 20));
  assert.equal(p4.detection_base_affaire, 5);
  assert.equal(RELEVE.i1.taux_detection, 70 - 20);
  for (const m of ['crim_brouillard_decl_v1', 'crim_brouillard_v1', 'crim_brouillard_taux_v1', 'crim_brouillard_retour_v1'])
    assert.ok(sql.includes("'" + m + "'"), m);
  assert.match(sql, /climat_brouillard_modificateurs_interne\(a\.country, a\.current_city\)/);
});

test('Résolution commune seulement ; anciennes signatures remplacées ; droits', () => {
  assert.equal((sql.match(/public\.crim_resoudre_interne\('(empoisonner|utiliser_explosifs|incendier)'/g) || []).length, 3);
  assert.deepEqual(RELEVE.anciennes, ['requete_requise', 'requete_requise', 'requete_requise']);
  for (const f of ['crime_empoisonner(text,uuid)', 'crime_explosifs(text,uuid)', 'crime_incendier(text,uuid)']) assert.ok(sql.includes("'" + f + "'"), f);
  assert.doesNotMatch(sql, /random\(\) \* 100|crime_tracer_interne/);
});

test('Écran : plus d’estimation ni de prérequis « Se cacher », pop-ups cpj-*, appels serveur', () => {
  assert.doesNotMatch(rumeurs, /MALUS_CENTRE_POUVOIR|confirmerIncendier|confirmerUtiliserExplosifs|confirmerEmpoisonnement|explosifBlesse|ouvrirModalArrestation\('tentative_empoisonnement'\)/);
  assert.match(rumeurs, /function doIncendier\(\) \{\n  if \(typeof crimOuvrirSabotage === 'function'\) crimOuvrirSabotage\('incendie'\);/);
  assert.match(rumeurs, /function ouvrirModalEmpoisonner\(\) \{\n  if \(typeof crimOuvrirEmpoisonner === 'function'\) crimOuvrirEmpoisonner\(\);/);
  assert.doesNotMatch(js, /Math\.random\(\)\s*\*\s*100|taux\s*=\s*\d/);

  const appels = [];
  const toasts = [];
  const dom = { innerHTML: '', textContent: '', classList: { add() {}, remove() {} } };
  const reponses = {
    crim_presents: { ok: true, presents: [{ name: 'Moi' }, { name: 'Jean Jaaj', masque: false }, { name: 'Individu masqué n°2', masque: true, jeton: '11111111-1111-4111-8111-111111111111' }] },
    crime_empoisonner: { ok: true, palier: 'totale', issue: 'reussite', identifie: false, trace: false },
    crime_explosifs: { ok: true, issue: 'echec', echec_critique: true, explosion_prematuree: true, identifie: true, peine_jours: 2, hp: 15 },
    crime_incendier: { ok: true, issue: 'reussite', jours: 3, bidon: true, identifie: false }
  };
  const g = {
    document: { getElementById: () => dom, readyState: 'loading', addEventListener() {} },
    state: { country: 'republic', inventory: [], char: { name: 'Moi' }, currentBuilding: 'banque-nationale' },
    BUILDINGS: { 'banque-nationale': { name: 'Banque nationale' } },
    showToast: (t, b, ok) => toasts.push([t, b, ok]),
    sbRpc: async (fn, p) => { appels.push([fn, p]); return reponses[fn]; },
    crypto: { randomUUID: () => '00000000-0000-4000-8000-000000000000' }
  };
  g.window = g; g.globalThis = g;
  vm.runInNewContext(js.replace(/\(typeof window !== 'undefined' \? window : globalThis\);\s*$/, '(globalThis);'), g);
  return (async () => {
    await g.crimOuvrirEmpoisonner();
    assert.match(dom.innerHTML, /class="cpj-dialogue"/);
    assert.match(dom.innerHTML, /Jean Jaaj[\s\S]*Individu masqué n°2/);
    assert.doesNotMatch(dom.innerHTML, />Moi</);
    assert.doesNotMatch(dom.innerHTML.replace(/onclick="[^"]*"/g, ""), /\d+ ?%/);
    const enc = encodeURIComponent(JSON.stringify({ name: 'Individu masqué n°2', isPJ: true, masque: true, jeton: '11111111-1111-4111-8111-111111111111' }));
    await g.crimEmpoisonnerConfirmer(enc);
    assert.deepEqual(JSON.parse(JSON.stringify(appels.at(-1))), ['crime_empoisonner', { p_cible: '11111111-1111-4111-8111-111111111111', p_requete: '00000000-0000-4000-8000-000000000000' }]);
    assert.equal(toasts.at(-1)[0], 'Poison administré');
    g.crimOuvrirSabotage('explosifs');
    assert.match(dom.innerHTML, /Déclencher — 3 PA/);
    assert.doesNotMatch(dom.innerHTML.replace(/onclick="[^"]*"/g, ""), /\d+ ?%/);
    await g.crimSabotageConfirmer('explosifs');
    assert.deepEqual(JSON.parse(JSON.stringify(appels.at(-1))), ['crime_explosifs', { p_nom_batiment: 'Banque nationale', p_requete: '00000000-0000-4000-8000-000000000000' }]);
    assert.equal(toasts.at(-1)[0], 'Explosion prématurée !');
    assert.match(toasts.at(-1)[1], /identifié\(e\)[\s\S]*2 jour/);
    assert.equal(g.state.hp, 15);
    await g.crimSabotageConfirmer('incendie');
    assert.equal(appels.at(-1)[0], 'crime_incendier');
    assert.match(toasts.at(-1)[1], /Banque nationale est fermé 3 jour\(s\)\. Un bidon de carburant a été utilisé\./);
  })();
});
