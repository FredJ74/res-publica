'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.join(__dirname,'../..');
const read=name=>fs.readFileSync(path.join(root,name),'utf8');
const source=read('plateau-navigation.js');
const ctx=vm.createContext({window:{RP_I18N_GAME_ENABLED:true}});
for(const file of ['i18n/resources.js','i18n/navigation-resources.js'])vm.runInContext(read(file),ctx,{filename:file});
const w=ctx.window;
const languages=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
const canonical=w.RP_I18N_RESOURCES.fr.translation.navigation;
test('titres du plan, légendes, transports et contextes présents dans les neuf langues',()=>{
 assert.ok(Object.keys(canonical).length >= 29, 'catalogue étendu aux repères du plan');
 for(const key of ['planTitlePrefix','planOfCity','hereSuffix','hereText','onStreet']) assert.ok(Object.hasOwn(canonical,key),key);
 assert.deepEqual(Object.keys(w.RP_I18N_LANGUAGES),languages);
 for(const lang of languages){
  const d=w.RP_I18N_RESOURCES[lang].translation.navigation;
  assert.deepEqual(Object.keys(d).sort(),Object.keys(canonical).sort(),lang+': clés');
  for(const [key,text] of Object.entries(d)){
   assert.ok(typeof text==='string' && text.trim(),lang+': '+key);
   // Certains mots sont identiques dans plusieurs langues (information, destination).
   assert.ok(!text.includes('undefined'),lang+': pas de clé invalide');
  }
 }
});
test('réconciliation française exacte, repli sans catalogue et échappement HTML',()=>{
 for(const lang of languages){
  w.RPPlateauI18n={language:()=>lang};
  for(const [key,original] of Object.entries(canonical)){
   const expected=w.RP_I18N_RESOURCES[lang].translation.navigation[key];
   assert.equal(w.RPNavigationI18n.label(key,original),expected,lang+': '+key);
   assert.equal(w.RPNavigationI18n.label(key,'Source différente'), 'Source différente',
     lang+': texte métier ne correspond plus');
  }
  const html=w.RPNavigationI18n.labelHtml('foreignTravelHelp',canonical.foreignTravelHelp);
  assert.ok(!html.includes('<script'),lang+': pas de HTML dans le plan');
 }
 assert.equal(w.RPNavigationI18n.label('cle_inconnue','Texte original'),'Texte original');
 w.RPPlateauI18n={language:()=>'en'};
 w.RP_I18N_GAME_ENABLED=false;
 assert.equal(w.RPNavigationI18n.label('transportTitleTrain',canonical.transportTitleTrain),
   canonical.transportTitleTrain,'pas de traduction si beta fermée');
 w.RP_I18N_GAME_ENABLED=true;
});
test('la navigation réelle utilise les libellés sans modifier trajet, montant et validation',()=>{
 const page=read('plateau.html');
 assert.ok(page.includes('i18n/navigation-resources.js'));
 assert.ok(page.indexOf('i18n/navigation-resources.js')<page.indexOf('i18n/plateau-init.js'));
 for(const fragment of [
  "rpNavHtml('youAreHere'",
  "rpNavHtml('foreignTravelHelp'",
  "rpNavHtml('nationalInstitutions'",
  "rpNavHtml('buildings'",
  "rpNav('capitalPrefix'",
  "rpNav('transportTitle'+nomTransport",
  "rpNavHtml('transportDesc'+nomTransport",
  "rpNavHtml('groupPriceNote'",
  "rpNavHtml('destinationEmpire'",
  "rpNavHtml('capital'",
  "rpNavHtml('city'"
 ])assert.ok(source.includes(fragment),fragment);
 for(const preserved of [
  "ordre:'prendre_train'","ordre:'prendre_bus_taxi'","ordre:'prendre_avion'","ordre:'prendre_bateau'",
  "pa:2, cost:75","pa:1, cost:150","pa:2, cost:300","pa:5, cost:100",
  "confirmerTransport(","state.currentCity","ouvrirPlanVille(countryId, cityId, true)"
 ])assert.ok(source.includes(preserved),preserved);
});
