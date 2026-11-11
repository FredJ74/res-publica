// Facade de la carte et des invitations EXISTANTES. Aucun moteur de paiement ou de stock ici.
function restaurantTexte(cle,fr,vars){
 const t=window.RPSharedSalesDinnerI18n?.text;
 return typeof t==='function'?t(cle,fr,vars):String(fr).replace(/\{([a-z]+)\}/g,(m,k)=>Object.hasOwn(vars||{},k)?String(vars[k]):m);
}
function restaurantLutheciaIci() {
  return state.country==='republic'&&state.currentCity==='capitale'&&state.currentBuilding==='hotel-republica'&&state.currentRoom==='restaurant';
}
// #379 (03/11/2026) : le diner d'affaires du Capitaine Sauvage (PSM) passe par les MEMES portes
// serveur (contrat commerce_v1, migration 20261103235800). Seuls changent la carte et le prix.
function restaurantDinerContratIci() {
  return restaurantLutheciaIci()||(state.country==='republic'&&state.currentCity==='ville_a'&&state.currentBuilding==='capitaine-sauvage'&&state.currentRoom==='salle_principale')
    // Grand Hotel de Sovarka (Novomirsk), 100 PSK (07/11/2026).
    ||(state.country==='soviet'&&state.currentCity==='capitale'&&state.currentBuilding==='hotel-republica'&&state.currentRoom==='restaurant');
}
function restaurantLutheciaCarte(data,pays,ville,batiment,piece) {
  if(!data||pays!=='republic'||ville!=='capitale'||batiment!=='hotel-republica') return data;
  if(state.country!==pays||state.currentCity!==ville||state.currentBuilding!==batiment) return data;
  const room=piece||state.currentRoom;
  if(!['restaurant','bar'].includes(room)) return data;
  if(data.versionGastronomieLuthecia!==1||!Array.isArray(data.cartesParPiece?.[room])) {
    showToast(restaurantTexte('menuUpdating','Carte en cours de mise à jour'),restaurantTexte('menuNotConfirmed','La nouvelle carte doit être confirmée par le serveur. Aucun paiement effectué.'),false);
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
  catch(_){if(valide())showToast(restaurantTexte('dinnerUnconfirmed','Dîner non confirmé'),restaurantTexte('dinnerUncertain','La réponse est incertaine. Réessayez le même ordre pour relire son résultat.'),false);}
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
    if(v?.ok!==true){showToast(restaurantTexte('invitationUnconfirmed','Invitation non confirmée'),restaurantTexte('invitationNotConfirmed','Le serveur n’a pas confirmé ce dîner. Aucun succès annoncé.'),false);return;}
    try{sessionStorage.removeItem(stockage);}catch(_){}RP_RESTAURANT_REQUETES.delete(signature);
    document.getElementById('modal-postes')?.classList.remove('open');
    state._restaurantLutheciaSuivi=true;
    showToast(v.statut==='refusee'?restaurantTexte('invitationRefused','Invitation refusée'):restaurantTexte('invitationRecorded','Invitation enregistrée'),v.statut==='refusee'?restaurantTexte('noPayment','Aucun paiement effectué.'):restaurantTexte('dinnerAfterAcceptance','Le dîner sera servi et facturé uniquement après acceptation et confirmation serveur.'),v.statut!=='refusee');
    await restaurantLutheciaSuivre(true);
  });
}
const RP_RESTAURANT_REQUETES=new Map();
async function restaurantLutheciaRepondre(id,accepte) {
  return restaurantLutheciaActe('repondre:'+id,async(c,valide)=>{
    const message=(document.getElementById('invitation-reponse-input')?.value||'').trim().slice(0,200);
    const v=await sbRpcVerdict('restaurant_diner_repondre',{p_invitation:id,p_accepte:!!accepte,p_reponse:message},{encoreValide:valide});
    if(!valide())return;
    if(v?.ok!==true){showToast(restaurantTexte('replyUnconfirmed','Réponse non confirmée'),restaurantTexte('replyRetry','Votre réponse n’a pas été confirmée. Réessayez.'),false);return;}
    state._restaurantLutheciaSuivi=true;
    state._invitationSocialeModalOuvert=false;state._invitationSocialeCourante=null;
    document.getElementById('modal-postes')?.classList.remove('open');
    showToast(accepte?restaurantTexte('invitationAccepted','Invitation acceptée'):restaurantTexte('invitationRefused','Invitation refusée'),accepte?restaurantTexte('dinnerAfterConfirmation','Le dîner sera servi après confirmation du restaurant.'):restaurantTexte('noDinnerCharged','Aucun dîner facturé.'),accepte);
    // Aucun effet ici. Le service atomique applique les effets aux deux convives.
  });
}
async function restaurantLutheciaSuivre(force=false) {
  if(!force&&!state._restaurantLutheciaSuivi&&!restaurantDinerContratIci())return;
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
      showToast(resultat.ok?restaurantTexte('dinnerServed','Dîner servi'):restaurantTexte('dinnerNotServed','Dîner non servi'),resultat.ok?restaurantTexte('mealServed','Deux repas et {drinks} servis ; {total} FR facturés une seule fois à l’organisateur.',{drinks:resultat.champagnes?restaurantTexte('champagnes','deux champagnes'):restaurantTexte('wine','une bouteille de vin'),total:resultat.total}):restaurantTexte('mealDeclined','Le serveur a refusé le service : aucun débit ni consommation partielle.'),!!resultat.ok);
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
  return ordre?[{...ordre,desc:restaurantTexte('dinnerOrderDesc','Après acceptation : deux repas gastronomiques et deux verres de champagne pour 300 FR. 2 PA. +10 Santé, +2 Moral, +5 INF et +3 PA au prochain Dormir pour chaque convive. Aucun paiement si refus ou service impossible.'),masque:['produire_commerce']}]:[];
}
if(typeof window!=='undefined'){
  window.RP_ORDRES_DYNAMIQUES=window.RP_ORDRES_DYNAMIQUES||[];
  if(!window.RP_ORDRES_DYNAMIQUES.includes(ordresRestaurantLuthecia))window.RP_ORDRES_DYNAMIQUES.push(ordresRestaurantLuthecia);
}
