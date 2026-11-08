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
 bureau_estado_novomirsk:"Ambassade d'El Estado"
};
test('neuf traductions de dix-huit salles, avec repli français explicite',()=>{
 assert.equal(Object.keys(win.RP_I18N_LANGUAGES).length,9);
 for(const lang of Object.keys(win.RP_I18N_LANGUAGES)){
  locale=lang;
  const rooms=win.RP_I18N_RESOURCES[lang].translation.rooms;
  assert.deepEqual(Object.keys(rooms).sort(),Object.keys(source).sort());
  for(const [room,original] of Object.entries(source)){
   assert.equal(typeof rooms[room],'string');
   assert.ok(rooms[room].trim(),lang+': '+room);
   assert.equal(win.RPRoomI18n.label(room.includes('maire')||room==='accueil_mairie'?'mairie':room==='salle_reception'||room.includes('ambassades_novomirsk')||room.startsWith('bureau_republia_novomirsk')||room.startsWith('bureau_khalija_novomirsk')||room.startsWith('bureau_estado_novomirsk')?'palais-ambassades-novomirsk':'palais-gouvernement',room,original),rooms[room]);
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
  ['palais-gouvernement','hall',"Hall d'entrée"]
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
