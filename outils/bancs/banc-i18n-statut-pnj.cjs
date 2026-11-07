'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.join(__dirname,'../..');
const src=fs.readFileSync(path.join(root,'plateau-pnj.js'),'utf8');
const html=fs.readFileSync(path.join(root,'plateau.html'),'utf8');
const win={};
let lng='fr';
win.RPPlateauI18n={language:()=>lng};
win.i18next={t:(key,{lng:target,defaultValue}={})=>key.split('.').reduce((v,k)=>v?.[k],
   win.RP_I18N_RESOURCES?.[target]?.translation)??defaultValue};
const ctx=vm.createContext({window:win});
for(const file of ['resources.js','pnj-status-resources.js'])
 vm.runInContext(fs.readFileSync(path.join(root,'i18n',file),'utf8'),ctx);
const keys={
 noConversation:"Ce personnage n'engage pas de conversation.",
 temporaryUnavailable:'Discussion impossible momentanément. Veuillez réessayer dans quelques instants.',
 noConversationHint:'Cette personne ne tient pas de conversation. Les autres actions restent disponibles.',
 questRecap:'Je vous remontre où nous en sommes.'
};
test('quatre statuts PNJ localisés dans les neuf langues, repli français préservé',()=>{
 assert.equal(Object.keys(win.RP_I18N_LANGUAGES).length,9);
 for(const locale of Object.keys(win.RP_I18N_LANGUAGES)){
  lng=locale;
  for(const [key,source] of Object.entries(keys)){
   const expected=win.RP_I18N_RESOURCES[locale].translation.pnjStatus[key];
   assert.ok(expected&&expected.trim(),locale+': '+key);
   assert.equal(win.RPPnjStatusI18n.label(key,source),expected);
  }
 }
 lng='ru';
 assert.equal(win.RPPnjStatusI18n.label('noConversation','Autre motif'), 'Autre motif');
 assert.equal(win.RPPnjStatusI18n.label('unknownKey','Source inconnue'), 'Source inconnue');
});
test('statut visible sans faux dialogue ni mutation des ordres',()=>{
 assert.ok(src.includes("statusTraduit('noConversation'"));
 assert.ok(src.includes("statusTraduit('temporaryUnavailable'"));
 assert.ok(src.includes("statusTraduit('noConversationHint'"));
 assert.ok(src.includes("RPPnjStatusI18n?.label?.('questRecap'"));
 assert.ok(src.includes("e && e.definitif === true"));
 assert.ok(src.includes("document.getElementById('pnj-zone-question')"));
 assert.ok(src.includes('zoneQ.firstElementChild.textContent'));
 assert.ok(src.includes("reponsePnjServeur(profilServeur, action, recentHistory)"));
 assert.ok(src.includes("history.push({ role: 'user', content: action })"));
 assert.ok(src.includes("history.push({ role: 'assistant', content: texteServeur })"));
 const bridge=html.indexOf('src="i18n/plateau-bridge.js');
 const status=html.indexOf('src="i18n/pnj-status-resources.js');
 const init=html.indexOf('src="i18n/plateau-init.js');
 assert.ok(bridge>=0&&status>bridge&&init>status);
});
