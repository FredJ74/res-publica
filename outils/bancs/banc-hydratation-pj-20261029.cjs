// Régression P0 : aucun échec de lecture ne rend un cache PJ autoritaire.
// Contrôle statique des quatre branches ciblées, sans accès aux vrais joueurs.
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const core = fs.readFileSync(path.join(__dirname, '../../plateau-core.js'), 'utf8');
const supabase = fs.readFileSync(path.join(__dirname, '../../supabase.js'), 'utf8');
const begin = core.indexOf('function loadCharacter()');
assert.ok(begin >= 0, 'loadCharacter présent');
const end = core.indexOf('\nfunction ', begin + 25);
const load = core.slice(begin, end < 0 ? undefined : end);
assert.match(load, /state\.personnageChargeDepuisServeur = !!sbState;/, 'un seul serveur chargé autorise une sauvegarde');
assert.match(load, /state\.personnageChargeDepuisServeur = false; \/\/ fiche serveur masquée/, 'fiche masquée');
assert.match(load, /\.catch\(e => \{\s*rpDiagId\('reconciliation', 'EXCEPTION[^\n]*\n[^]*?state\.personnageChargeDepuisServeur = false;/, 'rejet réseau');
assert.match(load, /\/\/ Lecture serveur indisponible[^]*?state\.personnageChargeDepuisServeur = false;/, 'lecteur absent');
assert.doesNotMatch(load, /personnageChargeDepuisServeur = true; \/\/ echec reseau/, 'aucun repli local autoritaire apres panne');
assert.match(supabase, /function sbSavePersonnage\(charState\) \{\s*if \(charState\.personnageChargeDepuisServeur === false\) return;/, 'porte de sauvegarde obligatoire');
assert.match(supabase, /function sbSauvegardeUrgenceDechargement\(\) \{[^]*?if \(state\.personnageChargeDepuisServeur === false\) return;/, 'porte avant decharger');
console.log('OK - aucun cache non reconcilie ne peut etre sauve par les deux portes generiques');
