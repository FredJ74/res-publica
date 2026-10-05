-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913232209
-- Nom original      : chantier_c_fabriquer_produit_pa
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-13 23:22:09 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : f5b4308d78d502b75794d26d5c060bf5
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
-- CHANTIER C (14 septembre 2026). Le PA de fabrication etait preleve separement par le client,
-- via payer_ordre -- qui le REFUSAIT des que la recette ne coutait pas exactement les 3 PA
-- declares par l'ordre fabriquer_armoire_souvenirs. Le PA de fabrication est une donnee de la
-- RECETTE, deja presente dans le miroir produits_manufactures : la RPC le prend en charge.
-- Le prelevement du PA et la mutation de l'atelier sont ainsi dans la meme transaction.
CREATE OR REPLACE FUNCTION public.fabriquer_produit_manufacture(
  p_acteur text, p_pays text, p_produit text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_ville text; v_bat text; v_recette jsonb; v_id text; v_pa_requis integer;
  v_etat jsonb; v_usine jsonb; v_sm jsonb; v_sp jsonb;
  v_cle text; v_q numeric; v_manque text; v_pa integer;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT ville, building_id, recette, COALESCE(pa, 0)
    INTO v_ville, v_bat, v_recette, v_pa_requis
  FROM public.produits_manufactures WHERE produit = p_produit;
  IF v_ville IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'produit_inconnu'); END IF;

  v_id := p_pays || '_' || v_ville || '_' || v_bat;
  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'atelier_introuvable'); END IF;
  v_usine := coalesce(v_etat->'usine', '{}'::jsonb);
  v_sm := coalesce(v_usine->'stockMatieres', '{}'::jsonb);
  v_sp := coalesce(v_usine->'stockProduits', '{}'::jsonb);

  -- Verification COMPLETE avant toute mutation : refus sans mutation partielle.
  FOR v_cle, v_q IN SELECT key, (value #>> '{}')::numeric FROM jsonb_each(v_recette) LOOP
    IF coalesce((v_sm->>v_cle)::numeric, 0) < v_q THEN v_manque := v_cle; EXIT; END IF;
  END LOOP;
  IF v_manque IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_insuffisant', 'matiere', v_manque);
  END IF;

  -- PA du fabricant, lu dans la recette miroir. Verifie AVANT toute mutation, comme le stock.
  SELECT COALESCE(pa, 0) INTO v_pa FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_pa IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  IF v_pa < v_pa_requis THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants',
                              'requis', v_pa_requis, 'pa_reel', v_pa);
  END IF;

  FOR v_cle, v_q IN SELECT key, (value #>> '{}')::numeric FROM jsonb_each(v_recette) LOOP
    v_sm := jsonb_set(v_sm, ARRAY[v_cle], to_jsonb(coalesce((v_sm->>v_cle)::numeric,0) - v_q));
  END LOOP;
  v_sp := jsonb_set(v_sp, ARRAY[p_produit], to_jsonb(coalesce((v_sp->>p_produit)::numeric,0) + 1));

  UPDATE public.batiments_etat
     SET data = to_jsonb((v_etat || jsonb_build_object('usine',
           v_usine || jsonb_build_object('stockMatieres', v_sm, 'stockProduits', v_sp)))::text),
         updated_at = now()
   WHERE id = v_id;

  IF v_pa_requis > 0 THEN
    UPDATE public.personnages_donnees SET pa = v_pa - v_pa_requis, updated_at = now()
     WHERE name = p_acteur;
  END IF;

  RETURN jsonb_build_object('ok', true, 'stock_produit', coalesce((v_sp->>p_produit)::numeric,0),
    'paConsommes', v_pa_requis, 'pa', v_pa - v_pa_requis);
END; $$;

REVOKE EXECUTE ON FUNCTION public.fabriquer_produit_manufacture(text,text,text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fabriquer_produit_manufacture(text,text,text) TO authenticated, service_role;
