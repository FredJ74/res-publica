-- BANC DES CINQ SECRETAIRES MINISTERIELS COMME REFERENTS DECLARES (11 octobre 2026)
--
-- CE BANC NE COMMITE RIEN : il appelle la porte pedagogique au nom d'un joueur reel, ecrit dans
-- pnj_referents_pedagogie, et se termine par un RAISE EXCEPTION INCONDITIONNEL.
--
-- CE QU'IL PROUVE, ET POURQUOI C'ETAIT NECESSAIRE. Les cinq ministres PNJ etaient referents de leur
-- ministere depuis la premiere passe -- corpus, role, titre de secretaire -- mais ILS N'ETAIENT PAS
-- INSCRITS dans `pnj_referents`, la liste fermee qui autorise la memoire pedagogique.
-- `referent_pedagogie_noter` rend `referent: false` et n'ecrit RIEN pour un identifiant absent : les
-- cinq recommencaient donc a zero a chaque conversation, la ou Martial, Tom Hawak et Huguette se
-- souviennent. Ce n'etait pas un arbitrage, c'etait un oubli.
--
--   . les cinq sont declares, sous leurs VRAIS identifiants ;
--   . la porte pedagogique les reconnait et COMPTE reellement les consultations ;
--   . un identifiant inconnu n'ecrit RIEN et le dit -- fail-closed ;
--   . les ANCIENNES cles generiques n'existent pas, donc ne repondent pas ;
--   . aucun DEHORS personnel n'est devenu un domaine de reference -- sinon Alain Bordage,
--     Laurent Barre et Lucas Tenaire seraient doubles sur leur propre rayon ;
--   . et le domaine de chacun est unique : deux referents sous un meme libelle en rendraient un
--     decoratif.
--
-- Usage : coller ce fichier dans un execute_sql. Il doit finir sur
--   ERROR: banc secretaires : LES 22 EPREUVES SONT VERTES. -- rien ne doit rester

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
  CINQ text[] := ARRAY['yvan_danltat','alain_theret','mathilde_garde',
                       'marie_eve_beaulieu','jean_jacques_carlin'];
  ANCIENS text[] := ARRAY['le_ministre_de_l_interieur','le_ministre_des_finances',
                          'le_ministre_de_la_justice','le_ministre_de_l_information',
                          'le_ministre_des_affaires_etrangeres'];
  v jsonb; n integer := 0; ko integer := 0; v_echecs text := '';
  v_n integer; v_id text; v_av integer;
