'use strict';
// Presse — décisions de Fred du 21/11/2026 (étape F) : monde fictif (jamais « soviétique »), point de vue de chaque pays,
// anonymat absolu, noms cliquables. Consignes du rédacteur, filet du générateur, migration (PGlite), rendu (Chromium).
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const lire = f => fs.readFileSync(path.join(root, f), 'utf8');

test('consignes du rédacteur : monde fictif, point de vue du pays, anonymat absolu', () => {
  const g = lire('api/_journal-generation.js');
  assert.match(g, /La Sovarka est SOVARKIENNE, jamais « soviétique »/);
  assert.match(g, /N'emploie JAMAIS « soviétique », « Soviétiques », « URSS »/);
  assert.match(g, /quand un fait a lieu SUR LE TERRITOIRE de ton pays et implique un étranger/);
  assert.match(g, /site militaire, sensible ou d'écoute/);
  assert.match(g, /Le journal du pays de l'étranger garde son propre angle/);
  assert.match(g, /un auteur anonyme \("auteur":\{"identifie":false\}\) n'est JAMAIS nommé/);
  assert.match(g, /Ne rapproche JAMAIS deux affaires d'une façon qui laisserait deviner l'identité d'un auteur anonyme/);
  assert.match(g, /json = assainirMondeReel\(json\);/);
});

test('filet du générateur : aucune référence au monde réel ne passe', async () => {
  const { assainirMondeReel, assainirTexteMondeReel } = await import(path.join(root, 'api/_journal-generation.js'));
  assert.equal(assainirTexteMondeReel('En terre soviétique, les formations soviétiques battent les Soviétiques.'),
    'En terre de Sovarka, les formations de Sovarka battent les Sovarkiens.');
  assert.equal(assainirTexteMondeReel("l'URSS et l’Union soviétique"), 'la Sovarka et la Sovarka');
  const ed = assainirMondeReel({ une: { sujets: [{ titre: 'Victoires soviétiques', n: 2 }] } });
  assert.equal(ed.une.sujets[0].titre, 'Victoires de Sovarka'); assert.equal(ed.une.sujets[0].n, 2);
});

test('migration : noms cités (jamais l’auteur anonyme) et numéros corrigés (PGlite)', async () => {
  const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
  let PGlite = null;
  try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
  if (!PGlite) return;   // contrôleur général sans PGlite : le workflow presse l'exécute avec PGLITE_DIR
  const db = new PGlite();
  await db.exec(lire('outils/bancs/fixtures/presse-pglite-socle.sql.txt'));
  await db.query("INSERT INTO journaux VALUES ('pravdovka', 'Pravdovka', 'soviet', 'pravdovka')");
  const faits = { FACTS: [
    { id: 'f1', acteur: 'Arnie', estPJ: true, victime: { nom: 'Arnie', estPJ: true }, auteur: { identifie: false, designation: 'un individu masqué' } },
    { id: 'f2', acteur: 'Tom Tom', estPJ: true, auteur: { identifie: true, nom: 'Commissaire Volkov' } },
    { id: 'f3', acteur: 'Ivan PNJ', estPJ: false }], PUBLIC_STATEMENTS: [] };
  await db.query("INSERT INTO journal_editions VALUES ('e1', 'pravdovka', '2026-11-21', 'publiee', 'v2-la-tribune', $1, $2, '{}', $3)",
    [JSON.stringify({ sujets: [{ titre: 'Les Soviétiques en terre soviétique' }] }), JSON.stringify({ articles: [] }), JSON.stringify(faits)]);
  await db.exec(lire('migrations/20261121160000_presse_noms_cites_monde_reel.sql'));
  const r = (await db.query("SELECT journal_edition_lire('e1') r")).rows[0].r;
  assert.deepEqual(r.noms_cites, ['Arnie', 'Commissaire Volkov', 'Tom Tom']);
  assert.ok(!JSON.stringify(r.noms_cites).includes('masqué'), 'auteur anonyme jamais nommé');
  assert.equal(r.une.sujets[0].titre, 'Les Sovarkiens en terre de Sovarka');
});

test('noms cliquables dans un vrai Chromium : lien vers la fiche, « Écrire à », jamais d’auteur anonyme', async () => {
  const http = require('node:http'), os = require('node:os');
  const { chromium } = require('../e2e/node_modules/playwright');
  const { lancerChromium } = require('./fixtures/chromium-cdp.cjs');
  const PAGE = '<!doctype html><meta charset="utf-8"><body><div id="journal"></div><script>window.__ecrire=[];function ecrireAMembre(n){__ecrire.push(n);}'
    + 'function construireHtmlJournalDuJour(ed){return "<h2>Arnie agressé à Krasnov</h2><p>Arnie, ministre, a été neutralisé par un individu masqué. <a href=\\"#x\\">Arnie</a></p>";}</script>'
    + '<script src="/plateau-presse-noms.js"></script></body>';
  const serveur = http.createServer((req, res) => { if (req.url === '/') { res.setHeader('Content-Type', 'text/html; charset=utf-8'); return res.end(PAGE); }
    res.setHeader('Content-Type', 'text/javascript'); res.end(lire('plateau-presse-noms.js')); });
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'hg-presse-')); let nav, browser;
  try {
    await new Promise(r => serveur.listen(0, '127.0.0.1', r));
    nav = await lancerChromium({ executable: process.env.HG_CHROMIUM || ['/usr/bin/chromium', '/usr/bin/google-chrome', '/usr/bin/google-chrome-stable'].find(p => require('node:fs').existsSync(p)), profil });
    browser = await chromium.connectOverCDP('http://127.0.0.1:' + nav.port);
    const page = await browser.contexts()[0].newPage();
    await page.goto('http://127.0.0.1:' + serveur.address().port);
    await page.evaluate(() => { document.getElementById('journal').innerHTML = construireHtmlJournalDuJour({ noms_cites: ['Arnie'] }); });
    assert.equal(await page.locator('a.journal-nom').count(), 2, 'titre et texte ; le lien existant n’est pas retouché');
    assert.equal(await page.locator('a.journal-nom', { hasText: 'masqué' }).count(), 0);
    await page.locator('a.journal-nom').first().click();
    assert.match(await page.locator('#journal-fiche').innerText(), /Arnie/);
    await page.locator('#journal-fiche [data-ecrire]').click();
    assert.deepEqual(await page.evaluate(() => __ecrire), ['Arnie']);
  } finally {
    if (browser) await browser.close(); if (nav) await nav.arreter();
    serveur.closeAllConnections(); await new Promise(r => serveur.close(r)); fs.rmSync(profil, { recursive: true, force: true });
  }
});
