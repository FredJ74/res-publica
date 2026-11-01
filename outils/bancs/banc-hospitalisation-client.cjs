// Banc client de l'hospitalisation à 0 PA (Claude, 01/11/2026). Règles : GAME-DESIGN-HOSPITALISATION.md.
// Vraies fonctions du dépôt (extraites par acorn), serveur simulé, aucune preuve distante.
// Contre-épreuve : CONTRE=<ref git> exécute les mêmes attentes sur les fichiers de cette référence.
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),{execFileSync}=require('node:child_process');
let acorn;try{acorn=require('../vercel/node_modules/acorn');}catch(_){acorn=require('acorn');}
const root=path.resolve(__dirname,'../..');
const lire=f=>process.env.CONTRE?execFileSync('git',['show',process.env.CONTRE+':'+f],{cwd:root,encoding:'utf8',maxBuffer:64<<20}):fs.readFileSync(path.join(root,f),'utf8');
// Déclarations de premier niveau nommées (fonctions, const/let), et instructions qui les complètent.
function extraire(file,names){const s=lire(file);const t=acorn.parse(s,{ecmaVersion:'latest'}).body;const out=[];
 for(const n of t){
  if(n.type==='FunctionDeclaration'&&names.includes(n.id.name))out.push(s.slice(n.start,n.end));
  else if(n.type==='VariableDeclaration'&&n.declarations.some(d=>names.includes(d.id.name)))out.push(s.slice(n.start,n.end).replace(/^(const|let) /,'var '));
  else if(n.type==='ExpressionStatement'&&names.some(x=>s.slice(n.start,n.end).startsWith('Object.assign('+x)))out.push(s.slice(n.start,n.end));}
 return out.join('\n');}
const AUJ='2026-11-01',HIER='2026-10-31';
const PERSO=['declencherHospitalisation','hospitalisationJourPa0','hospitalisationEcritureInterdite','HOSPITALISATION_REFUS',
 'relectureHospitalisationEnCours','derniereRelectureHospitalisation','relireHospitalisationServeur','surveillerHospitalisationServeur',
 'doRepasHopital','doSortieHopital','hospitalisationRejoindreServeur','verifierProgressionHospitalisation','doDormir','signalerRefusSalaire','MOTIFS_REFUS_SALAIRE'];
function jeu(serveur={}){
 const c={console,JSON,Promise,Array,Object,Math,Date,Number,toasts:[],journal:[],rpc:[],sauvegardes:0,positions:[],
  state:{char:{name:'A',country:'republic'},country:'republic',pa:3,hp:100,moral:50,arg:0,liquide:0,currentCity:'capitale',
   currentBuilding:'assemblee',currentRoom:'hemicycle',_navigationServeur:true,_ficheBase:{}},
  COUNTRIES:{republic:{cur:'FR'}},
  dateCivileParisMedicale:()=>AUJ,showToast:(...a)=>c.toasts.push(a),addJournalEntry:(t)=>c.journal.push(t),updateUI(){},
  switchSelfTab(){},sbFicheBaseAdopter(){},
  sbSavePersonnage:async(s)=>{c.sauvegardes++;c.paSauve=s.pa;c.hospiSauvee=s.hospitalisation;return true;},
  sbLoadPersonnage:async()=>serveur.fiche||null,
  sbRpc:async(fn,p)=>{c.rpc.push(fn);return serveur[fn]?serveur[fn](p):null;},
  sbRpcVerdict:async(fn,p)=>{c.rpc.push(fn);return serveur[fn]?serveur[fn](p):null;},
  afficherPositionNavigationConfirmee:(f)=>c.positions.push([f.currentCity,f.currentBuilding,f.currentRoom]),
  adopterPositionServeurRelue:async()=>{c.positions.push(['relue']);return true;},
  rpAuthUid:()=>'u1'};
 vm.createContext(c);
 vm.runInContext(extraire('plateau-personnage.js',PERSO),c);
 return c;}
const attendre=()=>new Promise(r=>setTimeout(r,20));
const PA0=(j,extra={})=>({regime:'pa0',lieu:'dispensaire',dateDebutParis:j===0?AUJ:j===1?HIER:'2026-10-30',dateFinParis:'9999-12-31',...extra});

