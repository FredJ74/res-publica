'use strict';
// Climat — lot 4 : blizzard (graisses, tableau de la grippe), contagion, image du furet.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '../..');
const lire = f => fs.readFileSync(path.join(root, f), 'utf8');

test('migration : tableau du § 5, graisse −5 points, contagion 30/70 au niveau le plus élevé', () => {
  const sql = lire('migrations/20261119090000_climat_blizzard_grippe.sql');
  assert.match(sql, /WHEN p_pa >= 26 THEN 0 WHEN p_pa >= 21 THEN 10 WHEN p_pa >= 16 THEN 25\s+WHEN p_pa >= 11 THEN 50 WHEN p_pa >= 6 THEN 65 ELSE 80/);
  assert.match(sql, /CASE WHEN v_cle IS NOT NULL THEN 5 ELSE 0 END/);
  assert.match(sql, /v_pa := greatest\(0, p\.pa - 3\)/);
  assert.match(sql, /\('poissonniere-novomirsk', 'soviet', 'capitale', 'poissonniere-novomirsk', 'etal_poissonniere', 'graisse_castor'\)/);
  assert.match(sql, /\('marche-krasnov',\s+'soviet', 'ville_b',\s+'marche',\s+'marche_ext',\s+'graisse_ours'\)/);
  assert.match(sql, /\? 'pharmacie'/);
  assert.match(sql, /THEN 'interaction' ELSE 'piece' END/);
  assert.match(sql, /jour < v_jour/);
  assert.match(sql, /images\/objet-graisse-castor\.webp/);
  assert.match(lire('migrations/20261119090500_furet_image.sql'), /images\/objet-furet-renifleur\.webp/);
  assert.ok(!/goulag_/i.test(sql));
});

test('écran : graisses et effets du blizzard dans les neuf langues, ordres, boutique PJ', () => {
  const ctx = { console, setTimeout: () => 0, setInterval: () => 0, Date, Math, JSON, Set, Map, Number, String, Object, Array,
    RPPlateauI18n: { language: () => 'ru' }, document: undefined };
  ctx.window = ctx; ctx.globalThis = ctx;
  vm.createContext(ctx);
  vm.runInContext(lire('plateau-climat.js'), ctx);
  const T = ctx.RPClimat.T;
  for (const l of Object.keys(T)) assert.deepEqual(Object.keys(T[l]).sort(), Object.keys(T.fr).sort(), l);
  assert.equal(ctx.RPClimat.nomObjet({ stackKey: 'graisse_ours' }), 'Банка медвежьего жира');
  assert.match(ctx.climatGraissesBoutiqueHtml({ typesAutorises: ['pharmacie'] }), /ouvrirGraisses\(\)/);
  assert.equal(ctx.climatGraissesBoutiqueHtml({ typesAutorises: ['vetements'] }), '');
  const data = lire('data.js');
  assert.equal((data.match(/\{fn:'acheter_graisse'/g) || []).length, 2);
  assert.match(lire('plateau-router.js'), /fn === 'acheter_graisse'.*ouvrirGraisses\(\)/);
  assert.match(lire('plateau-commerce-pj.js'), /climatGraissesBoutiqueHtml\(f\)/);
  assert.match(lire('plateau-maladies.js'), /images\/objet-furet-renifleur\.webp/);
  for (const f of ['objet-furet-renifleur', 'objet-graisse-castor', 'objet-graisse-ours', 'objet-sac-de-sable'])
    assert.ok(fs.existsSync(path.join(root, 'images', f + '.webp')), f);
});
