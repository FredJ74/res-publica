// Publicite premium presse : atelier beta. Aucun paiement n'est demande.
function pubT(key,fr,vars){const tr=window.RPPremiumAdsI18n?.text;return typeof tr==='function'?tr(key,fr,vars):String(fr).replace(/\{([a-z]+)\}/g,(m,k)=>Object.hasOwn(vars||{},k)?String(vars[k]):m)}
function pubHT(key,fr,vars){const str=pubT(key,fr,vars);return typeof escapeHtmlText==='function'?escapeHtmlText(str):str.replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));}
function ouvrirPublicitePremium() {
  const modal=document.getElementById('modal-postes');
  const titre=document.getElementById('postes-modal-title');
  const corps=document.getElementById('postes-body');
  if(!modal||!corps)return;
  if(titre)titre.textContent=pubT('title',"Publicité premium — L’Autruche Entravée");
  corps.innerHTML='<div style="padding:1rem;max-width:680px;margin:auto">'+
    '<h3>'+pubHT("fullPage","Votre pleine page publicitaire")+'</h3>'+
    '<p>'+pubHT("beta","Offre bêta : création gratuite. La facturation Stripe sera activée ultérieurement.")+'</p>'+
    '<label for="pub-premium-formule">'+pubHT("campaign","Campagne")+'</label>'+
    '<select id="pub-premium-formule" style="display:block;width:100%;padding:.6rem;margin:.4rem 0 1rem">'+
    '<option value="cinq">'+pubHT("five","5 parutions — gratuit en bêta (futur tarif 4,99 €)")+'</option>'+
    '<option value="dix">'+pubHT("ten","10 parutions — gratuit en bêta (futur tarif 7,99 €)")+'</option></select>'+
    '<label for="pub-premium-texte">'+pubHT("describe","Décrivez votre publicité")+'</label>'+
    '<textarea id="pub-premium-texte" rows="5" maxlength="1500" style="display:block;width:100%;padding:.6rem;margin:.4rem 0 1rem" placeholder="'+pubHT("placeholder","Commerce, organisation, slogan, message, ambiance graphique...")+'"></textarea>'+
    '<label style="display:block;margin-bottom:1rem"><input id="pub-premium-assistance" type="checkbox" checked> '+pubHT("assist","Assistance IA pour concevoir la page")+'</label>'+
    '<label>'+pubHT("refs","Images de référence (5 maximum, PNG/JPEG/WebP, 5 Mo chacune)")+'</label>'+
    '<input type="file" id="pub-premium-sources" accept="image/png,image/jpeg,image/webp" multiple style="display:block;margin:.5rem 0 1rem">' +
    '<label style="display:block;margin:.7rem 0"><input type="checkbox" id="pub-premium-droits"> '+pubHT("rights","Je confirme disposer des droits et autorisations nécessaires sur les images fournies, y compris pour les personnes reconnaissables. Je comprends que leurs originaux et leur provenance seront conservés à des fins de traçabilité et que les images litigieuses pourront être retirées.")+'</label>'+
    '<label>'+pubHT("ownPoster","Ou importer une affiche finale personnelle (sans IA)")+'</label>'+
    '<input type="file" id="pub-premium-affiche" accept="image/png,image/jpeg,image/webp" style="display:block;margin:.5rem 0 1rem">' +
    '<p style="opacity:.8">'+pubHT("previewNote","La création comprendra un aperçu et jusqu’à deux retouches. Les parutions commenceront le lendemain de la commande validée.")+'</p>'+
    '<button type="button" onclick="publicitePremiumEnregistrerBrouillon()" style="padding:.7rem 1rem;cursor:pointer">'+pubHT("prepare","Préparer ma publicité gratuite")+'</button>'+
    '<div id="pub-premium-retour" role="status" style="margin-top:.8rem"></div></div>';
  modal.classList.add('open');
}
async function publicitePremiumEnregistrerBrouillon(){
  const retour=document.getElementById('pub-premium-retour');
  const nom=state?.char?.name;
  const instructions=document.getElementById('pub-premium-texte')?.value.trim()||'';
  const formule=document.getElementById('pub-premium-formule')?.value;
  const assistance=document.getElementById('pub-premium-assistance')?.checked===true;
  if(!nom||(instructions.length<10&&!document.getElementById('pub-premium-affiche')?.files?.length)){if(retour)retour.textContent=pubT("login","Connectez votre personnage et décrivez la publicité (10 caractères minimum), ou importez votre affiche finale.");return;}
  const sources=Array.from(document.getElementById('pub-premium-sources')?.files||[]);
  const affiche=document.getElementById('pub-premium-affiche')?.files?.[0];
  if(sources.length>5){if(retour)retour.textContent=pubT("maxFive","Cinq images de référence maximum.");return;}
  if((sources.length||affiche)&&!document.getElementById('pub-premium-droits')?.checked){if(retour)retour.textContent=pubT("accept","Veuillez accepter les conditions relatives aux images fournies.");return;}
  if(retour)retour.textContent=pubT("saving","Enregistrement du projet...");
  try{
    const res=await fetch(SUPABASE_URL+'/rest/v1/rpc/publicite_premium_creer_beta',{method:'POST',headers:sbEnTetes(),body:JSON.stringify({p_personnage:nom,p_formule:formule,p_instructions:instructions||'Affiche personnelle importée sans génération IA.',p_assistance:assistance})});
    if(!res.ok)throw new Error(pubT('recordDenied',"Enregistrement refusé ({status}).",{status:res.status}));
    const id=await res.json();
    await publicitePremiumPreparerImages(String(id));
  }catch(e){if(retour)retour.textContent=e.message||pubT("saveFailed","Enregistrement impossible.");}
}

