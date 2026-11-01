-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261029182603.
-- Archivage documentaire seulement ; ne pas rejouer.
-- =====================================================================================
-- PRÊTS ET BUDGETS MUNICIPAUX : ÉCRITURES DE L'ÉCRAN RÉDUITES À LEUR USAGE LÉGITIME
-- (29/10/2026, Claude). NON APPLIQUÉE — application par ChatGPT. Compatible avec l'écran en ligne.
--
-- Défauts reproduits au rôle authenticated (Jean Jaaj, transaction annulée) :
-- 1. `prets` : un joueur soldait ses propres prêts (`montant_restant = 0, statut = 'rembourse'`).
--    La garde existante ne couvre que les prêts nationaux versionnés. Seule écriture légitime de
--    l'écran : passer SES prêts au statut 'succession' (plateau-personnage.js). Tout le reste passe
--    déjà par des fonctions serveur (contrat, échéances, Helvetia).
-- 2. `budgets_municipaux` : tout joueur pouvait réécrire le budget de n'importe quelle ville, dont
--    `tauxFoncier` (lu chaque nuit par `taxe_fonciere_prelever`) et les taux lus par
--    `appliquer_taxe_transaction` à chaque vente. Le maire fixe ses taux par la porte serveur
--    existante `taux_imposition_fixer`. Écritures légitimes de l'écran : créer le budget vide d'une
--    ville (clés `key`, `tauxFoncier` = 0,05) et poser / lever `manifestationInterdite`
--    (ordre « Gérer les manifestations », réservé au ministre de l'Intérieur).
-- =====================================================================================
-- Garde en SECURITY INVOKER : current_user vaut le rôle du joueur pour une écriture directe de l'écran,
-- et le propriétaire de la fonction pour une fonction serveur SECURITY DEFINER (Helvetia, prêt
-- national, taux_imposition_fixer, mariage_*). est_appel_serveur() ne fait pas cette différence.
CREATE OR REPLACE FUNCTION public.prets_ecriture_ecran_garder()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN RETURN coalesce(NEW, OLD); END IF;
  IF TG_OP = 'UPDATE'
     AND OLD.emprunteur = public.mon_personnage()
     AND NEW.statut = 'succession'
     AND (to_jsonb(NEW) - 'statut') = (to_jsonb(OLD) - 'statut') THEN
    RETURN NEW;
  END IF;
  RAISE EXCEPTION 'pret_ecrit_par_le_serveur' USING ERRCODE = '42501';
END;
$function$;
DROP TRIGGER IF EXISTS prets_ecriture_ecran_garder ON public.prets;
CREATE TRIGGER prets_ecriture_ecran_garder BEFORE INSERT OR UPDATE OR DELETE ON public.prets
  FOR EACH ROW EXECUTE FUNCTION public.prets_ecriture_ecran_garder();

CREATE OR REPLACE FUNCTION public.budgets_municipaux_ecran_garder()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_pays text := split_part(NEW.id, '_', 1);
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN RETURN NEW; END IF;
  IF TG_OP = 'INSERT' THEN
    -- L'écran écrit par upsert : une ligne existante sera jugée par la garde UPDATE.
    IF EXISTS (SELECT 1 FROM public.budgets_municipaux b WHERE b.id = NEW.id) THEN RETURN NEW; END IF;
    IF (NEW.data - 'key' - 'tauxFoncier') = '{}'::jsonb AND (NEW.data->>'tauxFoncier')::numeric = 0.05 THEN RETURN NEW; END IF;
    RAISE EXCEPTION 'budget_municipal_ecrit_par_le_serveur' USING ERRCODE = '42501';
  END IF;
  IF (NEW.data - 'manifestationInterdite') IS DISTINCT FROM (OLD.data - 'manifestationInterdite')
     OR NEW.id IS DISTINCT FROM OLD.id THEN
    RAISE EXCEPTION 'budget_municipal_ecrit_par_le_serveur' USING ERRCODE = '42501';
  END IF;
  IF (NEW.data->'manifestationInterdite') IS DISTINCT FROM (OLD.data->'manifestationInterdite')
     AND NOT public.mon_poste_est_dans('min_int', v_pays) THEN
    RAISE EXCEPTION 'autorite_refusee' USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$function$;
DROP TRIGGER IF EXISTS budgets_municipaux_ecran_garder ON public.budgets_municipaux;
CREATE TRIGGER budgets_municipaux_ecran_garder BEFORE INSERT OR UPDATE ON public.budgets_municipaux
  FOR EACH ROW EXECUTE FUNCTION public.budgets_municipaux_ecran_garder();
