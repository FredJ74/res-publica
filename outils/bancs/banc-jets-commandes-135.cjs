const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),acorn=require('../vercel/node_modules/acorn');
const source=fs.readFileSync('plateau-jets-commandes.js','utf8');
function fixture(stockage=new Map()){
 const appels=[],messages=[],c=vm.createContext({console,Map,Symbol,JSON,Number,Object,Array,crypto:{randomUUID:()=> 'uuid-fixture-'+Math.random()},sessionStorage:{getItem:k=>stockage.get(k)||null,setItem:(k,v)=>stockage.set(k,v),removeItem:k=>stockage.delete(k)},state:{char:{name:'Fixture'},country:'republic',currentCity:'capitale',currentBuilding:'armurerie',currentRoom:'magasin',_inventaireGeneration:0,_dernierUpdatedAtConnu:'ancien'},uid:'uid-fixture',session:'session-fixture',showToast:(...x)=>messages.push(x),updateUI:()=>{},addJournalEntry:()=>{},document:{getElementById:()=>null,querySelector:()=>({value:'Autre'})}});
 c.rpAuthUid=()=>c.uid;c.rpAuthJeton=()=>c.session;c.rpAuthSessionIdentifiant=()=>c.session;
 c.contexteNavigationRue=()=>({uid:c.uid,nom:c.state.char.name,char:c.state.char,pays:c.state.country,session:c.session});
 c.contexteNavigationRueValide=x=>x.uid===c.uid&&x.char===c.state.char&&x.pays===c.state.country&&x.session===c.session;
 c.contrat={ok:true,actesAtomiques:1,personnageId:'personnage-fixture'};
 c.resultat={ok:true,succes:true,bonus:5,cible:'Autre',execution:{jours:3},deplacements:[],quantite:2,matiere:'bois',butin:'argent',montant:50,amende:0,pertePop:0,reliquat:3,prix:750,objet:{name:'Arme fixture'},realites:{benediction:{actif:false}}};
 c.sbRpcVerdict=async(fn,p)=>{appels.push({fn,p});return fn==='religion_benediction_lire'?c.contrat:c.resultat;};
 c.rafraichirRuntimeHelvetia=async()=>c.frais;
 c.frais={pa:42,hp:90,pop:0,userId:c.uid,updatedAt:'nouveau',inventory:[],_inventaireRevision:2};
 const supabase=fs.readFileSync('supabase.js','utf8'),ast=acorn.parse(supabase,{ecmaVersion:'latest'});
 const morceaux=ast.body.filter(n=>n.type==='VariableDeclaration'&&n.declarations.some(d=>d.id.name==='RP_INVENTAIRE_ORIGINE')||n.type==='FunctionDeclaration'&&['sbContexteInventaire','sbEmpreinteInventaire','sbMarquerInventaires','sbAdopterInventaireServeur'].includes(n.id.name));
 for(const n of morceaux)vm.runInContext(supabase.slice(n.start,n.end),c);
 vm.runInContext(source,c);return{c,appels,messages,stockage};
}
test('serveur non activé : aucun hôte nouveau appelé et comportement historique conservé',async()=>{
 const f=fixture();f.c.contrat={ok:true,actesAtomiques:0};assert.equal(await f.c.l09Intercepter('vol',{p_cible:'Autre',p_genre:'argent'}),false);assert.equal(f.appels.length,1);assert.equal(f.stockage.size,0);
});
test('session perdue : ne jamais basculer sur un ordre historique après erreur',async()=>{
 const f=fixture();f.c.contrat={ok:false,raison:'session_perdue',transport:{http:401}};assert.equal(await f.c.l09Intercepter('vol',{}),true);assert.equal(f.appels.length,1);
});
test('huit entrées délèguent au même adaptateur privé sans prix ni PA navigateur',async()=>{
 const f=fixture();for(const ordre of ['vol','achat_arme_illegal','tentative_evasion','mener_enquete','organiser_filature','organiser_chasse_homme','voler_materiel_chantier','benediction'])await f.c.l09Intercepter(ordre,{});
 const a=f.appels.filter(a=>a.fn==='ordres_jets_commande');assert.equal(a.length,8);assert.ok(a.every(x=>x.p.p_personnage==='personnage-fixture'&&!('p_pa'in x.p)&&!('p_montant'in x.p)));assert.equal(f.c.state.pa,42);assert.equal(f.c.state.pop,0);assert.equal(f.c.state._dernierUpdatedAtConnu,'ancien');
});
test('réponse perdue : même UUID, paramètres liés, aucune fausse réussite',async()=>{
 const f=fixture(),p={p_cible:'Autre',p_genre:'argent'};f.c.resultat={ok:false,transport:{etat:'reseau'}};await f.c.l09Intercepter('vol',p);const cle=f.appels.at(-1).p.p_requete;assert.equal(f.stockage.size,1);
 await f.c.l09Intercepter('vol',{...p,p_genre:'objet'});assert.equal(f.appels.filter(a=>a.fn==='ordres_jets_commande').length,1);
 f.c.resultat={ok:true,succes:true,butin:'rien'};await f.c.l09Intercepter('vol',p);assert.equal(f.appels.at(-1).p.p_requete,cle);assert.equal(f.stockage.size,0);
});
test('rechargement : intention conservée pour la même identité immuable',async()=>{
 const a=fixture();a.c.resultat={ok:false,transport:{etat:'reseau'}};await a.c.l09Intercepter('vol',{});const id=a.appels.at(-1).p.p_requete;
 const b=fixture(a.stockage);await b.c.l09Intercepter('vol',{});assert.equal(b.appels.at(-1).p.p_requete,id);
});
test('personnage recréé de même nom : intention ancienne jamais réutilisée',async()=>{
 const a=fixture();a.c.resultat={ok:false,transport:{etat:'reseau'}};await a.c.l09Intercepter('vol',{});const id=a.appels.at(-1).p.p_requete;
 const b=fixture(a.stockage);b.c.contrat.personnageId='autre-identite';await b.c.l09Intercepter('vol',{});assert.notEqual(b.appels.at(-1).p.p_requete,id);assert.equal(b.stockage.size,1);
});
test('absence d’identité serveur : aucun ordre',async()=>{
 const f=fixture();delete f.c.contrat.personnageId;await f.c.l09Intercepter('vol',{});assert.equal(f.appels.length,1);
});
test('lecture financière impossible : reçu confirmé mais reprise non supprimée',async()=>{
 const f=fixture();f.c.frais=null;await f.c.l09Intercepter('vol',{});assert.equal(f.stockage.size,1);assert.equal(f.c.state.pa,undefined);
});
test('écriture de stockage impossible : pas de commande envoyée',async()=>{
 const f=fixture();f.c.sessionStorage.setItem=()=>{throw Error('stockage indisponible');};await f.c.l09Intercepter('vol',{});assert.equal(f.appels.length,1);
});
test('double clic en cours : une seule commande',async()=>{
 const f=fixture();let finir;f.c.sbRpcVerdict=async(fn,p)=>{f.appels.push({fn,p});if(fn==='religion_benediction_lire')return f.c.contrat;return new Promise(r=>finir=r);};
 const a=f.c.l09Intercepter('vol',{});for(let i=0;i<5&&!finir;i++)await Promise.resolve();assert.ok(finir);await f.c.l09Intercepter('vol',{});assert.equal(f.appels.length,2);finir(f.c.resultat);await a;
});
test('réponse tardive après changement de personnage : aucun état adopté',async()=>{
 const f=fixture();let finir;f.c.sbRpcVerdict=async(fn,p)=>{f.appels.push({fn,p});return fn==='religion_benediction_lire'?f.c.contrat:new Promise(r=>finir=r);};
 const a=f.c.l09Intercepter('vol',{});for(let i=0;i<5&&!finir;i++)await Promise.resolve();f.c.state.char={name:'Autre'};finir(f.c.resultat);await a;assert.equal(f.c.state.pa,undefined);assert.equal(f.stockage.size,1);
});
test('inventaire modifié pendant la relecture : vrai garde refuse l’adoption',async()=>{
 const f=fixture();f.c.rafraichirRuntimeHelvetia=async()=>{f.c.state._inventaireGeneration++;return f.c.frais;};await f.c.l09Intercepter('vol',{});assert.equal(f.stockage.size,1);assert.equal(f.c.state.inventory,undefined);
});
test('refus métier confirmé : rien affiché comme succès',async()=>{
 const f=fixture();f.c.resultat={ok:false,raison:'fonds_insuffisants'};await f.c.l09Intercepter('vol',{});assert.equal(f.stockage.size,0);assert.ok(f.messages.some(m=>m[0]==='Ordre refusé'));assert.equal(f.c.state.pa,undefined);
});
test('les huit vrais points d’entrée quittent le chemin historique après prise en charge',async()=>{
 const f=fixture();f.c.l09Intercepter=async(...x)=>{f.appels.push(x);return true;};f.c.getEntrepriseIdArmurerie=()=> 'armurerie-fixture';
 const fichiers={'plateau-actions-illegales-rumeurs.js':['confirmerVol','confirmerAchatArmeIllegal'],'plateau-justice-economie.js':['doTentativeEvasion','confirmerMenerEnquete','confirmerOrganiserFilature','confirmerOrganiserChasseHomme','confirmerVolMateriaux'],'plateau-divers.js':['doDemanderBenedictionContact']};
 for(const[file,noms]of Object.entries(fichiers)){const s=fs.readFileSync(file,'utf8'),ast=acorn.parse(s,{ecmaVersion:'latest'});for(const nom of noms){const n=ast.body.find(n=>n.type==='FunctionDeclaration'&&n.id.name===nom);vm.runInContext(s.slice(n.start,n.end),f.c);}}
 await f.c.confirmerVol(encodeURIComponent(JSON.stringify({name:'Autre'})),999,'argent');await f.c.confirmerAchatArmeIllegal('couteau');await f.c.doTentativeEvasion(999,999);await f.c.confirmerMenerEnquete(999,999);await f.c.confirmerOrganiserFilature(999,999);await f.c.confirmerOrganiserChasseHomme(999,999);await f.c.confirmerVolMateriaux('bois',999,999);await f.c.doDemanderBenedictionContact('Père Ception');assert.equal(f.appels.length,8);assert.ok(f.appels.every(a=>!JSON.stringify(a[1]).includes('999')));
});

test('suspension explicite : aucun retour à un ordre historique',async()=>{
 const f=fixture();f.c.contrat={ok:true,actesAtomiques:0,actesSuspendus:true,personnageId:'personnage-fixture'};assert.equal(await f.c.l09Intercepter('vol',{}),true);assert.equal(f.appels.length,1);
});
test('suspension avec reçu en attente : reprise du même UUID seulement',async()=>{
 const f=fixture();f.c.resultat={ok:false,transport:{etat:'reseau'}};await f.c.l09Intercepter('vol',{});const id=f.appels.at(-1).p.p_requete;
 f.c.contrat.actesAtomiques=0;f.c.contrat.actesSuspendus=true;f.c.resultat={ok:true,rejeu:true,succes:true,butin:'rien'};await f.c.l09Intercepter('vol',{});assert.equal(f.appels.at(-1).p.p_requete,id);assert.equal(f.stockage.size,0);
});
