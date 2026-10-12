-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 12 OCTOBRE 2026
--
-- Registre Supabase : version 20261012093319 (UTC), nom
-- `parquet_autorite_du_verdict_et_compare_and_swap`.
-- Le registre passe de 674 a 675 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 c19d80fa945439a7558bc0c3088895a7, 20680 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LE PARQUET (4/7) -- LE DECLENCHEUR RECONNAIT LE PARQUET, ET LES PORTES REVENDIQUENT
--
-- DEUX DEFAUTS TROUVES PAR LE BANC, PAS PAR LE PLAN, et le premier est grave.
--
-- `plaintes_epingler_verdict` protege les champs d'issue judiciaire -- dont `status` -- contre
-- toute ecriture qui ne vient ni du serveur, ni d'un laissez-passer, ni de
-- `affaire_autorite_de(NEW.city)`. Cette derniere accepte le juge et le commissaire DE LA VILLE.
-- Or le Procureur est NATIONAL : son poste n'a pas de ville, donc il etait refuse.
-- MESURE AU BANC : `parquet_poursuivre` rendait `ok: true`, le dossier recevait bien sa
-- qualification et son horodatage -- et son `status` restait `au_parquet`, restaure par le
-- declencheur. Les poursuites etaient engagees ET sans effet, et toute la suite de la chaine se
-- refusait ensuite pour « statut_incompatible ». C'est le defaut recurrent du projet : DECIDE AU
-- SERVEUR N'EST PAS APPLIQUE AU SERVEUR.
--
-- LE CORRECTIF N'EST PAS UN LAISSEZ-PASSER. On pourrait entourer chaque UPDATE du parquet de
-- `set_config('rp.verdict_interne', 'on')` : ce serait cinq endroits ou l'oublier. La REGLE
-- D'AUTORITE est corrigee a sa source -- le declencheur protege contre les PARTIES a l'affaire,
-- et le Procureur n'est pas une partie.
--
-- SECOND DEFAUT : les six portes a transition n'en revendiquaient pas. Elles lisaient le statut,
-- puis ecrivaient sans verifier qu'il etait toujours celui-la. Elles passent en COMPARE-AND-SWAP :
-- la condition entre dans le WHERE de l'UPDATE, et un ROW_COUNT de zero devient un refus nomme.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- LE PARQUET DE REPUBLIA (4/4) -- LE DECLENCHEUR RECONNAIT LE PARQUET, ET LES PORTES REVENDIQUENT
-- 12 octobre 2026
--
-- DEUX DEFAUTS TROUVES PAR LE BANC, PAS PAR LE PLAN. Les deux etaient invisibles aux preuves
-- structurelles, et le second l'etait meme a l'oeil nu.
--
-- UN -- LE DECLENCHEUR EFFACAIT CE QUE LE PARQUET VENAIT D'ECRIRE.
-- `plaintes_epingler_verdict` protege les champs d'issue judiciaire -- `status`, `peine`, `juge`,
-- `sentence`, `jugement`, et les deux drapeaux de defense -- contre toute ecriture qui ne vient
-- ni du serveur, ni d'un laissez-passer explicite, ni de `affaire_autorite_de(NEW.city)`. Cette
-- derniere accepte le JUGE et le COMMISSAIRE DE LA VILLE, et personne d'autre.
--
-- Or le Procureur est NATIONAL : son poste n'a pas de ville, donc `affaire_autorite_de` le
-- refuse. Resultat mesure au banc : `parquet_poursuivre` rendait `ok: true`, le dossier recevait
-- bien `qualification_parquet`, `poursuites_par` et `poursuites_le` -- mais son `status` restait
-- `au_parquet`, restaure par le declencheur. Les poursuites etaient donc engagees ET sans effet,
-- et toute la suite de la chaine se refusait ensuite pour « statut_incompatible ».
--
-- C'EST LE DEFAUT RECURRENT DU PROJET : decide au serveur n'est pas applique au serveur. La porte
-- repondait honnetement sur ce qu'elle avait tente ; c'est l'ecriture qui ne passait pas.
--
-- LE CORRECTIF N'EST PAS UN LAISSEZ-PASSER. On pourrait entourer chaque UPDATE du parquet de
-- `set_config('rp.verdict_interne', 'on')`, comme le font la defense de l'accuse et comme le
-- faisait le classement ministeriel. Ce serait cinq endroits ou l'oublier. La REGLE D'AUTORITE
-- est corrigee a sa source : le declencheur protege contre les PARTIES a l'affaire, et le
-- Procureur n'est pas une partie -- c'est l'autorite qui conduit la procedure. Il est donc
-- reconnu comme telle, une fois, dans le declencheur.
--
-- DEUX -- LES PORTES NE REVENDIQUAIENT PAS LEUR TRANSITION.
-- Chaque acte du parquet lisait le statut dans la garde, puis ecrivait sans verifier que le
-- statut etait toujours celui-la. Deux actes simultanes sur le meme dossier -- un non-lieu et des
-- poursuites, par exemple -- se seraient tous deux crus autorises, et le second aurait ecrase le
-- premier en silence. Les six portes a transition passent donc en COMPARE-AND-SWAP : la condition
-- de statut entre dans le WHERE de l'UPDATE, et un ROW_COUNT de zero devient un refus nomme.
-- C'est le patron de revendication deja employe par le calendrier electoral et par les
-- subventions municipales.

