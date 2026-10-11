-- BANC DE LA SUCCESSION SANS VACANCE (11 octobre 2026, correctif du calendrier electoral commun)
--
-- CE BANC NE COMMITE RIEN. Il joue un mandat entier, son scrutin de succession, un second tour et
-- une alternance, et se termine par un RAISE EXCEPTION INCONDITIONNEL.
--
-- L'INVARIANT EPROUVE : une election en cours ne cree JAMAIS a elle seule une vacance du poste.
-- Le titulaire sortant garde ses pouvoirs jusqu'a l'instant exact ou le resultat definitif
-- designe son successeur, et la succession est immediate a cet instant.
--
-- CE QU'IL ATTRAPE, ET QUE RIEN N'ATTRAPAIT. L'ancien moteur remplacait le blob du cycle au
-- passage de `dateFinMandat`. Comme `poste_est_atteste` ne lit que `eluId` / `elus`, cette seule
-- ecriture faisait disparaitre le titulaire -- pendant QUATORZE JOURS, jusqu'a la proclamation du
-- successeur. Ce banc met un mandat et son scrutin de succession dans le MEME blob, et exige que
-- l'attestation tienne a tous les instants du calendrier, proclamation echue comprise.
--
-- CE QU'IL PROUVE :
--   1. un titulaire en exercice et un scrutin ouvert coexistent, et l'attestation ne depend
--      d'aucune date ;
--   2. les candidatures sont ouvertes PENDANT le mandat, et gelees a partir du lundi 00:01 de la
--      derniere semaine ;
--   3. on vote le dernier dimanche du mandat ALORS QUE le titulaire est en fonction -- c'est le
--      court-circuit « phase = mandat » qui est retire ;
--   4. aucun instant sans titulaire entre le premier et le second tour ;
--   5. aucun instant sans titulaire entre deux mandats : la succession est UNE ecriture ;
--   6. les neuf deputes sont remplaces simultanement, et la presidence sortante tombe au meme
--      instant ;
--   7. seuls les neuf entrants sont eligibles a la presidence suivante ;
--   8. un electeur du premier tour peut voter au SECOND -- defaut prealable, ferme par le tour
--      dans la cle du bulletin ;
--   9. la consignation garde sur `dateResultats` : un rejeu ne proclame pas deux fois ;
--  10. le casting PNJ des neuf sieges est celui de l'hemicycle, dans l'ordre des rangs ;
--  11. les cycles vivants sont tous sortis de l'ancien contrat ;
--  12. l'estampille du scrutin ne vient JAMAIS du client, meme quand le cycle est muet.
--
-- Usage : coller ce fichier dans un execute_sql. Il doit finir sur
--   ERROR: banc succession : LES 36 EPREUVES SONT VERTES. -- rien ne doit rester

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
  LEE_U   text := 'ea4a2a0c-a192-4e10-8cff-d5db9b1cceb6'; LEE   text := 'Lee Capene';
  MARS_U  text := 'a5a55fc8-64fa-4406-b617-76439d1d4aac'; MARS  text := 'Marsault';
  PHIL_U  text := '0821bcdf-0c69-4ba3-adcd-f60d9b82b7bf'; PHIL  text := 'Phileas Frogg';
  BEN_U   text := 'bafc96b1-1628-4ae2-93d2-78d89f8ac5b5'; BEN   text := 'Ben';
  MAY_U   text := '3d91b1fa-a22d-41ae-82cf-fef98194b10a'; MAY   text := 'May';
  BART_U  text := '0d119ada-f6e4-4c8c-bc8d-34e57de6115f'; BART  text := 'Bartesto Chevara';
  LAROCHE text := 'President Laroche';
  v jsonb; n integer := 0; ko integer := 0; v_echecs text := '';
  v_n integer; v_txt text; v_big bigint;
  -- LE CALENDRIER DU MANDAT, EN HEURE MURALE DE PARIS. Mandat du lundi 2026-09-28 00:00 au lundi
  -- 2026-11-02 00:00 : cinq semaines, gel au lundi 2026-10-26 00:01, vote le dimanche
  -- 2026-11-01 00:01. Ce sont exactement les valeurs que `calendrierSuccession` rend pour ce
  -- mandat, et le banc JavaScript les verifie de son cote.
  MS_DEBUT numeric := floor(extract(epoch FROM (timestamp '2026-09-28 00:00' AT TIME ZONE 'Europe/Paris')) * 1000);
  MS_GEL   numeric := floor(extract(epoch FROM (timestamp '2026-10-26 00:01' AT TIME ZONE 'Europe/Paris')) * 1000);
  MS_VOTE  numeric := floor(extract(epoch FROM (timestamp '2026-11-01 00:01' AT TIME ZONE 'Europe/Paris')) * 1000);
  MS_FIN   numeric := floor(extract(epoch FROM (timestamp '2026-11-02 00:00' AT TIME ZONE 'Europe/Paris')) * 1000);
  v_maintenant numeric := floor(extract(epoch FROM now()) * 1000);
  v_blob jsonb;
