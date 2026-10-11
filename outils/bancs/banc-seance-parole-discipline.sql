-- BANC DE LA SEANCE : LA PAROLE ET LA DISCIPLINE (11 octobre 2026)
--
-- CE BANC NE COMMITE RIEN. Il forge une presidence, quatre deputes attestes et un figurant, joue
-- la seance, et se termine par un RAISE EXCEPTION INCONDITIONNEL.
--
-- IL FORGE LES ROLES PAR LA VOIE LEGALE, et c'est deliberement penible : un depute n'existe que si
-- `cycles_electoraux` le declare elu, parce que le trigger d'attestation annule silencieusement
-- tout poste non atteste. Un banc qui contournerait cette voie prouverait une seance imaginaire.
--
-- CE QU'IL PROUVE :
--   . qui peut demander, donner, retirer la parole -- et qui ne peut pas ;
--   . que la file est chronologique et que le President NE CHOISIT PAS son orateur ;
--   . qu'une demande refaite apres un retrait repart en FIN de file ;
--   . qu'on peut parler SANS la parole, que c'est enregistre comme tel, et que le serveur n'en
--     tire RIGOUREUSEMENT RIEN -- ni popularite, ni argent, ni discipline ;
--   . que le rappel coute 15 points, exige un motif, et conserve ce motif AU MOT ;
--   . qu'une sanction est impossible sans rappel, qu'elle en consomme un, et qu'un seul rappel
--     n'en permet jamais deux ;
--   . que les 100 FR partent du depute ET arrivent dans la caisse, ou ne partent pas du tout ;
--   . qu'une reponse perdue, rejouee, ne coute pas deux fois ;
--   . que la presse recoit des FAITS et le motif verbatim, et personne d'autre qu'elle.
--
-- Usage : coller ce fichier dans un execute_sql. Il doit finir sur
--   ERROR: banc seance : LES 35 EPREUVES SONT VERTES. -- rien ne doit rester

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
  MARS_U  text := 'a5a55fc8-64fa-4406-b617-76439d1d4aac'; MARS  text := 'Marsault';
  PHIL_U  text := '0821bcdf-0c69-4ba3-adcd-f60d9b82b7bf'; PHIL  text := 'Phileas Frogg';
  BEN_U   text := 'bafc96b1-1628-4ae2-93d2-78d89f8ac5b5'; BEN   text := 'Ben';
  BART_U  text := '0d119ada-f6e4-4c8c-bc8d-34e57de6115f'; BART  text := 'Bartesto Chevara';
  -- TEXTE_MOTIF, et pas MOTIF : plpgsql refuse une variable homonyme d'une colonne de la table
  -- interrogee (`assemblee_disciplines.motif`) et rend une erreur d'ambiguite, pas un resultat.
  TEXTE_MOTIF text := 'Vous avez interrompu l''orateur trois fois, et je ne vous aime pas.';
  CAISSE  text := 'republic_assemblee';
  v jsonb; n integer := 0; ko integer := 0; v_echecs text := '';
  v_n integer; v_pop numeric; v_pop2 numeric; v_liq integer; v_solde integer; v_solde2 integer;
  v_txt text; v_rappel text; v_cloture timestamptz;
