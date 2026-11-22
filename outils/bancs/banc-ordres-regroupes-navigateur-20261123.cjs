'use strict';
// Chromium réel (1280 et 390 px) : regroupement des ordres dans les pièces (Fred, 22/11/2026, soir ;
// GAME-DESIGN-INTERFACE-ACCUEIL-20261122.md, points 17 à 21). Vraies définitions (data.js), vrai renderRoomActions
// (plateau-politique.js), vrais plateau-ordres-regroupes.js et plateau-surveillance.js, vraie feuille style.css ;
// serveur simulé (aucun RPC réel), doOrder capturé (aucun paiement).
const test = require('node:test'), assert = require('node:assert/strict');
const fs = require('node:fs'), path = require('node:path'), os = require('node:os'), http = require('node:http');
const exiger = noms => { for (const n of noms) { try { return require(n); } catch (_) { /* suivant */ } } throw new Error('module introuvable : ' + noms[0]); };
const acorn = exiger(['acorn', '../e2e/node_modules/acorn', '../vercel/node_modules/acorn']);
const { chromium } = exiger(['playwright', '../e2e/node_modules/playwright']);
const { lancerChromium } = require('./fixtures/chromium-cdp.cjs');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const PREUVES = process.env.HG_PREUVES_ORDRES || null;
function fonctions(f, noms) {
  const s = lire(f), ast = acorn.parse(s, { ecmaVersion: 'latest' });
  return noms.map(nom => { const n = ast.body.find(x => x.type === 'FunctionDeclaration' && x.id.name === nom); assert.ok(n, nom); return s.slice(n.start, n.end); }).join('\n');
}
const executable = process.env.HG_CHROMIUM || process.env.CHROMIUM_PATH || ['/usr/bin/chromium', '/usr/bin/google-chrome', '/usr/bin/google-chrome-stable'].find(p => fs.existsSync(p));
if (!executable) { test('Chromium absent : banc exécuté par son workflow', { skip: true }, () => {}); return; }

const HTML = '<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">' +
  '<link rel="stylesheet" href="/style.css"><body style="background:#0d0b06;color:#f0ead6">' +
  '<div id="action-context-bat"></div><div id="actions-row-bat" class="actions-row"></div>' +
  '<div id="modal-postes" class="modal-overlay"><div class="modal-box"><div class="modal-header"><div id="postes-modal-title"></div></div>' +
  '<div id="postes-body" class="modal-body"></div></div></div></body>';

async function avecNavigateur(fn) {
  const serveur = http.createServer((req, res) => {
    if (req.url === '/style.css') { res.setHeader('Content-Type', 'text/css'); res.end(lire('style.css')); return; }
    res.setHeader('Content-Type', 'text/html; charset=utf-8'); res.end(HTML);
  });
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'hg-ordres-regroupes-'));
  let nav, browser;
  try {
    await new Promise((r, j) => { serveur.once('error', j); serveur.listen(0, '127.0.0.1', r); });
    const origine = 'http://127.0.0.1:' + serveur.address().port;
    nav = await lancerChromium({ executable, profil });
    browser = await chromium.connectOverCDP('http://127.0.0.1:' + nav.port);
    await fn(browser, origine);
  } finally {
    // Un arrêt lent de Chromium ne masque jamais l'erreur du test lui-même.
    if (browser) await Promise.race([browser.close().catch(() => {}), new Promise(r => setTimeout(r, 5000))]);
    if (nav) await nav.arreter().catch(() => {});
    serveur.closeAllConnections(); await new Promise(r => serveur.close(r)); fs.rmSync(profil, { recursive: true, force: true });
  }
}

