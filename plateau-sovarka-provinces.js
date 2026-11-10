// SOVARKA : LOT DES PROVINCES (10/11/2026, décisions de Fred, GAME-DESIGN-NOVOMIRSK.md,
// « Réponses de Fred »). Bons d'État, centres d'écoute, maisons, forêt de Krasnov.
// Le serveur décide tout ; l'écran n'affiche que ses réponses (règle « une seule réalité »).

const PROV_MOTIFS = {
  acteur_non_authentifie: 'Votre session doit être rétablie.',
  pas_sur_place: 'Présentez-vous sur place.',
  montant_invalide: 'Indiquez un montant entier positif.',
  fonds_insuffisants: 'Vous n’avez pas cette somme (liquide et Banque nationale).',
  requete_etrangere: 'Requête refusée.'
};
const provMotif = v => PROV_MOTIFS[v?.raison] || (v?.transport ? 'Réponse du serveur non reçue : réessayez, la même requête sera rejouée sans repayer.' : 'Refusé par le serveur.');
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
async function ouvrirBonsEtat() {
  const v = await sbRpcVerdict('sovarka_bons_etat_lire', {}).catch(() => null);
  if (!v || v.ok !== true) { showToast('Bons d’État', provMotif(v), false); return; }
  const j = v.jour || {};
  let html = '<p>« Soutenez l’économie de Sovarka ! » Le bon d’État est un geste patriotique : il ne donne aucun ' +
    'avantage en jeu. Votre argent va au Trésor de Sovarka, qui vous le rend dans <strong>7 jours</strong>, ' +
    'augmenté ou diminué du rendement fixé aujourd’hui.</p>' +
    '<p class="cpj-note">Rendement du jour : <strong>' + j.taux + ' %</strong> (indice Économie moyen des trois villes : ' +
    j.indice + ' / 100 ; de −10 % au plus bas à +3 % au plus haut). Si le Trésor est vide à l’échéance, la Banque ' +
    'imprime les billets : vous êtes remboursé à −10 %, quel que soit le rendement prévu.</p>';
  html += vehSection('Souscrire', '<div style="margin-top:.4rem">' + vehChamp('bon-etat-montant', 100) + ' PSK' +
    vehBouton('Souscrire', 'souscrireBonEtat()', true) + '</div>');
  const bons = Array.isArray(v.bons) ? v.bons : [];
  if (bons.length) {
    html += vehSection('Mes bons', bons.map(b => '<div style="margin:.3rem 0">' + b.montant + ' PSK à ' + b.taux + ' % — ' +
      (b.statut === 'rembourse'
        ? 'remboursé ' + b.rembourse + ' PSK' + (b.planche_a_billets ? ' (planche à billets)' : '')
        : 'échéance le ' + new Date(b.echeance + 'T12:00:00').toLocaleDateString('fr-FR')) + '</div>').join(''));
  }
  vehModal('Bons d’État de Sovarka', html);
}

async function souscrireBonEtat() {
  const montant = vehLireChamp('bon-etat-montant');
  if (!(montant > 0)) { showToast('Bons d’État', PROV_MOTIFS.montant_invalide, false); return; }
  const v = await provActe('sovarka_bon_etat_souscrire', { p_montant: montant }, 'souscrire:' + montant);
  if (!v) return;
  if (v.ok !== true) { showToast('Bons d’État', provMotif(v), false); return; }
  showToast('Bon d’État souscrit', v.montant + ' PSK à ' + v.taux + ' %, rendus le ' +
    new Date(v.echeance + 'T12:00:00').toLocaleDateString('fr-FR') + '.', true, true);
  if (typeof addJournalEntry === 'function') addJournalEntry('Bon d’État souscrit : ' + v.montant + ' PSK à ' + v.taux + ' %.', 'event-good');
  await ouvrirBonsEtat();
}

