'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const win={};
const ctx=vm.createContext({window:win});
for(const filename of ['resources.js','guide-resources.js','guide-economie-resources.js'])
 vm.runInContext(fs.readFileSync(path.join(root,'i18n',filename),'utf8'),ctx);
const locales=['en','es','zh-TW','ru','ko','ar','pt-BR','de'];

test('huit versions de l économie sans conversion des montants',()=>{
 for(const locale of locales){
  const item=win.RP_I18N_RESOURCES[locale]?.translation?.guide?.economie;
  assert.ok(item?.titre?.trim(),locale);
  assert.ok(item?.contenu?.trim(),locale);
  for(const n of ['30%','70%','12','48','FR'])
   assert.ok(item.contenu.includes(n),locale+':'+n);
  // Valeurs salariales présentes, le séparateur des milliers varie selon la langue.
  for(const value of ['5','3','2','1','800','150'])
   assert.ok(item.contenu.includes(value),locale+':'+value);
 }
});
test('aucune substitution du français et chargement avant le moteur',()=>{
 assert.equal(win.RP_I18N_RESOURCES.fr.translation.guide,undefined);
 const html=fs.readFileSync(path.join(root,'plateau.html'),'utf8');
 const source=html.indexOf('src="i18n/guide-resources.js');
 const localized=html.indexOf('src="i18n/guide-economie-resources.js');
 const init=html.indexOf('src="i18n/plateau-init.js');
 assert.ok(source>=0 && localized>source && init>localized);
});
