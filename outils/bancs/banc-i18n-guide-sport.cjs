'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const window={};const context=vm.createContext({window});
for(const file of ['resources.js','guide-resources.js','guide-sport-resources.js'])
 vm.runInContext(fs.readFileSync(path.join(root,'i18n',file),'utf8'),context);
const languages=['en','es','zh-TW','ru','ko','ar','pt-BR','de'];

test('football : huit traductions conservent les durées et phases',()=>{
 for(const lang of languages){
  const section=window.RP_I18N_RESOURCES[lang]?.translation?.guide?.sport;
  assert.ok(section?.titre?.includes('⚽'),lang);
  const body=section.contenu;
  for(const number of ['5','10','45','90'])
   assert.ok(body.includes(number),lang+'/'+number);
  assert.ok(body.length>=160,lang);
 }
});
test('chargement sans écraser les règles FR ni les autres rubriques',()=>{
 assert.equal(window.RP_I18N_RESOURCES.fr.translation.guide,undefined);
 const html=fs.readFileSync(path.join(root,'plateau.html'),'utf8');
 const first=html.indexOf('src="i18n/guide-resources.js');
 const next=html.indexOf('src="i18n/guide-sport-resources.js');
 const init=html.indexOf('src="i18n/plateau-init.js');
 assert.ok(first>=0&&next>first&&init>next);
});
