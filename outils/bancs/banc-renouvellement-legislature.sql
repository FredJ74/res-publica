-- BANC DU RENOUVELLEMENT INTEGRAL DE LA LEGISLATURE (11 octobre 2026, correctif)
--
-- CE BANC NE COMMITE RIEN. Il joue une legislature entiere, la renouvelle, et se termine par un
-- RAISE EXCEPTION INCONDITIONNEL.
--
-- L'INVARIANT EPROUVE : un President de l'Assemblee doit etre l'un des NEUF deputes de la
-- legislature EN COURS, et il ne doit jamais exister de periode ou un ancien depute preside la
-- nouvelle Assemblee.
--
-- LE DEFAUT QU'IL ATTRAPE, ET QUE RIEN N'ATTRAPAIT. Le siege d'un depute joueur etait derive de
-- `personnages.poste_depute` seul -- un champ POSE sur la fiche, verifie par le declencheur
-- d'attestation uniquement A L'ECRITURE. Un mandat acheve y survivait donc tant que la fiche
-- n'etait pas reecrite, c'est-a-dire indefiniment pour un joueur deconnecte. Ce banc laisse
-- EXPRES le champ perime en base apres le renouvellement : si le siege en dependait encore,
-- l'ancienne Assemblee siegerait toujours et son President presiderait toujours.
--
-- CE QU'IL PROUVE :
--   1. les neuf mandats finissent SIMULTANEMENT, et commencent SIMULTANEMENT ;
--   2. la presidence sortante prend fin AU MEME INSTANT, sans qu'aucun cron ait tourne ;
--   3. aucune presidence entre le renouvellement et l'election suivante -- et les prerogatives
--      presidentielles sont refusees a l'ancien President pendant cette periode ;
--   4. seuls les neuf deputes ENTRANTS sont eligibles au nouveau scrutin ;
--   5. Laroche n'a aucune protection : trois deputes joueurs a Luthecia le sortent des neuf, et
--      il ne presiderait rien s'il etait au registre ;
--   6. aucun dixieme parlementaire -- les eligibles sont exactement les titulaires des neuf ;
--   7. le nouveau President est toujours l'un des neuf.
--
-- Usage : coller ce fichier dans un execute_sql. Il doit finir sur
--   ERROR: banc legislature : LES 24 EPREUVES SONT VERTES. -- rien ne doit rester

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
  ARNIE_U text := '9abef1c4-75ab-4352-b5ca-a219fc37a35c'; ARNIE text := 'Arnie';
  LAROCHE text := 'President Laroche';
  v jsonb; n integer := 0; ko integer := 0; v_echecs text := '';
  v_n integer; v_txt text;
