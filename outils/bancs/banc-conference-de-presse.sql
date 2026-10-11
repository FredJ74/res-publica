-- BANC DE LA CONFERENCE DE PRESSE ET DU FINANCEMENT DES COMMUNICATIONS (11 octobre 2026)
--
-- CE BANC NE COMMITE RIEN. Il fait parler un ministre reel, deplace des soldes de caisse, cree
-- des conferences et des sujets de forum, puis se termine par un RAISE EXCEPTION INCONDITIONNEL.
-- Un banc du 4 octobre 2026 a laisse une accusation forgee au nom d'un joueur reel pendant six
-- jours parce qu'il commitait : aucun banc de ce depot ne commite plus.
--
-- CE QU'IL PROUVE -- les deux arbitrages, et leurs contre-epreuves :
--
-- A. QUI PAIE
--   . les francs sortent PAR DEFAUT du budget du Ministere de l'Information ;
--   . s'il ne couvre pas, RIEN n'est debite et la porte NOMME la caisse de repli et son solde ;
--   . avec l'accord explicite, le cout est pris EN ENTIER sur la caisse du poste -- et le budget
--     de l'Information reste INTACT : il n'y a pas de financement mixte ;
--   . si aucune des deux ne couvre, c'est impossible, et rien n'est debite ;
--   . un refus ne coute NI FRANC NI POINT D'ACTION, et n'ecrit rien du tout ;
--   . la caisse du Premier ministre n'est pas inventee : c'est celle que `salaires_caisses`
--     declare deja pour son poste ;
--   . un manque de PA ne laisse aucun franc preleve -- le verrou des PA est pris AVANT le debit.
--
-- B. LA BOUCLE DES JOURNALISTES
--   . la conference nait VIDE : aucune question n'est preparee a l'avance ;
--   . le navigateur NE PEUT PAS poser une question -- la porte est reservee au serveur ;
--   . on ne pose pas une question tant que la precedente n'a pas de suite ;
--   . la reponse est conservee VERBATIM, et une reponse deja donnee ne peut pas etre reecrite :
--     les paroles du ministre sont intangibles ;
--   . un joueur ne peut pas ecrire dans la transcription, meme directement ;
--   . un REFUS DE REPONDRE ne termine PAS la conference ;
--   . au-dela de cinq questions, la porte refuse ;
--   . fermer la conference la ferme IMMEDIATEMENT : plus aucune question ne s'y ajoute, et ce
--     qui a eu lieu avant est conserve ;
--   . une seule conference ouverte par auteur, et le second essai ne debite rien.
--
-- C. LA TRACE PUBLIQUE ET LA MATIERE DE LA REDACTION
--   . une trace FACTUELLE est deposee dans la chronique nationale par le serveur, dans la meme
--     transaction -- sans resume, sans jugement, sans transcription ;
--   . la transcription n'est PAS publiee automatiquement : elle attend `conference_matiere` ;
--   . la matiere est reservee aux membres d'un groupe de presse -- un ministre est refuse ;
--   . elle ne rend que les conferences CLOSES, et ne porte ni titre d'article, ni angle, ni
--     commentaire, ni aucun champ de jugement.
--
-- Usage : coller ce fichier dans un execute_sql. Il doit finir sur
--   ERROR: banc conference : LES 63 EPREUVES SONT VERTES. -- rien ne doit rester

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
  LEE_U   text := 'ea4a2a0c-a192-4e10-8cff-d5db9b1cceb6'; LEE   text := 'Lee Capene';
  GOUV text := 'palais-gouvernement'; SPG text := 'salle_presse';
  C_INFO text := 'republic_gouvernement-min_info';
  C_DEF  text := 'republic_gouvernement-min_def';
  -- LES MONTANTS NE SONT PAS INVENTES ICI : ils sont RELUS dans le miroir des couts, qui est
  -- genere depuis data.js. Si le game design les change, le banc suit sans etre retouche.
  PA_PROP integer; FR_PROP integer; PA_CONF integer; FR_CONF integer;
  v jsonb; n integer := 0; ko integer := 0; v_echecs text := '';
  v_conf text; v_conf2 text; v_n integer; v_pa integer; v_pa0 integer;
  v_info numeric; v_def numeric; v_txt text; v_statut text; v_cles text[];
  REPONSE_EXACTE text := 'Non, et je le dis clairement : « l etat n a jamais finance cela » -- point final.';
