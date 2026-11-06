import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {fileURLToPath} from 'node:url';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const ctx=vm.createContext({console});
vm.runInContext(fs.readFileSync(path.join(root,'data.js'),'utf8')+';this.world=WORLD;this.buildings=BUILDINGS;',ctx);
const sov=ctx.world.soviet.capitale.buildingContext['centre-affaires'];
const base=ctx.buildings['centre-affaires'];
const dir='images/Sovarka/Novomirsk/';
const expected={
  hall:'Novomirsk_centre_affaires_hall.webp',
  bureau_prestige:'Novomirsk_centre_affaires_bureau_prestige.webp',
  bureau_prestige_b:'Novomirsk_centre_affaires_bureau_prestige_2.webp',
  reunion_grande_a:'Novomirsk_centre_affaires_grande_reunion.webp',
  reunion_grande_b:'Novomirsk_centre_affaires_grande_reunion.webp',
  reunion_moyenne_a:'Novomirsk_centre_affaires_moyenne_reunion.webp',
  reunion_moyenne_b:'Novomirsk_centre_affaires_moyenne_reunion.webp'
};
test('un hall et six pièces du centre de Novomirsk, sans open space',()=>{
 assert.equal(Object.keys(expected).length,7);
 assert.equal(sov.name,"Centre d'affaires de Novomirsk");
 assert.deepEqual(Array.from(sov.roomsExclues).sort(),['bureau_standard','open_space','tribune_republia'].sort());
 const listed=Object.keys({...base.rooms,...sov.roomsExtra}).filter(k=>!sov.roomsExclues.includes(k));
 assert.deepEqual(listed.sort(),Object.keys(expected).sort());
 assert.equal(sov.roomOverrides.hall.persons.length,2);
});
test('cinq WebP distincts, fichiers PNG supprimés',()=>{
 assert.equal(new Set(Object.values(expected)).size,5);
 for(const [id,file] of Object.entries(expected)){
  const room=sov.roomOverrides[id] || sov.roomsExtra[id];
  assert.equal(room.imageUrl,dir+file,id);
  const bytes=fs.readFileSync(path.join(root,room.imageUrl));
  assert.ok(bytes.length>100000,file);
  assert.equal(bytes.toString('ascii',0,4),'RIFF',file);
  assert.equal(bytes.toString('ascii',8,12),'WEBP',file);
 }
 const originals=[
  'Novomirsk_centre affaires_bureau prestige 2.png','Novomirsk_centre affaires_bureau prestige.png',
  'Novomirsk_centre affaires_grand bureau.png','Novomirsk_centre affaires_hall.png',
  'Novomirsk_centre affaires_moyen bureau.png'
 ];
 for(const f of originals)assert.equal(fs.existsSync(path.join(root,dir,f)),false,f);
});
test('deux bureaux attribués par la mairie (Fred, 07/11) : demande de location, 150 PSK, sans guichet',()=>{
 const a=sov.roomOverrides.bureau_prestige,b=sov.roomsExtra.bureau_prestige_b;
 for(const r of [a,b]){
  const fns=Array.from(r.orders.map(o=>o.fn));
  assert.equal(fns[0],'sovarka_demande_location');
  assert.equal(fns.includes('louer_local'),false);
  assert.equal(fns.includes('gerer_local'),true);
  assert.equal(r.locationData.prix,150);
 }
 assert.equal(b.isLocationRoom,true);
 assert.equal(a.name.includes('prestige'),true);
 assert.equal(base.rooms.bureau_prestige.locationData.prix,1000); // socle de Républia intact
});
test('les salles à la journée ne débitent jamais le client hors de la transaction serveur',()=>{
 for(const id of ['reunion_grande_a','reunion_grande_b','reunion_moyenne_a','reunion_moyenne_b']){
  const room=sov.roomsExtra[id];
  assert.ok(room && !room.isLocationRoom);
  assert.equal(room.orders.length,1);
  assert.equal(room.orders[0].fn,'sovarka_reunion_reserver');
  assert.equal(room.orders[0].cost,0);
  assert.equal(room.orders[0].pa,0);
  assert.match(room.desc,/(100|150) PSK\/jour/);
 }
 assert.equal(ctx.world.republic.capitale.buildingContext['centre-affaires'].roomsExclues?.includes('open_space')||false,false);
});
