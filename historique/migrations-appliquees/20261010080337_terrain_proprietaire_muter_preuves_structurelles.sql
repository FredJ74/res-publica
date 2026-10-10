-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010080337 (UTC), nom `terrain_proprietaire_muter_preuves_structurelles`.
-- Le registre passe de 597 a 598 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 511c92c424079a7d0c8f62c0efea1a4c, 3827 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- TERRAIN : PREUVES STRUCTURELLES DE LA PORTE
--
-- Separee du corps pour la meme raison de transport. Huit preuves, dont celle qui tient le point
d'architecture : la fusion doit se faire sur l'etat lu SOUS VERROU (`v_data := v_data ||
p_patch`), les quatre titres doivent tous etre controles, et l'identifiant de vente doit rester
DATE et protege par `ON CONFLICT`.
--
-- ELLE VA PAR PAIRE AVEC : aucun fichier du depot.
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- Preuves STRUCTURELLES de terrain_proprietaire_muter. Separees du corps pour la seule raison
-- technique de la limite de transport du canal de migration. Aucune n'execute la porte.
DO $$
DECLARE v_def text; v_acl text;
BEGIN
  SELECT pg_get_functiondef(p.oid),
         coalesce(array_to_string(p.proacl::text[], ' | '), '(defaut)')
    INTO v_def, v_acl
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname='public' AND p.proname='terrain_proprietaire_muter';
  IF v_def IS NULL THEN RAISE EXCEPTION 'P1 : la porte est absente'; END IF;
  IF v_def NOT LIKE '%SECURITY DEFINER%' THEN RAISE EXCEPTION 'P1 : pas SECURITY DEFINER'; END IF;
  IF v_acl LIKE '%anon=%' THEN RAISE EXCEPTION 'P2 : anon peut muter un terrain -- %', v_acl; END IF;
  IF v_acl NOT LIKE '%authenticated=X/postgres%' THEN
    RAISE EXCEPTION 'P2 : l''acheteur ne peut pas appeler sa porte -- %', v_acl; END IF;

  -- P3 : LA FUSION SE FAIT SUR L'ETAT LU SOUS VERROU. C'est le point d'architecture : un patch
  -- partiel n'efface plus rien, et un cache client perime n'ecrase plus le serveur.
  IF v_def NOT LIKE '%FROM public.terrains_etat t%FOR UPDATE%' THEN
    RAISE EXCEPTION 'P3a : le terrain n''est pas verrouille'; END IF;
  IF v_def NOT LIKE '%v_data := v_data || p_patch;%' THEN
    RAISE EXCEPTION 'P3b : le patch n''est pas fusionne sur l''etat reel'; END IF;

  -- P4 : les QUATRE titres sont verifies, et aucun n'est accorde sans controle.
  IF v_def NOT LIKE '%pas_mon_compromis%' OR v_def NOT LIKE '%pas_mon_achat_direct%'
     OR v_def NOT LIKE '%pas_ma_quete%' OR v_def NOT LIKE '%titre_reserve_au_serveur%' THEN
    RAISE EXCEPTION 'P4 : un titre n''est pas controle'; END IF;
  IF v_def NOT LIKE '%public.mon_personnage()%' THEN
    RAISE EXCEPTION 'P4 : l''acteur n''est pas resolu au serveur'; END IF;

  -- P5 : le gel successoral est refuse AU SERVEUR, plus seulement dans le navigateur.
  IF v_def NOT LIKE '%terrain_gele%' THEN RAISE EXCEPTION 'P5 : le gel n''est pas refuse'; END IF;

  -- P6 : L'IDENTIFIANT DE LA VENTE EST DATE, PAS HORODATE A LA MILLISECONDE, et protege par
  -- ON CONFLICT -- un rejeu ne cree plus de seconde ligne.
  IF v_def NOT LIKE '%YYYYMMDD%' THEN
    RAISE EXCEPTION 'P6a : l''identifiant de vente n''est pas date'; END IF;
  IF v_def NOT LIKE '%ON CONFLICT (id) DO NOTHING%' THEN
    RAISE EXCEPTION 'P6b : l''insertion de la vente n''est pas protegee'; END IF;

  -- P7 : la table de l'historique public et la table des quetes ont toujours les colonnes lues.
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                  WHERE table_schema='public' AND table_name='terrains_historique_ventes'
                    AND column_name IN ('id','country','building_id','proprietaire','prix')
                 GROUP BY table_name HAVING count(*) = 5) THEN
    RAISE EXCEPTION 'P7a : terrains_historique_ventes a change de forme'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                  WHERE table_schema='public' AND table_name='quetes_actives'
                    AND column_name IN ('id','statut','resolu_par')
                 GROUP BY table_name HAVING count(*) = 3) THEN
    RAISE EXCEPTION 'P7b : quetes_actives ne permet plus de verifier le titre'; END IF;

  -- P8 : aucune donnee de banc n'a survecu (les bancs tournaient en transaction annulee).
  IF EXISTS (SELECT 1 FROM public.terrains_etat WHERE id LIKE 'zzt-%')
     OR EXISTS (SELECT 1 FROM public.quetes_actives WHERE id LIKE 'zzq-%')
     OR EXISTS (SELECT 1 FROM public.terrains_historique_ventes WHERE building_id LIKE 'zz-%') THEN
    RAISE EXCEPTION 'P8 : une donnee de banc a survecu'; END IF;

  RAISE NOTICE 'terrain_proprietaire_muter : 8 preuves structurelles conformes ; % terrain(s) en base.',
    (SELECT count(*) FROM public.terrains_etat);
END $$;