// Contrat client uniquement : les reponses RPC sont simulees, pas Supabase.
const test=require('node:test'),assert=require('node:assert/strict'),vm=require('node:vm'),fs=require('node:fs'),path=require('node:path');
const acorn=require('../vercel/node_modules/acorn'),root=path.resolve(__dirname,'../..');
function fonctions(f,noms){const rue=f==='plateau-rue-centrale.js'&&noms.some(n=>['initialiserRueCentrale','afficherNoeudRue'].includes(n));if(rue)noms=[...noms,'contexteNavigationRue','contexteNavigationRueValide'];const s=fs.readFileSync(path.join(root,f),'utf8');return (rue?'let rueCentraleLecturePosition=0,rueCentraleDeplacementEnCours=null;':'')+acorn.parse(s,{ecmaVersion:'latest'}).body.filter(n=>n.type==='FunctionDeclaration'&&noms.includes(n.id.name)).map(n=>s.slice(n.start,n.end)).join('\n');}
function contexte(){
 const elements=new Map();for(const id of ['modal-postes','postes-modal-title','postes-body'])elements.set(id,{innerHTML:'',classList:{add(){},remove(){}}});
 const c=vm.createContext({state:{char:{name:'Alice'},country:'republic',currentCity:'capitale',currentBuilding:'mairie',currentRoom:'accueil',pa:12},console,
 document:{getElementById:id=>elements.get(id)},showToast(){},addJournalEntry(){},addExternalEvent(){},updateUI(){},RUE_CENTRALE_NOEUDS:{republic:{destination:{}}},
 teleporterVersCellule:d=>{c.transfert=d;},afficherNoeudRue:async(...args)=>{c.navigation=args;}});
 vm.runInContext('let interceptionJudiciaire=null,interceptionJudiciaireOccupee=false;'+fonctions('plateau-justice-economie.js',[
 'contexteInterceptionJudiciaire','contexteInterceptionJudiciaireValide','interceptionJudiciaireBloqueDeplacement','marquerInterceptionIncertaine',
 'afficherInterceptionJudiciaire','reprendreInterceptionJudiciaireServeur','recupererVerdictInterception','ordreInterceptionAvecReprise','conclureArrestationJudiciaire','choisirInterceptionJudiciaire','verifierArrestationRecherchePolice',
 'verifierSurveillancePolicePJUnique','calculerPerGroupePolice','calculerVolGroupePolice']),c);
 vm.runInContext(`interceptionJudiciaire={rencontreId:'police-rencontre',ville:'capitale',eligible:{},policiers:[{},{}],zone:{batiment:'mairie',piece:'accueil'}};`,c);
 c.dossier=()=>vm.runInContext('interceptionJudiciaire',c);c.html=()=>elements.get('postes-body').innerHTML;return c;
}
for(const action of ['rendre','fuir','combattre'])test(`${action} : double clic, perte de reponse et appel direct ne rejouent jamais l'acte`,async()=>{
 const c=contexte();let n=0,resolve;c.sbRpc=()=>{n++;return n===1?new Promise(r=>resolve=r):Promise.resolve({ok:true,trouve:false});};const a=c.choisirInterceptionJudiciaire(action);await c.choisirInterceptionJudiciaire(action);assert.equal(n,1);assert.match(c.html(),/disabled/);resolve(null);await a;
 assert.equal(c.dossier().reponseIncertaine,true);assert.doesNotMatch(c.html(),/onclick=/);await c.conclureArrestationJudiciaire();await c.choisirInterceptionJudiciaire(action);assert.equal(n,2);assert.equal(c.transfert,undefined);
});
for(const action of ['rendre','fuir','combattre'])test(`${action} : relecture du reçu après perte de réponse sans rejouer l'action`,async()=>{
 const c=contexte();const appels=[];
 c.sbRpc=async(nom,parametres)=>{
  appels.push([nom,parametres]);
  if(nom==='police_action_resultat_lire')return {ok:true,trouve:true,verdict:action==='rendre'?{ok:true,detention_id:'d',jours:2}:action==='fuir'?{ok:true,reussite:true,destination:'destination'}:{ok:true,pa:10,policiers_restants:1,arrestation:false,police_neutralisee:false}};
  throw Error('connexion perdue');
 };
 await c.choisirInterceptionJudiciaire(action);
 assert.equal(appels.length,2);assert.equal(appels[1][0],'police_action_resultat_lire');
 assert.equal(appels[1][1].p_action,action==='rendre'?'reddition':action==='fuir'?'fuite':'combat');
 if(action==='rendre')assert.equal(c.transfert.detentionId,'d');
 if(action==='fuir')assert.equal(c.navigation[1],'destination');
 if(action==='combattre')assert.equal(c.state.pa,10);
});
test('reconnexion : rencontre active restauree en lecture seule sans nouvelle detection',async()=>{
 const c=contexte();vm.runInContext('interceptionJudiciaire=null',c);const appels=[];
 c.sbRpc=async(nom)=>{appels.push(nom);return {ok:true,active:true,rencontre:'police-rencontre',country:'republic',city:'capitale',building:'mairie',room:'accueil',street:null,dernier_round:2,dernier_verdict:{ok:true,policiers_restants:1},fuite_tentee:true};};
 assert.equal(await c.reprendreInterceptionJudiciaireServeur(),true);
 assert.deepEqual(appels,['police_reprise_lire']);assert.equal(c.dossier().round,3);
 assert.equal(c.dossier().fuiteEchouee,true);assert.equal(c.interceptionJudiciaireBloqueDeplacement(),true);
});
test('reconnexion : aucun dossier si verdict terminal ou rencontre inactive',async()=>{
 for(const reponse of [{ok:true,active:false},{ok:true,active:true,rencontre:'police-rencontre',country:'republic',city:'capitale',building:'mairie',room:'accueil',dernier_verdict:{arrestation:true}}]){
  const c=contexte();vm.runInContext('interceptionJudiciaire=null',c);c.sbRpc=async()=>reponse;
  assert.equal(await c.reprendreInterceptionJudiciaireServeur(),false);assert.equal(c.dossier(),null);
 }
});
test('reddition : detention confirmee avant transfert',async()=>{const c=contexte();c.sbRpc=async()=>({ok:true,detention_id:'d',jours:2});await c.choisirInterceptionJudiciaire('rendre');assert.equal(c.transfert.detentionId,'d');assert.equal(c.dossier(),null);});
test('reddition incomplete ne libere pas la navigation',async()=>{const c=contexte();c.sbRpc=async()=>({ok:true});await c.choisirInterceptionJudiciaire('rendre');assert.equal(c.dossier().reponseIncertaine,true);assert.equal(c.transfert,undefined);});
for(const action of ['rendre','fuir','combattre'])test(`${action} : retour d'un ancien personnage ignore`,async()=>{const c=contexte();let resolve;c.sbRpc=()=>new Promise(r=>resolve=r);const p=c.choisirInterceptionJudiciaire(action);c.state.char={name:'Bob'};resolve({ok:true,detention_id:'d',jours:2,reussite:true,destination:'destination',pa:0,policiers_restants:0,arrestation:true});await p;assert.equal(c.state.pa,12);assert.equal(c.transfert,undefined);assert.equal(c.navigation,undefined);});
test('fuite reussie : rendu confirme sans rejouer un deplacement serveur',async()=>{const c=contexte();c.sbRpc=async()=>({ok:true,reussite:true,destination:'destination'});await c.choisirInterceptionJudiciaire('fuir');assert.equal(c.navigation[3],true);assert.equal(c.state.currentBuilding,null);assert.equal(c.dossier(),null);});
test('fuite echouee : choix restant sans nouveau jet',async()=>{const c=contexte();let n=0;c.sbRpc=async()=>{n++;return {ok:true,reussite:false};};await c.choisirInterceptionJudiciaire('fuir');await c.choisirInterceptionJudiciaire('fuir');assert.equal(n,1);assert.equal(c.dossier().fuiteEchouee,true);});
test('fuite confirmee sans destination exploitable : blocage conserve',async()=>{const c=contexte();c.sbRpc=async()=>({ok:true,reussite:true,destination:'inconnue'});await c.choisirInterceptionJudiciaire('fuir');assert.equal(c.dossier().reponseIncertaine,true);assert.equal(c.interceptionJudiciaireBloqueDeplacement(),true);});
test('round suivant seulement apres verdict complet, PA et effectifs viennent du serveur',async()=>{const c=contexte();const rounds=[];c.sbRpc=async(f,a)=>{rounds.push(a.p_round);return {ok:true,pa:7,policiers_restants:1};};await c.choisirInterceptionJudiciaire('combattre');await c.choisirInterceptionJudiciaire('combattre');assert.deepEqual(rounds,[1,2]);assert.equal(c.state.pa,7);assert.equal(c.dossier().policiers.length,1);});
test('neutralisation : cloture sans inventer de detention',async()=>{const c=contexte();c.sbRpc=async()=>({ok:true,pa:4,policiers_restants:0,police_neutralisee:true});await c.choisirInterceptionJudiciaire('combattre');assert.equal(c.dossier(),null);assert.equal(c.transfert,undefined);});
test('arrestation et neutralisation simultanees : detention serveur prioritaire',async()=>{const c=contexte();c.sbRpc=async()=>({ok:true,pa:0,policiers_restants:0,police_neutralisee:true,arrestation:true,detention_id:'d',jours:3});await c.choisirInterceptionJudiciaire('combattre');assert.equal(c.transfert.detentionId,'d');assert.equal(c.dossier(),null);});
test('combat sans PA valides ou sans detention confirmee : pas de faux succes',async()=>{for(const verdict of [{ok:true,policiers_restants:0},{ok:true,pa:0,policiers_restants:1,arrestation:true}]){const c=contexte();c.sbRpc=async()=>verdict;await c.choisirInterceptionJudiciaire('combattre');assert.equal(c.dossier().reponseIncertaine,true);assert.equal(c.transfert,undefined);}});
for(const [f,nom,args] of [['plateau-navigation.js','enterBuilding',['mairie']],['plateau-navigation.js','enterRoom',['mairie','accueil']],['plateau-navigation.js','sortirBatiment',[]],['plateau-rue-centrale.js','afficherNoeudRue',['republic','destination']]])test(`interception active : ${nom} bloque avant toute ecriture`,async()=>{const c=contexte();vm.runInContext(fonctions(f,[nom]),c);await c[nom](...args);assert.equal(c.state.currentBuilding,'mairie');assert.equal(c.navigation,undefined);});
test('la garde est levee seulement apres cloture',()=>{const c=contexte();assert.equal(c.interceptionJudiciaireBloqueDeplacement(),true);vm.runInContext('interceptionJudiciaire=null',c);assert.equal(c.interceptionJudiciaireBloqueDeplacement(),false);});
test('aucune interception judiciaire sans detection serveur',async()=>{const c=contexte();let n=0;c.sbRpc=async()=>{n++;};assert.equal(await c.verifierArrestationRecherchePolice(),false);assert.equal(n,0);});
for(const cas of ['non_recherche','non_detecte','detecte','absent','sans_pa'])test(`detection : ${cas}`,async()=>{
 const c=contexte();vm.runInContext('interceptionJudiciaire=null',c);const appels=[];
 c.chargerEffectifsPolice=async()=>({policiers:cas==='absent'?[]:[{buildingId:'mairie',roomId:'accueil',pa:cas==='sans_pa'?0:12}]});
 c.calculerPerGroupePolice=()=>12;c.calculerVolGroupePolice=()=>12;c.calculerDisEffective=()=>8;c.calculerChancePJ=()=>90;c.resoudreControlePoliceAutomatique=()=>{};
 c.sbRpc=async(f)=>{appels.push(f);if(f==='justice_recherches')return [{id:'j',country:'republic',data:{motifs:[]}}];return cas==='non_recherche'?{ok:false,raison:'non_recherche'}:{ok:true,detecte:cas==='detecte',rencontre:'police-rencontre'};};
 await c.verifierSurveillancePolicePJUnique('mairie','accueil');assert.equal(!!c.dossier(),cas==='detecte');
 if(cas==='absent'||cas==='sans_pa')assert.deepEqual(appels,['police_reprise_lire']);
 if(cas==='detecte')assert.deepEqual(appels,['police_reprise_lire','police_detection_verifier','justice_recherches']);
});
test('restauration de rue : lecture de position seule, aucun ordre de mouvement',async()=>{
 const c=contexte();let appels=[];c.sbRpc=async(f)=>{appels.push(f);return {ok:true,country:'republic',city:'capitale',street:'destination',building:null};};
 vm.runInContext(fonctions('plateau-rue-centrale.js',['initialiserRueCentrale']),c);
 await c.initialiserRueCentrale('republic','destination',null);assert.deepEqual(appels,['rue_position_lire']);assert.equal(c.navigation[3],true);
});
test('un dossier appartient a sa connexion, pas au personnage suivant',()=>{const c=contexte();vm.runInContext('interceptionJudiciaire.contexte=contexteInterceptionJudiciaire()',c);c.state.char={name:'Bob'};assert.equal(c.interceptionJudiciaireBloqueDeplacement(),false);assert.equal(c.dossier(),null);});
