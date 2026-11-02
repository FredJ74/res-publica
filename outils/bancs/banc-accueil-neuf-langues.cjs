'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '../..');
function load() {
  const sandbox = { window: {} };
  vm.createContext(sandbox);
  vm.runInContext(fs.readFileSync(path.join(root, 'i18n/resources.js'), 'utf8'), sandbox);
  return sandbox.window;
}
test('six langues historiques et trois autres presentes a l accueil', () => {
  const w = load();
  assert.deepEqual(Array.from(Object.keys(w.RP_I18N_LANGUAGES)), ['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de']);
  for (const lang of Object.keys(w.RP_I18N_LANGUAGES)) {
    assert.ok(w.RP_I18N_LANGUAGES[lang].nativeName);
    assert.ok(w.RP_I18N_RESOURCES[lang]?.translation?.home?.createCharacter, lang);
  }
});
test('nouvelles langues : accueil traduit, suite du parcours avec repli FR', () => {
  const w = load();
  for (const lang of ['ar','pt-BR','de']) {
    const t = w.RP_I18N_RESOURCES[lang].translation;
    assert.ok(t.home.descriptor);
    assert.ok(t.home.signature);
    assert.ok(t.home.findCharacter);
    assert.equal(t.creation, undefined, 'La suite ne doit pas etre annoncee comme integralement traduite');
  }
  assert.ok(w.RP_I18N_RESOURCES.fr.translation.creation.steps.country.title);
});
test('index et script i18n conservent la generation dynamique du selecteur', () => {
  const index = fs.readFileSync(path.join(root, 'index.html'),'utf8');
  const init = fs.readFileSync(path.join(root, 'i18n/i18n-init.js'),'utf8');
  assert.match(index, /id="lang-switcher"/);
  assert.match(index, /i18n\/resources\.js\?v=3/);
  assert.match(init, /Object\.keys\(window\.RP_I18N_LANGUAGES/);
  assert.match(init, /genererSelecteurLangueRP\(\)/);
});
