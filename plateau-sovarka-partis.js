// PARTIS DE SOVARKA (07/11/2026, décisions de Fred, GAME-DESIGN-NOVOMIRSK.md « Partis de Sovarka »).
// Le serveur (sovarka_partis_liste, sovarka_parti_commande) décide de tout : lieu, coûts, adhésion
// unique, droit d'entrée, refus à -2 POP, successeur, dissolution. L'écran n'affiche que ses réponses.

// Textes d'affichage : catalogue i18n/sovarka-partis-resources.js (français de référence et de repli).
const partiT = (k, v) => (typeof texteSovPartis === 'function' ? texteSovPartis(k, v) : k);
const PARTI_RAISONS = ['parti_non_vainqueur', 'chef_pm_d_office', 'cible_deja_elue', 'salle_des_partis_requise', 'deja_dans_un_parti',
  'demande_en_cours', 'nom_requis', 'nom_deja_pris', 'texte_trop_long', 'reserve_au_chef', 'reserve_a_sovarka', 'prix_invalide',
  'demande_absente', 'membre_absent', 'candidat_deja_dans_un_parti', 'fonds_insuffisants_candidat', 'successeur_requis',
  'parti_introuvable', 'pa_insuffisants', 'fonds_insuffisants', 'acteur_non_authentifie'];
const partiModal = (titre, html, rouvrir) => (typeof sovModal === 'function') ? sovModal(titre, html, rouvrir) : vehModal(titre, html);
const PARTI_VILLES = { capitale: 'Novomirsk', ville_a: 'Starovka', ville_b: 'Krasnov' };
let partiDonnees = null;
let partiEnCours = false;
const partiE = v => (typeof vehEchappe === 'function') ? vehEchappe(v)
  : String(v == null ? '' : v).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

async function partiCharger(cache) {
  if (cache === true && partiDonnees) return partiDonnees;
  const v = await sbRpcVerdict('sovarka_partis_liste', {}).catch(() => null);
  if (!v || v.ok !== true) { showToast(partiT('tParties'), partiT('noServer'), false); return null; }
  partiDonnees = v;
  return v;
}

function partiEstDansSalle() {
  return state.currentRoom === 'salle_partis';
}

function partiListeHtml(partis) {
  if (!partis.length) return '<p class="cpj-note">' + partiT('noParty') + '</p>';
  return partis.map((p, i) =>
    '<div style="border-top:1px solid #344354;padding:.5rem 0">' +
      '<b>' + partiE(p.nom) + '</b>' + partiT('partyHead', { chef: partiE(p.chef), siege: partiE(PARTI_VILLES[p.siege] || p.siege) }) +
      '<br><span class="cpj-note">' + (p.desc ? partiE(p.desc) + ' · ' : '') + partiT(p.membres > 1 ? 'membersMany' : 'membersOne', { n: p.membres }) +
      partiT('partyStats', { pop: p.pop, prix: p.prix }) + '</span><br>' +
      (p.demande_en_cours ? '<span class="cpj-note">' + partiT('requestPending') + '</span>'
        : (partiDonnees && !partiDonnees.mon_parti ? vehBouton(partiT('askJoin'), 'partiDemander(' + i + ')', false) : '')) +
    '</div>').join('');
}

// « Postuler à un poste » : en Sovarka, le parti d'abord (Fred, 07/11/2026).
async function sovarkaPostuler(cache) {
  if (state.country !== 'soviet') { ouvrirEcranPostes(); return; }
  const v = await partiCharger(cache);
  if (!v) return;
  if (v.mon_parti) { if (cache !== true) ouvrirEcranPostes(); return; }
  partiModal(partiT('titleApply'),
    '<p><b>' + partiT('mustJoin') + '</b></p>' +
    vehSection(partiT('secParties'), partiListeHtml(v.partis)) +
    vehSection(partiT('secCreate'), '<p>' + partiT('createInfo') + '</p>' +
      (partiEstDansSalle() ? vehBouton(partiT('create'), 'partiFormulaireCreation()', true) : '')), sovarkaPostuler);
}

