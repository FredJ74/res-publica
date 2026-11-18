'use strict';
// Maladies — lot 2c : plats cuisinés avec un ingrédient avarié (20 %), furet renifleur (Chasse et Pêche).
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '../..');
const lire = f => fs.readFileSync(path.join(root, f), 'utf8');

test('migration : contamination à la production, tirage à la consommation, furet', () => {
  const sql = lire('migrations/20261118072000_aliments_plats_furet.sql');
  assert.match(sql, /CREATE TRIGGER aliments_contamination_production BEFORE UPDATE OF data ON public\.entreprises/);
  for (const f of ['commerce_vendre_produit_interne', 'acheter_produit_commerce_interne', 'consommer_sur_place_commerce', 'inventaire_consommer'])
    assert.ok(sql.includes("'public." + f + '('), f);
  assert.match(sql, /'plat_avarie'/);
  assert.match(sql, /\('chasse-peche-psm', 'republic', 'ville_a', 'chasse-peche-psm', 'boutique'\)/);
  assert.match(sql, /\('chasse-peche-starovka', 'soviet', 'ville_a', 'armurerie', 'magasin'\)/);
  assert.match(sql, /payer_ordre\(a, 'furet_renifler', 1, 0\)/);
  assert.match(sql, /'furet_vies', 10/);
  assert.ok(!/goulag_/i.test(sql));
});

test('écran : ordre chez Chasse et Pêche seulement, bouton Renifler, neuf langues', () => {
  const data = lire('data.js');
  assert.equal((data.match(/\{fn:'acheter_furet'/g) || []).length, 2);
  assert.match(data, /chasse\.roomOverrides\.magasin\.orders = \(chasse\.roomOverrides\.magasin\.orders \|\| \[\]\)\.concat/);
  assert.match(lire('plateau-router.js'), /fn === 'acheter_furet'.*ouvrirFuret\(\)/);
  assert.match(lire('plateau-personnage.js'), /boutonRenifler\(item, idx, 'flex:1/);
  const ctx = { console, setTimeout: () => 0, setInterval: () => 0, Date, Math, JSON, Set, Map, Number, String, Object, Array,
    showToast: () => {}, RPPlateauI18n: { language: () => 'de' }, document: undefined };
  ctx.window = ctx; ctx.globalThis = ctx;
  vm.createContext(ctx);
  vm.runInContext(lire('plateau-maladies.js') + '\n;globalThis.__state = s => { state = s; };\nvar state;', ctx);
  for (const l of Object.keys(ctx.RPMaladies.T)) for (const k of ['ferret', 'sniff', 'sneeze', 'purr', 'ferretDead'])
    assert.ok(ctx.RPMaladies.T[l][k], l + ' ' + k);
  assert.equal(ctx.nomObjetMaladie({ type: 'furet' }), 'Schnüffelfrettchen');
  assert.match(lire('i18n/orders-resources.js'), /"acheter_furet": "Ein Schnüffelfrettchen kaufen"/);
});
