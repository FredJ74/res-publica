'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const {extract}=require('../audits/libelles-ordres-source.cjs');
const root=path.resolve(__dirname,'../..');

test('les apostrophes échappées dans les deux ordres de champs ne tronquent pas les labels',()=>{
 const sample=String.raw`[{fn:'diner_affaires',label:'Diner d\'affaires'},
 {label:"Entrée d'un bâtiment",fn:'entree'},
 {fn:"essai",label:"Consulter l\"archive"}]`;
 const all=extract(sample);
 const byFn=Object.fromEntries(all.map(x=>[x.fn,x.label]));
 assert.equal(byFn.diner_affaires,"Diner d'affaires");
 assert.equal(byFn.entree,"Entrée d'un bâtiment");
 assert.equal(byFn.essai,'Consulter l"archive');
});
test('les séquences unicode littérales sont décodées sans évaluer la source',()=>{
 const found=extract(String.raw`{fn:'essai',label:'Produire les mati\u00e8res'}`);
 assert.deepEqual(found,[{fn:'essai',label:'Produire les matières'}]);
});
test('les sources réelles gardent les ordres à apostrophes et ne créent aucun ordre',()=>{
 const data=fs.readFileSync(path.join(root,'data.js'),'utf8');
 const rows=extract(data);
 assert.ok(rows.length>1000);
 const find=id=>rows.filter(x=>x.fn===id).map(x=>x.label);
 assert.ok(find('diner_affaires').includes("Diner d'affaires"));
 assert.ok(find('mobiliser_police').includes("Faire intervenir les forces de l'ordre"));
 assert.ok(find('s_engager_armee').includes("S'engager dans l'armée"));
 assert.ok(!find('diner_affaires').some(x=>x.endsWith('\\')));
});
