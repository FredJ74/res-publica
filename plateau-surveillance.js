/* ===========================================================================
   SURVEILLANCE, FOUILLER LES LIEUX, COUINATOR 3000 (11 novembre 2026)
   ===========================================================================

   Decisions de Fred (GAME-DESIGN-EQUIPEMENTS.md, decisions 1 a 5) : une camera se
   pose dans une piece ou une vue de rue (1 PA), le proprietaire seul la voit dans
   la colonne des personnes presentes, la reprend (1 PA) ou regle la frequence de
   ses rapports (1 a 24 h). Tout PJ peut fouiller les lieux (2 PA) ; avec le
   Couinator 3000, une fouille fructueuse declenche une animation drole. Une camera
   trouvee est detruite ou emportee.

   TOUT EST DECIDE PAR LE SERVEUR (cameras_lire, camera_poser, camera_reprendre,
   camera_frequence, fouiller_lieux, camera_trouvee_traiter). Cet ecran n'affiche
   que ses reponses.
   =========================================================================== */

const SURVEILLANCE_REFUS = {
  acteur_non_authentifie: 'Votre personnage n\'est pas identifié.',
  emprisonne: 'Impossible en prison.',
  lieu_invalide: 'Il faut être dans une pièce ou dans une rue.',
  pas_de_camera: 'Vous n\'avez pas de caméra sur vous.',
  pas_ordinateur_connecte: 'Il faut d\'abord un ordinateur et une box installés dans votre bureau.',
  capacite_cameras: 'Vous avez atteint 8 caméras par ordinateur connecté : il faut un autre ordinateur et une autre box.',
  pa_insuffisants: 'Vous n\'avez pas assez de PA.',
  camera_introuvable: 'Cette caméra n\'est plus là.',
  pas_proprietaire: 'Cette caméra ne vous appartient pas.',
  pas_sur_place: 'Il faut être sur place.',
  inventaire_plein: 'Votre inventaire est plein.',
  frequence_invalide: 'Fréquence invalide (1 à 24 h).',
  camera_non_trouvee: 'Il faut d\'abord trouver cette caméra en fouillant les lieux.',
  action_invalide: 'Action invalide.'
};
function surveillanceRefus(r) {
  return (r && SURVEILLANCE_REFUS[r.raison] && texteEquip('sv.' + r.raison, SURVEILLANCE_REFUS[r.raison])) || texteEquip('refusServeur', 'Le serveur a refusé{raison}.', {raison: r && r.raison ? ' (' + r.raison + ')' : ''});
}
function surveillanceEchapper(t) {
  return (typeof escapeHtmlText === 'function') ? escapeHtmlText(String(t == null ? '' : t)) : String(t == null ? '' : t)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}
async function surveillanceRpc(nom, params) {
  if (typeof sbRpcVerdict === 'function') return sbRpcVerdict(nom, params || {}).catch(() => null);
  if (typeof sbRpc === 'function') return sbRpc(nom, params || {}).catch(() => null);
  return null;
}
// Applique l'inventaire renvoye par le serveur (meme forme que les equipements).
function surveillanceAppliquer(r) {
  if (!r) return;
  if (Array.isArray(r.inventory)) {
    state.inventory = r.inventory;
    if (r.revision != null) state.inventoryRevision = r.revision;
  }
  if (typeof r.pa === 'number' && state.char) state.char.pa = r.pa;
  if (typeof updateUI === 'function') updateUI();
}
// Nom lisible du lieu courant, pour le libelle de la camera (cosmetique, jamais une autorite).
function surveillanceLibelleLieu() {
  try {
    if (state.currentBuilding && state.currentRoom) {
      const b = (typeof getBuildingEffectif === 'function' ? getBuildingEffectif(state.currentBuilding) : null) || (typeof BUILDINGS !== 'undefined' ? BUILDINGS[state.currentBuilding] : null);
      const room = b?.rooms?.find?.(x => x.id === state.currentRoom);
      return [b?.name, room?.name].filter(Boolean).join(' — ') || state.currentBuilding;
    }
    return document.getElementById('rue-titre')?.textContent?.trim() || texteEquip('ruePar', 'Dans la rue');
  } catch (e) { return texteEquip('lieuSurveille', 'Lieu surveillé'); }
}

