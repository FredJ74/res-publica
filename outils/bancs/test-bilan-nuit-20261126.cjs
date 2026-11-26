'use strict';
// Bilan de la nuit (Fred, 26/11/2026) : l'ordre Dormir annonce au journal tous les gains et pertes (PA, Santé, Moral, argent).
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const src = fs.readFileSync(path.join(__dirname, '../../plateau-personnage.js'), 'utf8');
const c = vm.createContext({});
vm.runInContext(src.slice(src.indexOf('function bilanNuitTexte'), src.indexOf('function ajouterBilanNuit')), c);

test('gains : PA, Santé, Moral et liquide, avec les nouvelles valeurs', () => {
  assert.equal(c.bilanNuitTexte({ pa: 4, hp: 70, moral: 60, liquide: 100, arg: 100 }, { pa: 16, hp: 80, moral: 61, liquide: 250, arg: 250 }, 'FR'),
    'Bilan de la nuit : +12 PA (PA 16) · +10 Santé (Santé 80) · +1 Moral (Moral 61) · +150 FR en liquide.');
});
test('pertes annoncées aussi (poison), rien d’inventé sans changement', () => {
  assert.equal(c.bilanNuitTexte({ pa: 4, hp: 70, moral: 60, liquide: 0, arg: 0 }, { pa: 4, hp: 35, moral: 60, liquide: 0, arg: 0 }, 'PSK'),
    'Bilan de la nuit : -35 Santé (Santé 35).');
  assert.equal(c.bilanNuitTexte({ pa: 1, hp: 1, moral: 1, liquide: 1, arg: 1 }, { pa: 1, hp: 1, moral: 1, liquide: 1, arg: 1 }, 'FR'),
    'Bilan de la nuit : aucun changement.');
});
test('doDormir relève l’état avant le sommeil et écrit le bilan après tous les effets', () => {
  const d = src.slice(src.indexOf('async function doDormir()'));
  assert.match(d, /const avantNuit = \{ pa: Number\(state\.pa\)/);
  assert.ok(d.indexOf('ajouterBilanNuit(avantNuit);') > d.indexOf('payerLocations();'), 'bilan après les suites du réveil');
});
