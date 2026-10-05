-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913212808
-- Nom original      : chantier_c_phase3_rpc_propriete
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-13 21:28:08 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : e3f8b9c38179823ced4b4485d1ae808a
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
-- CHANTIER C / PHASE 3 — FAMILLE 6, LES QUATRE RPC DE PROPRIETE.
--
-- Les quatre sites clients ecrivaient le blob complet pour poser un compromis, transferer la
-- propriete, ou marquer une preemption -- en prenant le prix, l'acompte et les termes du pret
-- dans leur propre catalogue, et en mutant state.arg directement (sans meme passer par
-- deduireCoutOrdre pour l'acompte et le solde). Tout est desormais relu et arrete au serveur.

-- 1. Signer un compromis : reserve une entreprise PNJ 7 jours contre un acompte.
CREATE OR REPLACE FUNCTION public.entreprise_signer_compromis(
  p_acteur text, p_entreprise text, p_pret_montant numeric DEFAULT NULL,
  p_pret_duree integer DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_data jsonb; v_acompte numeric; v_plafond numeric; v_taux numeric;
  v_total numeric; v_pret jsonb; v_expire bigint; v_maintenant bigint;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_entreprise FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  IF COALESCE(v_data->>'proprietaire','') <> 'PNJ' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_rachetable');
  END IF;
  IF public.entreprise_prix_rachat(v_data) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_rachetable');
  END IF;

  v_maintenant := (extract(epoch from now()) * 1000)::bigint;
  v_expire := COALESCE((v_data->>'compromisExpireAt')::bigint, 0);
  IF COALESCE((v_data->>'compromis')::boolean, false) AND v_expire > v_maintenant THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_reservee',
                              'par', v_data->>'compromisPar');
  END IF;

  SELECT valeur INTO v_acompte FROM public.entreprises_constantes WHERE cle = 'acompte_compromis';
  IF NOT public.helvetia_debiter_fonds_ordinaires(p_acteur, v_acompte) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'acompte', v_acompte);
  END IF;

  v_data := v_data || jsonb_build_object(
    'compromis', true, 'compromisPar', p_acteur, 'acompte', v_acompte,
    'compromisAt', v_maintenant, 'compromisExpireAt', v_maintenant + 7 * 86400000);

  IF p_pret_montant IS NOT NULL AND p_pret_montant > 0 THEN
    SELECT valeur INTO v_plafond FROM public.entreprises_constantes WHERE cle = 'plafond_pret_compromis';
    IF p_pret_montant > COALESCE(v_plafond, 0) OR COALESCE(p_pret_duree,0) <= 0 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pret_hors_bornes', 'plafond', v_plafond);
    END IF;
    -- Le taux n'est PAS transmis : il est recalcule depuis l'indice economique reel du pays.
    v_taux  := public.taux_pret_nationale(COALESCE(v_data->>'country','republic'));
    v_total := round(p_pret_montant * (1 + v_taux / 100));
    v_pret  := jsonb_build_object('demandeur', p_acteur, 'montant', p_pret_montant,
                 'montantTotal', v_total, 'duree', p_pret_duree,
                 'mensualite', ceil(v_total / p_pret_duree), 'statut', 'attente_validation');
    v_data := jsonb_set(v_data, '{pretDemande}', v_pret, true);
  END IF;

  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_entreprise;
  RETURN jsonb_build_object('ok', true, 'acompte', v_acompte,
    'expireAt', v_maintenant + 7 * 86400000, 'pret', v_pret,
    'arg', (SELECT arg FROM public.personnages_donnees WHERE name = p_acteur),
    'liquide', (SELECT liquide FROM public.personnages_donnees WHERE name = p_acteur));
END; $$;

-- 2. Acte de rachat : transfere la propriete contre le solde (prix - acompte).
CREATE OR REPLACE FUNCTION public.entreprise_acte_rachat(
  p_acteur text, p_entreprise text, p_ordre text DEFAULT NULL,
  p_pa integer DEFAULT 0, p_cost integer DEFAULT 0)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_data jsonb; v_prix numeric; v_solde numeric; v_r jsonb; v_jour integer;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_entreprise FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  IF COALESCE((v_data->>'compromis')::boolean, false) IS NOT TRUE
     OR (v_data->>'compromisPar') IS DISTINCT FROM p_acteur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_votre_compromis');
  END IF;
  IF COALESCE(v_data->'pretDemande'->>'statut','') = 'attente_validation' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pret_en_attente');
  END IF;

  v_prix := public.entreprise_prix_rachat(v_data);
  IF v_prix IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'prix_inconnu'); END IF;
  v_solde := GREATEST(0, v_prix - COALESCE((v_data->>'acompte')::numeric, 0));

  IF COALESCE(p_ordre,'') <> '' THEN
    v_r := public.payer_ordre(p_acteur, p_ordre, COALESCE(p_pa,0), COALESCE(p_cost,0));
    IF COALESCE((v_r->>'ok')::boolean, false) IS NOT TRUE THEN
      RETURN jsonb_build_object('ok', false, 'raison', COALESCE(v_r->>'raison','paiement_refuse'));
    END IF;
  END IF;

  IF NOT public.helvetia_debiter_fonds_ordinaires(p_acteur, v_solde) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'solde', v_solde);
  END IF;

  SELECT COALESCE(day,1) INTO v_jour FROM public.personnages_donnees WHERE name = p_acteur;
  v_data := (v_data - 'compromis' - 'compromisPar' - 'acompte' - 'compromisAt'
                    - 'compromisExpireAt')
            || jsonb_build_object('proprietaire', p_acteur);
  v_data := public.entreprise_ajouter_historique(v_data, 0,
              'Rachat de l''entreprise par ' || p_acteur || ' (acte notarié)', v_jour);
  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_entreprise;

  RETURN jsonb_build_object('ok', true, 'prix', v_prix, 'solde', v_solde,
    'arg', (SELECT arg FROM public.personnages_donnees WHERE name = p_acteur),
    'liquide', (SELECT liquide FROM public.personnages_donnees WHERE name = p_acteur),
    'pa', (SELECT pa FROM public.personnages_donnees WHERE name = p_acteur));