BEGIN
  PERFORM pg_temp.je_suis_le_serveur();

  -- ===========================================================================================
  -- LEGISLATURE A : SEPT DEPUTES JOUEURS, DONT LE PRESIDENT
  -- ===========================================================================================
  -- LES CYCLES D'ABORD, LES FICHES ENSUITE : le declencheur d'attestation annulerait en silence
  -- un poste_depute que `cycles_electoraux` ne confirme pas.
  UPDATE public.cycles_electoraux SET data = '{"elus":["Lee Capene","Marsault","Phileas Frogg"]}'
   WHERE country='republic' AND poste_id='depute' AND city='capitale';
  UPDATE public.cycles_electoraux SET data = '{"elus":["Ben","May","Bartesto Chevara"]}'
   WHERE country='republic' AND poste_id='depute' AND city='ville_a';
  UPDATE public.cycles_electoraux SET data = '{"elus":["Arnie"]}'
   WHERE country='republic' AND poste_id='depute' AND city='ville_b';
  UPDATE public.personnages_donnees SET poste_depute = jsonb_build_object('id','depute','city','capitale')
   WHERE name IN (LEE, MARS, PHIL);
  UPDATE public.personnages_donnees SET poste_depute = jsonb_build_object('id','depute','city','ville_a')
   WHERE name IN (BEN, MAY, BART);
  UPDATE public.personnages_donnees SET poste_depute = jsonb_build_object('id','depute','city','ville_b')
   WHERE name = ARNIE;
  UPDATE public.personnages_donnees
     SET current_city='capitale', current_building='assemblee', current_room='hemicycle'
   WHERE name IN (LEE, MARS, PHIL, BEN, MAY, BART, ARNIE);

  DELETE FROM public.postes_attribues
   WHERE country='republic' AND poste_id='president_assemblee' AND city IS NULL;
  INSERT INTO public.postes_attribues (id, country, poste_id, city, titulaire, source)
  VALUES ('bancleg-presidence', 'republic', 'president_assemblee', NULL, LEE, 'banc');

  n := n + 1;   -- SEPT SIEGES JOUEURS, DEUX PNJ : la legislature A siege.
  SELECT count(*) INTO v_n FROM public.assemblee_occupation_sieges('republic') o WHERE NOT o.est_pnj;
  IF v_n <> 7 THEN ko := ko + 1; v_echecs := v_echecs || E'\nE1 ' || v_n || ' sieges PJ sur 7'; END IF;

  n := n + 1;   -- ET LE PRESIDENT PRESIDE, parce qu'il est l'un des neuf.
  IF public.assemblee_president('republic') IS DISTINCT FROM LEE THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE2 le President de la legislature A ne preside pas'; END IF;

  n := n + 1;   -- §5 : LAROCHE N'A AUCUNE PROTECTION. Trois deputes joueurs a Luthecia, et il
  --              n'est plus l'un des neuf -- son rang n'y change rien.
  IF public.assemblee_est_des_neuf('republic', LAROCHE) THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE3 Laroche siege alors que les trois sieges de Luthecia sont tenus'; END IF;

  n := n + 1;   -- ET S'IL ETAIT AU REGISTRE, IL NE PRESIDERAIT RIEN. On le met President le temps
  --              de l'epreuve : la presidence est derivee, donc elle ne lui est pas rendue.
  UPDATE public.postes_attribues SET titulaire = LAROCHE WHERE id = 'bancleg-presidence';
  IF public.assemblee_president('republic') IS NOT NULL THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE4 un non-depute preside : '
      || coalesce(public.assemblee_president('republic'), '?'); END IF;
  UPDATE public.postes_attribues SET titulaire = LEE WHERE id = 'bancleg-presidence';

  n := n + 1;   -- §6 : AUCUN DIXIEME PARLEMENTAIRE. Les eligibles sont EXACTEMENT les titulaires
  --              des neuf sieges, ni plus ni autre chose.
  SELECT count(*) INTO v_n FROM (
    SELECT e.depute FROM public.assemblee_presidence_eligibles('republic') e
    EXCEPT
    SELECT coalesce(o.pj_nom, o.pnj_nom) FROM public.assemblee_occupation_sieges('republic') o) z;
  IF v_n <> 0 THEN ko := ko + 1; v_echecs := v_echecs || E'\nE5 ' || v_n || ' eligible(s) hors des neuf'; END IF;
  n := n + 1;
  SELECT count(*) INTO v_n FROM public.assemblee_presidence_eligibles('republic');
  IF v_n <> 9 THEN ko := ko + 1; v_echecs := v_echecs || E'\nE6 ' || v_n || ' eligibles au lieu de 9'; END IF;

  -- ===========================================================================================
  -- LE RENOUVELLEMENT : LES NEUF MANDATS PRENNENT FIN
  -- ===========================================================================================
  -- C'est exactement ce que fait le moteur electoral a l'echeance d'un mandat : il reecrit le
  -- cycle de chaque ville en phase 'candidatures', sans `elus`. UNE ecriture par ville.
  --
  -- ET ON NE TOUCHE PAS AUX FICHES. Les sept `poste_depute` restent en base, perimes : c'est la
  -- situation reelle d'un joueur deconnecte. Si le siege en dependait encore, tout ce qui suit
  -- serait vert pour la mauvaise raison.
  UPDATE public.cycles_electoraux SET data = '{"phase":"candidatures"}'
   WHERE country='republic' AND poste_id='depute';

  n := n + 1;   -- LE CHAMP PERIME EST BIEN RESTE : la premisse de l'epreuve est fermee.
  SELECT count(*) INTO v_n FROM public.personnages_donnees
   WHERE name IN (LEE, MARS, PHIL, BEN, MAY, BART, ARNIE) AND poste_depute IS NOT NULL;
  IF v_n <> 7 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE7 premisse cassee : ' || v_n || ' fiches portent encore poste_depute sur 7'; END IF;

  n := n + 1;   -- §1 : LES NEUF MANDATS ONT PRIS FIN SIMULTANEMENT. Aucun siege joueur ne reste,
  --              et il n'existe aucun depute « en cours de sortie ».
  SELECT count(*) INTO v_n FROM public.assemblee_occupation_sieges('republic') o WHERE NOT o.est_pnj;
  IF v_n <> 0 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE8 ' || v_n || ' siege(s) joueur(s) survivent au renouvellement'; END IF;

  n := n + 1;   -- ET LES NEUF SIEGES SONT TOUJOURS NEUF : le renouvellement ne detruit rien.
  SELECT count(*) INTO v_n FROM public.assemblee_occupation_sieges('republic');
  IF v_n <> 9 THEN ko := ko + 1; v_echecs := v_echecs || E'\nE9 ' || v_n || ' sieges au lieu de 9'; END IF;

  n := n + 1;   -- §2 : LA PRESIDENCE SORTANTE A PRIS FIN AU MEME INSTANT, sans qu'aucun cron
  --              n'ait tourne. C'est le coeur du correctif.
  IF public.assemblee_president('republic') IS NOT NULL THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE10 l ancien President preside encore : '
      || coalesce(public.assemblee_president('republic'), '?'); END IF;

  n := n + 1;   -- ET LA LIGNE DU REGISTRE EST TOUJOURS LA : la presidence n'a pas cesse parce
  --              qu'on l'a nettoyee, elle a cesse parce qu'elle est DERIVEE. L'invariant ne
  --              depend donc d'aucune tache planifiee.
  IF NOT EXISTS (SELECT 1 FROM public.postes_attribues WHERE id = 'bancleg-presidence') THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE11 la ligne du registre a disparu toute seule'; END IF;

  n := n + 1;   -- §3 : LES PREROGATIVES PRESIDENTIELLES SONT REFUSEES A L'ANCIEN PRESIDENT.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.assemblee_suspendre_seance('Je preside encore.', 'rq-bancleg-susp-01');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'pas_le_president' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE12 l ancien President a suspendu la seance : ' || v::text; END IF;

  n := n + 1;
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.assemblee_rappeler(MARS, 'Motif du banc, assez long pour etre recevable.', 'rq-bancleg-rap-01');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') = '' OR v->>'ok' = 'true' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE13 l ancien President a exerce la discipline : ' || v::text; END IF;

  n := n + 1;   -- ET L'ETAT DE SEANCE NE LE DIT PLUS PRESIDENT.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.assemblee_seance(5);
  PERFORM pg_temp.je_suis_le_serveur();
  IF v->>'je_suis_le_president' <> 'false' OR coalesce(v->>'president','null') <> 'null' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE14 l etat de seance designe encore un President : '
      || coalesce(v->>'president','(nul)'); END IF;

  n := n + 1;   -- ET IL N'EST PLUS DEPUTE NON PLUS : son mandat a pris fin avec les autres.
  IF public.assemblee_est_depute('republic', LEE) OR public.assemblee_est_des_neuf('republic', LEE) THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE15 l ancien depute siege encore'; END IF;

  -- LE REGISTRE EST NETTOYE PAR LA PORTE DEDIEE, et elle est idempotente.
  n := n + 1;
  v := public.assemblee_presidence_fin_de_legislature('republic');
  IF v->>'ok' <> 'true' OR (v->>'sortis')::int <> 1
     OR (v->'detail'->0->>'ancien_president') IS DISTINCT FROM LEE THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE16 la fin de legislature n a pas consigne la sortie : ' || v::text; END IF;
  n := n + 1;
  IF EXISTS (SELECT 1 FROM public.postes_attribues
              WHERE country='republic' AND poste_id='president_assemblee' AND city IS NULL) THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE17 la ligne perimee du registre survit au nettoyage'; END IF;
  n := n + 1;   -- UN SECOND PASSAGE NE TROUVE RIEN : idempotence.
  v := public.assemblee_presidence_fin_de_legislature('republic');
  IF v->>'ok' <> 'true' OR (v->>'sortis')::int <> 0 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE18 second passage de la fin de legislature : ' || v::text; END IF;

  n := n + 1;   -- ET ELLE N'EST PAS A LA MAIN DES JOUEURS : le GRANT arrete l'appel avant le corps.
  BEGIN
    PERFORM pg_temp.je_suis(MARS_U);
    PERFORM public.assemblee_presidence_fin_de_legislature('republic');
    ko := ko + 1; v_echecs := v_echecs || E'\nE19 un joueur a pu clore une legislature';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.je_suis_le_serveur();

  -- ===========================================================================================
  -- LEGISLATURE B : LES NEUF ENTRANTS, SIMULTANEMENT
  -- ===========================================================================================
  -- Les sortants gardent leur `poste_depute` perime en base ; les entrants recoivent le leur.
  -- Si le siege dependait encore du champ pose, on verrait DOUZE deputes.
  UPDATE public.cycles_electoraux SET data = '{"elus":["Ben","May","Bartesto Chevara"]}'
   WHERE country='republic' AND poste_id='depute' AND city='capitale';
  UPDATE public.personnages_donnees SET poste_depute = jsonb_build_object('id','depute','city','capitale')
   WHERE name IN (BEN, MAY, BART);

  n := n + 1;   -- §1 (dans l'autre sens) : LES ENTRANTS ENTRENT SIMULTANEMENT, et eux seuls.
  SELECT count(*) INTO v_n FROM public.assemblee_occupation_sieges('republic') o WHERE NOT o.est_pnj;
  IF v_n <> 3 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE20 ' || v_n || ' sieges joueurs au lieu de 3 : les sortants siegent encore'; END IF;

  n := n + 1;   -- §4 : SEULS LES NEUF ENTRANTS SONT ELIGIBLES. Les sortants, non.
  SELECT count(*) INTO v_n FROM public.assemblee_presidence_eligibles('republic') e
   WHERE e.depute IN (LEE, MARS, PHIL, ARNIE);
  IF v_n <> 0 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE21 ' || v_n || ' sortant(s) encore eligible(s)'; END IF;

  -- LE SCRUTIN DE LA NOUVELLE LEGISLATURE
  DELETE FROM public.assemblee_presidence_bulletins;
  DELETE FROM public.assemblee_presidence_scrutins WHERE pays = 'republic';
  INSERT INTO public.assemblee_presidence_scrutins (id, pays, cause, cloture_ts, eligibles, statut)
  SELECT 'bancleg-scrutin', 'republic', 'renouvellement', now() + interval '2 hours',
         coalesce(jsonb_agg(jsonb_build_object('depute', e.depute, 'ville', e.ville,
                   'rang', e.rang, 'est_pnj', e.est_pnj) ORDER BY e.ville, e.rang), '[]'::jsonb),
         'ouvert'
    FROM public.assemblee_presidence_eligibles('republic') e;

  n := n + 1;   -- ON NE VOTE PAS POUR UN SORTANT : il n'est pas dans les neuf figes.
  PERFORM pg_temp.je_suis(BEN_U);
  v := public.assemblee_presidence_voter(LEE, 'rq-bancleg-vote-sortant');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'pas_eligible' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE22 un sortant a recu une voix : ' || v::text; END IF;

  n := n + 1;   -- UN ENTRANT, LUI, EST ELU.
  PERFORM pg_temp.je_suis(BEN_U);
  v := public.assemblee_presidence_voter(MAY, 'rq-bancleg-vote-entrant');
  PERFORM pg_temp.je_suis_le_serveur();
  IF v->>'ok' <> 'true' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE23 un entrant n a pas pu voter : ' || v::text; END IF;

  n := n + 1;   -- §7 : LE NOUVEAU PRESIDENT EST L'UN DES NEUF, et il preside vraiment.
  UPDATE public.assemblee_presidence_scrutins SET cloture_ts = now() - interval '1 minute'
   WHERE id = 'bancleg-scrutin';
  v := public.assemblee_presidence_depouiller('republic');
  IF v->>'elu' IS DISTINCT FROM MAY
     OR public.assemblee_president('republic') IS DISTINCT FROM MAY
     OR NOT public.assemblee_est_des_neuf('republic', MAY) THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE24 le nouveau President n est pas l un des neuf : ' || v::text; END IF;

  -- ===========================================================================================
  IF ko > 0 THEN
    RAISE EXCEPTION 'banc legislature : % ECHEC(S) SUR % EPREUVES.%', ko, n, v_echecs;
  END IF;
  RAISE EXCEPTION 'banc legislature : LES % EPREUVES SONT VERTES. -- rien ne doit rester', n;
END $banc$;
ROLLBACK;
