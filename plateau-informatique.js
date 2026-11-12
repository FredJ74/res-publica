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

function informatiqueTr(fr){const fn=window.RPComputerFilesI18n?.text;return typeof fn==='function'?fn(fr):fr;}
function informatiqueBouton(onclick,libelle,primaire){
 const source=String(libelle);
 const html=equipementsBouton(onclick,informatiqueTr(source),primaire);
 return html.replace('<button ','<button data-info-text="'+encodeURIComponent(source)+'" ');
}
function informatiqueModal(titre,html){
 equipementsModale(informatiqueTr(titre),html);
 const node=document.getElementById('postes-modal-title');
 if(node)node.setAttribute('data-info-title',encodeURIComponent(titre));
}
function informatiqueToast(titre,message,ok){
 showToast(informatiqueTr(titre),informatiqueTr(message),ok);
}
function informatiqueTitre(texte){
 return '<div class="cpj-titre" data-info-heading="'+encodeURIComponent(texte)+'">'+informatiqueEch(informatiqueTr(texte))+'</div>';
}
function informatiquePlaceholder(texte){
 return '" data-info-placeholder="'+encodeURIComponent(texte)+'"';
}
(window.RP_I18N_CHANGE_CALLBACKS=window.RP_I18N_CHANGE_CALLBACKS||[]).push(function(){
 const modal=document.getElementById('modal-postes');
 if(!modal?.classList?.contains('open'))return;
 const body=document.getElementById('postes-body');
 if(!body?.querySelector?.('[data-info-text]'))return;
 const titre=document.getElementById('postes-modal-title');
 if(titre?.getAttribute('data-info-title'))titre.textContent=informatiqueTr(decodeURIComponent(titre.getAttribute('data-info-title')));
 for(const b of body.querySelectorAll('[data-info-text]'))b.textContent=informatiqueTr(decodeURIComponent(b.getAttribute('data-info-text')||''));
 for(const h of body.querySelectorAll('[data-info-heading]'))h.textContent=informatiqueTr(decodeURIComponent(h.getAttribute('data-info-heading')||''));
 for(const input of body.querySelectorAll('[data-info-placeholder]'))input.placeholder=informatiqueTr(decodeURIComponent(input.getAttribute('data-info-placeholder')||''));
});
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
  const message=r&&INFORMATIQUE_REFUS[r.raison];
  return message?informatiqueTr(message):(typeof equipementsRefus==='function'?equipementsRefus(r):informatiqueTr('Refusé.'));
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
  const h = '<p class="cpj-note">3 PA par tentative. Réussite de base 45 %, selon votre intelligence. Un intranet protège presque toujours un ordinateur. ' +
    'Tout piratage laisse une trace ; un échec peut alerter la cible.</p>' +
    informatiqueTitre("Comptes en banque") +
    '<input id="pirate-banque" placeholder="Nom d\'un PJ ou d\'une organisation" style="width:100%;margin-bottom:.4rem"> ' +
    informatiqueBouton('piraterLancer(\'banque\')', 'Pirater la banque', true) +
    informatiqueTitre("Registres de votre ville") +
    informatiqueBouton('piraterLancer(\'registre\',\'armes\')', 'Ventes d\'armes') + ' ' +
    informatiqueBouton('piraterLancer(\'registre\',\'plaintes\')', 'Plaintes') + ' ' +
    informatiqueBouton('piraterLancer(\'registre\',\'carceral\')', 'Registre carcéral') +
    (sov ? ' ' + informatiqueBouton('piraterLancer(\'registre\',\'signalements\')', 'Signalements') : '') +
    informatiqueTitre("Casernes") + informatiqueBouton('piraterLancer(\'caserne\',\'\')', 'Pirater les casernes') +
    informatiqueTitre("Ordinateur d'un PJ") +
    '<input id="pirate-ordi" placeholder="Nom du PJ" style="width:100%;margin-bottom:.4rem"> ' +
    informatiqueBouton('piraterLancer(\'ordinateur\')', 'Pirater son ordinateur') +
    '<div style="margin-top:1rem">' + informatiqueBouton('ouvrirModalEquipements()', 'Retour') + '</div>';
  informatiqueModal('Piratage', h);
}

