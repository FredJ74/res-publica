// SOVARKA : LOT DES PROVINCES (10/11/2026, décisions de Fred, GAME-DESIGN-NOVOMIRSK.md,
// « Réponses de Fred »). Bons d'État, centres d'écoute, maisons, forêt de Krasnov.
// Le serveur décide tout ; l'écran n'affiche que ses réponses (règle « une seule réalité »).

// Textes d'affichage : catalogue i18n/sovarka-provinces-resources.js (français de référence et de repli).
// PROV_MOTIFS ne garde que la liste des raisons connues (ses valeurs sont les clés du catalogue).
const provT = (k, v) => (typeof texteSovProvinces === 'function' ? texteSovProvinces(k, v) : k);
const provRaisons = l => Object.fromEntries(l.map(r => [r, 'm_' + r]));
const PROV_MOTIFS = provRaisons(['requete_absente', 'action_inconnue', 'acteur_non_authentifie', 'pas_sur_place', 'montant_invalide', 'fonds_insuffisants', 'requete_etrangere']);
const provMotif = v => PROV_MOTIFS[v?.raison] ? provT(PROV_MOTIFS[v.raison]) : provT(v?.transport ? 'noReplyReplay' : 'refused');
const provModal = (titre, html, rouvrir) => (typeof sovModal === 'function') ? sovModal(titre, html, rouvrir) : vehModal(titre, html);
const provDate = d => new Date(d + 'T12:00:00').toLocaleDateString('fr-FR');
let provBonsDernier = null, provEcoutesDernier = null, provMaisonDerniere = null;
const provEchapper = s => (typeof sovEchapper === 'function') ? sovEchapper(s) : String(s == null ? '' : s);
let provActeEnCours = false;
// Phrases renvoyées en français par le serveur (réplique de l'habitant, ragots, fausses alertes, noms de
// créatures, travaux de ferme, services) : traduites si elles correspondent EN ENTIER à un modèle connu
// (plateau-sovarka-courriers.js, catalogue des messages) ; sinon, et en français, texte d'origine.
const provServeur = (cles, s) => (typeof RPCourriersSovarka === 'object' && RPCourriersSovarka.phrase(cles, s)) || s;
const provRagot = s => (typeof RPCourriersSovarka === 'object' && RPCourriersSovarka.ragot(s)) || s;
const PROV_REACTIONS = ['hb_vodka', 'hb_slivovitz', 'hb_samogon', 'hb_alcool'];
const PROV_CREATURES = ['cf_loup', 'cf_meute', 'cf_ours'];
const PROV_ALERTES = ['fa_1', 'fa_2', 'fa_3', 'fa_4', 'fa_5'];
// Illustrations des rencontres de la forêt profonde (images de Fred, 14/11/2026).
const PROV_FORET_IMAGES = { cf_loup: 'Krasnov_foret_loup_attaque.webp', cf_meute: 'Krasnov_foret_meute_loups.webp', cf_ours: 'Krasnov_foret_ours_attaque.webp', olga: 'Krasnov_foret_olga_panier.webp' };
const provForetImage = cle => PROV_FORET_IMAGES[cle]
  ? '<img src="images/Sovarka/Krasnov/' + PROV_FORET_IMAGES[cle] + '" alt="" style="display:block;width:100%;max-height:42vh;object-fit:cover;border-radius:6px;margin-bottom:.6rem">' : '';
// Le serveur nomme la créature en français ; on retrouve sa clé dans le catalogue des messages.
const provCreatureCle = nom => PROV_CREATURES.find(k => typeof RPCourriersSovarka === 'object' && RPCourriersSovarka.phrase([k], nom) && RPCourriersSovarka.phrase([k], nom) !== nom)
  || ({ 'Loup solitaire': 'cf_loup', 'Meute de loups': 'cf_meute', 'Ours': 'cf_ours' })[nom] || null;
const PROV_SERVICES = ['bois', 'fruits_legumes', 'oeufs', 'vodka', 'poisson', 'carburant', 'viande', 'viande_renne'];
// Service demandé : en français le libellé du serveur ; ailleurs, la quantité et l'objet exigés par le serveur.
function provService(s) {
  if (!s) return '';
  const fr = typeof RPCourriersSovarka !== 'object' || RPCourriersSovarka.langue() === 'fr';
  if (fr || !PROV_SERVICES.includes(s.cle) || !Number.isSafeInteger(Number(s.qte)) || typeof texteSovMessages !== 'function') return s.label;
  return texteSovMessages('hs_' + s.cle, { n: Number(s.qte) });
}

