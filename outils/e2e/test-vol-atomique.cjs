'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),acorn=require('acorn');
const R=path.resolve(__dirname,'../..');
function fonction(f,nom){const s=fs.readFileSync(path.join(R,f),'utf8'),n=acorn.parse(s,{ecmaVersion:'latest'}).body.find(n=>n.type==='FunctionDeclaration'&&n.id.name===nom);assert.ok(n,nom);return s.slice(n.start,n.end);}
function fixture(){
 const stockage=new Map(),appels=[],messages=[],c=vm.createContext({console,crypto:require('node:crypto').webcrypto,
 state:{char:{name:'Fixture'},country:'republic',currentCity:'capitale',currentBuilding:'terrain-a-batir-1',currentRoom:'terrain'},
 sessionStorage:{getItem:k=>stockage.get(k)||null,setItem:(k,v)=>stockage.set(k,v),removeItem:k=>stockage.delete(k)},
 document:{getElementById:()=>({classList:{remove(){}}})},showToast:(...m)=>messages.push(m),updateUI(){},
 chargerTerrainState:async()=>true,rafraichirRuntimeHelvetia:async()=>({pa:48,recherche:[],journal:[]}),
 sbInventaireReceptionEtat:async()=>({ok:true,inventory:[{stackKey:'bois',qty:2}],revision:1}),
 sbAdopterInventaireServeur:r=>{c.state.inventory=r.inventory;return true;}});
 c.sbRpcVerdict=async(fn,p)=>{appels.push({fn,p});return {ok:true,reussite:true,detecte:false,quantite:2,message:'Deux bois accordés.'};};
 vm.runInContext(fonction('plateau-rue-centrale.js','contexteNavigationRue')+'\n'+fonction('plateau-rue-centrale.js','contexteNavigationRueValide')+'\nlet constructionCommandeEnCours=false;\n'+fonction('plateau-construction-commandes.js','constructionExecuterCommande')+'\n'+fonction('plateau-justice-economie.js','confirmerVolMateriaux'),c);
 return {c,stockage,appels,messages};
}
test('handler actuel : commande commune seule, inventaire relu, aucun coût ou jet local',async()=>{
 const x=fixture();await x.c.confirmerVolMateriaux('bois',999,9999);
 assert.equal(x.appels.length,1);assert.equal(x.appels[0].fn,'chantier_commande');
 assert.deepEqual(JSON.parse(JSON.stringify(x.appels[0].p.p_parametres)),{matiere:'bois'});
 assert.equal(x.appels[0].p.p_action,'voler');assert.equal(x.c.state.inventory[0].qty,2);
 assert.equal(x.messages.at(-1)[1],'Deux bois accordés.');assert.equal(x.stockage.size,0);
});
test('réponse perdue : intention conservée et même identifiant à la reprise',async()=>{
 const x=fixture();let n=0;x.c.sbRpcVerdict=async(fn,p)=>{x.appels.push({fn,p});return ++n===1?{ok:false,transport:{etat:'reseau'}}:{ok:true,rejeu:true,reussite:true,detecte:false,quantite:2,message:'Reçu existant.'};};
 await x.c.confirmerVolMateriaux('bois',2,0);assert.equal(x.stockage.size,1);assert.equal(x.c.state.inventory,undefined);
 await x.c.confirmerVolMateriaux('bois',2,0);assert.equal(x.appels[0].p.p_requete,x.appels[1].p.p_requete);assert.equal(x.stockage.size,0);
});
test('double clic pendant traitement : une seule commande',async()=>{
 const x=fixture();let finir;x.c.sbRpcVerdict=async(fn,p)=>{x.appels.push({fn,p});return new Promise(r=>finir=r);};
 const a=x.c.confirmerVolMateriaux('bois',2,0);await x.c.confirmerVolMateriaux('bois',2,0);
 assert.equal(x.appels.length,1);finir({ok:true,reussite:true,detecte:false,quantite:2,message:'Accordé'});await a;
});
for(const changement of ['personnage','ville','piece'])test('réponse tardive/'+changement+' : aucun inventaire ni succès pour le nouveau contexte',async()=>{
 const x=fixture();let finir;x.c.sbRpcVerdict=()=>new Promise(r=>finir=r);
 const a=x.c.confirmerVolMateriaux('bois',2,0);
 if(changement==='personnage')x.c.state.char={name:'Autre'};
 if(changement==='ville')x.c.state.currentCity='ville_a';
 if(changement==='piece')x.c.state.currentRoom='autre';
 finir({ok:true,reussite:true,message:'Ancien accord'});await a;
 assert.equal(x.c.state.inventory,undefined);assert.equal(x.messages.length,0);assert.equal(x.stockage.size,1);
});
test('inventaire impossible à relire : reçu conservé, pas de faux succès de vol',async()=>{
 const x=fixture();x.c.sbInventaireReceptionEtat=async()=>null;await x.c.confirmerVolMateriaux('bois',2,0);
 assert.equal(x.stockage.size,1);assert.equal(x.c.state.inventory,undefined);assert.equal(x.messages.at(-1)[0],'Commande acquise');
});
test('autre matière pendant intention incertaine : aucune nouvelle commande',async()=>{
 const x=fixture();x.c.sbRpcVerdict=async(fn,p)=>{x.appels.push(p);return null;};
 await x.c.confirmerVolMateriaux('bois',2,0);await x.c.confirmerVolMateriaux('metal',2,0);
 assert.equal(x.appels.length,1);assert.equal(x.stockage.size,1);assert.equal(x.messages.at(-1)[0],'Commande en attente');
});
test('refus métier : aucune attribution et intention libérée',async()=>{
 const x=fixture();x.c.sbRpcVerdict=async()=>({ok:false,raison:'stock_vide'});await x.c.confirmerVolMateriaux('bois',2,0);
 assert.equal(x.c.state.inventory,undefined);assert.equal(x.stockage.size,0);assert.equal(x.messages.at(-1)[0],'Commande non confirmée');
});

