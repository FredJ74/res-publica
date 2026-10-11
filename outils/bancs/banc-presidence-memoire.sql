-- BANC DE LA MEMOIRE DES MANDATS (11 octobre 2026)
--
-- CE BANC NE COMMITE RIEN. Il installe une fausse Presidence, ecrit dans la memoire, declare une
-- guerre, et se termine par un RAISE EXCEPTION INCONDITIONNEL. Un banc du 4 octobre 2026 a laisse
-- une accusation forgee au nom d'un joueur reel pendant six jours parce qu'il avait commite.
--
-- CE QU'IL PROUVE, et chaque point est une exigence de l'arbitrage :
--   . AUCUN PASSE RECONSTRUIT : sans President joueur, rien ne s'ecrit, et la porte le dit ;
--   . les MANDATS sont separes, y compris deux mandats du MEME joueur ;
--   . seuls des faits de SOURCE DECLAREE entrent -- une source inconnue est refusee, et un genre
--     qui contredit sa source aussi ;
--   . une REACTION n'est enregistree que si son auteur est le President : la conference de presse
--     d'un MINISTRE n'entre pas dans la memoire presidentielle, alors que l'ordre porte le meme
--     nom dans les deux salles de presse ;
--   . payer_ordre temoigne des actes SANS qu'aucun handler ait ete touche ;
--   . l'ABSENCE DE REACTION est rendue comme telle -- `suivi_de` nul -- et jamais comme un echec ;
--   . AUCUNE QUALIFICATION : la lecture ne rend ni score, ni note, ni verdict ;
--   . et la CONTRE-EPREUVE d'autorite : le navigateur ne peut pas ecrire dans la memoire.
--
-- MESURES DE DEPART (11 octobre 2026) : memoire vide, aucun President joueur a Republia.
--
-- Usage : coller ce fichier dans un execute_sql. Il doit finir sur
--   ERROR: banc memoire : LES 22 EPREUVES SONT VERTES. -- rien ne doit rester

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
  LEE_UUID  text := 'ea4a2a0c-a192-4e10-8cff-d5db9b1cceb6';   -- future Presidente (decor)
  ARNIE_UUID text := '9abef1c4-75ab-4352-b5ca-a219fc37a35c';  -- ministre de la Defense (reel)
  LEE text := 'Lee Capene'; ARNIE text := 'Arnie';
  T1 timestamptz := now() - interval '10 days';   -- premier mandat
  T2 timestamptz := now() - interval '2 days';    -- second mandat, meme joueuse
  v jsonb; n integer := 0; ko integer := 0; v_echecs text := '';
  v_n integer; v_av integer; m jsonb; f jsonb;