// Un acte idempotent : clé de requête stable par geste, oubliée après une réponse du serveur.
async function provActe(rpc, params, geste) {
  if (provActeEnCours) return null;
  provActeEnCours = true;
  const cle = 'hg-sovarka:' + (state.char?.name || '') + ':' + rpc + ':' + geste;
  try {
    let requete = sessionStorage.getItem(cle);
    if (!requete) { requete = crypto.randomUUID(); sessionStorage.setItem(cle, requete); }
    const v = await sbRpcVerdict(rpc, Object.assign({ p_requete: requete }, params)).catch(() => null);
    if (v && !v.transport) sessionStorage.removeItem(cle);
    if (v && typeof v === 'object') v._requete = requete;   // trinquer : la réaction par l'IA relit ce geste
    if (v && v.ok === true) {
      if (Array.isArray(v.inventory) && typeof sbAdopterInventaireServeur === 'function') sbAdopterInventaireServeur(v);
      if (typeof appliquerPaiementServeur === 'function') appliquerPaiementServeur({ pa: v.pa, liquide: v.liquide, arg: v.arg });
      if (typeof renderInventory === 'function') renderInventory();
      if (typeof updateHeader === 'function') updateHeader();
      if (typeof updateUI === 'function') updateUI();
    }
    return v;
  } finally { provActeEnCours = false; }
}

// ---------- BONS D'ÉTAT ----------
async function ouvrirBonsEtat(cache) {
  const v = (cache === true && provBonsDernier) || await sbRpcVerdict('sovarka_bons_etat_lire', {}).catch(() => null);
  if (!v || v.ok !== true) { showToast(provT('tBonds'), provMotif(v), false); return; }
  provBonsDernier = v;
  const j = v.jour || {};
  let html = '<p>' + provT('bondsIntro') + '</p>' +
    '<p class="cpj-note">' + provT('bondsRate', { taux: j.taux, indice: j.indice }) + '</p>';
  html += vehSection(provT('subscribe'), '<div style="margin-top:.4rem">' + vehChamp('bon-etat-montant', 100) + ' PSK' +
    vehBouton(provT('subscribe'), 'souscrireBonEtat()', true) + '</div>');
  const bons = Array.isArray(v.bons) ? v.bons : [];
  if (bons.length) {
    html += vehSection(provT('myBonds'), bons.map(b => '<div style="margin:.3rem 0">' + provT('bondLine', { montant: b.montant, taux: b.taux }) +
      (b.statut === 'rembourse'
        ? provT('repaid', { montant: b.rembourse }) + (b.planche_a_billets ? provT('printing') : '')
        : provT('maturity', { date: provDate(b.echeance) })) + '</div>').join(''));
  }
  provModal(provT('titleBonds'), html, ouvrirBonsEtat);
}

async function souscrireBonEtat() {
  const montant = vehLireChamp('bon-etat-montant');
  if (!(montant > 0)) { showToast(provT('tBonds'), provT('m_montant_invalide'), false); return; }
  const v = await provActe('sovarka_bon_etat_souscrire', { p_montant: montant }, 'souscrire:' + montant);
  if (!v) return;
  if (v.ok !== true) { showToast(provT('tBonds'), provMotif(v), false); return; }
  showToast(provT('tBondOk'), provT('bondOk', { montant: v.montant, taux: v.taux, date: provDate(v.echeance) }), true, true);
  if (typeof addJournalEntry === 'function') addJournalEntry('Bon d’État souscrit : ' + v.montant + ' PSK à ' + v.taux + ' %.', 'event-good');
  await ouvrirBonsEtat();
}

// ---------- CENTRES D'ÉCOUTE ----------
Object.assign(PROV_MOTIFS, provRaisons(['pas_ministre_defense', 'rapport_introuvable', 'ministre_defense', 'archives_vides']));
const PROV_CENTRES = { novomirsk: 'Novomirsk', starovka: 'Starovka', krasnov: 'Krasnov' };

async function ouvrirEcoutesMinistre(cache) {
  const v = (cache === true && provEcoutesDernier) || await sbRpcVerdict('sovarka_ecoutes_lire', {}).catch(() => null);
  if (!v || v.ok !== true) { showToast(provT('tListening'), provMotif(v), false); return; }
  provEcoutesDernier = v;
  const rapports = Array.isArray(v.rapports) ? v.rapports : [];
  let html = '<p>' + provT('listenIntro') + '</p>';
  if (!rapports.length) html += '<p class="cpj-note">' + provT('noReports') + '</p>';
  else html += vehSection(provT('reports30'), rapports.map(r => {
    const js = 'demanderRapportEcoute(' + JSON.stringify(r.centre).replace(/"/g, '&quot;') + ',' + JSON.stringify(r.jour).replace(/"/g, '&quot;') + ')';
    return '<div style="margin:.3rem 0">' + PROV_CENTRES[r.centre] + ' — ' + provDate(r.jour) +
      provT('intercepts', { n: r.nb }) + vehBouton(provT('ask'), js) + '</div>';
  }).join(''));
  provModal(provT('tListening'), html, ouvrirEcoutesMinistre);
}

async function demanderRapportEcoute(centre, jour) {
  const v = await sbRpcVerdict('sovarka_ecoute_rapport_demander', { p_centre: centre, p_jour: jour }).catch(() => null);
  if (!v || v.ok !== true) { showToast(provT('tListening'), provMotif(v), false); return; }
  showToast(provT('tReportAsked'), provT('reportSent', { centre: PROV_CENTRES[centre] }), true);
}

