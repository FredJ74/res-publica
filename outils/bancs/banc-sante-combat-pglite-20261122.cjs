'use strict';
// Santé — lot « combat » (Fred, 22/11/2026, après-midi, GAME-DESIGN-SANTE-20261122.md, points 1, 2, 3, 15, 19), migration
// 20261122231000, dans un vrai PostgreSQL local (PGlite). Base : copies de production du combat et de la forêt (fixtures
// foret-combat-*), migration forêt 20261122210000 (appliquée en production), fixture sante-combat-ancrages (copies de production
// et bouchons d'ancrage portant les lignes exactes de production), socle Santé 20261122230000, puis la migration du lot.
//  - robustesse : coup de 10 PA → 8 à Santé 100, 12 à Santé 10 ; morsure puis robustesse ; Santé perdue = PA perdus ;
//  - coma = PA 0 (la Santé n'est plus mise à 0), plus aucun blocage à Santé 0 ;
//  - meute : dernier loup enfui après deux morts, état « fuite » au dernier round, butin par loup tué (même en défaite),
//    reste d'une pile non rangée envoyé au sas ;
//  - regen_jour / stats_affaiblies sans effet ; aucune Santé modifiée par la migration.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : banc exécuté par son workflow dédié (PGLITE_DIR)', { skip: true }, () => {}); return; }

const UID = { 'Tom Tom': '00000000-0000-0000-0000-000000000001', Arnie: '00000000-0000-0000-0000-000000000002' };
const SOCLE = 'migrations/20261122230000_sante_socle.sql';
const MIGRATION = 'migrations/20261122231000_sante_combat.sql';

async function base({ hp = { 'Tom Tom': 100, Arnie: 100 }, vol = 30, pa = 30 } = {}) {
  const db = new PGlite();
  for (const f of ['outils/bancs/fixtures/foret-combat-socle.sql.txt', 'outils/bancs/fixtures/foret-combat-ouverture.sql.txt',
    'migrations/20261122210000_foret_groupe_combat_meute.sql', 'outils/bancs/fixtures/sante-combat-ancrages.sql.txt']) await db.exec(lire(f));
  const armes = { 'Tom Tom': [{ name: 'Couteau de poche', type: 'arme' }], Arnie: [{ name: 'Revolver .38', type: 'arme' }] };
  for (const [n, u] of Object.entries(UID)) {
    await db.query('INSERT INTO personnages VALUES ($1, $2)', [n, u]);
    await db.query(`INSERT INTO personnages_donnees (name, country, current_city, current_building, current_room, pa, hp, stats, inventory)
      VALUES ($1, 'soviet', 'ville_b', 'zone-production', 'foret_vue_3', $2, $3, $4, $5)`,
      [n, pa, hp[n], JSON.stringify({ VOL: vol, PER: 10, DUP: 10, INT: 8, CHA: 8 }), JSON.stringify(armes[n])]);
  }
  await db.query("INSERT INTO groupes_pj_adhesions VALUES ('Arnie', 'Tom Tom')");
  await db.exec('SET check_function_bodies = on');   // comme en production : chaque fonction réécrite est compilée
  await db.exec(lire(SOCLE));
  await db.exec(lire(MIGRATION));
  return db;
}
const un = async (db, sql, p) => (await db.query(sql, p)).rows[0];
const en = (db, qui) => db.query("SELECT set_config('test.uid', $1, false)", [qui ? UID[qui] : '']);
const perso = (db, n) => un(db, 'SELECT pa, hp, regen_jour, stats_affaiblies FROM personnages_donnees WHERE name = $1', [n]);
const meute = async db => (await un(db, "SELECT sovarka_foret_faune_creer_interne('Tom Tom', 3, 'meute') r")).r;
async function ouvrir(db, pnj) {
  await en(db, 'Tom Tom');
  const o = (await un(db, "SELECT combat_ouvrir($1, 'arme', gen_random_uuid()) r", [pnj])).r;
  assert.equal(o.ok, true, JSON.stringify(o));
  return o.bataille;
}
const eng = async (db, b, qui) => Number((await un(db, 'SELECT id FROM batailles_engagements WHERE bataille_id = $1 AND (personnage = $2 OR pnj_id = $2)', [b, qui])).id);
async function frapper(db, b, att, cib, degre) {
  const a = { degre, mode: 'cac', att_eng: await eng(db, b, att), cib_eng: await eng(db, b, cib), cib_camp: 'acteur', cib_pj: true, cib_nom: cib };
  return (await un(db, 'SELECT militaire_bataille_appliquer($1, $2::jsonb, 1) r', [b, JSON.stringify([a])])).r[0];
}
const qte = async (db, qui, cle) => Number((await un(db,
  "SELECT coalesce(sum((i->>'qty')::int), 0) n FROM personnages_donnees, jsonb_array_elements(inventory) i WHERE name = $1 AND i->>'stackKey' = $2", [qui, cle])).n);
