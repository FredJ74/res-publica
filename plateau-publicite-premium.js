// Publicite premium presse : atelier beta. Aucun paiement n'est demande.
function ouvrirPublicitePremium() {
  const modal=document.getElementById('modal-postes');
  const titre=document.getElementById('postes-modal-title');
  const corps=document.getElementById('postes-body');
  if(!modal||!corps)return;
  if(titre)titre.textContent='Publicité premium — L’Autruche Entravée';
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
    '<label>Images de référence (5 maximum, PNG/JPEG/WebP, 5 Mo chacune)</label>'+
    '<input type="file" id="pub-premium-sources" accept="image/png,image/jpeg,image/webp" multiple style="display:block;margin:.5rem 0 1rem">' +
    '<label style="display:block;margin:.7rem 0"><input type="checkbox" id="pub-premium-droits"> Je confirme disposer des droits et autorisations nécessaires sur les images fournies, y compris pour les personnes reconnaissables. Je comprends que leurs originaux et leur provenance seront conservés à des fins de traçabilité et que les images litigieuses pourront être retirées.</label>'+
    '<label>Ou importer une affiche finale personnelle (sans IA)</label>'+
    '<input type="file" id="pub-premium-affiche" accept="image/png,image/jpeg,image/webp" style="display:block;margin:.5rem 0 1rem">' +
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
  if(!nom||(instructions.length<10&&!document.getElementById('pub-premium-affiche')?.files?.length)){if(retour)retour.textContent='Connectez votre personnage et décrivez la publicité (10 caractères minimum).';return;}
  if(retour)retour.textContent='Enregistrement du projet...';
  try{
    const res=await fetch(SUPABASE_URL+'/rest/v1/rpc/publicite_premium_creer_beta',{method:'POST',headers:sbEnTetes(),body:JSON.stringify({p_personnage:nom,p_formule:formule,p_instructions:instructions,p_assistance:assistance})});
    if(!res.ok)throw new Error('Enregistrement refusé ('+res.status+').');
    const id=await res.json();
    await publicitePremiumPreparerImages(String(id));
  }catch(e){if(retour)retour.textContent=e.message||'Enregistrement impossible.';}
}

async function publicitePremiumAction(id,action){
 const retour=document.getElementById('pub-premium-retour');
 if(!retour)return;
 let prompt='';
 if(action==='retouch'){prompt=window.prompt('Décrivez les modifications souhaitées (2 retouches maximum) :')||'';if(prompt.trim().length<10)return;}
 retour.textContent='Traitement en cours, veuillez patienter...';
 try{
  const res=await fetch(SUPABASE_URL+'/functions/v1/publicite-premium',{method:'POST',headers:sbEnTetes(),body:JSON.stringify({id,action,prompt})});
  const data=await res.json();
  if(!res.ok||!data.ok)throw Error(data.error||'Opération impossible');
  if(action==='finalize'){
   retour.textContent='Publicité validée et programmée du '+data.premiere_parution+' au '+data.derniere_parution+'.';
   return;
  }
  publicitePremiumAfficherApercu(id,data);
 }catch(e){retour.textContent='Erreur : '+e.message;}
}

// Telechargement de chaque apercu sans validation ni cout supplementaire.
async function publicitePremiumTelecharger(url){
 try{
  const response=await fetch(url);
  if(!response.ok)throw new Error('Image indisponible');
  const blob=await response.blob();
  const objectUrl=URL.createObjectURL(blob);
  const link=document.createElement('a');
  link.href=objectUrl;
  link.download='human-gambit-publicite-'+Date.now()+'.png';
  document.body.appendChild(link);
  link.click();
  link.remove();
  setTimeout(()=>URL.revokeObjectURL(objectUrl),10000);
 }catch(error){alert('Téléchargement impossible : '+error.message);}
}

async function publicitePremiumFichierBase64(file){
 if(!['image/png','image/jpeg','image/webp'].includes(file.type)||file.size>5242880)throw Error('Images PNG, JPEG ou WebP de 5 Mo maximum.');
 return new Promise((resolve,reject)=>{const reader=new FileReader();reader.onerror=()=>reject(Error('Lecture impossible'));reader.onload=()=>resolve(String(reader.result).split(',')[1]);reader.readAsDataURL(file);});
}
async function publicitePremiumAppeler(id,action,extra={}){
 const res=await fetch(SUPABASE_URL+'/functions/v1/publicite-premium',{method:'POST',headers:sbEnTetes(),body:JSON.stringify({id,action,...extra})});
 const data=await res.json();
 if(!res.ok||!data.ok)throw Error(data.error||'Opération refusée');
 return data;
}
async function publicitePremiumPreparerImages(id){
 const retour=document.getElementById('pub-premium-retour');
 const sources=Array.from(document.getElementById('pub-premium-sources')?.files||[]);
 const affiche=document.getElementById('pub-premium-affiche')?.files?.[0];
 const accepte=document.getElementById('pub-premium-droits')?.checked;
 if(sources.length>5)throw Error('Cinq images de référence maximum.');
 if((sources.length||affiche)&&!accepte)throw Error('Veuillez accepter les conditions relatives aux images fournies.');
 if(retour)retour.textContent='Préparation des images...';
 if(accepte)await publicitePremiumAppeler(id,'consent');
 for(const file of sources)await publicitePremiumAppeler(id,'upload_source',{filename:file.name,mime:file.type,base64:await publicitePremiumFichierBase64(file)});
 if(affiche){
  const data=await publicitePremiumAppeler(id,'import_final',{filename:affiche.name,mime:affiche.type,base64:await publicitePremiumFichierBase64(affiche)});
  publicitePremiumAfficherApercu(id,data);
 }else if(retour){
  retour.innerHTML=`Projet enregistré. <button type="button" onclick="publicitePremiumAction('${id}','generate')">Générer mon aperçu</button>`;
 }
}
function publicitePremiumAfficherApercu(id,data){
 const retour=document.getElementById('pub-premium-retour');
 if(!retour)return;
 const url=SUPABASE_URL+'/storage/v1/object/public/publicites-premium/'+data.path.split('/').map(encodeURIComponent).join('/');
 const remaining=2-data.retouches;
 retour.innerHTML=`<img src="${url}" alt="Aperçu publicitaire" style="display:block;max-width:100%;max-height:600px;margin:1rem auto">`+
 `<button type="button" onclick="publicitePremiumTelecharger('${url}')">Télécharger cette version</button> `+
 (remaining>0?`<button type="button" onclick="publicitePremiumAction('${id}','retouch')">Retoucher (${remaining} restante(s))</button> `:'')+
 `<button type="button" onclick="publicitePremiumAction('${id}','finalize')">Valider et programmer</button>`;

}

async function publicitePremiumVersions(id){
 const zone=document.getElementById('pub-premium-versions');if(!zone)return;
 try{
  const data=await publicitePremiumAppeler(id,'versions');
  zone.textContent='';
  for(const [i,v] of data.versions.entries()){
   const url=SUPABASE_URL+'/storage/v1/object/public/publicites-premium/'+v.image_path.split('/').map(encodeURIComponent).join('/');
   const b=document.createElement('button');b.type='button';b.textContent='Télécharger version '+(data.versions.length-i);
   b.onclick=()=>publicitePremiumTelecharger(url);zone.append(b);
  }
 }catch(e){zone.textContent=e.message;}
}
