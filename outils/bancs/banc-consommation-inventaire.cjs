// node --test outils/bancs/banc-consommation-inventaire.cjs
// Le vrai handler et la vraie sortie d'inventaire ; seule la RPC est simulee.
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');
const root=path.resolve(__dirname,'../..');
function bloc(fichier,debut,fin){
 const s=fs.readFileSync(path.join(root,fichier),'utf8');const a=s.indexOf(debut),b=s.indexOf(fin,a);
 assert.ok(a>=0&&b>a);return s.slice(a,b);
}
function plateau(rpc){
 const appels=[];const inventory=[{name:'Pain',familleProduitMarche:'aliment',qty:1}];
 const ctx=vm.createContext({console,state:{char:{name:'Temoin'},inventory,pa:3},
  sbInventaireConsommer:async(...a)=>{appels.push(['rpc',...a]);return rpc(...a);},
  document:{getElementById:()=>({classList:{remove(){}}})},
  showToast:(...a)=>appels.push(['toast',...a]),addJournalEntry:(...a)=>appels.push(['journal',...a]),
  renderInventory:()=>appels.push(['inventaire']),updateUI:()=>appels.push(['ui']),
  switchSelfTab:()=>appels.push(['onglet']),messageRefusSortieInventaire:String});
 vm.runInContext(bloc('plateau-divers.js','const MOTIFS_SORTIE_INVENTAIRE =','// Message unique des refus de sortie'),ctx);
 vm.runInContext(bloc('plateau-personnage.js','let consommationAlimentEnCours =','// ====================='),ctx);
 return {ctx,appels,inventory};
}
test('double clic : un seul retrait en vol, effet PA lu dans le verdict',async()=>{
 let resolve;const {ctx,appels}=plateau(()=>new Promise(r=>resolve=r));
 const premier=ctx.consommerAliment(0);await ctx.consommerAliment(0);
 assert.equal(appels.filter(a=>a[0]==='rpc').length,1);
 assert.equal(ctx.state.pa,3);
 resolve({ok:true,inventory:[],pa:4,aliment_frais:true});await premier;
 assert.equal(ctx.state.inventory.length,0);assert.equal(ctx.state.pa,4);
 assert.equal(appels.filter(a=>a[0]==='journal').length,1);
 assert.ok(appels.some(a=>a[0]==='onglet'));
});
test('refus et panne : inventaire et PA conserves, aucun succes ni sauvegarde',async()=>{
 for(const rpc of [async()=>null,async()=>({ok:false,raison:'objet_absent'}),async()=>{throw Error('reseau');}]){
  const {ctx,appels,inventory}=plateau(rpc);await ctx.consommerAliment(0);
  assert.equal(ctx.state.inventory,inventory);assert.equal(ctx.state.pa,3);
  assert.equal(appels.filter(a=>a[0]==='journal').length,0);
  assert.ok(appels.some(a=>a[0]==='toast'&&a[1]==='Consommation impossible'));
 }
});
test('peremption confirmee au serveur : aucun calcul depuis la date locale',async()=>{
 const {ctx,appels}=plateau(async()=>({ok:true,inventory:[],pa:2,aliment_frais:false}));
 await ctx.consommerAliment(0);assert.equal(ctx.state.pa,2);
 assert.ok(appels.some(a=>a[0]==='toast'&&a[1]==='Intoxication alimentaire'));
});
test('verdict ancien : aucune intoxication ni PA invente',async()=>{
 const {ctx,appels}=plateau(async()=>({ok:true,inventory:[]}));
 await ctx.consommerAliment(0);assert.equal(ctx.state.pa,3);
 assert.ok(appels.some(a=>a[0]==='toast'&&a[1]==='Aliment consommé'));
 assert.ok(!appels.some(a=>a[1]==='Intoxication alimentaire'));
});
test('objet absent ou non alimentaire : aucune RPC',async()=>{
 const {ctx,appels}=plateau(()=>assert.fail('Aucun appel attendu'));
 await ctx.consommerAliment(5);ctx.state.inventory=[{name:'Document'}];await ctx.consommerAliment(0);
 assert.equal(appels.length,0);
});
test('un refus libere le verrou pour une nouvelle tentative autorisee',async()=>{
 let n=0;const {ctx,appels}=plateau(async()=>++n===1?null:{ok:true,inventory:[],pa:4,aliment_frais:true});
 await ctx.consommerAliment(0);await ctx.consommerAliment(0);
 assert.equal(appels.filter(a=>a[0]==='rpc').length,2);assert.equal(ctx.state.pa,4);
});
