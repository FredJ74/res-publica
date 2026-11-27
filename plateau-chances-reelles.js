// « Vos chances réelles : X % » (mission de nuit du 25/11/2026, bloc 4 ; décision de Fred du 24/11 au soir).
// Avant le clic, les ordres à chance de la pièce affichent la chance calculée par le SERVEUR (ordres_chances_lire), avec
// la même formule que celle qui tranche l'ordre. Aucun calcul ici : on lit, on affiche.
// Tant que la migration 20261125130000 n'est pas appliquée, la lecture échoue en silence et rien ne change à l'écran.
(function (global) {
  'use strict';
  const doc = global.document;
  if (!doc) return;
  // Ordres dont le serveur sait lire la chance avant le clic (voir ordres_chances_lire).
  // Mission du soir (25/11, bloc 1A) : ordres de l'audit des chances (migration 20261125400000, ordres_chances_audit_interne).
  const ORDRES = ['se_cacher', 'acheter_bombe_illegale', 'utiliser_explosifs', 'lancer_rumeur_cible',
    'bourrer_urnes', 'falsifier_listes_electorales', 'truquer_depouillement', 'tentative_evasion',
    'se_rebeller', 'ecouter_rumeurs', 'inspecter_cargaisons', 'contester_resultats', 'falsifier_document',
    'voler_materiel_chantier', 'corrompre_fonct', 'corrompre_gardien', 'soins_discrets'];
  // Ordres sans jet de réussite (le serveur vend, accorde ou exécute à coup sûr) : aucun pourcentage n'est affiché.
  const SANS_JET = ['acheter_ghb', 'acheter_vipere', 'campagne_securite', 'propagande_etat', 'emprunter', 'visiter_prisonnier',
    'mobiliser'];
  // Ordres dont la chance dépend d'une cible ou d'un tiers choisi ensuite : pas de pourcentage écrit en dur sur le bouton,
  // la fenêtre de l'ordre ou sa description dit de quoi dépend la chance.
  const SELON_CIBLE = ['blocus_portuaire', 'corrompre_douanier', 'defense', 'escort_piege', 'greffe_corrompre_dossier',
    'greffe_corrompre_faux_casier', 'marchander_vote', 'faire_disparaitre_cadavre', 'negocier_squatteurs', 'donner_argent_pnj',
    'ouvrir_enquete',
    // Fuite aux archives (Fred, 27/11/2026) : la chance dépend du témoin présent (moteur commun du vol).
    'fuite_info'];
  // Le bouton n'affiche jamais un pourcentage écrit en dur pour ces ordres : seulement la chance lue au serveur, s'il la donne.
  const sansTauxEcrit = fn => ORDRES.includes(fn) || SANS_JET.includes(fn) || SELON_CIBLE.includes(fn);
  // Mission du soir (25/11/2026, 1.2) : ordres dont le jet est passé au serveur (migration 20261125500000).
  ORDRES.push('article', 'etouffer', 'demander_parler_loge', 'corrompre_journaliste', 'fabriquer_scandale');
  const texte = x => 'Vos chances réelles : ' + x + ' %';
  let generation = 0, planifie = false;

  function fnDuBouton(b) {
    const m = /doOrder\('([a-z0-9_]+)'/.exec(b.getAttribute('onclick') || '');
    return m ? m[1] : null;
  }
  // Fin de soirée du 25/11 (choix 2.3) : fuite d'information et soins sans trace affichent aussi la chance du demi-effet,
  // rendue par le serveur sous la clé « <ordre>_demi » (migration 20261125820000).
  const texteDemi = y => 'demi-effet : ' + y + ' %';
  function poser(b, taux, demi) {
    let pastille = b.querySelector('.rp-chance-reelle');
    if (!pastille) {
      pastille = doc.createElement('span');
      pastille.className = 'rp-chance-reelle';
      b.appendChild(pastille);
    }
    const aDemi = typeof demi === 'number';
    pastille.textContent = taux + ' %' + (aDemi ? ' · ½ ' + demi + ' %' : '');
    pastille.title = texte(taux) + (aDemi ? ' (' + texteDemi(demi) + ')' : '');
    // Infobulle d'ordinateur et bulle « i » : la chance réelle en tête, la réussite déclarée remplacée.
    const titre = (b.getAttribute('title') || '').replace(/^Vos chances réelles : \d+ %( \(demi-effet : \d+ %\))? \| /, '').replace(/Reussite: \d+%/, 'Reussite: ' + taux + '%');
    b.setAttribute('title', texte(taux) + (aDemi ? ' (' + texteDemi(demi) + ')' : '') + ' | ' + titre);
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
      const demi = r.chances[fn + '_demi'];
      if (typeof taux === 'number') parOrdre[fn].forEach(b => { if (b.isConnected) poser(b, taux, demi); });
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
  global.RPChancesReelles = Object.freeze({ annoter, texte, texteDemi, ORDRES, SANS_JET, SELON_CIBLE, sansTauxEcrit });
})(typeof window !== 'undefined' ? window : globalThis);
