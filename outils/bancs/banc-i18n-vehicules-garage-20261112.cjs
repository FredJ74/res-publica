'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),vm=require('node:vm'),fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'../..');
const read=f=>fs.readFileSync(path.join(root,f),'utf8');
const source=read('plateau-vehicules.js'),catalog=read('i18n/vehicle-garage-resources.js'),html=read('plateau.html');
const locales=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
function harness(lang='fr',type='garage'){
 const calls=[],pop={title:'',body:'',open:false,fields:{}};
 const body={get innerHTML(){return pop.body},set innerHTML(v){
  pop.body=v;const fields={};
  for(const m of v.matchAll(/<input[^>]+id="([^"]+)"[^>]*value="([^"]+)"/g))
   fields[m[1]]={id:m[1],value:m[2]};
  pop.fields=fields;
 },querySelector(q){
  return pop.body.includes('data-veh-i18n="'+(q.match(/"([^"]+)"/)||[])[1]+'"')?{}:null;
 },querySelectorAll(){return Object.values(pop.fields)}};
 const modal={classList:{add(v){pop.open=v==='open';},contains(v){return v==='open'&&pop.open;}}};
 const doc={getElementById(k){
  if(k==='postes-body')return body;
  if(k==='postes-modal-title')return{set textContent(v){pop.title=v}};
  if(k==='modal-postes')return modal;
  return pop.fields[k]||null;
 }};
 const garage={id:'g-1',type:'garage',stock:{voiture:1,'deux-roues':0,'vehicule-utilitaire':1},prix:{voiture:1500,'vehicule-utilitaire':2500},
    stock_max:{voiture:3},modeles:{voiture:{jours:5,pa:3,materiaux:{metal:10,textile:5}}},
    matieres:{metal:50},fabrication:null};
 const station={id:'s-1',type:'station-service',prix:{bidon_carburant:10},stock:{bidon_carburant:20}};
 const ctx={console,document:doc,lang,state:{country:'republic',pa:30,char:{name:'Demo'},inventory:[]},
  COUNTRIES:{republic:{cur:'FR'}},RP_I18N_GAME_ENABLED:true,
  RP_I18N_RESOURCES:Object.fromEntries(locales.map(x=>[x,{translation:{}}])),
  RPPlateauI18n:{language:()=>ctx.lang},
  sbRpcVerdict:async(name)=>{calls.push(name);return{ok:true,ici:type==='garage'?garage:station,vehicules:[]}},
  showToast(){},sessionStorage:{getItem(){return null},setItem(){},removeItem(){}}
 };
 ctx.window=ctx;vm.createContext(ctx);vm.runInContext(catalog,ctx,{filename:'vehicle-garage-resources.js'});
 vm.runInContext(source,ctx,{filename:'plateau-vehicules.js'});
 return{ctx,calls,pop};
}
test('41 libellés et variables intacts dans les neuf langues',()=>{
 const f=harness();
 const reference=f.ctx.RP_I18N_RESOURCES.fr.translation.vehicleGarage;
 assert.equal(Object.keys(reference).length,41);
 const vars=x=>(x.match(/\{[a-z]+\}/g)||[]).sort().join(',');
 for(const l of locales){
  const r=f.ctx.RP_I18N_RESOURCES[l].translation.vehicleGarage;
  assert.deepEqual(Object.keys(r).sort(),Object.keys(reference).sort());
  for(const k of Object.keys(reference)){
   assert.ok(r[k]?.trim(),l+'.'+k);
   assert.equal(vars(r[k]),vars(reference[k]),l+'.'+k);
  }
 }
});
test('neuf langues : mêmes trois modèles, identifiants, prix et quantités',async()=>{
 for(const lang of locales){
  const f=harness(lang);
  await vm.runInContext('ouvrirGarageVehicules()',f.ctx);
  const w=f.ctx.RP_I18N_RESOURCES[lang].translation.vehicleGarage;
  assert.ok(f.pop.body.includes(w.car),lang);
  assert.ok(f.pop.body.includes(w.buyPrice.split('{price}')[0]),lang);
  assert.ok(f.pop.body.includes(w.sellMaterials),lang);
  assert.match(f.pop.body,/vehAcheter\('voiture'\)/);
  assert.match(f.pop.body,/vehFabriquer\('g-1','voiture'\)/);
  assert.match(f.pop.body,/value="10"/);
  assert.ok(f.pop.body.includes('1\u202f500')||f.pop.body.includes('1 500')||f.pop.body.includes('1500'),lang);
  assert.equal(f.calls.join(','),'vehicules_lire');
 }
});
test('neuf langues : la station conserve unités, ID et achat',async()=>{
 for(const lang of locales){
  const f=harness(lang,'station-service');await vm.runInContext('ouvrirStationCarburant()',f.ctx);
  const w=f.ctx.RP_I18N_RESOURCES[lang].translation.vehicleGarage;
  assert.ok(f.pop.body.includes(w.stationHelp),lang);
  assert.ok(f.pop.body.includes(w.cans),lang);
  assert.match(f.pop.body,/vehAcheterBidons\(\)/);
  assert.match(f.pop.body,/vehConditionner\('s-1'\)/);
  assert.equal(f.calls.length,1);
 }
});
test('bascule de langue ouverte : aucun RPC, valeurs saisies préservées',async()=>{
 const f=harness('fr');
 await vm.runInContext('ouvrirGarageVehicules()',f.ctx);
 assert.equal(f.pop.open,true);
 assert.equal(f.pop.fields['veh-mat-metal'].value,'10');
 f.pop.fields['veh-mat-metal'].value='27';
 f.ctx.lang='ko';
 for(const cb of f.ctx.RP_I18N_CHANGE_CALLBACKS)cb();
 assert.equal(f.calls.length,1);
 assert.ok(f.pop.body.includes('차고에 자재 판매'));
 assert.equal(f.pop.fields['veh-mat-metal'].value,'27');
 const station=harness('fr','station-service');
 await vm.runInContext('ouvrirStationCarburant()',station.ctx);
 station.pop.fields['veh-bidons'].value='9';station.ctx.lang='ar';
 for(const cb of station.ctx.RP_I18N_CHANGE_CALLBACKS)cb();
 assert.equal(station.calls.length,1);
 assert.equal(station.pop.fields['veh-bidons'].value,'9');
 assert.ok(station.pop.body.includes('عبوات الوقود'));
});
test('audit éditorial et version HTML, moteurs et RPC inchangés',()=>{
 assert.match(html,/i18n\/vehicle-garage-resources\.js\?v=20261112/);
 assert.match(html,/plateau-vehicules\.js\?v=i18n-garage-station-20261112/);
 assert.match(read('outils/audits/audit-i18n-editorial.cjs'),/'vehicle-garage-resources\.js'/);
 assert.match(source,/sbRpcVerdict\('vehicules_lire'/);
 assert.match(source,/sbRpcVerdict\('vehicule_acte'/);
 assert.match(source,/p_requete: requete, p_action: action, p_parametres: parametres/);
 assert.match(source,/const VEH_MODELES = Object\.freeze/);
});
