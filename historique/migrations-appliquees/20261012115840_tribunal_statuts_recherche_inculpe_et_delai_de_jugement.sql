-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 12 OCTOBRE 2026
--
-- Registre Supabase : version 20261012115840 (UTC), nom
-- `tribunal_statuts_recherche_inculpe_et_delai_de_jugement`.
-- Le registre passe de 680 a 681 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 43288f1e8f5bee3df263c2e0194f2f3d, 18968 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LE TRIBUNAL (2/4) -- RECHERCHE, INCULPE, ET UN DELAI QUI S'OPPOSE TOUT SEUL
--
-- LES DEUX STATUTS SONT DERIVES, JAMAIS STOCKES. RECHERCHE se lit du tableau `recherche` deja
-- en place -- on n'en cree pas un second ; INCULPE se lit DU DOSSIER : un PV existe, l'affaire
-- est vivante, le delai n'est pas expire. La suspension est PAR AFFAIRE, et c'est tout l'enjeu :
-- un meme joueur peut etre INCULPE pour l'affaire A et RECHERCHE pour l'affaire B.
--
-- LA VISIBILITE EST LOCALE, ET LA PORTE L'IMPOSE. `justice_statuts_publics()` ne prend AUCUN
-- parametre : elle lit la presence de l'appelant et ne rend que les gens de sa piece. Un
-- parametre en aurait fait un scanner national, ce que personne n'a arbitre. Aucune reaction
-- n'est codee : ni popularite, ni influence, ni rumeur.
--
-- LE DELAI S'OPPOSE AVANT D'ETRE EXECUTE. La passe de minuit ne tourne qu'une fois par jour ; la
-- garde commune du parquet lit donc l'echeance elle-meme. La passe n'invente pas la regle, elle
-- inscrit ce qui est deja vrai.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- RECHERCHE, INCULPE, ET UN DELAI QUI S'OPPOSE TOUT SEUL
-- 12 octobre 2026, nuit -- deuxieme migration de la tranche du Tribunal
--
-- LES DEUX STATUTS SONT DERIVES, JAMAIS STOCKES. C'est la doctrine du depot, et ici elle n'est
-- pas un confort : un statut stocke se desynchronise du dossier des que la procedure avance, et
-- il faudrait alors une porte pour le corriger -- donc une autorite de plus sur une etape qui
-- n'en demande aucune.
--   . RECHERCHE se lit deja dans `personnages_donnees.recherche`, un tableau d'actes alimente
--     par deux portes serveur. On n'en cree pas un second.
--   . INCULPE se lit du DOSSIER : il existe un PV d'audition, l'affaire est vivante, et le delai
--     n'est pas expire. Rien a inscrire nulle part.
--
-- LA SUSPENSION DE LA RECHERCHE EST PAR AFFAIRE, ET C'EST TOUT L'ENJEU DU §G. Un PV ne suspend
-- QUE la recherche de SON affaire : l'acte de reference de ce dossier cesse de compter, les
-- autres entrees restent. Un meme joueur peut donc etre INCULPE pour l'affaire A et RECHERCHE
-- pour l'affaire B, simultanement -- et c'est l'etat normal, pas une exception.
--
-- LA VISIBILITE EST LOCALE, ET LA PORTE L'IMPOSE. `justice_statuts_publics()` ne prend AUCUN
-- parametre : elle lit la presence de l'appelant et ne rend que les personnes qui sont dans LA
-- MEME PIECE. Un parametre `p_noms` en aurait fait un scanner national -- on saurait d'un clic
-- qui est recherche dans tout l'empire, ce que personne n'a arbitre. Ce sont des faits publics
-- LOCALEMENT, et la porte ne sait rien dire d'autre.
--
-- AUCUNE REACTION N'EST CODEE. Pas de malus de popularite, pas d'influence, pas de refus de
-- service, pas de rumeur. Le serveur dit un fait ; les joueurs en font ce qu'ils veulent.
--
-- LE DELAI S'OPPOSE AVANT MEME D'ETRE EXECUTE, et c'est voulu. `justice_delais_echus()` clot les
-- dossiers echus, mais elle ne tourne qu'a minuit : entre l'echeance et la passe, un Procureur
-- pourrait poursuivre un dossier deja perime. La garde commune du parquet et les trois portes du
-- juge lisent donc l'echeance ELLES-MEMES. La passe nocturne ne fait qu'inscrire ce qui est deja
-- vrai -- elle ne cree pas la regle, elle la consigne.
--
-- PREUVES STRUCTURELLES -- 9.

