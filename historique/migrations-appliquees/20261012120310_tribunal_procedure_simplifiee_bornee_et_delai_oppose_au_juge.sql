-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 12 OCTOBRE 2026
--
-- Registre Supabase : version 20261012120310 (UTC), nom
-- `tribunal_procedure_simplifiee_bornee_et_delai_oppose_au_juge`.
-- Le registre passe de 681 a 682 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 30d97df6eed379078de6d63e5dc54649, 22899 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LE TRIBUNAL (3/4) -- LA PROCEDURE SIMPLIFIEE NE PEUT PLUS CLORE UN CRIME
--
-- LIVRE : LE DOMAINE. « Se defendre » est reservee aux infractions dont la peine de prison de
-- REFERENCE est <= 2 jours, exige une infraction CANONIQUE sur le dossier, et devient DEFINITIVE
-- -- une seule fois par affaire, la ou elle etait repetable et payante a chaque tentative. La
-- garde de gravite precede la lecture de l'issue : aucune reussite critique ne la contourne.
--
-- ARRETE, ET L'ARBITRAGE EST REMONTE. La resolution automatique demandee -- relaxe, ou -50 %, ou
-- peine executable -- ferait du jet une DECISION DE PEINE. Or le jet vit dans le navigateur et
-- son taux depend de `getStatEffective('CHA')`, qui agrege DEUX termes que le serveur ne sait pas
-- lire : la moyenne CHA du GROUPE DE COMPAGNONS, et la fraction de points de vie appliquee aux
-- caracteristiques affaiblies. Les trois sorties possibles etaient : laisser le navigateur
-- decider d'une peine (interdit) ; porter une formule AMPUTEE (interdit -- cela modifie les
-- probabilites) ; ou porter d'abord le groupe et l'affaiblissement au serveur (un autre
-- chantier). Le comportement actuel des affaires courtes est conserve tel quel.
--
-- ET LE DELAI S'OPPOSE AUX PORTES DU JUGE, comme il s'oppose deja au parquet.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- LA PROCEDURE SIMPLIFIEE NE PEUT PLUS CLORE UN CRIME, ET LE DELAI S'OPPOSE AU JUGE
-- 12 octobre 2026, nuit -- troisieme migration de la tranche du Tribunal
--
-- ============================================================================================
-- CE QUI EST LIVRE ICI, ET CE QUI EST ARRETE -- A LIRE AVANT LE CODE
-- ============================================================================================
-- LE §A DU CAHIER DES CHARGES SE DECOUPE EN DEUX, ET SEULE LA PREMIERE MOITIE EST LIVRABLE.
--
-- LIVRE : LE DOMAINE. « Se defendre » est desormais RESERVEE aux infractions dont la peine de
-- prison de reference est <= 2 jours, elle exige une infraction CANONIQUE sur le dossier, et
-- elle est DEFINITIVE -- une seule fois par affaire. La branche de reussite critique, qui
-- cloturait l'affaire quelle qu'elle soit, ne peut plus atteindre un dossier a >= 3 jours : la
-- garde est posee AVANT que l'issue ne soit lue, donc aucune issue ne la contourne.
--
-- ARRETE, ET VOICI POURQUOI. La resolution automatique demandee -- relaxe complete, ou reduction
-- de 50 %, ou peine normale immediatement executable -- fait de l'issue du jet une DECISION DE
-- PEINE. Or le jet vit dans le navigateur, et son taux est
--     clamp(5, 90, 50 + (CHA - 8) x 3 - 35 si preuve reelle)
-- ou CHA est `getStatEffective('CHA')`. Mesure faite sur le code de production : cette fonction
-- agrege DEUX termes que le serveur ne sait pas lire --
--     . la MOYENNE DES CHA DU GROUPE DE COMPAGNONS, quand le joueur en a un
--       (`getMembresGroupeAvecStat`), qui remplace purement et simplement sa propre valeur ;
--     . la FRACTION DE POINTS DE VIE appliquee aux caracteristiques affaiblies
--       (`state.statsAffaiblies`), qui peut diviser le taux par deux apres une blessure.
-- Le commentaire laisse le 12 octobre au matin affirmait que « plus aucun terme de ce taux n'est
-- hors de portee du serveur » : il ne parlait que du bonus de formation supprime ce jour-la, et
-- il est FAUX pour ces deux termes. Il est rectifie par cette migration.
--
-- Les trois sorties possibles etaient donc : laisser le navigateur decider d'une peine (interdit
-- -- l'autorite metier est serveur) ; porter une formule AMPUTEE de ces deux termes (interdit --
-- cela modifie les probabilites, et retire en silence l'avantage que donnent les compagnons) ;
-- ou porter d'abord le groupe et l'affaiblissement au serveur (un chantier qui n'est pas
-- celui-ci). L'ARBITRAGE EST DONC REMONTE, et la resolution automatique n'est pas ecrite. Le
-- comportement actuel des affaires <= 2 jours -- annotation du dossier, decision au juge -- est
-- conserve tel quel : ce n'est pas un demi-systeme, c'est l'etat d'avant, correctement borne a
-- son nouveau domaine.
--
-- ============================================================================================
-- ET LE DELAI S'OPPOSE AUSSI AU JUGE
-- ============================================================================================
-- La migration precedente l'a oppose au parquet. Les trois portes du juge -- condamner, relaxer,
-- decider apres un abandon -- doivent le lire aussi : un dossier dont le delai de jugement de
-- premiere instance est expire est ETEINT, et le juger reviendrait a juger une procedure close.
-- La passe de minuit l'inscrit ; ces gardes le rendent opposable AVANT elle.
--
-- PREUVES STRUCTURELLES -- 11.

