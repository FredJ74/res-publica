/* ===========================================================================
   PIRATAGE ET DOSSIERS INFORMATIQUES (11 novembre 2026)
   ===========================================================================

   Decisions de Fred (GAME-DESIGN-EQUIPEMENTS.md, decisions 6 a 11 et 16) : depuis
   son bureau connecte, 3 PA par tentative contre une banque (PJ ou organisation),
   un registre de ville, les casernes ou l'ordinateur d'un PJ ; le rapport arrive
   par mail et se range dans les dossiers. Les dossiers vivent sur l'ordinateur
   (20) ou le peripherique de stockage (180) ; le proprietaire les lit, les deplace,
   les detruit ou les transmet (1 PA).

   TOUT EST DECIDE PAR LE SERVEUR (pirater, piratage_dossier_agir, dossiers_lire,
   dossier_ouvrir, dossier_deplacer, dossier_detruire, dossier_transferer).
   =========================================================================== */

const INFORMATIQUE_REFUS = {
  pas_de_connexion: 'Il faut être dans votre bureau, avec votre ordinateur et votre box installés.',
  pa_insuffisants: 'Vous n\'avez pas assez de PA.',
  cible_inconnue: 'Cible introuvable.',
  registre_inconnu: 'Registre inconnu ici.',
  cible_invalide: 'Cible invalide.',
  acces_expire: 'L\'accès obtenu a expiré ou a déjà servi : il faut pirater à nouveau.',
  dossier_inaccessible: 'Ce dossier n\'est pas accessible.',
  support_absent_ou_plein: 'Pas d\'autre support disponible (ou il est plein).',
  destinataire_inconnu: 'Destinataire inconnu.'
};
function informatiqueRefus(r) {
  return (r && INFORMATIQUE_REFUS[r.raison] && texteEquip('in.' + r.raison, INFORMATIQUE_REFUS[r.raison])) || (typeof equipementsRefus === 'function' ? equipementsRefus(r) : texteEquip('refuse', 'Refusé.'));
}
function informatiqueEch(t) {
  return typeof equipementsEchapper === 'function' ? equipementsEchapper(t) : String(t == null ? '' : t);
}
async function informatiqueRpc(nom, params) {
  if (typeof sbRpcVerdict === 'function') return sbRpcVerdict(nom, params || {}).catch(() => null);
  if (typeof sbRpc === 'function') return sbRpc(nom, params || {}).catch(() => null);
  return null;
}
function informatiquePa(r) {
  if (r && typeof r.pa === 'number' && state.char) { state.char.pa = r.pa; if (typeof updateUI === 'function') updateUI(); }
}
function informatiqueTexte(t) {
  return '<pre style="white-space:pre-wrap;font-family:inherit;font-size:.85rem;background:#0f1419;border:1px solid #2a3340;padding:.6rem;max-height:50vh;overflow:auto">' + informatiqueEch(t) + '</pre>';
}

