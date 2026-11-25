// CHRONIQUE DE L'EMPIRE (Fred, 25/11/2026, mission de jour, bloc 2 ; migration 20261125200000) : le journal des événements
// s'ouvre sur deux onglets, « Mes événements » (le journal actuel, inchangé) et « L'empire » (la chronique publique du pays du
// joueur : actes illégaux connus, procès, décisions publiques, incidents climatiques, bagarres, rencontres en forêt).
// LE SERVEUR DÉCIDE DE TOUT (chronique_empire_lire) : quels faits, dans quel pays, et si l'auteur est nommé (seulement s'il est
// publiquement connu pour cet acte). L'écran ne fait que mettre chaque fait en une phrase courte, lisible par un enfant, avec la
// date au format unique et un lien vers le lieu quand on est dans la même ville. Sans la migration, l'onglet n'apparaît pas.
(function (global) {
  'use strict';
  const doc = global.document;
  if (!doc) return;
  const TXT = {
    mes: 'Mes événements',
    empire: 'L’empire',
    vide: 'Rien à signaler dans l’empire ces derniers jours.',
    plus: 'Voir plus ancien',
    charge: 'Chargement de la chronique…',
    indispo: 'La chronique ne répond pas pour le moment.',
    a: 'à {lieu}',
    lieuVille: '{batiment}, {ville}',
    // Actes illégaux : sans auteur connu / avec auteur connu.
    acte_voler: ['Un vol a été commis {lieu}.', '{auteur} a commis un vol {lieu}.'],
    acte_rumeur: ['Une rumeur calomnieuse{sur} circule {lieu}.', '{auteur} a lancé une rumeur calomnieuse{sur} {lieu}.'],
    acte_neutraliser: ['Quelqu’un a été agressé {lieu}.', '{auteur} a agressé quelqu’un {lieu}.'],
    acte_effraction: ['Une porte a été forcée {lieu}.', '{auteur} a forcé une porte {lieu}.'],
    acte_explosifs: ['Une explosion a secoué {lieu}.', '{auteur} a fait sauter une charge {lieu}.'],
    acte_autre: ['Un acte illégal a été signalé {lieu}.', '{auteur} a commis un acte illégal {lieu}.'],
    sur: ' sur {cible}',
    arrestation: '{auteur} a été arrêté à {ville}{motif}.',
    arrestation_qhs: '{auteur} a été arrêté à {ville}{motif} et conduit au quartier de haute sécurité.',
    motif: ' ({m})',
    verdict: 'Le tribunal de {ville} a jugé {auteur}{peine}.',
    peine: ' : {p}',
    proces: '{auteur} est renvoyé devant le tribunal de {ville}{motif}.',
    pour: ' pour {m}',
    climat_canicule: 'Canicule à {ville} : il fait trop chaud pour travailler dehors.',
    climat_crue: 'Crue à {ville} : l’eau monte dans certains quartiers.',
    climat_orage: 'Orage sur {ville}.',
    climat_brouillard: 'Brouillard épais sur {ville}.',
    climat_blizzard: 'Blizzard sur {ville} : tout le monde se met à l’abri.',
    climat_autre: 'Intempéries à {ville}.',
    bagarre: 'Une bagarre a éclaté {lieu}.',
    foret_ours: 'Un ours a surgi dans la forêt de Krasnov.',
    foret_loup: 'Un loup a attaqué dans la forêt de Krasnov.',
    foret_meute: 'Une meute de loups a surgi dans la forêt de Krasnov.',
    foret_vaincu: ' Il a été repoussé.',
    foret_vaincue: ' Elle a été repoussée.',
    foret_fuite: ' Le bûcheron a pris la fuite.'
  };
  const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  // Remplace {x} par une valeur DÉJÀ échappée (ou du HTML construit ici).
  const f = (t, v) => String(t).replace(/\{(\w+)\}/g, (_, k) => (v && v[k] != null ? v[k] : ''));
  const court = (s, n) => { s = String(s || '').replace(/\s+/g, ' ').trim(); return s.length > n ? s.slice(0, n - 1) + '…' : s; };
  let disponible = null, onglet = 'mes', faits = [], fin = false, chargement = false, pays = null;

  async function rpc(args) {
    if (typeof global.sbRpc !== 'function') return null;
    try { const r = await global.sbRpc('chronique_empire_lire', args || {}); return Array.isArray(r) ? r[0] : r; } catch (_) { return null; }
  }
  const W = () => global.WORLD || (typeof WORLD !== 'undefined' ? WORLD : {});
  const B = () => global.BUILDINGS || (typeof BUILDINGS !== 'undefined' ? BUILDINGS : {});
  const st = () => global.state || (typeof state !== 'undefined' ? state : {});
  const nomVille = v => (W()[pays] && W()[pays][v] && W()[pays][v].name) || v || '';
  function nomBatiment(b) { const x = B()[b]; return x ? (x.shortName || x.name || b) : ''; }
  // Le lieu, avec un lien quand il est dans la ville où l'on se trouve (le serveur juge le déplacement).
  function lieu(fait) {
    const ville = esc(nomVille(fait.ville)), nb = fait.batiment ? nomBatiment(fait.batiment) : '';
    if (!nb) return f(TXT.a, { lieu: ville });
    const s = st(), ici = s.country === pays && s.currentCity === fait.ville && B()[fait.batiment];
    const b = ici ? '<button type="button" class="hg-chron-lieu" data-batiment="' + esc(fait.batiment) + '">' + esc(nb) + '</button>' : esc(nb);
    return f(TXT.a, { lieu: f(TXT.lieuVille, { batiment: b, ville }) });
  }
  function cleActe(a) {
    a = String(a || '');
    if (/rumeur/.test(a)) return 'acte_rumeur';
    if (/vol(er)?$|^vol|pickpocket|cambriol/.test(a)) return 'acte_voler';
    if (/neutralis|agress|assassin|frapper/.test(a)) return 'acte_neutraliser';
    if (/effraction|crochet|forcer|serrure/.test(a)) return 'acte_effraction';
    if (/explosif|bombe|attentat/.test(a)) return 'acte_explosifs';
    return 'acte_autre';
  }
  function phrase(fait) {
    const p = fait.params || {}, auteur = fait.auteur ? '<b>' + esc(fait.auteur) + '</b>' : null;
    const ville = esc(nomVille(fait.ville));
    switch (fait.cat) {
      case 'acte': {
        const t = TXT[cleActe(fait.cle)];
        return f(t[auteur ? 1 : 0], { auteur, lieu: lieu(fait), sur: p.cible ? f(TXT.sur, { cible: esc(p.cible) }) : '' });
      }
      case 'arrestation':
        return f(fait.cle === 'qhs' ? TXT.arrestation_qhs : TXT.arrestation, { auteur, ville, motif: p.motif ? f(TXT.motif, { m: esc(court(p.motif, 60)) }) : '' });
      case 'verdict':
        return f(TXT.verdict, { auteur, ville, peine: p.peine ? f(TXT.peine, { p: esc(court(p.peine, 60)) }) : '' });
      case 'proces':
        return f(TXT.proces, { auteur, ville, motif: p.motif ? f(TXT.pour, { m: esc(court(p.motif, 80)) }) : '' });
      case 'public':
        return esc(court(p.texte, 220));
      case 'climat':
        return f(TXT['climat_' + fait.cle] || TXT.climat_autre, { ville });
      case 'bagarre':
        return f(TXT.bagarre, { lieu: lieu(fait) });
      case 'foret': {
        const base = TXT['foret_' + fait.cle] || TXT.foret_loup;
        const suite = p.issue === 'vaincu' ? (fait.cle === 'meute' ? TXT.foret_vaincue : TXT.foret_vaincu) : p.issue === 'fuite' ? TXT.foret_fuite : '';
        return base + suite;
      }
      default: return '';
    }
  }
  const heure = q => (typeof global.formaterHorodatageJournal === 'function' && global.formaterHorodatageJournal(q)) || '';

  function zone() { return doc.getElementById('journal-empire'); }
  function rendre(message) {
    const z = zone(); if (!z) return;
    let h = '';
    for (const x of faits) {
      const t = phrase(x); if (!t) continue;
      h += '<div class="journal-entry hg-chron-' + esc(x.cat) + '"><span class="journal-time">' + esc(heure(x.quand)) + '</span><span class="journal-text">' + t + '</span></div>';
    }
    if (!h) h = '<p class="cpj-note hg-chron-vide">' + esc(message || TXT.vide) + '</p>';
    else if (!fin) h += '<button type="button" class="cpj-touche hg-chron-plus">' + esc(TXT.plus) + '</button>';
    z.innerHTML = h;
  }
  async function charger(suite) {
    if (chargement) return;
    chargement = true;
    if (!suite) { faits = []; fin = false; rendre(TXT.charge); }
    const avant = suite && faits.length ? faits[faits.length - 1].quand : null;
    const r = await rpc(avant ? { p_avant: avant, p_limite: 40 } : { p_limite: 40 });
    chargement = false;
    if (!r || r.ok !== true) { rendre(TXT.indispo); return; }
    pays = r.pays || pays;
    const neufs = Array.isArray(r.faits) ? r.faits : [];
    const vus = new Set(faits.map(x => x.ref));
    faits = faits.concat(neufs.filter(x => x && !vus.has(x.ref)));
    fin = neufs.length < 40;
    rendre();
  }
  function choisir(o) {
    onglet = o;
    const j = doc.getElementById('journal'), z = zone();
    if (j) j.hidden = o !== 'mes';
    if (z) z.hidden = o !== 'empire';
    doc.querySelectorAll('.hg-chron-onglets [role="tab"]').forEach(b => b.setAttribute('aria-selected', String(b.dataset.onglet === o)));
    if (o === 'empire') charger(false);
  }
  function installer() {
    const store = doc.getElementById('journal-store'), j = doc.getElementById('journal');
    if (!store || !j || doc.querySelector('.hg-chron-onglets')) return;
    const barre = doc.createElement('div');
    barre.className = 'hg-chron-onglets'; barre.setAttribute('role', 'tablist'); barre.hidden = true;
    barre.innerHTML = '<button type="button" role="tab" data-onglet="mes" aria-selected="true">' + esc(TXT.mes) + '</button>' +
      '<button type="button" role="tab" data-onglet="empire" aria-selected="false">' + esc(TXT.empire) + '</button>';
    barre.addEventListener('click', e => { const b = e.target.closest('[data-onglet]'); if (b) choisir(b.dataset.onglet); });
    j.parentNode.insertBefore(barre, j);
    const z = doc.createElement('div');
    z.id = 'journal-empire'; z.className = 'journal'; z.hidden = true; z.setAttribute('role', 'tabpanel');
    z.style.cssText = 'flex:1;overflow-y:auto;padding:.4rem';
    z.addEventListener('click', e => {
      const l = e.target.closest('.hg-chron-lieu');
      if (l && typeof global.enterBuilding === 'function') { global.enterBuilding(l.dataset.batiment); return; }
      if (e.target.closest('.hg-chron-plus')) charger(true);
    });
    j.parentNode.insertBefore(z, j.nextSibling);
    const s = doc.createElement('style');
    s.textContent = '.hg-chron-onglets{display:flex;gap:.3rem;padding:.35rem .5rem;border-bottom:1px solid #2a3442;flex-shrink:0}' +
      '.hg-chron-onglets[hidden]{display:none}.hg-chron-onglets button{flex:1;min-height:36px;font-size:.95rem;background:#1b2531;color:#a9b6c4;border:1px solid #344354;border-radius:4px;cursor:pointer}' +
      '.hg-chron-onglets button[aria-selected="true"]{background:#344354;color:#e5c477;border-color:#a98d56}' +
      '#journal-empire[hidden],#journal[hidden]{display:none!important}.hg-chron-lieu{background:none;border:none;padding:0;color:#e5c477;text-decoration:underline;cursor:pointer;font:inherit}' +
      '.hg-chron-plus{display:block;margin:.5rem auto;min-height:36px}.hg-chron-vide{padding:.5rem}';
    doc.head.appendChild(s);
    // Le serveur dit si la chronique existe (migration appliquée) : sinon l'onglet reste caché.
    const sonder = async () => {
      if (disponible !== null || store.style.display !== 'flex') return;
      disponible = false;
      const r = await rpc({ p_limite: 1 });
      disponible = !!(r && r.ok === true);
      if (disponible) { pays = r.pays; barre.hidden = false; }
      else disponible = null;   // nouvel essai à la prochaine ouverture
    };
    new global.MutationObserver(sonder).observe(store, { attributes: true, attributeFilter: ['style'] });
  }
  if (doc.readyState === 'loading') doc.addEventListener('DOMContentLoaded', installer); else installer();

  global.RPChroniqueEmpire = Object.freeze({ phrase, choisir, charger, installer, TXT, etat: () => ({ disponible, onglet, faits: faits.length, pays }) });
})(typeof window !== 'undefined' ? window : globalThis);
