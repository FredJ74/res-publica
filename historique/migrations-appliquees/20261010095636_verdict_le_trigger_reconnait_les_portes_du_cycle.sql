-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010095636 (UTC), nom `verdict_le_trigger_reconnait_les_portes_du_cycle`.
-- Le registre passe de 613 a 614 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 9d5db4497d4594ffbef8ef828a147a4f, 6887 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- RECTIFICATION MESUREE DES DEUX MIGRATIONS PRECEDENTES, ET LE DEFAUT QU'ELLES AURAIENT LAISSE
--
-- Le trigger `plaintes_epingler_verdict` restaure sept champs de verdict quand l'ecrivain n'est ni
-- serveur ni l'autorite de la ville : il rectifie l'affirmation fausse de l'en-tete de la 612, il
-- montre que la defense n'a jamais rien inscrit, et il aurait neutralise les deux portes neuves.
-- La reponse est un laissez-passer de transaction, ouvert et REFERME par chaque porte.
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- RECTIFICATION MESUREE DES DEUX MIGRATIONS PRECEDENTES, ET LE DEFAUT QU'ELLES AURAIENT LAISSE
-- Chantier 5, cycle de vie des plaintes (10 octobre 2026).
--
-- CE QUE LE BANC A TROUVE, ET QUE LA RELECTURE N'AVAIT PAS VU. `plaintes_en_cours` porte un
-- trigger BEFORE UPDATE, `plaintes_epingler_verdict`, qui EXISTAIT DEJA : quand l'auteur de
-- l'ecriture n'est ni serveur ni l'autorite judiciaire de la ville, il RESTAURE sept champs tels
-- qu'ils etaient -- `status`, `sentence`, `peine`, `jugement`, `juge`, `circonstanceAttenuante`,
-- `aggravation`. Deux consequences, toutes deux mesurees :
--
--   1. L'EN-TETE DE `affaire_transmettre` SE TROMPE SUR UN POINT, et les faits gagnent. Il dit
--      qu'un client modifie pouvait poser `status = 'jugee'` sur sa propre affaire. C'est FAUX :
--      le trigger le lui reprenait. Le corps archive de cette migration reste celui qui a ete
--      applique -- on ne refait pas l'histoire -- et la rectification est ici.
--
--   2. LE DEFAUT REEL DE LA DEFENSE EST PLUS GRAVE QUE L'AUDIT NE LE DISAIT. `sbSavePlainte` est
--      un UPSERT : sur une affaire existante, c'est un UPDATE, donc le trigger s'appliquait. La
--      defense de l'accuse n'a donc JAMAIS rien inscrit -- ni circonstance attenuante, ni
--      aggravation, ni classement -- a moins que l'accuse ne soit lui-meme le juge ou le
--      commissaire de la ville. Ce n'etait pas « une ecriture parfois perdue » : c'etait une
--      ecriture SYSTEMATIQUEMENT annulee, pour 2 PA et 300 FR, a chaque defense de chaque joueur.
--
-- ET C'EST AUSSI CE QUI AURAIT NEUTRALISE MES DEUX PORTES. `est_appel_serveur()` lit le GUC
-- `role` ; `SECURITY DEFINER` change `current_user`, PAS ce GUC. Depuis `plainte_defendre`
-- appelee par un joueur, le trigger voyait donc toujours « authenticated », et il effacait ce que
-- la porte venait d'ecrire -- tout en rendant `ok: true` et le blob complet a l'appelant. Mesure
-- en transaction annulee, avant ce correctif :
--
--   verdict rendu par la porte : { "ok": true, ..., "circonstanceAttenuante": true }
--   ce qui est reellement stocke : { ... }   <- le champ a disparu
--
-- LA REPONSE EST LE LAISSEZ-PASSER, deja employe deux fois dans ce depot (`rp.caisse_interne`,
-- `rp.recherche_interne`). Le trigger reconnait un drapeau de transaction ; chaque porte l'ouvre
-- juste avant son ecriture et le REFERME juste apres. La fermeture n'est pas une precaution de
-- style : `set_config(..., true)` vaut pour toute la TRANSACTION, et c'est le banc du chantier
-- precedent qui a montre qu'un laissez-passer laisse ouvert laissait ensuite passer une
-- sauvegarde cliente en bloc.

