// Chromium réel : étape J, terrains à bâtir (GAME-DESIGN-CHANTIERS-IMAGES-20261120.md, complément du 21/11, points 1 et 2).
// Vrais fichiers data.js, plateau-rue-centrale.js, plateau-chantier-vue.js, plateau-terrains-plan.js, style.css,
// rue-centrale.css et vraies images du dépôt ; seules la lecture de terrains_etat et l'entrée dans un lot sont simulées.
// Plan en vignettes : bonne image et bonne étiquette pour un lot à vendre, acheté, en chantier, achevé ; clic qui mène au lot ;
// mise à jour sans recharger ; flèche de retour jamais couverte. Rue en trois états à Luthécia et Montrouge, repli si l'image manque.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), os = require('node:os'), http = require('node:http');
const { chromium } = require('../e2e/node_modules/playwright');
const { lancerChromium } = require('./fixtures/chromium-cdp.cjs');
const racine = path.resolve(__dirname, '../..');
const lire = f => fs.readFileSync(path.join(racine, f), 'utf8');

// Sources uniques reprises telles quelles (listes et surfaces des lots, contexte de ville, catégorie des logements).
function bloc(src, debut) {
  const i = src.indexOf(debut); assert.ok(i >= 0, debut);
  let n = 0; const depart = debut.startsWith('function') ? src.indexOf(')', i) : src.indexOf('=', i);
  const ouvrant = depart + src.slice(depart).search(/[[{]/);
  const o = src[ouvrant], f = o === '[' ? ']' : '}';
  for (let k = ouvrant; k < src.length; k++) { if (src[k] === o) n++; else if (src[k] === f && --n === 0) return src.slice(i, k + 1) + ';'; }
}
const je = lire('plateau-justice-economie.js'), pnj = lire('plateau-pnj.js'), nav = lire('plateau-navigation.js');
const SOURCES = [bloc(je, 'const TERRAINS_LUTHECIA ='), bloc(je, 'const TERRAINS_PAR_VILLE ='), bloc(pnj, 'const SURFACE_TERRAINS ='),
  bloc(je, 'function logementsSociauxPour('), bloc(nav, 'function getBuildingContext(')].join('\n');

const FICHIERS = ['/data.js', '/plateau-rue-centrale.js', '/plateau-chantier-vue.js', '/plateau-terrains-plan.js', '/style.css', '/rue-centrale.css'];
const PAGE = '<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
  + '<link rel="stylesheet" href="/style.css"><link rel="stylesheet" href="/rue-centrale.css"><body>'
  + '<div id="vue-rue" class="active"><div id="rue-centrale-conteneur"></div></div>'
  + '<div id="vue-batiment"><div id="bat-nom"></div><div id="bat-cat"></div><div id="bat-caisse"></div><div id="bat-stock"></div><div id="bat-directeur"></div>'
  + '<div id="pieces-tabs"></div><div class="piece-container"><div class="piece-image" id="piece-image"><div class="piece-ambiance"><div class="piece-nom" id="piece-nom"></div><div class="piece-desc" id="piece-desc"></div></div></div></div>'
  + '<div id="action-context-bat"></div><div id="actions-row-bat"></div><div id="loc-name"></div><div id="loc-sub"></div></div>'
  + '<script>var state={char:{name:"Temoin"},country:"republic",currentCity:"capitale",terrainsState:{}};async function sbRpc(){return {ok:true};}'
  + 'var NIVEAUX_CONSTRUCTION={hangar:{imageUrl:"images/hangar-construction-terrain.webp"},building:{imageUrl:"images/building-construction-terrain.webp"},logement:{imageUrl:"images/commerce-premium-construction-terrain.webp"}};'
  + 'window.__lignes=[];window.__lectures=0;async function sbGetTerrainsLibres(){window.__lectures++;return JSON.parse(JSON.stringify(window.__lignes));}'
  + 'window.__entrees=[];function enterBuilding(id){window.__entrees.push(id);}function renderPersonsList(){}'
  + '</script><script>' + SOURCES + '</script>' + FICHIERS.filter(f => f.endsWith('.js')).map(f => '<script src="' + f + '"></script>').join('') + '</body>';

async function avecPage(largeur, fn) {
  const serveur = http.createServer((req, res) => {
    const url = decodeURIComponent(req.url.split('?')[0]);
    if (url === '/') { res.setHeader('Content-Type', 'text/html; charset=utf-8'); res.end(PAGE); return; }
    if (!FICHIERS.includes(url) && !url.startsWith('/images/')) { res.writeHead(404); res.end(); return; }
    const type = url.endsWith('.js') ? 'text/javascript' : url.endsWith('.css') ? 'text/css' : url.endsWith('.jpg') ? 'image/jpeg' : url.endsWith('.png') ? 'image/png' : 'image/webp';
    try { const b = fs.readFileSync(path.join(racine, url.slice(1))); res.setHeader('Content-Type', type); res.end(b); } catch (_) { res.writeHead(404); res.end(); }
  });
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'hg-terrains-plan-')); let nav, browser;
  try {
    await new Promise((r, j) => { serveur.once('error', j); serveur.listen(0, '127.0.0.1', r); });
    nav = await lancerChromium({ executable: process.env.HG_CHROMIUM || ['/usr/bin/chromium', '/usr/bin/google-chrome', '/usr/bin/google-chrome-stable'].find(p => fs.existsSync(p)), profil });
    browser = await chromium.connectOverCDP('http://127.0.0.1:' + nav.port);
    const page = await browser.contexts()[0].newPage(); await page.setViewportSize({ width: largeur, height: 900 });
    const erreurs = []; page.on('pageerror', e => erreurs.push(e.message));
    await page.goto('http://127.0.0.1:' + serveur.address().port);
    await page.waitForFunction(() => window.RPTerrainsPlan && window.RPChantierVue && typeof afficherNoeudRue === 'function');
    await fn(page);
    assert.deepEqual(erreurs, [], 'aucune erreur de page');
  } finally {
    if (browser) await browser.close(); if (nav) await nav.arreter();
    serveur.closeAllConnections(); await new Promise(r => serveur.close(r)); fs.rmSync(profil, { recursive: true, force: true });
  }
}

