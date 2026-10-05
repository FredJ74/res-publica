-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260922122431
-- Nom original      : renseignement_portraits_par_role
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-22 12:24:31 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 0476b98d8026153b4d5813a431257d81
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
-- LE CHEMIN DU PORTRAIT NE DOIT RIEN TRAHIR (22 septembre 2026).
-- Il etait bati sur le VRAI nom de l'agent : un joueur qui transporte l'equipe sans rien
-- savoir d'elle pouvait lire « raymond-hialiste-khalija.png » dans les outils de son
-- navigateur et decouvrir l'identite reelle derriere la couverture. Le fichier est desormais
-- nomme d'apres le ROLE TECHNIQUE, qui ne designe personne.
-- Identifiants existants, repris tels quels sans nomenclature parallele : garde, traducteur,
-- conseiller, coordinateur. 16 fichiers = 4 roles x 4 apparences.
DROP FUNCTION IF EXISTS public.agent_portrait_chemin(text, text);

CREATE FUNCTION public.agent_portrait_chemin(p_role text, p_pays text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT 'images/renseignement/' || coalesce(p_role, 'agent')
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
           'portrait', public.agent_portrait_chemin(ag.role, ag.pays_couverture))
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
           'portrait', public.agent_portrait_chemin(ag.role, ag.pays_couverture))
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

CREATE OR REPLACE FUNCTION public.renseignement_agents_disponibles()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $fn$
DECLARE v_poste text; v_res jsonb;
BEGIN
  SELECT a.poste_id INTO v_poste FROM public.acteur_poste_courant() a;
  IF v_poste IS DISTINCT FROM 'min_def' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante'); END IF;
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'role', i.role, 'vrai_nom', i.vrai_nom, 'dup', i.dup,
           'portrait', public.agent_portrait_chemin(i.role, 'republic'))
           ORDER BY i.role), '[]'::jsonb)
    INTO v_res FROM public.renseignement_identites_reelles i;
  RETURN jsonb_build_object('ok', true, 'agents', v_res);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.cellule_renseignement_mes_cellules()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $fn$
DECLARE v_nom text; v_poste text; v_pays text; v_res jsonb;
BEGIN
  SELECT a.nom, a.poste_id, a.pays INTO v_nom, v_poste, v_pays
    FROM public.acteur_poste_courant() a;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF v_poste IS DISTINCT FROM 'min_def' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
  END IF;

  SELECT coalesce(jsonb_agg(x ORDER BY x ->> 'cree_le' DESC), '[]'::jsonb) INTO v_res
  FROM (
    SELECT jsonb_build_object(
      'cellule', c.id, 'pays_couverture', c.pays_cible, 'pays_cible', c.pays_cible,
      'statut', c.statut, 'mode_fin', c.mode_fin, 'cree_le', c.cree_le,
      'echeance', c.echeance_le, 'terminee_le', c.terminee_le,
      'agents', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                    'id', ag.id, 'role', ag.role, 'vrai_nom', ag.vrai_nom,
                    'couverture', ag.nom_couverture, 'dup', ag.dup, 'statut', ag.statut,
                    'leader', ag.leader_courant,
                    'pays', pe.pays, 'ville', pe.ville,
                    'batiment', pe.building_id, 'piece', pe.room_id,
                    'porte', pe.porte,
                    'au_bureau', public.agent_au_bureau_min_def(pe.building_id, pe.room_id),
                    'portrait', public.agent_portrait_chemin(ag.role, ag.pays_couverture))
                    ORDER BY ag.role), '[]'::jsonb)
                   FROM public.agents_renseignement ag
                   LEFT JOIN LATERAL public.agent_position_effective(ag.id) pe ON true
                  WHERE ag.cellule_id = c.id)
    ) AS x
    FROM public.cellules_renseignement c
   WHERE c.pays_proprietaire = v_pays
  ) s;

  RETURN jsonb_build_object('ok', true, 'pays', v_pays, 'cellules', v_res);
END;
$fn$;

GRANT EXECUTE ON FUNCTION public.agent_portrait_chemin(text, text) TO authenticated, service_role;