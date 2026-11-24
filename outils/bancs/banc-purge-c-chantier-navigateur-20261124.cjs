// Chromium réel : fenêtre du chantier simplifiée (mission « Purge », bloc C, Fred, 24/11/2026). Vrais fichiers
// plateau-chantiers.js, plateau-construction-commandes.js, plateau-chantier-vue.js et style.css ; terrain simulé et
// lecture serveur simulée (réponse de chantier_fenetre_lire), aucune écriture.
// À 390 px et 1280 px : aucune table à colonnes, un contrôle par action, aucun débordement horizontal, texte ≥ texte courant.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), os = require('node:os'), http = require('node:http');
const { chromium } = require('../e2e/node_modules/playwright');
const { lancerChromium } = require('./fixtures/chromium-cdp.cjs');
const racine = path.resolve(__dirname, '../..');
const FICHIERS = ['/plateau-chantiers.js', '/plateau-construction-commandes.js', '/plateau-chantier-vue.js', '/style.css'];

const LECTURE = { ok: true, terrain: 'republic_terrain-a-batir-3', surPlace: true,
  travail: { capacite: 50, faitesJour: 0, restantesJour: 50, restantesAvance: 50, taux: 70, pa: 12, max: 12, raison: null },
  materiaux: { bois: { prix: 6, stock: 90, besoin: 100, manque: 10, possede: 5, payables: 6000, max: 5, maxDon: 5 },
    minerai: { prix: 11, stock: 0, besoin: 50, manque: 50, possede: 40, payables: 3, max: 3, maxDon: 40 },
    metal: { prix: 17, stock: 34, besoin: 34, manque: 0, possede: 9, payables: 2000, max: 0, maxDon: 0 } }, accepteMateriaux: true };

const PAGE = '<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><link rel="stylesheet" href="/style.css">'
  + '<body><div id="piece-image" style="width:100%;height:200px"></div>'
  + '<div id="modal-postes" class="modal-overlay"><div class="modal-box"><div class="modal-header"><div class="modal-title" id="postes-modal-title"></div></div><div id="postes-body"></div></div></div>'
  + '<script>var state={char:{name:"Arnie",pa:12},pa:12,liquide:50000,country:"republic",currentCity:"capitale",currentBuilding:"terrain-a-batir-3",currentRoom:"terrain",inventory:[{stackable:true,stackKey:"bois",qty:5}]};'
  + 'var COUNTRIES={republic:{cur:"FR"}};var NIVEAUX_CONSTRUCTION={building:{imageUrl:"images/building-construction-terrain.webp"}};'
  + 'var __terrain={proprietaire:"Arnie",chantier:{type:"construction",niveau:"building",coutTotal:120000,dureeJours:24,progressionJours:1,totalVerse:42000,tresorerie:37005,coutTravail:84000,coutMateriaux:36000,heuresTotales:1200,heuresFaites:0,prixAchatPJ:{bois:6,minerai:11,metal:17},stockMateriaux:{bois:90,minerai:0,metal:34},maitreOuvrage:"Arnie",evenements:[]}};'
  + 'window.__lecture=' + JSON.stringify(LECTURE) + ';window.__lectures=0;'
  + 'async function sbRpcVerdict(fn,p){ if(fn!=="chantier_fenetre_lire") return {ok:false,raison:"inattendu"}; window.__lectures++; return JSON.parse(JSON.stringify(window.__lecture)); }'
  + 'function getTerrainState(){return __terrain;} function estTitulaire(r){return r===state.char.name;} function contexteNavigationRue(){return {};} function contexteNavigationRueValide(){return true;}'
  + 'async function chargerTerrainState(){return __terrain;} function enterRoom(){}'
  + 'window.__actions=[]; async function confirmerTravailChantier(){__actions.push(["travailler",document.getElementById("chantier-heures").value]);}'
  + 'async function confirmerVenteMateriauxChantier(m){__actions.push([m,document.getElementById("vente-matiere").value,document.getElementById("vente-quantite").value]);}'
  + 'window.__climat=[]; window.chantierZoneClimat=function(zone,ctx){__climat.push([zone.id,ctx.terrain]);};'
  + '</script>' + FICHIERS.filter(f => f.endsWith('.js')).map(f => '<script src="' + f + '"></script>').join('')
  + '<script>window.constructionExecuterCommande=async function(a,p){__actions.push([a,p]);return {ok:true};};</script></body>';

