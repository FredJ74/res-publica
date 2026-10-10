-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010005254 (UTC), nom `election_resultats_une_proclamation_par_scrutin`.
-- Le registre passe de 588 a 589 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 28ed33f5fd0cb2f69d3126b280942886, 9001 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- RESULTATS D'ELECTION : UNE PROCLAMATION PAR SCRUTIN
--
-- `election_resultats_consigner(cycle, data, evenement, chronique)` fait de `resultatsTraites` un
COMPARE-AND-SWAP dans le filtre de l'UPDATE, puis pose l'evenement global et la chronique
nationale dans la meme transaction. Un fait de l'audit etait FAUX et il est corrige dans
l'en-tete : le depouillement n'est pas aleatoire -- verifie fonction par fonction. Ce qu'un
rejeu dupliquait, c'etait l'ANNONCE, qui partait avant le drapeau du cycle.
--
-- ELLE VA PAR PAIRE AVEC : `api/cron-minuit.js` (le bloc du calendrier electoral, 8 remplacements ancres).
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- Chantier 6, famille C -- UN SCRUTIN NE SE PROCLAME QU'UNE FOIS.
--
-- L'AUDIT SE TROMPAIT SUR LA CAUSE, ET IL FAUT LE DIRE. Il annoncait « resoudreScrutinSimple est
-- aleatoire : deux proclamations contradictoires ». C'est FAUX, mesure sur le code :
-- `resoudreScrutinSimple` et `resoudreScrutinDepute` sont entierement DETERMINISTES -- aucun
-- `random()`, et l'egalite est departagee par l'anciennete de la candidature puis l'ordre
-- alphabetique (`departageCandidats`). Un rejeu recalcule donc le MEME vainqueur a partir des
-- memes bulletins. Il n'y a pas de hasard a descendre ici.
--
-- CE QU'UN REJEU PRODUISAIT REELLEMENT, et c'est assez grave : une SECONDE PROCLAMATION PUBLIQUE.
-- Le bloc du calendrier electoral inserait l'evenement global PUIS ecrivait le blob du cycle avec
-- `resultatsTraites = true` -- deux requetes HTTP, la seconde en fin de boucle. Une interruption
-- entre les deux laissait l'annonce faite et le drapeau absent : la nuit suivante reproclamait.
--
--   . `chronique_nationale` etait DEJA protegee : son identifiant est
--     `election-<cycle>-<dateResultats>`, et sa cle primaire refuse le doublon. Le commentaire du
--     code le disait, et il avait raison.
--   . `evenements_globaux`, lui, n'avait AUCUNE garde -- son identifiant est une sequence. La
--     chronique nationale restait juste, mais la chronique VISIBLE du jeu affichait deux fois le
--     meme resultat d'election.
--
-- LA PROTECTION EST DONC UN COMPARE-AND-SWAP, PAS LA BRIQUE NOCTURNE. Le drapeau du cycle est le
-- verrou naturel, et il doit vivre dans le FILTRE de l'ecriture : `WHERE id = ... AND
-- resultatsTraites = false`. Zero ligne touchee = deja proclame. La brique `actes_nocturnes`
-- serait fausse ici, pour la meme raison que pour le vote de confiance : un scrutin se depouille
-- une fois dans sa vie, pas une fois par jour.
--
-- CE QUE LA PORTE NE FAIT PAS. Elle ne depouille pas : le calcul reste en JavaScript, parce qu'il
-- est deterministe et qu'il est DUPLIQUE A L'IDENTIQUE cote client (plateau-politique.js) pour
-- l'affichage -- les deux copies doivent rester identiques, et les descendre en SQL creerait une
-- TROISIEME copie. Ce que la porte garantit, c'est que le resultat calcule et son annonce sont
-- ecrits ensemble ou pas du tout.
--
-- LES BRANCHES DE RENOUVELLEMENT (vote blanc majoritaire, second tour) ecrivent un blob dont
-- `resultatsTraites` reste faux : leur garde contre le rejeu n'est PAS le drapeau mais la DATE du
-- nouveau scrutin, qui est dans le futur -- le pre-filtre `now < dateResultats` les ecarte. C'est
-- deja vrai et ce lot n'y touche pas.
--
-- Banc en transaction annulee : 6 epreuves vertes, dont le rejeu qui ne pose plus de second
-- evenement public, et le cycle inconnu qui n'en pose aucun.
CREATE OR REPLACE FUNCTION public.election_resultats_consigner(
  p_cycle_id text, p_data jsonb,
  p_evenement jsonb DEFAULT NULL, p_chronique jsonb DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE v_n integer; v_ev integer := 0; v_ch integer := 0;
BEGIN
  IF coalesce(btrim(p_cycle_id),'') = '' OR p_data IS NULL OR jsonb_typeof(p_data) <> 'object' THEN
    RAISE EXCEPTION 'election_resultats_consigner : cycle et blob sont obligatoires';
  END IF;
  -- COMPARE-AND-SWAP SUR LE DRAPEAU DU CYCLE. La garde est dans le FILTRE, pas dans le corps :
  -- deux passes simultanees ne peuvent pas proclamer le meme scrutin, et un rejeu lit zero ligne.
  -- Un cycle inconnu donne aussi zero ligne : aucune annonce ne peut partir sans son cycle.
  UPDATE public.cycles_electoraux
     SET data = p_data::text, updated_at = now()
   WHERE id = p_cycle_id
     AND coalesce((data::jsonb ->> 'resultatsTraites')::boolean, false) = false;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_traite');
  END IF;

  IF jsonb_typeof(p_evenement) = 'object' THEN
    INSERT INTO public.evenements_globaux (country, city, texte, jour)
    VALUES (p_evenement ->> 'country', p_evenement ->> 'city', p_evenement ->> 'texte', NULL);
    v_ev := 1;
  END IF;
  -- L'identifiant de la chronique vient de l'appelant et est DEJA deterministe
  -- (election-<cycle>-<dateResultats>) : le ON CONFLICT est une seconde barriere, pas la premiere.
  IF jsonb_typeof(p_chronique) = 'object' THEN
    INSERT INTO public.chronique_nationale (id, country, city, type, personnages, libelle, data, source_ref)
    VALUES (p_chronique ->> 'id', p_chronique ->> 'country', p_chronique ->> 'city',
            p_chronique ->> 'type',
            CASE WHEN jsonb_typeof(p_chronique -> 'personnages') = 'array'
                 THEN p_chronique -> 'personnages' ELSE '[]'::jsonb END,
            p_chronique ->> 'libelle', p_chronique -> 'data', p_chronique ->> 'source_ref')
    ON CONFLICT (id) DO NOTHING;
    GET DIAGNOSTICS v_ch = ROW_COUNT;
  END IF;
  RETURN jsonb_build_object('ok', true, 'cycle', p_cycle_id,
                            'evenement_pose', v_ev = 1, 'chronique_posee', v_ch = 1);
END; $fn$;

COMMENT ON FUNCTION public.election_resultats_consigner(text,jsonb,jsonb,jsonb) IS
'Consigne le resultat d''un scrutin en une transaction : le blob du cycle, l''evenement public et
la ligne de chronique nationale. La garde est un COMPARE-AND-SWAP sur `resultatsTraites` dans le
FILTRE de l''UPDATE -- zero ligne touchee signifie deja proclame, ou cycle inconnu, et dans les
deux cas aucune annonce ne part. Elle ne DEPOUILLE pas : le calcul est deterministe et reste chez
l''appelant, qui le partage a l''identique avec le client. Verdicts : deja_traite, puis ok avec
evenement_pose et chronique_posee. Non appelable depuis le reseau.';

DO $$
DECLARE v_def text; v_n int;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace AND n.nspname='public'
   WHERE p.proname='election_resultats_consigner';
  IF v_def IS NULL THEN RAISE EXCEPTION 'P1 ECHOUEE -- la porte n''existe pas'; END IF;

  -- P1 : LA GARDE EST DANS LE FILTRE, et l'annonce vient APRES.
  IF position('AND coalesce((data::jsonb ->> ''resultatsTraites'')::boolean, false) = false' in v_def) = 0 THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- la garde n''est pas dans le filtre de l''UPDATE'; END IF;
  IF position('GET DIAGNOSTICS v_n = ROW_COUNT' in v_def) = 0
     OR position('''deja_traite''' in v_def) = 0 THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- le compare-and-swap ne rend pas de verdict'; END IF;
  IF position('UPDATE public.cycles_electoraux' in v_def)
     >= position('INSERT INTO public.evenements_globaux' in v_def) THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- l''annonce precede la revendication du cycle'; END IF;

  -- P2 : LES DEUX ANNONCES SONT DANS LA MEME FONCTION, donc la meme transaction.
  IF position('INSERT INTO public.evenements_globaux' in v_def) = 0
     OR position('INSERT INTO public.chronique_nationale' in v_def) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- une annonce manque'; END IF;
  IF position('ON CONFLICT (id) DO NOTHING' in v_def) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- la chronique a perdu sa seconde barriere'; END IF;

  -- P3 : LA PORTE NE DEPOUILLE PAS. Aucun hasard, aucun calcul de scores : ce serait une
  -- TROISIEME copie d'un calcul deja duplique entre le cron et le client.
  IF v_def ~ 'random\(' THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- la porte tire au sort, alors que le depouillement est deterministe';
  END IF;
  IF v_def ~ 'votesPNJ|totalExprimes|blancMajoritaire' THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- la porte depouille : troisieme copie du calcul'; END IF;

  -- P4 : droits. Acte de minuit : injoignable depuis le reseau.
  IF has_function_privilege('authenticated','public.election_resultats_consigner(text,jsonb,jsonb,jsonb)','EXECUTE')
     OR has_function_privilege('anon','public.election_resultats_consigner(text,jsonb,jsonb,jsonb)','EXECUTE') THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- un navigateur peut proclamer une election'; END IF;
  IF NOT has_function_privilege('service_role','public.election_resultats_consigner(text,jsonb,jsonb,jsonb)','EXECUTE') THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- le cron ne peut pas appeler la porte'; END IF;

  -- P5 : AUCUNE DONNEE TOUCHEE, aucun residu de banc.
  SELECT count(*) INTO v_n FROM public.cycles_electoraux WHERE id LIKE 'zzc-%';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P5 ECHOUEE -- % cycle(s) de banc', v_n; END IF;
  SELECT count(*) INTO v_n FROM public.chronique_nationale;
  IF v_n <> 0 THEN RAISE EXCEPTION 'P5 ECHOUEE -- % chronique(s)', v_n; END IF;
  SELECT count(*) INTO v_n FROM public.evenements_globaux WHERE texte LIKE '%zzc%'
     OR texte LIKE '%Ben est élu(e)%';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P5 ECHOUEE -- % evenement(s) de banc', v_n; END IF;
  SELECT count(*) INTO v_n FROM public.cycles_electoraux;
  IF v_n <> 13 THEN RAISE EXCEPTION 'P5 ECHOUEE -- % cycles au lieu de 13', v_n; END IF;

  RAISE NOTICE 'CINQ PREUVES STRUCTURELLES VERTES.';
END $$;