-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260917142610
-- Nom original      : militaire_armurerie_transfert_atteste
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-17 14:26:10 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : ef9a73a944ebe5bfd05ffbdc852c461b
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
-- LOT B — DOUBLE CIRCUIT DE L'ARMURERIE MILITAIRE
--
-- CONSTAT PROUVE : deux chemins ecrivent le MEME stock, budgets_nationaux.data.stockArmurerieMilitaire.
--   * militaire_retrait -> caserne_stock_mouvement : RPC attestee, SELECT ... FOR UPDATE, file de
--     lots FIFO, registre retraits_materiel_militaire. Exige lieutenant + presence a la caserne.
--   * confirmerTransfertArmement (repartir_armement, capitaine) : chargerBudgetNational puis
--     sbSaveBudgetNational -- lecture-modification-reecriture CLIENTE du blob national entier,
--     sans verrou, sans autorite serveur.
--
-- TROIS DEFAUTS DU CHEMIN CLIENT, tous corriges ici :
--   1. Aucune autorite serveur : la garde « capitaine » etait cote client, donc contournable par
--      un appel direct -- n'importe quel joueur pouvait vider l'armurerie nationale.
--   2. Reecriture du blob ENTIER de budgets_nationaux : une repartition d'armement ecrasait au
--      passage toute modification concurrente du budget national (reserve fiscale, refectoire,
--      recherche militaire...), qui vivent dans le meme document.
--   3. DESYNCHRONISATION DES LOTS : le chemin client decrementait stockArmurerieMilitaire sans
--      jamais toucher lotsMilitaires. Le stock et sa file de lots divergeaient, et
--      militaire_retrait servait ensuite des lots fantomes etiquetes 'legacy'.
--
-- CETTE RPC NE CHANGE AUCUNE REGLE DE JEU. Meme autorite qu'aujourd'hui (le Capitaine de CETTE
-- compagnie, comme data.js le declare pour repartir_armement), memes produits, memes quantites,
-- meme destination. Elle passe simplement par caserne_stock_mouvement -- la primitive atomique que
-- militaire_retrait utilise deja -- au lieu de reecrire le blob, et fait les deux mouvements
-- (armurerie et section) dans UNE SEULE transaction.
--
-- ARBITRAGE SIGNALE, NON TRANCHE ICI : data.js declare DEUX ordres de retrait sur ce meme stock,
-- avec deux grades differents -- repartir_armement (capitaine, ligne 4546) et
-- retirer_armes_militaires (lieutenant, ligne 4576). La regle de game design confirmee dit
-- « seul le Lieutenant peut sortir du materiel de l'armurerie ». Changer repartir_armement de
-- grade retirerait une prerogative au Capitaine : c'est une decision de design, pas un correctif.
-- L'autorite actuelle est donc PRESERVEE telle quelle, et la question est posee au rapport.
CREATE OR REPLACE FUNCTION public.militaire_armurerie_transfert(
  p_compagnie_id text, p_section_id text, p_produit text, p_qte integer, p_sens text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE
  v_moi text; v_pays text; v_data jsonb; v_sec jsonb; v_stock jsonb;
  v_dispo int; v_mvt jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_produit NOT IN ('arme_de_poing', 'mitraillette') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'produit_invalide');
  END IF;
  IF COALESCE(p_qte, 0) <= 0 OR p_qte > 100000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide');
  END IF;
  IF p_sens NOT IN ('vers_section', 'vers_armurerie') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'sens_invalide');
  END IF;

  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = p_compagnie_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;
  IF v_data->>'pays' IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction');
  END IF;
  -- AUTORITE : le Capitaine de CETTE compagnie, exactement comme data.js le declare.
  IF v_data->>'capitaineNom' IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_capitaine_de_cette_compagnie');
  END IF;

  SELECT s INTO v_sec FROM jsonb_array_elements(COALESCE(v_data->'sections','[]'::jsonb)) s
   WHERE s->>'id' = p_section_id LIMIT 1;
  IF v_sec IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'section_introuvable'); END IF;
  v_stock := CASE WHEN jsonb_typeof(v_sec->'stockArmes') = 'object' THEN v_sec->'stockArmes'
                  ELSE jsonb_build_object('arme_de_poing',0,'mitraillette',0) END;

  IF p_sens = 'vers_section' THEN
    -- Sortie d'armurerie : la primitive atomique tranche, verrou et file de lots compris.
    v_mvt := public.caserne_stock_mouvement(v_pays, p_produit, -p_qte, NULL);
    IF COALESCE((v_mvt->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_mvt; END IF;
    v_stock := v_stock || jsonb_build_object(p_produit,
                 GREATEST(0, COALESCE((v_stock->>p_produit)::int, 0)) + p_qte);
  ELSE
    -- Retour : on verifie d'abord le stock LIBRE de la section (le reste est porte par les
    -- soldats), puis on rend a l'armurerie. Le lot 'retour-<section>' preserve la tracabilite
    -- que le chemin client detruisait en ignorant purement et simplement lotsMilitaires.
    v_dispo := GREATEST(0, COALESCE((v_stock->>p_produit)::int, 0));
    IF v_dispo < p_qte THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'stock_section_insuffisant', 'disponible', v_dispo);
    END IF;
    v_stock := v_stock || jsonb_build_object(p_produit, v_dispo - p_qte);
    v_mvt := public.caserne_stock_mouvement(v_pays, p_produit, p_qte, 'retour-' || p_section_id);
    IF COALESCE((v_mvt->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_mvt; END IF;
  END IF;

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(v_data, p_section_id,
                  v_sec || jsonb_build_object('stockArmes', v_stock))
   WHERE id = p_compagnie_id;

  RETURN jsonb_build_object('ok', true, 'sens', p_sens, 'produit', p_produit, 'quantite', p_qte,
    'stock_armurerie', v_mvt->'stock', 'stock_section', v_stock->p_produit);
END; $fn$;
REVOKE EXECUTE ON FUNCTION public.militaire_armurerie_transfert(text,text,text,integer,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_armurerie_transfert(text,text,text,integer,text) TO authenticated;