const sas = async (db, qui, cle) => Number((await un(db,
  "SELECT coalesce(sum(((data#>>'{}')::jsonb->>'qty')::int), 0) n FROM objets_recus WHERE destinataire = $1 AND (data#>>'{}')::jsonb->>'stackKey' = $2", [qui, cle])).n);

test('migration rejouable, marques posées une fois, aucune Santé modifiée (point 16)', async () => {
  const db = await base({ hp: { 'Tom Tom': 37, Arnie: 0 } });
  await db.exec(lire(MIGRATION));
  assert.equal((await perso(db, 'Tom Tom')).hp, 37); assert.equal((await perso(db, 'Arnie')).hp, 0);
  const marques = {
    'militaire_bataille_appliquer(bigint,jsonb,integer)': ['sante_combat_robustesse_v1', 'sante_combat_declaration_v1', 'sante_combat_rapport_v1', 'foret_morsure_v1'],
    'police_combat_personnage_interne(text,text,text,text,integer,text)': ['sante_police_robustesse_v1', 'sante_police_agent_robustesse_v1', 'sante_zero_libre_v1'],
    'militaire_bataille_neutralisation_terminale_interne(bigint,jsonb,integer)': ['sante_coma_pa_v1'],
    'militaire_bataille_round(bigint)': ['foret_meute_derniere_fuite_v1', 'combat_rapport_etats_fin_v1'],
    'militaire_bataille_arbitrer_groupes(bigint,integer)': ['sante_zero_libre_a_v1', 'sante_zero_libre_b_v1'],
    'impact_marquer_traite(text,integer)': ['sante_sans_regen_v1', 'sante_sans_affaiblies_poison_v1'],
    'terrain_occupation_action_preparer(text,text)': ['sante_zero_libre_v1', 'sante_sans_affaiblies_cha_v1', 'sante_sans_affaiblies_dup_v1'],
  };
  for (const f of ['acces_forcer_passage(uuid,text)', 'chantier_commande(text,text,text,jsonb)', 'groupe_combattants_interne(text,text,bigint)',
    'jardins_ouvriers_acteur_interne(text)', 'local_louer(uuid,text)', 'militaire_bataille_combattants(bigint,text)', 'militaire_bataille_etat(bigint)',
    'militaire_bataille_recruter_metier_interne(bigint,text,text,text,text)', 'navigation_disponibilite_interne(text)', 'poissonniere_acteur_interne(text)',
    'pret_national_contracter_versionne(numeric,integer,text,text,uuid)', 'sovarka_reunion_evenement(uuid,text,text,text)',
    'terrain_acquisition_commande(text,text,jsonb,uuid)', 'terrain_lot_loyer_fixer(text,text,integer)', 'terrain_lots_acte(text,text,jsonb,text[])',
    'vendre_materiaux_chantier(text,text,text,text,integer,integer)']) marques[f] = ['sante_zero_libre_v1'];
  for (const f of ['jauges_ordre_executer(text,uuid,jsonb)', 'militaire_subtiliser_tenter(text)', 'terrain_negociation_preparer(text)',
    'terrain_squatteurs_don(text,integer,text,uuid)']) marques[f] = ['sante_sans_affaiblies_v1'];
  marques['militaire_bataille_commande_interne(bigint,text,integer,uuid)'] = ['sante_zero_libre_v1'];
  let gardes = 0;
  for (const [f, ms] of Object.entries(marques)) {
    const d = (await un(db, `SELECT pg_get_functiondef('public.${f}'::regprocedure) d`)).d;
    for (const m of ms) assert.ok(d.includes(m), f + ' : ' + m);
    assert.ok(!/coalesce\((p|a|d|m|pd|v_pj)?\.?hp, ?(0|100)\) ?(<=|>) ?0/.test(d), f + ' : plus aucune garde sur la Santé');
    gardes++;
  }
  assert.equal(gardes, 28);
  const cmd = (await un(db, "SELECT pg_get_functiondef('public.militaire_bataille_commande_interne(bigint,text,integer,uuid)'::regprocedure) d")).d;
  assert.equal(cmd.split('sante_zero_libre_v1').length - 1, 2, 'les deux gardes du commandement');
});

