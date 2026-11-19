'use strict';
// Maladies — lot 2b : contrôle à la réception, bandelettes réactives, fraude alimentaire, réglages du MJ.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '../..');
const lire = f => fs.readFileSync(path.join(root, f), 'utf8');

test('migration : contrôle après les refus de stock et de prix, fraude tracée, bandelettes', () => {
  const sql = lire('migrations/20261118071000_aliments_reception_bandelettes.sql');
  assert.match(sql, /\('detection_base', 70\), \('detection_bandelette', 95\), \('prix_bandelette', 4\)/);
  assert.match(sql, /'fraude_alimentaire'/);
  for (const f of ['commerce_apporter_matiere', 'fonds_matiere_apporter', 'pharmacie_etat']) assert.ok(sql.includes("'public." + f + '('), f);
  // Le contrôle s'ancre sur le calcul du montant : il vient après les refus « stock plein » et « prix inconnu ».
  assert.match(sql, /ARRAY\['  v_total := round\(v_prix \* p_qte, 2\);',\s+'  -- Contrôle à la réception/);
  assert.ok(!/v_recus, v_prix/.test(sql), 'le registre des apports garde la quantité livrée');
  assert.match(sql, /controle structurel en echec/);
  const mj = lire('migrations/20261118071500_aliments_parametres_mj.sql');
  assert.match(mj, /PERFORM public\.admin_exiger\(\);/);
  assert.match(lire('admin.html'), /admAlimentsCharger\(\)/);
});

test('écran : bandelettes et refus dans les neuf langues', () => {
  const ctx = { console, setTimeout: () => 0, setInterval: () => 0, Date, Math, JSON, Set, Map, Number, String, Object, Array,
    showToast: () => {}, RPPlateauI18n: { language: () => 'ar' }, document: undefined };
  ctx.window = ctx; ctx.globalThis = ctx;
  vm.createContext(ctx);
  vm.runInContext(lire('plateau-maladies.js'), ctx);
  for (const l of Object.keys(ctx.RPMaladies.T)) {
    assert.match(ctx.RPMaladies.T[l].foodRefused, /\{n\}/, l);
    assert.match(ctx.RPMaladies.T[l].stripsDeposited, /\{reserve\}/, l);
  }
  assert.equal(ctx.nomObjetMaladie({ type: 'bandelette_reactive' }), 'شرائط كاشفة');
  assert.match(ctx.boutonBandelettes({ type: 'bandelette_reactive', qty: 3 }, ''), /deposerBandelettes\(3\)/);
  assert.match(lire('plateau-maladies.js'), /'pharmacie_bandelettes_acheter'/);
  assert.match(lire('plateau-personnage.js'), /boutonBandelettes\(item, 'flex:1/);
});
