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
  return (r && SURVEILLANCE_REFUS[r.raison]) || 'Le serveur a refusé' + (r && r.raison ? ' (' + r.raison + ')' : '') + '.';
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
    return document.getElementById('rue-titre')?.textContent?.trim() || 'Dans la rue';
  } catch (e) { return 'Lieu surveillé'; }
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
      '<div style="flex:1;min-width:0"><div class="person-name">Votre caméra</div>' +
      '<div class="person-role">' + (c.operationnelle ? 'Rapports toutes les ' : 'Inopérante (ordinateur ou box manquant) — ') +
      '<select onchange="surveillanceFrequence(\'' + surveillanceEchapper(c.id) + '\', this.value)" style="font-size:.78rem;background:#151a21;color:#dce4ee;border:1px solid #5d7085">' + opts + '</select></div>' +
      '<button type="button" onclick="surveillanceReprendre(\'' + surveillanceEchapper(c.id) + '\')" style="margin-top:.25rem;font-size:.78rem;background:none;border:1px solid #5d7085;color:#92b5db;cursor:pointer;padding:.15rem .4rem">Reprendre (1 PA)</button>' +
      '</div></div>';
  }
  if (r.cameras_inventaire > 0) {
    h += '<button type="button" onclick="surveillancePoser()" style="width:100%;padding:.45rem;margin:.35rem 0;border:1px solid #5d7085;background:#151a21;color:#dce4ee;font-size:.85rem;cursor:pointer">📷 Poser une caméra ici (1 PA)</button>';
  }
  h += '<button type="button" onclick="surveillanceFouiller()" style="width:100%;padding:.45rem;margin:.35rem 0;border:1px solid #6a5a20;background:#151107;color:#e0d8c0;font-size:.85rem;cursor:pointer">🔍 Fouiller les lieux (2 PA)' + (r.couinator ? ' 🦆' : '') + '</button>';
  if (typeof ouvrirVolMateriel === 'function' && state.currentBuilding) {
    h += '<button type="button" onclick="ouvrirVolMateriel()" style="width:100%;padding:.45rem;margin:.35rem 0;border:1px solid #5a2a2a;background:#160d0d;color:#e0c8c8;font-size:.85rem;cursor:pointer">🕵 Voler du matériel installé ici</button>';
  }
  bloc.innerHTML = h;
  liste.appendChild(bloc);
}
function surveillanceRafraichir() {
  const rue = document.getElementById('persons-sidebar-rue');
  surveillanceAfficherIci(rue && rue.style.display !== 'none' ? 'persons-list-rue' : 'persons-list');
}

async function surveillancePoser() {
  const r = await surveillanceRpc('camera_poser', { p_libelle: surveillanceLibelleLieu() });
  if (!r || r.ok !== true) { showToast('Caméra non posée', surveillanceRefus(r), false); return; }
  surveillanceAppliquer(r);
  if (r.repere) {
    showToast('Repéré !', 'Vous avez été surpris en posant la caméra : elle est saisie et vous êtes arrêté.', false);
    if (typeof rafraichirEtatCriminel === 'function') rafraichirEtatCriminel(r);
    if (typeof chargerPersonnage === 'function') chargerPersonnage();
    return;
  }
  showToast('Caméra posée', r.legale ? 'Votre caméra surveille ce lieu, en toute légalité.' : 'Votre caméra surveille ce lieu. Personne ne vous a vu… cette fois.', true);
  surveillanceRafraichir();
}
async function surveillanceReprendre(id) {
  const r = await surveillanceRpc('camera_reprendre', { p_id: id });
  if (!r || r.ok !== true) { showToast('Caméra non reprise', surveillanceRefus(r), false); return; }
  surveillanceAppliquer(r);
  showToast('Caméra reprise', 'Elle est de nouveau dans votre inventaire.', true);
  surveillanceRafraichir();
}
async function surveillanceFrequence(id, heures) {
  const r = await surveillanceRpc('camera_frequence', { p_id: id, p_heures: parseInt(heures, 10) });
  if (!r || r.ok !== true) { showToast('Réglage refusé', surveillanceRefus(r), false); return; }
  showToast('Réglage enregistré', 'Rapport toutes les ' + r.frequence + ' h.', true);
}