async function publicitePremiumAction(id,action){
 const retour=document.getElementById('pub-premium-retour');
 if(!retour)return;
 let prompt='';
 if(action==='retouch'){prompt=window.prompt(pubT('retouchPrompt',"Décrivez les modifications souhaitées (2 retouches maximum) :"))||'';if(prompt.trim().length<10)return;}
 retour.textContent=pubT("working","Traitement en cours, veuillez patienter...");
 try{
  const res=await fetch(SUPABASE_URL+'/functions/v1/publicite-premium',{method:'POST',headers:sbEnTetes(),body:JSON.stringify({id,action,prompt})});
  const data=await res.json();
  if(!res.ok||!data.ok)throw Error(data.error||pubT("operationFailed","Opération impossible"));
  if(action==='finalize'){
   retour.innerHTML=`${pubHT("validated","Publicité validée et programmée du {start} au {end}.",{start:data.premiere_parution,end:data.derniere_parution})} <button type="button" onclick="publicitePremiumVersions('${id}')">${pubHT("downloadVersions","Télécharger mes versions")}</button><div id="pub-premium-versions"></div>`;
   return;
  }
  publicitePremiumAfficherApercu(id,data);
 }catch(e){retour.textContent=pubT('error',"Erreur : {reason}",{reason:e.message});}
}

// Telechargement de chaque apercu sans validation ni cout supplementaire.
async function publicitePremiumTelecharger(url){
 try{
  const response=await fetch(url);
  if(!response.ok)throw new Error(pubT("imageUnavailable","Image indisponible"));
  const blob=await response.blob();
  const objectUrl=URL.createObjectURL(blob);
  const link=document.createElement('a');
  link.href=objectUrl;
  const extension=blob.type==='image/jpeg'?'jpg':blob.type==='image/webp'?'webp':'png';
  link.download='human-gambit-publicite-'+Date.now()+'.'+extension;
  document.body.appendChild(link);
  link.click();
  link.remove();
  setTimeout(()=>URL.revokeObjectURL(objectUrl),10000);
 }catch(error){alert(pubT('downloadFailed',"Téléchargement impossible : {reason}",{reason:error.message}));}
}

