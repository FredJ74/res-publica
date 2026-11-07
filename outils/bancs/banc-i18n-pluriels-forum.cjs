'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const forum=fs.readFileSync(path.join(root,'forum.js'),'utf8');
const win={};let lng='fr';
win.RPPlateauI18n={language:()=>lng};
win.i18next={t:(key,{lng:locale,defaultValue}={})=>key.split('.').reduce((v,k)=>v?.[k],win.RP_I18N_RESOURCES[locale]?.translation)??defaultValue};
const context=vm.createContext({window:win});
for(const file of ['resources.js','forum-ui.js'])
 vm.runInContext(fs.readFileSync(path.join(root,'i18n',file),'utf8'),context);
const count=(kind,n,original)=>win.RPForumUI.count(kind,n,original);
test('neuf locales, langue française strictement compatible',()=>{
 assert.equal(Object.keys(win.RP_I18N_LANGUAGES).length,9);
 lng='fr';
 for(const [kind,n,text] of [['subjects',1,'1 sujet(s)'],['subjects',null,'… sujet(s)'],['unread',2,'2 non lu(s)']])
  assert.equal(count(kind,n,text),text);
});
test('formes simples et langue sans pluriel grammatical',()=>{
 for(const [lang,n,word] of [
  ['en',1,'1 topic'],['en',4,'4 topics'],['es',2,'2 temas'],
  ['zh-TW',5,'5 個主題'],['ko',2,'2 개 주제'],
  ['pt-BR',1,'1 tópico'],['pt-BR',2,'2 tópicos'],
  ['de',1,'1 Thema'],['de',3,'3 Themen']
 ]){lng=lang;assert.equal(count('subjects',n,'source'),word,lang+' '+n);}
});
test('formes russes et arabes : 0, 1, 2, 3, 5, 11 et 21',()=>{
 lng='ru';
 for(const [n,label] of [[1,'тема'],[2,'темы'],[5,'тем'],[11,'тем'],[21,'тема']])
  assert.equal(count('subjects',n,'source'),n+' '+label,'ru '+n);
 lng='ar';
 for(const [n,label] of [[0,'مواضيع'],[1,'موضوع'],[2,'موضوعان'],[3,'مواضيع'],[11,'موضوعًا']])
  assert.equal(count('subjects',n,'source'),n+' '+label,'ar '+n);
});
test('absence serveur ne devient jamais zéro, valeurs invalides inchangées',()=>{
 lng='en';
 assert.equal(count('subjects',null,'… sujet(s)'),'… topics');
 assert.equal(count('unread',null,'… non lu(s)'),'… unread');
 for(const bad of [-1,NaN,1.25,Infinity,'2',undefined]){
  assert.equal(count('subjects',bad,'source'),'source');
 }
 assert.equal(count('unsupported',2,'source'),'source');
 assert.ok(forum.includes("rpForumCompte('subjects',null,'… sujet(s)')"));
 assert.ok(forum.includes("rpForumCompte('unread',unreadCount,unreadCount+' non lu(s)')"));
 assert.ok(forum.includes('FORUM_LECTURE_ECHOUEE[id]'));
 assert.ok(forum.includes('Object.prototype.hasOwnProperty.call(forumCompteursServeur, id)'));
});
