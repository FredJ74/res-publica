'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const audit=require('../audits/audit-i18n-editorial.cjs');
test('les neuf langues couvrent les catalogues de base sans variables perdues',()=>{
 assert.equal(audit.languages.length,9);
 assert.ok(audit.referenceKeys>=700,'nombre de ressources anormalement réduit');
 for(const lang of audit.languages){
  const result=audit.results[lang];
  assert.deepEqual(result.missing,[],lang+' clés manquantes');
  assert.deepEqual(result.placeholderMismatch,[],lang+' placeholders');
 }
});
test('les traductions identiques et unités monétaires restent visibles pour relecture',()=>{
 assert.ok(audit.results.en.unchanged.length>0);
 for(const lang of audit.languages){
  const r=audit.results[lang];
  assert.ok(Array.isArray(r.currencyReview));
  assert.ok(Array.isArray(r.extra));
  assert.ok(r.keys>=audit.referenceKeys);
 }
});

test('tout catalogue de ressources chargé par le plateau ou l’accueil est inclus dans la mesure',()=>{
 const fs=require('node:fs'),path=require('node:path');
 const html=['plateau.html','index.html'].map(f=>fs.readFileSync(path.join(__dirname,'../..',f),'utf8')).join('\n');
 const files=[...html.matchAll(/src="i18n\/([^"?]+\.js)(?:\?[^"\s]*)?"/g)].map(m=>m[1])
  .filter(n=>n==='resources.js'||n==='forum-ui.js'||n.endsWith('-resources.js'));
 for(const file of files)assert.ok(audit.sourceFiles.includes(file),file+' absent de l’audit éditorial');
});
