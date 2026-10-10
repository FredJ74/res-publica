-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010123910 (UTC), nom `terrain_chaque_acte_declare_ses_cles`.
-- Le registre passe de 619 a 620 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 e4a0862e82a389b49205952590173b41, 4755 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- CHAQUE ACTE DECLARE SES CLES -- LA PORTE DU COMPROMIS REJOINT LA REGLE GENERALE
--
-- `terrain_permis_acte` refuse tout patch qui nomme une cle de premier niveau etrangere a l'acte
-- demande. `terrain_compromis_acte`, ecrite avant cette regle, forcait bien les quatre champs
-- d'identite mais acceptait n'importe quelle autre cle a cote : un client modifie pouvait, en
-- signant un compromis, poser au passage un `chantier` ou un `subdivisions` de son choix. Elle
-- rejoint la regle ici, par patch en place, avec les cles relevees sur les six chemins du
-- navigateur -- et le garde-fou est teste avant la lecture verrouillee du terrain.
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- CHAQUE ACTE DECLARE SES CLES -- la porte du compromis rejoint la regle generale
-- Chantier 5, les 19 `sbSetTerrainState` (10 octobre 2026).
--
-- POURQUOI CE COMPLEMENT. `terrain_permis_acte` a ete ecrite avec une LISTE DE CLES par acte : la
-- porte refuse tout patch qui nomme une cle de premier niveau etrangere a l'acte demande. Ce
-- garde-fou n'est pas une regle de jeu -- c'est la constatation que « signer un compromis » n'a
-- jamais eu a reecrire un chantier, un decoupage en lots ou un permis deja decide. Il ferme d'un
-- coup l'ecrasement par cache perime, pour tous les actes d'un mecanisme.
--
-- `terrain_compromis_acte`, ecrite avant cette regle, forcait bien les quatre champs d'IDENTITE
-- (`compromisPar`, `transfertProposePar`, `achatDirect.demandeur`) mais acceptait n'importe quelle
-- autre cle a cote. Un client modifie pouvait donc, en signant un compromis, poser au passage un
-- `chantier` ou un `subdivisions` de son choix. Elle rejoint la regle ici, par patch en place --
-- on ne retape pas son corps.
--
-- LES CLES PAR ACTE sont exactement celles que les six chemins du navigateur ecrivent, relevees
-- dans plateau-pnj.js et plateau-justice-economie.js, et rien de plus.

DO $m$
DECLARE v_def text; v_new text; v_ancre text;
BEGIN
  v_def := pg_get_functiondef('public.terrain_compromis_acte(text,text,jsonb)'::regprocedure);
  v_ancre := '  SELECT d.country INTO v_pays FROM public.personnages_donnees d WHERE d.name = v_moi LIMIT 1;';
  v_new := replace(v_def, v_ancre,
    v_ancre || E'\n'
    || E'\n  -- LISTE DE CLES PAR ACTE (10 octobre 2026). Meme regle que `terrain_permis_acte` : un acte\n'
    || E'  -- ne touche que les cles qu''il declare. Relevees sur les six chemins du navigateur.\n'
    || E'  v_cles := CASE p_acte\n'
    || E'    WHEN ''compromis_signer'' THEN ARRAY[''compromis'', ''compromisPar'', ''acompte'',\n'
    || E'                                        ''compromisAt'', ''compromisExpireAt'', ''pretDemande'', ''permis'']\n'
    || E'    WHEN ''compromis_pret_demander'' THEN ARRAY[''pretDemande'']\n'
    || E'    WHEN ''compromis_transfert_proposer'' THEN ARRAY[''transfertPropose'', ''transfertProposePar'']\n'
    || E'    WHEN ''compromis_transfert_accepter'' THEN ARRAY[''compromisPar'', ''transfertPropose'',\n'
    || E'                                        ''transfertProposePar'', ''permis'', ''pretDemande'']\n'
    || E'    ELSE ARRAY[''achatDirect''] END;\n'
    || E'  FOR v_k IN SELECT jsonb_object_keys(p_patch) LOOP\n'
    || E'    IF NOT (v_k = ANY (v_cles)) THEN\n'
    || E'      RETURN jsonb_build_object(''ok'', false, ''raison'', ''cle_hors_acte'', ''cle'', v_k);\n'
    || E'    END IF;\n'
    || E'  END LOOP;');
  IF v_new = v_def THEN RAISE EXCEPTION 'l''ancre de la porte du compromis est introuvable'; END IF;
  -- Les deux variables de travail du garde-fou.
  v_new := replace(v_new,
    'DECLARE v_moi text; v_pays text; v_lu jsonb; v_etat jsonb; v_patch jsonb; v_final jsonb;',
    'DECLARE v_moi text; v_pays text; v_lu jsonb; v_etat jsonb; v_patch jsonb; v_final jsonb;'
    || E'\n  v_cles text[]; v_k text;');
  IF v_new NOT LIKE '%v_cles text[]; v_k text;%' THEN
    RAISE EXCEPTION 'la declaration des variables du garde-fou n''a pas pu etre posee';
  END IF;
  EXECUTE v_new;
END $m$;

DO $p$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('public.terrain_compromis_acte(text,text,jsonb)'::regprocedure);
  IF v_def NOT LIKE '%cle_hors_acte%' THEN
    RAISE EXCEPTION 'la porte du compromis accepte encore un patch qui depasse son acte';
  END IF;
  -- LE GARDE-FOU EST AVANT TOUTE DECISION : il precede la lecture verrouillee du terrain.
  IF position('cle_hors_acte' in v_def) > position('terrain_etat_verrouiller_interne' in v_def) THEN
    RAISE EXCEPTION 'le garde-fou des cles est teste APRES la lecture du terrain';
  END IF;
  -- ET LES QUATRE CHAMPS D'IDENTITE SONT TOUJOURS FORCES : le patch en place n'a rien casse.
  IF v_def NOT LIKE '%''compromisPar'', v_moi%' OR v_def NOT LIKE '%''transfertProposePar'', v_moi%'
     OR v_def NOT LIKE '%{achatDirect,demandeur}%' OR v_def NOT LIKE '%transfert_non_propose%' THEN
    RAISE EXCEPTION 'le patch en place a efface une garde d''identite de la porte du compromis';
  END IF;
  -- LES DEUX PORTES A PATCH PARTAGENT DESORMAIS LA MEME REGLE.
  IF (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
       WHERE n.nspname = 'public' AND p.proname IN ('terrain_compromis_acte', 'terrain_permis_acte')
         AND pg_get_functiondef(p.oid) LIKE '%cle_hors_acte%') <> 2 THEN
    RAISE EXCEPTION 'les deux portes a patch ne partagent pas la regle des cles';
  END IF;
  RAISE NOTICE 'Les 4 preuves structurelles de la liste de cles sont vertes.';
END $p$;
