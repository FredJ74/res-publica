/* Accueil progressif des nouveaux PJ. Les délais ne produisent aucun effet de jeu :
   seuls les RPC existants décident de l'interview et de ses objectifs.
   Suivi UX local à cet appareil, sans migration et sans toucher aux données serveur. */
(function (global) {
  'use strict';
  const doc = global.document;
  if (!doc) return;
  const CINQ_MINUTES = 5 * 60 * 1000;
  const UNE_HEURE = 60 * 60 * 1000;
  const PREFIX = 'hg-accueil-progressif-v1:';
  let nom = '', debut = false, progression = null, dernier = Date.now(), journal = null, fenetre = null;

  function cle() { return PREFIX + encodeURIComponent(nom); }
  function sauver() {
    if (!debut || !progression) return;
    try { global.localStorage.setItem(cle(), JSON.stringify(progression)); } catch (_) {}
  }
  function lire() {
    try {
      const v = JSON.parse(global.localStorage.getItem(cle()) || 'null');
      if (v && Number.isFinite(v.ms) && v.ms >= 0 && typeof v.fermee === 'boolean') {
        return { ms: Math.min(v.ms, 86400000), fermee: v.fermee, parle: v.parle === true, journal: v.journal === true };
      }
    } catch (_) {}
    return {ms: 0, fermee: false, parle: false, journal: false};
  }
  function actif() {
    return doc.visibilityState === 'visible';
  }
  function style() {
    if (doc.getElementById('hg-bienvenue-style')) return;
    const css = doc.createElement('style');
    css.id = 'hg-bienvenue-style';
    css.textContent =
      '#hg-bienvenue{position:fixed;inset:0;z-index:16000;background:rgba(6,15,24,.84);display:flex;justify-content:center;align-items:center;padding:16px;box-sizing:border-box}' +
      '#hg-bienvenue .hg-bienvenue-carte{position:relative;max-height:calc(100dvh - 32px);overflow:auto;width:min(520px,100%);background:#202a36;color:#e2e9f1;border:1px solid #a98d56;border-radius:10px;box-shadow:0 12px 45px #0009;padding:24px 22px;box-sizing:border-box;font-size:1rem;line-height:1.55}' +
      '#hg-bienvenue h2{font-size:1.45rem;margin:0 45px 12px 0;color:#e5c477}' +
      '#hg-bienvenue p{font-size:1rem;margin:0 0 14px}' +
      '#hg-bienvenue .hg-bienvenue-aide{display:inline-flex;align-items:center;gap:8px;background:#344354;color:#e5c477;border:1px solid #a98d56;border-radius:5px;padding:9px 15px;font-size:1rem;font-weight:600}' +
      '#hg-bienvenue .hg-bienvenue-croix{position:absolute;top:8px;right:8px;width:44px;height:44px;display:grid;place-items:center;background:#344354;color:#e5c477;border:1px solid #a98d56;border-radius:6px;font-size:26px;cursor:pointer}' +
      '@media(max-width:400px){#hg-bienvenue .hg-bienvenue-carte{padding:18px 14px}}';
    doc.head.appendChild(css);
  }
  function lieu() {
    if (global.state?.country === 'soviet' && global.state?.currentCity === 'ville_b') return 'Krasnov, en Sovarka';
    if (global.state?.country === 'soviet') return 'Sovarka';
    if (global.state?.country === 'republic' && global.state?.currentCity === 'capitale') return 'Luthécia, en Républia';
    return 'Human Gambit';
  }
  function ouvrirBienvenue() {
    if (!debut || progression.fermee || fenetre) return;
    if (doc.querySelector('#modal-quete-accueil.open, #modal-pnj.open, .modal-overlay.open, #hg-accueil-interview')) return;
    style();
    fenetre = doc.createElement('section');
    fenetre.id = 'hg-bienvenue';
    fenetre.setAttribute('role', 'dialog');
    fenetre.setAttribute('aria-modal', 'true');
    fenetre.setAttribute('aria-label', 'Bienvenue dans Human Gambit');
    fenetre.innerHTML =
      '<div class="hg-bienvenue-carte">' +
        '<button type="button" class="hg-bienvenue-croix" aria-label="Fermer le message de bienvenue">×</button>' +
        '<h2>Bienvenue à ' + lieu() + ' !</h2>' +
        '<p>Ça doit faire bizarre de débarquer en terre inconnue ! Mais sache que tu n’es pas seul : on est là pour t’aider.</p>' +
        '<p><span class="hg-bienvenue-aide"><i class="ti ti-book" aria-hidden="true"></i> Aide</span></p>' +
        '<p>N’hésite pas à parler aux personnages que tu croiseras. Ils connaissent leur ville et pourront t’aider et t’orienter.</p>' +
        '<p>Je te laisse découvrir les lieux à ton rythme. On reviendra vers toi bientôt. Si tu as besoin d’aide, n’oublie pas : on est là !</p>' +
      '</div>';
    const croix = fenetre.querySelector('.hg-bienvenue-croix');
    croix.addEventListener('click', function () {
      progression.fermee = true;
      sauver();
      fenetre.remove();
      fenetre = null;
      verifier();
    });
    fenetre.addEventListener('keydown', function (e) {
      // La bienvenue ne se ferme jamais par Échap, ni par un clic extérieur.
      if (e.key === 'Escape') e.preventDefault();
      if (e.key === 'Tab' && doc.activeElement === croix) e.preventDefault();
    });
    doc.body.appendChild(fenetre);
    croix.focus({preventScroll: true});
  }
  function initialiser(etat) {
    const nouveauNom = global.state?.char?.name;
    if (!nouveauNom || !etat || etat.ok !== true || etat.personnage !== nouveauNom) return;
    if (nom === nouveauNom && progression) return;
    nom = nouveauNom;
    // La bienvenue accompagne seulement un premier accueil encore à faire.
    // Les joueurs dont l'interview est déjà terminée ne voient pas une nouvelle popup.
    const premiereVisite = etat.interview?.etat === 'a_faire';
    const ancien = lire();
    debut = premiereVisite || ancien.fermee || ancien.ms > 0;
    progression = debut ? ancien : {ms: UNE_HEURE, fermee: true, parle: true, journal: true};
    dernier = Date.now();
    verifier();
  }
  function entretienAutomatiqueAutorise() {
    return !!progression && (!debut || (progression.fermee && progression.ms >= CINQ_MINUTES && !progression.parle && !fenetre));
  }
  function journalAutomatiqueAutorise() {
    return !!progression && (!debut || (progression.fermee && progression.ms >= UNE_HEURE && !fenetre));
  }
  function queteInitialeAutorisee() {
    return !!progression && (!debut || (progression.fermee && progression.ms >= CINQ_MINUTES && !fenetre));
  }
  function verifier() {
    if (!progression) return;
    if (debut && !progression.fermee) ouvrirBienvenue();
    if (queteInitialeAutorisee() && typeof global.queteAccueilAfficherGardeDifferee === 'function'
        && !doc.querySelector('#hg-bienvenue, #hg-accueil-interview, #modal-quete-accueil.open, #modal-pnj.open, .modal-overlay.open')) {
      global.queteAccueilAfficherGardeDifferee();
    }
    if (journal && !progression.journal && journalAutomatiqueAutorise()) {
      if (doc.querySelector('#hg-accueil-interview, #hg-bienvenue, #modal-quete-accueil.open, .modal-overlay.open')) return;
      const action = journal;
      journal = null;
      progression.journal = true;
      sauver();
      action();
    } else if (journal && !debut) {
      const action = journal;
      journal = null;
      action();
    }
  }
  function programmerJournal(action) {
    if (typeof action !== 'function') return;
    journal = action;
    verifier();
  }
  function noterDiscussionPnj() {
    if (!debut || !progression || progression.parle) return;
    progression.parle = true;
    sauver();
  }
  function tic() {
    const maintenant = Date.now();
    const delta = Math.max(0, Math.min(5000, maintenant - dernier));
    dernier = maintenant;
    if (debut && progression && actif() && progression.ms < UNE_HEURE) {
      progression.ms += delta;
      sauver();
    }
    verifier();
  }
  global.addEventListener?.('pagehide', sauver);
  global.setInterval(tic, 1000);
  global.RPAccueilProgressif = Object.freeze({
    initialiser, verifier, noterDiscussionPnj, programmerJournal,
    entretienAutomatiqueAutorise, journalAutomatiqueAutorise, queteInitialeAutorisee,
    etat: () => progression && {...progression}
  });
})(typeof window !== 'undefined' ? window : globalThis);
