-- PRESSE (décisions de Fred du 21/11/2026, étape F).
-- • F4 noms cliquables : journal_edition_lire renvoie aussi « noms_cites », les personnages joueurs cités par les faits
--   sources du numéro (acteur ou victime avec estPJ, auteur IDENTIFIÉ). Un auteur anonyme n'y figure jamais.
-- • F1 aucune référence au monde réel : les quatre numéros déjà parus qui écrivaient « soviétique » sont corrigés
--   (adjectif → « de Sovarka », nom → « Sovarkiens ») dans leurs pages lues par les joueurs ; les faits sources archivés
--   ne sont pas réécrits. Le filet du générateur (assainirMondeReel) empêche toute récidive.
BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.rp_raccorder(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn);
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, p_avant, ''))) / length(p_avant) <> 1 THEN RAISE EXCEPTION '% : ancrage (%)', p_fn, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : raccord absent', p_fn; END IF;
END $$;

CREATE OR REPLACE FUNCTION public.journal_noms_cites_interne(p_faits jsonb)
RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT coalesce(jsonb_agg(DISTINCT n ORDER BY n), '[]'::jsonb) FROM (
    SELECT f ->> 'acteur' AS n FROM jsonb_array_elements(coalesce(p_faits -> 'FACTS', '[]') || coalesce(p_faits -> 'PUBLIC_STATEMENTS', '[]')) f
     WHERE coalesce((f ->> 'estPJ')::boolean, false)
    UNION SELECT f -> 'victime' ->> 'nom' FROM jsonb_array_elements(coalesce(p_faits -> 'FACTS', '[]')) f
     WHERE coalesce((f -> 'victime' ->> 'estPJ')::boolean, false)
    UNION SELECT f -> 'auteur' ->> 'nom' FROM jsonb_array_elements(coalesce(p_faits -> 'FACTS', '[]')) f
     WHERE coalesce((f -> 'auteur' ->> 'identifie')::boolean, false)) x
  WHERE n IS NOT NULL AND length(btrim(n)) >= 2;
$$;
SELECT pg_temp.rp_raccorder('public.journal_edition_lire(text)'::regprocedure,
  $a$           'faits_sources', jsonb_build_object($a$,
  $b$           'noms_cites', public.journal_noms_cites_interne(e.faits_sources) /* presse_noms_cites_v1 */,
           'faits_sources', jsonb_build_object($b$,
  'presse_noms_cites_v1');

CREATE OR REPLACE FUNCTION pg_temp.monde_reel(t text) RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT regexp_replace(regexp_replace(regexp_replace(regexp_replace(regexp_replace(regexp_replace(t,
    'l[''’]Union soviétique', 'la Sovarka', 'g'), '\mUnion soviétique\M', 'Sovarka', 'gi'), '\mURSS\M', 'Sovarka', 'g'),
    '\mSoviétiques\M', 'Sovarkiens', 'g'), '\msoviétiques\M', 'de Sovarka', 'g'), '\msoviétique\M', 'de Sovarka', 'g');
$$;
UPDATE public.journal_editions
   SET une = pg_temp.monde_reel(une::text)::jsonb,
       double_page_centrale = pg_temp.monde_reel(double_page_centrale::text)::jsonb,
       page_economie_societe = pg_temp.monde_reel(page_economie_societe::text)::jsonb
 WHERE (coalesce(une::text, '') || coalesce(double_page_centrale::text, '') || coalesce(page_economie_societe::text, '')) ~* '(soviétique|URSS)';

DO $v$ BEGIN
  IF EXISTS (SELECT 1 FROM public.journal_editions
              WHERE (coalesce(une::text, '') || coalesce(double_page_centrale::text, '') || coalesce(page_economie_societe::text, '')) ~* '(soviétique|URSS)') THEN
    RAISE EXCEPTION 'références au monde réel restantes';
  END IF;
END $v$;

REVOKE ALL ON FUNCTION public.journal_noms_cites_interne(jsonb) FROM PUBLIC, anon, authenticated;

COMMIT;
