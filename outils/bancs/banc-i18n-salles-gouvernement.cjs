'use strict';
/* Salle du Conseil de Sovarka : test de localisation purement visuelle. */
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const html=fs.readFileSync(path.join(root,'plateau.html'),'utf8');
const nav=fs.readFileSync(path.join(root,'plateau-navigation.js'),'utf8');
const win={};
let locale='fr';
win.RPPlateauI18n={language:()=>locale};
win.i18next={t:(key,{lng,defaultValue}={})=>key.split('.').reduce((x,k)=>x?.[k],win.RP_I18N_RESOURCES?.[lng]?.translation)??defaultValue};
const ctx=vm.createContext({window:win});
for(const name of ['resources.js','room-resources.js'])
 vm.runInContext(fs.readFileSync(path.join(root,'i18n',name),'utf8'),ctx,{filename:name});
const source={
 bureaux:'Bureau du Président du Conseil du Peuple',
 salle_conseil:'Salle du Conseil du Peuple',
 salle_presse:'Salle de Presse',
 archives_gouv:'Archives Gouvernementales',
 bureau_min_int:'Bureau - Ministre de la Sécurité du Peuple',
 bureau_min_fin:"Bureau - Ministre de l'Économie collective",
 bureau_min_just:'Bureau - Ministre de la Justice prolétarienne',
 bureau_min_def:'Bureau - Ministre de la Défense de la Patrie',
 bureau_min_info:'Bureau - Ministre de la Vérité officielle',
 bureau_min_ae:"Bureau - Ministre de l'Amitié entre les Peuples",
 accueil_mairie:'Accueil',
 bureau_maire_local:'Bureau du Maire',
 bureau_maire_adjoint:'Bureau du Maire Adjoint',
 accueil_ambassades_novomirsk:'Accueil du Palais des Ambassades',
 salle_reception:'Salle de Réception',
 bureau_republia_novomirsk:'Ambassade de Républia',
 bureau_khalija_novomirsk:"Ambassade d'Al-Khalija",
 bureau_estado_novomirsk:"Ambassade d'El Estado",
 magasin:'Magasin',
 accueil_police:'Accueil',
 prison:'Cellules de garde a vue',
 bureau_commissaire:'Bureau du Commissaire',
 marche_ext:'Etals du marche',
 accueil:'Accueil',
 restaurant:'Salle du Restaurant',
 bar:'Bar',
 chambres:'Chambres',
 suite_privee:'Suite Privée — Local à louer',
 suite_presidentielle:'Suite Présidentielle — Local à louer',
 accueil_banque:'Accueil',
 coffre_privatif:'Coffre Privatif — Local à louer',
 bureau_prive:'Bureau prive',
 accueil_notaire:'Accueil',
 bureau_successions:'Bureau des Successions',
 bureau_contrats:'Bureau des Contrats',
 archives_notariales:'Archives Notariales',
 amphi:'Amphitheatre',
 salle_reunion:'Salle de Réunion'
};
const serviceBuilding={
 accueil:'hotel-republica',restaurant:'hotel-republica',bar:'hotel-republica',
 chambres:'hotel-republica',suite_privee:'hotel-republica',suite_presidentielle:'hotel-republica',
 accueil_banque:'banque-nationale',coffre_privatif:'banque-nationale',bureau_prive:'banque-privee',
 accueil_notaire:'office-notarial',bureau_successions:'office-notarial',
 bureau_contrats:'office-notarial',archives_notariales:'office-notarial',
 amphi:'universite',salle_reunion:'universite'
};
test('neuf traductions de trente-huit salles, avec repli français explicite',()=>{
 assert.equal(Object.keys(win.RP_I18N_LANGUAGES).length,9);
 for(const lang of Object.keys(win.RP_I18N_LANGUAGES)){
  locale=lang;
  const rooms=win.RP_I18N_RESOURCES[lang].translation.rooms;
  assert.deepEqual(Object.keys(rooms).sort(),Object.keys(source).sort());
  for(const [room,original] of Object.entries(source)){
   assert.equal(typeof rooms[room],'string');
   assert.ok(rooms[room].trim(),lang+': '+room);
   assert.equal(win.RPRoomI18n.label(serviceBuilding[room]|| (room==='magasin'?'armurerie':['accueil_police','prison','bureau_commissaire'].includes(room)?'commissariat':room==='marche_ext'?'marche':room.includes('maire')||room==='accueil_mairie'?'mairie':room==='salle_reception'||room.includes('ambassades_novomirsk')||room.startsWith('bureau_republia_novomirsk')||room.startsWith('bureau_khalija_novomirsk')||room.startsWith('bureau_estado_novomirsk')?'palais-ambassades-novomirsk':'palais-gouvernement'),room,original),rooms[room]);
  }
 }
});
test('une autre pièce, un nom contextuel ou une autre institution garde son nom original',()=>{
 locale='ru';
 for(const [building,room,original] of [
  ['palais-presidentiel','bureaux',source.bureaux],
  ['palais-gouvernement','bureaux','Bureau du Premier Ministre'],
  ['palais-gouvernement','salle_conseil','Salle du Conseil'],
  ['palais-gouvernement','salle_presse','Salle de presse — Jean Jaaj'],
  ['palais-gouvernement','hall',"Hall d'entrée"],
  ['armurerie','magasin','Boutique privée'],
  ['marché','magasin','Magasin'],
  ['armurerie','hall','Magasin'],
  ['commissariat','accueil_police','Accueil du poste de garde'],
  ['marche','marche_ext','Marché couvert'],
  ['mairie','accueil_police','Accueil']
 ]){
  assert.equal(win.RPRoomI18n.label(building,room,original),original);
 }
});
test('texte des onglets échappé, texte de titre non HTML, handlers et IDs préservés',()=>{
 locale='en';
 const real=win.i18next.t;
 win.i18next.t=()=>'<span onmouseover="evil()">Danger & error</span>';
 const raw=win.RPRoomI18n.label('palais-gouvernement','salle_presse',source.salle_presse);
 const safe=win.RPRoomI18n.labelHtml('palais-gouvernement','salle_presse',source.salle_presse);
 assert.ok(raw.includes('<span'));
 assert.ok(!safe.includes('<span'));
 assert.ok(safe.includes('&lt;span'));
 assert.ok(safe.includes('&amp;'));
 win.i18next.t=real;
 assert.ok(nav.includes("RPRoomI18n.labelHtml(buildingId, roomId, tabName)"));
 assert.ok(nav.includes("RPRoomI18n.label(buildingId, roomId, nomPieceAffiche)"));
 assert.ok(nav.includes('onclick="${clic}"'));
 assert.ok(nav.includes('const clic = porteInterdite'));
 assert.equal(win.RPRoomI18n.label('mairie','bureau_maire_local','Bureau du Conseil local'),'Bureau du Conseil local');
 const bridge=html.indexOf('src="i18n/plateau-bridge.js');
 const translations=html.indexOf('src="i18n/room-resources.js');
 const init=html.indexOf('src="i18n/plateau-init.js');
 assert.ok(bridge>=0&&translations>bridge&&init>translations);
});

