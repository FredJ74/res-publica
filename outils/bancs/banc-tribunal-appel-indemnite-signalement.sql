-- BANC DE L'APPEL, DE L'INDEMNISATION ET DU SIGNALEMENT (12 octobre 2026) -- 30 epreuves
--
-- CE BANC NE COMMITE RIEN. Il nomme un juge et un Procureur, joue un proces complet avec son
-- appel, fait purger des jours en reculant l'epoque, verifie les indemnites et leur file FIFO,
-- puis joue deux signalements -- un reussi, un sur une cible qui fuit -- et se termine par un
-- RAISE EXCEPTION INCONDITIONNEL qui annule tout.
--
-- POURQUOI IL EXISTE. Les 38 preuves des quatre migrations sont STRUCTURELLES. Aucune ne peut
-- prouver qu'une peine S'EXECUTE, qu'un appel N'ARRETE PAS la detention, que l'indemnite porte
-- sur les jours REELLEMENT purges, que la file paie l'aine AVANT le cadet, ni qu'une cible qui
-- change de piece pendant les dix secondes echappe a l'arrestation. Ca se joue.
--
-- CE QU'IL PROUVE :
--   1-4.   la sentence ouvre la detention elle-meme, et pas sans jours ni sur un deja-detenu ;
--   5-9.   l'appel : qui, quand, une seule fois, jamais en procedure simplifiee ;
--   10-14. l'appel n'est pas suspensif, la peine est re-basee, la liberation est immediate ;
--   15-18. l'indemnite porte sur les jours PURGES, pas sur l'ecart des jugements ;
--   19-24. la cascade Justice -> Finances, le tout-ou-rien, la dette, le FIFO strict ;
--   25-27. le declencheur d'alimentation, et aucune caisse negative ;
--   28-30. le signalement : la cible qui reste est arretee, celle qui fuit ne l'est pas.
--
-- Usage : coller ce fichier debarrasse de ses lignes de commentaire. Il doit finir sur
--   ERROR: banc tribunal 2 : LES 30 EPREUVES SONT VERTES. -- rien ne doit rester

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
  JUGE_U  text := 'a5a55fc8-64fa-4406-b617-76439d1d4aac'; JUGE  text := 'Marsault';
  LEE_U   text := 'ea4a2a0c-a192-4e10-8cff-d5db9b1cceb6'; LEE   text := 'Lee Capene';
  TIERS_U text := '0821bcdf-0c69-4ba3-adcd-f60d9b82b7bf'; TIERS text := 'Phileas Frogg';
  v jsonb; n integer := 0; ko integer := 0; e text := '';
  v_n integer; v_d jsonb; v_jour integer; v_num numeric; v_txt text;
  v_det record; v_arg1 numeric; v_arg2 numeric; v_leve boolean;
  A1 text := 'banc-ap-un'; A2 text := 'banc-ap-deux'; A3 text := 'banc-ap-simpl';
