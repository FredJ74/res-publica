-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20261001154504
-- Nom original      : referents_lot_deux_republia
-- Categorie         : DML -- DML seul (mutation de donnees)
-- Date (deduite de la version) : 2026-10-01 15:45:04 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 6f6077816fc25d57729a7334316626f8
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
-- Neuf referents de plus pour Republia : les deux derniers de la caserne, les quatre
-- civils qui portaient deja un corpus pedagogique sans personnalite, et les trois chefs
-- de supporters -- un par ville, car chaque tribune a sa culture.
insert into public.pnj_referents (referent_id, pays, domaine) values
  ('caporal_alouche',   'republic', 'militaire — intendance et refectoire'),
  ('eve_toahemarch',    'republic', 'militaire — sante, blessures et soins'),
  ('jean_lou_zeure',    'republic', 'elections et campagnes'),
  ('alain_bordage',     'republic', 'voyages internationaux'),
  ('marcel_ancre',      'republic', 'administration portuaire'),
  ('pat_hounette',      'republic', 'milieu criminel'),
  ('alfredo_mifassole', 'republic', 'role social et politique du club — Luthecia'),
  ('pascal_hamar',      'republic', 'role social du club — Port-Sainte-Marie'),
  ('lucas_tenaire',     'republic', 'role social du club — Montrouge')
on conflict (referent_id) do nothing;

DO $garde$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n FROM public.pnj_referents;
  IF n < 16 THEN RAISE EXCEPTION 'liste des referents : % entrees, au moins 16 attendues', n; END IF;
  SELECT count(*) INTO n FROM public.pnj_referents WHERE pays IS NULL;
  IF n <> 0 THEN RAISE EXCEPTION '% referent(s) sans empire', n; END IF;
END $garde$;