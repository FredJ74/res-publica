'use strict';
// Catalogue d'impression des tracts (11/11/2026) : neuf langues complètes, mêmes variables, français par défaut.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const racine = path.resolve(__dirname, '../..');
const source = fs.readFileSync(path.join(racine, 'i18n/tracts-resources.js'), 'utf8');

function charger(langue, actif = true) {
  const window = { RP_I18N_GAME_ENABLED: actif, RPPlateauI18n: { language: () => langue } };
  const ctx = { window };
  vm.createContext(ctx);
  vm.runInContext(source, ctx);
  return window;
}
const variables = s => [...s.matchAll(/\{(\w+)\}/g)].map(m => m[1]).sort().join(',');
const balises = s => (s.match(/<\/?strong>/g) || []).join('');

test('neuf langues, mêmes clés, mêmes variables et mêmes balises que le français', () => {
  const w = charger('fr');
  const langues = [...w.RPTractsI18n.langues];
  assert.deepEqual(langues, ['fr', 'en', 'es', 'zh-TW', 'ru', 'ko', 'ar', 'pt-BR', 'de']);
  const fr = {};
  for (const m of source.matchAll(/^    "(\w+)": "((?:[^"\\]|\\.)*)",?$/gm)) if (!(m[1] in fr)) fr[m[1]] = m[2];
  const cles = Object.keys(fr);
  assert.ok(cles.length >= 60);
  for (const l of langues) {
    const t = charger(l);
    for (const k of cles) {
      const v = t.texteTract(k);
      assert.ok(v && v.length, l + ' ' + k);
      const ref = charger('fr').texteTract(k);
      assert.equal(variables(v), variables(ref), l + ' ' + k + ' (variables)');
      assert.equal(balises(v), balises(ref), l + ' ' + k + ' (balises)');
    }
  }
});

test('interpolation, repli français hors activation et clé inconnue vide', () => {
  assert.equal(charger('de').texteTract('paNeed', { pa: 2, n: 20 }), 'Für 20 Flugblätter sind 2 AP nötig (1 AP pro 10er-Stapel).');
  assert.equal(charger('de', false).texteTract('titlePrint'), 'Imprimer des tracts');
  assert.equal(charger('en').texteTract('inexistante'), '');
});

test('le module des tracts ne garde plus ces libellés en dur', () => {
  const comm = fs.readFileSync(path.join(racine, 'plateau-communication.js'), 'utf8');
  for (const s of ["'Imprimer des tracts électoraux'", 'STOCKS ET PRODUCTION', "'Tracts imprimés !'", 'Production possible maintenant']) assert.ok(!comm.includes(s), s);
  assert.match(fs.readFileSync(path.join(racine, 'plateau.html'), 'utf8'), /i18n\/tracts-resources\.js/);
});
