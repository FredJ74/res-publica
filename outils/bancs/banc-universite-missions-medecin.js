// Banc du catalogue des missions medicales, sans dependance serveur.
const assert = require('node:assert/strict');
const { missions, missionPourSemaine, objectifAtteint } = require('../../universite-missions-medecin.js');
assert.equal(missions.length, 7);
assert.deepEqual(missions.map(m => m.semaine), [2,3,4,5,6,7,8]);
assert.equal(new Set(missions.map(m => m.id)).size, 7);
assert(missions.slice(0,3).every(m => m.ville === 'luthecia' && m.lieu === 'ehpad'));
assert(missions.slice(3).every(m => m.ville === 'port-sainte-marie' && m.lieu === 'dispensaire'));
assert.equal(missionPourSemaine(1), null);
assert.equal(missionPourSemaine(9), null);
for (const m of missions) {
  assert.equal(missionPourSemaine(m.semaine)?.id, m.id);
  assert(m.consigne && m.objectif && m.reaction && m.action);
  assert.equal(objectifAtteint(m.id, m.action), true);
  assert.equal(objectifAtteint(m.id, 'action_incorrecte'), false);
}
assert.equal(objectifAtteint('mission_inconnue', 'action_incorrecte'), false);
console.log('Catalogue medical : 7 missions coherentes.');
