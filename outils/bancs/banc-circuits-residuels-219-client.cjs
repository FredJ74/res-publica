// Banc client des circuits résiduels de déplacement #219 (Claude, 01/11/2026).
// Vraies fonctions du dépôt (extraites par acorn), transports simulés, aucune preuve distante.
// Contre-épreuve : CONTRE=<ref git> exécute les mêmes attentes sur les fichiers de cette référence.
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),{execFileSync}=require('node:child_process');
let acorn;try{acorn=require('../vercel/node_modules/acorn');}catch(_){acorn=require('acorn');}
const root=path.resolve(__dirname,'../..');
const lire=f=>process.env.CONTRE?execFileSync('git',['show',process.env.CONTRE+':'+f],{cwd:root,encoding:'utf8',maxBuffer:64<<20}):fs.readFileSync(path.join(root,f),'utf8');
function fonctions(file,names){const s=lire(file);const t=acorn.parse(s,{ecmaVersion:'latest'}).body;const out=[];
 for(const n of t){if(n.type==='FunctionDeclaration'&&names.includes(n.id.name))out.push(s.slice(n.start,n.end));
  if(n.type==='VariableDeclaration'&&n.declarations.some(d=>names.includes(d.id.name)))out.push(s.slice(n.start,n.end).replace(/^const /,'var '));}
 return out.join('\n');}
const NAV=['representerPositionServeur','adopterPositionServeurRelue','enterBuilding','enterRoom'];
function jeu(opts={}){
 const journal=[];const c={console,journal,toasts:[],JSON,Promise,Array,Object,
  state:{char:{name:'A'},country:'republic',currentCity:'capitale',currentBuilding:'caserne-militaire',currentRoom:'corps_garde',_navigationServeur:true},
  navigationInterieureRendu:null,BUILDINGS:{},WORLD:{},
  document:{getElementById:()=>({classList:{add(){},remove(){}},style:{},innerHTML:''})},
  setTimeout:f=>f(),showToast:(...a)=>c.toasts.push(a),addJournalEntry(){},addMailNotification(){},updateUI(){},buildCityTabs(){},
  hideBuildingTooltip(){},interceptionJudiciaireBloqueDeplacement:()=>false,
  commanderNavigationInterieure:(b,r)=>{journal.push(['commande',b,r]);return false;},
  contexteNavigationRue:()=>({nom:c.state.char?.name,uid:'u1',personnage:c.state.char}),contexteNavigationRueValide:()=>true,
  rpAuthUid:()=>'u1',window:{},getBuildingContext:()=>null,checkZoneEmbarquementAcces:()=>true,retirerRecherche:async()=>{},
  joursEcoulesHospitalisation:()=>2,batimentHospitalisation:()=> 'dispensaire-public',locationsActivesCache:[]};
 vm.createContext(c);
 vm.runInContext(fonctions('plateau-navigation.js',NAV),c);
 // Rendu simulé : on note ce que l'écran affiche et si la navigation serveur aurait été commandée.
 if(opts.renduSimule){
  const vraiEB=c.enterBuilding,vraiER=c.enterRoom;
  c.enterBuilding=(b,s)=>{journal.push(['affiche-batiment',b,c.navigationInterieureRendu?.buildingId===b]);vraiEB(b,s);c.state.currentBuilding=b;};
  c.enterRoom=(b,r,t)=>{journal.push(['affiche-piece',b,r,c.navigationInterieureRendu?.roomId===r]);vraiER(b,r,t);c.state.currentRoom=r;};
 }
 c.afficherPositionNavigationConfirmee=f=>journal.push(['position-serveur',f.currentCity,f.currentBuilding,f.currentRoom]);
 return c;}
const commandes=c=>c.journal.filter(e=>e[0]==='commande');

test('garde réelle de enterBuilding : sans marqueur, la navigation serveur est recommandée (ancien circuit)',()=>{
 const c=jeu();c.BUILDINGS={mairie:{rooms:{hall:{},bureau:{}}}};c.enterBuilding('mairie',true);assert.deepEqual(commandes(c)[0],['commande','mairie','hall']);
 c.journal.length=0;c.state.currentBuilding='mairie';c.state.currentRoom='bureau';c.enterRoom('mairie','hall',null);assert.deepEqual(commandes(c)[0],['commande','mairie','hall']);});

test('F5 : la position serveur est représentée, aucune navigation recommandée',()=>{
 const c=jeu({renduSimule:true});c.state.currentBuilding=null;c.state.currentRoom=null;
 c.BUILDINGS={mairie:{rooms:{bureau:{}}}};
 vm.runInContext(fonctions('plateau-core.js',['restaurerPositionApresChargement']),c);
 // Le rendu réel s'arrête au bâtiment inconnu ; la garde est éprouvée avant.
 const b=c.BUILDINGS;c.restaurerPositionApresChargement({currentBuilding:'mairie',currentRoom:'bureau'});
 assert.equal(commandes(c).length,0,JSON.stringify(c.journal));
 assert.ok(c.journal.some(e=>e[0]==='affiche-batiment'&&e[1]==='mairie'&&e[2]===true),JSON.stringify(c.journal));
 assert.equal(c.navigationInterieureRendu,null);});

