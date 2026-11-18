'use strict';
// Climat — lot 3 : calendrier, propagation, alertes 48 h, fenêtre du gouvernement, filtres, chantiers, outils du MJ.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '../..');
const lire = f => fs.readFileSync(path.join(root, f), 'utf8');

test('migration : décisions de Fred (trimestre, propagation, délais, 48 h, 2 ou 3 lieux)', () => {
  const sql = lire('migrations/20261118080000_climat_socle.sql');
  assert.match(sql, /\('crue',\s+'republic', 'trimestre_propage', 1, 1, 3, true\)/);
  assert.match(sql, /\('canicule',\s+'republic', 'trimestre_propage', 1, 2, 4, true\)/);
  assert.match(sql, /\('orage',\s+'republic', 'trimestre_propage', 1, 1, 2, true\)/);
  assert.match(sql, /\('brouillard', 'republic', 'mois',\s+2, 0, 0, false\)/);
  assert.match(sql, /preavis_heures integer NOT NULL DEFAULT 48/);
  assert.match(sql, /LIMIT \(2 \+ floor\(random\(\) \* 2\)\)::integer/);
  for (const b of ['entrepot-logistique-luthecia', 'parc-botanique-national', 'port-plaisance-psm', 'bar-des-pecheurs', 'chantier-naval',
                   'marche-psm', 'chasse-peche-psm', 'entrepot-logistique-montrouge', 'zone-production']) assert.ok(sql.includes("'" + b + "'"), b);
  assert.match(sql, /journal_articles_en_attente/);
  assert.match(sql, /evenements_globaux/);
  assert.match(sql, /e\.alerte_le IS NOT NULL\s+-- jamais sans alerte publiée/);
  assert.match(sql, /climat_chantiers_v1/);
  assert.ok(!/goulag_/i.test(sql));
});

test('écran : message du gouvernement dans les neuf langues, filtre sur la vue de rue, section MJ', () => {
  const ctx = { console, setTimeout: () => 0, setInterval: () => 0, Date, Math, JSON, Set, Map, Number, String, Object, Array,
    RPPlateauI18n: { language: () => 'es' }, document: undefined };
  ctx.window = ctx; ctx.globalThis = ctx;
  vm.createContext(ctx);
  vm.runInContext(lire('plateau-climat.js'), ctx);
  const T = ctx.RPClimat.T;
  assert.deepEqual(Object.keys(T).sort(), ['ar', 'de', 'en', 'es', 'fr', 'ko', 'pt-BR', 'ru', 'zh-TW']);
  for (const l of Object.keys(T)) {
    assert.deepEqual(Object.keys(T[l]).sort(), Object.keys(T.fr).sort(), l);
    assert.match(T[l].crue, /\{lieux\}/, l);
  }
  const m = ctx.RPClimat.message({ type: 'crue', ville: 'ville_a', debut: '2026-12-12T00:00:00+01:00', lieux: ['port-sainte-marie'] });
  assert.match(m, /Port-Sainte-Marie/);
  assert.match(lire('plateau.html'), /plateau-climat\.js/);
  assert.match(lire('admin.html'), /admClimatCharger\(\)/);
  assert.match(lire('plateau-construction-commandes.js'), /chantier_intemperies/);
});
