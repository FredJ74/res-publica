// #66 : présentation commune des titres existants et des offres arrêtées par le serveur.
// Aucune autorisation, aucun prix de vente ou transfert n'est déduit du DOM.
function immobilierPrixReference(surface,tarif){
  if(typeof surface!=='number'||!Number.isFinite(surface)||surface<=0||typeof tarif!=='number'||!Number.isFinite(tarif)||tarif<0)return null;
  const valeur=surface*tarif;
  return Number.isSafeInteger(valeur)?valeur:null;
}
function immobilierCoutCompletComparaison(surface,tarif,terrain,chantier,obligatoires){
  const reference=immobilierPrixReference(surface,tarif);
  const montants=[terrain,chantier,...(Array.isArray(obligatoires)?obligatoires:[NaN])];
  if(reference===null||montants.some(n=>!Number.isSafeInteger(n)||n<0))return {verifiable:false};
  const total=montants.reduce((a,b)=>a+b,0);
  if(!Number.isSafeInteger(total))return {verifiable:false};
  return {verifiable:true,construction:total,reference,conforme:total<=reference};
}
function immobilierOffresRegrouper(offres){
 const biens=new Map();
 for(const offre of offres||[]){
  if(!offre||!['fonds','murs'].includes(offre.actif))continue;
  if(!biens.has(offre.bien_id))biens.set(offre.bien_id,[]);
  biens.get(offre.bien_id).push(offre);
 }
 const resultat=[];
 for(const groupe of biens.values()){
  resultat.push(...groupe.map(o=>({...o,offres:[o.id]})));
  const fonds=groupe.find(o=>o.actif==='fonds'),murs=groupe.find(o=>o.actif==='murs');
  if(fonds&&murs&&fonds.disponible&&murs.disponible){
   resultat.push({...fonds,actif:'ensemble',offres:[fonds.id,murs.id],vendeur_fonds:fonds.vendeur,vendeur_murs:murs.vendeur,
    prix_fonds:fonds.prix,prix_murs:murs.prix,prix_total:immobilierTotalExact(fonds.prix,murs.prix),surface:murs.surface});
  }
 }
 return resultat;
}
let immobilierCommandeEnCours=false;
let immobilierCatalogueCourant=[];
let immobilierOffreAConfirmer=null;
function immobilierContexte(){return contexteNavigationRue();}
function immobilierContexteValide(c){return contexteNavigationRueValide(c);}
function immobilierEchapper(t){return String(t??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));}
function immobilierTotalExact(a,b){if(!/^[0-9]+$/.test(String(a))||!/^[0-9]+$/.test(String(b)))return null;return (BigInt(a)+BigInt(b)).toString();}
function immobilierFenetre(titre,html){document.getElementById('postes-modal-title').textContent=titre;document.getElementById('postes-body').innerHTML='<div class="immobilier-offres">'+html+'</div>';document.getElementById('modal-postes').classList.add('open');}
async function ouvrirCatalogueImmobilier(){
 const c=immobilierContexte();
 await immobilierReconcilierActes(c);if(!immobilierContexteValide(c))return;
 const v=await sbImmobilierCatalogue(c.pays).catch(()=>null);
 if(!immobilierContexteValide(c))return;
 if(!v?.ok||!Array.isArray(v.offres)){showToast('Catalogue indisponible','Les offres du notaire n’ont pas pu être confirmées. Aucun acte effectué.',false);return;}
 immobilierCatalogueCourant=immobilierOffresRegrouper(v.offres);
 let html='<p>Les murs et le fonds sont deux propriétés indépendantes. Les baux en cours sont conservés lors de la vente des murs.</p>';
 for(const [i,o] of immobilierCatalogueCourant.entries()){
  const libelle={fonds:'Fonds de commerce',murs:'Murs / immobilier',ensemble:'Fonds + murs'}[o.actif];
  const prix=o.actif==='ensemble'?immobilierTotalExact(o.prix_fonds,o.prix_murs):String(o.prix);
  html+='<article class="immobilier-offre"><h3>'+libelle+' — '+immobilierEchapper(WORLD?.[o.pays]?.[o.ville]?.buildingContext?.[o.building_id]?.name||BUILDINGS?.[o.building_id]?.name||o.building_id)+'</h3>';
  html+='<p>Ville : '+immobilierEchapper(WORLD?.[o.pays]?.[o.ville]?.name||o.ville)+' · Surface des murs : '+immobilierEchapper(o.surface)+' m²</p>';
  if(o.actif==='ensemble')html+='<p>Fonds : '+immobilierEchapper(o.prix_fonds)+' FR — vendeur '+immobilierEchapper(o.vendeur_fonds)+'<br>Murs : '+immobilierEchapper(o.prix_murs)+' FR — vendeur '+immobilierEchapper(o.vendeur_murs)+'</p>';
  else html+='<p>Vendeur : '+immobilierEchapper(o.vendeur)+' · '+(o.regime==='libre_pj'?'Prix demandé par le propriétaire PJ':'Prix public / de référence')+'</p>';
  html+='<p>Prix '+(o.actif==='ensemble'?'total':'')+' : <strong>'+immobilierEchapper(prix)+' FR</strong> · Acte : 1 PA, sans frais supplémentaires en FR.</p>';
  if(o.prioritaire)html+='<p>Votre priorité court jusqu’au '+immobilierEchapper(new Date(o.priorite_fin).toLocaleString('fr-FR'))+'.</p>';
  html+='<p>'+(o.sous_compromis?'Sous compromis':(o.disponible?'Disponible':'Offre non ouverte dans votre situation'))+'</p>';
  if(o.disponible)html+='<button class="pnj-action-btn" onclick="preparerAchatImmobilier('+i+')">Préparer l’acte</button>';
  if(o.prioritaire)html+='<button class="pnj-action-btn" onclick="refuserPrioriteImmobiliere('+i+')">Refuser ma priorité</button>';
  html+='</article>';
 }
 html+='<button class="pnj-action-btn" onclick="ouvrirMesBiensImmobiliers()">Mettre un bien en vente</button>';
 immobilierFenetre('Catalogue notarial',html);return true;
}
async function immobilierReconcilierActes(c){
 const prefixe='immobilier-acte:';let cles=[];
 try{for(let i=0;i<sessionStorage.length;i++){const cle=sessionStorage.key(i);if(cle?.startsWith(prefixe))cles.push(cle);}}catch(_){return;}
 for(const cle of cles){
  if(!immobilierContexteValide(c))return;
  let contenu;try{contenu=JSON.parse(cle.slice(prefixe.length));}catch(_){continue;}
  if(contenu[0]!==c.uid||contenu[1]!==c.nom||contenu[2]!==c.pays)continue;
  const requete=sessionStorage.getItem(cle);if(!requete)continue;
  const v=await sbImmobilierActeEtat(requete).catch(()=>null);
  if(!immobilierContexteValide(c))return;
  if(!v?.ok||!v.termine||v.verdict?.ok!==true)continue;
  if(JSON.stringify([...(v.verdict.offres||[])].sort())!==JSON.stringify([...contenu[3]].sort()))continue;
  const fiche=typeof rafraichirRuntimeHelvetia==='function'?await rafraichirRuntimeHelvetia():null;
  if(!immobilierContexteValide(c))return;
  if(typeof fiche?.pa==='number')state.pa=fiche.pa;
  sessionStorage.removeItem(cle);
  showToast('Acte confirmé','Le notaire confirme l’acte dont la réponse avait été perdue. Aucun nouveau paiement.',true);
 }
}
function preparerAchatImmobilier(index){
 const o=immobilierCatalogueCourant[index];if(!o?.disponible)return;
 immobilierOffreAConfirmer={index,offre:{...o,offres:[...o.offres]},contexte:immobilierContexte()};
 const prix=o.actif==='ensemble'?immobilierTotalExact(o.prix_fonds,o.prix_murs):o.prix;
 immobilierFenetre('Confirmer l’acte notarial','<p>Actif : '+immobilierEchapper({fonds:'Fonds seul',murs:'Murs seuls',ensemble:'Fonds et murs'}[o.actif])+'</p><p>Prix : '+immobilierEchapper(prix)+' FR. Coût de l’acte : 1 PA.</p><p>L’achat des murs conserve le bail. L’achat du fonds suit ses règles de cession existantes.</p><button class="pnj-action-btn" onclick="confirmerAchatImmobilier('+index+')">Signer l’acte et payer</button>');
}
function immobilierCleReprise(c,offres){return 'immobilier-acte:'+JSON.stringify([c.uid,c.nom,c.pays,[...offres].sort()]);}
async function confirmerAchatImmobilier(index){
 if(immobilierCommandeEnCours)return;
 const prepare=immobilierOffreAConfirmer?.index===index?immobilierOffreAConfirmer:null;
 if(prepare&&!immobilierContexteValide(prepare.contexte))return;
 const offre=prepare?.offre||immobilierCatalogueCourant[index];if(!offre||!offre.disponible)return;
 const c=immobilierContexte(),cle=immobilierCleReprise(c,offre.offres);
 let requete;
 try{requete=sessionStorage.getItem(cle);if(!requete){requete=crypto.randomUUID();sessionStorage.setItem(cle,requete);}}
 catch(_){showToast('Acte non lancé','La reprise sûre de cet acte ne peut pas être enregistrée dans ce navigateur.',false);return;}
 immobilierCommandeEnCours=true;
 try{
  const v=await sbImmobilierActe(requete,offre.offres).catch(()=>null);
  if(!immobilierContexteValide(c))return;
  if(v?.ok!==true){showToast('Acte non confirmé',v?.transport?'La réponse est incertaine. La prochaine tentative vérifiera le même acte.':immobilierMotif(v?.raison),false);return;}
  sessionStorage.removeItem(cle);immobilierOffreAConfirmer=null;
  // Relecture des poches existantes ; aucun ancien solde d'un recu n'est recopie.
  const fiche=typeof rafraichirRuntimeHelvetia==='function'?await rafraichirRuntimeHelvetia():null;
  if(!immobilierContexteValide(c))return;
  if(typeof fiche?.pa==='number')state.pa=fiche.pa;
  if(typeof chargerLocations==='function')await chargerLocations();
  if(!immobilierContexteValide(c))return;
  if(typeof updateUI==='function')updateUI();
  if(typeof renderInventory==='function')renderInventory();
  showToast('Acte signé','Les titres achetés ont été transférés. Les baux sont conservés.',true);
  await ouvrirCatalogueImmobilier();
 }finally{immobilierCommandeEnCours=false;}
}
function immobilierMotif(raison){return ({priorite_exploitant:'Cette offre est encore réservée à l’exploitant.',occupation_modifiee:'L’occupation a changé : le notaire doit actualiser l’offre.',titre_modifie:'Le propriétaire a changé. Relisez le catalogue.',offre_vendue:'Cette offre a déjà été vendue.',fonds_insuffisants:'Fonds insuffisants : aucun achat partiel.',fiche_incomplete:'La fiche du bien doit être complétée avant sa vente.',pas_chez_notaire:'Rendez-vous au bureau des contrats du notaire.',pret_en_attente:'La décision de prêt est encore attendue.',compromis_expire:'Le compromis a expiré.',cession_imprimerie_a_raccorder:'La cession de cette imprimerie doit être raccordée au circuit existant.',pas_proprietaire:'Vous n’êtes pas titulaire de ce droit.'})[raison]||'Le serveur n’a pas autorisé cet acte. Aucun succès ne peut être confirmé.';}
async function refuserPrioriteImmobiliere(index){
 if(immobilierCommandeEnCours)return;const offre=immobilierCatalogueCourant[index];if(!offre?.prioritaire)return;
 const c=immobilierContexte();immobilierCommandeEnCours=true;
 try{const v=await sbImmobilierRefuser(offre.id).catch(()=>null);if(!immobilierContexteValide(c))return;if(!v?.ok){showToast('Réponse non confirmée',immobilierMotif(v?.raison),false);return;}await ouvrirCatalogueImmobilier();}
 finally{immobilierCommandeEnCours=false;}
}
let immobilierBiensCourants=[];
async function ouvrirMesBiensImmobiliers(){
 const c=immobilierContexte(),v=await sbImmobilierBiens(c.pays).catch(()=>null);if(!immobilierContexteValide(c))return;
 if(!v?.ok){showToast('Biens indisponibles','Les titres doivent être relus sur le serveur.',false);return;}
 immobilierBiensCourants=v.biens;let html='';
 for(const [i,b]of v.biens.entries()){
  html+='<article class="immobilier-offre"><h3>'+immobilierEchapper(b.building_id)+'</h3><p>'+immobilierEchapper(b.ville)+' · '+(b.surface===null?'Surface à valider':immobilierEchapper(b.surface)+' m²')+'</p><p>Murs : '+immobilierEchapper(b.proprietaire_murs)+' · Fonds : '+immobilierEchapper(b.proprietaire_fonds)+'</p>';
  if(b.surface!==null)for(const actif of ['fonds','murs'])if(b['peut_vendre_'+actif])html+='<button class="pnj-action-btn" onclick="preparerOffreImmobiliere('+i+',\''+actif+'\')">Proposer '+(actif==='fonds'?'le fonds':'les murs')+'</button>';
  html+='</article>';
 }
 immobilierFenetre('Mettre un bien en vente',html||'<p>Aucun titre raccordé à proposer.</p>');
}
function preparerOffreImmobiliere(index,actif){
 const b=immobilierBiensCourants[index];if(!b||!['fonds','murs'].includes(actif)||!b['peut_vendre_'+actif])return;
 const proprietaire=b['proprietaire_'+actif],libre=proprietaire===state.char?.name||proprietaire==='pj:'+state.char?.name;
 immobilierFenetre('Proposer '+(actif==='fonds'?'le fonds':'les murs'),'<p>Les prix libres des PJ ne sont pas plafonnés par la référence publique. Les baux survivent à la vente des murs.</p>'+
  (libre?'<label>Prix demandé en FR <input id="immobilier-prix" type="text" inputmode="numeric"></label>':'<p>Le prix de référence sera vérifié par le serveur.</p>')+
  '<button class="pnj-action-btn" onclick="deposerOffreImmobiliere('+index+',\''+actif+'\','+libre+')">Déposer chez le notaire</button>');
}
async function deposerOffreImmobiliere(index,actif,libre){
 if(immobilierCommandeEnCours)return;const b=immobilierBiensCourants[index];if(!b)return;
 const prix=libre?document.getElementById('immobilier-prix')?.value?.trim():null;
 if(libre&&!/^[0-9]+$/.test(prix||'')){showToast('Prix invalide','Indiquez un montant en francs entiers, positif ou nul.',false);return;}
 const c=immobilierContexte(),cle='immobilier-offre:'+JSON.stringify([c.uid,c.nom,b.id,actif,prix]);let id;
 try{id=sessionStorage.getItem(cle)||crypto.randomUUID();sessionStorage.setItem(cle,id);}catch(_){showToast('Dépôt non lancé','La reprise sûre du dépôt ne peut pas être enregistrée.',false);return;}
 immobilierCommandeEnCours=true;
 try{const v=await sbImmobilierDeposer(id,b.id,actif,prix).catch(()=>null);if(!immobilierContexteValide(c))return;if(!v?.ok){showToast('Offre non confirmée',immobilierMotif(v?.raison),false);return;}sessionStorage.removeItem(cle);await ouvrirCatalogueImmobilier();}
 finally{immobilierCommandeEnCours=false;}
}

// Un ancien compromis conserve son acompte et ses clauses ; son acte utilise le socle commun.
// Retour true = pris en charge ou lecture incertaine : ne jamais essayer un autre debit.
async function immobilierReprendreCompromis(entreprise){
 const c=immobilierContexte(),v=await sbImmobilierBiens(c.pays).catch(()=>null);
 if(!immobilierContexteValide(c))return true;
 if(!v?.ok||!Array.isArray(v.biens)){showToast('Acte non lancé','Le raccordement du titre doit être confirmé par le notaire.',false);return true;}
 const bien=v.biens.find(b=>b.entreprise_id===entreprise.id);
 if(!bien)return false; // ancien actif non raccorde : moteur historique inchange
 const catalogueLu=await ouvrirCatalogueImmobilier();if(!immobilierContexteValide(c)||!catalogueLu)return true;
 const index=immobilierCatalogueCourant.findIndex(o=>o.bien_id===bien.id&&o.actif==='fonds'&&o.disponible);
 if(index<0){showToast('Acte non lancé','L’offre du fonds doit être complétée ou rendue disponible chez le notaire. Votre compromis reste conservé.',false);return true;}
 preparerAchatImmobilier(index);return true;
}
