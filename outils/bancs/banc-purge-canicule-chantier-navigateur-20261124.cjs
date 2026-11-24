// Chromium réel : zone d'alerte climatique de la fenêtre du chantier pendant une canicule (mission « Purge », D.4, Fred,
// 24/11/2026). Vrais fichiers plateau-chantiers.js, plateau-construction-commandes.js, plateau-chantier-vue.js,
// plateau-climat.js et style.css ; réponses serveur simulées (chantier_fenetre_lire, chantier_climat_etat,
// chantier_canicule_offrir_eau), aucune écriture.
// À 390 px et 1280 px : image dédiée, bouton « Offrir 20 bouteilles d'eau aux ouvriers » (un contrôle, une action), rond « ? »
// à bulle au survol et au toucher, aucun débordement ; après le don, la zone dit qui a offert l'eau ; journal du chantier.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), os = require('node:os'), http = require('node:http');
const { chromium } = require('../e2e/node_modules/playwright');
const { lancerChromium } = require('./fixtures/chromium-cdp.cjs');
const racine = path.resolve(__dirname, '../..');
const FICHIERS = ['/plateau-chantiers.js', '/plateau-construction-commandes.js', '/plateau-chantier-vue.js', '/plateau-climat.js', '/style.css'];

const LECTURE = { ok: true, terrain: 'republic_terrain-a-batir-3', surPlace: true,
  travail: { capacite: 50, faitesJour: 0, restantesJour: 50, restantesAvance: 50, taux: 70, pa: 12, max: 12, raison: null },
  materiaux: { bois: { prix: 6, stock: 90, besoin: 100, manque: 10, possede: 0, payables: 6000, max: 0, maxDon: 0 },
    minerai: { prix: 11, stock: 50, besoin: 50, manque: 0, possede: 0, payables: 0, max: 0, maxDon: 0 },
    metal: { prix: 17, stock: 34, besoin: 34, manque: 0, possede: 0, payables: 0, max: 0, maxDon: 0 } }, accepteMateriaux: true };
const debut = new Date(Date.now() - 3600000).toISOString(), fin = new Date(Date.now() + 5 * 3600000).toISOString();
const ETAT = { ok: true, canicule: true, evenement: 7, fin_arret: fin, eau_offerte: null, leve_arret: true, requis: 20, possede: 25, present: true };

const PAGE = '<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><link rel="stylesheet" href="/style.css">'
  + '<body><div id="piece-image" style="width:100%;height:200px"></div>'
  + '<div id="modal-postes" class="modal-overlay"><div class="modal-box"><div class="modal-header"><div class="modal-title" id="postes-modal-title"></div></div><div id="postes-body"></div></div></div>'
  + '<script>var state={char:{name:"Bob",pa:12},pa:12,liquide:50000,country:"republic",currentCity:"capitale",currentBuilding:"terrain-a-batir-3",currentRoom:"terrain",inventory:[]};'
  + 'var COUNTRIES={republic:{cur:"FR"}};var NIVEAUX_CONSTRUCTION={building:{imageUrl:"images/building-construction-terrain.webp"}};'
  + 'var __terrain={proprietaire:"Arnie",chantier:{type:"construction",niveau:"building",coutTotal:120000,dureeJours:24,progressionJours:1,totalVerse:42000,tresorerie:37005,coutTravail:84000,coutMateriaux:36000,heuresTotales:1200,heuresFaites:0,prixAchatPJ:{bois:6,minerai:11,metal:17},stockMateriaux:{bois:90,minerai:50,metal:34},maitreOuvrage:"Arnie",evenements:[]}};'
  + 'window.__lecture=' + JSON.stringify(LECTURE) + ';window.__etat=' + JSON.stringify(ETAT) + ';window.__appels=[];window.__toasts=[];'
  + 'async function sbRpcVerdict(fn,p){ if(fn!=="chantier_fenetre_lire") return {ok:false,raison:"inattendu"}; return JSON.parse(JSON.stringify(window.__lecture)); }'
  + 'window.sbRpc=async function(fn,p){ __appels.push(fn); if(fn==="chantier_climat_etat") return JSON.parse(JSON.stringify(__etat));'
  + '  if(fn==="chantier_canicule_offrir_eau"){ __etat.eau_offerte={cle:"eau_offerte",par:"Bob",bouteilles:20}; __terrain.chantier.evenements.push({cle:"eau_offerte",date:"2026-11-24",par:"Bob",bouteilles:20}); return {ok:true,bouteilles:20,inventory:[]}; }'
  + '  if(fn==="climat_etat") return {ok:true,evenements:[]}; return {ok:false,raison:"inattendu"}; };'
  + 'window.showToast=function(t,m,ok){__toasts.push([t,m,ok]);};'
  + 'function getTerrainState(){return __terrain;} function estTitulaire(r){return r===state.char.name;} function contexteNavigationRue(){return {};} function contexteNavigationRueValide(){return true;}'
  + 'async function chargerTerrainState(){return __terrain;} function enterRoom(){}'
  + '</script>' + FICHIERS.filter(f => f.endsWith('.js')).map(f => '<script src="' + f + '"></script>').join('')
  + '<script>RPClimat._evenements([{type:"canicule",pays:"republic",ville:"capitale",debut:' + JSON.stringify(debut) + ',fin:' + JSON.stringify(fin) + '}]);</script></body>';

