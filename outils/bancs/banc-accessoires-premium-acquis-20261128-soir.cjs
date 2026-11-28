'use strict';
// Mission du 28/11/2026 (soir), points 5, 6 et 7 de Fred (questions 9 à 14, 19 et 20 de l'après-midi) :
//   5. achat des accessoires de club non limité ; seul le port l'est (trois objets, un par type : crim_revetir) ;
//   6. accessoire personnalisé gratuit pendant la bêta, renouvellement hebdomadaire de l'abonné puis achat à l'unité,
//      renouvellement consommé dès que l'image existe ; fonction Edge déployée ;
//   7. fin d'abonnement : commerce premium acquis dès son premier usage (en plus des options attachées à un lieu).
// Épreuves SQL passées en production dans une transaction annulée (« TESTS_OK ») avant application, puis essai réel de bout en
// bout avec un personnage de test (commande bêta, deuxième écharpe acceptée, image créée par la fonction Edge, annulation
// refusée après l'image, livraison dans l'inventaire), personnage et compte supprimés ensuite.
// Usage : node --test outils/bancs/banc-accessoires-premium-acquis-20261128-soir.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const MIG = lire('migrations/20261128210000_accessoires_premium_acquis.sql');
const bloc = (debut, fin) => MIG.slice(MIG.indexOf(debut), fin ? MIG.indexOf(fin, MIG.indexOf(debut) + 1) : undefined);

test('migration : transaction, remplacements contrôlés par marque, aucun ajout de blocage', () => {
  assert.match(MIG, /^BEGIN;$/m);
  assert.match(MIG, /^COMMIT;$/m);
  assert.match(MIG, /IF n <> p_n THEN RAISE EXCEPTION/);
  for (const m of ['accessoire_achat_libre_v1', 'commerce_premium_acquis_v1']) assert.match(MIG, new RegExp("'" + m + "'\\);"), m);
  assert.match(MIG, /DROP FUNCTION IF EXISTS public\.accessoire_club_type_possede_interne\(text, jsonb, text\);/);
  // Le code exécutable (hors commentaires) ne renvoie plus jamais le refus d'achat d'un deuxième objet du même type.
  const code = MIG.split('\n').filter(l => !/^\s*--/.test(l)).join('\n');
  const apres = code.slice(code.indexOf('$b$ /* accessoire_achat_libre_v1'));
  assert.doesNotMatch(apres, /'accessoire_type_deja_possede'/);
});

test('point 5 : le port reste limité par crim_revetir (trois objets, un par catégorie), achat libre', () => {
  const mig3 = lire('migrations/20261128110000_accessoires_club_revetables.sql');
  assert.match(mig3, /IF v_portes >= 3 THEN RETURN jsonb_build_object\(''ok'', false, ''raison'', ''trois_objets_revetus_max''\)/);
  // Catégorie de port = « revetable » (accessoire_echarpe…) : revêtir une deuxième écharpe retire d'office la première.
  assert.match(mig3, /'revetable','accessoire_'\|\|p_accessoire|''revetable'',''accessoire_''\|\|p_accessoire/);
  const cmd = bloc('FUNCTION public.accessoire_personnalise_commander', 'FUNCTION public.accessoire_personnalise_annuler');
  assert.doesNotMatch(cmd, /type_possede|deja_possede/);
});

test('point 6 : bêta, puis renouvellement de l’abonné, puis crédit à l’unité ; sinon achat à l’unité', () => {
  const src = bloc('FUNCTION public.accessoire_personnalise_source_interne', 'REVOKE ALL ON FUNCTION public.accessoire_personnalise_source_interne');
  const iBeta = src.indexOf("premium_beta_interne() THEN 'beta'"), iAbo = src.indexOf("THEN 'abonnement'"), iUnite = src.indexOf("THEN 'unite'");
  assert.ok(iBeta > 0 && iAbo > iBeta && iUnite > iAbo, 'ordre bêta → abonnement → unité');
  assert.match(src, /r\.semaine = public\.premium_semaine_interne\(\) AND r\.source = 'abonnement'/);
  assert.match(src, /d\.produit = 'accessoire_personnalise'\s+AND d\.revoque_le IS NULL AND d\.consomme_le IS NULL/);
  const cmd = bloc('FUNCTION public.accessoire_personnalise_commander', 'FUNCTION public.accessoire_personnalise_annuler');
  assert.match(cmd, /'raison', 'achat_unite_requis'/);
  assert.match(cmd, /UPDATE public\.premium_droits SET consomme_le = now\(\), cible = v_id::text WHERE id = v_droit;/);
  assert.match(cmd, /v_achat := 'unite:' \|\| v_droit;/);
  assert.match(cmd, /VALUES \(p\.user_id, v_sem, 'accessoire', v_id::text, 'beta'\)/);
  assert.match(cmd, /now\(\), v_achat\);/);
  assert.match(MIG, /REVOKE ALL ON FUNCTION public\.accessoire_personnalise_source_interne\(uuid\) FROM PUBLIC, anon, authenticated;/);
  for (const f of ['accessoire_personnalise_commander(text, text)', 'accessoire_personnalise_annuler(uuid)', 'accessoire_personnalise_offre()'])
    assert.ok(MIG.includes('REVOKE ALL ON FUNCTION public.' + f + ' FROM PUBLIC, anon;') && MIG.includes('GRANT EXECUTE ON FUNCTION public.' + f + ' TO authenticated;'), f);
});

