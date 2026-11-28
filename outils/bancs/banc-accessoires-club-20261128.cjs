'use strict';
// Mission du 28/11/2026 (après-midi), étape 3 : accessoires de club revêtables (décision de Fred).
// Standard revêtable +5, personnalisé +5, bonus seulement dans la ville du club (gain réel repris), un de chaque type,
// trois objets revêtus au plus, personnalisation incluse dans l'abonnement (renouvellement d'image de la semaine).
// Épreuves SQL passées en transaction annulée en production avant application (achat, refus du doublon, +5 au port,
// sortie / retour de la ville, autre pays même identifiant de ville, plafond 100, quatrième objet refusé, commande abonné,
// renouvellement hebdomadaire, annulation qui le rend, livraison à +5).
// Usage : node --test outils/bancs/banc-accessoires-club-20261128.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const MIG = lire('migrations/20261128110000_accessoires_club_revetables.sql');

test('migration : transaction, remplacements contrôlés par marque', () => {
  assert.match(MIG, /^BEGIN;$/m);
  assert.match(MIG, /^COMMIT;$/m);
  for (const m of ['revetus_trois_max_v1', 'accessoire_un_par_type_v1', 'accessoire_standard_revetable_v1'])
    assert.match(MIG, new RegExp("'" + m + "'\\);"), m);
  assert.match(MIG, /n <> 1 THEN RAISE EXCEPTION/);
});

test('trois objets revêtus au plus (remplace la règle des deux)', () => {
  assert.match(MIG, /'IF v_portes >= 2 THEN RETURN jsonb_build_object\(''ok'', false, ''raison'', ''deux_objets_revetus_max''\); END IF;'/);
  assert.match(MIG, /IF v_portes >= 3 THEN RETURN jsonb_build_object\(''ok'', false, ''raison'', ''trois_objets_revetus_max''\)/);
});

