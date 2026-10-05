-- Fonctions et procedures stockees
-- ============================================================================
-- BASELINE Human Gambit -- domaine militaire -- phase 20 : fonctions
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- camion_batiment_interieur() -> text | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.camion_batiment_interieur()
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$ select 'camion-militaire'::text $function$;

-- camion_deplacer(text,text,boolean,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.camion_deplacer(p_camion_id text, p_destination_cle text, p_avec_officier boolean, p_cle text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; c record; a record; d record; v_rejeu jsonb; v_grade text;
  v_cout constant integer := 2;
  v_total integer; v_debarques text[] := '{}'; v_transportes_pj text[] := '{}';
  v_transportes_pnj text[] := '{}'; u record; v_res jsonb; v_compagnie text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(btrim(p_cle), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cle_requete_absente'); END IF;

  SELECT * INTO c FROM public.camions_militaires WHERE id = p_camion_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'camion_introuvable'); END IF;
  IF c.statut <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'camion_hors_service'); END IF;

  SELECT resultat INTO v_rejeu FROM public.camions_ordres WHERE requete = p_cle;
  IF FOUND THEN RETURN v_rejeu || jsonb_build_object('rejeu', true); END IF;

  SELECT country, current_city, current_building, current_room INTO a
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  IF a.country IS DISTINCT FROM c.pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_de_mon_pays'); END IF;
  IF NOT (a.current_city = c.ville
          AND a.current_building = public.camion_batiment_interieur()
          AND a.current_room = c.id) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'officier_absent_du_camion');
  END IF;

  v_grade := public.camion_grade_commandant(v_moi);
  IF v_grade IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'grade_insuffisant'); END IF;

  SELECT * INTO d FROM public.camion_destinations(p_camion_id)
   WHERE cle = p_destination_cle;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destination_refusee'); END IF;
  IF NOT p_avec_officier AND v_grade = 'lieutenant' AND p_destination_cle <> '__caserne__' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'envoi_a_vide_hors_caserne');
  END IF;

  SELECT count(*) INTO v_total FROM public.camion_occupants(p_camion_id);
  IF v_total > c.capacite THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'capacite_depassee',
      'occupants', v_total, 'capacite', c.capacite);
  END IF;

  IF p_avec_officier THEN
    IF EXISTS (SELECT 1 FROM public.camion_occupants(p_camion_id) o
                WHERE o.chef = v_moi
                  AND (o.est_pj OR o.classe = 'alpha')
                  AND COALESCE(o.pa, 0) < v_cout) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants_section',
        'cout_par_occupant', v_cout,
        'manquants', COALESCE((SELECT jsonb_agg(o.nom) FROM public.camion_occupants(p_camion_id) o
           WHERE o.chef = v_moi AND (o.est_pj OR o.classe = 'alpha')
             AND COALESCE(o.pa, 0) < v_cout), '[]'::jsonb));
    END IF;
  END IF;

  FOR u IN
    SELECT DISTINCT o.chef,
           (SELECT bool_or((x.est_pj OR x.classe = 'alpha') AND COALESCE(x.pa,0) < v_cout)
              FROM public.camion_occupants(p_camion_id) x WHERE x.chef = o.chef) AS sans_pa,
           (SELECT bool_or(x.est_pj) FROM public.camion_occupants(p_camion_id) x
             WHERE x.chef = o.chef AND x.ref = o.chef) AS est_pj
      FROM public.camion_occupants(p_camion_id) o
  LOOP
    IF u.chef = v_moi AND NOT p_avec_officier THEN
      UPDATE public.personnages_donnees
         SET current_city = c.ville, current_building = c.building_id,
             current_room = c.room_id, updated_at = now()
       WHERE name = v_moi;
      DELETE FROM public.camions_embarquements
       WHERE camion_id = c.id AND personnage = v_moi;
      CONTINUE;
    END IF;
    IF u.sans_pa THEN
      IF COALESCE(u.est_pj, false) THEN
        UPDATE public.personnages_donnees
           SET current_city = c.ville, current_building = c.building_id,
               current_room = c.room_id, updated_at = now()
         WHERE name = u.chef;
        DELETE FROM public.camions_embarquements
         WHERE camion_id = c.id AND personnage = u.chef;
      ELSE
        UPDATE public.pnj_membres
           SET ville = c.ville, building_id = c.building_id, room_id = c.room_id,
               rue_noeud_id = NULL, maj_le = now()
         WHERE id = u.chef;
      END IF;
      v_debarques := v_debarques || u.chef;
    END IF;
  END LOOP;

  SELECT COALESCE(array_agg(o.ref), '{}') INTO v_transportes_pj
    FROM public.camion_occupants(p_camion_id) o WHERE o.est_pj;
  SELECT COALESCE(array_agg(o.ref), '{}') INTO v_transportes_pnj
    FROM public.camion_occupants(p_camion_id) o
   WHERE NOT o.est_pj AND o.classe = 'alpha';

  IF array_length(v_transportes_pj, 1) > 0 THEN
    UPDATE public.personnages_donnees
       SET pa = pa - v_cout, updated_at = now()
     WHERE name = ANY(v_transportes_pj);
  END IF;
  IF array_length(v_transportes_pnj, 1) > 0 THEN
    PERFORM public.pnj_pa_debiter(v_transportes_pnj, v_cout);
  END IF;

  UPDATE public.camions_militaires
     SET ville = d.ville, building_id = d.building_id, room_id = d.room_id,
         maj_le = now()
   WHERE id = c.id;

  IF array_length(v_transportes_pj, 1) > 0 THEN
    UPDATE public.personnages_donnees SET current_city = d.ville, updated_at = now()
     WHERE name = ANY(v_transportes_pj);
  END IF;
  UPDATE public.pnj_membres
     SET ville = d.ville, maj_le = now()
   WHERE building_id = public.camion_batiment_interieur() AND room_id = c.id;

  IF array_length(v_transportes_pnj, 1) > 0 THEN
    FOR v_compagnie IN
      SELECT DISTINCT m.proprietaire_perimetre
        FROM public.pnj_membres m
       WHERE m.id = ANY(v_transportes_pnj) AND m.famille = 'soldat'
         AND m.proprietaire_perimetre IS NOT NULL
    LOOP
      PERFORM public.militaire_blob_projeter(
        regexp_replace(v_compagnie, '-s[0-9]+$', ''));
    END LOOP;
  END IF;

  v_res := jsonb_build_object('ok', true, 'camion_id', c.id,
    'depart', jsonb_build_object('ville', c.ville, 'building_id', c.building_id,
                                 'room_id', c.room_id),
    'arrivee', jsonb_build_object('ville', d.ville, 'building_id', d.building_id,
                                  'room_id', d.room_id, 'libelle', d.libelle),
    'avec_officier', p_avec_officier, 'grade', v_grade,
    'cout_par_occupant', v_cout,
    'transportes_pj', to_jsonb(v_transportes_pj),
    'transportes_pnj', COALESCE(array_length(v_transportes_pnj, 1), 0),
    'debarques', to_jsonb(v_debarques));

  INSERT INTO public.camions_ordres (requete, camion_id, acteur, action, destination, resultat)
       VALUES (p_cle, c.id, v_moi,
               CASE WHEN p_avec_officier THEN 'trajet' ELSE 'a_vide' END,
               p_destination_cle, v_res);
  RETURN v_res;
EXCEPTION WHEN unique_violation THEN
  SELECT resultat INTO v_rejeu FROM public.camions_ordres WHERE requete = p_cle;
  RETURN COALESCE(v_rejeu, '{}'::jsonb) || jsonb_build_object('rejeu', true);
END; $function$;

-- camion_descendre(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.camion_descendre(p_camion_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; c record; a record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO c FROM public.camions_militaires WHERE id = p_camion_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'camion_introuvable'); END IF;
  SELECT current_city, current_building, current_room INTO a
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  IF NOT (a.current_building = public.camion_batiment_interieur()
          AND a.current_room = c.id) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_a_bord');
  END IF;

  UPDATE public.personnages_donnees
     SET current_city = c.ville, current_building = c.building_id,
         current_room = c.room_id, updated_at = now()
   WHERE name = v_moi;
  DELETE FROM public.camions_embarquements
   WHERE camion_id = c.id AND personnage = v_moi;

  RETURN jsonb_build_object('ok', true, 'camion_id', c.id, 'ville', c.ville,
    'building_id', c.building_id, 'room_id', c.room_id);
END; $function$;

-- camion_destinations(text) -> TABLE(cle text, ville text, building_id text, room_id text, libelle text, rang integer) | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.camion_destinations(p_camion_id text)
 RETURNS TABLE(cle text, ville text, building_id text, room_id text, libelle text, rang integer)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  WITH cam AS (SELECT * FROM public.camions_militaires WHERE id = p_camion_id)
  SELECT d.cle, d.ville, d.building_id, d.room_id, d.libelle, d.rang
    FROM public.camions_destinations d, cam c
   WHERE d.pays = c.pays
     AND NOT (d.ville = c.ville AND d.building_id = c.building_id AND d.room_id = c.room_id)
  UNION ALL
  SELECT '__caserne__', c.caserne_ville, c.caserne_building, c.caserne_room,
         c.caserne_libelle, -1
    FROM cam c
   WHERE NOT (c.caserne_ville = c.ville AND c.caserne_building = c.building_id
              AND c.caserne_room = c.room_id)
   ORDER BY 6, 5;
$function$;

-- camion_etat(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.camion_etat(p_camion_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; c record; a record; v_grade text; v_dedans boolean;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO c FROM public.camions_militaires WHERE id = p_camion_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'camion_introuvable'); END IF;
  SELECT country, current_city, current_building, current_room, pa INTO a
    FROM public.personnages_donnees WHERE name = v_moi;
  IF a.country IS DISTINCT FROM c.pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_de_mon_pays'); END IF;

  v_dedans := a.current_city = c.ville
          AND a.current_building = public.camion_batiment_interieur()
          AND a.current_room = c.id;
  v_grade  := public.camion_grade_commandant(v_moi);

  RETURN jsonb_build_object(
    'ok', true,
    'camion', jsonb_build_object(
      'id', c.id, 'libelle', c.libelle, 'capacite', c.capacite,
      'image_url', c.image_url, 'pays', c.pays,
      'ville', c.ville, 'building_id', c.building_id, 'room_id', c.room_id,
      'caserne', jsonb_build_object('ville', c.caserne_ville,
        'building_id', c.caserne_building, 'room_id', c.caserne_room,
        'libelle', c.caserne_libelle)),
    'moi', jsonb_build_object('nom', v_moi, 'pa', a.pa, 'ville', a.current_city,
      'building_id', a.current_building, 'room_id', a.current_room),
    'dedans', v_dedans,
    'grade', v_grade,
    'peut_commander', (v_grade IS NOT NULL AND v_dedans),
    'occupants_total', (SELECT count(*) FROM public.camion_occupants(p_camion_id)),
    'destinations', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('cle', d.cle, 'libelle', d.libelle) ORDER BY d.rang, d.libelle)
        FROM public.camion_destinations(p_camion_id) d), '[]'::jsonb));
END; $function$;

-- camion_grade_commandant(text) -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.camion_grade_commandant(p_nom text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT t.g FROM (SELECT public.militaire_grade_effectif(p_nom) AS g) t
   WHERE t.g IN ('lieutenant', 'capitaine');
$function$;

-- camion_monter(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.camion_monter(p_camion_id text, p_cle text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; c record; a record; v_rejeu jsonb;
  v_grade text; v_ma_troupe integer; v_prioritaire boolean;
  v_occupants integer; v_apres integer; v_place integer;
  v_ejectes text[] := '{}'; u record; v_taille integer;
  v_res jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(btrim(p_cle), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cle_requete_absente'); END IF;

  SELECT * INTO c FROM public.camions_militaires WHERE id = p_camion_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'camion_introuvable'); END IF;
  IF c.statut <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'camion_hors_service'); END IF;

  SELECT resultat INTO v_rejeu FROM public.camions_ordres WHERE requete = p_cle;
  IF FOUND THEN RETURN v_rejeu || jsonb_build_object('rejeu', true); END IF;

  SELECT country, current_city, current_building, current_room INTO a
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  IF a.country IS DISTINCT FROM c.pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_de_mon_pays'); END IF;

  IF a.current_city = c.ville
     AND a.current_building = public.camion_batiment_interieur()
     AND a.current_room = c.id THEN
    RETURN jsonb_build_object('ok', true, 'deja_dedans', true, 'camion_id', c.id);
  END IF;

  IF NOT (a.current_city = c.ville AND a.current_building = c.building_id
          AND a.current_room = c.room_id) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;

  v_grade := public.camion_grade_commandant(v_moi);
  SELECT count(*) INTO v_ma_troupe FROM public.pnj_membres m
    LEFT JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
   WHERE m.statut = 'actif' AND m.leader_pj = v_moi AND m.famille = 'soldat'
     AND COALESCE(sm.en_reserve, false) = false;
  v_prioritaire := (v_grade IS NOT NULL AND v_ma_troupe > 0);

  SELECT count(*) INTO v_occupants FROM public.camion_occupants(p_camion_id);
  SELECT 1 + count(*) INTO v_taille FROM public.pnj_membres m
    LEFT JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
   WHERE m.statut = 'actif' AND m.leader_pj = v_moi
     AND COALESCE(sm.en_reserve, false) = false;
  v_apres := v_occupants + v_taille;

  IF v_apres > c.capacite THEN
    IF NOT v_prioritaire THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'camion_complet',
        'capacite', c.capacite, 'occupants', v_occupants, 'demande', v_taille);
    END IF;
    IF v_taille > c.capacite THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'section_trop_nombreuse',
        'capacite', c.capacite, 'section', v_taille);
    END IF;
    v_place := v_apres - c.capacite;
    FOR u IN
      SELECT o.ref AS nom,
             (SELECT count(*) FROM public.camion_occupants(p_camion_id) x
               WHERE x.chef = o.ref) AS taille,
             o.monte_le
        FROM public.camion_occupants(p_camion_id) o
       WHERE o.est_pj = true
       ORDER BY o.monte_le DESC NULLS FIRST, o.ref DESC
    LOOP
      EXIT WHEN v_place <= 0;
      UPDATE public.personnages_donnees
         SET current_city = c.ville, current_building = c.building_id,
             current_room = c.room_id, updated_at = now()
       WHERE name = u.nom;
      DELETE FROM public.camions_embarquements
       WHERE camion_id = c.id AND personnage = u.nom;
      v_ejectes := v_ejectes || u.nom;
      v_place := v_place - u.taille;
    END LOOP;
    IF v_place > 0 THEN
      UPDATE public.pnj_membres m
         SET ville = c.ville, building_id = c.building_id, room_id = c.room_id,
             rue_noeud_id = NULL, maj_le = now()
       WHERE m.id IN (SELECT o.ref FROM public.camion_occupants(p_camion_id) o
                       WHERE o.est_pj = false AND o.chef = o.ref);
    END IF;
    SELECT count(*) INTO v_occupants FROM public.camion_occupants(p_camion_id);
    IF v_occupants + v_taille > c.capacite THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'capacite_insuffisante',
        'capacite', c.capacite, 'occupants', v_occupants, 'demande', v_taille);
    END IF;
  END IF;

  UPDATE public.personnages_donnees
     SET current_city = c.ville,
         current_building = public.camion_batiment_interieur(),
         current_room = c.id, updated_at = now()
   WHERE name = v_moi;
  INSERT INTO public.camions_embarquements (camion_id, personnage, monte_le)
       VALUES (c.id, v_moi, now())
  ON CONFLICT (camion_id, personnage) DO UPDATE SET monte_le = now();

  v_res := jsonb_build_object('ok', true, 'camion_id', c.id,
    'building_id', public.camion_batiment_interieur(), 'room_id', c.id,
    'ville', c.ville, 'embarques', v_taille, 'debarques', to_jsonb(v_ejectes),
    'occupants', (SELECT count(*) FROM public.camion_occupants(p_camion_id)));

  INSERT INTO public.camions_ordres (requete, camion_id, acteur, action, resultat)
       VALUES (p_cle, c.id, v_moi, 'monter', v_res);
  RETURN v_res;
EXCEPTION WHEN unique_violation THEN
  SELECT resultat INTO v_rejeu FROM public.camions_ordres WHERE requete = p_cle;
  RETURN COALESCE(v_rejeu, '{}'::jsonb) || jsonb_build_object('rejeu', true);
END; $function$;

-- camion_occupants(text) -> TABLE(est_pj boolean, ref text, nom text, famille text, classe text, pa integer, chef text, monte_le timestamp with time zone) | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.camion_occupants(p_camion_id text)
 RETURNS TABLE(est_pj boolean, ref text, nom text, famille text, classe text, pa integer, chef text, monte_le timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  WITH cam AS (SELECT * FROM public.camions_militaires WHERE id = p_camion_id),
  pj AS (
    SELECT d.name, d.pa
      FROM public.personnages_donnees d, cam c
     WHERE d.current_city     = c.ville
       AND d.current_building = public.camion_batiment_interieur()
       AND d.current_room     = c.id
  ),
  pnj AS (
    SELECT m.id, m.nom, m.famille, m.pa,
           public.pnj_classe_de(m.id) AS classe,
           COALESCE(m.leader_pj,
                    (SELECT l.leader_pj FROM public.pnj_membres l WHERE l.id = m.leader_pnj_id),
                    m.leader_pnj_id, m.id) AS chef
      FROM cam c
      JOIN public.pnj_membres m ON m.statut = 'actif'
      JOIN LATERAL public.pnj_position_effective(m.id) pe ON true
      LEFT JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
     WHERE COALESCE(sm.en_reserve, false) = false
       AND pe.ville       IS NOT DISTINCT FROM c.ville
       AND pe.building_id = public.camion_batiment_interieur()
       AND pe.room_id     = c.id
  )
  SELECT true, pj.name, pj.name, NULL::text, 'pj'::text, pj.pa, pj.name,
         (SELECT e.monte_le FROM public.camions_embarquements e
           WHERE e.camion_id = p_camion_id AND e.personnage = pj.name)
    FROM pj
  UNION ALL
  SELECT false, pnj.id, pnj.nom, pnj.famille, pnj.classe, pnj.pa, pnj.chef,
         (SELECT e.monte_le FROM public.camions_embarquements e
           WHERE e.camion_id = p_camion_id AND e.personnage = pnj.chef)
    FROM pnj;
$function$;

-- camions_ici(text,text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.camions_ici(p_pays text, p_ville text, p_building text, p_room text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  RETURN jsonb_build_object('ok', true, 'camions', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
             'id', c.id, 'libelle', c.libelle, 'capacite', c.capacite,
             'image_url', c.image_url, 'caserne', c.caserne_libelle,
             'occupants', (SELECT count(*) FROM public.camion_occupants(c.id))
           ) ORDER BY c.libelle)
      FROM public.camions_militaires c
     WHERE c.statut = 'actif'
       AND c.pays        = p_pays
       AND c.ville       = p_ville
       AND c.building_id = p_building
       AND c.room_id     = p_room
  ), '[]'::jsonb));
