'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const report=require('../audits/etat-i18n-ordres.cjs');

test('couverture des 420 identifiants sans faux positifs de source',()=>{
 assert.equal(report.locales.length,9);
 assert.equal(report.catalogueFrenchKeys,420); // +1 transferts_detenus (27/11 soir) ; −4 ordres supprimés (27/11) ; +1 indices_interrogatoire (27/11) ; −1 contrebande_port (26/11/2026) ; −2 corrompre_rdv_notaire, corrompre_chantier (20/11, criminalité lot 7)  ; +1 boutique_climat (19/11, climat lot 5) ; +1 acheter_graisse (19/11, climat lot 4) ; +1 acheter_furet (18/11, maladies lot 2c)
 assert.equal(report.canonicalMatches,414); // +1 transferts_detenus (27/11 soir) ; −4 ordres supprimés (27/11) ; +1 indices_interrogatoire (27/11) ; −1 contrebande_port (26/11/2026) ; Polonium et cinq anciens contrats d’informateurs retirés ; traductions conservées.
 const retraits=['acheter_polonium','recruter_informateur_pnj','recruter_info_4','recruter_informateur_2','consulter_info_4','gerer_informateurs'];
 assert.deepEqual(report.retiredCanonical.slice().sort(),retraits.slice().sort());
 const exec=require('node:child_process').execFileSync,path=require('node:path');
 const root=path.resolve(__dirname,'../..');
 const avant=['data.js','plateau-multijoueur.js','plateau-actions-illegales-rumeurs.js'].map(f=>exec('git',['show','5a1c24e1:'+f],{cwd:root,encoding:'utf8',maxBuffer:4e6})).join('\n');
 for(const id of retraits.filter(x=>x!=='acheter_polonium'))assert.ok(avant.includes("'"+id+"'"),'provenance avant refonte : '+id);
 assert.equal(report.obsoleteCanonical.length,0);
 assert.ok(!report.obsoleteCanonical.some(item => item.fn === 'sovarka_soviet_deputes'));
 assert.ok(report.missingStable.every(item => item.fn !== 'sovarka_soviet_deputes'));

 for(const [locale,data] of Object.entries(report.perLocale)){
  assert.equal(data.keys,420,locale);
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
