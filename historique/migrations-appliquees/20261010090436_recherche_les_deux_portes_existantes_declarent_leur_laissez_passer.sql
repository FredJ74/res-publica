-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010090436 (UTC), nom `recherche_les_deux_portes_existantes_declarent_leur_laissez_passer`.
-- Le registre passe de 604 a 605 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 6ea6a71e72b939263b5b9bb7527ebfc5, 4988 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- CHANTIER 5, CHAINE 14 : LES DEUX LAISSEZ-PASSER
--
-- Deux fonctions deja en service ecrivent legitimement `recherche` -- `calomnie_inscrire_mandat`
-- et `militaire_presentation_affectation` -- et toutes deux etaient deja atomiques. Il leur
-- manquait seulement de se declarer, sans quoi le verrou pose juste avant les aurait rendues
-- silencieusement inoperantes. Patch en place : le corps des deux fonctions n'est jamais retape.
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- CHANTIER 5, CHAINE 14 (10 octobre 2026) -- LES DEUX LAISSEZ-PASSER
--
-- Le verrou pose juste avant ignore toute version de `recherche` qui ne vient pas d'une porte.
-- DEUX fonctions deja en service ecrivent legitimement cette colonne, et aucune des deux n'avait
-- le defaut de la chaine 14 -- elles etaient deja atomiques. Il leur manquait seulement de se
-- declarer, sans quoi le verrou les aurait rendues silencieusement inoperantes.
--
--   . `calomnie_inscrire_mandat` -- le mandat d'arret des tracts calomnieux. Son ecriture est un
--     `||` atomique. FAIT MESURE, et il compte : elle ecrit sur la VUE `public.personnages`, pas
--     sur la table. Le declencheur de preservation la voit quand meme, puisqu'il est pose sur la
--     TABLE et que le declencheur de la vue y repercute l'ecriture -- c'est exactement pourquoi
--     le verrou a ete pose la et pas sur la vue.
--   . `militaire_presentation_affectation` -- l'extinction des poursuites a la presentation a la
--     caserne. Son retrait est un `jsonb_agg` filtre, deja juste.
--
-- PATCH EN PLACE : le corps de ces deux fonctions n'est jamais retape, et un fragment absent
-- ferait echouer la migration bruyamment.

DO $$
DECLARE v_def text; v_new text;
BEGIN
  SELECT pg_get_functiondef(
    'public.calomnie_inscrire_mandat(text,text,text,text,timestamptz)'::regprocedure) INTO v_def;
  v_new := replace(v_def,
'  UPDATE public.personnages
     SET recherche =',
'  PERFORM set_config(''rp.recherche_interne'', ''on'', true);
  UPDATE public.personnages
     SET recherche =');
  IF v_new = v_def THEN
    RAISE EXCEPTION 'calomnie_inscrire_mandat : fragment UPDATE introuvable';
  END IF;
  EXECUTE v_new;
END $$;

DO $$
DECLARE v_def text; v_new text;
BEGIN
  SELECT pg_get_functiondef('public.militaire_presentation_affectation()'::regprocedure) INTO v_def;
  v_new := replace(v_def,
'  UPDATE public.personnages_donnees
     SET requisition = v_req, recherche = v_recherche2',
'  PERFORM set_config(''rp.recherche_interne'', ''on'', true);
  UPDATE public.personnages_donnees
     SET requisition = v_req, recherche = v_recherche2');
  IF v_new = v_def THEN
    RAISE EXCEPTION 'militaire_presentation_affectation : fragment UPDATE introuvable';
  END IF;
  EXECUTE v_new;
END $$;

DO $$
DECLARE v_n integer;
BEGIN
  -- P1 : QUATRE fonctions posent le laissez-passer, et aucune autre. C'est la liste fermee des
  -- ecrivains legitimes de la colonne.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='public'
     AND pg_get_functiondef(p.oid) LIKE '%set_config(''rp.recherche_interne''%';
  IF v_n <> 4 THEN
    RAISE EXCEPTION 'P1 : % fonction(s) posent le laissez-passer au lieu de 4', v_n; END IF;

  -- P2 : les quatre sont nommement celles qu'on attend.
  IF NOT (EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
            WHERE n.nspname='public' AND p.proname='recherche_inscrire'
              AND pg_get_functiondef(p.oid) LIKE '%rp.recherche_interne%')
      AND EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
            WHERE n.nspname='public' AND p.proname='recherche_retirer'
              AND pg_get_functiondef(p.oid) LIKE '%rp.recherche_interne%')
      AND EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
            WHERE n.nspname='public' AND p.proname='calomnie_inscrire_mandat'
              AND pg_get_functiondef(p.oid) LIKE '%rp.recherche_interne%')
      AND EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
            WHERE n.nspname='public' AND p.proname='militaire_presentation_affectation'
              AND pg_get_functiondef(p.oid) LIKE '%rp.recherche_interne%')) THEN
    RAISE EXCEPTION 'P2 : la liste des quatre ecrivains legitimes n''est pas celle attendue'; END IF;

  -- P3 : les deux portes patchees gardent leur ACL exacte et leur nature.
  IF (SELECT coalesce(array_to_string(proacl::text[],' | '),'(defaut)') FROM pg_proc p
       JOIN pg_namespace n ON n.oid=p.pronamespace
      WHERE n.nspname='public' AND p.proname='calomnie_inscrire_mandat')
     <> 'postgres=X/postgres | service_role=X/postgres' THEN
    RAISE EXCEPTION 'P3a : l''ACL de calomnie_inscrire_mandat a change'; END IF;
  IF (SELECT coalesce(array_to_string(proacl::text[],' | '),'(defaut)') FROM pg_proc p
       JOIN pg_namespace n ON n.oid=p.pronamespace
      WHERE n.nspname='public' AND p.proname='militaire_presentation_affectation')
     <> 'postgres=X/postgres | authenticated=X/postgres | service_role=X/postgres' THEN
    RAISE EXCEPTION 'P3b : l''ACL de militaire_presentation_affectation a change'; END IF;

  -- P4 : les avis de recherche existants n'ont pas bouge.
  SELECT count(*) INTO v_n FROM public.personnages_donnees
   WHERE recherche IS NOT NULL AND jsonb_array_length(recherche) > 0;
  RAISE NOTICE 'laissez-passer : 3 preuves conformes ; % fiche(s) portant un avis de recherche.', v_n;
END $$;
