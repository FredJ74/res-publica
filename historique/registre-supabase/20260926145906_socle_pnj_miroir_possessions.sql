-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260926145906
-- Nom original      : socle_pnj_miroir_possessions
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-26 14:59:06 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 4261e70810c4f83559e052f7bdb397dc
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
-- LE MIROIR PORTE DESORMAIS LES POSSESSIONS -- 26 septembre 2026.
--
-- Il est DIFFERENTIEL, pas destructif-reconstructif : un objet inchange garde sa ligne et donc
-- son id. Ce n'est pas de la coquetterie -- pnj_possessions_lire numerote les objets par ordre
-- d'id, et pnj_objet_transferer('retirer') les designe par cet index. Un miroir qui recreerait
-- tout a chaque passe ferait glisser les index entre la lecture et l'ecriture.
--
-- Il ne touche JAMAIS les lignes d'origine 'socle' : ce sont les objets qu'un joueur a donnes,
-- que le blob ne connait pas et n'a pas a arbitrer.
--
-- Comme cette fonction est appelee par le declencheur sur compagnies_militaires, les DEUX
-- ecritures de `accessoires` sont couvertes sans les toucher :
--   militaire_equiper_accessoire  (client, equipe un accessoire)
--   militaire_gilet_absorber      (serveur, consomme un gilet)
-- L'appeler une fois a la main REALISE la migration : elle est idempotente par construction.

CREATE OR REPLACE FUNCTION public.pnj_miroir_compagnie(p_compagnie text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $fn$
DECLARE c record; v_pays text; v_vus text[] := '{}'; v_sup integer := 0; v_maj integer := 0;
        s jsonb; sol jsonb; v_id text; v_sec text;
        v_pos_ins integer := 0; v_pos_sup integer := 0; v_n integer;
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
      SELECT a.ins, a.sup INTO v_n, v_n FROM public.pnj_miroir_possessions(v_id,
        CASE WHEN jsonb_typeof(sol->'accessoires')='array' THEN sol->'accessoires' ELSE '[]'::jsonb END) a;
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
    PERFORM public.pnj_miroir_possessions(v_id,
      CASE WHEN jsonb_typeof(sol->'accessoires')='array' THEN sol->'accessoires' ELSE '[]'::jsonb END);
  END LOOP;

  DELETE FROM public.pnj_membres
   WHERE id LIKE p_compagnie || '-%' AND NOT (id = ANY(v_vus));
  GET DIAGNOSTICS v_sup = ROW_COUNT;
  RETURN jsonb_build_object('ok', true, 'synchronises', v_maj, 'supprimes', v_sup);
END; $fn$;

-- Synchronisation DIFFERENTIELLE des possessions d'un PNJ depuis un tableau d'accessoires.
-- Ne touche que les lignes d'origine 'blob_accessoires'.
CREATE OR REPLACE FUNCTION public.pnj_miroir_possessions(p_pnj_id text, p_accessoires jsonb)
RETURNS TABLE(ins integer, sup integer)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $fn$
DECLARE v_ins integer := 0; v_sup integer := 0;
BEGIN
  -- Ce qui a disparu du blob disparait du socle. Comparaison par texte de l'objet ENTIER et par
  -- rang d'occurrence, pour gerer correctement deux exemplaires identiques.
  WITH voulu AS (
    SELECT a::text AS cle, row_number() OVER (PARTITION BY a::text) AS occ
      FROM jsonb_array_elements(COALESCE(p_accessoires,'[]'::jsonb)) a),
  present AS (
    SELECT p.id, p.objet::text AS cle, row_number() OVER (PARTITION BY p.objet::text ORDER BY p.id) AS occ
      FROM public.pnj_possessions p
     WHERE p.pnj_id = p_pnj_id AND p.origine = 'blob_accessoires'),
  a_supprimer AS (
    SELECT pr.id FROM present pr
     WHERE NOT EXISTS (SELECT 1 FROM voulu v WHERE v.cle = pr.cle AND v.occ = pr.occ))
  DELETE FROM public.pnj_possessions p USING a_supprimer d WHERE p.id = d.id;
  GET DIAGNOSTICS v_sup = ROW_COUNT;

  -- Ce qui est apparu dans le blob apparait dans le socle, objet COMPLET, sans reconstruction.
  WITH voulu AS (
    SELECT a AS objet, a::text AS cle, row_number() OVER (PARTITION BY a::text) AS occ
      FROM jsonb_array_elements(COALESCE(p_accessoires,'[]'::jsonb)) a),
  present AS (
    SELECT p.objet::text AS cle, row_number() OVER (PARTITION BY p.objet::text ORDER BY p.id) AS occ
      FROM public.pnj_possessions p
     WHERE p.pnj_id = p_pnj_id AND p.origine = 'blob_accessoires')
  INSERT INTO public.pnj_possessions (pnj_id, objet, exemplaire_unique, origine)
  SELECT p_pnj_id, v.objet,
         COALESCE((v.objet->>'usageUnique')::boolean, false),
         'blob_accessoires'
    FROM voulu v
   WHERE NOT EXISTS (SELECT 1 FROM present pr WHERE pr.cle = v.cle AND pr.occ = v.occ);
  GET DIAGNOSTICS v_ins = ROW_COUNT;

  RETURN QUERY SELECT v_ins, v_sup;
END; $fn$;

REVOKE ALL ON FUNCTION public.pnj_miroir_possessions(text, jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.pnj_miroir_possessions(text, jsonb) TO service_role;