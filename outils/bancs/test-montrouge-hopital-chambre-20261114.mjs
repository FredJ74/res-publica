// Banc ciblé chambre Montrouge : décor, isolation, 3 ordres et arrivée serveur.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const lire = p => fs.readFileSync(new URL('../../'+p, import.meta.url),'utf8');
const ctx=vm.createContext({});
vm.runInContext(lire('data.js'),ctx);
const ch=vm.runInContext("WORLD.republic.ville_b.buildingContext['dispensaire-public-v'].roomsExtra.chambre",ctx);
assert.equal(ch.name,"Chambre d'hôpital");
assert.equal(ch.imageUrl,'images/montrouge/montrouge-hopital-chambre.webp');
assert.ok(fs.existsSync(new URL('../../'+ch.imageUrl,import.meta.url)),'WebP de la chambre');
assert.deepEqual(Array.from(ch.orders,o=>o.fn),['dormir','repas_hopital','transfert_clinique_privee']);
assert.deepEqual(Array.from(ch.orders,o=>[o.pa,o.cost]),[[0,0],[1,0],[0,1000]]);
for(const pays of ['soviet','narco','khalija']) {
  const nom=vm.runInContext(`WORLD.${pays}.ville_b.buildingContext?.['dispensaire-public-v']?.roomsExtra?.chambre?.imageUrl`,ctx);
  assert.notEqual(nom,ch.imageUrl,pays+' non modifié');
}
// Depuis le 14/11 (uniformisation), PSM et Luthécia ont la même chambre : voir test-hopitaux-chambre-partout-20261114.mjs.
const sql=lire('migrations/20261114090000_montrouge_hopital_chambre.sql');
assert.match(sql,/pays = 'republic'/);
assert.match(sql,/ville = 'ville_b'/);
assert.match(sql,/batiment = 'dispensaire-public-v'/);
assert.match(sql,/pieces \? 'chambre'/);
const transfert=lire('plateau-router.js');
assert.match(transfert,/fn === 'transfert_clinique_privee'/);
assert.match(transfert,/fn === 'repas_hopital'/);
console.log('Montrouge chambre : contrôles ciblés OK');
