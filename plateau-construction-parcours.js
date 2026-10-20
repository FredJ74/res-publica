// Parcours immobilier : composition des ordres existants, aucun debit ni moteur de location ici.
const CONSTRUCTION_ORDRES_AVANT_VENTE = ['acheter_terrain','signer_compromis','racheter_terrain'];
const CONSTRUCTION_ORDRES_INTRUS = ['negocier_squatteurs','appeler_police_terrain','faire_disparaitre_cadavre','neutraliser_squatteurs'];
const CONSTRUCTION_ORDRES_CHANTIER = ['construire_sur_terrain','payer_versement_chantier','travailler_chantier','vendre_materiaux_chantier','modifier_plan_chantier','corrompre_chantier','voler_materiel_chantier','diviser_construction','reconfigurer_lots','louer_lot_ici','gerer_lot_loue','gerer_fonds_commerce','deposer_demande_permis','corrompre_rdv_notaire'];
function constructionOrdre(fn,label,icon,extra) {
  return Object.assign({fn,label,icon:icon||'ti-building',pa:0,cost:0,type:'legal',successRate:100},extra||{});
}
function constructionImageTerrainNu(pays,id,etat) {
  return pays==='republic' && id?.startsWith('terrain-a-batir') && !etat?.chantier && !etat?.niveau_construction
    ? 'images/terrain-a-vendre-republic.webp' : null;
}
// Donnees propres a la parcelle, jamais derivees de son numero ou d'une image.
function constructionReferenceTerrain(id,etat) {
  const ts=etat||{},batiment=BUILDINGS[id],roomId=Object.keys(batiment?.rooms||{})[0];
  const room=batiment?.rooms?.[roomId],ctx=typeof getBuildingContext==='function'?getBuildingContext(id):null;
  const ordres=typeof ordresDeclaresDeLaPiece==='function'?ordresDeclaresDeLaPiece(room,ctx,roomId):(room?.orders||[]);
  const achat=ordres.find(o=>o.fn==='acheter_terrain');
  const surface=Number(ts.surface??(typeof SURFACE_TERRAINS!=='undefined'?SURFACE_TERRAINS[id]:null));
  const brut=ts.valeur_totale??ts.achatDirect?.prix??achat?.cost;
  const prix=brut!==null && brut!==undefined && Number.isFinite(Number(brut)) && Number(brut)>=0?Number(brut):null;
  return {surface:Number.isFinite(surface)&&surface>0?surface:null,prix};
}
function constructionMenusTerrain(ts,proprietaire) {
  const ordres=[],ch=ts.chantier;
  const masque=[...CONSTRUCTION_ORDRES_AVANT_VENTE,...CONSTRUCTION_ORDRES_INTRUS,...CONSTRUCTION_ORDRES_CHANTIER];
  if(!ts.proprietaire && !ts.niveau_construction && !ch)ordres.push(constructionOrdre('achat_terrains','Achat de terrains','ti-home-plus'));
  if(!ts.proprietaire && ['squatter_cool','squatter_agr','cadavre'].includes(ts.pnj))ordres.push(constructionOrdre('gestion_intrus','Gestion des intrus','ti-users'));
  if(ch){
    ordres.push(constructionOrdre('information_chantier','Information sur le chantier','ti-info-circle'));
    if(typeof chantierTermine==='function' && chantierTermine(ch)){
      if(proprietaire)ordres.push(constructionOrdre('receptionner_chantier','Fin du chantier — Réceptionner','ti-key'));
    }else{
      ordres.push(constructionOrdre('approvisionner_chantier_menu','Approvisionner le chantier','ti-truck-delivery'));
      ordres.push(constructionOrdre('travailler_chantier','Travailler sur le chantier','ti-hammer'));
      if(proprietaire && typeof verdictModificationPlan==='function' && verdictModificationPlan(ch).ok)ordres.push(constructionOrdre('modifier_plan_chantier','Diviser les lots intérieurs','ti-layout-grid'));
    }
  }else if(ts.niveau_construction){
    ordres.push(constructionOrdre('information_locaux','Information sur les locaux','ti-building-store'));
    if(proprietaire)ordres.push(constructionOrdre('reconfigurer_lots','Réorganiser les lots','ti-layout-grid'));
  }else if(proprietaire)ordres.push(constructionOrdre('construire_sur_terrain','Démarrage du chantier','ti-building'));
  if(ordres.length)ordres[0].masque=masque;
  else ordres.push(constructionOrdre('information_chantier','Information sur le terrain','ti-info-circle',{masque}));
  return ordres;
}
function ordresConstructionParcours(id,room){
  if(state.country!=='republic')return [];
  if(id==='mairie-capitale' && state.currentCity==='capitale'){
    if(room==='hall_mairie')return [constructionOrdre('demarches_administratives','Démarches administratives','ti-files',{masque:['etat_civil','consulter_indices_locaux']})];
    if(['bureau_maire','bureau_maire_adjoint'].includes(room))return [constructionOrdre('consulter_indices_locaux','Consulter les caisses communales','ti-chart-histogram',{requiresPost:['maire','maire_adjoint']})];
  }
  if(!id?.startsWith('terrain-a-batir') || room!==Object.keys(BUILDINGS[id]?.rooms||{})[0])return [];
  const ts=getTerrainState(id);
  return constructionMenusTerrain(ts,typeof estTitulaire==='function' && estTitulaire(ts.proprietaire));
}
function constructionEchapper(v){return String(v??'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;');}
function constructionFenetre(titre,html){
  document.getElementById('postes-modal-title').textContent=titre;
  document.getElementById('postes-body').innerHTML='<div class="construction-dossier">'+html+'</div>';
  document.getElementById('modal-postes').classList.add('open');
}
function constructionBouton(texte,js){return '<button type="button" class="construction-action" onclick="'+constructionEchapper(js)+'">'+constructionEchapper(texte)+'</button>';}
function constructionSousOrdre(fn,label,pa,cost){return constructionBouton(label,'doOrder('+[JSON.stringify(fn),pa||0,cost||0,JSON.stringify(label),'""',100].join(',')+')');}
function ouvrirDemarchesAdministratives(){
  constructionFenetre('Démarches administratives',constructionBouton('Déposer un permis de construire — 1 PA · 100 FR','ouvrirChoixTerrainPermis()')+constructionBouton('État civil','ouvrirEtatCivil()'));
}
async function ouvrirChoixTerrainPermis(){
  const pays=state.country,ville=state.currentCity,personnage=state.char;
  const ids=(WORLD[pays]?.[ville]?.buildings||[]).filter(id=>id.startsWith('terrain-a-batir'));
  await Promise.all(ids.map(id=>chargerTerrainState(id)));
  if(state.country!==pays||state.currentCity!==ville||state.char!==personnage)return;
  const possibles=ids.filter(id=>{const t=getTerrainState(id);return estTitulaire(t.proprietaire)||(t.compromis && t.compromisPar===personnage?.name);});
  constructionFenetre('Terrain concerné par le permis',possibles.map(id=>constructionBouton(BUILDINGS[id]?.name||id,'choisirTerrainPermis('+JSON.stringify(id)+')')).join('')||'<p>Aucun titre ou compromis à votre nom dans cette commune.</p>');
}
function choisirTerrainPermis(id){state._ordreEnCours='deposer_demande_permis';return doDeposerDemandePermis(1,100,id);}
function ouvrirAchatTerrains(){
  const ts=getTerrainState(state.currentBuilding);if(ts.proprietaire)return;
  constructionFenetre('Achat de terrains',constructionSousOrdre('acheter_terrain','Acheter directement',2,1000)+constructionSousOrdre('signer_compromis','Signer un compromis',2,1000)+constructionSousOrdre('racheter_terrain','Faire une offre de rachat',2,0));
}
function ouvrirGestionIntrus(){
  const t=getTerrainState(state.currentBuilding);let h='';
  if(['squatter_cool','squatter_agr'].includes(t.pnj))h+=constructionSousOrdre('negocier_squatteurs','Négocier le départ',0,0)+constructionSousOrdre('neutraliser_squatteurs','Neutraliser les squatteurs',0,0);
  if(['squatter_cool','squatter_agr','cadavre'].includes(t.pnj))h+=constructionSousOrdre('appeler_police_terrain','Appeler la police',0,0);
  if(t.pnj==='cadavre')h+=constructionSousOrdre('faire_disparaitre_cadavre','Faire disparaître le corps',2,0);
  constructionFenetre('Gestion des intrus',h||'<p>Aucun intrus présent.</p>');
}
function ouvrirInformationChantier(){
  const t=getTerrainState(state.currentBuilding),ch=t.chantier;
  constructionFenetre('Information sur le chantier','<p>Propriétaire : '+constructionEchapper(t.proprietaire||'Terrain non vendu')+'</p>'+(ch?'<p>'+constructionEchapper(ch.niveau||ch.type)+' · '+constructionEchapper(ch.progressionJours||0)+' / '+constructionEchapper(ch.dureeJours)+' jours utiles</p><p>Trésorerie : '+constructionEchapper(ch.tresorerie||0)+' FR · Financement : '+constructionEchapper(ch.totalVerse||0)+' / '+constructionEchapper(ch.coutTotal||0)+' FR</p><p>État : '+constructionEchapper(ch.arrete||'Travaux en cours')+'</p>':'<p>Aucun chantier en cours.</p>'));
}
function ouvrirApprovisionnementChantier(){constructionFenetre('Approvisionner le chantier',constructionSousOrdre('vendre_materiaux_chantier','Vendre des matériaux',0,0)+constructionSousOrdre('donner_materiaux_chantier','Donner gratuitement des matériaux',0,0));}
function ouvrirInformationLocaux(){
  const t=getTerrainState(state.currentBuilding);
  const lots=t.subdivisions||[];
  constructionFenetre('Information sur les locaux','<p>Propriétaire : '+constructionEchapper(t.proprietaire)+'</p>'+constructionBouton('Écrire au propriétaire','constructionEcrireProprietaire()')+lots.map(l=>'<p>'+constructionEchapper(l.label)+' · '+constructionEchapper(l.surface)+' m² · '+constructionEchapper(l.loyer||0)+' FR/jour · '+constructionEchapper(typeof locataireDuLot==='function'?(locataireDuLot(state.currentBuilding,l)||'Disponible'):'À vérifier')+'</p>').join('')+'<p>Les locaux accessibles figurent dans les onglets du bâtiment.</p>');
}
function constructionEcrireProprietaire(){const nom=getTerrainState(state.currentBuilding).proprietaire;if(nom&&typeof composerMailPour==='function')composerMailPour(nom);}
window.RP_ORDRES_DYNAMIQUES=window.RP_ORDRES_DYNAMIQUES||[];
window.RP_ORDRES_DYNAMIQUES.push(ordresConstructionParcours);