// ---------- CENTRES D'ÉCOUTE ----------
Object.assign(PROV_MOTIFS, {
  pas_ministre_defense: 'Seul le ministre de la Défense de Sovarka reçoit les rapports des cellules d’écoute.',
  rapport_introuvable: 'Ce rapport n’existe pas.',
  ministre_defense: 'Le ministre de la Défense n’a pas besoin de voler ses propres archives : demandez le rapport depuis votre bureau.',
  archives_vides: 'Les archives de ce centre sont encore vides.'
});
const PROV_CENTRES = { novomirsk: 'Novomirsk', starovka: 'Starovka', krasnov: 'Krasnov' };

async function ouvrirEcoutesMinistre() {
  const v = await sbRpcVerdict('sovarka_ecoutes_lire', {}).catch(() => null);
  if (!v || v.ok !== true) { showToast('Centres d’écoute', provMotif(v), false); return; }
  const rapports = Array.isArray(v.rapports) ? v.rapports : [];
  let html = '<p>Chaque nuit, les cellules d’écoute compilent les mails interceptés la veille (environ un sur dix). ' +
    'Novomirsk écoute la ville et la Républia, Starovka la ville et El Estado, Krasnov la ville et Al-Khalija. ' +
    'Demandez un rapport : il vous arrive par mail.</p>';
  if (!rapports.length) html += '<p class="cpj-note">Aucun rapport consigné pour l’instant.</p>';
  else html += vehSection('Rapports des 30 derniers jours', rapports.map(r => {
    const js = 'demanderRapportEcoute(' + JSON.stringify(r.centre).replace(/"/g, '&quot;') + ',' + JSON.stringify(r.jour).replace(/"/g, '&quot;') + ')';
    return '<div style="margin:.3rem 0">' + PROV_CENTRES[r.centre] + ' — ' + new Date(r.jour + 'T12:00:00').toLocaleDateString('fr-FR') +
      ' · ' + r.nb + ' interception(s)' + vehBouton('Demander', js) + '</div>';
  }).join(''));
  vehModal('Centres d’écoute', html);
}

async function demanderRapportEcoute(centre, jour) {
  const v = await sbRpcVerdict('sovarka_ecoute_rapport_demander', { p_centre: centre, p_jour: jour }).catch(() => null);
  if (!v || v.ok !== true) { showToast('Centres d’écoute', provMotif(v), false); return; }
  showToast('Rapport demandé', 'Le rapport de ' + PROV_CENTRES[centre] + ' vous a été envoyé par mail.', true);
}

async function volerArchivesEcoute() {
  const v = await provActe('sovarka_ecoute_archives_voler', {}, 'vol');
  if (!v) return;
  if (v.ok !== true) { showToast('Archives', provMotif(v), false); return; }
  if (typeof adopterEtatCrimeServeur === 'function') adopterEtatCrimeServeur(v);
  if (v.reussi) {
    showToast('Rapport dérobé', 'Vous filez avec le rapport de ' + PROV_CENTRES[v.centre] + ' : il est dans vos mails. Vous avez laissé une trace.', true, true);
    if (typeof addJournalEntry === 'function') addJournalEntry('Rapport d’écoute volé (' + PROV_CENTRES[v.centre] + ').', 'event-bad');
  } else {
    showToast('Pris sur le fait', 'L’opérateur vous tombe dessus : après la bagarre, direction la prison.', false);
    if (typeof addJournalEntry === 'function') addJournalEntry('Surpris en volant les archives d’écoute : arrêté.', 'event-bad');
    if (v.arrestation && typeof adopterArrestationServeur === 'function') await adopterArrestationServeur(v.arrestation);
  }
}

