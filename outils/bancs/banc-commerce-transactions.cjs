// node --test outils/bancs/banc-commerce-transactions.cjs
// Vrai module UI, transport et registres simules ; jamais une preuve SQL.
const test=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const code=fs.readFileSync(path.resolve(__dirname,'../../plateau-commerce-pj.js'),'utf8');
const actions=[
 ['commercePjCaisseMouvement',['apport'],'sbAlimenterCaisseFonds'],
 ['commercePjProduireLots',['ref'],'sbFondsReferenceProduireLots'],
 ['commercePjProduire',['ref','production-test','publique'],'sbFondsReferenceProduire'],
 ['commercePjApporterDepuisTerminal',['bois','vente'],'sbFondsMatiereApporter'],
 ['commercePjApporter',['bois','apport-test','vente'],'sbFondsMatiereApporter'],
 ['commercePjAcheter',['ref','achat-test'],'sbAcheterProduitCommerce'],
 ['commercePjConsommerSurPlace',['ref','achat-test'],'sbRpcVerdict']
];
function plateau(rpc=async()=>({ok:true,montant:10,salaire:10,quantite:1,prixUnitaire:10,caisse:50,paRestants:2,inventory:[{name:'Ancien snapshot'}]})){
 const appels=[];const c=vm.createContext({console,SUPABASE_URL:'https://test.invalid',
  state:{char:{name:'Alice'},country:'republic',currentCity:'capitale',currentBuilding:'commerce',currentRoom:'boutique',arg:1000,liquide:1000,pa:8,inventory:[{name:'Personnel'}]},
  document:{getElementById:id=>id==='cpj-payeur-collectif'?null:({value:'1',innerHTML:''})},rpAuthUid:()=> 'uid-alice'});
 vm.runInContext(code,c);
 c.commercePjContexte=async()=>({fondsId:'fonds',jeSuisProprietaire:true});
 c.sbGet=async()=>[{user_id:'uid-alice',arg:300,liquide:200,pa:5,hp:70,moral:60,inventory:[{name:'Inventaire actuel'}]}];
 for(const n of ['sbAlimenterCaisseFonds','sbRetirerCaisseFonds','sbFondsReferenceProduireLots','sbFondsReferenceProduire','sbFondsMatiereApporter','sbAcheterProduitCommerce','sbRpcVerdict'])
  c[n]=async(...a)=>{appels.push(['rpc',n,...a]);return rpc(...a);};
 for(const n of ['commercePjEcranGestion','commercePjEcranTravail','commercePjEcranArticles','commercePjEcranMatieresPubliques','commercePjEcranBoutique','renderInventory','updateUI','verifierObjetsRecus'])c[n]=()=>appels.push([n]);
 c.showToast=(...a)=>appels.push(['toast',...a]);c.addJournalEntry=()=>appels.push(['journal']);
 c.commercePjMessage=()=>{};c.nouvelleCleProduction=()=> 'production-test';c.nouvelleCleApport=()=> 'apport-test';
 return {c,appels};
}
for(const [fn,args] of actions){
 test(`${fn} : solde et PA sont relus, jamais calcules a partir d’un vieux miroir`,async()=>{
  const {c}=plateau();await c[fn](...args);assert.equal(c.state.arg,300);assert.equal(c.state.liquide,200);assert.equal(c.state.pa,5);
  if(fn.startsWith('commercePjApporter'))assert.equal(c.state.inventory[0].name,'Inventaire actuel');
 });
 test(`${fn} : double clic en vol, une seule transaction`,async()=>{
  const attentes=[];const {c,appels}=plateau(()=>new Promise(r=>attentes.push(r)));
  const p=c[fn](...args);await new Promise(r=>setImmediate(r));
  const second=c[fn](...args);await new Promise(r=>setImmediate(r));
  const n=appels.filter(a=>a[0]==='rpc').length;
  for(const resolve of attentes)resolve({ok:true,montant:10,quantite:1,caisse:50});await p;await second;
  assert.equal(n,1);
 });
 test(`${fn} : changement de personnage pendant la RPC, aucun effet sur le nouveau`,async()=>{
  let resolve;const {c,appels}=plateau(()=>new Promise(r=>resolve=r));
  const p=c[fn](...args);await new Promise(r=>setImmediate(r));c.state.char={name:'Bob'};
  resolve({ok:true,montant:10,salaire:10,quantite:1,paRestants:2,inventory:[]});await p;
  assert.equal(c.state.arg,1000);assert.equal(c.state.pa,8);assert.equal(c.state.inventory[0].name,'Personnel');
  assert.equal(appels.filter(a=>a[0]==='toast'||a[0]==='journal').length,0);
 });
}
test('reconnexion du meme compte pendant un achat : aucun effet de l’ancienne session',async()=>{
 let resolve;const {c,appels}=plateau(()=>new Promise(r=>resolve=r));let jeton='ancien';c.rpAuthJeton=()=>jeton;
 const p=c.commercePjAcheter('ref','achat-test');await new Promise(r=>setImmediate(r));jeton='nouveau';
 resolve({ok:true,montant:10,quantite:1});await p;
 assert.equal(c.state.arg,1000);assert.equal(appels.filter(a=>a[0]==='toast').length,0);
});

test('un client ne peut pas utiliser le chemin historique de production',async()=>{const {c,appels}=plateau();c.commercePjContexte=async()=>({fondsId:'fonds',jeSuisProprietaire:false});await c.commercePjProduire('ref','prod-test-000001','publique');assert.equal(appels.filter(a=>a[0]==='rpc').length,0);assert.equal(c.state.arg,1000);});
