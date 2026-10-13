-- BANC DU SIXIEME CANAL -- L'ETAPE DE LA VISITE D'ACCUEIL (13 octobre 2026)
--
-- Une transaction annulee, aucune donnee residuelle, verdict leve en EXCEPTION.
--
-- CE QU'IL EPROUVE. `quete_accueil_contexte()` est la porte par laquelle le serveur de dialogue
-- apprend OU EN EST la visite d'accueil du joueur qui parle a Jeremy. Elle ne prend aucun
-- parametre : l'identite vient du jeton. Les preuves de la migration 20261013152848 verifient sa
-- FORME -- definer, search_path gele, STABLE, zero argument, droits, colonnes nommees. Ce banc
-- verifie son COMPORTEMENT, qu'aucune preuve structurelle ne peut atteindre :
--
--   . deux joueurs differents obtiennent DEUX reponses differentes, sans qu'aucun ne puisse
--     nommer l'autre -- c'est la seule facon de montrer que l'isolement tient vraiment ;
--   . les trois etats terminaux ferment la visite, et toute autre valeur la laisse ouverte ;
--   . une fiche sans visite rend une reponse valide, pas une erreur ;
--   . la charge rendue ne porte QUE trois clefs : une porte de contexte qui en rendrait une
--     quatrieme donnerait au modele une donnee que personne n'a arbitree.
--
-- Usage : coller ce fichier dans un execute_sql. Il doit finir sur
--   ERROR: banc visite : LES 14 EPREUVES SONT VERTES. -- rien ne doit rester
BEGIN;
CREATE OR REPLACE FUNCTION pg_temp.je_suis(p_uuid text) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', p_uuid, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
END $f$;
CREATE OR REPLACE FUNCTION pg_temp.je_suis_le_serveur() RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  PERFORM set_config('role', 'postgres', true);
  PERFORM set_config('request.jwt.claims', '', true);
END $f$;
GRANT EXECUTE ON FUNCTION pg_temp.je_suis(text) TO PUBLIC;
GRANT EXECUTE ON FUNCTION pg_temp.je_suis_le_serveur() TO PUBLIC;
DO $banc$
DECLARE
  MARS_U text := 'a5a55fc8-64fa-4406-b617-76439d1d4aac'; MARS text := 'Marsault';
  BEN_U  text := 'bafc96b1-1628-4ae2-93d2-78d89f8ac5b5'; BEN  text := 'Ben';
  v jsonb; n integer := 0; ko integer := 0; e text := ''; v_t text;
