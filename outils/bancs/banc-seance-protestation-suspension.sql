-- BANC DE LA SEANCE : LA PROTESTATION, LE BOYCOTT, LE REPORT (11 octobre 2026)
--
-- CE BANC NE COMMITE RIEN. Il forge une presidence, six deputes attestes, un parti politique et un
-- parti etranger, joue un boycott complet, et se termine par un RAISE EXCEPTION INCONDITIONNEL.
--
-- CE QU'IL PROUVE :
--   . qu'une protestation DEPLACE vraiment le depute au hall, et qu'un retour l'annule ;
--   . que `qualifie` est calcule PAR LE SERVEUR -- acte subi soi-meme, ou subi par un depute du
--     MEME PARTI, relu en base et borne au pays -- et jamais recu du navigateur ;
--   . qu'une sortie sans motif qualifiant est enregistree mais NE COMPTE PAS ;
--   . que quatre protestataires qualifies ne suspendent rien et que cinq suspendent ;
--   . qu'un retour a quatre fait cesser la suspension ;
--   . QU'UN ALLER-RETOUR hall -> hemicycle -> hall NE FABRIQUE PAS un second episode, et qu'il faut
--     une dissolution COMPLETE du groupe pour qu'un episode neuf s'ouvre ;
--   . que deux episodes sont un FAIT rendu, et que rien ne se declenche a deux -- la presidence
--     reste intacte, puisque l'election qui la remplacerait n'est pas arbitree ;
--   . qu'un scrutin echu part d'une semaine CALENDAIRE tant que la seance est suspendue, et que ce
--     report automatique NE CONSOMME PAS la prerogative du President ;
--   . qu'un texte ne peut etre reporte qu'une fois par le President, qu'un rejeu n'est pas un faux
--     refus, et qu'un texte en debat n'a pas d'echeance a repousser ;
--   . qu'une suspension volontaire coute 20 points au President, n'est JAMAIS comptee comme un
--     boycott, et ne coute pas 40 points si la reponse se perd ;
--   . que les deux portes systeme -- recalcul du seuil, report du mercredi -- sont fermees aux joueurs.
--
-- Usage : coller ce fichier dans un execute_sql. Il doit finir sur
--   ERROR: banc protestation : LES 29 EPREUVES SONT VERTES. -- rien ne doit rester

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
  VINCE_U text := '585ae078-342b-435d-b187-93be52c8ccfb'; VINCE text := 'Vince Kubrick';
  v jsonb; n integer := 0; ko integer := 0; v_echecs text := '';
  v_n integer; v_pop numeric; v_pop2 numeric; v_piece text; v_c1 timestamptz; v_c2 timestamptz;
