'use strict';
// Piece sur telephone (11/11/2026) : image pleine largeur, texte dessous, ordres en liste,
// marge sous les ordres ; bureau intact (regles dans le seul media <= 1023 px).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const lire = f => fs.readFileSync(path.resolve(__dirname, '../..', f), 'utf8');

test('les regles de la piece mobile sont confinees au media <= 1023 px', () => {
  const css = lire('style.css');
  const i = css.lastIndexOf('/* Piece et ordres sur telephone');
  assert.ok(i > 0);
  const bloc = css.slice(i);
  assert.match(bloc, /@media\(max-width:1023px\)\{/);
  for (const r of ['#piece-image[data-hg-split="1"]::before', '.actions-row{display:grid', '#actionbar-batiment{padding-bottom:calc(140px'])
    assert.ok(bloc.includes(r), r);
  assert.equal(css.slice(0, i).includes('data-hg-split'), false);
});

test('le controleur mobile exclut le bureau et les salles de musee ; enseigne sur la hauteur de l image', () => {
  const js = lire('plateau-mobile.js');
  assert.match(js, /if \(!petit\.matches \|\| !url \|\| cadre\.dataset\.musee === '1'\) \{ retirer\(\); return; \}/);
  const v = lire('plateau-variantes-pieces.js');
  assert.match(v, /function varianteHauteurImage\(cadre\) \{\s*\n\s*const h = Number\(cadre\.dataset\.hgImageH\);\s*\n\s*return h > 0 \? h : cadre\.clientHeight;/);
  assert.match(v, /const cl = cadre\.clientWidth, ch = varianteHauteurImage\(cadre\);/);
});
