// SOVARKA : DROITS D'EXPLOITER (decisions de Fred du 06/11/2026, GAME-DESIGN-NOVOMIRSK.md).
// L'Etat possede tout ; un PJ obtient un droit d'exploiter : demande a la mairie, acceptation du maire
// (a defaut l'adjoint, a defaut le ministre de l'Economie collective), signature chez le notaire.
// Cession entre PJ enregistree par le notaire, retour a l'Etat au deces ou par decision du juge.
// Tout est decide par les fonctions serveur sovarka_* ; l'ecran n'affiche que leurs reponses.

// Textes d'affichage : catalogue i18n/sovarka-droits-resources.js (français de référence et de repli).
const sovT = (k, v) => (typeof texteSovDroits === 'function' ? texteSovDroits(k, v) : k);
const SOV_RAISONS = ['pas_a_la_mairie', 'pas_chez_le_notaire', 'pas_au_tribunal', 'pas_dans_le_local', 'demande_deja_en_cours',
  'projet_invalide', 'reserve_autorite_municipale', 'reserve_juge', 'demande_introuvable', 'local_introuvable', 'local_non_libre',
  'loyer_invalide', 'commerce_sans_loyer', 'aucune_attribution', 'pas_exploitant', 'repreneur_introuvable', 'cession_deja_en_cours',
  'cession_introuvable', 'reserve_repreneur', 'cedant_plus_exploitant', 'motif_invalide', 'saisine_requise', 'local_non_exploite',
  'pa_insuffisants', 'acteur_non_authentifie', 'parametres_invalides', 'cause_invalide'];
