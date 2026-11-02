'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
const path=require('node:path');
const root=path.join(__dirname,'../..');
const win={};vm.createContext({window:win});
const ctx=vm.createContext({window:win});
for(const filename of ['resources.js','plateau-resources.js']) vm.runInContext(fs.readFileSync(path.join(root,'i18n',filename),'utf8'),ctx);
test('libellés du plateau complets et identiques dans neuf catalogues',()=>{
 const langs=Object.keys(win.RP_I18N_LANGUAGES);
 assert.equal(langs.length,9);
 const reference=Object.keys(win.RP_I18N_RESOURCES.fr.translation.plateau);
 assert.ok(reference.length>=14);
 for(const lang of langs) {
  const labels=win.RP_I18N_RESOURCES[lang].translation.plateau;
  assert.deepEqual(Object.keys(labels),reference,lang);
  for(const label of Object.values(labels)) assert.ok(typeof label==='string'&&label.trim().length>0);
 }
});

test('toutes les clés câblées au HTML du plateau existent dans les neuf langues',()=>{
 const html=fs.readFileSync(path.join(root,'plateau.html'),'utf8');
 const keys=[...html.matchAll(/data-i18n="plateau\.([a-zA-Z]+)"/g)].map(m=>m[1]);
 assert.ok(keys.length>=20,'Trop peu de libellés câblés au plateau');
 for(const lang of Object.keys(win.RP_I18N_LANGUAGES)) {
  const catalog=win.RP_I18N_RESOURCES[lang].translation.plateau;
  for(const key of keys) assert.ok(catalog[key],lang+':'+key);
 }
});
