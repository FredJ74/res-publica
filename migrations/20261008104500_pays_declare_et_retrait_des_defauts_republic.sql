-- =============================================================================
-- UN PAYS ABSENT NE DEVIENT PLUS REPUBLIA -- LE GARDE-FOU ET LES ONZE DEFAUTS
-- Chantier 4G, 8 octobre 2026
-- =============================================================================
--
-- ⚠ CETTE MIGRATION N'EST PAS APPLIQUEE. Elle a ete ecrite et sa grammaire est validee
-- localement (pglast, grammaire de PostgreSQL 17), mais l'instance Supabase est redevenue
-- injoignable pendant le lot -- trois echecs consecutifs, dont deux `SELECT 1` nus en
-- « Connection terminated due to connection timeout ». Le banc en transaction annulee n'a donc
-- PAS pu rendre son rapport : rien n'est prouve contre la base reelle, et rien ne doit etre
-- affirme a ce sujet.
--
-- CE QU'IL FAUT FAIRE AVANT DE L'APPLIQUER, dans cet ordre :
--   1. les quatre sondes de stabilite (SELECT 1, list_migrations, list_tables, SELECT 1) ;
--   2. le banc ci-dessous, en BEGIN ... ROLLBACK, et LIRE son rapport ;
--   3. l'application, seulement si le rapport est conforme ;
--   4. la relecture de l'etat LIVE, puis la reextraction du baseline.
--
-- -----------------------------------------------------------------------------
-- 1. LA RACINE : UN PERSONNAGE APPARTIENT A UN EMPIRE DECLARE
-- -----------------------------------------------------------------------------
-- MESURE DU 8 OCTOBRE 2026, avant d'ecrire une ligne : personnages_donnees.country est
-- `text NOT NULL`, sans valeur par defaut et SANS AUCUN CHECK. Les huit lignes vivantes portent
-- toutes `republic`, et aucune ne sort du referentiel.
--
-- CE QUE NOT NULL NE DIT PAS. Il n'interdit pas la CHAINE VIDE, et il n'interdit pas un empire
-- inexistant. Or les deux fonctions de la vue -- personnages_vue_inserer et
-- personnages_vue_modifier, seul chemin d'ecriture ouvert aux clients, la table elle-meme etant
-- fermee a anon et authenticated depuis le chantier B -- passent `NEW.country` TEL QUEL, sans
-- aucune validation. Un client pouvait donc se declarer d'un pays vide ou inventé.
--
-- POURQUOI CELA COMPTE AUTANT. Cote navigateur, 227 sites ecrivent `state.country || 'republic'`.
-- Tous sont en aval d'UNE SEULE ligne, applyCharToState, et un pays vide y devenait Republia :
-- le personnage heritait de l'Assemblee de Republia, de ses lois d'interdiction et de son
-- circuit fiscal. Poser la garde ICI rend ces 227 replis INATTEIGNABLES pour un personnage
-- charge, sans en modifier un seul -- c'est une garde, pas un balayage.
--
-- POURQUOI UN DECLENCHEUR ET PAS UN CHECK. Un CHECK ne peut pas interroger une autre table, et
-- la liste des empires ne doit exister qu'a UN endroit : le referentiel `villes`. Recopier
-- ('republic','soviet','narco','khalija') dans une contrainte creerait une seconde regle, qui
-- divergerait le jour ou un empire s'ajoute. Le declencheur porte sur la TABLE et non sur la vue :
-- il couvre donc aussi les ecritures de service_role et des fonctions SECURITY DEFINER.

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

-- -----------------------------------------------------------------------------
-- 2. LES ONZE DEFAUTS `p_country text DEFAULT 'republic'`
-- -----------------------------------------------------------------------------
-- LES ONZE SONT TOUTES DU DOMAINE DE L'ASSEMBLEE -- dix `assemblee_*` plus depute_presence --
-- et c'est coherent : elles datent du chantier de l'Assemblee, ou Republia etait le seul empire
-- concerne. Le defaut etait donc une commodite, pas une regle metier.
--
-- AUCUN APPEL NE S'APPUIE DESSUS AUJOURD'HUI, et c'est verifie : les neuf appels SQL internes
-- passent tous le pays EXPLICITEMENT -- `v_row.country`, `v_perso.country`, `v_siege.country`,
-- `p_country` -- et les appels du cron comme ceux de supabase.js passent `p_country`. Retirer le
-- defaut ne casse donc aucun appelant connu ; il transforme seulement un appel INCOMPLET, qui
-- rendait silencieusement la reponse de Republia, en une erreur visible.
--
-- DEUX DE CES FONCTIONS SONT OUVERTES AUX CLIENTS, et ce sont les plus sensibles :
-- assemblee_verifier_vente (anon + authenticated) et assemblee_peut_deposer (anon +
-- authenticated). La premiere est le controle d'INTERDICTION commerciale : appelee sans pays, elle
-- appliquait la loi de Republia a un joueur d'un autre empire. Ce n'etait pas « permissif », mais
-- c'etait faux -- et c'est exactement le repli que la regle de socle interdit.
--
-- LA SIGNATURE NE CHANGE PAS. Retirer une valeur par defaut ne modifie ni le nom ni les types :
-- `assemblee_verifier_vente(jsonb,text)` reste `assemblee_verifier_vente(jsonb,text)`. Les droits
-- EXECUTE sont donc PRESERVES, et aucun GRANT n'est a rejouer -- ce que la preuve 3 verifie
-- plutot que de le supposer.
--
-- LA REECRITURE EST DYNAMIQUE, ET C'EST VOULU. Chaque fonction est relue par
-- pg_get_functiondef(), son en-tete est prive du defaut, et le resultat est rejoue. Recopier
-- onze corps a la main dans cette migration aurait introduit onze occasions de les alterer
-- involontairement ; ici, le corps n'est pas touche -- il est transporte.

