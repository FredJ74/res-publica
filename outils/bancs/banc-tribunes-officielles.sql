-- BANC DES TRIBUNES OFFICIELLES (11 octobre 2026)
--
-- CE BANC NE COMMITE RIEN. Il nomme un President de decor, fait parler un ministre, cree des
-- sujets de forum, et se termine par un RAISE EXCEPTION INCONDITIONNEL. Un banc du 4 octobre 2026
-- a laisse une accusation forgee au nom d'un joueur reel pendant six jours parce qu'il commitait.
--
-- CE QU'IL PROUVE -- le defaut constate en jouant, et ses contre-epreuves :
--   . un MINISTRE peut enfin tenir une conference depuis la tribune du Gouvernement. Il ne
--     pouvait pas : le handler exigeait le poste de President, en dur, quelle que soit la salle ;
--   . le sujet ET le message sont ecrits dans la MEME transaction, et les PA sont pris ;
--   . une simple citoyenne est refusee, et son refus n'ecrit rien et ne preleve rien ;
--   . le PRESIDENT est refuse dans la salle du Gouvernement -- il a la sienne -- et un MINISTRE
--     est refuse a l'Elysee. La frontiere joue dans les deux sens ;
--   . une piece sans tribune, un cout que le miroir ne declare pas, un message vide et un manque
--     de PA sont tous refuses sans rien ecrire ;
--   . anon ne peut pas appeler la porte ;
--   . et la porte de LECTURE dit a l'interface la meme chose que la porte d'ecriture -- c'est
--     l'infobulle fausse qui faisait partie du defaut.
--
-- Usage : coller ce fichier dans un execute_sql. Il doit finir sur
--   ERROR: banc tribune : LES 21 EPREUVES SONT VERTES. -- rien ne doit rester

BEGIN;
CREATE OR REPLACE FUNCTION pg_temp.je_suis(p_uuid text) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', p_uuid, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
END $f$;
CREATE OR REPLACE FUNCTION pg_temp.je_suis_le_serveur() RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  PERFORM set_config('role', 'postgres', true);
  PERFORM set_config('request.jwt.claims', '', true);
END $f$;
GRANT EXECUTE ON FUNCTION pg_temp.je_suis(text) TO PUBLIC;
GRANT EXECUTE ON FUNCTION pg_temp.je_suis_le_serveur() TO PUBLIC;

DO $banc$
DECLARE
  ARNIE_U text := '9abef1c4-75ab-4352-b5ca-a219fc37a35c'; ARNIE text := 'Arnie';
  LEE_U   text := 'ea4a2a0c-a192-4e10-8cff-d5db9b1cceb6'; LEE   text := 'Lee Capene';
  BEN_U   text := 'bafc96b1-1628-4ae2-93d2-78d89f8ac5b5'; BEN   text := 'Ben';
  GOUV text := 'palais-gouvernement'; SPG text := 'salle_presse';
  ELY  text := 'palais-presidentiel';  SPE text := 'salle_presse_elysee';
  v jsonb; n integer := 0; ko integer := 0; v_echecs text := '';
  v_n integer; v_t integer; v_p integer; v_pa integer;
