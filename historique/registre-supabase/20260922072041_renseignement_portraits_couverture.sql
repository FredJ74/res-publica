-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260922072041
-- Nom original      : renseignement_portraits_couverture
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-22 07:20:41 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 43f18b0b18704c971e2181b429e33d27
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
-- CHEMIN DU PORTRAIT. Calcule EN BASE, jamais par une table de correspondance cote client :
-- une telle table serait lisible par n'importe qui et revelerait l'identite reelle derriere
-- chaque couverture. Ici, seul le chemin sort -- et uniquement pour les agents que l'appelant
-- a deja le droit de voir.
-- 16 fichiers attendus : <slug du vrai nom>-<pays de couverture>.png, republic servant
-- d'apparence neutre avant tout choix de couverture.
CREATE OR REPLACE FUNCTION public.agent_portrait_chemin(p_vrai_nom text, p_pays text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT 'images/renseignement/' ||
         regexp_replace(
           lower(translate(coalesce(p_vrai_nom, ''),
                           'ÀÁÂÃÄÅàáâãäåÈÉÊËèéêëÌÍÎÏìíîïÒÓÔÕÖòóôõöÙÚÛÜùúûüÇçÑñ',
                           'AAAAAAaaaaaaEEEEeeeeIIIIiiiiOOOOOoooooUUUUuuuuCcNn')),
           '[^a-z0-9]+', '-', 'g')
         || '-' || coalesce(p_pays, 'republic') || '.png';
$$;

CREATE OR REPLACE FUNCTION public.agents_couverture_de_mon_groupe()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $fn$
DECLARE v_moi text; v_res jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'id', ag.id, 'nom', ag.nom_couverture, 'couverture', ag.pays_couverture,
           'portrait', public.agent_portrait_chemin(ag.vrai_nom, ag.pays_couverture))
           ORDER BY ag.nom_couverture), '[]'::jsonb)
    INTO v_res
    FROM public.agents_renseignement ag
    JOIN public.cellules_renseignement c ON c.id = ag.cellule_id
   WHERE ag.leader_courant = v_moi AND ag.statut = 'actif' AND c.statut = 'active';
  RETURN jsonb_build_object('ok', true, 'agents', v_res);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.agents_couverture_ici()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $fn$
DECLARE v_moi text; d record; v_res jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, current_room INTO d
    FROM public.personnages_donnees WHERE name = v_moi;
  IF d.current_building IS NULL OR d.current_room IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'agents', '[]'::jsonb); END IF;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'id', ag.id, 'nom', ag.nom_couverture, 'couverture', ag.pays_couverture,
           'portrait', public.agent_portrait_chemin(ag.vrai_nom, ag.pays_couverture))
           ORDER BY ag.nom_couverture), '[]'::jsonb)
    INTO v_res
    FROM public.agents_renseignement ag
    JOIN public.cellules_renseignement c ON c.id = ag.cellule_id
   WHERE ag.statut = 'actif' AND c.statut = 'active'
     AND ag.leader_courant IS NULL
     AND ag.pays        IS NOT DISTINCT FROM d.country
     AND ag.ville       IS NOT DISTINCT FROM d.current_city
     AND ag.building_id IS NOT DISTINCT FROM d.current_building
     AND ag.room_id     IS NOT DISTINCT FROM d.current_room;
  RETURN jsonb_build_object('ok', true, 'agents', v_res);
END;
$fn$;

-- LES QUATRE AGENTS DISPONIBLES, pour l'ecran de convocation. Reserve au min_def : c'est le
-- seul ecran ou vrai nom et specialite apparaissent. Portraits en apparence neutre Republia.
CREATE OR REPLACE FUNCTION public.renseignement_agents_disponibles()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $fn$
DECLARE v_poste text; v_res jsonb;
BEGIN
  SELECT a.poste_id INTO v_poste FROM public.acteur_poste_courant() a;
  IF v_poste IS DISTINCT FROM 'min_def' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante'); END IF;
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'role', i.role, 'vrai_nom', i.vrai_nom, 'dup', i.dup,
           'portrait', public.agent_portrait_chemin(i.vrai_nom, 'republic'))
           ORDER BY i.role), '[]'::jsonb)
    INTO v_res FROM public.renseignement_identites_reelles i;
  RETURN jsonb_build_object('ok', true, 'agents', v_res);
END;
$fn$;

GRANT EXECUTE ON FUNCTION public.agent_portrait_chemin(text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.renseignement_agents_disponibles() TO authenticated, service_role;