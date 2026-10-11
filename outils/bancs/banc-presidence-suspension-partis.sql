-- BANC DE LA SUSPENSION PRESIDENTIELLE, DU DEUXIEME BOYCOTT ET DE L'AUTORITE DES PARTIS
-- (11 octobre 2026)
--
-- CE BANC NE COMMITE RIEN. Il forge six deputes joueurs, une presidence au registre et un parti
-- politique, joue deux boycotts complets, et se termine par un RAISE EXCEPTION INCONDITIONNEL.
--
-- CE QU'IL PROUVE -- LA SUSPENSION PRESIDENTIELLE :
--   . seul le President suspend, et cela coute 20 points de popularite ;
--   . l'etat PERSISTE -- c'est tout l'arbitrage neuf de cette passe -- et on ne suspend pas deux
--     fois une seance deja suspendue : ce serait payer deux fois le meme etat ;
--   . pendant la suspension, la parole ne se demande pas, ne se donne pas, et PERSONNE ne parle --
--     pas meme le President, qui a « Reprendre la seance » pour cela ; et la police de seance ne
--     s'exerce pas sur une seance qui ne siege pas ;
--   . mais QUITTER L'HEMICYCLE ET Y REVENIR restent possibles : ce sont des actes PHYSIQUES ;
--   . elle n'est JAMAIS un boycott, et elle ne reporte AUCUN scrutin -- cette regle-la n'est pas
--     arbitree, elle n'a donc pas ete inventee ;
--   . seul le President reprend, et la reprise ne coute rien ; un rejeu n'est pas un faux refus.
--
-- CE QU'IL PROUVE -- LE DEUXIEME BOYCOTT :
--   . 5 -> 4 -> 5 et 5 -> 3 -> 1 -> 5 restent le MEME episode ; seul un retour a ZERO le termine ;
--   . un aller-retour individuel ne declenche donc JAMAIS d'election ;
--   . un deuxieme episode DISTINCT inscrit une election DUE, une seule, avec sa cause ;
--   . et la presidence ne change pas toute seule : c'est la convocation du lundi qui ouvrira le
--     scrutin, pas la protestation d'un depute.
--
-- CE QU'IL PROUVE -- L'AUTORITE DES PARTIS, et c'est la faille de la deuxieme passe :
--   . un depute ne s'inscrit PLUS seul dans le parti d'un depute sanctionne pour devenir
--     « protestataire qualifie » ;
--   . il ne se pose pas non plus une invitation pour contourner la garde ;
--   . il n'exclut personne, et il ne prend pas la direction du parti -- meme en forgeant une
--     election interne, car la direction ne passe qu'a un MEMBRE deja present ;
--   . le chef, lui, fait entrer qui il veut ; on quitte un parti quand on veut ; et une adhesion
--     INVITEE par le chef passe ;
--   . une organisation NON politique reste libre -- aucune regression ailleurs ;
--   . et le SERVEUR passe toujours : la cotisation nocturne retire un membre qui n'a pas paye, et
--     elle ne doit pas tomber chaque nuit.
--
-- Usage : coller ce fichier dans un execute_sql. Il doit finir sur
--   ERROR: banc troisieme passe : LES 37 EPREUVES SONT VERTES. -- rien ne doit rester

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
  MAY_U   text := '3d91b1fa-a22d-41ae-82cf-fef98194b10a'; MAY   text := 'May';
  BART_U  text := '0d119ada-f6e4-4c8c-bc8d-34e57de6115f'; BART  text := 'Bartesto Chevara';
  v jsonb; n integer := 0; ko integer := 0; v_echecs text := '';
  v_n integer; v_pop numeric; v_pop2 numeric; v_c1 timestamptz; v_c2 timestamptz;
