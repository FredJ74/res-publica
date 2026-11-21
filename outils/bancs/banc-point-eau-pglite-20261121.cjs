'use strict';
// Eau de la place de l'Ours — « Puiser de l'eau » (migration 20261121170000), éprouvée dans un vrai PostgreSQL local (PGlite).
// PGlite : PGLITE_DIR=<dossier contenant node_modules/@electric-sql/pglite> (le workflow dédié l'installe).
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : banc exécuté par son workflow dédié (PGLITE_DIR)', { skip: true }, () => {}); return; }

const MIGRATION = 'migrations/20261121170000_point_eau_puiser_mairie_krasnov.sql';
const TOM = '00000000-0000-0000-0000-000000000001';
async function base() {
  const db = new PGlite();
  await db.exec(lire('outils/bancs/fixtures/point-eau-pglite-socle.sql.txt'));
  await db.exec(lire(MIGRATION));
  return db;
}
const un = async (db, sql, p) => (await db.query(sql, p)).rows[0];
async function comme(db, uid, sql, p) { await db.exec(`SELECT set_config('test.uid', '${uid}', false)`); return (await db.query(sql, p)).rows[0]; }
let n = 0; const req = () => '00000000-0000-4000-8000-' + String(++n).padStart(12, '0');

test('puiser : 1 PA quelle que soit la quantité, bouteilles dans l\'inventaire, compteur de tranche', async () => {
  const db = await base();
  const e = (await comme(db, TOM, 'SELECT public.point_eau_etat() r')).r;
  assert.equal(e.ok, true); assert.equal(e.restant, 10); assert.equal(e.place, 100);
  assert.equal(e.point.image, 'images/Sovarka/Krasnov/Krasnov_place_ours_fontaine.webp');
  assert.ok([0, 6, 12, 18].includes(e.heure_fin));
  const r = (await comme(db, TOM, 'SELECT public.point_eau_puiser($1, 7) r', [req()])).r;
  assert.equal(r.ok, true); assert.equal(r.quantite, 7); assert.equal(r.restant, 3);
  assert.equal((await un(db, "SELECT pa FROM personnages_donnees WHERE name='Tom'")).pa, 9);
  // Demande de 5 : plafonnée au reste (3), 1 PA.
  const r2 = (await comme(db, TOM, 'SELECT public.point_eau_puiser($1, 5) r', [req()])).r;
  assert.equal(r2.quantite, 3); assert.equal(r2.restant, 0);
  assert.equal((await un(db, "SELECT pa FROM personnages_donnees WHERE name='Tom'")).pa, 8);
  // Plafond atteint : refus, aucun PA.
  const r3 = (await comme(db, TOM, 'SELECT public.point_eau_puiser($1, 1) r', [req()])).r;
  assert.equal(r3.ok, false); assert.equal(r3.raison, 'plafond_atteint');
  assert.equal((await un(db, "SELECT pa FROM personnages_donnees WHERE name='Tom'")).pa, 8);
  const q = await un(db, "SELECT sum((e->>'qty')::int) q FROM personnages_donnees, jsonb_array_elements(inventory) e WHERE name='Tom'");
  assert.equal(Number(q.q), 10);
});

test('inventaire : plafonné à la place libre ; plein = refus sans PA ; rejeu idempotent', async () => {
  const db = await base();
  await db.exec(`UPDATE personnages_donnees SET inventory = '[{"name":"Bois","qty":96}]' WHERE name = 'Tom'`);
  const id = req();
  const r = (await comme(db, TOM, 'SELECT public.point_eau_puiser($1, 10) r', [id])).r;
  assert.equal(r.quantite, 4);
  const rejeu = (await comme(db, TOM, 'SELECT public.point_eau_puiser($1, 10) r', [id])).r;
  assert.equal(rejeu.rejeu, true);
  assert.equal((await un(db, "SELECT pa FROM personnages_donnees WHERE name='Tom'")).pa, 9);
  const plein = (await comme(db, TOM, 'SELECT public.point_eau_puiser($1, 1) r', [req()])).r;
  assert.equal(plein.raison, 'inventaire_plein');
  assert.equal((await un(db, "SELECT pa FROM personnages_donnees WHERE name='Tom'")).pa, 9);
});

test('ailleurs qu\'à la fontaine, sans PA, ancien bouton : refus expliqués', async () => {
  const db = await base();
  const loin = (await comme(db, '00000000-0000-0000-0000-000000000002', 'SELECT public.point_eau_puiser($1, 1) r', [req()])).r;
  assert.equal(loin.raison, 'pas_de_point_eau');
  await db.exec("UPDATE personnages_donnees SET pa = 0 WHERE name = 'Tom'");
  const sansPa = (await comme(db, TOM, 'SELECT public.point_eau_puiser($1, 1) r', [req()])).r;
  assert.equal(sansPa.ok, false); assert.equal(sansPa.raison, 'pa_insuffisants');
  assert.equal((await un(db, "SELECT count(*)::int c FROM climat_points_eau_puisages")).c, 0);
  assert.equal((await comme(db, TOM, 'SELECT public.point_eau_remplir($1) r', [req()])).r.raison, 'remplace_par_puiser');
});

test('consigne de canicule, mairie de Krasnov à une seule sortie, hôtel de Novomirsk intact, rejouable', async () => {
  const db = await base();
  const c = (await un(db, "SELECT public.climat_consigne_interne('canicule','soviet','ville_b') c")).c;
  assert.match(c, /puiser coûte 1 PA, jusqu'à 10 bouteilles toutes les 6 heures/);
  const s = (await un(db, "SELECT string_agg(noeud, ',' ORDER BY noeud) s FROM rue_sorties_batiments WHERE building='mairie'")).s;
  assert.equal(s, 'krasnov-rue-mairie-place');
  assert.equal((await un(db, "SELECT count(*)::int c FROM rue_sorties_batiments WHERE building='hotel-republica'")).c, 2);
  await db.exec(lire(MIGRATION));
  assert.match((await un(db, "SELECT public.climat_consigne_interne('canicule','soviet','ville_b') c")).c, /puiser coûte 1 PA/);
});