BEGIN
  PERFORM pg_temp.je_suis_le_serveur();

  -- A. LE REGISTRE
  n := n + 1;
  SELECT count(*) INTO v_n FROM public.pnj_referents
   WHERE pays = 'republic' AND referent_id = ANY (CINQ);
  IF v_n <> 5 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE1 ' || v_n || ' des cinq secretaires sont declares au lieu de 5';
  END IF;

  n := n + 1;   -- CONTRE-EPREUVE : les anciennes cles generiques n'ont jamais ete creees.
  SELECT count(*) INTO v_n FROM public.pnj_referents WHERE referent_id = ANY (ANCIENS);
  IF v_n <> 0 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE2 ' || v_n || ' ancienne(s) cle(s) generique(s) au registre';
  END IF;

  n := n + 1;   -- Le modele de la mecanique est intact.
  SELECT count(*) INTO v_n FROM public.pnj_referents WHERE referent_id = 'martial_bouterin';
  IF v_n <> 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE3 le referent de la Defense a disparu';
  END IF;

  n := n + 1;   -- AUCUN DOMAINE PARTAGE : deux referents sous un meme libelle en rendraient un decoratif.
  SELECT count(*) INTO v_n FROM (
    SELECT domaine FROM public.pnj_referents WHERE pays = 'republic'
     GROUP BY domaine HAVING count(*) > 1) q;
  IF v_n <> 0 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE4 ' || v_n || ' domaine(s) de reference partage(s)';
  END IF;

  n := n + 1;   -- AUCUN DEHORS PERSONNEL DECLARE COMME DOMAINE. Le bateau, le locatif, le marche,
                -- le football et l'EHPAD colorent cinq personnages ; ils ne font d'eux les
                -- referents de rien.
  SELECT count(*) INTO v_n FROM public.pnj_referents
   WHERE referent_id = ANY (CINQ)
     AND (domaine ILIKE '%plaisance%' OR domaine ILIKE '%locatif%' OR domaine ILIKE '%football%'
       OR domaine ILIKE '%marche%' OR domaine ILIKE '%ehpad%' OR domaine ILIKE '%universite%'
       OR domaine ILIKE '%alimentation%' OR domaine ILIKE '%bateau%');
  IF v_n <> 0 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE5 ' || v_n || ' dehors personnel declare comme domaine de reference';
  END IF;

  n := n + 1;   -- ET LES RAYONS VOISINS RESTENT TENUS PAR LEURS PROPRIETAIRES.
  SELECT count(*) INTO v_n FROM public.pnj_referents
   WHERE referent_id IN ('alain_bordage','laurent_barre','lucas_tenaire','marc_hantile');
  IF v_n <> 4 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE6 un des quatre referents voisins a disparu du registre';
  END IF;

  -- B. LA MEMOIRE PEDAGOGIQUE FONCTIONNE REELLEMENT POUR LES CINQ
  -- On part d'une ardoise propre pour ce joueur, et on compte ce que la porte ecrit.
  DELETE FROM public.pnj_referents_pedagogie WHERE joueur = ARNIE AND referent_id = ANY (CINQ);

  FOREACH v_id IN ARRAY CINQ LOOP
    PERFORM pg_temp.je_suis(ARNIE_U);
    v := public.referent_pedagogie_noter(v_id);
    PERFORM pg_temp.je_suis_le_serveur();
    n := n + 1;
    IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE
       OR coalesce((v->>'referent')::boolean, false) IS NOT TRUE THEN
      ko := ko + 1; v_echecs := v_echecs || E'\nE7 ' || v_id || ' n est pas reconnu comme referent : ' || v::text;
    END IF;
    n := n + 1;
    SELECT consultations INTO v_n FROM public.pnj_referents_pedagogie
     WHERE referent_id = v_id AND joueur = ARNIE;
    IF coalesce(v_n, 0) <> 1 THEN
      ko := ko + 1; v_echecs := v_echecs || E'\nE8 ' || v_id || ' : ' || coalesce(v_n, -1) || ' consultation(s) au lieu de 1';
    END IF;
  END LOOP;

  n := n + 1;   -- UNE SECONDE VISITE S'AJOUTE : c'est bien un souvenir, pas un drapeau.
  PERFORM pg_temp.je_suis(ARNIE_U);
  PERFORM public.referent_pedagogie_noter('yvan_danltat');
  v := public.referent_pedagogie_contexte('yvan_danltat');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v->>'consultations')::integer, 0) <> 2 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE9 la seconde consultation ne s ajoute pas : ' || v::text;
  END IF;

  -- C. CONTRE-EPREUVES DE LA LISTE FERMEE
  SELECT count(*) INTO v_av FROM public.pnj_referents_pedagogie;
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.referent_pedagogie_noter('le_ministre_de_l_interieur');
  PERFORM pg_temp.je_suis_le_serveur();
  n := n + 1;
  IF coalesce((v->>'referent')::boolean, true) IS NOT FALSE THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE10 une ancienne cle generique est reconnue comme referent : ' || v::text;
  END IF;
  n := n + 1;
  SELECT count(*) INTO v_n FROM public.pnj_referents_pedagogie;
  IF v_n <> v_av THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE11 une cle inconnue a quand meme ecrit une ligne';
  END IF;

  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.referent_pedagogie_noter('ministre_imaginaire_des_sports');
  PERFORM pg_temp.je_suis_le_serveur();
  n := n + 1;
  IF coalesce((v->>'referent')::boolean, true) IS NOT FALSE THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE12 un referent invente est reconnu : ' || v::text;
  END IF;
  n := n + 1;
  SELECT count(*) INTO v_n FROM public.pnj_referents_pedagogie;
  IF v_n <> v_av THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE13 un referent invente a ecrit une ligne';
  END IF;

  n := n + 1;   -- ET LE REGISTRE COMPTE 27 REFERENTS : 22 plus les cinq.
  SELECT count(*) INTO v_n FROM public.pnj_referents;
  IF v_n <> 27 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE14 ' || v_n || ' referents au registre au lieu de 27';
  END IF;

  IF ko > 0 THEN
    RAISE EXCEPTION 'banc secretaires : % ECHEC(S) SUR % EPREUVES.%', ko, n, v_echecs;
  END IF;
  RAISE EXCEPTION 'banc secretaires : LES % EPREUVES SONT VERTES. -- rien ne doit rester', n;
END $banc$;
ROLLBACK;
