// MARCHÉ DE KRASNOV : INTERFACE UNIQUE (lot de Krasnov, point 2 ; GAME-DESIGN-KRASNOV-LOT-20261120.md ; étape I, 22/11/2026).
// Une seule fenêtre : la liste des produits et trois colonnes, Acheter / Vendre / Produire. On saisit les quantités,
// les totaux se calculent en direct, puis un seul « Valider » fait tout en une fois, ou rien du tout (marche_krasnov_valider).
// Le serveur décide de tout (prix, stock, caisse, PA, argent, place) ; l'écran ne fait que prévenir avant l'envoi :
// le bouton « Valider » est grisé, avec la raison écrite en clair, tant que la demande ne peut pas passer.
// Manger le pain noir, le goulash et les fruits et légumes : marche_krasnov_manger (boutons dans la fiche de l'objet).
(function (global) {
  'use strict';
  // Textes français (nouvelles clés à traduire : voir RELAIS.md, « Pour Codex »).
  const MK_TXT = {
    titre: 'Marché de Krasnov',
    intro: 'Inscrivez les quantités dans les colonnes, puis appuyez sur « Valider » : tout se fait en une seule fois, ou rien du tout.',
    vous: 'Vous avez {argent} PSK, {pa} PA et {place} place{s} libre{s} dans votre inventaire.',
    caisse: 'Caisse du marché : {caisse} PSK (elle paie ce que vous vendez et votre travail).',
    produit: 'Produit', acheter: 'Acheter', vendre: 'Vendre', produire: 'Produire',
    prixAchat: '{p} PSK l’unité', prixRachat: 'rachat {p} PSK', auMarche: 'Au marché : {n}', vousEnAvez: 'Vous en avez : {n}',
    fournee: '1 fournée = {pa} PA → {n} {label}', prend: 'prend au marché : {m}', salaire: 'payé {montant} PSK par PA',
    pasDeProd: '—', pasDeProdAide: 'Les produits bruts ne se fabriquent pas ici.',
    total: 'Vous dépensez {cout} PSK · vous gagnez {gain} PSK (ventes) + {salaire} PSK (travail) · PA : {pa}',
    annuler: 'Annuler', valider: 'Valider', fermer: 'Fermer', chargement: 'Le marché se prépare…',
    rien: 'Inscrivez au moins une quantité.',
    r_pas_au_marche: 'Il faut être sur les étals du marché de Krasnov.',
    r_pa_insuffisants: 'Il vous manque des PA pour produire : il en faut {requis}, vous en avez {pa}.',
    r_argent_insuffisant: 'Il vous manque de l’argent : il faut {requis} PSK, vous en avez {argent}.',
    r_caisse_vide: 'La caisse du marché est vide : elle ne peut payer que {caisse} PSK. Achetez d’abord, ou vendez moins.',
    r_stock_insuffisant: 'Le marché n’a que {disponible} « {label} ».',
    r_vous_n_en_avez_pas_assez: 'Vous n’avez que {possede} « {label} » à vendre (un objet porté ne se vend pas).',
    r_matiere_manquante: 'Il manque {manque} « {label} » au marché pour produire : vendez-en d’abord, ou produisez moins.',
    r_stock_marche_plein: 'Le marché n’a pas de place pour plus de {stock_max} « {label} ».',
    r_production_impossible: '« {label} » ne se fabrique pas.',
    r_inventaire_plein: 'Votre inventaire est plein : il reste {place} place(s), il en faut {requis}. Faites de la place ou achetez moins.',
    r_rien_a_faire: 'Inscrivez au moins une quantité.',
    r_emprisonne: 'Impossible depuis une cellule.',
    r_echec_execution: 'Le marché n’a rien pu faire : rien n’a été exécuté. Réessayez.',
    refus: 'Le marché a refusé : rien n’a été exécuté.',
    fait: 'C’est fait.',
    journal: 'Marché de Krasnov : {resume}.',
    ligneA: '{n} × {label} acheté(s)', ligneV: '{n} × {label} vendu(s)', ligneP: '{n} × {label} produit(s)',
    manger: 'Manger', mangeTitre: 'Repas',
    m_pain_noir: 'Pain noir mangé : +{sante} Santé, +{pa} PA au prochain Dormir.',
    m_fruits_legumes: 'Fruits et légumes mangés : +{sante} Santé, +{pa} PA au prochain Dormir.',
    m_goulash: 'Goulash mangé : +{sante} Santé, +{pa} PA au prochain Dormir.',
    r_repas_brut_deja_pris: 'Vous avez déjà pris un repas brut depuis votre dernier Dormir : celui-ci attendra.',
    r_pas_dans_l_inventaire: 'Vous n’en avez plus dans votre inventaire.',
  };
  const txt = (k, v) => String(MK_TXT[k] || '').replace(/\{(\w+)\}/g, (_, x) => {
    if (x === 's') return (v && Number(v.place) > 1) ? 's' : '';
    return v && v[x] != null ? v[x] : '';
  });
  const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const un = r => Array.isArray(r) ? r[0] : r;
  const uuid = () => (global.crypto && global.crypto.randomUUID) ? global.crypto.randomUUID()
    : 'xxxxxxxx-xxxx-4xxx-8xxx-xxxxxxxxxxxx'.replace(/x/g, () => Math.floor(Math.random() * 16).toString(16));
  const entier = v => { const n = Math.floor(Number(v)); return Number.isFinite(n) && n > 0 ? n : 0; };

  let mkEtat = null, mkSaisie = {}, mkEnCours = false;

  // Prévision fidèle aux contrôles du serveur (même ordre : vendre, produire, acheter). Renvoie la première raison de refus.
  function mkPrevoir(e, saisie) {
    const P = {}; (e.produits || []).forEach(p => { P[p.cle] = p; });
    const stock = {}; Object.values(P).forEach(p => { stock[p.cle] = Number(p.stock) || 0; });
    let pa = 0, gain = 0, cout = 0, place = 0, rien = true;
    for (const p of Object.values(P)) {
      const s = saisie[p.cle] || {}; const a = entier(s.a), v = entier(s.v), f = entier(s.p);
      if (a + v + f > 0) rien = false;
      if (v > (Number(p.possede) || 0)) return { raison: 'vous_n_en_avez_pas_assez', label: p.label, possede: p.possede };
      pa += f * (Number(p.pa) || 0); gain += v * p.prix_rachat; cout += a * p.prix_vente; place += a;
      stock[p.cle] += v + f * (Number(p.unites) || 0);
      if (f > 0) Object.entries(p.recette || {}).forEach(([m, q]) => { stock[m] -= f * Number(q); });
    }
    const salaire = pa * (Number(e.salaire_pa) || 15);
    const t = { pa, gain, cout, salaire, place };
    if (rien) return Object.assign(t, { raison: 'rien_a_faire' });
    for (const p of Object.values(P)) if (stock[p.cle] < 0) return Object.assign(t, { raison: 'matiere_manquante', label: p.label, manque: -stock[p.cle] });
    for (const p of Object.values(P)) {
      const a = entier((saisie[p.cle] || {}).a);
      if (stock[p.cle] - a < 0) return Object.assign(t, { raison: 'stock_insuffisant', label: p.label, disponible: stock[p.cle] });
      if (stock[p.cle] - a > p.stock_max && stock[p.cle] - a > p.stock) return Object.assign(t, { raison: 'stock_marche_plein', label: p.label, stock_max: p.stock_max });
    }
    if ((Number(e.pa) || 0) < pa) return Object.assign(t, { raison: 'pa_insuffisants', requis: pa, pa: e.pa });
    if ((Number(e.argent) || 0) + gain + salaire < cout) return Object.assign(t, { raison: 'argent_insuffisant', requis: cout - gain - salaire, argent: e.argent });
    if ((Number(e.caisse) || 0) + cout < gain + salaire) return Object.assign(t, { raison: 'caisse_vide', caisse: e.caisse });
    let libere = 0;
    for (const p of Object.values(P)) { const v = entier((saisie[p.cle] || {}).v); libere += v; }
    if ((Number(e.place) || 0) + libere < place) return Object.assign(t, { raison: 'inventaire_plein', place: (Number(e.place) || 0) + libere, requis: place });
    return t;
  }

  function mkLigne(p) {
    const s = mkSaisie[p.cle] || {};
    const champ = (col, max, aide) => '<input type="number" inputmode="numeric" class="cpj-champ mk-q" data-cle="' + esc(p.cle) + '" data-col="' + col + '"'
      + ' min="0" max="' + max + '" value="' + (entier(s[col]) || '') + '" placeholder="0" aria-label="' + esc(aide) + '"'
      + ' style="width:4.2rem;text-align:center"' + (max <= 0 ? ' disabled title="' + esc(aide) + '"' : '') + '>';
    const recette = p.recette ? Object.entries(p.recette).map(([m, q]) => {
      const mp = (mkEtat.produits || []).find(x => x.cle === m); return q + ' ' + (mp ? mp.label : m);
    }).join(' + ') : '';
    const prod = p.genre === 'transforme'
      ? champ('p', 999, txt('produire')) + '<div class="cpj-note" style="font-size:.78rem">' + esc(txt('fournee', { pa: p.pa, n: p.unites, label: p.label.toLowerCase() })) + '<br>'
        + esc(txt('prend', { m: recette })) + '<br>' + esc(txt('salaire', { montant: mkEtat.salaire_pa })) + '</div>'
      : '<span class="cpj-note" title="' + esc(txt('pasDeProdAide')) + '">' + esc(txt('pasDeProd')) + '</span>';
    return '<tr style="border-top:1px solid #2a3340">'
      + '<td style="padding:.45rem .3rem;vertical-align:top"><strong>' + esc(p.label) + '</strong>'
      + (p.effet ? '<div class="cpj-note" style="font-size:.8rem">' + esc(p.effet) + '</div>' : '')
      + '<div class="cpj-note" style="font-size:.78rem">' + esc(txt('auMarche', { n: p.stock })) + ' · ' + esc(txt('vousEnAvez', { n: p.possede })) + '</div></td>'
      + '<td style="padding:.45rem .3rem;vertical-align:top;text-align:center">' + champ('a', p.stock, txt('acheter')) + '<div class="cpj-note" style="font-size:.78rem">' + esc(txt('prixAchat', { p: p.prix_vente })) + '</div></td>'
      + '<td style="padding:.45rem .3rem;vertical-align:top;text-align:center">' + champ('v', p.possede, txt('vendre')) + '<div class="cpj-note" style="font-size:.78rem">' + esc(txt('prixRachat', { p: p.prix_rachat })) + '</div></td>'
      + '<td style="padding:.45rem .3rem;vertical-align:top;text-align:center">' + prod + '</td></tr>';
  }

  function mkMajTotaux() {
    const doc = global.document;
    const t = mkPrevoir(mkEtat, mkSaisie);
    const tot = doc.getElementById('mk-total'), raison = doc.getElementById('mk-raison'), ok = doc.getElementById('mk-valider');
    if (tot) tot.textContent = txt('total', { cout: t.cout || 0, gain: t.gain || 0, salaire: t.salaire || 0, pa: t.pa || 0 });
    const msg = t.raison ? txt('r_' + t.raison, t) : '';
    if (raison) { raison.textContent = msg; raison.style.display = msg ? '' : 'none'; }
    if (ok) { ok.disabled = !!t.raison || mkEnCours; ok.title = msg || ''; }
  }

  function mkRendre(message, ok) {
    const doc = global.document, e = mkEtat;
    const titre = doc.getElementById('postes-modal-title');
    if (titre) titre.textContent = txt('titre');
    doc.getElementById('postes-body').innerHTML = '<div class="cpj-dialogue mk-fenetre" style="padding:.8rem;font-size:.95rem;line-height:1.4">'
      + '<p style="margin:0 0 .4rem">' + esc(txt('intro')) + '</p>'
      + '<p class="cpj-note" style="margin:0 0 .2rem">' + esc(txt('vous', { argent: e.argent, pa: e.pa, place: e.place })) + '</p>'
      + '<p class="cpj-note" style="margin:0 0 .6rem">' + esc(txt('caisse', { caisse: e.caisse })) + '</p>'
      + (message ? '<p style="margin:0 0 .6rem;color:' + (ok ? '#8ab070' : '#e0a040') + '">' + esc(message) + '</p>' : '')
      + '<div style="overflow-x:auto;max-height:55vh;overflow-y:auto"><table style="width:100%;border-collapse:collapse">'
      + '<thead><tr><th style="text-align:left">' + esc(txt('produit')) + '</th><th>' + esc(txt('acheter')) + '</th><th>' + esc(txt('vendre')) + '</th><th>' + esc(txt('produire')) + '</th></tr></thead>'
      + '<tbody>' + (e.produits || []).map(mkLigne).join('') + '</tbody></table></div>'
      + '<p id="mk-total" style="margin:.7rem 0 .3rem;font-weight:bold"></p>'
      + '<p id="mk-raison" style="margin:0 0 .5rem;color:#e0a040;display:none"></p>'
      + '<div style="display:flex;gap:.5rem;flex-wrap:wrap">'
      + '<button type="button" class="cpj-touche cpj-primaire" style="flex:1" id="mk-valider">' + esc(txt('valider')) + '</button>'
      + '<button type="button" class="cpj-touche" style="flex:1" id="mk-annuler">' + esc(txt('annuler')) + '</button>'
      + '<button type="button" class="cpj-touche" style="flex:1" id="mk-fermer">' + esc(txt('fermer')) + '</button></div></div>';
    doc.querySelectorAll('.mk-q').forEach(inp => inp.addEventListener('input', () => {
      const max = Number(inp.max); let v = entier(inp.value);
      if (Number.isFinite(max) && v > max) { v = max; inp.value = String(max); }
      mkSaisie[inp.dataset.cle] = Object.assign({}, mkSaisie[inp.dataset.cle], { [inp.dataset.col]: v });
      mkMajTotaux();
    }));
    doc.getElementById('mk-annuler').addEventListener('click', () => { mkSaisie = {}; mkRendre(); });
    doc.getElementById('mk-fermer').addEventListener('click', () => doc.getElementById('modal-postes')?.classList.remove('open'));
    doc.getElementById('mk-valider').addEventListener('click', mkValider);
    mkMajTotaux();
    doc.getElementById('modal-postes').classList.add('open');
  }

  async function ouvrirMarcheKrasnov(message, ok) {
    const e = un(await global.sbRpc('marche_krasnov_etat', {}).catch(() => null));
    if (!e || e.ok !== true) { global.showToast(txt('titre'), txt('refus'), false); return; }
    if (!e.ici) { global.showToast(txt('titre'), txt('r_pas_au_marche'), false); return; }
    mkEtat = e;
    mkRendre(message, ok);
  }

  function mkResume(r) {
    return (r.lignes || []).flatMap(l => [
      l.acheter ? txt('ligneA', { n: l.acheter, label: l.label }) : null,
      l.vendre ? txt('ligneV', { n: l.vendre, label: l.label }) : null,
      l.produire ? txt('ligneP', { n: l.produits, label: l.label }) : null]).filter(Boolean).join(', ');
  }

  async function mkValider() {
    if (mkEnCours || !mkEtat) return;
    const t = mkPrevoir(mkEtat, mkSaisie);
    if (t.raison) { mkMajTotaux(); return; }
    const lignes = Object.entries(mkSaisie).map(([cle, s]) => ({ cle, acheter: entier(s.a), vendre: entier(s.v), produire: entier(s.p) }))
      .filter(l => l.acheter + l.vendre + l.produire > 0);
    mkEnCours = true; mkMajTotaux();
    try {
      const r = un(await global.sbRpc('marche_krasnov_valider', { p_requete: uuid(), p_lignes: lignes }).catch(() => null));
      if (!r || r.ok !== true) {
        const m = r && MK_TXT['r_' + r.raison] ? txt('r_' + r.raison, r) : txt('refus');
        global.showToast(txt('titre'), m, false);
        await ouvrirMarcheKrasnov(m, false);
        return;
      }
      if (typeof global.sbAdopterInventaireServeur === 'function') { try { global.sbAdopterInventaireServeur(r); } catch (_) {} }
      if (r.paie && typeof global.appliquerPaiementServeur === 'function') { try { global.appliquerPaiementServeur(r.paie); } catch (_) {} }
      else if (typeof state !== 'undefined' && state && Number.isFinite(Number(r.pa))) { state.pa = Number(r.pa); if (state.char) state.char.pa = state.pa; }
      const resume = mkResume(r);
      global.showToast(txt('titre'), txt('fait') + ' ' + resume + '.', true);
      if (typeof global.addJournalEntry === 'function') global.addJournalEntry(txt('journal', { resume }), 'event-good');
      if (typeof global.updateUI === 'function') global.updateUI();
      mkSaisie = {};
      mkEtat = r.etat && r.etat.ok ? r.etat : mkEtat;
      mkRendre(txt('fait') + ' ' + resume + '.', true);
    } finally { mkEnCours = false; mkMajTotaux(); }
  }

  // Manger ce qui vient du marché : pain noir, goulash, fruits et légumes (le serveur décide de l'effet).
  const MK_COMESTIBLES = { krasnov_pain_noir: 'pain_noir', krasnov_goulash: 'goulash', fruits_legumes: 'fruits_legumes' };
  async function mangerProduitMarche(cle) {
    if (!Object.values(MK_COMESTIBLES).includes(cle)) return;
    const r = un(await global.sbRpc('marche_krasnov_manger', { p_requete: uuid(), p_cle: cle }).catch(() => null));
    if (!r || r.ok !== true) { global.showToast(txt('mangeTitre'), r && MK_TXT['r_' + r.raison] ? txt('r_' + r.raison, r) : txt('refus'), false); return; }
    if (typeof global.sbAdopterInventaireServeur === 'function') { try { global.sbAdopterInventaireServeur(r); } catch (_) {} }
    if (r.paie && typeof global.appliquerPaiementServeur === 'function') { try { global.appliquerPaiementServeur(r.paie); } catch (_) {} }
    global.document.getElementById('modal-postes')?.classList.remove('open');
    // Barème des repas (22/11/2026) : Santé et PA différés arrêtés par le serveur.
    const repas = r.sante || {};
    if (typeof repas.apres === 'number' && typeof state !== 'undefined' && state) {
      state.hp = repas.apres;
      if (typeof global.sbFicheBaseAdopter === 'function') global.sbFicheBaseAdopter({ hp: repas.apres });
    }
    const effet = { sante: Number(repas.gain) || 0, pa: Number(repas.pa_differe) || 0 };
    global.showToast(txt('mangeTitre'), txt('m_' + cle, effet), true);
    if (typeof global.addJournalEntry === 'function') global.addJournalEntry(txt('m_' + cle, effet), 'event-good');
    if (typeof global.updateUI === 'function') global.updateUI();
  }
  // Bouton « Manger » de la fiche d'un objet (vide si l'objet ne se mange pas par cette voie).
  function boutonMangerProduitMarche(item, style) {
    const cle = item && MK_COMESTIBLES[item.stackKey];
    if (!cle) return '';
    return '<button onclick="mangerProduitMarche(\'' + cle + '\')" style="' + (style || '') + '"><i class="ti ti-tools-kitchen-2"></i> ' + esc(txt('manger')) + '</button>';
  }

  global.MK_TXT = MK_TXT;
  global.ouvrirMarcheKrasnov = ouvrirMarcheKrasnov;
  global.mangerProduitMarche = mangerProduitMarche;
  global.boutonMangerProduitMarche = boutonMangerProduitMarche;
  global.RPMarcheKrasnov = { prevoir: mkPrevoir, txt, _etat: v => { if (v) mkEtat = v; return mkEtat; }, _saisie: v => { if (v) mkSaisie = v; return mkSaisie; } };
})(typeof window !== 'undefined' ? window : globalThis);
