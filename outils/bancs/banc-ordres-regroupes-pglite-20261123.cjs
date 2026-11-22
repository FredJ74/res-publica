'use strict';
// Regroupement des ordres (Fred, 22/11/2026, soir ; GAME-DESIGN-INTERFACE-ACCUEIL-20261122.md, point 17), dans un vrai
// PostgreSQL local (PGlite) : migration 20261123130000_ordres_regroupes.sql appliquée sur les définitions de production
// de desinstaller_lire / desinstaller_materiel (fixture ordres-regroupes-desinstaller.sql.txt, md5 vérifiés).
//   • désinstaller : son matériel, ou tout le matériel chez soi (2 PA, au sol) ; le matériel d'autrui ailleurs : refusé ;
//   • lecture : drapeau « volable » ; plein air : toujours refusé ; rejouable.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : banc exécuté par son workflow dédié (PGLITE_DIR)', { skip: true }, () => {}); return; }

const UID = { Tom: '00000000-0000-0000-0000-000000000002', Arnie: '00000000-0000-0000-0000-000000000003' };
const MIGRATION = 'migrations/20261123130000_ordres_regroupes.sql';
async function base({ migrer = true } = {}) {
  const db = new PGlite();
  await db.exec(lire('outils/bancs/fixtures/krasnov-lot-suite-pglite-socle.sql.txt'));
  await db.exec(lire('migrations/20261122162000_pieces_inspecter_desinstaller.sql'));
  await db.exec(lire('outils/bancs/fixtures/ordres-regroupes-desinstaller.sql.txt'));
  if (migrer) await db.exec(lire(MIGRATION));
  for (const [n, u] of Object.entries(UID)) await db.query('INSERT INTO personnages VALUES ($1, $2)', [n, u]);
  await db.query(`INSERT INTO personnages_donnees (name, country, current_city, current_building, current_room, pa) VALUES
    ('Tom', 'soviet', 'ville_b', 'bureaux', 'bureau_1', 10), ('Arnie', 'soviet', 'ville_b', 'bureaux', 'bureau_1', 10)`);
  return db;
}
const un = async (db, sql, args = []) => (await db.query(sql, args)).rows[0];
async function appel(db, qui, sql, args = []) {
  await db.query("SELECT set_config('test.uid', $1, false)", [UID[qui]]);
  return (await db.query(sql, args)).rows[0].r;
}
const poser = async (db, prop, gen = 'ordinateur-complet') => (await un(db, `INSERT INTO equipements_installes (proprietaire, generique_id, objet, pays, ville, batiment, piece)
  VALUES ($1, $2, $3, 'soviet', 'ville_b', 'bureaux', 'bureau_1') RETURNING id`, [prop, gen, JSON.stringify({ name: 'Ordinateur de ' + prop, id: 'o-' + prop + '-' + gen })])).id;
const desinstaller = (db, qui, id) => appel(db, qui, 'SELECT desinstaller_materiel(gen_random_uuid(), $1) r', [id]);

test('la fixture reproduit les corps de production (md5 de prosrc relevés le 22/11/2026)', async () => {
  const db = await base({ migrer: false });
  const md5 = Object.fromEntries((await db.query("SELECT proname, md5(prosrc) m FROM pg_proc WHERE proname IN ('desinstaller_lire', 'desinstaller_materiel')")).rows.map(r => [r.proname, r.m]));
  assert.equal(md5.desinstaller_lire, '53fbc951dbe121dcbac039303b70bdfd');
  assert.equal(md5.desinstaller_materiel, 'f841877ff6da4469eb5ebcae7d28bb49');
});

test('migration rejouable, marques présentes une fois, ancrages comptés', async () => {
  const db = await base();
  await db.exec(lire(MIGRATION));
  const m = (await un(db, "SELECT pg_get_functiondef('desinstaller_materiel(uuid,uuid)'::regprocedure) d")).d;
  const l = (await un(db, "SELECT pg_get_functiondef('desinstaller_lire()'::regprocedure) d")).d;
  assert.equal(m.split('ordres_regroupes_desinstaller_legal_v1').length - 1, 1);
  assert.equal(l.split('ordres_regroupes_lire_volable_v1').length - 1, 1);
  assert.match(m, /plein_air_desinstaller_v1/); assert.match(l, /plein_air_desinstaller_lire_v1/);
  assert.doesNotMatch(lire(MIGRATION), /^\s*(BEGIN|COMMIT)\s*;/m, 'sans BEGIN/COMMIT');
});

