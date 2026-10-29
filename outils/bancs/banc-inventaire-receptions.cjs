// Transport controle ; vrais handlers et vraie adoption versionnee de supabase.js.
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const root=require('node:path').resolve(__dirname,'../..');
function extrait(file,start,end){const s=fs.readFileSync(root+'/'+file,'utf8'),a=s.indexOf(start),b=s.indexOf(end,a);assert(a>=0&&b>a);return s.slice(a,b);}
function monde(rpc){
 const stockage=new Map(),appels=[];let nonce=0;
 const c=vm.createContext({state:{char:{name:'Fixture'},country:'republic',currentCity:'capitale',currentBuilding:'mairie-capitale',currentRoom:'hall_mairie',inventory:[],_inventaireVersionne:true},
  rpAuthUid:()=> 'fixture-uid',rpAuthSessionIdentifiant:()=> 'fixture-session',
  sessionStorage:{getItem:k=>stockage.get(k),setItem:(k,v)=>stockage.set(k,v),removeItem:k=>stockage.delete(k)},crypto:{randomUUID:()=> 'nonce-'+(++nonce)},
  showToast:(...a)=>appels.push(['toast',...a]),signalerRefusCout:v=>appels.push(['refus',v]),updateUI:()=>appels.push(['ui']),appliquerPaiementServeur:v=>appels.push(['paie',v])});
 vm.runInContext(extrait('supabase.js','const RP_INVENTAIRE_ORIGINE =','// Fusionne uniquement'),c);
 c.sbRpcVerdict=async(fn,p,opts)=>{appels.push(['rpc',fn,p]);const o=c.sbContexteInventaire();const r=await rpc(fn,p,opts,c);return c.sbMarquerInventaires(r,o);};
 vm.runInContext(extrait('plateau-divers.js','const receptionsInventaireEnCours =','// ACHAT D\'UN OBJET PAR LE SERVEUR'),c);
 return {c,stockage,appels};
}
const succes=()=>({ok:true,inventory:[{id:'serveur',name:'Objet'}],revision:8,paie:{pa:9},trouve:true});
test('adopte la reponse marquee elle-meme et supprime seulement une intention confirmee',async()=>{
 const r=succes(),m=monde(async()=>r);assert.equal(await m.c.executerReceptionInventaire('x',{}),r);assert.equal(m.c.state.inventory,r.inventory);assert.equal(m.c.state._inventaireRevision,8);assert.equal(m.stockage.size,0);assert.equal(m.appels.filter(a=>a[0]==='paie').length,1);
});
test('double clic : une seule demande en cours',async()=>{let finir;const m=monde(()=>new Promise(r=>finir=r));const p=m.c.executerReceptionInventaire('x',{});assert.equal(await m.c.executerReceptionInventaire('x',{}),null);finir(succes());await p;assert.equal(m.appels.filter(a=>a[0]==='rpc').length,1);});
test('reponse perdue : nonce et parametres conserves pour le rejeu',async()=>{let k=0;const m=monde(async()=>++k===1?{ok:false,transport:{etat:'reseau'}}:succes());assert.equal(await m.c.executerReceptionInventaire('x',{n:2}),null);assert.equal(m.stockage.size,1);await m.c.executerReceptionInventaire('x',{n:2});const r=m.appels.filter(a=>a[0]==='rpc');assert.equal(r[0][2].p_requete,r[1][2].p_requete);});
test('selection ou revision modifiee : termine seulement le rejeu de la demande precedente',async()=>{let k=0;const m=monde(async()=>++k===1?{ok:false,transport:{etat:'reseau'}}:succes());await m.c.executerReceptionInventaire('x',{n:2});assert.equal(await m.c.executerReceptionInventaire('x',{n:3}),null);const r=m.appels.filter(a=>a[0]==='rpc');assert.equal(r.length,2);assert.equal(r[1][2].n,2);assert.equal(r[0][2].p_requete,r[1][2].p_requete);assert.equal(m.stockage.size,0);});
test('refus metier ne donne aucun objet ni paiement local',async()=>{const m=monde(async()=>({ok:false,raison:'fonds_insuffisants'}));assert.equal(await m.c.executerReceptionInventaire('x',{}),null);assert.equal(m.c.state.inventory.length,0);assert.equal(m.appels.filter(a=>a[0]==='paie').length,0);assert.equal(m.stockage.size,0);});
for(const changement of ['personnage','personnage_muté','lieu','ville','generation','session']) test('reponse tardive ignoree apres changement de '+changement,async()=>{
 let finir;const m=monde(()=>new Promise(r=>finir=r));const p=m.c.executerReceptionInventaire('x',{});
 if(changement==='personnage')m.c.state.char={name:'Autre'};
 if(changement==='personnage_muté')m.c.state.char.name='Autre';
 if(changement==='lieu')m.c.state.currentRoom='rue';
 if(changement==='ville')m.c.state.currentCity='ville_a';
 if(changement==='generation')m.c.state._inventaireGeneration=2;
 if(changement==='session')m.c.rpAuthSessionIdentifiant=()=> 'autre';
 finir(succes());assert.equal(await p,null);assert.equal(m.c.state.inventory.length,0);assert.equal(m.stockage.size,1);assert.equal(m.appels.filter(a=>a[0]==='paie').length,0);
});
test('authentification retardee : garde fournie au transport existant',async()=>{let garde;const m=monde(async(f,p,opts)=>{garde=opts.encoreValide;assert(garde());return succes();});await m.c.executerReceptionInventaire('x',{});m.c.state.char={name:'Autre'};assert.equal(garde(),false);});
test('inventaire incomplet : pas de faux succes ni de nouveau nonce',async()=>{const m=monde(async()=>({ok:true,inventory:[]}));assert.equal(await m.c.executerReceptionInventaire('x',{}),null);assert.equal(m.stockage.size,1);assert.equal(m.appels.filter(a=>a[0]==='paie').length,0);});
test('adoption refuse un inventaire recompose sans marque serveur',()=>{const m=monde(async()=>succes());assert.equal(m.c.sbAdopterInventaireServeur({ok:true,inventory:[],revision:2}),false);});
test('session perdue sans envoi : aucune intention fantome ne bloque ou rejoue une autre selection',async()=>{
 const m=monde(async()=>({ok:false,raison:'session_perdue',transport:{etat:'session_perdue',envoyee:false}}));await m.c.executerReceptionInventaire('x',{});assert.equal(m.stockage.size,0);assert.equal(m.c.state.inventory.length,0);assert(m.appels.some(a=>a[0]==='toast'&&a[1]==='Demande non envoyée'));
});
test('reponse transport perdue apres envoi : ne pretend pas que le paiement a ete refuse',async()=>{
 const m=monde(async()=>({ok:false,transport:{etat:'reseau',envoyee:true}}));await m.c.executerReceptionInventaire('x',{});assert.equal(m.stockage.size,1);assert(m.appels.some(a=>a[0]==='toast'&&a[1]==='Confirmation incertaine'));assert.equal(m.appels.filter(a=>a[0]==='refus').length,0);
});
