// Production en VM ; serveur simule. Atomicite et autorite SQL : banc PostgreSQL distinct.
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const root=path.resolve(__dirname,'../..');
function jeu(){
 const c=vm.createContext({console,state:{char:{name:'Alice'},country:'republic',inventory:[],_inventaireBase:'[]',personnageChargeDepuisServeur:true},uid:'u',jeton:'t'});
 c.rpAuthUid=()=>c.uid;c.rpAuthJeton=()=>c.jeton;
 vm.runInContext(fs.readFileSync(path.join(root,'supabase.js'),'utf8'),c);
 const s=fs.readFileSync(path.join(root,'plateau-communication.js'),'utf8');
 vm.runInContext(s.slice(s.indexOf('// Verifie les objets recus'),s.indexOf('// Lots de tracts transmissibles')),c);
 c.serveur={inventory:[],revision:0,queue:[{id:'objet-1',objet:{name:'Livre',qty:1},expediteur:'Donneur'}]};
 const copier=x=>JSON.parse(JSON.stringify(x));
 c.etat=()=>c.sbMarquerInventaires({ok:true,contrat:1,inventory:copier(c.serveur.inventory),revision:c.serveur.revision},c.sbContexteInventaire());
 c.sbInventaireReceptionEtat=async()=>c.etat();c.sbGetLivraisonsEnAttente=async()=>c.serveur.queue.map(o=>({id:o.id}));
 c.sbInventaireReclamerLivraison=async(n,id,rev)=>{
  assert.equal(n,'Alice');assert.equal(rev,c.serveur.revision);const i=c.serveur.queue.findIndex(o=>o.id===id);
  if(i<0)return {...c.etat(),rejeu:true};
  const r=c.serveur.queue.splice(i,1)[0];c.serveur.inventory.push(r.objet);c.serveur.revision++;
  return {...c.etat(),...r,rejeu:false};
 };
 c.sbInventaireSauverRevision=async(n,r,inv)=>{
  if(r!==c.serveur.revision)return {ok:false,raison:'inventaire_perime'};
  c.serveur.inventory=copier(inv);c.serveur.revision++;return c.etat();
 };
 c.sbEcrirePersonnage=async()=>[{}];
 c.recevoirObjetAutomatique=c.recevoirLotTracts=c.sbSupprimerObjetRecu=()=>assert.fail('Ancien circuit interdit');
 return c;
}
for(const changement of ['personnage','compte','session'])test(`lecture tardive/${changement} : aucune reclamation ni contamination`,async()=>{
 const c=jeu();let resolve,n=0;c.sbInventaireReceptionEtat=()=>new Promise(r=>resolve=r);c.sbInventaireReclamerLivraison=async()=>{n++;};
 const p=c.verifierObjetsRecus();
 if(changement==='personnage')c.state.char={name:'Bob'};
 if(changement==='compte')c.uid='autre';if(changement==='session')c.jeton='autre';
 resolve(c.etat());await p;assert.equal(n,0);assert.equal(c.state.inventory.length,0);
});
test('changement pendant reception confirmee : aucun ajout au nouveau personnage',async()=>{
 const c=jeu();let resolve;const recevoir=c.sbInventaireReclamerLivraison;
 c.sbInventaireReclamerLivraison=async(...args)=>{const v=await recevoir(...args);return new Promise(r=>resolve=()=>r(v));};
 const p=c.verifierObjetsRecus();await new Promise(r=>setImmediate(r));c.state.char={name:'Bob'};resolve();await p;
 assert.equal(c.state.inventory.length,0);assert.equal(c.serveur.inventory.length,1);
});
test('deux polls simultanes ne reclament pas deux fois',async()=>{
 const c=jeu();let resolve,n=0;c.sbInventaireReceptionEtat=()=>{n++;return new Promise(r=>resolve=r);};
 const a=c.verifierObjetsRecus(),b=c.verifierObjetsRecus();assert.equal(n,1);resolve(c.etat());await Promise.all([a,b]);assert.equal(c.serveur.inventory.length,1);
});
test('reception nominale puis repetitions : adoption du resultat autoritaire sans delta local',async()=>{
 const c=jeu();await c.verifierObjetsRecus();await c.verifierObjetsRecus();assert.equal(c.state.inventory[0].name,'Livre');assert.equal(c.state.inventory.length,1);assert.equal(c.state._inventaireRevision,1);
});
test('migration absente ou panne : jamais de repli destructif',async()=>{
 for(const resultat of [null,{ok:false},{}]){const c=jeu();c.sbInventaireReceptionEtat=async()=>resultat;await c.verifierObjetsRecus();assert.equal(c.serveur.queue.length,1);assert.equal(c.state.inventory.length,0);}
});
test('reponse perdue apres commit : le prochain poll relit sans doublon',async()=>{
 const c=jeu(),recevoir=c.sbInventaireReclamerLivraison;c.sbInventaireReclamerLivraison=async(...a)=>{await recevoir(...a);throw Error('reseau');};
 await c.verifierObjetsRecus();assert.equal(c.state.inventory.length,0);assert.equal(c.serveur.inventory.length,1);
 c.sbInventaireReclamerLivraison=recevoir;await c.verifierObjetsRecus();assert.equal(c.state.inventory.length,1);
});
test('ajout local non sauvegarde : CAS avant reception, sans perte',async()=>{
 const c=jeu();c.state.inventory.push({name:'Objet de quete local'});await c.verifierObjetsRecus();
 assert.equal(c.state.inventory.length,2);assert.equal(c.serveur.inventory[0].name,'Objet de quete local');
});
test('conflit entre ajout local et nouvel inventaire serveur : rien ecrase, livraison conservee',async()=>{
 const c=jeu();c.state.inventory.push({name:'Local'});c.serveur.inventory.push({name:'Serveur'});c.serveur.revision=1;
 await c.verifierObjetsRecus();assert.equal(c.state.inventory[0].name,'Local');assert.equal(c.serveur.inventory[0].name,'Serveur');assert.equal(c.serveur.queue.length,1);assert.equal(c.state._inventaireConflit,true);
});
test('modification locale pendant reponse : ne pas ecraser le nouvel ajout',async()=>{
 const c=jeu();let resolve;const recevoir=c.sbInventaireReclamerLivraison;
 c.sbInventaireReclamerLivraison=async(...args)=>{const v=await recevoir(...args);return new Promise(r=>resolve=()=>r(v));};
 const p=c.verifierObjetsRecus();await new Promise(r=>setImmediate(r));c.state.inventory.push({name:'Pendant'});resolve();await p;
 assert.equal(c.state.inventory[0].name,'Pendant');assert.equal(c.serveur.inventory[0].name,'Livre');assert.equal(c.state._inventaireConflit,true);
});
test('carte postale : contenu et expediteur restent confidentiels a la reception',async()=>{
 const c=jeu(),messages=[];c.serveur.queue=[{id:'carte',expediteur:'IdentiteSecrete',objet:{name:'Secret',familleProduitMarche:'carte_postale',message:'TexteSecret'}}];
 c.showToast=(...args)=>messages.push(args.join(' '));c.addJournalEntry=m=>messages.push(m);
 await c.verifierObjetsRecus();assert.equal(c.state.inventory.length,1);assert.ok(messages.length>0);assert.ok(messages.every(m=>!m.includes('IdentiteSecrete')&&!m.includes('TexteSecret')));
});
test('tracts : resultat serveur adopte, aucun recevoirLotTracts local',async()=>{
 const c=jeu();c.serveur.queue=[{id:'don-tracts-1',expediteur:'Donneur',objet:{type:'tract',quantite:9,name:'Programme'}}];await c.verifierObjetsRecus();assert.equal(c.state.inventory[0].quantite,9);
});
test('sauvegarde versionnee : inventaire exclu du PATCH et de la fermeture',async()=>{
 const c=jeu();c.state._inventaireRevision=0;let donnees;
 c.sbEcrirePersonnage=async d=>{donnees=d;return [{}];};await c.sbSavePersonnage(c.state);assert.equal('inventory' in donnees,false);
 c.state._dernierUpdatedAtConnu='date';let body;c.fetch=async(u,o)=>{body=JSON.parse(o.body);};c.sbSauvegardeUrgenceDechargement();assert.equal('inventory' in body,false);
});
test('une sauvegarde capture sa revision avec son snapshot et ne la rajeunit pas dans la file',async()=>{
 const c=jeu();c.state._inventaireRevision=0;let revision;c.sbInventaireSauverRevision=async(n,r)=>{revision=r;return {ok:false};};
 const p=c.sbSavePersonnage(c.state);c.state._inventaireRevision=7;await p;assert.equal(revision,0);
});
test('ancien retour RPC apres reception : impossible de restaurer son inventaire perime',async()=>{
 const c=jeu();const ancien=c.sbMarquerInventaires({inventory:[]},c.sbContexteInventaire());
 await c.verifierObjetsRecus();assert.equal(c.sbAdopterInventaireServeur(ancien),false);assert.equal(c.state.inventory[0].name,'Livre');
});
test('reponse deja recue mais adoptee tardivement : la garde est au point de mutation',async()=>{
 const c=jeu();c.sbTransportRest=async()=>({etat:'ok',donnees:[{inventory:[]}]});
 const anciennes=await c.sbGet('personnages','');await c.verifierObjetsRecus();
 assert.equal(c.sbAdopterInventaireServeur(anciennes[0]),false);assert.equal(c.state.inventory.length,1);
});
test('retour frais sans revision : le miroir reste valide, le prochain PATCH exclut son inventaire',async()=>{
 const c=jeu();await c.verifierObjetsRecus();
 const r=c.sbMarquerInventaires({inventory:[]},c.sbContexteInventaire());assert.equal(c.sbAdopterInventaireServeur(r),true);
 assert.equal(c.state._inventaireRevision,null);assert.equal(c.state._inventaireVersionne,true);
 let body;c.sbEcrirePersonnage=async d=>{body=d;return [{}];};await c.sbSavePersonnage(c.state);assert.equal('inventory' in body,false);
});
test('provenance de reponse conservee par spread et jamais serialisee vers le serveur',()=>{
 const c=jeu(),r=c.sbMarquerInventaires({inventory:[]},c.sbContexteInventaire());
 assert.deepEqual(JSON.parse(JSON.stringify(r)),{inventory:[]});c.state.char={name:'Bob'};
 assert.equal(c.sbAdopterInventaireServeur({...r}),false);
});
test('ordre des cles JSON : egalite semantique, aucun faux conflit ou ajout perdu',async()=>{
 const c=jeu();c.state.inventory=[{name:'Livre',qty:1}];c.serveur.inventory=[{qty:1,name:'Livre'}];
 c.state._inventaireBase=c.sbEmpreinteInventaire(c.state.inventory);c.serveur.queue=[];
 c.sbInventaireSauverRevision=()=>assert.fail('Aucune sauvegarde pour un ordre de cles');
 await c.verifierObjetsRecus();assert.equal(c.state._inventaireRevision,0);assert.equal(c.state._inventaireConflit,false);
});
