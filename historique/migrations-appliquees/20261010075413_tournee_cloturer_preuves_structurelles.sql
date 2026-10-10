-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010075413 (UTC), nom `tournee_cloturer_preuves_structurelles`.
-- Le registre passe de 595 a 596 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 a9698004442623b90462e9b3023a8db1, 3097 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- TOURNEE : PREUVES STRUCTURELLES DE LA PORTE
--
-- Separee du corps pour une seule raison technique -- corps plus preuves depassaient la limite de
transport du canal de migration. Huit preuves, dont deux qui PERIMENT LE DIAGNOSTIC si la base
change : la politique `personnages_maj_soi` doit rester `(user_id = auth.uid())`, et
`personnages_vue_modifier` doit toujours lever `personnage_non_possede`.
--
-- ELLE VA PAR PAIRE AVEC : aucun fichier du depot.
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- Preuves STRUCTURELLES de tournee_cloturer (migration precedente). Separees d'elle pour une seule
-- raison technique : le corps plus les preuves depassaient la limite de transport du canal de
-- migration. Aucune ne s'execute la porte -- une migration commite les effets de bord de ses
-- preuves (regle 3 de migrations/README.md).
DO $$
DECLARE v_def text; v_acl text;
BEGIN
  SELECT pg_get_functiondef(p.oid),
         coalesce(array_to_string(p.proacl::text[], ' | '), '(defaut)')
    INTO v_def, v_acl
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname='public' AND p.proname='tournee_cloturer';
  IF v_def IS NULL THEN RAISE EXCEPTION 'P1 : la porte est absente'; END IF;
  IF v_acl LIKE '%anon=%' THEN RAISE EXCEPTION 'P2 : anon peut clore une tournee -- %', v_acl; END IF;
  IF v_acl NOT LIKE '%authenticated=X/postgres%' THEN
    RAISE EXCEPTION 'P2 : l''offreur ne peut pas clore sa tournee -- %', v_acl; END IF;
  IF v_def NOT LIKE '%WHERE id = p_tournee_id AND statut = ''en_resolution''%' THEN
    RAISE EXCEPTION 'P3 : la cloture n''est pas un compare-and-swap'; END IF;
  IF v_def NOT LIKE '%public.mon_personnage()%' THEN
    RAISE EXCEPTION 'P4 : l''offreur n''est pas verifie'; END IF;

  -- P5 : LE CREDIT VISE LA TABLE, PAS LA VUE. C'est exactement le defaut mesure : la vue
  -- public.personnages leve personnage_non_possede sur la fiche d'autrui.
  IF v_def LIKE '%UPDATE public.personnages %' THEN
    RAISE EXCEPTION 'P5 : le credit passe par la vue, il sera refuse'; END IF;
  IF v_def NOT LIKE '%UPDATE public.personnages_donnees d%' THEN
    RAISE EXCEPTION 'P5 : le credit ne vise pas la table'; END IF;

  -- P6 : les deux plafonds de la regle de jeu sont dans le corps.
  IF v_def NOT LIKE '%least(100%' OR v_def NOT LIKE '%least(20%' THEN
    RAISE EXCEPTION 'P6 : un plafond de la regle manque'; END IF;

  -- P7 : la politique RLS qui a CAUSE le defaut est toujours celle qu'on a mesuree. Si elle
  -- change, le diagnostic inscrit dans l'en-tete de la migration precedente devient perime, et
  -- cette preuve doit le faire savoir bruyamment.
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public'
                  AND tablename='personnages_donnees' AND policyname='personnages_maj_soi'
                  AND cmd='UPDATE' AND qual = '(user_id = auth.uid())') THEN
    RAISE EXCEPTION 'P7 : la politique personnages_maj_soi a change -- le diagnostic est perime';
  END IF;

  -- P8 : le trigger de la vue qui leve l'exception existe toujours.
  IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
                  WHERE n.nspname='public' AND p.proname='personnages_vue_modifier'
                    AND pg_get_functiondef(p.oid) LIKE '%personnage_non_possede%') THEN
    RAISE EXCEPTION 'P8 : personnages_vue_modifier ne leve plus personnage_non_possede';
  END IF;

  RAISE NOTICE 'tournee_cloturer : 8 preuves structurelles conformes ; % tournee(s), % invitation(s) en base.',
    (SELECT count(*) FROM public.tournees), (SELECT count(*) FROM public.invitations_diner);
END $$;