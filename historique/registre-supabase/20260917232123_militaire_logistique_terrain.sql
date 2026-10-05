-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260917232123
-- Nom original      : militaire_logistique_terrain
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-17 23:21:23 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 0588575eb27ef56ea6c637bef4b79e6e
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
-- LOGISTIQUE DE TERRAIN : rations, bivouac, et commandement par radio
--
-- UN SEUL ORDRE COLLECTIF pour deux actions, parce qu'elles partagent tout : meme groupe cible,
-- meme garde quotidienne, meme atomicite, meme condition de radio a distance. Les dupliquer aurait
-- produit deux moteurs a maintenir.
--
-- LA RATION EST UN VRAI OBJET, tiree du stock EXISTANT du refectoire -- celui que
-- refectoire_repas fabrique deja par lots de 10 a partir d'1 cereale + 1 viande OU poisson.
-- Aucune recette nouvelle n'est inventee : on reutilise la filiere alimentaire en place.
--
-- LE LEADER PORTE LES RATIONS DE SON GROUPE : elles sortent de SON inventaire, une par soldat.
-- C'est la seule lecture coherente avec un groupe de PNJ qui n'a pas d'inventaire propre.
--
-- GARDE QUOTIDIENNE : date reelle Europe/Paris, la convention serveur canonique du projet (celle
-- du refectoire et des soldes). Aucun nouveau moteur de journee.
--
-- ATOMICITE COLLECTIVE : si les ressources ne couvrent pas TOUT le groupe, l'ordre est refuse en
-- entier. Jamais de bonus accorde sans consommation reelle, jamais de consommation partielle.
--
-- DOUBLE RADIO pour commander a distance : le Lieutenant ET le chef du groupe doivent chacun en
-- porter une. La radio est un relais de commandement, jamais une teleportation.
-- ==========================================================================================

-- Retrait de rations de combat, sur le stock du refectoire. Objet reel, une unite par ration.
CREATE OR REPLACE FUNCTION public.militaire_rations_retirer(p_nombre integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE
  c_plafond constant integer := 100;
  v_moi text; v_pays text; v_bat text; v_inv jsonb; v_occupe numeric;
  v_data jsonb; v_ref jsonb; v_dispo integer; v_n integer; i integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_n := greatest(0, coalesce(p_nombre, 0));
  IF v_n = 0 OR v_n > 50 THEN RETURN jsonb_build_object('ok', false, 'raison', 'nombre_invalide'); END IF;

  SELECT coalesce(country,'republic'), coalesce(current_building,''),
         CASE WHEN jsonb_typeof(inventory)='array' THEN inventory ELSE '[]'::jsonb END
    INTO v_pays, v_bat, v_inv FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_bat <> 'caserne-militaire' THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;

  SELECT coalesce(sum(greatest(1, coalesce((i2->>'qty')::numeric, (i2->>'encombrement')::numeric, 1))), 0)
    INTO v_occupe FROM jsonb_array_elements(v_inv) i2;
  IF v_occupe + v_n > c_plafond THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein', 'plafond', c_plafond);
  END IF;

  SELECT data INTO v_data FROM public.budgets_nationaux WHERE id = v_pays FOR UPDATE;
  v_ref := CASE WHEN jsonb_typeof(v_data->'refectoire')='object' THEN v_data->'refectoire' ELSE '{}'::jsonb END;
  v_dispo := greatest(0, coalesce((v_ref->>'rations')::integer, 0));
  IF v_dispo < v_n THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'rations_insuffisantes', 'disponibles', v_dispo);
  END IF;

  UPDATE public.budgets_nationaux
     SET data = v_data || jsonb_build_object('refectoire', v_ref || jsonb_build_object('rations', v_dispo - v_n)),
         updated_at = now()
   WHERE id = v_pays;

  FOR i IN 1 .. v_n LOOP
    v_inv := v_inv || jsonb_build_array(jsonb_build_object(
      'id', 'mil-' || replace(gen_random_uuid()::text, '-', ''),
      'type', 'vivres', 'sousType', 'militaire', 'produitMilitaire', 'ration_combat',
      'origineMilitaire', true, 'usageUnique', true,
      'name', 'Ration de combat', 'icon', 'ti-soup', 'legal', true, 'imageUrl', NULL,
      'desc', 'Ration de combat. Consommee sur le terrain : +1 PA par jour.'));
  END LOOP;
  UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = v_moi;

  RETURN jsonb_build_object('ok', true, 'retirees', v_n, 'restantes', v_dispo - v_n);
