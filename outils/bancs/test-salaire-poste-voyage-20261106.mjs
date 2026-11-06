import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const sql=fs.readFileSync('migrations/20261106060000_salaire_poste_pays_employeur_voyage.sql','utf8');
const salarySource=fs.readFileSync('baseline/seeds/90_socle/salaires_civils_declares.sql','utf8');

test('Le pays employeur du poste est distinct de la localisation du PJ',()=>{
  assert.match(sql,/s\.categorie = 'poste' AND s\.cle = v_poste/);
  assert.match(sql,/count\(DISTINCT s\.pays\)/);
  assert.match(sql,/v_pays := v_poste_pays/);
  assert.match(sql,/pays_employeur_ambigu/);
  assert.match(sql,/v_poste_pays_count = 1/);
  assert.match(sql,/salaire_civil_percevoir_version_inattendue/);
});

test('Le traitement ne change ni montant, ni caisse, ni anti-double paiement',()=>{
 assert.doesNotMatch(sql,/UPDATE\s+public\.personnages_donnees/i);
 assert.doesNotMatch(sql,/INSERT\s+INTO\s+public\.salaires_civils_verses/i);
 assert.doesNotMatch(sql,/DROP\s+FUNCTION/i);
 assert.match(sql,/pg_get_functiondef/);
 assert.match(sql,/replace\(v_source, v_before_logic, v_after_logic\)/);
 assert.ok(salarySource.includes('min_def'));
});
