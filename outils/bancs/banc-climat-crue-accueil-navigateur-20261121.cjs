// Chromium réel : décisions climat de Fred du 21/11/2026 (GAME-DESIGN-CLIMAT-20261121.md).
// Vue de rue factice (scène, flèche, zones de bâtiments) + vrai plateau-climat.js ; serveur simulé (sbRpc).
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), os = require('node:os'), http = require('node:http');
const { chromium } = require('../e2e/node_modules/playwright');
const { lancerChromium } = require('./fixtures/chromium-cdp.cjs');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');

const PAGE = '<!doctype html><meta charset="utf-8"><body><div id="rue-image" style="position:relative;width:800px;height:450px">'
  + '<div id="rue-centrale-conteneur"><div class="rc-scene" id="rc-scene" style="position:relative;width:800px;height:450px">'
  + '<div class="rc-fleche" id="fleche" style="left:10px;top:200px;width:40px;height:40px" onclick="window.__deplace=(window.__deplace||0)+1"></div>'
  + '<div class="rc-zone" id="z-marche" data-building="marche-psm" style="position:absolute;left:100px;top:100px;width:120px;height:120px"></div>'
  + '<div class="rc-zone" id="z-gare" data-building="psm-centre-multimodal" style="position:absolute;left:300px;top:100px;width:120px;height:120px"></div>'
  + '<div class="rc-zone" id="z-port" data-building="port-sainte-marie" style="position:absolute;left:500px;top:100px;width:120px;height:120px"></div>'
  + '</div></div></div><div id="rue-actions-row"><button class="action-btn legal" id="fouiller">Fouiller ou voler</button></div>'
  + '<div id="modal-postes"><div id="postes-modal-title"></div><div id="postes-body"></div></div></body>';

const CONSIGNE = 'Pendant 6 heures, les commerces et entrepôts non protégés de la zone inondable sont fermés et perdent 20 % de leurs stocks, et les chantiers sont à l’arrêt.';
async function avecPage(fn, { maintenant, creationRecente = true, ville = 'ville_a', pays = 'republic', type = 'crue' } = {}) {
  const serveur = http.createServer((req, res) => {
    // Le renderer masque une image non décodable : servir la vraie photo, pas le HTML de PAGE.
    const photo = 'images/Sovarka/Krasnov/Krasnov_place_ours_fontaine.webp';
    if (req.url.split('?')[0] === '/' + photo) {
      res.setHeader('Content-Type', 'image/webp'); res.end(fs.readFileSync(path.join(root, photo))); return;
    }
    res.setHeader('Content-Type', 'text/html; charset=utf-8'); res.end(PAGE);
  });
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'hg-climat-crue-')); let nav, browser;
  try {
    await new Promise((r, j) => { serveur.once('error', j); serveur.listen(0, '127.0.0.1', r); });
    nav = await lancerChromium({ executable: process.env.HG_CHROMIUM || ['/usr/bin/chromium', '/usr/bin/google-chrome', '/usr/bin/google-chrome-stable'].find(p => require('node:fs').existsSync(p)), profil });
    browser = await chromium.connectOverCDP('http://127.0.0.1:' + nav.port);
    const page = await browser.contexts()[0].newPage(); await page.setViewportSize({ width: 1000, height: 700 });
    await page.goto('http://127.0.0.1:' + serveur.address().port);
    const t0 = maintenant || Date.now();
    await page.addScriptTag({ content: `
      var rueCentraleNoeudActuel = 'krasnov-place-ours';
      var state = { country: '${pays}', currentCity: '${ville}', currentBuilding: null, currentRoom: null, char: { name: 'Banc' } };
      window.__toasts = []; window.__vus = []; window.__entrees = 0;
      window.showToast = (t, c) => window.__toasts.push([t, c]);
      const crue = { id: 77, type: '${type}', ville: 'ville_a', debut: new Date(${t0} - 3600e3).toISOString(), fin: new Date(${t0} + 5 * 3600e3 + 20 * 60e3).toISOString(), lieux: ['marche-psm'], lieux_proteges: ['port-sainte-marie'], consigne: ${JSON.stringify(CONSIGNE)}, en_cours: true };
      window.__eau = 0;
      window.__crue = crue;
      window.sbRpc = async (fn, p) => {
        if (fn === 'climat_etat') return { ok: true, evenements: [crue] };
        if (fn === 'climat_effets_lire') return { ok: true };
        if (fn === 'climat_accueil_lire') return { ok: true, evenement: (${creationRecente} && !window.__vus.includes(77)) ? crue : null };
        if (fn === 'climat_accueil_vu') { window.__vus.push(p.p_evenement); return { ok: true }; }
        if (fn === 'climat_points_eau_lister') return { ok: true, points: [{ id: 'krasnov-fontaine-ours', pays: 'soviet', ville: 'ville_b', noeud: 'krasnov-place-ours', nom: 'la fontaine de la statue de l’Ours, place de l’Ours' }] };
        if (fn === 'point_eau_etat') return { ok: true, point: { id: 'krasnov-fontaine-ours', image: 'images/Sovarka/Krasnov/Krasnov_place_ours_fontaine.webp' },
          max_tranche: 10, deja: window.__eau, restant: 10 - window.__eau, place: window.__place ?? 100, pa: 5, heure_fin: 12 };
        if (fn === 'point_eau_puiser') { window.__puisages = (window.__puisages || []).concat(p.p_quantite); const n = Math.min(p.p_quantite, 10 - window.__eau); window.__eau += n;
          return { ok: true, quantite: n, restant: 10 - window.__eau, pa: 4, inventory: [{ name: 'Bouteille d’eau', stackKey: 'bouteille_eau', qty: window.__eau }] }; }
        return null;
      };
      document.getElementById('z-marche').addEventListener('click', () => window.__entrees++);
      document.getElementById('z-gare').addEventListener('click', () => window.__entrees++);
      document.getElementById('z-port').addEventListener('click', () => window.__entrees++);
    ` });
    await page.addScriptTag({ content: lire('plateau-climat.js') });
    await fn(page);
  } finally {
    if (browser) await browser.close(); if (nav) await nav.arreter(); serveur.closeAllConnections(); await new Promise(r => serveur.close(r)); fs.rmSync(profil, { recursive: true, force: true });
  }
}

