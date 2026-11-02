'use strict';
/* Audit de couverture des ressources réellement utilisées par l'accueil et la création.
   Commande : node --test outils/bancs/banc-i18n-couverture.cjs
   Ce banc signale une couverture partielle sans prétendre que le plateau est traduit. */
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '../..');
const context = { window: {} };
vm.createContext(context);
vm.runInContext(fs.readFileSync(path.join(root, 'i18n/resources.js'), 'utf8'), context);
const data = context.window.RP_I18N_RESOURCES;
const langs = context.window.RP_I18N_LANGUAGES;
function flatten(obj, prefix = '', out = {}) {
  for (const [key, val] of Object.entries(obj || {})) {
    const p = prefix ? prefix + '.' + key : key;
    if (typeof val === 'string') out[p] = val;
    else if (Array.isArray(val)) val.forEach((v, i) => { if (typeof v === 'string') out[p + '.' + i] = v; });
    else if (val && typeof val === 'object') flatten(val, p, out);
  }
  return out;
}
const canonical = flatten(data.fr.translation);
const keys = Object.keys(canonical);
const vars = s => [...String(s).matchAll(/\{\{\s*([a-zA-Z0-9_]+)\s*\}\}/g)].map(x => x[1]).sort().join(',');
test('neuf langues visibles, ressources françaises et clés stables', () => {
  assert.deepEqual(Object.keys(langs), ['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de']);
  assert.ok(keys.length > 100, 'inventaire français anormalement petit');
});
test('aucune interpolation ne diverge du français', () => {
  for (const lang of Object.keys(langs)) {
    const translations = flatten(data[lang].translation);
    for (const [key, value] of Object.entries(translations)) {
      const source = canonical[key] !== undefined ? canonical[key] :
        /_(few|many|zero)$/.test(key) ? canonical[key.replace(/_(few|many|zero)$/, '_other')] : undefined;
      assert.ok(source !== undefined, lang + ': clé non canonique ' + key);
      assert.equal(vars(value), vars(source), lang + ': interpolation ' + key);
    }
  }
});
test('l état réel de couverture est calculable, sans confondre fallback et traduction', () => {
  const report = Object.fromEntries(Object.keys(langs).map(lang => {
    const translated = flatten(data[lang].translation);
    return [lang, { translated: Object.keys(translated).length, reference: keys.length,
      percent: Number((100 * Object.keys(translated).length / keys.length).toFixed(1)) }];
  }));
  console.log('COUVERTURE I18N ACCUEIL/CREATION (hors plateau): ' + JSON.stringify(report));
  assert.equal(report.fr.percent, 100);
  for (const lang of Object.keys(langs)) {
    assert.ok(report[lang].percent <= 100);
    assert.ok(report[lang].translated > 0);
  }
});
