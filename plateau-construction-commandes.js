// #94 : adaptateurs extraits du parcours commun existant, aucune regle metier nouvelle.
function constructionPeutGerer(ts){
  if(typeof estTitulaire==='function'&&estTitulaire(ts?.proprietaire))return true;
  const ref=ts?.proprietaire;
  if(ref==='ville:'+state.country+':'+state.currentCity)return state.char?.poste?.id==='maire'&&state.char?.poste?.city===state.currentCity;
  if(typeof ref==='string'&&ref.startsWith('orga:')&&typeof getOrgaById==='function')return getOrgaById(ref.slice(5))?.chef===state.char?.name;
  return false;
}
function constructionCleCommande(action,buildingId=state.currentBuilding,contexte=contexteNavigationRue()) {
  return 'chantier-commande:'+JSON.stringify([contexte.uid,contexte.nom,state.country,state.currentCity,buildingId,action]);
}
function constructionRelireIntention(action) {
  try { return JSON.parse(sessionStorage.getItem(constructionCleCommande(action)) || 'null'); }
  catch (_) { return null; }
}
let constructionCommandeEnCours=false;
async function constructionExecuterCommande(action,parametres={}){
  if(constructionCommandeEnCours)return null;
  const contexte=contexteNavigationRue(),id=state.currentBuilding;
  const cle=constructionCleCommande(action,id,contexte);
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
    const finance=typeof rafraichirRuntimeHelvetia==='function'?await rafraichirRuntimeHelvetia({exigerComptes:true}):null;
    if(!finance){showToast('Commande acquise','La relecture financière reste à confirmer. L’intention de reprise est conservée.',true);return null;}
    if(!contexteNavigationRueValide(contexte))return null;
    if(typeof finance.pa==='number'){state.pa=finance.pa;state.char.pa=finance.pa;}
    if(action==='louer') {
      const locations=typeof chargerLocations==='function'?await chargerLocations():false;
      if(!contexteNavigationRueValide(contexte))return null;
      if(!locations){showToast('Bail confirmé','La relecture du bail reste à confirmer. L’intention de reprise est conservée.',true);return null;}
    }
    sessionStorage.removeItem(cle);updateUI();return r;
  }finally{constructionCommandeEnCours=false;}
}
async function receptionnerChantier(){
  const r=await constructionExecuterCommande('receptionner');
  if(!r)return;
  showToast('Bâtiment réceptionné','Les locaux sont ouverts. Les reliquats sont conservés dans la caisse et le stock du bâtiment.',true,true);
  if(typeof rafraichirPiecesDynamiques==='function')rafraichirPiecesDynamiques(state.currentBuilding);
  if(typeof renderRoomActions==='function')renderRoomActions(BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom],state.currentBuilding,state.currentRoom);
}

let constructionRepriseEnCours=false;
async function constructionReconcilierCommandes(buildingId){
  if(typeof finance135Reconcilier==='function')await finance135Reconcilier();
  if(constructionRepriseEnCours||constructionCommandeEnCours||buildingId!==state.currentBuilding)return;
  const c=contexteNavigationRue();constructionRepriseEnCours=true;
  try{
    for(const action of ['lancer','verser','receptionner','plan','travailler','prix','reamenager','louer']){
      const cle=constructionCleCommande(action,buildingId,c);
      let i;try{i=JSON.parse(sessionStorage.getItem(cle)||'null');}catch(_){continue;}
      if(!i?.requete)continue;
      const r=await sbRpcVerdict('chantier_commande_recu',{p_requete:i.requete}).catch(()=>null);
      if(!contexteNavigationRueValide(c))return;
      if(r?.ok&&r.terminee){
        const finance=typeof rafraichirRuntimeHelvetia==='function'?await rafraichirRuntimeHelvetia({exigerComptes:true}):null;
        if(!finance||!contexteNavigationRueValide(c))return;
        if(typeof finance.pa==='number'){state.pa=finance.pa;state.char.pa=finance.pa;}
        if(action==='louer') {
          const locations=typeof chargerLocations==='function'?await chargerLocations():false;
          if(!contexteNavigationRueValide(c)||!locations)return;
        }
        sessionStorage.removeItem(cle);
      }
      // Absence non concluante : une autre transaction peut etre encore en cours. Garder l'intention.
    }
  }finally{constructionRepriseEnCours=false;}
}

