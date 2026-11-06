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


test('le navigateur choisit une langue en absence de préférence explicite',()=>{
 const source=fs.readFileSync(path.join(__dirname,'../../i18n/plateau-bridge.js'),'utf8');
 for(const [locale,expected] of [
  ['es-MX','es'],['ru-RU','ru'],['ko-KR','ko'],['en-GB','en'],
  ['pt-BR','pt-BR'],['zh-Hant-TW','zh-TW'],['zh-Hans-CN','fr'],
  ['pt-PT','fr'],['zh','fr']
 ]) {
  const window={navigator:{language:locale},localStorage:{getItem:()=>null}};
  vm.runInNewContext(source,{window,Intl,Number,Object,String});
  assert.equal(window.RPPlateauI18n.language(),expected,locale);
 }
});
test('la préférence de jeu prime sur le navigateur et le stockage bloqué ne casse rien',()=>{
 const window={navigator:{language:'es-MX'},localStorage:{getItem:()=>'ar'}};
 vm.runInNewContext(src,{window,Intl,Number,Object,String});
 assert.equal(window.RPPlateauI18n.language(),'ar');
 const blocked={navigator:{language:'de-DE'},localStorage:{getItem(){throw Error('blocked')}}};
 vm.runInNewContext(src,{window:blocked,Intl,Number,Object,String});
 assert.equal(blocked.RPPlateauI18n.language(),'de');
});
test('le plateau ne choisit pas une autre langue navigateur que l accueil',()=>{
 const window={navigator:{languages:['zh-CN','es-ES'],language:'zh-CN'},
  localStorage:{getItem:()=>null}};
 vm.runInNewContext(src,{window,Intl,Number,Object,String});
 assert.equal(window.RPPlateauI18n.language(),'fr');
});