test('robustesse et blessures : un coup de 10 PA en retire 8 à Santé 100, 12 à Santé 10 ; Santé perdue = PA perdus', async () => {
  const db = await base({ hp: { 'Tom Tom': 100, Arnie: 10 }, pa: 20 });
  const b = await ouvrir(db, (await meute(db)).pnj);
  // Arnie frappe Tom (partielle_2 : 50 % de 20 PA = 10 PA bruts) : facteur 0,8.
  let r = await frapper(db, b, 'Arnie', 'Tom Tom', 'partielle_2');
  assert.equal(r.perte, 8); assert.equal(r.perte_brute, 10); assert.equal(r.sante_perdue, 8);
  assert.deepEqual([(await perso(db, 'Tom Tom')).pa, (await perso(db, 'Tom Tom')).hp], [12, 92]);
  // Tom frappe Arnie (Santé 10) : facteur 1,24 → 12 PA ; Santé 10 − 12 → plancher 0.
  r = await frapper(db, b, 'Tom Tom', 'Arnie', 'partielle_2');
  assert.equal(r.perte, 12); assert.equal(r.sante_perdue, 10);
  assert.deepEqual([(await perso(db, 'Arnie')).pa, (await perso(db, 'Arnie')).hp], [8, 0]);
  // Morsure puis robustesse : 10 bruts → 3 (un tiers) → 2 à Santé 92 (facteur 0,832).
  await db.query("UPDATE personnages_donnees SET pa = 20 WHERE name = 'Tom Tom'");
  r = await frapper(db, b, c(await db.query("SELECT id FROM pnj_membres WHERE nom = 'Loup 2'")), 'Tom Tom', 'partielle_2');
  assert.equal(r.perte_brute, 3); assert.equal(r.perte, 2);
  assert.deepEqual([(await perso(db, 'Tom Tom')).pa, (await perso(db, 'Tom Tom')).hp], [18, 90]);
  // Paramètre MJ : 2 points de Santé par PA.
  await db.query("UPDATE sante_parametres SET valeur = 2 WHERE cle = 'blessure_sante_par_pa'");
  r = await frapper(db, b, 'Arnie', 'Tom Tom', 'partielle_2');
  assert.equal(r.perte, 8, '9 bruts × 0,86'); assert.equal(r.sante_perdue, 16);
  // Les PNJ n'ont pas de Santé : un loup perd ses PA bruts.
  const loup = c(await db.query("SELECT id FROM pnj_membres WHERE nom = 'Loup 3'"));
  const a = { degre: 'partielle_2', mode: 'cac', att_eng: await eng(db, b, 'Tom Tom'), cib_eng: await eng(db, b, loup), cib_camp: 'defenseur', cib_pj: false, cib_nom: 'Loup 3' };
  r = (await un(db, 'SELECT militaire_bataille_appliquer($1, $2::jsonb, 1) r', [b, JSON.stringify([a])])).r[0];
  assert.equal(r.perte, 4); assert.equal(r.sante_perdue, undefined);
});
function c(res) { return res.rows[0].id; }

