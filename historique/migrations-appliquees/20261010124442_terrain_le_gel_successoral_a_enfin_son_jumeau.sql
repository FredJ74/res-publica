-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010124442 (UTC), nom `terrain_le_gel_successoral_a_enfin_son_jumeau`.
-- Le registre passe de 620 a 621 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 2858294863b12a405bc668c94ee91469, 8750 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- LE GEL SUCCESSORAL D'UN TERRAIN A ENFIN LE JUMEAU QUE L'ENTREPRISE AVAIT DEPUIS LE CHANTIER C
--
-- Dans `ouvrirSuccession`, l'entreprise passait par `entreprise_succession_geler` mais le terrain
-- ecrivait encore le blob entier depuis le cache : le defaut corrige sur l'entreprise au chantier C
-- restait ouvert sur le terrain, et n'importe quel joueur connecte pouvait geler n'importe quel
-- terrain du jeu -- donc paralyser compromis, permis, chantier et decoupage. Deux portes jumelles
-- exactes des fonctions d'entreprise (succession en attente, actif du defunt, idempotence), qui
-- passent volontairement par l'ecrivain interne et non par la lecture qui refuse le gel.
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- LE GEL SUCCESSORAL D'UN TERRAIN A ENFIN LE JUMEAU QUE L'ENTREPRISE AVAIT DEPUIS LE CHANTIER C
-- Chantier 5, les dernieres ecritures clientes de `terrains_etat` (10 octobre 2026).
--
-- CE QUE L'INSPECTION A TROUVE, et c'est le commentaire du depot lui-meme qui le dit. Dans
-- `ouvrirSuccession` (plateau-personnage.js), la boucle de gel traite deux familles d'actifs :
--
--   * ENTREPRISE -- passe par `entreprise_succession_geler`, et son en-tete explique pourquoi :
--     « le gel etait pose en reecrivant le blob entier, sans aucun controle -- un succession_gel
--     INVENTE suffisait a geler l'entreprise d'autrui » ;
--   * TERRAIN -- fait encore `sbSetTerrainState(country, d.id, { ...ts, succession_gel: ... })`.
--
-- Le defaut corrige sur l'entreprise au chantier C est donc RESTE OUVERT sur le terrain. Et il y
-- est plus grave depuis ce lot : `succession_gel` est la cle que les QUATRE portes des terrains
-- consultent pour refuser toute action. N'importe quel joueur connecte pouvait donc geler
-- n'importe quel terrain du jeu -- la policy d'UPDATE est `acteur_identifie()` -- et paralyser
-- compromis, permis, chantier et decoupage.
--
-- Meme constat pour le NETTOYAGE des engagements du defunt : l'entreprise a
-- `entreprise_succession_annuler_compromis`, le terrain ecrivait `{ ...ts, compromis: null, ... }`
-- depuis le cache.
--
-- CES DEUX PORTES SONT LES JUMELLES EXACTES des deux fonctions d'entreprise : meme exigence d'une
-- ligne `successions` EN ATTENTE, meme verification que l'actif est bien celui du defunt, meme
-- idempotence (reposer le meme gel est un no-op, ce que la reprise apres echec partiel exige).
-- Aucune regle nouvelle : la regle existait, elle ne s'appliquait qu'a la moitie des actifs.
--
-- ELLES N'UTILISENT PAS `terrain_etat_verrouiller_interne` : cette lecture refuse les terrains
-- geles, et ces deux portes sont precisement celles qui POSENT et qui LEVENT ce gel. Elles
-- passent donc par l'ecrivain interne, qui ne connait pas le gel.

CREATE OR REPLACE FUNCTION public.terrain_succession_geler(
  p_terrain_id text, p_succession text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp' AS $fn$
DECLARE v_moi text; v_defunt text; v_cle text; v_data jsonb; v_final jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT defunt INTO v_defunt FROM public.successions
   WHERE id = p_succession AND statut = 'en_attente';
  IF v_defunt IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'succession_inconnue');
  END IF;

  SELECT t.id, coalesce(t.data::jsonb, '{}'::jsonb) INTO v_cle, v_data
    FROM public.terrains_etat t
   WHERE t.id = p_terrain_id OR t.building_id = p_terrain_id
   ORDER BY (t.id = p_terrain_id) DESC LIMIT 1 FOR UPDATE;
  IF v_cle IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;

  -- LE TERRAIN DOIT ETRE CELUI DU DEFUNT. `titulaire_est_moi` ne sert pas ici : on compare au
  -- DEFUNT, pas a l'appelant -- mais on reconnait les memes trois formes de reference.
  IF NOT (coalesce(v_data ->> 'proprietaire', '') IN (v_defunt, 'pj:' || v_defunt)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_du_defunt',
                              'proprietaire', v_data ->> 'proprietaire');
  END IF;

  -- Rejouable sans risque : reposer le MEME gel est un no-op. Un gel par une AUTRE succession est
  -- en revanche refuse -- deux successions ne se disputent pas un bien.
  IF coalesce(v_data ->> 'succession_gel', '') NOT IN ('', p_succession) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_gele_par_une_autre_succession',
                              'gel', v_data ->> 'succession_gel');
  END IF;

  v_final := public.terrain_etat_fusionner_interne(p_terrain_id,
               jsonb_build_object('succession_gel', p_succession), NULL);
  RETURN jsonb_build_object('ok', true, 'gel', p_succession, 'etat', v_final);
