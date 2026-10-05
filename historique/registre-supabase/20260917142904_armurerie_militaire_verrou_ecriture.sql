-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260917142904
-- Nom original      : armurerie_militaire_verrou_ecriture
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-17 14:29:04 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 66e29cad23611d3afe4202068d5dc8a8
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
-- LOT B (suite) — FERMER REELLEMENT L'ANCIEN CHEMIN, PAS SEULEMENT LE DEBRANCHER DU CLIENT
--
-- CONSTAT : budgets_nationaux porte une RLS totalement ouverte (« Maj publique budgets nationaux »,
-- role public, UPDATE, USING true). Migrer confirmerTransfertArmement vers une RPC attestee ne
-- suffisait donc pas : un appel REST direct pouvait toujours reecrire le blob et se servir dans
-- stockArmurerieMilitaire.
--
-- POURQUOI PAS FERMER LA TABLE : budgets_nationaux porte aussi la reserve fiscale, le refectoire,
-- la recherche militaire, les virements journaliers, les greves... ecrits par de nombreux chemins
-- clients legitimes. La fermer casserait tout cela.
--
-- SOLUTION CHIRURGICALE : un laissez-passer de session local a la transaction, idiome deja utilise
-- dans ce projet. caserne_stock_mouvement -- la SEULE primitive autorisee a bouger l'armurerie --
-- le pose avant d'ecrire ; un trigger restaure les deux cles protegees pour toute autre ecriture.
-- Le refus est SILENCIEUX (restauration de l'ancienne valeur), sur le modele du trigger
-- personnages_attester_poste. Le reste du budget national continue de s'ecrire comme avant.
-- Valeur par defaut du parametre p_lot conservee a l'identique.
CREATE OR REPLACE FUNCTION public.caserne_stock_mouvement(
  p_pays text, p_produit text, p_delta integer, p_lot text DEFAULT NULL::text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE
  v_data jsonb; v_stock jsonb; v_lots jsonb; v_file jsonb;
  v_cur integer; v_reste integer; v_servis jsonb := '[]'::jsonb;
  v_tete jsonb; v_q integer; v_pris integer;
BEGIN
  IF COALESCE(btrim(p_pays), '') = '' OR COALESCE(btrim(p_produit), '') = ''
     OR p_delta IS NULL OR p_delta = 0 OR abs(p_delta) > 100000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  IF p_delta > 0 AND COALESCE(btrim(p_lot), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'lot_obligatoire');
  END IF;

  SELECT data INTO v_data FROM public.budgets_nationaux WHERE id = p_pays FOR UPDATE;
  IF NOT FOUND THEN
    IF p_delta < 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'stock_insuffisant', 'stock', 0); END IF;
    v_data := '{}'::jsonb;
    INSERT INTO public.budgets_nationaux (id, data, updated_at) VALUES (p_pays, v_data, now());
  END IF;
  v_data := COALESCE(v_data, '{}'::jsonb);

  v_stock := CASE WHEN jsonb_typeof(v_data -> 'stockArmurerieMilitaire') = 'object'
                  THEN v_data -> 'stockArmurerieMilitaire' ELSE '{}'::jsonb END;
  v_lots  := CASE WHEN jsonb_typeof(v_data -> 'lotsMilitaires') = 'object'
                  THEN v_data -> 'lotsMilitaires' ELSE '{}'::jsonb END;
  v_cur   := GREATEST(0, COALESCE((v_stock ->> p_produit)::integer, 0));
  v_file  := CASE WHEN jsonb_typeof(v_lots -> p_produit) = 'array'
                  THEN v_lots -> p_produit ELSE '[]'::jsonb END;

  IF v_cur + p_delta < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_insuffisant', 'stock', v_cur);
  END IF;

  IF p_delta > 0 THEN
    v_file := v_file || jsonb_build_array(jsonb_build_object('lot', p_lot, 'qte', p_delta));
  ELSE
    v_reste := -p_delta;
    WHILE v_reste > 0 AND jsonb_array_length(v_file) > 0 LOOP
      v_tete := v_file -> 0;
      v_q    := GREATEST(0, COALESCE((v_tete ->> 'qte')::integer, 0));
      v_pris := LEAST(v_q, v_reste);
      IF v_pris > 0 THEN
        v_servis := v_servis || jsonb_build_array(jsonb_build_object('lot', v_tete ->> 'lot', 'qte', v_pris));
        v_reste := v_reste - v_pris;
      END IF;
      IF v_q - v_pris <= 0 THEN v_file := v_file - 0;
      ELSE v_file := jsonb_set(v_file, ARRAY['0','qte'], to_jsonb(v_q - v_pris)); END IF;
    END LOOP;
    IF v_reste > 0 THEN
      v_servis := v_servis || jsonb_build_array(jsonb_build_object('lot', 'legacy', 'qte', v_reste));
    END IF;
  END IF;

  v_stock := v_stock || jsonb_build_object(p_produit, v_cur + p_delta);
  v_lots  := v_lots  || jsonb_build_object(p_produit, v_file);
  v_data  := v_data  || jsonb_build_object('stockArmurerieMilitaire', v_stock, 'lotsMilitaires', v_lots);

  PERFORM set_config('rp.armurerie_militaire', '1', true);
  UPDATE public.budgets_nationaux SET data = v_data, updated_at = now() WHERE id = p_pays;
  PERFORM set_config('rp.armurerie_militaire', '', true);

  RETURN jsonb_build_object('ok', true, 'produit', p_produit, 'stock', v_cur + p_delta, 'lots', v_servis);
END; $fn$;

CREATE OR REPLACE FUNCTION public.budgets_armurerie_verrou()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
BEGIN
  IF public.est_appel_serveur() THEN RETURN NEW; END IF;
  IF COALESCE(current_setting('rp.armurerie_militaire', true), '') = '1' THEN RETURN NEW; END IF;

  IF (NEW.data -> 'stockArmurerieMilitaire') IS DISTINCT FROM (OLD.data -> 'stockArmurerieMilitaire') THEN
    NEW.data := CASE WHEN (OLD.data -> 'stockArmurerieMilitaire') IS NULL
                     THEN NEW.data - 'stockArmurerieMilitaire'
                     ELSE jsonb_set(NEW.data, '{stockArmurerieMilitaire}', OLD.data -> 'stockArmurerieMilitaire') END;
  END IF;
  IF (NEW.data -> 'lotsMilitaires') IS DISTINCT FROM (OLD.data -> 'lotsMilitaires') THEN
    NEW.data := CASE WHEN (OLD.data -> 'lotsMilitaires') IS NULL
                     THEN NEW.data - 'lotsMilitaires'
                     ELSE jsonb_set(NEW.data, '{lotsMilitaires}', OLD.data -> 'lotsMilitaires') END;
  END IF;
  RETURN NEW;
END; $fn$;

DROP TRIGGER IF EXISTS budgets_armurerie_verrou ON public.budgets_nationaux;
CREATE TRIGGER budgets_armurerie_verrou
  BEFORE UPDATE ON public.budgets_nationaux
  FOR EACH ROW EXECUTE FUNCTION public.budgets_armurerie_verrou();