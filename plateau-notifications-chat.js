// NOTIFICATIONS DU NAVIGATEUR, POUR LE CHAT UNIQUEMENT (Fred, 24/11/2026, purge A.8).
//  • Proposées par une bulle (avec « ? ») la première fois qu'un message de chat arrive en jeu ; jamais pendant la
//    première heure de jeu d'un nouveau venu (le serveur le dit : notifications_chat_lire → a_proposer) : la bulle attend.
//  • Un réglage pour les activer ou les couper (liste des conversations du chat). Choix gardé au serveur.
//  • Une notification par interlocuteur jusqu'à la reconnexion (retour sur l'onglet ou rechargement), et pas plus d'une
//    par heure. Seulement quand le jeu n'est pas sous les yeux du joueur (onglet caché ou fenêtre sans focus).
//  • Jamais le texte du message : le nom et le lieu, ou « Quelqu'un vous a parlé » si l'interlocuteur est caché ou anonyme.
//  • Les messages du PNJ guide (auteur « pnj:… ») n'en déclenchent pas. Pas de courriel.
(function (global) {
  'use strict';
  const doc = global.document;
  if (!doc) return;
  const TXT = {
    propose: 'Être prévenu quand quelqu’un vous parle, même quand le jeu est en arrière-plan ?',
    aide: 'Votre navigateur affichera une petite alerte avec le nom de la personne et le lieu, jamais le contenu du message. Vous pouvez la couper à tout moment dans le chat.',
    activer: 'Activer',
    nonMerci: 'Non merci',
    titre: 'Human Gambit',
    parle: '{nom} vous a parlé ({lieu})',
    quelquun: 'Quelqu’un vous a parlé',
    reglage: 'Notifications du chat',
    actives: 'activées',
    coupees: 'coupées',
    couper: 'Couper',
    refusees: 'Votre navigateur bloque les notifications : autorisez-les dans ses réglages pour ce site.',
    rue: 'dans la rue',
    aideBouton: 'Explication'
  };
  const UNE_HEURE = 3600 * 1000;
  const CLE_HEURE = 'hg-notif-chat-derniere';
  const f = (t, v) => String(t).replace(/\{(\w+)\}/g, (_, k) => (v && v[k] != null ? v[k] : ''));
  const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  let reglage = null, chargement = null, notifies = new Set(), bulleOuverte = false;

  const supporte = () => typeof global.Notification === 'function';
  async function rpc(fn, args) {
    if (typeof global.sbRpc !== 'function') return null;
    try { const r = await global.sbRpc(fn, args || {}); return Array.isArray(r) ? r[0] : r; } catch (_) { return null; }
  }
  async function lire(force) {
    if (reglage && !force) return reglage;
    if (!chargement) chargement = rpc('notifications_chat_lire').then(r => { if (r && r.ok) reglage = r; return reglage; }).finally(() => { chargement = null; });
    return chargement;
  }
  async function fixer(active) {
    const r = await rpc('notifications_chat_fixer', { p_active: !!active });
    if (r && r.ok) reglage = r;
    return reglage;
  }
  // Reconnexion : le joueur revient sur le jeu → chaque interlocuteur peut de nouveau être signalé une fois.
  doc.addEventListener('visibilitychange', () => { if (!doc.hidden) notifies = new Set(); });

  function lieuIci() {
    const s = (typeof global.state !== 'undefined' && global.state) || {};
    if (!s.currentBuilding) return TXT.rue;
    try { if (typeof global.nomBatimentTraduit === 'function') { const n = global.nomBatimentTraduit(s.currentBuilding); if (n) return n; } } catch (_) {}
    try { if (typeof BUILDINGS !== 'undefined' && BUILDINGS[s.currentBuilding] && BUILDINGS[s.currentBuilding].name) return String(BUILDINGS[s.currentBuilding].name).replace(/&amp;/g, '&'); } catch (_) {}
    return s.currentBuilding;
  }
  // Le texte d'une notification : jamais le message.
  function texteNotification(auteur, libelle) {
    const anonyme = !auteur || String(auteur).startsWith('masque:') || !libelle;
    return anonyme ? TXT.quelquun : f(TXT.parle, { nom: libelle, lieu: lieuIci() });
  }
  function derniereHeure() { try { return Number(global.localStorage.getItem(CLE_HEURE)) || 0; } catch (_) { return 0; } }
  function noterHeure() { try { global.localStorage.setItem(CLE_HEURE, String(Date.now())); } catch (_) {} }

  // Appelé par verifierNotificationChat (plateau-multijoueur.js) quand un message non lu arrive.
  async function messageRecu(nonLu, libelle) {
    if (!nonLu || nonLu.salon || !nonLu.auteur) return;
    if (String(nonLu.auteur).startsWith('pnj:')) return;                // PNJ guide : jamais de notification
    const r = await lire();
    if (!r) return;
    if (!r.proposee) { if (supporte()) proposer(); return; }
    if (!r.active || !supporte() || global.Notification.permission !== 'granted') return;
    const auPremierPlan = !doc.hidden && (typeof doc.hasFocus !== 'function' || doc.hasFocus());
    if (auPremierPlan) return;
    const cle = String(nonLu.auteur);
    if (notifies.has(cle)) return;                                      // une par interlocuteur jusqu'à la reconnexion
    if (Date.now() - derniereHeure() < UNE_HEURE) return;               // pas plus d'une par heure
    notifies.add(cle); noterHeure();
    try { new global.Notification(TXT.titre, { body: texteNotification(nonLu.auteur, libelle), tag: 'hg-chat' }); } catch (_) {}
  }

  // ---------------------------------------------------------------- bulle de proposition (une fois, jamais en première heure)
  function styles() {
    if (doc.getElementById('hg-notif-styles')) return;
    const s = doc.createElement('style');
    s.id = 'hg-notif-styles';
    s.textContent = '#hg-notif-proposition{position:fixed;right:16px;bottom:80px;z-index:9200;width:min(340px,calc(100vw - 32px));box-sizing:border-box}' +
      '#hg-notif-proposition p{margin:0 0 .6rem;font-size:1rem}' +
      '#hg-notif-proposition .hg-notif-actions{display:flex;gap:8px;flex-wrap:wrap}' +
      '.hg-notif-q{display:inline-flex;align-items:center;justify-content:center;width:28px;height:28px;min-height:28px!important;padding:0;border-radius:50%;margin-left:6px;vertical-align:middle}' +
      '.hg-notif-reglage{display:flex;align-items:center;gap:6px;flex-wrap:wrap;padding:.4rem .6rem;font-size:1rem}';
    doc.head.appendChild(s);
  }
  // Rond « ? » : bulle de deux phrases au survol, au focus et au toucher (même bulle que les jauges : .hg-jauge-bulle).
  function brancherAide(bouton) {
    const montrer = () => {
      let b = doc.getElementById('hg-notif-aide');
      if (!b) { b = doc.createElement('div'); b.id = 'hg-notif-aide'; b.className = 'hg-jauge-bulle'; b.setAttribute('role', 'tooltip'); doc.body.appendChild(b); }
      b.textContent = TXT.aide; b.hidden = false;
      const r = bouton.getBoundingClientRect(), vw = global.innerWidth || 1024, l = Math.min(300, vw - 32);
      b.style.maxWidth = l + 'px'; b.style.left = Math.max(16, Math.min(r.left, vw - l - 16)) + 'px';
      const h = b.getBoundingClientRect().height; b.style.top = Math.max(8, r.top - h - 8) + 'px';
    };
    const cacher = () => { const b = doc.getElementById('hg-notif-aide'); if (b) b.hidden = true; };
    bouton.addEventListener('mouseenter', montrer); bouton.addEventListener('mouseleave', cacher);
    bouton.addEventListener('focus', montrer); bouton.addEventListener('blur', cacher);
    bouton.addEventListener('click', e => { e.stopPropagation(); const b = doc.getElementById('hg-notif-aide'); if (b && !b.hidden) cacher(); else montrer(); });
  }
  function proposer() {
    if (bulleOuverte || doc.getElementById('hg-notif-proposition')) return;
    if (!reglage || !reglage.a_proposer) return;                        // première heure : la bulle attend
    const portier = global.RPFenetresAuto;
    if (portier) {
      const d = portier.decision('notifications');
      if (d !== 'ouvrir') return;                                       // proposée à un prochain message, jamais par-dessus
      portier.marquer('notifications');
    }
    styles();
    bulleOuverte = true;
    const el = doc.createElement('div');
    el.id = 'hg-notif-proposition';
    el.className = 'modal-box cpj-dialogue';
    el.setAttribute('role', 'dialog');
    el.innerHTML = '<p>' + esc(TXT.propose) + '<button type="button" class="hg-notif-q cpj-touche" aria-label="' + esc(TXT.aideBouton) + '">?</button></p>' +
      '<div class="hg-notif-actions"><button type="button" class="cpj-touche cpj-primaire" data-notif="oui">' + esc(TXT.activer) + '</button>' +
      '<button type="button" class="cpj-touche" data-notif="non">' + esc(TXT.nonMerci) + '</button></div>';
    brancherAide(el.querySelector('.hg-notif-q'));
    el.addEventListener('click', async e => {
      const b = e.target.closest('[data-notif]');
      if (!b) return;
      const oui = b.dataset.notif === 'oui';
      let accorde = false;
      if (oui && supporte()) { try { accorde = (await global.Notification.requestPermission()) === 'granted'; } catch (_) { accorde = false; } }
      await fixer(oui && accorde);
      el.remove(); bulleOuverte = false;
      const a = doc.getElementById('hg-notif-aide'); if (a) a.hidden = true;
    });
    doc.body.appendChild(el);
  }

  // ---------------------------------------------------------------- réglage (liste des conversations du chat)
  function reglageHtml() {
    if (!supporte() || !reglage) return '';
    const actif = reglage.active && global.Notification.permission === 'granted';
    return '<div class="hg-notif-reglage cpj-note" data-notif-reglage>' + esc(TXT.reglage) + ' : <strong>' + esc(actif ? TXT.actives : TXT.coupees) + '</strong>' +
      '<button type="button" class="cpj-touche" data-notif-basculer="' + (actif ? 'couper' : 'activer') + '">' + esc(actif ? TXT.couper : TXT.activer) + '</button>' +
      '<button type="button" class="hg-notif-q cpj-touche" aria-label="' + esc(TXT.aideBouton) + '">?</button></div>';
  }
  async function insererReglage(conteneur) {
    if (!conteneur || !supporte()) return;
    styles();
    await lire();
    conteneur.querySelector('[data-notif-reglage]')?.remove();
    const h = reglageHtml();
    if (!h) return;
    conteneur.insertAdjacentHTML('afterbegin', h);
    const zone = conteneur.querySelector('[data-notif-reglage]');
    brancherAide(zone.querySelector('.hg-notif-q'));
    zone.querySelector('[data-notif-basculer]').addEventListener('click', async e => {
      const activer = e.currentTarget.dataset.notifBasculer === 'activer';
      if (activer) {
        let p = global.Notification.permission;
        if (p === 'default') { try { p = await global.Notification.requestPermission(); } catch (_) { p = 'denied'; } }
        if (p !== 'granted') { await fixer(false); if (typeof global.showToast === 'function') global.showToast(TXT.reglage, TXT.refusees, false); }
        else await fixer(true);
      } else await fixer(false);
      insererReglage(conteneur);
    });
  }

  global.RPNotifChat = Object.freeze({ messageRecu, insererReglage, texteNotification, lire, TXT });
})(typeof window !== 'undefined' ? window : globalThis);