END; $fn$;

CREATE OR REPLACE FUNCTION public.terrain_succession_annuler_compromis(
  p_terrain_id text, p_succession text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp' AS $fn$
DECLARE v_moi text; v_defunt text; v_cle text; v_data jsonb; v_final jsonb; v_concerne boolean;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT defunt INTO v_defunt FROM public.successions
   WHERE id = p_succession AND statut = 'en_attente';
  IF v_defunt IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'succession_inconnue');
  END IF;

  SELECT t.id, coalesce(t.data::jsonb, '{}'::jsonb) INTO v_cle, v_data
    FROM public.terrains_etat t
   WHERE t.id = p_terrain_id OR t.building_id = p_terrain_id
   ORDER BY (t.id = p_terrain_id) DESC LIMIT 1 FOR UPDATE;
  IF v_cle IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;

  -- LES TROIS ENGAGEMENTS QUE LE CLIENT NETTOYAIT, et les trois seules raisons de le faire : le
  -- defunt detenait le compromis, avait un achat direct en cours, ou s'etait vu proposer un
  -- transfert. Rien d'autre n'est touche.
  v_concerne := (v_data ->> 'compromisPar') = v_defunt
             OR (v_data -> 'achatDirect' ->> 'demandeur') = v_defunt
             OR (v_data ->> 'transfertPropose') = v_defunt
             OR (v_data ->> 'transfertProposePar') = v_defunt;
  IF NOT v_concerne THEN
    -- Un engagement deja nettoye n'apparait plus dans le scan du client : on repond ok sans rien
    -- ecrire, exactement comme le jumeau des entreprises.
    IF NOT (v_data ? 'compromisPar' OR v_data ? 'achatDirect' OR v_data ? 'transfertPropose') THEN
      RETURN jsonb_build_object('ok', true, 'deja_nettoye', true);
    END IF;
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_l_engagement_du_defunt');
  END IF;

  v_final := public.terrain_etat_fusionner_interne(p_terrain_id, jsonb_build_object(
    'compromis', NULL, 'compromisPar', NULL, 'acompte', NULL, 'compromisAt', NULL,
    'compromisExpireAt', NULL, 'achatDirect', NULL,
    'transfertPropose', NULL, 'transfertProposePar', NULL), NULL);
  RETURN jsonb_build_object('ok', true, 'etat', v_final);
END; $fn$;

REVOKE ALL ON FUNCTION public.terrain_succession_geler(text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.terrain_succession_annuler_compromis(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.terrain_succession_geler(text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.terrain_succession_annuler_compromis(text, text) TO authenticated, service_role;

DO $p$
DECLARE v_def text;
BEGIN
  IF NOT has_function_privilege('authenticated', 'public.terrain_succession_geler(text,text)'::regprocedure, 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.terrain_succession_annuler_compromis(text,text)'::regprocedure, 'EXECUTE')
     OR has_function_privilege('anon', 'public.terrain_succession_geler(text,text)'::regprocedure, 'EXECUTE')
     OR has_function_privilege('anon', 'public.terrain_succession_annuler_compromis(text,text)'::regprocedure, 'EXECUTE') THEN
    RAISE EXCEPTION 'les droits des deux portes successorales sont faux';
  END IF;
  -- LES DEUX EXIGENT UNE SUCCESSION EN ATTENTE, comme leurs jumelles d'entreprise.
  FOR v_def IN
    SELECT pg_get_functiondef(p.oid) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public'
       AND p.proname IN ('terrain_succession_geler', 'terrain_succession_annuler_compromis')
  LOOP
    IF v_def NOT LIKE '%statut = ''en_attente''%' THEN
      RAISE EXCEPTION 'une porte successorale accepte une succession qui n''est pas en attente';
    END IF;
    IF v_def NOT LIKE '%FOR UPDATE%' THEN
      RAISE EXCEPTION 'une porte successorale decide sans verrou de ligne';
    END IF;
    -- ELLES NE PASSENT PAS PAR LA LECTURE QUI REFUSE LES TERRAINS GELES : c'est volontaire.
    IF v_def LIKE '%terrain_etat_verrouiller_interne%' THEN
      RAISE EXCEPTION 'une porte successorale passe par la lecture qui refuse le gel';
    END IF;
    IF v_def NOT LIKE '%terrain_etat_fusionner_interne%' THEN
      RAISE EXCEPTION 'une porte successorale n''utilise pas l''ecrivain unique';
    END IF;
  END LOOP;
  v_def := pg_get_functiondef('public.terrain_succession_geler(text,text)'::regprocedure);
  IF v_def NOT LIKE '%pas_du_defunt%' OR v_def NOT LIKE '%deja_gele_par_une_autre_succession%' THEN
    RAISE EXCEPTION 'le gel successoral ne verifie pas a qui est le terrain';
  END IF;
  RAISE NOTICE 'Les 10 preuves structurelles des portes successorales sont vertes.';
END $p$;
