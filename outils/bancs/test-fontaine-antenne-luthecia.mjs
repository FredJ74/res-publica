import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
const data=readFileSync('data.js','utf8');
const nav=readFileSync('plateau-navigation.js','utf8');
const commerce=readFileSync('plateau-commerce-pj.js','utf8');
test('la suppression d antenne est uniquement dans le contexte de Luthecia',()=>{
 const contexte=vm.createContext({});vm.runInContext(data,contexte);
 const villes=vm.runInContext('WORLD.republic',contexte);
 assert.deepEqual(Array.from(villes.capitale.buildingContext['centre-affaires'].roomsExclues),['tribune_republia']);
 for(const id of ['ville_a','ville_b']) assert.ok(!(villes[id].buildingContext?.['centre-affaires']?.roomsExclues||[]).includes('tribune_republia'),id+' conserve son antenne');
 assert.ok(vm.runInContext("!!BUILDINGS['centre-affaires'].rooms.tribune_republia",contexte),'le gabarit partage conserve antenne');
 assert.match(nav,/ctxForTabs\?\.roomsExclues/);
 assert.match(nav,/ctxEntreePiece\?\.roomsExclues\?\.includes\(roomId\)/);
});
test('la consommation sur place est possible pour les boissons',()=>{
 assert.match(commerce,/\['boisson','encas','encas-a-emporter'/);
 assert.match(commerce,/venteSurPlaceUniquement !== true/);
 assert.match(commerce,/venteSurPlaceUniquement === true/);
});