// ---------- MAISONS (hospitalité russe) ----------
Object.assign(PROV_MOTIFS, {
  service_non_rendu: 'Rendez d’abord le service demandé par l’habitant.',
  deja_mange: 'Vous avez déjà mangé ici aujourd’hui.',
  deja_heberge: 'Vous avez déjà rendu service aujourd’hui : vous êtes chez vous.',
  heberge_ailleurs: 'Vous avez déjà été accueilli dans une autre maison aujourd’hui (une hospitalité par jour).',
  service_incomplet: 'Il vous manque de quoi rendre ce service.',
  aucun_service: 'L’habitant n’a besoin de rien aujourd’hui.',
  pas_de_bouteille: 'Il vous faut une bouteille d’alcool dans votre inventaire.',
  acteur_indisponible: 'Vous n’êtes pas en état.'
});

async function ouvrirMaisonHabitant() {
  const v = await sbRpcVerdict('sovarka_maison_lire', {}).catch(() => null);
  if (!v || v.ok !== true) { showToast('Maison', provMotif(v), false); return; }
  const nom = provEchapper(v.habitant);
  let html;
  if (v.heberge) {
    html = '<p>« Fais comme chez toi, étranger. »</p>' +
      (v.mange ? '<p class="cpj-note">Vous avez déjà mangé. Vous pouvez dormir ici ce soir (« Dormir chez l’habitant »).</p>'
               : vehBouton('Partager le repas', 'agirMaisonHabitant(\'manger\')', true) + '<p class="cpj-note">Un repas ordinaire : +2 PA à votre prochain sommeil.</p>');
  } else if (v.heberge_ailleurs) {
    html = '<p>« Tu as déjà un toit pour ce soir, à ce que je vois. Reviens demain ! »</p>';
  } else if (!v.service) {
    html = '<p>« Je n’ai besoin de rien aujourd’hui… reviens demain, étranger. »</p>';
  } else {
    html = '<p>« Tu peux rester manger et dormir ici, étranger. Je te demande juste de me ramener ' +
      provEchapper(v.service.label) + '. »</p>' + vehBouton('Donner ' + provEchapper(v.service.label), 'agirMaisonHabitant(\'service\')', true);
  }
  html += '<p class="cpj-note" style="margin-top:.7rem">Vous pouvez aussi trinquer avec ' + nom + ' : apportez une bouteille.' +
    (v.bouteille ? '' : ' Vous n’en avez pas sur vous.') + '</p>';
  vehModal(nom, html);
}

async function agirMaisonHabitant(action) {
  const v = await provActe('sovarka_maison_agir', { p_action: action }, action);
  if (!v) return;
  if (v.ok !== true) { showToast('Maison', provMotif(v), false); return; }
  if (action === 'service') showToast('Service rendu', provEchapper(v.habitant) + ' vous ouvre sa porte : repas et lit pour ce soir.', true, true);
  if (action === 'manger') showToast('Repas partagé', '+' + v.bonus + ' PA à votre prochain sommeil.', true, true);
  await ouvrirMaisonHabitant();
}

async function trinquerHabitant() {
  const v = await provActe('sovarka_maison_agir', { p_action: 'trinquer' }, 'trinquer');
  if (!v) return;
  if (v.ok !== true) { if (typeof signalerRefusCout === 'function' && !PROV_MOTIFS[v.raison]) signalerRefusCout(v); else showToast('Trinquer', provMotif(v), false); return; }
  vehModal('Na zdorovie !', '<p>« ' + provEchapper(v.reaction) + ' »</p>' +
    vehSection('Ce que vous apprenez', '<p>« ' + provEchapper(v.secret_recu) + ' »</p>') +
    vehSection('Ce qui vous échappe', '<p class="cpj-note">L’alcool aidant, vous en avez trop dit : ' + provEchapper(v.secret_livre) + '</p>') +
    vehBouton('Encore une bouteille (3 PA)', 'trinquerHabitant()', false));
  if (typeof addJournalEntry === 'function') addJournalEntry('Trinqué avec ' + v.habitant + ' : « ' + v.secret_recu + ' »', 'event-neutral');
}
