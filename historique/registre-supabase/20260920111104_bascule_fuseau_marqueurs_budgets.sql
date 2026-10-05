-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920111104
-- Nom original      : bascule_fuseau_marqueurs_budgets
-- Categorie         : DML -- DML seul (mutation de donnees)
-- Date (deduite de la version) : 2026-09-20 11:11:04 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 1a7347a66e8396f7ebec07da19e3feb1
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
-- BASCULE UTC -> EUROPE/PARIS DES MARQUEURS DE JOURNEE (arbitrage GD du 20/09/2026)
-- ---------------------------------------------------------------------------
-- Meme raisonnement que pour le registre joursCron du cron, applique aux seuls
-- marqueurs qui vivent hors de ce registre. Inventaire complet fait avant :
--
--   greves_generales.derniere_application_jour ............ 0 ligne
--   organisations.data->greve->derniereApplicationJour .... 0 ligne
--   terrains_etat.data->permis->jourInstruction ........... 0 ligne
--   prets.jour_dernier_prelevement ........................ 0 ligne
--   budgets_nationaux.data->derniereDistribJour ........... 1 ligne  <- seule a traduire
--
-- Les quatre premiers n'ayant aucune valeur heritee, leur code peut passer a
-- Europe/Paris sans traduction : toute valeur future naitra deja parisienne.
-- On ne s'autorise PAS a en conclure qu'ils sont « sans risque parce que vides »
-- -- c'est bien le code qui est rendu correct, la base n'a simplement rien a
-- rattraper.
--
-- LA REGLE DE TRADUCTION : ces marqueurs ont ete ecrits par le cron, a 23 h UTC.
-- A cette heure-la, la date parisienne vaut toujours UTC + 1, en heure d'hiver
-- comme en heure d'ete (verifie sur les deux changements d'heure 2026). La nuit
-- deja traitee garde donc son marqueur et ne sera pas rejouee ; la nuit suivante
-- porte une date differente et s'executera.
--
-- Idempotence : on ne traduit que les valeurs strictement anterieures a la date
-- parisienne du jour. Rejouer cette migration ne decale donc rien une seconde
-- fois, puisque la valeur traduite n'est plus anterieure.

UPDATE public.budgets_nationaux b
   SET data = b.data || jsonb_build_object(
                 'derniereDistribJour',
                 to_char((((b.data ->> 'derniereDistribJour')::date) + 1), 'YYYY-MM-DD'))
 WHERE (b.data ->> 'derniereDistribJour') ~ '^\d{4}-\d{2}-\d{2}$'
   AND ((b.data ->> 'derniereDistribJour')::date) < (now() AT TIME ZONE 'Europe/Paris')::date;

UPDATE public.budgets_nationaux b
   SET data = b.data || jsonb_build_object(
                 'dernierVirementCaserneJour',
                 to_char((((b.data ->> 'dernierVirementCaserneJour')::date) + 1), 'YYYY-MM-DD'))
 WHERE (b.data ->> 'dernierVirementCaserneJour') ~ '^\d{4}-\d{2}-\d{2}$'
   AND ((b.data ->> 'dernierVirementCaserneJour')::date) < (now() AT TIME ZONE 'Europe/Paris')::date;