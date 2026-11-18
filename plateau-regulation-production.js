// RÉGULATION DE LA PRODUCTION ET RÉCOLTE (Fred, 16/11/2026, GAME-DESIGN-REGULATION-PRODUCTION.md).
// Le serveur décide tout (regulation_production_lire, regulation_production_fixer, recolte_effectuer) ;
// l'écran n'affiche que ses réponses. Textes : catalogue i18n/regulation-production-resources.js
// (espace « regulationProduction »), le français restant dans le HTML comme repli.

const regT = (cle, francais, values) => (typeof ficheLibelleHtml === 'function')
  ? ficheLibelleHtml(cle, francais, values, 'regulationProduction')
  : String(francais).replace(/\{\{values\.(\w+)\}\}/g, (_, k) => (values && values[k] != null ? values[k] : ''));
const regEchapper = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
let regulationEnCours = false;

async function regulationLire() {
  const brut = (typeof sbRpc === 'function') ? await sbRpc('regulation_production_lire', {}).catch(() => null) : null;
  const v = Array.isArray(brut) ? brut[0] : brut;
  return (v && v.ok === true) ? v : null;
}

function regulationOuvrirModal(titreHtml, corpsHtml) {
  document.getElementById('postes-modal-title').innerHTML = titreHtml;
  document.getElementById('postes-body').innerHTML = corpsHtml;
  document.getElementById('modal-postes').classList.add('open');
  // Les textes posés par data-i18n attendent ce passage pour recevoir leurs valeurs ({{values.n}}) et leur
  // traduction : sans lui, la fenêtre affichait le gabarit brut (signalé par Fred, 17/11/2026).
  if (typeof window !== 'undefined') window.RPI18nPlateau?.apply?.(document.getElementById('modal-postes'));
}

// Une ligne d'information sur les règles de la ville pour une ressource (fenêtre de récolte).
function regulationInfoHtml(m) {
  let h = '';
  if (m.par_pa) h += '<div class="cpj-note">' + regT('perAp', '{{values.n}} par PA', { n: m.par_pa }) + '</div>';
  if (m.max_par_joueur != null) h += '<div class="cpj-note">' + regT('limitPlayer', 'Régulation : {{values.max}} récolte(s) par joueur et par jour ; vous en êtes à {{values.done}}.', { max: m.max_par_joueur, done: m.mes_recoltes_jour || 0 }) + '</div>';
  if (m.plafond_ville != null) h += '<div class="cpj-note">' + regT('limitCity', 'Plafond de la ville : {{values.done}} / {{values.max}} récolte(s) aujourd\'hui.', { max: m.plafond_ville, done: m.recoltes_ville_jour || 0 }) + '</div>';
  return h;
}

// ----- Fenêtre de récolte (remplace l'ancienne limite fixe de 2 par jour) -----
async function doRecolterMatiere(pa, cost) {
  const pays = state.country || 'republic';
  const ville = state.currentCity || 'capitale';
  const matieres = typeof getMatieresPremieresVille === 'function' ? getMatieresPremieresVille(pays, ville) : [];
  if (!matieres.length) { showToast('Indisponible', 'Aucune ressource naturelle à récolter ici.', false); globalThis.RPI18nPlateau?.markToast("toastBodies.b56661508", 'Aucune ressource naturelle à récolter ici.', undefined, 'Indisponible'); return; }
  const lecture = await regulationLire();
  const parMatiere = {};
  if (lecture && lecture.pays === pays && lecture.ville === ville) (lecture.matieres || []).forEach(m => { parMatiere[m.matiere] = m; });
  let html = '<div class="cpj-dialogue" style="padding:1rem">';
  matieres.forEach(m => {
    const info = parMatiere[m] || {};
    html += '<button class="cpj-touche" style="display:block;width:100%;text-align:left;margin-bottom:.3rem" onclick="confirmerRecolte(\'' + regEchapper(m).replace(/\\/g, '\\\\') + '\',1,0)">' + regEchapper(m) + '</button>';
    html += '<div style="margin:0 0 .6rem .4rem">' + regulationInfoHtml(info) + '</div>';
  });
  html += '</div>';
  regulationOuvrirModal(regT('harvestTitle', 'Récolter'), html);
}

