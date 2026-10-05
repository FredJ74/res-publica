-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260922072406
-- Nom original      : renseignement_suivi_position_effective
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-22 07:24:06 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : f631eb87ca7bdbd490520aad8e035a8b
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
-- SUIVI D'OPERATION (ministre seulement). Rend desormais la POSITION EFFECTIVE de chaque
-- agent -- celle de son porteur quand il en a un -- au lieu de ses seules colonnes propres,
-- qui sont vides pendant tout le transport. Le ministre voit donc ou sont reellement ses
-- gens, et non « non deploye » pendant que son equipe traverse un empire.
-- `pays_couverture` est rendu sous ce nom, jamais sous celui de « pays cible » : c'est une
-- couverture, et l'interface doit pouvoir le dire sans ambiguite.
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
                    'portrait', public.agent_portrait_chemin(ag.vrai_nom, ag.pays_couverture))
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