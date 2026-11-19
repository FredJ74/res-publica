'use strict';
// Maladies — lot 2a (GAME-DESIGN-MALADIES-CLIMAT.md §§ 3 et 11) : piles d'aliments datées, péremption, message, retraits multi-piles.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '../..');
const lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const sql = lire('migrations/20261118070000_aliments_piles_datees.sql');

test('migration : périssables, fusion le même jour, retraits des plus anciennes, passe de nuit', () => {
  assert.match(sql, /p_cle IN \('viande', 'viande_renne', 'laitages', 'poisson', 'fruits_legumes', 'oeufs'\)/);
  assert.match(sql, /\('peremption_jours', 10\)/);
  assert.match(sql, /ORDER BY \(o - 1 = coalesce\(p_pos, -1\)\) DESC, public\.aliment_recu_interne\(e\) NULLS FIRST, o/);
  for (const f of ['inventaire_deposer_interne', 'inventaire_reclamer_livraison', 'acheter_a_entrepot', 'helvetia_inventaire_sortie',
                   'offre_achat_servir', 'jardins_laisser_interne', 'inventaire_consommer'])
    assert.ok(sql.includes("'public." + f + '('), f);
  assert.match(sql, /cron\.schedule\('aliments_passe_nuit'/);
  assert.match(sql, /'aliment_avarie'/);
  assert.match(sql, /controle structurel en echec/);
  assert.ok(!/goulag_/i.test(sql)); // aucune fonction du goulag (chantier de Codex)
  // Le message au propriétaire ne nomme que des clés de matières, jamais une pile ni une date.
  const lireAnnonces = sql.slice(sql.indexOf('FUNCTION public.aliments_annonces_lire'), sql.indexOf('cron.unschedule'));
  assert.ok(!/recu/.test(lireAnnonces.replace(/aliments_avaries_annonces/g, '')));
});

test('écran : message des aliments gâtés dans les neuf langues, quantités = somme des piles', () => {
  const ctx = { console, setTimeout: () => 0, setInterval: () => 0, Date, Math, JSON, Set, Map, Number, String, Object, Array,
    showToast: () => {}, RPPlateauI18n: { language: () => 'ko' }, document: undefined };
  ctx.window = ctx; ctx.globalThis = ctx;
  vm.createContext(ctx);
  vm.runInContext(lire('plateau-maladies.js'), ctx);
  const T = ctx.RPMaladies.T;
  for (const l of Object.keys(T)) {
    assert.match(T[l].spoiled, /\{liste\}/, l);
    for (const c of ['viande', 'viande_renne', 'laitages', 'poisson', 'fruits_legumes', 'oeufs']) assert.ok(T[l]['a_' + c], l + ' ' + c);
  }
  assert.match(lire('plateau-maladies.js'), /sbRpc\('aliments_annonces_lire'/);
  assert.match(lire('plateau-actions-illegales-rumeurs.js'), /filter\(i => i && i\.stackKey === matiere\)\.reduce/);
  assert.match(lire('plateau-sovarka-provinces.js'), /deja\.qty \+= Number\(o\.qty\)/);
});
