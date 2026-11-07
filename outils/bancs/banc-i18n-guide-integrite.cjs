'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const game=fs.readFileSync(path.join(root,'plateau-personnage.js'),'utf8');
const token='const REGLES = ';
const begin=game.indexOf(token);
const open=begin+token.length;
const close=game.indexOf('\n};',open);
assert.ok(begin>=0&&close>open,'REGLES non retrouvées');
const regles=vm.runInNewContext('('+game.slice(open,close+2)+')');
const window={};
vm.runInNewContext(fs.readFileSync(path.join(root,'i18n/guide-integrity.js'),'utf8'),{window});
const integrity=window.RPGuideIntegrity;

test('les neuf rubriques françaises correspondent exactement aux traductions relues',()=>{
 const expected=['tuto','intro','personnage','plateau','politique','interactions','sport','religion','economie'];
 assert.deepEqual(Object.keys(regles),expected);
 for(const section of expected)
  assert.equal(integrity.valid(section,regles[section]),true,section);
});
test('changement métier : refus de traduction et maintien de la version française',()=>{
 for(const section of ['personnage','plateau','politique','interactions','sport','religion','economie']){
  const old=regles[section];
  const modified={...old,contenu:old.contenu+'\nNouvelle règle métier.'};
  assert.equal(integrity.valid(section,modified),false,section);
 }
 assert.equal(integrity.valid('inconnu',{titre:'X',contenu:'Y'}),false);
 assert.equal(integrity.valid('plateau',null),false);
});
test('rendu du guide vérifie son empreinte et n utilise jamais une traduction périmée',()=>{
 const html=fs.readFileSync(path.join(root,'plateau.html'),'utf8');
 const source=html.indexOf('src="i18n/guide-integrity.js');
 const init=html.indexOf('src="i18n/plateau-init.js');
 assert.ok(source>=0 && init>source);
 assert.match(game,/RPGuideIntegrity\?\.valid\?\.\(section,regle\)/);
 assert.match(game,/!guideTraductionValide/);
});
