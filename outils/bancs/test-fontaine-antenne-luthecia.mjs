import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const data=readFileSync('data.js','utf8');
const nav=readFileSync('plateau-navigation.js','utf8');
const commerce=readFileSync('plateau-commerce-pj.js','utf8');
test('la suppression d antenne est uniquement dans le contexte de Luthecia',()=>{
 const start=data.indexOf("'centre-affaires': {",data.indexOf("ville_a:"));
 const luthecia=data.slice(data.indexOf("'centre-affaires': {"),data.indexOf("    ville_a:"));
 assert.match(luthecia,/roomsExclues: \['tribune_republia'\]/);
 assert.ok(start > data.indexOf("    ville_a:"));
 assert.match(nav,/ctxForTabs\?\.roomsExclues/);
 assert.match(nav,/ctxEntreePiece\?\.roomsExclues\?\.includes\(roomId\)/);
});
test('la consommation sur place est possible pour les boissons',()=>{
 assert.match(commerce,/\['boisson','encas','encas-a-emporter'/);
 assert.match(commerce,/venteSurPlaceUniquement !== true/);
 assert.match(commerce,/venteSurPlaceUniquement === true/);
});
