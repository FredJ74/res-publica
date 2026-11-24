// Chromium réel : chantier « construction » (GAME-DESIGN-CHANTIERS-IMAGES-20261120.md). Vrais fichiers plateau-chantiers.js,
// plateau-construction-commandes.js et plateau-chantier-vue.js, vraies images du dépôt ; terrain et RPC simulés (aucune écriture).
// Le chantier simulé reprend les chiffres réels de celui d'Arnie (building, 24 jours, Luthécia).
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), os = require('node:os'), http = require('node:http');
const { chromium } = require('../e2e/node_modules/playwright');
const { lancerChromium } = require('./fixtures/chromium-cdp.cjs');
const racine = path.resolve(__dirname, '../..');
const FICHIERS = ['/plateau-chantiers.js', '/plateau-construction-commandes.js', '/plateau-chantier-vue.js', '/style.css'];

const PAGE = '<!doctype html><meta charset="utf-8"><link rel="stylesheet" href="/style.css"><body><div id="piece-image" style="width:800px;height:420px"></div>'
  + '<div id="modal-postes"><div id="postes-modal-title"></div><div id="postes-body"></div></div>'
  + '<script>var state={char:{name:"Arnie",pa:10},pa:10,liquide:50000,country:"republic",currentCity:"capitale",currentBuilding:"terrain-a-batir-3",currentRoom:"terrain",inventory:[{stackable:true,stackKey:"bois",qty:5}]};'
  + 'var COUNTRIES={republic:{cur:"FR"}};var NIVEAUX_CONSTRUCTION={building:{imageUrl:"images/building-construction-terrain.webp"},hangar:{imageUrl:"images/hangar-construction-terrain.webp"}};'
  + 'var __terrain={proprietaire:"Arnie",chantier:{type:"construction",niveau:"building",coutTotal:120000,dureeJours:24,progressionJours:1,totalVerse:42000,tresorerie:37005,coutTravail:84000,coutMateriaux:36000,heuresTotales:1200,heuresFaites:0,prixAchatPJ:{bois:6,minerai:11,metal:17},stockMateriaux:{bois:0,minerai:0,metal:0},maitreOuvrage:"Arnie",evenements:[]}};'
  + 'function getTerrainState(){return __terrain;} function estTitulaire(r){return r===state.char.name;} function contexteNavigationRue(){return {};} function contexteNavigationRueValide(){return true;}'
  + 'window.__lectures=0; async function chargerTerrainState(){window.__lectures++; return __terrain;} function enterRoom(){}'
  + 'window.__actions=[]; async function confirmerTravailChantier(){__actions.push(["travailler",document.getElementById("chantier-heures").value]);}'
  + 'async function confirmerVenteMateriauxChantier(m){__actions.push([m,document.getElementById("vente-matiere").value,document.getElementById("vente-quantite").value]);}'
  + '</script>' + FICHIERS.filter(f => f.endsWith('.js')).map(f => '<script src="' + f + '"></script>').join('') + '</body>';

