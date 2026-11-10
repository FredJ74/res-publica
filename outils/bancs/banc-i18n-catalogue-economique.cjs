// Catalogue public, RPC simulées ; aucune commande de jeu exécutée.
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),zlib=require('node:zlib'),crypto=require('node:crypto');
const acorn=require('../vercel/node_modules/acorn'),{avecJeu,page,R}=require('./mobile-navigateur.cjs');
const read=f=>fs.readFileSync(path.join(R,f),'utf8'),src=read('plateau-actions-illegales-rumeurs.js');
const a=src.indexOf('function texteCommerceMenu('),b=src.indexOf('// =====================\n// FAIRE DES ACHATS',a),code=src.slice(a,b);
const archive=fs.readFileSync(path.join(__dirname,'fixtures/i18n-carte-temoin-7aafbb9f.js.gz')),old=zlib.gunzipSync(archive).toString();
assert.equal(crypto.createHash('sha256').update(archive).digest('hex'),'f162981249c288d2f28296ddd42de7eaa4c24a7dfe3d69dddd098e7abd0f5c5a');
const locales=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
const recipe={id:'porte_cle_palais_luthecia',label:'Porte-clé du Palais présidentiel',desc:'Souvenir représentant le Palais présidentiel de Luthécia en miniature.',materiaux:{metal:1,fruits_legumes:2},effets:{},image:null};
const materials={metal:{label:'Métal'},fruits_legumes:{label:'Fruits & légumes'}};
function catalogue(){const window={RP_I18N_RESOURCES:{}};for(const l of locales)window.RP_I18N_RESOURCES[l]={translation:{}};vm.runInNewContext(read('i18n/economic-catalog-resources.js'),{window});return window;}
test('63 clés dans neuf langues, texte français exactement égal aux catalogues métier',()=>{
 const w=catalogue(),fr=w.RP_I18N_RESOURCES.fr.translation.economicCatalog,found={};
 for(const[file,names]of [['data.js',['RESSOURCES_ECONOMIE']],['plateau-actions-illegales-rumeurs.js',['RECETTES_ALIMENTAIRES','PRODUITS_MARCHE']]]){
  for(const n of acorn.parse(read(file),{ecmaVersion:'latest'}).body)if(n.type==='VariableDeclaration')for(const d of n.declarations)if(names.includes(d.id.name))for(const p of d.init.properties){const id=p.key.name||p.key.value;if(id.includes('sovarka')||(p.value.properties||[]).some(f=>f.key&&f.key.name==='paysAutorises'&&f.value.type==='ArrayExpression'&&f.value.elements.some(e=>e.value==='soviet')))continue;for(const f of p.value.properties||[])if(['label','desc'].includes(f.key.name)&&f.value.type==='Literal')found[(d.id.name==='RESSOURCES_ECONOMIE'?'material':'product')+'_'+id+'_'+f.key.name]=f.value.value;}
 }
 assert.equal(Object.keys(fr).length,63);assert.deepEqual(JSON.parse(JSON.stringify(fr)),found);
 for(const l of locales){const d=w.RP_I18N_RESOURCES[l].translation.economicCatalog;assert.deepEqual(Object.keys(d),Object.keys(fr));for(const v of Object.values(d))assert.ok(v.trim())}
 const api=w.RPEconomicCatalogI18n;assert.equal(api.key('product',recipe.id,'label',recipe.label),'economicCatalog.product_'+recipe.id+'_label');
 assert.equal(api.key('product',recipe.id,'label','Nom personnalisé'),null);assert.equal(api.key('product','autre','label',recipe.label),null);
 assert.equal(api.markup('product','autre','label','<privé>'),'&lt;privé&gt;');assert.equal(api.text('product',recipe.id,'label',recipe.label),recipe.label,'sans moteur : français');
});
async function ouvrir(b,o,w=390,ancien=false){
 const p=await page(b,o,w,950);await p.evaluate(()=>{window.RP_I18N_GAME_ENABLED=true;localStorage.setItem('respublica_language','fr')});
 for(const f of ['i18next.min.js','resources.js','economic-catalog-resources.js','product-sheet-resources.js','commerce-menu-resources.js','plateau-bridge.js','plateau-init.js'])await p.addScriptTag({path:path.join(R,'i18n',f)});
 await p.addScriptTag({content:read('plateau-objets.js')});await p.addScriptTag({content:ancien?old:code});
 await p.evaluate(({recipe,materials})=>{
  window.state={country:'republic',currentCity:'capitale',char:{name:'Fictif'},inventory:[]};window.COUNTRIES={republic:{cur:'PSK'}};window.RESSOURCES_ECONOMIE=materials;window.BUILDINGS={marche:{name:'Lieu original'}};window._recipe=recipe;window._reads=0;window._costs=[];
  window.resoudreProduitCommerce=id=>id===recipe.id?recipe:null;window.deduireCoutOrdre=async c=>{_costs.push(c);return {ok:true}};window.chargerCommerce=async()=>{_reads++;return {carte:[recipe.id],stockProduits:{[recipe.id]:0},parametres:{prixVente:{[recipe.id]:5.5}}}};window.commercePeutProduire=()=>false;window.recetteAutoriseePourCommerce=()=>true;window.sbObjetFicheOfficielle=async()=>{_reads++;return {resolu:true,generique:'Objet canonique',famille:'Souvenir',aucun_effet:true}};
 },{recipe,materials});await p.evaluate(()=>doConsulterCarteCommerce('marche','marche','salle',0,0));return p;
}
test('carte réelle : produits, composition, stock zéro et permissions conservés en neuf langues',()=>avecJeu(async(b,o)=>{
 const p=await ouvrir(b,o);const before=await p.evaluate(()=>({state:JSON.stringify(state),recipe:JSON.stringify(_recipe),costs:_costs,reads:_reads,buttons:[...document.querySelectorAll('#postes-body button')].map(e=>[e.getAttribute('onclick'),e.disabled])}));
 for(const w of [360,390,768]){await p.setViewportSize({width:w,height:950});for(const l of locales){await p.evaluate(l=>i18next.changeLanguage(l),l);const r=await p.evaluate(()=>({state:JSON.stringify(state),recipe:JSON.stringify(_recipe),costs:_costs,reads:_reads,buttons:[...document.querySelectorAll('#postes-body button')].map(e=>[e.getAttribute('onclick'),e.disabled]),markers:[...document.querySelectorAll('#postes-body [data-i18n]')].every(e=>e.textContent===i18next.t(e.getAttribute('data-i18n'))),text:document.getElementById('postes-body').textContent,overflow:document.getElementById('postes-body').scrollWidth>document.getElementById('postes-body').clientWidth+1}));for(const k of Object.keys(before))assert.deepEqual(r[k],before[k],k);assert.equal(r.markers,true);assert.ok(r.text.includes('5,5 PSK'));assert.equal(r.overflow,false,l+' '+w);}}
 await p.close();
}));
test('fiche réelle : description canonique traduite, noms personnalisés et contenu libre intacts',()=>avecJeu(async(b,o)=>{
 const p=await ouvrir(b,o);await p.evaluate(()=>ouvrirFicheProduitCommerce('marche','marche','salle',_recipe.id));
 const calls=await p.evaluate(()=>({reads:_reads,costs:_costs}));for(const l of locales){await p.evaluate(l=>i18next.changeLanguage(l),l);assert.equal(await p.locator('[data-i18n="economicCatalog.product_porte_cle_palais_luthecia_desc"]').textContent(),await p.evaluate(()=>i18next.t('economicCatalog.product_porte_cle_palais_luthecia_desc')));assert.deepEqual(await p.evaluate(()=>({reads:_reads,costs:_costs})),calls)}
 await p.evaluate(()=>{document.getElementById('postes-body').innerHTML=ficheCommercialeHtml({catalogueId:_recipe.id,nom:'Nom de joueur <عربي>',description:'Texte libre du joueur',prix:0,stock:0,devise:'PSK'});RPI18nPlateau.apply(document)});
 assert.equal(await p.locator('#postes-body [data-i18n^="economicCatalog."]').count(),0);assert.ok((await p.locator('#postes-body').textContent()).includes('Nom de joueur <عربي>'));await p.close();
}));
test('matières du commerce PJ : bascule sans perdre la quantité ni relire le serveur',()=>avecJeu(async(b,o)=>{
 const p=await ouvrir(b,o);await p.addScriptTag({content:read('plateau-commerce-pj.js')});await p.evaluate(()=>{commercePjModale('Matières','<b>'+commercePjMatiereHtml('fruits_legumes')+'</b><input id="quantite-test" value="7">');});
 const calls=await p.evaluate(()=>_reads);for(const l of locales){await p.evaluate(l=>i18next.changeLanguage(l),l);assert.equal(await p.locator('#postes-body b').textContent(),await p.evaluate(()=>i18next.t('economicCatalog.material_fruits_legumes_label')));assert.equal(await p.inputValue('#quantite-test'),'7');assert.equal(await p.evaluate(()=>_reads),calls)}await p.close();
}));
test('carte française à 1440 : mêmes pixels que main 7aafbb9f',()=>avecJeu(async(b,o)=>{
 const shots=[];for(const ancien of [true,false]){const p=await ouvrir(b,o,1440,ancien);shots.push(await p.locator('#modal-postes .modal-box').screenshot({animations:'disabled'}));fs.writeFileSync('/tmp/hg-carte-'+ancien+'.png',shots.at(-1));await p.close()}assert.equal(Buffer.compare(...shots),0);
}));
