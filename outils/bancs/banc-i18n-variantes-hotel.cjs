'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const ctx=vm.createContext({window:{}});
for(const file of ['resources.js','orders-resources.js','order-variants-resources.js','ordres.js'])
 vm.runInContext(fs.readFileSync(path.join(root,'i18n',file),'utf8'),ctx);
const w=ctx.window;
const engine={t(key,{lng,defaultValue}){return key.split('.').reduce((v,k)=>v?.[k],w.RP_I18N_RESOURCES[lng].translation)??defaultValue}};

test('réservation simple et standard : 9 traductions contextuelles, identifiants métiers intacts',()=>{
 const languages=Object.keys(w.RP_I18N_LANGUAGES);
 assert.equal(languages.length,9);
 for(const lng of languages) {
  const vars=w.RP_I18N_RESOURCES[lng].translation.orderVariants;
  assert.equal(Object.keys(vars).length,2);
  for(const value of Object.values(vars))assert.ok(value.trim());
 }
 for(const [key,original,cost] of [
  ['hotel_basic','Reserver une chambre',80],
  ['hotel_standard',"Réserver une chambre d'hôtel",60]
 ]) {
  const order=Object.freeze({fn:'reserver_chambre_hotel',i18nKey:'variant.'+key,label:original,cost,pa:0,requiresPost:null});
  for(const lng of languages) {
   const expected=w.RP_I18N_RESOURCES[lng].translation.orderVariants[key];
   assert.equal(w.RPOrderI18n.label(order,engine,lng),expected,lng+':'+key);
  }
  assert.equal(order.label,original);assert.equal(order.cost,cost);
  assert.equal(order.pa,0);assert.equal(order.fn,'reserver_chambre_hotel');
 }
});

test('trois ordres existants portent leur variante ; aucun nouveau fn ni modification du coût',()=>{
 const data=fs.readFileSync(path.join(root,'data.js'),'utf8');
 const found=[...data.matchAll(/fn:'reserver_chambre_hotel',\s*label:'((?:\\.|[^'])*)',\s*i18nKey:'variant\.(hotel_basic|hotel_standard)',\s*pa:0,\s*cost:(\d+)/g)];
 assert.equal(found.length,3);
 assert.equal(found.filter(x=>x[2]==='hotel_basic'&&x[3]==='80').length,1);
 assert.equal(found.filter(x=>x[2]==='hotel_standard'&&x[3]==='60').length,2);
 const html=fs.readFileSync(path.join(root,'plateau.html'),'utf8');
 assert.ok(html.indexOf('i18n/order-variants-resources.js')>html.indexOf('i18n/orders-resources.js'));
 assert.ok(html.indexOf('i18n/ordres.js')>html.indexOf('i18n/order-variants-resources.js'));
});

test('un ordre ambigu sans i18nKey ne reçoit aucune traduction par défaut',()=>{
 const order={fn:'reserver_chambre_hotel',label:'Réserver une chambre spéciale',pa:0,cost:0};
 assert.equal(w.RPOrderI18n.ambiguous(order.fn),true);
 assert.equal(w.RPOrderI18n.label(order,engine,'en'),order.label);
});
