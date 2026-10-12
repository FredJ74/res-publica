-- BANC DE LA CHAINE DU PARQUET (12 octobre 2026 au soir) -- 32 epreuves
--
-- CE BANC NE COMMITE RIEN. Il nomme un Procureur, un juge et un commissaire, joue la chaine
-- procedurale entiere sur six dossiers, et se termine par un RAISE EXCEPTION INCONDITIONNEL qui
-- annule tout.
--
-- POURQUOI IL EXISTE, ET CE QU'IL A TROUVE QUE LES PREUVES NE POUVAIENT PAS TROUVER. Les 37
-- preuves des cinq migrations sont STRUCTURELLES : elles lisent des catalogues, comptent des
-- droits, verifient qu'une condition figure dans un corps de fonction. Aucune ne peut prouver
-- qu'une ecriture ABOUTIT. Ce banc en a trouve DEUX qui n'aboutissaient pas :
--
--   1. LE DECLENCHEUR `plaintes_epingler_verdict` EFFACAIT LE STATUT ECRIT PAR LE PARQUET. Il
--      n'accepte que `affaire_autorite_de(NEW.city)` -- juge ou commissaire DE LA VILLE -- et le
--      Procureur est NATIONAL, donc sans ville. `parquet_poursuivre` rendait `ok: true`, le
--      dossier recevait sa qualification, et son `status` restait `au_parquet` : les poursuites
--      etaient engagees ET sans effet. Corrige en reconnaissant le parquet dans le declencheur.
--   2. `dossier_acte_consigner` ECHOUAIT EN SILENCE sur un type d'acte inconnu. `requalification`
--      manquait a la liste blanche, et la fonction rendait un refus propre que ses onze appelants
--      -- tous en `PERFORM` -- jetaient. Le jugement s'enregistrait, la chronologie avait un
--      trou. Corrige en la faisant LEVER.
--
-- Usage : coller ce fichier dans un execute_sql. Il doit finir sur
--   ERROR: banc parquet : LES 32 EPREUVES SONT VERTES. -- rien ne doit rester
--
-- DEUX PIEGES DE DECOR, pour qui le rejoue :
--   . un poste doit etre INSCRIT dans `postes_attribues` AVANT d'etre pose sur une fiche, sinon
--     `trg_personnages_attester_poste` refuse l'ecriture -- et c'est la garde qu'on veut laisser
--     en place, pas contourner ;
--   . le Procureur commence AILLEURS que dans le tribunal, exprès : c'est ce qui permet de
--     mesurer que la presence physique est reellement exigee avant de la lui accorder.

-- Le corps du banc est celui qui a ete execute le 12 octobre 2026 au soir ; il est reproduit
-- ici a l'identique. Les quatre personnages sont les PJ reels de la beta.
-- (voir le rapport de ce lot pour la liste des 32 epreuves et leur numerotation T1..T26)

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
  PROC_U text := 'a5a55fc8-64fa-4406-b617-76439d1d4aac'; PROC text := 'Marsault';
  JUGE_U text := 'ea4a2a0c-a192-4e10-8cff-d5db9b1cceb6'; JUGE text := 'Lee Capene';
  FLIC_U text := '0821bcdf-0c69-4ba3-adcd-f60d9b82b7bf'; FLIC text := 'Phileas Frogg';
  BEN_U  text := 'bafc96b1-1628-4ae2-93d2-78d89f8ac5b5'; BEN  text := 'Ben';
  v jsonb; n integer := 0; ko integer := 0; e text := '';
  v_n integer; v_pa_av integer; v_pa_ap integer; v_aff text; v_d jsonb; v_a2 text;
