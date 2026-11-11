// JUSTICE DE SOVARKA (08/11/2026, décisions de Fred, GAME-DESIGN-NOVOMIRSK.md « Justice de Sovarka »).
// Pas de procureur : la plainte reste au registre du commissariat ; le commissaire de la ville ou le
// ministre de la Justice prolétarienne saisit le juge ou enterre l'affaire. Le ministre envoie ses
// consignes au juge, qui reste libre. Le juge peut offrir un café. Le chef d'un parti demande l'extrait
// d'enregistrement de son parti. Tout est décidé par les fonctions serveur sovarka_* ; l'écran n'affiche
// que leurs réponses.

// Textes d'affichage : catalogue i18n/sovarka-justice-resources.js (français de référence et de repli).
const justiceT = (k, v) => (typeof texteSovJustice === 'function' ? texteSovJustice(k, v) : k);
const JUSTICE_SOV_RAISONS = ['reserve_justice_sovarka', 'reserve_commissaire_ou_ministre', 'reserve_ministre_justice', 'reserve_juge',
  'statut_incompatible', 'affaire_absente', 'hors_juridiction', 'pas_de_juge', 'proces_trop_proche', 'consigne_invalide',
  'pas_au_bureau_des_magistrats', 'aucun_beneficiaire', 'beneficiaire_invalide', 'beneficiaire_absent', 'caisse_insuffisante',
  'requete_invalide', 'salle_des_partis_requise', 'reserve_au_chef', 'inventaire_plein', 'caisse_de_la_mairie_introuvable',
  'pa_insuffisants', 'fonds_insuffisants', 'acteur_non_authentifie'];
const justiceModal = (titre, html, rouvrir) => (typeof sovModal === 'function') ? sovModal(titre, html, rouvrir) : vehModal(titre, html);
const JUSTICE_SOV_VILLES = { capitale: 'Novomirsk', ville_a: 'Starovka', ville_b: 'Krasnov' };
const justiceSovStatut = st => ['au_parquet', 'enterree', 'saisie'].includes(st) ? justiceT('st_' + st) : st;
const JUSTICE_SOV_CONSIGNES = ['severe', 'legere', 'relaxe', 'libre'];
const justiceSovConsigneTexte = k => JUSTICE_SOV_CONSIGNES.includes(k) ? justiceT('c_' + k) : k;
let justiceSovDernier = null;
let justiceSovEnCours = false;
let justiceSovCafeRequete = null;
const justiceSovE = v => (typeof vehEchappe === 'function') ? vehEchappe(v)
  : String(v == null ? '' : v).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const justiceSovMotif = v => {
  if (!v) return justiceT('noServer');
  if (v.raison === 'deja_servi_aujourdhui') return justiceT('alreadyServed', { noms: (v.beneficiaires || []).join(', ') });
  return JUSTICE_SOV_RAISONS.includes(v.raison) ? justiceT('m_' + v.raison) : justiceT('refusedWhy', { raison: v.raison || justiceT('unknownReason') });
};

async function justiceSovCharger(cache) {
  if (cache === true && justiceSovDernier) return justiceSovDernier;
  const v = await sbRpcVerdict('sovarka_justice_registre', {}).catch(() => null);
  if (!v || v.ok !== true) { showToast(justiceT('tJustice'), justiceSovMotif(v), false); return null; }
  justiceSovDernier = v;
  return v;
}

function justiceSovFiche(a, v) {
  const id = String(a.id).replace(/[^A-Za-z0-9_-]/g, '');
  let html = '<div style="border-top:1px solid #344354;padding:.55rem 0">' +
    '<b>' + justiceT('against', { cible: justiceSovE(a.cible || 'X') }) + '</b> — ' + justiceSovE(JUSTICE_SOV_VILLES[a.ville] || a.ville) +
    ' · <span class="cpj-note">' + justiceSovE(justiceSovStatut(a.statut)) + '</span><br>' +
    '<span class="cpj-note">' + justiceT('plaintiff', { nom: justiceSovE(a.plaignant || justiceT('unknown')) }) + justiceT('day', { jour: justiceSovE(a.jour || '?') }) +
    (a.audience_jour ? justiceT('hearing', { jour: justiceSovE(a.audience_jour) }) : '') + '</span><br>' +
    '<span class="cpj-note">' + justiceT('reason', { motif: justiceSovE(a.motif || '—') }) + '</span><br>';
  if (a.peut_decider) {
    html += vehBouton(a.statut === 'enterree' ? justiceT('transmit') : justiceT('refer'), 'justiceSovDecider(\'' + id + '\',\'saisir\')', true);
    if (a.statut === 'au_parquet') html += ' ' + vehBouton(justiceT('bury'), 'justiceSovDecider(\'' + id + '\',\'enterrer\')', false);
  }
  if (v.ministre) {
    const tardif = a.audience_ouverte || (a.audience_jour && v.jour >= a.audience_jour);
    html += '<br><span class="cpj-note">' + justiceT('orderToJudge') + ' <b>' + justiceSovE(justiceSovConsigneTexte(a.consigne || 'libre')) + '</b>' +
      (tardif ? justiceT('tooLate') : '') + '</span>';
    if (!tardif) {
      html += '<br>' + JUSTICE_SOV_CONSIGNES.map(k =>
        vehBouton(justiceSovConsigneTexte(k), 'justiceSovConsigne(\'' + id + '\',\'' + k + '\')', (a.consigne || 'libre') === k)).join(' ');
    }
  }
  return html + '</div>';
}