DO $$
DECLARE r record; v_def text; v_n integer := 0;
BEGIN
  FOR r IN SELECT p.oid::regprocedure::text AS sig, pg_get_functiondef(p.oid) AS def
             FROM pg_proc p
             JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
            WHERE pg_get_function_arguments(p.oid) ILIKE '%DEFAULT ''republic''%'
            ORDER BY 1
  LOOP
    v_def := replace(r.def, ' DEFAULT ''republic''::text', '');
    IF v_def = r.def THEN
      RAISE EXCEPTION 'le defaut n''a pas pu etre retire de % : la forme du texte a change', r.sig;
    END IF;
    EXECUTE v_def;
    v_n := v_n + 1;
  END LOOP;
  IF v_n <> 11 THEN
    RAISE EXCEPTION 'ARRET : % fonctions traitees, 11 attendues. Le perimetre a bouge depuis la mesure du 8 octobre 2026 ; il faut le reconstater avant d''appliquer.', v_n;
  END IF;
  RAISE NOTICE '% defauts republic retires', v_n;
END $$;

-- -----------------------------------------------------------------------------
-- 3. LES PREUVES, DANS LA TRANSACTION
-- -----------------------------------------------------------------------------
DO $$
DECLARE
  v_restants integer; v_nb_fn integer; v_droits integer; v_lignes integer;
BEGIN
  -- PREUVE 1 -- plus aucun defaut republic nulle part.
  SELECT count(*) INTO v_restants
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
   WHERE pg_get_function_arguments(p.oid) ILIKE '%DEFAULT ''republic''%';
  IF v_restants <> 0 THEN
    RAISE EXCEPTION 'PREUVE 1 ECHOUEE -- % defaut(s) republic subsistent', v_restants;
  END IF;

  -- PREUVE 2 -- aucune signature n'a ete creee ni perdue : la reecriture a bien REMPLACE.
  SELECT count(*) INTO v_nb_fn
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public';
  IF v_nb_fn <> 664 THEN
    RAISE EXCEPTION 'PREUVE 2 ECHOUEE -- % signatures de fonction, 664 attendues (663 avant ce lot + personnage_pays_declare)', v_nb_fn;
  END IF;

  -- PREUVE 3 -- les droits des deux fonctions ouvertes aux clients sont INTACTS.
  SELECT count(*) INTO v_droits
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
    CROSS JOIN aclexplode(p.proacl) ae
    LEFT JOIN pg_roles rr ON rr.oid = ae.grantee
   WHERE p.proname IN ('assemblee_verifier_vente', 'assemblee_peut_deposer')
     AND coalesce(rr.rolname, 'PUBLIC') IN ('anon', 'authenticated')
     AND ae.privilege_type = 'EXECUTE';
  IF v_droits <> 4 THEN
    RAISE EXCEPTION 'PREUVE 3 ECHOUEE -- % droits EXECUTE anon/authenticated sur les deux fonctions ouvertes, 4 attendus', v_droits;
  END IF;

  -- PREUVE 4 -- un appel EXPLICITE continue de fonctionner.
  PERFORM public.assemblee_verifier_vente('[]'::jsonb, 'republic');

  -- PREUVE 5 -- un appel SANS pays ne rend plus la reponse de Republia : il leve.
  BEGIN
    PERFORM public.assemblee_verifier_vente('[]'::jsonb);
    RAISE EXCEPTION 'PREUVE 5 ECHOUEE -- un appel sans pays a ete accepte';
  EXCEPTION WHEN undefined_function THEN
    NULL;   -- c'est le comportement attendu
  END;

  -- PREUVE 6 -- aucun personnage vivant ne viole la garde.
  SELECT count(*) INTO v_lignes
    FROM public.personnages_donnees p
   WHERE coalesce(btrim(p.country), '') = ''
      OR NOT EXISTS (SELECT 1 FROM public.villes v WHERE v.pays = p.country);
  IF v_lignes <> 0 THEN
    RAISE EXCEPTION 'PREUVE 6 ECHOUEE -- % personnage(s) portent un pays non declare', v_lignes;
  END IF;

  RAISE NOTICE 'SIX PREUVES VERTES. % signatures, % droits clients preserves.', v_nb_fn, v_droits;
END $$;

-- -----------------------------------------------------------------------------
-- CE QUE CETTE MIGRATION NE FAIT PAS
-- -----------------------------------------------------------------------------
-- Elle ne touche a AUCUN des 287 replis `|| 'republic'` du navigateur : ils sont corriges ou
-- rendus inatteignables cote JavaScript, dans le meme lot, et les remplacer mecaniquement etait
-- explicitement exclu. Elle ne touche pas au circuit municipal, clos. Elle n'active l'economie
-- d'aucun autre empire : la garde REFUSE un pays inconnu, elle n'en fabrique pas. Et elle ne pose
-- aucune contrainte sur personnages_supprimes, qui est une archive -- contraindre le passe n'a
-- pas de sens, et le ferait echouer sur la premiere ligne heritee.
