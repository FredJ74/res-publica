// Logements du Marché (Novomirsk, vue 16) : seconds logements sociaux, demande de Fred du 12/11/2026.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
const lire = f => readFileSync(new URL('../../' + f, import.meta.url), 'utf8');
const ctx = { console: { log() {}, warn() {} } }; ctx.window = ctx; vm.createContext(ctx);
vm.runInContext(lire('data.js') + ';this.__B=BUILDINGS;this.__W=WORLD;', ctx);
vm.runInContext(lire('plateau-rue-centrale.js') + ';this.__N=RUE_CENTRALE_NOEUDS;', ctx);
test('même immeuble que la vue 14, appartements n°5 à n°8, mêmes loyers', () => {
  const b = ctx.__B['logements-novomirsk-marche'], ref = ctx.__B['logements-novomirsk'];
  assert.ok(b && ctx.__W.soviet.capitale.buildings.includes('logements-novomirsk-marche'));
  assert.deepEqual(Object.keys(b.rooms), Object.keys(ref.rooms));
  for (const [id, r] of Object.entries(b.rooms)) {
    const m = id.match(/^(petit|grand)_appartement_(\d)$/);
    if (!m) continue;
    assert.equal(r.name, (m[1] === 'petit' ? 'Petit' : 'Grand') + ' appartement n°' + (Number(m[2]) + 4));
    assert.equal(r.locationData.label, r.name);
    assert.equal(r.locationData.prix, ref.rooms[id].locationData.prix);
    assert.equal(r.locationData.logementSocial, true);
  }
  assert.equal(ref.rooms.petit_appartement_1.name, 'Petit appartement n°1', 'la vue 14 est intacte');
});
test('zone cliquable : moitié droite au-dessus du marché, vers le nouvel immeuble', () => {
  const z = ctx.__N.soviet['novomirsk-vue-16'].zones.find(x => x.buildingId === 'logements-novomirsk-marche');
  assert.deepEqual([...z.xPct], [50, 100]); assert.deepEqual([...z.yPct], [0, 32]);
});
test('serveur : 8 logements, pièces accessibles et sortie de rue de la vue 16', () => {
  const sql = lire('migrations/20261112130000_logements_marche_novomirsk.sql');
  assert.equal((sql.match(/'logements-novomirsk-marche', '(petit|grand)_appartement_\d'/g) || []).length, 8);
  assert.match(sql, /navigation_lieux_regles[\s\S]*'logements-novomirsk-marche'/);
  assert.match(sql, /'novomirsk-vue-16', 'logements-novomirsk-marche'/);
});
