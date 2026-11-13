// plateau-appartements.js
// Appartements populaires (décisions de Fred du 12/11/2026, GAME-DESIGN-APPARTEMENTS.md) :
// fenêtre « Mon logement », option premium (chambres séparées, décors par IA), colocation,
// reprise du bail, onglets des chambres et décors affichés.
//
// TOUT EST DÉCIDÉ PAR LE SERVEUR (migration 20261112221500) : qui a la jouissance de quelle pièce,
// le +1 PA au sommeil, les emplacements, qui peut décorer, la colocation (2 PA), la reprise du bail.
// Cet écran ne fait que demander et afficher la réponse.
(function (global) {
'use strict';

function texteAppart(cle, fr, vars) {
  if (global.RPAppartementsI18n && typeof global.RPAppartementsI18n.texte === 'function') return global.RPAppartementsI18n.texte(cle, fr, vars);
  return String(fr).replace(/\{(\w+)\}/g, (t, k) => vars && Object.prototype.hasOwnProperty.call(vars, k) ? String(vars[k]) : t);
}
function esc(s) {
  return String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

const REFUS = {
  acteur_non_authentifie: ['refus.auth', 'Connexion au serveur requise.'],
  pas_dans_un_logement: ['refus.pasLogement', 'Vous n\'êtes pas dans un appartement populaire.'],
  reserve_titulaire: ['refus.titulaire', 'Réservé au titulaire du bail.'],
  premium_indisponible_ici: ['refus.premiumIci', 'L\'option premium n\'est pas encore disponible pour ce logement.'],
  deja_premium: ['refus.dejaPremium', 'L\'option premium est déjà active ici.'],
  coloc_grand_seulement: ['refus.grand', 'La colocation n\'existe que dans les grands appartements.'],
  deja_un_colocataire: ['refus.dejaColoc', 'Il y a déjà un colocataire.'],
  personnage_introuvable: ['refus.introuvable', 'Aucun personnage de ce nom.'],
  pas_soi_meme: ['refus.soiMeme', 'Vous ne pouvez pas vous désigner vous-même.'],
  deja_conjoint: ['refus.conjoint', 'Votre conjoint a déjà la jouissance de l\'appartement.'],
  deja_colocataire_ailleurs: ['refus.ailleurs', 'Ce personnage est déjà colocataire ailleurs.'],
  chambre_2_occupee: ['refus.chambre2', 'Désinstallez d\'abord le matériel de la deuxième chambre : elle reviendra au colocataire.'],
  aucun_colocataire: ['refus.aucunColoc', 'Il n\'y a pas de colocataire.'],
  aucune_colocation: ['refus.aucuneColoc', 'Vous n\'êtes colocataire nulle part.'],
  aucune_reprise: ['refus.aucuneReprise', 'Aucune offre de reprise en cours.'],
  local_occupe: ['refus.occupe', 'Le logement a déjà été attribué.'],
  pa_insuffisants: ['refus.pa', 'Pas assez de PA.'],
  reserve_colocataire: ['refus.colocataire', 'Réservé au colocataire.'],
  demande_en_cours: ['refus.demandeEnCours', 'Une demande d\'option premium attend déjà la réponse du titulaire.'],
  aucune_demande: ['refus.aucuneDemande', 'Aucune demande d\'option premium en attente.'],
  demande_caduque: ['refus.demandeCaduque', 'La demande est tombée : son auteur n\'est plus colocataire.'],
  aucun_titulaire: ['refus.aucunTitulaire', 'Ce logement n\'a pas de titulaire.']
};
function refus(r) {
  const m = r && REFUS[r.raison];
  if (m) return texteAppart(m[0], m[1]);
  if (r && r.raison && typeof signalerRefusCout === 'function' && /pa|cout|fonds/.test(r.raison)) return texteAppart('refus.pa', 'Pas assez de PA.');
  return texteAppart('refus.serveur', 'Le serveur a refusé ({r}).', { r: esc((r && r.raison) || 'sans réponse') });
}

// ---------- Modale
function modale(titre, html) {
  const t = document.getElementById('postes-modal-title');
  const b = document.getElementById('postes-body');
  if (!t || !b) return;
  t.textContent = titre;
  b.innerHTML = '<div class="cpj-dialogue" style="padding:1rem">' + html + '</div>';
  document.getElementById('modal-postes')?.classList.add('open');
}
function fermer() { document.getElementById('modal-postes')?.classList.remove('open'); }
function bouton(onclick, libelle, primaire) {
  return '<button type="button" class="cpj-touche' + (primaire ? ' cpj-primaire' : '') + '" onclick="' + onclick + '">' + libelle + '</button>';
}
function titre(t) { return '<div class="cpj-titre" style="margin-top:.8rem">' + t + '</div>'; }
function note(t) { return '<p class="cpj-note">' + t + '</p>'; }

// ---------- Appartements premium d'un immeuble (onglets des chambres)
const PREMIUM = {};   // 'pays|ville|batiment' -> Set des appartements premium (ou 'chargement')
const CHAMBRES = {};  // 'pays|ville|batiment' -> { appartement: nombre de chambres } (dit par le serveur)
function cleImmeuble(bid) { return (state.country || '') + '|' + (state.currentCity || '') + '|' + bid; }
// Tout immeuble qui contient un logement populaire peut avoir des chambres (décision de Fred du 13/11 :
// l'option premium vaut aussi pour les logements construits en cours de partie).
function immeubleAChambres(bid) {
  const b = typeof BUILDINGS !== 'undefined' ? BUILDINGS[bid] : null;
  return !!(b && Object.entries(b.rooms || {}).some(([id, r]) => r && (r.chambreLogement
    || (r.locationData && r.locationData.logementSocial) || id.indexOf('lot_dyn_') === 0)));
}
// Logements créés à la volée (lots des terrains, immeubles des mairies de Sovarka) : leurs chambres
// n'existent pas dans data.js. On les ajoute pour les appartements dont le serveur dit qu'ils sont
// premium, avec le nombre de chambres qu'il donne. Image : celle de l'appartement, en attendant mieux.
function assurerChambres(bid) {
  const b = typeof BUILDINGS !== 'undefined' ? BUILDINGS[bid] : null;
  const n = CHAMBRES[cleImmeuble(bid)];
  if (!b || !b.rooms || !n) return;
  Object.entries(n).forEach(([base, total]) => {
    const r = b.rooms[base];
    if (!r || r.chambreLogement) return;
    for (let k = 1; k <= (Number(total) === 2 ? 2 : 1); k++) {
      const id = base + '_chambre_' + k;
      if (b.rooms[id]) continue;
      b.rooms[id] = {
        name: Number(total) === 2 ? 'Chambre ' + k : 'Chambre',
        desc: 'Une chambre de l\'appartement. On y dort, on y range son matériel ; sa porte peut recevoir une serrure.',
        imageBg: r.imageBg, imageUrl: r.imageUrl, persons: [], chambreLogement: true, baseLogement: base, _chambreDyn: true,
        orders: [{ fn: 'gerer_logement_social', label: 'Mon logement', pa: 0, cost: 0, type: 'legal', icon: 'ti-home-cog', successRate: 100,
          desc: 'Voir l\'appartement, son option premium, sa colocation et ses décors.' }]
      };
    }
  });
}
async function chargerPremium(bid, force) {
  const cle = cleImmeuble(bid);
  if (!force && PREMIUM[cle]) return;
  PREMIUM[cle] = PREMIUM[cle] instanceof Set ? PREMIUM[cle] : 'chargement';
  let rows = [];
  try {
    rows = await sbGet('logements_premium', 'pays=eq.' + encodeURIComponent(state.country) + '&ville=eq.' + encodeURIComponent(state.currentCity)
      + '&batiment=eq.' + encodeURIComponent(bid) + '&select=piece,chambres');
  } catch (e) { rows = []; }
  PREMIUM[cle] = new Set((rows || []).map(r => r.piece));
  CHAMBRES[cle] = {};
  (rows || []).forEach(r => { CHAMBRES[cle][r.piece] = r.chambres || (/^grand_/.test(r.piece) ? 2 : 1); });
  assurerChambres(bid);
  if (state.currentBuilding === bid && typeof renderOngletsPieces === 'function') renderOngletsPieces(bid, state.currentRoom);
}
// Une chambre n'a d'onglet que dans un appartement premium, et seulement quand on est dedans.
function chambreVisible(bid, roomId, room, actif) {
  if (!room || !room.chambreLogement) return true;
  const set = PREMIUM[cleImmeuble(bid)];
  if (!(set instanceof Set) || !set.has(room.baseLogement)) return false;
  const ici = actif || state.currentRoom || '';
  return ici === room.baseLogement || ici.indexOf(room.baseLogement + '_chambre_') === 0;
}
function rafraichirOnglets(bid, roomId) {
  if (!immeubleAChambres(bid)) return;
  if (!(PREMIUM[cleImmeuble(bid)] instanceof Set)) { chargerPremium(bid); return; }
  assurerChambres(bid);
  if (typeof renderOngletsPieces === 'function') renderOngletsPieces(bid, roomId);
}

// ---------- Décor affiché d'une pièce
function piecePopulaire(bid, roomId) {
  const b = typeof BUILDINGS !== 'undefined' ? BUILDINGS[bid] : null;
  const r = b && b.rooms && b.rooms[roomId];
  return !!(r && (r.chambreLogement || (r.locationData && r.locationData.logementSocial)));
}
function appliquerDecor(pieceImg, bid, roomId) {
  if (!pieceImg || !piecePopulaire(bid, roomId) || typeof SUPABASE_URL === 'undefined') return;
  const cle = state.country + '|' + state.currentCity + '|' + bid + '|' + roomId;
  fetch(SUPABASE_URL + '/rest/v1/logements_decors?cle=eq.' + encodeURIComponent(cle) + '&retiree_le=is.null&select=image_path',
    { headers: typeof sbEnTetes === 'function' ? sbEnTetes() : {} })
    .then(r => r.ok ? r.json() : [])
    .then(rows => {
      const path = rows && rows[0] && rows[0].image_path;
      if (!path || state.currentBuilding !== bid || state.currentRoom !== roomId) return;
      pieceImg.setAttribute('data-commerce-decor', '1');
      pieceImg.style.backgroundImage = 'url("' + SUPABASE_URL + '/storage/v1/object/public/commerce-decors/' + encodeURIComponent(path) + '")';
    }).catch(() => {});
}

// ---------- Fenêtre « Mon logement »
let ETAT = null;
const ROLES = {
  titulaire: ['role.titulaire', 'Vous êtes titulaire du bail.'],
  conjoint: ['role.conjoint', 'Vous êtes marié(e) au titulaire : vous avez la jouissance complète de l\'appartement.'],
  colocataire: ['role.colocataire', 'Vous êtes colocataire : vous avez la jouissance légale de l\'appartement.'],
  reprise: ['role.reprise', 'Le titulaire est parti : en tant que colocataire, vous êtes prioritaire pour reprendre le bail.']
};
function nomPiece(p) {
  if (!p.chambre) return texteAppart('piece.salon', 'Salon');
  const n = ETAT && ETAT.logement && ETAT.logement.type === 'grand';
  return n ? texteAppart('piece.chambreN', 'Chambre {n}', { n: p.chambre }) : texteAppart('piece.chambre', 'Chambre');
}

async function ouvrirMonLogement() {
  modale(texteAppart('titre', 'Mon logement'), note('…'));
  const r = await sbRpc('logement_etat', {}).catch(() => null);
  if (!r || r.ok !== true) { modale(texteAppart('titre', 'Mon logement'), note(esc(refus(r)))); return; }
  ETAT = r;
  const l = r.logement || {};
  const premium = l.premium === true;
  let h = '<p><strong>' + esc(l.label) + '</strong> — ' + (l.type === 'grand' ? texteAppart('grand', 'grand appartement') : texteAppart('petit', 'petit appartement')) + '</p>';
  h += note(r.role && ROLES[r.role] ? texteAppart(ROLES[r.role][0], ROLES[r.role][1])
    : (l.titulaire ? texteAppart('role.visiteur', 'Vous êtes chez {nom}.', { nom: esc(l.titulaire) }) : texteAppart('role.libre', 'Ce logement n\'est pas attribué. Les demandes se déposent à la mairie.')));

  // Reprise du bail par le colocataire (48 h).
  if (r.reprise_expire_le) {
    h += titre(texteAppart('reprise.titre', 'Reprendre le bail'));
    h += note(texteAppart('reprise.note', 'Le bail passerait à votre nom, au même loyer et avec la même option premium. Offre valable jusqu\'au {date}. Si vous refusez, vous aurez encore 48 h pour partir avec votre matériel.',
      { date: esc(new Date(r.reprise_expire_le).toLocaleString(undefined, { timeZone: 'Europe/Paris', day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit' })) }));
    h += '<div style="display:flex;gap:.5rem">' + bouton('logementReprendre(true)', texteAppart('reprise.accepter', 'Reprendre le bail'), true) + bouton('logementReprendre(false)', texteAppart('reprise.refuser', 'Refuser')) + '</div>';
  }

  // Sommeil : rappel de la règle (le serveur décide).
  h += titre(texteAppart('sommeil.titre', 'Sommeil'));
  h += note(premium ? texteAppart('sommeil.premium', 'Le titulaire, son conjoint et le colocataire gagnent +1 PA en dormant dans une chambre. Dormir au salon ne donne pas ce bonus.')
    : texteAppart('sommeil.gratuit', 'Le titulaire, son conjoint et le colocataire gagnent +1 PA en dormant dans l\'appartement.'));

  // Bail (titulaire, dans la pièce principale).
  if (r.role === 'titulaire' && (l.chambre || 0) === 0 && typeof ouvrirModalGererLocal === 'function') {
    h += '<div style="margin-top:.5rem">' + bouton('fermerMonLogement();ouvrirModalGererLocal()', texteAppart('bail', 'Conditions du bail')) + '</div>';
  }

  // Option premium.
  h += titre(texteAppart('premium.titre', 'Option premium'));
  if (premium) {
    h += note(texteAppart('premium.active', 'Active : un salon et {n} chambre(s) séparée(s), des décors par IA et plus d\'emplacements de matériel (3 au salon, 6 par chambre). Elle reste attachée à l\'appartement.',
      { n: l.type === 'grand' ? 2 : 1 }));
  } else if (!l.premium_possible) {
    h += note(texteAppart('premium.indispo', 'Pas encore disponible pour ce logement.'));
  } else {
    const dem = r.premium_demande;
    const dateDem = dem ? new Date(dem.expire_le).toLocaleString(undefined, { timeZone: 'Europe/Paris', day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit' }) : '';
    h += note(texteAppart('premium.offre', 'Purement cosmétique, sans aucun avantage d\'indices ni de PA : {piece}, des décors par IA et des emplacements de matériel répartis par pièce. Attachée à l\'appartement : celui qui part la perd, le suivant en hérite. Gratuite pendant la bêta.',
      { piece: l.type === 'grand' ? texteAppart('premium.piecesGrand', 'un salon et deux chambres séparées') : texteAppart('premium.piecesPetit', 'un salon et une chambre séparée') }));
    if (dem && r.role === 'titulaire') {
      h += note(texteAppart('premium.demandeRecue', '{nom}, votre colocataire, demande l\'option premium. Répondez avant le {date} ; sans réponse, la demande tombe.', { nom: esc(dem.colocataire), date: esc(dateDem) }));
      h += '<div style="display:flex;gap:.5rem;flex-wrap:wrap">' + bouton('logementPremiumDemandeRepondre(' + JSON.stringify(l.bail).replace(/"/g, '&quot;') + ',true)', texteAppart('premium.accepter', 'Accepter l\'option premium'), true)
        + bouton('logementPremiumDemandeRepondre(' + JSON.stringify(l.bail).replace(/"/g, '&quot;') + ',false)', texteAppart('premium.refuser', 'Refuser')) + '</div>';
    } else if (dem && r.role === 'colocataire') {
      h += note(texteAppart('premium.demandeEnvoyee', 'Demande envoyée à {nom}, titulaire du bail : en attente de sa réponse, jusqu\'au {date}.', { nom: esc(l.titulaire || ''), date: esc(dateDem) }));
    } else if (r.role === 'titulaire' || r.role === 'conjoint') {
      h += bouton('logementPremiumActiver()', texteAppart('premium.activer', 'Activer l\'option premium'), true);
    } else if (r.role === 'colocataire') {
      h += note(texteAppart('premium.colocNote', 'En tant que colocataire, vous pouvez la demander, mais c\'est le titulaire du bail, {nom}, qui décide : il recevra un courrier et aura 48 h pour accepter ou refuser.', { nom: esc(l.titulaire || '') }));
      h += bouton('logementPremiumDemanderConfirmer()', texteAppart('premium.demander', 'Demander l\'option premium'), true);
    }
  }

  // Colocation.
  h += titre(texteAppart('coloc.titre', 'Colocation'));
  if (l.type !== 'grand') {
    h += note(texteAppart('coloc.grand', 'La colocation n\'existe que dans les grands appartements.'));
  } else if (l.colocataire) {
    h += note(texteAppart('coloc.actuel', 'Colocataire : {nom}. Le loyer reste au nom du titulaire ; le partage se règle entre vous.', { nom: esc(l.colocataire) }));
    if (r.role === 'titulaire') h += bouton('logementColocRetirer()', texteAppart('coloc.retirer', 'Mettre fin à la colocation (2 PA)'));
    if (r.role === 'colocataire') h += bouton('logementColocPartir()', texteAppart('coloc.partir', 'Quitter la colocation'));
  } else if (r.role === 'titulaire') {
    h += note(texteAppart('coloc.offre', 'Désignez un seul colocataire : il aura la jouissance légale de l\'appartement (sommeil +1 PA, serrure, matériel{chambre}). Le loyer reste à votre nom.',
      { chambre: premium ? texteAppart('coloc.chambre2', ', la deuxième chambre') : '' }));
    h += '<input id="logement-coloc-nom" class="cpj-champ" type="text" maxlength="80" placeholder="' + esc(texteAppart('coloc.placeholder', 'Nom du personnage')) + '" style="width:100%;margin:.3rem 0">';
    h += bouton('logementColocDesigner()', texteAppart('coloc.designer', 'Désigner (2 PA)'), true);
  } else {
    h += note(texteAppart('coloc.aucun', 'Pas de colocataire.'));
  }
  if (r.ma_colocation && r.role !== 'colocataire') {
    h += note(texteAppart('coloc.ailleurs', 'Vous êtes colocataire de {lieu} (bail de {nom}).', { lieu: esc(r.ma_colocation.label), nom: esc(r.ma_colocation.titulaire) }));
    h += bouton('logementColocPartir()', texteAppart('coloc.partir', 'Quitter la colocation'));
  }

  // Décors par IA (premium).
  if (premium) {
    h += titre(texteAppart('decor.titre', 'Décors'));
    h += note(texteAppart('decor.note', 'Une génération et deux retouches par pièce, gratuites pendant la bêta. Pour décorer une pièce, soyez dedans.'));
    (r.pieces || []).forEach(p => {
      const ici = p.piece === state.currentRoom;
      h += '<div style="display:flex;justify-content:space-between;align-items:center;gap:.6rem;margin:.3rem 0"><span>' + esc(nomPiece(p))
        + (p.decor ? ' <span class="cpj-note">— ' + texteAppart('decor.fait', 'décorée') + '</span>' : '') + '</span>'
        + (p.peut_decorer ? (ici ? bouton('logementOuvrirAtelier()', texteAppart('decor.decorer', 'Décorer')) : '<span class="cpj-note">' + texteAppart('decor.allez', 'rendez-vous dans la pièce') + '</span>')
          : '<span class="cpj-note">' + texteAppart('decor.pasVous', 'pas à vous') + '</span>') + '</div>';
    });
  }
  modale(texteAppart('titre', 'Mon logement'), h);
}

async function appel(fn, args, succes) {
  const r = await sbRpc(fn, args || {}).catch(() => null);
  if (!r || r.ok !== true) { showToast(texteAppart('refuse', 'Refusé'), refus(r), false); return null; }
  if (typeof r.pa === 'number') { state.pa = r.pa; if (typeof updateUI === 'function') updateUI(); }
  if (succes) showToast(succes[0], succes[1], true);
  return r;
}
async function logementPremiumActiver() {
  const r = await appel('logement_premium_activer', {}, [texteAppart('premium.ok', 'Option premium activée'), texteAppart('premium.okNote', 'Les portes des chambres s\'ouvrent depuis le salon.')]);
  if (!r) return;
  if (typeof addJournalEntry === 'function') addJournalEntry('Option premium activée pour votre appartement.', 'event-good');
  await chargerPremium(state.currentBuilding, true);
  ouvrirMonLogement();
}
// Le colocataire demande l'option : confirmation qui rappelle explicitement que le titulaire doit accepter.
function logementPremiumDemanderConfirmer() {
  const tit = ETAT && ETAT.logement && ETAT.logement.titulaire;
  modale(texteAppart('premium.demandeTitre', 'Demander l\'option premium'),
    note(texteAppart('premium.demandeConfirme', 'Votre demande sera envoyée à {nom}, titulaire du bail. L\'option ne sera activée que s\'il l\'accepte. Il a 48 h pour répondre ; sans réponse, la demande tombe.', { nom: esc(tit || '') }))
    + '<div style="display:flex;gap:.5rem;flex-wrap:wrap">' + bouton('logementPremiumDemander()', texteAppart('premium.envoyer', 'Envoyer la demande au titulaire'), true)
    + bouton('ouvrirMonLogement()', texteAppart('atelier.retour', 'Retour')) + '</div>');
}
async function logementPremiumDemander() {
  const r = await appel('logement_premium_demander', {}, [texteAppart('premium.demandeOkT', 'Demande envoyée'),
    texteAppart('premium.demandeOk', 'Le titulaire du bail a reçu votre demande : l\'option ne sera active que s\'il l\'accepte.')]);
  if (!r) return;
  if (typeof addJournalEntry === 'function') addJournalEntry('Option premium demandée au titulaire du bail (' + r.titulaire + ').', 'event-info');
  ouvrirMonLogement();
}
// Réponse du titulaire : depuis le bouton du courrier (où qu'il soit) ou depuis « Mon logement ».
async function logementPremiumDemandeRepondre(bail, accepter) {
  const oui = accepter === true || accepter === 'true';
  const r = await appel('logement_premium_demande_repondre', { p_bail: String(bail || ''), p_accepter: oui },
    oui ? [texteAppart('premium.ok', 'Option premium activée'), texteAppart('premium.accepteNote', 'Votre colocataire est prévenu ; les portes des chambres s\'ouvrent depuis le salon.')]
        : [texteAppart('premium.refusT', 'Demande refusée'), texteAppart('premium.refusNote', 'Votre colocataire est prévenu.')]);
  if (!r) return;
  if (typeof addJournalEntry === 'function') addJournalEntry(oui ? 'Option premium acceptée pour votre appartement.' : 'Demande d\'option premium refusée.', oui ? 'event-good' : 'event-info');
  if (oui && r.batiment && r.batiment === state.currentBuilding) await chargerPremium(r.batiment, true);
  if (document.getElementById('modal-postes')?.classList.contains('open') && ETAT && document.getElementById('postes-modal-title')?.textContent === texteAppart('titre', 'Mon logement')) ouvrirMonLogement();
}
async function logementColocDesigner() {
  const nom = (document.getElementById('logement-coloc-nom')?.value || '').trim();
  if (!nom) return;
  const r = await appel('logement_coloc_designer', { p_nom: nom }, [texteAppart('coloc.okT', 'Colocataire désigné'), texteAppart('coloc.ok', '{nom} a reçu un courrier.', { nom: esc(nom) })]);
  if (!r) return;
  addJournalEntry('Colocation : ' + nom + ' devient votre colocataire.', 'event-good');
  ouvrirMonLogement();
}
async function logementColocRetirer() {
  const r = await appel('logement_coloc_retirer', {}, [texteAppart('coloc.finT', 'Colocation terminée'), texteAppart('coloc.fin', 'Votre colocataire a 48 h pour désinstaller son matériel.')]);
  if (!r) return;
  addJournalEntry('Fin de la colocation avec ' + r.colocataire + '.', 'event-info');
  ouvrirMonLogement();
}
async function logementColocPartir() {
  const r = await appel('logement_coloc_partir', {}, [texteAppart('coloc.partiT', 'Colocation quittée'), texteAppart('coloc.parti', 'Pensez à désinstaller votre matériel sous 48 h.')]);
  if (!r) return;
  addJournalEntry('Vous avez quitté votre colocation.', 'event-info');
  ouvrirMonLogement();
}
async function logementReprendre(accepter) {
  const r = await appel('logement_reprendre_bail', { p_accepter: !!accepter },
    accepter ? [texteAppart('reprise.okT', 'Bail repris'), texteAppart('reprise.ok', 'Le bail est désormais à votre nom.')]
             : [texteAppart('reprise.refusT', 'Offre refusée'), texteAppart('reprise.refus', 'Vous avez 48 h pour partir avec votre matériel.')]);
  if (!r) return;
  if (accepter && typeof chargerLocations === 'function') await chargerLocations().catch(() => {});
  ouvrirMonLogement();
}

// ---------- Atelier de décoration (même principe que l'atelier du Commerce Premium)
let ATELIER = { piece: null, preview: null, retouches: 0, enCours: false };
async function atelierAppel(action, extra) {
  if (typeof rpAuthAssurerSession === 'function') await rpAuthAssurerSession();
  const jeton = typeof rpAuthJeton === 'function' ? rpAuthJeton() : null;
  if (!jeton) throw new Error(texteAppart('atelier.connexion', 'Connexion requise.'));
  const res = await fetch(SUPABASE_URL + '/functions/v1/logement-decoration', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', apikey: SUPABASE_ANON, Authorization: 'Bearer ' + jeton },
    body: JSON.stringify(Object.assign({ pays: state.country, ville: state.currentCity, batiment: state.currentBuilding, piece: ATELIER.piece, action }, extra || {}))
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok || !data.ok) throw new Error(data.error || texteAppart('atelier.echec', 'La génération a échoué.'));
  return data;
}
function fichierBase64(file) {
  if (!['image/png', 'image/jpeg', 'image/webp'].includes(file.type) || file.size > 5242880)
    return Promise.reject(new Error(texteAppart('atelier.format', 'Images PNG, JPEG ou WebP de 5 Mo maximum.')));
  return new Promise((ok, ko) => { const r = new FileReader(); r.onerror = () => ko(new Error(texteAppart('atelier.lecture', 'Lecture impossible.'))); r.onload = () => ok(String(r.result).split(',')[1]); r.readAsDataURL(file); });
}
function urlDecor(path) { return SUPABASE_URL + '/storage/v1/object/public/commerce-decors/' + encodeURIComponent(path); }
function atelierMessage(m) { const el = document.getElementById('logement-atelier-retour'); if (el) el.textContent = m; }
async function logementOuvrirAtelier() {
  ATELIER = { piece: state.currentRoom, preview: null, retouches: 0, enCours: false };
  try {
    const rows = await sbGet('logements_decors', 'cle=eq.' + encodeURIComponent(state.country + '|' + state.currentCity + '|' + state.currentBuilding + '|' + state.currentRoom) + '&select=preview_path,retouches');
    if (rows && rows[0] && rows[0].preview_path) { ATELIER.preview = rows[0].preview_path; ATELIER.retouches = Number(rows[0].retouches) || 0; }
  } catch (e) {}
  let h = note(texteAppart('atelier.intro', 'Décrivez l\'ambiance souhaitée : les murs, portes et fenêtres de la pièce sont conservés. Une génération et deux retouches, gratuites pendant la bêta (ensuite 0,99 € la nouvelle génération).'));
  h += '<textarea id="logement-atelier-demande" class="cpj-champ" maxlength="1500" rows="4" style="width:100%" placeholder="' + esc(texteAppart('atelier.placeholder', 'Ambiance, mobilier, couleurs, textiles, éclairage…')) + '"></textarea>';
  if (!ATELIER.preview) {
    h += '<label for="logement-atelier-sources" class="cpj-note" style="display:block;margin-top:.5rem">' + texteAppart('atelier.sources', 'Images de référence (facultatif, 5 maximum, 5 Mo chacune)') + '</label>';
    h += '<input id="logement-atelier-sources" type="file" accept="image/png,image/jpeg,image/webp" multiple style="display:block;width:100%;margin:.3rem 0">';
    h += '<label class="cpj-note" style="display:flex;gap:.5rem;align-items:flex-start"><input type="checkbox" id="logement-atelier-droits" style="margin-top:.25rem">'
      + '<span>' + texteAppart('atelier.droits', 'Je confirme disposer des droits nécessaires sur les images fournies, y compris les autorisations des personnes représentées, et accepte leur conservation privée pour la traçabilité.') + '</span></label>';
  }
  h += '<div id="logement-atelier-image" style="margin:.6rem 0;min-height:80px;display:flex;align-items:center;justify-content:center" class="cpj-note">' + (ATELIER.preview ? '<img src="' + esc(urlDecor(ATELIER.preview)) + '" style="width:100%;max-height:320px;object-fit:contain">' : texteAppart('atelier.vide', 'Votre décor apparaîtra ici.')) + '</div>';
  h += '<p id="logement-atelier-retour" class="cpj-note" aria-live="polite"></p>';
  h += '<div style="display:flex;flex-wrap:wrap;gap:.5rem">'
    + bouton('logementAtelierGenerer()', ATELIER.preview ? texteAppart('atelier.retoucher', 'Demander une retouche ({n}/2)', { n: ATELIER.retouches }) : texteAppart('atelier.generer', 'Générer'), true)
    + (ATELIER.preview ? bouton('logementAtelierValider()', texteAppart('atelier.valider', 'Valider ce décor')) : '')
    + (ATELIER.preview ? bouton('logementAtelierRecommencer()', texteAppart('atelier.recommencer', 'Nouvelle génération')) : '')
    + bouton('ouvrirMonLogement()', texteAppart('atelier.retour', 'Retour')) + '</div>';
  modale(texteAppart('atelier.titre', 'Décorer la pièce'), h);
}
async function logementAtelierGenerer() {
  if (ATELIER.enCours) return;
  const prompt = (document.getElementById('logement-atelier-demande')?.value || '').trim();
  if (prompt.length < 10) { atelierMessage(texteAppart('atelier.court', 'Décrivez votre souhait en quelques phrases.')); return; }
  if (ATELIER.preview && ATELIER.retouches >= 2) { atelierMessage(texteAppart('atelier.epuise', 'Vos deux retouches sont épuisées : validez ou recommencez.')); return; }
  ATELIER.enCours = true;
  atelierMessage(texteAppart('atelier.attente', 'Génération en cours, patientez…'));
  try {
    const payload = { prompt };
    if (!ATELIER.preview) {
      const files = Array.from(document.getElementById('logement-atelier-sources')?.files || []);
      if (files.length > 5) throw new Error(texteAppart('atelier.cinq', 'Cinq images maximum.'));
      if (files.length && !document.getElementById('logement-atelier-droits')?.checked) throw new Error(texteAppart('atelier.droitsRequis', 'Veuillez accepter les conditions des images fournies.'));
      await atelierAppel('clear_sources');
      for (const file of files) await atelierAppel('upload_source', { filename: file.name, mime: file.type, base64: await fichierBase64(file), consent: true });
      if (typeof commercePjDecorImageOriginale !== 'function') throw new Error(texteAppart('atelier.image', 'Image de la pièce introuvable.'));
      payload.baseImage = await commercePjDecorImageOriginale();
    }
    const r = await atelierAppel(ATELIER.preview ? 'retouch' : 'start', payload);
    ATELIER.preview = r.path; ATELIER.retouches = r.retouches || 0;
    ATELIER.enCours = false;
    await logementOuvrirAtelier();
    atelierMessage(texteAppart('atelier.pret', 'Aperçu prêt : validez-le ou demandez une retouche.'));
  } catch (e) { atelierMessage(e.message); }
  finally { ATELIER.enCours = false; }
}
async function logementAtelierValider() {
  try {
    await atelierAppel('finalize');
    showToast(texteAppart('atelier.okT', 'Décor enregistré'), texteAppart('atelier.ok', 'Il est visible de tous dans cette pièce.'), true);
    fermer();
    if (typeof renderRoom === 'function') renderRoom(); else appliquerDecor(document.getElementById('piece-image'), state.currentBuilding, state.currentRoom);
  } catch (e) { atelierMessage(e.message); }
}
async function logementAtelierRecommencer() {
  try { await atelierAppel('restart'); ATELIER.preview = null; ATELIER.retouches = 0; await logementOuvrirAtelier(); }
  catch (e) { atelierMessage(e.message); }
}

global.texteAppart = texteAppart;
global.ouvrirMonLogement = ouvrirMonLogement;
global.fermerMonLogement = fermer;
global.logementPremiumActiver = logementPremiumActiver;
global.logementColocDesigner = logementColocDesigner;
global.logementPremiumDemanderConfirmer = logementPremiumDemanderConfirmer;
global.logementPremiumDemander = logementPremiumDemander;
global.logementPremiumDemandeRepondre = logementPremiumDemandeRepondre;
global.logementColocRetirer = logementColocRetirer;
global.logementColocPartir = logementColocPartir;
global.logementReprendre = logementReprendre;
global.logementOuvrirAtelier = logementOuvrirAtelier;
global.logementAtelierGenerer = logementAtelierGenerer;
global.logementAtelierValider = logementAtelierValider;
global.logementAtelierRecommencer = logementAtelierRecommencer;
global.logementChambreVisible = chambreVisible;
global.logementRafraichirOnglets = rafraichirOnglets;
global.logementChargerPremium = chargerPremium;
global.logementAppliquerDecor = appliquerDecor;
global.RPAppartementsRefus = REFUS;
})(typeof window !== 'undefined' ? window : globalThis);
