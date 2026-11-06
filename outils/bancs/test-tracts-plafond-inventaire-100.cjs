'use strict';
const { test }=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const divers=fs.readFileSync(path.join(root,'plateau-divers.js'),'utf8');
const imprimerie=fs.readFileSync(path.join(root,'plateau-communication.js'),'utf8');
const migration=fs.readFileSync(path.join(root,'migrations/20261104164500_tracts_imprimer_plafond_inventaire.sql'),'utf8');
function fonction(source,debut) {
 const start=source.indexOf(debut);
 assert.ok(start>=0,debut);
 let depth=0,open=source.indexOf('{',start),end=-1;
 for(let i=open;i<source.length;i++){
  if(source[i]==='{')depth++;
  if(source[i]==='}'&&--depth===0){end=i+1;break;}
 }
 assert.ok(end>start,'fin de '+debut);
 return source.slice(start,end);
}
const totalSrc=fonction(divers,'function getTotalInventaire() {');
const capaciteSrc=fonction(imprimerie,'function capaciteImpressionTracts(stockBois) {');
function scenario(inventory,stock=9) {
 const state={inventory,pa:10,arg:3000};
 const ctx={
  state,BOIS_PAR_LOT_TRACTS:1,TRACTS_PAR_LOT:10,
  prixLotTractsAtelier:()=>150,
  getFondsDisponiblesOrdinaires:()=>state.arg
 };
 vm.createContext(ctx);vm.runInContext(totalSrc+'\n'+capaciteSrc,ctx);
 return {total:ctx.getTotalInventaire(),cap:ctx.capaciteImpressionTracts(stock)};
}
test('tracts pour/contre et calomnieux : chaque tract compte, objets non-tracts inchanges',()=>{
 assert.equal(scenario([{type:'tract',quantite:50,cible:'A',tractType:'pour'}]).total,50);
 assert.equal(scenario([{type:'tract',quantite:25},{type:'tract_calomnieux',quantite:15}]).total,40);
 assert.equal(scenario([{qty:12},{encombrement:3},{name:'clé'}]).total,16);
 assert.equal(scenario([{type:'tract',quantite:90},{qty:10}]).total,100);
});
test('100 unités : un lot s il reste 10 places ; aucune production à 91/100',()=>{
 const c90=scenario([{type:'tract',quantite:80},{qty:10}]);
 assert.equal(c90.cap.charge,90);assert.equal(c90.cap.libres,10);assert.equal(c90.cap.lots,1);
 const c91=scenario([{type:'tract',quantite:80},{qty:11}]);
 assert.equal(c91.cap.libres,9);assert.equal(c91.cap.parPlace,0);assert.equal(c91.cap.lots,0);
 const c80=scenario([{type:'tract',quantite:60},{qty:20}]);
 assert.equal(c80.cap.lots,2);
 const c100=scenario([{type:'tract_calomnieux',quantite:100}]);
 assert.equal(c100.cap.lots,0);
});
test('la RPC refuse au serveur avant toute dépense et protège les deux types de tracts',()=>{
 assert.match(migration,/md5\(v_source\) <> '900ac20f81f40b5f14fadc12de33de47'/);
 assert.match(migration,/FOR UPDATE/);
 assert.match(migration,/IF v_charge \+ v_qte > 100 THEN/);
 assert.match(migration,/'raison','inventaire_plein'/);
 assert.match(migration,/p_calomnieux THEN 10 ELSE p_lots \* 10 END/);
 assert.ok(migration.indexOf('IF v_charge + v_qte > 100')<migration.lastIndexOf('v_r := public.imprimerie_produire_tracts'));
 assert.ok(!migration.includes('DROP FUNCTION'));
 assert.match(imprimerie,/raison === 'inventaire_plein'/);
 assert.match(imprimerie,/cap\.parPlace < 1/);
 assert.match(imprimerie,/les places libres de votre inventaire/);
 assert.match(imprimerie,/p_cible: cible, p_sens: sens/);
});
