// JUSTICE DE SOVARKA (08/11/2026, décisions de Fred, GAME-DESIGN-NOVOMIRSK.md « Justice de Sovarka »).
// Pas de procureur : la plainte reste au registre du commissariat ; le commissaire de la ville ou le
// ministre de la Justice prolétarienne saisit le juge ou enterre l'affaire. Le ministre envoie ses
// consignes au juge, qui reste libre. Le juge peut offrir un café. Le chef d'un parti demande l'extrait
// d'enregistrement de son parti. Tout est décidé par les fonctions serveur sovarka_* ; l'écran n'affiche
// que leurs réponses.

const JUSTICE_SOV_MOTIFS = {
  reserve_justice_sovarka: 'Réservé au commissaire, au juge et au ministre de la Justice prolétarienne.',
  reserve_commissaire_ou_ministre: 'Seuls le commissaire de la ville et le ministre de la Justice prolétarienne décident du sort d’une plainte.',
  reserve_ministre_justice: 'Réservé au ministre de la Justice prolétarienne.',
  reserve_juge: 'Réservé au juge.',
  statut_incompatible: 'Cette affaire a changé de situation : rouvrez le registre.',
  affaire_absente: 'Cette affaire n’existe plus.',
  hors_juridiction: 'Cette affaire ne relève pas de la justice de Sovarka.',
  pas_de_juge: 'Aucun juge n’est en fonction dans cette ville.',
  proces_trop_proche: 'Trop tard : les consignes s’envoient au plus tard la veille du procès.',
  consigne_invalide: 'Consigne inconnue.',
  pas_au_bureau_des_magistrats: 'Le café se sert dans le bureau des magistrats de votre tribunal.',
  aucun_beneficiaire: 'Choisissez au moins une personne présente.',
  beneficiaire_invalide: 'Vous ne pouvez pas vous offrir un café à vous-même.',
  beneficiaire_absent: 'Une des personnes choisies n’est plus dans le bureau.',
  deja_servi_aujourdhui: 'Déjà servi aujourd’hui',
  caisse_insuffisante: 'La caisse du tribunal ne peut pas payer ces cafés.',
  requete_invalide: 'Cette demande a déjà servi. Rouvrez l’écran.',
  salle_des_partis_requise: 'L’extrait se demande dans la salle des partis d’une mairie de Sovarka.',
  reserve_au_chef: 'Réservé au chef du parti.',
  inventaire_plein: 'Votre inventaire est plein.',
  caisse_de_la_mairie_introuvable: 'La caisse de la mairie est introuvable. Signalez-le.',
  pa_insuffisants: 'Vous n’avez pas assez de PA.',
  fonds_insuffisants: 'Vous n’avez pas assez de PSK.',
  acteur_non_authentifie: 'Votre session doit être rétablie.'
};
const JUSTICE_SOV_VILLES = { capitale: 'Novomirsk', ville_a: 'Starovka', ville_b: 'Krasnov' };
const JUSTICE_SOV_STATUTS = { au_parquet: 'au registre du commissariat', enterree: 'enterrée', saisie: 'juge saisi' };
const JUSTICE_SOV_CONSIGNES = { severe: 'Condamner sévèrement', legere: 'Condamner légèrement', relaxe: 'Relaxer', libre: 'Libre à vous' };
let justiceSovEnCours = false;
let justiceSovCafeRequete = null;
const justiceSovE = v => (typeof vehEchappe === 'function') ? vehEchappe(v)
  : String(v == null ? '' : v).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const justiceSovMotif = v => {
  if (!v) return 'Le serveur n’a pas répondu. Rien n’a été modifié.';
  if (v.raison === 'deja_servi_aujourdhui') return JUSTICE_SOV_MOTIFS.deja_servi_aujourdhui + ' : ' + (v.beneficiaires || []).join(', ') + '.';
  return JUSTICE_SOV_MOTIFS[v.raison] || ('Refusé (' + (v.raison || 'raison inconnue') + ').');
};

async function justiceSovCharger() {
  const v = await sbRpcVerdict('sovarka_justice_registre', {}).catch(() => null);
  if (!v || v.ok !== true) { showToast('Justice', justiceSovMotif(v), false); return null; }
  return v;
}

