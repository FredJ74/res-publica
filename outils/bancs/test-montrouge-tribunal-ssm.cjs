// Régression : l'accès au tribunal reste sur une scène dédiée après le marché.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const rue = fs.readFileSync(path.join(root, 'plateau-rue-centrale.js'), 'utf8');
const data = fs.readFileSync(path.join(root, 'data.js'), 'utf8');
test('image et aller-retour de la rue du tribunal de Montrouge', () => {
  const image = path.join(root, 'images/montrouge/montrouge-rue-tribunal-ssm.webp');
  assert.ok(fs.existsSync(image), 'illustration de la rue absente');
  const marche = rue.slice(rue.indexOf("'montrouge-vue-13':"), rue.indexOf("'montrouge-tribunal-ssm':"));
  assert.match(marche, /arriere: 'montrouge-tribunal-ssm'/);
  const scene = rue.slice(rue.indexOf("'montrouge-tribunal-ssm':"), rue.indexOf('// NOVOMIRSK'));
  assert.match(scene, /image: 'images\/montrouge\/montrouge-rue-tribunal-ssm\.png'/);
  assert.match(scene, /arriere: 'montrouge-vue-13'/);
  assert.doesNotMatch(scene, /toutDroit:|gauche:|droite:/);
  for (const id of ['tribunal-local', 'services-sociaux-montrouge', 'parking-tribunal-montrouge']) {
    assert.match(scene, new RegExp("buildingId: '" + id + "'"));
  }
});
test('SSM et parking sont des lieux visitables sans mécanique anticipée', () => {
  for (const id of ['services-sociaux-montrouge','parking-tribunal-montrouge']) {
    const start = data.indexOf("  '" + id + "': {");
    assert.ok(start >= 0, 'batiment absent ' + id);
    const block = data.slice(start, data.indexOf("\n  },", start) + 5);
    assert.match(block, /rooms:\s*\{\s*accueil:/);
    assert.match(block, /orders: \[\]/);
  }
});
