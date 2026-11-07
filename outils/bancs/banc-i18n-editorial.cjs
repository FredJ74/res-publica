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