BEGIN
  PERFORM pg_temp.je_suis_le_serveur();

  -- ===========================================================================================
  -- DECOR : UN MANDAT EN EXERCICE, ET SON SCRUTIN DE SUCCESSION DEJA OUVERT
  -- ===========================================================================================
  -- LES CYCLES D'ABORD, LES FICHES ENSUITE : le declencheur d'attestation annulerait en silence
  -- un poste_depute que `cycles_electoraux` ne confirme pas.
  --
  -- LE BLOB PORTE LES DEUX CHOSES A LA FOIS, et c'est tout l'objet du correctif : `elus` atteste
  -- le mandat en exercice, les dates decrivent l'election de sa succession. Les candidatures sont
  -- ouvertes parce que `dateDebutCampagne` -- le gel -- est devant nous.
  v_blob := jsonb_build_object(
    'posteId', 'depute', 'city', 'capitale',
    'elus', jsonb_build_array(LEE, MARS, PHIL),
    'dateDebutMandatTs', MS_DEBUT,
    'phase', 'candidatures', 'tour', 1,
    'candidats', '[]'::jsonb, 'votes', '{}'::jsonb, 'votesPNJ', '{}'::jsonb,
    'dateDebutCandidatures', MS_DEBUT,
    'dateDebutCampagne', v_maintenant + 86400000,   -- le gel est demain : candidatures ouvertes
    'dateVote', v_maintenant + 2 * 86400000,
    'dateResultats', v_maintenant + 3 * 86400000,
    'dateFinMandat', v_maintenant + 3 * 86400000,
    'resultatsTraites', false);
  UPDATE public.cycles_electoraux SET data = v_blob::text
   WHERE country='republic' AND poste_id='depute' AND city='capitale';
  UPDATE public.cycles_electoraux SET data = jsonb_build_object('elus', jsonb_build_array(BEN, MAY, BART),
    'phase','candidatures','dateResultats', v_maintenant + 3*86400000, 'resultatsTraites', false)::text
   WHERE country='republic' AND poste_id='depute' AND city='ville_a';

  UPDATE public.personnages_donnees SET poste_depute = jsonb_build_object('id','depute','city','capitale'),
         domicile = jsonb_build_object('country','republic')
   WHERE name IN (LEE, MARS, PHIL);
  UPDATE public.personnages_donnees SET poste_depute = jsonb_build_object('id','depute','city','ville_a'),
         domicile = jsonb_build_object('country','republic')
   WHERE name IN (BEN, MAY, BART);

  DELETE FROM public.postes_attribues
   WHERE country='republic' AND poste_id='president_assemblee' AND city IS NULL;
  INSERT INTO public.postes_attribues (id, country, poste_id, city, titulaire, source)
  VALUES ('bancsucc-presidence', 'republic', 'president_assemblee', NULL, LEE, 'banc');

  -- ===========================================================================================
  -- 1. UN MANDAT ET UN SCRUTIN COEXISTENT
  -- ===========================================================================================
  n := n + 1;   -- E1 : les six deputes joueurs sont attestes.
  SELECT count(*) INTO v_n FROM public.assemblee_occupation_sieges('republic') o WHERE NOT o.est_pnj;
  IF v_n <> 6 THEN ko := ko + 1; v_echecs := v_echecs || E'\nE1 ' || v_n || ' sieges PJ sur 6'; END IF;

  n := n + 1;   -- E2 : et le President preside, parce qu'il est l'un des neuf.
  IF public.assemblee_president('republic') IS DISTINCT FROM LEE THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE2 le President en exercice ne preside pas'; END IF;

  n := n + 1;   -- E3 : L'ATTESTATION NE DEPEND D'AUCUNE DATE. On met la proclamation DANS LE
  --              PASSE -- l'etat exact ou le cron n'a pas encore tourne -- et les six restent
  --              deputes. C'est l'instant que l'ancien moteur transformait en vacance.
  UPDATE public.cycles_electoraux
     SET data = (data::jsonb || jsonb_build_object('dateResultats', v_maintenant - 3600000,
                                                   'dateFinMandat', v_maintenant - 3600000))::text
   WHERE country='republic' AND poste_id='depute';
  SELECT count(*) INTO v_n FROM public.assemblee_occupation_sieges('republic') o WHERE NOT o.est_pnj;
  IF v_n <> 6 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE3 ' || v_n || ' sieges PJ apres echeance : le mandat a expire tout seul'; END IF;

  n := n + 1;   -- E4 : et la presidence tient aussi -- aucune fenetre sans President.
  IF public.assemblee_president('republic') IS DISTINCT FROM LEE THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE4 la presidence a chute a l echeance, avant tout successeur'; END IF;

  n := n + 1;   -- E5 : poste_est_atteste, la source d'autorite, dit la meme chose.
  IF NOT public.poste_est_atteste(LEE, jsonb_build_object('id','depute','city','capitale'), 'republic') THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE5 l attestation refuse un titulaire en exercice'; END IF;

  -- on remet la proclamation devant nous pour la suite
  UPDATE public.cycles_electoraux
     SET data = (data::jsonb || jsonb_build_object('dateResultats', v_maintenant + 3 * 86400000,
                                                   'dateFinMandat', v_maintenant + 3 * 86400000))::text
   WHERE country='republic' AND poste_id='depute';

  -- ===========================================================================================
  -- 2. LES CANDIDATURES SONT OUVERTES PENDANT LE MANDAT, ET GELEES LA DERNIERE SEMAINE
  -- ===========================================================================================
  n := n + 1;   -- E6 : UNE CANDIDATURE EST ACCEPTEE ALORS QU'UN TITULAIRE EST EN FONCTION.
  --              L'ancien declencheur refusait `candidatures_closes` pendant tout le mandat.
  DELETE FROM public.candidatures WHERE id LIKE 'bancsucc-%';
  BEGIN
    INSERT INTO public.candidatures (id, country, poste_id, city, nom, created_at)
    VALUES ('bancsucc-c1', 'republic', 'depute', 'capitale', BEN, now());
  EXCEPTION WHEN OTHERS THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE6 candidature refusee pendant le mandat : ' || SQLERRM;
  END;

  n := n + 1;   -- E7 : et elle est ESTAMPILLEE du scrutin, par le serveur.
  -- UN bigint, PAS UN integer : une estampille est un epoch en millisecondes. La premiere
  -- version de cette epreuve levait « integer out of range » -- et un banc qui plante n'eprouve
  -- rien.
  SELECT cle_scrutin INTO v_big FROM public.candidatures WHERE id = 'bancsucc-c1';
  IF v_big IS DISTINCT FROM MS_DEBUT::bigint THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE7 cle_scrutin = ' || coalesce(v_big::text,'NULL')
      || ' au lieu de ' || MS_DEBUT::bigint::text; END IF;

  n := n + 1;   -- E8 : APRES LE GEL, ELLE EST REFUSEE. On avance le gel dans le passe.
  UPDATE public.cycles_electoraux
     SET data = (data::jsonb || jsonb_build_object('dateDebutCampagne', v_maintenant - 60000))::text
   WHERE country='republic' AND poste_id='depute' AND city='capitale';
  BEGIN
    INSERT INTO public.candidatures (id, country, poste_id, city, nom, created_at)
    VALUES ('bancsucc-c2', 'republic', 'depute', 'capitale', MAY, now());
    ko := ko + 1; v_echecs := v_echecs || E'\nE8 une candidature est passee apres le gel';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%candidatures_closes%' THEN
      ko := ko + 1; v_echecs := v_echecs || E'\nE8 refus pour le mauvais motif : ' || SQLERRM; END IF;
  END;

  n := n + 1;   -- E9 : la candidature deja deposee RESTE valide -- le gel fige, il n'annule pas.
  SELECT count(*) INTO v_n FROM public.candidatures WHERE id = 'bancsucc-c1';
  IF v_n <> 1 THEN ko := ko + 1; v_echecs := v_echecs || E'\nE9 le gel a efface une candidature deja deposee'; END IF;

  -- ===========================================================================================
  -- 3. ON VOTE LE DERNIER DIMANCHE, ALORS QUE LE TITULAIRE EST EN FONCTION
  -- ===========================================================================================
  -- C'EST LA REGRESSION LA PLUS DIRECTE DU CORRECTIF. `election_voter` refusait
  -- « vote_ferme / phase = mandat » des qu'un titulaire existait : sous le nouveau calendrier,
  -- un titulaire existe TOUJOURS, donc plus personne n'aurait jamais pu voter.
  UPDATE public.cycles_electoraux
     SET data = (data::jsonb || jsonb_build_object(
           'phase', 'candidatures',
           'candidats', jsonb_build_array(jsonb_build_object('nom', BEN), jsonb_build_object('nom', MAY)),
           'dateVote', v_maintenant - 3600000,
           'dateResultats', v_maintenant + 3600000))::text
   WHERE country='republic' AND poste_id='depute' AND city='capitale';

  n := n + 1;   -- E10 : le bulletin passe.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.election_voter('republic', 'depute', 'capitale', BEN);
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE10 vote refuse malgre la fenetre ouverte : ' || coalesce(v ->> 'raison','?'); END IF;

  n := n + 1;   -- E11 : il porte son TOUR.
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT count(*) INTO v_n FROM public.votes_electoraux
   WHERE votant = LEE AND poste_id = 'depute' AND city = 'capitale'
     AND tour = (v_maintenant - 3600000)::bigint;
  IF v_n <> 1 THEN ko := ko + 1; v_echecs := v_echecs || E'\nE11 le bulletin ne porte pas son tour'; END IF;

  n := n + 1;   -- E12 : un second bulletin du MEME electeur au MEME tour est refuse.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.election_voter('republic', 'depute', 'capitale', MAY);
  IF coalesce(v ->> 'raison','') <> 'deja_vote' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE12 double vote au meme tour : ' || coalesce(v ->> 'raison','ACCEPTE'); END IF;

  n := n + 1;   -- E13 : HORS FENETRE, LE VOTE EST REFUSE -- la borne n'a pas bouge.
  PERFORM pg_temp.je_suis_le_serveur();
  UPDATE public.cycles_electoraux
     SET data = (data::jsonb || jsonb_build_object('dateVote', v_maintenant + 86400000,
                                                   'dateResultats', v_maintenant + 2 * 86400000))::text
   WHERE country='republic' AND poste_id='depute' AND city='capitale';
  PERFORM pg_temp.je_suis(MARS_U);
  v := public.election_voter('republic', 'depute', 'capitale', BEN);
  IF coalesce(v ->> 'raison','') <> 'vote_ferme' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE13 vote accepte avant l ouverture : ' || coalesce(v ->> 'raison','ACCEPTE'); END IF;

  -- ===========================================================================================
  -- 4. ENTRE LE PREMIER ET LE SECOND TOUR, LE TITULAIRE RESTE EN FONCTION
  -- ===========================================================================================
  -- Le second tour tel que le moteur le pose : memes `elus`, meme `dateDebutMandatTs`, tour 2,
  -- bulletins remis a zero, et un calendrier decale d'une semaine. LE MANDAT EST PROLONGE.
  PERFORM pg_temp.je_suis_le_serveur();
  UPDATE public.cycles_electoraux
     SET data = (data::jsonb || jsonb_build_object(
           'tour', 2, 'phase', 'second_tour',
           'votes', '{}'::jsonb, 'votesPNJ', '{}'::jsonb,
           -- UN AUTRE `dateVote` QUE LE PREMIER TOUR, et c'est le point de l'epreuve E16 : c'est
           -- lui qui entre dans la cle du bulletin. Avec la meme valeur, le second tour serait le
           -- meme tour, et le refus serait vert pour la mauvaise raison.
           'dateVote', v_maintenant - 1800000,
           'dateResultats', v_maintenant + 3600000,
           'dateFinMandat', v_maintenant + 3600000))::text
   WHERE country='republic' AND poste_id='depute' AND city='capitale';

  n := n + 1;   -- E14 : les six deputes sont TOUJOURS attestes pendant le second tour.
  SELECT count(*) INTO v_n FROM public.assemblee_occupation_sieges('republic') o WHERE NOT o.est_pnj;
  IF v_n <> 6 THEN ko := ko + 1; v_echecs := v_echecs || E'\nE14 ' || v_n || ' sieges PJ pendant le second tour'; END IF;

  n := n + 1;   -- E15 : et la presidence aussi.
  IF public.assemblee_president('republic') IS DISTINCT FROM LEE THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE15 la presidence tombe pendant un second tour'; END IF;

  n := n + 1;   -- E16 : UN ELECTEUR DU PREMIER TOUR PEUT VOTER AU SECOND. C'etait impossible
  --               avant : la cle du bulletin ne portait pas le tour, et le blob remettait `votes`
  --               a zero sans effacer la ligne. Personne n'a jamais pu voter a un second tour.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.election_voter('republic', 'depute', 'capitale', MAY);
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE16 vote au second tour refuse : ' || coalesce(v ->> 'raison','?'); END IF;

  -- ===========================================================================================
  -- 5. LA SUCCESSION EST UNE SEULE ECRITURE, ET ELLE EST IMMEDIATE
  -- ===========================================================================================
  -- C'est exactement ce que fait le moteur a la proclamation : il remplace `elus` et rouvre le
  -- scrutin suivant, DANS LE MEME BLOB. Trois nouveaux deputes a Luthecia.
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT data::jsonb INTO v_blob FROM public.cycles_electoraux
   WHERE country='republic' AND poste_id='depute' AND city='capitale';

  n := n + 1;   -- E17 : la consignation accepte, parce qu'elle est pointee sur la dateResultats lue.
  v := public.election_resultats_consigner(
         'republic_depute_capitale',
         v_blob || jsonb_build_object(
           'elus', jsonb_build_array(BEN, MAY, BART),
           'dateDebutMandatTs', v_maintenant + 3600000,
           'tour', 1, 'phase', 'candidatures',
           'candidats', '[]'::jsonb, 'votes', '{}'::jsonb, 'votesPNJ', '{}'::jsonb,
           'dateDebutCandidatures', v_maintenant + 3600000,
           'dateDebutCampagne', v_maintenant + 10 * 86400000,
           'dateVote', v_maintenant + 16 * 86400000,
           'dateResultats', v_maintenant + 17 * 86400000,
           'dateFinMandat', v_maintenant + 17 * 86400000,
           'resultatsTraites', false),
         NULL, NULL, (v_blob ->> 'dateResultats')::numeric);
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE17 la proclamation a ete refusee : ' || coalesce(v ->> 'raison','?'); END IF;

  n := n + 1;   -- E18 : UN REJEU NE PROCLAME PAS DEUX FOIS. La garde porte sur `dateResultats`,
  --               que la proclamation vient de faire avancer.
  v := public.election_resultats_consigner(
         'republic_depute_capitale', v_blob, NULL, NULL,
         (v_blob ->> 'dateResultats')::numeric);
  IF coalesce(v ->> 'raison','') <> 'deja_traite' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE18 rejeu accepte : ' || coalesce(v ->> 'raison','ACCEPTE'); END IF;

  n := n + 1;   -- E19 : LES TROIS SORTANTS DE LUTHECIA NE SONT PLUS DEPUTES. Leur fiche porte
  --               encore `poste_depute`, perime : s'il faisait autorite, ils siegeraient encore.
  SELECT count(*) INTO v_n FROM public.personnages_donnees
   WHERE name IN (LEE, MARS, PHIL) AND poste_depute IS NOT NULL;
  IF v_n <> 3 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE19 premisse cassee : ' || v_n || ' fiches perimees sur 3'; END IF;
  n := n + 1;
  IF public.assemblee_est_des_neuf('republic', LEE) THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE20 un sortant siege encore apres la succession'; END IF;

  n := n + 1;   -- E21 : LES TROIS ENTRANTS SIEGENT, AU MEME INSTANT. Il n'existe aucun instant
  --               intermediaire : c'est une seule ecriture.
  IF NOT public.assemblee_est_des_neuf('republic', BART) THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE21 un entrant ne siege pas apres la succession'; END IF;

  n := n + 1;   -- E22 : ET IL Y A TOUJOURS NEUF SIEGES, pas un de plus.
  SELECT count(*) INTO v_n FROM public.assemblee_occupation_sieges('republic');
  IF v_n <> 9 THEN ko := ko + 1; v_echecs := v_echecs || E'\nE22 ' || v_n || ' sieges au lieu de 9'; END IF;

  n := n + 1;   -- E23 : LA PRESIDENCE SORTANTE TOMBE AU MEME INSTANT, sans qu'aucun cron ait
  --               tourne. Lee n'est plus l'un des neuf, donc il ne preside plus rien.
  IF public.assemblee_president('republic') IS NOT NULL THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE23 l ancien President preside encore : '
      || coalesce(public.assemblee_president('republic'), '?'); END IF;

  n := n + 1;   -- E24 : LA LIGNE DU REGISTRE EST TOUJOURS LA, et c'est voulu : la presidence est
  --               DERIVEE, pas planifiee. Le cron ne fait que retirer une ligne devenue fausse.
  SELECT count(*) INTO v_n FROM public.postes_attribues WHERE id = 'bancsucc-presidence';
  IF v_n <> 1 THEN ko := ko + 1; v_echecs := v_echecs || E'\nE24 la ligne du registre a disparu toute seule'; END IF;

  n := n + 1;   -- E25 : SEULS LES NEUF ENTRANTS SONT ELIGIBLES a la presidence suivante.
  SELECT count(*) INTO v_n FROM (
    SELECT e.depute FROM public.assemblee_presidence_eligibles('republic') e
    EXCEPT
    SELECT coalesce(o.pj_nom, o.pnj_nom) FROM public.assemblee_occupation_sieges('republic') o) z;
  IF v_n <> 0 THEN ko := ko + 1; v_echecs := v_echecs || E'\nE25 ' || v_n || ' eligible(s) hors des neuf'; END IF;
  n := n + 1;
  SELECT count(*) INTO v_n FROM public.assemblee_presidence_eligibles('republic') e WHERE e.depute = LEE;
  IF v_n <> 0 THEN ko := ko + 1; v_echecs := v_echecs || E'\nE26 un sortant est eligible a la presidence suivante'; END IF;

  n := n + 1;   -- E27 : ET LE SCRUTIN SUIVANT EST DEJA OUVERT sur le meme blob -- aucune periode
  --               sans election en preparation.
  SELECT data::jsonb INTO v_blob FROM public.cycles_electoraux
   WHERE country='republic' AND poste_id='depute' AND city='capitale';
  IF (v_blob ->> 'dateResultats')::numeric <= v_maintenant
     OR coalesce((v_blob ->> 'resultatsTraites')::boolean, false)
     OR coalesce(v_blob ->> 'phase','') <> 'candidatures' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE27 pas de scrutin ouvert apres la succession'; END IF;

  n := n + 1;   -- E28 : la fin du mandat entrant et la proclamation de SON successeur sont le
  --               meme instant -- l'invariant du contrat.
  IF (v_blob ->> 'dateFinMandat')::numeric <> (v_blob ->> 'dateResultats')::numeric THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE28 dateFinMandat et dateResultats divergent'; END IF;

  -- ===========================================================================================
  -- 6. LE CASTING DES NEUF SIEGES PNJ
  -- ===========================================================================================
  n := n + 1;   -- E29 : les neuf PNJ de l'hemicycle sont ceux du casting officiel, par rang.
  SELECT string_agg(s.pnj_nom, '|' ORDER BY s.city, s.rang) INTO v_txt
    FROM public.assemblee_sieges s WHERE s.country = 'republic';
  IF v_txt IS DISTINCT FROM
     'Étienne Vauclerc|Sophie Maréchal|President Laroche|Yann Legall|Maëlle Leroux|Loïc Kermeur|Nathalie Charron|Gérard Pichon|Élodie Vasseur' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE29 casting des neuf sieges : ' || coalesce(v_txt,'NULL'); END IF;

  n := n + 1;   -- E30 : aucun des neuf noms fantomes du moteur electoral n'est au registre.
  SELECT count(*) INTO v_n FROM public.assemblee_sieges s
   WHERE s.pnj_nom LIKE '%Marchand%' OR s.pnj_nom LIKE '%Rousseau%' OR s.pnj_nom LIKE '%Lecoq%'
      OR s.pnj_nom LIKE '%Girard%'   OR s.pnj_nom LIKE '%Ambroise%' OR s.pnj_nom LIKE '%Ferraille%'
      OR s.pnj_nom LIKE '%Charbonnier%' OR s.pnj_nom LIKE '%Houiller%';
  IF v_n <> 0 THEN ko := ko + 1; v_echecs := v_echecs || E'\nE30 ' || v_n || ' PNJ fantome(s) au registre'; END IF;

  -- ===========================================================================================
  -- 7. LES CYCLES VIVANTS SONT SORTIS DE L'ANCIEN CONTRAT
  -- ===========================================================================================
  -- Ces quatre epreuves portent sur les lignes NON touchees par ce banc : elles mesurent l'etat
  -- reel laisse par la migration de transition.
  n := n + 1;   -- E31 : aucune phase de l'ancien contrat, aucune relance en attente.
  SELECT count(*) INTO v_n FROM public.cycles_electoraux c
   WHERE c.poste_id <> 'depute' AND left(btrim(c.data), 1) = '{'
     AND (coalesce(c.data::jsonb ->> 'phase','') IN ('mandat','vacant')
          OR c.data::jsonb ? 'relancePossibleApres');
  IF v_n <> 0 THEN ko := ko + 1; v_echecs := v_echecs || E'\nE31 ' || v_n || ' cycle(s) dans l ancien contrat'; END IF;

  n := n + 1;   -- E32 : tous portent un scrutin a venir.
  SELECT count(*) INTO v_n FROM public.cycles_electoraux c
   WHERE c.poste_id <> 'depute' AND left(btrim(c.data), 1) = '{'
     AND (jsonb_typeof(c.data::jsonb -> 'dateResultats') <> 'number'
          OR (c.data::jsonb ->> 'dateResultats')::numeric <= v_maintenant);
  IF v_n <> 0 THEN ko := ko + 1; v_echecs := v_echecs || E'\nE32 ' || v_n || ' cycle(s) sans scrutin a venir'; END IF;

  n := n + 1;   -- E33 : le vote est un dimanche, la proclamation un lundi minuit.
  SELECT count(*) INTO v_n FROM public.cycles_electoraux c
   WHERE c.poste_id <> 'depute' AND left(btrim(c.data), 1) = '{'
     AND (extract(isodow FROM (to_timestamp((c.data::jsonb ->> 'dateVote')::numeric / 1000) AT TIME ZONE 'Europe/Paris')) <> 7
          OR extract(isodow FROM (to_timestamp((c.data::jsonb ->> 'dateResultats')::numeric / 1000) AT TIME ZONE 'Europe/Paris')) <> 1);
  IF v_n <> 0 THEN ko := ko + 1; v_echecs := v_echecs || E'\nE33 ' || v_n || ' cycle(s) hors du calendrier du dimanche'; END IF;

  n := n + 1;   -- E34 : LES DEUX TITULAIRES EN EXERCICE SONT TOUJOURS ATTESTES par la base reelle.
  IF NOT public.poste_est_atteste('Le Président (PNJ)', jsonb_build_object('id','president'), 'republic')
     OR NOT public.poste_est_atteste('Le Maire (PNJ)', jsonb_build_object('id','maire','city','ville_b'), 'republic') THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE34 un titulaire reel n est plus atteste apres la migration'; END IF;

  -- ===========================================================================================
  -- 8. L'ESTAMPILLE DU SCRUTIN NE VIENT JAMAIS DU CLIENT
  -- ===========================================================================================
  -- `authenticated` garde son droit d'INSERT sur `candidatures` (dette nommee du chantier 5) :
  -- l'estampille doit donc etre INDIFFERENTE a ce que l'appelant annonce. Le declencheur la jette
  -- AVANT de lire le cycle, et ne la repose que depuis le cycle.
  UPDATE public.cycles_electoraux
     SET data = (data::jsonb || jsonb_build_object('phase','candidatures','resultatsTraites',false,
          'dateDebutCandidatures', 1700000000000::numeric,
          'dateDebutCampagne', v_maintenant + 86400000))::text
   WHERE id = 'republic_depute_capitale';
  DELETE FROM public.candidatures WHERE id LIKE 'bancsucc-est%';

  n := n + 1;   -- E35 : UNE VALEUR FORGEE EST JETEE, et remplacee par celle du cycle.
  INSERT INTO public.candidatures (id, country, poste_id, city, nom, cle_scrutin, created_at)
  VALUES ('bancsucc-est-1', 'republic', 'depute', 'capitale', BEN, 999999999999, now());
  SELECT cle_scrutin INTO v_big FROM public.candidatures WHERE id = 'bancsucc-est-1';
  IF v_big IS DISTINCT FROM 1700000000000::bigint THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE35 estampille forgee non jetee : ' || coalesce(v_big::text,'NULL'); END IF;

  n := n + 1;   -- E36 : CYCLE MUET -> NULL, JAMAIS LA VALEUR DU CLIENT. Fail-closed : NULL ne
  --               remonte dans aucun scrutin, puisque le navigateur ne lit rien sans clef connue.
  UPDATE public.cycles_electoraux SET data = (data::jsonb - 'dateDebutCandidatures')::text
   WHERE id = 'republic_depute_capitale';
  INSERT INTO public.candidatures (id, country, poste_id, city, nom, cle_scrutin, created_at)
  VALUES ('bancsucc-est-2', 'republic', 'depute', 'capitale', MAY, 888888888888, now());
  SELECT cle_scrutin INTO v_big FROM public.candidatures WHERE id = 'bancsucc-est-2';
  IF v_big IS NOT NULL THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE36 cycle muet : l estampille du client a survecu : ' || v_big::text; END IF;

  IF ko = 0 THEN
    RAISE EXCEPTION 'banc succession : LES % EPREUVES SONT VERTES. -- rien ne doit rester', n;
  ELSE
    RAISE EXCEPTION 'banc succession : % epreuve(s) sur % en defaut.%', ko, n, v_echecs;
  END IF;
END
$banc$;
ROLLBACK;
