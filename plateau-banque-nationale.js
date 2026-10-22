// #64 : ecran de compte existant, meme moteur de placement ; aucun polling ni calcul de rendement.
let placementNationalEnCours=false;
function banquePlacementCle(c){return 'placement-national:'+JSON.stringify([c.uid,c.nom]);}
function banqueNationaleDates(p){
 const debut=Date.parse(p.date_placement),fin=Date.parse(p.prochaine_echeance);
 const date=n=>Number.isFinite(n)?new Date(n).toLocaleString('fr-FR'):'Non renseignée';
 return 'Souscription : '+date(debut)+' · Échéance : '+date(fin)+' · '+(Number.isFinite(fin)?Math.max(0,Math.ceil((fin-Date.now())/86400000))+' jour(s) restant(s)':'Échéance non confirmée');
}
function banqueNationaleFormulaire(){
 const ech=t=>String(t??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 const placements=(state.placementsBancaires||[]).filter(p=>p.banque==='nationale');
 return '<section style="padding:1rem"><h3>Mes placements Banque nationale</h3>'+placements.map(p=>'<p>'+ech(p.montant)+' FR · '+ech(p.statut)+'<br>'+ech(banqueNationaleDates(p))+'</p>').join('')+
 '<p>Placement de 7 jours, minimum 500 FR. Rendement existant de −12 % à +12 %, déterminé à l’échéance. Souscription : 1 PA.</p><label>Montant en FR <input class="finance-input" id="investir-montant" type="text" inputmode="numeric"></label><label>Source <select id="investir-source"><option value="compte">Compte Banque nationale</option><option value="liquide">Espèces</option></select></label><button class="finance-btn" onclick="confirmerInvestir()">Placer les fonds</button></section>';
}
async function banqueNationaleReconcilier(){
 const c=contexteNavigationRue(),cle=banquePlacementCle(c);let attente;
 try{attente=JSON.parse(sessionStorage.getItem(cle)||'null');}catch(_){return;}
 if(!attente?.requete)return;
 const v=await sbRpcVerdict('banque_placement_recu',{p_requete:attente.requete}).catch(()=>null);
 if(!contexteNavigationRueValide(c)||!v?.ok)return;
 await banqueNationaleActualiser(c);if(!contexteNavigationRueValide(c))return;
 sessionStorage.removeItem(cle);
 showToast('Placement confirmé','Le serveur confirme votre souscription précédente. Aucun nouveau paiement.',true);
}
async function banqueNationaleActualiser(c){
 const f=await rafraichirRuntimeHelvetia();
 if(!contexteNavigationRueValide(c)||!f)return false;
 if(typeof f?.pa==='number')state.pa=f.pa;
 if(typeof updateUI==='function')updateUI();return true;
}
async function placerBanqueNationale(){
 if(placementNationalEnCours)return;
 const montant=document.getElementById('investir-montant')?.value?.trim(),source=document.getElementById('investir-source')?.value;
 if(!/^[0-9]+$/.test(montant||'')||BigInt(montant)<500n||!['liquide','compte'].includes(source)){showToast('Montant invalide','Indiquez au moins 500 FR entiers et une source de fonds.',false);return;}
 const c=contexteNavigationRue(),cle=banquePlacementCle(c);let intention;
 try{
  intention=JSON.parse(sessionStorage.getItem(cle)||'null');
  if(intention&&(intention.montant!==montant||intention.source!==source)){showToast('Souscription à vérifier','La souscription précédente reste à confirmer. Réessayez avec son montant et sa source avant un nouvel ordre.',false);return;}
  if(!intention){intention={requete:crypto.randomUUID(),montant,source,intSnapshot:getStatEffective('INT')};sessionStorage.setItem(cle,JSON.stringify(intention));}
 }catch(_){showToast('Souscription non lancée','La reprise sûre de cette opération ne peut pas être enregistrée.',false);return;}
 placementNationalEnCours=true;
 try{
  const v=await sbRpcVerdict('banque_nationale_placer',{p_requete:intention.requete,p_montant:intention.montant,p_source:intention.source,p_int_snapshot:intention.intSnapshot}).catch(()=>null);
  if(!contexteNavigationRueValide(c))return;
  if(!v?.ok){if(v&&!v.transport)sessionStorage.removeItem(cle);showToast('Placement non confirmé',v?.transport?'Réponse incertaine : la prochaine tentative vérifiera le même identifiant.':'Le serveur n’a pas accepté la souscription. Aucun succès annoncé.',false);return;}
  sessionStorage.removeItem(cle);const fraisConfirmes=await banqueNationaleActualiser(c);if(!contexteNavigationRueValide(c))return;
  if(!fraisConfirmes){showToast('Placement confirmé','Le serveur a enregistré la souscription. La relecture de vos soldes reste à confirmer.',true);return;}
  showToast('Placement souscrit','Les fonds ont été placés, sans dépôt intermédiaire.',true);await openFinancesModal(0,0);
 }finally{placementNationalEnCours=false;}
}

// #69 : les ordres louer_local/gerer_local conservent une seule entree, vers les coffres annuels.
let coffreCommandeEnCours=false,coffreVue=null,coffreCatalogueActuel=null;
function coffreLutheciaIci(){return state.country==='republic'&&state.currentCity==='capitale'&&state.currentBuilding==='banque-nationale'&&state.currentRoom==='coffre_privatif';}
function coffreEchapper(v){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));}
function coffreBouton(label,js,disabled=false){return '<button type="button" class="finance-btn" onclick="'+coffreEchapper(js)+'"'+(disabled?' disabled':'')+'>'+coffreEchapper(label)+'</button>';}
function coffreFenetre(html){document.getElementById('postes-modal-title').textContent='Mes coffres bancaires';document.getElementById('postes-body').innerHTML='<section class="finance-section" style="padding:1rem">'+html+'</section>';document.getElementById('modal-postes').classList.add('open');}
function coffreCle(c){return 'coffre-commande:'+JSON.stringify([c.uid,c.nom]);}
async function coffreActualiser(c,inventaire=false){
 const f=await rafraichirRuntimeHelvetia({exigerComptes:true});
 if(!f||!contexteNavigationRueValide(c))return false;
 if(inventaire){
  const frais=await sbInventaireReceptionEtat(c.nom).catch(()=>null);
  if(!contexteNavigationRueValide(c)||!frais?.ok||!sbAdopterInventaireServeur(frais))return false;
  if(typeof renderInventory==='function')renderInventory();
 }
 if(Number.isSafeInteger(f.pa)){state.pa=f.pa;state.char.pa=f.pa;}updateUI();return true;
}
async function coffreReconcilier(c){
 let i;try{i=JSON.parse(sessionStorage.getItem(coffreCle(c))||'null');}catch(_){return;}
 if(!i?.requete)return;
 const r=await sbRpcVerdict('coffre_recu',{p_requete:i.requete}).catch(()=>null);
 if(!contexteNavigationRueValide(c))return;
 if(r?.ok&&r.terminee&&await coffreActualiser(c,i.rpc==='coffre_transferer'))sessionStorage.removeItem(coffreCle(c));
}
async function ouvrirCoffresBancaires(){
 if(!coffreLutheciaIci())return;
 const c=contexteNavigationRue();await coffreReconcilier(c);if(!contexteNavigationRueValide(c))return;
 const v=await sbRpcVerdict('coffre_catalogue',{}).catch(()=>null);if(!contexteNavigationRueValide(c))return;
 if(!v?.ok){showToast('Coffres indisponibles','Le service annuel ne peut pas être confirmé. Aucun frais prélevé.',false);return;}
 coffreVue=null;coffreCatalogueActuel=v;
 let html='<p>Chaque exemplaire ou unité empilable occupe une unité. Tarif annuel ; location : 1 PA.</p>';
 for(const o of v.offres||[])html+=coffreBouton(o.taille+' · '+o.capacite+' unités · '+o.tarifAnnuel+' FR/an','coffreExecuter("coffre_souscrire",'+JSON.stringify({p_taille:o.taille})+')');
 html+='<h3>Mes contrats</h3>';
 for(const t of v.coffres||[])html+='<p>'+coffreEchapper(t.taille)+' · '+coffreEchapper(t.occupation)+'/'+coffreEchapper(t.capacite)+' unités · renouvellement '+coffreEchapper(t.renouvellementAnnuel||'à confirmer')+(t.impaye?' · '+coffreEchapper(t.impaye)+' FR impayés':'')+'</p>'+coffreBouton(t.gele?'Succession en cours':'Ouvrir','ouvrirCoffreBancaire('+JSON.stringify(t.id)+')',!!t.gele);
 if(sessionStorage.getItem(coffreCle(c)))html+='<p>Une commande reste à vérifier.</p>'+coffreBouton('Reprendre la commande en attente','coffreReprendre()');
 coffreFenetre(html);
}
async function ouvrirCoffreBancaire(id){
 if(!coffreLutheciaIci())return;const c=contexteNavigationRue();
 const v=await sbRpcVerdict('coffre_lire',{p_coffre:id}).catch(()=>null);if(!contexteNavigationRueValide(c))return;
 if(!v?.ok||!sbAdopterInventaireServeur(v)){showToast('Lecture non confirmée','Relisez le coffre avant toute opération.',false);return;}
 // La selection est le snapshot serveur, distinct d'eventuelles mutations locales ulterieures.
 coffreVue=JSON.parse(JSON.stringify(v));
 let html='<p>'+coffreEchapper(v.occupation)+'/'+coffreEchapper(v.capacite)+' unités</p>';
 for(const action of ['deposer','retirer']){
  html+='<h3>'+(action==='deposer'?'Mon inventaire':'Contenu du coffre')+'</h3>';
  const items=action==='deposer'?v.inventory:v.contenu;
  (items||[]).forEach((o,index)=>{html+='<div><span>'+coffreEchapper(o.name||o.type||'Objet')+'</span> <input class="finance-input" type="number" min="1" step="1" value="1" id="coffre-q-'+action+'-'+index+'" aria-label="Quantité">'+coffreBouton(action==='deposer'?'Déposer':'Retirer','coffreTransferer('+JSON.stringify(action)+','+index+')')+'</div>';});
 }
 html+='<h3>Changer la taille</h3><p>Effet immédiat, échéance inchangée. Réduction gratuite sans remboursement.</p>';
 const t=(coffreCatalogueActuel?.coffres||[]).find(t=>t.id===id);
 if(t)for(const o of coffreCatalogueActuel.offres||[]){const diff=Math.max(0,o.tarifAnnuel-t.tarifAnnuel);html+=coffreBouton(o.taille+' · '+o.capacite+' unités · '+diff+' FR maintenant','coffreExecuter("coffre_changer_taille",'+JSON.stringify({p_coffre:id,p_taille:o.taille,p_revision:v.revisionCoffre})+')',o.capacite<v.occupation||o.taille===t.taille);}
 html+='<hr>'+coffreBouton('Résilier le coffre vide','coffreExecuter("coffre_resilier",'+JSON.stringify({p_coffre:id,p_revision:v.revisionCoffre})+')',v.occupation!==0)+coffreBouton('Mes contrats','ouvrirCoffresBancaires()');
 coffreFenetre(html);if(typeof renderInventory==='function')renderInventory();
}
async function coffreTransferer(action,index){
 const v=coffreVue;if(!v||!['deposer','retirer'].includes(action))return;
 const q=document.getElementById('coffre-q-'+action+'-'+index)?.value;
 if(!/^[1-9][0-9]*$/.test(q||'')||!Number.isSafeInteger(Number(q))){showToast('Quantité invalide','Indiquez un nombre entier positif.',false);return;}
 const objets=action==='deposer'?v.inventory:v.contenu;if(!objets[index])return;
 return coffreExecuter('coffre_transferer',{p_coffre:v.coffre,p_action:action,p_index:index,p_signature:objets[index],p_quantite:Number(q),p_revision_inventaire:v.revision,p_revision_coffre:v.revisionCoffre});
}
async function coffreReprendre(){
 const c=contexteNavigationRue();let i;try{i=JSON.parse(sessionStorage.getItem(coffreCle(c))||'null');}catch(_){return;}
 if(i)return coffreExecuter(i.rpc,i.args);
}
async function coffreExecuter(rpc,args){
 if(coffreCommandeEnCours||!coffreLutheciaIci()||!['coffre_souscrire','coffre_transferer','coffre_changer_taille','coffre_resilier'].includes(rpc))return null;
 const c=contexteNavigationRue(),cle=coffreCle(c);let i;
 try{
  i=JSON.parse(sessionStorage.getItem(cle)||'null');
  const propre=JSON.parse(JSON.stringify(args));
  if(i&&(i.rpc!==rpc||JSON.stringify(i.args)!==JSON.stringify(propre))){showToast('Commande en attente','Vérifiez la commande précédente avant une autre opération.',false);return null;}
  if(!i)i={requete:'coffre-'+crypto.randomUUID(),rpc,args:propre};sessionStorage.setItem(cle,JSON.stringify(i));
 }catch(_){showToast('Commande non lancée','La reprise sûre de cette opération ne peut pas être enregistrée.',false);return null;}
 coffreCommandeEnCours=true;
 try{
  const v=await sbRpcVerdict(i.rpc,{...i.args,p_requete:i.requete}).catch(()=>null);if(!contexteNavigationRueValide(c))return null;
  if(!v?.ok){if(v&&!v.transport)sessionStorage.removeItem(cle);showToast('Commande non confirmée',v?.transport||!v?'Réponse incertaine. Reprenez la même commande sans second traitement.':(v.raison||'Le serveur a refusé.'),false);return null;}
  if(!await coffreActualiser(c,i.rpc==='coffre_transferer')){showToast('Commande acquise','Le serveur confirme l’opération ; la relecture financière reste à confirmer.',true);return null;}
  sessionStorage.removeItem(cle);showToast('Coffre mis à jour','L’opération est confirmée par le serveur.',true);
  await ouvrirCoffresBancaires();return v;
 }finally{coffreCommandeEnCours=false;}
}
