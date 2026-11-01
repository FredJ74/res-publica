'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),vm=require('node:vm'),fs=require('node:fs'),path=require('node:path'),acorn=require('../e2e/node_modules/acorn');
const root=path.resolve(__dirname,'../..');
function fonction(f,nom){const s=fs.readFileSync(path.join(root,f),'utf8'),n=acorn.parse(s,{ecmaVersion:'latest'}).body.find(x=>x.type==='FunctionDeclaration'&&x.id.name===nom);assert.ok(n);return s.slice(n.start,n.end);}
test('équipements futurs : aucune consultation ni installation, même en appel direct',async()=>{
 let appels=0;const c=vm.createContext({showToast(){},sbRpcVerdict(){appels++;throw Error('RPC future interdite');}});
 vm.runInContext(fs.readFileSync(path.join(root,'plateau-equipements-collectifs.js'),'utf8'),c);
 const r=await c.equipementsCollectifsOuvrir('o1');assert.equal(r.raison,'service_non_active');let efface=false;
 assert.equal(await c.equipementsCollectifsProposerPayeur({replaceChildren(){efface=true;}}),false);assert.equal(efface,true);assert.equal(appels,0);
});
for(const collectif of [false,true])test('achat actif '+(collectif?'collectif forgé refusé avant consultation':'personnel conservé, serveur seul'),async()=>{
 let lectures=0,paiements=0,receptions=0;const messages=[];
 const c=vm.createContext({state:{char:{name:'Alice'},arg:100,liquide:20},document:{getElementById:id=>({value:id==='cpj-payeur-collectif'?(collectif?'orga:o1':''):1})},commercePjTransaction:async(_,f)=>f({}),commercePjContexte:async()=>{lectures++;return {fondsId:'fonds'};},commercePjTransactionActive:()=>true,sbAcheterProduitCommerce:async()=>{paiements++;return {ok:true,montant:5,quantite:1};},sbRpcVerdict:()=>{throw Error('RPC future interdite');},commercePjActualiserPersonnage:async()=>true,commercePjEcranBoutique(){},showToast:(...x)=>messages.push(x),commercePjMontant:String,commercePjDevise:()=> 'FR',tCommercePJ:s=>s,verifierObjetsRecus:async()=>receptions++});
 vm.runInContext(fonction('plateau-commerce-pj.js','commercePjAcheter'),c);await c.commercePjAcheter('ref','achat-fictif-0001');
 assert.equal(lectures,collectif?0:1);assert.equal(paiements,collectif?0:1);assert.equal(receptions,collectif?0:1);assert.equal(c.state.arg,100);assert.equal(c.state.liquide,20);if(collectif)assert.equal(messages[0][2],false);
});
test('interfaces actives : bouton explicite désactivé, préparation historique non chargée',()=>{
 const s=fs.readFileSync(path.join(root,'plateau-organisations-quetes.js'),'utf8');assert.ok(!s.includes('onclick="equipementsCollectifsOuvrir'));
 assert.ok(s.includes('disabled title="Service serveur non activé"'));
 assert.ok(!fs.readFileSync(path.join(root,'plateau.html'),'utf8').includes('clients-prepares/'));
});
