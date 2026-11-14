// Logements de Krasnov : entrée, 2 types de logement, images et baux sociaux.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const path=new URL('../../',import.meta.url);
const read=p=>fs.readFileSync(new URL(p,path),'utf8');
const ctx=vm.createContext({});
vm.runInContext(read('data.js'),ctx);
const city=vm.runInContext("WORLD.soviet.ville_b",ctx);
assert.ok(city.buildings.includes('logements-novomirsk'));
const rooms=city.buildingContext['logements-novomirsk'].roomOverrides;
assert.equal(Object.keys(rooms).length,9);
assert.equal(rooms.salle.imageUrl,'images/Sovarka/Krasnov/Krasnov_immeuble_commercial_hall.webp');
for(let i=1;i<=4;i++){
 assert.equal(rooms['petit_appartement_'+i].imageUrl,'images/Sovarka/Krasnov/Krasnov_immeuble_commercial_appartement_1_chambre.webp');
 assert.equal(rooms['grand_appartement_'+i].imageUrl,'images/Sovarka/Krasnov/Krasnov_immeuble_commercial_appartement_2_chambres.webp');
}
for(const p of new Set(Object.values(rooms).map(r=>r.imageUrl))){
 const b=fs.readFileSync(new URL(p,path));
 assert.equal(b.toString('ascii',0,4),'RIFF',p);
 assert.equal(b.toString('ascii',8,12),'WEBP',p);
}
const shared=vm.runInContext("BUILDINGS['logements-novomirsk']",ctx);
assert.ok(shared.rooms.petit_appartement_1.locationData.logementSocial);
assert.ok(shared.rooms.grand_appartement_1.locationData.logementSocial);
assert.equal(shared.rooms.petit_appartement_1.locationData.prix,10);
assert.equal(shared.rooms.grand_appartement_1.locationData.prix,20);
const rue=read('plateau-rue-centrale.js');
assert.match(rue,/nom: 'Immeuble collectif de Krasnov', type: 'batiment', buildingId: 'logements-novomirsk'/);
const sql=read('migrations/20261114183000_krasnov_immeuble_commercial.sql');
assert.match(sql,/country='soviet' AND city='ville_b'/);
assert.match(sql,/INSERT INTO public.logements_sociaux_historiques/);
assert.match(sql,/INSERT INTO public.rue_sorties_batiments/);
assert.ok(!city.buildingContext['logements-novomirsk'].roomsExtra);
console.log('Krasnov immeuble : trois visuels, accès et huit baux sociaux : OK');
