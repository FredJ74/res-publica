// Point 45 (Fred, 23/11/2026, GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md) : un seul maire à Novomirsk, dans son bureau
// (« Le Maire de Novomirsk (PNJ) ») ; le doublon « Le Maire (PNJ) » hérité du gabarit de Luthécia ne revient pas dans le hall.
// Les autres mairies (Luthécia, Starovka, Krasnov) gardent leur maire.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const R = path.resolve(__dirname, '../..');

test('Novomirsk : le maire est dans son bureau, plus de doublon dans le hall', () => {
  const c = vm.createContext({ console, window: {} });
  vm.runInContext(fs.readFileSync(path.join(R, 'data.js'), 'utf8') + ';globalThis.__W = WORLD; globalThis.__B = BUILDINGS;', c);
  const ro = c.__W.soviet.capitale.buildingContext['mairie-capitale'].roomOverrides;
  const noms = piece => (ro[piece]?.persons || []).map(p => p.name);
  assert.ok(!noms('hall_mairie').some(n => /^Le Maire/.test(n)), 'hall : ' + JSON.stringify(noms('hall_mairie')));
  assert.ok(noms('hall_mairie').includes('Secrétaire municipal Arseni Krylov'), 'le secrétariat reste au hall');
  assert.equal(JSON.stringify(noms('bureau_maire')), JSON.stringify(['Le Maire de Novomirsk (PNJ)']));
  // Gabarit et Républia intacts.
  assert.ok(c.__B['mairie-capitale'].rooms.hall_mairie.persons.some(p => p.name === 'Le Maire (PNJ)'));
  assert.ok(c.__B['mairie-capitale'].rooms.bureau_maire.persons.some(p => p.name === 'Le Maire de Luthecia (PNJ)'));
});
