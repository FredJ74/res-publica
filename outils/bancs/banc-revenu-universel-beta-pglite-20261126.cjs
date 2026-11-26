'use strict';
// Décision de Fred du 26/11/2026 (21 h 29) : pendant la bêta, le revenu universel est rendu à tous les testeurs ; la limite
// des 10 premiers jours ne s'applique qu'à partir du lancement (clé « limite_a_partir », 20261219).
// Usage : PGLITE_DIR=<dossier où @electric-sql/pglite est installé> node --test outils/bancs/banc-revenu-universel-beta-pglite-20261126.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const MIG = 'migrations/20261126100000_revenu_universel.sql', BETA = 'migrations/20261126500000_revenu_universel_beta.sql';
const PROD = 'outils/bancs/fixtures/salaire-civil-percevoir-prod-20261126.sql.txt';

test('fichier : en-tête, contrôles, date du lancement, marque', () => {
  const m = lire(BETA);
  assert.match(m.split('\n')[0], /(NON APPLIQUÉE|APPLIQUÉE en production)/);
  assert.match(m, /Contrôles en lecture après application/);
  assert.match(m, /VALUES \('limite_a_partir', 20261219\)/);
  assert.match(m, /revenu_universel_beta_v1/);
});

const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : partie SQL exécutée avec PGLITE_DIR', { skip: true }, () => {}); return; }

// Même socle que le banc du bloc B (relu dans son fichier, pour ne pas le dupliquer).
const SOCLE = lire('outils/bancs/banc-revenu-universel-pglite-20261126.cjs').match(/const SOCLE = `([\s\S]*?)`;/)[1];
async function base() {
  const db = new PGlite();
  await db.exec(SOCLE); await db.exec(lire(PROD)); await db.exec(lire(MIG)); await db.exec(lire(BETA));
  await db.exec(`INSERT INTO personnages_donnees (name, nationalite, country, poste, created_at) VALUES
    ('Testeuse', 'soviet', 'soviet', NULL, now() - interval '30 days'),
    ('Testeur', 'republic', 'republic', NULL, now() - interval '30 days'),
    ('Nouveau', 'republic', 'republic', NULL, now() - interval '2 days')`);
  return db;
}
const limite = (db, v) => db.query("UPDATE revenu_universel_parametres SET valeur = $1 WHERE cle = 'limite_a_partir'", [v]);
const percevoir = async (db, nom) => { await db.query("SELECT set_config('banc.moi', $1, false)", [nom]); return (await db.query('SELECT salaire_civil_percevoir() r')).rows[0].r; };

test('avant le lancement : tous les testeurs le touchent, même après 10 jours, dans les deux empires', async () => {
  const db = await base();
  await limite(db, 29991231);
  assert.equal((await percevoir(db, 'Testeuse')).montant, 45);
  assert.equal((await percevoir(db, 'Testeur')).montant, 150);
});

test('après le lancement : la règle des 10 premiers jours reprend', async () => {
  const db = await base();
  await limite(db, 20000101);
  assert.equal((await percevoir(db, 'Testeur')).raison, 'revenu_universel_termine');
  assert.equal((await percevoir(db, 'Nouveau')).montant, 150);
});

test('rejouée, la migration garde le réglage en place', async () => {
  const db = await base();
  await limite(db, 20270101);
  await db.exec(lire(BETA));
  assert.equal(Number((await db.query("SELECT valeur FROM revenu_universel_parametres WHERE cle = 'limite_a_partir'")).rows[0].valeur), 20270101);
});