async function avecPage(largeur, fn) {
  const serveur = http.createServer((req, res) => {
    const url = decodeURIComponent(req.url.split('?')[0]);
    if (url === '/') { res.setHeader('Content-Type', 'text/html; charset=utf-8'); res.end(PAGE); return; }
    if (!FICHIERS.includes(url) && !url.startsWith('/images/')) { res.writeHead(404); res.end(); return; }
    res.setHeader('Content-Type', url.endsWith('.js') ? 'text/javascript' : url.endsWith('.css') ? 'text/css' : 'image/webp');
    try { res.end(fs.readFileSync(path.join(racine, url.slice(1)))); } catch (_) { res.writeHead(404); res.end(); }
  });
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'hg-purge-d4-')); let nav, browser;
  try {
    await new Promise((r, j) => { serveur.once('error', j); serveur.listen(0, '127.0.0.1', r); });
    nav = await lancerChromium({ executable: process.env.HG_CHROMIUM || ['/usr/bin/chromium', '/usr/bin/google-chrome', '/usr/bin/google-chrome-stable'].find(p => fs.existsSync(p)), profil });
    browser = await chromium.connectOverCDP('http://127.0.0.1:' + nav.port);
    const page = await browser.contexts()[0].newPage(); await page.setViewportSize({ width: largeur, height: 900 });
    const erreurs = []; page.on('pageerror', e => erreurs.push(e.message));
    await page.goto('http://127.0.0.1:' + serveur.address().port);
    await page.waitForFunction(() => window.RPChantierVue && window.RPClimat);
    await fn(page);
    assert.deepEqual(erreurs, [], 'aucune erreur de page');
  } finally {
    if (browser) await browser.close(); if (nav) await nav.arreter();
    serveur.closeAllConnections(); await new Promise(r => serveur.close(r)); fs.rmSync(profil, { recursive: true, force: true });
  }
}
const sansEsp = t => t.replace(/[  ]/g, ' ');

for (const largeur of [390, 1280]) {
  test(largeur + ' px — D.4 : canicule sur le chantier, image dédiée, « Offrir 20 bouteilles d’eau aux ouvriers » avec « ? », journal', () => avecPage(largeur, async page => {
    await page.evaluate(() => ouvrirFenetreChantier());
    await page.waitForSelector('#chantier-zone-climat:not([hidden]) #climat-offrir-eau');
    const zone = page.locator('#chantier-zone-climat');
    assert.match(sansEsp(await zone.innerText()), /Canicule : chantier à l’arrêt/);
    assert.match(sansEsp(await zone.innerText()), /Vous avez 25 bouteilles d’eau sur vous\./);
    assert.equal(await zone.locator('img[src="images/chantier-alea-canicule.webp"]').count(), 1, 'image dédiée');
    assert.equal((await page.locator('#climat-offrir-eau').innerText()).trim(), 'Offrir 20 bouteilles d’eau aux ouvriers');
    // Rond « ? » : bulle au survol, de deux phrases ; au toucher (clic) aussi.
    await page.locator('#climat-offrir-eau-aide').hover();
    const bulle = await page.locator('#climat-aide-bulle').innerText();
    assert.equal((bulle.match(/\./g) || []).length, 2, 'bulle de deux phrases');
    await page.mouse.move(0, 0);
    assert.equal(await page.locator('#climat-aide-bulle').isHidden(), true);
    await page.locator('#climat-offrir-eau-aide').click();
    assert.equal(await page.locator('#climat-aide-bulle').isVisible(), true);
    // Lisibilité : aucun débordement horizontal, texte ≥ texte courant dans la zone.
    const r = await page.evaluate(() => {
      const z = document.getElementById('chantier-zone-climat'), vw = document.documentElement.clientWidth, courant = 0.95 * parseFloat(getComputedStyle(document.documentElement).fontSize);
      return { debord: [...z.querySelectorAll('*')].filter(e => e.getBoundingClientRect().right > vw + 1).length, pageLarge: document.documentElement.scrollWidth > vw + 1,
        petits: [...z.querySelectorAll('*')].filter(e => [...e.childNodes].some(n => n.nodeType === 3 && n.textContent.trim()) && parseFloat(getComputedStyle(e).fontSize) < courant - 0.01).length };
    });
    assert.deepEqual(r, { debord: 0, pageLarge: false, petits: 0 });
    // Offrir : une seule action, le serveur tranche ; la zone dit qui a offert ; le journal du chantier en garde la trace.
    await page.locator('#climat-offrir-eau').click();
    await page.waitForFunction(() => __appels.includes('chantier_canicule_offrir_eau'));
    await page.evaluate(() => ouvrirFenetreChantier());
    await page.waitForFunction(() => /Bob a offert 20 bouteilles d’eau aux ouvriers : le travail reprend\./.test(document.getElementById('chantier-zone-climat').innerText));
    assert.equal(await page.locator('#climat-offrir-eau').count(), 0, 'plus de bouton après le don');
    assert.deepEqual(await page.evaluate(() => __toasts.at(-1)), ['Canicule : chantier à l’arrêt', 'Merci ! Les ouvriers ont reçu 20 bouteilles d’eau.', true]);
    await page.locator('[role=tab]', { hasText: /Avancement/i }).click();
    assert.match(sansEsp(await page.locator('.cj-journal').innerText()), /Bob a offert 20 bouteilles d’eau aux ouvriers pendant la canicule\./);
  }));
}

test('hors canicule : zone vide et cachée, aucune lecture serveur du climat du chantier', () => avecPage(390, async page => {
  await page.evaluate(() => { RPClimat._evenements([]); ouvrirFenetreChantier(); });
  await page.waitForSelector('#chantier-fenetre');
  await page.waitForTimeout(300);
  assert.equal(await page.locator('#chantier-zone-climat').isHidden(), true);
  assert.equal(await page.evaluate(() => __appels.filter(f => f === 'chantier_climat_etat').length), 0);
}));
