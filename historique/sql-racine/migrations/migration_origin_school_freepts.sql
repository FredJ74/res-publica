-- Migration requise avant que le correctif de persistance origin/school (bêta, création de
-- personnage) ne prenne réellement effet en production.
--
-- Contexte : vérifié en direct via l'API REST Supabase (requête POST de test avec origin/
-- school, avant toute modification de code) -- la table "personnages" n'a AUCUNE colonne
-- origin ni school aujourd'hui (confirmé par l'erreur PGRST204 "Could not find the 'origin'
-- column of 'personnages' in the schema cache"). Le code lui-même ne les écrivait jamais non
-- plus (sbSavePersonnage/sbLoadPersonnage) -- double confirmation du bug déjà identifié par
-- l'audit précédent : origin/school sont perdus depuis toujours, pas seulement "mal lus".
--
-- free_pts_restants (nouveau, lot "reliquat des 30 points") : permet au joueur de ne pas
-- dépenser tous ses points à la création, et de conserver le reliquat pour une distribution
-- ultérieure depuis la fiche de personnage (onglet Statistiques).
--
-- La clé anon (utilisée par le client via l'API REST) n'a pas les privilèges DDL nécessaires
-- pour exécuter ceci elle-même (déjà le cas pour tous les changements de schéma de ce projet,
-- voir JOURNAL-SESSION.md -- toujours exécutés manuellement par Fred dans l'éditeur SQL
-- Supabase). Sans cette migration, le code déployé continuera de tourner normalement (les
-- deux champs sont lus avec repli sur null/0), mais origin/school/freePtsRestants resteront
-- non persistés tant qu'elle n'a pas été appliquée.

ALTER TABLE personnages ADD COLUMN IF NOT EXISTS origin text;
ALTER TABLE personnages ADD COLUMN IF NOT EXISTS school text;
ALTER TABLE personnages ADD COLUMN IF NOT EXISTS free_pts_restants integer DEFAULT 0;