const ligne = (id, data, niveau) => ({ id: 'republic_' + id, country: 'republic', building_id: id, proprietaire: data.proprietaire || null, niveau_construction: niveau || null, data: JSON.stringify(data) });
const chantier = (niveau, prog, duree) => ({ type: 'construction', niveau, progressionJours: prog, dureeJours: duree, maitreOuvrage: 'Arnie' });
const sansEsp = s => String(s).replace(/[  ]/g, ' ');
// Cartes affichées : étiquette, état, image et jauge, une fois toutes les images posées.
async function cartes(page) {
  await page.waitForFunction(() => [...document.querySelectorAll('.tplan-carte img')].every(i => i.complete && i.naturalWidth > 0));
  return (await page.evaluate(() => [...document.querySelectorAll('.tplan-carte')].map(b => ({
    lot: b.dataset.lot, etat: b.dataset.etat, etiquette: b.querySelector('.tplan-etiquette').textContent,
    image: b.querySelector('img').getAttribute('src'), jauge: b.querySelector('.tplan-jauge').hidden ? null : b.querySelector('.tplan-jauge span').style.width
  })))).map(c => ({ ...c, etiquette: sansEsp(c.etiquette) }));
}
const LUTHECIA = () => [
  ligne('terrain-a-batir-1', { surface: 2150, pnj: 'squatter_cool' }),
  // terrain-a-batir-2 : aucune ligne → à vendre
  ligne('terrain-a-batir-3', { surface: 2300, proprietaire: 'Arnie', chantier: chantier('building', 11.3, 24) }),
  ligne('terrain-a-batir-4', { surface: 1850, proprietaire: 'Arnie', niveau_construction: 'building' }, 'building'),
  ligne('terrain-a-batir-5', { surface: 2750, proprietaire: 'Jean Jaaj' })
];