async function avecPage(fn) {
  const serveur = http.createServer((req, res) => {
    const url = decodeURIComponent(req.url.split('?')[0]);
    if (url === '/') { res.setHeader('Content-Type', 'text/html; charset=utf-8'); res.end(PAGE); return; }
    if (!FICHIERS.includes(url) && !url.startsWith('/images/')) { res.writeHead(404); res.end(); return; }
    res.setHeader('Content-Type', url.endsWith('.js') ? 'text/javascript' : url.endsWith('.css') ? 'text/css' : 'image/webp');
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
    nav = await lancerChromium({ executable: process.env.HG_CHROMIUM || ['/usr/bin/chromium', '/usr/bin/google-chrome', '/usr/bin/google-chrome-stable'].find(p => require('node:fs').existsSync(p)), profil });
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
    r.demarrage = await essai(0, 'building');
    r.fondations = await essai(1, 'building');
    r.grosHaut = await essai(9, 'building');
    r.grosBas = await essai(9, 'hangar');           // série de Luthécia complète depuis le 22/11 (soir)
    r.facadeHaut = await essai(20, 'building');
    r.facadeBas = await essai(20, 'commerce_standard');
    const fini = { proprietaire: 'Arnie', niveau_construction: 'building' };
    r.finalBuilding = await R.imageResolue(fini);
    r.finalHangar = await R.imageResolue({ proprietaire: 'Arnie', niveau_construction: 'hangar' });
    ch.progressionJours = 1; ch.niveau = 'building';
    return r;
  });
  assert.equal(cas.demarrage, 'images/chantier-en-cours.webp');
  assert.equal(cas.fondations, 'images/chantiers/luthecia/fondations.webp');
  assert.equal(cas.grosHaut, 'images/chantiers/luthecia/gros-oeuvre-haut.webp');
  assert.equal(cas.grosBas, 'images/chantiers/luthecia/gros-oeuvre-bas.webp');
  assert.equal(cas.facadeHaut, 'images/chantiers/luthecia/facade-haut.webp');
  assert.equal(cas.facadeBas, 'images/chantiers/luthecia/facade-bas.webp');
  assert.equal(cas.finalBuilding, 'images/chantiers/luthecia/final-building.webp');
  assert.equal(cas.finalHangar, 'images/chantiers/luthecia/final-hangar.webp');
  // Règle du 22/11/2026 (point 3) : fondations par ville après le premier jour (Luthécia : fondations.webp) ;
  // Port-Sainte-Marie a sa série complète, sans repli.
  const lu = await page.evaluate(() => window.RPChantierVue.candidatsImage({ chantier: { niveau: 'hangar', dureeJours: 6, progressionJours: 1 } }));
  assert.deepEqual(lu, ['images/chantiers/luthecia/fondations.webp', 'images/chantier-en-cours.webp']);
  const psm = await page.evaluate(() => { state.currentCity = 'ville_a'; const c = window.RPChantierVue.candidatsImage({ chantier: { niveau: 'hangar', dureeJours: 6, progressionJours: 1 } }); state.currentCity = 'capitale'; return c; });
  assert.deepEqual(psm, ['images/chantiers/psm/PSM_chantier_fondations.webp']);
}));

const sansEsp = t => t.replace(/[  ]/g, ' ');
test('aucun encadré sur l’image, jamais d’ouverture automatique ; rafraîchissement de la fenêtre ouverte, sans recharger', () => avecPage(async page => {
  await page.evaluate(() => rafraichirVueChantier());
  assert.equal(await page.locator('#chantier-surcouche').count(), 0, 'l’ancien encadré « État du chantier » ne chevauche plus le texte');
  assert.match(await fond(page), /luthecia\/fondations\.webp/);   // Arnie : jour 2 → fondations de Luthécia
  assert.equal(await page.evaluate(() => document.getElementById('modal-postes').classList.contains('open')), false);
  // Fenêtre ouverte puis fermée : entrer de nouveau sur le terrain ne la rouvre pas.
  await page.evaluate(() => { ouvrirFenetreChantier(); document.getElementById('modal-postes').classList.remove('open'); rafraichirVueChantier(); });
  assert.equal(await page.evaluate(() => document.getElementById('modal-postes').classList.contains('open')), false);
  // Ouverte : le serveur fait avancer le chantier, la fenêtre et l'image suivent.
  await page.evaluate(() => ouvrirFenetreChantier(false, 'avancement'));
  await page.evaluate(async () => { __terrain.chantier.progressionJours = 9; __terrain.chantier.arrete = 'penurie_materiaux'; await chargerTerrainState('terrain-a-batir-3'); });
  await page.waitForFunction(() => document.getElementById('piece-image').style.background.includes('gros-oeuvre-haut'));
  const txt = sansEsp(await page.locator('#chantier-fenetre').innerText());
  assert.match(txt, /Jour 10 \/ 24 · 37 %/); assert.match(txt, /À l’arrêt : matériaux manquants/);
  assert.match(fs.readFileSync(path.join(racine, 'plateau-chantier-vue.js'), 'utf8'), /setInterval\(suivre, 20000\)/);
}));

