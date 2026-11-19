'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const report=require('../audits/etat-i18n-ordres.cjs');

test('couverture des 421 identifiants sans faux positifs de source',()=>{
 assert.equal(report.locales.length,9);
 assert.equal(report.catalogueFrenchKeys,421); // −2 corrompre_rdv_notaire, corrompre_chantier (20/11, criminalité lot 7) ; +1 acheter_furet (18/11, maladies lot 2c)
 assert.equal(report.canonicalMatches,421);
 assert.equal(report.obsoleteCanonical.length,0);
 assert.ok(!report.obsoleteCanonical.some(item => item.fn === 'sovarka_soviet_deputes'));
 assert.ok(report.missingStable.every(item => item.fn !== 'sovarka_soviet_deputes'));

 for(const [locale,data] of Object.entries(report.perLocale)){
  assert.equal(data.keys,421,locale);
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
