-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260923142639
-- Nom original      : ration_combat_pj_aligner_depot
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-23 14:26:39 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 01605526033112c303468414311d1feb
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
CREATE OR REPLACE FUNCTION public.militaire_ration_consommer()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  c_pa_max_pj    constant integer := 30;
  c_gain         constant integer := 1;
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

  -- LA POSSESSION EST VERIFIEE ICI, jamais crue sur parole. La premiere ration trouvee est
  -- consommee : elles sont interchangeables, aucun choix a offrir au joueur.
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

  -- USAGE UNIQUE : la ration quitte l'inventaire dans la MEME transaction que le gain et que
  -- l'incrementation du compteur du jour.
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

-- PIEGE RECURRENT : une RPC non accordee repond 42501 « permission denied », pas un refus metier.
REVOKE ALL ON FUNCTION public.militaire_ration_consommer() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.militaire_ration_consommer() TO authenticated;