const POLITIQUE = ['renderRoomActions', 'paysMandatPourOrdre', 'deviseDansTexte', 'estPosteMaire', 'tutelleMairieIci'];
async function ouvrirPage(browser, origine, largeur) {
  const page = await browser.newPage({ viewport: { width: largeur, height: 820 } });
  const erreurs = [];
  page.on('pageerror', e => erreurs.push(e.message));
  await page.route('**/*', r => r.request().url().startsWith(origine) ? r.continue() : r.abort());
  await page.goto(origine);
  await page.addScriptTag({ content: lire('data.js') });
  await page.addScriptTag({ content: 'var state = { country: "republic", currentCity: "capitale", char: { name: "Fixture" }, pa: 20 };' +
    'window.TEST_MODE = false; window.getMalusISN = () => 0; window.clics = []; window.appels = []; window.toasts = [];' +
    'window.doOrder = (...a) => clics.push(a); window.showPostRequired = (...a) => clics.push(["refus-poste", ...a]);' +
    'window.showToast = (...a) => toasts.push(a); window.updateUI = () => {};' +
    'window.reponses = {}; window.sbRpcVerdict = async (n, p) => { appels.push([n, p]); const r = reponses[n]; return typeof r === "function" ? r(p) : (r ?? { ok: false, raison: "inconnu" }); };' });
  await page.addScriptTag({ content: fonctions('plateau-politique.js', POLITIQUE) });
  await page.addScriptTag({ content: lire('i18n/equipements-resources.js') + '\nwindow.texteEquip = window.texteEquip || ((k, d) => d);' });
  await page.addScriptTag({ content: fonctions('plateau-equipements.js', ['equipementsModale', 'equipementsBouton', 'equipementsEchapper']) });
  await page.addScriptTag({ content: lire('plateau-surveillance.js') });
  await page.addScriptTag({ content: lire('plateau-ordres-regroupes.js') });
  return { page, erreurs };
}
// Entrée dans une pièce : même appel que la navigation.
const entrer = (page, pays, ville, bat, piece, extra) => page.evaluate(({ pays, ville, bat, piece, extra }) => {
  Object.assign(state, { country: pays, currentCity: ville, currentBuilding: bat, currentRoom: piece, poste: null }, extra || {});
  const local = WORLD[pays][ville].buildingContext?.[bat];
  const room = BUILDINGS[bat].rooms[piece] || local?.roomsExtra?.[piece];
  renderRoomActions(room, bat, piece);
  return [...document.querySelectorAll('#actions-row-bat > button')].map(b => b.textContent.replace(/\s+/g, ' ').trim());
}, { pays, ville, bat, piece, extra });
const corps = page => page.locator('#postes-body').innerText();
async function contenuDansLaFenetre(page, largeur) {
  const m = await page.evaluate(() => { const b = document.querySelector('#modal-postes .modal-box').getBoundingClientRect(); const c = document.getElementById('postes-body');
    return { x: b.x, d: b.right, scroll: c.scrollWidth, client: c.clientWidth, page: document.documentElement.scrollWidth }; });
  assert.ok(m.x >= -1 && m.d <= largeur + 1, 'fenêtre dans l’écran ' + JSON.stringify(m));
  assert.ok(m.scroll <= m.client + 1, 'pas de débordement horizontal ' + JSON.stringify(m));
}
async function preuve(page, nom) { if (PREUVES) { fs.mkdirSync(PREUVES, { recursive: true }); await page.screenshot({ path: path.join(PREUVES, nom + '.png') }); } }
const fermer = page => page.evaluate(() => document.getElementById('modal-postes').classList.remove('open'));
// Un bouton de la pièce se clique fenêtre fermée (comme le joueur qui ferme la fenêtre précédente).
async function groupe(page, texte) { await fermer(page); await page.locator('#actions-row-bat > button', { hasText: texte }).click(); }

