'use strict';
// Climat — lot 5 : canicule, orage (groupe électrogène), crue (sacs de sable, pertes), état de catastrophe naturelle, brouillard.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '../..');
const lire = f => fs.readFileSync(path.join(root, f), 'utf8');

test('migration : décisions de Fred (crue 20 %, 50 % au prix de base, sacs par défaut, extension au choix du PM)', () => {
  const sql = lire('migrations/20261119100000_climat_effets.sql');
  assert.match(sql, /\('crue_perte_pct', 20\), \('sacs_protection_pct', 100\), \('catastrophe_part_pct', 50\), \('catastrophe_delai_h', 72\)/);
  assert.match(sql, /AND \(protege OR coalesce\(p_etendre, false\)\)/);
  assert.match(sql, /'cout_sacs'.*\n\s+'cout_tous'/);
  assert.match(sql, /poste->>'id' = 'min_int'/);
  assert.match(sql, /poste->>'id' = 'pm'/);
  assert.match(sql, /v_pa := greatest\(0, p\.pa - 3\)/);
  assert.match(sql, /'coup_de_chaleur'/);
  assert.match(sql, /'raison','batiment_inonde'/);
  assert.match(sql, /'groupe-electrogene'/);
  assert.match(sql, /climat_brouillard_modificateurs_interne/);
  // Criminalité non touchée : aucune fonction d'acte illégal ni de détection n'est raccordée.
  for (const f of ['crime_detecter_interne', 'police_detection', 'securite_ordre_detection']) assert.ok(!sql.includes(f), f);
  assert.match(lire('migrations/20261119100500_catastrophe_caisse_pm.sql'), /_gouvernement-pm/);
});

test('sacs de sable : un sac protège entièrement pour une crue (décision définitive du 21/11, règle du 19/11 retirée)', () => {
  const sql = lire('migrations/20261121130000_climat_horaire_cadence_catastrophe_sacs.sql');
  assert.match(sql, /DROP FUNCTION IF EXISTS public\.climat_sacs_reste_pct_interne\(numeric\);/);
  assert.match(sql, /DELETE FROM public\.aliments_parametres WHERE cle IN \('sac_protection_pct', 'sacs_plafond', 'sacs_protection_pct'\);/);
  assert.match(sql, /ALTER TABLE public\.climat_protections DROP COLUMN IF EXISTS sacs;/);
  assert.match(sql, /public\.inventaire_retirer\(inventory, 'sac_de_sable', 1\)/);
  const js = lire('plateau-climat.js');
  assert.match(js, /global\.showToast\(texte\('o_sac_de_sable'\), texte\('posed'\), true\);/);
  assert.match(js, /posed: 'Sac de sable posé : à la prochaine crue, ce lieu restera ouvert et gardera tous ses stocks\.'/);
  assert.ok(!/plafond 9/.test(js));
});

test('écran : boutique, sacs, groupe, catastrophe (deux options et coûts) dans les neuf langues', () => {
  const ctx = { console, setTimeout: () => 0, setInterval: () => 0, Date, Math, JSON, Set, Map, Number, String, Object, Array,
    RPPlateauI18n: { language: () => 'pt-BR' }, document: undefined };
  ctx.window = ctx; ctx.globalThis = ctx;
  vm.createContext(ctx);
  vm.runInContext(lire('plateau-climat.js'), ctx);
  const T = ctx.RPClimat.T;
  for (const l of Object.keys(T)) {
    assert.deepEqual(Object.keys(T[l]).sort(), Object.keys(T.fr).sort(), l);
    assert.match(T[l].catSacs, /\{cout\}/, l); assert.match(T[l].catTous, /\{cout\}/, l);
  }
  assert.equal(ctx.RPClimat.nomObjet({ stackKey: 'sac_de_sable' }), 'Saco de areia');
  assert.match(ctx.boutonPoserSacs({ stackKey: 'sac_de_sable' }, ''), /poserSacsSable\(\)/);
  assert.match(ctx.boutonGroupeRemplir({ generique_id: 'groupe-electrogene', a_moi: true }), /groupeRemplir\(\)/);
  const forum = lire('forum.js');
  assert.match(forum, /catastrophe_proposer: \{ fn:'catastropheProposer'/);
  assert.match(forum, /catastrophe_examiner: \{ fn:'catastropheExaminer'/);
  assert.equal((lire('i18n/forum-ui.js').match(/"catastrophe_examiner"/g) || []).length, 9);
  assert.match(lire('plateau-router.js'), /fn === 'boutique_climat'.*ouvrirBoutiqueClimat\(\)/);
  assert.match(lire('plateau-equipements.js'), /'groupe-electrogene': 'Groupe électrogène'/);
});