END; $$;

-- 3. Preemption : le Ministre des Finances reserve une entreprise pour l'Etat.
CREATE OR REPLACE FUNCTION public.entreprise_preempter(
  p_acteur text, p_entreprise text, p_montant numeric, p_duree integer)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_data jsonb; v_prix numeric; v_pays text; v_taux numeric; v_total numeric;
  v_maintenant bigint; v_r jsonb;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  PERFORM public.exiger_poste('min_fin');

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_entreprise FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  IF COALESCE(v_data->>'proprietaire','') <> 'PNJ' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_preemptable');
  END IF;
  v_maintenant := (extract(epoch from now()) * 1000)::bigint;
  IF (COALESCE((v_data->>'compromis')::boolean, false)
      AND COALESCE((v_data->>'compromisExpireAt')::bigint,0) > v_maintenant)
     OR COALESCE(v_data->>'preemptionEtat','') <> '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_preemptable');
  END IF;

  v_prix := public.entreprise_prix_rachat(v_data);
  IF v_prix IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'prix_inconnu'); END IF;
  IF p_montant IS NULL OR p_montant < v_prix OR COALESCE(p_duree,0) <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_insuffisant', 'prix', v_prix);
  END IF;

  v_pays  := COALESCE(v_data->>'country','republic');
  v_taux  := public.taux_pret_nationale(v_pays);
  v_total := round(p_montant * (1 + v_taux / 100));

  -- Mouvements institutionnels atomiques, jamais une lecture-modification-ecriture cliente.
  PERFORM public.caisse_institution_mouvement(v_pays || '_gouvernement-min_fin', p_montant, false);
  v_r := public.caisse_institution_mouvement(v_pays || '_gouvernement-min_fin', -v_prix, false);
  IF COALESCE((v_r->>'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante');
  END IF;

  v_data := v_data || jsonb_build_object('preemptionEtat', 'attente_acte',
                                         'preemptionPar', p_acteur);
  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_entreprise;

  RETURN jsonb_build_object('ok', true, 'prix', v_prix, 'montant', p_montant,
    'montantTotal', v_total, 'mensualite', ceil(v_total / p_duree), 'taux', v_taux);
END; $$;

-- 4. Acte de preemption : la propriete passe a l'Etat.
CREATE OR REPLACE FUNCTION public.entreprise_acte_preemption(
  p_acteur text, p_entreprise text, p_libelle_etat text,
  p_ordre text DEFAULT NULL, p_pa integer DEFAULT 0, p_cost integer DEFAULT 0)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_data jsonb; v_r jsonb; v_jour integer;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  PERFORM public.exiger_poste('min_fin');

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_entreprise FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  IF COALESCE(v_data->>'preemptionEtat','') <> 'attente_acte' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'preemption_introuvable');
  END IF;

  IF COALESCE(p_ordre,'') <> '' THEN
    v_r := public.payer_ordre(p_acteur, p_ordre, COALESCE(p_pa,0), COALESCE(p_cost,0));
    IF COALESCE((v_r->>'ok')::boolean, false) IS NOT TRUE THEN
      RETURN jsonb_build_object('ok', false, 'raison', COALESCE(v_r->>'raison','paiement_refuse'));
    END IF;
  END IF;

  SELECT COALESCE(day,1) INTO v_jour FROM public.personnages_donnees WHERE name = p_acteur;
  v_data := (v_data - 'preemptionEtat' - 'preemptionPar')
            || jsonb_build_object('proprietaire',
                 COALESCE(NULLIF(btrim(COALESCE(p_libelle_etat,'')),''), 'État'));
  v_data := public.entreprise_ajouter_historique(v_data, 0,
              'Préemption par l''État, officialisée par le Ministre des Finances', v_jour);
  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_entreprise;

  RETURN jsonb_build_object('ok', true, 'proprietaire', v_data->>'proprietaire',
    'pa', (SELECT pa FROM public.personnages_donnees WHERE name = p_acteur));
END; $$;

DO $$
DECLARE r record; v text;
BEGIN
  FOR r IN SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS a
             FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
            WHERE n.nspname='public' AND p.proname IN
              ('entreprise_signer_compromis','entreprise_acte_rachat',
               'entreprise_preempter','entreprise_acte_preemption')
  LOOP
    v := format('public.%I(%s)', r.proname, r.a);
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon', v);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated, service_role', v);
  END LOOP;
END $$;
