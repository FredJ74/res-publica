'use strict';
// Reprise de la PR #636 sans budget obsolète. Tests statiques, sans réseau ni données joueur.
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');
const root=path.resolve(__dirname,'../..');
const lire=p=>fs.readFileSync(path.join(root,p),'utf8');
const contenu=lire('data.js');
function salle(debut,fin){const a=contenu.indexOf('            '+debut+':');const b=contenu.indexOf('            '+fin+':',a+1);assert.ok(a>=0&&b>a,debut+' missing');return contenu.slice(a,b);}
test('la reprise ne modifie pas la répartition budgétaire ni les caisses',()=>{
 const sql=lire('migrations/20261114040000_sovarka_ministeres_lot2_sans_budget_obsolete.sql');
 assert.doesNotMatch(sql,/INSERT INTO public\.repartitions_budgetaires|UPDATE public\.caisses_batiments|INSERT INTO public\.dotations_amorcage_caisses/);
 assert.match(sql,/sovarka_ministeres_commande/);
 assert.match(sql,/sovarka_loi_trancher/);
 assert.match(sql,/sovarka_grace_garder/);
});
test('grâces, manifestations, subvention, garde et sondages sont déclarés dans leur bureau',()=>{
 const pm=salle('bureaux','salle_conseil');
 const securite=salle('bureau_min_int','bureau_min_fin');
 const economie=salle('bureau_min_fin','bureau_min_just');
 const justice=salle('bureau_min_just','bureau_min_def');
 const defense=salle('bureau_min_def','bureau_min_info');
 const verite=salle('bureau_min_info','bureau_min_ae');
 assert.match(pm,/sovarka_graces/);
 assert.match(securite,/sovarka_manifs_gerer/);
 assert.match(securite,/sovarka_habilitations/);
 assert.match(securite,/sovarka_signalements/);
 assert.match(economie,/fn: 'subvention'.*requiresPost: 'min_fin'/);
 assert.match(economie,/150 PSK/);
 assert.match(justice,/sovarka_registre_plaintes/);
 assert.match(justice,/fn: 'sovarka_goulag_gestion'.*bientot:/);
 assert.doesNotMatch(justice,/fn: 'gestion_qhs'/);
 assert.match(defense,/sovarka_ecoutes/);
 assert.match(defense,/Garde de la Patrie/);
 assert.match(verite,/fn: 'commanditer_sondage', label: 'Commanditer un sondage', pa: 1, cost: 60/);
 assert.match(verite,/fn: 'propagande_etat', label: 'Campagne de propagande', pa: 3, cost: 150/);
});
test('routes et écrans emploient les nouvelles décisions du serveur',()=>{
 const router=lire('plateau-router.js'),pouvoir=lire('plateau-sovarka-pouvoir.js');
 const partis=lire('plateau-sovarka-partis.js'),politique=lire('plateau-politique.js');
 const gouv=lire('plateau-gouvernement.js');
 for(const name of ['ouvrirSovarkaGraces','ouvrirSovarkaManifsGerer'])assert.match(router,new RegExp(name));
 for(const name of ['sovMinActe','sovarkaManifDemander','sovarkaManifDecider','sovarkaManifReprimer','sovarkaGraceTransmettre'])assert.match(pouvoir,new RegExp('function '+name+'\('));
 assert.match(pouvoir,/sbRpcVerdict\('sovarka_ministeres_commande'/);
 assert.match(pouvoir,/sbRpcVerdict\('sovarka_ministeres_lire'/);
 assert.match(partis,/sovarkaManifDemander\(\)/);
 assert.match(partis,/sovarkaManifSoutien\(\)/);
 assert.match(politique,/sovGrace \? 'pm' : 'president'/);
 assert.match(politique,/sovGarde \? sbGardePiece\('palais-gouvernement', 'hall'\)/);
 assert.match(gouv,/state.country === 'soviet' && e.cle === 'requisition'/);
});
test('les neuf langues sont servies pour la demande de manifestation',()=>{
 const src=lire('i18n/sovarka-partis-resources.js');
 for(const langue of ['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de']){
  const i=src.indexOf('  "'+langue+'": {');assert.ok(i>=0,langue);
  const j=src.indexOf('\n  "',i+1);
  const block=src.slice(i,j<0?src.length:j);
  for(const key of ['lawsNote','rallyRequest','rallyAuthorized'])assert.match(block,new RegExp('"'+key+'":'));
 }
});
test('syntaxe de tous les scripts modifiés',()=>{
 for(const f of ['data.js','plateau-politique.js','plateau-gouvernement.js','plateau-sovarka-pouvoir.js','plateau-sovarka-partis.js','plateau-router.js','i18n/sovarka-partis-resources.js'])assert.doesNotThrow(()=>new vm.Script(lire(f),{filename:f}),f);
});
