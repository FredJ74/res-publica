// Ordres propres à Sovarka : neuf langues, français inchangé, variantes branchées (12/11/2026).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
const R = new URL('../../', import.meta.url);
const lire = f => readFileSync(new URL(f, R), 'utf8');
const LANGUES = ['fr', 'en', 'es', 'zh-TW', 'ru', 'ko', 'ar', 'pt-BR', 'de'];
function catalogue() {
  const ctx = { RP_I18N_RESOURCES: Object.fromEntries(LANGUES.map(l => [l, { translation: {} }])) };
  ctx.window = ctx; vm.createContext(ctx);
  vm.runInContext(lire('i18n/sovarka-ordres-resources.js'), ctx);
  return ctx;
}
test('chaque ordre et chaque variante existe dans les neuf langues, non vide', () => {
  const c = catalogue();
  const ordres = c.RPSovarkaOrdresI18n.orders, variantes = c.RPSovarkaOrdresI18n.variantes;
  assert.ok(ordres.length >= 29 && variantes.length === 7);
  for (const l of LANGUES) {
    const t = c.RP_I18N_RESOURCES[l].translation;
    for (const k of ordres) assert.ok(typeof t.orders[k] === 'string' && t.orders[k].trim(), l + ' ' + k);
    for (const k of variantes) assert.ok(typeof t.orderVariants[k] === 'string' && t.orderVariants[k].trim(), l + ' ' + k);
  }
});
test('le français du catalogue est exactement le libellé de data.js', () => {
  const c = catalogue(), data = lire('data.js').replace(/\\'/g, "'"), fr = c.RP_I18N_RESOURCES.fr.translation;
  for (const [fn, label] of Object.entries(fr.orders)) assert.ok(data.includes(label), fn + ' : ' + label);
  for (const [k, label] of Object.entries(fr.orderVariants)) {
    assert.ok(data.includes("'variant." + k + "'"), 'clé posée dans data.js : ' + k);
    assert.ok(data.includes(label), k + ' : ' + label);
  }
});
test('montants et sigles conservés dans toutes les langues', () => {
  const c = catalogue();
  for (const l of LANGUES) {
    const t = c.RP_I18N_RESOURCES[l].translation;
    assert.match(t.orders.pavillon_reception, /1 500 PSK/);
    for (const [k, n] of [['sov_bail_650', '650'], ['sov_bail_800', '800'], ['sov_bail_500', '500']]) assert.match(t.orderVariants[k], new RegExp(n + ' FR'));
    assert.match(t.orders.residence_reserver, /3/);
  }
});
test('le catalogue est chargé avant l’initialisation de la langue', () => {
  const html = lire('plateau.html');
  const a = html.indexOf('i18n/sovarka-ordres-resources.js'), b = html.indexOf('i18n/plateau-init.js');
  assert.ok(a > 0 && b > a);
});