END; $function$;

-- caserne_stock_mouvement(text,text,integer,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.caserne_stock_mouvement(p_pays text, p_produit text, p_delta integer, p_lot text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_data jsonb; v_stock jsonb; v_lots jsonb; v_file jsonb;
  v_cur integer; v_reste integer; v_servis jsonb := '[]'::jsonb;
  v_tete jsonb; v_q integer; v_pris integer;
BEGIN
  IF COALESCE(btrim(p_pays), '') = '' OR COALESCE(btrim(p_produit), '') = ''
     OR p_delta IS NULL OR p_delta = 0 OR abs(p_delta) > 100000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  IF p_delta > 0 AND COALESCE(btrim(p_lot), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'lot_obligatoire');
  END IF;

  SELECT data INTO v_data FROM public.budgets_nationaux WHERE id = p_pays FOR UPDATE;
  IF NOT FOUND THEN
    IF p_delta < 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'stock_insuffisant', 'stock', 0); END IF;
    v_data := '{}'::jsonb;
    INSERT INTO public.budgets_nationaux (id, data, updated_at) VALUES (p_pays, v_data, now());
  END IF;
  v_data := COALESCE(v_data, '{}'::jsonb);

  v_stock := CASE WHEN jsonb_typeof(v_data -> 'stockArmurerieMilitaire') = 'object'
                  THEN v_data -> 'stockArmurerieMilitaire' ELSE '{}'::jsonb END;
  v_lots  := CASE WHEN jsonb_typeof(v_data -> 'lotsMilitaires') = 'object'
                  THEN v_data -> 'lotsMilitaires' ELSE '{}'::jsonb END;
  v_cur   := GREATEST(0, COALESCE((v_stock ->> p_produit)::integer, 0));
  v_file  := CASE WHEN jsonb_typeof(v_lots -> p_produit) = 'array'
                  THEN v_lots -> p_produit ELSE '[]'::jsonb END;

  IF v_cur + p_delta < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_insuffisant', 'stock', v_cur);
  END IF;

  IF p_delta > 0 THEN
    v_file := v_file || jsonb_build_array(jsonb_build_object('lot', p_lot, 'qte', p_delta));
  ELSE
    v_reste := -p_delta;
    WHILE v_reste > 0 AND jsonb_array_length(v_file) > 0 LOOP
      v_tete := v_file -> 0;
      v_q    := GREATEST(0, COALESCE((v_tete ->> 'qte')::integer, 0));
      v_pris := LEAST(v_q, v_reste);
      IF v_pris > 0 THEN
        v_servis := v_servis || jsonb_build_array(jsonb_build_object('lot', v_tete ->> 'lot', 'qte', v_pris));
        v_reste := v_reste - v_pris;
      END IF;
      IF v_q - v_pris <= 0 THEN v_file := v_file - 0;
      ELSE v_file := jsonb_set(v_file, ARRAY['0','qte'], to_jsonb(v_q - v_pris)); END IF;
    END LOOP;
    IF v_reste > 0 THEN
      v_servis := v_servis || jsonb_build_array(jsonb_build_object('lot', 'legacy', 'qte', v_reste));
    END IF;
  END IF;

  v_stock := v_stock || jsonb_build_object(p_produit, v_cur + p_delta);
  v_lots  := v_lots  || jsonb_build_object(p_produit, v_file);
  v_data  := v_data  || jsonb_build_object('stockArmurerieMilitaire', v_stock, 'lotsMilitaires', v_lots);

  PERFORM set_config('rp.armurerie_militaire', '1', true);
  UPDATE public.budgets_nationaux SET data = v_data, updated_at = now() WHERE id = p_pays;
  PERFORM set_config('rp.armurerie_militaire', '', true);

  RETURN jsonb_build_object('ok', true, 'produit', p_produit, 'stock', v_cur + p_delta, 'lots', v_servis);
END; $function$;

-- caserne_virement_journalier_fixer(integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.caserne_virement_journalier_fixer(p_montant integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  c_plafond constant integer := 1000000;
  v_moi text; v_pays text; v_montant integer;
BEGIN
  -- exiger_poste leve si l'acteur n'est pas le Ministre de la Defense ATTESTE.
  v_moi := public.exiger_poste('min_def');
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'appel_serveur_interdit'); END IF;

  -- LA JURIDICTION N'EST PAS UN PARAMETRE : c'est le pays de l'acteur. Un Ministre ne peut donc
  -- pas fixer le virement d'un autre empire, meme en forgeant la requete.
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;

  v_montant := greatest(0, least(c_plafond, coalesce(p_montant, 0)));

  PERFORM set_config('rp.virement_caserne', '1', true);
  -- Ecriture par SOUS-CLE sous verrou : aucune reecriture de blob, donc aucun ecrasement des
  -- autres cles (reserveJour, repartition, refectoire, caserneMatieres, stock d'armurerie...).
  UPDATE public.budgets_nationaux
     SET data = jsonb_set(coalesce(data, '{}'::jsonb), '{virementJournalierCaserne}', to_jsonb(v_montant)),
         updated_at = now()
   WHERE id = v_pays;
  PERFORM set_config('rp.virement_caserne', '0', true);

  RETURN jsonb_build_object('ok', true, 'pays', v_pays, 'montant', v_montant);
END;
$function$;

-- effort_produire_lot(text,text,text,jsonb,jsonb,numeric,text,text,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.effort_produire_lot(p_pays text, p_commande_id text, p_armurerie text, p_entrepots jsonb, p_recette jsonb, p_cout_revient numeric, p_lot text, p_arme_label text, p_ville_arm text, p_jour integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_cmd public.commandes_militaires%ROWTYPE;
  v_ids text[]; v_id text; v_etats jsonb := '{}'::jsonb; v_d jsonb;
  v_mat text; v_besoin numeric; v_dispo numeric; v_reste numeric; v_pris numeric;
  v_stock jsonb; v_res jsonb; v_caisse text; v_solde numeric;
  v_ent jsonb; v_arm jsonb; v_parlot integer; v_mvt jsonb; v_conso jsonb := '{}'::jsonb;
BEGIN
  IF COALESCE(p_cout_revient, -1) < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cout_invalide');
  END IF;
  IF p_entrepots IS NULL OR jsonb_typeof(p_entrepots) <> 'array'
     OR jsonb_array_length(p_entrepots) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_entrepot');
  END IF;
  v_parlot := GREATEST(1, COALESCE((p_recette ->> 'produitParLot')::integer, 1));

  SELECT * INTO v_cmd FROM public.commandes_militaires WHERE id = p_commande_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'commande_absente'); END IF;
  IF v_cmd.statut <> 'en_cours' THEN RETURN jsonb_build_object('ok', false, 'raison', 'commande_close'); END IF;
  IF v_cmd.quantite_produite + v_parlot > v_cmd.quantite_demandee THEN
    v_parlot := v_cmd.quantite_demandee - v_cmd.quantite_produite;
    IF v_parlot <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'commande_complete'); END IF;
  END IF;

  SELECT COALESCE(array_agg(x ORDER BY x), ARRAY[]::text[]) INTO v_ids
  FROM (SELECT public.eg_etat_id(p_pays, e) AS x FROM jsonb_array_elements(p_entrepots) e) s;
  FOREACH v_id IN ARRAY v_ids LOOP
    SELECT public.eg_etat_lire(data) INTO v_d FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
    IF FOUND THEN v_etats := v_etats || jsonb_build_object(v_id, v_d); END IF;
  END LOOP;
  IF v_etats = '{}'::jsonb THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucun_entrepot_trouve'); END IF;

  FOR v_mat IN SELECT k FROM jsonb_object_keys(COALESCE(p_recette -> 'materiaux', '{}'::jsonb)) k LOOP
    v_besoin := COALESCE((p_recette -> 'materiaux' ->> v_mat)::numeric, 0);
    v_dispo := 0;
    FOR v_id IN SELECT k2 FROM jsonb_object_keys(v_etats) k2 ORDER BY 1 LOOP
      v_ent := COALESCE(v_etats -> v_id -> 'entrepot', '{}'::jsonb);
      v_dispo := v_dispo + LEAST(
        GREATEST(0, COALESCE((v_ent -> 'stock' ->> v_mat)::numeric, 0)),
        GREATEST(0, COALESCE((v_ent -> 'reserveMilitaire' ->> v_mat)::numeric, 0)));
    END LOOP;
    IF v_dispo < v_besoin THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'matieres_insuffisantes',
                                'matiere', v_mat, 'requis', v_besoin, 'reserve', v_dispo);
    END IF;
  END LOOP;

  v_caisse := p_pays || '_caserne-militaire';
  SELECT COALESCE((data ->> 'solde')::numeric, 0) INTO v_solde
    FROM public.caisses_batiments WHERE id = v_caisse FOR UPDATE;
  IF NOT FOUND THEN v_solde := 0; END IF;
  IF v_solde < p_cout_revient THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante', 'solde', v_solde);
  END IF;

  SELECT data INTO v_arm FROM public.entreprises WHERE id = p_armurerie FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'armurerie_absente'); END IF;

  FOR v_mat IN SELECT k FROM jsonb_object_keys(COALESCE(p_recette -> 'materiaux', '{}'::jsonb)) k LOOP
    v_reste := COALESCE((p_recette -> 'materiaux' ->> v_mat)::numeric, 0);
    FOR v_id IN SELECT k2 FROM jsonb_object_keys(v_etats) k2 ORDER BY 1 LOOP
      EXIT WHEN v_reste <= 0;
      v_d     := v_etats -> v_id;
      v_ent   := COALESCE(v_d -> 'entrepot', '{}'::jsonb);
      v_stock := COALESCE(v_ent -> 'stock', '{}'::jsonb);
      v_res   := COALESCE(v_ent -> 'reserveMilitaire', '{}'::jsonb);
      v_pris := LEAST(v_reste,
                      GREATEST(0, COALESCE((v_stock ->> v_mat)::numeric, 0)),
                      GREATEST(0, COALESCE((v_res   ->> v_mat)::numeric, 0)));
      CONTINUE WHEN v_pris <= 0;
      v_stock := v_stock || jsonb_build_object(v_mat, COALESCE((v_stock ->> v_mat)::numeric, 0) - v_pris);
      v_res   := v_res   || jsonb_build_object(v_mat, COALESCE((v_res   ->> v_mat)::numeric, 0) - v_pris);
      v_ent   := v_ent   || jsonb_build_object('stock', v_stock, 'reserveMilitaire', v_res);
      v_etats := v_etats || jsonb_build_object(v_id, v_d || jsonb_build_object('entrepot', v_ent));
      v_reste := v_reste - v_pris;
      v_conso := v_conso || jsonb_build_object(v_mat, COALESCE((v_conso ->> v_mat)::numeric, 0) + v_pris);
    END LOOP;
  END LOOP;

  FOR v_id IN SELECT k FROM jsonb_object_keys(v_etats) k ORDER BY 1 LOOP
    UPDATE public.batiments_etat SET data = to_jsonb((v_etats -> v_id)::text), updated_at = now() WHERE id = v_id;
  END LOOP;

  UPDATE public.caisses_batiments
     SET data = COALESCE(data, '{}'::jsonb) || jsonb_build_object('solde', v_solde - p_cout_revient), updated_at = now()
   WHERE id = v_caisse;

  v_arm := COALESCE(v_arm, '{}'::jsonb);
  v_arm := v_arm || jsonb_build_object(
    'caisse', COALESCE((v_arm ->> 'caisse')::numeric, 0) + p_cout_revient,
    'historique', COALESCE(v_arm -> 'historique', '[]'::jsonb) || jsonb_build_array(
      jsonb_build_object('jour', p_jour, 'montant', p_cout_revient,
                         'motif', 'Commande militaire — ' || COALESCE(p_arme_label, ''))));
  UPDATE public.entreprises SET data = v_arm, updated_at = now() WHERE id = p_armurerie;

  v_mvt := public.caserne_stock_mouvement(p_pays, v_cmd.produit, v_parlot, p_lot);
  IF COALESCE((v_mvt ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'caserne_stock_mouvement a echoue: %', v_mvt;
  END IF;

  UPDATE public.commandes_militaires
     SET quantite_produite = quantite_produite + v_parlot,
         statut = CASE WHEN quantite_produite + v_parlot >= quantite_demandee THEN 'terminee' ELSE 'en_cours' END,
         updated_at = now()
   WHERE id = p_commande_id;

  INSERT INTO public.registre_ventes_armes (joueur, arme, prix, pays, city, jour, heure)
  VALUES (COALESCE(v_arm ->> 'proprietaire', 'PNJ'),
          COALESCE(p_arme_label, v_cmd.produit) || ' (commande militaire)',
          round(p_cout_revient)::integer, p_pays, p_ville_arm, COALESCE(p_jour, 1), 0);

  RETURN jsonb_build_object('ok', true, 'produit', v_cmd.produit, 'quantite', v_parlot,
                            'lot', p_lot, 'cout', p_cout_revient, 'matieres', v_conso,
                            'armurerie', p_armurerie,
                            'caisseArmurerie', COALESCE((v_arm ->> 'caisse')::numeric, 0),
                            'caisseCaserne', v_solde - p_cout_revient);
END;
$function$;

-- effort_ravitailler(text,jsonb,jsonb,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.effort_ravitailler(p_pays text, p_entrepots jsonb, p_cibles jsonb, p_prix jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_ids text[]; v_id text; v_etats jsonb := '{}'::jsonb; v_d jsonb; v_res text;
  v_reste numeric; v_pris numeric; v_prix numeric; v_cout numeric; v_total numeric := 0;
  v_caisse text; v_solde numeric; v_ent jsonb; v_stock jsonb; v_resv jsonb; v_dispo numeric;
  v_achats jsonb := '{}'::jsonb; v_data jsonb; v_commun jsonb;
BEGIN
  IF p_entrepots IS NULL OR jsonb_typeof(p_entrepots) <> 'array'
     OR jsonb_array_length(p_entrepots) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_entrepot');
  END IF;
  v_caisse := p_pays || '_caserne-militaire';
  SELECT COALESCE((data ->> 'solde')::numeric, 0) INTO v_solde
    FROM public.caisses_batiments WHERE id = v_caisse FOR UPDATE;
  IF NOT FOUND THEN v_solde := 0; END IF;
  IF v_solde <= 0 THEN RETURN jsonb_build_object('ok', true, 'achats', '{}'::jsonb, 'total', 0); END IF;

  SELECT COALESCE(array_agg(x ORDER BY x), ARRAY[]::text[]) INTO v_ids
  FROM (SELECT public.eg_etat_id(p_pays, e) AS x FROM jsonb_array_elements(p_entrepots) e) s;
  FOREACH v_id IN ARRAY v_ids LOOP
    SELECT public.eg_etat_lire(data) INTO v_d FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
    IF FOUND THEN v_etats := v_etats || jsonb_build_object(v_id, v_d); END IF;
  END LOOP;
  IF v_etats = '{}'::jsonb THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucun_entrepot_trouve'); END IF;

  FOR v_res IN SELECT k FROM jsonb_object_keys(COALESCE(p_cibles, '{}'::jsonb)) k ORDER BY 1 LOOP
    v_reste := GREATEST(0, COALESCE((p_cibles ->> v_res)::numeric, 0));
    v_prix  := GREATEST(0, COALESCE((p_prix ->> v_res)::numeric, 0));
    CONTINUE WHEN v_reste <= 0 OR v_prix <= 0;
    FOR v_id IN SELECT k2 FROM jsonb_object_keys(v_etats) k2 ORDER BY 1 LOOP
      EXIT WHEN v_reste <= 0 OR v_solde < v_prix;
      v_d     := v_etats -> v_id;
      v_ent   := COALESCE(v_d -> 'entrepot', '{}'::jsonb);
      v_stock := COALESCE(v_ent -> 'stock', '{}'::jsonb);
      v_resv  := COALESCE(v_ent -> 'reserveMilitaire', '{}'::jsonb);
      v_dispo := GREATEST(0, COALESCE((v_stock ->> v_res)::numeric, 0))
               - GREATEST(0, COALESCE((v_resv  ->> v_res)::numeric, 0));
      v_pris := LEAST(v_reste, GREATEST(0, v_dispo), floor(v_solde / v_prix));
      CONTINUE WHEN v_pris <= 0;
      v_cout  := v_pris * v_prix;
      v_stock := v_stock || jsonb_build_object(v_res, COALESCE((v_stock ->> v_res)::numeric, 0) - v_pris);
      v_ent   := v_ent || jsonb_build_object('stock', v_stock,
                   'caisse', COALESCE((v_ent ->> 'caisse')::numeric, 0) + v_cout);
      v_etats := v_etats || jsonb_build_object(v_id, v_d || jsonb_build_object('entrepot', v_ent));
      v_solde := v_solde - v_cout;
      v_total := v_total + v_cout;
      v_reste := v_reste - v_pris;
      v_achats := v_achats || jsonb_build_object(v_res, COALESCE((v_achats ->> v_res)::numeric, 0) + v_pris);
    END LOOP;
  END LOOP;

  IF v_total <= 0 THEN RETURN jsonb_build_object('ok', true, 'achats', '{}'::jsonb, 'total', 0); END IF;

  FOR v_id IN SELECT k FROM jsonb_object_keys(v_etats) k ORDER BY 1 LOOP
    UPDATE public.batiments_etat SET data = to_jsonb((v_etats -> v_id)::text), updated_at = now() WHERE id = v_id;
  END LOOP;
  UPDATE public.caisses_batiments
     SET data = COALESCE(data, '{}'::jsonb) || jsonb_build_object('solde', v_solde), updated_at = now()
   WHERE id = v_caisse;

  -- DESTINATION : le stock COMMUN de la caserne, plus refectoire.brut.
  SELECT data INTO v_data FROM public.budgets_nationaux WHERE id = p_pays FOR UPDATE;
  v_data := COALESCE(v_data, '{}'::jsonb);
  v_commun := CASE WHEN jsonb_typeof(v_data -> 'caserneMatieres') = 'object'
                   THEN v_data -> 'caserneMatieres' ELSE '{}'::jsonb END;
  FOR v_res IN SELECT k FROM jsonb_object_keys(v_achats) k LOOP
    v_commun := v_commun || jsonb_build_object(v_res,
      COALESCE((v_commun ->> v_res)::numeric, 0) + COALESCE((v_achats ->> v_res)::numeric, 0));
  END LOOP;
  UPDATE public.budgets_nationaux
     SET data = v_data || jsonb_build_object('caserneMatieres', v_commun), updated_at = now()
   WHERE id = p_pays;

  RETURN jsonb_build_object('ok', true, 'achats', v_achats, 'total', v_total, 'solde', v_solde);
END; $function$;

-- effort_reserve_appliquer(text,jsonb,text[],numeric) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.effort_reserve_appliquer(p_pays text, p_entrepots jsonb, p_ressources text[], p_pct numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_pct numeric; v_id text; v_ids text[] := ARRAY[]::text[];
  v_etats jsonb := '{}'::jsonb; v_d jsonb; v_stock jsonb; v_res text;
  v_total numeric; v_cible numeric; v_pose numeric; v_q numeric;
  v_dispo numeric; v_reste numeric; v_avance boolean;
  v_reserves jsonb := '{}'::jsonb; v_totaux jsonb := '{}'::jsonb; v_obj jsonb;
BEGIN
  IF NOT public.est_appel_serveur() AND public.mon_personnage() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  IF COALESCE(btrim(p_pays), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  IF p_entrepots IS NULL OR jsonb_typeof(p_entrepots) <> 'array' OR jsonb_array_length(p_entrepots) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_entrepot');
  END IF;
  IF p_ressources IS NULL OR array_length(p_ressources, 1) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_ressource');
  END IF;
  v_pct := LEAST(100, GREATEST(0, COALESCE(p_pct, 0)));

  SELECT array_agg(x ORDER BY x) INTO v_ids
  FROM (SELECT public.eg_etat_id(p_pays, e) AS x FROM jsonb_array_elements(p_entrepots) AS e) s;

  FOREACH v_id IN ARRAY v_ids LOOP
    SELECT public.eg_etat_lire(data) INTO v_d FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
    IF NOT FOUND THEN CONTINUE; END IF;
    v_etats := v_etats || jsonb_build_object(v_id, v_d);
  END LOOP;
  IF v_etats = '{}'::jsonb THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_entrepot_trouve');
  END IF;

  FOREACH v_res IN ARRAY p_ressources LOOP
    v_total := 0;
    FOR v_id IN SELECT k FROM jsonb_object_keys(v_etats) k ORDER BY 1 LOOP
      v_stock := COALESCE(v_etats -> v_id -> 'entrepot' -> 'stock', '{}'::jsonb);
      v_total := v_total + GREATEST(0, COALESCE((v_stock ->> v_res)::numeric, 0));
    END LOOP;
    v_cible  := floor(v_total * v_pct / 100.0);
    v_totaux := v_totaux || jsonb_build_object(v_res, v_cible);
    v_pose := 0;
    FOR v_id IN SELECT k FROM jsonb_object_keys(v_etats) k ORDER BY 1 LOOP
      v_stock := COALESCE(v_etats -> v_id -> 'entrepot' -> 'stock', '{}'::jsonb);
      v_dispo := GREATEST(0, COALESCE((v_stock ->> v_res)::numeric, 0));
      v_q := CASE WHEN v_total > 0 THEN LEAST(v_dispo, floor(v_cible * v_dispo / v_total)) ELSE 0 END;
      v_reserves := v_reserves || jsonb_build_object(
        v_id, COALESCE(v_reserves -> v_id, '{}'::jsonb) || jsonb_build_object(v_res, v_q));
      v_pose := v_pose + v_q;
    END LOOP;
    v_reste := v_cible - v_pose;
    WHILE v_reste > 0 LOOP
      v_avance := false;
      FOR v_id IN SELECT k FROM jsonb_object_keys(v_etats) k ORDER BY 1 LOOP
        EXIT WHEN v_reste <= 0;
        v_stock := COALESCE(v_etats -> v_id -> 'entrepot' -> 'stock', '{}'::jsonb);
        v_dispo := GREATEST(0, COALESCE((v_stock ->> v_res)::numeric, 0));
        v_q := COALESCE((v_reserves -> v_id ->> v_res)::numeric, 0);
        IF v_q < v_dispo THEN
          v_reserves := v_reserves || jsonb_build_object(
            v_id, (v_reserves -> v_id) || jsonb_build_object(v_res, v_q + 1));
          v_reste  := v_reste - 1;
          v_avance := true;
        END IF;
      END LOOP;
      EXIT WHEN NOT v_avance;
    END LOOP;
  END LOOP;

  FOR v_id IN SELECT k FROM jsonb_object_keys(v_etats) k ORDER BY 1 LOOP
    v_d   := v_etats -> v_id;
    v_obj := COALESCE(v_d -> 'entrepot', '{}'::jsonb);
    IF v_pct = 0 THEN
      v_obj := v_obj - 'reserveMilitaire';
    ELSE
      v_obj := v_obj || jsonb_build_object('reserveMilitaire', COALESCE(v_reserves -> v_id, '{}'::jsonb));
    END IF;
    v_d := v_d || jsonb_build_object('entrepot', v_obj);
    UPDATE public.batiments_etat SET data = to_jsonb(v_d::text), updated_at = now() WHERE id = v_id;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'pct', v_pct, 'reserves', v_reserves, 'totaux', v_totaux);
END;
$function$;

-- guerre_acteur_poste(text) -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.guerre_acteur_poste(p_poste text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce(d.country, 'republic')
    FROM public.personnages_donnees d
   WHERE d.user_id = auth.uid() AND (d.poste ->> 'id') = p_poste
   LIMIT 1;
$function$;

-- guerre_cessez_le_feu_activer(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.guerre_cessez_le_feu_activer(p_guerre_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_pays text; g record; v_cf jsonb; v_actif jsonb; v_tous boolean;
BEGIN
  v_pays := public.guerre_acteur_poste('min_def');
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_ministre_defense');
  END IF;

  SELECT * INTO g FROM public.guerres WHERE id = p_guerre_id FOR UPDATE;
  IF NOT FOUND OR g.statut <> 'active' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'guerre_introuvable');
  END IF;
  IF v_pays NOT IN (g.data ->> 'attaquant', g.data ->> 'attaque') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pays_non_belligerant');
  END IF;

  v_cf := g.data -> 'ceasefire';
  IF v_cf IS NULL OR jsonb_typeof(v_cf) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_treve_proposee');
  END IF;
  IF (v_cf ->> 'refuseePar') IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'treve_refusee');
  END IF;
  IF (v_cf ->> 'accepteePar') IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'treve_non_acceptee');
  END IF;

  v_actif := coalesce(v_cf -> 'actifPar', '{}'::jsonb) || jsonb_build_object(v_pays, true);
  v_tous  := (v_actif ? (g.data ->> 'attaquant')) AND (v_actif ? (g.data ->> 'attaque'));

  UPDATE public.guerres
     SET statut = CASE WHEN v_tous THEN 'terminee' ELSE 'active' END,
         data   = g.data || jsonb_build_object('ceasefire', v_cf || jsonb_build_object('actifPar', v_actif))
   WHERE id = p_guerre_id;

  RETURN jsonb_build_object('ok', true, 'pays', v_pays, 'terminee', v_tous);
END;
$function$;

-- guerre_declarer(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.guerre_declarer(p_pays_attaque text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_pays text; v_id text;
BEGIN
  v_pays := public.guerre_acteur_poste('president');
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_president');
  END IF;
  IF p_pays_attaque IS NULL OR btrim(p_pays_attaque) = '' OR p_pays_attaque = v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide');
  END IF;
  -- Une seule guerre active entre deux memes pays, quel que soit le sens.
  IF EXISTS (SELECT 1 FROM public.guerres g
              WHERE g.statut = 'active'
                AND ((g.data ->> 'attaquant' = v_pays AND g.data ->> 'attaque' = p_pays_attaque)
                  OR (g.data ->> 'attaque' = v_pays AND g.data ->> 'attaquant' = p_pays_attaque))) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'guerre_deja_active');
  END IF;

  v_id := 'guerre-' || (extract(epoch from clock_timestamp()) * 1000)::bigint;
  INSERT INTO public.guerres (id, statut, data)
  VALUES (v_id, 'active', jsonb_build_object(
    'attaquant', v_pays, 'attaque', p_pays_attaque,
    'jourDebut', public.jour_de_jeu_pays(v_pays), 'ceasefire', NULL));

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'attaquant', v_pays, 'attaque', p_pays_attaque);
END;
$function$;

-- guerre_treve_proposer(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.guerre_treve_proposer(p_guerre_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_pays text; v_moi text; g record; v_cf jsonb;
BEGIN
  v_pays := public.guerre_acteur_poste('min_ae');
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_ministre_ae');
  END IF;
  v_moi := public.mon_personnage();

  SELECT * INTO g FROM public.guerres WHERE id = p_guerre_id FOR UPDATE;
  IF NOT FOUND OR g.statut <> 'active' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'guerre_introuvable');
  END IF;
  IF v_pays NOT IN (g.data ->> 'attaquant', g.data ->> 'attaque') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pays_non_belligerant');
  END IF;

  -- Une proposition deja en attente de reponse n'est pas remplacee en silence.
  v_cf := g.data -> 'ceasefire';
  IF v_cf IS NOT NULL AND jsonb_typeof(v_cf) = 'object'
     AND (v_cf ->> 'accepteePar') IS NULL
     AND (v_cf ->> 'refuseePar') IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'proposition_deja_en_attente',
                              'proposePays', v_cf ->> 'proposePays');
  END IF;

  UPDATE public.guerres
     SET data = g.data || jsonb_build_object('ceasefire', jsonb_build_object(
           'proposePar',  v_moi,
           'proposePays', v_pays,          -- <- ce qui rend le destinataire calculable
           'accepteePar', NULL,
           'refuseePar',  NULL,
           'actifPar',    '{}'::jsonb))
   WHERE id = p_guerre_id;

  RETURN jsonb_build_object('ok', true, 'proposePar', v_moi, 'proposePays', v_pays,
    'destinataire', CASE WHEN v_pays = (g.data ->> 'attaquant')
                         THEN g.data ->> 'attaque' ELSE g.data ->> 'attaquant' END);
END;
$function$;

-- guerre_treve_repondre(text,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.guerre_treve_repondre(p_guerre_id text, p_accepte boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_pays text; v_moi text; g record; v_cf jsonb; v_destinataire text;
BEGIN
  v_pays := public.guerre_acteur_poste('min_ae');
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_ministre_ae');
  END IF;
  v_moi := public.mon_personnage();

  SELECT * INTO g FROM public.guerres WHERE id = p_guerre_id FOR UPDATE;
  IF NOT FOUND OR g.statut <> 'active' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'guerre_introuvable');
  END IF;

  v_cf := g.data -> 'ceasefire';
  IF v_cf IS NULL OR jsonb_typeof(v_cf) <> 'object' OR (v_cf ->> 'proposePays') IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_proposition');
  END IF;
  IF (v_cf ->> 'accepteePar') IS NOT NULL OR (v_cf ->> 'refuseePar') IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'proposition_deja_tranchee');
  END IF;

  -- LE DESTINATAIRE est l'autre belligerant, jamais celui qui a propose.
  v_destinataire := CASE WHEN (v_cf ->> 'proposePays') = (g.data ->> 'attaquant')
                         THEN g.data ->> 'attaque' ELSE g.data ->> 'attaquant' END;
  IF v_pays IS DISTINCT FROM v_destinataire THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_destinataire',
                              'destinataire', v_destinataire);
  END IF;

  IF coalesce(p_accepte, false) THEN
    v_cf := v_cf || jsonb_build_object('accepteePar', v_moi, 'accepteePays', v_pays);
  ELSE
    v_cf := v_cf || jsonb_build_object('refuseePar', v_moi, 'refuseePays', v_pays);
  END IF;

  UPDATE public.guerres SET data = g.data || jsonb_build_object('ceasefire', v_cf)
   WHERE id = p_guerre_id;

  RETURN jsonb_build_object('ok', true, 'accepte', coalesce(p_accepte, false), 'par', v_moi);
END;
$function$;

-- militaire_accepter_capitaine(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_accepter_capitaine(p_nomination_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_moi text; v_n record; v_data jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO v_n FROM public.nominations_militaires WHERE id = p_nomination_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'nomination_introuvable'); END IF;
  IF v_n.destinataire IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_destinataire'); END IF;
  IF v_n.traitee THEN RETURN jsonb_build_object('ok', true, 'rejeu', true); END IF;
  IF v_n.grade <> 'capitaine' THEN RETURN jsonb_build_object('ok', false, 'raison', 'grade_invalide'); END IF;

  SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = v_n.compagnie_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;
  IF COALESCE(v_data->>'capitaineNom','') <> '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_deja_commandee'); END IF;

  UPDATE public.compagnies_militaires
     SET data = v_data || jsonb_build_object('capitaineNom', v_moi)
   WHERE id = v_n.compagnie_id;
  UPDATE public.personnages_donnees
     SET poste = jsonb_build_object('id','capitaine','compagnieId', v_n.compagnie_id), updated_at = now()
   WHERE name = v_moi;
  UPDATE public.nominations_militaires SET traitee = true WHERE id = p_nomination_id;
  RETURN jsonb_build_object('ok', true, 'compagnie', v_n.compagnie_id, 'capitaine', v_moi);
END; $function$;

-- militaire_accepter_lieutenant(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_accepter_lieutenant(p_nomination_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  c_places constant integer := 24;
  v_moi text; v_n record; v_data jsonb; v_secs jsonb; v_trouve boolean := false;
  v_reserve jsonb; v_deja integer; v_tire integer; v_pris jsonb; v_reste jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO v_n FROM public.nominations_militaires WHERE id = p_nomination_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'nomination_introuvable'); END IF;
  IF v_n.destinataire IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_destinataire'); END IF;
  IF v_n.traitee THEN RETURN jsonb_build_object('ok', true, 'rejeu', true); END IF;
  IF v_n.grade <> 'lieutenant' THEN RETURN jsonb_build_object('ok', false, 'raison', 'grade_invalide'); END IF;

  SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = v_n.compagnie_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;

  -- Combien d'hommes la section compte-t-elle deja, et combien la reserve peut-elle en fournir ?
  SELECT count(*) INTO v_deja
    FROM jsonb_array_elements(coalesce(v_data->'sections', '[]'::jsonb)) s,
         jsonb_array_elements(coalesce(s->'soldats', '[]'::jsonb)) sol
   WHERE s->>'id' = v_n.section_id;
  v_reserve := CASE WHEN jsonb_typeof(v_data->'reserve') = 'array'
                    THEN v_data->'reserve' ELSE '[]'::jsonb END;
  -- Jamais plus de 24 places : la limite est desormais APPLIQUEE cote serveur, elle n'etait
  -- jusqu'ici qu'une taille de lot pour la generation des matricules, verifiee nulle part.
  v_tire := least(greatest(0, c_places - v_deja), jsonb_array_length(v_reserve));

  SELECT coalesce(jsonb_agg(sol ORDER BY pos) FILTER (WHERE pos <= v_tire), '[]'::jsonb),
         coalesce(jsonb_agg(sol ORDER BY pos) FILTER (WHERE pos > v_tire), '[]'::jsonb)
    INTO v_pris, v_reste
    FROM jsonb_array_elements(v_reserve) WITH ORDINALITY AS t(sol, pos);

  SELECT COALESCE(jsonb_agg(
           CASE WHEN s->>'id' = v_n.section_id AND COALESCE(s->>'lieutenantNom','') = ''
                THEN s || jsonb_build_object('lieutenantNom', v_moi,
                       'soldats', coalesce(s->'soldats', '[]'::jsonb) || v_pris)
                ELSE s END ORDER BY ord), '[]'::jsonb)
    INTO v_secs
    FROM jsonb_array_elements(COALESCE(v_data->'sections','[]'::jsonb)) WITH ORDINALITY AS t(s, ord);
  SELECT EXISTS (SELECT 1 FROM jsonb_array_elements(v_secs) s
                  WHERE s->>'id' = v_n.section_id AND s->>'lieutenantNom' = v_moi) INTO v_trouve;
  IF NOT v_trouve THEN RETURN jsonb_build_object('ok', false, 'raison', 'section_indisponible'); END IF;

  UPDATE public.compagnies_militaires
     SET data = v_data || jsonb_build_object('sections', v_secs, 'reserve', v_reste)
   WHERE id = v_n.compagnie_id;
  UPDATE public.personnages_donnees
     SET poste = jsonb_build_object('id','lieutenant','compagnieId', v_n.compagnie_id,
                                    'sectionId', v_n.section_id), updated_at = now()
   WHERE name = v_moi;
  UPDATE public.nominations_militaires SET traitee = true WHERE id = p_nomination_id;

  RETURN jsonb_build_object('ok', true, 'compagnie', v_n.compagnie_id, 'section', v_n.section_id,
                            'hommes', v_tire, 'places', c_places,
                            'incomplete', (v_deja + v_tire) < c_places,
                            'reserve_restante', jsonb_array_length(v_reste));
END;
$function$;

-- militaire_accessoires_section(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.militaire_accessoires_section(p_compagnie_id text, p_section_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE g record;
BEGIN
  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;

  RETURN jsonb_build_object('ok', true, 'portes', COALESCE((
    SELECT jsonb_object_agg(t.matricule, t.objets)
      FROM (SELECT sm.matricule,
                   jsonb_agg(jsonb_build_object('id', p.objet->>'id',
                              'name', COALESCE(p.objet->>'name', p.objet->>'nom'),
                              'produitMilitaire', p.objet->>'produitMilitaire')
                             ORDER BY p.id) AS objets
              FROM public.pnj_soldats_metier sm
              JOIN public.pnj_membres m ON m.id = sm.pnj_id
              JOIN public.pnj_possessions p ON p.pnj_id = sm.pnj_id
             WHERE sm.compagnie_id = p_compagnie_id AND sm.section_id = p_section_id
               AND m.statut = 'actif'
             GROUP BY sm.matricule) t
  ), '{}'::jsonb));
END; $function$;

-- militaire_affectation_decouvrir() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_affectation_decouvrir()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  c_places constant integer := 24;
  v_moi text; v_bat text; v_pays text; v_c record; v_data jsonb; v_sec jsonb;
  v_sols jsonb; v_total integer; v_pnj_pos integer; v_pnj jsonb; v_reserve jsonb;
  v_deja integer; v_tire integer; v_pris jsonb; v_reste jsonb; v_secs jsonb;
  v_chef text; v_effectif integer; v_sec_nom text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(current_building,''), coalesce(country,'republic') INTO v_bat, v_pays
    FROM public.personnages_donnees WHERE name = v_moi;
  IF v_bat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  IF v_bat <> 'caserne-militaire' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;

  SELECT * INTO v_c FROM public.candidatures_militaires
   WHERE candidat = v_moi AND statut = 'acceptee' AND echeance > now()
   ORDER BY accepte_le LIMIT 1 FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucune_affectation'); END IF;

  SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = v_c.compagnie_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;

  -- Le nom lisible de la section, lu AVANT toute reecriture du blob.
  IF v_c.section_id IS NOT NULL THEN
    SELECT coalesce(s->>'nom', 'section ' || coalesce(s->>'numero', s->>'id'))
      INTO v_sec_nom
      FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb)) s
     WHERE s->>'id' = v_c.section_id;
  END IF;

  IF v_c.grade_vise = 'capitaine' THEN
    IF coalesce(v_data->>'capitaineNom','') <> '' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_deja_commandee');
    END IF;
    UPDATE public.compagnies_militaires
       SET data = v_data || jsonb_build_object('capitaineNom', v_moi) WHERE id = v_c.compagnie_id;
    UPDATE public.personnages_donnees
       SET poste = jsonb_build_object('id','capitaine','compagnieId', v_c.compagnie_id),
           updated_at = now() WHERE name = v_moi;
    SELECT count(*) INTO v_effectif
      FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb)) s,
           jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol;

  ELSIF v_c.grade_vise = 'lieutenant' THEN
    SELECT count(*) INTO v_deja
      FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb)) s,
           jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol
     WHERE s->>'id' = v_c.section_id;
    v_reserve := CASE WHEN jsonb_typeof(v_data->'reserve') = 'array' THEN v_data->'reserve' ELSE '[]'::jsonb END;
    v_tire := least(greatest(0, c_places - v_deja), jsonb_array_length(v_reserve));
    SELECT coalesce(jsonb_agg(sol ORDER BY pos) FILTER (WHERE pos <= v_tire), '[]'::jsonb),
           coalesce(jsonb_agg(sol ORDER BY pos) FILTER (WHERE pos > v_tire), '[]'::jsonb)
      INTO v_pris, v_reste
      FROM jsonb_array_elements(v_reserve) WITH ORDINALITY AS t(sol, pos);

    SELECT coalesce(jsonb_agg(
             CASE WHEN s->>'id' = v_c.section_id AND coalesce(s->>'lieutenantNom','') = ''
                  THEN s || jsonb_build_object('lieutenantNom', v_moi,
                         'soldats', coalesce(s->'soldats','[]'::jsonb) || v_pris)
                  ELSE s END ORDER BY ord), '[]'::jsonb) INTO v_secs
      FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb)) WITH ORDINALITY AS t(s, ord);
    IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_secs) s
                    WHERE s->>'id' = v_c.section_id AND s->>'lieutenantNom' = v_moi) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'section_indisponible');
    END IF;
    UPDATE public.compagnies_militaires
       SET data = v_data || jsonb_build_object('sections', v_secs, 'reserve', v_reste)
     WHERE id = v_c.compagnie_id;
    UPDATE public.personnages_donnees
       SET poste = jsonb_build_object('id','lieutenant','compagnieId', v_c.compagnie_id,
                                      'sectionId', v_c.section_id), updated_at = now()
     WHERE name = v_moi;
    v_chef := v_data->>'capitaineNom';
    v_effectif := v_deja + v_tire;

  ELSE
    SELECT s INTO v_sec FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb)) s
     WHERE s->>'id' = v_c.section_id;
    IF v_sec IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'section_introuvable'); END IF;
    v_sols := CASE WHEN jsonb_typeof(v_sec->'soldats') = 'array' THEN v_sec->'soldats' ELSE '[]'::jsonb END;
    v_total := jsonb_array_length(v_sols);
    v_reserve := CASE WHEN jsonb_typeof(v_data->'reserve') = 'array' THEN v_data->'reserve' ELSE '[]'::jsonb END;

    IF v_total < c_places THEN
      v_sols := v_sols || jsonb_build_array(jsonb_build_object('pj', true, 'nom', v_moi));
    ELSE
      SELECT pos, sol INTO v_pnj_pos, v_pnj
        FROM jsonb_array_elements(v_sols) WITH ORDINALITY AS t(sol, pos)
       WHERE NOT coalesce((sol->>'pj')::boolean, false) ORDER BY pos LIMIT 1;
      IF v_pnj IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'section_pleine');
      END IF;
      SELECT coalesce(jsonb_agg(sol ORDER BY pos), '[]'::jsonb) INTO v_sols
        FROM jsonb_array_elements(v_sols) WITH ORDINALITY AS t(sol, pos) WHERE pos <> v_pnj_pos;
      v_sols := v_sols || jsonb_build_array(jsonb_build_object('pj', true, 'nom', v_moi));
      v_reserve := v_reserve || jsonb_build_array(v_pnj);
    END IF;

    UPDATE public.compagnies_militaires
       SET data = public.militaire_sections_remplacer(v_data, v_c.section_id,
                    v_sec || jsonb_build_object('soldats', v_sols))
                  || jsonb_build_object('reserve', v_reserve)
     WHERE id = v_c.compagnie_id;
    PERFORM public.militaire_service_ouvrir(v_moi, v_pays, 'soldat', v_c.compagnie_id, v_c.section_id);
    v_chef := v_sec->>'lieutenantNom';
    v_effectif := jsonb_array_length(v_sols);
  END IF;

  UPDATE public.candidatures_militaires
     SET statut = 'finalisee', finalise_le = now() WHERE id = v_c.id;

  RETURN jsonb_build_object('ok', true, 'grade', v_c.grade_vise,
    'compagnie_id', v_c.compagnie_id, 'compagnie_nom', coalesce(v_data->>'nom', v_c.compagnie_id),
    'section_id', v_c.section_id, 'section_nom', v_sec_nom, 'recruteur', v_c.accepte_par,
    'chef', v_chef, 'effectif', v_effectif,
    'pnj_rendu_reserve', (v_pnj IS NOT NULL), 'matricule_rendu', v_pnj->>'matricule');
