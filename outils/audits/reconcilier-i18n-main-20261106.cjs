#!/usr/bin/env node
'use strict';
// Reconciliation uniquement dans le workspace de la PR brouillon, apres fusion de main.
// Conserve toutes les ressources francaises et les nouvelles donnees metier de main.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root=path.resolve(__dirname,'../..');
const resourcePath=path.join(root,'i18n/resources.js');
const existing=fs.readFileSync(resourcePath,'utf8');
const context=vm.createContext({window:{}});
vm.runInContext(existing,context);
const dictionaries=context.window.RP_I18N_RESOURCES;
assert.ok(dictionaries?.fr?.translation?.creation?.common?.careerUseful);
const required=['INT','CHA','VOL','PER','DUP','ENT'];
const patches={
  ar:{
    common:{careerUseful:'مفيد لمسارك المهني',examplesLabel:'في اللعبة'},
    examples:{
      INT:'الاستثمارات المالية، السرقة، التسميم، والتأثير في مؤشرات المدينة.',
      CHA:'المنشورات الانتخابية، المساومة في المجلس، رشوة الصحافة، التفاوض على الأراضي، وتبرير الموقف عند الاستدعاء.',
      VOL:'القتال، الهرب من الشرطة أو مقاومتها، التمرد أثناء الاحتجاز، قمع المظاهرات، والمعارك العسكرية.',
      PER:'القتال، مكافحة التجسس، تفتيش الشحنات لدى الجمارك، كشف الأعمال غير القانونية، والسرقة.',
      DUP:'الهروب من السجن، التهريب، رشوة موظف الجمارك، استمالة شخصية غير لاعبة، وتجنب القبض أثناء التلبس.',
      ENT:'المساومة في المجلس، تقديم جولة مشروبات في الحانة، وبناء شبكة علاقات.'
    }
  },
  'pt-BR':{
    common:{careerUseful:'Útil para sua carreira',examplesLabel:'No jogo'},
    examples:{
      INT:'Investimentos financeiros, furtos, envenenamentos e ações sobre os indicadores da cidade.',
      CHA:'Panfletos eleitorais, negociações na Assembleia, suborno da imprensa, negociação de terrenos e explicações após uma intimação.',
      VOL:'Combates, fuga ou resistência à polícia, rebelião durante a detenção, repressão de protestos e batalhas militares.',
      PER:'Combates, contraespionagem, fiscalização de cargas na alfândega, detecção de ações ilegais e furtos.',
      DUP:'Fuga da prisão, contrabando, suborno de um agente alfandegário, aliciamento de PNJs e evasão de flagrante.',
      ENT:'Negociação na Assembleia, pagar uma rodada no bar e construir uma rede de contatos.'
    }
  },
  de:{
    common:{careerUseful:'Nützlich für deine Laufbahn',examplesLabel:'Im Spiel'},
    examples:{
      INT:'Geldanlagen, Diebstahl, Vergiftungen und Aktionen, die Stadtindikatoren beeinflussen.',
      CHA:'Wahlflugblätter, Verhandlungen in der Versammlung, Bestechung der Presse, Grundstücksverhandlungen und Rechtfertigung bei Vorladungen.',
      VOL:'Kämpfe, Flucht oder Widerstand gegen die Polizei, Auflehnung in Haft, Niederschlagung von Demonstrationen und militärische Gefechte.',
      PER:'Kämpfe, Spionageabwehr, Zollkontrollen von Fracht, Erkennen illegaler Handlungen und Diebstahl.',
      DUP:'Gefängnisausbruch, Schmuggel, Bestechung von Zollbeamten, Abwerbung von NSC und Entkommen bei einer Festnahme auf frischer Tat.',
      ENT:'Verhandlungen in der Versammlung, eine Runde Getränke in der Bar ausgeben und ein Kontaktnetz aufbauen.'
    }
  }
};
const add={};
for(const [locale,patch] of Object.entries(patches)){
  const original=dictionaries[locale]?.translation?.creation;
  assert.ok(original?.common && original?.stats,'unknown language '+locale);
  for(const key of Object.keys(patch.common)){
    assert.ok(typeof dictionaries.fr.translation.creation.common[key]==='string');
    if(typeof original.common[key]!=='string') (add[locale]??={common:{},examples:{}}).common[key]=patch.common[key];
  }
  for(const name of required){
    assert.ok(typeof dictionaries.fr.translation.creation.stats[name]?.examples==='string');
    if(typeof original.stats[name]?.examples!=='string') (add[locale]??={common:{},examples:{}}).examples[name]=patch.examples[name];
  }
}
assert.equal(Object.keys(add).length,3,'The merge should add 8 keys in each of three locales');
for(const [locale,value] of Object.entries(add)){
  assert.equal(Object.keys(value.common).length,2);
  assert.equal(Object.keys(value.examples).length,6);
}
const marker='// Reconciliation i18n du socle ajoute par main, sans remplacement des anciennes traductions.';
assert.ok(!existing.includes(marker),'reconciliation already applied');
const source=existing+'\n\n'+marker+'\n'+
  ';(function(global){\n'+
  '  const patches='+JSON.stringify(add,null,2)+';\n'+
  '  for(const [locale,patch] of Object.entries(patches)){\n'+
  '    const creation=global.RP_I18N_RESOURCES[locale].translation.creation;\n'+
  '    for(const [key,value] of Object.entries(patch.common)) creation.common[key]=value;\n'+
  '    for(const [name,value] of Object.entries(patch.examples)) creation.stats[name].examples=value;\n'+
  '  }\n'+
  '})(window);\n';
fs.writeFileSync(resourcePath,source);
const politics=path.join(root,'plateau-politique.js');
let renderer=fs.readFileSync(politics,'utf8');
const old=`messageAchatTerrainIntrus + '"><i class="ti ' + o.icon + '"></i> ' + o.label + '</button>';`;
const replacement=`messageAchatTerrainIntrus + '"><i class="ti ' + o.icon + '"></i> ' + libelleAffiche + '</button>';`;
if(renderer.includes(old)){
  assert.ok(renderer.includes('const libelleAffiche ='),'renderer i18n lost during merge');
  renderer=renderer.replace(old,replacement);
  fs.writeFileSync(politics,renderer);
}else{
  assert.ok(renderer.includes(replacement),'blocked button lost during merge');
}
// Le main récent a également changé le bouton normal : l'algorithme de
// merge donne priorité au serveur et peut y restaurer le libellé français.
const normalOriginal=` + o.label + ' <span class="pa-cost">'`;
const normalTranslated=` + libelleAffiche + ' <span class="pa-cost">'`;
if(renderer.includes(normalOriginal)){
  assert.ok(renderer.includes('const libelleAffiche ='),'renderer i18n absent');
  renderer=renderer.replace(normalOriginal,normalTranslated);
  fs.writeFileSync(politics,renderer);
}
assert.equal(renderer.split(' + libelleAffiche + ').length-1,2);
console.log('Reconciliation validée : 24 traductions, bouton bloqué et normal, aucun contrat métier modifié.');
