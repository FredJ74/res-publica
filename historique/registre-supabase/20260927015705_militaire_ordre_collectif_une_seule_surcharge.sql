-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927015705
-- Nom original      : militaire_ordre_collectif_une_seule_surcharge
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-27 01:57:05 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 9535417da3cb01e5ce20ecc03cdb942d
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
-- UNE SEULE SURCHARGE DE militaire_ordre_collectif (27 septembre 2026)
--
-- PIEGE RENCONTRE, ET QUI A FAILLI PASSER. `CREATE OR REPLACE FUNCTION` avec UN PARAMETRE DE PLUS
-- ne remplace rien : PostgreSQL identifie une fonction par sa signature, donc il en CREE une
-- seconde. Les deux versions coexistaient :
--     militaire_ordre_collectif(text,text,text,text)          <- l'ancienne
--     militaire_ordre_collectif(text,text,text,text,text[])   <- la nouvelle, avec le filtre
-- Consequence immediate, constatee a l'execution : un appel a quatre arguments devient AMBIGU
-- (42725, « is not unique »). L'ordre de ration de section du client, qui envoie exactement ces
-- quatre arguments, aurait ete casse pour Vince -- alors meme que les deux corps contenaient les
-- bonnes regles. Et pire sur le fond : deux copies des memes regles metier, c'est-a-dire tout ce
-- que le filtre de beneficiaires servait a eviter.
--
-- La signature a cinq arguments suffit a tout le monde : `p_matricules` a une valeur par defaut,
-- donc les appels a quatre arguments -- SQL comme PostgREST -- continuent de fonctionner.
DROP FUNCTION IF EXISTS public.militaire_ordre_collectif(text, text, text, text);

REVOKE ALL ON FUNCTION public.militaire_ordre_collectif(text,text,text,text,text[])
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_ordre_collectif(text,text,text,text,text[])
  TO authenticated, service_role;