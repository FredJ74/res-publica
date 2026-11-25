'use strict';
// Mission du soir du 25/11/2026, bloc 4.5 : remise à zéro du 19/12 (préparée, jamais exécutée). Banc du script généré.
// Garde-fous (phrase, date, tables à vérifier, tables inconnues non vides, réinitialisations déclarées), relevé des comptes de
// la bêta (comptes de test exclus), effacement de l'état vivant seulement, offre des testeurs, achats premium gardés.
// Usage : PGLITE_DIR=<…/node_modules/@electric-sql/pglite> node --test outils/bancs/banc-remise-a-zero-pglite-20261125.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const { execFileSync } = require('node:child_process');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const SCRIPT = 'outils/lancement/remise-a-zero-20261219.sql';

test('script généré à jour, transaction unique, jamais de CASCADE, aucune table premium payée effacée', () => {
  execFileSync('python3', [path.join(root, 'outils/lancement/generer-remise-a-zero.py'), '--verifier'], { encoding: 'utf8' });
  const s = lire(SCRIPT);
  assert.match(s, /^BEGIN;$/m); assert.match(s, /^COMMIT;$/m);
  assert.doesNotMatch(s.replace(/^--.*$/gm, ''), /CASCADE/i);
  const vider = /\) AS garder, (ARRAY\[[^\]]*\])::text\[\] AS vider/.exec(s) || /(ARRAY\[[^\]]*\])::text\[\] AS vider/.exec(s);
  for (const t of ['premium_achats', 'premium_abonnements', 'premium_droits', 'administrateurs', 'comptes_test', 'ordres_couts'])
    assert.doesNotMatch(vider[1], new RegExp("'" + t + "'"), t + ' ne doit jamais être vidée');
  for (const t of ['personnages', 'personnages_donnees', 'crim_affaires', 'publicites_joueurs']) assert.match(vider[1], new RegExp("'" + t + "'"));
  assert.ok(fs.existsSync(path.join(root, 'docs/premium/REMISE-A-ZERO-20261219.md')), 'procédure documentée');
});

const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : partie SQL exécutée avec PGLITE_DIR', { skip: true }, () => {}); return; }

const SOCLE = `
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN CREATE ROLE anon; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN CREATE ROLE authenticated; END IF; END $$;
CREATE TABLE personnages (name text PRIMARY KEY, user_id uuid);
CREATE TABLE personnages_donnees (name text PRIMARY KEY);
CREATE TABLE crim_affaires (id bigserial PRIMARY KEY, auteur text);
CREATE TABLE comptes_test (personnage text PRIMARY KEY);
CREATE TABLE administrateurs (user_id uuid PRIMARY KEY);
CREATE TABLE ordres_couts (fn text PRIMARY KEY);
CREATE TABLE premium_produits (produit text PRIMARY KEY);
CREATE TABLE premium_achats (id uuid PRIMARY KEY);
CREATE TABLE premium_droits (id bigserial PRIMARY KEY, user_id uuid, produit text REFERENCES premium_produits, cible text, source text, note text);
INSERT INTO premium_produits VALUES ('personnalisation_local'), ('credit_publicite_presse'), ('credit_publicite_rue');
INSERT INTO personnages VALUES ('Olga', '00000000-0000-0000-0000-000000000001'), ('Olga2', '00000000-0000-0000-0000-000000000001'),
  ('Ivan', '00000000-0000-0000-0000-000000000002'), ('Arnie', '00000000-0000-0000-0000-000000000003'), ('PNJ', NULL);
INSERT INTO personnages_donnees VALUES ('Olga'), ('Ivan');
INSERT INTO crim_affaires (auteur) VALUES ('Olga');
INSERT INTO comptes_test VALUES ('Arnie');
INSERT INTO administrateurs VALUES ('00000000-0000-0000-0000-0000000000aa');
INSERT INTO ordres_couts VALUES ('voler');
INSERT INTO premium_achats VALUES ('00000000-0000-0000-0000-00000000beef');
`;
// Le corps sans le bloc de date (banc joué avant le 19/12), listes « à vérifier » et « réinitialiser » vidées pour l'essai.
function corpsEssai(s, { garderDate = false } = {}) {
  let c = s;
  if (!garderDate) c = c.replace(/DO \$garde\$[\s\S]*?END \$garde\$;/, '');
  return c.replace(/ARRAY\[[^\]]*\]::text\[\] AS a_verifier/, "'{}'::text[] AS a_verifier")
          .replace(/ARRAY\[[^\]]*\]::text\[\] AS reinitialiser/, "'{}'::text[] AS reinitialiser");
}

