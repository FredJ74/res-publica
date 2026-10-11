-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 11 OCTOBRE 2026
--
-- Registre Supabase : version 20261011000152 (UTC), nom `garde_synchronisation_derriere_une_garde`.
-- Le registre passe de 639 a 640 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 d20ff988f006ce0cc88e93c78ad07266, 6355 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- L'INVARIANT 10 A TROUVE LA GARDE LE JOUR MEME OU ELLE A ETE POSEE
--
--   garde_republicaine_synchroniser : mutante, EXECUTE a authenticated, aucune garde.
--
-- Il avait raison : cette fonction cree et retire des PNJ, et elle etait ouverte a tout joueur
-- authentifie. Ses effets etaient bornes -- jamais au-dela du facteur national, aucune caisse
-- touchee -- mais « les effets sont bornes » n'a jamais ete une garde.
--
-- LA CORRECTION N'AJOUTE PAS UN CONTROLE D'AUTORITE : ELLE SUPPRIME LA PORTE. Faire avancer la
-- Garde n'est pas une prerogative, c'est le temps qui passe, et n'importe quel passant doit
-- pouvoir le declencher en entrant dans le hall. `garde_republicaine_controle` devient donc
-- VOLATILE et synchronise elle-meme, bornee au pays de l'appelant qu'elle lit par
-- `mon_personnage()` ; la porte nue est revoquee a authenticated. Une porte unique, deja gardee,
-- plutot qu'une seconde garde sur une seconde porte.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- =================================================================================================
-- LA SYNCHRONISATION DE LA GARDE PASSE DERRIERE UNE GARDE (11 octobre 2026)
-- =================================================================================================
-- CE QUE L'INVARIANT 10 A TROUVE, le jour meme ou la Garde republicaine a ete posee :
--   garde_republicaine_synchroniser : mutante, EXECUTE a authenticated, aucune garde.
--
-- Il a raison. Cette fonction cree et retire des PNJ, et elle etait ouverte a tout joueur
-- authentifie sans qu'aucune autorite ne soit verifiee. Ses effets sont bornes -- elle ne peut
-- jamais depasser le facteur national, ne touche a aucune caisse et ne supprime rien dont un
-- joueur profite -- mais « les effets sont bornes » n'a jamais ete une garde. C'est exactement la
-- classe de defaut que la purge a fermee partout ailleurs.
--
-- LA CORRECTION N'AJOUTE PAS UN CONTROLE D'AUTORITE, ELLE SUPPRIME LA PORTE. Faire avancer la
-- Garde n'est pas une prerogative : c'est le temps qui passe, et n'importe quel passant doit
-- pouvoir le declencher simplement en entrant dans le hall. Le besoin n'etait donc pas d'une
-- autorite, mais d'un SEUL point d'entree deja identifie.
--
--   . `garde_republicaine_controle` devient VOLATILE et synchronise elle-meme avant de repondre.
--     Elle est deja gardee par ce qui compte ici : elle lit `mon_personnage()`, refuse un appelant
--     non authentifie, et ne travaille que sur le pays de cet appelant. Un joueur ne peut donc
--     faire avancer que la Garde de son propre pays, en entrant dans une piece, ce qui est
--     precisement le fait de jeu voulu.
--   . `garde_republicaine_synchroniser` est REVOQUEE a authenticated. Elle reste appelable par le
--     serveur -- et par `garde_republicaine_controle`, qui est SECURITY DEFINER et traverse donc
--     la revocation : c'est le patron habituel de la porte unique.
--
-- UNE FONCTION STABLE NE PEUT PAS MUTER, et c'est pour cela que la volatilite change ici : une
-- `STABLE` qui appellerait la synchronisation echouerait a l'execution. Le changement de
-- volatilite est donc la cause, pas un effet de bord.
-- =================================================================================================

CREATE OR REPLACE FUNCTION public.garde_republicaine_controle(
  p_building_id text, p_room_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_etat jsonb; v_motifs integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;

  -- LE TEMPS PASSE ICI, ET SEULEMENT ICI DU COTE CLIENT. Un permanent dont les quatre heures sont
  -- ecoulees reprend son poste, les renforts expires rentrent. L'operation est idempotente : la
  -- declencher a chaque entree dans une piece est sans double effet.
  -- Elle est bornee au pays de l'appelant : on ne fait pas avancer la Garde d'un empire voisin.
  PERFORM public.garde_republicaine_synchroniser(v_pays);

  v_etat := public.garde_republicaine_piece(v_pays, p_building_id, p_room_id);
  IF coalesce((v_etat->>'gardee')::boolean, false) IS NOT TRUE
     OR coalesce((v_etat->>'gardes')::integer, 0) = 0 THEN
    -- NI POSTE DE GARDE, NI GARDE VIVANT : aucun controle. Un poste decime laisse entrer.
    RETURN jsonb_build_object('ok', true, 'intervention', false, 'gardes',
                              coalesce((v_etat->>'gardes')::integer, 0));
  END IF;

  SELECT count(*) INTO v_motifs FROM public.justice_recherches(v_moi);

  RETURN jsonb_build_object('ok', true, 'intervention', v_motifs > 0,
                            'gardes', (v_etat->>'gardes')::integer,
                            'malus', (v_etat->>'malus')::integer,
                            'libelle', v_etat->>'libelle');
END;
$function$;

REVOKE ALL ON FUNCTION public.garde_republicaine_controle(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.garde_republicaine_controle(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.garde_republicaine_controle(text, text) TO service_role;

-- LA PORTE NUE SE REFERME. Le navigateur n'a plus aucune raison de l'appeler.
REVOKE EXECUTE ON FUNCTION public.garde_republicaine_synchroniser(text) FROM authenticated;

-- -------------------------------------------------------------------------------------------------
-- PREUVES STRUCTURELLES
-- -------------------------------------------------------------------------------------------------
DO $$
DECLARE v_n integer;
BEGIN
  -- P1 : la synchronisation n'est plus appelable par un client.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'garde_republicaine_synchroniser'
     AND (has_function_privilege('authenticated', p.oid, 'EXECUTE')
          OR has_function_privilege('anon', p.oid, 'EXECUTE'));
  IF v_n <> 0 THEN RAISE EXCEPTION 'P1 : la synchronisation reste ouverte a un client'; END IF;

  -- P2 : elle reste appelable par le serveur -- sinon la Garde n'avancerait plus du tout.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'garde_republicaine_synchroniser'
     AND has_function_privilege('service_role', p.oid, 'EXECUTE');
  IF v_n <> 1 THEN RAISE EXCEPTION 'P2 : le serveur ne peut plus synchroniser la Garde'; END IF;

  -- P3 : le controle est devenu VOLATILE, sinon il ne pourrait pas muter, et il appelle bien la
  -- synchronisation. Les deux ensemble : une volatilite changee sans l'appel serait inutile.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'garde_republicaine_controle'
     AND p.provolatile = 'v' AND p.prosecdef
     AND p.prosrc LIKE '%garde_republicaine_synchroniser%'
     AND has_function_privilege('authenticated', p.oid, 'EXECUTE')
     AND NOT has_function_privilege('anon', p.oid, 'EXECUTE');
  IF v_n <> 1 THEN RAISE EXCEPTION 'P3 : la porte unique du controle est mal posee'; END IF;

  RAISE NOTICE 'Garde : les 3 preuves structurelles passent.';
END $$;
