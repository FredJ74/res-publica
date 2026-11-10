'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const root=path.resolve(__dirname,'../..'),read=p=>fs.readFileSync(path.join(root,p),'utf8');
const src=read('plateau-actions-illegales-rumeurs.js'),localeSrc=read('i18n/commerce-menu-resources.js');
const langs=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
function load(locale,enabled=true){
 const window={RP_I18N_GAME_ENABLED:enabled,RPPlateauI18n:{language:()=>locale},RP_I18N_RESOURCES:{}};
 for(const lang of langs)window.RP_I18N_RESOURCES[lang]={translation:{}};
 const ctx=vm.createContext({window,console,Number,Object});
 vm.runInContext(localeSrc,ctx);return {ctx,window};
}
test('27 clés par langue, mêmes variables, aucun texte absent',()=>{
 const ref=load('fr').window.RP_I18N_RESOURCES.fr.translation.commerceMenu;
 assert.equal(Object.keys(ref).length,27);
 for(const locale of langs){
  const x=load(locale).window.RP_I18N_RESOURCES[locale].translation.commerceMenu;
  assert.deepEqual(Object.keys(x),Object.keys(ref),locale);
  for(const key of Object.keys(ref)){
   assert.ok(typeof x[key]==='string'&&x[key].trim(),locale+'/'+key);
   const v=s=>(s.match(/\{\w+\}/g)||[]).sort();
   assert.deepEqual(v(x[key]),v(ref[key]),locale+'/'+key);
  }
 }
});
test('affichage respectant langue, variables, fail-closed et texte français désactivé',()=>{
 const ru=load('ru').window.RPCommerceMenuI18n;
 assert.equal(ru.text('required',{price:5,currency:'PSK'}),'Требуется 5 PSK.');
 assert.equal(ru.productLabel('the_chaud_sovarka','Thé chaud'),'Горячий чай');
 assert.equal(ru.productLabel('the_chaud_sovarka','Étiquette modifiée'),'Étiquette modifiée');
 assert.equal(ru.productLabel('autre','Thé chaud'),'Thé chaud');
 assert.equal(ru.html('orderJournal',{product:'<x>',price:5,currency:'PSK'}),'Заказ: &lt;x&gt; — 5 PSK.');
 const ar=load('ar',false).window.RPCommerceMenuI18n;
 assert.equal(ar.text('order'),'Commander');
 assert.equal(ar.productLabel('the_chaud_sovarka','Thé chaud'),'Thé chaud');
});
const a=src.indexOf('function texteCommerceMenu('),b=src.indexOf('// =====================\n// FAIRE DES ACHATS',a);
assert.ok(a>=0&&b>a);const section=src.slice(a,b);
test('la carte Dynamo traduit ses boutons, le stock et conserve son prix PSK',async()=>{
 for(const locale of langs){
  const {ctx,window}=load(locale);
  const product={id:'the_chaud_sovarka',label:'Thé chaud',materiaux:{},effets:{moral:1},image:null};
  const data={carte:[product.id],stockProduits:{[product.id]:5},
    parametres:{prixVente:{[product.id]:5}}};
  const elements={'postes-modal-title':{textContent:''},'postes-body':{innerHTML:''},
    'modal-postes':{classList:{add(){}}}};
  Object.assign(ctx,{state:{country:'soviet',currentCity:'capitale'},
    COUNTRIES:{soviet:{cur:'PSK'}},
    resoudreProduitCommerce:id=>id===product.id?product:null,
    chargerCommerce:async()=>data,
    deduireCoutOrdre:async()=>({ok:true}),
    commercePeutProduire:()=>true,
    recetteAutoriseePourCommerce:()=>true,
    document:{getElementById:id=>elements[id]}});
  vm.runInContext(section,ctx);
  await vm.runInContext("doConsulterCarteCommerce('buvette','stade','buvette',0,0)",ctx);
  const h=elements['postes-body'].innerHTML,dict=window.RP_I18N_RESOURCES[locale].translation.commerceMenu;
  assert.equal(elements['postes-modal-title'].textContent,dict.card);
  assert.ok(h.includes(dict.prodTea),locale+' produit');
  assert.ok(h.includes(dict.stock.replace('{stock}','5')),locale+' stock');
  assert.ok(h.includes('5 PSK'),locale+' prix');
  assert.ok(h.includes(dict.order),locale+' bouton commander');
  assert.ok(h.includes(dict.produce),locale+' bouton produire');
  assert.ok(h.includes(dict.sheet),locale+' bouton fiche');
  assert.ok(h.includes("doCommanderProduitCommerceUI('buvette','stade','buvette','the_chaud_sovarka')"),locale+' callback');
 }
});
test('aucun identifiant, RPC ou condition métier modifié par les libellés',()=>{
 assert.ok(section.includes("doCommanderProduitCommerceUI('+args+')"));
 assert.ok(section.includes("doProduireRecetteCommerceUI('+args+')"));
 assert.ok(section.includes('await commanderProduitCommerce(commerceType, pays, ville, buildingId, roomId, recetteId)'));
 assert.ok(section.includes('await deduireCoutOrdre({ pa, cost })'));
 assert.ok(section.includes('stock>0'));
 assert.ok(read('plateau.html').includes('i18n/commerce-menu-resources.js'));
});
