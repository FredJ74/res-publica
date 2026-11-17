'use strict';
// Restaurant « Entre terre et mer » de Starovka (prix validés par Fred, 18/11/2026) :
// dîner d'affaires à 40 PSK (écran ET serveur), menus à 15 PSK (dotation ET commerce existant).
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const R = path.resolve(__dirname, '../..');
const ctx = vm.createContext({ console });
vm.runInContext(fs.readFileSync(path.join(R, 'data.js'), 'utf8'), ctx);
const diner = (pays, ville) => vm.runInContext(`ordresDeclaresDeLaPiece(BUILDINGS['capitaine-sauvage'].rooms.salle_principale,
  WORLD[${JSON.stringify(pays)}][${JSON.stringify(ville)}].buildingContext['capitaine-sauvage'], 'salle_principale')
  .filter(o => o.fn === 'diner_affaires').map(o => ({ pa: o.pa, cost: o.cost, desc: o.desc }))`, ctx);
const migration = fs.readFileSync(path.join(R, 'migrations/20261118010000_starovka_restaurant_prix.sql'), 'utf8');

test('écran : un seul dîner d\'affaires à Starovka, à 40 PSK et 2 PA ; Port-Sainte-Marie inchangé à 150', () => {
  const s = JSON.parse(JSON.stringify(diner('soviet', 'ville_a')));
  assert.equal(s.length, 1); assert.equal(s[0].cost, 40); assert.equal(s[0].pa, 2); assert.match(s[0].desc, /1 biere du restaurant/);
  assert.deepEqual(JSON.parse(JSON.stringify(diner('republic', 'ville_a'))).map(o => o.cost), [150]);
});

test('description du dîner traduite dans les neuf langues', () => {
  const i18n = fs.readFileSync(path.join(R, 'i18n/sovarka-infobulles-resources.js'), 'utf8');
  const ligne = i18n.split('\n').find(l => l.includes('1 biere du restaurant'));
  assert.ok(ligne); assert.equal(JSON.parse(ligne.trim().replace(/,$/, '')).length, 9);
  assert.ok(ligne.includes(JSON.stringify(JSON.parse(JSON.stringify(diner('soviet', 'ville_a')))[0].desc).slice(1, -1)));
});

test('serveur : même lieu tarifé à 40, tarif déclaré, menus à 15 dans la dotation et le commerce', () => {
  assert.match(migration, /\(''soviet'',''ville_a'',''capitaine-sauvage'',''salle_principale''\)/);
  assert.match(migration, /"prix":40,"pa":2/);
  assert.match(migration, /"boisson":"biere_pression"/);
  assert.match(migration, /cle = 'capitaine-sauvage\|salle_principale@soviet\.ville_a'/);
  assert.match(migration, /e\.id = 'brasserie-soviet-ville_a-capitaine-sauvage-salle_principale'/);
  for (const m of ['starovka_menu_pecheur', 'starovka_menu_eleveur', 'starovka_menu_terre_mer']) assert.match(migration, new RegExp('"' + m + '":15'));
  const seed = fs.readFileSync(path.join(R, 'baseline/seeds/95_a-regenerer/ordres_couts.sql'), 'utf8');
  assert.match(seed, /\('diner_affaires',2,40\)/);
});