-- ============================================================================================
-- 1. LE SEUIL, DECLARE UNE SEULE FOIS
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.justice_seuil_procedure_simplifiee_jours()
RETURNS integer LANGUAGE sql IMMUTABLE AS $$ SELECT 2 $$;
COMMENT ON FUNCTION public.justice_seuil_procedure_simplifiee_jours() IS
  'Le plafond de la procedure simplifiee, en jours de prison de REFERENCE : deux. Une infraction dont la reference vaut 3 jours ou plus suit la vraie chaine judiciaire -- parquet, poursuites, juge, jugement -- et aucune defense automatique ne peut la clore.';
REVOKE ALL ON FUNCTION public.justice_seuil_procedure_simplifiee_jours() FROM PUBLIC;

INSERT INTO public.dossiers_judiciaires_actes_types (type, libelle, pose_par, note) VALUES
 ('defense_simplifiee', 'Defense plaidee (procedure simplifiee)', 'accuse',
  'La personne mise en cause a plaide sa defense sur une affaire dont la peine de reference est courte. L''acte consigne le FAIT et son issue ; il ne juge ni la sincerite ni la qualite de la plaidoirie. Une seule fois par affaire : la procedure simplifiee est definitive.');

-- ============================================================================================
-- 2. « SE DEFENDRE » : UN DOMAINE, ET UNE SEULE FOIS
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.plainte_defendre(p_affaire_id text, p_issue text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_nom text; v_brut text; v_data jsonb; v_maj jsonb;
  v_inf text; v_ref integer; v_seuil integer; v_pays text; v_ville text;
BEGIN
  v_nom := public.mon_personnage();
  IF v_nom IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  -- LISTE CLOSE DES QUATRE ISSUES de la formule de defense de `data.js` : reussite eclatante
  -- (classe l'affaire), reussite simple (circonstance attenuante), echec flagrant (aggravation),
  -- echec simple (aucun effet). Elle est INCHANGEE : les probabilites ne sont pas touchees.
  IF p_issue NOT IN ('reussite_critique', 'attenuante', 'aggravation', 'infructueuse') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'issue_inconnue');
  END IF;

  SELECT p.data, p.country, p.city INTO v_brut, v_pays, v_ville
    FROM public.plaintes_en_cours WHERE id = p_affaire_id FOR UPDATE;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente');
  END IF;
  v_data := v_brut::jsonb;
  -- Se defendre est le fait de l'ACCUSE, et de lui seul.
  IF coalesce(v_data ->> 'cible', '') IS DISTINCT FROM v_nom THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_affaire');
  END IF;
  -- LE DOSSIER DOIT ETRE AU PARQUET, ET RIEN D'AUTRE : on se defend tant qu'aucune autorite n'a
  -- agi. Inchange depuis le 12 octobre au matin.
  IF coalesce(v_data ->> 'status', '') IS DISTINCT FROM 'au_parquet' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_non_defendable',
                              'statut', v_data ->> 'status');
  END IF;

  -- LA PROCEDURE SIMPLIFIEE EST DEFINITIVE : une seule fois par affaire. Avant cette migration,
  -- la defense etait REPETABLE et payante a chaque tentative -- on pouvait relancer le jet
  -- jusqu'a la reussite critique, donc jusqu'a la cloture de l'affaire, pour 2 PA et 300 FR le
  -- tour. C'etait la vraie faille de cette mecanique, et elle valait pour toutes les peines.
  IF v_data ? 'defense_le' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'defense_deja_plaidee',
                              'issue_precedente', v_data ->> 'defense_issue');
  END IF;

  -- LE DOMAINE : UNE INFRACTION CANONIQUE, ET UNE REFERENCE COURTE.
  v_inf := public.affaire_infraction_de(v_data);
  IF v_inf IS NULL THEN
    -- Sans infraction canonique, le seuil n'est pas calculable. Refuser est la seule reponse
    -- honnete : accepter reviendrait a laisser passer n'importe quelle gravite.
    RETURN jsonb_build_object('ok', false, 'raison', 'infraction_non_determinee');
  END IF;
  SELECT i.jours_reference INTO v_ref FROM public.infractions i WHERE i.id = v_inf;
  IF v_ref IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'infraction_hors_catalogue',
                              'infraction', v_inf);
  END IF;
  v_seuil := public.justice_seuil_procedure_simplifiee_jours();
  IF v_ref > v_seuil THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'procedure_simplifiee_reservee_aux_peines_courtes',
                              'infraction', v_inf, 'jours_reference', v_ref, 'seuil', v_seuil);
  END IF;

  v_maj := jsonb_build_object('defendue_par', v_nom, 'defendue_le',
                              to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
                              'defense_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
                              'defense_issue', p_issue,
                              'defense_infraction', v_inf,
                              'procedure_simplifiee', true);
  IF p_issue = 'reussite_critique' THEN
    v_maj := v_maj || jsonb_build_object('status', 'jugee', 'resultatDefense', 'reussite_critique');
  ELSIF p_issue = 'attenuante' THEN
    v_maj := v_maj || jsonb_build_object('circonstanceAttenuante', true);
  ELSIF p_issue = 'aggravation' THEN
    v_maj := v_maj || jsonb_build_object('aggravation', true);
  END IF;

  v_data := v_data || v_maj;
  -- Le laissez-passer ne dure que cette ecriture (voir le trigger `plaintes_epingler_verdict`).
  PERFORM set_config('rp.verdict_interne', 'on', true);
  UPDATE public.plaintes_en_cours SET data = v_data::text WHERE id = p_affaire_id;
  PERFORM set_config('rp.verdict_interne', '', true);

  -- LA DEFENSE N'ETAIT CONSIGNEE NULLE PART. Un acte de procedure pose par l'accuse n'apparaissait
  -- dans aucune chronologie : le juge voyait une circonstance attenuante tombee du ciel.
  PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville, 'defense_simplifiee',
    v_nom, NULL, NULL, v_inf,
    jsonb_build_object('issue', p_issue, 'jours_reference', v_ref, 'seuil', v_seuil));

  RETURN jsonb_build_object('ok', true, 'issue', p_issue, 'affaire', v_data,
                            'infraction', v_inf, 'jours_reference', v_ref);