test('les cinq pièces diplomatiques ne débordent pas sur les autres empires, IDs et actions inchangés',()=>{
 const sourceData=fs.readFileSync(path.join(root,'data.js'),'utf8');
 const i=sourceData.indexOf("  'palais-ambassades-novomirsk': {");
 const j=sourceData.indexOf("  'pavillon-ambassadeurs-novomirsk': {",i);
 assert.ok(i>0 && j>i);
 const building=sourceData.slice(i,j);
 const ids=['accueil_ambassades_novomirsk','salle_reception','bureau_republia_novomirsk','bureau_khalija_novomirsk','bureau_estado_novomirsk'];
 for(const id of ids){
  assert.ok(building.includes(id+': {'),'salle manquante : '+id);
  assert.ok(building.includes('name: "'+source[id]+'"'),'intitulé canonique introuvable : '+id);
  for(const locale of Object.keys(win.RP_I18N_LANGUAGES)){
   const expected=win.RP_I18N_RESOURCES[locale].translation.rooms[id];
   assert.ok(typeof expected==='string'&&expected.trim(),locale+'/'+id);
  }
 }
 locale='ru';
 for(const id of ids){
  assert.equal(win.RPRoomI18n.label('quartier-ambassades',id,source[id]),source[id]);
  assert.equal(win.RPRoomI18n.label('palais-gouvernement',id,source[id]),source[id]);
  assert.equal(win.RPRoomI18n.label('palais-ambassades-novomirsk',id,source[id]+' (fermé)'),source[id]+' (fermé)');
 }
 assert.ok(building.includes("bientot:'Bientôt disponible"));
});