test('nouveau personnage pendant une crue : fenêtre d’accueil complète, une seule fois', async () => {
  await avecPage(async page => {
    await page.evaluate(() => window.RPClimat.rafraichirClimat());
    const d = page.locator('#climat-explication');
    await d.waitFor();
    const txt = await d.innerText();
    assert.match(txt, /Bienvenue à Port-Sainte-Marie/);
    assert.match(txt, /Un événement climatique frappe la ville en ce moment \(crue\)/, 'phrase d’accueil bienveillante');
    // Même fenêtre que l'alerte : la durée restante, puis la consigne.
    assert.ok(txt.indexOf('Encore 5 h') < txt.indexOf('Pendant 6 heures'), 'durée restante avant la consigne');
    assert.match(txt, /Encore 5 h 2\d min/, 'durée restante');
    assert.match(txt, /Lieux fermés : /);
    assert.match(txt, /Protégés par des sacs de sable, donc ouverts : port-sainte-marie/);
    assert.match(txt, /Pendant 6 heures, les commerces et entrepôts non protégés/);
    assert.equal(await page.locator('#climat-gouvernement').count(), 0, 'pas de doublon avec le message du gouvernement');
    await d.locator('button').click();
    await page.waitForFunction(() => window.__vus.includes(77));
    await page.evaluate(() => window.RPClimat.rafraichirClimat());
    await page.waitForTimeout(150);
    assert.equal(await page.locator('#climat-explication').count(), 0, 'affichée une seule fois par événement');
  });
});

test('personnage ancien : aucune fenêtre d’accueil', async () => {
  await avecPage(async page => {
    await page.evaluate(() => window.RPClimat.rafraichirClimat());
    await page.waitForTimeout(150);
    assert.equal(await page.locator('#climat-explication').count(), 0);
  }, { creationRecente: false });
});

