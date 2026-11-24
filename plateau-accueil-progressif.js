/* ACCUEIL PROGRESSIF DES NOUVEAUX PJ ET PORTIER DES FENÊTRES AUTOMATIQUES.
   Module de la PR #1188 (ChatGPT, 24/11/2026), repris par la purge, bloc A (Claude, 24/11/2026) pour suivre la consigne
   de Fred mot pour mot (GAME-DESIGN-ACCUEIL-FENETRES-PNJ-GUIDE-20261124.md, points A.2 et A.3) :
   • A.2 — Bienvenue à la première connexion d'un nouveau personnage : texte exact de Fred (ville et pays de départ),
     icône réelle du bouton d'aide, fermeture par la croix SEULE (ni Échap, ni clic à côté), jamais recouverte, grande
     croix sur téléphone, emplacement de signature vide (PNJ d'accueil à créer par Fred). Mémorisée au serveur.
   • A.3 — Le temps de jeu cumulé et le moment de l'interview sont tenus par le SERVEUR (une seule réalité ; « d'une
     connexion à l'autre » vaut aussi d'un appareil à l'autre) : migration 20261124102000 (battement de présence, tirage
     entre 5 et 10 min, report de 5 min après une conversation avec un PNJ, interview forcée à 30 min, fin de la
     première heure). Ce module n'a plus de minuterie ni de localStorage : il affiche ce que dit accueil_etat.
   • Portier : pendant la première heure d'un nouveau venu, aucune fenêtre automatique (journal du jour, climat,
     proposition de notifications, PNJ guide) ; ensuite, pour tous, au plus UNE fenêtre automatique par connexion, les
     autres derrière un badge cliquable (journal, météo), jamais deux superposées. Pendant la première heure, jamais deux
     fenêtres automatiques à la suite : un délai de respiration sépare la quête d'accueil de Luthécia et l'interview
     (sauf l'interview forcée à 30 min, qui attend seulement que la fenêtre ouverte soit fermée).
   API gardée de #1188 (raccords de plateau-core.js, plateau-pnj.js, plateau-quete-accueil.js) : initialiser, verifier,
   noterDiscussionPnj, programmerJournal, entretienAutomatiqueAutorise, journalAutomatiqueAutorise,
   queteInitialeAutorisee, etat. Ajouts : bienvenueEnCours, marquer, demander, decision, fenetreOuverte ; alias
   RPFenetresAuto pour le portier. */
