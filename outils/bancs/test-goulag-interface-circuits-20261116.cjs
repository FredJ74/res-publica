'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const load=f=>fs.readFileSync(f,'utf8');
const html=load('plateau.html'),router=load('plateau-router.js');
const transports=load('plateau-goulag-transports.js'),refuge=load('plateau-goulag-refuge.js');
const toundra=load('plateau-goulag-toundra.js');
const justice=load('plateau-justice-economie.js');
for(const name of ['plateau-goulag-toundra.js','plateau-goulag-transports.js','plateau-goulag-refuge.js']){
  assert.ok(html.includes(name),name+' chargé avant le routeur');
  assert.ok(html.indexOf(name)<html.indexOf('plateau-router.js'),name+' ordre');
}
for(const [ordre,handler] of Object.entries({
  goulag_visite_demander:'goulagAutorisationDemander',
  goulag_voyager:'goulagVoyager',
  goulag_autorisations_gerer:'goulagAutorisationsGerer',
  goulag_visiteur_retour:'goulagVisiteurRetour',
  goulag_refuge_nuit:'goulagRefugeNuit',
  goulag_refuge_terminer:'goulagRefugeTerminer',
})){
  assert.ok(router.includes(ordre+':\x27'+handler+'\x27'),'ordre '+ordre);
  assert.ok((transports+refuge).includes('window.'+handler+'='),'handler '+handler);
}
for(const rpc of ['sovarka_goulag_visite_demander','sovarka_goulag_voyager',
 'sovarka_goulag_visite_decider','sovarka_goulag_visite_lire',
 'sovarka_goulag_visiteur_repartir']) assert.ok(transports.includes(rpc),rpc);
for(const rpc of ['sovarka_goulag_refuge_lire','sovarka_goulag_refuge_nuit',
 'sovarka_goulag_refuge_terminer']) assert.ok(refuge.includes(rpc),rpc);
assert.ok(justice.includes("type === 'qhs' && state.country === 'soviet'"));
assert.ok(justice.includes("sbRpcVerdict('sovarka_goulag_juger'"));
assert.ok(justice.includes('Condamner — envoi au goulag'));
assert.ok(toundra.includes('champignons_a_decider'));
assert.ok(toundra.includes('sbAdopterInventaireServeur'));
assert.ok(toundra.includes("v.recherche"));
assert.ok(transports.includes("requiresPost:'min_just'"));
assert.ok(!transports.includes("goulag_condamner"),'aucun pouvoir ministériel de condamner');
console.log('Goulag interface : modules chargés, demandes, transport, refuge, champignons, juge seul : OK');
