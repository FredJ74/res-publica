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
    showToast(provT('tCaught'), provT('caught'), false);
    if (typeof addJournalEntry === 'function') addJournalEntry('Surpris en volant les archives d’écoute : arrêté.', 'event-bad');
    if (v.arrestation && typeof adopterArrestationServeur === 'function') await adopterArrestationServeur(v.arrestation);
  }
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
               : vehBouton(provT('shareMeal'), 'agirMaisonHabitant(\'manger\')', true) + '<p class="cpj-note">' + provT('mealNote') + '</p>');
  } else if (v.heberge_ailleurs) {
    html = '<p>' + provT('hElsewhere') + '</p>';
  } else if (!v.service) {
    html = '<p>' + provT('hNothing') + '</p>';
  } else {
    html = '<p>' + provT('hAsk', { objet: provEchapper(v.service.label) }) + '</p>' +
      vehBouton(provT('give', { objet: provEchapper(v.service.label) }), 'agirMaisonHabitant(\'service\')', true);
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

async function trinquerHabitant() {
  const v = await provActe('sovarka_maison_agir', { p_action: 'trinquer' }, 'trinquer');
  if (!v) return;
  if (v.ok !== true) { if (typeof signalerRefusCout === 'function' && !PROV_MOTIFS[v.raison]) signalerRefusCout(v); else showToast(provT('tToast'), provMotif(v), false); return; }
  const fenetre = () => provModal(provT('titleToast'), '<p>« ' + provEchapper(v.reaction) + ' »</p>' +
    vehSection(provT('learn'), '<p>« ' + provEchapper(v.secret_recu) + ' »</p>') +
    vehSection(provT('slip'), '<p class="cpj-note">' + provT('slipNote', { secret: provEchapper(v.secret_livre) }) + '</p>') +
    vehBouton(provT('another'), 'trinquerHabitant()', false), fenetre);
  fenetre();
  if (typeof addJournalEntry === 'function') addJournalEntry('Trinqué avec ' + v.habitant + ' : « ' + v.secret_recu + ' »', 'event-neutral');
}

// ---------- FERMES (Fred, 10/11/2026 à midi) ----------
// Une ferme ne consomme que du travail : le serveur paie les PA et dépose les produits dans l'inventaire.
Object.assign(PROV_MOTIFS, provRaisons(['inventaire_plein', 'pas_d_oeufs']));
const PROV_FERME_TRAVAUX = { ferme_renne: 'renne', ferme_traire: 'traire', ferme_legumes: 'legumes', ferme_oeufs: 'oeufs', ferme_poulet: 'poulet', ferme_lapin: 'lapin' };
const PROV_MATIERES = ['viande', 'textile', 'bois', 'laitages', 'fruits_legumes', 'oeufs'];
const provProduits = l => (Array.isArray(l) ? l : []).map(p => p.qte + ' ' + (PROV_MATIERES.includes(p.cle) ? provT('mat_' + p.cle) : p.cle)).join(', ');
const provRefus = (titre, v) => { if (typeof signalerRefusCout === 'function' && !PROV_MOTIFS[v?.raison] && v?.raison) signalerRefusCout(v); else showToast(titre, provMotif(v), false); };

async function travaillerFerme(fn) {
  const travail = PROV_FERME_TRAVAUX[fn];
  if (!travail) return;
  const v = await provActe('sovarka_ferme_travailler', { p_travail: travail }, travail);
  if (!v) return;
  if (v.ok !== true) { provRefus(provT('tFarm'), v); return; }
  showToast(provEchapper(v.label), provT('bring', { produits: provProduits(v.produits) }), true, true);
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

// ---------- FORÊT PROFONDE DE KRASNOV (Fred, 09-10/11/2026, issue #72) ----------
// On n'entre en forêt profonde, on n'y change de vue et on n'en ressort que par ces ordres : le serveur tire la vue.
Object.assign(PROV_MOTIFS, provRaisons(['deja_en_foret', 'deja_a_l_entree', 'rencontre_en_cours', 'pas_en_foret_profonde', 'coupes_epuisees',
  'quitter_groupe_pour_couper', 'chef_de_groupe_requis', 'aucune_rencontre', 'combat_en_cours', 'foret_perdu', 'foret_chemin_aleatoire']));

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
  if (v.ok !== true) { if (v.raison === 'rencontre_en_cours') { await foretReprendreRencontre(); return; } provRefus(provT('tForest'), v); return; }
  provForetRendre(v.room);
  if (sens === 'enfoncer') showToast(provT('tDeep'), provT('deeper'), true);
  else if (v.perdu) showToast(provT('tLost'), provT('lost'), false);
  else showToast(provT('tOut'), provT('out'), true);
}

async function foretCouper() {
  const v = await provActe('sovarka_foret_couper', {}, 'couper');
  if (!v) return;
  if (v.ok !== true) { if (v.raison === 'rencontre_en_cours') { await foretReprendreRencontre(); return; } provRefus(provT('tForest'), v); return; }
  if (v.rencontre === 'olga') {
    const nourris = Array.isArray(v.nourris) ? v.nourris.length : 1;
    const fenetre = () => provModal(provT('titleNoise'), '<p>' + provT('olga1') + '</p>' +
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
      '<p>' + provEchapper(v.fausse_alerte) + '</p><p class="cpj-note">' + provT('woodBack', { n: v.quantite }) + '</p>', fenetre);
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
  let html = '<p>' + provT('enc1') + '</p>' +
    '<p>' + provT('enc2', { nom: provEchapper(nom) }) + '</p>';
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
    showToast(provT('tEaten'), provT('eaten', { nom: provEchapper(v.nom) }), false);
    if (typeof relireHospitalisationServeur === 'function') await relireHospitalisationServeur(true);
  }
}