test('coma = PA 0 : la Santé n’est plus mise à 0 ; Santé 0 ne bloque plus rien', async () => {
  const db = await base({ hp: { 'Tom Tom': 0, Arnie: 50 }, pa: 20 });
  const b = await ouvrir(db, (await meute(db)).pnj);
  // Santé 0 : Tom est engagé et combat (combattants, groupe).
  const comb = (await db.query("SELECT nom FROM militaire_bataille_combattants($1, 'acteur')", [b])).rows.map(x => x.nom).sort();
  assert.deepEqual(comb, ['Arnie', 'Tom Tom']);
  assert.equal((await db.query("SELECT * FROM groupe_combattants_interne('Tom Tom')")).rows.length, 2);
  // Arnie mis à 0 PA (critique) : Santé 50 − 20 = 30, et non 0 ; son état au rapport : « coma ».
  const r = await frapper(db, b, 'Tom Tom', 'Arnie', 'critique');
  assert.equal(r.pa_apres, 0);
  assert.deepEqual([(await perso(db, 'Arnie')).pa, (await perso(db, 'Arnie')).hp], [0, 30]);
  const l = (await un(db, "SELECT combat_rapport_lignes_interne($1, 'acteur', 1, '[]') r", [b])).r.lignes;
  assert.equal(l.find(x => x.nom === 'Arnie').etat, 'coma'); assert.equal(l.find(x => x.nom === 'Tom Tom').etat, null, 'Santé 0 mais PA > 0 : debout');
  // Gardes d'acteur : plus aucun refus à Santé 0.
  await db.query("UPDATE batailles SET statut = 'terminee'");
  await en(db, 'Tom Tom');
  assert.equal((await un(db, "SELECT navigation_disponibilite_interne('Tom Tom') r")).r.ok, true);
  assert.equal((await un(db, "SELECT jardins_ouvriers_acteur_interne('Tom Tom') r")).r.raison, 'pas_sur_place', 'garde Santé franchie');
  for (const appel of ["acces_forcer_passage(gen_random_uuid(), 'x')", "chantier_commande('r', 't', 'a', '{}')", "local_louer(gen_random_uuid(), 'o')",
    "poissonniere_acteur_interne('Tom Tom')", "pret_national_contracter_versionne(1, 1, 't', 'b', gen_random_uuid())", "terrain_acquisition_commande('t', 'a', '{}', gen_random_uuid())",
    "terrain_lot_loyer_fixer('t', 'l', 1)", "terrain_lots_acte('t', 'a', '[]', '{}')", "terrain_occupation_action_preparer('t', 'a')",
    "vendre_materiaux_chantier('Tom Tom', 'soviet', 'b', 'm', 1, 1)"]) assert.equal((await un(db, `SELECT ${appel} r`)).r.ok, true, appel);
  assert.equal((await un(db, "SELECT sovarka_reunion_evenement(gen_random_uuid(), 'foret_vue_3', 't', 'c') r")).r.presents, 2);
  // Combat de police : le PJ à Santé 0 n'est plus « indisponible » ; le coup passe par la robustesse.
  await db.query("UPDATE personnages_donnees SET pa = 20 WHERE name = 'Tom Tom'");
  const p = (await un(db, "SELECT police_combat_personnage_interne('rencontre-1', 'rue', NULL, NULL, 10, 'Tom Tom') r")).r;
  assert.equal(p.ok, true); assert.equal(p.jet.perte, 13, '10 bruts × 1,3 à Santé 0'); assert.equal(p.victimes[0].pa, 7);
  assert.equal((await perso(db, 'Tom Tom')).hp, 0, 'plancher 0');
  await db.query("UPDATE personnages_donnees SET hp = 100, pa = 20 WHERE name = 'Tom Tom'");
  const p2 = (await un(db, "SELECT police_combat_personnage_interne('rencontre-1', 'rue', NULL, NULL, 10, 'Tom Tom') r")).r;
  assert.equal(p2.jet.perte, 8); assert.deepEqual([(await perso(db, 'Tom Tom')).pa, (await perso(db, 'Tom Tom')).hp], [12, 92]);
});

async function combattre(db, b) {
  for (let i = 0; i < 30; i++) {
    const r = (await un(db, 'SELECT militaire_bataille_round($1) r', [b])).r;
    assert.equal(r.ok, true, JSON.stringify(r));
    if (r.terminee) return;
  }
}

test('combat complet : à Santé 100 et à Santé 10, chaque PA perdu retire un point de Santé', async () => {
  for (let essai = 0; essai < 4; essai++) {
    const db = await base({ hp: { 'Tom Tom': 100, Arnie: 10 }, vol: 20 });
    const b = await ouvrir(db, (await meute(db)).pnj);
    await combattre(db, b);
    for (const [n, hp0] of [['Tom Tom', 100], ['Arnie', 10]]) {
      const p = await perso(db, n), perdus = 30 - p.pa;
      assert.equal(p.hp, Math.max(0, hp0 - perdus), n + ' : Santé = Santé initiale − PA perdus');
    }
    const actions = (await db.query("SELECT rapport FROM batailles_rounds WHERE bataille_id = $1 AND camp = 'acteur'", [b])).rows;
    assert.ok(actions.length > 0);
  }
});

