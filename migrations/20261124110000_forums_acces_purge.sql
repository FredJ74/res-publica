-- NON APPLIQUÉE — à appliquer par l'agent principal à la fusion (mission « Purge », bloc B, point B.1).
-- RÈGLES D'ACCÈS DES FORUMS (Fred, 24/11/2026 ; GAME-DESIGN-FORUMS.md, section « Règles d'accès du 24/11/2026 ») :
--   - le forum national de son pays est toujours accessible (son pays = sa NATIONALITÉ, jamais sa position) ;
--   - à l'étranger, le forum national du pays visité est en lecture seule ;
--   - le forum local de sa ville de domiciliation est toujours accessible (lecture et écriture), où que l'on soit ;
--   - le forum local d'une ville visitée est en lecture et en écriture ;
--   - les sous-forums nationaux (presidence, assemblee, gouvernement, presse) suivent la règle du forum national.
-- CAUSE DU DÉFAUT DE BERNARD (Sovarka, lu en production le 24/11) : forum_lecture_autorisee rendait « true » pour tout
-- forum autre que national / local_ / org_, sans regarder le pays du sujet ; les sujets de Républia de la Présidence, du
-- Gouvernement et de la Presse remontaient donc chez un personnage de Sovarka (et l'écran ne filtrait par pays que
-- national et local_). Désormais ces sous-forums sont lus et écrits avec la règle du forum national.
-- Inchangés : forums d'organisation (adhésion), international, sport, tribunal_<ville> ; réserves propres des sous-forums
-- (création réservée au Président, aux journalistes ; Gouvernement aux ministres) dans forum_publication_jauges_interne.
-- Rejouable : CREATE OR REPLACE, remplacement contrôlé avec marque (purge_b1) qui ne s'applique qu'une fois.
BEGIN;

CREATE OR REPLACE FUNCTION public.forum_lecture_autorisee(p_forum text, p_pays text)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE
  v_nom text := public.mon_personnage();
  v_pays text; v_ville text; v_nat text; v_dom jsonb; v_local text;
BEGIN
  IF p_forum IS NULL THEN RETURN false; END IF;
  IF left(p_forum,4) = 'org_' THEN
    IF v_nom IS NULL THEN RETURN false; END IF;
    RETURN EXISTS (
      SELECT 1 FROM public.organisations o
       WHERE o.id = substring(p_forum from 5)
         AND CASE WHEN o.data IS JSON OBJECT THEN (
           (o.data::jsonb ->> 'chef') = v_nom
           OR EXISTS (
             SELECT 1 FROM jsonb_array_elements(
               CASE WHEN jsonb_typeof(o.data::jsonb -> 'membres') = 'array'
                 THEN o.data::jsonb -> 'membres' ELSE '[]'::jsonb END
             ) m(elem)
             WHERE coalesce(m.elem ->> 'nom', m.elem #>> '{}') = v_nom
           )
         ) ELSE false END
    );
  END IF;
  IF p_forum IN ('national','presidence','assemblee','gouvernement','presse') OR left(p_forum,6) = 'local_' THEN
    IF v_nom IS NULL OR p_pays IS NULL THEN RETURN false; END IF;
    SELECT country, current_city, coalesce(nationalite, country), domicile INTO v_pays, v_ville, v_nat, v_dom
      FROM public.personnages_donnees WHERE name = v_nom;
    IF left(p_forum,6) = 'local_' THEN
      v_local := substring(p_forum from 7);
      -- Ville de domiciliation (toujours) ou ville visitée (là où l'on se trouve).
      RETURN (p_pays = v_dom ->> 'country' AND v_local = v_dom ->> 'city')
          OR (p_pays = v_pays AND v_local = v_ville);
    END IF;
    -- Forum national et sous-forums nationaux : son pays, ou le pays où l'on se trouve (lecture seule, voir l'écriture).
    RETURN p_pays = v_nat OR p_pays = v_pays;
  END IF;
  -- International, sport, tribunaux : règles de lecture inchangées.
  RETURN true;
END;
$function$;
REVOKE ALL ON FUNCTION public.forum_lecture_autorisee(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.forum_lecture_autorisee(text, text) TO authenticated;

-- Écriture : comme la lecture, sauf le forum national (et ses sous-forums) d'un pays qui n'est pas le sien.
CREATE OR REPLACE FUNCTION public.forum_ecriture_autorisee(p_forum text, p_pays text)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
BEGIN
  IF NOT public.forum_lecture_autorisee(p_forum, p_pays) THEN RETURN false; END IF;
  IF p_forum IN ('national','presidence','assemblee','gouvernement','presse')
     AND p_pays IS DISTINCT FROM public.personnage_nationalite(public.mon_personnage()) THEN
    RETURN false;
  END IF;
  RETURN true;
END;
$function$;
REVOKE ALL ON FUNCTION public.forum_ecriture_autorisee(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.forum_ecriture_autorisee(text, text) TO authenticated;

-- Publication par le serveur : le pays d'un NOUVEAU sujet d'un sous-forum national est celui que le joueur affiche
-- (sa nationalité ou le pays où il se trouve), comme pour le forum national ; une réponse dans le forum local de sa
-- ville de domicile reste possible depuis un troisième pays. L'écriture suit toujours forum_ecriture_autorisee.
DO $publier$
DECLARE d text; a text; b text; n int;
  ancres text[] := ARRAY[
    'CASE WHEN f=''national'' OR left(f,6)=''local_'' THEN coalesce(nullif(p_message->>''pays'',''''), a.country) ELSE a.country END',
    'AND t.country IS DISTINCT FROM coalesce(a.nationalite, a.country) THEN'];
  remplacements text[] := ARRAY[
    'CASE WHEN f IN(''national'',''presidence'',''assemblee'',''gouvernement'',''presse'')/*purge_b1*/ OR left(f,6)=''local_'' THEN coalesce(nullif(p_message->>''pays'',''''), a.country) ELSE a.country END',
    'AND t.country IS DISTINCT FROM coalesce(a.nationalite, a.country) AND t.country IS DISTINCT FROM a.domicile->>''country''/*purge_b1*/ THEN'];
  attendus int[] := ARRAY[2, 1];
  i int;
BEGIN
  d := pg_get_functiondef('public.forum_publication_jauges_interne(text,uuid,jsonb)'::regprocedure);
  IF position('purge_b1' IN d) > 0 THEN RETURN; END IF;
  FOR i IN 1 .. array_length(ancres, 1) LOOP
    a := ancres[i]; b := remplacements[i];
    n := (length(d) - length(replace(d, a, ''))) / length(a);
    IF n <> attendus[i] THEN
      RAISE EXCEPTION 'forum_publication_jauges_interne : ancrage % trouvé % fois (attendu %)', i, n, attendus[i];
    END IF;
    d := replace(d, a, b);
  END LOOP;
  EXECUTE d;
END $publier$;

DO $controle$
DECLARE d text := pg_get_functiondef('public.forum_publication_jauges_interne(text,uuid,jsonb)'::regprocedure);
BEGIN
  IF (length(d) - length(replace(d, 'purge_b1', ''))) / length('purge_b1') <> 3
     OR position('''presse''' IN pg_get_functiondef('public.forum_lecture_autorisee(text,text)'::regprocedure)) = 0
     OR position('''presse''' IN pg_get_functiondef('public.forum_ecriture_autorisee(text,text)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'forums_acces_purge : raccords absents';
  END IF;
END $controle$;

NOTIFY pgrst, 'reload schema';
COMMIT;
