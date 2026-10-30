'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');
function boot() {
  const sandbox = { Intl };
  sandbox.globalThis = sandbox;
  vm.createContext(sandbox);
  for (const f of ['core.js', 'fr.js', 'en.js']) {
    vm.runInContext(fs.readFileSync(path.join(__dirname, '..', '..', 'i18n', f), 'utf8'), sandbox, { filename: f });
  }
  return sandbox.HGI18n;
}
test('la langue initiale est toujours le français', () => {
  const i = boot();
  assert.equal(i.getLocale(), 'fr');
  assert.equal(i.t('common.confirm'), 'Confirmer');
});
test('changement de langue strictement opt-in', () => {
  const i = boot();
  assert.equal(i.setLocale('en'), true);
  assert.equal(i.t('common.confirm'), 'Confirm');
  assert.equal(i.setLocale('zz'), false);
  assert.equal(i.getLocale(), 'en');
});
test('interpolation sans évaluation de HTML ni d expressions', () => {
  const i = boot();
  assert.equal(i.t('finance.balance', { amount: '<script>' }), 'Caisse : <script> FR');
  assert.equal(i.t('finance.balance'), 'Caisse : {amount} FR');
});
test('repli français en cas de traduction manquante', () => {
  const i = boot();
  i.register('en', { 'common.confirm': 'Confirm' });
  i.setLocale('en');
  assert.equal(i.t('common.cancel'), 'Annuler');
  assert.equal(i.t('unknown.key'), 'unknown.key');
});
test('catalogues valides et non mutables de l extérieur', () => {
  const i = boot();
  assert.throws(() => i.register('fr', { bad: 5 }), /Catalogue|Entrée/);
  assert.throws(() => i.register('bad_TAG', {}), /Catalogue invalide/);
  const languages = i.supported();
  assert.deepEqual(Array.from(languages), ['fr', 'en']);
});
test('formatage de nombre selon locale sans modifier la valeur', () => {
  const i = boot();
  assert.equal(Number(i.number(1234.5).replace(/[^\d.,]/g, '').replace(',', '.')), 1234.5);
  assert.equal(i.setLocale('en'), true);
  assert.equal(i.number(1234.5), '1,234.5');
});
