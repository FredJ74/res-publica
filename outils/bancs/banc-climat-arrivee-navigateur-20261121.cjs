// Chromium réel : un personnage neuf arrive à Novomirsk pendant un orage (cas de Régis, 21/11/2026), avec le correctif de
// la première rue (partie A) et le vrai plateau-climat.js. Vrais fichiers du jeu ; identité et RPC simulées.
// Contrôles : rue affichée du premier coup, flèches nettes au-dessus du filtre, alerte « Attention : orage » en
// pictogramme, fenêtre d'accueil (une seule fois) avec la durée restante puis la consigne, aucune exemption.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), os = require('node:os'), http = require('node:http');
const { chromium } = require('../e2e/node_modules/playwright');
const { lancerChromium } = require('./fixtures/chromium-cdp.cjs');
const racine = path.resolve(__dirname, '../..');
const FICHIERS = ['/rue-centrale.css', '/data.js', '/plateau-variantes-pieces.js', '/plateau-rue-centrale.js', '/plateau-climat.js'];

test('Novomirsk, orage en cours : rue affichée, alerte et fenêtre d’accueil une seule fois', async () => {
  const page0 = '<!doctype html><meta charset="utf-8"><link rel="stylesheet" href="/rue-centrale.css"><div id="rue-image"><div id="rue-centrale-conteneur"></div></div>'
    + '<script>var state={char:{name:"Régis"},country:"soviet",currentCity:"capitale",currentBuilding:null,currentRoom:null};</script>'
    + FICHIERS.filter(f => f.endsWith('.js')).map(f => '<script src="' + f + '"></script>').join('');
  const serveur = http.createServer((req, res) => {
    const url = decodeURIComponent(req.url.split('?')[0]);
    if (url === '/') { res.setHeader('Content-Type', 'text/html; charset=utf-8'); res.end(page0); return; }
    if (!FICHIERS.includes(url) && !url.startsWith('/images/')) { res.writeHead(404); res.end(); return; }
    try { res.setHeader('Content-Type', url.endsWith('.js') ? 'text/javascript' : url.endsWith('.css') ? 'text/css' : 'image/webp'); res.end(fs.readFileSync(path.join(racine, url.slice(1)))); }
    catch (_) { res.writeHead(404); res.end(); }
  });
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'hg-climat-arrivee-')); let nav, browser;
  try {
    await new Promise((r, j) => { serveur.once('error', j); serveur.listen(0, '127.0.0.1', r); });
    nav = await lancerChromium({ executable: process.env.HG_CHROMIUM || ['/usr/bin/chromium', '/usr/bin/google-chrome', '/usr/bin/google-chrome-stable'].find(p => require('node:fs').existsSync(p)), profil });
    browser = await chromium.connectOverCDP('http://127.0.0.1:' + nav.port);
    const page = await browser.contexts()[0].newPage(); await page.setViewportSize({ width: 1100, height: 800 });
    await page.goto('http://127.0.0.1:' + serveur.address().port);
    await page.waitForFunction(() => typeof initialiserRueCentraleSure === 'function' && window.RPClimat);
    await page.evaluate(() => {
      const t = Date.now();
      const orage = { id: 19, type: 'orage', ville: 'capitale', debut: new Date(t - 3600e3).toISOString(), fin: new Date(t + 5 * 3600e3).toISOString(),
        lieux: [], lieux_proteges: [], en_cours: true,
        consigne: 'Pendant 6 heures, ordinateurs, box et caméras sont hors service : plus de surveillance, de trading à distance ni de piratage, et les chantiers sont à l’arrêt.' };
      window.__vus = []; window.__toasts = [];
      window.showToast = (a, b) => window.__toasts.push(a + ' : ' + b);
      window.sbRpc = async (fn, p) => {
        if (fn === 'rue_position_lire') return { ok: true, country: 'soviet', city: 'capitale', building: null, street: null };
        if (fn === 'rue_position_enregistrer') return { ok: true, country: 'soviet', city: 'capitale', street: p.p_noeud };
        if (fn === 'climat_etat') return { ok: true, evenements: [orage] };
        if (fn === 'climat_accueil_lire') return { ok: true, evenement: window.__vus.includes(19) ? null : orage };
        if (fn === 'climat_accueil_vu') { window.__vus.push(p.p_evenement); return { ok: true }; }
        if (fn === 'climat_effets_lire' || fn === 'climat_points_eau_lister') return { ok: true, points: [] };
        return null;
      };
      initialiserRueCentraleSure('soviet', 'novomirsk-vue-1', null);
    });
    await page.waitForSelector('#rc-scene #rc-image', { timeout: 6000 });
    assert.equal(await page.locator('#rc-panne').count(), 0);
    await page.evaluate(() => window.RPClimat.rafraichirClimat());
    // Fenêtre d'accueil : phrase de bienvenue, durée restante, puis consigne.
    const d = page.locator('#climat-explication'); await d.waitFor();
    const txt = await d.innerText();
    assert.match(txt, /Bienvenue à Novomirsk/);
    assert.match(txt, /Un événement climatique frappe la ville en ce moment \(orage\)/);
    assert.ok(txt.indexOf('Encore ') >= 0 && txt.indexOf('Encore ') < txt.indexOf('Pendant 6 heures'), 'durée restante avant la consigne');
    await d.locator('button').click();
    await page.waitForFunction(() => window.__vus.includes(19));
    // Aucune exemption : filtre et alerte comme pour tout le monde ; flèches nettes au-dessus et cliquables.
    await page.evaluate(() => window.RPClimat.appliquerFiltre());
    assert.equal(await page.locator('#climat-filtre.orage').count(), 1);
    assert.match(await page.locator('#climat-alerte .climat-alerte-texte').textContent(), /^Attention : orage$/);
    assert.equal(await page.locator('#climat-alerte svg.climat-picto').count(), 1);
    const fleche = page.locator('.rc-fleche').first();
    const z = await page.evaluate(() => [getComputedStyle(document.querySelector('.rc-fleche')).zIndex, getComputedStyle(document.getElementById('climat-filtre')).zIndex].map(Number));
    assert.ok(z[0] > z[1], 'flèches au-dessus du filtre');
    const r = await fleche.boundingBox();
    assert.equal(await page.evaluate(([x, y]) => !!document.elementFromPoint(x, y).closest('.rc-fleche'), [r.x + r.width / 2, r.y + r.height / 2]), true, 'flèche cliquable');
    // Une seule fois par événement.
    await page.evaluate(() => window.RPClimat.rafraichirClimat()); await page.waitForTimeout(200);
    assert.equal(await page.locator('#climat-explication').count(), 0);
  } finally {
    if (browser) await browser.close(); if (nav) await nav.arreter();
    serveur.closeAllConnections(); await new Promise(r => serveur.close(r)); fs.rmSync(profil, { recursive: true, force: true });
  }
});
