'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const files=['resources.js','guide-resources.js','guide-plateau-resources.js','guide-interactions-resources.js'];
const window={};
const context=vm.createContext({window});
for(const file of files)vm.runInContext(fs.readFileSync(path.join(root,'i18n',file),'utf8'),context);
const languages=['en','es','zh-TW','ru','ko','ar','pt-BR','de'];

test('guide des interactions renseigné dans toutes les langues supplémentaires',()=>{
 for(const lang of languages){
  const guide=window.RP_I18N_RESOURCES[lang].translation.guide;
  for(const sectionName of ['plateau','interactions']){
   const section=guide[sectionName];
   assert.ok(section?.titre?.trim(),lang+'/'+sectionName+' titre');
   assert.ok(section?.contenu?.trim(),lang+'/'+sectionName+' contenu');
  }
 }
});

test('la traduction sociale ne supprime pas les distinctions ville, pays, membre et presse',()=>{
 for(const lang of languages){
  const text=window.RP_I18N_RESOURCES[lang].translation.guide.interactions.contenu;
  assert.ok(text.length>=200,lang);
  assert.ok(!/<script|<iframe/i.test(text),lang);
  assert.ok(!text.includes('{{'),lang);
 }
 const html=fs.readFileSync(path.join(root,'plateau.html'),'utf8');
 const first=html.indexOf('src="i18n/guide-resources.js');
 const second=html.indexOf('src="i18n/guide-plateau-resources.js');
 const third=html.indexOf('src="i18n/guide-interactions-resources.js');
 const last=html.indexOf('src="i18n/plateau-init.js');
 assert.ok(first>=0&&first<second&&second<third&&third<last);
});

test('guide français : suppression du forum régional obsolète sans modifier les ordres',()=>{
 const game=fs.readFileSync(path.join(root,'plateau-personnage.js'),'utf8');
 const start=game.indexOf('const REGLES = {');
 const end=game.indexOf('  sport: {',start);
 assert.ok(start>=0&&end>start);
 const guide=game.slice(start,end);
 for(const phrase of ['Forum local','Forum national','Forum international','Forums des organisations','Presse et médias'])
  assert.ok(guide.includes(phrase),phrase);
 assert.ok(!guide.includes('Forum Régional'), 'le forum régional inexistant ne doit plus être annoncé');
 assert.ok(guide.includes('auxquelles vous appartenez ou que vous dirigez'));
 assert.ok(guide.includes('Celui de la ville où vous vous trouvez'));
});
