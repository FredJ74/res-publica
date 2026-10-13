-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 13 OCTOBRE 2026
--
-- Registre Supabase : version 20261013074409 (UTC), nom
-- `presse_la_garde_judiciaire_du_journal_passe_par_une_porte_definer`.
-- Le registre passe de 704 a 705 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 e02b02d87656bb36cc48428b779995a0, 4584 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LA GARDE DU JOURNAL PASSE PAR UNE PORTE SECURITY DEFINER
--
-- CORRECTIF DE LA MIGRATION PRECEDENTE, APPLIQUE DANS LA MEME HEURE. Sa policy lisait
-- `public.justice_faits_publics` dans un sous-select. Une policy RLS s'execute avec les DROITS DE
-- L'APPELANT, et ce registre n'accorde aucun droit client : chaque insertion cliente mourait en
-- « permission denied for table justice_faits_publics ». Le navigateur ne pouvait donc plus deposer
-- ni un faux fait judiciaire -- ce qui etait voulu -- ni une nomination, ce qui ne l'etait pas.
--
-- C'EST LE BANC DES PARCOURS QUI L'A TROUVE, et c'est l'interet de sa contre-mesure : l'epreuve F6
-- ne mesure pas seulement que le faux est refuse, elle mesure que le VRAI passe. Une garde qui ferme
-- tout serait verte sur la moitie d'une epreuve qui n'en aurait eu qu'une.
--
-- LA QUESTION DEVIENT PUBLIQUE, LE REGISTRE RESTE FERME. `fait_judiciaire_declare(type)` lit le
-- registre avec ses droits a elle et ne rend qu'un booleen. Elle ne dit rien d'autre.
--
-- PREUVES STRUCTURELLES -- 7.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- CORRECTIF IMMEDIAT : LA GARDE POSEE A L'INSTANT FERMAIT TOUT LE JOURNAL AU NAVIGATEUR.
--
-- La policy d'insertion de `chronique_nationale` lisait `public.justice_faits_publics` dans un
-- sous-select. Une policy RLS s'execute avec les DROITS DE L'APPELANT -- et le registre des faits
-- judiciaires n'accorde AUCUN droit client. Resultat : chaque insertion cliente mourait en
-- `permission denied for table justice_faits_publics`, donc le navigateur ne pouvait plus deposer
-- NI un faux fait judiciaire (ce qui etait voulu) NI une nomination (ce qui ne l'etait pas).
--
-- C'EST LE BANC DES PARCOURS QUI L'A TROUVE, et c'est tout l'interet de sa contre-mesure : son
-- epreuve F6 ne mesure pas seulement que le faux est refuse, elle mesure que le VRAI passe. Une
-- garde qui ferme tout est verte sur la moitie d'une epreuve qui n'en aurait eu qu'une.
--
-- LA GARDE PASSE DONC PAR UNE PORTE SECURITY DEFINER, qui lit le registre avec ses droits a elle
-- et ne rend qu'un booleen. Le registre reste ferme ; la question « ce type est-il un fait
-- judiciaire declare ? » devient publique, et elle ne dit rien d'autre.

CREATE OR REPLACE FUNCTION public.fait_judiciaire_declare(p_type text)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT EXISTS (SELECT 1 FROM public.justice_faits_publics f
                  WHERE f.chronique_type = p_type);
$$;
REVOKE ALL ON FUNCTION public.fait_judiciaire_declare(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fait_judiciaire_declare(text) TO authenticated, service_role;

DROP POLICY IF EXISTS chronique_nationale_ecriture_acteur ON public.chronique_nationale;

CREATE POLICY chronique_nationale_ecriture_acteur
  ON public.chronique_nationale FOR INSERT TO authenticated
  WITH CHECK (public.acteur_identifie() AND NOT public.fait_judiciaire_declare(type));

DO $$
DECLARE v_c text; v_n integer;
BEGIN
  -- P1 -- la policy ne lit plus le registre directement.
  SELECT with_check INTO v_c FROM pg_policies
   WHERE schemaname = 'public' AND tablename = 'chronique_nationale' AND cmd = 'INSERT';
  IF v_c IS NULL THEN RAISE EXCEPTION 'P1 ECHOUEE -- aucune policy d''insertion'; END IF;
  IF v_c ILIKE '%justice_faits_publics%' THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- la policy lit encore le registre en direct : %', v_c; END IF;
  IF v_c NOT ILIKE '%fait_judiciaire_declare%' OR v_c NOT ILIKE '%acteur_identifie%' THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- la garde a perdu une moitie : %', v_c; END IF;

  -- P3 -- la porte est SECURITY DEFINER, sinon elle ne resout rien.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    AND n.nspname = 'public'
   WHERE p.proname = 'fait_judiciaire_declare' AND p.prosecdef;
  IF v_n <> 1 THEN RAISE EXCEPTION 'P3 ECHOUEE -- la porte n''est pas SECURITY DEFINER'; END IF;

  -- P4 -- elle est appelable par le client (sans quoi la policy echoue de nouveau), et son
  -- search_path est fige.
  SELECT count(*) INTO v_n FROM information_schema.routine_privileges
   WHERE routine_schema = 'public' AND routine_name = 'fait_judiciaire_declare'
     AND grantee = 'authenticated';
  IF v_n < 1 THEN RAISE EXCEPTION 'P4 ECHOUEE -- le client ne peut pas appeler la porte'; END IF;
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    AND n.nspname = 'public'
   WHERE p.proname = 'fait_judiciaire_declare'
     AND array_to_string(coalesce(p.proconfig, ARRAY[]::text[]), ',') LIKE '%search_path%';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P5 ECHOUEE -- le search_path n''est pas fige'; END IF;

  -- P6 -- LE REGISTRE RESTE FERME AU CLIENT : c'est la porte qui le lit, pas lui.
  SELECT count(*) INTO v_n FROM information_schema.table_privileges
   WHERE table_schema = 'public' AND table_name = 'justice_faits_publics'
     AND grantee IN ('anon', 'authenticated', 'PUBLIC');
  IF v_n <> 0 THEN RAISE EXCEPTION 'P6 ECHOUEE -- le registre s''est ouvert au client'; END IF;

  -- P7 -- ET ELLE REPOND JUSTE : vrai sur un type judiciaire declare, faux sur une nomination.
  IF NOT public.fait_judiciaire_declare('justice_condamnation') THEN
    RAISE EXCEPTION 'P7 ECHOUEE -- un fait judiciaire declare n''est pas reconnu'; END IF;
  IF public.fait_judiciaire_declare('nomination') THEN
    RAISE EXCEPTION 'P7 ECHOUEE -- une nomination est prise pour un fait judiciaire'; END IF;
  IF public.fait_judiciaire_declare(NULL) THEN
    RAISE EXCEPTION 'P7 ECHOUEE -- un type nul est pris pour un fait judiciaire'; END IF;

  RAISE NOTICE 'LES 7 PREUVES SONT VERTES.';
END $$;
