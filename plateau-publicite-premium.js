// Publicite premium presse : atelier beta. Aucun paiement n'est demande.
function ouvrirPublicitePremium() {
  const modal=document.getElementById('modal-postes');
  const titre=document.getElementById('modal-postes-title');
  const corps=document.getElementById('modal-postes-body');
  if(!modal||!corps)return;
  if(titre)titre.textContent='Publicité premium — La Tribune de Républia';
  corps.innerHTML='<div style="padding:1rem;max-width:680px;margin:auto">'+
    '<h3>Votre pleine page publicitaire</h3>'+
    '<p>Offre bêta : création gratuite. La facturation Stripe sera activée ultérieurement.</p>'+
    '<label for="pub-premium-formule">Campagne</label>'+
    '<select id="pub-premium-formule" style="display:block;width:100%;padding:.6rem;margin:.4rem 0 1rem">'+
    '<option value="cinq">5 parutions — gratuit en bêta (futur tarif 4,99 €)</option>'+
    '<option value="dix">10 parutions — gratuit en bêta (futur tarif 7,99 €)</option></select>'+
    '<label for="pub-premium-texte">Décrivez votre publicité</label>'+
    '<textarea id="pub-premium-texte" rows="5" maxlength="1500" style="display:block;width:100%;padding:.6rem;margin:.4rem 0 1rem" placeholder="Commerce, organisation, slogan, message, ambiance graphique..."></textarea>'+
    '<label style="display:block;margin-bottom:1rem"><input id="pub-premium-assistance" type="checkbox" checked> Assistance IA pour concevoir la page</label>'+
    '<p style="opacity:.8">La création comprendra un aperçu et jusqu’à deux retouches. Les parutions commenceront le lendemain de la commande validée.</p>'+
    '<button type="button" onclick="publicitePremiumEnregistrerBrouillon()" style="padding:.7rem 1rem;cursor:pointer">Préparer ma publicité gratuite</button>'+
    '<div id="pub-premium-retour" role="status" style="margin-top:.8rem"></div></div>';
  modal.classList.add('open');
}
async function publicitePremiumEnregistrerBrouillon(){
  const retour=document.getElementById('pub-premium-retour');
  const nom=state?.char?.name;
  const instructions=document.getElementById('pub-premium-texte')?.value.trim()||'';
  const formule=document.getElementById('pub-premium-formule')?.value;
  const assistance=document.getElementById('pub-premium-assistance')?.checked===true;
  if(!nom||instructions.length<10){if(retour)retour.textContent='Connectez votre personnage et décrivez la publicité (10 caractères minimum).';return;}
  if(retour)retour.textContent='Enregistrement du projet...';
  try{
    const res=await fetch(SUPABASE_URL+'/rest/v1/rpc/publicite_premium_creer_beta',{method:'POST',headers:sbEnTetes(),body:JSON.stringify({p_personnage:nom,p_formule:formule,p_instructions:instructions,p_assistance:assistance})});
    if(!res.ok)throw new Error('Enregistrement refusé ('+res.status+').');
    const id=await res.json();
    if(retour)retour.textContent='Projet enregistré (référence '+String(id).slice(0,8)+'). La génération et la diffusion seront accessibles après raccordement de l’atelier IA.';
  }catch(e){if(retour)retour.textContent=e.message||'Enregistrement impossible.';}
}
