// PARTIS DE SOVARKA (07/11/2026, décisions de Fred, GAME-DESIGN-NOVOMIRSK.md « Partis de Sovarka »).
// Le serveur (sovarka_partis_liste, sovarka_parti_commande) décide de tout : lieu, coûts, adhésion
// unique, droit d'entrée, refus à -2 POP, successeur, dissolution. L'écran n'affiche que ses réponses.

const PARTI_MOTIFS = {
  parti_non_vainqueur: 'Seul le chef du parti vainqueur de la semaine à la gloire désigne le Président du Conseil.',
  chef_pm_d_office: 'Vous n’êtes ni président ni maire : le Président du Conseil, c’est vous, d’office.',
  cible_deja_elue: 'Ce membre est déjà président ou maire.',
  salle_des_partis_requise: 'On crée un parti dans la salle des partis d’une mairie de Sovarka.',
  deja_dans_un_parti: 'Vous êtes déjà membre d’un parti : quittez-le d’abord.',
  demande_en_cours: 'Vous avez déjà une demande d’adhésion en attente.',
  nom_requis: 'Donnez un nom au parti (2 caractères au moins).',
  nom_deja_pris: 'Un parti porte déjà ce nom.',
  texte_trop_long: 'Nom (40 caractères) ou description (200 caractères) trop long.',
  reserve_au_chef: 'Réservé au chef du parti.',
  reserve_a_sovarka: 'Les partis n’existent qu’en Sovarka.',
  prix_invalide: 'Le droit d’entrée doit être un nombre entier de PSK, entre 0 et 100 000.',
  demande_absente: 'Cette demande n’existe plus.',
  membre_absent: 'Ce camarade n’est pas membre du parti.',
  candidat_deja_dans_un_parti: 'Ce candidat a rejoint un autre parti entre-temps.',
  fonds_insuffisants_candidat: 'Le candidat n’a pas de quoi payer le droit d’entrée : la demande reste en attente.',
  successeur_requis: 'Le chef doit désigner un successeur avant de quitter le parti.',
  parti_introuvable: 'Ce parti n’existe plus.',
  pa_insuffisants: 'Vous n’avez pas assez de PA.',
  fonds_insuffisants: 'Vous n’avez pas assez de PSK.',
  acteur_non_authentifie: 'Votre session doit être rétablie.'
};
const PARTI_VILLES = { capitale: 'Novomirsk', ville_a: 'Starovka', ville_b: 'Krasnov' };
let partiDonnees = null;
let partiEnCours = false;
const partiE = v => (typeof vehEchappe === 'function') ? vehEchappe(v)
  : String(v == null ? '' : v).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

async function partiCharger() {
  const v = await sbRpcVerdict('sovarka_partis_liste', {}).catch(() => null);
  if (!v || v.ok !== true) { showToast('Partis', 'Le serveur n’a pas répondu.', false); return null; }
  partiDonnees = v;
  return v;
}

function partiEstDansSalle() {
  return state.currentRoom === 'salle_partis';
}

function partiListeHtml(partis) {
  if (!partis.length) return '<p class="cpj-note">Aucun parti n’est encore constitué.</p>';
  return partis.map((p, i) =>
    '<div style="border-top:1px solid #344354;padding:.5rem 0">' +
      '<b>' + partiE(p.nom) + '</b> — chef : ' + partiE(p.chef) + ' · siège : ' + partiE(PARTI_VILLES[p.siege] || p.siege) +
      '<br><span class="cpj-note">' + (p.desc ? partiE(p.desc) + ' · ' : '') + p.membres + ' membre' + (p.membres > 1 ? 's' : '') +
      ' · popularité ' + p.pop + ' · droit d’entrée ' + p.prix + ' PSK (payé à l’acceptation)</span><br>' +
      (p.demande_en_cours ? '<span class="cpj-note">Votre demande est en attente.</span>'
        : (partiDonnees && !partiDonnees.mon_parti ? vehBouton('Demander l’adhésion (2 PA)', 'partiDemander(' + i + ')', false) : '')) +
    '</div>').join('');
}