async function piraterLancer(cible, parametre) {
  if (cible === 'banque') parametre = (document.getElementById('pirate-banque')?.value || '').trim();
  if (cible === 'ordinateur') parametre = (document.getElementById('pirate-ordi')?.value || '').trim();
  if ((cible === 'banque' || cible === 'ordinateur') && !parametre) { informatiqueToast('Piratage', 'Indiquez une cible.', false); return; }
  const r = await informatiqueRpc('pirater', { p_cible: cible, p_parametre: parametre || '', p_ville: null });
  if (!r || r.ok !== true) { informatiqueToast('Piratage impossible', informatiqueRefus(r), false); return; }
  informatiquePa(r);
  if (!r.reussi) {
    informatiqueModal('Piratage', '<p class="cpj-note">Échec (jet ' + r.jet + ' pour ' + r.taux + ' %' + (r.intranet ? ', intranet' : '') + '). ' +
      'Les 3 PA sont perdus ; la cible a peut-être été alertée.</p>' + informatiqueBouton('ouvrirPiratage()', 'Retour'));
    return;
  }
  if (cible === 'ordinateur') {
    const lignes = (r.dossiers || []).map(d => '<div style="display:flex;justify-content:space-between;gap:.4rem;padding:.3rem 0;border-top:1px solid #2a3340">' +
      '<span>' + informatiqueEch(d.titre) + '</span><span>' +
      informatiqueBouton('piratageDossier(\'' + informatiqueEch(r.cible) + '\',\'' + d.id + '\',\'lire\')', 'Lire') + ' ' +
      informatiqueBouton('piratageDossier(\'' + informatiqueEch(r.cible) + '\',\'' + d.id + '\',\'copier\')', 'Copier') + ' ' +
      informatiqueBouton('piratageDossier(\'' + informatiqueEch(r.cible) + '\',\'' + d.id + '\',\'detruire\')', 'Détruire') + '</span></div>').join('');
    informatiqueModal('Piratage réussi', '<p class="cpj-note">Vous êtes dans l\'ordinateur de ' + informatiqueEch(r.cible) +
      '. Une seule action possible sur un seul dossier.</p>' + (lignes || '<p class="cpj-note">Aucun dossier.</p>') +
      '<div style="margin-top:1rem">' + informatiqueBouton('ouvrirPiratage()', 'Retour') + '</div>');
    return;
  }
  informatiqueModal(r.titre || 'Piratage réussi', '<p class="cpj-note">Rapport reçu par mail' + (r.dossier ? ' et rangé dans vos dossiers' : ' (dossiers pleins : non rangé)') + '.</p>' +
    informatiqueTexte(r.texte) + informatiqueBouton('ouvrirPiratage()', 'Retour'));
}

async function piratageDossier(cible, id, action) {
  const r = await informatiqueRpc('piratage_dossier_agir', { p_cible: cible, p_id: id, p_action: action });
  if (!r || r.ok !== true) { informatiqueToast('Refusé', informatiqueRefus(r), false); return; }
  const msg = r.action === 'detruire' ? '<p class="cpj-note">Dossier « ' + informatiqueEch(r.titre) + ' » détruit.</p>'
    : (r.action === 'copier' ? '<p class="cpj-note">Copie reçue par mail' + (r.copie ? ' et rangée dans vos dossiers' : '') + '.</p>' : '') + informatiqueTexte(r.contenu);
  informatiqueModal(r.titre || 'Dossier', msg + informatiqueBouton('ouvrirPiratage()', 'Retour'));
}

