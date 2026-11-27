'use strict';
// Mission du 27/11/2026 (après-midi), étape 3 : « Stage à la caserne » porté par le serveur (stage_caserne_effectuer,
// migration 20261127160000) — 3 PA, +5 VOL, une fois par jour, trois jours d'affilée puis 7 jours de repos. L'écran
// n'ajoute plus rien lui-même. Partie SQL dans PGlite (PGLITE_DIR).
// Usage : PGLITE_DIR=<dossier où @electric-sql/pglite est installé> node --test outils/bancs/banc-stage-caserne-serveur-20261127.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const MIG = 'migrations/20261127160000_stage_caserne_serveur.sql';

test('écran : le stage appelle le serveur et n’ajoute aucune VOL ni série lui-même', () => {
  const src = lire('plateau-organisations-quetes.js');
  const i = src.indexOf('async function doStageCaserne');
  const corps = src.slice(i, src.indexOf('\n}\n', i));
  assert.match(corps, /sbRpcVerdict\('stage_caserne_effectuer'/);
  assert.doesNotMatch(corps, /\+ 5|deduireCoutOrdre|stageCaserne|sauvegarderPersonnage/);
  assert.match(corps, /state\.char\.stats\.VOL = v\.vol/);
  const ordre = lire('data.js').match(/\{fn:'stage_caserne'[^\n]*/)[0];
  assert.match(ordre, /pa:3, cost:0/);
});

const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : partie SQL exécutée avec PGLITE_DIR', { skip: true }, () => {}); return; }

const SOCLE = `
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN CREATE ROLE authenticated; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN CREATE ROLE anon; END IF; END $$;
CREATE TABLE personnages_donnees (name text PRIMARY KEY, day integer, current_building text, current_room text, stats jsonb, pa integer);
INSERT INTO personnages_donnees VALUES ('Ivan', 10, 'caserne-militaire', 'corps_garde', '{"VOL": 6, "INT": 9}', 20),
  ('Olga', 10, 'mairie', 'accueil', '{"VOL": 6}', 20);
CREATE FUNCTION mon_personnage() RETURNS text LANGUAGE sql STABLE AS $f$ SELECT nullif(current_setting('rp.moi', true), '') $f$;
CREATE FUNCTION payer_ordre(a text, fn text, pa integer, cost integer) RETURNS jsonb LANGUAGE plpgsql AS $f$
DECLARE reste integer;
BEGIN
  IF fn <> 'stage_caserne' OR pa <> 3 OR cost <> 0 THEN RAISE EXCEPTION 'tarif inattendu %', fn; END IF;
  UPDATE personnages_donnees SET pa = personnages_donnees.pa - 3 WHERE name = a AND personnages_donnees.pa >= 3 RETURNING personnages_donnees.pa INTO reste;
  IF reste IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants'); END IF;
  RETURN jsonb_build_object('ok', true, 'pa', reste);
END $f$;`;

async function stage(db, moi, jour) {
  if (jour) await db.query('UPDATE personnages_donnees SET day = $1 WHERE name = $2', [jour, moi]);
  await db.query("SELECT set_config('rp.moi', $1, false)", [moi]);
  return (await db.query('SELECT public.stage_caserne_effectuer() AS r')).rows[0].r;
}
const fiche = async (db, n) => (await db.query('SELECT stats, pa FROM personnages_donnees WHERE name = $1', [n])).rows[0];

test('serveur : +5 VOL et 3 PA, une fois par jour, trois jours puis 7 jours de repos ; série relancée après un jour manqué', async () => {
  const db = new PGlite(); await db.exec(SOCLE); await db.exec(lire(MIG));
  assert.equal((await stage(db, 'Olga')).raison, 'pas_sur_place');
  let r = await stage(db, 'Ivan');
  assert.deepEqual([r.ok, r.vol, r.serie, r.repos_jusqua, r.paie.pa], [true, 11, 1, null, 17]);
  assert.deepEqual(await fiche(db, 'Ivan'), { stats: { VOL: 11, INT: 9 }, pa: 17 });
  assert.equal((await stage(db, 'Ivan')).raison, 'deja_fait_aujourdhui');
  assert.equal((await fiche(db, 'Ivan')).pa, 17, 'refus sans prélèvement');
  // Un jour manqué : nouvelle série, sans repos.
  r = await stage(db, 'Ivan', 12); assert.deepEqual([r.serie, r.repos_jusqua], [1, null]);
  r = await stage(db, 'Ivan', 13); assert.equal(r.serie, 2);
  r = await stage(db, 'Ivan', 14); assert.deepEqual([r.serie, r.repos_jusqua, r.vol], [3, 21, 26]);
  r = await stage(db, 'Ivan', 20); assert.deepEqual([r.ok, r.raison, r.repos_jusqua], [false, 'repos_obligatoire', 21]);
  r = await stage(db, 'Ivan', 21); assert.deepEqual([r.ok, r.serie], [true, 1]);
  await db.exec("UPDATE personnages_donnees SET pa = 2 WHERE name = 'Ivan'");
  r = await stage(db, 'Ivan', 22); assert.equal(r.raison, 'pa_insuffisants');
  assert.equal((await fiche(db, 'Ivan')).stats.VOL, 31, 'aucune VOL sans paiement');
  await db.exec(lire(MIG));
});