async function avecPage(largeur, fn) {
  const serveur = http.createServer((req, res) => {
    const url = decodeURIComponent(req.url.split('?')[0]);
    if (url === '/') { res.setHeader('Content-Type', 'text/html; charset=utf-8'); res.end(PAGE); return; }
    if (!FICHIERS.includes(url) && !url.startsWith('/images/')) { res.writeHead(404); res.end(); return; }
    res.setHeader('Content-Type', url.endsWith('.js') ? 'text/javascript' : url.endsWith('.css') ? 'text/css' : 'image/webp');
    try { res.end(fs.readFileSync(path.join(racine, url.slice(1)))); } catch (_) { res.writeHead(404); res.end(); }
  });
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'hg-purge-c-')); let nav, browser;
  try {
    await new Promise((r, j) => { serveur.once('error', j); serveur.listen(0, '127.0.0.1', r); });
    nav = await lancerChromium({ executable: process.env.HG_CHROMIUM || ['/usr/bin/chromium', '/usr/bin/google-chrome', '/usr/bin/google-chrome-stable'].find(p => fs.existsSync(p)), profil });
    browser = await chromium.connectOverCDP('http://127.0.0.1:' + nav.port);
    const page = await browser.contexts()[0].newPage(); await page.setViewportSize({ width: largeur, height: 900 });
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
const sansEsp = t => t.replace(/[  ]/g, ' ');
async function ouvrir(page) {
  await page.evaluate(() => ouvrirFenetreChantier());
  await page.waitForFunction(() => /Encore|Plus aucune|heures du jour sont faites/.test(document.querySelector('.cj-resume-heures')?.innerText || ''));
}
// Contrôles communs de lisibilité : aucune table, aucun débordement, onglets entiers, texte ≥ texte courant (0,95 rem).
async function lisible(page, quoi) {
  const r = await page.evaluate(() => {
    const f = document.getElementById('chantier-fenetre'), vw = document.documentElement.clientWidth, courant = 0.95 * parseFloat(getComputedStyle(document.documentElement).fontSize);
    const debord = [...f.querySelectorAll('*')].filter(e => e.getClientRects().length && e.getBoundingClientRect().right > vw + 1).map(e => e.className || e.tagName);
    const petits = [...f.querySelectorAll('*')].filter(e => e.getClientRects().length && [...e.childNodes].some(n => n.nodeType === 3 && n.textContent.trim())
      && parseFloat(getComputedStyle(e).fontSize) < courant - 0.01).map(e => (e.className || e.tagName) + ' ' + getComputedStyle(e).fontSize);
    const coupes = [...f.querySelectorAll('[role=tab]')].filter(b => b.scrollWidth > b.clientWidth + 1 || b.scrollHeight > b.clientHeight + 1).map(b => b.innerText);
    return { tables: f.querySelectorAll('table, th, td, thead, tbody').length, debord, petits, coupes, cases: f.querySelectorAll('input[type=checkbox], input[type=radio]').length,
      pageLarge: document.documentElement.scrollWidth > vw + 1,
      multiAction: [...f.querySelectorAll('button')].filter(b => ((b.getAttribute('onclick') || '').match(/\(/g) || []).length > 1 && !/^chantier\w+\(/.test(b.getAttribute('onclick') || '')).length };
  });
  assert.equal(r.tables, 0, quoi + ' : aucune table à colonnes');
  assert.deepEqual(r.debord, [], quoi + ' : aucun débordement horizontal');
  assert.equal(r.pageLarge, false, quoi + ' : pas de défilement horizontal de la page');
  assert.deepEqual(r.petits, [], quoi + ' : texte ≥ texte courant');
  assert.deepEqual(r.coupes, [], quoi + ' : onglets non coupés');
  assert.equal(r.cases, 0, quoi + ' : aucune case à cocher (un contrôle par action)');
  assert.equal(r.multiAction, 0, quoi + ' : un bouton = une action');
}

for (const largeur of [390, 1280]) {
  test(largeur + ' px — C.1 à C.5 : résumé, travail, vente, gestion lisibles, sans table ni débordement', () => avecPage(largeur, async page => {
    await ouvrir(page);
    // C.1 : résumé permanent, « ? » à bulle de deux phrases, matériaux du jour ; emplacement du climat sous le résumé.
    const resume = sansEsp(await page.locator('.cj-resume-haut').innerText());
    assert.match(resume, /Encore 50 heure\(s\) à faire aujourd’hui/);
    assert.match(resume, /Bois : 90 sur 100/); assert.match(resume, /Minerai : 0 sur 50/); assert.match(resume, /Métal : 34 sur 34/);
    assert.equal(await page.locator('.cj-pastille.cj-manque').count(), 2);
    await page.locator('.cj-resume-heures .cj-aide').hover();
    const bulle = await page.locator('#cj-aide-bulle').innerText();
    assert.equal((bulle.match(/\./g) || []).length, 2, 'bulle de deux phrases');
    assert.equal(await page.evaluate(() => { const z = document.getElementById('chantier-zone-climat'), r = document.querySelector('.cj-resume-haut'), o = document.querySelector('.cj-onglets');
      return !!z && z.hidden && r.compareDocumentPosition(z) === Node.DOCUMENT_POSITION_FOLLOWING && z.compareDocumentPosition(o) === Node.DOCUMENT_POSITION_FOLLOWING; }), true);
    assert.deepEqual(await page.evaluate(() => __climat[0]), ['chantier-zone-climat', 'terrain-a-batir-3']);
    // Onglets : « Participer » (par défaut) et « Avancement ».
    assert.deepEqual((await page.locator('[role=tab]').allInnerTexts()).map(x => x.trim().toLowerCase()), ['participer', 'avancement']);
    await lisible(page, largeur + ' px, Participer');

    // C.2 : heures − / +, plafond du serveur (12 h : les PA), gain avant validation au salaire du serveur.
    const travail = page.locator('.cj-travail');
    assert.match(sansEsp(await travail.innerText()), /Salaire : 70 FR de l’heure · 1 PA par heure/);
    assert.equal((await page.locator('#cj-v-h').innerText()).trim(), '12 h');
    assert.equal(await travail.locator('button[aria-label="Une heure de plus"]').isDisabled(), true, 'plafonné');
    assert.match(sansEsp(await page.locator('#cj-main-resume').innerText()), /Vous recevrez 840 FR et utiliserez 12 PA\./);
    await travail.locator('button[aria-label="Une heure de moins"]').click();
    assert.match(sansEsp(await page.locator('#cj-main-resume').innerText()), /Vous recevrez 770 FR et utiliserez 11 PA\./);
    assert.equal((await page.locator('#cj-main-valider').innerText()).trim(), 'Travailler 11 h');
    await page.locator('#cj-main-valider').click();
    await page.waitForFunction(() => __actions.length === 1);
    assert.deepEqual(await page.evaluate(() => __actions[0]), ['travailler', '11']);

    // C.3 : une carte par matériau, « Vendre » et « Donner » séparés ; plafonds du serveur.
    await ouvrir(page);
    const bois = page.locator('.cj-mat[data-m=bois]');
    assert.match(sansEsp(await bois.innerText()), /Le chantier en rachète encore 10 aujourd’hui\. Vous en avez 5\./);
    assert.equal((await page.locator('#cj-vendre-bois').innerText()).trim().replace(/[  ]/g, ' '), 'Vendre 5 bois · 30 FR');
    await page.locator('#cj-vendre-bois').click();
    await page.waitForFunction(() => __actions.length === 2);
    assert.deepEqual(await page.evaluate(() => __actions[1]), ['vente', 'bois', '5']);
    await ouvrir(page);
    // Minerai : la trésorerie ne paie que 3 unités ; au-delà, seul le don reste proposé.
    assert.equal((await page.locator('#cj-vendre-minerai').innerText()).trim().replace(/[  ]/g, ' '), 'Vendre 3 minerai · 33 FR');
    await page.locator('.cj-mat[data-m=minerai] button[aria-label="Une unité de plus"]').click();
    assert.equal(await page.locator('#cj-vendre-minerai').count(), 0);
    assert.match(await page.locator('.cj-mat[data-m=minerai]').innerText(), /ne peut vous en payer que 3/);
    await page.locator('#cj-donner-minerai').click();
    await page.waitForFunction(() => __actions.length === 3);
    assert.deepEqual(await page.evaluate(() => __actions[2]), ['don', 'minerai', '4']);
    await ouvrir(page);
    assert.match(await page.locator('.cj-mat[data-m=metal]').innerText(), /Le besoin du jour en métal est couvert\./);
    assert.equal(await page.locator('.cj-mat[data-m=metal] button').count(), 0);

    // Avancement : jauges, sans couleur en dur dans le JS.
    await page.locator('[role=tab]', { hasText: /Avancement/i }).click();
    assert.equal(await page.locator('#chantier-fenetre .cj-jauge').count() >= 2, true);
    await lisible(page, largeur + ' px, Avancement');

    // C.4 : « Gérer mon chantier » dans une vue à part, une ligne par réglage, chacune avec un seul bouton.
    await page.locator('[role=tab]', { hasText: /Participer/i }).click();
    await page.locator('.cj-bouton-gerer').click();
    assert.equal(await page.locator('#postes-modal-title').innerText(), 'Gérer mon chantier');
    const lignes = page.locator('#chantier-fenetre .cj-reglage:not(.cj-info)');
    assert.equal(await lignes.count(), 5, 'bois, minerai, métal, salaire, fonds');
    for (let i = 0; i < 5; i++) assert.equal(await lignes.nth(i).locator('button:not(.cj-aide)').count(), 1);
    await page.fill('#chantier-prix-minerai', '14');
    await lignes.nth(1).locator('button:not(.cj-aide)').click();
    await page.waitForFunction(() => __actions.length === 4);
    assert.deepEqual(await page.evaluate(() => __actions[3]), ['prix', { prix: { minerai: '14' } }]);
    assert.equal(await page.locator('#chantier-fenetre .cj-onglets').count(), 0);
    await lisible(page, largeur + ' px, Gérer mon chantier');
    await page.locator('.cj-retour').click();
    assert.equal(await page.locator('#postes-modal-title').innerText(), 'Le chantier');
    // Un autre joueur ne voit pas « Gérer mon chantier ».
    await page.evaluate(() => { state.char.name = 'Tom Tom'; ouvrirFenetreChantier(); });
    assert.equal(await page.locator('.cj-bouton-gerer').count(), 0);
    if (process.env.HG_CAPTURE) { await page.evaluate(() => { state.char.name = 'Arnie'; ouvrirFenetreChantier(); }); await page.waitForTimeout(500);
      await page.locator('#modal-postes .modal-box').screenshot({ path: process.env.HG_CAPTURE.replace(/(\.png)?$/, '-' + largeur + '.png') }); }
  }));
}

test('refus du serveur nommé : intempéries, aucune heure, lecture impossible', () => avecPage(390, async page => {
  await page.evaluate(() => { __lecture.travail = Object.assign(__lecture.travail, { max: 0, raison: 'chantier_intemperies' }); });
  await ouvrir(page);
  assert.match(await page.locator('.cj-travail').innerText(), /Le chantier est arrêté par les intempéries\./);
  assert.equal(await page.locator('#cj-main-valider').count(), 0);
  await page.evaluate(() => { __lecture.travail = Object.assign(__lecture.travail, { restantesJour: 0, restantesAvance: 0, raison: 'aucune_heure_ouverte' }); ouvrirFenetreChantier(); });
  await page.waitForFunction(() => /Plus aucune heure/.test(document.querySelector('.cj-resume-heures').innerText));
  await page.evaluate(() => { window.__lecture = { ok: false, raison: 'transport' }; ouvrirFenetreChantier(); });
  await page.waitForFunction(() => /ne répond pas/.test(document.querySelector('.cj-resume-heures').innerText));
  assert.equal(await page.locator('#chantier-fenetre button.cpj-primaire').count(), 0, 'aucune action sans lecture du serveur');
}));

test('sources : aucune couleur en dur ni table dans la fenêtre, plus de style injecté', () => {
  const js = fs.readFileSync(path.join(racine, 'plateau-chantier-vue.js'), 'utf8');
  const fenetre = js.slice(js.indexOf('// ── Fenêtre « Le chantier »'), js.indexOf('function demarrer()'));
  assert.doesNotMatch(fenetre, /#[0-9a-fA-F]{3,6}\b|rgba?\(|hsl\(/, 'couleurs dans style.css');
  assert.doesNotMatch(fenetre, /<table|<td|<th/);
  assert.doesNotMatch(fenetre, /st\.textContent\s*=/);
  assert.match(fs.readFileSync(path.join(racine, 'style.css'), 'utf8'), /CHANTIER — fenêtre simplifiée/);
});
