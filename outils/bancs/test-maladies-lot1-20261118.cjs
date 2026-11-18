'use strict';
// Maladies — lot 1 (GAME-DESIGN-MALADIES-CLIMAT.md §§ 2 et 11) : catalogue neuf langues, branchements écran, migration.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '../..');
const lire = f => fs.readFileSync(path.join(root, f), 'utf8');

function charger(langue) {
  const toasts = [];
  const ctx = { console, setTimeout: () => 0, setInterval: () => 0, Date, Math, JSON, Set, Number, String, Object, Array,
    showToast: (t, b, ok) => toasts.push([t, b, ok]), RPPlateauI18n: { language: () => langue }, document: undefined };
  ctx.window = ctx; ctx.globalThis = ctx;
  vm.createContext(ctx);
  vm.runInContext(lire('plateau-maladies.js'), ctx);
  return { ctx, toasts };
}

test('neuf langues, mêmes clés et mêmes variables que le français', () => {
  const { ctx } = charger('fr');
  const T = ctx.RPMaladies.T;
  const langues = ['fr', 'en', 'es', 'zh-TW', 'ru', 'ko', 'ar', 'pt-BR', 'de'];
  assert.deepEqual(Object.keys(T).sort(), [...langues].sort());
  const vars = s => (String(s).match(/\{\w+\}/g) || []).sort().join(',');
  for (const l of langues) {
    assert.deepEqual(Object.keys(T[l]).sort(), Object.keys(T.fr).sort(), l);
    for (const [k, v] of Object.entries(T.fr)) {
      assert.ok(String(T[l][k]).trim(), l + ' ' + k);
      assert.equal(vars(T[l][k]), vars(v), l + ' ' + k);
    }
  }
  for (const c of ctx.RPMaladies.CLES) for (const p of ['n_', 's_', 'o_']) assert.ok(T.fr[p + c], p + c);
  for (const m of ctx.RPMaladies.MEDICAMENTS) assert.ok(T.fr['m_' + m], m);
});

test('le texte libre du MJ prime ; le nom de la maladie n’est jamais dans le symptôme vu par les autres', () => {
  const { ctx } = charger('ru');
  const M = ctx.RPMaladies;
  assert.equal(M.nomMaladie({ cle: 'grippe' }), 'Грипп');
  assert.equal(M.nomMaladie({ cle: 'grippe', nom_mj: 'Gastro du sirocco' }), 'Gastro du sirocco');
  assert.equal(M.symptomeAutre({ symptome: 'grippe', symptome_mj: 'Court aux toilettes.' }), 'Court aux toilettes.');
  for (const l of Object.keys(M.T)) for (const c of M.CLES) {
    assert.ok(!M.T[l]['o_' + c].includes(M.T[l]['n_' + c]), l + ' ' + c);
  }
  assert.equal(M.motif({ raison: 'stock_insuffisant', restant: 3 }), 'Недостаточно запасов: осталось 3.');
  assert.equal(M.motif({ raison: 'inconnue' }), 'Сервер отклонил операцию.');
});

test('pharmacie : ordre actif à Novomirsk, ajouté à la salle des ventes de Luthécia, exclu de Pharmanov', () => {
  const data = lire('data.js');
  const ordres = data.match(/\{fn:'pharmacie_medicaments'[^}]*\}/g) || [];
  assert.equal(ordres.length, 2);
  for (const o of ordres) assert.ok(!/bientot/.test(o), o);
  assert.match(data, /excludeOrders: \['acheter_sels_ammoniaque', 'pharmacie_medicaments'\]/);
  assert.match(lire('plateau-router.js'), /fn === 'pharmacie_medicaments'.*ouvrirPharmacie\(\)/);
  assert.match(lire('plateau.html'), /plateau-maladies\.js/);
  assert.match(lire('plateau-personnage.js'), /boutonMedicamentMaladie\(item/);
  assert.match(lire('plateau-pnj.js'), /afficherSymptomesDans\(traitEl, pnjKey\)/);
  assert.match(lire('admin.html'), /admin-maladies\.js/);
});

test('migration : catalogue paramétrable, raccords à ancre unique et contrôle structurel', () => {
  const sql = lire('migrations/20261118060000_maladies_socle.sql');
  for (const c of ['intoxication', 'gueule_de_bois', 'grippe', 'coup_de_chaleur']) assert.match(sql, new RegExp("\\('" + c + "'"));
  assert.match(sql, /'\{"viande_crue":15/);
  assert.match(sql, /'\{"verre":30,"verres_sans_risque":2\}'/);
  assert.match(sql, /'grippe',\s+'\{"INT":-2\}',\s+15,/);
  for (const f of ['pa_repos_nocturne', 'inventaire_consommer', 'matiere_brute_manger_interne', 'tournee_cloturer_boire',
                   'sovarka_maison_agir', 'militaire_bataille_combattants']) assert.ok(sql.includes("pg_get_functiondef('public." + f), f);
  assert.match(sql, /controle structurel en echec/);
  assert.match(sql, /PERFORM public\.admin_exiger\(\);/);
  assert.ok(!/goulag/i.test(sql));
  // Les lectures des joueurs ne renvoient jamais le nom de la maladie d'autrui : seulement la clé de symptôme.
  const symptomes = sql.slice(sql.indexOf('FUNCTION public.maladies_symptomes_piece'), sql.indexOf('-- ── Pharmacie'));
  assert.ok(!/nom_mj/.test(symptomes));
});
