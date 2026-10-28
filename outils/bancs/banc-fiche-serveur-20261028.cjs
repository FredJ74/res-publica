// Regression garde serveur: un echec de chargement ne peut pas revalider le cache.
// Ce banc inspecte les quatre issues de loadCharacter sans acceder a Supabase.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const src = fs.readFileSync('plateau-core.js','utf8');
const debut = src.indexOf('function loadCharacter()');
assert.ok(debut >= 0, 'loadCharacter doit exister');
const fin = src.indexOf('function ', debut + 25);
const code = src.slice(debut, fin < 0 ? undefined : fin);
assert.match(code, /state\\.personnageChargeDepuisServeur = !!sbState/, 'seule une fiche reelle revalide la sauvegarde');
assert.match(code, /fiche masquée : aucune autorité locale/);
assert.match(code, /rpDiagId\\('reconciliation', 'EXCEPTION[\\s\\S]{0,320}personnageChargeDepuisServeur = false/, 'le rejet reseau ferme le portillon');
assert.doesNotMatch(code, /personnageChargeDepuisServeur = true; \\/\\/ echec reseau/);
console.log('OK — cache sans autorite apres echec de reconciliation');

// La file ne doit plus envoyer une fiche sans comparaison préalable à la version serveur.
const sb = fs.readFileSync('supabase.js','utf8');
const fileStart = sb.indexOf('function sbEnfilerEcriturePersonnage(');
const fileEnd = sb.indexOf('function ',fileStart+35);
const queue = sb.slice(fileStart,fileEnd<0?undefined:fileEnd);
assert.match(queue,/const repereServeur = charState\._dernierUpdatedAtConnu/);
assert.match(queue,/sbEcrirePersonnage\(data, repereServeur\)/);
assert.match(sb,/updated_at=eq\.\$\{encodeURIComponent\(versionAttendue\)\}/);
assert.doesNotMatch(queue,/const actuel = await sbGet\('personnages'/);
assert.match(queue,/charState\.personnageChargeDepuisServeur = false/);
