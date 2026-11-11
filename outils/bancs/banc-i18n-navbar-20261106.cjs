'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const read=name=>fs.readFileSync(path.join(root,name),'utf8');
const html=read('plateau.html');
const ids=['imperialIndices','help','messagesForums','players','orgs','elections','worldMap','plan'];
const titles=['indicesTitle','forumsTitle','playersTitle','orgsTitle','electionsTitle','footballTitle','planTitle','forumActivity'];

function fixture(locale) {
 const window={RP_I18N_GAME_ENABLED:true};
 const ctx=vm.createContext({window,console});
 vm.runInContext(read('i18n/resources.js'),ctx);
 vm.runInContext(read('i18n/plateau-resources.js'),ctx);
 const label={attributes:{'data-i18n':'plateau.imperialIndices','data-i18n-uppercase':''},textContent:'INDICES IMPERIAUX',
   getAttribute(k){return this.attributes[k]},hasAttribute(k){return Object.hasOwn(this.attributes,k)},
   setAttribute(k,v){this.attributes[k]=v},removeAttribute(k){delete this.attributes[k]}};
 const button={attributes:{'data-i18n-title':'plateau.indicesTitle',title:'Indices des 4 empires'},
   childNodes:[{nodeName:'I',className:'ti ti-chart-bar'},label,{nodeName:'SPAN',id:'mail-badge'}],
   getAttribute(k){return this.attributes[k]},hasAttribute(k){return Object.hasOwn(this.attributes,k)},
   setAttribute(k,v){this.attributes[k]=v},removeAttribute(k){delete this.attributes[k]}};
 const doc={documentElement:{lang:'fr'},querySelectorAll(selector){
   if(selector==='[data-i18n]')return [label];
   if(selector==='[data-i18n-title]')return [button];
   return [];
 }};
 window.document=doc;
 window.localStorage={getItem:(key)=>key==='respublica_language'?locale:null};
 window.i18next={init(opts,cb){this.options=opts;cb(null)},t(key){return key.split('.').reduce((obj,k)=>obj?.[k],window.RP_I18N_RESOURCES[this.options.lng]?.translation)??key}};
 vm.runInContext(read('i18n/plateau-init.js'),ctx);
 return {window,label,button,doc};
}

test('la navigation dispose des huit boutons et huit descriptions dans neuf langues',()=>{
 const {window}=fixture('fr');
 const lang=Object.keys(window.RP_I18N_LANGUAGES);
 assert.equal(lang.length,9);
 for(const locale of lang){
  const values=window.RP_I18N_RESOURCES[locale].translation.plateau;
  for(const id of [...ids,...titles])assert.ok(typeof values[id]==='string' && values[id].trim(),locale+':'+id);
 }
});

test('les spans de navigation sont localisés sans déplacer les icônes ou compteurs',()=>{
 for(const locale of ['en','ar','de']){
  const {window,label,button,doc}=fixture(locale);
  const dict=window.RP_I18N_RESOURCES[locale].translation.plateau;
  assert.equal(doc.documentElement.lang,locale);
  assert.equal(label.textContent,dict.imperialIndices.toLocaleUpperCase(locale));
  assert.equal(button.attributes.title,dict.indicesTitle);
  assert.equal(button.childNodes[0].className,'ti ti-chart-bar');
  assert.equal(button.childNodes[2].id,'mail-badge');
  assert.equal(button.childNodes.length,3);
  assert.equal(label.attributes.dir,locale==='ar'?'rtl':undefined);
 }
});

test('le HTML ne traduit pas les boutons entiers et conserve les gestionnaires',()=>{
 for(const id of ids){
  assert.ok(html.includes('data-i18n="plateau.'+id+'"'),id);
  const bad=new RegExp('<button[^>]*data-i18n="plateau\\.'+id+'"');
  assert.doesNotMatch(html,bad,'ne pas remplacer le contenu entier du bouton: '+id);
 }
 for(const id of titles)assert.ok(html.includes('data-i18n-title="plateau.'+id+'"'),id);
 for(const fn of ['ouvrirIndicesImperiaux','openRulesView','openForumView','ouvrirRepertoirePJ',
    'ouvrirTableauOrganisations','ouvrirCalendrierElectoral','openWorldMap','ouvrirPlanVille'])
  assert.ok(html.includes('onclick="'+fn+'()"'),fn);
 assert.ok(html.includes('id="mail-badge"'));
 assert.ok(html.includes('id="forum-activity-dot"'));
});
