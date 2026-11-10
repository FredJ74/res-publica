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
  return (r && INFORMATIQUE_REFUS[r.raison]) || (typeof equipementsRefus === 'function' ? equipementsRefus(r) : 'Refusé.');
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
    '<div class="cpj-titre">Comptes en banque</div>' +
    '<input id="pirate-banque" placeholder="Nom d\'un PJ ou d\'une organisation" style="width:100%;margin-bottom:.4rem"> ' +
    equipementsBouton('piraterLancer(\'banque\')', 'Pirater la banque', true) +
    '<div class="cpj-titre">Registres de votre ville</div>' +
    equipementsBouton('piraterLancer(\'registre\',\'armes\')', 'Ventes d\'armes') + ' ' +
    equipementsBouton('piraterLancer(\'registre\',\'plaintes\')', 'Plaintes') + ' ' +
    equipementsBouton('piraterLancer(\'registre\',\'carceral\')', 'Registre carcéral') +
    (sov ? ' ' + equipementsBouton('piraterLancer(\'registre\',\'signalements\')', 'Signalements') : '') +
    '<div class="cpj-titre">Casernes</div>' + equipementsBouton('piraterLancer(\'caserne\',\'\')', 'Pirater les casernes') +
    '<div class="cpj-titre">Ordinateur d\'un PJ</div>' +
    '<input id="pirate-ordi" placeholder="Nom du PJ" style="width:100%;margin-bottom:.4rem"> ' +
    equipementsBouton('piraterLancer(\'ordinateur\')', 'Pirater son ordinateur') +
    '<div style="margin-top:1rem">' + equipementsBouton('ouvrirModalEquipements()', 'Retour') + '</div>';
  equipementsModale('Piratage', h);
}

async function piraterLancer(cible, parametre) {
  if (cible === 'banque') parametre = (document.getElementById('pirate-banque')?.value || '').trim();
  if (cible === 'ordinateur') parametre = (document.getElementById('pirate-ordi')?.value || '').trim();
  if ((cible === 'banque' || cible === 'ordinateur') && !parametre) { showToast('Piratage', 'Indiquez une cible.', false); return; }
  const r = await informatiqueRpc('pirater', { p_cible: cible, p_parametre: parametre || '', p_ville: null });
  if (!r || r.ok !== true) { showToast('Piratage impossible', informatiqueRefus(r), false); return; }
  informatiquePa(r);
  if (!r.reussi) {
    equipementsModale('Piratage', '<p class="cpj-note">Échec (jet ' + r.jet + ' pour ' + r.taux + ' %' + (r.intranet ? ', intranet' : '') + '). ' +
      'Les 3 PA sont perdus ; la cible a peut-être été alertée.</p>' + equipementsBouton('ouvrirPiratage()', 'Retour'));
    return;
  }
  if (cible === 'ordinateur') {
    const lignes = (r.dossiers || []).map(d => '<div style="display:flex;justify-content:space-between;gap:.4rem;padding:.3rem 0;border-top:1px solid #2a3340">' +
      '<span>' + informatiqueEch(d.titre) + '</span><span>' +
      equipementsBouton('piratageDossier(\'' + informatiqueEch(r.cible) + '\',\'' + d.id + '\',\'lire\')', 'Lire') + ' ' +
      equipementsBouton('piratageDossier(\'' + informatiqueEch(r.cible) + '\',\'' + d.id + '\',\'copier\')', 'Copier') + ' ' +
      equipementsBouton('piratageDossier(\'' + informatiqueEch(r.cible) + '\',\'' + d.id + '\',\'detruire\')', 'Détruire') + '</span></div>').join('');
    equipementsModale('Piratage réussi', '<p class="cpj-note">Vous êtes dans l\'ordinateur de ' + informatiqueEch(r.cible) +
      '. Une seule action possible sur un seul dossier.</p>' + (lignes || '<p class="cpj-note">Aucun dossier.</p>') +
      '<div style="margin-top:1rem">' + equipementsBouton('ouvrirPiratage()', 'Retour') + '</div>');
    return;
  }
  equipementsModale(r.titre || 'Piratage réussi', '<p class="cpj-note">Rapport reçu par mail' + (r.dossier ? ' et rangé dans vos dossiers' : ' (dossiers pleins : non rangé)') + '.</p>' +
    informatiqueTexte(r.texte) + equipementsBouton('ouvrirPiratage()', 'Retour'));
}

