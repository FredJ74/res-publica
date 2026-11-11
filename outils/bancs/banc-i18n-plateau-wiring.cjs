'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'../..');
const plateau=fs.readFileSync(path.join(root,'plateau.html'),'utf8');
test('le plateau charge le moteur i18next existant et conserve la même préférence',()=>{
 const scripts=['i18n/i18next.min.js','i18n/resources.js','i18n/plateau-resources.js','i18n/orders-resources.js','i18n/plateau-bridge.js','i18n/ordres.js','i18n/texte-joueur.js','i18n/plateau-init.js'];
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
 for(const key of ['money','cash','bank','cityMap','peoplePresent','combatReports','newMessage']) {
  assert.ok(plateau.includes('data-i18n="plateau.'+key+'"'),'clé absente '+key);
 }
 assert.match(plateau,/onclick="ouvrirCalepinCampagne\(\)"/);
 assert.match(plateau,/id="action-context-bat"/);
});

test('navigation principale, forum et courrier gardent leurs clés et événements',()=>{
 for(const key of ['personalActions','inventory','organizations','identity','statistics','help','forum','mailbox','financeManagement','characterSheet']) {
  assert.ok(plateau.includes('data-i18n="plateau.'+key+'"'),key);
 }
 assert.match(plateau,/onclick="switchSelfTab\('actions',this\)"/);
 assert.match(plateau,/onclick="switchSelfTab\('inventaire',this\)"/);
 assert.match(plateau,/id="pnj-modal-title"/);
});

test('cartes, organigramme, courrier et guide utilisent des textes localisés statiques',()=>{
 for(const key of ['worldMap','subject','messageLabel','gameGuide']) {
  assert.ok(plateau.includes('data-i18n="plateau.'+key+'"'),key);
 }
 assert.match(plateau,/onclick="closeWorldMap\(\)"/);
 assert.match(plateau,/id="compose-mail-subject"/);
 assert.match(plateau,/id="compose-mail-body"/);
});

test('les titres et descriptions dynamiques préservent les valeurs métier entre deux langues',()=>{
 for(const id of ['piece-desc','pnj-modal-title','postes-modal-title','forum-view-subtitle',
  'mail-view-subtitle','action-context-bat','minimap-ville-title','carte-postale-modal-title']){
  const fragment=plateau.match(new RegExp('<[^>]*id="'+id+'"[^>]*>'));
  assert.ok(fragment,'noeud absent '+id);
  assert.doesNotMatch(fragment[0],/data-i18n=/,'marqueur statique dangereux sur '+id);
 }
});