async function ouvrirDossiers() {
  const r = await informatiqueRpc('dossiers_lire', {});
  if (!r || r.ok !== true) { informatiqueToast('Dossiers', informatiqueRefus(r), false); return; }
  const supports = (r.supports || []).map(s => (s.generique === 'ordinateur-complet' ? 'Ordinateur' : 'Stockage') + ' : ' + s.nb + ' / ' + s.capacite).join(' · ');
  const lignes = (r.dossiers || []).map(d => '<div style="display:flex;justify-content:space-between;gap:.4rem;padding:.3rem 0;border-top:1px solid #2a3340">' +
    '<span>' + informatiqueEch(d.titre) + ' <span style="color:#7a8898;font-size:.78rem">(' + (d.support === 'ordinateur' ? 'ordinateur' : 'stockage') + ')</span></span><span>' +
    informatiqueBouton('dossierOuvrir(\'' + d.id + '\')', 'Lire') + ' ' +
    informatiqueBouton('dossierDeplacer(\'' + d.id + '\')', 'Déplacer') + ' ' +
    ((d.type === 'faux_document' || d.type === 'plan_3d') ? informatiqueBouton('dossierImprimer(\'' + d.id + '\')', 'Imprimer (1 PA)') + ' ' : '') +
    informatiqueBouton('dossierTransmettre(\'' + d.id + '\')', 'Transmettre') + ' ' +
    informatiqueBouton('dossierDetruire(\'' + d.id + '\')', 'Détruire') + '</span></div>').join('');
  informatiqueModal('Mes dossiers', '<p class="cpj-note">' + (supports || 'Aucun ordinateur ni périphérique de stockage installé ici.') +
    '<br>Un dossier rangé sur l\'ordinateur part avec lui s\'il est volé ; ceux du périphérique restent.</p>' +
    (lignes || '<p class="cpj-note">Aucun dossier.</p>') + '<div style="margin-top:1rem">' + informatiqueBouton('ouvrirModalEquipements()', 'Retour') + '</div>');
}
async function dossierOuvrir(id) {
  const r = await informatiqueRpc('dossier_ouvrir', { p_id: id });
  if (!r || r.ok !== true) { informatiqueToast('Refusé', informatiqueRefus(r), false); return; }
  informatiqueModal(r.titre, informatiqueTexte(r.contenu) + informatiqueBouton('ouvrirDossiers()', 'Retour'));
}
async function dossierDeplacer(id) {
  const r = await informatiqueRpc('dossier_deplacer', { p_id: id });
  if (!r || r.ok !== true) { informatiqueToast('Refusé', informatiqueRefus(r), false); return; }
  ouvrirDossiers();
}
async function dossierDetruire(id) {
  if (!confirmerSansDialogue('Détruire définitivement ce dossier ?')) return;
  const r = await informatiqueRpc('dossier_detruire', { p_id: id });
  if (!r || r.ok !== true) { informatiqueToast('Refusé', informatiqueRefus(r), false); return; }
  ouvrirDossiers();
}
function dossierTransmettre(id) {
  informatiqueModal('Transmettre un dossier', '<p class="cpj-note">1 PA. Le destinataire reçoit une copie par mail ; vous gardez l\'original.</p>' +
    '<input id="dossier-dest" placeholder="Nom du PJ" style="width:100%;margin-bottom:.4rem">' +
    informatiqueBouton('dossierTransmettreValider(\'' + id + '\')', 'Transmettre', true) + ' ' + informatiqueBouton('ouvrirDossiers()', 'Retour'));
}
async function dossierTransmettreValider(id) {
  const dest = (document.getElementById('dossier-dest')?.value || '').trim();
  if (!dest) return;
  const r = await informatiqueRpc('dossier_transferer', { p_id: id, p_destinataire: dest });
  if (!r || r.ok !== true) { informatiqueToast('Refusé', informatiqueRefus(r), false); return; }
  informatiquePa(r);
  informatiqueToast('Dossier transmis', 'Copie envoyée à ' + dest + '.', true);
  ouvrirDossiers();
}
// Pas de boite de dialogue navigateur (elles bloquent certaines integrations) : double clic de confirmation.
let RP_DOSSIER_CONFIRM = 0;
function confirmerSansDialogue(message) {
  const maintenant = Date.now();
  if (maintenant - RP_DOSSIER_CONFIRM < 4000) { RP_DOSSIER_CONFIRM = 0; return true; }
  RP_DOSSIER_CONFIRM = maintenant;
  informatiqueToast('Confirmation', message + ' Cliquez une seconde fois pour confirmer.', false);
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
  const docs = [['fausse_identite', 'Fausse identité'], ['faux_permis', 'Faux permis de construire'], ['faux_contrat', 'Faux contrat commercial'], ['fausse_convocation', 'Fausse convocation']];
  informatiqueModal('Imprimantes', '<div class="cpj-titre">Imprimante papier — faux documents</div>' +
    '<p class="cpj-note">3 PA et une cartouche d\'encre. 70 % de réussite, sans risque d\'être vu. Le modèle est rangé dans vos dossiers.</p>' +
    docs.map(d => informatiqueBouton('fauxImprimer(\'' + d[0] + '\')', d[1])).join(' ') +
    '<div class="cpj-titre">Imprimante 3D</div><p class="cpj-note">1 PA et 1 plastique par objet. Les souvenirs s\'impriment depuis un plan (vos dossiers).</p>' +
    informatiqueBouton('couteauImprimer()', 'Couteau en plastique') + ' ' + informatiqueBouton('ouvrirPlans3d()', 'Banque de plans 3D') +
    '<div style="margin-top:1rem">' + informatiqueBouton('ouvrirModalEquipements()', 'Retour') + '</div>');
}
async function fauxImprimer(doc) {
  const r = await informatiqueRpc('faux_document_imprimer', { p_doc: doc });
  if (!r || r.ok !== true) { informatiqueToast('Impression refusée', informatiqueRefus(r), false); return; }
  informatiqueInventaire(r);
  informatiqueToast(r.reussi ? 'Faux imprimé' : 'Impression ratée', r.reussi ? (r.nom_document + ' ajouté à votre inventaire.') : 'Le faux est inutilisable ; la cartouche est perdue.', !!r.reussi);
}
async function couteauImprimer() {
  const r = await informatiqueRpc('imprimer_couteau_plastique', {});
  if (!r || r.ok !== true) { informatiqueToast('Impression refusée', informatiqueRefus(r), false); return; }
  informatiqueInventaire(r);
  informatiqueToast('Imprimé', 'Couteau en plastique ajouté à votre inventaire.', true);
}
async function dossierImprimer(id) {
  const r = await informatiqueRpc('dossier_imprimer', { p_id: id });
  if (!r || r.ok !== true) { informatiqueToast('Impression refusée', informatiqueRefus(r), false); return; }
  informatiqueInventaire(r);
  informatiqueToast('Imprimé', r.objet + ' ajouté à votre inventaire.', true);
}
async function ouvrirPlans3d() {
  const r = await informatiqueRpc('plans3d_lire', {});
  if (!r || r.ok !== true) { informatiqueToast('Banque de plans', informatiqueRefus(r), false); return; }
  const cur = (typeof COUNTRIES !== 'undefined' && COUNTRIES[state.country]?.cur) || 'FR';
  const lignes = (r.plans || []).map(p => '<div style="display:flex;justify-content:space-between;gap:.4rem;padding:.3rem 0;border-top:1px solid #2a3340"><span>' +
    informatiqueEch(p.label) + '</span><span>' + informatiqueBouton('plan3dObtenir(\'' + p.id + '\',\'acheter\')', 'Acheter ' + p.prix + ' ' + cur) + ' ' +
    informatiqueBouton('plan3dObtenir(\'' + p.id + '\',\'pirater\')', 'Pirater (3 PA)') + '</span></div>').join('');
  informatiqueModal('Banque de plans 3D', '<p class="cpj-note">Le plan est rangé dans vos dossiers ; imprimez-le depuis « Mes dossiers ».</p>' + lignes +
    '<div style="margin-top:1rem">' + informatiqueBouton('ouvrirImprimantes()', 'Retour') + '</div>');
}
async function plan3dObtenir(id, mode) {
  const r = await informatiqueRpc('plan3d_obtenir', { p_recette: id, p_mode: mode });
  if (!r || r.ok !== true) { informatiqueToast('Refusé', informatiqueRefus(r), false); return; }
  informatiquePa(r);
  informatiqueToast(r.reussi ? 'Plan obtenu' : 'Piratage raté', r.reussi ? (r.label + ' est dans vos dossiers.') : 'Les 3 PA sont perdus.', !!r.reussi);
}

