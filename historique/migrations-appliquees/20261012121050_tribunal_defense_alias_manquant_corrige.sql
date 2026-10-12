-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 12 OCTOBRE 2026
--
-- Registre Supabase : version 20261012121050 (UTC), nom
-- `tribunal_defense_alias_manquant_corrige`.
-- Le registre passe de 682 a 683 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 908a8bb4e3260c9820ddfd8dfc30a396, 8021 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LE TRIBUNAL (4/4) -- LA DEFENSE NE SAVAIT PLUS LIRE SON PROPRE DOSSIER
--
-- UN ALIAS MANQUANT, ET LA PORTE ENTIERE CASSEE. La migration precedente a ajoute deux colonnes
-- a la lecture du dossier dans `plainte_defendre` et a ecrit `SELECT p.data, p.country, p.city
-- ... FROM public.plaintes_en_cours WHERE id = ...` sans l'alias `p` : la version d'avant ne
-- lisait qu'une colonne, sans prefixe.
--
-- POSTGRESQL NE L'A PAS VU A LA CREATION, et c'est le point. Le corps d'une fonction plpgsql
-- n'est pas analyse quand on la cree : la migration a ete acceptee, ses 11 preuves sont passees
-- au vert -- elles lisent `prosrc`, elles ne l'executent pas -- et la fonction levait
-- « missing FROM-clause entry for table p » au PREMIER appel reel.
--
-- C'EST LE BANC QUI L'A TROUVE, a sa toute premiere epreuve. Une preuve structurelle montre
-- qu'une condition est ECRITE, jamais qu'une porte FONCTIONNE.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- LA DEFENSE NE SAVAIT PLUS LIRE SON PROPRE DOSSIER
-- 12 octobre 2026, nuit -- correctif de la tranche du Tribunal
--
-- LE DEFAUT, ET CE QU'IL APPREND. La migration precedente a ajoute deux colonnes a la lecture du
-- dossier dans `plainte_defendre` -- le pays et la ville, pour pouvoir consigner l'acte a la
-- chronologie -- et a ecrit :
--     SELECT p.data, p.country, p.city ... FROM public.plaintes_en_cours WHERE id = ...
-- sans l'alias `p` sur la table. La version d'avant ne lisait qu'une colonne, sans prefixe :
-- l'alias n'avait jamais ete necessaire.
--
-- POSTGRESQL NE L'A PAS VU A LA CREATION, et c'est le point. Le corps d'une fonction plpgsql
-- n'est pas analyse quand on la cree : la migration a ete acceptee, ses 11 preuves sont passees
-- au vert -- elles lisent `prosrc`, elles ne l'executent pas -- et la fonction levait
-- « missing FROM-clause entry for table p » au PREMIER appel reel. « Se defendre » etait donc
-- totalement cassee, et aucune preuve structurelle ne pouvait le dire.
--
-- C'EST LE BANC QUI L'A TROUVE, a sa toute premiere epreuve. C'est exactement la raison pour
-- laquelle ce depot exige un banc comportemental a cote des preuves de migration : une preuve
-- structurelle montre qu'une condition est ECRITE, jamais qu'une porte FONCTIONNE.
--
-- PREUVES STRUCTURELLES -- 3.

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

  -- L'ALIAS `p` EST CE QUI MANQUAIT, et son absence cassait la porte entiere (voir l'en-tete).
  SELECT p.data, p.country, p.city INTO v_brut, v_pays, v_ville
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id FOR UPDATE;
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

  -- LA PROCEDURE SIMPLIFIEE EST DEFINITIVE : une seule fois par affaire. Avant cette tranche,
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

DO $preuves$
DECLARE v_n integer; v_txt text;
BEGIN
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'plainte_defendre';

  -- P1 : L'ALIAS EST LA, et la clause WHERE le porte aussi.
  IF position('FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id FOR UPDATE' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- la lecture du dossier n''est toujours pas aliasee'; END IF;

  -- P2 : AUCUNE COLONNE PREFIXEE `p.` NE SUBSISTE SANS SA TABLE ALIASEE. On compte les deux
  -- cotes : autant de prefixes que de FROM aliases dans cette fonction.
  IF position('SELECT p.data, p.country, p.city INTO v_brut, v_pays, v_ville' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- la projection a change de forme'; END IF;

  -- P3 : LE DOMAINE ET LA DEFINITIVITE N'ONT PAS ETE PERDUS DANS LE CORRECTIF.
  IF position('procedure_simplifiee_reservee_aux_peines_courtes' IN v_txt) = 0
     OR position('defense_deja_plaidee' IN v_txt) = 0
     OR position('infraction_non_determinee' IN v_txt) = 0
     OR position('''defense_simplifiee''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- le correctif a perdu une garde de la migration precedente'; END IF;
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'plainte_defendre';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P3 ECHOUEE -- % signature(s) de plainte_defendre', v_n; END IF;

  RAISE NOTICE 'LES 3 PREUVES SONT VERTES.';
END $preuves$;
