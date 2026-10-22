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
function constructionPeutGerer(ts){
  if(typeof estTitulaire==='function'&&estTitulaire(ts?.proprietaire))return true;
  const ref=ts?.proprietaire;
  if(ref==='ville:'+state.country+':'+state.currentCity)return state.char?.poste?.id==='maire'&&state.char?.poste?.city===state.currentCity;
  if(typeof ref==='string'&&ref.startsWith('orga:')&&typeof getOrgaById==='function')return getOrgaById(ref.slice(5))?.chef===state.char?.name;
  return false;
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
  return constructionMenusTerrain(ts,constructionPeutGerer(ts));
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
function ouvrirApprovisionnementChantier(){
  const ts=getTerrainState(state.currentBuilding),ch=ts.chantier;
  if(!ch||!chantierAccepteMateriaux(ch))return;
  const tarifs=['bois','minerai','metal'].map(m=>'<p>'+constructionEchapper(m)+' : '+constructionEchapper(ch.prixAchatPJ?.[m]??'entrepôt + 10 %, arrondi au franc supérieur, à confirmer par le serveur')+' FR/unité</p>').join('');
  constructionFenetre('Approvisionner le chantier',tarifs+constructionSousOrdre('vendre_materiaux_chantier','Vendre des matériaux',0,0)+constructionSousOrdre('donner_materiaux_chantier','Donner gratuitement des matériaux',0,0)+(estTitulaire(ts.proprietaire)?constructionBouton('Fixer les prix d’achat','ouvrirPrixChantier()'):''));
}
function ouvrirPrixChantier(){
  const ts=getTerrainState(state.currentBuilding);if(!estTitulaire(ts.proprietaire))return;
  constructionFenetre('Prix d’achat des matériaux','<p>Prix en francs entiers uniquement. Les champs vides conservent les tarifs existants.</p>'+['bois','minerai','metal'].map(m=>'<label>'+m+' <input id="chantier-prix-'+m+'" inputmode="numeric" step="1" value="'+constructionEchapper(ts.chantier?.prixAchatPJ?.[m]??'')+'"></label>').join('')+constructionBouton('Enregistrer les prix','confirmerPrixChantier()'));
}
let constructionPrixEnCours=false;
async function confirmerPrixChantier(){
  if(constructionPrixEnCours)return;
  const contexte=contexteNavigationRue(),id=state.currentBuilding,prix={};
  try{for(const m of ['bois','minerai','metal']){const v=document.getElementById('chantier-prix-'+m)?.value?.trim();if(v)prix[m]=constructionFrancsEntiers(v);}}
  catch(_){showToast('Prix invalide','Utilisez un nombre entier de francs, positif ou nul.',false);return;}
  if(!Object.keys(prix).length)return;
  constructionPrixEnCours=true;
  try{
    const v=await sbRpcVerdict('chantier_prix_definir',{p_terrain_id:id,p_prix:prix},{encoreValide:()=>contexteNavigationRueValide(contexte)});
    if(!contexteNavigationRueValide(contexte))return;
    if(!v?.ok){showToast('Prix non confirmés','Les prix n’ont pas pu être confirmés par le serveur. Relisez-les avant de réessayer.',false);return;}
    await chargerTerrainState(id);if(contexteNavigationRueValide(contexte))ouvrirApprovisionnementChantier();
  }catch(_){if(contexteNavigationRueValide(contexte))showToast('Prix non confirmés','Relisez les prix sur le serveur avant de réessayer.',false);}
  finally{constructionPrixEnCours=false;}
}
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

// Intentions techniques persistantes, transport/auth et relectures existants. Aucun delta financier.
let constructionCommandeEnCours=false;
async function constructionExecuterCommande(action,parametres={}){
  if(constructionCommandeEnCours)return null;
  const contexte=contexteNavigationRue(),id=state.currentBuilding;
  const cle='chantier-commande:'+JSON.stringify([contexte.uid,contexte.nom,state.country,state.currentCity,id,action]);
  let intention;
  try{
    const stockee=sessionStorage.getItem(cle);
    intention=stockee?JSON.parse(stockee):{requete:'ch-'+crypto.randomUUID(),parametres};
    if(JSON.stringify(intention.parametres)!==JSON.stringify(parametres)){
      showToast('Commande en attente','Reprenez d’abord la commande précédente avec les mêmes paramètres pour vérifier son résultat.',false);return null;
    }
    sessionStorage.setItem(cle,JSON.stringify(intention));
  }catch(_){showToast('Commande non lancée','La reprise sûre de cette opération ne peut pas être enregistrée.',false);return null;}
  constructionCommandeEnCours=true;
  try{
    const r=await sbRpcVerdict('chantier_commande',{p_requete:intention.requete,p_terrain_id:id,p_action:action,p_parametres:intention.parametres}).catch(()=>null);
    if(!contexteNavigationRueValide(contexte))return null;
    if(!r?.ok){
      // Ne pas perdre l'intention sur une erreur HTTP/transport dont le resultat est inconnu.
      if(r&&!r.transport)sessionStorage.removeItem(cle);
      showToast('Commande non confirmée',r?.transport||!r?'La réponse est incertaine. Reprenez la même commande pour vérifier son résultat sans second traitement.':(r.raison||'Le serveur a refusé cette commande.'),false);return null;
    }
    // Le recu peut etre ancien : relire le terrain et les finances, jamais adopter son snapshot.
    const frais=await chargerTerrainState(id,true);
    if(!contexteNavigationRueValide(contexte))return null;
    if(!frais){showToast('Commande acquise','Le serveur a confirmé l’opération, mais son état actualisé reste à relire. L’intention de reprise est conservée.',true);return null;}
    if(typeof commercePjActualiserPersonnage==='function')await commercePjActualiserPersonnage();
    if(!contexteNavigationRueValide(contexte))return null;
    sessionStorage.removeItem(cle);updateUI();return r;
  }finally{constructionCommandeEnCours=false;}
}
async function receptionnerChantier(){
  const r=await constructionExecuterCommande('receptionner');
  if(!r)return;
  showToast('Bâtiment réceptionné','Les locaux sont ouverts. Les reliquats sont conservés dans la caisse et le stock du bâtiment.',true,true);
  if(typeof hydraterPiecesDynamiques==='function')hydraterPiecesDynamiques();
  if(typeof renderBuilding==='function')renderBuilding();
}

let constructionRepriseEnCours=false;
async function constructionReconcilierCommandes(buildingId){
  if(constructionRepriseEnCours||constructionCommandeEnCours||buildingId!==state.currentBuilding)return;
  const c=contexteNavigationRue();constructionRepriseEnCours=true;
  try{
    for(const action of ['lancer','verser','receptionner']){
      const cle='chantier-commande:'+JSON.stringify([c.uid,c.nom,state.country,state.currentCity,buildingId,action]);
      let i;try{i=JSON.parse(sessionStorage.getItem(cle)||'null');}catch(_){continue;}
      if(!i?.requete)continue;
      const r=await sbRpcVerdict('chantier_commande_recu',{p_requete:i.requete}).catch(()=>null);
      if(!contexteNavigationRueValide(c))return;
      if(r?.ok&&r.terminee){
        if(typeof commercePjActualiserPersonnage==='function')await commercePjActualiserPersonnage();
        if(!contexteNavigationRueValide(c))return;
        sessionStorage.removeItem(cle);
      }
      // Absence non concluante : une autre transaction peut etre encore en cours. Garder l'intention.
    }
  }finally{constructionRepriseEnCours=false;}
}
