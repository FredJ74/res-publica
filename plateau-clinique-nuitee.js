// Clinique privée : réservation libre d'une nuit à l'accueil.
// L'attribution, la facturation et les soins de nuit restent exclusivement côté serveur.
(function(global){'use strict';
function clT(key,fr,vars){return global.RPClinicStayI18n?.text?.(key,fr,vars)||String(fr).replace(/\{([a-z]+)\}/g,(m,k)=>Object.hasOwn(vars||{},k)?String(vars[k]):m)}
function clH(key,fr,vars){return String(clT(key,fr,vars)).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));}
const cliniquePays=()=>typeof state!=='undefined'&&['republic','soviet'].includes(state.country);
function cliniqueDevise(){return state.country==='soviet'?'PSK':'FR';}
function ordresNuiteeClinique(buildingId,roomId){
 if(!cliniquePays()||state.currentCity!=='capitale'||buildingId!=='clinique-privee')return [];
 if(roomId==='reception_clinique')return [{
   fn:'clinique_reserver_nuit',label:clT('reserveLabel',"Réserver une chambre — 150 {currency}",{currency:cliniqueDevise()}),
   pa:0,cost:0,type:'legal',icon:'ti-bed',successRate:100,
   desc:clT('reserveDesc',"Réserver une chambre jusqu’à votre prochain Dormir validé dans celle-ci : 150 {currency}. Même après avoir déjà dormi aujourd’hui, vous pouvez réserver. Le prochain Dormir dans votre chambre apportera +2 PA, +10 Santé et +3 Moral en plus du repos normal.",{currency:cliniqueDevise()})
 }];
 if(/^chambre_(?:[1-9]|10)$/.test(roomId)){
 // Occupant de la chambre : client d'une nuit ou patient hospitalisé (même bail de clinique).
 const occupant=(state.locationsActives||[]).some(l=>l.buildingId==='clinique-privee'
   &&l.roomId===roomId&&l.locataire===state.char?.name);
 const ordres=[{
   fn:'clinique_dormir',label:clT('sleepLabel','Dormir dans la chambre'),
   pa:0,cost:0,type:'legal',icon:'ti-moon',successRate:100,
   desc:clT('sleepDesc','Une seule nuitée payée donne +2 PA, +10 Santé et +3 Moral lors du prochain Dormir validé par le serveur.'),
   // « Sortir de l'hôpital » ne concerne que le patient hospitalisé (relevé de Fred, 13/11/2026).
   masque:state.hospitalisation?[]:['sortie_hopital']
 }];
 // Escorts en clinique (décision de Fred, 13/11/2026) : même standard que les résidences de Novomirsk,
 // ouvert à l'occupant ; le serveur vérifie le bail et ne propose que les deux escorts des cliniques.
 if(occupant)ordres.push({
   fn:'escort_standard',label:clT('escortLabel','Appel à un(e) escort'),
   pa:0,cost:0,type:'legal',icon:'ti-phone-call',successRate:100,
   desc:clT('escortDesc','Le standard de l’agence internationale Roxane Velours. 800 {currency} par escort et par jour, jusqu’à ce que vous rompiez le contrat. Légal, mais immoral : la rumeur coûte cher.',{currency:cliniqueDevise()})
 });
 return ordres;
 }
 return [];
}
(global.RP_ORDRES_DYNAMIQUES=global.RP_ORDRES_DYNAMIQUES||[]).push(ordresNuiteeClinique);
const REFUS={
 non_authentifie:'Connectez-vous pour réserver.',pas_a_accueil:'Présentez-vous à l’accueil de la clinique.',
 deja_hospitalise:'Vous disposez déjà d’une chambre au titre de votre hospitalisation.',
 indisponible:'Votre situation actuelle ne permet pas de réserver.',
 complet:'Les dix chambres sont occupées.'
};
let reservationEnCours=false;
function reserverNuiteeClinique(){
 if(reservationEnCours)return;
 if(!cliniquePays()||state.currentCity!=='capitale'||state.currentBuilding!=='clinique-privee'
   ||state.currentRoom!=='reception_clinique')return;
 const modal=document.getElementById('modal-postes');
 const titre=document.getElementById('postes-modal-title');
 const corps=document.getElementById('postes-body');
 if(!modal||!titre||!corps){
  showToast('Réservation indisponible','La fenêtre de réservation ne peut pas être affichée.',false);
  return;
 }
 const cur=cliniqueDevise();
 titre.textContent=clT('title','Réserver une chambre à la clinique');
 corps.innerHTML=
  '<div id="clinique-nuitee-confirmation" style="padding:1.25rem 1.4rem;color:#d7d0be">'
 +'<div style="font-size:1.03rem;color:#eac67a;margin-bottom:.85rem">'+clH('oneNight','Une nuit en chambre privée')+'</div>'
 +'<p style="line-height:1.65;margin:0 0 .75rem">'+clH('rateIntro','Tarif : ')+'<strong>150 '+cur+clH('rateNight',' par nuit')+'</strong>'+clH('rateCharge',', prélevés lors de la réservation.')+'</p>'
 +'<p style="line-height:1.65;margin:0 0 .75rem">'+clH('benefitIntro','En dormant dans votre chambre : ')+'<strong>'+clH('benefitStrong','+2 PA, +10 Santé et +3 Moral')+'</strong>'+clH('benefitEnd',', en plus des effets du sommeil habituel et dans la limite des plafonds.')+'</p>'
 +'<p style="color:#a69b86;font-size:.83rem;margin:0 0 1.2rem">'+clH('terms','La chambre est attribuée selon les disponibilités et reste réservée tant que vous n’avez pas effectué l’ordre Dormir dans cette chambre. Vous pouvez réserver même si vous avez déjà dormi aujourd’hui ; les bonus seront accordés lors de votre prochain sommeil autorisé.')+'</p>'
 +'<div style="display:flex;flex-wrap:wrap;gap:.65rem;justify-content:flex-end">'
 +'<button type="button" id="clinique-annuler-reservation" style="padding:.65rem 1rem;background:transparent;color:#c9b99a;border:1px solid #64543b;cursor:pointer">'+clH('cancel','Annuler')+'</button>'
 +'<button type="button" id="clinique-confirmer-reservation" style="padding:.65rem 1rem;background:#493615;color:#ffe4a8;border:1px solid #a37d35;cursor:pointer">'+clH('confirmButton','Confirmer la réservation — 150 {currency}',{currency:cur})+'</button>'
 +'</div></div>';
 corps.querySelector('#clinique-annuler-reservation')?.addEventListener('click',()=>modal.classList.remove('open'));
 corps.querySelector('#clinique-confirmer-reservation')?.addEventListener('click',()=>{void confirmerReservationNuiteeClinique();});
 modal.classList.add('open');
}
async function confirmerReservationNuiteeClinique(){
 if(reservationEnCours)return;
 if(!cliniquePays()||state.currentCity!=='capitale'||state.currentBuilding!=='clinique-privee'
   ||state.currentRoom!=='reception_clinique')return;
 const bouton=document.getElementById('clinique-confirmer-reservation');
 if(bouton){bouton.disabled=true;bouton.textContent=clT('checking','Vérification auprès de la clinique…');}
 reservationEnCours=true;
 const acteur=state.char?.name,pays=state.country;
 try{
  const brut=typeof sbRpcVerdict==='function'
   ?await sbRpcVerdict('clinique_nuitee_reserver',{}).catch(()=>null)
   :await sbRpc('clinique_nuitee_reserver',{}).catch(()=>null);
  const r=Array.isArray(brut)?brut[0]:brut;
  if(!r||r.transport){
   showToast(clT('unconfirmed','Réservation non confirmée'),clT('uncertain','Vérifiez votre chambre avant de réessayer : aucun second paiement automatique.'),false);return;
  }
  if(!r.ok){
   showToast(clT('refused','Réservation refusée'),(r.raison==='fonds_insuffisants'?clT('insufficient','Il vous faut 150 {currency} pour cette nuit.',{currency:cliniqueDevise()}):REFUS[r.raison])||'Le serveur a refusé la réservation.',false);return;
  }
  if(state.char?.name!==acteur||state.country!==pays)return;
  if(typeof r.liquide==='number')state.liquide=r.liquide;
  if(typeof r.arg==='number'){state.arg=r.arg;if(state.char)state.char.arg=r.arg;}
  if(typeof updateUI==='function')updateUI();
  if(typeof chargerLocations==='function')await chargerLocations();
  document.getElementById('modal-postes')?.classList.remove('open');
  showToast(clT('booked','Chambre réservée'),
    clT('bookedDetails','Chambre {number} : 150 {currency} réglés. Réservation valable jusqu’à votre prochain Dormir dans la chambre.',{number:r.chambre.replace('chambre_',''),currency:cliniqueDevise()}),true);
  if(state.char?.name===acteur&&state.country===pays
    &&state.currentBuilding==='clinique-privee'&&state.currentRoom==='reception_clinique'
    &&typeof enterRoom==='function')enterRoom('clinique-privee',r.chambre,null);
 }finally{
  reservationEnCours=false;
  const bouton=document.getElementById('clinique-confirmer-reservation');
  if(bouton){bouton.disabled=false;bouton.textContent=clT('confirmButton','Confirmer la réservation — 150 {currency}',{currency:cliniqueDevise()});}
 }
}
// Appelée APRÈS le repos normal. Depuis le 13/11/2026, le serveur crédite la nuitée dans le
// sommeil lui-même (déclencheur clinique_nuitee_marquer_repos) : cet appel ne fait plus que relire
// le résultat (réponse « rejeu ») pour l'afficher. Une coupure réseau ne fait donc plus rien perdre.
async function consommerNuiteeCliniqueApresDormir(nomInitial,paysInitial,pieceInitial){
 if(!['republic','soviet'].includes(paysInitial)||!/^chambre_(?:[1-9]|10)$/.test(pieceInitial))return;
 if(state.char?.name!==nomInitial||state.country!==paysInitial
   ||state.currentBuilding!=='clinique-privee'||state.currentRoom!==pieceInitial)return;
 const maChambre=(typeof getChambreAttribueeClinique==='function')?getChambreAttribueeClinique(nomInitial):null;
 if(!maChambre||maChambre.roomId!==pieceInitial||maChambre.reservationClinique!==true)return;
 const brut=await sbRpc('clinique_nuitee_consommer',{}).catch(()=>null);
 const r=Array.isArray(brut)?brut[0]:brut;
 if(!r||r.transport||!r.ok)return;
 if(state.char?.name!==nomInitial||state.country!==paysInitial)return;
 if(typeof r.pa==='number')state.pa=r.pa;
 if(typeof r.hp==='number')state.hp=r.hp;
 if(typeof r.moral==='number')state.moral=r.moral;
 if(typeof updateUI==='function')updateUI();
 showToast(clT('night','Nuit à la clinique'),clT('bonus','+2 PA, +10 Santé, +3 Moral (plafonds habituels).'),true);
 if(typeof addJournalEntry==='function')addJournalEntry('Nuit à la clinique privée : +2 PA, +10 Santé, +3 Moral.','event-good');
 if(typeof chargerLocations==='function')await chargerLocations();
}
global.reserverNuiteeClinique=reserverNuiteeClinique;
global.consommerNuiteeCliniqueApresDormir=consommerNuiteeCliniqueApresDormir;
(global.RP_I18N_CHANGE_CALLBACKS=global.RP_I18N_CHANGE_CALLBACKS||[]).push(function(){
 const modal=document.getElementById('modal-postes'),corps=document.getElementById('postes-body');
 if(!reservationEnCours&&modal?.classList?.contains('open')
   &&corps?.querySelector?.('#clinique-nuitee-confirmation')
   &&state.currentBuilding==='clinique-privee'&&state.currentRoom==='reception_clinique'){
  // Aucun champ ni paiement n'est recréé ; il s'agit seulement d'une confirmation.
  reserverNuiteeClinique();
 }
});
})(window);
