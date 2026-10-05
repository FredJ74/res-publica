-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260914104032
-- Nom original      : inventaire_donner_mutations_presentation
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-14 10:40:32 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : d7f22ff00c47f0ac9b67194ff4e82c31
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
-- La carte postale est le seul don qui TRANSFORME l'objet en partant : l'exemplaire vierge
-- quitte l'inventaire, un exemplaire ecrit (auteur, message, date) arrive chez le destinataire.
-- Le guichet accepte donc des mutations de PRESENTATION, sans jamais laisser le navigateur
-- toucher a ce qui a une valeur : quantite, empilement, type, legalite et encombrement sont
-- retires des mutations avant fusion. Liste NOIRE et non blanche, pour qu'un champ de jeu
-- nouvellement invente soit transmissible sans rouvrir cette fonction, mais qu'aucun des
-- champs economiques ne puisse l'etre par oubli.
CREATE OR REPLACE FUNCTION public.inventaire_donner(
  p_acteur text, p_destinataire text, p_index integer, p_signature jsonb,
  p_qte integer DEFAULT 1, p_mutations jsonb DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_inv jsonb; v_quete jsonb; v_trouve boolean; v_r jsonb; v_id text;
        v_mut jsonb; v_objet jsonb;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF coalesce(p_destinataire, '') = '' OR p_destinataire = p_acteur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_invalide');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_destinataire) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_introuvable');
  END IF;

  SELECT true, coalesce(inventory, '[]'::jsonb), quete_carriere
    INTO v_trouve, v_inv, v_quete
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF NOT coalesce(v_trouve, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  v_r := public.helvetia_inventaire_sortie(v_inv, v_quete, p_index, p_signature, p_qte);
  IF NOT (v_r->>'ok')::boolean THEN RETURN v_r; END IF;

  v_objet := v_r->'objet';
  IF p_mutations IS NOT NULL AND jsonb_typeof(p_mutations) = 'object' THEN
    v_mut := p_mutations - 'qty' - 'quantite' - 'stackable' - 'stackKey'
                         - 'encombrement' - 'type' - 'legal' - 'id';
    v_objet := v_objet || v_mut;
  END IF;

  v_id := 'objet-recu-' || replace(gen_random_uuid()::text, '-', '');
  UPDATE public.personnages_donnees SET inventory = v_r->'inventory' WHERE name = p_acteur;
  -- objets_recus est le SAS obligatoire : le serveur n'ecrit JAMAIS directement dans
  -- l'inventaire du destinataire, dont le client ouvert reecrirait le tableau entier et
  -- ecraserait l'ajout (doctrine posee par migration_moteur_commerce.sql).
  INSERT INTO public.objets_recus (id, destinataire, expediteur, data)
  VALUES (v_id, p_destinataire, p_acteur, v_objet);

  RETURN v_r || jsonb_build_object('objet', v_objet, 'objet_id', v_id);
END; $$;

REVOKE ALL ON FUNCTION public.inventaire_donner(text, text, integer, jsonb, integer, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.inventaire_donner(text, text, integer, jsonb, integer, jsonb) TO authenticated;

-- L'ancienne signature a 5 arguments disparait : deux surcharges du meme nom rendraient
-- l'appel PostgREST ambigu (PGRST203), et le client passe desormais toujours les 6.
DROP FUNCTION IF EXISTS public.inventaire_donner(text, text, integer, jsonb, integer);
