-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260922070539
-- Nom original      : renseignement_decouplage_couverture_et_transfert
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-22 07:05:39 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 4bcef1de11aea2ab38be1bbc1b8b2734
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
-- BALAYAGE DE COLLECTE. Ne retenait que les agents POSES. Desormais : tout agent ayant une
-- position effective et qui n'est pas reste dans le bureau du ministre -- donc aussi ceux
-- qu'un PJ transporte. Le detail de l'exclusion est refait par chaque collecteur.
CREATE OR REPLACE FUNCTION public.cellules_renseignement_collecter()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $fn$
DECLARE r record; v_n integer := 0; v_faits integer := 0; v_res jsonb; v_res2 jsonb;
BEGIN
  FOR r IN
    SELECT a.id, a.role FROM public.agents_renseignement a
      JOIN public.cellules_renseignement c ON c.id = a.cellule_id
      LEFT JOIN LATERAL public.agent_position_effective(a.id) pe ON true
     WHERE c.statut = 'active' AND a.statut = 'actif'
       AND pe.ville IS NOT NULL AND pe.pays IS NOT NULL
       AND NOT public.agent_au_bureau_min_def(pe.building_id, pe.room_id)
  LOOP
    IF r.role = 'coordinateur' THEN
      v_res  := public.agent_coordinateur_multimodal(r.id);
      v_res2 := public.agent_coordinateur_port(r.id);
      v_faits := v_faits + coalesce((v_res ->> 'faits')::integer, 0)
                         + coalesce((v_res2 ->> 'faits')::integer, 0);
    ELSE
      v_res := CASE r.role
        WHEN 'garde'      THEN public.agent_garde_observer(r.id)
        WHEN 'traducteur' THEN public.agent_traducteur_ecouter(r.id)
        WHEN 'conseiller' THEN public.agent_conseillere_observer(r.id)
      END;
      v_faits := v_faits + coalesce((v_res ->> 'faits')::integer, 0);
    END IF;
    v_n := v_n + 1;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'agents', v_n, 'faits', v_faits);
END;
$fn$;

-- DEPOT. Le controle « pays_couverture » disparait : la couverture est narrative, elle ne
-- dit pas ou l'on a le droit d'etre. On enregistre en revanche le PAYS REEL, donnee qui
-- n'existait pas avant cette migration.
CREATE OR REPLACE FUNCTION public.agent_deposer(p_agent_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $fn$
DECLARE v_moi text; d record; a record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT country, current_city, current_building, current_room INTO d
    FROM public.personnages_donnees WHERE name = v_moi;
  IF d.current_building IS NULL OR d.current_room IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'position_indefinie'); END IF;

  SELECT ag.*, c.statut AS statut_cellule INTO a
    FROM public.agents_renseignement ag
    JOIN public.cellules_renseignement c ON c.id = ag.cellule_id
   WHERE ag.id = p_agent_id FOR UPDATE;
  IF a.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'agent_introuvable'); END IF;
  IF a.leader_courant IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_agent'); END IF;
  IF a.statut <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_indisponible', 'statut', a.statut); END IF;

  UPDATE public.agents_renseignement
     SET leader_courant = NULL, pays = d.country, ville = d.current_city,
         building_id = d.current_building, room_id = d.current_room, maj_le = now()
   WHERE id = p_agent_id;
  RETURN jsonb_build_object('ok', true, 'agent', p_agent_id, 'pays', d.country,
    'ville', d.current_city, 'batiment', d.current_building, 'piece', d.current_room);
END;
$fn$;