test('ouverture du vol : presence serveur plutot que compteur JSON historique',async()=>{
 const x=fixture();let contenu;
 x.c.getTerrainState=()=>({chantier:{stockMateriaux:{bois:20},vigiles:999}});
 x.c.sbRpcVerdict=async()=>({ok:true,nombre:2});x.c.constructionFenetre=(titre,html)=>contenu=html;
 x.c.constructionEchapper=String;x.c.constructionBouton=(label,js)=>label+js;
 vm.runInContext(fonction('plateau-justice-economie.js','doVolerMaterielChantier'),x.c);
 await x.c.doVolerMaterielChantier(2,0);assert.match(contenu,/présents : 2/);assert.doesNotMatch(contenu,/999/);
});
test('lecture de protection indisponible : pas de faux compteur nul ni de formulaire',async()=>{
 const x=fixture();let ouvert=false;x.c.sbRpcVerdict=async()=>null;x.c.constructionFenetre=()=>ouvert=true;
 vm.runInContext(fonction('plateau-justice-economie.js','doVolerMaterielChantier'),x.c);
 await x.c.doVolerMaterielChantier(2,0);assert.equal(ouvert,false);assert.equal(x.messages.at(-1)[0],'Chantier indisponible');
});

test('changement de personnage pendant renouvellement auth : aucune requête envoyée',async()=>{
 const x=fixture();let finir,jeton=null,requêtes=0;
 x.c.rpAuthUid=()=> 'uid-fixture';x.c.rpAuthSessionIdentifiant=()=> 'session-stable';
 x.c.rpAuthJeton=()=>jeton;x.c.RP_RPC_PUBLIQUES=new Set();
 x.c.rpAuthAssurerSession=()=>new Promise(r=>finir=r);
 x.c.fetch=async()=>{requêtes++;throw Error('requête interdite dans ce cas');};
 vm.runInContext(fonction('supabase.js','sbTransportRpc'),x.c);
 x.c.sbRpcVerdict=async(fn,p,options)=>{assert.equal(typeof options?.encoreValide,'function');const env=await x.c.sbTransportRpc(fn,p,options);return {ok:false,transport:env};};
 const a=x.c.confirmerVolMateriaux('bois',2,0);x.c.state.char={name:'Autre'};jeton='jeton-fixture';finir();await a;
 assert.equal(requêtes,0);assert.equal(x.c.state.inventory,undefined);assert.equal(x.messages.length,0);
});

test('réponse de succès incomplète : intention gardée sans inventaire ou succès fabriqué',async()=>{
 const x=fixture();x.c.sbRpcVerdict=async()=>({ok:true});await x.c.confirmerVolMateriaux('bois',2,0);
 assert.equal(x.c.state.inventory,undefined);assert.equal(x.stockage.size,1);assert.equal(x.messages.at(-1)[0],'Résultat non confirmé');
});
