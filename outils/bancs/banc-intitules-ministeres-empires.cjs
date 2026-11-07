// Vérifie que le pays d'un poste ne suit pas les voyages du personnage.
// node --test outils/bancs/banc-intitules-ministeres-empires.cjs
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const core = fs.readFileSync(path.join(root, 'plateau-core.js'), 'utf8');
const start = core.indexOf('function applyCharToState(char) {');
const end = core.indexOf('function construireMapComptesBancaires', start);
assert.ok(start >= 0 && end > start);
const offices = {
  min_int: ["Ministre de l'Interieur", 'Ministre de la Sécurité du Peuple'],
  min_fin: ['Ministre des Finances', "Ministre de l'Économie collective"],
  min_just: ['Ministre de la Justice', 'Ministre de la Justice prolétarienne'],
  min_def: ['Ministre de la Defense', 'Ministre de la Défense de la Patrie'],
  min_info: ["Ministre de l'Information", 'Ministre de la Vérité officielle'],
  min_ae: ['Ministre des Affaires Etrangeres', "Ministre de l'Amitié entre les Peuples"]
};
function jeu() {
  const nodes = new Map();
  const context = vm.createContext({
    console,
    state: {},
    document: {getElementById(id) {if (!nodes.has(id)) nodes.set(id, {});return nodes.get(id);}},
    localStorage: {getItem() {return null;}},
    migrerCareerId() {},
    ARCHETYPES: [], CAREERS: [], STAT_DEFS: []
  });
  vm.runInContext(fs.readFileSync(path.join(root, 'data.js'), 'utf8'), context);
  vm.runInContext(core.slice(start, end), context);
  return context;
}
for (const [id, [base, soviet]] of Object.entries(offices)) {
  test(id + ': voyage en Sovarka ne change pas le mandat républien', () => {
    const j = jeu();
    j.state.domicile = {country:'republic',city:'capitale'};
    j.applyCharToState({name:'PJ',country:'soviet',
      poste:{id,name:soviet},resources:{inf:10,pop:10,dis:10}});
    assert.equal(j.state.poste.name,base);
    assert.equal(j.state.country,'soviet');
    assert.equal(vm.runInContext(`intitulePoste('${id}', 'republic')`,j),base);
    assert.equal(vm.runInContext(`intitulePoste('${id}', 'soviet')`,j),soviet);
  });
  test(id + ': ministre sovarkien conserve son titre', () => {
    const j = jeu();
    j.state.domicile = {country:'soviet',city:'capitale'};
    j.applyCharToState({name:'PJ',country:'soviet',poste:{id,name:base}});
    assert.equal(j.state.poste.name,soviet);
  });
  test(id + ': autre empire n'hérite pas du titre sovarkien', () => {
    const j = jeu();
    j.state.domicile = {country:'khalija',city:'capitale'};
    j.applyCharToState({name:'PJ',country:'soviet',poste:{id,name:soviet}});
    assert.equal(j.state.poste.name,base);
  });
}
test('le pays explicitement associé au mandat prévaut sur la domiciliation',()=>{
  const j=jeu();
  j.state.domicile={country:'soviet'};
  j.applyCharToState({name:'PJ',country:'soviet',
    poste:{id:'min_def',country:'republic',name:'Ministre de la Défense de la Patrie'}});
  assert.equal(j.state.poste.name,'Ministre de la Defense');
});
