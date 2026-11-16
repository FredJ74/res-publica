// Garde statique : refonte mobile purement presentation, sans duplication du moteur.
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const html = lire('plateau.html');
const css = lire('plateau-exploration-mobile.css');
const js = lire('plateau-exploration-mobile.js');
const mobile = lire('plateau-mobile.js');
const rue = lire('plateau-rue-centrale.js');
let n=0;
function test(nom, f){f(); n++;console.log('OK '+nom);}
test('assets references une seule fois dans le plateau',()=>{
  for(const f of ['plateau-exploration-mobile.css','plateau-exploration-mobile.js']){
    assert.equal(html.split(f).length-1,1);
    assert.ok(fs.existsSync(path.join(root,f)));
  }
});
test('scripts differes et interface de rue existante',()=>{
  assert.match(html,/plateau-exploration-mobile\.js[^"]*" defer/);
  for(const id of ['vue-rue','rue-image','actionbar','rue-actions-row','rue-title','rue-desc'])
    assert.ok(html.includes('id="'+id+'"'),id);
});
test('responsivite sans masque du bureau',()=>{
  assert.match(css,/@media\(max-width:1023px\)/);
  assert.match(css,/\.hg-explore-tabs\{display:grid/);
  assert.match(css,/min-height:48px/);
  assert.match(css,/\.rc-image\{width:100%;height:auto;max-height:none/);
});
test('pas de commandes metier ni de stats inventees',()=>{
  assert.doesNotMatch(js,/\bsbRpc\s*\(|\bfetch\s*\(|\benterBuilding\s*\(|\bdeplacerRueCentrale\s*\(/);
  assert.match(js,/getElementById\('r-pa'\)/);
  assert.match(js,/getElementById\('r-arg'\)/);
  assert.match(js,/getElementById\('actionbar'\)/);
  assert.doesNotMatch(js,/12\s?450|20\s?\/\s?20|Angie/);
});
test('zones et boutons moteurs preserves',()=>{
  assert.match(rue,/div\.className = 'rc-zone'/);
  assert.match(mobile,/zone\.click\(\)/);
  assert.match(js,/details\.open=true/);
});
test('pas de CSS pour effacer les zones ou flèches',()=>{
  assert.doesNotMatch(css,/\.rc-zone\s*\{[^}]*display\s*:\s*none/);
  assert.doesNotMatch(css,/\.rc-fleche\s*\{[^}]*pointer-events\s*:\s*none/);
});
test('lecture seule, sans traitement des reponses serveur',()=>{
  assert.doesNotMatch(js,/localStorage|sessionStorage|Math\.random|Date\.now/);
  assert.match(js,/scrollIntoView/);
});
console.log(n+' contrôles exploration mobile réussis');
