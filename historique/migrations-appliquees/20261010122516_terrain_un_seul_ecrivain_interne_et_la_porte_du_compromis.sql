-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010122516 (UTC), nom `terrain_un_seul_ecrivain_interne_et_la_porte_du_compromis`.
-- Le registre passe de 614 a 615 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 05bec1a59c949b6d61e15da94bbadf39, 12905 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- L'ETAT D'UN TERRAIN A UN SEUL ECRIVAIN, ET DES PORTES D'AUTORITE
--
-- Chantier 5, lot 1/4 des 19 `sbSetTerrainState` avales : le socle et le compromis. Deux
-- primitives internes injoignables depuis le reseau -- verrouiller puis fusionner le patch sur
-- l'etat relu sous verrou -- et une premiere porte, `terrain_compromis_acte`, qui porte six actes
-- en liste close. Les droits clients d'ecriture ne sont PAS retires : la revocation suit le
-- deploiement, et une preuve constate expressement qu'ils sont encore la.
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- L'ETAT D'UN TERRAIN A UN SEUL ECRIVAIN, ET DES PORTES D'AUTORITE
-- Chantier 5, les 19 `sbSetTerrainState` avales (10 octobre 2026). 1/4 : le socle et le compromis.
--
-- CE QUE L'INSPECTION A MESURE, avant toute correction.
--
--   1. `sbSetTerrainState` ecrit `data` EN ENTIER, depuis le cache du navigateur. Vingt-deux sites
--      l'appellent ; DIX-NEUF avalent son resultat par un `.catch()` muet. Trois familles de
--      defauts en decoulent, toutes constatees : un patch partiel efface le reste de l'etat, un
--      cache perime ecrase ce que le serveur a arrete, et deux joueurs qui agissent sur le meme
--      terrain se detruisent mutuellement -- `subdivisions`, `permis`, `chantier` et `compromis`
--      vivent dans le MEME blob.
--
--   2. ET LA TABLE EST OUVERTE A TOUS. La policy d'UPDATE de `terrains_etat` est
--      `acteur_identifie()` : TOUT joueur connecte peut reecrire l'etat entier de N'IMPORTE QUEL
--      terrain du jeu -- proprietaire, detenteur du compromis, permis, lots, locataires. Aucune
--      des dix-neuf ecritures ne verifiait quoi que ce soit en base.
--
--   3. L'EXEMPLE LE PLUS NET est `doAccepterTransfertCompromis` : il pose `compromisPar` a son
--      propre nom sans jamais verifier que le transfert LUI a ete propose. Seul l'ecran filtrait.
--
-- L'ARCHITECTURE. Un seul ecrivain interne, injoignable depuis le reseau, et une porte par
-- MECANISME -- pas dix-neuf rustines. Le socle est pose ici : `terrain_etat_verrouiller_interne`
-- prend le verrou de ligne et rend l'etat REEL, `terrain_etat_fusionner_interne` fusionne le patch
-- sur cet etat et tient la colonne `proprietaire`. Entre les deux, chaque porte applique la regle
-- d'autorite de SON acte -- celle qui existait deja dans l'ecran ou dans l'ordre, lue en base et
-- non reinventee. Le verrou etant tenu pour toute la transaction, decider puis ecrire est atomique.
--
-- CE QUI N'EST PAS FAIT ICI, ET POURQUOI. Les droits clients (`INSERT`/`UPDATE` de
-- `terrains_etat` pour `authenticated`) NE SONT PAS RETIRES. Le precedent du depot est explicite
-- (registre 584) : on ne retire une surface d'ecriture qu'APRES avoir prouve octet par octet que
-- le code deploye est celui qui n'en a plus besoin. Le code de ce lot n'est pas encore deploye.
-- La revocation est donc la premiere action du lot suivant, et elle est consignee comme telle.

