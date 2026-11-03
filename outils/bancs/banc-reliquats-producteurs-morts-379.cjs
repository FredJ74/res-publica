'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const read=f=>fs.readFileSync(f,'utf8');

test('l ancien sondage sans ordre de catalogue ne peut plus produire INF',()=>{
 const data=read('data.js'),router=read('plateau-router.js');
 const divers=read('plateau-divers.js'),politique=read('plateau-politique.js');
 assert.doesNotMatch(data,/fn\s*:\s*['"]commander_sondage['"]/);
 assert.doesNotMatch(router,/commanderSondage\(/);
 assert.doesNotMatch(divers,/function commanderSondage\(/);
 assert.doesNotMatch(divers,/function publierSondage\(/);
 assert.match(politique,/executerOrdreJaugesServeur\('commanditer_sondage'/);
});

test('l allegement fiscal non raccorde reste indisponible sans INF locale',()=>{
 const data=read('data.js'),router=read('plateau-router.js'),politique=read('plateau-politique.js');
 assert.doesNotMatch(data,/fn\s*:\s*['"]allegemement_secteur['"]/);
 assert.doesNotMatch(router,/allegemement_secteur|ouvrirModalSecteur/);
 assert.doesNotMatch(politique,/function ouvrirModalSecteur\(/);
 assert.doesNotMatch(politique,/function appliquerAllegement\(/);
 assert.match(router,/doAllegementFiscalIndisponible\(/);
 assert.match(politique,/function doAllegementFiscalIndisponible\(/);
});
