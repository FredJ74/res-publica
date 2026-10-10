-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010090719 (UTC), nom `recherche_le_laissez_passer_ne_dure_que_son_ecriture`.
-- Le registre passe de 605 a 606 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 391ea787b38c66458dbecf84c4670286, 5249 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- CHANTIER 5, CHAINE 14 : LA PORTEE DU LAISSEZ-PASSER
--
-- Defaut trouve par le banc comportemental, pas par la relecture : `set_config(..., true)` est
-- local a la TRANSACTION et non a l'instruction, donc toute ecriture ulterieure de `recherche`
-- dans la meme transaction franchissait le verrou. Les quatre portes referment desormais le
-- laissez-passer immediatement apres leur ecriture.
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- CHANTIER 5, CHAINE 14 -- DEFAUT DE MA PROPRE CONCEPTION, TROUVE PAR LE BANC (10 octobre 2026)
--
-- Le banc comportemental a refuse la premiere version du verrou, et il avait raison.
--
-- `set_config(..., true)` est local a la TRANSACTION, pas a l'instruction. Une porte qui posait
-- `rp.recherche_interne = 'on'` le laissait donc pose jusqu'a la fin de la transaction : toute
-- ecriture ULTERIEURE de `recherche` dans la meme transaction franchissait le verrou. En
-- production, chaque requete HTTP est sa propre transaction et le cas ne se presente pas -- mais
-- un laissez-passer dont la portee depasse son ecriture n'est pas un laissez-passer, c'est une
-- porte laissee ouverte.
--
-- LES QUATRE PORTES LE REFERMENT DESORMAIS IMMEDIATEMENT APRES LEUR ECRITURE. La portee du
-- laissez-passer est exactement l'instruction qu'il autorise.
--
-- C'est le banc qui a trouve ce defaut, pas la relecture : l'epreuve « une sauvegarde de fiche
-- n'efface plus l'avis » passait au vert pour la mauvaise raison, et elle est rouge des qu'on la
-- joue APRES un appel de porte dans la meme transaction. Un banc qui ne prouve pas ce qu'il
-- pretend doit etre corrige avant de considerer le defaut ferme -- ici, c'est le code qui l'etait.

DO $$
DECLARE v_def text; v_new text; v_f text;
BEGIN
  -- recherche_inscrire : apres l'UPDATE avec RETURNING.
  SELECT pg_get_functiondef('public.recherche_inscrire(jsonb,text)'::regprocedure) INTO v_def;
  v_new := replace(v_def,
'  RETURNING recherche INTO v_apres;
  IF NOT FOUND THEN',
'  RETURNING recherche INTO v_apres;
  PERFORM set_config(''rp.recherche_interne'', '''', true);   -- la portee s''arrete ici
  IF NOT FOUND THEN');
  IF v_new = v_def THEN RAISE EXCEPTION 'recherche_inscrire : ancrage introuvable'; END IF;
  EXECUTE v_new;

  -- recherche_retirer : apres son UPDATE.
  SELECT pg_get_functiondef('public.recherche_retirer(text[],text,text)'::regprocedure) INTO v_def;
  v_new := replace(v_def,
'  UPDATE public.personnages_donnees SET recherche = v_apres WHERE name = v_cible;',
'  UPDATE public.personnages_donnees SET recherche = v_apres WHERE name = v_cible;
  PERFORM set_config(''rp.recherche_interne'', '''', true);   -- la portee s''arrete ici');
  IF v_new = v_def THEN RAISE EXCEPTION 'recherche_retirer : ancrage introuvable'; END IF;
  EXECUTE v_new;

  -- calomnie_inscrire_mandat : apres son UPDATE sur la vue.
  SELECT pg_get_functiondef(
    'public.calomnie_inscrire_mandat(text,text,text,text,timestamptz)'::regprocedure) INTO v_def;
  v_new := replace(v_def,
'   WHERE name = p_auteur;
  IF NOT FOUND THEN',
'   WHERE name = p_auteur;
  PERFORM set_config(''rp.recherche_interne'', '''', true);   -- la portee s''arrete ici
  IF NOT FOUND THEN');
  IF v_new = v_def THEN RAISE EXCEPTION 'calomnie_inscrire_mandat : ancrage introuvable'; END IF;
  EXECUTE v_new;

  -- militaire_presentation_affectation : apres son UPDATE.
  SELECT pg_get_functiondef('public.militaire_presentation_affectation()'::regprocedure) INTO v_def;
  v_new := replace(v_def,
'     SET requisition = v_req, recherche = v_recherche2
   WHERE name = v_moi;',
'     SET requisition = v_req, recherche = v_recherche2
   WHERE name = v_moi;
  PERFORM set_config(''rp.recherche_interne'', '''', true);   -- la portee s''arrete ici');
  IF v_new = v_def THEN
    RAISE EXCEPTION 'militaire_presentation_affectation : ancrage introuvable'; END IF;
  EXECUTE v_new;
END $$;

DO $$
DECLARE v_n integer; v_f text;
BEGIN
  -- P1 : les QUATRE portes posent le laissez-passer ET le referment. Deux occurrences chacune.
  FOR v_f IN SELECT unnest(ARRAY['recherche_inscrire','recherche_retirer',
                                 'calomnie_inscrire_mandat','militaire_presentation_affectation'])
  LOOP
    SELECT (length(pg_get_functiondef(p.oid))
            - length(replace(pg_get_functiondef(p.oid), 'rp.recherche_interne', ''))) / 20
      INTO v_n
      FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
     WHERE n.nspname='public' AND p.proname = v_f;
    IF v_n <> 2 THEN
      RAISE EXCEPTION 'P1 : %s porte % mention(s) du laissez-passer au lieu de 2', v_f, v_n; END IF;
  END LOOP;

  -- P2 : chacune le referme avec une chaine VIDE, jamais avec 'on'.
  FOR v_f IN SELECT unnest(ARRAY['recherche_inscrire','recherche_retirer',
                                 'calomnie_inscrire_mandat','militaire_presentation_affectation'])
  LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
                    WHERE n.nspname='public' AND p.proname = v_f
                      AND pg_get_functiondef(p.oid)
                          LIKE '%set_config(''rp.recherche_interne'', '''', true)%') THEN
      RAISE EXCEPTION 'P2 : %s ne referme pas son laissez-passer', v_f; END IF;
  END LOOP;

  -- P3 : aucune AUTRE fonction ne touche au laissez-passer.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='public' AND pg_get_functiondef(p.oid) LIKE '%rp.recherche_interne%';
  IF v_n <> 5 THEN
    RAISE EXCEPTION 'P3 : % fonction(s) nomment le laissez-passer au lieu de 5 (4 portes + le declencheur)', v_n;
  END IF;

  RAISE NOTICE 'laissez-passer referme : 3 preuves structurelles conformes.';
END $$;