async function volerArchivesEcoute() {
  const v = await provActe('sovarka_ecoute_archives_voler', {}, 'vol');
  if (!v) return;
  if (v.ok !== true) { showToast(provT('tArchives'), provMotif(v), false); return; }
  if (typeof adopterEtatCrimeServeur === 'function') adopterEtatCrimeServeur(v);
  if (v.reussi) {
    showToast(provT('tStolen'), provT('stolenOk', { centre: PROV_CENTRES[v.centre] }), true, true);
    if (typeof addJournalEntry === 'function') addJournalEntry('Rapport d’écoute volé (' + PROV_CENTRES[v.centre] + ').', 'event-bad');
  } else {
    showToast(provT('tCaught'), provT('caught') + (v.interrogatoire ? ' ' + provT('caughtInterro') : ''), false);
    if (typeof addJournalEntry === 'function') addJournalEntry('Surpris en volant les archives d’écoute : arrêté.', 'event-bad');
    if (v.arrestation && typeof adopterArrestationServeur === 'function') await adopterArrestationServeur(v.arrestation);
  }
}

// ---------- HABILITATIONS, CONSULTATION ET INTERROGATOIRE (Fred, 13/11/2026) ----------
// Le ministre de la Sécurité du Peuple habilite des personnages (jamais lui-même) ; un habilité cherche un nom
// dans les archives du centre où il se trouve (1 PA). Le voleur pris à Novomirsk attend en salle d'interrogatoire.
Object.assign(PROV_MOTIFS, provRaisons(['pas_habilite', 'cible_absente', 'pas_ministre_securite', 'pas_soi_meme',
  'personnage_introuvable', 'deja_habilite', 'pas_en_interrogatoire', 'autorite_insuffisante', 'pa_insuffisants']));
