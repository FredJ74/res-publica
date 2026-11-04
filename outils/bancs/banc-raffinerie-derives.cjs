'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ROOT = path.resolve(__dirname, '../..');
const lire = f => fs.readFileSync(path.join(ROOT,f), 'utf8');

test('la raffinerie propose une seule sous-famille petro-chimique', () => {
  const data = lire('data.js');
  const bloc = data.slice(data.indexOf("'raffinerie-montrouge': {"));
  assert.ok(bloc.includes("fn:'produire_derives_petrochimiques'"));
  for (const interdit of ['produire_diluant','produire_vernis','produire_polyester']) {
    assert.ok(!data.includes("fn:'"+interdit+"'"), interdit+' ne doit pas rester visible');
  }
  assert.match(data, /derives_petrochimiques:\s*\{ label: 'Dérivés pétrochimiques'[^\n]*prixBase: 20, prixAchatFournisseur: 10/);
  const router = lire('plateau-router.js');
  assert.match(router, /if \(fn === 'produire_derives_petrochimiques'\) \{ doProduireUsine\('derives_petrochimiques'\)/);
  const client = lire('plateau-justice-economie.js');
  assert.match(client, /derives_petrochimiques:\s*\{[^\n]*matiere: 'petrole', salairePA: 70/);
});
test('une production de derives garde la marge de gros de 10 pct', () => {
  const matiere = 5, coutMatiere = 4, salaire = 70, produits = 10, gros = 10;
  assert.equal(produits * gros - matiere * coutMatiere - salaire, 10);
  const sql = lire('migrations/20261104220000_regrouper_derives_petrochimiques.sql');
  assert.match(sql, /INSERT INTO public\.chaines_production_usine/);
  assert.match(sql, /\('derives_petrochimiques','ville_b','raffinerie-montrouge','petrole',70\)/);
  assert.match(sql, /petrochimie_anciens_stocks_a_convertir_avant_regroupement/);
});
test('catalogues et seed n inventent ni vernis ni polyester comme ressources', () => {
  const g = lire('api/_referentiels-generes.js');
  const j = lire('api/_journal-collecte.js');
  const seed = lire('baseline/seeds/95_a-regenerer/ressources_economie.sql');
  for (const x of [g,j]) assert.match(x, /"derives_petrochimiques":/);
  assert.match(seed, /\('derives_petrochimiques',20,10,100,'transformation'\)/);
  for (const old of ['diluant','vernis','polyester']) {
    assert.ok(!seed.includes("('"+old+"'"), 'ancienne ressource dans le seed: '+old);
  }
  const chaines = lire('baseline/seeds/90_socle/chaines_production_usine.sql');
  assert.match(chaines, /VALUES \('derives_petrochimiques', 'ville_b', 'raffinerie-montrouge', 'petrole', '70'\)/);
});
