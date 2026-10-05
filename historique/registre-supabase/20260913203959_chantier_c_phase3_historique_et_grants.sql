-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913203959
-- Nom original      : chantier_c_phase3_historique_et_grants
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-13 20:39:59 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 7ac1ea4ebaa7304a93dd3d626a698852
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
-- Journal de caisse d'une entreprise, a l'identique de ajouterHistoriqueEntreprise :
-- { jour, montant, motif }, tronque aux 50 dernieres lignes. Le jour est celui du personnage
-- qui agit -- c'est exactement ce que faisait state.day cote client.
CREATE OR REPLACE FUNCTION public.entreprise_ajouter_historique(
  p_data jsonb, p_montant numeric, p_motif text, p_jour integer DEFAULT 1)
RETURNS jsonb
LANGUAGE sql IMMUTABLE SET search_path = public AS $$
  SELECT jsonb_set(p_data, '{historique}', (
    SELECT COALESCE(jsonb_agg(e), '[]'::jsonb) FROM (
      SELECT e FROM jsonb_array_elements(
        COALESCE(p_data->'historique', '[]'::jsonb)
        || jsonb_build_array(jsonb_build_object('jour', COALESCE(p_jour,1),
                                                'montant', p_montant, 'motif', p_motif))) e
      OFFSET GREATEST(0, jsonb_array_length(COALESCE(p_data->'historique','[]'::jsonb)) + 1 - 50)
    ) t
  ), true);
$$;

REVOKE EXECUTE ON FUNCTION public.entreprise_ajouter_historique(jsonb, numeric, text, integer)
  FROM PUBLIC, anon, authenticated;

REVOKE EXECUTE ON FUNCTION public.commerce_acheter_matiere(text,text,text,integer) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.commerce_acheter_matiere(text,text,text,integer) TO authenticated, service_role;
