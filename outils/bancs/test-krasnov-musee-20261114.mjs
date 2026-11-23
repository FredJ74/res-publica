import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const root=new URL('../../',import.meta.url);
const read=p=>fs.readFileSync(new URL(p,root),'utf8');
const ctx=vm.createContext({});vm.runInContext(read('data.js'),ctx);
const city=vm.runInContext("WORLD.soviet.ville_b",ctx);
const source=vm.runInContext("BUILDINGS['musee-novomirsk']",ctx);
const c=city.buildingContext['musee-novomirsk'];
const expected=['hall','faune_sauvage','flore_sauvage','exploitation_bois','kolkhozes','ecoute_spatiale'];
assert.deepEqual(Array.from(Object.keys(c.roomsExtra)),expected.slice(1));
assert.equal(c.roomsExclues.length,13);
assert.ok(!c.roomsExclues.includes('hall'));
assert.equal(c.roomOverrides.hall.name,'Accueil du musée de Krasnov');
assert.equal(c.roomOverrides.hall.persons.length,2); // hôtesse et guide (directeur du musée supprimé : Fred, 23/11/2026, point 29)
assert.deepEqual(Array.from(c.roomOverrides.hall.excludeOrders),['ilia_ecouter_guide']);
assert.equal(c.roomOverrides.hall.orders.length,2); // « Écouter le guide » (Arkadi) et guide des baies (23/11 : plus d'ordre de réponse au directeur)
assert.ok(!c.roomOverrides.hall.persons.some(p=>/directeur/i.test(p.name+' '+(p.profilId||''))),'directeur du musée supprimé (23/11)');
// Bloc 3 (23/11/2026) : Zoïa Biletova et Arkadi Pamiatnikov reçoivent leurs portraits recadrés.
for(const p of c.roomOverrides.hall.persons)assert.ok(/Krasnov_musee_accueil_|krasnov-(zoia-biletova|arkadi-pamiatnikov)-portrait/.test(p.photoUrl),p.photoUrl);
const paths=[
 c.roomOverrides.hall.imageUrl,...Object.values(c.roomsExtra).map(r=>r.imageUrl),
 ...c.roomOverrides.hall.persons.filter(p=>p.photoUrl).map(p=>p.photoUrl)
];
assert.equal(new Set(paths).size,8);
for(const path of paths){
 const buf=fs.readFileSync(new URL(path,root));
 assert.equal(buf.toString('ascii',0,4),'RIFF',path);
 assert.equal(buf.toString('ascii',8,12),'WEBP',path);
}
for(const r of Object.values(c.roomsExtra)){
 assert.deepEqual(Array.from(r.orders,o=>o.fn),['ilia_ecouter_guide']); // « Écouter le guide » : Arkadi présente la salle (23/11)
 assert.ok(r.desc.length>50);
}
assert.ok(source.rooms.salle_origines);
assert.ok(source.rooms.salle_personnalites_discretes);
assert.ok(!source.rooms.faune_sauvage,'Les salles de Krasnov ne doivent pas contaminer Novomirsk');
const sql=read('migrations/20261114223000_krasnov_musee_salles.sql');
assert.match(sql,/ville='ville_b'/);
assert.match(sql,/faune_sauvage.*flore_sauvage.*exploitation_bois.*kolkhozes.*ecoute_spatiale/);
assert.doesNotMatch(sql,/DROP TABLE|DELETE FROM|TRUNCATE/i);
console.log('Musée Krasnov : 6 salles et 8 WebP, Novomirsk préservé : OK');