for (const largeur of [1280, 390]) test(`Luthécia ${largeur}px : plan en vignettes, étiquettes serveur, images actuelles, flèche libre, clic vers le lot`, () => avecPage(largeur, async page => {
  await page.evaluate(async l => { window.__lignes = l; await afficherNoeudRue('republic', 'luthecia-terrains-lots', 'luthecia-terrains-artisanal', true); }, LUTHECIA());
  await page.waitForFunction(() => document.querySelectorAll('.tplan-carte[data-etat]:not([data-etat="inconnu"])').length === 5);
  const c = await cartes(page);
  assert.deepEqual(c.map(x => x.etiquette), ['Lot 1 — 2 150 m² — À vendre', 'Lot 2 — 2 300 m² — À vendre', 'Lot 3 — Chantier 47 %', 'Lot 4 — Building d’Arnie', 'Lot 5 — 2 750 m² — Terrain de Jean Jaaj']);
  assert.deepEqual(c.map(x => x.etat), ['a_vendre', 'a_vendre', 'chantier', 'acheve', 'achete']);
  assert.equal(c[0].image, 'images/terrain-a-vendre-republic.webp');
  assert.equal(c[2].image, 'images/chantiers/luthecia/gros-oeuvre-haut.webp');
  assert.equal(c[2].jauge, '47%');
  assert.equal(c[3].image, 'images/chantiers/luthecia/final-building.webp');
  assert.equal(c[4].image, 'images/terrain-a-vendre-republic.webp');
  // La flèche de retour reste visible, cliquable et ne touche aucune carte ni l'en-tête.
  const geo = await page.evaluate(() => {
    const f = document.querySelector('.rc-fleche').getBoundingClientRect(), s = document.getElementById('rc-scene').getBoundingClientRect();
    const touche = [...document.querySelectorAll('.tplan-carte,.tplan-tete')].some(e => { const r = e.getBoundingClientRect(); return !(r.right <= f.left || r.left >= f.right || r.bottom <= f.top || r.top >= f.bottom); });
    const dessus = document.elementFromPoint(f.left + f.width / 2, f.top + f.height / 2).closest('.rc-fleche') !== null;
    const debord = [...document.querySelectorAll('.tplan-carte')].some(e => { const r = e.getBoundingClientRect(); return r.left < s.left - 1 || r.right > s.right + 1 || r.bottom > s.bottom; });
    return { touche, dessus, bas: Math.round(s.bottom - f.bottom), debord };
  });
  assert.equal(geo.touche, false, 'aucune carte sur la flèche');
  assert.equal(geo.dessus, true, 'flèche au premier plan');
  assert.equal(geo.debord, false, 'cartes dans la scène');
  if (process.env.HG_CAPTURE) await page.waitForTimeout(1200), await page.locator('#rc-scene').screenshot({ path: process.env.HG_CAPTURE.replace(/\.png$/, '') + '-luthecia-' + largeur + '.png' });
  // Mise à jour sans recharger : le lot 1 est acheté, le chantier passe en façade.
  await page.evaluate(async () => {
    window.__lignes[0] = { ...window.__lignes[0], proprietaire: 'Tom Tom', data: JSON.stringify({ surface: 2150, proprietaire: 'Tom Tom' }) };
    const d = JSON.parse(window.__lignes[1].data); d.chantier.progressionJours = 20; window.__lignes[1].data = JSON.stringify(d);
    await window.RPTerrainsPlan.relire();
  });
  await page.waitForFunction(() => document.querySelector('[data-lot="terrain-a-batir-3"] img').getAttribute('src').includes('facade-haut'));
  const c2 = await cartes(page);
  assert.equal(c2[0].etiquette, 'Lot 1 — 2 150 m² — Terrain de Tom Tom');
  assert.equal(c2[2].etiquette, 'Lot 3 — Chantier 83 %');
  assert.equal(c2[2].image, 'images/chantiers/luthecia/facade-haut.webp');
  // Clic sur une carte : on entre dans le lot, comme avec l'ancienne zone de l'image.
  await page.click('[data-lot="terrain-a-batir-3"]');
  await page.waitForFunction(() => window.__entrees.length === 1, null, { timeout: 4000 });
  assert.deepEqual(await page.evaluate(() => window.__entrees), ['terrain-a-batir-3']);
  // Retour en arrière : plan retiré, aucune carte ne reste dans la rue.
  await page.evaluate(() => afficherNoeudRue('republic', 'luthecia-terrains-artisanal', null, true));
  assert.equal(await page.locator('.tplan').count(), 0);
}));

