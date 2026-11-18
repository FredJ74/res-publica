'use strict';
// Corrections du 19/11 : orages trimestriels partout, jet unique pour la tablée, furet à 150.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const sql = fs.readFileSync(path.join(__dirname, '../../migrations/20261119110000_climat_corrections_fred.sql'), 'utf8');

test('orages trimestriels avec propagation en Sovarka, jet unique pour la tablée, furet à 150', () => {
  assert.match(sql, /SET frequence = 'trimestre_propage', par_periode = 1, delai_min = 1, delai_max = 2\s+WHERE type = 'orage' AND pays = 'soviet'/);
  assert.match(sql, /alerte_le IS NULL AND NOT annule AND debut > now\(\)/);
  assert.match(sql, /random\(\) \* 100 < public\.maladie_risque_interne\('intoxication', 'plat_avarie'\)/);
  assert.match(sql, /maladie_contracter_interne\(x, 'intoxication', 'plat_avarie'\) FROM unnest\(v_participants\)/);
  assert.equal((sql.match(/maladie_contracter_interne\(i\.invite, 'intoxication', 'plat_avarie'\)/g) || []).length, 2);
  assert.match(sql, /SET valeur = 150 WHERE cle = 'prix_furet'/);
});
