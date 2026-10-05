-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913130015
-- Nom original      : reset_beta_correctif_colonnes_proprietaire
-- Categorie         : DML -- DML seul (mutation de donnees)
-- Date (deduite de la version) : 2026-09-13 13:00:15 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : e74670424040a837c84f9548d2a5f98d
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
-- COMPLEMENT AU RESET (13 septembre 2026).
-- terrains_etat ne stocke pas le proprietaire QUE dans son blob 'data' : la table
-- porte aussi de VRAIES colonnes 'proprietaire' et 'coproprietaire', que le
-- premier passage n'a pas vues. Trois terrains restaient donc au nom d'un
-- personnage supprime. Le terrain, son batiment, sa surface et sa valeur sont
-- conserves : seule la propriete est liberee.
UPDATE public.terrains_etat
SET proprietaire = NULL, coproprietaire = NULL, updated_at = now()
WHERE proprietaire IS NOT NULL OR coproprietaire IS NOT NULL;

-- Le championnat conserve sa saison et son calendrier ; seul le nom du joueur
-- inscrit dans un club est retire.
UPDATE public.championnat
SET data = replace(data::text, '"Vince Major Kubrick"', '"Joueur PNJ"')::jsonb,
    updated_at = now()
WHERE data::text LIKE '%Vince Major Kubrick%';

-- Presences et historique de deplacement : un joueur encore connecte au moment
-- du reset a recree une ligne. Elles ne portent aucune valeur de jeu.
DELETE FROM public.presences;
DELETE FROM public.historique_deplacements;