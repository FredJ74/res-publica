'use strict';
const assert = require('node:assert/strict');
const M = require('../../monnaie.js');
let n = 0;
function test(nom, fn) { fn(); n++; console.log('OK ' + nom); }
test('francs conserves et centimes exacts', () => {
  assert.equal(M.normaliser('5.50'), '5.50');
  assert.equal(M.additionner('0.10', '0.20'), '0.30');
  assert.equal(M.multiplierEntier('5.50', 3), '16.50');
  assert.equal(M.soustraire('5.50', '5.50'), '0.00');
});
test('aucun arrondi implicite ni nombre binaire sur le transport', () => {
  for (const v of ['5.505', '1e2', 'NaN', 'Infinity', '01', '', ' 5.50', '5,50', null, 5.5, 5]) {
    assert.throws(() => M.normaliser(v));
  }
  assert.equal(M.historique(2000), '2000.00');
  assert.throws(() => M.historique(5.5));
  assert.equal(M.lireSaisie('5,50'), '5.50');
});
test('grands soldes et signes sans perte', () => {
  assert.equal(M.additionner('9007199254740993.01', '0.01'), '9007199254740993.02');
  assert.equal(M.soustraire('0.00', '0.01'), '-0.01');
  assert.equal(M.normaliser('-0.00'), '0.00');
  assert.equal(M.comparer('0.00', '-0.01'), 1);
});
test('conservation transferts, bornes et quantites', () => {
  for (let i = 0; i < 1000; i++) {
    const a = (i / 100).toFixed(2);
    assert.equal(M.additionner(M.soustraire('100.00', a), a), '100.00');
  }
  assert.throws(() => M.multiplierEntier('5.50', 1.1));
  assert.throws(() => M.multiplierEntier('5.50', Number.MAX_SAFE_INTEGER + 1));
});
console.log(n + '/' + n + ' groupes monnaie reussis');