// Purge, bloc C (Fred, 24/11/2026) : les quatre onglets du 21/11 (État, Stock, Main-d’œuvre, Gestion) deviennent « Participer »
// (travail et vente, par défaut) et « Avancement » (l’ancien État) ; « Gérer mon chantier » est une vue à part. Contrôles
// détaillés de la nouvelle fenêtre : banc-purge-c-chantier-navigateur-20261124.cjs.
test('deux onglets « Participer » puis « Avancement » ; Avancement : jauges chantier (un carré par jour), jour (10 carrés), trois matériaux', () => avecPage(async page => {
  await page.evaluate(() => ouvrirFenetreChantier());
  const onglets = await page.locator('#chantier-fenetre [role=tab]').allInnerTexts();
  assert.deepEqual(onglets.map(x => x.trim().toLowerCase()), ['participer', 'avancement']);
  assert.equal((await page.locator('#chantier-fenetre [role=tab][aria-selected=true]').innerText()).trim().toLowerCase(), 'participer');
  await page.locator('[role=tab]', { hasText: /Avancement/i }).click();
  const jauges = page.locator('#chantier-fenetre .cj-jauge');
  assert.equal(await jauges.count(), 5);
  assert.equal(await jauges.nth(0).locator('.cj-case').count(), 24);
  assert.equal(await jauges.nth(0).locator('.cj-case.on').count(), 1);
  assert.equal(await jauges.nth(0).locator('.cj-case.sep').count(), 2);
  assert.match(await jauges.nth(0).innerText(), /Démarrage/i);
  const txt = sansEsp(await page.locator('#chantier-fenetre').innerText());
  assert.match(txt, /Jour 2 \/ 24 · 4 %/); assert.match(txt, /Étape suivante : Gros œuvre/); assert.match(txt, /Fin prévue : /);
  assert.equal(await jauges.nth(1).locator('.cj-case').count(), 10); assert.match(txt, /0 \/ 50 h/);
  assert.match(txt, /L’entrepôt de Luthécia n’a pas pu tout fournir : il manque 100 bois, 50 minerai et 33 métal pour aujourd’hui/);
  // Teinte des carrés par variable CSS (plus de couleur en dur dans le JS) : rouge = --h:0.
  assert.equal(await page.evaluate(() => /--h:0;/.test(window.RPChantierVue.jauge('', 10, 3, '', { rouge: true }))), true, 'petite jauge rouge');
  const taille = await page.evaluate(() => parseFloat(getComputedStyle(document.getElementById('chantier-fenetre')).fontSize));
  assert.ok(taille >= 16, 'police ' + taille);
  // Un autre joueur : pas de « Gérer mon chantier ».
  await page.evaluate(() => { state.char.name = 'Tom Tom'; ouvrirFenetreChantier(); });
  assert.equal(await page.locator('.cj-bouton-gerer').count(), 0);
}));

test('sans lecture du serveur, aucune action proposée ; « Gérer mon chantier » : tableau de bord et réglages dans la même fenêtre', () => avecPage(async page => {
  await page.evaluate(() => ouvrirFenetreChantier());
  assert.match(await page.locator('.cj-resume-heures').innerText(), /Lecture du chantier/);
  assert.equal(await page.locator('#cj-main-valider').count(), 0, 'le plafond vient du serveur, jamais de l’écran');
  assert.equal(await page.locator('#chantier-fenetre table').count(), 0);
  await page.locator('.cj-bouton-gerer').click();
  const g = sansEsp(await page.locator('#chantier-fenetre').innerText());
  for (const r of [/Trésorerie\s*37 005 FR/, /Fonds versés \/ coût total\s*42 000 \/ 120 000 FR/, /Prochain appel de fonds\s*42 000 FR avant le jour 9/,
    /Prix de rachat du bois/, /Salaire horaire des ouvriers/, /Verser des fonds/, /Commande de matériaux/,
    /Commande automatique chaque nuit à l’entrepôt de Luthécia/, /Aucune commande pour l’instant/]) assert.match(g, r);
  assert.equal(await page.locator('#chantier-fenetre button', { hasText: /Commander/i }).count(), 0, 'pas de commande manuelle');
  await page.evaluate(() => { __terrain.chantier.derniereCommande = { motif: 'nuit', date: '2026-11-23', pourJour: 4, livre: { bois: 100, minerai: 50 }, manque: { metal: 33 }, cout: 1300 }; ouvrirFenetreChantier(false, 'gestion'); });
  assert.match(sansEsp(await page.locator('#cj-derniere-commande').innerText()), /Dernière commande \(2026-11-23, pour le jour 4\) : livré 100 bois et 50 minerai ; manquant 33 métal ; coût 1 300 FR\./);
  assert.equal(await page.locator('#modal-postes #chantier-fenetre').count(), 1);
}));