test('camion : monter représente la pièce posée par le serveur, sans redescendre',async()=>{
 const c=jeu({renduSimule:true});let descendu=0;
 Object.assign(c,{RP_CAMION_BATIMENT:'camion-militaire',RP_CAMION_ETAT:null,RP_CAMIONS_ICI:[],RP_CAMION_SIGNATURE:'',
  sbCamionEtat:async()=>({ok:true,dedans:true,camion:{id:'cam1',ville:'caserne'}}),camionInjecterPiece(){},
  sbCamionDescendre:async()=>{descendu++;return {ok:true};},camionDemarrerVeille(){},camionSignalerRefus(){}});
 vm.runInContext('var RP_CAMION_BATIMENT="camion-militaire";'+fonctions('plateau-camion-militaire.js',['camionEntrerDansLaPiece','camionNaviguerVers']),c);
 await c.camionEntrerDansLaPiece('cam1');
 assert.equal(commandes(c).length,0,JSON.stringify(c.journal));assert.equal(descendu,0);
 c.camionNaviguerVers('capitale','caserne-militaire','corps_garde');
 assert.equal(commandes(c).length,0,JSON.stringify(c.journal));});

test('libération purgée au QHS : position relue sur le serveur, jamais posée par l’écran',async()=>{
 const c=jeu();c.state.estEmprisonne={qhs:true,retourVille:'ville_a'};c.state.currentCity='qhs';c.state.currentBuilding='qhs-prison';c.state.currentRoom='cellules_qhs';
 Object.assign(c,{incrementerDetentionDeserteur(){},sbRpc:async fn=>fn==='detention_clore_purgee'?[{ok:true,sortait_du_qhs:true,retour_ville:'ville_a'}]:null,
  sbLoadPersonnage:async()=>({userId:'u1',country:'republic',currentCity:'ville_a',currentBuilding:'centre-multinodal-port-sainte-marie',currentRoom:'hall_gare_psm'}),
  forceRenderCity(){c.journal.push(['force-ville']);}});
 c.WORLD={republic:{ville_a:{buildings:['hotel-port']}}};
 vm.runInContext(fonctions('plateau-justice-economie.js',['verifierLiberationPrisonniers']),c);
 await c.verifierLiberationPrisonniers();
 assert.deepEqual(c.journal.find(e=>e[0]==='position-serveur'),['position-serveur','ville_a','centre-multinodal-port-sainte-marie','hall_gare_psm'],JSON.stringify(c.journal));
 assert.equal(commandes(c).length,0);assert.notEqual(c.state.currentBuilding,'hotel-port');});

test('incorporation : position relue sur le serveur (corps de garde)',async()=>{
 const c=jeu();c.state.estEmprisonne={motifDesertionSeul:true};c.state.currentBuilding='commissariat-local';c.state.currentRoom='geoles';
 c.state.char.requisition={statut:'deserteur'};c.state.mobilisationNationaleCache=true;
 Object.assign(c,{sbRpc:async fn=>fn==='detention_clore_motif_eteint'?[{ok:true}]:[{ok:true}],sbSavePersonnage:async()=>{},sauvegarderPersonnageImmediat(){},
  sbLoadPersonnage:async()=>({userId:'u1',country:'republic',currentCity:'caserne',currentBuilding:'caserne-militaire',currentRoom:'corps_garde'})});
 vm.runInContext(fonctions('plateau-politique.js',['doAccepterIncorporation']),c);
 try{await c.doAccepterIncorporation();}catch(e){c.journal.push(['exception',String(e)]);}
 assert.ok(c.journal.some(e=>e[0]==='position-serveur'&&e[2]==='caserne-militaire'),JSON.stringify(c.journal));
 assert.equal(commandes(c).length,0);});

function jeuHospitalisation(reponses){
 const c=jeu();const appels=[];c.appels=appels;
 Object.assign(c,{dateCivileParisMedicale:()=> '2026-11-01',sauvegarderPersonnageImmediat(){},
  sbSavePersonnage:async()=>{appels.push(['sauvegarde',c.state.hospitalisation?.lieu]);},
  sbRpcVerdict:async(fn,p)=>{appels.push([fn,p]);return reponses.shift();},
  sbSaveLocation:async l=>{appels.push(['location',l.roomId]);},sbSupprimerLocation:async(...a)=>{appels.push(['location-supprimee',a[2]]);},
  deduireCoutOrdre:async()=>{appels.push(['paiement-ecran']);return {ok:true};},
  sbLoadPersonnage:async()=>({userId:'u1',country:'republic',currentCity:'capitale',currentBuilding:'clinique-privee',currentRoom:'chambre_2'}),
  getChambreAttribueeClinique:()=>null,trouverChambreLibreClinique:()=> 'chambre_2'});
 vm.runInContext(fonctions('plateau-personnage.js',['declencherHospitalisation','doTransfertCliniquePrivee','HOSPITALISATION_REFUS','hospitalisationRejoindreServeur','conduireHospitalisationServeur','transfertCliniqueServeur']),c);
 return c;}

