'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const root=path.resolve(__dirname,'../..');
const read=f=>fs.readFileSync(path.join(root,f),'utf8');
const script=read('plateau-terrain-banque.js'),dictionary=read('i18n/finance135-resources.js'),html=read('plateau.html');
const langs=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
function setup(lang){
 const ctx={console,locale:lang,state:{country:'republic',currentCity:'capitale',poste:{id:'maire',city:'capitale'},char:{name:'TEST'}},
  RP_I18N_GAME_ENABLED:true,RPPlateauI18n:{language:()=>ctx.locale},
  RP_I18N_RESOURCES:Object.fromEntries(langs.map(x=>[x,{translation:{}}]))};
 let title='',body='',open=false;const calls=[];
 const modal={classList:{add(){open=true},contains(v){return v==='open'&&open}}};
 const nodes=['buyerIntro','commune','personal','communeDesc'].map(k=>({
  textContent:'',getAttribute:name=>name==='data-finance135-key'?k:null,key:k
 }));
 const box={get innerHTML(){return body},set innerHTML(v){body=v},
  querySelector:q=>q==='#finance135-choix'&&body.includes('id="finance135-choix"')?{}:null,
  querySelectorAll:q=>q==='[data-finance135-key]'?nodes:[]};
 const heading={set textContent(v){title=v},get textContent(){return title}};
 ctx.document={getElementById:id=>({'postes-body':box,'postes-modal-title':heading,'modal-postes':modal})[id]||null};
 ctx.sbRpcVerdict=()=>{calls.push('rpc');throw Error('No RPC expected')};
 ctx.window=ctx;vm.createContext(ctx);
 vm.runInContext(dictionary,ctx,{filename:'finance135-resources.js'});
 vm.runInContext(script,ctx,{filename:'plateau-terrain-banque.js'});
 return{ctx,nodes,calls,get title(){return title},get body(){return body}};
}
test('44 clés exactes et variables identiques dans les neuf langues',()=>{
 const {ctx}=setup('fr'),fr=ctx.RP_I18N_RESOURCES.fr.translation.finance135;
 assert.equal(Object.keys(fr).length,44);
 for(const lang of langs){
  const d=ctx.RP_I18N_RESOURCES[lang].translation.finance135;
  assert.deepEqual(Object.keys(d).sort(),Object.keys(fr).sort(),lang);
  for(const [k,v] of Object.entries(fr)){
   assert.ok(d[k]&&d[k].trim(),lang+':'+k);
   const vars=x=>(x.match(/\{[a-z]+\}/g)||[]).sort().join(',');
   assert.equal(vars(d[k]),vars(v),lang+':'+k);
  }
 }
});
test('les motifs servent uniquement à la présentation, jamais à la décision',()=>{
 for(const lang of langs){
  const {ctx}=setup(lang);
  assert.equal(vm.runInContext("financeR('commune_sans_pret')",ctx),
   ctx.RP_I18N_RESOURCES[lang].translation.finance135.reason_commune_sans_pret);
  assert.equal(vm.runInContext("financeT('loanEntry','Prêt {type} accordé : {amount} FR.',{type:'immobilier',amount:120})",ctx),
   ctx.RP_I18N_RESOURCES[lang].translation.finance135.loanEntry.replace('{type}','immobilier').replace('{amount}','120'));
 }
});
test('sélection du maire en neuf langues, paramètres et identifiants préservés',async()=>{
 for(const lang of langs){
  const a=setup(lang);
  const promise=vm.runInContext('terrainChoisirAcquereur()',a.ctx);
  const words=a.ctx.RP_I18N_RESOURCES[lang].translation.finance135;
  assert.equal(a.title,words.chooseBuyer,lang);
  assert.ok(a.body.includes(words.buyerIntro),lang);
  assert.ok(a.body.includes(words.commune),lang);
  assert.ok(a.body.includes(words.personal),lang);
  assert.ok(a.body.includes("terrainAcquereurRepondre('commune')"),lang);
  assert.ok(a.body.includes("terrainAcquereurRepondre('personnel')"),lang);
  vm.runInContext("terrainAcquereurRepondre('commune')",a.ctx);
  assert.equal(await promise,'commune');
  assert.equal(a.calls.length,0);
 }
});
test('bascule de langue à chaud : choix en cours sans nouvelle RPC',async()=>{
 const a=setup('fr');
 const promise=vm.runInContext('terrainChoisirAcquereur()',a.ctx);
 const original=a.body;
 a.ctx.locale='ko';
 for(const cb of a.ctx.RP_I18N_CHANGE_CALLBACKS)cb();
 assert.equal(a.body,original);
 assert.equal(a.calls.length,0);
 assert.equal(a.title,a.ctx.RP_I18N_RESOURCES.ko.translation.finance135.chooseBuyer);
 assert.equal(a.nodes[0].textContent,a.ctx.RP_I18N_RESOURCES.ko.translation.finance135.buyerIntro);
 vm.runInContext("terrainAcquereurRepondre('personnel')",a.ctx);
 assert.equal(await promise,'personnel');
});
test('aucun contrat, prix, montant ou RPC modifiés',()=>{
 for(const symbol of ['pret_national_contracter_versionne','terrain_acquisition_commande','finance_terrain_banque_recu',
 'p_montant:i.parametres.p_montant','p_duree_jours:i.parametres.p_duree_jours',
 'p_requete:i.requete','p_terrain:i.parametres.p_terrain','p_action:i.parametres.p_action'])
 assert.ok(script.includes(symbol),symbol);
 assert.match(html,/i18n\/finance135-resources\.js\?v=20261112/);
 assert.match(html,/plateau-terrain-banque\.js\?v=i18n-finance135-20261112/);
});