test('agression / combat perdu : l’écran enregistre seulement les PA à 0, puis adopte l’hospitalisation du serveur',async()=>{
 const fiche={userId:'u1',pa:0,hospitalisation:PA0(0),currentCity:'ville_a',currentBuilding:'dispensaire-public-v',currentRoom:'attente'};
 const c=jeu({fiche});c.declencherHospitalisation('totale');await attendre();
 assert.equal(c.paSauve,0);
 assert.equal(c.hospiSauvee??null,null,'l’écran ne pose plus de durée par palier');
 assert.equal(c.state.hospitalisation.regime,'pa0');
 assert.deepEqual(c.positions[0],['ville_a','dispensaire-public-v','attente']);});

test('empoisonnement : garde son propre fonctionnement (durée par palier posée comme avant)',()=>{
 const c=jeu();c.state._navigationServeur=false;c.enterBuilding=()=>{};c.enterRoom=()=>{};c.sauvegarderPersonnageImmediat=()=>{};
 c.declencherHospitalisation('partielle',{poison:true});
 assert.equal(c.state.hospitalisation.regime,undefined);
 assert.equal(c.state.hospitalisation.dateFinParis,'2026-11-05');
 assert.equal(c.state.pa,0);});

test('PA à 0 sans hospitalisation connue : la fiche est relue (ordre payé jusqu’au dernier PA)',async()=>{
 const c=jeu({fiche:{userId:'u1',pa:0,hospitalisation:PA0(0),currentCity:'capitale',currentBuilding:'dispensaire-public',currentRoom:'salle_attente'}});
 c.state.pa=0;c.surveillerHospitalisationServeur();await attendre();
 assert.equal(c.state.hospitalisation?.regime,'pa0');
 const d=jeu({fiche:null});d.state.pa=0;d.state.estEmprisonne={raison:'x'};d.surveillerHospitalisationServeur();await attendre();
 assert.equal(d.rpc.length+d.positions.length,0);});

test('J0 : Dormir refusé et nommé, aucun salaire ni effet du sommeil',async()=>{
 const c=jeu({pa_repos_nocturne:()=>({ok:false,raison:'hospitalise_j0',pa:0})});c.state.pa=0;c.state.hospitalisation=PA0(0);
 const r=await c.doDormir();
 assert.equal(r,false);assert.deepEqual(c.rpc,['pa_repos_nocturne']);
 assert.equal(c.toasts[0][0],'Repos impossible');});

test('J2 : le sommeil à l’hôpital est relaté avec les montants du serveur et la sortie annoncée',async()=>{
 const c=jeu({pa_repos_nocturne:()=>({ok:true,pa:22,hospitalisation:true,jour_hospitalisation:2,gain:18,repas:2,sortie_possible:true,bonus_consomme:0}),
  salaire_civil_percevoir:()=>({ok:false,raison:'bareme_absent'})});
 c.state.pa=2;c.state.hospitalisation=PA0(2,{lieu:'clinique'});
 await c.doDormir();
 assert.equal(c.state.pa,22);
 assert.ok(c.journal.some(t=>t.includes('Nuit à l\'hôpital (jour 2) : +18 PA, +2 PA du repas')),JSON.stringify(c.journal));
 assert.ok(c.toasts.some(t=>t[0]==='Sortie autorisée'));
 assert.equal(c.state.hospitalisation.regime,'pa0','la progression ne lève pas une hospitalisation pa0');});

test('progression nocturne : le régime pa0 ne touche ni aux PA ni à l’hospitalisation',()=>{
 const c=jeu();c.state.pa=14;c.state.hospitalisation=PA0(2);c.verifierProgressionHospitalisation();
 assert.equal(c.state.pa,14);assert.equal(c.state.hospitalisation.regime,'pa0');});

test('mails et forums : interdits à J0 seulement',()=>{
 const c=jeu();c.state.hospitalisation=PA0(0);assert.equal(c.hospitalisationEcritureInterdite(),true);
 c.state.hospitalisation=PA0(1);assert.equal(c.hospitalisationEcritureInterdite(),false);
 c.state.hospitalisation={lieu:'dispensaire',palier:'partielle',dateFinParis:'2026-11-04'};assert.equal(c.hospitalisationEcritureInterdite(),false);
 const forum=lire('forum.js');
 for(const f of ['async function submitNewTopic() {','async function submitReply() {','function submitMail() {'])
  assert.match(forum.slice(forum.indexOf(f),forum.indexOf(f)+400),/hospitalisationEcritureInterdite\(\)/,f);});

