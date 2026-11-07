'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const base=path.join(__dirname,'../..');
const sourceFiles=['i18n/resources.js','i18n/plateau-resources.js',
 'i18n/plateau-bridge.js','i18n/texte-joueur.js'];
function load(locale){
 const listeners={};
 const root={localStorage:{getItem:()=>locale}};
 const context=vm.createContext({window:root,Intl,Object,String,Number});
 for(const file of sourceFiles){
  if(file.endsWith('plateau-bridge.js')){
   root.i18next={t:(key,{lng}={})=>{
    const language=lng||locale;
    const value=key.split('.').reduce((obj,part)=>obj?.[part],
     root.RP_I18N_RESOURCES[language]?.translation);
    return typeof value==='string'?value:key;
   }};
  }
  vm.runInContext(fs.readFileSync(path.join(base,file),'utf8'),context);
 }
 const display={textContent:'',attrs:{},
  setAttribute(k,v){this.attrs[k]=v},
  removeAttribute(k){delete this.attrs[k]}};
 const button={hidden:true,textContent:'',attrs:{},
  addEventListener(k,fn){listeners[k]=fn},
  removeEventListener(k){delete listeners[k]},
  setAttribute(k,v){this.attrs[k]=v}};
 return {root,display,button,listeners};
}
test('les neuf langues localisent automatiquement les boutons sociaux',()=>{
 const langs=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
 for(const lang of langs){
  const {root,button,display,listeners}=load(lang);
  const record={original:'Message original',originalLanguage:'fr',
    translation:'Traduction',translationLanguage:lang};
  // En français, ne pas proposer une bascule inutile vers le même texte.
  const toggle=root.RPPlayerText.attachToggle(display,button,record,lang);
  const catalog=root.RP_I18N_RESOURCES[lang].translation.plateau;
  if(lang==='fr'){
   assert.equal(button.hidden,true);
   assert.equal(display.textContent,'Message original');
  }else{
   assert.equal(button.hidden,false);
   assert.equal(display.textContent,'Traduction');
   assert.equal(button.textContent,catalog.showOriginal,lang);
   assert.equal(display.attrs.lang,lang,lang);
   assert.equal(display.attrs.dir,lang==='ar'?'rtl':'auto');
   listeners.click();
   assert.equal(button.textContent,catalog.showTranslation,lang);
   assert.equal(display.textContent,'Message original');
   assert.equal(display.attrs.lang,'fr');
   assert.equal(display.attrs.dir,'auto');
  }
  toggle.detach();
 }
});
test('traduction vide ou non autorisée : toujours original, aucun bouton',()=>{
 const {root,button,display}=load('ar');
 root.RPPlayerText.attachToggle(display,button,{
  original:'Message privé inchangé',originalLanguage:'fr',
  translation:' ',translationLanguage:'ar'},'ar');
 assert.equal(display.textContent,'Message privé inchangé');
 assert.equal(button.hidden,true);
});
