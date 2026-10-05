-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260918092937
-- Nom original      : militaire_entree_zone_portee_ville
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-18 09:29:37 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 6b16020b884a9cf5f947dae41c1fa391
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
-- CORRECTIF DE PORTEE. militaire_bande_distance ne rend 'hors' que si les deux pays different --
-- or on lui passe le meme pays des deux cotes (elle compare des POSITIONS, pas des nationalites,
-- sans quoi deux ennemis seraient toujours 'hors' par construction). Consequence : AUCUN ennemi
-- n'etait jamais hors de portee, et une force a l'autre bout du pays etait sondee.
--
-- La detection PASSIVE s'arrete a la ville : on remarque des troupes la ou l'on est, on ne balaie
-- pas un empire en marchant. Les bandes longues restent le domaine de l'observation ACTIVE aux
-- jumelles (militaire_observer, 1 PA), qui elle est deja livree et ne change pas.
CREATE OR REPLACE FUNCTION public.militaire_entree_zone()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  c_bonus_jumelles constant integer := 30;
  v_moi text; v_pays text; v_ville text; v_bat text; v_piece text;
  v_jour text; v_zone text; v_cle text;
  v_reco numeric; v_jumelles boolean;
  v_mes_pnj integer; v_ma_reco numeric; v_mes_equipes integer; v_mon_effectif integer;
  v_militaire boolean; v_contacts jsonb := '[]'::jsonb; v_mutuels integer := 0;
  r record; v_bande text; v_modif integer;
  v_camo_eux numeric; v_camo_moi numeric;
  v_chance_moi integer; v_chance_eux integer; v_vu_par_moi boolean; v_vu_par_eux boolean;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT coalesce(country,'republic'), coalesce(current_city,''), coalesce(current_building,''),
         coalesce(current_room,''), coalesce((competences_militaires->>'reconnaissance')::numeric, 0),
         EXISTS (SELECT 1 FROM jsonb_array_elements(
                   CASE WHEN jsonb_typeof(inventory)='array' THEN inventory ELSE '[]'::jsonb END) i
                  WHERE i->>'produitMilitaire' = 'jumelles')
    INTO v_pays, v_ville, v_bat, v_piece, v_reco, v_jumelles
    FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;

  SELECT count(*)::integer,
         coalesce(avg(coalesce((sol->'formation'->>'reconnaissance')::numeric, 0)), 0),
         count(*) FILTER (WHERE EXISTS (
           SELECT 1 FROM jsonb_array_elements(
             CASE WHEN jsonb_typeof(sol->'accessoires')='array' THEN sol->'accessoires' ELSE '[]'::jsonb END) a
            WHERE a->>'produitMilitaire' = 'tenue_camouflage'))::integer
    INTO v_mes_pnj, v_ma_reco, v_mes_equipes
    FROM public.compagnies_militaires c,
         jsonb_array_elements(coalesce(c.data->'sections','[]'::jsonb)) s,
         jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol
   WHERE sol->>'leaderCourant' = v_moi;

  v_militaire := EXISTS (SELECT 1 FROM public.services_militaires sm
                          WHERE sm.personnage = v_moi AND sm.fin_ts IS NULL);

  IF coalesce(v_mes_pnj,0) = 0 AND NOT v_militaire THEN
    RETURN jsonb_build_object('ok', true, 'force', false, 'contacts', '[]'::jsonb);
  END IF;
  v_mon_effectif := coalesce(v_mes_pnj,0) + 1;

  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date::text;
  v_zone := v_pays || '/' || v_ville || '/' || v_bat || '/' || v_piece;
  v_cle  := v_moi || ':' || v_jour || ':' || v_zone;
  BEGIN
    INSERT INTO public.militaire_detections (id, personnage, jour, zone)
    VALUES (v_cle, v_moi, v_jour, v_zone);
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('ok', true, 'force', true, 'deja_sonde', true, 'contacts', '[]'::jsonb);
  END;

  FOR r IN
    SELECT c.data->>'pays' AS pays_cible,
           sol->>'ville' AS ville, sol->>'buildingId' AS bat, sol->>'roomId' AS piece,
           count(*)::integer AS effectif,
           avg(coalesce((sol->'formation'->>'reconnaissance')::numeric, 0)) AS reco_moy,
           count(*) FILTER (WHERE EXISTS (
             SELECT 1 FROM jsonb_array_elements(
               CASE WHEN jsonb_typeof(sol->'accessoires')='array' THEN sol->'accessoires' ELSE '[]'::jsonb END) a
              WHERE a->>'produitMilitaire' = 'tenue_camouflage'))::integer AS equipes,
           bool_or(EXISTS (
             SELECT 1 FROM jsonb_array_elements(
               CASE WHEN jsonb_typeof(sol->'accessoires')='array' THEN sol->'accessoires' ELSE '[]'::jsonb END) a
              WHERE a->>'produitMilitaire' = 'jumelles')) AS a_jumelles
      FROM public.compagnies_militaires c,
           jsonb_array_elements(coalesce(c.data->'sections','[]'::jsonb)) s,
           jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol
     WHERE c.data->>'pays' IS DISTINCT FROM v_pays
       -- PORTEE PASSIVE = LA VILLE OU JE SUIS. Au-dela, rien : pas de jet, pas de trace.
       AND sol->>'ville' = v_ville
       AND (sol->>'leaderCourant') IS NULL
       AND EXISTS (SELECT 1 FROM public.guerres g
                    WHERE g.statut = 'active'
                      AND ((g.data->>'attaquant' = v_pays AND g.data->>'attaque' = c.data->>'pays')
                        OR (g.data->>'attaque'  = v_pays AND g.data->>'attaquant' = c.data->>'pays')))
     GROUP BY 1, 2, 3, 4
  LOOP
    v_bande := public.militaire_bande_distance(v_pays, v_ville, v_bat, v_pays, r.ville, r.bat);
    v_modif := public.militaire_modif_distance(v_bande);
    CONTINUE WHEN v_modif IS NULL;

    v_camo_eux := public.militaire_camouflage_groupe(r.reco_moy, r.effectif, r.equipes);
    v_camo_moi := public.militaire_camouflage_groupe(v_ma_reco, v_mon_effectif, v_mes_equipes);

    v_chance_moi := public.militaire_chance_detection(
      v_reco, v_camo_eux, v_modif, CASE WHEN v_jumelles THEN c_bonus_jumelles ELSE 0 END);
    v_chance_eux := public.militaire_chance_detection(
      r.reco_moy, v_camo_moi, v_modif, CASE WHEN coalesce(r.a_jumelles,false) THEN c_bonus_jumelles ELSE 0 END);

    v_vu_par_moi := (floor(random() * 100)::integer + 1) <= v_chance_moi;
    v_vu_par_eux := (floor(random() * 100)::integer + 1) <= v_chance_eux;

    IF v_vu_par_moi THEN
      v_contacts := v_contacts || jsonb_build_array(
        public.militaire_degrader(v_bande, r.effectif, r.pays_cible, r.ville, r.bat));
    END IF;

    IF v_vu_par_moi AND v_vu_par_eux THEN
      INSERT INTO public.contacts_militaires (pays_a, pays_b, ville, batiment, piece, effectif_a, effectif_b)
      VALUES (v_pays, r.pays_cible, r.ville, r.bat, r.piece, v_mon_effectif, r.effectif);
      v_mutuels := v_mutuels + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'force', true, 'effectif', v_mon_effectif,
    'reconnaissance', v_reco, 'jumelles', v_jumelles,
    'contacts', v_contacts, 'contacts_mutuels', v_mutuels);
END;
$$;

REVOKE ALL ON FUNCTION public.militaire_entree_zone() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_entree_zone() TO authenticated;