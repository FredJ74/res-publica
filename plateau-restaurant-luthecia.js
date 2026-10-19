// Facade de la carte et des invitations EXISTANTES. Aucun moteur de paiement ou de stock ici.
function restaurantLutheciaIci() {
  return state.country==='republic'&&state.currentCity==='capitale'&&state.currentBuilding==='hotel-republica'&&state.currentRoom==='restaurant';
}
function restaurantLutheciaCarte(data,pays,ville,batiment,piece) {
  if(!data||pays!=='republic'||ville!=='capitale'||batiment!=='hotel-republica') return data;
  if(state.country!==pays||state.currentCity!==ville||state.currentBuilding!==batiment) return data;
  const room=piece||state.currentRoom;
  if(!['restaurant','bar'].includes(room)) return data;
  if(data.versionGastronomieLuthecia!==1||!Array.isArray(data.cartesParPiece?.[room])) {
    showToast('Carte en cours de mise à jour','La nouvelle carte doit être confirmée par le serveur. Aucun paiement effectué.',false);
    return null;
  }
  // Copie de presentation seulement. L'entreprise et ses stocks ne sont jamais recopies ni scindes.
  return {...data,carte:[...data.cartesParPiece[room]]};
}
const RP_RESTAURANT_ACTES=new Set();
async function restaurantLutheciaActe(cle,executer) {
  if(RP_RESTAURANT_ACTES.has(cle)) return;
  RP_RESTAURANT_ACTES.add(cle);
  const contexte=contexteNavigationRue();
  const valide=()=>contexteNavigationRueValide(contexte);
  try{return await executer(contexte,valide);}
  catch(_){if(valide())showToast('Dîner non confirmé','La réponse est incertaine. Réessayez le même ordre pour relire son résultat.',false);}
  finally{RP_RESTAURANT_ACTES.delete(cle);}
}
async function restaurantLutheciaInviter(nomInvite,estPJ) {
  return restaurantLutheciaActe('inviter',async(c,valide)=>{
    const message=(document.getElementById('invitation-message-input')?.value||'').trim().slice(0,200);
    const signature=JSON.stringify([c.uid,c.nom,nomInvite,!!estPJ,message]);
    const stockage='restaurant_luthecia:'+signature;
    let requete=RP_RESTAURANT_REQUETES.get(signature);
    try {requete=requete||sessionStorage.getItem(stockage);} catch(_){}
    requete=requete||'diner-'+crypto.randomUUID();RP_RESTAURANT_REQUETES.set(signature,requete);
    try{sessionStorage.setItem(stockage,requete);}catch(_){}
    const v=await sbRpcVerdict('restaurant_diner_creer',{p_requete:requete,p_invite:nomInvite,p_pnj:!estPJ,p_message:message},{encoreValide:valide});
    if(!valide())return;
    if(v?.ok!==true){showToast('Invitation non confirmée','Le serveur n’a pas confirmé ce dîner. Aucun succès annoncé.',false);return;}
    try{sessionStorage.removeItem(stockage);}catch(_){}RP_RESTAURANT_REQUETES.delete(signature);
    document.getElementById('modal-postes')?.classList.remove('open');
    state._restaurantLutheciaSuivi=true;
    showToast(v.statut==='refusee'?'Invitation refusée':'Invitation enregistrée',v.statut==='refusee'?'Aucun paiement effectué.':'Deux repas et deux champagnes seront servis uniquement après acceptation et confirmation serveur.',v.statut!=='refusee');
    await restaurantLutheciaSuivre(true);
  });
}
const RP_RESTAURANT_REQUETES=new Map();
async function restaurantLutheciaRepondre(id,accepte) {
  return restaurantLutheciaActe('repondre:'+id,async(c,valide)=>{
    const message=(document.getElementById('invitation-reponse-input')?.value||'').trim().slice(0,200);
    const v=await sbRpcVerdict('restaurant_diner_repondre',{p_invitation:id,p_accepte:!!accepte,p_reponse:message},{encoreValide:valide});
    if(!valide())return;
    if(v?.ok!==true){showToast('Réponse non confirmée','Votre réponse n’a pas été confirmée. Réessayez.',false);return;}
    state._restaurantLutheciaSuivi=true;
    state._invitationSocialeModalOuvert=false;state._invitationSocialeCourante=null;
    document.getElementById('modal-postes')?.classList.remove('open');
    showToast(accepte?'Invitation acceptée':'Invitation refusée',accepte?'Le dîner sera servi après confirmation du restaurant.':'Aucun dîner facturé.',accepte);
    // Aucun effet ici. Le service atomique applique les effets aux deux convives.
  });
}
async function restaurantLutheciaSuivre(force=false) {
  if(!force&&!state._restaurantLutheciaSuivi&&!restaurantLutheciaIci())return;
  return restaurantLutheciaActe('suivre',async(c,valide)=>{
    const liste=await sbRpcVerdict('restaurant_diner_suivre',{}, {encoreValide:valide});
    if(!valide()||liste?.ok!==true||!Array.isArray(liste.invitations))return;
    for(const invitation of liste.invitations){
      let resultat=invitation.resultat_service;
      if(!resultat&&invitation.inviteur===c.nom&&invitation.statut==='acceptee') {
        resultat=await sbRpcVerdict('restaurant_diner_servir',{p_invitation:invitation.id},{encoreValide:valide});
        if(!valide())return;
        if(!resultat||resultat.transport)continue; // Le prochain sondage relira le recu persiste.
      }
      if(!resultat)continue;
      const relu=await commercePjActualiserPersonnage({social:true});
      if(!valide())return;
      if(!relu)continue;
      updateUI();
      const acquit=await sbRpcVerdict('restaurant_diner_acquitter',{p_invitation:invitation.id},{encoreValide:valide});
      if(!valide())return;
      if(acquit?.ok!==true||acquit.rejeu)continue;
      showToast(resultat.ok?'Dîner servi':'Dîner non servi',resultat.ok?'Deux repas et deux champagnes servis ; 300 FR facturés une seule fois à l’organisateur.':'Le serveur a refusé le service : aucun débit ni consommation partielle.',!!resultat.ok);
      if(resultat.ok&&typeof tracerActionPourRumeur==='function')tracerActionPourRumeur('diner_affaires_accepte',invitation.invite);
      if(resultat.ok&&invitation.inviteur===c.nom&&typeof advanceTime==='function')advanceTime(2);
    }
  });
}

// Le registre d'ordres existant remplace seulement la presentation de CE diner.
// Le gabarit partage des autres hotels, ses couts et ses handlers restent intacts.
function ordresRestaurantLuthecia(buildingId,roomId) {
  if(state.country!=='republic'||state.currentCity!=='capitale'||buildingId!=='hotel-republica'||roomId!=='restaurant')return [];
  const ordre=BUILDINGS[buildingId]?.rooms?.[roomId]?.orders?.find(o=>o.fn==='diner_affaires');
  return ordre?[{...ordre,desc:'Après acceptation : deux repas gastronomiques et deux verres de champagne pour 300 FR. 2 PA. +10 Santé, +2 Moral, +5 INF et +3 PA au prochain Dormir pour chaque convive. Aucun paiement si refus ou service impossible.',masque:['produire_commerce']}]:[];
}
if(typeof window!=='undefined'){
  window.RP_ORDRES_DYNAMIQUES=window.RP_ORDRES_DYNAMIQUES||[];
  if(!window.RP_ORDRES_DYNAMIQUES.includes(ordresRestaurantLuthecia))window.RP_ORDRES_DYNAMIQUES.push(ordresRestaurantLuthecia);
}
