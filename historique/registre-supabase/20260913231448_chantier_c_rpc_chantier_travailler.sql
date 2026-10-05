-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913231448
-- Nom original      : chantier_c_rpc_chantier_travailler
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-13 23:14:48 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : b2ae3c7e8b2c1807dd33a3ad6c90e943
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
-- CHANTIER C — TRAVAILLER SUR UN CHANTIER (14 septembre 2026).
--
-- Le joueur choisit ses heures ; chaque heure coute 1 PA et lui RAPPORTE le taux horaire, pris
-- sur la tresorerie du chantier. Le navigateur bornait lui-meme les heures et se creditait.
--
-- Les quatre bornes du jeu sont recalculees ici, a l'identique de heuresTravaillablesPar :
--   1. ce que le joueur demande ;
--   2. les heures encore UTILES aujourd'hui -- capacite du jour ramenee a la fraction de
--      materiaux reellement en stock, moins ce qui a deja ete fait. Sans materiaux, aucune heure
--      n'est travaillable : on ne paie pas un travail qui ne fera rien avancer ;
--   3. les PA reellement disponibles ;
--   4. ce que la tresorerie du chantier peut payer.
-- Le besoin en materiaux du jour vient du miroir genere (cycle de 3 jours), jamais du client.
CREATE OR REPLACE FUNCTION public.chantier_travailler(
  p_acteur text, p_pays text, p_batiment text, p_heures integer)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id text; v_data jsonb; v_ch jsonb; v_stock jsonb; v_besoin record;
  v_jour_num integer; v_fraction numeric := 1; v_capacite numeric; v_utiles numeric;
  v_faites numeric; v_restantes numeric; v_tresorerie numeric; v_payables numeric;
  v_taux numeric; v_pa integer; v_arg numeric; v_liquide numeric; v_jour integer;
  v_heures integer; v_montant numeric; v_m text; v_req numeric; v_dispo numeric;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF COALESCE(p_heures, 0) <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'heures_invalides');
  END IF;
  v_id := p_pays || '_' || p_batiment;

  SELECT valeur INTO v_taux FROM public.entreprises_constantes WHERE cle = 'chantier_taux_horaire';
  IF COALESCE(v_taux, 0) <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'taux_indisponible');
  END IF;

  SELECT public.terrain_etat_lire(data) INTO v_data
    FROM public.terrains_etat WHERE id = v_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'terrain_absent'); END IF;
  IF COALESCE(v_data->>'succession_gel','') <> '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'terrain_gele');
  END IF;

  v_ch := v_data->'chantier';
  IF v_ch IS NULL OR jsonb_typeof(v_ch) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'chantier_absent');
  END IF;
  -- Le besoin quotidien d'un reamenagement se derive de SON budget, pas du cycle de construction :
  -- ce chemin n'est pas couvert ici et reste a traiter separement.
  IF COALESCE(v_ch->>'type','') <> 'construction' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'type_non_couvert', 'type', v_ch->>'type');
  END IF;

  -- --- Borne 2 : heures encore utiles aujourd'hui --------------------------
  v_jour_num := floor(GREATEST(0, COALESCE((v_ch->>'progressionJours')::numeric, 0)))::integer + 1;
  SELECT * INTO v_besoin FROM public.chantiers_besoins_jour
   WHERE position_cycle = ((v_jour_num - 1) % (SELECT count(*) FROM public.chantiers_besoins_jour)) + 1;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'besoin_indisponible'); END IF;

  v_stock := COALESCE(v_ch->'stockMateriaux', '{}'::jsonb);
  FOR v_m, v_req IN SELECT * FROM (VALUES ('bois', v_besoin.bois), ('minerai', v_besoin.minerai),
                                          ('metal', v_besoin.metal)) AS t(m, r) LOOP
    IF v_req > 0 THEN
      v_dispo := GREATEST(0, COALESCE((v_stock->>v_m)::numeric, 0));
      v_fraction := LEAST(v_fraction, LEAST(1, GREATEST(0, v_dispo / v_req)));
    END IF;
  END LOOP;

  v_capacite := CASE WHEN COALESCE((v_ch->>'dureeJours')::numeric, 0) > 0
                     THEN (COALESCE((v_ch->>'coutTravail')::numeric, 0) / v_taux)
                          / (v_ch->>'dureeJours')::numeric
                     ELSE 0 END;
  v_utiles   := floor(v_capacite * v_fraction);
  v_faites   := GREATEST(0, COALESCE((v_ch->>'heuresFaites')::numeric, 0));
  v_restantes := GREATEST(0, v_utiles - v_faites);

  -- --- Bornes 3 et 4 : PA reels et tresorerie reelle -----------------------
  SELECT COALESCE(pa,0), COALESCE(arg,0), COALESCE(liquide,0), COALESCE(day,1)
    INTO v_pa, v_arg, v_liquide, v_jour
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_pa IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;

  v_tresorerie := GREATEST(0, COALESCE((v_ch->>'tresorerie')::numeric, 0));
  v_payables   := floor(v_tresorerie / v_taux);

  v_heures := GREATEST(0, LEAST(p_heures, v_restantes, v_pa, v_payables))::integer;
  IF v_heures <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_heure_travaillable',
      'utilesRestantes', v_restantes, 'pa', v_pa, 'payables', v_payables,
      'fractionMateriaux', round(v_fraction, 4));
  END IF;
  v_montant := v_heures * v_taux;

  -- --- Application, tout ou rien -------------------------------------------
  v_ch := v_ch || jsonb_build_object(
    'heuresFaites', v_faites + v_heures,
    'tresorerie', v_tresorerie - v_montant,
    'travauxPJ', COALESCE(v_ch->'travauxPJ', '[]'::jsonb) || jsonb_build_array(
      jsonb_build_object('nom', p_acteur, 'heures', v_heures, 'montant', v_montant,
                         'jour', v_jour)));

  UPDATE public.terrains_etat
     SET data = (v_data || jsonb_build_object('chantier', v_ch))::text, updated_at = now()
   WHERE id = v_id;

  UPDATE public.personnages_donnees
     SET pa = v_pa - v_heures, arg = v_arg + v_montant, liquide = v_liquide + v_montant,
         updated_at = now()
   WHERE name = p_acteur;

  RETURN jsonb_build_object('ok', true, 'heures', v_heures, 'montant', v_montant,
    'pa', v_pa - v_heures, 'arg', v_arg + v_montant, 'liquide', v_liquide + v_montant,
    'chantier', v_ch);
END; $$;

REVOKE EXECUTE ON FUNCTION public.chantier_travailler(text,text,text,integer) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.chantier_travailler(text,text,text,integer) TO authenticated, service_role;
