-- BANC DES CARRIERES, DE L'AUDIENCE ET DU GREFFE PUBLIC (12 octobre 2026, nuit) -- 40 epreuves
--
-- CE BANC NE COMMITE RIEN. Il ouvre des carrieres, nomme des magistrats, fixe des audiences, fait
-- parler des gens dans une salle, et se termine par un RAISE EXCEPTION INCONDITIONNEL.
--
-- POURQUOI IL EXISTE. Les 65 preuves des cinq migrations sont STRUCTURELLES : elles lisent des
-- catalogues et verifient qu'une garde est ECRITE. Aucune ne peut prouver qu'un officier se voit
-- REFUSER le poste de juge, qu'un consentement donne pour le jour 12 ne vaut pas pour le 11, qu'un
-- spectateur present dans la salle lit sans pouvoir ecrire, ni qu'un plaignant ne peut plus citer
-- de temoin une seconde apres son depot. Ca se joue.
--
-- Usage : coller ce fichier dans un execute_sql. Il doit finir sur
--   ERROR: banc carrieres/audience : LES 40 EPREUVES SONT VERTES. -- rien ne doit rester

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
  BEN_U  text := 'bafc96b1-1628-4ae2-93d2-78d89f8ac5b5'; BEN  text := 'Ben';
  MARS_U text := 'a5a55fc8-64fa-4406-b617-76439d1d4aac'; MARS text := 'Marsault';
  LEE_U  text := 'ea4a2a0c-a192-4e10-8cff-d5db9b1cceb6'; LEE  text := 'Lee Capene';
  PHIL_U text := '0821bcdf-0c69-4ba3-adcd-f60d9b82b7bf'; PHIL text := 'Phileas Frogg';
  v jsonb; n integer := 0; ko integer := 0; e text := '';
  v_n integer; v_s text; v_jour integer; v_aff text; v_rang bigint; v_leve boolean;
