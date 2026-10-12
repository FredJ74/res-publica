-- BANC DU BARREAU, DES TEMOINS ET DE L'AUDIENCE (12 octobre 2026, soir) -- 34 epreuves
--
-- CE BANC NE COMMITE RIEN. Il ouvre le barreau (une qualification de banc, une ligne de
-- registre), joue la constitution d'une defense, la course a l'acceptation, l'acces au dossier,
-- la rupture, le verrou de l'audience, le circuit complet des temoins -- deux convocations, la
-- recherche, la deposition, l'extinction -- et se termine par un RAISE EXCEPTION INCONDITIONNEL
-- qui annule tout.
--
-- CE QU'IL VERIFIE QUE LES PREUVES NE PEUVENT PAS VERIFIER. Les 38 preuves des deux migrations
-- lisent `prosrc`, des catalogues et des index : aucune ne peut dire qu'une course a
-- l'acceptation designe UN SEUL gagnant, qu'une recherche de temoin s'eteint sans toucher les
-- autres, ni qu'un dossier reste ferme a trois metres du greffe.
--
-- Usage : coller ce fichier dans un execute_sql. Il doit finir sur
--   ERROR: banc avocat/temoins : LES 34 EPREUVES SONT VERTES. -- rien ne doit rester
--
-- TROIS PIEGES DE DECOR, pour qui le rejoue :
--   . LE BARREAU EST VIDE EN PRODUCTION, et c'est voulu : la qualification universitaire n'est
--     pas arbitree. Le banc insere donc sa propre qualification et sa propre ligne de registre --
--     c'est ce qui permet d'eprouver toute la chaine sans rien inventer dans le monde reel ;
--   . le temps se simule en RECULANT `rp_epoques.jour_un`, jamais en corrigeant une echeance :
--     c'est le monde qui avance, pas le dossier qu'on retouche ;
--   . lire une table du socle exige d'etre le SERVEUR. Un `je_suis(...)` oublie avant un SELECT
--     fait echouer le banc sur un refus de privilege -- qui est la bonne reponse, mais pas celle
--     qu'on mesurait.

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
  v_n integer; v_s text; v_leve boolean; r1 bigint; r2 bigint; v_jour integer;
