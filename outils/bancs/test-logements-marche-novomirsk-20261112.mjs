// Logements du Marché (Novomirsk, vue 16) : seconds logements sociaux, demande de Fred du 12/11/2026.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
const lire = f => readFileSync(new URL('../../' + f, import.meta.url), 'utf8');
const ctx = { console: { log() {}, warn() {} } }; ctx.window = ctx; vm.createContext(ctx);
vm.runInContext(lire('data.js') + ';this.__B=BUILDINGS;this.__W=WORLD;', ctx);
vm.runInContext(lire('plateau-rue-centrale.js') + ';this.__N=RUE_CENTRALE_NOEUDS;', ctx);
for (const [id, decalage] of [['logements-novomirsk-marche', 4], ['logements-novomirsk-quais', 8]])
test(id + ' : même immeuble que la vue 14, mêmes loyers, numérotation décalée de ' + decalage, () => {
  const b = ctx.__B[id], ref = ctx.__B['logements-novomirsk'];
  assert.ok(b && ctx.__W.soviet.capitale.buildings.includes(id));
  assert.deepEqual(Object.keys(b.rooms), Object.keys(ref.rooms));
  for (const [id, r] of Object.entries(b.rooms)) {
    const m = id.match(/^(petit|grand)_appartement_(\d)$/);
    if (!m) continue;
    assert.equal(r.name, (m[1] === 'petit' ? 'Petit' : 'Grand') + ' appartement n°' + (Number(m[2]) + decalage));
    assert.equal(r.locationData.label, r.name);
    assert.equal(r.locationData.prix, ref.rooms[id].locationData.prix);
    assert.equal(r.locationData.logementSocial, true);
  }
  assert.equal(ref.rooms.petit_appartement_1.name, 'Petit appartement n°1', 'la vue 14 est intacte');
});
test('deux zones au-dessus du marché : Quais de Sovarka à gauche, Marché tout à droite', () => {
  const zs = ctx.__N.soviet['novomirsk-vue-16'].zones;
  const q = zs.find(x => x.buildingId === 'logements-novomirsk-quais'), m = zs.find(x => x.buildingId === 'logements-novomirsk-marche');
  assert.deepEqual([...q.xPct], [50, 72]); assert.deepEqual([...m.xPct], [72, 100]);
  assert.equal(q.nom, 'Logements des Quais de Sovarka'); assert.equal(m.nom, 'Logements du Marché');
});
for (const [id, f] of [['logements-novomirsk-marche', '20261112130000_logements_marche_novomirsk'], ['logements-novomirsk-quais', '20261112131500_logements_quais_novomirsk']])
test(id + ' — serveur : 8 logements, pièces accessibles et sortie de rue de la vue 16', () => {
  const sql = lire('migrations/' + f + '.sql');
  assert.equal((sql.match(new RegExp("'" + id + "', '(petit|grand)_appartement_\\d'", 'g')) || []).length, 8);
  assert.match(sql, new RegExp('navigation_lieux_regles[\\s\\S]*' + "'" + id + "'"));
  assert.ok(sql.includes("'novomirsk-vue-16', '" + id + "'"));
});
