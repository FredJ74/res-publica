// Chromium réel : refonte des informateurs (Fred, 19/11/2026 ; étape K du 22/11/2026). Vrais fichiers du jeu
// (plateau-informateurs.js, plateau-criminalite.js, style.css) ; identité et RPC simulées.
// Mission Novomirsk, bloc 3, points 24 et 25 (23/11/2026) : plus d'ordre de pièce, on clique sur le PNJ informateur ;
// sa fiche porte « Acheter une information » (« Lui offrir un verre » pour l'habitué du Bar Sever), la fiche se ferme et
// la fenêtre de l'informateur s'ouvre à sa place (R8 : jamais deux fenêtres superposées).
// Contrôles « comme pour un enfant » : le bouton n'apparaît que si le serveur dit que ce PNJ est informateur ici ; la
// fenêtre dit qui il est, ce qu'il sait et le barème ; le bouton dit la somme et le palier et reste grisé hors barème ;
// la réponse du serveur s'affiche en texte (jamais en HTML) ; un refus est nommé ; l'habitué du Bar Sever a sa fenêtre ;
// le commissaire paie un informateur depuis la fenêtre des plaintes contre X.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), os = require('node:os'), http = require('node:http');
const { chromium } = require('../e2e/node_modules/playwright');
const { lancerChromium } = require('./fixtures/chromium-cdp.cjs');
const racine = path.resolve(__dirname, '../..');
const FICHIERS = ['/style.css', '/plateau-informateurs.js', '/plateau-criminalite.js'];

const ICI_BAR = { ok: true, pays: 'republic', ville: 'capitale', batiment: 'hotel-republica', piece: 'bar',
  bareme: { devise: 'FR', min: 20, max: 50, paliers: [{ palier: 'flou', min: 20, max: 29 }, { palier: 'correct', min: 30, max: 44 }, { palier: 'premier_choix', min: 45, max: 50 }] },
  informateurs: [{ id: 'm', nom: 'Marco (Barman)', role: 'PNJ - Barman', profil: 'generaliste', sujet: null },
                 { id: 'l', nom: 'Marc Hantile', role: 'Lobbyiste', profil: 'sujet', sujet: 'politique' }] };

async function avecPage(fn) {
  const page0 = '<!doctype html><meta charset="utf-8"><link rel="stylesheet" href="/style.css">'
    + '<div id="modal-pnj" class="modal-overlay open"><div id="pnj-actions"><div id="pnj-informateur-zone" data-pnj="Marco (Barman)"></div></div></div>'
    + '<div id="modal-postes" class="modal-overlay"><div class="modal-box"><div id="postes-modal-title"></div><div id="postes-body"></div></div></div>'
    + '<script>let state={char:{name:"Tom"},country:"republic",currentCity:"capitale",currentBuilding:"hotel-republica",currentRoom:"bar"};'
    + 'var BUILDINGS={"hotel-republica":{rooms:{bar:{name:"Bar"},salle:{name:"Salle"}}}};</script>'
    + FICHIERS.filter(f => f.endsWith('.js')).map(f => '<script src="' + f + '"></script>').join('');
  const serveur = http.createServer((req, res) => {
    const url = decodeURIComponent(req.url.split('?')[0]);
    if (url === '/') { res.setHeader('Content-Type', 'text/html; charset=utf-8'); res.end(page0); return; }
    if (!FICHIERS.includes(url)) { res.writeHead(404); res.end(); return; }
    res.setHeader('Content-Type', url.endsWith('.js') ? 'text/javascript' : 'text/css'); res.end(fs.readFileSync(path.join(racine, url.slice(1))));
  });
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'hg-informateurs-')); let nav, browser;
  try {
    await new Promise((r, j) => { serveur.once('error', j); serveur.listen(0, '127.0.0.1', r); });
    nav = await lancerChromium({ executable: process.env.HG_CHROMIUM || ['/usr/bin/chromium', '/usr/bin/google-chrome', '/usr/bin/google-chrome-stable'].find(p => fs.existsSync(p)), profil });
    browser = await chromium.connectOverCDP('http://127.0.0.1:' + nav.port);
    const page = await browser.contexts()[0].newPage(); await page.setViewportSize({ width: 1000, height: 800 });
    const erreurs = []; page.on('pageerror', e => erreurs.push(String(e)));
    await page.goto('http://127.0.0.1:' + serveur.address().port);
    await page.waitForFunction(() => typeof window.ouvrirInformateursIci === 'function' && typeof window.crimOuvrirEnquetes === 'function');
    await page.evaluate((ici) => {
      window.__ici = ici; window.__appels = []; window.__toasts = []; window.__journal = []; window.__rendus = 0; window.__paie = null;
      window.showToast = (a, b, ok) => window.__toasts.push([a, b, !!ok]);
      window.addJournalEntry = (t) => window.__journal.push(t);
      window.renderRoomActions = () => { window.__rendus++; };
      window.appliquerPaiementServeur = (p) => { window.__paie = p; };
      window.sbRpc = async (fn, p) => { window.__appels.push([fn, p]);
        if (fn === 'informateurs_ici') return window.__ici;
        if (fn === 'crim_enquetes_lire') return { ok: true, pa: 2, affaires: [{ affaire: 7, acte: 'voler', victime: 'Ana', jour: 3, issue: 'reussite', masque: false, indices: {}, pistes: { trace: true }, chances: 40, tentatives: 0 }] };
        if (fn === 'crim_informateur_payer') return window.__crimReponse;
        return null; };
      window.sbRpcVerdict = async (fn, p) => { window.__appels.push([fn, p]); return window.__reponse; };
    }, ICI_BAR);
    await fn(page);
    assert.deepEqual(erreurs, []);
  } finally {
    if (browser) await browser.close(); if (nav) await nav.arreter();
    serveur.closeAllConnections(); await new Promise(r => serveur.close(r)); fs.rmSync(profil, { recursive: true, force: true });
  }
}