DO $m$
DECLARE v_def text; v_new text; v_cible text;
BEGIN
  -- 1 -- LE TRIGGER RECONNAIT LE LAISSEZ-PASSER, et rien d'autre ne change de son comportement.
  v_def := pg_get_functiondef('public.plaintes_epingler_verdict()'::regprocedure);
  v_cible := 'IF public.est_appel_serveur() THEN RETURN NEW; END IF;';
  v_new := replace(v_def, v_cible,
    v_cible || E'\n  -- LAISSEZ-PASSER DES PORTES DU CYCLE (10 octobre 2026). Deux portes ecrivent des champs de\n'
            || E'  -- verdict pour le compte de quelqu''un qui n''est PAS l''autorite de la ville : la defense de\n'
            || E'  -- l''accuse et le classement du Ministre de la Justice. Elles sont SECURITY DEFINER, mais\n'
            || E'  -- `est_appel_serveur()` lit le GUC `role`, que SECURITY DEFINER ne change pas : sans ce\n'
            || E'  -- drapeau, ce trigger effacait ce qu''elles venaient d''ecrire. Chacune l''ouvre juste avant\n'
            || E'  -- son UPDATE et le referme juste apres -- il ne couvre donc jamais une autre ecriture.\n'
            || E'  IF coalesce(current_setting(''rp.verdict_interne'', true), '''') = ''on'' THEN RETURN NEW; END IF;');
  IF v_new = v_def THEN RAISE EXCEPTION 'le trigger du verdict n''a pas le garde-fou attendu'; END IF;
  EXECUTE v_new;

  -- 2 et 3 -- LES DEUX PORTES DECLARENT LEUR LAISSEZ-PASSER ET LE REFERMENT.
  v_cible := '  UPDATE public.plaintes_en_cours SET data = v_data::text WHERE id = p_affaire_id;';
  FOREACH v_def IN ARRAY ARRAY[
      pg_get_functiondef('public.plainte_defendre(text,text)'::regprocedure),
      pg_get_functiondef('public.plainte_classer_ministere(text)'::regprocedure)]
  LOOP
    v_new := replace(v_def, v_cible,
      E'  -- Le laissez-passer ne dure que cette ecriture (voir le trigger `plaintes_epingler_verdict`).\n'
      || E'  PERFORM set_config(''rp.verdict_interne'', ''on'', true);\n'
      || v_cible || E'\n'
      || E'  PERFORM set_config(''rp.verdict_interne'', '''', true);');
    IF v_new = v_def THEN RAISE EXCEPTION 'une porte du cycle n''a pas l''ecriture attendue'; END IF;
    EXECUTE v_new;
  END LOOP;
END $m$;

-- PREUVES STRUCTURELLES : qui nomme le drapeau, et combien de fois.
DO $p$
DECLARE v integer; v_def text;
BEGIN
  v_def := pg_get_functiondef('public.plaintes_epingler_verdict()'::regprocedure);
  IF (length(v_def) - length(replace(v_def, 'rp.verdict_interne', ''))) / length('rp.verdict_interne') <> 1 THEN
    RAISE EXCEPTION 'le trigger ne nomme pas le laissez-passer exactement une fois';
  END IF;
  -- Le garde-fou doit etre AVANT la restauration des champs, sinon il ne sert a rien.
  IF position('rp.verdict_interne' in v_def) > position('FOREACH v_cle IN ARRAY v_verdict' in v_def) THEN
    RAISE EXCEPTION 'le laissez-passer est teste APRES la restauration des champs de verdict';
  END IF;

  FOR v_def IN
    SELECT pg_get_functiondef(p.oid) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.proname IN ('plainte_defendre', 'plainte_classer_ministere')
  LOOP
    -- EXACTEMENT DEUX MENTIONS PAR PORTE : l'ouverture et la fermeture.
    v := (length(v_def) - length(replace(v_def, 'rp.verdict_interne', ''))) / length('rp.verdict_interne');
    IF v <> 2 THEN RAISE EXCEPTION 'une porte nomme le laissez-passer % fois au lieu de 2', v; END IF;
    IF position('set_config(''rp.verdict_interne'', ''on'', true)' in v_def)
       > position('UPDATE public.plaintes_en_cours' in v_def) THEN
      RAISE EXCEPTION 'une porte ouvre son laissez-passer APRES son ecriture';
    END IF;
    IF position('set_config(''rp.verdict_interne'', '''', true)' in v_def)
       < position('UPDATE public.plaintes_en_cours' in v_def) THEN
      RAISE EXCEPTION 'une porte referme son laissez-passer AVANT son ecriture';
    END IF;
  END LOOP;

  -- AUCUNE AUTRE FONCTION NE CONNAIT CE DRAPEAU : trois, et seulement trois.
  SELECT count(*) INTO v FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND pg_get_functiondef(p.oid) LIKE '%rp.verdict_interne%';
  IF v <> 3 THEN RAISE EXCEPTION '% fonctions nomment rp.verdict_interne, attendu 3', v; END IF;

  RAISE NOTICE 'Les 6 preuves structurelles du laissez-passer du verdict sont vertes.';
END $p$;
