// Chromium réel : « let state » de plateau-core.js n'est pas une propriété de window. Les modules qui lisent window.state
// (informateurs, accueil, médecin, secrets, énigme de Krasnov, événements) voyaient un objet vide : écran des informateurs
// « Personne ici ne vend d'informations », accueil sans nom de personnage. Correctif du 23/11/2026 : accesseur window.state
// posé par plateau-core.js juste après la déclaration. On rejoue la vraie ligne du cœur dans une page, avec un vrai « let ».
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), os = require('node:os'), http = require('node:http');
const { chromium } = require('../e2e/node_modules/playwright');
const { lancerChromium } = require('./fixtures/chromium-cdp.cjs');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');

const core = lire('plateau-core.js');
const ligne = core.split('\n').find(l => l.includes("Object.defineProperty(window, 'state'"));

test('plateau-core.js pose l’accesseur window.state juste après « let state »', () => {
  assert.ok(ligne, 'ligne de l’accesseur absente de plateau-core.js');
  const iLet = core.indexOf('\nlet state = {'), iAcc = core.indexOf(ligne);
  assert.ok(iLet > 0 && iAcc > iLet, 'accesseur après la déclaration');
  // Tous les modules qui lisent window.state / global.state se chargent après plateau-core.js.
  const html = lire('plateau.html'), pos = f => html.indexOf('src="' + f + '?');
  const lecteurs = fs.readdirSync(root).filter(f => /^plateau.*\.js$/.test(f) && f !== 'plateau-core.js' && /\b(global|window)\.state\b/.test(lire(f)));
  assert.ok(lecteurs.length >= 5, lecteurs.join(', '));
  for (const f of lecteurs) if (pos(f) >= 0) assert.ok(pos(f) > pos('plateau-core.js'), f + ' chargé avant plateau-core.js');
});

test('dans une vraie page : window.state suit « let state », même réassigné ; le module des informateurs lit la bonne pièce', async () => {
  const serveur = http.createServer((q, r) => { r.setHeader('Content-Type', 'text/html; charset=utf-8'); r.end('<!doctype html><meta charset="utf-8"><body></body>'); });
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'hg-state-window-')); let nav, browser;
  try {
    await new Promise((r, j) => { serveur.once('error', j); serveur.listen(0, '127.0.0.1', r); });
    nav = await lancerChromium({ executable: process.env.HG_CHROMIUM || process.env.CHROMIUM_PATH || ['/usr/bin/chromium', '/usr/bin/google-chrome', '/usr/bin/google-chrome-stable'].find(p => fs.existsSync(p)), profil });
    browser = await chromium.connectOverCDP('http://127.0.0.1:' + nav.port);
    const page = await browser.contexts()[0].newPage();
    await page.goto('http://127.0.0.1:' + serveur.address().port);
    await page.addScriptTag({ content: 'let state = { char: { name: "Tom" }, country: "soviet", currentCity: "ville_b", currentBuilding: "bar-sever", currentRoom: "salle" };\n' + ligne });
    assert.equal(await page.evaluate(() => Object.prototype.hasOwnProperty.call(window, 'state')), true);
    assert.equal(await page.evaluate(() => window.state.char.name), 'Tom');
    await page.addScriptTag({ content: 'state = { char: { name: "Ana" }, country: "republic" };' });
    assert.equal(await page.evaluate(() => window.state.char.name), 'Ana', 'réassignation suivie');
    await page.addScriptTag({ content: 'state = { char: { name: "Tom" }, country: "soviet", currentCity: "ville_b", currentBuilding: "bar-sever", currentRoom: "salle" };' });
    // Le vrai module des informateurs : il demande au serveur (simulé) et range la réponse sous la clé de la pièce.
    await page.addScriptTag({ content: 'window.__appels = []; window.sbRpc = async (fn) => { window.__appels.push(fn); return { ok: true, pays: "soviet", ville: "ville_b", batiment: "bar-sever", piece: "salle", informateurs: [{ id: "habitue_krasnov", nom: "L’habitué", profil: "generaliste" }] }; };' });
    await page.addScriptTag({ content: lire('plateau-informateurs.js') });
    const k = await page.evaluate(() => [window.state.country, window.state.currentCity, window.state.currentBuilding, window.state.currentRoom].join('/'));
    assert.equal(k, 'soviet/ville_b/bar-sever/salle', 'clé de pièce non vide');
  } finally {
    if (browser) await browser.close(); if (nav) await nav.arreter(); serveur.closeAllConnections(); await new Promise(r => serveur.close(r)); fs.rmSync(profil, { recursive: true, force: true });
  }
});
