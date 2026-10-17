import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const cron = readFileSync(new URL('../../api/cron-minuit.js', import.meta.url), 'utf8');
const client = readFileSync(new URL('../../plateau-justice-economie.js', import.meta.url), 'utf8');
const sql = readFileSync(new URL('../../supabase/migrations/20261017180000_detention_jours_civils_universels.sql', import.meta.url), 'utf8');
test('cron calcule les peines sur des dates Paris, non 24h', () => {
  assert.match(cron, /jourParisISO\(new Date\(debutTs\)\)/);
  assert.match(cron, /decalerJourISO\(jourDebut, Math\.ceil\(jours\)\)/);
  assert.doesNotMatch(cron, /debutTs \+ jours \* MS_PAR_JOUR_DETENTION/);
});
test('client laisse le serveur trancher la peine', () => {
  assert.match(client, /sbRpc\('detention_clore_purgee'/);
  assert.doesNotMatch(client, /if \(state\.day >= state\.estEmprisonne\.jourFin\)/);
});
test('SQL contrôle le calendrier et garde la clôture atomique', () => {
  assert.match(sql, /AT TIME ZONE 'Europe\/Paris'/);
  assert.match(sql, /v_jour_fin := v_jour_debut \+ ceil\(v_jours\)::integer/);
  assert.match(sql, /v_aujourdhui < v_jour_fin/);
  assert.match(sql, /detention_clore_interne\(v_moi,'purgee'\)/);
});
