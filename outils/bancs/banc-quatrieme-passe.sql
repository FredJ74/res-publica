-- BANC DE LA QUATRIEME PASSE DE L'ASSEMBLEE NATIONALE (11 octobre 2026)
--
-- CE BANC NE COMMITE RIEN. Il forge un decor complet -- un President joueur qui est AUSSI depute,
-- deux autres deputes, un non-depute, un texte en session avec des bulletins deja deposes -- joue
-- les quatre regles de la quatrieme passe, et se termine par un RAISE EXCEPTION INCONDITIONNEL.
--
-- CE QU'IL PROUVE, ARBITRAGE PAR ARBITRAGE :
--
-- §1 LAROCHE EST L'UN DES NEUF
--   . neuf sieges exactement, trois par ville, et Laroche est l'un des trois de Luthecia ;
--   . il n'existe aucun dixieme parlementaire : les eligibles a la presidence sont exactement les
--     titulaires des neuf sieges, et personne d'autre ;
--   . elu President, il reste depute -- la proclamation ne touche ni son siege ni le registre des
--     sieges ; et quand il perd la presidence, son siege est toujours la.
--
-- §2 ZERO VOTANT (confirmation de la troisieme passe)
--   . neuf candidats a zero voix, tous ex aequo, un seul gagnant tire par le serveur, et le
--     resultat ne bouge plus : un second depouillement rend le meme elu.
--
-- §3 LE BOYCOTT NE FERME PAS LE DEBAT
--   . pendant un boycott de cinq protestataires qualifies, la parole et le debat FONCTIONNENT ;
--   . mais un scrutin echu n'est pas conclu : son echeance est repoussee ;
--   . alors qu'une suspension presidentielle, elle, arrete bien la parole, le debat, le rappel et
--     la sanction. La difference est tenue, et elle est prouvee dans les deux sens.
--
-- §4 LE SEUIL D'UNE HEURE
--   . une suspension de moins d'une heure ne touche AUCUNE echeance ;
--   . une suspension qui depasse l'heure renvoie le texte a la prochaine session (statut
--     'renvoyee', cloture_ts NULL), annule les bulletins deja deposes, et le scrutin repart de
--     zero a la prochaine ouverture avec un numero de session neuf ;
--   . le renvoi est trace comme renvoi POUR SUSPENSION, il n'ecrit rien dans le registre du
--     report volontaire, et le droit du President de repousser un vote d'une semaine reste
--     entier -- puis verrouille a une seule fois par texte, numero de session ou non ;
--   . le calcul est SERVEUR : la duree est lue sur ouverte_le / close_le, aucune duree n'est
--     acceptee en parametre, et la porte de renvoi n'est accordee a aucun role client ;
--   . une suspension deja reprise mais qui avait depasse l'heure est renvoyee quand meme : on ne
--     s'en sort pas en reprenant juste avant le passage du cron.
--
-- §5 ON N'ELIT PAS SON PRESIDENT DEPUIS LE HALL
--   . un depute dans le hall : refuse (hors_hemicycle) ; ailleurs dans le monde : refuse ;
--   . dans l'hemicycle : accepte ;
--   . la position est lue en base et la porte n'accepte aucune piece declaree ;
--   . et la regle vaut pour une election exceptionnelle apres deux boycotts, parce que c'est la
--     MEME porte -- prouve en jouant un scrutin de cause 'deux_boycotts'.
--
-- §6 LE CUMUL DEPUTE + PRESIDENT
--   . le President reste depute, et changer de President ne detruit aucun siege.
--
-- Usage : coller ce fichier dans un execute_sql. Il doit finir sur
--   ERROR: banc 4e passe : LES 53 EPREUVES SONT VERTES. -- rien ne doit rester

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
  TEXTE   text := 'banc4-proposition';
  v jsonb; n integer := 0; ko integer := 0; v_echecs text := '';
  v_n integer; v_txt text; v_statut text; v_sess integer;
  v_cloture timestamptz; v_cloture2 timestamptz; v_sus text; v_elu text; v_elu2 text;
