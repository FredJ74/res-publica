-- BANC DE L'ELECTION DU PRESIDENT DE L'ASSEMBLEE (11 octobre 2026)
--
-- CE BANC NE COMMITE RIEN. Il forge trois deputes joueurs a Luthecia, joue un scrutin entier --
-- vote, egalite, courte paille, proclamation --, et se termine par un RAISE EXCEPTION
-- INCONDITIONNEL.
--
-- IL FORGE LES ROLES PAR LA VOIE LEGALE : un depute n'existe que si `cycles_electoraux` le
-- declare elu, parce que le trigger d'attestation annule silencieusement tout poste non atteste.
--
-- POURQUOI LE SCRUTIN EST POSE A LA MAIN ET NON CONVOQUE. La convocation refuse hors du lundi de
-- Paris -- c'est la regle, et l'epreuve E6 la verifie dans les deux sens, selon le jour ou le banc
-- tourne. Pour pouvoir jouer le vote et le depouillement n'importe quel jour, la ligne de scrutin
-- est donc posee directement, sous identite serveur : c'est le DECOR, pas la regle.
--
-- CE QU'IL PROUVE :
--   . NEUF ELIGIBLES, TROIS PAR VILLE, jamais dix -- et le PNJ d'un siege tenu par un joueur
--     cesse d'etre eligible : le depute remplace son suppleant, il ne s'y ajoute pas ;
--   . AUCUNE CANDIDATURE n'est exigee : les neuf sont la sans avoir rien depose ;
--   . un depute vote pour lui-meme, pour un autre joueur, ou pour un PNJ ;
--   . le DOUBLE VOTE est refuse et la voix deja deposee RESTE celle qui compte ;
--   . AUCUN BULLETIN PNJ n'est fabrique -- les neuf PNJ sont eligibles et muets ;
--   . le decompte est visible EN DIRECT, zeros compris, et ne dit pas qui a vote pour qui ;
--   . un bulletin arrive apres 23h00 est refuse, meme avant le depouillement ;
--   . la courte paille ne porte QUE sur les ex aequo EN TETE, elle est tiree par le SERVEUR, et
--     le resultat ne bouge plus -- un second depouillement ne retire pas la paille ;
--   . la proclamation ecrit le REGISTRE DES POSTES, donc les pouvoirs changent de main, et elle
--     ne touche PAS au mandat de depute : perdre la presidence n'est pas perdre son siege ;
--   . le tirage n'est propose QU'UNE FOIS par joueur, et l'etat « vu » est serveur ;
--   . UNE SEULE VOIX SUFFIT -- aucun quorum n'existe ;
--   . un PNJ elu est President, et aucun joueur ne detient alors ses pouvoirs ;
--   . et ZERO VOTANT ne laisse pas la presidence vacante : les neuf sont a egalite a zero voix, la
--     courte paille les departage tous. Consequence mecanique des regles arbitrees, mesuree ici.
--
-- Usage : coller ce fichier dans un execute_sql. Il doit finir sur
--   ERROR: banc presidence : LES 35 EPREUVES SONT VERTES. -- rien ne doit rester

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
  BART_U  text := '0d119ada-f6e4-4c8c-bc8d-34e57de6115f'; BART  text := 'Bartesto Chevara';
  PNJ_A   text := 'Yann Legall';        -- siege PNJ de ville_a
  PNJ_B   text := 'Gérard Pichon';      -- siege PNJ de ville_b
  v jsonb; n integer := 0; ko integer := 0; v_echecs text := '';
  v_n integer; v_elu text; v_elu2 text; v_txt text; v_fen boolean;