async function ouvrirSovarkaPartis(cache) {
  const v = await partiCharger(cache);
  if (!v) return;
  partiModal(partiT('titleHall'), vehSection(partiT('secParties'), partiListeHtml(v.partis)), ouvrirSovarkaPartis);
}

function partiFormulaireCreation() {
  partiModal(partiT('create'),
    '<p>' + partiT('createIntro') + '</p>' +
    '<input id="parti-nom" class="cpj-champ" maxlength="40" placeholder="' + partiE(partiT('namePh')) + '" style="width:100%"><br>' +
    '<textarea id="parti-desc" class="cpj-champ" maxlength="200" rows="3" placeholder="' + partiE(partiT('programPh')) + '" style="width:100%;margin-top:.4rem"></textarea><br>' +
    vehBouton(partiT('found'), 'partiFonder()', true), partiFormulaireCreation);
}

async function partiCommande(action, parti, params, cleSuffixe) {
  if (partiEnCours) return null;
  partiEnCours = true;
  const cle = 'hg-parti:' + (state.char?.name || '') + ':' + action + ':' + (parti || '') + ':' + (cleSuffixe || '');
  try {
    let requete = sessionStorage.getItem(cle);
    if (!requete) { requete = crypto.randomUUID(); sessionStorage.setItem(cle, requete); }
    const v = await sbRpcVerdict('sovarka_parti_commande',
      { p_requete: requete, p_action: action, p_parti: parti || null, p_params: params || {} }).catch(() => null);
    if (v && !v.transport) sessionStorage.removeItem(cle);
    if (!v || v.ok !== true) {
      showToast(partiT('tRefused'), PARTI_RAISONS.includes(v?.raison) ? partiT('m_' + v.raison) : partiT('notConfirmed'), false);
      return null;
    }
    if (typeof appliquerPaiementServeur === 'function' && (v.pa != null || v.liquide != null))
      appliquerPaiementServeur({ pa: v.pa, liquide: v.liquide, arg: v.arg });
    if (typeof updateHeader === 'function') updateHeader();
    return v;
  } finally { partiEnCours = false; }
}

async function partiFonder() {
  const nom = (document.getElementById('parti-nom')?.value || '').trim();
  const desc = (document.getElementById('parti-desc')?.value || '').trim();
  const v = await partiCommande('fonder', null, { nom, desc }, nom);
  if (!v) return;
  document.getElementById('modal-postes')?.classList.remove('open');
  showToast(partiT('tFounded'), partiT('founded', { nom: v.nom }), true);
  if (typeof addJournalEntry === 'function') addJournalEntry('Fondation du parti ' + v.nom + '.', 'event-info');
}

async function partiDemander(i) {
  const p = partiDonnees?.partis?.[i];
  if (!p) return;
  const v = await partiCommande('demander', p.id, {});
  if (!v) return;
  document.getElementById('modal-postes')?.classList.remove('open');
  showToast(partiT('tSent'), partiT('sent', { nom: v.nom }), true);
}

