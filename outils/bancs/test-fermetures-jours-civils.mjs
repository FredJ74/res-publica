import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const core = readFileSync(new URL('../../plateau-core.js', import.meta.url), 'utf8');
const db = readFileSync(new URL('../../supabase.js', import.meta.url), 'utf8');
const sql = readFileSync(new URL('../../supabase/migrations/20261017190000_fermetures_date_universelle.sql', import.meta.url), 'utf8');

test('une fermeture datée ne dépend pas du jour personnel', () => {
  const start = core.indexOf('function fermetureEncoreActive(r)');
  const end = core.indexOf('async function chargerBatimentsFermes()', start);
  assert.ok(start >= 0 && end > start);
  const body = core.slice(start, end);
  assert.match(body, /date_fin_universelle/);
  assert.match(body, /timeZone: 'Europe\/Paris'/);
  assert.match(body, /formatToParts/);
  assert.match(body, /jour < r\.date_fin_universelle/);
});
test('la date de fin est décidée par PostgreSQL', () => {
  assert.match(sql, /NEW\.date_fin_universelle := \(now\(\) AT TIME ZONE 'Europe\/Paris'\)::date \+ NEW\.duree_jours/);
  assert.match(sql, /BEFORE INSERT ON public\.batiments_fermes/);
  assert.match(db, /duree_jours: duree/);
  assert.doesNotMatch(db.slice(db.indexOf('async function sbFermerBatiment'), db.indexOf('async function sbChargerBatimentsFermes')), /dateFin\.toISOString/);
});