-- LE VERROU ET LA LECTURE REELLE. Rend `trouve` a false quand le terrain n'a pas encore de ligne
-- -- c'est un cas normal : `sbSetTerrainState` etait un upsert, et un terrain vierge n'existe en
-- base qu'a sa premiere ecriture.
CREATE OR REPLACE FUNCTION public.terrain_etat_verrouiller_interne(p_terrain_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp' AS $fn$
DECLARE v_cle text; v_data jsonb;
BEGIN
  SELECT t.id, coalesce(t.data::jsonb, '{}'::jsonb) INTO v_cle, v_data
    FROM public.terrains_etat t
   WHERE t.id = p_terrain_id OR t.building_id = p_terrain_id
   ORDER BY (t.id = p_terrain_id) DESC LIMIT 1
     FOR UPDATE;
  IF v_cle IS NULL THEN
    RETURN jsonb_build_object('trouve', false, 'etat', '{}'::jsonb, 'gele', false);
  END IF;
  RETURN jsonb_build_object('trouve', true, 'cle', v_cle, 'etat', v_data,
    'gele', coalesce(v_data ->> 'succession_gel', '') <> '');
END; $fn$;

-- L'UNIQUE ECRITURE. Elle fusionne sur l'etat relu sous verrou, jamais sur un cache, et tient la
-- colonne `proprietaire` -- qui est l'index de `sbGetTerrainsPossedesPar`, donc du revenu passif.
CREATE OR REPLACE FUNCTION public.terrain_etat_fusionner_interne(
  p_terrain_id text, p_patch jsonb, p_pays text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp' AS $fn$
DECLARE v_cle text; v_data jsonb; v_pays text; v_bat text;
BEGIN
  SELECT t.id, coalesce(t.data::jsonb, '{}'::jsonb), t.country, t.building_id
    INTO v_cle, v_data, v_pays, v_bat
    FROM public.terrains_etat t
   WHERE t.id = p_terrain_id OR t.building_id = p_terrain_id
   ORDER BY (t.id = p_terrain_id) DESC LIMIT 1
     FOR UPDATE;

  IF v_cle IS NULL THEN
    -- PREMIERE ECRITURE SUR UN TERRAIN VIERGE. La cle est celle que `sbSetTerrainState` composait
    -- deja : pays + '_' + batiment. Le pays vient de l'appelant serveur, jamais du navigateur.
    v_pays := coalesce(p_pays, 'republic');
    v_bat := p_terrain_id;
    v_cle := v_pays || '_' || v_bat;
    v_data := coalesce(p_patch, '{}'::jsonb);
    INSERT INTO public.terrains_etat (id, country, building_id, proprietaire, data, updated_at)
    VALUES (v_cle, v_pays, v_bat, nullif(v_data ->> 'proprietaire', ''), v_data::text, now())
    ON CONFLICT (id) DO NOTHING;
    RETURN v_data;
  END IF;

  v_data := v_data || coalesce(p_patch, '{}'::jsonb);
  UPDATE public.terrains_etat
     SET data = v_data::text, proprietaire = nullif(v_data ->> 'proprietaire', ''), updated_at = now()
   WHERE id = v_cle;
  RETURN v_data;
END; $fn$;

-- LES DEUX PRIMITIVES SONT INJOIGNABLES DEPUIS LE RESEAU : seules les portes les appellent, et
-- elles le font en SECURITY DEFINER.
REVOKE ALL ON FUNCTION public.terrain_etat_verrouiller_interne(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.terrain_etat_fusionner_interne(text, jsonb, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.terrain_etat_verrouiller_interne(text) FROM anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.terrain_etat_fusionner_interne(text, jsonb, text) FROM anon, authenticated, service_role;

-- LA PORTE DU COMPROMIS ET DE L'ACHAT DIRECT -- six actes, liste close.
CREATE OR REPLACE FUNCTION public.terrain_compromis_acte(
  p_terrain_id text, p_acte text, p_patch jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp' AS $fn$
DECLARE v_moi text; v_pays text; v_lu jsonb; v_etat jsonb; v_patch jsonb; v_final jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_acte NOT IN ('compromis_signer', 'compromis_pret_demander', 'compromis_transfert_proposer',
                    'compromis_transfert_accepter', 'achat_direct_deposer', 'achat_direct_accelerer') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acte_inconnu');
  END IF;
  IF p_patch IS NULL OR jsonb_typeof(p_patch) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'patch_invalide');
  END IF;
  SELECT d.country INTO v_pays FROM public.personnages_donnees d WHERE d.name = v_moi LIMIT 1;

  v_lu := public.terrain_etat_verrouiller_interne(p_terrain_id);
  v_etat := v_lu -> 'etat';
  -- LE GEL SUCCESSORAL EST LA MEME REGLE QUE DANS `terrain_proprietaire_muter`, lue en base.
  IF (v_lu ->> 'gele')::boolean THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'terrain_gele');
  END IF;
  v_patch := p_patch;

  IF p_acte = 'compromis_signer' THEN
    -- LA REGLE EXISTAIT DEJA, cote serveur, pour le jumeau Helvetia : `signer_compromis_bien_helvetia`
    -- refuse « bien deja sous compromis ». Le chemin ordinaire ne la verifiait que dans l'ecran.
    IF coalesce((v_etat ->> 'compromis')::boolean, false)
       AND (v_etat ->> 'compromisPar') IS DISTINCT FROM v_moi THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'deja_sous_compromis',
                                'detenteur', v_etat ->> 'compromisPar');
    END IF;
    -- LE DETENTEUR N'EST PLUS DICTE PAR LE NAVIGATEUR.
    v_patch := v_patch || jsonb_build_object('compromis', true, 'compromisPar', v_moi);

  ELSIF p_acte IN ('compromis_pret_demander', 'compromis_transfert_proposer') THEN
    IF coalesce((v_etat ->> 'compromis')::boolean, false) IS NOT TRUE
       OR (v_etat ->> 'compromisPar') IS DISTINCT FROM v_moi THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_compromis');
    END IF;
    IF p_acte = 'compromis_transfert_proposer' THEN
      IF nullif(btrim(coalesce(v_patch ->> 'transfertPropose', '')), '') IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_absent');
      END IF;
      IF (v_patch ->> 'transfertPropose') = v_moi THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'transfert_a_soi_meme');
      END IF;
      v_patch := v_patch || jsonb_build_object('transfertProposePar', v_moi);
    END IF;

  ELSIF p_acte = 'compromis_transfert_accepter' THEN
    -- LA REGLE QUI N'EXISTAIT QUE DANS L'ECRAN. Sans elle, n'importe quel joueur connecte posait
    -- son nom dans `compromisPar` et reprenait le compromis d'un autre.
    IF (v_etat ->> 'transfertPropose') IS DISTINCT FROM v_moi THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'transfert_non_propose');
    END IF;
    v_patch := v_patch || jsonb_build_object('compromisPar', v_moi,
      'transfertPropose', NULL, 'transfertProposePar', NULL);

  ELSIF p_acte = 'achat_direct_deposer' THEN
    IF coalesce((v_etat ->> 'compromis')::boolean, false)
       OR ((v_etat -> 'achatDirect') IS NOT NULL
           AND (v_etat -> 'achatDirect' ->> 'demandeur') IS DISTINCT FROM v_moi) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'terrain_indisponible');
    END IF;
    IF jsonb_typeof(v_patch -> 'achatDirect') <> 'object' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'achat_direct_absent');
    END IF;
    v_patch := jsonb_set(v_patch, '{achatDirect,demandeur}', to_jsonb(v_moi));

  ELSIF p_acte = 'achat_direct_accelerer' THEN
    -- REGLE RECOPIEE MOT POUR MOT DU CLIENT :
    --   if (!ts.achatDirect || ts.achatDirect.demandeur !== state.char?.name)
    IF (v_etat -> 'achatDirect') IS NULL
       OR (v_etat -> 'achatDirect' ->> 'demandeur') IS DISTINCT FROM v_moi THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_achat_direct');
    END IF;
    v_patch := jsonb_set(v_patch, '{achatDirect,demandeur}', to_jsonb(v_moi));
  END IF;

  v_final := public.terrain_etat_fusionner_interne(p_terrain_id, v_patch, v_pays);
  RETURN jsonb_build_object('ok', true, 'acte', p_acte, 'etat', v_final);