let RP_SURVEILLANCE_VUE = 0;
// Appele apres le rendu de la colonne des personnes presentes (piece ou rue).
async function surveillanceAfficherIci(targetId) {
  const vue = ++RP_SURVEILLANCE_VUE;
  const r = await surveillanceRpc('cameras_lire', {});
  if (vue !== RP_SURVEILLANCE_VUE) return;
  const liste = document.getElementById(targetId || 'persons-list');
  if (!liste || !r || r.ok !== true || !r.lieu_valide) return;
  liste.querySelectorAll('.surveillance-bloc').forEach(n => n.remove());
  const bloc = document.createElement('div');
  bloc.className = 'surveillance-bloc';
  let h = '';
  for (const c of (r.ici || [])) {
    const opts = [1, 2, 3, 4, 6, 8, 12, 24].map(n => '<option value="' + n + '"' + (n === c.frequence ? ' selected' : '') + '>' + n + ' h</option>').join('');
    h += '<div class="person-card" style="border-left:2px solid #5d7085">' +
      '<div class="person-avatar"><i class="ti ti-device-cctv" style="font-size:.8rem;color:#92b5db"></i></div>' +
      '<div style="flex:1;min-width:0"><div class="person-name">' + texteEquip('votreCamera', 'Votre caméra') + '</div>' +
      '<div class="person-role">' + (c.operationnelle ? texteEquip('rapportsToutes', 'Rapports toutes les ') : texteEquip('inoperante', 'Inopérante (ordinateur ou box manquant) — ')) +
      '<select onchange="surveillanceFrequence(\'' + surveillanceEchapper(c.id) + '\', this.value)" style="font-size:.78rem;background:#151a21;color:#dce4ee;border:1px solid #5d7085">' + opts + '</select></div>' +
      '<button type="button" onclick="surveillanceReprendre(\'' + surveillanceEchapper(c.id) + '\')" style="margin-top:.25rem;font-size:.78rem;background:none;border:1px solid #5d7085;color:#92b5db;cursor:pointer;padding:.15rem .4rem">' + texteEquip('reprendre1', 'Reprendre (1 PA)') + '</button>' +
      '</div></div>';
  }
  if (r.cameras_inventaire > 0) {
    h += '<button type="button" onclick="surveillancePoser()" style="width:100%;padding:.45rem;margin:.35rem 0;border:1px solid #5d7085;background:#151a21;color:#dce4ee;font-size:.85rem;cursor:pointer">' + texteEquip('poserIci', '📷 Poser une caméra ici (1 PA)') + '</button>';
  }
  // « Fouiller les lieux » et « Voler du matériel installé » ne sont plus dans cette colonne : un seul
  // ordre vert « Fouiller ou voler », tout en bas des ordres de la piece ou de la rue (Fred, 11/11/2026).
  bloc.innerHTML = h;
  liste.appendChild(bloc);
}
function surveillanceRafraichir() {
  const rue = document.getElementById('persons-sidebar-rue');
  surveillanceAfficherIci(rue && rue.style.display !== 'none' ? 'persons-list-rue' : 'persons-list');
}

async function surveillancePoser() {
  const r = await surveillanceRpc('camera_poser', { p_libelle: surveillanceLibelleLieu() });
  if (!r || r.ok !== true) { showToast(texteEquip('camNonPosee', 'Caméra non posée'), surveillanceRefus(r), false); return; }
  surveillanceAppliquer(r);
  if (r.repere) {
    showToast(texteEquip('repere', 'Repéré !'), texteEquip('surprisCam', 'Vous avez été surpris en posant la caméra : elle est saisie et vous êtes arrêté.'), false);
    if (typeof rafraichirEtatCriminel === 'function') rafraichirEtatCriminel(r);
    if (typeof chargerPersonnage === 'function') chargerPersonnage();
    return;
  }
  showToast(texteEquip('camPosee', 'Caméra posée'), r.legale ? texteEquip('camLegale', 'Votre caméra surveille ce lieu, en toute légalité.') : texteEquip('camIllegale', 'Votre caméra surveille ce lieu. Personne ne vous a vu… cette fois.'), true);
  surveillanceRafraichir();
}
async function surveillanceReprendre(id) {
  const r = await surveillanceRpc('camera_reprendre', { p_id: id });
  if (!r || r.ok !== true) { showToast(texteEquip('camNonReprise', 'Caméra non reprise'), surveillanceRefus(r), false); return; }
  surveillanceAppliquer(r);
  showToast(texteEquip('camReprise', 'Caméra reprise'), texteEquip('retourInventaire', 'Elle est de nouveau dans votre inventaire.'), true);
  surveillanceRafraichir();
}
async function surveillanceFrequence(id, heures) {
  const r = await surveillanceRpc('camera_frequence', { p_id: id, p_heures: parseInt(heures, 10) });
  if (!r || r.ok !== true) { showToast(texteEquip('reglageRefuse', 'Réglage refusé'), surveillanceRefus(r), false); return; }
  showToast(texteEquip('reglageOk', 'Réglage enregistré'), texteEquip('rapportToutes', 'Rapport toutes les {n} h.', {n: r.frequence}), true);
}

