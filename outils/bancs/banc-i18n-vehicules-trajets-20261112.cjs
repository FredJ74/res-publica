'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),vm=require('node:vm'),fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'../..'),read=f=>fs.readFileSync(path.join(root,f),'utf8');
const original=read('plateau-vehicules.js'),res=read('i18n/vehicle-travel-resources.js'),garageRes=read('i18n/vehicle-garage-resources.js'),html=read('plateau.html');
const langs=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
function fixture(locale='fr'){
 let modalTitle='',modalBody='',opened=false;const calls=[],fields={};
 const corps={get innerHTML(){return modalBody},set innerHTML(s){
   modalBody=s;
   for(const k of Object.keys(fields))delete fields[k];
   for(const m of s.matchAll(/<input[^>]+id="([^"]+)"[^>]*value="([^"]+)"/g))fields[m[1]]={id:m[1],value:m[2]};
   for(const m of s.matchAll(/<select[^>]+id="([^"]+)"/g))fields[m[1]]={id:m[1],value:'0'};
 },querySelector(q){const m=q.match(/\[data-veh-i18n="([^"]+)"\]/);return m&&modalBody.includes('data-veh-i18n="'+m[1]+'"')?{}:null},
 querySelectorAll(){return Object.values(fields)}};
 const doc={getElementById(id){
   if(id==='postes-body')return corps;
   if(id==='postes-modal-title')return{set textContent(v){modalTitle=v}};
   if(id==='modal-postes')return{classList:{add(){opened=true},contains(){return opened},remove(){opened=false}}};
   return fields[id]||null;
 }};
 const garage={id:'g1',type:'garage',proprietaire:'PNJ',prix:{revision_vehicule:500},stock:{},matieres:{},fabrication:null};
 const car={id:'v1',numero:123,modele:'voiture',label:'Voiture',places:4,pays:'republic',ville:'capitale',
  proprietaire:'A',carburant:5,reservoir:18,consommation:2,unites:3,chargement:150,trajets:4,
  sur_place:true,statut:'ok',routes:['ville_a'],cargaison:[{name:'Colis',qty:2}]};
 const state={country:'republic',char:{name:'A'},currentCity:'capitale',pa:12,inventory:[{name:'Carburant',stackKey:'carburant',qty:4},{name:'Livre',qty:2}]};
 const ctx={window:null,console,document:doc,state,
  lang:locale,RP_I18N_GAME_ENABLED:true,
  RP_I18N_RESOURCES:Object.fromEntries(langs.map(x=>[x,{translation:{}}])),
  RPPlateauI18n:{language:()=>ctx.lang},COUNTRIES:{republic:{cur:'FR'}},
  villeNom:(p,v)=>v,
  sbRpcVerdict:async name=>{calls.push(name);return{ok:true,ici:garage,vehicules:[car]};},
  showToast(){},sessionStorage:{getItem(){return null},setItem(){},removeItem(){}}
 };
 ctx.window=ctx;vm.createContext(ctx);
 vm.runInContext(garageRes,ctx);vm.runInContext(res,ctx);vm.runInContext(original,ctx);
 return{ctx,calls,fields,car,get title(){return modalTitle},get body(){return modalBody}};
}
test('47 libellés sur neuf langues, mêmes paramètres dynamiques',()=>{
 const f=fixture(),fr=f.ctx.RP_I18N_RESOURCES.fr.translation.vehicleTravel;
 assert.equal(Object.keys(fr).length,47);
 const variables=s=>(s.match(/\{[a-z]+\}/g)||[]).sort().join(',');
 for(const lang of langs){
  const tr=f.ctx.RP_I18N_RESOURCES[lang].translation.vehicleTravel;
  assert.deepEqual(Object.keys(tr).sort(),Object.keys(fr).sort());
  for(const k of Object.keys(fr)){
   assert.ok(tr[k]?.trim(),lang+':'+k);
   assert.equal(variables(tr[k]),variables(fr[k]),lang+':'+k);
  }
 }
});
test('neuf langues : itinéraire, cargaison et chiffres intacts',async()=>{
 for(const lang of langs){
  const f=fixture(lang);await vm.runInContext('ouvrirMesVehicules()',f.ctx);
  const tr=f.ctx.RP_I18N_RESOURCES[lang].translation.vehicleTravel;
  assert.equal(f.title,tr.vehicles);
  assert.ok(f.body.includes(tr.cargo),lang);
  assert.ok(f.body.includes('4'),lang);
  assert.ok(f.body.includes('18'),lang);
  assert.ok(f.body.includes('150'),lang);
  assert.match(f.body,/vehConduire\('v1','ville_a'\)/);
  assert.match(f.body,/vehCharger\('v1'\)/);
  assert.match(f.body,/vehDecharger\('v1',0\)/);
  assert.equal(f.calls.length,1,lang);
 }
});
test('révision : 500 FR et compteur conservés dans les neuf langues',async()=>{
 for(const lang of langs){
  const f=fixture(lang);await vm.runInContext('ouvrirGarageRevision()',f.ctx);
  const tr=f.ctx.RP_I18N_RESOURCES[lang].translation.vehicleTravel;
  assert.equal(f.title,tr.revisionTitle);
  assert.ok(f.body.includes('500'),lang);
  assert.ok(f.body.includes(tr.revisionNote.split('{price}')[0]),lang);
  assert.match(f.body,/vehReviser\('v1'\)/);
  assert.equal(f.calls.length,1);
 }
});
test('panne : options et coûts immuables, nom du garage inchangé',()=>{
 for(const lang of langs){
  const f=fixture(lang);vm.runInContext("afficherPanneVehicule('v1',{depart:'capitale',destination:'ville_a',garages:[{id:'g1',nom:'Garage Maritime',ville:'capitale',prix:150}]})",f.ctx);
  const tr=f.ctx.RP_I18N_RESOURCES[lang].translation.vehicleTravel;
  assert.equal(f.title,tr.breakdownTitle);
  assert.ok(f.body.includes(tr.breakdownBig),lang);
  assert.ok(f.body.includes('Garage Maritime'),lang);
  assert.match(f.body,/vehDepanner\('v1','g1'\)/);
  assert.ok(f.body.includes('150'),lang);
  assert.equal(f.calls.length,0);
 }
});
test('bascule de langue en fenêtre ouverte : cache uniquement et saisies préservées',async()=>{
 const f=fixture('fr');await vm.runInContext('ouvrirMesVehicules()',f.ctx);
 assert.equal(f.calls.length,1);
 f.fields['veh-plein-v1'].value='3';
 f.ctx.lang='ar';for(const cb of f.ctx.RP_I18N_CHANGE_CALLBACKS)cb();
 assert.equal(f.calls.length,1);
 assert.equal(f.fields['veh-plein-v1'].value,'3');
 assert.ok(f.body.includes('الحمولة'));
 assert.equal(f.title,'مركباتي');
});
test('catalogue enregistré et logique transactionnelle inchangée',()=>{
 assert.match(html,/i18n\/vehicle-travel-resources\.js\?v=20261112/);
 assert.match(html,/plateau-vehicules\.js\?v=i18n-vehicules-complet-20261112/);
 assert.match(read('outils/audits/audit-i18n-editorial.cjs'),/'vehicle-travel-resources\.js'/);
 assert.match(original,/sbRpcVerdict\('vehicule_acte'/);
 assert.match(original,/p_requete: requete, p_action: action, p_parametres: parametres/);
 assert.match(original,/vehActe\('trajet', \{ vehicule: id, ville \}/);
 assert.match(original,/await sbLoadPersonnage\(state.char\?\.name\)/);
});
