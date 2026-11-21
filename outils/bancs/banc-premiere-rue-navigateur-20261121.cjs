// Chromium réel : parcours d'arrivée d'un personnage neuf (incident de Régis, 21/11/2026). Vrais fichiers du jeu
// (rue-centrale.css, data.js, plateau-variantes-pieces.js, plateau-rue-centrale.js) ; identité et RPC simulées : aucun
// compte ni aucune écriture en production (base gelée). Luthécia et Novomirsk :
//  1. position vierge (personnage neuf) : la rue de départ s'affiche du premier coup ;
//  2. fiche rechargée pendant la lecture de position (cause du 21/11) : la rue s'affiche quand même ;
//  3. lecture de position en échec : « La ville se charge encore… » + « Réessayer », qui affiche la rue sans recharger ;
//  4. réponse qui n'arrive jamais : le même message au bout de 8 secondes ; journal muet même s'il échoue.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), os = require('node:os'), http = require('node:http');
const { chromium } = require('../e2e/node_modules/playwright');
const { lancerChromium } = require('./fixtures/chromium-cdp.cjs');
const racine = path.resolve(__dirname, '../..');
const FICHIERS = ['/rue-centrale.css', '/data.js', '/plateau-variantes-pieces.js', '/plateau-rue-centrale.js'];

const VILLES = [
  { pays: 'republic', ville: 'capitale', nom: 'Luthécia', depart: 'luthecia-palais-presidentiel' },
  { pays: 'soviet', ville: 'capitale', nom: 'Novomirsk', depart: 'novomirsk-vue-1' }
];

async function avecPage(fn) {
  const page0 = '<!doctype html><meta charset="utf-8"><link rel="stylesheet" href="/rue-centrale.css"><div id="rue-centrale-conteneur"></div>'
    + '<script>var state={char:{name:"Neuf"},country:"republic",currentCity:"capitale",currentBuilding:null,currentRoom:null};</script>'
    + FICHIERS.filter(f => f.endsWith('.js')).map(f => '<script src="' + f + '"></script>').join('');
  const serveur = http.createServer((req, res) => {
    const url = decodeURIComponent(req.url.split('?')[0]);
    if (url === '/') { res.setHeader('Content-Type', 'text/html; charset=utf-8'); res.end(page0); return; }
    if (!FICHIERS.includes(url) && !url.startsWith('/images/')) { res.writeHead(404); res.end(); return; }
    res.setHeader('Content-Type', url.endsWith('.js') ? 'text/javascript' : url.endsWith('.css') ? 'text/css' : url.endsWith('.png') ? 'image/png' : 'image/webp');
    // HG_SOURCE_URL=https://… : mêmes scénarios avec les fichiers réellement déployés (vérification après mise en ligne).
    if (process.env.HG_SOURCE_URL) {
      fetch(process.env.HG_SOURCE_URL + encodeURI(url)).then(async r => { if (!r.ok) throw 0; res.end(Buffer.from(await r.arrayBuffer())); })
        .catch(() => { res.writeHead(404); res.end(); });
      return;
    }
    try { res.end(fs.readFileSync(path.join(racine, url.slice(1)))); } catch (_) { res.writeHead(404); res.end(); }
  });
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'hg-premiere-rue-')); let nav, browser;
  try {
    await new Promise((r, j) => { serveur.once('error', j); serveur.listen(0, '127.0.0.1', r); });
    nav = await lancerChromium({ executable: process.env.HG_CHROMIUM || '/usr/bin/chromium', profil });
    browser = await chromium.connectOverCDP('http://127.0.0.1:' + nav.port);
    const page = await browser.contexts()[0].newPage(); await page.setViewportSize({ width: 1100, height: 800 });
    await page.goto('http://127.0.0.1:' + serveur.address().port);
    await page.waitForFunction(() => typeof initialiserRueCentrale === 'function' && typeof RUE_CENTRALE_NOEUDS === 'object');
    await fn(page);
  } finally {
    if (browser) await browser.close(); if (nav) await nav.arreter();
    serveur.closeAllConnections(); await new Promise(r => serveur.close(r)); fs.rmSync(profil, { recursive: true, force: true });
  }
}