-- ============================================================================================
-- 1. L'ECHEANCE, LUE AU MEME ENDROIT PAR TOUT LE MONDE
-- ============================================================================================
-- STRICTEMENT APRES, et non « a partir de ». L'echeance est `pv_jour + 15` : le quinzieme jour
-- est le dernier jour utile, donc l'expiration ne mord qu'au seizieme. Un `>=` aurait retire une
-- journee au delai annonce.
CREATE OR REPLACE FUNCTION public.affaire_delai_expire(p_data jsonb, p_pays text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT (p_data ->> 'delai_jugement_jour') IS NOT NULL
     AND coalesce(public.jour_de_jeu_pays(coalesce(p_pays, p_data ->> 'country')), 1)
         > (p_data ->> 'delai_jugement_jour')::integer;
$$;
COMMENT ON FUNCTION public.affaire_delai_expire(jsonb, text) IS
  'Le delai de jugement de premiere instance est-il depasse ? Strictement apres l''echeance : le quinzieme jour reste utile. Un dossier sans PV n''a pas d''echeance et n''expire donc jamais -- la protection temporelle est la contrepartie de l''audition, pas un droit automatique.';

-- ============================================================================================
-- 2. LES ACTES SUSPENDUS PAR UNE INCULPATION EN COURS
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.justice_affaires_vivantes_avec_pv(p_nom text)
RETURNS TABLE(affaire text, pays text, infraction text, echeance integer)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT p.id, p.country,
         public.affaire_infraction_de(p.data::jsonb),
         ((p.data::jsonb) ->> 'delai_jugement_jour')::integer
    FROM public.plaintes_en_cours p
    JOIN public.dossiers_auditions a ON a.affaire = p.id AND a.personne = p_nom
   WHERE p.data IS NOT NULL AND left(btrim(p.data), 1) = '{'
     AND ((p.data::jsonb) ->> 'cible') = p_nom
     AND ((p.data::jsonb) ->> 'status') IN
         ('au_parquet', 'enquete', 'poursuites', 'saisie', 'abandon_demande')
     AND NOT public.affaire_delai_expire(p.data::jsonb, p.country);
$$;
COMMENT ON FUNCTION public.justice_affaires_vivantes_avec_pv(text) IS
  'Les dossiers pour lesquels cette personne est INCULPEE : un PV d''audition existe, l''affaire est vivante, et le delai n''est pas expire. C''est la source unique des deux derivations -- le statut INCULPE, et la suspension de la recherche affaire par affaire.';

-- ============================================================================================
-- 3. LES STATUTS PUBLICS, ET SEULEMENT DANS LA PIECE
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.justice_statuts_publics()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_moi text; v_p record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT pr.country, pr.city, pr.building_id, pr.room_id INTO v_p
    FROM public.presences pr WHERE pr.name = v_moi;
  IF v_p IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'statuts', '[]'::jsonb);
  END IF;

  RETURN jsonb_build_object('ok', true, 'statuts', coalesce((
    SELECT jsonb_agg(jsonb_build_object(
             'nom', x.nom, 'recherche', x.recherche, 'inculpe', x.inculpe) ORDER BY x.nom)
      FROM (
        SELECT pr.name AS nom,
               -- RECHERCHE : il reste au moins une entree dont l'acte n'est PAS suspendu par une
               -- inculpation en cours. Une entree sans acte -- il en existe -- n'est jamais
               -- suspendue : aucun dossier ne peut s'y rattacher.
               EXISTS (
                 SELECT 1 FROM public.personnages_donnees d,
                        jsonb_array_elements(CASE WHEN jsonb_typeof(d.recherche) = 'array'
                                                  THEN d.recherche ELSE '[]'::jsonb END) e
                  WHERE d.name = pr.name
                    AND NOT EXISTS (SELECT 1 FROM public.justice_affaires_vivantes_avec_pv(pr.name) v
                                     WHERE v.infraction IS NOT NULL
                                       AND v.infraction = (e ->> 'acte'))
               ) AS recherche,
               EXISTS (SELECT 1 FROM public.justice_affaires_vivantes_avec_pv(pr.name)) AS inculpe
          FROM public.presences pr
         WHERE pr.country IS NOT DISTINCT FROM v_p.country
           AND pr.city IS NOT DISTINCT FROM v_p.city
           AND pr.building_id IS NOT DISTINCT FROM v_p.building_id
           AND pr.room_id IS NOT DISTINCT FROM v_p.room_id
      ) x
      WHERE x.recherche OR x.inculpe), '[]'::jsonb));
