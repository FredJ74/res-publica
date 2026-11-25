// Chromium réel : fenêtre de l'armoire à souvenirs installée (Fred, 25/11/2026, bloc 3). Douze emplacements (remplis ou vides),
// progression « 7/12 », « Déposer » depuis l'inventaire, « Reprendre » ; sans réponse du serveur, l'armoire n'est pas proposée.
const test = require('node:test'), assert = require('node:assert/strict');
const { avecJeu, page } = require('./mobile-navigateur.cjs');

test('armoire : 12 emplacements, 7/12, Déposer et Reprendre envoyés au serveur ; indisponible sans migration', async () => avecJeu(async (b, o) => {
  const p = await page(b, o, 390, 844, false, { texteMinimum: true });
  const erreurs = []; p.on('pageerror', e => erreurs.push(e.message));
  await p.evaluate(() => {
    document.body.insertAdjacentHTML('beforeend', '<div id="modal-postes"><h2 id="postes-modal-title"></h2><div id="postes-body"></div></div>');
    window.__S = { migration: false }; window.__appels = [];
    const etat = () => ({ ok: true, id: 'e1', liste: 'Collection n°1', total: 12, remplis: 7, complete: false,
      acces: { present: true, proprietaire: true, ouvrable: true },
      emplacements: Array.from({ length: 12 }, (_, i) => ({ rang: i + 1, ville: 'Ville ' + (i + 1), nom: 'Souvenir ' + (i + 1), contenu: i < 7 ? 100 + i : null, objet: i < 7 ? 'Souvenir ' + (i + 1) : null })),
      cartes: [], deposables: [{ ref: 's8', nom: 'Souvenir 8' }] });
    window.sbRpc = async (fn, a) => { window.__appels.push([fn, a]); if (!window.__S.migration) throw new Error('404');
      if (fn === 'armoire_lire' && a.p_equipement === '00000000-0000-0000-0000-000000000000') return { ok: false, raison: 'armoire_introuvable' };
      return etat(); };
  });
  await p.addScriptTag({ url: o + '/plateau-armoire-souvenirs.js' });
  assert.equal(await p.evaluate(() => window.armoireDisponible()), false, 'sans migration : pas d’armoire proposée');
  await p.evaluate(() => { window.__S.migration = true; });
  await p.evaluate(() => window.ouvrirArmoireInstallee('e1'));
  await p.waitForSelector('.hg-armoire-progression');
  assert.equal(await p.locator('.hg-armoire-progression').innerText(), '7/12 souvenirs');
  assert.equal(await p.locator('.hg-armoire-liste li.rempli').count(), 7);
  assert.equal(await p.locator('.hg-armoire-liste li.vide').count(), 5);
  await p.locator('[data-deposer="s8"]').click();
  await p.waitForFunction(() => window.__appels.some(x => x[0] === 'armoire_deposer'));
  const dep = await p.evaluate(() => window.__appels.find(x => x[0] === 'armoire_deposer')[1]);
  assert.equal(dep.p_ref, 's8'); assert.equal(dep.p_equipement, 'e1'); assert.match(dep.p_requete, /^[0-9a-f-]{36}$/);
  await p.waitForSelector('[data-reprendre="100"]');
  await p.locator('[data-reprendre="100"]').click();
  await p.waitForFunction(() => window.__appels.some(x => x[0] === 'armoire_reprendre'));
  assert.equal(await p.evaluate(() => window.__appels.find(x => x[0] === 'armoire_reprendre')[1].p_contenu), 100);
  assert.deepEqual(erreurs, []);
}));