BEGIN
  PERFORM pg_temp.je_suis_le_serveur();
  -- DECOR. Le poste est inscrit au registre AVANT d'etre pose sur la fiche : le declencheur
  -- d'attestation refuserait sinon, et c'est la garde qu'on veut laisser en place.
  INSERT INTO public.postes_attribues (id, country, poste_id, city, titulaire, source) VALUES
    ('banc-proc', 'republic', 'procureur',   NULL,       PROC, 'banc'),
    ('banc-juge', 'republic', 'juge',        'capitale', JUGE, 'banc'),
    ('banc-flic', 'republic', 'commissaire', 'capitale', FLIC, 'banc');
  UPDATE public.personnages_donnees SET poste = jsonb_build_object('id','procureur','city',NULL,'name','Procureur') WHERE name = PROC;
  UPDATE public.personnages_donnees SET poste = jsonb_build_object('id','juge','city','capitale','name','Juge') WHERE name = JUGE;
  UPDATE public.personnages_donnees SET poste = jsonb_build_object('id','commissaire','city','capitale','name','Commissaire') WHERE name = FLIC;
  UPDATE public.personnages_donnees SET current_city='capitale', current_building='commissariat', current_room='accueil_police', pa=10 WHERE name = BEN;
  -- Le Procureur commence HORS du tribunal : c'est ce qui rend l'epreuve T5 possible.
  UPDATE public.personnages_donnees SET current_city='capitale', current_building='banque-nationale', current_room=NULL WHERE name = PROC;
  UPDATE public.personnages_donnees SET current_city='capitale', current_building='tribunal', current_room='salle_audience' WHERE name = JUGE;
  UPDATE public.personnages_donnees SET current_city='capitale', current_building='commissariat', current_room='accueil_police' WHERE name = FLIC;

  n := n + 1;   -- T1/T2 : la plainte est payee, arrive AU PARQUET, et n'instruit RIEN.
  SELECT pa INTO v_pa_av FROM public.personnages_donnees WHERE name = BEN;
  PERFORM pg_temp.je_suis(BEN_U);
  v := public.plainte_deposer(JUGE, 'Il a pris mon manteau', 'delit_mineur');
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT pa INTO v_pa_ap FROM public.personnages_donnees WHERE name = BEN;
  v_aff := v ->> 'id';
  SELECT data::jsonb INTO v_d FROM public.plaintes_en_cours WHERE id = v_aff;
  IF coalesce((v->>'ok')::boolean,false) IS NOT TRUE OR (v_pa_av - v_pa_ap) <> 1
     OR v_d ->> 'status' <> 'au_parquet' OR v_d ->> 'categorie_alleguee' <> 'delit_mineur'
     OR (SELECT count(*) FROM public.detentions WHERE nom = JUGE AND jour_fin_effective IS NULL) <> 0 THEN
    ko:=ko+1; e:=e||E'\nT1 depot : '||v::text; END IF;

  n := n + 1;   -- T21a : la chronologie porte deja l'acte de depot, au rang 1.
  SELECT count(*) INTO v_n FROM public.dossiers_judiciaires_actes
   WHERE affaire = v_aff AND rang = 1 AND type = 'plainte_deposee' AND acteur = BEN;
  IF v_n <> 1 THEN ko:=ko+1; e:=e||E'\nT21a acte de depot absent'; END IF;

  n := n + 1;   -- T3 : le commissaire ne peut plus classer.
  PERFORM pg_temp.je_suis(FLIC_U);
  v := public.plainte_traiter(v_aff, 'classer');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'classement_reserve_au_parquet' THEN ko:=ko+1; e:=e||E'\nT3 : '||v::text; END IF;

  n := n + 1;   -- T3b : et il ne peut pas enqueter sans ordre du parquet.
  PERFORM pg_temp.je_suis(FLIC_U);
  v := public.plainte_traiter(v_aff, 'enqueter');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'enquete_non_diligentee' THEN ko:=ko+1; e:=e||E'\nT3b : '||v::text; END IF;

  n := n + 1;   -- T4 : la porte du ministre n'existe plus.
  SELECT count(*) INTO v_n FROM pg_proc p
   WHERE p.pronamespace='public'::regnamespace AND p.proname='plainte_classer_ministere';
  IF v_n <> 0 THEN ko:=ko+1; e:=e||E'\nT4 la porte du ministre survit'; END IF;

  n := n + 1;   -- T5 : le Procureur hors du tribunal est refuse, et RIEN ne bouge.
  PERFORM pg_temp.je_suis(PROC_U);
  v := public.parquet_enqueter(v_aff);
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT data::jsonb INTO v_d FROM public.plaintes_en_cours WHERE id = v_aff;
  SELECT count(*) INTO v_n FROM public.dossiers_judiciaires_actes WHERE affaire = v_aff;
  IF coalesce(v->>'raison','') <> 'presence_requise' OR v_d ->> 'status' <> 'au_parquet' OR v_n <> 1 THEN
    ko:=ko+1; e:=e||E'\nT5 : '||v::text; END IF;

  n := n + 1;   -- T5b : le site exige est bien celui de la VILLE, et une ville inconnue rend NULL.
  IF public.parquet_site_competent('republic','capitale') <> 'tribunal'
     OR public.parquet_site_competent('republic','ville_b') <> 'tribunal-local'
     OR public.parquet_site_competent('republic','zzz') IS NOT NULL THEN
    ko:=ko+1; e:=e||E'\nT5b site competent'; END IF;

  UPDATE public.personnages_donnees SET current_building='tribunal', current_room='greffe' WHERE name = PROC;

  n := n + 1;   -- T6 : dans le tribunal, l'enquete est diligentee.
  PERFORM pg_temp.je_suis(PROC_U);
  v := public.parquet_enqueter(v_aff);
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT data::jsonb INTO v_d FROM public.plaintes_en_cours WHERE id = v_aff;
  IF coalesce((v->>'ok')::boolean,false) IS NOT TRUE OR v_d ->> 'status' <> 'enquete' THEN
    ko:=ko+1; e:=e||E'\nT6 : '||v::text; END IF;

  n := n + 1;   -- T6b : la police peut alors accomplir l'acte, et le statut NE BOUGE PAS.
  PERFORM pg_temp.je_suis(FLIC_U);
  v := public.plainte_traiter(v_aff, 'enqueter');
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT data::jsonb INTO v_d FROM public.plaintes_en_cours WHERE id = v_aff;
  IF coalesce((v->>'ok')::boolean,false) IS NOT TRUE OR v_d ->> 'status' <> 'enquete'
     OR coalesce((v_d->>'enquete_accomplie')::boolean,false) IS NOT TRUE THEN
    ko:=ko+1; e:=e||E'\nT6b : '||v::text; END IF;

  n := n + 1;   -- T8 : apres enquete, le non-lieu est possible.
  PERFORM pg_temp.je_suis(PROC_U);
  v := public.parquet_non_lieu(v_aff, 'Aucun element a charge');
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT data::jsonb INTO v_d FROM public.plaintes_en_cours WHERE id = v_aff;
  IF coalesce((v->>'ok')::boolean,false) IS NOT TRUE OR v_d ->> 'status' <> 'non_lieu'
     OR v_d ->> 'non_lieu_motif_declare' <> 'Aucun element a charge' THEN
    ko:=ko+1; e:=e||E'\nT8 : '||v::text; END IF;

  v_a2 := 'banc-aff-2';
  INSERT INTO public.plaintes_en_cours (id, country, city, data) VALUES (v_a2, 'republic', 'capitale',
    jsonb_build_object('id',v_a2,'auteur',BEN,'cible',FLIC,'motif','Il a menti','status','au_parquet','city','capitale','country','republic','jour',1)::text);
  n := n + 1;   -- T7 : non-lieu IMMEDIAT, sans enquete prealable.
  PERFORM pg_temp.je_suis(PROC_U);
  v := public.parquet_non_lieu(v_a2);
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT data::jsonb INTO v_d FROM public.plaintes_en_cours WHERE id = v_a2;
  IF coalesce((v->>'ok')::boolean,false) IS NOT TRUE OR v_d ->> 'status' <> 'non_lieu' THEN
    ko:=ko+1; e:=e||E'\nT7 : '||v::text; END IF;

  v_a2 := 'banc-aff-3';
  INSERT INTO public.plaintes_en_cours (id, country, city, data) VALUES (v_a2, 'republic', 'capitale',
    jsonb_build_object('id',v_a2,'auteur',BEN,'cible',FLIC,'motif','Il a tue mon chien','categorie_alleguee','delit_mineur','status','au_parquet','city','capitale','country','republic','jour',1)::text);

  n := n + 1;   -- T9 : une infraction inventee est refusee.
  PERFORM pg_temp.je_suis(PROC_U);
  v := public.parquet_poursuivre(v_a2, 'zz_pas_une_infraction');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'infraction_inconnue' THEN ko:=ko+1; e:=e||E'\nT9 : '||v::text; END IF;

  n := n + 1;   -- T10 : une CATEGORIE generique est refusee comme charge.
  PERFORM pg_temp.je_suis(PROC_U);
  v := public.parquet_poursuivre(v_a2, 'crime');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'infraction_inconnue' THEN ko:=ko+1; e:=e||E'\nT10 : '||v::text; END IF;

  n := n + 1;   -- T11a : les poursuites sont engagees, et le statut SUIT.
  PERFORM pg_temp.je_suis(PROC_U);
  v := public.parquet_poursuivre(v_a2, 'assassiner_mains');
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT data::jsonb INTO v_d FROM public.plaintes_en_cours WHERE id = v_a2;
  IF coalesce((v->>'ok')::boolean,false) IS NOT TRUE OR v_d ->> 'status' <> 'poursuites'
     OR v_d ->> 'qualification_parquet' <> 'assassiner_mains' THEN
    ko:=ko+1; e:=e||E'\nT11a : '||v::text; END IF;

  n := n + 1;   -- T24 : on ne juge pas une affaire dont on n'est pas saisi.
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.justice_rendre_sentence(v_a2, 'assassiner_mains', 'prison', 8, 0);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'affaire_non_saisie' THEN ko:=ko+1; e:=e||E'\nT24 : '||v::text; END IF;

  n := n + 1;   -- T11b : la saisine.
  PERFORM pg_temp.je_suis(PROC_U);
  v := public.parquet_transmettre_juge(v_a2);
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT data::jsonb INTO v_d FROM public.plaintes_en_cours WHERE id = v_a2;
  IF coalesce((v->>'ok')::boolean,false) IS NOT TRUE OR v_d ->> 'status' <> 'saisie' THEN
    ko:=ko+1; e:=e||E'\nT11b : '||v::text; END IF;

  n := n + 1;   -- T13 : abandon APRES saisine -> le juge doit decider, le dossier reste.
  PERFORM pg_temp.je_suis(PROC_U);
  v := public.parquet_abandonner(v_a2, 'Je me retire');
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT data::jsonb INTO v_d FROM public.plaintes_en_cours WHERE id = v_a2;
  IF coalesce((v->>'ok')::boolean,false) IS NOT TRUE OR v_d ->> 'status' <> 'abandon_demande'
     OR coalesce((v->>'apres_saisine')::boolean,false) IS NOT TRUE THEN
    ko:=ko+1; e:=e||E'\nT13 : '||v::text; END IF;

  n := n + 1;   -- T15 : le juge POURSUIT malgre l'abandon.
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.juge_suite_apres_abandon(v_a2, 'poursuivre');
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT data::jsonb INTO v_d FROM public.plaintes_en_cours WHERE id = v_a2;
  IF coalesce((v->>'ok')::boolean,false) IS NOT TRUE OR v_d ->> 'status' <> 'saisie' THEN
    ko:=ko+1; e:=e||E'\nT15 : '||v::text; END IF;

  n := n + 1;   -- T15b : les deux faits COEXISTENT dans la chronologie, distincts.
  SELECT count(*) INTO v_n FROM public.dossiers_judiciaires_actes
   WHERE affaire = v_a2 AND type IN ('abandon_poursuites','juge_poursuite_maintenue');
  IF v_n <> 2 THEN ko:=ko+1; e:=e||E'\nT15b : '||v_n||' au lieu de 2'; END IF;

  n := n + 1;   -- T19 : peine hors bornes refusee (assassiner_mains = 8 j -> [4,12]).
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.justice_rendre_sentence(v_a2, 'assassiner_mains', 'prison', 13, 0);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'peine_hors_bornes' THEN ko:=ko+1; e:=e||E'\nT19 : '||v::text; END IF;

  n := n + 1;   -- T20 : reference 1 jour -> plage [1,2], et JAMAIS 0.
  v := public.infraction_peine_bornes('vol');
  IF (v->>'jours_min')::int <> 1 OR (v->>'jours_max')::int <> 2 THEN
    ko:=ko+1; e:=e||E'\nT20 plage du vol : '||v::text; END IF;
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.justice_rendre_sentence(v_a2, 'vol', 'prison', 0, 0);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'peine_hors_bornes' OR (v->>'jours_min')::int <> 1 THEN
    ko:=ko+1; e:=e||E'\nT20b : '||v::text; END IF;

  n := n + 1;   -- T16/T18/T23 : le juge requalifie et condamne ; les TROIS niveaux survivent.
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.justice_rendre_sentence(v_a2, 'vol', 'prison', 2, 0);
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT data::jsonb INTO v_d FROM public.plaintes_en_cours WHERE id = v_a2;
  IF coalesce((v->>'ok')::boolean,false) IS NOT TRUE
     OR coalesce((v->>'requalifiee')::boolean,false) IS NOT TRUE
     OR v_d ->> 'status' <> 'jugee' OR v_d ->> 'qualification_parquet' <> 'assassiner_mains'
     OR v_d ->> 'qualification_finale' <> 'vol' OR v_d ->> 'categorie_alleguee' <> 'delit_mineur'
     OR v_d ->> 'motif' <> 'Il a tue mon chien' THEN
    ko:=ko+1; e:=e||E'\nT16 : '||v::text; END IF;

  n := n + 1;   -- T16b : la requalification est un acte DISTINCT, avec son avant et son apres.
  SELECT count(*) INTO v_n FROM public.dossiers_judiciaires_actes
   WHERE affaire = v_a2 AND type = 'requalification'
     AND qualif_avant = 'assassiner_mains' AND qualif_apres = 'vol';
  IF v_n <> 1 THEN ko:=ko+1; e:=e||E'\nT16b acte de requalification absent'; END IF;

  v_a2 := 'banc-aff-4';
  INSERT INTO public.plaintes_en_cours (id, country, city, data) VALUES (v_a2, 'republic', 'capitale',
    jsonb_build_object('id',v_a2,'auteur',BEN,'cible',FLIC,'motif','Vol de dossier','status','poursuites','qualification_parquet','vol','city','capitale','country','republic','jour',1)::text);
  n := n + 1;   -- T12 : abandon AVANT saisine -> la procedure s'arrete.
  PERFORM pg_temp.je_suis(PROC_U);
  v := public.parquet_abandonner(v_a2);
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT data::jsonb INTO v_d FROM public.plaintes_en_cours WHERE id = v_a2;
  IF coalesce((v->>'ok')::boolean,false) IS NOT TRUE OR v_d ->> 'status' <> 'abandonnee'
     OR coalesce((v->>'apres_saisine')::boolean,true) IS NOT FALSE THEN
    ko:=ko+1; e:=e||E'\nT12 : '||v::text; END IF;

  v_a2 := 'banc-aff-5';
  INSERT INTO public.plaintes_en_cours (id, country, city, data) VALUES (v_a2, 'republic', 'capitale',
    jsonb_build_object('id',v_a2,'auteur',BEN,'cible',FLIC,'motif','Incendie','status','saisie','qualification_parquet','incendier','city','capitale','country','republic','jour',1)::text);
  n := n + 1;   -- T17 : la relaxe est un VERDICT -- peine NULL, jamais zero.
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.justice_relaxer(v_a2);
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT data::jsonb INTO v_d FROM public.plaintes_en_cours WHERE id = v_a2;
  IF coalesce((v->>'ok')::boolean,false) IS NOT TRUE OR v_d ->> 'status' <> 'relaxe'
     OR v_d ->> 'verdict' <> 'relaxe'
     OR (SELECT peine FROM public.jugements WHERE id = 'jug-'||v_a2) IS NOT NULL
     OR (SELECT data->>'verdict' FROM public.jugements WHERE id = 'jug-'||v_a2) <> 'relaxe' THEN
    ko:=ko+1; e:=e||E'\nT17 : '||v::text; END IF;

  v_a2 := 'banc-aff-6';
  INSERT INTO public.plaintes_en_cours (id, country, city, data) VALUES (v_a2, 'republic', 'capitale',
    jsonb_build_object('id',v_a2,'auteur',BEN,'cible',FLIC,'motif','Abandon accepte','status','abandon_demande','qualification_parquet','vol','city','capitale','country','republic','jour',1)::text);
  n := n + 1;   -- T14 : le juge ACCEPTE l'arret.
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.juge_suite_apres_abandon(v_a2, 'arret');
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT data::jsonb INTO v_d FROM public.plaintes_en_cours WHERE id = v_a2;
  IF coalesce((v->>'ok')::boolean,false) IS NOT TRUE OR v_d ->> 'status' <> 'arret' THEN
    ko:=ko+1; e:=e||E'\nT14 : '||v::text; END IF;

  n := n + 1;   -- T21b : la chronologie est APPEND-ONLY -- UPDATE refuse.
  BEGIN
    UPDATE public.dossiers_judiciaires_actes SET acteur = 'quelqu un d autre' WHERE affaire = 'banc-aff-3';
    ko:=ko+1; e:=e||E'\nT21b un UPDATE a reussi';
  EXCEPTION WHEN raise_exception THEN NULL; END;

  n := n + 1;   -- T21c : et DELETE aussi.
  BEGIN
    DELETE FROM public.dossiers_judiciaires_actes WHERE affaire = 'banc-aff-3';
    ko:=ko+1; e:=e||E'\nT21c un DELETE a reussi';
  EXCEPTION WHEN raise_exception THEN NULL; END;

  n := n + 1;   -- T22 : le navigateur ne peut NI lire NI fabriquer un acte procedural.
  BEGIN
    PERFORM set_config('role', 'authenticated', true);
    PERFORM count(*) FROM public.dossiers_judiciaires_actes;
    ko:=ko+1; e:=e||E'\nT22a un client a lu la chronologie';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  PERFORM pg_temp.je_suis_le_serveur();
  BEGIN
    PERFORM pg_temp.je_suis(BEN_U);
    PERFORM public.dossier_acte_consigner('banc-aff-3','republic','capitale','relaxe', BEN);
    ko:=ko+1; e:=e||E'\nT22b un client a fabrique un acte';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  PERFORM pg_temp.je_suis_le_serveur();

  n := n + 1;   -- T26 : Fontaine n'est plus une autorite ; Honore et Saad le sont.
  SELECT count(*) INTO v_n FROM public.titulaires_pnj WHERE nom_pnj = 'Juge Fontaine';
  IF v_n <> 0 THEN ko:=ko+1; e:=e||E'\nT26 Fontaine est encore titulaire'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.titulaires_pnj WHERE poste_id='juge' AND city='capitale' AND nom_pnj='Honoré Cozetoujours (PNJ)')
     OR NOT EXISTS (SELECT 1 FROM public.titulaires_pnj WHERE poste_id='procureur' AND city IS NULL AND nom_pnj='Procureur Saad') THEN
    ko:=ko+1; e:=e||E'\nT26b Honore ou Saad absents'; END IF;

  n := n + 1;   -- T25 : le Ministre de la Justice est l'autorite du parquet, et personne d'autre.
  INSERT INTO public.postes_attribues (id, country, poste_id, city, titulaire, source)
  VALUES ('banc-minjust', 'republic', 'min_just', NULL, BEN, 'banc');
  UPDATE public.personnages_donnees SET poste = jsonb_build_object('id','min_just','city',NULL,'name','Ministre') WHERE name = BEN;
  PERFORM pg_temp.je_suis(BEN_U);
  SELECT count(*) INTO v_n FROM public.poste_autorite_de('procureur', NULL);
  PERFORM pg_temp.je_suis_le_serveur();
  IF v_n <> 1 THEN ko:=ko+1; e:=e||E'\nT25 le ministre n est pas l autorite du parquet'; END IF;
  PERFORM pg_temp.je_suis(FLIC_U);
  SELECT count(*) INTO v_n FROM public.poste_autorite_de('procureur', NULL);
  PERFORM pg_temp.je_suis_le_serveur();
  IF v_n <> 0 THEN ko:=ko+1; e:=e||E'\nT25b le commissaire peut nommer le procureur'; END IF;

  n := n + 1;   -- T23b : les deux lectures repondent a leur titulaire.
  PERFORM pg_temp.je_suis(PROC_U);
  v := public.parquet_dossiers();
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v->>'ok')::boolean,false) IS NOT TRUE THEN ko:=ko+1; e:=e||E'\nT23b : '||v::text; END IF;
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.juge_dossiers();
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v->>'ok')::boolean,false) IS NOT TRUE THEN ko:=ko+1; e:=e||E'\nT23c : '||v::text; END IF;

  IF ko = 0 THEN RAISE EXCEPTION 'banc parquet : LES % EPREUVES SONT VERTES. -- rien ne doit rester', n;
  ELSE RAISE EXCEPTION 'banc parquet : % epreuve(s) sur % en defaut.%', ko, n, e; END IF;
END
$banc$;
ROLLBACK;