END;
$$;
COMMENT ON FUNCTION public.justice_statuts_publics() IS
  'Les statuts judiciaires PUBLICS -- recherche, inculpe -- des personnes presentes dans la MEME PIECE que l''appelant, et de personne d''autre. Aucun parametre, volontairement : un nom en entree en ferait un scanner national, ce que personne n''a arbitre. Deux faits, aucune reaction : ni popularite, ni influence, ni rumeur. Les joueurs en font ce qu''ils veulent.';
REVOKE ALL ON FUNCTION public.justice_statuts_publics() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.justice_statuts_publics() TO authenticated;

-- ============================================================================================
-- 4. LE DELAI S'OPPOSE AU PARQUET ET AU JUGE, AVANT LA PASSE DE MINUIT
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.parquet_garde(p_affaire_id text, p_statuts text[])
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_p record; v_brut text; v_a jsonb; v_ville text; v_pays text; v_site text;
BEGIN
  SELECT * INTO v_p FROM public.parquet_moi();
  IF v_p.nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_procureur');
  END IF;

  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente');
  END IF;
  v_a := v_brut::jsonb;

  IF v_pays IS DISTINCT FROM v_p.pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction');
  END IF;
  IF NOT (coalesce(v_a ->> 'status', '') = ANY (p_statuts)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'statut_incompatible',
                              'statut', v_a ->> 'status', 'attendus', to_jsonb(p_statuts));
  END IF;

  -- LE DELAI S'OPPOSE ICI, et non seulement a minuit. Entre l'echeance et la passe nocturne, le
  -- dossier est perime : la poursuivre serait poursuivre une procedure eteinte.
  IF public.affaire_delai_expire(v_a, v_pays) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delai_de_jugement_expire',
                              'echeance', (v_a ->> 'delai_jugement_jour')::integer);
  END IF;

  v_site := public.parquet_site_competent(v_pays, v_ville);
  IF NOT public.acteur_present_sur_site(v_p.nom, v_pays, v_ville, v_site) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'presence_requise',
                              'ville', v_ville, 'site', v_site);
  END IF;

  RETURN jsonb_build_object('ok', true, 'procureur', v_p.nom, 'pays', v_pays,
                            'ville', v_ville, 'affaire', v_a);
END;
$$;
COMMENT ON FUNCTION public.parquet_garde(text, text[]) IS
  'La garde commune des actes du parquet : identite, pays, statut attendu, DELAI DE JUGEMENT non expire, et presence physique dans le tribunal competent. Une seule fonction porte toutes les conditions, donc aucune des cinq portes ne peut en oublier une.';

