// ARMOIRE À SOUVENIRS INSTALLÉE — dépôt et collection (Fred, 25/11/2026, mission de jour, bloc 3 / H.9 ; migration
// 20261125300000). Le serveur tranche tout (armoire_lire, armoire_deposer, armoire_reprendre) : qui peut ouvrir, quel souvenir
// remplit quel emplacement, la progression, les cartes postales hors liste. Cette fenêtre montre les douze emplacements (remplis
// ou vides), « Déposer » depuis l'inventaire, « Reprendre », et la progression « 7/12 ». Ouverte depuis « Équipements du local »
// (bouton « Ouvrir l'armoire », affiché seulement quand le serveur connaît l'armoire : sans la migration, rien ne change).
(function (global) {
  'use strict';
  const doc = global.document;
  if (!doc) return;
  const TXT = {
    titre: 'Armoire à souvenirs',
    ouvrir: 'Ouvrir l’armoire',
    progression: '{n}/{total} souvenirs',
    complete: 'Collection complète : vous dormez mieux près de votre armoire (+1 PA au réveil).',
    vide: 'Emplacement vide',
    deposer: 'Déposer',
    reprendre: 'Reprendre',
    aDeposer: 'Depuis votre inventaire',
    rienADeposer: 'Aucun souvenir de cette liste dans votre inventaire.',
    cartes: 'Cartes postales rangées (hors collection)',
    fermee: 'Cette armoire est fermée à clé.',
    visiteur: 'Cette armoire n’est pas à vous : vous pouvez en reprendre le contenu, mais pas y déposer.',
    villeFermee: 'Cette ville ouvrira ses portes au premier trimestre 2027.',
    regle: 'Seul le souvenir exact de chaque ville remplit son emplacement. Les cartes postales hors liste se rangent sans compter.',
    r_hors_liste: 'Cet objet ne figure pas sur la liste de cette armoire.',
    r_emplacement_deja_rempli: 'Cet emplacement est déjà rempli.',
    r_pas_proprietaire: 'Seul le propriétaire des lieux dépose dans cette armoire.',
    r_armoire_fermee_a_cle: 'L’armoire est fermée à clé.',
    r_inventaire_plein: 'Votre inventaire est plein.',
    r_pas_sur_place: 'Il faut être dans la pièce de l’armoire.',
    r_autre: 'L’armoire ne s’ouvre pas pour le moment.'
  };
  const VILLES_FERMEES = ['Ciudad Roja', 'Puerto Negro', 'Villa Sangre', 'Al Madina', 'Oasis City', 'Al-Petrol'];
  const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const f = (t, v) => String(t).replace(/\{(\w+)\}/g, (_, k) => (v && v[k] != null ? v[k] : ''));
  const uuid = () => (global.crypto && typeof global.crypto.randomUUID === 'function') ? global.crypto.randomUUID()
    : '00000000-0000-4000-8000-' + String(Date.now()).slice(-12).padStart(12, '0');
  let disponible = null, courant = null, envoi = false;

  async function rpc(fn, args) {
    if (typeof global.sbRpc !== 'function') return null;
    try { const r = await global.sbRpc(fn, args || {}); return Array.isArray(r) ? r[0] : r; } catch (_) { return null; }
  }
  // Le serveur connaît-il l'armoire ? (une réponse nommée suffit ; sans migration, l'appel échoue et le bouton reste caché)
  async function armoireDisponible() {
    if (disponible !== null) return disponible;
    const r = await rpc('armoire_lire', { p_equipement: '00000000-0000-0000-0000-000000000000' });
    disponible = !!(r && typeof r.ok === 'boolean');
    return disponible;
  }
  function modale(html) {
    const t = doc.getElementById('postes-modal-title'), c = doc.getElementById('postes-body'), m = doc.getElementById('modal-postes');
    if (!t || !c || !m) return;
    t.textContent = TXT.titre;
    c.innerHTML = '<div class="cpj-dialogue hg-armoire" style="padding:1rem">' + html + '</div>';
    m.classList.add('open');
  }
  function rendre(s, message) {
    if (!s || s.ok !== true) { modale('<p class="cpj-note">' + esc(TXT['r_' + (s && s.raison)] || TXT.r_autre) + '</p>'); return; }
    const acc = s.acces || {};
    let h = '<p class="cpj-note">' + esc(s.liste || '') + '</p>';
    if (message) h += '<p class="cpj-note hg-armoire-msg" role="status">' + esc(message) + '</p>';
    if (!acc.ouvrable) { modale(h + '<p class="cpj-note">' + esc(TXT.fermee) + '</p>'); return; }
    h += '<p class="hg-armoire-progression"><b>' + esc(f(TXT.progression, { n: s.remplis, total: s.total })) + '</b></p>';
    if (s.complete) h += '<p class="cpj-note">' + esc(TXT.complete) + '</p>';
    if (!acc.proprietaire) h += '<p class="cpj-note">' + esc(TXT.visiteur) + '</p>';
    h += '<p class="cpj-note">' + esc(TXT.regle) + '</p><ol class="hg-armoire-liste">';
    for (const e of (s.emplacements || [])) {
      h += '<li class="' + (e.contenu ? 'rempli' : 'vide') + '"><span><i class="ti ' + (e.contenu ? 'ti-square-check' : 'ti-square') + '" aria-hidden="true"></i> ' +
        esc(e.ville) + ' — ' + esc(e.nom) + (e.contenu ? '' : ' <span class="cpj-note">(' + esc(TXT.vide) + ')</span>') + '</span>' +
        (e.contenu ? '<button type="button" class="cpj-touche" data-reprendre="' + esc(e.contenu) + '">' + esc(TXT.reprendre) + '</button>' : '') +
        // Empires fermés (Fred, 25/11/2026 au soir, 3.3) : le serveur signale la ville (ville_fermee) ; repli sur les six noms.
        ((e.ville_fermee || VILLES_FERMEES.includes(e.ville)) ? '<span class="cpj-note hg-armoire-fermee">' + esc(TXT.villeFermee) + '</span>' : '') + '</li>';
    }
    h += '</ol>';
    if ((s.cartes || []).length) {
      h += '<div class="cpj-titre">' + esc(TXT.cartes) + '</div><ul class="hg-armoire-liste">';
      for (const c of s.cartes) h += '<li><span>' + esc(c.objet) + '</span><button type="button" class="cpj-touche" data-reprendre="' + esc(c.contenu) + '">' + esc(TXT.reprendre) + '</button></li>';
      h += '</ul>';
    }
    if (acc.proprietaire) {
      h += '<div class="cpj-titre">' + esc(TXT.aDeposer) + '</div>';
      if (!(s.deposables || []).length) h += '<p class="cpj-note">' + esc(TXT.rienADeposer) + '</p>';
      else {
        h += '<ul class="hg-armoire-liste">';
        for (const d of s.deposables) h += '<li><span>' + esc(d.nom) + '</span><button type="button" class="cpj-touche cpj-primaire" data-deposer="' + esc(d.ref) + '">' + esc(TXT.deposer) + '</button></li>';
        h += '</ul>';
      }
    }
    modale(h);
  }
  function adopterInventaire(r) {
    if (r && Array.isArray(r.inventory) && global.state) {
      global.state.inventory = r.inventory;
      if (typeof global.renderInventaire === 'function') { try { global.renderInventaire(); } catch (_) {} }
    }
  }
  async function agir(fn, args) {
    if (envoi || !courant) return;
    envoi = true;
    try {
      const r = await rpc(fn, Object.assign({ p_requete: uuid(), p_equipement: courant }, args));
      if (r && r.ok === true) { adopterInventaire(r); rendre(r); }
      else { const s = await rpc('armoire_lire', { p_equipement: courant }); rendre(s, TXT['r_' + (r && r.raison)] || TXT.r_autre); }
    } finally { envoi = false; }
  }
  async function ouvrirArmoireInstallee(id) {
    courant = id;
    modale('<p class="cpj-note">…</p>');
    rendre(await rpc('armoire_lire', { p_equipement: id }));
  }
  doc.addEventListener('click', e => {
    const zone = e.target.closest && e.target.closest('.hg-armoire');
    if (!zone) return;
    const dep = e.target.closest('[data-deposer]'), rep = e.target.closest('[data-reprendre]');
    if (dep) agir('armoire_deposer', { p_ref: dep.dataset.deposer });
    else if (rep) agir('armoire_reprendre', { p_contenu: Number(rep.dataset.reprendre) });
  });
  const s = doc.createElement('style');
  s.textContent = '.hg-armoire-liste{list-style:none;padding:0;margin:.3rem 0;display:flex;flex-direction:column;gap:.3rem}' +
    '.hg-armoire-liste li{display:flex;justify-content:space-between;align-items:center;gap:.5rem;font-size:.95rem;flex-wrap:wrap}' +
    '.hg-armoire-fermee{flex-basis:100%;font-size:.85rem}' +
    '.hg-armoire-liste li.vide{opacity:.7}.hg-armoire-liste button{min-height:36px}.hg-armoire-progression{font-size:1.05rem;margin:.3rem 0}';
  (doc.head || doc.documentElement).appendChild(s);

  global.ouvrirArmoireInstallee = ouvrirArmoireInstallee;
  global.armoireDisponible = armoireDisponible;
  global.RPArmoireSouvenirs = Object.freeze({ ouvrirArmoireInstallee, armoireDisponible, rendre, TXT });
})(typeof window !== 'undefined' ? window : globalThis);
