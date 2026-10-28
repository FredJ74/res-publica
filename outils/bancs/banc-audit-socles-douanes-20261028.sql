-- Audit non destructif des mecanismes existants pour les deux affectations douanieres.
-- A executer en lecture seule : le test n'appelle aucun ordre joueur.
DO $test$
DECLARE v_sql text; v_n integer;
BEGIN
 SELECT pg_get_functiondef('public.arme_acheter(text,text)'::regprocedure) INTO v_sql;
 IF position('''legal'', true' IN v_sql) = 0 THEN
   RAISE EXCEPTION 'achat_arme_legale_sans_marqueur';
 END IF;
 SELECT pg_get_functiondef('public.crime_acheter_arme_noire(text,text,boolean)'::regprocedure) INTO v_sql;
 IF position('''legal'', false' IN v_sql) = 0 THEN
   RAISE EXCEPTION 'achat_arme_noire_sans_marqueur';
 END IF;

 SELECT pg_get_functiondef('public.fret_dedouaner(uuid)'::regprocedure) INTO v_sql;
 IF position('FROM public.caisses_fret' IN v_sql) = 0 THEN
   RAISE EXCEPTION 'fret_dedouanement_non_raccorde';
 END IF;

 SELECT count(*) INTO v_n FROM pg_proc
 WHERE pronamespace = 'public'::regnamespace
 AND proname IN ('inventaire_confisquer','police_detection_verifier',
                 'police_combat_resoudre','douane_payer_effectifs','douane_effectifs_publics');
 IF v_n <> 5 THEN RAISE EXCEPTION 'socle_douanes_incomplet: % / 5', v_n; END IF;

 RAISE NOTICE 'OK : marqueurs arme legale/noire, dedouanement et socles existants';
END $test$;
