// Chromium réel : marché unique de Krasnov (lot de Krasnov, point 2 ; étape I, 22/11/2026).
// Vrai plateau-marche-krasnov.js dans une page factice (fenêtre modal-postes) ; serveur simulé (sbRpc).
// On saisit des quantités au clavier : les totaux bougent en direct, « Valider » se grise avec la raison écrite,
// un seul appel serveur exécute tout, puis la fenêtre se met à jour sans recharger la page.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), os = require('node:os'), http = require('node:http');
const { chromium } = require('../e2e/node_modules/playwright');
const { lancerChromium } = require('./fixtures/chromium-cdp.cjs');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');

const PAGE = '<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width"><body style="margin:0">'
  + '<div id="modal-postes"><div id="postes-modal-title"></div><div id="postes-body"></div></div></body>';

async function avecPage(fn, largeur = 1000) {
  const serveur = http.createServer((req, res) => { res.setHeader('Content-Type', 'text/html; charset=utf-8'); res.end(PAGE); });
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'hg-marche-krasnov-')); let nav, browser;
  try {
    await new Promise((r, j) => { serveur.once('error', j); serveur.listen(0, '127.0.0.1', r); });
    nav = await lancerChromium({ executable: process.env.HG_CHROMIUM || ['/usr/bin/chromium', '/usr/bin/google-chrome', '/usr/bin/google-chrome-stable'].find(p => fs.existsSync(p)), profil });
    browser = await chromium.connectOverCDP('http://127.0.0.1:' + nav.port);
    const page = await browser.contexts()[0].newPage(); await page.setViewportSize({ width: largeur, height: 800 });
    await page.goto('http://127.0.0.1:' + serveur.address().port);
    await page.addScriptTag({ content: `
      var state = { country: 'soviet', currentCity: 'ville_b', currentBuilding: 'marche', currentRoom: 'marche_ext', pa: 3, char: { name: 'Banc', pa: 3 } };
      window.__toasts = []; window.__appels = []; window.__journal = [];
      window.showToast = (t, c, ok) => window.__toasts.push([t, c, ok]);
      window.addJournalEntry = (m) => window.__journal.push(m);
      const P = (cle, label, genre, pv, pr, stock, possede, extra) => Object.assign({ cle, label, genre, prix_vente: pv, prix_rachat: pr, stock, stock_max: 60, possede, recette: null, pa: 0, unites: 0, effet: '' }, extra || {});
      window.__etat = { ok: true, ici: true, caisse: 30, pa: 3, argent: 40, place: 20, salaire_pa: 15, produits: [
        P('fruits_legumes', 'Fruits et légumes', 'brut', 2, 1, 20, 5),
        P('sucre', 'Sucre', 'brut', 2, 1, 10, 0),
        P('bouteille_eau', 'Bouteille d’eau', 'brut', 2, 1, 30, 0),
        P('confiture', 'Confiture d’airelles (bocal)', 'transforme', 10, 7, 8, 0, { recette: { fruits_legumes: 1, sucre: 1 }, pa: 1, unites: 4 }),
        P('tenue_ninja', 'Tenue ninja', 'objet', 32, 24, 2, 2) ] };
      window.sbRpc = async (fn, p) => {
        window.__appels.push([fn, p]);
        if (fn === 'marche_krasnov_etat') return window.__etat;
        if (fn === 'marche_krasnov_valider') {
          const e = JSON.parse(JSON.stringify(window.__etat)); e.caisse += 6 - 15; e.argent += 15 - 6; e.pa -= 1;
          e.produits.find(x => x.cle === 'bouteille_eau').stock -= 3; e.produits.find(x => x.cle === 'confiture').stock += 4;
          window.__etat = e;
          return { ok: true, depense: 6, gain_ventes: 0, salaire: 15, pa_depenses: 1, pa: 2, etat: e, inventory: [],
            lignes: [{ cle: 'bouteille_eau', label: 'Bouteille d’eau', acheter: 3, vendre: 0, produire: 0, produits: 0 },
                     { cle: 'confiture', label: 'Confiture d’airelles (bocal)', acheter: 0, vendre: 0, produire: 1, produits: 4 }] };
        }
        return null;
      };
    ` });
    await page.addScriptTag({ content: lire('plateau-marche-krasnov.js') });
    await fn(page);
  } finally {
    if (browser) await browser.close(); if (nav) await nav.arreter(); serveur.closeAllConnections(); await new Promise(r => serveur.close(r)); fs.rmSync(profil, { recursive: true, force: true });
  }
}
const champ = (cle, col) => `.mk-q[data-cle="${cle}"][data-col="${col}"]`;

