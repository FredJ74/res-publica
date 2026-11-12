// plateau-enigme-tresor-tsars.js
// Énigme du trésor des Tsars, Novomirsk (Fred, 12/11/2026) : première énigme de la ville, gratuite.
// Étapes dans l'ordre, chaque joueur la sienne, tout est décidé par le serveur :
//   1. Salle des Origines : « Écouter le guide » (tresor_tsars_guide) ;
//   2. Galina Karpova et 3. Evgueni Sudakov : mots clés dans le dialogue (/api/chat -> tresor_tsars_parler) ;
//   4. fouille du musée présidentiel : le livre, à coup sûr (fouiller_lieux) ;
//   5. Mère Volga : donner le livre à Tatiana (tresor_tsars_donner_livre), répondre, recevoir deux gâteaux
//      (tresor_tsars_recit) ; manger un gâteau (tresor_tsars_manger : +1 PA et +10 de moral, 4 jours).
// L'écran ne fait qu'afficher ce que le serveur a décidé.

const TRESOR_TSARS_RAISONS = { pas_sur_place: 'pasSurPlace', pas_de_livre: 'pasDeLivre', pas_de_gateau: 'pasDeGateau', etape_invalide: 'refus' };

function tresorTsarsEch(t) {
  return String(t == null ? '' : t).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}
function tresorTsarsParagraphes(texte) {
  return String(texte || '').split('\n\n').map(p => '<p>' + tresorTsarsEch(p).replace(/\n/g, '<br>') + '</p>').join('');
}
function tresorTsarsRefus(titre, v) {
  const cle = TRESOR_TSARS_RAISONS[v && v.raison] || 'refus';
  if (typeof showToast === 'function') showToast(titre, texteTresor(cle), false);
}
function tresorTsarsFenetre(titre, html, rendre) {
  if (typeof sovModal === 'function') sovModal(titre, html, rendre);
  else if (typeof vehModal === 'function') vehModal(titre, html);
}
// Clé locale d'affichage seulement : rappelle qu'il reste à répondre à Tatiana si la fenêtre a été fermée.
function tresorTsarsCleReponse() { return 'hg-tresor-tsars-reponse:' + (state.char?.name || ''); }
function tresorTsarsAAvoirLivre() { return (state.inventory || []).some(o => o && o.tresorTsars === 'livre'); }
function tresorTsarsChezTatiana(buildingId, roomId) {
  return state.country === 'soviet' && state.currentCity === 'capitale' && buildingId === 'capitaine-sauvage' && roomId === 'salle_principale';
}

// 1. Le guide de la Salle des Origines.
async function tresorEcouterGuide() {
  const salle = state.currentRoom;
  const rendre = () => {
    if (state.currentRoom !== salle) return;
    tresorTsarsFenetre(texteTresor('tGuide'), '<div class="guide-musee-fiche">' + tresorTsarsParagraphes(texteTresor('guide')) + '</div>', rendre);
  };
  const v = typeof sbRpcVerdict === 'function' ? await sbRpcVerdict('tresor_tsars_guide', {}).catch(() => null) : null;
  if (v && v.ok === false && v.raison === 'pas_sur_place') { if (typeof showToast === 'function') showToast(texteTresor('tGuide'), texteTresor('refusGuide'), false); return; }
  rendre();
}

// 4. Résultat de la fouille du musée présidentiel (appelé par plateau-surveillance.js).
function tresorTsarsApresFouille(r) {
  if (!r || r.livre_tresor !== true) return false;
  if (Array.isArray(r.inventory) && typeof sbAdopterInventaireServeur === 'function') sbAdopterInventaireServeur(r);
  if (typeof renderInventory === 'function') renderInventory();
  const rendre = () => tresorTsarsFenetre(texteTresor('tTrouve'), tresorTsarsParagraphes(texteTresor('trouve')) +
    '<div style="text-align:center;margin-top:.6rem"><button class="cpj-btn cpj-btn-primary" onclick="tresorLireLivre()">' + tresorTsarsEch(texteTresor('lireLivre')) + '</button></div>', rendre);
  rendre();
  if (typeof addJournalEntry === 'function') addJournalEntry('Vous trouvez au musée présidentiel un vieux livre : « Le fabuleux trésor des Tsars ».', 'event-good');
  return true;
}

function tresorLireLivre() {
  const rendre = () => tresorTsarsFenetre(texteTresor('tBook'), '<div style="font-style:italic">' + tresorTsarsParagraphes(texteTresor('book')) + '</div>', rendre);
  rendre();
}

// 5. Donner le livre à Tatiana, puis lui répondre.
async function tresorDonnerLivre() {
  if (typeof provActe !== 'function') return;
  const v = await provActe('tresor_tsars_donner_livre', {}, 'donner');
  if (!v) return;
  if (v.ok !== true) { tresorTsarsRefus(texteTresor('tTatiana'), v); return; }
  try { localStorage.setItem(tresorTsarsCleReponse(), '1'); } catch (e) { /* stockage indisponible : la fenêtre suffit */ }
  tresorOuvrirReponse();
}

