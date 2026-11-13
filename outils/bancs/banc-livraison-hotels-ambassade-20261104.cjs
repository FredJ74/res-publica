'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');
const root=path.resolve(__dirname,'../..');
const personne=fs.readFileSync(path.join(root,'plateau-personnage.js'),'utf8');
const politique=fs.readFileSync(path.join(root,'plateau-politique.js'),'utf8');
function entre(s,debut,fin){
 const a=s.indexOf(debut),b=s.indexOf(fin,a+debut.length);
 assert.ok(a>=0&&b>a,'Code absent : '+debut);
 return s.slice(a,b);
}
function scene(chambrePrix=80,servicePrix=150) {
 const appels=[],messages=[],journal=[],elements=new Map();
 for(const id of ['postes-modal-title','postes-body','modal-postes']){
   elements.set(id,{innerHTML:'',textContent:'',classList:{add(){},remove(){}}});
 }
 const building={rooms:{
    accueil:{orders:chambrePrix==null?[]:[{fn:'reserver_chambre_hotel',cost:chambrePrix,pa:0}]},
    chambre:{orders:servicePrix==null?[]:[{fn:'service_etage',cost:servicePrix,pa:0}]}
 }};
 const state={char:{name:'Alice'},country:'republic',currentCity:'capitale',
    currentBuilding:'hotel-republica',currentRoom:'accueil',hp:60,moral:40};
 const c={
   state,BUILDINGS:{'hotel-republica':building},COUNTRIES:{republic:{cur:'FR'}},
   document:{getElementById:id=>elements.get(id)},console,
   chargerCommerce:async()=>({id:'hotel-commerce'}),
   commerceVendreProduit:async(...args)=>{appels.push(['chambre',...args]);return {ok:true};},
   sbRpc:async fn=>fn==='hotel_reservations_lire'
     ? [{buildingId:'hotel-republica',country:'republic',ville:'capitale'}]
     : {ok:true},
   deduireCoutOrdre:async order=>{appels.push(['service',order]);return {ok:true};},
   updateUI(){},sauvegarderPersonnageImmediat(){},addJournalEntry:(...v)=>journal.push(v),
   showToast:(...v)=>messages.push(v),queteAccueilApresReservationChambre(){},
   getCaisseLocaleId:()=> 'hotel',encaisserVenteStructure:async()=>{throw Error('double paiement')},
   signalerRefusReservationChambre(r){messages.push(['Refus réservation',r.raison]);},
   addExternalEvent(){},appliquerPaiementServeur(){}
 };
 vm.createContext(c);
 vm.runInContext('let reservationHotelEnCours = false;\n'+
   entre(personne,'async function doReserverChambreHotel(', 'async function doServiceEtage(')+
   entre(personne,'async function doServiceEtage(', 'async function doDormirChambre('),c);
 return {c,state,appels,messages,journal,elements};
}
test('#306 tarif affiché 80 FR repris sans repli à 60 FR',async()=>{
 const {c,appels}=scene();
 await c.doReserverChambreHotel(0);
 assert.equal(appels.length,1);
 assert.deepEqual(JSON.parse(JSON.stringify(appels[0])),['chambre','hotel-commerce',[],'service','reserver_chambre_hotel',0,80]);
});
test('#306 ordre absent : aucun achat à 60 FR',async()=>{
 const {c,appels,messages}=scene(null);
 await c.doReserverChambreHotel(0);
 assert.equal(appels.length,0);
 assert.equal(messages[0][1],'tarif_local_introuvable');
});
// 13/11/2026 : le service d'étage passe par UNE fonction serveur (hotel_service_etage_commander),
// qui vérifie la réservation, paie et applique les effets ; l'écran recopie sa réponse.
test('#307 service d’étage : une seule fonction serveur, effets recopiés',async()=>{
 const {c,state,appels}=scene();
 state.currentRoom='chambre';
 c.sbRpcVerdict=async fn=>{appels.push(['rpc',fn]);return {ok:true,prix:150,pa:20,hp:70,moral:41,liquide:850,arg:850,bonus_pa:1};};
 await c.doServiceEtage(0);
 assert.deepEqual(JSON.parse(JSON.stringify(appels)),[['rpc','hotel_service_etage_commander']]);
 assert.equal(state.hp,70);
 assert.equal(state.moral,41);
});
test('#307 refus serveur : pas de bénéfices attribués, refus nommé',async()=>{
 const {c,state,messages}=scene();
 state.currentRoom='chambre';
 c.sbRpcVerdict=async()=>({ok:false,raison:'chambre_non_reservee'});
 await c.doServiceEtage(0);
 assert.equal(state.hp,60);
 assert.equal(state.moral,40);
 assert.match(messages.at(-1)[1],/réserver une chambre/);
});
test('#307 l’écran ne crédite plus rien lui-même',()=>{
 const code=entre(personne,'async function doServiceEtage(', 'async function doDormirChambre(');
 assert.doesNotMatch(code,/pa_bonus_differe_crediter|deduireCoutOrdre|\+ 10\)/);
});
test('#315 les noms de contacts sont échappés dans value et libellé',()=>{
 const html=entre(politique,'function ouvrirModalNommerAmbassadeur(', 'const REFUS_AMBASSADE_MINISTRE');
 const nom='Jean "<img src=x onerror=alert(1)>" & O\'Neil';
 const state={country:'republic',contacts:[{name:nom}]};
 const elements=new Map([['postes-modal-title',{textContent:''}],['postes-body',{innerHTML:''}],['modal-postes',{classList:{add(){}}}]]);
 const c={state,COUNTRIES:{republic:{n:'Républia'},narco:{n:'El Estado'}},
 document:{getElementById:id=>elements.get(id)}};
 vm.createContext(c);vm.runInContext(html,c);c.ouvrirModalNommerAmbassadeur(0,0);
 const out=elements.get('postes-body').innerHTML;
 assert.doesNotMatch(out,/<img(?:\\s|>)/i, 'aucune balise image active');
 assert.ok(out.includes('&lt;img src=x onerror=alert(1)&gt;'), 'le nom hostile demeure uniquement du texte échappé');
 assert.match(out,/Jean &quot;&lt;img/);
 assert.match(out,/&amp; O&#39;Neil/);
});
