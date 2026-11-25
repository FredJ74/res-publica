import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {test} from 'node:test';
const data=fs.readFileSync('data.js','utf8');
const css=fs.readFileSync('style.css','utf8');
const nav=fs.readFileSync('plateau-navigation.js','utf8');
const html=fs.readFileSync('plateau.html','utf8');
const context=vm.createContext({});
vm.runInContext(data,context);
const center=vm.runInContext("WORLD.soviet.ville_b.buildingContext['centre-affaires']",context);
test('Accueil autonome, sans traitement panoramique ni changement des quatre bureaux',()=>{
 assert.equal(center.roomOverrides.hall.imageUrl,'images/Sovarka/Krasnov/Krasnov_centre_affaires_accueil_20261115.webp');
 assert.equal(center.roomOverrides.hall.cadrageIntegral,undefined);
 assert.equal(center.roomOverrides.hall.persons[0].photoUrl,'images/Sovarka/Krasnov/Krasnov_centre_affaires_hotesse_20261115.webp');
 assert.equal(Object.keys(center.roomsExtra).length,4);
 assert.doesNotMatch(css,/data-cadrage-integral/);
 assert.doesNotMatch(nav,/data-cadrage-integral/);
 assert.doesNotMatch(data,/cadrageIntegral:\s*true/);
});
test('Les images sont réellement des WebP et la source PNG a été supprimée',()=>{
 for(const f of ['Krasnov_centre_affaires_accueil_20261115.webp','Krasnov_centre_affaires_hotesse_20261115.webp']){
   const p='images/Sovarka/Krasnov/'+f;
   const bytes=fs.readFileSync(p);
   assert.equal(bytes.toString('ascii',0,4),'RIFF');
   assert.equal(bytes.toString('ascii',8,12),'WEBP');
   assert.ok(bytes.length>10000,f);
 }
 const files=fs.readdirSync('images/Sovarka/Krasnov').map(x=>x.normalize('NFC'));
 assert.equal(files.includes('Réception chaleureuse du centre d’affaires.png'),false);
 assert.equal(files.includes('Hopital_municipal_de_Krasnov_sous_la_neige.png'),true);
});
test('Le navigateur charge la nouvelle version des ressources',()=>{
 for(const n of ['style.css','plateau-navigation.js','data.js'])
   assert.match(html,new RegExp(n.replace('.','\\.')+'\\?v=[^"]*krasnov-accueil-image-unique-20261115'));
});