function tresorOuvrirReponse() {
  const rendre = () => tresorTsarsFenetre(texteTresor('tTatiana'),
    '<div style="font-weight:bold">' + tresorTsarsParagraphes(texteTresor('cri')) + '</div>' +
    '<textarea id="tresor-reponse" rows="3" maxlength="400" style="width:100%;box-sizing:border-box;margin-top:.5rem" placeholder="' + tresorTsarsEch(texteTresor('votreReponse')) + '"></textarea>' +
    '<div style="text-align:right;margin-top:.5rem"><button class="cpj-btn cpj-btn-primary" onclick="tresorRepondre()">' + tresorTsarsEch(texteTresor('repondre')) + '</button></div>', rendre);
  rendre();
}

async function tresorRepondre() {
  const champ = document.getElementById('tresor-reponse');
  const reponse = (champ && champ.value || '').trim();
  if (!reponse) { if (typeof showToast === 'function') showToast(texteTresor('tTatiana'), texteTresor('direQuelqueChose'), false); return; }
  if (typeof provActe !== 'function') return;
  // La réponse du joueur n'a aucun effet sur la suite (décision de Fred) : elle n'est pas transmise.
  const v = await provActe('tresor_tsars_recit', {}, 'recit');
  if (!v) return;
  if (v.ok !== true) { tresorTsarsRefus(texteTresor('tTatiana'), v); return; }
  try { localStorage.removeItem(tresorTsarsCleReponse()); } catch (e) { /* sans effet */ }
  const rendre = () => tresorTsarsFenetre(texteTresor('tTatiana'), tresorTsarsParagraphes(texteTresor('recit')), rendre);
  rendre();
  if (typeof showToast === 'function') showToast(texteTresor('tRecu'), texteTresor('recu'), true, true);
  if (typeof addJournalEntry === 'function') addJournalEntry('Tatiana Bortchova vous offre deux « Trésor des tsars ».', 'event-good');
}

// Manger un « Trésor des tsars » depuis l'inventaire.
async function tresorManger() {
  if (typeof provActe !== 'function') return;
  const v = await provActe('tresor_tsars_manger', {}, 'manger');
  if (!v) return;
  if (v.ok !== true) { tresorTsarsRefus(texteTresor('manger'), v); return; }
  document.getElementById('modal-postes')?.classList.remove('open');
  if (typeof v.moral === 'number') state.moral = v.moral;
  if (v.frais === true) {
    if (typeof showToast === 'function') showToast(texteTresor('tMange'), texteTresor('mange'), true, true);
    if (typeof addJournalEntry === 'function') addJournalEntry('Vous savourez un « Trésor des tsars » : +1 PA, +10 de moral.', 'event-good');
  } else {
    if (typeof showToast === 'function') showToast(texteTresor('tTourne'), texteTresor('tourne'), false);
    if (typeof addJournalEntry === 'function') addJournalEntry('Votre « Trésor des tsars » avait tourné : -1 PA.', 'event-bad');
  }
  if (typeof updateUI === 'function') updateUI();
}

// Description affichée d'un objet de l'énigme, dans la langue du joueur.
function texteTresorTsarsObjet(item) {
  if (!item || !item.tresorTsars || typeof texteTresor !== 'function') return null;
  return item.tresorTsars === 'livre' ? texteTresor('descLivre') : item.tresorTsars === 'gateau' ? texteTresor('descGateau') : null;
}
// Boutons de l'inventaire pour les objets de l'énigme (deux affichages de l'inventaire les utilisent).
function boutonsTresorTsarsObjet(item, style) {
  if (!item || typeof texteTresor !== 'function') return '';
  if (item.tresorTsars === 'livre') return '<button onclick="tresorLireLivre()" style="' + style + '"><i class="ti ti-book"></i> ' + tresorTsarsEch(texteTresor('lireLivre')) + '</button>';
  if (item.stackKey === 'tresor-tsars') return '<button onclick="tresorManger()" style="' + style + '"><i class="ti ti-cake"></i> ' + tresorTsarsEch(texteTresor('manger')) + '</button>';
  return '';
}

// Ordres de la salle de la Mère Volga : donner le livre (le joueur l'a), ou répondre à Tatiana (fenêtre fermée).
function ordresTresorTsars(buildingId, roomId) {
  if (!tresorTsarsChezTatiana(buildingId, roomId) || typeof texteTresor !== 'function') return [];
  if (tresorTsarsAAvoirLivre()) {
    return [{ fn: 'tresor_donner_livre', label: texteTresor('donner'), pa: 0, cost: 0, type: 'legal', icon: 'ti-book', successRate: 100, desc: texteTresor('donnerDesc') }];
  }
  let attente = false;
  try { attente = localStorage.getItem(tresorTsarsCleReponse()) === '1'; } catch (e) { attente = false; }
  return attente ? [{ fn: 'tresor_repondre', label: texteTresor('repondreTatiana'), pa: 0, cost: 0, type: 'legal', icon: 'ti-message', successRate: 100, desc: texteTresor('repondreTatiana') }] : [];
}
if (typeof window !== 'undefined') {
  window.RP_ORDRES_DYNAMIQUES = window.RP_ORDRES_DYNAMIQUES || [];
  if (!window.RP_ORDRES_DYNAMIQUES.includes(ordresTresorTsars)) window.RP_ORDRES_DYNAMIQUES.push(ordresTresorTsars);
}
