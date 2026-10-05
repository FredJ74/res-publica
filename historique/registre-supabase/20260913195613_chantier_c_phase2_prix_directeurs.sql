-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913195613
-- Nom original      : chantier_c_phase2_prix_directeurs
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-13 19:56:13 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : a03fcf8895f518073c414ad21b4ef2b0
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
-- ============================================================================
-- CHANTIER C / PHASE 2 — GROUPE 3 : PRIX ET REPARTITION FIXES PAR LES DIRECTEURS
-- 13 septembre 2026.
-- ============================================================================
-- LE TROU D'AUTORITE. Ces trois ecritures ne verifiaient le poste que dans le
-- navigateur (state.poste?.id), c'est-a-dire nulle part : n'importe quel joueur
-- pouvait fixer les prix d'un entrepot national ou la repartition de production
-- d'une usine. Le poste est desormais relu SUR LA LIGNE du personnage connecte,
-- et le batiment doit etre celui que ce poste dirige -- pas un autre.
--
-- AUCUNE REGLE DE PRIX MODIFIEE : liberte totale du directeur d'entrepot
-- (arbitrage du 24 aout 2026, seules subsistent les protections techniques :
-- nombre fini et strictement positif), fourchette +/-40 % pour la vente directe
-- d'usine, 0 a 100 % pour la repartition.
--
-- CHAQUE RPC N'ECRIT QU'UNE SOUS-CLE. Aucune ne peut servir a toucher un stock
-- ou une caisse : elles reconstruisent l'etat a partir de la ligne relue et n'y
-- remplacent que 'prixManuel' ou 'repartitionEntrepots'.

CREATE OR REPLACE FUNCTION public.fixer_prix_entrepot(
  p_acteur text, p_pays text, p_prix jsonb)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
  v_poste text; v_ville text; v_bat text; v_id text;
  v_etat jsonb; v_entrepot jsonb; v_pm jsonb := '{}'::jsonb;
  v_cle text; v_val numeric;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT poste->>'id', poste->>'city' INTO v_poste, v_ville
  FROM public.personnages_donnees WHERE name = p_acteur;
  IF v_poste IS DISTINCT FROM 'directeur_entrepot' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_non_detenu', 'poste_reel', v_poste);
  END IF;
  SELECT building_id INTO v_bat FROM public.entrepots_par_ville WHERE ville = v_ville;
  IF v_bat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'entrepot_introuvable'); END IF;

  -- Validation AVANT toute ecriture : un seul prix invalide annule l'ensemble.
  FOR v_cle, v_val IN SELECT key, (value #>> '{}')::numeric FROM jsonb_each(coalesce(p_prix,'{}'::jsonb)) LOOP
    IF NOT EXISTS (SELECT 1 FROM public.ressources_economie WHERE cle = v_cle) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'ressource_inconnue', 'cle', v_cle);
    END IF;
    IF v_val IS NULL OR v_val <= 0 OR NOT (v_val = v_val) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'prix_invalide', 'cle', v_cle);
    END IF;
    v_pm := jsonb_set(v_pm, ARRAY[v_cle], to_jsonb(round(v_val, 2)));
  END LOOP;

  v_id := p_pays || '_' || v_ville || '_' || v_bat;
  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'entrepot_introuvable'); END IF;
  v_entrepot := coalesce(v_etat->'entrepot', '{}'::jsonb);

  UPDATE public.batiments_etat
     SET data = to_jsonb((v_etat || jsonb_build_object('entrepot',
           v_entrepot || jsonb_build_object('prixManuel', v_pm)))::text), updated_at = now()
   WHERE id = v_id;
  RETURN jsonb_build_object('ok', true, 'prixManuel', v_pm, 'batiment', v_bat);
END; $$;

CREATE OR REPLACE FUNCTION public.fixer_prix_vente_directe(
  p_acteur text, p_pays text, p_prix jsonb)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
  v_poste text; v_ville text; v_bat text; v_produits jsonb; v_id text;
  v_etat jsonb; v_usine jsonb; v_pm jsonb := '{}'::jsonb;
  v_cle text; v_val numeric; v_base numeric; v_min numeric; v_max numeric;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT poste->>'id' INTO v_poste FROM public.personnages_donnees WHERE name = p_acteur;
  SELECT ville, building_id, produits INTO v_ville, v_bat, v_produits
  FROM public.directeurs_usine WHERE poste_id = v_poste;
  IF v_bat IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_non_detenu', 'poste_reel', v_poste);
  END IF;

  FOR v_cle, v_val IN SELECT key, (value #>> '{}')::numeric FROM jsonb_each(coalesce(p_prix,'{}'::jsonb)) LOOP
    IF NOT (v_produits ? v_cle) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'produit_hors_usine', 'cle', v_cle);
    END IF;
    SELECT prix_base INTO v_base FROM public.ressources_economie WHERE cle = v_cle;
    IF v_base IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'ressource_inconnue', 'cle', v_cle); END IF;
    -- Fourchette +/-40 %, arrondie au centime, exactement comme cote client.
    v_min := round(v_base * 0.6, 2); v_max := round(v_base * 1.4, 2);
    IF v_val IS NULL OR v_val < v_min OR v_val > v_max THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'prix_hors_fourchette',
                                'cle', v_cle, 'min', v_min, 'max', v_max);
    END IF;
    v_pm := jsonb_set(v_pm, ARRAY[v_cle], to_jsonb(round(v_val, 2)));
  END LOOP;

  v_id := p_pays || '_' || v_ville || '_' || v_bat;
  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'usine_introuvable'); END IF;
  v_usine := coalesce(v_etat->'usine', '{}'::jsonb);
  UPDATE public.batiments_etat
     SET data = to_jsonb((v_etat || jsonb_build_object('usine',
           v_usine || jsonb_build_object('prixManuel', v_pm)))::text), updated_at = now()
   WHERE id = v_id;
  RETURN jsonb_build_object('ok', true, 'prixManuel', v_pm, 'batiment', v_bat);
END; $$;

CREATE OR REPLACE FUNCTION public.fixer_repartition_production(
  p_acteur text, p_pays text, p_pourcentage numeric)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
  v_poste text; v_ville text; v_bat text; v_id text; v_etat jsonb; v_usine jsonb;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT poste->>'id' INTO v_poste FROM public.personnages_donnees WHERE name = p_acteur;
  SELECT ville, building_id INTO v_ville, v_bat FROM public.directeurs_usine WHERE poste_id = v_poste;
  IF v_bat IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_non_detenu', 'poste_reel', v_poste);
  END IF;
  IF p_pourcentage IS NULL OR p_pourcentage < 0 OR p_pourcentage > 100 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'valeur_invalide');
  END IF;

  v_id := p_pays || '_' || v_ville || '_' || v_bat;
  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'usine_introuvable'); END IF;
  v_usine := coalesce(v_etat->'usine', '{}'::jsonb);
  UPDATE public.batiments_etat
     SET data = to_jsonb((v_etat || jsonb_build_object('usine',
           v_usine || jsonb_build_object('repartitionEntrepots', p_pourcentage / 100)))::text),
         updated_at = now()
   WHERE id = v_id;
  RETURN jsonb_build_object('ok', true, 'repartitionEntrepots', p_pourcentage / 100, 'batiment', v_bat);
END; $$;

REVOKE ALL ON FUNCTION public.fixer_prix_entrepot(text,text,jsonb) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fixer_prix_vente_directe(text,text,jsonb) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fixer_repartition_production(text,text,numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fixer_prix_entrepot(text,text,jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fixer_prix_vente_directe(text,text,jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fixer_repartition_production(text,text,numeric) TO authenticated;