async function confirmerRecolte(matiere, pa, cost) {
  // L'Assemblée empêche la production légale de ce qu'elle interdit (garde navigateur conservée).
  const cleRecolte = (typeof MATIERE_RECOLTE_VERS_CLE === 'object') ? MATIERE_RECOLTE_VERS_CLE[matiere] : null;
  if (cleRecolte && typeof assembleeControlerVenteLegale === 'function'
      && !(await assembleeControlerVenteLegale([{ stackKey: cleRecolte }]))) return;
  const brut = (typeof sbRpc === 'function')
    ? await sbRpc('recolte_effectuer', { p_matiere: matiere, p_pa: 1, p_cost: 0 }).catch(() => null) : null;
  const r = Array.isArray(brut) ? brut[0] : brut;
  if (!r || r.ok !== true) {
    if (r?.raison === 'regulation_joueur') { showToast('Action impossible', 'La régulation de la production de cette ville limite vos récoltes de cette ressource aujourd\'hui.', false); globalThis.RPI18nPlateau?.markToast("toastBodies.b637df782", 'La régulation de la production de cette ville limite vos récoltes de cette ressource aujourd\'hui.', undefined, 'Action impossible'); }
    else if (r?.raison === 'regulation_ville') { showToast('Action impossible', 'Le plafond de production de la ville est atteint pour aujourd\'hui.', false); globalThis.RPI18nPlateau?.markToast("toastBodies.be3cb73b2", 'Le plafond de production de la ville est atteint pour aujourd\'hui.', undefined, 'Action impossible'); }
    else if (r?.raison === 'rien_a_recolter_ici') { showToast('Indisponible', 'Cette ressource ne se récolte pas ici.', false); globalThis.RPI18nPlateau?.markToast("toastBodies.b56da2d59", 'Cette ressource ne se récolte pas ici.', undefined, 'Indisponible'); }
    else if (r?.raison === 'inventaire_plein') { showToast('Inventaire plein', 'Libérez de la place avant de récolter.', false); globalThis.RPI18nPlateau?.markToast("toastBodies.b8570e6ca", 'Libérez de la place avant de récolter.', undefined, 'Inventaire plein'); }
    else if (typeof signalerRefusCout === 'function') signalerRefusCout(r || { raison: 'paiement_indisponible' });
    return;
  }
  const quantite = r.quantite;
  if (typeof r.pa === 'number') state.pa = r.pa;
  if (Array.isArray(r.inventory) && typeof sbAdopterInventaireServeur === 'function') sbAdopterInventaireServeur(r);
  document.getElementById('modal-postes')?.classList.remove('open');
  if (typeof updateUI === 'function') updateUI();
  showToast('Récolte effectuée', '+' + quantite + ' ' + matiere + '.', true, true);
  if (typeof addJournalEntry === 'function') addJournalEntry('Récolte de ' + quantite + ' ' + matiere + '.', 'event-good');
}