-- ============================================================================================
-- 1. LE DECLENCHEUR RECONNAIT L'AUTORITE DU PARQUET
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.plaintes_epingler_verdict()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_old jsonb; v_new jsonb; v_cle text; v_proc record;
  -- Champs qui disent l'issue judiciaire. Tout le reste (defense, pieces, circonstances) reste
  -- librement modifiable par les parties.
  v_verdict constant text[] := ARRAY['status','sentence','peine','jugement','juge',
                                     'circonstanceAttenuante','aggravation'];
BEGIN
  IF public.est_appel_serveur() THEN RETURN NEW; END IF;
  -- LAISSEZ-PASSER DES PORTES DU CYCLE (10 octobre 2026). Il reste utilise par la defense de
  -- l'accuse, qui ecrit un champ de verdict pour le compte de quelqu'un qui n'est PAS une
  -- autorite. Le classement ministeriel, qui l'employait aussi, a disparu avec la porte.
  IF coalesce(current_setting('rp.verdict_interne', true), '') = 'on' THEN RETURN NEW; END IF;
  -- L'AUTORITE JUDICIAIRE DE LA VILLE : le juge, et le commissaire.
  IF public.affaire_autorite_de(NEW.city) THEN RETURN NEW; END IF;

  -- ET LE PARQUET (12 octobre 2026). Le Procureur est NATIONAL : son poste n'a pas de ville,
  -- donc `affaire_autorite_de` le refusait, et ce declencheur restaurait le `status` qu'il venait
  -- d'ecrire -- ses poursuites etaient engagees et sans effet. Il n'est pas une PARTIE a
  -- l'affaire, il est l'autorite qui conduit la procedure : la protection ne le vise pas. Le pays
  -- est verifie, parce qu'un procureur n'a d'autorite que sur les affaires du sien.
  SELECT * INTO v_proc FROM public.parquet_moi();
  IF v_proc.nom IS NOT NULL AND v_proc.pays IS NOT DISTINCT FROM NEW.country THEN
    RETURN NEW;
  END IF;

  -- L'auteur n'est ni l'autorite judiciaire, ni le parquet : on restaure les champs de verdict
  -- tels qu'ils etaient. Si l'un d'eux est illisible, on ne prend aucun risque.
  IF OLD.data IS NULL OR left(btrim(OLD.data), 1) <> '{'
     OR NEW.data IS NULL OR left(btrim(NEW.data), 1) <> '{' THEN
    RETURN NEW;
  END IF;

  BEGIN
    v_old := OLD.data::jsonb;
    v_new := NEW.data::jsonb;
  EXCEPTION WHEN OTHERS THEN
    RETURN NEW;
  END;

  FOREACH v_cle IN ARRAY v_verdict LOOP
    IF (v_new -> v_cle) IS DISTINCT FROM (v_old -> v_cle) THEN
      IF (v_old ? v_cle) THEN
        v_new := jsonb_set(v_new, ARRAY[v_cle], v_old -> v_cle);
      ELSE
        v_new := v_new - v_cle;   -- le champ n'existait pas : il n'apparait pas
      END IF;
    END IF;
  END LOOP;

  NEW.data := v_new::text;
  RETURN NEW;
END;
$$;
COMMENT ON FUNCTION public.plaintes_epingler_verdict() IS
  'Protege les champs d''issue judiciaire d''un dossier contre les ecritures des PARTIES. Trois autorites passent : le serveur, l''autorite judiciaire de la ville (juge ou commissaire) et, depuis le 12 octobre 2026, LE PARQUET de son pays -- le Procureur est national, donc affaire_autorite_de le refusait et ce declencheur restaurait le statut qu''il venait d''ecrire. Le laissez-passer rp.verdict_interne reste employe par la defense de l''accuse, qui n''est pas une autorite.';

