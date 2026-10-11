-- BANC DU PALAIS PRESIDENTIEL -- CONTEXTE PUBLIC ET ELIGIBILITE (11 octobre 2026)
--
-- CE BANC NE COMMITE RIEN. Il pose un decor dans des tables de JEU -- `personnages_donnees`,
-- `candidatures`, `cycles_electoraux` -- et se termine par un RAISE EXCEPTION INCONDITIONNEL,
-- que les epreuves soient vertes ou rouges. Un banc du 4 octobre 2026 a laisse une accusation
-- forgee au nom d'un joueur reel pendant six jours parce qu'il avait commite.
--
-- CE QU'IL PROUVE, et qu'une migration ne peut pas prouver (elle commite) :
--   . un PNJ apprend le NOM et la FONCTION OFFICIELLE de son interlocuteur, et RIEN d'autre --
--     la reponse a exactement trois clefs, et aucune ne porte d'argent, de domicile ni de passe ;
--   . un civil sans poste est nomme sans fonction : le canal ne fabrique pas de titre ;
--   . le cumul ministre + depute rend DEUX fonctions, parce que la fiche en porte deux ;
--   . l'usurpation echoue : qui s'ecrit ministre sur sa propre fiche n'obtient rien du canal,
--     parce que le poste doit etre ATTESTE ;
--   . `anon` ne peut pas appeler le canal du tout ;
--   . l'eligibilite presidentielle est refusee AU SERVEUR -- influence, domiciliation, cumul --
--     sur le chemin REELLEMENT emprunte par le depot de candidature ;
--   . et la contre-epreuve d'ecriture : un refus d'eligibilite n'ecrit RIEN, pas meme la moitie.
--
-- MESURES DE DEPART (11 octobre 2026) : 8 personnages a Republia, Arnie Ministre de la Defense,
-- Vince Kubrick Lieutenant, les six autres sans poste ; cycle `republic_president` en phase de
-- mandat ; la presidence exige 10 INF.
--
-- Usage : coller ce fichier dans un execute_sql. Il doit finir sur
--   ERROR: banc palais : LES 17 EPREUVES SONT VERTES. -- rien ne doit rester
-- Le verdict voyage DANS l'exception, parce que le canal technique ne rapporte ni NOTICE ni
-- WARNING. Toute autre fin est un echec, et le message nomme alors chaque epreuve rouge.

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
  ARNIE text := '9abef1c4-75ab-4352-b5ca-a219fc37a35c';  -- Ministre de la Defense (reel)
  LEE   text := 'ea4a2a0c-a192-4e10-8cff-d5db9b1cceb6';  -- civile, 25 INF (reelle)
  MAY   text := '3d91b1fa-a22d-41ae-82cf-fef98194b10a';  -- influence abaissee (decor)
  BEN   text := 'bafc96b1-1628-4ae2-93d2-78d89f8ac5b5';  -- domicilie ailleurs (decor)
  MARS  text := 'a5a55fc8-64fa-4406-b617-76439d1d4aac';  -- Maire (decor)
  PHIL  text := '0821bcdf-0c69-4ba3-adcd-f60d9b82b7bf';  -- cas malformes
  v jsonb; n integer := 0; ko integer := 0; v_echecs text := '';
  v_av integer; v_ap integer; v_poste jsonb; v_cands jsonb;