test('accessoire standard : revêtable, +5, ville du club enregistrée, un de chaque type', () => {
  assert.match(MIG, /''revetable'',''accessoire_''\|\|p_accessoire,''bonus_pop_revetu'',5/);
  assert.match(MIG, /''club_pays'',a\.country,''club_ville'',a\.current_city,''accessoire_id'',gen_random_uuid\(\)/);
  assert.match(MIG, /IF public\.accessoire_club_type_possede_interne\(a\.name,a\.inventory,p_accessoire\) THEN RETURN jsonb_build_object\(''ok'',false,''raison'',''accessoire_type_deja_possede''/);
  // Les commandes personnalisées en cours comptent aussi.
  assert.match(MIG, /a\.acheteur_nom = p_nom AND a\.type_accessoire = p_type AND a\.etat IN \('commande', 'apercu'\)/);
  // Prix inchangés : la migration ne touche pas la ligne des prix.
  assert.doesNotMatch(MIG, /WHEN 'echarpe' THEN 80/);
});

test('accessoire personnalisé : +5 (au lieu de +10), ville du club', () => {
  const livrer = MIG.slice(MIG.indexOf('FUNCTION public.accessoire_personnalise_livrer_service'), MIG.indexOf('GRANT EXECUTE ON FUNCTION public.accessoire_personnalise_livrer_service'));
  assert.match(livrer, /'bonus_pop_revetu', 5,/);
  assert.match(livrer, /'club_pays', a\.pays, 'club_ville', a\.ville/);
  assert.doesNotMatch(livrer, /'bonus_pop_revetu', 10/);
  assert.match(MIG, /GRANT EXECUTE ON FUNCTION public\.accessoire_personnalise_livrer_service\(uuid\) TO service_role/);
});

test('popularité : suit l’inventaire ET la position, gain réel seulement, après les gardes', () => {
  const actif = MIG.slice(MIG.indexOf('FUNCTION public.accessoire_club_bonus_actif_interne'), MIG.indexOf('2. Popularité'));
  assert.match(actif, /crim_porte_ligne_interne\(p_item, p_nom\)/);
  assert.match(actif, /p_item ->> 'club_pays' IS NOT DISTINCT FROM p_pays/);
  assert.match(actif, /p_item ->> 'club_ville' IS NOT DISTINCT FROM p_ville/);
  const trg = MIG.slice(MIG.indexOf('FUNCTION public.accessoires_revetus_popularite_trg'), MIG.indexOf('3. Trois objets'));
  assert.match(trg, /accessoire_club_bonus_actif_interne\(x, OLD\.name, OLD\.country, OLD\.current_city\)/);
  assert.match(trg, /accessoire_club_bonus_actif_interne\(e, NEW\.name, NEW\.country, NEW\.current_city\)/);
  assert.match(trg, /v_gain := greatest\(0, least\(5, \(100 - greatest\(0, least\(100, v_pop\)\)\)::integer\)\)/);
  assert.match(trg, /v_pop := v_pop - coalesce\(\(o ->> 'bonus_pop_applique'\)::numeric, 0\)/);
  assert.match(trg, /DROP TRIGGER IF EXISTS accessoires_revetus_popularite ON public\.personnages_donnees/);
  assert.match(trg, /CREATE TRIGGER zzz_accessoires_club_popularite BEFORE UPDATE ON public\.personnages_donnees/);
  assert.match(trg, /OLD\.country IS DISTINCT FROM NEW\.country\s+OR OLD\.current_city IS DISTINCT FROM NEW\.current_city/);
  // Ordre alphabétique : après navigation_positions_garder et trg_personnages_fusionner_pop, avant zzzz_hg_inventory_revision.
  assert.ok('zzz_accessoires_club_popularite' > 'trg_personnages_fusionner_pop' && 'zzz_accessoires_club_popularite' > 'navigation_positions_garder'
    && 'zzz_accessoires_club_popularite' > 'zz_goulag_fiche_garder' && 'zzz_accessoires_club_popularite' < 'zzzz_hg_inventory_revision');
  // Une fiche écrite par la fiche du navigateur (hors RPC) n'est pas touchée.
  assert.match(trg, /NOT LIKE '\/rpc\/%' THEN RETURN NEW; END IF;/);
});

test('personnalisation : incluse dans l’abonnement, renouvellement de la semaine, unité sinon', () => {
  const cmd = MIG.slice(MIG.indexOf('FUNCTION public.accessoire_personnalise_commander'), MIG.indexOf('FUNCTION public.accessoire_personnalise_annuler'));
  assert.match(cmd, /IF NOT public\.premium_abonne_interne\(p\.user_id\) THEN RETURN jsonb_build_object\('ok', false, 'raison', 'paiement_bientot'\)/);
  assert.match(cmd, /r\.semaine = v_sem AND r\.source = 'abonnement'\) THEN\s+RETURN jsonb_build_object\('ok', false, 'raison', 'renouvellement_hebdo_utilise'\)/);
  assert.match(cmd, /INSERT INTO public\.premium_renouvellements \(user_id, semaine, type_visuel, objet, source\)\s+VALUES \(p\.user_id, v_sem, 'accessoire', v_id::text, 'abonnement'\)/);
  assert.match(cmd, /paiement_confirme_le, achat_id\)[\s\S]*now\(\), 'abonnement:' \|\| v_sem\)/);
  assert.ok(cmd.indexOf('accessoire_type_deja_possede') < cmd.indexOf('premium_abonne_interne'), 'un de chaque type vérifié avant tout');
  assert.doesNotMatch(cmd, /premium_beta_interne/, 'la bêta « tout gratuit » ne rend pas l’accessoire gratuit');
  const ann = MIG.slice(MIG.indexOf('FUNCTION public.accessoire_personnalise_annuler'), MIG.indexOf('INSERT INTO storage.buckets'));
  assert.match(ann, /a\.etat <> 'commande' OR a\.apercu_path IS NOT NULL OR coalesce\(a\.achat_id, ''\) NOT LIKE 'abonnement:%'/);
  assert.match(ann, /DELETE FROM public\.premium_renouvellements/);
  for (const f of ['accessoire_personnalise_commander(text, text)', 'accessoire_personnalise_annuler(uuid)'])
    assert.ok(MIG.includes('REVOKE ALL ON FUNCTION public.' + f + ' FROM PUBLIC, anon;') && MIG.includes('GRANT EXECUTE ON FUNCTION public.' + f + ' TO authenticated;'), f);
  assert.match(MIG, /REVOKE ALL ON FUNCTION public\.accessoire_club_type_possede_interne\(text, jsonb, text\) FROM PUBLIC, anon, authenticated/);
});