test('Port-Sainte-Marie et Montrouge : vignettes dans la vue « Terrains à bâtir », images de la ville, repli, clic vers le lot', () => avecPage(1100, async page => {
  await page.evaluate(() => {
    state.currentCity = 'ville_a';
    window.__lignes = [
      { id: 'republic_terrain-a-batir-8', country: 'republic', building_id: 'terrain-a-batir-8', proprietaire: 'Arnie', niveau_construction: null, data: JSON.stringify({ surface: 1500, proprietaire: 'Arnie', chantier: { niveau: 'hangar', progressionJours: 0, dureeJours: 6 } }) },
      { id: 'republic_terrain-a-batir-9', country: 'republic', building_id: 'terrain-a-batir-9', proprietaire: 'ville:ville_a', niveau_construction: 'logement', data: JSON.stringify({ surface: 1650, proprietaire: 'ville:ville_a', niveau_construction: 'logement' }) },
      { id: 'republic_terrain-a-batir-10', country: 'republic', building_id: 'terrain-a-batir-10', proprietaire: null, niveau_construction: null, data: JSON.stringify({ surface: 2200 }) }
    ];
    ouvrirTerrainsVille('ville_a');
  });
  await page.waitForFunction(() => document.querySelectorAll('.tplan-carte[data-etat]:not([data-etat="inconnu"])').length === 6);
  let c = await cartes(page);
  assert.deepEqual(c.slice(0, 3).map(x => x.etiquette), ['Lot 8 — Chantier 0 %', 'Lot 9 — Logements sociaux de la mairie', 'Lot 10 — 2 200 m² — À vendre']);
  assert.equal(c[0].image, 'images/chantiers/psm/PSM_chantier_demarrage_petit.webp');
  assert.equal(c[1].image, 'images/chantiers/psm/PSM_batiment_logement.webp');
  assert.equal(c[2].image, 'images/terrain-a-vendre-republic.webp');
  assert.equal(c[5].etiquette, 'Lot 13 — 5 500 m² — À vendre');
  assert.equal(await page.evaluate(() => document.getElementById('piece-image').dataset.planLots), '1');
  if (process.env.HG_CAPTURE) await page.waitForTimeout(1200), await page.locator('#piece-image').screenshot({ path: process.env.HG_CAPTURE.replace(/\.png$/, '') + '-psm.png' });
  await page.click('[data-lot="terrain-a-batir-9"]');
  assert.deepEqual(await page.evaluate(() => window.__entrees), ['terrain-a-batir-9']);

  // Montrouge : image propre à chaque lot pour un terrain nu ; gros œuvre bas absent → image de démarrage commune.
  await page.evaluate(() => {
    state.currentCity = 'ville_b';
    window.__lignes = [
      { id: 'republic_terrain-a-batir-montrouge-7', country: 'republic', building_id: 'terrain-a-batir-montrouge-7', proprietaire: 'Lina', niveau_construction: null, data: JSON.stringify({ surface: 1800, proprietaire: 'Lina', chantier: { niveau: 'hangar', progressionJours: 3, dureeJours: 6, attenteReception: false } }) },
      { id: 'republic_terrain-a-batir-montrouge-8', country: 'republic', building_id: 'terrain-a-batir-montrouge-8', proprietaire: 'Lina', niveau_construction: 'hangar', data: JSON.stringify({ surface: 2200, proprietaire: 'Lina', niveau_construction: 'hangar' }) }
    ];
    ouvrirTerrainsVille('ville_b');
  });
  await page.waitForFunction(() => document.querySelectorAll('.tplan-carte[data-etat]:not([data-etat="inconnu"])').length === 6);
  c = await cartes(page);
  const par = Object.fromEntries(c.map(x => [x.lot, x]));
  assert.equal(par['terrain-a-batir-montrouge-3'].image, 'images/montrouge/montrouge-terrain-lot-3.jpg');
  assert.equal(par['terrain-a-batir-montrouge-3'].etiquette, 'Lot 3 — 1 500 m² — À vendre');
  assert.equal(par['terrain-a-batir-6'].etiquette, 'Lot 6 — 2 100 m² — À vendre');
  assert.equal(par['terrain-a-batir-montrouge-7'].etiquette, 'Lot 7 — Chantier 50 %');
  assert.equal(par['terrain-a-batir-montrouge-7'].image, 'images/chantier-en-cours.webp');
  assert.equal(par['terrain-a-batir-montrouge-8'].etiquette, 'Lot 8 — Hangar de Lina');
  assert.equal(par['terrain-a-batir-montrouge-8'].image, 'images/hangar-construction-terrain.webp', 'final-hangar absent → fiche actuelle');
  // Une image qui ne se charge pas retombe sur le terrain nu (jamais d'image cassée).
  await page.evaluate(() => { document.querySelector('[data-lot="terrain-a-batir-montrouge-9"] img').src = 'images/chantiers/montrouge/inexistante.webp'; });
  await page.waitForFunction(() => document.querySelector('[data-lot="terrain-a-batir-montrouge-9"] img').getAttribute('src') === 'images/montrouge/montrouge-terrain-lot-9.jpg');
  // Serveur muet : message clair, dernières étiquettes gardées.
  await page.evaluate(async () => { window.sbGetTerrainsLibres = async () => { throw new Error('hors ligne'); }; await window.RPTerrainsPlan.relire(); });
  assert.equal(await page.locator('.tplan-panne').isVisible(), true);
  assert.equal(sansEsp(await page.locator('[data-lot="terrain-a-batir-montrouge-8"] .tplan-etiquette').textContent()), 'Lot 8 — Hangar de Lina');
}));

