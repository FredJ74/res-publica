-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20261001155144
-- Nom original      : referent_laurent_barre
-- Categorie         : DML -- DML seul (mutation de donnees)
-- Date (deduite de la version) : 2026-10-01 15:51:44 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : fc897c465f896a2a20df7cb22bf7bb3b
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
-- Laurent Barre rejoint les referents : sa personnalite avait ete arbitree le
-- 18 aout 2026, en meme temps que son corpus pedagogique, et seul le corpus avait
-- ete repris. Dix-septieme referent de Republia.
insert into public.pnj_referents (referent_id, pays, domaine) values
  ('laurent_barre', 'republic', 'immobilier et entrepreneuriat')
on conflict (referent_id) do nothing;

DO $garde$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n FROM public.pnj_referents;
  IF n < 17 THEN RAISE EXCEPTION 'liste des referents : % entrees, au moins 17 attendues', n; END IF;
  SELECT count(*) INTO n FROM public.pnj_referents WHERE pays IS NULL;
  IF n <> 0 THEN RAISE EXCEPTION '% referent(s) sans empire', n; END IF;
END $garde$;