test('fenêtre unique : saisie au clavier, totaux en direct, Valider grisé avec la raison, un seul appel, mise à jour sans recharger', async () => {
  await avecPage(async page => {
    await page.evaluate(() => window.ouvrirMarcheKrasnov());
    await page.waitForSelector('#mk-valider');
    assert.equal(await page.textContent('#postes-modal-title'), 'Marché de Krasnov');
    assert.equal(await page.isDisabled('#mk-valider'), true);
    assert.equal(await page.textContent('#mk-raison'), 'Inscrivez au moins une quantité.');
    assert.equal(await page.isDisabled(champ('sucre', 'v')), true, 'rien à vendre : champ grisé');
    assert.equal(await page.locator(champ('tenue_ninja', 'p')).count(), 0, 'un objet ne se produit pas');

    // Vendre les deux tenues : la caisse (30 PSK) ne peut pas payer 48 PSK.
    await page.fill(champ('tenue_ninja', 'v'), '2');
    assert.equal(await page.isDisabled('#mk-valider'), true);
    assert.match(await page.textContent('#mk-raison'), /La caisse du marché est vide : elle ne peut payer que 30 PSK/);
    assert.match(await page.getAttribute('#mk-valider', 'title'), /caisse du marché est vide/);
    // Plafonnement automatique au stock : 9 tenues demandées à l'achat → 2.
    await page.fill(champ('tenue_ninja', 'v'), '');
    await page.fill(champ('tenue_ninja', 'a'), '9');
    assert.equal(await page.inputValue(champ('tenue_ninja', 'a')), '2');
    await page.fill(champ('tenue_ninja', 'a'), '');

    await page.fill(champ('bouteille_eau', 'a'), '3');
    await page.fill(champ('confiture', 'p'), '1');
    assert.equal(await page.textContent('#mk-total'), 'Vous dépensez 6 PSK · vous gagnez 0 PSK (ventes) + 15 PSK (travail) · PA : 1');
    assert.equal(await page.isDisabled('#mk-valider'), false);
    await page.click('#mk-valider');
    await page.waitForFunction(() => document.getElementById('postes-body').textContent.includes('C’est fait.'));
    const appels = await page.evaluate(() => window.__appels.filter(a => a[0] === 'marche_krasnov_valider'));
    assert.equal(appels.length, 1);
    assert.deepEqual(appels[0][1].p_lignes, [{ cle: 'bouteille_eau', acheter: 3, vendre: 0, produire: 0 }, { cle: 'confiture', acheter: 0, vendre: 0, produire: 1 }]);
    assert.match(appels[0][1].p_requete, /^[0-9a-f-]{36}$/);
    // Fenêtre rafraîchie avec l'état renvoyé par le serveur (sans nouvelle lecture), saisie remise à zéro.
    assert.match(await page.textContent('#postes-body'), /Au marché : 27/);
    assert.match(await page.textContent('#postes-body'), /Caisse du marché : 21 PSK/);
    assert.equal(await page.inputValue(champ('bouteille_eau', 'a')), '');
    const t = await page.evaluate(() => window.__toasts.pop());
    assert.match(t[1], /3 × Bouteille d’eau acheté\(s\), 4 × Confiture d’airelles \(bocal\) produit\(s\)/);
    assert.equal(await page.evaluate(() => window.__journal.length), 1);
    // Annuler vide la saisie.
    await page.fill(champ('fruits_legumes', 'a'), '1');
    await page.click('#mk-annuler');
    assert.equal(await page.inputValue(champ('fruits_legumes', 'a')), '');
  });
});

test('petit écran (390 px) : la page ne défile pas en largeur, le tableau défile dans sa boîte', async () => {
  await avecPage(async page => {
    await page.evaluate(() => window.ouvrirMarcheKrasnov());
    await page.waitForSelector('#mk-valider');
    const l = await page.evaluate(() => ({ doc: document.documentElement.scrollWidth, vue: window.innerWidth }));
    assert.ok(l.doc <= l.vue, JSON.stringify(l));
  }, 390);
});