function ouvrirPiratage() {
  const sov = state.country === 'soviet';
  const h = '<p class="cpj-note">' + texteEquip('pirIntro', '3 PA par tentative. Réussite de base 45 %, selon votre intelligence. Un intranet protège presque toujours un ordinateur. Tout piratage laisse une trace ; un échec peut alerter la cible.') + '</p>' +
    '<div class="cpj-titre">' + texteEquip('comptesBanque', 'Comptes en banque') + '</div>' +
    '<input id="pirate-banque" placeholder="' + texteEquip('nomPjOrga', 'Nom d\'un PJ ou d\'une organisation') + '" style="width:100%;margin-bottom:.4rem"> ' +
    equipementsBouton('piraterLancer(\'banque\')', texteEquip('pirBanque', 'Pirater la banque'), true) +
    '<div class="cpj-titre">' + texteEquip('registresVille', 'Registres de votre ville') + '</div>' +
    equipementsBouton('piraterLancer(\'registre\',\'armes\')', texteEquip('ventesArmes', 'Ventes d\'armes')) + ' ' +
    equipementsBouton('piraterLancer(\'registre\',\'plaintes\')', texteEquip('plaintes', 'Plaintes')) + ' ' +
    equipementsBouton('piraterLancer(\'registre\',\'carceral\')', texteEquip('regCarceral', 'Registre carcéral')) +
    (sov ? ' ' + equipementsBouton('piraterLancer(\'registre\',\'signalements\')', texteEquip('signalements', 'Signalements')) : '') +
    '<div class="cpj-titre">' + texteEquip('casernes', 'Casernes') + '</div>' + equipementsBouton('piraterLancer(\'caserne\',\'\')', texteEquip('pirCasernes', 'Pirater les casernes')) +
    '<div class="cpj-titre">' + texteEquip('ordiPj', 'Ordinateur d\'un PJ') + '</div>' +
    '<input id="pirate-ordi" placeholder="' + texteEquip('nomPj', 'Nom du PJ') + '" style="width:100%;margin-bottom:.4rem"> ' +
    equipementsBouton('piraterLancer(\'ordinateur\')', texteEquip('pirOrdi', 'Pirater son ordinateur')) +
    '<div style="margin-top:1rem">' + equipementsBouton('ouvrirModalEquipements()', texteEquip('retour', 'Retour')) + '</div>';
  equipementsModale(texteEquip('piratage', 'Piratage'), h);
}

async function piraterLancer(cible, parametre) {
  if (cible === 'banque') parametre = (document.getElementById('pirate-banque')?.value || '').trim();
  if (cible === 'ordinateur') parametre = (document.getElementById('pirate-ordi')?.value || '').trim();
  if ((cible === 'banque' || cible === 'ordinateur') && !parametre) { showToast(texteEquip('piratage', 'Piratage'), texteEquip('indiquerCible', 'Indiquez une cible.'), false); return; }
  const r = await informatiqueRpc('pirater', { p_cible: cible, p_parametre: parametre || '', p_ville: null });
  if (!r || r.ok !== true) { showToast(texteEquip('pirImpossible', 'Piratage impossible'), informatiqueRefus(r), false); return; }
  informatiquePa(r);
  if (!r.reussi) {
    equipementsModale(texteEquip('piratage', 'Piratage'), '<p class="cpj-note">' + texteEquip('pirEchec', 'Échec (jet {jet} pour {taux} %{intranet}). Les 3 PA sont perdus ; la cible a peut-être été alertée.', {jet: r.jet, taux: r.taux, intranet: r.intranet ? texteEquip('intranetV', ', intranet') : ''}) + '</p>' + equipementsBouton('ouvrirPiratage()', texteEquip('retour', 'Retour')));
    return;
  }
  if (cible === 'ordinateur') {
    const lignes = (r.dossiers || []).map(d => '<div style="display:flex;justify-content:space-between;gap:.4rem;padding:.3rem 0;border-top:1px solid #2a3340">' +
      '<span>' + informatiqueEch(d.titre) + '</span><span>' +
      equipementsBouton('piratageDossier(\'' + informatiqueEch(r.cible) + '\',\'' + d.id + '\',\'lire\')', texteEquip('lire', 'Lire')) + ' ' +
      equipementsBouton('piratageDossier(\'' + informatiqueEch(r.cible) + '\',\'' + d.id + '\',\'copier\')', texteEquip('copier', 'Copier')) + ' ' +
      equipementsBouton('piratageDossier(\'' + informatiqueEch(r.cible) + '\',\'' + d.id + '\',\'detruire\')', texteEquip('detruire', 'Détruire')) + '</span></div>').join('');
    equipementsModale(texteEquip('pirReussi', 'Piratage réussi'), '<p class="cpj-note">' + texteEquip('dansOrdi', 'Vous êtes dans l\'ordinateur de {cible}. Une seule action possible sur un seul dossier.', {cible: informatiqueEch(r.cible)}) + '</p>' + (lignes || '<p class="cpj-note">' + texteEquip('aucunDossier', 'Aucun dossier.') + '</p>') +
      '<div style="margin-top:1rem">' + equipementsBouton('ouvrirPiratage()', texteEquip('retour', 'Retour')) + '</div>');
    return;
  }
  equipementsModale(r.titre || texteEquip('pirReussi', 'Piratage réussi'), '<p class="cpj-note">' + (r.dossier ? texteEquip('rapportMail', 'Rapport reçu par mail et rangé dans vos dossiers.') : texteEquip('rapportMailPlein', 'Rapport reçu par mail (dossiers pleins : non rangé).')) + '</p>' +
    informatiqueTexte(r.texte) + equipementsBouton('ouvrirPiratage()', texteEquip('retour', 'Retour')));
}