const provChampTexte = (id, indice) => '<input id="' + id + '" type="text" maxlength="60" class="cpj-champ" placeholder="' + provEchapper(indice) + '">';
const provLireTexte = id => String(document.getElementById(id)?.value || '').trim();
const provJs = (f, x) => f + '(' + JSON.stringify(String(x)).replace(/"/g, '&quot;') + ')';

async function ouvrirHabilitations() {
  const v = await sbRpcVerdict('sovarka_habilitations_lire', {}).catch(() => null);
  if (!v || v.ok !== true) { showToast(provT('tHabil'), provMotif(v), false); return; }
  provAfficherHabilitations(v);
}
function provAfficherHabilitations(v) {
  const liste = Array.isArray(v.habilites) ? v.habilites : [];
  let html = '<p>' + provT('habilIntro') + '</p>' +
    vehSection(provT('habilGrant'), '<div style="margin-top:.4rem">' + provChampTexte('habil-nom', provT('habilName')) +
      vehBouton(provT('habilGrant'), 'accorderHabilitation()', true) + '</div>');
  html += vehSection(provT('habilList'), liste.length
    ? liste.map(h => '<div style="margin:.3rem 0">' + provT('habilLine', { nom: provEchapper(h.nom), par: provEchapper(h.par) }) +
        vehBouton(provT('habilRevoke'), provJs('retirerHabilitation', h.nom)) + '</div>').join('')
    : '<p class="cpj-note">' + provT('habilNone') + '</p>');
  provModal(provT('tHabil'), html, ouvrirHabilitations);
}
async function accorderHabilitation() {
  const nom = provLireTexte('habil-nom');
  if (!nom) { showToast(provT('tHabil'), provT('m_cible_absente'), false); return; }
  const v = await sbRpcVerdict('sovarka_habilitation_accorder', { p_nom: nom }).catch(() => null);
  if (!v || v.ok !== true) { showToast(provT('tHabil'), provMotif(v), false); return; }
  showToast(provT('tHabilOk'), provT('habilOk', { nom: provEchapper(v.accorde) }), true);
  provAfficherHabilitations(v);
}
async function retirerHabilitation(nom) {
  const v = await sbRpcVerdict('sovarka_habilitation_retirer', { p_nom: nom }).catch(() => null);
  if (!v || v.ok !== true) { showToast(provT('tHabil'), provMotif(v), false); return; }
  showToast(provT('tHabilOff'), provT('habilOff', { nom: provEchapper(v.retire) }), true);
  provAfficherHabilitations(v);
}

function ouvrirConsultationArchives() {
  provModal(provT('tConsult'), '<p>' + provT('consultIntro') + '</p><div style="margin-top:.4rem">' +
    provChampTexte('archives-cible', provT('consultName')) + vehBouton(provT('consultGo'), 'consulterArchivesEcoute()', true) + '</div>');
}
async function consulterArchivesEcoute() {
  const cible = provLireTexte('archives-cible');
  if (!cible) { showToast(provT('tConsult'), provT('m_cible_absente'), false); return; }
  const v = await provActe('sovarka_ecoute_archives_consulter', { p_cible: cible }, 'consulter:' + cible.toLowerCase());
  if (!v) return;
  if (v.ok !== true) { showToast(provT('tConsult'), provMotif(v), false); return; }
  const centre = PROV_CENTRES[v.centre] || v.centre;
  if (v.nb > 0) showToast(provT('tConsult'), provT('consultFound', { n: v.nb, centre }), true);
  else showToast(provT('tConsult'), provT('consultNone', { cible: provEchapper(v.cible), centre }), false);
  if (typeof addJournalEntry === 'function') addJournalEntry('Archives d’écoute consultées (' + centre + ') : ' + v.cible + ', ' + v.nb + ' communication(s).', '');
}

async function ouvrirInterrogatoireRenseignement() {
  const v = await sbRpcVerdict('renseignement_detenus_interrogatoire', {}).catch(() => null);
  if (!v || v.ok !== true) { showToast(provT('tInterro'), provMotif(v), false); return; }
  const detenus = Array.isArray(v.detenus) ? v.detenus : [];
  const html = '<p>' + provT('interroIntro') + '</p>' + (detenus.length
    ? detenus.map(d => '<div style="margin:.3rem 0">' + provEchapper(d.nom) + vehBouton(provT('interroGo'), provJs('interrogerDetenuRenseignement', d.nom), true) + '</div>').join('')
    : '<p class="cpj-note">' + provT('interroNone') + '</p>');
  provModal(provT('tInterro'), html, ouvrirInterrogatoireRenseignement);
}
async function interrogerDetenuRenseignement(nom) {
  const v = await sbRpcVerdict('renseignement_interroger', { p_detenu: nom }).catch(() => null);
  if (!v || v.ok !== true) { showToast(provT('tInterro'), provMotif(v), false); return; }
  if (typeof appliquerPaiementServeur === 'function') appliquerPaiementServeur({ pa: v.pa });
  if (v.reussi && typeof adopterJaugeServeur === 'function') adopterJaugeServeur('inf', v.inf);
  showToast(provT('tInterroOk'), provT('interroOk', { nom: provEchapper(v.detenu) }) + (v.reussi ? provT('interroInf') : ''), true);
  if (typeof addJournalEntry === 'function') addJournalEntry('Interrogatoire de ' + v.detenu + ' à la Direction du Renseignement.', 'event-good');
  if (typeof updateUI === 'function') updateUI();
  await ouvrirInterrogatoireRenseignement();
}

// ---------- MAISONS (hospitalité russe) ----------
Object.assign(PROV_MOTIFS, provRaisons(['service_non_rendu', 'deja_mange', 'deja_heberge', 'heberge_ailleurs', 'service_incomplet',
  'aucun_service', 'pas_de_bouteille', 'acteur_indisponible']));

async function ouvrirMaisonHabitant(cache) {
  const v = (cache === true && provMaisonDerniere) || await sbRpcVerdict('sovarka_maison_lire', {}).catch(() => null);
  if (!v || v.ok !== true) { showToast(provT('tHouse'), provMotif(v), false); return; }
  provMaisonDerniere = v;
  const nom = provEchapper(v.habitant);
  let html;
  if (v.heberge) {
    html = '<p>' + provT('hHome') + '</p>' +
      (v.mange ? '<p class="cpj-note">' + provT('hAte') + '</p>'
               : vehBouton(provT('shareMeal'), 'agirMaisonHabitant(\'manger\')', true) + '<p class="cpj-note">' + provT('mealNote') + '</p>') +
      vehBouton(provT('sleepHere'), 'dormirChezHabitant()', true);
  } else if (v.heberge_ailleurs) {
    html = '<p>' + provT('hElsewhere') + '</p>';
  } else if (!v.service) {
    html = '<p>' + provT('hNothing') + '</p>';
  } else {
    html = '<p>' + provT('hAsk', { objet: provEchapper(provService(v.service)) }) + '</p>' +
      vehBouton(provT('give', { objet: provEchapper(provService(v.service)) }), 'agirMaisonHabitant(\'service\')', true);
  }
  html += '<p class="cpj-note" style="margin-top:.7rem">' + provT('toastWith', { nom }) +
    (v.bouteille ? '' : provT('noBottle')) + '</p>';
  provModal(nom, html, ouvrirMaisonHabitant);
}

async function agirMaisonHabitant(action) {
  const v = await provActe('sovarka_maison_agir', { p_action: action }, action);
  if (!v) return;
  if (v.ok !== true) { showToast(provT('tHouse'), provMotif(v), false); return; }
  if (action === 'service') showToast(provT('tServiceDone'), provT('serviceDone', { nom: provEchapper(v.habitant) }), true, true);
  if (action === 'manger') showToast(provT('tMeal'), provT('bonusSleep', { bonus: v.bonus }), true, true);
  await ouvrirMaisonHabitant();
}

// Dormir chez l'habitant (Fred, 14/11/2026) : ce n'est pas une nuit d'hôtel réservée. Le lit se débloque en rendant le
// service du jour ; le serveur a alors inscrit la nuit gratuite (hotel_nuitees) et la consomme au sommeil.
async function dormirChezHabitant() {
  const v = await sbRpcVerdict('sovarka_maison_lire', {}).catch(() => null);
  if (!v || v.ok !== true) { showToast(provT('tHouse'), provMotif(v), false); return; }
  const nom = provEchapper(v.habitant);
  if (!v.heberge) {
    const texte = v.heberge_ailleurs ? provT('hElsewhere')
      : v.service ? provT('sleepNo', { nom, objet: provEchapper(provService(v.service)) }) : provT('hNothing');
    showToast(provT('tSleepNo'), texte, false);
    return;
  }
  document.getElementById('modal-postes')?.classList.remove('open');
  if (typeof doDormirChambre === 'function') await doDormirChambre({ habitant: nom });
}

async function trinquerHabitant() {
  const v = await provActe('sovarka_maison_agir', { p_action: 'trinquer' }, 'trinquer');
  if (!v) return;
  if (v.ok !== true) { if (typeof signalerRefusCout === 'function' && !PROV_MOTIFS[v.raison]) signalerRefusCout(v); else showToast(provT('tToast'), provMotif(v), false); return; }
  // Réaction écrite par DeepSeek (Fred, 13/11/2026). Une seule fenêtre (Fred, 14/11/2026) : on attend la réplique de
  // l'habitant (8 s au plus) avant d'ouvrir la fenêtre, sinon la phrase fixe. Un seul appel par bouteille (serveur).
  const reactionIA = await Promise.race([provReactionIA(v._requete), new Promise(r => setTimeout(() => r(null), 8000))]).catch(() => null);
  const fenetre = () => provModal(provT('titleToast'), '<p>« ' + provEchapper(reactionIA || provServeur(PROV_REACTIONS, v.reaction)) + ' »</p>' +
    vehSection(provT('learn'), '<p>« ' + provEchapper(provRagot(v.secret_recu)) + ' »</p>') +
    vehSection(provT('slip'), '<p class="cpj-note">' + provT('slipNote', { secret: provEchapper(provRagot(v.secret_livre)) }) + '</p>') +
    vehBouton(provT('another'), 'trinquerHabitant()', false), fenetre);
  fenetre();
  if (typeof addJournalEntry === 'function') addJournalEntry('Trinqué avec ' + v.habitant + ' : « ' + v.secret_recu + ' »', 'event-neutral');
}

async function provReactionIA(requete) {
  if (!requete) return null;
  try {
    if (typeof rpAuthAssurerSession === 'function') await rpAuthAssurerSession().catch(() => null);
    const jeton = typeof rpAuthJeton === 'function' ? rpAuthJeton() : null;
    if (!jeton) return null;
    const r = await fetch('/api/chat?mode=trinquer', {
      method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + jeton },
      body: JSON.stringify({ requete, lang: typeof langueDuJeu === 'function' ? langueDuJeu() : 'fr' })
    });
    const d = r.ok ? await r.json().catch(() => null) : null;
    return d && typeof d.reaction === 'string' && d.reaction.trim() ? d.reaction.trim() : null;
  } catch (e) { return null; }
}

