'use strict';
// Mission du 27/11/2026 (soir), étape 7 : accessoire personnalisé (buvette des stades) et règle des deux objets revêtus.
// Épreuves SQL passées en transaction annulée en production avant application (troisième objet refusé, +10 popularité au
// port, retrait quand l'objet quitte l'inventaire, aucune livraison sans paiement confirmé).
// Usage : node --test outils/bancs/banc-accessoire-personnalise-20261127.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const MIG = lire('migrations/20261127237000_accessoire_personnalise_revetir.sql');

test('serveur : deux objets revêtus au plus, bonus de popularité suivant l’inventaire, livraison après paiement seulement', () => {
  assert.match(MIG, /IF v_portes >= 2 THEN RETURN jsonb_build_object\('ok', false, 'raison', 'deux_objets_revetus_max'\)/);
  assert.match(MIG, /'revetable', 'accessoire_' \|\| a\.type_accessoire, 'bonus_pop_revetu', 10/);
  assert.match(MIG, /IF a\.paiement_confirme_le IS NULL THEN RETURN jsonb_build_object\('ok', false, 'raison', 'paiement_requis'\)/);
  assert.match(MIG, /GRANT EXECUTE ON FUNCTION public\.accessoire_personnalise_livrer_service\(uuid\) TO service_role/);
  assert.doesNotMatch(MIG, /livrer_service\(uuid\) TO authenticated/);
  assert.match(MIG, /BEFORE UPDATE OF inventory ON public\.personnages_donnees/);
  assert.match(MIG, /'accessoire_personnalise', 'unite'/, 'prix réglé dans la page MJ (premium_produits)');
  assert.match(MIG, /'paiement_ouvert', false/);
  const edge = lire('supabase/edge-functions/accessoire-personnalise/index.ts');
  assert.match(edge, /if\(!acc\.paiement_confirme_le\)return out\(\{error:"Payment required"\},402\)/);
  assert.match(edge, /accessoire_personnalise_livrer_service/);
});

test('écran : ouvert à tous, paiement « bientôt disponible », rien n’est créé ni débité', () => {
  const src = lire('plateau-accessoire-personnalise.js');
  assert.match(src, /sbRpcVerdict\('accessoire_personnalise_offre'/);
  const clic = src.slice(src.indexOf("addEventListener('click'"));
  assert.doesNotMatch(clic, /sbRpc|fetch\(/, 'aucun appel au paiement ni à la création');
  assert.match(clic, /t\('bientot'\)/);
  const data = lire('data.js'), lignes = data.split('\n').filter(l => l.includes("{fn:'acheter_accessoire_personnalise'"));
  assert.equal(lignes.length, 4);
  for (const l of lignes) { assert.doesNotMatch(l, /premium|ti-lock|requiresPremium/); assert.match(l, /\+10 popularité/); }
  assert.match(lire('plateau-router.js'), /fn === 'acheter_accessoire_personnalise'\) \{ ouvrirAccessoirePersonnalise\(\)/);
  assert.doesNotMatch(lire('plateau-organisations-quetes.js'), /function doAcheterAccessoirePersonnalise/);
  assert.match(lire('plateau-criminalite.js'), /r_deux_objets_revetus_max:/);
});

test('textes : neuf langues, mêmes clés', () => {
  const ctx = { window: {} };
  vm.runInNewContext(lire('plateau-accessoire-personnalise.js'), ctx);
  const T = ctx.window.RP_ACCESSOIRE_PERSONNALISE_T, cles = o => Object.keys(o).sort().join() + '|' + Object.keys(o.r).sort().join();
  assert.deepEqual(Object.keys(T), ['fr', 'en', 'es', 'zh-TW', 'ru', 'ko', 'ar', 'pt-BR', 'de']);
  for (const l of Object.keys(T)) assert.equal(cles(T[l]), cles(T.fr), l);
});
