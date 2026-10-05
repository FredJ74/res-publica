-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260926144120
-- Nom original      : socle_pnj_metier_mutin
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-26 14:41:20 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : b72bf7d08b24bcc13bafa89b5ee39ece
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
-- LE CHAMP `mutin` MONTE DANS LA TABLE METIER MILITAIRE -- 26 septembre 2026.
--
-- POURQUOI. Trois des sept lectures restantes le lisent :
--   mutinerie_camps_presents  : camp = coalesce(sol->>'mutin', compagnie.pays)
--   militaire_bataille_engager, militaire_bataille_recruter : filtrent dessus
-- Or je ne l'avais PAS copie : pnj_soldats_metier n'avait que matricule, section, reserve,
-- arme et formation. Sans lui, basculer ces trois lectures produirait une semantique FAUSSE
-- des qu'une mutinerie aurait lieu -- pas aujourd'hui (0 soldat le porte en production), mais
-- des le premier soulevement. Une equivalence vraie aujourd'hui et fausse demain n'est pas une
-- equivalence.
--
-- OU IL VA. Dans la table METIER, pas dans le socle : « mutin » designe le camp d'un soldat
-- revolte, c'est une notion purement militaire. Le socle n'a pas a la connaitre.
--
-- NULL = loyal. C'est exactement la convention du blob, ou la cle est absente tant que le
-- soldat n'a pas mutine, et ou le camp se lit coalesce(mutin, pays de la compagnie).

ALTER TABLE public.pnj_soldats_metier ADD COLUMN IF NOT EXISTS mutin text;

COMMENT ON COLUMN public.pnj_soldats_metier.mutin IS
  'Camp d''un soldat revolte. NULL = loyal, et le camp effectif se lit alors '
  'coalesce(mutin, pays de la compagnie) -- convention reprise telle quelle du blob. '
  'Donnee purement militaire : elle n''a pas sa place dans pnj_membres.';

