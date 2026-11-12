'use strict';
// Contrôle de l'interface de publicité presse : données factices, aucun appel serveur.
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const root=path.resolve(__dirname,'../..');
const read=f=>fs.readFileSync(path.join(root,f),'utf8');
const source=read('plateau-publicite-premium.js'),dictionary=read('i18n/premium-ads-resources.js'),html=read('plateau.html');
const langs=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
function setup(lang){
 const requests=[],nodes={};
 const inputs={value:'Texte saisi qui doit être conservé',files:[{name:'test-factice.png'}],placeholder:''};
 let currentHtml='',currentTitle='',open=false;
 const list={get innerHTML(){return currentHtml},set innerHTML(v){currentHtml=v},querySelector(s){
   const m=s.match(/^\[data-premium-i18n="([^"]+)"\]$/);
   if(!m||!currentHtml.includes('data-premium-i18n="'+m[1]+'"'))return null;
   return nodes[m[1]]||(nodes[m[1]]={textContent:''});
 }};
 const title={get textContent(){return currentTitle},set textContent(x){currentTitle=x}};
 const modal={classList:{add(){open=true},contains(k){return k==='open'&&open}}};
 const context={console,locale:lang,state:{char:{name:null}},
   RP_I18N_GAME_ENABLED:true,
   RP_I18N_RESOURCES:Object.fromEntries(langs.map(x=>[x,{translation:{}}])),
   RPPlateauI18n:{language:()=>context.locale},
   document:{getElementById(id){return ({'postes-body':list,'postes-modal-title':title,'modal-postes':modal,'pub-premium-texte':inputs,'pub-premium-retour':{set textContent(v){requests.push(v)}}})[id]||null;}},
   fetch(){throw Error('Le changement de langue ne doit pas appeler le serveur');}
 };
 context.window=context;vm.createContext(context);
 vm.runInContext(dictionary,context,{filename:'premium-ads-resources.js'});
 vm.runInContext(source,context,{filename:'plateau-publicite-premium.js'});
 return {ctx:context,inputs,list,nodes,requests,get html(){return currentHtml},get title(){return currentTitle}};
}
test('41 libellés présents dans les neuf langues, mêmes variables',()=>{
 const e=setup('fr'),fr=e.ctx.RP_I18N_RESOURCES.fr.translation.premiumAds;
 assert.equal(Object.keys(fr).length,41);
 for(const lang of langs){
  const d=e.ctx.RP_I18N_RESOURCES[lang].translation.premiumAds;
  assert.deepEqual(Object.keys(d).sort(),Object.keys(fr).sort(),lang);
  for(const k of Object.keys(fr)){
   assert.ok(d[k]&&d[k].trim(),lang+':'+k);
   const vars=s=>(s.match(/\{[a-z]+\}/g)||[]).sort().join(',');
   assert.equal(vars(d[k]),vars(fr[k]),lang+':'+k);
  }
 }
});
test('9 langues : formulaire rendu et tarifs/identifiants/contraintes identiques',()=>{
 for(const lang of langs){
  const e=setup(lang),fr=e.ctx.RP_I18N_RESOURCES[lang].translation.premiumAds;
  e.ctx.ouvrirPublicitePremium();
  assert.equal(e.title,fr.title,lang);
  assert.ok(e.html.includes(fr.fullPage),lang);
  assert.ok(e.html.includes(fr.rights),lang);
  assert.ok(e.html.includes(fr.five),lang);
  assert.ok(e.html.includes(fr.ten),lang);
  assert.ok(e.html.includes('id="pub-premium-formule"'),lang);
  assert.ok(e.html.includes('value="cinq"'),lang);
  assert.ok(e.html.includes('value="dix"'),lang);
  assert.ok(e.html.includes('maxlength="1500"'),lang);
  assert.ok(e.html.includes('pub-premium-sources'),lang);
  assert.ok(e.html.includes('type="checkbox"'),lang);
  assert.ok(e.html.includes('publicitePremiumEnregistrerBrouillon()'),lang);
 }
});
test('bascule de langue à chaud : texte actualisé sans toucher aux champs ni aux fichiers',()=>{
 const e=setup('fr');e.ctx.ouvrirPublicitePremium();
 const original=e.html;assert.ok(original.includes('Votre pleine page publicitaire'));
 const value=e.inputs.value,files=e.inputs.files;
 e.ctx.locale='ko';
 assert.equal(e.ctx.RP_I18N_CHANGE_CALLBACKS.length,1);
 e.ctx.RP_I18N_CHANGE_CALLBACKS[0]();
 assert.equal(e.title,e.ctx.RP_I18N_RESOURCES.ko.translation.premiumAds.title);
 assert.equal(e.nodes.fullPage.textContent,e.ctx.RP_I18N_RESOURCES.ko.translation.premiumAds.fullPage);
 assert.equal(e.nodes.rights.textContent,e.ctx.RP_I18N_RESOURCES.ko.translation.premiumAds.rights);
 assert.equal(e.inputs.placeholder,e.ctx.RP_I18N_RESOURCES.ko.translation.premiumAds.placeholder);
 assert.equal(e.inputs.value,value);
 assert.equal(e.inputs.files,files);
 assert.equal(e.html,original,'aucun innerHTML reconstruit à chaud');
 assert.equal(e.requests.length,0,'aucune requête ou écriture');
});
test('refus local traduit et aucun appel serveur',async()=>{
 for(const lang of langs){
  const e=setup(lang);e.ctx.ouvrirPublicitePremium();await e.ctx.publicitePremiumEnregistrerBrouillon();
  assert.equal(e.requests[0],e.ctx.RP_I18N_RESOURCES[lang].translation.premiumAds.login);
 }
});
test('aucune modification des appels, tarifs et plafonds métier',()=>{
 assert.match(source,/rpc\/publicite_premium_creer_beta/);
 assert.match(source,/functions\/v1\/publicite-premium/);
 assert.match(source,/file\.size>5242880/);
 assert.match(source,/sources\.length>5/);
 assert.match(source,/remaining=2-data\.retouches/);
 assert.match(source,/p_formule:formule/);
 assert.match(source,/p_assistance:assistance/);
 assert.match(html,/i18n\/premium-ads-resources\.js\?v=20261112/);
 assert.match(html,/plateau-publicite-premium\.js\?v=i18n-20261112/);
});
