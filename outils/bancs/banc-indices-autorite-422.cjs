'use strict';
// Revue de l'évolution #404, préservée par #410 : le client Republia ne doit plus écrire les indices.
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm');
const acorn=require('../e2e/node_modules/acorn');
function extraire(source,nom){const n=acorn.parse(source,{ecmaVersion:'latest'}).body.find(n=>n.type==='FunctionDeclaration'&&n.id.name===nom);assert.ok(n);return source.slice(n.start,n.end);}
function decor(source){let appels=0;const c=vm.createContext({INDICE_VILLE_CLE_LEGACY:{social:'social'},INDICES_NATIONAUX:{narco:{social:50}},INDICES_VILLES_CACHE:{republic_capitale:{social:45}},sbGet:async()=>{appels++;return[{data:{social:45}}]},sbUpdate:async()=>{appels++},sbInsert:async()=>{appels++}});vm.runInContext(extraire(source,'modifierIndiceVille'),c);return{c,appels:()=>appels};}
async function sansEcriture(source){const d=decor(source);for(const delta of [-100,-5,0,5,100])await d.c.modifierIndiceVille('republic','capitale','social',delta);assert.equal(d.appels(),0);assert.equal(d.c.INDICES_VILLES_CACHE.republic_capitale.social,45);}
const courant=fs.readFileSync('plateau-divers.js','utf8');
test('indices Republia : aucun effet local ni écriture depuis le client',()=>sansEcriture(courant));
test('indices legacy : comportement hors Republia préservé et borné',async()=>{const d=decor(courant);await d.c.modifierIndiceVille('narco','capitale','social',100);assert.equal(d.c.INDICES_NATIONAUX.narco.social,100);await d.c.modifierIndiceVille('narco','capitale','social',-200);assert.equal(d.c.INDICES_NATIONAUX.narco.social,0);assert.equal(d.appels(),0);});
test('contre-épreuve : ancien écrivain client effectivement détecté',async()=>{const ancien=fs.readFileSync('outils/bancs/fixtures/indices-client-avant-404.txt','utf8');await assert.rejects(sansEcriture(ancien),assert.AssertionError);});
