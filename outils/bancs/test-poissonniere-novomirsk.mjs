// Marchande de poissons de Novomirsk (06/11/2026) : raccordement écran ↔ serveur.
// node outils/bancs/test-poissonniere-novomirsk.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const lire = (f) => readFileSync(new URL('../../' + f, import.meta.url), 'utf8');
const data = lire('data.js'), routeur = lire('plateau-router.js'), rue = lire('plateau-rue-centrale.js');
const module = lire('plateau-poissonniere.js'), page = lire('plateau.html');
const migration = lire('migrations/20261106172000_poissonniere_novomirsk.sql');

test('le bâtiment est listé à Novomirsk et raccordé à la vue 16', () => {
  assert.match(data, /'pharmacie-officielle-novomirsk','poissonniere-novomirsk'[,\]]/);
  assert.match(data, /'poissonniere-novomirsk': \{/);
  assert.match(rue, /nom: 'Marchande de poissons', type: 'batiment', buildingId: 'poissonniere-novomirsk'/);
  assert.match(migration, /'novomirsk-vue-16', 'poissonniere-novomirsk'/);
});

test('les quatre ordres de l’étal : deux nouveaux routés, deux rumeurs existantes', () => {
  for (const fn of ['poissonniere_poisson', 'contrebande_poissonniere', 'ecouter_rumeurs', 'lancer_rumeur_cible']) {
    assert.ok(data.includes("fn:'" + fn + "'"), fn);
  }
  assert.match(routeur, /fn === 'poissonniere_poisson'\) \{ ouvrirPoissonniere\('poisson'\)/);
  assert.match(routeur, /fn === 'contrebande_poissonniere'\) \{ ouvrirPoissonniere\('contrebande'\)/);
  assert.match(page, /plateau-poissonniere\.js/);
});

test('coûts déclarés au serveur identiques à l’écran', () => {
  assert.match(data, /fn:'poissonniere_poisson', label:[^}]*pa:0, cost:0/);
  assert.match(data, /fn:'contrebande_poissonniere', label:[^}]*pa:1, cost:0/);
  assert.match(migration, /'poissonniere_poisson', 0, 0/);
  assert.match(migration, /'contrebande_poissonniere', 1, 0/);
});

test('l’écran ne décide rien : il appelle le serveur et affiche sa réponse', () => {
  assert.doesNotMatch(module, /Math\.random|Date\.now|localStorage/);
  assert.match(module, /executerReceptionInventaire\('poissonniere_acheter_poisson'/);
  assert.match(module, /executerReceptionInventaire\('poissonniere_acheter_contrebande'/);
  assert.match(module, /il faut que mon mari relève les filets, on a tout vendu la précédente pêche/);
  assert.match(migration, /12 - r\.poisson/);
});
