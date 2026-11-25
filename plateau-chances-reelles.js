// « Vos chances réelles : X % » (mission de nuit du 25/11/2026, bloc 4 ; décision de Fred du 24/11 au soir).
// Avant le clic, les ordres à chance de la pièce affichent la chance calculée par le SERVEUR (ordres_chances_lire), avec
// la même formule que celle qui tranche l'ordre. Aucun calcul ici : on lit, on affiche.
// Tant que la migration 20261125130000 n'est pas appliquée, la lecture échoue en silence et rien ne change à l'écran.
(function (global) {
  'use strict';
  const doc = global.document;
  if (!doc) return;
  // Ordres dont le serveur sait lire la chance avant le clic (voir ordres_chances_lire).
  const ORDRES = ['se_cacher', 'acheter_bombe_illegale', 'utiliser_explosifs', 'lancer_rumeur_cible'];
  const texte = x => 'Vos chances réelles : ' + x + ' %';
  let generation = 0, planifie = false;

  function fnDuBouton(b) {
    const m = /doOrder\('([a-z0-9_]+)'/.exec(b.getAttribute('onclick') || '');
    return m ? m[1] : null;
  }
  function poser(b, taux) {
    let pastille = b.querySelector('.rp-chance-reelle');
    if (!pastille) {
      pastille = doc.createElement('span');
      pastille.className = 'rp-chance-reelle';
      b.appendChild(pastille);
    }
    pastille.textContent = taux + ' %';
    pastille.title = texte(taux);
    // Infobulle d'ordinateur et bulle « i » : la chance réelle en tête, la réussite déclarée remplacée.
    const titre = (b.getAttribute('title') || '').replace(/^Vos chances réelles : \d+ % \| /, '').replace(/Reussite: \d+%/, 'Reussite: ' + taux + '%');
    b.setAttribute('title', texte(taux) + ' | ' + titre);
    const brut = b.getAttribute('data-rp-tip');
    if (brut) {
      try {
        const d = JSON.parse(decodeURIComponent(brut));
        const cible = d.details || d;
        cible.s = taux; d.cr = taux;
        b.setAttribute('data-rp-tip', encodeURIComponent(JSON.stringify(d)));
      } catch (_) { /* descripteur illisible : la pastille suffit */ }
    }
    b.setAttribute('data-rp-chance', String(taux));
  }
  async function annoter() {
    planifie = false;
    const rangee = doc.getElementById('actions-row-bat');
    if (!rangee || typeof global.sbRpc !== 'function') return;
    const parOrdre = {};
    rangee.querySelectorAll('button.action-btn').forEach(b => {
      if (b.classList.contains('blocked')) return;
      const fn = fnDuBouton(b);
      if (fn && ORDRES.includes(fn)) (parOrdre[fn] = parOrdre[fn] || []).push(b);
    });
    const fns = Object.keys(parOrdre);
    if (!fns.length) return;
    const g = ++generation;
    let r = null;
    try { r = await global.sbRpc('ordres_chances_lire', { p_fns: fns }); } catch (_) { r = null; }
    if (g !== generation || !r || r.ok !== true || !r.chances) return;
    for (const fn of fns) {
      const taux = r.chances[fn];
      if (typeof taux === 'number') parOrdre[fn].forEach(b => { if (b.isConnected) poser(b, taux); });
    }
  }
  function planifier() { if (!planifie) { planifie = true; global.setTimeout(annoter, 0); } }
  function brancher() {
    const rangee = doc.getElementById('actions-row-bat');
    if (!rangee) return false;
    // Seuls les remplacements de la rangée (rendu des ordres de la pièce) relancent la lecture, pas nos pastilles.
    new global.MutationObserver(ms => { if (ms.some(m => m.target === rangee)) planifier(); }).observe(rangee, { childList: true });
    planifier();
    return true;
  }
  if (!brancher()) doc.addEventListener('DOMContentLoaded', brancher, { once: true });
  global.RPChancesReelles = Object.freeze({ annoter, texte, ORDRES });
})(typeof window !== 'undefined' ? window : globalThis);
