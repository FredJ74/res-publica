// Chromium réel, vrai plateau.html (HTML et toutes les feuilles de style, mobiles comprises) : remontées du test en forêt
// de Krasnov (Fred, 22/11/2026, GAME-DESIGN-FORET-TEST-20261122.md), points 1 et 8.
//  - Point 1 : dans plusieurs fenêtres types (fenêtre classique, rapport de combat, rencontre en plein écran, notes grises,
//    infobulle, journal, notification, explication du climat), aucun texte sous le texte courant des pages (0,95 rem),
//    titres et pictogrammes inchangés, aucune fenêtre qui déborde à 390 px.
//  - Point 8 : pendant un événement climatique, l'effet est posé dans la rue de Krasnov, au camp de bûcherons et dans
//    toutes les vues de la forêt ; il quitte l'image d'une pièce couverte ; le bandeau d'alerte est au-dessus de l'image,
//    centré, lisible, et ne recouvre ni la photo ni une flèche. À 1280 et à 390 px.
// Vrais fichiers : data.js, plateau-variantes-pieces.js, plateau-rue-centrale.js, plateau-foret-krasnov.js, plateau-climat.js,
// plateau-texte-minimum.js, plateau-mobile.js ; seuls le serveur (sbRpc) et l'entrée dans une pièce (enterRoom) sont simulés.
const test = require('node:test'), assert = require('node:assert/strict');
const { avecJeu, page, R } = require('./mobile-navigateur.cjs');
const fs = require('node:fs'), path = require('node:path');
// Vraies images du dépôt (noms accentués ou avec espaces : décodés, forme NFC puis NFD).
function lireImage(url) {
  const nom = decodeURIComponent(new URL(url).pathname.slice(1));
  for (const n of [nom, nom.normalize('NFC'), nom.normalize('NFD')]) { try { return fs.readFileSync(path.join(R, n)); } catch (_) {} }
  return null;
}

const SCRIPTS = ['data.js', 'plateau-variantes-pieces.js', 'plateau-rue-centrale.js', 'plateau-foret-krasnov.js', 'plateau-climat.js', 'plateau-texte-minimum.js'];
// Entrée dans une pièce, réduite à ce que fait plateau-navigation.js pour l'image (le vrai enterRoom tire tout le jeu).
const ENTREE_PIECE = `
  window.enterRoom = function (b, r) {
    state.currentBuilding = b; state.currentRoom = r;
    document.getElementById('vue-rue').classList.remove('active'); document.getElementById('vue-batiment').classList.add('active');
    const fiche = (BUILDINGS[b] && BUILDINGS[b].rooms && BUILDINGS[b].rooms[r]) || {};
    const z = window.RPForetKrasnov && window.RPForetKrasnov.ZONES[r];
    const img = (z && z.image) || fiche.imageUrl || 'images/Sovarka/Krasnov/Krasnov_foret_clairiere.webp';
    const p = document.getElementById('piece-image');
    p.style.background = "url('" + img + "') center/cover no-repeat";
    document.getElementById('piece-nom').textContent = fiche.name || r;
    window.__entrees = (window.__entrees || 0) + 1;
  };
  window.enterBuilding = function () {};
`;

