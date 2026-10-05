-- =====================================================================
-- PRESSE LOT 2 — LECTURE D'UNE EDITION SANS SON BLOC DE MATIERE BRUTE
-- =====================================================================
-- Miroir versionne de la migration appliquee le 21 septembre 2026 sous le nom
-- `presse_lot2_kiosque_lecture_edition`. C'est la SEULE migration du Lot 2 :
-- le kiosque, les archives et la pagination se font integralement en PostgREST
-- avec un `select=` explicite, sans aucun objet serveur supplementaire.
--
-- MESURE A L'ORIGINE DE CETTE RPC. L'ouverture du journal faisait un
-- sbGet SANS `select=` : PostgREST renvoyait donc toutes les colonnes, dont
-- `faits_sources` -- 107 kB en moyenne pour 4,7 kB reellement affiches.
--
-- Les colonnes de contenu se recuperent tres bien en PostgREST avec un
-- `select=` explicite. UNE SEULE CHOSE ne s'y exprime pas : l'index d'images.
-- Le renderer resout `image.ref_id` en cherchant le fait cite dans
-- faits_sources.FACTS / PUBLIC_STATEMENTS, et n'en lit que `photo_url`
-- (portrait de PJ) ou `club_image` (lieu). PostgREST ne sait pas projeter
-- deux champs des elements d'un tableau JSON : il faut le faire ici.
--
-- CE QUE CETTE FONCTION RENVOIE. Le contenu, l'identite du titre, et un
-- faits_sources REDUIT aux seuls faits reellement cites par une image, avec
-- leurs trois champs utiles. La forme est celle que le renderer attend deja
-- ({FACTS:[...], PUBLIC_STATEMENTS:[...]}) : construireIndexFaitsJournal
-- fonctionne sans aucune modification.
--
-- MESURE SUR LES 24 EDITIONS v2 PUBLIEES : 119 images referencees, dont
-- 17 seulement retrouvent leur fait et se resolvent reellement. Ces 17
-- pesent 172 kB au total, soit 7,3 kB par edition en moyenne, contre 107 kB
-- pour le blob entier. Aucune image affichee aujourd'hui ne disparait.
-- Mesure de bout en bout sur le reseau (edition republic du 21/09) :
-- 106 336 octets avant, 12 340 apres (kiosque + lecture), soit -88,4 %.
--
-- DEDOUBLONNAGE NON RETENU. Un meme URI peut etre porte par deux faits cites
-- dans la meme edition. Mesure sur le corpus : 3 cas, 156 octets au total.
-- Aucune complexite ne se justifiait ; le renderer garde son contrat actuel.
--
-- LECTURE SEULE, et deliberement restreinte aux editions v2 PUBLIEES : les
-- editions v1 et les editions en echec ne sont pas lisibles par ce guichet
-- (arbitrages A et B du lot). Elles restent en base, simplement invisibles.
-- Verifie : connaitre l'identifiant d'une edition v1 ou en echec ne suffit
-- pas a l'ouvrir, la fonction rend NULL.
CREATE OR REPLACE FUNCTION public.journal_edition_lire(p_edition_id text)
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
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

-- La lecture de la presse est publique : journal_editions et journaux le sont
-- deja (policies USING(true)). Cette RPC ne donne donc acces a rien de plus --
-- elle donne acces a MOINS, en retirant la matiere brute du paquet.
-- REVOKE explicite : les DEFAULT PRIVILEGES du schema public reaccordent
-- EXECUTE a anon sur chaque nouvelle fonction. Ne jamais s'en remettre a eux.
REVOKE ALL ON FUNCTION public.journal_edition_lire(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.journal_edition_lire(text) TO anon, authenticated, service_role;
