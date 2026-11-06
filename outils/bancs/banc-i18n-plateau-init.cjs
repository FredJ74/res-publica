'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const script=fs.readFileSync(path.join(__dirname,'../../i18n/plateau-init.js'),'utf8');
function run(locale){
 const el={textContent:'MESSAGES',attrs:{'data-i18n':'plateau.messages','data-i18n-uppercase':''},
  getAttribute(k){return this.attrs[k]},hasAttribute(k){return Object.hasOwn(this.attrs,k)},
  setAttribute(k,v){this.attrs[k]=v}};
 const document={documentElement:{lang:'fr'},querySelectorAll:()=>[el]};
 const window={document,localStorage:{getItem:()=>locale},
  RP_I18N_LANGUAGES:{fr:{},ar:{},en:{}},RP_I18N_RESOURCES:{fr:{},ar:{},en:{}},
  i18next:{init(opts,done){this.options=opts;done(null)},t(key){return key==='plateau.messages'?(locale==='ar'?'الرسائل':'Messages'):key}}};
 vm.runInNewContext(script,{window,console});
 return {el,document,opts:window.i18next.options,api:window.RPI18nPlateau,engine:window.i18next};
}
test('arabe : seuls les textes localisés passent en RTL',()=>{
 const {el,document,opts}=run('ar');
 assert.equal(document.documentElement.lang,'ar');
 assert.equal(el.textContent,'الرسائل');
 assert.equal(el.attrs.dir,'rtl');
 assert.equal(opts.fallbackLng,'fr');
});
test('préférence non prise en charge : fallback français',()=>{
 const {el,document,opts}=run('xx');
 assert.equal(document.documentElement.lang,'fr');
 assert.equal(el.textContent,'MESSAGES');
 assert.equal(el.attrs.dir,undefined);
 assert.equal(opts.lng,'fr');
});

test('une interface créée plus tard peut être localisée sans réinitialiser i18next',()=>{
 const {api}=run('ar');
 const el={textContent:'',attrs:{'data-i18n':'plateau.messages'},
  getAttribute(k){return this.attrs[k]},
  hasAttribute(k){return Object.hasOwn(this.attrs,k)},
  setAttribute(k,v){this.attrs[k]=v},
  removeAttribute(k){delete this.attrs[k]}};
 const subtree={querySelectorAll(){return [el]}};
 api.apply(subtree);
 assert.equal(el.textContent,'الرسائل');
 assert.equal(el.attrs.dir,'rtl');
 assert.equal(api.locale(),'ar');
});


test('clé absente : garder le libellé français déjà présent dans le DOM',()=>{
 const {api}=run('en');
 const el={textContent:'Texte français de secours',attrs:{'data-i18n':'plateau.cle_inconnue'},
  getAttribute(k){return this.attrs[k]},
  hasAttribute(k){return Object.hasOwn(this.attrs,k)},
  setAttribute(k,v){this.attrs[k]=v},
  removeAttribute(k){delete this.attrs[k]}};
 api.apply({querySelectorAll(){return [el]}});
 assert.equal(el.textContent,'Texte français de secours');
 assert.equal(el.attrs.dir,undefined);
});


test('placeholder mail traduit sans altérer la saisie ni la mise en page',()=>{
 const {api,engine}=run('de');
 const attrs={'data-i18n-placeholder':'plateau.recipientPlaceholder',placeholder:'Destinataire...'};
 const input={value:'Jean Jaaj',attrs,
  getAttribute(k){return this.attrs[k]},setAttribute(k,v){this.attrs[k]=v},
  hasAttribute(k){return Object.hasOwn(this.attrs,k)}};
 engine.t=key=>key==='plateau.recipientPlaceholder'?'Empfänger...':key;
 api.apply({querySelectorAll(selector){return selector==='[data-i18n-placeholder]'?[input]:[]}});
 assert.equal(input.value,'Jean Jaaj');
 assert.equal(attrs.placeholder,'Empfänger...');
 assert.equal(attrs.dir,undefined);
 input.attrs['data-i18n-placeholder']='plateau.absent';
 api.apply({querySelectorAll(selector){return selector==='[data-i18n-placeholder]'?[input]:[]}});
 assert.equal(attrs.placeholder,'Empfänger...');
});