// « Postuler à un poste » : en Sovarka, le parti d'abord (Fred, 07/11/2026).
async function sovarkaPostuler() {
  if (state.country !== 'soviet') { ouvrirEcranPostes(); return; }
  const v = await partiCharger();
  if (!v) return;
  if (v.mon_parti) { ouvrirEcranPostes(); return; }
  vehModal('Postuler à un poste',
    '<p><b>Vous ne pouvez pas obtenir un poste si vous n’adhérez pas à un parti.</b></p>' +
    vehSection('Partis constitués', partiListeHtml(v.partis)) +
    vehSection('Créer un parti', '<p>2 PA et 15 PSK de droits d’enregistrement. Un parti se crée dans la <b>salle des partis</b> ' +
      'd’une mairie ; il est national et a son siège dans la ville où il est créé.</p>' +
      (partiEstDansSalle() ? vehBouton('Créer un parti', 'partiFormulaireCreation()', true) : '')));
}

async function ouvrirSovarkaPartis() {
  const v = await partiCharger();
  if (!v) return;
  vehModal('Salle des partis', vehSection('Partis constitués', partiListeHtml(v.partis)));
}

function partiFormulaireCreation() {
  vehModal('Créer un parti',
    '<p>Fonder un parti coûte 2 PA et 15 PSK de droits d’enregistrement. Vous en serez le chef ; son siège sera dans cette ville.</p>' +
    '<input id="parti-nom" class="cpj-champ" maxlength="40" placeholder="Nom du parti" style="width:100%"><br>' +
    '<textarea id="parti-desc" class="cpj-champ" maxlength="200" rows="3" placeholder="Programme (facultatif)" style="width:100%;margin-top:.4rem"></textarea><br>' +
    vehBouton('Fonder le parti', 'partiFonder()', true));
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
      showToast('Refusé', PARTI_MOTIFS[v?.raison] || 'Le serveur n’a pas confirmé l’opération.', false);
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
  showToast('Parti fondé', 'Le parti « ' + v.nom + ' » est enregistré. Vous en êtes le chef.', true);
  if (typeof addJournalEntry === 'function') addJournalEntry('Fondation du parti ' + v.nom + '.', 'event-info');
}

async function partiDemander(i) {
  const p = partiDonnees?.partis?.[i];
  if (!p) return;
  const v = await partiCommande('demander', p.id, {});
  if (!v) return;
  document.getElementById('modal-postes')?.classList.remove('open');
  showToast('Demande envoyée', 'Votre demande d’adhésion au parti « ' + v.nom + ' » attend la décision de son chef.', true);
}