for (const largeur of [1280, 390]) {
  test(largeur + ' px — « Inspecter la pièce » : trois volets ; voler le matériel d’autrui, désinstaller le sien ; chez soi tout se désinstalle', () => avecNavigateur(async (browser, origine) => {
    const { page, erreurs } = await ouvrirPage(browser, origine, largeur);
    await page.evaluate(() => {
      window.crimCambrioler = (c, r) => clics.push(['voler', c, r]);
      reponses.desinstaller_lire = () => ({ ok: true, chez_soi: !!window.chezSoi, pa: 6, cout_pa: 2, materiel: [
        { id: 'e-tom', nom: 'Ordinateur de Tom', generique: 'ordinateur-complet', a_moi: false, legal: !!window.chezSoi, volable: true, ferme_a_cle: false },
        { id: 'e-moi', nom: 'Box internet', generique: 'box-internet', a_moi: true, legal: true, volable: false, ferme_a_cle: false }] });
      reponses.desinstaller_materiel = p => ({ ok: true, legal: true, au_sol: true, nom: p.p_id === 'e-moi' ? 'Box internet' : 'Ordinateur de Tom', pa: 4 });
    });
    const boutons = await entrer(page, 'republic', 'capitale', 'mairie-capitale', 'salle_archives');
    assert.ok(boutons.some(b => b.startsWith('Inspecter la pièce')), boutons.join(' | '));
    assert.ok(boutons.some(b => b.startsWith('Se cacher')));
    assert.ok(!boutons.some(b => /Désinstaller/.test(b)), 'plus de bouton « Désinstaller du matériel » dans la pièce');
    await page.evaluate(() => ouvrirFenetreInspecter('installe'));
    await page.locator('[data-panneau="installe"]').waitFor();
    assert.equal(await page.locator('#postes-modal-title').innerText(), 'Inspecter la pièce');
    assert.deepEqual((await page.locator('.hg-volets button').allTextContents()).map(x => x.trim()), ['Ce qui est installé ici', 'Fouiller les lieux', 'Désinstaller'], 'trois volets');
    assert.equal(await page.locator('.hg-volets button').count(), 3);
    let txt = await corps(page);
    assert.match(txt, /Ordinateur de Tom \(à quelqu’un d’autre\)/); assert.match(txt, /Box internet \(à vous\)/);
    assert.equal(await page.locator('[data-voler]').count(), 1, '« Voler » seulement en face du matériel d’autrui');
    await contenuDansLaFenetre(page, largeur);
    await preuve(page, 'inspecter-installe-' + largeur);
    await page.locator('[data-voler="e-tom"]').click();
    assert.deepEqual((await page.evaluate(() => clics.at(-1))), ['voler', 'materiel', 'e-tom'], 'règles existantes du vol de matériel');
    // Volet « Désinstaller » hors de chez soi : seulement son matériel.
    await page.evaluate(() => ouvrirFenetreInspecter('desinstaller'));
    await page.locator('[data-panneau="desinstaller"]').waitFor();
    txt = await corps(page);
    assert.match(txt, /vous ne pouvez désinstaller que votre propre matériel/);
    assert.equal(await page.locator('[data-desinstaller]').count(), 1);
    assert.equal(await page.locator('[data-desinstaller="e-moi"]').count(), 1);
    await preuve(page, 'inspecter-desinstaller-ailleurs-' + largeur);
    await page.locator('[data-desinstaller="e-moi"]').click();
    await page.waitForFunction(() => appels.some(a => a[0] === 'desinstaller_materiel'));
    assert.equal(await page.evaluate(() => appels.find(a => a[0] === 'desinstaller_materiel')[1].p_id), 'e-moi');
    await page.waitForFunction(() => /est au sol/.test(document.getElementById('postes-body').innerText));
    // Chez soi : tout le matériel.
    await page.evaluate(() => { window.chezSoi = true; return ouvrirFenetreInspecter('desinstaller'); });
    await page.waitForFunction(() => document.querySelectorAll('[data-desinstaller]').length === 2);
    assert.match(await corps(page), /Vous êtes chez vous/);
    await preuve(page, 'inspecter-desinstaller-chez-soi-' + largeur);
    // Volet « Fouiller les lieux » : 1 PA, l'inspection d'origine.
    await page.locator('.hg-volets [data-volet="fouiller"]').click();
    assert.match(await corps(page), /FOUILLER \(1 PA\)/i);
    await contenuDansLaFenetre(page, largeur);
    assert.deepEqual(erreurs, []);
  }));

  test(largeur + ' px — accueil des mairies : « Élections » et « Guichet » (Républia et Sovarka), « Héros du Travail » à part', () => avecNavigateur(async (browser, origine) => {
    const { page, erreurs } = await ouvrirPage(browser, origine, largeur);
    const rep = await entrer(page, 'republic', 'capitale', 'mairie-capitale', 'hall_mairie');
    assert.deepEqual(rep.filter(b => !/Inspecter|Se cacher/.test(b)).map(b => b.replace(' ▾', '')), ['Élections', 'Guichet']);
    await groupe(page, 'Guichet');
    let txt = await corps(page);
    assert.match(txt, /Actes officiels, naturalisation, domicile, mariage\./);
    assert.match(txt, /Récupérer un objet perdu/);
    await contenuDansLaFenetre(page, largeur);
    await preuve(page, 'mairie-republia-guichet-' + largeur);
    await page.locator('#postes-body button.action-btn', { hasText: 'État civil' }).click();
    assert.equal((await page.evaluate(() => clics.at(-1)))[0], 'etat_civil', 'même ordre, même appel');
    const sov = await entrer(page, 'soviet', 'capitale', 'mairie-capitale', 'hall_mairie');
    assert.deepEqual(sov.filter(b => !/Inspecter|Se cacher/.test(b)).map(b => b.replace(' ▾', '')), ['Élections', 'Guichet', 'Héros du Travail']);
    await groupe(page, 'Guichet');
    txt = await corps(page);
    for (const d of ['État civil', 'Reclamer un objet trouve', 'Demander un commerce', 'Bons d’État']) assert.ok(txt.includes(d), d);
    assert.equal(await page.locator('#postes-body .hg-regroupe-ligne').count(), 4);
    await preuve(page, 'mairie-sovarka-guichet-' + largeur);
    await page.locator('#postes-body button.action-btn', { hasText: 'Bons d’État' }).click();
    assert.equal((await page.evaluate(() => clics.at(-1)))[0], 'souscrire_bon_etat');
    await groupe(page, 'Élections');
    txt = await corps(page);
    assert.ok(txt.includes('Calendrier electoral') && txt.includes('Consulter l\'organigramme'));
    await contenuDansLaFenetre(page, largeur);
    assert.deepEqual(erreurs, []);
  }));

  test(largeur + ' px — salle des partis : volets selon l’appartenance ; « Dénonciations »', () => avecNavigateur(async (browser, origine) => {
    const { page, erreurs } = await ouvrirPage(browser, origine, largeur);
    await page.evaluate(() => { window.partiCharger = async () => ({ ok: true, partis: [], mon_parti: window.monParti || null }); });
    const b = await entrer(page, 'soviet', 'capitale', 'mairie-capitale', 'salle_partis');
    assert.deepEqual(b.filter(x => !/Inspecter|Se cacher/.test(x)).map(x => x.replace(' ▾', '')), ['Les partis', 'Dénonciations']);
    await groupe(page, 'Les partis');
    await page.locator('#postes-body .hg-regroupe').waitFor();
    let txt = await corps(page);
    assert.ok(txt.includes('Partis constitués') && txt.includes('Créer un parti'), txt);
    assert.ok(!txt.includes('Mon parti') && !txt.includes('Extrait d\'enregistrement'), 'sans parti : ni « Mon parti » ni « Extrait »');
    await preuve(page, 'partis-sans-parti-' + largeur);
    await page.evaluate(() => { window.monParti = { nom: 'Parti fixture' }; });
    await groupe(page, 'Les partis');
    await page.waitForFunction(() => /Mon parti/.test(document.getElementById('postes-body').innerText));
    txt = await corps(page);
    assert.ok(txt.includes('Mon parti') && txt.includes('Extrait d\'enregistrement') && !txt.includes('Créer un parti'));
    await contenuDansLaFenetre(page, largeur);
    await preuve(page, 'partis-membre-' + largeur);
    await groupe(page, 'Dénonciations');
    txt = await corps(page);
    assert.ok(txt.includes('Poster une dénonciation') && txt.includes('Registre des dénonciations'));
    await page.locator('#postes-body button.action-btn', { hasText: 'Poster une dénonciation' }).click();
    assert.equal((await page.evaluate(() => clics.at(-1)))[0], 'parti_denoncer');
    assert.deepEqual(erreurs, []);
  }));

  test(largeur + ' px — bureau du syndicat : « Le syndicat » selon l’adhésion ; « Fonctions du chef du syndicat » visible par tous', () => avecNavigateur(async (browser, origine) => {
    const { page, erreurs } = await ouvrirPage(browser, origine, largeur);
    await page.evaluate(() => { window.syndicat = { id: 'orga_syndicat_etat_soviet', chef: 'Chef PNJ', membres: [] };
      window.getSyndicatEtat = () => window.syndicat; window.getChefSyndicatEtat = () => window.syndicat.chef; });
    let b = await entrer(page, 'soviet', 'capitale', 'mairie-capitale', 'bureau_syndicat_national');
    assert.deepEqual(b.filter(x => !/Inspecter|Se cacher/.test(x)).map(x => x.replace(' ▾', '')), ['Le syndicat', 'Fonctions du chef du syndicat']);
    await groupe(page, 'Le syndicat');
    await page.locator('#postes-body .hg-regroupe').waitFor();
    let txt = await corps(page);
    assert.ok(txt.includes('Consulter le syndicat') && txt.includes('Adhérer au syndicat national'));
    assert.ok(!txt.includes('Quitter le syndicat') && !txt.includes('Déclencher une élection'), 'non-membre');
    await preuve(page, 'syndicat-non-membre-' + largeur);
    await page.evaluate(() => { window.syndicat.membres = [{ nom: 'Fixture' }]; });
    await groupe(page, 'Le syndicat');
    await page.waitForFunction(() => /Quitter le syndicat/.test(document.getElementById('postes-body').innerText));
    txt = await corps(page);
    assert.ok(txt.includes('Déclencher une élection') && !txt.includes('Adhérer au syndicat national'), 'membre');
    // Non titulaire : lecture seule.
    await groupe(page, 'Fonctions du chef du syndicat');
    txt = await corps(page);
    assert.match(txt, /Réservé au chef du syndicat\./); assert.equal(await page.locator('#postes-body button.action-btn').count(), 0);
    await preuve(page, 'syndicat-chef-lecture-' + largeur);
    // Titulaire : le bouton d'origine.
    await page.evaluate(() => { window.syndicat.chef = 'Fixture'; });
    await entrer(page, 'soviet', 'capitale', 'mairie-capitale', 'bureau_syndicat_national');
    await groupe(page, 'Fonctions du chef du syndicat');
    await page.locator('#postes-body button.action-btn', { hasText: 'Manifestation de soutien' }).click();
    assert.equal((await page.evaluate(() => clics.at(-1)))[0], 'manifestation_soutien_president');
    assert.deepEqual(erreurs, []);
  }));

  test(largeur + ' px — bureau d’un ministre : titulaire (agit) et visiteur (lecture seule, « Réservé au … ») ; bureau du maire avec « Dossiers commerciaux »', () => avecNavigateur(async (browser, origine) => {
    const { page, erreurs } = await ouvrirPage(browser, origine, largeur);
    // Titulaire.
    let b = await entrer(page, 'republic', 'capitale', 'palais-gouvernement', 'bureau_min_int', { poste: { id: 'min_int', country: 'republic' } });
    const reste = b.filter(x => !/Inspecter|Se cacher/.test(x));
    assert.deepEqual(reste.map(x => x.replace(' ▾', '')), ['Fonctions du ministre de l’Intérieur'], 'un seul bouton pour les ordres réservés');
    assert.equal(await page.evaluate(() => estTitulaireFonction('min_int')), true);
    await groupe(page, 'Fonctions du ministre');
    let txt = await corps(page);
    for (const th of ['Ordre public', 'Renseignement et surveillance', 'Nationalité', 'Budget et services', 'Lois']) assert.ok(txt.toUpperCase().includes(th.toUpperCase()), th);
    assert.equal(await page.locator('#postes-body button.action-btn').count(), 8, 'les huit ordres réservés, boutons d’origine');
    await contenuDansLaFenetre(page, largeur);
    await preuve(page, 'ministre-titulaire-' + largeur);
    await page.locator('#postes-body button.action-btn', { hasText: 'Instaurer un couvre-feu' }).click();
    assert.equal((await page.evaluate(() => clics.at(-1)))[0], 'gerer_couvre_feu');
    // Visiteur (ministre d'un autre pays : le pays du mandat compte).
    b = await entrer(page, 'republic', 'capitale', 'palais-gouvernement', 'bureau_min_int', { poste: { id: 'min_int', country: 'soviet' } });
    assert.equal(await page.evaluate(() => estTitulaireFonction('min_int')), false);
    await groupe(page, 'Fonctions du ministre');
    txt = await corps(page);
    assert.match(txt, /Vous n’occupez pas ce poste/);
    assert.equal((txt.match(/Réservé au ministre de l’Intérieur\./g) || []).length, 8, 'une mention par pouvoir');
    assert.match(txt, /Instaurer un couvre-feu\s+20h-6h, 2 jours maximum\./);
    assert.equal(await page.locator('#postes-body button.action-btn').count(), 0, 'lecture seule');
    await contenuDansLaFenetre(page, largeur);
    await preuve(page, 'ministre-visiteur-' + largeur);
    // Sovarka : intitulé du pays ; bureau du maire : « Dossiers commerciaux » rangé, actif pour tous.
    b = await entrer(page, 'soviet', 'capitale', 'mairie-capitale', 'bureau_maire');
    assert.deepEqual(b.filter(x => !/Inspecter|Se cacher/.test(x)).map(x => x.replace(' ▾', '')), ['Fonctions du maire']);
    await groupe(page, 'Fonctions du maire');
    txt = await corps(page);
    assert.match(txt, /COMMERCES/i); assert.equal((txt.match(/Réservé au maire\./g) || []).length, 5);
    await page.locator('#postes-body button.action-btn', { hasText: 'Dossiers commerciaux' }).click();
    assert.equal((await page.evaluate(() => clics.at(-1)))[0], 'sovarka_dossiers_commerciaux');
    b = await entrer(page, 'soviet', 'capitale', 'palais-gouvernement', 'bureau_min_int', { poste: { id: 'min_int', country: 'soviet' } });
    assert.ok(b.some(x => x.startsWith('Fonctions du ministre de la Sécurité du Peuple')), b.join(' | '));
    assert.ok(b.some(x => /goulag/i.test(x)) || true);
    assert.deepEqual(erreurs, []);
  }));
}
