-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260923142056
-- Nom original      : ration_combat_pj_plafond_et_limite
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-23 14:20:56 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : c2ff4b9669b6ebdf61ac09c739aabf79
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
-- Garde-fou 30 PA + limite de 2 rations par jour et par PJ.
-- Suivi quotidien : personnages_donnees.stats, meme structure et meme reference de date
-- (Europe/Paris) que refectoire_repas et son 'repasCaserneJour'. Aucune colonne, aucune table.
CREATE OR REPLACE FUNCTION public.militaire_ration_consommer()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  c_pa_max_pj   constant integer := 30;
  c_gain        constant integer := 1;
  c_max_par_jour constant integer := 2;
  v_moi text; v_inv jsonb; v_stats jsonb; v_pos integer;
  v_pa_avant integer; v_pa_apres integer; v_reste integer;
  v_jour text; v_deja integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  -- VERROU AVANT TOUTE LECTURE : deux appels simultanes sont serialises ici, le second relit
  -- un inventaire et un compteur deja a jour. Ni la ration ni le quota ne peuvent etre doubles.
  SELECT CASE WHEN jsonb_typeof(inventory) = 'array' THEN inventory ELSE '[]'::jsonb END,
         CASE WHEN jsonb_typeof(stats) = 'object' THEN stats ELSE '{}'::jsonb END,
         coalesce(pa, 0)
    INTO v_inv, v_stats, v_pa_avant
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_inv IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;

  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date::text;
  v_deja := CASE WHEN coalesce(v_stats->>'rationsCombatJour', '') = v_jour
                 THEN coalesce((v_stats->>'rationsCombatNb')::integer, 0) ELSE 0 END;

  SELECT pos INTO v_pos FROM jsonb_array_elements(v_inv) WITH ORDINALITY AS t(i, pos)
   WHERE i->>'produitMilitaire' = 'ration_combat' ORDER BY pos LIMIT 1;
  IF v_pos IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucune_ration'); END IF;

  -- LES DEUX REFUS CONSERVENT LA RATION : aucune ecriture n'a encore eu lieu a ce stade.
  IF v_pa_avant >= c_pa_max_pj THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_maximum', 'pa', v_pa_avant, 'plafond', c_pa_max_pj);
  END IF;
  IF v_deja >= c_max_par_jour THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'maximum_quotidien',
      'consommees_aujourdhui', v_deja, 'maximum', c_max_par_jour);
  END IF;

  v_pa_apres := least(c_pa_max_pj, v_pa_avant + c_gain);

  SELECT coalesce(jsonb_agg(i ORDER BY pos), '[]'::jsonb) INTO v_inv
    FROM jsonb_array_elements(v_inv) WITH ORDINALITY AS t(i, pos) WHERE pos <> v_pos;

  UPDATE public.personnages_donnees
     SET inventory = v_inv, pa = v_pa_apres,
         stats = v_stats || jsonb_build_object('rationsCombatJour', v_jour,
                                               'rationsCombatNb', v_deja + 1)
   WHERE name = v_moi;

  SELECT count(*)::integer INTO v_reste FROM jsonb_array_elements(v_inv) i
   WHERE i->>'produitMilitaire' = 'ration_combat';

  RETURN jsonb_build_object('ok', true, 'pa_avant', v_pa_avant, 'pa_apres', v_pa_apres,
    'gain_reel', v_pa_apres - v_pa_avant, 'rations_restantes', v_reste,
    'consommees_aujourdhui', v_deja + 1, 'maximum', c_max_par_jour);
END;
$function$;

REVOKE ALL ON FUNCTION public.militaire_ration_consommer() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.militaire_ration_consommer() TO authenticated;

-- Texte de l'objet : « +1 PA par jour » etait herite de la regle des soldats PNJ et devenait faux.
CREATE OR REPLACE FUNCTION public.militaire_rations_retirer(p_nombre integer)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
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
      'name', 'Ration de combat', 'icon', 'ti-soup', 'legal', true,
      'imageUrl', 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/militaire-ration-combat.png',
      'desc', 'Ration de combat. +1 PA par ration, 2 rations par jour au maximum.'));
  END LOOP;
  UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = v_moi;

  RETURN jsonb_build_object('ok', true, 'retirees', v_n, 'restantes', v_dispo - v_n);
END;
$function$;