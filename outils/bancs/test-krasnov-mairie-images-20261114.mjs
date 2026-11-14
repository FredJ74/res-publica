import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const base=new URL('../../',import.meta.url);
const lire=p=>fs.readFileSync(new URL(p,base),'utf8');
const ctx=vm.createContext({});
vm.runInContext(lire('data.js'),ctx);
const city=vm.runInContext("WORLD.soviet.ville_b",ctx);
const mairie=city.buildingContext.mairie;
const names={
 accueil_mairie:'Krasnov_mairie_accueil.webp',
 bureau_maire_local:'Krasnov_mairie_bureau_maire.webp',
 bureau_maire_adjoint:'Krasnov_mairie_bureau_adjoint.webp',
 salle_partis:'Krasnov_mairie_salle_partis.webp',
 salle_elections:'Krasnov_mairie_salle_elections.webp'
};
for(const [room,name] of Object.entries(names)){
 const obj=mairie.roomOverrides?.[room]||mairie.roomsExtra?.[room];
 assert.ok(obj,'Pièce absente '+room);
 const path='images/Sovarka/Krasnov/'+name;
 assert.equal(obj.imageUrl,path);
 const buffer=fs.readFileSync(new URL(path,base));
 assert.equal(buffer.toString('ascii',0,4),'RIFF',path);
 assert.equal(buffer.toString('ascii',8,12),'WEBP',path);
}
assert.deepEqual(mairie.roomOverrides.accueil_mairie.persons.length,1);
// 14/11/2026 (audit) : mêmes ordres que la salle des élections de Novomirsk.
assert.deepEqual(Array.from(mairie.roomsExtra.salle_elections.orders,o=>o.fn),['consulter_elections','voter_election','contester_resultats','falsifier_listes_electorales','bourrer_urnes','truquer_depouillement']);
assert.ok(mairie.roomsExtra.salle_partis.orders.some(o=>o.fn==='sovarka_parti_fonder'),'partis restent fonctionnels');
assert.ok(vm.runInContext("BUILDINGS.mairie.rooms.bureau_maire_local.orders.some(o=>o.fn==='fixer_impots_locaux')",ctx));
assert.ok(vm.runInContext("BUILDINGS.mairie.rooms.bureau_maire_adjoint.orders.some(o=>o.fn==='traiter_demandes_permis')",ctx));
const sql=lire('migrations/20261114190000_krasnov_mairie_salle_elections.sql');
assert.match(sql,/pays='soviet' AND ville='ville_b' AND batiment='mairie'/);
assert.match(sql,/\["salle_elections"\]/);
assert.equal(fs.readdirSync(new URL('images/Sovarka/Krasnov/',base)).filter(n=>/^Image ChatGPT 14 nov\. 2026, 18_15_.*\.png$|^Bureau de vote.*\.png$/i.test(n)).length,0);
console.log('Krasnov mairie : cinq images, salles, règles existantes et migration : OK');