test('le magasin de l’armurerie de Sovarka utilise une traduction de salle et non un nouvel ordre',()=>{
 const data=fs.readFileSync(path.join(root,'data.js'),'utf8');
 assert.ok(data.includes("name: 'Arsenal Collectif'"));
 assert.ok(data.includes("magasin: { imageUrl: \"images/Sovarka/Novomirsk/Novomirsk_armurerie.webp\" }"));
 for(const lng of Object.keys(win.RP_I18N_LANGUAGES)){
  locale=lng;
  const translated=win.RPRoomI18n.label('armurerie','magasin','Magasin');
  assert.equal(translated,win.RP_I18N_RESOURCES[lng].translation.rooms.magasin);
  assert.ok(translated.trim());
 }
 // Ce banc ne charge aucun catalogue d'ordres : les ressources de salle sont isolées.
 assert.equal(win.RP_I18N_RESOURCES.fr.translation.orders,undefined);
});

test('quatre salles publiques : source canonique et périmètre limité aux lieux appropriés',()=>{
 const data=fs.readFileSync(path.join(root,'data.js'),'utf8');
 const civic={commissariat:['accueil_police','prison','bureau_commissaire'],marche:['marche_ext']};
 for(const [building,ids] of Object.entries(civic)){
  const start=data.indexOf("\n  '"+building+"': {",300000);
  assert.ok(start>=0,'édifice manquant '+building);
  const end=data.indexOf("\n  '",start+5);
  const sourceBuilding=data.slice(start,end>start?end:undefined);
  for(const id of ids){
   assert.ok(sourceBuilding.includes(id+': {'),'salle absente '+building+'/'+id);
   for(const lng of Object.keys(win.RP_I18N_LANGUAGES)){
    locale=lng;
    const label=win.RPRoomI18n.label(building,id,source[id]);
    assert.equal(label,win.RP_I18N_RESOURCES[lng].translation.rooms[id]);
   }
   locale='en';
   assert.equal(win.RPRoomI18n.label(building,id,source[id]+' (privé)'),source[id]+' (privé)');
  }
 }
});

test('quinze salles supplémentaires sont ancrées au bâtiment exact sans changer la navigation',()=>{
 const data=fs.readFileSync(path.join(root,'data.js'),'utf8');
 const grouped={
  'hotel-republica':['accueil','restaurant','bar','chambres','suite_privee','suite_presidentielle'],
  'banque-nationale':['accueil_banque','coffre_privatif'],
  'banque-privee':['bureau_prive'],
  'office-notarial':['accueil_notaire','bureau_successions','bureau_contrats','archives_notariales'],
  'universite':['amphi','salle_reunion']
 };
 assert.equal(Object.values(grouped).flat().length,15);
 for(const [building,ids] of Object.entries(grouped)){
  const begin=data.indexOf("\n  '"+building+"': {",190000);
  assert.ok(begin>=0,'bâtiment absent : '+building);
  const end=data.indexOf("\n  '",begin+5);
  const body=data.slice(begin,end>begin?end:undefined);
  for(const id of ids){
   assert.ok(body.includes(id+': {'),'salle absente '+building+'/'+id);
   locale='en';
   assert.equal(win.RPRoomI18n.label(building,id,source[id]),win.RP_I18N_RESOURCES.en.translation.rooms[id]);
   assert.equal(win.RPRoomI18n.label('mairie',id,source[id]),source[id]);
   assert.equal(win.RPRoomI18n.label(building,id,source[id]+' — temporairement fermé'),source[id]+' — temporairement fermé');
  }
 }
});