BEGIN
  PERFORM pg_temp.je_suis_le_serveur();

  -- ------------------------------------------------------------------ T1 : L'ETAPE EST RENDUE
  UPDATE public.personnages_donnees
     SET quete_accueil = jsonb_build_object('etape', 'attente_hotel') WHERE name = MARS;
  n := n + 1;
  PERFORM pg_temp.je_suis(MARS_U);
  v := public.quete_accueil_contexte();
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE
     OR (v ->> 'etape') IS DISTINCT FROM 'attente_hotel'
     OR (v ->> 'visite_en_cours')::boolean IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nT1 : l''etape du joueur n''est pas rendue -- ' || v::text; END IF;

  -- ------------------------------------------- T2 : TROIS CLEFS, ET PAS UNE DE PLUS
  n := n + 1;
  SELECT string_agg(k, ',' ORDER BY k) INTO v_t FROM jsonb_object_keys(v) k;
  IF v_t IS DISTINCT FROM 'etape,ok,visite_en_cours' THEN
    ko := ko + 1; e := e || E'\nT2 : la charge porte ' || coalesce(v_t, '(rien)'); END IF;

  -- ------------------------------- T3 : DEUX JOUEURS, DEUX REPONSES, AUCUN NOM A DONNER
  UPDATE public.personnages_donnees
     SET quete_accueil = jsonb_build_object('etape', 'guide_stade') WHERE name = BEN;
  n := n + 1;
  PERFORM pg_temp.je_suis(BEN_U);
  v := public.quete_accueil_contexte();
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'etape') IS DISTINCT FROM 'guide_stade' THEN
    ko := ko + 1; e := e || E'\nT3 : le second joueur lit l''etape du premier -- ' || v::text; END IF;
  n := n + 1;
  PERFORM pg_temp.je_suis(MARS_U);
  v := public.quete_accueil_contexte();
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'etape') IS DISTINCT FROM 'attente_hotel' THEN
    ko := ko + 1; e := e || E'\nT4 : le premier joueur a change d''etape -- ' || v::text; END IF;

  -- ------------------------------------------- T5 a T7 : LES TROIS ETATS TERMINAUX FERMENT
  FOREACH v_t IN ARRAY ARRAY['carriere_terminee', 'quete_terminee_sans_aide', 'refusee'] LOOP
    n := n + 1;
    UPDATE public.personnages_donnees
       SET quete_accueil = jsonb_build_object('etape', v_t) WHERE name = MARS;
    PERFORM pg_temp.je_suis(MARS_U);
    v := public.quete_accueil_contexte();
    PERFORM pg_temp.je_suis_le_serveur();
    IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE
       OR (v ->> 'etape') IS DISTINCT FROM v_t
       OR (v ->> 'visite_en_cours')::boolean IS NOT FALSE THEN
      ko := ko + 1; e := e || E'\nT5 : ' || v_t || ' ne ferme pas la visite -- ' || v::text; END IF;
  END LOOP;

  -- -------------------------------------- T8 : UNE ETAPE INCONNUE LAISSE LA VISITE OUVERTE
  -- La liste nommee est celle des FINS. Une etape ajoutee demain est donc une etape vivante,
  -- et Jeremy continue de guider -- l'inverse l'aurait fait se taire au premier ajout.
  n := n + 1;
  UPDATE public.personnages_donnees
     SET quete_accueil = jsonb_build_object('etape', 'etape_inventee_par_le_banc') WHERE name = MARS;
  PERFORM pg_temp.je_suis(MARS_U);
  v := public.quete_accueil_contexte();
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'visite_en_cours')::boolean IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nT8 : une etape inconnue ferme la visite -- ' || v::text; END IF;

  -- -------------------------------------------------- T9 : AUCUNE VISITE N'EST UNE REPONSE
  n := n + 1;
  UPDATE public.personnages_donnees SET quete_accueil = NULL WHERE name = MARS;
  PERFORM pg_temp.je_suis(MARS_U);
  v := public.quete_accueil_contexte();
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE
     OR (v ->> 'etape') IS NOT NULL
     OR (v ->> 'visite_en_cours')::boolean IS NOT FALSE THEN
    ko := ko + 1; e := e || E'\nT9 : une fiche sans visite ne rend pas une reponse valide -- ' || v::text; END IF;

  -- ------------------------------------------ T10 : UNE VISITE SANS ETAPE N'INVENTE RIEN
  n := n + 1;
  UPDATE public.personnages_donnees
     SET quete_accueil = '{"autre": 1}'::jsonb WHERE name = MARS;
  PERFORM pg_temp.je_suis(MARS_U);
  v := public.quete_accueil_contexte();
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'etape') IS NOT NULL OR (v ->> 'visite_en_cours')::boolean IS NOT FALSE THEN
    ko := ko + 1; e := e || E'\nT10 : une visite sans etape invente quelque chose -- ' || v::text; END IF;

  -- -------------------------------------------- T11 : UNE ETAPE VIDE VAUT PAS D'ETAPE
  n := n + 1;
  UPDATE public.personnages_donnees
     SET quete_accueil = jsonb_build_object('etape', '   ') WHERE name = MARS;
  PERFORM pg_temp.je_suis(MARS_U);
  v := public.quete_accueil_contexte();
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'etape') IS NOT NULL OR (v ->> 'visite_en_cours')::boolean IS NOT FALSE THEN
    ko := ko + 1; e := e || E'\nT11 : une etape blanche est transmise telle quelle -- ' || v::text; END IF;

  -- ------------------------------------ T12 : SANS JETON, LA PORTE NE DIT RIEN D'UTILE
  n := n + 1;
  PERFORM set_config('request.jwt.claims', '', true);
  PERFORM set_config('role', 'authenticated', true);
  v := public.quete_accueil_contexte();
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, true) IS NOT FALSE
     OR (v ->> 'raison') IS DISTINCT FROM 'acteur_non_authentifie' THEN
    ko := ko + 1; e := e || E'\nT12 : un appel sans identite obtient une reponse -- ' || v::text; END IF;

  -- ------------------------------------------- T13 : ANON NE PEUT PAS APPELER LA PORTE
  n := n + 1;
  BEGIN
    PERFORM set_config('role', 'anon', true);
    PERFORM public.quete_accueil_contexte();
    PERFORM pg_temp.je_suis_le_serveur();
    ko := ko + 1; e := e || E'\nT13 : anon a pu appeler la porte';
  EXCEPTION WHEN insufficient_privilege THEN PERFORM pg_temp.je_suis_le_serveur();
  END;

  -- -------------------------- T14 : ELLE N'ECRIT RIEN -- la fiche est inchangee apres lecture
  n := n + 1;
  UPDATE public.personnages_donnees
     SET quete_accueil = jsonb_build_object('etape', 'guide_hdv') WHERE name = MARS;
  PERFORM pg_temp.je_suis(MARS_U);
  PERFORM public.quete_accueil_contexte();
  PERFORM public.quete_accueil_contexte();
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT quete_accueil::text INTO v_t FROM public.personnages_donnees WHERE name = MARS;
  IF v_t IS DISTINCT FROM '{"etape": "guide_hdv"}' THEN
    ko := ko + 1; e := e || E'\nT14 : la lecture a modifie la fiche -- ' || coalesce(v_t, '(nul)'); END IF;

  IF ko > 0 THEN RAISE EXCEPTION 'banc visite : % EPREUVE(S) ROUGE(S) sur % --%', ko, n, e; END IF;
  RAISE EXCEPTION 'banc visite : LES % EPREUVES SONT VERTES. -- rien ne doit rester', n;
END $banc$;
ROLLBACK;