const sovMotif = v => SOV_RAISONS.includes(v?.raison) ? sovT('m_' + v.raison) : sovT(v?.transport ? 'noReply' : 'refused');
const sovEsc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const sovJs = s => String(s == null ? '' : s).replace(/\\/g, '\\\\').replace(/'/g, "\\'");
const sovVille = v => (typeof VILLES !== 'undefined' && VILLES.soviet?.[v]?.nom) || v;
const sovSection = (titre, corps) => (typeof vehSection === 'function') ? vehSection(titre, corps)
  : '<section><strong>' + titre + '</strong>' + corps + '</section>';
const sovBouton = (libelle, js, primaire) =>
  '<button class="cpj-touche' + (primaire ? ' cpj-primaire' : '') + '" style="margin:.4rem .4rem 0 0" onclick="' + js + '">' + libelle + '</button>';
const sovStatut = st => ['en_attente', 'acceptee', 'attribuee'].includes(st) ? sovT('st_' + st) : st;
const sovImmeuble = st => ['en_attente_fonds', 'en_chantier', 'livre'].includes(st) ? sovT('im_' + st) : st;

// Fenêtre de Sovarka ouverte : retenue pour la réafficher au changement de langue.
// Le marqueur caché distingue nos fenêtres de celles des autres modules qui partagent #modal-postes.
function sovModal(titre, html, rouvrir) {
  window.sovFenetreCourante = typeof rouvrir === 'function' ? rouvrir : null;
  vehModal(titre, '<span data-sov-fenetre hidden></span>' + html);
}
// Changement de langue : réaffichage depuis la dernière lecture du serveur (aucun acte), saisies conservées.
function sovarkaRerendreFenetre() {
  const f = window.sovFenetreCourante;
  if (typeof f !== 'function' || !document.getElementById('modal-postes')?.classList.contains('open')
    || !document.querySelector('#postes-body [data-sov-fenetre]')) return;
  const champs = {};
  document.querySelectorAll('#postes-body input[id], #postes-body select[id], #postes-body textarea[id]').forEach(e => { champs[e.id] = e.value; });
  return Promise.resolve(f(true)).then(() => {
    for (const [id, v] of Object.entries(champs)) { const e = document.getElementById(id); if (e) e.value = v; }
  });
}
window.sovarkaRerendreFenetre = sovarkaRerendreFenetre;

let sovarkaDroitsCache = null;
let sovarkaActeEnCours = false;

async function sovLire(cache) {
  if (cache === true && sovarkaDroitsCache) return sovarkaDroitsCache;
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
const sovLoyer = l => l.origine === 'pnj' ? sovT('noRent') : sovT('rentPerDay', { loyer: l.loyer });

// ----------------------------------------------------------------------------- Notaire
async function ouvrirSovarkaCommercesLibres(cache) {
  const l = await sovLire(cache);
  if (!l) { showToast(sovT('tShops'), sovT('readFail'), false); return; }
  let html = '<p class="cpj-note">' + sovT('freeIntro') + '</p>';
  for (const ville of ['capitale', 'ville_a', 'ville_b']) {
    const libres = l.locaux.filter(x => x.ville === ville && sovLibre(x));
    html += sovSection(sovVille(ville), libres.length
      ? '<ul>' + libres.map(x => '<li>' + sovEsc(x.label) + ' — ' + sovLoyer(x) + '</li>').join('') + '</ul>'
      : '<p class="cpj-note">' + sovT('noFreeShop') + '</p>');
  }
  sovModal(sovT('titleUnassigned'), html, ouvrirSovarkaCommercesLibres);
}

async function ouvrirSovarkaSignerAttribution(cache) {
  const l = await sovLire(cache);
  if (!l) { showToast(sovT('tAttribution'), sovT('readFail'), false); return; }
  const aSigner = l.demandes.filter(d => d.demandeur === l.moi && d.statut === 'attribuee');
  let html = '';
  if (!aSigner.length) html = '<p>' + sovT('m_aucune_attribution') + '</p><p class="cpj-note">' + sovT('signWait') + '</p>';
  for (const d of aSigner) {
    const loc = l.locaux.find(x => x.ville === d.ville && x.batiment === d.local_batiment && x.piece === d.local_piece);
    html += sovSection(sovEsc(loc?.label || sovT('premises')) + ' (' + sovVille(d.ville) + ')',
      '<p>' + sovT('projectLine', { projet: sovEsc(d.projet) }) + ' ' + (loc ? sovLoyer(loc) : '') + '.</p>' +
      sovBouton(sovT('signBtn'), "sovarkaSigner('" + sovJs(d.id) + "')", true));
  }
  sovModal(sovT('titleSign'), html, ouvrirSovarkaSignerAttribution);
}
function sovarkaSigner(id) {
  sovActe('sovarka_attribution_signer', { p_demande: id }, sovT('tSigned'),
    v => sovT('nowExploit', { local: v.local }), () => document.getElementById('modal-postes')?.classList.remove('open'));
}

async function ouvrirSovarkaCession(cache) {
  const l = await sovLire(cache);
  if (!l) { showToast(sovT('tCession'), sovT('readFail'), false); return; }
  const miens = l.locaux.filter(x => x.exploitant === l.moi);
  let html = '<p class="cpj-note">' + sovT('cessionIntro') + '</p>';
  for (const c of l.cessions) {
    const loc = l.locaux.find(x => x.ville === c.ville && x.batiment === c.batiment && x.piece === c.piece);
    const nom = sovEsc(loc?.label || sovT('shop')) + ' (' + sovVille(c.ville) + ')';
    html += c.repreneur === l.moi
      ? sovSection(sovT('takeoverBy', { nom: sovEsc(c.cedant) }), '<p>' + nom + '</p>' +
          sovBouton(sovT('accept1'), "sovarkaCessionRepondre('" + sovJs(c.id) + "',true)", true) +
          sovBouton(sovT('refuse'), "sovarkaCessionRepondre('" + sovJs(c.id) + "',false)"))
      : sovSection(sovT('cessionTo', { nom: sovEsc(c.repreneur) }), '<p>' + nom + '</p>' +
          sovBouton(sovT('cancel'), "sovarkaCessionRepondre('" + sovJs(c.id) + "',false)"));
  }
  miens.forEach((x, i) => {
    if (l.cessions.some(c => c.ville === x.ville && c.batiment === x.batiment && c.piece === x.piece)) return;
    html += sovSection(sovEsc(x.label) + ' (' + sovVille(x.ville) + ')',
      '<input class="cpj-champ" id="sov-repreneur-' + i + '" maxlength="60" placeholder="' + sovEsc(sovT('buyerPh')) + '" style="width:100%">' +
      sovBouton(sovT('proposeBtn'), "sovarkaCessionProposer('" + sovJs(x.ville) + "','" + sovJs(x.batiment) + "','" + sovJs(x.piece) + "'," + i + ")", true));
  });
  if (!miens.length && !l.cessions.length) html += '<p>' + sovT('noneOwned') + '</p>';
  sovModal(sovT('titleCession'), html, ouvrirSovarkaCession);
}
function sovarkaCessionProposer(ville, batiment, piece, i) {
  const rep = (document.getElementById('sov-repreneur-' + i)?.value || '').trim();
  sovActe('sovarka_cession_proposer', { p_ville: ville, p_batiment: batiment, p_piece: piece, p_repreneur: rep },
    sovT('tProposed'), sovT('proposedOk'), ouvrirSovarkaCession);
}
function sovarkaCessionRepondre(id, accepter) {
  sovActe('sovarka_cession_repondre', { p_cession: id, p_accepter: !!accepter },
    accepter ? sovT('tRegistered') : sovT('tCancelled'),
    v => v.annulee ? sovT('willNot') : sovT('nowExploit', { local: v.local }), ouvrirSovarkaCession);
}

// ----------------------------------------------------------------------------- Mairie
async function ouvrirSovarkaDemanderLocal(cache) {
  const l = await sovLire(cache);
  if (!l) { showToast(sovT('tRequest'), sovT('readFail'), false); return; }
  const miennes = l.demandes.filter(d => d.demandeur === l.moi);
  let html = '<p class="cpj-note">' + sovT('requestIntro') + '</p>';
  miennes.forEach(d => {
    html += sovSection(sovT('yourRequest', { ville: sovVille(d.ville) }), '<p>' + sovT('statusLine', { projet: sovEsc(d.projet), statut: sovStatut(d.statut) }) + '</p>' +
      sovBouton(sovT('withdraw'), "sovarkaDemandeAnnuler('" + sovJs(d.id) + "')"));
  });
  if (!miennes.some(d => d.ville === l.ville)) {
    html += sovSection(sovT('newRequest'), '<input class="cpj-champ" id="sov-projet" maxlength="200" placeholder="' + sovEsc(sovT('projectPh')) + '" style="width:100%">' +
      sovBouton(sovT('fileBtn'), 'sovarkaDemandeDeposer()', true));
  }
  sovModal(sovT('titleRequest'), html, ouvrirSovarkaDemanderLocal);
}
function sovarkaDemandeDeposer() {
  const projet = (document.getElementById('sov-projet')?.value || '').trim();
  sovActe('sovarka_demande_deposer', { p_projet: projet }, sovT('tFiled'), sovT('filedOk'), ouvrirSovarkaDemanderLocal);
}
function sovarkaDemandeAnnuler(id) {
  sovActe('sovarka_demande_annuler', { p_demande: id }, sovT('tWithdrawn'), sovT('withdrawnOk'), ouvrirSovarkaDemanderLocal);
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

async function ouvrirSovarkaDemandeLocation(cache) {
  const l = await sovLire(cache);
  if (!l) { showToast(sovT('tRental'), sovT('readFail'), false); return; }
  const p = sovPieceCourante();
  const loc = l.locaux.find(x => x.ville === l.ville && x.batiment === p.batiment && x.piece === p.piece);
  const titre = sovT('tRental');
  const fen = (h) => sovModal(titre, h, ouvrirSovarkaDemandeLocation);
  if (!loc) { fen('<p>' + sovT('m_local_introuvable') + '</p>'); return; }
  const mienne = l.demandes.find(d => d.demandeur === l.moi && d.ville === l.ville);
  if (mienne) {
    fen('<p>' + sovT('already', { ville: sovEsc(sovVille(l.ville)), projet: sovEsc(mienne.projet), statut: sovStatut(mienne.statut) }) +
      '</p><p class="cpj-note">' + sovT('oneAtTime') + '</p>');
    return;
  }
  if (!sovLibre(loc)) {
    fen('<p>' + (loc.exploitant ? sovT('exploitedBy', { nom: sovEsc(loc.exploitant) }) : sovT('reservedSign')) + '</p>');
    return;
  }
  const ville = sovVille(l.ville);
  const rue = WORLD?.soviet?.[l.ville]?.streetName;
  const lettre =
    '<div style="background:#1b2531;border:1px solid #a98d56;border-radius:6px;padding:1rem;line-height:1.5">' +
    '<p style="margin:0">' + sovEsc(l.moi) + '<br>' + sovEsc(ville) + '</p>' +
    '<p style="text-align:right;margin:.6rem 0">' + sovT('lAttn') + '<br>' + sovT('lTownHall', { ville: sovEsc(ville) }) + '</p>' +
    '<p><strong>' + sovT('lSubject') + '</strong></p>' +
    '<p>' + sovT('lComrade') + '</p>' +
    '<p>' + sovT('lHonour') + '</p>' +
    '<ul style="margin:.3rem 0 .6rem 1.2rem"><li><strong>' + sovEsc(p.nomPiece) + '</strong></li>' +
    '<li>' + sovT('lPlace', { lieu: sovEsc(p.nomBatiment) + (rue ? ', ' + sovEsc(rue) : '') + ', ' + sovEsc(ville) }) + '</li>' +
    (p.desc ? '<li>' + sovT('lDesc', { desc: sovEsc(p.desc) }) + '</li>' : '') + '</ul>' +
    '<p style="margin-bottom:.3rem">' + sovT('lActivity') + '</p>' +
    '<input class="cpj-champ" id="sov-activite" maxlength="200" placeholder="' + sovEsc(sovT('lActivityPh')) + '" style="width:100%">' +
    '<p style="margin-top:.6rem">' + sovT('lClose') + '</p>' +
    '<p style="text-align:right;font-style:italic">' + sovEsc(l.moi) + '</p></div>' +
    '<p class="cpj-note">' + sovT('lRentNote', { loyer: sovLoyer(loc) }) + '</p>' +
    sovBouton(sovT('send'), "sovarkaDemandeLocationEnvoyer('" + sovJs(p.batiment) + "','" + sovJs(p.piece) + "')", true);
  fen(lettre);
}
function sovarkaDemandeLocationEnvoyer(batiment, piece) {
  const activite = (document.getElementById('sov-activite')?.value || '').trim();
  sovActe('sovarka_demande_location', { p_batiment: batiment, p_piece: piece, p_activite: activite || null }, sovT('tSent'),
    v => sovT('sentOk', { local: v.local }), () => document.getElementById('modal-postes')?.classList.remove('open'));
}

async function ouvrirSovarkaDossiers(cache) {
  const l = await sovLire(cache);
  if (!l) { showToast(sovT('tFiles'), sovT('readFail'), false); return; }
  if (!l.role) { sovModal(sovT('titleFiles'), '<p>' + sovT('m_reserve_autorite_municipale') + '</p>', ouvrirSovarkaDossiers); return; }
  const ville = l.ville;
  const locaux = l.locaux.filter(x => x.ville === ville);
  const libres = locaux.filter(sovLibre);
  const options = '<option value="">' + sovT('waitBuilding') + '</option>' +
    libres.map(x => '<option value="' + sovEsc(x.batiment + '|' + x.piece) + '">' + sovEsc(x.label) + ' (' + sovLoyer(x) + ')</option>').join('');
  let html = '<p class="cpj-note">' + sovT('cashNote', { caisse: Number(l.caisseMairie || 0).toLocaleString('fr-FR'),
    cout: l.parametres.coutLocal, jours: l.parametres.delaiJours }) + '</p>';
  const dossiers = l.demandes.filter(d => d.ville === ville && (d.statut === 'en_attente' || d.statut === 'acceptee'));
  // Demande de location (06/11/2026) : le local souhaité est indiqué et présélectionné s'il est encore libre.
  const optionsPour = d => {
    const cle = d.local_souhaite_batiment ? d.local_souhaite_batiment + '|' + d.local_souhaite_piece : '';
    return cle ? options.replace('value="' + sovEsc(cle) + '"', 'value="' + sovEsc(cle) + '" selected') : options;
  };
  const souhait = d => {
    if (!d.local_souhaite_batiment) return '';
    const x = locaux.find(y => y.batiment === d.local_souhaite_batiment && y.piece === d.local_souhaite_piece);
    return '<br>' + sovT('wanted') + ' <strong>' + sovEsc(x?.label || d.local_souhaite_piece) + '</strong>' + (x && !sovLibre(x) ? sovT('noLongerFree') : '');
  };
  html += sovSection(sovT('requests'), dossiers.length ? dossiers.map((d, i) =>
    '<div style="margin:.5rem 0"><strong>' + sovEsc(d.demandeur) + '</strong> — « ' + sovEsc(d.projet) + ' » (' + sovStatut(d.statut) + ')' + souhait(d) + '<br>' +
    '<select class="cpj-champ" id="sov-local-' + i + '">' + optionsPour(d) + '</select>' +
    sovBouton(sovT('accept'), "sovarkaAccepter('" + sovJs(d.id) + "'," + i + ")", true) + '</div>').join('')
    : '<p class="cpj-note">' + sovT('noneWaiting') + '</p>');
  const attribuees = l.demandes.filter(d => d.ville === ville && d.statut === 'attribuee');
  if (attribuees.length) html += sovSection(sovT('toSign'), '<ul>' + attribuees.map(d => '<li>' + sovEsc(d.demandeur) + ' — ' +
    sovEsc((locaux.find(x => x.batiment === d.local_batiment && x.piece === d.local_piece) || {}).label || '') + '</li>').join('') + '</ul>');
  html += sovSection(sovT('premisesRents'), locaux.map((x, i) => '<div style="margin:.4rem 0">' + sovEsc(x.label) + ' — ' +
    (x.exploitant ? sovT('exploitedByShort', { nom: sovEsc(x.exploitant) }) : x.reserve ? sovT('reserved') : sovT('free')) +
    (x.origine === 'pnj' ? sovT('noRentParen') : '<br><input class="cpj-champ" id="sov-loyer-' + i + '" type="number" min="0" max="' + x.plafond +
      '" value="' + x.loyer + '" style="width:6rem"> ' + sovT('rentRange', { max: x.plafond }) +
      sovBouton(sovT('set'), "sovarkaLoyer('" + sovJs(x.batiment) + "','" + sovJs(x.piece) + "'," + i + ")")) + '</div>').join(''));
  const comp = l.composition || 'commerces';
  html += sovSection(sovT('buildings'), '<p>' + sovT('nextType') + ' <strong>' + (comp === 'mixte' ? sovT('mixed') : sovT('shopsOnly')) + '</strong></p>' +
    sovBouton(sovT('bMixed'), "sovarkaComposition('mixte')", comp === 'mixte') + sovBouton(sovT('bShops'), "sovarkaComposition('commerces')", comp !== 'mixte') +
    '<ul>' + l.immeubles.filter(i => i.ville === ville).map(i => '<li>' + sovT('bLine', { terrain: sovEsc(i.terrain), n: i.nb_commerces }) +
      (i.nb_logements ? sovT('bHomes', { n: i.nb_logements }) : '') + ' — ' + sovImmeuble(i.statut) +
      (i.statut === 'en_chantier' ? sovT('delivery', { date: sovEsc(i.livraison_le) }) : '') + '</li>').join('') + '</ul>');
  sovModal(sovT('titleFilesCity', { ville: sovVille(ville) }), html, ouvrirSovarkaDossiers);
}
function sovarkaAccepter(id, i) {
  const v = document.getElementById('sov-local-' + i)?.value || '';
  const [batiment, piece] = v ? v.split('|') : [null, null];
  sovActe('sovarka_demande_accepter', { p_demande: id, p_batiment: batiment, p_piece: piece }, sovT('tAccepted'),
    r => r.attente ? sovT('waitsNext') : sovT('attributed', { local: r.local }), ouvrirSovarkaDossiers);
}
function sovarkaLoyer(batiment, piece, i) {
  const loyer = parseInt(document.getElementById('sov-loyer-' + i)?.value, 10);
  sovActe('sovarka_local_loyer_fixer', { p_ville: state.currentCity, p_batiment: batiment, p_piece: piece, p_loyer: isNaN(loyer) ? null : loyer },
    sovT('tRentSet'), v => sovT('newRent', { loyer: v.loyer }), ouvrirSovarkaDossiers);
}
function sovarkaComposition(c) {
  sovActe('sovarka_composition_fixer', { p_ville: state.currentCity, p_composition: c }, sovT('buildings'),
    c === 'mixte' ? sovT('mixedOk') : sovT('shopsOk'), ouvrirSovarkaDossiers);
}

// ----------------------------------------------------------------------------- Tribunal
async function ouvrirSovarkaRetirerDroit(cache) {
  // Décision de Fred (08/11/2026) : le juge ne retire un droit que sur saisine du ministre de la
  // Justice prolétarienne ; il décide librement (retirer ou rejeter).
  const l = (typeof sovPouvoirLire === 'function') ? await sovPouvoirLire(cache) : null;
  if (!l) return;
  if (!(l.juge_villes || []).includes(state.currentCity)) { sovModal(sovT('titleReferrals'), '<p>' + sovT('m_reserve_juge') + '</p>', ouvrirSovarkaRetirerDroit); return; }
  const saisines = (l.saisines || []).filter(x => x.statut === 'en_attente' && x.ville === state.currentCity);
  let html = '<p class="cpj-note">' + sovT('referralIntro') + '</p>'
    + '<input class="cpj-champ" id="sov-motif" maxlength="300" placeholder="' + sovEsc(sovT('reasonPh')) + '" style="width:100%">';
  html += saisines.length ? saisines.map(x => sovSection(sovEsc(x.exploitant || '?'),
    '<p>' + sovT('shopLine', { lieu: sovEsc(x.batiment) + ' · ' + sovEsc(x.piece) }) + '</p><p class="cpj-note">' + sovT('ministerReason', { motif: sovEsc(x.motif) }) + '</p>' +
    sovBouton(sovT('revokeBtn'), "sovarkaRetirer('" + sovJs(x.batiment) + "','" + sovJs(x.piece) + "')", true) +
    sovBouton(sovT('rejectBtn'), 'sovarkaRejeterSaisine(' + Number(x.id) + ')', false))).join('')
    : '<p>' + sovT('noReferral') + '</p>';
  sovModal(sovT('titleReferrals'), html, ouvrirSovarkaRetirerDroit);
}
function sovarkaRetirer(batiment, piece) {
  const motif = (document.getElementById('sov-motif')?.value || '').trim();
  sovActe('sovarka_droit_retirer', { p_ville: state.currentCity, p_batiment: batiment, p_piece: piece, p_motif: motif },
    sovT('tRevoked'), v => sovT('revokedOk', { local: v.local }), ouvrirSovarkaRetirerDroit);
}
function sovarkaRejeterSaisine(id) {
  if (typeof sovPouvoirActe === 'function')
    sovPouvoirActe('juge_rejeter', { saisine: id }, sovT('tReferral'), sovT('rejectedOk'), ouvrirSovarkaRetirerDroit);
}

// ----------------------------------------------------------------------------- Terrains
async function ouvrirSovarkaTerrain(cache) {
  const l = await sovLire(cache);
  if (!l) { showToast(sovT('tLand'), sovT('readFail'), false); return; }
  // Un terrain peut porter plusieurs parcelles (Starovka : 4, decision de Fred du 09/11/2026) :
  // le serveur nomme la parcelle n « terrain@pn ».
  const parcelle = t => (String(t).split('@')[1] || 'p1').slice(1);
  const imm = l.immeubles.filter(x => x.ville === state.currentCity && String(x.terrain).split('@')[0] === state.currentBuilding);
  const html = !imm.length ? '<p>' + sovT('landFree') + '</p>'
    : imm.map(i => '<p>' + (imm.length > 1 || String(i.terrain).includes('@') ? sovT('plot', { n: parcelle(i.terrain) }) : '') +
      sovT('landBuilding', { n: i.nb_commerces }) + (i.nb_logements ? sovT('landHomes', { n: i.nb_logements }) : '') +
      ' — ' + sovImmeuble(i.statut) + (i.statut === 'en_chantier' ? sovT('delivery', { date: sovEsc(i.livraison_le) }) : '') + '.</p>').join('');
  sovModal(sovT('titleLand'), html, ouvrirSovarkaTerrain);
  if (!cache && typeof rafraichirPiecesDynamiques === 'function') rafraichirPiecesDynamiques(state.currentBuilding);
}

// Pieces des immeubles collectifs (locaux et logements), injectees dans le terrain par
// hydraterPiecesDynamiques (plateau-immobilier.js) depuis la derniere lecture du serveur.
function sovarkaPiecesImmeuble(buildingId) {
  if (typeof state === 'undefined' || state.country !== 'soviet' || !sovarkaDroitsCache) return [];
  const ville = state.currentCity;
  const livres = (sovarkaDroitsCache.immeubles || []).filter(x => x.ville === ville && String(x.terrain).split('@')[0] === buildingId && x.statut === 'livre');
  if (!livres.length) return [];
  const fond = 'linear-gradient(135deg,#121418,#1a1d22)';
  const pieces = (sovarkaDroitsCache.locaux || []).filter(x => x.ville === ville && x.batiment === buildingId).map(x => [x.piece, {
    name: x.label, desc: sovT('roomDesc') + ' ' + (x.exploitant ? sovT('roomExploited', { nom: x.exploitant }) : sovT('roomAttributed')),
    imageBg: fond, isLocationRoom: true, persons: [],
    locationData: { prix: x.loyer, bonusPOP: 0, bonusINF: 0, bonusDIS: 0, label: x.label },
    orders: [
      { fn: 'commerce_pj', label: 'Ce commerce', pa: 0, cost: 0, type: 'legal', icon: 'ti-building-store', successRate: 100, desc: sovT('orderShopDesc') },
      { fn: 'gerer_local', label: 'Gérer mon local', pa: 1, cost: 0, type: 'legal', icon: 'ti-settings', successRate: 100 }
    ]
  }]);
  for (const i of livres) for (let k = 1; k <= (i.nb_logements || 0); k++) {
    const prefixe = String(i.terrain).includes('@') ? String(i.terrain).split('@')[1] + '_' : '';
    const nom = (prefixe ? 'Parcelle ' + prefixe.slice(1, -1) + ' — logement n°' : 'Logement n°') + k;
    pieces.push([prefixe + 'logement_' + k, {
      name: nom, desc: sovT('homeDesc'), imageBg: fond, isLocationRoom: true, persons: [],
      locationData: { type: 'petit', prix: 10, bonusPOP: 0, bonusINF: 0, bonusDIS: 0, label: nom, logementSocial: true,
        orgaAutorisee: false, bonusMoralSommeil: 3, bonusSanteSommeil: 4 },
      orders: [{ fn: 'gerer_logement_social', label: 'Mon logement', pa: 0, cost: 0, type: 'legal', icon: 'ti-home-cog', successRate: 100,
        desc: sovT('homeOrderDesc') }]
    }]);
  }
  return pieces;
}

// Lecture en arriere-plan a l'entree d'un terrain de Sovarka, puis reconstruction des onglets.
function sovarkaPrechargerTerrain(buildingId) {
  if (typeof state === 'undefined' || state.country !== 'soviet' || !/^terrain-a-batir-/.test(buildingId || '')) return;
  sovLire().then(l => { if (l && typeof rafraichirPiecesDynamiques === 'function') rafraichirPiecesDynamiques(buildingId); });
}
