'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const script=fs.readFileSync(path.join(__dirname,'../../i18n/ordres.js'),'utf8');
const win={};vm.runInNewContext(script,{window:win,Set,Object});
const {label,ambiguous}=win.RPOrderI18n;
const translator={t(key,{lng,defaultValue}){return key==='orders.voter_election'?(lng==='fr'?'Voter':'Vote'):key==='orders.local.suite'?'Rent suite':defaultValue}};
test('ordre simple : seul le libellé change, pas le prix, les PA ou la fonction',()=>{
 const order=Object.freeze({fn:'voter_election',label:'Voter',pa:1,cost:200,requiresPost:'citoyen'});
 assert.equal(label(order,translator,'en'),'Vote');
 assert.equal(order.label,'Voter');assert.equal(order.pa,1);assert.equal(order.cost,200);
});
test('un ordre à étiquettes multiples ne reçoit jamais une traduction hors contexte',()=>{
 const order={fn:'louer_local',label:'Louer ce local (800 FR/jour)',pa:1,cost:800};
 assert.equal(ambiguous(order.fn),true);
 assert.equal(label(order,translator,'en'),order.label);
 assert.equal(label({...order,i18nKey:'local.suite'},translator,'en'),'Rent suite');
});
test('aucun moteur ni entrée non conforme ne change le libellé',()=>{
 assert.equal(label({fn:'x',label:'Bonjour'},null,'ar'),'Bonjour');
 assert.equal(label({fn:'x',label:'Bonjour'},translator,'ar'),'Bonjour');
 assert.equal(label({fn:'../',label:'Bonjour'},translator,'ar'),'Bonjour');
});

test('une variante contextuelle du même fn conserve son prix et son libellé',()=>{
 assert.equal(label({fn:'voter_election',label:'Voter pour le maire',cost:0},translator,'en'),'Voter pour le maire');
 assert.equal(label({fn:'voter_election',label:'Voter',cost:0},translator,'en'),'Vote');
});
