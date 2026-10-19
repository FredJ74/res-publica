// node --test outils/bancs/banc-commerce-etat-client.cjs
// Vraies fonctions UI ; registres et RPC simules, aucune ecriture distante.
const test=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
const path=require('node:path');
const source=fs.readFileSync(path.resolve(__dirname,'../../plateau-commerce-pj.js'),'utf8');
function plateau(verdict={ok:true,montant:100,quantite:1,prixUnitaire:100}) {
 const appels=[],inventory=[{name:'Objet personnel'}];
 const ctx=vm.createContext({console,Number,state:{country:'republic',char:{name:'Alice'},arg:1000,liquide:500,hp:50,moral:40,pa:8,inventory},
  rpAuthUid:()=> 'uid-alice',document:{getElementById:id=>id==='cpj-payeur-collectif'?null:({value:1})},
  commercePjContexte:async()=>({fondsId:'fonds-local'}),
  sbAcheterProduitCommerce:async(...a)=>{appels.push(['achat',...a]);return verdict;},
  sbRpcVerdict:async(...a)=>{appels.push(['rpc',...a]);return verdict;},
  sbGet:async(table,filtre)=>{appels.push(['lecture',table,filtre]);return [{user_id:'uid-alice',arg:700,liquide:200,hp:65,moral:55,pa:7}];},
  showToast:(...a)=>appels.push(['toast',...a]),addJournalEntry:()=>appels.push(['journal']),
  tCommercePJ:k=>k,commercePjMontant:String,commercePjDevise:()=> 'FR',commercePjRefus:()=> 'Refus',
  commercePjEcranBoutique:()=>appels.push(['boutique']),updateUI:()=>appels.push(['ui']),
  verifierObjetsRecus:async()=>{assert.equal(ctx.state.arg,700);appels.push(['livraison']);}});
 const a=source.indexOf('let RP_CPJ_ETAT_VERSION = 0;');
 const b=source.indexOf('// Atelier de decoration',a);
 assert.ok(a>=0&&b>a);vm.runInContext(source.slice(a,b),ctx);
 return {ctx,appels,inventory};
}
for(const action of ['commercePjAcheter','commercePjConsommerSurPlace']){
 test(`${action} : recopie du registre, aucun calcul local ni remplacement d’inventaire`,async()=>{
  const {ctx,appels,inventory}=plateau();await ctx[action]('ref','achat-test');
  assert.equal(ctx.state.arg,700);assert.equal(ctx.state.liquide,200);
  assert.equal(ctx.state.hp,65);assert.equal(ctx.state.moral,55);assert.equal(ctx.state.pa,7);
  assert.equal(ctx.state.char.arg,700);assert.equal(ctx.state.inventory,inventory);
  assert.equal(appels.filter(a=>a[0]==='lecture').length,1);
  assert.ok(appels.find(a=>a[0]==='lecture')[2].includes('country=eq.republic'));
  assert.ok(appels.find(a=>a[0]==='lecture')[2].includes('name=eq.Alice'));
  if(action==='commercePjConsommerSurPlace')assert.equal(appels.filter(a=>a[0]==='livraison').length,0);
 });
 test(`${action} : un rejeu resynchronise sans livrer ni annoncer une seconde transaction`,async()=>{
  const {ctx,appels}=plateau({ok:true,rejeu:true});await ctx[action]('ref','achat-test');
  assert.equal(ctx.state.arg,700);
  assert.equal(appels.filter(a=>['toast','journal','livraison'].includes(a[0])).length,0);
 });
 test(`${action} : refus sans lecture ni effet local`,async()=>{
  const {ctx,appels}=plateau({ok:false,raison:'fonds_insuffisants'});await ctx[action]('ref','achat-test');
  assert.equal(ctx.state.arg,1000);assert.equal(ctx.state.hp,50);
  assert.equal(appels.filter(a=>a[0]==='lecture'||a[0]==='livraison'||a[0]==='journal').length,0);
 });
}
test('panne, fiche etrangere ou ambigue : aucun solde invente',async()=>{
 for(const lecture of [async()=>null,async()=>{throw Error('reseau');},async()=>[{user_id:'autre',arg:0}],async()=>[{},{}]]){
  const {ctx}=plateau();ctx.sbGet=lecture;assert.equal(await ctx.commercePjActualiserPersonnage(),false);assert.equal(ctx.state.arg,1000);
 }
});
test('zero est recopie, null et les nombres invalides ne deviennent pas zero',async()=>{
 const {ctx}=plateau();ctx.sbGet=async()=>[{user_id:'uid-alice',arg:0,liquide:null,hp:NaN,moral:'0',pa:0}];
 assert.equal(await ctx.commercePjActualiserPersonnage(),true);
 assert.equal(ctx.state.arg,0);assert.equal(ctx.state.liquide,500);assert.equal(ctx.state.hp,50);assert.equal(ctx.state.moral,40);assert.equal(ctx.state.pa,0);
});
test('une reponse apres changement de compte ou personnage est ignoree',async()=>{
 for(const changer of [ctx=>ctx.state.char.name='Bob',ctx=>ctx.state.country='narco',ctx=>ctx.rpAuthUid=()=> 'autre']){
  const {ctx}=plateau();let resolve;ctx.sbGet=()=>new Promise(r=>resolve=r);
  const p=ctx.commercePjActualiserPersonnage();changer(ctx);
  resolve([{user_id:'uid-alice',arg:0}]);assert.equal(await p,false);assert.equal(ctx.state.arg,1000);
 }
});
test('sans session, aucune lecture de fiche n’est tentee',async()=>{
 const {ctx,appels}=plateau();ctx.rpAuthUid=()=>null;
 assert.equal(await ctx.commercePjActualiserPersonnage(),false);assert.equal(appels.length,0);
});
test('une ancienne relecture ne remplace pas un solde plus recent',async()=>{
 const {ctx}=plateau();let resolve;
 ctx.sbGet=()=>new Promise(r=>resolve=r);
 const ancien=ctx.commercePjActualiserPersonnage();
 ctx.sbGet=async()=>[{user_id:'uid-alice',arg:600}];
 assert.equal(await ctx.commercePjActualiserPersonnage(),true);
 resolve([{user_id:'uid-alice',arg:700}]);assert.equal(await ancien,false);
 assert.equal(ctx.state.arg,600);
});
