// Chromium réel : onglets du journal (Fred, 25/11/2026, mission de jour, bloc 2). Sans réponse du serveur (migration non
// appliquée), aucun onglet ; avec, « Mes événements » / « L'empire », la chronique s'affiche (plus récent d'abord, date au format
// unique), l'auteur anonyme n'apparaît pas, et le lieu de la ville où l'on se trouve est un lien. Serveur simulé.
const test = require('node:test'), assert = require('node:assert/strict');
const { avecJeu, page } = require('./mobile-navigateur.cjs');

test('journal : onglets seulement si le serveur répond ; chronique lisible ; lien vers le lieu', async () => avecJeu(async (b, o) => {
  const p = await page(b, o, 390, 844, false, { texteMinimum: true });
  const erreurs = []; p.on('pageerror', e => erreurs.push(e.message));
  await p.evaluate(() => {
    window.__S = { migration: false }; window.__appels = []; window.__entrer = [];
    window.state = { country: 'soviet', currentCity: 'ville_b' };
    window.WORLD = { soviet: { ville_b: { name: 'Krasnov' }, ville_a: { name: 'Starovka' } } };
    window.BUILDINGS = { marche: { name: 'Marché de Krasnov', shortName: 'Marché' } };
    window.enterBuilding = id => window.__entrer.push(id);
    window.formaterHorodatageJournal = () => '25/11 à 10 h 00';
    window.sbRpc = async (fn, a) => {
      window.__appels.push([fn, a]);
      if (!window.__S.migration) throw new Error('404');
      return { ok: true, pays: 'soviet', faits: [
        { quand: '2026-11-25T10:00:00Z', cat: 'acte', cle: 'fausse_rumeur', ville: 'ville_b', batiment: 'marche', auteur: null, params: { cible: 'Sovarka' }, ref: 'a1' },
        { quand: '2026-11-25T09:00:00Z', cat: 'climat', cle: 'blizzard', ville: 'ville_a', params: {}, ref: 'c1' }] };
    };
    window.toggleJournal = () => { const s = document.getElementById('journal-store'); s.style.display = s.style.display === 'flex' ? 'none' : 'flex'; };
  });
  await p.addScriptTag({ url: o + '/plateau-chronique-empire.js' });
  await p.evaluate(() => window.toggleJournal());
  await p.waitForFunction(() => window.__appels.length === 1);
  await p.waitForTimeout(50);
  assert.equal(await p.locator('.hg-chron-onglets').isVisible(), false, 'sans migration : pas d’onglet');
  assert.equal(await p.locator('#journal').isVisible(), true);
  await p.evaluate(() => { window.toggleJournal(); window.__S.migration = true; window.toggleJournal(); });
  await p.waitForSelector('.hg-chron-onglets:not([hidden])');
  assert.deepEqual(await p.locator('.hg-chron-onglets [role="tab"]').allInnerTexts(), ['Mes événements', 'L’empire']);
  await p.locator('[data-onglet="empire"]').click();
  await p.waitForSelector('#journal-empire .journal-entry');
  assert.equal(await p.locator('#journal').isVisible(), false);
  const textes = await p.locator('#journal-empire .journal-text').allInnerTexts();
  assert.deepEqual(textes, ['Une rumeur calomnieuse sur Sovarka circule à Marché, Krasnov.', 'Blizzard sur Starovka : tout le monde se met à l’abri.']);
  assert.equal(await p.locator('#journal-empire .journal-time').first().innerText(), '25/11 à 10 h 00');
  await p.locator('.hg-chron-lieu').click();
  assert.deepEqual(await p.evaluate(() => window.__entrer), ['marche']);
  await p.locator('[data-onglet="mes"]').click();
  assert.equal(await p.locator('#journal').isVisible(), true);
  assert.deepEqual(erreurs, []);
}));
