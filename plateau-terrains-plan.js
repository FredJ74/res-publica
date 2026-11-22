// Plan du lotissement en vignettes (Fred, 21/11/2026, étape J : GAME-DESIGN-CHANTIERS-IMAGES-20261120.md, complément,
// point 1). Une carte cliquable par lot, qui mène au lot comme avant. Chaque carte montre l'image ACTUELLE du lot
// (terrain nu, étape du chantier, bâtiment achevé : mêmes fichiers et même repli que la vue du chantier,
// plateau-chantier-vue.js) et, dessous, une étiquette tirée du serveur (terrains_etat) :
//   « Lot 3 — 2 300 m² — À vendre », « Lot 3 — Chantier 47 % », « Lot 3 — Building d'Arnie ».
// Mise à jour sans recharger : affichage immédiat, relecture du serveur à l'ouverture puis toutes les 15 s tant que le
// plan est à l'écran. Tant que le serveur n'a pas répondu, l'étiquette ne dit que ce qui ne change jamais (numéro, surface).
// Deux hôtes : la scène de rue des lots de Luthécia (luthecia-terrains-lots, flèche de retour jamais couverte) et la vue
// « Terrains à bâtir » de Port-Sainte-Marie et de Montrouge (ouvrirTerrainsVille). Si ce fichier manque, rien ne change.
(function (global) {
'use strict';

// Textes français (clés listées dans RELAIS pour Codex).
const TXT_PLAN = {
  titre: 'Plan du lotissement', aide: 'Cliquez sur un lot pour vous y rendre.',
  lot: 'Lot {n}', surface: '{s} m²', a_vendre: 'À vendre', terrain_de: 'Terrain {de}', chantier: 'Chantier {p} %',
  a_receptionner: 'Chantier {p} % — à réceptionner', batiment: '{type} {de}', de_mairie: 'de la mairie',
  t_hangar: 'Hangar', t_commerce_standard: 'Commerce standard', t_commerce_premium: 'Commerce premium',
  t_logement: 'Logement', t_logement_social: 'Logements sociaux', t_building: 'Building', t_inconnu: 'Bâtiment',
  aller: 'Se rendre sur le lot {n}',
  panne: 'Le serveur ne répond pas : les étiquettes montrent la dernière information reçue. Nouvel essai dans quelques secondes.'
};
const t = (k, v) => String(TXT_PLAN[k] || k).replace(/\{(\w+)\}/g, (m, c) => (v && v[c] != null) ? String(v[c]) : m);
const etat = () => (typeof state !== 'undefined' && state) ? state : {};
const TERRAIN_NU = 'images/terrain-a-vendre-republic.webp';
const VOYELLE = /^[aeiouyàâäéèêëîïôöùûüœæh]/i;   // « d'Arnie », « d'Hélène », mais « de Jean Jaaj »

function numeroLot(id) { return String(id).split('-').pop(); }
function surfaceLot(id, ville, t0) {
  const s = Number(t0 && t0.surface);
  if (s > 0) return s;
  if (typeof SURFACE_TERRAINS === 'undefined') return null;
  return SURFACE_TERRAINS['republic|' + ville + '|' + id] ?? SURFACE_TERRAINS[id] ?? null;
}
function deQui(nom) {
  nom = String(nom || '').trim();
  if (!nom) return '';
  if (nom.startsWith('ville:')) return t('de_mairie');
  return (VOYELLE.test(nom) ? 'd’' : 'de ') + nom;
}
function typeBatiment(t0) {
  const n = t0.niveau_construction;
  if (n === 'logement' && typeof logementsSociauxPour === 'function' && logementsSociauxPour(t0)) return t('t_logement_social');
  return TXT_PLAN['t_' + n] || t('t_inconnu');
}
const fr = n => Number(n).toLocaleString('fr-FR');

// État d'un lot, à partir de la ligne serveur (t0 = colonne data, null tant qu'elle n'est pas lue).
function etatLot(id, ville, t0) {
  const n = numeroLot(id), s = surfaceLot(id, ville, t0);
  const tete = t('lot', { n }), surf = s ? t('surface', { s: fr(s) }) : null;
  const avec = (...parts) => [tete, ...parts.filter(Boolean)].join(' — ');
  if (!t0) return { id, numero: n, etat: 'inconnu', pct: null, etiquette: avec(surf) };
  const proprio = t0.proprietaire || null;
  if (t0.niveau_construction && !t0.chantier) {
    return { id, numero: n, etat: 'acheve', pct: null, etiquette: avec(t('batiment', { type: typeBatiment(t0), de: deQui(proprio) }).trim()) };
  }
  if (t0.chantier && typeof t0.chantier === 'object') {
    const ch = t0.chantier, d = Number(ch.dureeJours) || 0;
    const pct = d > 0 ? Math.max(0, Math.min(100, Math.floor((Number(ch.progressionJours) || 0) / d * 100))) : 0;
    return { id, numero: n, etat: 'chantier', pct, etiquette: avec(t(ch.attenteReception || pct >= 100 ? 'a_receptionner' : 'chantier', { p: pct })) };
  }
  if (proprio) return { id, numero: n, etat: 'achete', pct: null, etiquette: avec(surf, t('terrain_de', { de: deQui(proprio) })) };
  return { id, numero: n, etat: 'a_vendre', pct: null, etiquette: avec(surf, t('a_vendre')) };
}

// Image du terrain nu : même ordre que enterRoom (surcharge de la ville, puis image du pays, puis image du lot).
function imageTerrainNu(id) {
  const b = (typeof BUILDINGS !== 'undefined') ? BUILDINGS[id] : null;
  const salle = b && b.rooms ? Object.keys(b.rooms)[0] : null;
  const ctx = (typeof getBuildingContext === 'function') ? getBuildingContext(id) : null;
  const pays = etat().country;
  return (salle && ctx && ctx.roomOverrides && ctx.roomOverrides[salle] && ctx.roomOverrides[salle].imageUrl)
    || (salle && typeof ROOM_IMAGES_EMPIRE !== 'undefined' && ROOM_IMAGES_EMPIRE[pays] && ROOM_IMAGES_EMPIRE[pays][id] && ROOM_IMAGES_EMPIRE[pays][id][salle])
    || (salle && b.rooms[salle].imageUrl) || TERRAIN_NU;
}
const vueChantier = () => global.RPChantierVue || null;
function avecImageChantier(t0) { return !!(t0 && (t0.chantier || t0.niveau_construction)); }
function imageImmediateLot(id, t0) {
  const R = vueChantier();
  return (avecImageChantier(t0) && R && R.imageImmediate(t0)) || imageTerrainNu(id);
}
async function imageResolueLot(id, t0) {
  const R = vueChantier();
  if (avecImageChantier(t0) && R) { try { const u = await R.imageResolue(t0); if (u) return u; } catch (_) {} }
  return imageTerrainNu(id);
}

// Lignes serveur : la colonne data (texte JSON) et la colonne proprietaire.
function lireLigne(l) {
  if (!l) return null;
  let d = l.data;
  if (typeof d === 'string') { try { d = JSON.parse(d); } catch (_) { d = null; } }
  if (!d || typeof d !== 'object' || Array.isArray(d)) d = {};
  if (!d.proprietaire && l.proprietaire) d = { ...d, proprietaire: l.proprietaire };
  if (!d.niveau_construction && l.niveau_construction) d = { ...d, niveau_construction: l.niveau_construction };
  return d;
}

// ── Affichage ────────────────────────────────────────────────────────────────────────────────
let courant = null;   // { hote, ville, mode, ids, lignes: Map, jeton }
function idsVille(ville) { return (typeof TERRAINS_PAR_VILLE !== 'undefined') ? (TERRAINS_PAR_VILLE[ville] || []) : []; }

function ouvrirLot(id, mode) {
  if (mode === 'rue' && typeof entrerDansBatimentRue === 'function') return entrerDansBatimentRue(id, t('lot', { n: numeroLot(id) }));
  if (typeof enterBuilding === 'function') return enterBuilding(id);
}

function carte(doc, id, mode) {
  const b = doc.createElement('button');
  b.type = 'button'; b.className = 'tplan-carte'; b.dataset.lot = id; b.setAttribute('role', 'listitem');
  b.setAttribute('aria-label', t('aller', { n: numeroLot(id) }));
  b.innerHTML = '<span class="tplan-cadre"><img class="tplan-image" alt="" decoding="async"><span class="tplan-jauge" hidden><span></span></span></span>'
    + '<span class="tplan-etiquette"></span>';
  const img = b.querySelector('img');
  img.addEventListener('error', () => { const nu = imageTerrainNu(id); if (img.getAttribute('src') !== nu) img.src = nu; });
  b.addEventListener('click', () => ouvrirLot(id, mode));
  return b;
}

function majCarte(b, id, ville, t0) {
  const e = etatLot(id, ville, t0);
  b.dataset.etat = e.etat;
  b.title = e.etiquette;
  const lab = b.querySelector('.tplan-etiquette');
  if (lab.textContent !== e.etiquette) lab.textContent = e.etiquette;
  const j = b.querySelector('.tplan-jauge');
  j.hidden = e.etat !== 'chantier';
  if (e.etat === 'chantier') j.firstChild.style.width = e.pct + '%';
  const img = b.querySelector('img'), immediate = imageImmediateLot(id, t0);
  if (!img.getAttribute('src') || (t0 && img.dataset.cle !== JSON.stringify([!!t0.chantier, t0.niveau_construction || null, e.etat]))) {
    if (img.getAttribute('src') !== immediate) img.src = immediate;
    if (t0) {
      const cle = JSON.stringify([!!t0.chantier, t0.niveau_construction || null, e.etat]);
      img.dataset.cle = cle;
      imageResolueLot(id, t0).then(u => { if (u && img.dataset.cle === cle && img.getAttribute('src') !== u) img.src = u; });
    }
  } else if (t0 && t0.chantier) {
    // Même étape mais l'image peut changer de palier (gros œuvre → façade) : on relit l'image juste.
    imageResolueLot(id, t0).then(u => { if (u && img.getAttribute('src') !== u) img.src = u; });
  }
  return e;
}

function rendre() {
  const c = courant;
  if (!c || !c.hote.isConnected) return;
  const doc = c.hote.ownerDocument;
  const grille = c.racine.querySelector('.tplan-grille');
  for (const id of c.ids) {
    let b = grille.querySelector('[data-lot="' + id + '"]');
    if (!b) { b = carte(doc, id, c.mode); grille.appendChild(b); }
    majCarte(b, id, c.ville, c.lignes.has(id) ? c.lignes.get(id) : null);
  }
  const p = c.racine.querySelector('.tplan-panne');
  if (p) p.hidden = !c.panne;
}

async function relire() {
  const c = courant;
  if (!c || typeof sbGetTerrainsLibres !== 'function') return;
  const jeton = ++c.jeton;
  let lignes = null;
  try { lignes = await sbGetTerrainsLibres('republic'); } catch (_) { lignes = null; }
  if (courant !== c || jeton !== c.jeton) return;
  if (!Array.isArray(lignes)) { c.panne = true; rendre(); return; }
  c.panne = false;
  for (const id of c.ids) {
    const l = lignes.find(x => x && (x.id === 'republic_' + id || (x.building_id === id && (!x.country || x.country === 'republic'))));
    // Lot sans ligne : jamais acheté ni construit, donc à vendre.
    c.lignes.set(id, l ? lireLigne(l) : {});
  }
  rendre();
}

function retirerPlanLots() {
  const c = courant;
  courant = null;
  if (!c) return;
  if (c.racine && c.racine.parentNode) c.racine.remove();
  if (c.mode === 'piece') { delete c.hote.dataset.planLots; }
  else c.hote.classList.remove('tplan-rue');
}

// hote : #rc-scene (mode 'rue') ou #piece-image (mode 'piece').
function afficherPlanLots(hote, ville, mode) {
  const ids = idsVille(ville);
  if (!hote || !ids.length) return false;
  retirerPlanLots();
  const doc = hote.ownerDocument;
  const racine = doc.createElement('div');
  racine.className = 'tplan';
  racine.innerHTML = '<div class="tplan-tete"><span class="tplan-titre"></span><span class="tplan-aide"></span></div>'
    + '<div class="tplan-panne" role="status" hidden></div><div class="tplan-grille" role="list"></div>';
  racine.querySelector('.tplan-titre').textContent = t('titre');
  racine.querySelector('.tplan-aide').textContent = t('aide');
  racine.querySelector('.tplan-panne').textContent = t('panne');
  racine.querySelector('.tplan-grille').setAttribute('aria-label', t('titre'));
  racine.querySelector('.tplan-grille').dataset.nombre = String(ids.length);
  if (mode === 'piece') { hote.dataset.planLots = '1'; hote.insertBefore(racine, hote.firstChild); }
  else { hote.classList.add('tplan-rue'); hote.appendChild(racine); }
  // Affichage immédiat avec ce que le navigateur sait déjà (terrains déjà visités), puis le serveur.
  const lignes = new Map();
  const cache = etat().terrainsState || {};
  for (const id of ids) if (cache[id] && typeof cache[id] === 'object') lignes.set(id, cache[id]);
  courant = { hote, ville, mode, ids, lignes, racine, jeton: 0, panne: false };
  rendre();
  relire();
  return true;
}

function suivre() {
  const c = courant, doc = global.document;
  if (!c) return;
  if (!c.hote.isConnected || !c.racine.isConnected) { retirerPlanLots(); return; }
  if (doc && doc.hidden) return;
  relire();
}
if (global.document) setInterval(suivre, 15000);

global.RPTerrainsPlan = { TXT_PLAN, etatLot, imageTerrainNu, imageImmediateLot, imageResolueLot, lireLigne, relire, _courant: () => courant };
Object.assign(global, { afficherPlanLots, retirerPlanLots });
})(typeof window !== 'undefined' ? window : globalThis);
