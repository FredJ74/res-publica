'use strict';
// Starovka et Sovarka (décisions de Fred, 18/11/2026) : train seulement pour Starovka, pas de blocus syndical
// en Sovarka, magasin du kolkhoze (six articles, jamais transmissible). Serveur : migration 20261118041000,
// essai en transaction annulée sur Supabase (bus vers Starovka refusé, bus vers Novomirsk accepté, compromis refusé).
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const R = path.resolve(__dirname, '../..');
const lire = f => fs.readFileSync(path.join(R, f), 'utf8');

test('bus : Starovka retirée des destinations, et aucune destination depuis Starovka', () => {
  const nav = lire('plateau-navigation.js');
  assert.match(nav, /const starovkaSansBus = mode === 'bus' && pays === 'soviet';/);
  assert.match(nav, /if \(starovkaSansBus && \(ville\.id === 'ville_a' \|\| state\.currentCity === 'ville_a'\)\) return;/);
  assert.match(nav, /starovka_train_seulement:/);
  const cat = lire('i18n/navigation-resources.js');
  assert.equal((cat.match(/"starovkaTrainOnly": /g) || []).length, 9);
});

test('syndicat de Sovarka : pas de blocus (fiche, ordre syndical, motif serveur)', () => {
  assert.match(lire('plateau-personnage.js'), /if \(state\.country !== 'soviet'\) \{\n    html \+= '<button onclick="doOrder\(\\'organiser_blocus\\'/);
  const org = lire('plateau-organisations-quetes.js');
  assert.match(org, /async function doOrganiserBlocusSyndical\(\) \{\n  \/\/ Sovarka[^\n]*\n  if \(state\.country === 'soviet'\)/);
  assert.match(org, /syndicat_etat_sans_greve:/);
});

test('magasin du kolkhoze : six articles, même liste à l\'écran et au serveur, prix PNJ ×2', () => {
  const ecran = lire('plateau-actions-illegales-rumeurs.js');
  const sql = lire('migrations/20261118041000_starovka_train_syndicat_kolkhoze.sql');
  const ids = ['kolkhoze_viande_renne', 'kolkhoze_lait_renne', 'kolkhoze_confiture_airelles', 'kolkhoze_graisse_renne', 'kolkhoze_peau_renne', 'kolkhoze_bois_renne'];
  for (const id of ids) {
    assert.match(ecran, new RegExp("  " + id + ": \\{\\n    id: '" + id + "'"), id);
    assert.match(sql, new RegExp("\\('" + id + "','kolkhoze'"), id);
  }
  assert.match(ecran, /'magasin-kolkhoze-starovka': 'tabac-presse'/);
  // 2 × (coût moyen des matières + 15 PSK × 1 PA) / portions
  const prix = JSON.parse(sql.match(/"prixVente":(\{[^}]*\})/)[1]);
  const att = { kolkhoze_viande_renne: [2, 4], kolkhoze_lait_renne: [1, 8], kolkhoze_confiture_airelles: [1, 6], kolkhoze_graisse_renne: [2, 6], kolkhoze_peau_renne: [1, 2], kolkhoze_bois_renne: [2, 3] };
  for (const [id, [cout, portions]] of Object.entries(att)) assert.equal(prix[id], Math.floor(2 * (cout + 15) / portions), id);
  assert.match(sql, /'nonTransmissible', true/);
  assert.match(sql, /commerce_kolkhoze_non_transmissible/);
  const data = lire('data.js');
  const bloc = data.slice(data.indexOf("BUILDINGS['magasin-kolkhoze-starovka']"), data.indexOf("BUILDINGS['compagnie-petrole-starovka']"));
  assert.match(bloc, /fn:'faire_achats_marche'/);
  assert.doesNotMatch(bloc, /gerer_commerce/, 'pas de gestion : jamais à un PJ');
  assert.doesNotMatch(ecran.slice(ecran.indexOf('const PRIX_RACHAT_COMMERCE'), ecran.indexOf('};', ecran.indexOf('const PRIX_RACHAT_COMMERCE'))), /kolkhoze/);
});