END;
$function$;

-- militaire_affectations_expirer() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_affectations_expirer()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_n integer := 0; r record;
BEGIN
  FOR r IN SELECT * FROM public.candidatures_militaires
            WHERE statut = 'acceptee' AND echeance <= now() FOR UPDATE
  LOOP
    UPDATE public.candidatures_militaires SET statut = 'expiree' WHERE id = r.id;
    INSERT INTO public.mails (id, from_player, to_player, subject, body, time, read)
    VALUES ('ce-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-' || substr(md5(random()::text),1,6),
            'État-major', r.candidat,
            'Engagement caduc — délai dépassé',
            'Vous ne vous êtes pas présenté(e) à la Caserne Militaire dans les 48 heures. ' ||
            'Votre engagement au grade de ' || r.grade_vise || ' est caduc et la place a été rendue. ' ||
            'Vous pouvez déposer une nouvelle candidature à la Caserne.',
            to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'), false);
    v_n := v_n + 1;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'expirees', v_n);
END;
$function$;

-- militaire_affecter_leader(text,text,integer,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.militaire_affecter_leader(p_compagnie_id text, p_section_id text, p_nb integer, p_leader text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE g record; v_sec jsonb; v_dispo int;
        v_mv text; v_mb text; v_mr text; v_lv text; v_lb text; v_lr text;
        v_pays_l text; v_pays_m text; v_membre boolean;
BEGIN
  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;
  IF COALESCE(p_nb,0) <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'nombre_invalide'); END IF;
  IF coalesce(btrim(coalesce(p_leader,'')),'') = '' OR p_leader = g.o_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'leader_invalide');
  END IF;

  SELECT current_city, current_building, current_room, country INTO v_mv, v_mb, v_mr, v_pays_m
    FROM public.personnages_donnees WHERE name = g.o_moi;
  SELECT current_city, current_building, current_room, country INTO v_lv, v_lb, v_lr, v_pays_l
    FROM public.personnages_donnees WHERE name = p_leader;
  IF v_pays_l IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'leader_introuvable'); END IF;
  IF v_pays_l IS DISTINCT FROM v_pays_m THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'leader_hors_juridiction'); END IF;
  IF v_lv IS DISTINCT FROM v_mv OR v_lb IS DISTINCT FROM v_mb OR v_lr IS DISTINCT FROM v_mr THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'leader_absent'); END IF;

  -- La cible doit rester un SOLDAT JOUEUR de cette section : donnee METIER, lue dans le blob.
  SELECT s INTO v_sec FROM jsonb_array_elements(g.o_data->'sections') s WHERE s->>'id' = p_section_id;
  SELECT EXISTS (
    SELECT 1 FROM jsonb_array_elements(COALESCE(v_sec->'soldats','[]'::jsonb)) s
     WHERE coalesce((s->>'pj')::boolean, false) AND s->>'nom' = p_leader
  ) INTO v_membre;
  IF NOT v_membre THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'leader_hors_section'); END IF;

  SELECT count(*) INTO v_dispo
    FROM public.pnj_membres m JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
   WHERE sm.compagnie_id = p_compagnie_id AND sm.section_id = p_section_id
     AND m.statut = 'actif' AND m.leader_pj = g.o_moi;
  IF v_dispo < p_nb THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_assez_avec_vous', 'disponibles', v_dispo);
  END IF;

  UPDATE public.pnj_membres SET leader_pj = p_leader, maj_le = now()
   WHERE id IN (SELECT m.id FROM public.pnj_membres m
                  JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
                 WHERE sm.compagnie_id = p_compagnie_id AND sm.section_id = p_section_id
                   AND m.statut = 'actif' AND m.leader_pj = g.o_moi
                 ORDER BY sm.matricule LIMIT p_nb);
  PERFORM public.militaire_blob_projeter(p_compagnie_id);

  RETURN jsonb_build_object('ok', true, 'affectes', p_nb, 'leader', p_leader);