test('crue : on circule, la gare reste ouverte, le lieu touché est fermé avec un message clair', async () => {
  await avecPage(async page => {
    await page.evaluate(async () => { await window.RPClimat.rafraichirClimat(); document.getElementById('climat-explication')?.remove(); document.getElementById('climat-gouvernement')?.remove(); window.RPClimat.appliquerFiltre(); });
    // Marque sur le seul lieu touché, expliquée au survol.
    assert.equal(await page.locator('#z-marche.climat-inonde').count(), 1);
    assert.equal(await page.locator('#z-gare.climat-inonde').count(), 0, 'la gare n’est jamais marquée');
    assert.equal(await page.locator('#z-port.climat-inonde').count(), 0, 'le lieu protégé par des sacs reste ouvert');
    assert.match(await page.locator('#z-marche').getAttribute('title'), /Fermé \(crue\) : .*réouverture dans 5 h/);
    // Déplacement : la flèche reste au-dessus du filtre et cliquable.
    await page.locator('#fleche').click();
    assert.equal(await page.evaluate(() => window.__deplace), 1);
    // Entrée dans la gare : permise ; entrée dans le lieu inondé : bloquée, message (cause, durée, que faire).
    await page.locator('#z-gare').click();
    assert.equal(await page.evaluate(() => window.__entrees), 1);
    await page.locator('#z-port').click();
    assert.equal(await page.evaluate(() => window.__entrees), 2, 'lieu protégé : on entre');
    await page.locator('#z-marche').click();
    assert.equal(await page.evaluate(() => window.__entrees), 2, 'entrée bloquée');
    const [titre, corps] = await page.evaluate(() => window.__toasts.at(-1));
    assert.equal(titre, 'Lieu fermé : crue');
    assert.match(corps, /fermé à cause de la crue/);
    assert.match(corps, /rouvre dans 5 h/);
    assert.match(corps, /gare et trains restent ouverts/);
    // Refus du serveur (autre chemin d'entrée) : même message clair.
    await page.evaluate(() => window.showToast('Déplacement refusé', 'batiment_inonde'));
    assert.match(await page.evaluate(() => window.__toasts.at(-1)[1]), /fermé à cause de la crue.*rouvre dans/);
  });
});

test('le bandeau « Attention crue » s’explique au clic ; tout disparaît à l’heure de fin', async () => {
  await avecPage(async page => {
    await page.evaluate(async () => { await window.RPClimat.rafraichirClimat(); document.getElementById('climat-explication')?.remove(); window.RPClimat.appliquerFiltre(); });
    // Pictogramme : triangle jaune, trait noir, texte dessous ; clignotement lent ; flèche au-dessus du filtre.
    const alerte = page.locator('#climat-alerte');
    assert.equal(await alerte.locator('svg.climat-picto path[fill="#FFD200"]').count(), 1);
    assert.match(await alerte.locator('.climat-alerte-texte').textContent(), /^Attention : crue$/);
    // Le pictogramme clignote lentement ; le texte du bandeau reste toujours pleinement lisible (22/11/2026).
    assert.match(await alerte.locator('svg.climat-picto').evaluate(el => getComputedStyle(el).animationName), /climatAlerte/);
    assert.equal(await alerte.evaluate(el => getComputedStyle(el).animationName), 'none');
    assert.ok(Number(await page.locator('#fleche').evaluate(el => getComputedStyle(el).zIndex)) > Number(await page.locator('#climat-filtre').evaluate(el => getComputedStyle(el).zIndex)));
    await alerte.click();
    const txt = await page.locator('#climat-explication').innerText();
    assert.match(txt, /Crue/); assert.match(txt, /Encore 5 h/); assert.match(txt, /Consignes/i); assert.match(txt, /Pendant 6 heures/);
    await page.locator('#climat-explication button').click();
    // Fin de l'événement (12 heures) : le client le lit lui-même, sans attendre le serveur.
    await page.evaluate(() => { window.__crue.fin = new Date(Date.now() - 1000).toISOString(); window.RPClimat.appliquerFiltre(); });
    assert.equal(await page.locator('#climat-filtre').count(), 0);
    assert.equal(await page.locator('#climat-alerte').count(), 0);
    assert.equal(await page.locator('.climat-inonde').count(), 0);
  });
});

