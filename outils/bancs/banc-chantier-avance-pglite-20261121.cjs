'use strict';
// Chantier « construction » — accélération par le travail des joueurs (migration 20261121140000), éprouvée dans un vrai
// PostgreSQL local (PGlite) sur les définitions de production de chantier_travailler et chantier_jour_traiter.
// Cas du document de design : jour normal ; jour complet sans avance ; jour d'avance partiel complété par les PNJ
// (+2 jours) ; troisième jour refusé ; matériaux insuffisants pour deux jours ; palier d'appel de fonds non versé.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
const { PGlite } = charger('@electric-sql/pglite');

// Building de 24 jours, comme celui d'Arnie : capacité 84 000 / 70 / 24 = 50 heures par jour.
function chantier(o = {}) {
  return Object.assign({ type: 'construction', niveau: 'building', coutTotal: 120000, dureeJours: 24, progressionJours: 1, totalVerse: 120000,
    tresorerie: 60000, coutTravail: 84000, coutMateriaux: 36000, heuresTotales: 1200, heuresFaites: 0, maitreOuvrage: 'Arnie',
    stockMateriaux: { bois: 1000, minerai: 1000, metal: 1000 }, travauxPJ: [], evenements: [], jourTraite: '2000-01-01' }, o);
}
async function base(ch, migre = true) {
  const db = new PGlite();
  await db.exec(lire('outils/bancs/fixtures/chantier-pglite-socle.sql.txt'));
  if (migre) await db.exec(lire('migrations/20261121140000_chantier_jour_avance.sql'));
  await db.query("INSERT INTO terrains_etat VALUES ('republic_terrain-a-batir-3', 'republic', $1, now())",
    [JSON.stringify({ proprietaire: 'Arnie', city: 'capitale', chantier: ch })]);
  await db.query("INSERT INTO personnages_donnees VALUES ('Arnie', 500, 0, 0, 30, 'capitale', now()), ('Tom Tom', 500, 0, 0, 30, 'capitale', now())");
  return db;
}
const travailler = async (db, qui, h) => (await db.query("SELECT chantier_travailler($1, 'republic', 'republic_terrain-a-batir-3', $2) r", [qui, h])).rows[0].r;
const nuit = async db => (await db.query("SELECT chantier_jour_traiter('republic_terrain-a-batir-3') r")).rows[0].r;
const ch = async db => JSON.parse((await db.query("SELECT data FROM terrains_etat")).rows[0].data).chantier;

test('jour normal : aucun joueur, les PNJ font le jour, +1 jour', async () => {
  const db = await base(chantier());
  await nuit(db);
  const c = await ch(db);
  assert.equal(c.progressionJours, 2); assert.equal(c.jourAvance, undefined);
  assert.equal(c.evenements.filter(e => e.cle === 'journee_avance').length, 0);
});

test('jour complet par les joueurs, sans avance : +1 jour', async () => {
  const db = await base(chantier());
  assert.equal((await travailler(db, 'Arnie', 50)).heures, 50);
  const c0 = await ch(db); assert.equal(c0.heuresFaites, 50); assert.equal(c0.jourAvance ?? null, null);
  await nuit(db);
  assert.equal((await ch(db)).progressionJours, 2);
});

test('jour d’avance partiel complété par les PNJ : +2 jours, coût total inchangé', async () => {
  const db = await base(chantier());
  const r = await travailler(db, 'Arnie', 70);          // 50 du jour + 20 du jour d'avance
  assert.equal(r.heures, 70);
  const c0 = await ch(db); assert.equal(c0.heuresFaites, 50); assert.equal(c0.jourAvance.heures, 20);
  await nuit(db);
  const c = await ch(db);
  assert.equal(c.progressionJours, 3, '+2 jours');
  const av = c.evenements.find(e => e.cle === 'journee_avance');
  assert.equal(av.heuresPJ, 20); assert.equal(av.heuresPNJ, 30); assert.equal(av.jourGagne, true);
  assert.equal(c.jourAvance, undefined, 'remis à zéro');
  // Matériaux : deux jours consommés (100 + 100 de bois).
  assert.equal(c.stockMateriaux.bois, 800);
  // Coût du travail : 70 h PJ × 70 + 30 h PNJ × 70 = 100 h × 70 = deux jours de 50 h.
  const pnj = c.evenements.reduce((a, e) => a + (Number(e.coutPNJ) || 0), 0);
  assert.equal(pnj + r.montant, 100 * 70);
});

test('troisième jour refusé : jamais plus d’un jour d’avance par jour', async () => {
  const db = await base(chantier());
  assert.equal((await travailler(db, 'Arnie', 200)).heures, 100, 'au plus 50 + 50');
  const refus = await travailler(db, 'Tom Tom', 1);
  assert.equal(refus.ok, false); assert.equal(refus.raison, 'aucune_heure_travaillable');
  await nuit(db);
  assert.equal((await ch(db)).progressionJours, 3, 'au plus deux jours par nuit');
});

test('matériaux insuffisants pour deux jours : pas de jour d’avance au-delà de ce que le stock permet', async () => {
  const db = await base(chantier({ stockMateriaux: { bois: 150, minerai: 75, metal: 51 } }));   // jour 2 entier (métal 34) + moitié du jour 3
  const r = await travailler(db, 'Arnie', 200);
  assert.equal(r.heures, 75, '50 + moitié du jour d’avance');
  await nuit(db);
  const c = await ch(db);
  assert.ok(c.progressionJours < 3 && c.progressionJours > 2, 'avancement proportionnel');
});

test('palier d’appel de fonds non versé : pas de jour d’avance au-delà du tiers sans les 70 %', async () => {
  const db = await base(chantier({ totalVerse: 42000, progressionJours: 6.5 }));   // tiers = 8 jours ; 35 % versés
  const r = await travailler(db, 'Arnie', 200);
  assert.equal(r.heures, 75, '50 du jour 7 + 25 (jusqu’au jour 8 = tiers)');
  await nuit(db);
  assert.equal((await ch(db)).progressionJours, 8, 'bloqué au tiers');
});

test('sans la migration (état actuel) : les heures s’arrêtent à celles du jour', async () => {
  const db = await base(chantier(), false);
  assert.equal((await travailler(db, 'Arnie', 200)).heures, 50);
});
