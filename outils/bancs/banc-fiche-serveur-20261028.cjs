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