-- Le miroir doit desormais le porter. On recree la fonction en entier : une substitution
-- textuelle sur deux INSERT distincts serait plus fragile que de reecrire.
CREATE OR REPLACE FUNCTION public.pnj_miroir_compagnie(p_compagnie text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $fn$
DECLARE c record; v_pays text; v_vus text[] := '{}'; v_sup integer := 0; v_maj integer := 0;
        s jsonb; sol jsonb; v_id text; v_sec text;
BEGIN
  SELECT * INTO c FROM public.compagnies_militaires WHERE id = p_compagnie;
  IF c.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;
  v_pays := c.data->>'pays';

  FOR s IN SELECT value FROM jsonb_array_elements(COALESCE(c.data->'sections','[]'::jsonb)) LOOP
    v_sec := s->>'id';
    FOR sol IN SELECT value FROM jsonb_array_elements(COALESCE(s->'soldats','[]'::jsonb)) LOOP
      CONTINUE WHEN COALESCE((sol->>'pj')::boolean, false) IS TRUE;
      v_id := p_compagnie || '-' || (sol->>'matricule');
      v_vus := v_vus || v_id;
      INSERT INTO public.pnj_membres (id, famille, nom, pays, proprietaire_poste,
          leader_pj, ville, building_id, room_id, pa, statut)
      VALUES (v_id, 'soldat', COALESCE(sol->>'matricule','?'), v_pays, 'lieutenant',
          sol->>'leaderCourant', sol->>'ville', sol->>'buildingId', sol->>'roomId',
          COALESCE((sol->>'pa')::integer, 12), 'actif')
      ON CONFLICT (id) DO UPDATE SET
          leader_pj = EXCLUDED.leader_pj, ville = EXCLUDED.ville,
          building_id = EXCLUDED.building_id, room_id = EXCLUDED.room_id,
          pa = EXCLUDED.pa, maj_le = now();
      INSERT INTO public.pnj_soldats_metier (pnj_id, matricule, section_id, en_reserve,
          arme, formation, mutin)
      VALUES (v_id, sol->>'matricule', v_sec, false, sol->>'arme',
              COALESCE(sol->'formation','{}'::jsonb), sol->>'mutin')
      ON CONFLICT (pnj_id) DO UPDATE SET
          section_id = EXCLUDED.section_id, en_reserve = EXCLUDED.en_reserve,
          arme = EXCLUDED.arme, formation = EXCLUDED.formation, mutin = EXCLUDED.mutin;
      v_maj := v_maj + 1;
    END LOOP;
  END LOOP;

  FOR sol IN SELECT value FROM jsonb_array_elements(COALESCE(c.data->'reserve','[]'::jsonb)) LOOP
    v_id := p_compagnie || '-' || (sol->>'matricule');
    v_vus := v_vus || v_id;
    INSERT INTO public.pnj_membres (id, famille, nom, pays, proprietaire_poste,
        leader_pj, ville, building_id, room_id, pa, statut)
    VALUES (v_id, 'soldat', COALESCE(sol->>'matricule','?'), v_pays, 'lieutenant',
        sol->>'leaderCourant', sol->>'ville', sol->>'buildingId', sol->>'roomId',
        COALESCE((sol->>'pa')::integer, 12), 'actif')
    ON CONFLICT (id) DO UPDATE SET
        leader_pj = EXCLUDED.leader_pj, ville = EXCLUDED.ville,
        building_id = EXCLUDED.building_id, room_id = EXCLUDED.room_id,
        pa = EXCLUDED.pa, maj_le = now();
    INSERT INTO public.pnj_soldats_metier (pnj_id, matricule, section_id, en_reserve,
        arme, formation, mutin)
    VALUES (v_id, sol->>'matricule', NULL, true, sol->>'arme',
            COALESCE(sol->'formation','{}'::jsonb), sol->>'mutin')
    ON CONFLICT (pnj_id) DO UPDATE SET
        section_id = NULL, en_reserve = true,
        arme = EXCLUDED.arme, formation = EXCLUDED.formation, mutin = EXCLUDED.mutin;
    v_maj := v_maj + 1;
  END LOOP;

  DELETE FROM public.pnj_membres
   WHERE id LIKE p_compagnie || '-%' AND NOT (id = ANY(v_vus));
  GET DIAGNOSTICS v_sup = ROW_COUNT;
  RETURN jsonb_build_object('ok', true, 'synchronises', v_maj, 'supprimes', v_sup);
END; $fn$;

-- Le comparateur doit comparer `mutin` lui aussi, sinon une divergence sur ce champ passerait
-- inapercue -- ce qui viderait de son sens la garantie « 0 divergence ».
CREATE OR REPLACE FUNCTION public.pnj_comparer_soldats(p_compagnie text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $fn$
DECLARE v_div jsonb; v_nb_blob integer; v_nb_socle integer;
BEGIN
  WITH blob AS (
    SELECT sol->>'matricule' AS matricule, sol->>'leaderCourant' AS leader,
           sol->>'ville' AS ville, sol->>'buildingId' AS bat, sol->>'roomId' AS room,
           (sol->>'pa')::integer AS pa, sol->>'arme' AS arme,
           COALESCE(sol->'formation','{}'::jsonb) AS formation,
           false AS en_reserve, s->>'id' AS section_id, sol->>'mutin' AS mutin
      FROM public.compagnies_militaires c,
           jsonb_array_elements(COALESCE(c.data->'sections','[]'::jsonb)) s,
           jsonb_array_elements(COALESCE(s->'soldats','[]'::jsonb)) sol
     WHERE c.id = p_compagnie AND COALESCE((sol->>'pj')::boolean, false) = false
    UNION ALL
    SELECT r->>'matricule', r->>'leaderCourant', r->>'ville', r->>'buildingId', r->>'roomId',
           (r->>'pa')::integer, r->>'arme', COALESCE(r->'formation','{}'::jsonb), true, NULL,
           r->>'mutin'
      FROM public.compagnies_militaires c,
           jsonb_array_elements(COALESCE(c.data->'reserve','[]'::jsonb)) r
     WHERE c.id = p_compagnie
  ), socle AS (
    SELECT sm.matricule, m.leader_pj AS leader, m.ville, m.building_id AS bat,
           m.room_id AS room, m.pa, sm.arme, sm.formation, sm.en_reserve, sm.section_id,
           sm.mutin, m.proprietaire_poste, m.statut
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
        WHEN s.proprietaire_poste IS DISTINCT FROM 'lieutenant' THEN 'proprietaire'
        WHEN s.statut IS DISTINCT FROM 'actif' THEN 'statut'
        ELSE NULL END AS divergence
      FROM blob b FULL OUTER JOIN socle s ON s.matricule = b.matricule
  )
  SELECT (SELECT count(*) FROM blob), (SELECT count(*) FROM socle),
         COALESCE(jsonb_agg(jsonb_build_object('matricule', matricule, 'divergence', divergence)
                            ORDER BY matricule) FILTER (WHERE divergence IS NOT NULL), '[]'::jsonb)
    INTO v_nb_blob, v_nb_socle, v_div FROM compare;

  RETURN jsonb_build_object(
    'ok', jsonb_array_length(v_div) = 0 AND v_nb_blob = v_nb_socle,
    'nb_blob', v_nb_blob, 'nb_socle', v_nb_socle,
    'correspondances', v_nb_blob - jsonb_array_length(v_div),
    'nb_divergences', jsonb_array_length(v_div),
    'manquants', (SELECT count(*) FROM jsonb_array_elements(v_div) d
                   WHERE d->>'divergence' = 'absent_du_socle'),
    'surnumeraires', (SELECT count(*) FROM jsonb_array_elements(v_div) d
                   WHERE d->>'divergence' = 'surnumeraire_dans_le_socle'),
    'details', v_div);
END; $fn$;