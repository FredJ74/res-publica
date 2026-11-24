-- APPLIQUÉE en production le 24/11/2026 (contrôlée en lecture, mission Purge).
-- Purge, bloc A, point A.4 (Fred, 24/11/2026) : l'interview publiée au forum de presse est signée par le journaliste du
-- PAYS de l'interview (Jodie Moitout en Républia, Vera Pravdina en Sovarka : table accueil_journalistes), et non plus
-- « Jodie Moitout » en dur. NON APPLIQUÉE. Rejouable. Rien du goulag.
-- Bug constaté par Fred le 23/11 (RELAIS.md) : l'article d'accueil de Bernard Bernardov (Sovarka) signé Jodie Moitout et
-- rangé dans la presse de Républia.
--  • jodie_interview_vers_forum (déclencheur de interviews_jodie) : auteur = journaliste du pays de l'interview
--    (NEW.country), à défaut la colonne journaliste, à défaut Jodie Moitout. Le pays du sujet reste NEW.country.
--  • Le forum de presse est filtré par pays à l'écran (supabase.js : 'presse' devient un forum territorial, comme
--    'national' et 'local_*'), d'après la colonne country du sujet.
--  • Reprise : les sujets d'interview déjà publiés en Sovarka et signés Jodie Moitout sont re-signés Vera Pravdina (à la
--    date du 24/11 : le seul est celui de Bernard Bernardov). Leur pays (soviet) les range dans la presse de Sovarka.

CREATE OR REPLACE FUNCTION public.jodie_interview_vers_forum()
 RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_id text; v_texte text; v_auteur text;
BEGIN
 IF NOT NEW.publie OR NEW.publie_le IS NULL OR nullif(btrim(NEW.article_titre),'') IS NULL
    OR nullif(btrim(NEW.article_texte),'') IS NULL THEN RETURN NEW; END IF;
 v_id := 'interview-jodie-'||NEW.id;
 -- Journaliste du pays de l'interview (Fred, 24/11/2026, purge A.4).
 v_auteur := coalesce((SELECT j.journaliste FROM public.accueil_journalistes j WHERE j.pays = NEW.country),
                      nullif(btrim(NEW.journaliste), ''), 'Jodie Moitout');
 -- Le forum affiche du HTML ; l'article original reste intact dans interviews_jodie.
 v_texte := replace(replace(replace(NEW.article_texte,'&','&amp;'),'<','&lt;'),'>','&gt;');
 v_texte := replace(v_texte,E'\n','<br>');
 INSERT INTO public.forum_topics(id,forum_id,title,author,country,time,last_post_author,last_post_time)
 VALUES(v_id,'presse',NEW.article_titre,v_auteur,NEW.country,NEW.publie_le::text,v_auteur,NEW.publie_le::text)
 ON CONFLICT(id) DO UPDATE SET title=EXCLUDED.title, author=EXCLUDED.author, country=EXCLUDED.country,
   last_post_author=CASE WHEN public.forum_topics.last_post_author = public.forum_topics.author THEN EXCLUDED.author
                         ELSE public.forum_topics.last_post_author END;
 INSERT INTO public.forum_posts(id,topic_id,author,content,time)
 VALUES(v_id||'-article',v_id,v_auteur,v_texte,NEW.publie_le::text)
 ON CONFLICT(id) DO UPDATE SET content=EXCLUDED.content, author=EXCLUDED.author;
 -- Le journal lit deja interviews_jodie : ne pas doubler ce circuit par une seconde file.
 RETURN NEW; /* interview_journaliste_pays_v1 */
END;
$function$;

-- Reprise des interviews de Sovarka déjà publiées sous la signature de Jodie Moitout.
UPDATE public.forum_posts p SET author = j.journaliste
  FROM public.forum_topics t, public.accueil_journalistes j
 WHERE p.id = t.id || '-article' AND t.id LIKE 'interview-jodie-%' AND t.forum_id = 'presse'
   AND j.pays = t.country AND t.country = 'soviet' AND p.author = 'Jodie Moitout';
UPDATE public.forum_topics t SET author = j.journaliste,
       last_post_author = CASE WHEN t.last_post_author = 'Jodie Moitout' THEN j.journaliste ELSE t.last_post_author END
  FROM public.accueil_journalistes j
 WHERE t.id LIKE 'interview-jodie-%' AND t.forum_id = 'presse' AND j.pays = t.country AND t.country = 'soviet'
   AND t.author = 'Jodie Moitout';
UPDATE public.interviews_jodie i SET journaliste = j.journaliste
  FROM public.accueil_journalistes j
 WHERE j.pays = i.country AND i.country = 'soviet' AND i.publie AND coalesce(i.journaliste, 'Jodie Moitout') = 'Jodie Moitout';
