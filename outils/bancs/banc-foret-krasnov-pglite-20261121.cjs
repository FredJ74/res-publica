'use strict';
// Forêt de Krasnov — portique, clairière, retour au campement, groupe (migration 20261121150000), dans un vrai PostgreSQL
// local (PGlite). Tous les contrôles demandés par Fred (point 5 et complément « exploration en groupe »).
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
const { PGlite } = charger('@electric-sql/pglite');
const UID = { 'Tom Tom': '00000000-0000-0000-0000-000000000001', Arnie: '00000000-0000-0000-0000-000000000002' };

async function base({ groupe = false } = {}) {
  const db = new PGlite();
  await db.exec(lire('outils/bancs/fixtures/foret-pglite-socle.sql.txt'));
  await db.exec(lire('migrations/20261121150000_foret_krasnov_clairiere_retour.sql'));
  for (const [n, u] of Object.entries(UID)) {
    await db.query('INSERT INTO personnages VALUES ($1, $2)', [n, u]);
    await db.query("INSERT INTO personnages_donnees VALUES ($1, 'soviet', 'ville_b', 'zone-production', 'zone_recolte', 10)", [n]);
  }
  if (groupe) await db.query("INSERT INTO groupes_pj_adhesions VALUES ('Arnie', 'Tom Tom')");
  return db;
}
async function aller(db, qui, sens) {
  await db.query("SELECT set_config('test.uid', $1, false)", [UID[qui]]);
  return (await db.query('SELECT sovarka_foret_aller(gen_random_uuid(), $1) r', [sens])).rows[0].r;
}
const piece = async (db, qui) => (await db.query('SELECT current_room FROM personnages_donnees WHERE name = $1', [qui])).rows[0].current_room;
const pa = async (db, qui) => (await db.query('SELECT pa FROM personnages_donnees WHERE name = $1', [qui])).rows[0].pa;

test('portique → clairière, toujours ; sans PA', async () => {
  const db = await base();
  for (let i = 0; i < 5; i++) {
    const r = await aller(db, 'Tom Tom', 'clairiere');
    assert.equal(r.room, 'foret_clairiere');
    await aller(db, 'Tom Tom', 'campement');
  }
  // L'ancien « S'enfoncer » depuis l'entrée mène aussi à la clairière.
  assert.equal((await aller(db, 'Tom Tom', 'enfoncer')).room, 'foret_clairiere');
  assert.equal(await pa(db, 'Tom Tom'), 10, 'aucun PA');
});

test('sentier de la clairière → tirage parmi les vues profondes ; jamais deux images de bois identiques de suite', async () => {
  const db = await base();
  await aller(db, 'Tom Tom', 'clairiere');
  const vues = new Set(); let prec = 5;
  for (let i = 0; i < 80; i++) {
    const r = await aller(db, 'Tom Tom', 'enfoncer');
    assert.match(r.room, /^foret_vue_[1-4]$/);
    assert.notEqual(r.vue, prec, 'une autre vue');
    assert.ok(!([1, 2].includes(prec) && [1, 2].includes(r.vue)), `bois ${prec} puis bois ${r.vue}`);
    vues.add(r.vue); prec = r.vue;
  }
  assert.equal(vues.size, 4, 'bois, loups, ours, Olga : toutes les vues sortent');
  assert.equal(await pa(db, 'Tom Tom'), 10);
});

test('retour depuis le cœur de la forêt : deux clics au plus, « égaré » au premier, clairière garantie au second', async () => {
  let egares = 0, directs = 0;
  for (let i = 0; i < 30; i++) {
    const db = await base();
    await aller(db, 'Tom Tom', 'clairiere'); await aller(db, 'Tom Tom', 'enfoncer');
    const r1 = await aller(db, 'Tom Tom', 'campement');
    if (r1.egare) {
      egares++;
      assert.match(r1.room, /^foret_vue_[1-4]$/, 'égaré : même tirage que l’aller');
      assert.equal(r1.perdu, true);
      const r2 = await aller(db, 'Tom Tom', 'campement');
      assert.equal(r2.room, 'foret_clairiere', 'second clic : toujours la clairière');
      assert.equal(r2.egare, false);
    } else { directs++; assert.equal(r1.room, 'foret_clairiere'); }
    // Depuis la clairière, un clic de plus : le campement, sans tirage.
    assert.equal((await aller(db, 'Tom Tom', 'campement')).room, 'zone_recolte');
    assert.equal(await pa(db, 'Tom Tom'), 10, 'aucun PA, même perdu');
  }
  assert.ok(egares > 0 && directs > 0, `égarés ${egares}, directs ${directs}`);
});

test('probabilité d’égarement en réglage (aliments_parametres.foret_egarement_pct, 80 % comme le code existant)', async () => {
  const db = await base();
  assert.equal(Number((await db.query("SELECT valeur FROM aliments_parametres WHERE cle = 'foret_egarement_pct'")).rows[0].valeur), 80);
  await db.query("UPDATE aliments_parametres SET valeur = 0 WHERE cle = 'foret_egarement_pct'");
  await aller(db, 'Tom Tom', 'clairiere'); await aller(db, 'Tom Tom', 'enfoncer');
  assert.equal((await aller(db, 'Tom Tom', 'campement')).room, 'foret_clairiere');
});

test('groupe : un seul tirage, la même vue pour tous, égarement commun ; seul le chef clique', async () => {
  const db = await base({ groupe: true });
  await aller(db, 'Tom Tom', 'clairiere');
  assert.equal(await piece(db, 'Arnie'), 'foret_clairiere', 'le membre suit');
  for (let i = 0; i < 10; i++) {
    const r = await aller(db, 'Tom Tom', 'enfoncer');
    assert.equal(await piece(db, 'Arnie'), r.room, 'même image pour tous');
  }
  const refus = await aller(db, 'Arnie', 'enfoncer');
  assert.equal(refus.raison, 'chef_de_groupe_requis');
  const r1 = await aller(db, 'Tom Tom', 'campement');
  assert.equal(await piece(db, 'Arnie'), r1.room, 'le groupe s’égare ou arrive ensemble');
});

test('on ne coupe pas dans la clairière ; « Retour au campement » coûte 0 PA', async () => {
  const db = await base();
  await aller(db, 'Tom Tom', 'clairiere');
  assert.equal((await db.query('SELECT sovarka_foret_couper(gen_random_uuid()) r')).rows[0].r.raison, 'pas_en_foret_profonde');
  assert.equal((await db.query("SELECT pa FROM ordres_couts WHERE fn = 'foret_campement'")).rows[0].pa, 0);
});
