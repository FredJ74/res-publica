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
 const window={RP_I18N_GAME_ENABLED:true,document,localStorage:{getItem:()=>locale},
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


test('plateau et pont partagent la langue détectée au premier chargement',()=>{
 const bridge=fs.readFileSync(path.join(__dirname,'../../i18n/plateau-bridge.js'),'utf8');
 for(const [navigatorLanguage,stored,wanted] of [
  ['es-MX',null,'es'],['ru-RU','ar','ar'],['zh-Hant-TW',null,'zh-TW'],
  ['zh-CN',null,'fr']
 ]) {
  const element={textContent:'Messages',attrs:{'data-i18n':'plateau.messages'},
   getAttribute(k){return this.attrs[k]},hasAttribute(k){return Object.hasOwn(this.attrs,k)},
   setAttribute(k,v){this.attrs[k]=v},removeAttribute(k){delete this.attrs[k]}};
  const document={documentElement:{lang:'fr'},querySelectorAll(selector){
   return selector==='[data-i18n]'?[element]:[];
  }};
  const languages={fr:{},en:{},es:{},'zh-TW':{},ru:{},ko:{},ar:{},'pt-BR':{},de:{}};
  const window={RP_I18N_GAME_ENABLED:true,document,navigator:{language:navigatorLanguage},localStorage:{getItem:()=>stored},
   RP_I18N_LANGUAGES:languages,RP_I18N_RESOURCES:{},
   i18next:{init(options,done){this.options=options;done(null)},t:()=> 'Messages'}};
  vm.runInNewContext(bridge,{window,console,Intl,Number,Object,String});
  vm.runInNewContext(script,{window,console});
  assert.equal(window.i18next.options.lng,wanted,navigatorLanguage);
  assert.equal(window.RPPlateauI18n.language(),wanted,navigatorLanguage);
  assert.equal(document.documentElement.lang,wanted,navigatorLanguage);
 }
});


test('aria-label localisé sans ajouter de texte ni déplacer un contrôle tactile',()=>{
 const {api,engine}=run('ar');
 const element={textContent:'',attrs:{'data-i18n-aria-label':'plateau.mobileClosePanel','aria-label':'Fermer le panneau'},
  getAttribute(k){return this.attrs[k]},hasAttribute(k){return Object.hasOwn(this.attrs,k)},
  setAttribute(k,v){this.attrs[k]=v},removeAttribute(k){delete this.attrs[k]}};
 engine.t=key=>key==='plateau.mobileClosePanel'?'إغلاق اللوحة':key;
 const root={querySelectorAll(selector){return selector==='[data-i18n-aria-label]'?[element]:[]}};
 api.apply(root);
 assert.equal(element.attrs['aria-label'],'إغلاق اللوحة');
 assert.equal(element.textContent,'');
 element.attrs['data-i18n-aria-label']='plateau.missingKey';
 api.apply(root);
 assert.equal(element.attrs['aria-label'],'إغلاق اللوحة');
});

test('changement de langue et autre onglet : textes, direction et état dynamique synchronisés',()=>{
 const attrs={'data-i18n':'plateau.messages'};
 const element={textContent:'Messages',attrs,
  getAttribute(k){return this.attrs[k]},hasAttribute(k){return Object.hasOwn(this.attrs,k)},
  setAttribute(k,v){this.attrs[k]=v},removeAttribute(k){delete this.attrs[k]}};
 const document={documentElement:{lang:'fr'},querySelectorAll(sel){return sel==='[data-i18n]'?[element]:[]}};
 const listeners={};
 const engine={language:'de',on(evt,fn){listeners[evt]=fn},
  init(opts,done){this.language=opts.lng;done(null);return this},
  t(key){return key==='plateau.messages'?({de:'Nachrichten',ar:'الرسائل',ko:'메시지'}[this.language]||'Messages'):key},
  changeLanguage(lang){this.language=lang;listeners.languageChanged?.(lang)}};
 const window={RP_I18N_GAME_ENABLED:true,document,localStorage:{getItem:()=> 'de'},addEventListener(evt,fn){listeners[evt]=fn},
  RP_I18N_LANGUAGES:{fr:{},de:{},ar:{},ko:{}},RP_I18N_RESOURCES:{},i18next:engine};
 vm.runInNewContext(script,{window,console});
 assert.equal(window.RPI18nPlateau.locale(),'de');
 engine.changeLanguage('ar');
 assert.equal(window.RPI18nPlateau.locale(),'ar');
 assert.equal(document.documentElement.lang,'ar');
 assert.equal(element.textContent,'الرسائل');
 assert.equal(attrs.dir,'rtl');
 listeners.storage({key:'respublica_language',newValue:'ko'});
 assert.equal(engine.language,'ko');
 assert.equal(window.RPI18nPlateau.locale(),'ko');
 assert.equal(document.documentElement.lang,'ko');
 assert.equal(element.textContent,'메시지');
 assert.equal(attrs.dir,undefined);
 listeners.storage({key:'respublica_language',newValue:'xx'});
 assert.equal(engine.language,'ko');
});

test('sans drapeau, les scripts du plateau restent exclusivement français',()=>{
 const element={textContent:'MESSAGES',attrs:{'data-i18n':'plateau.messages'},
  getAttribute(k){return this.attrs[k]},hasAttribute(k){return Object.hasOwn(this.attrs,k)},
  setAttribute(k,v){this.attrs[k]=v},removeAttribute(k){delete this.attrs[k]}};
 const document={documentElement:{lang:'fr'},querySelectorAll(sel){return sel==='[data-i18n]'?[element]:[]}};
 const engine={init(opts,cb){this.options=opts;this.language=opts.lng;cb(null)},
  t(key){return this.language==='fr'?'MESSAGES':'الرسائل'}};
 const window={document,navigator:{language:'ar'},localStorage:{getItem:()=> 'ar'},
  RP_I18N_LANGUAGES:{fr:{},ar:{},en:{}},RP_I18N_RESOURCES:{},i18next:engine};
 vm.runInNewContext(script,{window,console});
 assert.equal(engine.options.lng,'fr');
 assert.equal(document.documentElement.lang,'fr');
 assert.equal(window.RPI18nPlateau.locale(),'fr');
 assert.equal(element.attrs.dir,undefined);
});

test('même une bascule programmatique non autorisée revient au français',()=>{
 const listeners={};
 const element={textContent:'MESSAGES',attrs:{'data-i18n':'plateau.messages'},
  getAttribute(k){return this.attrs[k]},hasAttribute(k){return Object.hasOwn(this.attrs,k)},
  setAttribute(k,v){this.attrs[k]=v},removeAttribute(k){delete this.attrs[k]}};
 const document={documentElement:{lang:'fr'},querySelectorAll(sel){return sel==='[data-i18n]'?[element]:[]}};
 const engine={language:'fr',on(evt,fn){listeners[evt]=fn},
  init(options,cb){this.language=options.lng;cb(null)},
  t(key){return this.language==='fr'?'MESSAGES':'الرسائل'},
  changeLanguage(lang){this.language=lang;listeners.languageChanged?.(lang)}};
 const window={document,navigator:{language:'ar'},localStorage:{getItem:()=> 'ar'},
  RP_I18N_LANGUAGES:{fr:{},ar:{}},RP_I18N_RESOURCES:{},i18next:engine};
 vm.runInNewContext(script,{window,console});
 engine.changeLanguage('ar');
 assert.equal(engine.language,'fr');
 assert.equal(document.documentElement.lang,'fr');
 assert.equal(element.textContent,'MESSAGES');
});

test('basculer vers une locale incomplète rétablit le français sans conserver l’anglais précédent',()=>{
 const attrs={'data-i18n':'plateau.messages','data-i18n-placeholder':'plateau.placeholder',
  'data-i18n-aria-label':'plateau.accessible','data-i18n-title':'plateau.tooltip',
  placeholder:'Destinataire…','aria-label':'Fermer',title:'Fermer la fenêtre'};
 const element={textContent:'Messages',value:'Saisie non modifiée',attrs,
  getAttribute(k){return this.attrs[k]},hasAttribute(k){return Object.hasOwn(this.attrs,k)},
  setAttribute(k,v){this.attrs[k]=v},removeAttribute(k){delete this.attrs[k]}};
 const document={documentElement:{lang:'fr'},querySelectorAll(selector){
  return ['[data-i18n]','[data-i18n-placeholder]','[data-i18n-aria-label]','[data-i18n-title]'].includes(selector)?[element]:[];
 }};
 const listeners={};
 const english={'plateau.messages':'Inbox','plateau.placeholder':'Recipient…',
  'plateau.accessible':'Close','plateau.tooltip':'Close window'};
 const engine={language:'en',on(name,fn){listeners[name]=fn},
  init(options,done){this.language=options.lng;done(null)},
  t(key){return this.language==='en'?english[key]||key:key},
  changeLanguage(lng){this.language=lng;listeners.languageChanged?.(lng)}};
 const window={RP_I18N_GAME_ENABLED:true,document,localStorage:{getItem:()=> 'en'},
  RP_I18N_LANGUAGES:{fr:{},en:{},ar:{}},RP_I18N_RESOURCES:{},i18next:engine};
 vm.runInNewContext(script,{window,console});
 assert.equal(element.textContent,'Inbox');
 assert.equal(attrs.placeholder,'Recipient…');
 assert.equal(attrs.title,'Close window');
 engine.changeLanguage('ar');
 assert.equal(window.RPI18nPlateau.locale(),'ar');
 assert.equal(element.textContent,'Messages');
 assert.equal(attrs.placeholder,'Destinataire…');
 assert.equal(attrs['aria-label'],'Fermer');
 assert.equal(attrs.title,'Fermer la fenêtre');
 assert.equal(attrs.dir,undefined);
 assert.equal(element.value,'Saisie non modifiée');
 engine.changeLanguage('en');
 assert.equal(element.textContent,'Inbox');
 assert.equal(attrs.placeholder,'Recipient…');
});
test('un attribut absent ne reste pas artificiellement présent après une traduction',()=>{
 const attrs={'data-i18n-title':'plateau.details'};
 const element={attrs,getAttribute(k){return this.attrs[k]??null},
  hasAttribute(k){return Object.hasOwn(this.attrs,k)},
  setAttribute(k,v){this.attrs[k]=v},removeAttribute(k){delete this.attrs[k]}};
 const document={documentElement:{lang:'fr'},querySelectorAll(selector){
  return selector==='[data-i18n-title]'?[element]:[];
 }};
 const listeners={};
 const engine={language:'en',on(name,fn){listeners[name]=fn},
  init(options,done){this.language=options.lng;done(null)},
  t(){return this.language==='en'?'Details':'plateau.details'},
  changeLanguage(lng){this.language=lng;listeners.languageChanged?.(lng)}};
 const window={RP_I18N_GAME_ENABLED:true,document,localStorage:{getItem:()=> 'en'},
  RP_I18N_LANGUAGES:{fr:{},en:{},ar:{}},RP_I18N_RESOURCES:{},i18next:engine};
 vm.runInNewContext(script,{window,console});
 assert.equal(attrs.title,'Details');
 engine.changeLanguage('ar');
 assert.equal(Object.hasOwn(attrs,'title'),false);
});

test('les textes et titres pilotés par les mécanismes métier ne portent pas de traduction statique',()=>{
 const html=fs.readFileSync(path.join(__dirname,'../../plateau.html'),'utf8');
 const dynamicIds=[
  'piece-desc','pnj-modal-title','postes-modal-title','forum-view-subtitle',
  'mail-view-subtitle','action-context-bat','minimap-ville-title','carte-postale-modal-title'
 ];
 for(const id of dynamicIds){
  const tag=html.match(new RegExp('<[^>]*\\bid="'+id+'"[^>]*>'));
  assert.ok(tag,'noeud dynamique absent : '+id);
  assert.doesNotMatch(tag[0],/\bdata-i18n(?:-uppercase)?(?:=|\s|>)/,
    'un changement de langue écraserait le contenu métier de '+id);
 }
 // Les libellés purement décoratifs restent traduits via i18next.
 assert.match(html,/data-i18n="plateau.character"/);
 assert.match(html,/data-i18n="plateau.messagesForums"/);
});

test('bascule arabe : rétablir le dir initial, y compris après traduction manquante',()=>{
 const attrs={'data-i18n':'plateau.messages',dir:'ltr'};
 const element={textContent:'Messages',attrs,
  getAttribute(k){return this.attrs[k]??null},
  hasAttribute(k){return Object.hasOwn(this.attrs,k)},
  setAttribute(k,v){this.attrs[k]=v},removeAttribute(k){delete this.attrs[k]}};
 const document={documentElement:{lang:'fr'},querySelectorAll(sel){return sel==='[data-i18n]'?[element]:[]}};
 const listeners={};
 const engine={language:'en',on(name,fn){listeners[name]=fn},
  init(opts,done){this.language=opts.lng;done(null)},
  t(key){return this.language==='ar'?'الرسائل':this.language==='en'?'Messages':key},
  changeLanguage(lng){this.language=lng;listeners.languageChanged?.(lng)}};
 const window={RP_I18N_GAME_ENABLED:true,document,localStorage:{getItem:()=> 'en'},
  RP_I18N_LANGUAGES:{fr:{},en:{},ar:{},ko:{}},RP_I18N_RESOURCES:{},i18next:engine};
 vm.runInNewContext(script,{window,console});
 assert.equal(attrs.dir,'ltr');
 engine.changeLanguage('ar');
 assert.equal(attrs.dir,'rtl');
 engine.changeLanguage('en');
 assert.equal(attrs.dir,'ltr');
 engine.changeLanguage('ko'); // traduction manquante => source et direction initiales
 assert.equal(element.textContent,'Messages');
 assert.equal(attrs.dir,'ltr');
});

test('bascule appelle le rafraîchissement des ordres visibles sans entrer de nouveau dans la pièce',()=>{
 const listeners={};
 const orderRefresh=[];
 const element={textContent:'Messages',attrs:{'data-i18n':'plateau.messages'},
  getAttribute(k){return this.attrs[k]},hasAttribute(k){return Object.hasOwn(this.attrs,k)},
  setAttribute(k,v){this.attrs[k]=v},removeAttribute(k){delete this.attrs[k]}};
 const document={documentElement:{lang:'fr'},querySelectorAll(sel){return sel==='[data-i18n]'?[element]:[]}};
 const engine={language:'fr',on(evt,fn){listeners[evt]=fn},
  init(opts,done){this.language=opts.lng;done(null)},
  t(key){return key==='plateau.messages'?(this.language==='ar'?'الرسائل':'Messages'):key},
  changeLanguage(lang){this.language=lang;listeners.languageChanged?.(lang)}};
 const window={RP_I18N_GAME_ENABLED:true,document,localStorage:{getItem:()=> 'fr'},
  RP_I18N_LANGUAGES:{fr:{},ar:{},en:{}},RP_I18N_RESOURCES:{},i18next:engine,
  RPOrderI18n:{refreshVisibleLabels(root,selected,locale){orderRefresh.push({root,selected,locale})}}};
 vm.runInNewContext(script,{window,console});
 engine.changeLanguage('ar');
 assert.equal(orderRefresh.length,1);
 assert.equal(orderRefresh[0].root,document);
 assert.equal(orderRefresh[0].selected,engine);
 assert.equal(orderRefresh[0].locale,'ar');
 assert.equal(document.documentElement.lang,'ar');
 assert.equal(element.textContent,'الرسائل');
 engine.changeLanguage('en');
 assert.equal(orderRefresh.length,2);
 assert.equal(orderRefresh[1].locale,'en');
});
