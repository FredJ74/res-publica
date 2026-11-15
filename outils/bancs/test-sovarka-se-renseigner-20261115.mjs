// « Se renseigner » en Sovarka (15/11/2026) : lit sovarka_locaux (sovarka_droits_lire), pas les baux de Républia.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
const lire = f => readFileSync(new URL('../../' + f, import.meta.url), 'utf8');

function bac(locaux) {
  const fenetres = [], appels = [];
  const ctx = { console, state: { country: 'soviet', currentCity: 'ville_b', currentBuilding: 'centre-commercial', locationsActives: [] },
    document: { getElementById: () => null, querySelector: () => null, querySelectorAll: () => [] },
    showToast: () => {}, vehModal: (t, h) => fenetres.push([t, h]),
    sbRpcVerdict: async (fn) => { appels.push(fn); return { ok: true, locaux }; } };
  ctx.window = ctx; vm.createContext(ctx);
  vm.runInContext(lire('i18n/sovarka-droits-resources.js'), ctx);
  vm.runInContext(lire('plateau-sovarka-droits.js'), ctx);
  return { ctx, fenetres, appels };
}

test('locaux du bâtiment courant, état serveur : exploité, réservé, libre', async () => {
  const b = bac([
    { ville: 'ville_b', batiment: 'centre-commercial', piece: 'box_1', label: 'Box commercial 1', loyer: 20, origine: 'centre', exploitant: 'Angie', reserve: false },
    { ville: 'ville_b', batiment: 'centre-commercial', piece: 'box_2', label: 'Box commercial 2', loyer: 20, origine: 'centre', exploitant: null, reserve: true },
    { ville: 'ville_b', batiment: 'centre-commercial', piece: 'box_3', label: 'Box commercial 3', loyer: 20, origine: 'centre', exploitant: null, reserve: false },
    { ville: 'ville_b', batiment: 'centre-affaires', piece: 'bureau_1', label: 'Bureau 1', loyer: 30, origine: 'centre', exploitant: null, reserve: false },
    { ville: 'capitale', batiment: 'centre-commercial', piece: 'vitrine_principale', label: 'Vitrine', loyer: 150, origine: 'centre', exploitant: null, reserve: false },
  ]);
  await b.ctx.ouvrirSovarkaSeRenseigner();
  assert.deepEqual(b.appels, ['sovarka_droits_lire']);
  const [titre, html] = b.fenetres[0];
  assert.equal(titre, 'Se renseigner');
  assert.match(html, /Box commercial 1[\s\S]*exploité par Angie/);
  assert.match(html, /Box commercial 2[\s\S]*réservé/);
  assert.match(html, /Box commercial 3[\s\S]*libre/);
  assert.doesNotMatch(html, /Bureau 1|Vitrine/);
});

test('aucun local : message dédié ; le routeur aiguille Sovarka vers ce module', async () => {
  const b = bac([]);
  await b.ctx.ouvrirSovarkaSeRenseigner();
  assert.match(b.fenetres[0][1], /Aucun local à louer/);
  assert.match(lire('plateau-router.js'), /fn === 'se_renseigner'\) \{ if \(state\.country === 'soviet' && typeof ouvrirSovarkaSeRenseigner === 'function'\) \{ ouvrirSovarkaSeRenseigner\(\); return; \} doSeRenseigner\(\); return; \}/);
});