test('garde-fous : sans la phrase, refus ; avec la phrase, refus avant le 19/12 ; rien n’est effacé', async () => {
  const db = new PGlite(); await db.exec(SOCLE);
  await assert.rejects(db.exec(lire(SCRIPT)), /phrase de confirmation absente/);
  await db.exec('ROLLBACK').catch(() => {});
  if (new Date() < new Date('2026-12-18T23:00:00Z')) {
    await db.exec(`SET human_gambit.remise_a_zero = 'JE-CONFIRME-LA-REMISE-A-ZERO-DU-19-12-2026'`);
    await assert.rejects(db.exec(lire(SCRIPT)), /pas avant le 19\/12\/2026/);
    await db.exec('ROLLBACK').catch(() => {});
  }
  assert.equal((await db.query('SELECT count(*)::int n FROM personnages')).rows[0].n, 5);
});

test('garde-fous : tables « à vérifier » restantes, réinitialisations non déclarées, table inconnue non vide', async () => {
  const s = lire(SCRIPT);
  const db = new PGlite(); await db.exec(SOCLE);
  await assert.rejects(db.exec(s.replace(/DO \$garde\$[\s\S]*?END \$garde\$;/, '')), /à vérifier/);
  await db.exec('ROLLBACK').catch(() => {});
  await assert.rejects(db.exec(s.replace(/DO \$garde\$[\s\S]*?END \$garde\$;/, '').replace(/ARRAY\[[^\]]*\]::text\[\] AS a_verifier/, "'{}'::text[] AS a_verifier")),
    /non déclarées traitées/);
  await db.exec('ROLLBACK').catch(() => {});
  await db.exec(`CREATE TABLE table_surprise (x int); INSERT INTO table_surprise VALUES (1);`);
  await assert.rejects(db.exec(corpsEssai(s)), /non classées et non vides : table_surprise/);
  await db.exec('ROLLBACK').catch(() => {});
  assert.equal((await db.query('SELECT count(*)::int n FROM crim_affaires')).rows[0].n, 1, 'tout ou rien');
});

test('exécution : état vivant effacé, référentiels, MJ et achats gardés ; offre aux comptes de la bêta, pas aux comptes de test', async () => {
  const db = new PGlite(); await db.exec(SOCLE);
  await db.exec(corpsEssai(lire(SCRIPT)));
  const n = async t => (await db.query(`SELECT count(*)::int n FROM ${t}`)).rows[0].n;
  assert.equal(await n('personnages'), 0); assert.equal(await n('personnages_donnees'), 0); assert.equal(await n('crim_affaires'), 0);
  assert.equal(await n('administrateurs'), 1); assert.equal(await n('ordres_couts'), 1); assert.equal(await n('premium_achats'), 1);
  assert.equal(await n('comptes_test'), 1);
  const b = (await db.query('SELECT user_id::text u, personnages FROM lancement_comptes_beta ORDER BY 1')).rows;
  assert.deepEqual(b.map(x => x.u), ['00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002']);
  assert.deepEqual(b[0].personnages, ['Olga', 'Olga2']);
  const o = (await db.query(`SELECT user_id::text u, produit, source FROM premium_droits ORDER BY 1, 2`)).rows;
  assert.equal(o.length, 6);
  assert.ok(o.every(x => x.source === 'offre_lancement'));
  assert.deepEqual(o.filter(x => x.u.endsWith('1')).map(x => x.produit), ['credit_publicite_presse', 'credit_publicite_rue', 'personnalisation_local']);
  // Rejouée par erreur : aucune seconde offre.
  await db.exec(`INSERT INTO personnages VALUES ('Nouveau', '00000000-0000-0000-0000-000000000009')`);
  await db.exec(corpsEssai(lire(SCRIPT)));
  assert.equal((await db.query(`SELECT count(*)::int n FROM premium_droits WHERE user_id = '00000000-0000-0000-0000-000000000001'`)).rows[0].n, 3);
});
