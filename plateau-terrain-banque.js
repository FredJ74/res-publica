// Reprise des moteurs terrain et banque existants, jamais de debit ni de remboursement client.
let finance135EnCours=false;
function finance135Cle(domaine,cible,c=contexteNavigationRue()) {return 'finance135:'+JSON.stringify([c.uid,c.nom,state.country,domaine,cible]);}
async function finance135Relire(domaine,cible,c) {
 const [fiche,terrain]=await Promise.all([rafraichirRuntimeHelvetia({exigerComptes:true}).catch(()=>null),domaine==='acquisition'?sbGetTerrainState(state.country,cible).catch(()=>null):Promise.resolve(true)]);
 if(!contexteNavigationRueValide(c)||!fiche||!terrain)return false;
 if(typeof fiche.pa==='number'){state.pa=fiche.pa;state.char.pa=fiche.pa;}
 if(domaine==='acquisition')remplacerTerrainState(cible,terrain);
 updateUI();return true;
}
async function finance135Executer(domaine,cible,parametres) {
 if(finance135EnCours)return null;
 const c=contexteNavigationRue(),cle=finance135Cle(domaine,cible,c);let i;
 try{
  i=JSON.parse(sessionStorage.getItem(cle)||'null')||{requete:crypto.randomUUID(),parametres,domaine,cible};
  if(JSON.stringify(i.parametres)!==JSON.stringify(parametres)){
   constructionFenetre('Opération en attente',constructionBouton('Vérifier l’opération précédente','finance135Reprendre('+JSON.stringify(cle)+')'));return null;
  }
  sessionStorage.setItem(cle,JSON.stringify(i));
 }catch(_){showToast('Opération non lancée','La reprise sûre ne peut pas être conservée.',false);return null;}
 finance135EnCours=true;
 try{
  let r;try{
   // Signatures explicites : le contrôle d’autorité vérifie noms ET paramètres transmis.
   if(domaine==='pret')r=await sbRpcVerdict('pret_national_contracter_versionne',{
    p_montant:i.parametres.p_montant,p_duree_jours:i.parametres.p_duree_jours,
    p_type_pret:i.parametres.p_type_pret,p_building_id:i.parametres.p_building_id,p_requete:i.requete});
   else r=await sbRpcVerdict('terrain_acquisition_commande',{
    p_terrain:i.parametres.p_terrain,p_action:i.parametres.p_action,
    p_parametres:i.parametres.p_parametres,p_requete:i.requete});
  }catch(_){r=null;}
  if(!contexteNavigationRueValide(c))return null;
  if(!r?.ok){
   if(r&&!r.transport){await finance135Relire(domaine,cible,c);if(!contexteNavigationRueValide(c))return null;sessionStorage.removeItem(cle);}
   showToast('Opération non confirmée',r?.transport||!r?'Réponse incertaine : vérifiez la même opération, sans nouveau paiement.':(r.raison||'Refus du serveur.'),false);return null;
  }
  if(!await finance135Relire(domaine,cible,c)){if(contexteNavigationRueValide(c))showToast('Opération enregistrée','La relecture reste à confirmer. La reprise est conservée.',true);return null;}
  sessionStorage.removeItem(cle);return r;
 }finally{finance135EnCours=false;}
}
async function finance135Reprendre(cle){
 const c=contexteNavigationRue();let i;try{i=JSON.parse(sessionStorage.getItem(cle)||'null');}catch(_){return;}
 if(!i||cle!==finance135Cle(i.domaine,i.cible,c))return;
 return finance135Executer(i.domaine,i.cible,i.parametres);
}
let finance135Reconciliation=false;
async function finance135Reconcilier(){
 if(finance135Reconciliation||finance135EnCours)return;
 const c=contexteNavigationRue();finance135Reconciliation=true;
 try{
  for(let n=0;n<sessionStorage.length;n++){
   const cle=sessionStorage.key(n);if(!cle?.startsWith('finance135:'))continue;
   let i;try{i=JSON.parse(sessionStorage.getItem(cle)||'null');}catch(_){continue;}
   if(!i||cle!==finance135Cle(i.domaine,i.cible,c))continue;
   const r=await sbRpcVerdict('finance_terrain_banque_recu',{p_requete:i.requete,p_domaine:i.domaine}).catch(()=>null);
   if(!contexteNavigationRueValide(c))return;
   if(r?.ok&&r.terminee&&await finance135Relire(i.domaine,i.cible,c)){sessionStorage.removeItem(cle);n--;showToast('Opération retrouvée','L’état officiel a été rechargé sans nouveau paiement.',true);}
  }
 }finally{finance135Reconciliation=false;}
}
async function finance135ContracterPret(type){
 const montant=Number(document.getElementById('pret-montant')?.value),duree=Number(document.getElementById('pret-duree')?.value);
 if(!Number.isSafeInteger(montant)||!Number.isSafeInteger(duree)){showToast('Montant ou durée invalide','Les francs et les jours doivent être entiers.',false);return;}
 const r=await finance135Executer('pret','banque-nationale',{p_montant:montant,p_duree_jours:duree,p_type_pret:type,p_building_id:state.currentBuilding});
 if(!r)return;document.getElementById('modal-postes')?.classList.remove('open');showToast('Prêt accordé','La dette et le crédit sur le compte national sont enregistrés.',true);addJournalEntry('Prêt '+type+' accordé : '+montant+' FR.','event-good');
}
async function finance135Acquerir(id,action,params={}){
 const r=await finance135Executer('acquisition',id,{p_terrain:id,p_action:action,p_parametres:params});
 if(!r)return null;
 document.getElementById('modal-postes')?.classList.remove('open');
 addJournalEntry(action.startsWith('acte_')?'Acte de vente enregistré, dépôt imputé.':action==='depot'?'Dépôt enregistré, rendez-vous notarial fixé.':'Compromis enregistré.','event-good');
 showToast('Opération enregistrée',action.startsWith('acte_')?'Le titre et le paiement sont confirmés.':'Retrouvez votre dossier chez le notaire.',true);return r;
}
