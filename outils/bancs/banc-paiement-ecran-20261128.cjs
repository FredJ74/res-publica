'use strict';
// Mission du 28/11/2026, étape 4 (décision de Fred) : écran du paiement (plateau-paiement.js).
// Textes complets dans les 9 langues ; aucune couleur en dur ; avant l'achat : vendeur (éditeur + mention 293 B, ou Stripe),
// prix rendu par la base, case CGV et case de renonciation NON pré-cochées (bouton « Payer » bloqué tant qu'elles ne sont pas
// cochées) ; pays non servi : jeu gratuit, aucun achat ; fiche du compte : résiliation en deux clics, remboursement 14 jours.
// Partie navigateur : NODE_PATH=outils/e2e/node_modules CHROMIUM_PATH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
// Lancer : node --test outils/bancs/banc-paiement-ecran-20261128.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const SRC = lire('plateau-paiement.js');

test('9 langues complètes, aucune couleur en dur, aucun prix écrit', () => {
  const ctx = { window: {}, document: { readyState: 'complete' }, setTimeout() {}, URL, console };
  ctx.window = ctx; ctx.window.location = { href: 'https://hg.test/plateau.html' }; ctx.window.history = { replaceState() {} };
  vm.createContext(ctx); vm.runInContext(SRC, ctx);
  const T = ctx.RP_PAIEMENT_T;
  assert.deepEqual(Object.keys(T).sort(), ['ar', 'de', 'en', 'es', 'fr', 'ko', 'pt-BR', 'ru', 'zh-TW']);
  const cles = Object.keys(T.fr).sort(), m = Object.keys(T.fr.m).sort();
  for (const l of Object.keys(T)) { assert.deepEqual(Object.keys(T[l]).sort(), cles, l); assert.deepEqual(Object.keys(T[l].m).sort(), m, l + '.m'); }
  assert.doesNotMatch(SRC, /#[0-9a-fA-F]{3,6}\b|rgba?\(/, 'couleurs : classes de style.css');
  assert.doesNotMatch(SRC, /\d+[.,]\d\d ?€/, 'aucun prix écrit');
  assert.match(T.fr.renonciation, /^Je demande la livraison immédiate et je renonce à mon droit de rétractation\.$/);
  assert.match(SRC, /<input type="checkbox" data-paiement-cgv>/); assert.match(SRC, /<input type="checkbox" data-paiement-renonciation>/);
  assert.doesNotMatch(SRC, /checked(?!\s*[=)&|;.?]|\s*===)/, 'aucune case pré-cochée');
});

let chromium = null;
try { ({ chromium } = require('playwright')); } catch (_) { chromium = null; }
const CHROME = process.env.CHROMIUM_PATH || process.env.HG_CHROMIUM;
if (!chromium || !CHROME) { test('navigateur absent : partie écran avec NODE_PATH et CHROMIUM_PATH', { skip: true }, () => {}); return; }

const PAGE = `<!doctype html><html><head><meta charset="utf-8"></head><body>
<div id="modal-postes"><h2 id="postes-modal-title"></h2><div id="postes-body"></div></div><div id="hote"></div>
<script>window.rpAuthJeton = () => 'jeton'; window.__toasts = []; window.showToast = (a, b) => window.__toasts.push(b);
window.sbRpc = async fn => fn === 'premium_abonnement_lire' ? window.__abo : null;</script>
<script src="/plateau-paiement.js"></script></body></html>`;

async function ouvrir(etat, commande, abo) {
  const nav = await chromium.launch({ executablePath: CHROME, headless: true });
  const page = await nav.newPage();
  const corps = [];
  await page.route('https://hg.test/**', async r => {
    const u = new URL(r.request().url());
    if (u.pathname === '/plateau.html') return r.fulfill({ contentType: 'text/html', body: PAGE });
    if (u.pathname === '/plateau-paiement.js') return r.fulfill({ contentType: 'text/javascript', body: SRC });
    if (u.pathname === '/api/paiement') {
      const b = JSON.parse(r.request().postData() || '{}'); corps.push(b);
      const rep = b.action === 'etat' ? etat : b.action === 'commander' ? commande : (abo.reponses || {})[b.action];
      return r.fulfill({ contentType: 'application/json', body: JSON.stringify(rep || { ok: false }) });
    }
    if (u.pathname === '/paiement-faux.html') return r.fulfill({ contentType: 'text/html', body: '<p>faux</p>' });
    return r.fulfill({ status: 404, body: '' });
  });
  await page.goto('https://hg.test/plateau.html?paiement=annule&achat=a-1');
  await page.evaluate(a => { window.__abo = a; }, abo.lecture || null);
  return { nav, page, corps };
}
const UNITE = { produit: 'renouvellement_image', nature: 'unite', libelle: 'Renouvellement d’une image', prix_centimes: 300 };

