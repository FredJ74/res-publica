'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const src = fs.readFileSync(path.resolve(__dirname, '../../plateau-communication.js'),'utf8');
function extraire(start, end) {
 const a=src.indexOf(start),b=src.indexOf(end,a+start.length);
 assert.ok(a>=0 && b>a,start);
 return src.slice(a,b);
}
const fn=extraire('async function ouvrirModalImprimerTractsElectoraux(pa, cost) {','\n// --- Tract calomnieux (atelier) ---');
function faireContexte(stock=3,pa=5,fonds=1500) {
 const noeuds={
 'postes-modal-title':{textContent:''},
 'postes-body':{innerHTML:''},
 'modal-postes':{classList:{add(){},remove(){}}},
 'tract-electoral-cible':{value:'Alice'},
 'tract-electoral-lots':{value:'2'},
 'tract-electoral-apercu':{textContent:'',style:{}}
 };
 const appels=[],toasts=[];
 const ctx={window:{},document:{getElementById:id=>noeuds[id]},
  state:{country:'republic',currentCity:'capitale',currentBuilding:'la-tribune',currentRoom:'accueil_tribune',pa,arg:fonds,
   char:{name:'Alice'},inventory:[{type:'tract',quantite:30,cible:'Alice',tractType:'pour'}]},
  COUNTRIES:{republic:{cur:'FR'}},STOCK_BOIS_MAX_IMPRIMERIE_PNJ:10,BOIS_PAR_LOT_TRACTS:1,TRACTS_PAR_LOT:10,SALAIRE_LOT_TRACTS:50,
  listerCiblesTractsElectoraux:async()=>[{nom:'Alice',enCampagne:true}],
  stockBoisAtelier:async()=>stock,
  capaciteImpressionTracts:(stockBois)=>({lots:Math.max(0,Math.min(stockBois,pa,Math.floor(fonds/150),7)),parBois:stockBois,parPa:pa,parFonds:Math.floor(fonds/150),parPlace:7,charge:30,libres:70,fonds,prixLot:150}),
  prixLotTractsAtelier:()=>150, atelierImprimerieCourant:()=>({pays:'republic',ville:'capitale',building:'la-tribune'}),
  echapperTexteTract:x=>x,showToast:(...a)=>toasts.push(a),
  imprimerTractsServeur:async(...a)=>{appels.push(a);return {montantDebite:a[0]*150,paConsommes:a[0],salaire:a[0]*50}},
  sauvegarderPersonnageImmediat:()=>{},updateUI:()=>{},addJournalEntry:()=>{},
  nomImprimeurLocal:()=>null
 };
 vm.createContext(ctx);
 vm.runInContext(fn,ctx);
 return {ctx,noeuds,appels,toasts};
}
test('matiere manquante ou production impossible : aucun champ quantite et aucune commande',async()=>{
 for(const [bois,pa,fonds] of [[0,5,1500],[4,0,1500],[4,4,0]]){
  const f=faireContexte(bois,pa,fonds);await f.ctx.ouvrirModalImprimerTractsElectoraux(1,150);
  const html=f.noeuds['postes-body'].innerHTML;
  assert.match(html,/STOCKS ET PRODUCTION/);
  assert.match(html,/Production possible maintenant/);
  assert.doesNotMatch(html,/id="tract-electoral-lots"/);
  assert.doesNotMatch(html,/>Commander</);
  await f.ctx.confirmerImprimerTractsElectoraux(1,150);
  assert.equal(f.appels.length,0);
 }
});
test('stock et capacite lisibles ; quantite entière bornée ; pour et contre la meme RPC',async()=>{
 const f=faireContexte(3,5,1500);await f.ctx.ouvrirModalImprimerTractsElectoraux(1,150);
 const html=f.noeuds['postes-body'].innerHTML;
 assert.match(html,/3 \/ 10/);
 assert.match(html,/Tracts électoraux déjà dans votre inventaire : <strong>30<\/strong>/);
 assert.match(html,/max="3"/);
 assert.match(html,/PERSONNE VISÉE/);
 assert.match(html,/selectTractType\('pour'\)/);
 assert.match(html,/selectTractType\('contre'\)/);
 for(const n of ['0','4','1.5','-1','NaN']){
  f.noeuds['tract-electoral-lots'].value=n;
  await f.ctx.confirmerImprimerTractsElectoraux(1,150);
  assert.equal(f.appels.length,0,'quantite refusee '+n);
 }
 f.noeuds['tract-electoral-lots'].value='2';
 f.ctx.window._tractType='contre';
 await f.ctx.confirmerImprimerTractsElectoraux(1,150);
 assert.deepEqual(Array.from(f.appels[0]),[2,'Alice','contre',false]);
});
test('changement de stock après ouverture : refus sans transaction',async()=>{
 let stock=2;const f=faireContexte(2,5,1500);
 f.ctx.stockBoisAtelier=async()=>stock;
 await f.ctx.ouvrirModalImprimerTractsElectoraux(1,150);
 stock=0;
 await f.ctx.confirmerImprimerTractsElectoraux(1,150);
 assert.equal(f.appels.length,0);
 assert.match(f.toasts.at(-1)[0],/Stock ou fonds modifiés/);
});
