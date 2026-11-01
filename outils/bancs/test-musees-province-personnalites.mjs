// Musées de province (décision de Fred, 01/11/2026) : chaque salle qui propose « Consulter les
// personnalités » a ses propres figures, et le musée national garde les siennes même quand une
// salle de province porte le même identifiant (salle_organisations).
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const lire = (f) => readFileSync(new URL('../../' + f, import.meta.url), 'utf8');
const c = { state: {} };
vm.createContext(c);
vm.runInContext(lire('data.js').replace(/^const /gm, 'var '), c);
vm.runInContext(lire('plateau-musee-personnalites.js').replace(/^const /gm, 'var '), c);

test('ordre présent exactement dans les salles de province pourvues de figures', () => {
  for (const b of ['musee-port-sainte-marie', 'musee-histoire-montrouge']) {
    for (const [id, r] of Object.entries(c.BUILDINGS[b].rooms)) {
      const ordre = (r.orders || []).some(o => o.fn === 'consulter_personnalites_musee');
      const n = (c.MUSEE_PROVINCE_PERSONNALITES[b][id] || []).length;
      assert.equal(ordre, n > 0, b + ' / ' + id);
    }
  }
});

test('même identifiant de salle : chaque musée lit ses propres figures', () => {
  c.state.currentRoom = 'salle_organisations';
  c.state.currentBuilding = 'musee-port-sainte-marie';
  const psm = c.personnalitesMuseeCourantes();
  c.state.currentBuilding = 'musee-national';
  const national = c.personnalitesMuseeCourantes();
  assert.ok(psm.length > 0 && national.length > 0);
  assert.notEqual(psm[0].nom, national[0].nom);
  assert.equal(national, c.MUSEE_NATIONAL_PERSONNALITES.salle_organisations);
});
