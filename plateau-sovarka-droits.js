// SOVARKA : DROITS D'EXPLOITER (decisions de Fred du 06/11/2026, GAME-DESIGN-NOVOMIRSK.md).
// L'Etat possede tout ; un PJ obtient un droit d'exploiter : demande a la mairie, acceptation du maire
// (a defaut l'adjoint, a defaut le ministre de l'Economie collective), signature chez le notaire.
// Cession entre PJ enregistree par le notaire, retour a l'Etat au deces ou par decision du juge.
// Tout est decide par les fonctions serveur sovarka_* ; l'ecran n'affiche que leurs reponses.

const SOV_MOTIFS = {
  pas_a_la_mairie: 'Présentez-vous à la mairie.',
  pas_chez_le_notaire: 'Présentez-vous chez le notaire de Novomirsk.',
  pas_au_tribunal: 'Présentez-vous au tribunal de la ville.',
  pas_dans_le_local: 'Rendez-vous dans le local que vous demandez.',
  demande_deja_en_cours: 'Vous avez déjà une demande en cours dans cette ville.',
  projet_invalide: 'Décrivez votre projet en quelques mots (3 à 200 caractères).',
  reserve_autorite_municipale: 'Réservé au maire, à défaut à son adjoint, à défaut au ministre de l’Économie collective.',
  reserve_juge: 'Réservé au juge de la ville.',
  demande_introuvable: 'Ce dossier n’est plus en attente.',
  local_introuvable: 'Local introuvable.',
  local_non_libre: 'Ce local n’est plus libre.',
  loyer_invalide: 'Loyer hors des limites de ce local.',
  commerce_sans_loyer: 'Ce commerce n’a pas de loyer.',
  aucune_attribution: 'Aucune attribution à signer.',
  pas_exploitant: 'Vous n’exploitez pas ce commerce.',
  repreneur_introuvable: 'Repreneur introuvable.',
  cession_deja_en_cours: 'Une cession est déjà en cours pour ce commerce.',
  cession_introuvable: 'Cette cession n’est plus en cours.',
  reserve_repreneur: 'Seul le repreneur peut accepter.',
  cedant_plus_exploitant: 'Le cédant n’exploite plus ce commerce : cession annulée.',
  motif_invalide: 'Indiquez un motif (3 à 300 caractères).',
  saisine_requise: 'Le juge ne retire un droit que sur saisine du ministre de la Justice prolétarienne.',
  local_non_exploite: 'Ce commerce n’est exploité par personne.',
  pa_insuffisants: 'Pas assez de points d’action.'
};
const sovMotif = v => SOV_MOTIFS[v?.raison] || (v?.transport ? 'Réponse du serveur non reçue.' : 'Refusé par le serveur.');
const sovEsc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const sovJs = s => String(s == null ? '' : s).replace(/\\/g, '\\\\').replace(/'/g, "\\'");
const sovVille = v => (typeof VILLES !== 'undefined' && VILLES.soviet?.[v]?.nom) || v;
const sovSection = (titre, corps) => (typeof vehSection === 'function') ? vehSection(titre, corps)
  : '<section><strong>' + titre + '</strong>' + corps + '</section>';
const sovBouton = (libelle, js, primaire) =>
  '<button class="cpj-touche' + (primaire ? ' cpj-primaire' : '') + '" style="margin:.4rem .4rem 0 0" onclick="' + js + '">' + libelle + '</button>';
const SOV_STATUTS = { en_attente: 'en attente d’examen', acceptee: 'acceptée, en attente d’un local', attribuee: 'local attribué, à signer chez le notaire' };
const SOV_IMMEUBLES = { en_attente_fonds: 'en attente des fonds de la mairie', en_chantier: 'en chantier', livre: 'livré' };

let sovarkaDroitsCache = null;
let sovarkaActeEnCours = false;

async function sovLire() {
  const l = await sbRpcVerdict('sovarka_droits_lire', {}).catch(() => null);
  if (!l || l.ok !== true) return null;
  sovarkaDroitsCache = l;
  return l;
}

async function sovActe(fn, params, titre, succes, rouvrir) {
  if (sovarkaActeEnCours) return;
  sovarkaActeEnCours = true;
  try {
    const v = await sbRpcVerdict(fn, params).catch(() => null);
    if (!v || v.ok !== true) { showToast(titre, sovMotif(v), false); return; }
    if (typeof appliquerPaiementServeur === 'function') appliquerPaiementServeur(v);
    if (typeof updateHeader === 'function') updateHeader();
    showToast(titre, typeof succes === 'function' ? succes(v) : succes, true);
    await sovLire();
    if (typeof rafraichirPiecesDynamiques === 'function' && state.currentBuilding) rafraichirPiecesDynamiques(state.currentBuilding);
    if (typeof rouvrir === 'function') rouvrir();
  } finally { sovarkaActeEnCours = false; }
}

const sovLibre = l => !l.exploitant && !l.reserve;
const sovLoyer = l => l.origine === 'pnj' ? 'sans loyer' : l.loyer + ' PSK / jour';

// ----------------------------------------------------------------------------- Notaire
async function ouvrirSovarkaCommercesLibres() {
  const l = await sovLire();
  if (!l) { showToast('Commerces', 'Lecture impossible auprès du serveur.', false); return; }
  let html = '<p class="cpj-note">L’État possède tout. Un commerce s’obtient par une demande à la mairie de la ville ; ' +
    'le maire l’attribue, puis l’attribution se signe ici. Pas de droit au bail : seul le loyer fixé par le maire est dû.</p>';
  for (const ville of ['capitale', 'ville_a', 'ville_b']) {
    const libres = l.locaux.filter(x => x.ville === ville && sovLibre(x));
    html += sovSection(sovVille(ville), libres.length
      ? '<ul>' + libres.map(x => '<li>' + sovEsc(x.label) + ' — ' + sovLoyer(x) + '</li>').join('') + '</ul>'
      : '<p class="cpj-note">Aucun commerce libre.</p>');
  }
  vehModal('Commerces non attribués', html);
}

async function ouvrirSovarkaSignerAttribution() {
  const l = await sovLire();
  if (!l) { showToast('Attribution', 'Lecture impossible auprès du serveur.', false); return; }
  const aSigner = l.demandes.filter(d => d.demandeur === l.moi && d.statut === 'attribuee');
  let html = '';
  if (!aSigner.length) html = '<p>' + SOV_MOTIFS.aucune_attribution + '</p><p class="cpj-note">Le maire doit d’abord accepter votre demande et vous attribuer un local.</p>';
  for (const d of aSigner) {
    const loc = l.locaux.find(x => x.ville === d.ville && x.batiment === d.local_batiment && x.piece === d.local_piece);
    html += sovSection(sovEsc(loc?.label || 'Local') + ' (' + sovVille(d.ville) + ')',
      '<p>Projet : « ' + sovEsc(d.projet) + ' ». ' + (loc ? sovLoyer(loc) : '') + '.</p>' +
      sovBouton('Signer l’attribution (1 PA)', "sovarkaSigner('" + sovJs(d.id) + "')", true));
  }
  vehModal('Signer une attribution', html);
}
function sovarkaSigner(id) {
  sovActe('sovarka_attribution_signer', { p_demande: id }, 'Attribution signée',
    v => 'Vous exploitez désormais : ' + v.local + '.', () => document.getElementById('modal-postes')?.classList.remove('open'));
}

async function ouvrirSovarkaCession() {
  const l = await sovLire();
  if (!l) { showToast('Cession', 'Lecture impossible auprès du serveur.', false); return; }
  const miens = l.locaux.filter(x => x.exploitant === l.moi);
  let html = '<p class="cpj-note">La cession se fait sans prix officiel : l’État possède le commerce. ' +
    'La caisse suit le droit (le cédant peut la vider avant). Proposer coûte 1 PA, accepter 1 PA, les deux chez le notaire.</p>';
  for (const c of l.cessions) {
    const loc = l.locaux.find(x => x.ville === c.ville && x.batiment === c.batiment && x.piece === c.piece);
    const nom = sovEsc(loc?.label || 'Commerce') + ' (' + sovVille(c.ville) + ')';
    html += c.repreneur === l.moi
      ? sovSection('Reprise proposée par ' + sovEsc(c.cedant), '<p>' + nom + '</p>' +
          sovBouton('Accepter (1 PA)', "sovarkaCessionRepondre('" + sovJs(c.id) + "',true)", true) +
          sovBouton('Refuser', "sovarkaCessionRepondre('" + sovJs(c.id) + "',false)"))
      : sovSection('Cession proposée à ' + sovEsc(c.repreneur), '<p>' + nom + '</p>' +
          sovBouton('Annuler', "sovarkaCessionRepondre('" + sovJs(c.id) + "',false)"));
  }
  miens.forEach((x, i) => {
    if (l.cessions.some(c => c.ville === x.ville && c.batiment === x.batiment && c.piece === x.piece)) return;
    html += sovSection(sovEsc(x.label) + ' (' + sovVille(x.ville) + ')',
      '<input class="cpj-champ" id="sov-repreneur-' + i + '" maxlength="60" placeholder="Nom du repreneur" style="width:100%">' +
      sovBouton('Proposer la cession (1 PA)', "sovarkaCessionProposer('" + sovJs(x.ville) + "','" + sovJs(x.batiment) + "','" + sovJs(x.piece) + "'," + i + ")", true));
  });
  if (!miens.length && !l.cessions.length) html += '<p>Vous n’exploitez aucun commerce et aucune cession ne vous attend.</p>';
  vehModal('Cession d’un droit d’exploiter', html);
}
function sovarkaCessionProposer(ville, batiment, piece, i) {
  const rep = (document.getElementById('sov-repreneur-' + i)?.value || '').trim();
  sovActe('sovarka_cession_proposer', { p_ville: ville, p_batiment: batiment, p_piece: piece, p_repreneur: rep },
    'Cession proposée', 'Le repreneur est prévenu par courrier ; il doit accepter chez le notaire.', ouvrirSovarkaCession);
}
function sovarkaCessionRepondre(id, accepter) {
  sovActe('sovarka_cession_repondre', { p_cession: id, p_accepter: !!accepter },
    accepter ? 'Cession enregistrée' : 'Cession annulée',
    v => v.annulee ? 'La cession n’aura pas lieu.' : 'Vous exploitez désormais : ' + v.local + '.', ouvrirSovarkaCession);
}

// ----------------------------------------------------------------------------- Mairie
async function ouvrirSovarkaDemanderLocal() {
  const l = await sovLire();
  if (!l) { showToast('Demande', 'Lecture impossible auprès du serveur.', false); return; }
  const miennes = l.demandes.filter(d => d.demandeur === l.moi);
  let html = '<p class="cpj-note">Le maire examine les dossiers. S’il accepte, il vous attribue un local libre, ' +
    'ou vous attendrez l’immeuble collectif que la mairie fait construire le 1er et le 15 de chaque mois. ' +
    'Vous recevrez un courrier, puis vous signerez chez le notaire.</p>';
  miennes.forEach(d => {
    html += sovSection('Votre demande à ' + sovVille(d.ville), '<p>« ' + sovEsc(d.projet) + ' » — ' + (SOV_STATUTS[d.statut] || d.statut) + '.</p>' +
      sovBouton('Retirer ma demande', "sovarkaDemandeAnnuler('" + sovJs(d.id) + "')"));
  });
  if (!miennes.some(d => d.ville === l.ville)) {
    html += sovSection('Nouvelle demande', '<input class="cpj-champ" id="sov-projet" maxlength="200" placeholder="Votre projet de commerce" style="width:100%">' +
      sovBouton('Déposer la demande (1 PA)', 'sovarkaDemandeDeposer()', true));
  }
  vehModal('Demander un commerce', html);
}
function sovarkaDemandeDeposer() {
  const projet = (document.getElementById('sov-projet')?.value || '').trim();
  sovActe('sovarka_demande_deposer', { p_projet: projet }, 'Demande déposée', 'Le maire examinera votre dossier.', ouvrirSovarkaDemanderLocal);
}
function sovarkaDemandeAnnuler(id) {
  sovActe('sovarka_demande_annuler', { p_demande: id }, 'Demande retirée', 'Votre dossier est clos.', ouvrirSovarkaDemanderLocal);
}

// Demande de location depuis le local (décision de Fred, 06/11/2026) : une lettre à la mairie
// décrit le bien ; à l'envoi, le serveur range le dossier dans la liste du maire, au nom du PJ.
function sovPieceCourante() {
  const b = state.currentBuilding, r = state.currentRoom;
  const ctx = WORLD?.[state.country]?.[state.currentCity]?.buildingContext?.[b];
  const base = (typeof BUILDINGS !== 'undefined' && BUILDINGS[b]?.rooms?.[r]) || {};
  const sur = ctx?.roomOverrides?.[r] || {};
  return {
    batiment: b, piece: r,
    nomBatiment: ctx?.name || BUILDINGS?.[b]?.name || b,
    nomPiece: String(sur.name || base.name || r).replace(/\s*—\s*Local à louer\s*$/i, ''),
    desc: String(sur.desc || base.desc || '').replace(/^📋\s*À LOUER\s*—\s*/i, '')
  };
}

async function ouvrirSovarkaDemandeLocation() {
  const l = await sovLire();
  if (!l) { showToast('Demande de location', 'Lecture impossible auprès du serveur.', false); return; }
  const p = sovPieceCourante();
  const loc = l.locaux.find(x => x.ville === l.ville && x.batiment === p.batiment && x.piece === p.piece);
  const titre = 'Demande de location';
  if (!loc) { vehModal(titre, '<p>' + SOV_MOTIFS.local_introuvable + '</p>'); return; }
  const mienne = l.demandes.find(d => d.demandeur === l.moi && d.ville === l.ville);
  if (mienne) {
    vehModal(titre, '<p>Vous avez déjà une demande en cours à la mairie de ' + sovEsc(sovVille(l.ville)) + ' : « ' + sovEsc(mienne.projet) +
      ' » — ' + (SOV_STATUTS[mienne.statut] || mienne.statut) + '.</p><p class="cpj-note">Une seule demande à la fois par ville. ' +
      'Vous pouvez la retirer à l’accueil de la mairie.</p>');
    return;
  }
  if (!sovLibre(loc)) {
    vehModal(titre, '<p>' + (loc.exploitant ? 'Ce local est exploité par ' + sovEsc(loc.exploitant) + '.' : 'Ce local est déjà attribué, en attente de signature chez le notaire.') + '</p>');
    return;
  }
  const ville = sovVille(l.ville);
  const rue = WORLD?.soviet?.[l.ville]?.streetName;
  const lettre =
    '<div style="background:#1b2531;border:1px solid #a98d56;border-radius:6px;padding:1rem;line-height:1.5">' +
    '<p style="margin:0">' + sovEsc(l.moi) + '<br>' + sovEsc(ville) + '</p>' +
    '<p style="text-align:right;margin:.6rem 0">À l’attention du Maire<br>Mairie de ' + sovEsc(ville) + '</p>' +
    '<p><strong>Objet : demande de location d’un local commercial</strong></p>' +
    '<p>Camarade Maire,</p>' +
    '<p>J’ai l’honneur de solliciter l’attribution du local suivant :</p>' +
    '<ul style="margin:.3rem 0 .6rem 1.2rem"><li><strong>' + sovEsc(p.nomPiece) + '</strong></li>' +
    '<li>Emplacement : ' + sovEsc(p.nomBatiment) + (rue ? ', ' + sovEsc(rue) : '') + ', ' + sovEsc(ville) + '</li>' +
    (p.desc ? '<li>Description : ' + sovEsc(p.desc) + '</li>' : '') + '</ul>' +
    '<p style="margin-bottom:.3rem">Activité envisagée (facultatif) :</p>' +
    '<input class="cpj-champ" id="sov-activite" maxlength="200" placeholder="Ex. : une librairie" style="width:100%">' +
    '<p style="margin-top:.6rem">Dans l’attente de votre décision, je vous prie d’agréer, Camarade Maire, l’expression de mon dévouement au bien commun.</p>' +
    '<p style="text-align:right;font-style:italic">' + sovEsc(l.moi) + '</p></div>' +
    '<p class="cpj-note">Loyer actuellement fixé par la mairie : ' + sovLoyer(loc) + '. Si le maire accepte, vous recevrez un courrier, ' +
    'puis vous signerez l’attribution chez le notaire.</p>' +
    sovBouton('Envoyer (1 PA)', "sovarkaDemandeLocationEnvoyer('" + sovJs(p.batiment) + "','" + sovJs(p.piece) + "')", true);
  vehModal(titre, lettre);
}
function sovarkaDemandeLocationEnvoyer(batiment, piece) {
  const activite = (document.getElementById('sov-activite')?.value || '').trim();
  sovActe('sovarka_demande_location', { p_batiment: batiment, p_piece: piece, p_activite: activite || null }, 'Lettre envoyée',
    v => 'Votre demande pour « ' + v.local + ' » est entre les mains du maire.', () => document.getElementById('modal-postes')?.classList.remove('open'));
}

async function ouvrirSovarkaDossiers() {
  const l = await sovLire();
  if (!l) { showToast('Dossiers', 'Lecture impossible auprès du serveur.', false); return; }
  if (!l.role) { vehModal('Dossiers commerciaux', '<p>' + SOV_MOTIFS.reserve_autorite_municipale + '</p>'); return; }
  const ville = l.ville;
  const locaux = l.locaux.filter(x => x.ville === ville);
  const libres = locaux.filter(sovLibre);
  const options = '<option value="">— attendre l’immeuble collectif —</option>' +
    libres.map(x => '<option value="' + sovEsc(x.batiment + '|' + x.piece) + '">' + sovEsc(x.label) + ' (' + sovLoyer(x) + ')</option>').join('');
  let html = '<p class="cpj-note">Caisse de la mairie : ' + Number(l.caisseMairie || 0).toLocaleString('fr-FR') + ' PSK. ' +
    'Un immeuble collectif coûte ' + l.parametres.coutLocal + ' PSK par local et se construit en ' + l.parametres.delaiJours +
    ' jours ; il est lancé le 1er et le 15 pour les dossiers acceptés qui attendent.</p>';
  const dossiers = l.demandes.filter(d => d.ville === ville && (d.statut === 'en_attente' || d.statut === 'acceptee'));
  // Demande de location (06/11/2026) : le local souhaité est indiqué et présélectionné s'il est encore libre.
  const optionsPour = d => {
    const cle = d.local_souhaite_batiment ? d.local_souhaite_batiment + '|' + d.local_souhaite_piece : '';
    return cle ? options.replace('value="' + sovEsc(cle) + '"', 'value="' + sovEsc(cle) + '" selected') : options;
  };
  const souhait = d => {
    if (!d.local_souhaite_batiment) return '';
    const x = locaux.find(y => y.batiment === d.local_souhaite_batiment && y.piece === d.local_souhaite_piece);
    return '<br>Local demandé : <strong>' + sovEsc(x?.label || d.local_souhaite_piece) + '</strong>' + (x && !sovLibre(x) ? ' (plus libre)' : '');
  };
  html += sovSection('Demandes', dossiers.length ? dossiers.map((d, i) =>
    '<div style="margin:.5rem 0"><strong>' + sovEsc(d.demandeur) + '</strong> — « ' + sovEsc(d.projet) + ' » (' + (SOV_STATUTS[d.statut] || d.statut) + ')' + souhait(d) + '<br>' +
    '<select class="cpj-champ" id="sov-local-' + i + '">' + optionsPour(d) + '</select>' +
    sovBouton('Accepter', "sovarkaAccepter('" + sovJs(d.id) + "'," + i + ")", true) + '</div>').join('')
    : '<p class="cpj-note">Aucune demande en attente.</p>');
  const attribuees = l.demandes.filter(d => d.ville === ville && d.statut === 'attribuee');
  if (attribuees.length) html += sovSection('Attributions à signer', '<ul>' + attribuees.map(d => '<li>' + sovEsc(d.demandeur) + ' — ' +
    sovEsc((locaux.find(x => x.batiment === d.local_batiment && x.piece === d.local_piece) || {}).label || '') + '</li>').join('') + '</ul>');
  html += sovSection('Locaux et loyers', locaux.map((x, i) => '<div style="margin:.4rem 0">' + sovEsc(x.label) + ' — ' +
    (x.exploitant ? 'exploité par ' + sovEsc(x.exploitant) : x.reserve ? 'réservé' : 'libre') +
    (x.origine === 'pnj' ? ' (sans loyer)' : '<br><input class="cpj-champ" id="sov-loyer-' + i + '" type="number" min="0" max="' + x.plafond +
      '" value="' + x.loyer + '" style="width:6rem"> PSK / jour (0 à ' + x.plafond + ')' +
      sovBouton('Fixer', "sovarkaLoyer('" + sovJs(x.batiment) + "','" + sovJs(x.piece) + "'," + i + ")")) + '</div>').join(''));
  const comp = l.composition || 'commerces';
  html += sovSection('Immeubles collectifs', '<p>Type des prochains immeubles : <strong>' + (comp === 'mixte' ? 'mixte (commerces et logements)' : 'uniquement des commerces') + '</strong></p>' +
    sovBouton('Mixte', "sovarkaComposition('mixte')", comp === 'mixte') + sovBouton('Commerces seulement', "sovarkaComposition('commerces')", comp !== 'mixte') +
    '<ul>' + l.immeubles.filter(i => i.ville === ville).map(i => '<li>' + sovEsc(i.terrain) + ' : ' + i.nb_commerces + ' commerce(s)' +
      (i.nb_logements ? ', ' + i.nb_logements + ' logement(s)' : '') + ' — ' + (SOV_IMMEUBLES[i.statut] || i.statut) +
      (i.statut === 'en_chantier' ? ', livraison le ' + sovEsc(i.livraison_le) : '') + '</li>').join('') + '</ul>');
  vehModal('Dossiers commerciaux — ' + sovVille(ville), html);
}
function sovarkaAccepter(id, i) {
  const v = document.getElementById('sov-local-' + i)?.value || '';
  const [batiment, piece] = v ? v.split('|') : [null, null];
  sovActe('sovarka_demande_accepter', { p_demande: id, p_batiment: batiment, p_piece: piece }, 'Demande acceptée',
    r => r.attente ? 'Le dossier attend le prochain immeuble collectif.' : 'Local attribué : ' + r.local + '. Le demandeur est prévenu.', ouvrirSovarkaDossiers);
}
function sovarkaLoyer(batiment, piece, i) {
  const loyer = parseInt(document.getElementById('sov-loyer-' + i)?.value, 10);
  sovActe('sovarka_local_loyer_fixer', { p_ville: state.currentCity, p_batiment: batiment, p_piece: piece, p_loyer: isNaN(loyer) ? null : loyer },
    'Loyer fixé', v => 'Nouveau loyer : ' + v.loyer + ' PSK par jour.', ouvrirSovarkaDossiers);
}
function sovarkaComposition(c) {
  sovActe('sovarka_composition_fixer', { p_ville: state.currentCity, p_composition: c }, 'Immeubles collectifs',
    c === 'mixte' ? 'Les prochains immeubles mêleront commerces et logements.' : 'Les prochains immeubles n’auront que des commerces.', ouvrirSovarkaDossiers);
}

// ----------------------------------------------------------------------------- Tribunal
async function ouvrirSovarkaRetirerDroit() {
  // Décision de Fred (08/11/2026) : le juge ne retire un droit que sur saisine du ministre de la
  // Justice prolétarienne ; il décide librement (retirer ou rejeter).
  const l = (typeof sovPouvoirLire === 'function') ? await sovPouvoirLire() : null;
  if (!l) return;
  if (!(l.juge_villes || []).includes(state.currentCity)) { vehModal('Saisines du ministre', '<p>' + SOV_MOTIFS.reserve_juge + '</p>'); return; }
  const saisines = (l.saisines || []).filter(x => x.statut === 'en_attente' && x.ville === state.currentCity);
  let html = '<p class="cpj-note">Le ministre de la Justice prolétarienne vous saisit. Le droit retiré revient à l’État, sans indemnité ; '
    + 'l’exploitant est prévenu par courrier. Vous pouvez aussi rejeter la saisine.</p>'
    + '<input class="cpj-champ" id="sov-motif" maxlength="300" placeholder="Motif de la décision" style="width:100%">';
  html += saisines.length ? saisines.map(x => sovSection(sovEsc(x.exploitant || '?'),
    '<p>Commerce : ' + sovEsc(x.batiment) + ' · ' + sovEsc(x.piece) + '</p><p class="cpj-note">Motif du ministre : ' + sovEsc(x.motif) + '</p>' +
    sovBouton('Retirer le droit (1 PA)', "sovarkaRetirer('" + sovJs(x.batiment) + "','" + sovJs(x.piece) + "')", true) +
    sovBouton('Rejeter la saisine', 'sovarkaRejeterSaisine(' + Number(x.id) + ')', false))).join('')
    : '<p>Aucune saisine en attente.</p>';
  vehModal('Saisines du ministre', html);
}
function sovarkaRetirer(batiment, piece) {
  const motif = (document.getElementById('sov-motif')?.value || '').trim();
  sovActe('sovarka_droit_retirer', { p_ville: state.currentCity, p_batiment: batiment, p_piece: piece, p_motif: motif },
    'Droit retiré', v => v.local + ' revient à l’État.', ouvrirSovarkaRetirerDroit);
}
function sovarkaRejeterSaisine(id) {
  if (typeof sovPouvoirActe === 'function')
    sovPouvoirActe('juge_rejeter', { saisine: id }, 'Saisine', 'Saisine rejetée : le ministre est prévenu.', ouvrirSovarkaRetirerDroit);
}

// ----------------------------------------------------------------------------- Terrains
async function ouvrirSovarkaTerrain() {
  const l = await sovLire();
  if (!l) { showToast('Terrain', 'Lecture impossible auprès du serveur.', false); return; }
  const i = l.immeubles.find(x => x.ville === state.currentCity && x.terrain === state.currentBuilding);
  const html = !i ? '<p>Terrain libre. La mairie y construira un immeuble collectif quand des dossiers de commerce attendront un local.</p>'
    : '<p>Immeuble collectif : ' + i.nb_commerces + ' local(aux) commercial(aux)' + (i.nb_logements ? ' et ' + i.nb_logements + ' logement(s)' : '') +
      ' — ' + (SOV_IMMEUBLES[i.statut] || i.statut) + (i.statut === 'en_chantier' ? ', livraison le ' + sovEsc(i.livraison_le) : '') + '.</p>';
  vehModal('Terrain municipal', html);
  if (typeof rafraichirPiecesDynamiques === 'function') rafraichirPiecesDynamiques(state.currentBuilding);
}

// Pieces des immeubles collectifs (locaux et logements), injectees dans le terrain par
// hydraterPiecesDynamiques (plateau-immobilier.js) depuis la derniere lecture du serveur.
function sovarkaPiecesImmeuble(buildingId) {
  if (typeof state === 'undefined' || state.country !== 'soviet' || !sovarkaDroitsCache) return [];
  const ville = state.currentCity;
  const i = (sovarkaDroitsCache.immeubles || []).find(x => x.ville === ville && x.terrain === buildingId && x.statut === 'livre');
  if (!i) return [];
  const fond = 'linear-gradient(135deg,#121418,#1a1d22)';
  const pieces = (sovarkaDroitsCache.locaux || []).filter(x => x.ville === ville && x.batiment === buildingId).map(x => [x.piece, {
    name: x.label, desc: 'Local commercial de l’immeuble collectif, propriété de l’État. ' + (x.exploitant ? 'Exploité par ' + x.exploitant + '.' : 'Attribué par la mairie.'),
    imageBg: fond, isLocationRoom: true, persons: [],
    locationData: { prix: x.loyer, bonusPOP: 0, bonusINF: 0, bonusDIS: 0, label: x.label },
    orders: [
      { fn: 'commerce_pj', label: 'Ce commerce', pa: 0, cost: 0, type: 'legal', icon: 'ti-building-store', successRate: 100, desc: 'Gérer votre commerce, ou visiter la boutique du commerçant.' },
      { fn: 'gerer_local', label: 'Gérer mon local', pa: 1, cost: 0, type: 'legal', icon: 'ti-settings', successRate: 100 }
    ]
  }]);
  for (let k = 1; k <= (i.nb_logements || 0); k++) {
    pieces.push(['logement_' + k, {
      name: 'Logement n°' + k, desc: 'Un logement social de l’immeuble collectif, attribué par la mairie.', imageBg: fond, isLocationRoom: true, persons: [],
      locationData: { type: 'petit', prix: 10, bonusPOP: 0, bonusINF: 0, bonusDIS: 0, label: 'Logement n°' + k, logementSocial: true,
        orgaAutorisee: false, bonusMoralSommeil: 3, bonusSanteSommeil: 4 },
      orders: [{ fn: 'gerer_logement_social', label: 'Mon logement', pa: 0, cost: 0, type: 'legal', icon: 'ti-home-cog', successRate: 100,
        desc: 'Voir les conditions de votre bail, si vous êtes le locataire de ce logement.' }]
    }]);
  }
  return pieces;
}

// Lecture en arriere-plan a l'entree d'un terrain de Sovarka, puis reconstruction des onglets.
function sovarkaPrechargerTerrain(buildingId) {
  if (typeof state === 'undefined' || state.country !== 'soviet' || !/^terrain-a-batir-/.test(buildingId || '')) return;
  sovLire().then(l => { if (l && typeof rafraichirPiecesDynamiques === 'function') rafraichirPiecesDynamiques(buildingId); });
}
