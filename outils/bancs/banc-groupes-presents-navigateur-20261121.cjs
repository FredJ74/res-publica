// Chromium réel : colonne « Personnes présentes » (Fred, 21/11/2026, soir, points 7 et 8) — vrai plateau-multijoueur.js,
// serveur simulé (sbGetPresencesInRoom renvoie la forme de presents_ici). Groupe en bloc, chef en premier, masques visibles.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), os = require('node:os'), http = require('node:http');
const { chromium } = require('../e2e/node_modules/playwright');
const { lancerChromium } = require('./fixtures/chromium-cdp.cjs');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const PAGE = '<!doctype html><meta charset="utf-8"><body><div id="persons-list-rue">'
  + '<div class="person-card" onclick="openSelfView()"><div class="person-avatar"></div><div><div class="person-name">Arnie (Vous)</div></div></div>'
  + '<div class="person-card pnj">Vendeuse (PNJ)</div></div></body>';

async function avecPage(presents, moi, fn) {
  const serveur = http.createServer((req, res) => { res.setHeader('Content-Type', 'text/html; charset=utf-8'); res.end(PAGE); });
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'hg-groupes-')); let nav, browser;
  try {
    await new Promise((r, j) => { serveur.once('error', j); serveur.listen(0, '127.0.0.1', r); });
    nav = await lancerChromium({ executable: process.env.HG_CHROMIUM || ['/usr/bin/chromium', '/usr/bin/google-chrome', '/usr/bin/google-chrome-stable'].find(p => fs.existsSync(p)), profil });
    browser = await chromium.connectOverCDP('http://127.0.0.1:' + nav.port);
    const page = await browser.contexts()[0].newPage(); await page.setViewportSize({ width: 390, height: 800 });
    await page.goto('http://127.0.0.1:' + serveur.address().port);
    await page.addScriptTag({ content: `
      var state = { country: 'soviet', currentCity: 'ville_b', currentBuilding: null, currentRoom: null, char: { name: 'Arnie' } };
      var rueCentraleNoeudActuel = 'krasnov-place-ours';
      var COUNTRIES = { soviet: { col: '#cc3333' } };
      window._cachePhotosJoueurs = { 'Tom Tom': 'images/x.webp' }; window._cachePhotosJoueursTimestamp = Date.now();
      function encodePnjSafe(o) { return encodeURIComponent(JSON.stringify(o)).replace(/'/g, '%27'); }
      function escapeHtmlText(t) { return String(t).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]); }
      function openSelfView() {} function openPnjModal() {}
      var __presents = ${JSON.stringify(presents)};
      async function sbGetPresencesInRoom() { window.RP_PRESENTS_MOI = ${JSON.stringify(moi)}; return __presents; }
    ` });
    await page.addScriptTag({ content: lire('plateau-multijoueur.js') });
    await fn(page);
  } finally {
    if (browser) await browser.close(); if (nav) await nav.arreter(); serveur.closeAllConnections(); await new Promise(r => serveur.close(r)); fs.rmSync(profil, { recursive: true, force: true });
  }
}
const lignes = page => page.evaluate(() => Array.from(document.querySelectorAll('#persons-list-rue .person-card')).map(c => c.innerText.replace(/\s+/g, ' ').trim()));

test('membre : le chef en tête « Groupe Tom Tom », ma carte juste dessous, rien ne s’intercale ; appel sans argument = liste de la rue', async () => {
  const G = 'g1';
  await avecPage([
    { name: 'Vlad', connecte: true },
    { name: 'Tom Tom', connecte: true, groupe: G, est_chef: true, mon_groupe: true, groupe_libelle: 'Groupe Tom Tom' },
    { name: 'Olga', connecte: false }
  ], { masque: false, chef: 'Tom Tom', est_chef: false, groupe: G, groupe_libelle: 'Groupe Tom Tom' }, async page => {
    await page.evaluate(() => chargerVraisJoueursPresents());   // signal temps réel : sans argument, dans la rue
    const l = await lignes(page);
    assert.match(l[0], /^Groupe Tom Tom Tom Tom \[JOUEUR\]/);
    assert.match(l[1], /^Arnie \(Vous\)/);
    assert.equal(await page.evaluate(() => document.querySelector('.bloc-mon-groupe').children.length), 2);
    assert.ok(l.some(x => /Vlad/.test(x)) && l.some(x => /Olga.*Absent/.test(x)));
    // Rafraîchissement : rien n'est dupliqué, ma carte n'est jamais perdue.
    await page.evaluate(() => chargerVraisJoueursPresents());
    const l2 = await lignes(page);
    assert.equal(l2.filter(x => /Arnie \(Vous\)/.test(x)).length, 1);
    assert.equal(l2.filter(x => /Tom Tom/.test(x)).length, 1);
  });
});

test('masqué hors groupe : « Personnage masqué », portrait du masque, aucun nom réel ; chef masqué = « Groupe d’un personnage masqué »', async () => {
  await avecPage([
    { name: 'Personnage masqué', masque: true, jeton: 'abc', connecte: true, groupe: 'g2', est_chef: true, mon_groupe: false, groupe_libelle: "Groupe d'un personnage masqué" },
    { name: 'Boris', connecte: true, groupe: 'g2', est_chef: false, mon_groupe: false, groupe_libelle: "Groupe d'un personnage masqué" }
  ], { masque: true, chef: null, est_chef: false, groupe: null }, async page => {
    await page.evaluate(() => chargerVraisJoueursPresents('rue-centrale', 'krasnov-place-ours', 'persons-list-rue'));
    const l = await lignes(page);
    const i = l.findIndex(x => /Groupe d’un personnage masqué|Groupe d'un personnage masqué/.test(x));
    assert.ok(i >= 0, l.join(' | '));
    assert.match(l[i], /Personnage masqué \[JOUEUR\] MASQUÉ/);
    assert.match(l[i + 1], /^Boris/);
    assert.equal(await page.evaluate(() => document.querySelector('.presence-membre-groupe').style.marginLeft), '14px');
    assert.equal(await page.evaluate(() => Array.from(document.querySelectorAll('.vrai-joueur-card img')).map(i => i.getAttribute('src'))[0]), 'images/objet-masque-carnaval.webp');
    // Je suis masqué : mon état est sur ma propre ligne.
    assert.match(l.find(x => /Arnie \(Vous\)/.test(x)), /MASQUÉ/);
  });
});