test('meute : deux loups morts, le dernier s’enfuit ; état « fuite » au dernier round ; butin des deux loups au chef', async () => {
  let fait = false;
  for (let essai = 0; essai < 25 && !fait; essai++) {
    const db = await base({ vol: 4 });
    const c0 = await meute(db);
    const b = await ouvrir(db, c0.pnj);
    // Loup 1 et Loup 2 sont tombés avant ce round ; Loup 3 a de quoi survivre à un coup ordinaire.
    await db.query("UPDATE batailles_engagements SET sorti_round = 0, etat_final = 'mort' WHERE bataille_id = $1 AND pnj_id IN ($2, $2 || ':2')", [b, c0.pnj]);
    await db.query("UPDATE pnj_membres SET statut = 'mort' WHERE id IN ($1, $1 || ':2')", [c0.pnj]);
    await db.query("UPDATE pnj_membres SET pa = 60 WHERE id = $1 || ':3'", [c0.pnj]);
    const r = (await un(db, 'SELECT militaire_bataille_round($1) r', [b])).r;
    const l3 = await un(db, 'SELECT etat_final, sorti_round FROM batailles_engagements WHERE bataille_id = $1 AND pnj_id = $2', [b, c0.pnj + ':3']);
    if (l3.etat_final === 'mort') continue;          // abattu dans le round : pas le cas étudié
    fait = true;
    assert.equal(r.terminee, true); assert.deepEqual([l3.etat_final, l3.sorti_round], ['replie', 1], 'fuite dans le même round');
    const res = (await un(db, 'SELECT contexte FROM batailles WHERE id = $1', [b])).contexte.resultat_civil;
    assert.equal(res.issue, 'tues'); assert.equal(res.abattus, 2);
    assert.equal(await qte(db, 'Tom Tom', 'textile'), 6); assert.equal(await qte(db, 'Tom Tom', 'viande'), 4);
    await en(db, 'Tom Tom');
    const e = (await un(db, 'SELECT militaire_bataille_etat($1) r', [b])).r.bataille;
    const der = e.rounds[e.rounds.length - 1];
    assert.deepEqual(der.lignes.filter(x => !x.mien).map(x => [x.nom, x.etat]), [['Loup 1', 'mort'], ['Loup 2', 'mort'], ['Loup 3', 'fuite']]);
    assert.equal(der.adversaire_estime.libelle, 'plus aucun adversaire debout');
  }
  assert.ok(fait, 'au moins un essai où Loup 3 survit au round');
});

test('meute : un seul loup mort, les autres gardent leur fuite individuelle (pas de fuite forcée)', async () => {
  const db = await base();
  const c0 = await meute(db);
  const b = await ouvrir(db, c0.pnj);
  await db.query("UPDATE batailles_engagements SET sorti_round = 0, etat_final = 'mort' WHERE bataille_id = $1 AND pnj_id = $2", [b, c0.pnj]);
  assert.equal((await un(db, 'SELECT sovarka_foret_meute_derniere_fuite_interne($1, 1) n', [b])).n, 0);
  assert.equal(Number((await un(db, 'SELECT count(*) n FROM batailles_engagements WHERE bataille_id = $1 AND pnj_id IS NOT NULL AND sorti_round IS NULL', [b])).n), 2);
  // Le seuil est un paramètre MJ.
  await db.query("UPDATE aliments_parametres SET valeur = 1 WHERE cle = 'foret_meute_fuite_apres_morts'");
  assert.equal((await un(db, 'SELECT sovarka_foret_meute_derniere_fuite_interne($1, 1) n', [b])).n, 2);
});

test('fuite au 5e round (arbitrage après le rapport) : la dernière ligne dit « fuite » pour le loup enfui', async () => {
  let fait = false;
  for (let essai = 0; essai < 25 && !fait; essai++) {
    const db = await base({ vol: 2, pa: 100 });
    const c0 = await meute(db);
    await db.query("UPDATE pnj_membres SET pa = 1000 WHERE id LIKE $1 || '%'", [c0.pnj]);
    const b = await ouvrir(db, c0.pnj);
    await combattre(db, b);
    const fuyards = (await db.query("SELECT e.id, m.nom, e.sorti_round FROM batailles_engagements e JOIN pnj_membres m ON m.id = e.pnj_id WHERE e.bataille_id = $1 AND e.etat_final = 'replie'", [b])).rows;
    if (!fuyards.length) continue;
    fait = true;
    await en(db, 'Tom Tom');
    const e = (await un(db, 'SELECT militaire_bataille_etat($1) r', [b])).r.bataille;
    const der = e.rounds[e.rounds.length - 1];
    for (const f of fuyards) {
      assert.equal(der.round, f.sorti_round);
      assert.equal(der.lignes.find(x => x.nom === f.nom).etat, 'fuite', f.nom + ' affiché en fuite au dernier round');
    }
  }
  assert.ok(fait, 'au moins un combat où un loup s’enfuit');
});