BEGIN
  PERFORM pg_temp.je_suis_le_serveur();
  -- DECOR : Arnie ministre de la Defense (reel), Ben President, Lee simple citoyenne.
  UPDATE public.personnages_donnees
     SET poste = '{"id":"president","name":"President de la Republique"}'::jsonb,
         pa = 12, liquide = 5000 WHERE name = BEN;
  UPDATE public.personnages_donnees SET pa = 12, liquide = 5000 WHERE name IN (ARNIE, LEE);
  UPDATE public.personnages_donnees SET poste = NULL WHERE name = LEE;

  -- ===========================================================================================
  -- A. LE DEFAUT CONSTATE : UN MINISTRE PEUT ENFIN PARLER
  -- ===========================================================================================
  SELECT count(*) INTO v_t FROM public.forum_topics;
  SELECT count(*) INTO v_p FROM public.forum_posts;
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.communication_officielle_publier(GOUV, SPG, 'conference_presse', 2, 0,
        '[CONFERENCE] L armee recrute', '<p>Des postes sont ouverts.</p>', '[]'::jsonb);
  n := n + 1;
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE1 un ministre ne peut toujours pas parler : ' || v::text;
  END IF;
  n := n + 1;
  IF v->>'poste' <> 'min_def' OR v->>'tribune' <> 'la tribune du Gouvernement' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE2 la tribune ou le poste sont mal rendus : ' || v::text;
  END IF;

  PERFORM pg_temp.je_suis_le_serveur();
  n := n + 1;   -- LE SUJET ET LE MESSAGE, DANS LA MEME TRANSACTION
  SELECT count(*) INTO v_n FROM public.forum_topics;
  IF v_n <> v_t + 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE3 le sujet n a pas ete cree';
  END IF;
  n := n + 1;
  SELECT count(*) INTO v_n FROM public.forum_posts;
  IF v_n <> v_p + 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE4 le message n a pas ete cree';
  END IF;
  n := n + 1;
  SELECT count(*) INTO v_n FROM public.forum_posts
   WHERE topic_id = v->>'topic' AND author = ARNIE AND content LIKE '%postes sont ouverts%';
  IF v_n <> 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE5 le message n est pas rattache a son sujet';
  END IF;
  n := n + 1;   -- ET LES PA ONT ETE PRIS
  SELECT pa INTO v_pa FROM public.personnages_donnees WHERE name = ARNIE;
  IF v_pa <> 10 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE6 les 2 PA n ont pas ete preleves (pa=' || v_pa::text || ')';
  END IF;

  -- ===========================================================================================
  -- B. LES CONTRE-EPREUVES D'AUTORITE
  -- ===========================================================================================
  SELECT count(*) INTO v_t FROM public.forum_topics;
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.communication_officielle_publier(GOUV, SPG, 'conference_presse', 2, 0,
        'Moi aussi', '<p>Je parle au nom de l Etat.</p>', '[]'::jsonb);
  n := n + 1;
  IF coalesce((v->>'ok')::boolean, true) IS NOT FALSE
     OR v->>'raison' <> 'poste_non_admis_dans_cette_tribune' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE7 une simple citoyenne a pu tenir une conference : ' || v::text;
  END IF;
  PERFORM pg_temp.je_suis_le_serveur();
  n := n + 1;   -- LE REFUS N'ECRIT RIEN
  SELECT count(*) INTO v_n FROM public.forum_topics;
  IF v_n <> v_t THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE8 un refus a quand meme cree un sujet';
  END IF;
  n := n + 1;   -- ET NE PRELEVE RIEN
  SELECT pa INTO v_pa FROM public.personnages_donnees WHERE name = LEE;
  IF v_pa <> 12 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE9 un refus a preleve des PA (pa=' || v_pa::text || ')';
  END IF;

  -- LE PRESIDENT N'EST PAS LE TITULAIRE DE LA SALLE DU GOUVERNEMENT. C'est le coeur de
  -- l'arbitrage : il a la sienne.
  PERFORM pg_temp.je_suis(BEN_U);
  v := public.communication_officielle_publier(GOUV, SPG, 'conference_presse', 2, 0,
        'Le President parle', '<p>Depuis la salle du Gouvernement.</p>', '[]'::jsonb);
  n := n + 1;
  IF coalesce((v->>'ok')::boolean, true) IS NOT FALSE
     OR v->>'raison' <> 'poste_non_admis_dans_cette_tribune' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE10 le President a pu parler depuis la tribune du Gouvernement : ' || v::text;
  END IF;

  -- MAIS IL PARLE CHEZ LUI.
  v := public.communication_officielle_publier(ELY, SPE, 'conference_presse', 2, 0,
        '[CONFERENCE] Adresse', '<p>Depuis l Elysee.</p>', '[]'::jsonb);
  n := n + 1;
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE
     OR v->>'tribune' <> 'la tribune presidentielle' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE11 le President ne peut pas parler a l Elysee : ' || v::text;
  END IF;

  -- ET UN MINISTRE NE PARLE PAS A L'ELYSEE.
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.communication_officielle_publier(ELY, SPE, 'conference_presse', 2, 0,
        'Un ministre a l Elysee', '<p>Non.</p>', '[]'::jsonb);
  n := n + 1;
  IF coalesce((v->>'ok')::boolean, true) IS NOT FALSE
     OR v->>'raison' <> 'poste_non_admis_dans_cette_tribune' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE12 un ministre a pu parler depuis la tribune presidentielle : ' || v::text;
  END IF;

  -- ===========================================================================================
  -- C. CE QUI NE PASSE PAS NON PLUS
  -- ===========================================================================================
  n := n + 1;   -- UNE PIECE QUI N'EST PAS UNE TRIBUNE
  v := public.communication_officielle_publier(GOUV, 'salle_conseil', 'conference_presse', 2, 0,
        'Depuis le Conseil', '<p>Non.</p>', '[]'::jsonb);
  IF coalesce((v->>'ok')::boolean, true) IS NOT FALSE OR v->>'raison' <> 'salle_sans_tribune' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE13 on a pu parler depuis une piece sans tribune : ' || v::text;
  END IF;

  n := n + 1;   -- UN COUT QUE LE MIROIR NE DECLARE PAS
  v := public.communication_officielle_publier(GOUV, SPG, 'conference_presse', 0, 0,
        'Gratuite', '<p>Non.</p>', '[]'::jsonb);
  IF coalesce((v->>'ok')::boolean, true) IS NOT FALSE OR v->>'raison' <> 'cout_non_declare' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE14 une conference gratuite est passee : ' || v::text;
  END IF;

  n := n + 1;   -- UN TITRE OU UN CONTENU VIDE
  v := public.communication_officielle_publier(GOUV, SPG, 'conference_presse', 2, 0,
        '   ', '   ', '[]'::jsonb);
  IF coalesce((v->>'ok')::boolean, true) IS NOT FALSE OR v->>'raison' <> 'titre_ou_contenu_vide' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE15 un message vide est passe : ' || v::text;
  END IF;

  -- PAS ASSEZ DE PA : le refus vient du chemin de paiement atteste, et il n ecrit rien.
  PERFORM pg_temp.je_suis_le_serveur();
  UPDATE public.personnages_donnees SET pa = 1 WHERE name = ARNIE;
  SELECT count(*) INTO v_t FROM public.forum_topics;
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.communication_officielle_publier(GOUV, SPG, 'conference_presse', 2, 0,
        'Sans PA', '<p>Non.</p>', '[]'::jsonb);
  n := n + 1;
  IF coalesce((v->>'ok')::boolean, true) IS NOT FALSE OR v->>'raison' <> 'pa_insuffisants' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE16 une conference sans PA est passee : ' || v::text;
  END IF;
  PERFORM pg_temp.je_suis_le_serveur();
  n := n + 1;
  SELECT count(*) INTO v_n FROM public.forum_topics;
  IF v_n <> v_t THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE17 un refus de paiement a quand meme cree un sujet';
  END IF;

  n := n + 1;   -- ANON NE PEUT RIEN
  BEGIN
    PERFORM set_config('role', 'anon', true);
    v := public.communication_officielle_publier(GOUV, SPG, 'conference_presse', 2, 0,
          'Anon', '<p>Non.</p>', '[]'::jsonb);
    ko := ko + 1; v_echecs := v_echecs || E'\nE18 anon a pu appeler la porte de publication';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.je_suis_le_serveur();

  -- ===========================================================================================
  -- D. LA PORTE DE LECTURE DIT LA VERITE A L'INTERFACE
  -- ===========================================================================================
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.communication_tribune(GOUV, SPG);
  n := n + 1;
  IF coalesce((v->>'je_peux')::boolean, false) IS NOT TRUE
     OR v->>'libelle' <> 'la tribune du Gouvernement' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE19 la lecture refuse le ministre dans sa propre tribune : ' || v::text;
  END IF;
  n := n + 1;
  v := public.communication_tribune(ELY, SPE);
  IF coalesce((v->>'je_peux')::boolean, true) IS NOT FALSE THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE20 la lecture autorise le ministre a l Elysee : ' || v::text;
  END IF;
  n := n + 1;
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.communication_tribune(GOUV, SPG);
  IF coalesce((v->>'je_peux')::boolean, true) IS NOT FALSE
     OR coalesce((v->>'tribune')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE21 la lecture autorise une citoyenne : ' || v::text;
  END IF;

  PERFORM pg_temp.je_suis_le_serveur();
  IF ko = 0 THEN
    RAISE EXCEPTION 'banc tribune : LES % EPREUVES SONT VERTES. -- rien ne doit rester', n;
  ELSE
    RAISE EXCEPTION 'banc tribune : % EPREUVES ROUGES sur %. %', ko, n, v_echecs;
  END IF;
END $banc$;
ROLLBACK;
