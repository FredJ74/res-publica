-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010090327 (UTC), nom `recherche_est_serveur_autoritaire`.
-- Le registre passe de 603 a 604 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 0d260843708d9f4f0e464fcc5b6c97d4, 3447 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- CHANTIER 5, CHAINE 14 : SECONDE MOITIE, LE VERROU
--
-- Tant que `sbSavePersonnage` republie `recherche` dans son blob de 48 colonnes, le dernier
-- ecrivain gagne malgre les deux portes atomiques. Meme doctrine que les PA : la colonne devient
-- SERVEUR-AUTORITAIRE et une version cliente divergente est ignoree en silence, elle seule, les
-- quarante-sept autres passant normalement. Le declencheur est sur la table, pas sur la vue.
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- CHANTIER 5, CHAINE 14 (10 octobre 2026), SECONDE MOITIE -- LE VERROU
--
-- Les deux portes posees juste avant rendent l'inscription et le retrait atomiques. Mais tant que
-- `sbSavePersonnage` republie `recherche` dans son blob de 48 colonnes, le dernier ecrivain gagne
-- toujours : une porte peut inscrire un motif a 10 h 00 et un simple changement de piece a 10 h 01
-- le fait disparaitre. LE VERROU EST DONC LA MOITIE QUI COMPTE.
--
-- MEME DOCTRINE QUE LES PA, en service depuis le 16 septembre 2026 : la colonne est
-- SERVEUR-AUTORITAIRE, et une version cliente divergente est ignoree. Elle n'est pas refusee
-- bruyamment, et c'est volontaire : `sbSavePersonnage` envoie 48 colonnes d'un bloc, dont
-- quarante-sept parfaitement legitimes. Faire echouer tout le PATCH parce que la 48e est obsolete
-- casserait la sauvegarde du personnage entier. On ignore donc cette colonne-la, et UNIQUEMENT
-- elle -- ce que le declencheur fait deja pour les convocations et l'historique des crimes.
--
-- LE DECLENCHEUR EST SUR LA TABLE, et c'est ce qui rend le verrou complet : il voit les ecritures
-- clientes (par le declencheur de la vue), celles du cron (en service_role direct) et celles des
-- portes. Une seule porte de sortie, pour tout le monde.
--
-- CE QUI DEVIENT STRUCTURELLEMENT IMPOSSIBLE : qu'un avis de recherche soit efface par une
-- sauvegarde de fiche.

DO $$
DECLARE v_def text; v_new text;
BEGIN
  SELECT pg_get_functiondef('public.personnages_preserver_judiciaire()'::regprocedure) INTO v_def;
  v_new := replace(v_def,
'    NEW.historique_crimes := v_hist;
  END IF;

  RETURN NEW;',
'    NEW.historique_crimes := v_hist;
  END IF;

  -- ---------------------------------------------------------------- AVIS DE RECHERCHE
  -- SERVEUR-AUTORITAIRE depuis le 10 octobre 2026 (chantier 5, chaine 14). `recherche` n''a
  -- aucune cle : deux versions du tableau ne peuvent pas etre fusionnees, et le dernier ecrivain
  -- gagnait. Toute version entrante qui ne vient pas d''une porte est donc IGNOREE -- et seule
  -- cette colonne l''est, les quarante-sept autres du blob passent normalement.
  IF NEW.recherche IS DISTINCT FROM OLD.recherche
     AND coalesce(current_setting(''rp.recherche_interne'', true), '''') <> ''on'' THEN
    NEW.recherche := OLD.recherche;
  END IF;

  RETURN NEW;');
  IF v_new = v_def THEN
    RAISE EXCEPTION 'le fragment de fin de personnages_preserver_judiciaire est introuvable';
  END IF;
  EXECUTE v_new;
END $$;

DO $$
DECLARE v_t text;
BEGIN
  SELECT pg_get_functiondef('public.personnages_preserver_judiciaire()'::regprocedure) INTO v_t;
  IF v_t NOT LIKE '%NEW.recherche := OLD.recherche;%' THEN
    RAISE EXCEPTION 'P1 : le verrou n''est pas pose'; END IF;
  IF v_t NOT LIKE '%rp.recherche_interne%' THEN
    RAISE EXCEPTION 'P2 : le laissez-passer n''est pas lu'; END IF;
  IF v_t NOT LIKE '%NEW.convocations := v_convs;%'
     OR v_t NOT LIKE '%NEW.historique_crimes := v_hist;%' THEN
    RAISE EXCEPTION 'P3 : les deux protections preexistantes ont ete perdues'; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid
                  WHERE t.tgname='trg_personnages_preserver_judiciaire'
                    AND c.relname='personnages_donnees' AND NOT t.tgisinternal) THEN
    RAISE EXCEPTION 'P4 : le declencheur n''est plus sur personnages_donnees'; END IF;
  RAISE NOTICE 'verrou de recherche pose : 4 preuves structurelles conformes.';
END $$;
