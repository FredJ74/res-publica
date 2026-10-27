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
test('employe donne la quantite choisie par le moteur commun, sans modifier sa charge locale',async()=>{
 let demande;const emp={nom:'Porteur',pnjId:'pnj-fixture',charge:{}},objet={stackable:true,qty:4};const c=vm.createContext({state:{employes:[emp],inventory:[objet],_inventaireRevision:7},document:{getElementById:()=>({value:'2',classList:{remove(){}}})},
 executerReceptionInventaire:async(fn,p)=>{demande={fn,p};return {ok:true,qte:2};},renderInventory(){},showToast(){}});
 vm.runInContext(fonction('plateau-multijoueur.js','confirmerDonnerEmploye'),c);await c.confirmerDonnerEmploye('Porteur',0);assert.equal(demande.fn,'pnj_objet_transferer');assert.equal(demande.p.p_quantite,2);assert.equal(demande.p.p_revision,7);assert.equal(objet.qty,4);assert.deepEqual(emp.charge,{});
});
test('ancienne charge employe reste intacte, sans copie automatique de contenu',async()=>{
 const emp={nom:'Porteur',pnjId:'pnj-fixture',charge:{bois:3}},c=vm.createContext({state:{employes:[emp]},showToast(){},ouvrirGroupePnjRetirer:()=>assert.fail('ancienne charge non reconciliee')});
 vm.runInContext(fonction('plateau-multijoueur.js','ouvrirReprendreEmploye'),c);await c.ouvrirReprendreEmploye('Porteur');assert.equal(emp.charge.bois,3);
});
test('reprise de groupe adresse une possession stable, jamais un seul index perime',async()=>{
 let demande;const c=vm.createContext({RP_GROUPE_COURANT:[{id:'pnj-fixture',nom:'Porteur'}],RP_GROUPE_POSSESSIONS:{'pnj-fixture':[{index:2,possession_id:91}]},executerReceptionInventaire:async(fn,p)=>{demande=p;return null;},showToast(){}});
 vm.runInContext(fonction('plateau-multijoueur.js','confirmerGroupePnjRetirerObjet'),c);await c.confirmerGroupePnjRetirerObjet(0,2);assert.equal(demande.p_possession,91);demande=null;await c.confirmerGroupePnjRetirerObjet(0,0);assert.equal(demande,null);
});
test('accessoire : le client ne transmet ni tarif ni nom ni objet au serveur',async()=>{
 let demande;const c=vm.createContext({executerReceptionInventaire:async(fn,p)=>{demande={fn,p};return {ok:true,objet:'Écharpe — Club serveur',prix:80};},document:{getElementById:()=>({classList:{remove(){}}})},updateUI(){},showToast(){},addJournalEntry(){},getClubLocal:()=>assert.fail('club client ne fait pas autorite'),crediterBudgetClub:()=>assert.fail('credit client'),addToInventory:()=>assert.fail('ajout client')});
 vm.runInContext(fonction('plateau-organisations-quetes.js','confirmerAchatAccessoireClub'),c);await c.confirmerAchatAccessoireClub('echarpe','FAUX',1,0,0);assert.equal(demande.fn,'club_accessoire_acheter');assert.deepEqual(Object.keys(demande.p).sort(),['p_accessoire','p_cost','p_pa']);assert.equal(demande.p.p_accessoire,'echarpe');
});
test('acte officiel : le contenu affiche ne peut pas devenir un objet dicte au serveur',async()=>{
 let demande;const c=vm.createContext({executerReceptionInventaire:async(fn,p)=>{demande=p;return {ok:true};}});
 vm.runInContext(fonction('plateau-etat-civil.js','etatCivilDelivrerActe'),c);await c.etatCivilDelivrerActe({type:'mariage',id:'archive-reelle',titre:'FAUX',texte:'ARME'},'Fixture',1,0);assert.deepEqual(Object.keys(demande).sort(),['p_cost','p_nom','p_pa','p_reference','p_type']);assert.equal(demande.p_reference,'archive-reelle');
});
test('fiche imprimee par RPC, sans sauvegarde generale ni ajout local',async()=>{
 let fn;const c=vm.createContext({executerReceptionInventaire:async(f)=>{fn=f;return {ok:true,objet:'Fiche serveur'};},updateUI(){},renderInventory(){},showToast(){},sbSavePersonnage:()=>assert.fail('sauvegarde fiche'),state:{inventory:[]}});
 vm.runInContext(fonction('plateau-etat-civil.js','etatCivilImprimerFiche'),c);await c.etatCivilImprimerFiche('Fixture');assert.equal(fn,'etat_civil_document_recevoir');assert.equal(c.state.inventory.length,0);
});
test('confirmation d acte attend la reponse sans paiement separe et sans fausse reussite',async()=>{
 let toasts=0;const c=vm.createContext({_acteOfficielChoixCache:[{type:'naissance'}],etatCivilDelivrerActe:async()=>null,deduireCoutOrdre:()=>assert.fail('debit separe'),showToast:()=>toasts++});vm.runInContext(fonction('plateau-justice-economie.js','confirmerActeOfficiel'),c);await c.confirmerActeOfficiel(0,'Fixture',1,100);assert.equal(toasts,0);
});
