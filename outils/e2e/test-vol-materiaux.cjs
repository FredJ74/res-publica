'use strict';
// Fonction réelle, contreparties fictives en mémoire : aucun appel de production.
// 28/10/2026 : le vol de matériaux est tranché ENTIER par le serveur (crime_voler_materiaux) :
// jet, stock du chantier, dépôt, traces. L'écran n'envoie aucune quantité et n'ajoute rien lui-même.
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),acorn=require('acorn');
const source=fs.readFileSync(path.join(__dirname,'../../plateau-justice-economie.js'),'utf8');
const n=acorn.parse(source,{ecmaVersion:'latest'}).body.find(n=>n.type==='FunctionDeclaration'&&n.id.name==='confirmerVolMateriaux');
assert.ok(n,'handler réel requis');
const code=source.slice(n.start,n.end);
function fixture(verdict,texte=code){
 const inventaire=[],appels=[],messages=[],adoptes=[];
 const ts={proprietaire:'Proprietaire fictif',chantier:{stockMateriaux:{bois:20}}};
 const c=vm.createContext({state:{char:{name:'Voleur fictif'},country:'republic',currentCity:'capitale',currentBuilding:'terrain-a-batir-1',day:1},
  getTerrainState:()=>ts,document:{getElementById:()=>({classList:{remove(){}}})},
  appelerCrimeServeur:async(fn,p)=>{appels.push({fn,p});return verdict;},
  adopterEtatCrimeServeur:v=>adoptes.push(v),adopterDetectionServeur(){},remplacerTerrainState:()=>{},
  addToInventory:o=>inventaire.push(o),signalerRefusCout:()=>messages.push('refus'),
  updateUI(){},showToast:(...v)=>messages.push(v),addJournalEntry(){},addExternalEvent(){},Math});
 vm.runInContext(texte,c);return {c,inventaire,appels,messages,adoptes};
}
test('vol chantier : une seule commande serveur, sans quantité ni jet fournis par l’écran',async()=>{
 const x=fixture({ok:true,reussi:true,matiere:'bois',quantite:2,inventory:[],revision:3});await x.c.confirmerVolMateriaux('bois',2,0);
 assert.equal(x.appels.length,1);assert.equal(x.appels[0].fn,'crime_voler_materiaux');
 assert.deepEqual(Object.keys(x.appels[0].p).sort(),['p_benediction','p_cost','p_matiere','p_pa','p_terrain']);
 assert.equal(x.inventaire.length,0,'aucun ajout local');assert.equal(x.adoptes.length,1,'inventaire du serveur adopté');
});
test('vol chantier : stock vidé, aucun ajout ni faux succès',async()=>{
 const x=fixture({ok:false,raison:'stock_vide'});await x.c.confirmerVolMateriaux('bois',2,0);
 assert.equal(x.inventaire.length,0);assert.equal(x.messages[0][0],'Rien à emporter');
});
test('vol chantier : refus serveur, aucun objet local',async()=>{
 const x=fixture({ok:false,raison:'pa_insuffisants'});await x.c.confirmerVolMateriaux('bois',2,0);
 assert.equal(x.inventaire.length,0);assert.deepEqual(x.messages,['refus']);
});
test('contre-épreuve : un handler qui ajouterait lui-même le butin est détecté',async()=>{
 const fautif=code.replace('adopterEtatCrimeServeur(v);','adopterEtatCrimeServeur(v); addToInventory({ name: v.matiere, qty: v.quantite });');
 assert.notEqual(fautif,code);
 const x=fixture({ok:true,reussi:true,matiere:'bois',quantite:2},fautif);await x.c.confirmerVolMateriaux('bois',2,0);
 assert.equal(x.inventaire.length,1,'la contre-épreuve doit être visible');
});
