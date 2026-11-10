// Verdicts fictifs : contrat des actions et valeurs du serveur conservés.
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),zlib=require('node:zlib'),crypto=require('node:crypto');
const R=path.resolve(__dirname,'../..'),read=f=>fs.readFileSync(path.join(R,f),'utf8'),i18next=require('../../i18n/i18next.min.js');
const src=read('plateau-actions-illegales-rumeurs.js'),a=src.indexOf('function texteProductionCommerce('),b=src.indexOf('\nasync function chargerArmurerieLocale(',a),code=src.slice(a,b);
const archive=fs.readFileSync(path.join(__dirname,'fixtures/i18n-production-temoin-7aafbb9f.js.gz')),old=zlib.gunzipSync(archive).toString();
assert.equal(crypto.createHash('sha256').update(archive).digest('hex'),'374315d4e797f5688bd17835c16d70da2885f3311e9a12b0c9dfd9b667293eee');
const locales=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
async function scenario(locale,result,ancien=false){
 const window={};for(const f of ['resources.js','commerce-production-resources.js'])vm.runInNewContext(read('i18n/'+f),{window});
 const engine=i18next.createInstance();await engine.init({lng:locale,fallbackLng:'fr',resources:window.RP_I18N_RESOURCES,interpolation:{escapeValue:false}});
 window.RPPlateauI18n={translate:(key,vars)=>engine.t(key,vars)};
 const calls=[],toasts=[],journal=[],recipe={label:'Produit <canonique>',pa:2},state={char:{name:'Fixture'},country:'republic',currentCity:'capitale',pa:0,liquide:0};
 const c=vm.createContext({window,state,BUILDINGS:{marche:{name:'Lieu <original>'}},RESSOURCES_ECONOMIE:{bois:{label:'Bois'}},document:{getElementById:()=>({classList:{remove:n=>calls.push(['close',n])}})},resoudreProduitCommerce:id=>{calls.push(['recipe',id]);return recipe},produireRecetteCommerce:async(...args)=>{calls.push(['command',...args]);return structuredClone(result)},nomProduitCommerce:(_,name)=>name,updateUI:()=>calls.push(['ui']),showToast:(...args)=>toasts.push(args),addJournalEntry:(...args)=>journal.push(args),doConsulterCarteCommerce:(...args)=>calls.push(['refresh',...args])});
 vm.runInContext(ancien?old:code,c);await c.doProduireRecetteCommerceUI('marche','marche','salle','produit');
 return {calls:JSON.parse(JSON.stringify(calls)),toasts,journal,state:JSON.stringify(state),dict:window.RP_I18N_RESOURCES[locale].translation.commerceProduction,engine,c};
}
test('9 clés, paramètres et montants littéraux identiques dans neuf langues',async()=>{
 const {dict}=await scenario('fr',{ok:false,raison:'introuvable'});assert.equal(Object.keys(dict).length,9);for(const l of locales){const s=await scenario(l,{ok:false,raison:'introuvable'});assert.deepEqual(Object.keys(s.dict),Object.keys(dict));for(const k of Object.keys(dict)){assert.ok(s.dict[k].trim());assert.deepEqual(s.dict[k].match(/{{[^}]+}}/g)?.sort(),dict[k].match(/{{[^}]+}}/g)?.sort())}assert.match(s.dict.margin,/25 FR/)}
});
const reasons={production_non_autorisee:'unauthorized',marge_pnj_insuffisante:'margin',recette_non_autorisee:'recipe',pa_insuffisants:'pa',stock_matiere_insuffisant:'material',caisse_insuffisante:'cash',stock_plein:'full',introuvable:null,inconnu:null};
for(const locale of locales)test('production '+locale+' : refus, succès et zéros sans mutation ni appel supplémentaire',async()=>{
 for(const result of [...Object.keys(reasons).map(raison=>({ok:false,raison,matiere:'bois'})),{ok:true,portions:5,salaire:12.5},{ok:true,portions:0,salaire:0}]){
  const a=await scenario('fr',result,true),b=await scenario(locale,result);assert.deepEqual(b.calls,a.calls);assert.equal(b.state,a.state);assert.equal(b.calls.filter(x=>x[0]==='command').length,1);
  if(locale==='fr'){assert.deepEqual(b.toasts,a.toasts);assert.deepEqual(b.journal,a.journal)}
  if(!result.ok){const k=reasons[result.raison];assert.equal(b.toasts[0][0],'Production impossible');assert.equal(b.toasts[0][1],k?b.engine.t('commerceProduction.'+k,{values:{pa:2,material:'Bois'}}):'');assert.equal(b.journal.length,0);assert.equal(b.calls.some(x=>x[0]==='refresh'),false)}
  else{assert.equal(b.toasts[0][1],b.engine.t('commerceProduction.served',{values:{product:'Produit <canonique>',portions:result.portions,salary:result.salaire}}));assert.equal(b.journal[0][0],b.engine.t('commerceProduction.journal',{values:{product:'Produit <canonique>',portions:result.portions,place:'Lieu <original>'}}));assert.equal(b.calls.filter(x=>x[0]==='refresh').length,1)}
 }
});
test('clé absente ou traduction incomplète : texte français exact, pas de clé technique',async()=>{
 const {c}=await scenario('de',{ok:false,raison:'introuvable'});c.window.RPPlateauI18n.translate=key=>key;assert.equal(c.texteProductionCommerce('inconnu','Texte français'),'Texte français');c.window.RPPlateauI18n.translate=()=> '{{values.absent}}';assert.equal(c.texteProductionCommerce('served','Texte français'),'Texte français');
});
const {avecJeu,page}=require('./mobile-navigateur.cjs');
test('Chromium : langue changée pendant la commande, valeurs serveur et diagnostic canonique',()=>avecJeu(async(b,o)=>{
 const p=await page(b,o,390,900);await p.evaluate(()=>{window.RP_I18N_GAME_ENABLED=true;localStorage.setItem('respublica_language','fr')});
 for(const f of ['i18next.min.js','resources.js','toast-resources.js','commerce-production-resources.js','plateau-bridge.js','plateau-init.js'])await p.addScriptTag({path:path.join(R,'i18n',f)});
 const core=read('plateau-core.js'),start=core.indexOf('function showToast('),end=core.indexOf('// =====================',start);
 await p.addScriptTag({content:core.slice(start,end)+'\n'+code});
 await p.evaluate(()=>{
  window.state={country:'republic',currentCity:'capitale',liquide:0,pa:0};window._calls=0;window._refresh=0;window._incidents=[];window._journal=[];
  window.BUILDINGS={marche:{name:'Lieu original'}};window.RESSOURCES_ECONOMIE={bois:{label:'Bois'}};window.resoudreProduitCommerce=()=>({label:'Produit original',pa:2});window.nomProduitCommerce=(_,x)=>x;
  window.produireRecetteCommerce=()=>{_calls++;return new Promise(r=>window._reply=r)};window.updateUI=()=>{};window.noterIncidentSession=(...x)=>_incidents.push(x);window.addJournalEntry=(...x)=>_journal.push(x);window.doConsulterCarteCommerce=()=>{_refresh++};window._pending=doProduireRecetteCommerceUI('marche','marche','salle','produit');
 });
 await p.evaluate(()=>i18next.changeLanguage('ar'));await p.evaluate(()=>_reply({ok:true,portions:5,salaire:12.5}));await p.evaluate(()=>_pending);
 assert.equal(await p.locator('#toast-result').textContent(),await p.evaluate(()=>i18next.t('toastTitles.productionSucceeded')));
 assert.equal(await p.locator('#toast-sub').textContent(),await p.evaluate(()=>i18next.t('commerceProduction.served',{values:{product:'Produit original',portions:5,salary:12.5}})));
 assert.deepEqual(await p.evaluate(()=>[_calls,_refresh,state.pa,state.liquide]),[1,1,0,0]);
 await p.evaluate(()=>{window._pending=doProduireRecetteCommerceUI('marche','marche','salle','produit')});await p.evaluate(()=>_reply({ok:false,raison:'caisse_insuffisante'}));await p.evaluate(()=>_pending);
 assert.deepEqual(await p.evaluate(()=>_incidents),[['notification','Production impossible']],'le diagnostic reste français');assert.deepEqual(await p.evaluate(()=>[_calls,_refresh,state.pa,state.liquide]),[2,1,0,0]);await p.close();
}));