test('bouton « Acheter une information » sur la fiche du PNJ : seulement si le serveur le dit informateur ici', async () => {
  await avecPage(async (page) => {
    assert.equal(await page.evaluate(() => typeof window.ordresInformateurs), 'undefined', 'plus d’ordre de pièce (point 24)');
    assert.equal(await page.evaluate(() => (window.RP_ORDRES_DYNAMIQUES || []).flatMap(f => f('hotel-republica', 'bar', 'capitale') || [])
      .filter(o => o.fn === 'informateur_payer').length), 0, 'aucune source d’ordres ne propose plus l’achat');
    await page.evaluate(() => window.informateursBoutonPnj({ name: 'Marco (Barman) (PNJ)', role: 'PNJ - Barman' }));
    assert.equal((await page.locator('#pnj-informateur-zone button').innerText()).trim(), 'Acheter une information');
    // PNJ qui n'est pas informateur : zone vide.
    await page.evaluate(() => { document.getElementById('pnj-informateur-zone').dataset.pnj = 'Gaston'; return window.informateursBoutonPnj({ name: 'Gaston (PNJ)' }); });
    assert.equal(await page.locator('#pnj-informateur-zone button').count(), 0);
    // Un joueur n'est jamais informateur.
    assert.equal(await page.evaluate(() => window.informateurDuPnj({ name: 'Marco (Barman)', isPJ: true }, window.__ici)), null);
    // Renommé côté écran, ancien nom au serveur : `aliasInformateur` fait le lien.
    assert.equal(await page.evaluate(() => window.informateurDuPnj({ name: 'Marc Lenouveau (PNJ)', aliasInformateur: 'Marc Hantile' }, window.__ici).id), 'l');
    // Clic : la fiche se ferme, la fenêtre de cet informateur seul s'ouvre (R8).
    await page.evaluate(() => { document.getElementById('pnj-informateur-zone').dataset.pnj = 'Marco (Barman)'; return window.informateursBoutonPnj({ name: 'Marco (Barman) (PNJ)' }); });
    await page.click('#pnj-informateur-zone button');
    await page.waitForSelector('#info-payer-0');
    assert.equal(await page.locator('#modal-pnj.open').count(), 0, 'jamais deux fenêtres superposées');
    assert.equal(await page.locator('#modal-postes.open').count(), 1);
    assert.equal(await page.locator('#postes-modal-title').innerText(), 'Acheter une information');
    const txt = await page.locator('#postes-body').innerText();
    assert.match(txt, /Marco \(Barman\)/); assert.doesNotMatch(txt, /Marc Hantile/);
  });
});

