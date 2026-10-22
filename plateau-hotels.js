// Droits de nuits : projection du champ serveur existant, aucune sauvegarde locale d'attribution.
let hotelAchatEnCours=false;
function hotelNuitsDisponibles(v=state.char?.reservationHotel){
 if(v?.version===2&&Array.isArray(v.nuits))return v.nuits;
 return v?.buildingId?[{...v,source:'legacy'}]:[];
}
function hotelReservationCourante(){return hotelNuitsDisponibles().find(n=>n.buildingId===state.currentBuilding&&(n.source==='legacy'||n.pays===state.country&&n.ville===state.currentCity));}
function hotelReservationsFiche(){
 const ech=t=>String(t??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 const groupes=new Map();for(const n of hotelNuitsDisponibles()){const cle=JSON.stringify([n.pays,n.ville,n.buildingId,n.bonus]);const g=groupes.get(cle)||{n,nb:0};g.nb++;groupes.set(cle,g);}
 return '<section class="cs-section"><div class="cs-title">Réservations d’hôtel</div>'+(groupes.size?[...groupes.values()].map(({n,nb})=>'<p>'+ech(BUILDINGS[n.buildingId]?.shortName||n.buildingId)+' · '+ech(n.ville?(WORLD?.[n.pays]?.[n.ville]?.name||n.ville):'Ville historique non renseignée')+' : '+nb+' nuit(s)<br>Bonus : +'+ech(n.bonus?.paBonus)+' PA, +'+ech(n.bonus?.moral)+' Moral. Valable jusqu’à utilisation.</p>').join(''):'<p>Aucune nuit en attente.</p>')+'</section>';
}
function hotelCleAchat(c){return 'hotel-reservation:'+JSON.stringify([c.uid,c.nom,c.pays,c.ville,c.batiment]);}
async function hotelReserverChambre(){
 if(hotelAchatEnCours)return;const c=contexteNavigationRue(),cle=hotelCleAchat(c);let id;
 try{id=sessionStorage.getItem(cle)||crypto.randomUUID();sessionStorage.setItem(cle,id);}catch(_){showToast('Réservation non lancée','La reprise sûre de cet achat ne peut pas être enregistrée.',false);return;}
 hotelAchatEnCours=true;
 try{
  const v=await sbRpcVerdict('hotel_reserver',{p_requete:id,p_batiment:c.batiment}).catch(()=>null);
  if(!contexteNavigationRueValide(c))return;
  if(!v?.ok){if(v&&!v.transport)sessionStorage.removeItem(cle);showToast('Réservation non confirmée',v?.transport?'Réponse incertaine. Réessayez : le même achat sera vérifié sans second paiement.':'Le serveur n’a pas autorisé cette réservation.',false);return;}
  sessionStorage.removeItem(cle);state.char.reservationHotel=v.reservation_hotel;
  const f=typeof rafraichirRuntimeHelvetia==='function'?await rafraichirRuntimeHelvetia():null;
  if(!contexteNavigationRueValide(c))return;if(typeof f?.pa==='number')state.pa=f.pa;
  updateUI();showToast(v.rejeu?'Réservation confirmée':'Chambre réservée','Votre nuit reste disponible jusqu’à son utilisation. Les autres réservations sont conservées.',true);
  if(typeof queteAccueilApresReservationChambre==='function')queteAccueilApresReservationChambre();
 }finally{hotelAchatEnCours=false;}
}
async function hotelReservationsReconcilier(){
 const c=contexteNavigationRue(),cle=hotelCleAchat(c);let id;try{id=sessionStorage.getItem(cle);}catch(_){return;}
 const v=await sbRpcVerdict('hotel_reservations_lire',{p_requete:id||null}).catch(()=>null);
 if(!contexteNavigationRueValide(c)||!v?.ok)return false;
 state.char.reservationHotel=v.reservation_hotel;if(id&&v.termine)sessionStorage.removeItem(cle);return true;
}
