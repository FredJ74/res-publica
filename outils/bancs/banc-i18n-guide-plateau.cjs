'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const files=['resources.js','guide-resources.js','guide-plateau-resources.js'];
const win={};
const sandbox=vm.createContext({window:win});
for(const file of files)vm.runInContext(fs.readFileSync(path.join(root,'i18n',file),'utf8'),sandbox);
const locales=['en','es','zh-TW','ru','ko','ar','pt-BR','de'];

test('huit langues du guide du plateau disposent d un titre et du contenu',()=>{
 for(const locale of locales){
  const section=win.RP_I18N_RESOURCES[locale].translation.guide.plateau;
  assert.ok(section?.titre?.trim(),locale+' titre');
  assert.ok(section?.contenu?.trim(),locale+' contenu');
  assert.ok(section.contenu.includes('24'),locale+' PA');
  assert.ok(section.contenu.includes('1–100'),locale+' jet 1–100');
  for(const stat of ['INF','POP','DIS'])assert.ok(section.contenu.includes(stat),locale+'/'+stat);
  assert.ok(section.contenu.includes('0'),locale+' santé 0');
 }
 assert.equal(win.RP_I18N_RESOURCES.fr.translation.guide,undefined,'source française REGLES conservée');
});

test('le plateau charge l extension après le dictionnaire guide, avant son moteur',()=>{
 const html=fs.readFileSync(path.join(root,'plateau.html'),'utf8');
 const a=html.indexOf('src="i18n/guide-resources.js');
 const b=html.indexOf('src="i18n/guide-plateau-resources.js');
 const c=html.indexOf('src="i18n/plateau-init.js');
 assert.ok(a>=0&&b>a&&c>b,'ordre de chargement guide invalide');
});

test('ne remplace pas une section plateau déjà fournie par un autre catalogue',()=>{
 const section={titre:'Existant',contenu:'Déjà fourni'};
 const own={RP_I18N_RESOURCES:{en:{translation:{guide:{plateau:section}}}}};
 vm.runInNewContext(fs.readFileSync(path.join(root,'i18n/guide-plateau-resources.js'),'utf8'),{window:own});
 assert.equal(own.RP_I18N_RESOURCES.en.translation.guide.plateau,section);
});