test('point 6 : consommé dès que l’image existe ; rendu seulement si aucune image', () => {
  const ann = bloc('FUNCTION public.accessoire_personnalise_annuler', 'REVOKE ALL ON FUNCTION public.accessoire_personnalise_annuler');
  assert.match(ann, /a\.etat <> 'commande' OR a\.apercu_path IS NOT NULL OR v_src NOT IN \('abonnement', 'beta', 'unite'\)/);
  assert.match(ann, /DELETE FROM public\.premium_renouvellements/);
  assert.match(ann, /UPDATE public\.premium_droits SET consomme_le = NULL, cible = NULL/);
  assert.match(MIG, /'logement'::text, 'accessoire'::text/, 'historique des images de la fonction Edge accepté');
});

test('point 6 : fonction Edge (copie de la version déployée) : commande réglée exigée, secret OPENAI_API_KEY', () => {
  const ef = lire('supabase/edge-functions/accessoire-personnalise/index.ts');
  assert.match(ef, /DÉPLOYÉE \(feu vert\)/);
  assert.match(ef, /if\(!acc\.paiement_confirme_le\)return out\(\{error:"Payment required"\},402\);/);
  assert.match(ef, /Deno\.env\.get\("OPENAI_API_KEY"\)/);
  assert.match(ef, /type_visuel:"accessoire"/);
  assert.doesNotMatch(ef, /sk-[A-Za-z0-9]{10,}/, 'aucune clé écrite');
});

test('point 7 : commerce premium acquis au premier dépassement d’un plafond gratuit par un abonné', () => {
  const f = bloc('FUNCTION public.premium_commerce_usage_noter_interne', 'REVOKE ALL ON FUNCTION public.premium_commerce_usage_noter_interne');
  assert.match(f, /public\.premium_beta_interne\(\) OR NOT public\.premium_abonne_interne\(v_user\) THEN RETURN;/);
  assert.match(f, /types_commerce_max_gratuit/);
  assert.match(f, /references_max_gratuit/);
  assert.match(f, /PERFORM public\.premium_option_source_interne\(v_user, 'commerce_premium', p_fonds_id\)/);
  assert.match(MIG, /premium_commerce_usage_noter_interne\(p_fonds_id, v_data::jsonb, coalesce\(array_length\(v_connus, 1\), 0\), NULL\)/);
  assert.match(MIG, /premium_commerce_usage_noter_interne\(p_fonds_id, v_data::jsonb, NULL, v_n \+ 1\)/);
  assert.match(MIG, /REVOKE ALL ON FUNCTION public\.premium_commerce_usage_noter_interne\(text, jsonb, integer, integer\) FROM PUBLIC, anon, authenticated;/);
});

test('écran : neuf langues, plus de limite d’achat, bêta gratuite, achat à l’unité par l’écran de paiement commun', () => {
  const src = lire('plateau-accessoire-personnalise.js');
  const ctx = { window: {} };
  vm.runInNewContext(src, ctx);
  const T = ctx.window.RP_ACCESSOIRE_PERSONNALISE_T;
  assert.deepEqual(Object.keys(T), ['fr', 'en', 'es', 'zh-TW', 'ru', 'ko', 'ar', 'pt-BR', 'de']);
  const cles = Object.keys(T.fr).filter(k => k !== 'r').sort(), clesR = Object.keys(T.fr.r).sort();
  for (const l of Object.keys(T)) {
    assert.deepEqual(Object.keys(T[l]).filter(k => k !== 'r').sort(), cles, l);
    assert.deepEqual(Object.keys(T[l].r).sort(), clesR, l + ' (refus)');
    for (const k of ['betaBtn', 'betaNote', 'uniteBtn', 'uniteNote', 'acheter', 'consomme']) assert.ok(T[l][k], l + ' ' + k);
    assert.ok(T[l].r.achat_unite_requis, l);
    assert.ok(!('accessoire_type_deja_possede' in T[l].r) && !('aucunType' in T[l]), l + ' : plus de limite d’achat');
    assert.match(T[l].uniteNote, /\{n\}/, l);
    assert.match(T[l].imageIndispo, /\{raison\}/, l);
  }
  assert.doesNotMatch(src, /possedes|libres/);
  assert.match(src, /window\.RPPaiement\.confirmerAchat\('accessoire_personnalise', null, v\.produit\)/);
  assert.match(src, /\{ beta: \['betaNote', 'betaBtn'\], abonnement: \['inclusNote', 'inclus'\], unite: \['uniteNote', 'uniteBtn'\] \}\[v\.source\]/);
  assert.match(src, /data-acc-annuler/);
});

test('inventaire : l’image créée par IA s’affiche (dépôt public accessoires-personnalises)', () => {
  const p = lire('plateau-personnage.js');
  assert.match(p, /item\.type === 'accessoire_club_perso'[\s\S]{0,200}\/storage\/v1\/object\/public\/accessoires-personnalises\//);
});
