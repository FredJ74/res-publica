-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260922171710
-- Nom original      : renseignement_charge_utile_sans_mot_couverture
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-22 17:17:10 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : f009bf2fc9a8f3d821186c8ad1437212
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
-- LE NOM DU CHAMP TRAHISSAIT AUTANT QUE SA VALEUR. Ces deux RPC rendaient
-- « "couverture": "soviet" » : un transporteur qui regarde la reponse dans son navigateur y
-- lisait, en toutes lettres, que ce compagnon de route est sous COUVERTURE -- donc qu'il
-- releve du renseignement. C'est precisement ce que la regle interdit.
-- Le champ n'etait lu nulle part cote client (les cartes n'utilisent que nom et portrait, ce
-- dernier etant calcule ici depuis le role et le pays) : on le retire. Le ministre, lui,
-- garde tout dans cellule_renseignement_mes_cellules, qui n'est pas touchee.
CREATE OR REPLACE FUNCTION public.agents_couverture_de_mon_groupe()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $fn$
DECLARE v_moi text; v_res jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'id', ag.id, 'nom', ag.nom_couverture,
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
           'id', ag.id, 'nom', ag.nom_couverture,
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