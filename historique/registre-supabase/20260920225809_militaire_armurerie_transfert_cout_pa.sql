-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920225809
-- Nom original      : militaire_armurerie_transfert_cout_pa
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-20 22:58:09 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : faf295d98d3edaef7c8febc13b355100
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
-- =====================================================================================
-- « Doter ma section en armement » : 1 PA AFFICHE, 1 PA REELLEMENT PRELEVE (21 sept. 2026)
-- =====================================================================================
-- data.js declare repartir_armement a 1 PA et le miroir porte deja le couple
-- ('repartir_armement',1,0) -- mais ni ouvrirRepartirArmement ni confirmerTransfertArmement
-- n'appelaient deduireCoutOrdre : le triplet n'etait JAMAIS consulte et l'ordre etait gratuit.
-- Le prelevement est pose ICI plutot que dans le navigateur : le transfert est deja une
-- transaction serveur atomique (stock national + stock de section), le cout en fait partie et
-- ne depend donc plus du client. UN mouvement = UN PA, dans les deux sens : sortir des armes du
-- magasin comme les y rendre est un acte de commandement, et le client ne peut plus obtenir
-- l'effet sans la contrepartie.
--
-- Le corps d'origine est conserve a l'identique (autorite : le Lieutenant de CETTE section,
-- memes produits, memes quantites, meme primitive caserne_stock_mouvement). Deux ajouts :
-- une verification prealable des PA (pour rendre un refus lisible plutot qu'une exception)
-- et l'appel a payer_ordre a la fin, sous la meme transaction -- un paiement refuse annule
-- l'ensemble du transfert.
CREATE OR REPLACE FUNCTION public.militaire_armurerie_transfert(p_compagnie_id text, p_section_id text, p_produit text, p_qte integer, p_sens text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  c_pa constant integer := 1;
  g record; v_pays text; v_sec jsonb; v_stock jsonb; v_dispo int; v_mvt jsonb;
  v_pa int; v_paye jsonb;
BEGIN
  IF p_produit NOT IN ('arme_de_poing', 'mitraillette') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'produit_invalide');
  END IF;
  IF COALESCE(p_qte, 0) <= 0 OR p_qte > 100000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide');
  END IF;
  IF p_sens NOT IN ('vers_section', 'vers_armurerie') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'sens_invalide');
  END IF;

  -- AUTORITE : le lieutenant de CETTE section. Refuse le capitaine, le commandant et tout autre.
  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;
  SELECT country, COALESCE(pa, 0) INTO v_pays, v_pa
    FROM public.personnages_donnees WHERE name = g.o_moi FOR UPDATE;

  -- COUT DE L'ORDRE, verifie AVANT tout mouvement de stock : un refus doit etre lisible.
  IF COALESCE(v_pa, 0) < c_pa THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants',
                              'requis', c_pa, 'pa_reel', COALESCE(v_pa, 0));
  END IF;

  SELECT s INTO v_sec FROM jsonb_array_elements(g.o_data->'sections') s WHERE s->>'id' = p_section_id;
  v_stock := CASE WHEN jsonb_typeof(v_sec->'stockArmes') = 'object' THEN v_sec->'stockArmes'
                  ELSE jsonb_build_object('arme_de_poing',0,'mitraillette',0) END;

  IF p_sens = 'vers_section' THEN
    v_mvt := public.caserne_stock_mouvement(v_pays, p_produit, -p_qte, NULL);
    IF COALESCE((v_mvt->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_mvt; END IF;
    v_stock := v_stock || jsonb_build_object(p_produit,
                 GREATEST(0, COALESCE((v_stock->>p_produit)::int, 0)) + p_qte);
  ELSE
    v_dispo := GREATEST(0, COALESCE((v_stock->>p_produit)::int, 0));
    IF v_dispo < p_qte THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'stock_section_insuffisant', 'disponible', v_dispo);
    END IF;
    v_stock := v_stock || jsonb_build_object(p_produit, v_dispo - p_qte);
    v_mvt := public.caserne_stock_mouvement(v_pays, p_produit, p_qte, 'retour-' || p_section_id);
    IF COALESCE((v_mvt->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_mvt; END IF;
  END IF;

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(g.o_data, p_section_id,
                  v_sec || jsonb_build_object('stockArmes', v_stock))
   WHERE id = p_compagnie_id;

  -- PAIEMENT ATTESTE (miroir ordres_couts). En cas de refus, l'exception annule aussi le
  -- mouvement de stock : jamais d'armes transferees sans PA preleves.
  v_paye := public.payer_ordre(g.o_moi, 'repartir_armement', c_pa, 0);
  IF NOT COALESCE((v_paye->>'ok')::boolean, false) THEN
    RAISE EXCEPTION 'militaire_armurerie_transfert: paiement refuse (%)',
      COALESCE(v_paye->>'raison', 'motif inconnu');
  END IF;

  RETURN jsonb_build_object('ok', true, 'sens', p_sens, 'produit', p_produit, 'quantite', p_qte,
    'stock_armurerie', v_mvt->'stock', 'stock_section', v_stock->p_produit,
    'pa', v_paye->'pa', 'pa_preleves', c_pa);
END; $function$;

REVOKE ALL ON FUNCTION public.militaire_armurerie_transfert(text, text, text, integer, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_armurerie_transfert(text, text, text, integer, text) TO authenticated, service_role;