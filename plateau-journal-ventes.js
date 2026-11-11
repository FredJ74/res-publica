// #96 : lecture des preuves de vente dans le journal existant, aucune transaction commerciale.
function journalVentesTexte(cle,fr,vars){
 const t=window.RPSharedSalesDinnerI18n?.text;
 return typeof t==='function'?t(cle,fr,vars):String(fr).replace(/\{([a-z]+)\}/g,(m,k)=>Object.hasOwn(vars||{},k)?String(vars[k]):m);
}
let journalVentesLecture=null,journalVentesContexte=null,journalVentesEvenements=[];
function journalVentesIdentite(){return JSON.stringify([typeof rpAuthUid==='function'?rpAuthUid():null,state.char?.name,typeof rpAuthSessionIdentifiant==='function'?rpAuthSessionIdentifiant():null]);}
function journalVentesPeindre(){
 const journal=document.getElementById('journal');if(!journal)return;
 journal.querySelectorAll('[data-vente-journal]').forEach(n=>n.remove());
 if(journalVentesContexte!==journalVentesIdentite())return;
 const ech=t=>String(t??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 for(const v of journalVentesEvenements){
  const div=document.createElement('div');div.className='journal-entry';div.dataset.venteJournal=v.id;
  const texte=journalVentesTexte('saleEntry','{buyer} a acheté dans votre commerce « {shop} » {quantity}{product} au prix de {amount} FR.',{
   buyer:String(v.acheteur).replace(/^pj:/,''),shop:v.enseigne,quantity:v.quantite>1?v.quantite+' × ':'',product:v.article,amount:v.montant
  });
  div.innerHTML='<span class="journal-time">'+ech(typeof formaterHorodatageJournal==='function'?formaterHorodatageJournal(v.ts):v.ts)+'</span><span class="journal-text event-external">'+ech(texte)+'</span>';
  journal.appendChild(div);
 }
}
async function chargerJournalVentes(acquitter=false){
 if(!state.char?.name||typeof rpAuthUid!=='function'||!rpAuthUid())return false;
 if(journalVentesLecture){await journalVentesLecture;if(acquitter)return chargerJournalVentes(true);return false;}
 const identite=journalVentesIdentite();
 const operation=(async()=>{
  const r=await sbRpcVerdict('journal_ventes_lire',{p_acquitter:acquitter}).catch(()=>null);
  if(identite!==journalVentesIdentite())return false;
  if(!r?.ok){if(acquitter&&typeof showToast==='function')showToast(journalVentesTexte('saleUnavailable','Journal des ventes indisponible'),journalVentesTexte('saleRetry','La lecture et son acquittement ne sont pas confirmés. Réessayez.'),false);return false;}
  journalVentesContexte=identite;journalVentesEvenements=r.evenements||[];journalVentesPeindre();
  if(r.nonLues>0&&typeof signalerEvenementJournal==='function')signalerEvenementJournal();
  return acquitter && r.nonLues===0;
 })();
 journalVentesLecture=operation;
 try{return await operation;}finally{if(journalVentesLecture===operation)journalVentesLecture=null;}
}
function initialiserJournalVentes(){
 journalVentesPeindre();
 if(journalVentesContexte!==journalVentesIdentite())void chargerJournalVentes(false);
}
// Les autres joueurs ecrivent le serveur ; aucun navigateur inactif n'est interroge.
if(typeof rpRealitesEnregistrer==='function')rpRealitesEnregistrer('journal-ventes',()=>chargerJournalVentes(false));
else document.addEventListener('click',()=>{void chargerJournalVentes(false);});

// Changer de langue ne doit jamais relire ni acquitter les ventes.
if(typeof window.i18next?.on==='function')window.i18next.on('languageChanged',()=>journalVentesPeindre());