// Commissaire (bureau du commissaire) et ministre (son bureau au Palais du Gouvernement).
async function ouvrirSovarkaRegistrePlaintes(cache) {
  const v = await justiceSovCharger(cache);
  if (!v) return;
  const affaires = (v.affaires || []).filter(a => v.ministre || a.ville === v.commissaire_ville);
  const enAttente = affaires.filter(a => a.statut === 'au_parquet');
  const enterrees = affaires.filter(a => a.statut === 'enterree');
  const saisies = affaires.filter(a => a.statut === 'saisie');
  const bloc = (liste, vide) => liste.length ? liste.map(a => justiceSovFiche(a, v)).join('') : '<p class="cpj-note">' + vide + '</p>';
  justiceModal(v.ministre ? justiceT('titleCases') : justiceT('titleRegister'),
    '<p class="cpj-note">' + justiceT('registerIntro') + '</p>' +
    vehSection(justiceT('secWaiting'), bloc(enAttente, justiceT('noWaiting'))) +
    vehSection(justiceT('secBuried'), bloc(enterrees, justiceT('noBuried'))) +
    vehSection(justiceT('secReferred'), bloc(saisies, justiceT('noReferred'))), ouvrirSovarkaRegistrePlaintes);
}

async function justiceSovDecider(id, decision) {
  if (justiceSovEnCours) return;
  justiceSovEnCours = true;
  try {
    const v = await sbRpcVerdict('sovarka_justice_decider', { p_affaire: id, p_decision: decision }).catch(() => null);
    if (!v || v.ok !== true) { showToast(justiceT('tJustice'), justiceSovMotif(v), false); return; }
    showToast(justiceT('tJustice'), decision === 'saisir'
      ? (v.juge ? justiceT('judgeSeizedBy', { juge: v.juge }) : justiceT('judgeSeized'))
      : justiceT('buriedOk'), true);
    addJournalEntry(decision === 'saisir' ? 'Affaire transmise au juge.' : 'Affaire enterrée au commissariat.', 'event-info');
  } finally { justiceSovEnCours = false; }
  await ouvrirSovarkaRegistrePlaintes();
}

async function justiceSovConsigne(id, consigne) {
  if (justiceSovEnCours) return;
  justiceSovEnCours = true;
  try {
    const v = await sbRpcVerdict('sovarka_consigne_envoyer', { p_affaire: id, p_consigne: consigne }).catch(() => null);
    if (!v || v.ok !== true) { showToast(justiceT('tOrder'), justiceSovMotif(v), false); return; }
    showToast(justiceT('tOrder'), justiceT('orderSent', { consigne: justiceSovConsigneTexte(consigne) }), true);
  } finally { justiceSovEnCours = false; }
  await ouvrirSovarkaRegistrePlaintes();
}

// Juge : « Prendre les ordres du ministre ». Aucun effet automatique : il lit, il juge librement.
async function ouvrirSovarkaOrdresMinistre(cache) {
  const v = await justiceSovCharger(cache);
  if (!v) return;
  if (!v.juge_ville) { justiceModal(justiceT('titleOrders'), '<p>' + justiceT('m_reserve_juge') + '</p>', ouvrirSovarkaOrdresMinistre); return; }
  const affaires = (v.affaires || []).filter(a => a.statut === 'saisie' && a.ville === v.juge_ville);
  justiceModal(justiceT('titleOrders'),
    '<p class="cpj-note">' + justiceT('ordersIntro') + '</p>' +
    vehSection(justiceT('secYourCases'), affaires.length ? affaires.map(a =>
      '<div style="border-top:1px solid #344354;padding:.5rem 0"><b>' + justiceT('against', { cible: justiceSovE(a.cible || 'X') }) + '</b>' +
      (a.audience_jour ? justiceT('hearing', { jour: justiceSovE(a.audience_jour) }) : '') +
      '<br>' + justiceT('orderLine') + ' <b>' + justiceSovE(justiceSovConsigneTexte(a.consigne || 'libre')) + '</b></div>').join('')
      : '<p class="cpj-note">' + justiceT('noCases') + '</p>'), ouvrirSovarkaOrdresMinistre);
}

