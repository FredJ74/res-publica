-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 11 OCTOBRE 2026
--
-- Registre Supabase : version 20261011013449 (UTC), nom `memoire_un_nom_de_contrainte_par_contrainte`.
-- Le registre passe de 646 a 644 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 f358281f5ad35708f27538a0f100ecd1, 3605 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- UNE SIMULATION DE RECONSTRUCTION A VU CE QU'AUCUN AUTRE CONTROLE NE VOYAIT
--
-- La migration de la memoire avait donne LE MEME NOM a deux CHECK differents : le genre d'une
-- SOURCE declaree et le genre d'un FAIT enregistre. PostgreSQL l'accepte -- un nom de contrainte
-- est unique par table, pas par schema -- et la base les a tous deux pris sans rien dire.
--
-- Ce n'est donc pas une erreur de SQL mais une erreur de LECTURE : deux regles distinctes sous un
-- seul nom, listees a la suite dans un fichier de baseline, c'est un piege pour qui lira un
-- message d'erreur de contrainte. On renomme plutot que d'assouplir le controle qui l'a vu.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- =================================================================================================
-- DEUX CONTRAINTES NE PARTAGENT PAS UN NOM (11 octobre 2026)
-- =================================================================================================
-- CE QUE LA SIMULATION DE RECONSTRUCTION A TROUVE, et qu'aucun autre controle n'aurait vu :
--
--   politique-et-elections/30_contraintes.sql (ordre 27) :
--   contrainte presidence_memoire_genre_connu declaree deux fois
--
-- La migration de la memoire des mandats a donne LE MEME NOM a deux CHECK differents : celui qui
-- borne le genre d'une SOURCE declaree (`presidence_memoire_sources`) et celui qui borne le genre
-- d'un FAIT enregistre (`presidence_memoire`). PostgreSQL l'accepte -- un nom de contrainte est
-- unique par table, pas par schema -- et la base les a tous deux pris sans rien dire.
--
-- CE N'EST DONC PAS UNE ERREUR DE SQL, MAIS UNE ERREUR DE LECTURE. Deux regles distinctes
-- portant un seul nom, dans un fichier de baseline qui les liste a la suite, c'est un piege pose
-- pour la prochaine personne qui lira un message d'erreur de contrainte : elle ne saura pas
-- laquelle des deux a parle. On renomme plutot que d'assouplir le controle qui l'a vu.
--
-- LE CHECK DE LA TABLE DES SOURCES PREND LE NOM DE SA TABLE. Celui de `presidence_memoire` garde
-- le sien : c'est la table principale, et son nom est deja le bon.
-- =================================================================================================

ALTER TABLE public.presidence_memoire_sources
  RENAME CONSTRAINT presidence_memoire_genre_connu TO presidence_memoire_sources_genre_connu;

-- -------------------------------------------------------------------------------------------------
-- PREUVES STRUCTURELLES
-- -------------------------------------------------------------------------------------------------
DO $$
DECLARE v_n integer;
BEGIN
  -- P1 : plus aucun nom de contrainte n'est porte par deux tables de la memoire.
  SELECT count(*) INTO v_n FROM (
    SELECT c.conname FROM pg_constraint c
      JOIN pg_class t ON t.oid = c.conrelid
      JOIN pg_namespace n ON n.oid = t.relnamespace
     WHERE n.nspname = 'public' AND t.relname LIKE 'presidence_memoire%'
     GROUP BY c.conname HAVING count(*) > 1) q;
  IF v_n <> 0 THEN RAISE EXCEPTION 'P1 : % nom(s) de contrainte encore partage(s)', v_n; END IF;

  -- P2 : les DEUX regles sont toujours la -- renommer n'est pas supprimer.
  SELECT count(*) INTO v_n FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid JOIN pg_namespace n ON n.oid = t.relnamespace
   WHERE n.nspname = 'public' AND c.contype = 'c'
     AND ((t.relname = 'presidence_memoire' AND c.conname = 'presidence_memoire_genre_connu')
       OR (t.relname = 'presidence_memoire_sources' AND c.conname = 'presidence_memoire_sources_genre_connu'));
  IF v_n <> 2 THEN RAISE EXCEPTION 'P2 : % des deux regles de genre au lieu de 2', v_n; END IF;

  -- P3 : et elles bornent bien les deux memes valeurs. Un renommage qui changerait la regle
  -- serait pire que le nom partage.
  SELECT count(*) INTO v_n FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid JOIN pg_namespace n ON n.oid = t.relnamespace
   WHERE n.nspname = 'public' AND t.relname LIKE 'presidence_memoire%' AND c.contype = 'c'
     AND pg_get_constraintdef(c.oid) LIKE '%contexte%'
     AND pg_get_constraintdef(c.oid) LIKE '%reaction%';
  IF v_n <> 2 THEN RAISE EXCEPTION 'P3 : une des deux regles de genre a change de contenu'; END IF;

  RAISE NOTICE 'Noms de contrainte : les 3 preuves structurelles passent.';
END $$;
