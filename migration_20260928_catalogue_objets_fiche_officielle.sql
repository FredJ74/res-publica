-- =====================================================================
-- L2 — FICHE OFFICIELLE
-- =====================================================================
-- Migration appliquee en base : 20260928000228 catalogue_objets_fiche_officielle
-- (5e et derniere des migrations du lot L2 ; s'applique apres
--  migration_20260928_catalogue_objets_resolveur.sql).
--
-- Ce fichier reproduit A L'IDENTIQUE le SQL applique. Ne pas le rejouer sur
-- une base ou la migration figure deja dans supabase_migrations.
-- =====================================================================

-- FICHE OFFICIELLE (L2, dernier element)
-- Lecture seule, autoritaire sur les proprietes systeme. Aucune ecriture possible.
--
-- SECURITY INVOKER (defaut) et NON definer : la fonction ne lit que les tables
-- catalogue_*, publiquement lisibles par leurs policies SELECT. Aucun privilege
-- supplementaire n'est necessaire, donc aucun n'est accorde.
--
-- CE QU'ELLE N'EXPOSE JAMAIS :
--   - catalogue_correspondance_legacy.note (notes d'audit internes : « ANOMALIE... »,
--     « Objet de QUETE : hors catalogue... ») ;
--   - catalogue_correspondance_legacy.source_audit (chemins:lignes du depot) ;
--   - catalogue_generiques.note ;
--   - le motif et la valeur de resolution.
-- Ces champs servent l'ingenierie, pas le joueur.
--
-- ORDRE DE PRIORITE DES EFFETS : effets reellement appliques a CET objet historique
-- d'abord, effets du generique ensuite. En L2 les generiques sont tous a NULL, donc
-- seuls les effets historiques remontent ; la bascule est deja en place pour L5, ou
-- une reference neuve s'appuiera sur le generique.
create or replace function public.objet_fiche_officielle(p_objet jsonb)
returns jsonb
language sql
stable
as $$
  with r as (
    select * from public.generique_de_objet(p_objet) limit 1
  ),
  g as (
    select gen.*, fam.libelle as famille_libelle
      from r
      join public.catalogue_generiques gen on gen.id = r.generique_id
      join public.catalogue_familles    fam on fam.id = gen.famille_id
  ),
  v as (
    select va.libelle, va.capacites
      from r
      join public.catalogue_variantes va on va.id = r.variante_id
  ),
  t as (
    select coalesce(jsonb_agg(ty.libelle order by ty.ordre), '[]'::jsonb) as types
      from g
      join public.catalogue_generique_type gt on gt.generique_id = g.id
      join public.catalogue_types ty on ty.id = gt.type_id
  )
  select case
    when not exists (select 1 from r) then
      jsonb_build_object('resolu', false)
    else
      (select jsonb_strip_nulls(jsonb_build_object(
        'resolu',        true,
        'generique_id',  g.id,
        'generique',     g.libelle,
        'famille',       g.famille_libelle,
        'types',         (select types from t),
        'variante',      (select libelle from v),
        'regime',        g.regime,
        'est_service',   g.est_service,
        'effets',        coalesce((select effets_effectifs from r), g.effets),
        'capacites',     coalesce((select capacites from v), g.capacites),
        'consommable',   g.consommable,
        'equipable',     g.equipable,
        'encombrement',  g.encombrement,
        'durabilite',    g.durabilite,
        'conditions',    g.conditions,
        'contraintes',   g.contraintes
      )) || jsonb_build_object(
        'aucun_effet',
        (coalesce((select effets_effectifs from r), g.effets) is null
         and coalesce((select capacites from v), g.capacites) is null)
      )
      from g)
  end;
$$;

comment on function public.objet_fiche_officielle(jsonb) is
  'Partie OFFICIELLE de la fiche d''un objet. Lecture seule. N''expose jamais les notes d''audit, les sources de code ni le motif de resolution. Rend {"resolu": false} pour un objet hors catalogue : aucun generique de repli n''est jamais attribue.';

revoke all on function public.objet_fiche_officielle(jsonb) from anon, authenticated;
grant execute on function public.objet_fiche_officielle(jsonb) to anon, authenticated;