async function ouvrirSovarkaMonParti() {
  const v = await partiCharger();
  if (!v) return;
  const m = v.mon_parti;
  if (!m) { ouvrirSovarkaPartis(); return; }
  let html = '<p><b>' + partiE(m.nom) + '</b> — chef : ' + partiE(m.chef) + ' · siège : ' + partiE(PARTI_VILLES[m.siege] || m.siege) +
    ' · popularité ' + m.pop + ' · droit d’entrée ' + m.prix + ' PSK' + (m.est_chef ? ' · caisse ' + m.caisse + ' PSK' : '') + '</p>';
  html += vehSection('Membres', m.membres.map((x, i) => '<div>' + partiE(x.nom) + ' — ' + partiE(x.grade) +
    (m.est_chef && x.nom !== m.chef ? ' ' + vehBouton('Désigner comme successeur', 'partiSuccesseur(' + i + ')', false) : '') +
    (m.peut_designer_pm && x.nom !== m.chef ? ' ' + vehBouton('Désigner Président du Conseil', 'partiDesignerPm(' + i + ')', true) : '') + '</div>').join(''));
  if (m.peut_designer_pm) html += '<p class="cpj-note">Votre parti a remporté la semaine à la gloire et vous êtes déjà élu : '
    + 'désignez le Président du Conseil du Peuple parmi les membres du parti.</p>';
  if (m.est_chef) {
    html += vehSection('Demandes d’adhésion', m.demandes.length
      ? m.demandes.map((x, i) => '<div>' + partiE(x.nom) + ' ' + vehBouton('Accepter', 'partiRepondre(' + i + ',true)', true) + ' ' +
          vehBouton('Refuser (−2 POP au parti)', 'partiRepondre(' + i + ',false)', false) + '</div>').join('')
      : '<p class="cpj-note">Aucune demande en attente.</p>');
    html += vehSection('Soviet Suprême', '<p class="cpj-note">Sièges obtenus à la semaine à la gloire ; désignez les députés de votre parti.</p>' +
      vehBouton('Sièges et députés', 'ouvrirSovietSupreme()', false));
    html += vehSection('Lois et manifestations', '<p class="cpj-note">Déposer un projet de loi au nom du parti (1 PA) ; '
      + 'organiser une manifestation de soutien au parti au pouvoir, qui part de la mairie, avec au moins 10 manifestants de votre groupe présents (1 PA).</p>'
      + vehBouton('Déposer un projet de loi', 'ouvrirSovarkaDeposerLoi()', true)
      + vehBouton('Manifestation de soutien', 'sovarkaManifSoutien()', false));
    html += vehSection('Droit d’entrée', '<input id="parti-prix" class="cpj-champ" type="number" min="0" step="1" value="' + m.prix + '"> PSK ' +
      vehBouton('Fixer', 'partiFixerPrix()', false));
  }
  html += vehSection('Quitter le parti', '<p class="cpj-note">1 PA. ' + (m.est_chef
    ? 'Le chef doit d’abord désigner un successeur ; s’il est le dernier membre, le parti est dissous.' : '') + '</p>' +
    vehBouton('Quitter', 'partiQuitter()', false));
  vehModal('Mon parti', html);
}

async function partiRepondre(i, accepter) {
  const m = partiDonnees?.mon_parti, x = m?.demandes?.[i];
  if (!x) return;
  const v = await partiCommande(accepter ? 'accepter' : 'refuser', m.id, { nom: x.nom }, x.nom);
  if (!v) return;
  showToast(accepter ? 'Adhésion acceptée' : 'Adhésion refusée',
    accepter ? x.nom + ' rejoint le parti' + (v.prix ? ' (' + v.prix + ' PSK versés à la caisse).' : '.')
             : 'Demande de ' + x.nom + ' refusée. Popularité du parti : ' + v.pop + '.', true);
  ouvrirSovarkaMonParti();
}

async function partiFixerPrix() {
  const m = partiDonnees?.mon_parti;
  const prix = Number(document.getElementById('parti-prix')?.value);
  if (!m) return;
  const v = await partiCommande('fixer_prix', m.id, { prix }, String(prix));
  if (v) { showToast('Droit d’entrée', 'Fixé à ' + v.prix + ' PSK.', true); ouvrirSovarkaMonParti(); }
}

async function partiSuccesseur(i) {
  const m = partiDonnees?.mon_parti, x = m?.membres?.[i];
  if (!x) return;
  const v = await partiCommande('successeur', m.id, { nom: x.nom }, x.nom);
  if (v) { showToast('Successeur désigné', x.nom + ' dirige désormais le parti.', true); ouvrirSovarkaMonParti(); }
}

async function partiDesignerPm(i) {
  const m = partiDonnees?.mon_parti, x = m?.membres?.[i];
  if (!x) return;
  const v = await partiCommande('designer_pm', m.id, { nom: x.nom }, x.nom);
  if (v) { showToast('Président du Conseil', v.nom + ' est désormais Président du Conseil du Peuple.', true); ouvrirSovarkaMonParti(); }
}

async function partiQuitter() {
  const m = partiDonnees?.mon_parti;
  if (!m) return;
  const v = await partiCommande('quitter', m.id, {});
  if (!v) return;
  document.getElementById('modal-postes')?.classList.remove('open');
  showToast('Parti quitté', v.dissous ? 'Vous étiez le dernier membre : le parti « ' + v.nom + ' » est dissous.'
    : 'Vous avez quitté le parti « ' + v.nom + ' ».', true);
}
