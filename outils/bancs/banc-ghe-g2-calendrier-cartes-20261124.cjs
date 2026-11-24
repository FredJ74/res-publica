'use strict';
// Mission « Purge » (Fred, 24/11/2026), point G.2 : calendrier électoral en cartes simples.
//   • l'étape en cours sur une ligne, en gros ; frise Candidatures → Campagne → Vote → Résultats, dates courtes, candidats ;
//   • la règle générale dans la bulle « ? » (deux phrases, survol ET toucher) ;
//   • les heures exactes et le second tour derrière un bouton « Détails » (fermé au départ) ;
//   • aucune couleur en dur dans le rendu ; lisible à 390 px sans défilement horizontal, texte jamais sous 0,9 rem.
// Vrais data.js, plateau-politique.js et style.css ; cycles et serveur simulés. Chromium réel pour le rendu (HG_CHROMIUM).
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), os = require('node:os'), http = require('node:http');
const racine = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(racine, f), 'utf8');

test('G.2 — le rendu du calendrier n’écrit plus de couleur en dur et garde les règles du jeu', () => {
  const s = lire('plateau-politique.js');
  const i = s.indexOf('CALENDRIER EN CARTES SIMPLES'), j = s.indexOf('// SE PORTER CANDIDAT : LE PROGRAMME D');
  assert.ok(i > 0 && j > i);
  const bloc = s.slice(i, j);
  assert.doesNotMatch(bloc, /#[0-9a-fA-F]{3,6}\b/, 'couleur en dur dans le calendrier');
  assert.doesNotMatch(bloc, /min-width:540px/);
  assert.match(bloc, /candidaturesOuvertes\(cycle\)/, 'même condition de candidature que le serveur');
  assert.match(bloc, /candidaturePossibleIci\(p\.id, country, city\)/);
  assert.match(bloc, /ouvrirBureauDeVoteBtn\(this\)/, 'le bureau de vote reste accessible (dans Détails)');
  const css = lire('style.css');
  for (const c of ['.hg-cal-carte', '.hg-cal-etape', '.hg-cal-frise', '.hg-cal-actuelle', '.hg-cal-details[hidden]', '.hg-aide-rond']) assert.ok(css.includes(c), c);
});

const { chromium } = (() => { try { return require('../e2e/node_modules/playwright'); } catch (_) { return {}; } })();
const exe = process.env.HG_CHROMIUM || ['/usr/bin/chromium', '/usr/bin/google-chrome', '/usr/bin/google-chrome-stable'].find(p => fs.existsSync(p));
test('G.2 — cartes, frise, bulle « ? » et Détails dans Chromium (1280 et 390 px)', { skip: (!chromium || !exe) && 'Chromium absent' }, async () => {
  const { lancerChromium } = require('./fixtures/chromium-cdp.cjs');
  const FICHIERS = ['/style.css', '/data.js', '/plateau-politique.js'];
  const page0 = '<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><link rel="stylesheet" href="/style.css">'
    + '<div class="modal" id="modal-postes"><div class="modal-box"><h2 id="postes-modal-title"></h2><div id="postes-body"></div></div></div>'
    + '<script>window.showToast=()=>{};</script><script src="/data.js"></script><script src="/plateau-politique.js"></script>';
  const serveur = http.createServer((req, res) => {
    const url = decodeURIComponent(req.url.split('?')[0]);
    if (url === '/') { res.setHeader('Content-Type', 'text/html; charset=utf-8'); res.end(page0); return; }
    if (!FICHIERS.includes(url)) { res.writeHead(404); res.end(); return; }
    res.setHeader('Content-Type', url.endsWith('.js') ? 'text/javascript' : 'text/css'); res.end(fs.readFileSync(path.join(racine, url.slice(1))));
  });
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'hg-cal-')); let nav, browser;
  try {
    await new Promise((r, j) => { serveur.once('error', j); serveur.listen(0, '127.0.0.1', r); });
    nav = await lancerChromium({ executable: exe, profil });
    browser = await chromium.connectOverCDP('http://127.0.0.1:' + nav.port);
    const page = await browser.contexts()[0].newPage();
    for (const largeur of [1280, 390]) {
      await page.setViewportSize({ width: largeur, height: 860 });
      await page.goto('http://127.0.0.1:' + serveur.address().port);
      await page.waitForFunction(() => typeof ouvrirCalendrierElectoral === 'function');
      await page.evaluate(async () => {
        const j = 864e5, t = Date.now();
        const base = { tour: 1, eluId: null, candidats: [{ nom: 'Tom Tom', topicId: 't1' }, { nom: 'Arnie' }],
          dateDebutCandidatures: t - 20 * j, dateDebutCampagne: t - j, dateVote: t + 5 * j, dateResultats: t + 6 * j, dateFinMandat: t + 6 * j };
        state = { country: 'republic', currentCity: 'capitale', char: { name: 'Banc' } };
        CYCLES_ELECTORAUX.republic = { president: { ...base }, maire_capitale: { ...base } };
        syncCyclesDepuisSupabase = async () => {}; initCycleElectoral = async () => {};
        await ouvrirCalendrierElectoral();
      });
      const r = await page.evaluate(() => {
        const carte = document.querySelector('.hg-cal-carte');
        const etape = carte.querySelector('.hg-cal-etape');
        const cases = [...carte.querySelectorAll('.hg-cal-case')];
        const details = carte.querySelector('.hg-cal-details');
        const tailles = [...document.querySelectorAll('#postes-body *')].filter(e => e.childNodes.length && [...e.childNodes].some(n => n.nodeType === 3 && n.textContent.trim()))
          .map(e => parseFloat(getComputedStyle(e).fontSize));
        window.__petits = [...document.querySelectorAll('#postes-body *')].filter(e => parseFloat(getComputedStyle(e).fontSize) < 14 && e.childNodes.length).map(e => e.className + ':' + e.tagName + ':' + getComputedStyle(e).fontSize);
        return { etape: etape.textContent, etapePx: parseFloat(getComputedStyle(etape).fontSize), cases: cases.map(c => c.textContent),
          actuelle: cases.findIndex(c => c.classList.contains('hg-cal-actuelle')), candidats: carte.querySelector('.hg-cal-candidats').textContent,
          detailsCache: details.hidden, detailsTexte: details.textContent, min: Math.min(...tailles),
          debord: document.documentElement.scrollWidth > window.innerWidth, rond: !!document.querySelector('.hg-cal-entete .hg-aide-rond') };
      });
      assert.equal(r.etape, 'Campagne', largeur + ' : étape en cours');
      assert.ok(r.etapePx >= 20, 'étape en gros : ' + r.etapePx);
      assert.deepEqual(r.cases.map(c => c.replace(/\d.*$/, '').trim()), ['Candidatures', 'Campagne', 'Vote', 'Résultats']);
      assert.ok(r.cases.every(c => /\d/.test(c)), 'dates courtes : ' + r.cases.join(' | '));
      assert.equal(r.actuelle, 1);
      assert.match(r.candidats, /Tom Tom.*Arnie/);
      assert.equal(r.detailsCache, true, 'Détails fermé au départ');
      assert.match(r.detailsTexte, /Second tour éventuel/);
      assert.match(r.detailsTexte, / à \d\d:\d\d/, 'heures exactes dans Détails');
      assert.ok(r.min >= 14, 'texte trop petit : ' + r.min + ' px ' + JSON.stringify(await page.evaluate(() => window.__petits)));
      assert.equal(r.debord, false, largeur + ' : défilement horizontal');
      assert.ok(r.rond, 'rond « ? »');
      if (process.env.G2_CAPTURE) await page.screenshot({ path: path.join(process.env.G2_CAPTURE, 'cal-' + largeur + '.png'), fullPage: true });
      // Détails s'ouvre et se referme.
      await page.click('.hg-cal-carte .hg-cal-bouton-details');
      assert.equal(await page.evaluate(() => document.querySelector('.hg-cal-details').hidden), false);
      await page.click('.hg-cal-carte .hg-cal-bouton-details');
      assert.equal(await page.evaluate(() => document.querySelector('.hg-cal-details').hidden), true);
      // Bulle « ? » : survol puis toucher.
      await page.hover('.hg-aide-rond');
      const bulle = await page.evaluate(() => { const b = document.getElementById('hg-aide-bulle'); return { vue: b && !b.hidden, texte: b && b.textContent }; });
      assert.equal(bulle.vue, true);
      assert.equal((bulle.texte.match(/\./g) || []).length, 2, 'deux phrases : ' + bulle.texte);
      await page.mouse.click(5, 5);
      assert.equal(await page.evaluate(() => document.getElementById('hg-aide-bulle').hidden), true);
      await page.dispatchEvent('.hg-aide-rond', 'click', { pointerType: 'touch' });
      assert.equal(await page.evaluate(() => !document.getElementById('hg-aide-bulle').hidden), true, 'toucher');
    }
  } finally {
    if (browser) await browser.close().catch(() => {});
    if (nav) await nav.arreter().catch(() => {});
    serveur.close(); fs.rmSync(profil, { recursive: true, force: true });
  }
});
