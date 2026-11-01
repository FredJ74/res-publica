// node --test outils/bancs/banc-ordres-territoires.cjs
// Conservation exhaustive du contrat statique ; aucune probabilite nouvelle.
const test=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'../..');
function contexte() {
 const ctx=vm.createContext({console,state:{country:'republic',currentCity:'capitale'}});
 vm.runInContext(fs.readFileSync(path.join(root,'data.js'),'utf8'),ctx);
 const nav=fs.readFileSync(path.join(root,'plateau-navigation.js'),'utf8');
 vm.runInContext(nav.slice(nav.indexOf('function getBuildingContext('),nav.indexOf('function joursRestantsPeine(')),ctx);
 const immo=fs.readFileSync(path.join(root,'plateau-immobilier.js'),'utf8');
 vm.runInContext(immo.slice(immo.indexOf('function definitionOrdreDansPiece('),immo.indexOf('// Libelles des refus,',immo.indexOf('function definitionOrdreDansPiece('))),ctx);
 return ctx;
}
test('toutes les pieces declarees des douze villes gardent leurs ordres, couts, gardes et jets',()=>{
 const ctx=contexte();
 const resultat=vm.runInContext(`(() => {
  const avant=JSON.stringify({WORLD,BUILDINGS});let pieces=0,ordres=0,verifications=0;
  for(const pays of Object.keys(VILLES))for(const ville of Object.keys(VILLES[pays])){
   const cite=WORLD[pays]?.[ville];if(!cite)throw Error('Ville absente '+pays+'/'+ville);
   state.country=pays;state.currentCity=ville;
   for(const id of cite.buildings||[]){
    const b=BUILDINGS[id];if(!b)continue; // inventorie separement, pas de gabarit invente
    const local=cite.buildingContext?.[id];
    for(const [pieceId,piece] of Object.entries({...b.rooms,...local?.roomsExtra})){
     const surcharge=local?.roomOverrides?.[pieceId];
     const historique=[...(piece.orders||[]),...(local?.orders||[])]
       .filter(o=>!(surcharge?.excludeOrders||[]).includes(o.fn)).concat(surcharge?.orders||[]);
     const actuel=ordresDeclaresDeLaPiece(piece,local,pieceId);
     if(JSON.stringify(actuel)!==JSON.stringify(historique))throw Error('Divergence '+pays+'/'+ville+'/'+id+'/'+pieceId);
     for(const o of actuel){
      const attendu=historique.find(h=>h.fn===o.fn);
      if(JSON.stringify(definitionOrdreDansPiece(id,pieceId,o.fn))!==JSON.stringify(attendu))throw Error('Garde divergente '+o.fn);
      verifications++;
     }
     pieces++;ordres+=actuel.length;
    }
   }
  }
  if(JSON.stringify({WORLD,BUILDINGS})!==avant)throw Error('Donnees modifiees');
  return {pieces,ordres,verifications};
 })()`,ctx);
 assert.ok(resultat.pieces>100);assert.ok(resultat.ordres>100);
 console.log('Conservation : '+JSON.stringify(resultat));
});
test('une surcharge remplace un ordre herite sans etre exclue elle-meme',()=>{
 const ctx=contexte();const piece={orders:[{fn:'acheter',cost:1},{fn:'autre'}]};
 const local={roomOverrides:{p:{excludeOrders:['acheter'],orders:[{fn:'acheter',cost:2}]}}};
 assert.deepEqual(JSON.parse(JSON.stringify(ctx.ordresDeclaresDeLaPiece(piece,local,'p'))),[{fn:'autre'},{fn:'acheter',cost:2}]);
});
test('ajout et exclusion locaux ne contaminent ni une autre piece ni le gabarit',()=>{
 const ctx=contexte();const piece={orders:[{fn:'commun',pa:2,successRate:37}]};
 const local={orders:[{fn:'batiment'}],roomOverrides:{bureau:{orders:[{fn:'local',requiresRole:'locataire'}],excludeOrders:['commun']}}};
 assert.deepEqual(Array.from(ctx.ordresDeclaresDeLaPiece(piece,local,'bureau'),o=>o.fn),['batiment','local']);
 assert.deepEqual(Array.from(ctx.ordresDeclaresDeLaPiece(piece,local,'autre'),o=>o.fn),['commun','batiment']);
 assert.deepEqual(Array.from(ctx.ordresDeclaresDeLaPiece(piece,null,'bureau'),o=>o.fn),['commun']);
 assert.equal(piece.orders[0].successRate,37);assert.equal(piece.orders[0].pa,2);
});
test('les deux consommateurs utilisent effectivement la fusion partagee',()=>{
 const politique=fs.readFileSync(path.join(root,'plateau-politique.js'),'utf8');
 assert.match(politique,/const ordresDeclares = ordresDeclaresDeLaPiece\(room, ctx, roomId\)/);
 const ctx=contexte();assert.match(ctx.definitionOrdreDansPiece.toString(),/ordresDeclaresDeLaPiece/);
});
