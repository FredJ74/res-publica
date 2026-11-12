'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const root=path.resolve(__dirname,'../..');
const js=fs.readFileSync(path.join(root,'plateau-clinique-nuitee.js'),'utf8');
const router=fs.readFileSync(path.join(root,'plateau-router.js'),'utf8');
const perso=fs.readFileSync(path.join(root,'plateau-personnage.js'),'utf8');
const html=fs.readFileSync(path.join(root,'plateau.html'),'utf8');
function init(country='republic'){
 const log=[],calls=[],identite={name:'A'};
 const state={country,currentCity:'capitale',currentBuilding:'clinique-privee',
  currentRoom:'reception_clinique',char:identite,locationsActives:[],pa:10,hp:40,moral:35,liquide:500,arg:500};
 let popupBody='',popupTitle='',popupOpen=false;
 const buttons={};
 const modal={classList:{add(k){if(k==='open')popupOpen=true;},remove(k){if(k==='open')popupOpen=false;}}};
 const titre={set textContent(v){popupTitle=v;},get textContent(){return popupTitle;}};
 const corps={set innerHTML(v){popupBody=v;},get innerHTML(){return popupBody;},
  querySelector(selector){return buttons[selector]||(buttons[selector]={
   disabled:false,textContent:'',addEventListener(event,fn){this.click=fn;}});}
 };
 const document={getElementById(id){
  if(id==='modal-postes')return modal;
  if(id==='postes-modal-title')return titre;
  if(id==='postes-body')return corps;
  return buttons['#'+id]||null;
 }};
 const x={console,state,document,confirm:()=>{throw Error('Native confirmation forbidden')},
  showToast:(...v)=>log.push(v),updateUI:()=>{},
  chargerLocations:async()=>{state.locationsActives=[{
    buildingId:'clinique-privee',roomId:'chambre_1',locataire:'A',
    reservationClinique:true,chambreClinique:true,country,city:'capitale'}];},
  enterRoom:(b,r)=>{state.currentBuilding=b;state.currentRoom=r;},
  getChambreAttribueeClinique:nom=>state.locationsActives.find(l=>l.locataire===nom),
  sbRpc:async(name)=>{calls.push(name);
   if(name==='clinique_nuitee_reserver')return {ok:true,chambre:'chambre_1',prix:150,liquide:350,arg:350};
   if(name==='clinique_nuitee_consommer')return {ok:true,pa:12,hp:50,moral:38,bonus_pa:2,bonus_hp:10,bonus_moral:3,rejeu:false};
   throw Error('Unexpected RPC '+name);},
  addJournalEntry:()=>{}
 };
 x.window=x;vm.createContext(x);vm.runInContext(js,x,{filename:'plateau-clinique-nuitee.js'});
 return{x,state,log,calls,
  get popupBody(){return popupBody;},get popupTitle(){return popupTitle;},get popupOpen(){return popupOpen;},
  async confirmer(){
   assert.equal(calls.length,0,'aucun appel réseau avant confirmation');
   assert.equal(popupOpen,true);
   const bouton=buttons['#clinique-confirmer-reservation'];
   assert.ok(bouton?.click,'bouton de confirmation présent');
   bouton.click();
   await new Promise(resolve=>setImmediate(resolve));
  }
 };
}
test('ordres du comptoir et de chambre seulement en Republia et Sovarka',()=>{
 for(const country of ['republic','soviet']){
  const f=init(country),order=f.x.RP_ORDRES_DYNAMIQUES[0];
  const accueil=order('clinique-privee','reception_clinique');
  assert.equal(accueil.length,1);
  assert.equal(accueil[0].fn,'clinique_reserver_nuit');
  assert.match(accueil[0].label,new RegExp(country==='soviet'?'150 PSK':'150 FR'));
  assert.equal(accueil[0].cost,0,'aucun paiement client');
  assert.equal(order('dispensaire-public','reception_clinique').length,0);
  assert.equal(order('clinique-privee','chambre_1').length,1);
  assert.equal(order('clinique-privee','chambre_1')[0].fn,'clinique_dormir');
 }
 const f=init('narco');assert.equal(f.x.RP_ORDRES_DYNAMIQUES[0]('clinique-privee','reception_clinique').length,0);
});
test('réservation : un seul RPC, retour de solde serveur, chambre entrée après relecture',async()=>{
 const f=init();f.x.reserverNuiteeClinique();
 assert.match(f.popupBody,/150 FR/);
 await f.confirmer();
 assert.equal(f.calls.join(','),'clinique_nuitee_reserver');
 assert.equal(f.state.currentRoom,'chambre_1');
 assert.equal(f.state.liquide,350);
 assert.equal(f.state.arg,350);
 assert.equal(f.state.locationsActives[0].reservationClinique,true);
 assert.equal(f.x.RP_ORDRES_DYNAMIQUES[0]('clinique-privee','chambre_1').length,2);
});
test('bonus de sommeil : uniquement verdict serveur, récupération distincte du repos',async()=>{
 const f=init();f.x.reserverNuiteeClinique();
 assert.match(f.popupBody,/150 FR/);
 await f.confirmer();
 await f.x.consommerNuiteeCliniqueApresDormir('A','republic','chambre_1');
 assert.equal(f.calls.join(','),'clinique_nuitee_reserver,clinique_nuitee_consommer');
 assert.equal(f.state.pa,12);
 assert.equal(f.state.hp,50);
 assert.equal(f.state.moral,38);
});
test('hors chambre et autre personne : aucun RPC de consommation',async()=>{
 const f=init();f.x.reserverNuiteeClinique();
 assert.match(f.popupBody,/150 FR/);
 await f.confirmer();
 f.state.currentRoom='reception_clinique';
 await f.x.consommerNuiteeCliniqueApresDormir('A','republic','chambre_1');
 assert.equal(f.calls.length,1);
 f.state.currentRoom='chambre_1';
 await f.x.consommerNuiteeCliniqueApresDormir('autre','republic','chambre_1');
 assert.equal(f.calls.length,1);
});
test('présentation sovarkienne : popup intégrée et prix en PSK, jamais boîte native',async()=>{
 const f=init('soviet');
 f.x.reserverNuiteeClinique();
 assert.match(f.popupTitle,/Réserver une chambre/);
 assert.match(f.popupBody,/150 PSK/);
 assert.match(f.popupBody,/\+2 PA, \+10 Santé et \+3 Moral/);
 assert.match(f.popupBody,/reste réservée tant que/);
 assert.match(f.popupBody,/déjà dormi aujourd’hui/);
 assert.equal(f.calls.length,0);
 await f.confirmer();
 assert.equal(f.calls.length,1);
 assert.equal(f.popupOpen,false);
});
test('les deux raccordements d’ordres et la chaîne Dormir sont présents',()=>{
 assert.match(router,/fn === 'clinique_reserver_nuit'/);
 assert.match(router,/fn === 'clinique_dormir'/);
 assert.match(router,/fn === 'clinique_verifier_bonus'/);
 assert.match(perso,/consommerNuiteeCliniqueApresDormir/);
 assert.match(perso,/if \(retourActif\(\) && pieceInitialRepos/);
 assert.match(perso,/ORDRES_MEDICAUX_CHAMBRE_CLINIQUE[\s\S]*'clinique_dormir'/);
 assert.match(html,/plateau-clinique-nuitee\.js\?v=clinique-i18n-20261112/);
});