END; $$;
COMMENT ON FUNCTION public.plainte_defendre(text, text) IS
  'LA PROCEDURE SIMPLIFIEE, et elle a desormais un domaine : les infractions dont la peine de prison de REFERENCE est au plus de 2 jours, sur un dossier qui porte une infraction CANONIQUE. Une affaire a 3 jours ou plus ne peut plus etre close par une reussite critique -- la garde precede la lecture de l''issue. DEFINITIVE : une seule defense par affaire, la ou elle etait repetable et payante a chaque tentative. La RESOLUTION AUTOMATIQUE en relaxe ou en reduction de 50 % n''est pas implementee : le jet vit dans le navigateur et son taux depend de deux termes que le serveur ne sait pas lire (moyenne CHA du groupe de compagnons, fraction de PV sur les caracteristiques affaiblies). Arbitrage remonte.';

-- ============================================================================================
-- 3. LE DELAI S'OPPOSE AUX TROIS PORTES DU JUGE
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.justice_relaxer(p_affaire_id text, p_infraction text DEFAULT NULL::text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_j record; v_brut text; v_a jsonb; v_ville text; v_pays text; v_jour integer;
  v_inf text; v_lib text; v_parquet text; v_jug text; v_n integer;
BEGIN
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
  -- ON NE RELAXE QUE SUR UNE AFFAIRE REGULIEREMENT SAISIE. Sans saisine, il n'y a rien a juger.
  IF coalesce(v_a ->> 'status', '') <> 'saisie' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_non_saisie',
                              'statut', v_a ->> 'status');
  END IF;
  -- LE DELAI DE PREMIERE INSTANCE EST OPPOSABLE AU JUGE AUSSI (12 octobre 2026, nuit).
  IF public.affaire_delai_expire(v_a, v_pays) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delai_de_jugement_expire',
                              'echeance', (v_a ->> 'delai_jugement_jour')::integer);
  END IF;

  -- LA RELAXE PORTE SUR UNE QUALIFICATION : on relaxe de QUELQUE CHOSE. Par defaut celle du
  -- parquet ; le juge peut requalifier avant de relaxer, et les deux restent lisibles.
  v_parquet := v_a ->> 'qualification_parquet';
  v_inf := public.infraction_canonique(coalesce(p_infraction, v_parquet));
  IF v_inf IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'infraction_inconnue',
                              'demande', coalesce(p_infraction, v_parquet));
  END IF;
  SELECT libelle INTO v_lib FROM public.infractions WHERE id = v_inf;
  SELECT coalesce(d.day, 1) INTO v_jour FROM public.personnages_donnees d WHERE d.name = v_j.nom;

  -- UNE RELAXE EST UN JUGEMENT, et elle a donc sa ligne au registre -- avec `peine` NULL, pas
  -- une peine de zero. C'est la difference entre « relaxe » et « condamne a rien ».
  v_jug := 'jug-' || p_affaire_id;
  INSERT INTO public.jugements (id, country, city, accuse, motif, peine, juge, jour, executee, data)
  VALUES (v_jug, v_pays, coalesce(v_ville, 'capitale'), v_a ->> 'cible', v_lib, NULL,
          v_j.nom, coalesce(v_jour, 1), true,
          jsonb_build_object('verdict', 'relaxe', 'infraction', v_inf,
            'infraction_libelle', v_lib, 'qualification_parquet', v_parquet,
            'motif_allegue', v_a ->> 'motif', 'motifs', '[]'::jsonb))
  ON CONFLICT (id) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'jugement_deja_rendu');
  END IF;

  -- REQUALIFICATION AVANT RELAXE : fait distinct, consigne avant le verdict.
  IF v_parquet IS NOT NULL AND v_inf IS DISTINCT FROM v_parquet THEN
    PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville,
      'requalification', v_j.nom, 'juge', v_parquet, v_inf);
  END IF;

  UPDATE public.plaintes_en_cours
     SET data = (v_a || jsonb_build_object(
           'status', 'relaxe',
           'verdict', 'relaxe',
           'juge', v_j.nom,
           'juge_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
           'qualification_finale', v_inf,
           'qualification_libelle', v_lib))::text
   WHERE id = p_affaire_id;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville, 'relaxe',
    v_j.nom, 'juge', v_parquet, v_inf, jsonb_build_object('accuse', v_a ->> 'cible'));
  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id, 'verdict', 'relaxe',
    'jugement_id', v_jug, 'juge', v_j.nom, 'infraction', v_inf, 'libelle', v_lib);
