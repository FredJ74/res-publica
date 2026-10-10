-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010010521 (UTC), nom `cotisation_horodatage_du_courrier_identique_a_l_original`.
-- Le registre passe de 590 a 591 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 5f1a7ebc08f5d089ab7fe2e9cc5fe2c9, 1945 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- COTISATION : L'HORODATAGE DU COURRIER EST CELUI DE L'ORIGINAL
--
-- PATCH EN PLACE d'un seul fragment : la porte posee quelques minutes plus tot mettait une heure
de Paris sans fuseau, alors que l'original transmettait un `toISOString()`. Rien dans le jeu ne
doit changer de forme a l'occasion d'un deplacement d'autorite. Le corps n'est jamais retape ; un
fragment absent aurait fait echouer la migration bruyamment.
--
-- ELLE VA PAR PAIRE AVEC : aucun fichier du depot.
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- L'ORIGINAL PASSAIT UN toISOString(), PAS UNE HEURE LOCALE. Le courrier de resiliation ecrit par
-- renouvellerCotisationsOrganisations portait `new Date().toISOString()` ; la porte posee quelques
-- minutes plus tot mettait une heure de Paris sans fuseau. Rien dans le jeu ne doit changer de
-- forme a l'occasion d'un deplacement d'autorite : patch EN PLACE du seul fragment concerne.
DO $$
DECLARE v_def text; v_new text;
BEGIN
  SELECT pg_get_functiondef('public.cotisation_renouveler(text,text,integer)'::regprocedure)
    INTO v_def;
  v_new := replace(v_def,
    'to_char(now() AT TIME ZONE ''Europe/Paris'',''YYYY-MM-DD"T"HH24:MI:SS''));',
    'to_char(now() AT TIME ZONE ''UTC'',''YYYY-MM-DD"T"HH24:MI:SS.MS"Z"''));');
  IF v_new = v_def THEN
    RAISE EXCEPTION 'le fragment d''horodatage du courrier est introuvable : rien patche';
  END IF;
  EXECUTE v_new;
END $$;

DO $$
DECLARE v_def text;
BEGIN
  SELECT pg_get_functiondef('public.cotisation_renouveler(text,text,integer)'::regprocedure)
    INTO v_def;
  IF v_def LIKE '%Europe/Paris%' THEN
    RAISE EXCEPTION 'P1 : l''heure locale subsiste dans le corps'; END IF;
  -- Les DEUX horodatages du corps sont desormais le meme format ISO que cote JS : celui du
  -- courrier et celui de derniereCotisationDate.
  IF (length(v_def) - length(replace(v_def, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"', ''))) / 29 <> 2 THEN
    RAISE EXCEPTION 'P2 : % horodatage(s) ISO au lieu de 2',
      (length(v_def) - length(replace(v_def, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"', ''))) / 29; END IF;
  IF coalesce(array_to_string((SELECT proacl::text[] FROM pg_proc p JOIN pg_namespace n
       ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='cotisation_renouveler'),
       ' | '), '(defaut)') <> 'postgres=X/postgres | service_role=X/postgres' THEN
    RAISE EXCEPTION 'P3 : le patch a rouvert les droits'; END IF;
  RAISE NOTICE 'horodatage du courrier aligne : 3 preuves conformes.';
END $$;