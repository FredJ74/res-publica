import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {test} from 'node:test';
const data=fs.readFileSync('data.js','utf8');
const css=fs.readFileSync('style.css','utf8');
const nav=fs.readFileSync('plateau-navigation.js','utf8');
const html=fs.readFileSync('plateau.html','utf8');
const ctx=vm.createContext({});
vm.runInContext(data,ctx);
const krasnov=vm.runInContext("WORLD.soviet.ville_b.buildingContext['centre-affaires']",ctx);
const hall=krasnov.roomOverrides.hall;
test('cadrage exclusivement pour l’accueil de Krasnov',()=>{
 assert.equal(hall.cadrageIntegral,true);
 assert.equal(hall.imageUrl,'images/Sovarka/Krasnov/Krasnov_centre_affaires_accueil.webp');
 assert.ok(!krasnov.roomsExtra.bureau_1.cadrageIntegral);
 assert.ok(!krasnov.roomsExtra.bureau_3.cadrageIntegral);
 assert.ok(!vm.runInContext("WORLD.republic.capitale.buildingContext['centre-affaires']?.roomOverrides?.hall?.cadrageIntegral",ctx));
 assert.equal((data.match(/cadrageIntegral:\s*true/g)||[]).length,1);
});
test('rendu integral sans rognage, et reinitialisation entre pieces',()=>{
 assert.match(nav,/pieceImg\.toggleAttribute\('data-cadrage-integral',\s*!!\(imgUrl && roomOverride\?\.cadrageIntegral\)\)/);
 const rule=css.match(/\.piece-image\[data-cadrage-integral\]\s*\{([^}]+)\}/);
 assert.ok(rule);
 assert.match(rule[1],/background-size:\s*100% 100%,\s*contain\s*!important/);
 assert.match(rule[1],/aspect-ratio:\s*10\s*\/\s*3/);
 assert.match(rule[1],/background-position:\s*center center\s*!important/);
 assert.match(rule[1],/background-repeat:\s*no-repeat\s*!important/);
 assert.match(rule[1],/background-color:[^;]+!important/);
});
test('cache des trois ressources mis à jour',()=>{
 for(const file of ['data.js','style.css','plateau-navigation.js'])
   assert.match(html,new RegExp(file.replace('.','\\.')+'\\?v=[^"]*krasnov-accueil-cadrage-20261115'));
});