BEGIN
  PERFORM pg_temp.je_suis_le_serveur();
  v_jour := public.jour_de_jeu_pays('republic');

  -- DECOR : Marsault juge de la capitale (inscrit au registre AVANT la fiche, sinon le
  -- declencheur d'attestation refuse -- et c'est la garde qu'on veut laisser en place).
  INSERT INTO public.postes_attribues (id, country, poste_id, city, titulaire, source)
  VALUES ('banc-ap-juge', 'republic', 'juge', 'capitale', JUGE, 'banc');
  UPDATE public.personnages_donnees
     SET poste = jsonb_build_object('id','juge','city','capitale','name','Juge') WHERE name = JUGE;

  -- Un dossier SAISI contre Lee, qualifie assassiner_mains (8 j de reference, plage [4,12]).
  -- L'AUDIENCE EST OUVERTE DANS LE DECOR (verrou du 13 octobre 2026). Depuis ce verrou, aucune
  -- condamnation ni relaxe de procedure COMPLETE ne se rend avant que le proces ait eu lieu. Ce
  -- banc-ci n'eprouve pas la chaine de l'audience -- `banc-parcours-judiciaires` le fait, des
  -- deux cotes -- mais il ne peut plus l'ignorer : la cle `audience_ouverte_le` est donc posee au
  -- decor, exactement comme le statut l'est. C'est la PRESENCE de cette cle que
  -- `affaire_audience_ouverte` lit.
  INSERT INTO public.plaintes_en_cours (id, country, city, data) VALUES
    (A1, 'republic', 'capitale', jsonb_build_object('id', A1, 'auteur', TIERS, 'cible', LEE,
      'motif', 'Il a tue mon chien', 'jour', v_jour, 'city', 'capitale', 'country', 'republic',
      'status', 'saisie', 'qualification_parquet', 'assassiner_mains',
      'audience_ouverte_le', '2026-10-13T10:00:00Z')::text);

  -- =========================================================== L'EXECUTION IMMEDIATE
  n := n + 1;   -- T1 : LA SENTENCE OUVRE LA DETENTION ELLE-MEME. Sans commissaire joueur.
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.justice_rendre_sentence(A1, 'assassiner_mains', 'prison', 8, 0);
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT count(*) INTO v_n FROM public.detention_active(LEE);
  IF coalesce((v->>'ok')::boolean,false) IS NOT TRUE OR (v->>'executee') <> 'true' OR v_n <> 1 THEN
    ko:=ko+1; e:=e||E'\nT1 sentence non executoire : '||v::text||' / detentions '||v_n; END IF;

  n := n + 1;   -- T2 : LE JUGEMENT EST MARQUE EXECUTE AU REGISTRE.
  SELECT count(*) INTO v_n FROM public.jugements WHERE id = 'jug-'||A1 AND executee IS TRUE;
  IF v_n <> 1 THEN ko:=ko+1; e:=e||E'\nT2 jugement non marque execute'; END IF;

  n := n + 1;   -- T3 : LA FENETRE D'APPEL EST INSCRITE AU DOSSIER, a J+2.
  -- L'ECHEANCE EST SUR L'HORLOGE DU PAYS, pas sur le compteur du juge : c'est le correctif du
  -- 12 octobre, et le banc l'a impose. `jugement_jour` reste le compteur du juge, pour l'affichage.
  SELECT data::jsonb INTO v_d FROM public.plaintes_en_cours WHERE id = A1;
  IF (v_d->>'appel_jusqu_au_jour')::int <> public.jour_de_jeu_pays('republic') + 2
     OR (v_d->>'jugement_jour_pays')::int <> public.jour_de_jeu_pays('republic') THEN
    ko:=ko+1; e:=e||E'\nT3 fenetre d appel : '||v_d::text; END IF;

  n := n + 1;   -- T4 : LA DETENTION PORTE BIEN HUIT JOURS.
  SELECT * INTO v_det FROM public.detention_active(LEE);
  IF (v_det.jour_fin - v_det.jour_debut) <> 8 THEN
    ko:=ko+1; e:=e||E'\nT4 duree de detention : '||(v_det.jour_fin - v_det.jour_debut); END IF;

  -- =========================================================== QUI PEUT FAIRE APPEL
  n := n + 1;   -- T5 : UN TIERS NE PEUT PAS. Ni victime, ni plaignant : seuls le condamne et le
                --      parquet ont qualite.
  PERFORM pg_temp.je_suis(TIERS_U);
  v := public.justice_appel_ouvrir(A1);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'autorite_refusee' THEN
    ko:=ko+1; e:=e||E'\nT5 un tiers interjette appel : '||v::text; END IF;

  n := n + 1;   -- T6 : LE CONDAMNE PEUT, et l'appel s'ouvre.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.justice_appel_ouvrir(A1);
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT data::jsonb INTO v_d FROM public.plaintes_en_cours WHERE id = A1;
  IF coalesce((v->>'ok')::boolean,false) IS NOT TRUE OR (v->>'qualite') <> 'condamne'
     OR (v_d->>'status') <> 'appel' THEN
    ko:=ko+1; e:=e||E'\nT6 appel du condamne : '||v::text||' / '||v_d::text; END IF;

  n := n + 1;   -- T7 : UN SEUL APPEL PAR AFFAIRE, ET LE REFUS NOMME L'UNICITE.
  --
  -- UN SEUL MOTIF EST ACCEPTE DEPUIS LE 13 OCTOBRE 2026. La garde de l'UNICITE passe desormais
  -- AVANT celle du statut : le refus s'appelle `appel_deja_interjete`, et il dit la vraie raison.
  -- Avant, le dossier etant en statut `appel`, c'est la garde du STATUT qui repondait --
  -- `pas_de_jugement_de_premiere_instance`, sur une affaire qui en avait un. La dette
  -- d'ergonomie nommee ici le 12 octobre est payee ; l'epreuve exige le motif exact.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.justice_appel_ouvrir(A1);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') IS DISTINCT FROM 'appel_deja_interjete'
     OR coalesce((v->>'ok')::boolean, false) IS NOT FALSE THEN
    ko:=ko+1; e:=e||E'\nT7 second appel accepte : '||v::text; END IF;

  n := n + 1;   -- T8 : L'APPEL N'EST PAS SUSPENSIF. La detention court toujours.
  SELECT count(*) INTO v_n FROM public.detention_active(LEE);
  IF v_n <> 1 THEN ko:=ko+1; e:=e||E'\nT8 l appel a suspendu la detention'; END IF;

  n := n + 1;   -- T9 : UNE AFFAIRE DE PROCEDURE SIMPLIFIEE N'OUVRE AUCUN APPEL.
  INSERT INTO public.plaintes_en_cours (id, country, city, data) VALUES
    (A3, 'republic', 'capitale', jsonb_build_object('id', A3, 'auteur', TIERS, 'cible', LEE,
      'motif', 'Vol', 'jour', v_jour, 'city', 'capitale', 'country', 'republic',
      'status', 'jugee', 'procedure_simplifiee', true, 'appel_jusqu_au_jour', v_jour + 2)::text);
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.justice_appel_ouvrir(A3);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'appel_exclu_procedure_simplifiee' THEN
    ko:=ko+1; e:=e||E'\nT9 appel sur procedure simplifiee : '||v::text; END IF;

  -- =========================================================== LE TEMPS PASSE, DEUX JOURS PURGES
  n := n + 1;   -- T10 : DEUX JOURS SONT PURGES, ET C'EST LA FICHE DU DETENU QUI LES COMPTE.
  --
  -- LE BANC A APPRIS ICI QUE LE SYSTEME A DEUX HORLOGES. Sa premiere version faisait reculer
  -- `rp_epoques` -- l'horloge du PAYS -- et lisait 31 jours purges sur une detention de 8 jours.
  -- `detention_ouvrir_interne` pose `jour_debut` depuis le `day` DE LA FICHE DU DETENU, et
  -- `detention_clore_purgee` libere quand ce MEME compteur atteint `jour_fin` : c'est lui qui
  -- compte les journees de peine, et c'est donc lui qu'on avance.
  UPDATE public.personnages_donnees SET day = coalesce(day,1) + 2 WHERE name = LEE;
  SELECT * INTO v_det FROM public.detention_active(LEE);
  IF public.justice_jours_purges(v_det.id) <> 2 THEN
    ko:=ko+1; e:=e||E'\nT10 jours purges : '||public.justice_jours_purges(v_det.id); END IF;

  -- =========================================================== L'APPEL JUGE : PEINE REDUITE A 4
  n := n + 1;   -- T11 : QUATRE JOURS EN APPEL -> AUCUNE INDEMNITE, et il reste a purger.
  SELECT coalesce(arg,0) INTO v_arg1 FROM public.personnages_donnees WHERE name = LEE;
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.justice_appel_juger(A1, 'condamnation', 'assassiner_mains', 'prison', 4, 0);
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT coalesce(arg,0) INTO v_arg2 FROM public.personnages_donnees WHERE name = LEE;
  IF coalesce((v->>'ok')::boolean,false) IS NOT TRUE OR (v->>'jours_indus')::int <> 0
     OR (v->>'libere') <> 'false' OR v_arg2 <> v_arg1 THEN
    ko:=ko+1; e:=e||E'\nT11 appel a 4 jours : '||v::text||' / arg '||v_arg1||'->'||v_arg2; END IF;

  n := n + 1;   -- T12 : LA DETENTION EST RE-BASEE SUR LA PEINE DEFINITIVE.
  SELECT * INTO v_det FROM public.detention_active(LEE);
  IF (v_det.jour_fin - v_det.jour_debut) <> 4 THEN
    ko:=ko+1; e:=e||E'\nT12 detention non re-basee : '||(v_det.jour_fin - v_det.jour_debut); END IF;

  n := n + 1;   -- T13 : LE PREMIER JUGEMENT EST CONSERVE, A COTE DU SECOND.
  SELECT count(*) INTO v_n FROM public.jugements WHERE id IN ('jug-'||A1, 'jug-app-'||A1);
  IF v_n <> 2 THEN ko:=ko+1; e:=e||E'\nT13 jugements au registre : '||v_n||' au lieu de 2'; END IF;

  n := n + 1;   -- T14 : L'APPEL EST DEFINITIF : on ne le juge pas deux fois.
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.justice_appel_juger(A1, 'relaxe');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') NOT IN ('pas_en_appel','appel_deja_juge') THEN
    ko:=ko+1; e:=e||E'\nT14 appel rejuge : '||v::text; END IF;

  -- =========================================================== LA RELAXE EN APPEL ET L'INDEMNITE
  -- Un second dossier, juge a 8 jours, deux jours purges, puis RELAXE en appel.
  PERFORM public.detention_clore_interne(LEE, 'fin_de_banc', public.jour_de_jeu_pays('republic'));
  INSERT INTO public.plaintes_en_cours (id, country, city, data) VALUES
    (A2, 'republic', 'capitale', jsonb_build_object('id', A2, 'auteur', TIERS, 'cible', LEE,
      'motif', 'Encore', 'jour', v_jour, 'city', 'capitale', 'country', 'republic',
      'status', 'saisie', 'qualification_parquet', 'assassiner_mains',
      'audience_ouverte_le', '2026-10-13T10:00:00Z')::text);
  -- La caisse de la Justice est dotee largement : elle doit payer l'integralite.
  UPDATE public.caisses_batiments SET data = jsonb_build_object('solde', 50000)
   WHERE id = 'republic_gouvernement-min_just';
  PERFORM pg_temp.je_suis(JUGE_U);
  PERFORM public.justice_rendre_sentence(A2, 'assassiner_mains', 'prison', 8, 0);
  -- L'APPEL EST INTERJETE PAR LE CONDAMNE, ET LE DECOR L'AVAIT OUBLIE. Jusqu'au 12 octobre 2026
  -- au soir, cette ligne appelait `justice_appel_ouvrir` SANS changer d'identite : c'est donc le
  -- juge qui interjetait appel de son propre jugement. Le resultat n'etait pas verifie, et le
  -- refus passait inapercu jusqu'a T15 -- qui tombait quatre epreuves plus loin, sur une affaire
  -- restee `jugee`. Le refus etait le bon : depuis que l'autorite du parquet se lit par
  -- `parquet_moi()`, un juge n'est plus confondu avec un procureur. Le decor est corrige, et le
  -- resultat est desormais MESURE ici, la ou il est produit.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.justice_appel_ouvrir(A2);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v->>'ok')::boolean,false) IS NOT TRUE OR (v->>'qualite') <> 'condamne' THEN
    ko:=ko+1; e:=e||E'\nT14b l appel du condamne sur la seconde affaire : '||v::text; END IF;
  UPDATE public.personnages_donnees SET day = coalesce(day,1) + 2 WHERE name = LEE;

  n := n + 1;   -- T15 : RELAXE EN APPEL -> DEUX JOURS INDUS, LIBERATION IMMEDIATE.
  SELECT coalesce(arg,0) INTO v_arg1 FROM public.personnages_donnees WHERE name = LEE;
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.justice_appel_juger(A2, 'relaxe');
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT coalesce(arg,0) INTO v_arg2 FROM public.personnages_donnees WHERE name = LEE;
  SELECT count(*) INTO v_n FROM public.detention_active(LEE);
  IF coalesce((v->>'ok')::boolean,false) IS NOT TRUE OR (v->>'jours_indus')::int <> 2
     OR (v->>'libere') <> 'true' OR v_n <> 0 THEN
    ko:=ko+1; e:=e||E'\nT15 relaxe en appel : '||v::text||' / detentions '||v_n; END IF;

  n := n + 1;   -- T16 : DEUX MILLE FRANCS, PAYES PAR LA JUSTICE, ET RECUS.
  IF (v_arg2 - v_arg1) <> 2000 THEN
    ko:=ko+1; e:=e||E'\nT16 indemnite recue : '||(v_arg2 - v_arg1)||' FR au lieu de 2000'; END IF;

  n := n + 1;   -- T17 : LA CREANCE EST REGLEE ET PORTEE PAR LA JUSTICE.
  SELECT count(*) INTO v_n FROM public.justice_indemnites
   WHERE affaire = A2 AND porteur = 'min_just' AND etat = 'reglee'
     AND montant_du = 2000 AND montant_paye = 2000 AND jours_indus = 2;
  IF v_n <> 1 THEN ko:=ko+1; e:=e||E'\nT17 creance de la Justice : '||v_n||' ligne(s)'; END IF;

  n := n + 1;   -- T18 : L'INDEMNISATION EST CONSIGNEE A LA CHRONOLOGIE.
  SELECT count(*) INTO v_n FROM public.dossiers_judiciaires_actes
   WHERE affaire = A2 AND type = 'indemnisation' AND (donnees->>'jours_indus')::int = 2;
  IF v_n <> 1 THEN ko:=ko+1; e:=e||E'\nT18 indemnisation non consignee'; END IF;

  -- =========================================================== LA CASCADE ET LE FIFO
  n := n + 1;   -- T19 : LA JUSTICE A ZERO -> LA CREANCE PASSE AUX FINANCES, SANS RIEN PRELEVER.
  UPDATE public.caisses_batiments SET data = jsonb_build_object('solde', 500)
   WHERE id = 'republic_gouvernement-min_just';
  UPDATE public.caisses_batiments SET data = jsonb_build_object('solde', 0)
   WHERE id = 'republic_gouvernement-min_fin';
  v := public.justice_indemnite_naitre('republic', LEE, 'banc-cr-1', 'jug-banc-1', 3);
  SELECT (data->>'solde')::numeric INTO v_num FROM public.caisses_batiments
   WHERE id = 'republic_gouvernement-min_just';
  IF (v->>'porteur') <> 'min_fin' OR (v->>'paye')::int <> 0 OR v_num <> 500 THEN
    ko:=ko+1; e:=e||E'\nT19 cascade Justice->Finances : '||v::text||' / justice '||v_num; END IF;

  n := n + 1;   -- T20 : LA DETTE EST INSCRITE, DUE, PORTEE PAR LES FINANCES.
  SELECT count(*) INTO v_n FROM public.justice_indemnites
   WHERE affaire = 'banc-cr-1' AND porteur = 'min_fin' AND etat = 'due' AND montant_du = 3000;
  IF v_n <> 1 THEN ko:=ko+1; e:=e||E'\nT20 dette non inscrite : '||v_n; END IF;

  n := n + 1;   -- T21 : UNE SECONDE CREANCE, PLUS RECENTE, S'INSCRIT DERRIERE.
  PERFORM pg_sleep(0.01);
  v := public.justice_indemnite_naitre('republic', TIERS, 'banc-cr-2', 'jug-banc-2', 1);
  SELECT count(*) INTO v_n FROM public.justice_indemnites
   WHERE pays = 'republic' AND etat = 'due' AND porteur = 'min_fin';
  IF v_n <> 2 THEN ko:=ko+1; e:=e||E'\nT21 deux dettes attendues : '||v_n; END IF;

  n := n + 1;   -- T22 : UNE ALIMENTATION PARTIELLE PAIE L'AINE, ET LUI SEUL. 1 000 FR arrivent :
                --       ils vont entierement a la creance de 3 000, pas a celle de 1 000 qui
                --       pourrait etre soldee. C'est le FIFO STRICT.
  SELECT coalesce(arg,0) INTO v_arg1 FROM public.personnages_donnees WHERE name = TIERS;
  UPDATE public.caisses_batiments SET data = jsonb_build_object('solde', 1000)
   WHERE id = 'republic_gouvernement-min_fin';
  SELECT coalesce(arg,0) INTO v_arg2 FROM public.personnages_donnees WHERE name = TIERS;
  SELECT montant_paye INTO v_n FROM public.justice_indemnites WHERE affaire = 'banc-cr-1';
  IF v_n <> 1000 OR v_arg2 <> v_arg1 THEN
    ko:=ko+1; e:=e||E'\nT22 FIFO strict : aine paye '||v_n||', cadet '||v_arg1||'->'||v_arg2; END IF;

  n := n + 1;   -- T23 : LA CAISSE DES FINANCES EST A ZERO, JAMAIS NEGATIVE.
  SELECT (data->>'solde')::numeric INTO v_num FROM public.caisses_batiments
   WHERE id = 'republic_gouvernement-min_fin';
  IF v_num <> 0 THEN ko:=ko+1; e:=e||E'\nT23 caisse des Finances : '||v_num; END IF;

  n := n + 1;   -- T24 : UNE ALIMENTATION SUFFISANTE SOLDE L'AINE PUIS SERT LE CADET.
  UPDATE public.caisses_batiments SET data = jsonb_build_object('solde', 5000)
   WHERE id = 'republic_gouvernement-min_fin';
  SELECT count(*) INTO v_n FROM public.justice_indemnites
   WHERE pays = 'republic' AND porteur = 'min_fin' AND etat = 'due';
  IF v_n <> 0 THEN ko:=ko+1; e:=e||E'\nT24 dettes restantes : '||v_n; END IF;

  n := n + 1;   -- T25 : LES DEUX CREANCES SONT INTEGRALEMENT REGLEES.
  SELECT count(*) INTO v_n FROM public.justice_indemnites
   WHERE affaire IN ('banc-cr-1','banc-cr-2') AND etat = 'reglee' AND montant_paye = montant_du;
  IF v_n <> 2 THEN ko:=ko+1; e:=e||E'\nT25 creances reglees : '||v_n||' au lieu de 2'; END IF;

  n := n + 1;   -- T26 : LA CAISSE A ETE DEBITEE DU JUSTE MONTANT. 3 000 dus a l'aine moins les
                --       1 000 deja verses a T22, plus 1 000 au cadet : 3 000 sortent des 5 000.
                --       La premiere version de cette epreuve attendait 1 000 en oubliant le
                --       versement partiel de T22 -- l'arithmetique du banc etait fausse, pas la
                --       file.
  SELECT (data->>'solde')::numeric INTO v_num FROM public.caisses_batiments
   WHERE id = 'republic_gouvernement-min_fin';
  IF v_num <> 2000 THEN ko:=ko+1; e:=e||E'\nT26 solde des Finances : '||v_num||' au lieu de 2000'; END IF;

  n := n + 1;   -- T27 : UNE BAISSE DE LA CAISSE NE DECLENCHE RIEN -- sans quoi le declencheur se
                --       rappellerait a l'infini sur son propre debit.
  v := public.justice_indemnite_naitre('republic', LEE, 'banc-cr-3', 'jug-banc-3', 9);
  UPDATE public.caisses_batiments SET data = jsonb_build_object('solde', 500)
   WHERE id = 'republic_gouvernement-min_fin';
  SELECT montant_paye INTO v_n FROM public.justice_indemnites WHERE affaire = 'banc-cr-3';
  IF v_n <> 0 THEN ko:=ko+1; e:=e||E'\nT27 une baisse a paye : '||v_n; END IF;

  -- =========================================================== LE SIGNALEMENT
  n := n + 1;   -- T28 : SIGNALER UN RECHERCHE PRESENT -> ARRESTATION A L'ECHEANCE.
  PERFORM public.detention_clore_interne(LEE, 'fin_de_banc', public.jour_de_jeu_pays('republic'));
  PERFORM public.recherche_inscrire(
    jsonb_build_object('acte','vol','type','delit_mineur','jour',v_jour), LEE);
  DELETE FROM public.presences WHERE name IN (LEE, TIERS);
  INSERT INTO public.presences (name, country, city, building_id, room_id) VALUES
    (LEE,   'republic', 'capitale', 'banc-batiment', 'banc-salle'),
    (TIERS, 'republic', 'capitale', 'banc-batiment', 'banc-salle');
  PERFORM pg_temp.je_suis(TIERS_U);
  v := public.police_signaler(LEE);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v->>'ok')::boolean,false) IS NOT TRUE OR (v->>'delai_secondes')::int <> 10 THEN
    ko:=ko+1; e:=e||E'\nT28 signalement refuse : '||v::text; END IF;
  v_txt := v->>'id';
  -- L'ECHEANCE EST OPPOSEE PAR LE SERVEUR : on la force a passer en base plutot que d'attendre
  -- dix secondes dans un banc -- c'est la seule chose qu'un banc ne peut pas se permettre
  -- d'attendre, et le refus avant echeance est eprouve a l'epreuve suivante.
  PERFORM pg_temp.je_suis(TIERS_U);
  v := public.police_signalement_resoudre(v_txt);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'delai_non_ecoule' THEN
    ko:=ko+1; e:=e||E'\nT28b resolution avant echeance acceptee : '||v::text; END IF;
  UPDATE public.signalements_police SET echeance = now() - interval '1 second' WHERE id = v_txt;
  PERFORM pg_temp.je_suis(TIERS_U);
  v := public.police_signalement_resoudre(v_txt);
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT count(*) INTO v_n FROM public.detention_active(LEE);
  IF (v->>'issue') <> 'arrestation' OR (v->>'arrestation') <> 'true' OR v_n <> 1 THEN
    ko:=ko+1; e:=e||E'\nT28c arrestation : '||v::text||' / detentions '||v_n; END IF;

  n := n + 1;   -- T29 : LA CIBLE QUI FUIT PENDANT LES DIX SECONDES ECHAPPE A L'ARRESTATION, ET
                --       RESTE RECHERCHEE. La police vient a un ENDROIT, pas apres une PERSONNE.
  PERFORM public.detention_clore_interne(LEE, 'fin_de_banc', public.jour_de_jeu_pays('republic'));
  PERFORM pg_temp.je_suis(TIERS_U);
  v := public.police_signaler(LEE);
  PERFORM pg_temp.je_suis_le_serveur();
  v_txt := v->>'id';
  UPDATE public.presences SET room_id = 'banc-autre-salle' WHERE name = LEE;
  UPDATE public.signalements_police SET echeance = now() - interval '1 second' WHERE id = v_txt;
  PERFORM pg_temp.je_suis(TIERS_U);
  v := public.police_signalement_resoudre(v_txt);
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT count(*) INTO v_n FROM public.detention_active(LEE);
  IF (v->>'issue') <> 'cible_partie' OR (v->>'arrestation') <> 'false' OR v_n <> 0 THEN
    ko:=ko+1; e:=e||E'\nT29 la cible partie a ete arretee : '||v::text; END IF;
  IF public.justice_est_recherche(LEE) IS NOT TRUE THEN
    ko:=ko+1; e:=e||E'\nT29b la fuite a efface l avis de recherche'; END IF;

  n := n + 1;   -- T30 : UN SEUL SIGNALEMENT VIVANT PAR CIBLE -- l'anti-doublon est structurel.
  UPDATE public.presences SET room_id = 'banc-salle' WHERE name = LEE;
  PERFORM pg_temp.je_suis(TIERS_U);
  v := public.police_signaler(LEE);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v->>'ok')::boolean,false) IS NOT TRUE THEN
    ko:=ko+1; e:=e||E'\nT30 troisieme signalement refuse a tort : '||v::text; END IF;
  PERFORM pg_temp.je_suis(TIERS_U);
  v := public.police_signaler(LEE);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'intervention_deja_en_route' THEN
    ko:=ko+1; e:=e||E'\nT30b doublon de signalement accepte : '||v::text; END IF;

  IF ko = 0 THEN RAISE EXCEPTION 'banc tribunal 2 : LES % EPREUVES SONT VERTES. -- rien ne doit rester', n;
  ELSE RAISE EXCEPTION 'banc tribunal 2 : % epreuve(s) sur % en defaut.%', ko, n, e; END IF;
END
$banc$;
ROLLBACK;
