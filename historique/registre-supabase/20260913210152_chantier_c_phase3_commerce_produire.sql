-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913210152
-- Nom original      : chantier_c_phase3_commerce_produire
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-13 21:01:52 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 9471e976853021da235498c7efa01e05
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
-- CHANTIER C / PHASE 3 — FAMILLE 5 : PRODUCTION EN COMMERCE ET EN ARMURERIE.
--
-- Sites migres : confirmerProduction (armurerie) et produireRecetteCommerce (alimentaire/marche).
-- Tous deux sont CASSES en production depuis la phase 1 : ils annoncaient a payer_ordre un PA
-- (2 pour l'armurerie, recette.pa pour un commerce) qui n'est PAS le PA declare de l'ordre dans
-- data.js (produire_arme et produire_commerce y valent 0) -- le miroir, fail-closed, refusait.
--
-- La regle de jeu est ici dans le CODE (PA_PRODUCTION_ARMURERIE, recette.pa), pas dans le
-- catalogue d'ordres : c'est donc au serveur de la connaitre, via le miroir des recettes et des
-- constantes. payer_ordre n'est appelee que pour sa part fixe reellement declaree (0,0), ce qui
-- conserve la propriete "ordre inconnu = refuse" sans lui demander d'arbitrer un PA qu'elle
-- n'a aucun moyen de connaitre.
--
-- Le joueur ne paie pas la production : il la REALISE et percoit le salaire de main-d'oeuvre,
-- pris sur la caisse du commerce. Regle existante, recopiee telle quelle.
CREATE OR REPLACE FUNCTION public.commerce_produire(
  p_acteur text, p_entreprise text, p_recette text, p_ordre text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_data jsonb; v_type text; v_pays text; v_ville text; v_bat text; v_jour integer;
  v_rec record; v_prod record;
  v_pa_requis integer; v_salaire numeric; v_portions integer; v_materiaux jsonb;
  v_sm jsonb; v_sp jsonb; v_stock numeric; v_plafond numeric; v_declare numeric; v_smc numeric;
  v_caisse numeric; v_categorie text; v_caisse_id text; v_r jsonb;
  v_pa integer; v_arg numeric; v_liquide numeric;
  v_m text; v_q jsonb; v_dispo numeric; v_cout numeric; v_mo numeric;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_entreprise FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  v_type := COALESCE(v_data->>'type','');
  v_pays := COALESCE(v_data->>'country','republic');
  v_ville:= COALESCE(v_data->>'city','capitale');
  v_bat  := COALESCE(v_data->>'buildingId','');

  -- ---- La recette, son cout en PA et son salaire : tous relus dans le miroir --------
  IF v_type = 'armurerie' THEN
    SELECT * INTO v_prod FROM public.recettes_production WHERE id = p_recette AND pays = v_pays;
    IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'recette_inconnue'); END IF;
    v_materiaux := v_prod.materiaux;
    v_portions  := 1;
    SELECT valeur INTO v_pa_requis FROM public.entreprises_constantes WHERE cle = 'pa_production_armurerie';
    SELECT valeur INTO v_salaire   FROM public.entreprises_constantes WHERE cle = 'salaire_production_armurerie';
  ELSE
    SELECT * INTO v_rec FROM public.recettes_commerce WHERE id = p_recette;
    IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'recette_inconnue'); END IF;
    -- La recette doit etre a la carte ET autorisee ici (type, pays, ville, batiment).
    IF NOT (COALESCE(v_data->'carte','[]'::jsonb) @> jsonb_build_array(to_jsonb(p_recette))) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'hors_carte');
    END IF;
    IF v_rec.types_autorises IS NOT NULL
       AND NOT (v_rec.types_autorises @> jsonb_build_array(to_jsonb(v_type))) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'type_non_autorise');
    END IF;
    IF v_rec.pays_autorises IS NOT NULL
       AND NOT (v_rec.pays_autorises @> jsonb_build_array(to_jsonb(v_pays))) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pays_non_autorise');
    END IF;
    IF v_rec.villes_autorisees IS NOT NULL
       AND NOT (v_rec.villes_autorisees @> jsonb_build_array(to_jsonb(v_ville))) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'ville_non_autorisee');
    END IF;
    IF v_rec.buildings_autorises IS NOT NULL
       AND NOT (v_rec.buildings_autorises @> jsonb_build_array(to_jsonb(v_bat))) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'batiment_non_autorise');
    END IF;
    v_materiaux := v_rec.materiaux;
    v_portions  := v_rec.portions;
    v_pa_requis := v_rec.pa;
    SELECT valeur INTO v_mo FROM public.entreprises_constantes WHERE cle = 'cout_main_oeuvre_pa_alimentaire';
    v_salaire := v_rec.pa * COALESCE(v_mo, 0);
  END IF;

  -- ---- Plafond de stock ---------------------------------------------------
  v_sp := COALESCE(v_data->'stockProduits','{}'::jsonb);
  v_stock := COALESCE((v_sp->>p_recette)::numeric, 0);
  v_declare := (v_data->'parametres'->'stockMax'->>p_recette)::numeric;
  IF v_type = 'armurerie' THEN
    v_plafond := v_declare;   -- l'armurerie n'a que son plafond declare, jamais de cap universel
  ELSE
    SELECT valeur INTO v_smc FROM public.entreprises_constantes WHERE cle = 'stock_max_commerce';
    v_plafond := CASE WHEN v_declare IS NOT NULL THEN LEAST(v_declare, COALESCE(v_smc,20))
                      ELSE COALESCE(v_smc,20) END;
  END IF;
  IF v_plafond IS NOT NULL AND v_stock + v_portions > v_plafond THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_plein', 'plafond', v_plafond);
  END IF;

  -- ---- Matieres reellement disponibles ------------------------------------
  v_sm := COALESCE(v_data->'stockMatieres','{}'::jsonb);
  FOR v_m, v_q IN SELECT key, value FROM jsonb_each(v_materiaux) LOOP
    v_dispo := COALESCE((v_sm->>v_m)::numeric, 0);
    IF v_dispo < (v_q#>>'{}')::numeric THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'matieres_insuffisantes',
                                'matiere', v_m, 'disponible', v_dispo);
    END IF;
  END LOOP;

  -- ---- Part fixe de l'ordre (conserve "ordre inconnu = refuse") ------------
  IF COALESCE(p_ordre,'') <> '' THEN
    v_r := public.payer_ordre(p_acteur, p_ordre, 0, 0);
    IF COALESCE((v_r->>'ok')::boolean, false) IS NOT TRUE THEN
      RETURN jsonb_build_object('ok', false, 'raison', COALESCE(v_r->>'raison','ordre_refuse'));
    END IF;
  END IF;

  -- ---- PA du travail (regle de code, relue dans le miroir) -----------------
  SELECT COALESCE(pa,0), COALESCE(arg,0), COALESCE(liquide,0)
    INTO v_pa, v_arg, v_liquide
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_pa IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  IF v_pa < COALESCE(v_pa_requis,0) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants', 'pa_reel', v_pa);
  END IF;

  -- ---- Salaire de main-d'oeuvre : caisse autonome ou institutionnelle ------
  v_categorie := CASE v_type WHEN 'buvette' THEN 'stade' WHEN 'marche' THEN 'marche' ELSE NULL END;
  v_caisse := GREATEST(0, COALESCE((v_data->>'caisse')::numeric, 0));
  IF v_categorie IS NOT NULL THEN
    v_caisse_id := v_pays || '_' || v_categorie || '_' || v_ville;
    v_r := public.caisse_institution_mouvement(v_caisse_id, -v_salaire, false);
    IF COALESCE((v_r->>'ok')::boolean, false) IS NOT TRUE THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante');
    END IF;
  ELSE
    IF v_caisse < v_salaire THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante', 'caisse', v_caisse);
    END IF;
    v_data := jsonb_set(v_data, '{caisse}', to_jsonb(v_caisse - v_salaire), true);
  END IF;

  -- ---- Mutations ----------------------------------------------------------
  FOR v_m, v_q IN SELECT key, value FROM jsonb_each(v_materiaux) LOOP
    v_sm := jsonb_set(v_sm, ARRAY[v_m],
             to_jsonb(COALESCE((v_sm->>v_m)::numeric,0) - (v_q#>>'{}')::numeric));
  END LOOP;
  v_data := jsonb_set(v_data, '{stockMatieres}', v_sm, true);
  v_data := jsonb_set(v_data, '{stockProduits}',
                      jsonb_set(v_sp, ARRAY[p_recette], to_jsonb(v_stock + v_portions)), true);

  -- Prix auto d'un commerce PNJ : cout de revient x2, arrondi a l'entier. Recalcule a chaque
  -- production car le cout moyen des matieres a pu bouger. Un commerce PJ garde SON prix.
  IF v_type <> 'armurerie' AND COALESCE(v_data->>'proprietaire','PNJ') = 'PNJ'
     AND v_rec.prix_fixe IS NULL THEN
    v_cout := public.commerce_cout_revient_portion(v_data, p_recette);
    IF v_cout IS NOT NULL THEN
      v_data := jsonb_set(v_data, ARRAY['parametres','prixVente',p_recette],
                          to_jsonb(round(v_cout * 2)), true);
    END IF;
  END IF;

  SELECT COALESCE(day,1) INTO v_jour FROM public.personnages_donnees WHERE name = p_acteur;
  v_data := public.entreprise_ajouter_historique(v_data, -v_salaire,
              'Production de ' || p_recette || ' (' || v_portions || ' portions) — ' || p_acteur, v_jour);
  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_entreprise;

  -- PA preleves et salaire verse au producteur, dans la meme transaction.
  UPDATE public.personnages_donnees
     SET pa = v_pa - COALESCE(v_pa_requis,0),
         arg = v_arg + v_salaire, liquide = v_liquide + v_salaire, updated_at = now()
   WHERE name = p_acteur;

  RETURN jsonb_build_object('ok', true, 'recette', p_recette, 'portions', v_portions,
    'salaire', v_salaire, 'paPreleves', COALESCE(v_pa_requis,0),
    'pa', v_pa - COALESCE(v_pa_requis,0), 'arg', v_arg + v_salaire,
    'liquide', v_liquide + v_salaire,
    'stockProduit', v_stock + v_portions,
    'prixVente', v_data->'parametres'->'prixVente'->p_recette);
END; $$;

REVOKE EXECUTE ON FUNCTION public.commerce_produire(text,text,text,text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.commerce_produire(text,text,text,text) TO authenticated, service_role;
