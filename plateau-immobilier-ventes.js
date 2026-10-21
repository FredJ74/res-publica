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
    prix_fonds:fonds.prix,prix_murs:murs.prix,prix_total:Number(fonds.prix)+Number(murs.prix),surface:murs.surface});
  }
 }
 return resultat;
}
