'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.join(__dirname,'../..');
const read=f=>fs.readFileSync(path.join(root,f),'utf8');
const ids=[
  'acte_officiel','demander_naturalisation','demander_mariage','officialiser_mariage',
  'deposer_candidature','nommer_commissaire','revoquer_commissaire',
  'gerer_candidature_maire_adjoint','revoquer_maire_adjoint',
  'gerer_candidature_directeur_entrepot','nommer_directeur_entrepot',
  'revoquer_directeur_entrepot','nommer_directeur_pharma','revoquer_directeur_pharma',
  'nommer_directeur_tabac_alcools','revoquer_directeur_tabac_alcools',
  'nommer_directeur_raffinerie','revoquer_directeur_raffinerie',
  'prix_chantier','taux_chantier','receptionner_chantier'
];
const langs=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
function load(language='en', enabled=true){
 const win={RP_I18N_GAME_ENABLED:enabled,RPPlateauI18n:{language:()=>language}};
 const context=vm.createContext({window:win});
 for(const f of ['i18n/resources.js','i18n/orders-resources.js','i18n/ordres.js','i18n/municipal-ui-resources.js'])
  vm.runInContext(read(f),context,{filename:f});
 win.i18next={t:(key,{lng,defaultValue}={})=>key.split('.').reduce((v,k)=>v?.[k],win.RP_I18N_RESOURCES[lng].translation)??defaultValue};
 return {context,win};
}
test('les 21 commandes nouvellement localisées correspondent aux sources et aux neuf catalogues',()=>{
 const {win}=load('en');
 const source=read('plateau-politique.js')+'\n'+read('plateau-construction-commandes.js');
 const canonical=win.RP_I18N_RESOURCES.fr.translation.orders;
 assert.equal(Object.keys(canonical).length,420); // consommer_buvette supprimé ; +4 Héros du Travail et boîte du Parti (13/11)
 for(const id of ids){
  const escaped=id.replace(/[.*+?^${}()|[\]\\]/g,'\\$&');
  assert.match(source,new RegExp('fn\\s*:\\s*[\\x27\\x22]'+escaped+'[\\x27\\x22]\\s*,\\s*label\\s*:\\s*[\\x27\\x22]'));
  assert.equal(typeof canonical[id],'string',id+': français');
  for(const lang of langs){
   const word=win.RP_I18N_RESOURCES[lang].translation.orders[id];
   assert.ok(typeof word==='string'&&word.trim(),lang+'/'+id);
   const order=Object.freeze({fn:id,label:canonical[id],pa:2,cost:123,requiresPost:'min_just'});
   assert.equal(win.RPOrderI18n.label(order,win.i18next,lang),word,lang+'/'+id);
   assert.equal(win.RPOrderI18n.label({...order,label:'Autre opération'},win.i18next,lang),'Autre opération');
   assert.equal(order.cost,123);assert.equal(order.pa,2);assert.equal(order.requiresPost,'min_just');
  }
 }
});
test('l état civil traduit les boutons réellement visibles et préserve les ordres envoyés au serveur',()=>{
 const source=read('plateau-politique.js');
 const begin=source.indexOf('const DEMARCHES_ETAT_CIVIL_PAR_BATIMENT =');
 const end=source.indexOf('// =====================\n// =====================\n// CALENDRIER',begin);
 assert.ok(begin>=0 && end>begin);
 for(const locale of ['fr','en','ko','ar']){
  const {context,win}=load(locale,true);
  const nodes={
   'postes-modal-title':{textContent:''},'postes-body':{innerHTML:''},
   'modal-postes':{classList:{add() {}}}
  };
  Object.assign(context,{
   state:{currentBuilding:'mairie-capitale',char:{country:'republic'}},
   COUNTRIES:{republic:{cur:'FR'}},
   document:{getElementById:k=>nodes[k]}
  });
  vm.runInContext(source.slice(begin,end),context);
  vm.runInContext('ouvrirEtatCivil()',context);
  const html=nodes['postes-body'].innerHTML;
  const canon=win.RP_I18N_RESOURCES[locale].translation.orders;
  const expected=locale==='fr'?'Demander un acte officiel':canon.acte_officiel;
  assert.ok(html.includes(expected),locale+' : libellé dans le HTML');
  assert.match(html,/doOrder\('acte_officiel',1,50,'Demander un acte officiel'/);
  assert.match(html,/doOrder\('officialiser_mariage',2,200,'Officialiser un mariage'/);
  assert.equal(nodes['postes-modal-title'].textContent,
   locale==='fr'?'État civil':win.RP_I18N_RESOURCES[locale].translation.municipalUi.civilStatusTitle);
  assert.ok(html.includes(win.RP_I18N_RESOURCES[locale].translation.municipalUi.comingSoon));
 }
});
test('drapeau fermé : textes français et interfaces administratives inchangés',()=>{
 const {context,win}=load('ko',false);
 assert.equal(win.RPMunicipalI18n.label('civilStatusTitle','État civil'),'État civil');
 assert.equal(win.RPMunicipalI18n.label('unknown','Original'),'Original');
 assert.equal(win.RPMunicipalI18n.labelHtml('manageApplications','Gerer les candidatures recues'),
  'Gerer les candidatures recues');
});
test('les boutons de nomination ne modifient aucun appel métier',()=>{
 const source=read('plateau-politique.js');
 assert.match(source,/ouvrirGestionCandidatures\(\['/);
 assert.match(source,/ouvrirNominerPosteNomme\('/);
 assert.match(source,/ouvrirRevoquerPosteNomme\('/);
 assert.match(source,/libelleMunicipalI18n\('manageApplications'/);
 assert.match(source,/libelleMunicipalI18n\('dismissHolder'/);
 assert.match(source,/window\.RPOrderI18n\.labelHtml\(d,/);
});
