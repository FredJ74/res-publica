// Chromium réel : chantier « construction » (GAME-DESIGN-CHANTIERS-IMAGES-20261120.md). Vrais fichiers plateau-chantiers.js,
// plateau-construction-commandes.js et plateau-chantier-vue.js, vraies images du dépôt ; terrain et RPC simulés (aucune écriture).
// Le chantier simulé reprend les chiffres réels de celui d'Arnie (building, 24 jours, Luthécia).
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), os = require('node:os'), http = require('node:http');
const { chromium } = require('../e2e/node_modules/playwright');
const { lancerChromium } = require('./fixtures/chromium-cdp.cjs');
const racine = path.resolve(__dirname, '../..');
const FICHIERS = ['/plateau-chantiers.js', '/plateau-construction-commandes.js', '/plateau-chantier-vue.js'];

const PAGE = '<!doctype html><meta charset="utf-8"><body><div id="piece-image" style="width:800px;height:420px"></div>'
  + '<div id="modal-postes"><div id="postes-modal-title"></div><div id="postes-body"></div></div>'
  + '<script>var state={char:{name:"Arnie",pa:10},pa:10,liquide:50000,country:"republic",currentCity:"capitale",currentBuilding:"terrain-a-batir-3",currentRoom:"terrain",inventory:[{stackable:true,stackKey:"bois",qty:5}]};'
  + 'var COUNTRIES={republic:{cur:"FR"}};var NIVEAUX_CONSTRUCTION={building:{imageUrl:"images/building-construction-terrain.webp"},hangar:{imageUrl:"images/hangar-construction-terrain.webp"}};'
  + 'var __terrain={proprietaire:"Arnie",chantier:{type:"construction",niveau:"building",coutTotal:120000,dureeJours:24,progressionJours:1,totalVerse:42000,tresorerie:37005,coutTravail:84000,coutMateriaux:36000,heuresTotales:1200,heuresFaites:0,prixAchatPJ:{bois:6,minerai:11,metal:17},stockMateriaux:{bois:0,minerai:0,metal:0},maitreOuvrage:"Arnie",evenements:[]}};'
  + 'function getTerrainState(){return __terrain;} function estTitulaire(r){return r===state.char.name;} function contexteNavigationRue(){return {};} function contexteNavigationRueValide(){return true;}'
  + 'window.__lectures=0; async function chargerTerrainState(){window.__lectures++; return __terrain;} function enterRoom(){}'
  + 'window.__actions=[]; async function confirmerTravailChantier(){__actions.push(["travailler",document.getElementById("chantier-heures").value]);}'
  + 'async function confirmerVenteMateriauxChantier(m){__actions.push([m,document.getElementById("vente-matiere").value,document.getElementById("vente-quantite").value]);}'
  + '</script>' + FICHIERS.map(f => '<script src="' + f + '"></script>').join('') + '</body>';

