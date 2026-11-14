// Sovarka n'a pas de législatives (Fred, 07/11/2026) : ni salle des élections, ni calendrier, ni
// tableau des candidats ne doivent créer ou afficher un cycle de député en Sovarka (audit 14/11/2026).
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const read = p => fs.readFileSync(new URL('../../' + p, import.meta.url), 'utf8');
const src = read('plateau-politique.js');
test('Garde écran : scrutinAbsentDuPays filtre les législatives de Sovarka partout', () => {
  const f = new Function(src.match(/function scrutinAbsentDuPays[\s\S]*?\n\}/)[0] + '; return scrutinAbsentDuPays;')();
  assert.equal(f('depute', 'soviet'), true);
  assert.equal(f('maire', 'soviet'), false);
  assert.equal(f('president', 'soviet'), false);
  assert.equal(f('depute', 'republic'), false);
  assert.equal((src.match(/for \(const e of ENTREES_SALLE_ELECTIONS\) \{\n    if \(scrutinAbsentDuPays\(e\.posteId, country\)\) continue;/g) || []).length, 3);
  assert.equal((src.match(/\]\.filter\(p => [^\n]*scrutinAbsentDuPays\(p\.id, country\)\)/g) || []).length, 3);
});
test('Garde serveur : la migration refuse le cycle de député en Sovarka', () => {
  const sql = read('migrations/20261114201500_sovarka_pas_de_legislatives.sql');
  assert.match(sql, /v_pays = 'soviet' AND p_poste = 'depute'[\s\S]*depute_designe_par_parti/);
});
