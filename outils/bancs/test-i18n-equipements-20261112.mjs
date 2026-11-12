// Matériels, trading, serrures, téléphone, escort : neuf langues, français au point d'appel inchangé (12/11/2026).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
const lire = f => readFileSync(new URL('../../' + f, import.meta.url), 'utf8');
const FICHIERS = ['plateau-equipements.js', 'plateau-surveillance.js', 'plateau-informatique.js', 'plateau-multijoueur.js', 'plateau-pnj.js'];
function charger(langue) {
  const ctx = { RP_I18N_GAME_ENABLED: true, RPPlateauI18n: { language: () => langue } };
  ctx.window = ctx; vm.createContext(ctx);
  vm.runInContext(lire('i18n/equipements-resources.js'), ctx);
  return ctx;
}
const src = lire('i18n/equipements-resources.js');
const T = Object.fromEntries([...src.matchAll(/^\s+("[^"]+"):(\[.+\]),?$/gm)].map(m => [JSON.parse(m[1]), JSON.parse(m[2])]));
const ph = s => [...s.matchAll(/\{(\w+)\}/g)].map(m => m[1]).sort().join(',');
const appels = () => FICHIERS.flatMap(f => [...lire(f).matchAll(/texteEquip\('([^']+)', '((?:[^'\\]|\\.)*)'/g)].map(m => [f, m[1], m[2].replace(/\\'/g, "'")]));
function cles(f, debut) {
  const t = lire(f); const out = [];
  let i = t.indexOf(debut);
  while (i >= 0) { const fin = t.indexOf('}', i); for (const m of t.slice(i, fin).matchAll(/(?:^\s+|[{,]\s*)'?([a-z0-9_\-]+)'?: '((?:[^'\\]|\\.)*)'/gm)) out.push([m[1], m[2].replace(/\\'/g, "'")]); i = t.indexOf(debut, fin); }
  return out;
}
test('chaque clé a huit traductions non vides', () => {
  assert.ok(Object.keys(T).length >= 380);
  for (const [k, v] of Object.entries(T)) { assert.equal(v.length, 8, k); for (const s of v) assert.ok(s.trim(), k); }
});
test('chaque appel a sa clé, et les variables sont les mêmes dans les neuf langues', () => {
  const a = appels(); assert.ok(a.length >= 300);
  for (const [f, k, fr] of a) { assert.ok(T[k], f + ' : clé absente ' + k); for (const s of T[k]) assert.equal(ph(s), ph(fr), k + ' → ' + s); }
});
test('refus, libellés et messages radio dynamiques : tous au catalogue, mêmes variables', () => {
  const groupes = [['sv.', 'plateau-surveillance.js', 'const SURVEILLANCE_REFUS = {'], ['in.', 'plateau-informatique.js', 'INFORMATIQUE_REFUS'],
    ['eq.', 'plateau-equipements.js', 'EQUIPEMENTS_REFUS'], ['lib.', 'plateau-equipements.js', 'const EQUIPEMENTS_LIBELLES = {'], ['radio.', 'plateau-multijoueur.js', 'const messages = { radio_hors_ville']];
  for (const [pre, f, debut] of groupes) {
    const c = cles(f, debut); assert.ok(c.length >= 7, pre);
    for (const [k, fr] of c) { assert.ok(T[pre + k], pre + k); for (const s of T[pre + k]) assert.equal(ph(s), ph(fr), pre + k); }
  }
});
test('français inchangé, traduction et variables interpolées', () => {
  assert.equal(charger('fr').texteEquip('cameraN', 'Caméra n° {n}', { n: 2 }), 'Caméra n° 2');
  assert.equal(charger('en').texteEquip('cameraN', 'Caméra n° {n}', { n: 2 }), 'Camera No. 2');
  assert.equal(charger('de').texteEquip('cle_inconnue', 'Texte', {}), 'Texte');
  assert.equal(charger('ko').texteEquip('eq.quantite_invalide', 'Quantité invalide.'), '잘못된 수량입니다.');
});
test('catalogue chargé dans la page et déclaré à l’audit éditorial', () => {
  assert.ok(lire('plateau.html').includes('i18n/equipements-resources.js'));
  assert.ok(lire('outils/audits/audit-i18n-editorial.cjs').includes("'equipements-resources.js'"));
});
