'use strict';
// Chantier — heures et matériaux (Fred, 22/11/2026, nuit, point 2), migration 20261122120000, dans un vrai PostgreSQL
// local (PGlite) sur les définitions de production de chantier_travailler et chantier_jour_traiter :
// heures toujours ouvertes ; commande de nuit pour le jour suivant ; commande aussitôt le jour d'avance ouvert ;
// entrepôt insuffisant → journal du chantier (plus de courrier) ; dernière commande consignée.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : banc exécuté par son workflow dédié (PGLITE_DIR)', { skip: true }, () => {}); return; }

// Building de 24 jours, comme celui d'Arnie : 50 h par jour ; besoin du jour 100 bois, 50 minerai, 33 ou 34 métal.
function chantier(o = {}) {
  return Object.assign({ type: 'construction', niveau: 'building', coutTotal: 120000, dureeJours: 24, progressionJours: 1, totalVerse: 120000,
    tresorerie: 60000, coutTravail: 84000, coutMateriaux: 36000, heuresTotales: 1200, heuresFaites: 0, maitreOuvrage: 'Arnie',
    stockMateriaux: { bois: 0, minerai: 0, metal: 0 }, travauxPJ: [], evenements: [], jourTraite: '2000-01-01' }, o);
}
async function base(ch, entrepot) {
  const db = new PGlite();
  await db.exec(lire('outils/bancs/fixtures/chantier-pglite-socle.sql.txt'));
  await db.exec(lire('outils/bancs/fixtures/chantier-commande-entrepot.sql.txt'));
  await db.exec(lire('migrations/20261121140000_chantier_jour_avance.sql'));
  await db.exec(lire('migrations/20261122120000_chantier_heures_ouvertes_commande_nuit.sql'));
  if (entrepot) for (const [m, q] of Object.entries(entrepot)) await db.query('UPDATE entrepot_test SET q = $2 WHERE m = $1', [m, q]);
  await db.query("INSERT INTO terrains_etat VALUES ('republic_terrain-a-batir-3', 'republic', $1, now())",
    [JSON.stringify({ proprietaire: 'Arnie', city: 'capitale', chantier: ch })]);
  await db.query("INSERT INTO personnages_donnees VALUES ('Arnie', 500, 0, 0, 30, 'capitale', now()), ('Tom Tom', 500, 0, 0, 30, 'capitale', now())");
  return db;
}
const travailler = async (db, qui, h) => (await db.query("SELECT chantier_travailler($1, 'republic', 'republic_terrain-a-batir-3', $2) r", [qui, h])).rows[0].r;
const nuit = async db => (await db.query("SELECT chantier_jour_traiter('republic_terrain-a-batir-3') r")).rows[0].r;
const lireCh = async db => JSON.parse((await db.query('SELECT data FROM terrains_etat')).rows[0].data).chantier;
const nouvelleJournee = db => db.query("UPDATE terrains_etat SET data = jsonb_set(data::jsonb, '{chantier,jourTraite}', '\"2000-01-01\"')::text");

test('heures toujours ouvertes : 50 h avec un stock vide', async () => {
  const db = await base(chantier());
  const r = await travailler(db, 'Arnie', 50);
  assert.equal(r.ok, true); assert.equal(r.heures, 50);
});

test('la nuit : consommation du jour écoulé puis commande du jour suivant ; stock plein au matin', async () => {
  const db = await base(chantier({ stockMateriaux: { bois: 100, minerai: 50, metal: 34 } }));   // jour 2 couvert
  await travailler(db, 'Arnie', 50);
  await nuit(db);
  const c = await lireCh(db);
  assert.equal(c.progressionJours, 2);
  assert.deepEqual(c.stockMateriaux, { bois: 100, minerai: 50, metal: 33 }, 'besoin du jour 3 livré cette nuit');
  assert.equal(c.derniereCommande.motif, 'nuit'); assert.equal(c.derniereCommande.pourJour, 3);
  assert.deepEqual(c.derniereCommande.livre, { bois: 100, minerai: 50, metal: 33 });
  assert.deepEqual(c.derniereCommande.manque, {}); assert.equal(c.derniereCommande.cout, 183);
  assert.equal(c.tresorerie, 60000 - 50 * 70 - 183, 'salaires des joueurs et commande payés par la trésorerie du chantier');
});

test('entrepôt insuffisant : le manque va au journal du chantier, aucun courrier ; les joueurs peuvent vendre', async () => {
  const db = await base(chantier({ stockMateriaux: { bois: 100, minerai: 50, metal: 34 } }), { bois: 0, minerai: 20, metal: 1000 });
  await travailler(db, 'Arnie', 50);
  await nuit(db);
  const c = await lireCh(db);
  assert.deepEqual(c.derniereCommande.livre, { minerai: 20, metal: 33 });
  assert.deepEqual(c.derniereCommande.manque, { bois: 100, minerai: 30 });
  const j = c.evenements.filter(e => e.cle === 'manque_materiaux');
  assert.equal(j.length, 1); assert.deepEqual(j[0].manque, { bois: 100, minerai: 30 });
  // Le jour suivant, les heures restent ouvertes malgré le manque.
  await nouvelleJournee(db);
  assert.equal((await travailler(db, 'Tom Tom', 50)).heures, 50);
  // Nuit suivante, jour écoulé sans bois : aucun courrier de pénurie.
  await nuit(db);
  assert.equal(Number((await db.query("SELECT count(*) n FROM courriers_test WHERE sujet LIKE '%matériaux manquants%'")).rows[0].n), 0);
});

test('jour d’avance ouvert par les joueurs : la commande de ce jour part aussitôt, une seule fois', async () => {
  const db = await base(chantier({ stockMateriaux: { bois: 100, minerai: 50, metal: 34 } }));
  const r = await travailler(db, 'Arnie', 60);
  assert.equal(r.heures, 60);
  const c = await lireCh(db);
  assert.equal(c.jourAvance.heures, 10);
  assert.equal(c.derniereCommande.motif, 'avance'); assert.equal(c.derniereCommande.pourJour, 3);
  assert.deepEqual(c.stockMateriaux, { bois: 200, minerai: 100, metal: 67 }, 'jour 2 et jour 3');
  await travailler(db, 'Tom Tom', 5);
  assert.equal((await lireCh(db)).evenements.filter(e => e.cle === 'commande_materiaux').length, 1);
  await nuit(db);
  const n = await lireCh(db);
  assert.equal(n.progressionJours, 3, '+2 jours');
  assert.equal(n.derniereCommande.motif, 'nuit'); assert.equal(n.derniereCommande.pourJour, 4);
});

test('migration rejouable ; raccords posés une seule fois', async () => {
  const db = await base(chantier());
  await db.exec(lire('migrations/20261122120000_chantier_heures_ouvertes_commande_nuit.sql'));
  for (const [f, m] of [['chantier_travailler(text,text,text,integer)', 'chantier_commande_avance_v1'], ['chantier_jour_traiter(text)', 'chantier_commande_nuit_v1'],
                        ['chantier_jour_traiter(text)', 'chantier_sans_courrier_v1'], ['chantier_travailler(text,text,text,integer)', 'chantier_heures_ouvertes_v1']]) {
    const d = (await db.query(`SELECT pg_get_functiondef('${f}'::regprocedure) d`)).rows[0].d;
    assert.equal(d.split(m).length, 2, f + ' ' + m);
  }
});
