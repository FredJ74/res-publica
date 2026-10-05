-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260914104857
-- Nom original      : inventaire_remettre_pnj
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-14 10:48:57 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 76a767dc1732e0220d1821446fe5966b
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
-- GUICHET 6 : REMISE A UN PNJ DESIGNE.
-- Famille distincte du don entre joueurs : le destinataire n'a pas d'inventaire, l'objet quitte
-- donc le jeu. C'est aussi le SEUL chemin par lequel un objet protege peut legitimement sortir --
-- remettre le colis secret a Brigitte Menottes est precisement la facon de terminer la quete.
-- Sans ce guichet, la protection posee sur les cinq autres rendrait la quete interminable.
--
-- La regle est celle du client (plateau-justice-economie.js:3238), reprise telle quelle et sans
-- generalisation : un objet protege ne peut etre remis qu'a son destinataire designe.
CREATE OR REPLACE FUNCTION public.inventaire_remettre(
  p_acteur text, p_index integer, p_signature jsonb, p_destinataire text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_inv jsonb; v_quete jsonb; v_trouve boolean; v_pos integer; v_item jsonb; v_r jsonb;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF coalesce(p_destinataire, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_invalide');
  END IF;

  SELECT true, coalesce(inventory, '[]'::jsonb), quete_carriere
    INTO v_trouve, v_inv, v_quete
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF NOT coalesce(v_trouve, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  v_pos := public.inventaire_localiser(v_inv, p_index, p_signature);
  IF v_pos < 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'objet_absent'); END IF;
  v_item := v_inv -> v_pos;

  -- Objet protege : sortie autorisee UNIQUEMENT vers son destinataire designe.
  IF public.inventaire_objet_protege(v_quete, v_item) THEN
    IF coalesce(v_item->>'type', '') = 'colis_secret_pat' AND p_destinataire = 'Brigitte Menottes' THEN
      v_inv := public.inventaire_retirer_position(v_inv, v_pos);
      UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = p_acteur;
      RETURN jsonb_build_object('ok', true, 'inventory', v_inv, 'objet', v_item,
                                'position', v_pos, 'remise_quete', true);
    END IF;
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_non_designe');
  END IF;

  v_r := public.helvetia_inventaire_sortie(v_inv, v_quete, p_index, p_signature, 1);
  IF NOT (v_r->>'ok')::boolean THEN RETURN v_r; END IF;
  UPDATE public.personnages_donnees SET inventory = v_r->'inventory' WHERE name = p_acteur;
  RETURN v_r;
END; $$;

REVOKE ALL ON FUNCTION public.inventaire_remettre(text, integer, jsonb, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.inventaire_remettre(text, integer, jsonb, text) TO authenticated;