test('achat à l’unité (UE) : éditeur vendeur, 293 B, cases non cochées, « Payer » bloqué puis commande avec les deux cases', async () => {
  const { nav, page, corps } = await ouvrir({ ok: true, achats_possibles: true, vendeur: 'editeur', editeur_nom: 'Éditeur Test', cgv_url: '/cgv' },
    { ok: true, url: '/paiement-faux.html?achat=a-1' }, {});
  try {
    assert.equal(await page.evaluate(() => location.search), '', 'paramètres de retour effacés');
    await page.evaluate(p => window.RPPaiement.confirmerAchat('renouvellement_image', null, p), UNITE);
    await page.waitForSelector('[data-paiement-payer]');
    const texte = await page.textContent('#postes-body');
    assert.match(texte, /Vendeur : Éditeur Test\./); assert.match(texte, /TVA non applicable, article 293 B du CGI\./); assert.match(texte, /3,00\s€/);
    assert.equal(await page.isChecked('[data-paiement-cgv]'), false); assert.equal(await page.isChecked('[data-paiement-renonciation]'), false);
    assert.equal(await page.isDisabled('[data-paiement-payer]'), true);
    await page.check('[data-paiement-cgv]');
    assert.equal(await page.isDisabled('[data-paiement-payer]'), true, 'renonciation encore exigée');
    await page.check('[data-paiement-renonciation]');
    assert.equal(await page.isDisabled('[data-paiement-payer]'), false);
    await Promise.all([page.waitForURL(/paiement-faux/), page.click('[data-paiement-payer]')]);
    const c = corps.find(x => x.action === 'commander');
    assert.deepEqual({ ...c, langue: undefined }, { action: 'commander', produit: 'renouvellement_image', cible: null, cgv: true, renonciation: true, langue: undefined });
    assert.ok(!('prix' in c) && !('montant' in c), 'le prix ne part jamais du navigateur');
  } finally { await nav.close(); }
});

test('hors UE : Stripe vendeur ; abonnement sans case de renonciation mais avec l’information de renouvellement', async () => {
  const { nav, page } = await ouvrir({ ok: true, achats_possibles: true, vendeur: 'stripe', cgv_url: '/cgv' }, { ok: false, raison: 'fournisseur_indisponible' }, {});
  try {
    await page.evaluate(() => window.RPPaiement.confirmerAchat('abonnement_annuel', null, { produit: 'abonnement_annuel', nature: 'abonnement', libelle: 'Abonnement annuel', prix_centimes: 4800 }));
    await page.waitForSelector('[data-paiement-payer]');
    const texte = await page.textContent('#postes-body');
    assert.match(texte, /Stripe \(Link\), vendeur officiel/); assert.doesNotMatch(texte, /293 B/);
    assert.match(texte, /Abonnement annuel, renouvelé automatiquement/);
    assert.equal(await page.$('[data-paiement-renonciation]'), null);
    await page.check('[data-paiement-cgv]'); await page.click('[data-paiement-payer]');
    await page.waitForFunction(() => /ne répond pas/.test(document.querySelector('[data-paiement-retour]').textContent));
  } finally { await nav.close(); }
});

test('pays non servi : message « jeu gratuit », aucune case ni bouton de paiement', async () => {
  const { nav, page } = await ouvrir({ ok: true, achats_possibles: false, raison: 'pays_non_servi' }, null, {});
  try {
    await page.evaluate(p => window.RPPaiement.confirmerAchat('renouvellement_image', null, p), UNITE);
    await page.waitForSelector('[data-paiement-annuler]');
    assert.match(await page.textContent('#postes-body'), /pas disponibles depuis votre pays\. Le jeu reste entièrement gratuit\./);
    assert.equal(await page.$('[data-paiement-payer]'), null);
  } finally { await nav.close(); }
});

test('fiche du compte : « Résilier mon abonnement » en deux clics, puis état « résilié » ; remboursement proposé dans les 14 jours', async () => {
  const fin = '2027-01-15T10:00:00Z';
  const abo = { lecture: { ok: true, abonne: true, intervalle: 'month', fin, annule: false, resiliable: true, remboursable: true, remboursable_jusqu_au: '2026-12-12T10:00:00Z' },
    reponses: { resilier: { ok: true, fin } } };
  const { nav, page, corps } = await ouvrir(null, null, abo);
  try {
    await page.evaluate(() => { document.getElementById('hote').innerHTML = window.rpHtmlAbonnementCompte(); });
    await page.waitForSelector('[data-abo-resilier]');
    assert.match(await page.textContent('#bloc-abonnement-compte'), /Abonnement mensuel actif jusqu’au 15 janvier 2027/);
    assert.match(await page.textContent('[data-abo-rembourser]'), /12 décembre 2026/);
    await page.click('[data-abo-resilier]');                       // 1er clic
    assert.match(await page.textContent('[data-abo-confirmer]'), /restera actif jusqu’au 15 janvier 2027/);
    await page.evaluate(a => { window.__abo = { ...a, annule: true, resiliable: false }; }, abo.lecture);
    await page.click('[data-abo-oui]');                            // 2e clic
    await page.waitForFunction(() => /Résiliation enregistrée/.test(document.getElementById('bloc-abonnement-compte').textContent));
    assert.match(await page.textContent('#bloc-abonnement-compte'), /résilié : il reste actif jusqu’au 15 janvier 2027/);
    assert.equal(await page.$('[data-abo-resilier]'), null);
    assert.deepEqual(corps.map(c => c.action), ['resilier']);
  } finally { await nav.close(); }
});