function justiceSovFiche(a, v) {
  const id = String(a.id).replace(/[^A-Za-z0-9_-]/g, '');
  let html = '<div style="border-top:1px solid #344354;padding:.55rem 0">' +
    '<b>Contre ' + justiceSovE(a.cible || 'X') + '</b> — ' + justiceSovE(JUSTICE_SOV_VILLES[a.ville] || a.ville) +
    ' · <span class="cpj-note">' + justiceSovE(JUSTICE_SOV_STATUTS[a.statut] || a.statut) + '</span><br>' +
    '<span class="cpj-note">Plaignant : ' + justiceSovE(a.plaignant || 'inconnu') + ' · jour ' + justiceSovE(a.jour || '?') +
    (a.audience_jour ? ' · audience au jour ' + justiceSovE(a.audience_jour) : '') + '</span><br>' +
    '<span class="cpj-note">Motif : ' + justiceSovE(a.motif || '—') + '</span><br>';
  if (a.peut_decider) {
    html += vehBouton(a.statut === 'enterree' ? 'Transmettre au juge' : 'Saisir le juge', 'justiceSovDecider(\'' + id + '\',\'saisir\')', true);
    if (a.statut === 'au_parquet') html += ' ' + vehBouton('Enterrer l’affaire', 'justiceSovDecider(\'' + id + '\',\'enterrer\')', false);
  }
  if (v.ministre) {
    const tardif = a.audience_ouverte || (a.audience_jour && v.jour >= a.audience_jour);
    html += '<br><span class="cpj-note">Consigne au juge : <b>' + justiceSovE(JUSTICE_SOV_CONSIGNES[a.consigne || 'libre']) + '</b>' +
      (tardif ? ' (trop tard pour la changer)' : '') + '</span>';
    if (!tardif) {
      html += '<br>' + Object.keys(JUSTICE_SOV_CONSIGNES).map(k =>
        vehBouton(JUSTICE_SOV_CONSIGNES[k], 'justiceSovConsigne(\'' + id + '\',\'' + k + '\')', (a.consigne || 'libre') === k)).join(' ');
    }
  }
  return html + '</div>';
}

// Commissaire (bureau du commissaire) et ministre (son bureau au Palais du Gouvernement).
async function ouvrirSovarkaRegistrePlaintes() {
  const v = await justiceSovCharger();
  if (!v) return;
  const affaires = (v.affaires || []).filter(a => v.ministre || a.ville === v.commissaire_ville);
  const enAttente = affaires.filter(a => a.statut === 'au_parquet');
  const enterrees = affaires.filter(a => a.statut === 'enterree');
  const saisies = affaires.filter(a => a.statut === 'saisie');
  const bloc = (liste, vide) => liste.length ? liste.map(a => justiceSovFiche(a, v)).join('') : '<p class="cpj-note">' + vide + '</p>';
  vehModal(v.ministre ? 'Affaires judiciaires de Sovarka' : 'Registre des plaintes',
    '<p class="cpj-note">Pas de procureur en Sovarka : vous saisissez le juge, ou vous enterrez l’affaire. Une affaire enterrée ' +
    'n’est jamais close ni connue du tribunal ; elle reste au registre et peut toujours être transmise. On en parlera peut-être…</p>' +
    vehSection('En attente', bloc(enAttente, 'Aucune plainte en attente.')) +
    vehSection('Enterrées', bloc(enterrees, 'Aucune affaire enterrée.')) +
    vehSection('Juge saisi', bloc(saisies, 'Aucune affaire devant le juge.')));
}

async function justiceSovDecider(id, decision) {
  if (justiceSovEnCours) return;
  justiceSovEnCours = true;
  try {
    const v = await sbRpcVerdict('sovarka_justice_decider', { p_affaire: id, p_decision: decision }).catch(() => null);
    if (!v || v.ok !== true) { showToast('Justice', justiceSovMotif(v), false); return; }
    showToast('Justice', decision === 'saisir'
      ? 'Le juge est saisi' + (v.juge ? ' (' + v.juge + ')' : '') + '.'
      : 'L’affaire s’est « égarée » au commissariat.', true);
    addJournalEntry(decision === 'saisir' ? 'Affaire transmise au juge.' : 'Affaire enterrée au commissariat.', 'event-info');
  } finally { justiceSovEnCours = false; }
  await ouvrirSovarkaRegistrePlaintes();
}

async function justiceSovConsigne(id, consigne) {
  if (justiceSovEnCours) return;
  justiceSovEnCours = true;
  try {
    const v = await sbRpcVerdict('sovarka_consigne_envoyer', { p_affaire: id, p_consigne: consigne }).catch(() => null);
    if (!v || v.ok !== true) { showToast('Consigne', justiceSovMotif(v), false); return; }
    showToast('Consigne', '« ' + JUSTICE_SOV_CONSIGNES[consigne] + ' » envoyée au juge.', true);
  } finally { justiceSovEnCours = false; }
  await ouvrirSovarkaRegistrePlaintes();
}