async function surveillanceFouiller() {
  const r = await surveillanceRpc('fouiller_lieux', {});
  if (!r || r.ok !== true) { showToast(texteEquip('fouilleImpossible', 'Fouille impossible'), surveillanceRefus(r), false); return; }
  surveillanceAppliquer(r);
  const trouvees = Array.isArray(r.trouvees) ? r.trouvees : [];
  // Énigme du trésor des Tsars (12/11/2026) : au musée présidentiel de Novomirsk, le serveur peut joindre le livre.
  if (r.livre_tresor === true && typeof tresorTsarsApresFouille === 'function' && tresorTsarsApresFouille(r) && !trouvees.length) return;
  if (!trouvees.length) {
    showToast(texteEquip('fouilleFinie', 'Fouille terminée'), r.couinator ? texteEquip('couinMuet', 'Le Couinator reste muet. Rien ici.') : texteEquip('rienSuspect', 'Vous ne trouvez rien de suspect.'), true);
    return;
  }
  surveillanceFenetreTrouvaille(trouvees, r.couinator);
}
function surveillanceFenetreTrouvaille(trouvees, couinator) {
  const fond = document.createElement('div');
  fond.className = 'surveillance-trouvaille';
  fond.style.cssText = 'position:fixed;inset:0;z-index:2147483000;background:rgba(0,0,0,.85);display:flex;align-items:center;justify-content:center;padding:1rem';
  const lignes = trouvees.map((c, i) => '<div style="display:flex;gap:.5rem;align-items:center;justify-content:space-between;padding:.4rem 0;border-top:1px solid #2a3340">' +
    '<span>' + texteEquip('cameraN', 'Caméra n° {n}', {n: i + 1}) + '</span><span>' +
    '<button type="button" data-cam="' + surveillanceEchapper(c.id) + '" data-action="detruire" style="margin-right:.3rem;background:#2a1414;color:#f0c0c0;border:1px solid #7a3a3a;padding:.3rem .6rem;cursor:pointer">' + texteEquip('detruire', 'Détruire') + '</button>' +
    '<button type="button" data-cam="' + surveillanceEchapper(c.id) + '" data-action="emporter" style="background:#14202a;color:#c0dcf0;border:1px solid #3a5a7a;padding:.3rem .6rem;cursor:pointer">' + texteEquip('emporter', 'Emporter') + '</button>' +
    '</span></div>').join('');
  fond.innerHTML = '<div style="max-width:420px;width:100%;background:#151a21;color:#dce4ee;border:1px solid #5d7085;border-radius:10px;padding:1rem;text-align:center">' +
    (couinator ? '<style>@keyframes couinCouin{0%,100%{transform:rotate(0) scale(1)}20%{transform:rotate(-8deg) scale(1.06)}40%{transform:rotate(7deg) scale(1.1)}60%{transform:rotate(-5deg) scale(1.06)}80%{transform:rotate(3deg) scale(1.03)}}</style>' +
      '<img src="images/objet-couinator-3000.webp" alt="Couinator 3000" style="width:200px;max-width:70%;animation:couinCouin .6s ease-in-out 4">' +
      '<div style="font-size:1.6rem;font-weight:bold;color:#f2c230;margin:.3rem 0">COIN COIN COIN !</div>' +
      '<div style="font-size:.9rem;margin-bottom:.5rem">' + (trouvees.length > 1 ? texteEquip('couinAffoleN', 'Le Couinator s\'affole : {n} caméras cachées !', {n: trouvees.length}) : texteEquip('couinAffole1', 'Le Couinator s\'affole : 1 caméra cachée !')) + '</div>'
      : '<div style="font-size:1.1rem;font-weight:bold;margin-bottom:.5rem">' + (trouvees.length > 1 ? texteEquip('trouveN', 'Vous avez trouvé {n} caméras cachées !', {n: trouvees.length}) : texteEquip('trouve1', 'Vous avez trouvé 1 caméra cachée !')) + '</div>') +
    '<div style="font-size:.8rem;color:#9aa8b8;margin-bottom:.4rem">' + texteEquip('emporterVol', 'Emporter une caméra qui n\'a pas été posée chez vous est un vol.') + '</div>' +
    lignes +
    '<button type="button" data-fermer="1" style="margin-top:.8rem;background:none;border:1px solid #5d7085;color:#dce4ee;padding:.35rem .9rem;cursor:pointer">' + texteEquip('fermer', 'Fermer') + '</button></div>';
  fond.addEventListener('click', async ev => {
    const btn = ev.target.closest('button');
    if (!btn) { if (ev.target === fond) fond.remove(); return; }
    if (btn.dataset.fermer) { fond.remove(); return; }
    btn.disabled = true;
    const r = await surveillanceRpc('camera_trouvee_traiter', { p_id: btn.dataset.cam, p_action: btn.dataset.action });
    if (!r || r.ok !== true) { btn.disabled = false; showToast('Refusé', surveillanceRefus(r), false); return; }
    surveillanceAppliquer(r);
    const ligne = btn.closest('div');
    if (ligne) ligne.innerHTML = '<span style="color:#9aa8b8">' + (r.action === 'detruire' ? texteEquip('camDetruite', 'Caméra détruite.') : texteEquip('camEmportee', 'Caméra emportée.')) + '</span>';
  });
  document.body.appendChild(fond);
}

