'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.join(__dirname,'../..');
const win={};const ctx=vm.createContext({window:win});
for(const file of ['resources.js','orders-resources.js','ordres.js'])
 vm.runInContext(fs.readFileSync(path.join(root,'i18n',file),'utf8'),ctx);
const engine={t(key,{lng,defaultValue}){return key.split('.').reduce((v,k)=>v?.[k],win.RP_I18N_RESOURCES[lng].translation)??defaultValue}};
test('quinze ordres pilotes ont les mêmes identifiants dans neuf langues',()=>{
 const ref=Object.keys(win.RP_I18N_RESOURCES.fr.translation.orders);
 assert.equal(ref.length,15);
 for(const lang of Object.keys(win.RP_I18N_LANGUAGES)) {
  const data=win.RP_I18N_RESOURCES[lang].translation.orders;
  assert.deepEqual(Object.keys(data),ref);
  for(const label of Object.values(data)) assert.ok(label);
 }
});
test('la langue ne modifie pas la commande serveur ni son coût',()=>{
 const source=Object.freeze({fn:'voter_election',label:'Voter',pa:1,cost:0});
 assert.equal(win.RPOrderI18n.label(source,engine,'de'),'Abstimmen');
 assert.equal(win.RPOrderI18n.label(source,engine,'ar'),'التصويت');
 assert.equal(source.label,'Voter');assert.equal(source.pa,1);
});
test('une variation de prix reste canonique sans clé contextuelle',()=>{
 const source=Object.freeze({fn:'louer_local',label:'Louer ce local (800 FR/jour)',cost:800});
 assert.equal(win.RPOrderI18n.label(source,engine,'en'),source.label);
});