// ----- Ordre « Régulation de la production » (adjoint au maire) -----
async function ouvrirRegulationProduction(pa, cost) {
  const v = await regulationLire();
  if (!v || !v.est_adjoint) {
    showToast('Action impossible', 'Seul l\'adjoint au maire de la ville peut régler la production, depuis la mairie.', false); globalThis.RPI18nPlateau?.markToast("toastBodies.b8835a03b", 'Seul l\'adjoint au maire de la ville peut régler la production, depuis la mairie.', undefined, 'Action impossible');
    return;
  }
  const mats = v.matieres || [];
  let html = '<div class="cpj-dialogue" style="padding:1rem">';
  html += '<div class="cpj-note" style="margin-bottom:.8rem">' + regT('intro', 'Pour chaque ressource de la ville : un maximum de récoltes par joueur et par jour et/ou un plafond total de la ville par jour. Laissez vide pour ne pas limiter ; 0 interdit la récolte. Chaque enregistrement coûte 1 PA.') + '</div>';
  if (!mats.length) html += '<div class="cpj-note">' + regT('none', 'Aucune ressource naturelle à récolter dans cette ville.') + '</div>';
  mats.forEach((m, i) => {
    html += '<div style="border-top:1px solid #394656;padding:.6rem 0">';
    html += '<div style="font-weight:600;margin-bottom:.3rem">' + regEchapper(m.matiere) + '</div>';
    html += '<div class="cpj-note">' + regT('today', 'Aujourd\'hui : {{values.n}} récolte(s) dans la ville.', { n: m.recoltes_ville_jour || 0 }) + '</div>';
    if (m.fixe_par && (m.max_par_joueur != null || m.plafond_ville != null)) html += '<div class="cpj-note">' + regT('setBy', 'Règle en vigueur, fixée par {{values.who}}.', { who: m.fixe_par }) + '</div>';
    html += '<label class="cpj-note" style="display:block;margin-top:.3rem">' + regT('perPlayer', 'Maximum par joueur et par jour') + '</label>';
    html += '<input class="cpj-champ" id="reg-joueur-' + i + '" type="number" min="0" max="10000" step="1" inputmode="numeric" value="' + (m.max_par_joueur != null ? m.max_par_joueur : '') + '" style="width:8rem">';
    html += '<label class="cpj-note" style="display:block;margin-top:.3rem">' + regT('cityCap', 'Plafond total de la ville par jour') + '</label>';
    html += '<input class="cpj-champ" id="reg-ville-' + i + '" type="number" min="0" max="100000" step="1" inputmode="numeric" value="' + (m.plafond_ville != null ? m.plafond_ville : '') + '" style="width:8rem">';
    html += '<div style="margin-top:.4rem"><button class="cpj-touche cpj-primaire" onclick="enregistrerRegulationProduction(' + i + ')">' + regT('save', 'Enregistrer (1 PA)') + '</button></div>';
    html += '</div>';
  });
  html += '</div>';
  regulationOuvrirModal(regT('title', 'Régulation de la production'), html);
  window._regulationMatieres = mats.map(m => m.matiere);
}

function regulationValeurChamp(id) {
  const el = document.getElementById(id);
  const s = el ? String(el.value).trim() : '';
  if (s === '') return null;
  const n = Number(s);
  return (Number.isInteger(n) && n >= 0) ? n : NaN;
}

async function enregistrerRegulationProduction(i) {
  if (regulationEnCours) return;
  const matiere = (window._regulationMatieres || [])[i];
  const joueur = regulationValeurChamp('reg-joueur-' + i);
  const ville = regulationValeurChamp('reg-ville-' + i);
  if (!matiere || Number.isNaN(joueur) || Number.isNaN(ville)) { showToast('Action impossible', 'Valeur invalide.', false); globalThis.RPI18nPlateau?.markToast("toastBodies.b70dc7ce4", 'Valeur invalide.', undefined, 'Action impossible'); return; }
  regulationEnCours = true;
  try {
    const brut = (typeof sbRpc === 'function')
      ? await sbRpc('regulation_production_fixer', { p_matiere: matiere, p_max_joueur: joueur, p_plafond_ville: ville }).catch(() => null) : null;
    const r = Array.isArray(brut) ? brut[0] : brut;
    if (!r || r.ok !== true) {
      if (r?.raison === 'poste_non_detenu' || r?.raison === 'pas_sur_place') { showToast('Action impossible', 'Seul l\'adjoint au maire de la ville peut régler la production, depuis la mairie.', false); globalThis.RPI18nPlateau?.markToast("toastBodies.b8835a03b", 'Seul l\'adjoint au maire de la ville peut régler la production, depuis la mairie.', undefined, 'Action impossible'); }
      else if (r?.raison === 'valeur_invalide') { showToast('Action impossible', 'Valeur invalide.', false); globalThis.RPI18nPlateau?.markToast("toastBodies.b70dc7ce4", 'Valeur invalide.', undefined, 'Action impossible'); }
      else if (typeof signalerRefusCout === 'function') signalerRefusCout(r || { raison: 'paiement_indisponible' });
      return;
    }
    if (typeof appliquerPaiementServeur === 'function') appliquerPaiementServeur({ pa: r.pa, liquide: r.liquide, arg: r.arg });
    else if (typeof r.pa === 'number') state.pa = r.pa;
    if (typeof updateUI === 'function') updateUI();
    showToast('Régulation de la production', 'Régulation enregistrée.', true, true); globalThis.RPI18nPlateau?.markToast("toastBodies.bab5a7f78", 'Régulation enregistrée.', undefined, 'Régulation de la production');
    await ouvrirRegulationProduction(1, 0);
  } finally { regulationEnCours = false; }
}
