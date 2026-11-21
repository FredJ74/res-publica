// Chromium réel : forêt de Krasnov (version définitive du 21/11/2026) — portique cliquable vers la clairière, sentier de la
// clairière et sous-bois des vues vers l'exploration, infobulle « Explorer la forêt », halo très léger, vraies images.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), os = require('node:os'), http = require('node:http');
const { chromium } = require('../e2e/node_modules/playwright');
const { lancerChromium } = require('./fixtures/chromium-cdp.cjs');
const racine = path.resolve(__dirname, '../..');
const FICHIERS = ['/data.js', '/plateau-variantes-pieces.js', '/plateau-foret-krasnov.js'];
const PAGE = '<!doctype html><meta charset="utf-8"><body><div id="piece-image" style="width:900px;height:506px;background-size:cover"></div>'
  + '<script>var state={country:"soviet",currentCity:"ville_b",currentBuilding:"zone-production",currentRoom:"zone_recolte"};window.__aller=[];'
  + 'function enterRoom(b,r){state.currentRoom=r;} function foretAller(s){__aller.push(s);}</script>'
  + FICHIERS.map(f => '<script src="' + f + '"></script>').join('') + '</body>';
test('portique → clairière, sentier → exploration, sous-bois → exploration ; rien ailleurs', async () => {
  const serveur = http.createServer((req, res) => {
    const url = decodeURIComponent(req.url.split('?')[0]);
    if (url === '/') { res.setHeader('Content-Type', 'text/html; charset=utf-8'); res.end(PAGE); return; }
    try { res.setHeader('Content-Type', url.endsWith('.js') ? 'text/javascript' : 'image/webp'); res.end(fs.readFileSync(path.join(racine, url.slice(1)))); }
    catch (_) { res.writeHead(404); res.end(); }
  });
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'hg-foret-')); let nav, browser;
  try {
    await new Promise((r, j) => { serveur.once('error', j); serveur.listen(0, '127.0.0.1', r); });
    nav = await lancerChromium({ executable: process.env.HG_CHROMIUM || '/usr/bin/chromium', profil });
    browser = await chromium.connectOverCDP('http://127.0.0.1:' + nav.port);
    const page = await browser.contexts()[0].newPage(); await page.setViewportSize({ width: 1000, height: 700 });
    const erreurs = []; page.on('pageerror', e => erreurs.push(e.message));
    await page.goto('http://127.0.0.1:' + serveur.address().port);
    await page.waitForFunction(() => window.RPForetKrasnov);
    const salle = async r => { await page.evaluate(r => enterRoom('zone-production', r), r); await page.waitForFunction(() => { const b = document.querySelector('.foret-porte'); return b && b.style.display === 'block' && b.style.width; }); };
    // Entrée : le portique, en haut à droite de l'image.
    await salle('zone_recolte');
    const porte = page.locator('.foret-porte');
    assert.equal(await porte.getAttribute('title'), 'Explorer la forêt');
    assert.equal(await porte.evaluate(e => getComputedStyle(e).cursor), 'pointer');
    assert.match(await porte.evaluate(e => getComputedStyle(e).animationName), /foretHalo/);
    const bb = await porte.boundingBox();
    assert.ok(bb.x > 600 && bb.y < 300, 'au fond à droite, au-dessus du chemin');
    await porte.click();
    assert.deepEqual(await page.evaluate(() => __aller), ['clairiere']);
    // Clairière : le sentier, au centre et en bas.
    await salle('foret_clairiere');
    await page.locator('.foret-porte').click();
    // Vue de la forêt : le sous-bois.
    await salle('foret_vue_3');
    await page.locator('.foret-porte').click();
    assert.deepEqual(await page.evaluate(() => __aller), ['clairiere', 'enfoncer', 'enfoncer']);
    // Ailleurs : aucune zone.
    await page.evaluate(() => { state.currentCity = 'ville_a'; enterRoom('zone-production', 'zone_recolte'); });
    assert.equal(await page.locator('.foret-porte').count(), 0);
    // Moins d'animations demandé : le halo ne pulse plus.
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await page.evaluate(() => { state.currentCity = 'ville_b'; enterRoom('zone-production', 'zone_recolte'); });
    assert.equal(await page.locator('.foret-porte').evaluate(e => getComputedStyle(e).animationName), 'none');
    assert.deepEqual(erreurs, []);
  } finally {
    if (browser) await browser.close(); if (nav) await nav.arreter();
    serveur.closeAllConnections(); await new Promise(r => serveur.close(r)); fs.rmSync(profil, { recursive: true, force: true });
  }
});
