'use strict';
// Mission du 27/11/2026 (soir), étape 2 : « Produire une fuite » aux Archives Gouvernementales (Républia), sur le modèle
// du vol d'archives d'écoute : information réelle tirée au hasard, archive dans l'inventaire, mêmes risques (moteur commun
// du vol). Épreuves SQL passées dans une transaction annulée en production avant application.
// Usage : node --test outils/bancs/banc-fuite-archives-20261127.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const MIG = lire('migrations/20261127230000_fuite_archives_gouvernement.sql');

test('serveur : information réelle, archive en inventaire, moteur commun du vol, plus de gain sans contenu', () => {
  assert.match(MIG, /DELETE FROM public\.ordres_generiques WHERE fn = 'fuite_info'/);
  const info = MIG.slice(MIG.indexOf('FUNCTION public.archives_gouv_information_interne'));
  assert.match(info, /fuite_traces_eligibles\(m\.name\)/);
  assert.match(info, /caisses_batiments c\s+WHERE c\.id LIKE p_pays \|\| '\\_gouvernement%'/);
  const f = MIG.slice(MIG.indexOf('FUNCTION public.archives_gouv_fuite'));
  assert.ok(f.indexOf("'archives_vides'") < f.indexOf('payer_ordre('), 'rien à prendre : refus avant paiement');
  assert.match(f, /crim_temoin_interne\(a, NULL\)/);
  assert.equal((f.match(/crim_resoudre_interne\('fuite_info'/g) || []).length, 2);
  assert.match(f, /'acte_peine_echec', 'voler_archives_ecoute'/);
  assert.match(f, /crim_combat_ouvrir_interne\(/);
  assert.match(f, /inventaire_deposer_interne\(a, v_objet, true\)/);
  assert.match(f, /'type', 'archive'/);
  assert.doesNotMatch(f, /'pop'|'inf'/);
  assert.match(f, /p\.country = 'soviet'/, 'la fuite de Sovarka reste la sienne');
});

test('écran : route Républia, Sovarka inchangée, description honnête', () => {
  const r = lire('plateau-router.js');
  assert.ok(r.indexOf("state.country === 'soviet' && fn === 'fuite_info'") < r.indexOf("if (fn === 'fuite_info') { produireFuiteArchives(); return; }"));
  const html = lire('plateau.html');
  assert.ok(html.indexOf('plateau-fuite-archives.js') > 0 && html.indexOf('plateau-fuite-archives.js') < html.indexOf('src="plateau-router.js'));
  const d = lire('data.js');
  assert.doesNotMatch(d, /fuite_info: +\{pop:10/);
  assert.match(d.match(/\{fn:'fuite_info'[^\n]*/)[0], /pièce réelle des archives/);
  const src = lire('plateau-fuite-archives.js');
  assert.match(src, /sbRpcVerdict\('archives_gouv_fuite'/);
  assert.doesNotMatch(src, /Math\.random/);
});

test('textes : neuf langues, mêmes clés', () => {
  const ctx = { window: {} };
  vm.runInNewContext(lire('plateau-fuite-archives.js'), ctx);
  const T = ctx.window.RP_FUITE_ARCHIVES_T, cles = o => Object.keys(o).sort().join() + '|' + Object.keys(o.r).sort().join();
  assert.deepEqual(Object.keys(T), ['fr', 'en', 'es', 'zh-TW', 'ru', 'ko', 'ar', 'pt-BR', 'de']);
  for (const l of Object.keys(T)) assert.equal(cles(T[l]), cles(T.fr), l);
});
