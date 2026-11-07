'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const win={};const ctx=vm.createContext({window:win});
for(const name of ['resources.js','guide-resources.js','guide-politique-resources.js'])
 vm.runInContext(fs.readFileSync(path.join(root,'i18n',name),'utf8'),ctx);
const langs=['en','es','zh-TW','ru','ko','ar','pt-BR','de'];

test('huit versions politiques : calendriers et seuils préservés',()=>{
 for(const lng of langs){
  const item=win.RP_I18N_RESOURCES[lng]?.translation?.guide?.politique;
  assert.ok(item?.titre?.trim(),lng);
  const text=item?.contenu||'';
  for(const n of ['5–6','50%','20%'])assert.ok(text.includes(n),lng+':'+n);
  assert.ok(text.length>300,lng);
 }
});
test('source française canonique intacte et extension chargée dans le bon ordre',()=>{
 assert.equal(win.RP_I18N_RESOURCES.fr.translation.guide,undefined);
 const html=fs.readFileSync(path.join(root,'plateau.html'),'utf8');
 const guide=html.indexOf('src="i18n/guide-resources.js');
 const localized=html.indexOf('src="i18n/guide-politique-resources.js');
 const bootstrap=html.indexOf('src="i18n/plateau-init.js');
 assert.ok(guide>=0 && localized>guide && bootstrap>localized);
 const game=fs.readFileSync(path.join(root,'plateau-personnage.js'),'utf8');
 const start=game.indexOf('  politique: {',game.indexOf('const REGLES = {'));
 const end=game.indexOf('  interactions: {',start);
 const canonical=game.slice(start,end);
 for(const literal of ['7 niveaux','5-6 semaines','>50%','>20%'])
  assert.ok(canonical.includes(literal),literal);
});
