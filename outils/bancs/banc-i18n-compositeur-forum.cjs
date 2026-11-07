'use strict';
/* Localisation du compositeur riche : exclusivement labels et placeholders. */
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');
const root=path.resolve(__dirname,'../..');
const src=fs.readFileSync(path.join(root,'forum-canvas.js'),'utf8');
const win={};
let lng='fr';
win.RPPlateauI18n={language:()=>lng};
win.i18next={t:(k,{lng:language,defaultValue}={})=>k.split('.').reduce((v,key)=>v?.[key],win.RP_I18N_RESOURCES[language].translation)??defaultValue};
const ctx=vm.createContext({window:win});
for(const file of ['resources.js','forum-ui.js'])
 vm.runInContext(fs.readFileSync(path.join(root,'i18n',file),'utf8'),ctx);
const keys=['topicTitle','topicPlaceholder','addTextZone','addImage','preview','backToEditing',
 'publishTopic','publishReply','saveChanges','cancel','editMessage'];
test('11 commandes du compositeur disponibles dans les neuf langues',()=>{
 assert.equal(Object.keys(win.RP_I18N_LANGUAGES).length,9);
 for(const locale of Object.keys(win.RP_I18N_LANGUAGES)){
  lng=locale;
  for(const key of keys)assert.ok(win.RP_I18N_RESOURCES[locale].translation.forumUI[key]?.trim(),locale+': '+key);
 }
});
test('tous les modes conservent éditeur, fonctions, soumission et IDs originaux',()=>{
 for(const key of keys)assert.ok(src.includes("rpCanvasLabel('"+key+"'"),key);
 for(const symbol of ['renderComposeCanvasForm','submitComposeCanvas()','rpCanvasAddTextZoneToCompose()',
   'rpCanvasAddImageToCompose()','rpCanvasTogglePreview()','rpCanvasSerializeCompose()',
   'renderComposedPost(layout)','id="compose-canvas-title"','id="rp-compose-canvas"',
   'id="rp-compose-preview-btn"']){
  assert.ok(src.includes(symbol),symbol);
 }
 assert.ok(src.includes("const enReponse = !enEdition"));
 assert.ok(src.includes("const backAction = (enEdition || enReponse)"));
});
test('les contenus traduits utilisés dans le HTML sont échappés',()=>{
 lng='en';
 const old=win.i18next.t;
 win.i18next.t=()=>'<svg onload=alert(1)> &';
 const out=win.RPForumUI.labelHtml('publishReply','Publier la réponse');
 assert.ok(out.includes('&lt;svg') && out.includes('&amp;'));
 assert.ok(!out.includes('<svg'));
 win.i18next.t=old;
});
