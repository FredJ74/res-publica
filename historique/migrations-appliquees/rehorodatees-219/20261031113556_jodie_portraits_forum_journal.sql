-- PRÉPARATION NON APPLIQUÉE : rehorodatée après la coupe canonique du 31/10/2026.
-- Ancien fichier : 20261019002000_jodie_portraits_forum_journal.sql ; aucun changement de règle.
-- Le portrait propose par courrier doit figurer a la fois sur le forum Presse & Medias
-- et dans l'edition suivante de L'Autruche Entravee.
-- Le post publie est la source des paroles : jamais de reconstitution par IA.
CREATE OR REPLACE FUNCTION public.jodie_portrait_vers_journal()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_sujet public.forum_topics%ROWTYPE;
BEGIN
  SELECT * INTO v_sujet FROM public.forum_topics WHERE id=NEW.topic_id;
  IF v_sujet.forum_id='presse' AND v_sujet.author='Jodie Moitout'
     AND NEW.author='Jodie Moitout'
     AND v_sujet.title LIKE 'Un jour, un portrait : %'
     AND length(btrim(coalesce(NEW.content,'')))>=40
  THEN
    INSERT INTO public.journal_articles_en_attente
      (id,country,rubrique,titre,texte,origine,priorite,statut,dedup_key)
    VALUES ('jodie-portrait-'||NEW.topic_id,v_sujet.country,'Portraits',
      v_sujet.title,NEW.content,'portrait_jodie','importante','attente',
      'portrait-jodie-'||NEW.topic_id)
    ON CONFLICT (id) DO UPDATE SET texte=EXCLUDED.texte
      WHERE public.journal_articles_en_attente.integree_le IS NULL;
  END IF;
  RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS trg_jodie_portrait_vers_journal ON public.forum_posts;
CREATE TRIGGER trg_jodie_portrait_vers_journal
AFTER INSERT ON public.forum_posts
FOR EACH ROW EXECUTE FUNCTION public.jodie_portrait_vers_journal();
