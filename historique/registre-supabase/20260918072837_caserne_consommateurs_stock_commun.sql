-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260918072837
-- Nom original      : caserne_consommateurs_stock_commun
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-18 07:28:37 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 5eab9cdc8a818ec45bc407f67295086f
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
-- refectoire_repas lit desormais le stock COMMUN pour ses matieres premieres.
-- Les RATIONS, elles, restent un PRODUIT FINI avec son propre magasin (data.refectoire.rations) :
-- le GD l'autorise explicitement, et c'est ce qui permet a militaire_rations_retirer de servir des
-- rations deja produites sans repasser par les matieres.
CREATE OR REPLACE FUNCTION public.refectoire_repas(
  p_pays text, p_joueur text, p_jour integer,
  p_pa_max integer DEFAULT 30, p_gain integer DEFAULT 2
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_pj personnages%ROWTYPE; v_pays text; v_jour text; v_stats jsonb;
  v_data jsonb; v_ref jsonb; v_commun jsonb; v_rations integer;
  v_cer integer; v_via integer; v_poi integer; v_prot text; v_fab boolean := false; v_pa integer;
BEGIN
  PERFORM public.exiger_acteur(p_joueur);
  IF COALESCE(btrim(p_joueur), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  SELECT * INTO v_pj FROM public.personnages WHERE name = p_joueur FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_absent'); END IF;
  IF COALESCE(v_pj.current_building, '') <> 'caserne-militaire' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;

  -- Ni le pays ni le jour ne sont crus : le batiment 'caserne-militaire' existe dans les quatre
  -- empires, et p_jour etait un robinet de PA. p_pays, p_jour, p_gain et p_pa_max sont ignores.
  v_pays := COALESCE(NULLIF(btrim(COALESCE(v_pj.country, '')), ''), 'republic');
  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date::text;

  v_stats := CASE WHEN jsonb_typeof(v_pj.stats) = 'object' THEN v_pj.stats ELSE '{}'::jsonb END;
  IF COALESCE(v_stats ->> 'repasCaserneJour', '') = v_jour THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_mange', 'jourCle', v_jour);
  END IF;

  SELECT data INTO v_data FROM public.budgets_nationaux WHERE id = v_pays FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'refectoire_vide'); END IF;
  v_data := COALESCE(v_data, '{}'::jsonb);

  v_ref := CASE WHEN jsonb_typeof(v_data -> 'refectoire') = 'object'
                THEN v_data -> 'refectoire' ELSE '{}'::jsonb END;
  v_commun := CASE WHEN jsonb_typeof(v_data -> 'caserneMatieres') = 'object'
                   THEN v_data -> 'caserneMatieres' ELSE '{}'::jsonb END;
  v_rations := GREATEST(0, COALESCE((v_ref ->> 'rations')::integer, 0));

  IF v_rations <= 0 THEN
    -- Fabrication automatique d'un lot de 10, sur le STOCK COMMUN : 1 cereale + 1 (viande OU poisson).
    v_cer := GREATEST(0, COALESCE((v_commun ->> 'cereales')::integer, 0));
    v_via := GREATEST(0, COALESCE((v_commun ->> 'viande')::integer, 0));
    v_poi := GREATEST(0, COALESCE((v_commun ->> 'poisson')::integer, 0));
    IF v_cer < 1 OR (v_via + v_poi) < 1 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'ingredients_insuffisants',
                                'cereales', v_cer, 'viande', v_via, 'poisson', v_poi);
    END IF;
    v_prot := CASE WHEN v_via >= 1 THEN 'viande' ELSE 'poisson' END;
    v_commun := v_commun || jsonb_build_object('cereales', v_cer - 1,
                  v_prot, (CASE WHEN v_prot = 'viande' THEN v_via ELSE v_poi END) - 1);
    v_rations := 10;
    v_fab := true;
  END IF;

  v_rations := v_rations - 1;
  v_data := v_data
            || jsonb_build_object('caserneMatieres', v_commun)
            || jsonb_build_object('refectoire', v_ref || jsonb_build_object('rations', v_rations));
  UPDATE public.budgets_nationaux SET data = v_data, updated_at = now() WHERE id = v_pays;

  v_pa := LEAST(30, GREATEST(0, COALESCE(v_pj.pa, 0)) + 2);
  UPDATE public.personnages_donnees
     SET pa = v_pa, stats = v_stats || jsonb_build_object('repasCaserneJour', v_jour)
   WHERE name = p_joueur;

  RETURN jsonb_build_object('ok', true, 'pa', v_pa, 'rations', v_rations,
                            'fabrique', v_fab, 'proteine', v_prot,
                            'pays', v_pays, 'jourCle', v_jour);
