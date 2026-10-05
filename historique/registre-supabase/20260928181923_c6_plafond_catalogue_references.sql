-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260928181923
-- Nom original      : c6_plafond_catalogue_references
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-28 18:19:23 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 726eb5d7844cd9bf0d8961a432ca1135
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
-- La cle s'appelait 'references_actives_max_base' : elle ne mesure plus les
-- references ACTIVES mais le CATALOGUE du commerce. Un nom qui ment est une
-- dette ; on le corrige en meme temps que la regle.
insert into public.entreprises_constantes (cle, valeur) values ('references_max_base', 4)
on conflict (cle) do update set valeur = 4;

delete from public.entreprises_constantes where cle = 'references_actives_max_base';

create or replace function public.fonds_references_max(p_proprietaire text)
returns integer
language sql
stable
as $$
  select greatest(1, coalesce(
    (select valeur::integer from public.entreprises_constantes
      where cle = 'references_max_base'), 4));
$$;

comment on function public.fonds_references_max(text) is
  'Nombre maximum de references qu''un commerce peut POSSEDER (son catalogue), gratuit = 4. Oppose une seule fois, a la creation. Retirer une reference de la vente ne libere aucune place : elle appartient toujours au commerce. Le parametre proprietaire est conserve pour qu''un statut Premium puisse relever ce plafond sans changer d''appelants.';