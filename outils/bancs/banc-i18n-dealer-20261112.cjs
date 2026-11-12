'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const root=path.resolve(__dirname,'../..'),read=p=>fs.readFileSync(path.join(root,p),'utf8');
const js=read('plateau-ced.js'),resource=read('i18n/dealer-resources.js'),html=read('plateau.html');
const langs=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
function setup(locale='fr'){
 let body='',title='',opened=false;
 const calls=[],actor={name:'PJ fictif'},storage=new Map();
 const ctx={console,locale,state:{country:'republic',currentCity:'capitale',currentBuilding:'centre-artisanal',currentRoom:'travees',char:actor},
  RP_I18N_GAME_ENABLED:true,RPPlateauI18n:{language:()=>ctx.locale},
  RP_I18N_RESOURCES:Object.fromEntries(langs.map(x=>[x,{translation:{}}])),
  rpAuthUid:()=> 'uid-test',sessionStorage:{getItem:k=>storage.get(k)||null,setItem:(k,v)=>storage.set(k,v),removeItem:k=>storage.delete(k)},
  crypto:{randomUUID:()=> 'test-request'},
  document:{getElementById(id){
   if(id==='modal-pnj')return {classList:{remove(){}}};
   if(id==='postes-modal-title')return {set textContent(v){title=v},get textContent(){return title}};
   if(id==='modal-postes')return {classList:{add(k){if(k==='open')opened=true},contains:k=>k==='open'&&opened,remove(){opened=false}}};
   if(id==='postes-body')return {get innerHTML(){return body},set innerHTML(v){body=v},querySelector:selector=>body.includes('data-ced-catalog="1"')?{}:null};
   return null;
  }},
  sbRpc:async name=>{
   calls.push(name);
   if(name!=='dealer_stocks_lire')throw Error('No purchase RPC during rendering');
   return {ok:true,brume:{stock:3},estadine:{stock:0}};
  }
 };
 ctx.window=ctx;vm.createContext(ctx);vm.runInContext(resource,ctx,{filename:'dealer-resources.js'});
 vm.runInContext(js,ctx,{filename:'plateau-ced.js'});
 return {ctx,calls,actor,get body(){return body},get title(){return title}};
}
test('29 libellés en neuf langues, variables identiques',()=>{
 const {ctx}=setup(),orig=ctx.RP_I18N_RESOURCES.fr.translation.dealer;
 assert.equal(Object.keys(orig).length,29);
 const vars=s=>(s.match(/\{[a-z]+\}/g)||[]).sort().join(',');
 for(const lang of langs){
  const words=ctx.RP_I18N_RESOURCES[lang].translation.dealer;
  assert.deepEqual(Object.keys(words).sort(),Object.keys(orig).sort());
  for(const key of Object.keys(orig)){
   assert.ok(words[key]?.trim(),lang+':'+key);
   assert.equal(vars(words[key]),vars(orig[key]),lang+':'+key);
  }
 }
});
test('neuf langues : galerie dealer, 50/120 FR et stocks, sans achat',async()=>{
 for(const lang of langs){
  const x=setup(lang);await x.ctx.ouvrirAchatCed();
  const w=x.ctx.RP_I18N_RESOURCES[lang].translation.dealer;
  assert.equal(x.title,"Céd' Labone");
  assert.ok(x.body.includes(w.brumeName));
  assert.ok(x.body.includes(w.estadineName));
  assert.ok(x.body.includes(w.brumeDesc));
  assert.ok(x.body.includes(w.illegalNotice));
  assert.ok(x.body.includes(w.inStock.replace('{stock}','3')));
  assert.ok(x.body.includes(w.outOfStock));
  assert.ok(x.body.includes('50 FR'));
  assert.ok(x.body.includes('120 FR'));
  assert.ok(x.body.includes("confirmerAchatCed('brume')"));
  assert.ok(x.body.includes("confirmerAchatCed('estadine')"));
  assert.equal(x.calls.join(','),'dealer_stocks_lire');
 }
});
test('bascule de langue dans la vitrine ouverte : stock mis en cache, zéro RPC',async()=>{
 const x=setup('fr');await x.ctx.ouvrirAchatCed();
 const before=x.body;
 x.ctx.locale='ar';
 assert.equal(x.ctx.RP_I18N_CHANGE_CALLBACKS.length,1);
 x.ctx.RP_I18N_CHANGE_CALLBACKS[0]();
 assert.notEqual(x.body,before);
 assert.ok(x.body.includes(x.ctx.RP_I18N_RESOURCES.ar.translation.dealer.brumeDesc));
 assert.ok(x.body.includes('50 FR'));
 assert.equal(x.calls.length,1);
});
test('règles métier, produits, reçus et audit inchangés',()=>{
 assert.match(js,/dealer_stocks_lire/);
 assert.match(js,/dealer_acheter/);
 assert.match(js,/p_requete: c.requete, p_produit: produit/);
 assert.match(js,/cedCleReprise\(produit\)/);
 assert.match(js,/inventaire_reception_etat/);
 assert.match(js,/sbAdopterInventaireServeur/);
 assert.match(js,/drogues_descentes_appliquer/);
 assert.match(html,/i18n\/dealer-resources\.js\?v=20261112/);
 assert.match(html,/plateau-ced\.js\?v=dealer-i18n-20261112/);
 assert.match(read('outils/audits/audit-i18n-editorial.cjs'),/dealer-resources\.js/);
});