// ACTIONS DE PIÈCE (lot de Krasnov, point 9 ; GAME-DESIGN-KRASNOV-LOT-20261120.md ; étape I, 22/11/2026).
// L'ancien ordre « Fouiller ou voler » (menu à quatre choix) devient, tout en bas des ordres de chaque lieu :
//   * « Inspecter la pièce » (1 PA) : un seul ordre qui cherche à la fois les caméras cachées et les personnes cachées
//     (inspecter_piece) ; dans une vue de rue, « Inspecter les lieux » : caméras seulement ;
//   * « Désinstaller du matériel » (2 PA par matériel, pièces seulement) : l'objet tombe au sol et se ramasse sans PA ;
//     légal chez soi ou dans le local de son organisation, sinon c'est un vol (desinstaller_lire / desinstaller_materiel) ;
//   * « Se cacher » (1 PA, pièces seulement), à côté d'Inspecter : il n'est plus dans la fiche personnelle.
// « Voler quelqu'un » n'y est plus (il reste dans la fenêtre de rencontre). Les PA sont débités par le serveur.
const PIECE_TXT = {
  inspecter: 'Inspecter la pièce',
  inspecterRue: 'Inspecter les lieux',
  inspecterDesc: 'Chercher les caméras cachées et les personnes cachées ici, en une seule fois (1 PA).',
  inspecterRueDesc: 'Chercher les caméras cachées dans cette rue (1 PA). Personne ne se cache dans la rue.',
  inspecterIntro: 'Vous inspectez les lieux de fond en comble : caméras cachées et personnes cachées. Coût : <strong>1 PA</strong>.',
  inspecterRueIntro: 'Vous inspectez la rue à la recherche de caméras cachées. Coût : <strong>1 PA</strong>.',
  inspecterChances: 'À mains nues, vous trouvez chaque caméra une fois sur sept environ ; avec un <strong>Couinator 3000</strong> sur vous, trois fois sur quatre. Une personne cachée est débusquée selon votre perception et sa discrétion.',
  inspecterBouton: 'Inspecter (1 PA)',
  annuler: 'Annuler', fermer: 'Fermer',
  rien: 'Vous ne trouvez rien : ni caméra cachée, ni personne cachée.',
  rienRue: 'Vous ne trouvez aucune caméra cachée.',
  personnes1: 'Vous débusquez une personne cachée : {noms}.',
  personnesN: 'Vous débusquez {n} personnes cachées : {noms}.',
  masque: 'un personnage masqué',
  titreFini: 'Inspection terminée',
  desinstaller: 'Désinstaller du matériel',
  desinstallerDesc: 'Démonter du matériel installé ici (2 PA par matériel) : il tombe au sol et se ramasse sans PA. Légal chez vous ; ailleurs, c’est un vol.',
  desinstallerChezSoi: 'Vous êtes chez vous (ou dans le local de votre organisation) : démonter ce matériel est légal.',
  desinstallerAilleurs: 'Vous n’êtes pas chez vous : démonter le matériel des autres est un vol. Les personnes présentes peuvent vous surprendre (jet de discrétion contre leur perception), vous laissez une trace et le propriétaire peut porter plainte.',
  desinstallerVide: 'Aucun matériel n’est installé dans cette pièce.',
  desinstallerApres: 'L’objet tombe au sol : il n’est plus lié à la pièce et se ramasse sans PA (liste « Objets au sol »).',
  desinstallerBouton: 'Désinstaller (2 PA)',
  aVous: 'à vous', legal: 'légal', vol: 'vol',
  fermeACle: 'Fermée à clé : ouvrez d’abord la serrure.',
  paManque: 'Il faut 2 PA.',
  auSol: '« {nom} » est au sol : ramassez-le sans PA.',
  echecVol: 'Vous n’arrivez pas à démonter « {nom} » sans être vu : le matériel reste en place.',
  bagarre: 'On vous a surpris en train de démonter « {nom} » : la bagarre éclate.',
  seCacher: 'Se cacher',
  seCacherDesc: 'Vous dissimuler dans la pièce (1 PA). Les chances vous sont annoncées avant le jet.',
};
const pieceTxt = (k, v) => String(PIECE_TXT[k] || '').replace(/\{(\w+)\}/g, (_, x) => (v && v[x] != null ? v[x] : ''));

