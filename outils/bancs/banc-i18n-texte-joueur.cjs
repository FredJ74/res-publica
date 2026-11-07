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

test('le texte arabe est RTL et le retour à l original rétablit la direction propre au message',()=>{
 const mod=api();
 const handlers={};
 const attrs={};
 const element={textContent:'',setAttribute(k,v){attrs[k]=v}};
 const button={hidden:true,textContent:'',attrs:{},
  addEventListener(k,cb){handlers[k]=cb},removeEventListener(k){delete handlers[k]},
  setAttribute(k,v){this.attrs[k]=v}};
 const record=Object.freeze({
  original:'Bonjour le monde',originalLanguage:'fr',
  translation:'مرحبًا بالعالم',translationLanguage:'ar'
 });
 assert.equal(mod.renderText(element,record,'ar'),true);
 assert.equal(element.textContent,'مرحبًا بالعالم');
 assert.equal(attrs.dir,'rtl');
 const control=mod.attachToggle(element,button,record,'ar');
 assert.equal(element.textContent,'مرحبًا بالعالم');
 assert.equal(attrs.dir,'rtl');
 handlers.click();
 assert.equal(element.textContent,'Bonjour le monde');
 assert.equal(attrs.dir,'auto');
 assert.equal(button.attrs['aria-pressed'],'true');
 handlers.click();
 assert.equal(element.textContent,'مرحبًا بالعالم');
 assert.equal(attrs.dir,'rtl');
 assert.equal(record.original,'Bonjour le monde');
 control.detach();
});
test('un original arabe conserve RTL après restitution depuis une traduction',()=>{
 const mod=api();const attrs={};
 const element={textContent:'',setAttribute(k,v){attrs[k]=v}};
 const source=Object.freeze({original:'مرحبا',originalLanguage:'ar',translation:'Hello',translationLanguage:'en'});
 mod.renderText(element,source,'en');
 assert.equal(element.textContent,'Hello');assert.equal(attrs.dir,'auto');
 mod.renderText(element,source,'en',true);
 assert.equal(element.textContent,'مرحبا');assert.equal(attrs.dir,'rtl');
});


test('traduction vide ou blanche : toujours afficher le texte original',()=>{
 const mod=api();
 for(const translation of ['', '   ', '\n\t']){
  const record={original:'Message important',originalLanguage:'fr',translation,translationLanguage:'ar'};
  const shown=mod.view(record,'ar');
  assert.equal(shown.text,'Message important');
  assert.equal(shown.showOriginalAvailable,false);
  assert.equal(shown.translated,false);
  const el={textContent:'',attrs:{},setAttribute(k,v){this.attrs[k]=v}};
  assert.equal(mod.renderText(el,record,'ar'),true);
  assert.equal(el.textContent,'Message important');
 }
});


test('accessibilité multilingue : lang correspond au texte affiché, jamais au lecteur',()=>{
 const apiModule=api();
 const attrs={};
 const element={
  textContent:'',
  setAttribute(k,v){attrs[k]=v},
  removeAttribute(k){delete attrs[k]}
 };
 const message=Object.freeze({
  original:'Bonjour à tous',
  originalLanguage:'fr',
  translation:'مرحباً بالجميع',
  translationLanguage:'ar'
 });
 apiModule.renderText(element,message,'ar');
 assert.equal(element.textContent,'مرحباً بالجميع');
 assert.equal(attrs.dir,'rtl');
 assert.equal(attrs.lang,'ar');
 apiModule.renderText(element,message,'ar',true);
 assert.equal(element.textContent,'Bonjour à tous');
 assert.equal(attrs.dir,'auto');
 assert.equal(attrs.lang,'fr');
 const unknown=Object.freeze({
  original:'Texte dont la langue est inconnue',
  translation:null,
  translationLanguage:null,
  originalLanguage:'xx'
 });
 apiModule.renderText(element,unknown,'de');
 assert.equal(element.textContent,unknown.original);
 assert.equal(attrs.dir,'auto');
 assert.equal(attrs.lang,undefined);
});
test('bascule Voir original : lang change avec le contenu et les commandes ne changent pas',()=>{
 const apiModule=api(),handlers={},attrs={};
 const element={textContent:'',setAttribute(k,v){attrs[k]=v},removeAttribute(k){delete attrs[k]}};
 const button={hidden:false,textContent:'',setAttribute(){},addEventListener(k,cb){handlers[k]=cb},removeEventListener(k){delete handlers[k]}};
 const record=Object.freeze({original:'Hola',originalLanguage:'es',translation:'Hello',translationLanguage:'en'});
 const control=apiModule.attachToggle(element,button,record,'en');
 assert.equal(attrs.lang,'en');
 assert.equal(element.textContent,'Hello');
 handlers.click();
 assert.equal(attrs.lang,'es');
 assert.equal(element.textContent,'Hola');
 handlers.click();
 assert.equal(attrs.lang,'en');
 assert.equal(element.textContent,'Hello');
 control.detach();
});
