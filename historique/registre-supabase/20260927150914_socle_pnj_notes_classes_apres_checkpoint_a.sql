-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927150914
-- Nom original      : socle_pnj_notes_classes_apres_checkpoint_a
-- Categorie         : DML -- DML seul (mutation de donnees)
-- Date (deduite de la version) : 2026-09-27 15:09:14 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 16b6d40c7620ef8841f08baa64b2e8b9
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
-- Les notes du registre des classes decrivaient un etat depasse par le checkpoint A.
-- Une note fausse est pire qu'une note absente : elle est lue comme vraie.
UPDATE public.pnj_familles_classes
   SET note = 'Famille pilote Alpha, entierement au socle depuis le 27 septembre 2026. '
           || 'Position, leader, PA, possessions, argent et propriete font autorite dans '
           || 'pnj_membres ; compagnies_militaires reste le magasin METIER (armes, stockArmes, '
           || 'formation, sections, reserve, missions, mutinerie, compteurs ration/bivouac) et en '
           || 'recoit une projection par militaire_blob_projeter. Ses PA se consomment par les '
           || 'primitives generiques pnj_pa_debiter/crediter/fixer, qui ne tuent jamais : '
           || 'atteindre 0 PA est une constatation rendue au metier, pas un evenement du socle. '
           || 'Ses six caracteristiques metier ne sont PAS renseignees et attendent un arbitrage.'
 WHERE famille = 'soldat';

UPDATE public.pnj_familles_classes
   SET note = 'Raccordee au lot 2. 12 PA presents, jamais debites : pnj_pa_garde refuse toute '
           || 'variation de PA hors classe alpha. Un ordre a 0 PA est donc COHERENT avec Beta et '
           || 'ne doit pas etre "corrige". Six caracteristiques renseignees : '
           || 'INT 10 CHA 8 VOL 12 PER 12 DUP 8 ENT 10. Autorite = Chef des Douanes du perimetre, '
           || 'et "personne" est un etat valide. Reste au blob : position_leader.'
 WHERE famille = 'douanier';

UPDATE public.pnj_familles_classes
   SET note = 'Raccordee au lot 3. 12 PA presents, jamais debites. Multi-ville : le perimetre '
           || 'porte la ville, l''autorite est le Commissaire DE CETTE VILLE, et la caisse '
           || 'municipale n''est accessible qu''a l''autorite de la meme ville. Paye deplacee du '
           || 'navigateur vers le cron de minuit (50 FR/jour, 100 pour le cynophile). '
           || 'Six caracteristiques renseignees : INT 10 CHA 8 VOL 12 PER 12 DUP 8 ENT 10. '
           || 'Reste au blob : position_leader.'
 WHERE famille = 'policier';