function ordresFouillerVoler(buildingId, roomId) {
  if (!buildingId || !roomId) return [];
  // Vues en plein air (Fred, 22/11/2026, GAME-DESIGN-SANTE-20261122.md, point 17 : PIECES_PLEIN_AIR et fiches pleinAir,
  // plateau-climat.js) : ni « Inspecter la pièce » ni « Désinstaller du matériel » ; « Se cacher » reste. Le serveur
  // refuse aussi les deux ordres (raison plein_air, migration 20261122234000).
  const s = typeof state !== 'undefined' ? state : null;
  const climat = globalThis.RPClimat;   // plateau-climat.js est chargé après ce fichier : lu au moment de l'appel
  const pleinAir = !!(climat && typeof climat.piecePleinAir === 'function'
    && climat.piecePleinAir({ country: s && s.country, currentCity: s && s.currentCity, currentBuilding: buildingId, currentRoom: roomId }));
  if (pleinAir) {
    return [{ fn: 'se_cacher', label: pieceTxt('seCacher'), pa: 1, cost: 0, type: 'legal', icon: 'ti-eye-off', successRate: 70, basDeListe: true,
      desc: pieceTxt('seCacherDesc') }];
  }
  return [
    { fn: 'inspecter_piece', label: pieceTxt('inspecter'), pa: 1, cost: 0, type: 'legal', icon: 'ti-search', successRate: 100, basDeListe: true,
      desc: pieceTxt('inspecterDesc') },
    { fn: 'se_cacher', label: pieceTxt('seCacher'), pa: 1, cost: 0, type: 'legal', icon: 'ti-eye-off', successRate: 70, basDeListe: true,
      desc: pieceTxt('seCacherDesc') },
    { fn: 'desinstaller_materiel', label: pieceTxt('desinstaller'), pa: 0, cost: 0, type: 'legal', icon: 'ti-tool', successRate: 100, basDeListe: true,
      desc: pieceTxt('desinstallerDesc') }
  ];
}
if (typeof window !== 'undefined') {
  window.RP_ORDRES_DYNAMIQUES = window.RP_ORDRES_DYNAMIQUES || [];
  if (!window.RP_ORDRES_DYNAMIQUES.includes(ordresFouillerVoler)) window.RP_ORDRES_DYNAMIQUES.push(ordresFouillerVoler);
}