// ---------- FERMES (Fred, 10/11/2026 à midi) ----------
// Une ferme ne consomme que du travail : le serveur paie les PA et dépose les produits dans l'inventaire.
Object.assign(PROV_MOTIFS, provRaisons(['inventaire_plein', 'pas_d_oeufs']));
const PROV_FERME_LABELS = ['ft_renne', 'ft_traire', 'ft_legumes', 'ft_oeufs', 'ft_vaches', 'ft_poulet', 'ft_lapin'];
const PROV_FERME_TRAVAUX = { ferme_renne: 'renne', ferme_traire: 'traire', ferme_legumes: 'legumes', ferme_oeufs: 'oeufs', ferme_vaches: 'vaches', ferme_poulet: 'poulet', ferme_lapin: 'lapin' };
const PROV_MATIERES = ['viande', 'textile', 'bois', 'laitages', 'fruits_legumes', 'oeufs'];
const provProduits = l => (Array.isArray(l) ? l : []).map(p => p.qte + ' ' + (PROV_MATIERES.includes(p.cle) ? provT('mat_' + p.cle) : p.cle)).join(', ');
const provRefus = (titre, v) => { if (typeof signalerRefusCout === 'function' && !PROV_MOTIFS[v?.raison] && v?.raison) signalerRefusCout(v); else showToast(titre, provMotif(v), false); };

async function travaillerFerme(fn) {
  const travail = PROV_FERME_TRAVAUX[fn];
  if (!travail) return;
  const v = await provActe('sovarka_ferme_travailler', { p_travail: travail }, travail);
  if (!v) return;
  if (v.ok !== true) { provRefus(provT('tFarm'), v); return; }
  showToast(provEchapper(PROV_FERME_LABELS.includes('ft_' + v.travail) ? provServeur(['ft_' + v.travail], v.label) : v.label),
    provT('bring', { produits: provProduits(v.produits) }), true, true);
  if (typeof addJournalEntry === 'function') addJournalEntry(v.label + ' : ' + provProduits(v.produits) + '.', 'event-good');
}

