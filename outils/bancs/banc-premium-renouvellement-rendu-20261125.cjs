'use strict';
// Mission de fin de soirée du 25/11/2026, point 1.3 (décision de Fred) : un renouvellement d'image décompté avant la
// génération est RENDU si la génération échoue. Migration 20261125800000 dans PGlite, et ateliers de décoration (statique).
// Usage : PGLITE_DIR=<…/node_modules/@electric-sql/pglite> node --test outils/bancs/banc-premium-renouvellement-rendu-20261125.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const MIG = 'migrations/20261125800000_premium_renouvellement_rendu.sql';
const ATELIERS = { commerce: 'supabase/edge-functions/commerce-decoration/index.ts', logement: 'supabase/edge-functions/logement-decoration/index.ts' };

test('migration : en-tête NON APPLIQUÉE, contrôles en lecture, réservée au serveur', () => {
  const m = lire(MIG);
  assert.match(m.split('\n')[0], /NON APPLIQUÉE/);
  assert.match(m, /Contrôles en lecture après application/);
  assert.match(m, /REVOKE ALL ON FUNCTION public\.premium_renouvellement_rendre_service\(uuid, text, text\) FROM PUBLIC, anon, authenticated;/);
  assert.match(m, /est_appel_serveur\(\)/);
});

for (const [type, f] of Object.entries(ATELIERS)) {
  test(`atelier ${type} : après le décompte, chaque échec rend le renouvellement`, () => {
    const s = lire(f);
    const i = s.lastIndexOf('decompte=');
    assert.ok(i > 0, 'décompte noté');
    assert.match(s, new RegExp(`premium_renouvellement_rendre_service",\\{p_user:user\\.id,p_type:"${type}"`));
    const apres = s.slice(i);
    assert.doesNotMatch(apres, /return reply\(\{error:/, 'aucun retour d\'erreur qui oublie de rendre');
    assert.match(apres, /fetch\("https:\/\/api\.openai\.com[^\n]*\.catch\(\(\)=>null\);\n if\(!response\)return await echec/, 'panne réseau du générateur');
    for (const motif of ['OpenAI: ', 'Aucune image recue', 'Format WebP invalide', 'Sauvegarde image impossible', 'Enregistrement impossible'])
      assert.match(apres, new RegExp('return await echec\\(\\{error:"' + motif.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')), motif);
    assert.match(s, /return reply\(\{ok:true,path/, 'réussite : rien n\'est rendu');
  });
}

const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : partie SQL exécutée avec PGLITE_DIR', { skip: true }, () => {}); return; }

const U = '00000000-0000-0000-0000-000000000001';
const SOCLE = `
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN CREATE ROLE anon; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN CREATE ROLE authenticated; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN CREATE ROLE service_role; END IF;
END $$;
CREATE OR REPLACE FUNCTION est_appel_serveur() RETURNS boolean LANGUAGE sql STABLE AS $f$ SELECT current_setting('test.service', true) = '1' $f$;
CREATE TABLE premium_renouvellements (id bigserial PRIMARY KEY, user_id uuid NOT NULL, semaine text NOT NULL, type_visuel text NOT NULL,
  objet text, source text NOT NULL, cree_le timestamptz NOT NULL DEFAULT now());
CREATE TABLE premium_droits (id bigserial PRIMARY KEY, user_id uuid NOT NULL, produit text NOT NULL, cible text, source text NOT NULL,
  accorde_le timestamptz NOT NULL DEFAULT now(), consomme_le timestamptz, revoque_le timestamptz);
`;
async function base() {
  const db = new PGlite(); await db.exec(SOCLE); await db.exec(lire(MIG)); await db.exec(`SET test.service = '1'`); return db;
}
const rendre = async (db, type, objet) => (await db.query(`SELECT premium_renouvellement_rendre_service('${U}', '${type}', '${objet}') r`)).rows[0].r;
const n = async (db, sql) => (await db.query(sql)).rows[0].n;

test('abonné : le renouvellement inclus de la semaine redevient libre ; rendu une seule fois', async () => {
  const db = await base();
  await db.exec(`INSERT INTO premium_renouvellements (user_id, semaine, type_visuel, objet, source) VALUES ('${U}', '2026-S48', 'commerce', 'fonds-1', 'abonnement')`);
  const r = await rendre(db, 'commerce', 'fonds-1');
  assert.deepEqual([r.ok, r.rendu, r.source], [true, true, 'abonnement']);
  assert.equal(await n(db, 'SELECT count(*)::int n FROM premium_renouvellements'), 0);
  const r2 = await rendre(db, 'commerce', 'fonds-1');
  assert.deepEqual([r2.ok, r2.rendu, r2.raison], [true, false, 'rien_a_rendre'], 'idempotent');
});

test('unité achetée : elle redevient utilisable ; un autre visuel n\'est pas touché', async () => {
  const db = await base();
  await db.exec(`INSERT INTO premium_droits (user_id, produit, cible, source, consomme_le) VALUES
    ('${U}', 'renouvellement_image', 'logement:republic|capitale|immeuble|salon', 'achat', now()),
    ('${U}', 'renouvellement_image', 'commerce:fonds-9', 'achat', now() - interval '1 hour');
    INSERT INTO premium_renouvellements (user_id, semaine, type_visuel, objet, source) VALUES
    ('${U}', '2026-S48', 'logement', 'republic|capitale|immeuble|salon', 'unite')`);
  const r = await rendre(db, 'logement', 'republic|capitale|immeuble|salon');
  assert.deepEqual([r.rendu, r.source], [true, 'unite']);
  const d = (await db.query(`SELECT cible, consomme_le FROM premium_droits ORDER BY id`)).rows;
  assert.deepEqual([d[0].cible, d[0].consomme_le], [null, null], 'unité rendue, réattachable au prochain usage');
  assert.equal(d[1].cible, 'commerce:fonds-9'); assert.ok(d[1].consomme_le, 'unité d\'un autre visuel toujours consommée');
});

test('bêta : la trace est retirée ; un décompte de plus de 15 minutes n\'est pas rendu ; réservé au serveur', async () => {
  const db = await base();
  await db.exec(`INSERT INTO premium_renouvellements (user_id, semaine, type_visuel, objet, source, cree_le) VALUES
    ('${U}', '2026-S48', 'commerce', 'fonds-2', 'beta', now()), ('${U}', '2026-S48', 'commerce', 'fonds-3', 'abonnement', now() - interval '1 hour')`);
  assert.equal((await rendre(db, 'commerce', 'fonds-2')).rendu, true);
  assert.equal((await rendre(db, 'commerce', 'fonds-3')).rendu, false, 'trop ancien : une génération réussie ne se rend pas après coup');
  await db.exec(`SET test.service = '0'`);
  assert.equal((await rendre(db, 'commerce', 'fonds-3')).raison, 'reserve_serveur');
  assert.equal(await n(db, 'SELECT count(*)::int n FROM premium_renouvellements'), 1);
});