-- ============================================================================================
-- 2. LES SIX PORTES A TRANSITION REVENDIQUENT LEUR STATUT
-- ============================================================================================
-- LE PATRON EST TOUJOURS LE MEME : la condition de statut entre dans le WHERE de l'UPDATE, et un
-- ROW_COUNT de zero devient `statut_a_change`. Deux actes simultanes ne peuvent donc plus se
-- croire tous deux autorises.

CREATE OR REPLACE FUNCTION public.parquet_enqueter(p_affaire_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_g jsonb; v_a jsonb; v_n integer;
BEGIN
  v_g := public.parquet_garde(p_affaire_id, ARRAY['au_parquet']);
  IF coalesce((v_g ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_g; END IF;
  v_a := v_g -> 'affaire';

  UPDATE public.plaintes_en_cours
     SET data = (v_a || jsonb_build_object(
           'status', 'enquete',
           'enquete_par', v_g ->> 'procureur',
           'enquete_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))::text
   WHERE id = p_affaire_id AND (data::jsonb ->> 'status') = 'au_parquet';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'statut_a_change'); END IF;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_g ->> 'pays', v_g ->> 'ville',
    'enquete_diligentee', v_g ->> 'procureur', 'procureur');
  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id, 'statut', 'enquete');
END;
$$;

CREATE OR REPLACE FUNCTION public.parquet_non_lieu(p_affaire_id text, p_motif text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_g jsonb; v_a jsonb; v_motif text; v_n integer;
BEGIN
  v_g := public.parquet_garde(p_affaire_id, ARRAY['au_parquet', 'enquete']);
  IF coalesce((v_g ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_g; END IF;
  v_a := v_g -> 'affaire';
  v_motif := nullif(btrim(coalesce(p_motif, '')), '');

  -- UN NON-LIEU N'EST PAS UN VERDICT SUR LES FAITS. Le serveur enregistre que le parquet a
  -- decide de ne pas poursuivre, et rien de plus : ni que la plainte etait mensongere, ni que la
  -- personne visee est innocente. Le motif, quand il y en a un, est le TEXTE DU PROCUREUR --
  -- une declaration de joueur, pas une conclusion du serveur.
  UPDATE public.plaintes_en_cours
     SET data = (v_a || jsonb_build_object(
           'status', 'non_lieu',
           'non_lieu_par', v_g ->> 'procureur',
           'non_lieu_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
           'non_lieu_motif_declare', v_motif))::text
   WHERE id = p_affaire_id AND (data::jsonb ->> 'status') IN ('au_parquet', 'enquete');
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'statut_a_change'); END IF;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_g ->> 'pays', v_g ->> 'ville',
    'non_lieu', v_g ->> 'procureur', 'procureur', NULL, NULL,
    CASE WHEN v_motif IS NULL THEN NULL
         ELSE jsonb_build_object('motif_declare', v_motif) END);
  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id, 'statut', 'non_lieu');
END;
$$;
COMMENT ON FUNCTION public.parquet_non_lieu(text, text) IS
  'Le parquet decide de ne pas poursuivre. Possible SANS enquete prealable. Le serveur enregistre la DECISION, jamais une conclusion sur les faits : un non-lieu ne dit ni que la plainte etait mensongere, ni que la personne visee est innocente. Le motif eventuel est le texte du Procureur, conserve comme declaration. Transition revendiquee par compare-and-swap.';

CREATE OR REPLACE FUNCTION public.parquet_poursuivre(p_affaire_id text, p_infraction text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_g jsonb; v_a jsonb; v_inf text; v_lib text; v_n integer;
BEGIN
  v_g := public.parquet_garde(p_affaire_id, ARRAY['au_parquet', 'enquete']);
  IF coalesce((v_g ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_g; END IF;
  v_a := v_g -> 'affaire';

  -- LA QUALIFICATION EST CANONIQUE, OU ELLE N'EST PAS. `infraction_canonique` est fail closed et
  -- refuse aussi un nom de CATEGORIE : on ne poursuit pas quelqu'un pour « crime » en general.
  v_inf := public.infraction_canonique(p_infraction);
  IF v_inf IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'infraction_inconnue', 'demande', p_infraction);
  END IF;
  SELECT libelle INTO v_lib FROM public.infractions WHERE id = v_inf;

  UPDATE public.plaintes_en_cours
     SET data = (v_a || jsonb_build_object(
           'status', 'poursuites',
           'qualification_parquet', v_inf,
           'qualification_parquet_libelle', v_lib,
           'poursuites_par', v_g ->> 'procureur',
           'poursuites_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))::text
   WHERE id = p_affaire_id AND (data::jsonb ->> 'status') IN ('au_parquet', 'enquete');
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'statut_a_change'); END IF;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_g ->> 'pays', v_g ->> 'ville',
    'poursuites_engagees', v_g ->> 'procureur', 'procureur', NULL, v_inf,
    jsonb_build_object('accuse', v_a ->> 'cible',
                       'categorie_alleguee', v_a ->> 'categorie_alleguee'));
  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id, 'statut', 'poursuites',
                            'qualification', v_inf, 'libelle', v_lib);
END;
$$;
COMMENT ON FUNCTION public.parquet_poursuivre(text, text) IS
  'Le parquet engage les poursuites sous une infraction CANONIQUE, qu''il choisit et qui peut differer de la categorie alleguee par le plaignant. La qualification est validee contre le catalogue : un identifiant invente, ou un nom de categorie generique, est refuse. Fait serveur date, consigne a la chronologie, transition revendiquee par compare-and-swap.';

CREATE OR REPLACE FUNCTION public.parquet_transmettre_juge(p_affaire_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_g jsonb; v_a jsonb; v_n integer;
BEGIN
  v_g := public.parquet_garde(p_affaire_id, ARRAY['poursuites']);
  IF coalesce((v_g ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_g; END IF;
  v_a := v_g -> 'affaire';

  UPDATE public.plaintes_en_cours
     SET data = (v_a || jsonb_build_object(
           'status', 'saisie',
           'saisine_par', v_g ->> 'procureur',
           'saisine_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))::text
   WHERE id = p_affaire_id AND (data::jsonb ->> 'status') = 'poursuites';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'statut_a_change'); END IF;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_g ->> 'pays', v_g ->> 'ville',
    'juge_saisi', v_g ->> 'procureur', 'procureur', NULL, v_a ->> 'qualification_parquet');
  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id, 'statut', 'saisie');
END;
$$;

CREATE OR REPLACE FUNCTION public.parquet_abandonner(p_affaire_id text, p_motif text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_g jsonb; v_a jsonb; v_avant text; v_apres text; v_motif text; v_n integer;
BEGIN
  v_g := public.parquet_garde(p_affaire_id, ARRAY['poursuites', 'saisie']);
  IF coalesce((v_g ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_g; END IF;
  v_a := v_g -> 'affaire';
  v_avant := v_a ->> 'status';
  v_motif := nullif(btrim(coalesce(p_motif, '')), '');

  -- Avant saisine : la procedure s'arrete. Apres saisine : le juge doit decider.
  v_apres := CASE WHEN v_avant = 'saisie' THEN 'abandon_demande' ELSE 'abandonnee' END;

  UPDATE public.plaintes_en_cours
     SET data = (v_a || jsonb_build_object(
           'status', v_apres,
           'abandon_par', v_g ->> 'procureur',
           'abandon_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
           'abandon_motif_declare', v_motif,
           'abandon_apres_saisine', (v_avant = 'saisie')))::text
   WHERE id = p_affaire_id AND (data::jsonb ->> 'status') = v_avant;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'statut_a_change'); END IF;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_g ->> 'pays', v_g ->> 'ville',
    'abandon_poursuites', v_g ->> 'procureur', 'procureur', NULL, NULL,
    jsonb_build_object('apres_saisine', (v_avant = 'saisie'))
      || CASE WHEN v_motif IS NULL THEN '{}'::jsonb
              ELSE jsonb_build_object('motif_declare', v_motif) END);
  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id, 'statut', v_apres,
                            'apres_saisine', (v_avant = 'saisie'));
END;
$$;
COMMENT ON FUNCTION public.parquet_abandonner(text, text) IS
  'Le parquet abandonne les poursuites. AVANT la saisine du juge, la procedure s''arrete (statut abandonnee). APRES, l''abandon n''y met pas fin : il ouvre une question (statut abandon_demande) que le juge tranchera par juge_suite_apres_abandon. Les deux actes restent DISTINCTS dans la chronologie, et le dossier n''est jamais supprime. Transition revendiquee par compare-and-swap.';

CREATE OR REPLACE FUNCTION public.juge_suite_apres_abandon(p_affaire_id text, p_decision text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_j record; v_brut text; v_a jsonb; v_ville text; v_pays text;
        v_statut text; v_type text; v_n integer;
BEGIN
  IF p_decision NOT IN ('arret', 'poursuivre') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'decision_invalide', 'decision', p_decision);
  END IF;

  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id FOR UPDATE;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente');
  END IF;
  v_a := v_brut::jsonb;

  SELECT * INTO v_j FROM public.juge_de_la_ville(v_ville);
  IF v_j.nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_juge_de_cette_ville', 'ville', v_ville);
  END IF;
  IF coalesce(v_a ->> 'status', '') <> 'abandon_demande' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'statut_incompatible',
                              'statut', v_a ->> 'status');
  END IF;

  v_statut := CASE WHEN p_decision = 'arret' THEN 'arret' ELSE 'saisie' END;
  v_type := CASE WHEN p_decision = 'arret' THEN 'juge_arret_accepte'
                 ELSE 'juge_poursuite_maintenue' END;

  UPDATE public.plaintes_en_cours
     SET data = (v_a || jsonb_build_object(
           'status', v_statut,
           'suite_abandon_par', v_j.nom,
           'suite_abandon_decision', p_decision,
           'suite_abandon_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))::text
   WHERE id = p_affaire_id AND (data::jsonb ->> 'status') = 'abandon_demande';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'statut_a_change'); END IF;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville, v_type, v_j.nom, 'juge');
  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id,
                            'decision', p_decision, 'statut', v_statut);
END;
$$;
COMMENT ON FUNCTION public.juge_suite_apres_abandon(text, text) IS
  'Apres un abandon du parquet sur une affaire DEJA SAISIE, le juge accepte l''arret ou poursuit la procedure. Deux faits serveur distincts (juge_arret_accepte / juge_poursuite_maintenue), consignes a cote de l''abandon et jamais fusionnes avec lui. Reserve au juge de la ville de l''affaire, transition revendiquee par compare-and-swap.';

-- ============================================================================================
-- 3. PREUVES STRUCTURELLES
-- ============================================================================================
DO $preuves$
DECLARE v_n integer; v_txt text;
BEGIN
  -- P1 : LE DECLENCHEUR RECONNAIT LE PARQUET, et verifie son pays.
  SELECT pg_get_functiondef(p.oid) INTO v_txt FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace AND p.proname = 'plaintes_epingler_verdict';
  IF position('public.parquet_moi()' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- le declencheur ne reconnait pas le parquet'; END IF;
  IF position('v_proc.pays IS NOT DISTINCT FROM NEW.country' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- le declencheur ne verifie pas le pays du parquet'; END IF;

  -- P2 : LES TROIS AUTRES AUTORITES SONT INTACTES. Le correctif ajoute, il ne retire rien.
  IF position('est_appel_serveur()' IN v_txt) = 0
     OR position('rp.verdict_interne' IN v_txt) = 0
     OR position('public.affaire_autorite_de(NEW.city)' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- une autorite preexistante a disparu du declencheur'; END IF;

  -- P3 : LES SEPT CHAMPS DE VERDICT SONT TOUJOURS PROTEGES, et `status` en fait partie.
  IF position('ARRAY[''status'',''sentence'',''peine'',''jugement'',''juge''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- la liste des champs de verdict a change'; END IF;

  -- P4 : LES SIX PORTES A TRANSITION REVENDIQUENT LEUR STATUT. La condition est dans le WHERE
  --      de l'UPDATE, et le ROW_COUNT devient un refus nomme.
  SELECT count(*) INTO v_n FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace
     AND p.proname IN ('parquet_enqueter','parquet_non_lieu','parquet_poursuivre',
                       'parquet_transmettre_juge','parquet_abandonner','juge_suite_apres_abandon')
     AND position('(data::jsonb ->> ''status'')' IN pg_get_functiondef(p.oid)) > 0
     AND position('statut_a_change' IN pg_get_functiondef(p.oid)) > 0;
  IF v_n <> 6 THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- % porte(s) sur 6 revendiquent leur transition', v_n; END IF;

  -- P5 : ET ELLES PASSENT TOUJOURS PAR LEUR GARDE. Le compare-and-swap s'ajoute a la garde, il
  --      ne la remplace pas : sans elle, la presence physique ne serait plus verifiee.
  SELECT count(*) INTO v_n FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace
     AND p.proname IN ('parquet_enqueter','parquet_non_lieu','parquet_poursuivre',
                       'parquet_transmettre_juge','parquet_abandonner')
     AND position('public.parquet_garde(' IN pg_get_functiondef(p.oid)) > 0;
  IF v_n <> 5 THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- % acte(s) du parquet sur 5 passent par la garde', v_n; END IF;

  RAISE NOTICE 'LES 5 PREUVES SONT VERTES.';
END
$preuves$;
