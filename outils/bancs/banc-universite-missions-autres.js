// Banc indépendant du catalogue des trois parcours non médicaux.
const assert=require('node:assert/strict');
const {parcours,missionPourSemaine,objectifAtteint}=require('../../universite-missions-autres.js');
assert.deepEqual(parcours.map(p=>p.carriere),['business','magistrat','officer']);
for(const p of parcours){
 assert.equal(p.missions.length,7);
 assert.deepEqual(p.missions.map(m=>m.semaine),[2,3,4,5,6,7,8]);
 assert.equal(new Set(p.missions.map(m=>m.id)).size,7);
 assert.equal(new Set(p.missions.map(m=>m.ville)).size,2);
 assert(p.missions.slice(0,3).every(m=>m.ville==='luthecia'));
 assert(p.missions.slice(3).every(m=>m.ville==='port-sainte-marie'));
 for(const m of p.missions){
  assert.deepEqual(missionPourSemaine(p.carriere,m.semaine),m);
  assert.equal(objectifAtteint(p.carriere,m.id,m.action),true);
  assert.equal(objectifAtteint(p.carriere,m.id,'autre action'),false);
 }
 assert.equal(missionPourSemaine(p.carriere,1),null);
 assert.equal(missionPourSemaine(p.carriere,9),null);
}
console.log('Catalogue universitaire: trois parcours, 21 missions cohérentes.');