BEGIN
  PERFORM pg_temp.je_suis_le_serveur();

  -- ===========================================================================================
  -- DECOR : UNE PRESIDENCE, SIX DEPUTES, UN PARTI, UN PARTI ETRANGER
  -- ===========================================================================================
  INSERT INTO public.postes_attribues (id, country, poste_id, city, titulaire, source)
  VALUES ('banc-presidence-an', 'republic', 'president_assemblee', NULL, ARNIE, 'banc');
  UPDATE public.cycles_electoraux SET data = '{"elus":["Lee Capene","Marsault","Phileas Frogg"]}'
   WHERE country = 'republic' AND poste_id = 'depute' AND city = 'capitale';
  UPDATE public.cycles_electoraux SET data = '{"elus":["Ben","May","Bartesto Chevara"]}'
   WHERE country = 'republic' AND poste_id = 'depute' AND city = 'ville_a';
  UPDATE public.personnages_donnees SET poste_depute = jsonb_build_object('id','depute','city','capitale')
   WHERE name IN (LEE, MARS, PHIL);
  UPDATE public.personnages_donnees SET poste_depute = jsonb_build_object('id','depute','city','ville_a')
   WHERE name IN (BEN, MAY, BART);
  UPDATE public.personnages_donnees
     SET current_city = 'capitale', current_building = 'assemblee', current_room = 'hemicycle',
         resources = jsonb_set(coalesce(resources,'{}'::jsonb), '{pop}', '50'::jsonb)
   WHERE name IN (ARNIE, LEE, MARS, PHIL, BEN, MAY, BART);

  -- LE PARTI : cinq des six deputes. Bartesto n'y est pas -- c'est lui qui prouvera qu'une sortie
  -- sans motif qualifiant ne compte pas dans le seuil.
  INSERT INTO public.organisations (id, country_origine, data) VALUES
   ('banc-parti', 'republic',
    '{"id":"banc-parti","type":"politique","nom":"Union du Banc","country":"republic",'
    || '"chef":"Lee Capene","fondateur":"Lee Capene","membres":['
    || '{"nom":"Lee Capene"},{"nom":"Marsault"},{"nom":"Phileas Frogg"},{"nom":"Ben"},{"nom":"May"}]}');
  -- ET UN PARTI D'UN AUTRE EMPIRE, qui ne doit rien qualifier a Republia.
  INSERT INTO public.organisations (id, country_origine, data) VALUES
   ('banc-parti-etranger', 'narco',
    '{"id":"banc-parti-etranger","type":"politique","nom":"Etrangers","country":"narco",'
    || '"membres":[{"nom":"Bartesto Chevara"}]}');

  n := n + 1;   -- LE PARTI EST RELU EN BASE, ET BORNE AU PAYS.
  IF public.assemblee_parti_de('republic', LEE) IS DISTINCT FROM 'banc-parti'
     OR public.assemblee_parti_de('republic', BART) IS NOT NULL THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE1 le parti n est pas relu correctement : lee='
      || coalesce(public.assemblee_parti_de('republic', LEE),'(nul)') || ' bart='
      || coalesce(public.assemblee_parti_de('republic', BART),'(nul)');
  END IF;

  -- ===========================================================================================
  -- A. QUI PEUT PROTESTER, ET CE QUE CA DEPLACE VRAIMENT
  -- ===========================================================================================
  n := n + 1;   -- UN NON-DEPUTE NE PROTESTE PAS, meme assis dans l'hemicycle.
  UPDATE public.personnages_donnees
     SET current_city='capitale', current_building='assemblee', current_room='hemicycle'
   WHERE name = VINCE;
  PERFORM pg_temp.je_suis(VINCE_U); v := public.assemblee_protester();
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'pas_depute' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE2 un non-depute a proteste : ' || v::text; END IF;

  n := n + 1;   -- ON NE QUITTE PAS L'HEMICYCLE QUAND ON EST DEJA DEHORS.
  UPDATE public.personnages_donnees SET current_room='accueil_assemblee' WHERE name = BART;
  PERFORM pg_temp.je_suis(BART_U); v := public.assemblee_protester();
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'pas_dans_hemicycle' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE3 protestation depuis le hall : ' || v::text; END IF;
  UPDATE public.personnages_donnees SET current_room='hemicycle' WHERE name = BART;

  n := n + 1;   -- UNE SORTIE SANS MOTIF QUALIFIANT : ENREGISTREE, LE DEPLACEMENT EST REEL, MAIS
  --              ELLE N'EST PAS QUALIFIEE. Le serveur n'interdit pas de sortir pour rien.
  PERFORM pg_temp.je_suis(BART_U); v := public.assemblee_protester();
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT current_room INTO v_piece FROM public.personnages_donnees WHERE name = BART;
  IF v->>'ok' <> 'true' OR v->>'qualifie' <> 'false' OR v_piece <> 'accueil_assemblee' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE4 sortie non qualifiee : ' || v::text
      || ' piece=' || coalesce(v_piece,'(nulle)'); END IF;

  n := n + 1;   -- ET ELLE NE COMPTE PAS DANS LE SEUIL.
  IF (v->'seance'->>'qualifies')::int <> 0 OR (v->'seance'->>'dehors')::int <> 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE5 une sortie non qualifiee compte : ' || (v->'seance')::text; END IF;

  n := n + 1;   -- REVENIR EFFACE LA PROTESTATION ET REMET DANS L'HEMICYCLE.
  PERFORM pg_temp.je_suis(BART_U); v := public.assemblee_revenir();
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT current_room INTO v_piece FROM public.personnages_donnees WHERE name = BART;
  SELECT count(*) INTO v_n FROM public.assemblee_protestations p WHERE p.depute = BART;
  IF v->>'ok' <> 'true' OR v_piece <> 'hemicycle' OR v_n <> 0 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE6 retour incomplet : ' || v::text
      || ' piece=' || coalesce(v_piece,'(nulle)') || ' lignes=' || v_n; END IF;

  -- ===========================================================================================
  -- B. CE QUI QUALIFIE UNE PROTESTATION -- CALCULE PAR LE SERVEUR, JAMAIS RECU
  -- ===========================================================================================
  PERFORM pg_temp.je_suis(ARNIE_U);
  PERFORM public.assemblee_rappeler(LEE, 'Vous criez sans la parole.', 'rq-banc2-rappel-001');
  PERFORM pg_temp.je_suis_le_serveur();

  n := n + 1;   -- CELUI QUI A SUBI L'ACTE : QUALIFIE PAR LUI-MEME.
  PERFORM pg_temp.je_suis(LEE_U); v := public.assemblee_protester();
  PERFORM pg_temp.je_suis_le_serveur();
  IF v->>'qualifie' <> 'true' OR (v->>'motif') <> 'soi_meme' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE7 motif soi_meme : ' || v::text; END IF;

  n := n + 1;   -- UN CAMARADE DE PARTI : QUALIFIE PAR SOLIDARITE. Rien n'est automatique -- il a
  --              fallu qu'il clique.
  PERFORM pg_temp.je_suis(MARS_U); v := public.assemblee_protester();
  PERFORM pg_temp.je_suis_le_serveur();
  IF v->>'qualifie' <> 'true' OR (v->>'motif') <> 'parti' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE8 motif parti : ' || v::text; END IF;

  n := n + 1;   -- UN DEPUTE SANS PARTI DE CE PAYS : NON QUALIFIE, malgre le rappel d'un autre.
  PERFORM pg_temp.je_suis(BART_U); v := public.assemblee_protester();
  PERFORM pg_temp.je_suis_le_serveur();
  IF v->>'qualifie' <> 'false' OR (v->>'parti') IS NOT NULL THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE9 un depute sans parti a ete qualifie : ' || v::text; END IF;

  -- ===========================================================================================
  -- C. LE SEUIL DE CINQ, ET LES EPISODES DISTINCTS
  -- ===========================================================================================
  n := n + 1;   -- QUATRE QUALIFIES : AUCUNE SUSPENSION.
  PERFORM pg_temp.je_suis(PHIL_U); PERFORM public.assemblee_protester();
  PERFORM pg_temp.je_suis(BEN_U);  v := public.assemblee_protester();
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v->'seance'->>'qualifies')::int <> 4 OR (v->'seance'->>'suspendue') <> 'false'
     OR public.assemblee_suspendue('republic') THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE10 quatre qualifies suspendent deja : ' || (v->'seance')::text; END IF;

  n := n + 1;   -- CINQ QUALIFIES : LA SEANCE EST SUSPENDUE.
  PERFORM pg_temp.je_suis(MAY_U); v := public.assemblee_protester();
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v->'seance'->>'qualifies')::int <> 5 OR (v->'seance'->>'suspendue') <> 'true'
     OR NOT public.assemblee_suspendue('republic') THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE11 cinq qualifies ne suspendent pas : ' || (v->'seance')::text; END IF;

  n := n + 1;   -- UN SEUL EPISODE OUVERT.
  SELECT count(*) INTO v_n FROM public.assemblee_suspensions s
   WHERE s.pays='republic' AND s.cause='boycott';
  IF v_n <> 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE12 ' || v_n || ' episode(s) de boycott au lieu de 1'; END IF;

  n := n + 1;   -- RETOUR A QUATRE : LA SUSPENSION CESSE.
  PERFORM pg_temp.je_suis(MAY_U); v := public.assemblee_revenir();
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v->'seance'->>'suspendue') <> 'false' OR public.assemblee_suspendue('republic') THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE13 la suspension ne cesse pas a quatre : ' || (v->'seance')::text; END IF;

  n := n + 1;   -- LE MEME BOYCOTT NE SE RECOMPTE PAS. C'est tout l'arbitrage sur les episodes :
  --              un depute faisant hall -> hemicycle -> hall ne doit pas fabriquer d'episodes.
  PERFORM pg_temp.je_suis(MAY_U); v := public.assemblee_protester();
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT count(*) INTO v_n FROM public.assemblee_suspensions s
   WHERE s.pays='republic' AND s.cause='boycott';
  IF v_n <> 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE14 un aller-retour a fabrique un episode : ' || v_n
      || ' / ' || (v->'seance')::text; END IF;

  n := n + 1;   -- IL FAUT UNE DISSOLUTION COMPLETE DU GROUPE.
  PERFORM pg_temp.je_suis(LEE_U);  PERFORM public.assemblee_revenir();
  PERFORM pg_temp.je_suis(MARS_U); PERFORM public.assemblee_revenir();
  PERFORM pg_temp.je_suis(PHIL_U); PERFORM public.assemblee_revenir();
  PERFORM pg_temp.je_suis(BEN_U);  PERFORM public.assemblee_revenir();
  PERFORM pg_temp.je_suis(MAY_U);  PERFORM public.assemblee_revenir();
  PERFORM pg_temp.je_suis(BART_U); PERFORM public.assemblee_revenir();
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT count(*) INTO v_n FROM public.assemblee_protestations p WHERE p.pays='republic';
  IF v_n <> 0 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE15 la dissolution est incomplete : ' || v_n || ' sorti(s)'; END IF;

  n := n + 1;   -- ET ALORS SEULEMENT, UN SECOND EPISODE S'OUVRE.
  PERFORM pg_temp.je_suis(LEE_U);  PERFORM public.assemblee_protester();
  PERFORM pg_temp.je_suis(MARS_U); PERFORM public.assemblee_protester();
  PERFORM pg_temp.je_suis(PHIL_U); PERFORM public.assemblee_protester();
  PERFORM pg_temp.je_suis(BEN_U);  PERFORM public.assemblee_protester();
  PERFORM pg_temp.je_suis(MAY_U);  v := public.assemblee_protester();
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT count(*) INTO v_n FROM public.assemblee_suspensions s
   WHERE s.pays='republic' AND s.cause='boycott';
  IF v_n <> 2 OR NOT public.assemblee_suspendue('republic') THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE16 le second episode distinct manque : ' || v_n
      || ' / ' || (v->'seance')::text; END IF;

  n := n + 1;   -- DEUX EPISODES SONT UN FAIT RENDU, ET RIEN NE SE DECLENCHE : la presidence reste
  --              intacte, parce que l'election qui la remplacerait n'est PAS arbitree. Ouvrir une
  --              vacance sans moyen de la combler creerait un etat bloque.
  PERFORM pg_temp.je_suis(ARNIE_U); v := public.assemblee_seance(10);
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v->>'episodes_sous_cette_presidence')::int <> 2
     OR public.assemblee_president('republic') IS DISTINCT FROM ARNIE THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE17 le compteur ou la presidence a bouge : '
      || coalesce(v->>'episodes_sous_cette_presidence','?') || ' / '
      || coalesce(public.assemblee_president('republic'),'(vacante)'); END IF;

  -- ===========================================================================================
  -- D. LES REPORTS -- CELUI QUE LE BOYCOTT IMPOSE, ET CELUI QUE LE PRESIDENT DECIDE
  -- ===========================================================================================
  INSERT INTO public.assemblee_propositions
    (id, country, auteur, titre, type, texte_original, statut, session_num,
     eligible_session_ts, session_ouverte_ts, cloture_ts)
  VALUES ('banc2-echu', 'republic', LEE, 'Texte echu', 'rp', 'Corps du texte.', 'session', 1,
          now() - interval '14 days', now() - interval '7 days', now() - interval '1 hour'),
         ('banc2-futur', 'republic', LEE, 'Texte a venir', 'rp', 'Corps du texte.', 'session', 1,
          now() - interval '7 days', now() - interval '1 day', now() + interval '2 days'),
         ('banc2-debat', 'republic', LEE, 'Texte en debat', 'rp', 'Corps du texte.', 'debat', 0,
          now() + interval '7 days', NULL, NULL);

  n := n + 1;   -- TANT QUE LA SEANCE EST SUSPENDUE, UN SCRUTIN ECHU PART D'UNE SEMAINE CALENDAIRE.
  SELECT cloture_ts INTO v_c1 FROM public.assemblee_propositions WHERE id = 'banc2-echu';
  v := public.assemblee_reporter_si_suspendue('republic');
  SELECT cloture_ts INTO v_c2 FROM public.assemblee_propositions WHERE id = 'banc2-echu';
  IF (v->>'reportes')::int <> 1
     OR v_c2 <> ((v_c1 AT TIME ZONE 'Europe/Paris') + interval '7 days') AT TIME ZONE 'Europe/Paris' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE18 report automatique : ' || v::text
      || ' / ' || v_c1 || ' -> ' || v_c2; END IF;

  n := n + 1;   -- ET IL NE CONSOMME PAS LA PREROGATIVE DU PRESIDENT : ce n'est pas une decision,
  --              c'est une consequence.
  SELECT count(*) INTO v_n FROM public.assemblee_reports r;
  IF v_n <> 0 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE19 le report automatique a consomme la prerogative : ' || v_n; END IF;

  n := n + 1;   -- UN DEPUTE NE REPORTE RIEN.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.assemblee_reporter_vote('banc2-futur', 'rq-banc2-report-001');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'pas_le_president' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE20 un depute a reporte : ' || v::text; END IF;

  n := n + 1;   -- UN TEXTE EN DEBAT N'A PAS D'ECHEANCE A REPOUSSER, et le dire vaut mieux que
  --              deviner une date.
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.assemblee_reporter_vote('banc2-debat', 'rq-banc2-report-002');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'pas_en_session' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE21 un texte en debat a ete reporte : ' || v::text; END IF;

  n := n + 1;   -- LE REPORT PRESIDENTIEL : UNE SEMAINE CALENDAIRE DE PARIS, jamais +7 x 24 h.
  SELECT cloture_ts INTO v_c1 FROM public.assemblee_propositions WHERE id = 'banc2-futur';
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.assemblee_reporter_vote('banc2-futur', 'rq-banc2-report-003');
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT cloture_ts INTO v_c2 FROM public.assemblee_propositions WHERE id = 'banc2-futur';
  IF v->>'ok' <> 'true'
     OR v_c2 <> ((v_c1 AT TIME ZONE 'Europe/Paris') + interval '7 days') AT TIME ZONE 'Europe/Paris' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE22 report presidentiel : ' || v::text
      || ' / ' || v_c1 || ' -> ' || v_c2; END IF;

  n := n + 1;   -- UNE SEULE FOIS PAR TEXTE. La prerogative appartient au TEXTE, pas a l'homme.
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.assemblee_reporter_vote('banc2-futur', 'rq-banc2-report-004');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'deja_reporte_une_fois' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE23 deux reports du meme texte : ' || v::text; END IF;

  n := n + 1;   -- ET UN REJEU N'EST PAS UN FAUX REFUS : sans la clef, le President croyait son
  --              report perdu alors qu'il etait enregistre.
  SELECT cloture_ts INTO v_c1 FROM public.assemblee_propositions WHERE id = 'banc2-futur';
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.assemblee_reporter_vote('banc2-futur', 'rq-banc2-report-003');
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT cloture_ts INTO v_c2 FROM public.assemblee_propositions WHERE id = 'banc2-futur';
  IF v->>'rejeu' <> 'true' OR v_c2 <> v_c1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE24 rejeu du report : ' || v::text
      || ' / ' || v_c1 || ' -> ' || v_c2; END IF;

  -- ===========================================================================================
  -- E. LA SUSPENSION VOLONTAIRE DU PRESIDENT
  -- ===========================================================================================
  n := n + 1;
  UPDATE public.personnages_donnees
     SET resources = jsonb_set(coalesce(resources,'{}'::jsonb), '{pop}', '50'::jsonb)
   WHERE name = ARNIE;
  SELECT (resources->>'pop')::numeric INTO v_pop FROM public.personnages_donnees WHERE name = ARNIE;
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.assemblee_suspendre_seance('Le calme ne revient pas.', 'rq-banc2-suspension-001');
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT (resources->>'pop')::numeric INTO v_pop2 FROM public.personnages_donnees WHERE name = ARNIE;
  IF v->>'ok' <> 'true' OR v_pop2 <> v_pop - 20 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE25 suspension presidentielle : pop ' || v_pop
      || ' -> ' || v_pop2 || ' / ' || v::text; END IF;

  n := n + 1;   -- ELLE N'EST JAMAIS UN BOYCOTT, et ne compte pas parmi les deux episodes. ELLE
  --              RESTE OUVERTE, aussi : depuis la troisieme passe (11 octobre 2026), la suspension
  --              presidentielle PERSISTE jusqu'a ce que le President reprenne la seance -- elle
  --              n'est plus l'acte instantane de la deuxieme passe. Cette epreuve cherchait une
  --              ligne CLOSE et ne la trouvait plus : elle etait rouge depuis cette passe-la.
  --              Elle verifie desormais la verite d'aujourd'hui, et elle est plus forte --
  --              persistance ET non-comptage, au lieu du seul non-comptage.
  SELECT count(*) INTO v_n FROM public.assemblee_suspensions s
   WHERE s.pays='republic' AND s.cause='presidence' AND s.close_le IS NULL;
  PERFORM pg_temp.je_suis(ARNIE_U); v := public.assemblee_seance(10);
  PERFORM pg_temp.je_suis_le_serveur();
  IF v_n <> 1 OR (v->>'episodes_sous_cette_presidence')::int <> 2
     OR NOT public.assemblee_suspendue_par_la_presidence('republic') THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE26 la suspension presidentielle compte comme boycott '
      || 'ou ne persiste pas : ' || v_n || ' ouverte(s) / '
      || coalesce(v->>'episodes_sous_cette_presidence','?') || ' episode(s)'; END IF;

  n := n + 1;   -- ET UN REJEU NE COUTE PAS 40 POINTS.
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.assemblee_suspendre_seance('Le calme ne revient pas.', 'rq-banc2-suspension-001');
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT (resources->>'pop')::numeric INTO v_pop FROM public.personnages_donnees WHERE name = ARNIE;
  SELECT count(*) INTO v_n FROM public.assemblee_suspensions s WHERE s.requete = 'rq-banc2-suspension-001';
  IF v->>'rejeu' <> 'true' OR v_n <> 1 OR v_pop <> v_pop2 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE27 suspension rejouee : pop ' || v_pop2 || ' -> '
      || v_pop || ', ' || v_n || ' ligne(s)'; END IF;

  -- ===========================================================================================
  -- F. LES DEUX PORTES SYSTEME SONT FERMEES AUX JOUEURS
  -- ===========================================================================================
  n := n + 1;   -- Un joueur qui pourrait recalculer le seuil fabriquerait une suspension.
  BEGIN
    PERFORM set_config('role', 'authenticated', true);
    PERFORM public.assemblee_recalculer_suspension('republic');
    ko := ko + 1; v_echecs := v_echecs || E'\nE28 un joueur peut recalculer la suspension';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.je_suis_le_serveur();

  n := n + 1;   -- Un joueur qui pourrait reporter les echeances enterrerait les textes.
  BEGIN
    PERFORM set_config('role', 'authenticated', true);
    PERFORM public.assemblee_reporter_si_suspendue('republic');
    ko := ko + 1; v_echecs := v_echecs || E'\nE29 un joueur peut reporter les scrutins echus';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.je_suis_le_serveur();

  -- ===========================================================================================
  IF ko > 0 THEN
    RAISE EXCEPTION 'banc protestation : % ECHEC(S) SUR % EPREUVES.%', ko, n, v_echecs;
  END IF;
  RAISE EXCEPTION 'banc protestation : LES % EPREUVES SONT VERTES. -- rien ne doit rester', n;
END $banc$;
ROLLBACK;
