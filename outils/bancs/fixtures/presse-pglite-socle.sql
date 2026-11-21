-- Socle minimal pour éprouver la migration presse dans PGlite (banc local).
SET check_function_bodies = off;
CREATE ROLE anon; CREATE ROLE authenticated;
CREATE TABLE public.journaux (id text PRIMARY KEY, nom text, pays text, slug text);
CREATE TABLE public.journal_editions (id text PRIMARY KEY, journal_id text, date_edition date, statut text, prompt_version text,
  une jsonb, double_page_centrale jsonb, page_economie_societe jsonb, faits_sources jsonb);
-- journal_edition_lire : définition de production du 21/11/2026 (avant la migration).
CREATE OR REPLACE FUNCTION public.journal_edition_lire(p_edition_id text)
 RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  WITH e AS (
    SELECT * FROM public.journal_editions
     WHERE id = p_edition_id
       AND statut = 'publiee'
       AND prompt_version = 'v2-la-tribune'
  ),
  refs AS (
    SELECT DISTINCT jsonb_path_query(
             jsonb_build_array(e.une, e.double_page_centrale, e.page_economie_societe),
             'strict $.**.image.ref_id') #>> '{}' AS ref_id
      FROM e
  ),
  images AS (
    SELECT coalesce(jsonb_agg(jsonb_build_object(
             'id',         f ->> 'id',
             'estPJ',      (f ->> 'estPJ')::boolean,
             'photo_url',  f ->> 'photo_url',
             'club_image', f ->> 'club_image')), '[]'::jsonb) AS liste
      FROM e,
           jsonb_array_elements(
             coalesce(e.faits_sources -> 'FACTS', '[]'::jsonb)
             || coalesce(e.faits_sources -> 'PUBLIC_STATEMENTS', '[]'::jsonb)) f
     WHERE f ->> 'id' IN (SELECT ref_id FROM refs WHERE ref_id IS NOT NULL)
       AND coalesce(f ->> 'photo_url', f ->> 'club_image') IS NOT NULL
  )
  SELECT jsonb_build_object(
           'ok', true,
           'id', e.id,
           'journal_id', e.journal_id,
           'date_edition', e.date_edition,
           'journal', jsonb_build_object('nom', j.nom, 'pays', j.pays, 'slug', j.slug),
           'une', e.une,
           'double_page_centrale', e.double_page_centrale,
           'page_economie_societe', e.page_economie_societe,
           -- Meme forme que la colonne d'origine, mais reduite a ce que le
           -- renderer lit reellement.
           'faits_sources', jsonb_build_object(
              'FACTS', (SELECT liste FROM images),
              'PUBLIC_STATEMENTS', '[]'::jsonb))
    FROM e JOIN public.journaux j ON j.id = e.journal_id;
$function$;
