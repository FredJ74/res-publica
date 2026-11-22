// Chromium réel : pays d'un poste (Fred, 22/11/2026, GAME-DESIGN-INTERFACE-ACCUEIL-20261122.md, partie B, points 15-16).
// Vrais fichiers du jeu (data.js, plateau-organisations-quetes.js, plateau-politique.js, plateau-personnage.js, style.css) ;
// lectures Supabase simulées avec les lignes de production du 22/11 au soir : postes_attribues n'a qu'une ligne pour
// Arnie (republic_min_def_national), sa fiche dit country = soviet (il est à Krasnov), poste = {"id":"min_def"} sans pays.
// Contrôles : organigrammes national et municipal de Sovarka et de Républia, Arnie à Krasnov puis à Luthécia ; Sasha,
// ministre soviétique, à Luthécia ; la ligne orpheline de Ben ne donne rien ; panneau du personnage ; ordres réservés.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), os = require('node:os'), http = require('node:http');
const { chromium } = require('../e2e/node_modules/playwright');
const { lancerChromium } = require('./fixtures/chromium-cdp.cjs');
const racine = path.resolve(__dirname, '../..');
const FICHIERS = ['/style.css', '/data.js', '/plateau-organisations-quetes.js', '/plateau-politique.js', '/plateau-personnage.js'];

const REGISTRE = [
  { id: 'republic_min_def_national', country: 'republic', poste_id: 'min_def', city: null, titulaire: 'Arnie', depuis: '2026-09-20T10:00:00Z' },
  { id: 'republic_min_fin_national', country: 'republic', poste_id: 'min_fin', city: null, titulaire: 'Jean Jaaj', depuis: '2026-10-20T10:00:00Z' },
  { id: 'republic_capitaine_port_national', country: 'republic', poste_id: 'capitaine_port', city: null, titulaire: 'Ben', depuis: '2026-11-20T10:00:00Z' },
  { id: 'republic_directeur_entrepot_ville_a', country: 'republic', poste_id: 'directeur_entrepot', city: 'ville_a', titulaire: 'Ben', depuis: '2026-11-01T10:00:00Z' },
  { id: 'republic_maire_adjoint_capitale', country: 'republic', poste_id: 'maire_adjoint', city: 'capitale', titulaire: 'Lina', depuis: '2026-11-01T10:00:00Z' },
  { id: 'soviet_min_def_national', country: 'soviet', poste_id: 'min_def', city: null, titulaire: 'Sasha', depuis: '2026-11-01T10:00:00Z' },
];
const FICHES = [
  { name: 'Arnie', country: 'soviet', nationalite: 'republic', poste: { id: 'min_def', city: null, name: 'Ministre de la Defense' } },
  { name: 'Jean Jaaj', country: 'republic', nationalite: 'republic', poste: { id: 'min_fin', city: null, name: 'Ministre des Finances' } },
  { name: 'Ben', country: 'republic', nationalite: 'republic', poste: { id: 'capitaine_port', city: null, name: 'Commandant du Port' } },
  { name: 'Lina', country: 'soviet', nationalite: 'republic', poste: { id: 'maire_adjoint', city: 'capitale', name: 'Maire Adjoint' } },
  { name: 'Sasha', country: 'republic', nationalite: 'soviet', poste: { id: 'min_def', city: null, name: 'Ministre de la Défense de la Patrie' } },
  { name: 'Moustafa Kheimal', country: 'republic', nationalite: 'republic', poste: { id: 'president', city: null, name: 'Président' } },
];
const CYCLES = [
  { id: 'republic_president', country: 'republic', poste_id: 'president', city: null, data: '{"eluId":"Moustafa Kheimal"}' },
  { id: 'republic_maire_capitale', country: 'republic', poste_id: 'maire', city: 'capitale', data: '{"eluId":"Le Maire (PNJ)"}' },
  { id: 'soviet_president', country: 'soviet', poste_id: 'president', city: null, data: '{"eluId":null}' },
];
const PNJ = [{ id: 'soviet_maire_adjoint_capitale', country: 'soviet', poste_id: 'maire_adjoint', city: 'capitale', nom_pnj: 'Adjoint Volkov (PNJ)' }];