async function piratageDossier(cible, id, action) {
  const r = await informatiqueRpc('piratage_dossier_agir', { p_cible: cible, p_id: id, p_action: action });
  if (!r || r.ok !== true) { showToast(texteEquip('refuseT', 'Refusé'), informatiqueRefus(r), false); return; }
  const msg = r.action === 'detruire' ? '<p class="cpj-note">' + texteEquip('dossierDetruit', 'Dossier « {titre} » détruit.', {titre: informatiqueEch(r.titre)}) + '</p>'
    : (r.action === 'copier' ? '<p class="cpj-note">' + (r.copie ? texteEquip('copieMailRangee', 'Copie reçue par mail et rangée dans vos dossiers.') : texteEquip('copieMail', 'Copie reçue par mail.')) + '</p>' : '') + informatiqueTexte(r.contenu);
  equipementsModale(r.titre || texteEquip('dossier', 'Dossier'), msg + equipementsBouton('ouvrirPiratage()', texteEquip('retour', 'Retour')));
}

async function ouvrirDossiers() {
  const r = await informatiqueRpc('dossiers_lire', {});
  if (!r || r.ok !== true) { showToast(texteEquip('dossiers', 'Dossiers'), informatiqueRefus(r), false); return; }
  const supports = (r.supports || []).map(s => (s.generique === 'ordinateur-complet' ? texteEquip('ordinateur', 'Ordinateur') : texteEquip('stockage', 'Stockage')) + ' : ' + s.nb + ' / ' + s.capacite).join(' · ');
  const lignes = (r.dossiers || []).map(d => '<div style="display:flex;justify-content:space-between;gap:.4rem;padding:.3rem 0;border-top:1px solid #2a3340">' +
    '<span>' + informatiqueEch(d.titre) + ' <span style="color:#7a8898;font-size:.78rem">(' + (d.support === 'ordinateur' ? texteEquip('ordinateurMin', 'ordinateur') : texteEquip('stockageMin', 'stockage')) + ')</span></span><span>' +
    equipementsBouton('dossierOuvrir(\'' + d.id + '\')', texteEquip('lire', 'Lire')) + ' ' +
    equipementsBouton('dossierDeplacer(\'' + d.id + '\')', texteEquip('deplacer', 'Déplacer')) + ' ' +
    ((d.type === 'faux_document' || d.type === 'plan_3d') ? equipementsBouton('dossierImprimer(\'' + d.id + '\')', texteEquip('imprimer1', 'Imprimer (1 PA)')) + ' ' : '') +
    equipementsBouton('dossierTransmettre(\'' + d.id + '\')', texteEquip('transmettre', 'Transmettre')) + ' ' +
    equipementsBouton('dossierDetruire(\'' + d.id + '\')', texteEquip('detruire', 'Détruire')) + '</span></div>').join('');
  equipementsModale(texteEquip('mesDossiers', 'Mes dossiers'), '<p class="cpj-note">' + (supports || texteEquip('aucunSupport', 'Aucun ordinateur ni périphérique de stockage installé ici.')) +
    '<br>' + texteEquip('dossierVole', 'Un dossier rangé sur l\'ordinateur part avec lui s\'il est volé ; ceux du périphérique restent.') + '</p>' +
    (lignes || '<p class="cpj-note">' + texteEquip('aucunDossier', 'Aucun dossier.') + '</p>') + '<div style="margin-top:1rem">' + equipementsBouton('ouvrirModalEquipements()', texteEquip('retour', 'Retour')) + '</div>');
}
async function dossierOuvrir(id) {
  const r = await informatiqueRpc('dossier_ouvrir', { p_id: id });
  if (!r || r.ok !== true) { showToast(texteEquip('refuseT', 'Refusé'), informatiqueRefus(r), false); return; }
  equipementsModale(r.titre, informatiqueTexte(r.contenu) + equipementsBouton('ouvrirDossiers()', texteEquip('retour', 'Retour')));
}
async function dossierDeplacer(id) {
  const r = await informatiqueRpc('dossier_deplacer', { p_id: id });
  if (!r || r.ok !== true) { showToast(texteEquip('refuseT', 'Refusé'), informatiqueRefus(r), false); return; }
  ouvrirDossiers();
}
async function dossierDetruire(id) {
  if (!confirmerSansDialogue(texteEquip('detruireDossierQ', 'Détruire définitivement ce dossier ?'))) return;
  const r = await informatiqueRpc('dossier_detruire', { p_id: id });
  if (!r || r.ok !== true) { showToast(texteEquip('refuseT', 'Refusé'), informatiqueRefus(r), false); return; }
  ouvrirDossiers();
}
function dossierTransmettre(id) {
  equipementsModale(texteEquip('transDossier', 'Transmettre un dossier'), '<p class="cpj-note">' + texteEquip('transIntro', '1 PA. Le destinataire reçoit une copie par mail ; vous gardez l\'original.') + '</p>' +
    '<input id="dossier-dest" placeholder="' + texteEquip('nomPj', 'Nom du PJ') + '" style="width:100%;margin-bottom:.4rem">' +
    equipementsBouton('dossierTransmettreValider(\'' + id + '\')', texteEquip('transmettre', 'Transmettre'), true) + ' ' + equipementsBouton('ouvrirDossiers()', texteEquip('retour', 'Retour')));
}
async function dossierTransmettreValider(id) {
  const dest = (document.getElementById('dossier-dest')?.value || '').trim();
  if (!dest) return;
  const r = await informatiqueRpc('dossier_transferer', { p_id: id, p_destinataire: dest });
  if (!r || r.ok !== true) { showToast(texteEquip('refuseT', 'Refusé'), informatiqueRefus(r), false); return; }
  informatiquePa(r);
  showToast(texteEquip('dossierTransmis', 'Dossier transmis'), texteEquip('copieEnvoyee', 'Copie envoyée à {dest}.', {dest: dest}), true);
  ouvrirDossiers();
}
// Pas de boite de dialogue navigateur (elles bloquent certaines integrations) : double clic de confirmation.
let RP_DOSSIER_CONFIRM = 0;
function confirmerSansDialogue(message) {
  const maintenant = Date.now();
  if (maintenant - RP_DOSSIER_CONFIRM < 4000) { RP_DOSSIER_CONFIRM = 0; return true; }
  RP_DOSSIER_CONFIRM = maintenant;
  showToast(texteEquip('confirmation', 'Confirmation'), texteEquip('cliquerDeuxFois', '{message} Cliquez une seconde fois pour confirmer.', {message: message}), false);
  return false;
}

