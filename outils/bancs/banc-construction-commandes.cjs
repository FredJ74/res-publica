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

// Charge aussi le vrai lecteur : la réconciliation l'appelle et ne doit pas boucler.
function jeuAvecLecteur(mutant=false){
 const f=jeu(),fs=require('node:fs'),acorn=require('../vercel/node_modules/acorn');
 const s=fs.readFileSync('plateau-justice-economie.js','utf8'),a=s.indexOf('async function chargerTerrainState('),n=acorn.parse(s.slice(a),{ecmaVersion:'latest'}).body[0];
 f.c.getTerrainState=id=>f.c.state.terrainsState?.[id]||{snapshot:'ancien'};
 f.c.sbGetTerrainState=async()=>{f.effets.push('lecture-terrain');return f.c.terrainDistant;};
 f.c.terrainDistant={proprietaire:'Fixture',niveau_construction:'hangar'};
 vm.runInContext(s.slice(a,a+n.end),f.c);
 if(mutant){const n=acorn.parse(source,{ecmaVersion:'latest'}).body.find(n=>n.id?.name==='constructionReconcilierCommandes');vm.runInContext(source.slice(n.start,n.end).replace('        const frais=await chargerTerrainState(buildingId,true,{sansReconciliation:true});\n        if(!contexteNavigationRueValide(c)||!frais)return;\n',''),f.c);}
 const cle=f.c.constructionCleCommande('receptionner');
 f.stockage.set(cle,JSON.stringify({requete:'ch-fixture-reprise135',parametres:{}}));
 f.c.reponse={ok:true,terminee:true,resultat:{etat:{niveau_construction:null,snapshot:'ancien'}}};
 return f;
}
test('reconnexion : reçu confirmé puis terrain courant relu avant abandon de la reprise',async()=>{
 const f=jeuAvecLecteur();await f.c.chargerTerrainState('terrain',true);
 assert.equal(f.appels.length,1);assert.equal(f.appels[0].fn,'chantier_commande_recu');
 assert.deepEqual(f.effets,['lecture-terrain','finance','lecture-terrain']);assert.equal(f.stockage.size,0);
 assert.equal(f.c.getTerrainState('terrain'),f.c.terrainDistant);assert.equal(f.c.state.pa,7);
});
test('reçu acquis mais terrain inaccessible : intention conservée, pas de faux état reconstruit',async()=>{
 const f=jeuAvecLecteur();f.c.terrainDistant=null;
 assert.equal(await f.c.chargerTerrainState('terrain',true),null);assert.equal(f.stockage.size,1);
 assert.equal(f.c.getTerrainState('terrain').snapshot,'ancien');assert(!f.effets.includes('finance'));
});
test('reprise : panne financière après lecture terrain conserve la preuve',async()=>{
 const f=jeuAvecLecteur();f.c.rafraichirRuntimeHelvetia=async()=>null;
 await f.c.constructionReconcilierCommandes('terrain');assert.equal(f.stockage.size,1);
 assert.equal(f.c.getTerrainState('terrain'),f.c.terrainDistant);
});
test('réponse terrain tardive : aucun cache ou PA sur un autre personnage',async()=>{
 const f=jeuAvecLecteur();let finir,signaler;const commence=new Promise(r=>signaler=r);f.c.sbGetTerrainState=()=>new Promise(r=>{finir=r;signaler();});
 const p=f.c.constructionReconcilierCommandes('terrain');await commence;
 f.c.state.char={name:'Autre fixture',pa:19};f.c.state.pa=19;f.c.valide=false;
 finir({niveau_construction:'hangar'});await p;
 assert.equal(f.stockage.size,1);assert.equal(f.c.state.terrainsState,undefined);assert.equal(f.c.state.pa,19);
});
test('contre-épreuve : ancienne réconciliation oublie la preuve malgré la panne de lecture',async()=>{
 const f=jeuAvecLecteur(true);f.c.terrainDistant=null;
 assert.equal(await f.c.chargerTerrainState('terrain',true),null);assert.equal(f.stockage.size,0);
 assert(f.effets.includes('finance'));
});
