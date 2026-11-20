-- ORGANISATIONS SECRÈTES (décisions de Fred du 20/11/2026). GAME-DESIGN-CRIMINALITE.md, « Organisations secrètes ».
--  • Une organisation secrète (type secret : criminelle, loge… ; ou visible = false) APPARAÎT dans la liste des
--    organisations, mais le nom de ses membres n'est JAMAIS révélé : ni dans la liste, ni ailleurs.
--  • À la création, le chef choisit le CLOISONNEMENT : 'connus' (les membres se connaissent) ou 'cloisonne' (chacun ne
--    connaît que lui-même ; ni les autres membres, ni le chef, ni les responsables).
--  • Le chef (et le fondateur) voit toujours la liste complète des membres.
--  • La table brute d'une organisation secrète n'est plus lisible que par son chef ou son fondateur ; tout le monde lit
--    les organisations par organisations_lire(), qui rend à chacun la vue qui lui revient (aucun compteur de membres pour
--    l'extérieur).
--  • Fuites indirectes : le vrai auteur d'un sujet, d'un message de forum ou d'un courrier signé par une organisation
--    secrète (author_real / from_real) n'est plus écrit dans la ligne lisible : il est rangé dans auteurs_secrets
--    (serveur seul) ; le chef garde ses droits d'édition et de suppression, la modération le retrouve.
-- Idempotente.
BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.rp_raccorder(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn);
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, p_avant, ''))) / length(p_avant) <> 1 THEN
    RAISE EXCEPTION '% : ancrage introuvable ou multiple (%)', p_fn, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : raccord absent', p_fn; END IF;
END $$;

