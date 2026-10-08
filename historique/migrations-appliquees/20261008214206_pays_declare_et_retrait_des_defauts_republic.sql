-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 8 OCTOBRE 2026
--
-- Registre Supabase : version 20261008214206, nom
-- `pays_declare_et_retrait_des_defauts_republic`. Registre passe de 559 a 560 entrees.
--
-- LE CORPS CI-DESSOUS EST EXACTEMENT CELUI QUI A TOURNE, relu dans
-- supabase_migrations.schema_migrations apres application : md5
-- a0e80fe8918c3993cf13bc841f317ba8 pour 8 922 caracteres, en un seul statement.
--
-- -----------------------------------------------------------------------------
-- CE QU'ELLE FERME : REPUBLIA CESSE D'ETRE LE PAYS DE CEUX DONT ON NE SAIT RIEN
-- -----------------------------------------------------------------------------
-- Chantier 4G. Deux mecanismes, une seule regle de socle : un pays absent, vide ou inconnu
-- ne devient plus Republia en silence.
--
-- 1. LE GARDE-FOU. personnages_donnees.country etait `text NOT NULL` sans aucun CHECK -- or
--    NOT NULL n'interdit ni la chaine vide ni un empire inexistant, et les deux fonctions de
--    la vue (seul chemin d'ecriture ouvert aux clients) passaient NEW.country TEL QUEL. Un
--    client pouvait se declarer d'un pays invente. Le declencheur porte sur la TABLE, donc il
--    couvre aussi service_role et les fonctions SECURITY DEFINER. La liste des empires n'est
--    PAS recopiee dans une contrainte : elle est lue dans `villes`, seul endroit ou elle vive.
--
--    Cote navigateur, 227 sites ecrivent `state.country || 'republic'`. Tous sont en aval
--    d'UNE SEULE ligne, applyCharToState. Poser la garde ici les rend INATTEIGNABLES pour un
--    personnage charge, sans en modifier un seul. C'est une garde, pas un balayage.
--
-- 2. LES ONZE `DEFAULT 'republic'`. Toutes du domaine de l'Assemblee -- dix `assemblee_*` plus
--    depute_presence -- heritees du chantier ou Republia etait le seul empire concerne. Deux
--    sont ouvertes aux clients, et ce sont les plus sensibles : assemblee_verifier_vente, qui
--    est le controle d'INTERDICTION commerciale, et assemblee_peut_deposer. Appelee sans pays,
--    la premiere appliquait la loi de Republia a un joueur d'un autre empire : pas
--    « permissif », mais faux. Le defaut retire, l'oubli devient bruyant.
--
-- -----------------------------------------------------------------------------
-- POURQUOI LA STRATEGIE A CHANGE EN COURS DE ROUTE -- ET CE QUE LE BANC A ATTRAPE
-- -----------------------------------------------------------------------------
-- La premiere version de cette migration retirait les defauts par `CREATE OR REPLACE
-- FUNCTION`. Le banc en transaction annulee l'a refusee :
--
--     ERROR 42P13: cannot remove parameter defaults from existing function
--     HINT:  Use DROP FUNCTION assemblee_cloturer_echues(text) first.
--
-- `CREATE OR REPLACE` peut AJOUTER un defaut et le CHANGER ; il ne peut pas le RETIRER. La
-- premiere version reposait sur une hypothese jamais eprouvee contre une vraie base. C'est
-- exactement ce qu'un banc sert a attraper, et c'est la seule raison pour laquelle elle n'a
-- pas ete appliquee telle quelle.
--
-- LE DETOUR PAR `DROP` COUTE TROIS CHOSES, TOUTES MESUREES AVANT D'ECRIRE UNE LIGNE :
--
--   1. LE SCHEMA public PORTE UN PRIVILEGE PAR DEFAUT. pg_default_acl y declare, pour les
--      fonctions creees par postgres, `{postgres=X, authenticated=X, service_role=X}`. Une
--      fonction recreee arrive donc OUVERTE A `authenticated` -- alors que sept des onze sont
--      des fonctions de cron que seul le serveur doit appeler. Un `REVOKE ... FROM PUBLIC`
--      n'y suffit pas : PUBLIC n'est meme pas le probleme, les roles NOMMES le sont. Le banc
--      l'a vu en signalant 7 droits APPARUS alors que 0 etait perdu.
--   2. TROIS DES ONZE PORTENT UN COMMENTAIRE. Un DROP le perd, et le baseline aurait
--      tranquillement compte trois commentaires de moins.
--   3. AUCUNE n'a de dependance non interne -- verifie dans pg_depend : zero vue, zero
--      declencheur. C'est ce qui rend le DROP acceptable. Si une seule en avait eu, il aurait
--      fallu une autre strategie, et surtout pas un CASCADE.
--
-- D'OU LA METHODE : memoriser l'etat exact des onze (corps, commentaire, liste des roles),
-- detruire, recreer sans le defaut, RETIRER tout role que la recreation a introduit et qui
-- n'etait pas la, REPOSER exactement ceux qui l'etaient, et remettre le commentaire. La
-- preuve 4 ne compte pas les operations : elle compare les ENSEMBLES de droits, dans les deux
-- sens -- ni perdu, ni apparu. C'est la seule formulation qui attrape a la fois une fermeture
-- excessive et une ouverture accidentelle.
--
-- LE CORPS N'EST PAS RECOPIE, IL EST TRANSPORTE : chaque fonction est relue par
-- pg_get_functiondef(), son en-tete prive du defaut, et le resultat rejoue. Recopier onze
-- corps a la main aurait introduit onze occasions de les alterer. La preuve 7 compare le
-- texte rendu au texte memorise, defaut mis a part.
--
-- -----------------------------------------------------------------------------
-- CE QUI A ETE PROUVE, ET QUAND
-- -----------------------------------------------------------------------------
-- AVANT L'APPLICATION, en transaction annulee, deux bancs separes :
--   . le garde-fou, 12 epreuves sur 12 -- dont une CONTRE-EPREUVE etablissant qu'AVANT la
--     garde un pays invente est bel et bien accepte. Sans elle, le banc n'aurait rien prouve.
--     Un pays vide est refuse (pays_absent), un empire inconnu refuse (pays_non_declare) a
--     l'UPDATE comme a l'INSERT -- le BEFORE mord avant les contraintes de colonne -- et un
--     passage a `soviet` est ACCEPTE : la garde refuse l'inconnu, elle n'enferme pas Republia.
--   . les onze defauts : 0 droit perdu, 0 droit apparu, 3/3 commentaires restitues, 11/11
--     corps transportes sans alteration, 11/11 signatures intactes, 0 defaut restant.
--
-- A L'APPLICATION : les dix preuves ci-dessous ont tourne DANS la transaction de la migration.
-- Si l'une avait echoue, l'application entiere aurait echoue. C'est ce qui rend cette
-- migration auto-verifiee plutot que verifiee a cote.
--
-- APRES L'APPLICATION, relu sur la base reelle : registre 560, migration presente une seule
-- fois, garde et declencheur presents, 0 defaut republic, 664 signatures, 4/4 droits clients
-- des deux fonctions ouvertes, 0 droit `authenticated` sur les sept fonctions de cron, 3
-- commentaires, 0 personnage sans pays declare, 0 objet temporaire residuel.
--
-- LES NEUF TABLES QUI PORTENT DE L'ARGENT SONT INCHANGEES, par empreinte md5 avant/apres :
-- caisses_batiments, comptes_bancaires, budgets_nationaux, budgets_municipaux, budgets_clubs,
-- entreprises, batiments_etat, terrains_etat, villes. Cette migration n'a touche aucune
-- donnee : ni INSERT, ni UPDATE de ligne, ni DELETE, ni TRUNCATE, ni DROP TABLE.
--
-- -----------------------------------------------------------------------------
-- CE QU'ELLE NE FAIT PAS
-- -----------------------------------------------------------------------------
-- Elle ne touche a AUCUN des 287 replis `|| 'republic'` du navigateur : ils sont corriges ou
-- rendus inatteignables cote JavaScript dans le meme lot (commit 7751bc0), et les remplacer
-- mecaniquement etait explicitement exclu. Elle ne touche pas au circuit municipal, clos.
-- Elle n'active l'economie d'aucun autre empire : la garde REFUSE un pays inconnu, elle n'en
-- fabrique pas. Elle ne pose aucune contrainte sur personnages_supprimes, qui est une archive
-- -- contraindre le passe n'a pas de sens, et echouerait sur la premiere ligne heritee.
--
-- ET ELLE NE CORRIGE PAS LE PRIVILEGE PAR DEFAUT DU SCHEMA public, qui ouvre a
-- `authenticated` toute fonction neuve. C'est un constat de securite reel, decouvert par ce
-- banc, mais d'un autre perimetre : il est consigne separement et n'est pas traite ici.
-- =============================================================================

-- Chantier 4G -- un pays absent ne devient plus Republia.
-- Le raisonnement complet, les trois pieges mesures et le detail des deux bancs sont dans
-- migrations/20261008104500_pays_declare_et_retrait_des_defauts_republic.sql, dont ce texte
-- est le code executable (meme arbre syntaxique, 8 instructions, commentaires retires pour
-- la taille du transport). Banc en transaction annulee : 10 preuves vertes avant application.

CREATE OR REPLACE FUNCTION public.personnage_pays_declare()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF coalesce(btrim(NEW.country), '') = '' THEN
    RAISE EXCEPTION 'pays_absent : un personnage doit appartenir a un empire declare';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.villes v WHERE v.pays = NEW.country) THEN
    RAISE EXCEPTION 'pays_non_declare : % n''est pas un empire du referentiel', NEW.country;
  END IF;
  RETURN NEW;
