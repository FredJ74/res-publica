'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const source=(name)=>fs.readFileSync(path.join(root,'i18n',name),'utf8');
function setup(browser='fr',stored=null) {
 const storage={value:stored,getItem(){return this.value},setItem(_key,v){this.value=v}};
 const selector={innerHTML:''};
 const buttons={};
 const document={
  documentElement:{lang:'fr'},title:'',
  getElementById(id){
   if(id==='lang-switcher')return selector;
   if(id.startsWith('lang-btn-'))return buttons[id] ||= {classList:{toggle(){}}};
   return null;
  },querySelectorAll(){return []}
 };
 const i18next={
  language:'fr',
  t(key){return key},
  init(options,done){this.language=options.lng;done(null)},
  changeLanguage(language,done){this.language=language;done()}
 };
 const ctx=vm.createContext({window:{},document,localStorage:storage,navigator:{language:browser},i18next,console});
 vm.runInContext(source('resources.js'),ctx);
 vm.runInContext(source('i18n-init.js'),ctx);
 return {ctx,selector,storage,document,i18next};
}
test('neuf boutons avec autonymes, incluant trois langues supplémentaires',()=>{
 const state=setup();
 for(const name of ['Français','English','Español','繁體中文','Русский','한국어','العربية','Português (Brasil)','Deutsch'])
  assert.ok(state.selector.innerHTML.includes(name),name);
 assert.equal((state.selector.innerHTML.match(/<button/g)||[]).length,9);
});
test('sélection arabe persistée sans changement serveur ni perte de la langue choisie',()=>{
 const state=setup('fr');
 state.ctx.changerLangueRP('ar');
 assert.equal(state.i18next.language,'ar');
 assert.equal(state.storage.value,'ar');
 assert.equal(state.document.documentElement.lang,'ar');
 state.ctx.changerLangueRP('xx');
 assert.equal(state.storage.value,'ar');
});
test('navigateur et préférence régionale utilisent le même sélecteur canonique',()=>{
 assert.equal(setup('zh-Hant-TW').i18next.language,'zh-TW');
 assert.equal(setup('pt-BR').i18next.language,'pt-BR');
 assert.equal(setup('en','de').i18next.language,'de');
 assert.equal(setup('zh-CN').i18next.language,'fr');
});
