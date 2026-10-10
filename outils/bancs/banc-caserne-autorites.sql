-- BANC DE LA CASERNE -- AUTORITE DE LA CAISSE, INSPECTION, ORDRE DE BATAILLE (10 octobre 2026)
--
-- CE BANC NE COMMITE RIEN. Il pose un decor dans des tables de JEU -- `personnages_donnees`,
-- `compagnies_militaires`, `caisses_batiments` -- et se termine par un RAISE EXCEPTION
-- INCONDITIONNEL, que les epreuves soient vertes ou rouges. Un banc du 4 octobre 2026 a laisse
-- une accusation forgee au nom d'un joueur reel pendant six jours parce qu'il avait commite.
--
-- CE QU'IL PROUVE, et qu'une migration ne peut pas prouver (elle commite) :
--   . le ministre de la Defense ALIMENTE la caserne et ne peut plus la DEBITER ;
--   . le Commandant depense la caisse de la caserne, et peut en reverser au ministere ;
--   . un reversement refuse n'ecrit rien -- ni debit, ni credit, ni moitie ;
--   . l'inspection est ouverte au Lieutenant, au Capitaine, au Commandant et au ministre,
--     refusee au soldat et au civil, avec le perimetre de chacun ;
--   . l'ordre de bataille complet n'est plus lisible par un civil, qui garde la PRESENCE ;
--   . et la CONTRE-EPREUVE : si l'on rend le GRANT, le civil relit tout -- c'est donc bien la
--     revocation qui ferme, et pas un hasard de policy.
--
-- MESURES DE DEPART (10 octobre 2026) : caserne 17 778 FR, ministere de la Defense 66 191 FR,
-- une compagnie `compagnie-republic-1790116175239`, section s1 tenue par Vince Kubrick avec
-- 24 soldats, sections s2 a s4 vides et sans lieutenant, aucun capitaine.
--
-- Usage : coller ce fichier dans un execute_sql. Il doit finir sur
--   ERROR: banc caserne : LES 24 EPREUVES SONT VERTES. -- rien ne doit rester
-- Le verdict voyage DANS l'exception, parce que le canal technique ne rapporte ni NOTICE ni
-- WARNING. Toute autre fin est un echec, et le message nomme alors chaque epreuve rouge.

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

-- Depuis le registre 561, une fonction neuve n'est appelable par personne : sans ces deux GRANT
-- le banc reprendrait son identite de serveur et TOUT passerait pour la mauvaise raison.
GRANT EXECUTE ON FUNCTION pg_temp.je_suis(text) TO PUBLIC;
GRANT EXECUTE ON FUNCTION pg_temp.je_suis_le_serveur() TO PUBLIC;

DO $banc$
DECLARE
  ARNIE text := '9abef1c4-75ab-4352-b5ca-a219fc37a35c';  -- ministre de la Defense (reel)
  VINCE text := '585ae078-342b-435d-b187-93be52c8ccfb';  -- Lieutenant (reel)
  BEN   text := 'bafc96b1-1628-4ae2-93d2-78d89f8ac5b5';  -- Commandant (decor)
  MARS  text := 'a5a55fc8-64fa-4406-b617-76439d1d4aac';  -- Capitaine (decor)
  MAY   text := '3d91b1fa-a22d-41ae-82cf-fef98194b10a';  -- soldat (decor)
  LEE   text := 'ea4a2a0c-a192-4e10-8cff-d5db9b1cceb6';  -- civil
  CIE   text := 'compagnie-republic-1790116175239';
  SEC   text := 'compagnie-republic-1790116175239-s1';
  v jsonb; ko integer := 0; n integer := 0;
  v_cas numeric; v_min numeric; v_cas2 numeric; v_min2 numeric;
  v_data jsonb; v_sol jsonb; v_echecs text := '';
