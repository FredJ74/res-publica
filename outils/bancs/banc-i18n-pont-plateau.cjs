'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const src=fs.readFileSync(path.join(__dirname,'../../i18n/plateau-bridge.js'),'utf8');
function load(lang) {
 const win={localStorage:{getItem:()=>lang},i18next:{t:(key,o)=>o.lng+':'+key}};
 vm.runInNewContext(src,{window:win,Intl,Number,Object,String});
 return win.RPPlateauI18n;
}
test('le pont conserve les neuf langues et la préférence existante',()=>{
 for(const code of ['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de']) {
  assert.equal(load(code).language(),code);
  assert.equal(load(code).translate('journal.title'),code+':journal.title');
 }
 assert.equal(load('unsupported').language(),'fr');
});
test('un texte joueur reste toujours disponible en original',()=>{
 const p=load('de');
 const translated=p.message('Texte original','Übersetzung','de');
 assert.equal(translated.original,'Texte original');
 assert.equal(translated.displayed,'Übersetzung');
 assert.equal(translated.isTranslated,true);
 const fallback=p.message('Texte original','Autre langue','ar');
 assert.equal(fallback.displayed,'Texte original');
 assert.equal(fallback.isTranslated,false);
});