async function avecPage(fn) {
  const page0 = '<!doctype html><meta charset="utf-8"><link rel="stylesheet" href="/style.css">'
    + '<div id="modal-postes" class="modal-overlay"><div class="modal-box"><div id="postes-modal-title"></div><div id="postes-body"></div></div></div>'
    + '<div id="vue-self"><div id="self-content"></div></div>'
    + '<script>var state={char:{name:"Arnie",country:"soviet"},country:"soviet",currentCity:"ville_b",currentBuilding:"mairie",currentRoom:"accueil_mairie",'
    + 'poste:{id:"min_def",city:null,name:"Ministre de la Defense"},arg:0,liquide:0,pa:20};'
    // escapeHtmlText vit dans forum.js (non chargé ici) : même fonction, recopiée.
    + 'function escapeHtmlText(s){return String(s==null?"":s).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/\'/g,"&#39;");}</script>'
    + FICHIERS.filter(f => f.endsWith('.js')).map(f => '<script src="' + f + '"></script>').join('');
  const serveur = http.createServer((req, res) => {
    const url = decodeURIComponent(req.url.split('?')[0]);
    if (url === '/') { res.setHeader('Content-Type', 'text/html; charset=utf-8'); res.end(page0); return; }
    if (!FICHIERS.includes(url)) { res.writeHead(404); res.end(); return; }
    res.setHeader('Content-Type', url.endsWith('.js') ? 'text/javascript' : 'text/css'); res.end(fs.readFileSync(path.join(racine, url.slice(1))));
  });
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'hg-postes-pays-')); let nav, browser;
  try {
    await new Promise((r, j) => { serveur.once('error', j); serveur.listen(0, '127.0.0.1', r); });
    nav = await lancerChromium({ executable: process.env.HG_CHROMIUM || ['/usr/bin/chromium', '/usr/bin/google-chrome', '/usr/bin/google-chrome-stable'].find(p => fs.existsSync(p)), profil });
    browser = await chromium.connectOverCDP('http://127.0.0.1:' + nav.port);
    const page = await browser.contexts()[0].newPage(); await page.setViewportSize({ width: 1000, height: 900 });
    const erreurs = []; page.on('pageerror', e => erreurs.push(String(e)));
    await page.goto('http://127.0.0.1:' + serveur.address().port);
    await page.waitForFunction(() => typeof window.afficherOrganigrammeMairieNational === 'function' && typeof window.posteDetenu === 'function');
    await page.evaluate(({ REGISTRE, FICHES, CYCLES, PNJ }) => {
      window.__lectures = [];
      window.sbGet = async (table, filtre) => {
        window.__lectures.push([table, filtre]);
        const m = /country=eq\.([a-z]+)/.exec(filtre || ''), pays = m && m[1];
        if (table === 'postes_attribues') return REGISTRE.map(r => ({ ...r }));
        if (table === 'cycles_electoraux') return CYCLES.filter(c => !pays || c.country === pays).map(c => ({ ...c }));
        if (table === 'titulaires_pnj') return PNJ.map(r => ({ ...r }));
        return [];
      };
      window.sbListPersonnages = async () => FICHES.map(f => ({ ...f, poste: { ...f.poste } }));
      window.sbGetTitulairePnj = async (pays, poste, ville) => (PNJ.find(r => r.country === pays && r.poste_id === poste && (r.city || null) === (ville || null)) || {}).nom_pnj || null;
      window.showToast = () => {};
    }, { REGISTRE, FICHES, CYCLES, PNJ });
    await fn(page);
    assert.deepEqual(erreurs, []);
  } finally {
    if (browser) await browser.close(); if (nav) await nav.arreter();
    serveur.closeAllConnections(); await new Promise(r => serveur.close(r)); fs.rmSync(profil, { recursive: true, force: true });
  }
}

