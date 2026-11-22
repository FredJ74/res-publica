'use strict';
// Chromium réel : remontées du test de Fred en forêt de Krasnov (22/11/2026, fin de nuit, points 5 à 7).
//  - rapport de combat par round : camp du joueur à gauche (chef d'abord), trait vertical, loups à droite, le premier au
//    niveau du chef, « −8 PA » à côté de chaque nom, état des tombés (mort, en fuite), conclusion, vrais noms, jamais
//    « soldats » ; lisible à 1280 et 390 px, texte jamais plus petit que celui de la page ;
//  - suspense en deux fenêtres : d'abord le seul texte de tension, puis (bouton ou croix) l'image, le récit et le combat ;
//  - le membre du groupe vit la même rencontre sans les choix du chef ; son journal reçoit l'issue et le butin du chef.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), os = require('node:os'), http = require('node:http');
const { chromium } = require('../e2e/node_modules/playwright');
const { lancerChromium } = require('./fixtures/chromium-cdp.cjs');
let acorn;
try { acorn = require('acorn'); } catch (_) { acorn = require('../vercel/node_modules/acorn'); }
const racine = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(racine, f), 'utf8');

// Fonctions du panneau de combat, extraites telles quelles de plateau-politique.js (le fichier entier dépend de tout le jeu).
function extraire(fichier, noms) {
  const src = lire(fichier), ast = acorn.parse(src, { ecmaVersion: 'latest' });
  return noms.map(n => {
    const d = ast.body.find(x => (x.type === 'FunctionDeclaration' && x.id.name === n)
      || (x.type === 'VariableDeclaration' && x.declarations.some(v => v.id.name === n)));
    assert.ok(d, n + ' introuvable dans ' + fichier);
    return src.slice(d.start, d.end);
  }).join('\n');
}
const PANNEAU = extraire('plateau-politique.js', ['libelleLieuCombat', 'libelleAdversaireDebout', 'rpConclusionFaune', 'dernierRoundDetaille',
  'libelleIssueCombat', 'combatsJournalises', 'journaliserFinCombat', 'ouvrirPanneauCombat', 'htmlDecisionsCombat', 'ETATS_COMBATTANT', 'htmlRoundsCombat']);

const L = (nom, mien, perte, etat = null, chef = false) => ({ nom, mien, perte, etat, chef });
const ETAT = {
  ok: true, bataille: { id: 7, statut: 'terminee', round_courant: 5, mon_camp: 'acteur', type: 'faune', resultat: 'tues', issue: 'victoire_acteur',
    adversaire_nom: 'Meute de 3 loups', mon_effectif_actuel: 2, mon_effectif_initial: 2, contrat_combat: 2,
    lieu: { ville: 'ville_b', batiment: 'zone-production', piece: 'foret_vue_3' },
    butin: [{ nom: 'Tissus et peaux', qte: 3 }, { nom: 'Viande', qte: 2 }, { nom: 'Bois', qte: 2 }],
    rounds: [
      { round: 1, adversaire_estime: { libelle: 'Loup 1, Loup 2, Loup 3' }, lignes: [L('Tom Tom', true, 0, null, true), L('Arnie', true, 6), L('Loup 1', false, 8, 'mort'), L('Loup 2', false, 4), L('Loup 3', false, 0)] },
      { round: 2, adversaire_estime: { libelle: 'Loup 2, Loup 3' }, lignes: [L('Tom Tom', true, 5, null, true), L('Arnie', true, 0), L('Loup 1', false, 0, 'mort'), L('Loup 2', false, 0), L('Loup 3', false, 0)] }
    ] } };

