-- BANC (annulé) : réversibilité des quatre migrations 20261117*_goulag_ordres_internes_*.
-- Enveloppe BEGIN ... ROLLBACK : rien ne reste écrit. Il prouve que le lot se retire proprement et que
-- les trois fonctions raccordées (départ #1020, repos général, purge calendaire) retrouvent EXACTEMENT
-- leur texte d'avant raccord. Un retour arrière en production passerait par une nouvelle migration
-- reprenant ce corps (WORKFLOW-SUPABASE.md), sur décision explicite : il supprimerait l'historique du
-- registre, des incidents, des interrogatoires et des corruptions du goulag.
BEGIN;

DO $retour_depart$
DECLARE source text; a_jet text; n_jet text; a_rest text; n_rest text;
BEGIN
  IF to_regprocedure('public.goulag_toundra_demarrer(text)') IS NULL THEN RETURN; END IF;
  source := pg_get_functiondef('public.goulag_toundra_demarrer(text)'::regprocedure);
  IF strpos(source,'goulag_sortie_jet_20261117') = 0 THEN RETURN; END IF;
  a_jet := E'    v_statut:=''detenu'';\n';
  n_jet := a_jet
    || E'    -- goulag_sortie_jet_20261117 : sortie du camp à 80 % (95 % après corruption), une fois par jour.\n'
    || E'    DECLARE v_sortie jsonb;\n'
    || E'    BEGIN\n'
    || E'      v_sortie := public.sovarka_goulag_sortie_jet_interne(v_nom, v_det.id);\n'
    || E'      IF coalesce((v_sortie->>''reussi'')::boolean,false) IS NOT TRUE THEN RETURN v_sortie; END IF;\n'
    || E'    END;\n';
  a_rest := E'    -- Peine restante à l''instant exact : pas de comparaison avec la durée de marche.\n'
    || E'    -- Les peines historiques portent debutTs en millisecondes et jours en numérique.\n'
    || E'    IF coalesce(p.est_emprisonne->>''debutTs'','''') !~ ''^[0-9]+(\\.[0-9]+)?$''\n'
    || E'       OR coalesce(p.est_emprisonne->>''jours'','''') !~ ''^[0-9]+(\\.[0-9]+)?$'' THEN\n'
    || E'      RETURN jsonb_build_object(''ok'',false,''raison'',''peine_calendaire_invalide''); END IF;\n'
    || E'    v_debut:=(p.est_emprisonne->>''debutTs'')::numeric;\n'
    || E'    v_duree:=(p.est_emprisonne->>''jours'')::numeric;\n'
    || E'    v_fin:=v_debut+v_duree*86400000;\n'
    || E'    v_rest:=greatest(0,(v_fin-extract(epoch from clock_timestamp())*1000)/1000);\n';
  n_rest := E'    -- goulag_reliquat_sommeil_20261117 : seul le sommeil valide purge la peine du goulag.\n'
    || E'    SELECT r.jours_restants::numeric*86400 INTO v_rest FROM public.sovarka_goulag_registre r\n'
    || E'      WHERE r.detention_id=v_det.id;\n'
    || E'    v_rest:=coalesce(v_rest,0);\n';
  IF strpos(source, n_jet) = 0 OR strpos(source, n_rest) = 0 THEN RAISE EXCEPTION 'retour_depart_texte_inattendu'; END IF;
  EXECUTE replace(replace(source, n_jet, a_jet), n_rest, a_rest);
END $retour_depart$;

DO $retour_repos$
DECLARE source text; garde text;
BEGIN
  source := pg_get_functiondef('public.pa_repos_nocturne(text)'::regprocedure);
  garde := E'  -- goulag_sommeil_dortoir_20261117 : le détenu du goulag dort au dortoir ou au cachot.\n'
    || E'  IF public.sovarka_goulag_detention_registree_interne(p_acteur) IS NOT NULL THEN\n'
    || E'    RETURN jsonb_build_object(''ok'', false, ''raison'', ''sommeil_goulag_dortoir'', ''pa'', v_pa); END IF;\n';
  IF strpos(source, garde) > 0 THEN EXECUTE replace(source, garde, ''); END IF;
END $retour_repos$;

DO $retour_purge$
DECLARE source text; garde text;
BEGIN
  source := pg_get_functiondef('public.detention_clore_purgee()'::regprocedure);
  garde := E'  -- goulag_peine_au_sommeil_20261117 : aucun décompte par simple passage du temps.\n'
    || E'  IF EXISTS (SELECT 1 FROM public.sovarka_goulag_registre r WHERE r.detention_id = v_det.id) THEN\n'
    || E'    RETURN jsonb_build_object(''ok'',false,''raison'',''peine_goulag_au_sommeil''); END IF;\n';
  IF strpos(source, garde) > 0 THEN EXECUTE replace(source, garde, ''); END IF;
END $retour_purge$;

DROP TRIGGER IF EXISTS sovarka_goulag_registre_ouverture ON public.detentions;
DROP TRIGGER IF EXISTS sovarka_goulag_registre_jugement ON public.jugements;
DROP FUNCTION IF EXISTS public.sovarka_goulag_registre_jugement();
DROP FUNCTION IF EXISTS public.sovarka_goulag_sortie_jet_interne(text,text);
DROP FUNCTION IF EXISTS public.sovarka_goulag_controle_minuit(date);
DROP FUNCTION IF EXISTS public.sovarka_goulag_incidents_consulter();
DROP FUNCTION IF EXISTS public.sovarka_goulag_corrompre(uuid,integer,jsonb);
DROP FUNCTION IF EXISTS public.sovarka_goulag_sanctionner(text,integer,uuid);
DROP FUNCTION IF EXISTS public.sovarka_goulag_interroger(text,uuid);
DROP FUNCTION IF EXISTS public.sovarka_goulag_detenus_choisir();
DROP FUNCTION IF EXISTS public.sovarka_goulag_registre_consulter();
DROP FUNCTION IF EXISTS public.sovarka_goulag_liste_detenus();
DROP FUNCTION IF EXISTS public.sovarka_goulag_ma_detention();
DROP FUNCTION IF EXISTS public.sovarka_goulag_detenu_aller(text);
DROP FUNCTION IF EXISTS public.sovarka_goulag_manger();
DROP FUNCTION IF EXISTS public.sovarka_goulag_dormir();
DROP FUNCTION IF EXISTS public.sovarka_goulag_liberer_interne(text,text);
DROP FUNCTION IF EXISTS public.sovarka_goulag_cachot_placer_interne(text,text,integer,text);
DROP FUNCTION IF EXISTS public.sovarka_goulag_registre_ouvrir();
DROP FUNCTION IF EXISTS public.sovarka_goulag_incident_interne(text,text,text,text,jsonb);
DROP FUNCTION IF EXISTS public.sovarka_goulag_habilite_present_interne(text,text);
DROP FUNCTION IF EXISTS public.sovarka_goulag_detention_registree_interne(text);
DROP FUNCTION IF EXISTS public.sovarka_goulag_jour_interne();
DROP FUNCTION IF EXISTS public.sovarka_goulag_ordres_refus_interne();
DROP TABLE IF EXISTS public.sovarka_goulag_traces_revelees;
DROP TABLE IF EXISTS public.sovarka_goulag_interrogatoires;
DROP TABLE IF EXISTS public.sovarka_goulag_corruptions;
DROP TABLE IF EXISTS public.sovarka_goulag_tentatives;
DROP TABLE IF EXISTS public.sovarka_goulag_incidents;
DROP TABLE IF EXISTS public.sovarka_goulag_controles;
DROP TABLE IF EXISTS public.sovarka_goulag_registre_jugements;
DROP TABLE IF EXISTS public.sovarka_goulag_registre;

ROLLBACK;
