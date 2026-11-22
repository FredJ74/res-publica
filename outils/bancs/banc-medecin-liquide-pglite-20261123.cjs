'use strict';
// Médecin payé en liquide seulement (Fred, 22/11/2026, soir, GAME-DESIGN-SANTE-20261122.md, « Suites », point 5) :
// migration 20261123160000 après 20261122230000 et 20261122234000, dans un vrai PostgreSQL local (PGlite).
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : banc exécuté par son workflow dédié (PGLITE_DIR)', { skip: true }, () => {}); return; }

const SOCLE = 'migrations/20261122230000_sante_socle.sql', MIGRATION = 'migrations/20261122234000_medecin_montrer.sql';
const LIQUIDE = 'migrations/20261123160000_medecin_paiement_liquide.sql';
const U = { doc: '00000000-0000-0000-0000-000000000001', arnie: '00000000-0000-0000-0000-000000000002', zoe: '00000000-0000-0000-0000-000000000003' };
const TROUSSE = { id: 'mil-1', name: 'Trousse de premiers secours', type: 'soin', produitMilitaire: 'trousse_secours', usageUnique: true };
const LETTRE = { id: 'l-1', name: 'Lettre scellée', desc: 'Une lettre au sceau du Tsar.', imageUrl: 'images/lettre.png', icon: 'ti-mail' };

async function base() {
  const db = new PGlite();
  await db.exec(lire('outils/bancs/fixtures/medecin-montrer-pglite-socle.sql.txt'));
  for (const [n, u] of [['Docteur Vlad', U.doc], ['Arnie', U.arnie], ['Zoé', U.zoe]]) await db.query('INSERT INTO personnages VALUES ($1,$2)', [n, u]);
  const ici = { country: 'soviet', city: 'ville_b', b: 'hopital-krasnov', r: 'accueil' };
  await db.query(`INSERT INTO personnages_donnees (name, user_id, career, country, current_city, current_building, current_room, pa, hp, moral, liquide, inventory)
    VALUES ('Docteur Vlad', $1, 'doctor', $2, $3, $4, $5, 10, 90, 50, 0, $6),
           ('Arnie', $7, 'worker', $2, $3, $4, $5, 20, 40, 50, 30, $8),
           ('Zoé', $9, 'worker', $2, $3, 'bar', 'salle', 20, 60, 50, 500, '[]')`,
    [U.doc, ici.country, ici.city, ici.b, ici.r, JSON.stringify([TROUSSE, LETTRE]), U.arnie, JSON.stringify([LETTRE]), U.zoe]);
  await db.query("INSERT INTO comptes_bancaires VALUES ('cb-arnie', 'Arnie', 'nationale', 100)");
  await db.query("INSERT INTO personnages_maladies (nom, cle) VALUES ('Arnie', 'grippe'), ('Arnie', 'gueule_de_bois')");
  await db.exec(lire(SOCLE));
  await db.exec(lire(MIGRATION));
  await db.exec(lire(LIQUIDE));
  return db;
}
const un = async (db, sql, p) => (await db.query(sql, p)).rows[0].r;
const en = (db, uid) => db.query("SELECT set_config('test.uid', $1, false)", [uid || '']);
const fiche = (db, n) => db.query('SELECT pa, hp, liquide, inventory FROM personnages_donnees WHERE name = $1', [n]).then(r => r.rows[0]);
const evenements = async (db, uid) => { await en(db, uid); return (await un(db, 'SELECT personnage_evenements_lire() r')).evenements; };


test('le patient paie en liquide seulement : la banque ne complète jamais, refus avant tout prélèvement', async () => {
  const db = await base();
  await db.exec(lire(LIQUIDE));   // rejouable
  await en(db, U.doc);
  const p = await un(db, "SELECT medecin_proposer('Arnie', 'diagnostic', 50) r");   // Arnie : 30 en liquide, 100 en banque
  await en(db, U.arnie);
  assert.equal((await un(db, 'SELECT medecin_repondre($1, true) r', [p.id])).raison, 'fonds_insuffisants');
  let a = await fiche(db, 'Arnie'), d = await fiche(db, 'Docteur Vlad');
  assert.deepEqual([a.liquide, d.liquide, d.pa], [30, 0, 10], 'rien de prélevé, aucun PA retiré');
  assert.equal(Number(await un(db, "SELECT solde r FROM comptes_bancaires WHERE id='cb-arnie'")), 100);
  await en(db, U.doc);
  const q = await un(db, "SELECT medecin_proposer('Arnie', 'diagnostic', 25) r");
  await en(db, U.arnie);
  const r = await un(db, 'SELECT medecin_repondre($1, true) r', [q.id]);
  assert.equal(r.ok, true, JSON.stringify(r)); assert.equal(Number(r.paye), 25);
  a = await fiche(db, 'Arnie'); d = await fiche(db, 'Docteur Vlad');
  assert.deepEqual([a.liquide, d.liquide, d.pa], [5, 25, 9]);
  assert.equal(Number(await un(db, "SELECT solde r FROM comptes_bancaires WHERE id='cb-arnie'")), 100, 'la banque reste un dépôt volontaire');
  for (const m of ['medecin_liquide_v1', 'medecin_liquide_debit_v1'])
    assert.equal(Number(await un(db, "SELECT count(*) r FROM pg_proc WHERE prosrc LIKE '%' || $1 || '%'", [m])), 1, m);
});