BEGIN
  PERFORM pg_temp.je_suis_le_serveur();

  -- ===========================================================================================
  -- DECOR : UNE PRESIDENCE QUI SIEGE, QUATRE AUTRES DEPUTES, UN FIGURANT
  -- ===========================================================================================
  -- LA PRESIDENCE PASSE PAR LE REGISTRE DES POSTES NOMMES, parce que c'est la seule source de
  -- verite que `assemblee_president` connait. Rien d'autre ne la fabrique.
  INSERT INTO public.postes_attribues (id, country, poste_id, city, titulaire, source)
  VALUES ('banc-presidence-an', 'republic', 'president_assemblee', NULL, ARNIE, 'banc');

  -- LES DEPUTES PASSENT PAR LE DEPOUILLEMENT. Le trigger d'attestation annulerait en silence un
  -- poste_depute que `cycles_electoraux` ne confirme pas : on ecrit donc d'abord l'election.
  UPDATE public.cycles_electoraux
     SET data = '{"elus":["Lee Capene","Marsault","Phileas Frogg"]}'
   WHERE country = 'republic' AND poste_id = 'depute' AND city = 'capitale';
  UPDATE public.cycles_electoraux
     SET data = '{"elus":["Ben"]}'
   WHERE country = 'republic' AND poste_id = 'depute' AND city = 'ville_a';
  -- LE PRESIDENT EST L'UN DES NEUF, ET LE DECOR DOIT LE RESPECTER (correctif du 11 octobre 2026).
  -- Arnie recoit un siege a Montrouge : depuis que `assemblee_president` derive la presidence des
  -- neuf, un President sans mandat ne preside RIEN -- et c'est exactement l'invariant voulu. Ce
  -- banc forgeait auparavant un President hors de l'Assemblee, un etat que l'arbitrage interdit.
  UPDATE public.cycles_electoraux
     SET data = '{"elus":["Arnie"]}'
   WHERE country = 'republic' AND poste_id = 'depute' AND city = 'ville_b';
  UPDATE public.personnages_donnees
     SET poste_depute = jsonb_build_object('id', 'depute', 'city', 'ville_b')
   WHERE name = ARNIE;

  UPDATE public.personnages_donnees
     SET poste_depute = jsonb_build_object('id', 'depute', 'city', 'capitale')
   WHERE name IN (LEE, MARS, PHIL);
  UPDATE public.personnages_donnees
     SET poste_depute = jsonb_build_object('id', 'depute', 'city', 'ville_a')
   WHERE name = BEN;

  -- TOUT LE MONDE DANS L'HEMICYCLE, et dans la capitale : l'Assemblee n'est nulle part ailleurs.
  UPDATE public.personnages_donnees
     SET current_city = 'capitale', current_building = 'assemblee', current_room = 'hemicycle',
         resources = jsonb_set(coalesce(resources, '{}'::jsonb), '{pop}', '50'::jsonb)
   WHERE name IN (ARNIE, LEE, MARS, PHIL, BEN, BART);

  -- L'ATTESTATION A-T-ELLE PRIS ? Si le trigger avait annule les postes, tout le reste du banc
  -- serait vert pour la mauvaise raison -- des refus partout, interpretes comme des regles.
  n := n + 1;
  SELECT count(*) INTO v_n FROM public.personnages_donnees
   WHERE name IN (LEE, MARS, PHIL, BEN) AND poste_depute IS NOT NULL;
  IF v_n <> 4 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE1 decor invalide : seulement ' || v_n || ' depute(s) atteste(s) sur 4';
  END IF;
  n := n + 1;
  IF public.assemblee_president('republic') IS DISTINCT FROM ARNIE THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE2 decor invalide : la presidence n est pas lue au registre';
  END IF;

  -- ===========================================================================================
  -- A. QUI PEUT DEMANDER LA PAROLE
  -- ===========================================================================================
  n := n + 1;   -- UN FIGURANT N'EST PAS DEPUTE.
  PERFORM pg_temp.je_suis(BART_U);
  v := public.assemblee_parole_demander();
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'pas_depute' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE3 un non-depute a pu demander la parole : ' || v::text;
  END IF;

  n := n + 1;   -- UN DEPUTE AU HALL NE DEMANDE PAS LA PAROLE EN SEANCE.
  UPDATE public.personnages_donnees SET current_room = 'accueil_assemblee' WHERE name = BEN;
  PERFORM pg_temp.je_suis(BEN_U);
  v := public.assemblee_parole_demander();
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'pas_dans_hemicycle' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE4 un depute hors hemicycle a pu demander la parole : ' || v::text;
  END IF;
  UPDATE public.personnages_donnees SET current_room = 'hemicycle' WHERE name = BEN;

  n := n + 1;   -- LEE DEMANDE, ET IL EST PREMIER.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.assemblee_parole_demander();
  PERFORM pg_temp.je_suis_le_serveur();
  IF v->>'ok' <> 'true' OR (v->>'rang')::int <> 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE5 la premiere demande de parole a echoue : ' || v::text;
  END IF;

  n := n + 1;   -- DOUBLE CLIC : AUCUN DOUBLON, ET LA PLACE EST CONSERVEE.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.assemblee_parole_demander();
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT count(*) INTO v_n FROM public.assemblee_paroles WHERE pays = 'republic' AND depute = LEE;
  IF v->>'deja_demande' <> 'true' OR v_n <> 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE6 un double clic a duplique la demande (' || v_n || ' lignes) : ' || v::text;
  END IF;

  -- MARSAULT PUIS PHILEAS : la file se remplit dans l'ordre reel.
  PERFORM pg_temp.je_suis(MARS_U); PERFORM public.assemblee_parole_demander();
  PERFORM pg_temp.je_suis(PHIL_U); PERFORM public.assemblee_parole_demander();
  PERFORM pg_temp.je_suis_le_serveur();

  n := n + 1;   -- L'ORDRE DE LA FILE EST CHRONOLOGIQUE.
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.assemblee_seance(50);
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v->'file'->0->>'depute') <> LEE OR (v->'file'->1->>'depute') <> MARS
     OR (v->'file'->2->>'depute') <> PHIL THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE7 la file n est pas chronologique : ' || (v->'file')::text;
  END IF;

  -- ===========================================================================================
  -- B. LE PRESIDENT NE CHOISIT PAS SON ORATEUR
  -- ===========================================================================================
  n := n + 1;   -- UN DEPUTE NE DISTRIBUE PAS LA PAROLE.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.assemblee_parole_donner(LEE);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'pas_le_president' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE8 un depute a pu donner la parole : ' || v::text;
  END IF;

  n := n + 1;   -- LE PRESIDENT NE PEUT PAS SAUTER LE PREMIER. C'est tout l'arbitrage.
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.assemblee_parole_donner(PHIL);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'pas_le_premier_de_la_file' OR (v->>'premier') <> LEE THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE9 le President a pu choisir son orateur : ' || v::text;
  END IF;

  n := n + 1;   -- IL PEUT LA DONNER AU PREMIER.
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.assemblee_parole_donner(LEE);
  PERFORM pg_temp.je_suis_le_serveur();
  IF v->>'ok' <> 'true' OR (v->>'orateur') <> LEE THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE10 la parole n a pas ete donnee au premier : ' || v::text;
  END IF;

  n := n + 1;   -- UN SEUL ORATEUR A LA FOIS.
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.assemblee_parole_donner(MARS);
  PERFORM pg_temp.je_suis_le_serveur();
  IF v->>'ok' <> 'false' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE11 deux orateurs ont pu avoir la parole : ' || v::text;
  END IF;

  -- ===========================================================================================
  -- C. PARLER, AVEC OU SANS LA PAROLE
  -- ===========================================================================================
  n := n + 1;   -- L'ORATEUR PARLE : AUTORISE.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.assemblee_debat_dire('Monsieur le President, je demande la parole sur le fond.', 'rq-banc-lee-001');
  PERFORM pg_temp.je_suis_le_serveur();
  IF v->>'ok' <> 'true' OR v->>'autorise' <> 'true' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE12 l orateur n a pas ete enregistre comme autorise : ' || v::text;
  END IF;

  n := n + 1;   -- UN AUTRE PARLE SANS LA PAROLE : C'EST ENREGISTRE, ET IDENTIFIABLE.
  SELECT (resources->>'pop')::numeric INTO v_pop FROM public.personnages_donnees WHERE name = MARS;
  PERFORM pg_temp.je_suis(MARS_U);
  v := public.assemblee_debat_dire('C est faux, et vous le savez !', 'rq-banc-mars-001');
  PERFORM pg_temp.je_suis_le_serveur();
  IF v->>'ok' <> 'true' OR v->>'autorise' <> 'false' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE13 l intervention sans parole n a pas ete enregistree comme telle : ' || v::text;
  END IF;

  n := n + 1;   -- ET LE SERVEUR N'EN TIRE RIGOUREUSEMENT RIEN. Ni popularite, ni discipline.
  SELECT (resources->>'pop')::numeric INTO v_pop2 FROM public.personnages_donnees WHERE name = MARS;
  SELECT count(*) INTO v_n FROM public.assemblee_disciplines WHERE pays = 'republic';
  IF v_pop2 <> v_pop OR v_n <> 0 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE14 parler sans la parole a eu une consequence automatique : pop '
      || v_pop || ' -> ' || v_pop2 || ', ' || v_n || ' discipline(s)';
  END IF;

  n := n + 1;   -- LE PRESIDENT PARLE DE DROIT.
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.assemblee_debat_dire('Monsieur Marsault, vous n avez pas la parole.', 'rq-banc-arnie-001');
  PERFORM pg_temp.je_suis_le_serveur();
  IF v->>'ok' <> 'true' OR v->>'autorise' <> 'true' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE15 le President n a pas parle de droit : ' || v::text;
  END IF;

  n := n + 1;   -- UNE REPONSE PERDUE, REJOUEE, NE PARLE PAS DEUX FOIS.
  PERFORM pg_temp.je_suis(MARS_U);
  v := public.assemblee_debat_dire('C est faux, et vous le savez !', 'rq-banc-mars-001');
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT count(*) INTO v_n FROM public.assemblee_debats WHERE requete = 'rq-banc-mars-001';
  IF v->>'rejeu' <> 'true' OR v_n <> 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE16 un rejeu a duplique l intervention (' || v_n || ') : ' || v::text;
  END IF;

  n := n + 1;   -- UNE REQUETE MAL FORMEE EST REFUSEE : la clef n est pas decorative.
  PERFORM pg_temp.je_suis(MARS_U);
  v := public.assemblee_debat_dire('Ceci ne doit pas passer.', 'pas-une-requete');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'requete_invalide' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE17 une requete mal formee est passee : ' || v::text;
  END IF;

  -- ===========================================================================================
  -- D. RETIRER LA PAROLE, ET REPARTIR EN FIN DE FILE
  -- ===========================================================================================
  n := n + 1;
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.assemblee_parole_retirer();
  PERFORM pg_temp.je_suis_le_serveur();
  IF v->>'ok' <> 'true' OR (v->>'retire') <> LEE THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE18 la parole n a pas ete retiree : ' || v::text;
  END IF;

  n := n + 1;   -- IL REDEMANDE, ET IL EST DERNIER. Le coeur de l'arbitrage sur la file.
  PERFORM pg_temp.je_suis(LEE_U);
  PERFORM public.assemblee_parole_demander();
  v := public.assemblee_seance(50);
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v->'file'->0->>'depute') <> MARS OR (v->'file'->2->>'depute') <> LEE THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE19 apres retrait, la demande n est pas repartie en fin de file : ' || (v->'file')::text;
  END IF;

  -- ===========================================================================================
  -- E. LE RAPPEL AU REGLEMENT
  -- ===========================================================================================
  n := n + 1;   -- UN DEPUTE NE RAPPELLE PERSONNE.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.assemblee_rappeler(MARS, TEXTE_MOTIF, 'rq-banc-usurpe-001');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'pas_le_president' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE20 un depute a pu rappeler au reglement : ' || v::text;
  END IF;

  n := n + 1;   -- UN MOTIF VIDE EST REFUSE : l'arbitrage le rend obligatoire.
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.assemblee_rappeler(MARS, '   ', 'rq-banc-vide-001');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'motif_obligatoire' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE21 un rappel sans motif est passe : ' || v::text;
  END IF;

  n := n + 1;   -- ON NE RAPPELLE PAS UN ABSENT.
  UPDATE public.personnages_donnees SET current_room = 'accueil_assemblee' WHERE name = PHIL;
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.assemblee_rappeler(PHIL, TEXTE_MOTIF, 'rq-banc-absent-001');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'cible_absente_de_l_hemicycle' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE22 un absent a pu etre rappele : ' || v::text;
  END IF;
  UPDATE public.personnages_donnees SET current_room = 'hemicycle' WHERE name = PHIL;

  n := n + 1;   -- NI UN FIGURANT QUI N'EST PAS DEPUTE.
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.assemblee_rappeler(BART, TEXTE_MOTIF, 'rq-banc-figurant-001');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'cible_pas_deputee' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE23 un non-depute a pu etre rappele : ' || v::text;
  END IF;

  n := n + 1;   -- LE RAPPEL ABOUTIT : 15 POINTS, ET LE MOTIF AU MOT.
  SELECT (resources->>'pop')::numeric INTO v_pop FROM public.personnages_donnees WHERE name = MARS;
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.assemblee_rappeler(MARS, TEXTE_MOTIF, 'rq-banc-rappel-001');
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT (resources->>'pop')::numeric INTO v_pop2 FROM public.personnages_donnees WHERE name = MARS;
  SELECT motif INTO v_txt FROM public.assemblee_disciplines WHERE requete = 'rq-banc-rappel-001';
  IF v->>'ok' <> 'true' OR v_pop2 <> v_pop - 15 OR v_txt IS DISTINCT FROM TEXTE_MOTIF THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE24 le rappel n a pas applique -15 POP ou n a pas garde le motif : pop '
      || v_pop || ' -> ' || v_pop2 || ', motif = ' || coalesce(v_txt, '(nul)');
  END IF;

  n := n + 1;   -- LA TRACE PUBLIQUE EST FACTUELLE, ET LE MOTIF VOYAGE VERBATIM DANS `data`.
  SELECT libelle INTO v_txt FROM public.chronique_nationale WHERE source_ref = (v->>'rappel');
  SELECT count(*) INTO v_n FROM public.chronique_nationale
   WHERE source_ref = (v->>'rappel') AND type = 'assemblee_rappel' AND (data->>'motif') = TEXTE_MOTIF;
  IF v_n <> 1 OR v_txt IS NULL
     OR v_txt ~* '(abusi|justifi|mensong|autoritair|scandaleu|arbitrair|legitim)' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE25 la chronique du rappel qualifie ou perd le motif : ' || coalesce(v_txt, '(nulle)');
  END IF;

  n := n + 1;   -- UN REJEU NE COUTE PAS 30 POINTS. C'etait le defaut corrige le jour meme.
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.assemblee_rappeler(MARS, TEXTE_MOTIF, 'rq-banc-rappel-001');
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT (resources->>'pop')::numeric INTO v_pop FROM public.personnages_donnees WHERE name = MARS;
  SELECT count(*) INTO v_n FROM public.assemblee_disciplines WHERE requete = 'rq-banc-rappel-001';
  IF v->>'rejeu' <> 'true' OR v_n <> 1 OR v_pop <> v_pop2 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE26 un rappel rejoue a coute deux fois : pop ' || v_pop2
      || ' -> ' || v_pop || ', ' || v_n || ' ligne(s)';
  END IF;

  -- ===========================================================================================
  -- F. LA SANCTION
  -- ===========================================================================================
  n := n + 1;   -- SANS RAPPEL PREALABLE, RIEN. Et rien n'est ecrit non plus.
  SELECT coalesce((data->>'solde')::integer, 0) INTO v_solde FROM public.caisses_batiments WHERE id = CAISSE;
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.assemblee_sanctionner(LEE, 'Sans rappel prealable.', 'rq-banc-sanction-nulle');
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT count(*) INTO v_n FROM public.assemblee_disciplines WHERE pays = 'republic' AND genre = 'sanction';
  IF coalesce(v->>'raison','') <> 'aucun_rappel_a_consommer' OR v_n <> 0 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE27 une sanction est passee sans rappel : ' || v::text;
  END IF;

  n := n + 1;   -- AVEC RAPPEL : 20 POINTS, 100 FR, LA CAISSE CREDITEE, LE RAPPEL CONSOMME.
  SELECT (resources->>'pop')::numeric, liquide INTO v_pop, v_liq
    FROM public.personnages_donnees WHERE name = MARS;
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.assemblee_sanctionner(MARS, 'Recidive immediate apres rappel.', 'rq-banc-sanction-001');
  PERFORM pg_temp.je_suis_le_serveur();
  v_rappel := v->>'rappel_consomme';
  SELECT (resources->>'pop')::numeric INTO v_pop2 FROM public.personnages_donnees WHERE name = MARS;
  SELECT coalesce((data->>'solde')::integer, 0) INTO v_solde2 FROM public.caisses_batiments WHERE id = CAISSE;
  IF v->>'ok' <> 'true' OR v_pop2 <> v_pop - 20 OR v_solde2 <> v_solde + 100
     OR v_rappel IS NULL THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE28 la sanction est incomplete : pop ' || v_pop || ' -> ' || v_pop2
      || ', caisse ' || v_solde || ' -> ' || v_solde2 || ', rappel = ' || coalesce(v_rappel, '(nul)');
  END IF;

  n := n + 1;   -- LES 100 FR SONT PARTIS DU DEPUTE : jamais de credit sans debit.
  SELECT liquide INTO v_n FROM public.personnages_donnees WHERE name = MARS;
  IF v_n <> v_liq - 100 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE29 l amende n a pas ete prelevee : liquide ' || v_liq || ' -> ' || v_n;
  END IF;

  n := n + 1;   -- UN SEUL RAPPEL NE PERMET JAMAIS DEUX SANCTIONS.
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.assemblee_sanctionner(MARS, 'Et une deuxieme fois.', 'rq-banc-sanction-002');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'aucun_rappel_a_consommer' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE30 un seul rappel a permis deux sanctions : ' || v::text;
  END IF;

  n := n + 1;   -- UN NOUVEAU RAPPEL ROUVRE LA POSSIBILITE. La sequence est rappel -> sanction.
  PERFORM pg_temp.je_suis(ARNIE_U);
  PERFORM public.assemblee_rappeler(MARS, 'Nouveau manquement.', 'rq-banc-rappel-002');
  v := public.assemblee_sanctionner(MARS, 'Suite au second rappel.', 'rq-banc-sanction-003');
  PERFORM pg_temp.je_suis_le_serveur();
  IF v->>'ok' <> 'true' OR (v->>'rappel_consomme') = v_rappel THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE31 la seconde sanction n a pas consomme le nouveau rappel : ' || v::text;
  END IF;

  n := n + 1;   -- SANS ARGENT, RIEN NE SE PASSE -- ET SURTOUT PAS A MOITIE.
  UPDATE public.personnages_donnees SET liquide = 0, arg = 0 WHERE name = LEE;
  DELETE FROM public.comptes_bancaires WHERE personnage = LEE AND banque = 'nationale';
  PERFORM pg_temp.je_suis(ARNIE_U);
  PERFORM public.assemblee_rappeler(LEE, 'Pour pouvoir le sanctionner ensuite.', 'rq-banc-rappel-003');
  PERFORM pg_temp.je_suis_le_serveur();
  -- LES REFERENCES SONT PRISES APRES LE RAPPEL : c'est l'effet de la SANCTION qu'on mesure.
  SELECT coalesce((data->>'solde')::integer, 0) INTO v_solde FROM public.caisses_batiments WHERE id = CAISSE;
  SELECT (resources->>'pop')::numeric INTO v_pop FROM public.personnages_donnees WHERE name = LEE;
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.assemblee_sanctionner(LEE, 'Amende impossible.', 'rq-banc-sanction-004');
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT coalesce((data->>'solde')::integer, 0) INTO v_solde2 FROM public.caisses_batiments WHERE id = CAISSE;
  SELECT (resources->>'pop')::numeric INTO v_pop2 FROM public.personnages_donnees WHERE name = LEE;
  SELECT count(*) INTO v_n FROM public.assemblee_disciplines WHERE requete = 'rq-banc-sanction-004';
  IF v->>'ok' <> 'false' OR v_solde2 <> v_solde OR v_pop2 <> v_pop OR v_n <> 0 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE32 une sanction sans fonds a laisse un demi-effet : caisse '
      || v_solde || ' -> ' || v_solde2 || ', pop ' || v_pop || ' -> ' || v_pop2 || ', ' || v_n || ' ligne(s)';
  END IF;

  -- ===========================================================================================
  -- G. LA MATIERE DE LA PRESSE
  -- ===========================================================================================
  n := n + 1;   -- RESERVEE A LA REDACTION, par le droit EXISTANT.
  -- ON FERME LA PREMISSE PLUTOT QUE D'ASSOUPLIR L'ASSERTION : si le figurant appartenait deja a
  -- une redaction de la beta, l'epreuve serait verte pour la mauvaise raison.
  DELETE FROM public.presse_membres WHERE personnage = BART;
  PERFORM pg_temp.je_suis(BART_U);
  v := public.assemblee_discipline_matiere(20);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'reserve_a_la_redaction' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE33 un non-journaliste a lu la matiere de presse : ' || v::text;
  END IF;

  n := n + 1;   -- UN JOURNALISTE RECOIT DES FAITS, ET LE MOTIF VERBATIM.
  INSERT INTO public.groupes_presse (id, nom, pays, organisation_id)
  VALUES ('banc-groupe-presse', 'Banc de presse', 'republic', NULL);
  INSERT INTO public.presse_membres (groupe_id, personnage, grade, nomme_par)
  VALUES ('banc-groupe-presse', BART, 'journaliste', ARNIE);
  PERFORM pg_temp.je_suis(BART_U);
  v := public.assemblee_discipline_matiere(20);
  PERFORM pg_temp.je_suis_le_serveur();
  IF v->>'ok' <> 'true' OR position(TEXTE_MOTIF in v::text) = 0 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE34 la matiere de presse ne porte pas le motif exact';
  END IF;

  n := n + 1;   -- ET ELLE NE PORTE AUCUNE QUALIFICATION. Ni dans les clefs, ni dans les valeurs
  --              produites par le serveur -- le motif du joueur, lui, dit ce qu'il veut.
  v_txt := (SELECT string_agg(k, ',') FROM jsonb_object_keys(v->'actes'->0) k);
  IF coalesce(v_txt, '') ~* '(abusi|justifi|mensong|gravite|score|jugement|legitim|pertinen)' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE35 la matiere de presse porte un champ de qualification : ' || v_txt;
  END IF;

  -- ===========================================================================================
  IF ko > 0 THEN
    RAISE EXCEPTION 'banc seance : % ECHEC(S) SUR % EPREUVES.%', ko, n, v_echecs;
  END IF;
  RAISE EXCEPTION 'banc seance : LES % EPREUVES SONT VERTES. -- rien ne doit rester', n;
END $banc$;
ROLLBACK;