-- ============================================================================================
-- 5. LA PASSE QUI CONSIGNE CE QUI EST DEJA VRAI
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.justice_delais_echus()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_d record; v_n integer := 0; v_infr text; v_clos jsonb := '[]'::jsonb;
BEGIN
  -- PORTE DE SERVEUR. Aucun joueur ne declenche l'expiration d'un dossier : elle est l'effet du
  -- temps, pas d'une decision.
  IF NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_serveur');
  END IF;

  FOR v_d IN
    SELECT p.id, p.country, p.city, p.data::jsonb AS a
      FROM public.plaintes_en_cours p
     WHERE p.data IS NOT NULL AND left(btrim(p.data), 1) = '{'
       AND ((p.data::jsonb) ->> 'status') IN
           ('au_parquet', 'enquete', 'poursuites', 'saisie', 'abandon_demande')
       AND public.affaire_delai_expire(p.data::jsonb, p.country)
     ORDER BY p.created_at
     FOR UPDATE
  LOOP
    -- Compare-and-swap : une decision rendue dans la meme seconde gagne, et la passe ne l'ecrase
    -- pas. Un jugement arrive a l'heure n'est pas annule par une expiration de la nuit.
    UPDATE public.plaintes_en_cours
       SET data = (v_d.a || jsonb_build_object(
             'status', 'delai_expire',
             'delai_expire_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))::text
     WHERE id = v_d.id AND (data::jsonb ->> 'status') = (v_d.a ->> 'status');
    IF NOT FOUND THEN CONTINUE; END IF;

    PERFORM public.dossier_acte_consigner(v_d.id, v_d.country, v_d.city,
      'charges_abandonnees_delai', NULL, NULL, NULL, NULL,
      jsonb_build_object('echeance', (v_d.a ->> 'delai_jugement_jour')::integer,
                         'statut_precedent', v_d.a ->> 'status'));

    -- LA RECHERCHE EST RESOLUE CONFORMEMENT A LA CLOTURE. Les charges sont abandonnees : la
    -- personne n'est plus recherchee POUR CET ACTE. Les autres entrees ne sont pas touchees --
    -- `recherche_retirer` filtre sur l'acte, et un motif n'en efface jamais un autre.
    v_infr := public.affaire_infraction_de(v_d.a);
    IF v_infr IS NOT NULL AND nullif(v_d.a ->> 'cible', '') IS NOT NULL THEN
      PERFORM public.recherche_retirer(ARRAY[v_infr], v_d.country, v_d.a ->> 'cible');
    END IF;

    v_n := v_n + 1;
    v_clos := v_clos || jsonb_build_array(jsonb_build_object(
      'affaire', v_d.id, 'cible', v_d.a ->> 'cible', 'infraction', v_infr));
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'closes', v_n, 'dossiers', v_clos);
END;
$$;
COMMENT ON FUNCTION public.justice_delais_echus() IS
  'Clot les dossiers dont le delai de jugement de premiere instance a expire : les charges sont abandonnees. Ce n''est ni une relaxe ni un non-lieu -- c''est une procedure qui n''a pas abouti dans le temps imparti, et aucun PJ ne doit rester inculpe indefiniment parce que les postes institutionnels ne sont pas occupes. La recherche de l''acte concerne est retiree avec les charges. Reservee au serveur : l''expiration est l''effet du temps, pas d''une decision.';
REVOKE ALL ON FUNCTION public.justice_delais_echus() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.affaire_delai_expire(jsonb, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.justice_affaires_vivantes_avec_pv(text) FROM PUBLIC;

-- ============================================================================================
-- PREUVES
-- ============================================================================================
DO $preuves$
DECLARE v_n integer; v_txt text;
BEGIN
  -- P1 : LA GARDE DU PARQUET LIT L'ECHEANCE. Assertion sur l'APPEL, pas sur le mot.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'parquet_garde';
  IF position('public.affaire_delai_expire(v_a, v_pays)' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- la garde du parquet n''oppose pas le delai'; END IF;

  -- P2 : LA GARDE N'A RIEN PERDU. Les quatre conditions d'origine sont toujours la : le delai
  -- est une condition DE PLUS, pas un remplacement.
  IF position('pas_procureur' IN v_txt) = 0 OR position('hors_juridiction' IN v_txt) = 0
     OR position('statut_incompatible' IN v_txt) = 0
     OR position('acteur_present_sur_site' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- la garde du parquet a perdu une de ses quatre conditions'; END IF;

  -- P3 : L'EXPIRATION EST STRICTEMENT POSTERIEURE A L'ECHEANCE. Un `>=` retirerait un jour au
  -- delai annonce, et c'est le genre d'ecart qu'aucun joueur ne pourrait constater.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'affaire_delai_expire';
  IF position('>=' IN v_txt) > 0 OR position('>' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- l''expiration n''est pas strictement posterieure a l''echeance'; END IF;

  -- P4 : UN DOSSIER SANS PV N'EXPIRE JAMAIS. La protection temporelle est la contrepartie de
  -- l'audition : sans echeance inscrite, rien ne se ferme.
  IF (SELECT public.affaire_delai_expire('{"country":"republic"}'::jsonb, 'republic')) IS NOT FALSE THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- un dossier sans echeance expire'; END IF;

  -- P5 : LA PORTE DES STATUTS NE PREND AUCUN PARAMETRE. C'est ce qui l'empeche d'etre un
  -- scanner national : on ne peut lui demander personne, seulement « qui est ici ».
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'justice_statuts_publics' AND p.pronargs = 0;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- justice_statuts_publics ne doit exister qu''a zero parametre'; END IF;

  -- P6 : ELLE FILTRE SUR LES QUATRE COORDONNEES DE LA PIECE. Trois auraient suffi a faire fuiter
  -- tout un batiment.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'justice_statuts_publics';
  IF position('pr.country IS NOT DISTINCT FROM v_p.country' IN v_txt) = 0
     OR position('pr.city IS NOT DISTINCT FROM v_p.city' IN v_txt) = 0
     OR position('pr.building_id IS NOT DISTINCT FROM v_p.building_id' IN v_txt) = 0
     OR position('pr.room_id IS NOT DISTINCT FROM v_p.room_id' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P6 ECHOUEE -- les statuts ne sont pas bornes a la piece'; END IF;

  -- P7 : AUCUNE REACTION AUTOMATIQUE. Ni popularite, ni influence, ni rumeur, ni courrier : la
  -- porte dit un fait et n'en tire rien.
  IF position('pop' IN v_txt) > 0 OR position('influence' IN v_txt) > 0
     OR position('rumeur' IN v_txt) > 0 OR position('mail' IN v_txt) > 0 THEN
    RAISE EXCEPTION 'P7 ECHOUEE -- la porte des statuts produit un effet de jeu'; END IF;

  -- P8 : L'EXPIRATION EST RESERVEE AU SERVEUR, et elle retire la recherche de l'acte clos.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'justice_delais_echus';
  IF position('est_appel_serveur()' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P8 ECHOUEE -- l''expiration n''est pas reservee au serveur'; END IF;
  IF position('public.recherche_retirer(ARRAY[v_infr]' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P8 ECHOUEE -- l''expiration ne resout pas la recherche de l''acte clos'; END IF;
  IF position('est_appel_serveur()' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P8 ECHOUEE -- porte ouverte'; END IF;

  -- P9 : AUCUN DROIT CLIENT SUR LES PORTES INTERNES. Seuls les statuts publics sont appelables
  -- depuis un navigateur.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace,
         aclexplode(p.proacl) a
   WHERE n.nspname = 'public'
     AND p.proname IN ('justice_delais_echus', 'affaire_delai_expire',
                       'justice_affaires_vivantes_avec_pv', 'affaire_infraction_de')
     AND (SELECT rolname FROM pg_roles WHERE oid = a.grantee) IN ('anon', 'authenticated');
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'P9 ECHOUEE -- % droit(s) client sur les portes internes du delai', v_n; END IF;
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace,
         aclexplode(p.proacl) a
   WHERE n.nspname = 'public' AND p.proname = 'justice_statuts_publics'
     AND (SELECT rolname FROM pg_roles WHERE oid = a.grantee) = 'authenticated';
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'P9 ECHOUEE -- les statuts publics ne sont pas appelables par un joueur'; END IF;

  RAISE NOTICE 'LES 9 PREUVES SONT VERTES.';
END $preuves$;
