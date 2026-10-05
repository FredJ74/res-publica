-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260917143508
-- Nom original      : armurerie_retrait_reserve_au_lieutenant
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-17 14:35:08 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 60d323ac66900c9fd968222afc0b6400
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
-- ARBITRAGE GD RENDU (17 septembre 2026) : SEUL LE LIEUTENANT RETIRE DE L'ARMURERIE.
--
-- Le Capitaine perd cette prerogative. Jusqu'ici, data.js declarait DEUX ordres de retrait sur le
-- meme stock national avec deux grades : repartir_armement (capitaine) et
-- retirer_armes_militaires (lieutenant). La regle unifie : c'est le chef de section qui puise au
-- magasin, pour sa section -- ce que le code notait deja pour les explosifs (« seul le chef de
-- section peut les sortir du magasin »).
--
-- L'autorite passe donc de « LE capitaine de cette compagnie » a « LE lieutenant de CETTE
-- section », via militaire_section_de_moi -- la meme garde que les cinq operations de section.
-- Consequence directe et voulue : un Lieutenant ne peut doter que SA section, jamais celle d'un
-- autre, et le Capitaine comme le Commandant sont refuses sur cette primitive.
--
-- Rien d'autre ne change : memes produits, memes quantites, meme destination (le stock libre de
-- la section), meme atomicite via caserne_stock_mouvement, meme verrou de session sur l'armurerie.
CREATE OR REPLACE FUNCTION public.militaire_armurerie_transfert(
  p_compagnie_id text, p_section_id text, p_produit text, p_qte integer, p_sens text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE
  g record; v_pays text; v_sec jsonb; v_stock jsonb; v_dispo int; v_mvt jsonb;
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
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = g.o_moi;

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

  RETURN jsonb_build_object('ok', true, 'sens', p_sens, 'produit', p_produit, 'quantite', p_qte,
    'stock_armurerie', v_mvt->'stock', 'stock_section', v_stock->p_produit);
END; $fn$;