BEGIN
  PERFORM pg_temp.je_suis_le_serveur();
  DELETE FROM public.postes_attribues WHERE poste_id IN ('procureur', 'juge', 'commissaire', 'commandant');
  DELETE FROM public.carrieres_acquises;
  UPDATE public.personnages_donnees SET poste = NULL, est_emprisonne = NULL, recherche = '[]'::jsonb
   WHERE name IN (BEN, MARS, LEE, PHIL);
  DELETE FROM public.detentions WHERE nom IN (BEN, MARS, LEE, PHIL);
  -- DECOR DE CARRIERES : Marsault officier, Lee magistrat, Ben crime organise, Phileas medecin.
  UPDATE public.personnages_donnees SET career = 'officer'    WHERE name = MARS;
  UPDATE public.personnages_donnees SET career = 'magistrat'  WHERE name = LEE;
  UPDATE public.personnages_donnees SET career = 'criminal_c' WHERE name = BEN;
  UPDATE public.personnages_donnees SET career = 'doctor'     WHERE name = PHIL;

  -- =========================================================== LES CARRIERES
  n := n + 1;   -- T1 : LA CARRIERE INITIALE SE LIT, ET ELLE EST SEULE AU DEPART.
  IF public.carriere_initiale(MARS) IS DISTINCT FROM 'officer'
     OR array_length(public.carrieres_de(MARS), 1) <> 1 THEN
    ko := ko + 1; e := e || E'\nT1 : la carriere initiale ne se lit pas'; END IF;

  n := n + 1;   -- T2 : L'HABILITATION SUIT LA CARRIERE, DANS LES DEUX SENS.
  IF NOT public.habilitation_ouverte(LEE, 'avocat')
     OR NOT public.habilitation_ouverte(LEE, 'juge')
     OR public.habilitation_ouverte(MARS, 'juge')
     OR NOT public.habilitation_ouverte(MARS, 'militaire')
     OR public.habilitation_ouverte(BEN, 'avocat') THEN
    ko := ko + 1; e := e || E'\nT2 : les habilitations ne suivent pas les carrieres'; END IF;

  n := n + 1;   -- T3 : UNE HABILITATION INCONNUE EST FERMEE. Fail closed.
  IF public.habilitation_ouverte(LEE, 'habilitation_qui_n_existe_pas') THEN
    ko := ko + 1; e := e || E'\nT3 : une habilitation inconnue est ouverte'; END IF;

  n := n + 1;   -- T4 : LE BARREAU EST LA CARRIERE JUSTICE, ET PLUS UN REGISTRE VIDE.
  IF NOT public.avocat_est_qualifie(LEE) OR public.avocat_est_qualifie(BEN) THEN
    ko := ko + 1; e := e || E'\nT4 : le barreau ne suit pas la carriere JUSTICE'; END IF;

  n := n + 1;   -- T5 : UN OFFICIER NE DEVIENT PAS JUGE. C'est le coeur du lot 2.
  v := public.poste_attribuer_interne('republic', 'juge', 'capitale', MARS, 'banc');
  IF (v ->> 'raison') IS DISTINCT FROM 'carriere_requise' THEN
    ko := ko + 1; e := e || E'\nT5 : un officier est nomme juge -- ' || v::text; END IF;
  SELECT count(*) INTO v_n FROM public.postes_attribues
   WHERE poste_id = 'juge' AND titulaire = MARS;
  IF v_n <> 0 THEN ko := ko + 1; e := e || E'\nT5 : le refus a quand meme ecrit au registre'; END IF;

  n := n + 1;   -- T6 : LE MAGISTRAT, LUI, PASSE -- juge, procureur et commissaire.
  v := public.poste_attribuer_interne('republic', 'juge', 'capitale', LEE, 'banc');
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nT6 : un magistrat ne peut pas etre juge -- ' || v::text; END IF;
  v := public.poste_attribuer_interne('republic', 'commissaire', 'capitale', LEE, 'banc');
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nT6 : un magistrat ne peut pas etre commissaire -- ' || v::text; END IF;

  n := n + 1;   -- T7 : LE COMMANDANT EXIGE L'ARMEE, ET PAS LA JUSTICE.
  v := public.poste_attribuer_interne('republic', 'commandant', NULL, LEE, 'banc');
  IF (v ->> 'raison') IS DISTINCT FROM 'carriere_requise' THEN
    ko := ko + 1; e := e || E'\nT7 : un magistrat commande la troupe -- ' || v::text; END IF;
  v := public.poste_attribuer_interne('republic', 'commandant', NULL, MARS, 'banc');
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nT7 : un officier ne commande pas -- ' || v::text; END IF;

  n := n + 1;   -- T8 : UN POSTE POLITIQUE N'EXIGE AUCUNE CARRIERE.
  v := public.poste_attribuer_interne('republic', 'min_just', NULL, BEN, 'banc');
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nT8 : un ministere exige une carriere -- ' || v::text; END IF;
  PERFORM public.poste_attribuer_interne('republic', 'min_just', NULL, MARS, 'banc');
  UPDATE public.personnages_donnees SET poste = NULL WHERE name = BEN;

  -- =========================================================== LA SECONDE CARRIERE
  n := n + 1;   -- T9 : LA SECONDE CARRIERE S'AJOUTE, ET ELLE OUVRE SES HABILITATIONS.
  INSERT INTO public.carrieres_acquises (personnage, carriere, source) VALUES (MARS, 'magistrat', 'universite');
  IF array_length(public.carrieres_de(MARS), 1) <> 2
     OR NOT public.habilitation_ouverte(MARS, 'juge')
     OR NOT public.habilitation_ouverte(MARS, 'militaire') THEN
    ko := ko + 1; e := e || E'\nT9 : la seconde carriere n''ouvre pas l''union des deux'; END IF;

  n := n + 1;   -- T10 : ET L'OFFICIER DEVENU MAGISTRAT PEUT ALORS ETRE JUGE.
  v := public.poste_attribuer_interne('republic', 'juge', 'ville_b', MARS, 'banc');
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nT10 : la seconde carriere n''ouvre pas le poste -- ' || v::text; END IF;
  DELETE FROM public.postes_attribues WHERE poste_id = 'juge' AND city = 'ville_b';

  n := n + 1;   -- T11 : IL N'Y A PAS DE TROISIEME CARRIERE, ET C'EST STRUCTUREL.
  BEGIN
    INSERT INTO public.carrieres_acquises (personnage, carriere, source) VALUES (MARS, 'doctor', 'universite');
    ko := ko + 1; e := e || E'\nT11 : une troisieme carriere a pu s''ecrire';
  EXCEPTION WHEN unique_violation THEN NULL; END;

  n := n + 1;   -- T12 : LE SLOT EST CONSOMME, ET L'INSCRIPTION EST REFUSEE.
  IF NOT public.universite_slot_consomme(MARS) THEN
    ko := ko + 1; e := e || E'\nT12 : le slot n''est pas vu comme consomme'; END IF;
  INSERT INTO public.universite_cursus (id, libelle, carriere, semaines_theoriques, cout_pa, cout_fr)
  VALUES ('banc-cur-droit', 'Banc -- droit', 'magistrat', 2, 0, 0),
         ('banc-cur-med', 'Banc -- medecine', 'doctor', 2, 0, 0);
  PERFORM pg_temp.je_suis(MARS_U);
  v := public.universite_inscrire('banc-cur-med', NULL);
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'seconde_carriere_deja_acquise' THEN
    ko := ko + 1; e := e || E'\nT12 : on s''inscrit avec un slot consomme -- ' || v::text; END IF;

  n := n + 1;   -- T13 : ON NE DEPENSE PAS SON UNIQUE SLOT POUR CE QU'ON A DEJA.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.universite_inscrire('banc-cur-droit', NULL);
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'carriere_deja_detenue' THEN
    ko := ko + 1; e := e || E'\nT13 : un magistrat s''inscrit en droit -- ' || v::text; END IF;

  n := n + 1;   -- T14 : L'ABANDON NE CONSOMME PAS LE SLOT.
  -- DEUX INSCRIPTIONS DANS LA MEME TRANSACTION EXIGENT DEUX REQUETES NOMMEES. `universite_inscrire`
  -- derive son identifiant de `now()` quand aucune requete n'est donnee -- et `now()` est CONSTANT
  -- dans une transaction : sans cela, la seconde inscription du banc reprenait l'identifiant de la
  -- premiere, tombait sur `ON CONFLICT DO NOTHING`, et T15 ne trouvait plus de cursus en cours.
  -- EN PRODUCTION LE DEFAUT N'EXISTE PAS : deux inscriptions y sont deux transactions.
  PERFORM pg_temp.je_suis(BEN_U);
  v := public.universite_inscrire('banc-cur-droit', 'rq-banc-ca-un');
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nT14 : inscription refusee -- ' || v::text; END IF;
  v := public.universite_abandonner(NULL);
  PERFORM pg_temp.je_suis_le_serveur();
  IF public.universite_slot_consomme(BEN) THEN
    ko := ko + 1; e := e || E'\nT14 : un abandon a consomme le slot'; END IF;

  n := n + 1;   -- T15 : LE SLOT NE SE CONSOMME QU'AU DIPLOME, ET IL EST ALORS UNE CARRIERE.
  PERFORM pg_temp.je_suis(BEN_U);
  PERFORM public.universite_inscrire('banc-cur-droit', 'rq-banc-ca-deux');
  PERFORM pg_temp.je_suis_le_serveur();
  UPDATE public.universite_inscriptions
     SET fin_theorique_le = now() - interval '1 hour'
   WHERE personnage = BEN AND statut = 'en_cours';
  PERFORM pg_temp.je_suis(BEN_U);
  v := public.universite_diplomer(NULL);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE
     OR (v ->> 'carriere') IS DISTINCT FROM 'magistrat' THEN
    ko := ko + 1; e := e || E'\nT15 : le diplome ne delivre pas la carriere -- ' || v::text; END IF;
  IF NOT public.avocat_est_qualifie(BEN) THEN
    ko := ko + 1; e := e || E'\nT15 : la carriere acquise n''ouvre pas le barreau'; END IF;

  -- =========================================================== LES TEMOINS DU PLAIGNANT
  v_jour := public.jour_de_jeu_pays('republic');
  UPDATE public.personnages_donnees SET country = 'republic', current_city = 'capitale',
         current_building = 'commissariat', current_room = 'accueil_police', pa = 10
   WHERE name = PHIL;
  n := n + 1;   -- T16 : LE PLAIGNANT CITE SES TEMOINS AU DEPOT, ET ILS SONT CONVOQUES.
  PERFORM pg_temp.je_suis(PHIL_U);
  v := public.plainte_deposer(BEN, 'Il a pris mon manteau', 'delit_mineur', ARRAY[LEE, MARS]);
  PERFORM pg_temp.je_suis_le_serveur();
  v_aff := v ->> 'id';
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE
     OR jsonb_array_length(v -> 'temoins_cites') <> 2 THEN
    ko := ko + 1; e := e || E'\nT16 : les temoins du depot ne sont pas cites -- ' || v::text; END IF;
  SELECT count(*) INTO v_n FROM public.temoins_citations
   WHERE affaire = v_aff AND cite_par = PHIL AND cite_par_qualite = 'plaignant';
  IF v_n <> 2 THEN ko := ko + 1; e := e || E'\nT16 : ' || v_n || ' citation(s) au lieu de 2'; END IF;

  n := n + 1;   -- T17 : UN NOM INCONNU ET LE PREVENU SONT ECARTES, SANS FAIRE ECHOUER LE DEPOT.
  PERFORM pg_temp.je_suis(PHIL_U);
  v := public.plainte_deposer(MARS, 'Autre affaire', NULL, ARRAY['Personne qui n''existe pas', MARS, PHIL]);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE
     OR jsonb_array_length(v -> 'temoins_ecartes') <> 3
     OR jsonb_array_length(v -> 'temoins_cites') <> 0 THEN
    ko := ko + 1; e := e || E'\nT17 : les noms impossibles ne sont pas ecartes -- ' || v::text; END IF;

  n := n + 1;   -- T18 : UNE SECONDE APRES SON DEPOT, LE PLAIGNANT NE PEUT PLUS CITER.
  PERFORM pg_temp.je_suis(PHIL_U);
  v := public.temoin_citer(v_aff, 'Un quidam qui n''existe pas');
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'autorite_refusee' THEN
    ko := ko + 1; e := e || E'\nT18 : le plaignant cite encore apres le depot -- ' || v::text; END IF;

  n := n + 1;   -- T19 : MEME AU PARQUET, ET C'EST LA CORRECTION DU LOT 1. L'ancienne regle lui
                --       laissait toute la duree du statut `au_parquet`.
  SELECT (p.data::jsonb) ->> 'status' INTO v_s FROM public.plaintes_en_cours p WHERE p.id = v_aff;
  IF v_s IS DISTINCT FROM 'au_parquet' THEN
    ko := ko + 1; e := e || E'\nT19 : le decor n''est pas au parquet (' || coalesce(v_s,'-') || ')'; END IF;
  PERFORM pg_temp.je_suis(PHIL_U);
  v := public.temoin_citer(v_aff, BEN);
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'le_prevenu_n_est_pas_temoin'
     AND (v ->> 'raison') IS DISTINCT FROM 'autorite_refusee' THEN
    ko := ko + 1; e := e || E'\nT19 : le plaignant cite au parquet -- ' || v::text; END IF;

  n := n + 1;   -- T20 : LE PARQUET ET LE JUGE, EUX, CITENT TOUJOURS.
  PERFORM pg_temp.je_suis_le_serveur();
  INSERT INTO public.postes_attribues (id, country, poste_id, city, titulaire, source)
  VALUES ('banc-ca-proc', 'republic', 'procureur', NULL, LEE, 'banc')
  ON CONFLICT (id) DO NOTHING;
  UPDATE public.personnages_donnees SET poste = jsonb_build_object('id','procureur') WHERE name = LEE;
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.temoin_citer(v_aff, PHIL);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE
     OR (v ->> 'qualite') IS DISTINCT FROM 'parquet' THEN
    ko := ko + 1; e := e || E'\nT20 : le parquet ne cite plus -- ' || v::text; END IF;

  -- =========================================================== LE DOSSIER DE L'AVOCAT
  PERFORM pg_temp.je_suis_le_serveur();
  UPDATE public.plaintes_en_cours
     SET data = (data::jsonb || '{"status":"poursuites","qualification_parquet":"vol"}'::jsonb)::text
   WHERE id = v_aff;
  INSERT INTO public.actions_tracables (id, auteur, cible, type_action, country, city, jour, jour_expiration)
  VALUES ('banc-ca-trace', BEN, PHIL, 'vol', 'republic', 'capitale', v_jour, v_jour + 30);
  -- MARSAULT EST AVOCAT PAR SA SECONDE CARRIERE, celle que T9 lui a donnee. Aucun registre
  -- d'attente n'est ouvert ici : c'est la carriere qui qualifie.
  PERFORM pg_temp.je_suis(MARS_U);
  PERFORM public.avocat_publier_tarification('500 FR');
  PERFORM pg_temp.je_suis(BEN_U);
  PERFORM public.defense_demander(v_aff, ARRAY[MARS]);
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT rang INTO v_rang FROM public.defenses_demandes WHERE affaire = v_aff AND avocat = MARS;
  PERFORM pg_temp.je_suis(MARS_U);
  PERFORM public.defense_repondre(v_rang, true);
  PERFORM pg_temp.je_suis_le_serveur();
  UPDATE public.personnages_donnees SET country = 'republic', current_city = 'capitale',
         current_building = 'tribunal', current_room = 'greffe' WHERE name = MARS;

  n := n + 1;   -- T21 : LE DOSSIER PORTE LES TEMOINS, LEURS DEPOSITIONS ET LES PREUVES REELLES.
  -- Une deposition d'abord, pour qu'il y ait quelque chose a lire.
  UPDATE public.personnages_donnees SET country = 'republic', current_city = 'capitale',
         current_building = 'commissariat', current_room = 'accueil_police' WHERE name = LEE;
  PERFORM pg_temp.je_suis(LEE_U);
  PERFORM public.temoin_deposer(v_aff, E'J etais la.\nIl pleuvait.', false);
  PERFORM pg_temp.je_suis(MARS_U);
  v := public.avocat_dossier(v_aff);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nT21 : le dossier ne s''ouvre pas -- ' || v::text;
  ELSE
    IF jsonb_array_length(v -> 'temoins') < 2 THEN
      ko := ko + 1; e := e || E'\nT21 : le dossier ne porte pas les temoins'; END IF;
    IF jsonb_array_length(v -> 'temoignages') <> 1
       OR ((v -> 'temoignages' -> 0) ->> 'declaration') IS DISTINCT FROM E'J etais la.\nIl pleuvait.' THEN
      ko := ko + 1; e := e || E'\nT21 : la deposition n''est pas au dossier, verbatim'; END IF;
    IF jsonb_array_length(v -> 'preuves') <> 1
       OR ((v -> 'preuves' -> 0) ->> 'acte') IS DISTINCT FROM 'vol' THEN
      ko := ko + 1; e := e || E'\nT21 : la preuve reelle n''est pas au dossier -- '
                           || coalesce((v -> 'preuves')::text, '(nul)'); END IF;
  END IF;

  n := n + 1;   -- T22 : ET TOUJOURS AUCUN CASIER.
  SELECT count(*) INTO v_n FROM jsonb_object_keys(v) k
   WHERE k IN ('casier', 'jugements', 'historique_crimes', 'recherche', 'antecedents');
  IF v_n <> 0 THEN
    ko := ko + 1; e := e || E'\nT22 : le dossier porte ' || v_n || ' cle(s) de casier'; END IF;

  n := n + 1;   -- T23 : UNE TRACE QUI NE PORTE PAS SUR CE DOSSIER N'EST PAS UNE PREUVE ICI.
  PERFORM pg_temp.je_suis_le_serveur();
  INSERT INTO public.actions_tracables (id, auteur, cible, type_action, country, city, jour, jour_expiration)
  VALUES ('banc-ca-autre', BEN, PHIL, 'fausse_rumeur', 'republic', 'capitale', v_jour, v_jour + 30);
  PERFORM pg_temp.je_suis(MARS_U);
  v := public.avocat_dossier(v_aff);
  PERFORM pg_temp.je_suis_le_serveur();
  IF jsonb_array_length(v -> 'preuves') <> 1 THEN
    ko := ko + 1; e := e || E'\nT23 : une trace etrangere au dossier y entre comme preuve'; END IF;

  -- =========================================================== L'AUDIENCE
  PERFORM pg_temp.je_suis_le_serveur();
  DELETE FROM public.postes_attribues WHERE poste_id = 'procureur';
  INSERT INTO public.postes_attribues (id, country, poste_id, city, titulaire, source)
  VALUES ('banc-ca-juge', 'republic', 'juge', 'capitale', LEE, 'banc')
  ON CONFLICT (id) DO UPDATE SET titulaire = EXCLUDED.titulaire;
  UPDATE public.personnages_donnees
     SET poste = jsonb_build_object('id','juge','city','capitale') WHERE name = LEE;
  UPDATE public.plaintes_en_cours
     SET data = (data::jsonb || '{"status":"saisie"}'::jsonb)::text WHERE id = v_aff;
  v_jour := public.jour_de_jeu_pays('republic');

  n := n + 1;   -- T24 : ON N'OUVRE PAS UNE AUDIENCE DONT LE JOUR N'EST PAS FIXE.
  UPDATE public.personnages_donnees SET current_city = 'capitale',
         current_building = 'tribunal', current_room = 'salle_audience' WHERE name = LEE;
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.justice_audience_ouvrir(v_aff);
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'jour_d_audience_non_fixe' THEN
    ko := ko + 1; e := e || E'\nT24 : l''audience s''ouvre sans jour fixe -- ' || v::text; END IF;

  n := n + 1;   -- T25 : MOINS DE TROIS JOURS EXIGE LE CONSENTEMENT DU PREVENU.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.justice_audience_fixer(v_aff, v_jour + 1);
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'consentement_du_prevenu_requis'
     OR (v ->> 'minimum')::integer <> v_jour + 3 THEN
    ko := ko + 1; e := e || E'\nT25 : une audience anticipee passe sans consentement -- ' || v::text; END IF;

  n := n + 1;   -- T26 : LE CONSENTEMENT APPARTIENT AU PREVENU, ET A LUI SEUL.
  PERFORM pg_temp.je_suis(MARS_U);
  v := public.justice_audience_consentir(v_aff, v_jour + 1);
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'pas_mon_affaire' THEN
    ko := ko + 1; e := e || E'\nT26 : l''avocat consent a la place de son client -- ' || v::text; END IF;

  n := n + 1;   -- T27 : LE CONSENTEMENT PORTE SUR UN JOUR PRECIS, ET PAS SUR UN AUTRE.
  PERFORM pg_temp.je_suis(BEN_U);
  v := public.justice_audience_consentir(v_aff, v_jour + 2);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nT27 : le prevenu ne peut pas consentir -- ' || v::text; END IF;
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.justice_audience_fixer(v_aff, v_jour + 1);
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'consentement_du_prevenu_requis' THEN
    ko := ko + 1; e := e || E'\nT27 : un consentement au jour J+2 vaut pour J+1 -- ' || v::text; END IF;

  n := n + 1;   -- T28 : AU JOUR CONSENTI, LE JUGE PEUT FIXER.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.justice_audience_fixer(v_aff, v_jour + 2);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nT28 : le jour consenti est refuse -- ' || v::text; END IF;

  n := n + 1;   -- T29 : LE JOUR N'EST PAS VENU : L'AUDIENCE NE S'OUVRE PAS.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.justice_audience_ouvrir(v_aff);
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'jour_d_audience_non_venu' THEN
    ko := ko + 1; e := e || E'\nT29 : l''audience s''ouvre avant son jour -- ' || v::text; END IF;

  n := n + 1;   -- T30 : SANS CONSENTEMENT, LE MINIMUM EST BIEN TROIS JOURS.
  PERFORM pg_temp.je_suis(BEN_U);
  PERFORM public.justice_audience_consentir(v_aff, NULL);
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.justice_audience_fixer(v_aff, v_jour + 3);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nT30 : J+3 est refuse sans consentement -- ' || v::text; END IF;

  n := n + 1;   -- T31 : LE JOUR VENU, LE JUGE DOIT ETRE DANS SA SALLE.
  UPDATE public.rp_epoques SET jour_un = jour_un - 3 WHERE pays = 'republic';
  UPDATE public.personnages_donnees SET current_building = 'banque-nationale', current_room = NULL
   WHERE name = LEE;
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.justice_audience_ouvrir(v_aff);
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'presence_du_juge_requise' THEN
    ko := ko + 1; e := e || E'\nT31 : le juge ouvre son audience a distance -- ' || v::text; END IF;

  n := n + 1;   -- T32 : DANS LA SALLE, ELLE S'OUVRE -- ET L'ABSENCE DU PREVENU NE BLOQUE RIEN.
  UPDATE public.personnages_donnees SET current_building = 'tribunal',
         current_room = 'salle_audience' WHERE name = LEE;
  UPDATE public.personnages_donnees SET current_building = 'hotel-republica',
         current_room = 'bar' WHERE name = BEN;
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.justice_audience_ouvrir(v_aff);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE
     OR (v ->> 'prevenu_present') <> 'false' THEN
    ko := ko + 1; e := e || E'\nT32 : l''audience ne s''ouvre pas sans le prevenu -- ' || v::text; END IF;

  n := n + 1;   -- T33 : L'ABSENCE DU PROCUREUR EST CONSTATEE, ET N'EMPORTE RIEN.
  IF (v ->> 'procureur_present') <> 'false' THEN
    ko := ko + 1; e := e || E'\nT33 : la presence du Procureur n''est pas constatee'; END IF;
  SELECT count(*) INTO v_n FROM public.dossiers_judiciaires_actes
   WHERE affaire = v_aff AND type = 'audience_ouverte'
     AND (donnees ->> 'procureur_present') = 'false';
  IF v_n <> 1 THEN
    ko := ko + 1; e := e || E'\nT33 : l''absence du Procureur n''est pas consignee'; END IF;
  -- LES QUATRE FICHES ONT ETE LIBEREES AU DEBUT DU BANC : toute detention qui existerait ici
  -- aurait ete ouverte par ce qui precede, et rien de ce qui precede ne doit en ouvrir une.
  SELECT count(*) INTO v_n FROM public.detentions WHERE nom IN (BEN, LEE, MARS, PHIL);
  IF v_n <> 0 THEN
    ko := ko + 1; e := e || E'\nT33 : une absence a ouvert une detention (' || v_n || ')'; END IF;

  -- =========================================================== LE CHAT JUDICIAIRE
  n := n + 1;   -- T34 : ON NE PARLE PAS DEPUIS L'EXTERIEUR DE LA SALLE.
  PERFORM pg_temp.je_suis(BEN_U);
  v := public.justice_audience_ecrire(v_aff, 'Je proteste');
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'presence_en_salle_requise' THEN
    ko := ko + 1; e := e || E'\nT34 : le prevenu parle depuis le bar -- ' || v::text; END IF;

  n := n + 1;   -- T35 : DANS LA SALLE, LE PREVENU PARLE, ET SON TEXTE EST VERBATIM.
  PERFORM pg_temp.je_suis_le_serveur();
  UPDATE public.personnages_donnees SET country = 'republic', current_city = 'capitale',
         current_building = 'tribunal', current_room = 'salle_audience'
   WHERE name IN (BEN, MARS, PHIL);
  PERFORM pg_temp.je_suis(BEN_U);
  v := public.justice_audience_ecrire(v_aff, E'Je conteste.\nTotalement.');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE
     OR (v ->> 'qualite') IS DISTINCT FROM 'prevenu' THEN
    ko := ko + 1; e := e || E'\nT35 : le prevenu ne parle pas a son proces -- ' || v::text; END IF;
  SELECT texte INTO v_s FROM public.audience_messages
   WHERE affaire = v_aff AND auteur = BEN ORDER BY rang DESC LIMIT 1;
  IF v_s IS DISTINCT FROM E'Je conteste.\nTotalement.' THEN
    ko := ko + 1; e := e || E'\nT35 : le texte n''est pas verbatim'; END IF;

  n := n + 1;   -- T36 : UN TEMOIN N'A AUCUN DROIT AUTOMATIQUE D'ECRIRE.
  PERFORM pg_temp.je_suis(PHIL_U);
  v := public.justice_audience_ecrire(v_aff, 'Je veux parler');
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'parole_non_accordee' THEN
    ko := ko + 1; e := e || E'\nT36 : un temoin parle sans la parole -- ' || v::text; END IF;

  n := n + 1;   -- T37 : LE JUGE LA DONNE, PUIS LA RETIRE -- ET LES DEUX MORDENT.
  PERFORM pg_temp.je_suis(LEE_U);
  PERFORM public.justice_audience_parole(v_aff, PHIL, true);
  PERFORM pg_temp.je_suis(PHIL_U);
  v := public.justice_audience_ecrire(v_aff, 'Je l''ai vu');
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nT37 : la parole accordee n''ouvre rien -- ' || v::text; END IF;
  PERFORM pg_temp.je_suis(LEE_U);
  PERFORM public.justice_audience_parole(v_aff, PHIL, false);
  PERFORM pg_temp.je_suis(PHIL_U);
  v := public.justice_audience_ecrire(v_aff, 'Encore un mot');
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'parole_non_accordee' THEN
    ko := ko + 1; e := e || E'\nT37 : la parole retiree laisse encore ecrire -- ' || v::text; END IF;

  n := n + 1;   -- T38 : LE SPECTATEUR LIT ET N'ECRIT PAS.
  PERFORM pg_temp.je_suis_le_serveur();
  DELETE FROM public.temoins_citations WHERE affaire = v_aff AND temoin = MARS;
  UPDATE public.defenses_demandes SET etat = 'revoquee' WHERE affaire = v_aff AND avocat = MARS;
  PERFORM pg_temp.je_suis(MARS_U);
  v := public.justice_audience_lire(v_aff, 0);
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE
     OR (v ->> 'mon_role') IS DISTINCT FROM 'spectateur'
     OR (v ->> 'je_peux_ecrire') <> 'false'
     OR jsonb_array_length(v -> 'messages') < 2 THEN
    ko := ko + 1; e := e || E'\nT38 : le spectateur ne lit pas, ou ecrit -- ' || v::text; END IF;
  v := public.justice_audience_ecrire(v_aff, 'Moi aussi je veux parler');
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'spectateur_sans_parole' THEN
    ko := ko + 1; e := e || E'\nT38 : un spectateur parle -- ' || v::text; END IF;

  n := n + 1;   -- T39 : LES DEBATS NE SE REECRIVENT PAS, MEME EN POSTGRES.
  v_leve := false;
  BEGIN
    UPDATE public.audience_messages SET texte = 'reecrit' WHERE affaire = v_aff;
  EXCEPTION WHEN raise_exception THEN v_leve := true; END;
  IF NOT v_leve THEN ko := ko + 1; e := e || E'\nT39 : un message d''audience a pu etre reecrit'; END IF;

  -- =========================================================== LE GREFFE PUBLIC ET LA PRESSE
  n := n + 1;   -- T40 : LE REGISTRE PUBLIC DIT QUATRE CHOSES, ET LE JOURNAL A RECU LE FAIT.
  PERFORM pg_temp.je_suis_le_serveur();
  UPDATE public.personnages_donnees SET current_building = 'tribunal', current_room = 'greffe'
   WHERE name = PHIL;
  PERFORM pg_temp.je_suis(PHIL_U);
  v := public.justice_affaires_publiques();
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nT40 : le registre public ne s''ouvre pas -- ' || v::text;
  ELSE
    SELECT count(*) INTO v_n FROM jsonb_array_elements(v -> 'affaires') a, jsonb_object_keys(a) k
     WHERE k NOT IN ('affaire', 'prevenu', 'categorie', 'statut', 'audience_jour', 'temoins');
    IF v_n <> 0 THEN
      ko := ko + 1; e := e || E'\nT40 : le registre public porte ' || v_n || ' cle(s) de trop'; END IF;
  END IF;
  SELECT count(*) INTO v_n FROM public.chronique_nationale
   WHERE source_ref = v_aff AND type = 'justice_audience'
     AND libelle LIKE '%absence du Procureur%';
  IF v_n <> 1 THEN
    ko := ko + 1; e := e || E'\nT40 : le Journal n''a pas recu l''ouverture du proces (' || v_n || ')'; END IF;
  SELECT count(*) INTO v_n FROM public.chronique_nationale
   WHERE source_ref = v_aff AND (libelle ILIKE '%manteau%' OR libelle ILIKE '%' || PHIL || '%');
  IF v_n <> 0 THEN
    ko := ko + 1; e := e || E'\nT40 : le Journal a appris le motif ou le plaignant'; END IF;

  IF ko > 0 THEN RAISE EXCEPTION 'banc carrieres/audience : % EPREUVE(S) ROUGE(S) sur % --%', ko, n, e; END IF;
  RAISE EXCEPTION 'banc carrieres/audience : LES % EPREUVES SONT VERTES. -- rien ne doit rester', n;
END $banc$;
ROLLBACK;
