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

// « Fouiller ou voler » : un seul ordre vert, tout en bas, dans toute piece et toute vue de rue
// (decision de Fred, 11/11/2026, 14 h 57). Il ouvre un menu deroulant : « Fouiller les lieux » ou
// « Voler du matériel installé », chacun avec sa fenetre dediee. Les PA sont debites par le serveur
// (fouiller_lieux : 2 PA ; vol : 3 PA) ; le routeur sort avant tout debit generique.
function ordresFouillerVoler(buildingId, roomId) {
  if (!buildingId || !roomId) return [];
  return [{ fn: 'fouiller_voler', label: texteEquip('fouillerVoler', 'Fouiller ou voler'), pa: 0, cost: 0, type: 'legal', icon: 'ti-search',
    successRate: 100, basDeListe: true,
    desc: texteEquip('fouillerVolerDesc', 'Fouiller les lieux à la recherche de caméras cachées, ou voler du matériel installé ici.') }];
}
if (typeof window !== 'undefined') {
  window.RP_ORDRES_DYNAMIQUES = window.RP_ORDRES_DYNAMIQUES || [];
  if (!window.RP_ORDRES_DYNAMIQUES.includes(ordresFouillerVoler)) window.RP_ORDRES_DYNAMIQUES.push(ordresFouillerVoler);
}

// Bouton de la vue de rue (meme ordre, meme place : tout en bas, en vert).
function ordreFouillerVolerRueHtml() {
  return '<button type="button" class="action-btn legal" data-fn="fouiller_voler" onclick="ouvrirMenuFouillerVoler(this)" title="' + texteEquip('fouillerVolerDesc', 'Fouiller les lieux à la recherche de caméras cachées, ou voler du matériel installé ici.') + '">' +
    '<i class="ti ti-search" style="font-size:.82rem"></i> ' + texteEquip('fouillerVoler', 'Fouiller ou voler') + '</button>';
}

function fermerMenuFouillerVoler() {
  const m = document.getElementById('menu-fouiller-voler');
  if (m) m.remove();
  document.removeEventListener('pointerdown', fermerMenuFouillerVolerDehors, true);
  document.removeEventListener('keydown', fermerMenuFouillerVolerEchap, true);
}
function fermerMenuFouillerVolerDehors(e) {
  const m = document.getElementById('menu-fouiller-voler');
  if (m && !m.contains(e.target)) fermerMenuFouillerVoler();
}
function fermerMenuFouillerVolerEchap(e) { if (e.key === 'Escape') fermerMenuFouillerVoler(); }

// Dernier bouton d'ordre clique : le routeur peut appeler le menu apres une attente, quand
// window.event n'existe plus ; le menu s'ancre alors sur ce bouton.
let RP_DERNIER_BOUTON_ORDRE = null;
if (typeof document !== 'undefined' && document.addEventListener) {
  document.addEventListener('click', (e) => {
    const b = e.target && e.target.closest ? e.target.closest('.action-btn') : null;
    if (b) RP_DERNIER_BOUTON_ORDRE = b;
  }, true);
}

// Menu deroulant sous le bouton (au-dessus s'il manque de place en bas).
function ouvrirMenuFouillerVoler(ancre) {
  fermerMenuFouillerVoler();
  const evt = (typeof window !== 'undefined') ? window.event : null;
  const el = ancre || (evt && evt.target && evt.target.closest ? evt.target.closest('.action-btn') : null)
    || (RP_DERNIER_BOUTON_ORDRE && RP_DERNIER_BOUTON_ORDRE.isConnected ? RP_DERNIER_BOUTON_ORDRE : null);
  const menu = document.createElement('div');
  menu.id = 'menu-fouiller-voler';
  menu.setAttribute('role', 'menu');
  menu.style.cssText = 'position:fixed;z-index:1000;min-width:240px;max-width:calc(100vw - 16px);background:#151107;border:1px solid #6a5a20;border-radius:6px;box-shadow:0 6px 18px rgba(0,0,0,.6);padding:4px;display:flex;flex-direction:column;gap:4px';
  const item = (libelle, action) => {
    const b = document.createElement('button');
    b.type = 'button';
    b.setAttribute('role', 'menuitem');
    b.textContent = libelle;
    b.style.cssText = 'text-align:left;min-height:44px;padding:.5rem .75rem;background:#1d170a;color:#e0d8c0;border:1px solid #3a3215;border-radius:4px;font:inherit;font-size:.95rem;cursor:pointer';
    b.addEventListener('click', () => { fermerMenuFouillerVoler(); action(); });
    return b;
  };
  menu.appendChild(item(texteEquip('menuFouiller', '🔍 Fouiller les lieux (2 PA)'), ouvrirFenetreFouille));
  menu.appendChild(item(texteEquip('menuVoler', '🕵 Voler du matériel installé (3 PA)'), () => { if (typeof ouvrirVolMateriel === 'function') ouvrirVolMateriel(); }));
  document.body.appendChild(menu);
  const r = el && el.getBoundingClientRect ? el.getBoundingClientRect() : null;
  const h = menu.offsetHeight, w = menu.offsetWidth, vw = window.innerWidth, vh = window.innerHeight;
  if (r) {
    const enBas = r.bottom + 4 + h <= vh;
    menu.style.top = Math.max(8, enBas ? r.bottom + 4 : r.top - 4 - h) + 'px';
    menu.style.left = Math.min(Math.max(8, r.left), vw - w - 8) + 'px';
  } else {
    menu.style.top = Math.max(8, (vh - h) / 2) + 'px';
    menu.style.left = Math.max(8, (vw - w) / 2) + 'px';
  }
  menu.querySelector('button')?.focus({ preventScroll: true });
  setTimeout(() => {
    document.addEventListener('pointerdown', fermerMenuFouillerVolerDehors, true);
    document.addEventListener('keydown', fermerMenuFouillerVolerEchap, true);
  }, 0);
}

// Fenetre dediee a la fouille : explication puis confirmation (le jet et le debit restent au serveur).
function ouvrirFenetreFouille() {
  const html = '<p class="cpj-note">' + texteEquip('fouilleIntro', 'Vous inspectez les lieux à la recherche de caméras cachées. Coût : <strong>2 PA</strong>.') + '</p>' +
    '<p class="cpj-note">' + texteEquip('fouilleChances', 'À mains nues, vous trouvez chaque caméra une fois sur sept environ. Avec un <strong>Couinator 3000</strong> sur vous, trois fois sur quatre. Une caméra trouvée peut être détruite ou emportée.') + '</p>' +
    '<div style="margin-top:1rem;display:flex;gap:.5rem;flex-wrap:wrap">' +
    '<button class="cpj-touche cpj-primaire" onclick="fouilleConfirmer()">' + texteEquip('fouiller2', 'Fouiller (2 PA)') + '</button>' +
    '<button class="cpj-touche" onclick="fouilleAnnuler()">' + texteEquip('annuler', 'Annuler') + '</button></div>';
  if (typeof equipementsModale === 'function' && equipementsModale(texteEquip('fouillerLieux', 'Fouiller les lieux'), html)) return;
  surveillanceFouiller();
}
function fouilleAnnuler() { document.getElementById('modal-postes')?.classList.remove('open'); }
function fouilleConfirmer() { fouilleAnnuler(); surveillanceFouiller(); }