// Juge : « Prendre les ordres du ministre ». Aucun effet automatique : il lit, il juge librement.
async function ouvrirSovarkaOrdresMinistre() {
  const v = await justiceSovCharger();
  if (!v) return;
  if (!v.juge_ville) { vehModal('Ordres du ministre', '<p>' + JUSTICE_SOV_MOTIFS.reserve_juge + '</p>'); return; }
  const affaires = (v.affaires || []).filter(a => a.statut === 'saisie' && a.ville === v.juge_ville);
  vehModal('Ordres du ministre',
    '<p class="cpj-note">Le ministre de la Justice prolétarienne vous a nommé ; il peut vous démettre. Ses consignes ne vous lient pas… officiellement.</p>' +
    vehSection('Vos affaires', affaires.length ? affaires.map(a =>
      '<div style="border-top:1px solid #344354;padding:.5rem 0"><b>Contre ' + justiceSovE(a.cible || 'X') + '</b>' +
      (a.audience_jour ? ' · audience au jour ' + justiceSovE(a.audience_jour) : '') +
      '<br>Consigne : <b>' + justiceSovE(JUSTICE_SOV_CONSIGNES[a.consigne || 'libre']) + '</b></div>').join('')
      : '<p class="cpj-note">Aucune affaire ne vous est soumise.</p>'));
}

// Juge : « Offrir un café » aux personnes présentes dans le bureau des magistrats.
function ouvrirSovarkaOffrirCafe() {
  const moi = state.char?.name;
  const presents = [...new Set((window._vraisJoueursPresents || []).map(p => p.name).filter(n => n && n !== moi))].sort();
  justiceSovCafeRequete = null;
  vehModal('Offrir un café',
    '<p>+10 Moral pour chacun. 1 PSK par café, pris sur la caisse du tribunal ; un café par jour et par personne.</p>' +
    (presents.length
      ? presents.map(n => '<label style="display:block;margin:.35rem 0"><input type="checkbox" class="cafe-cible" value="' + justiceSovE(n) + '"> ' + justiceSovE(n) + '</label>').join('') +
        vehBouton('Servir le café', 'justiceSovServirCafe()', true)
      : '<p class="cpj-note">Personne d’autre n’est dans le bureau.</p>'));
}

async function justiceSovServirCafe() {
  if (justiceSovEnCours) return;
  const choix = [...new Set(Array.from(document.querySelectorAll('.cafe-cible:checked')).map(el => el.value))].sort();
  if (!choix.length) { showToast('Café', JUSTICE_SOV_MOTIFS.aucun_beneficiaire, false); return; }
  // Une même sélection garde la même requête : une réponse perdue se rejoue sans second café.
  const signature = JSON.stringify(choix);
  if (!justiceSovCafeRequete || justiceSovCafeRequete.signature !== signature)
    justiceSovCafeRequete = { signature, id: crypto.randomUUID() };
  justiceSovEnCours = true;
  try {
    const v = await sbRpcVerdict('sovarka_offrir_cafe', { p_requete: justiceSovCafeRequete.id, p_beneficiaires: choix }).catch(() => null);
    if (!v || v.ok !== true) {
      if (v && !v.transport) justiceSovCafeRequete = null;
      showToast('Café', justiceSovMotif(v), false); return;
    }
    justiceSovCafeRequete = null;
    document.getElementById('modal-postes')?.classList.remove('open');
    showToast('Café', 'Café servi à ' + (v.beneficiaires || []).join(', ') + ' (' + v.cout + ' PSK pris sur la caisse du tribunal).', true);
    addJournalEntry('Vous avez offert un café dans le bureau des magistrats.', 'event-info');
  } finally { justiceSovEnCours = false; }
}

// Chef de parti : « Extrait d'enregistrement du parti » (salle des partis).
async function sovarkaExtraitParti() {
  if (justiceSovEnCours) return;
  justiceSovEnCours = true;
  try {
    const v = await sbRpcVerdict('sovarka_parti_extrait', {}).catch(() => null);
    if (!v || v.ok !== true) { showToast('Extrait du parti', justiceSovMotif(v), false); return; }
    if (typeof appliquerPaiementServeur === 'function') appliquerPaiementServeur({ pa: v.pa, liquide: v.liquide, arg: v.arg });
    if (typeof rafraichirInventaireDepuisServeur === 'function') await rafraichirInventaireDepuisServeur();
    showToast('Extrait du parti', 'L’extrait d’enregistrement de « ' + (v.parti || 'votre parti') + ' » est dans votre inventaire (1 PA, 7 PSK).', true);
    addJournalEntry('Extrait d’enregistrement du parti délivré.', 'event-neutral');
    if (typeof updateUI === 'function') updateUI();
  } finally { justiceSovEnCours = false; }
}