// Œufs : toujours par 3, mangés d'un coup, sans PA ; +2 PA au prochain sommeil.
async function mangerOeufs() {
  const v = await provActe('sovarka_oeufs_manger', {}, 'manger');
  if (!v) return;
  if (v.ok !== true) { provRefus(provT('tEggs'), v); return; }
  document.getElementById('modal-postes')?.classList.remove('open');
  showToast(provT('tEggsEaten'), provT('bonusSleep', { bonus: v.bonus }), true, true);
  if (typeof addJournalEntry === 'function') addJournalEntry('Vous mangez trois œufs : +' + v.bonus + ' PA au prochain sommeil.', 'event-good');
}

// ---------- CAISSE COMMUNE DU KOLKHOZE (Fred, 14/11/2026 ; migration 20261114004000) ----------
// Toute matière première ; don : +2 popularité par article, +6 par jour au plus ; prise : 5 articles par jour au plus.
// Le serveur décide de tout (quotas, matières admises, inventaire) ; l'écran ne fait que proposer.
Object.assign(PROV_MOTIFS, provRaisons(['matiere_refusee', 'stock_insuffisant', 'reserve_insuffisante', 'quota_caisse', 'quantite_invalide']));
const PROV_KOLKHOZE_ADMISES = ['cereales', 'poisson', 'viande', 'bois', 'charbon', 'petrole', 'minerai', 'metal', 'plantes',
  'fruits_legumes', 'produits_exotiques', 'textile', 'laitages', 'oeufs'];
let provKolkhozeDernier = null;

async function ouvrirCaisseKolkhoze(cache) {
  const v = (cache === true && provKolkhozeDernier) || await sbRpcVerdict('kolkhoze_caisse_lire', {}).catch(() => null);
  if (!v || v.ok !== true) { showToast(provT('tKolkhoze'), provMotif(v), false); return; }
  provKolkhozeDernier = v;
  const caisse = Array.isArray(v.caisse) ? v.caisse : [];
  const champ = id => '<input id="' + id + '" type="number" min="1" max="99" value="1" class="cpj-champ" style="width:4.2rem">';
  const contenu = caisse.length
    ? caisse.map(c => '<div style="margin:.3rem 0"><i class="ti ' + provEchapper(c.icon || 'ti-package') + '"></i> ' + provEchapper(c.nom) + ' : ' + c.qte + ' ' +
        champ('kol-p-' + c.cle) + vehBouton(provT('kolTake'), provJs('agirCaisseKolkhoze', 'prendre:' + c.cle), false) + '</div>').join('')
    : '<p class="cpj-note">' + provT('kolEmpty') + '</p>';
  const miennes = (Array.isArray(state.inventory) ? state.inventory : [])
    .filter(o => o && o.stackable && PROV_KOLKHOZE_ADMISES.includes(o.stackKey) && Number(o.qty) >= 1);
  const dons = miennes.length
    ? miennes.map(o => '<div style="margin:.3rem 0"><i class="ti ' + provEchapper(o.icon || 'ti-package') + '"></i> ' + provEchapper(o.name) + ' : ' + Math.floor(Number(o.qty)) + ' ' +
        champ('kol-d-' + o.stackKey) + vehBouton(provT('kolGive'), provJs('agirCaisseKolkhoze', 'donner:' + o.stackKey), true) + '</div>').join('')
    : '<p class="cpj-note">' + provT('kolNothing') + '</p>';
  provModal(provT('tKolkhoze'),
    vehSection(provT('kolBox'), contenu + '<p class="cpj-note">' + provT('kolTakeLeft', { n: Math.max(0, v.pris_restant) }) + '</p>') +
    vehSection(provT('kolMine'), dons + '<p class="cpj-note">' + provT('kolPopLeft', { n: Math.max(0, v.pop_restante) }) + '</p>'),
    ouvrirCaisseKolkhoze);
}

async function agirCaisseKolkhoze(geste) {
  const [action, cle] = String(geste).split(':');
  const qte = Math.floor(Number(document.getElementById((action === 'donner' ? 'kol-d-' : 'kol-p-') + cle)?.value || 0));
  if (!(qte >= 1)) { showToast(provT('tKolkhoze'), provT('m_quantite_invalide'), false); return; }
  const v = await provActe('kolkhoze_caisse_agir', { p_action: action, p_cle: cle, p_qte: qte }, action + ':' + cle + ':' + qte);
  if (!v) return;
  if (v.ok !== true) { showToast(provT('tKolkhoze'), provMotif(v), false); return; }
  if (v.jauges && typeof v.jauges.pop !== 'undefined' && typeof adopterJaugeServeur === 'function') adopterJaugeServeur('pop', v.jauges.pop);
  if (typeof updateUI === 'function') updateUI();
  const nom = provEchapper(v.nom || cle);
  if (action === 'donner') {
    showToast(provT('tKolGiven'), provT('kolGiven', { n: v.quantite, nom }) + (v.gain_pop > 0 ? ' ' + provT('kolPop', { n: v.gain_pop }) : ''), true);
    if (typeof addJournalEntry === 'function') addJournalEntry('Don au kolkhoze de Krasnov : ' + v.quantite + ' ' + (v.nom || cle) + (v.gain_pop > 0 ? ' (+' + v.gain_pop + ' popularité).' : '.'), 'event-good');
  } else {
    showToast(provT('tKolTaken'), provT('kolTaken', { n: v.quantite, nom }), true);
    if (typeof addJournalEntry === 'function') addJournalEntry('Pris dans la caisse du kolkhoze : ' + v.quantite + ' ' + (v.nom || cle) + '.', 'event-neutral');
  }
  provKolkhozeDernier = v;
  await ouvrirCaisseKolkhoze(true);
}