BEGIN
  PERFORM pg_temp.je_suis_le_serveur();

  -- ===========================================================================================
  -- DECOR : SIX DEPUTES JOUEURS, UNE PRESIDENCE AU REGISTRE
  -- ===========================================================================================
  INSERT INTO public.postes_attribues (id, country, poste_id, city, titulaire, source)
  VALUES ('banc-presidence-an', 'republic', 'president_assemblee', NULL, ARNIE, 'banc');
  UPDATE public.cycles_electoraux SET data = '{"elus":["Lee Capene","Marsault","Phileas Frogg"]}'
   WHERE country = 'republic' AND poste_id = 'depute' AND city = 'capitale';
  UPDATE public.cycles_electoraux SET data = '{"elus":["Ben","May","Bartesto Chevara"]}'
   WHERE country = 'republic' AND poste_id = 'depute' AND city = 'ville_a';
  -- LE PRESIDENT EST L'UN DES NEUF, ET LE DECOR DOIT LE RESPECTER (correctif du 11 octobre 2026).
  -- Arnie recoit un siege a Montrouge : depuis que `assemblee_president` derive la presidence des
  -- neuf, un President sans mandat ne preside RIEN -- et c'est exactement l'invariant voulu. Ce
  -- banc forgeait auparavant un President hors de l'Assemblee, un etat que l'arbitrage interdit.
  UPDATE public.cycles_electoraux SET data = '{"elus":["Arnie"]}'
   WHERE country = 'republic' AND poste_id = 'depute' AND city = 'ville_b';
  UPDATE public.personnages_donnees
     SET poste_depute = jsonb_build_object('id', 'depute', 'city', 'ville_b')
   WHERE name = ARNIE;
  UPDATE public.personnages_donnees SET poste_depute = jsonb_build_object('id','depute','city','capitale')
   WHERE name IN (LEE, MARS, PHIL);
  UPDATE public.personnages_donnees SET poste_depute = jsonb_build_object('id','depute','city','ville_a')
   WHERE name IN (BEN, MAY, BART);
  UPDATE public.personnages_donnees
     SET current_city='capitale', current_building='assemblee', current_room='hemicycle',
         resources = jsonb_set(coalesce(resources,'{}'::jsonb), '{pop}', '50'::jsonb)
   WHERE name IN (ARNIE, LEE, MARS, PHIL, BEN, MAY, BART);

  -- ===========================================================================================
  -- A. LA SUSPENSION PRESIDENTIELLE PERSISTE JUSQU'A LA REPRISE
  -- ===========================================================================================
  n := n + 1;   -- UN DEPUTE NE SUSPEND PAS LA SEANCE.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.assemblee_suspendre_seance('Je decide.', 'rq-banc4-usurpe-01');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'pas_le_president' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE1 un depute a suspendu : ' || v::text; END IF;

  n := n + 1;   -- LE PRESIDENT SUSPEND : -20 POP, ET L'ETAT RESTE OUVERT.
  SELECT (resources->>'pop')::numeric INTO v_pop FROM public.personnages_donnees WHERE name = ARNIE;
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.assemblee_suspendre_seance('Le calme ne revient pas.', 'rq-banc4-susp-01');
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT (resources->>'pop')::numeric INTO v_pop2 FROM public.personnages_donnees WHERE name = ARNIE;
  IF v->>'ok' <> 'true' OR v->>'ouverte' <> 'true' OR v_pop2 <> v_pop - 20
     OR NOT public.assemblee_suspendue_par_la_presidence('republic') THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE2 suspension : pop ' || v_pop || ' -> ' || v_pop2
      || ' / ' || v::text; END IF;

  n := n + 1;   -- ON NE SUSPEND PAS DEUX FOIS : ce serait payer deux fois le meme etat.
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.assemblee_suspendre_seance('Encore.', 'rq-banc4-susp-02');
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT (resources->>'pop')::numeric INTO v_pop FROM public.personnages_donnees WHERE name = ARNIE;
  IF coalesce(v->>'raison','') <> 'deja_suspendue' OR v_pop <> v_pop2 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE3 double suspension : ' || v::text
      || ' / pop ' || v_pop2 || ' -> ' || v_pop; END IF;

  n := n + 1;   -- PENDANT LA SUSPENSION : ON NE DEMANDE PAS LA PAROLE.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.assemblee_parole_demander();
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'seance_suspendue' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE4 demande de parole pendant la suspension : ' || v::text; END IF;

  n := n + 1;   -- NI ON NE LA DONNE.
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.assemblee_parole_donner(LEE);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'seance_suspendue' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE5 parole donnee pendant la suspension : ' || v::text; END IF;

  n := n + 1;   -- NI LE PRESIDENT LUI-MEME NE PARLE : il a « Reprendre la seance » pour cela.
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.assemblee_debat_dire('Je reprends la main.', 'rq-banc4-dire-01');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'seance_suspendue' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE6 le President a parle pendant la suspension : ' || v::text; END IF;

  n := n + 1;   -- ET LA POLICE DE SEANCE NE S'EXERCE PAS SUR UNE SEANCE QUI NE SIEGE PAS.
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.assemblee_rappeler(LEE, 'Pendant la suspension.', 'rq-banc4-rap-01');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'seance_suspendue' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE7 rappel pendant la suspension : ' || v::text; END IF;
  n := n + 1;
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.assemblee_sanctionner(LEE, 'Pendant la suspension.', 'rq-banc4-san-01');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'seance_suspendue' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE8 sanction pendant la suspension : ' || v::text; END IF;

  n := n + 1;   -- MAIS QUITTER L'HEMICYCLE RESTE POSSIBLE : acte PHYSIQUE, et une suspension
  --              n'enferme personne.
  PERFORM pg_temp.je_suis(BART_U);
  v := public.assemblee_protester();
  PERFORM pg_temp.je_suis_le_serveur();
  IF v->>'ok' <> 'true' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE9 la suspension empeche de sortir : ' || v::text; END IF;
  n := n + 1;
  PERFORM pg_temp.je_suis(BART_U);
  v := public.assemblee_revenir();
  PERFORM pg_temp.je_suis_le_serveur();
  IF v->>'ok' <> 'true' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE10 la suspension empeche de rentrer : ' || v::text; END IF;

  n := n + 1;   -- ELLE N'EST PAS UN BOYCOTT : le depouillement du mercredi ne la voit pas.
  IF public.assemblee_suspendue('republic') THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE11 la suspension presidentielle passe pour un boycott'; END IF;

  n := n + 1;   -- ET ELLE NE REPORTE AUCUN SCRUTIN : regle NON arbitree, donc NON inventee.
  INSERT INTO public.assemblee_propositions
    (id, country, auteur, titre, type, texte_original, statut, session_num,
     eligible_session_ts, session_ouverte_ts, cloture_ts)
  VALUES ('banc4-echu', 'republic', LEE, 'Texte echu', 'rp', 'Corps.', 'session', 1,
          now() - interval '14 days', now() - interval '7 days', now() - interval '1 hour');
  SELECT cloture_ts INTO v_c1 FROM public.assemblee_propositions WHERE id = 'banc4-echu';
  v := public.assemblee_reporter_si_suspendue('republic');
  SELECT cloture_ts INTO v_c2 FROM public.assemblee_propositions WHERE id = 'banc4-echu';
  IF v->>'suspendue' <> 'false' OR (v->>'reportes')::int <> 0 OR v_c2 <> v_c1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE12 la suspension presidentielle a reporte un scrutin : '
      || v::text; END IF;

  n := n + 1;   -- UN DEPUTE NE REPREND PAS LA SEANCE.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.assemblee_reprendre_seance('rq-banc4-rep-usurpe');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'pas_le_president' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE13 un depute a repris la seance : ' || v::text; END IF;

  n := n + 1;   -- LE PRESIDENT REPREND, ET CELA NE COUTE RIEN.
  SELECT (resources->>'pop')::numeric INTO v_pop FROM public.personnages_donnees WHERE name = ARNIE;
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.assemblee_reprendre_seance('rq-banc4-rep-01');
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT (resources->>'pop')::numeric INTO v_pop2 FROM public.personnages_donnees WHERE name = ARNIE;
  IF v->>'ok' <> 'true' OR v_pop2 <> v_pop
     OR public.assemblee_suspendue_par_la_presidence('republic') THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE14 reprise : pop ' || v_pop || ' -> ' || v_pop2
      || ' / ' || v::text; END IF;

  n := n + 1;   -- ET LA PAROLE REVIENT.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.assemblee_parole_demander();
  PERFORM pg_temp.je_suis_le_serveur();
  IF v->>'ok' <> 'true' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE15 la parole ne revient pas apres la reprise : ' || v::text; END IF;

  n := n + 1;   -- UN REJEU DE LA REPRISE N'EST PAS UN FAUX REFUS.
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.assemblee_reprendre_seance('rq-banc4-rep-01');
  PERFORM pg_temp.je_suis_le_serveur();
  IF v->>'rejeu' <> 'true' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE16 rejeu de la reprise : ' || v::text; END IF;

  n := n + 1;   -- ELLE NE COMPTE PAS DANS LES EPISODES DE BOYCOTT.
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.assemblee_seance(5);
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v->>'episodes_sous_cette_presidence')::int <> 0 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE17 la suspension presidentielle compte comme episode : '
      || coalesce(v->>'episodes_sous_cette_presidence','?'); END IF;

  -- ===========================================================================================
  -- B. LE DEUXIEME BOYCOTT DISTINCT REMET LA PRESIDENCE EN JEU
  -- ===========================================================================================
  DELETE FROM public.assemblee_paroles WHERE pays = 'republic';
  INSERT INTO public.organisations (id, country_origine, data) VALUES
   ('banc-parti', 'republic',
    '{"id":"banc-parti","type":"politique","nom":"Union du Banc","country":"republic",'
    || '"chef":"Lee Capene","fondateur":"Lee Capene","membres":['
    || '{"nom":"Lee Capene"},{"nom":"Marsault"},{"nom":"Phileas Frogg"},{"nom":"Ben"},'
    || '{"nom":"May"}],"invitationsEnvoyees":[],"demandesAdhesion":[]}');

  PERFORM pg_temp.je_suis(ARNIE_U);
  PERFORM public.assemblee_rappeler(LEE, 'Vous criez sans la parole.', 'rq-banc4-rappel-01');
  PERFORM pg_temp.je_suis_le_serveur();

  n := n + 1;   -- CINQ QUALIFIES : PREMIER EPISODE, ET AUCUNE ELECTION DUE.
  PERFORM pg_temp.je_suis(LEE_U);  PERFORM public.assemblee_protester();
  PERFORM pg_temp.je_suis(MARS_U); PERFORM public.assemblee_protester();
  PERFORM pg_temp.je_suis(PHIL_U); PERFORM public.assemblee_protester();
  PERFORM pg_temp.je_suis(BEN_U);  PERFORM public.assemblee_protester();
  PERFORM pg_temp.je_suis(MAY_U);  v := public.assemblee_protester();
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT count(*) INTO v_n FROM public.assemblee_presidence_dues u
   WHERE u.pays='republic' AND u.honore_le IS NULL;
  IF (v->'seance'->>'suspendue') <> 'true' OR v_n <> 0 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE18 premier episode : ' || (v->'seance')::text
      || ' / ' || v_n || ' election(s) due(s)'; END IF;

  n := n + 1;   -- 5 -> 4 -> 5 : MEME EPISODE.
  PERFORM pg_temp.je_suis(MAY_U); PERFORM public.assemblee_revenir();
  PERFORM pg_temp.je_suis(MAY_U); v := public.assemblee_protester();
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT count(*) INTO v_n FROM public.assemblee_suspensions s
   WHERE s.pays='republic' AND s.cause='boycott';
  IF v_n <> 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE19 un aller-retour a fabrique un episode : ' || v_n; END IF;

  n := n + 1;   -- ET DONC AUCUNE ELECTION : un depute seul ne remet pas la presidence en jeu.
  SELECT count(*) INTO v_n FROM public.assemblee_presidence_dues u
   WHERE u.pays='republic' AND u.honore_le IS NULL;
  IF v_n <> 0 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE20 un aller-retour a declenche une election : ' || v_n; END IF;

  n := n + 1;   -- 5 -> 3 -> 1 -> 5 : TOUJOURS LE MEME EPISODE.
  PERFORM pg_temp.je_suis(MAY_U);  PERFORM public.assemblee_revenir();
  PERFORM pg_temp.je_suis(BEN_U);  PERFORM public.assemblee_revenir();
  PERFORM pg_temp.je_suis(PHIL_U); PERFORM public.assemblee_revenir();
  PERFORM pg_temp.je_suis(MARS_U); PERFORM public.assemblee_revenir();
  PERFORM pg_temp.je_suis(MARS_U); PERFORM public.assemblee_protester();
  PERFORM pg_temp.je_suis(PHIL_U); PERFORM public.assemblee_protester();
  PERFORM pg_temp.je_suis(BEN_U);  PERFORM public.assemblee_protester();
  PERFORM pg_temp.je_suis(MAY_U);  PERFORM public.assemblee_protester();
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT count(*) INTO v_n FROM public.assemblee_suspensions s
   WHERE s.pays='republic' AND s.cause='boycott';
  IF v_n <> 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE21 5-3-1-5 a fabrique un episode : ' || v_n; END IF;

  n := n + 1;   -- RETOUR A ZERO : L'EPISODE EST TERMINE.
  PERFORM pg_temp.je_suis(LEE_U);  PERFORM public.assemblee_revenir();
  PERFORM pg_temp.je_suis(MARS_U); PERFORM public.assemblee_revenir();
  PERFORM pg_temp.je_suis(PHIL_U); PERFORM public.assemblee_revenir();
  PERFORM pg_temp.je_suis(BEN_U);  PERFORM public.assemblee_revenir();
  PERFORM pg_temp.je_suis(MAY_U);  PERFORM public.assemblee_revenir();
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT count(*) INTO v_n FROM public.assemblee_protestations p WHERE p.pays='republic';
  IF v_n <> 0 OR public.assemblee_suspendue('republic') THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE22 la dissolution est incomplete : ' || v_n; END IF;

  n := n + 1;   -- ET UN NOUVEAU MOUVEMENT A CINQ : DEUXIEME EPISODE, ELECTION DUE.
  PERFORM pg_temp.je_suis(LEE_U);  PERFORM public.assemblee_protester();
  PERFORM pg_temp.je_suis(MARS_U); PERFORM public.assemblee_protester();
  PERFORM pg_temp.je_suis(PHIL_U); PERFORM public.assemblee_protester();
  PERFORM pg_temp.je_suis(BEN_U);  PERFORM public.assemblee_protester();
  PERFORM pg_temp.je_suis(MAY_U);  v := public.assemblee_protester();
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT count(*) INTO v_n FROM public.assemblee_suspensions s
   WHERE s.pays='republic' AND s.cause='boycott';
  IF v_n <> 2 OR (v->'seance'->>'election_presidentielle_due') <> 'true' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE23 second episode : ' || v_n || ' episode(s) / '
      || (v->'seance')::text; END IF;

  n := n + 1;   -- UNE SEULE ELECTION DUE, et la cause est nommee.
  SELECT count(*) INTO v_n FROM public.assemblee_presidence_dues u
   WHERE u.pays='republic' AND u.honore_le IS NULL AND u.cause='deux_boycotts';
  IF v_n <> 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE24 ' || v_n || ' election(s) due(s) au lieu de 1'; END IF;

  n := n + 1;   -- L'ETAT DE SEANCE LE REND COMME UN FAIT.
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.assemblee_seance(5);
  PERFORM pg_temp.je_suis_le_serveur();
  IF v->>'election_presidentielle_due' <> 'true'
     OR (v->>'episodes_sous_cette_presidence')::int <> 2 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE25 l etat de seance ne rend pas l election due : '
      || v::text; END IF;

  n := n + 1;   -- LES SIX DEPUTES RESTENT ELIGIBLES. Ce n'est pas une ineligibilite : un
  --              President sortant qui est depute peut se presenter de nouveau.
  SELECT count(*) INTO v_n FROM public.assemblee_presidence_eligibles('republic') e
   WHERE e.depute IN (LEE, MARS, PHIL, BEN, MAY, BART);
  IF v_n <> 6 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE26 ' || v_n || ' des six deputes eligibles'; END IF;

  n := n + 1;   -- ET LA PRESIDENCE N'A PAS CHANGE TOUTE SEULE : c'est la convocation du lundi qui
  --              ouvrira le scrutin, pas la protestation d'un depute.
  IF public.assemblee_president('republic') IS DISTINCT FROM ARNIE THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE27 la presidence a change hors election : '
      || coalesce(public.assemblee_president('republic'),'(vacante)'); END IF;

  -- ===========================================================================================
  -- C. ON N'ENTRE PAS DANS UN PARTI SANS QUE SON CHEF L'AIT VOULU
  -- ===========================================================================================
  n := n + 1;   -- L'ATTAQUE DE LA DEUXIEME PASSE : un depute s'inscrit dans le parti d'un
  --              sanctionne pour devenir protestataire qualifie. ELLE EST FERMEE.
  BEGIN
    PERFORM pg_temp.je_suis(BART_U);
    UPDATE public.organisations SET data = (data::jsonb || jsonb_build_object('membres',
      (data::jsonb -> 'membres') || jsonb_build_array(jsonb_build_object('nom', BART))))::text
     WHERE id = 'banc-parti';
    ko := ko + 1; v_echecs := v_echecs || E'\nE28 un depute s est inscrit seul dans un parti';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.je_suis_le_serveur();

  n := n + 1;   -- ET IL NE SE POSE PAS UNE INVITATION POUR CONTOURNER LA GARDE. Sans cette
  --              seconde moitie, la premiere ne vaudrait rien.
  BEGIN
    PERFORM pg_temp.je_suis(BART_U);
    UPDATE public.organisations SET data = (data::jsonb || jsonb_build_object('invitationsEnvoyees',
      jsonb_build_array(jsonb_build_object('nom', BART))))::text
     WHERE id = 'banc-parti';
    ko := ko + 1; v_echecs := v_echecs || E'\nE29 un depute s est invite lui-meme';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.je_suis_le_serveur();

  n := n + 1;   -- IL N'EXCLUT PAS UN MEMBRE.
  BEGIN
    PERFORM pg_temp.je_suis(BART_U);
    UPDATE public.organisations SET data = (data::jsonb || jsonb_build_object('membres',
      (SELECT coalesce(jsonb_agg(m), '[]'::jsonb) FROM jsonb_array_elements(data::jsonb -> 'membres') m
        WHERE m ->> 'nom' <> MAY)))::text
     WHERE id = 'banc-parti';
    ko := ko + 1; v_echecs := v_echecs || E'\nE30 un etranger a exclu un membre';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.je_suis_le_serveur();

  n := n + 1;   -- ET IL NE PREND PAS LA DIRECTION DU PARTI.
  BEGIN
    PERFORM pg_temp.je_suis(BART_U);
    UPDATE public.organisations SET data = (data::jsonb || jsonb_build_object('chef', BART))::text
     WHERE id = 'banc-parti';
    ko := ko + 1; v_echecs := v_echecs || E'\nE31 un etranger a pris la direction du parti';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.je_suis_le_serveur();

  n := n + 1;   -- MEME EN FORGEANT UNE ELECTION INTERNE : la direction ne va qu'a un MEMBRE. Sans
  --              cela, on se couronnerait chef d'un parti ou l'on n'est pas, puis on s'y ajouterait.
  UPDATE public.organisations SET data = (data::jsonb || jsonb_build_object('election',
    jsonb_build_object('enCours', true, 'phase', 'vote')))::text WHERE id = 'banc-parti';
  BEGIN
    PERFORM pg_temp.je_suis(BART_U);
    UPDATE public.organisations SET data = (data::jsonb || jsonb_build_object('chef', BART))::text
     WHERE id = 'banc-parti';
    ko := ko + 1; v_echecs := v_echecs || E'\nE32 une election forgee a couronne un non-membre';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.je_suis_le_serveur();

  n := n + 1;   -- LE CHEF, LUI, FAIT ENTRER QUI IL VEUT.
  PERFORM pg_temp.je_suis(LEE_U);
  UPDATE public.organisations SET data = (data::jsonb || jsonb_build_object('membres',
    (data::jsonb -> 'membres') || jsonb_build_array(jsonb_build_object('nom', BART))))::text
   WHERE id = 'banc-parti';
  PERFORM pg_temp.je_suis_le_serveur();
  IF public.assemblee_parti_de('republic', BART) IS DISTINCT FROM 'banc-parti' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE33 le chef n a pas pu faire entrer un membre'; END IF;

  n := n + 1;   -- ET ON QUITTE UN PARTI QUAND ON VEUT : personne n'y est retenu.
  PERFORM pg_temp.je_suis(BART_U);
  UPDATE public.organisations SET data = (data::jsonb || jsonb_build_object('membres',
    (SELECT coalesce(jsonb_agg(m), '[]'::jsonb) FROM jsonb_array_elements(data::jsonb -> 'membres') m
      WHERE m ->> 'nom' <> BART)))::text
   WHERE id = 'banc-parti';
  PERFORM pg_temp.je_suis_le_serveur();
  IF public.assemblee_parti_de('republic', BART) IS NOT NULL THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE34 un membre n a pas pu quitter son parti'; END IF;

  n := n + 1;   -- INVITE PAR LE CHEF, IL PEUT S'AJOUTER : le flux legitime est intact.
  PERFORM pg_temp.je_suis(LEE_U);
  UPDATE public.organisations SET data = (data::jsonb || jsonb_build_object('invitationsEnvoyees',
    jsonb_build_array(jsonb_build_object('nom', BART))))::text WHERE id = 'banc-parti';
  PERFORM pg_temp.je_suis(BART_U);
  UPDATE public.organisations SET data = (data::jsonb || jsonb_build_object('membres',
    (data::jsonb -> 'membres') || jsonb_build_array(jsonb_build_object('nom', BART))))::text
   WHERE id = 'banc-parti';
  PERFORM pg_temp.je_suis_le_serveur();
  IF public.assemblee_parti_de('republic', BART) IS DISTINCT FROM 'banc-parti' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE35 une adhesion invitee a ete refusee'; END IF;

  n := n + 1;   -- UNE ORGANISATION NON POLITIQUE RESTE LIBRE : aucune regression ailleurs. C'est
  --              ce qui rend cette correction non destructrice -- et c'est aussi la dette.
  INSERT INTO public.organisations (id, country_origine, data) VALUES
   ('banc-syndicat', 'republic',
    '{"id":"banc-syndicat","type":"syndicale","nom":"Dockers","country":"republic",'
    || '"chef":"Lee Capene","fondateur":"Lee Capene","membres":[]}');
  PERFORM pg_temp.je_suis(BART_U);
  UPDATE public.organisations SET data = (data::jsonb || jsonb_build_object('membres',
    jsonb_build_array(jsonb_build_object('nom', BART))))::text WHERE id = 'banc-syndicat';
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT count(*) INTO v_n FROM public.organisations o
   WHERE o.id = 'banc-syndicat'
     AND o.data::jsonb -> 'membres' @> jsonb_build_array(jsonb_build_object('nom', BART));
  IF v_n <> 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE36 le garde-fou a bloque une organisation non politique'; END IF;

  n := n + 1;   -- ET LE SERVEUR PASSE TOUJOURS : la cotisation nocturne retire un membre qui n'a
  --              pas paye, et elle ne doit pas tomber chaque nuit.
  UPDATE public.organisations SET data = (data::jsonb || jsonb_build_object('membres',
    (SELECT coalesce(jsonb_agg(m), '[]'::jsonb) FROM jsonb_array_elements(data::jsonb -> 'membres') m
      WHERE m ->> 'nom' <> MAY)))::text
   WHERE id = 'banc-parti';
  IF public.assemblee_parti_de('republic', MAY) IS NOT NULL THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE37 le serveur n a pas pu retirer un membre'; END IF;

  -- ===========================================================================================
  IF ko > 0 THEN
    RAISE EXCEPTION 'banc troisieme passe : % ECHEC(S) SUR % EPREUVES.%', ko, n, v_echecs;
  END IF;
  RAISE EXCEPTION 'banc troisieme passe : LES % EPREUVES SONT VERTES. -- rien ne doit rester', n;
END $banc$;
ROLLBACK;