test('repas de l’hôpital : payé par le serveur, l’écran adopte ses PA',async()=>{
 const c=jeu({hospitalisation_repas_prendre:()=>({ok:true,pa:1,bonus_lendemain:2,jour:1})});c.state.pa=2;c.state.hospitalisation=PA0(1);
 await c.doRepasHopital();
 assert.equal(c.state.pa,1);assert.equal(c.state.hospitalisation.repasLe,AUJ);
 const d=jeu({hospitalisation_repas_prendre:()=>({ok:false,raison:'repas_deja_pris'})});d.state.pa=2;d.state.hospitalisation=PA0(1);
 await d.doRepasHopital();assert.equal(d.state.pa,2);assert.match(d.toasts[0][1],/déjà pris/);});

test('sortie : refus nommé sous 20 PA ; acceptée, l’hospitalisation est levée et la position relue',async()=>{
 const c=jeu({hospitalisation_lieu_rejoindre:()=>({ok:false,raison:'pa_insuffisants_sortie',pa:9,seuil:20})});c.state.hospitalisation=PA0(2);
 await c.doSortieHopital();
 assert.equal(c.state.hospitalisation.regime,'pa0');assert.match(c.toasts[0][1],/20 PA/);
 const d=jeu({hospitalisation_lieu_rejoindre:(p)=>p.p_lieu==='sortie'?{ok:true,sortie:true,street:'luthecia-imprimerie'}:null});
 d.state.hospitalisation=PA0(3);await d.doSortieHopital();
 assert.equal(d.state.hospitalisation,null);assert.deepEqual(d.positions,[['relue']]);});

test('catalogue : ordres présents aux trois lieux de soins, coût du repas identique au miroir serveur, routage',()=>{
 const data=lire('data.js'),routeur=lire('plateau-router.js'),sql=lire('migrations/20261101171000_hospitalisation_pa0.sql');
 const repas=[...data.matchAll(/\{fn:'repas_hopital'[^}]*\}/g)].map(m=>m[0]);
 assert.equal(repas.length,2,'salle d’attente de Luthécia, gabarit de province');
 for(const r of repas)assert.match(r,/pa:1, cost:0/);
 const clinique=[...data.matchAll(/\{fn:'repas_clinique'[^}]*\}/g)].map(m=>m[0]);
 assert.equal(clinique.length,10,'les 10 chambres de la clinique');
 for(const r of clinique)assert.match(r,/pa:1, cost:30/);
 assert.equal((data.match(/fn:'se_nourrir', label:'Manger'/g)||[]).length,0,'ancien « Manger » retiré des chambres (Fred, 01/11)');
 assert.match(sql,/SELECT 'repas_hopital', 1, 0/);
 assert.match(sql,/SELECT 'repas_clinique', 1, 30/);
 assert.match(routeur,/fn === 'repas_hopital' \|\| fn === 'repas_clinique'\) \{ doRepasHopital\(\)/);
 assert.equal([...data.matchAll(/\{fn:'sortie_hopital'/g)].length,13,'+ la réception de la clinique');
 assert.match(routeur,/fn === 'sortie_hopital'\) \{ doSortieHopital\(\)/);});

test('rébellion : après le sommeil de J1, le retour en cellule décidé par le serveur est adopté',async()=>{
 const c=jeu({pa_repos_nocturne:()=>({ok:true,pa:2,hospitalisation:true,jour_hospitalisation:1,gain:2,repas:0,transfert_prison:true,sortie_possible:false,bonus_consomme:0}),
  salaire_civil_percevoir:()=>({ok:false,raison:'bareme_absent'})});
 c.state.pa=0;c.state.hospitalisation=PA0(1,{detention:true});
 await c.doDormir();
 assert.equal(c.state.pa,2);assert.equal(c.state.hospitalisation,null);
 assert.ok(c.positions.some(p=>p[0]==='relue'));
 assert.ok(c.toasts.some(t=>t[0]==='Retour en cellule'));
 assert.ok(!c.toasts.some(t=>t[0]==='Sortie autorisée'));});

test('repas de la clinique : coût et bonus arrêtés par le serveur, adoptés tels quels',async()=>{
 const c=jeu({hospitalisation_repas_prendre:()=>({ok:true,pa:5,cout:30,bonus_lendemain:4,jour:1,liquide:1970,arg:1970})});
 c.state.pa=6;c.state.liquide=2000;c.state.arg=2000;c.state.hospitalisation=PA0(1,{lieu:'clinique'});
 await c.doRepasHopital();
 assert.equal(c.state.pa,5);assert.equal(c.state.liquide,1970);assert.equal(c.state.hospitalisation.repasBonus,4);
 assert.match(c.toasts[0][1],/-30 FR.*\+4 PA/);});