async function avecPage(fn) {
  const serveur = http.createServer((req, res) => {
    const url = decodeURIComponent(req.url.split('?')[0]);
    if (url === '/') { res.setHeader('Content-Type', 'text/html; charset=utf-8'); res.end(PAGE); return; }
    if (!FICHIERS.includes(url) && !url.startsWith('/images/')) { res.writeHead(404); res.end(); return; }
    res.setHeader('Content-Type', url.endsWith('.js') ? 'text/javascript' : 'image/webp');
    // HG_SOURCE_URL=https://… : mêmes contrôles avec les fichiers et images réellement déployés.
    if (process.env.HG_SOURCE_URL) {
      fetch(process.env.HG_SOURCE_URL + encodeURI(url)).then(async r => { if (!r.ok) throw 0; res.end(Buffer.from(await r.arrayBuffer())); })
        .catch(() => { res.writeHead(404); res.end(); });
      return;
    }
    try { res.end(fs.readFileSync(path.join(racine, url.slice(1)))); } catch (_) { res.writeHead(404); res.end(); }
  });
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'hg-chantier-')); let nav, browser;
  try {
    await new Promise((r, j) => { serveur.once('error', j); serveur.listen(0, '127.0.0.1', r); });
    nav = await lancerChromium({ executable: process.env.HG_CHROMIUM || '/usr/bin/chromium', profil });
    browser = await chromium.connectOverCDP('http://127.0.0.1:' + nav.port);
    const page = await browser.contexts()[0].newPage(); await page.setViewportSize({ width: 1100, height: 900 });
    const erreurs = []; page.on('pageerror', e => erreurs.push(e.message));
    await page.goto('http://127.0.0.1:' + serveur.address().port);
    await page.waitForFunction(() => window.RPChantierVue);
    await fn(page);
    assert.deepEqual(erreurs, [], 'aucune erreur de page');
  } finally {
    if (browser) await browser.close(); if (nav) await nav.arreter();
    serveur.closeAllConnections(); await new Promise(r => serveur.close(r)); fs.rmSync(profil, { recursive: true, force: true });
  }
}
const fond = page => page.evaluate(() => document.getElementById('piece-image').style.background);

test('images par étape, ville et gabarit, avec repli (jamais d’image cassée)', () => avecPage(async page => {
  const cas = await page.evaluate(async () => {
    const R = window.RPChantierVue, ch = __terrain.chantier, r = {};
    const essai = async (prog, niveau) => { ch.progressionJours = prog; ch.niveau = niveau; return await R.imageResolue(__terrain); };
    r.demarrage = await essai(1, 'building');
    r.grosHaut = await essai(9, 'building');
    r.grosBas = await essai(9, 'hangar');           // gros-oeuvre-bas absent → démarrage
    r.facadeHaut = await essai(20, 'building');
    r.facadeBas = await essai(20, 'commerce_standard');
    const fini = { proprietaire: 'Arnie', niveau_construction: 'building' };
    r.finalBuilding = await R.imageResolue(fini);
    r.finalHangar = await R.imageResolue({ proprietaire: 'Arnie', niveau_construction: 'hangar' });   // absent → fiche actuelle
    ch.progressionJours = 1; ch.niveau = 'building';
    return r;
  });
  assert.equal(cas.demarrage, 'images/chantier-en-cours.webp');
  assert.equal(cas.grosHaut, 'images/chantiers/luthecia/gros-oeuvre-haut.webp');
  assert.equal(cas.grosBas, 'images/chantier-en-cours.webp');
  assert.equal(cas.facadeHaut, 'images/chantiers/luthecia/facade-haut.webp');
  assert.equal(cas.facadeBas, 'images/chantier-en-cours.webp');
  assert.equal(cas.finalBuilding, 'images/chantiers/luthecia/final-building.webp');
  assert.equal(cas.finalHangar, 'images/hangar-construction-terrain.webp');
  // La photo des fondations n'est pas branchée (document de design).
  assert.ok(!fs.readFileSync(path.join(racine, 'plateau-chantier-vue.js'), 'utf8').includes('fondations.webp'));
}));

test('surcouche d’avancement et rafraîchissement immédiat, sans recharger', () => avecPage(async page => {
  await page.evaluate(() => rafraichirVueChantier());
  let txt = await page.locator('#chantier-surcouche').innerText();
  assert.match(txt, /Jour 2 \/ 24 · 4 %/); assert.match(txt, /Étape : Démarrage/); assert.match(txt, /Prochaine étape : Gros œuvre/); assert.match(txt, /Fin prévue : /);
  assert.match(await fond(page), /chantier-en-cours\.webp/);
  // Le serveur fait avancer le chantier (autre joueur, nuit) : la relecture redessine tout.
  await page.evaluate(async () => { __terrain.chantier.progressionJours = 9; __terrain.chantier.arrete = 'penurie_materiaux'; await chargerTerrainState('terrain-a-batir-3'); });
  await page.waitForFunction(() => document.getElementById('piece-image').style.background.includes('gros-oeuvre-haut'));
  txt = await page.locator('#chantier-surcouche').innerText();
  assert.match(txt, /Étape : Gros œuvre/); assert.match(txt, /À l’arrêt : matériaux manquants/);
  // Suivi des autres joueurs : relecture périodique quand on regarde le terrain.
  assert.match(fs.readFileSync(path.join(racine, 'plateau-chantier-vue.js'), 'utf8'), /setInterval\(suivre, 20000\)/);
}));