async function ouvrirVolMateriel() {
  const r = await informatiqueRpc('equipements_voler_lire', {});
  if (!r || r.ok !== true) { informatiqueToast('Vol', informatiqueRefus(r), false); return; }
  const lib = typeof EQUIPEMENTS_LIBELLES !== 'undefined' ? EQUIPEMENTS_LIBELLES : {};
  const lignes = (r.materiel || []).map(m => '<div style="display:flex;justify-content:space-between;padding:.3rem 0;border-top:1px solid #2a3340"><span>' +
    informatiqueEch(lib[m.generique] || m.generique) + '</span>' + informatiqueBouton('materielVoler(\'' + m.id + '\')', 'Voler (3 PA)') + '</div>').join('');
  informatiqueModal('Voler du matériel', '<p class="cpj-note">20 % de réussite, selon votre duplicité. Si vous êtes repéré : arrestation. Tout vol laisse une trace.</p>' +
    (lignes || '<p class="cpj-note">Rien à voler ici.</p>'));
}
async function materielVoler(id) {
  const r = await informatiqueRpc('voler_materiel', { p_id: id });
  if (!r || r.ok !== true) { informatiqueToast('Vol impossible', informatiqueRefus(r), false); return; }
  informatiqueInventaire(r);
  if (r.repere) { informatiqueToast('Repéré !', 'Vous êtes arrêté en flagrant délit.', false); if (typeof chargerPersonnage === 'function') chargerPersonnage(); return; }
  informatiqueToast(r.reussi ? 'Volé !' : 'Raté', r.reussi ? 'Le matériel est dans votre inventaire.' : 'Vous n\'avez pas réussi à l\'emporter.', !!r.reussi);
  ouvrirVolMateriel();
}

