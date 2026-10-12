-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 12 OCTOBRE 2026
--
-- Registre Supabase : version 20261012094344 (UTC), nom
-- `parquet_le_classement_ministeriel_perd_son_cout`.
-- Le registre passe de 676 a 677 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 eea786aef85d86436d057f8a7900f746, 3191 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LE PARQUET (6/7) -- L'ORDRE MINISTERIEL DE CLASSEMENT PERD SON COUT
--
-- `annuler_poursuites` (2 PA) a quitte data.js avec la porte qu'il appelait. Sa ligne de
-- `ordres_couts` part avec lui : il coutait 2 PA, donc il traversait bien `payer_ordre`, et
-- laisser son cout declare aurait laisse un cout pour un acte que plus rien ne peut demander.
-- C'est la difference avec les 22 ordres GRATUITS non declares du lot 4D, qui ne consultent
-- jamais le miroir. Meme raisonnement que `se_former` le matin meme.
--
-- ET LE COMPTE DU MIROIR EST RECTIFIE AU PASSAGE. referentiels.json annoncait 406 lignes et sa
-- propre prose signalait trois nombres divergents (407 declare, 406 en base, 405 au generateur).
-- MESURE : la base en portait 405 avant cette suppression, 404 apres.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- L'ORDRE MINISTERIEL DE CLASSEMENT PERD SON COUT DECLARE
-- 12 octobre 2026
--
-- `annuler_poursuites` (2 PA, « Classer une plainte ») a quitte data.js avec la porte qu'il
-- appelait : `plainte_classer_ministere` est supprimee, l'opportunite des poursuites appartient
-- au parquet. Sa ligne de `ordres_couts` -- le miroir du canon -- doit partir avec lui, sinon le
-- miroir declare un cout pour un ordre qui n'existe plus.
--
-- ET IL FALLAIT LA RETIRER, pas seulement la laisser dormir : l'ordre coutait 2 PA, donc il
-- traversait bien `deduireCoutOrdre` et `payer_ordre`. C'est la difference avec les 22 ordres
-- GRATUITS non declares que l'audit du lot 4D a inventories -- ceux-la ne consultent jamais le
-- miroir. Meme raisonnement que `se_former` le 12 octobre au matin.
--
-- CE N'EST PAS UNE REGENERATION DU MIROIR. Aucune des autres lignes n'est touchee, et l'interdit
-- du lot 4D est respecte : retirer la ligne d'un ordre QUI N'EXISTE PLUS n'est pas reparer la
-- derive de la sentinelle, c'est l'empecher de grandir d'une ligne morte de plus.
--
-- `parquet`, le nouvel ecran du Procureur, n'est PAS ajoute au miroir, et ce n'est pas un oubli :
-- il coute 0 PA et 0 FR, donc `deduireCoutOrdre` ne l'envoie jamais a `payer_ordre`
-- (`pa > 0 || cost > 0`, plateau-core.js). Y declarer un cout serait declarer un cout qui
-- n'existe pas. Il rejoint les ecrans institutionnels gratuits, comme `gerer_budget_caserne` et
-- `seance_parlementaire`.
--
-- ET LE COMPTE DU MIROIR EST RECTIFIE AU PASSAGE. referentiels.json annoncait `lignes: 406` et sa
-- propre prose signalait deja trois nombres divergents (407 declare, 406 en base, 405 au
-- generateur). MESURE : la base en portait 405 avant cette suppression, et 404 apres. La preuve
-- P4 porte donc sur le compte REEL, et le champ `lignes` est recale dans le meme lot.
DELETE FROM public.ordres_couts WHERE fn = 'annuler_poursuites';

DO $preuves$
DECLARE v_n integer;
BEGIN
  -- P1 : L'ORDRE N'A PLUS DE COUT DECLARE.
  IF EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'annuler_poursuites') THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- annuler_poursuites a encore un cout declare';
  END IF;

  -- P2 : ET LA PORTE QU'IL APPELAIT N'EXISTE PLUS NON PLUS. Les deux disparaissent ensemble, ou
  --      l'une des deux serait un piege : un cout sans porte, ou une porte sans cout.
  SELECT count(*) INTO v_n FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace AND p.proname = 'plainte_classer_ministere';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P2 ECHOUEE -- la porte ministerielle survit'; END IF;

  -- P3 : LE NOUVEL ECRAN DU PARQUET N'A PAS DE COUT DECLARE, et c'est voulu : a 0 PA et 0 FR il
  --      ne traverse jamais la verification du miroir.
  IF EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'parquet') THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- un cout a ete declare pour un ecran gratuit';
  END IF;

  -- P4 : LE MIROIR N'A PERDU QU'UNE LIGNE -- 405 mesurees avant, 404 apres.
  SELECT count(*) INTO v_n FROM public.ordres_couts;
  IF v_n <> 404 THEN RAISE EXCEPTION 'P4 ECHOUEE -- % ligne(s) au miroir au lieu de 404', v_n; END IF;

  RAISE NOTICE 'LES 4 PREUVES SONT VERTES.';
END
$preuves$;
