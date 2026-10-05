-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913004533
-- Nom original      : effort_guerre_correctif_entrepots_vides
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-13 00:45:33 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 8e1479b9b723615ebcff5db49063634a
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
-- Correctif : array_agg sur zero ligne renvoie NULL, et FOREACH sur NULL leve une erreur
-- (22004) au lieu de sortir proprement. effort_reserve_appliquer etait deja protege par sa garde
-- jsonb_array_length ; les deux autres ne l'etaient pas. On garde donc le tableau NON NULL.
CREATE OR REPLACE FUNCTION public.effort_ravitailler(
  p_pays text, p_entrepots jsonb, p_cibles jsonb, p_prix jsonb
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $fn$
DECLARE
  v_ids text[]; v_id text; v_etats jsonb := '{}'::jsonb; v_d jsonb; v_res text;
  v_reste numeric; v_pris numeric; v_prix numeric; v_cout numeric; v_total numeric := 0;
  v_caisse text; v_solde numeric; v_ent jsonb; v_stock jsonb; v_resv jsonb; v_dispo numeric;
  v_achats jsonb := '{}'::jsonb; v_data jsonb; v_ref jsonb; v_brut jsonb;
BEGIN
  IF p_entrepots IS NULL OR jsonb_typeof(p_entrepots) <> 'array'
     OR jsonb_array_length(p_entrepots) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_entrepot');
  END IF;
  v_caisse := p_pays || '_caserne-militaire';
  SELECT COALESCE((data ->> 'solde')::numeric, 0) INTO v_solde
    FROM public.caisses_batiments WHERE id = v_caisse FOR UPDATE;
  IF NOT FOUND THEN v_solde := 0; END IF;
  IF v_solde <= 0 THEN RETURN jsonb_build_object('ok', true, 'achats', '{}'::jsonb, 'total', 0); END IF;

  SELECT COALESCE(array_agg(x ORDER BY x), ARRAY[]::text[]) INTO v_ids
  FROM (SELECT public.eg_etat_id(p_pays, e) AS x FROM jsonb_array_elements(p_entrepots) e) s;
  FOREACH v_id IN ARRAY v_ids LOOP
    SELECT public.eg_etat_lire(data) INTO v_d FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
    IF FOUND THEN v_etats := v_etats || jsonb_build_object(v_id, v_d); END IF;
  END LOOP;
  IF v_etats = '{}'::jsonb THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucun_entrepot_trouve'); END IF;

  FOR v_res IN SELECT k FROM jsonb_object_keys(COALESCE(p_cibles, '{}'::jsonb)) k ORDER BY 1 LOOP
    v_reste := GREATEST(0, COALESCE((p_cibles ->> v_res)::numeric, 0));
    v_prix  := GREATEST(0, COALESCE((p_prix ->> v_res)::numeric, 0));
    CONTINUE WHEN v_reste <= 0 OR v_prix <= 0;
    FOR v_id IN SELECT k2 FROM jsonb_object_keys(v_etats) k2 ORDER BY 1 LOOP
      EXIT WHEN v_reste <= 0 OR v_solde < v_prix;
      v_d     := v_etats -> v_id;
      v_ent   := COALESCE(v_d -> 'entrepot', '{}'::jsonb);
      v_stock := COALESCE(v_ent -> 'stock', '{}'::jsonb);
      v_resv  := COALESCE(v_ent -> 'reserveMilitaire', '{}'::jsonb);
      v_dispo := GREATEST(0, COALESCE((v_stock ->> v_res)::numeric, 0))
               - GREATEST(0, COALESCE((v_resv  ->> v_res)::numeric, 0));
      v_pris := LEAST(v_reste, GREATEST(0, v_dispo), floor(v_solde / v_prix));
      CONTINUE WHEN v_pris <= 0;
      v_cout  := v_pris * v_prix;
      v_stock := v_stock || jsonb_build_object(v_res, COALESCE((v_stock ->> v_res)::numeric, 0) - v_pris);
      v_ent   := v_ent || jsonb_build_object('stock', v_stock,
                   'caisse', COALESCE((v_ent ->> 'caisse')::numeric, 0) + v_cout);
      v_etats := v_etats || jsonb_build_object(v_id, v_d || jsonb_build_object('entrepot', v_ent));
      v_solde := v_solde - v_cout;
      v_total := v_total + v_cout;
      v_reste := v_reste - v_pris;
      v_achats := v_achats || jsonb_build_object(v_res, COALESCE((v_achats ->> v_res)::numeric, 0) + v_pris);
    END LOOP;
  END LOOP;

  IF v_total <= 0 THEN RETURN jsonb_build_object('ok', true, 'achats', '{}'::jsonb, 'total', 0); END IF;

  FOR v_id IN SELECT k FROM jsonb_object_keys(v_etats) k ORDER BY 1 LOOP
    UPDATE public.batiments_etat SET data = to_jsonb((v_etats -> v_id)::text), updated_at = now() WHERE id = v_id;
  END LOOP;
  UPDATE public.caisses_batiments
     SET data = COALESCE(data, '{}'::jsonb) || jsonb_build_object('solde', v_solde), updated_at = now()
   WHERE id = v_caisse;

  SELECT data INTO v_data FROM public.budgets_nationaux WHERE id = p_pays FOR UPDATE;
  v_data := COALESCE(v_data, '{}'::jsonb);
  v_ref  := CASE WHEN jsonb_typeof(v_data -> 'refectoire') = 'object' THEN v_data -> 'refectoire' ELSE '{}'::jsonb END;
  v_brut := CASE WHEN jsonb_typeof(v_ref -> 'brut') = 'object' THEN v_ref -> 'brut' ELSE '{}'::jsonb END;
  FOR v_res IN SELECT k FROM jsonb_object_keys(v_achats) k LOOP
    v_brut := v_brut || jsonb_build_object(v_res,
      COALESCE((v_brut ->> v_res)::numeric, 0) + COALESCE((v_achats ->> v_res)::numeric, 0));
  END LOOP;
  v_ref  := v_ref || jsonb_build_object('brut', v_brut);
  v_data := v_data || jsonb_build_object('refectoire', v_ref);
  UPDATE public.budgets_nationaux SET data = v_data, updated_at = now() WHERE id = p_pays;

  RETURN jsonb_build_object('ok', true, 'achats', v_achats, 'total', v_total, 'solde', v_solde);
END;
$fn$;

-- Meme garde pour la production : un appel sans entrepot doit refuser proprement.
CREATE OR REPLACE FUNCTION public.effort_produire_lot(
  p_pays text, p_commande_id text, p_armurerie text, p_entrepots jsonb,
  p_recette jsonb, p_cout_revient numeric, p_lot text,
  p_arme_label text, p_ville_arm text, p_jour integer
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $fn$
DECLARE
  v_cmd public.commandes_militaires%ROWTYPE;
  v_ids text[]; v_id text; v_etats jsonb := '{}'::jsonb; v_d jsonb;
  v_mat text; v_besoin numeric; v_dispo numeric; v_reste numeric; v_pris numeric;
  v_stock jsonb; v_res jsonb; v_caisse text; v_solde numeric;
  v_ent jsonb; v_arm jsonb; v_parlot integer; v_mvt jsonb; v_conso jsonb := '{}'::jsonb;
BEGIN
  IF COALESCE(p_cout_revient, -1) < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cout_invalide');
  END IF;
  IF p_entrepots IS NULL OR jsonb_typeof(p_entrepots) <> 'array'
     OR jsonb_array_length(p_entrepots) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_entrepot');
  END IF;
  v_parlot := GREATEST(1, COALESCE((p_recette ->> 'produitParLot')::integer, 1));

  SELECT * INTO v_cmd FROM public.commandes_militaires WHERE id = p_commande_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'commande_absente'); END IF;
  IF v_cmd.statut <> 'en_cours' THEN RETURN jsonb_build_object('ok', false, 'raison', 'commande_close'); END IF;
  IF v_cmd.quantite_produite + v_parlot > v_cmd.quantite_demandee THEN
    v_parlot := v_cmd.quantite_demandee - v_cmd.quantite_produite;
    IF v_parlot <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'commande_complete'); END IF;
  END IF;

  SELECT COALESCE(array_agg(x ORDER BY x), ARRAY[]::text[]) INTO v_ids
  FROM (SELECT public.eg_etat_id(p_pays, e) AS x FROM jsonb_array_elements(p_entrepots) e) s;
  FOREACH v_id IN ARRAY v_ids LOOP
    SELECT public.eg_etat_lire(data) INTO v_d FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
    IF FOUND THEN v_etats := v_etats || jsonb_build_object(v_id, v_d); END IF;
  END LOOP;
  IF v_etats = '{}'::jsonb THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucun_entrepot_trouve'); END IF;

  FOR v_mat IN SELECT k FROM jsonb_object_keys(COALESCE(p_recette -> 'materiaux', '{}'::jsonb)) k LOOP
    v_besoin := COALESCE((p_recette -> 'materiaux' ->> v_mat)::numeric, 0);
    v_dispo := 0;
    FOR v_id IN SELECT k2 FROM jsonb_object_keys(v_etats) k2 ORDER BY 1 LOOP
      v_ent := COALESCE(v_etats -> v_id -> 'entrepot', '{}'::jsonb);
      v_dispo := v_dispo + LEAST(
        GREATEST(0, COALESCE((v_ent -> 'stock' ->> v_mat)::numeric, 0)),
        GREATEST(0, COALESCE((v_ent -> 'reserveMilitaire' ->> v_mat)::numeric, 0)));
    END LOOP;
    IF v_dispo < v_besoin THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'matieres_insuffisantes',
                                'matiere', v_mat, 'requis', v_besoin, 'reserve', v_dispo);
    END IF;
  END LOOP;

  v_caisse := p_pays || '_caserne-militaire';
  SELECT COALESCE((data ->> 'solde')::numeric, 0) INTO v_solde
    FROM public.caisses_batiments WHERE id = v_caisse FOR UPDATE;
  IF NOT FOUND THEN v_solde := 0; END IF;
  IF v_solde < p_cout_revient THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante', 'solde', v_solde);
  END IF;

  SELECT data INTO v_arm FROM public.entreprises WHERE id = p_armurerie FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'armurerie_absente'); END IF;

  FOR v_mat IN SELECT k FROM jsonb_object_keys(COALESCE(p_recette -> 'materiaux', '{}'::jsonb)) k LOOP
    v_reste := COALESCE((p_recette -> 'materiaux' ->> v_mat)::numeric, 0);
    FOR v_id IN SELECT k2 FROM jsonb_object_keys(v_etats) k2 ORDER BY 1 LOOP
      EXIT WHEN v_reste <= 0;
      v_d     := v_etats -> v_id;
      v_ent   := COALESCE(v_d -> 'entrepot', '{}'::jsonb);
      v_stock := COALESCE(v_ent -> 'stock', '{}'::jsonb);
      v_res   := COALESCE(v_ent -> 'reserveMilitaire', '{}'::jsonb);
      v_pris := LEAST(v_reste,
                      GREATEST(0, COALESCE((v_stock ->> v_mat)::numeric, 0)),
                      GREATEST(0, COALESCE((v_res   ->> v_mat)::numeric, 0)));
      CONTINUE WHEN v_pris <= 0;
      v_stock := v_stock || jsonb_build_object(v_mat, COALESCE((v_stock ->> v_mat)::numeric, 0) - v_pris);
      v_res   := v_res   || jsonb_build_object(v_mat, COALESCE((v_res   ->> v_mat)::numeric, 0) - v_pris);
      v_ent   := v_ent   || jsonb_build_object('stock', v_stock, 'reserveMilitaire', v_res);
      v_etats := v_etats || jsonb_build_object(v_id, v_d || jsonb_build_object('entrepot', v_ent));
      v_reste := v_reste - v_pris;
      v_conso := v_conso || jsonb_build_object(v_mat, COALESCE((v_conso ->> v_mat)::numeric, 0) + v_pris);
    END LOOP;
  END LOOP;

  FOR v_id IN SELECT k FROM jsonb_object_keys(v_etats) k ORDER BY 1 LOOP
    UPDATE public.batiments_etat SET data = to_jsonb((v_etats -> v_id)::text), updated_at = now() WHERE id = v_id;
  END LOOP;

  UPDATE public.caisses_batiments
     SET data = COALESCE(data, '{}'::jsonb) || jsonb_build_object('solde', v_solde - p_cout_revient), updated_at = now()
   WHERE id = v_caisse;

  v_arm := COALESCE(v_arm, '{}'::jsonb);
  v_arm := v_arm || jsonb_build_object(
    'caisse', COALESCE((v_arm ->> 'caisse')::numeric, 0) + p_cout_revient,
    'historique', COALESCE(v_arm -> 'historique', '[]'::jsonb) || jsonb_build_array(
      jsonb_build_object('jour', p_jour, 'montant', p_cout_revient,
                         'motif', 'Commande militaire — ' || COALESCE(p_arme_label, ''))));
  UPDATE public.entreprises SET data = v_arm, updated_at = now() WHERE id = p_armurerie;

  v_mvt := public.caserne_stock_mouvement(p_pays, v_cmd.produit, v_parlot, p_lot);
  IF COALESCE((v_mvt ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'caserne_stock_mouvement a echoue: %', v_mvt;
  END IF;

  UPDATE public.commandes_militaires
     SET quantite_produite = quantite_produite + v_parlot,
         statut = CASE WHEN quantite_produite + v_parlot >= quantite_demandee THEN 'terminee' ELSE 'en_cours' END,
         updated_at = now()
   WHERE id = p_commande_id;

  INSERT INTO public.registre_ventes_armes (joueur, arme, prix, pays, city, jour, heure)
  VALUES (COALESCE(v_arm ->> 'proprietaire', 'PNJ'),
          COALESCE(p_arme_label, v_cmd.produit) || ' (commande militaire)',
          round(p_cout_revient)::integer, p_pays, p_ville_arm, COALESCE(p_jour, 1), 0);

  RETURN jsonb_build_object('ok', true, 'produit', v_cmd.produit, 'quantite', v_parlot,
                            'lot', p_lot, 'cout', p_cout_revient, 'matieres', v_conso,
                            'armurerie', p_armurerie,
                            'caisseArmurerie', COALESCE((v_arm ->> 'caisse')::numeric, 0),
                            'caisseCaserne', v_solde - p_cout_revient);
END;
$fn$;

REVOKE ALL ON FUNCTION public.effort_ravitailler(text, jsonb, jsonb, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.effort_produire_lot(text, text, text, jsonb, jsonb, numeric, text, text, text, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.effort_ravitailler(text, jsonb, jsonb, jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.effort_produire_lot(text, text, text, jsonb, jsonb, numeric, text, text, text, integer) TO service_role;