'use strict';
// Contre-épreuves historiques #194 conservées sur la fixture du handler remplacé.
// Les raccordements du handler actuel sont dans test-vol-atomique.cjs.
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),acorn=require('acorn');
const source=fs.readFileSync(path.join(__dirname,'fixtures/vol-materiaux-avant-atomique.js'),'utf8');
const n=acorn.parse(source,{ecmaVersion:'latest'}).body.find(n=>n.type==='FunctionDeclaration'&&n.id.name==='confirmerVolMateriaux');
assert.ok(n,'handler réel requis');
const code=source.slice(n.start,n.end);
function fixture(verdict,texte=code){
 const inventaire=[],appels=[],messages=[];
 const ts={proprietaire:'Proprietaire fictif',chantier:{stockMateriaux:{bois:20}}};
 const c=vm.createContext({state:{char:{name:'Voleur fictif'},country:'republic',currentCity:'capitale',currentBuilding:'terrain-a-batir-1',day:1},
  getTerrainState:()=>ts,deduireCoutOrdre:async()=>({ok:true}),getStatEffective:()=>10,
  document:{getElementById:()=>({classList:{remove(){}}})},scoreVolMateriaux:()=>80,verdictVolMateriaux:()=>({reussite:true}),
  numeroJourChantier:()=>1,quantiteVolMateriaux:()=>5,vigilesDuChantier:()=>0,
  sbTerrainActe:async(fn,p)=>{appels.push({fn,p});return verdict;},remplacerTerrainState:()=>{},
  addToInventory:o=>inventaire.push(o),signalerRefusTerrain:()=>messages.push('refus'),
  updateUI(){},showToast:(...v)=>messages.push(v),addJournalEntry(){}});
 vm.runInContext(texte,c);return {c,inventaire,appels,messages};
}
test('vol chantier : quantité accordée par le serveur, pas quantité demandée',async()=>{
 const x=fixture({ok:true,quantite:2,etat:{}});await x.c.confirmerVolMateriaux('bois',1,0);
 assert.equal(x.appels.length,1);assert.equal(x.appels[0].p.p_quantite,5);
 assert.equal(x.inventaire.length,1);assert.equal(x.inventaire[0].qty,2);
});
test('vol chantier : stock vidé, aucun ajout ni faux succès',async()=>{
 const x=fixture({ok:true,quantite:0,etat:{}});await x.c.confirmerVolMateriaux('bois',1,0);
 assert.equal(x.inventaire.length,0);assert.equal(x.messages[0][0],'Rien à emporter');
});
test('vol chantier : refus serveur, aucun objet local',async()=>{
 const x=fixture({ok:false,raison:'stock_vide'});await x.c.confirmerVolMateriaux('bois',1,0);
 assert.equal(x.inventaire.length,0);assert.deepEqual(x.messages,['refus']);
});
test('contre-épreuve : ancien handler échoue après réponse serveur',async()=>{
 const ancien=code.replace('const quantiteDemandee = quantiteVolMateriaux','const qte = quantiteVolMateriaux')
  .replace('if (quantiteDemandee <= 0)','if (qte <= 0)').replace('p_quantite: quantiteDemandee','p_quantite: qte')
  .replace('const qte = Number(vVol.quantite)','qte = Number(vVol.quantite)');
 assert.notEqual(ancien,code);
 const x=fixture({ok:true,quantite:2,etat:{}},ancien);
 await assert.rejects(x.c.confirmerVolMateriaux('bois',1,0),/Assignment to constant variable/);
 assert.equal(x.appels.length,1);assert.equal(x.inventaire.length,0);
});
