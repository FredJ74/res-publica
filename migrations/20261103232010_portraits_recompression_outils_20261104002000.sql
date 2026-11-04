-- Outils TEMPORAIRES de la recompression des portraits (04/11/2026, Claude, #55/#60).
-- Utilisés par la fonction Edge ponctuelle `recompresser-portraits`
-- (source : outils/supabase-functions/recompresser-portraits/index.ts), réservés à
-- service_role. À supprimer avec portraits_recompression une fois l'opération faite.
create table if not exists public.portraits_recompression_traites (
  table_source text not null, id text not null, primary key (table_source, id));
alter table public.portraits_recompression_traites enable row level security;
revoke all on public.portraits_recompression_traites from anon, authenticated;

create or replace function public.portraits_lourds_lister()
returns table(id text, name text) language sql security definer set search_path=public as $$
  select p.id::text, p.name from public.personnages_donnees p
  where left(p.photo_url,5)='data:' and length(p.photo_url) > 60000
    and not exists (select 1 from public.portraits_recompression_traites t where t.table_source='personnages' and t.id=p.id::text)
  order by length(p.photo_url) desc $$;
create or replace function public.portraits_lourds_ignorer(p_id text)
returns void language sql security definer set search_path=public as $$
  insert into public.portraits_recompression_traites values ('personnages', p_id) on conflict do nothing $$;
create or replace function public.editions_portraits_lourds_lister()
returns table(id text) language sql security definer set search_path=public as $$
  select e.id::text from public.journal_editions e
  where position('data:image' in e.faits_sources::text) > 0 and length(e.faits_sources::text) > 60000
    and not exists (select 1 from public.portraits_recompression_traites t where t.table_source='journal_editions' and t.id=e.id::text)
  order by e.date_edition desc $$;
create or replace function public.editions_portraits_lourds_ignorer(p_id text)
returns void language sql security definer set search_path=public as $$
  insert into public.portraits_recompression_traites values ('journal_editions', p_id) on conflict do nothing $$;
revoke all on function public.portraits_lourds_lister(), public.portraits_lourds_ignorer(text),
  public.editions_portraits_lourds_lister(), public.editions_portraits_lourds_ignorer(text) from public, anon, authenticated;
grant execute on function public.portraits_lourds_lister(), public.portraits_lourds_ignorer(text),
  public.editions_portraits_lourds_lister(), public.editions_portraits_lourds_ignorer(text) to service_role;
