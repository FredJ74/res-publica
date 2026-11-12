'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const root=path.resolve(__dirname,'../..');
const read=f=>fs.readFileSync(path.join(root,f),'utf8');
const dictionary=read('i18n/civil-registry-resources.js');
const source=read('plateau-etat-civil.js');
const html=read('plateau.html');
const langs=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
function setup(lang){
 let locale=lang,title='',bodyHtml='',open=false,network=0;
 const field={value:'Pierre',placeholder:'Nom...',getAttribute:k=>k==='data-ec-placeholder'?'name':null};
 const dyn={
  textContent:'',getAttribute:k=>k==='data-ec-i18n'?'search':k==='data-ec-args'?'{}':null
 };
 const body={get innerHTML(){return bodyHtml},set innerHTML(v){bodyHtml=v},querySelector(){return {};},
 querySelectorAll(selector){
  if(selector==='[data-ec-i18n]')return[dyn];
  if(selector==='[data-ec-placeholder]')return[field];
  return[];
 }};
 const titleObj={set textContent(v){title=v},get textContent(){return title}};
 const doc={getElementById:id=>({
  'postes-modal-title':titleObj,'postes-body':body,'modal-postes':{classList:{add(){open=true},contains(k){return k==='open'&&open}}}
 })[id]||null};
 const ctx={window:null,console,document:doc,state:{country:'republic',inventory:[]},
  RP_I18N_RESOURCES:Object.fromEntries(langs.map(l=>[l,{translation:{}}])),
  RP_I18N_GAME_ENABLED:true,
  RPPlateauI18n:{language:()=>locale},sbRpc(){network++;throw Error('No RPC in language repaint')}};
 ctx.window=ctx;vm.createContext(ctx);
 vm.runInContext(dictionary,ctx,{filename:'civil-registry-resources.js'});
 vm.runInContext(source,ctx,{filename:'plateau-etat-civil.js'});
 return{ctx,field,dyn,body,get title(){return title},get html(){return bodyHtml},get network(){return network},setLang:l=>locale=l};
}
test('29 clés identiques et variables conservées dans les neuf langues',()=>{
 const {ctx}=setup('fr');const fr=ctx.RP_I18N_RESOURCES.fr.translation.civilRegistry;
 assert.equal(Object.keys(fr).length,29);
 for(const lang of langs){
  const entries=ctx.RP_I18N_RESOURCES[lang].translation.civilRegistry;
  assert.deepEqual(Object.keys(entries).sort(),Object.keys(fr).sort());
  for(const [key,val] of Object.entries(fr)){
   assert.ok(entries[key],lang+':'+key);
   const vars=v=>(v.match(/\{[a-z]+\}/g)||[]).sort().join(',');
   assert.equal(vars(entries[key]),vars(val),lang+':'+key);
  }
 }
});
test('interface de recherche traduite et IDs de recherche conservés',()=>{
 for(const lang of langs){
  const e=setup(lang);e.ctx.doConsulterEtatCivil();
  const tr=e.ctx.RP_I18N_RESOURCES[lang].translation.civilRegistry;
  assert.equal(e.title,tr.title);
  assert.ok(e.html.includes(tr.instructions));
  assert.ok(e.html.includes(tr.name));
  assert.ok(e.html.includes(tr.search));
  assert.ok(e.html.includes('id="etat-civil-nom"'));
  assert.ok(e.html.includes('id="etat-civil-decennie"'));
  assert.ok(e.html.includes('etatCivilLancerRecherche()'));
 }
});
test('fiches historiques traduites sans changer les noms ni les années',()=>{
 for(const lang of langs){
  const e=setup(lang);
  const fiche=e.ctx.etatCivilConstruireFiche('Pierre Thibault');
  assert.ok(fiche&&fiche.evenements.length>=2,lang);
  const all=fiche.evenements.map(x=>x.texte).join('\n');
  assert.ok(all.includes('Pierre Thibault'),lang);
  assert.ok(all.includes('1898'),lang);
  assert.ok(all.includes('1949'),lang);
  if(lang==='en')assert.ok(all.includes('birth of'),all);
  if(lang==='ar')assert.ok(all.includes('ميلاد'),all);
 }
});
test('bascule à chaud : conserve champ et résultats, sans appel réseau',()=>{
 const e=setup('fr');e.ctx.doConsulterEtatCivil();
 const original=e.html,v=e.field.value;
 e.setLang('ko');for(const callback of e.ctx.RP_I18N_CHANGE_CALLBACKS)callback();
 assert.equal(e.field.value,v);
 assert.equal(e.html,original);
 assert.equal(e.network,0);
 assert.equal(e.dyn.textContent,e.ctx.RP_I18N_RESOURCES.ko.translation.civilRegistry.search);
 assert.equal(e.field.placeholder,e.ctx.RP_I18N_RESOURCES.ko.translation.civilRegistry.name);
 assert.equal(e.title,e.ctx.RP_I18N_RESOURCES.ko.translation.civilRegistry.title);
});
test('ne modifie aucun ordre ni coût ou mutation serveur',()=>{
 assert.match(source,/etat_civil_document_recevoir/);
 assert.match(source,/p_type: 'fiche', p_reference: null, p_pa: 0, p_cost: 0/);
 assert.match(source,/executerReceptionInventaire\(/);
 assert.match(html,/i18n\/civil-registry-resources\.js\?v=20261112/);
 assert.match(html,/plateau-etat-civil\.js\?v=i18n-registre-20261112/);
});
