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
 return {el,document,opts:window.i18next.options};
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
