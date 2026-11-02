'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');

const root = path.resolve(__dirname, '..', '..');
const localeFiles = ['fr', 'en', 'es', 'de', 'pt-BR', 'pt-PT', 'ar'];
const keyPattern = /\{([a-z][a-z0-9_]*)\}/g;
function boot() {
  const sandbox = { Intl };
  sandbox.globalThis = sandbox;
  vm.createContext(sandbox);
  for (const name of ['core', ...localeFiles]) {
    vm.runInContext(fs.readFileSync(path.join(root, 'i18n', name + '.js'), 'utf8'), sandbox, { filename: name + '.js' });
  }
  return sandbox.HGI18n;
}
test('les sept catalogues sont chargés sans activation', () => {
  const i = boot();
  assert.equal(i.getLocale(), 'fr');
  assert.deepEqual(Array.from(i.supported()).sort(), [...localeFiles].sort());
  assert.equal(i.t('common.confirm'), 'Confirmer');
});
test('parité des clés et paramètres avec le français', () => {
  const i = boot();
  const text = fs.readFileSync(path.join(root, 'i18n', 'fr.js'), 'utf8');
  const keys = [...text.matchAll(/^\s*'([^']+)':/gm)].map(m => m[1]);
  assert.equal(keys.length, 15);
  for (const lang of localeFiles) {
    assert.equal(i.setLocale(lang), true);
    const catalogText = fs.readFileSync(path.join(root, 'i18n', lang + '.js'), 'utf8');
    const catalogKeys = [...catalogText.matchAll(/^\s*'([^']+)':/gm)].map(m => m[1]);
    assert.deepEqual(catalogKeys.sort(), [...keys].sort(), lang);
    for (const key of keys) {
      const value = i.t(key);
      assert.ok(value && value !== key, lang + ':' + key);
      const fr = boot().t(key);
      const placeholders = v => Array.from(v.matchAll(keyPattern), m => m[1]).sort();
      assert.deepEqual(placeholders(value), placeholders(fr), lang + ':' + key);
    }
  }
});
test('les traductions sont du texte brut, jamais exécuté', () => {
  const i = boot();
  for (const lang of localeFiles) {
    i.setLocale(lang);
    assert.match(i.t('action.cost', { amount: '<script>alert(1)</script>' }), /<script>alert\(1\)<\/script>/);
  }
});
test('repli français quand une clé manque ; langue inconnue refusée', () => {
  const i = boot();
  i.setLocale('es');
  i.register('es', { 'common.confirm': 'Confirmar' });
  assert.equal(i.t('common.cancel'), 'Annuler');
  assert.equal(i.setLocale('zz'), false);
  assert.equal(i.getLocale(), 'es');
});
