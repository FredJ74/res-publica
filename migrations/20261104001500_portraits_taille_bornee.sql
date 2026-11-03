-- =====================================================================
-- Portraits des PJ : taille bornée (#55 / #60, consommation Supabase)
-- 04/11/2026 — Claude
-- =====================================================================
-- Constat (04/11) : les portraits sont stockés en base64 dans
-- personnages_donnees.photo_url — 6,8 Mo pour 12 fiches, dont 3,2 Mo pour
-- une seule. L'annuaire des joueurs (sbListPersonnages, ~40 appelants)
-- les redescend tous à chaque appel ; la génération du journal les
-- recopie dans journal_editions.faits_sources (27 Mo sur 26 éditions).
--
-- 1. Garde serveur : un nouveau portrait en data URL de plus de 120 000
--    caractères (~90 Ko d'image) est refusé SANS casser la sauvegarde :
--    à la modification on conserve l'ancien portrait, à la création on
--    n'en pose pas. Protège contre les anciens navigateurs qui renvoient
--    encore l'image d'origine gardée en localStorage. Les URL http(s)
--    ne sont pas concernées.
-- 2. Table de travail de la recompression ponctuelle (fonction Edge
--    `recompresser-portraits`) : empreinte de l'ancienne image -> image
--    réduite, pour ne décoder qu'une fois une image recopiée dans
--    plusieurs éditions. Supprimée après l'opération.
-- =====================================================================

create or replace function public.personnages_portrait_borner()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.photo_url is not null
     and left(new.photo_url, 5) = 'data:'
     and length(new.photo_url) > 120000 then
    if tg_op = 'UPDATE' then
      new.photo_url := old.photo_url;
    else
      new.photo_url := null;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_personnages_portrait_borner on public.personnages_donnees;
create trigger trg_personnages_portrait_borner
  before insert or update of photo_url on public.personnages_donnees
  for each row
  when (new.photo_url is not null)
  execute function public.personnages_portrait_borner();

create table if not exists public.portraits_recompression (
  empreinte text primary key,
  nouveau   text not null,
  ancien_ko integer not null,
  nouveau_ko integer not null,
  cree_le   timestamptz not null default now()
);
alter table public.portraits_recompression enable row level security;
revoke all on public.portraits_recompression from anon, authenticated;
