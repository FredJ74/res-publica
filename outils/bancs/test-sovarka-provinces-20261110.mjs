// Lot des provinces de Sovarka (10/11/2026, GAME-DESIGN-NOVOMIRSK.md, « Réponses de Fred »).
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {fileURLToPath} from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
function charger(ville = 'capitale') {
  const ctx = vm.createContext({console, state: {country: 'soviet', currentCity: ville}});
  vm.runInContext(fs.readFileSync(path.join(root, 'data.js'), 'utf8'), ctx);
  return ctx;
}
const ordres = (ctx, ville, b, p) => vm.runInContext(
  `ordresDeclaresDeLaPiece(BUILDINGS[${JSON.stringify(b)}].rooms[${JSON.stringify(p)}], WORLD.soviet[${JSON.stringify(ville)}].buildingContext?.[${JSON.stringify(b)}], ${JSON.stringify(p)}).map(o => o.fn)`, ctx);

test('Banques de Sovarka : bons d’État, ni prêts ni banque privée', () => {
  const ctx = charger();
  for (const [ville, b, p] of [['capitale', 'banque-nationale', 'accueil_banque'], ['ville_a', 'banque-locale', 'guichet'], ['ville_b', 'banque-locale', 'guichet']]) {
    const fns = ordres(ctx, ville, b, p);
    assert.ok(fns.includes('souscrire_bon_etat'), ville + ' : bons absents');
    assert.ok(!fns.includes('emprunter'), ville + ' : prêt encore proposé');
  }
  assert.ok(!vm.runInContext(`WORLD.soviet.capitale.buildings.includes('banque-privee')`, ctx));
  const rep = vm.runInContext(`ordresDeclaresDeLaPiece(BUILDINGS['banque-locale'].rooms.guichet, WORLD.republic.ville_a.buildingContext?.['banque-locale'], 'guichet').map(o => o.fn)`, ctx);
  assert.ok(rep.includes('emprunter') && !rep.includes('souscrire_bon_etat'), 'Républia modifiée');
});

test('Extraction : pétrole à Starovka, bois à Krasnov', () => {
  const src = fs.readFileSync(path.join(root, 'plateau-justice-economie.js'), 'utf8');
  assert.match(src, /ville_a: \['Pétrole'\],\s+\/\/ Starovka/);
  assert.match(src, /ville_b: \['Bois'\]\s+\/\/ Krasnov/);
});

test('Centres d’écoute : façades, une pièce, opérateur, vol d’archives ; ministre de la Défense', () => {
  const ctx = vm.createContext({console, state: {country: 'soviet', currentCity: 'ville_a'}});
  vm.runInContext(fs.readFileSync(path.join(root, 'data.js'), 'utf8'), ctx);
  vm.runInContext(fs.readFileSync(path.join(root, 'plateau-rue-centrale.js'), 'utf8'), ctx);
  const r = vm.runInContext(`(() => {
    const z = (n, b) => (RUE_CENTRALE_NOEUDS.soviet[n].zones || []).some(x => x.buildingId === b);
    return {
      poste: z('starovka-rue-bureaux-caserne', 'poste-vigilance-glaciale') && WORLD.soviet.ville_a.buildings.includes('poste-vigilance-glaciale'),
      radar: z('krasnov-rue-distillerie-radar', 'station-radar-krasnov') && WORLD.soviet.ville_b.buildings.includes('station-radar-krasnov'),
      pieces: Object.keys(BUILDINGS['poste-vigilance-glaciale'].rooms).join() + '|' + Object.keys(BUILDINGS['station-radar-krasnov'].rooms).join(),
      vol: BUILDINGS['station-radar-krasnov'].rooms.salle_ecoute.orders.map(o => o.fn + ':' + o.pa).join(),
      operateurs: BUILDINGS['poste-vigilance-glaciale'].rooms.salle_ecoute.persons[0].name + '|' + BUILDINGS['station-radar-krasnov'].rooms.salle_ecoute.persons[0].name
    };
  })()`, ctx);
  assert.ok(r.poste && r.radar);
  assert.equal(r.pieces, 'salle_ecoute|salle_ecoute');
  assert.equal(r.vol, 'voler_archives_ecoute:2');
  assert.equal(r.operateurs, 'Sergent Bair Dorjiev (PNJ)|Lieutenante Nadejda Sokolova (PNJ)');
  assert.match(fs.readFileSync(path.join(root, 'data.js'), 'utf8'), /fn: 'sovarka_ecoutes', label: 'Rapports des centres d’écoute'[^\n]*requiresPost: 'min_def'/);
  const routeur = fs.readFileSync(path.join(root, 'plateau-router.js'), 'utf8');
  for (const fn of ['souscrire_bon_etat', 'sovarka_ecoutes', 'voler_archives_ecoute']) assert.ok(routeur.includes(`fn === '${fn}'`), fn);
});
