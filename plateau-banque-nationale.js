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
