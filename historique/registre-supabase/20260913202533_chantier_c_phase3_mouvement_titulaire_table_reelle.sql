-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913202533
-- Nom original      : chantier_c_phase3_mouvement_titulaire_table_reelle
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-13 20:25:33 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : f4b1279234c00350fee6555fe3a26df1
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
-- CHANTIER C / PHASE 3 (13 septembre 2026).
--
-- mouvement_titulaire est la primitive de mouvement d'argent partagee par acheter_produit_commerce
-- et les autres briques "fonds de commerce". Elle lisait et ecrivait la VUE public.personnages,
-- ce qui la rendait doublement inoperante depuis le chantier B :
--   * lecture : 'arg' est une colonne MASQUEE dans la vue (visible du seul proprietaire ou du
--     serveur), donc lire le solde d'un AUTRE personnage renvoyait NULL -- un debit etait alors
--     evalue contre 0 ;
--   * ecriture : le declencheur INSTEAD OF refuse toute ligne qui n'appartient pas a auth.uid()
--     (personnage_non_possede), donc crediter un vendeur tiers echouait systematiquement.
--
-- Toutes les RPC ecrites depuis le chantier B (payer_ordre, acheter_a_entrepot, recevoir_soin,
-- vendre_ressource_medicale, justice_prolonger_peine) passent par personnages_donnees. On aligne
-- cette brique-ci sur la meme regle, sans rien changer a sa semantique ni a sa signature.
CREATE OR REPLACE FUNCTION public.mouvement_titulaire(p_ref text, p_delta numeric)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_type text; v_id text; v_solde numeric; v_data text; v_json jsonb;
BEGIN
  IF COALESCE(p_ref, '') = '' THEN RETURN false; END IF;

  IF left(p_ref, 5) = 'orga:' THEN
    v_type := 'orga'; v_id := substr(p_ref, 6);
  ELSIF left(p_ref, 3) = 'pj:' THEN
    v_type := 'pj'; v_id := substr(p_ref, 4);
  ELSIF left(p_ref, 6) = 'ville:' THEN
    RETURN false;
  ELSE
    v_type := 'pj'; v_id := p_ref;
  END IF;
  IF COALESCE(v_id, '') = '' THEN RETURN false; END IF;

  IF v_type = 'pj' THEN
    -- TABLE REELLE, pas la vue : ni masquage de colonne, ni controle de propriete a traverser.
    SELECT arg INTO v_solde FROM public.personnages_donnees WHERE name = v_id FOR UPDATE;
    IF NOT FOUND THEN RETURN false; END IF;
    IF COALESCE(v_solde, 0) + p_delta < 0 THEN RETURN false; END IF;
    UPDATE public.personnages_donnees
       SET arg = COALESCE(arg, 0) + p_delta, updated_at = now()
     WHERE name = v_id;
    RETURN true;
  END IF;

  SELECT data INTO v_data FROM public.organisations WHERE id = v_id FOR UPDATE;
  IF NOT FOUND THEN RETURN false; END IF;
  BEGIN
    v_json := v_data::jsonb;
  EXCEPTION WHEN others THEN RETURN false;
  END;
  IF v_json IS NULL OR jsonb_typeof(v_json) <> 'object' THEN RETURN false; END IF;
  v_solde := GREATEST(0, COALESCE((v_json ->> 'caisse')::numeric, 0));
  IF v_solde + p_delta < 0 THEN RETURN false; END IF;
  UPDATE public.organisations
     SET data = jsonb_set(v_json, '{caisse}', to_jsonb(v_solde + p_delta))::text
   WHERE id = v_id;
  RETURN true;
END; $$;

-- Primitive interne : appelee par les RPC, jamais directement par un navigateur.
REVOKE EXECUTE ON FUNCTION public.mouvement_titulaire(text, numeric) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.mouvement_titulaire(text, numeric) TO service_role;
