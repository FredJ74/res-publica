-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260928192540
-- Nom original      : contacts_pnj_retires_caserne
-- Categorie         : DML -- DML seul (mutation de donnees)
-- Date (deduite de la version) : 2026-09-28 19:25:40 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : fa40acc5b399414df455687bccb0097d
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
update public.personnages_donnees
   set contacts = (
         select coalesce(jsonb_agg(c order by ord), '[]'::jsonb)
           from jsonb_array_elements(coalesce(contacts, '[]'::jsonb))
                with ordinality as t(c, ord)
          where coalesce(c->>'name', '') not in ('Sergent Dubois (PNJ)', 'Soldat Martin (PNJ)')
       ),
       updated_at = now()
 where contacts @> '[{"name": "Sergent Dubois (PNJ)"}]'::jsonb
    or contacts @> '[{"name": "Soldat Martin (PNJ)"}]'::jsonb;