// Vrais handlers, transports controles ; aucune connexion Supabase.
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const acorn=require('../vercel/node_modules/acorn'),path=require('node:path'),root=path.resolve(__dirname,'../..');
function fonction(file,nom){const s=fs.readFileSync(path.join(root,file),'utf8'),n=acorn.parse(s,{ecmaVersion:'latest'}).body.find(n=>n.type==='FunctionDeclaration'&&n.id.name===nom);assert(n,nom);return s.slice(n.start,n.end);}
for(const nom of ['deposerDansCaisseFret','reprendreDeCaisseFret','retirerDeCaisseFret','acheterLotNonReclameeFret'])test(nom+' delegue la commande et ne fabrique rien',async()=>{
 const obj={id:'ancien'};let demande;const c=vm.createContext({state:{inventory:[obj],_inventaireRevision:12},window:{_fretEligiblesDepot:[obj]},
 document:{getElementById:id=>({value:id==='fret-depot-objet'?0:2,classList:{remove(){}}})},
 executerReceptionInventaire:async(fn,p)=>{demande={fn,p};return {ok:true,qte:2,prix:50};},
 showToast(){},updateUI(){},afficherGestionCaisseOuverteFret:async()=>{},afficherCaisseArriveeFret:async()=>{},
 addToInventory:()=>assert.fail('ajout local'),sbUpdate:()=>assert.fail('PATCH'),sbSavePersonnage:()=>assert.fail('sauvegarde generale')});
 vm.runInContext(fonction('plateau-justice-economie.js',nom),c);await c[nom]('caisse','ligne',1);assert.equal(demande.fn,'fret_objet_agir');assert.equal(demande.p.p_caisse,'caisse');assert.equal(c.state.inventory[0],obj);
 if(nom==='deposerDansCaisseFret'){assert.equal(demande.p.p_revision,12);assert.equal(demande.p.p_index,0);}
});
for(const destinataire of ['Fixture','Autre'])test('urbanisme pour '+destinataire+' passe exclusivement par le sas',async()=>{
 const appels=[],doc={documentRemis:true};const c=vm.createContext({state:{char:{name:'Fixture'},inventory:[]},
 objetInventaireDocumentUrbanisme:d=>({documentUrbanisme:d}),estTitulaire:n=>n==='Fixture',sbObjetSasDeposer:async(...a)=>{appels.push(a);return {ok:true};},recevoirObjetAutomatique:()=>assert.fail('ancien ajout local')});
 vm.runInContext(fonction('plateau-immobilier.js','delivrerDocumentUrbanisme'),c);await c.delivrerDocumentUrbanisme(doc,destinataire,'archive');assert.equal(appels.length,1);assert.equal(appels[0][0],'document_urbanisme');assert.equal(appels[0][1],destinataire);assert.equal(appels[0][3],'archive');assert.equal(c.state.inventory.length,0);
});
test('sas refuse ou injoignable : document non annonce comme remis',async()=>{
 for(const rpc of [async()=>({ok:false,raison:'dossier_introuvable'}),async()=>{throw Error('reseau');}]){
  const c=vm.createContext({objetInventaireDocumentUrbanisme:()=>({}),sbObjetSasDeposer:rpc});vm.runInContext(fonction('plateau-immobilier.js','delivrerDocumentUrbanisme'),c);const d={documentRemis:true};await c.delivrerDocumentUrbanisme(d,'Fixture','ref');assert.equal(d.documentRemis,false);
 }
});
test('anciens producteurs inactifs supprimes, les ordres actifs restent raccordes',()=>{
 const noms=['doAcheterEntreprise','doImprimerClandestin','doImprimerLivre','poserObjetMilitaire'];
 for(const file of ['plateau-justice-economie.js','plateau-effort-guerre.js']){
  const ast=acorn.parse(fs.readFileSync(path.join(root,file),'utf8'),{ecmaVersion:'latest'});assert(!ast.body.some(n=>n.type==='FunctionDeclaration'&&noms.includes(n.id.name)));
 }
 const router=fs.readFileSync(path.join(root,'plateau-router.js'),'utf8');assert(router.includes('doRachatEntreprise()'));assert(router.includes('imprimer_tracts_calomnieux'));
 assert(fonction('plateau-effort-guerre.js','confirmerRetraitMilitaire').includes('sbMilitaireRetrait'));
});
