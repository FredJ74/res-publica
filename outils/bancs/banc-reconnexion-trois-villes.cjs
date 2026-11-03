'use strict';
// Chargement réel et réponse async fictive : aucun compte ni Supabase.
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const acorn=require('../vercel/node_modules/acorn'),root=path.resolve(__dirname,'../..');
const source=process.env.HG135_CONTRE_POSITION?require('node:child_process').execFileSync('git',['show',process.env.HG135_CONTRE_POSITION+':plateau-core.js'],{cwd:root,encoding:'utf8'}):fs.readFileSync(path.join(root,'plateau-core.js'),'utf8');
const ast=acorn.parse(source,{ecmaVersion:'latest'});
function fixture(ville,sort='ok'){
 const diff={country:'khalija',currentCity:'capitale',currentBuilding:'banque-nationale',currentRoom:'accueil'};
 const nom='FixtureReconnexion',timers=[],rendus=[],erreurs=[],ecritures=[];let finir;
 const local={name:nom,...diff};
 const batiment=ville==='capitale'?'tribunal':'tribunal-local';
 const position={country:'republic',currentCity:ville,currentBuilding:batiment,currentRoom:'greffe'};
 const fiche={userId:sort==='etranger'?'autre-uid':'uid-fixture',...position,char:{name:nom,...position},arg:0,liquide:0,banque:0,pa:0};
 const c={state:{char:null,currentBuilding:null,currentRoom:null},console:{log(){},warn:(...a)=>erreurs.push(a)},window:{},document:{getElementById:()=>null},migrerCareerId(){},rpDiagId(){},rpProprietaireCache:()=> 'uid-fixture',rpAuthUid:()=> 'uid-fixture',restaurerJournal(){},diagnostiquerIdentite:async()=>{},updateUI(){},
  rpPurgerCachePersonnage(){},rpOublierIdentiteCourante(){},recupererPersonnageDuCompte:async()=>{},
  localStorage:{getItem:k=>k==='respublica_last_char'?nom:k==='respublica_char_'+nom?JSON.stringify(local):null,setItem:(...a)=>ecritures.push(a)},
  sbLoadPersonnage:()=>new Promise((resolve,reject)=>{finir=()=>sort==='panne'?reject(Error('panne fictive')):resolve(fiche);}),
  sbSavePersonnage:()=>{throw Error('sauvegarde interdite pendant le banc');},
  setTimeout:(fn,ms)=>timers.push({fn,ms}),representerPositionServeur:(b,r)=>rendus.push({b,r,ville:c.state.currentCity,pays:c.state.country})};
 vm.createContext(c);vm.runInContext(fs.readFileSync(path.join(root,'data.js'),'utf8'),c);
 for(const nom of ['loadCharacter','applyCharToState','restaurerPositionApresChargement']){const n=ast.body.find(n=>n.id?.name===nom);assert.ok(n,nom);vm.runInContext(source.slice(n.start,n.end),c);}
 return {c,finir:()=>finir(),timers,rendus,erreurs,ecritures,position};
}
for(const ville of ['capitale','ville_a','ville_b'])for(const sort of ['ok','panne','etranger']){
 test(ville+' : cache périmé / '+sort,async()=>{
  const f=fixture(ville,sort);f.c.loadCharacter();assert.equal(f.rendus.length,0,'aucun déplacement avant lecture');assert.equal(f.timers.length,0);
  f.finir();await new Promise(r=>setImmediate(r));
  if(sort==='ok'){
   assert.equal(f.c.state.personnageChargeDepuisServeur,true);
   assert.equal(f.c.state.country,'republic');assert.equal(f.c.state.currentCity,ville);
   assert.equal(f.c.state.pa,0);assert.equal(f.c.state.liquide,0);
   assert.equal(f.timers.length,1);assert.equal(f.timers[0].ms,300);f.timers[0].fn();
   assert.deepEqual(f.rendus,[{b:f.position.currentBuilding,r:'greffe',ville,pays:'republic'}]);assert.equal(f.erreurs.length,0);
  }else{
   assert.equal(f.c.state.personnageChargeDepuisServeur,false);assert.equal(f.timers.length,0);assert.deepEqual(f.rendus,[],'aucune ancienne position restaurée');
  }
  assert.deepEqual(f.ecritures,[],'aucune sauvegarde du cache ou de la position');
 });
}

// #366 corrige aussi la lecture de rue APRÈS le chargement : un cache de ville
// erroné ne doit pas faire refuser la vraie position. Ce corps, distinct du
// chargement de fiche ci-dessus, doit être exécuté, pas seulement recherché par regex.
function rue(ville,groupes){
 const c=vm.createContext({console,state:{char:{name:'FixtureRue',currentCity:'ancienne'},country:'republic',currentCity:ville==='capitale'?'ville_a':'capitale',currentBuilding:null,currentRoom:null,_navigationServeur:groupes},session:'S',appels:[],affichages:[],toasts:[]});
 c.rpAuthUid=()=> 'uid-fixture';c.rpAuthSessionIdentifiant=()=>c.session;
 const texte=process.env.HG135_CONTRE_RUE?require('node:child_process').execFileSync('git',['show',process.env.HG135_CONTRE_RUE+':plateau-rue-centrale.js'],{cwd:root,encoding:'utf8'}):fs.readFileSync(path.join(root,'plateau-rue-centrale.js'),'utf8');
 vm.runInContext(texte,c);const noeud=vm.runInContext('RUE_CENTRALE_DEPART.republic['+JSON.stringify(ville)+']',c);
 c.sbGroupePjLire=async()=>null;c.sbPositionNavigationConfirmee=()=>null;
 c.sbRpc=(fn)=>{c.appels.push(fn);assert.equal(fn,'rue_position_lire','aucun ordre de déplacement au rechargement');return new Promise(r=>{c.finir=()=>r(c.reponse);});};
 c.reponse={ok:true,country:'republic',city:ville,street:noeud,building:null,room:null};
 c.afficherNoeudRue=async(...a)=>c.affichages.push(a);c.showToast=(...a)=>c.toasts.push(a);
 return {c,noeud};
}
for(const ville of ['capitale','ville_a','ville_b'])for(const groupes of [false,true])test('rue #366 / '+ville+' / groupes '+groupes,async()=>{
 const {c,noeud}=rue(ville,groupes),p=c.initialiserRueCentrale('republic','ancien-noeud',null);
 await new Promise(r=>setImmediate(r));c.finir();await p;
 assert.equal(c.state.currentCity,ville);assert.equal(c.state.char.currentCity,ville);
 assert.deepEqual([...c.appels],['rue_position_lire']);assert.deepEqual(c.affichages,[['republic',noeud,null,true]]);assert.equal(c.toasts.length,0);
});
for(const changement of ['session','personnage','refus','rue-inconnue'])test('rue #366 : '+changement+' ne restaure pas de position inventée',async()=>{
 const {c}=rue('ville_a',false),ancienne=c.state.currentCity,p=c.initialiserRueCentrale('republic','ancien-noeud',null);
 if(changement==='session')c.session='autre';if(changement==='personnage')c.state.char={name:'AutreFixture'};
 if(changement==='refus')c.reponse={ok:false,raison:'session_absente'};if(changement==='rue-inconnue')c.reponse.street='inconnue';
 c.finir();await p;assert.deepEqual(c.affichages,[]);assert.equal(c.state.currentCity,ancienne);
});
