// Quete d'accueil, etape « fiche personnage » (correctif du 09/11/2026) : l'etape se valide a
// l'OUVERTURE de la fiche, par l'une ou l'autre porte, et la suite de Jeremy vient a la fermeture.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

function charger(etape) {
  const popups = [], sauvegardes = [];
  const el = () => ({ classList: { add() {}, remove() {} }, textContent: '', innerHTML: '', style: {} });
  const ctx = {
    console, setTimeout: () => 0,
    document: { getElementById: el, querySelectorAll: () => [] },
    state: { char: { name: 'Test', queteAccueil: { etape } }, currentBuilding: 'dispensaire-public' },
    sbSavePersonnage: s => { sauvegardes.push(s.char.queteAccueil.etape); return Promise.resolve(); },
  };
  vm.createContext(ctx);
  vm.runInContext(fs.readFileSync('plateau-quete-accueil.js', 'utf8'), ctx);
  ctx.afficherPopupQueteAccueil = o => popups.push(o.texte);
  ctx.queteAccueilSurbrillance = () => {};
  return { ctx, popups, sauvegardes };
}

for (const porte of ['carte du personnage', 'raccourci moi']) {
  test(`Fiche ouverte par la ${porte} : étape validée à l'ouverture, suite à la fermeture`, () => {
    const { ctx, popups, sauvegardes } = charger('attente_fiche_personnage');
    vm.runInContext('queteAccueilFichePersonnageOuverte()', ctx);
    assert.equal(ctx.state.char.queteAccueil.etape, 'attente_hotel');
    assert.deepEqual(sauvegardes, ['attente_hotel']);
    assert.equal(popups.length, 0, 'rien par-dessus la fiche');
    vm.runInContext('queteAccueilApresFichePersonnage()', ctx);
    assert.equal(popups.length, 1);
    assert.match(popups[0], /hôtel/);
    vm.runInContext('queteAccueilApresFichePersonnage()', ctx);
    assert.equal(popups.length, 1, 'la suite ne se répète pas');
  });
}

test('Jérémy ne redemande plus la fiche une fois ouverte', () => {
  const { ctx, popups } = charger('attente_fiche_personnage');
  vm.runInContext('queteAccueilFichePersonnageOuverte(); queteAccueilApresFichePersonnage(); queteAccueilRappel()', ctx);
  assert.doesNotMatch(popups.at(-1), /fiche personnage/);
});

test('Hors de cette étape, ouvrir la fiche ne change rien', () => {
  const { ctx, popups, sauvegardes } = charger('attente_bar');
  vm.runInContext('queteAccueilFichePersonnageOuverte(); queteAccueilApresFichePersonnage()', ctx);
  assert.equal(ctx.state.char.queteAccueil.etape, 'attente_bar');
  assert.equal(popups.length + sauvegardes.length, 0);
});

test('Les deux portes de la fiche sont raccordées', () => {
  const src = fs.readFileSync('plateau-personnage.js', 'utf8');
  const corps = nom => src.slice(src.indexOf(`function ${nom}(`), src.indexOf('\n}', src.indexOf(`function ${nom}(`)));
  for (const f of ['openCharSheet', 'openSelfView']) assert.match(corps(f), /queteAccueilFichePersonnageOuverte\(\)/, f);
  for (const f of ['closeCharSheet', 'closeSelfView']) assert.match(corps(f), /queteAccueilApresFichePersonnage\(\)/, f);
});
