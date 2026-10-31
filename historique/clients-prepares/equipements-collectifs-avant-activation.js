// NON CHARGÉ PAR LE JEU. Source conservée depuis 4a8990a5 pour la future activation et ses bancs.
// Equipements collectifs : rendu des faits serveur, aucune mutation d'argent ou d'objet locale.
let RP_EQ_VUE = 0;
function equipementsCollectifsContexte() {
 return {personnage:state.char,nom:state.char?.name,
  uid:typeof rpAuthUid==='function'?rpAuthUid():null,
  session:typeof rpAuthSessionIdentifiant==='function'?rpAuthSessionIdentifiant():null};
}
function equipementsCollectifsContexteValide(c) {
 return state.char===c.personnage&&state.char?.name===c.nom&&
  (typeof rpAuthUid!=='function'||rpAuthUid()===c.uid)&&
  (typeof rpAuthSessionIdentifiant!=='function'||rpAuthSessionIdentifiant()===c.session);
}
async function equipementsCollectifsOuvrir(organisation) {
 const contexte=equipementsCollectifsContexte(),version=++RP_EQ_VUE;
 commercePjModale('Équipements collectifs','<div id="equipements-collectifs" style="display:grid;gap:.8rem;padding:1rem"></div>');
 const root=document.getElementById('equipements-collectifs');
 if(!root)return;
 root.textContent='Lecture des équipements…';
 const r=typeof sbRpcVerdict==='function'?await sbRpcVerdict('organisation_equipements_etat',{p_organisation:organisation}).catch(()=>null):null;
 if(version!==RP_EQ_VUE||!root.isConnected||!equipementsCollectifsContexteValide(contexte))return;
 root.replaceChildren();
 const texte=(parent,tag,contenu)=>{const n=document.createElement(tag);n.textContent=contenu;parent.appendChild(n);return n;};
 const relire=texte(root,'button','Actualiser');relire.onclick=()=>equipementsCollectifsOuvrir(organisation);
 if(!r?.ok||!Array.isArray(r.objets)){texte(root,'p','Équipements indisponibles ou accès non autorisé.');return;}
 texte(root,'p','Ce matériel appartient à l’organisation et reste sa propriété lors d’un changement de direction.');
 const libelles={commerce_international:'Ordinateur et internet',piratage:'Configuration informatique connectée',surveillance:'Ordinateur et caméras',protection_intranet:'Protection intranet',impression_papier:'Impression papier',impression_3d:'Impression 3D'};
 const capacites=Object.keys(libelles).filter(c=>r.capacites?.[c]===true).map(c=>libelles[c]);
 texte(root,'p',capacites.length?'Configurations installées : '+capacites.join(' · '):'Aucune configuration complète installée.');
 if(!r.objets.length)texte(root,'p','Aucun matériel dans l’inventaire collectif.');
 const message=texte(root,'p','');message.setAttribute('role','status');
 let occupe=false;
 const envoyer=async(objet,action,destination)=>{
  if(occupe||!equipementsCollectifsContexteValide(contexte))return;
  occupe=true;root.querySelectorAll('button').forEach(b=>b.disabled=true);
  const requete='equip-'+crypto.randomUUID();
  const verdict=await sbRpcVerdict('organisation_equipement_deplacer',{p_requete:requete,p_organisation:organisation,p_objet:objet,p_action:action,p_destination:destination||null}).catch(()=>null);
  if(version!==RP_EQ_VUE||!root.isConnected||!equipementsCollectifsContexteValide(contexte))return;
  if(!verdict?.ok){
   message.textContent='Opération non confirmée. Actualisez pour consulter la situation enregistrée avant toute nouvelle action.';
   relire.disabled=false;return;
  }
  await equipementsCollectifsOuvrir(organisation);
 };
 for(const item of r.objets){
  const ligne=texte(root,'section','');ligne.style.cssText='border:1px solid #6b5731;padding:.7rem;display:grid;gap:.5rem';
  texte(ligne,'strong',String(item.objet?.name||item.objet?.generique_id||'Objet')+' × '+String(item.objet?.qty||1));
  texte(ligne,'span',item.localId?'Installé : '+item.ville+' / '+item.localId:'En réserve');
  const action=texte(ligne,'button',item.localId?'Retirer':'Installer dans les locaux');action.onclick=()=>envoyer(item.id,item.localId?'retirer':'installer');
  if(!item.localId){
   const destinations=(state.organisations||[]).filter(o=>o.id!==organisation&&o.chef===state.char?.name);
   if(destinations.length){const choix=document.createElement('select');choix.setAttribute('aria-label','Organisation destinataire');
    for(const d of destinations){const opt=document.createElement('option');opt.value=d.id;opt.textContent=d.nom||d.id;choix.appendChild(opt);}ligne.appendChild(choix);
    const transferer=texte(ligne,'button','Transférer à cette organisation');transferer.onclick=()=>envoyer(item.id,'transferer',choix.value);
   }
  }
 }
}

