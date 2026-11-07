'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const ctx=vm.createContext({window:{}});
for(const file of ['resources.js','orders-resources.js','ordres.js'])
 vm.runInContext(fs.readFileSync(path.join(root,'i18n',file),'utf8'),ctx);
const w=ctx.window;
const engine={t(key,{lng,defaultValue}){return key.split('.').reduce((v,k)=>v?.[k],w.RP_I18N_RESOURCES[lng]?.translation)??defaultValue}};

test('un ordre canonique ne traduit que son texte HTML, jamais ses paramètres métier',()=>{
 const order=Object.freeze({fn:'plainte_police',label:'Porter plainte',pa:1,cost:200,requiresPost:'commissaire'});
 assert.equal(w.RPOrderI18n.labelHtml(order,engine,'de'),'Anzeige erstatten');
 assert.equal(w.RPOrderI18n.labelHtml(order,engine,'ar'),'تقديم بلاغ');
 assert.equal(order.fn,'plainte_police');
 assert.equal(order.label,'Porter plainte');
 assert.equal(order.pa,1);assert.equal(order.cost,200);
});

test('les libellés variables et non répertoriés restent exactement originaux',()=>{
 const ordre={fn:'louer_local',label:'Louer la boutique (800 FR/jour)'};
 assert.equal(w.RPOrderI18n.labelHtml(ordre,engine,'en'),ordre.label);
 const inconnu={fn:'nouvel_ordre',label:'Action spéciale'};
 assert.equal(w.RPOrderI18n.labelHtml(inconnu,engine,'ru'),'Action spéciale');
});

test('une traduction HTML dangereuse est échappée, sans modifier la source',()=>{
 const original=Object.freeze({fn:'plainte_police',label:'Porter plainte'});
 const dangerous={t(key,{lng,defaultValue}){return lng==='fr'?'Porter plainte':'<img src=x onerror="evil()" /> & test';}};
 const value=w.RPOrderI18n.labelHtml(original,dangerous,'de');
 assert.equal(value,'&lt;img src=x onerror=&quot;evil()&quot; /&gt; &amp; test');
 assert.equal(original.label,'Porter plainte');
});

test('le renderer ne change que le texte visible : doOrder conserve le libellé original',()=>{
 const source=fs.readFileSync(path.join(root,'plateau-politique.js'),'utf8');
 const from=source.indexOf('function renderRoomActions(room, buildingId, roomId) {');
 assert.ok(from>=0);
 const end=source.indexOf('\nfunction ',from+30);
 assert.ok(end>from);
 const segment=source.slice(from,end);
 assert.match(segment,/const libelleAffiche = \(window\.RPOrderI18n/);
 assert.match(segment,/window\.RPOrderI18n\.labelHtml\(o,window\.i18next,window\.RPPlateauI18n\.language\(\)\)/);
 assert.match(segment,/safeLabel = o\.label\.replace/);
 assert.match(segment,/doOrder\('/);
 assert.equal(segment.split(" + libelleAffiche + ").length-1,2);
 assert.match(segment,/const coutJoint = \[costDisplay, paDisplay\]/);
});
