'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const zlib = require('node:zlib');
const path = require('node:path');
const crypto = require('node:crypto');
const {temoin, avecJeu, page} = require('./mobile-navigateur.cjs');

test('le témoin renouvelé ne change que le texte du logo historique', () => {
  const original = fs.readFileSync(path.join(__dirname, 'fixtures/mobile-temoin-728010c8.json.gz'));
  assert.equal(crypto.createHash('sha256').update(original).digest('hex'), temoin.ajustement_logo.source_sha256);
  const ancien = JSON.parse(zlib.gunzipSync(original));
  assert.equal(temoin.commit, ancien.commit);
  assert.deepEqual(Object.keys(temoin.fichiers), Object.keys(ancien.fichiers));
  const marque = 'title="Retour accueil">Res Publica</div>';
  assert.equal(ancien.fichiers['plateau.html'].split(marque).length, 2);
  for (const [nom, texte] of Object.entries(ancien.fichiers)) {
    assert.equal(temoin.fichiers[nom], nom === 'plateau.html'
      ? texte.replace(marque, 'title="Retour accueil">Human Gambit</div>') : texte, nom);
  }
});

for (const largeur of [320, 390, 1440]) {
  test(`logo Human Gambit et nom conservé après rendu à ${largeur}px`, async () => avecJeu(async (b, o) => {
    const p = await page(b, o, largeur, 900);
    assert.equal((await p.locator('#topbar .logo').textContent()).trim(), 'Human Gambit');
    assert.equal(await p.locator('#topbar .logo').evaluate(e => e.classList.contains('bebas')), true);
    assert.equal(await p.locator('#topbar .logo').getAttribute('onclick'), "window.location.href='index.html'");
    assert.ok(await p.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1));
  }));
}
