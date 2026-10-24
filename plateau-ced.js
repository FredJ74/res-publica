// Achat mecanique distinct de la conversation : serveur, inventaire revisionne et recu UUID.
function cedContexteValide(c) {
  return !!c && state.char === c.personnage && c.uid === rpAuthUid();
}
function cedSurPlace() {
  return state.country === 'republic' && state.currentCity === 'capitale'
    && state.currentBuilding === 'centre-artisanal' && state.currentRoom === 'travees';
}
function ouvrirAchatCed() {
  if (!cedSurPlace() || !state.char || !rpAuthUid()) return;
  let c = state._achatCed;
  if (!cedContexteValide(c) || c.termine) {
    c = { personnage: state.char, uid: rpAuthUid(), requete: crypto.randomUUID() };
    state._achatCed = c;
  }
  document.getElementById('modal-pnj')?.classList.remove('open');
  document.getElementById('postes-modal-title').textContent = "Céd' Labone";
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1rem;display:grid;gap:1rem"><p>Une boulette de shit — résine de cannabis.</p>' +
    '<p><b>50 FR</b> · 1 place dans l’inventaire</p><p>Marchandise illégale. Cet échange peut laisser des traces.</p>' +
    '<button id="ced-acheter" class="pnj-action-btn" onclick="confirmerAchatCed()">' +
    (c.incertain ? 'Vérifier cet achat' : 'Acheter — 50 FR') + '</button></div>';
  document.getElementById('ced-acheter').disabled = !!c.enCours;
  document.getElementById('modal-postes').classList.add('open');
}
async function confirmerAchatCed() {
  const c = state._achatCed;
  if (!cedContexteValide(c) || c.enCours || c.termine) return;
  if (!c.incertain && !cedSurPlace()) return;
  c.enCours = true;
  const bouton = document.getElementById('ced-acheter');
  if (bouton) bouton.disabled = true;
  let r;
  try { r = await sbRpcVerdict('pnj_ced_acheter', { p_requete: c.requete }); }
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
    const messages = { pas_sur_place: 'Retrouvez Ced dans les travées du Centre Artisanal de Luthécia.',
      inventaire_plein: 'Il vous faut une place libre dans l’inventaire.',
      fonds_insuffisants: 'Vos fonds disponibles ne couvrent pas les 50 FR.',
      acteur_non_authentifie: 'Reconnectez-vous avant de faire cet achat.' };
    showToast('Achat refusé', messages[r.raison] || 'L’achat n’a pas été validé. Réessayez.', false);
    return;
  }
  c.termine = true;
  appliquerPaiementServeur(r.paiement);
  let adopte = sbAdopterInventaireServeur(r);
  if (!adopte) {
    const frais = await sbRpc('inventaire_reception_etat', { p_acteur: c.personnage.name }).catch(() => null);
    if (!cedContexteValide(c)) return;
    adopte = !!frais?.ok && sbAdopterInventaireServeur(frais);
  }
  if (!cedContexteValide(c)) return;
  if (document.getElementById('ced-acheter')) document.getElementById('modal-postes')?.classList.remove('open');
  if (!r.rejeu) addJournalEntry("Achat auprès de Céd' Labone : une boulette de shit, 50 FR.", 'event-info');
  updateUI();
  showToast('Achat enregistré', adopte ? 'Une boulette de shit est dans votre inventaire. −50 FR.'
    : 'La livraison est enregistrée. Actualisez pour relire votre inventaire.', true);
}