/* ---------------------------------------------------------------------------
   IMPRIMANTES, BANQUE DE PLANS 3D, VOL DE MATERIEL, MATERIEL DES ORGANISATIONS
   (decisions 12 a 15, 17 et 18). RPC : faux_document_imprimer, dossier_imprimer,
   imprimer_couteau_plastique, plans3d_lire, plan3d_obtenir, equipements_voler_lire,
   voler_materiel, equipement_ceder_organisation, organisation_materiel_lire,
   organisation_materiel_autoriser.
   --------------------------------------------------------------------------- */
Object.assign(INFORMATIQUE_REFUS, {
  pas_imprimante: 'Il faut un ordinateur et une imprimante installés dans votre bureau.',
  pas_imprimante_3d: 'Il faut un ordinateur et une imprimante 3D installés dans votre bureau.',
  pas_de_cartouche: 'Il vous faut une cartouche d\'encre (boutique d\'électronique).',
  pas_de_plastique: 'Il vous faut 1 unité de plastique (dérivés pétrochimiques).',
  dossier_non_imprimable: 'Ce dossier ne s\'imprime pas.',
  plan_invalide: 'Plan inconnu.',
  dossiers_pleins: 'Vos dossiers sont pleins.',
  fonds_insuffisants: 'Fonds insuffisants.',
  deja_a_vous: 'Ce matériel est déjà à vous.',
  local_pas_a_organisation: 'Ce local n\'est pas loué par cette organisation.',
  pas_chef: 'Seul le chef de l\'organisation le peut.',
  pas_membre: 'Cette personne n\'est pas membre.'
});
function informatiqueInventaire(r) {
  if (r && Array.isArray(r.inventory)) { state.inventory = r.inventory; if (r.revision != null) state.inventoryRevision = r.revision; }
  informatiquePa(r);
}

