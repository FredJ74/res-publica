/* Goulag de Sovarka : dix vues de progression, aucune décision locale des PA.
 * Les RPC servent d'unique source de vérité (trajet et effets d'ordres).
 * Ce module n'active aucune évasion avant le raccordement des gardes serveur.
 */
(function () {
  'use strict';
  const BASE = 'images/Sovarka/Goulag/Sovarka_goulag_toundra_';
  let etat = null;
  let occupe = false;
  let message = '';

  const el = (id) => document.getElementById(id);
  const image = (numero) => BASE + String(Math.max(1, Math.min(10, numero))).padStart(2, '0') + '.webp';
  const encode = (value) => String(value).replace(/[&<>"']/g, ch => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
  })[ch]);
  function imageEtape(d) {
    const numero = Math.max(1, Math.min(d.destination === 'starovka' ? 7 : 10, (d.progressions || 0) + 1));
    return image(numero);
  }

  function garantirSurface() {
    let root = el('goulag-toundra');
    if (root) return root;
    root = document.createElement('section');
    root.id = 'goulag-toundra';
    root.setAttribute('role', 'dialog');
    root.setAttribute('aria-label', 'Traversée de la toundra');
    root.innerHTML = '<div class="goulag-toundra-interieur"></div>';
    document.body.appendChild(root);
    return root;
  }

  function rendre() {
    const root = garantirSurface();
    if (!etat || !etat.en_cours) { root.style.display = 'none'; return; }
    const place = root.querySelector('.goulag-toundra-interieur');
    const total = etat.destination === 'starovka' ? 7 : 10;
    const avance = Math.min(total, Math.max(0, Number(etat.progressions) || 0));
    const etape = Math.min(total, avance + 1);
    place.innerHTML =
      '<h2>Traversée de la toundra — '+encode(etat.destination === 'starovka' ? 'Starovka' : 'Krasnov')+'</h2>'+
      '<p class="goulag-infos">Progression : <strong>'+avance+' / '+total+'</strong> · PA : <strong>'+encode(etat.pa)+'</strong> · Bois trouvé : <strong>'+encode(etat.bois_trouve || 0)+'</strong> / 8</p>'+
      '<img src="'+imageEtape(etat)+'" alt="Étape '+etape+' de la toundra de Sovarka" '+
      'style="width:100%;height:auto;aspect-ratio:4/3;object-fit:cover;border-radius:10px;display:block">'+
      '<p class="goulag-explique">Vous êtes seul dans la toundra. Votre marche ne peut pas être annulée. Une progression par jour ; aucun ordre ne peut vous ramener à zéro PA.</p>'+
      '<div class="goulag-actions">'+
      '<button type="button" data-goulag-action="abri">Dresser un abri (−1 PA)</button>'+
      '<button type="button" data-goulag-action="dormir" style="min-height:44px;padding:12px 16px">Dormir (+3 PA, +3 avec abri)</button>'+
      '<button type="button" data-goulag-action="progresser" style="min-height:44px;padding:12px 16px">Progresser (−5 PA)</button>'+
      '</div>'+(etat.champignons_a_decider ? '<div class="goulag-actions"><p>Vous découvrez des champignons. Les manger peut avoir des conséquences sur votre énergie.</p><button type="button" data-goulag-action="champignons_manger">Manger les champignons</button><button type="button" data-goulag-action="champignons_refuser">Ne pas les manger</button></div>' : '')+'<p id="goulag-toundra-message" role="status" aria-live="polite">'+encode(message)+'</p>';
    root.style.display = 'block';
    for (const btn of root.querySelectorAll('[data-goulag-action]')) {
      const a=btn.dataset.goulagAction;
      btn.disabled = occupe || (a==='progresser' && etat.champignons_a_decider) || (a==='abri' && (etat.abri_aujourdhui || etat.dormi_aujourdhui || etat.pa <= 1))
        || (a==='dormir' && etat.dormi_aujourdhui)
        || (a==='progresser' && (etat.progresse_aujourdhui || etat.pa <= 5));
      btn.addEventListener('click', () => action(btn.dataset.goulagAction));
    }
  }

  async function lire() {
    if (typeof sbRpcVerdict !== 'function') return null;
    try {
      const v = await sbRpcVerdict('goulag_toundra_lire', {});
      if (!v || v.ok !== true) return null;
      etat = v;
      rendre();
      return v;
    } catch (_) { return null; }
  }

  async function action(nom) {
    if (occupe || !etat?.en_cours) return;
    if (typeof sbRpcVerdict !== 'function') return;
    occupe = true; rendre();
    try {
      const v = await sbRpcVerdict('goulag_toundra_agir', { p_action: nom });
      if (!v || v.ok !== true) {
        message = 'Ordre refusé : ' + (v?.raison || 'réponse du serveur indisponible');
        return;
      }
      message = '';
      if (v.inventory && typeof sbAdopterInventaireServeur === 'function') sbAdopterInventaireServeur(v);
      if (v.termine || v.arrivee) {
        if (v.recherche && typeof showToast === 'function') showToast('Évasion du goulag', 'Votre portrait circule désormais en ville. Trouvez un refuge chez un habitant : trois jours de repos vous attendent.', false);
        else if (typeof showToast === 'function') showToast('Traversée achevée', 'Vous êtes épuisé. Vous devez récupérer trois jours chez un habitant.', true);
        etat = null; rendre();
        if (typeof sbLoadPersonnage === 'function') await sbLoadPersonnage();
        if (typeof updateUI === 'function') updateUI();
        if (typeof window.goulagRefugeRejoindre === 'function') await window.goulagRefugeRejoindre();
        return;
      }
      await lire();
    } catch (_) { message = 'Impossible de confirmer cet ordre auprès du serveur.'; }
    finally { occupe = false; rendre(); }
  }

  function ordresGoulagDuLieu(buildingId, roomId, ville) {
    if (typeof state === 'undefined' || state.country !== 'soviet' || ville !== 'qhs' || buildingId !== 'qhs-prison') return [];
    const pieces = (typeof BUILDINGS !== 'undefined' && BUILDINGS['qhs-prison']?.rooms) || {};
    const masque = Object.values(pieces).flatMap(p => (p.orders || []).map(o => o.fn));
    if (roomId === 'cellules_qhs') return [
      { fn: '__goulag_masque', masque, invisible: true, label: '', pa: 0, cost: 0 },
      { fn: 'goulag_detenu_entree', label: "Se rendre à l'entrée du goulag", pa: 0, cost: 0,
        type: 'legal', icon: 'ti-door-enter', successRate: 100,
        desc: "Rejoindre l'entrée sous contrôle de la détention. Ce n'est pas une libération ni un transport." }
    ];
    if (roomId !== 'entree_qhs') return [{ fn: '__goulag_masque', masque, invisible: true, label: '', pa: 0, cost: 0 }];
    return [{ fn: 'goulag_depart_pied', label: "S'enfuir à pied", pa: 0, cost: 0,
      icon: 'ti-walk', type: 'legal', successRate: 100, masque,
      desc: 'Choisir Starovka (7 PA minimum, 7 progressions) ou Krasnov (10 PA minimum, 10 progressions). Départ irréversible.' }];
  }

  // Le registre dynamique masque les ordres républicains hérités du QHS dans le seul goulag.
  if (typeof window !== 'undefined') {
    window.RP_ORDRES_DYNAMIQUES = window.RP_ORDRES_DYNAMIQUES || [];
    window.RP_ORDRES_DYNAMIQUES.push(ordresGoulagDuLieu);
  }

  async function rejoindreEntree() {
    if (occupe || typeof sbRpcVerdict !== 'function') return;
    occupe = true;
    try {
      const r=await sbRpcVerdict('sovarka_goulag_detenu_vers_entree',{});
      if (!r || r.ok!==true) {
        if (typeof showToast==='function') showToast('Entrée inaccessible',r?.raison||'Refus du serveur.',false);
        return;
      }
      if (typeof sbLoadPersonnage==='function') await sbLoadPersonnage();
      if (typeof updateUI==='function') updateUI();
    } catch (_) {
      if (typeof showToast==='function') showToast('Entrée inaccessible','Le serveur ne confirme pas le déplacement.',false);
    } finally { occupe=false; }
  }
  window.goulagDetenuVersEntree=rejoindreEntree;

  async function choisirDepart() {
    if (occupe || typeof sbRpcVerdict !== 'function') return;
    const nom = window.prompt('Destination : 1 — Starovka (7 PA minimum, 7 jours) ; 2 — Krasnov (10 PA minimum, 10 jours). Départ irréversible.', '1');
    if (nom === null) return;
    const destination = String(nom).trim() === '1' ? 'starovka' : String(nom).trim() === '2' ? 'krasnov' : null;
    if (!destination) { if (typeof showToast === 'function') showToast('Destination inconnue', 'Choisissez 1 ou 2.', false); return; }
    if (!window.confirm('Confirmer le départ à pied vers '+(destination === 'starovka' ? 'Starovka' : 'Krasnov')+' ? Cette marche est irréversible.')) return;
    occupe = true;
    try {
      const verdict = await sbRpcVerdict('goulag_toundra_demarrer', { p_destination: destination });
      if (!verdict || verdict.ok !== true) {
        if (typeof showToast === 'function') showToast('Départ refusé', verdict?.raison || 'Le serveur ne confirme pas le départ.', false);
        return;
      }
      await lire();
    } catch (_) {
      if (typeof showToast === 'function') showToast('Départ non confirmé', 'Le serveur est indisponible.', false);
    } finally { occupe = false; }
  }

  // Initialisation explicite depuis une entrée validée par le serveur.
  window.goulagToundraChoisirDepart = choisirDepart;
  window.goulagToundraOuvrir = lire;
  // Reconnexion : attendre la vraie fiche serveur, sans lire le cache local.
  if (typeof document.addEventListener === 'function') document.addEventListener('DOMContentLoaded', () => {
    let essais = 0;
    const minuteur = window.setInterval(() => {
      essais++;
      if (typeof state !== 'undefined' && state.personnageChargeDepuisServeur === true) {
        window.clearInterval(minuteur);
        if (state.country === 'soviet') Promise.resolve(lire()).catch(() => null);
      } else if (essais >= 20) window.clearInterval(minuteur);
    }, 1500);
  });
  window.goulagToundraImageEtape = imageEtape;
})();