BEGIN
  -- ================================ LE DECOR ================================
  PERFORM pg_temp.je_suis_le_serveur();

  UPDATE public.personnages_donnees
     SET poste = jsonb_build_object('id', 'commandant', 'name', 'Commandant de la Caserne')
   WHERE name = 'Ben';
  UPDATE public.personnages_donnees
     SET poste = jsonb_build_object('id', 'capitaine', 'name', 'Capitaine', 'compagnieId', CIE)
   WHERE name = 'Marsault';
  UPDATE public.personnages_donnees
     SET poste = jsonb_build_object('id', 'soldat', 'name', 'Soldat')
   WHERE name = 'May';
  UPDATE public.compagnies_militaires
     SET data = data || jsonb_build_object('capitaineNom', 'Marsault')
   WHERE id = CIE;

  -- Le decor a-t-il pris ? Si l'attestation avait refuse, les epreuves refuseraient pour la
  -- mauvaise raison et le banc verdirait a tort.
  IF (SELECT poste->>'id' FROM public.personnages_donnees WHERE name = 'Ben') IS DISTINCT FROM 'commandant'
     OR (SELECT poste->>'id' FROM public.personnages_donnees WHERE name = 'Marsault') IS DISTINCT FROM 'capitaine'
     OR (SELECT poste->>'id' FROM public.personnages_donnees WHERE name = 'May') IS DISTINCT FROM 'soldat' THEN
    RAISE EXCEPTION 'DECOR : les postes du banc ne sont pas poses';
  END IF;

  -- ============ EPREUVE 0 : LE BANC PORTE VRAIMENT L'IDENTITE QU'IL CROIT ============
  PERFORM pg_temp.je_suis(LEE);
  n := n + 1;
  IF current_user <> 'authenticated' OR public.mon_personnage() IS DISTINCT FROM 'Lee Capene' THEN
    RAISE EXCEPTION 'E0 identite de banc non prise : role=%, personnage=%',
      current_user, coalesce(public.mon_personnage(), 'NULL');
  END IF;

  -- ===================== LA CAISSE : QUI PEUT DEBITER LA CASERNE =====================
  -- E1 un civil, non.
  PERFORM pg_temp.je_suis(LEE);
  v := public.caisse_client_mouvement('republic_caserne-militaire', -100, 'banc');
  n := n + 1;
  IF coalesce((v->>'ok')::boolean, true) OR v->>'raison' <> 'autorite_insuffisante' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\n  . ' || format('E1 un civil debite la caserne : %s', v); END IF;

  -- E2 LE MINISTRE DE LA DEFENSE, NON PLUS -- c'est la fermeture de ce lot.
  PERFORM pg_temp.je_suis(ARNIE);
  v := public.caisse_client_mouvement('republic_caserne-militaire', -100, 'banc');
  n := n + 1;
  IF coalesce((v->>'ok')::boolean, true) OR v->>'raison' <> 'autorite_insuffisante' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\n  . ' || format('E2 le ministre puise encore dans la caserne : %s', v); END IF;

  -- E3 le Commandant, oui.
  PERFORM pg_temp.je_suis(BEN);
  SELECT (data->>'solde')::numeric INTO v_cas FROM public.caisses_batiments WHERE id = 'republic_caserne-militaire';
  v := public.caisse_client_mouvement('republic_caserne-militaire', -100, 'banc');
  SELECT (data->>'solde')::numeric INTO v_cas2 FROM public.caisses_batiments WHERE id = 'republic_caserne-militaire';
  n := n + 1;
  IF NOT coalesce((v->>'ok')::boolean, false) OR v_cas2 <> v_cas - 100 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\n  . ' || format('E3 le Commandant ne peut pas depenser : %s (%s -> %s)', v, v_cas, v_cas2); END IF;

  -- E4 LE MINISTRE ALIMENTE, et les deux caisses bougent d'un seul coup.
  PERFORM pg_temp.je_suis(ARNIE);
  SELECT (data->>'solde')::numeric INTO v_cas FROM public.caisses_batiments WHERE id = 'republic_caserne-militaire';
  SELECT (data->>'solde')::numeric INTO v_min FROM public.caisses_batiments WHERE id = 'republic_gouvernement-min_def';
  v := public.caisse_ministere_mouvement('republic_gouvernement-min_def', 500, 'republic_caserne-militaire');
  SELECT (data->>'solde')::numeric INTO v_cas2 FROM public.caisses_batiments WHERE id = 'republic_caserne-militaire';
  SELECT (data->>'solde')::numeric INTO v_min2 FROM public.caisses_batiments WHERE id = 'republic_gouvernement-min_def';
  n := n + 1;
  IF NOT coalesce((v->>'ok')::boolean, false) OR v_cas2 <> v_cas + 500 OR v_min2 <> v_min - 500 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\n  . ' || format('E4 l alimentation de la caserne est cassee : %s (caserne %s -> %s, min %s -> %s)',
      v, v_cas, v_cas2, v_min, v_min2); END IF;

  -- ===================== LE REVERSEMENT CASERNE -> MINISTERE =====================
  -- E5 le Commandant reverse : exactement le montant, dans les deux sens.
  PERFORM pg_temp.je_suis(BEN);
  SELECT (data->>'solde')::numeric INTO v_cas FROM public.caisses_batiments WHERE id = 'republic_caserne-militaire';
  SELECT (data->>'solde')::numeric INTO v_min FROM public.caisses_batiments WHERE id = 'republic_gouvernement-min_def';
  v := public.caserne_reverser_au_ministere(1200);
  SELECT (data->>'solde')::numeric INTO v_cas2 FROM public.caisses_batiments WHERE id = 'republic_caserne-militaire';
  SELECT (data->>'solde')::numeric INTO v_min2 FROM public.caisses_batiments WHERE id = 'republic_gouvernement-min_def';
  n := n + 1;
  IF NOT coalesce((v->>'ok')::boolean, false) OR v_cas2 <> v_cas - 1200 OR v_min2 <> v_min + 1200 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\n  . ' || format('E5 le reversement ne fait pas ce qu il dit : %s (caserne %s -> %s, min %s -> %s)',
      v, v_cas, v_cas2, v_min, v_min2); END IF;

  -- E6 un civil ne reverse pas. exiger_poste LEVE : on capture.
  PERFORM pg_temp.je_suis(LEE);
  n := n + 1;
  BEGIN
    v := public.caserne_reverser_au_ministere(100);
    ko := ko + 1; v_echecs := v_echecs || E'\n  . ' || format('E6 un civil a reverse : %s', v);
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  -- E7 LE MINISTRE NON PLUS : reverser est une decision du Commandant.
  PERFORM pg_temp.je_suis(ARNIE);
  n := n + 1;
  BEGIN
    v := public.caserne_reverser_au_ministere(100);
    ko := ko + 1; v_echecs := v_echecs || E'\n  . ' || format('E7 le ministre a reverse a sa place : %s', v);
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  -- E8 SOLDE INSUFFISANT : refus, et AUCUNE moitie ecrite.
  PERFORM pg_temp.je_suis(BEN);
  SELECT (data->>'solde')::numeric INTO v_cas FROM public.caisses_batiments WHERE id = 'republic_caserne-militaire';
  SELECT (data->>'solde')::numeric INTO v_min FROM public.caisses_batiments WHERE id = 'republic_gouvernement-min_def';
  v := public.caserne_reverser_au_ministere(v_cas + 1);
  SELECT (data->>'solde')::numeric INTO v_cas2 FROM public.caisses_batiments WHERE id = 'republic_caserne-militaire';
  SELECT (data->>'solde')::numeric INTO v_min2 FROM public.caisses_batiments WHERE id = 'republic_gouvernement-min_def';
  n := n + 1;
  IF coalesce((v->>'ok')::boolean, true) OR v->>'raison' <> 'solde_insuffisant'
     OR v_cas2 <> v_cas OR v_min2 <> v_min THEN
    ko := ko + 1; v_echecs := v_echecs || E'\n  . ' || format('E8 un reversement refuse a quand meme ecrit : %s (%s -> %s, %s -> %s)',
      v, v_cas, v_cas2, v_min, v_min2); END IF;

  -- E9 montants invalides : refus, rien ecrit.
  n := n + 1;
  IF coalesce((public.caserne_reverser_au_ministere(0)->>'ok')::boolean, true)
     OR coalesce((public.caserne_reverser_au_ministere(-50)->>'ok')::boolean, true)
     OR coalesce((public.caserne_reverser_au_ministere(NULL)->>'ok')::boolean, true) THEN
    ko := ko + 1; v_echecs := v_echecs || E'\n  . ' || format('E9 un montant invalide est accepte'); END IF;

  -- ===================== L'INSPECTION DES TROUPES =====================
  -- E10 un civil : refuse.
  PERFORM pg_temp.je_suis(LEE);
  v := public.militaire_inspection_perimetre();
  n := n + 1;
  IF coalesce((v->>'ok')::boolean, true) OR v->>'raison' <> 'hors_chaine_d_inspection' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\n  . ' || format('E10 un civil inspecte les troupes : %s', v); END IF;

  -- E11 un soldat : refuse (il est dans la chaine de commandement, pas dans celle d inspection).
  PERFORM pg_temp.je_suis(MAY);
  v := public.militaire_inspection_perimetre();
  n := n + 1;
  IF coalesce((v->>'ok')::boolean, true) OR v->>'raison' <> 'hors_chaine_d_inspection' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\n  . ' || format('E11 un soldat inspecte les troupes : %s', v); END IF;

  -- E12 le Lieutenant : autorise, perimetre = sa section.
  PERFORM pg_temp.je_suis(VINCE);
  v := public.militaire_inspection_perimetre();
  n := n + 1;
  IF NOT coalesce((v->>'ok')::boolean, false) OR v->>'portee' <> 'section'
     OR NOT (v->'sections' ? SEC) OR NOT (v->'compagnies' ? CIE) THEN
    ko := ko + 1; v_echecs := v_echecs || E'\n  . ' || format('E12 le Lieutenant n a pas sa section : %s', v); END IF;

  -- E13 le Capitaine : autorise, perimetre = sa compagnie.
  PERFORM pg_temp.je_suis(MARS);
  v := public.militaire_inspection_perimetre();
  n := n + 1;
  IF NOT coalesce((v->>'ok')::boolean, false) OR v->>'portee' <> 'compagnie'
     OR NOT (v->'compagnies' ? CIE) THEN
    ko := ko + 1; v_echecs := v_echecs || E'\n  . ' || format('E13 le Capitaine n a pas sa compagnie : %s', v); END IF;

  -- E14 le Commandant : autorise, toute l armee.
  PERFORM pg_temp.je_suis(BEN);
  v := public.militaire_inspection_perimetre();
  n := n + 1;
  IF NOT coalesce((v->>'ok')::boolean, false) OR v->>'portee' <> 'armee' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\n  . ' || format('E14 le Commandant n inspecte pas l armee : %s', v); END IF;

  -- E15 le ministre de la Defense : autorise, toute l armee.
  PERFORM pg_temp.je_suis(ARNIE);
  v := public.militaire_inspection_perimetre();
  n := n + 1;
  IF NOT coalesce((v->>'ok')::boolean, false) OR v->>'portee' <> 'armee' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\n  . ' || format('E15 le ministre n inspecte pas l armee : %s', v); END IF;

  -- ===================== L'ORDRE DE BATAILLE =====================
  -- E16 plus aucun SELECT direct pour le navigateur.
  n := n + 1;
  IF has_table_privilege('authenticated', 'public.compagnies_militaires', 'SELECT') THEN
    ko := ko + 1; v_echecs := v_echecs || E'\n  . ' || format('E16 authenticated garde un SELECT sur compagnies_militaires'); END IF;

  -- E17 un civil, par la RPC : pas de matricule, pas de PA, pas d arme, pas de reserve.
  PERFORM pg_temp.je_suis(LEE);
  SELECT l.data INTO v_data FROM public.militaire_compagnies_lisibles() l WHERE l.id = CIE;
  n := n + 1;
  IF v_data IS NULL THEN
    ko := ko + 1; v_echecs := v_echecs || E'\n  . ' || format('E17 un civil ne voit meme plus la presence');
  ELSE
    v_sol := v_data->'sections'->0->'soldats'->0;
    IF (v_data ? 'reserve') OR (v_data ? 'contingentInitial') OR (v_data ? 'tresorerie')
       OR (v_sol ? 'matricule') OR (v_sol ? 'pa') OR (v_sol ? 'arme') OR (v_sol ? 'accessoires') THEN
      ko := ko + 1; v_echecs := v_echecs || E'\n  . ' || format('E17 l ordre de bataille fuit encore vers un civil : %s',
        jsonb_build_object('cie', (SELECT jsonb_agg(k) FROM jsonb_object_keys(v_data) k), 'soldat', v_sol));
    END IF;
  END IF;

  -- E18 ... mais il voit toujours la PRESENCE : qui mene, ou, et la consigne.
  n := n + 1;
  IF v_data IS NULL
     OR v_data->'sections'->0->>'lieutenantNom' IS DISTINCT FROM 'Vince Kubrick'
     OR jsonb_array_length(v_data->'sections'->0->'soldats') <> 24
     OR NOT (v_data->'sections'->0->'soldats'->0 ? 'leaderCourant') THEN
    ko := ko + 1; v_echecs := v_echecs || E'\n  . ' || format('E18 la presence n est plus observable : %s', v_data->'sections'->0); END IF;

  -- E19 le Lieutenant, lui, recoit le blob entier.
  PERFORM pg_temp.je_suis(VINCE);
  SELECT l.data INTO v_data FROM public.militaire_compagnies_lisibles() l WHERE l.id = CIE;
  n := n + 1;
  IF v_data IS NULL OR NOT (v_data ? 'reserve')
     OR NOT (v_data->'sections'->0->'soldats'->0 ? 'matricule') THEN
    ko := ko + 1; v_echecs := v_echecs || E'\n  . ' || format('E19 le Lieutenant a perdu sa section : %s', v_data); END IF;

  -- E20 le ministre de la Defense aussi.
  PERFORM pg_temp.je_suis(ARNIE);
  SELECT l.data INTO v_data FROM public.militaire_compagnies_lisibles() l WHERE l.id = CIE;
  n := n + 1;
  IF v_data IS NULL OR NOT (v_data ? 'reserve') THEN
    ko := ko + 1; v_echecs := v_echecs || E'\n  . ' || format('E20 le ministre ne voit plus l armee : %s', v_data); END IF;

  -- E21 le Capitaine de cette compagnie aussi.
  PERFORM pg_temp.je_suis(MARS);
  SELECT l.data INTO v_data FROM public.militaire_compagnies_lisibles() l WHERE l.id = CIE;
  n := n + 1;
  IF v_data IS NULL OR NOT (v_data ? 'reserve') THEN
    ko := ko + 1; v_echecs := v_echecs || E'\n  . ' || format('E21 le Capitaine ne voit pas sa compagnie : %s', v_data); END IF;

  -- E22 CONTRE-EPREUVE : si l on rend le GRANT, le civil relit TOUT en direct. C'est donc bien
  -- la revocation qui ferme, et non une policy restee par hasard.
  PERFORM pg_temp.je_suis_le_serveur();
  GRANT SELECT ON TABLE public.compagnies_militaires TO authenticated;
  CREATE POLICY banc_contre_epreuve ON public.compagnies_militaires FOR SELECT TO authenticated USING (true);
  PERFORM pg_temp.je_suis(LEE);
  SELECT c.data INTO v_data FROM public.compagnies_militaires c WHERE c.id = CIE;
  n := n + 1;
  IF v_data IS NULL OR NOT (v_data->'sections'->0->'soldats'->0 ? 'matricule') THEN
    ko := ko + 1; v_echecs := v_echecs || E'\n  . ' || format('E22 la contre-epreuve ne reproduit pas la fuite : %s', v_data); END IF;
  PERFORM pg_temp.je_suis_le_serveur();
  DROP POLICY banc_contre_epreuve ON public.compagnies_militaires;
  REVOKE SELECT ON TABLE public.compagnies_militaires FROM authenticated;

  -- E23 et une fois refermee, le civil ne lit plus rien en direct.
  PERFORM pg_temp.je_suis(LEE);
  n := n + 1;
  BEGIN
    SELECT c.data INTO v_data FROM public.compagnies_militaires c WHERE c.id = CIE;
    ko := ko + 1; v_echecs := v_echecs || E'\n  . ' || format('E23 le civil lit encore la table en direct');
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  -- LE VERDICT VOYAGE DANS L'EXCEPTION, et c'est volontaire : le canal technique ne rapporte
  -- ni NOTICE ni WARNING. Un banc dont le verdict se perd en route ne prouve rien. L'exception
  -- est de toute facon obligatoire -- elle est ce qui annule le decor.
  PERFORM pg_temp.je_suis_le_serveur();
  IF ko = 0 THEN
    RAISE EXCEPTION 'banc caserne : LES % EPREUVES SONT VERTES. -- rien ne doit rester', n;
  ELSE
    RAISE EXCEPTION 'banc caserne : ECHEC, % epreuve(s) sur % ont rougi.%', ko, n, v_echecs;
  END IF;
END $banc$;
ROLLBACK;
