-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261030122900.
-- Archivage documentaire seulement ; ne pas rejouer.
-- =====================================================================================
-- CORRECTIF BLOQUANT DE #256 : LE TRÉSOR NE RECEVAIT PLUS LES CRÉDITS NÉS D'UNE ACTION DE JOUEUR
-- (30/10/2026, Claude). NON APPLIQUÉE. À appliquer par ChatGPT AVANT 20261030140000.
--
-- Défaut prouvé (transaction annulée, production) : une fonction serveur SECURITY DEFINER appelée
-- par un joueur (rôle `authenticated`) ajoute 7 FR à reserveJour → la valeur revient à l'ancienne.
-- Cause : #256 a rendu la garde de fusion SECURITY DEFINER et lui fait tester est_appel_serveur(),
-- qui lit le paramètre `role` de la requête : il vaut `authenticated` pendant TOUT l'appel RPC,
-- y compris dans les fonctions serveur. La garde traite donc la taxe nationale sur les ventes,
-- l'amende immédiate (procédure simplifiée, appel), la fraude électorale… comme une écriture de
-- l'écran et rétablit l'ancienne réserve : le joueur est débité, le Trésor ne reçoit rien.
--
-- Correction minimale, sans réécrire la protection :
--   - la garde redevient SECURITY INVOKER et distingue l'écran par `current_user` : dans une
--     fonction serveur, current_user est le propriétaire (postgres) ; une écriture directe de
--     l'écran s'exécute sous `authenticated`/`anon` ;
--   - le registre budget_national_champs_regles reste illisible pour les joueurs (#256) : la garde
--     obtient la liste des rubriques par budget_national_rubriques_ecran(), SECURITY DEFINER, qui
--     ne renvoie que les noms de rubriques ;
--   - tout le reste est inchangé (fusion, défauts à l'insertion, suppression refusée, autorité par
--     poste via budget_national_epingler).
-- =====================================================================================
CREATE OR REPLACE FUNCTION public.budget_national_rubriques_ecran()
RETURNS text[] LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce(array_agg(DISTINCT split_part(r.champ, '.', 1)), ARRAY[]::text[]) FROM public.budget_national_champs_regles r;
$function$;
REVOKE ALL ON FUNCTION public.budget_national_rubriques_ecran() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.budget_national_rubriques_ecran() TO authenticated;

ALTER FUNCTION public.budgets_nationaux_ecran_fusionner() SECURITY INVOKER;
DO $fix$
DECLARE d text;
  f1 text := 'IF public.est_appel_serveur() THEN RETURN coalesce(NEW, OLD); END IF;';
  f2 text := 'SELECT array_agg(DISTINCT split_part(r.champ, ''.'', 1)) INTO libres FROM public.budget_national_champs_regles r;';
BEGIN
  d := pg_get_functiondef('public.budgets_nationaux_ecran_fusionner()'::regprocedure);
  IF position('budget_national_rubriques_ecran' IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, f1, ''))) / length(f1) <> 1 OR (length(d) - length(replace(d, f2, ''))) / length(f2) <> 1 THEN
    RAISE EXCEPTION 'contrat_budget_garde_inattendu';
  END IF;
  d := replace(d, f1, 'IF current_user NOT IN (''authenticated'', ''anon'') THEN RETURN coalesce(NEW, OLD); END IF;');
  d := replace(d, f2, 'libres := public.budget_national_rubriques_ecran();');
  EXECUTE d;
END $fix$;