test('fenêtre « Le chantier » : État et Participer pour tous, Gestion pour le maître d’ouvrage seul', () => avecPage(async page => {
  await page.evaluate(() => ouvrirFenetreChantier());
  const txt = (await page.locator('#chantier-fenetre').innerText()).replace(/[\u202f\u00a0]/g, ' ');
  for (const r of [/ÉTAT|État/, /Trésorerie : 37 005 FR/, /Fonds versés : 42 000 \/ 120 000 FR/, /Prochain appel de fonds : 42 000 FR avant le jour 9/,
    /Heures du jour : 0 faites/, /Salaire horaire/, /Prix de rachat des matériaux : bois 6, minerai 11, métal 17 FR/,
    /Si les joueurs terminent les heures du jour, le jour suivant s’ouvre en avance/, /Travailler sur le chantier/, /Vendre des matériaux au chantier/,
    /Donner des matériaux au chantier/, /Gestion|GESTION/, /Salaire horaire des ouvriers/, /Apporter des fonds/]) assert.match(txt, r);
  // Un autre joueur ne voit pas la gestion.
  await page.evaluate(() => { state.char.name = 'Tom Tom'; ouvrirFenetreChantier(); });
  const autre = await page.locator('#chantier-fenetre').innerText();
  assert.ok(!/Apporter des fonds|Salaire horaire des ouvriers/.test(autre), 'Gestion réservée au maître d’ouvrage');
  assert.match(autre, /Travailler sur le chantier/);
}));

test('Valider grisé avec explication tant qu’il manque quelque chose ; une seule opération validée', () => avecPage(async page => {
  await page.evaluate(() => ouvrirFenetreChantier());
  const valider = page.locator('#chantier-valider'), env = page.locator('#chantier-valider-enveloppe');
  assert.equal(await valider.isDisabled(), true); assert.equal(await env.getAttribute('title'), 'Choisissez d’abord une action.');
  // Vendre plus de bois qu'on n'en porte : grisé, raison claire ; quantité possible : actif, totaux en direct.
  await page.locator('input[value=vendre]').check();
  await page.fill('#chantier-v-qte', '9');
  assert.equal(await valider.isDisabled(), true); assert.equal(await env.getAttribute('title'), 'Vous n’avez pas assez de cette matière.');
  await page.fill('#chantier-v-qte', '3');
  assert.equal(await valider.isDisabled(), false);
  assert.match((await page.locator('#chantier-totaux').innerText()).replace(/[\u202f\u00a0]/g, ' '), /Vous recevez : 18 FR/);
  await valider.click();
  await page.waitForFunction(() => __actions.length === 1);
  assert.deepEqual(await page.evaluate(() => __actions[0]), ['vente', 'bois', '3']);
  // Travailler : sans matériaux sur le chantier, aucune heure utile → refus expliqué.
  await page.evaluate(() => ouvrirFenetreChantier());
  await page.locator('input[value=travailler]').check();
  assert.equal(await page.locator('#chantier-valider').isDisabled(), true);
  assert.match(await page.locator('#chantier-valider-enveloppe').getAttribute('title'), /Plus aucune heure de travail disponible/);
  // Salaire sous le minimum : refus expliqué.
  await page.locator('input[value=taux]').check(); await page.fill('#chantier-taux', '20');
  assert.match(await page.locator('#chantier-valider-enveloppe').getAttribute('title'), /au moins 50 FR/);
}));
