// SOUVENIRS DES VILLES (Fred, 25/11/2026 au soir, mission du soir, point 3.1 ; migration 20261125600000).
// Chaque souvenir des listes de l'armoire s'achète SUR PLACE, auprès d'un PNJ de sa ville. Le jeu n'indique jamais où :
// cet écran ne connaît aucun lieu. Il demande au serveur ce qui se vend dans la pièce où l'on se trouve (souvenirs_ici)
// et, s'il y a quelque chose, propose l'ordre « Acheter un souvenir ». L'achat (souvenir_acheter) est tranché par le
// serveur : présence, prix, paiement en liquide, place dans l'inventaire. Sans la migration, aucun ordre n'apparaît.
(function (global) {
  'use strict';
  const doc = global.document;
  if (!doc) return;
  const TXT = {
    ordre: 'Acheter un souvenir',
    ordreDesc: 'Un souvenir de la ville, à ranger dans une armoire à souvenirs ou à offrir.',
    titre: 'Souvenirs',
    propose: '{pnj} vous propose :',
    acheter: 'Acheter — {prix} {devise}',
    achete: '{nom} est à vous (−{prix} {devise}).',
    rien: 'Plus rien à vendre ici pour le moment.',
    r_fonds_insuffisants: 'Il vous faut {requis} en liquide.',
    r_inventaire_plein: 'Votre inventaire est plein.',
    r_pas_vendu_ici: 'Ce souvenir ne se vend pas ici.',
    r_autre: 'L’achat n’a pas abouti.'
  };
  const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const f = (t, v) => String(t).replace(/\{(\w+)\}/g, (_, k) => (v && v[k] != null ? v[k] : ''));
  const uuid = () => (global.crypto && typeof global.crypto.randomUUID === 'function') ? global.crypto.randomUUID()
    : '00000000-0000-4000-8000-' + String(Date.now()).slice(-12).padStart(12, '0');
  const st = () => (typeof global.state !== 'undefined' ? global.state : null);
  const cleIci = () => { const s = st(); return s ? [s.char && s.char.name, s.country, s.currentCity, s.currentBuilding, s.currentRoom].join('|') : ''; };
  let cache = { cle: null, liste: null, enCours: false };
  let achatEnCours = false;

  async function rpc(fn, args) {
    if (typeof global.sbRpc !== 'function') return null;
    try { const r = await global.sbRpc(fn, args || {}); return Array.isArray(r) ? r[0] : r; } catch (_) { return null; }
  }
  // Lecture serveur de la pièce courante, une fois par pièce ; puis on redessine les ordres si l'on n'a pas bougé.
  function lire(buildingId, roomId) {
    const cle = cleIci();
    if (cache.cle === cle && (cache.liste || cache.enCours)) return;
    cache = { cle, liste: null, enCours: true };
    rpc('souvenirs_ici').then(r => {
      if (cache.cle !== cle) return;
      cache.enCours = false;
      cache.liste = (r && r.ok === true && Array.isArray(r.souvenirs)) ? r.souvenirs : [];
      if (!cache.liste.length || cleIci() !== cle || typeof global.renderRoomActions !== 'function') return;
      const B = global.BUILDINGS || (typeof BUILDINGS !== 'undefined' ? BUILDINGS : null);
      const ctx = typeof global.getBuildingContext === 'function' ? global.getBuildingContext(buildingId) : null;
      const room = (B && B[buildingId] && B[buildingId].rooms && B[buildingId].rooms[roomId]) || (ctx && ctx.roomsExtra && ctx.roomsExtra[roomId]);
      if (room) { try { global.renderRoomActions(room, buildingId, roomId); } catch (_) {} }
    });
  }
  function ordresSouvenirs(buildingId, roomId) {
    const s = st();
    if (!s || !buildingId || !roomId || s.currentBuilding !== buildingId || s.currentRoom !== roomId) return [];
    lire(buildingId, roomId);
    if (cache.cle !== cleIci() || !cache.liste || !cache.liste.length) return [];
    return [{ fn: 'acheter_souvenir', label: TXT.ordre, pa: 0, cost: 0, type: 'legal', icon: 'ti-gift', successRate: 100, desc: TXT.ordreDesc }];
  }
  function modale(html) {
    const t = doc.getElementById('postes-modal-title'), c = doc.getElementById('postes-body'), m = doc.getElementById('modal-postes');
    if (!t || !c || !m) return;
    t.textContent = TXT.titre;
    c.innerHTML = '<div class="cpj-dialogue hg-souvenirs" style="padding:1rem">' + html + '</div>';
    m.classList.add('open');
  }
  function rendre(liste, message) {
    let h = message ? '<p class="cpj-note" role="status">' + esc(message) + '</p>' : '';
    if (!liste.length) { modale(h + '<p class="cpj-note">' + esc(TXT.rien) + '</p>'); return; }
    const pnjs = [...new Set(liste.map(x => x.pnj).filter(Boolean))];
    if (pnjs.length) h += '<p class="cpj-note">' + esc(f(TXT.propose, { pnj: pnjs.join(', ') })) + '</p>';
    h += '<ul class="hg-souvenirs-liste">';
    for (const x of liste) {
      h += '<li><span><i class="ti ti-gift" aria-hidden="true"></i> ' + esc(x.nom) + '</span><button type="button" class="cpj-touche cpj-primaire" data-souvenir="' +
        esc(x.cle) + '">' + esc(f(TXT.acheter, { prix: x.prix, devise: x.devise })) + '</button></li>';
    }
    modale(h + '</ul>');
  }
  async function ouvrirSouvenirs() {
    const r = await rpc('souvenirs_ici');
    const liste = (r && r.ok === true && Array.isArray(r.souvenirs)) ? r.souvenirs : [];
    cache = { cle: cleIci(), liste, enCours: false };
    rendre(liste);
  }
  async function acheter(cle) {
    if (achatEnCours) return;
    achatEnCours = true;
    try {
      const r = await rpc('souvenir_acheter', { p_requete: uuid(), p_cle: cle });
      if (!r || r.ok !== true) {
        const t = TXT['r_' + (r && r.raison)] || TXT.r_autre;
        rendre(cache.liste || [], f(t, { requis: r && r.requis }));
        return;
      }
      if (typeof global.sbAdopterInventaireServeur === 'function') { try { global.sbAdopterInventaireServeur(r); } catch (_) {} }
      else if (Array.isArray(r.inventory) && st()) st().inventory = r.inventory;
      if (r.paie && typeof global.appliquerPaiementServeur === 'function') { try { global.appliquerPaiementServeur(Object.assign({ ok: true }, r.paie)); } catch (_) {} }
      if (typeof global.renderInventory === 'function') { try { global.renderInventory(); } catch (_) {} }
      if (typeof global.updateUI === 'function') { try { global.updateUI(); } catch (_) {} }
      const msg = f(TXT.achete, { nom: r.nom, prix: r.paye, devise: r.devise });
      if (typeof global.addJournalEntry === 'function') { try { global.addJournalEntry(msg, 'event-good'); } catch (_) {} }
      rendre(cache.liste || [], msg);
    } finally { achatEnCours = false; }
  }
  doc.addEventListener('click', e => {
    const b = e.target.closest && e.target.closest('.hg-souvenirs [data-souvenir]');
    if (b) acheter(b.dataset.souvenir);
  });
  const s = doc.createElement('style');
  s.textContent = '.hg-souvenirs-liste{list-style:none;padding:0;margin:.4rem 0;display:flex;flex-direction:column;gap:.4rem}' +
    '.hg-souvenirs-liste li{display:flex;justify-content:space-between;align-items:center;gap:.5rem;font-size:.95rem;flex-wrap:wrap}' +
    '.hg-souvenirs-liste button{min-height:40px}';
  (doc.head || doc.documentElement).appendChild(s);

  global.RP_ORDRES_DYNAMIQUES = global.RP_ORDRES_DYNAMIQUES || [];
  if (!global.RP_ORDRES_DYNAMIQUES.includes(ordresSouvenirs)) global.RP_ORDRES_DYNAMIQUES.push(ordresSouvenirs);
  global.ouvrirSouvenirs = ouvrirSouvenirs;
  global.RPSouvenirs = Object.freeze({ ouvrirSouvenirs, ordresSouvenirs, acheter, TXT });
})(typeof window !== 'undefined' ? window : globalThis);
