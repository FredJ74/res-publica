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
 vm.runInContext(fonctions('plateau-multijoueur.js',['contexteGroupePj','contexteGroupePjValide'])+'\nlet SB_BATAILLE_COMMANDE_EN_COURS=null;\n'+fonctions('supabase.js',['sbCombatOuvrir','sbMilitaireCommande','sbMilitaireBatailleEngager','sbMilitaireBataillePoursuivre','sbMilitaireBatailleDecider'])+'\n'+fonctions('plateau-politique.js',['rafraichirApresRound','poursuivreCombat','messageRefusCombat']),c);
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

test('repli de rue à rue : relit et rend la rue même si ville et bâtiment ne changent pas',async()=>{const c=jeu();c.state.currentBuilding=null;c.state.currentRoom=null;const frais={userId:'uid',pa:7,country:'republic',currentCity:'capitale',currentBuilding:null,currentRoom:null};c.sbLoadPersonnage=async()=>frais;let rendu;c.afficherPositionNavigationConfirmee=v=>rendu=v;assert.equal(await c.rafraichirApresRound(71),true);assert.equal(rendu,frais);assert.equal(c.rpc.length,0);});
test('rendu confirmé extérieur : utilise la rue existante, jamais enterBuilding(null)',()=>{const c=vm.createContext({state:{char:{}},rues:0,batiments:0,applyEmpireTheme:()=>{},buildCityTabs:()=>{},showVueRue:()=>c.rues++,enterBuilding:()=>c.batiments++,enterRoom:()=>c.batiments++});vm.runInContext('let navigationInterieureRendu=null;'+fonctions('plateau-navigation.js',['afficherPositionNavigationConfirmee']),c);c.afficherPositionNavigationConfirmee({country:'republic',currentCity:'capitale',currentBuilding:null,currentRoom:null});assert.equal(c.rues,1);assert.equal(c.batiments,0);});

test('ouverture civile : reçu conservé après perte de réponse, aucun round lu',async()=>{const c=jeu();c.sbRpcVerdict=async(fn,p)=>{c.rpc.push([fn,p]);return null;};await c.sbCombatOuvrir('C','mains');await c.sbCombatOuvrir('C','mains');assert.equal(c.lus,0);assert.equal(c.rpc[0][0],'combat_ouvrir');assert.deepEqual(c.rpc[0][1],c.rpc[1][1]);assert.equal(c.rpc[0][1].p_cible,'C');assert.equal(c.rpc[0][1].p_mode,'mains');assert.equal(c.storage.size,1);});
test('reddition : décision explicite transmise, même contrat de reçu',async()=>{const c=jeu();await c.sbMilitaireBatailleDecider(71,'rendre');assert.equal(c.rpc[0][1].p_decision,'rendre');assert.equal(c.rpc[0][1].p_round_attendu,3);});

for(const [titre,cible,attendu] of [
 ['PJ identifié par nom serveur',{isPJ:true,id:'uid-ne-pas-envoyer',name:'C'},'C'],
 ['squatteurs par occupation courante',{id:'squatter_cool',name:'squatteurs'},'mairie'],
 ['PNJ par identité canonique',{id:'presentation',socleId:'pnj-canonique'},'pnj-canonique'],
 ['PNJ présenté par nom officiel',{id:'ancien-id-ecran',name:'Un (PNJ)'},'Un']
])test('ouverture depuis fiche : '+titre,async()=>{
 const c=jeu();c.document={getElementById:()=>({classList:{remove(){}}})};c.NEUTRALISER_MODES={mains:{}};
 c.neutraliserPossedeArme=()=>true;c.neutraliserCibleEstDepute=()=>null;c.neutraliserTaux=()=>0;
 vm.runInContext(fonctions('plateau-actions-illegales-rumeurs.js',['confirmerAssassinatArme']),c);
 await c.confirmerAssassinatArme(encodeURIComponent(JSON.stringify(cible)),'mains');
 assert.equal(c.rpc[0][0],'combat_ouvrir');assert.equal(c.rpc[0][1].p_cible,attendu);assert.equal(c.state.pa,99);
});

