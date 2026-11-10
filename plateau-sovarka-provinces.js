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

// ---------- FERMES (Fred, 10/11/2026 à midi) ----------
// Une ferme ne consomme que du travail : le serveur paie les PA et dépose les produits dans l'inventaire.
Object.assign(PROV_MOTIFS, {
  inventaire_plein: 'Votre inventaire est plein.',
  pas_d_oeufs: 'Vous n’avez pas d’œufs sur vous.'
});
const PROV_FERME_TRAVAUX = { ferme_renne: 'renne', ferme_traire: 'traire', ferme_legumes: 'legumes', ferme_oeufs: 'oeufs', ferme_poulet: 'poulet', ferme_lapin: 'lapin' };
const PROV_MATIERES = { viande: 'viande', textile: 'tissus et peaux', bois: 'bois', laitages: 'laitages', fruits_legumes: 'fruits et légumes', oeufs: 'œufs (par 3)' };
const provProduits = l => (Array.isArray(l) ? l : []).map(p => p.qte + ' ' + (PROV_MATIERES[p.cle] || p.cle)).join(', ');
const provRefus = (titre, v) => { if (typeof signalerRefusCout === 'function' && !PROV_MOTIFS[v?.raison] && v?.raison) signalerRefusCout(v); else showToast(titre, provMotif(v), false); };

async function travaillerFerme(fn) {
  const travail = PROV_FERME_TRAVAUX[fn];
  if (!travail) return;
  const v = await provActe('sovarka_ferme_travailler', { p_travail: travail }, travail);
  if (!v) return;
  if (v.ok !== true) { provRefus('Ferme', v); return; }
  showToast(provEchapper(v.label), 'Vous rapportez : ' + provProduits(v.produits) + '.', true, true);
  if (typeof addJournalEntry === 'function') addJournalEntry(v.label + ' : ' + provProduits(v.produits) + '.', 'event-good');
}

// Œufs : toujours par 3, mangés d'un coup, sans PA ; +2 PA au prochain sommeil.
async function mangerOeufs() {
  const v = await provActe('sovarka_oeufs_manger', {}, 'manger');
  if (!v) return;
  if (v.ok !== true) { provRefus('Œufs', v); return; }
  document.getElementById('modal-postes')?.classList.remove('open');
  showToast('Trois œufs avalés', '+' + v.bonus + ' PA à votre prochain sommeil.', true, true);
  if (typeof addJournalEntry === 'function') addJournalEntry('Vous mangez trois œufs : +' + v.bonus + ' PA au prochain sommeil.', 'event-good');
}

// ---------- FORÊT PROFONDE DE KRASNOV (Fred, 09-10/11/2026, issue #72) ----------
// On n'entre en forêt profonde, on n'y change de vue et on n'en ressort que par ces ordres : le serveur tire la vue.
Object.assign(PROV_MOTIFS, {
  deja_en_foret: 'Vous êtes déjà sous les arbres.',
  deja_a_l_entree: 'Vous êtes à l’entrée de la forêt.',
  rencontre_en_cours: 'Quelque chose vous fait face : impossible de l’ignorer.',
  pas_en_foret_profonde: 'On ne coupe ce bois-là qu’en forêt profonde.',
  coupes_epuisees: 'Vous avez coupé tout ce qu’on peut couper ici sans attirer les ennuis. Revenez vers l’entrée.',
  quitter_groupe_pour_couper: 'En groupe, seul le chef coupe : quittez le groupe pour couper pour vous (et prendre seul le risque).',
  chef_de_groupe_requis: 'Seul le chef du groupe décide du chemin.',
  aucune_rencontre: 'Il n’y a plus rien devant vous.',
  combat_en_cours: 'Le combat est engagé.',
  foret_perdu: 'Vous êtes en pleine forêt : « Revenir à l’entrée de la forêt » est le seul chemin.',
  foret_chemin_aleatoire: 'On ne choisit pas son chemin sous les arbres : « S’enfoncer dans la forêt ».'
});

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
  if (v.ok !== true) { if (v.raison === 'rencontre_en_cours') { await foretReprendreRencontre(); return; } provRefus('Forêt', v); return; }
  provForetRendre(v.room);
  if (sens === 'enfoncer') showToast('Forêt profonde', 'Vous vous enfoncez sous les arbres. Le chemin disparaît derrière vous.', true);
  else if (v.perdu) showToast('Perdu !', 'Vous avez tourné en rond : vous voici ailleurs dans la forêt.', false);
  else showToast('Sorti du bois', 'Vous retrouvez l’entrée de la forêt.', true);
}

