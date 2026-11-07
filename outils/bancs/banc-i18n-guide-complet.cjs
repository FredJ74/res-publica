'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const window={};const ctx=vm.createContext({window});
const files=['resources.js','guide-resources.js','guide-plateau-resources.js',
 'guide-interactions-resources.js','guide-politique-resources.js',
 'guide-sport-resources.js','guide-economie-resources.js','guide-religion-resources.js'];
for(const file of files)
 vm.runInContext(fs.readFileSync(path.join(root,'i18n',file),'utf8'),ctx);
const languages=['en','es','zh-TW','ru','ko','ar','pt-BR','de'];
const names=['tuto','intro','personnage','plateau','politique','interactions','sport','religion','economie'];

test('neuf rubriques du guide ont un titre et un contenu dans chacune des huit traductions',()=>{
 for(const lang of languages){
  const sections=window.RP_I18N_RESOURCES[lang].translation.guide;
  for(const name of names){
   assert.ok(sections[name]?.titre?.trim(),lang+'/'+name+'/titre');
   assert.ok(sections[name]?.contenu?.trim(),lang+'/'+name+'/contenu');
  }
 }
 assert.equal(window.RP_I18N_RESOURCES.fr.translation.guide,undefined,
  'la source originale française reste exclusivement dans REGLES');
});

test('religion : chiffres, confidentialité, villes, et propriétés des offices inchangés',()=>{
 for(const lang of languages){
  const text=window.RP_I18N_RESOURCES[lang].translation.guide.religion.contenu;
  for(const name of ['Republia','El Estado','Sovarka','Al-Khalija',
   'Luthécia','Port-Sainte-Marie','Montrouge','Père Ception','Père Iscope','Abbé Tonnière'])
   assert.ok(text.includes(name),lang+'/'+name);
  for(const number of ['12','100','40','7','200','80%','24','10','25','45','50','15'])
   assert.ok(text.includes(number),lang+'/'+number);
  assert.ok(text.length>500,lang);
 }
});

test('les sept scripts du guide sont chargés avant initialisation et ne touchent pas au monde',()=>{
 const html=fs.readFileSync(path.join(root,'plateau.html'),'utf8');
 let previous=-1;
 for(const file of files.slice(1)){
  const index=html.indexOf('src="i18n/'+file);
  assert.ok(index>previous,file);
  previous=index;
 }
 assert.ok(previous<html.indexOf('src="i18n/plateau-init.js'));
 const source=fs.readFileSync(path.join(root,'plateau-personnage.js'),'utf8');
 assert.ok(source.includes('const REGLES = {'));
 assert.ok(source.includes('  religion: {'));
});