// Serveur simulé : mode 'normal' | 'course' (fiche rechargée pendant la 1re lecture) | 'echec' | 'muet' (aucune réponse).
async function preparer(page, v, mode) {
  await page.evaluate(({ v, mode }) => {
    state.country = v.pays; state.currentCity = v.ville; state.currentBuilding = null; state.char = { name: 'Neuf' };
    document.getElementById('rue-centrale-conteneur').innerHTML = '';
    window.__mode = mode; window.__journal = []; window.__toasts = []; window.__lectures = 0;
    window.showToast = (t, c) => window.__toasts.push(t + ' : ' + c);
    window.SUPABASE_URL = 'https://exemple.invalid'; window.sbEnTetes = () => ({});
    window.fetch = async (url, o) => { window.__journal.push([url, o && o.body]); throw new Error('table absente'); };
    window.sbRpc = async (fn, p) => {
      if (fn === 'rue_position_lire') {
        window.__lectures++;
        if (window.__mode === 'muet') return new Promise(() => {});
        if (window.__mode === 'echec') return null;
        if (window.__mode === 'course' && window.__lectures === 1) state.char = { name: 'Neuf' };   // fiche rechargée
        return { ok: true, country: v.pays, city: v.ville, building: null, street: null };
      }
      if (fn === 'rue_position_enregistrer') return { ok: true, country: v.pays, city: v.ville, street: p.p_noeud };
      return null;
    };
  }, { v, mode });
}
const lancer = (page, v) => page.evaluate(v => { initialiserRueCentrale(v.pays, v.depart, null); }, v);
async function sceneAffichee(page, v, delai = 6000) {
  await page.waitForSelector('#rc-scene #rc-image', { timeout: delai });
  const ok = await page.evaluate(async () => { const i = document.getElementById('rc-image'); await i.decode(); return i.naturalWidth > 0; });
  assert.ok(ok, v.nom + ' : image de rue lisible');
  assert.ok(await page.locator('.rc-fleche').count() > 0, v.nom + ' : flèches de navigation');
  assert.equal(await page.evaluate(() => rueCentraleNoeudActuel), v.depart, v.nom + ' : rue de départ');
  assert.equal(await page.locator('#rc-panne').count(), 0, v.nom + ' : pas de message de panne');
}

for (const v of VILLES) {
  test(`${v.nom} : personnage neuf, la rue de départ s’affiche du premier coup`, () => avecPage(async page => {
    await preparer(page, v, 'normal'); await lancer(page, v); await sceneAffichee(page, v);
    assert.equal(await page.evaluate(() => window.__lectures), 1);
    assert.deepEqual(await page.evaluate(() => window.__toasts), []);
  }));
  test(`${v.nom} : fiche rechargée pendant la lecture (cause du 21/11), la rue s’affiche quand même`, () => avecPage(async page => {
    await preparer(page, v, 'course'); await lancer(page, v); await sceneAffichee(page, v);
  }));
  test(`${v.nom} : échec du chargement → « La ville se charge encore… », « Réessayer » affiche la rue`, () => avecPage(async page => {
    await preparer(page, v, 'echec'); await lancer(page, v);
    const panne = page.locator('#rc-panne');
    await panne.waitFor({ timeout: 12000 });
    assert.match(await panne.innerText(), /La ville se charge encore…/);
    // Journal tenté une fois, échec avalé : aucun message pour le joueur à ce sujet, aucune nouvelle tentative.
    assert.equal(await page.evaluate(() => window.__journal.length), 1);
    assert.match(await page.evaluate(() => window.__journal[0][1]), /"p_type":"rue_vide"/);
    await page.evaluate(() => { window.__mode = 'normal'; });
    await page.locator('#rc-panne-reessayer').click();
    await sceneAffichee(page, v);
    assert.equal(await page.evaluate(() => window.__journal.length), 1, 'pas de boucle de journalisation');
  }));
}

test('Novomirsk : réponse qui n’arrive jamais → message au bout de 8 secondes', () => avecPage(async page => {
  const v = VILLES[1];
  await preparer(page, v, 'muet'); await lancer(page, v);
  await page.waitForTimeout(6000);
  assert.equal(await page.locator('#rc-panne').count(), 0, 'pas trop tôt');
  await page.locator('#rc-panne').waitFor({ timeout: 4000 });
  await page.evaluate(() => { window.__mode = 'normal'; });
  await page.locator('#rc-panne-reessayer').click();
  await sceneAffichee(page, v, 8000);
}));