test('le matériel d’autrui hors de chez soi ne se désinstalle plus : refus « pas_a_vous », rien ne bouge, aucun PA', async () => {
  const db = await base();
  const e = await poser(db, 'Tom');
  const r = await desinstaller(db, 'Arnie', e);
  assert.deepEqual(r, { ok: false, raison: 'pas_a_vous' });
  assert.equal((await un(db, 'SELECT count(*)::int n FROM equipements_installes WHERE id = $1', [e])).n, 1);
  assert.equal((await un(db, "SELECT pa FROM personnages_donnees WHERE name = 'Arnie'")).pa, 10);
  assert.equal((await un(db, 'SELECT count(*)::int n FROM crim_affaires')).n, 0, 'aucun vol ouvert par la désinstallation');
  // Même avec un témoin dans la pièce (ancienne branche « vol ») : toujours refusé.
  await db.query("INSERT INTO reglages_test VALUES ('temoin', '1')");
  assert.equal((await desinstaller(db, 'Arnie', e)).raison, 'pas_a_vous');
});

test('son propre matériel, partout : 2 PA, l’objet tombe au sol, légal', async () => {
  const db = await base();
  const e = await poser(db, 'Arnie');
  const r = await desinstaller(db, 'Arnie', e);
  assert.equal(r.ok, true); assert.equal(r.legal, true); assert.equal(r.au_sol, true); assert.equal(r.pa, 8);
  assert.equal((await un(db, 'SELECT count(*)::int n FROM objets_abandonnes WHERE id = $1', [r.objet_sol])).n, 1);
  assert.equal((await un(db, 'SELECT count(*)::int n FROM crim_affaires')).n, 0);
});

test('chez soi : tout le matériel se désinstalle légalement, y compris celui d’autrui', async () => {
  const db = await base();
  const e = await poser(db, 'Tom');
  await db.query("INSERT INTO locaux_test VALUES ('Arnie', 'bureaux', 'bureau_1')");
  const r = await desinstaller(db, 'Arnie', e);
  assert.equal(r.ok, true); assert.equal(r.legal, true); assert.equal(r.au_sol, true);
});

test('lecture : « volable » seulement pour le matériel d’autrui hors armoire ; armoire d’autrui invisible hors de chez soi', async () => {
  const db = await base();
  await poser(db, 'Tom'); await poser(db, 'Arnie'); await poser(db, 'Tom', 'armoire_souvenirs');
  const l = await appel(db, 'Arnie', 'SELECT desinstaller_lire() r');
  assert.equal(l.ok, true); assert.equal(l.chez_soi, false);
  const parProprio = Object.fromEntries(l.materiel.map(m => [m.nom, m]));
  assert.equal(l.materiel.length, 2, 'l’armoire de Tom n’apparaît pas');
  assert.deepEqual([parProprio['Ordinateur de Tom'].volable, parProprio['Ordinateur de Tom'].legal, parProprio['Ordinateur de Tom'].a_moi], [true, false, false]);
  assert.deepEqual([parProprio['Ordinateur de Arnie'].volable, parProprio['Ordinateur de Arnie'].legal, parProprio['Ordinateur de Arnie'].a_moi], [false, true, true]);
  // Chez soi : l'armoire d'autrui apparaît, désinstallable, jamais volable.
  await db.query("INSERT INTO locaux_test VALUES ('Arnie', 'bureaux', 'bureau_1')");
  const c = await appel(db, 'Arnie', 'SELECT desinstaller_lire() r');
  const armoire = c.materiel.find(m => m.generique === 'armoire_souvenirs');
  assert.equal(c.materiel.length, 3); assert.equal(armoire.volable, false); assert.equal(armoire.legal, true);
});

test('plein air : lecture et désinstallation toujours refusées (piece_plein_air_interne)', async () => {
  const db = await base();
  const e = await poser(db, 'Arnie');
  await db.query("INSERT INTO plein_air_test VALUES ('soviet', 'ville_b', 'bureaux', 'bureau_1')");
  assert.equal((await appel(db, 'Arnie', 'SELECT desinstaller_lire() r')).raison, 'plein_air');
  assert.equal((await desinstaller(db, 'Arnie', e)).raison, 'plein_air');
});
