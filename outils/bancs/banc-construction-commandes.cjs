const {test}=require('node:test'),assert=require('node:assert/strict'),vm=require('node:vm');
const source=require('node:fs').readFileSync('plateau-construction-commandes.js','utf8');
function jeu(){
 const stockage=new Map(),appels=[],effets=[];
 const c={state:{char:{name:'Fixture'},country:'republic',currentCity:'capitale',currentBuilding:'terrain'},
  contexteNavigationRue:()=>({uid:'fixture',nom:'Fixture'}),contexteNavigationRueValide:()=>c.valide,
  valide:true,crypto:require('node:crypto'),sessionStorage:{getItem:k=>stockage.get(k)||null,setItem:(k,v)=>stockage.set(k,v),removeItem:k=>stockage.delete(k)},
  showToast:()=>{},updateUI:()=>{},chargerTerrainState:async()=>{effets.push('terrain');return {frais:true};},
  rafraichirRuntimeHelvetia:async()=>{effets.push('finance');return {pa:7};},
  sbRpcVerdict:async(fn,p)=>{appels.push({fn,p});return c.reponse;},reponse:{ok:true},
 };
 vm.createContext(c);vm.runInContext(source,c);return{c,stockage,appels,effets};
}
test('commande versionnee et relectures : aucun ancien snapshot adopte',async()=>{
 const f=jeu();const r=await f.c.constructionExecuterCommande('lancer',{apport:'10500'});
 assert.equal(r.ok,true);assert.equal(f.appels[0].fn,'chantier_commande');
 assert.deepEqual(f.effets,['terrain','finance']);assert.equal(f.c.state.pa,7);assert.equal(f.stockage.size,0);
});
test('reponse perdue : reprendre le meme identifiant sans changer les parametres',async()=>{
 const f=jeu();f.c.reponse={ok:false,transport:{etat:'indetermine'}};
 await f.c.constructionExecuterCommande('verser',{montant:'100'});const id=f.appels[0].p.p_requete;
 await f.c.constructionExecuterCommande('verser',{montant:'200'});assert.equal(f.appels.length,1);
 f.c.reponse={ok:true,rejeu:true};await f.c.constructionExecuterCommande('verser',{montant:'100'});
 assert.equal(f.appels[1].p.p_requete,id);assert.equal(f.stockage.size,0);
});
test('double clic : une seule execution en vol',async()=>{
 const f=jeu();let finir;f.c.sbRpcVerdict=async(fn,p)=>{f.appels.push(p);return new Promise(r=>finir=r);};
 const a=f.c.constructionExecuterCommande('receptionner');await f.c.constructionExecuterCommande('receptionner');
 assert.equal(f.appels.length,1);finir({ok:true});await a;
});
test('contexte perime : aucune relecture ni actualisation du nouveau personnage',async()=>{
 const f=jeu();let finir;f.c.sbRpcVerdict=()=>new Promise(r=>finir=r);
 const a=f.c.constructionExecuterCommande('travailler',{heures:1});f.c.valide=false;finir({ok:true});await a;
 assert.equal(f.effets.length,0);assert.equal(f.stockage.size,1);
});
test('relecture financiere impossible : preuve de reprise conservee',async()=>{
 const f=jeu();f.c.rafraichirRuntimeHelvetia=async()=>null;
 assert.equal(await f.c.constructionExecuterCommande('verser',{montant:'100'}),null);assert.equal(f.stockage.size,1);
});
