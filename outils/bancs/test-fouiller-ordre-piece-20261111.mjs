// « Fouiller les lieux » devient un ordre de piece, en vert, tout en bas (decision de Fred, 11/11/2026).
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const racine = new URL('../../', import.meta.url);
const lire = f => fs.readFileSync(new URL(f, racine), 'utf8');

function charger() {
  const ctx = { window: {}, state: {}, console };
  vm.createContext(ctx);
  vm.runInContext(lire('plateau-surveillance.js'), ctx);
  return ctx;
}

test('ordre de piece vert, place en bas, enregistre dans le registre', () => {
  const ctx = charger();
  assert.ok(ctx.window.RP_ORDRES_DYNAMIQUES.includes(ctx.ordresFouillerLieux));
  const [o] = ctx.ordresFouillerLieux('bureaux', 'bureau_1');
  assert.equal(o.fn, 'fouiller_lieux');
  assert.equal(o.type, 'legal');
  assert.equal(o.pa, 2);
  assert.equal(o.basDeListe, true);
  assert.equal(ctx.ordresFouillerLieux(null, null).length, 0);
});

test('la liste des ordres met les ordres basDeListe a la fin', () => {
  const src = lire('plateau-politique.js');
  assert.match(src, /\.concat\(dynOrders\.filter\(d => !d\.basDeListe\)\)\s*\n[^\n]*\n\s*\.concat\(dynOrders\.filter\(d => d\.basDeListe\)\)/);
});

test('le routeur sort avant tout debit generique et la colonne ne double pas le bouton en piece', () => {
  const routeur = lire('plateau-router.js');
  const iFouiller = routeur.indexOf("fn === 'fouiller_lieux'");
  assert.ok(iFouiller > 0 && iFouiller < routeur.indexOf("fn === 'camion_militaire'"));
  assert.match(lire('plateau-surveillance.js'), /if \(!state\.currentBuilding\) \{\s*\n\s*h \+= '<button type="button" onclick="surveillanceFouiller\(\)"/);
});