test('après combat : occupation exacte relue sans génération ni ordre immobilier',async()=>{
 const c=jeu();c.state.currentBuilding='terrain-a-batir-1';c.state.currentRoom='terrain';
 const occupation={pnj:'cadavre',pnjSocleId:'occupation-canonique'};let adopte;
 c.sbGetTerrainState=async()=>occupation;c.remplacerTerrainState=(id,v)=>adopte=[id,v];c.chargerPnjTerrain=()=>{throw Error('visite interdite');};
 c.sbLoadPersonnage=async()=>({userId:'uid',pa:7,hp:0,country:'republic',currentCity:'capitale',currentBuilding:'terrain-a-batir-1',currentRoom:'terrain'});
 assert.equal(await c.rafraichirApresRound(71),true);assert.equal(adopte[0],'terrain-a-batir-1');assert.equal(adopte[1],occupation);assert.equal(c.state.hp,0);assert.equal(c.rpc.length,0);
});
test('occupation tardive : jamais appliquée à un autre personnage',async()=>{
 const c=jeu();c.state.currentBuilding='terrain-a-batir-1';let adoptes=0;
 c.sbGetTerrainState=async()=>{c.state.char={name:'B'};return {pnj:'cadavre'};};c.remplacerTerrainState=()=>adoptes++;
 assert.equal(await c.rafraichirApresRound(71),false);assert.equal(adoptes,0);assert.equal(c.state.pa,99);
});

test('interaction après attaque : même panneau confirmé, aucun ordre automatique',async()=>{
 const c=jeu();let ouvre;c.sbMilitaireBatailleEtat=async()=>({ok:true,bataille:{id:83,statut:'en_cours'}});c.ouvrirPanneauCombat=async id=>ouvre=id;
 vm.runInContext(fonctions('plateau-politique.js',['reprendreCombatConfirme']),c);
 assert.equal(await c.reprendreCombatConfirme(),true);assert.equal(ouvre,83);assert.equal(c.rpc.length,0);assert.equal(c.state.pa,99);
});
test('reprise tardive après changement de session : aucun panneau étranger',async()=>{
 const c=jeu();let ouvre=0;c.sbMilitaireBatailleEtat=async()=>{c.session='nouvelle';return {ok:true,bataille:{id:83,statut:'en_cours'}};};c.ouvrirPanneauCombat=async()=>ouvre++;
 vm.runInContext(fonctions('plateau-politique.js',['reprendreCombatConfirme']),c);
 assert.equal(await c.reprendreCombatConfirme(),false);assert.equal(ouvre,0);
});

test('journal : historique commun et accès aux vrais rounds sans ordre de combat',async()=>{
 const c=jeu(),elements=new Map();c.document={getElementById:id=>{if(!elements.has(id))elements.set(id,{textContent:'',innerHTML:'',classList:{add(){}}});return elements.get(id);}};
 c.escapeHtmlText=x=>String(x);c.LIBELLES_GRADES_MILITAIRES={};c.LIBELLES_DOMAINES_MILITAIRES={};c.LIBELLES_NIVEAUX_DECORATION={};
 c.sbMilitaireCalepin=async()=>({ok:true,nom:'A'});c.sbMilitaireMesBatailles=async()=>({ok:true,batailles:[{id:83,statut:'terminee',lieu:{ville:'capitale'},rounds:[{mes_pa_perdus:2}]}]});
 vm.runInContext(fonctions('plateau-politique.js',['ouvrirCalepinCampagne']),c);await c.ouvrirCalepinCampagne();
 assert.match(elements.get('postes-body').innerHTML,/ouvrirPanneauCombat\(83\)/);assert.match(elements.get('postes-body').innerHTML,/Lire les rounds/);assert.equal(c.rpc.length,0);
 assert.match(fs.readFileSync(path.join(root,'plateau.html'),'utf8'),/onclick="ouvrirCalepinCampagne\(\)"[^>]*>Rapports de combat/);
});
