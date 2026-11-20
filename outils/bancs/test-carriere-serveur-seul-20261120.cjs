'use strict';
// La carrière ne change que par les voies du jeu (Fred, 20/11/2026). Essai annulé en base : un joueur qui écrit
// career par la vue `personnages` → témoin sans raccord : réécrite ; avec raccord : inchangée.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const lire = (f) => fs.readFileSync(path.join(__dirname, '../..', f), 'utf8');

test('Serveur : la vue reprend la carrière canonique', () => {
  const sql = lire('migrations/20261120240000_carriere_serveur_seul.sql');
  assert.match(sql, /rp_raccorder\('public\.personnages_vue_modifier\(\)'/);
  assert.match(sql, /NEW\.career {12}:= v_canon\.career;\$b\$, 'carriere_serveur_seul_v1'\)/);
});

test('Docs : la règle est notée', () => {
  assert.match(lire('RELAIS.md'), /carriere_serveur_seul/);
});
