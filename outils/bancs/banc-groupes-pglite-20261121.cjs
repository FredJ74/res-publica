'use strict';
// Groupes, masque, cachette collective (migration 20261121180000), éprouvés dans un vrai PostgreSQL local (PGlite).
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : banc exécuté par son workflow dédié (PGLITE_DIR)', { skip: true }, () => {}); return; }

const MIGRATION = 'migrations/20261121180000_groupes_presents_masques_cachette.sql';
const U = { tom: '00000000-0000-0000-0000-000000000001', arnie: '00000000-0000-0000-0000-000000000002', vlad: '00000000-0000-0000-0000-000000000003', olga: '00000000-0000-0000-0000-000000000004' };
async function base() {
  const db = new PGlite();
  await db.exec(lire('outils/bancs/fixtures/groupes-pglite-socle.sql.txt'));
  await db.exec(lire(MIGRATION));
  return db;
}
async function comme(db, uid, sql) { await db.exec(`SELECT set_config('test.uid', '${uid}', false)`); return (await db.query(sql)).rows[0].r; }
const presents = async (db, uid) => (await comme(db, uid, 'SELECT public.presents_ici() r'));
const un = async (db, sql) => (await db.query(sql)).rows[0];

test('rue : un masqué reste listé « Personnage masqué », sans nom réel ; absent si son battement est vieux', async () => {
  const db = await base();
  await db.exec("UPDATE personnages_donnees SET masque = true WHERE name = 'Tom Tom'");
  const p = await presents(db, U.arnie);
  assert.equal(p.ok, true);
  const noms = p.presents.map(x => x.name).sort();
  assert.deepEqual(noms, ['Personnage masqué', 'Vlad']);
  const tt = p.presents.find(x => x.masque);
  assert.equal(tt.jeton, 'jeton-tt'); assert.ok(!JSON.stringify(p).includes('Tom Tom'));
  assert.equal(p.presents.find(x => x.name === 'Vlad').connecte, false);
  // Le masqué voit son propre état.
  assert.equal((await presents(db, U.tom)).moi.masque, true);
  // Olga, dans une autre rue, ne voit personne de la place.
  assert.equal((await presents(db, U.olga)).presents.length, 0);
});

test('groupe : clé commune, chef « Groupe <chef> » ; chef masqué = « Groupe d’un personnage masqué » pour les autres seulement', async () => {
  const db = await base();
  await db.exec("INSERT INTO groupes_pj_adhesions (membre, chef) VALUES ('Arnie', 'Tom Tom')");
  let p = await presents(db, U.vlad);
  const tt = p.presents.find(x => x.name === 'Tom Tom'), ar = p.presents.find(x => x.name === 'Arnie');
  assert.equal(tt.groupe, ar.groupe); assert.equal(tt.est_chef, true); assert.equal(ar.est_chef, false);
  assert.equal(tt.groupe_libelle, 'Groupe Tom Tom');
  await db.exec("UPDATE personnages_donnees SET masque = true WHERE name = 'Tom Tom'");
  p = await presents(db, U.vlad);
  assert.equal(p.presents.find(x => x.name === 'Arnie').groupe_libelle, "Groupe d'un personnage masqué");
  assert.ok(!JSON.stringify(p).includes('Tom Tom'), JSON.stringify(p));
  const vuParArnie = await presents(db, U.arnie);
  assert.equal(vuParArnie.presents.find(x => x.est_chef).name, 'Tom Tom');
  assert.equal(vuParArnie.moi.groupe_libelle, 'Groupe Tom Tom');
  // Adhésion et départ signalent la salle (mise à jour en direct).
  const v1 = (await un(db, "SELECT version FROM salles_signaux WHERE salle = 'soviet|ville_b|rue|krasnov-place-ours'")).version;
  await db.exec("INSERT INTO groupes_pj_adhesions (membre, chef) VALUES ('Vlad', 'Tom Tom')");
  await db.exec("DELETE FROM groupes_pj_adhesions WHERE membre = 'Vlad'");
  const v2 = (await un(db, "SELECT version FROM salles_signaux WHERE salle = 'soviet|ville_b|rue|krasnov-place-ours'")).version;
  assert.ok(v2 >= v1 + 2, v1 + ' -> ' + v2);
});

test('cachette collective : un jet du chef, malus 5 par membre, tout le groupe ou personne ; sortie du chef = groupe visible', async () => {
  const db = await base();
  await db.exec("UPDATE personnages_donnees SET current_building = 'bar', current_room = 'salle', current_street = NULL WHERE name IN ('Tom Tom','Arnie','Vlad','Olga')");
  await db.exec("INSERT INTO groupes_pj_adhesions (membre, chef) VALUES ('Arnie', 'Tom Tom'), ('Vlad', 'Tom Tom')");
  const ch = await comme(db, U.tom, 'SELECT public.se_cacher_chances() r');
  assert.equal(ch.base, 80); assert.equal(ch.membres, 2); assert.equal(ch.taux, 70); assert.equal(ch.malus_par_membre, 5);
  // Jet 75 : réussirait seul (80), échoue en groupe (70) : personne n'est caché.
  await db.exec("SELECT set_config('test.jet', '75', false)");
  let r = await comme(db, U.tom, 'SELECT public.se_cacher() r');
  assert.equal(r.taux, 70); assert.equal(r.cache, false);
  assert.equal((await un(db, 'SELECT count(*)::int c FROM caches_pj')).c, 0);
  await db.exec("SELECT set_config('test.jet', '10', false)");
  r = await comme(db, U.tom, 'SELECT public.se_cacher() r');
  assert.equal(r.cache, true);
  assert.equal((await un(db, 'SELECT string_agg(personnage, \',\' ORDER BY personnage) s FROM caches_pj')).s, 'Arnie,Tom Tom,Vlad');
  // Olga ne voit plus personne ; Arnie voit son groupe caché.
  assert.equal((await presents(db, U.olga)).presents.length, 0);
  assert.deepEqual((await presents(db, U.arnie)).presents.map(x => x.name).sort(), ['Olga', 'Tom Tom', 'Vlad']);
  // Olga rejoint le groupe caché : cachée sans jet.
  await db.exec("INSERT INTO groupes_pj_adhesions (membre, chef) VALUES ('Olga', 'Tom Tom')");
  assert.equal((await un(db, "SELECT count(*)::int c FROM caches_pj WHERE personnage = 'Olga'")).c, 1);
  // Le chef est découvert : tout le groupe redevient visible.
  await db.exec("SELECT public.crim_debusquer_interne('Tom Tom')");
  assert.equal((await un(db, 'SELECT count(*)::int c FROM caches_pj')).c, 0);
});

test('seul : taux inchangé, plafond 98 et ninja comme aujourd’hui ; migration rejouable', async () => {
  const db = await base();
  await db.exec("UPDATE personnages_donnees SET current_building = 'bar', current_room = 'salle', dis = 100, ninja = true WHERE name = 'Vlad'");
  const ch = await comme(db, U.vlad, 'SELECT public.se_cacher_chances() r');
  assert.equal(ch.taux, 98); assert.equal(ch.chef, false); assert.equal(ch.membres, 0);
  await db.exec(lire(MIGRATION));
  const def = (await un(db, "SELECT pg_get_functiondef('public.se_cacher()'::regprocedure) d")).d;
  assert.equal(def.split('groupe_cachette_v1').length - 1, 1);
});