const placer = (page, pays, ville) => page.evaluate(([p, v]) => { state.country = p; state.char.country = p; state.currentCity = v; }, [pays, ville]);
async function lignes(page, ouvrir) {
  await page.evaluate(o => window[o](), ouvrir);
  await page.waitForFunction(() => !/Chargement/.test(document.getElementById('postes-body').textContent));
  return page.evaluate(() => ({ titre: document.getElementById('postes-modal-title').textContent,
    lignes: [...document.querySelectorAll('#postes-body > div')].map(d => d.innerText.replace(/\s+/g, ' ').trim()).filter(Boolean) }));
}
const ligneDe = (o, intitule) => o.lignes.find(l => l.startsWith(intitule)) || '';

test('organigramme national : Arnie à Krasnov n’est pas ministre de Sovarka, il reste ministre de Républia', async () => {
  await avecPage(async (page) => {
    // Arnie à Krasnov ; on consulte l'organigramme de Sovarka (pays affiché = pays où l'on se trouve).
    let o = await lignes(page, 'afficherOrganigrammeMairieNational');
    assert.match(o.titre, /Organigramme national — Sovarka/);
    assert.match(ligneDe(o, 'Ministre de la Défense de la Patrie'), /Sasha/, 'le ministre soviétique, même en voyage à Luthécia');
    assert.doesNotMatch(o.lignes.join('\n'), /Arnie/, 'Arnie n’apparaît nulle part dans l’organigramme de Sovarka');
    assert.doesNotMatch(o.lignes.join('\n'), /Jean Jaaj|Ben/);
    // Le même lecteur, pour Républia, pendant qu'Arnie est toujours à Krasnov : il garde son poste.
    await placer(page, 'republic', 'capitale');
    await page.evaluate(() => { state.country = 'republic'; });
    o = await lignes(page, 'afficherOrganigrammeMairieNational');
    assert.match(o.titre, /Organigramme national — Republia/);
    assert.match(ligneDe(o, 'Ministre de la Defense'), /Arnie/);
    assert.match(ligneDe(o, 'Ministre des Finances'), /Jean Jaaj/);
    assert.match(ligneDe(o, 'Président'), /Moustafa Kheimal/);
    assert.doesNotMatch(o.lignes.join('\n'), /Sasha/, 'Sasha, ministre soviétique présent à Luthécia, n’y figure pas');
  });
});

test('organigramme national : mêmes résultats quand Arnie rentre à Luthécia', async () => {
  await avecPage(async (page) => {
    await page.evaluate(() => { state.country = 'republic'; state.char.country = 'republic'; state.currentCity = 'capitale'; });
    let o = await lignes(page, 'afficherOrganigrammeMairieNational');
    assert.match(ligneDe(o, 'Ministre de la Defense'), /Arnie ✦/);
    await page.evaluate(() => { state.country = 'soviet'; state.currentCity = 'ville_b'; });
    o = await lignes(page, 'afficherOrganigrammeMairieNational');
    assert.match(ligneDe(o, 'Ministre de la Défense de la Patrie'), /Sasha/);
    assert.doesNotMatch(o.lignes.join('\n'), /Arnie/);
  });
});

test('organigramme municipal : l’adjoint de Luthécia en voyage reste à Luthécia ; Sovarka garde son PNJ', async () => {
  await avecPage(async (page) => {
    await page.evaluate(() => { state.country = 'soviet'; state.currentCity = 'capitale'; });
    let o = await lignes(page, 'afficherOrganigrammeMairieMunicipal');
    assert.match(ligneDe(o, 'Maire Adjoint'), /Adjoint Volkov \(PNJ\)/, 'Lina (Républia) est à Novomirsk mais n’en devient pas adjointe');
    assert.doesNotMatch(o.lignes.join('\n'), /Lina/);
    await page.evaluate(() => { state.country = 'republic'; state.currentCity = 'capitale'; });
    o = await lignes(page, 'afficherOrganigrammeMairieMunicipal');
    assert.match(ligneDe(o, 'Maire Adjoint'), /Lina/);
    // Ligne orpheline : Ben n'est plus directeur de l'entrepôt de PSM (sa fiche porte Commandant du Port).
    assert.equal(await page.evaluate(() => posteDetenu('Ben', 'directeur_entrepot', 'republic', 'ville_a')), false);
    assert.equal(await page.evaluate(() => posteDetenu('Ben', 'capitaine_port', 'republic', null)), true);
  });
});

