// PORTIER DES FENÊTRES AUTOMATIQUES (Fred, 24/11/2026, purge A.3). « Le nouveau venu doit pouvoir respirer. »
//  • Pendant la première heure de jeu d'un nouveau venu (décidée par le serveur : accueil_etat → calendrier.premiere_heure),
//    aucune fenêtre automatique : ni événement climatique, ni journal du jour (revue de presse), ni proposition de
//    notifications, ni message du PNJ guide. Seules exceptions, tenues ailleurs : la bienvenue (A.2), l'interview (A.3,
//    quand le serveur la déclare due) et l'avertissement sur les PA (au premier ordre payant).
//  • Après la première heure, et pour tous les joueurs : au plus UNE fenêtre automatique par connexion (chargement de la
//    page). Les autres attendent derrière un badge cliquable : icône journal pour le journal du jour, icône météo pour
//    l'événement climatique. Elles ne se superposent jamais : une fenêtre demandée pendant qu'une autre est ouverte attend.
// Le portier ne décide d'aucun effet de jeu : il range l'affichage selon l'état que le serveur a donné.
(function (global) {
  'use strict';
  const doc = global.document;
  if (!doc) return;

  // Ce qui compte comme « une fenêtre ouverte » (jamais deux à la fois).
  const OUVERTES = ['#hg-bienvenue', '#hg-accueil-interview', '#climat-explication', '#climat-gouvernement',
    '.modal-overlay.open', '#hg-notif-proposition', '#hg-bulle-pa'].join(',');
  // Badge de chaque type de fenêtre.
  const GROUPE = { journal_du_jour: 'journal', revue_presse: 'journal', climat: 'meteo', climat_accueil: 'meteo' };
  const TXT = {
    journal: 'Journal du jour : à lire quand vous voulez',
    meteo: 'Événement climatique : à lire quand vous voulez'
  };
  const ICONE = { journal: 'ti-news', meteo: 'ti-cloud-storm' };
  let montrees = 0;
  const files = { journal: [], meteo: [] };
  let attenteEtat = 0;

  const accueil = () => (global.RPAccueil && typeof global.RPAccueil.etat === 'function') ? global.RPAccueil.etat() : null;
  function premiereHeure() { const e = accueil(); return !!(e && e.calendrier && e.calendrier.premiere_heure); }
  function fenetreOuverte() { return !!doc.querySelector(OUVERTES); }

  // 'ouvrir' | 'attendre' | 'badge'
  function decision(type) {
    if (!accueil() && attenteEtat < 10) return 'attendre';     // état du serveur pas encore lu (au plus ~20 s)
    if (premiereHeure()) return 'badge';
    if (montrees >= 1) return 'badge';
    if (fenetreOuverte()) return 'attendre';
    return 'ouvrir';
  }
  // Demande d'ouverture automatique. `ouvrir` affiche la fenêtre ; `pertinent` (facultatif) dit si elle a encore lieu d'être.
  function demander(type, ouvrir, pertinent) {
    if (typeof ouvrir !== 'function') return;
    if (typeof pertinent === 'function' && !pertinent()) return;
    const d = decision(type);
    if (d === 'ouvrir') { montrees++; ouvrir(); return; }
    if (d === 'attendre') { if (!accueil()) attenteEtat++; setTimeout(() => demander(type, ouvrir, pertinent), 2000); return; }
    mettreEnBadge(type, ouvrir, pertinent);
  }
  // Une fenêtre automatique ouverte par un autre module (interview d'un ancien joueur) compte aussi.
  function marquer() { montrees++; }

  function mettreEnBadge(type, ouvrir, pertinent) {
    const g = GROUPE[type] || 'journal';
    if (!files[g].some(x => x.type === type)) files[g].push({ type, ouvrir, pertinent });
    dessiner();
  }
  function styles() {
    if (doc.getElementById('hg-fa-styles')) return;
    const s = doc.createElement('style');
    s.id = 'hg-fa-styles';
    s.textContent = '#hg-fenetres-badges{position:fixed;right:12px;top:72px;z-index:8500;display:flex;flex-direction:column;gap:8px}' +
      '#hg-fenetres-badges .hg-fa-badge{position:relative;width:48px;height:48px;min-height:48px;padding:0;font-size:1.4rem!important;border-radius:50%;display:flex;align-items:center;justify-content:center}' +
      '#hg-fenetres-badges .hg-fa-nb{position:absolute;top:-4px;right:-4px;min-width:20px;height:20px;border-radius:10px;font-size:.8rem;line-height:20px;text-align:center}' +
      '@media (max-width:520px){#hg-fenetres-badges{top:auto;bottom:88px;right:10px}}';
    doc.head.appendChild(s);
  }
  function dessiner() {
    styles();
    let zone = doc.getElementById('hg-fenetres-badges');
    if (!zone) { zone = doc.createElement('div'); zone.id = 'hg-fenetres-badges'; doc.body.appendChild(zone); }
    zone.innerHTML = '';
    for (const g of ['journal', 'meteo']) {
      files[g] = files[g].filter(x => typeof x.pertinent !== 'function' || x.pertinent());
      if (!files[g].length) continue;
      const b = doc.createElement('button');
      b.type = 'button';
      b.className = 'hg-fa-badge cpj-touche cpj-primaire';
      b.dataset.badge = g;
      b.title = TXT[g];
      b.setAttribute('aria-label', TXT[g]);
      b.innerHTML = '<i class="ti ' + ICONE[g] + '" aria-hidden="true"></i>' + (files[g].length > 1 ? '<span class="hg-fa-nb cpj-note">' + files[g].length + '</span>' : '');
      b.addEventListener('click', () => ouvrirBadge(g));
      zone.appendChild(b);
    }
    if (!zone.children.length) zone.remove();
  }
  // Clic du joueur : une fenêtre à la fois, jamais par-dessus une autre.
  function ouvrirBadge(g) {
    if (fenetreOuverte()) return;
    const x = files[g].shift();
    dessiner();
    if (x) x.ouvrir();
  }

  // Le serveur prévient de la fin de la première heure : l'état d'accueil est relu (les fenêtres en attente restent au badge).
  const gestionnaires = global.rpEvenementsPersonnageGestionnaires = global.rpEvenementsPersonnageGestionnaires || {};
  const avant = gestionnaires.accueil_heure_finie;
  gestionnaires.accueil_heure_finie = ev => { if (typeof avant === 'function') avant(ev); global.RPAccueil?.charger?.(); };

  global.RPFenetresAuto = Object.freeze({ demander, decision, marquer, fenetreOuverte, premiereHeure, ouvrirBadge,
    files: () => ({ journal: files.journal.map(x => x.type), meteo: files.meteo.map(x => x.type) }), montrees: () => montrees });
})(typeof window !== 'undefined' ? window : globalThis);