BEGIN
  -- ===========================================================================================
  -- A. LE CONTEXTE PUBLIC : NOM ET FONCTION, RIEN D'AUTRE
  -- ===========================================================================================
  PERFORM pg_temp.je_suis(ARNIE);
  v := public.pnj_contexte_public();

  n := n + 1;  -- E1 : le ministre est reconnu, et nomme
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE OR v->>'nom' <> 'Arnie' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE1 le ministre n est pas reconnu : ' || v::text;
  END IF;

  n := n + 1;  -- E2 : sa fonction officielle est rendue, a la lettre de sa fiche
  IF v->'fonctions' <> '["Ministre de la Defense"]'::jsonb THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE2 fonction rendue inattendue : ' || (v->'fonctions')::text;
  END IF;

  n := n + 1;  -- E3 : TROIS clefs, pas quatre. Rien ne fuit par accident.
  IF (SELECT count(*) FROM jsonb_object_keys(v)) <> 3
     OR NOT (v ? 'ok' AND v ? 'nom' AND v ? 'fonctions') THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE3 le contexte public a d autres clefs : '
      || (SELECT string_agg(k, ',') FROM jsonb_object_keys(v) k);
  END IF;

  PERFORM pg_temp.je_suis(LEE);
  v := public.pnj_contexte_public();

  n := n + 1;  -- E4 : une civile est nommee SANS fonction. Le canal ne fabrique pas de titre.
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE OR v->>'nom' <> 'Lee Capene'
     OR jsonb_array_length(v->'fonctions') <> 0 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE4 la civile recoit une fonction : ' || v::text;
  END IF;

  -- LE CUMUL MINISTRE + DEPUTE. La fiche porte deux colonnes : les deux doivent etre rendues.
  PERFORM pg_temp.je_suis_le_serveur();
  UPDATE public.personnages_donnees
     SET poste_depute = '{"id":"depute","name":"Depute de la Capitale"}'::jsonb
   WHERE name = 'Arnie';
  PERFORM pg_temp.je_suis(ARNIE);
  v := public.pnj_contexte_public();

  n := n + 1;  -- E5 : deux fonctions, dans l ordre poste puis mandat parlementaire
  IF v->'fonctions' <> '["Ministre de la Defense","Depute de la Capitale"]'::jsonb THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE5 le cumul n est pas rendu : ' || (v->'fonctions')::text;
  END IF;

  -- L USURPATION, PAR LE CHEMIN QU'UN NAVIGATEUR EMPRUNTE VRAIMENT. `authenticated` n'a aucun
  -- droit sur `personnages_donnees` : la fiche s'ecrit par la VUE `personnages`, que le client
  -- peut mettre a jour. Lee s'y ecrit Ministre des Finances ; le declencheur d'attestation remet
  -- silencieusement l'ancienne valeur, donc le canal public ne voit rien.
  -- LA VERIFICATION SE FAIT AU SERVEUR : relire la table sous l'identite de Lee echouerait sur
  -- un defaut de droit, et ferait passer l'epreuve pour la mauvaise raison.
  PERFORM pg_temp.je_suis(LEE);
  BEGIN
    UPDATE public.personnages
       SET poste = '{"id":"min_fin","name":"Ministre des Finances"}'::jsonb
     WHERE name = 'Lee Capene';
  EXCEPTION WHEN others THEN NULL;  -- un refus franc est une fermeture plus forte encore
  END;
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT poste INTO v_poste FROM public.personnages_donnees WHERE name = 'Lee Capene';
  PERFORM pg_temp.je_suis(LEE);
  v := public.pnj_contexte_public();

  n := n + 1;  -- E6 : la fiche n a pas pris le poste auto-declare
  IF v_poste IS NOT NULL AND coalesce(v_poste->>'id','') = 'min_fin' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE6 un poste auto-declare a ete accepte sur la fiche';
  END IF;

  n := n + 1;  -- E7 : et le PNJ ne lui donne donc aucun titre
  IF jsonb_array_length(v->'fonctions') <> 0 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE7 le canal rend un titre usurpe : ' || (v->'fonctions')::text;
  END IF;

  -- anon n a pas le droit d appeler le canal du tout.
  PERFORM pg_temp.je_suis_le_serveur();
  BEGIN
    PERFORM set_config('role', 'anon', true);
    v := public.pnj_contexte_public();
    n := n + 1; ko := ko + 1;
    v_echecs := v_echecs || E'\nE8 anon a pu appeler le contexte public : ' || v::text;
  EXCEPTION WHEN insufficient_privilege THEN
    n := n + 1;  -- E8 : refuse, et pour la bonne raison
  END;
  PERFORM pg_temp.je_suis_le_serveur();

  -- ===========================================================================================
  -- B. L ELIGIBILITE PRESIDENTIELLE, AU SERVEUR
  -- ===========================================================================================
  -- Le decor : May tombe a 2 INF, Ben est domicilie en Narcovie, Marsault est Maire.
  UPDATE public.personnages_donnees
     SET resources = jsonb_set(coalesce(resources,'{}'::jsonb), '{inf}', '2'::jsonb)
   WHERE name = 'May';
  UPDATE public.personnages_donnees
     SET domicile = jsonb_set(coalesce(domicile,'{}'::jsonb), '{country}', '"narco"'::jsonb)
   WHERE name = 'Ben';
  UPDATE public.personnages_donnees
     SET poste = '{"id":"maire","name":"Maire de la Capitale"}'::jsonb
   WHERE name = 'Marsault';

  -- LE SCRUTIN PRESIDENTIEL EST OUVERT POUR LE DECOR. Le declencheur `candidatures_cloture`
  -- refuse toute inscription a un scrutin en phase de mandat, deja depouille, ou dont la campagne
  -- a commence -- et le cycle reel de Republia est justement en mandat. C'est une REGLE DE JEU
  -- correcte, pas un obstacle a contourner : le banc ouvre donc la fenetre de candidature, et
  -- cette ouverture disparait avec le ROLLBACK.
  -- A NOTER : les trois controles d'eligibilite rendent leur refus AVANT l'insertion, donc les
  -- epreuves de refus (E13, E15, E16, E17) n'atteignent jamais ce declencheur. L'ordre compte.
  UPDATE public.cycles_electoraux
     SET data = jsonb_set(jsonb_set(jsonb_set(data::jsonb,
                  '{phase}', '"candidatures"'::jsonb),
                  '{resultatsTraites}', 'false'::jsonb),
                  '{dateDebutCampagne}',
                  to_jsonb(floor(extract(epoch FROM now()) * 1000) + 86400000))::text
   WHERE id = 'republic_president';

  -- LE DEPOT LEGITIME : Lee a 25 INF, elle est domiciliee a Republia, elle n a aucun poste.
  SELECT count(*) INTO v_av FROM public.candidatures;
  PERFORM pg_temp.je_suis(LEE);
  v := public.candidature_deposer('president', NULL, NULL,
        '{"nom":"Lee Capene","programme":"banc","archetype":"populiste"}'::jsonb);

  n := n + 1;  -- E9 : une candidate eligible passe
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE9 une candidature eligible est refusee : ' || v::text;
  END IF;

  n := n + 1;  -- E10 : la ligne attestee existe
  IF NOT EXISTS (SELECT 1 FROM public.candidatures
                  WHERE nom = 'Lee Capene' AND poste_id = 'president' AND country = 'republic') THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE10 la ligne attestee de candidature manque';
  END IF;

  n := n + 1;  -- E11 : et le bulletin est dans le cycle, dans la MEME transaction
  SELECT (data::jsonb)->'candidats' INTO v_cands FROM public.cycles_electoraux
   WHERE id = 'republic_president';
  IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_cands) e WHERE e->>'nom' = 'Lee Capene') THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE11 le bulletin n a pas rejoint le cycle';
  END IF;

  n := n + 1;  -- E12 : deuxieme depot refuse, et pas par erreur de clef
  v := public.candidature_deposer('president', NULL, NULL,
        '{"nom":"Lee Capene","programme":"banc","archetype":"populiste"}'::jsonb);
  IF coalesce((v->>'ok')::boolean, true) IS NOT FALSE OR v->>'raison' <> 'deja_candidat' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE12 un second depot est passe : ' || v::text;
  END IF;

  -- L INFLUENCE. C est le trou que l audit a trouve : 2 INF pour un poste qui en exige 10.
  SELECT count(*) INTO v_av FROM public.candidatures;
  PERFORM pg_temp.je_suis(MAY);
  v := public.candidature_deposer('president', NULL, NULL,
        '{"nom":"May","programme":"banc","archetype":"populiste"}'::jsonb);

  n := n + 1;  -- E13 : refus, avec le seuil exact rendu
  IF coalesce((v->>'ok')::boolean, true) IS NOT FALSE
     OR v->>'raison' <> 'influence_insuffisante'
     OR (v->>'requis')::numeric <> 10 OR (v->>'reel')::numeric <> 2 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE13 2 INF suffisent encore a la presidence : ' || v::text;
  END IF;

  n := n + 1;  -- E14 : CONTRE-EPREUVE D ECRITURE -- un refus n ecrit rien, pas meme la moitie
  SELECT count(*) INTO v_ap FROM public.candidatures;
  IF v_ap <> v_av THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE14 un refus a laisse une ligne : '
      || v_av::text || ' -> ' || v_ap::text;
  END IF;

  n := n + 1;  -- E15 : la domiciliation
  PERFORM pg_temp.je_suis(BEN);
  v := public.candidature_deposer('president', NULL, NULL,
        '{"nom":"Ben","programme":"banc","archetype":"populiste"}'::jsonb);
  IF coalesce((v->>'ok')::boolean, true) IS NOT FALSE OR v->>'raison' <> 'non_domicilie' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE15 un non-domicilie peut se presenter : ' || v::text;
  END IF;

  n := n + 1;  -- E16 : le cumul president/maire
  PERFORM pg_temp.je_suis(MARS);
  v := public.candidature_deposer('president', NULL, NULL,
        '{"nom":"Marsault","programme":"banc","archetype":"populiste"}'::jsonb);
  IF coalesce((v->>'ok')::boolean, true) IS NOT FALSE OR v->>'raison' <> 'cumul_interdit' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE16 un maire peut cumuler la presidence : ' || v::text;
  END IF;

  n := n + 1;  -- E17 : un poste qui n est pas un poste electif, et un nom qui n est pas le sien
  PERFORM pg_temp.je_suis(PHIL);
  v := public.candidature_deposer('empereur', NULL, NULL,
        '{"nom":"Phileas Frogg","programme":"banc","archetype":"populiste"}'::jsonb);
  IF coalesce((v->>'ok')::boolean, true) IS NOT FALSE OR v->>'raison' <> 'poste_inconnu' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE17a un poste inexistant est accepte : ' || v::text;
  END IF;
  v := public.candidature_deposer('president', NULL, NULL,
        '{"nom":"Lee Capene","programme":"banc","archetype":"populiste"}'::jsonb);
  IF coalesce((v->>'ok')::boolean, true) IS NOT FALSE OR v->>'raison' <> 'pas_mon_nom' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE17b on peut candidater au nom d un autre : ' || v::text;
  END IF;

  PERFORM pg_temp.je_suis_le_serveur();

  IF ko = 0 THEN
    RAISE EXCEPTION 'banc palais : LES % EPREUVES SONT VERTES. -- rien ne doit rester', n;
  ELSE
    RAISE EXCEPTION 'banc palais : % EPREUVES ROUGES sur %. %', ko, n, v_echecs;
  END IF;
END $banc$;

ROLLBACK;