// Mis à jour par le chantier hospitalisation (01/11/2026, GAME-DESIGN-HOSPITALISATION.md) : hors
// empoisonnement, l'écran n'enregistre que les PA à 0 et le SERVEUR hospitalise et transfère
// (déclencheur à 0 PA, même porte). L'empoisonnement garde la porte appelée depuis l'écran.
test('hospitalisation à 0 PA : seule la chute des PA est enregistrée, le serveur transfère ; aucune navigation écran',async()=>{
 const c=jeuHospitalisation([]);
 c.declencherHospitalisation('partielle');await new Promise(setImmediate);await new Promise(setImmediate);
 assert.deepEqual(c.appels.map(a=>a[0]),['sauvegarde'],JSON.stringify(c.appels));
 assert.equal(c.state.pa,0);assert.equal(commandes(c).length,0);});

test('hospitalisation par empoisonnement : fiche enregistrée puis porte serveur, aucune navigation écran',async()=>{
 const c=jeuHospitalisation([{ok:true,city:'capitale',building:'dispensaire-public',room:'salle_attente'}]);
 c.declencherHospitalisation('partielle',{poison:true});await new Promise(setImmediate);await new Promise(setImmediate);
 assert.deepEqual(c.appels.map(a=>a[0]),['sauvegarde','hospitalisation_lieu_rejoindre'],JSON.stringify(c.appels));
 assert.equal(c.appels[1][1].p_lieu,'dispensaire');assert.equal(commandes(c).length,0);
 assert.ok(c.journal.some(e=>e[0]==='position-serveur'));});

test('transfert clinique : vérification, chambre, puis paiement et déplacement serveur',async()=>{
 const c=jeuHospitalisation([{ok:true,verifie:true},{ok:true}]);c.state.hospitalisation={lieu:'dispensaire'};
 await c.doTransfertCliniquePrivee(0,1000);
 assert.deepEqual(c.appels.map(a=>a[0]),['hospitalisation_lieu_rejoindre','location','hospitalisation_lieu_rejoindre'],JSON.stringify(c.appels));
 assert.equal(c.appels[0][1].p_verifier,true);assert.equal(c.appels[2][1].p_chambre,'chambre_2');
 assert.equal(c.state.hospitalisation.lieu,'clinique');assert.equal(commandes(c).length,0);});

test('transfert clinique refusé à la vérification : ni chambre ni paiement',async()=>{
 const c=jeuHospitalisation([{ok:false,raison:'fonds_insuffisants'}]);c.state.hospitalisation={lieu:'dispensaire'};
 await c.doTransfertCliniquePrivee(0,1000);
 assert.deepEqual(c.appels.map(a=>a[0]),['hospitalisation_lieu_rejoindre']);assert.equal(c.state.hospitalisation.lieu,'dispensaire');
 assert.equal(c.toasts.at(-1)[1],'1000 FR requis pour le transfert.');});

test('transfert clinique refusé à l’exécution : la chambre réservée est rendue',async()=>{
 const c=jeuHospitalisation([{ok:true,verifie:true},{ok:false,raison:'fonds_insuffisants'}]);c.state.hospitalisation={lieu:'dispensaire'};
 await c.doTransfertCliniquePrivee(0,1000);
 assert.deepEqual(c.appels.map(a=>a[0]),['hospitalisation_lieu_rejoindre','location','hospitalisation_lieu_rejoindre','location-supprimee']);
 assert.equal((c.state.locationsActives||[]).length,0);assert.equal(c.state.hospitalisation.lieu,'dispensaire');});

test('relecture d’une autre identité : rien n’est représenté',async()=>{
 const c=jeu();c.sbLoadPersonnage=async()=>({userId:'autre',currentBuilding:'x'});
 assert.equal(await c.adopterPositionServeurRelue(),false);assert.equal(c.journal.length,0);});

test('hors navigation serveur (avant activation) : les anciens chemins restent inchangés',async()=>{
 const c=jeuHospitalisation([]);c.state._navigationServeur=false;c.state.hospitalisation={lieu:'dispensaire'};
 await c.doTransfertCliniquePrivee(0,1000);
 assert.equal(c.appels[0][0],'paiement-ecran');});
