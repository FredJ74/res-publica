// Achat mecanique distinct de la conversation : serveur, inventaire revisionne et recu UUID.
function cedT(key,original,vars){return window.RPDealerI18n?.text?.(key,original,vars)||String(original).replace(/\{([a-z]+)\}/g,(m,k)=>Object.hasOwn(vars||{},k)?String(vars[k]):m)}
function cedH(key,original,vars){return String(cedT(key,original,vars)).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));}
function cedNomAffiche(produit,nom){
 const d=DROGUES_DEALER[produit];
 if(!d)return nom||'';
 if(!nom||nom===d.nom)return cedT(produit==='brume'?'brumeName':'estadineName',d.nom);
 return nom;
}
function cedContexteValide(c) {
  return !!c && state.char === c.personnage && c.uid === rpAuthUid();
}
// 2 novembre 2026 (decisions de Fred) : les dealers vendent tous la meme chose. Un dealer par
// centre artisanal de Republia. Deux drogues fictives (aucune drogue reelle nommee) : la Brume
// (50 FR) et l'Estadine (120 FR), en stock limite par dealer (dealer_acheter, dealer_stocks_lire,
// migration 20261102210000). Prix, stock et objet sont decides par le serveur.
const DROGUES_DEALER = {
  brume: { nom: 'Pochon de Brume', prix: 50, texte: 'La Brume, l’herbe qui embrume la Républia.' },
  estadine: { nom: 'Pochon d’Estadine', prix: 120, texte: 'L’Estadine, poudre blanche venue d’El Estado. Un coup de fouet immédiat, une descente qui se paie cher.' }
};
const DEALERS_REPUBLIA = { capitale: "Céd' Labone", ville_a: 'Ronan Lafourgue', ville_b: 'Jojo Laferraille' };
function cedNomDealer() {
  return state.country === 'republic' ? (DEALERS_REPUBLIA[state.currentCity] || null) : null;
}
function cedSurPlace() {
  return !!cedNomDealer()
    && state.currentBuilding === 'centre-artisanal' && state.currentRoom === 'travees';
}
function cedCleReprise(produit) {
  return 'ced_achat_' + rpAuthUid() + '_' + state.char.name + '_' + produit;
}
// Fenetre du dealer : les deux produits, leur prix et le stock lu sur le serveur.
let CED_VUE=null;
async function ouvrirAchatCed() {
 if (!cedSurPlace() || !state.char || !rpAuthUid()) return;
 const acteur=state.char,uid=rpAuthUid();
 document.getElementById('modal-pnj')?.classList.remove('open');
 document.getElementById('postes-modal-title').textContent=cedNomDealer();
 const corps=document.getElementById('postes-body');
 corps.innerHTML='<div class="cpj-note" style="padding:1rem">'+cedH('loading',"Le dealer jette un œil à sa marchandise…")+'</div>';
 document.getElementById('modal-postes').classList.add('open');
 let stocks=null;
 try{stocks=await sbRpc('dealer_stocks_lire',{});}catch(_){stocks=null;}
 if(!cedSurPlace()||state.char!==acteur||rpAuthUid()!==uid)return;
 CED_VUE={stocks,acteur,uid,country:state.country,city:state.currentCity};
 cedAfficherStocks(stocks);
}
function cedAfficherStocks(stocks){
 const corps=document.getElementById('postes-body');
 if(!corps)return;
  let html = '<div data-ced-catalog="1" style="padding:1rem;display:grid;gap:1rem">';
  Object.keys(DROGUES_DEALER).forEach(function (produit) {
    const d = DROGUES_DEALER[produit];
    const s = stocks && stocks.ok ? stocks[produit] : null;
    const stock = s && typeof s.stock === 'number' ? s.stock : null;
    let precedente = null;
    try { precedente = sessionStorage.getItem(cedCleReprise(produit)); } catch (_) {}
    html += '<div style="display:grid;gap:.4rem"><p><b>'+cedH(produit==='brume'?'brumeName':'estadineName',d.nom)+'</b> — '+cedH(produit==='brume'?'brumeDesc':'estadineDesc',d.texte)+'</p>' +
      '<p class="cpj-note">' + d.prix + ' FR · '+cedH('oneSlot',"1 place")+' · '+
      (stock===null?cedH('stockUnknown',"stock inconnu"):(stock>0?cedH('inStock',"en stock : {stock}",{stock}):cedH('outOfStock',"rupture de stock")))+'</p>' +
      '<button id="ced-acheter-' + produit + '" class="pnj-action-btn" onclick="confirmerAchatCed(\'' + produit + '\')"' +
      (stock === 0 && !precedente ? ' disabled' : '') + '>' +
      (precedente?cedH('checkPurchase',"Vérifier cet achat"):cedH('buy',"Acheter — {price} FR",{price:d.prix})) + '</button></div>';
  });
  html += '<p class="cpj-note">'+cedH('illegalNotice',"Marchandise illégale : l’achat et le transport peuvent laisser des traces.")+'</p></div>';
  corps.innerHTML = html;
}
(window.RP_I18N_CHANGE_CALLBACKS=window.RP_I18N_CHANGE_CALLBACKS||[]).push(function(){
 const modal=document.getElementById('modal-postes'),corps=document.getElementById('postes-body'),v=CED_VUE;
 if(!v||!modal?.classList?.contains('open')||!corps?.querySelector?.('[data-ced-catalog="1"]')
   ||!cedSurPlace()||state.char!==v.acteur||rpAuthUid()!==v.uid
   ||state.country!==v.country||state.currentCity!==v.city)return;
 cedAfficherStocks(v.stocks);
});

