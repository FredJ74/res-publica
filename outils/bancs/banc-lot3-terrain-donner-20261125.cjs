'use strict';
// Mission de jour du 25/11/2026, bloc 1.6 (décision de Fred, suite de la Purge C.6) : le Lot 3 de Luthécia devient
// « Lot 3 — Terrain à bâtir » ; dans la fenêtre du chantier, « Donner » reste, discret, sous « Vendre mes matériaux au chantier ».
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');

test('Lot 3 : nom et nom court ; miroir des scènes PNJ régénéré', () => {
  const d = lire('data.js'), i = d.indexOf("  'terrain-a-batir-3': {\n    // Mission de jour");
  assert.ok(i > 0);
  const bloc = d.slice(i, i + 400);
  assert.match(bloc, /name: "Lot 3 — Terrain à bâtir"/);
  assert.match(bloc, /shortName: "Lot 3 — Terrain à bâtir"/);
  assert.doesNotMatch(lire('api/_pnj-scenes-generes.js'), /Lot 3 \(La Châtaigneraie\)/);
});

test('« Donner » : gardé, discret (lien), après la vente, dans la carte « Vendre mes matériaux au chantier »', () => {
  const js = lire('plateau-chantier-vue.js');
  const i = js.indexOf('function carteMateriau('), bloc = js.slice(i, js.indexOf('\n}\n', i));
  assert.ok(bloc.indexOf('cj-vendre-') < bloc.indexOf('cj-donner-'), 'Donner sous Vendre');
  assert.match(bloc, /class="cj-donner-discret" id="cj-donner-/);
  assert.match(lire('style.css'), /#chantier-fenetre \.cj-donner-discret\{[^}]*background:none[^}]*text-decoration:underline/);
});