END; $fn$;

REVOKE ALL ON FUNCTION public.terrain_compromis_acte(text, text, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.terrain_compromis_acte(text, text, jsonb) TO authenticated, service_role;

-- PREUVES STRUCTURELLES.
DO $p$
DECLARE v integer; v_def text;
BEGIN
  SELECT count(*) INTO v FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('terrain_etat_verrouiller_interne', 'terrain_etat_fusionner_interne')
     AND (has_function_privilege('anon', p.oid, 'EXECUTE')
          OR has_function_privilege('authenticated', p.oid, 'EXECUTE')
          OR has_function_privilege('service_role', p.oid, 'EXECUTE'));
  IF v <> 0 THEN RAISE EXCEPTION '% primitive(s) interne(s) joignable(s) depuis le reseau', v; END IF;

  IF NOT has_function_privilege('authenticated',
        'public.terrain_compromis_acte(text,text,jsonb)'::regprocedure, 'EXECUTE') THEN
    RAISE EXCEPTION 'un joueur ne peut pas appeler la porte du compromis';
  END IF;
  IF has_function_privilege('anon',
        'public.terrain_compromis_acte(text,text,jsonb)'::regprocedure, 'EXECUTE') THEN
    RAISE EXCEPTION 'anon peut appeler la porte du compromis';
  END IF;

  v_def := pg_get_functiondef('public.terrain_etat_verrouiller_interne(text)'::regprocedure);
  IF v_def NOT LIKE '%FOR UPDATE%' THEN RAISE EXCEPTION 'la lecture interne ne verrouille pas'; END IF;
  v_def := pg_get_functiondef('public.terrain_etat_fusionner_interne(text,jsonb,text)'::regprocedure);
  IF v_def NOT LIKE '%FOR UPDATE%' OR v_def NOT LIKE '%v_data || coalesce(p_patch%' THEN
    RAISE EXCEPTION 'l''ecriture interne n''est pas une fusion sous verrou';
  END IF;

  -- LA PORTE NE DICTE JAMAIS L'IDENTITE : les quatre champs d'identite sont forces au serveur.
  v_def := pg_get_functiondef('public.terrain_compromis_acte(text,text,jsonb)'::regprocedure);
  IF v_def NOT LIKE '%''compromisPar'', v_moi%' OR v_def NOT LIKE '%''transfertProposePar'', v_moi%'
     OR v_def NOT LIKE '%{achatDirect,demandeur}%' THEN
    RAISE EXCEPTION 'la porte du compromis laisse le client nommer un detenteur';
  END IF;
  IF v_def NOT LIKE '%transfert_non_propose%' THEN
    RAISE EXCEPTION 'la porte accepte un transfert qui ne lui a pas ete propose';
  END IF;

  -- LA TABLE RESTE OUVERTE AUX CLIENTS, ET C'EST ASSUME : la revocation suit le deploiement.
  -- Cette preuve CONSTATE l'etat, pour qu'il ne soit jamais oublie ni presente autrement.
  IF NOT EXISTS (SELECT 1 FROM information_schema.role_table_grants
                  WHERE table_schema = 'public' AND table_name = 'terrains_etat'
                    AND grantee = 'authenticated' AND privilege_type = 'UPDATE') THEN
    RAISE EXCEPTION 'le droit client d''UPDATE a disparu sans que ce lot ne l''ait retire : verifier';
  END IF;

  RAISE NOTICE 'Les 8 preuves structurelles du socle des terrains sont vertes.';
END $p$;
