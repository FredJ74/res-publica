'use strict';
// Goulag de Sovarka — ordres internes : rendu réel Chromium / WebKit, RPC simulées (aucune session,
// aucune écriture). 320 / 390 / 1280 px × neuf langues (arabe en RTL) × sept fenêtres ; double clic.
const assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
let pw; try { pw = require('../e2e/node_modules/playwright'); } catch (_) { pw = require('playwright'); }
const R = path.resolve(__dirname, '../..');
const moteur = process.env.GOULAG_BROWSER || 'chromium', driver = pw[moteur];
if (!['chromium', 'webkit'].includes(moteur)) throw Error('Moteur inconnu');
const LANGUES = ['fr', 'en', 'es', 'zh-TW', 'ru', 'ko', 'ar', 'pt-BR', 'de'];
const STYLES = ['style.css', 'rue-centrale.css', 'plateau-exploration-mobile.css', 'plateau-mobile-refonte-visible.css',
  'plateau-mobile-prototype.css', 'plateau-interieurs-mobile.css'].filter(f => fs.existsSync(path.join(R, f)));

(async () => {
  const browser = await driver.launch(moteur === 'chromium'
    ? { executablePath: process.env.CHROMIUM_PATH || (fs.existsSync('/usr/bin/chromium') ? '/usr/bin/chromium' : driver.executablePath()), headless: true, args: ['--no-sandbox'] }
    : { headless: true });
  let rendus = 0;
  try {
    for (const width of [320, 390, 1280]) {
      const page = await browser.newPage({ viewport: { width, height: 850 } });
      await page.route('**/*', r => r.abort());
      await page.setContent(fs.readFileSync(path.join(R, 'plateau.html'), 'utf8').replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, ''));
      for (const f of STYLES) await page.addStyleTag({ content: fs.readFileSync(path.join(R, f), 'utf8') });
      await page.evaluate(() => {
        window.i18next = { language: 'fr' };
        window.state = { country: 'soviet', currentCity: 'qhs', estEmprisonne: null, char: { poste: { id: 'juge' } },
          inventory: [{ name: 'Montre à gousset très ancienne avec gravure', type: 'objet', stackKey: 'montre' }] };
        window.WORLD = { soviet: { capitale: { name: 'Novomirsk' }, ville_a: { name: 'Starovka' }, ville_b: { name: 'Krasnov' } } };
        window.appels = []; window.toasts = [];
        window.showToast = (t, m, ok) => toasts.push({ t, m, ok });
        window.sbLoadPersonnage = async () => null; window.updateUI = () => {};
        window.fermerModalPostes = () => document.getElementById('modal-postes').classList.remove('open');
        window.doOrder = fn => appels.push({ fn: 'doOrder:' + fn });
        const long = 'Aleksandra Konstantinovna Vorontsova-Dashkova';
        window.verdicts = {
          sovarka_goulag_liste_detenus: { ok: true, detenus: [{ nom: long, jours_restants: 12, statut: 'en_fuite' }, { nom: 'Ivan', jours_restants: 3, statut: 'detenu' }] },
          sovarka_goulag_registre_consulter: { ok: true, registre: [{ nom: long, tribunal_pays: 'soviet', tribunal_ville: 'ville_b', entree_le: '2026-11-17T10:00:00Z', sortie_le: null, evasion_le: '2026-11-18T14:00:00Z', interrogatoires: 2 }] },
          sovarka_goulag_incidents_consulter: { ok: true, incidents: [{ nature: 'sanction_disciplinaire', nom: long, survenu_le: '2026-11-17T10:00:00Z', nuits: 2 }] },
          sovarka_goulag_detenus_choisir: { ok: true, detenus: [{ nom: long }, { nom: 'Ivan' }] },
          sovarka_goulag_interroger: { ok: true, reussi: true, revelation: true, probabilite: 70 },
          sovarka_goulag_sanctionner: { ok: true, detenu: long, nuits: 2 },
          sovarka_goulag_corrompre: { ok: false, raison: 'corruption_a_arbitrer' }
        };
        window.sbRpcVerdict = async (fn, p) => { appels.push({ fn, p }); await new Promise(r => setTimeout(r, 30)); return verdicts[fn] || { ok: true }; };
      });
      await page.addScriptTag({ content: fs.readFileSync(path.join(R, 'plateau-goulag-ordres.js'), 'utf8') });
      const fenetres = [
        ['liste', () => goulagOrdresTest('sovarka_goulag_liste')], ['registre', () => goulagOrdresTest('sovarka_goulag_registre')],
        ['incidents', () => goulagOrdresTest('sovarka_goulag_incidents')], ['interroger', () => goulagOrdresTest('sovarka_goulag_interroger')],
        ['sanction', () => goulagOrdresTest('sovarka_goulag_sanction')], ['corrompre', () => goulagOrdresTest('sovarka_goulag_corrompre')],
        ['depart', () => goulagOrdresTest('depart')]
      ];
      await page.evaluate(() => {
        window.goulagOrdresTest = async fn => {
          document.getElementById('modal-postes').classList.remove('open');
          if (fn === 'depart') { goulagOrdresInternes.choisirDepart(); return; }
          await window.doOrder(fn); await new Promise(r => setTimeout(r, 60));
        };
      });
      for (const lang of LANGUES) {
        await page.evaluate(l => { i18next.language = l; document.documentElement.lang = l; document.documentElement.dir = l === 'ar' ? 'rtl' : 'ltr'; }, lang);
        for (const [nom] of fenetres) {
          await page.evaluate(n => goulagOrdresTest(n === 'depart' ? 'depart' : 'sovarka_goulag_' + n), nom);
          await page.waitForTimeout(80);
          const etat = await page.evaluate(() => {
            const box = document.querySelector('#modal-postes .modal-box') || document.getElementById('modal-postes');
            const d = document.querySelector('#postes-body .goulag-ordres');
            return { ouvert: document.getElementById('modal-postes').classList.contains('open'), boxW: box.getBoundingClientRect().width,
              docScroll: document.documentElement.scrollWidth, docW: document.documentElement.clientWidth,
              dir: d ? getComputedStyle(d).direction : null, titre: document.getElementById('postes-modal-title').textContent };
          });
          assert.ok(etat.ouvert, JSON.stringify({ width, lang, nom }));
          assert.ok(etat.titre.trim().length > 0);
          assert.ok(etat.boxW <= width + 1, JSON.stringify({ width, lang, nom, etat }));
          assert.ok(etat.docScroll <= etat.docW + 1, 'défilement horizontal de page ' + JSON.stringify({ width, lang, nom, etat }));
          assert.equal(etat.dir, lang === 'ar' ? 'rtl' : 'ltr', JSON.stringify({ lang, nom }));
          for (const b of await page.locator('#postes-body button').all()) {
            await b.scrollIntoViewIfNeeded(); const r = await b.boundingBox();
            assert.ok(r && r.height >= 36 && r.x >= -1 && r.x + r.width <= width + 1, JSON.stringify({ width, lang, nom, r }));
          }
          rendus++;
        }
      }
      // Double clic sur « Confirmer » : une seule RPC, même clé de requête.
      await page.evaluate(async () => {
        i18next.language = 'fr'; await goulagOrdresTest('sovarka_goulag_interroger'); appels.length = 0;
        const b = document.getElementById('goulag-ordres-ok'); b.click(); b.click();
      });
      await page.waitForTimeout(200);
      assert.equal(await page.evaluate(() => appels.filter(a => a.fn === 'sovarka_goulag_interroger').length), 1);
      // Refus du serveur nommé (corruption non arbitrée), sans effet local.
      await page.evaluate(async () => { toasts.length = 0; await goulagOrdresTest('sovarka_goulag_corrompre'); document.getElementById('goulag-ordres-ok').click(); });
      await page.waitForTimeout(150);
      assert.ok(await page.evaluate(() => toasts.some(t => /game designer/.test(t.m))));
      assert.equal(await page.evaluate(() => state.inventory.length), 1);
      // Ordres d'un autre bâtiment ou de Républia : jamais routés vers le goulag.
      await page.evaluate(() => { appels.length = 0; doOrder('prier'); });
      assert.deepEqual(await page.evaluate(() => appels.map(a => a.fn)), ['doOrder:prier']);
      await page.close();
    }
    console.log(JSON.stringify({ moteur, rendus, largeurs: [320, 390, 1280], langues: 9, fenetres: 7, rtl: true, doubleClic: 'une seule RPC', serveur: 'simulé', personnageConnecte: false }));
  } finally { await browser.close(); }
})().catch(e => { console.error(e); process.exitCode = 1; });