// Bouton de la vue de rue (même place : tout en bas, en vert) : caméras seulement.
function ordreFouillerVolerRueHtml() {
  return '<button type="button" class="action-btn legal" data-fn="inspecter_piece" onclick="ouvrirFenetreInspecter()" title="' + pieceTxt('inspecterRueDesc') + '">' +
    '<i class="ti ti-search" style="font-size:.82rem"></i> ' + pieceTxt('inspecterRue') + ' <span style="opacity:.7">(1 PA)</span></button>';
}
// Ancien nom (écran resté ouvert, ancien routeur) : ouvre la nouvelle fenêtre.
function ouvrirMenuFouillerVoler() { ouvrirFenetreInspecter(); }

function pieceEstIci() {
  return typeof state !== 'undefined' && state && !!state.currentBuilding && !!state.currentRoom;
}
function pieceFermerFenetre() { document.getElementById('modal-postes')?.classList.remove('open'); }

// Fenêtre d'inspection : explication, puis confirmation (le jet et le débit restent au serveur).
function ouvrirFenetreInspecter() {
  const piece = pieceEstIci();
  const html = '<p class="cpj-note">' + pieceTxt(piece ? 'inspecterIntro' : 'inspecterRueIntro') + '</p>' +
    '<p class="cpj-note">' + pieceTxt('inspecterChances') + '</p>' +
    '<div style="margin-top:1rem;display:flex;gap:.5rem;flex-wrap:wrap">' +
    '<button class="cpj-touche cpj-primaire" onclick="inspecterConfirmer()">' + pieceTxt('inspecterBouton') + '</button>' +
    '<button class="cpj-touche" onclick="pieceFermerFenetre()">' + pieceTxt('annuler') + '</button></div>';
  if (typeof equipementsModale === 'function' && equipementsModale(pieceTxt(piece ? 'inspecter' : 'inspecterRue'), html)) return;
  inspecterConfirmer();
}
let inspectionEnCours = false;
async function inspecterConfirmer() {
  if (inspectionEnCours) return;
  inspectionEnCours = true;
  pieceFermerFenetre();
  try {
    const r = await surveillanceRpc('inspecter_piece', {});
    if (!r || r.ok !== true) { showToast(pieceTxt('inspecter'), surveillanceRefus(r), false); return; }
    surveillanceAppliquer(r);
    const trouvees = Array.isArray(r.trouvees) ? r.trouvees : [];
    const trouves = Array.isArray(r.trouves) ? r.trouves : [];
    if (trouves.length) {
      const noms = trouves.map(t => t.masque ? pieceTxt('masque') : t.nom).join(', ');
      const m = trouves.length > 1 ? pieceTxt('personnesN', { n: trouves.length, noms }) : pieceTxt('personnes1', { noms });
      showToast(pieceTxt('titreFini'), m, true);
      if (typeof addJournalEntry === 'function') addJournalEntry(m, 'event-good');
      if (typeof chargerVraisJoueursPresents === 'function') chargerVraisJoueursPresents();
    }
    // Énigme du trésor des Tsars (12/11/2026) : au musée présidentiel de Novomirsk, le serveur peut joindre le livre.
    if (r.livre_tresor === true && typeof tresorTsarsApresFouille === 'function' && tresorTsarsApresFouille(r) && !trouvees.length) return;
    if (trouvees.length) { surveillanceFenetreTrouvaille(trouvees, r.couinator); return; }
    if (!trouves.length) showToast(pieceTxt('titreFini'), r.couinator ? texteEquip('couinMuet', 'Le Couinator reste muet. Rien ici.') : pieceTxt(r.piece ? 'rien' : 'rienRue'), true);
  } finally { inspectionEnCours = false; }
}

