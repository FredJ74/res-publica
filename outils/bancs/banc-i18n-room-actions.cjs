'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const read=f=>fs.readFileSync(path.join(root,f),'utf8');
const win={RP_I18N_GAME_ENABLED:true};
const ctx=vm.createContext({window:win});
for(const f of ['i18n/resources.js','i18n/room-actions-resources.js','i18n/room-resources.js'])
 vm.runInContext(read(f),ctx,{filename:f});
const source=read('plateau-politique.js'),html=read('plateau.html');
const langs=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
const originals={
 actionsAvailable:'ACTIONS DISPONIBLES',
 audioTooltip:"Ecouter l'audioguide de cette salle",
 audioAction:"Écouter l'audioguide",
 audioCost:'gratuit · 0 PA',
 caserneEngagement:'Engagement et affectation',
 caserneService:'Service et distinctions',
 caserneRecrutement:'Gestion des engagements',
 caserneCommandement:'Commandement et effectifs',
 caserneSection:'Ma section',
 caserneBudget:'Budget et stratégie'
};
test('dix libellés des salles, audioguides et menus de caserne dans les neuf langues',()=>{
 assert.deepEqual(Object.keys(win.RP_I18N_LANGUAGES),langs);
 for(const lang of langs){
  win.RPPlateauI18n={language:()=>lang};
  const texts=win.RP_I18N_RESOURCES[lang].translation.roomActions;
  assert.deepEqual(Object.keys(texts).sort(),Object.keys(originals).sort());
  for(const [key,original] of Object.entries(originals)){
   assert.ok(texts[key]?.trim(),lang+':'+key);
   assert.equal(win.RPRoomActionsI18n.label(key,original),texts[key],lang+':'+key);
   assert.equal(win.RPRoomActionsI18n.label(key,'Texte métier différent'),'Texte métier différent');
  }
  assert.ok(texts.audioCost.includes('0 PA'),lang+': PA non modifiés');
  assert.equal(win.RPRoomActionsI18n.labelHtml('audioTooltip',originals.audioTooltip)
    .includes('<script>'),false);
 }
});
test('repli FR, noms propres de salles hors contexte conservés, drapeau respecté',()=>{
 win.RPPlateauI18n={language:()=>'ko'};
 win.i18next={t:(key,{lng,defaultValue}={})=>key.split('.').reduce((o,k)=>o?.[k],win.RP_I18N_RESOURCES[lng].translation)??defaultValue};
 assert.equal(win.RPRoomI18n.label('mairie','bureau_maire_local','Bureau du Maire'),
  win.RP_I18N_RESOURCES.ko.translation.rooms.bureau_maire_local);
 assert.equal(win.RPRoomI18n.label('palais-presidentiel','bureau_maire_local','Bureau du Maire'),'Bureau du Maire');
 win.RP_I18N_GAME_ENABLED=false;
 assert.equal(win.RPRoomActionsI18n.label('actionsAvailable',originals.actionsAvailable),
  originals.actionsAvailable);
 win.RP_I18N_GAME_ENABLED=true;
});
test('en-tête et audioguide utilisent un texte localisé, jamais un nouvel ordre ni un débit',()=>{
 assert.match(source,/RPRoomActionsI18n\?\.label\?\.\('actionsAvailable'/);
 assert.match(source,/RPRoomI18n\?\.label\?\.\(buildingId,roomId,room\.name\)/);
 assert.match(source,/RPRoomActionsI18n/);
 assert.match(source,/audioTitle/);
 assert.match(source,/audioAction/);
 assert.match(source,/audioCost/);
 assert.match(source,/onclick="ouvrirAudioguide/);
 assert.match(source,/room\.audioUrl/);
 assert.match(source,/const safeNom = room\.name\.replace/);
 assert.ok(!source.includes('RP_ROOM_ACTIONS_REMOTE'));
 assert.ok(html.indexOf('i18n/room-resources.js')<html.indexOf('i18n/room-actions-resources.js'));
 assert.ok(html.indexOf('i18n/room-actions-resources.js')<html.indexOf('i18n/plateau-init.js'));
});