function memoriserVisiteTerrain(id,ts){
  if(!id?.startsWith('terrain-a-batir'))return;
  const visite={pnj:ts.pnj??null,pnjData:ts.pnjData??null,occupationInitialisee:ts.occupationInitialisee===true,
    occupationScellee:!!(ts.occupationScellee||ts.proprietaire||ts.compromis),enqueteJusqua:ts.enqueteJusqua||null,policeInterventionAt:ts.policeInterventionAt||null,policeAppellee:ts.policeAppellee||null};
  try{sessionStorage.setItem('terrain_occupation_visite_'+state.country+'_'+id,JSON.stringify(visite));}catch(e){}
}
function terminerVisiteTerrain(id){
  if(!id?.startsWith('terrain-a-batir'))return;
  const ts=getTerrainState(id);
  if(ts.proprietaire||ts.compromis||ts.occupationScellee||ts.pnj)return;
  setTerrainState(id,{occupationInitialisee:false});
  try{sessionStorage.removeItem('terrain_occupation_visite_'+state.country+'_'+id);}catch(e){}
}
// Adaptateur de verdict uniquement : aucun jet, paiement, combat ou sanction parallele.
function consequencesNeutralisationSquatteurs(score){
  if(!Number.isFinite(score)||score<0||score>100)return null;
  return score<50?{issue:'defaite'}:score<90?{issue:'neutralisation',trace:'delit'}:{issue:'cadavres',trace:'crime'};
}
function ouvrirNeutralisationSquatteurs(){
  const ts=getTerrainState(state.currentBuilding);
  if(!['squatter_cool','squatter_agr'].includes(ts.pnj))return;
  // Le moteur civil actuel ne rend pas le jet final atteste demande par #57.
  // Ne pas rejouer un assassinat aux seuils differents ni facturer un combat incomplet.
  showToast('Combat non raccordé','La neutralisation attend le contrat serveur du combat commun. Aucun PA ni FR prélevé.',false);
}
