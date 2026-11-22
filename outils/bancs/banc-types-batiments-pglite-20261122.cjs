'use strict';
// Refonte des types de bâtiments, 7 → 5 (Fred, 22/11/2026, nuit, point 6), migration 20261122130000, dans un vrai
// PostgreSQL local (PGlite) : paliers, découpage des lots (Logement fixe, Building plafonné, premium ≥ 600 m²), catégorie
// selon le donneur d'ordre (mairie = social, joueur = classique), permis, acquisition, valeur Helvetia.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : banc exécuté par son workflow dédié (PGLITE_DIR)', { skip: true }, () => {}); return; }

async function base() {
  const db = new PGlite();
  await db.exec(lire('outils/bancs/fixtures/types-batiments-socle.sql.txt'));
  await db.exec(lire('migrations/20261122130000_types_batiments_cinq.sql'));
  return db;
}
const un = async (db, sql, args = []) => (await db.query(sql, args)).rows[0];
const lots = async (db, etat, niveau, plan) => (await un(db, 'SELECT chantier_plan_normaliser_interne($1::jsonb, $2, $3::jsonb) r', [JSON.stringify(etat), niveau, JSON.stringify(plan)])).r;
const erreur = async (db, etat, niveau, plan) => { try { await lots(db, etat, niveau, plan); return null; } catch (e) { return e.message; } };
const JOUEUR = { proprietaire: 'Arnie', surface: 2300 }, MAIRIE = { proprietaire: 'ville:republic:capitale', surface: 2300 };

test('cinq paliers, aux montants de Fred ; plus de logements sociaux petit, moyen ni barre', async () => {
  const db = await base();
  const p = (await db.query('SELECT palier, cout_total::int c, duree_jours d, heures_totales::int h FROM chantiers_paliers ORDER BY cout_total, palier')).rows;
  assert.deepEqual(p, [{ palier: 'hangar', c: 30000, d: 6, h: 300 }, { palier: 'commerce_standard', c: 60000, d: 12, h: 600 },
    { palier: 'commerce_premium', c: 90000, d: 18, h: 900 }, { palier: 'logement', c: 90000, d: 18, h: 900 }, { palier: 'building', c: 120000, d: 24, h: 1200 }]);
  assert.equal((await un(db, "SELECT gabarit->>'niveau' n FROM chantiers_paliers WHERE palier = 'logement'")).n, 'logement');
});

test('Logement : 6 appartements (3 × 45 m², 3 × 75 m²) ; mairie = logements sociaux, joueur = logements classiques', async () => {
  const db = await base();
  const social = await lots(db, MAIRIE, 'logement', null), classique = await lots(db, JOUEUR, 'logement', null);
  for (const l of [social, classique]) assert.deepEqual(l.map(x => x.surface), [45, 45, 45, 75, 75, 75]);
  assert.ok(social.every(x => x.logementSocial === true && x.destination === 'logement_social' && x.loyer > 0 && x.bonusMoralSommeil > 0 && x.bonusSanteSommeil > 0));
  assert.ok(classique.every(x => !x.logementSocial && x.destination === 'appartement' && x.loyer === 0));
});

test('Building : commerces ≥ 300 m², appartements ≥ 150 m², au plus 6 commerces et 14 appartements, somme ≤ surface', async () => {
  const db = await base();
  const c = (i, s) => ({ id: 'c' + i, destination: 'commerce', surface: s }), a = (i, s) => ({ id: 'a' + i, destination: 'appartement', surface: s });
  assert.equal((await lots(db, JOUEUR, 'building', [c(1, 300), a(1, 150), a(2, 150)])).length, 3);
  assert.equal((await lots(db, { ...JOUEUR, surface: 3000 }, 'building', Array.from({ length: 14 }, (_, i) => a(i, 150)))).length, 14, 'sans aucun commerce');
  assert.equal(await erreur(db, JOUEUR, 'building', [c(1, 299)]), 'plan_invalide');
  assert.equal(await erreur(db, JOUEUR, 'building', [a(1, 149)]), 'plan_invalide');
  assert.equal(await erreur(db, { ...JOUEUR, surface: 9999 }, 'building', Array.from({ length: 7 }, (_, i) => c(i, 300))), 'plan_invalide', '7 commerces');
  assert.equal(await erreur(db, { ...JOUEUR, surface: 9999 }, 'building', Array.from({ length: 15 }, (_, i) => a(i, 150))), 'plan_invalide', '15 appartements');
  assert.equal(await erreur(db, JOUEUR, 'building', [c(1, 1200), c(2, 1200)]), 'plan_invalide', 'somme > surface');
  // Mairie : les appartements d'un building sont des logements sociaux ; les commerces restent des commerces.
  const m = await lots(db, MAIRIE, 'building', [c(1, 300), a(1, 150)]);
  assert.equal(m[0].destination, 'commerce'); assert.equal(m[1].destination, 'logement_social'); assert.equal(m[1].logementSocial, true);
  const j = await lots(db, JOUEUR, 'building', [a(1, 150)]);
  assert.equal(j[0].destination, 'appartement'); assert.equal(j[0].logementSocial, undefined);
});

test('Commerce premium : boutiques de 600 m² minimum', async () => {
  const db = await base();
  assert.equal((await lots(db, JOUEUR, 'commerce_premium', [{ id: 'b1', surface: 600 }])).length, 1);
  assert.equal(await erreur(db, JOUEUR, 'commerce_premium', [{ id: 'b1', surface: 599 }]), 'plan_invalide');
});

test('permis : Logement ouvert aux joueurs, 6 jours, libellé « Logement » ; anciens types refusés ; décision, acquisition, Helvetia', async () => {
  const db = await base();
  await db.query("INSERT INTO terrains_etat VALUES ('t1', 'republic', '{\"proprietaire\":\"Arnie\",\"surface\":2300}', NULL), ('t2', 'republic', '{\"proprietaire\":\"Arnie\",\"surface\":1500}', NULL)");
  const r = (await un(db, "SELECT terrain_permis_deposer('t1', 'logement', gen_random_uuid()) r")).r;
  assert.equal(r.ok, true); assert.equal(r.document.palierLabel, 'Logement'); assert.equal(r.document.duree, 6);
  assert.equal((await un(db, "SELECT terrain_permis_deposer('t2', 'logement', gen_random_uuid()) r")).r.raison, 'terrain_trop_petit');
  for (const v of ['logements_petit', 'logements_moyen', 'logements_barre']) assert.equal((await un(db, 'SELECT terrain_permis_deposer($1, $2, gen_random_uuid()) r', ['t1', v])).r.raison, 'palier_invalide');
  assert.equal((await un(db, "SELECT terrain_permis_decider('logement', true, null, null) r")).r.lib, 'Logement');
  assert.equal((await un(db, "SELECT terrain_acquisition_commande('t1', 'compromis', '{\"permis\":\"logement\"}', null) r")).r.ok, true);
  assert.equal((await un(db, "SELECT terrain_acquisition_commande('t1', 'compromis', '{\"permis\":\"logements_barre\"}', null) r")).r.raison, 'palier_invalide');
  assert.equal(Number((await un(db, 'SELECT traiter_prets_helvetia_quotidien() r')).r.logement), 70000, 'les logements comptent');
});

test('migration rejouable', async () => {
  const db = await base();
  await db.exec(lire('migrations/20261122130000_types_batiments_cinq.sql'));
  assert.equal(Number((await un(db, 'SELECT count(*) n FROM chantiers_paliers')).n), 5);
});
