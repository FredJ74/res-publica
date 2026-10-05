-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920091040
-- Nom original      : caisse_primitive_heritee_durcie
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-20 09:10:40 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 4d635ae3fafac5719fd5cd360ec65b36
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
-- =====================================================================
-- LA PRIMITIVE HERITEE EST DURCIE SANS TOUCHER AU CLIENT DEPLOYE
-- =====================================================================
-- CONSTAT FACTUEL. Le bundle reellement servi en production (verifie par requete
-- HTTP : supabase.js?v=222) appelle caisse_institution_mouvement 3 fois et
-- _plafonne 1 fois, et n'appelle JAMAIS caisse_client_mouvement. Le durcissement
-- du lot precedent ne protegeait donc rien en production : l'exploit « un citoyen
-- vide n'importe quelle caisse » y restait entierement ouvert.
--
-- Revoquer casserait le client deploye. Et est_appel_serveur() ne distingue pas
-- l'appel interne de l'appel direct : une RPC SECURITY DEFINER declenchee par un
-- joueur porte toujours ses claims ET son SET ROLE.
--
-- D'OU LE MARQUEUR rp.caisse_interne, pose en tete des 13 appelants par la
-- migration precedente. Ils portent deja chacun leur propre controle d'autorite
-- metier ; c'est l'appel DIRECT depuis le navigateur qui n'en avait aucun.
--
-- PORTEE : DEBITS et CREATION de caisse. Les credits restent ouverts -- 17 des
-- 29 sites du jeu sont des recettes versees par des citoyens sans poste, et
-- verser a l'Etat n'est pas une attaque.

CREATE OR REPLACE FUNCTION public.caisse_institution_mouvement(
  p_id text, p_delta numeric, p_exiger_existant boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $fn$
DECLARE
  v_data jsonb; v_solde numeric; v_existe boolean;
  v_moi text; v_pays text; v_postes text[]; v_client boolean;
BEGIN
  IF COALESCE(btrim(p_id), '') = '' OR p_delta IS NULL OR p_delta = 0
     OR abs(p_delta) > 100000000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  v_client := coalesce(current_setting('rp.caisse_interne', true), '') <> 'on'
              AND NOT public.est_appel_serveur();

  IF p_delta < 0 AND v_client THEN
    v_moi := public.mon_personnage();
    IF v_moi IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
    END IF;
    SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
    IF v_pays IS NULL OR p_id NOT LIKE v_pays || '\_%' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_hors_pays');
    END IF;
    v_postes := public.caisse_postes_requis(p_id, v_pays);
    IF v_postes IS NOT NULL THEN
      IF array_length(v_postes, 1) IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'caisse_reservee_au_serveur');
      END IF;
      IF NOT EXISTS (SELECT 1 FROM public.acteur_poste_courant() a
                      WHERE a.poste_id = ANY (v_postes) AND a.pays = v_pays) THEN
        INSERT INTO public.caisses_mouvements_clients (acteur, caisse, delta, motif, accepte, raison)
        VALUES (v_moi, p_id, p_delta, 'primitive_heritee', false, 'autorite_insuffisante');
        RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
      END IF;
    END IF;
  END IF;

  SELECT data INTO v_data FROM public.caisses_batiments WHERE id = p_id FOR UPDATE;
  v_existe := FOUND;
  IF p_exiger_existant AND NOT v_existe THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_absente');
  END IF;

  v_solde := CASE WHEN v_existe AND jsonb_typeof(v_data -> 'solde') = 'number'
                  THEN (v_data ->> 'solde')::numeric ELSE 0 END;
  IF v_solde + p_delta < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'solde_insuffisant');
  END IF;

  IF v_existe THEN
    UPDATE public.caisses_batiments
       SET data = coalesce(v_data, '{}'::jsonb) || jsonb_build_object('solde', v_solde + p_delta),
           updated_at = now()
     WHERE id = p_id;
  ELSE
    IF v_client THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_inexistante');
    END IF;
    INSERT INTO public.caisses_batiments (id, data, updated_at)
    VALUES (p_id, jsonb_build_object('solde', v_solde + p_delta), now());
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.caisse_institution_mouvement_plafonne(
  p_id text, p_montant numeric)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $fn$
DECLARE v_data jsonb; v_solde numeric; v_verse numeric;
        v_moi text; v_pays text; v_postes text[];
BEGIN
  IF COALESCE(btrim(p_id), '') = '' OR p_montant IS NULL OR p_montant <= 0
     OR p_montant > 100000000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  IF coalesce(current_setting('rp.caisse_interne', true), '') <> 'on'
     AND NOT public.est_appel_serveur() THEN
    v_moi := public.mon_personnage();
    IF v_moi IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
    END IF;
    SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
    IF v_pays IS NULL OR p_id NOT LIKE v_pays || '\_%' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_hors_pays');
    END IF;
    v_postes := public.caisse_postes_requis(p_id, v_pays);
    IF v_postes IS NOT NULL THEN
      IF array_length(v_postes, 1) IS NULL
         OR NOT EXISTS (SELECT 1 FROM public.acteur_poste_courant() a
                         WHERE a.poste_id = ANY (v_postes) AND a.pays = v_pays) THEN
        INSERT INTO public.caisses_mouvements_clients (acteur, caisse, delta, motif, accepte, raison)
        VALUES (v_moi, p_id, -p_montant, 'primitive_heritee_plafonnee', false, 'autorite_insuffisante');
        RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante', 'verse', 0);
      END IF;
    END IF;
  END IF;

  SELECT data INTO v_data FROM public.caisses_batiments WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', true, 'verse', 0, 'solde', 0);
  END IF;
  v_solde := CASE WHEN jsonb_typeof(v_data -> 'solde') = 'number'
                  THEN (v_data ->> 'solde')::numeric ELSE 0 END;
  v_verse := least(greatest(v_solde, 0), p_montant);
  IF v_verse <= 0 THEN
    RETURN jsonb_build_object('ok', true, 'verse', 0, 'solde', v_solde);
  END IF;
  UPDATE public.caisses_batiments
     SET data = coalesce(v_data, '{}'::jsonb) || jsonb_build_object('solde', v_solde - v_verse),
         updated_at = now()
   WHERE id = p_id;
  RETURN jsonb_build_object('ok', true, 'verse', v_verse, 'solde', v_solde - v_verse);
END;
$fn$;