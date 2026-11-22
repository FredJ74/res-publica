'use strict';
// Forêt de Krasnov (Fred, 22/11/2026, nuit, point 4), migration 20261122110000, dans un vrai PostgreSQL local (PGlite) :
// égarement 50 % ; 15 % de rencontre en arrivant dans une vue profonde, même sans couper ; mêmes créatures ;
// le groupe du chef est concerné ; « se laisser faire » vise la vue de la rencontre.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : banc exécuté par son workflow dédié (PGLITE_DIR)', { skip: true }, () => {}); return; }
const UID = { 'Tom Tom': '00000000-0000-0000-0000-000000000001', Arnie: '00000000-0000-0000-0000-000000000002' };

async function base({ groupe = false, pct = null } = {}) {
  const db = new PGlite();
  await db.exec(lire('outils/bancs/fixtures/foret-pglite-socle.sql.txt'));
  await db.exec(lire('outils/bancs/fixtures/foret-rencontre-arrivee-socle.sql.txt'));
  await db.exec(lire('migrations/20261121150000_foret_krasnov_clairiere_retour.sql'));
  await db.exec(lire('migrations/20261122110000_foret_egarement_rencontre_arrivee.sql'));
  for (const [n, u] of Object.entries(UID)) {
    await db.query('INSERT INTO personnages VALUES ($1, $2)', [n, u]);
    await db.query("INSERT INTO personnages_donnees VALUES ($1, 'soviet', 'ville_b', 'zone-production', 'zone_recolte', 10)", [n]);
  }
  if (groupe) await db.query("INSERT INTO groupes_pj_adhesions VALUES ('Arnie', 'Tom Tom')");
  if (pct !== null) await db.query("UPDATE aliments_parametres SET valeur = $1 WHERE cle = 'foret_rencontre_arrivee_pct'", [pct]);
  return db;
}
async function appel(db, qui, sql, args) {
  await db.query("SELECT set_config('test.uid', $1, false)", [UID[qui]]);
  return (await db.query(sql, args)).rows[0].r;
}
const aller = (db, qui, sens) => appel(db, qui, 'SELECT sovarka_foret_aller(gen_random_uuid(), $1) r', [sens]);
const param = async (db, cle) => Number((await db.query('SELECT valeur FROM aliments_parametres WHERE cle = $1', [cle])).rows[0].valeur);

test('réglages : égarement 50 %, rencontre à l’arrivée 15 % ; migration rejouable', async () => {
  const db = await base();
  assert.equal(await param(db, 'foret_egarement_pct'), 50);
  assert.equal(await param(db, 'foret_rencontre_arrivee_pct'), 15);
  await db.exec(lire('migrations/20261122110000_foret_egarement_rencontre_arrivee.sql'));
  const d = (await db.query("SELECT pg_get_functiondef('sovarka_foret_aller(uuid,text)'::regprocedure) d")).rows[0].d;
  assert.equal(d.split('foret_rencontre_arrivee_v1').length, 2, 'un seul raccord');
});

test('arrivée dans une vue profonde : la bête surgit dans cette vue, sans couper ; la clairière et le campement en sont exempts', async () => {
  const db = await base({ pct: 100 });
  const c = await aller(db, 'Tom Tom', 'clairiere');
  assert.equal(c.rencontre, undefined, 'clairière : jamais');
  const r = await aller(db, 'Tom Tom', 'enfoncer');
  assert.match(r.room, /^foret_vue_[1-4]$/);
  assert.equal(r.rencontre, 'attaque'); assert.equal(r.a_l_arrivee, true);
  assert.ok(['loup', 'meute', 'ours'].includes(r.creature));
  const p = (await db.query('SELECT room_id, proprietaire_institution FROM pnj_membres WHERE id = $1', [r.pnj])).rows[0];
  assert.deepEqual(p, { room_id: r.room, proprietaire_institution: 'faune' });
  assert.equal((await aller(db, 'Tom Tom', 'enfoncer')).raison, 'rencontre_en_cours', 'il faut d’abord régler la rencontre');
});

test('sans tirage favorable, aucune rencontre ; environ 15 % sur de nombreuses arrivées', async () => {
  const db0 = await base({ pct: 0 });
  await aller(db0, 'Tom Tom', 'clairiere');
  for (let i = 0; i < 20; i++) assert.equal((await aller(db0, 'Tom Tom', 'enfoncer')).rencontre, undefined);
  const db = await base();
  await aller(db, 'Tom Tom', 'clairiere');
  let n = 0, total = 400;
  for (let i = 0; i < total; i++) {
    const r = await aller(db, 'Tom Tom', 'enfoncer');
    if (r.rencontre) { n++; await db.query("UPDATE sovarka_foret_rencontres SET statut = 'fuite'"); }
  }
  assert.ok(n > total * 0.07 && n < total * 0.25, `rencontres ${n} / ${total}`);
});

test('groupe : le groupe arrive avec le chef ; se laisser faire frappe tout le groupe dans la vue de la rencontre', async () => {
  const db = await base({ groupe: true, pct: 100 });
  await aller(db, 'Tom Tom', 'clairiere');
  const r = await aller(db, 'Tom Tom', 'enfoncer');
  assert.equal(r.rencontre, 'attaque');
  const s = await appel(db, 'Tom Tom', "SELECT sovarka_foret_rencontre(gen_random_uuid(), 'subir') r", []);
  assert.deepEqual(s.victimes, ['Arnie', 'Tom Tom'], 'vue ' + r.vue + ' : tout le groupe');
});
