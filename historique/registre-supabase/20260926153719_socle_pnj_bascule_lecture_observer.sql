-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260926153719
-- Nom original      : socle_pnj_bascule_lecture_observer
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-26 15:37:19 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : caa77666861bede97328b962e5f4f749
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
-- BASCULE DE LECTURE : militaire_observer lit le socle. 26 septembre 2026.
--
-- SEMANTIQUE CONSERVEE : « avec des jumelles, pour 1 PA, reperer les forces ENNEMIES ayant une
-- position reelle ». Regroupement par (pays, ville, batiment), et pour chaque groupe :
-- effectif, reconnaissance moyenne, nombre d'hommes en tenue de camouflage.
--
-- SUBTILITE DECISIVE, et elle va a l'encontre du reflexe : cette lecture ne veut PAS la position
-- effective. Elle exige `coalesce(sol->>'ville','') <> ''`, c'est-a-dire une position PROPRE.
-- Un soldat qui suit un chef n'en a pas et est donc volontairement INVISIBLE aux jumelles --
-- on ne repere pas une troupe en mouvement derriere son officier comme un campement. Utiliser
-- pnj_position_effective ici aurait donc AJOUTE des cibles : ce serait un changement de
-- gameplay. On lit les colonnes propres, sans passer par la primitive.
--
-- FILTRES METIER CONSERVES :
--   * SECTIONS SEULEMENT -- en_reserve = false ;
--   * position propre non nulle -- l'equivalent exact de ville <> '' ;
--   * pays different du mien, et guerre ACTIVE entre les deux -- inchange ;
--   * camouflage : compte les porteurs de produitMilitaire = 'tenue_camouflage'.
--
-- LE CAMOUFLAGE EST COMPTE SUR origine = 'blob_accessoires' UNIQUEMENT, et c'est volontaire.
-- L'ancienne lecture ne voyait que `accessoires`. Une tenue DONNEE par un joueur arrive dans
-- pnj_possessions avec origine 'socle' : la compter maintenant ferait entrer dans le calcul de
-- detection un objet que le code historique ignorait -- un changement de gameplay que je n'ai
-- pas a decider. La restriction tombera d'elle-meme a la bascule d'autorite, quand la colonne
-- origine disparaitra.

CREATE OR REPLACE FUNCTION public.militaire_observer()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
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

  FOR r IN
    SELECT m.pays AS pays_cible, m.ville, m.building_id AS bat,
           count(*)::integer AS effectif,
           avg(coalesce((sm.formation->>'reconnaissance')::numeric, 0)) AS reco_moy,
           count(*) FILTER (WHERE EXISTS (
             SELECT 1 FROM public.pnj_possessions p
              WHERE p.pnj_id = m.id AND p.origine = 'blob_accessoires'
                AND p.objet->>'produitMilitaire' = 'tenue_camouflage'))::integer AS equipes
      FROM public.pnj_membres m
      JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
     WHERE m.famille = 'soldat'
       AND m.statut  = 'actif'
       AND sm.en_reserve = false
       AND m.pays IS DISTINCT FROM v_pays
       AND coalesce(m.ville,'') <> ''
       AND EXISTS (SELECT 1 FROM public.guerres g
                    WHERE g.statut = 'active'
                      AND ((g.data->>'attaquant' = v_pays AND g.data->>'attaque' = m.pays)
                        OR (g.data->>'attaque'  = v_pays AND g.data->>'attaquant' = m.pays)))
     GROUP BY 1, 2, 3
  LOOP
    v_bande := public.militaire_bande_distance(v_pays, v_ville, v_bat, v_pays, r.ville, r.bat);
    v_modif := public.militaire_modif_distance(v_bande);
    IF v_modif IS NULL THEN v_modif := -60; END IF;
    v_camo := public.militaire_camouflage_groupe(r.reco_moy, r.effectif, r.equipes);
    v_chance := public.militaire_chance_detection(v_reco, v_camo, v_modif, c_bonus_jumelles);
    v_jet := floor(random() * 100)::integer + 1;
    CONTINUE WHEN v_jet > v_chance;
    v_contacts := v_contacts || jsonb_build_array(
      public.militaire_degrader(CASE WHEN v_modif = -60 THEN 'limite' ELSE v_bande END,
                                r.effectif, r.pays_cible, r.ville, r.bat));
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'pa_restants', v_pa - c_pa,
    'reconnaissance', v_reco, 'contacts', v_contacts);
END; $function$;