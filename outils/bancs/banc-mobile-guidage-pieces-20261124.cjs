// Vérifie que le guidage de Jérémy révèle une pièce masquée par l'onglet mobile « Pièces ».
// Test isolé du comportement du DOM, sans navigateur connecté ni action métier.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname, '../../plateau-quete-accueil.js'), 'utf8');
const start = source.indexOf('function queteAccueilSurbrillance(');
const end = source.indexOf('\n}\n', start) + 2;
assert.ok(start >= 0 && end > start, 'fonction de guidage présente');

function scenario({mobile,hidden,elementCache}) {
  let ouvertures = 0, styles = 0;
  const panneau = {hidden};
  const elt = {
    matches: selector => selector === '.piece-tab',
    closest: selector => selector === '#hg-room-list' ? panneau : null,
    getClientRects: () => elementCache ? [] : [{}],
    classList: {add: () => styles++, remove: () => {}},
    addEventListener: () => {}, removeEventListener: () => {}
  };
  const acces = {click() { ouvertures++; panneau.hidden = false; }};
  const document = {
    querySelectorAll: () => [elt],
    querySelector: selector => selector === '#hg-room-primary [data-room-tab="0"]' ? acces : null,
    getElementById: id => id === 'hg-room-list' ? panneau : null
  };
  const ctx = {document, window: {matchMedia: () => ({matches: mobile})}, setTimeout: () => {}};
  vm.runInNewContext(source.slice(start, end), ctx);
  ctx.queteAccueilSurbrillance('.piece-tab[onclick*="salle_elections"]', 12000);
  return {ouvertures, styles, hidden: panneau.hidden};
}
test('mobile : la pièce cachée ouvre le panneau avant la surbrillance', () => {
  assert.deepEqual(scenario({mobile:true,hidden:true,elementCache:true}), {ouvertures:1,styles:1,hidden:false});
});
test('bureau : aucune ouverture de panneau', () => {
  assert.deepEqual(scenario({mobile:false,hidden:true,elementCache:true}), {ouvertures:0,styles:1,hidden:true});
});
test('mobile : panneau déjà visible non rouvert', () => {
  assert.deepEqual(scenario({mobile:true,hidden:false,elementCache:false}), {ouvertures:0,styles:1,hidden:false});
});