if (typeof window !== 'undefined') {
  window.RP_ORDRES_DYNAMIQUES = window.RP_ORDRES_DYNAMIQUES || [];
  window.RP_ORDRES_DYNAMIQUES.push(function(id,piece) {
    if (!id?.startsWith('terrain-a-batir')) return [];
    const ts=getTerrainState(id),ch=ts.chantier || ts.chantierReamenagement;
    if (!constructionPeutGerer(ts)) return [];
    const plan={fn:'modifier_plan_chantier',label:'Définir les lots intérieurs',icon:'ti-layout-grid',pa:0,cost:0,type:'legal',successRate:100};
    if (!ch) return ts.niveau_construction && !ts.planInitialValide && !(ts.subdivisions||[]).length ? [plan] : [];
    if (!chantierTermine(ch)) {
      const ordres=[{fn:'prix_chantier',label:'Prix d’achat des matériaux',icon:'ti-coins',pa:0,cost:0,type:'legal',successRate:100}];
      if(ch.type!=='reamenagement' && verdictModificationPlan(ch).ok) ordres.push(plan);
      return ordres;
    }
    return [{fn:'receptionner_chantier',label:'Réceptionner le bâtiment',icon:'ti-key',pa:0,cost:0,type:'legal',successRate:100}];
  });
}

let constructionPrixEnCours=false;
function constructionEchapper(v){return String(v??'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;');}
function constructionFenetre(titre,html){
  document.getElementById('postes-modal-title').textContent=titre;
  document.getElementById('postes-body').innerHTML='<div class="construction-dossier">'+html+'</div>';
  document.getElementById('modal-postes').classList.add('open');
}
function constructionBouton(texte,js){return '<button type="button" class="construction-action" onclick="'+constructionEchapper(js)+'">'+constructionEchapper(texte)+'</button>';}
function ouvrirApprovisionnementChantier(){
  const ts=getTerrainState(state.currentBuilding),ch=ts.chantier || ts.chantierReamenagement;
  if(!ch||!chantierAccepteMateriaux(ch))return;
  const tarifs=['bois','minerai','metal'].map(m=>'<p>'+constructionEchapper(m)+' : '+constructionEchapper(ch.prixAchatPJ?.[m]??'entrepôt + 10 %, arrondi au franc supérieur, à confirmer par le serveur')+' FR/unité</p>').join('');
  constructionFenetre('Approvisionner le chantier',tarifs+constructionSousOrdre('vendre_materiaux_chantier','Vendre des matériaux',0,0)+constructionSousOrdre('donner_materiaux_chantier','Donner gratuitement des matériaux',0,0)+(constructionPeutGerer(ts)?constructionBouton('Fixer les prix d’achat','ouvrirPrixChantier()'):''));
}
function constructionSousOrdre(fn,label,pa,cost){return constructionBouton(label,'doOrder('+[JSON.stringify(fn),pa||0,cost||0,JSON.stringify(label),'""',100].join(',')+')');}
function ouvrirPrixChantier(){
  const ts=getTerrainState(state.currentBuilding);if(!constructionPeutGerer(ts))return;
  constructionFenetre('Prix d’achat des matériaux','<p>Prix en francs entiers uniquement. Les champs vides conservent les tarifs existants.</p>'+['bois','minerai','metal'].map(m=>'<label>'+m+' <input id="chantier-prix-'+m+'" inputmode="numeric" step="1" value="'+constructionEchapper((ts.chantier || ts.chantierReamenagement)?.prixAchatPJ?.[m]??'')+'"></label>').join('')+constructionBouton('Enregistrer les prix','confirmerPrixChantier()'));
}
async function confirmerPrixChantier(){
  if(constructionPrixEnCours)return;
  const contexte=contexteNavigationRue(),id=state.currentBuilding,prix={};
  try{for(const m of ['bois','minerai','metal']){const v=document.getElementById('chantier-prix-'+m)?.value?.trim();if(v)prix[m]=constructionFrancsEntiers(v);}}
  catch(_){showToast('Prix invalide','Utilisez un nombre entier de francs, positif ou nul.',false);return;}
  if(!Object.keys(prix).length)return;
  constructionPrixEnCours=true;
  try{
    const v=await constructionExecuterCommande('prix',{prix});
    if(!contexteNavigationRueValide(contexte))return;
    if(!v?.ok){showToast('Prix non confirmés','Les prix n’ont pas pu être confirmés par le serveur. Relisez-les avant de réessayer.',false);return;}
    await chargerTerrainState(id);if(contexteNavigationRueValide(contexte))ouvrirApprovisionnementChantier();
  }catch(_){if(contexteNavigationRueValide(contexte))showToast('Prix non confirmés','Relisez les prix sur le serveur avant de réessayer.',false);}
  finally{constructionPrixEnCours=false;}
}
