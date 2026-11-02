// Le référentiel des fondations recopié côté serveur (20261102000900, organisation_vie_referentiel)
// doit rester identique à TYPES_ORGANISATIONS (data.js) : grades, confidentialité, prérequis, pour
// les types fondables dans un local loué. Idem pour le premier grade des supporters (20261102001100).
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const lire = (f) => readFileSync(new URL('../../' + f, import.meta.url), 'utf8');
const data = lire('data.js');
const i = data.indexOf('const TYPES_ORGANISATIONS');
let d = 0, j = data.indexOf('{', i), k = j;
for (; k < data.length; k++) { if (data[k] === '{') d++; else if (data[k] === '}' && --d === 0) break; }
const TYPES = JSON.parse(JSON.stringify(vm.runInNewContext('(' + data.slice(j, k + 1) + ')', { GREVE_MEMBRES_MIN: 5, GREVE_GENERALE_ADHERENTS_MIN: 100 })));
const EXCLUS = JSON.parse(lire('plateau-organisations-quetes.js').match(/const TYPES_ORGA_EXCLUS_LOCAL_LOUE = (\[[^\]]*\])/)[1].replace(/'/g, '"'));

const sql = lire('migrations/20261102000900_organisations_vie_referentiel.sql');
const REF = JSON.parse(sql.match(/SELECT '(\{[\s\S]*?\})'::jsonb/)[1].replace(/''/g, "'"));

test('référentiel serveur = TYPES_ORGANISATIONS pour les types fondables en local loué', () => {
  const attendus = Object.keys(TYPES).filter((t) => !EXCLUS.includes(t)).sort();
  assert.deepEqual(Object.keys(REF).sort(), attendus);
  for (const t of attendus) {
    assert.equal(REF[t].secret, !!TYPES[t].secret, t + ' secret');
    assert.deepEqual(REF[t].requis, TYPES[t].requis || {}, t + ' requis');
    assert.deepEqual(REF[t].grades, TYPES[t].grades, t + ' grades');
  }
});

test('premier grade des supporters identique côté serveur', () => {
  const m = lire('migrations/20261102001100_organisations_greve_generale_supporters_serveur.sql')
    .match(/c_grades constant jsonb := '(\{[^']*\})'/);
  const premiers = JSON.parse(m[1]);
  for (const [pays, g] of Object.entries(TYPES.supporters.grades)) assert.equal(premiers[pays], g[0], pays);
});
