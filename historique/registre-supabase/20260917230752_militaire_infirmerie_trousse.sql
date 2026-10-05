-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260917230752
-- Nom original      : militaire_infirmerie_trousse
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-17 23:07:52 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 14785173f8bbcb0a08d18fb28361ad9b
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
-- INFIRMERIE DE CASERNE : trousses de premiers secours
--
-- PATRON REUTILISE : celui du refectoire (refectoire_repas). Le stock de matieres vit dans
-- budgets_nationaux.data.infirmerie, exactement comme data.refectoire, et la trousse est
-- FABRIQUEE A LA DEMANDE au moment du retrait -- aucune production prealable a lancer. Les trois
-- intrants sont deduits atomiquement ; s'il en manque un, RIEN n'est consomme ni cree.
--
-- Recette GD : 1 textile + 1 medicament + 1 desinfectant -> 1 trousse, 0 PA de fabrication.
--
-- EFFET : +2 PA de base, +1 par tranche COMPLETE de 25 points de Secourisme DU SOIGNANT.
--   0-24 -> +2 | 25-49 -> +3 | 50-74 -> +4 | 75-99 -> +5 | 100 -> +6
-- C'est la competence de celui qui prodigue les soins qui compte, pas celle du soigne.
-- Usage unique : la trousse disparait de l'inventaire dans la meme transaction que le gain.
-- ==========================================================================================

CREATE OR REPLACE FUNCTION public.militaire_trousse_retirer()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE
  c_plafond constant integer := 100;
  v_moi text; v_pays text; v_bat text; v_inv jsonb; v_occupe numeric;
  v_data jsonb; v_inf jsonb; v_tex integer; v_med integer; v_des integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(country,'republic'), coalesce(current_building,''),
         CASE WHEN jsonb_typeof(inventory)='array' THEN inventory ELSE '[]'::jsonb END
    INTO v_pays, v_bat, v_inv
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_pays IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  IF v_bat <> 'caserne-militaire' THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;

  SELECT coalesce(sum(greatest(1, coalesce((i->>'qty')::numeric, (i->>'encombrement')::numeric, 1))), 0)
    INTO v_occupe FROM jsonb_array_elements(v_inv) i;
  IF v_occupe + 1 > c_plafond THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein', 'plafond', c_plafond);
  END IF;

  SELECT data INTO v_data FROM public.budgets_nationaux WHERE id = v_pays FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'infirmerie_vide'); END IF;
  v_inf := CASE WHEN jsonb_typeof(v_data->'infirmerie')='object' THEN v_data->'infirmerie' ELSE '{}'::jsonb END;
  v_tex := greatest(0, coalesce((v_inf->>'textile')::integer, 0));
  v_med := greatest(0, coalesce((v_inf->>'medicaments')::integer, 0));
  v_des := greatest(0, coalesce((v_inf->>'desinfectant')::integer, 0));

  IF v_tex < 1 OR v_med < 1 OR v_des < 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ingredients_insuffisants',
      'textile', v_tex, 'medicaments', v_med, 'desinfectant', v_des);
  END IF;

  -- Deduction ATOMIQUE des trois intrants ET creation de l'objet, dans la meme ecriture.
  UPDATE public.budgets_nationaux
     SET data = v_data || jsonb_build_object('infirmerie',
           v_inf || jsonb_build_object('textile', v_tex - 1, 'medicaments', v_med - 1,
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
REVOKE ALL ON FUNCTION public.militaire_trousse_retirer() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_trousse_retirer() TO authenticated, service_role;


CREATE OR REPLACE FUNCTION public.militaire_trousse_utiliser(p_cible text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE
  c_pa_max_pj constant integer := 30;
  v_moi text; v_inv jsonb; v_pos integer; v_sec numeric; v_gain integer;
  v_cible text; v_pa_avant integer; v_pa_apres integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_cible := coalesce(nullif(btrim(coalesce(p_cible,'')), ''), v_moi);

  SELECT CASE WHEN jsonb_typeof(inventory)='array' THEN inventory ELSE '[]'::jsonb END,
         coalesce((competences_militaires->>'secourisme')::numeric, 0)
    INTO v_inv, v_sec FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_inv IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;

  SELECT pos INTO v_pos FROM jsonb_array_elements(v_inv) WITH ORDINALITY AS t(i, pos)
   WHERE i->>'produitMilitaire' = 'trousse_secours' ORDER BY pos LIMIT 1;
  IF v_pos IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucune_trousse'); END IF;

  -- +2 de base, +1 par tranche COMPLETE de 25 de Secourisme DU SOIGNANT.
  v_gain := 2 + floor(least(100, greatest(0, v_sec)) / 25)::integer;

  SELECT coalesce(pa, 0) INTO v_pa_avant FROM public.personnages_donnees WHERE name = v_cible FOR UPDATE;
  IF v_pa_avant IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable'); END IF;
  v_pa_apres := least(c_pa_max_pj, v_pa_avant + v_gain);

  -- USAGE UNIQUE : la trousse quitte l'inventaire dans la MEME transaction que le gain.
  SELECT coalesce(jsonb_agg(i ORDER BY pos), '[]'::jsonb) INTO v_inv
    FROM jsonb_array_elements(v_inv) WITH ORDINALITY AS t(i, pos) WHERE pos <> v_pos;
  UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = v_moi;
  UPDATE public.personnages_donnees SET pa = v_pa_apres WHERE name = v_cible;

  RETURN jsonb_build_object('ok', true, 'soignant', v_moi, 'cible', v_cible,
    'secourisme', v_sec, 'gain_theorique', v_gain,
    'pa_avant', v_pa_avant, 'pa_apres', v_pa_apres, 'gain_reel', v_pa_apres - v_pa_avant);
END; $fn$;
REVOKE ALL ON FUNCTION public.militaire_trousse_utiliser(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_trousse_utiliser(text) TO authenticated, service_role;