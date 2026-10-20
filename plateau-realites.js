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
    pays:state.country,ville:state.currentCity,batiment:state.currentBuilding,piece:state.currentRoom};
}
function rpRealitesContexteValide(c,position=true) {
  const n=rpRealitesContexte();
  return c.nom===n.nom&&c.uid===n.uid&&c.session===n.session&&(!position||c.pays===n.pays&&c.ville===n.ville&&c.batiment===n.batiment&&c.piece===n.piece);
}
function rpRealitesEnregistrer(nom,lecteur) { if(typeof lecteur==='function')RP_REALITES_LECTEURS.set(nom,lecteur); }
function rpRealitesLectureEnCours() { return RP_REALITES_LECTURE; }
async function rpRealitesSynchroniser(options={}) {
  if(RP_REALITES_EN_COURS)return RP_REALITES_EN_COURS;
  const travail=(async()=>{
    if(typeof rpAuthAssurerSession==='function')await rpAuthAssurerSession();
    if(state._chargementPersonnage)await state._chargementPersonnage;
    if(!state.char?.name)return {ok:false,raison:'personnage_absent'};
    if(typeof sbViderSauvegardeDifferee==='function')await sbViderSauvegardeDifferee();
    const c=rpRealitesContexte(),generation=state._inventaireGeneration||0,revision=state._inventaireRevision;
    if(!c.uid)return {ok:false,raison:'session_perdue'};
    let minuteur;
    const fiche=await Promise.race([sbLoadPersonnage(c.nom),new Promise(resolve=>{
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
      RP_REALITES_LECTURE=false;
      const contexte=rpRealitesContexte();
      if(options.domaines!==false){
        // Les fonctions de reception existantes gardent leurs recus et controles atomiques.
        // Ordre sequentiel : pas de mutations concurrentes des miroirs d'un personnage.
        for(const [nom,lire] of RP_REALITES_LECTEURS){
          if(!rpRealitesContexteValide(contexte))return {ok:false,raison:'contexte_obsolete'};
          try{await lire();}catch(_){console.warn('[Realites] Lecture non confirmee : '+nom);}
        }
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
  if(!v.ok&&v.raison!=='contexte_obsolete'&&typeof showToast==='function')showToast('Synchronisation nécessaire','Votre état serveur ne peut pas être confirmé. Réessayez après reconnexion.',false);
  return v.ok&&!v.positionChangee;
}
function rpRealitesInstaller(){
  // Le retour sur un onglet ne vaut pas reconnexion ni interaction : aucune lecture sur focus.
  window.addEventListener('online',()=>rpRealitesSynchroniser());
  window.addEventListener('pageshow',e=>{if(e.persisted)return rpRealitesSynchroniser();});
  for(const type of ['click','submit','change'])document.addEventListener(type,async e=>{
    if(RP_REALITES_REJEU||e.defaultPrevented)return;
    const cible=type==='click'?e.target?.closest?.('[onclick],button,[role=button]'):e.target;
    if(!cible||cible.matches?.('input[type=file],a[href]:not([onclick])'))return;
    if(!state.char?.name||!cible?.dispatchEvent)return;
    e.preventDefault();e.stopImmediatePropagation();
    if(RP_REALITES_INTERACTION)return; // jamais rejouer un second clic obsolete apres l'attente
    RP_REALITES_INTERACTION=true;
    let actualise=false;
    try{
      const v=await rpRealitesSynchroniser({peindre:false});
      if(!v.ok){if(v.raison!=='contexte_obsolete')showToast('Synchronisation nécessaire','Connexion ou session indisponible. Aucune commande de ce clic n’a été envoyée.',false);return;}
      actualise=true;
      if(v.positionChangee){if(typeof updateLocationDisplay==='function')updateLocationDisplay();showToast('Situation actualisée','Votre position a changé sur le serveur. Consultez votre situation avant de reprendre cet ordre.',false);return;}
      if(!cible.isConnected)return;
      RP_REALITES_REJEU=true;
      try{
        // click() conserve les actions natives (checkbox/lien/formulaire), sans recopier du code metier.
        if(type==='click'&&typeof cible.click==='function')cible.click();
        else cible.dispatchEvent(new Event(type,{bubbles:true,cancelable:true}));
      }finally{RP_REALITES_REJEU=false;}
    }finally{RP_REALITES_INTERACTION=false;if(actualise&&typeof updateUI==='function')updateUI({lecture:true});}
  },true);
}
if(typeof document!=='undefined')document.addEventListener('DOMContentLoaded',rpRealitesInstaller);
