-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 9 OCTOBRE 2026
--
-- Registre Supabase : version 20261009140303 (UTC ; 16h03 a Paris), nom
-- `election_voter_porte_atomique`. Le registre passe de 568 a 569 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 321861cbbcea3ca28338bfe537ab32e2, 11 775 caracteres,
-- 1 instruction au registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- Elle ferme la chaine du vote electoral : `voterPour` enchainait DEUX ecritures clientes
-- independantes -- le bulletin dans `votes_electoraux` (via `sbVoterPour`, dont le corps etait un
-- try/catch VIDE) et le blob du cycle en `.catch(() => {})` -- puis annoncait « Vote enregistre ! »
-- sans rien attendre, alors que le depouillement de minuit ne compte QUE le blob. La porte ecrit les
-- deux dans une transaction, sous verrou du cycle.
--
-- ELLE VA PAR PAIRE AVEC LE DEPOT : `plateau-politique.js` (`voterPour`, devenue async) et
-- `plateau-navigation.js` (`voterPourCandidat`) ; `sbVoterPour` est supprimee de `supabase.js`.
-- =============================================================================

-- Chantier 5 -- LE VOTE N'EST PLUS ANNONCE SANS PREUVE, ET SES DEUX ECRITURES SONT ATOMIQUES.
--
-- voterPour (plateau-politique.js) enchainait DEUX ecritures clientes independantes : un
-- bulletin dans `votes_electoraux` (via sbVoterPour, dont le corps etait un try{}catch{} VIDE
-- sans aucun retour) et le blob du cycle (`.catch(() => {})`). Puis il affichait
-- « Vote enregistre ! » sans attendre ni lire quoi que ce soit -- la fonction n'etait meme pas
-- async. Aucune des deux tables ne confirmait rien.
--
-- ET LES DEUX COMPTENT, CE QUI EST LE POINT LE MOINS EVIDENT. Le client reconstruit
-- `cycle.votes` depuis la TABLE a chaque synchronisation ; mais le depouillement de minuit
-- (calculerScoresBaseCycle, api/cron-minuit.js) ne lit QUE LE BLOB. Un bulletin ecrit sans son
-- blob existait donc pour l'affichage et disparaissait du decompte -- jusqu'a ce qu'un client
-- resynchronise et reecrive le blob, ou jamais.
--
-- Cette porte ecrit les deux dans UNE transaction, sous verrou du cycle. Elle ne change aucune
-- regle electorale : la fenetre de vote, le domicile et la liste des candidats sont les
-- conditions du client, transcrites sur les champs que le blob porte lui-meme.
-- Banc en transaction annulee : 9 preuves vertes, dont une panne qui annule les DEUX ecritures.
CREATE OR REPLACE FUNCTION public.election_voter(
  p_pays text, p_poste_id text, p_ville text, p_candidat text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $fn$
DECLARE
  v_moi      text;
  v_pays     text := lower(btrim(coalesce(p_pays, '')));
  v_poste    text := btrim(coalesce(p_poste_id, ''));
  v_cand     text := btrim(coalesce(p_candidat, ''));
  v_local    boolean;
  v_ville    text;
  v_cle      text;
  v_id_cycle text;
  v_brut     text;
  v_cycle    jsonb;
  v_ms       numeric := floor(extract(epoch from now()) * 1000);
  v_domicile text;
  v_titulaire boolean;
  v_n        integer;
BEGIN
  -- L'IDENTITE N'EST PAS UN PARAMETRE. L'appelant ne dit pas qui vote : le serveur le lit.
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF v_pays = '' OR v_poste = '' OR v_cand = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  -- LA LOCALITE DU POSTE VIENT DU REFERENTIEL, pas du navigateur :
  -- postes_electifs_regles.niveau = 'ville' est exactement la regle de posteEstLocal(). La cle
  -- du scrutin et l'identifiant du bulletin s'en deduisent, comme getCleCycle() cote client.
  SELECT (niveau = 'ville') INTO v_local FROM public.postes_electifs_regles WHERE poste_id = v_poste;
  IF v_local IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_inconnu');
  END IF;
  v_ville    := CASE WHEN v_local AND coalesce(btrim(p_ville), '') <> '' THEN btrim(p_ville) END;
  v_cle      := CASE WHEN v_ville IS NOT NULL THEN v_poste || '_' || v_ville ELSE v_poste END;
  v_id_cycle := v_pays || '_' || v_cle;

  -- DOMICILE : meme regle que le client -- domicile.country, a defaut le pays du personnage.
  SELECT coalesce(nullif(d.domicile ->> 'country', ''), d.country) INTO v_domicile
    FROM public.personnages_donnees d WHERE d.name = v_moi;
  IF v_domicile IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'non_domicilie');
  END IF;

  -- VERROU DU CYCLE. C'est lui qui serialise deux electeurs simultanes : le blob etant
  -- relu-modifie-reecrit, le second ecrasait sinon le bulletin du premier.
  SELECT data INTO v_brut FROM public.cycles_electoraux WHERE id = v_id_cycle FOR UPDATE;
  IF NOT FOUND OR v_brut IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cycle_absent');
  END IF;
  BEGIN
    v_cycle := v_brut::jsonb;
  EXCEPTION WHEN others THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cycle_illisible');
  END;
  IF jsonb_typeof(v_cycle) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cycle_illisible');
  END IF;

  -- FENETRE DE VOTE, transcrite de getPhaseActuelle() sans y rien ajouter. Le client n'accepte
  -- que VOTE, VOTE2 et VOTE3E_SIEGE, et ces trois phases sont exactement l'intervalle
  -- [dateVote, dateResultats) -- ce qui les distingue est le tour, jamais les bornes. La garde
  -- serveur ne peut donc ni ouvrir ni fermer une fenetre que le client n'ouvrait ou ne fermait
  -- pas. Les dates sont des millisecondes JavaScript.
  --
  -- Et le retour anticipe « mandat en cours » est repris tel quel, parce qu'il PRIME sur le
  -- calcul par dates. Pour depute le signal est cycle.elus (au moins un siege pourvu), pour les
  -- autres cycle.eluId.
  v_titulaire := CASE
    WHEN v_poste = 'depute' THEN EXISTS (
      SELECT 1 FROM jsonb_array_elements(
        CASE WHEN jsonb_typeof(v_cycle -> 'elus') = 'array' THEN v_cycle -> 'elus' ELSE '[]'::jsonb END
      ) e WHERE e IS NOT NULL AND jsonb_typeof(e) <> 'null' AND e::text <> '""')
    ELSE coalesce(nullif(v_cycle ->> 'eluId', ''), NULL) IS NOT NULL
  END;
  IF (v_cycle ->> 'phase') = 'mandat' AND v_titulaire
     AND jsonb_typeof(v_cycle -> 'dateFinMandat') = 'number'
     AND v_ms < (v_cycle ->> 'dateFinMandat')::numeric THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'vote_ferme', 'phase', 'mandat');
  END IF;
  IF jsonb_typeof(v_cycle -> 'dateVote') <> 'number'
     OR jsonb_typeof(v_cycle -> 'dateResultats') <> 'number' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cycle_sans_calendrier');
  END IF;
  IF v_ms < (v_cycle ->> 'dateVote')::numeric
     OR v_ms >= (v_cycle ->> 'dateResultats')::numeric THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'vote_ferme');
  END IF;

  -- LE CANDIDAT DOIT EXISTER, ou etre le vote blanc -- qui n'est jamais un candidat fictif
  -- ajoute a la liste, mais un choix reel compte a part par le depouillement.
  IF v_cand <> 'BLANC' AND NOT EXISTS (
       SELECT 1 FROM jsonb_array_elements(
         CASE WHEN jsonb_typeof(v_cycle -> 'candidats') = 'array' THEN v_cycle -> 'candidats' ELSE '[]'::jsonb END
       ) c WHERE c ->> 'nom' = v_cand) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'candidat_inconnu');
  END IF;

  -- LE BULLETIN EST LA REVENDICATION. Sa cle primaire porte (pays, cle du scrutin, votant) :
  -- un second bulletin du meme electeur pour le meme scrutin obtient un conflit et ne produit
  -- rien. Ce n'est pas un marqueur qu'une ecriture avalee peut perdre.
  INSERT INTO public.votes_electoraux (id, country, poste_id, city, votant, candidat, created_at)
  VALUES (v_pays || '_' || v_cle || '_' || v_moi, v_pays, v_poste, v_ville, v_moi, v_cand, now())
  ON CONFLICT (id) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_vote');
  END IF;

  -- LE BLOB EST CE QUE LE DEPOUILLEMENT COMPTE, et il est ecrit DANS LA MEME TRANSACTION que le
  -- bulletin.
  UPDATE public.cycles_electoraux
     SET data = (v_cycle || jsonb_build_object('votes',
                   coalesce(CASE WHEN jsonb_typeof(v_cycle -> 'votes') = 'object'
                                 THEN v_cycle -> 'votes' END, '{}'::jsonb)
                   || jsonb_build_object(v_moi, v_cand)))::text,
         updated_at = now()
   WHERE id = v_id_cycle;

  RETURN jsonb_build_object('ok', true, 'votant', v_moi, 'candidat', v_cand, 'cle', v_cle);
