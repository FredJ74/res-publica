-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913203728
-- Nom original      : chantier_c_phase3_commerce_fixer_parametres
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-13 20:37:28 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : ba45847d618202c5998bb801f3cb168a
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
-- CHANTIER C / PHASE 3 — FAMILLE 2 : PRIX ET PARAMETRES D'UN COMMERCE.
--
-- Sites migres : confirmerFixerPrixCommerce, confirmerFixerPrixAchatMatiereCommerce,
-- confirmerGestionArmurerie. Tous trois ecrivaient parametres.* depuis des <input> du
-- navigateur. Les fourchettes existaient, mais uniquement cote client : il suffisait d'appeler
-- la fonction avec une autre valeur. Aucune regle n'est modifiee ici -- elles sont recopiees
-- telles quelles depuis fourchettePrixPJ (+10 %/+80 % du cout de revient),
-- fourchettePrixAchatMatierePJ (+/-50 % de prixAchatFournisseur) et le Math.max(0, ...) de
-- l'armurerie, qui n'a volontairement aucune borne haute.

-- Cout de revient d'une portion, a l'identique de coutRevientPortionRecette :
-- (matieres au cout moyen REELLEMENT paye par CE commerce + main-d'oeuvre) / portions.
-- Jamais un cours theorique -- c'est une decision economique deja arretee, on la respecte.
CREATE OR REPLACE FUNCTION public.commerce_cout_revient_portion(p_data jsonb, p_recette text)
RETURNS numeric
LANGUAGE plpgsql STABLE SET search_path = public AS $$
DECLARE v_r record; v_cout numeric := 0; v_m text; v_q jsonb; v_mo numeric;
BEGIN
  SELECT * INTO v_r FROM public.recettes_commerce WHERE id = p_recette;
  IF NOT FOUND OR COALESCE(v_r.portions, 0) <= 0 THEN RETURN NULL; END IF;
  FOR v_m, v_q IN SELECT key, value FROM jsonb_each(v_r.materiaux) LOOP
    v_cout := v_cout + (v_q#>>'{}')::numeric
              * COALESCE((p_data->'coutMoyenMatieres'->>v_m)::numeric, 0);
  END LOOP;
  SELECT valeur INTO v_mo FROM public.entreprises_constantes WHERE cle = 'cout_main_oeuvre_pa_alimentaire';
  RETURN (v_cout + v_r.pa * COALESCE(v_mo, 0)) / v_r.portions;
END; $$;

CREATE OR REPLACE FUNCTION public.commerce_fixer_parametres(
  p_acteur text, p_entreprise text,
  p_prix_vente jsonb, p_prix_achat_matiere jsonb, p_stock_max jsonb)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_moi text; v_data jsonb; v_param jsonb; v_type text; v_pays text;
  v_k text; v_v jsonb; v_n numeric; v_cout numeric; v_base numeric;
  v_matieres text[]; v_ok boolean;
BEGIN
  v_moi := public.exiger_acteur(p_acteur);

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_entreprise FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'entreprise_absente'); END IF;

  -- Propriete relue en base, jamais celle annoncee par le navigateur.
  IF COALESCE(v_data->>'proprietaire','PNJ') = 'PNJ'
     OR (v_data->>'proprietaire') IS DISTINCT FROM COALESCE(v_moi, p_acteur) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_proprietaire');
  END IF;

  v_type  := COALESCE(v_data->>'type', '');
  v_pays  := COALESCE(v_data->>'country', 'republic');
  v_param := COALESCE(v_data->'parametres', '{}'::jsonb);

  IF v_type = 'armurerie' THEN
    -- L'armurerie n'a AUCUNE fourchette dans le jeu actuel (verifie site par site) : seule
    -- regle existante, Math.max(0, ...). On ne lui en invente pas une.
    FOR v_k, v_v IN SELECT key, value FROM jsonb_each(COALESCE(p_prix_vente,'{}'::jsonb)) LOOP
      IF NOT EXISTS (SELECT 1 FROM public.recettes_production WHERE id = v_k AND pays = v_pays) THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'recette_inconnue', 'cle', v_k);
      END IF;
      v_n := (v_v#>>'{}')::numeric;
      IF v_n IS NULL OR v_n < 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'valeur_invalide', 'cle', v_k); END IF;
      v_param := jsonb_set(v_param, ARRAY['prixVente', v_k], to_jsonb(trunc(v_n)), true);
    END LOOP;

    FOR v_k, v_v IN SELECT key, value FROM jsonb_each(COALESCE(p_stock_max,'{}'::jsonb)) LOOP
      IF NOT EXISTS (SELECT 1 FROM public.recettes_production WHERE id = v_k AND pays = v_pays) THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'recette_inconnue', 'cle', v_k);
      END IF;
      v_n := (v_v#>>'{}')::numeric;
      IF v_n IS NULL OR v_n < 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'valeur_invalide', 'cle', v_k); END IF;
      v_param := jsonb_set(v_param, ARRAY['stockMax', v_k], to_jsonb(trunc(v_n)), true);
    END LOOP;

    -- Matieres acceptees = union des materiaux des recettes du pays.
    SELECT array_agg(DISTINCT m) INTO v_matieres
      FROM public.recettes_production r, jsonb_object_keys(r.materiaux) m
     WHERE r.pays = v_pays;
    FOR v_k, v_v IN SELECT key, value FROM jsonb_each(COALESCE(p_prix_achat_matiere,'{}'::jsonb)) LOOP
      IF NOT (v_k = ANY (COALESCE(v_matieres, ARRAY[]::text[]))) THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'matiere_non_acceptee', 'cle', v_k);
      END IF;
      v_n := (v_v#>>'{}')::numeric;
      IF v_n IS NULL OR v_n < 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'valeur_invalide', 'cle', v_k); END IF;
      v_param := jsonb_set(v_param, ARRAY['prixAchatMatiere', v_k], to_jsonb(trunc(v_n)), true);
    END LOOP;

  ELSE
    -- Commerce alimentaire / marche : stockMax n'est modifiable par aucun ordre du jeu.
    IF p_stock_max IS NOT NULL AND p_stock_max <> '{}'::jsonb THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'stock_max_non_modifiable');
    END IF;

    FOR v_k, v_v IN SELECT key, value FROM jsonb_each(COALESCE(p_prix_vente,'{}'::jsonb)) LOOP
      IF NOT (COALESCE(v_data->'carte','[]'::jsonb) @> jsonb_build_array(to_jsonb(v_k))) THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'hors_carte', 'cle', v_k);
      END IF;
      IF EXISTS (SELECT 1 FROM public.recettes_commerce WHERE id = v_k AND prix_fixe IS NOT NULL) THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'prix_fixe', 'cle', v_k);
      END IF;
      v_cout := public.commerce_cout_revient_portion(v_data, v_k);
      IF v_cout IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'recette_inconnue', 'cle', v_k); END IF;
      v_n := (v_v#>>'{}')::numeric;
      IF v_n IS NULL
         OR v_n < round(v_cout * 1.10, 2) OR v_n > round(v_cout * 1.80, 2) THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'prix_hors_fourchette', 'cle', v_k,
                                  'min', round(v_cout * 1.10, 2), 'max', round(v_cout * 1.80, 2));
      END IF;
      v_param := jsonb_set(v_param, ARRAY['prixVente', v_k], to_jsonb(v_n), true);
    END LOOP;

    -- Matieres acceptees = union des materiaux des recettes de la CARTE, comme
    -- matieresAccepteesParCommerce -- jamais une liste codee en dur.
    SELECT array_agg(DISTINCT m) INTO v_matieres
      FROM jsonb_array_elements_text(COALESCE(v_data->'carte','[]'::jsonb)) c
      JOIN public.recettes_commerce r ON r.id = c.value,
           jsonb_object_keys(r.materiaux) m;
    FOR v_k, v_v IN SELECT key, value FROM jsonb_each(COALESCE(p_prix_achat_matiere,'{}'::jsonb)) LOOP
      IF NOT (v_k = ANY (COALESCE(v_matieres, ARRAY[]::text[]))) THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'matiere_non_acceptee', 'cle', v_k);
      END IF;
      SELECT prix_achat_fournisseur INTO v_base FROM public.ressources_economie WHERE cle = v_k;
      IF v_base IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'prix_fournisseur_absent', 'cle', v_k);
      END IF;
      v_n := (v_v#>>'{}')::numeric;
      IF v_n IS NULL OR v_n < round(v_base * 0.5, 2) OR v_n > round(v_base * 1.5, 2) THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'prix_hors_fourchette', 'cle', v_k,
                                  'min', round(v_base * 0.5, 2), 'max', round(v_base * 1.5, 2));
      END IF;
      v_param := jsonb_set(v_param, ARRAY['prixAchatMatiere', v_k], to_jsonb(v_n), true);
    END LOOP;
  END IF;

  -- UNE seule sous-cle ecrite : 'parametres'. Ni caisse, ni stock, ni proprietaire.
  UPDATE public.entreprises
     SET data = jsonb_set(v_data, '{parametres}', v_param, true), updated_at = now()
   WHERE id = p_entreprise;

  RETURN jsonb_build_object('ok', true, 'parametres', v_param);
END; $$;

REVOKE EXECUTE ON FUNCTION public.commerce_cout_revient_portion(jsonb, text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.commerce_fixer_parametres(text,text,jsonb,jsonb,jsonb) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.commerce_fixer_parametres(text,text,jsonb,jsonb,jsonb) TO authenticated, service_role;
