'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const ctx=vm.createContext({window:{}});
for(const file of ['resources.js','order-templates-resources.js','ordres.js'])
 vm.runInContext(fs.readFileSync(path.join(root,'i18n',file),'utf8'),ctx);
const w=ctx.window;
const translator={t(key,opts={}){
 const parts=key.split('.');
 const template=parts.reduce((item,part)=>item?.[part],w.RP_I18N_RESOURCES[opts.lng]?.translation);
 if(typeof template!=='string')return opts.defaultValue;
 return template.replace(/\{\{([a-z]+)\}\}/g,(_,name)=>String(opts[name]??'{{'+name+'}}'));
}};
const data=fs.readFileSync(path.join(root,'data.js'),'utf8');
const locales=Object.keys(w.RP_I18N_LANGUAGES);

test('six modèles de loyers et terrains présents pour neuf langues',()=>{
 assert.equal(locales.length,9);
 const ref=Object.keys(w.RP_I18N_RESOURCES.fr.translation.orderTemplates);
 assert.equal(ref.length,6);
 for(const lng of locales){
  const x=w.RP_I18N_RESOURCES[lng].translation.orderTemplates;
  assert.deepEqual(Object.keys(x),ref);
  for(const text of Object.values(x))assert.ok(text.trim());
 }
});
test('chaque loyer du jeu garde exactement son montant, sa monnaie et son ordre',()=>{
 const labels=[...data.matchAll(/fn:'louer_local',\s*label:'((?:\\.|[^'])*)'/g)].map(x=>x[1]);
 assert.ok(labels.length>=12);
 for(const original of labels){
  assert.match(original,/^Louer (ce local|cette suite|ce coffre|cet appartement) \(\d[\d ]* (FR|PSK)\/jour\)$/);
  const price=original.match(/\((\d[\d ]*) (FR|PSK)\/jour\)/);
  const order=Object.freeze({fn:'louer_local',label:original,cost:874,pa:1});
  for(const lng of locales){
   const translated=w.RPOrderI18n.label(order,translator,lng);
   assert.ok(translated.includes(price[1]),lng+': somme absente');
   assert.ok(translated.includes(price[2]),lng+': monnaie absente');
   if(lng!=='fr')assert.notEqual(translated,original,lng+': non traduit');
  }
  assert.equal(order.label,original);assert.equal(order.cost,874);assert.equal(order.pa,1);
 }
});
test('tous les achats de terrains à prix affiché préservent surface et prix',()=>{
 const labels=[...data.matchAll(/fn:'acheter_terrain',\s*label:'((?:\\.|[^'])*)'/g)].map(x=>x[1]);
 assert.ok(labels.length>=12);
 for(const original of labels){
  const order=Object.freeze({fn:'acheter_terrain',label:original,cost:25200,pa:1});
  const variable=original.match(/^Acheter ce terrain \((\d[\d ]*) m² — (\d[\d ]*) FR\)$/);
  assert.ok(variable||original==='Acheter ce terrain',original);
  for(const lng of locales){
   const translated=w.RPOrderI18n.label(order,translator,lng);
   if(variable){
    assert.ok(translated.includes(variable[1]),lng+': surface');
    assert.ok(translated.includes(variable[2]),lng+': prix');
    assert.ok(translated.includes('FR'),lng+': devise');
   }else assert.ok(translated.trim());
  }
  assert.equal(order.label,original);assert.equal(order.cost,25200);assert.equal(order.pa,1);
 }
});
test('pas de traduction pour devises et formes inconnues, jamais de prix interpolé incorrect',()=>{
 for(const order of [
  {fn:'louer_local',label:'Louer ce local (200 EUR/jour)'},
  {fn:'louer_local',label:'Louer ce local (prix variable)'},
  {fn:'acheter_terrain',label:'Acheter ce terrain (2500 m² — prix libre)'},
  {fn:'acheter_terrain',label:'Acheter ce terrain <script>alert(1)</script>'}
 ])assert.equal(w.RPOrderI18n.label(order,translator,'en'),order.label);
 const unavailable={t:()=> 'Rent this local ({{price}} {{currency}}/day)'};
 const priced={fn:'louer_local',label:'Louer ce local (800 FR/jour)'};
 assert.equal(w.RPOrderI18n.label(priced,unavailable,'en'),priced.label);
});
test('les modèles sont chargés après les ressources et avant le résolveur',()=>{
 const html=fs.readFileSync(path.join(root,'plateau.html'),'utf8');
 const a=html.indexOf('i18n/resources.js'),b=html.indexOf('i18n/order-templates-resources.js');
 const c=html.indexOf('i18n/ordres.js');
 assert.ok(a>=0 && a<b && b<c);
});
