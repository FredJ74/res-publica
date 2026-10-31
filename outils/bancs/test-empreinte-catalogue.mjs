// EMPREINTE ARBORESCENTE DU CATALOGUE (31/10/2026, #219) : les deux requêtes restent jumelles.
// La descente (detail) n'a de sens que si elle calcule les objets EXACTEMENT comme la racine ;
// la référence de production doit rester lisible par le comparateur.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const lire = (f) => readFileSync(new URL('../../' + f, import.meta.url), 'utf8');
const RACINE = lire('outils/bancs/empreinte-catalogue-racine.sql');
const DETAIL = lire('outils/bancs/empreinte-catalogue-detail.sql');
const REF = JSON.parse(lire('outils/audits/catalogue-1012/EMPREINTE-PRODUCTION-1012.json'));

const objets = (sql) => {
  const i = sql.indexOf('acl AS ('), j = sql.indexOf('seaux AS (') >= 0 && sql.indexOf('resultat AS (') < 0
    ? sql.indexOf('seaux AS (') : sql.indexOf('resultat AS (');
  return sql.slice(i, j);
};

test('la descente calcule les objets exactement comme la racine', () => {
  assert.ok(objets(RACINE).length > 2000);
  assert.equal(objets(DETAIL), objets(RACINE));
});

test('les deux requêtes sont en lecture seule et enveloppées', () => {
  for (const sql of [RACINE, DETAIL]) {
    assert.match(sql, /BEGIN;\s*\nSET TRANSACTION READ ONLY;/);
    assert.match(sql.trim(), /ROLLBACK;$/);
    assert.doesNotMatch(sql.replace(/--[^\n]*/g, ''), /\b(INSERT|UPDATE|DELETE|CREATE|ALTER|DROP|GRANT|REVOKE)\b/i);
  }
});

test('la référence de production couvre les six familles, 16 seaux chacune', () => {
  const cats = REF.empreinte.categories;
  assert.deepEqual(Object.keys(cats).sort(), ['contraintes', 'declencheurs', 'fonctions', 'index', 'politiques', 'relations']);
  for (const [nom, c] of Object.entries(cats)) {
    assert.equal(Object.keys(c.seaux).length, 16, nom);
    assert.equal(Object.values(c.seaux).reduce((s, v) => s + Number(v.split(':')[0]), 0), c.objets, nom);
    assert.match(c.racine, /^[0-9a-f]{32}$/);
  }
  assert.equal(REF.empreinte.registre.lignes, 1012);
  assert.equal(REF.empreinte.categories.fonctions.objets, 1213);
});