BEGIN
  PERFORM pg_temp.je_suis_le_serveur();

  -- ===========================================================================================
  -- A. AUCUN PASSE RECONSTRUIT
  -- ===========================================================================================
  n := n + 1;   -- E1 : la memoire est vide au depart. Rien n'a ete fabrique a l'installation.
  SELECT count(*) INTO v_n FROM public.presidence_memoire;
  IF v_n <> 0 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE1 la memoire contient deja ' || v_n::text || ' lignes';
  END IF;

  n := n + 1;   -- E2 : SANS President joueur, la porte refuse d'ecrire -- et le dit.
  v := public.presidence_memoire_noter('republic', 'reaction', 'ordre_presidentiel',
                                       'une grace examinee', '{}'::jsonb, LEE);
  IF coalesce((v->>'enregistre')::boolean, true) IS NOT FALSE
     OR v->>'raison' <> 'aucun_president_joueur' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE2 un fait est entre sans President joueur : ' || v::text;
  END IF;
  n := n + 1;
  SELECT count(*) INTO v_n FROM public.presidence_memoire;
  IF v_n <> 0 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE3 le refus a quand meme ecrit une ligne';
  END IF;

  -- ===========================================================================================
  -- B. LE PREMIER MANDAT S'OUVRE
  -- ===========================================================================================
  INSERT INTO public.postes_attribues (id, country, poste_id, city, titulaire, depuis, source)
  VALUES ('republic_president_national', 'republic', 'president', NULL, LEE, T1, 'banc')
  ON CONFLICT (id) DO UPDATE SET titulaire = EXCLUDED.titulaire, depuis = EXCLUDED.depuis;

  n := n + 1;   -- E4 : le mandat est resolu, et c'est bien une joueuse
  SELECT count(*) INTO v_n FROM public.presidence_mandat_courant('republic')
   WHERE president = LEE AND depuis = T1;
  IF v_n <> 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE4 le mandat courant n est pas resolu';
  END IF;

  -- UN CONTEXTE PUBLIC : la guerre subie. Pose a la main ici, exactement comme guerre_declarer
  -- le ferait pour le pays attaque.
  n := n + 1;   -- E5
  v := public.presidence_memoire_noter('republic', 'contexte', 'guerre_subie',
         'la guerre declaree par narco', '{"attaquant":"narco"}'::jsonb, NULL);
  IF coalesce((v->>'enregistre')::boolean, false) IS NOT TRUE
     OR v->>'president' <> LEE THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE5 le contexte n est pas enregistre : ' || v::text;
  END IF;

  n := n + 1;   -- E6 : UN CONTEXTE N'A PAS BESOIN D'ACTEUR. C'est le monde qui agit, pas un joueur.
  SELECT count(*) INTO v_n FROM public.presidence_memoire
   WHERE genre = 'contexte' AND source = 'guerre_subie' AND president = LEE AND mandat_depuis = T1;
  IF v_n <> 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE6 le contexte n est pas rattache au mandat';
  END IF;

  -- ===========================================================================================
  -- C. CE QUI N'ENTRE PAS
  -- ===========================================================================================
  n := n + 1;   -- E7 : une source non declaree est refusee (fail-closed sur la provenance)
  v := public.presidence_memoire_noter('republic', 'contexte', 'ragot_de_couloir',
                                       'une rumeur', '{}'::jsonb, NULL);
  IF coalesce((v->>'enregistre')::boolean, true) IS NOT FALSE
     OR v->>'raison' <> 'source_non_declaree' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE7 une source inventee est entree : ' || v::text;
  END IF;

  n := n + 1;   -- E8 : un genre qui CONTREDIT sa source est refuse. Une guerre subie n'est pas
                --      une reaction du President, et on ne peut pas la faire passer pour telle.
  v := public.presidence_memoire_noter('republic', 'reaction', 'guerre_subie',
                                       'faux', '{}'::jsonb, LEE);
  IF coalesce((v->>'enregistre')::boolean, true) IS NOT FALSE
     OR v->>'raison' <> 'genre_contredit_la_source' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE8 un genre contredisant sa source est passe : ' || v::text;
  END IF;

  n := n + 1;   -- E9 : une REACTION dont l'auteur n'est pas le President est refusee
  v := public.presidence_memoire_noter('republic', 'reaction', 'ordre_presidentiel',
                                       'une conference de presse', '{}'::jsonb, ARNIE);
  IF coalesce((v->>'enregistre')::boolean, true) IS NOT FALSE
     OR v->>'raison' <> 'acteur_n_est_pas_le_president' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE9 un ministre a ecrit dans la memoire presidentielle : ' || v::text;
  END IF;

  -- ===========================================================================================
  -- D. L'ABSENCE DE REACTION, RENDUE COMME UNE OBSERVATION
  -- ===========================================================================================
  n := n + 1;   -- E10 : le contexte existe, aucune reaction ne l'a suivi -> `suivi_de` est nul
  v := public.presidence_memoire_contexte('republic', 12);
  m := (v->'mandats')->0;
  f := (m->'faits')->0;
  IF coalesce((v->>'vide')::boolean, true) IS NOT FALSE
     OR f->>'genre' <> 'contexte' OR (f->'suivi_de') <> 'null'::jsonb THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE10 l absence de reaction n est pas rendue : ' || coalesce(f::text,'(rien)');
  END IF;

  n := n + 1;   -- E11 : et la lecture NE PORTE AUCUN JUGEMENT. Aucune clef de verdict nulle part.
  IF v::text LIKE '%score%' OR v::text LIKE '%reussite%' OR v::text LIKE '%echec%'
     OR v::text LIKE '%bilan%' OR v::text LIKE '%jugement%' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE11 la lecture rend un jugement';
  END IF;

  -- ===========================================================================================
  -- E. payer_ordre TEMOIGNE DES ACTES, SANS HANDLER TOUCHE
  -- ===========================================================================================
  -- La Presidente a de quoi payer. 2 PA pour une grace.
  UPDATE public.personnages_donnees SET pa = 12, liquide = 5000 WHERE name = LEE;
  SELECT count(*) INTO v_av FROM public.presidence_memoire WHERE genre = 'reaction';

  PERFORM pg_temp.je_suis(LEE_UUID);
  v := public.payer_ordre(LEE, 'gracier', 2, 0);
  PERFORM pg_temp.je_suis_le_serveur();

  n := n + 1;   -- E12 : l'ordre est bien paye
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE12 la grace n a pas ete payee : ' || v::text;
  END IF;

  n := n + 1;   -- E13 : et la memoire l'a vu, sans qu'on ait touche au handler de la grace
  SELECT count(*) INTO v_n FROM public.presidence_memoire
   WHERE genre = 'reaction' AND source = 'ordre_presidentiel' AND sujet = 'une grace examinee'
     AND president = LEE AND mandat_depuis = T1;
  IF v_n <> 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE13 payer_ordre n a pas temoigne de la grace';
  END IF;

  n := n + 1;   -- E14 : le contexte est MAINTENANT suivi d'une reaction -- et c'est la bonne
  v := public.presidence_memoire_contexte('republic', 12);
  f := ((v->'mandats')->0->'faits')->0;
  IF f->>'suivi_de' <> 'une grace examinee' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE14 la reaction ne se rattache pas au contexte : ' || coalesce(f::text,'(rien)');
  END IF;

  -- CONTRE-EPREUVE DECISIVE : le MEME ordre, paye par un MINISTRE. Il ne doit rien laisser dans
  -- la memoire presidentielle, alors que `conference_presse` existe a l'identique dans les deux
  -- salles de presse. Si cette epreuve passait, la memoire confondrait les institutions.
  UPDATE public.personnages_donnees SET pa = 12, liquide = 5000 WHERE name = ARNIE;
  SELECT count(*) INTO v_av FROM public.presidence_memoire;
  PERFORM pg_temp.je_suis(ARNIE_UUID);
  v := public.payer_ordre(ARNIE, 'conference_presse', 2, 0);
  PERFORM pg_temp.je_suis_le_serveur();

  n := n + 1;   -- E15 : le ministre a bien paye sa conference
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE15 la conference du ministre a echoue : ' || v::text;
  END IF;
  n := n + 1;   -- E16 : et la memoire presidentielle n'a PAS bouge
  SELECT count(*) INTO v_n FROM public.presidence_memoire;
  IF v_n <> v_av THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE16 la conference d un ministre est entree dans la memoire presidentielle';
  END IF;

  -- ===========================================================================================
  -- F. LA SEPARATION DES MANDATS
  -- ===========================================================================================
  -- Le mandat change -- MEME joueuse, nouvelle echeance. C'est le cas le plus dur : si la
  -- separation se faisait sur le nom, les deux presidences se confondraient.
  UPDATE public.postes_attribues SET depuis = T2
   WHERE country = 'republic' AND poste_id = 'president';

  -- LA SOURCE A CHANGE LE 11 OCTOBRE 2026, ET CE N'EST PAS UN DETAIL DE BANC. `election_
  -- presidentielle` a ete RETIREE des sources declarees : elle n'etait alimentee que par le
  -- declencheur de chronique, lui-meme retire parce que la chronique nationale est ecrite depuis
  -- le navigateur. Garder ce libelle ici aurait fait rougir l'epreuve pour une bonne raison --
  -- la source n'existe plus -- et masque ce qu'elle teste vraiment : LA SEPARATION DES MANDATS.
  -- On la rejoue donc sur une source toujours attestee, et l'epreuve garde son objet.
  v := public.presidence_memoire_noter('republic', 'contexte', 'guerre_subie',
         'une seconde guerre, sous le second mandat', '{"attaquant":"kolkhoze"}'::jsonb, NULL);
  n := n + 1;   -- E17 : le fait neuf porte le NOUVEAU mandat
  IF coalesce((v->>'enregistre')::boolean, false) IS NOT TRUE
     OR (v->>'mandat_depuis')::timestamptz <> T2 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE17 le fait neuf ne porte pas le second mandat : ' || v::text;
  END IF;

  n := n + 1;   -- E18 : les faits du PREMIER mandat ont garde leur echeance -- rien n'a migre
  SELECT count(*) INTO v_n FROM public.presidence_memoire WHERE mandat_depuis = T1;
  IF v_n <> 2 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE18 ' || v_n::text || ' faits au premier mandat au lieu de 2';
  END IF;

  n := n + 1;   -- E19 : la lecture rend DEUX mandats distincts, le plus recent en tete
  v := public.presidence_memoire_contexte('republic', 12);
  IF jsonb_array_length(v->'mandats') <> 2
     OR ((v->'mandats')->0->>'depuis')::timestamptz <> T2
     OR coalesce(((v->'mandats')->0->>'en_cours')::boolean, false) IS NOT TRUE
     OR coalesce(((v->'mandats')->1->>'en_cours')::boolean, true) IS NOT FALSE THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE19 les deux mandats ne sont pas separes : ' || v::text;
  END IF;

  -- ===========================================================================================
  -- G. L'AUTORITE : LE NAVIGATEUR N'ECRIT PAS LA MEMOIRE
  -- ===========================================================================================
  n := n + 1;   -- E20 : la porte d'ecriture est refusee a un joueur authentifie
  PERFORM pg_temp.je_suis(LEE_UUID);
  BEGIN
    v := public.presidence_memoire_noter('republic', 'reaction', 'ordre_presidentiel',
                                         'un acte forge', '{}'::jsonb, LEE);
    ko := ko + 1; v_echecs := v_echecs || E'\nE20 un joueur a pu ecrire dans la memoire';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  n := n + 1;   -- E21 : mais il peut la LIRE -- c'est ce dont Huguette a besoin.
                -- PAR LA PORTE SANS PAYS, ET C'EST UNE CORRECTION DE BANC DU 11 OCTOBRE 2026.
                -- `presidence_memoire_contexte(text,int)` prend le pays en parametre : la laisser
                -- ouverte au navigateur aurait permis de lire la memoire presidentielle d'un AUTRE
                -- empire. Elle a donc ete REVOQUEE le jour ou `presidence_memoire_mon_pays()` est
                -- apparue, qui relit le pays de l'acteur en base. Le banc interrogeait encore
                -- l'ancienne : il levait un refus de privilege, et personne ne l'avait rejoue.
  v := public.presidence_memoire_mon_pays();
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE21 un joueur ne peut pas lire la memoire de son pays : ' || v::text;
  END IF;
  n := n + 1;   -- E22 : ET LA PORTE AVEC PAYS EXPLICITE LUI EST FERMEE. Sans cette contre-epreuve,
                -- E21 passerait aussi si les deux portes etaient ouvertes.
  BEGIN
    v := public.presidence_memoire_contexte('narco', 12);
    ko := ko + 1; v_echecs := v_echecs || E'\nE22 un joueur a lu la memoire d un pays choisi par lui';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  PERFORM pg_temp.je_suis_le_serveur();

  IF ko = 0 THEN
    RAISE EXCEPTION 'banc memoire : LES % EPREUVES SONT VERTES. -- rien ne doit rester', n;
  ELSE
    RAISE EXCEPTION 'banc memoire : % EPREUVES ROUGES sur %. %', ko, n, v_echecs;
  END IF;
END $banc$;

ROLLBACK;