async function piratageDossier(cible, id, action) {
  const r = await informatiqueRpc('piratage_dossier_agir', { p_cible: cible, p_id: id, p_action: action });
  if (!r || r.ok !== true) { showToast('Refusé', informatiqueRefus(r), false); return; }
  const msg = r.action === 'detruire' ? '<p class="cpj-note">Dossier « ' + informatiqueEch(r.titre) + ' » détruit.</p>'
    : (r.action === 'copier' ? '<p class="cpj-note">Copie reçue par mail' + (r.copie ? ' et rangée dans vos dossiers' : '') + '.</p>' : '') + informatiqueTexte(r.contenu);
  equipementsModale(r.titre || 'Dossier', msg + equipementsBouton('ouvrirPiratage()', 'Retour'));
}

async function ouvrirDossiers() {
  const r = await informatiqueRpc('dossiers_lire', {});
  if (!r || r.ok !== true) { showToast('Dossiers', informatiqueRefus(r), false); return; }
  const supports = (r.supports || []).map(s => (s.generique === 'ordinateur-complet' ? 'Ordinateur' : 'Stockage') + ' : ' + s.nb + ' / ' + s.capacite).join(' · ');
  const lignes = (r.dossiers || []).map(d => '<div style="display:flex;justify-content:space-between;gap:.4rem;padding:.3rem 0;border-top:1px solid #2a3340">' +
    '<span>' + informatiqueEch(d.titre) + ' <span style="color:#7a8898;font-size:.78rem">(' + (d.support === 'ordinateur' ? 'ordinateur' : 'stockage') + ')</span></span><span>' +
    equipementsBouton('dossierOuvrir(\'' + d.id + '\')', 'Lire') + ' ' +
    equipementsBouton('dossierDeplacer(\'' + d.id + '\')', 'Déplacer') + ' ' +
    equipementsBouton('dossierTransmettre(\'' + d.id + '\')', 'Transmettre') + ' ' +
    equipementsBouton('dossierDetruire(\'' + d.id + '\')', 'Détruire') + '</span></div>').join('');
  equipementsModale('Mes dossiers', '<p class="cpj-note">' + (supports || 'Aucun ordinateur ni périphérique de stockage installé ici.') +
    '<br>Un dossier rangé sur l\'ordinateur part avec lui s\'il est volé ; ceux du périphérique restent.</p>' +
    (lignes || '<p class="cpj-note">Aucun dossier.</p>') + '<div style="margin-top:1rem">' + equipementsBouton('ouvrirModalEquipements()', 'Retour') + '</div>');
}
async function dossierOuvrir(id) {
  const r = await informatiqueRpc('dossier_ouvrir', { p_id: id });
  if (!r || r.ok !== true) { showToast('Refusé', informatiqueRefus(r), false); return; }
  equipementsModale(r.titre, informatiqueTexte(r.contenu) + equipementsBouton('ouvrirDossiers()', 'Retour'));
}
async function dossierDeplacer(id) {
  const r = await informatiqueRpc('dossier_deplacer', { p_id: id });
  if (!r || r.ok !== true) { showToast('Refusé', informatiqueRefus(r), false); return; }
  ouvrirDossiers();
}
async function dossierDetruire(id) {
  if (!confirmerSansDialogue('Détruire définitivement ce dossier ?')) return;
  const r = await informatiqueRpc('dossier_detruire', { p_id: id });
  if (!r || r.ok !== true) { showToast('Refusé', informatiqueRefus(r), false); return; }
  ouvrirDossiers();
}
function dossierTransmettre(id) {
  equipementsModale('Transmettre un dossier', '<p class="cpj-note">1 PA. Le destinataire reçoit une copie par mail ; vous gardez l\'original.</p>' +
    '<input id="dossier-dest" placeholder="Nom du PJ" style="width:100%;margin-bottom:.4rem">' +
    equipementsBouton('dossierTransmettreValider(\'' + id + '\')', 'Transmettre', true) + ' ' + equipementsBouton('ouvrirDossiers()', 'Retour'));
}
async function dossierTransmettreValider(id) {
  const dest = (document.getElementById('dossier-dest')?.value || '').trim();
  if (!dest) return;
  const r = await informatiqueRpc('dossier_transferer', { p_id: id, p_destinataire: dest });
  if (!r || r.ok !== true) { showToast('Refusé', informatiqueRefus(r), false); return; }
  informatiquePa(r);
  showToast('Dossier transmis', 'Copie envoyée à ' + dest + '.', true);
  ouvrirDossiers();
}
// Pas de boite de dialogue navigateur (elles bloquent certaines integrations) : double clic de confirmation.
let RP_DOSSIER_CONFIRM = 0;
function confirmerSansDialogue(message) {
  const maintenant = Date.now();
  if (maintenant - RP_DOSSIER_CONFIRM < 4000) { RP_DOSSIER_CONFIRM = 0; return true; }
  RP_DOSSIER_CONFIRM = maintenant;
  showToast('Confirmation', message + ' Cliquez une seconde fois pour confirmer.', false);
  return false;
}