async function preparer(b, o, largeur, hauteur) {
  const p = await page(b, o, largeur, hauteur);
  await p.route('**/images/**', r => { const c = lireImage(r.request().url()); return c ? r.fulfill({ body: c, contentType: /\.png$/i.test(r.request().url()) ? 'image/png' : 'image/webp' }) : r.fulfill({ status: 404, body: '' }); });
  const erreurs = []; p.on('pageerror', e => erreurs.push(e.message));
  await p.evaluate(() => {
    window.state = { char: { name: 'Arnie' }, country: 'soviet', currentCity: 'ville_b', currentBuilding: null, currentRoom: null, inventory: [] };
    window.showToast = () => {};
    // Comme renderRue (plateau-navigation.js) pour une ville à rues : conteneur de la scène, plan masqué.
    const rue = document.getElementById('rue-image');
    document.getElementById('minimap').style.display = 'none'; document.getElementById('rue-ambiance').style.display = 'none';
    rue.style.background = 'none';
    const c = document.createElement('div'); c.id = 'rue-centrale-conteneur'; c.style.cssText = 'position:absolute; inset:0; z-index:0;';
    rue.insertBefore(c, rue.firstChild);
  });
  await p.addScriptTag({ content: ENTREE_PIECE });
  for (const s of SCRIPTS) await p.addScriptTag({ url: o + '/' + s });
  await p.waitForFunction(() => window.RPClimat && window.RPTexteMinimum && typeof initialiserRueCentraleSure === 'function');
  return { p, erreurs };
}
// Orage en cours à Krasnov (ville_b) ; serveur simulé.
async function orage(p, type = 'orage') {
  await p.evaluate(async type => {
    const t = Date.now();
    const ev = { id: 77, type, ville: 'ville_b', debut: new Date(t - 3600e3).toISOString(), fin: new Date(t + 5 * 3600e3).toISOString(),
      lieux: [], lieux_proteges: [], en_cours: true, consigne: 'Pendant 6 heures, restez prudents.' };
    try { localStorage.setItem('rp-climat-vu:Arnie:77:' + ev.debut.slice(0, 16), '1'); } catch (_) {}
    window.sbRpc = async fn => {
      if (fn === 'rue_position_lire') return { ok: true, country: 'soviet', city: 'ville_b', building: null, street: null };
      if (fn === 'rue_position_enregistrer') return { ok: true };
      if (fn === 'climat_etat') return { ok: true, evenements: [ev] };
      if (fn === 'climat_accueil_lire') return { ok: true, evenement: null };
      if (fn === 'climat_effets_lire' || fn === 'climat_points_eau_lister') return { ok: true, points: [] };
      return null;
    };
    window.RPClimat._evenements([ev]);
  }, type);
}
// Mesure du bandeau : au-dessus de l'image, centré, lisible, rien de couvert, rien qui le couvre.
function mesurerBandeau(p, imageSel) {
  return p.evaluate(sel => {
    const el = document.getElementById('climat-alerte');
    if (!el) return null;
    const a = el.getBoundingClientRect(), img = document.querySelector(sel).getBoundingClientRect();
    const t = el.querySelector('.climat-alerte-texte').getBoundingClientRect();
    const fleches = Array.from(document.querySelectorAll('.rc-fleche, .foret-porte')).filter(f => f.offsetParent).map(f => f.getBoundingClientRect());
    const pt = document.elementFromPoint(t.left + t.width / 2, t.top + t.height / 2);
    return {
      visible: a.width > 0 && a.height > 0, basBandeau: a.bottom, hautImage: img.top, gauche: a.left, droite: a.right,
      ecart: Math.abs((t.left + t.width / 2) - (a.left + a.width / 2)), largeurPage: document.documentElement.clientWidth,
      taille: parseFloat(getComputedStyle(el.querySelector('.climat-alerte-texte')).fontSize),
      couvreFleche: fleches.some(r => a.left < r.right && a.right > r.left && a.top < r.bottom && a.bottom > r.top),
      dessus: !!(pt && pt.closest('#climat-alerte')), debordePage: document.documentElement.scrollWidth > document.documentElement.clientWidth + 1
    };
  }, imageSel);
}
function verifierBandeau(m, quoi) {
  assert.ok(m && m.visible, quoi + ' : bandeau affiché ' + JSON.stringify(m));
  assert.ok(m.basBandeau <= m.hautImage + 0.5, quoi + ' : au-dessus de l’image, sans la couvrir ' + JSON.stringify(m));
  assert.ok(m.ecart < 60, quoi + ' : centré ' + JSON.stringify(m));
  assert.ok(m.taille >= 16, quoi + ' : taille normale et lisible ' + JSON.stringify(m));
  assert.equal(m.couvreFleche, false, quoi + ' : aucune flèche couverte');
  assert.equal(m.dessus, true, quoi + ' : rien ne recouvre le bandeau');
  assert.ok(m.gauche >= -0.5 && m.droite <= m.largeurPage + 0.5, quoi + ' : dans la largeur de l’écran ' + JSON.stringify(m));
  assert.equal(m.debordePage, false, quoi + ' : aucun défilement horizontal');
}