-- PRISE EN CHARGE. Le pays reel est efface en meme temps que la position : tant qu'il est
-- porte, l'agent n'a pas de position propre, c'est celle de sa locomotive qui fait foi.
CREATE OR REPLACE FUNCTION public.agent_prendre(p_agent_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $fn$
DECLARE v_moi text; d record; a record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT country, current_city, current_building, current_room INTO d
    FROM public.personnages_donnees WHERE name = v_moi;

  SELECT ag.*, c.pays_proprietaire, c.ministre, c.statut AS statut_cellule INTO a
    FROM public.agents_renseignement ag
    JOIN public.cellules_renseignement c ON c.id = ag.cellule_id
   WHERE ag.id = p_agent_id FOR UPDATE;
  IF a.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'agent_introuvable'); END IF;
  IF a.statut_cellule <> 'active' THEN RETURN jsonb_build_object('ok', false, 'raison', 'cellule_inactive'); END IF;
  IF a.statut <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_indisponible', 'statut', a.statut); END IF;
  IF a.leader_courant IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_en_groupe', 'leader', a.leader_courant); END IF;

  IF a.ville IS NULL THEN
    IF d.country IS DISTINCT FROM a.pays_proprietaire THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_empire');
    END IF;
  ELSE
    IF d.current_building IS NULL OR d.current_room IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'position_indefinie'); END IF;
    -- Co-presence PHYSIQUE COMPLETE, pays reel inclus. Avant cette migration le pays n'etait
    -- pas compare (il etait suppose egal a la couverture) ; deux villes homonymes dans deux
    -- empires auraient suffi a reprendre un agent a distance.
    IF d.country IS DISTINCT FROM a.pays
       OR d.current_city IS DISTINCT FROM a.ville
       OR d.current_building IS DISTINCT FROM a.building_id
       OR d.current_room IS DISTINCT FROM a.room_id THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_au_meme_endroit');
    END IF;
    IF d.country IS DISTINCT FROM a.pays_proprietaire AND v_moi IS DISTINCT FROM a.ministre THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_empire');
    END IF;
  END IF;

  UPDATE public.agents_renseignement
     SET leader_courant = v_moi, pays = NULL, ville = NULL,
         building_id = NULL, room_id = NULL, maj_le = now()
   WHERE id = p_agent_id;
  RETURN jsonb_build_object('ok', true, 'agent', p_agent_id, 'leader', v_moi);
END;
$fn$;

-- TRANSFERT ENTRE PJ (22 septembre 2026). Le destinataire n'accepte rien : il recoit le PNJ
-- dans son groupe et, s'il n'en veut pas, il le laisse sur place par l'ordre general. C'est la
-- regle generale du jeu pour tous les PNJ, appliquee ici sans exception.
-- Le transporteur n'apprend RIEN : la reponse ne porte ni vrai nom, ni role, ni cellule.
CREATE OR REPLACE FUNCTION public.agent_transferer(p_agent_id text, p_destinataire text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $fn$
DECLARE v_moi text; d record; e record; a record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(btrim(p_destinataire), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_absent'); END IF;
  IF p_destinataire = v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_est_moi'); END IF;

  SELECT country, current_city, current_building, current_room INTO d
    FROM public.personnages_donnees WHERE name = v_moi;
  IF d.current_building IS NULL OR d.current_room IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'position_indefinie'); END IF;

  SELECT country, current_city, current_building, current_room INTO e
    FROM public.personnages_donnees WHERE name = p_destinataire;
  IF e.current_building IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_introuvable'); END IF;

  -- CO-PRESENCE EXIGEE : on ne confie pas quelqu'un a distance.
  IF e.country IS DISTINCT FROM d.country
     OR e.current_city IS DISTINCT FROM d.current_city
     OR e.current_building IS DISTINCT FROM d.current_building
     OR e.current_room IS DISTINCT FROM d.current_room THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_au_meme_endroit');
  END IF;

  SELECT ag.*, c.statut AS statut_cellule INTO a
    FROM public.agents_renseignement ag
    JOIN public.cellules_renseignement c ON c.id = ag.cellule_id
   WHERE ag.id = p_agent_id FOR UPDATE;
  IF a.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'agent_introuvable'); END IF;
  IF a.statut_cellule <> 'active' THEN RETURN jsonb_build_object('ok', false, 'raison', 'cellule_inactive'); END IF;
  IF a.statut <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_indisponible', 'statut', a.statut); END IF;
  IF a.leader_courant IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_agent'); END IF;

  -- Le rattachement a l'operation (cellule_id) n'est PAS touche : seul le porteur change.
  UPDATE public.agents_renseignement
     SET leader_courant = p_destinataire, pays = NULL, ville = NULL,
         building_id = NULL, room_id = NULL, maj_le = now()
   WHERE id = p_agent_id;

  RETURN jsonb_build_object('ok', true, 'agent', p_agent_id, 'nouveau_leader', p_destinataire);
END;
$fn$;

GRANT EXECUTE ON FUNCTION public.agent_transferer(text, text) TO authenticated, service_role;