const PAGE = '<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
  + '<link rel="stylesheet" href="/style.css"><link rel="stylesheet" href="/rue-centrale.css"><body>'
  + '<div id="journal"></div>'
  + '<div id="modal-postes" class="modal-overlay"><div class="modal-box"><button id="croix" onclick="document.getElementById(\'modal-postes\').classList.remove(\'open\')">×</button>'
  + '<div id="postes-modal-title"></div><div id="postes-body" style="max-height:80vh;overflow:auto"></div></div></div>'
  + '<script>var state={country:"soviet",currentCity:"ville_b",currentBuilding:"zone-production",currentRoom:"foret_vue_3",char:{name:"Arnie"}};'
  + 'window.__toasts=[];window.__journal=[];function showToast(t,c,ok){__toasts.push([t,c,ok]);}'
  + 'function addJournalEntry(t,c){__journal.push([t,c]);var d=document.createElement("div");d.className="journal-entry";d.innerHTML=t;document.getElementById("journal").appendChild(d);}'
  + 'function escapeHtmlText(s){return String(s==null?"":s).replace(/[&<>"\']/g,function(c){return {"&":"&amp;","<":"&lt;",">":"&gt;","\\"":"&quot;","\'":"&#39;"}[c];});}'
  + 'function contexteGroupePj(){return {};} function contexteGroupePjValide(){return true;}'
  + 'var BUILDINGS={"zone-production":{name:"Exploitation forestière de Krasnov",rooms:{foret_vue_3:{name:"Forêt profonde — Le ravin noir"}}}};'
  + 'var WORLD={soviet:{ville_b:{name:"Krasnov"}}};window.__etat=' + JSON.stringify(ETAT) + ';'
  + 'async function sbMilitaireBatailleEtat(){return window.__etat;} async function sbRpcVerdict(){return {ok:true,evenements:[]};}</script>'
  + '<script src="/i18n/sovarka-provinces-resources.js"></script><script src="/plateau-vehicules.js"></script>'
  + '<script src="/plateau-sovarka-provinces.js"></script><script src="/panneau.js"></script></body>';

function servir() {
  return http.createServer((req, res) => {
    const url = decodeURIComponent(req.url.split('?')[0]);
    if (url === '/') { res.setHeader('Content-Type', 'text/html; charset=utf-8'); res.end(PAGE); return; }
    if (url === '/panneau.js') { res.setHeader('Content-Type', 'text/javascript'); res.end(PANNEAU); return; }
    try {
      const t = url.endsWith('.js') ? 'text/javascript' : url.endsWith('.css') ? 'text/css' : 'image/webp';
      res.setHeader('Content-Type', t); res.end(fs.readFileSync(path.join(racine, url.slice(1))));
    } catch (_) { res.writeHead(404); res.end(); }
  });
}

