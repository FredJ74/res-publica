'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const win={};
const ctx=vm.createContext({window:win});
for(const file of ['resources.js','guide-resources.js'])
 vm.runInContext(fs.readFileSync(path.join(root,'i18n',file),'utf8'),ctx);
const original=fs.readFileSync(path.join(root,'plateau-personnage.js'),'utf8');
const start=original.indexOf('function renderRulesContent(section) {');
const end=original.indexOf('\n}\n',start);
assert.ok(start>=0&&end>start);
const fn=original.slice(start,end+2);

test('tutoriel initial disponible pour huit langues + repli FR',()=>{
 const langs=Object.keys(win.RP_I18N_LANGUAGES);
 assert.equal(langs.length,9);
 for(const lng of langs.filter(x=>x!=='fr')){
  const d=win.RP_I18N_RESOURCES[lng].translation.guide.tuto;
  assert.ok(d.titre.trim(),lng+' titre');
  assert.ok(d.contenu.trim().length>600,lng+' contenu');
  assert.equal((d.contenu.match(/^━+$/gm)||[]).length,12,lng+' cinq étapes et conseils');
 }
 const html=fs.readFileSync(path.join(root,'plateau.html'),'utf8');
 assert.ok(html.indexOf('i18n/guide-resources.js')>html.indexOf('i18n/resources.js'));
 assert.ok(html.indexOf('i18n/guide-resources.js')<html.indexOf('i18n/plateau-init.js'));
});

function render(lang,unsafe=false,section='tuto'){
 const el={innerHTML:''};
 const window={
  RPPlateauI18n:{language:()=>lang},
  i18next:{t(key,opts){
   if(unsafe)return '<img src=x onerror="evil()"> & test';
   return key.split('.').reduce((value,part)=>value?.[part],
    win.RP_I18N_RESOURCES[lang]?.translation)??opts.defaultValue;
  }}
 };
 const document={
  querySelectorAll:()=>[],
  getElementById:(id)=>id==='rules-content'?el:null
 };
 vm.runInNewContext(fn+';renderRulesContent('+JSON.stringify(section)+')',{window,document,REGLES:{tuto:{titre:'FR TITRE',contenu:'FR TEXTE'},intro:{titre:'FR INTRO',contenu:'FR TEXTE INTRO'}}});
 return el.innerHTML;
}
test('le guide rend l’anglais et l’arabe dans le moteur existant, sans nouveau handler',()=>{
 const en=render('en');
 assert.ok(en.includes('Tutorial — First steps'));
 assert.ok(en.includes('STEP 1'));
 const ar=render('ar');
 assert.ok(ar.includes('الخطوة 1'));
 assert.ok(!ar.includes('FR TEXTE'));
 const fr=render('fr');
 assert.ok(fr.includes('FR TEXTE'));
});
test('les balises dans des traductions ne deviennent jamais du HTML actif',()=>{
 const html=render('en',true);
 assert.ok(html.includes('&lt;img'));
 assert.ok(!html.includes('<img'));
 assert.ok(html.includes('&amp;'));
});


test('introduction du jeu disponible et rendue dans les huit langues',()=>{
 const languages=Object.keys(win.RP_I18N_LANGUAGES).filter(x=>x!=='fr');
 for(const lang of languages){
  const intro=win.RP_I18N_RESOURCES[lang].translation.guide.intro;
  assert.ok(intro?.titre?.trim(),lang+' titre');
  assert.ok(intro?.contenu?.includes('Panem et circenses'),lang+' texte');
  // Les écritures idéographiques expriment le même contenu en moins de caractères.
  assert.ok(intro.contenu.length>250,lang+' trop court');
  assert.equal(intro.contenu.split('\n\n').length,4,lang+' quatre paragraphes');
  const html=render(lang,false,'intro');
  assert.ok(html.includes('Panem et circenses'));
  assert.ok(!html.includes('FR TEXTE INTRO'));
 }
 assert.ok(render('fr',false,'intro').includes('FR TEXTE INTRO'));
});