// Un choix de payeur n'apparait que si le contrat d'achat serveur est disponible.
async function equipementsCollectifsProposerPayeur(cible) {
 const c=equipementsCollectifsContexte();
 const r=typeof sbRpcVerdict==='function'?await sbRpcVerdict('organisation_equipements_payeurs',{}).catch(()=>null):null;
 if(!cible?.isConnected||!equipementsCollectifsContexteValide(c)||!r?.ok||!r.achats||!Array.isArray(r.organisations)||!r.organisations.length)return;
 const label=document.createElement('label');label.textContent='Payeur et propriétaire';
 const select=document.createElement('select');select.id='cpj-payeur-collectif';select.setAttribute('aria-label','Payeur et propriétaire');
 const perso=document.createElement('option');perso.value='';perso.textContent='Personnellement';select.appendChild(perso);
 for(const o of r.organisations){const opt=document.createElement('option');opt.value='orga:'+o.id;opt.textContent=o.nom||o.id;select.appendChild(opt);}
 label.appendChild(select);cible.appendChild(label);
}

// Une intention d'achat non confirmee conserve sa cle a travers F5/reconnexion.
// Le stockage ne porte aucun solde ; seul le recu serveur tranche l'operation.
function equipementsCollectifsCleAchat(organisation,fonds,reference,quantite,candidate) {
 const uid=typeof rpAuthUid==='function'?rpAuthUid():null;
 if(!uid||!state.char?.name)throw Error('Connexion requise.');
 const cle='rp_achat_collectif:'+JSON.stringify([uid,state.char.name,organisation,fonds,reference,quantite]);
 const ancienne=localStorage.getItem(cle);
 const requete=ancienne||candidate;
 if(typeof requete!=='string'||!/^achat-[A-Za-z0-9-]{6,80}$/.test(requete))throw Error('Identifiant de reprise invalide.');
 localStorage.setItem(cle,requete);
 if(localStorage.getItem(cle)!==requete)throw Error('Reprise de transaction indisponible.');
 return {cle,requete};
}
function equipementsCollectifsAchatConfirme(reprise) {
 if(!reprise)return;
 try{if(localStorage.getItem(reprise.cle)===reprise.requete)localStorage.removeItem(reprise.cle);}catch(_){/* Le rejeu reste sur le recu deja confirme, sans nouveau debit. */}
}

async function commercePjAcheter(referenceId, requete) {
  return commercePjTransaction('achat', async (tx) => {
  const payeur=document.getElementById('cpj-payeur-collectif')?.value||'';
  const ctx = await commercePjContexte();
  if (!commercePjTransactionActive(tx)) return;
  const qte = Math.max(1, Math.floor(Number((document.getElementById('cpj-qte') || {}).value) || 1));
  if(payeur && !payeur.startsWith('orga:'))return;
  const collectif=payeur.startsWith('orga:');
  const reprise=collectif?equipementsCollectifsCleAchat(payeur.slice(5),ctx.fondsId,referenceId,qte,requete):null;
  const r = collectif
    ? await sbRpcVerdict('organisation_equipement_acheter',{p_requete:reprise.requete,p_organisation:payeur.slice(5),p_fonds:ctx.fondsId,p_reference:referenceId,p_quantite:qte})
    : await sbAcheterProduitCommerce(requete, state.char.name, ctx.fondsId, referenceId, qte);
  if (!commercePjTransactionActive(tx)) return;
  if (!r || !r.ok) { showToast('—', commercePjRefus(r), false); return; }
  if(collectif)equipementsCollectifsAchatConfirme(reprise);
  await commercePjActualiserPersonnage();
  if (!commercePjTransactionActive(tx)) return;
  if (typeof updateUI === 'function') updateUI();
  if (r.rejeu === true) { commercePjEcranBoutique(); return; }
  showToast(tCommercePJ('commercepj.fiche.achete'),
    commercePjMontant(r.montant) + ' ' + commercePjDevise() + ' — ' + (collectif?'Inventaire collectif':tCommercePJ('commercepj.fiche.recu')), true, true);
  if (typeof addJournalEntry === 'function') {
    addJournalEntry('Achat : ' + r.quantite + ' × ' + commercePjMontant(r.prixUnitaire) + ' ' +
      commercePjDevise() + '.', 'event-good');
  }
  // Le sas existant reste le seul chemin de livraison : on ne cree pas un second
  // systeme de reception, on declenche simplement le drainage deja en place.
  if (!collectif && typeof verifierObjetsRecus === 'function') { try { await verifierObjetsRecus(); } catch (e) {} }
  if (typeof updateUI === 'function') updateUI();
  commercePjEcranBoutique();
  });
}