test('écran : textes 9 langues, refus nommés, achat standard traduit', () => {
  const src = lire('plateau-accessoire-personnalise.js');
  const ctx = { window: {} };
  vm.runInNewContext(src, ctx);
  const T = ctx.window.RP_ACCESSOIRE_PERSONNALISE_T;
  assert.deepEqual(Object.keys(T), ['fr', 'en', 'es', 'zh-TW', 'ru', 'ko', 'ar', 'pt-BR', 'de']);
  for (const l of Object.keys(T)) {
    // 28/11 soir : l'achat n'est plus limité (refus « accessoire_type_deja_possede » retiré, banc-accessoires-premium-acquis-20261128-soir).
    for (const k of ['achat_unite_requis', 'renouvellement_hebdo_utilise', 'paiement_bientot', 'commande_non_annulable']) assert.ok(T[l].r[k], l + ' ' + k);
    for (const k of ['inclus', 'inclusNote', 'hebdoPris', 'standardNote', 'imageIndispo']) assert.ok(T[l][k], l + ' ' + k);
    assert.match(T[l].intro, /\+5/, l);
    assert.doesNotMatch(T[l].intro, /\+10/, l);
  }
  assert.match(src, /rpc\('accessoire_personnalise_commander'/);
  assert.match(src, /rpc\('accessoire_personnalise_annuler'/);
  assert.equal(typeof ctx.window.accessoireClubMotif, 'function');
  const q = lire('plateau-organisations-quetes.js');
  assert.match(q, /surRefus: \(r\) => \{[\s\S]{0,200}window\.accessoireClubMotif\(r\)/);
  assert.match(q, /window\.accessoireClubNote\(\)/);
  const crim = lire('plateau-criminalite.js');
  for (const l of ['en', 'es', 'de', 'ru', 'ko', 'ar', "'pt-BR'", "'zh-TW'"])
    assert.match(crim, new RegExp('\\n  ' + l + ': \\{ r_trois_objets_revetus_max: '), l);
});

test('descriptions d’ordres : +5 et ville du club, traduites dans les catalogues', () => {
  const data = lire('data.js');
  const std = data.split('\n').filter(l => l.includes("fn:'choisir_accessoire_club'"));
  assert.equal(std.length, 4);
  for (const l of std) assert.match(l, /Revêtu : \+5 popularité tant que vous êtes dans la ville du club\. Un seul de chaque type\./);
  const perso = data.split('\n').filter(l => l.includes("{fn:'acheter_accessoire_personnalise'"));
  for (const l of perso) { assert.match(l, /\+5 popularité tant que vous êtes dans la ville du club/); assert.match(l, /Inclus dans l\\'abonnement/); }
  const ctx = { window: {} };
  vm.runInNewContext(lire('i18n/infobulles-communes-resources.js'), ctx);
  const fr = new Set(ctx.window.RP_INFOBULLES_COMMUNES.map(x => x[0]));
  for (const l of [...std.filter(x => x.includes('du club, à choisir')), ...perso]) {
    const d = /desc:'((?:[^'\\]|\\.)*)'/.exec(l)[1].replace(/\\'/g, "'");
    assert.ok(fr.has(d), d);
  }
  const sov = lire('i18n/sovarka-infobulles-resources.js');
  assert.ok(sov.includes('Écharpe, casquette ou maillot du Dynamo, à choisir. Revêtu : +5 popularité'));
  assert.ok(sov.includes('Écharpe, casquette ou maillot de l’Étoile Rouge, à choisir. Revêtu : +5 popularité'));
});

test('fonction Edge : aperçu avec adresse publique, paiement (ou abonnement) toujours exigé', () => {
  const edge = lire('supabase/edge-functions/accessoire-personnalise/index.ts');
  assert.match(edge, /\["generate","retouch","preview","finalize"\]/);
  assert.match(edge, /getPublicUrl/);
  assert.match(edge, /if\(!acc\.paiement_confirme_le\)return out\(\{error:"Payment required"\},402\)/);
  assert.match(MIG, /VALUES \('accessoires-personnalises', 'accessoires-personnalises', true, 5242880, ARRAY\['image\/png'\]\)/);
});
