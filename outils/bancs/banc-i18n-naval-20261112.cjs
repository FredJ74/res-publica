'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const root=path.resolve(__dirname,'../..');
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const langs=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
const source=read('plateau-naval.js'),res=read('i18n/naval-resources.js'),html=read('plateau.html');
const sample=model=>({modele:model,prix_total_fr:150000,acompte:52500,jours:7,passagers:3,fret:300,
 recette:{bois:1800,metal:1800,derives_petrochimiques:600},
 entrepot_psm:{bois:1200,metal:500,derives_petrochimiques:200},
 manquant_psm:{bois:600,metal:1300,derives_petrochimiques:400}});
function fixture(locale='fr'){
 const calls=[],toasts=[];let title='',body='',opened=false,confirmed='';
 const controls={
 'postes-modal-title':{get textContent(){return title},set textContent(v){title=v}},
 'postes-body':{get innerHTML(){return body},set innerHTML(v){body=v},
  querySelector(q){return q==='[data-naval-catalog]'&&body.includes('data-naval-catalog')?{}:null}},
 'modal-postes':{classList:{add(){opened=true},contains(k){return k==='open'&&opened}}}
 };
 const context={console,state:{country:'republic',currentCity:'ville_a',currentBuilding:'chantier-naval'},
 RP_I18N_GAME_ENABLED:true,RPPlateauI18n:{language:()=>context.locale},locale,
 RP_I18N_RESOURCES:Object.fromEntries(langs.map(x=>[x,{translation:{}}])),
 document:{getElementById:k=>controls[k]||null},
 sbRpc:async(nom)=>{calls.push(nom);if(nom==='chantier_naval_devis')return [sample('bateau_3'),sample('bateau_5')];
 if(nom==='chantier_naval_mes_commandes')return [{modele:'bateau_3',etat:'bloque_matieres',jours:2,total:7,verse:52500,prix_total:150000,bateau_id:null}];
 throw Error('Unexpected RPC: '+nom)},
 showToast:(...args)=>toasts.push(args),sessionStorage:{getItem(){return null},setItem(){},removeItem(){}},
 crypto:{randomUUID:()=> 'fixture-uuid'},confirm:s=>{confirmed=s;return false}};
 context.window=context;vm.createContext(context);
 vm.runInContext(res,context,{filename:'naval-resources.js'});
 vm.runInContext(source,context,{filename:'plateau-naval.js'});
 return{context,calls,toasts,get body(){return body},get title(){return title},get confirmed(){return confirmed}};
}
test('36 clés et variables cohérentes dans les neuf langues',()=>{
 const e=fixture(),fr=e.context.RP_I18N_RESOURCES.fr.translation.naval;
 assert.equal(Object.keys(fr).length,36);
 for(const lang of langs){
  const d=e.context.RP_I18N_RESOURCES[lang].translation.naval;
  assert.deepEqual(Object.keys(d).sort(),Object.keys(fr).sort());
  for(const k of Object.keys(fr)){
   assert.ok(d[k]&&d[k].trim(),lang+':'+k);
   const params=v=>(v.match(/\{[a-z]+\}/g)||[]).sort().join(',');
   assert.equal(params(d[k]),params(fr[k]),lang+':'+k);
  }
 }
});
test('neuf langues : devis, identifiants et paramètres serveur inchangés',async()=>{
 for(const lang of langs){
  const e=fixture(lang);await e.context.ouvrirDevisChantierNaval();
  const t=e.context.RP_I18N_RESOURCES[lang].translation.naval;
  assert.equal(e.title,t.title,lang);
  assert.ok(e.body.includes(t.constructionNotice),lang);
  assert.ok(/150[  ]000 FR/.test(e.body),lang);
  assert.ok(/52[  ]500 FR/.test(e.body),lang);
  assert.ok(e.body.includes('1800')||/1[\u202f ]800/.test(e.body),lang);
  assert.ok(e.body.includes("commanderBateauNaval('bateau_3')"),lang);
  assert.ok(e.body.includes("commanderBateauNaval('bateau_5')"),lang);
  assert.ok(e.body.includes(t.blockedMaterials),lang);
  assert.equal(e.calls.length,2,lang);
 }
});
test('changement de langue dans devis ouvert : aucune requête supplémentaire',async()=>{
 const e=fixture('fr');await e.context.ouvrirDevisChantierNaval();
 assert.equal(e.calls.length,2);
 e.context.locale='ar';for(const cb of e.context.RP_I18N_CHANGE_CALLBACKS)cb();
 assert.equal(e.calls.length,2);
 assert.ok(e.body.includes('بناء'),e.body.slice(0,180));
 assert.equal(e.title,e.context.RP_I18N_RESOURCES.ar.translation.naval.title);
 assert.ok(e.body.includes("commanderBateauNaval('bateau_3')"));
});
test('annulation de commande : identifiants et montant transmis à la confirmation uniquement',async()=>{
 const e=fixture('en');await e.context.ouvrirDevisChantierNaval();
 await e.context.commanderBateauNaval('bateau_3');
 assert.ok(/150[  ]000 FR/.test(e.confirmed));
 assert.ok(/52[  ]500 FR/.test(e.confirmed));
 assert.ok(e.confirmed.includes('3-seat boat'));
 assert.equal(e.calls.length,2,'no order RPC on refusal');
});
test('RPC, plafonds, devis et livraison non modifiés',()=>{
 assert.match(source,/chantier_naval_commander/);
 assert.match(source,/chantier_naval_devis/);
 assert.match(source,/chantier_naval_mes_commandes/);
 assert.match(source,/p_modele:modele,p_requete:requete/);
 assert.match(source,/state\.country !== 'republic'/);
 assert.match(html,/i18n\/naval-resources\.js\?v=20261112/);
 assert.match(html,/plateau-naval\.js\?v=naval-i18n-20261112/);
});
