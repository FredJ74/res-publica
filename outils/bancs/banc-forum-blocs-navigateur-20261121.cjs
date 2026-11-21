// Chromium réel : messages composés du forum (Fred, 21/11/2026, soir, point 2 et complément G) — vrai forum-canvas.js.
// Ordinateur : agencement libre conservé, chevauchement corrigé à l'affichage. Petit écran : blocs empilés dans
// l'ordre de lecture (haut puis gauche), sans défilement horizontal.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), os = require('node:os'), http = require('node:http');
const { chromium } = require('../e2e/node_modules/playwright');
const { lancerChromium } = require('./fixtures/chromium-cdp.cjs');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const PAGE = '<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width"><body style="margin:0"><div id="forum-body"><div id="post"></div></div></body>';
const LAYOUT = { canvas_width: 680, elements: [
  { type: 'text_zone', html_fallback: '<p>Deuxième (à droite)</p>', layout: { x: 360, y: 0, width: 300, contentHeight: 40 } },
  { type: 'text_zone', html_fallback: '<p>Premier (en haut à gauche)</p>', layout: { x: 0, y: 0, width: 320, contentHeight: 40 } },
  // Ancien message : ce bloc chevauche le premier (texte plus long que prévu).
  { type: 'text_zone', html_fallback: '<p>Troisième</p><p>ligne</p><p>ligne</p><p>ligne</p>', layout: { x: 20, y: 20, width: 300, contentHeight: 20 } }
] };

async function avecPage(largeur, fn) {
  const serveur = http.createServer((req, res) => { res.setHeader('Content-Type', 'text/html; charset=utf-8'); res.end(PAGE); });
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'hg-forum-')); let nav, browser;
  try {
    await new Promise((r, j) => { serveur.once('error', j); serveur.listen(0, '127.0.0.1', r); });
    nav = await lancerChromium({ executable: process.env.HG_CHROMIUM || ['/usr/bin/chromium', '/usr/bin/google-chrome', '/usr/bin/google-chrome-stable'].find(p => fs.existsSync(p)), profil });
    browser = await chromium.connectOverCDP('http://127.0.0.1:' + nav.port);
    const page = await browser.contexts()[0].newPage(); await page.setViewportSize({ width: largeur, height: 800 });
    await page.goto('http://127.0.0.1:' + serveur.address().port);
    await page.addScriptTag({ content: 'function sanitizeRichHtml(h){return h;}' });
    await page.addScriptTag({ content: lire('forum-canvas.js') });
    await page.evaluate(l => { document.getElementById('post').innerHTML = renderComposedPost(l); rpCanvasFixRenderedHeights(document); }, LAYOUT);
    await fn(page);
  } finally {
    if (browser) await browser.close(); if (nav) await nav.arreter(); serveur.closeAllConnections(); await new Promise(r => serveur.close(r)); fs.rmSync(profil, { recursive: true, force: true });
  }
}
const boites = page => page.evaluate(() => Array.from(document.querySelectorAll('.rp-composed-canvas > div')).map(d => { const r = d.getBoundingClientRect(); return { t: d.innerText.split('\n')[0], g: r.left, d: r.right, h: r.top, b: r.bottom }; }));

test('ordinateur : agencement libre, ordre de lecture, aucun bloc ne recouvre un autre', () => avecPage(1200, async page => {
  const b = await boites(page);
  assert.deepEqual(b.map(x => x.t), ['Premier (en haut à gauche)', 'Deuxième (à droite)', 'Troisième']);
  assert.ok(b[1].g > b[0].d - 1, 'le deuxième reste à droite du premier');
  for (let i = 0; i < b.length; i++) for (let j = i + 1; j < b.length; j++) {
    const x = b[i], y = b[j];
    assert.ok(!(x.g < y.d && x.d > y.g && x.h < y.b && x.b > y.h), x.t + ' recouvre ' + y.t);
  }
}));

test('petit écran : blocs empilés dans l’ordre de lecture, pleine largeur, sans défilement horizontal', () => avecPage(375, async page => {
  const b = await boites(page);
  assert.deepEqual(b.map(x => x.t), ['Premier (en haut à gauche)', 'Deuxième (à droite)', 'Troisième']);
  for (let i = 1; i < b.length; i++) assert.ok(b[i].h >= b[i - 1].b - 1, 'empilés');
  assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth), true);
}));
