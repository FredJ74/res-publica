// GARDE DE L'AUDIT PSM / MONTROUGE (01/11/2026) : LES QUINZE PARCELLES DE RÉPUBLIA ONT LE MÊME SOCLE.
//
// Avant l'audit, les quatre lots de Port-Sainte-Marie n'avaient que trois ordres anciens et aucune
// surface (le serveur refusait l'achat : « prix_ou_surface_non_reference »), le lot 6 de Montrouge
// n'avait pas de surface, et les six lots de Montrouge affichaient « Accélérer le chantier », bouton
// mort dans les empires non P2W. Ce test charge le vrai data.js et le vrai SURFACE_TERRAINS.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const racine = new URL('../../', import.meta.url);
const lire = (f) => readFileSync(new URL(f, racine), 'utf8');

function charger() {
  const ctx = vm.createContext({ console });
  vm.runInContext(lire('data.js'), ctx);
  const pnj = lire('plateau-pnj.js');
  const debut = pnj.indexOf('const SURFACE_TERRAINS = {');
  const fin = pnj.indexOf('const PRIX_AU_M2_TERRAIN = ', debut);
  assert.ok(debut > 0 && fin > debut, 'SURFACE_TERRAINS et PRIX_AU_M2_TERRAIN introuvables');
  vm.runInContext(pnj.slice(debut, pnj.indexOf(';', fin) + 1).replace(/^const /gm, 'var '), ctx);
  return vm.runInContext(`(() => {
    const sortie = [];
    for (const ville of Object.keys(WORLD.republic)) {
      for (const id of WORLD.republic[ville].buildings || []) {
        if (!id.startsWith('terrain-a-batir')) continue;
        const pieces = BUILDINGS[id].rooms, pieceId = Object.keys(pieces)[0];
        const ordres = ordresDeclaresDeLaPiece(pieces[pieceId], WORLD.republic[ville].buildingContext?.[id], pieceId);
        sortie.push({ ville, id, surface: SURFACE_TERRAINS['republic|' + ville + '|' + id] ?? SURFACE_TERRAINS[id],
          prixM2: PRIX_AU_M2_TERRAIN, ordres: ordres.map(o => o.fn).sort(), achat: ordres.find(o => o.fn === 'acheter_terrain') });
      }
    }
    return JSON.parse(JSON.stringify(sortie));
  })()`, ctx);
}

test('les quinze parcelles de Républia : surface connue, prix à 12 FR/m², même parcours', () => {
  const parcelles = charger();
  assert.equal(parcelles.length, 15);
  const reference = parcelles.find(p => p.id === 'terrain-a-batir-1').ordres;
  for (const p of parcelles) {
    assert.ok(Number.isInteger(p.surface) && p.surface > 0, 'surface absente : ' + p.id);
    assert.equal(p.achat.cost, p.surface * p.prixM2, 'prix hors règle des 12 FR/m² : ' + p.id);
    assert.match(p.achat.label, new RegExp(String(p.surface) + ' m²'), 'surface non annoncée : ' + p.id);
    assert.deepEqual(p.ordres, reference, 'parcours divergent de Luthécia : ' + p.id);
  }
  assert.ok(!reference.includes('corrompre_chantier'), 'aucun raccourcissement payant de chantier');
  for (const fn of ['signer_compromis', 'construire_sur_terrain', 'corrompre_fonctionnaire_permis', 'racheter_terrain'])
    assert.ok(reference.includes(fn), 'ordre du parcours absent : ' + fn);
});

test('hors Républia, le lot 6 partagé garde son prix et sa surface inconnue', () => {
  const ctx = vm.createContext({ console });
  vm.runInContext(lire('data.js'), ctx);
  const achat = vm.runInContext("BUILDINGS['terrain-a-batir-6'].rooms.terrain.orders.find(o => o.fn === 'acheter_terrain').cost", ctx);
  assert.equal(achat, 25000);
  assert.ok(!/'terrain-a-batir-6':/.test(lire('plateau-pnj.js').split('const SURFACE_TERRAINS')[1].split('};')[0]));
});

test('le dépôt de permis reste déclaré au miroir des coûts sans bouton propre', () => {
  assert.match(lire('plateau-justice-economie.js'),
    /const ORDRE_DEPOSER_PERMIS = \{fn:'deposer_demande_permis', label:'[^']+', pa:1, cost:100\};/);
});
