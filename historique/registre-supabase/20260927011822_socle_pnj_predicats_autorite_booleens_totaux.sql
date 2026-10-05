-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927011822
-- Nom original      : socle_pnj_predicats_autorite_booleens_totaux
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-27 01:18:22 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : fd98d00e3b96c5dd78263e2cf695a636
--
-- ARCHIVE DOCUMENTAIRE exportee de supabase_migrations.schema_migrations.
-- Ce fichier NE FAIT PAS partie d'une chaine de reconstruction et NE DOIT
-- PAS etre rejoue, ni execute automatiquement, ni servir a installer une
-- base neuve. Voir historique/registre-supabase/README.md.
--
-- Le SQL ci-dessous est conserve INTEGRALEMENT, SANS AUCUNE MODIFICATION :
-- ni correction, ni mise en forme, ni separation des parties DDL et DML,
-- ni ajout d'idempotence. On archive ce qui s'est reellement passe.
-- ============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- LES PREDICATS D'AUTORITE DOIVENT ETRE TOTAUX (27 septembre 2026)
--
-- DEFAUT TROUVE PAR LES TESTS OBLIGATOIRES, pas par relecture. Ecrits
--   SELECT p_moi IS NOT NULL AND p_moi = public.pnj_autorite_de(p_pnj_id);
-- les predicats rendaient NULL -- et non false -- des que l'autorite etait A PERSONNE, ce qui
-- est desormais un etat NORMAL du modele (reserve militaire, poste vacant).
--
-- Consequence exacte, en logique ternaire : dans
--   IF NOT public.pnj_peut_administrer(v_moi, p_pnj) THEN ... refuser ... END IF;
-- on evalue NOT NULL = NULL, la branche n'est PAS prise, et la fonction CONTINUE comme si
-- l'autorisation etait accordee. Autrement dit : la garde s'ouvrait precisement dans le cas
-- qu'elle devait fermer -- n'importe qui administrait un reserviste.
--
-- Le nouveau modele rend ce cas courant alors que l'ancien le rendait rare : avec
-- `proprietaire_poste='lieutenant'` et un LIMIT 1 sans ORDER BY, la resolution renvoyait
-- toujours un nom. C'est la correction du premier defaut qui a arme celui-ci.
--
-- Les trois predicats sont donc rendus TOTAUX : ils ne renvoient plus jamais NULL.

CREATE OR REPLACE FUNCTION public.pnj_peut_administrer(p_moi text, p_pnj_id text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT (p_moi = public.pnj_autorite_de(p_pnj_id)) IS TRUE;
$$;

CREATE OR REPLACE FUNCTION public.pnj_peut_conduire(p_moi text, p_pnj_id text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT public.pnj_peut_administrer(p_moi, p_pnj_id)
      OR ((p_moi = (SELECT leader_pj FROM public.pnj_membres WHERE id = p_pnj_id)) IS TRUE);
$$;

CREATE OR REPLACE FUNCTION public.pnj_co_present(p_moi text, p_pnj_id text)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a record; pe record; v_b text; v_r text;
BEGIN
  IF p_moi IS NULL THEN RETURN false; END IF;
  SELECT country, current_city, current_building, current_room INTO a
    FROM public.personnages_donnees WHERE name = p_moi;
  IF a.current_city IS NULL THEN RETURN false; END IF;
  SELECT * INTO pe FROM public.pnj_position_effective(p_pnj_id);
  IF pe.ville IS NULL THEN RETURN false; END IF;
  v_b := COALESCE(pe.building_id,
                  CASE WHEN pe.rue_noeud_id IS NOT NULL THEN 'rue-centrale' END);
  v_r := COALESCE(pe.room_id, pe.rue_noeud_id);
  RETURN COALESCE(pe.pays = a.country AND pe.ville = a.current_city
     AND v_b IS NOT DISTINCT FROM a.current_building
     AND v_r IS NOT DISTINCT FROM a.current_room, false);
END; $$;

REVOKE ALL ON FUNCTION public.pnj_peut_administrer(text,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_peut_conduire(text,text)    FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_co_present(text,text)       FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.pnj_peut_administrer(text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.pnj_peut_conduire(text,text)    TO service_role;
GRANT EXECUTE ON FUNCTION public.pnj_co_present(text,text)       TO service_role;