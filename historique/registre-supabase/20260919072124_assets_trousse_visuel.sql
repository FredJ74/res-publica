-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260919072124
-- Nom original      : assets_trousse_visuel
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-19 07:21:24 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 5a527953f43ef598dbd221cbd724ba3a
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
-- Seule l'URL du visuel change ; la recette, les matieres, le plafond d'inventaire et les motifs
-- de refus sont repris a l'identique. Decoupe issue de la planche « Republia accessoires
-- militaires » (19/09/2026).
CREATE OR REPLACE FUNCTION public.militaire_trousse_retirer()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
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
           'legal', true,
           'imageUrl', 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/militaire-trousse-secours.png',
           'desc', 'Trousse de premiers secours. Usage unique. Restaure des PA, d''autant plus que le soignant maîtrise le Secourisme.'))
   WHERE name = v_moi;

  RETURN jsonb_build_object('ok', true, 'fabriquee', true,
    'restant', jsonb_build_object('textile', v_tex - 1, 'medicaments', v_med - 1, 'desinfectant', v_des - 1));
END;
$$;

REVOKE ALL ON FUNCTION public.militaire_trousse_retirer() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_trousse_retirer() TO authenticated;