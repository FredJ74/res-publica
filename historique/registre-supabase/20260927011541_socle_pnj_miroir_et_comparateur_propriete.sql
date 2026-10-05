-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927011541
-- Nom original      : socle_pnj_miroir_et_comparateur_propriete
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-27 01:15:41 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 4891371945e5421e1ad524d6fcb8aed9
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
-- MIROIR, COPIE ET COMPARATEUR ALIGNES SUR LE MODELE PROPRIETE / AUTORITE (27 septembre 2026)
--
-- Trois corrections de fond, au-dela du simple renommage de colonnes :
--
--  (a) LE MIROIR NE RATTRAPAIT PAS LE PERIMETRE. Son ON CONFLICT ne touchait pas la propriete.
--      Quand le Capitaine verse la reserve dans une section neuve, le perimetre du soldat CHANGE
--      (`...:reserve` -> `...-s2`). Sans mise a jour, le soldat restait administre par personne
--      alors que son nouveau Lieutenant devait le commander. Le perimetre est desormais reecrit
--      a chaque passage, comme le reste.
--
--  (b) LE MIROIR NE RESSUSCITAIT PAS (defaut B6 de l'audit). `statut` etait absent du ON CONFLICT.
--      Un soldat passe a 'mort' dans le socle y restait mort pour toujours, meme si le blob --
--      qui fait autorite -- le donnait vivant : le socle divergeait sans que rien ne le dise.
--
--  (c) LE COMPARATEUR NE VERIFIAIT PAS LA PROPRIETE, il verifiait une CONSTANTE. Il testait
--      `proprietaire_poste <> 'lieutenant'`, ce qui etait vrai pour les 96 soldats y compris les
--      reservistes : le test ne pouvait rien detecter. Il compare maintenant le perimetre reel
--      cote blob et cote socle -- section par section, reserve comprise.

-- ---------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.pnj_miroir_compagnie(p_compagnie text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE c record; v_pays text; v_vus text[] := '{}'; v_sup integer := 0; v_maj integer := 0;
        s jsonb; sol jsonb; v_id text; v_sec text; v_res_per text;
BEGIN
  SELECT * INTO c FROM public.compagnies_militaires WHERE id = p_compagnie;
  IF c.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;
  v_pays := c.data->>'pays';
  v_res_per := p_compagnie || ':reserve';

  FOR s IN SELECT value FROM jsonb_array_elements(COALESCE(c.data->'sections','[]'::jsonb)) LOOP
    v_sec := s->>'id';
    FOR sol IN SELECT value FROM jsonb_array_elements(COALESCE(s->'soldats','[]'::jsonb)) LOOP
      CONTINUE WHEN COALESCE((sol->>'pj')::boolean, false) IS TRUE;
      v_id := p_compagnie || '-' || (sol->>'matricule');
      v_vus := v_vus || v_id;
      INSERT INTO public.pnj_membres (id, famille, nom, pays,
          proprietaire_institution, proprietaire_perimetre,
          leader_pj, ville, building_id, room_id, pa, statut)
      VALUES (v_id, 'soldat', COALESCE(sol->>'matricule','?'), v_pays, 'militaire', v_sec,
          sol->>'leaderCourant', sol->>'ville', sol->>'buildingId', sol->>'roomId',
          COALESCE((sol->>'pa')::integer, 12), 'actif')
      ON CONFLICT (id) DO UPDATE SET
          leader_pj = EXCLUDED.leader_pj, ville = EXCLUDED.ville,
          building_id = EXCLUDED.building_id, room_id = EXCLUDED.room_id,
          pa = EXCLUDED.pa, statut = EXCLUDED.statut,
          proprietaire_institution = EXCLUDED.proprietaire_institution,
          proprietaire_perimetre = EXCLUDED.proprietaire_perimetre,
          maj_le = now();
      INSERT INTO public.pnj_soldats_metier (pnj_id, matricule, section_id, en_reserve,
          arme, formation, mutin)
      VALUES (v_id, sol->>'matricule', v_sec, false, sol->>'arme',
              COALESCE(sol->'formation','{}'::jsonb), sol->>'mutin')
      ON CONFLICT (pnj_id) DO UPDATE SET
          section_id = EXCLUDED.section_id, en_reserve = EXCLUDED.en_reserve,
          arme = EXCLUDED.arme, formation = EXCLUDED.formation, mutin = EXCLUDED.mutin;
      v_maj := v_maj + 1;
      PERFORM public.pnj_miroir_possessions(v_id,
        CASE WHEN jsonb_typeof(sol->'accessoires')='array' THEN sol->'accessoires' ELSE '[]'::jsonb END);
    END LOOP;
  END LOOP;

  FOR sol IN SELECT value FROM jsonb_array_elements(COALESCE(c.data->'reserve','[]'::jsonb)) LOOP
    v_id := p_compagnie || '-' || (sol->>'matricule');
    v_vus := v_vus || v_id;
    INSERT INTO public.pnj_membres (id, famille, nom, pays,
        proprietaire_institution, proprietaire_perimetre,
        leader_pj, ville, building_id, room_id, pa, statut)
    VALUES (v_id, 'soldat', COALESCE(sol->>'matricule','?'), v_pays, 'militaire', v_res_per,
        sol->>'leaderCourant', sol->>'ville', sol->>'buildingId', sol->>'roomId',
        COALESCE((sol->>'pa')::integer, 12), 'actif')
    ON CONFLICT (id) DO UPDATE SET
        leader_pj = EXCLUDED.leader_pj, ville = EXCLUDED.ville,
        building_id = EXCLUDED.building_id, room_id = EXCLUDED.room_id,
        pa = EXCLUDED.pa, statut = EXCLUDED.statut,
        proprietaire_institution = EXCLUDED.proprietaire_institution,
        proprietaire_perimetre = EXCLUDED.proprietaire_perimetre,
        maj_le = now();
    INSERT INTO public.pnj_soldats_metier (pnj_id, matricule, section_id, en_reserve,
        arme, formation, mutin)
    VALUES (v_id, sol->>'matricule', NULL, true, sol->>'arme',
            COALESCE(sol->'formation','{}'::jsonb), sol->>'mutin')
    ON CONFLICT (pnj_id) DO UPDATE SET
        section_id = NULL, en_reserve = true,
        arme = EXCLUDED.arme, formation = EXCLUDED.formation, mutin = EXCLUDED.mutin;
    v_maj := v_maj + 1;
    PERFORM public.pnj_miroir_possessions(v_id,
      CASE WHEN jsonb_typeof(sol->'accessoires')='array' THEN sol->'accessoires' ELSE '[]'::jsonb END);
  END LOOP;

  DELETE FROM public.pnj_membres
   WHERE id LIKE p_compagnie || '-%' AND NOT (id = ANY(v_vus));
  GET DIAGNOSTICS v_sup = ROW_COUNT;
  RETURN jsonb_build_object('ok', true, 'synchronises', v_maj, 'supprimes', v_sup);
END; $$;

-- ---------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.pnj_copier_soldats(p_compagnie text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE
  c record; s jsonb; sol jsonb; v_id text; v_pays text;
  v_sections integer := 0; v_sect integer := 0; v_res integer := 0; v_deja integer := 0;
BEGIN
  IF NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_serveur'); END IF;
  SELECT * INTO c FROM public.compagnies_militaires WHERE id = p_compagnie;
  IF c.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;
  v_pays := c.data->>'pays';

  SELECT count(*) INTO v_deja FROM public.pnj_membres m
   WHERE m.famille = 'soldat' AND m.id LIKE p_compagnie || '-%';
  IF v_deja > 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_copie', 'deja', v_deja); END IF;

  FOR s IN SELECT value FROM jsonb_array_elements(COALESCE(c.data->'sections','[]'::jsonb)) LOOP
    v_sections := v_sections + 1;
    FOR sol IN SELECT value FROM jsonb_array_elements(COALESCE(s->'soldats','[]'::jsonb)) LOOP
      CONTINUE WHEN COALESCE((sol->>'pj')::boolean, false) IS TRUE;
      v_id := p_compagnie || '-' || (sol->>'matricule');
      INSERT INTO public.pnj_membres (id, famille, nom, pays, proprietaire_institution,
          proprietaire_perimetre, leader_pj, ville, building_id, room_id, pa, statut)
      VALUES (v_id, 'soldat', COALESCE(sol->>'matricule','?'), v_pays, 'militaire', s->>'id',
          sol->>'leaderCourant', sol->>'ville', sol->>'buildingId', sol->>'roomId',
          COALESCE((sol->>'pa')::integer, 12), 'actif');
      INSERT INTO public.pnj_soldats_metier (pnj_id, matricule, section_id, en_reserve, arme, formation)
      VALUES (v_id, sol->>'matricule', s->>'id', false, sol->>'arme',
              COALESCE(sol->'formation','{}'::jsonb));
      v_sect := v_sect + 1;
    END LOOP;
  END LOOP;

  FOR sol IN SELECT value FROM jsonb_array_elements(COALESCE(c.data->'reserve','[]'::jsonb)) LOOP
    v_id := p_compagnie || '-' || (sol->>'matricule');
    INSERT INTO public.pnj_membres (id, famille, nom, pays, proprietaire_institution,
        proprietaire_perimetre, leader_pj, ville, building_id, room_id, pa, statut)
    VALUES (v_id, 'soldat', COALESCE(sol->>'matricule','?'), v_pays, 'militaire',
        p_compagnie || ':reserve',
        sol->>'leaderCourant', sol->>'ville', sol->>'buildingId', sol->>'roomId',
        COALESCE((sol->>'pa')::integer, 12), 'actif');
    INSERT INTO public.pnj_soldats_metier (pnj_id, matricule, section_id, en_reserve, arme, formation)
    VALUES (v_id, sol->>'matricule', NULL, true, sol->>'arme',
            COALESCE(sol->'formation','{}'::jsonb));
    v_res := v_res + 1;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'compagnie', p_compagnie, 'pays', v_pays,
    'sections', v_sections, 'copies_section', v_sect, 'copies_reserve', v_res,
    'total', v_sect + v_res);
END; $$;

-- ---------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.pnj_comparer_soldats(p_compagnie text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_div jsonb; v_nb_blob integer; v_nb_socle integer;
        v_pos_blob integer; v_pos_socle integer; v_pos_div jsonb;
        v_liquide numeric; v_liquide_non_nuls integer;
BEGIN
  WITH blob AS (
    SELECT sol->>'matricule' AS matricule, sol->>'leaderCourant' AS leader,
           sol->>'ville' AS ville, sol->>'buildingId' AS bat, sol->>'roomId' AS room,
           (sol->>'pa')::integer AS pa, sol->>'arme' AS arme,
           COALESCE(sol->'formation','{}'::jsonb) AS formation,
           false AS en_reserve, s->>'id' AS section_id, sol->>'mutin' AS mutin,
           s->>'id' AS perimetre
      FROM public.compagnies_militaires c,
           jsonb_array_elements(COALESCE(c.data->'sections','[]'::jsonb)) s,
           jsonb_array_elements(COALESCE(s->'soldats','[]'::jsonb)) sol
     WHERE c.id = p_compagnie AND COALESCE((sol->>'pj')::boolean, false) = false
    UNION ALL
    SELECT r->>'matricule', r->>'leaderCourant', r->>'ville', r->>'buildingId', r->>'roomId',
           (r->>'pa')::integer, r->>'arme', COALESCE(r->'formation','{}'::jsonb), true, NULL,
           r->>'mutin', p_compagnie || ':reserve'
      FROM public.compagnies_militaires c,
           jsonb_array_elements(COALESCE(c.data->'reserve','[]'::jsonb)) r
     WHERE c.id = p_compagnie
  ), socle AS (
    SELECT sm.matricule, m.leader_pj AS leader, m.ville, m.building_id AS bat,
           m.room_id AS room, m.pa, sm.arme, sm.formation, sm.en_reserve, sm.section_id,
           sm.mutin, m.statut, m.proprietaire_pj,
           m.proprietaire_institution AS institution, m.proprietaire_perimetre AS perimetre,
           m.leader_pnj_id, m.rue_noeud_id
      FROM public.pnj_membres m JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
     WHERE m.id LIKE p_compagnie || '-%'
  ), compare AS (
    SELECT COALESCE(b.matricule, s.matricule) AS matricule,
      CASE
        WHEN s.matricule IS NULL THEN 'absent_du_socle'
        WHEN b.matricule IS NULL THEN 'surnumeraire_dans_le_socle'
        WHEN b.leader      IS DISTINCT FROM s.leader      THEN 'leader'
        WHEN b.ville       IS DISTINCT FROM s.ville       THEN 'ville'
        WHEN b.bat         IS DISTINCT FROM s.bat         THEN 'batiment'
        WHEN b.room        IS DISTINCT FROM s.room        THEN 'piece'
        WHEN b.pa          IS DISTINCT FROM s.pa          THEN 'pa'
        WHEN b.arme        IS DISTINCT FROM s.arme        THEN 'arme'
        WHEN b.formation   IS DISTINCT FROM s.formation   THEN 'entrainement'
        WHEN b.en_reserve  IS DISTINCT FROM s.en_reserve  THEN 'reserve'
        WHEN b.section_id  IS DISTINCT FROM s.section_id  THEN 'section'
        WHEN b.mutin       IS DISTINCT FROM s.mutin       THEN 'mutin'
        -- PROPRIETE : institutionnelle, militaire, et sur le PERIMETRE que le blob decrit.
        WHEN s.proprietaire_pj IS NOT NULL                THEN 'propriete_personnelle_inattendue'
        WHEN s.institution IS DISTINCT FROM 'militaire'   THEN 'institution'
        WHEN b.perimetre   IS DISTINCT FROM s.perimetre   THEN 'perimetre'
        -- AXES QUE LE BLOB NE PEUT PAS PRODUIRE. Pendant la phase miroir les verbes de
        -- mouvement generiques sont verrouilles pour les soldats : un soldat suivant un autre
        -- PNJ, ou pose sur un noeud de rue, ne peut venir que d'une ecriture illegitime.
        WHEN s.leader_pnj_id IS NOT NULL                  THEN 'leader_pnj_interdit_phase_miroir'
        WHEN s.rue_noeud_id  IS NOT NULL                  THEN 'rue_noeud_interdit_phase_miroir'
        WHEN s.statut IS DISTINCT FROM 'actif'            THEN 'statut'
        ELSE NULL END AS divergence
      FROM blob b FULL OUTER JOIN socle s ON s.matricule = b.matricule
  )
  SELECT (SELECT count(*) FROM blob), (SELECT count(*) FROM socle),
         COALESCE(jsonb_agg(jsonb_build_object('matricule', matricule, 'divergence', divergence)
                            ORDER BY matricule) FILTER (WHERE divergence IS NOT NULL), '[]'::jsonb)
    INTO v_nb_blob, v_nb_socle, v_div FROM compare;

  -- POSSESSIONS : comparaison par (matricule, objet complet). On compare l'OBJET ENTIER, pas
  -- seulement son nom : un attribut modifie (usageUnique retire, produitMilitaire change) est
  -- donc une divergence. Multiensembles : un objet en double d'un cote et pas de l'autre est vu.
  WITH pb AS (
    SELECT sol->>'matricule' AS matricule, a AS objet,
           row_number() OVER (PARTITION BY sol->>'matricule', a::text) AS occ
      FROM public.compagnies_militaires c,
           jsonb_array_elements(COALESCE(c.data->'sections','[]'::jsonb)) s,
           jsonb_array_elements(COALESCE(s->'soldats','[]'::jsonb)) sol,
           jsonb_array_elements(CASE WHEN jsonb_typeof(sol->'accessoires')='array'
                                     THEN sol->'accessoires' ELSE '[]'::jsonb END) a
     WHERE c.id = p_compagnie AND COALESCE((sol->>'pj')::boolean, false) = false
    UNION ALL
    SELECT r->>'matricule', a,
           row_number() OVER (PARTITION BY r->>'matricule', a::text)
      FROM public.compagnies_militaires c,
           jsonb_array_elements(COALESCE(c.data->'reserve','[]'::jsonb)) r,
           jsonb_array_elements(CASE WHEN jsonb_typeof(r->'accessoires')='array'
                                     THEN r->'accessoires' ELSE '[]'::jsonb END) a
     WHERE c.id = p_compagnie
  ), ps AS (
    SELECT sm.matricule, p.objet,
           row_number() OVER (PARTITION BY sm.matricule, p.objet::text) AS occ
      FROM public.pnj_possessions p
      JOIN public.pnj_soldats_metier sm ON sm.pnj_id = p.pnj_id
      JOIN public.pnj_membres m ON m.id = p.pnj_id
     WHERE m.id LIKE p_compagnie || '-%' AND p.origine = 'blob_accessoires'
  ), pcmp AS (
    SELECT COALESCE(b.matricule, s.matricule) AS matricule,
           COALESCE(b.objet, s.objet) AS objet,
           CASE WHEN s.matricule IS NULL THEN 'possession_absente_du_socle'
                WHEN b.matricule IS NULL THEN 'possession_surnumeraire_dans_le_socle'
                ELSE NULL END AS divergence
      FROM pb b FULL OUTER JOIN ps s
        ON s.matricule = b.matricule AND s.objet::text = b.objet::text AND s.occ = b.occ
  )
  SELECT (SELECT count(*) FROM pb), (SELECT count(*) FROM ps),
         COALESCE(jsonb_agg(jsonb_build_object('matricule', matricule,
                    'objet', COALESCE(objet->>'name', objet->>'nom', '?'),
                    'divergence', divergence) ORDER BY matricule)
                  FILTER (WHERE divergence IS NOT NULL), '[]'::jsonb)
    INTO v_pos_blob, v_pos_socle, v_pos_div FROM pcmp;

  -- ARGENT : axe PROPRE AU SOCLE, le blob n'en a aucun. Ce n'est donc pas une divergence
  -- possible, mais une derive a rendre VISIBLE : on l'observe sans faire echouer la comparaison.
  SELECT COALESCE(sum(m.liquide), 0), count(*) FILTER (WHERE m.liquide <> 0)
    INTO v_liquide, v_liquide_non_nuls
    FROM public.pnj_membres m WHERE m.id LIKE p_compagnie || '-%';

  RETURN jsonb_build_object(
    'ok', jsonb_array_length(v_div) = 0 AND v_nb_blob = v_nb_socle
          AND jsonb_array_length(v_pos_div) = 0 AND v_pos_blob = v_pos_socle,
    'nb_blob', v_nb_blob, 'nb_socle', v_nb_socle,
    'correspondances', v_nb_blob - jsonb_array_length(v_div),
    'nb_divergences', jsonb_array_length(v_div),
    'manquants', (SELECT count(*) FROM jsonb_array_elements(v_div) d
                   WHERE d->>'divergence' = 'absent_du_socle'),
    'surnumeraires', (SELECT count(*) FROM jsonb_array_elements(v_div) d
                   WHERE d->>'divergence' = 'surnumeraire_dans_le_socle'),
    'details', v_div,
    'possessions_blob', v_pos_blob, 'possessions_socle', v_pos_socle,
    'possessions_divergences', jsonb_array_length(v_pos_div),
    'possessions_details', v_pos_div,
    'observation_liquide_total', v_liquide,
    'observation_liquide_non_nuls', v_liquide_non_nuls);
END; $$;

REVOKE ALL ON FUNCTION public.pnj_miroir_compagnie(text)  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_copier_soldats(text)    FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_comparer_soldats(text)  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.pnj_miroir_compagnie(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.pnj_copier_soldats(text)   TO service_role;
GRANT EXECUTE ON FUNCTION public.pnj_comparer_soldats(text) TO service_role;