async function surveillanceFouiller() {
  const r = await surveillanceRpc('fouiller_lieux', {});
  if (!r || r.ok !== true) { showToast('Fouille impossible', surveillanceRefus(r), false); return; }
  surveillanceAppliquer(r);
  const trouvees = Array.isArray(r.trouvees) ? r.trouvees : [];
  if (!trouvees.length) {
    showToast('Fouille terminée', r.couinator ? 'Le Couinator reste muet. Rien ici.' : 'Vous ne trouvez rien de suspect.', true);
    return;
  }
  surveillanceFenetreTrouvaille(trouvees, r.couinator);
}
function surveillanceFenetreTrouvaille(trouvees, couinator) {
  const fond = document.createElement('div');
  fond.className = 'surveillance-trouvaille';
  fond.style.cssText = 'position:fixed;inset:0;z-index:2147483000;background:rgba(0,0,0,.85);display:flex;align-items:center;justify-content:center;padding:1rem';
  const lignes = trouvees.map((c, i) => '<div style="display:flex;gap:.5rem;align-items:center;justify-content:space-between;padding:.4rem 0;border-top:1px solid #2a3340">' +
    '<span>Caméra n° ' + (i + 1) + '</span><span>' +
    '<button type="button" data-cam="' + surveillanceEchapper(c.id) + '" data-action="detruire" style="margin-right:.3rem;background:#2a1414;color:#f0c0c0;border:1px solid #7a3a3a;padding:.3rem .6rem;cursor:pointer">Détruire</button>' +
    '<button type="button" data-cam="' + surveillanceEchapper(c.id) + '" data-action="emporter" style="background:#14202a;color:#c0dcf0;border:1px solid #3a5a7a;padding:.3rem .6rem;cursor:pointer">Emporter</button>' +
    '</span></div>').join('');
  fond.innerHTML = '<div style="max-width:420px;width:100%;background:#151a21;color:#dce4ee;border:1px solid #5d7085;border-radius:10px;padding:1rem;text-align:center">' +
    (couinator ? '<style>@keyframes couinCouin{0%,100%{transform:rotate(0) scale(1)}20%{transform:rotate(-8deg) scale(1.06)}40%{transform:rotate(7deg) scale(1.1)}60%{transform:rotate(-5deg) scale(1.06)}80%{transform:rotate(3deg) scale(1.03)}}</style>' +
      '<img src="images/objet-couinator-3000.webp" alt="Couinator 3000" style="width:200px;max-width:70%;animation:couinCouin .6s ease-in-out 4">' +
      '<div style="font-size:1.6rem;font-weight:bold;color:#f2c230;margin:.3rem 0">COIN COIN COIN !</div>' +
      '<div style="font-size:.9rem;margin-bottom:.5rem">Le Couinator s\'affole : ' + trouvees.length + ' caméra' + (trouvees.length > 1 ? 's' : '') + ' cachée' + (trouvees.length > 1 ? 's' : '') + ' !</div>'
      : '<div style="font-size:1.1rem;font-weight:bold;margin-bottom:.5rem">Vous avez trouvé ' + trouvees.length + ' caméra' + (trouvees.length > 1 ? 's' : '') + ' cachée' + (trouvees.length > 1 ? 's' : '') + ' !</div>') +
    '<div style="font-size:.8rem;color:#9aa8b8;margin-bottom:.4rem">Emporter une caméra qui n\'a pas été posée chez vous est un vol.</div>' +
    lignes +
    '<button type="button" data-fermer="1" style="margin-top:.8rem;background:none;border:1px solid #5d7085;color:#dce4ee;padding:.35rem .9rem;cursor:pointer">Fermer</button></div>';
  fond.addEventListener('click', async ev => {
    const btn = ev.target.closest('button');
    if (!btn) { if (ev.target === fond) fond.remove(); return; }
    if (btn.dataset.fermer) { fond.remove(); return; }
    btn.disabled = true;
    const r = await surveillanceRpc('camera_trouvee_traiter', { p_id: btn.dataset.cam, p_action: btn.dataset.action });
    if (!r || r.ok !== true) { btn.disabled = false; showToast('Refusé', surveillanceRefus(r), false); return; }
    surveillanceAppliquer(r);
    const ligne = btn.closest('div');
    if (ligne) ligne.innerHTML = '<span style="color:#9aa8b8">' + (r.action === 'detruire' ? 'Caméra détruite.' : 'Caméra emportée.') + '</span>';
  });
  document.body.appendChild(fond);
}
