-- Banc annulé de 20261103140000_arrestations_flagrant_delit_serveur : à jouer APRÈS la migration,
-- dans la même transaction ; l'exception finale annule tout. Personnage d'essai : Angie Porcelana.
-- Mis à jour le 20/11/2026 (criminalité lot 6) : l'empoisonnement ne pose plus de flagrant délit à l'échec (lot 5) ; barème
-- unique (assassinat et tentative 2 j, résistance 2 j au barème) ; la peine d'office du même acte est réputée exécutée par
-- l'arrestation. Plus de suppression : un flagrant périmé (> 15 min) vaut absence de flagrant.
DO $$
DECLARE u uuid; n text := 'Angie Porcelana'; r jsonb; e jsonb; h integer; l numeric; m jsonb;
  PROCEDURE_RESET CONSTANT text := 'reset';
BEGIN
  PERFORM set_config('request.path', '/rpc/arrestation_flagrant_choisir', true);
  SELECT user_id INTO u FROM public.personnages_donnees WHERE name = n;
  UPDATE public.detentions SET mode_fin = 'banc', jour_fin_effective = 0 WHERE nom = n AND mode_fin IS NULL;
  UPDATE public.personnages_donnees SET est_emprisonne = NULL, detention_qhs = NULL, poste = NULL, country = 'republic',
         current_city = 'capitale', hp = 100, liquide = 2000, stats = stats || '{"VOL": 0, "DUP": 8}'::jsonb,
         resources = coalesce(resources, '{}'::jsonb) || '{"dis": 50}'::jsonb, recherche = '[]'::jsonb WHERE name = n;
  UPDATE public.flagrants_delits_attente SET cree_le = now() - interval '1 hour' WHERE personnage = n;

  -- 1. Portes « sur soi » fermées, choix impossible sans flagrant délit.
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  BEGIN
    PERFORM public.detention_ouvrir_soi('Banc', 1, NULL, NULL, false, NULL);
    RAISE EXCEPTION 'banc 1a: detention_ouvrir_soi encore ouverte';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    PERFORM public.arrestation_flagrant_interne(n, 'vol', false, 'banc');
    RAISE EXCEPTION 'banc 1b: moteur joignable';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  r := public.arrestation_flagrant_choisir('reddition');
  IF r ->> 'raison' IS DISTINCT FROM 'aucun_flagrant' THEN RAISE EXCEPTION 'banc 1c: %', r; END IF;
  RESET ROLE;

  -- 2. Flagrant délit d'un acte du barème (tentative d'assassinat, 2 j), le joueur se rend : motif porteur de l'acte.
  PERFORM public.flagrant_delit_poser_interne(n, 'tentative_assassinat', 'banc');
  SET LOCAL ROLE authenticated;
  r := public.arrestation_flagrant_choisir('reddition');
  RESET ROLE;
  SELECT est_emprisonne INTO e FROM public.personnages_donnees WHERE name = n;
  SELECT motifs INTO m FROM public.detentions WHERE nom = n AND mode_fin IS NULL;
  IF NOT coalesce((r #>> '{arrestation,ok}')::boolean, false) OR (r #>> '{arrestation,jours}')::int <> 2
     OR e IS NULL OR m -> 0 ->> 'acte' <> 'tentative_assassinat' THEN
    RAISE EXCEPTION 'banc 2: % / % / %', r, e, m;
  END IF;
  IF EXISTS (SELECT 1 FROM public.flagrants_delits_attente WHERE personnage = n) THEN RAISE EXCEPTION 'banc 2b: flagrant non consommé'; END IF;
  -- La porte de clôture pour désertion refuse : la peine tient à autre chose.
  SET LOCAL ROLE authenticated;
  r := public.detention_clore_motif_eteint('poursuites_eteintes');
  RESET ROLE;
  -- Pendant une mobilisation générale, la porte refuse d'abord pour cette raison-là (état du monde, pas un défaut).
  IF coalesce(r ->> 'raison', '') NOT IN ('peine_pas_seulement_desertion', 'mobilisation_en_cours') THEN RAISE EXCEPTION 'banc 2c: %', r; END IF;

  -- 3. Résistance avec VOL 0 : échec certain, arrestation aggravée (2 + 2), PV −20.
  UPDATE public.detentions SET mode_fin = 'banc', jour_fin_effective = 0 WHERE nom = n AND mode_fin IS NULL;
  UPDATE public.personnages_donnees SET est_emprisonne = NULL, detention_qhs = NULL, current_city = 'capitale' WHERE name = n;
  -- Identifiée sur le moment (lot 6) : jugement d'office simple, réputé exécuté par l'arrestation en flagrant délit.
  PERFORM public.crim_identifier_interne(n, 'tentative_assassinat', 'crime');
  PERFORM public.flagrant_delit_poser_interne(n, 'tentative_assassinat', 'banc');
  SET LOCAL ROLE authenticated;
  r := public.arrestation_flagrant_choisir('resistance');
  RESET ROLE;
  SELECT hp INTO h FROM public.personnages_donnees WHERE name = n;
  IF (r ->> 'reussi')::boolean OR (r #>> '{arrestation,jours}')::int <> 4 OR h <> 80 THEN RAISE EXCEPTION 'banc 3: % hp %', r, h; END IF;
  IF EXISTS (SELECT 1 FROM public.jugements WHERE accuse = n AND NOT coalesce(executee, false) AND data ->> 'source' = 'peine_office'
               AND data ->> 'acte' = 'tentative_assassinat') THEN RAISE EXCEPTION 'banc 3b: peine d''office non soldée'; END IF;

  -- 4. Corruption : 500 FR prélevés ; libre (DIS −10) ou arrêté aggravé (DIS −15).
  UPDATE public.detentions SET mode_fin = 'banc', jour_fin_effective = 0 WHERE nom = n AND mode_fin IS NULL;
  UPDATE public.personnages_donnees SET est_emprisonne = NULL, detention_qhs = NULL, current_city = 'capitale',
         resources = resources || '{"dis": 50}'::jsonb WHERE name = n;
  SELECT liquide INTO l FROM public.personnages_donnees WHERE name = n;
  PERFORM public.flagrant_delit_poser_interne(n, 'tentative_assassinat', 'banc');
  SET LOCAL ROLE authenticated;
  r := public.arrestation_flagrant_choisir('corruption');
  RESET ROLE;
  IF (SELECT liquide FROM public.personnages_donnees WHERE name = n) <> l - 500
     OR (r ->> 'dis')::numeric <> (CASE WHEN (r ->> 'reussi')::boolean THEN 40 ELSE 35 END)
     OR ((r ->> 'reussi')::boolean = false AND (r #>> '{arrestation,jours}')::int <> 4) THEN
    RAISE EXCEPTION 'banc 4: %', r;
  END IF;

  -- 5. Détenu pour seule désertion : libéré par l'extinction des poursuites.
  UPDATE public.detentions SET mode_fin = 'banc', jour_fin_effective = 0 WHERE nom = n AND mode_fin IS NULL;
  UPDATE public.personnages_donnees SET est_emprisonne = NULL, detention_qhs = NULL, current_city = 'capitale' WHERE name = n;
  r := public.arrestation_flagrant_interne(n, 'desertion', false, 'banc');
  IF NOT coalesce((r ->> 'ok')::boolean, false) THEN RAISE EXCEPTION 'banc 5a: %', r; END IF;
  SET LOCAL ROLE authenticated;
  r := public.detention_clore_motif_eteint('poursuites_eteintes');
  RESET ROLE;
  IF r ->> 'raison' IS DISTINCT FROM 'mobilisation_en_cours' AND (NOT coalesce((r ->> 'ok')::boolean, false)
     OR (SELECT est_emprisonne FROM public.personnages_donnees WHERE name = n) IS NOT NULL) THEN
    RAISE EXCEPTION 'banc 5b: %', r;
  END IF;

  -- 6. Patrouille et détachement : sans couvre-feu ni soldats, personne n'est interpellé.
  -- militaire_detachement_arrestation() n'existe plus et couvre_feu_patrouille() n'est plus ouverte aux joueurs (relevé du
  -- 20/11/2026) : la patrouille est appelée côté serveur.
  IF (public.couvre_feu_patrouille() ->> 'interpelle')::boolean THEN
    RAISE EXCEPTION 'banc 6: interpellation sans motif';
  END IF;

  -- 7. QHS du vol militaire et actes raccordés.
  r := public.arrestation_flagrant_interne(n, 'vol_materiel_militaire', false, 'banc', 'Vol de matériel militaire', 3, true, 'caserne');
  IF NOT coalesce((r ->> 'ok')::boolean, false) OR (SELECT detention_qhs FROM public.personnages_donnees WHERE name = n) IS NULL THEN
    RAISE EXCEPTION 'banc 7a: %', r;
  END IF;
  -- Criminalité lot 7 (20/11) : terrain_permis_corrompre est supprimé (« ordre_supprime »), il n'arrête plus personne.
  IF position('arrestation_flagrant_interne' IN pg_get_functiondef('public.calomnie_distribuer_consommer(text,text,text,integer)'::regprocedure)) = 0
     OR position('arrestation_flagrant_interne' IN pg_get_functiondef('public.militaire_subtiliser_tenter(text)'::regprocedure)) = 0
     OR position('flagrant_delit_poser_interne' IN pg_get_functiondef('public.assemblee_neutraliser_depute(text,text,text,text)'::regprocedure)) = 0
     OR position('crim_office_flagrant_v1' IN pg_get_functiondef('public.arrestation_flagrant_interne(text,text,boolean,text,text,integer,boolean,text)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'banc 7b: acte non raccordé';
  END IF;
  -- Lot 5 : l'empoisonnement raté ne pose plus de flagrant délit (règle commune : échec critique seulement).
  IF position('flagrant_delit_poser_interne' IN pg_get_functiondef('public.crime_empoisonner(text,uuid)'::regprocedure)) > 0 THEN
    RAISE EXCEPTION 'banc 7c: flagrant délit encore posé par l''empoisonnement';
  END IF;
  RAISE EXCEPTION 'BANC OK : portes fermées, reddition 2 j, résistance 4 j PV 80 (peine d''office soldée), corruption %, désertion libérée, QHS posé', r ->> 'jours';
END $$;
