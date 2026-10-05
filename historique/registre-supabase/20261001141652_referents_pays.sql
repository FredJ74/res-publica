-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20261001141652
-- Nom original      : referents_pays
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-10-01 14:16:52 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 4a97798d3d54f2885ef5db8773b1bebb
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
alter table public.pnj_referents
  add column if not exists pays text;

update public.pnj_referents set pays = 'republic' where pays is null;

alter table public.pnj_referents
  alter column pays set not null;

comment on column public.pnj_referents.pays is
  'Empire auquel ce referent appartient. Un personnage n''existe QUE dans son empire : Sovarka aura son propre referent economie, qui ne sera pas Marc Hantile. Doit rester aligne avec le champ `pays` de api/_pnj-referents.js -- le banc .scratch/banc_referents_personnalites.py le verifie.';

create index if not exists pnj_referents_par_empire
  on public.pnj_referents (pays);

DO $garde$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n FROM public.pnj_referents WHERE pays IS NULL;
  IF n <> 0 THEN RAISE EXCEPTION '% referent(s) sans empire', n; END IF;
  SELECT count(*) INTO n FROM public.pnj_referents WHERE pays = 'republic';
  IF n < 7 THEN RAISE EXCEPTION 'Republia : % referents, au moins 7 attendus', n; END IF;
END $garde$;