'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const read=p=>fs.readFileSync(p,'utf8');
const sql=read('migrations/20261113221500_mandats_postes_pays_serveur.sql');
const data=read('data.js');
const politique=read('plateau-politique.js');
const routeur=read('plateau-router.js');
const gouvernement=read('plateau-gouvernement.js');
const ctx=vm.createContext({});
vm.runInContext(data,ctx);
function ordres(pays,ville,piece) {
 return Array.from(vm.runInContext(`ordresDeclaresDeLaPiece(BUILDINGS['palais-gouvernement'].rooms[${JSON.stringify(piece)}],
 WORLD[${JSON.stringify(pays)}][${JSON.stringify(ville)}].buildingContext['palais-gouvernement'],${JSON.stringify(piece)})`,ctx));
}
test('la gestion de caserne est commune aux ministres de Défense de Républia et Sovarka',()=>{
 for(const pays of ['republic','soviet']){
  const a=ordres(pays,'capitale','bureau_min_def');
  const gestion=a.find(o=>o.fn==='gestion_caserne');
  assert.ok(gestion,pays);
  assert.equal(gestion.requiresPost,'min_def');
 }
 const sov=ordres('soviet','capitale','bureau_min_def');
 for(const fn of ['garde_republicaine','mobilisation_nationale','activer_cessez_le_feu'])
  assert.ok(!sov.some(o=>o.fn===fn),fn);
});
test('le bureau sovarkien des ministres limite chaque pouvoir à son propre poste',()=>{
 for(const [room,fn,id] of [
  ['bureau_min_def','sovarka_conscription','min_def'],
  ['bureau_min_def','sovarka_ecoutes','min_def'],
  ['bureau_min_int','sovarka_surveiller','min_int'],
  ['bureau_min_just','sovarka_saisir_juge','min_just'],
  ['bureau_min_info','sovarka_sondages','min_info'],
  ['bureaux','sovarka_lois_examen','pm'],
  ['bureaux','sovarka_autocritique','pm'],
  ['salle_conseil','sovarka_seance','pm']
 ]) {
  const order=ordres('soviet','capitale',room).find(o=>o.fn===fn);
  assert.ok(order,fn);
  assert.equal(order.requiresPost,id,fn);
 }
});
test('contrôle générique : tous les postes déclarés exigent le pays de leur mandat',()=>{
 assert.match(politique,/if \(o\.requiresPost && !needsPost && paysMandatPourOrdre\(\) !== state\.country\)/);
 assert.match(routeur,/definitionMinisterielle\?\.requiresPost && paysMandatPourOrdre\(\) !== state\.country/);
 const source=politique.slice(politique.indexOf('function paysMandatPourOrdre()'),politique.indexOf('\n}\n',politique.indexOf('function paysMandatPourOrdre()'))+2);
 const a=vm.createContext({state:{country:'soviet',poste:{id:'min_def',country:'republic'}}});
 vm.runInContext(source+'\nthis.resultat=paysMandatPourOrdre();',a);
 assert.equal(a.resultat,'republic');
});
test('les deux gardes serveur refusent un pays étranger et attestent le poste réel',()=>{
 for(const proc of ['public.exiger_poste','public.poste_autorite_de']){
  assert.ok(sql.includes('CREATE OR REPLACE FUNCTION '+proc),proc);
 }
 assert.match(sql,/v_pays_mandat IS DISTINCT FROM v_pays_present/);
 assert.match(sql,/v_pays_mandat IS DISTINCT FROM v_pays\b/);
 assert.match(sql,/poste_est_atteste\(v_nom,v_poste_json,v_pays_present\)/);
 assert.match(sql,/poste_est_atteste\(v_nom,v_poste,v_pays\)/);
 assert.match(sql,/acteur_poste_courant\(\)/);
 assert.match(sql,/set search_path/ig);
});
test('les panneaux de caserne et le financement utilisent le pays courant, pas un identifiant fixé Républia',()=>{
 assert.match(gouvernement,/async function ouvrirGestionCaserne\(\)/);
 assert.match(gouvernement,/ouvrirGererBudgetMilitaire\(\)/);
 assert.match(politique,/const pays = state\.country \|\| 'republic';/);
});
