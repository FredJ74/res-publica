-- BANC DE LA PORTE DES REGARDS DE RENEE (11 octobre 2026)
--
-- CE BANC NE COMMITE RIEN. Il pose des passages de decor dans `historique_deplacements`, clot un
-- scrutin fictif, et se termine par un RAISE EXCEPTION INCONDITIONNEL.
--
-- CE QU'IL PROUVE :
--   . la porte est en LECTURE SEULE -- STABLE, aucune ecriture, aucune table neuve ;
--   . elle ne rend que des FAITS : passages, co-presences, sieges, scrutins clos ;
--   . elle DIT CE QU'ELLE NE SAIT PAS -- `rien_a_signaler` et `aucun_scrutin` -- et c'est ce qui
--     empeche d'inventer une anecdote pour remplir un silence ;
--   . elle est bornee au PAYS DE L'ACTEUR, relu en base, et au seul batiment de l'Assemblee ;
--   . elle ne rend AUCUNE conclusion : ni negociation, ni corruption, ni complot ;
--   . `raison_institutionnelle` est un FAIT derive du poste reel, pas un soupcon ;
--   . anon ne peut pas l'appeler, et le journal des passages reste ferme au navigateur.
--
-- Usage : coller ce fichier dans un execute_sql. Il doit finir sur
--   ERROR: banc regards : LES 26 EPREUVES SONT VERTES. -- rien ne doit rester

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
  BEN_U   text := 'bafc96b1-1628-4ae2-93d2-78d89f8ac5b5'; BEN   text := 'Ben';
  LEE     text := 'Lee Capene';
  v jsonb; n integer := 0; ko integer := 0; v_echecs text := '';
  v_n integer; v_jour integer; v_txt text; v_cles text[];
