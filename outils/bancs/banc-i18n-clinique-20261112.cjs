'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const root=path.resolve(__dirname,'../..');
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const moduleJs=read('plateau-clinique-nuitee.js'),dictJs=read('i18n/clinic-stay-resources.js'),html=read('plateau.html');
const langs=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
function fixture(lang='fr',country='republic'){
 let modalOpen=false,body='',title='';
 const calls=[],buttons={};
 const bodyEl={
  get innerHTML(){return body},set innerHTML(v){body=v},
  querySelector(selector){
   if(selector==='#clinique-nuitee-confirmation')return body.includes('id="clinique-nuitee-confirmation"')?{}:null;
   return buttons[selector]||(buttons[selector]={addEventListener(type,fn){this.click=fn;}});
  }
 };
 const modal={classList:{
   add(key){if(key==='open')modalOpen=true;},
   remove(key){if(key==='open')modalOpen=false;},
   contains(key){return key==='open'&&modalOpen;}
 }};
 const ctx={console,lang,
  state:{country,currentCity:'capitale',currentBuilding:'clinique-privee',
    currentRoom:'reception_clinique',char:{name:'PJ fictif'},locationsActives:[]},
  RP_I18N_GAME_ENABLED:true,
  RPPlateauI18n:{language:()=>ctx.lang},
  RP_I18N_RESOURCES:Object.fromEntries(langs.map(lang=>[lang,{translation:{}}])),
  document:{getElementById:id=>{
   if(id==='postes-body')return bodyEl;
   if(id==='modal-postes')return modal;
   if(id==='postes-modal-title')return {set textContent(v){title=v},get textContent(){return title}};
   return buttons['#'+id]||null;
  }},
  showToast(){},confirm(){throw Error('Native dialog forbidden');},
  sbRpc(){calls.push('unexpected');throw Error('No server call on render')}
 };
 ctx.window=ctx;vm.createContext(ctx);vm.runInContext(dictJs,ctx,{filename:'clinic-stay-resources.js'});
 vm.runInContext(moduleJs,ctx,{filename:'plateau-clinique-nuitee.js'});
 return {ctx,calls,get title(){return title},get body(){return body},get open(){return modalOpen}};
}
test('26 libellés disponibles et variables identiques dans les neuf langues',()=>{
 const {ctx}=fixture();
 const orig=ctx.RP_I18N_RESOURCES.fr.translation.clinicStay;
 assert.equal(Object.keys(orig).length,26);
 const params=v=>(v.match(/\{[a-z]+\}/g)||[]).sort().join(',');
 for(const lang of langs){
  const dict=ctx.RP_I18N_RESOURCES[lang].translation.clinicStay;
  assert.deepEqual(Object.keys(dict).sort(),Object.keys(orig).sort(),lang);
  for(const k of Object.keys(orig)){
   assert.ok(dict[k]?.trim(),lang+':'+k);
   assert.equal(params(dict[k]),params(orig[k]),lang+':'+k);
  }
 }
});
test('neuf langues : réservation gratuite côté navigateur, devise et règles du serveur',()=>{
 for(const lang of langs)for(const country of ['republic','soviet']){
  const x=fixture(lang,country),{ctx}=x;
  const order=ctx.RP_ORDRES_DYNAMIQUES[0]('clinique-privee','reception_clinique');
  assert.equal(order.length,1);
  assert.equal(order[0].fn,'clinique_reserver_nuit');
  assert.equal(order[0].cost,0);
  const currency=country==='soviet'?'PSK':'FR';
  const dict=ctx.RP_I18N_RESOURCES[lang].translation.clinicStay;
  assert.equal(order[0].label,dict.reserveLabel.replace('{currency}',currency));
  ctx.reserverNuiteeClinique();
  assert.equal(x.title,dict.title);
  assert.ok(x.body.includes(dict.oneNight),lang);
  assert.ok(x.body.includes(dict.confirmButton.replace('{currency}',currency)),lang);
  assert.ok(x.body.includes(dict.benefitStrong),lang);
  assert.ok(x.body.includes('150 '+currency),lang);
  assert.equal(x.calls.length,0,lang);
 }
});
test('bascule de langue au milieu de la confirmation : zéro RPC ni nouvelle transaction',()=>{
 const x=fixture('fr','soviet'),{ctx}=x;
 ctx.reserverNuiteeClinique();
 const oldBody=x.body;
 assert.equal(x.open,true);
 ctx.lang='ko';
 assert.equal(ctx.RP_I18N_CHANGE_CALLBACKS.length,1);
 ctx.RP_I18N_CHANGE_CALLBACKS[0]();
 assert.notEqual(x.body,oldBody);
 assert.equal(x.title,ctx.RP_I18N_RESOURCES.ko.translation.clinicStay.title);
 assert.ok(x.body.includes(ctx.RP_I18N_RESOURCES.ko.translation.clinicStay.oneNight));
 assert.ok(x.body.includes('150 PSK'));
 assert.equal(x.calls.length,0,'no reservation on language switch');
});
test('identifiants, RPC, montants et conventions HTML inchangés',()=>{
 assert.match(moduleJs,/fn:'clinique_reserver_nuit'/);
 assert.match(moduleJs,/fn:'clinique_dormir'/);
 assert.doesNotMatch(moduleJs,/clinique_verifier_bonus/);
 assert.match(moduleJs,/fn:'escort_standard'/);
 assert.match(moduleJs,/clinique_nuitee_reserver/);
 assert.match(moduleJs,/clinique_nuitee_consommer/);
 assert.match(moduleJs,/state\.country==='soviet'\?'PSK':'FR'/);
 assert.match(html,/i18n\/clinic-stay-resources\.js\?v=20261113/);
 assert.match(html,/plateau-clinique-nuitee\.js\?v=clinique-escorts-20261113/);
 assert.match(read('outils/audits/audit-i18n-editorial.cjs'),/clinic-stay-resources\.js/);
});