END;
$function$;

COMMENT ON FUNCTION public.personnage_pays_declare() IS
  'Refuse un personnage dont le pays est absent, vide, ou absent du referentiel `villes`. Republia est le premier empire implemente, jamais le repli implicite de ce qu''on ne sait pas lire. La liste des empires n''est PAS recopiee ici : elle est lue dans villes, seul endroit ou elle vive.';

REVOKE ALL ON FUNCTION public.personnage_pays_declare() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.personnage_pays_declare() FROM anon;
REVOKE ALL ON FUNCTION public.personnage_pays_declare() FROM authenticated;

DROP TRIGGER IF EXISTS trg_personnage_pays_declare ON public.personnages_donnees;
CREATE TRIGGER trg_personnage_pays_declare
  BEFORE INSERT OR UPDATE OF country ON public.personnages_donnees
  FOR EACH ROW EXECUTE FUNCTION public.personnage_pays_declare();

DO $$
DECLARE
  v_etat jsonb; v_item jsonb; v_sig text; v_def text; v_role text;
  v_memo jsonb; v_actuel jsonb; v_n integer := 0; v_com integer := 0; v_nb_fn integer;
BEGIN
  SELECT coalesce(jsonb_agg(x.item ORDER BY x.sig), '[]'::jsonb) INTO v_etat
    FROM (
      SELECT format('public.%I(%s)', p.proname, pg_get_function_identity_arguments(p.oid)) AS sig,
             jsonb_build_object(
               'sig',   format('public.%I(%s)', p.proname, pg_get_function_identity_arguments(p.oid)),
               'def',   pg_get_functiondef(p.oid),
               'com',   obj_description(p.oid, 'pg_proc'),
               'roles', (SELECT coalesce(jsonb_agg(coalesce(ro.rolname, 'PUBLIC')
                                                   ORDER BY coalesce(ro.rolname, 'PUBLIC')), '[]'::jsonb)
                           FROM aclexplode(p.proacl) ae
                           LEFT JOIN pg_roles ro ON ro.oid = ae.grantee
                          WHERE ae.privilege_type = 'EXECUTE')
             ) AS item
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
       WHERE pg_get_function_arguments(p.oid) ILIKE '%DEFAULT ''republic''%'
    ) x;

  IF jsonb_array_length(v_etat) <> 11 THEN
    RAISE EXCEPTION 'ARRET : % fonctions portent le defaut, 11 attendues.', jsonb_array_length(v_etat);
  END IF;

  FOR v_item IN SELECT jsonb_array_elements(v_etat) LOOP
    v_sig := v_item ->> 'sig';
    v_def := replace(v_item ->> 'def', ' DEFAULT ''republic''::text', '');
    IF v_def = (v_item ->> 'def') THEN
      RAISE EXCEPTION 'le defaut n''a pas pu etre retire de % : la forme du texte a change', v_sig;
    END IF;
    EXECUTE 'DROP FUNCTION ' || v_sig;
    EXECUTE v_def;
    FOR v_role IN
      SELECT coalesce(ro.rolname, 'PUBLIC')
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
        CROSS JOIN aclexplode(p.proacl) ae
        LEFT JOIN pg_roles ro ON ro.oid = ae.grantee
       WHERE format('public.%I(%s)', p.proname, pg_get_function_identity_arguments(p.oid)) = v_sig
         AND ae.privilege_type = 'EXECUTE'
         AND NOT (v_item -> 'roles') @> to_jsonb(coalesce(ro.rolname, 'PUBLIC'))
    LOOP
      IF v_role = 'PUBLIC' THEN EXECUTE 'REVOKE ALL ON FUNCTION ' || v_sig || ' FROM PUBLIC';
      ELSE EXECUTE format('REVOKE ALL ON FUNCTION %s FROM %I', v_sig, v_role); END IF;
    END LOOP;
    FOR v_role IN SELECT jsonb_array_elements_text(v_item -> 'roles') LOOP
      IF v_role = 'PUBLIC' THEN EXECUTE 'GRANT EXECUTE ON FUNCTION ' || v_sig || ' TO PUBLIC';
      ELSE EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO %I', v_sig, v_role); END IF;
    END LOOP;
    IF (v_item ->> 'com') IS NOT NULL THEN
      EXECUTE format('COMMENT ON FUNCTION %s IS %L', v_sig, v_item ->> 'com');
      v_com := v_com + 1;
    END IF;
    v_n := v_n + 1;
  END LOOP;

  IF v_n <> 11 THEN RAISE EXCEPTION 'ARRET : % fonctions traitees, 11 attendues', v_n; END IF;

  IF (SELECT count(*) FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
       WHERE pg_get_function_arguments(p.oid) ILIKE '%DEFAULT ''republic''%') <> 0 THEN
    RAISE EXCEPTION 'PREUVE 1 ECHOUEE -- des defauts republic subsistent';
  END IF;

  SELECT count(*) INTO v_nb_fn FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public';
  IF v_nb_fn <> 664 THEN
    RAISE EXCEPTION 'PREUVE 2 ECHOUEE -- % signatures, 664 attendues', v_nb_fn;
  END IF;

  FOR v_item IN SELECT jsonb_array_elements(v_etat) LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_proc p
                     JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
                    WHERE format('public.%I(%s)', p.proname,
                                 pg_get_function_identity_arguments(p.oid)) = (v_item ->> 'sig')) THEN
      RAISE EXCEPTION 'PREUVE 3 ECHOUEE -- la signature % a disparu', v_item ->> 'sig';
    END IF;
  END LOOP;

  FOR v_item IN SELECT jsonb_array_elements(v_etat) LOOP
    v_sig := v_item ->> 'sig'; v_memo := v_item -> 'roles';
    SELECT coalesce(jsonb_agg(coalesce(ro.rolname,'PUBLIC') ORDER BY coalesce(ro.rolname,'PUBLIC')), '[]'::jsonb)
      INTO v_actuel
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
      CROSS JOIN aclexplode(p.proacl) ae
      LEFT JOIN pg_roles ro ON ro.oid = ae.grantee
     WHERE format('public.%I(%s)', p.proname, pg_get_function_identity_arguments(p.oid)) = v_sig
       AND ae.privilege_type = 'EXECUTE';
    IF v_actuel <> v_memo THEN
      RAISE EXCEPTION 'PREUVE 4 ECHOUEE -- droits de % : memorise %, obtenu %', v_sig, v_memo, v_actuel;
    END IF;
  END LOOP;

  IF (SELECT count(*) FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
        CROSS JOIN aclexplode(p.proacl) ae
        LEFT JOIN pg_roles ro ON ro.oid = ae.grantee
       WHERE p.proname IN ('assemblee_verifier_vente','assemblee_peut_deposer')
         AND coalesce(ro.rolname,'PUBLIC') IN ('anon','authenticated')
         AND ae.privilege_type = 'EXECUTE') <> 4 THEN
    RAISE EXCEPTION 'PREUVE 5 ECHOUEE -- les droits clients ont bouge';
  END IF;

  IF v_com <> 3 THEN RAISE EXCEPTION 'PREUVE 6 ECHOUEE -- % commentaires, 3 attendus', v_com; END IF;
  FOR v_item IN SELECT jsonb_array_elements(v_etat) LOOP
    IF (v_item ->> 'com') IS NOT NULL
       AND (v_item ->> 'com') <> (SELECT obj_description(p.oid,'pg_proc') FROM pg_proc p
                                    JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
                                   WHERE format('public.%I(%s)', p.proname,
                                                pg_get_function_identity_arguments(p.oid)) = (v_item ->> 'sig')) THEN
      RAISE EXCEPTION 'PREUVE 6 ECHOUEE -- commentaire de % non restitue', v_item ->> 'sig';
    END IF;
  END LOOP;

  FOR v_item IN SELECT jsonb_array_elements(v_etat) LOOP
    IF replace(v_item ->> 'def', ' DEFAULT ''republic''::text', '')
       <> (SELECT pg_get_functiondef(p.oid) FROM pg_proc p
             JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
            WHERE format('public.%I(%s)', p.proname,
                         pg_get_function_identity_arguments(p.oid)) = (v_item ->> 'sig')) THEN
      RAISE EXCEPTION 'PREUVE 7 ECHOUEE -- le corps de % a ete altere', v_item ->> 'sig';
    END IF;
  END LOOP;

  PERFORM public.assemblee_verifier_vente('[]'::jsonb, 'republic');

  BEGIN
    PERFORM public.assemblee_verifier_vente('[]'::jsonb);
    RAISE EXCEPTION 'PREUVE 9 ECHOUEE -- un appel sans pays a ete accepte';
  EXCEPTION WHEN undefined_function THEN NULL;
  END;

  IF (SELECT count(*) FROM public.personnages_donnees p
       WHERE coalesce(btrim(p.country),'') = ''
          OR NOT EXISTS (SELECT 1 FROM public.villes v WHERE v.pays = p.country)) <> 0 THEN
    RAISE EXCEPTION 'PREUVE 10 ECHOUEE -- des personnages portent un pays non declare';
  END IF;

  RAISE NOTICE 'DIX PREUVES VERTES. % fonctions refaites, % commentaires reposes, % signatures.',
    v_n, v_com, v_nb_fn;
END $$;
