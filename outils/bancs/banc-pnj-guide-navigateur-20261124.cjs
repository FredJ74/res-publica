// Chromium réel : écran du PNJ guide (purge A.10, Fred, 24/11/2026). Rien pendant la première heure ni pendant qu'une
// fenêtre est ouverte ; une demande par connexion ; badge « PNJ » ; « Je me débrouille, merci » coupe tout ; la réponse
// du joueur part vers le PNJ (serveur), pas vers le chat entre joueurs. Serveur simulé ; vrai plateau-pnj-guide.js.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const { avecJeu, page, R } = require('./mobile-navigateur.cjs');

test('guide : calendrier, badge, bouton qui coupe tout, réponse au PNJ', async () => avecJeu(async (b, o) => {
  const p = await page(b, o, 390, 844, false, { texteMinimum: true });
  const erreurs = []; p.on('pageerror', e => erreurs.push(e.message));
  await p.evaluate(() => {
    window.__S = { premiere: true }; window.__appels = []; window.__api = [];
    window.__RP_GUIDE_SANS_MINUTERIE = true;
    window.RPAccueil = { etat: () => ({ calendrier: { actif: true, premiere_heure: window.__S.premiere } }) };
    window.sbRpc = async (fn) => { window.__appels.push(fn); if (fn === 'guide_etat_lire') return { ok: true, a_ecrire: true, arrete: false }; if (fn === 'guide_arreter') return { ok: true }; return null; };
    window.rpAuthJeton = () => 'j';
    window.fetch = async (u, o) => { window.__api.push([u, JSON.parse(o.body)]); return { json: async () => ({ ok: true }) }; };
    window.showToast = () => {};
  });
  await p.addScriptTag({ url: o + '/plateau-pnj-guide.js' });
  await p.evaluate(() => window.RPPnjGuide.verifier());
  assert.equal(await p.evaluate(() => window.__api.length), 0, 'première heure : rien');
  await p.evaluate(() => { window.__S.premiere = false; window.RPFenetresAuto = { fenetreOuverte: () => true }; return window.RPPnjGuide.verifier(); });
  assert.equal(await p.evaluate(() => window.__api.length), 0, 'fenêtre ouverte : rien');
  await p.evaluate(() => { window.RPFenetresAuto = { fenetreOuverte: () => false }; return window.RPPnjGuide.verifier().then(() => window.RPPnjGuide.verifier()); });
  assert.deepEqual(await p.evaluate(() => window.__api), [['/api/chat?mode=guide', { action: 'prochain' }]], 'une seule demande par connexion');
  // Rendu dans le chat.
  await p.evaluate(() => { document.body.insertAdjacentHTML('beforeend', '<div id="zone">' + 'Vera Pravdina' + window.RPPnjGuide.badgeHtml() +
    window.RPPnjGuide.boutonHtml({ id: 'guide-3' }) + window.RPPnjGuide.boutonHtml({ id: 'guiderep-1' }) + '</div>'); });
  assert.equal(await p.locator('#zone .hg-guide-badge').innerText(), 'PNJ');
  assert.equal(await p.locator('[data-guide-debrouille]').count(), 1, 'sous les messages de guide seulement');
  assert.equal(await p.locator('[data-guide-debrouille]').innerText(), 'Je me débrouille, merci');
  await p.locator('[data-guide-debrouille]').click();
  await p.waitForFunction(() => window.__appels.includes('guide_arreter'));
  assert.equal(await p.locator('[data-guide-debrouille]').count(), 0);
  assert.equal(await p.evaluate(() => window.RPPnjGuide.boutonHtml({ id: 'guide-4' })), '', 'plus jamais de bouton');
  const v = await p.evaluate(() => window.RPPnjGuide.repondre('pnj:Vera Pravdina__Bernard', 'Merci !'));
  assert.equal(v.ok, true);
  assert.deepEqual(await p.evaluate(() => window.__api[1]), ['/api/chat?mode=guide', { action: 'repondre', pnj: 'Vera Pravdina', message: 'Merci !' }]);
  // Le chat entre joueurs reconnaît la conversation avec un PNJ guide.
  const mj = fs.readFileSync(path.join(R, 'plateau-multijoueur.js'), 'utf8');
  assert.match(mj, /window\.RPPnjGuide\.repondre\(_conversationActuelle\.id, texte\)/);
  assert.match(mj, /if \(id && String\(id\)\.startsWith\('pnj:'\)\) return String\(id\)\.slice\(4\);/);
  assert.deepEqual(erreurs, []);
}));