BEGIN
  PERFORM pg_temp.je_suis_le_serveur();

  -- DECOR
  DELETE FROM public.postes_attribues WHERE poste_id IN ('procureur', 'juge');
  UPDATE public.personnages_donnees SET poste = NULL, est_emprisonne = NULL, recherche = '[]'::jsonb
   WHERE name IN (BEN, MARS, LEE, PHIL);
  DELETE FROM public.detentions WHERE nom IN (BEN, MARS, LEE, PHIL);
  -- LE BARREAU EST UNE CARRIERE, PLUS UN REGISTRE D'ATTENTE (lot 2, 12 octobre 2026).
  -- `justice_barreau_qualifications` a ete SUPPRIMEE : l'arbitrage est rendu, et c'est la carriere
  -- JUSTICE qui qualifie. Le decor donne donc cette carriere aux deux avocats du banc -- l'une
  -- comme carriere INITIALE, l'autre comme SECONDE carriere, pour que les deux voies soient
  -- exercees ici aussi.
  UPDATE public.personnages_donnees SET career = 'magistrat' WHERE name = LEE;
  UPDATE public.personnages_donnees SET career = 'officer'   WHERE name = MARS;
  -- PHILEAS DOIT ETRE HORS DU BARREAU, ET EN BASE IL NE L'EST PAS : sa carriere de bêta est
  -- `magistrat`. Sans cette ligne, le temoin de ce banc etait avocat, s'inscrivait au barreau,
  -- apparaissait dans la liste offerte au prevenu, et six epreuves tombaient -- pour une raison
  -- qui n'avait rien a voir avec ce qu'elles mesurent. Le decor nomme ce qu'il exige.
  UPDATE public.personnages_donnees SET career = 'doctor'    WHERE name = PHIL;
  DELETE FROM public.carrieres_acquises WHERE personnage IN (LEE, PHIL, BEN);
  DELETE FROM public.carrieres_acquises WHERE personnage = MARS;
  INSERT INTO public.carrieres_acquises (personnage, carriere, source)
  VALUES (MARS, 'magistrat', 'universite');
  v_jour := public.jour_de_jeu_pays('republic');
  INSERT INTO public.plaintes_en_cours (id, country, city, data) VALUES
    ('banc-av-1', 'republic', 'capitale', jsonb_build_object('id', 'banc-av-1',
      'status', 'poursuites', 'cible', BEN, 'plaignant', PHIL, 'motif', 'Vol',
      'qualification_parquet', 'vol', 'infraction_constatee', 'vol',
      'country', 'republic', 'city', 'capitale', 'jour', v_jour)::text),
    ('banc-av-2', 'republic', 'ville_b', jsonb_build_object('id', 'banc-av-2',
      'status', 'au_parquet', 'cible', BEN, 'plaignant', PHIL, 'motif', 'Tracts',
      'infraction_constatee', 'imprimer_tracts_calomnieux',
      'country', 'republic', 'city', 'ville_b', 'jour', v_jour)::text);

  -- ------------------------------------------- T1 : LE BARREAU EST FERME PAR DEFAUT
  -- Le registre de production est VIDE : personne n'est avocat tant qu'il l'est.
  n := n + 1;
  IF public.avocat_est_qualifie(PHIL) THEN
    ko := ko + 1; e := e || E'\nT1 : un joueur sans la carriere JUSTICE est avocat'; END IF;
  IF NOT public.avocat_est_qualifie(MARS) THEN
    ko := ko + 1; e := e || E'\nT1 : la carriere JUSTICE n''ouvre pas le barreau'; END IF;

  -- ------------------------- T2 : LA TARIFICATION EXIGE LA QUALIFICATION
  n := n + 1;
  PERFORM pg_temp.je_suis(PHIL_U);
  v := public.avocat_publier_tarification('100 FR');
  IF (v ->> 'raison') IS DISTINCT FROM 'qualification_avocat_requise' THEN
    ko := ko + 1; e := e || E'\nT2 : un non-qualifie s''inscrit au barreau -- ' || v::text; END IF;

  -- --------------- T3 : UNE TARIFICATION VIDE N'INSCRIT PERSONNE, ET C'EST ELLE QUI INSCRIT
  n := n + 1;
  PERFORM pg_temp.je_suis(MARS_U);
  v := public.avocat_publier_tarification('   ');
  IF (v ->> 'raison') IS DISTINCT FROM 'tarification_absente' THEN
    ko := ko + 1; e := e || E'\nT3 : une tarification vide est acceptee -- ' || v::text; END IF;
  v := public.avocat_publier_tarification('500 FR, ou un service rendu');
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nT3 : la tarification n''est pas publiee -- ' || v::text; END IF;
  PERFORM pg_temp.je_suis(LEE_U);
  PERFORM public.avocat_publier_tarification('gratuit');

  -- ------- T4 : LA LISTE OFFERTE AU PREVENU NE PORTE QUE L'IDENTITE ET LA TARIFICATION
  n := n + 1;
  PERFORM pg_temp.je_suis(BEN_U);
  v := public.justice_avocats_disponibles('banc-av-1');
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE
     OR jsonb_array_length(v -> 'avocats') <> 2 THEN
    ko := ko + 1; e := e || E'\nT4 : la liste des avocats est fausse -- ' || (v -> 'avocats')::text; END IF;
  -- AUCUNE CLE MECANIQUE : la liste n'a que `nom` et `tarification`, et rien d'autre.
  SELECT count(*) INTO v_n FROM jsonb_array_elements(v -> 'avocats') a,
         jsonb_object_keys(a) k WHERE k NOT IN ('nom', 'tarification');
  IF v_n <> 0 THEN
    ko := ko + 1; e := e || E'\nT4 : la liste porte ' || v_n || ' cle(s) hors nom/tarification'; END IF;

  -- -------------------- T5 : UN AVOCAT SANS TARIFICATION N'APPARAIT PAS
  n := n + 1;
  PERFORM pg_temp.je_suis(LEE_U);
  PERFORM public.avocat_retirer_tarification();
  PERFORM pg_temp.je_suis(BEN_U);
  v := public.justice_avocats_disponibles('banc-av-1');
  IF jsonb_array_length(v -> 'avocats') <> 1 THEN
    ko := ko + 1; e := e || E'\nT5 : un avocat retire de la liste y figure encore'; END IF;
  PERFORM pg_temp.je_suis(LEE_U);
  PERFORM public.avocat_publier_tarification('gratuit');

  -- ---------- T6 : ON NE CONSTITUE PAS SA DEFENSE AVANT D'ETRE POURSUIVI
  n := n + 1;
  PERFORM pg_temp.je_suis(BEN_U);
  v := public.defense_demander('banc-av-2', ARRAY[MARS]);
  IF (v ->> 'raison') IS DISTINCT FROM 'poursuites_non_engagees' THEN
    ko := ko + 1; e := e || E'\nT6 : on constitue sa defense au parquet -- ' || v::text; END IF;

  -- ---------------------------- T7 : DEMANDES MULTIPLES, ET LE NON-INSCRIT EST ECARTE
  n := n + 1;
  v := public.defense_demander('banc-av-1', ARRAY[MARS, LEE, PHIL]);
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE
     OR jsonb_array_length(v -> 'envoyees') <> 2
     OR ((v -> 'ecartees' -> 0) ->> 'raison') IS DISTINCT FROM 'avocat_non_inscrit' THEN
    ko := ko + 1; e := e || E'\nT7 : les demandes multiples ne passent pas -- ' || v::text; END IF;

  -- -------------------------- T8 : PAS DEUX FOIS LA MEME DEMANDE EN ATTENTE
  n := n + 1;
  v := public.defense_demander('banc-av-1', ARRAY[MARS]);
  IF coalesce((v ->> 'ok')::boolean, true) IS NOT FALSE
     OR ((v -> 'ecartees' -> 0) ->> 'raison') IS DISTINCT FROM 'demande_deja_en_attente' THEN
    ko := ko + 1; e := e || E'\nT8 : un double clic double la demande -- ' || v::text; END IF;

  -- -------------- T9 : AVANT ACCEPTATION, L'AVOCAT SOLLICITE NE VOIT RIEN DU DOSSIER
  n := n + 1;
  PERFORM pg_temp.je_suis(MARS_U);
  v := public.defense_mes_demandes();
  IF jsonb_array_length(v -> 'demandes') <> 1 THEN
    ko := ko + 1; e := e || E'\nT9 : la demande n''arrive pas a l''avocat'; END IF;
  SELECT count(*) INTO v_n FROM jsonb_array_elements(v -> 'demandes') d, jsonb_object_keys(d) k
   WHERE k IN ('motif', 'qualification_parquet', 'actes', 'audition');
  IF v_n <> 0 THEN
    ko := ko + 1; e := e || E'\nT9 : l''avocat sollicite voit ' || v_n || ' donnee(s) du dossier'; END IF;

  -- ------------------------ T10 : ET LE DOSSIER LUI EST REFUSE
  n := n + 1;
  v := public.avocat_dossier('banc-av-1');
  IF (v ->> 'raison') IS DISTINCT FROM 'pas_mon_dossier' THEN
    ko := ko + 1; e := e || E'\nT10 : le dossier s''ouvre avant acceptation -- ' || v::text; END IF;

  -- -------------- T11 : LE PREMIER ACCEPTANT GAGNE, ET LE SECOND EST REFUSE PROPREMENT
  n := n + 1;
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT rang INTO r1 FROM public.defenses_demandes WHERE affaire = 'banc-av-1' AND avocat = MARS;
  SELECT rang INTO r2 FROM public.defenses_demandes WHERE affaire = 'banc-av-1' AND avocat = LEE;
  PERFORM pg_temp.je_suis(MARS_U);
  v := public.defense_repondre(r1, true);
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE
     OR (v ->> 'accepte') <> 'true' OR (v ->> 'demandes_caduques')::integer <> 1 THEN
    ko := ko + 1; e := e || E'\nT11 : la premiere acceptation echoue -- ' || v::text; END IF;
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.defense_repondre(r2, true);
  IF coalesce((v ->> 'ok')::boolean, true) IS NOT FALSE
     OR (v ->> 'raison') NOT IN ('demande_close', 'avocat_deja_retenu') THEN
    ko := ko + 1; e := e || E'\nT11 : deux avocats acceptent la meme defense -- ' || v::text; END IF;

  -- ---------- T12 : L'UNICITE EST STRUCTURELLE, ET PAS SEULEMENT GARDEE PAR LA PORTE
  -- On force une seconde ligne `acceptee` en PASSANT PAR LA TABLE : l'index doit refuser.
  n := n + 1;
  PERFORM pg_temp.je_suis_le_serveur();
  v_leve := false;
  BEGIN
    UPDATE public.defenses_demandes SET etat = 'acceptee' WHERE rang = r2;
  EXCEPTION WHEN unique_violation THEN v_leve := true; END;
  IF NOT v_leve THEN
    ko := ko + 1; e := e || E'\nT12 : deux lignes `acceptee` coexistent sur une affaire'; END IF;

  -- ------------------- T13 : UN SEUL AVOCAT EST DESIGNE PAR LA DEFINITION UNIQUE
  n := n + 1;
  IF public.defense_avocat_de('banc-av-1') IS DISTINCT FROM MARS THEN
    ko := ko + 1; e := e || E'\nT13 : l''avocat retenu n''est pas celui qui a accepte'; END IF;

  -- --------------- T14 : LE DOSSIER NE S'OUVRE PAS HORS DU GREFFE COMPETENT
  n := n + 1;
  UPDATE public.personnages_donnees SET country = 'republic', current_city = 'capitale',
         current_building = 'banque-nationale', current_room = NULL WHERE name = MARS;
  PERFORM pg_temp.je_suis(MARS_U);
  v := public.avocat_dossier('banc-av-1');
  IF (v ->> 'raison') IS DISTINCT FROM 'presence_au_greffe_requise' THEN
    ko := ko + 1; e := e || E'\nT14 : le dossier se lit a distance -- ' || v::text; END IF;

  -- ------------------- T15 : NI DEPUIS LE BUREAU DES MAGISTRATS, NI D'UNE AUTRE VILLE
  n := n + 1;
  PERFORM pg_temp.je_suis_le_serveur();
  UPDATE public.personnages_donnees SET current_building = 'tribunal',
         current_room = 'bureau_magistrats' WHERE name = MARS;
  PERFORM pg_temp.je_suis(MARS_U);
  v := public.avocat_dossier('banc-av-1');
  IF (v ->> 'raison') IS DISTINCT FROM 'presence_au_greffe_requise' THEN
    ko := ko + 1; e := e || E'\nT15 : le dossier se lit au bureau des magistrats'; END IF;
  PERFORM pg_temp.je_suis_le_serveur();
  UPDATE public.personnages_donnees SET current_city = 'ville_b',
         current_building = 'tribunal-local', current_room = 'greffe' WHERE name = MARS;
  PERFORM pg_temp.je_suis(MARS_U);
  v := public.avocat_dossier('banc-av-1');
  IF (v ->> 'raison') IS DISTINCT FROM 'presence_au_greffe_requise' THEN
    ko := ko + 1; e := e || E'\nT15 : le greffe d''une autre ville ouvre le dossier'; END IF;

  -- ---------------------------- T16 : AU GREFFE COMPETENT, LE DOSSIER EST COMPLET
  n := n + 1;
  PERFORM pg_temp.je_suis_le_serveur();
  UPDATE public.personnages_donnees SET current_city = 'capitale',
         current_building = 'tribunal', current_room = 'greffe' WHERE name = MARS;
  PERFORM pg_temp.je_suis(MARS_U);
  v := public.avocat_dossier('banc-av-1');
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE
     OR (v ->> 'plaignant') IS DISTINCT FROM PHIL
     OR (v ->> 'motif') IS DISTINCT FROM 'Vol'
     OR (v ->> 'qualification_parquet') IS DISTINCT FROM 'vol'
     OR jsonb_array_length(v -> 'actes') < 1 THEN
    ko := ko + 1; e := e || E'\nT16 : le dossier est incomplet -- ' || v::text; END IF;

  -- ------------------------- T17 : ET IL N'OUVRE AUCUNE PORTE VERS LE CASIER
  n := n + 1;
  SELECT count(*) INTO v_n FROM jsonb_object_keys(v) k
   WHERE k IN ('casier', 'jugements', 'historique_crimes', 'recherche', 'antecedents');
  IF v_n <> 0 THEN
    ko := ko + 1; e := e || E'\nT17 : le dossier porte ' || v_n || ' cle(s) de casier'; END IF;

  -- ---------------- T18 : L'AVOCAT CITE UN TEMOIN, DE N'IMPORTE QUEL EMPIRE
  n := n + 1;
  PERFORM pg_temp.je_suis_le_serveur();
  UPDATE public.personnages_donnees SET country = 'soviet' WHERE name = PHIL;
  PERFORM pg_temp.je_suis(MARS_U);
  v := public.temoin_citer('banc-av-1', PHIL);
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE
     OR (v ->> 'qualite') IS DISTINCT FROM 'avocat'
     OR (v ->> 'commissariat') IS DISTINCT FROM 'commissariat' THEN
    ko := ko + 1; e := e || E'\nT18 : un PJ d''un autre empire n''est pas citable -- ' || v::text; END IF;

  -- ------------------------------ T19 : UN TIERS NE CITE PERSONNE
  -- T19 A ETE RECALIBREE A SA PREMIERE EXECUTION : elle citait le PREVENU, et la garde
  -- `le_prevenu_n_est_pas_temoin` passe AVANT celle de l'autorite. Elle mesurait donc la mauvaise
  -- garde. Le nom choisi n'existe volontairement pas : l'autorite est verifiee avant l'existence
  -- du temoin, et c'est bien l'autorite qu'on mesure.
  n := n + 1;
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.temoin_citer('banc-av-1', 'Un quidam qui n''existe pas');
  IF (v ->> 'raison') IS DISTINCT FROM 'autorite_refusee' THEN
    ko := ko + 1; e := e || E'\nT19 : un tiers cite un temoin -- ' || v::text; END IF;

  -- -------------------- T20 : ET LE PREVENU N'EST PAS SON PROPRE TEMOIN
  n := n + 1;
  PERFORM pg_temp.je_suis(MARS_U);
  v := public.temoin_citer('banc-av-1', BEN);
  IF (v ->> 'raison') IS DISTINCT FROM 'le_prevenu_n_est_pas_temoin' THEN
    ko := ko + 1; e := e || E'\nT20 : le prevenu est cite comme temoin -- ' || v::text; END IF;

  -- ------------ T21 : LE PLAIGNANT CITE AU MOMENT DU DEPOT, ET PAS APRES
  n := n + 1;
  PERFORM pg_temp.je_suis(PHIL_U);
  v := public.temoin_citer('banc-av-2', LEE);
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE
     OR (v ->> 'qualite') IS DISTINCT FROM 'plaignant'
     OR (v ->> 'commissariat') IS DISTINCT FROM 'commissariat-local' THEN
    ko := ko + 1; e := e || E'\nT21 : le plaignant ne cite pas au depot -- ' || v::text; END IF;
  v := public.temoin_citer('banc-av-1', LEE);
  IF (v ->> 'raison') IS DISTINCT FROM 'autorite_refusee' THEN
    ko := ko + 1; e := e || E'\nT21 : le plaignant cite apres le depot -- ' || v::text; END IF;

  -- ------------- T22 : LE TEMOIN VOIT SON OBLIGATION, PAS LE DOSSIER
  n := n + 1;
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.temoin_mes_convocations();
  IF jsonb_array_length(v -> 'convocations') <> 1
     OR ((v -> 'convocations' -> 0) ->> 'site') IS DISTINCT FROM 'commissariat-local' THEN
    ko := ko + 1; e := e || E'\nT22 : la convocation du temoin est fausse -- ' || v::text; END IF;
  SELECT count(*) INTO v_n FROM jsonb_object_keys(v -> 'convocations' -> 0) k
   WHERE k IN ('motif', 'prevenu', 'qualification_parquet', 'actes');
  IF v_n <> 0 THEN
    ko := ko + 1; e := e || E'\nT22 : le temoin voit ' || v_n || ' donnee(s) du dossier'; END IF;

  -- -------------- T23 : ON NE DEPOSE PAS AILLEURS QU'AU BON COMMISSARIAT
  n := n + 1;
  PERFORM pg_temp.je_suis_le_serveur();
  UPDATE public.personnages_donnees SET country = 'republic', current_city = 'capitale',
         current_building = 'commissariat', current_room = 'accueil_police' WHERE name = LEE;
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.temoin_deposer('banc-av-2', 'Je depose a Luthecia', false);
  IF (v ->> 'raison') IS DISTINCT FROM 'presence_au_commissariat_requise' THEN
    ko := ko + 1; e := e || E'\nT23 : une affaire de province se depose a la capitale -- ' || v::text; END IF;

  -- ------------------------- T24 : UNE REPONSE VIDE N'EST PAS UNE REPONSE
  n := n + 1;
  PERFORM pg_temp.je_suis_le_serveur();
  UPDATE public.personnages_donnees SET current_city = 'ville_b',
         current_building = 'commissariat-local', current_room = 'accueil_loc' WHERE name = LEE;
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.temoin_deposer('banc-av-2', '   ', false);
  IF (v ->> 'raison') IS DISTINCT FROM 'reponse_absente' THEN
    ko := ko + 1; e := e || E'\nT24 : une deposition vide est acceptee -- ' || v::text; END IF;

  -- -------------- T25 : LA DEPOSITION EST CONSIGNEE VERBATIM, RETOURS A LA LIGNE COMPRIS
  n := n + 1;
  v := public.temoin_deposer('banc-av-2', E'J etais la.\nIl pleuvait.', false);
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nT25 : la deposition echoue -- ' || v::text; END IF;
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT declaration INTO v_s FROM public.dossiers_auditions
   WHERE affaire = 'banc-av-2' AND personne = LEE AND qualite = 'temoin';
  IF v_s IS DISTINCT FROM E'J etais la.\nIl pleuvait.' THEN
    ko := ko + 1; e := e || E'\nT25 : la deposition n''est pas verbatim -- ' || coalesce(v_s, '(nul)'); END IF;

  -- ------------- T26 : LA DEPOSITION SATISFAIT LA COMPARUTION, ET NE SE REJOUE PAS
  n := n + 1;
  SELECT etat || '/' || coalesce(issue, '-') INTO v_s FROM public.temoins_citations
   WHERE affaire = 'banc-av-2' AND temoin = LEE;
  IF v_s IS DISTINCT FROM 'close/deposition' THEN
    ko := ko + 1; e := e || E'\nT26 : la citation n''est pas satisfaite -- ' || coalesce(v_s, '-'); END IF;
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.temoin_deposer('banc-av-2', 'Je me ravise', false);
  IF (v ->> 'raison') IS DISTINCT FROM 'aucune_citation_vivante' THEN
    ko := ko + 1; e := e || E'\nT26 : on depose deux fois -- ' || v::text; END IF;

  -- ------- T27 : LE DELAI DE JUGEMENT N'A PAS BOUGE. Une deposition de temoin ne le touche pas.
  n := n + 1;
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT data::jsonb ->> 'delai_jugement_jour' INTO v_s
    FROM public.plaintes_en_cours WHERE id = 'banc-av-2';
  IF v_s IS NOT NULL THEN
    ko := ko + 1; e := e || E'\nT27 : la deposition d''un temoin a ouvert un delai de jugement'; END IF;

  -- ------- T28 : LE PV DU PREVENU, LUI, OUVRE TOUJOURS LES QUINZE JOURS -- ET SANS PRESENCE
  n := n + 1;
  UPDATE public.personnages_donnees SET country = 'republic', current_city = 'capitale',
         current_building = 'hotel-republica', current_room = 'bar' WHERE name = BEN;
  -- L'HORLOGE SE LIT EN SERVEUR. `jour_de_jeu_pays` n'a aucun droit client -- un joueur ne la
  -- lit pas, et c'est voulu : le banc la releve AVANT d'endosser une identite.
  v_jour := public.jour_de_jeu_pays('republic');
  PERFORM pg_temp.je_suis(BEN_U);
  v := public.pv_audition_realiser('banc-av-2', 'Je conteste', false);
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE
     OR (v ->> 'delai_jugement_jour')::integer <> v_jour + 15 THEN
    ko := ko + 1; e := e || E'\nT28 : le PV du prevenu a change de regle -- ' || v::text; END IF;
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT qualite INTO v_s FROM public.dossiers_auditions
   WHERE affaire = 'banc-av-2' AND personne = BEN;
  IF v_s IS DISTINCT FROM 'prevenu' THEN
    ko := ko + 1; e := e || E'\nT28 : le PV du prevenu n''est pas distingue de la deposition'; END IF;

  -- ------------- T29 : DEUX CONVOCATIONS DE DEUX JOURS, PUIS LA RECHERCHE
  n := n + 1;
  v := public.temoins_convocations_echues();
  IF (v ->> 'secondes_convocations')::integer <> 0 OR (v ->> 'recherches_ouvertes')::integer <> 0 THEN
    ko := ko + 1; e := e || E'\nT29 : une convocation echoit le jour meme -- ' || v::text; END IF;
  UPDATE public.rp_epoques SET jour_un = jour_un - 3 WHERE pays = 'republic';
  v := public.temoins_convocations_echues();
  IF (v ->> 'secondes_convocations')::integer <> 1 OR (v ->> 'recherches_ouvertes')::integer <> 0 THEN
    ko := ko + 1; e := e || E'\nT29 : la seconde convocation n''est pas emise -- ' || v::text; END IF;
  UPDATE public.rp_epoques SET jour_un = jour_un - 3 WHERE pays = 'republic';
  v := public.temoins_convocations_echues();
  IF (v ->> 'recherches_ouvertes')::integer <> 1 THEN
    ko := ko + 1; e := e || E'\nT29 : la recherche n''est pas ouverte -- ' || v::text; END IF;

  -- ------------- T30 : LA RECHERCHE EXISTE, ET N'A AUCUNE AUTRE CONSEQUENCE
  n := n + 1;
  IF NOT public.justice_est_recherche(PHIL) THEN
    ko := ko + 1; e := e || E'\nT30 : le temoin absent n''est pas recherche'; END IF;
  SELECT count(*) INTO v_n FROM public.detentions WHERE nom = PHIL;
  IF v_n <> 0 THEN
    ko := ko + 1; e := e || E'\nT30 : l''absence a ouvert une detention'; END IF;

  -- ------- T31 : LA DEPOSITION RETIRE SA RECHERCHE, ET ELLE SEULE
  -- On ajoute une recherche d'INFRACTION a cote : elle doit survivre.
  n := n + 1;
  PERFORM public.recherche_inscrire(jsonb_build_object(
    'id', 'banc-infraction', 'acte', 'vol', 'type', 'delit_mineur',
    'country', 'republic', 'jour', 1), PHIL);
  -- LA TERRITORIALITE, MESUREE EN DEUX TEMPS. Tant qu'il est a l'etranger, la regle unique de
  -- localisation refuse : `acteur_present_sur_site` compare le PAYS de sa fiche a celui du site.
  -- Republia n'exerce donc aucune contrainte chez lui, et aucune recherche internationale
  -- n'existe. Des qu'il ENTRE en Republia, la meme porte l'accepte.
  UPDATE public.personnages_donnees SET country = 'soviet', current_city = 'capitale',
         current_building = 'commissariat', current_room = 'accueil_police' WHERE name = PHIL;
  PERFORM pg_temp.je_suis(PHIL_U);
  v := public.temoin_deposer('banc-av-1', NULL, true);
  IF (v ->> 'raison') IS DISTINCT FROM 'presence_au_commissariat_requise' THEN
    ko := ko + 1; e := e || E'\nT31 : un temoin depose depuis l''etranger -- ' || v::text; END IF;
  PERFORM pg_temp.je_suis_le_serveur();
  UPDATE public.personnages_donnees SET country = 'republic' WHERE name = PHIL;
  PERFORM pg_temp.je_suis(PHIL_U);
  v := public.temoin_deposer('banc-av-1', NULL, true);
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE OR (v ->> 'refus') <> 'true' THEN
    ko := ko + 1; e := e || E'\nT31 : le refus de temoigner echoue -- ' || v::text; END IF;
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT count(*) INTO v_n FROM public.personnages_donnees d,
         jsonb_array_elements(CASE WHEN jsonb_typeof(d.recherche) = 'array' THEN d.recherche ELSE '[]'::jsonb END) x
   WHERE d.name = PHIL AND (x ->> 'acte') = 'non_presentation_temoin';
  IF v_n <> 0 THEN
    ko := ko + 1; e := e || E'\nT31 : la recherche du temoin survit a sa deposition'; END IF;
  SELECT count(*) INTO v_n FROM public.personnages_donnees d,
         jsonb_array_elements(CASE WHEN jsonb_typeof(d.recherche) = 'array' THEN d.recherche ELSE '[]'::jsonb END) x
   WHERE d.name = PHIL AND (x ->> 'id') = 'banc-infraction';
  IF v_n <> 1 THEN
    ko := ko + 1; e := e || E'\nT31 : une recherche independante a ete effacee'; END IF;

  -- ------ T32 : LE VERROU DE L'AUDIENCE. Plus de revocation, plus d'abandon, plus de citation.
  n := n + 1;
  UPDATE public.rp_epoques SET jour_un = jour_un + 6 WHERE pays = 'republic';
  INSERT INTO public.postes_attribues (id, country, poste_id, city, titulaire, source)
  VALUES ('banc-av-juge', 'republic', 'juge', 'capitale', LEE, 'banc');
  UPDATE public.personnages_donnees SET poste = jsonb_build_object('id', 'juge', 'city', 'capitale'),
         country = 'republic' WHERE name = LEE;
  UPDATE public.plaintes_en_cours
     SET data = (data::jsonb || '{"status":"saisie"}'::jsonb)::text WHERE id = 'banc-av-1';
  -- L'AUDIENCE A DESORMAIS UN JOUR ET UN LIEU (lot 6, 12 octobre 2026). Le decor doit donc fixer
  -- la date, laisser le temps l'atteindre, et POSER LE JUGE DANS SA SALLE -- sans quoi l'ouverture
  -- est refusee pour `jour_d_audience_non_fixe`, `jour_d_audience_non_venu` ou
  -- `presence_du_juge_requise`, et ce banc mesurerait l'audience d'avant.
  UPDATE public.personnages_donnees SET country = 'republic', current_city = 'capitale',
         current_building = 'tribunal', current_room = 'salle_audience' WHERE name = LEE;
  v_jour := public.jour_de_jeu_pays('republic');
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.justice_audience_fixer('banc-av-1', v_jour + 3);
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nT32 : le jour d''audience ne se fixe pas -- ' || v::text; END IF;
  PERFORM pg_temp.je_suis_le_serveur();
  UPDATE public.rp_epoques SET jour_un = jour_un - 3 WHERE pays = 'republic';
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.justice_audience_ouvrir('banc-av-1');
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nT32 : l''audience ne s''ouvre pas -- ' || v::text; END IF;
  PERFORM pg_temp.je_suis(BEN_U);
  v := public.defense_rompre('banc-av-1');
  IF (v ->> 'raison') IS DISTINCT FROM 'audience_ouverte' THEN
    ko := ko + 1; e := e || E'\nT32 : on revoque son avocat a l''audience -- ' || v::text; END IF;
  PERFORM pg_temp.je_suis(MARS_U);
  v := public.defense_rompre('banc-av-1');
  IF (v ->> 'raison') IS DISTINCT FROM 'audience_ouverte' THEN
    ko := ko + 1; e := e || E'\nT32 : l''avocat abandonne a l''audience -- ' || v::text; END IF;
  v := public.temoin_citer('banc-av-1', 'Un quidam qui n''existe pas');
  IF (v ->> 'raison') IS DISTINCT FROM 'audience_ouverte' THEN
    ko := ko + 1; e := e || E'\nT32 : l''avocat cite un temoin a l''audience -- ' || v::text; END IF;

  -- ------- T33 : LE DROIT D'ECRIRE A L'AUDIENCE APPARTIENT AU JUGE, ET SE RETIRE
  n := n + 1;
  PERFORM pg_temp.je_suis(BEN_U);
  v := public.justice_audience_parole('banc-av-1', PHIL, true);
  IF (v ->> 'raison') IS DISTINCT FROM 'pas_juge_de_cette_ville' THEN
    ko := ko + 1; e := e || E'\nT33 : un prevenu distribue la parole -- ' || v::text; END IF;
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.justice_audience_parole('banc-av-1', PHIL, true);
  IF coalesce((v ->> 'peut_ecrire')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nT33 : la parole donnee n''ouvre pas le droit d''ecrire'; END IF;
  v := public.justice_audience_parole('banc-av-1', PHIL, false);
  IF coalesce((v ->> 'peut_ecrire')::boolean, true) IS NOT FALSE THEN
    ko := ko + 1; e := e || E'\nT33 : la parole retiree laisse encore ecrire'; END IF;

  -- ------- T34 : LA CLOTURE DE L'AFFAIRE ETEINT SES CITATIONS, ET CELLES-LA SEULEMENT
  n := n + 1;
  PERFORM pg_temp.je_suis_le_serveur();
  -- une citation neuve, encore vivante, sur banc-av-1
  PERFORM pg_temp.je_suis(LEE_U);
  PERFORM public.temoin_citer('banc-av-1', MARS);
  PERFORM pg_temp.je_suis_le_serveur();
  -- DEUX AVANCES D'HORLOGE, PAS UNE. La seconde convocation REPOUSSE l'echeance de deux jours :
  -- la rejouer dans la meme journee ne trouve plus rien a echoir. Le banc l'a appris en rouge.
  UPDATE public.rp_epoques SET jour_un = jour_un - 3 WHERE pays = 'republic';
  PERFORM public.temoins_convocations_echues();
  UPDATE public.rp_epoques SET jour_un = jour_un - 3 WHERE pays = 'republic';
  PERFORM public.temoins_convocations_echues();
  IF NOT public.justice_est_recherche(MARS) THEN
    ko := ko + 1; e := e || E'\nT34 : le decor de la cloture n''a pas ouvert de recherche'; END IF;
  UPDATE public.plaintes_en_cours
     SET data = (data::jsonb || '{"status":"non_lieu"}'::jsonb)::text WHERE id = 'banc-av-1';
  SELECT count(*) INTO v_n FROM public.temoins_citations
   WHERE affaire = 'banc-av-1' AND etat <> 'close';
  IF v_n <> 0 THEN
    ko := ko + 1; e := e || E'\nT34 : ' || v_n || ' citation(s) survivent a la cloture'; END IF;
  SELECT count(*) INTO v_n FROM public.personnages_donnees d,
         jsonb_array_elements(CASE WHEN jsonb_typeof(d.recherche) = 'array' THEN d.recherche ELSE '[]'::jsonb END) x
   WHERE d.name = MARS AND (x ->> 'acte') = 'non_presentation_temoin';
  IF v_n <> 0 THEN
    ko := ko + 1; e := e || E'\nT34 : la recherche du temoin survit a la cloture'; END IF;
  SELECT count(*) INTO v_n FROM public.personnages_donnees d,
         jsonb_array_elements(CASE WHEN jsonb_typeof(d.recherche) = 'array' THEN d.recherche ELSE '[]'::jsonb END) x
   WHERE d.name = PHIL AND (x ->> 'id') = 'banc-infraction';
  IF v_n <> 1 THEN
    ko := ko + 1; e := e || E'\nT34 : la cloture a efface une recherche d''une autre cause'; END IF;
  UPDATE public.rp_epoques SET jour_un = jour_un + 9 WHERE pays = 'republic';

  IF ko > 0 THEN RAISE EXCEPTION 'banc avocat/temoins : % EPREUVE(S) ROUGE(S) sur % --%', ko, n, e; END IF;
  RAISE EXCEPTION 'banc avocat/temoins : LES % EPREUVES SONT VERTES. -- rien ne doit rester', n;
END $banc$;
ROLLBACK;