test('rue en trois états à Luthécia et Montrouge : aucune réception, une, toutes ; repli si l’image manque', () => avecPage(1100, async page => {
  const src = () => page.evaluate(() => document.getElementById('rc-image').getAttribute('src'));
  const vue = async (ville, noeud, lignes) => {
    await page.evaluate(async ([v, n, l]) => { state.currentCity = v; window.__lignes = l; await afficherNoeudRue('republic', n, null, true); }, [ville, noeud, lignes]);
    await page.waitForTimeout(500);
  };
  const ids = ['terrain-a-batir-1', 'terrain-a-batir-2', 'terrain-a-batir-3', 'terrain-a-batir-4', 'terrain-a-batir-5'];
  await vue('capitale', 'luthecia-terrains-artisanal', [ligne(ids[2], { chantier: chantier('building', 3, 24) })]);
  assert.equal(await src(), 'images/rue-terrains-artisanal.webp');
  await vue('capitale', 'luthecia-terrains-artisanal', [ligne(ids[3], { niveau_construction: 'hangar' }, 'hangar')]);
  await page.waitForFunction(() => document.getElementById('rc-image').getAttribute('src').endsWith('rue-etat-2.webp'));
  assert.equal(await src(), 'images/terrains/luthecia/rue-etat-2.webp');
  await vue('capitale', 'luthecia-terrains-artisanal', ids.map(i => ligne(i, { niveau_construction: 'building' }, 'building')));
  await page.waitForFunction(() => document.getElementById('rc-image').getAttribute('src').endsWith('rue-etat-3.webp'));
  // Zones et sorties inchangées.
  assert.equal(await page.locator('.rc-zone').count(), 2);
  assert.equal(await page.locator('.rc-fleche').count(), 3);
  // Montrouge : images pas encore livrées → l'image actuelle reste, quel que soit l'état.
  await vue('ville_b', 'montrouge-vue-11', [ligne('terrain-a-batir-6', { niveau_construction: 'hangar' }, 'hangar')]);
  assert.equal(await src(), 'images/montrouge/montrouge-rue-centre-artisanal-terrains.jpg');
  await vue('ville_b', 'montrouge-vue-11', ['terrain-a-batir-6', 'terrain-a-batir-montrouge-3', 'terrain-a-batir-montrouge-7', 'terrain-a-batir-montrouge-8', 'terrain-a-batir-montrouge-9', 'terrain-a-batir-montrouge-12'].map(i => ligne(i, {}, 'hangar')));
  assert.equal(await src(), 'images/montrouge/montrouge-rue-centre-artisanal-terrains.jpg');
}));
