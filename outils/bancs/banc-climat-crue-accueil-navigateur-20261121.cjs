// Chromium réel : décisions climat de Fred du 21/11/2026 (GAME-DESIGN-CLIMAT-20261121.md).
// Vue de rue factice (scène, flèche, zones de bâtiments) + vrai plateau-climat.js ; serveur simulé (sbRpc).
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), os = require('node:os'), http = require('node:http');
const { chromium } = require('../e2e/node_modules/playwright');
const { lancerChromium } = require('./fixtures/chromium-cdp.cjs');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');

const PAGE = '<!doctype html><meta charset="utf-8"><body><div id="rue-image" style="position:relative;width:800px;height:450px">'
  + '<div id="rue-centrale-conteneur"><div class="rc-scene" id="rc-scene" style="position:relative;width:800px;height:450px">'
  + '<div class="rc-fleche" id="fleche" style="left:10px;top:200px;width:40px;height:40px" onclick="window.__deplace=(window.__deplace||0)+1"></div>'
  + '<div class="rc-zone" id="z-marche" data-building="marche-psm" style="position:absolute;left:100px;top:100px;width:120px;height:120px"></div>'
  + '<div class="rc-zone" id="z-gare" data-building="psm-centre-multimodal" style="position:absolute;left:300px;top:100px;width:120px;height:120px"></div>'
  + '</div></div></div></body>';

async function avecPage(fn, { maintenant, creationRecente = true } = {}) {
  const serveur = http.createServer((req, res) => { res.setHeader('Content-Type', 'text/html; charset=utf-8'); res.end(PAGE); });
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'hg-climat-crue-')); let nav, browser;
  try {
    await new Promise((r, j) => { serveur.once('error', j); serveur.listen(0, '127.0.0.1', r); });
    nav = await lancerChromium({ executable: process.env.HG_CHROMIUM || '/usr/bin/chromium', profil });
    browser = await chromium.connectOverCDP('http://127.0.0.1:' + nav.port);
    const page = await browser.contexts()[0].newPage(); await page.setViewportSize({ width: 1000, height: 700 });
    await page.goto('http://127.0.0.1:' + serveur.address().port);
    const t0 = maintenant || Date.now();
    await page.addScriptTag({ content: `
      var state = { country: 'republic', currentCity: 'ville_a', currentBuilding: null, currentRoom: null, char: { name: 'Banc' } };
      window.__toasts = []; window.__vus = []; window.__entrees = 0;
      window.showToast = (t, c) => window.__toasts.push([t, c]);
      const crue = { id: 77, type: 'crue', ville: 'ville_a', debut: new Date(${t0} - 3600e3).toISOString(), fin: new Date(${t0} + 5 * 3600e3 + 20 * 60e3).toISOString(), lieux: ['marche-psm', 'port-sainte-marie'], en_cours: true };
      window.__crue = crue;
      window.sbRpc = async (fn, p) => {
        if (fn === 'climat_etat') return { ok: true, evenements: [crue] };
        if (fn === 'climat_effets_lire') return { ok: true };
        if (fn === 'climat_accueil_lire') return { ok: true, evenement: (${creationRecente} && !window.__vus.includes(77)) ? crue : null };
        if (fn === 'climat_accueil_vu') { window.__vus.push(p.p_evenement); return { ok: true }; }
        return null;
      };
      document.getElementById('z-marche').addEventListener('click', () => window.__entrees++);
      document.getElementById('z-gare').addEventListener('click', () => window.__entrees++);
    ` });
    await page.addScriptTag({ content: lire('plateau-climat.js') });
    await fn(page);
  } finally {
    if (browser) await browser.close(); if (nav) await nav.arreter(); serveur.closeAllConnections(); await new Promise(r => serveur.close(r)); fs.rmSync(profil, { recursive: true, force: true });
  }
}

