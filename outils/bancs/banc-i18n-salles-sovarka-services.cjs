'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const data=fs.readFileSync(path.join(root,'data.js'),'utf8');
const nav=fs.readFileSync(path.join(root,'plateau-navigation.js'),'utf8');
const langs=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
const entries=[
 ["stade","terrain","Terrain — Dynamo de Novomirsk","dynamoPitch"],
 ["stade","vestiaires","Vestiaires — Dynamo de Novomirsk","dynamoChangingRooms"],
 ["stade","buvette","Buvette des tribunes","dynamoKiosk"],
 ["stade","guichet_paris","Bookmaker du Dynamo","dynamoBookmaker"],
 ["stade","siege_supporters","Club des supporters du Dynamo","dynamoFanClub"],
 ["stade","boutique","Boutique officielle du Dynamo","dynamoStore"],
 ['musee-novomirsk','hall',"Hall d'accueil",'novoMuseumHall'],
 ['musee-novomirsk','salle_criminels','Salle des Grands Criminels Novomirskois','novoMuseumCriminals'],
 ['musee-novomirsk','salle_maires','Salle des Présidents du Soviet municipal','novoMuseumMayors'],
 ['musee-novomirsk','salle_personnalites','Salle des Héros du Peuple','novoMuseumHeroes'],
 ['musee-novomirsk','salle_entrepreneurs','Salle des Grands Bâtisseurs de la Production','novoMuseumBuilders'],
 ['musee-novomirsk','salle_organisations','Salle des Organisations Novomirskoises','novoMuseumOrgs'],
 ['musee-novomirsk','salle_plumes','Salle des Plumes Novomirskoises','novoMuseumWriters'],
 ['musee-novomirsk','salle_honneur_militaire',"Salle d'Honneur Militaire",'novoMuseumMilitary'],
 ['musee-novomirsk','salle_unions','Salle des Unions Célèbres','novoMuseumUnions'],
 ['musee-novomirsk','salle_scandales','Salle des Scandales et Affaires','novoMuseumScandals'],
 ['garage-novomirsk','atelier_garage','Atelier','novoGarageWorkshop'],
 ['salon-coiffure-novomirsk','salon_coiffure','Salon','novoHairSalon'],
 ['pharmacie-officielle-novomirsk','comptoir_pharmacie','Comptoir','novoPharmacyCounter'],
 ['poissonniere-novomirsk','etal_poissonniere','Étal','novoFishStall'],
 ['station-service-krasnov','boutique_station','Boutique','krasnovFuelShop'],
 ['siege-renseignement','accueil_renseignement','Accueil','intelReception'],
 ['siege-renseignement','salle_ecoutes','Salle des Écoutes','intelListeningRoom'],
 ['siege-renseignement','salle_interrogatoire_renseignement',"Salle d'Interrogatoire",'intelInterrogationRoom'],
 ['entrepot-logistique-novomirsk','salle_ventes','Salle des Ventes','novoWarehouseSales'],
 ['entrepot-logistique-novomirsk','bureau_direction','Bureau de Direction','novoWarehouseDirector']
];
let locale='fr';
const win={RPPlateauI18n:{language:()=>locale}};
win.i18next={t:(key,{lng,defaultValue}={})=>key.split('.').reduce((v,k)=>v?.[k],win.RP_I18N_RESOURCES[lng].translation)??defaultValue};
const ctx=vm.createContext({window:win});
for(const file of ['resources.js','room-resources.js'])
 vm.runInContext(fs.readFileSync(path.join(root,'i18n',file),'utf8'),ctx,{filename:file});
test('26 salles contextualisées avec intitulés canoniques du socle et surcharges',()=>{
 const environment=vm.createContext({console,window:{},state:{country:'soviet',currentCity:'capitale'}});
 vm.runInContext(data,environment);
 const defs=vm.runInContext('BUILDINGS',environment);
 const world=vm.runInContext('WORLD',environment);
 for(const [building,room,original] of entries){
  const local=building==='station-service-krasnov'?world.soviet.ville_b:world.soviet.capitale;
  const localContext=local.buildingContext?.[building];
  const expected=localContext?.roomOverrides?.[room]?.name ||
    localContext?.roomsExtra?.[room]?.name || defs[building]?.rooms?.[room]?.name;
  assert.equal(expected,original,building+'/'+room+': intitulé canonique divergent');
 }
});
test('26 salles dans neuf langues, sans interférence entre bâtiments homonymes',()=>{
 assert.equal(entries.length,26);
 for(const lang of langs){
  locale=lang;
  const dict=win.RP_I18N_RESOURCES[lang].translation.extraRooms;
  assert.equal(Object.keys(dict).length,26,lang+': nombre de clés');
  for(const [building,room,original,key] of entries){
   assert.ok(typeof dict[key]==='string'&&dict[key].trim(),lang+'/'+key);
   assert.equal(win.RPRoomI18n.label(building,room,original),dict[key],lang+'/'+key);
   assert.equal(win.RPRoomI18n.label('autre-edifice',room,original),original,'ailleurs inchangé');
   assert.equal(win.RPRoomI18n.label(building,room,original+' - variante'),original+' - variante','variante inchangée');
  }
 }
});
test('les libellés HTML sont échappés sans modifier la navigation ni les ordres',()=>{
 locale='en';
 const dict=win.RP_I18N_RESOURCES.en.translation.extraRooms;
 const before=dict.novoMuseumHall;
 dict.novoMuseumHall='<img src=x onerror=alert(1)> & test';
 const html=win.RPRoomI18n.labelHtml('musee-novomirsk','hall',"Hall d'accueil");
 assert.ok(html.includes('&lt;img')&&!html.includes('<img'));
 assert.ok(html.includes('&amp;'));
 dict.novoMuseumHall=before;
 assert.ok(nav.includes('RPRoomI18n.labelHtml(buildingId, roomId, tabName)'));
 assert.ok(nav.includes('RPRoomI18n.label(buildingId, roomId, nomPieceAffiche)'));
});
