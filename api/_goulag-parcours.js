'use strict';
// Domaine du goulag : toutes ces règles sont pures et doivent être exécutées
// dans une RPC transactionnelle. Un client ne peut attester un poste ou un lieu.
class RefusParcours extends Error {
  constructor(code) { super(code); this.code=code; this.name='RefusParcours'; }
}
const refuser = code => {throw new RefusParcours(code);};
const ENTREE = Object.freeze({
  starovka:Object.freeze({ville:'ville_a',progressions:7,minimumPA:7,noeud:'starovka-rue-stade'}),
  krasnov:Object.freeze({ville:'ville_b',progressions:10,minimumPA:10,noeud:null})
});
const entier = n => Number.isSafeInteger(n) && n>=0;
const copie = obj => JSON.parse(JSON.stringify(obj));
function verifierCondamnation({juge,cible,jugement}) {
  if (!juge || juge.country!=='soviet' || juge.poste!=='juge' || juge.titulaireConfirmeServeur!==true)
    refuser('reserve_juge_sovarka');
  if (!cible || !jugement || jugement.country!=='soviet'
      || jugement.accuse!==cible || jugement.juge!==juge.nom
      || jugement.genre!=='qhs' || jugement.verdict!=='condamnation'
      || !jugement.affaireValideeServeur || !entier(jugement.jours)
      || jugement.jours===0) refuser('condamnation_invalide');
  return {cible,pays:'soviet',destination:'qhs',jugementId:jugement.id,jours:jugement.jours};
}
function verifierVoyage({acteur,destination,habilitation}) {
  if (!acteur || acteur.country!=='soviet'
      || !['capitale','ville_a','ville_b'].includes(acteur.city)
      || !acteur.dansCentreMultimodalServeur) refuser('depart_non_autorise');
  if (destination!=='qhs') refuser('destination_invalide');
  if (acteur.detenu) refuser('detenu_transport_interdit');
  const direct=['min_just','pm','juge'].includes(acteur.poste)
      && acteur.postePays==='soviet' && acteur.posteVerifieServeur===true;
  const autorise=habilitation && habilitation.etat==='accordee'
      && habilitation.personnage===acteur.nom && habilitation.pays==='soviet'
      && habilitation.signeeParMinistreServeur===true
      && habilitation.valideServeur===true;
  if (!direct && !autorise) refuser('autorisation_goulag_requise');
  return {pays:'soviet',ville:'qhs',batiment:'qhs-prison',piece:'entree_qhs'};
}
function confisquer({inventaire,isCle,detentionId}) {
  if (!detentionId || !Array.isArray(inventaire) || typeof isCle!=='function')
    refuser('inventaire_invalide');
  const conserve=[],depot=[];
  for (const obj of inventaire) {
    if (!obj || typeof obj!=='object' || Array.isArray(obj)) refuser('objet_invalide');
    (isCle(obj)?conserve:depot).push(copie(obj));
  }
  return {detentionId,conserve,depot,etatDepot:'confisque'};
}
function cloreDepot(depot,mode) {
  if (!depot || !Array.isArray(depot.conserve) || !Array.isArray(depot.depot)
      || !['confisque','restitue','perdu'].includes(depot.etatDepot)) refuser('depot_invalide');
  if (!['liberation','evasion'].includes(mode)) refuser('mode_invalide');
  const fin=mode==='liberation'?'restitue':'perdu';
  if (depot.etatDepot!== 'confisque') {
    if (depot.etatDepot===fin) return {etatDepot:fin,aRestituer:[],dejaTraite:true};
    refuser('depot_deja_clos');
  }
  return {etatDepot:fin,aRestituer:mode==='liberation'?copie(depot.depot):[],dejaTraite:false};
}
function debuterMarche({destination,statut,pa,presenceServeur,peineRestante}) {
  const route=ENTREE[destination];
  if (!route) refuser('destination_invalide');
  if (!['detenu','visiteur'].includes(statut) || presenceServeur!==true)
    refuser('depart_non_autorise');
  if (!entier(pa) || pa<route.minimumPA) refuser('pa_insuffisants_depart');
  if (statut==='detenu' && (!Number.isFinite(peineRestante) || peineRestante<0))
    refuser('peine_invalide');
  return {destination,statut,pa,progressions:0,irreversible:true,
    peineGelee:statut==='detenu'?peineRestante:null,
    recherche:statut==='detenu',perteDepot:statut==='detenu'};
}
function arriver({marche,paApresProgression,noeudKrasnovVerifie}) {
  const route=marche && ENTREE[marche.destination];
  if (!route || !marche.irreversible || marche.progressions!==route.progressions
      || !entier(paApresProgression) || paApresProgression<1)
    refuser('arrivee_invalide');
  const noeud=marche.destination==='starovka'?route.noeud:noeudKrasnovVerifie;
  if (typeof noeud!=='string' || !noeud) refuser('arrivee_non_referencee');
  return {pays:'soviet',ville:route.ville,batiment:null,piece:null,
    rue:noeud,pa:1,reposForceJours:3,statut:marche.statut,
    recherche:marche.statut==='detenu',peineGelee:marche.peineGelee??null};
}
function heberger({refuge,nuit,bois}) {
  if (!refuge || !entier(refuge.nuits) || refuge.nuits>2
      || !entier(refuge.dernierJour) || !entier(bois))
    refuser('refuge_invalide');
  if (!entier(nuit) || nuit<1 || nuit>3) refuser('jour_refuge_invalide');
  if (refuge.nuits>=2 || nuit!==refuge.nuits+1 || nuit<=refuge.dernierJour)
    refuser('nuit_deja_prise');
  const cout=nuit===1?5:3;
  if (bois<cout) refuser('bois_insuffisant');
  return {nuits:refuge.nuits+1,dernierJour:nuit,coutBois:cout,boisRestant:bois-cout};
}
function regleNonArbitree(action) {
  if (['penalite_champignons','arrestation_hotel_hopital','autorisation_validite'].includes(action))
    refuser('arbitrage_game_designer_requis');
  refuser('action_inconnue');
}
module.exports={ENTREE,RefusParcours,verifierCondamnation,verifierVoyage,
  confisquer,cloreDepot,debuterMarche,arriver,heberger,regleNonArbitree};