function ouvrirImprimantes() {
  const docs = [['fausse_identite', texteEquip('fausseIdentite', 'Fausse identité')], ['faux_permis', texteEquip('fauxPermis', 'Faux permis de construire')], ['faux_contrat', texteEquip('fauxContrat', 'Faux contrat commercial')], ['fausse_convocation', texteEquip('fausseConvoc', 'Fausse convocation')]];
  equipementsModale(texteEquip('imprimantes', 'Imprimantes'), '<div class="cpj-titre">' + texteEquip('impPapier', 'Imprimante papier — faux documents') + '</div>' +
    '<p class="cpj-note">' + texteEquip('impPapierNote', '3 PA et une cartouche d\'encre. 70 % de réussite, sans risque d\'être vu. Le modèle est rangé dans vos dossiers.') + '</p>' +
    docs.map(d => equipementsBouton('fauxImprimer(\'' + d[0] + '\')', d[1])).join(' ') +
    '<div class="cpj-titre">' + texteEquip('imp3d', 'Imprimante 3D') + '</div><p class="cpj-note">' + texteEquip('imp3dNote', '1 PA et 1 plastique par objet. Les souvenirs s\'impriment depuis un plan (vos dossiers).') + '</p>' +
    equipementsBouton('couteauImprimer()', texteEquip('couteauPlast', 'Couteau en plastique')) + ' ' + equipementsBouton('ouvrirPlans3d()', texteEquip('banquePlans', 'Banque de plans 3D')) +
    '<div style="margin-top:1rem">' + equipementsBouton('ouvrirModalEquipements()', texteEquip('retour', 'Retour')) + '</div>');
}
async function fauxImprimer(doc) {
  const r = await informatiqueRpc('faux_document_imprimer', { p_doc: doc });
  if (!r || r.ok !== true) { showToast(texteEquip('impRefusee', 'Impression refusée'), informatiqueRefus(r), false); return; }
  informatiqueInventaire(r);
  showToast(r.reussi ? texteEquip('fauxImprime', 'Faux imprimé') : texteEquip('impRatee', 'Impression ratée'), r.reussi ? texteEquip('ajouteInv', '{objet} ajouté à votre inventaire.', {objet: r.nom_document}) : texteEquip('fauxInutilisable', 'Le faux est inutilisable ; la cartouche est perdue.'), !!r.reussi);
}
async function couteauImprimer() {
  const r = await informatiqueRpc('imprimer_couteau_plastique', {});
  if (!r || r.ok !== true) { showToast(texteEquip('impRefusee', 'Impression refusée'), informatiqueRefus(r), false); return; }
  informatiqueInventaire(r);
  showToast(texteEquip('imprime', 'Imprimé'), texteEquip('couteauAjoute', 'Couteau en plastique ajouté à votre inventaire.'), true);
}
async function dossierImprimer(id) {
  const r = await informatiqueRpc('dossier_imprimer', { p_id: id });
  if (!r || r.ok !== true) { showToast(texteEquip('impRefusee', 'Impression refusée'), informatiqueRefus(r), false); return; }
  informatiqueInventaire(r);
  showToast(texteEquip('imprime', 'Imprimé'), texteEquip('ajouteInv', '{objet} ajouté à votre inventaire.', {objet: r.objet}), true);
}
async function ouvrirPlans3d() {
  const r = await informatiqueRpc('plans3d_lire', {});
  if (!r || r.ok !== true) { showToast(texteEquip('banquePlansT', 'Banque de plans'), informatiqueRefus(r), false); return; }
  const cur = (typeof COUNTRIES !== 'undefined' && COUNTRIES[state.country]?.cur) || 'FR';
  const lignes = (r.plans || []).map(p => '<div style="display:flex;justify-content:space-between;gap:.4rem;padding:.3rem 0;border-top:1px solid #2a3340"><span>' +
    informatiqueEch(p.label) + '</span><span>' + equipementsBouton('plan3dObtenir(\'' + p.id + '\',\'acheter\')', texteEquip('acheterPrix', 'Acheter {prix} {cur}', {prix: p.prix, cur: cur})) + ' ' +
    equipementsBouton('plan3dObtenir(\'' + p.id + '\',\'pirater\')', texteEquip('pirater3', 'Pirater (3 PA)')) + '</span></div>').join('');
  equipementsModale(texteEquip('banquePlans', 'Banque de plans 3D'), '<p class="cpj-note">' + texteEquip('planNote', 'Le plan est rangé dans vos dossiers ; imprimez-le depuis « Mes dossiers ».') + '</p>' + lignes +
    '<div style="margin-top:1rem">' + equipementsBouton('ouvrirImprimantes()', texteEquip('retour', 'Retour')) + '</div>');
}
async function plan3dObtenir(id, mode) {
  const r = await informatiqueRpc('plan3d_obtenir', { p_recette: id, p_mode: mode });
  if (!r || r.ok !== true) { showToast(texteEquip('refuseT', 'Refusé'), informatiqueRefus(r), false); return; }
  informatiquePa(r);
  showToast(r.reussi ? texteEquip('planObtenu', 'Plan obtenu') : texteEquip('pirRate', 'Piratage raté'), r.reussi ? texteEquip('dansDossiers', '{label} est dans vos dossiers.', {label: r.label}) : texteEquip('pa3Perdus', 'Les 3 PA sont perdus.'), !!r.reussi);
}

