// Rendus publics et réponses fictives ; aucune session ni écriture serveur.
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),zlib=require('node:zlib'),crypto=require('node:crypto');
const {avecJeu,page,R}=require('./mobile-navigateur.cjs');
const source=fs.readFileSync(path.join(R,'plateau-objets.js'),'utf8');
const archive=fs.readFileSync(path.join(__dirname,'fixtures/i18n-fiches-temoin-7aafbb9f.js.gz'));
assert.equal(crypto.createHash('sha256').update(archive).digest('hex'),'0c3bd1d2f318e3c02947469d7b39413b56c23a635335542e559fa1655b99520e');
const old=zlib.gunzipSync(archive).toString();
const locales=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
const item={resolu:true,generique:'Nom <canonique>',famille:'famille serveur',types:['type serveur'],variante:'Configuration serveur',regime:'reglemente',aucun_effet:false,effets:{hp:5,moral:-2,pa:0,non_cumulable:true,inconnu:'Valeur inconnue'},capacites:['observer_secteur','capacite_inconnue'],consommable:true,equipable:true,encombrement:2,durabilite:{max:3},conditions:{autorite:'serveur'},contraintes:{min:1}};
const commerce={nom:'Nom personnalisé <文>',description:'Description du joueur, jamais traduite.',prix:5.5,devise:'PSK',vendeur:'Vendeur <اسم>',stock:0};
function fonctions(src){const c=vm.createContext({});vm.runInContext(src,c);return c;}
function mots(){const window={RP_I18N_RESOURCES:{}};for(const l of locales)window.RP_I18N_RESOURCES[l]={translation:{}};vm.runInNewContext(fs.readFileSync(path.join(R,'i18n/product-sheet-resources.js'),'utf8'),{window});return window.RP_I18N_RESOURCES;}
test('79 clés complètes dans neuf langues ; toutes les tables officielles correspondent au français',()=>{
 const d=mots(),c=fonctions(source);assert.equal(Object.keys(d.fr.translation.productSheet).length,79);
 for(const l of locales){assert.deepEqual(Object.keys(d[l].translation.productSheet),Object.keys(d.fr.translation.productSheet));for(const v of Object.values(d[l].translation.productSheet))assert.ok(v.trim())}
 for(const [table,prefix]of [['EFFETS','effect'],['CAPACITES','ability'],['REGIMES','status']]){
  for(const [key,label]of Object.entries(vm.runInContext('FICHE_LIBELLES_'+table,c)))assert.equal(d.fr.translation.productSheet[prefix+'_'+key],(prefix==='ability'?'• ':'')+label);
 }
});
test('aucune propriété officielle ajoutée ou modifiée, aucun contenu commercial réécrit',()=>{
 const a=fonctions(old),b=fonctions(source),strip=x=>x.replace(/<[^>]*>/g,'');
 for(const fiche of [null,{resolu:false},{...item,aucun_effet:true},{...item,est_service:true,regime:'inconnu'},item,{...item,effets:{pa:null,hp:false,pa_lendemain:0},capacites:[]}]){
  const before=JSON.stringify(fiche);assert.equal(strip(b.ficheOfficielleHtml(fiche)),strip(a.ficheOfficielleHtml(fiche)));assert.equal(JSON.stringify(fiche),before);
 }
 assert.equal(strip(b.ficheCommercialeHtml(commerce)),strip(a.ficheCommercialeHtml(commerce)));
 assert.deepEqual(JSON.parse(JSON.stringify(b.ficheLignesEffets(item.effets))),JSON.parse(JSON.stringify(a.ficheLignesEffets(item.effets))));
});
async function ouvrir(b,o,width=390,ancien=false){
 const p=await page(b,o,width,950);await p.evaluate(()=>{window.RP_I18N_GAME_ENABLED=true;localStorage.setItem('respublica_language','fr')});
 for(const f of ['i18next.min.js','resources.js','product-sheet-resources.js','plateau-bridge.js','plateau-init.js'])await p.addScriptTag({path:path.join(R,'i18n',f)});
 await p.addScriptTag({content:ancien?old:source});await p.evaluate(({item,commerce})=>{window._fiche=item;window._commerce=commerce;document.getElementById('postes-modal-title').textContent='Fiche produit';document.getElementById('postes-body').innerHTML=ficheCommercialeHtml(commerce)+ficheOfficielleHtml(item)+'<input id="saisie-test" value="saisie conservée"><button onclick="window._commandes++">Action témoin</button>';window._commandes=0;document.getElementById('modal-postes').classList.add('open');RPI18nPlateau.apply(document.getElementById('postes-body'))},{item,commerce});return p;
}
test('vraies fiches : neuf langues à chaud, RTL, données et saisie conservées sur mobile',()=>avecJeu(async(b,o)=>{
 const p=await ouvrir(b,o);for(const width of [360,390,768]){await p.setViewportSize({width,height:950});for(const l of locales){
  await p.evaluate(l=>i18next.changeLanguage(l),l);const r=await p.evaluate(()=>({translated:[...document.querySelectorAll('#postes-body [data-i18n]')].every(e=>e.textContent===i18next.t(e.getAttribute('data-i18n'),{values:JSON.parse(e.getAttribute('data-i18n-values')||'{}')})),dir:document.querySelector('#postes-body [data-i18n]').getAttribute('dir'),item:_fiche,commerce:_commerce,saisie:document.getElementById('saisie-test').value,commands:_commandes,overflow:document.getElementById('postes-body').scrollWidth>document.getElementById('postes-body').clientWidth+1,text:document.getElementById('postes-body').textContent}));
  assert.equal(r.translated,true,l);assert.equal(r.overflow,false,l+' '+width+' débordement');assert.equal(r.dir,l==='ar'?'rtl':null);assert.deepEqual(r.item,item);assert.deepEqual(r.commerce,commerce);assert.equal(r.saisie,'saisie conservée');assert.equal(r.commands,0);assert.ok(r.text.includes('5,5 PSK'));assert.ok(r.text.includes('Nom personnalisé <文>'));assert.ok(r.text.includes('Valeur inconnue'));assert.ok(r.text.includes('capacite_inconnue'));
 }}
 await p.evaluate(async()=>{await i18next.changeLanguage('de');delete i18next.getResourceBundle('de','translation').productSheet.effects;delete i18next.getResourceBundle('fr','translation').productSheet.effects;RPI18nPlateau.apply(document)});
 assert.equal(await p.locator('[data-i18n="productSheet.effects"]').textContent(),'EFFETS RÉELS','clé absente : français originel');await p.close();
}));
test('bureau 1440 : fiches françaises pixel-identiques au main 7aafbb9f',()=>avecJeu(async(b,o)=>{
 const shots=[];for(const ancien of [true,false]){const p=await ouvrir(b,o,1440,ancien);shots.push(await p.locator('#modal-postes .modal-box').screenshot({animations:'disabled'}));fs.writeFileSync('/tmp/hg-fiche-'+ancien+'.png',shots.at(-1));await p.close()}assert.equal(Buffer.compare(...shots),0);
}));