END; $fn$;

-- La trousse prend ses matieres dans le stock COMMUN, sans aucune copie intermediaire.
CREATE OR REPLACE FUNCTION public.militaire_trousse_retirer()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE
  c_plafond constant integer := 100;
  v_moi text; v_pays text; v_bat text; v_inv jsonb; v_occupe numeric;
  v_data jsonb; v_commun jsonb; v_tex integer; v_med integer; v_des integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(country,'republic'), coalesce(current_building,''),
         CASE WHEN jsonb_typeof(inventory)='array' THEN inventory ELSE '[]'::jsonb END
    INTO v_pays, v_bat, v_inv
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_pays IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  -- La PIECE determine ce qu'on peut fabriquer ; le BATIMENT determine les matieres accessibles.
  IF v_bat <> 'caserne-militaire' THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;

  SELECT coalesce(sum(greatest(1, coalesce((i->>'qty')::numeric, (i->>'encombrement')::numeric, 1))), 0)
    INTO v_occupe FROM jsonb_array_elements(v_inv) i;
  IF v_occupe + 1 > c_plafond THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein', 'plafond', c_plafond);
  END IF;

  SELECT data INTO v_data FROM public.budgets_nationaux WHERE id = v_pays FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'matieres_insuffisantes'); END IF;
  v_commun := CASE WHEN jsonb_typeof(v_data->'caserneMatieres')='object'
                   THEN v_data->'caserneMatieres' ELSE '{}'::jsonb END;
  v_tex := greatest(0, coalesce((v_commun->>'textile')::integer, 0));
  v_med := greatest(0, coalesce((v_commun->>'medicaments')::integer, 0));
  v_des := greatest(0, coalesce((v_commun->>'desinfectant')::integer, 0));

  IF v_tex < 1 OR v_med < 1 OR v_des < 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ingredients_insuffisants',
      'textile', v_tex, 'medicaments', v_med, 'desinfectant', v_des);
  END IF;

  UPDATE public.budgets_nationaux
     SET data = v_data || jsonb_build_object('caserneMatieres',
           v_commun || jsonb_build_object('textile', v_tex - 1, 'medicaments', v_med - 1,
                                          'desinfectant', v_des - 1)),
         updated_at = now()
   WHERE id = v_pays;

  UPDATE public.personnages_donnees
     SET inventory = v_inv || jsonb_build_array(jsonb_build_object(
           'id', 'mil-' || replace(gen_random_uuid()::text, '-', ''),
           'type', 'soin', 'sousType', 'militaire', 'produitMilitaire', 'trousse_secours',
           'origineMilitaire', true, 'usageUnique', true,
           'name', 'Trousse de premiers secours', 'icon', 'ti-first-aid-kit',
           'legal', true, 'imageUrl', NULL,
           'desc', 'Trousse de premiers secours. Usage unique. Restaure des PA, d''autant plus que le soignant maîtrise le Secourisme.'))
   WHERE name = v_moi;

  RETURN jsonb_build_object('ok', true, 'fabriquee', true,
    'restant', jsonb_build_object('textile', v_tex - 1, 'medicaments', v_med - 1, 'desinfectant', v_des - 1));
END; $fn$;

-- Les rations restent servies sur le PRODUIT FINI refectoire.rations : inchange.
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