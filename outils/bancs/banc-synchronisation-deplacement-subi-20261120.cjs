// Banc : déplacement subi par un autre PJ, sans réseau ni mutation.
const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const src=fs.readFileSync(path.resolve(__dirname,'../../plateau-navigation.js'),'utf8');
const start=src.indexOf('let synchronisationDeplacementSubiEnCours = false;');
const end=src.indexOf('// Une porte serveur a DÉJÀ déplacé le PJ',start);
assert(start>=0&&end>start,'corps de surveillance introuvable');
const code=src.slice(start,end);
function environnement(){
 let uid='uid-test',queries=0,charges=0,rendus=0,notifications=0;
 const state={char:{name:'Arnie'},country:'soviet',currentCity:'ville_b',currentBuilding:'commissariat',currentRoom:'accueil',personnageChargeDepuisServeur:true,hospitalisation:null,hp:10,pa:10};
 const document={hidden:false};
 const position={ok:true,country:'soviet',city:'ville_b',building:'dispensaire-public',room:'chambre',street:null};
 const fiche={userId:'uid-test',country:'soviet',currentCity:'ville_b',currentBuilding:'dispensaire-public',currentRoom:'chambre',hospitalisation:{regime:'combat'},hp:0,pa:0};
 const ctx={state,document,console,rpAuthUid:()=>uid, sbRpc:async()=>{queries++;return {...position}},
 sbLoadPersonnage:async()=>{charges++;return {...fiche}},
 afficherPositionNavigationConfirmee: (v)=>{rendus++;state.country=v.country;state.currentCity=v.currentCity;state.currentBuilding=v.currentBuilding;state.currentRoom=v.currentRoom;},
 showToast:()=>{notifications++},updateUI:()=>{},chargerVraisJoueursPresents:()=>{}};
 vm.createContext(ctx);vm.runInContext(code,ctx);
 return {state,document,position,fiche,ctx,run:()=>vm.runInContext('synchroniserDeplacementSubi()',ctx),
 get compte(){return {queries,charges,rendus,notifications}},changeUid:(v)=>{uid=v}};
}
(async()=>{
 let e=environnement(); assert.equal(await e.run(),true);assert.equal(e.state.currentBuilding,'dispensaire-public');assert.equal(e.state.hp,0);assert.equal(e.state.pa,0);assert.equal(e.compte.rendus,1);assert.equal(e.compte.notifications,1);
 e=environnement();e.position.building='commissariat';e.position.room='accueil';assert.equal(await e.run(),false);assert.equal(e.compte.charges,0);assert.equal(e.compte.rendus,0);
 e=environnement();e.document.hidden=true;assert.equal(await e.run(),false);assert.equal(e.compte.queries,0);
 e=environnement();e.fiche.userId='uid-autrui';assert.equal(await e.run(),false);assert.equal(e.compte.rendus,0);
 e=environnement();e.changeUid('uid-autre');assert.equal(await e.run(),false);assert.equal(e.compte.rendus,0);
 e=environnement();e.state.personnageChargeDepuisServeur=false;assert.equal(await e.run(),false);assert.equal(e.compte.queries,0);
 e=environnement();e.ctx.rueCentraleDeplacementEnCours={};assert.equal(await e.run(),false);assert.equal(e.compte.queries,0);
 e=environnement();let debloquer; e.ctx.sbRpc=()=>new Promise(resolve=>{debloquer=resolve});const essai=e.run();e.state.currentRoom='bureau';debloquer({...e.position});assert.equal(await essai,false);assert.equal(e.compte.rendus,0);
 console.log('OK : 8 cas de synchronisation, droits et concurrence.');
})().catch(e=>{console.error(e);process.exitCode=1});