async function publicitePremiumFichierBase64(file){
 if(!['image/png','image/jpeg','image/webp'].includes(file.type)||file.size>5242880)throw Error(pubT("formats","Images PNG, JPEG ou WebP de 5 Mo maximum."));
 return new Promise((resolve,reject)=>{const reader=new FileReader();reader.onerror=()=>reject(Error(pubT("readFailed","Lecture impossible")));reader.onload=()=>resolve(String(reader.result).split(',')[1]);reader.readAsDataURL(file);});
}
async function publicitePremiumAppeler(id,action,extra={}){
 const res=await fetch(SUPABASE_URL+'/functions/v1/publicite-premium',{method:'POST',headers:sbEnTetes(),body:JSON.stringify({id,action,...extra})});
 const data=await res.json();
 if(!res.ok||!data.ok)throw Error(data.error||pubT("operationDenied","Opération refusée"));
 return data;
}
async function publicitePremiumPreparerImages(id){
 const retour=document.getElementById('pub-premium-retour');
 const sources=Array.from(document.getElementById('pub-premium-sources')?.files||[]);
 const affiche=document.getElementById('pub-premium-affiche')?.files?.[0];
 const accepte=document.getElementById('pub-premium-droits')?.checked;
 if(sources.length>5)throw Error(pubT("maxFive","Cinq images de référence maximum."));
 if((sources.length||affiche)&&!accepte)throw Error(pubT("accept","Veuillez accepter les conditions relatives aux images fournies."));
 if(retour)retour.textContent=pubT("preparing","Préparation des images...");
 if(accepte)await publicitePremiumAppeler(id,'consent');
 for(const file of sources)await publicitePremiumAppeler(id,'upload_source',{filename:file.name,mime:file.type,base64:await publicitePremiumFichierBase64(file)});
 if(affiche){
  const data=await publicitePremiumAppeler(id,'import_final',{filename:affiche.name,mime:affiche.type,base64:await publicitePremiumFichierBase64(affiche)});
  publicitePremiumAfficherApercu(id,data);
 }else if(retour){
  retour.innerHTML=`${pubHT("saved","Projet enregistré.")} <button type="button" onclick="publicitePremiumAction('${id}','generate')">${pubHT("generate","Générer mon aperçu")}</button>`;
 }
}
function publicitePremiumAfficherApercu(id,data){
 const retour=document.getElementById('pub-premium-retour');
 if(!retour)return;
 const url=SUPABASE_URL+'/storage/v1/object/public/publicites-premium/'+data.path.split('/').map(encodeURIComponent).join('/');
 const remaining=2-data.retouches;
 retour.innerHTML=`<img src="${url}" alt="${pubHT("previewAlt","Aperçu publicitaire")}" style="display:block;max-width:100%;max-height:600px;margin:1rem auto">`+
 `<button type="button" onclick="publicitePremiumTelecharger('${url}')">${pubHT("downloadThis","Télécharger cette version")}</button> `+
 (remaining>0?`<button type="button" onclick="publicitePremiumAction('${id}','retouch')">${pubHT("retouch","Retoucher ({count} restante(s))",{count:remaining})}</button> `:'')+
 `<button type="button" onclick="publicitePremiumAction('${id}','finalize')">${pubHT("finalize","Valider et programmer")}</button> `+
 `<button type="button" onclick="publicitePremiumVersions('${id}')">${pubHT("allVersions","Toutes mes versions")}</button><div id="pub-premium-versions"></div>`;

}

async function publicitePremiumVersions(id){
 const zone=document.getElementById('pub-premium-versions');if(!zone)return;
 try{
  const data=await publicitePremiumAppeler(id,'versions');
  zone.textContent='';
  for(const [i,v] of data.versions.entries()){
   const url=SUPABASE_URL+'/storage/v1/object/public/publicites-premium/'+v.image_path.split('/').map(encodeURIComponent).join('/');
   const b=document.createElement('button');b.type='button';b.textContent=pubT('downloadVersion',"Télécharger version {number}",{number:data.versions.length-i});
   b.onclick=()=>publicitePremiumTelecharger(url);zone.append(b);
  }
 }catch(e){zone.textContent=e.message;}
}