BEGIN
  PERFORM pg_temp.je_suis_le_serveur();

  SELECT pa, cost INTO PA_PROP, FR_PROP FROM public.ordres_couts WHERE fn = 'propagande_etat';
  SELECT pa, cost INTO PA_CONF, FR_CONF FROM public.ordres_couts WHERE fn = 'conference_presse';
  IF PA_PROP IS NULL OR PA_CONF IS NULL THEN
    RAISE EXCEPTION 'banc conference : le miroir ne declare pas les ordres de tribune';
  END IF;
  n := n + 1;  -- E1 : la propagande est le seul des trois ordres qui coute des francs ; sans elle,
               -- la question du financement ne se poserait jamais.
  IF FR_PROP <= 0 OR FR_CONF <> 0 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE1 les couts du miroir ne sont plus ceux attendus : propagande '
      || FR_PROP || ' FR, conference ' || FR_CONF || ' FR';
  END IF;

  -- DECOR. Arnie est REELLEMENT ministre de la Defense (poste atteste) : on ne lui invente pas
  -- d'autorite. Ben et Lee n'ont aucun poste. Lee entre dans un groupe de presse de decor, parce
  -- qu'aucun n'existe encore en base -- c'est le droit EXISTANT qu'on eprouve, pas un nouveau.
  UPDATE public.personnages_donnees SET pa = 30 WHERE name = ARNIE;
  UPDATE public.personnages_donnees SET poste = NULL, pa = 12 WHERE name IN (BEN, LEE);
  INSERT INTO public.groupes_presse (id, pays, nom) VALUES ('banc-presse', 'republic', 'La Tribune du banc')
    ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.presse_membres (groupe_id, personnage, grade)
    VALUES ('banc-presse', LEE, 'redacteur_chef') ON CONFLICT DO NOTHING;

  -- ===========================================================================================
  -- A. QUI PAIE
  -- ===========================================================================================
  -- A1. L'INFORMATION COUVRE : c'est elle qui paie, et la caisse du ministre n'est pas touchee.
  UPDATE public.caisses_batiments SET data = jsonb_set(coalesce(data,'{}'::jsonb), '{solde}', '10000'::jsonb) WHERE id = C_INFO;
  UPDATE public.caisses_batiments SET data = jsonb_set(coalesce(data,'{}'::jsonb), '{solde}', '20000'::jsonb) WHERE id = C_DEF;
  SELECT pa INTO v_pa0 FROM public.personnages_donnees WHERE name = ARNIE;

  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.communication_officielle_publier(GOUV, SPG, 'propagande_etat', PA_PROP, FR_PROP,
        'L effort national', '<p>Le pays avance.</p>', '[]'::jsonb);
  PERFORM pg_temp.je_suis_le_serveur();
  n := n + 1;
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE OR v->>'caisse_payeuse' <> C_INFO THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE2 l Information n a pas paye par defaut : ' || v::text;
  END IF;
  SELECT (data->>'solde')::numeric INTO v_info FROM public.caisses_batiments WHERE id = C_INFO;
  SELECT (data->>'solde')::numeric INTO v_def  FROM public.caisses_batiments WHERE id = C_DEF;
  n := n + 1;
  IF v_info <> 10000 - FR_PROP THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE3 le budget de l Information n a pas ete debite : ' || v_info;
  END IF;
  n := n + 1;   -- CONTRE-EPREUVE : la caisse du ministre n'a RIEN paye.
  IF v_def <> 20000 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE4 la caisse du ministre a ete touchee a tort : ' || v_def;
  END IF;
  SELECT pa INTO v_pa FROM public.personnages_donnees WHERE name = ARNIE;
  n := n + 1;
  IF v_pa <> v_pa0 - PA_PROP THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE5 les PA n ont pas ete preleves : ' || v_pa || ' au lieu de ' || (v_pa0 - PA_PROP);
  END IF;
  n := n + 1;   -- LE MOUVEMENT EST JOURNALISE, comme tout debit de caisse institutionnelle.
  SELECT count(*) INTO v_n FROM public.caisses_mouvements_clients
   WHERE acteur = ARNIE AND caisse = C_INFO AND delta = -FR_PROP AND motif = 'communication_officielle:propagande_etat';
  IF v_n < 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE6 le debit de caisse n est pas journalise';
  END IF;

  -- La conference de A1 est close : l'index d'unicite n'autorise qu'une ouverte par auteur, et
  -- c'est precisement ce qu'on eprouvera en B.
  v_conf := v->>'conference';
  PERFORM public.conference_clore(v_conf, false);
  PERFORM pg_sleep(0.003);

  -- A2. L'INFORMATION NE COUVRE PAS, ET PERSONNE N'A DONNE SON ACCORD : rien ne bouge.
  UPDATE public.caisses_batiments SET data = jsonb_set(data, '{solde}', '100'::jsonb) WHERE id = C_INFO;
  UPDATE public.caisses_batiments SET data = jsonb_set(data, '{solde}', '20000'::jsonb) WHERE id = C_DEF;
  SELECT pa INTO v_pa0 FROM public.personnages_donnees WHERE name = ARNIE;
  SELECT count(*) INTO v_n FROM public.conferences_presse;

  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.communication_officielle_publier(GOUV, SPG, 'propagande_etat', PA_PROP, FR_PROP,
        'Un second message', '<p>Encore.</p>', '[]'::jsonb);
  PERFORM pg_temp.je_suis_le_serveur();
  n := n + 1;
  IF coalesce((v->>'ok')::boolean, true) IS NOT FALSE
     OR coalesce((v->>'accord_requis')::boolean, false) IS NOT TRUE
     OR v->>'raison' <> 'budget_information_insuffisant' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE7 le refus de financement est mal forme : ' || v::text;
  END IF;
  n := n + 1;   -- LA CAISSE DE REPLI EST NOMMEE, ET SON SOLDE AUSSI : on ne demande pas a
                -- l'humain d'accepter une depense dont il ignore la provenance.
  IF v->>'caisse_proposee' <> C_DEF OR (v->>'solde_proposee')::numeric <> 20000
     OR coalesce((v->>'proposee_suffisante')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE8 la caisse de repli est mal rendue : ' || v::text;
  END IF;
  SELECT (data->>'solde')::numeric INTO v_info FROM public.caisses_batiments WHERE id = C_INFO;
  SELECT (data->>'solde')::numeric INTO v_def  FROM public.caisses_batiments WHERE id = C_DEF;
  n := n + 1;   -- CONTRE-EPREUVE : AUCUN FRANC n'a bouge, ni d'un cote ni de l'autre.
  IF v_info <> 100 OR v_def <> 20000 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE9 un franc a ete debite sur un refus : info ' || v_info || ', def ' || v_def;
  END IF;
  SELECT pa INTO v_pa FROM public.personnages_donnees WHERE name = ARNIE;
  n := n + 1;   -- CONTRE-EPREUVE : AUCUN PA n'a ete perdu.
  IF v_pa <> v_pa0 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE10 des PA ont ete perdus sur un refus : ' || v_pa;
  END IF;
  n := n + 1;   -- CONTRE-EPREUVE : AUCUNE conference n'a ete ouverte.
  IF (SELECT count(*) FROM public.conferences_presse) <> v_n THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE11 une conference a ete ouverte sur un refus';
  END IF;

  -- A3. AVEC L'ACCORD EXPLICITE : la caisse du poste paie LA TOTALITE, et l'Information reste
  -- INTACTE. C'est la preuve qu'il n'y a pas de financement mixte.
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.communication_officielle_publier(GOUV, SPG, 'propagande_etat', PA_PROP, FR_PROP,
        'Un second message', '<p>Encore.</p>', '[]'::jsonb, true);
  PERFORM pg_temp.je_suis_le_serveur();
  n := n + 1;
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE OR v->>'caisse_payeuse' <> C_DEF THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE12 l accord explicite n a pas fait payer la caisse du poste : ' || v::text;
  END IF;
  SELECT (data->>'solde')::numeric INTO v_info FROM public.caisses_batiments WHERE id = C_INFO;
  SELECT (data->>'solde')::numeric INTO v_def  FROM public.caisses_batiments WHERE id = C_DEF;
  n := n + 1;
  IF v_def <> 20000 - FR_PROP THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE13 la caisse du poste n a pas paye en entier : ' || v_def;
  END IF;
  n := n + 1;   -- PAS DE FINANCEMENT MIXTE : l'Information n'a pas verse ses 100 FR disponibles.
  IF v_info <> 100 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE14 financement mixte : l Information a verse une part : ' || v_info;
  END IF;
  v_conf := v->>'conference';
  PERFORM public.conference_clore(v_conf, false);
  PERFORM pg_sleep(0.003);

  -- A4. AUCUNE DES DEUX NE COUVRE : c'est impossible, et rien n'est debite.
  UPDATE public.caisses_batiments SET data = jsonb_set(data, '{solde}', '100'::jsonb) WHERE id = C_INFO;
  UPDATE public.caisses_batiments SET data = jsonb_set(data, '{solde}', '10'::jsonb)  WHERE id = C_DEF;
  SELECT pa INTO v_pa0 FROM public.personnages_donnees WHERE name = ARNIE;
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.communication_officielle_publier(GOUV, SPG, 'propagande_etat', PA_PROP, FR_PROP,
        'Un troisieme message', '<p>Toujours.</p>', '[]'::jsonb, true);
  PERFORM pg_temp.je_suis_le_serveur();
  n := n + 1;
  IF v->>'raison' <> 'les_deux_caisses_insuffisantes'
     OR coalesce((v->>'accord_requis')::boolean, true) IS NOT FALSE THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE15 la double insuffisance est mal nommee : ' || v::text;
  END IF;
  SELECT (data->>'solde')::numeric INTO v_info FROM public.caisses_batiments WHERE id = C_INFO;
  SELECT (data->>'solde')::numeric INTO v_def  FROM public.caisses_batiments WHERE id = C_DEF;
  SELECT pa INTO v_pa FROM public.personnages_donnees WHERE name = ARNIE;
  n := n + 1;
  IF v_info <> 100 OR v_def <> 10 OR v_pa <> v_pa0 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE16 une ressource a ete consommee sur une depense impossible';
  END IF;

  -- A5. LA CAISSE DU PREMIER MINISTRE N'EST PAS INVENTEE. Elle vient du resolveur declaratif, et
  -- elle existe reellement en base : sans cela, le PM aurait une tribune mais aucun financement.
  n := n + 1;
  IF public.salaire_caisse_de('pm', 'republic', NULL) IS DISTINCT FROM 'republic_gouvernement-pm' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE17 la caisse du PM n est pas celle que le resolveur declare : '
      || coalesce(public.salaire_caisse_de('pm','republic',NULL), 'NULL');
  END IF;
  n := n + 1;
  SELECT count(*) INTO v_n FROM public.caisses_batiments WHERE id = 'republic_gouvernement-pm';
  IF v_n <> 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE18 la caisse du PM n existe pas en base';
  END IF;
  n := n + 1;   -- ET ELLE EST DECLAREE, pas devinee par une convention de nommage. La ligne
                -- existe, et son motif porte meme la note « enveloppe du PM » : c est bien la
                -- caisse institutionnelle de sa FONCTION, pas une caisse creee pour l occasion.
  SELECT count(*) INTO v_n FROM public.salaires_caisses
   WHERE poste_id = 'pm' AND motif = '{pays}_gouvernement-pm';
  IF v_n <> 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE19 la caisse du PM n est pas declaree dans salaires_caisses';
  END IF;
  n := n + 1;   -- LES SEPT POSTES DE LA TRIBUNE ONT TOUS UNE CAISSE REELLE.
  SELECT count(*) INTO v_n FROM (
    SELECT unnest(postes) AS p FROM public.communications_salles WHERE building_id = GOUV) q
   WHERE public.salaire_caisse_de(q.p, 'republic', NULL) IS NULL
      OR NOT EXISTS (SELECT 1 FROM public.caisses_batiments cb
                      WHERE cb.id = public.salaire_caisse_de(q.p, 'republic', NULL));
  IF v_n <> 0 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE20 ' || v_n || ' poste(s) de tribune sans caisse reelle';
  END IF;

  -- A6. UNE COMMUNICATION GRATUITE NE POSE AUCUNE QUESTION DE CAISSE.
  UPDATE public.caisses_batiments SET data = jsonb_set(data, '{solde}', '0'::jsonb) WHERE id = C_INFO;
  UPDATE public.caisses_batiments SET data = jsonb_set(data, '{solde}', '0'::jsonb) WHERE id = C_DEF;
  SELECT pa INTO v_pa0 FROM public.personnages_donnees WHERE name = ARNIE;
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.communication_officielle_publier(GOUV, SPG, 'conference_presse', PA_CONF, FR_CONF,
        'Les comptes de la Defense', '<p>Je reponds aux questions.</p>', '[]'::jsonb);
  PERFORM pg_temp.je_suis_le_serveur();
  n := n + 1;
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE OR v->>'caisse_payeuse' IS NOT NULL THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE21 une communication gratuite a cherche une caisse : ' || v::text;
  END IF;
  SELECT pa INTO v_pa FROM public.personnages_donnees WHERE name = ARNIE;
  n := n + 1;
  IF v_pa <> v_pa0 - PA_CONF THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE22 les PA d une conference gratuite sont mal pris : ' || v_pa;
  END IF;
  v_conf := v->>'conference';

  -- ===========================================================================================
  -- B. LA BOUCLE DES JOURNALISTES
  -- ===========================================================================================
  -- B1. LA CONFERENCE NAIT VIDE. Aucune question n'est preparee a l'avance : c'est la difference
  -- entre une conference de presse et un formulaire.
  n := n + 1;
  SELECT statut INTO v_statut FROM public.conferences_presse WHERE id = v_conf;
  SELECT count(*) INTO v_n FROM public.conferences_presse_echanges WHERE conference_id = v_conf;
  IF v_statut <> 'ouverte' OR v_n <> 0 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE23 la conference ne nait pas ouverte et vide : ' || v_statut || ', ' || v_n || ' echange(s)';
  END IF;
  n := n + 1;   -- LA FONCTION EST FIGEE AU MOMENT DE LA PAROLE : un ministre revoque demain a bien
                -- parle comme ministre aujourd hui.
  SELECT poste_id INTO v_txt FROM public.conferences_presse WHERE id = v_conf;
  IF v_txt <> 'min_def' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE24 le poste n est pas fige dans la conference : ' || coalesce(v_txt,'NULL');
  END IF;

  -- B2. UNE SEULE CONFERENCE OUVERTE PAR AUTEUR, et le second essai ne debite RIEN.
  SELECT pa INTO v_pa0 FROM public.personnages_donnees WHERE name = ARNIE;
  PERFORM pg_sleep(0.003);
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.communication_officielle_publier(GOUV, SPG, 'conference_presse', PA_CONF, FR_CONF,
        'Une seconde conference', '<p>Encore moi.</p>', '[]'::jsonb);
  PERFORM pg_temp.je_suis_le_serveur();
  n := n + 1;
  IF v->>'raison' <> 'conference_deja_ouverte' OR v->>'conference' <> v_conf THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE25 deux conferences ouvertes a la fois : ' || v::text;
  END IF;
  SELECT pa INTO v_pa FROM public.personnages_donnees WHERE name = ARNIE;
  n := n + 1;
  IF v_pa <> v_pa0 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE26 des PA ont ete pris sur une conference refusee : ' || v_pa;
  END IF;

  -- B3. CONTRE-EPREUVE CAPITALE : LE NAVIGATEUR NE POSE PAS LES QUESTIONS. S'il le pouvait, il
  -- choisirait ce que les journalistes demandent -- donc la transcription elle-meme.
  PERFORM pg_temp.je_suis(ARNIE_U);
  BEGIN
    v := public.conference_question_poser(v_conf, 'Une question que je m ecris a moi-meme ?');
    n := n + 1; ko := ko + 1;
    v_echecs := v_echecs || E'\nE27 un joueur authentifie a pu poser une question : ' || v::text;
  EXCEPTION WHEN insufficient_privilege THEN
    n := n + 1;
  END;
  PERFORM pg_temp.je_suis_le_serveur();

  -- B4. LA PREMIERE QUESTION, POSEE PAR LE SERVEUR.
  v := public.conference_question_poser(v_conf, 'Monsieur le Ministre, ou en est le budget de la Defense ?');
  n := n + 1;
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE OR (v->>'rang')::integer <> 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE28 la premiere question n a pas ete posee : ' || v::text;
  END IF;

  -- B5. ON N'EMPILE PAS LES QUESTIONS SANS REPONSE.
  v := public.conference_question_poser(v_conf, 'Et sur les effectifs ?');
  n := n + 1;
  IF v->>'raison' <> 'question_en_attente_de_reponse' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE29 une question a ete posee alors que la precedente attendait : ' || v::text;
  END IF;

  -- B6. CONTRE-EPREUVE : UN AUTRE JOUEUR NE MET PAS DE MOTS DANS LA BOUCHE DU MINISTRE.
  PERFORM pg_temp.je_suis(BEN_U);
  v := public.conference_repondre(v_conf, 1, 'Je demissionne.', false);
  PERFORM pg_temp.je_suis_le_serveur();
  n := n + 1;
  IF v->>'raison' <> 'pas_votre_conference' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE30 un tiers a pu repondre a la place de l auteur : ' || v::text;
  END IF;
  n := n + 1;
  SELECT reponse INTO v_txt FROM public.conferences_presse_echanges WHERE conference_id = v_conf AND rang = 1;
  IF v_txt IS NOT NULL THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE31 la reponse d un tiers a ete enregistree : ' || v_txt;
  END IF;

  -- B7. LA REPONSE EST CONSERVEE VERBATIM. Ni nettoyage, ni reformulation, ni analyse : ce sont
  -- les paroles du ministre, accents, guillemets et tirets compris.
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.conference_repondre(v_conf, 1, REPONSE_EXACTE, false);
  PERFORM pg_temp.je_suis_le_serveur();
  n := n + 1;
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE32 l auteur n a pas pu repondre : ' || v::text;
  END IF;
  n := n + 1;
  SELECT reponse INTO v_txt FROM public.conferences_presse_echanges WHERE conference_id = v_conf AND rang = 1;
  IF v_txt IS DISTINCT FROM REPONSE_EXACTE THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE33 la reponse n est pas conservee verbatim : ' || coalesce(v_txt,'NULL');
  END IF;

  -- B8. LES PAROLES DU MINISTRE SONT INTANGIBLES : une reponse donnee ne se reecrit pas.
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.conference_repondre(v_conf, 1, 'En fait si, l etat a tout finance.', false);
  PERFORM pg_temp.je_suis_le_serveur();
  n := n + 1;
  IF v->>'raison' <> 'deja_repondu' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE34 une reponse a pu etre reecrite : ' || v::text;
  END IF;
  n := n + 1;
  SELECT reponse INTO v_txt FROM public.conferences_presse_echanges WHERE conference_id = v_conf AND rang = 1;
  IF v_txt IS DISTINCT FROM REPONSE_EXACTE THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE35 le texte d origine a ete altere : ' || coalesce(v_txt,'NULL');
  END IF;

  -- B9 / B10. AUCUN JOUEUR NE PEUT FALSIFIER DIRECTEMENT LA TRANSCRIPTION. Les deux tables sont
  -- sous RLS sans policy, et aucun droit d ecriture n est accorde au role client.
  PERFORM pg_temp.je_suis(ARNIE_U);
  BEGIN
    UPDATE public.conferences_presse_echanges SET reponse = 'Texte reecrit a la main'
     WHERE conference_id = v_conf AND rang = 1;
    n := n + 1;
    SELECT reponse INTO v_txt FROM public.conferences_presse_echanges WHERE conference_id = v_conf AND rang = 1;
    IF v_txt IS DISTINCT FROM REPONSE_EXACTE THEN
      ko := ko + 1; v_echecs := v_echecs || E'\nE36 un joueur a reecrit la transcription a la main';
    END IF;
  EXCEPTION WHEN insufficient_privilege THEN
    n := n + 1;
  END;
  PERFORM pg_temp.je_suis(ARNIE_U);
  BEGIN
    INSERT INTO public.conferences_presse_echanges (conference_id, rang, question)
    VALUES (v_conf, 4, 'Une question que je m invente');
    n := n + 1; ko := ko + 1;
    v_echecs := v_echecs || E'\nE37 un joueur a insere une question dans la transcription';
  EXCEPTION WHEN insufficient_privilege OR check_violation THEN
    n := n + 1;
  END;
  PERFORM pg_temp.je_suis(ARNIE_U);
  n := n + 1;   -- ET IL N'EN LIT MEME PAS LA TABLE EN DIRECT : il passe par les portes.
  SELECT count(*) INTO v_n FROM public.conferences_presse_echanges;
  IF v_n <> 0 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE38 un joueur lit la table des echanges en direct : ' || v_n || ' ligne(s)';
  END IF;
  PERFORM pg_temp.je_suis_le_serveur();

  -- B11. UN REFUS DE REPONDRE NE TERMINE PAS LA CONFERENCE, et ce n'est pas une reponse vide.
  v := public.conference_question_poser(v_conf, 'Avez-vous informe le President ?');
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.conference_repondre(v_conf, 2, NULL, true);
  PERFORM pg_temp.je_suis_le_serveur();
  n := n + 1;
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE OR coalesce((v->>'refus')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE39 le refus n a pas ete enregistre : ' || v::text;
  END IF;
  n := n + 1;
  SELECT count(*) INTO v_n FROM public.conferences_presse_echanges
   WHERE conference_id = v_conf AND rang = 2 AND refus AND reponse IS NULL AND repondu_le IS NOT NULL;
  IF v_n <> 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE40 un refus n est pas distingue d une reponse vide';
  END IF;
  n := n + 1;   -- CONTRE-EPREUVE : LA CONFERENCE EST TOUJOURS OUVERTE.
  SELECT statut INTO v_statut FROM public.conferences_presse WHERE id = v_conf;
  IF v_statut <> 'ouverte' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE41 un refus a termine la conference : ' || v_statut;
  END IF;
  n := n + 1;   -- ET ON PEUT ENCHAINER APRES UN REFUS.
  v := public.conference_question_poser(v_conf, 'Pourquoi refusez-vous de repondre ?');
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE OR (v->>'rang')::integer <> 3 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE42 on ne peut pas enchainer apres un refus : ' || v::text;
  END IF;

  -- B12. LE MAXIMUM DE CINQ EST TENU PAR LA PORTE, et une sixieme question est refusee.
  PERFORM pg_temp.je_suis(ARNIE_U);
  PERFORM public.conference_repondre(v_conf, 3, 'Parce que c est confidentiel.', false);
  PERFORM pg_temp.je_suis_le_serveur();
  PERFORM public.conference_question_poser(v_conf, 'Quatrieme question ?');
  PERFORM pg_temp.je_suis(ARNIE_U);
  PERFORM public.conference_repondre(v_conf, 4, 'Reponse quatre.', false);
  PERFORM pg_temp.je_suis_le_serveur();
  v := public.conference_question_poser(v_conf, 'Cinquieme question ?');
  n := n + 1;
  IF (v->>'rang')::integer <> 5 OR (v->>'reste_possible')::integer <> 0 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE43 la cinquieme question est mal comptee : ' || v::text;
  END IF;
  PERFORM pg_temp.je_suis(ARNIE_U);
  PERFORM public.conference_repondre(v_conf, 5, 'Reponse cinq.', false);
  PERFORM pg_temp.je_suis_le_serveur();
  v := public.conference_question_poser(v_conf, 'Sixieme question ?');
  n := n + 1;
  IF v->>'raison' <> 'maximum_de_questions_atteint' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE44 une sixieme question a ete posee : ' || v::text;
  END IF;
  n := n + 1;
  SELECT count(*) INTO v_n FROM public.conferences_presse_echanges WHERE conference_id = v_conf;
  IF v_n <> 5 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE45 la conference porte ' || v_n || ' echanges au lieu de 5';
  END IF;

  -- B13. FERMER MET FIN IMMEDIATEMENT : plus aucune question ne s'ajoute.
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.conference_clore(v_conf, false);
  PERFORM pg_temp.je_suis_le_serveur();
  n := n + 1;
  IF v->>'statut' <> 'terminee' OR (v->>'echanges')::integer <> 5 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE46 la cloture normale est mal rendue : ' || v::text;
  END IF;
  v := public.conference_question_poser(v_conf, 'Une question de trop ?');
  n := n + 1;
  IF v->>'raison' <> 'conference_close' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE47 une question a pu etre posee apres la cloture : ' || v::text;
  END IF;
  n := n + 1;   -- CONTRE-EPREUVE : CE QUI A EU LIEU EST CONSERVE.
  SELECT count(*) INTO v_n FROM public.conferences_presse_echanges WHERE conference_id = v_conf;
  IF v_n <> 5 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE48 la cloture a efface des echanges : ' || v_n;
  END IF;
  n := n + 1;   -- ET LA REPONSE NE BOUGE PAS DAVANTAGE APRES LA CLOTURE.
  SELECT reponse INTO v_txt FROM public.conferences_presse_echanges WHERE conference_id = v_conf AND rang = 1;
  IF v_txt IS DISTINCT FROM REPONSE_EXACTE THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE49 la transcription a change apres la cloture';
  END IF;
  n := n + 1;   -- IDEMPOTENTE : un double clic sur la croix ne leve pas.
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.conference_clore(v_conf, false);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE OR coalesce((v->>'deja_close')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE50 refermer une conference close leve : ' || v::text;
  END IF;

  -- B14. L'INTERRUPTION EST UNE FIN DIFFERENTE, et une redaction a le droit de le savoir.
  PERFORM pg_sleep(0.003);
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.communication_officielle_publier(GOUV, SPG, 'dementi', 2, 0,
        'Je dementi formellement', '<p>C est faux.</p>', '[]'::jsonb);
  PERFORM pg_temp.je_suis_le_serveur();
  v_conf2 := v->>'conference';
  PERFORM public.conference_question_poser(v_conf2, 'Que dementez-vous exactement ?');
  PERFORM pg_temp.je_suis(ARNIE_U);
  PERFORM public.conference_repondre(v_conf2, 1, 'Tout.', false);
  v := public.conference_clore(v_conf2, true);
  PERFORM pg_temp.je_suis_le_serveur();
  n := n + 1;
  IF v->>'statut' <> 'interrompue' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE51 l interruption n est pas enregistree comme telle : ' || v::text;
  END IF;
  n := n + 1;
  SELECT count(*) INTO v_n FROM public.conferences_presse_echanges WHERE conference_id = v_conf2;
  IF v_n <> 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE52 l interruption a efface l echange qui avait eu lieu';
  END IF;

  -- B16. CONTRE-EPREUVE : UN TIERS NE CLOT PAS LA CONFERENCE D'UN AUTRE.
  PERFORM pg_sleep(0.003);
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.communication_officielle_publier(GOUV, SPG, 'conference_presse', PA_CONF, FR_CONF,
        'Une conference en cours', '<p>Je parle.</p>', '[]'::jsonb);
  PERFORM pg_temp.je_suis_le_serveur();
  v_conf := v->>'conference';
  PERFORM pg_temp.je_suis(BEN_U);
  v := public.conference_clore(v_conf, true);
  PERFORM pg_temp.je_suis_le_serveur();
  n := n + 1;
  IF v->>'raison' <> 'pas_votre_conference' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE53 un tiers a clos la conference d un autre : ' || v::text;
  END IF;
  n := n + 1;
  SELECT statut INTO v_statut FROM public.conferences_presse WHERE id = v_conf;
  IF v_statut <> 'ouverte' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE54 la conference a ete close par un tiers : ' || v_statut;
  END IF;

  -- ===========================================================================================
  -- C. LA TRACE PUBLIQUE ET LA MATIERE DE LA REDACTION
  -- ===========================================================================================
  -- C1. LA TRACE EST FACTUELLE, ECRITE PAR LE SERVEUR, DANS LA MEME TRANSACTION. Elle dit QU UNE
  -- conference a eu lieu, et rien de son contenu.
  n := n + 1;
  SELECT count(*) INTO v_n FROM public.chronique_nationale
   WHERE type = 'conference_presse' AND country = 'republic' AND source_ref = v_conf2;
  IF v_n <> 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE55 aucune trace publique pour la conference ' || v_conf2;
  END IF;
  n := n + 1;
  SELECT libelle INTO v_txt FROM public.chronique_nationale WHERE source_ref = v_conf2;
  IF v_txt IS NULL OR v_txt NOT LIKE '%conference de presse%' OR v_txt NOT LIKE '%Je dementi formellement%' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE56 la trace publique ne nomme pas le fait : ' || coalesce(v_txt,'NULL');
  END IF;
  n := n + 1;   -- CONTRE-EPREUVE : AUCUNE TRANSCRIPTION DANS LA TRACE PUBLIQUE.
  SELECT data::text INTO v_txt FROM public.chronique_nationale WHERE source_ref = v_conf2;
  IF v_txt LIKE '%question%' OR v_txt LIKE '%reponse%' OR v_txt LIKE '%Tout.%'
     OR v_txt LIKE '%dementez%' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE57 la trace publique contient la transcription : ' || v_txt;
  END IF;

  -- C2. CONTRE-EPREUVE : LA MATIERE N'EST PAS OUVERTE AU GOUVERNEMENT. Un ministre ne lit pas la
  -- transcription des conferences du pays.
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.conference_matiere(10);
  PERFORM pg_temp.je_suis_le_serveur();
  n := n + 1;
  IF v->>'raison' <> 'reserve_a_la_redaction' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE58 un ministre a lu la matiere de la redaction : ' || left(v::text, 200);
  END IF;

  -- C3. LA REDACTION, ELLE, RECOIT LA MATIERE BRUTE DES CONFERENCES CLOSES.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.conference_matiere(10);
  PERFORM pg_temp.je_suis_le_serveur();
  n := n + 1;
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE OR v->>'pays' <> 'republic' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE59 la redaction ne recoit pas la matiere : ' || left(v::text, 200);
  END IF;
  n := n + 1;   -- LA TRANSCRIPTION EST COMPLETE ET EXACTE : c est ce qui permet de CITER.
  IF v::text NOT LIKE '%' || REPONSE_EXACTE || '%' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE60 la matiere ne porte pas la reponse exacte du ministre';
  END IF;
  n := n + 1;   -- CONTRE-EPREUVE : ON NE CITE PAS UNE CONFERENCE EN COURS.
  IF v::text LIKE '%' || v_conf || '%' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE61 la matiere livre une conference encore ouverte';
  END IF;
  n := n + 1;   -- CONTRE-EPREUVE : AUCUN CHAMP DE JUGEMENT, ET AUCUN TRAVAIL EDITORIAL. Le titre
                -- d article, l angle et le commentaire appartiennent au journaliste joueur.
  SELECT array_agg(k ORDER BY k) INTO v_cles
    FROM jsonb_object_keys((v->'conferences')->0) AS k;
  IF v_cles IS NULL OR v_cles <> ARRAY['auteur','close_le','communication','echanges','fonction',
                                       'id','ordre','ouverte_le','poste','statut','titre']::text[] THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE62 la matiere ne porte pas exactement les champs attestes : '
      || coalesce(array_to_string(v_cles, ','), 'NULL');
  END IF;

  -- C5. LA LECTURE D'UNE CONFERENCE NOMMEE : l auteur et la presse, et personne d autre.
  PERFORM pg_temp.je_suis(BEN_U);
  v := public.conference_lire(v_conf2);
  PERFORM pg_temp.je_suis_le_serveur();
  n := n + 1;
  IF v->>'raison' <> 'lecture_reservee_a_l_auteur_et_a_la_presse' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE63 un tiers a lu une conference : ' || left(v::text, 200);
  END IF;

  -- ===========================================================================================
  IF ko > 0 THEN
    RAISE EXCEPTION 'banc conference : % ECHEC(S) SUR % EPREUVES.%', ko, n, v_echecs;
  END IF;
  RAISE EXCEPTION 'banc conference : LES % EPREUVES SONT VERTES. -- rien ne doit rester', n;
END $banc$;
ROLLBACK;