END; $function$;

-- militaire_arme_operationnelle(text) -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.militaire_arme_operationnelle(p_pnj_id text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce(
    (SELECT b.cle FROM public.pnj_possessions p
        JOIN public.militaire_armes_bonus b
          ON b.cle = coalesce(p.objet->>'produitMilitaire', p.objet->>'name')
       WHERE p.pnj_id = p_pnj_id AND p.objet->>'type' = 'arme' AND b.mode = 'feu'
       ORDER BY b.bonus DESC, b.cle LIMIT 1),
    (SELECT b.cle FROM public.pnj_possessions p
        JOIN public.militaire_armes_bonus b
          ON b.cle = coalesce(p.objet->>'produitMilitaire', p.objet->>'name')
       WHERE p.pnj_id = p_pnj_id AND p.objet->>'type' = 'arme' AND b.mode = 'cac'
       ORDER BY b.bonus DESC, b.cle LIMIT 1),
    'corps_a_corps');
$function$;

-- militaire_arme_recalculer(text) -> text | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.militaire_arme_recalculer(p_pnj_id text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_arme text; v_compagnie text; v_mat text; v_data jsonb;
BEGIN
  SELECT sm.compagnie_id, sm.matricule INTO v_compagnie, v_mat
    FROM public.pnj_soldats_metier sm WHERE sm.pnj_id = p_pnj_id;
  IF v_compagnie IS NULL THEN RETURN NULL; END IF;

  v_arme := public.militaire_arme_operationnelle(p_pnj_id);
  UPDATE public.pnj_soldats_metier SET arme = v_arme WHERE pnj_id = p_pnj_id;

  -- Le blob, soldat par soldat, sans toucher a quoi que ce soit d'autre : on
  -- reecrit la seule cle 'arme' de la seule entree qui porte ce matricule.
  SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = v_compagnie FOR UPDATE;
  IF v_data IS NOT NULL THEN
    UPDATE public.compagnies_militaires
       SET data = jsonb_set(v_data, '{sections}', (
             SELECT coalesce(jsonb_agg(
               CASE WHEN EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) so
                                  WHERE so->>'matricule' = v_mat)
                    THEN jsonb_set(s, '{soldats}', (
                           SELECT coalesce(jsonb_agg(
                             CASE WHEN so->>'matricule' = v_mat
                                  THEN so || jsonb_build_object('arme', v_arme)
                                  ELSE so END ORDER BY o2), '[]'::jsonb)
                             FROM jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb))
                                  WITH ORDINALITY AS t2(so, o2)))
                    ELSE s END ORDER BY o1), '[]'::jsonb)
               FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb))
                    WITH ORDINALITY AS t1(s, o1))),
           updated_at = now()
     WHERE id = v_compagnie;
  END IF;

  PERFORM public.militaire_blob_projeter(v_compagnie);
  RETURN v_arme;
END; $function$;

