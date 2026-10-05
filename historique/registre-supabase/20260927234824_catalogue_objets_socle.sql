-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927234824
-- Nom original      : catalogue_objets_socle
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-27 23:48:24 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 6204109d6ee6e0f8bb2b9b94b582761c
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
create table if not exists public.catalogue_types (
  id      text primary key,
  libelle text not null,
  ordre   int  not null default 0
);
comment on table public.catalogue_types is
  'Les 14 types de commerce du referentiel cible. Lecture publique, ecriture service_role.';

create table if not exists public.catalogue_familles (
  id      text primary key,
  libelle text not null
);
comment on table public.catalogue_familles is
  'Familles commerciales. Liste plate en L2 ; le rattachement aux types arrive en L5.';

create table if not exists public.catalogue_generiques (
  id            text primary key,
  libelle       text not null,
  famille_id    text not null references public.catalogue_familles(id),
  regime        text not null default 'libre'
                check (regime in ('libre','reglemente','illegal','institutionnel')),
  est_service   boolean not null default false,
  empilable     boolean not null default false,
  individualise boolean not null default false,
  consommable   boolean not null default false,
  equipable     boolean not null default false,
  encombrement  int,
  effets        jsonb,
  capacites     jsonb,
  durabilite    jsonb,
  conditions    jsonb,
  contraintes   jsonb,
  note          text
);
comment on column public.catalogue_generiques.est_service is
  'true = ne produit jamais d''objet d''inventaire. Le mode de commercialisation d''un bien (livre ou consomme sur place) n''est PAS une propriete du generique : il releve de la reference (L5).';
comment on column public.catalogue_generiques.equipable is
  'Affectation REELLEMENT existante dans le moteur actuel uniquement. Aucune anticipation des futures mecaniques d''installation.';
comment on column public.catalogue_generiques.capacites is
  'Ce que l''objet permet de faire. Jamais herite d''un autre generique, jamais deduit du nom commercial.';

create table if not exists public.catalogue_generique_type (
  generique_id text not null references public.catalogue_generiques(id),
  type_id      text not null references public.catalogue_types(id),
  primary key (generique_id, type_id)
);

create table if not exists public.catalogue_variantes (
  id           text primary key,
  generique_id text not null references public.catalogue_generiques(id),
  cle          text not null,
  libelle      text not null,
  regime       text not null default 'reglemente'
               check (regime in ('libre','reglemente','illegal','institutionnel')),
  surcharges   jsonb,
  capacites    jsonb,
  note         text,
  unique (generique_id, cle)
);

create table if not exists public.catalogue_correspondance_legacy (
  id               bigserial primary key,
  motif            text not null check (motif in (
                     'type_soustype','type','produit_militaire',
                     'type_produit_militaire','type_tracttype',
                     'famille_produit_marche','recette_id','stack_key',
                     'ordre','objet_id')),
  valeur           text not null,
  generique_id     text not null references public.catalogue_generiques(id),
  variante_id      text references public.catalogue_variantes(id),
  priorite         int  not null default 100,
  effets_effectifs jsonb,
  source_audit     text not null,
  note             text,
  unique (motif, valeur)
);
comment on column public.catalogue_correspondance_legacy.effets_effectifs is
  'UNIQUEMENT les effets que le moteur applique reellement a cet objet historique. NULL = aucun effet effectif, ce qui produira « Aucun effet » sur la fiche. Les proprietes declarees mais jamais lues n''y figurent jamais.';
comment on column public.catalogue_correspondance_legacy.source_audit is
  'chemin:ligne ou nom de fonction prouvant l''effet. Obligatoire : une correspondance sans preuve ne doit pas exister.';

create index if not exists idx_corresp_legacy_generique
  on public.catalogue_correspondance_legacy (generique_id);

create or replace view public.catalogue_generiques_raccordes as
  select g.id                as generique_id,
         count(c.id)::int    as nb_correspondances
    from public.catalogue_generiques g
    left join public.catalogue_correspondance_legacy c on c.generique_id = g.id
   group by g.id;

alter table public.recettes_commerce     add column if not exists generique_id text;
alter table public.recettes_production   add column if not exists generique_id text;
alter table public.produits_manufactures add column if not exists generique_id text;
comment on column public.recettes_commerce.generique_id is
  'Etiquette de referentiel (L2). Nullable, aucun lecteur historique. Ne modifie aucun comportement.';

alter table public.catalogue_types                  enable row level security;
alter table public.catalogue_familles               enable row level security;
alter table public.catalogue_generiques             enable row level security;
alter table public.catalogue_generique_type         enable row level security;
alter table public.catalogue_variantes              enable row level security;
alter table public.catalogue_correspondance_legacy  enable row level security;

drop policy if exists "catalogue_types lecture"       on public.catalogue_types;
drop policy if exists "catalogue_familles lecture"    on public.catalogue_familles;
drop policy if exists "catalogue_generiques lecture"  on public.catalogue_generiques;
drop policy if exists "catalogue_generique_type lecture" on public.catalogue_generique_type;
drop policy if exists "catalogue_variantes lecture"   on public.catalogue_variantes;
drop policy if exists "catalogue_correspondance_legacy lecture" on public.catalogue_correspondance_legacy;

create policy "catalogue_types lecture"
  on public.catalogue_types for select to anon, authenticated using (true);
create policy "catalogue_familles lecture"
  on public.catalogue_familles for select to anon, authenticated using (true);
create policy "catalogue_generiques lecture"
  on public.catalogue_generiques for select to anon, authenticated using (true);
create policy "catalogue_generique_type lecture"
  on public.catalogue_generique_type for select to anon, authenticated using (true);
create policy "catalogue_variantes lecture"
  on public.catalogue_variantes for select to anon, authenticated using (true);
create policy "catalogue_correspondance_legacy lecture"
  on public.catalogue_correspondance_legacy for select to anon, authenticated using (true);

revoke all on public.catalogue_types                 from anon, authenticated;
revoke all on public.catalogue_familles              from anon, authenticated;
revoke all on public.catalogue_generiques            from anon, authenticated;
revoke all on public.catalogue_generique_type        from anon, authenticated;
revoke all on public.catalogue_variantes             from anon, authenticated;
revoke all on public.catalogue_correspondance_legacy from anon, authenticated;
revoke all on public.catalogue_generiques_raccordes  from anon, authenticated;

grant select on public.catalogue_types                 to anon, authenticated;
grant select on public.catalogue_familles              to anon, authenticated;
grant select on public.catalogue_generiques            to anon, authenticated;
grant select on public.catalogue_generique_type        to anon, authenticated;
grant select on public.catalogue_variantes             to anon, authenticated;
grant select on public.catalogue_correspondance_legacy to anon, authenticated;
grant select on public.catalogue_generiques_raccordes  to anon, authenticated;