test('organigramme du Palais (ouvrirOrganigramme et écran des postes) : registre filtré sur le pays affiché', async () => {
  await avecPage(async (page) => {
    let o = await lignes(page, 'ouvrirOrganigramme');
    assert.match(o.titre, /Sovarka/);
    assert.doesNotMatch(o.lignes.join('\n'), /Arnie/);
    assert.match(o.lignes.join('\n'), /Sasha/);
    await page.evaluate(() => { state.country = 'republic'; state.currentCity = 'capitale'; });
    o = await lignes(page, 'ouvrirEcranPostes');
    assert.match(o.lignes.join('\n'), /Ministre de la Defense\s*Occupé par Arnie/);
    assert.doesNotMatch(o.lignes.join('\n'), /Occupé par Sasha/);
  });
});

test('règle unique du navigateur et ordres réservés : aucun pouvoir à l’étranger, tout chez soi', async () => {
  await avecPage(async (page) => {
    await page.evaluate(() => chargerRegistrePostes(true));
    const r = await page.evaluate(() => ({ paysArnie: paysDuPoste('Arnie'), paysSasha: paysDuPoste('Sasha'), paysMoustafa: paysDuPoste('Moustafa Kheimal'),
      detSov: posteDetenu('Arnie', 'min_def', 'soviet'), detRep: posteDetenu('Arnie', 'min_def', 'republic'),
      ici: posteExerceIci('min_def'), mandat: paysMandatPourOrdre('min_def'), paysPoste: state.paysPoste }));
    assert.deepEqual(r, { paysArnie: 'republic', paysSasha: 'soviet', paysMoustafa: 'republic', detSov: false, detRep: true,
      ici: false, mandat: 'republic', paysPoste: 'republic' });
    await page.evaluate(() => { state.country = 'republic'; state.currentCity = 'capitale'; });
    assert.equal(await page.evaluate(() => posteExerceIci('min_def')), true);
  });
});

test('panneau du personnage : le poste d’Arnie reste celui de Républia, le pays est nommé quand il voyage', async () => {
  await avecPage(async (page) => {
    await page.evaluate(() => chargerRegistrePostes(true));
    assert.equal(await page.evaluate(() => libellePosteJoueur()), 'Ministre de la Defense — Republia');
    await page.evaluate(() => {
      // Dépendances périphériques de la fiche (banque, fortune, textes riches) : neutres, mêmes noms.
      window.sbRpc = async () => null;
      for (const [n, f] of [['totalComptesBancaires', () => 0], ['resumeFortune', () => ''], ['rpCharSheetLabel', (k, fr) => fr],
        ['sanitizeRichHtml', t => String(t || '')], ['switchCharSheetTab', () => {}]]) if (typeof window[n] !== 'function') window[n] = f;
      switchSelfTab('identite', null);
    });
    const fiche = await page.evaluate(() => document.getElementById('self-content').innerText);
    assert.match(fiche, /Ministre de la Defense — Republia/);
    assert.doesNotMatch(fiche, /de la Patrie/);
    await page.evaluate(() => { state.country = 'republic'; state.char.country = 'republic'; });
    assert.equal(await page.evaluate(() => libellePosteJoueur()), 'Ministre de la Defense');
    // Liste des PJ : rangé avec les républicains, poste attesté, pays nommé pour Sasha rangé ailleurs.
    assert.equal(await page.evaluate(() => libellePostePJ({ name: 'Sasha', poste: { id: 'min_def' } }, 'republic')), 'Ministre de la Défense de la Patrie (Sovarka)');
    assert.equal(await page.evaluate(() => libellePostePJ({ name: 'Ben', poste: { id: 'directeur_entrepot' } }, 'republic')), '', 'poste non attesté : rien');
  });
});
