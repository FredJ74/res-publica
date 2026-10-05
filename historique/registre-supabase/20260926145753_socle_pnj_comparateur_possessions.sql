-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260926145753
-- Nom original      : socle_pnj_comparateur_possessions
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-26 14:57:53 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 07aecc8d03ceb61d8b7edebcbfdb4557
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
-- LE COMPARATEUR COMPARE DESORMAIS LES POSSESSIONS -- 26 septembre 2026.
-- Applique AVANT la migration, exprès : on veut qu'il DETECTE le trou connu avant qu'on le
-- comble. Un comparateur etendu apres coup ne prouverait rien.
--
-- UNE DISTINCTION NECESSAIRE, ET CE N'EST PAS UNE REGLE INVENTEE. Pendant la phase miroir,
-- deux sources alimentent les possessions d'un soldat :
--   * `accessoires` du blob -- equipement militaire, ecrit par militaire_equiper_accessoire et
--     consomme par militaire_gilet_absorber. Le blob en est l'autorite.
--   * pnj_possessions ecrit par pnj_objet_transferer -- ce qu'un joueur vient de DONNER depuis
--     son inventaire. Le blob ne le connait pas et ne le connaitra jamais : c'est une capacite
--     neuve du socle.
-- Comparer l'ensemble complet contre `accessoires` declarerait donc « surnumeraire » tout objet
-- legitimement donne par un joueur. On marque l'origine, et le comparateur ne confronte que le
-- sous-ensemble d'origine blob. A la bascule d'autorite, cette colonne deviendra inutile.

ALTER TABLE public.pnj_possessions
  ADD COLUMN IF NOT EXISTS origine text NOT NULL DEFAULT 'socle';

ALTER TABLE public.pnj_possessions
  DROP CONSTRAINT IF EXISTS pnj_possessions_origine_connue;
ALTER TABLE public.pnj_possessions
  ADD CONSTRAINT pnj_possessions_origine_connue
  CHECK (origine IN ('socle','blob_accessoires'));

COMMENT ON COLUMN public.pnj_possessions.origine IS
  '''blob_accessoires'' = objet miroite depuis compagnies_militaires.data...accessoires, dont le '
  'blob reste l''autorite pendant la phase transitoire. ''socle'' = objet donne par un joueur via '
  'pnj_objet_transferer, que le blob ne connait pas. Le comparateur ne confronte au blob que le '
  'premier sous-ensemble. Colonne destinee a disparaitre a la bascule d''autorite.';

-- Comparateur etendu : les 13 axes precedents, PLUS les possessions d'origine blob.
CREATE OR REPLACE FUNCTION public.pnj_comparer_soldats(p_compagnie text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $fn$
DECLARE v_div jsonb; v_nb_blob integer; v_nb_socle integer;
        v_pos_blob integer; v_pos_socle integer; v_pos_div jsonb;
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
    'possessions_details', v_pos_div);
END; $fn$;