test('fenêtre : qui, ce qu’il sait, barème ; bouton grisé hors barème ; paiement ; réponse en texte ; refus nommé', async () => {
  await avecPage(async (page) => {
    await page.evaluate(() => window.ouvrirInformateursIci());
    await page.waitForSelector('#info-payer-1');
    const txt = await page.locator('#postes-body').innerText();
    assert.match(txt, /À qui voulez-vous parler \?/);
    assert.match(txt, /Marco \(Barman\)/); assert.match(txt, /Il entend tout, sur toute la ville/);
    assert.match(txt, /Marc Hantile/); assert.match(txt, /coulisses de la politique/);
    assert.match(txt, /De 20 à 50 FR/); assert.match(txt, /45 à 50 FR — Premier choix/); assert.match(txt, /L’argent versé est perdu/);
    assert.equal(await page.locator('#modal-postes.open').count(), 1);
    assert.equal(await page.locator('#info-payer-0').innerText(), 'Payer 30 FR');
    assert.equal(await page.locator('#info-palier-0').innerText(), 'Correct : une vraie information');
    await page.fill('#info-montant-0', '19');
    assert.equal(await page.locator('#info-payer-0').isDisabled(), true, 'jamais un formulaire impossible à envoyer');
    assert.match(await page.locator('#info-palier-0').innerText(), /entre 20 et 50 FR/);
    await page.fill('#info-montant-0', '45');
    assert.equal(await page.locator('#info-payer-0').innerText(), 'Payer 45 FR');
    // Refus du serveur : nommé, fenêtre gardée.
    await page.evaluate(() => { window.__reponse = { ok: false, raison: 'fonds_insuffisants' }; });
    await page.click('#info-payer-0');
    await page.waitForFunction(() => window.__toasts.length > 0);
    assert.deepEqual(await page.evaluate(() => window.__toasts[0]), ['Impossible', 'Vous n’avez pas assez d’argent.', false]);
    assert.equal(await page.locator('#info-payer-0').isDisabled(), false);
    // Succès : réponse du serveur affichée comme du texte.
    await page.evaluate(() => { window.__reponse = { ok: true, informateur: { id: 'm', nom: 'Marco (Barman)' }, montant: 45, devise: 'FR', palier: 'premier_choix',
      lignes: ['« Le plus gros, en ce moment ? quelqu’un a été assassiné. Quelqu’un — habite Montrouge. »', '<img src=x onerror="window.__xss=1">'],
      paie: { pa: 10, liquide: 55, arg: 55 } }; });
    await page.click('#info-payer-0');
    await page.waitForSelector('#info-reponse');
    const appel = await page.evaluate(() => window.__appels.filter(a => a[0] === 'informateur_payer').pop()[1]);
    assert.equal(appel.p_informateur, 'm'); assert.equal(appel.p_montant, 45); assert.match(appel.p_requete, /^[0-9a-f-]{36}$/);
    assert.equal(await page.locator('#postes-modal-title').innerText(), 'Marco (Barman) vous glisse à l’oreille…');
    assert.match(await page.locator('#info-reponse').innerText(), /assassiné/);
    assert.equal(await page.locator('#info-reponse img').count(), 0); assert.equal(await page.evaluate(() => window.__xss), undefined);
    assert.match(await page.locator('#postes-body').innerText(), /Vous avez donné 45 FR \(Premier choix/);
    assert.deepEqual(await page.evaluate(() => window.__paie), { pa: 10, liquide: 55, arg: 55 });
    assert.match(await page.evaluate(() => window.__journal[0]), /Information achetée à Marco \(Barman\) \(−45 FR\)/);
    assert.equal(await page.locator('#postes-body button').count(), 2, 'une issue : payer encore ou fermer');
  });
});

test('habitué du Bar Sever : « Lui offrir un verre », sa fenêtre ne montre que lui', async () => {
  await avecPage(async (page) => {
    await page.evaluate(() => { window.__ici = { ok: true, pays: 'soviet', ville: 'ville_b', batiment: 'cafe-tabac-cheminots-montrouge', piece: 'salle',
      bareme: { devise: 'PSK', min: 7, max: 20, paliers: [{ palier: 'flou', min: 7, max: 11 }, { palier: 'correct', min: 12, max: 17 }, { palier: 'premier_choix', min: 18, max: 20 }] },
      informateurs: [{ id: 'g', nom: 'Grigori Zaitsev', profil: 'generaliste' }, { id: 'habitue_krasnov', nom: 'L’habitué du Bar Sever', profil: 'generaliste' }] };
      Object.assign(state, { country: 'soviet', currentCity: 'ville_b', currentBuilding: 'cafe-tabac-cheminots-montrouge', currentRoom: 'salle' });
      window.ouvrirInformateursIci('habitue_krasnov'); });
    await page.waitForSelector('#info-payer-0');
    const txt = await page.locator('#postes-body').innerText();
    assert.match(txt, /L’habitué du Bar Sever/); assert.doesNotMatch(txt, /Grigori/);
    assert.equal(await page.locator('#info-payer-0').innerText(), 'Payer 12 PSK');
    assert.equal(await page.locator('#postes-modal-title').innerText(), 'Lui offrir un verre');
    assert.match(txt, /Offrez-lui un verre, de 7 à 20 PSK/);
    // Sur sa fiche : « Lui offrir un verre » (point 25), reconnu par son identifiant de fiche.
    await page.evaluate(() => { document.getElementById('pnj-informateur-zone').dataset.pnj = 'L’habitué du Bar Sever';
      return window.informateursBoutonPnj({ name: 'L’habitué du Bar Sever (PNJ)', profilId: 'habitue_krasnov' }); });
    assert.equal((await page.locator('#pnj-informateur-zone button').innerText()).trim(), 'Lui offrir un verre');
    assert.equal(await page.locator('#pnj-informateur-zone button').getAttribute('data-informateur'), 'habitue_krasnov');
  });
});

test('pièce vide : la fenêtre le dit et propose de fermer', async () => {
  await avecPage(async (page) => {
    await page.evaluate(() => { window.__ici = Object.assign({}, window.__ici, { informateurs: [] }); window.ouvrirInformateursIci(); });
    await page.waitForFunction(() => /Personne ici ne vend/.test(document.getElementById('postes-body').innerText));
    await page.click('#postes-body button');
    assert.equal(await page.locator('#modal-postes.open').count(), 0);
  });
});

test('commissaire : payer un informateur sur une plainte contre X, caisse ou fonds propres, bouton grisé hors barème', async () => {
  await avecPage(async (page) => {
    await page.evaluate(() => window.crimOuvrirEnquetes());
    await page.waitForSelector('#crim-info-btn-7');
    assert.match(await page.locator('#postes-body').innerText(), /La caisse du commissariat paie d’abord/);
    assert.equal(await page.locator('#crim-info-btn-7').innerText(), 'Payer 30 FR');
    await page.fill('#crim-info-7', '60');
    assert.equal(await page.locator('#crim-info-btn-7').isDisabled(), true);
    await page.fill('#crim-info-7', '20');
    assert.match(await page.locator('#crim-info-note-7').innerText(), /flou \(bonus divisé par deux\)/);
    await page.evaluate(() => { window.__crimReponse = { ok: true, affaire: 7, palier: 'flou', montant: 20, source: 'caisse', devise: 'FR', ligne: '« Une affaire ? »', taux: 45 }; });
    await page.click('#crim-info-btn-7');
    await page.waitForFunction(() => window.__toasts.some(t => t[0] === 'Informateur payé'));
    const t = await page.evaluate(() => window.__toasts.find(x => x[0] === 'Informateur payé'));
    assert.match(t[1], /20 FR pris sur la caisse du commissariat\. Chances d’identification : 45 %/);
    const appel = await page.evaluate(() => window.__appels.filter(a => a[0] === 'crim_informateur_payer').pop()[1]);
    assert.equal(appel.p_affaire, 7); assert.equal(appel.p_montant, 20);
  });
});