END; $fn$;
REVOKE ALL ON FUNCTION public.militaire_rations_retirer(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_rations_retirer(integer) TO authenticated, service_role;


-- ---- Ordre collectif : nourrir ou faire bivouaquer un groupe ----
CREATE OR REPLACE FUNCTION public.militaire_ordre_collectif(
  p_compagnie_id text, p_section_id text, p_action text, p_leader text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE
  c_capacite_tente constant integer := 13;
  c_gain constant integer := 1;
  c_pa_max_pnj constant integer := 12;
  v_moi text; v_data jsonb; v_sec jsonb; v_sols jsonb; v_leader text;
  v_jour text; v_n integer; v_tentes integer; v_requis integer;
  v_rations integer; v_inv jsonb; v_pos integer; i integer;
  v_a_distance boolean := false; v_radio_chef boolean; v_radio_leader boolean;
BEGIN
  IF p_action NOT IN ('ration', 'bivouac') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'action_invalide');
  END IF;
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = p_compagnie_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;
  SELECT s INTO v_sec FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb)) s
   WHERE s->>'id' = p_section_id;
  IF v_sec IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'section_introuvable'); END IF;

  -- Le groupe vise : celui mene par p_leader, ou par l'acteur lui-meme par defaut.
  v_leader := coalesce(nullif(btrim(coalesce(p_leader,'')), ''), v_moi);

  -- AUTORITE : le Lieutenant structurel, ou le leader operationnel pour SON propre groupe.
  IF v_sec->>'lieutenantNom' = v_moi THEN
    v_a_distance := (v_leader <> v_moi);
  ELSIF v_leader = v_moi THEN
    NULL;   -- un leader operationnel commande le groupe qu'il mene physiquement
  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
  END IF;

  -- DOUBLE RADIO obligatoire pour commander a distance. Relais de commandement, pas teleportation.
  IF v_a_distance THEN
    SELECT EXISTS (SELECT 1 FROM public.personnages_donnees pd,
             jsonb_array_elements(CASE WHEN jsonb_typeof(pd.inventory)='array' THEN pd.inventory ELSE '[]'::jsonb END) i2
             WHERE pd.name = v_moi AND i2->>'produitMilitaire' = 'radio') INTO v_radio_chef;
    SELECT EXISTS (SELECT 1 FROM public.personnages_donnees pd,
             jsonb_array_elements(CASE WHEN jsonb_typeof(pd.inventory)='array' THEN pd.inventory ELSE '[]'::jsonb END) i2
             WHERE pd.name = v_leader AND i2->>'produitMilitaire' = 'radio') INTO v_radio_leader;
    IF NOT coalesce(v_radio_chef,false) OR NOT coalesce(v_radio_leader,false) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'radio_manquante',
        'radio_lieutenant', coalesce(v_radio_chef,false), 'radio_leader', coalesce(v_radio_leader,false));
    END IF;
  END IF;

  v_sols := CASE WHEN jsonb_typeof(v_sec->'soldats')='array' THEN v_sec->'soldats' ELSE '[]'::jsonb END;
  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date::text;

  -- Soldats PNJ menes par ce leader, qui n'ont pas deja recu ce bonus aujourd'hui.
  SELECT count(*) INTO v_n FROM jsonb_array_elements(v_sols) sol
   WHERE NOT coalesce((sol->>'pj')::boolean,false)
     AND sol->>'leaderCourant' = v_leader
     AND coalesce(sol->>('dernier_' || p_action), '') <> v_jour;
  IF v_n = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_soldat_concerne');
  END IF;

  -- RESSOURCES, verifiees pour TOUT le groupe avant la moindre ecriture.
  SELECT CASE WHEN jsonb_typeof(inventory)='array' THEN inventory ELSE '[]'::jsonb END
    INTO v_inv FROM public.personnages_donnees WHERE name = v_leader FOR UPDATE;
  IF p_action = 'ration' THEN
    SELECT count(*) INTO v_rations FROM jsonb_array_elements(v_inv) i2
     WHERE i2->>'produitMilitaire' = 'ration_combat';
    IF v_rations < v_n THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'rations_insuffisantes',
        'requis', v_n, 'disponibles', v_rations);
    END IF;
  ELSE
    SELECT count(*) INTO v_tentes FROM jsonb_array_elements(v_inv) i2
     WHERE i2->>'produitMilitaire' = 'tente';
    v_requis := ceil(v_n::numeric / c_capacite_tente)::integer;
    IF coalesce(v_tentes,0) < v_requis THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'tentes_insuffisantes',
        'requis', v_requis, 'disponibles', coalesce(v_tentes,0), 'capacite_tente', c_capacite_tente);
    END IF;
  END IF;

  -- Application : +1 PA a chaque soldat concerne, marqueur du jour pose, plafond respecte.
  SELECT coalesce(jsonb_agg(
           CASE WHEN NOT coalesce((sol->>'pj')::boolean,false)
                     AND sol->>'leaderCourant' = v_leader
                     AND coalesce(sol->>('dernier_' || p_action), '') <> v_jour
                THEN sol || jsonb_build_object(
                       'pa', least(c_pa_max_pnj, coalesce((sol->>'pa')::numeric, 0) + c_gain),
                       'dernier_' || p_action, v_jour)
                ELSE sol END ORDER BY pos), '[]'::jsonb)
    INTO v_sols FROM jsonb_array_elements(v_sols) WITH ORDINALITY AS t(sol, pos);

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(v_data, p_section_id,
                  v_sec || jsonb_build_object('soldats', v_sols))
   WHERE id = p_compagnie_id;

  -- La ration est consommee : une par soldat nourri. Le bivouac ne detruit PAS la tente.
  IF p_action = 'ration' THEN
    FOR i IN 1 .. v_n LOOP
      SELECT pos INTO v_pos FROM jsonb_array_elements(v_inv) WITH ORDINALITY AS t(i2, pos)
       WHERE i2->>'produitMilitaire' = 'ration_combat' ORDER BY pos LIMIT 1;
      SELECT coalesce(jsonb_agg(i2 ORDER BY pos), '[]'::jsonb) INTO v_inv
        FROM jsonb_array_elements(v_inv) WITH ORDINALITY AS t(i2, pos) WHERE pos <> v_pos;
    END LOOP;
    UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = v_leader;
  END IF;

  RETURN jsonb_build_object('ok', true, 'action', p_action, 'leader', v_leader,
    'soldats', v_n, 'a_distance', v_a_distance, 'gain_pa', c_gain,
    'tentes_requises', CASE WHEN p_action='bivouac' THEN v_requis END,
    'rations_consommees', CASE WHEN p_action='ration' THEN v_n END);
END; $fn$;
REVOKE ALL ON FUNCTION public.militaire_ordre_collectif(text,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_ordre_collectif(text,text,text,text) TO authenticated, service_role;