BEGIN
  PERFORM pg_temp.je_suis_le_serveur();

  -- ===========================================================================================
  -- DECOR : TROIS DEPUTES JOUEURS A LUTHECIA, SIX PNJ AILLEURS
  -- ===========================================================================================
  UPDATE public.cycles_electoraux SET data = '{"elus":["Lee Capene","Marsault","Phileas Frogg"]}'
   WHERE country = 'republic' AND poste_id = 'depute' AND city = 'capitale';
  UPDATE public.personnages_donnees SET poste_depute = jsonb_build_object('id','depute','city','capitale')
   WHERE name IN (LEE, MARS, PHIL);
  UPDATE public.personnages_donnees
     SET current_city='capitale', current_building='assemblee', current_room='hemicycle'
   WHERE name IN (LEE, MARS, PHIL, BART);

  n := n + 1;   -- NEUF ELIGIBLES, JAMAIS DIX. La presidence n'est pas un siege de plus.
  SELECT count(*) INTO v_n FROM public.assemblee_presidence_eligibles('republic');
  IF v_n <> 9 THEN ko := ko + 1; v_echecs := v_echecs || E'\nE1 ' || v_n || ' eligibles au lieu de 9'; END IF;

  n := n + 1;   -- TROIS PAR VILLE.
  SELECT count(*) INTO v_n FROM (
    SELECT e.ville FROM public.assemblee_presidence_eligibles('republic') e
     GROUP BY e.ville HAVING count(*) <> 3) z;
  IF v_n <> 0 THEN ko := ko + 1; v_echecs := v_echecs || E'\nE2 une ville n a pas 3 eligibles'; END IF;

  n := n + 1;   -- LES TROIS DEPUTES JOUEURS SONT ELIGIBLES.
  SELECT count(*) INTO v_n FROM public.assemblee_presidence_eligibles('republic') e
   WHERE e.depute IN (LEE, MARS, PHIL) AND NOT e.est_pnj;
  IF v_n <> 3 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE3 ' || v_n || ' depute(s) joueur(s) eligible(s) sur 3'; END IF;
  n := n + 1;   -- ET LES SIX PNJ RESTANTS AUSSI.
  SELECT count(*) INTO v_n FROM public.assemblee_presidence_eligibles('republic') e WHERE e.est_pnj;
  IF v_n <> 6 THEN ko := ko + 1; v_echecs := v_echecs || E'\nE4 ' || v_n || ' PNJ eligible(s) sur 6'; END IF;

  n := n + 1;   -- UN SIEGE TENU PAR UN PJ N'EST PLUS PROPOSE SOUS LE NOM DE SON PNJ : le depute
  --              REMPLACE son suppleant, il ne s'y ajoute pas. Sans cela il y aurait douze noms.
  IF EXISTS (SELECT 1 FROM public.assemblee_presidence_eligibles('republic') e
              WHERE e.depute = 'Sophie Maréchal') THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE5 le PNJ d un siege tenu par un PJ reste eligible'; END IF;

  n := n + 1;   -- LE CALENDRIER EST TENU : on ne convoque un scrutin QUE le lundi. L'epreuve
  --              verifie la regle DANS LES DEUX SENS, selon le jour ou le banc tourne.
  v_fen := public.assemblee_presidence_fenetre_convocation(now());
  v := public.assemblee_presidence_convoquer('republic', 'renouvellement');
  IF v_fen THEN
    IF v->>'ok' <> 'true' THEN
      ko := ko + 1; v_echecs := v_echecs || E'\nE6 un lundi, la convocation a echoue : ' || v::text; END IF;
  ELSE
    IF coalesce(v->>'raison','') <> 'hors_fenetre_convocation' THEN
      ko := ko + 1; v_echecs := v_echecs || E'\nE6 hors lundi, la convocation est passee : ' || v::text; END IF;
  END IF;

  n := n + 1;   -- UN JOUEUR N'A MEME PAS LE DROIT D'APPELER LA CONVOCATION : le GRANT l'arrete
  --              avant le corps de la fonction, ce qui est plus fort qu'un refus interne.
  BEGIN
    PERFORM pg_temp.je_suis(LEE_U);
    PERFORM public.assemblee_presidence_convoquer('republic', 'renouvellement');
    ko := ko + 1; v_echecs := v_echecs || E'\nE7 un joueur a pu appeler la convocation';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.je_suis_le_serveur();

  -- LE DECOR DU SCRUTIN, pose a la main pour que le banc tourne n'importe quel jour.
  DELETE FROM public.assemblee_presidence_scrutins WHERE pays = 'republic';
  INSERT INTO public.assemblee_presidence_scrutins (id, pays, cause, cloture_ts, eligibles)
  SELECT 'banc-scrutin', 'republic', 'renouvellement', now() + interval '2 hours',
         coalesce(jsonb_agg(jsonb_build_object('depute', e.depute, 'ville', e.ville,
                            'rang', e.rang, 'est_pnj', e.est_pnj) ORDER BY e.ville, e.rang), '[]'::jsonb)
    FROM public.assemblee_presidence_eligibles('republic') e;

  n := n + 1;   -- AUCUNE PHASE DE CANDIDATURE : les neuf sont la, sans avoir rien depose.
  SELECT jsonb_array_length(eligibles) INTO v_n FROM public.assemblee_presidence_scrutins
   WHERE id = 'banc-scrutin';
  IF v_n <> 9 THEN ko := ko + 1; v_echecs := v_echecs || E'\nE8 le scrutin ne porte pas 9 eligibles : ' || v_n; END IF;

  n := n + 1;   -- UN NON-DEPUTE NE VOTE PAS.
  PERFORM pg_temp.je_suis(BART_U);
  v := public.assemblee_presidence_voter(LEE, 'rq-banc3-bart-001');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'pas_depute' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE9 un non-depute a vote : ' || v::text; END IF;

  n := n + 1;   -- ON NE VOTE PAS POUR QUELQU'UN QUI N'EST PAS L'UN DES NEUF.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.assemblee_presidence_voter(BART, 'rq-banc3-hors-001');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'pas_eligible' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE10 un dixieme nom a recu une voix : ' || v::text; END IF;

  n := n + 1;   -- UN DEPUTE PEUT VOTER POUR LUI-MEME.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.assemblee_presidence_voter(LEE, 'rq-banc3-lee-001');
  PERFORM pg_temp.je_suis_le_serveur();
  IF v->>'ok' <> 'true' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE11 vote pour soi-meme refuse : ' || v::text; END IF;

  n := n + 1;   -- LE DOUBLE VOTE EST REFUSE, ET LA VOIX DEJA DEPOSEE RESTE.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.assemblee_presidence_voter(MARS, 'rq-banc3-lee-002');
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT count(*) INTO v_n FROM public.assemblee_presidence_bulletins b
   WHERE b.scrutin_id = 'banc-scrutin' AND b.votant = LEE;
  SELECT b.pour INTO v_txt FROM public.assemblee_presidence_bulletins b
   WHERE b.scrutin_id = 'banc-scrutin' AND b.votant = LEE;
  IF coalesce(v->>'raison','') <> 'deja_vote' OR v_n <> 1 OR v_txt <> LEE THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE12 double vote : ' || v::text
      || ' / ' || v_n || ' bulletin(s), pour ' || coalesce(v_txt,'(nul)'); END IF;

  n := n + 1;   -- UN REJEU NE DEPOSE PAS UN SECOND BULLETIN.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.assemblee_presidence_voter(LEE, 'rq-banc3-lee-001');
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT count(*) INTO v_n FROM public.assemblee_presidence_bulletins b WHERE b.scrutin_id = 'banc-scrutin';
  IF v->>'rejeu' <> 'true' OR v_n <> 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE13 rejeu du vote : ' || v::text || ' / ' || v_n; END IF;

  n := n + 1;   -- UN DEPUTE PEUT VOTER POUR UN PNJ.
  PERFORM pg_temp.je_suis(MARS_U);
  v := public.assemblee_presidence_voter(PNJ_A, 'rq-banc3-mars-001');
  PERFORM pg_temp.je_suis_le_serveur();
  IF v->>'ok' <> 'true' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE14 vote pour un PNJ refuse : ' || v::text; END IF;

  n := n + 1;   -- LE DECOMPTE EST VISIBLE EN DIRECT, ZERO VOIX COMPRISE : sans les zeros,
  --              l'egalite a zero serait illisible.
  PERFORM pg_temp.je_suis(PHIL_U);
  v := public.assemblee_presidence_etat();
  PERFORM pg_temp.je_suis_le_serveur();
  IF jsonb_array_length(v->'scrutin'->'decompte') <> 9
     OR (v->'scrutin'->>'bulletins')::int <> 2 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE15 decompte en direct faux : ' || (v->'scrutin')::text; END IF;

  n := n + 1;   -- ET IL NE DIT PAS QUI A VOTE POUR QUI : chacun voit SON bulletin, pas celui des
  --              autres. Phileas n'a pas vote, il ne doit donc en voir aucun.
  IF (v->'scrutin'->>'mon_bulletin') IS NOT NULL THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE16 Phileas voit un bulletin alors qu il n a pas vote'; END IF;

  n := n + 1;   -- AUCUN BULLETIN PNJ N'EST FABRIQUE.
  SELECT count(*) INTO v_n FROM public.assemblee_presidence_bulletins b
   WHERE b.scrutin_id = 'banc-scrutin'
     AND b.votant NOT IN (SELECT e.depute FROM public.assemblee_presidence_eligibles('republic') e
                           WHERE NOT e.est_pnj);
  IF v_n <> 0 THEN ko := ko + 1; v_echecs := v_echecs || E'\nE17 ' || v_n || ' bulletin(s) de PNJ'; END IF;

  n := n + 1;   -- ON NE DEPOUILLE PAS AVANT L'ECHEANCE.
  v := public.assemblee_presidence_depouiller('republic');
  IF v->>'depouille' <> 'false' OR coalesce(v->>'raison','') <> 'pas_encore_echu' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE18 depouillement avant 23h : ' || v::text; END IF;

  n := n + 1;   -- ET UN JOUEUR N'A PAS LE DROIT DE DEPOUILLER.
  BEGIN
    PERFORM pg_temp.je_suis(LEE_U);
    PERFORM public.assemblee_presidence_depouiller('republic');
    ko := ko + 1; v_echecs := v_echecs || E'\nE19 un joueur a pu appeler le depouillement';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.je_suis_le_serveur();

  -- L'ECHEANCE EST ATTEINTE. Deux voix : Lee 1, Yann Legall 1 -> EGALITE EN TETE.
  UPDATE public.assemblee_presidence_scrutins SET cloture_ts = now() - interval '1 minute'
   WHERE id = 'banc-scrutin';

  n := n + 1;   -- UN BULLETIN APRES 23H EST REFUSE, meme avant que le depouillement n'ait tourne.
  PERFORM pg_temp.je_suis(PHIL_U);
  v := public.assemblee_presidence_voter(PHIL, 'rq-banc3-phil-001');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'scrutin_clos' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE20 bulletin tardif accepte : ' || v::text; END IF;

  n := n + 1;   -- LA COURTE PAILLE NE PORTE QUE SUR LES EX AEQUO EN TETE.
  v := public.assemblee_presidence_depouiller('republic');
  v_elu := v->>'elu';
  IF v->>'depouille' <> 'true' OR jsonb_array_length(v->'egalite') <> 2
     OR v_elu NOT IN (LEE, PNJ_A) THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE21 depouillement avec egalite : ' || v::text; END IF;

  n := n + 1;   -- ET LES SEPT AUTRES, A ZERO VOIX, NE TIRENT PAS.
  IF (v->'egalite')::text LIKE '%Marsault%' OR (v->'egalite')::text LIKE '%Phileas%' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE22 un depute sans voix a tire : ' || (v->'egalite')::text; END IF;

  n := n + 1;   -- LA PROCLAMATION ECRIT LE REGISTRE DES POSTES : les pouvoirs suivent.
  IF public.assemblee_president('republic') IS DISTINCT FROM v_elu THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE23 registre : '
      || coalesce(public.assemblee_president('republic'),'(vacante)') || ' au lieu de ' || v_elu; END IF;

  n := n + 1;   -- LE RESULTAT EST STABLE : un second depouillement ne retire pas la paille.
  v := public.assemblee_presidence_depouiller('republic');
  SELECT elu INTO v_elu2 FROM public.assemblee_presidence_scrutins WHERE id = 'banc-scrutin';
  IF v->>'depouille' <> 'false' OR v_elu2 IS DISTINCT FROM v_elu THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE24 le resultat a bouge : ' || v_elu || ' -> '
      || coalesce(v_elu2,'(nul)'); END IF;

  n := n + 1;   -- LE MANDAT DE DEPUTE EST INTACT : la presidence est une fonction, pas un siege.
  SELECT count(*) INTO v_n FROM public.personnages_donnees
   WHERE name IN (LEE, MARS, PHIL) AND poste_depute IS NOT NULL;
  IF v_n <> 3 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE25 ' || v_n || ' mandat(s) sur 3 apres election'; END IF;

  n := n + 1;   -- LA TRACE PUBLIQUE EST FACTUELLE, ET SANS QUALIFICATION.
  SELECT c.libelle INTO v_txt FROM public.chronique_nationale c WHERE c.source_ref = 'banc-scrutin';
  IF v_txt IS NULL OR v_txt ~* '(illegitim|usurp|scandaleu|contestable|douteu)' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE26 chronique : ' || coalesce(v_txt,'(nulle)'); END IF;

  n := n + 1;   -- UN ABSENT SE VOIT PROPOSER LE TIRAGE A SON RETOUR.
  PERFORM pg_temp.je_suis(MARS_U);
  v := public.assemblee_presidence_etat();
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v->'a_revoir'->>'id') IS DISTINCT FROM 'banc-scrutin' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE27 tirage non propose a un absent : '
      || coalesce((v->'a_revoir')::text,'(nul)'); END IF;

  n := n + 1;   -- ET UNE SEULE FOIS : l'etat « vu » est serveur, donc il survit a tout.
  PERFORM pg_temp.je_suis(MARS_U);
  PERFORM public.assemblee_presidence_tirage_vu('banc-scrutin');
  v := public.assemblee_presidence_etat();
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'a_revoir','null') <> 'null' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE28 tirage propose deux fois : ' || (v->'a_revoir')::text; END IF;

  n := n + 1;   -- ET IL RESTE PROPOSE A CELUI QUI NE L'A PAS VU : l'etat est PAR JOUEUR.
  PERFORM pg_temp.je_suis(PHIL_U);
  v := public.assemblee_presidence_etat();
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v->'a_revoir'->>'id') IS DISTINCT FROM 'banc-scrutin' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE29 le tirage vu par l un a disparu pour l autre'; END IF;

  -- ===========================================================================================
  -- UNE SEULE VOIX SUFFIT -- AUCUN QUORUM N'EXISTE
  -- ===========================================================================================
  DELETE FROM public.assemblee_presidence_tirage_vu;
  DELETE FROM public.assemblee_presidence_bulletins;
  DELETE FROM public.assemblee_presidence_scrutins;
  INSERT INTO public.assemblee_presidence_scrutins (id, pays, cause, cloture_ts, eligibles)
  SELECT 'banc-scrutin-2', 'republic', 'renouvellement', now() + interval '1 hour',
         coalesce(jsonb_agg(jsonb_build_object('depute', e.depute, 'ville', e.ville,
                            'rang', e.rang, 'est_pnj', e.est_pnj) ORDER BY e.ville, e.rang), '[]'::jsonb)
    FROM public.assemblee_presidence_eligibles('republic') e;

  n := n + 1;
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.assemblee_presidence_voter(PNJ_B, 'rq-banc3-seul-001');
  PERFORM pg_temp.je_suis_le_serveur();
  IF v->>'ok' <> 'true' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE30 le vote unique a echoue : ' || v::text; END IF;

  n := n + 1;   -- UNE VOIX, UN President. Aucun seuil de participation n'a ete invente.
  UPDATE public.assemblee_presidence_scrutins SET cloture_ts = now() - interval '1 minute'
   WHERE id = 'banc-scrutin-2';
  v := public.assemblee_presidence_depouiller('republic');
  IF v->>'elu' <> PNJ_B OR coalesce(v->>'egalite','null') <> 'null' OR (v->>'voix')::int <> 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE31 une seule voix n a pas suffi : ' || v::text; END IF;

  n := n + 1;
  IF public.assemblee_president('republic') <> PNJ_B THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE32 le PNJ elu n est pas au registre'; END IF;

  n := n + 1;   -- UN PNJ PRESIDENT : AUCUN JOUEUR NE DETIENT SES POUVOIRS.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.assemblee_seance(5);
  PERFORM pg_temp.je_suis_le_serveur();
  IF v->>'je_suis_le_president' <> 'false' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE33 un joueur se croit President alors qu un PNJ l est'; END IF;

  -- ===========================================================================================
  -- ZERO VOTANT : CONSEQUENCE MECANIQUE DE LA REGLE D'EGALITE, PAS UN QUORUM
  -- ===========================================================================================
  DELETE FROM public.assemblee_presidence_bulletins;
  DELETE FROM public.assemblee_presidence_scrutins;
  INSERT INTO public.assemblee_presidence_scrutins (id, pays, cause, cloture_ts, eligibles)
  SELECT 'banc-scrutin-3', 'republic', 'renouvellement', now() - interval '1 minute',
         coalesce(jsonb_agg(jsonb_build_object('depute', e.depute, 'ville', e.ville,
                            'rang', e.rang, 'est_pnj', e.est_pnj) ORDER BY e.ville, e.rang), '[]'::jsonb)
    FROM public.assemblee_presidence_eligibles('republic') e;

  n := n + 1;   -- LES NEUF SONT A EGALITE A ZERO VOIX, ET LA COURTE PAILLE LES DEPARTAGE TOUS.
  v := public.assemblee_presidence_depouiller('republic');
  IF v->>'depouille' <> 'true' OR jsonb_array_length(v->'egalite') <> 9
     OR (v->>'voix')::int <> 0 OR coalesce(v->>'elu','') = '' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE34 zero votant : ' || v::text; END IF;

  n := n + 1;   -- ET LA PRESIDENCE N'EST JAMAIS LAISSEE VACANTE : toute la seance en depend.
  IF public.assemblee_president('republic') IS NULL THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE35 la presidence est restee vacante apres un scrutin sans votant'; END IF;

  -- ===========================================================================================
  IF ko > 0 THEN
    RAISE EXCEPTION 'banc presidence : % ECHEC(S) SUR % EPREUVES.%', ko, n, v_echecs;
  END IF;
  RAISE EXCEPTION 'banc presidence : LES % EPREUVES SONT VERTES. -- rien ne doit rester', n;
END $banc$;
ROLLBACK;
