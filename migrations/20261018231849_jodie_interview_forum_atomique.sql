-- PREPARE, NON APPLIQUE. Pas de rattrapage ni de modification des entretiens existants.
BEGIN;
DO $controle$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
                WHERE n.nspname='public' AND c.relname='interviews_jodie' AND c.relrowsecurity) THEN
   RAISE EXCEPTION 'interviews_jodie_rls_non_confirmee';
 END IF;
 IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='interviews_jodie'
            AND cmd IN ('ALL','INSERT','UPDATE') AND roles && ARRAY['public','anon','authenticated']::name[]) THEN
   RAISE EXCEPTION 'interviews_jodie_ecriture_cliente_non_autorisee';
 END IF;
END;
$controle$;
CREATE OR REPLACE FUNCTION public.jodie_interview_vers_forum()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='public','pg_temp' AS $fonction$
DECLARE v_id text; v_texte text;
BEGIN
 IF NOT NEW.publie OR NEW.publie_le IS NULL OR nullif(btrim(NEW.article_titre),'') IS NULL
    OR nullif(btrim(NEW.article_texte),'') IS NULL THEN RETURN NEW; END IF;
 v_id := 'interview-jodie-'||NEW.id;
 -- Le forum affiche du HTML ; l'article original reste intact dans interviews_jodie.
 v_texte := replace(replace(replace(NEW.article_texte,'&','&amp;'),'<','&lt;'),'>','&gt;');
 v_texte := replace(v_texte,E'\n','<br>');
 INSERT INTO public.forum_topics(id,forum_id,title,author,country,time,last_post_author,last_post_time)
 VALUES(v_id,'presse',NEW.article_titre,'Jodie Moitout',NEW.country,NEW.publie_le::text,'Jodie Moitout',NEW.publie_le::text)
 ON CONFLICT(id) DO UPDATE SET title=EXCLUDED.title;
 INSERT INTO public.forum_posts(id,topic_id,author,content,time)
 VALUES(v_id||'-article',v_id,'Jodie Moitout',v_texte,NEW.publie_le::text)
 ON CONFLICT(id) DO UPDATE SET content=EXCLUDED.content;
 -- Le journal lit deja interviews_jodie : ne pas doubler ce circuit par une seconde file.
 RETURN NEW;
END;
$fonction$;
REVOKE ALL ON FUNCTION public.jodie_interview_vers_forum() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS trg_jodie_interview_vers_forum ON public.interviews_jodie;
CREATE TRIGGER trg_jodie_interview_vers_forum
AFTER INSERT OR UPDATE OF article_titre,article_texte,publie,publie_le ON public.interviews_jodie
FOR EACH ROW EXECUTE FUNCTION public.jodie_interview_vers_forum();
COMMIT;