BEGIN
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT coalesce(day, 1) INTO v_jour FROM public.personnages_donnees WHERE name = ARNIE;

  -- ===========================================================================================
  -- A. LA PORTE EST UNE LECTURE, ET SEULEMENT UNE LECTURE
  -- ===========================================================================================
  n := n + 1;
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace nn ON nn.oid = p.pronamespace
   WHERE nn.nspname = 'public' AND p.proname = 'assemblee_regards' AND p.provolatile = 's';
  IF v_n <> 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE1 la porte n est pas STABLE -- elle pourrait ecrire';
  END IF;

  n := n + 1;   -- ANON NE PEUT RIEN. Meme garde que partout ailleurs.
  BEGIN
    PERFORM set_config('role', 'anon', true);
    v := public.assemblee_regards(7);
    ko := ko + 1; v_echecs := v_echecs || E'\nE2 anon a pu interroger les regards';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.je_suis_le_serveur();

  n := n + 1;   -- LE JOURNAL DES PASSAGES EST FERME AU NAVIGATEUR : ni lecture, ni ecriture.
  SELECT count(*) INTO v_n FROM information_schema.role_table_grants
   WHERE table_schema = 'public' AND table_name = 'historique_deplacements'
     AND grantee IN ('anon', 'authenticated');
  IF v_n <> 0 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE3 ' || v_n || ' droit(s) client sur le journal des passages';
  END IF;

  n := n + 1;   -- CONTRE-EPREUVE : un joueur ne lit pas la table en direct, il passe par la porte.
  PERFORM pg_temp.je_suis(ARNIE_U);
  BEGIN
    SELECT count(*) INTO v_n FROM public.historique_deplacements;
    ko := ko + 1; v_echecs := v_echecs || E'\nE4 un joueur a lu le journal des passages en direct';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.je_suis_le_serveur();

  -- ===========================================================================================
  -- B. RIEN A SIGNALER EST UNE REPONSE, ET C'EST LA PLUS IMPORTANTE
  -- ===========================================================================================
  -- On vide la fenetre : aucun passage recent, aucun scrutin. La porte doit le DIRE.
  DELETE FROM public.historique_deplacements WHERE building_id = 'assemblee';
  DELETE FROM public.assemblee_scrutins;

  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.assemblee_regards(7);
  PERFORM pg_temp.je_suis_le_serveur();
  n := n + 1;
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE
     OR coalesce((v->>'rien_a_signaler')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE5 un batiment vide ne rend pas rien_a_signaler : ' || left(v::text, 300);
  END IF;
  n := n + 1;
  IF jsonb_array_length(v->'passages') <> 0 OR jsonb_array_length(v->'ensemble') <> 0 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE6 des passages ou des rencontres sont apparus de nulle part';
  END IF;
  n := n + 1;   -- ET L'ABSENCE DE SCRUTIN EST NOMMEE : c'est ce qui interdit de conclure a une assiduite.
  IF coalesce((v->>'aucun_scrutin')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE7 aucun_scrutin n est pas leve alors qu aucun scrutin n existe';
  END IF;
  n := n + 1;   -- LES NEUF SIEGES RESTENT VISIBLES : ils ne dependent d aucun passage.
  IF jsonb_array_length(v->'deputes') <> 9 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE8 ' || jsonb_array_length(v->'deputes') || ' sieges au lieu de 9';
  END IF;

  -- ===========================================================================================
  -- C. DES FAITS REELS, ET RIEN QUE DES FAITS
  -- ===========================================================================================
  -- DECOR : Arnie passe trois fois, dont deux pieces ; Ben passe une fois ; et les deux se
  -- trouvent la en meme temps une fois. Tout est pose A LA MAIN ici, comme le ferait
  -- `deplacement_enregistrer` -- la porte de Renee ne sait pas qui a ecrit, elle lit.
  INSERT INTO public.historique_deplacements (name, country, city, building_id, room_id, jour, heure)
  VALUES (ARNIE, 'republic', 'capitale', 'assemblee', 'accueil_assemblee', v_jour, '10h'),
         (ARNIE, 'republic', 'capitale', 'assemblee', 'hemicycle',         v_jour, '10h'),
         (ARNIE, 'republic', 'capitale', 'assemblee', 'couloirs',          v_jour - 1, '21h'),
         (BEN,   'republic', 'capitale', 'assemblee', 'accueil_assemblee', v_jour, '10h');

  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.assemblee_regards(7);
  PERFORM pg_temp.je_suis_le_serveur();

  n := n + 1;
  IF coalesce((v->>'rien_a_signaler')::boolean, true) IS NOT FALSE THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE9 rien_a_signaler est encore leve alors qu il y a des passages';
  END IF;
  n := n + 1;
  IF jsonb_array_length(v->'passages') <> 2 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE10 ' || jsonb_array_length(v->'passages') || ' visiteur(s) au lieu de 2';
  END IF;
  n := n + 1;   -- LE COMPTE ET LES PIECES SONT JUSTES, et le plus assidu vient en tete.
  IF (v->'passages'->0->>'qui') <> ARNIE
     OR (v->'passages'->0->>'passages')::integer <> 3 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE11 le compte des passages est faux : ' || (v->'passages'->0)::text;
  END IF;
  n := n + 1;
  IF NOT ((v->'passages'->0->'pieces')::text LIKE '%hemicycle%'
      AND (v->'passages'->0->'pieces')::text LIKE '%couloirs%') THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE12 les pieces vues ne sont pas rendues : ' || (v->'passages'->0->'pieces')::text;
  END IF;

  -- LA RAISON INSTITUTIONNELLE EST UN FAIT, PAS UN SOUPCON. Arnie est ministre de la Defense :
  -- il peut deposer un projet, donc il a une raison. Ben n'a aucun poste : il n'en a pas.
  n := n + 1;
  SELECT count(*) INTO v_n FROM jsonb_array_elements(v->'passages') e
   WHERE e->>'qui' = ARNIE AND (e->>'raison_institutionnelle')::boolean IS TRUE
     AND e->>'poste_actuel' = 'min_def';
  IF v_n <> 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE13 le ministre n a pas de raison institutionnelle : ' || (v->'passages')::text;
  END IF;
  n := n + 1;
  SELECT count(*) INTO v_n FROM jsonb_array_elements(v->'passages') e
   WHERE e->>'qui' = BEN AND (e->>'raison_institutionnelle')::boolean IS FALSE;
  IF v_n <> 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE14 un citoyen sans poste est declare avoir une raison officielle';
  END IF;

  -- LA CO-PRESENCE EST OBSERVEE, UNE SEULE FOIS, ET SANS INTERPRETATION.
  n := n + 1;
  IF jsonb_array_length(v->'ensemble') <> 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE15 ' || jsonb_array_length(v->'ensemble') || ' co-presence(s) au lieu de 1';
  END IF;
  n := n + 1;   -- LE COUPLE N'EST PAS COMPTE DEUX FOIS (A avec B, puis B avec A).
  IF (v->'ensemble'->0->>'qui_a') <> ARNIE OR (v->'ensemble'->0->>'qui_b') <> BEN
     OR (v->'ensemble'->0->>'fois')::integer <> 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE16 la co-presence est mal rendue : ' || (v->'ensemble'->0)::text;
  END IF;

  -- ===========================================================================================
  -- D. AUCUNE CONCLUSION, AUCUN CHAMP DE JUGEMENT
  -- ===========================================================================================
  n := n + 1;
  v_txt := v::text;
  IF v_txt ~* '(negoci|corrupt|complot|soupcon|suspect|achat_de_vote|intention)' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE17 la porte rend une conclusion : ' || left(v_txt, 300);
  END IF;
  n := n + 1;   -- ET AUCUN SCORE NI NOTE D ASSIDUITE.
  IF v_txt ~* '(score|note_|assiduite|classement|credibilite)' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE18 la porte rend un score ou une note';
  END IF;
  n := n + 1;   -- LES CHAMPS RENDUS SONT EXACTEMENT CEUX QUI SONT ATTESTES.
  SELECT array_agg(k ORDER BY k) INTO v_cles FROM jsonb_object_keys(v) AS k;
  IF v_cles <> ARRAY['aucun_scrutin','deputes','ensemble','fenetre_jours','jour','ok','passages',
                     'pays','rien_a_signaler','scrutins']::text[] THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE19 les champs rendus ne sont pas ceux attendus : '
      || coalesce(array_to_string(v_cles, ','), 'NULL');
  END IF;

  -- ===========================================================================================
  -- E. LA FENETRE, LE PAYS, ET LE BATIMENT
  -- ===========================================================================================
  n := n + 1;   -- UNE FENETRE D UN JOUR NE VOIT PAS LE PASSAGE DE LA VEILLE.
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.assemblee_regards(0);
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v->>'fenetre_jours')::integer <> 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE20 la fenetre n est pas bornee a 1 au minimum : ' || (v->>'fenetre_jours');
  END IF;

  -- UN PASSAGE DANS UN AUTRE BATIMENT N'EST PAS VU : Renee nettoie l'Assemblee, pas la ville.
  INSERT INTO public.historique_deplacements (name, country, city, building_id, room_id, jour, heure)
  VALUES (LEE, 'republic', 'capitale', 'palais-presidentiel', 'accueil_elysee', v_jour, '10h');
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.assemblee_regards(7);
  PERFORM pg_temp.je_suis_le_serveur();
  n := n + 1;
  IF v::text LIKE '%' || LEE || '%' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE21 un passage dans un AUTRE batiment est rendu';
  END IF;

  -- UN PASSAGE DANS L'ASSEMBLEE D'UN AUTRE EMPIRE N'EST PAS VU NON PLUS.
  INSERT INTO public.historique_deplacements (name, country, city, building_id, room_id, jour, heure)
  VALUES (LEE, 'narco', 'capitale', 'assemblee', 'accueil_assemblee', v_jour, '10h');
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.assemblee_regards(7);
  PERFORM pg_temp.je_suis_le_serveur();
  n := n + 1;
  IF v::text LIKE '%' || LEE || '%' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE22 un passage dans l Assemblee d un autre empire est rendu';
  END IF;
  n := n + 1;
  IF v->>'pays' <> 'republic' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE23 le pays rendu n est pas celui de l acteur : ' || coalesce(v->>'pays','NULL');
  END IF;

  -- ===========================================================================================
  -- F. UN SCRUTIN CLOS, ET L'ASSIDUITE DEVIENT ETABLISSABLE
  -- ===========================================================================================
  -- LE SCRUTIN A UNE PROPOSITION : la cle etrangere l'exige, et c'est bien ainsi -- un
  -- depouillement sans texte n'aurait aucun sens. On pose donc les deux, en respectant les CHECK
  -- reels du type et du statut.
  INSERT INTO public.assemblee_propositions
    (id, country, auteur, titre, type, statut, session_num, texte_original, amendements,
     eligible_session_ts, data)
  VALUES ('banc-prop-1', 'republic', ARNIE, 'Interdiction du metal', 'rp', 'adoptee', 1,
          'Texte de decor.', '[]'::jsonb, now() - interval '8 days', '{}'::jsonb),
         ('banc-prop-2', 'narco', 'Quelqu un', 'Loi etrangere', 'rp', 'adoptee', 1,
          'Texte de decor.', '[]'::jsonb, now() - interval '8 days', '{}'::jsonb);

  INSERT INTO public.assemblee_scrutins
    (id, proposition_id, session_num, country, titre, resultat, score_pour, score_contre,
     pour, contre, abstention, non_votants, endormis, cloture_ts)
  VALUES ('banc-scrutin-1', 'banc-prop-1', 1, 'republic', 'Interdiction du metal', 'ADOPTEE',
          2, 1, '["Yann Legall","Maelle Leroux"]'::jsonb, '["Gerard Pichon"]'::jsonb, '[]'::jsonb,
          '["Sophie Marechal"]'::jsonb, '[]'::jsonb, now() - interval '1 day');

  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.assemblee_regards(7);
  PERFORM pg_temp.je_suis_le_serveur();
  n := n + 1;
  IF coalesce((v->>'aucun_scrutin')::boolean, true) IS NOT FALSE THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE24 aucun_scrutin reste leve alors qu un scrutin est clos';
  END IF;
  n := n + 1;   -- LE DEPOUILLEMENT EST NOMINATIF, NON-VOTANTS COMPRIS : c'est cela, l'assiduite.
  IF NOT ((v->'scrutins'->0->'pour')::text LIKE '%Yann Legall%'
      AND (v->'scrutins'->0->'non_votants')::text LIKE '%Sophie Marechal%') THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE25 le depouillement nominatif n est pas rendu : ' || (v->'scrutins'->0)::text;
  END IF;
  n := n + 1;   -- ET UN SCRUTIN D UN AUTRE EMPIRE NE PASSE PAS.
  INSERT INTO public.assemblee_scrutins
    (id, proposition_id, session_num, country, titre, resultat, score_pour, score_contre,
     pour, contre, abstention, non_votants, endormis, cloture_ts)
  VALUES ('banc-scrutin-2', 'banc-prop-2', 1, 'narco', 'Loi etrangere', 'ADOPTEE',
          1, 0, '["Quelqu un"]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb,
          '[]'::jsonb, now());
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.assemblee_regards(7);
  PERFORM pg_temp.je_suis_le_serveur();
  IF v::text LIKE '%Loi etrangere%' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE26 un scrutin d un autre empire est rendu';
  END IF;

  -- ===========================================================================================
  IF ko > 0 THEN
    RAISE EXCEPTION 'banc regards : % ECHEC(S) SUR % EPREUVES.%', ko, n, v_echecs;
  END IF;
  RAISE EXCEPTION 'banc regards : LES % EPREUVES SONT VERTES. -- rien ne doit rester', n;
END $banc$;
ROLLBACK;
