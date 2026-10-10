-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010122711 (UTC), nom `terrain_la_porte_du_permis_et_sa_liste_de_cles`.
-- Le registre passe de 615 a 616 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 1baf3f69595affdd3c0485b3a5b6239c, 9153 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- L'ETAT D'UN TERRAIN -- 2/4 : LE CYCLE DE VIE DU PERMIS
--
-- Quatre des dix-neuf `sbSetTerrainState` avales sont dans ce mecanisme, et trois envoyaient
-- l'etat ENTIER depuis le cache. La porte `terrain_permis_acte` porte cinq actes, et chacun
-- declare la LISTE DE CLES qu'il a le droit de toucher : tout patch qui en nomme une autre est
-- refuse. L'autorite de la decision est le portefeuille `maire_adjoint` declare par `data.js` ;
-- la ville d'un terrain manquant parfois du blob, la lacune est consignee et non comblee en douce.
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- L'ETAT D'UN TERRAIN -- 2/4 : LE CYCLE DE VIE DU PERMIS
-- Chantier 5, les 19 `sbSetTerrainState` avales (10 octobre 2026).
--
-- QUATRE DES DIX-NEUF ECRITURES SONT DANS CE MECANISME, et trois d'entre elles envoyaient
-- `ts` ou `etat` ENTIER -- l'objet du cache du navigateur, pas un patch. C'est la forme la plus
-- pure du defaut : le cron de minuit avance l'instruction (`joursInstructionFaits`) et le chantier
-- (`progressionJours`) dans la MEME ligne ; un joueur qui decidait un permis depuis un ecran
-- ouvert depuis dix minutes REVENAIT la nuit en arriere.
--
-- D'OU LA LISTE DE CLES. Chaque acte declare les cles de premier niveau qu'il a le droit de
-- toucher, et la porte refuse tout patch qui en nomme une autre. Ce n'est pas une regle de jeu --
-- c'est la constatation que « decider un permis » n'a jamais eu a reecrire un chantier, un
-- decoupage en lots ni un compromis. Le garde-fou est generique : il ferme d'un coup l'ecrasement
-- par cache perime pour tous les actes du mecanisme.
--
-- L'AUTORITE DE LA DECISION EST CELLE QUE `data.js` DECLARE, mot pour mot :
--   { fn: 'traiter_demandes_permis', requiresPost: 'maire_adjoint',
--     desc: '... dans cette ville uniquement.' }
-- Elle n'etait verifiee que par l'ordre, cote navigateur. `traiterPermis` lui-meme ne verifiait
-- rien : n'importe quel joueur connecte pouvait valider ou refuser n'importe quel permis du jeu.
--
-- UNE LACUNE DU MODELE DE DONNEES EST CONSIGNEE ICI, pas comblee en douce : la ville d'un terrain
-- n'est pas une colonne de `terrains_etat`, elle vit dans le blob (`data.city`) et MANQUE sur une
-- ligne de la beta sur cinq. Quand elle manque, la juridiction de ville n'est pas opposable : la
-- porte exige alors le portefeuille et le PAYS, et le dit dans son verdict (`ville_inconnue`).
-- Refuser serait rendre ces permis indecidables a jamais.