// ---------- FORÊT PROFONDE DE KRASNOV (Fred, 09-10/11/2026, issue #72) ----------
// On n'entre en forêt profonde, on n'y change de vue et on n'en ressort que par ces ordres : le serveur tire la vue.
Object.assign(PROV_MOTIFS, provRaisons(['deja_en_foret', 'deja_a_l_entree', 'rencontre_en_cours', 'pas_en_foret_profonde', 'coupes_epuisees',
  'quitter_groupe_pour_couper', 'chef_de_groupe_requis', 'aucune_rencontre', 'combat_en_cours', 'foret_perdu', 'foret_chemin_aleatoire',
  'foret_pas_perdu']));

// Égarement (retour de Fred, 14/11/2026) : l'état « perdu » est au serveur (sovarka_foret_perdus). Ce reflet ne sert qu'à
// choisir entre « Revenir à l'entrée » et « Retrouver son chemin » à l'écran ; il est réécrit à chaque réponse du serveur.
let foretPerduServeur = false;
let foretPerduLu = false;
function foretEstPerdu() {
  const enForet = /^foret_vue_[1-4]$/.test(state.currentRoom || '');
  // Première vue profonde affichée depuis le chargement : l'état est relu une fois au serveur.
  if (enForet && !foretPerduLu) { foretPerduLu = true; setTimeout(() => { foretRelirePerdu(); }, 0); }
  return foretPerduServeur === true && enForet;
}
function foretNoterPerdu(v) {
  if (v && typeof v.perdu === 'boolean') foretPerduLu = true;
  if (v && typeof v.perdu === 'boolean' && foretPerduServeur !== v.perdu) {
    foretPerduServeur = v.perdu;
    return true;
  }
  return false;
}
// Fenêtre angoissante de l'égarement : le texte varie avec la vue tirée par le serveur.
function foretFenetrePerdu(titre, vue) {
  const n = Number.isSafeInteger(Number(vue)) && vue >= 1 && vue <= 4 ? Number(vue) : 1;
  const fenetre = () => provModal(titre, '<p style="font-style:italic">' + provT('lost_' + n) + '</p>' +
    '<p class="cpj-note">' + provT('lostHint') + '</p>', fenetre);
  fenetre();
}

function provForetRendre(room) {
  if (!room) return;
  navigationInterieureRendu = { buildingId: 'zone-production', roomId: room };
  try {
    if (state.currentBuilding !== 'zone-production') enterBuilding('zone-production', true);
    enterRoom('zone-production', room, null);
  } finally { navigationInterieureRendu = null; }
}

async function foretAller(sens) {
  const v = await provActe('sovarka_foret_aller', { p_sens: sens }, sens);
  if (!v) return;
  if (v.ok !== true) {
    if (v.raison === 'rencontre_en_cours') { await foretReprendreRencontre(); return; }
    // L'écran ignorait l'égarement (rechargement) : le serveur le rappelle, on remplace l'ordre et on le dit.
    if (foretNoterPerdu(v) && /^foret_vue_[1-4]$/.test(state.currentRoom || '')) provForetRendre(state.currentRoom);
    if (v.raison === 'foret_perdu' && v.perdu === true) { foretFenetrePerdu(provT('tStill'), Number(String(state.currentRoom).slice(-1))); return; }
    provRefus(provT('tForest'), v); return;
  }
  foretNoterPerdu(v);
  provForetRendre(v.room);
  if (Number(v.vue) === 0) showToast(provT('tOut'), provT(sens === 'retrouver' ? 'found' : 'out'), true);
  else if (v.egare === true) foretFenetrePerdu(provT(sens === 'retrouver' ? 'tStill' : 'tLost'), v.vue);
  else showToast(provT('tDeep'), provT('deeper'), true);
}

// Rechargement ou arrivée en forêt profonde : relire l'égarement au serveur pour afficher le bon ordre.
async function foretRelirePerdu() {
  const v = await sbRpcVerdict('sovarka_foret_lire', {}).catch(() => null);
  if (v?.ok === true && foretNoterPerdu(v) && /^foret_vue_[1-4]$/.test(state.currentRoom || '')) provForetRendre(state.currentRoom);
}

