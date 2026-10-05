-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260917231620
-- Nom original      : militaire_observer_jumelles
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-17 23:16:20 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : ffddba4b194b7443c843c5bc6dafa629
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
-- ==========================================================================================
-- ORDRE « OBSERVER » — jumelles, 1 PA, bonus +30 a la reconnaissance
--
-- SNAPSHOT, pas radar : chaque appel est un jet independant, il n'existe aucun suivi permanent.
--
-- LE SERVEUR NE RENVOIE QUE DU RENSEIGNEMENT DEJA DEGRADE. Les effectifs et positions exacts ne
-- quittent jamais la base : les masquer graphiquement cote client les rendrait recuperables.
--
-- UN ECHEC NE RENVOIE RIEN DU TOUT -- pas meme le nombre de forces manquees. On ne revele jamais,
-- meme implicitement, l'existence de ce qui n'a pas ete detecte.
-- ==========================================================================================
CREATE OR REPLACE FUNCTION public.militaire_observer()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE
  c_pa constant integer := 1;
  c_bonus_jumelles constant integer := 30;
  v_moi text; v_pays text; v_ville text; v_bat text; v_pa integer; v_reco numeric;
  v_a_jumelles boolean; v_contacts jsonb := '[]'::jsonb;
  r record; v_bande text; v_modif integer; v_camo numeric; v_chance integer; v_jet integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT coalesce(country,'republic'), coalesce(current_city,''), coalesce(current_building,''),
         coalesce(pa,0), coalesce((competences_militaires->>'reconnaissance')::numeric, 0),
         EXISTS (SELECT 1 FROM jsonb_array_elements(
                   CASE WHEN jsonb_typeof(inventory)='array' THEN inventory ELSE '[]'::jsonb END) i
                  WHERE i->>'produitMilitaire' = 'jumelles')
    INTO v_pays, v_ville, v_bat, v_pa, v_reco, v_a_jumelles
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_pays IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  IF NOT v_a_jumelles THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_jumelles'); END IF;
  IF v_pa < c_pa THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants', 'requis', c_pa);
  END IF;

  UPDATE public.personnages_donnees SET pa = v_pa - c_pa WHERE name = v_moi;

  -- Forces ENNEMIES : sections d'une compagnie dont le pays est en guerre ACTIVE avec le mien,
  -- et dont des soldats ont une position reelle (ceux qui suivent un chef n'en ont pas).
  FOR r IN
    SELECT c.data->>'pays' AS pays_cible,
           sol->>'ville' AS ville, sol->>'buildingId' AS bat,
           count(*)::integer AS effectif,
           avg(coalesce((sol->'formation'->>'reconnaissance')::numeric, 0)) AS reco_moy,
           count(*) FILTER (WHERE EXISTS (
             SELECT 1 FROM jsonb_array_elements(
               CASE WHEN jsonb_typeof(sol->'accessoires')='array' THEN sol->'accessoires' ELSE '[]'::jsonb END) a
              WHERE a->>'produitMilitaire' = 'tenue_camouflage'))::integer AS equipes
      FROM public.compagnies_militaires c,
           jsonb_array_elements(coalesce(c.data->'sections','[]'::jsonb)) s,
           jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol
     WHERE c.data->>'pays' IS DISTINCT FROM v_pays
       AND coalesce(sol->>'ville','') <> ''
       AND EXISTS (SELECT 1 FROM public.guerres g
                    WHERE g.statut = 'active'
                      AND ((g.data->>'attaquant' = v_pays AND g.data->>'attaque' = c.data->>'pays')
                        OR (g.data->>'attaque'  = v_pays AND g.data->>'attaquant' = c.data->>'pays')))
     GROUP BY 1, 2, 3
  LOOP
    v_bande := public.militaire_bande_distance(v_pays, v_ville, v_bat, v_pays, r.ville, r.bat);
    v_modif := public.militaire_modif_distance(v_bande);
    -- Hors bande : les jumelles ne donnent qu'un signe de vie, et seulement si le jet passe.
    IF v_modif IS NULL THEN v_modif := -60; END IF;
    v_camo := public.militaire_camouflage_groupe(r.reco_moy, r.effectif, r.equipes);
    v_chance := public.militaire_chance_detection(v_reco, v_camo, v_modif, c_bonus_jumelles);
    v_jet := floor(random() * 100)::integer + 1;
    -- ECHEC : on n'ajoute RIEN. Pas de trace, pas de compteur, pas d'indice.
    CONTINUE WHEN v_jet > v_chance;
    v_contacts := v_contacts || jsonb_build_array(
      public.militaire_degrader(CASE WHEN v_modif = -60 THEN 'limite' ELSE v_bande END,
                                r.effectif, r.pays_cible, r.ville, r.bat));
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'pa_restants', v_pa - c_pa,
    'reconnaissance', v_reco, 'contacts', v_contacts);
END; $fn$;
REVOKE ALL ON FUNCTION public.militaire_observer() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_observer() TO authenticated, service_role;