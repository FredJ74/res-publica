// #135 : transport commun des actes à jet, sans règles métier navigateur.
// Le serveur ne publie actesAtomiques=1 qu'après validation de TOUS les hôtes.
let l09EnCours=false;
const L09_RPC=Object.freeze({
  vol:'vol_commande',achat_arme_illegal:'arme_clandestine_commande',tentative_evasion:'evasion_commande',
  mener_enquete:'police_enquete_commande',organiser_filature:'police_filature_commande',
  organiser_chasse_homme:'police_chasse_commande',voler_materiel_chantier:'chantier_vol_commande',
  benediction:'religion_benediction_demander'
});
function l09CibleVol(encoded){try{return JSON.parse(decodeURIComponent(encoded)).name.replace(/ \(PNJ\)$/,'');}catch(_){return '';}}
function l09MessageRefus(r){
  const messages={session_perdue:'Votre session doit être rétablie.',session_absente:'Votre session doit être rétablie.',
    pa_insuffisants:'Vous n’avez pas assez de PA.',fonds_insuffisants:'Vos fonds sont insuffisants.',caisse_insuffisante:'La caisse ne permet pas cet ordre.',
    cible_absente:'Cette personne n’est plus sur place.',pas_sur_place:'Vous n’êtes pas dans la pièce requise.',acteur_indisponible:'Votre état actuel ne permet pas cet ordre.',
    commissaire_hors_juridiction:'Vous ne pouvez agir que dans votre juridiction.',refugie_protege:'Cette personne est protégée par l’asile politique.',
    tentative_quotidienne_deja_effectuee:'Vous avez déjà tenté de vous évader aujourd’hui.',historique_bonus_deserteur_a_verifier:'Votre historique de détention doit être vérifié avant cette tentative.'};
  return messages[r?.raison]||'Le serveur a refusé cet ordre. Aucun succès n’est confirmé.';
}
function l09Cle(ordre,c,id){return 'hg-jet:'+JSON.stringify([c.uid,id,ordre]);}
async function l09Rpc(fn,parametres,c){
  if(!['religion_benediction_lire','ordres_jets_commande'].includes(fn))throw new Error('transport_jet_non_autorise');
  let delai,expire=false;
  const limite=new Promise(resolve=>{delai=setTimeout(()=>{expire=true;resolve({ok:false,transport:{etat:'indetermine'}});},15000);});
  try{
    // Le délai ne prouve pas un refus serveur : le même UUID restera à reprendre.
    const options={encoreValide:()=>!expire&&contexteNavigationRueValide(c)};
    // Noms explicites : le contrôle d’autorité doit continuer de voir les deux RPC.
    const appel=(fn==='religion_benediction_lire'
      ?sbRpcVerdict('religion_benediction_lire',parametres,options)
      :sbRpcVerdict('ordres_jets_commande',parametres,options)).catch(()=>null);
    return await Promise.race([appel,limite]);
  }finally{clearTimeout(delai);}
}
async function l09Intercepter(ordre,parametres){
  if(!L09_RPC[ordre])throw new Error('ordre_jet_inconnu');
  if(l09EnCours)return true;
  const c=contexteNavigationRue();l09EnCours=true;
  try{
    const contrat=await l09Rpc('religion_benediction_lire',{},c);
    if(!contexteNavigationRueValide(c))return true;
    // Un ancien serveur ne possède pas ce service ; aucun nouvel hôte n'est appelé.
    if(contrat?.transport?.http===404&&contrat.transport.code==='PGRST202')return false;
    if(contrat?.ok===true&&contrat.actesAtomiques!==1){
      let reprise=false;try{reprise=!!(contrat.personnageId&&sessionStorage.getItem(l09Cle(ordre,c,contrat.personnageId)));}catch(_){showToast('Ordre non lancé','La reprise de cette commande ne peut pas être vérifiée.',false);return true;}
      if(!reprise){if(contrat.actesSuspendus){showToast('Ordres suspendus','Le service est temporairement suspendu.',false);return true;}return false;}
    }
    if(!contrat?.ok){showToast('Ordre non lancé',l09MessageRefus(contrat),false);return true;}
    if(typeof contrat.personnageId!=='string'){showToast('Ordre non lancé','L’identité du personnage n’a pas été confirmée par le serveur.',false);return true;}
    const cle=l09Cle(ordre,c,contrat.personnageId);let intention;
    try{
      const ancien=sessionStorage.getItem(cle);intention=ancien?JSON.parse(ancien):{requete:crypto.randomUUID(),parametres};
      if(!intention?.requete||JSON.stringify(intention.parametres)!==JSON.stringify(parametres)){
        showToast('Commande en attente','Reprenez la commande précédente avec les mêmes paramètres pour confirmer son résultat.',false);return true;
      }
      sessionStorage.setItem(cle,JSON.stringify(intention));
    }catch(_){showToast('Ordre non lancé','La reprise sûre de cette commande ne peut pas être enregistrée.',false);return true;}
    const r=await l09Rpc('ordres_jets_commande',{p_personnage:contrat.personnageId,p_ordre:ordre,p_parametres:intention.parametres,p_requete:intention.requete},c);
    if(!contexteNavigationRueValide(c))return true;
    if(!r?.ok){
      if(r&&!r.transport){sessionStorage.removeItem(cle);showToast('Ordre refusé',l09MessageRefus(r),false);}
      else showToast('Confirmation incertaine','Reprenez la même commande pour vérifier son résultat. Aucun succès n’est annoncé.',false);
      return true;
    }
    const origine=typeof sbContexteInventaire==='function'?sbContexteInventaire():null;
    const frais=typeof rafraichirRuntimeHelvetia==='function'?await rafraichirRuntimeHelvetia({exigerComptes:true}):null;
    if(!contexteNavigationRueValide(c))return true;
    if(!frais||frais.userId&&frais.userId!==c.uid){showToast('Ordre confirmé','La relecture de votre état reste à confirmer. La commande est conservée pour reprise.',false);return true;}
    if(Array.isArray(frais.inventory)&&Number.isSafeInteger(frais._inventaireRevision)){
      const inventaire={inventory:frais.inventory,revision:frais._inventaireRevision};
      if(origine&&typeof sbMarquerInventaires==='function')sbMarquerInventaires(inventaire,origine);
      if(typeof sbAdopterInventaireServeur!=='function'||!sbAdopterInventaireServeur(inventaire)){
        showToast('Ordre confirmé','L’inventaire a changé pendant la lecture. Reprenez la commande pour le vérifier.',false);return true;
      }
    }else if(r.inventaire){showToast('Ordre confirmé','L’inventaire actualisé reste à relire. La reprise est conservée.',false);return true;}
    for(const champ of ['pa','hp','moral','pop','recherche','convocations','historiqueCrimes','estEmprisonne','detentionQhs']){
      if(Object.prototype.hasOwnProperty.call(frais,champ))state[champ]=frais[champ];
    }
    if(typeof frais.pa==='number')state.char.pa=frais.pa;
    if(contrat.benediction)state.char.benedictionServeur=contrat.benediction;
    if(r.realites?.benediction)state.char.benedictionServeur=r.realites.benediction;
    if(r.benediction)state.char.benedictionServeur=r.benediction;
    sessionStorage.removeItem(cle);
    document.getElementById('modal-postes')?.classList.remove('open');
    updateUI();l09AfficherResultat(ordre,r);return true;
  }finally{l09EnCours=false;}
}
function l09AfficherResultat(ordre,r){
  let titre='Ordre confirmé',texte='Le serveur a enregistré le résultat.',positif=r.succes===true;
  if(ordre==='benediction'){titre=r.succes?'Béni !':'Pas de réponse';texte=r.succes?'Bénédiction accordée pour votre prochain jet.':'Le religieux n’a pas accordé de bénédiction.';}
  if(ordre==='vol'){titre=!r.succes?'Vol échoué':r.butin==='rien'?'Vol infructueux':'Vol réussi';texte=!r.succes?'Sanction : '+r.amende+' et '+r.pertePop+' POP perdue.':r.butin==='argent'?r.montant+' dérobés.':r.butin==='rien'?'Aucun butin.':r.quantite+' × '+(r.objet?.name||'objet')+' reçu(s).';}
  if(ordre==='achat_arme_illegal'){titre=r.succes?'Arme acquise':'Vente refusée';texte=r.succes?(r.objet?.name||'Arme')+' reçue. Prix payé : '+r.prix+'.':'L’armurier vous a dénoncé. Une convocation est enregistrée.';}
  if(ordre==='tentative_evasion'){titre=r.succes?'Évasion réussie':'Évasion échouée';texte=r.succes?'Reliquat : '+r.reliquat+' jour(s), plus la sanction d’évasion enregistrée.':'Peine prolongée d’un jour. Amende payée : '+r.amende+'.';}
  if(ordre==='voler_materiel_chantier'){titre=r.succes?'Vol de matériaux réussi':'Vol de matériaux échoué';texte=r.quantite+' unité(s) de '+r.matiere+' reçue(s).'+(r.detecte?' Vous avez été détecté(e).':'');}
  if(ordre==='organiser_chasse_homme'){titre=r.succes?'Arrestation confirmée':'Chasse infructueuse';texte=r.succes?r.cible+' : '+r.execution.jours+' jour(s) de détention.':'La cible n’a pas été arrêtée.';}
  if(ordre==='mener_enquete'){titre=r.decision==='enquete_ouverte'?'Enquête ouverte':r.decision==='contre_espionnage'?'Enquête transmise':'Enquête terminée';texte=r.decision==='aucun_element'?'Aucun élément exploitable.':r.decision==='contre_espionnage'?'Résultat transmis au renseignement.':r.decision==='enquete_ouverte'?'La détention et le dossier judiciaire sont enregistrés.':'Les indices sont insuffisants.';}
  if(ordre==='organiser_filature'){
    titre=r.succes?'Filature réussie':'Filature échouée';texte=r.succes?'Le rapport des déplacements confirmés est disponible.':'Aucun rapport obtenu.';
    if(r.succes)l09AfficherRapport(r);
  }
  showToast(titre,texte,positif,true);
  if(typeof addJournalEntry==='function'){
    const brut=titre+' — '+texte;
    const journal=typeof escapeHtmlText==='function'?escapeHtmlText(brut):brut.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
    addJournalEntry(journal,positif?'event-good':'event-info');
  }
}
function l09AfficherRapport(r){
  const h=document.getElementById('postes-modal-title'),b=document.getElementById('postes-body'),m=document.getElementById('modal-postes');if(!h||!b||!m)return;
  h.textContent='Rapport de filature';b.replaceChildren();const boite=document.createElement('div');boite.className='cpj-dialogue';
  for(const d of r.deplacements||[]){const p=document.createElement('p');p.className='cpj-note';p.textContent=[d.date_evenement,d.country,d.city,d.building_id,d.room_id].filter(Boolean).join(' · ');boite.appendChild(p);}
  if(!r.deplacements?.length){const p=document.createElement('p');p.className='cpj-note';p.textContent='Aucun déplacement dans la période examinée.';boite.appendChild(p);}
  if(r.horodatagesInconnus){const p=document.createElement('p');p.className='cpj-note';p.textContent='Certains déplacements anciens n’ont pas d’horodatage exploitable.';boite.appendChild(p);}
  b.appendChild(boite);m.classList.add('open');
}
