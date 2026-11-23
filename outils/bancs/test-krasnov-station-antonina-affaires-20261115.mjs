import assert from 'node:assert/strict';
import {test} from 'node:test';
import fs from 'node:fs';
import vm from 'node:vm';
const root=new URL('../../',import.meta.url);
const read=p=>fs.readFileSync(new URL(p,root),'utf8');
const ctx=vm.createContext({});
vm.runInContext(read('data.js'),ctx);
const world=vm.runInContext('WORLD.soviet.ville_b',ctx);
const b=vm.runInContext('BUILDINGS',ctx);
const business=world.buildingContext['centre-affaires'];
const rooms=business.roomsExtra;
const expected=['bureau_1','bureau_2','bureau_3','bureau_4'];
test('quatre bureaux de taille/catégorie et loyer égaux, vues alternées',()=>{
 assert.deepEqual(Object.keys(rooms),expected);
 assert.equal(business.roomsExclues.length,4);
 assert.equal(business.roomOverrides.hall.persons.length,1);
 for(let i=1;i<=4;i++){
   const r=rooms['bureau_'+i];
   assert.equal(r.isLocationRoom,true);
   assert.equal(r.locationData.prix,40); // plafond de loyer (Fred, 23/11/2026, point 32)
   assert.equal(r.orders.some(o=>o.fn==='louer_local'),false);
   assert.equal(r.orders.some(o=>o.fn==='sovarka_demande_location'),true);
   assert.equal(r.orders.some(o=>o.fn==='gerer_local'),true);
   assert.equal(r.orders.some(o=>o.fn==='installer_equipements'),true);
   assert.match(r.imageUrl,i<=2?/bureau_maison_bleue/:/bureau_hopital/);
 }
});
test('station, maison, images et portraits WebP',()=>{
 const paths=[
  world.buildingContext['station-service-krasnov'].roomOverrides.boutique_station.imageUrl,
  world.buildingContext['maison-krasnov-bureaux'].roomOverrides.piece_maison.imageUrl,
  business.roomOverrides.hall.imageUrl,
  business.roomOverrides.hall.persons[0].photoUrl,
  rooms.bureau_1.imageUrl, rooms.bureau_3.imageUrl
 ];
 assert.equal(new Set(paths).size,6);
 for(const p of paths){
  const bytes=fs.readFileSync(new URL(p,root));
  assert.equal(bytes.toString('ascii',0,4),'RIFF',p);
  assert.equal(bytes.toString('ascii',8,12),'WEBP',p);
 }
 assert.equal(b['station-service-krasnov'].rooms.boutique_station.orders.length,3); // + boutique climat (23/11, point 34)
 assert.equal(b['maison-krasnov-bureaux'].rooms.piece_maison.orders.length,3);
});
test('migration portée sur la seule ville de Krasnov, et originaux supprimés',()=>{
 const sql=read('migrations/20261115004000_krasnov_centre_affaires_quatre_bureaux.sql');
 assert.match(sql,/ville='ville_b'/);
 assert.match(sql,/INSERT INTO public.locaux_loyers_referentiel/);
 assert.match(sql,/locations_archives/);
 assert.doesNotMatch(sql,/DELETE FROM|TRUNCATE TABLE|DROP TABLE/i);
 const list=fs.readdirSync(new URL('images/Sovarka/Krasnov/',root)).join('\n').normalize('NFC');
 for(const name of ['Épicerie soviétique au crépuscule.png','Cuisine russe rétro aux couleurs chaleureuses.png','Centre d’affaires au coucher du soleil.png']) assert.equal(list.includes(name),false,name);
});