for (const [largeur, hauteur] of [[1280, 860], [390, 844]]) {
  test(`climat ${largeur} px : rue de Krasnov, camp de bûcherons et toutes les vues de la forêt`, async () => avecJeu(async (b, o) => {
    const { p, erreurs } = await preparer(b, o, largeur, hauteur);
    await orage(p);
    // Rue (place de l'Ours) : filtre dans la scène, bandeau au-dessus de l'image.
    await p.evaluate(() => initialiserRueCentraleSure('soviet', 'krasnov-place-ours', null));
    await p.waitForSelector('#rc-scene #rc-image');
    await p.waitForFunction(() => document.getElementById('rc-image').naturalWidth > 0);
    await p.evaluate(() => window.RPClimat.appliquerFiltre());
    assert.equal(await p.locator('#rc-scene > #climat-filtre.orage').count(), 1, 'pluie dans la rue');
    if (process.env.HG_PREUVES) await p.screenshot({ path: process.env.HG_PREUVES + '/rue-' + largeur + '.png' });   // captures de contrôle
    verifierBandeau(await mesurerBandeau(p, '#rc-scene'), 'rue');
    assert.equal(await p.evaluate(() => document.getElementById('climat-alerte').nextElementSibling.className), 'rue-container');
    // Rien entre le bandeau et la photo (sur téléphone, la date de jeu reste au-dessus du bandeau).
    const m = await mesurerBandeau(p, '#rc-scene'); assert.ok(m.hautImage - m.basBandeau < 2, 'bandeau collé à l’image ' + JSON.stringify(m));
    // Les flèches restent au-dessus de la pluie et cliquables.
    const r = await p.locator('.rc-fleche').first().boundingBox();
    assert.equal(await p.evaluate(([x, y]) => !!document.elementFromPoint(x, y).closest('.rc-fleche'), [r.x + r.width / 2, r.y + r.height / 2]), true);

    // Camp de bûcherons, clairière, quatre vues de la forêt : comme provForetRendre (enterRoom), l'effet suit AUSSITÔT.
    for (const piece of ['zone_recolte', 'foret_clairiere', 'foret_vue_1', 'foret_vue_2', 'foret_vue_3', 'foret_vue_4']) {
      await p.evaluate(piece => enterRoom('zone-production', piece, null), piece);
      assert.equal(await p.locator('#piece-image > #climat-filtre.orage').count(), 1, piece + ' : pluie sur la vue');
      assert.equal(await p.locator('#climat-filtre').count(), 1, piece + ' : un seul filtre');
      assert.equal(await p.evaluate(() => document.getElementById('climat-alerte').nextElementSibling.className), 'piece-container', piece);
      await p.waitForTimeout(150);   // zone « Explorer la forêt » posée (taille naturelle de l'image)
      verifierBandeau(await mesurerBandeau(p, '#piece-image'), piece);
      if (process.env.HG_PREUVES && /zone_recolte|foret_vue_3/.test(piece)) await p.screenshot({ path: process.env.HG_PREUVES + '/' + piece + '-' + largeur + '.png' });
      // La zone « Explorer la forêt » reste cliquable à travers la pluie.
      const z = await p.locator('.foret-porte').boundingBox();
      if (z) assert.equal(await p.evaluate(([x, y]) => !!document.elementFromPoint(x, y).closest('.foret-porte'), [z.x + z.width / 2, z.y + z.height / 2]), true, piece + ' : explorer');
    }
    // Pièce couverte : plus d'effet sur l'image de la pièce ; il retourne dans la rue.
    await p.evaluate(() => enterRoom('mairie', 'accueil', null));
    assert.equal(await p.locator('#piece-image #climat-filtre').count(), 0, 'rien dans une pièce couverte');
    assert.equal(await p.locator('#rc-scene > #climat-filtre').count(), 1);
    // Les autres climats : même place.
    for (const type of ['blizzard', 'brouillard', 'canicule']) {
      await orage(p, type);
      await p.evaluate(() => enterRoom('zone-production', 'foret_vue_3', null));
      assert.equal(await p.locator('#piece-image > #climat-filtre.' + type).count(), 1, type);
      assert.match(await p.locator('#climat-alerte .climat-alerte-texte').textContent(), new RegExp('^Attention : ' + type + '$'));
    }
    // Fin de l'événement : tout disparaît.
    await p.evaluate(() => { window.RPClimat._evenements([]); window.RPClimat.appliquerFiltre(); });
    assert.equal(await p.locator('#climat-filtre, #climat-alerte').count(), 0);
    assert.deepEqual(erreurs, []);
  }));

  test(`texte minimum ${largeur} px : fenêtres, rapports, notes, infobulles, journal`, async () => avecJeu(async (b, o) => {
    const { p, erreurs } = await preparer(b, o, largeur, hauteur);
    const plancher = await p.evaluate(() => window.RPTexteMinimum.plancherPx());
    assert.equal(plancher, 15.2, 'texte courant des pages : 0,95 rem');
    await p.evaluate(() => {
      // 1. Fenêtre classique (#modal-postes), écrite comme dans le jeu : tailles en dur dans le HTML.
      document.getElementById('postes-modal-title').textContent = 'Rencontre en forêt';
      document.getElementById('postes-body').innerHTML = '<div class="cpj-dialogue">'
        + '<div id="t-titre" style="font-family:Bebas Neue;font-size:1.3rem">L’ours brun</div>'
        + '<p>Une masse sombre approche.</p><p class="cpj-note" id="t-note">Mention grise : vos PA baissent.</p>'
        + '<div id="t-gris" style="font-size:.7rem;color:#888">Fausse alerte possible.</div>'
        + '<span id="t-mini" style="font-size:.6rem">−12 PA</span> <small id="t-small">(coma)</small>'
        + '<i class="ti ti-x" id="t-picto" style="font-size:.7rem"></i></div>';
      document.getElementById('modal-postes').classList.add('open');
      // 2. Rapport de combat (tableau dense écrit en .78rem).
      const fond = document.createElement('div');
      fond.className = 'modal-overlay open'; fond.id = 'banc-rapport';
      fond.innerHTML = '<div class="modal-box"><div class="modal-header"><div class="modal-title">Rapport de combat</div></div>'
        + '<div class="modal-body"><table style="font-size:.78rem"><tr><td id="t-round">ROUND 1</td><td>Tom Tom −0 PA</td><td>Loup 1 −8 PA (mort)</td></tr></table>'
        + '<div style="font-size:.72rem" id="t-conclusion">La meute rompt le combat.</div></div></div>';
      document.body.appendChild(fond);
    });
    // 3. Fenêtre plein écran créée par le code (position fixe, comme les rencontres et les révélations).
    await p.evaluate(() => {
      const f = document.createElement('div');
      f.style.cssText = 'position:fixed;inset:0;z-index:9000;background:rgba(0,0,0,.9)'; f.id = 'banc-plein-ecran';
      f.innerHTML = '<div style="font-size:.75rem" id="t-plein">Un bruit dans les fourrés…</div>';
      document.body.appendChild(f);
      // 4. Infobulle de rue, notification, journal des événements.
      const bulle = document.createElement('div'); bulle.className = 'rc-tooltip visible'; bulle.id = 't-bulle'; bulle.textContent = 'Kolkhoze S. M. Kirov';
      document.body.appendChild(bulle);
      document.getElementById('result-toast').style.display = 'block';
      document.getElementById('toast-result').textContent = 'Coupe de bois'; document.getElementById('toast-sub').textContent = '+3 bois';
      document.getElementById('journal-store').style.display = 'flex';
      const j = document.getElementById('journal');
      j.insertAdjacentHTML('afterbegin', '<div class="journal-entry"><span class="journal-time">22/11 · 06h10</span><span class="journal-text event-bad" style="font-size:.7rem" id="t-journal">Un loup vous mord.</span></div>');
      // 5. Explication du climat (vraie fenêtre de plateau-climat.js).
      const t = Date.now();
      window.RPClimat.fenetreExplication({ id: 1, type: 'orage', ville: 'ville_b', debut: new Date(t - 3600e3).toISOString(), fin: new Date(t + 3600e3).toISOString(), lieux: [], lieux_proteges: [], consigne: 'Restez prudents.' });
    });
    await p.waitForTimeout(120);
    if (process.env.HG_PREUVES) {
      await p.screenshot({ path: process.env.HG_PREUVES + '/fenetres-' + largeur + '.png' });
      await p.evaluate(() => { document.getElementById('climat-explication')?.remove(); document.getElementById('banc-plein-ecran').style.display = 'none'; document.getElementById('banc-rapport').classList.remove('open'); });
      await p.screenshot({ path: process.env.HG_PREUVES + '/postes-' + largeur + '.png' });
      await p.evaluate(() => { document.getElementById('banc-plein-ecran').style.display = ''; document.getElementById('banc-rapport').classList.add('open'); });
    }
    const mesure = await p.evaluate(() => {
      const fen = window.RPTexteMinimum.FENETRES + ',#banc-plein-ecran';
      const trop = [];
      document.querySelectorAll(fen).forEach(f => f.querySelectorAll('*').forEach(el => {
        const texte = Array.from(el.childNodes).some(n => n.nodeType === 3 && n.nodeValue.trim());
        if (!texte || el.closest('svg') || (el.tagName === 'I' && /\bti\b/.test(el.className))) return;
        if (!el.getClientRects().length && !el.closest('#modal-postes,#banc-rapport')) return;
        const px = parseFloat(getComputedStyle(el).fontSize);
        if (px < 15.15) trop.push((el.id || el.className || el.tagName) + ' ' + px);
      }));
      const tailles = {};
      for (const id of ['t-titre', 't-note', 't-gris', 't-mini', 't-small', 't-picto', 't-round', 't-conclusion', 't-plein', 't-bulle', 't-journal', 'toast-sub', 'toast-result'])
        tailles[id] = parseFloat(getComputedStyle(document.getElementById(id)).fontSize);
      const debord = Array.from(document.querySelectorAll('.modal-overlay.open .modal-box, #climat-explication > *')).filter(e => e.scrollWidth > e.clientWidth + 1).map(e => e.id || e.className);
      return { trop, tailles, debord, page: document.documentElement.scrollWidth > document.documentElement.clientWidth + 1 };
    });
    assert.deepEqual(mesure.trop, [], 'aucun texte sous 0,95 rem dans les fenêtres');
    for (const id of ['t-note', 't-gris', 't-mini', 't-small', 't-round', 't-conclusion', 't-plein', 't-bulle', 't-journal', 'toast-sub'])
      assert.ok(mesure.tailles[id] >= 15.2, id + ' ' + mesure.tailles[id]);
    assert.equal(mesure.tailles['t-titre'], 20.8, 'titre inchangé (1,3 rem)');
    assert.equal(await p.locator('#t-picto[data-texte-minimum]').count(), 0, 'pictogramme jamais touché');
    assert.ok(mesure.tailles['toast-result'] >= 16, 'titre de la notification');
    assert.deepEqual(mesure.debord, [], 'aucune fenêtre ne déborde');
    assert.equal(mesure.page, false, 'aucun défilement horizontal');
    // Le forum (page plein écran au gabarit propre, témoin au pixel) n'est pas touché.
    assert.equal(await p.evaluate(() => { const f = document.getElementById('forum-body'); f.innerHTML = '<span id="t-forum" style="font-size:.7rem">sujet</span>'; return new Promise(r => requestAnimationFrame(() => setTimeout(() => r(parseFloat(getComputedStyle(document.getElementById('t-forum')).fontSize)), 30))); }), 11.2);
    assert.deepEqual(erreurs, []);
  }));
}
