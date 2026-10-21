// Une synchronisation sur connexion/reconnexion/interaction, jamais sur horloge.
// Ce module orchestre les lecteurs existants. Il ne valide ni ne rejoue un acte metier.
const RP_REALITES_LECTEURS = new Map();
let RP_REALITES_EN_COURS = null;
let RP_REALITES_LECTURE = false;
let RP_REALITES_REJEU = false;
let RP_REALITES_INTERACTION = false;
function rpRealitesContexte() {
  return {nom:state.char?.name,uid:typeof rpAuthUid==='function'?rpAuthUid():null,
    session:typeof rpAuthSessionIdentifiant==='function'?rpAuthSessionIdentifiant():(typeof rpAuthJeton==='function'?rpAuthJeton():null),
    pays:state.country,ville:state.currentCity,batiment:state.currentBuilding,piece:state.currentRoom,
    rue:typeof rueCentraleNoeudActuel==='undefined'?null:rueCentraleNoeudActuel};
}
function rpRealitesContexteValide(c,position=true) {
  const n=rpRealitesContexte();
  return c.nom===n.nom&&c.uid===n.uid&&c.session===n.session&&(!position||c.pays===n.pays&&c.ville===n.ville&&c.batiment===n.batiment&&c.piece===n.piece&&c.rue===n.rue);
}
function rpRealitesEnregistrer(nom,lecteur) { if(typeof lecteur==='function')RP_REALITES_LECTEURS.set(nom,lecteur); }
function rpRealitesLectureEnCours() { return RP_REALITES_LECTURE; }
// Observation des promesses du transport existant ; aucun appel ni rejeu supplementaire.
const RP_REALITES_REQUETES = new Set();
function rpRealitesRequeteCommencer(){
  let finir;const fin=new Promise(r=>finir=r),contexte=rpRealitesContexte();
  const entree={fin,contexte};RP_REALITES_REQUETES.add(entree);
  return ()=>{RP_REALITES_REQUETES.delete(entree);finir();};
}
async function rpRealitesAttendreRequetes(){
  const contexte=rpRealitesContexte();
  while(true){
    const presentes=[...RP_REALITES_REQUETES].filter(r=>r.contexte.nom===contexte.nom&&r.contexte.uid===contexte.uid);
    if(!presentes.length)return;
    await Promise.all(presentes.map(r=>r.fin));
    // Les continuations des handlers peuvent avoir enchaine une autre transaction.
    await new Promise(r=>setTimeout(r,0));
  }
}
async function rpRealitesRelirePersonnage(options={}) {
    const c=rpRealitesContexte(),generation=state._inventaireGeneration||0,revision=state._inventaireRevision;
    if(!c.uid)return {ok:false,raison:'session_perdue'};
    let minuteur;
    const fiche=await Promise.race([(async()=>{
      if(typeof sbSynchroniserImpactsRealites==='function'){
        const v=await sbSynchroniserImpactsRealites();
        if(v?.ok!==true||v.contrat!==1)throw new Error('impacts_non_confirmes');
        if(!rpRealitesContexteValide(c))return null;
      }
      return sbLoadPersonnage(c.nom);
    })(),new Promise(resolve=>{
      minuteur=setTimeout(()=>resolve(null),options.delaiLecture||10000);
    })]).finally(()=>clearTimeout(minuteur));
    if(!rpRealitesContexteValide(c))return {ok:false,raison:'contexte_obsolete'};
    if(!fiche||fiche.userId!==c.uid)return {ok:false,raison:'lecture_non_confirmee'};
    if(generation!==(state._inventaireGeneration||0))return {ok:false,raison:'inventaire_obsolete'};
    if(state._inventaireVersionne&&(!fiche._inventaireVersionne||!Number.isSafeInteger(fiche._inventaireRevision)))return {ok:false,raison:'inventaire_non_confirme'};
    if(Number.isSafeInteger(revision)&&Number.isSafeInteger(fiche._inventaireRevision)&&fiche._inventaireRevision<revision)return {ok:false,raison:'inventaire_obsolete'};
    RP_REALITES_LECTURE=true;
    try{
      // Meme mapping et memes miroirs que loadCharacter, sans recharger depuis localStorage.
      Object.assign(state,fiche);
      state._inventaireGeneration=generation+1;
      state._dernierUpdatedAtConnu=fiche.updatedAt||null;
      state._popEnvoye=fiche.pop;state._infEnvoye=fiche.inf;
      state.char.resources={inf:fiche.inf,pop:fiche.pop,dis:fiche.dis};
      state.char.arg=fiche.arg;state.char.pa=fiche.pa;
      if(typeof restaurerJournal==='function')restaurerJournal(state.char);
      if(options.peindre!==false){if(typeof updateUI==='function')updateUI({lecture:true});if(typeof updateLocationDisplay==='function')updateLocationDisplay();}
      return {ok:true,positionChangee:c.pays!==state.country||c.ville!==state.currentCity||c.batiment!==state.currentBuilding||c.piece!==state.currentRoom};
    }finally{RP_REALITES_LECTURE=false;}
}
async function rpRealitesSynchroniser(options={}) {
  if(RP_REALITES_EN_COURS)return RP_REALITES_EN_COURS;
  const travail=(async()=>{
    if(typeof rpAuthAssurerSession==='function')await rpAuthAssurerSession();
    if(state._chargementPersonnage)await state._chargementPersonnage;
    let attente;
    const disponible=await Promise.race([rpRealitesAttendreRequetes().then(()=>true),new Promise(r=>attente=setTimeout(()=>r(false),options.delaiLecture||10000))]).finally(()=>clearTimeout(attente));
    if(!disponible)return {ok:false,raison:'transaction_en_cours'};
    if(!state.char?.name)return {ok:false,raison:'personnage_absent'};
    if(typeof sbViderSauvegardeDifferee==='function'&&(await sbViderSauvegardeDifferee())===false)return {ok:false,raison:'sauvegarde_non_confirmee'};
    const c=rpRealitesContexte();
    const lecture=await rpRealitesRelirePersonnage(options);
    if(!lecture.ok)return lecture;
    try{
      const contexte=rpRealitesContexte();
      if(options.domaines!==false){
        // Les fonctions de reception existantes gardent leurs recus et controles atomiques.
        // Ordre sequentiel : pas de mutations concurrentes des miroirs d'un personnage.
        for(const [nom,lire] of RP_REALITES_LECTEURS){
          if(!rpRealitesContexteValide(contexte))return {ok:false,raison:'contexte_obsolete'};
          try{const verdict=await lire();if(verdict?.realiteNonConfirmee)return {ok:false,raison:'realite_non_confirmee'};}catch(_){console.warn('[Realites] Lecture non confirmee : '+nom);return {ok:false,raison:'realite_non_confirmee'};}
        }
        // Les receptions historiques peuvent avoir utilise la file existante de sauvegarde.
        // Ne pas autoriser un nouvel ordre avant leur confirmation, ni inventer un succes.
        if(typeof sbViderSauvegardeDifferee==='function'&&(await sbViderSauvegardeDifferee())===false)return {ok:false,raison:'sauvegarde_non_confirmee'};
        if(!rpRealitesContexteValide(contexte,false))return {ok:false,raison:'contexte_obsolete'};
      }
      return {ok:true,positionChangee:c.pays!==state.country||c.ville!==state.currentCity||c.batiment!==state.currentBuilding||c.piece!==state.currentRoom};
    }finally{RP_REALITES_LECTURE=false;}
  })().catch(()=>({ok:false,raison:'synchronisation_indisponible'}));
  RP_REALITES_EN_COURS=travail;
  try{return await travail;}finally{if(RP_REALITES_EN_COURS===travail)RP_REALITES_EN_COURS=null;}
}
async function rpRealitesAvantOrdre() {
  if(RP_REALITES_REJEU)return true;
  const v=await rpRealitesSynchroniser();
  if(!v.ok&&v.raison!=='contexte_obsolete'&&typeof showToast==='function')showToast('Synchronisation nécessaire','Votre situation serveur ne peut pas être confirmée. La commande demandée n’a pas été lancée.',false);
  return v.ok&&!v.positionChangee;
}
function rpRealitesInstaller(){
  // Le retour sur un onglet ne vaut pas reconnexion ni interaction : aucune lecture sur focus.
  window.addEventListener('online',()=>rpRealitesSynchroniser());
  window.addEventListener('pageshow',e=>{if(e.persisted)return rpRealitesSynchroniser();});
  for(const type of ['click','dblclick','submit','change','keydown'])document.addEventListener(type,async e=>{
    if(RP_REALITES_REJEU||e.defaultPrevented)return;
    if(type==='keydown'&&(e.key!=='Enter'||!e.target?.closest?.('[onkeydown]')))return;
    const activation=(type==='click'||type==='dblclick')?e.target?.closest?.('[onclick],[ondblclick],button,[role=button]'):e.target;
    const cible=activation?e.target:null;
    if(!cible||cible.matches?.('input[type=file],a[href]:not([onclick])'))return;
    if(!state.char?.name||!cible?.dispatchEvent)return;
    e.preventDefault();e.stopImmediatePropagation();
    if(RP_REALITES_INTERACTION)return; // jamais rejouer un second clic obsolete apres l'attente
    RP_REALITES_INTERACTION=true;
    let actualise=false;
    try{
      const v=await rpRealitesSynchroniser({peindre:false});
      if(!v.ok){if(v.raison!=='contexte_obsolete')showToast('Synchronisation nécessaire','Votre situation serveur n’a pas pu être confirmée. La commande demandée n’a pas été lancée.',false);return;}
      actualise=true;
      if(v.positionChangee){if(typeof updateLocationDisplay==='function')updateLocationDisplay();showToast('Situation actualisée','Votre position a changé sur le serveur. Consultez votre situation avant de reprendre cet ordre.',false);return;}
      if(!cible.isConnected)return;
      RP_REALITES_REJEU=true;
      try{
        // Conserver coordonnees/modificateurs/cible : la carte et les raccourcis en dependent.
        if(type==='click'||type==='dblclick')cible.dispatchEvent(new MouseEvent(type,{bubbles:true,cancelable:true,
          clientX:e.clientX,clientY:e.clientY,screenX:e.screenX,screenY:e.screenY,button:e.button,
          ctrlKey:e.ctrlKey,shiftKey:e.shiftKey,altKey:e.altKey,metaKey:e.metaKey,detail:e.detail}));
        else if(type==='keydown')cible.dispatchEvent(new KeyboardEvent(type,{bubbles:true,cancelable:true,key:e.key,code:e.code,
          ctrlKey:e.ctrlKey,shiftKey:e.shiftKey,altKey:e.altKey,metaKey:e.metaKey}));
        else cible.dispatchEvent(new Event(type,{bubbles:true,cancelable:true}));
      }finally{RP_REALITES_REJEU=false;}
    }finally{RP_REALITES_INTERACTION=false;if(actualise&&typeof updateUI==='function')updateUI({lecture:true});}
  },true);
}
if(typeof document!=='undefined')document.addEventListener('DOMContentLoaded',rpRealitesInstaller);
