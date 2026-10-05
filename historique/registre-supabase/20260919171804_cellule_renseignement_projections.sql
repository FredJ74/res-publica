-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260919171804
-- Nom original      : cellule_renseignement_projections
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-19 17:18:04 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 5cd8514636c51bccc8f14317bb6e3ee5
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
-- PROJECTIONS. Le client ne lit JAMAIS agents_renseignement (RLS, zero policy).
-- Il ne recoit que ce que ces deux fonctions consentent a construire.

-- ---------------------------------------------------------------------------
-- PROJECTION PUBLIQUE : ce qu'un joueur ordinaire voit autour de lui.
-- Ne renvoie QUE le nom de couverture. Jamais le role, le vrai nom, la cellule,
-- l'empire proprietaire ni le statut reel.
-- La position n'est PAS acceptee du client : elle est relue en base a partir du
-- personnage de l'appelant. Sans cela, n'importe qui pourrait balayer la carte
-- a la recherche d'agents -- exactement le defaut qui avait ete releve sur
-- l'ancien ordre de renseignement.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.agents_renseignement_ici()
RETURNS TABLE(nom_couverture text)
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_ville text; v_bat text; v_room text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN; END IF;

  SELECT d.country, d.current_city, d.current_building, d.current_room
    INTO v_pays, v_ville, v_bat, v_room
    FROM public.personnages_donnees d WHERE d.name = v_moi;
  IF v_pays IS NULL OR v_bat IS NULL OR v_room IS NULL THEN RETURN; END IF;

  RETURN QUERY
    SELECT a.nom_couverture
      FROM public.agents_renseignement a
     WHERE a.statut = 'actif'
       AND a.leader_courant IS NULL          -- pose sur place, pas en deplacement
       AND a.pays_couverture = v_pays
       AND a.ville       IS NOT DISTINCT FROM v_ville
       AND a.building_id IS NOT DISTINCT FROM v_bat
       AND a.room_id     IS NOT DISTINCT FROM v_room
     ORDER BY a.nom_couverture;
END;
$function$;

REVOKE ALL ON FUNCTION public.agents_renseignement_ici() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.agents_renseignement_ici() TO authenticated, service_role;

-- ---------------------------------------------------------------------------
-- VUE DU MINISTRE PROPRIETAIRE. Le GD l'autorise a connaitre vraie identite,
-- role, couverture et etat de SES agents -- et de personne d'autre : le filtre
-- porte sur pays_proprietaire = le pays de l'appelant, jamais sur un parametre
-- venu du client.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cellule_renseignement_mes_cellules()
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
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
      'cellule', c.id, 'pays_cible', c.pays_cible, 'statut', c.statut,
      'mode_fin', c.mode_fin, 'cree_le', c.cree_le, 'echeance', c.echeance_le,
      'terminee_le', c.terminee_le,
      'agents', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                    'id', ag.id, 'role', ag.role, 'vrai_nom', ag.vrai_nom,
                    'couverture', ag.nom_couverture, 'dup', ag.dup, 'statut', ag.statut,
                    'leader', ag.leader_courant, 'ville', ag.ville,
                    'batiment', ag.building_id, 'piece', ag.room_id)
                    ORDER BY ag.role), '[]'::jsonb)
                   FROM public.agents_renseignement ag WHERE ag.cellule_id = c.id)
    ) AS x
    FROM public.cellules_renseignement c
   WHERE c.pays_proprietaire = v_pays
  ) s;

  RETURN jsonb_build_object('ok', true, 'pays', v_pays, 'cellules', v_res);
END;
$function$;

REVOKE ALL ON FUNCTION public.cellule_renseignement_mes_cellules() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cellule_renseignement_mes_cellules() TO authenticated, service_role;
