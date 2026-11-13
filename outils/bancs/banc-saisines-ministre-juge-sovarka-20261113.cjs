'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const src = fs.readFileSync('data.js', 'utf8');
const ctx = vm.createContext({});
vm.runInContext(src, ctx);

function ordresVille(ville) {
  const name = ville === 'capitale' ? 'tribunal' : 'tribunal-local';
  return Array.from(vm.runInContext(`ordresDeclaresDeLaPiece(BUILDINGS[${JSON.stringify(name)}].rooms.bureau_magistrats, WORLD.soviet[${JSON.stringify(ville)}].buildingContext[${JSON.stringify(name)}], 'bureau_magistrats')`, ctx));
}

test('les trois villes de Sovarka réservent et grisent les saisines au juge', () => {
  for (const ville of ['capitale', 'ville_a', 'ville_b']) {
    const ordres = ordresVille(ville);
    const saisine = ordres.find(o => o.fn === 'sovarka_retirer_droit');
    assert.ok(saisine, 'Ordre absent : ' + ville);
    assert.equal(saisine.requiresPost, 'juge', 'Droit de saisine incorrect : ' + ville);
    assert.equal(saisine.pa, 1, 'Coût modifié : ' + ville);
    assert.equal(saisine.cost, 0, 'Prix modifié : ' + ville);
    for (const fn of ['rendre_sentence', 'sovarka_ordres_ministre', 'sovarka_offrir_cafe'])
      assert.equal(ordres.find(o => o.fn === fn)?.requiresPost, 'juge', fn + ' / ' + ville);
  }
});

test('la règle de grisage générique utilise bien requiresPost', () => {
  const politique = fs.readFileSync('plateau-politique.js', 'utf8');
  assert.match(politique, /if \(o\.requiresPost\)/);
  assert.match(politique, /needsPost = posteId !== reqPost/);
  assert.match(politique, /if \(o\.requiresPost && !needsPost && paysMandatPourOrdre\(\) !== state\.country\)/);
});
