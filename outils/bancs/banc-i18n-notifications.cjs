'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const root=path.resolve(__dirname,'../..');
const core=fs.readFileSync(path.join(root,'plateau-core.js'),'utf8');
const page=fs.readFileSync(path.join(root,'plateau.html'),'utf8');
const win={};let lang='fr';
win.RPPlateauI18n={language:()=>lang};
win.i18next={t:(key,{lng,defaultValue}={})=>key.split('.').reduce((obj,k)=>obj?.[k],win.RP_I18N_RESOURCES[lng].translation)??defaultValue};
const ctx=vm.createContext({window:win});
for(const file of ['resources.js','toast-resources.js'])vm.runInContext(fs.readFileSync(path.join(root,'i18n',file),'utf8'),ctx,{filename:file});
test('34 titres de notification conformes dans neuf langues, hors messages libres',()=>{
 const langs=Object.keys(win.RP_I18N_LANGUAGES);
 assert.equal(langs.length,9);
 const expected=Object.keys(win.RP_I18N_RESOURCES.fr.translation.toastTitles);
 assert.equal(expected.length,34);
 for(const language of langs){
  lang=language;
  const titles=win.RP_I18N_RESOURCES[language].translation.toastTitles;
  assert.deepEqual(Object.keys(titles).sort(),expected.sort(),language+': clés');
  for(const title of Object.values(titles))assert.ok(typeof title==='string'&&title.trim(),language);
 }
 lang='ru';
 assert.equal(win.RPToastI18n.label('Action impossible'),win.RP_I18N_RESOURCES.ru.translation.toastTitles.actionImpossible);
 assert.equal(win.RPToastI18n.label('Fiche non synchronisée'),win.RP_I18N_RESOURCES.ru.translation.toastTitles.sheetNotSynced);
 assert.equal(win.RPToastI18n.label('Forum introuvable'),win.RP_I18N_RESOURCES.ru.translation.toastTitles.forumNotFound);
 for(const text of ['Erreur technique — 411','Arnie','Action impossible : 75 FR','{{placeholder}}',''])
  assert.equal(win.RPToastI18n.label(text),text,'inconnu jamais traduit');
});
test('incident et sous-message non modifiés, titre non injecté en HTML',()=>{
 const start=core.indexOf('function showToast('),end=core.indexOf('// =====================',start);
 assert.ok(start>=0&&end>start);
 const body=core.slice(start,end);
 assert.ok(body.includes("noterIncidentSession('notification', result)"));
 assert.ok(body.includes("document.getElementById('toast-sub').textContent = msg"));
 assert.ok(body.includes("RPToastI18n.label(result)"));
 assert.ok(body.includes("document.getElementById('toast-result').textContent ="));
 assert.ok(!body.includes('innerHTML'));
 const bridge=page.indexOf('src="i18n/plateau-bridge.js');
 const file=page.indexOf('src="i18n/toast-resources.js');
 const init=page.indexOf('src="i18n/plateau-init.js');
 assert.ok(bridge>=0&&file>bridge&&init>file);
});
