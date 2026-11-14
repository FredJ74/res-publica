import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const root = new URL('../../', import.meta.url);
const read = p => fs.readFileSync(new URL(p, root), 'utf8');
const c=vm.createContext({});
vm.runInContext(read('data.js'),c);
const b=vm.runInContext("BUILDINGS['logements-krasnov-place-ours']",c);
assert.ok(b);
const keys=Object.keys(b.rooms);
assert.deepEqual(keys,['hall',...Array.from({length:4},(_,i)=>'petit_appartement_'+(i+1)),...Array.from({length:4},(_,i)=>'grand_appartement_'+(i+1))]);
assert.equal(b.rooms.hall.orders.length,0);
for(const [key,room] of Object.entries(b.rooms)){
 assert.ok(room.imageUrl,'Image manquante pour '+key);
 const bytes=fs.readFileSync(new URL(room.imageUrl,root));
 assert.equal(bytes.toString('ascii',0,4),'RIFF',key);
 assert.equal(bytes.toString('ascii',8,12),'WEBP',key);
 if(key==='hall') continue;
 const small=key.startsWith('petit');
 assert.equal(room.locationData.logementSocial,true,key);
 assert.equal(room.locationData.prix,small?10:20,key);
 assert.equal(room.locationData.type,small?'petit':'grand',key);
 assert.equal(room.orders.some(o=>o.fn==='gerer_logement_social'),true,key);
 const n=Number(key.slice(-1)),v=(n-1)%2+1;
 assert.equal(room.imageUrl,`images/Sovarka/Krasnov/Krasnov_immeuble_place_ours_${small?'petit':'grand'}_${v}.webp`,key);
}
const city=vm.runInContext('WORLD.soviet.ville_b',c);
assert.ok(city.buildings.includes('logements-krasnov-place-ours'));
assert.ok(!city.buildingContext?.['logements-krasnov-place-ours']?.roomsExclues);
const sql=read('migrations/20261114203000_krasnov_place_ours_appartements.sql');
assert.match(sql,/INSERT INTO public.logements_sociaux_historiques/);
assert.match(sql,/logements-krasnov-place-ours/);
assert.match(sql,/jsonb_array_length\(pieces\)=9/);
assert.doesNotMatch(sql,/DELETE FROM|TRUNCATE|DROP TABLE/i);
const folder=new URL('images/Sovarka/Krasnov/',root);
for(const p of fs.readdirSync(folder)){
 if(p.startsWith('Image ChatGPT 14 nov. 2026, 19_26_')&&p.endsWith('.png')) throw Error('PNG temporaire conservé : '+p);
}
console.log('Krasnov place de l’Ours : 9 pièces, 5 WebP, 8 baux configurés : OK');