CREATE OR REPLACE FUNCTION public.terrain_permis_acte(
  p_terrain_id text, p_acte text, p_patch jsonb DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp' AS $fn$
DECLARE
  v_moi text; v_pays text; v_poste text; v_poste_ville text;
  v_lu jsonb; v_etat jsonb; v_patch jsonb; v_final jsonb; v_permis jsonb;
  v_ville text; v_ville_inconnue boolean := false; v_cles text[]; v_k text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_acte NOT IN ('permis_deposer', 'permis_prevenir_maire', 'permis_decider',
                    'permis_accelerer', 'permis_plan_modifier') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acte_inconnu');
  END IF;
  v_patch := coalesce(p_patch, '{}'::jsonb);
  IF jsonb_typeof(v_patch) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'patch_invalide');
  END IF;

  -- LISTE DE CLES PAR ACTE. Seule la decision touche `constructionAutorisee` ; aucun acte de ce
  -- mecanisme ne touche `chantier`, `subdivisions`, `proprietaire` ni le compromis.
  v_cles := CASE WHEN p_acte = 'permis_decider' THEN ARRAY['permis', 'constructionAutorisee']
                 ELSE ARRAY['permis'] END;
  FOR v_k IN SELECT jsonb_object_keys(v_patch) LOOP
    IF NOT (v_k = ANY (v_cles)) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cle_hors_acte', 'cle', v_k);
    END IF;
  END LOOP;

  SELECT a.nom, a.poste_id, a.poste_city, a.pays
    INTO v_moi, v_poste, v_poste_ville, v_pays FROM public.acteur_poste_courant() a;

  v_lu := public.terrain_etat_verrouiller_interne(p_terrain_id);
  v_etat := v_lu -> 'etat';
  IF (v_lu ->> 'gele')::boolean THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'terrain_gele');
  END IF;
  v_permis := v_etat -> 'permis';
  v_ville := nullif(btrim(coalesce(v_etat ->> 'city', '')), '');
  v_ville_inconnue := (v_ville IS NULL);

  IF p_acte = 'permis_deposer' THEN
    IF jsonb_typeof(v_patch -> 'permis') <> 'object' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'permis_absent');
    END IF;
    -- LE DEMANDEUR N'EST PLUS DICTE PAR LE NAVIGATEUR.
    v_patch := jsonb_set(v_patch, '{permis,demandeur}', to_jsonb(v_moi));

  ELSIF p_acte = 'permis_prevenir_maire' THEN
    -- ACTE PASSIF : il se declenche a l'entree dans la piece, pour N'IMPORTE QUEL joueur. Il n'a
    -- donc aucune autorite a verifier -- mais il ne doit poser QUE ce drapeau, et la porte le pose
    -- elle-meme plutot que de recopier un patch. Les trois conditions sont celles du client :
    --   if (!instructionAchevee(ts.permis) || ts.permis.mairePrevenu) return;
    IF v_permis IS NULL OR (v_permis ->> 'statut') IS DISTINCT FROM 'instruction'
       OR coalesce((v_permis ->> 'dureeInstruction')::numeric, 0) <= 0
       OR coalesce((v_permis ->> 'joursInstructionFaits')::numeric, 0)
          < coalesce((v_permis ->> 'dureeInstruction')::numeric, 0)
       OR coalesce((v_permis ->> 'mairePrevenu')::boolean, false) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'rien_a_signaler');
    END IF;
    v_patch := jsonb_build_object('permis', v_permis || '{"mairePrevenu": true}'::jsonb);

  ELSIF p_acte = 'permis_decider' THEN
    IF v_poste IS DISTINCT FROM 'maire_adjoint' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'autorite_refusee');
    END IF;
    IF NOT v_ville_inconnue AND v_poste_ville IS DISTINCT FROM v_ville THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction',
                                'ville_terrain', v_ville, 'ville_poste', v_poste_ville);
    END IF;
    -- LA MEME REGLE QUE `verdictDecisionPermis` : un dossier deja tranche ne se retranche pas.
    IF v_permis IS NULL OR (v_permis ->> 'statut') IS DISTINCT FROM 'instruction' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'dossier_deja_decide',
                                'statut', v_permis ->> 'statut');
    END IF;
    IF (v_patch -> 'permis' ->> 'statut') NOT IN ('valide', 'refuse') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'decision_invalide');
    END IF;
    IF (v_patch -> 'permis' ->> 'statut') = 'refuse'
       AND length(btrim(coalesce(v_patch -> 'permis' ->> 'motifRefus', ''))) < 10 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'motif_requis');
    END IF;

  ELSIF p_acte = 'permis_accelerer' THEN
    -- REGLE RECOPIEE DU CLIENT : if (!ts.permis || ts.permis.statut !== 'instruction')
    IF v_permis IS NULL OR (v_permis ->> 'statut') IS DISTINCT FROM 'instruction' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'aucune_instruction');
    END IF;

  ELSIF p_acte = 'permis_plan_modifier' THEN
    -- PREMIERE REGLE DE `verdictOuvertureModificationPlan`, et la seule qui soit une AUTORITE :
    --   if (!estTitulaire(ts && ts.proprietaire)) return { ok:false, ... }
    -- Les autres (chantier present, deux tiers non franchis, palier divisible, surface connue)
    -- restent au verdict unique du client : les porter ici en ferait une SECONDE version.
    IF nullif(v_etat ->> 'proprietaire', '') IS DISTINCT FROM v_moi THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire');
    END IF;
    IF v_permis IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'aucun_permis');
    END IF;
  END IF;

  v_final := public.terrain_etat_fusionner_interne(p_terrain_id, v_patch, v_pays);
  RETURN jsonb_build_object('ok', true, 'acte', p_acte, 'etat', v_final,
                            'ville_inconnue', v_ville_inconnue);
END; $fn$;

REVOKE ALL ON FUNCTION public.terrain_permis_acte(text, text, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.terrain_permis_acte(text, text, jsonb) TO authenticated, service_role;

DO $p$
DECLARE v_def text;
BEGIN
  IF NOT has_function_privilege('authenticated',
        'public.terrain_permis_acte(text,text,jsonb)'::regprocedure, 'EXECUTE')
     OR has_function_privilege('anon',
        'public.terrain_permis_acte(text,text,jsonb)'::regprocedure, 'EXECUTE') THEN
    RAISE EXCEPTION 'les droits de la porte du permis sont faux';
  END IF;
  v_def := pg_get_functiondef('public.terrain_permis_acte(text,text,jsonb)'::regprocedure);
  IF v_def NOT LIKE '%cle_hors_acte%' THEN
    RAISE EXCEPTION 'la porte du permis accepte un patch qui depasse son acte';
  END IF;
  IF v_def NOT LIKE '%v_poste IS DISTINCT FROM ''maire_adjoint''%' THEN
    RAISE EXCEPTION 'la decision du permis ne verifie pas le portefeuille declare par data.js';
  END IF;
  IF v_def NOT LIKE '%{permis,demandeur}%' THEN
    RAISE EXCEPTION 'le depot laisse le client nommer le demandeur';
  END IF;
  IF v_def NOT LIKE '%terrain_etat_verrouiller_interne%'
     OR v_def NOT LIKE '%terrain_etat_fusionner_interne%' THEN
    RAISE EXCEPTION 'la porte du permis n''utilise pas l''ecrivain unique';
  END IF;
  -- AUCUNE AUTRE ECRITURE DE `terrains_etat` DANS CETTE PORTE : elle passe par l'ecrivain.
  IF v_def LIKE '%UPDATE public.terrains_etat%' OR v_def LIKE '%INSERT INTO public.terrains_etat%' THEN
    RAISE EXCEPTION 'la porte du permis ecrit la table directement';
  END IF;
  RAISE NOTICE 'Les 6 preuves structurelles de la porte du permis sont vertes.';
END $p$;
