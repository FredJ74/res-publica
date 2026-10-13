-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 13 OCTOBRE 2026
--
-- Registre Supabase : version 20261013065913 (UTC), nom
-- `greffe_le_dossier_d_une_affaire_jugee_cesse_d_etre_public`.
-- Le registre passe de 702 a 703 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 425ed61d2b10ccafca054dd14d3299db, 4944 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- UNE AFFAIRE JUGEE RENDAIT SON DOSSIER ENTIER LISIBLE PAR TOUT LE MONDE
--
-- LA FUITE, EXACTEMENT. La policy de lecture de `plaintes_en_cours` accordait la ligne a tout compte
-- authentifie des que `affaire_statut(data) = 'jugee'`. Or `data` n'est pas un resume : il porte le
-- TEXTE LIBRE du plaignant, son IDENTITE, la preuve reelle retenue et jusqu'au jet de la procedure
-- simplifiee. Un seul GET PostgREST rendait tout cela, pour toutes les affaires closes du pays.
--
-- C'EST CE QUE L'ARBITRAGE DU GREFFE INTERDIT. Le registre public nomme la personne visee, la
-- categorie generale, l'etat de la procedure et les temoins CITES. Les archives exposent la SUITE
-- des actes, jamais leur contenu. Les deux portes existent et disent cela.
--
-- CE QUI RESTE ACCORDE : les PARTIES sur leur propre affaire -- et c'est cette branche qui rend
-- atteignables le PV d'audition, le delai de jugement, le consentement a une audience anticipee et
-- l'appel --, le juge et le commissaire de la ville de l'affaire, et les deux ministres, qui sont
-- des autorites nommees et pas le public. L'avocat retenu, le Procureur et le juge lisent par leurs
-- portes dediees, qui filtrent chacune ce qu'elles ont le droit de dire.
--
-- AUCUNE DONNEE N'EST TOUCHEE : seule la regle de lecture change.
--
-- PREUVES STRUCTURELLES -- 7.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- UNE AFFAIRE JUGEE RENDAIT SON DOSSIER ENTIER LISIBLE PAR TOUT LE MONDE.
--
-- La policy de lecture de `plaintes_en_cours` accordait la ligne a tout compte authentifie des
-- que `affaire_statut(data) = 'jugee'`. Or `data` NE CONTIENT PAS un resume : il porte le TEXTE
-- LIBRE du plaignant (`motif`), son IDENTITE (`plaignant`), le PV d'audition VERBATIM
-- (`pv_audition`, `pv_refus`), la preuve reelle retenue (`preuve_reelle`) et jusqu'au jet de la
-- procedure simplifiee (`defense_jet`). Un seul GET PostgREST sur la table rendait tout cela,
-- pour toutes les affaires closes du pays.
--
-- C'EST EXACTEMENT CE QUE L'ARBITRAGE DU GREFFE INTERDIT. Le registre public nomme la personne
-- visee, la categorie generale, l'etat de la procedure et les temoins CITES. Les archives
-- exposent la SUITE des actes, jamais leur contenu. Les deux portes existent et disent cela :
-- `justice_affaires_publiques()` et `justice_archives_greffe(affaire)`.
--
-- CE QUI RESTE ACCORDE, ET POURQUOI C'EST SUFFISANT :
--   . `affaire_me_concerne(data)` -- la personne visee et le plaignant, sur leur propre affaire.
--     C'est cette branche qui rend atteignables le PV d'audition, le delai de jugement, le
--     consentement a une audience anticipee et l'appel. Elle ne connait pas de statut : une
--     affaire jugee reste lisible par ses parties.
--   . `affaire_autorite_de(city)` -- le juge et le commissaire de la ville de l'affaire.
--   . les deux ministres, inchanges : ce sont des autorites nommees, pas le public.
-- L'avocat retenu, le Procureur et le juge lisent par leurs portes dediees -- `avocat_dossier`,
-- `parquet_dossiers`, `juge_dossiers` -- qui filtrent chacune ce qu'elles ont le droit de dire.
--
-- AUCUNE DONNEE N'EST TOUCHEE : seule la regle de lecture change.