test('point d’eau : ordre vert « Puiser de l’eau » dans la liste des ordres de la place, fenêtre illustrée et pédagogique', async () => {
  await avecPage(async page => {
    await page.evaluate(() => window.RPClimat.appliquerFiltre());
    await page.waitForFunction(() => window.RPClimat._pointsEau());
    await page.evaluate(() => window.RPClimat.appliquerFiltre());
    // Plus rien sur l'image : l'ordre est le premier de la rangée des ordres, en vert (classe « legal »).
    assert.equal(await page.locator('#rc-scene button').count(), 0);
    const b = page.locator('#rue-actions-row #rue-ordre-puiser');
    assert.match(await b.innerText(), /Puiser de l’eau \(1 PA\)/);
    assert.equal(await b.getAttribute('class'), 'action-btn legal');
    assert.equal(await page.evaluate(() => document.getElementById('rue-actions-row').firstElementChild.id), 'rue-ordre-puiser');
    await b.click();
    const corps = page.locator('#postes-body');
    await corps.locator('img').waitFor();
    await page.waitForFunction(() => document.querySelector('#postes-body img').naturalWidth > 0);
    const txt = await corps.innerText();
    assert.match(txt, /Fontaine de la statue de l’Ours\. L’eau est gratuite\. Puiser coûte 1 PA, quelle que soit la quantité\. Vous pouvez puiser jusqu’à 10 bouteilles toutes les 6 heures\./);
    assert.match(txt, /Vous pouvez encore puiser 10 bouteilles avant 12 h 00\./);
    await page.fill('#puiser-qte', '5');
    await page.click('#puiser-valider');
    await page.waitForFunction(() => window.__eau === 5);
    assert.match((await page.evaluate(() => window.__toasts.at(-1)))[1], /^Vous avez puisé 5 bouteilles d’eau \(−1 PA\)\. Elles sont dans votre inventaire\.$/);
    await page.waitForFunction(() => /encore puiser 5 bouteilles/.test(document.getElementById('postes-body').innerText));
    // Inventaire limitant : la phrase s'ajoute ; plafond atteint : bouton désactivé et explication.
    await page.evaluate(() => { window.__place = 3; });
    await page.evaluate(() => window.RPClimat.ouvrirPuiserEau());
    await page.waitForFunction(() => /ne peut accueillir que 3 bouteilles de plus/.test(document.getElementById('postes-body').innerText));
    assert.equal(await page.inputValue('#puiser-qte'), '3');
    await page.evaluate(() => { window.__place = 100; window.__eau = 10; });
    await page.evaluate(() => window.RPClimat.ouvrirPuiserEau());
    await page.waitForFunction(() => /déjà puisé vos 10 bouteilles pour cette période\. La fontaine sera de nouveau à vous à 12 h 00\. Astuce : le marché vend de l’eau déjà puisée, sans dépense de PA\./.test(document.getElementById('postes-body').innerText));
    assert.equal(await page.locator('#puiser-valider').isDisabled(), true);
    await page.evaluate(() => { window.__eau = 0; window.__place = 0; });
    await page.evaluate(() => window.RPClimat.ouvrirPuiserEau());
    await page.waitForFunction(() => /Votre inventaire est plein : faites de la place pour puiser de l’eau\./.test(document.getElementById('postes-body').innerText));
    assert.equal(await page.locator('#puiser-valider').isDisabled(), true);
    // Ailleurs dans la ville : pas d'ordre.
    await page.evaluate(() => { rueCentraleNoeudActuel = 'krasnov-rue-mairie-place'; window.RPClimat.appliquerFiltre(); });
    assert.equal(await page.locator('#rue-ordre-puiser').count(), 0);
  }, { ville: 'ville_b', pays: 'soviet' });
});

test('orage : pluie animée en continu, légère obliquité, sans redessin ; immobile si l’animation est réduite', async () => {
  await avecPage(async page => {
    await page.evaluate(async () => { await window.RPClimat.rafraichirClimat(); document.getElementById('climat-explication')?.remove(); document.getElementById('climat-gouvernement')?.remove(); window.RPClimat.appliquerFiltre(); });
    const pluie = sel => page.evaluate(s => { const c = getComputedStyle(document.getElementById('climat-filtre'), s); return { nom: c.animationName, duree: c.animationDuration, rotate: c.rotate, transform: c.transform, image: c.backgroundImage.slice(0, 30) }; }, sel);
    const avant = await pluie('::before'), apres = await pluie('::after');
    assert.equal(avant.nom, 'climatPluieProche'); assert.equal(apres.nom, 'climatPluieLointaine');
    assert.equal(avant.duree, '1.1s'); assert.equal(avant.rotate, '12deg');
    assert.match(avant.image, /^url\("data:image\/svg\+xml/);
    // La pluie tombe réellement : la position de la nappe change d'un instant à l'autre.
    const t1 = (await pluie('::before')).transform; await page.waitForTimeout(250); const t2 = (await pluie('::before')).transform;
    assert.notEqual(t1, t2, 'animation en cours');
    // Navigation intacte : flèche au-dessus du filtre et cliquable.
    await page.locator('#fleche').click();
    assert.equal(await page.evaluate(() => window.__deplace), 1);
    // Réduction des animations demandée par le système : la pluie reste visible mais ne bouge plus.
    await page.emulateMedia({ reducedMotion: 'reduce' });
    assert.equal((await pluie('::before')).nom, 'none');
    assert.equal((await pluie('::after')).nom, 'none');
    assert.equal(await page.evaluate(() => getComputedStyle(document.querySelector('#climat-alerte .climat-picto')).animationName), 'none');
  }, { type: 'orage' });
});
