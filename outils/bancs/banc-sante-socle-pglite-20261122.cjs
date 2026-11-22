'use strict';
// Santé — socle commun (Fred, 22/11/2026, après-midi, GAME-DESIGN-SANTE-20261122.md, points 1, 11, 16), migration
// 20261122230000, dans un vrai PostgreSQL local (PGlite).
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : banc exécuté par son workflow dédié (PGLITE_DIR)', { skip: true }, () => {}); return; }

const MIGRATION = 'migrations/20261122230000_sante_socle.sql';
const U = { tom: '00000000-0000-0000-0000-000000000001', mj: '00000000-0000-0000-0000-0000000000aa' };
async function base() {
  const db = new PGlite();
  await db.exec(lire('outils/bancs/fixtures/inventaire-direct-pglite-socle.sql.txt'));
  await db.exec('ALTER TABLE personnages_donnees ADD COLUMN IF NOT EXISTS hp integer, ADD COLUMN IF NOT EXISTS moral integer');
  await db.query('INSERT INTO personnages VALUES ($1,$2)', ['Tom Tom', U.tom]);
  await db.query('INSERT INTO administrateurs VALUES ($1, true)', [U.mj]);
  await db.query("INSERT INTO personnages_donnees (name, user_id, hp, moral) VALUES ('Tom Tom', $1, 40, 50)", [U.tom]);
  await db.exec(lire(MIGRATION));
  return db;
}
const un = async (db, sql, p) => (await db.query(sql, p)).rows[0].r;
const en = (db, uid) => db.query("SELECT set_config('test.uid', $1, false)", [uid || '']);

test('la migration ne touche aucune Santé et se rejoue', async () => {
  const db = await base();
  assert.equal(await un(db, "SELECT hp r FROM personnages_donnees WHERE name='Tom Tom'"), 40);
  await db.exec(lire(MIGRATION));
  assert.equal(await un(db, "SELECT hp r FROM personnages_donnees WHERE name='Tom Tom'"), 40);
  assert.ok(Number(await un(db, 'SELECT count(*) r FROM sante_parametres')) >= 40);
});

test('robustesse : 1,3 à 0, 1,0 à 50, 0,8 à 100, linéaire ; au moins 1 PA', async () => {
  const db = await base();
  const f = async h => Number(await un(db, 'SELECT sante_facteur_robustesse($1) r', [h]));
  assert.equal(await f(0), 1.3); assert.equal(await f(50), 1); assert.equal(await f(100), 0.8);
  assert.ok(Math.abs(await f(25) - 1.15) < 1e-9); assert.ok(Math.abs(await f(75) - 0.9) < 1e-9);
  const p = async (h, x) => Number(await un(db, 'SELECT sante_perte_combat_interne($1,$2) r', [h, x]));
  assert.equal(await p(0, 10), 13); assert.equal(await p(100, 10), 8); assert.equal(await p(100, 1), 1, 'un coup qui touche retire au moins 1 PA');
  assert.equal(await p(100, 0), 0, 'un coup manqué ne retire rien');
});

test('Moral : gains ×1,5 / ×1 / ×0,5 arrondis ; pertes jamais modulées ; bornes 0 et 100', async () => {
  const db = await base();
  const gagner = async (moral, hp, g) => {
    await db.query("UPDATE personnages_donnees SET moral=$1, hp=$2 WHERE name='Tom Tom'", [moral, hp]);
    return un(db, "SELECT sante_gagner_interne('Tom Tom', $1, 'test') r", [g]);
  };
  assert.equal((await gagner(80, 40, 5)).apres, 48, '5 × 1,5 = 7,5 → 8');
  assert.equal((await gagner(74, 40, 5)).apres, 45);
  assert.equal((await gagner(24, 40, 5)).apres, 43, '5 × 0,5 = 2,5 → 3');
  assert.equal((await gagner(80, 40, -6)).apres, 34, 'perte non modulée');
  assert.equal((await gagner(80, 98, 5)).apres, 100);
  assert.equal((await gagner(20, 3, -10)).apres, 0);
  await db.query("UPDATE personnages_donnees SET hp=50 WHERE name='Tom Tom'");
  assert.equal((await un(db, "SELECT sante_perdre_interne('Tom Tom', 4, 'test') r")).apres, 46);
});

test('journal d’événements : écrit par le serveur, lu une fois par son destinataire', async () => {
  const db = await base();
  await db.query("SELECT personnage_evenement_ajouter_interne('Tom Tom', 'sante', 'Bonjour', '{}')");
  await en(db, U.tom);
  const r = await un(db, 'SELECT personnage_evenements_lire() r');
  assert.equal(r.evenements.length, 1); assert.equal(r.evenements[0].texte, 'Bonjour');
  assert.equal((await un(db, 'SELECT personnage_evenements_lire() r')).evenements.length, 0);
  assert.deepEqual(await un(db, "SELECT sante_reveil_interne('Tom Tom') r"), []);
});

test('MJ : lecture et réglage journalisé ; refus hors MJ', async () => {
  const db = await base();
  await en(db, U.tom);
  await assert.rejects(db.query("SELECT admin_sante_parametre_fixer('sommeil_chambre', 6)"));
  await en(db, U.mj);
  const r = await un(db, "SELECT admin_sante_parametre_fixer('sommeil_chambre', 6) r");
  assert.equal(r.ok, true); assert.equal(Number(r.avant), 5);
  assert.equal((await un(db, "SELECT admin_sante_parametre_fixer('inconnu', 1) r")).raison, 'parametre_inconnu');
  assert.ok((await un(db, 'SELECT admin_sante_parametres_lire() r')).parametres.some(p => p.cle === 'sommeil_chambre' && Number(p.valeur) === 6));
  assert.equal(Number(await un(db, "SELECT count(*) r FROM admin_journal WHERE action='sante_parametre_fixer'")), 1);
});
