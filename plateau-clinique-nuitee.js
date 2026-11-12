// Clinique privée : réservation libre d'une nuit à l'accueil.
// L'attribution, la facturation et les soins de nuit restent exclusivement côté serveur.
(function(global){'use strict';
const cliniquePays=()=>typeof state!=='undefined'&&['republic','soviet'].includes(state.country);
function cliniqueDevise(){return state.country==='soviet'?'PSK':'FR';}
function ordresNuiteeClinique(buildingId,roomId){
 if(!cliniquePays()||state.currentCity!=='capitale'||buildingId!=='clinique-privee')return [];
 if(roomId==='reception_clinique')return [{
   fn:'clinique_reserver_nuit',label:'Réserver une chambre — 150 '+cliniqueDevise(),
   pa:0,cost:0,type:'legal',icon:'ti-bed',successRate:100,
   desc:'Réserver et payer une nuit à la clinique : 150 '+cliniqueDevise()
    +'. Dans votre chambre, Dormir apporte +2 PA, +10 Santé et +3 Moral en plus du repos normal.'
 }];
 if(/^chambre_(?:[1-9]|10)$/.test(roomId)){
 const propre=(state.locationsActives||[]).some(l=>l.buildingId==='clinique-privee'
   &&l.roomId===roomId&&l.locataire===state.char?.name&&l.reservationClinique===true);
 return [{
   fn:'clinique_dormir',label:'Dormir dans la chambre',
   pa:0,cost:0,type:'legal',icon:'ti-moon',successRate:100,
   desc:'Une seule nuitée payée donne +2 PA, +10 Santé et +3 Moral lors du prochain Dormir validé par le serveur.'
 }].concat(propre?[{
   fn:'clinique_verifier_bonus',label:'Vérifier les bonus de la nuit',
   pa:0,cost:0,type:'legal',icon:'ti-check',successRate:100,
   desc:'Après Dormir, vérifier les bonus de nuitée auprès du serveur. Aucun bonus n’est accordé deux fois.'
 }]:[]);
 }
 return [];
}
(global.RP_ORDRES_DYNAMIQUES=global.RP_ORDRES_DYNAMIQUES||[]).push(ordresNuiteeClinique);
const REFUS={
 non_authentifie:'Connectez-vous pour réserver.',pas_a_accueil:'Présentez-vous à l’accueil de la clinique.',
 deja_hospitalise:'Vous disposez déjà d’une chambre au titre de votre hospitalisation.',
 deja_dormi:'Vous avez déjà dormi aujourd’hui. Revenez après le changement de jour.',
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
 titre.textContent='Réserver une chambre à la clinique';
 corps.innerHTML=
  '<div id="clinique-nuitee-confirmation" style="padding:1.25rem 1.4rem;color:#d7d0be">'
 +'<div style="font-size:1.03rem;color:#eac67a;margin-bottom:.85rem">Une nuit en chambre privée</div>'
 +'<p style="line-height:1.65;margin:0 0 .75rem">Tarif : <strong>150 '+cur
 +' par nuit</strong>, prélevés lors de la réservation.</p>'
 +'<p style="line-height:1.65;margin:0 0 .75rem">En dormant dans votre chambre : <strong>+2 PA, +10 Santé et +3 Moral</strong>, en plus des effets du sommeil habituel et dans la limite des plafonds.</p>'
 +'<p style="color:#a69b86;font-size:.83rem;margin:0 0 1.2rem">La chambre est attribuée selon les disponibilités.</p>'
 +'<div style="display:flex;flex-wrap:wrap;gap:.65rem;justify-content:flex-end">'
 +'<button type="button" id="clinique-annuler-reservation" style="padding:.65rem 1rem;background:transparent;color:#c9b99a;border:1px solid #64543b;cursor:pointer">Annuler</button>'
 +'<button type="button" id="clinique-confirmer-reservation" style="padding:.65rem 1rem;background:#493615;color:#ffe4a8;border:1px solid #a37d35;cursor:pointer">Confirmer la réservation — 150 '+cur+'</button>'
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
 if(bouton){bouton.disabled=true;bouton.textContent='Vérification auprès de la clinique…';}
 reservationEnCours=true;
 const acteur=state.char?.name,pays=state.country;
 try{
  const brut=typeof sbRpcVerdict==='function'
   ?await sbRpcVerdict('clinique_nuitee_reserver',{}).catch(()=>null)
   :await sbRpc('clinique_nuitee_reserver',{}).catch(()=>null);
  const r=Array.isArray(brut)?brut[0]:brut;
  if(!r||r.transport){
   showToast('Réservation non confirmée','Vérifiez votre chambre avant de réessayer : aucun second paiement automatique.',false);return;
  }
  if(!r.ok){
   showToast('Réservation refusée',(r.raison==='fonds_insuffisants'?'Il vous faut 150 '+cliniqueDevise()+' pour cette nuit.':REFUS[r.raison])||'Le serveur a refusé la réservation.',false);return;
  }
  if(state.char?.name!==acteur||state.country!==pays)return;
  if(typeof r.liquide==='number')state.liquide=r.liquide;
  if(typeof r.arg==='number'){state.arg=r.arg;if(state.char)state.char.arg=r.arg;}
  if(typeof updateUI==='function')updateUI();
  if(typeof chargerLocations==='function')await chargerLocations();
  document.getElementById('modal-postes')?.classList.remove('open');
  showToast('Chambre réservée',r.chambre.replace('chambre_','Chambre ')
    +' : une nuit réglée pour 150 '+cliniqueDevise()+'.',true);
  if(state.char?.name===acteur&&state.country===pays
    &&state.currentBuilding==='clinique-privee'&&state.currentRoom==='reception_clinique'
    &&typeof enterRoom==='function')enterRoom('clinique-privee',r.chambre,null);
 }finally{
  reservationEnCours=false;
  const bouton=document.getElementById('clinique-confirmer-reservation');
  if(bouton){bouton.disabled=false;bouton.textContent='Confirmer la réservation — 150 '+cliniqueDevise();}
 }
}
// Appelée APRÈS la sauvegarde du repos normal : le serveur constate la même nuit
// et attribue, au plus une fois, le bonus de la réservation réellement payée.
async function consommerNuiteeCliniqueApresDormir(nomInitial,paysInitial,pieceInitial){
 if(!['republic','soviet'].includes(paysInitial)||!/^chambre_(?:[1-9]|10)$/.test(pieceInitial))return;
 if(state.char?.name!==nomInitial||state.country!==paysInitial
   ||state.currentBuilding!=='clinique-privee'||state.currentRoom!==pieceInitial)return;
 const maChambre=(typeof getChambreAttribueeClinique==='function')?getChambreAttribueeClinique(nomInitial):null;
 if(!maChambre||maChambre.roomId!==pieceInitial||maChambre.reservationClinique!==true)return;
 const brut=await sbRpc('clinique_nuitee_consommer',{}).catch(()=>null);
 const r=Array.isArray(brut)?brut[0]:brut;
 if(!r||r.transport){
  showToast('Nuitée à confirmer','Le repos est enregistré mais les bonus de clinique restent à vérifier auprès du serveur.',false);
  return;
 }
 if(!r.ok){
  if(r.raison==='aucune_reservation')return;
  showToast('Bonus de clinique non appliqué',r.raison==='repos_non_valide'
    ?'Dormez d’abord dans la chambre réservée pour obtenir ces bonus.'
    :(r.raison||'Réponse du serveur indisponible.'),false);
  return;
 }
 if(state.char?.name!==nomInitial||state.country!==paysInitial)return;
 if(typeof r.pa==='number')state.pa=r.pa;
 if(typeof r.hp==='number')state.hp=r.hp;
 if(typeof r.moral==='number')state.moral=r.moral;
 if(typeof updateUI==='function')updateUI();
 if(!r.rejeu){
  showToast('Nuit à la clinique','+2 PA, +10 Santé, +3 Moral (plafonds habituels).',true);
  if(typeof addJournalEntry==='function')addJournalEntry('Nuit à la clinique privée : +2 PA, +10 Santé, +3 Moral.','event-good');
 }
 if(typeof chargerLocations==='function')await chargerLocations();
}
global.verifierNuiteeClinique=function(){
 const acteur=state.char?.name, pays=state.country, piece=state.currentRoom;
 if(!acteur)return;
 return consommerNuiteeCliniqueApresDormir(acteur,pays,piece);
};
global.reserverNuiteeClinique=reserverNuiteeClinique;
global.consommerNuiteeCliniqueApresDormir=consommerNuiteeCliniqueApresDormir;
})(window);
