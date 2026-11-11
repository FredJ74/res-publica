// Guide du Musée de la République (11/11/2026) : présente dans les neuf salles, portrait dédié,
// et sa carte n'ouvre pas le dialogue libre gratuit.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const racine = new URL('../../', import.meta.url);
const lire = f => fs.readFileSync(new URL(f, racine), 'utf8');

test('la guide est dans les neuf salles du musée de Novomirsk', () => {
  const ctx = { window: {}, console, navigator: {}, localStorage: { getItem() { return null; }, setItem() {} },
    document: { addEventListener() {}, getElementById() { return null; }, querySelector() { return null; } } };
  ctx.self = ctx.window;
  vm.createContext(ctx);
  vm.runInContext(lire('data.js') + ';globalThis.__W = WORLD;', ctx);
  const ro = ctx.__W.soviet.capitale.buildingContext['musee-national-republia'].roomOverrides;
  const salles = Object.keys(ro);
  assert.equal(salles.length, 9);
  for (const s of salles) {
    const p = ro[s].persons || [];
    assert.equal(p.length, 1, s);
    assert.equal(p[0].guideMusee, true, s);
    assert.equal(p[0].photoUrl, 'images/Sovarka/Novomirsk/Novo_guide_musee_national_portrait.webp');
  }
  assert.ok(fs.existsSync(new URL('images/Sovarka/Novomirsk/Novo_guide_musee_national_portrait.webp', racine)));
});

test('la carte de la guide ouvre sa fenêtre, pas le dialogue PNJ', () => {
  const m = lire('plateau-multijoueur.js');
  const i = m.indexOf('if (p.guideMusee === true) {');
  assert.ok(i > 0 && i < m.indexOf("onclick=\"openPnjModal(this.dataset.enc)\""));
  assert.match(m.slice(i, i + 500), /onclick="ouvrirGuideMusee\(\)"/);
  assert.match(m, /function ouvrirGuideMusee\(\)/);
});