// Juge : « Offrir un café » aux personnes présentes dans le bureau des magistrats.
// Changement de langue : mêmes présents, cases cochées conservées, requête en cours gardée.
function ouvrirSovarkaOffrirCafeLangue() {
  const coches = Array.from(document.querySelectorAll('.cafe-cible:checked')).map(el => el.value);
  const requete = justiceSovCafeRequete;
  ouvrirSovarkaOffrirCafe();
  justiceSovCafeRequete = requete;
  document.querySelectorAll('.cafe-cible').forEach(el => { if (coches.includes(el.value)) el.checked = true; });
}
function ouvrirSovarkaOffrirCafe() {
  const moi = state.char?.name;
  const presents = [...new Set((window._vraisJoueursPresents || []).map(p => p.name).filter(n => n && n !== moi))].sort();
  justiceSovCafeRequete = null;
  justiceModal(justiceT('titleCoffee'),
    '<p>' + justiceT('coffeeIntro') + '</p>' +
    (presents.length
      ? presents.map(n => '<label style="display:block;margin:.35rem 0"><input type="checkbox" class="cafe-cible" value="' + justiceSovE(n) + '"> ' + justiceSovE(n) + '</label>').join('') +
        vehBouton(justiceT('serve'), 'justiceSovServirCafe()', true)
      : '<p class="cpj-note">' + justiceT('nobody') + '</p>'), ouvrirSovarkaOffrirCafeLangue);
}

async function justiceSovServirCafe() {
  if (justiceSovEnCours) return;
  const choix = [...new Set(Array.from(document.querySelectorAll('.cafe-cible:checked')).map(el => el.value))].sort();
  if (!choix.length) { showToast(justiceT('tCoffee'), justiceT('m_aucun_beneficiaire'), false); return; }
  // Une même sélection garde la même requête : une réponse perdue se rejoue sans second café.
  const signature = JSON.stringify(choix);
  if (!justiceSovCafeRequete || justiceSovCafeRequete.signature !== signature)
    justiceSovCafeRequete = { signature, id: crypto.randomUUID() };
  justiceSovEnCours = true;
  try {
    const v = await sbRpcVerdict('sovarka_offrir_cafe', { p_requete: justiceSovCafeRequete.id, p_beneficiaires: choix }).catch(() => null);
    if (!v || v.ok !== true) {
      if (v && !v.transport) justiceSovCafeRequete = null;
      showToast(justiceT('tCoffee'), justiceSovMotif(v), false); return;
    }
    justiceSovCafeRequete = null;
    document.getElementById('modal-postes')?.classList.remove('open');
    showToast(justiceT('tCoffee'), justiceT('coffeeServed', { noms: (v.beneficiaires || []).join(', '), cout: v.cout }), true);
    addJournalEntry('Vous avez offert un café dans le bureau des magistrats.', 'event-info');
  } finally { justiceSovEnCours = false; }
}

// Chef de parti : « Extrait d'enregistrement du parti » (salle des partis).
async function sovarkaExtraitParti() {
  if (justiceSovEnCours) return;
  justiceSovEnCours = true;
  try {
    const v = await sbRpcVerdict('sovarka_parti_extrait', {}).catch(() => null);
    if (!v || v.ok !== true) { showToast(justiceT('tExtract'), justiceSovMotif(v), false); return; }
    if (typeof appliquerPaiementServeur === 'function') appliquerPaiementServeur({ pa: v.pa, liquide: v.liquide, arg: v.arg });
    if (typeof rafraichirInventaireDepuisServeur === 'function') await rafraichirInventaireDepuisServeur();
    showToast(justiceT('tExtract'), justiceT('extractOk', { parti: v.parti || justiceT('yourParty') }), true);
    addJournalEntry('Extrait d’enregistrement du parti délivré.', 'event-neutral');
    if (typeof updateUI === 'function') updateUI();
  } finally { justiceSovEnCours = false; }
}