async function foretCouper() {
  const v = await provActe('sovarka_foret_couper', {}, 'couper');
  if (!v) return;
  if (v.ok !== true) { if (v.raison === 'rencontre_en_cours') { await foretReprendreRencontre(); return; } provRefus('Forêt', v); return; }
  if (v.rencontre === 'olga') {
    const nourris = Array.isArray(v.nourris) ? v.nourris.length : 1;
    vehModal('Un bruit dans les fourrés…', '<p>Les branches craquent, une masse sombre approche… vous serrez votre hache.</p>' +
      '<p>Ce n’est pas l’ours. C’est <strong>Olga</strong>, la vieille de l’isba, une marmite fumante dans les bras : ' +
      '« Mange, mon petit, tu es tout maigre ! »</p>' +
      '<p class="cpj-note">Un repas ordinaire : +' + v.bonus + ' PA au prochain sommeil' + (nourris > 1 ? ', pour chacun des ' + nourris + ' membres du groupe.' : '.') + '</p>');
    if (typeof addJournalEntry === 'function') addJournalEntry('Olga vous a nourri dans la forêt profonde.', 'event-good');
    return;
  }
  if (v.rencontre === 'attaque') { foretAfficherRencontre(v.nom, v.pnj); return; }
  if (v.fausse_alerte) {
    vehModal('Un bruit dans les fourrés…', '<p>Les branches craquent derrière vous. Vous lâchez presque votre hache…</p>' +
      '<p>' + provEchapper(v.fausse_alerte) + '</p><p class="cpj-note">Vous rapportez ' + v.quantite + ' bois.</p>');
  } else {
    showToast('Bois coupé', v.quantite + ' bois de la forêt profonde.', true, true);
  }
  if (typeof addJournalEntry === 'function') addJournalEntry('Forêt profonde : ' + v.quantite + ' bois coupés.', 'event-good');
}

async function foretReprendreRencontre() {
  const v = await sbRpcVerdict('sovarka_foret_lire', {}).catch(() => null);
  if (v?.ok === true && v.rencontre) foretAfficherRencontre(v.rencontre.nom, v.rencontre.pnj);
  else showToast('Forêt', provMotif({ raison: 'rencontre_en_cours' }), false);
}

function foretAfficherRencontre(nom, pnj) {
  const js = s => JSON.stringify(String(s)).replace(/"/g, '&quot;');
  let html = '<p>Un bruit dans les fourrés… et cette fois, ce n’est ni un lièvre ni un tractoriste perdu.</p>' +
    '<p><strong>' + provEchapper(nom) + '</strong> surgit d’entre les arbres et vous barre le chemin.</p>';
  const modes = (typeof NEUTRALISER_MODES === 'object' && NEUTRALISER_MODES) ? NEUTRALISER_MODES : { mains: { label: 'À mains nues' } };
  html += vehSection('Combattre', Object.keys(modes).map(m => {
    const possede = m === 'mains' || typeof neutraliserPossedeArme !== 'function' || neutraliserPossedeArme(m);
    return possede ? vehBouton(provEchapper(modes[m].label), 'foretCombattre(' + js(pnj) + ',' + js(m) + ')', m === 'mains') : '';
  }).join(''));
  html += vehSection('Ou bien', vehBouton('Fuir (vous lâchez le bois coupé ici)', 'foretChoisir(\'fuir\')') +
    vehBouton('Ne pas se défendre', 'foretChoisir(\'subir\')') +
    '<p class="cpj-note">On ne meurt jamais dans le jeu : un combat perdu, et l’on se réveille à l’hôpital.</p>');
  vehModal('Rencontre en forêt profonde', html);
}

async function foretCombattre(pnj, mode) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const v = await sbCombatOuvrir(pnj, mode);
  if (v?.ok !== true || !Number.isSafeInteger(Number(v.bataille))) { showToast('Combat non engagé', PROV_MOTIFS[v?.raison] || v?.raison || 'Réponse du serveur non confirmée.', false); return; }
  if (v.paie && typeof appliquerPaiementServeur === 'function') appliquerPaiementServeur(v.paie);
  if (typeof ouvrirPanneauCombat === 'function') await ouvrirPanneauCombat(Number(v.bataille));
}

async function foretChoisir(choix) {
  const v = await provActe('sovarka_foret_rencontre', { p_choix: choix }, choix);
  if (!v) return;
  if (v.ok !== true) { provRefus('Forêt', v); return; }
  document.getElementById('modal-postes')?.classList.remove('open');
  if (choix === 'fuir') {
    provForetRendre(v.room);
    showToast('Sauve qui peut !', 'Vous détalez jusqu’à l’entrée de la forêt' + (v.bois_perdu ? ', en lâchant ' + v.bois_perdu + ' bois.' : '.'), false);
  } else {
    showToast('Bon appétit…', provEchapper(v.nom) + ' ne s’est pas fait prier. Vous vous réveillerez à l’hôpital.', false);
    if (typeof relireHospitalisationServeur === 'function') await relireHospitalisationServeur(true);
  }
}
