import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const sql=readFileSync('historique/migrations-appliquees/rehorodatees-219/20261031113625_placement_national_idempotent.sql','utf8');
const client=readFileSync('plateau-justice-economie.js','utf8');
const ui=readFileSync('plateau-communication.js','utf8');
const transport=readFileSync('supabase.js','utf8');
test('une seule transaction debite les especes ou le compte national',()=>{
 assert.match(sql,/p_source = 'liquide'/);
 assert.match(sql,/update public\.personnages_donnees\s+set liquide = v_liquide - p_montant/i);
 assert.match(sql,/update public\.comptes_bancaires\s+set solde = solde - p_montant/i);
 assert.match(sql,/insert into public\.placements_bancaires/i);
 assert.match(sql,/perform public\.exiger_acteur\(p_personnage\)/i);
});
test('les operations repetées gardent leur id et ne repassent pas par le debit',()=>{
 assert.match(sql,/v_id := 'terme_' \|\| replace\(p_intention::text, '-', ''\)/);
 const retour=sql.indexOf('return v_exist;');
 const debit=sql.indexOf('if p_source =');
 assert.ok(retour>=0&&debit>retour);
 assert.match(sql,/for update/i);
 assert.match(sql,/source_fonds is distinct from p_source/);
});
test('pas de nouvelle interdiction de plusieurs placements actifs',()=>{
 assert.doesNotMatch(sql,/un placement Banque nationale est déjà actif/i);
});
test('l interface unifiee presente les deux sources et conserve une intention en attente',()=>{
 assert.match(ui,/id="investir-source"/);
 assert.match(ui,/value="liquide"/);
 assert.match(client,/localStorage\.setItem\(cleAttente/);
 assert.match(client,/localStorage\.removeItem\(cleAttente/);
 assert.match(client,/relirePlacementsNationauxServeur\(nom\)/);
 assert.match(transport,/creer_placement_national_securise/);
});
