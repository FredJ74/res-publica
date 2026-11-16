// Banc non mutant — UI des interieurs et acces aux fonctions existantes.
'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'../..');
const read=name=>fs.readFileSync(path.join(root,name),'utf8');
const html=read('plateau.html'),css=read('plateau-interieurs-mobile.css'),js=read('plateau-interieurs-mobile.js');
let passed=0;function check(name,fn){fn();passed++;console.log('OK '+name);}
check('fichiers raccordes une fois et dans le bon ordre',()=>{
 for(const name of ['plateau-interieurs-mobile.css','plateau-interieurs-mobile.js'])
   assert.equal(html.split(name).length-1,1);
 assert.ok(html.indexOf('plateau-interieurs-mobile.css')>html.indexOf('plateau-exploration-mobile.css'));
 assert.ok(html.indexOf('plateau-interieurs-mobile.js')>html.indexOf('plateau-exploration-mobile.js'));
});
check('structure du plateau conservee',()=>{
 for(const id of ['vue-batiment','piece-image','pieces-tabs','actionbar-batiment','actions-row-bat','piece-nom','piece-desc'])
   assert.ok(html.includes('id="'+id+'"'),id);
});
check('module sans requete ni commande metier',()=>{
 assert.doesNotMatch(js,/\bsbRpc\s*\(|\bfetch\s*\(|\benterRoom\s*\(|\benterBuilding\s*\(|\bexecuteOrder\s*\(/);
 assert.doesNotMatch(js,/localStorage|sessionStorage|Math\.random|Date\.now/);
});
check('boutons tactiles et etats des ordres preserves',()=>{
 assert.match(css,/min-height:48px/);
 assert.match(css,/\.action-btn\.legal/);
 assert.match(css,/\.action-btn\.illegal/);
 assert.match(css,/\.action-btn\.blocked/);
 assert.doesNotMatch(css,/\.piece-tab\s*\{[^}]*pointer-events\s*:\s*none/);
});
check('le module ne recadre pas les images',()=>{
 assert.doesNotMatch(css,/#piece-image[^{}]*\{[^}]*background-size\s*:/);
 assert.match(css,/\[data-hg-split="1"\]/);
 assert.match(css,/\[data-musee="1"\]/);
});
check('langues et informations DOM reelles',()=>{
 for(const locale of ['fr','en','es','ru','ko','ar','pt','de','zh-TW'])assert.ok(js.includes(locale+':')||js.includes("'"+locale+"':"),locale);
 assert.match(js,/getElementById\('piece-nom'\)/);
 assert.match(js,/getElementById\('piece-desc'\)/);
 assert.match(js,/aria-pressed/);
});
console.log(passed+' controles interieurs reussis');