test('rapport par round, suspense en deux fenêtres, membre du groupe (1280 et 390 px)', { timeout: 180000 }, async () => {
  const serveur = servir();
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'hg-foret-combat-')); let nav, browser;
  try {
    await new Promise((r, j) => { serveur.once('error', j); serveur.listen(0, '127.0.0.1', r); });
    nav = await lancerChromium({ executable: process.env.HG_CHROMIUM || ['/usr/bin/chromium', '/usr/bin/google-chrome', '/usr/bin/google-chrome-stable'].find(p => fs.existsSync(p)), profil });
    browser = await chromium.connectOverCDP('http://127.0.0.1:' + nav.port);
    const page = await browser.contexts()[0].newPage();
    const erreurs = []; page.on('pageerror', e => erreurs.push(e.message));
    for (const largeur of [1280, 390]) {
      await page.setViewportSize({ width: largeur, height: 860 });
      await page.goto('http://127.0.0.1:' + serveur.address().port, { waitUntil: 'load', timeout: 60000 });
      await page.waitForFunction(() => typeof ouvrirPanneauCombat === 'function' && typeof foretAfficherRencontre === 'function', null, { timeout: 60000 });

      // 1. Rapport de combat.
      await page.evaluate(() => ouvrirPanneauCombat(7));
      const corps = page.locator('#postes-body');
      assert.match(await corps.innerText(), /Contre : Meute de 3 loups/);
      assert.equal(await page.locator('.hg-round').count(), 2);
      const r1 = page.locator('.hg-round').first();
      assert.match(await r1.locator('.hg-round-titre').innerText(), /round 1/i);
      const lignes = r1.locator('.hg-round-ligne');
      // Grille : gauche, trait, droite ; première rangée = chef à gauche, Loup 1 à droite.
      assert.match(await lignes.nth(0).innerText(), /Tom Tom\s*−0 PA/);
      assert.match(await lignes.nth(1).innerText(), /Loup 1\s*−8 PA\s*\(mort\)/);
      assert.match(await lignes.nth(2).innerText(), /Arnie\s*−6 PA/);
      assert.match(await lignes.nth(3).innerText(), /Loup 2\s*−4 PA/);
      assert.match(await lignes.nth(5).innerText(), /Loup 3\s*−0 PA/);
      // Une seule mesure dans la même frame : les lectures CDP séparées pouvaient
      // chevaucher l'animation d'ouverture et comparer des instants différents.
      const [bTom, bLoup, bTrait] = await r1.evaluate(r => {
        const l = r.querySelectorAll('.hg-round-ligne');
        return [l[0], l[1], r.querySelector('.hg-round-trait')].map(e => e.getBoundingClientRect().toJSON());
      });
      assert.ok(Math.abs(bTom.y - bLoup.y) < 3, 'le premier loup au niveau du chef');
      assert.ok(bTom.x < bTrait.x && bTrait.x < bLoup.x, 'chef à gauche, trait, loup à droite');
      // Le trait est continu d'une rangée à l'autre, sur toute la hauteur du round.
      const trait = await page.evaluate(() => {
        const g = document.querySelector('.hg-round-grille'), t = [...g.querySelectorAll('.hg-round-trait')].map(e => e.getBoundingClientRect());
        return { trous: t.slice(1).some((r, i) => r.top - t[i].bottom > 1), hauteur: t[t.length - 1].bottom - t[0].top, grille: g.getBoundingClientRect().height };
      });
      assert.equal(trait.trous, false); assert.ok(Math.abs(trait.hauteur - trait.grille) < 2, JSON.stringify(trait));
      // Round 2 : le mort garde sa ligne ; à la fin, les loups encore debout se sont enfuis.
      const r2 = await page.locator('.hg-round').nth(1).innerText();
      assert.match(r2, /Loup 1\s*−0 PA\s*\(mort\)/); assert.match(r2, /Loup 2\s*−0 PA\s*\(en fuite\)/);
      const conclusion = await page.locator('.hg-combat-conclusion').innerText();
      assert.equal(conclusion, 'Loup 1 est abattu ; Loup 2 et Loup 3 s’enfuient entre les arbres. Victoire.');
      assert.match(await corps.innerText(), /Butin, remis au chef du groupe : Tissus et peaux ×3, Viande ×2, Bois ×2\./);
      assert.doesNotMatch(await corps.innerText(), /soldat/i);
      // Lisible : jamais plus petit que le texte de la page ; pas de défilement horizontal.
      const tailles = await page.evaluate(() => ({ page: parseFloat(getComputedStyle(document.body).fontSize),
        ligne: parseFloat(getComputedStyle(document.querySelector('.hg-round-ligne')).fontSize),
        titre: parseFloat(getComputedStyle(document.querySelector('.hg-round-titre')).fontSize),
        deborde: document.getElementById('postes-body').scrollWidth > document.getElementById('postes-body').clientWidth + 1 }));
      assert.ok(tailles.ligne >= tailles.page && tailles.titre >= tailles.page, JSON.stringify(tailles));
      assert.equal(tailles.deborde, false, 'pas de défilement horizontal à ' + largeur + ' px');
      await page.screenshot({ path: path.join(os.tmpdir(), 'hg-rapport-combat-' + largeur + '.png') });
      await page.click('#croix');

      // 2. Suspense : d'abord le seul texte de tension, sans image ni choix.
      await page.evaluate(() => foretAfficherRencontre('Meute de 3 loups', 'faune:krasnov:1', null, { suspense: true }));
      assert.equal(await page.locator('#postes-modal-title').innerText(), 'Un bruit dans les fourrés…');
      assert.match(await corps.innerText(), /Les branches craquent, une masse sombre approche… vous serrez votre hache\./);
      assert.equal(await corps.locator('img').count(), 0, 'pas d’image dans la première fenêtre');
      assert.doesNotMatch(await corps.innerText(), /Combattre|Fuir/);
      await page.getByText('Voir ce qui approche').click();
      // Seconde fenêtre : image, récit, trois loups expliqués, combat.
      assert.equal(await corps.locator('img').count(), 1);
      assert.match(await corps.locator('img').getAttribute('src'), /Krasnov_foret_meute_loups\.webp/);
      assert.match(await corps.innerText(), /Meute de 3 loups surgit/);
      assert.match(await corps.innerText(), /Trois loups, trois combattants : chacun a 8 PA/);
      assert.match(await corps.innerText(), /Combattre/); assert.match(await corps.innerText(), /Fuir/);
      await page.click('#croix');
      // Fermer la première fenêtre par la croix ouvre aussi la seconde : jamais d'action sans issue.
      await page.evaluate(() => foretAfficherRencontre('Ours', 'faune:krasnov:2', null, { suspense: true }));
      await page.click('#croix');
      await page.waitForFunction(() => document.getElementById('modal-postes').classList.contains('open') && document.querySelector('#postes-body img'));
      assert.match(await corps.innerText(), /Ours surgit/);
      await page.click('#croix');

      // 3. Le membre : même rencontre en deux fenêtres, sans les choix du chef ; journal.
      await page.evaluate(() => foretJournalAfficher({ cle: 'rencontre', params: { nom: 'Meute de 3 loups', chef: 'Tom Tom', creature: 'meute' } }));
      assert.equal(await corps.locator('img').count(), 0);
      await page.getByText('Voir ce qui approche').click();
      const membre = await corps.innerText();
      assert.match(membre, /Votre chef décide/); assert.match(membre, /groupe de Tom Tom/);
      assert.doesNotMatch(membre, /Fuir|Ne pas se défendre/);
      await page.getByText('Compris').click();
      assert.equal(await page.locator('#modal-postes.open').count(), 0);
      await page.evaluate(() => foretJournalAfficher({ cle: 'olga', params: { chef: 'Tom Tom', bonus: 5, nourris: ['Arnie', 'Tom Tom'] } }));
      assert.equal(await corps.locator('img').count(), 0);
      await page.getByText('Voir ce qui approche').click();
      assert.match(await corps.locator('img').getAttribute('src'), /olga/);
      assert.match(await corps.innerText(), /\+5 PA au prochain sommeil/);
      await page.click('#croix');
      await page.evaluate(() => foretJournalAfficher({ cle: 'combat', bataille: 7, params: { chef: 'Tom Tom', nom: 'Meute de 3 loups', issue: 'tues', abattus: 2, total: 3,
        butin: [{ nom: 'Tissus et peaux', qte: 6 }, { nom: 'Viande', qte: 4 }] } }));
      const journal = await page.locator('#journal').innerText();
      assert.match(journal, /Forêt profonde : Meute de 3 loups surgit devant votre groupe \(Tom Tom mène le groupe\)\./);
      assert.match(journal, /Olga, la vieille de l’isba, a nourri le groupe de Tom Tom\. Vous aussi : \+5 PA/);
      assert.match(journal, /Combat contre Meute de 3 loups, mené par Tom Tom : 2 loups sur 3 abattus, les autres s’enfuient entre les arbres\. Victoire\. Butin remis à Tom Tom : Tissus et peaux ×6, Viande ×4\./);
      await page.locator('#journal').getByText('Lire le rapport de combat').click();
      assert.match(await corps.innerText(), /Contre : Meute de 3 loups/);
      await page.click('#croix');
    }
    assert.deepEqual(erreurs, []);
  } finally {
    if (browser) await browser.close(); if (nav) await nav.arreter();
    serveur.closeAllConnections(); await new Promise(r => serveur.close(r)); fs.rmSync(profil, { recursive: true, force: true });
  }
});