async function ouvrirSovarkaMonParti(cache) {
  const v = await partiCharger(cache);
  if (!v) return;
  const m = v.mon_parti;
  if (!m) { ouvrirSovarkaPartis(cache); return; }
  let html = '<p><b>' + partiE(m.nom) + '</b>' + partiT('partyHead', { chef: partiE(m.chef), siege: partiE(PARTI_VILLES[m.siege] || m.siege) }) +
    partiT('myStats', { pop: m.pop, prix: m.prix }) + (m.est_chef ? partiT('treasury', { caisse: m.caisse }) : '') + '</p>';
  html += vehSection(partiT('secMembers'), m.membres.map((x, i) => '<div>' + partiE(x.nom) + ' — ' + partiE(x.grade) +
    (m.est_chef && x.nom !== m.chef ? ' ' + vehBouton(partiT('makeSuccessor'), 'partiSuccesseur(' + i + ')', false) : '') +
    (m.peut_designer_pm && x.nom !== m.chef ? ' ' + vehBouton(partiT('makePm'), 'partiDesignerPm(' + i + ')', true) : '') + '</div>').join(''));
  if (m.peut_designer_pm) html += '<p class="cpj-note">' + partiT('pmNote') + '</p>';
  if (m.est_chef) {
    html += vehSection(partiT('secRequests'), m.demandes.length
      ? m.demandes.map((x, i) => '<div>' + partiE(x.nom) + ' ' + vehBouton(partiT('accept'), 'partiRepondre(' + i + ',true)', true) + ' ' +
          vehBouton(partiT('refuse'), 'partiRepondre(' + i + ',false)', false) + '</div>').join('')
      : '<p class="cpj-note">' + partiT('noRequest') + '</p>');
    html += vehSection(partiT('secSoviet'), '<p class="cpj-note">' + partiT('sovietNote') + '</p>' +
      vehBouton(partiT('seats'), 'ouvrirSovietSupreme()', false));
    html += vehSection(partiT('secLaws'), '<p class="cpj-note">' + partiT('lawsNote') + '</p>'
      + vehBouton(partiT('bill'), 'ouvrirSovarkaDeposerLoi()', true)
      + vehBouton(partiT('rally'), 'sovarkaManifSoutien()', false));
    html += vehSection(partiT('secFee'), '<input id="parti-prix" class="cpj-champ" type="number" min="0" step="1" value="' + m.prix + '"> PSK ' +
      vehBouton(partiT('set'), 'partiFixerPrix()', false));
  }
  html += vehSection(partiT('secLeave'), '<p class="cpj-note">' + partiT('leaveCost') + (m.est_chef
    ? partiT('leaveChief') : '') + '</p>' +
    vehBouton(partiT('leave'), 'partiQuitter()', false));
  partiModal(partiT('titleMine'), html, ouvrirSovarkaMonParti);
}

async function partiRepondre(i, accepter) {
  const m = partiDonnees?.mon_parti, x = m?.demandes?.[i];
  if (!x) return;
  const v = await partiCommande(accepter ? 'accepter' : 'refuser', m.id, { nom: x.nom }, x.nom);
  if (!v) return;
  showToast(accepter ? partiT('tAccepted') : partiT('tRejected'),
    accepter ? (v.prix ? partiT('joinsPaid', { nom: x.nom, prix: v.prix }) : partiT('joins', { nom: x.nom }))
             : partiT('rejected', { nom: x.nom, pop: v.pop }), true);
  ouvrirSovarkaMonParti();
}

async function partiFixerPrix() {
  const m = partiDonnees?.mon_parti;
  const prix = Number(document.getElementById('parti-prix')?.value);
  if (!m) return;
  const v = await partiCommande('fixer_prix', m.id, { prix }, String(prix));
  if (v) { showToast(partiT('tFee'), partiT('feeSet', { prix: v.prix }), true); ouvrirSovarkaMonParti(); }
}

async function partiSuccesseur(i) {
  const m = partiDonnees?.mon_parti, x = m?.membres?.[i];
  if (!x) return;
  const v = await partiCommande('successeur', m.id, { nom: x.nom }, x.nom);
  if (v) { showToast(partiT('tSuccessor'), partiT('successor', { nom: x.nom }), true); ouvrirSovarkaMonParti(); }
}

async function partiDesignerPm(i) {
  const m = partiDonnees?.mon_parti, x = m?.membres?.[i];
  if (!x) return;
  const v = await partiCommande('designer_pm', m.id, { nom: x.nom }, x.nom);
  if (v) { showToast(partiT('tPm'), partiT('pm', { nom: v.nom }), true); ouvrirSovarkaMonParti(); }
}

async function partiQuitter() {
  const m = partiDonnees?.mon_parti;
  if (!m) return;
  const v = await partiCommande('quitter', m.id, {});
  if (!v) return;
  document.getElementById('modal-postes')?.classList.remove('open');
  showToast(partiT('tLeft'), v.dissous ? partiT('dissolved', { nom: v.nom }) : partiT('left', { nom: v.nom }), true);
}
