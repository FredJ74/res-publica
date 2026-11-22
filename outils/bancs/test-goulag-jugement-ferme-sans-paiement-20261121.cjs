'use strict';
// Exécute la vraie porte historique, sans réseau ni personnage de production.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const acorn = require('../e2e/node_modules/acorn');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '../../plateau-justice-economie.js'), 'utf8');
const ast = acorn.parse(source, {ecmaVersion: 'latest'});
const fn = ast.body.find(n => n.type === 'FunctionDeclaration' && n.id.name === 'appliquerSentence');
assert.ok(fn);

function scenario(country, ouvert = false) {
  const contexte = {
    state: {country, plaintesEnCours: [{id: 'fictif', cible: 'fictif', city: 'capitale',
      status: 'saisie', audience_ouverte_le: 'fixture'}]},
    pa: 20, argent: 100, paiements: 0, rpc: [], toasts: [],
    window: {goulagOuvert: () => ouvert},
    estActuellementDetenu: async () => true
  };
  contexte.showToast = (...args) => contexte.toasts.push(args);
  contexte.sbRpc = async (nom, args) => { contexte.rpc.push({nom, args}); return true; };
  // Arrêt avant toute sanction dans les contre-épreuves hors goulag.
  contexte.deduireCoutOrdre = async () => { contexte.paiements++; throw Error('porte-paiement-atteinte'); };
  vm.createContext(contexte);
  vm.runInContext(source.slice(fn.start, fn.end), contexte);
  return contexte;
}

for (const ouvert of [false, true]) {
  test(`ancienne porte QHS Sovarka, ouverture ${ouvert} : zéro paiement, sanction ou RPC`, async () => {
    const c = scenario('soviet', ouvert);
    const avant = JSON.stringify(c.state);
    await c.appliquerSentence('fictif', 'qhs', 'vol', 30, 0, 2, 0);
    await c.appliquerSentence('fictif', 'qhs', 'vol', 30, 0, 2, 0);
    assert.equal(c.paiements, 0);
    assert.equal(c.rpc.length, 0);
    assert.equal(c.pa, 20);
    assert.equal(c.argent, 100);
    assert.equal(JSON.stringify(c.state), avant);
    assert.equal(c.toasts.length, 2);
    assert.equal(c.toasts[0][2], false);
  });
}

for (const [country, genre] of [['republic', 'qhs'], ['soviet', 'prison'], ['republic', 'prison']]) {
  test(`${country}/${genre} : la porte historique reste atteignable`, async () => {
    const c = scenario(country);
    await assert.rejects(c.appliquerSentence('fictif', genre, 'vol', 30, 0, 2, 0), /porte-paiement-atteinte/);
    assert.equal(c.paiements, 1);
    assert.equal(c.rpc[0].nom, 'affaire_autorite_de');
  });
}

test('dossier absent : aucun effet', async () => {
  const c = scenario('soviet');
  await c.appliquerSentence('absent', 'qhs', 'vol', 30, 0, 2, 0);
  assert.equal(c.paiements, 0);
  assert.equal(c.toasts.length, 0);
});
