import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import { test } from 'node:test';

const source = fs.readFileSync('plateau-organisations-quetes.js', 'utf8');
const start = source.indexOf('function doSeRenseigner() {');
const end = source.indexOf('\n// Statut effectif', start);
assert.ok(start >= 0 && end > start);
const handler = source.slice(start, end);
const buildings = {
  'centre-commercial': {
    rooms: {
      boutique_milieu: { isLocationRoom: true, name: 'Box commercial 2' },
      hall: { isLocationRoom: false, name: 'Accueil' }
    }
  }
};

function render(country, leases) {
  const nodes = {
    'postes-modal-title': { textContent: '' },
    'postes-body': { innerHTML: '' },
    'modal-postes': { classList: { add() {} } }
  };
  const context = {
    BUILDINGS: buildings,
    state: {
      country,
      currentCity: 'ville_b',
      currentBuilding: 'centre-commercial',
      locationsActives: leases,
      organisations: []
    },
    document: { getElementById: id => nodes[id] }
  };
  vm.runInNewContext(handler + '\ndoSeRenseigner();', context);
  return nodes['postes-body'].innerHTML;
}

test('Sovarka ne confond pas un bail de Républia avec un bail sovarkien', () => {
  const leases = [
    { country: 'republic', city: 'ville_b', buildingId: 'centre-commercial', roomId: 'boutique_milieu', locataire: 'Locataire de Républia' },
    { country: 'soviet', city: 'ville_b', buildingId: 'centre-commercial', roomId: 'boutique_milieu', locataire: 'Locataire de Sovarka' }
  ];
  const sovarka = render('soviet', leases);
  assert.match(sovarka, /Locataire de Sovarka/);
  assert.doesNotMatch(sovarka, /Locataire de Républia/);
  const republia = render('republic', leases);
  assert.match(republia, /Locataire de Républia/);
  assert.doesNotMatch(republia, /Locataire de Sovarka/);
});

test('un bail historique sans country reste attribué à Républia et non à Sovarka', () => {
  const lease = [{ city: 'ville_b', buildingId: 'centre-commercial', roomId: 'boutique_milieu', locataire: 'Ancien bail' }];
  assert.match(render('republic', lease), /Ancien bail/);
  assert.match(render('soviet', lease), /Libre/);
  assert.doesNotMatch(render('soviet', lease), /Ancien bail/);
});

test('aucune autre ville ni autre bâtiment ne s’affiche', () => {
  const leases = [
    { country: 'soviet', city: 'capitale', buildingId: 'centre-commercial', roomId: 'boutique_milieu', locataire: 'Novomirsk' },
    { country: 'soviet', city: 'ville_b', buildingId: 'centre-affaires', roomId: 'boutique_milieu', locataire: 'Bureau' }
  ];
  const out = render('soviet', leases);
  assert.match(out, /Libre/);
  assert.doesNotMatch(out, /Novomirsk|Bureau/);
});
