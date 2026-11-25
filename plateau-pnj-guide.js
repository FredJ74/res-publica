// PNJ GUIDE DES NOUVEAUX JOUEURS — écran (Fred, 24/11/2026, purge A.10). Le serveur décide de tout (migration
// 20261124106000_pnj_guide, /api/chat?mode=guide) ; l'écran :
//  • demande le message du jour UNE fois par connexion (et à la fin de la première heure), seulement pour un nouveau venu
//    hors de sa première heure, quand aucune fenêtre n'est ouverte ; le serveur dit s'il y a lieu (guide_etat_lire) ;
//  • affiche les messages du guide dans le chat avec le badge « PNJ » ; sous chaque message de guide, le bouton
//    « Je me débrouille, merci » arrête définitivement les deux voix (guide_arreter) ;
//  • transmet la réponse du joueur au PNJ (action « repondre ») au lieu de l'envoi de chat entre joueurs ;
//  • relance de l'interview d'accueil (Fred, 25/11/2026, migration 20261125140000) : sous ce message de la journaliste,
//    « Reprendre l'interview » ouvre « Mes objectifs », et « Ne plus me proposer d'interview d'accueil » la coupe pour de bon
//    (accueil_interview_refuser). Sans la migration, aucune relance n'arrive et rien ne change.
(function (global) {
  'use strict';
  const doc = global.document;
  if (!doc) return;
  const TXT = {
    badge: 'PNJ',
    debrouille: 'Je me débrouille, merci',
    arrete: 'Entendu : ils ne vous écriront plus.',
    epuise: 'Ce PNJ ne peut plus vous répondre aujourd’hui.',
    indispo: 'Le PNJ ne peut pas répondre pour le moment.',
    aideBadge: 'Personnage non joueur',
    reprendre: "Reprendre l'interview",
    refuser: "Ne plus me proposer d'interview d'accueil",
    refusee: "Entendu : l'interview d'accueil ne vous sera plus proposée."
  };
  let demande = false, arrete = false, refusee = false;
  const estPnj = id => typeof id === 'string' && id.startsWith('pnj:');
  const nomPnj = id => estPnj(id) ? id.slice(4) : id;
  async function rpc(fn, args) {
    if (typeof global.sbRpc !== 'function') return null;
    try { const r = await global.sbRpc(fn, args || {}); return Array.isArray(r) ? r[0] : r; } catch (_) { return null; }
  }
  async function api(corps) {
    try {
      if (typeof global.rpAuthAssurerSession === 'function') await global.rpAuthAssurerSession();
      const jeton = typeof global.rpAuthJeton === 'function' ? global.rpAuthJeton() : null;
      if (!jeton) return null;
      const r = await fetch('/api/chat?mode=guide', { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + jeton }, body: JSON.stringify(corps) });
      return await r.json().catch(() => null);
    } catch (_) { return null; }
  }
  const accueil = () => global.RPAccueil?.etat?.() || null;

  // Une fois par connexion : jamais pendant la première heure, jamais pendant qu'une fenêtre est ouverte.
  async function verifier() {
    if (demande || arrete) return;
    const e = accueil();
    if (!e || !e.calendrier || !e.calendrier.actif || e.calendrier.premiere_heure) return;
    if (global.RPFenetresAuto && global.RPFenetresAuto.fenetreOuverte()) return;
    demande = true;
    const s = await rpc('guide_etat_lire');
    if (!s || s.ok !== true) { demande = false; return; }
    if (s.interview_refusee) refusee = true;
    if (s.arrete) { arrete = true; return; }
    if (!s.a_ecrire) return;
    await api({ action: 'prochain' });
  }
  async function arreter() {
    const r = await rpc('guide_arreter');
    if (r && r.ok) {
      arrete = true;
      doc.querySelectorAll('[data-guide-debrouille]').forEach(b => b.remove());
      if (typeof global.showToast === 'function') global.showToast(TXT.debrouille, TXT.arrete, true);
    }
  }
  // Relance de l'interview : « Mes objectifs », où l'interview attend.
  async function reprendreInterview() {
    try { if (global.RPAccueil && typeof global.RPAccueil.charger === 'function') await global.RPAccueil.charger(); } catch (_) {}
    if (typeof global.afficherObjectifsSecrets === 'function') global.afficherObjectifsSecrets();
  }
  async function refuserInterview() {
    const r = await rpc('accueil_interview_refuser');
    if (r && r.ok) {
      refusee = true;
      doc.querySelectorAll('[data-guide-relance]').forEach(b => b.remove());
      try { if (global.RPAccueil && typeof global.RPAccueil.charger === 'function') await global.RPAccueil.charger(); } catch (_) {}
      if (typeof global.showToast === 'function') global.showToast(TXT.refuser, TXT.refusee, true);
    }
  }
  // Réponse du joueur au PNJ : le serveur pose son message et fait répondre le PNJ (5 par jour et par PNJ).
  async function repondre(conversationId, texte) {
    const autre = String(conversationId || '').split('__').find(estPnj);
    if (!autre) return { ok: false, raison: 'pas_un_pnj' };
    const r = await api({ action: 'repondre', pnj: nomPnj(autre), message: texte });
    if (!r) return { ok: false, raison: 'indisponible', texte: TXT.indispo };
    if (r.ok !== true) return { ok: false, raison: r.raison, texte: r.raison === 'reponses_epuisees' ? TXT.epuise : TXT.indispo };
    return r;
  }
  // Rendu dans le chat (appelé par plateau-multijoueur.js).
  function badgeHtml() { return ' <span class="hg-guide-badge cpj-note" title="' + TXT.aideBadge + '">' + TXT.badge + '</span>'; }
  function boutonHtml(message) {
    if (!message) return '';
    if (String(message.id || '').startsWith('guide-relance-')) {
      if (refusee) return '';
      return '<div data-guide-relance><button type="button" class="cpj-touche cpj-primaire" onclick="RPPnjGuide.reprendreInterview()">' + TXT.reprendre + '</button> ' +
        '<button type="button" class="cpj-touche" onclick="RPPnjGuide.refuserInterview()">' + TXT.refuser + '</button></div>';
    }
    if (arrete || !String(message.id || '').startsWith('guide-')) return '';
    return '<div><button type="button" class="cpj-touche" data-guide-debrouille onclick="RPPnjGuide.arreter()">' + TXT.debrouille + '</button></div>';
  }
  function styles() {
    if (doc.getElementById('hg-guide-styles')) return;
    const s = doc.createElement('style');
    s.id = 'hg-guide-styles';
    s.textContent = '.hg-guide-badge{display:inline-block;border:1px solid currentColor;border-radius:3px;padding:0 4px;font-size:.8rem;line-height:1.3;vertical-align:1px}' +
      '[data-guide-debrouille],[data-guide-relance] button{margin-top:.35rem;font-size:1rem!important;min-height:36px}';
    doc.head.appendChild(s);
  }
  styles();

  const gestionnaires = global.rpEvenementsPersonnageGestionnaires = global.rpEvenementsPersonnageGestionnaires || {};
  const avant = gestionnaires.accueil_heure_finie;
  gestionnaires.accueil_heure_finie = ev => { if (typeof avant === 'function') avant(ev); demande = false; setTimeout(verifier, 4000); };
  if (!global.__RP_GUIDE_SANS_MINUTERIE && typeof global.setInterval === 'function') { setTimeout(verifier, 15000); global.setInterval(verifier, 20000); }

  global.RPPnjGuide = Object.freeze({ verifier, arreter, repondre, reprendreInterview, refuserInterview, estPnj, nomPnj, badgeHtml, boutonHtml, TXT });
})(typeof window !== 'undefined' ? window : globalThis);