async function confirmerAchatCed(produit) {
  produit = DROGUES_DEALER[produit] ? produit : 'brume';
  const d = DROGUES_DEALER[produit];
  let c = state._achatCed;
  if (!cedContexteValide(c) || c.termine || c.produit !== produit) {
    if (cedContexteValide(c) && c.enCours) return;
    let precedente = null;
    try { precedente = sessionStorage.getItem(cedCleReprise(produit)); } catch (_) {}
    c = { personnage: state.char, uid: rpAuthUid(), produit: produit, requete: precedente || crypto.randomUUID(),
      incertain: !!precedente, cleReprise: cedCleReprise(produit) };
    state._achatCed = c;
  }
  if (!cedContexteValide(c) || c.enCours || c.termine) return;
  if (!c.incertain && !cedSurPlace()) return;
  c.enCours = true;
  try { sessionStorage.setItem(c.cleReprise, c.requete); } catch (_) {}
  const bouton = document.getElementById('ced-acheter-' + produit);
  if (bouton) bouton.disabled = true;
  let r;
  try { r = await sbRpcVerdict('dealer_acheter', { p_requete: c.requete, p_produit: produit }); }
  catch (_) { r = null; }
  c.enCours = false;
  if (!cedContexteValide(c) || state._achatCed !== c) return;
  if (bouton) bouton.disabled = false;
  if (!r || r.transport) {
    c.incertain = true;
    if (bouton) bouton.textContent = cedT("checkPurchase","Vérifier cet achat");
    showToast(cedT("unconfirmed","Achat non confirmé"), cedT("retry","Vérifiez cet achat avant de recommencer. La même transaction sera relue."), false);
    return;
  }
  c.incertain = false;
  if (!r.ok) {
    try { sessionStorage.removeItem(c.cleReprise); } catch (_) {}
    const messages = { pas_sur_place: cedT("wrongPlace","Retrouvez le dealer dans les travées du centre artisanal."),
      inventaire_plein: cedT("inventoryFull","Il vous faut une place libre dans l’inventaire."),
      rupture_stock: cedT("noStock","Plus rien en stock pour aujourd’hui. Repassez demain."),
      fonds_insuffisants: cedT('insufficient',"Vos fonds disponibles ne couvrent pas les {price} FR.",{price:d.prix}),
      acteur_non_authentifie: cedT("auth","Reconnectez-vous avant de faire cet achat.") };
    showToast(cedT("refused","Achat refusé"), messages[r.raison] || cedT("tryAgain","L’achat n’a pas été validé. Réessayez."), false);
    return;
  }
  c.termine = true;
  try { sessionStorage.removeItem(c.cleReprise); } catch (_) {}
  appliquerPaiementServeur(r.paiement);
  let adopte = sbAdopterInventaireServeur(r);
  if (!adopte) {
    const frais = await sbRpc('inventaire_reception_etat', { p_acteur: c.personnage.name }).catch(() => null);
    if (!cedContexteValide(c)) return;
    adopte = !!frais?.ok && sbAdopterInventaireServeur(frais);
  }
  if (!cedContexteValide(c)) return;
  if (document.getElementById('ced-acheter-' + produit)) document.getElementById('modal-postes')?.classList.remove('open');
  const nom = cedNomAffiche(produit,r.nom), prix = r.prix || d.prix;
  if (!r.rejeu) addJournalEntry(cedT('purchaseJournal',"Achat auprès de {dealer} : {product}, {price} FR.",{dealer:r.dealer||cedNomDealer()||cedT('anonDealer',"un dealer"),product:nom,price:prix}), 'event-info');
  updateUI();
  showToast(cedT("bought","Achat enregistré"), adopte ? cedT('inventoryDelivered',"{product} dans votre inventaire. −{price} FR.",{product:nom,price:prix})
    : cedT("deliveryPending","La livraison est enregistrée. Actualisez pour relire votre inventaire."), true);
}

// DESCENTES D'ESTADINE (2 novembre 2026) : le serveur seul decide si une descente est echue
// (drogues_descentes_appliquer, horloge du serveur). L'ecran ne fait que le lui demander quand
// une descente en attente semble due, puis adopte moral, sante et effets rendus.
let descenteDrogueEnCours = false;
async function verifierDescentesDrogue() {
  if (descenteDrogueEnCours || !state.char || typeof sbRpc !== 'function') return;
  const due = (Array.isArray(state.effetsActifs) ? state.effetsActifs : []).some(function (e) {
    return e && e.descente && !e.descenteAppliquee && Number(e.descenteA) <= Date.now();
  });
  if (!due) return;
  descenteDrogueEnCours = true;
  try {
    const r = await sbRpc('drogues_descentes_appliquer', {});
    if (!r || r.ok !== true || !(r.appliquees > 0)) return;
    if (typeof r.moral === 'number') state.moral = r.moral;
    if (typeof r.hp === 'number') state.hp = r.hp;
    if (Array.isArray(r.effets_actifs)) state.effetsActifs = r.effets_actifs;
    const dd = r.descente || {};
    showToast(cedT("withdrawalTitle","La descente"), cedT('withdrawalNotice',"L’Estadine se paie : moral {moral}, santé {hp}, {pa} PA à la prochaine recharge.",{moral:dd.moral,hp:dd.hp,pa:dd.pa_differe}), false);
    addJournalEntry(cedT('withdrawalJournal',"Descente d’Estadine : moral {moral}, santé {hp}, {pa} PA à la prochaine recharge.",{moral:dd.moral,hp:dd.hp,pa:dd.pa_differe}), 'event-bad');
    if (typeof updateUI === 'function') updateUI();
  } catch (_) { /* reessaye au prochain passage */ }
  finally { descenteDrogueEnCours = false; }
}
if (typeof setInterval === 'function' && typeof window !== 'undefined') setInterval(verifierDescentesDrogue, 60000);
