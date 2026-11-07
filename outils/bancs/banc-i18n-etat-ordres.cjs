'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const report=require('../audits/etat-i18n-ordres.cjs');

test('couverture des 237 identifiants sans faux positifs de source',()=>{
 assert.equal(report.locales.length,9);
 assert.equal(report.catalogueFrenchKeys,237);
 assert.equal(report.canonicalMatches,237);
 assert.equal(report.obsoleteCanonical.length,0);
 for(const [locale,data] of Object.entries(report.perLocale)){
  assert.equal(data.keys,237,locale);
  assert.deepEqual(data.missing,[],locale);
  assert.deepEqual(data.extra,[],locale);
 }
});
test('les ordres non traduits restent visibles dans un inventaire reproductible',()=>{
 assert.ok(report.sourceUniqueIds>=report.catalogueFrenchKeys);
 assert.ok(report.stableNotCovered+report.ambiguousNotCovered>0,
  'ne pas déclarer tout le jeu traduit avant un vrai raccordement exhaustif');
 for(const item of report.missingStable)
  assert.ok(item.fn && typeof item.label==='string');
});
