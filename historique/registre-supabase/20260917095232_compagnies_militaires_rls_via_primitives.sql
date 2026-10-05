-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260917095232
-- Nom original      : compagnies_militaires_rls_via_primitives
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-17 09:52:32 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : a19cf212c3303c0bc8af75b40f8b8ff3
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
-- CORRECTIF DE LA POLITIQUE RLS POSEE QUELQUES MINUTES PLUS TOT (17 septembre 2026, passe 3).
--
-- Les politiques initiales interrogeaient directement personnages_donnees. Or le role
-- authenticated n'a AUCUN droit sur cette table (verifie : information_schema.role_table_grants
-- ne renvoie rien pour anon/authenticated/PUBLIC) -- le jeu y accede par la VUE personnages.
-- Consequence : l'evaluation de la politique levait « permission denied for table
-- personnages_donnees » pour TOUT client, y compris un Commandant parfaitement legitime. La
-- fermeture etait donc trop large : elle aurait casse le recrutement de compagnie et de section.
--
-- Le banc l'a vu parce qu'il rapporte le MOTIF du refus et pas seulement le fait qu'il y ait
-- refus : « permission denied for table personnages_donnees » n'est pas le refus attendu.
--
-- Correctif : passer par acteur_poste_courant(), primitive SECURITY DEFINER du projet qui lit la
-- table avec les droits du proprietaire et rend (nom, poste_id, poste_city, pays).
DROP POLICY IF EXISTS "compagnies creation par le commandant" ON public.compagnies_militaires;
DROP POLICY IF EXISTS "compagnies maj par la chaine de commandement" ON public.compagnies_militaires;

CREATE POLICY "compagnies creation par le commandant" ON public.compagnies_militaires
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.acteur_poste_courant() a
             WHERE a.poste_id = 'commandant' AND a.pays = data->>'pays')
  );

CREATE POLICY "compagnies maj par la chaine de commandement" ON public.compagnies_militaires
  FOR UPDATE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.acteur_poste_courant() a
             WHERE a.pays = data->>'pays'
               AND (a.poste_id = 'commandant'
                    OR (a.poste_id = 'capitaine' AND a.nom = data->>'capitaineNom')))
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.acteur_poste_courant() a
             WHERE a.pays = data->>'pays'
               AND (a.poste_id = 'commandant'
                    OR (a.poste_id = 'capitaine' AND a.nom = data->>'capitaineNom')))
  );

GRANT EXECUTE ON FUNCTION public.acteur_poste_courant() TO authenticated;