-- militaire_armurerie_transfert(text,text,text,integer,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_armurerie_transfert(p_compagnie_id text, p_section_id text, p_produit text, p_qte integer, p_sens text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  c_pa constant integer := 1;
  g record; v_pays text; v_sec jsonb; v_stock jsonb; v_dispo int; v_mvt jsonb;
  v_pa int; v_paye jsonb;
BEGIN
  IF p_produit NOT IN ('arme_de_poing', 'mitraillette') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'produit_invalide');
  END IF;
  IF COALESCE(p_qte, 0) <= 0 OR p_qte > 100000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide');
  END IF;
  IF p_sens NOT IN ('vers_section', 'vers_armurerie') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'sens_invalide');
  END IF;

  -- AUTORITE : le lieutenant de CETTE section. Refuse le capitaine, le commandant et tout autre.
  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;
  SELECT country, COALESCE(pa, 0) INTO v_pays, v_pa
    FROM public.personnages_donnees WHERE name = g.o_moi FOR UPDATE;

  -- COUT DE L'ORDRE, verifie AVANT tout mouvement de stock : un refus doit etre lisible.
  IF COALESCE(v_pa, 0) < c_pa THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants',
                              'requis', c_pa, 'pa_reel', COALESCE(v_pa, 0));
  END IF;

  SELECT s INTO v_sec FROM jsonb_array_elements(g.o_data->'sections') s WHERE s->>'id' = p_section_id;
  v_stock := CASE WHEN jsonb_typeof(v_sec->'stockArmes') = 'object' THEN v_sec->'stockArmes'
                  ELSE jsonb_build_object('arme_de_poing',0,'mitraillette',0) END;

  IF p_sens = 'vers_section' THEN
    v_mvt := public.caserne_stock_mouvement(v_pays, p_produit, -p_qte, NULL);
    IF COALESCE((v_mvt->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_mvt; END IF;
    v_stock := v_stock || jsonb_build_object(p_produit,
                 GREATEST(0, COALESCE((v_stock->>p_produit)::int, 0)) + p_qte);
  ELSE
    v_dispo := GREATEST(0, COALESCE((v_stock->>p_produit)::int, 0));
    IF v_dispo < p_qte THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'stock_section_insuffisant', 'disponible', v_dispo);
    END IF;
    v_stock := v_stock || jsonb_build_object(p_produit, v_dispo - p_qte);
    v_mvt := public.caserne_stock_mouvement(v_pays, p_produit, p_qte, 'retour-' || p_section_id);
    IF COALESCE((v_mvt->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_mvt; END IF;
  END IF;

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(g.o_data, p_section_id,
                  v_sec || jsonb_build_object('stockArmes', v_stock))
   WHERE id = p_compagnie_id;

  -- PAIEMENT ATTESTE (miroir ordres_couts). En cas de refus, l'exception annule aussi le
  -- mouvement de stock : jamais d'armes transferees sans PA preleves.
  v_paye := public.payer_ordre(g.o_moi, 'repartir_armement', c_pa, 0);
  IF NOT COALESCE((v_paye->>'ok')::boolean, false) THEN
    RAISE EXCEPTION 'militaire_armurerie_transfert: paiement refuse (%)',
      COALESCE(v_paye->>'raison', 'motif inconnu');
  END IF;

  RETURN jsonb_build_object('ok', true, 'sens', p_sens, 'produit', p_produit, 'quantite', p_qte,
    'stock_armurerie', v_mvt->'stock', 'stock_section', v_stock->p_produit,
    'pa', v_paye->'pa', 'pa_preleves', c_pa);
END; $function$;

-- militaire_assigner_mission(text,text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_assigner_mission(p_compagnie_id text, p_section_id text, p_mission text, p_cible text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE g record; v_sec jsonb;
BEGIN
  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;
  IF p_mission NOT IN ('bloquer_acces','securiser','assassiner','arreter','surveiller') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'mission_invalide');
  END IF;
  SELECT s INTO v_sec FROM jsonb_array_elements(g.o_data->'sections') s WHERE s->>'id' = p_section_id;
  -- cibleEscorte est retire de la section a chaque assignation : plus aucune mission ne l'utilise,
  -- et laisser trainer un champ mort ferait croire un jour qu'il veut encore dire quelque chose.
  v_sec := (v_sec - 'cibleEscorte') || jsonb_build_object('mission', p_mission);
  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(g.o_data, p_section_id, v_sec)
   WHERE id = p_compagnie_id;
  RETURN jsonb_build_object('ok', true, 'mission', p_mission);
END;
$function$;

-- militaire_autorite_de_perimetre(text,text) -> text | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.militaire_autorite_de_perimetre(p_pays text, p_perimetre text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_nom text;
BEGIN
  IF p_perimetre LIKE '%:reserve' THEN RETURN NULL; END IF;
  SELECT s->>'lieutenantNom' INTO v_nom
    FROM public.compagnies_militaires c,
         jsonb_array_elements(COALESCE(c.data->'sections','[]'::jsonb)) s
   WHERE c.data->>'pays' = p_pays AND s->>'id' = p_perimetre
   LIMIT 1;
  RETURN NULLIF(btrim(COALESCE(v_nom, '')), '');
END; $function$;

-- militaire_bande_distance(text,text,text,text,text,text) -> text | sql | SECURITY INVOKER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_bande_distance(p_pays_a text, p_ville_a text, p_bat_a text, p_pays_b text, p_ville_b text, p_bat_b text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  SELECT CASE
    WHEN p_ville_a IS NOT DISTINCT FROM p_ville_b
     AND p_bat_a   IS NOT DISTINCT FROM p_bat_b   THEN 'proche'
    WHEN p_ville_a IS NOT DISTINCT FROM p_ville_b THEN 'moyenne'
    WHEN p_pays_a  IS NOT DISTINCT FROM p_pays_b  THEN 'longue'
    ELSE 'hors' END;
$function$;

-- militaire_bataille_actions(bigint,text,integer,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_bataille_actions(p_bataille_id bigint, p_camp_att text, p_round integer, p_surprise boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_res jsonb := '[]'::jsonb;
  a record; k integer; n integer; v_hostiles text[];
  d_eng bigint[]; d_pj boolean[]; d_nom text[]; d_cie text[]; d_sec text[]; d_mat text[];
  d_camp text[]; d_per numeric[]; d_dup numeric[]; d_tir numeric[]; d_cac numeric[];
  d_feu boolean[]; u_tir integer[]; u_cac integer[]; v_urne integer[];
  v_mode text; v_taux integer; v_jet integer; v_degre text;
BEGIN
  v_hostiles := public.militaire_camps_hostiles(p_bataille_id, p_camp_att);
  IF coalesce(array_length(v_hostiles, 1), 0) = 0 THEN RETURN v_res; END IF;

  SELECT array_agg(c.eng_id ORDER BY c.eng_id), array_agg(c.est_pj ORDER BY c.eng_id),
         array_agg(c.nom ORDER BY c.eng_id), array_agg(c.compagnie_id ORDER BY c.eng_id),
         array_agg(c.section_id ORDER BY c.eng_id), array_agg(c.matricule ORDER BY c.eng_id),
         array_agg(c.camp ORDER BY c.eng_id), array_agg(c.def_per ORDER BY c.eng_id),
         array_agg(c.def_dup ORDER BY c.eng_id), array_agg(c.comp_tir ORDER BY c.eng_id),
         array_agg(c.comp_cac ORDER BY c.eng_id), array_agg(c.arme_feu ORDER BY c.eng_id)
    INTO d_eng, d_pj, d_nom, d_cie, d_sec, d_mat, d_camp, d_per, d_dup, d_tir, d_cac, d_feu
    FROM (SELECT x.*, h.camp
            FROM unnest(v_hostiles) AS h(camp)
            CROSS JOIN LATERAL public.militaire_bataille_combattants(p_bataille_id, h.camp) x) c;
  n := coalesce(array_length(d_eng, 1), 0);
  IF n = 0 THEN RETURN v_res; END IF;

  -- Urne de base : un jeton par ennemi.
  SELECT coalesce(array_agg(i ORDER BY i), '{}') INTO u_cac FROM generate_series(1, n) AS g(i);
  -- Urne des tireurs : un second jeton pour chaque ennemi au corps-a-corps.
  SELECT u_cac || coalesce(array_agg(i ORDER BY i), '{}') INTO u_tir
    FROM generate_series(1, n) AS g(i) WHERE NOT coalesce(d_feu[g.i], false);

  FOR a IN
    SELECT * FROM public.militaire_bataille_combattants(p_bataille_id, p_camp_att)
     WHERE saute_round IS DISTINCT FROM p_round
  LOOP
    v_mode := CASE WHEN a.arme_feu THEN 'feu' ELSE 'cac' END;
    v_urne := CASE WHEN a.arme_feu THEN u_tir ELSE u_cac END;
    k := v_urne[1 + floor(random() * array_length(v_urne, 1))::integer];

    -- La competence qui DEFEND est celle du meme domaine que l'attaque subie.
    v_taux := public.militaire_taux_combat(
      CASE WHEN a.arme_feu THEN a.comp_tir ELSE a.comp_cac END,
      CASE WHEN a.arme_feu THEN d_tir[k]   ELSE d_cac[k]   END,
      CASE WHEN a.arme_feu THEN d_per[k]   ELSE d_dup[k]   END,
      a.bonus_arme);
    v_jet   := floor(random() * 100)::integer + 1;
    v_degre := public.militaire_degre_combat(v_taux, v_jet);

    IF coalesce(p_surprise, false) AND v_jet <> 1 THEN
      v_degre := public.militaire_degre_par_rang(public.militaire_degre_rang(v_degre) + 1);
    END IF;

    v_res := v_res || jsonb_build_array(jsonb_build_object(
      'camp_attaquant', p_camp_att,
      'att_eng', a.eng_id, 'att_pj', a.est_pj, 'att_nom', a.nom, 'att_mat', a.matricule,
      'att_arme', a.arme_cle, 'att_bonus', a.bonus_arme, 'att_groupe', a.groupe_id,
      'cib_eng', d_eng[k], 'cib_pj', d_pj[k], 'cib_nom', d_nom[k], 'cib_mat', d_mat[k],
      'cib_cie', d_cie[k], 'cib_sec', d_sec[k], 'cib_camp', d_camp[k],
      'mode', v_mode, 'taux', v_taux, 'jet', v_jet, 'degre', v_degre,
      'surprise', coalesce(p_surprise, false)));
  END LOOP;
  RETURN v_res;
END;
$function$;

-- militaire_bataille_appliquer(bigint,jsonb,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_bataille_appliquer(p_bataille_id bigint, p_actions jsonb, p_round integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  act jsonb; v_pa integer; v_new integer; v_gilet jsonb; v_degre text; v_abaisse text;
  v_out jsonb := '[]'::jsonb; v_protege boolean;
  v_camp_mutin text; v_b record; v_ville_prison text; v_det jsonb;
BEGIN
  SELECT pays, ville INTO v_b FROM public.batailles WHERE id = p_bataille_id;

  FOR act IN SELECT value FROM jsonb_array_elements(coalesce(p_actions, '[]'::jsonb))
  LOOP
    v_degre := act->>'degre'; v_protege := false;

    IF v_degre = 'echec_critique' THEN
      UPDATE public.batailles_engagements SET saute_round = p_round + 1
       WHERE id = (act->>'att_eng')::bigint AND sorti_round IS NULL;
      v_out := v_out || jsonb_build_array(act || jsonb_build_object('perte', 0, 'saute_suivant', true));
      CONTINUE;
    END IF;

    IF public.militaire_degats_pct(v_degre) = 0
       OR NOT EXISTS (SELECT 1 FROM public.batailles_engagements
                       WHERE id = (act->>'cib_eng')::bigint AND sorti_round IS NULL) THEN
      v_out := v_out || jsonb_build_array(act || jsonb_build_object('perte', 0));
      CONTINUE;
    END IF;

    SELECT pa INTO v_pa FROM public.militaire_bataille_combattants(
      p_bataille_id, act->>'cib_camp') WHERE eng_id = (act->>'cib_eng')::bigint;
    IF v_pa IS NULL THEN
      v_out := v_out || jsonb_build_array(act || jsonb_build_object('perte', 0));
      CONTINUE;
    END IF;

    v_new := public.militaire_pa_restants(v_pa, v_degre);

    IF v_new = 0 AND act->>'mode' = 'feu' THEN
      v_gilet := public.militaire_gilet_absorber(
        (act->>'cib_pj')::boolean, act->>'cib_nom',
        act->>'cib_cie', act->>'cib_sec', act->>'cib_mat');
      IF coalesce((v_gilet->>'protege')::boolean, false) THEN
        v_protege := true;
        v_abaisse := public.militaire_degre_par_rang(public.militaire_degre_rang(v_degre) - 1);
        v_new := greatest(1, public.militaire_pa_restants(v_pa, v_abaisse));
      END IF;
    END IF;

    IF (act->>'cib_pj')::boolean THEN
      UPDATE public.personnages_donnees SET pa = v_new WHERE name = act->>'cib_nom';
    ELSE
      PERFORM public.militaire_soldat_pa_fixer(act->>'cib_cie', act->>'cib_sec', act->>'cib_mat', v_new);
    END IF;

    v_out := v_out || jsonb_build_array(act || jsonb_build_object(
      'pa_avant', v_pa, 'pa_apres', v_new, 'perte', v_pa - v_new,
      'gilet', v_protege, 'degre_applique', coalesce(v_abaisse, v_degre)));

    CONTINUE WHEN v_new > 0;

    IF (act->>'cib_pj')::boolean THEN
      v_camp_mutin := public.mutinerie_camp_de(act->>'cib_nom');
      IF v_camp_mutin IS NOT NULL THEN
        -- MUTIN NEUTRALISE : capture. La prison est ouverte par le chemin canonique du jeu, avec
        -- la peine de 7 jours ; le cycle carceral existant prend le relais.
        -- La caserne n'est pas une ville dotee d'une prison : on rabat sur la capitale.
        v_ville_prison := CASE WHEN coalesce(v_b.ville,'') IN ('', 'caserne') THEN 'capitale' ELSE v_b.ville END;
        v_det := public.detention_ouvrir_interne(act->>'cib_nom', 'Mutinerie', 7,
                   v_ville_prison, coalesce(v_b.pays, 'republic'),
                   jsonb_build_object('source', 'mutinerie', 'bataille', p_bataille_id),
                   'Armee reguliere', 'capture');
        UPDATE public.mutineries_membres SET statut = 'capture'
         WHERE personnage = act->>'cib_nom' AND camp = v_camp_mutin;
        UPDATE public.batailles_engagements
           SET sorti_round = p_round, etat_final = 'capture'
         WHERE id = (act->>'cib_eng')::bigint;
      ELSE
        UPDATE public.personnages_donnees
           SET current_city = 'caserne', current_building = 'caserne-militaire',
               current_room = 'infirmerie'
         WHERE name = act->>'cib_nom';
        UPDATE public.batailles_engagements
           SET sorti_round = p_round, etat_final = 'neutralise'
         WHERE id = (act->>'cib_eng')::bigint;
      END IF;
    ELSE
      PERFORM public.militaire_soldat_supprimer(act->>'cib_cie', act->>'cib_sec', act->>'cib_mat');
      UPDATE public.batailles_engagements
         SET sorti_round = p_round, etat_final = 'mort'
       WHERE id = (act->>'cib_eng')::bigint;
    END IF;
  END LOOP;
  RETURN v_out;
END;
$function$;

-- militaire_bataille_arbitrer_groupes(bigint,integer) -> integer | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_bataille_arbitrer_groupes(p_bataille_id bigint, p_round integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE g record; v_attente integer := 0;
BEGIN
  FOR g IN SELECT * FROM public.batailles_groupes
            WHERE bataille_id = p_bataille_id AND sorti_round IS NULL
  LOOP
    -- Un groupe qui a deja tranche « replier » decroche.
    IF g.decision = 'replier' THEN
      PERFORM public.militaire_bataille_decrocher_groupe(p_bataille_id, g.groupe_id, p_round);
      CONTINUE;
    END IF;
    -- Un groupe qui a deja tranche « tenir » continue : rien a faire.
    IF g.decision = 'tenir' THEN CONTINUE; END IF;

    IF NOT public.militaire_groupe_sous_seuil(p_bataille_id, g.groupe_id) THEN
      CONTINUE;                                  -- pas encore a 50 % de pertes
    END IF;

    IF g.leader IS NULL THEN
      -- Groupe mene par un PNJ : repli automatique, sans attente.
      PERFORM public.militaire_bataille_decrocher_groupe(p_bataille_id, g.groupe_id, p_round);
      CONTINUE;
    END IF;

    IF g.attente_depuis IS NULL THEN
      -- Ouverture de la fenetre de 90 secondes pour le chef PJ.
      UPDATE public.batailles_groupes SET attente_depuis = now()
       WHERE bataille_id = p_bataille_id AND groupe_id = g.groupe_id;
      v_attente := v_attente + 1;
    ELSIF now() - g.attente_depuis >= interval '90 seconds' THEN
      -- Delai ecoule sans reponse : repli automatique du groupe.
      PERFORM public.militaire_bataille_decrocher_groupe(p_bataille_id, g.groupe_id, p_round);
    ELSE
      v_attente := v_attente + 1;                -- la fenetre court encore
    END IF;
  END LOOP;
  RETURN v_attente;
END;
$function$;

-- militaire_bataille_avancer(bigint) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_bataille_avancer(p_bataille_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE b record; v_attente integer; v_debout integer;
BEGIN
  SELECT * INTO b FROM public.batailles WHERE id = p_bataille_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'bataille_introuvable'); END IF;
  IF b.statut <> 'en_cours' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'bataille_terminee', 'issue', b.issue);
  END IF;

  -- Les fenetres echues se resolvent ici : un chef qui n'a pas repondu dans
  -- les 90 secondes voit son groupe decrocher.
  v_attente := public.militaire_bataille_arbitrer_groupes(p_bataille_id, b.round_courant);

  SELECT count(DISTINCT camp) INTO v_debout FROM public.batailles_engagements
   WHERE bataille_id = p_bataille_id AND sorti_round IS NULL;
  IF v_debout <= 1 THEN
    UPDATE public.batailles SET statut = 'terminee', fin_ts = now(),
           termine_raison = 'camp_hors_combat',
           issue = CASE WHEN v_debout = 0 THEN 'aneantissement_mutuel'
                        ELSE 'victoire_' || (SELECT DISTINCT camp FROM public.batailles_engagements
                                              WHERE bataille_id = p_bataille_id AND sorti_round IS NULL) END
     WHERE id = p_bataille_id;
    RETURN jsonb_build_object('ok', true, 'terminee', true, 'camps_debout', v_debout);
  END IF;

  IF v_attente > 0 THEN
    -- AUCUN ROUND NE PART tant qu'un chef a la main : la fenetre de decision
    -- ne se paie pas en morts.
    RETURN jsonb_build_object('ok', true, 'en_attente', v_attente,
      'raison', 'decision_en_attente', 'round', b.round_courant);
  END IF;

  RETURN public.militaire_bataille_round(p_bataille_id);
END;
$function$;

-- militaire_bataille_combattants(bigint,text) -> TABLE(eng_id bigint, est_pj boolean, nom text, compagnie_id text, section_id text, matricule text, pa integer, comp_tir numeric, comp_cac numeric, arme_feu boolean, arme_cle text, bonus_arme integer, def_per numeric, def_dup numeric, saute_round integer, groupe_id text) | sql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_bataille_combattants(p_bataille_id bigint, p_camp text)
 RETURNS TABLE(eng_id bigint, est_pj boolean, nom text, compagnie_id text, section_id text, matricule text, pa integer, comp_tir numeric, comp_cac numeric, arme_feu boolean, arme_cle text, bonus_arme integer, def_per numeric, def_dup numeric, saute_round integer, groupe_id text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT e.id, true, e.personnage, e.compagnie_id, e.section_id, NULL::text,
         greatest(0, coalesce(pd.pa, 0)),
         coalesce((pd.competences_militaires->>'tir')::numeric, 0),
         coalesce((pd.competences_militaires->>'combat_rapproche')::numeric, 0),
         (af.cle IS NOT NULL),
         coalesce(af.cle, ac.cle),
         coalesce(af.bonus, ac.bonus, 0),
         public.assemblee_stat_base(pd.stats, 'PER'),
         public.assemblee_stat_base(pd.stats, 'DUP'),
         e.saute_round, e.groupe_id
    FROM public.batailles_engagements e
    JOIN public.personnages_donnees pd ON pd.name = e.personnage
    LEFT JOIN LATERAL (
      SELECT b.cle, b.bonus FROM jsonb_array_elements(
               CASE WHEN jsonb_typeof(pd.inventory)='array' THEN pd.inventory ELSE '[]'::jsonb END) i
        JOIN public.militaire_armes_bonus b
          ON b.cle = coalesce(i->>'produitMilitaire', i->>'name')
       WHERE i->>'type' = 'arme' AND b.mode = 'feu'
       ORDER BY b.bonus DESC LIMIT 1) af ON true
    LEFT JOIN LATERAL (
      SELECT b.cle, b.bonus FROM jsonb_array_elements(
               CASE WHEN jsonb_typeof(pd.inventory)='array' THEN pd.inventory ELSE '[]'::jsonb END) i
        JOIN public.militaire_armes_bonus b
          ON b.cle = coalesce(i->>'produitMilitaire', i->>'name')
       WHERE i->>'type' = 'arme' AND b.mode = 'cac'
       ORDER BY b.bonus DESC LIMIT 1) ac ON true
   WHERE e.bataille_id = p_bataille_id AND e.camp = p_camp
     AND e.personnage IS NOT NULL AND e.sorti_round IS NULL

  UNION ALL

  SELECT e.id, false,
         NULL::text,
         e.compagnie_id, e.section_id, e.matricule,
         greatest(0, coalesce(m.pa, 0)),
         coalesce((sm.formation->>'tir')::numeric, 0),
         coalesce((sm.formation->>'combat_rapproche')::numeric, 0),
         EXISTS (SELECT 1 FROM public.militaire_armes_bonus b
                  WHERE b.cle = coalesce(sm.arme,'corps_a_corps') AND b.mode = 'feu'),
         coalesce(sm.arme,'corps_a_corps'),
         public.militaire_bonus_arme(coalesce(sm.arme,'corps_a_corps'),
           CASE WHEN EXISTS (SELECT 1 FROM public.militaire_armes_bonus b
                              WHERE b.cle = coalesce(sm.arme,'corps_a_corps') AND b.mode = 'feu')
                THEN 'feu' ELSE 'cac' END),
         public.militaire_defense_pnj('PER'),
         public.militaire_defense_pnj('DUP'),
         e.saute_round, e.groupe_id
    FROM public.batailles_engagements e
    JOIN public.pnj_soldats_metier sm ON sm.matricule = e.matricule
    JOIN public.pnj_membres m ON m.id = sm.pnj_id
   WHERE e.bataille_id = p_bataille_id AND e.camp = p_camp
     AND e.matricule IS NOT NULL AND e.sorti_round IS NULL
     AND m.id LIKE e.compagnie_id || '-%'
     AND sm.section_id = e.section_id;
$function$;

-- militaire_bataille_decider(bigint,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_bataille_decider(p_bataille_id bigint, p_decision text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_moi text; b record; g record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_decision NOT IN ('tenir','replier') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'decision_invalide');
  END IF;

  SELECT * INTO b FROM public.batailles WHERE id = p_bataille_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'bataille_introuvable'); END IF;
  IF b.statut <> 'en_cours' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'bataille_terminee', 'issue', b.issue);
  END IF;

  SELECT * INTO g FROM public.batailles_groupes
   WHERE bataille_id = p_bataille_id AND leader = v_moi AND sorti_round IS NULL FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_chef_de_groupe');
  END IF;

  UPDATE public.batailles_groupes
     SET decision = p_decision, attente_depuis = NULL
   WHERE bataille_id = p_bataille_id AND groupe_id = g.groupe_id;

  IF p_decision = 'replier' THEN
    PERFORM public.militaire_bataille_decrocher_groupe(p_bataille_id, g.groupe_id, b.round_courant);
  END IF;

  RETURN public.militaire_bataille_avancer(p_bataille_id)
         || jsonb_build_object('mon_groupe', g.groupe_id, 'ma_decision', p_decision);
END;
$function$;

-- militaire_bataille_decision_effective(bigint,text) -> text | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_bataille_decision_effective(p_bataille_id bigint, p_camp text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE b record; v_dec text; v_doc text; v_init integer; v_reste integer; v_repli jsonb;
BEGIN
  SELECT * INTO b FROM public.batailles WHERE id = p_bataille_id;
  IF p_camp = b.camp_a THEN v_dec := b.decision_a; v_doc := b.doctrine_a;
                            v_init := b.effectif_initial_a; v_repli := b.repli_a;
                       ELSE v_dec := b.decision_b; v_doc := b.doctrine_b;
                            v_init := b.effectif_initial_b; v_repli := b.repli_b; END IF;
  IF v_dec IS NULL THEN
    IF v_doc = 'repli_50' THEN
      SELECT count(*) INTO v_reste FROM public.militaire_bataille_combattants(p_bataille_id, p_camp);
      -- SEUIL CALCULE SUR L'EFFECTIF INITIAL DE CETTE BATAILLE, jamais recalcule round par round.
      v_dec := CASE WHEN v_reste * 2 <= coalesce(v_init, 0) THEN 'replier' ELSE 'continuer' END;
    ELSE
      v_dec := 'continuer';
    END IF;
  END IF;
  -- Un camp sans position de repli connue ne peut pas se replier : il tient, et le rapport le dit.
  IF v_dec = 'replier' AND v_repli IS NULL THEN v_dec := 'continuer'; END IF;
  RETURN v_dec;
END;
$function$;

-- militaire_bataille_decrocher_groupe(bigint,text,integer) -> integer | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.militaire_bataille_decrocher_groupe(p_bataille_id bigint, p_groupe_id text, p_round integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r record; v_repli jsonb; v_n integer := 0; v_cies text[] := '{}'; v_cie text;
BEGIN
  SELECT g.repli INTO v_repli FROM public.batailles_groupes g
   WHERE g.bataille_id = p_bataille_id AND g.groupe_id = p_groupe_id;
  IF v_repli IS NULL THEN RETURN 0; END IF;   -- sans position de repli, on tient

  FOR r IN SELECT e.* FROM public.batailles_engagements e
            WHERE e.bataille_id = p_bataille_id AND e.groupe_id = p_groupe_id
              AND e.sorti_round IS NULL
  LOOP
    IF r.personnage IS NOT NULL THEN
      UPDATE public.personnages_donnees
         SET current_city = v_repli->>'ville', current_building = v_repli->>'batiment',
             current_room = v_repli->>'piece'
       WHERE name = r.personnage;
    ELSE
      -- Un soldat qui suit un chef ne decroche pas seul : il reste avec lui. Regle inchangee.
      UPDATE public.pnj_membres
         SET ville = v_repli->>'ville', building_id = v_repli->>'batiment',
             room_id = v_repli->>'piece', maj_le = now()
       WHERE id = r.compagnie_id || '-' || r.matricule
         AND leader_pj IS NULL AND leader_pnj_id IS NULL;
      IF NOT (r.compagnie_id = ANY(v_cies)) THEN v_cies := v_cies || r.compagnie_id; END IF;
    END IF;
    UPDATE public.batailles_engagements
       SET sorti_round = p_round, etat_final = 'replie' WHERE id = r.id;
    v_n := v_n + 1;
  END LOOP;

  FOREACH v_cie IN ARRAY v_cies LOOP
    PERFORM public.militaire_blob_projeter(v_cie);
  END LOOP;

  UPDATE public.batailles_groupes
     SET sorti_round = p_round, attente_depuis = NULL
   WHERE bataille_id = p_bataille_id AND groupe_id = p_groupe_id;
  RETURN v_n;
END; $function$;

-- militaire_bataille_doctrine(bigint,text) -> jsonb | sql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_bataille_doctrine(p_bataille_id bigint, p_doctrine text)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT jsonb_build_object('ok', false, 'raison', 'doctrine_obsolete',
    'detail', 'Le repli se decide desormais groupe par groupe, a 50 % de pertes.');
$function$;

-- militaire_bataille_engager() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_bataille_engager()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_moi text; a record; v_id bigint; v_contact bigint; v_init text;
  v_camps text[]; v_camp text; v_na integer; v_total integer; v_mon_camp text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT country, current_city, current_building, current_room, pa INTO a
    FROM public.personnages_donnees WHERE name = v_moi;
  IF a.country IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.services_militaires
                  WHERE personnage = v_moi AND fin_ts IS NULL) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_militaire');
  END IF;
  IF EXISTS (SELECT 1 FROM public.batailles WHERE statut = 'en_cours'
              AND pays = a.country AND ville = a.current_city
              AND batiment = a.current_building AND piece = a.current_room) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'bataille_deja_en_cours');
  END IF;

  -- MON CAMP : mon camp mutin s'il existe, mon pays sinon. Jamais fourni par le client.
  v_mon_camp := coalesce(public.mutinerie_camp_de(v_moi), a.country);

  -- (a) ENNEMIS ETRANGERS : predicat d'origine, inchange. Reserve aux forces loyalistes ;
  --     une force mutine ne combat pas encore l'etranger (lot suivant).
  IF v_mon_camp = a.country THEN
    SELECT coalesce(array_agg(DISTINCT m.pays), '{}') INTO v_camps
      FROM public.pnj_membres m
      JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
     WHERE m.famille = 'soldat' AND m.statut = 'actif'
       AND sm.en_reserve = false
       AND m.pays IS DISTINCT FROM a.country
       AND m.ville = a.current_city AND m.building_id = a.current_building
       AND m.room_id = a.current_room
       AND m.leader_pj IS NULL AND m.leader_pnj_id IS NULL
       AND EXISTS (SELECT 1 FROM public.guerres g WHERE g.statut = 'active'
                    AND ((g.data->>'attaquant' = a.country AND g.data->>'attaque' = c.data->>'pays')
                      OR (g.data->>'attaque'  = a.country AND g.data->>'attaquant' = c.data->>'pays')));
  ELSE
    v_camps := '{}';
  END IF;

  -- (b) ADVERSAIRES DU MEME PAYS : uniquement si une mutinerie separe reellement les deux camps.
  SELECT v_camps || coalesce(array_agg(c), '{}') INTO v_camps
    FROM unnest(public.mutinerie_camps_presents(a.country, a.current_city,
                                                a.current_building, a.current_room)) c
   WHERE c IS DISTINCT FROM v_mon_camp
     AND (public.mutinerie_est_camp(c) OR public.mutinerie_est_camp(v_mon_camp));

  IF coalesce(array_length(v_camps, 1), 0) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_ennemi_ici');
  END IF;

  SELECT id INTO v_contact FROM public.contacts_militaires
   WHERE consomme_le IS NULL AND ville = a.current_city AND batiment = a.current_building
     AND ((pays_a = a.country AND pays_b = ANY(v_camps)) OR (pays_a = ANY(v_camps) AND pays_b = a.country))
   ORDER BY etabli_le DESC LIMIT 1;
  v_init := CASE WHEN v_contact IS NOT NULL THEN 'simultane' ELSE 'a' END;

  INSERT INTO public.batailles (pays, ville, batiment, piece, camp_a, camp_b, initiative,
                                leader_a, contact_id, statut, round_courant)
  VALUES (a.country, a.current_city, a.current_building, a.current_room, v_mon_camp, v_camps[1],
          v_init, v_moi, v_contact, 'en_cours', 0)
  RETURNING id INTO v_id;

  PERFORM public.militaire_bataille_recruter(v_id, v_mon_camp, a.current_city, a.current_building, a.current_room);
  FOREACH v_camp IN ARRAY v_camps LOOP
    PERFORM public.militaire_bataille_recruter(v_id, v_camp, a.current_city, a.current_building, a.current_room);
  END LOOP;

  SELECT count(*) INTO v_na    FROM public.militaire_bataille_combattants(v_id, v_mon_camp);
  SELECT count(*) INTO v_total FROM public.batailles_engagements
   WHERE bataille_id = v_id AND camp <> v_mon_camp AND sorti_round IS NULL;
  IF v_na = 0 OR v_total = 0 THEN
    DELETE FROM public.batailles_engagements WHERE bataille_id = v_id;
    DELETE FROM public.batailles WHERE id = v_id;
    RETURN jsonb_build_object('ok', false, 'raison', 'effectif_insuffisant',
      'mon_camp', v_na, 'adverse', v_total);
  END IF;

  PERFORM public.militaire_bataille_groupes_constituer(v_id);
  UPDATE public.batailles SET effectif_initial_a = v_na, effectif_initial_b = v_total,
         repli_a = public.militaire_position_repli(v_moi, a.current_city, a.current_building, a.current_room)
   WHERE id = v_id;

  IF v_contact IS NOT NULL THEN
    UPDATE public.contacts_militaires SET consomme_le = now(), bataille_id = v_id WHERE id = v_contact;
  END IF;

  RETURN jsonb_build_object('ok', true, 'bataille_id', v_id, 'initiative', v_init,
    'mon_camp', v_mon_camp, 'camps_adverses', v_camps, 'mon_effectif', v_na,
    'effectif_adverse', v_total,
    'groupes', (SELECT count(*) FROM public.batailles_groupes WHERE bataille_id = v_id));
END;
$function$;

-- militaire_bataille_etat(bigint) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_bataille_etat(p_bataille_id bigint DEFAULT NULL::bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_moi text; v_id bigint; b record; g record; v_camp text; v_reste integer;
  v_rounds jsonb; v_hostiles text[]; v_secondes integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  IF p_bataille_id IS NULL THEN
    SELECT e.bataille_id INTO v_id FROM public.batailles_engagements e
      JOIN public.batailles bb ON bb.id = e.bataille_id
     WHERE e.personnage = v_moi AND bb.statut = 'en_cours'
     ORDER BY bb.debut_ts DESC LIMIT 1;
    IF v_id IS NULL THEN RETURN jsonb_build_object('ok', true, 'bataille', NULL); END IF;
  ELSE
    v_id := p_bataille_id;
  END IF;

  SELECT * INTO b FROM public.batailles WHERE id = v_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'bataille_introuvable'); END IF;

  v_camp := public.militaire_bataille_mon_camp(v_id, v_moi);
  IF v_camp IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'non_engage'); END IF;

  -- Mon groupe : celui ou je suis engage.
  SELECT gg.* INTO g FROM public.batailles_groupes gg
    JOIN public.batailles_engagements e
      ON e.bataille_id = gg.bataille_id AND e.groupe_id = gg.groupe_id
   WHERE gg.bataille_id = v_id AND e.personnage = v_moi LIMIT 1;

  v_hostiles := public.militaire_camps_hostiles(v_id, v_camp);
  SELECT count(*) INTO v_reste FROM public.militaire_bataille_combattants(v_id, v_camp);
  SELECT coalesce(jsonb_agg(r.rapport ORDER BY r.numero), '[]'::jsonb) INTO v_rounds
    FROM public.batailles_rounds r WHERE r.bataille_id = v_id AND r.camp = v_camp;

  v_secondes := CASE WHEN g.attente_depuis IS NULL THEN NULL
    ELSE greatest(0, 90 - extract(epoch FROM now() - g.attente_depuis))::integer END;

  RETURN jsonb_build_object('ok', true, 'bataille', jsonb_build_object(
    'id', b.id, 'statut', b.statut, 'round_courant', b.round_courant,
    'lieu', jsonb_build_object('ville', b.ville, 'batiment', b.batiment, 'piece', b.piece),
    'mon_camp', v_camp, 'camps_adverses', v_hostiles,
    'camp_adverse', coalesce(v_hostiles[1], '—'),
    'mon_effectif_actuel', v_reste,
    -- Mon groupe, unite de decision
    'mon_groupe', g.groupe_id,
    'mon_groupe_effectif_initial', g.effectif_initial,
    'mon_groupe_restants', (SELECT count(*) FROM public.batailles_engagements e2
                             WHERE e2.bataille_id = v_id AND e2.groupe_id = g.groupe_id
                               AND e2.sorti_round IS NULL),
    'mon_effectif_initial', g.effectif_initial,
    'je_suis_leader', (g.leader IS NOT NULL AND g.leader = v_moi),
    'mon_chef', g.leader,
    'decision_attendue', (g.attente_depuis IS NOT NULL AND g.decision IS NULL),
    'secondes_restantes', v_secondes,
    'ma_decision', g.decision,
    'mon_groupe_replie', (g.sorti_round IS NOT NULL),
    'issue', b.issue, 'rounds', v_rounds));
END;
$function$;

-- militaire_bataille_groupes_constituer(bigint) -> integer | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_bataille_groupes_constituer(p_bataille_id bigint)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_n integer;
BEGIN
  INSERT INTO public.batailles_groupes
    (bataille_id, groupe_id, camp, compagnie_id, section_id, leader, effectif_initial, repli)
  SELECT e.bataille_id, e.groupe_id, min(e.camp), min(e.compagnie_id), min(e.section_id),
         (SELECT p.personnage FROM public.batailles_engagements p
           WHERE p.bataille_id = e.bataille_id AND p.groupe_id = e.groupe_id
             AND p.personnage IS NOT NULL
           ORDER BY CASE p.grade WHEN 'commandant' THEN 1 WHEN 'capitaine' THEN 2
                                 WHEN 'lieutenant' THEN 3 ELSE 4 END, p.id LIMIT 1),
         count(*),
         coalesce(
           (SELECT public.militaire_position_repli(p.personnage, b.ville, b.batiment, b.piece)
              FROM public.batailles_engagements p
              JOIN public.batailles b ON b.id = p.bataille_id
             WHERE p.bataille_id = e.bataille_id AND p.groupe_id = e.groupe_id
               AND p.personnage IS NOT NULL LIMIT 1),
           jsonb_build_object('ville', 'caserne', 'batiment', 'caserne-militaire',
                              'piece', 'corps_garde'))
    FROM public.batailles_engagements e
   WHERE e.bataille_id = p_bataille_id
   GROUP BY e.bataille_id, e.groupe_id
  ON CONFLICT (bataille_id, groupe_id) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END;
$function$;

-- militaire_bataille_mon_camp(bigint,text) -> text | sql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_bataille_mon_camp(p_bataille_id bigint, p_nom text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT e.camp FROM public.batailles_engagements e
   WHERE e.bataille_id = p_bataille_id AND e.personnage = p_nom LIMIT 1;
$function$;

-- militaire_bataille_poursuivre(bigint) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_bataille_poursuivre(p_bataille_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_moi text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF public.militaire_bataille_mon_camp(p_bataille_id, v_moi) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'non_engage');
  END IF;
  RETURN public.militaire_bataille_avancer(p_bataille_id);
END;
$function$;

-- militaire_bataille_rapport(bigint,text,text,integer,jsonb,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_bataille_rapport(p_bataille_id bigint, p_camp text, p_camp_adverse text, p_round integer, p_actions jsonb, p_reste_moi integer, p_reste_adverse integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  b record; v_pa_perdus integer; v_touches integer; v_morts integer; v_neutralises integer;
  v_tombes_adverse integer;
BEGIN
  SELECT * INTO b FROM public.batailles WHERE id = p_bataille_id;

  SELECT coalesce(sum(coalesce((a->>'perte')::integer, 0)), 0),
         count(*) FILTER (WHERE coalesce((a->>'perte')::integer, 0) > 0)
    INTO v_pa_perdus, v_touches
    FROM jsonb_array_elements(coalesce(p_actions, '[]'::jsonb)) a
   WHERE a->>'cib_camp' = p_camp;

  SELECT count(*) FILTER (WHERE etat_final = 'mort'),
         count(*) FILTER (WHERE etat_final = 'neutralise')
    INTO v_morts, v_neutralises
    FROM public.batailles_engagements
   WHERE bataille_id = p_bataille_id AND camp = p_camp AND sorti_round = p_round;

  SELECT count(*) INTO v_tombes_adverse FROM public.batailles_engagements
   WHERE bataille_id = p_bataille_id AND camp <> p_camp AND sorti_round = p_round;

  RETURN jsonb_build_object(
    'round', p_round,
    'lieu', jsonb_build_object('ville', b.ville, 'batiment', b.batiment, 'piece', b.piece),
    'mon_camp', p_camp,
    'mes_combattants_restants', p_reste_moi,
    'mes_pa_perdus', v_pa_perdus,
    'mes_combattants_touches', v_touches,
    'mes_morts_pnj', v_morts,
    'mes_pj_neutralises', v_neutralises,
    'adversaires_tombes', v_tombes_adverse,
    'adversaire_estime', CASE WHEN p_reste_adverse > 0
      THEN public.militaire_degrader('proche', p_reste_adverse, p_camp_adverse, b.ville, b.batiment)
      ELSE jsonb_build_object('libelle', 'plus aucun adversaire debout') END,
    'termine', (p_reste_moi = 0 OR p_reste_adverse = 0));
END;
$function$;

-- militaire_bataille_recruter(bigint,text,text,text,text) -> void | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_bataille_recruter(p_bataille_id bigint, p_camp text, p_ville text, p_bat text, p_piece text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_mutin boolean; v_pays text;
BEGIN
  v_mutin := public.mutinerie_est_camp(p_camp);
  v_pays  := public.mutinerie_pays_du_camp(p_camp);

  -- Branche PJ : inchangee.
  INSERT INTO public.batailles_engagements
    (bataille_id, camp, personnage, compagnie_id, section_id, grade, pa_initial, groupe_id)
  SELECT p_bataille_id, p_camp, pd.name, sm.compagnie_id, sm.section_id, sm.grade, pd.pa,
         p_camp || '|' || coalesce(sm.compagnie_id, 'solo') || ':' || coalesce(sm.section_id, pd.name)
    FROM public.personnages_donnees pd
    JOIN public.services_militaires sm ON sm.personnage = pd.name AND sm.fin_ts IS NULL
   WHERE pd.current_city = p_ville AND pd.current_building = p_bat AND pd.current_room = p_piece
     AND coalesce(pd.pa, 0) > 0
     AND pd.country = v_pays
     AND CASE WHEN v_mutin THEN public.mutinerie_camp_de(pd.name) = p_camp
                           ELSE public.mutinerie_camp_de(pd.name) IS NULL END
  ON CONFLICT DO NOTHING;

  -- Branche SOLDATS PNJ : lit desormais le socle.
  INSERT INTO public.batailles_engagements
    (bataille_id, camp, compagnie_id, section_id, matricule, grade, pa_initial, groupe_id)
  SELECT p_bataille_id, p_camp, cm.id, sm.section_id, sm.matricule, 'soldat',
         m.pa, p_camp || '|' || cm.id || ':' || sm.section_id
    FROM public.pnj_membres m
    JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
    JOIN public.compagnies_militaires cm ON m.id LIKE cm.id || '-%'
    JOIN LATERAL public.pnj_position_effective(m.id) pe ON true
   WHERE m.famille = 'soldat'
     AND m.statut  = 'actif'
     AND sm.en_reserve = false
     AND m.pays = v_pays
     AND coalesce(m.pa, 0) > 0
     AND CASE WHEN v_mutin THEN sm.mutin = p_camp ELSE sm.mutin IS NULL END
     AND pe.ville = p_ville AND pe.building_id = p_bat AND pe.room_id = p_piece
  ON CONFLICT DO NOTHING;
END;
$function$;

-- militaire_bataille_round(bigint) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_bataille_round(p_bataille_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  b record; v_round integer; v_camps text[]; v_camp text; v_surprise text;
  v_actions jsonb := '[]'::jsonb; v_autres jsonb := '[]'::jsonb;
  v_reste integer; v_debout integer; v_issue text; v_attente integer;
BEGIN
  SELECT * INTO b FROM public.batailles WHERE id = p_bataille_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'bataille_introuvable'); END IF;
  IF b.statut <> 'en_cours' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'bataille_terminee', 'issue', b.issue);
  END IF;

  v_round := b.round_courant + 1;
  IF v_round > 200 THEN
    UPDATE public.batailles SET statut = 'terminee', fin_ts = now(),
           termine_raison = 'borne_technique_atteinte', issue = NULL WHERE id = p_bataille_id;
    RETURN jsonb_build_object('ok', false, 'raison', 'borne_technique_atteinte', 'round', v_round);
  END IF;

  SELECT coalesce(array_agg(DISTINCT camp), '{}') INTO v_camps
    FROM public.batailles_engagements
   WHERE bataille_id = p_bataille_id AND sorti_round IS NULL;

  -- SURPRISE : premier round, et seulement si l'engageant avait l'initiative.
  v_surprise := CASE WHEN v_round = 1 AND b.initiative = 'a' THEN b.camp_a ELSE NULL END;

  IF v_surprise IS NOT NULL THEN
    -- La passe du camp surprenant est calculee ET appliquee avant que les
    -- autres ne soient photographies : c'est cela, l'initiative.
    v_actions := public.militaire_bataille_actions(p_bataille_id, v_surprise, v_round, true);
    v_actions := public.militaire_bataille_appliquer(p_bataille_id, v_actions, v_round);
    FOREACH v_camp IN ARRAY v_camps LOOP
      CONTINUE WHEN v_camp = v_surprise;
      v_autres := v_autres || public.militaire_bataille_actions(p_bataille_id, v_camp, v_round, false);
    END LOOP;
    v_autres  := public.militaire_bataille_appliquer(p_bataille_id, v_autres, v_round);
    v_actions := v_actions || v_autres;
  ELSE
    -- Hors surprise, toutes les passes sont calculees AVANT toute
    -- application : c'est cela, la simultaneite.
    FOREACH v_camp IN ARRAY v_camps LOOP
      v_actions := v_actions || public.militaire_bataille_actions(p_bataille_id, v_camp, v_round, false);
    END LOOP;
    v_actions := public.militaire_bataille_appliquer(p_bataille_id, v_actions, v_round);
  END IF;

  -- Un rapport par camp encore present.
  FOREACH v_camp IN ARRAY v_camps LOOP
    SELECT count(*) INTO v_reste FROM public.batailles_engagements
     WHERE bataille_id = p_bataille_id AND camp = v_camp AND sorti_round IS NULL;
    INSERT INTO public.batailles_rounds (bataille_id, numero, camp, rapport)
    VALUES (p_bataille_id, v_round, v_camp,
            public.militaire_bataille_rapport(p_bataille_id, v_camp,
              coalesce((public.militaire_camps_hostiles(p_bataille_id, v_camp))[1], v_camp),
              v_round, v_actions, v_reste,
              (SELECT count(*)::integer FROM public.batailles_engagements
                WHERE bataille_id = p_bataille_id AND camp <> v_camp AND sorti_round IS NULL)))
    ON CONFLICT (bataille_id, numero, camp) DO NOTHING;
  END LOOP;

  UPDATE public.batailles SET round_courant = v_round WHERE id = p_bataille_id;

  -- Seuil de 50 %, fenetre de 90 s, replis automatiques.
  v_attente := public.militaire_bataille_arbitrer_groupes(p_bataille_id, v_round);

  -- Fin : il ne reste qu'un camp debout, ou aucun.
  SELECT count(DISTINCT camp) INTO v_debout FROM public.batailles_engagements
   WHERE bataille_id = p_bataille_id AND sorti_round IS NULL;
  IF v_debout <= 1 THEN
    SELECT CASE WHEN v_debout = 0 THEN 'aneantissement_mutuel'
                ELSE 'victoire_' || (SELECT DISTINCT camp FROM public.batailles_engagements
                                      WHERE bataille_id = p_bataille_id AND sorti_round IS NULL) END
      INTO v_issue;
    UPDATE public.batailles SET statut = 'terminee', fin_ts = now(), issue = v_issue,
           termine_raison = 'camp_hors_combat' WHERE id = p_bataille_id;
  END IF;

  RETURN jsonb_build_object('ok', true, 'round', v_round, 'surprise', v_surprise,
    'camps', v_camps, 'camps_debout', v_debout, 'groupes_en_attente', v_attente,
    'issue', v_issue, 'terminee', (v_debout <= 1));
END;
$function$;

-- militaire_blob_projeter(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.militaire_blob_projeter(p_compagnie text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_data jsonb; v_secs jsonb; v_res jsonb; v_n integer := 0;
BEGIN
  SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = p_compagnie FOR UPDATE;
  IF v_data IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;

  -- SECTIONS. Les soldats JOUEURS (pj) n'ont pas de ligne au socle : on ne les touche jamais.
  SELECT COALESCE(jsonb_agg(
           s || jsonb_build_object('soldats', (
             SELECT COALESCE(jsonb_agg(
                      CASE WHEN COALESCE((sol->>'pj')::boolean,false) THEN sol
                           ELSE sol || jsonb_build_object(
                                  'leaderCourant', m.leader_pj,
                                  'ville', m.ville, 'buildingId', m.building_id,
                                  'roomId', m.room_id, 'pa', m.pa)
                      END ORDER BY sp), '[]'::jsonb)
               FROM jsonb_array_elements(COALESCE(s->'soldats','[]'::jsonb))
                    WITH ORDINALITY AS ts(sol, sp)
               LEFT JOIN public.pnj_membres m
                 ON m.id = p_compagnie || '-' || (sol->>'matricule')))
           ORDER BY sp2), '[]'::jsonb)
    INTO v_secs
    FROM jsonb_array_elements(COALESCE(v_data->'sections','[]'::jsonb)) WITH ORDINALITY AS t(s, sp2);

  SELECT COALESCE(jsonb_agg(
           r || jsonb_build_object('leaderCourant', m.leader_pj,
                  'ville', m.ville, 'buildingId', m.building_id,
                  'roomId', m.room_id, 'pa', m.pa)
           ORDER BY rp), '[]'::jsonb)
    INTO v_res
    FROM jsonb_array_elements(COALESCE(v_data->'reserve','[]'::jsonb)) WITH ORDINALITY AS t(r, rp)
    LEFT JOIN public.pnj_membres m ON m.id = p_compagnie || '-' || (r->>'matricule');

  UPDATE public.compagnies_militaires
     SET data = v_data || jsonb_build_object('sections', v_secs, 'reserve', v_res)
   WHERE id = p_compagnie;
  SELECT count(*) INTO v_n FROM public.pnj_membres WHERE id LIKE p_compagnie || '-%';
  RETURN jsonb_build_object('ok', true, 'projetes', v_n);
END; $function$;

-- militaire_bonus_arme(text,text) -> integer | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.militaire_bonus_arme(p_cle text, p_mode text)
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce((SELECT b.bonus FROM public.militaire_armes_bonus b
                    WHERE b.cle = p_cle AND b.mode = p_mode), 0);
$function$;

-- militaire_calepin() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_calepin()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_moi text; v_periodes jsonb; v_total integer; v_comp jsonb;
  v_grade text; v_pays text; v_deco jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT coalesce(country,'republic'),
         CASE WHEN jsonb_typeof(competences_militaires)='object' THEN competences_militaires ELSE '{}'::jsonb END
    INTO v_pays, v_comp FROM public.personnages_donnees WHERE name = v_moi;

  SELECT coalesce(jsonb_agg(p ORDER BY p_debut DESC), '[]'::jsonb), coalesce(sum(p_jours), 0)
    INTO v_periodes, v_total
    FROM (
      SELECT sm.debut_ts AS p_debut,
             greatest(1, (coalesce(sm.fin_ts, now())::date - sm.debut_ts::date) + 1) AS p_jours,
             jsonb_build_object(
               'grade', sm.grade, 'pays', sm.pays,
               'compagnie', sm.compagnie_id, 'section', sm.section_id,
               'debut', sm.debut_ts::date, 'fin', sm.fin_ts::date,
               'en_cours', sm.fin_ts IS NULL,
               'jours', greatest(1, (coalesce(sm.fin_ts, now())::date - sm.debut_ts::date) + 1)) AS p
        FROM public.services_militaires sm
       WHERE sm.personnage = v_moi) t;

  SELECT sm.grade INTO v_grade FROM public.services_militaires sm
   WHERE sm.personnage = v_moi AND sm.fin_ts IS NULL ORDER BY sm.debut_ts DESC LIMIT 1;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'niveau', d.niveau, 'intitule', d.intitule, 'citation', d.citation,
           'decerne_par', d.decerne_par, 'poste', d.poste_decernant,
           'le', d.decerne_le::date) ORDER BY d.decerne_le DESC), '[]'::jsonb)
    INTO v_deco FROM public.decorations_militaires d WHERE d.decore = v_moi;

  RETURN jsonb_build_object('ok', true, 'nom', v_moi, 'pays', v_pays,
    'grade_courant', v_grade, 'en_service', v_grade IS NOT NULL,
    'jours_total', v_total, 'periodes', v_periodes, 'decorations', v_deco,
    'competences', jsonb_build_object(
      'combat_rapproche', coalesce((v_comp->>'combat_rapproche')::integer, 0),
      'tir',             coalesce((v_comp->>'tir')::integer, 0),
      'reconnaissance',  coalesce((v_comp->>'reconnaissance')::integer, 0),
      'secourisme',      coalesce((v_comp->>'secourisme')::integer, 0)));
END;
$function$;

-- militaire_camouflage_groupe(numeric,integer,integer) -> numeric | sql | SECURITY INVOKER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_camouflage_groupe(p_reco_moyenne numeric, p_effectif integer, p_equipes integer)
 RETURNS numeric
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  SELECT coalesce(p_reco_moyenne, 0)
       + CASE WHEN coalesce(p_effectif,0) > 0
              THEN 20.0 * least(1.0, greatest(0, coalesce(p_equipes,0))::numeric / p_effectif)
              ELSE 0 END
       + public.militaire_malus_taille(p_effectif);
$function$;

-- militaire_camps_hostiles(bigint,text) -> text[] | sql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_camps_hostiles(p_bataille_id bigint, p_camp text)
 RETURNS text[]
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT coalesce(array_agg(DISTINCT e.camp), '{}')
    FROM public.batailles_engagements e
   WHERE e.bataille_id = p_bataille_id
     AND e.sorti_round IS NULL
     AND e.camp IS DISTINCT FROM p_camp
     AND ( EXISTS (SELECT 1 FROM public.guerres g
                    WHERE g.statut = 'active'
                      AND ((g.data->>'attaquant' = p_camp AND g.data->>'attaque'  = e.camp)
                        OR (g.data->>'attaque'  = p_camp AND g.data->>'attaquant' = e.camp)))
        OR ( public.mutinerie_pays_du_camp(p_camp) = public.mutinerie_pays_du_camp(e.camp)
             AND (public.mutinerie_est_camp(p_camp) OR public.mutinerie_est_camp(e.camp)) ) );
$function$;

-- militaire_candidater_soldat(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_candidater_soldat(p_compagnie_id text, p_section_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_moi text; v_pays text; v_bat text; v_poste text;
  v_data jsonb; v_sec jsonb; v_id text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT coalesce(country,'republic'), coalesce(current_building,''), coalesce(poste->>'id','')
    INTO v_pays, v_bat, v_poste FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  -- Presence reelle exigee, comme militaire_retrait et refectoire_repas : on s'engage a la caserne.
  IF v_bat <> 'caserne-militaire' THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF v_poste IN ('lieutenant','capitaine','commandant') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_officier', 'poste', v_poste);
  END IF;

  SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = p_compagnie_id;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;
  IF v_data->>'pays' IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction'); END IF;
  SELECT s INTO v_sec FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb)) s
   WHERE s->>'id' = p_section_id;
  IF v_sec IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'section_introuvable'); END IF;
  IF coalesce(v_sec->>'lieutenantNom','') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'section_sans_lieutenant'); END IF;

  -- Deja soldat quelque part ? On ne sert pas deux sections a la fois.
  IF EXISTS (SELECT 1 FROM public.compagnies_militaires c,
                    jsonb_array_elements(coalesce(c.data->'sections','[]'::jsonb)) s,
                    jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol
              WHERE coalesce((sol->>'pj')::boolean,false) AND sol->>'nom' = v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_soldat');
  END IF;

  -- Candidature active deja en cours pour ce meme PJ (tous statuts non finaux).
  IF EXISTS (SELECT 1 FROM public.engagements_militaires
              WHERE statut IN ('soldat_attente_lieutenant','soldat_liste_attente')
                AND data->>'nom' = v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'candidature_en_cours');
  END IF;

  v_id := 'engsold-' || replace(gen_random_uuid()::text, '-', '');
  INSERT INTO public.engagements_militaires (id, statut, data)
  VALUES (v_id, 'soldat_attente_lieutenant', jsonb_build_object(
    'grade', 'soldat', 'nom', v_moi, 'pays', v_pays,
    'compagnieId', p_compagnie_id, 'sectionId', p_section_id,
    'lieutenantNom', v_sec->>'lieutenantNom', 'depuis', to_jsonb(now())));

  RETURN jsonb_build_object('ok', true, 'engagement', v_id,
                            'lieutenant', v_sec->>'lieutenantNom');
END; $function$;

-- militaire_candidature_accepter(text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_candidature_accepter(p_id text, p_compagnie_id text, p_section_id text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE r record; v record; v_libre integer; v_echeance timestamptz; v_annulees integer;
BEGIN
  SELECT * INTO r FROM public.militaire_recruteur_de_moi();
  IF r.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', r.o_raison); END IF;

  -- LA CIBLE DOIT ETRE LA SIENNE : le client propose, le serveur verifie.
  IF r.o_compagnie IS NOT NULL AND p_compagnie_id IS DISTINCT FROM r.o_compagnie THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_hors_autorite');
  END IF;
  IF r.o_section IS NOT NULL AND p_section_id IS DISTINCT FROM r.o_section THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'section_hors_autorite');
  END IF;

  -- VERROU SUR LA CANDIDATURE D'ABORD. Deux recruteurs qui acceptent le meme candidat a la meme
  -- seconde se presentent ici l'un apres l'autre : le second trouve `acceptee` et repart avec un
  -- refus propre. C'est ce qui donne son sens a « le premier qui accepte l'emporte ».
  SELECT * INTO v FROM public.candidatures_militaires WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'candidature_introuvable'); END IF;
  IF v.pays <> r.o_pays OR v.grade_vise <> r.o_grade_recrute THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_perimetre');
  END IF;
  IF v.statut <> 'active' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'candidature_non_active', 'statut', v.statut);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = v.candidat) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'candidat_introuvable');
  END IF;
  IF public.militaire_grade_effectif(v.candidat) IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'candidat_deja_militaire');
  END IF;

  v_libre := public.militaire_places_libres_grade(r.o_pays, v.grade_vise, p_compagnie_id, p_section_id);
  IF v_libre <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'plus_de_place'); END IF;

  v_echeance := now() + interval '48 hours';
  UPDATE public.candidatures_militaires
     SET statut = 'acceptee', accepte_par = r.o_moi, accepte_le = now(),
         echeance = v_echeance, compagnie_id = p_compagnie_id, section_id = p_section_id
   WHERE id = p_id;

  -- UNE ACCEPTATION EN ANNULE TOUTES LES AUTRES. On ne sert pas deux armees.
  UPDATE public.candidatures_militaires
     SET statut = 'annulee'
   WHERE candidat = v.candidat AND id <> p_id AND statut = 'active';
  GET DIAGNOSTICS v_annulees = ROW_COUNT;

  -- COURRIER AU CANDIDAT — et rien sur le lieu ni sur le recruteur : la decouverte se fait a la
  -- caserne, en personne. C'est tout l'interet de la scene.
  INSERT INTO public.mails (id, from_player, to_player, subject, body, time, read)
  VALUES ('ce-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-' || substr(md5(random()::text),1,6),
          'État-major', v.candidat,
          'Votre engagement est accepté',
          'Votre candidature au grade de ' || v.grade_vise || ' a été retenue. ' ||
          'Présentez-vous à la Caserne Militaire dans les 48 heures pour découvrir votre affectation. ' ||
          'Passé ce délai, votre engagement sera caduc et la place rendue.',
          to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'), false);

  RETURN jsonb_build_object('ok', true, 'id', p_id, 'candidat', v.candidat,
    'grade', v.grade_vise, 'echeance', v_echeance, 'autres_annulees', v_annulees);
END;
$function$;

-- militaire_candidature_deposer(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_candidature_deposer(p_grade text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_moi text; v_pays text; v_bat text; v_grade_actuel text; v_id text; v_paie jsonb;
BEGIN
  IF p_grade NOT IN ('capitaine','lieutenant','soldat') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'grade_invalide');
  END IF;
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT coalesce(country,'republic'), coalesce(current_building,'')
    INTO v_pays, v_bat FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_pays IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  IF v_bat <> 'caserne-militaire' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;

  v_grade_actuel := public.militaire_grade_effectif(v_moi);
  IF v_grade_actuel IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_militaire', 'grade', v_grade_actuel);
  END IF;

  IF EXISTS (SELECT 1 FROM public.candidatures_militaires
              WHERE candidat = v_moi AND grade_vise = p_grade AND statut IN ('active','acceptee')) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'candidature_deja_active', 'grade', p_grade);
  END IF;

  v_paie := public.payer_ordre(v_moi, 's_engager_armee', 2, 0);
  IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_paie->>'raison','paiement_refuse'));
  END IF;

  v_id := 'cand-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-' || substr(md5(random()::text), 1, 6);
  INSERT INTO public.candidatures_militaires (id, pays, candidat, grade_vise, derniere_relance)
  VALUES (v_id, v_pays, v_moi, p_grade, now());

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'grade', p_grade,
                            'pa', v_paie->'pa', 'pa_preleves', 2);
END;
$function$;

-- militaire_candidature_refuser(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_candidature_refuser(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE r record; v record;
BEGIN
  SELECT * INTO r FROM public.militaire_recruteur_de_moi();
  IF r.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', r.o_raison); END IF;

  SELECT * INTO v FROM public.candidatures_militaires WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'candidature_introuvable'); END IF;
  IF v.pays <> r.o_pays OR v.grade_vise <> r.o_grade_recrute THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_perimetre');
  END IF;
  IF v.statut <> 'active' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'candidature_non_active', 'statut', v.statut);
  END IF;

  IF NOT (v.refus ? r.o_moi) THEN
    UPDATE public.candidatures_militaires
       SET refus = refus || to_jsonb(r.o_moi) WHERE id = p_id;
  END IF;

  RETURN jsonb_build_object('ok', true, 'id', p_id);
END;
$function$;

-- militaire_candidature_retirer(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_candidature_retirer(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_moi text; v_statut text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT statut INTO v_statut FROM public.candidatures_militaires
   WHERE id = p_id AND candidat = v_moi FOR UPDATE;
  IF v_statut IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'candidature_introuvable'); END IF;
  IF v_statut <> 'active' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'candidature_non_retirable', 'statut', v_statut);
  END IF;

  UPDATE public.candidatures_militaires SET statut = 'retiree' WHERE id = p_id;
  RETURN jsonb_build_object('ok', true, 'id', p_id);
END;
$function$;

-- militaire_candidature_traiter(text,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_candidature_traiter(p_engagement_id text, p_accepter boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  c_places constant integer := 24;
  g record; v_e record; v_nom text; v_sec jsonb; v_sols jsonb;
  v_total integer; v_pnj_pos integer; v_pnj jsonb; v_reserve jsonb;
BEGIN
  SELECT * INTO v_e FROM public.engagements_militaires WHERE id = p_engagement_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'engagement_introuvable'); END IF;
  IF v_e.statut NOT IN ('soldat_attente_lieutenant','soldat_liste_attente') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'engagement_deja_traite', 'statut', v_e.statut);
  END IF;

  -- AUTORITE : le Lieutenant structurel de la section visee, verifie sur la compagnie elle-meme.
  SELECT * INTO g FROM public.militaire_section_de_moi(v_e.data->>'compagnieId', v_e.data->>'sectionId');
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;

  v_nom := v_e.data->>'nom';
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = v_nom) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'candidat_introuvable');
  END IF;

  IF NOT coalesce(p_accepter, false) THEN
    UPDATE public.engagements_militaires SET statut = 'soldat_refuse' WHERE id = p_engagement_id;
    RETURN jsonb_build_object('ok', true, 'resultat', 'refuse', 'nom', v_nom);
  END IF;

  SELECT s INTO v_sec FROM jsonb_array_elements(g.o_data->'sections') s
   WHERE s->>'id' = v_e.data->>'sectionId';
  v_sols := CASE WHEN jsonb_typeof(v_sec->'soldats') = 'array' THEN v_sec->'soldats' ELSE '[]'::jsonb END;
  v_total := jsonb_array_length(v_sols);

  -- Deja dans la section ? Idempotence.
  IF EXISTS (SELECT 1 FROM jsonb_array_elements(v_sols) s
              WHERE coalesce((s->>'pj')::boolean,false) AND s->>'nom' = v_nom) THEN
    UPDATE public.engagements_militaires SET statut = 'soldat_accepte' WHERE id = p_engagement_id;
    RETURN jsonb_build_object('ok', true, 'resultat', 'deja_present', 'nom', v_nom);
  END IF;

  IF v_total < c_places THEN
    -- Place libre : le PJ l'occupe.
    v_sols := v_sols || jsonb_build_array(jsonb_build_object('pj', true, 'nom', v_nom));
    v_reserve := CASE WHEN jsonb_typeof(g.o_data->'reserve') = 'array' THEN g.o_data->'reserve' ELSE '[]'::jsonb END;
  ELSE
    -- Section pleine : on cherche un PNJ a remplacer. Le premier venu.
    SELECT pos, sol INTO v_pnj_pos, v_pnj
      FROM jsonb_array_elements(v_sols) WITH ORDINALITY AS t(sol, pos)
     WHERE NOT coalesce((sol->>'pj')::boolean, false) ORDER BY pos LIMIT 1;
    IF v_pnj IS NULL THEN
      -- 24 PJ : personne n'est evince. Liste d'attente, le candidat reste civil.
      UPDATE public.engagements_militaires SET statut = 'soldat_liste_attente' WHERE id = p_engagement_id;
      RETURN jsonb_build_object('ok', true, 'resultat', 'liste_attente', 'nom', v_nom,
                                'places', c_places);
    END IF;
    -- Remplacement ATOMIQUE : le PNJ COMPLET retourne en reserve, avec son matricule et son
    -- entrainement. Aucune perte d'identite, aucun PNJ cree ni detruit.
    SELECT coalesce(jsonb_agg(sol ORDER BY pos), '[]'::jsonb) INTO v_sols
      FROM jsonb_array_elements(v_sols) WITH ORDINALITY AS t(sol, pos) WHERE pos <> v_pnj_pos;
    v_sols := v_sols || jsonb_build_array(jsonb_build_object('pj', true, 'nom', v_nom));
    v_reserve := (CASE WHEN jsonb_typeof(g.o_data->'reserve') = 'array' THEN g.o_data->'reserve' ELSE '[]'::jsonb END)
                 || jsonb_build_array(v_pnj);
  END IF;

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(g.o_data, v_e.data->>'sectionId',
                  v_sec || jsonb_build_object('soldats', v_sols))
                || jsonb_build_object('reserve', v_reserve)
   WHERE id = v_e.data->>'compagnieId';

  UPDATE public.engagements_militaires SET statut = 'soldat_accepte' WHERE id = p_engagement_id;
  PERFORM public.militaire_service_ouvrir(v_nom, g.o_data->>'pays', 'soldat',
            v_e.data->>'compagnieId', v_e.data->>'sectionId');

  RETURN jsonb_build_object('ok', true, 'resultat', 'accepte', 'nom', v_nom,
    'pnj_rendu_reserve', (v_pnj IS NOT NULL),
    'matricule_rendu', v_pnj->>'matricule',
    'effectif', jsonb_array_length(v_sols),
    'reserve', jsonb_array_length(v_reserve));
END; $function$;

-- militaire_candidatures_a_traiter() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_candidatures_a_traiter()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE r record; v_places jsonb; v_cands jsonb;
BEGIN
  SELECT * INTO r FROM public.militaire_recruteur_de_moi();
  IF r.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', r.o_raison); END IF;

  -- LES PLACES OUVERTES. Le calcul retranche deja les acceptations vivantes, si bien qu'un
  -- Capitaine ne peut pas promettre deux fois la meme section.
  IF r.o_grade_recrute = 'capitaine' THEN
    SELECT coalesce(jsonb_agg(jsonb_build_object(
             'compagnie_id', c.id, 'compagnie_nom', coalesce(c.data->>'nom', c.id),
             'section_id', NULL, 'libre',
             public.militaire_places_libres_grade(r.o_pays, 'capitaine', c.id, NULL))
             ORDER BY c.id), '[]'::jsonb) INTO v_places
      FROM public.compagnies_militaires c
     WHERE c.data->>'pays' = r.o_pays
       AND public.militaire_places_libres_grade(r.o_pays, 'capitaine', c.id, NULL) > 0;

  ELSIF r.o_grade_recrute = 'lieutenant' THEN
    SELECT coalesce(jsonb_agg(jsonb_build_object(
             'compagnie_id', c.id, 'compagnie_nom', coalesce(c.data->>'nom', c.id),
             'section_id', s->>'id', 'section_nom', coalesce(s->>'nom', s->>'id'), 'libre',
             public.militaire_places_libres_grade(r.o_pays, 'lieutenant', c.id, s->>'id'))
             ORDER BY s->>'id'), '[]'::jsonb) INTO v_places
      FROM public.compagnies_militaires c, jsonb_array_elements(c.data->'sections') s
     WHERE c.id = r.o_compagnie
       AND public.militaire_places_libres_grade(r.o_pays, 'lieutenant', c.id, s->>'id') > 0;

  ELSE
    SELECT jsonb_build_array(jsonb_build_object(
             'compagnie_id', c.id, 'compagnie_nom', coalesce(c.data->>'nom', c.id),
             'section_id', s->>'id', 'section_nom', coalesce(s->>'nom', s->>'id'), 'libre',
             public.militaire_places_libres_grade(r.o_pays, 'soldat', c.id, s->>'id')))
      INTO v_places
      FROM public.compagnies_militaires c, jsonb_array_elements(c.data->'sections') s
     WHERE c.id = r.o_compagnie AND s->>'id' = r.o_section;
  END IF;

  -- LES CANDIDATS. On masque ceux que J'AI deja ecartes -- pas ceux que d'autres ont ecartes.
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'id', cm.id, 'candidat', cm.candidat, 'depuis', cm.cree_le) ORDER BY cm.cree_le),
         '[]'::jsonb) INTO v_cands
    FROM public.candidatures_militaires cm
   WHERE cm.pays = r.o_pays AND cm.grade_vise = r.o_grade_recrute AND cm.statut = 'active'
     AND NOT (cm.refus ? r.o_moi);

  RETURN jsonb_build_object('ok', true, 'grade_recrute', r.o_grade_recrute,
    'places', coalesce(v_places, '[]'::jsonb), 'candidatures', v_cands);