// Fenêtre « Désinstaller du matériel » : liste du matériel installé, 2 PA par matériel, légal ou vol annoncé avant.
const DESINSTALLER_REFUS = {
  hors_batiment: 'Il faut être dans une pièce.', equipement_introuvable: 'Ce matériel n’est plus là.',
  pas_sur_place: 'Il faut être dans la pièce du matériel.', armoire_fermee_a_cle: 'Cette armoire est fermée à clé.',
  pa_insuffisants: 'Il vous faut 2 PA pour démonter un matériel.', emprisonne: 'Impossible en prison.'
};
async function ouvrirDesinstaller(message) {
  const r = await surveillanceRpc('desinstaller_lire', {});
  if (!r || r.ok !== true) { showToast(pieceTxt('desinstaller'), DESINSTALLER_REFUS[r && r.raison] || surveillanceRefus(r), false); return; }
  const liste = Array.isArray(r.materiel) ? r.materiel : [];
  const pa = Number(r.pa) || 0;
  let h = (message ? '<p style="color:#8ab070">' + surveillanceEchapper(message) + '</p>' : '') +
    '<p class="cpj-note">' + pieceTxt(r.chez_soi ? 'desinstallerChezSoi' : 'desinstallerAilleurs') + '</p>' +
    '<p class="cpj-note">' + pieceTxt('desinstallerApres') + '</p>';
  if (!liste.length) h += '<p>' + pieceTxt('desinstallerVide') + '</p>';
  h += liste.map(m => {
    const raison = m.ferme_a_cle ? pieceTxt('fermeACle') : (pa < 2 ? pieceTxt('paManque') : '');
    return '<div style="display:flex;gap:.5rem;align-items:center;justify-content:space-between;padding:.45rem 0;border-top:1px solid #2a3340">' +
      '<span>' + surveillanceEchapper(m.nom) + ' <span class="cpj-note">(' + pieceTxt(m.legal ? 'legal' : 'vol') + (m.a_moi ? ', ' + pieceTxt('aVous') : '') + ')</span>' +
      (raison ? '<br><span style="color:#e0a040;font-size:.85rem">' + raison + '</span>' : '') + '</span>' +
      '<button type="button" class="cpj-touche' + (m.legal ? ' cpj-primaire' : '') + '" data-desinstaller="' + surveillanceEchapper(m.id) + '"' +
      (raison ? ' disabled title="' + surveillanceEchapper(raison) + '"' : '') + '>' + pieceTxt('desinstallerBouton') + '</button></div>';
  }).join('');
  h += '<div style="margin-top:1rem"><button class="cpj-touche" onclick="pieceFermerFenetre()">' + pieceTxt('fermer') + '</button></div>';
  if (!(typeof equipementsModale === 'function' && equipementsModale(pieceTxt('desinstaller'), h))) return;
  document.querySelectorAll('[data-desinstaller]').forEach(b => b.addEventListener('click', () => desinstallerConfirmer(b.dataset.desinstaller, b)));
}
let desinstallationEnCours = false;
async function desinstallerConfirmer(id, bouton) {
  if (desinstallationEnCours) return;
  desinstallationEnCours = true;
  if (bouton) bouton.disabled = true;
  try {
    const requete = (window.crypto && crypto.randomUUID) ? crypto.randomUUID()
      : 'xxxxxxxx-xxxx-4xxx-8xxx-xxxxxxxxxxxx'.replace(/x/g, () => Math.floor(Math.random() * 16).toString(16));
    const r = await surveillanceRpc('desinstaller_materiel', { p_requete: requete, p_id: id });
    if (!r || r.ok !== true) {
      showToast(pieceTxt('desinstaller'), DESINSTALLER_REFUS[r && r.raison] || surveillanceRefus(r), false);
      await ouvrirDesinstaller(); return;
    }
    surveillanceAppliquer(r);
    if (typeof rafraichirEtatCriminel === 'function' && !r.legal) rafraichirEtatCriminel(r);
    let m;
    if (r.au_sol) m = pieceTxt('auSol', { nom: r.nom });
    else if (r.issue === 'combat') m = pieceTxt('bagarre', { nom: r.nom });
    else m = pieceTxt('echecVol', { nom: r.nom });
    showToast(pieceTxt('desinstaller'), m, !!r.au_sol);
    if (typeof addJournalEntry === 'function') addJournalEntry(m, r.au_sol ? 'event-info' : 'event-bad');
    if (typeof chargerObjetsAbandonnesDansPiece === 'function') chargerObjetsAbandonnesDansPiece();
    if (typeof updateUI === 'function') updateUI();
    if (r.issue === 'combat') { pieceFermerFenetre(); if (typeof chargerPersonnage === 'function') chargerPersonnage(); return; }
    await ouvrirDesinstaller(m);
  } finally { desinstallationEnCours = false; }
}

// Anciennes fenêtres de fouille (2 PA) : gardées pour un écran resté ouvert, elles ouvrent l'inspection.
function ouvrirFenetreFouille() { ouvrirFenetreInspecter(); }
function fouilleAnnuler() { pieceFermerFenetre(); }
function fouilleConfirmer() { inspecterConfirmer(); }
