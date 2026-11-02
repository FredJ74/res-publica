'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const src=fs.readFileSync(path.join(__dirname,'../../i18n/texte-joueur.js'),'utf8');
function api(){
 const win={RP_I18N_LANGUAGES:{fr:{},en:{},es:{},'zh-TW':{},ru:{},ko:{},ar:{},'pt-BR':{},de:{}}};
 vm.runInNewContext(src,{window:win,String,Object});
 return win.RPPlayerText;
}
test('conserve original et traduction séparés, sans inventer de traduction',()=>{
 const mod=api(),record=Object.freeze({original:'Bonjour',originalLanguage:'fr',translation:'Hello',translationLanguage:'en'});
 assert.equal(mod.view(record,'en').text,'Hello');
 assert.equal(mod.view(record,'en').original,'Bonjour');
 assert.equal(mod.view(record,'en',true).text,'Bonjour');
 assert.equal(mod.view(record,'es').text,'Bonjour');
 assert.equal(mod.view(record,'en').showOriginalAvailable,true);
 assert.equal(record.original,'Bonjour');
});
test('un texte malveillant ne peut pas injecter de HTML via le rendu',()=>{
 const mod=api(),element={textContent:''};
 const record={original:'<script>alert(1)</script>',originalLanguage:'fr',translation:'<b>Attack</b>',translationLanguage:'de'};
 assert.equal(mod.renderText(element,record,'de'),true);
 assert.equal(element.textContent,'<b>Attack</b>');
 assert.equal(mod.renderText(element,record,'de',true),true);
 assert.equal(element.textContent,'<script>alert(1)</script>');
});

test('bouton Voir original : bascule sans perdre la traduction ni injecter de HTML',()=>{
 const mod=api(),element={textContent:''};
 const handlers={};
 const button={hidden:false,textContent:'',attrs:{},
  addEventListener(k,f){handlers[k]=f},removeEventListener(k){delete handlers[k]},
  setAttribute(k,v){this.attrs[k]=v}};
 const record=Object.freeze({original:'<b>Bonjour</b>',originalLanguage:'fr',translation:'<script>Hallo</script>',translationLanguage:'de'});
 const ctrl=mod.attachToggle(element,button,record,'de',{showOriginal:"Voir l'original",showTranslation:'Voir la traduction'});
 assert.equal(element.textContent,'<script>Hallo</script>');
 assert.equal(button.hidden,false);
 assert.equal(button.attrs['aria-pressed'],'false');
 handlers.click();
 assert.equal(element.textContent,'<b>Bonjour</b>');
 assert.equal(button.attrs['aria-pressed'],'true');
 assert.equal(record.original,'<b>Bonjour</b>');
 handlers.click();
 assert.equal(element.textContent,'<script>Hallo</script>');
 ctrl.detach();assert.equal(handlers.click,undefined);
});