BEGIN
  PERFORM pg_temp.je_suis_le_serveur();

  -- ===========================================================================================
  -- §1 : LA COMPOSITION, AVANT TOUT DECOR
  -- ===========================================================================================
  n := n + 1;   -- NEUF SIEGES, exactement.
  SELECT count(*) INTO v_n FROM public.assemblee_sieges WHERE country = 'republic';
  IF v_n <> 9 THEN ko := ko + 1; v_echecs := v_echecs || E'\nE1 ' || v_n || ' sieges au lieu de 9'; END IF;

  n := n + 1;   -- TROIS PAR VILLE, sur trois villes.
  SELECT count(*) INTO v_n FROM (
    SELECT city FROM public.assemblee_sieges WHERE country = 'republic'
     GROUP BY city HAVING count(*) = 3) z;
  IF v_n <> 3 THEN ko := ko + 1; v_echecs := v_echecs || E'\nE2 ' || v_n || ' villes a 3 sieges'; END IF;

  n := n + 1;   -- LAROCHE EST L'UN DES TROIS DE LUTHECIA.
  IF NOT EXISTS (SELECT 1 FROM public.assemblee_sieges
                  WHERE country='republic' AND city='capitale' AND pnj_nom = LAROCHE) THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE3 Laroche n est pas depute de Luthecia'; END IF;

  n := n + 1;   -- ET IL N'Y FIGURE QU'UNE FOIS : pas de siege dedouble.
  SELECT count(*) INTO v_n FROM public.assemblee_sieges WHERE pnj_nom = LAROCHE;
  IF v_n <> 1 THEN ko := ko + 1; v_echecs := v_echecs || E'\nE4 ' || v_n || ' sieges pour Laroche'; END IF;

  n := n + 1;   -- AUCUN DIXIEME PARLEMENTAIRE. Les eligibles a la presidence sont EXACTEMENT les
  --              titulaires des neuf sieges -- ni plus, ni autre chose.
  SELECT count(*) INTO v_n FROM (
    SELECT e.depute FROM public.assemblee_presidence_eligibles('republic') e
    EXCEPT
    SELECT coalesce(o.pj_nom, o.pnj_nom) FROM public.assemblee_occupation_sieges('republic') o) z;
  IF v_n <> 0 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE5 ' || v_n || ' eligible(s) hors des neuf sieges'; END IF;

  -- ===========================================================================================
  -- DECOR : UN PRESIDENT JOUEUR QUI EST AUSSI DEPUTE, CINQ AUTRES DEPUTES, UN NON-DEPUTE
  -- ===========================================================================================
  -- UN SEUL depute joueur a Luthecia : les rangs 2 et 3 restent PNJ, donc Laroche garde son
  -- siege et reste eligible. C'est ce qui permet de l'elire plus bas.
  UPDATE public.cycles_electoraux SET data = '{"elus":["Lee Capene"]}'
   WHERE country='republic' AND poste_id='depute' AND city='capitale';
  UPDATE public.cycles_electoraux SET data = '{"elus":["Marsault","Phileas Frogg","Ben"]}'
   WHERE country='republic' AND poste_id='depute' AND city='ville_a';
  UPDATE public.cycles_electoraux SET data = '{"elus":["May","Bartesto Chevara","Arnie"]}'
   WHERE country='republic' AND poste_id='depute' AND city='ville_b';
  UPDATE public.personnages_donnees SET poste_depute = jsonb_build_object('id','depute','city','capitale')
   WHERE name = LEE;
  UPDATE public.personnages_donnees SET poste_depute = jsonb_build_object('id','depute','city','ville_a')
   WHERE name IN (MARS, PHIL, BEN);
  UPDATE public.personnages_donnees SET poste_depute = jsonb_build_object('id','depute','city','ville_b')
   WHERE name IN (MAY, BART, ARNIE);
  UPDATE public.personnages_donnees
     SET current_city='capitale', current_building='assemblee', current_room='hemicycle'
   WHERE name IN (LEE, MARS, PHIL, BEN, MAY, BART, ARNIE);

  -- UNE SEULE LIGNE DE PRESIDENCE, ET ON LA POSE A NEUF. assemblee_president() lit la premiere
  -- ligne trouvee : laisser deux titulaires au registre rendrait tout le banc indecidable.
  DELETE FROM public.postes_attribues
   WHERE country='republic' AND poste_id='president_assemblee' AND city IS NULL;
  INSERT INTO public.postes_attribues (id, country, poste_id, city, titulaire, source)
  VALUES ('banc4-presidence', 'republic', 'president_assemblee', NULL, LEE, 'banc');

  n := n + 1;   -- SEPT DEPUTES JOUEURS, DEUX SIEGES ENCORE PNJ -- dont celui de Laroche.
  SELECT count(*) INTO v_n FROM public.assemblee_occupation_sieges('republic') o WHERE NOT o.est_pnj;
  IF v_n <> 7 THEN ko := ko + 1; v_echecs := v_echecs || E'\nE6 ' || v_n || ' sieges PJ sur 7'; END IF;

  n := n + 1;   -- §6 : LE PRESIDENT EST DEPUTE, ET IL LE RESTE. Deux qualites, deux registres :
  --              postes_attribues pour la fonction, poste_depute + les sieges pour le mandat.
  IF public.assemblee_president('republic') IS DISTINCT FROM LEE
     OR NOT public.assemblee_est_depute('republic', LEE) THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE7 le President n est pas simultanement depute'; END IF;

  -- ===========================================================================================
  -- §5 : ON N'ELIT PAS SON PRESIDENT DEPUIS LE HALL
  -- ===========================================================================================
  INSERT INTO public.assemblee_presidence_scrutins (id, pays, cause, cloture_ts, eligibles, statut)
  SELECT 'banc4-scrutin', 'republic', 'renouvellement', now() + interval '2 hours',
         coalesce(jsonb_agg(jsonb_build_object('depute', e.depute, 'ville', e.ville,
                   'rang', e.rang, 'est_pnj', e.est_pnj) ORDER BY e.ville, e.rang), '[]'::jsonb),
         'ouvert'
    FROM public.assemblee_presidence_eligibles('republic') e;

  n := n + 1;   -- DANS L'HEMICYCLE : ACCEPTE.
  PERFORM pg_temp.je_suis(MARS_U);
  v := public.assemblee_presidence_voter(LAROCHE, 'rq-banc4-vote-mars');
  IF v->>'ok' <> 'true' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE8 un depute present n a pas pu voter : ' || v::text; END IF;

  n := n + 1;   -- DEPUIS LE HALL : REFUSE. La piece compte, pas le batiment.
  PERFORM pg_temp.je_suis_le_serveur();
  UPDATE public.personnages_donnees SET current_room='accueil_assemblee' WHERE name = PHIL;
  PERFORM pg_temp.je_suis(PHIL_U);
  v := public.assemblee_presidence_voter(LAROCHE, 'rq-banc4-vote-phil');
  IF coalesce(v->>'raison','') <> 'hors_hemicycle' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE9 vote accepte depuis le hall : ' || v::text; END IF;

  n := n + 1;   -- ET AUCUN BULLETIN N'A ETE DEPOSE : le refus precede l'ecriture.
  PERFORM pg_temp.je_suis_le_serveur();
  IF EXISTS (SELECT 1 FROM public.assemblee_presidence_bulletins
              WHERE scrutin_id='banc4-scrutin' AND votant = PHIL) THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE10 un bulletin a ete depose depuis le hall'; END IF;

  n := n + 1;   -- AILLEURS DANS LE MONDE : REFUSE AUSSI.
  UPDATE public.personnages_donnees
     SET current_city='ville_a', current_building='hotel_ville', current_room='accueil'
   WHERE name = BEN;
  PERFORM pg_temp.je_suis(BEN_U);
  v := public.assemblee_presidence_voter(LAROCHE, 'rq-banc4-vote-ben');
  IF coalesce(v->>'raison','') <> 'hors_hemicycle' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE11 vote accepte depuis une autre ville : ' || v::text; END IF;

  n := n + 1;   -- REVENIR DANS L'HEMICYCLE SUFFIT : la regle est une position, pas une punition.
  PERFORM pg_temp.je_suis_le_serveur();
  UPDATE public.personnages_donnees
     SET current_city='capitale', current_building='assemblee', current_room='hemicycle'
   WHERE name = PHIL;
  PERFORM pg_temp.je_suis(PHIL_U);
  v := public.assemblee_presidence_voter(LAROCHE, 'rq-banc4-vote-phil2');
  IF v->>'ok' <> 'true' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE12 revenu dans l hemicycle, le vote est refuse : ' || v::text; END IF;

  n := n + 1;   -- UN NON-DEPUTE PRESENT S'ENTEND DIRE QU'IL N'EST PAS DEPUTE, pas qu'il est mal
  --              place : l'ordre des refus est une information, pas un hasard.
  PERFORM pg_temp.je_suis_le_serveur();
  UPDATE public.personnages_donnees SET poste_depute = NULL WHERE name = ARNIE;
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.assemblee_presidence_voter(LAROCHE, 'rq-banc4-vote-arnie');
  IF coalesce(v->>'raison','') <> 'pas_depute' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE13 un non-depute present : ' || v::text; END IF;

  n := n + 1;   -- LA PORTE N'ACCEPTE AUCUNE POSITION DECLAREE : deux parametres, et c'est tout.
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT pg_get_function_identity_arguments(p.oid) INTO v_txt
    FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname='public' AND p.proname='assemblee_presidence_voter';
  IF v_txt <> 'p_pour text, p_requete text' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE14 la porte de vote accepte : ' || v_txt; END IF;

  -- §1 : LAROCHE EST ELU, ET IL RESTE DEPUTE
  n := n + 1;
  UPDATE public.assemblee_presidence_scrutins SET cloture_ts = now() - interval '1 minute'
   WHERE id='banc4-scrutin';
  v := public.assemblee_presidence_depouiller('republic');
  IF v->>'elu' IS DISTINCT FROM LAROCHE THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE15 Laroche n a pas ete proclame : ' || v::text; END IF;

  n := n + 1;   -- UN PNJ DEPUTE PEUT DONC PRESIDER, et le registre le dit.
  IF public.assemblee_president('republic') IS DISTINCT FROM LAROCHE THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE16 le registre ne designe pas Laroche'; END IF;

  n := n + 1;   -- ET IL EST TOUJOURS DEPUTE DE LUTHECIA : la proclamation ne touche pas au siege.
  IF NOT EXISTS (SELECT 1 FROM public.assemblee_occupation_sieges('republic') o
                  WHERE o.est_pnj AND o.pnj_nom = LAROCHE AND o.city = 'capitale') THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE17 Laroche President a perdu son siege'; END IF;

  n := n + 1;   -- LEE A PERDU LA PRESIDENCE ET GARDE SON SIEGE : §1 dans l'autre sens.
  IF NOT public.assemblee_est_depute('republic', LEE) THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE18 l ancien President a perdu son mandat de depute'; END IF;

  n := n + 1;   -- §6 : CHANGER DE PRESIDENT NE DETRUIT AUCUN SIEGE.
  SELECT count(*) INTO v_n FROM public.assemblee_sieges WHERE country='republic';
  IF v_n <> 9 THEN ko := ko + 1; v_echecs := v_echecs || E'\nE19 ' || v_n || ' sieges apres un changement de President'; END IF;

  -- ===========================================================================================
  -- §5 bis : LA MEME REGLE POUR UNE ELECTION EXCEPTIONNELLE
  -- ===========================================================================================
  -- UNE SEULE PORTE POUR LES DEUX CAUSES : si la presence etait contournable par la cause du
  -- scrutin, ce bloc le montrerait. On rejoue donc le refus sur un scrutin 'deux_boycotts'.
  PERFORM pg_temp.je_suis_le_serveur();
  -- ON RETIRE LE SCRUTIN JOUE, ON NE LE « CLOT » PAS A LA MAIN : une contrainte de coherence
  -- exige qu'un scrutin clos porte son elu, son decompte et son heure de cloture. Le depouillement
  -- les a poses ; ce qui suit est du decor, et le decor se retire.
  DELETE FROM public.assemblee_presidence_bulletins WHERE scrutin_id='banc4-scrutin';
  DELETE FROM public.assemblee_presidence_scrutins WHERE id='banc4-scrutin';
  INSERT INTO public.assemblee_presidence_scrutins (id, pays, cause, cloture_ts, eligibles, statut)
  SELECT 'banc4-exceptionnel', 'republic', 'deux_boycotts', now() + interval '2 hours',
         coalesce(jsonb_agg(jsonb_build_object('depute', e.depute, 'ville', e.ville,
                   'rang', e.rang, 'est_pnj', e.est_pnj) ORDER BY e.ville, e.rang), '[]'::jsonb),
         'ouvert'
    FROM public.assemblee_presidence_eligibles('republic') e;

  n := n + 1;
  UPDATE public.personnages_donnees SET current_room='accueil_assemblee' WHERE name = MARS;
  PERFORM pg_temp.je_suis(MARS_U);
  v := public.assemblee_presidence_voter(LAROCHE, 'rq-banc4-exc-hall');
  IF coalesce(v->>'raison','') <> 'hors_hemicycle' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE20 election exceptionnelle : le hall suffit : ' || v::text; END IF;

  n := n + 1;
  PERFORM pg_temp.je_suis_le_serveur();
  UPDATE public.personnages_donnees SET current_room='hemicycle' WHERE name = MARS;
  PERFORM pg_temp.je_suis(MARS_U);
  v := public.assemblee_presidence_voter(LAROCHE, 'rq-banc4-exc-hemi');
  IF v->>'ok' <> 'true' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE21 election exceptionnelle : present et refuse : ' || v::text; END IF;

  -- ===========================================================================================
  -- §2 : ZERO VOTANT -- CONFIRMATION
  -- ===========================================================================================
  PERFORM pg_temp.je_suis_le_serveur();
  DELETE FROM public.assemblee_presidence_bulletins;
  DELETE FROM public.assemblee_presidence_scrutins WHERE id='banc4-exceptionnel';
  INSERT INTO public.assemblee_presidence_scrutins (id, pays, cause, cloture_ts, eligibles, statut)
  SELECT 'banc4-zero', 'republic', 'renouvellement', now() - interval '1 minute',
         coalesce(jsonb_agg(jsonb_build_object('depute', e.depute, 'ville', e.ville,
                   'rang', e.rang, 'est_pnj', e.est_pnj) ORDER BY e.ville, e.rang), '[]'::jsonb),
         'ouvert'
    FROM public.assemblee_presidence_eligibles('republic') e;

  n := n + 1;   -- NEUF A ZERO VOIX, TOUS EX AEQUO, ET UN GAGNANT QUAND MEME.
  v := public.assemblee_presidence_depouiller('republic');
  v_elu := v->>'elu';
  IF jsonb_array_length(v->'egalite') <> 9 OR (v->>'voix')::int <> 0 OR coalesce(v_elu,'') = '' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE22 zero votant : ' || v::text; END IF;

  n := n + 1;   -- UN SEUL GAGNANT, et il est l'un des neuf.
  IF NOT EXISTS (SELECT 1 FROM public.assemblee_presidence_eligibles('republic') e
                  WHERE e.depute = v_elu) THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE23 l elu du tirage n est pas l un des neuf : ' || coalesce(v_elu,'(null)'); END IF;

  n := n + 1;   -- LE RESULTAT NE BOUGE PLUS : un second depouillement ne retire pas la paille.
  v := public.assemblee_presidence_depouiller('republic');
  v_elu2 := coalesce(v->>'elu', (SELECT s.elu FROM public.assemblee_presidence_scrutins s WHERE s.id='banc4-zero'));
  IF v_elu2 IS DISTINCT FROM v_elu THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE24 le tirage a change au second depouillement : '
      || coalesce(v_elu,'?') || ' -> ' || coalesce(v_elu2,'?'); END IF;

  n := n + 1;   -- AUCUN BULLETIN N'A ETE FABRIQUE POUR LES PNJ.
  SELECT count(*) INTO v_n FROM public.assemblee_presidence_bulletins WHERE scrutin_id='banc4-zero';
  IF v_n <> 0 THEN ko := ko + 1; v_echecs := v_echecs || E'\nE25 ' || v_n || ' bulletin(s) fabrique(s)'; END IF;

  -- ===========================================================================================
  -- DECOR : UN TEXTE EN SESSION, AVEC DES BULLETINS DEJA DEPOSES
  -- ===========================================================================================
  -- LA PRESIDENCE REVIENT A LEE : la suite exige un President JOUEUR, qui puisse suspendre.
  -- Et une SEULE ligne, de nouveau : le depouillement a pu en ecrire une autre.
  DELETE FROM public.postes_attribues
   WHERE country='republic' AND poste_id='president_assemblee' AND city IS NULL;
  INSERT INTO public.postes_attribues (id, country, poste_id, city, titulaire, source)
  VALUES ('banc4-presidence-2', 'republic', 'president_assemblee', NULL, LEE, 'banc');
  UPDATE public.personnages_donnees SET poste_depute = jsonb_build_object('id','depute','city','ville_b')
   WHERE name = ARNIE;

  INSERT INTO public.assemblee_propositions
    (id, country, auteur, titre, type, categorie, texte_original, statut, session_num,
     depose_ts, eligible_session_ts, session_ouverte_ts, cloture_ts)
  -- type 'mecanique' + categorie : c'est la seule forme qu'une contrainte de coherence accepte
  -- avec une categorie, et 'loi' n'est pas un type connu de la table.
  VALUES (TEXTE, 'republic', LEE, 'Texte du banc de la quatrieme passe', 'mecanique', 'economie',
          'Texte original du banc.', 'session', 1,
          now() - interval '10 days', now() - interval '3 days',
          now() - interval '2 hours', now() + interval '3 days');

  INSERT INTO public.assemblee_votes (id, proposition_id, session_num, votant, city, choix) VALUES
    (TEXTE || ':1:' || MARS, TEXTE, 1, MARS, 'ville_a', 'POUR'),
    (TEXTE || ':1:' || PHIL, TEXTE, 1, PHIL, 'ville_a', 'POUR'),
    (TEXTE || ':1:' || MAY,  TEXTE, 1, MAY,  'ville_b', 'CONTRE');

  -- ===========================================================================================
  -- §4 : UNE SUSPENSION DE MOINS D'UNE HEURE NE TOUCHE RIEN
  -- ===========================================================================================
  SELECT cloture_ts INTO v_cloture FROM public.assemblee_propositions WHERE id = TEXTE;

  PERFORM pg_temp.je_suis(LEE_U);
  v := public.assemblee_suspendre_seance('Le banc suspend brievement.', 'rq-banc4-sus-courte');
  IF v->>'ok' <> 'true' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nDECOR suspension courte refusee : ' || v::text; END IF;

  PERFORM pg_temp.je_suis_le_serveur();
  -- 40 MINUTES : EN DECA DU SEUIL. On deplace l'ouverture, pas l'horloge : c'est la base qui
  -- mesure, et c'est exactement ce qu'on veut eprouver.
  UPDATE public.assemblee_suspensions SET ouverte_le = now() - interval '40 minutes'
   WHERE pays='republic' AND cause='presidence' AND close_le IS NULL
  RETURNING id INTO v_sus;

  n := n + 1;   -- LE FAIT EST RENDU : le seuil n'est PAS depasse.
  IF public.assemblee_suspension_depassee('republic') THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE26 40 minutes comptent comme un depassement'; END IF;

  n := n + 1;   -- ET L'APPLICATION NE RENVOIE RIEN.
  v := public.assemblee_suspension_appliquer_seuil('republic');
  IF (v->>'reportes')::int <> 0 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE27 une suspension de 40 minutes a renvoye : ' || v::text; END IF;

  n := n + 1;   -- L'ECHEANCE INITIALE DEMEURE, et le texte est toujours en session.
  SELECT statut, cloture_ts INTO v_statut, v_cloture2 FROM public.assemblee_propositions WHERE id = TEXTE;
  IF v_statut <> 'session' OR v_cloture2 IS DISTINCT FROM v_cloture THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE28 l echeance a bouge sous le seuil : ' || v_statut; END IF;

  n := n + 1;   -- ET LES TROIS BULLETINS SONT INTACTS.
  SELECT count(*) INTO v_n FROM public.assemblee_votes WHERE proposition_id = TEXTE;
  IF v_n <> 3 THEN ko := ko + 1; v_echecs := v_echecs || E'\nE29 ' || v_n || ' bulletins apres une suspension courte'; END IF;

  n := n + 1;   -- LA REPRISE SOUS LE SEUIL NE RENVOIE RIEN NON PLUS, et elle le dit.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.assemblee_reprendre_seance('rq-banc4-reprise-courte');
  IF v->>'ok' <> 'true' OR (v->'renvois'->>'reportes')::int <> 0
     OR v->>'seuil_depasse' <> 'false' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE30 reprise sous le seuil : ' || v::text; END IF;

  -- ===========================================================================================
  -- §3 : LE BOYCOTT NE FERME PAS LE DEBAT
  -- ===========================================================================================
  PERFORM pg_temp.je_suis_le_serveur();
  INSERT INTO public.assemblee_protestations (pays, depute, sorti_le, qualifie, motif_qualifiant)
  VALUES ('republic', MARS, now(), true, 'motif du banc'),
         ('republic', PHIL, now(), true, 'motif du banc'),
         ('republic', BEN,  now(), true, 'motif du banc'),
         ('republic', MAY,  now(), true, 'motif du banc'),
         ('republic', BART, now(), true, 'motif du banc');
  v := public.assemblee_recalculer_suspension('republic');

  n := n + 1;   -- LA SUSPENSION PAR BOYCOTT EST OUVERTE.
  IF NOT public.assemblee_suspendue('republic') THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE31 cinq protestataires n ont pas ouvert de boycott : ' || v::text; END IF;

  n := n + 1;   -- ET LA SEANCE N'EST PAS SUSPENDUE PAR LA PRESIDENCE : les deux etats sont distincts.
  IF public.assemblee_suspendue_par_la_presidence('republic') THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE32 un boycott passe pour une suspension presidentielle'; END IF;

  n := n + 1;   -- LA PAROLE FONCTIONNE PENDANT UN BOYCOTT. Eprouvee avec un depute qui n'est NI
  --              President NI protestataire : exactement « les deputes restes presents ».
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.assemblee_parole_demander();
  IF v->>'ok' <> 'true' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE33 la parole est refusee pendant un boycott : ' || v::text; END IF;

  n := n + 1;   -- LE DEBAT AUSSI : un boycott ne ferme pas la seance de debat.
  v := public.assemblee_debat_dire('Le banc parle pendant un boycott.', 'rq-banc4-debat-boycott');
  IF v->>'ok' <> 'true' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE34 le debat est ferme pendant un boycott : ' || v::text; END IF;

  n := n + 1;   -- MAIS UN SCRUTIN ECHU N'EST PAS CONCLU : son echeance est repoussee.
  PERFORM pg_temp.je_suis_le_serveur();
  UPDATE public.assemblee_propositions SET cloture_ts = now() - interval '1 minute' WHERE id = TEXTE;
  v := public.assemblee_reporter_si_suspendue('republic');
  IF (v->>'reportes')::int <> 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE35 le boycott n a pas repousse le scrutin echu : ' || v::text; END IF;

  n := n + 1;   -- ET LE TEXTE EST TOUJOURS EN SESSION, bulletins compris : un boycott REPOUSSE,
  --              il n'annule pas. C'est toute la difference avec le seuil d'une heure.
  SELECT statut INTO v_statut FROM public.assemblee_propositions WHERE id = TEXTE;
  SELECT count(*) INTO v_n FROM public.assemblee_votes WHERE proposition_id = TEXTE;
  IF v_statut <> 'session' OR v_n <> 3 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE36 le boycott a annule des suffrages : ' || v_statut || ' / ' || v_n; END IF;

  -- LA SUSPENSION PRESIDENTIELLE, ELLE, ARRETE BIEN LA SEANCE
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.assemblee_suspendre_seance('Le banc suspend longuement.', 'rq-banc4-sus-longue');
  IF v->>'ok' <> 'true' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nDECOR suspension longue refusee : ' || v::text; END IF;

  n := n + 1;   -- LA PAROLE EST REFUSEE. MEME depute qu'en E33 : seule la suspension a change,
  --              donc c'est bien elle qui ferme la seance, et non une particularite du votant.
  PERFORM pg_temp.je_suis(ARNIE_U);
  v := public.assemblee_parole_demander();
  IF coalesce(v->>'raison','') <> 'seance_suspendue' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE37 la parole passe sous suspension presidentielle : ' || v::text; END IF;

  n := n + 1;   -- LE DEBAT AUSSI.
  v := public.assemblee_debat_dire('Le banc ne devrait pas parler.', 'rq-banc4-debat-suspendu');
  IF coalesce(v->>'raison','') <> 'seance_suspendue' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE38 le debat passe sous suspension presidentielle : ' || v::text; END IF;

  n := n + 1;   -- ET LA DISCIPLINE. Exercee par le President, sur un depute present.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.assemblee_rappeler(ARNIE, 'Motif du banc, assez long pour etre recevable.', 'rq-banc4-rappel');
  IF coalesce(v->>'raison','') <> 'seance_suspendue' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE39 le rappel passe sous suspension presidentielle : ' || v::text; END IF;

  -- ===========================================================================================
  -- §4 : AU-DELA D'UNE HEURE, LE TEXTE EST RENVOYE ET LES SUFFRAGES ANNULES
  -- ===========================================================================================
  PERFORM pg_temp.je_suis_le_serveur();
  UPDATE public.assemblee_suspensions SET ouverte_le = now() - interval '95 minutes'
   WHERE pays='republic' AND cause='presidence' AND close_le IS NULL
  RETURNING id INTO v_sus;
  SELECT cloture_ts INTO v_cloture FROM public.assemblee_propositions WHERE id = TEXTE;

  n := n + 1;   -- LE FAIT EST RENDU : le seuil EST depasse, et il l'est sans qu'aucun client
  --              n'ait rien compte.
  IF NOT public.assemblee_suspension_depassee('republic') THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE40 95 minutes ne comptent pas comme un depassement'; END IF;

  n := n + 1;   -- LE RENVOI A LIEU, ET IL DIT COMBIEN DE BULLETINS IL ANNULE.
  v := public.assemblee_suspension_appliquer_seuil('republic');
  IF (v->>'reportes')::int <> 1 OR (v->>'bulletins_annules')::int <> 3 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE41 renvoi au-dela du seuil : ' || v::text; END IF;

  n := n + 1;   -- LE TEXTE EST RENVOYE A LA PROCHAINE SESSION : statut 'renvoyee', PLUS D'ECHEANCE.
  --              Aucune date n'est fabriquee ici -- c'est la fenetre d'ouverture qui la donnera.
  SELECT statut, cloture_ts, session_ouverte_ts INTO v_statut, v_cloture2, v_cloture
    FROM public.assemblee_propositions WHERE id = TEXTE;
  IF v_statut <> 'renvoyee' OR v_cloture2 IS NOT NULL OR v_cloture IS NOT NULL THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE42 le texte n est pas renvoye proprement : '
      || v_statut || ' / ' || coalesce(v_cloture2::text,'null'); END IF;

  n := n + 1;   -- LES SUFFRAGES DEJA EXPRIMES SONT ANNULES : il n'en reste aucun.
  SELECT count(*) INTO v_n FROM public.assemblee_votes WHERE proposition_id = TEXTE;
  IF v_n <> 0 THEN ko := ko + 1; v_echecs := v_echecs || E'\nE43 ' || v_n || ' suffrage(s) survivent au renvoi'; END IF;

  n := n + 1;   -- LE RENVOI EST TRACE, ET TRACE COMME RENVOI POUR SUSPENSION.
  IF NOT EXISTS (SELECT 1 FROM public.assemblee_reports_suspension r
                  WHERE r.proposition_id = TEXTE AND r.suspension_id = v_sus
                    AND r.session_annulee = 1 AND r.bulletins_annules = 3
                    AND r.suspension_duree > interval '1 hour') THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE44 le renvoi n est pas trace comme renvoi pour suspension'; END IF;

  n := n + 1;   -- IL N'A RIEN ECRIT DANS LE REGISTRE DU REPORT VOLONTAIRE : le droit du President
  --              n'est pas consomme.
  IF EXISTS (SELECT 1 FROM public.assemblee_reports WHERE proposition_id = TEXTE) THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE45 le renvoi a consomme le report volontaire'; END IF;

  n := n + 1;   -- UN SECOND PASSAGE NE RENVOIE PAS DEUX FOIS LA MEME SESSION.
  v := public.assemblee_suspension_appliquer_seuil('republic');
  IF (v->>'reportes')::int <> 0 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE46 second passage : ' || v::text; END IF;

  -- ===========================================================================================
  -- §4 : LE SCRUTIN REPART DE ZERO A LA PROCHAINE SESSION
  -- ===========================================================================================
  n := n + 1;   -- L'OUVERTURE SUIVANTE DONNE UN NUMERO DE SESSION NEUF ET UNE ECHEANCE NEUVE.
  --              La fenetre est mercredi 22h / jeudi : hors fenetre, la porte refuse, et c'est la
  --              regle -- l'epreuve verifie donc les deux sens, selon le jour ou le banc tourne.
  v := public.assemblee_ouvrir_session(TEXTE);
  IF public.assemblee_fenetre_ouverture(now()) THEN
    SELECT statut, session_num, cloture_ts INTO v_statut, v_sess, v_cloture2
      FROM public.assemblee_propositions WHERE id = TEXTE;
    IF v->>'ok' <> 'true' OR v_statut <> 'session' OR v_sess <> 2 OR v_cloture2 IS NULL THEN
      ko := ko + 1; v_echecs := v_echecs || E'\nE47 reouverture : ' || v::text; END IF;
  ELSE
    IF coalesce(v->>'raison','') <> 'hors_fenetre_ouverture' THEN
      ko := ko + 1; v_echecs := v_echecs || E'\nE47 hors fenetre, la reouverture est passee : ' || v::text; END IF;
    -- POUR POUVOIR EPROUVER LA SUITE N'IMPORTE QUEL JOUR, on pose la session a la main sous
    -- identite serveur : c'est le DECOR, pas la regle -- la regle vient d'etre eprouvee ci-dessus.
    UPDATE public.assemblee_propositions
       SET statut='session', session_num = 2, session_ouverte_ts = now(),
           cloture_ts = now() + interval '3 days'
     WHERE id = TEXTE;
  END IF;

  n := n + 1;   -- ET LE SCRUTIN EST VIDE : tous les deputes doivent voter de nouveau.
  SELECT count(*) INTO v_n FROM public.assemblee_votes WHERE proposition_id = TEXTE AND session_num = 2;
  IF v_n <> 0 THEN ko := ko + 1; v_echecs := v_echecs || E'\nE48 ' || v_n || ' voix survivent dans la session 2'; END IF;

  n := n + 1;   -- LE DROIT DE REPORT VOLONTAIRE DU PRESIDENT EST ENTIER : il n'a pas ete consomme
  --              par le renvoi, et il s'exerce sur la session neuve.
  PERFORM pg_temp.je_suis_le_serveur();
  DELETE FROM public.assemblee_protestations WHERE pays='republic';
  PERFORM public.assemblee_recalculer_suspension('republic');
  UPDATE public.assemblee_suspensions SET close_le = now() WHERE pays='republic' AND close_le IS NULL;
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.assemblee_reporter_vote(TEXTE, 'rq-banc4-report-volontaire');
  IF v->>'ok' <> 'true' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE49 le report volontaire a ete consomme par le renvoi : ' || v::text; END IF;

  n := n + 1;   -- ET IL NE S'ENCHAINE PAS : une seule fois par texte, numero de session ou non.
  v := public.assemblee_reporter_vote(TEXTE, 'rq-banc4-report-volontaire-2');
  IF coalesce(v->>'raison','') <> 'deja_reporte_une_fois' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE50 un second report volontaire est passe : ' || v::text; END IF;

  -- ===========================================================================================
  -- §4 : ON NE S'EN SORT PAS EN REPRENANT AVANT LE CRON
  -- ===========================================================================================
  PERFORM pg_temp.je_suis_le_serveur();
  UPDATE public.assemblee_propositions SET session_ouverte_ts = now() - interval '4 hours'
   WHERE id = TEXTE;
  INSERT INTO public.assemblee_suspensions (id, pays, cause, president, protestataires,
                                            ouverte_le, close_le)
  VALUES ('banc4-sus-close', 'republic', 'presidence', LEE, '[]'::jsonb,
          now() - interval '3 hours', now() - interval '80 minutes');

  n := n + 1;   -- LA SUSPENSION EST DEJA CLOSE, ET ELLE AVAIT DURE 100 MINUTES : le renvoi a lieu
  --              quand meme. La duree est lue sur close_le - ouverte_le, pas sur le present.
  v := public.assemblee_suspension_appliquer_seuil('republic');
  IF (v->>'reportes')::int <> 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE51 une suspension close de 100 minutes n a rien renvoye : ' || v::text; END IF;

  n := n + 1;   -- ET LE SEUIL N'EST PAS « DEPASSE » AU SENS DE L'ECRAN : plus rien ne court.
  IF public.assemblee_suspension_depassee('republic') THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE52 une suspension close est annoncee comme courante'; END IF;

  -- ===========================================================================================
  -- §4 : LA PORTE DE RENVOI N'EST PAS A LA MAIN DES JOUEURS
  -- ===========================================================================================
  n := n + 1;   -- LE GRANT ARRETE L'APPEL AVANT LE CORPS DE LA FONCTION, ce qui est plus fort
  --              qu'un refus interne : un joueur ne peut pas renvoyer un scrutin sur commande.
  BEGIN
    PERFORM pg_temp.je_suis(MARS_U);
    PERFORM public.assemblee_suspension_appliquer_seuil('republic');
    ko := ko + 1; v_echecs := v_echecs || E'\nE53 un joueur a pu appeler le renvoi';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  -- ===========================================================================================
  PERFORM pg_temp.je_suis_le_serveur();
  IF ko > 0 THEN
    RAISE EXCEPTION 'banc 4e passe : % ECHEC(S) SUR % EPREUVES.%', ko, n, v_echecs;
  END IF;
  RAISE EXCEPTION 'banc 4e passe : LES % EPREUVES SONT VERTES. -- rien ne doit rester', n;
END $banc$;
ROLLBACK;
