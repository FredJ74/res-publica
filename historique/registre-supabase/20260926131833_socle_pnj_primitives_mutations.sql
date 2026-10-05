-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260926131833
-- Nom original      : socle_pnj_primitives_mutations
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-26 13:18:33 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 435d8c68662c892cf4008ededb40421f
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
-- PRIMITIVES DE MUTATION APPELABLES PAR LE CLIENT -- 26 septembre 2026
-- L'identite de l'acteur est TOUJOURS resolue par le serveur (mon_personnage), jamais recue
-- en parametre. L'autorite est : etre l'administrateur du PNJ (proprietaire personnel ou
-- titulaire du poste proprietaire) OU son leader courant.

CREATE OR REPLACE FUNCTION public.pnj_peut_commander(p_moi text, p_id text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT p_moi IS NOT NULL AND (
           p_moi = public.pnj_administrateur(p_id)
        OR p_moi = (SELECT leader_pj FROM public.pnj_membres WHERE id = p_id))
$$;

-- QUITTER LE GROUPE : la position est MATERIALISEE avant que le lien soit rompu. Le PNJ
-- reste exactement la ou il etait. Sa propriete ne change pas.
CREATE OR REPLACE FUNCTION public.pnj_quitter_groupe(p_ids text[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text; r record; pe record; v_n integer := 0;
BEGIN
  v_moi := CASE WHEN public.est_appel_serveur() THEN NULL ELSE public.mon_personnage() END;
  IF NOT public.est_appel_serveur() AND v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  FOR r IN SELECT id FROM public.pnj_membres WHERE id = ANY(p_ids) FOR UPDATE LOOP
    IF v_moi IS NOT NULL AND NOT public.pnj_peut_commander(v_moi, r.id) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante', 'pnj', r.id); END IF;
    SELECT * INTO pe FROM public.pnj_position_effective(r.id);
    UPDATE public.pnj_membres
       SET leader_pj = NULL, leader_pnj_id = NULL,
           ville = pe.ville, building_id = pe.building_id, room_id = pe.room_id
     WHERE id = r.id;
    v_n := v_n + 1;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'detaches', v_n);
END; $$;

-- TRANSFERT DE CONDUITE : co-presence exigee, AUCUNE acceptation du nouveau leader, et la
-- PROPRIETE NE CHANGE PAS.
CREATE OR REPLACE FUNCTION public.pnj_transferer(
  p_ids text[], p_dest text, p_dest_est_pnj boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text; r record; dv text; db text; dr text; pm record; v_n integer := 0;
BEGIN
  v_moi := CASE WHEN public.est_appel_serveur() THEN NULL ELSE public.mon_personnage() END;
  IF NOT public.est_appel_serveur() AND v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  IF p_dest_est_pnj THEN
    SELECT ville, building_id, room_id INTO dv, db, dr
      FROM public.pnj_position_effective(p_dest);
    IF NOT EXISTS (SELECT 1 FROM public.pnj_membres WHERE id = p_dest AND statut = 'actif') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_introuvable'); END IF;
  ELSE
    SELECT current_city, current_building, current_room INTO dv, db, dr
      FROM public.personnages_donnees WHERE name = p_dest;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_introuvable'); END IF;
  END IF;

  FOR r IN SELECT id FROM public.pnj_membres
            WHERE id = ANY(p_ids) AND statut = 'actif' FOR UPDATE LOOP
    IF v_moi IS NOT NULL AND NOT public.pnj_peut_commander(v_moi, r.id) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante', 'pnj', r.id); END IF;
    SELECT * INTO pm FROM public.pnj_position_effective(r.id);
    IF pm.ville IS DISTINCT FROM dv OR pm.building_id IS DISTINCT FROM db
       OR pm.room_id IS DISTINCT FROM dr THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_co_presents', 'pnj', r.id); END IF;
    IF p_dest_est_pnj THEN
      UPDATE public.pnj_membres SET leader_pj = NULL, leader_pnj_id = p_dest,
        ville = NULL, building_id = NULL, room_id = NULL, rue_noeud_id = NULL WHERE id = r.id;
    ELSE
      UPDATE public.pnj_membres SET leader_pnj_id = NULL, leader_pj = p_dest,
        ville = NULL, building_id = NULL, room_id = NULL, rue_noeud_id = NULL WHERE id = r.id;
    END IF;
    v_n := v_n + 1;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'transferes', v_n, 'nouveau_leader', p_dest);
END; $$;

-- REJOINDRE UN LEADER : l'inverse, pour qu'un administrateur reprenne un PNJ laisse sur place.
CREATE OR REPLACE FUNCTION public.pnj_prendre(p_ids text[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text; r record; pm record; mv text; mb text; mr text; v_n integer := 0;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT current_city, current_building, current_room INTO mv, mb, mr
    FROM public.personnages_donnees WHERE name = v_moi;
  FOR r IN SELECT id FROM public.pnj_membres
            WHERE id = ANY(p_ids) AND statut = 'actif' FOR UPDATE LOOP
    IF NOT public.pnj_peut_commander(v_moi, r.id) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante', 'pnj', r.id); END IF;
    SELECT * INTO pm FROM public.pnj_position_effective(r.id);
    IF pm.ville IS DISTINCT FROM mv OR pm.building_id IS DISTINCT FROM mb
       OR pm.room_id IS DISTINCT FROM mr THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_co_presents', 'pnj', r.id); END IF;
    UPDATE public.pnj_membres SET leader_pj = v_moi, leader_pnj_id = NULL,
      ville = NULL, building_id = NULL, room_id = NULL, rue_noeud_id = NULL WHERE id = r.id;
    v_n := v_n + 1;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'pris', v_n);
END; $$;

-- DONNER / RETIRER DE L'ARGENT. Atomique. Le sens 'donner' va du PJ vers le PNJ.
CREATE OR REPLACE FUNCTION public.pnj_argent_transferer(
  p_pnj text, p_montant numeric, p_sens text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text; v_pj numeric; v_pnj numeric;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_montant IS NULL OR p_montant <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide'); END IF;
  IF NOT public.pnj_peut_commander(v_moi, p_pnj) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante'); END IF;

  SELECT liquide INTO v_pj FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  SELECT liquide INTO v_pnj FROM public.pnj_membres WHERE id = p_pnj FOR UPDATE;
  IF v_pj IS NULL OR v_pnj IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;

  IF p_sens = 'donner' THEN
    IF v_pj < p_montant THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants'); END IF;
    UPDATE public.personnages_donnees SET liquide = v_pj - p_montant, arg = arg - p_montant
     WHERE name = v_moi;
    UPDATE public.pnj_membres SET liquide = v_pnj + p_montant WHERE id = p_pnj;
  ELSIF p_sens = 'retirer' THEN
    IF v_pnj < p_montant THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants'); END IF;
    UPDATE public.pnj_membres SET liquide = v_pnj - p_montant WHERE id = p_pnj;
    UPDATE public.personnages_donnees SET liquide = v_pj + p_montant, arg = arg + p_montant
     WHERE name = v_moi;
  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'sens_invalide'); END IF;

  RETURN jsonb_build_object('ok', true, 'sens', p_sens, 'montant', p_montant);
END; $$;

-- DONNER / RETIRER UN OBJET. Atomique : l'objet quitte un inventaire et entre dans l'autre
-- dans la meme transaction. Le client designe l'objet par son INDEX dans l'inventaire source,
-- jamais par son contenu -- il ne peut donc pas fabriquer un objet.
CREATE OR REPLACE FUNCTION public.pnj_objet_transferer(
  p_pnj text, p_index integer, p_sens text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text; v_inv jsonb; v_objet jsonb; v_poss record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT public.pnj_peut_commander(v_moi, p_pnj) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante'); END IF;

  IF p_sens = 'donner' THEN
    SELECT COALESCE(inventory, '[]'::jsonb) INTO v_inv
      FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
    IF p_index IS NULL OR p_index < 0 OR p_index >= jsonb_array_length(v_inv) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'index_invalide'); END IF;
    v_objet := v_inv -> p_index;
    UPDATE public.personnages_donnees
       SET inventory = (v_inv - p_index) WHERE name = v_moi;
    INSERT INTO public.pnj_possessions (pnj_id, objet) VALUES (p_pnj, v_objet);
    RETURN jsonb_build_object('ok', true, 'sens', 'donner', 'objet', v_objet);

  ELSIF p_sens = 'retirer' THEN
    SELECT * INTO v_poss FROM public.pnj_possessions
     WHERE pnj_id = p_pnj ORDER BY id OFFSET p_index LIMIT 1 FOR UPDATE;
    IF v_poss.id IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'index_invalide'); END IF;
    SELECT COALESCE(inventory, '[]'::jsonb) INTO v_inv
      FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
    UPDATE public.personnages_donnees
       SET inventory = v_inv || jsonb_build_array(v_poss.objet) WHERE name = v_moi;
    DELETE FROM public.pnj_possessions WHERE id = v_poss.id;
    RETURN jsonb_build_object('ok', true, 'sens', 'retirer', 'objet', v_poss.objet);
  END IF;
  RETURN jsonb_build_object('ok', false, 'raison', 'sens_invalide');
END; $$;

-- EVENEMENTS : ce que le proprietaire (ou le titulaire du poste proprietaire) doit savoir.
CREATE OR REPLACE FUNCTION public.pnj_evenements_lire(p_limite integer DEFAULT 30)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text; v_pays text; v_poste text; v_ville text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, poste->>'id', poste->>'city' INTO v_pays, v_poste, v_ville
    FROM public.personnages_donnees WHERE name = v_moi;
  RETURN jsonb_build_object('ok', true, 'evenements', COALESCE((
    SELECT jsonb_agg(jsonb_build_object('id', e.id, 'type', e.type, 'pnj', e.pnj_nom,
             'famille', e.famille, 'ville', e.ville, 'building_id', e.building_id,
             'room_id', e.room_id, 'cree_le', e.cree_le, 'lu', e.lu_le IS NOT NULL)
             ORDER BY e.cree_le DESC)
      FROM (SELECT * FROM public.pnj_evenements e2
             WHERE e2.proprietaire_pj = v_moi
                OR (e2.proprietaire_poste IS NOT NULL AND e2.pays = v_pays
                    AND e2.proprietaire_poste = v_poste
                    AND (e2.proprietaire_poste_ville IS NULL
                         OR e2.proprietaire_poste_ville = v_ville))
             ORDER BY e2.cree_le DESC LIMIT greatest(1, least(coalesce(p_limite,30), 100))) e
  ), '[]'::jsonb));
END; $$;

REVOKE ALL ON FUNCTION public.pnj_peut_commander(text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.pnj_quitter_groupe(text[]) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.pnj_transferer(text[], text, boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.pnj_prendre(text[]) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.pnj_argent_transferer(text, numeric, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.pnj_objet_transferer(text, integer, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.pnj_evenements_lire(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pnj_quitter_groupe(text[]) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.pnj_transferer(text[], text, boolean) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.pnj_prendre(text[]) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.pnj_argent_transferer(text, numeric, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.pnj_objet_transferer(text, integer, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.pnj_evenements_lire(integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.pnj_peut_commander(text, text) TO service_role;