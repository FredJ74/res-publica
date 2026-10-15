// node --test outils/bancs/banc-hydratation-personnage.cjs
// Fonction reelle du jeu, DOM minimal, aucune connexion ni sauvegarde.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const racine = path.resolve(__dirname, '../..');
const source = fs.readFileSync(path.join(racine, 'plateau-core.js'), 'utf8');
const debut = source.indexOf('function applyCharToState(char) {');
const fin = source.indexOf('function construireMapComptesBancaires', debut);
assert.ok(debut >= 0 && fin > debut);
function plateau() {
  const dom = new Map();
  const ctx = vm.createContext({console, state:{},
    document:{getElementById(id) { if (!dom.has(id)) dom.set(id, {}); return dom.get(id); }},
    localStorage:{getItem(){return null;}}, migrerCareerId(){},
    ARCHETYPES:[], CAREERS:[], STAT_DEFS:[]});
  vm.runInContext(fs.readFileSync(path.join(racine, 'data.js'), 'utf8'), ctx);
  vm.runInContext(source.slice(debut, fin), ctx);
  return {ctx, dom};
}
for (const country of ['republic','soviet','narco','khalija']) {
  test(`${country} : les ressources nulles restent a zero, y compris apres rechargement`, () => {
    for (let reload = 0; reload < 2; reload++) {
      const {ctx, dom} = plateau();
      ctx.applyCharToState({name:'Temoin',country,arg:0,pa:0,resources:{inf:0,pop:0,dis:0}});
      for (const k of ['arg','pa','inf','pop','dis']) assert.equal(ctx.state[k], 0, k);
      assert.match(dom.get('r-arg').textContent, /^0 /);
    }
  });
}
test('les valeurs positives sont conservees sans recalcul', () => {
  const {ctx} = plateau();
  ctx.applyCharToState({country:'republic',arg:123,pa:2,resources:{inf:3,pop:4,dis:5}});
  for (const [k,v] of Object.entries({arg:123,pa:2,inf:3,pop:4,dis:5})) assert.equal(ctx.state[k], v);
});
test('les replis historiques restent limites aux champs absents', () => {
  const {ctx} = plateau();ctx.applyCharToState({country:'republic'});
  for (const [k,v] of Object.entries({arg:4250,pa:10,inf:25,pop:30,dis:85})) assert.equal(ctx.state[k], v);
});
test('un pays inconnu ne devient pas Republia', () => {
  const {ctx} = plateau();ctx.applyCharToState({country:'inconnu',arg:99});
  assert.equal(ctx.state.char, undefined);assert.equal(ctx.state.arg, undefined);
});