async function foretCouper() {
  const v = await provActe('sovarka_foret_couper', {}, 'couper');
  if (!v) return;
  if (v.ok !== true) { if (v.raison === 'rencontre_en_cours') { await foretReprendreRencontre(); return; } provRefus(provT('tForest'), v); return; }
  if (v.rencontre === 'olga') {
    const nourris = Array.isArray(v.nourris) ? v.nourris.length : 1;
    const fenetre = () => provModal(provT('titleNoise'), provForetImage('olga') + '<p>' + provT('olga1') + '</p>' +
      '<p>' + provT('olga2') + '</p>' +
      '<p class="cpj-note">' + (nourris > 1 ? provT('olgaMealGroup', { bonus: v.bonus, n: nourris }) : provT('olgaMeal', { bonus: v.bonus })) + '</p>' +
      (v.quantite ? '<p class="cpj-note">' + provT('woodToo', { n: v.quantite }) + '</p>' : ''), fenetre);
    fenetre();
    if (typeof addJournalEntry === 'function') addJournalEntry('Olga vous a nourri dans la forêt profonde' + (v.quantite ? ' ; ' + v.quantite + ' bois coupés.' : '.'), 'event-good');
    return;
  }
  if (v.rencontre === 'attaque') { foretAfficherRencontre(v.nom, v.pnj); return; }
  if (v.fausse_alerte) {
    const fenetre = () => provModal(provT('titleNoise'), '<p>' + provT('falseAlarm') + '</p>' +
      '<p>' + provEchapper(provServeur(PROV_ALERTES, v.fausse_alerte)) + '</p><p class="cpj-note">' + provT('woodBack', { n: v.quantite }) + '</p>', fenetre);
    fenetre();
  } else {
    showToast(provT('tWood'), provT('woodCut', { n: v.quantite }), true, true);
  }
  if (typeof addJournalEntry === 'function') addJournalEntry('Forêt profonde : ' + v.quantite + ' bois coupés.', 'event-good');
}

async function foretReprendreRencontre() {
  const v = await sbRpcVerdict('sovarka_foret_lire', {}).catch(() => null);
  if (v?.ok === true && v.rencontre) foretAfficherRencontre(v.rencontre.nom, v.rencontre.pnj);
  else showToast(provT('tForest'), provMotif({ raison: 'rencontre_en_cours' }), false);
}

function foretAfficherRencontre(nom, pnj) {
  const js = s => JSON.stringify(String(s)).replace(/"/g, '&quot;');
  let html = provForetImage(provCreatureCle(nom)) + '<p>' + provT('enc1') + '</p>' +
    '<p>' + provT('enc2', { nom: provEchapper(provServeur(PROV_CREATURES, nom)) }) + '</p>';
  const modes = (typeof NEUTRALISER_MODES === 'object' && NEUTRALISER_MODES) ? NEUTRALISER_MODES : { mains: { label: provT('bare') } };
  html += vehSection(provT('fight'), Object.keys(modes).map(m => {
    const possede = m === 'mains' || typeof neutraliserPossedeArme !== 'function' || neutraliserPossedeArme(m);
    return possede ? vehBouton(provEchapper(modes[m].label), 'foretCombattre(' + js(pnj) + ',' + js(m) + ')', m === 'mains') : '';
  }).join(''));
  html += vehSection(provT('orElse'), vehBouton(provT('flee'), 'foretChoisir(\'fuir\')') +
    vehBouton(provT('noDefend'), 'foretChoisir(\'subir\')') +
    '<p class="cpj-note">' + provT('neverDie') + '</p>');
  provModal(provT('titleEncounter'), html, () => foretAfficherRencontre(nom, pnj));
}

async function foretCombattre(pnj, mode) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const v = await sbCombatOuvrir(pnj, mode);
  if (v?.ok !== true || !Number.isSafeInteger(Number(v.bataille))) { showToast(provT('tNoFight'), PROV_MOTIFS[v?.raison] ? provT(PROV_MOTIFS[v.raison]) : (v?.raison || provT('notConfirmed')), false); return; }
  if (v.paie && typeof appliquerPaiementServeur === 'function') appliquerPaiementServeur(v.paie);
  if (typeof ouvrirPanneauCombat === 'function') await ouvrirPanneauCombat(Number(v.bataille));
}

async function foretChoisir(choix) {
  const v = await provActe('sovarka_foret_rencontre', { p_choix: choix }, choix);
  if (!v) return;
  if (v.ok !== true) { provRefus(provT('tForest'), v); return; }
  document.getElementById('modal-postes')?.classList.remove('open');
  if (choix === 'fuir') {
    provForetRendre(v.room);
    showToast(provT('tRun'), provT('run'), false);
  } else {
    showToast(provT('tEaten'), provT('eaten', { nom: provEchapper(provServeur(PROV_CREATURES, v.nom)) }), false);
    if (typeof relireHospitalisationServeur === 'function') await relireHospitalisationServeur(true);
  }
}