test('nouveau personnage pendant une crue : fenêtre d’accueil complète, une seule fois', async () => {
  await avecPage(async page => {
    await page.evaluate(() => window.RPClimat.rafraichirClimat());
    const d = page.locator('#climat-explication');
    await d.waitFor();
    const txt = await d.innerText();
    assert.match(txt, /Bienvenue à Port-Sainte-Marie/);
    assert.match(txt, /crue/);
    assert.match(txt, /Encore 5 h 2\d min/, 'durée restante');
    assert.match(txt, /Lieux fermés : /);
    assert.match(txt, /Ce que cela change pour vous/);
    assert.match(txt, /Ce que vous pouvez faire en attendant/);
    assert.match(txt, /prendre le train à la gare/);
    assert.equal(await page.locator('#climat-gouvernement').count(), 0, 'pas de doublon avec le message du gouvernement');
    await d.locator('button').click();
    await page.waitForFunction(() => window.__vus.includes(77));
    await page.evaluate(() => window.RPClimat.rafraichirClimat());
    await page.waitForTimeout(150);
    assert.equal(await page.locator('#climat-explication').count(), 0, 'affichée une seule fois par événement');
  });
});

test('personnage ancien : aucune fenêtre d’accueil', async () => {
  await avecPage(async page => {
    await page.evaluate(() => window.RPClimat.rafraichirClimat());
    await page.waitForTimeout(150);
    assert.equal(await page.locator('#climat-explication').count(), 0);
  }, { creationRecente: false });
});

test('crue : on circule, la gare reste ouverte, le lieu touché est fermé avec un message clair', async () => {
  await avecPage(async page => {
    await page.evaluate(async () => { await window.RPClimat.rafraichirClimat(); document.getElementById('climat-explication')?.remove(); document.getElementById('climat-gouvernement')?.remove(); window.RPClimat.appliquerFiltre(); });
    // Marque sur le seul lieu touché, expliquée au survol.
    assert.equal(await page.locator('#z-marche.climat-inonde').count(), 1);
    assert.equal(await page.locator('#z-gare.climat-inonde').count(), 0, 'la gare n’est jamais marquée');
    assert.match(await page.locator('#z-marche').getAttribute('title'), /Fermé \(crue\) : .*réouverture dans 5 h/);
    // Déplacement : la flèche reste au-dessus du filtre et cliquable.
    await page.locator('#fleche').click();
    assert.equal(await page.evaluate(() => window.__deplace), 1);
    // Entrée dans la gare : permise ; entrée dans le lieu inondé : bloquée, message (cause, durée, que faire).
    await page.locator('#z-gare').click();
    assert.equal(await page.evaluate(() => window.__entrees), 1);
    await page.locator('#z-marche').click();
    assert.equal(await page.evaluate(() => window.__entrees), 1, 'entrée bloquée');
    const [titre, corps] = await page.evaluate(() => window.__toasts.at(-1));
    assert.equal(titre, 'Lieu fermé : crue');
    assert.match(corps, /fermé à cause de la crue/);
    assert.match(corps, /rouvre dans 5 h/);
    assert.match(corps, /gare et trains restent ouverts/);
    // Refus du serveur (autre chemin d'entrée) : même message clair.
    await page.evaluate(() => window.showToast('Déplacement refusé', 'batiment_inonde'));
    assert.match(await page.evaluate(() => window.__toasts.at(-1)[1]), /fermé à cause de la crue.*rouvre dans/);
  });
});

test('le bandeau « Attention crue » s’explique au clic ; tout disparaît à l’heure de fin', async () => {
  await avecPage(async page => {
    await page.evaluate(async () => { await window.RPClimat.rafraichirClimat(); document.getElementById('climat-explication')?.remove(); window.RPClimat.appliquerFiltre(); });
    await page.locator('#climat-alerte').click();
    const txt = await page.locator('#climat-explication').innerText();
    assert.match(txt, /Crue/); assert.match(txt, /Encore 5 h/); assert.match(txt, /Ce que vous pouvez faire en attendant/);
    await page.locator('#climat-explication button').click();
    // Fin de l'événement (12 heures) : le client le lit lui-même, sans attendre le serveur.
    await page.evaluate(() => { window.__crue.fin = new Date(Date.now() - 1000).toISOString(); window.RPClimat.appliquerFiltre(); });
    assert.equal(await page.locator('#climat-filtre').count(), 0);
    assert.equal(await page.locator('#climat-alerte').count(), 0);
    assert.equal(await page.locator('.climat-inonde').count(), 0);
  });
});