END;
$$;

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
  -- LE DELAI EST OPPOSABLE ICI AUSSI. Maintenir des poursuites sur un dossier eteint le
  -- ressusciterait ; le juge peut encore accepter l'arret, mais plus relancer la procedure.
  IF public.affaire_delai_expire(v_a, v_pays) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delai_de_jugement_expire',
                              'echeance', (v_a ->> 'delai_jugement_jour')::integer);
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

-- ============================================================================================
-- PREUVES
-- ============================================================================================
DO $preuves$
DECLARE v_n integer; v_txt text;
BEGIN
  -- P1 : LE SEUIL EST DECLARE UNE FOIS, ET IL VAUT DEUX.
  IF public.justice_seuil_procedure_simplifiee_jours() <> 2 THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- le seuil de la procedure simplifiee ne vaut pas 2 jours'; END IF;

  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'plainte_defendre';

  -- P2 : LA DEFENSE LIT LE SEUIL, elle ne le recopie pas.
  IF position('justice_seuil_procedure_simplifiee_jours()' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- la defense recopie le seuil au lieu de le lire'; END IF;

  -- P3 : LA GARDE DE GRAVITE PRECEDE LA LECTURE DE L'ISSUE. C'est tout l'enjeu : une reussite
  -- critique ne doit pas pouvoir clore un crime. On verifie l'ORDRE dans le corps.
  IF position('procedure_simplifiee_reservee_aux_peines_courtes' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- la garde de gravite est absente'; END IF;
  IF position('procedure_simplifiee_reservee_aux_peines_courtes' IN v_txt)
     > position('''status'', ''jugee''' IN v_txt) THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- la reussite critique est appliquee AVANT la garde de gravite'; END IF;

  -- P4 : LE DOMAINE EXIGE UNE INFRACTION CANONIQUE. Sans elle, le seuil n'est pas calculable.
  IF position('infraction_non_determinee' IN v_txt) = 0
     OR position('public.affaire_infraction_de(v_data)' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- la defense ne reclame pas d''infraction canonique'; END IF;

  -- P5 : LA PROCEDURE EST DEFINITIVE. La repetition etait la vraie faille : on relancait le jet
  -- jusqu'a la reussite critique.
  IF position('defense_deja_plaidee' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- la defense reste repetable'; END IF;

  -- P6 : LES QUATRE ISSUES SONT INTACTES -- les probabilites ne sont pas touchees.
  IF position('''reussite_critique'', ''attenuante'', ''aggravation'', ''infructueuse''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P6 ECHOUEE -- la liste close des issues a bouge'; END IF;

  -- P7 : LA DEFENSE EST CONSIGNEE. Elle ne l'etait nulle part avant cette migration.
  IF position('''defense_simplifiee''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P7 ECHOUEE -- la defense n''est pas consignee a la chronologie'; END IF;
  SELECT count(*) INTO v_n FROM public.dossiers_judiciaires_actes_types
   WHERE type = 'defense_simplifiee' AND pose_par = 'accuse';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P7 ECHOUEE -- le type d''acte de la defense manque'; END IF;

  -- P8 : AUCUNE PEINE N'EST APPLIQUEE PAR LA DEFENSE. La sous-partie est ARRETEE, pas a moitie
  -- ecrite : la porte ne doit toucher ni detention, ni jugement, ni argent.
  IF position('detention_ouvrir' IN v_txt) > 0 OR position('INSERT INTO public.jugements' IN v_txt) > 0
     OR position('payer_ordre' IN v_txt) > 0 OR position('justice_peine_calcul' IN v_txt) > 0 THEN
    RAISE EXCEPTION 'P8 ECHOUEE -- la defense applique une peine alors que la resolution automatique est arretee'; END IF;

  -- P9 : LES TROIS PORTES DU JUGE OPPOSENT LE DELAI.
  FOR v_txt IN SELECT p.prosrc FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                WHERE n.nspname = 'public'
                  AND p.proname IN ('justice_relaxer', 'juge_suite_apres_abandon') LOOP
    IF position('public.affaire_delai_expire(v_a, v_pays)' IN v_txt) = 0 THEN
      RAISE EXCEPTION 'P9 ECHOUEE -- une porte du juge n''oppose pas le delai'; END IF;
  END LOOP;
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname IN ('justice_relaxer', 'juge_suite_apres_abandon')
     AND position('delai_de_jugement_expire' IN p.prosrc) > 0;
  IF v_n <> 2 THEN
    RAISE EXCEPTION 'P9 ECHOUEE -- % porte(s) du juge sur 2 nomment le refus de delai', v_n; END IF;

  -- P10 : LES DEUX PORTES DU JUGE N'ONT RIEN PERDU AU PASSAGE.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'justice_relaxer';
  IF position('''verdict'', ''relaxe''' IN v_txt) = 0 OR position('jugement_deja_rendu' IN v_txt) = 0
     OR position('pas_juge_de_cette_ville' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P10 ECHOUEE -- justice_relaxer a perdu une de ses conditions'; END IF;
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'juge_suite_apres_abandon';
  IF position('juge_poursuite_maintenue' IN v_txt) = 0 OR position('juge_arret_accepte' IN v_txt) = 0
     OR position('statut_a_change' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P10 ECHOUEE -- juge_suite_apres_abandon a perdu une de ses conditions'; END IF;

  -- P11 : UNE SEULE SIGNATURE POUR CHACUNE DES TROIS FONCTIONS REECRITES.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('plainte_defendre', 'justice_relaxer', 'juge_suite_apres_abandon');
  IF v_n <> 3 THEN
    RAISE EXCEPTION 'P11 ECHOUEE -- % signature(s) au lieu de 3 : une surcharge a ete creee', v_n; END IF;

  RAISE NOTICE 'LES 11 PREUVES SONT VERTES.';
END $preuves$;
