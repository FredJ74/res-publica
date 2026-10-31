-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261027102605.
-- Archivage documentaire seulement ; ne pas rejouer.
-- APPLIQUEE le 27/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261027102605.
-- Eprouvee avant application en transaction annulee, au role authenticated (ecriture serveur conservee, ecriture directe sans base annulee, variation avec base acceptee). Baseline NON reextrait.
-- ============================================================================
-- LA POPULARITE ET L'INFLUENCE ECRITES PAR UNE FONCTION DU SERVEUR NE SONT PLUS ANNULEES
-- (27 octobre 2026)
-- ============================================================================
-- Le declencheur personnages_fusionner_pop empeche le navigateur de fixer lui-meme sa popularite
-- ou son influence : une ecriture sans « base » annoncee est remise a l'ancienne valeur. Mais il
-- reconnaissait le navigateur au seul role de la connexion (est_appel_serveur), qui reste
-- « authenticated » a l'interieur d'une fonction du serveur appelee par un joueur. Resultat,
-- constate en conditions reelles le 27/10 : les gains et pertes decides PAR LE SERVEUR etaient
-- annules en silence -- don a l'eglise (+3), ordre generique (fuite d'information, loge,
-- interrogatoire), et toute fonction qui ecrit la popularite sans le protocole de base
-- (diner au restaurant, tournee, tirage d'une candidature, pouvoirs du QHS...).
-- Desormais une ecriture faite au cours d'un appel de fonction (/rpc/...) est celle du serveur ;
-- seule une ecriture directe de la fiche par le navigateur reste soumise au protocole de base.
-- Aucune fonction appelable par un joueur ne recoit une popularite ou une influence en argument
-- libre (verifie le 27/10). Idempotente. Aucun acte de joueur.
-- ============================================================================

DO $do$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('public.personnages_fusionner_pop'::regproc);
  IF position('request.path' IN v_def) = 0 THEN
    v_def := replace(v_def,
      'v_client boolean := NOT public.est_appel_serveur();',
      'v_client boolean := NOT public.est_appel_serveur()
                       AND coalesce(current_setting(''request.path'', true), '''') NOT LIKE ''/rpc/%'';');
    IF position('request.path' IN v_def) = 0 THEN
      RAISE EXCEPTION 'personnages_fusionner_pop : motif introuvable';
    END IF;
    EXECUTE v_def;
  END IF;
END $do$;
