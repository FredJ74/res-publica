'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '../..');
const src = f => fs.readFileSync(path.join(root, f), 'utf8');
const langs = ['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
function fixture(language='fr'){
 let current=language, rpcCalls=0;
 const elements={};
 function element(id){
  if (!elements[id]) {
   const e={innerHTML:'',textContent:'',open:false,classList:{add(){e.open=true;},contains(k){return k==='open'&&e.open;}},
     querySelector(sel){return sel==='[data-rp-plan-rues]' && e.innerHTML.includes('data-rp-plan-rues="1"') ? {} : null;}};
   elements[id]=e;
  }
  return elements[id];
 }
 const document={getElementById:element};
 const ctx={console,document,state:{country:'soviet',currentCity:'capitale',currentBuilding:null},
  RP_I18N_GAME_ENABLED:true,RP_I18N_RESOURCES:Object.fromEntries(langs.map(l=>[l,{translation:{}}])),
  RPPlateauI18n:{language:()=>current},sbRpc(){rpcCalls++;throw Error('RPC forbidden');}};
 ctx.window=ctx;vm.createContext(ctx);
 for(const p of ['data.js','plateau-rue-centrale.js','i18n/navigation-resources.js','plateau-plan-rues.js'])
  vm.runInContext(src(p),ctx,{filename:p});
 vm.runInContext('rueCentraleNoeudActuel = RUE_CENTRALE_DEPART.soviet.capitale',ctx);
 return {ctx,elements,setLang:l=>{current=l},rpc:()=>rpcCalls};
}
test('Les 5 libellés du plan existent en neuf langues et le français reste canonique',()=>{
 const f=fixture();
 const fr=f.ctx.RP_I18N_RESOURCES.fr.translation.navigation;
 for(const lang of langs) {
  const words=f.ctx.RP_I18N_RESOURCES[lang].translation.navigation;
  for(const key of ['planTitlePrefix','planOfCity','hereSuffix','hereText','onStreet'])
   assert.equal(typeof words[key],'string',lang+':'+key);
  assert.ok(words.planTitlePrefix.length>0);
 }
 assert.equal(fr.planTitlePrefix,'Plan de ');
 assert.equal(fr.onStreet,'Vous êtes ici, dans la rue.');
});
test('Le plan des rues de Novomirsk est traduit sans déplacement ni RPC, dans toutes les langues',()=>{
 const f=fixture();
 for(const lang of langs){
  f.setLang(lang);
  assert.equal(vm.runInContext("ouvrirPlanRuesVille('soviet','capitale')",f.ctx),true,lang);
  const body=f.elements['minimap-ville-body'].innerHTML;
  const words=f.ctx.RP_I18N_RESOURCES[lang].translation.navigation;
  assert.ok(body.includes(words.planTitlePrefix),lang+' plan prefix');
  assert.ok(body.includes(words.onStreet),lang+' street');
  assert.ok(body.includes(words.hereText),lang+' point');
  assert.match(body,/data-rp-plan-rues="1"/);
  assert.equal(f.rpc(),0);
 }
});
test('Le plan ouvert se rafraîchit en place à la bascule de langue, sans serveur',()=>{
 const f=fixture('fr');
 vm.runInContext("ouvrirPlanRuesVille('soviet','capitale')",f.ctx);
 assert.ok(f.elements['minimap-ville-body'].innerHTML.includes('Vous êtes ici, dans la rue.'));
 f.setLang('ko');
 for(const cb of f.ctx.RP_I18N_CHANGE_CALLBACKS) cb();
 const translated=f.ctx.RP_I18N_RESOURCES.ko.translation.navigation.onStreet;
 assert.ok(f.elements['minimap-ville-body'].innerHTML.includes(translated));
 assert.equal(f.rpc(),0);
 f.elements['modal-minimap-ville'].open=false;
 f.setLang('ar');
 for(const cb of f.ctx.RP_I18N_CHANGE_CALLBACKS) cb();
 assert.ok(f.elements['minimap-ville-body'].innerHTML.includes(translated),'closed modal not repainted');
});
test('Les scripts invalidant le cache sont chargés, le calcul pur reste exposé',()=>{
 const html=src('plateau.html');
 assert.match(html,/plateau-plan-rues\.js\?v=plan-rues-i18n-20261113/);
 assert.match(html,/i18n\/navigation-resources\.js\?v=plan-rues-i18n-20261113/);
 const calc=require(path.join(root,'plateau-plan-rues.js'));
 assert.equal(typeof calc.calculerPlanRues,'function');
 assert.equal(typeof calc.dessinerPlanRues,'function');
});
