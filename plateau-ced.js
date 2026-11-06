// Achat mecanique distinct de la conversation : serveur, inventaire revisionne et recu UUID.
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
async function ouvrirAchatCed() {
  if (!cedSurPlace() || !state.char || !rpAuthUid()) return;
  document.getElementById('modal-pnj')?.classList.remove('open');
  document.getElementById('postes-modal-title').textContent = cedNomDealer();
  const corps = document.getElementById('postes-body');
  corps.innerHTML = '<div class="cpj-note" style="padding:1rem">Le dealer jette un œil à sa marchandise…</div>';
  document.getElementById('modal-postes').classList.add('open');
  let stocks = null;
  try { stocks = await sbRpc('dealer_stocks_lire', {}); } catch (_) { stocks = null; }
  if (!cedSurPlace()) return;
  let html = '<div style="padding:1rem;display:grid;gap:1rem">';
  Object.keys(DROGUES_DEALER).forEach(function (produit) {
    const d = DROGUES_DEALER[produit];
    const s = stocks && stocks.ok ? stocks[produit] : null;
    const stock = s && typeof s.stock === 'number' ? s.stock : null;
    let precedente = null;
    try { precedente = sessionStorage.getItem(cedCleReprise(produit)); } catch (_) {}
    html += '<div style="display:grid;gap:.4rem"><p><b>' + d.nom + '</b> — ' + d.texte + '</p>' +
      '<p class="cpj-note">' + d.prix + ' FR · 1 place · ' +
      (stock === null ? 'stock inconnu' : (stock > 0 ? 'en stock : ' + stock : 'rupture de stock')) + '</p>' +
      '<button id="ced-acheter-' + produit + '" class="pnj-action-btn" onclick="confirmerAchatCed(\'' + produit + '\')"' +
      (stock === 0 && !precedente ? ' disabled' : '') + '>' +
      (precedente ? 'Vérifier cet achat' : 'Acheter — ' + d.prix + ' FR') + '</button></div>';
  });
  html += '<p class="cpj-note">Marchandise illégale : l’achat et le transport peuvent laisser des traces.</p></div>';
  corps.innerHTML = html;
}
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
    if (bouton) bouton.textContent = 'Vérifier cet achat';
    showToast('Achat non confirmé', 'Vérifiez cet achat avant de recommencer. La même transaction sera relue.', false);
    return;
  }
  c.incertain = false;
  if (!r.ok) {
    try { sessionStorage.removeItem(c.cleReprise); } catch (_) {}
    const messages = { pas_sur_place: 'Retrouvez le dealer dans les travées du centre artisanal.',
      inventaire_plein: 'Il vous faut une place libre dans l’inventaire.',
      rupture_stock: 'Plus rien en stock pour aujourd’hui. Repassez demain.',
      fonds_insuffisants: 'Vos fonds disponibles ne couvrent pas les ' + d.prix + ' FR.',
      acteur_non_authentifie: 'Reconnectez-vous avant de faire cet achat.' };
    showToast('Achat refusé', messages[r.raison] || 'L’achat n’a pas été validé. Réessayez.', false);
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
  const nom = r.nom || d.nom, prix = r.prix || d.prix;
  if (!r.rejeu) addJournalEntry('Achat auprès de ' + (r.dealer || cedNomDealer() || 'un dealer') + ' : ' + nom + ', ' + prix + ' FR.', 'event-info');
  updateUI();
  showToast('Achat enregistré', adopte ? nom + ' dans votre inventaire. −' + prix + ' FR.'
    : 'La livraison est enregistrée. Actualisez pour relire votre inventaire.', true);
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
    showToast('La descente', 'L’Estadine se paie : moral ' + dd.moral + ', santé ' + dd.hp + ', ' + dd.pa_differe + ' PA à la prochaine recharge.', false);
    addJournalEntry('Descente d’Estadine : moral ' + dd.moral + ', santé ' + dd.hp + ', ' + dd.pa_differe + ' PA à la prochaine recharge.', 'event-bad');
    if (typeof updateUI === 'function') updateUI();
  } catch (_) { /* reessaye au prochain passage */ }
  finally { descenteDrogueEnCours = false; }
}
if (typeof setInterval === 'function' && typeof window !== 'undefined') setInterval(verifierDescentesDrogue, 60000);