DROP POLICY IF EXISTS "affaire lue par les parties, l autorite, ou publique une fois j"
  ON public.plaintes_en_cours;

CREATE POLICY "affaire lue par ses parties et par l autorite de sa ville"
  ON public.plaintes_en_cours FOR SELECT TO authenticated
  USING (
    public.affaire_autorite_de(city)
    OR public.mon_poste_est_dans('min_just', country)
    OR public.mon_poste_est_dans('min_int', country)
    OR public.affaire_me_concerne(data)
  );

DO $$
DECLARE v_n integer; v_q text;
BEGIN
  -- P1 -- une seule policy de lecture, et c'est la neuve.
  SELECT count(*) INTO v_n FROM pg_policies
   WHERE schemaname = 'public' AND tablename = 'plaintes_en_cours' AND cmd = 'SELECT';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P1 ECHOUEE -- % policy(s) de lecture', v_n; END IF;

  -- P2 -- LE STATUT N'OUVRE PLUS RIEN. Aucune mention de `affaire_statut` ni de 'jugee' dans la
  -- condition : c'est la fuite qui est fermee, et elle est nommee ici pour qu'on ne la rouvre
  -- pas par distraction.
  SELECT qual INTO v_q FROM pg_policies
   WHERE schemaname = 'public' AND tablename = 'plaintes_en_cours' AND cmd = 'SELECT';
  IF v_q ILIKE '%affaire_statut%' OR v_q ILIKE '%jugee%' THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- le statut ouvre encore la lecture : %', v_q; END IF;

  -- P3 -- LES QUATRE PORTES LEGITIMES SONT TOUJOURS LA.
  IF v_q NOT ILIKE '%affaire_me_concerne%' OR v_q NOT ILIKE '%affaire_autorite_de%'
     OR v_q NOT ILIKE '%min_just%' OR v_q NOT ILIKE '%min_int%' THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- une branche legitime a disparu : %', v_q; END IF;

  -- P4 -- AUCUNE AUTRE PORTE NE S'EST OUVERTE AU PASSAGE : la table reste en lecture seule pour
  -- le client, et fermee a `anon`.
  SELECT count(*) INTO v_n FROM information_schema.table_privileges
   WHERE table_schema = 'public' AND table_name = 'plaintes_en_cours'
     AND grantee IN ('anon', 'authenticated', 'PUBLIC')
     AND privilege_type <> 'SELECT';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P4 ECHOUEE -- % droit(s) client autre(s) que SELECT', v_n; END IF;
  SELECT count(*) INTO v_n FROM information_schema.table_privileges
   WHERE table_schema = 'public' AND table_name = 'plaintes_en_cours' AND grantee = 'anon';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P5 ECHOUEE -- anon lit les dossiers judiciaires'; END IF;

  -- P6 -- LA RLS EST ACTIVE. Une policy sans RLS ne ferme rien.
  SELECT count(*) INTO v_n FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public' AND c.relname = 'plaintes_en_cours' AND c.relrowsecurity;
  IF v_n <> 1 THEN RAISE EXCEPTION 'P6 ECHOUEE -- la RLS n''est pas active'; END IF;

  -- P7 -- LES DEUX PORTES PUBLIQUES DU GREFFE EXISTENT TOUJOURS, et restent appelables par un
  -- joueur ordinaire. Fermer la table sans elles aurait rendu le greffe muet.
  SELECT count(*) INTO v_n FROM information_schema.routine_privileges
   WHERE routine_schema = 'public' AND grantee = 'authenticated'
     AND routine_name IN ('justice_affaires_publiques', 'justice_archives_greffe');
  IF v_n < 2 THEN RAISE EXCEPTION 'P7 ECHOUEE -- % porte(s) publique(s) du greffe', v_n; END IF;

  RAISE NOTICE 'LES 7 PREUVES SONT VERTES.';
END $$;