END; $fn$;

GRANT EXECUTE ON FUNCTION public.election_voter(text, text, text, text) TO authenticated;

COMMENT ON FUNCTION public.election_voter(text, text, text, text) IS
'Enregistre le bulletin d''un joueur : la ligne de votes_electoraux ET l''entree du blob que le
depouillement compte, dans UNE transaction, sous verrou du cycle. L''electeur n''est pas un
parametre -- il vient de mon_personnage().
VERDICTS : acteur_non_authentifie, parametres_invalides, poste_inconnu, non_domicilie,
cycle_absent, cycle_illisible, cycle_sans_calendrier, vote_ferme (avec phase=mandat le cas
echeant), candidat_inconnu, deja_vote, puis ok avec le votant, le candidat et la cle du scrutin.
AUCUNE REGLE ELECTORALE N''EST DECIDEE ICI : fenetre, domicile et liste des candidats sont les
conditions deja appliquees par voterPour(), transcrites sur les champs du blob.';

DO $$
DECLARE v_def text; v_n int; v_emp text;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
   WHERE p.proname = 'election_voter';
  IF v_def IS NULL THEN RAISE EXCEPTION 'P1 ECHOUEE -- la fonction n''existe pas'; END IF;

  -- P1 : l'identite n'est pas un parametre, elle est lue.
  IF position('v_moi := public.mon_personnage()' in v_def) = 0 THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- l''electeur n''est pas resolu par mon_personnage()';
  END IF;
  IF v_def ~ 'p_votant|p_electeur' THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- un parametre nomme l''electeur : il serait falsifiable';
  END IF;

  -- P2 : les DEUX ecritures sont dans la meme fonction, donc la meme transaction.
  IF position('INSERT INTO public.votes_electoraux' in v_def) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- le bulletin n''est pas ecrit';
  END IF;
  IF position('UPDATE public.cycles_electoraux' in v_def) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- le blob que compte le depouillement n''est pas ecrit';
  END IF;
  IF position('ON CONFLICT (id) DO NOTHING' in v_def) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- le bulletin ne s''appuie pas sur sa cle primaire';
  END IF;
  IF position('FOR UPDATE' in v_def) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- le cycle n''est pas verrouille : deux electeurs simultanes s''ecraseraient';
  END IF;

  -- P3 : la fenetre de vote est celle du client, et le mandat prime.
  IF position('(v_cycle ->> ''dateVote'')::numeric' in v_def) = 0
     OR position('(v_cycle ->> ''dateResultats'')::numeric' in v_def) = 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- la fenetre de vote n''est pas verifiee';
  END IF;
  IF position('''mandat''' in v_def) = 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- le mandat en cours ne prime plus sur les dates';
  END IF;

  -- P4 : la localite vient du referentiel, et il est bien peuple.
  IF position('FROM public.postes_electifs_regles' in v_def) = 0 THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- la localite du poste vient encore du navigateur';
  END IF;
  SELECT count(*) INTO v_n FROM public.postes_electifs_regles WHERE niveau = 'ville';
  IF v_n < 1 THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- aucun poste de ville declare : tous les scrutins locaux seraient mal cles';
  END IF;

  -- P5 : autorite et droits. Appelable par un joueur authentifie, jamais par anon.
  IF v_def !~ 'SECURITY DEFINER' OR v_def !~ 'search_path TO ''public'', ''pg_temp''' THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- autorite ou search_path incorrects';
  END IF;
  IF NOT has_function_privilege('authenticated', 'public.election_voter(text,text,text,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- un joueur authentifie ne pourrait pas voter';
  END IF;
  IF has_function_privilege('anon', 'public.election_voter(text,text,text,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- anon peut voter';
  END IF;

  -- P6 : AUCUNE DONNEE TOUCHEE.
  SELECT count(*) INTO v_n FROM public.votes_electoraux;
  IF v_n <> 0 THEN RAISE EXCEPTION 'P6 ECHOUEE -- % bulletin(s) apparu(s)', v_n; END IF;
  SELECT count(*)::text || ' / ' || md5(string_agg(id || ':' || md5(coalesce(data,'')), '|' ORDER BY id COLLATE "C"))
    INTO v_emp FROM public.cycles_electoraux;
  IF v_emp IS DISTINCT FROM '13 / da30043ce543e921f9a6899bb80abd21' THEN
    RAISE EXCEPTION 'P6 ECHOUEE -- les cycles electoraux ont bouge : %', v_emp;
  END IF;

  RAISE NOTICE 'SIX PREUVES STRUCTURELLES VERTES.';
END $$;