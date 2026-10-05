-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260916082420
-- Nom original      : pa_aliment_effet_dans_la_consommation
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-16 08:24:20 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 849267b4cab7d835df129bfadad5f505
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
-- LES PA D'UN ALIMENT SONT DECIDES LA OU L'ALIMENT EST REELLEMENT RETIRE (16 septembre 2026).
--
-- Premiere tentative : le client appelait pa_crediter_atteste avec, pour reference d'unicite, la
-- signature de l'objet. Mauvaise idee -- la signature ne porte que (name, type, stackKey) : deux
-- baguettes achetees a dix jours d'intervalle ont la MEME signature, et la seconde n'aurait plus
-- jamais rapporte de PA. Un verrou ne doit pas amputer le jeu.
--
-- La bonne unicite existait deja, ailleurs : c'est le RETRAIT lui-meme. inventaire_consommer
-- retire l'objet sous verrou, une fois, et tient l'objet REEL avec son dateAchat. L'effet en PA
-- appartient donc a cette transaction : un aliment consomme = un effet, jamais zero, jamais deux,
-- et la fraicheur est appreciee sur l'horodatage du serveur, plus sur celui que le client annonce.
--
-- La regle de jeu est inchangee : frais (moins de 7 jours) +1 PA, perime -1 PA, plafond 30.
-- Les autres consommables (medicament, explosif, poison) ne sont pas touches.

CREATE OR REPLACE FUNCTION public.inventaire_consommer(p_acteur text, p_index integer, p_signature jsonb)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_inv jsonb; v_quete jsonb; v_trouve boolean; v_r jsonb; v_pos integer; v_item jsonb;
  v_date numeric; v_frais boolean; v_pa integer; v_delta integer;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT true, coalesce(inventory, '[]'::jsonb), quete_carriere
    INTO v_trouve, v_inv, v_quete
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF NOT coalesce(v_trouve, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  v_pos := public.inventaire_localiser(v_inv, p_index, p_signature);
  IF v_pos < 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'objet_absent'); END IF;
  v_item := v_inv -> v_pos;

  IF NOT (coalesce(v_item->>'familleProduitMarche', '') = 'aliment'
          OR coalesce(v_item->>'type', '') IN ('medicament', 'explosif', 'poison')) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'objet_non_consommable');
  END IF;

  v_r := public.helvetia_inventaire_sortie(v_inv, v_quete, p_index, p_signature, 1);
  IF NOT (v_r->>'ok')::boolean THEN RETURN v_r; END IF;

  UPDATE public.personnages_donnees SET inventory = v_r->'inventory' WHERE name = p_acteur;

  -- EFFET EN PA DES ALIMENTS, dans la meme transaction que le retrait.
  IF coalesce(v_item->>'familleProduitMarche', '') = 'aliment' THEN
    BEGIN v_date := (v_item->>'dateAchat')::numeric; EXCEPTION WHEN others THEN v_date := NULL; END;
    IF v_date IS NOT NULL AND v_date > 0 THEN
      -- dateAchat est un horodatage en millisecondes, comme du cote du navigateur.
      v_frais := (extract(epoch FROM now()) * 1000 - v_date) <= 7 * 24 * 60 * 60 * 1000;
      v_delta := CASE WHEN v_frais THEN 1 ELSE -1 END;
      UPDATE public.personnages_donnees
         SET pa = least(30, greatest(0, coalesce(pa, 0) + v_delta))
       WHERE name = p_acteur
       RETURNING pa INTO v_pa;
      v_r := v_r || jsonb_build_object('pa', v_pa, 'aliment_frais', v_frais);
    END IF;
  END IF;

  RETURN v_r;
END; $function$;