(function (global) {
  'use strict';
  const doc = global.document;
  if (!doc) return;

  const TXT = {
    bvTitre: 'Bienvenue à {ville} en {pays},',
    bv1: "Ça doit faire bizarre d'arriver en terre inconnue, mais sache que tu n'es pas seul : on est là pour t'aider.",
    bv2: "Demande aussi aux personnages que tu croiseras : ils seront très probablement en mesure de t'aider, de t'orienter.",
    bv3: "Je te laisse découvrir un peu la ville, on reviendra vers toi très rapidement. Et si tu as besoin d'aide, n'oublie pas : on est là.",
    bvFermer: 'Fermer le message de bienvenue',
    bvAide: 'Aide',
    journal: 'Journal du jour : à lire quand vous voulez',
    meteo: 'Événement climatique : à lire quand vous voulez'
  };
  // Ville et pays de départ lus dans les données du jeu (précision de Fred, 24/11/2026) : villeNom (data.js) pour TOUTES
  // les villes, nomPaysAffiche (plateau-core.js) pour le pays ; aucune table en dur, aucun repli sur le nom du jeu.
  const nomVilleJeu = (pays, ville) => { try { return (typeof global.villeNom === 'function' && global.villeNom(pays, ville)) || ''; } catch (_) { return ''; } };
  const nomPaysJeu = pays => { try { return (typeof global.nomPaysAffiche === 'function' && global.nomPaysAffiche(pays)) || ''; } catch (_) { return ''; } };
  // Ce qui compte comme « une fenêtre ouverte » (jamais deux à la fois).
  const OUVERTES = ['#hg-bienvenue', '#hg-accueil-interview', '#climat-explication', '#climat-gouvernement',
    '.modal-overlay.open', '#hg-notif-proposition', '#hg-bulle-pa'].join(',');
  const GROUPE = { journal_du_jour: 'journal', revue_presse: 'journal', climat: 'meteo', climat_accueil: 'meteo' };
  const ICONE = { journal: 'ti-news', meteo: 'ti-cloud-storm' };
  const RESPIRATION_MS = 120000;   // première heure : délai entre deux fenêtres automatiques
  const f = (t, v) => String(t).replace(/\{(\w+)\}/g, (_, k) => (v && v[k] != null ? v[k] : ''));
  const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

  let etat = null, montrees = 0, attenteEtat = 0, bienvenue = null, derniereFermeture = 0, ouverteAuto = null;
  const files = { journal: [], meteo: [] };

  // État d'accueil du serveur : celui que plateau-accueil-interview.js a lu (accueil_etat).
  const accueil = () => ((global.RPAccueil && typeof global.RPAccueil.etat === 'function') ? global.RPAccueil.etat() : null) || etat;
  const cal = () => (accueil() && accueil().calendrier) || null;
  const calendrierActif = () => !!(cal() && cal().actif);
  function premiereHeure() { const c = cal(); return !!(c && c.premiere_heure); }
  function fenetreOuverte() { return !!doc.querySelector(OUVERTES); }
  function bienvenueEnCours() { return !!bienvenue || !!(accueil() && accueil().bienvenue && accueil().bienvenue.a_voir); }

  // Une fenêtre automatique qui se ferme : point de départ du délai de respiration (première heure).
  function suivreFermeture(el) {
    if (!el) return;
    ouverteAuto = el;
    const obs = new MutationObserver(() => { if (!doc.body.contains(el) || (el.classList && el.classList.contains('modal-overlay') && !el.classList.contains('open'))) { derniereFermeture = Date.now(); ouverteAuto = null; obs.disconnect(); } });
    obs.observe(doc.body, { childList: true, subtree: true, attributes: true, attributeFilter: ['class'] });
  }
  function respire() { return !premiereHeure() || Date.now() - derniereFermeture >= RESPIRATION_MS; }

  // ------------------------------------------------------------------ portier
  // 'ouvrir' | 'attendre' | 'badge'
  function decision() {
    if (global.RPAccueil && !accueil() && attenteEtat < 10) return 'attendre';     // état du serveur pas encore lu (~20 s)
    if (bienvenueEnCours()) return 'attendre';
    if (premiereHeure()) return 'badge';
    if (montrees >= 1) return 'badge';
    if (fenetreOuverte()) return 'attendre';
    return 'ouvrir';
  }
  function demander(type, ouvrir, pertinent) {
    if (typeof ouvrir !== 'function') return;
    if (typeof pertinent === 'function' && !pertinent()) return;
    const d = decision(type);
    if (d === 'ouvrir') { montrees++; ouvrir(); return; }
    if (d === 'attendre') { if (!accueil()) attenteEtat++; setTimeout(() => demander(type, ouvrir, pertinent), 2000); return; }
    mettreEnBadge(type, ouvrir, pertinent);
  }
  function marquer() { montrees++; setTimeout(() => suivreFermeture(doc.querySelector('#hg-accueil-interview')), 0); }
  function mettreEnBadge(type, ouvrir, pertinent) {
    const g = GROUPE[type] || 'journal';
    if (!files[g].some(x => x.type === type)) files[g].push({ type, ouvrir, pertinent });
    dessinerBadges();
  }
  function styles() {
    if (doc.getElementById('hg-accueil-progressif-styles')) return;
    const s = doc.createElement('style');
    s.id = 'hg-accueil-progressif-styles';
    s.textContent = [
      '#hg-fenetres-badges{position:fixed;right:12px;top:72px;z-index:8500;display:flex;flex-direction:column;gap:8px}',
      '#hg-fenetres-badges .hg-fa-badge{position:relative;width:48px;height:48px;min-height:48px;padding:0;font-size:1.4rem!important;border-radius:50%;display:flex;align-items:center;justify-content:center}',
      '#hg-fenetres-badges .hg-fa-nb{position:absolute;top:-4px;right:-4px;min-width:20px;height:20px;border-radius:10px;font-size:.8rem;line-height:20px;text-align:center}',
      '@media (max-width:520px){#hg-fenetres-badges{top:auto;bottom:88px;right:10px}}',
      '#hg-bienvenue{position:fixed;inset:0;z-index:20000;display:flex;align-items:center;justify-content:center;padding:16px;box-sizing:border-box;background:rgba(6,12,20,.78)}',
      '#hg-bienvenue .hg-bienvenue-carte{position:relative;width:min(540px,100%);max-height:calc(100dvh - 32px);overflow-y:auto;box-sizing:border-box;padding:22px 22px 20px;font-size:1.05rem;line-height:1.55}',
      '#hg-bienvenue .hg-bienvenue-titre{margin:0 52px 12px 0;font-size:1.3rem}',
      '#hg-bienvenue p{margin:0 0 12px;font-size:1.05rem}',
      '#hg-bienvenue .hg-bienvenue-aide{display:flex;justify-content:center;margin:4px 0 14px}',
      '#hg-bienvenue .hg-bienvenue-aide .forum-btn{pointer-events:none;cursor:default;font-size:1rem}',
      '#hg-bienvenue .hg-bienvenue-croix{position:absolute;top:8px;right:8px;width:48px;height:48px;min-height:48px;font-size:1.8rem!important;line-height:1;padding:0}',
      '@media (max-width:520px){#hg-bienvenue .hg-bienvenue-croix{width:60px;height:60px;min-height:60px;font-size:2.2rem!important;top:4px;right:4px}#hg-bienvenue .hg-bienvenue-titre{margin-right:64px}}',
      '#hg-bienvenue .hg-bienvenue-signature{display:flex;align-items:center;gap:10px;margin-top:6px}',
      '#hg-bienvenue .hg-bienvenue-signature:empty{display:none}',
      '#hg-bienvenue .hg-bienvenue-portrait{width:56px;height:56px;border-radius:50%;object-fit:cover}'
    ].join('\n');
    doc.head.appendChild(s);
  }
  function dessinerBadges() {
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
    dessinerBadges();
    if (x) x.ouvrir();
  }

  // ------------------------------------------------------------------ bienvenue (A.2)
  function iconeAide() {
    const vrai = doc.querySelector('#hg-menu-existant button[onclick="openRulesView()"]');
    if (vrai) {
      const c = vrai.cloneNode(true);
      c.removeAttribute('onclick'); c.removeAttribute('id'); c.setAttribute('tabindex', '-1'); c.setAttribute('aria-hidden', 'true');
      return c.outerHTML;
    }
    return '<button type="button" class="forum-btn" tabindex="-1" aria-hidden="true"><i class="ti ti-book"></i> <span>' + esc(TXT.bvAide) + '</span></button>';
  }
  function rpc(fn, args) {
    if (typeof global.sbRpc !== 'function') return Promise.resolve(null);
    return Promise.resolve(global.sbRpc(fn, args || {})).catch(() => null);
  }
  function ouvrirBienvenue() {
    const bv = accueil() && accueil().bienvenue;
    if (!bv || !bv.a_voir || bienvenue || doc.getElementById('hg-bienvenue')) return false;
    styles();
    const ville = nomVilleJeu(bv.pays, bv.ville);
    const pays = nomPaysJeu(bv.pays);
    bienvenue = doc.createElement('section');
    bienvenue.id = 'hg-bienvenue';
    bienvenue.setAttribute('role', 'dialog');
    bienvenue.setAttribute('aria-modal', 'true');
    bienvenue.setAttribute('aria-labelledby', 'hg-bienvenue-titre');
    const signature = (bv.portrait ? '<img class="hg-bienvenue-portrait" alt="" src="' + esc(bv.portrait) + '">' : '') +
      (bv.signataire ? '<span class="cpj-note">' + esc(bv.signataire) + '</span>' : '');
    bienvenue.innerHTML = '<div class="hg-bienvenue-carte modal-box cpj-dialogue">' +
      '<button type="button" class="hg-bienvenue-croix cpj-touche" aria-label="' + esc(TXT.bvFermer) + '">×</button>' +
      '<h2 class="hg-bienvenue-titre" id="hg-bienvenue-titre">' + esc(f(TXT.bvTitre, { ville, pays })) + '</h2>' +
      '<p>' + esc(TXT.bv1) + '</p>' +
      '<div class="hg-bienvenue-aide">' + iconeAide() + '</div>' +
      '<p>' + esc(TXT.bv2) + '</p>' +
      '<p>' + esc(TXT.bv3) + '</p>' +
      '<div class="hg-bienvenue-signature" data-bienvenue-signature>' + signature + '</div></div>';
    const croix = bienvenue.querySelector('.hg-bienvenue-croix');
    croix.addEventListener('click', () => {
      const b = bienvenue; bienvenue = null;
      if (accueil() && accueil().bienvenue) accueil().bienvenue.a_voir = false;
      b.remove();
      derniereFermeture = Date.now();
      rpc('accueil_bienvenue_vue');
      verifier();
    });
    // Ni Échap ni clic à côté ; le focus reste sur la croix.
    bienvenue.addEventListener('keydown', e => {
      if (e.key === 'Escape') { e.preventDefault(); e.stopPropagation(); }
      if (e.key === 'Tab') { e.preventDefault(); croix.focus({ preventScroll: true }); }
    }, true);
    bienvenue.addEventListener('click', e => { if (e.target === bienvenue) { e.preventDefault(); e.stopPropagation(); } });
    doc.body.appendChild(bienvenue);
    // Toujours au-dessus : une fenêtre ajoutée après elle ne la recouvre pas.
    const garde = new MutationObserver(() => {
      if (!bienvenue) { garde.disconnect(); return; }
      if (doc.body.lastElementChild !== bienvenue) doc.body.appendChild(bienvenue);
    });
    garde.observe(doc.body, { childList: true });
    setTimeout(() => croix.focus({ preventScroll: true }), 30);
    return true;
  }

  // ------------------------------------------------------------------ API de #1188, désormais pilotée par le serveur
  function initialiser(e) {
    const nom = global.state?.char?.name;
    if (!nom || !e || e.ok !== true || e.personnage !== nom) return;
    etat = e;
    verifier();
  }
  // L'interview due (serveur) s'ouvre dès qu'aucune fenêtre n'est ouverte ; forcée (30 min), sans délai de respiration.
  // Ancien personnage (hors calendrier) : une fenêtre automatique par connexion, comme les autres.
  function entretienAutomatiqueAutorise() {
    if (bienvenueEnCours()) return false;
    if (calendrierActif()) {
      if (fenetreOuverte()) return false;
      return !!(cal().interview_forcee) || respire();
    }
    const d = decision('interview');
    return d === 'ouvrir';
  }
  function journalAutomatiqueAutorise() { return !bienvenueEnCours() && !premiereHeure(); }
  // Quête d'accueil de Luthécia (garde du Palais, #1188) : après les 5 minutes de découverte (serveur), jamais par-dessus
  // une fenêtre, et pas juste après une autre fenêtre automatique pendant la première heure.
  function queteInitialeAutorisee() {
    if (!calendrierActif()) return !bienvenueEnCours();
    return !!cal().decouverte_finie && !bienvenueEnCours() && !fenetreOuverte() && respire();
  }
  function verifier() {
    if (accueil() && accueil().bienvenue && accueil().bienvenue.a_voir && !bienvenue) ouvrirBienvenue();
    if (queteInitialeAutorisee() && typeof global.queteAccueilAfficherGardeDifferee === 'function') {
      const avant = doc.querySelector('#modal-quete-accueil.open');
      global.queteAccueilAfficherGardeDifferee();
      const apres = doc.querySelector('#modal-quete-accueil.open');
      if (!avant && apres) suivreFermeture(apres);
    }
  }
  // Journal du jour : par le portier (badge pendant la première heure ou après une autre fenêtre automatique).
  function programmerJournal(action, pertinent) { demander('journal_du_jour', action, pertinent); }
  // Conversation avec un PNJ : le serveur note l'instant de jeu (report de l'interview de 5 min, A.3).
  function noterDiscussionPnj() { if (calendrierActif() && !(cal().interview_due)) rpc('accueil_pnj_parle'); }

  // Le serveur prévient (journal d'événements) : fin de la découverte, fin de la première heure → relire l'état.
  const gestionnaires = global.rpEvenementsPersonnageGestionnaires = global.rpEvenementsPersonnageGestionnaires || {};
  for (const cle of ['accueil_decouverte_finie', 'accueil_heure_finie']) {
    const avant = gestionnaires[cle];
    gestionnaires[cle] = ev => {
      if (typeof avant === 'function') avant(ev);
      const r = global.RPAccueil?.charger?.();
      if (r && r.then) r.then(e => { if (e) initialiser(e); });
    };
  }
  // Le garde de Luthécia attend la fin du délai de respiration : nouvelle vérification régulière (aucune décision locale).
  if (typeof global.setInterval === 'function') global.setInterval(verifier, 5000);

  const portier = Object.freeze({ demander, decision, marquer, fenetreOuverte, premiereHeure, ouvrirBadge,
    files: () => ({ journal: files.journal.map(x => x.type), meteo: files.meteo.map(x => x.type) }), montrees: () => montrees });
  global.RPFenetresAuto = portier;
  global.RPAccueilProgressif = Object.freeze({
    initialiser, verifier, noterDiscussionPnj, programmerJournal,
    entretienAutomatiqueAutorise, journalAutomatiqueAutorise, queteInitialeAutorisee,
    bienvenueEnCours, ouvrirBienvenue, marquer, demander, decision, fenetreOuverte,
    etat: () => (cal() ? Object.assign({}, cal()) : null), TXT
  });
})(typeof window !== 'undefined' ? window : globalThis);