END;
$function$;

-- militaire_candidatures_relancer() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_candidatures_relancer()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_n integer := 0; r record;
BEGIN
  FOR r IN SELECT * FROM public.candidatures_militaires
            WHERE statut = 'active'
              AND coalesce(derniere_relance, cree_le) <= now() - interval '7 days'
            FOR UPDATE
  LOOP
    INSERT INTO public.mails (id, from_player, to_player, subject, body, time, read)
    VALUES ('ce-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-' || substr(md5(random()::text),1,6),
            'État-major', r.candidat,
            'Votre candidature est toujours à l''étude',
            'Votre candidature au grade de ' || r.grade_vise || ', déposée le ' ||
            to_char(r.cree_le AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY') ||
            ', reste enregistrée et sera examinée. Vous pouvez la retirer à tout moment à la Caserne Militaire.',
            to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'), false);
    UPDATE public.candidatures_militaires SET derniere_relance = now() WHERE id = r.id;
    v_n := v_n + 1;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'relancees', v_n);
END;
$function$;

-- militaire_chance_detection(numeric,numeric,integer,integer) -> integer | sql | SECURITY INVOKER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_chance_detection(p_reco_observateur numeric, p_camouflage_cible numeric, p_modif_distance integer, p_bonus_jumelles integer DEFAULT 0)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  SELECT greatest(5, least(95, round(
    50 + coalesce(p_reco_observateur,0) - coalesce(p_camouflage_cible,0)
       + coalesce(p_modif_distance,0) + coalesce(p_bonus_jumelles,0))::integer));
$function$;

-- militaire_compagnie_creer() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.militaire_compagnie_creer()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  c_contingent constant integer := 96;
  c_sections   constant integer := 4;
  c_cout       constant numeric := 20000;
  c_pa         constant integer := 3;
  v_moi text; v_pays text; v_pa integer; v_id text; v_prefixe text;
  v_paye jsonb; v_caisse jsonb; v_sections jsonb; v_reserve jsonb;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  v_moi := public.exiger_poste('commandant');
  IF v_moi IS NULL THEN v_moi := public.mon_personnage(); END IF;
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT coalesce(country, 'republic'), coalesce(pa, 0) INTO v_pays, v_pa
    FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  IF v_pa < c_pa THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants', 'requis', c_pa, 'pa_reel', v_pa);
  END IF;

  v_caisse := public.caisse_institution_mouvement(v_pays || '_caserne-militaire', -c_cout, true);
  IF NOT coalesce((v_caisse->>'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false,
      'raison', coalesce(v_caisse->>'raison', 'caisse_refusee'), 'cout', c_cout);
  END IF;

  v_paye := public.payer_ordre(v_moi, 'recruter_compagnie', c_pa, 0);
  IF NOT coalesce((v_paye->>'ok')::boolean, false) THEN
    RAISE EXCEPTION 'militaire_compagnie_creer: paiement des PA refuse (%)',
      coalesce(v_paye->>'raison', 'motif inconnu');
  END IF;

  v_id := 'compagnie-' || v_pays || '-' || floor(extract(epoch FROM clock_timestamp()) * 1000)::bigint::text;
  v_prefixe := to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYYMM');

  SELECT jsonb_agg(jsonb_build_object(
           'id', v_id || '-s' || i, 'numero', i, 'lieutenantNom', NULL,
           'soldats', '[]'::jsonb) ORDER BY i)
    INTO v_sections FROM generate_series(1, c_sections) AS g(i);

  SELECT jsonb_agg(jsonb_build_object(
           'matricule', v_prefixe || '-' || lpad(i::text, 3, '0'),
           'formation', jsonb_build_object('combat_rapproche', 0, 'tir', 0,
                                           'reconnaissance', 0, 'secourisme', 0),
           'arme', 'corps_a_corps',
           'ville', 'caserne', 'buildingId', 'caserne-militaire', 'roomId', 'corps_garde',
           'leaderCourant', NULL, 'pa', 12) ORDER BY i)
    INTO v_reserve FROM generate_series(1, c_contingent) AS g(i);

  INSERT INTO public.compagnies_militaires (id, data)
  VALUES (v_id, jsonb_build_object(
    'id', v_id, 'pays', v_pays, 'capitaineNom', NULL,
    'contingentInitial', c_contingent, 'reserve', v_reserve, 'sections', v_sections));

  RETURN jsonb_build_object('ok', true, 'compagnie', v_id, 'contingent', c_contingent,
                            'sections', c_sections, 'cout', c_cout, 'pa', v_paye->'pa');
END;
$function$;