-- Secrète ? (même règle que la lecture publique jusqu'ici : non visible, ou criminelle)
CREATE OR REPLACE FUNCTION public.organisation_secrete_donnees_interne(p_data jsonb)
RETURNS boolean LANGUAGE sql IMMUTABLE AS $$
  SELECT coalesce(p_data ->> 'visible', 'false') <> 'true' OR coalesce(p_data ->> 'type', '') = 'criminelle';
$$;
GRANT EXECUTE ON FUNCTION public.organisation_secrete_donnees_interne(jsonb) TO anon, authenticated;   -- appelée par la règle de lecture
CREATE OR REPLACE FUNCTION public.organisation_secrete_interne(p_id text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT coalesce((SELECT public.organisation_secrete_donnees_interne(o.data::jsonb) FROM public.organisations o WHERE o.id = p_id), false);
$$;
CREATE OR REPLACE FUNCTION public.organisation_chef_est_moi(p_id text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT public.mon_personnage() IS NOT NULL AND EXISTS (SELECT 1 FROM public.organisations o
    WHERE o.id = p_id AND public.mon_personnage() IN (o.data::jsonb ->> 'chef', o.data::jsonb ->> 'fondateur'));
$$;
GRANT EXECUTE ON FUNCTION public.organisation_chef_est_moi(text) TO authenticated;

-- La vue d'une organisation pour un lecteur donné.
CREATE OR REPLACE FUNCTION public.organisation_vue_interne(p_data jsonb, p_moi text)
RETURNS jsonb LANGUAGE plpgsql STABLE AS $$
DECLARE v_membres jsonb := CASE WHEN jsonb_typeof(p_data -> 'membres') = 'array' THEN p_data -> 'membres' ELSE '[]'::jsonb END;
  v_moi_entree jsonb;
BEGIN
  IF NOT public.organisation_secrete_donnees_interne(p_data) THEN RETURN p_data; END IF;
  IF p_moi IS NOT NULL AND p_moi IN (p_data ->> 'chef', p_data ->> 'fondateur') THEN
    RETURN p_data || jsonb_build_object('secrete', true);
  END IF;
  SELECT m INTO v_moi_entree FROM jsonb_array_elements(v_membres) m WHERE m ->> 'nom' = p_moi LIMIT 1;
  IF v_moi_entree IS NOT NULL AND coalesce(p_data ->> 'cloisonnement', 'connus') = 'connus' THEN
    RETURN (p_data - 'demandesAdhesion') || jsonb_build_object('secrete', true);
  END IF;
  IF v_moi_entree IS NOT NULL THEN
    RETURN (p_data - 'demandesAdhesion' - 'chef' - 'fondateur' - 'president' - 'tresorier' - 'secretaire' - 'election')
      || jsonb_build_object('membres', jsonb_build_array(v_moi_entree), 'secrete', true, 'membres_masques', true);
  END IF;
  -- Extérieur : le nom et la nature, jamais un membre ni un compteur.
  RETURN jsonb_strip_nulls(jsonb_build_object('id', p_data ->> 'id', 'nom', p_data ->> 'nom', 'type', p_data ->> 'type',
    'desc', p_data ->> 'desc', 'country', p_data ->> 'country', 'country_origine', p_data ->> 'country_origine',
    'avatar', p_data -> 'avatar', 'visible', false, 'secrete', true, 'membres_masques', true,
    'membres', '[]'::jsonb, 'demandesAdhesion', '[]'::jsonb));
END $$;

CREATE OR REPLACE FUNCTION public.organisations_lire()
RETURNS TABLE(id text, country_origine text, data jsonb, created_at timestamptz)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT o.id, o.country_origine, public.organisation_vue_interne(o.data::jsonb, public.mon_personnage()), o.created_at
    FROM public.organisations o
   WHERE o.data IS JSON OBJECT
   ORDER BY o.created_at;
$$;
REVOKE ALL ON FUNCTION public.organisations_lire() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.organisations_lire() TO anon, authenticated;

-- Table brute : publiques pour tous ; secrètes pour leur chef ou fondateur seulement.
DROP POLICY IF EXISTS organisations_lecture_publique ON public.organisations;
CREATE POLICY organisations_lecture_publique ON public.organisations FOR SELECT USING (
  (data IS JSON OBJECT AND NOT public.organisation_secrete_donnees_interne(data::jsonb))
  OR (public.mon_personnage() IS NOT NULL AND data IS JSON OBJECT
      AND public.mon_personnage() IN (data::jsonb ->> 'chef', data::jsonb ->> 'fondateur')));

-- Cloisonnement choisi à la création (secrètes seulement ; 'connus' par défaut, comme jusqu'ici).
SELECT pg_temp.rp_raccorder('public.organisation_vie_commande(text,text,text,jsonb)'::regprocedure,
  $a$      'visible', NOT (v_def->>'secret')::boolean);$a$,
  $b$      'visible', NOT (v_def->>'secret')::boolean,
      'cloisonnement', CASE WHEN (v_def->>'secret')::boolean AND p_parametres->>'cloisonnement' = 'cloisonne' THEN 'cloisonne' ELSE 'connus' END); /* organisations_secretes_v1 */$b$,
  'organisations_secretes_v1');

-- Fuites indirectes : vrai auteur d'un contenu signé par une organisation secrète.
CREATE TABLE IF NOT EXISTS public.auteurs_secrets (
  source text NOT NULL, contenu_id text NOT NULL, auteur text NOT NULL, organisation text,
  cree_le timestamptz NOT NULL DEFAULT now(), PRIMARY KEY (source, contenu_id));
ALTER TABLE public.auteurs_secrets ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.auteurs_secrets FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.auteurs_secrets_trg()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_org text; v_reel text;
BEGIN
  IF TG_TABLE_NAME = 'mails' THEN v_org := NEW.from_org_id; v_reel := NEW.from_real;
  ELSE v_org := NEW.author_org_id; v_reel := NEW.author_real; END IF;
  IF v_org IS NULL OR v_reel IS NULL OR NOT public.organisation_secrete_interne(v_org) THEN RETURN NEW; END IF;
  INSERT INTO public.auteurs_secrets (source, contenu_id, auteur, organisation) VALUES (TG_TABLE_NAME, NEW.id::text, v_reel, v_org)
  ON CONFLICT (source, contenu_id) DO UPDATE SET auteur = excluded.auteur, organisation = excluded.organisation;
  IF TG_TABLE_NAME = 'mails' THEN NEW.from_real := NULL; ELSE NEW.author_real := NULL; END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.auteurs_secrets_trg() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS zz_auteurs_secrets ON public.forum_posts;
CREATE TRIGGER zz_auteurs_secrets BEFORE INSERT OR UPDATE ON public.forum_posts FOR EACH ROW EXECUTE FUNCTION public.auteurs_secrets_trg();
DROP TRIGGER IF EXISTS zz_auteurs_secrets ON public.forum_topics;
CREATE TRIGGER zz_auteurs_secrets BEFORE INSERT OR UPDATE ON public.forum_topics FOR EACH ROW EXECUTE FUNCTION public.auteurs_secrets_trg();
DROP TRIGGER IF EXISTS zz_auteurs_secrets ON public.mails;
CREATE TRIGGER zz_auteurs_secrets BEFORE INSERT OR UPDATE ON public.mails FOR EACH ROW EXECUTE FUNCTION public.auteurs_secrets_trg();

-- Le chef garde la main sur ce qu'il a signé au nom de l'organisation.
CREATE OR REPLACE FUNCTION public.contenu_organisation_est_moi(p_org text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT p_org IS NOT NULL AND public.organisation_chef_est_moi(p_org);
$$;
GRANT EXECUTE ON FUNCTION public.contenu_organisation_est_moi(text) TO authenticated;

DROP POLICY IF EXISTS forum_topics_creation ON public.forum_topics;
CREATE POLICY forum_topics_creation ON public.forum_topics FOR INSERT WITH CHECK (
  ((author = public.mon_personnage()) OR (author_real = public.mon_personnage()) OR public.contenu_organisation_est_moi(author_org_id))
  AND public.forum_ecriture_autorisee(forum_id, country));
DROP POLICY IF EXISTS forum_topics_maj_auteur ON public.forum_topics;
CREATE POLICY forum_topics_maj_auteur ON public.forum_topics FOR UPDATE
  USING (((author = public.mon_personnage()) OR (author_real = public.mon_personnage()) OR public.contenu_organisation_est_moi(author_org_id)) AND public.forum_ecriture_autorisee(forum_id, country))
  WITH CHECK (((author = public.mon_personnage()) OR (author_real = public.mon_personnage()) OR public.contenu_organisation_est_moi(author_org_id)) AND public.forum_ecriture_autorisee(forum_id, country));
DROP POLICY IF EXISTS forum_topics_suppression_auteur ON public.forum_topics;
CREATE POLICY forum_topics_suppression_auteur ON public.forum_topics FOR DELETE
  USING (((author = public.mon_personnage()) OR (author_real = public.mon_personnage()) OR public.contenu_organisation_est_moi(author_org_id)) AND public.forum_ecriture_autorisee(forum_id, country));
DROP POLICY IF EXISTS forum_posts_creation ON public.forum_posts;
CREATE POLICY forum_posts_creation ON public.forum_posts FOR INSERT WITH CHECK (
  ((author = public.mon_personnage()) OR (author_real = public.mon_personnage()) OR public.contenu_organisation_est_moi(author_org_id))
  AND EXISTS (SELECT 1 FROM public.forum_topics t WHERE t.id = forum_posts.topic_id AND public.forum_ecriture_autorisee(t.forum_id, t.country)));
DROP POLICY IF EXISTS forum_posts_maj_auteur ON public.forum_posts;
CREATE POLICY forum_posts_maj_auteur ON public.forum_posts FOR UPDATE
  USING (((author = public.mon_personnage()) OR (author_real = public.mon_personnage()) OR public.contenu_organisation_est_moi(author_org_id)) AND EXISTS (SELECT 1 FROM public.forum_topics t WHERE t.id = forum_posts.topic_id))
  WITH CHECK (((author = public.mon_personnage()) OR (author_real = public.mon_personnage()) OR public.contenu_organisation_est_moi(author_org_id)) AND EXISTS (SELECT 1 FROM public.forum_topics t WHERE t.id = forum_posts.topic_id));
DROP POLICY IF EXISTS forum_posts_suppression_auteur ON public.forum_posts;
CREATE POLICY forum_posts_suppression_auteur ON public.forum_posts FOR DELETE
  USING (((author = public.mon_personnage()) OR (author_real = public.mon_personnage()) OR public.contenu_organisation_est_moi(author_org_id)) AND EXISTS (SELECT 1 FROM public.forum_topics t WHERE t.id = forum_posts.topic_id));
DROP POLICY IF EXISTS mails_lecture_partie ON public.mails;
CREATE POLICY mails_lecture_partie ON public.mails FOR SELECT USING (
  (to_player = public.mon_personnage()) OR (from_player = public.mon_personnage()) OR (from_real = public.mon_personnage())
  OR public.contenu_organisation_est_moi(from_org_id));
DROP POLICY IF EXISTS mails_envoi ON public.mails;
CREATE POLICY mails_envoi ON public.mails FOR INSERT WITH CHECK (
  (from_player = public.mon_personnage()) OR (from_real = public.mon_personnage()) OR public.mail_expediteur_organisation(from_player)
  OR public.mail_expediteur_autorise(from_player, to_player) OR public.contenu_organisation_est_moi(from_org_id));

-- La modération (signalements) retrouve le vrai auteur d'un contenu d'organisation secrète.
SELECT pg_temp.rp_raccorder('public.message_signaler(text,text,text)'::regprocedure,
  $a$    SELECT coalesce(nullif(m.from_real, ''), m.from_player), ARRAY[m.to_player], left(m.subject || ' — ' || m.body, 2000)$a$,
  $b$    SELECT coalesce(nullif(m.from_real, ''), (SELECT s.auteur FROM public.auteurs_secrets s WHERE s.source = 'mails' AND s.contenu_id = m.id::text), m.from_player) /* organisations_secretes_v1 */,
           ARRAY[m.to_player], left(m.subject || ' — ' || m.body, 2000)$b$,
  'organisations_secretes_v1');
SELECT pg_temp.rp_raccorder('public.message_signaler(text,text,text)'::regprocedure,
  $a$    SELECT coalesce(nullif(p.author_real, ''), p.author), '{}'::text[], left(p.content, 2000)$a$,
  $b$    SELECT coalesce(nullif(p.author_real, ''), (SELECT s.auteur FROM public.auteurs_secrets s WHERE s.source = 'forum_posts' AND s.contenu_id = p.id::text), p.author) /* organisations_secretes_forum_v1 */,
           '{}'::text[], left(p.content, 2000)$b$,
  'organisations_secretes_forum_v1');

COMMIT;
