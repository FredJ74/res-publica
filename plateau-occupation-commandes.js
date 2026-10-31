// Adaptateurs des ordres d'occupation existants. Aucune depense, aucun jet local.
let occupationCommandeEnCours=false;
function occupationCle(action,c=contexteNegociationSquatteurs()) {
  return 'occupation-acte:'+JSON.stringify([c.uid,c.personnage?.name,c.pays,c.ville,c.terrain,action]);
}
async function occupationPreparer(action) {
  const contexte=contexteNegociationSquatteurs();
  let r;try{r=await sbRpcVerdict('terrain_occupation_action_preparer',{p_terrain:contexte.terrain,p_action:action});}catch(_){r=null;}
  if(!memeContexteNegociation(contexte))return null;
  if(!r?.ok){showToast('Action indisponible',r?.raison||'Le serveur ne peut pas confirmer la situation du terrain.',false);return null;}
  return {...r,action,contexte};
}
async function occupationOuvrirPolice() {
  const reprise=contexteNegociationSquatteurs();
  for(const action of ['police','corruption_police']) {
    let attente;
    try{attente=JSON.parse(sessionStorage.getItem(occupationCle(action,reprise))||'null');}
    catch(_){showToast('Action indisponible','La reprise sûre ne peut pas être lue.',false);return;}
    if(attente){
      state._occupationPolice={[action]:{...attente.plan,contexte:reprise}};
      constructionFenetre('Appel en attente',constructionBouton('Vérifier le résultat de cet appel','occupationExecuterPolice('+JSON.stringify(action)+')'));return;
    }
  }
  const c=contexteNegociationSquatteurs(),[legale,rapide]=await Promise.all([occupationPreparer('police'),occupationPreparer('corruption_police')]);
  if(!legale||!rapide||!memeContexteNegociation(c))return;
  state._occupationPolice={police:legale,corruption_police:rapide};
  constructionFenetre('Appeler la police','<p>Intervention légale : '+legale.pa+' PA, sans paiement ni jet aléatoire. Délai : '+legale.delaiHeures+' h.</p>'+constructionBouton('Demander l’intervention légale','occupationExecuterPolice("police")')+'<p>Soudoyer : '+rapide.pa+' PA et '+rapide.cout+' FR ; réussite '+rapide.taux+' %, délai '+rapide.delaiHeures+' h en cas de succès.</p>'+constructionBouton('Soudoyer l’inspecteur','occupationExecuterPolice("corruption_police")'));
}
async function occupationExecuterPolice(action) {
  const plan=state._occupationPolice?.[action];
  if(!plan||!memeContexteNegociation(plan.contexte)){showToast('Action périmée','Rouvrez la demande depuis ce terrain.',false);return;}
  return occupationExecuter(plan);
}
async function occupationDissimuler() {
  // Une reponse incertaine doit etre rejouee avec l'ancienne occupation, jamais un nouveau jet.
  const c=contexteNegociationSquatteurs();let attente;
  try{attente=JSON.parse(sessionStorage.getItem(occupationCle('cadavre',c))||'null');}catch(_){showToast('Action indisponible','La reprise sûre ne peut pas être lue.',false);return;}
  if(attente)return occupationExecuter({...attente.plan,contexte:c});
  const plan=await occupationPreparer('cadavre');if(plan)return occupationExecuter(plan);
}
async function occupationExecuter(plan) {
  if(occupationCommandeEnCours)return;
  const c=plan.contexte;if(!memeContexteNegociation(c))return;
  const cle=occupationCle(plan.action,c);let intention;
  try{
    intention=JSON.parse(sessionStorage.getItem(cle)||'null')||{requete:crypto.randomUUID(),plan:{action:plan.action,occupation:plan.occupation,taux:plan.taux,cout:plan.cout??0}};
    sessionStorage.setItem(cle,JSON.stringify(intention));
  }catch(_){showToast('Action non lancée','La reprise sûre ne peut pas être conservée.',false);return;}
  occupationCommandeEnCours=true;
  try{
    let r;try{r=await sbRpcVerdict('terrain_occupation_action',{p_terrain:c.terrain,p_action:intention.plan.action,p_occupation:intention.plan.occupation,p_requete:intention.requete,p_taux:intention.plan.taux,p_cout:intention.plan.cout??0});}catch(_){r=null;}
    if(!memeContexteNegociation(c))return;
    if(!r?.ok){
      if(r&&!r.transport)sessionStorage.removeItem(cle);
      showToast('Action non confirmée',r?.transport||!r?'Réponse incertaine. Reprenez la même action pour vérifier son résultat.':r.raison,false);return;
    }
    // Relecture canonique, y compris au rejeu : aucun ancien recu ne remplace un etat plus recent.
    const [terrain,fiche]=await Promise.all([sbGetTerrainState(c.pays,c.terrain).catch(()=>null),rafraichirRuntimeHelvetia({exigerComptes:true}).catch(()=>null)]);
    if(!memeContexteNegociation(c))return;
    if(!terrain||!fiche){showToast('Action enregistrée','La relecture reste à confirmer ; la reprise est conservée.',true);return;}
    remplacerTerrainState(c.terrain,terrain);
    for(const k of ['pa','hp','dis'])if(typeof fiche[k]==='number')state[k]=fiche[k];
    if(typeof fiche.pa==='number')state.char.pa=fiche.pa;
    if(Array.isArray(fiche.recherche))state.recherche=fiche.recherche;
    sessionStorage.removeItem(cle);updateUI();
    const texte=r.action==='cadavre'?(r.succes?'Le corps a été dissimulé.':'La tentative a échoué. Les conséquences ont été enregistrées.'):(r.succes?'L’intervention de la police est enregistrée.':'L’inspecteur a refusé.');
    addJournalEntry(texte+(r.jet==null?'':' Jet '+r.jet+'/'+r.taux+' %.'),r.succes?'event-good':'event-bad');
    showToast('Résultat confirmé',texte,!!r.succes);document.getElementById('modal-postes')?.classList.remove('open');
  }finally{occupationCommandeEnCours=false;}
}
