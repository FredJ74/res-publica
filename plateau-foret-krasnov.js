// FORÊT DE KRASNOV — entrée par le portique, clairière, exploration en cliquant l'image (GAME-DESIGN-FORET-KRASNOV-20261121.md).
// Zones cliquables posées sur l'image de la pièce, au même calcul de recadrage que les enseignes (varianteZoneEnPixels) :
//  - entrée de la forêt (cour de l'exploitation) : le portique en bois → la clairière ;
//  - clairière : le sentier au centre → une vue de la forêt au hasard (mécanisme existant) ;
//  - vues de la forêt : le sous-bois au centre → une autre vue (on continue d'explorer).
// Au survol : main et infobulle « Explorer la forêt » au format des entrées de bâtiment des rues (.rc-tooltip : même
// taille, même police, même cadre) ; au toucher : l'action directement. Plus de halo (Fred, 22/11/2026, point 8 : il
// donnait l'impression d'un problème d'affichage). Aucun PA : ce sont des déplacements.
// En groupe, seul le chef fait avancer le groupe : le serveur le dit aux autres membres (« chef_de_groupe_requis »).
(function (global) {
'use strict';
const D = 'images/Sovarka/Krasnov/';
const ZONES = {
  zone_recolte: { image: D + 'Krasnov_exploitation_forestiere_cour.webp', zone: { x: 0.755, y: 0.265, w: 0.185, h: 0.23 }, sens: 'clairiere' },
  foret_clairiere: { image: D + 'Krasnov_foret_clairiere.webp', zone: { x: 0.40, y: 0.52, w: 0.21, h: 0.46 }, sens: 'enfoncer' },
  foret_vue_1: { image: D + 'Krasnov_foret_coupe.webp', zone: { x: 0.32, y: 0.28, w: 0.36, h: 0.44 }, sens: 'enfoncer' },
  foret_vue_2: { image: D + 'Krasnov_foret_coupe.webp', zone: { x: 0.32, y: 0.28, w: 0.36, h: 0.44 }, sens: 'enfoncer' },
  foret_vue_3: { image: D + 'Krasnov_foret_profonde.webp', zone: { x: 0.32, y: 0.28, w: 0.36, h: 0.44 }, sens: 'enfoncer' },
  foret_vue_4: { image: D + 'Krasnov_foret_profonde.webp', zone: { x: 0.32, y: 0.28, w: 0.36, h: 0.44 }, sens: 'enfoncer' }
};
const TXT = { explorer: 'Explorer la forêt' };   // clé pour Codex (RELAIS)
const etat = () => (typeof state !== 'undefined' && state) ? state : {};
function ici() {
  const s = etat();
  return s.country === 'soviet' && s.currentCity === 'ville_b' && s.currentBuilding === 'zone-production' ? ZONES[s.currentRoom] || null : null;
}
// Infobulle flottante des entrées de bâtiment (plateau-rue-centrale.js, afficherTooltipRue) : même classe, suit le curseur.
function infobulle(e) {
  const doc = global.document;
  let tip = doc.getElementById('foret-tooltip');
  if (!tip) { tip = doc.createElement('div'); tip.id = 'foret-tooltip'; tip.className = 'rc-tooltip'; doc.body.appendChild(tip); }
  tip.textContent = TXT.explorer;
  tip.style.left = (e.pageX + 16) + 'px';
  tip.style.top = (e.pageY - 10) + 'px';
  tip.classList.add('visible');
}
function masquerInfobulle() { const t = global.document && global.document.getElementById('foret-tooltip'); if (t) t.remove(); }
function poser() {
  const doc = global.document, cadre = doc && doc.getElementById('piece-image');
  if (!cadre) return;
  cadre.querySelectorAll('.foret-porte').forEach(e => e.remove());
  masquerInfobulle();
  const z = ici();
  if (!z) return;
  const b = doc.createElement('div');
  b.className = 'foret-porte'; b.setAttribute('role', 'button'); b.tabIndex = 0;
  b.setAttribute('aria-label', TXT.explorer); b.dataset.sens = z.sens;
  Object.assign(b.style, { position: 'absolute', zIndex: '2', cursor: 'pointer', display: 'none' });
  b.addEventListener('mousemove', infobulle);
  b.addEventListener('mouseleave', masquerInfobulle);
  const agir = e => { e.preventDefault(); e.stopPropagation(); masquerInfobulle(); if (typeof global.foretAller === 'function') global.foretAller(z.sens); };
  b.addEventListener('click', agir);
  b.addEventListener('keydown', e => { if (e.key === 'Enter' || e.key === ' ') agir(e); });
  if (global.getComputedStyle && global.getComputedStyle(cadre).position === 'static') cadre.style.position = 'relative';
  cadre.appendChild(b);
  placer(b, z, cadre);
}
function placer(b, z, cadre) {
  const enPx = taille => {
    let px = null;
    try { px = taille && typeof varianteZoneEnPixels === 'function' ? varianteZoneEnPixels(z.zone, cadre, taille, null) : null; } catch (_) { px = null; }
    if (px) Object.assign(b.style, { display: 'block', left: px.gauche + 'px', top: px.haut + 'px', width: px.largeur + 'px', height: px.hauteur + 'px' });
    else Object.assign(b.style, { display: 'block', left: z.zone.x * 100 + '%', top: z.zone.y * 100 + '%', width: z.zone.w * 100 + '%', height: z.zone.h * 100 + '%' });
  };
  // Repli en pourcentages si le calcul du recadrage est indisponible : la zone n'est jamais invisible.
  try {
    if (typeof varianteTailleNaturelle !== 'function') return enPx(null);
    varianteTailleNaturelle(z.image).then(t => { try { enPx(t); } catch (_) { enPx(null); } }, () => enPx(null));
  } catch (_) { enPx(null); }
}
function brancher() {
  if (typeof global.enterRoom === 'function' && !global.enterRoom.__foret) {
    const orig = global.enterRoom;
    const env = function () { const r = orig.apply(this, arguments); try { poser(); } catch (_) {} return r; };
    env.__foret = true; Object.keys(orig).forEach(k => { env[k] = orig[k]; }); global.enterRoom = env;
  }
  global.addEventListener && global.addEventListener('resize', () => { const z = ici(), b = global.document.querySelector('.foret-porte'); if (z && b) placer(b, z, global.document.getElementById('piece-image')); });
}
if (global.document && global.document.readyState !== 'loading') brancher();
else if (global.document) global.document.addEventListener('DOMContentLoaded', brancher);
global.RPForetKrasnov = { ZONES, TXT, poser };
})(typeof window !== 'undefined' ? window : globalThis);
