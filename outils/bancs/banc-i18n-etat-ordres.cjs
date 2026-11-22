'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const report=require('../audits/etat-i18n-ordres.cjs');

test('couverture des 423 identifiants sans faux positifs de source',()=>{
 assert.equal(report.locales.length,9);
 assert.equal(report.catalogueFrenchKeys,423); // −2 corrompre_rdv_notaire, corrompre_chantier (20/11, criminalité lot 7)  ; +1 boutique_climat (19/11, climat lot 5) ; +1 acheter_graisse (19/11, climat lot 4) ; +1 acheter_furet (18/11, maladies lot 2c)
 assert.equal(report.canonicalMatches,417); // acheter_polonium retiré du jeu (20/11) ; −5 anciens ordres d'informateurs (22/11, étape K) ; traductions conservées
 assert.deepEqual(report.retiredCanonical,['recruter_informateur_pnj','recruter_info_4','recruter_informateur_2','consulter_info_4','gerer_informateurs','acheter_polonium']);
 assert.equal(report.obsoleteCanonical.length,0);
 assert.ok(!report.obsoleteCanonical.some(item => item.fn === 'sovarka_soviet_deputes'));
 assert.ok(report.missingStable.every(item => item.fn !== 'sovarka_soviet_deputes'));

 for(const [locale,data] of Object.entries(report.perLocale)){
  assert.equal(data.keys,423,locale);
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