async function ouvrirVolMateriel() {
  const r = await informatiqueRpc('equipements_voler_lire', {});
  if (!r || r.ok !== true) { showToast(texteEquip('vol', 'Vol'), informatiqueRefus(r), false); return; }
  const lib = typeof EQUIPEMENTS_LIBELLES !== 'undefined' ? EQUIPEMENTS_LIBELLES : {};
  const lignes = (r.materiel || []).map(m => '<div style="display:flex;justify-content:space-between;padding:.3rem 0;border-top:1px solid #2a3340"><span>' +
    informatiqueEch((lib[m.generique] && texteEquip('lib.' + m.generique, lib[m.generique])) || m.generique) + '</span>' + equipementsBouton('materielVoler(\'' + m.id + '\')', texteEquip('voler3', 'Voler (3 PA)')) + '</div>').join('');
  equipementsModale(texteEquip('volerMateriel', 'Voler du matériel'), '<p class="cpj-note">' + texteEquip('volNote', '20 % de réussite, selon votre duplicité. Si vous êtes repéré : arrestation. Tout vol laisse une trace.') + '</p>' +
    (lignes || '<p class="cpj-note">' + texteEquip('rienAVoler', 'Rien à voler ici.') + '</p>'));
}
async function materielVoler(id) {
  const r = await informatiqueRpc('voler_materiel', { p_id: id });
  if (!r || r.ok !== true) { showToast(texteEquip('volImpossible', 'Vol impossible'), informatiqueRefus(r), false); return; }
  informatiqueInventaire(r);
  if (r.repere) { showToast(texteEquip('repere', 'Repéré !'), texteEquip('arreteFlagrant', 'Vous êtes arrêté en flagrant délit.'), false); if (typeof chargerPersonnage === 'function') chargerPersonnage(); return; }
  showToast(r.reussi ? texteEquip('vole', 'Volé !') : texteEquip('rate', 'Raté'), r.reussi ? texteEquip('materielInv', 'Le matériel est dans votre inventaire.') : texteEquip('pasEmporte', 'Vous n\'avez pas réussi à l\'emporter.'), !!r.reussi);
  ouvrirVolMateriel();
}

