// #96 : lecture des preuves de vente dans le journal existant, aucune transaction commerciale.
let journalVentesLecture=null,journalVentesContexte=null,journalVentesEvenements=[];
function journalVentesIdentite(){return JSON.stringify([typeof rpAuthUid==='function'?rpAuthUid():null,state.char?.name,typeof rpAuthSessionIdentifiant==='function'?rpAuthSessionIdentifiant():null]);}
function journalVentesPeindre(){
 const journal=document.getElementById('journal');if(!journal)return;
 journal.querySelectorAll('[data-vente-journal]').forEach(n=>n.remove());
 if(journalVentesContexte!==journalVentesIdentite())return;
 const ech=t=>String(t??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 for(const v of journalVentesEvenements){
  const div=document.createElement('div');div.className='journal-entry';div.dataset.venteJournal=v.id;
  const texte=String(v.acheteur).replace(/^pj:/,'')+' a acheté dans votre commerce « '+v.enseigne+' » '+(v.quantite>1?v.quantite+' × ':'')+v.article+' au prix de '+v.montant+' FR.';
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
  if(!r?.ok){if(acquitter&&typeof showToast==='function')showToast('Journal des ventes indisponible','La lecture et son acquittement ne sont pas confirmés. Réessayez.',false);return false;}
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