async function ouvrirMaterielOrganisation() {
  const r = await informatiqueRpc('organisation_materiel_lire', {});
  if (!r || r.ok !== true) { informatiqueToast('Organisation', informatiqueRefus(r), false); return; }
  const h = (r.organisations || []).map(o => '<div class="cpj-titre">' + informatiqueEch(o.nom) + '</div>' +
    (o.membres || []).map(mb => '<div style="display:flex;justify-content:space-between;padding:.25rem 0"><span>' + informatiqueEch(mb.nom) + '</span>' +
      informatiqueBouton('materielAutoriser(\'' + o.id + '\',\'' + informatiqueEch(mb.nom).replace(/'/g, '') + '\',' + (!mb.autorise) + ')', mb.autorise ? 'Retirer l\'autorisation' : 'Autoriser') + '</div>').join('')).join('');
  informatiqueModal('Matériel des organisations', '<p class="cpj-note">Les membres autorisés se servent du matériel de l\'organisation (leurs PA) et reçoivent les rapports des caméras.</p>' +
    (h || '<p class="cpj-note">Vous ne dirigez aucune organisation.</p>') + '<div style="margin-top:1rem">' + informatiqueBouton('ouvrirModalEquipements()', 'Retour') + '</div>');
}
async function materielAutoriser(orga, membre, autorise) {
  const r = await informatiqueRpc('organisation_materiel_autoriser', { p_organisation: orga, p_membre: membre, p_autorise: autorise });
  if (!r || r.ok !== true) { informatiqueToast('Refusé', informatiqueRefus(r), false); return; }
  ouvrirMaterielOrganisation();
}
// Choix de l'organisation qui recoit le materiel (chef seulement ; le local doit etre loue par elle).
async function materielCederChoisir(id) {
  const r = await informatiqueRpc('organisation_materiel_lire', {});
  if (!r || r.ok !== true) { informatiqueToast('Refusé', informatiqueRefus(r), false); return; }
  const orgs = r.organisations || [];
  const h = orgs.map(o => '<div style="display:flex;justify-content:space-between;align-items:center;padding:.3rem 0;border-top:1px solid #2a3340"><span>' +
    informatiqueEch(o.nom || o.id) + '</span>' + informatiqueBouton('materielCeder(\'' + String(id).replace(/'/g, '') + '\',\'' + informatiqueEch(o.id).replace(/'/g, '') + '\')', 'Céder', true) + '</div>').join('');
  informatiqueModal('Céder à l\'organisation', '<p class="cpj-note">Le matériel appartiendra à l\'organisation : vous ne pourrez plus le désinstaller vous-même. Le local doit être loué par elle.</p>' +
    (h || '<p class="cpj-note">Vous ne dirigez aucune organisation.</p>') + '<div style="margin-top:1rem">' + informatiqueBouton('ouvrirModalEquipements()', 'Retour') + '</div>');
}
async function materielCeder(id, orga) {
  const r = await informatiqueRpc('equipement_ceder_organisation', { p_id: id, p_organisation: orga });
  if (!r || r.ok !== true) { informatiqueToast('Refusé', informatiqueRefus(r), false); return; }
  informatiqueToast('Matériel cédé', 'Il appartient désormais à l\'organisation.', true);
  ouvrirModalEquipements();
}