test('butin par loup tué même si le groupe tombe ; reste d’une pile non rangée envoyé au sas', async () => {
  const db = await base();
  const c0 = await meute(db);
  const b = await ouvrir(db, c0.pnj);
  await db.query("UPDATE batailles_engagements SET sorti_round = 2, etat_final = 'mort' WHERE bataille_id = $1 AND pnj_id = $2", [b, c0.pnj]);
  const v = (await un(db, "SELECT sovarka_foret_issue_combat_interne($1, 'Tom Tom', 'defaite') r", [c0.pnj])).r;
  assert.equal(v.abattus, 1);
  assert.equal(await qte(db, 'Tom Tom', 'textile'), 3); assert.equal(await qte(db, 'Tom Tom', 'viande'), 2);
  assert.equal(await qte(db, 'Tom Tom', 'bois'), 0, 'pas de seconde coupe dans une défaite');
  // Ours abattu, chef presque plein (3 places) : 3 peaux rangées, le reste de chaque pile part au sas, rien ne se perd.
  const o = await base();
  await o.query("UPDATE personnages_donnees SET capacite = jsonb_array_length(inventory) + 3 WHERE name = 'Tom Tom'");
  const ours = (await un(o, "SELECT sovarka_foret_faune_creer_interne('Tom Tom', 3, 'ours') r")).r;
  const res = (await un(o, "SELECT sovarka_foret_issue_combat_interne($1, 'Tom Tom', 'tues') r", [ours.pnj])).r;
  assert.equal(res.ok, true);
  assert.equal(await qte(o, 'Tom Tom', 'textile'), 3);
  assert.equal(await sas(o, 'Tom Tom', 'textile'), 7, '7 peaux au sas');
  assert.equal(await sas(o, 'Tom Tom', 'graisse_ours'), 10, '10 pots de graisse au sas');
  assert.equal(await qte(o, 'Tom Tom', 'viande') + await sas(o, 'Tom Tom', 'viande'), 9);
});

test('regen_jour et stats_affaiblies sans effet (point 15)', async () => {
  const db = await base({ hp: { 'Tom Tom': 50, Arnie: 50 } });
  await db.query("UPDATE personnages_donnees SET stats_affaiblies = '{\"INT\":true,\"CHA\":true,\"DUP\":true}' WHERE name = 'Tom Tom'");
  await en(db, 'Tom Tom');
  assert.equal((await un(db, "SELECT jauges_ordre_executer('o', gen_random_uuid(), '{}') r")).r.int, 8);
  assert.equal((await un(db, "SELECT militaire_subtiliser_tenter('soviet') r")).r.dup, 10);
  assert.equal(Number((await un(db, "SELECT terrain_negociation_preparer('t') r")).r.cha), 8);
  assert.equal(Number((await un(db, "SELECT terrain_squatteurs_don('t', 1, 'o', gen_random_uuid()) r")).r.cha), 8);
  const occ = (await un(db, "SELECT terrain_occupation_action_preparer('t', 'a') r")).r;
  assert.deepEqual([Number(occ.cha), Number(occ.dup)], [8, 10]);
  // Agression (hp_set) : Santé posée et PA à 0, mais ni régénération ni caractéristiques affaiblies.
  await db.query("UPDATE personnages_donnees SET stats_affaiblies = '{}' WHERE name = 'Tom Tom'");
  await db.query("INSERT INTO impacts_indices_attente (id, victime, indice, delta) VALUES ('i1', 'Tom Tom', 'hp_set', 20), ('i2', 'Tom Tom', 'poison_start', 0)");
  await db.query("UPDATE impacts_indices_attente SET details = '{\"statsTouchees\":[\"VOL\"],\"poisonType\":\"x\"}' WHERE id = 'i2'");
  assert.equal((await un(db, "SELECT impact_marquer_traite('i1', 1) r")).r.ok, true);
  assert.equal((await un(db, "SELECT impact_marquer_traite('i2', 1) r")).r.ok, true);
  const p = await perso(db, 'Tom Tom');
  assert.deepEqual([p.hp, p.pa, p.regen_jour, p.stats_affaiblies], [20, 0, null, {}]);
});
