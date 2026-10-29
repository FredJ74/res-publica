// Corps réels du client ; réponses simulées, pas une preuve Supabase.
const test=require('node:test'),assert=require('node:assert/strict'),vm=require('node:vm'),fs=require('node:fs'),path=require('node:path'),acorn=require('../vercel/node_modules/acorn');
const root=path.resolve(__dirname,'../..');
function fonctions(f,noms){const s=fs.readFileSync(path.join(root,f),'utf8');return acorn.parse(s,{ecmaVersion:'latest'}).body.filter(x=>x.type==='FunctionDeclaration'&&noms.includes(x.id.name)).map(x=>s.slice(x.start,x.end)).join('\n');}
function jeu(){
 const c=vm.createContext({state:{char:{name:'A'},pa:99,country:'republic',currentCity:'capitale',currentBuilding:'mairie',currentRoom:'accueil'},crypto:{randomUUID:()=> 'r1'},session:'s',storage:new Map(),rpc:[],lus:0,messages:[]});
 c.rpAuthUid=()=> 'uid';c.rpAuthSessionIdentifiant=()=>c.session;
 c.localStorage={getItem:k=>c.storage.get(k),setItem:(k,v)=>c.storage.set(k,v),removeItem:k=>c.storage.delete(k)};
 c.sbMilitaireBatailleEtat=async()=>{c.lus++;return {ok:true,bataille:{round_courant:3}};};
 c.sbRpcVerdict=async(fn,p)=>{c.rpc.push([fn,p]);return {ok:true,round:4};};
 vm.runInContext(fonctions('plateau-multijoueur.js',['contexteGroupePj','contexteGroupePjValide'])+'\nlet SB_BATAILLE_COMMANDE_EN_COURS=null;\n'+fonctions('supabase.js',['sbMilitaireCommande','sbMilitaireBatailleEngager','sbMilitaireBataillePoursuivre','sbMilitaireBatailleDecider'])+'\n'+fonctions('plateau-politique.js',['rafraichirApresRound','poursuivreCombat','messageRefusCombat']),c);
 c.showToast=(...v)=>c.messages.push(v);c.updateUI=()=>{};c.ouvrirPanneauCombat=async()=>{};
 c.sbLoadPersonnage=async()=>({userId:'uid',pa:7,country:'republic',currentCity:'capitale',currentBuilding:'mairie',currentRoom:'accueil',group:null});
 c.sbInventaireReceptionEtat=async()=>null;
 return c;
}
test('round attendu lu avant commande et reçu durable avant envoi',async()=>{const c=jeu();const v=await c.sbMilitaireBataillePoursuivre(71);assert.equal(v.round,4);assert.equal(c.rpc[0][1].p_round_attendu,3);assert.equal(c.rpc[0][1].p_requete,'r1');assert.equal(c.storage.size,0);});
test('réponse perdue : conserve aussi ancien round, ne relit pas un round neuf',async()=>{const c=jeu();c.sbRpcVerdict=async(fn,p)=>{c.rpc.push([fn,p]);return null;};await c.sbMilitaireBataillePoursuivre(71);await c.sbMilitaireBataillePoursuivre(71);assert.equal(c.lus,1);assert.deepEqual(c.rpc[0][1],c.rpc[1][1]);assert.equal(c.storage.size,1);});
test('round obsolète refusé : le prochain ordre peut obtenir un nouveau reçu',async()=>{const c=jeu();c.sbRpcVerdict=async()=>({ok:false,raison:'round_obsolete'});await c.sbMilitaireBataillePoursuivre(71);assert.equal(c.storage.size,0);});
test('double clic pendant la lecture : une seule commande',async()=>{const c=jeu();let finir;c.sbMilitaireBatailleEtat=()=>new Promise(r=>finir=r);const p=c.sbMilitaireBataillePoursuivre(71);assert.equal((await c.sbMilitaireBataillePoursuivre(71)).raison,'commande_en_cours');finir({ok:true,bataille:{round_courant:0}});await p;assert.equal(c.rpc.length,1);});
test('session changée pendant la lecture : aucun coup envoyé',async()=>{const c=jeu();c.sbMilitaireBatailleEtat=async()=>{c.session='autre';return {ok:true,bataille:{round_courant:0}};};assert.equal(await c.sbMilitaireBataillePoursuivre(71),null);assert.equal(c.rpc.length,0);});
test('réponse tardive pour ancien personnage : ignorée et reçu conservé',async()=>{const c=jeu();c.sbRpcVerdict=async()=>{c.state.char={name:'B'};return {ok:true};};assert.equal(await c.sbMilitaireBataillePoursuivre(71),null);assert.equal(c.storage.size,1);});
test('engagement : reçu même sans bataille existante',async()=>{const c=jeu();await c.sbMilitaireBatailleEngager();assert.equal(c.lus,0);assert.equal(c.rpc[0][0],'militaire_bataille_engager');assert.equal(c.rpc[0][1].p_requete,'r1');});
test('décision : même porte avec round et reçu',async()=>{const c=jeu();await c.sbMilitaireBatailleDecider(71,'replier');assert.equal(c.rpc[0][0],'militaire_bataille_decider');assert.equal(c.rpc[0][1].p_decision,'replier');});
test('stockage impossible : aucun ordre envoyé',async()=>{const c=jeu();c.localStorage.setItem=()=>{throw Error('quota');};assert.equal((await c.sbMilitaireBataillePoursuivre(71)).raison,'recu_non_conserve');assert.equal(c.rpc.length,0);});
test('après round : PA réels et réponse inventaire exacte, aucun objet recomposé',async()=>{const c=jeu();const v={ok:true,inventory:[],revision:4};c.sbInventaireReceptionEtat=async()=>v;let adopte;c.sbAdopterInventaireServeur=x=>adopte=x;assert.equal(await c.rafraichirApresRound(71),true);assert.equal(c.state.pa,7);assert.equal(adopte,v);});
test('rafraîchissement tardif : ne touche pas le nouveau personnage',async()=>{const c=jeu();c.sbLoadPersonnage=async()=>{c.state.char={name:'B'};return {userId:'uid',pa:1};};assert.equal(await c.rafraichirApresRound(71),false);assert.equal(c.state.pa,99);});
test('position relue après évacuation : même rendu confirmé, pas de nouvelle commande',async()=>{const c=jeu();const frais={userId:'uid',pa:0,country:'republic',currentCity:'caserne',currentBuilding:'caserne-militaire',currentRoom:'infirmerie'};c.sbLoadPersonnage=async()=>frais;let rendu;c.afficherPositionNavigationConfirmee=v=>rendu=v;assert.equal(await c.rafraichirApresRound(71),true);assert.equal(rendu,frais);assert.equal(c.rpc.length,0);});

test('réponse incertaine : le texte ne prétend pas que le round a échoué',async()=>{const c=jeu();c.sbMilitaireBataillePoursuivre=async()=>({ok:false,raison:'reponse_incertaine'});await c.poursuivreCombat(71);assert.match(c.messages[0][1],/réponse a été perdue/);assert.match(c.messages[0][1],/même reçu/);});
