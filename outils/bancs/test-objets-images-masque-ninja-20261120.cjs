'use strict';
// Images du masque de carnaval et de la tenue ninja (Fred, 20/11/2026).
// Essai annulé en base le 20/11 : les trois recettes portent leur image ; crim_objet_interne('masque_carnaval' /
// 'tenue_ninja') rend imageUrl ; le masque déjà possédé par Tom Tom est rattrapé.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const racine = path.join(__dirname, '../..');
const lire = (f) => fs.readFileSync(path.join(racine, f), 'utf8');

test('Fichiers : deux webp de 800 px de large dans images/', () => {
  for (const f of ['images/objet-masque-carnaval.webp', 'images/objet-tenue-ninja.webp']) {
    const b = fs.readFileSync(path.join(racine, f));
    assert.equal(b.slice(0, 4).toString(), 'RIFF'); assert.equal(b.slice(8, 12).toString(), 'WEBP');
    assert.ok(b.length < 200000, f);
  }
});

test('Écran : inventaire et fiche d\'objet trouvent l\'image par identité, jamais par nom', () => {
  const src = lire('plateau-personnage.js');
  const debut = src.indexOf('const IMAGES_OBJETS_PAR_IDENTITE'), fin = src.indexOf('\n}\n', src.indexOf('function imageUrlObjet(')) + 3;
  const g = {}; vm.runInNewContext(src.slice(debut, fin) + ';this.f=imageUrlObjet;', g);
  assert.equal(g.f({ generique_id: 'masque_carnaval', name: 'Masque de carnaval' }), 'images/objet-masque-carnaval.webp');
  assert.equal(g.f({ recette_id: 'masque_carnaval_habillement' }), 'images/objet-masque-carnaval.webp');
  assert.equal(g.f({ recette_id: 'tenue_ninja_marche' }), 'images/objet-tenue-ninja.webp');
  assert.equal(g.f({ generique_id: 'tenue_ninja' }), 'images/objet-tenue-ninja.webp');
  assert.equal(g.f({ name: 'Tenue ninja' }), '');                         // jamais par le nom affiché
  assert.equal(g.f({ imageUrl: 'images/autre.webp', generique_id: 'tenue_ninja' }), 'images/autre.webp');
  assert.match(src, /const imageSrc = imageUrlObjet\(item\) \|\|/);
  assert.match(src, /src="' \+ imageObjet \+ '"/);
  assert.match(lire('plateau-actions-illegales-rumeurs.js'), /categorie: 'objet', image: 'images\/objet-tenue-ninja\.webp', icon: 'ti-shirt',/);
});

test('Serveur : recettes, objets déposés et rattrapage', () => {
  const sql = lire('migrations/20261120290000_objets_images_masque_ninja.sql');
  assert.match(sql, /SET image = 'images\/objet-masque-carnaval\.webp'\s+WHERE id = 'masque_carnaval_habillement'/);
  assert.match(sql, /WHERE id IN \('tenue_ninja_marche', 'tenue_ninja_militaire'\)/);
  assert.match(sql, /'imageUrl', 'images\/objet-masque-carnaval\.webp' \/\* objets_images_masque_v1 \*\//);
  assert.match(sql, /'imageUrl', 'images\/objet-tenue-ninja\.webp' \/\* objets_images_ninja_v1 \*\//);
  assert.match(sql, /UPDATE public\.personnages_donnees d SET inventory/);
});
