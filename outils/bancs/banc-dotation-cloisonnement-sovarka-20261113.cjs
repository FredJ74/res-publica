'use strict';
const { test }=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const read=f=>fs.readFileSync(f,'utf8');
const data=read('data.js');
const politique=read('plateau-politique.js');
const router=read('plateau-router.js');
const stock=read('migrations/20261113210000_novomirsk_dotation_initiale_stock.sql');
const protection=read('migrations/20261113210100_renseignement_garde_pays_du_mandat.sql');
function world(expression) {
 const context=vm.createContext({});
 vm.runInContext(data,context);
 return vm.runInContext(expression,context);
}
function paysDuPoste(state) {
 const a=politique.indexOf('function paysMandatPourOrdre() {');
 const b=politique.indexOf('\n}\n',a);
 assert.ok(a>=0&&b>a);
 const ctx=vm.createContext({state});
 vm.runInContext(politique.slice(a,b+2)+'\nthis.valeur=paysMandatPourOrdre();',ctx);
 return ctx.valeur;
}
test('code client et definitions syntaxiquement valides',()=>{
 for(const [f,s] of [['data.js',data],['plateau-politique.js',politique],['plateau-router.js',router]])
   assert.doesNotThrow(()=>new vm.Script(s,{filename:f}));
});
test('un ministre republicain voyageur conserve son mandat republicain',()=>{
 assert.equal(paysDuPoste({country:'soviet',poste:{id:'min_def',country:'republic'},char:{country:'soviet'}}),'republic');
 assert.equal(paysDuPoste({country:'soviet',poste:{id:'min_def'},char:{domicile:{country:'republic'},country:'soviet'}}),'republic');
 assert.equal(paysDuPoste({country:'soviet',poste:{id:'min_def',country:'soviet'}}),'soviet');
});
test('affichage et appel direct refusent un ordre de poste dans un autre pays',()=>{
 assert.match(politique,/if \(o\.requiresPost && !needsPost && paysMandatPourOrdre\(\) !== state\.country\)/);
 assert.match(router,/definitionMinisterielle\?\.requiresPost && paysMandatPourOrdre\(\) !== state\.country/);
});
test('Sovarka Defense ne propose pas la garde republicaine et exige son propre ministre',()=>{
 const defs=world(`ordresDeclaresDeLaPiece(BUILDINGS['palais-gouvernement'].rooms.bureau_min_def,
 WORLD.soviet.capitale.buildingContext['palais-gouvernement'],'bureau_min_def')`);
 const fns=Array.from(defs,x=>x.fn);
 for(const fn of ['garde_republicaine','mobilisation_nationale','activer_cessez_le_feu'])
  assert.equal(fns.includes(fn),false,fn);
 assert.ok(fns.includes('sovarka_conscription'));
 assert.ok(fns.includes('gestion_caserne'), 'La gestion de la caserne appartient au ministre sovarkien comme au républicain');
 assert.ok(fns.includes('renseignement_militaire'));
 assert.equal(defs.find(x=>x.fn==='sovarka_conscription').requiresPost,'min_def');
});
test('les autorisations des principaux ministres sovarkiens sont explicites',()=>{
 const ctx=world(`WORLD.soviet.capitale.buildingContext['palais-gouvernement'].roomOverrides`);
 for(const [room,fn,post] of [
   ['bureau_min_int','sovarka_surveiller','min_int'],
   ['bureau_min_just','sovarka_saisir_juge','min_just'],
   ['bureau_min_info','sovarka_sondages','min_info']
 ]) assert.equal(ctx[room].orders.find(x=>x.fn===fn)?.requiresPost,post,fn);
});
test('la garde serveur verifie explicitement le pays du poste',()=>{
 assert.match(protection,/v_pays_mandat IS DISTINCT FROM p_pays/);
 assert.match(protection,/acteur_poste_courant\(\)/);
 assert.match(protection,/bureau_min_def/);
 assert.match(protection,/bureau_min_int/);
});
test('dotation unique, plafond et journal sans ecraser les stocks existants',()=>{
 assert.match(stock,/operation='dotation_initiale_novomirsk_20261113'/);
 assert.match(stock,/greatest\(v_cible-v_actuel,0\)/);
 assert.match(stock,/v_total > 5000/);
 assert.match(stock,/FOR UPDATE/);
 const m=stock.match(/v_cibles jsonb := '(\{[^']+\})'/);
 assert.ok(m);
 const targets=JSON.parse(m[1]);
 assert.ok(Object.values(targets).reduce((a,b)=>a+b,0)<=5000);
 assert.equal(targets.bois,500);
 assert.equal(targets.metal,250);
});