async function ouvrirMaterielOrganisation() {
  const r = await informatiqueRpc('organisation_materiel_lire', {});
  if (!r || r.ok !== true) { showToast(texteEquip('organisation', 'Organisation'), informatiqueRefus(r), false); return; }
  const h = (r.organisations || []).map(o => '<div class="cpj-titre">' + informatiqueEch(o.nom) + '</div>' +
    (o.membres || []).map(mb => '<div style="display:flex;justify-content:space-between;padding:.25rem 0"><span>' + informatiqueEch(mb.nom) + '</span>' +
      equipementsBouton('materielAutoriser(\'' + o.id + '\',\'' + informatiqueEch(mb.nom).replace(/'/g, '') + '\',' + (!mb.autorise) + ')', mb.autorise ? texteEquip('retirerAutor', 'Retirer l\'autorisation') : texteEquip('autoriser', 'Autoriser')) + '</div>').join('')).join('');
  equipementsModale(texteEquip('matOrgas', 'Matériel des organisations'), '<p class="cpj-note">' + texteEquip('matOrgasNote', 'Les membres autorisés se servent du matériel de l\'organisation (leurs PA) et reçoivent les rapports des caméras.') + '</p>' +
    (h || '<p class="cpj-note">' + texteEquip('aucuneOrga', 'Vous ne dirigez aucune organisation.') + '</p>') + '<div style="margin-top:1rem">' + equipementsBouton('ouvrirModalEquipements()', texteEquip('retour', 'Retour')) + '</div>');
}
async function materielAutoriser(orga, membre, autorise) {
  const r = await informatiqueRpc('organisation_materiel_autoriser', { p_organisation: orga, p_membre: membre, p_autorise: autorise });
  if (!r || r.ok !== true) { showToast(texteEquip('refuseT', 'Refusé'), informatiqueRefus(r), false); return; }
  ouvrirMaterielOrganisation();
}
// Choix de l'organisation qui recoit le materiel (chef seulement ; le local doit etre loue par elle).
async function materielCederChoisir(id) {
  const r = await informatiqueRpc('organisation_materiel_lire', {});
  if (!r || r.ok !== true) { showToast(texteEquip('refuseT', 'Refusé'), informatiqueRefus(r), false); return; }
  const orgs = r.organisations || [];
  const h = orgs.map(o => '<div style="display:flex;justify-content:space-between;align-items:center;padding:.3rem 0;border-top:1px solid #2a3340"><span>' +
    informatiqueEch(o.nom || o.id) + '</span>' + equipementsBouton('materielCeder(\'' + String(id).replace(/'/g, '') + '\',\'' + informatiqueEch(o.id).replace(/'/g, '') + '\')', texteEquip('ceder', 'Céder'), true) + '</div>').join('');
  equipementsModale(texteEquip('cederOrga', 'Céder à l\'organisation'), '<p class="cpj-note">' + texteEquip('cederNote', 'Le matériel appartiendra à l\'organisation : vous ne pourrez plus le désinstaller vous-même. Le local doit être loué par elle.') + '</p>' +
    (h || '<p class="cpj-note">' + texteEquip('aucuneOrga', 'Vous ne dirigez aucune organisation.') + '</p>') + '<div style="margin-top:1rem">' + equipementsBouton('ouvrirModalEquipements()', texteEquip('retour', 'Retour')) + '</div>');
}
async function materielCeder(id, orga) {
  const r = await informatiqueRpc('equipement_ceder_organisation', { p_id: id, p_organisation: orga });
  if (!r || r.ok !== true) { showToast(texteEquip('refuseT', 'Refusé'), informatiqueRefus(r), false); return; }
  showToast(texteEquip('matCede', 'Matériel cédé'), texteEquip('appartientOrga', 'Il appartient désormais à l\'organisation.'), true);
  ouvrirModalEquipements();
}
