'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'../..');
const plateau=fs.readFileSync(path.join(root,'plateau.html'),'utf8');
test('le plateau charge le moteur i18next existant et conserve la même préférence',()=>{
 const scripts=['i18n/i18next.min.js','i18n/resources.js','i18n/plateau-resources.js','i18n/plateau-bridge.js','i18n/plateau-init.js'];
 let last=-1;
 for(const script of scripts){
  const i=plateau.indexOf('src="'+script);
  assert.ok(i>last,'ordre ou absence de '+script);
  last=i;
 }
 assert.match(fs.readFileSync(path.join(root,'i18n/plateau-init.js'),'utf8'),/respublica_language/);
});
test('les en-têtes de plateau ont un fallback français sans modifier leurs commandes',()=>{
 for (const [key,text] of [['character','MON PERSONNAGE'],['eventJournal','JOURNAL DES ÉVÉNEMENTS'],['messages','MESSAGES']]){
  assert.match(plateau,new RegExp('data-i18n="plateau\\.'+key+'"[^>]*>'+text));
 }
});

test('les panneaux statiques portent des clés de localisation sans modifier les handlers',()=>{
 for(const key of ['money','cash','bank','cityMap','peoplePresent','availableActions','combatReports','newMessage','description']) {
  assert.ok(plateau.includes('data-i18n="plateau.'+key+'"'),'clé absente '+key);
 }
 assert.match(plateau,/onclick="ouvrirCalepinCampagne\(\)"/);
 assert.match(plateau,/id="action-context-bat"/);
});

test('navigation principale, forum et courrier gardent leurs clés et événements',()=>{
 for(const key of ['personalActions','inventory','organizations','identity','statistics','rules','forum','localForum','mailbox','receivedMessages','financeManagement','characterSheet','conversation']) {
  assert.ok(plateau.includes('data-i18n="plateau.'+key+'"'),key);
 }
 assert.match(plateau,/onclick="switchSelfTab\('actions',this\)"/);
 assert.match(plateau,/onclick="switchSelfTab\('inventaire',this\)"/);
 assert.match(plateau,/id="pnj-modal-title"/);
});

test('cartes, organigramme, courrier et guide utilisent des textes localisés statiques',()=>{
 for(const key of ['worldMap','orgChart','postalCard','subject','messageLabel','gameGuide']) {
  assert.ok(plateau.includes('data-i18n="plateau.'+key+'"'),key);
 }
 assert.match(plateau,/onclick="closeWorldMap\(\)"/);
 assert.match(plateau,/id="compose-mail-subject"/);
 assert.match(plateau,/id="compose-mail-body"/);
});
