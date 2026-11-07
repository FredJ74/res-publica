'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');
const root=path.resolve(__dirname,'../..');
const source=fs.readFileSync(path.join(root,'plateau-quete-accueil.js'),'utf8');
const scene=fs.readFileSync(path.join(root,'i18n/jeremy-scenes-resources.js'),'utf8');
const window={};let language='fr';
window.RPPlateauI18n={language:()=>language};
window.i18next={t:(key,{lng,defaultValue}={})=>key.split('.').reduce((v,k)=>v?.[k],window.RP_I18N_RESOURCES[lng].translation)??defaultValue};
const context=vm.createContext({window});
for(const file of ['resources.js','jeremy-scenes-resources.js'])
 vm.runInContext(fs.readFileSync(path.join(root,'i18n',file),'utf8'),context,{filename:file});
const french=window.RP_I18N_RESOURCES.fr.translation.jeremyScenes;
test('une visite de stade et deux titres de rue disponibles dans les neuf langues',()=>{
 assert.equal(Object.keys(window.RP_I18N_LANGUAGES).length,9);
 for(const lang of Object.keys(window.RP_I18N_LANGUAGES)){
  language=lang;
  const labels=window.RP_I18N_RESOURCES[lang].translation.jeremyScenes;
  for(const key of ['stadium','followRoadTitle','townHallStreetTitle']){
   assert.ok(typeof labels[key]==='string'&&labels[key].trim(),lang+': '+key);
   assert.equal(window.RPJeremyScenesI18n.label(key,french[key]),labels[key],lang+': rendu');
  }
  // Les étapes de la visite restent des paragraphes séparés dans chaque langue.
  assert.equal(labels.stadium.split('<br><br>').length,6,lang+': six paragraphes');
  assert.ok(!/<(?!br\s*\/?\s*>)/i.test(labels.stadium),lang+': balises non prévues');
 }
});
test('seules les chaînes de présentation changent, pas le stade ni ses règles',()=>{
 assert.ok(source.includes("rpQueteTexte('stadium'"));
 assert.ok(source.includes("rpQueteTexte('followRoadTitle'"));
 assert.ok(source.includes("rpQueteTexte('townHallStreetTitle'"));
 assert.ok(source.includes("if (etape === 'guide_stade' && buildingId === 'stade')"));
 assert.ok(source.includes("state.char.queteAccueil = { etape: 'stade_attente_action' }"));
 assert.ok(source.includes("if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {})"));
 for(const k of ['keepDirection','selectBuilding'])assert.ok(source.includes("rpQueteTexte('"+k+"'"));
});
test('la traduction n’écrase pas une variante française, un nom de joueur ni un texte inconnu',()=>{
 language='ru';
 assert.equal(window.RPJeremyScenesI18n.label('stadium',french.stadium+' — scène spéciale'),
  french.stadium+' — scène spéciale');
 assert.equal(window.RPJeremyScenesI18n.label('unmapped','Nom joueur'), 'Nom joueur');
 assert.ok(scene.includes('const visitTitles='));
});
