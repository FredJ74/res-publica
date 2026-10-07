-- =============================================================================
-- CINQ FONCTIONS SERVEUR PERDENT LE DROIT `authenticated` QU'ELLES N'ONT JAMAIS DEMANDE
-- Chantier 4F -- 8 octobre 2026
--
-- APPLIQUEE le 8 octobre 2026. Inscrite au registre Supabase sous la version
-- 20261007153134 (le registre horodate a l'APPLICATION ; le nom de ce fichier garde
-- l'horodatage de sa redaction).
--
-- CE QUI A ETE VERIFIE APRES COUP. Verifie apres application : les cinq fonctions ne portent
-- plus que `postgres, service_role`. La migration porte elle-meme son controle, dans la
-- transaction -- elle aurait echoue plutot que de laisser croire qu'elle avait ferme ce qu'elle
-- annonce.
-- =============================================================================
--
-- LE PIEGE, POUR LA CINQUIEME FOIS. Supabase pose un ALTER DEFAULT PRIVILEGES sur le schema
-- public : toute fonction qui y nait recoit un GRANT EXECUTE NOMME a `anon`, `authenticated` et
-- `service_role`. Un `REVOKE ALL ... FROM PUBLIC, anon` ne retire PAS le grant nomme a
-- `authenticated` -- il retire le pseudo-role PUBLIC et le grant nomme a anon, rien d'autre.
--
-- Les migrations 20261008000000 et 20261008010000 declaraient donc service_role seul, et la base
-- disait `authenticated, postgres, service_role`. Le depot ne mentait pas par negligence : il
-- decrivait une intention que la base n'avait pas appliquee. C'est la REEXTRACTION DU BASELINE,
-- relue ligne par ligne, qui l'a vu -- aucun des dix controles ne le voyait, et c'est la
-- troisieme fois que ce diff rattrape ce que les controles laissent passer.
--
-- CE QUI EST REVOQUE, ET POURQUOI CHACUNE EST RESERVEE AU SERVEUR.
--
--   . villes_empreinte_reelle()        recalcule l'empreinte du referentiel des villes. Un
--                                      navigateur qui la compare a l'empreinte posee pourrait
--                                      conclure que la base divergent du depot : ce n'est pas
--                                      son affaire, c'est celle du controle.
--   . ville_est_reelle(pays, ville)    le resolveur d'autorite territoriale. Un navigateur n'a
--                                      pas a interroger la loi puis a decider seul : le serveur
--                                      l'applique. C'est exactement le motif « decide au serveur
--                                      n'est pas applique au serveur ».
--   . caisse_territoire(pays, caisse)  deduit le territoire d'une caisse. Idem.
--   . caisse_refus_autorite(caisse,    dit POURQUOI une caisse serait refusee. Donne la carte
--     pays)                            des caisses et de leurs postes d'autorite a qui la lit en
--                                      boucle ; les primitives l'appellent elles-memes, et elles
--                                      sont SECURITY DEFINER, donc elles n'ont pas besoin que
--                                      l'appelant y ait droit.
--   . budget_coherence()               expose les quatre invariants budgetaires et, avec eux, la
--                                      cle de repartition complete. C'est un outil de controle,
--                                      pas une lecture de jeu.
--
-- CE QUI N'EST PAS TOUCHE, ET C'EST VOULU. budget_repartition_lire(source) et
-- budget_repartition_fixer(source, beneficiaire, part) GARDENT `authenticated` : c'est par elles
-- que le Ministre de l'Economie et des Finances lit et modifie la cle depuis son navigateur, et
-- elles relisent son autorite en base. douane_payer_effectifs(pays) aussi : le Chef des Douanes
-- l'appelle. budget_repartir et budget_cascade_quotidienne, elles, etaient deja revoquees pour
-- `authenticated` -- leurs migrations le nommaient explicitement, ce qui est la preuve que le
-- manquement est un oubli de redaction et non une doctrine differente.
--
-- IDEMPOTENT. Un REVOKE sur un droit absent ne leve pas.
-- =============================================================================

BEGIN;

REVOKE EXECUTE ON FUNCTION public.villes_empreinte_reelle()           FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.ville_est_reelle(text, text)        FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.caisse_territoire(text, text)       FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.caisse_refus_autorite(text, text)   FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.budget_coherence()                  FROM authenticated;

-- CONTROLE DANS LA TRANSACTION : si l'une des cinq garde `authenticated`, la migration echoue au
-- lieu de laisser croire qu'elle a ferme ce qu'elle annonce.
DO $$
DECLARE v_restantes text;
BEGIN
  SELECT string_agg(p.oid::regprocedure::text, ', ' ORDER BY p.oid::regprocedure::text)
    INTO v_restantes
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
   WHERE p.proname IN ('villes_empreinte_reelle', 'ville_est_reelle', 'caisse_territoire',
                       'caisse_refus_autorite', 'budget_coherence')
     AND has_function_privilege('authenticated', p.oid, 'EXECUTE');
  IF v_restantes IS NOT NULL THEN
    RAISE EXCEPTION 'authenticated garde EXECUTE sur : %', v_restantes;
  END IF;
END $$;

COMMIT;
