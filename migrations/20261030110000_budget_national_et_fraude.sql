-- =====================================================================================
-- BUDGET NATIONAL PROTÉGÉ ET FRAUDE ÉLECTORALE AU TRÉSOR (30/10/2026, Claude). NON APPLIQUÉE.
-- Application par ChatGPT, APRÈS 20261030100000. Compatible avec l'écran en ligne.
--
-- 1. budgets_nationaux.data était réécrivable en entier par tout joueur connecté (bilan des
--    écritures de l'écran du 29/10). Il porte aujourd'hui la réserve du Trésor (taxe nationale,
--    amendes), le taux national, les stocks militaires… L'écran le réécrit en bloc à partir d'une
--    copie lue plus tôt. Une garde existante (trg_budget_national_epingler) vérifie déjà le poste
--    pour les rubriques de son registre budget_national_champs_regles (couvre-feu = min_int,
--    taux national et préemption = min_fin, recherche = commandant…), mais tout ce qui n'y figure
--    pas restait libre, dont la réserve du Trésor (reserveJour). Refuser les écritures casserait
--    les ordres légitimes dès que le serveur a bougé une autre clé entre-temps. La garde FUSIONNE
--    donc : pour une écriture de l'écran, seules les rubriques du registre sont prises dans la
--    nouvelle valeur (la garde existante y applique ensuite l'autorité), tout le reste garde la
--    valeur du serveur. Création par l'écran (budget absent) : valeurs par défaut seulement. Suppression
--    refusée. Les fonctions serveur (SECURITY DEFINER) ne sont pas concernées (test current_user,
--    voir ECRITURES-ECRAN-20261029.md).
-- 2. fraude_electorale_sanctionner retirait l'amende de `arg`, sans caisse : l'argent
--    disparaissait. Elle passe par amende_imposer_interne : Trésor national, dette prélevée la
--    nuit, au plus une fois par fraude (clé « fraude-<id> »).
--    minuit_decouverte_crimes a le même défaut ; c'est un moteur de police (Codex) : signalé,
--    non modifié.
-- =====================================================================================
CREATE OR REPLACE FUNCTION public.budgets_nationaux_ecran_fusionner()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE libres text[]; k text; base jsonb;
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN RETURN coalesce(NEW, OLD); END IF;
  -- Les rubriques que l'écran a le droit de modifier sont celles du registre d'autorité existant ;
  -- trg_budget_national_epingler y vérifie ensuite le poste de l'acteur, rubrique par rubrique.
  SELECT array_agg(DISTINCT split_part(r.champ, '.', 1)) INTO libres FROM public.budget_national_champs_regles r;
  libres := coalesce(libres, ARRAY[]::text[]);
  IF TG_OP = 'DELETE' THEN RAISE EXCEPTION 'budget_national_ecrit_par_le_serveur' USING ERRCODE = '42501'; END IF;
  IF TG_OP = 'INSERT' THEN
    -- Upsert d'une ligne existante : la garde UPDATE fusionnera.
    IF EXISTS (SELECT 1 FROM public.budgets_nationaux b WHERE b.id = NEW.id) THEN RETURN NEW; END IF;
    NEW.data := jsonb_build_object('tauxNational', 2, 'reserveJour', 0, 'derniereDistribJour', NEW.data->'derniereDistribJour');
    RETURN NEW;
  END IF;
  IF NEW.id IS DISTINCT FROM OLD.id THEN RAISE EXCEPTION 'budget_national_ecrit_par_le_serveur' USING ERRCODE = '42501'; END IF;
  base := coalesce(OLD.data, '{}'::jsonb);
  FOREACH k IN ARRAY libres LOOP
    base := base - k;
    IF NEW.data ? k THEN base := base || jsonb_build_object(k, NEW.data->k); END IF;
  END LOOP;
  NEW.data := base;
  RETURN NEW;
END;
$function$;
DROP TRIGGER IF EXISTS budgets_nationaux_ecran_fusionner ON public.budgets_nationaux;
CREATE TRIGGER budgets_nationaux_ecran_fusionner BEFORE INSERT OR UPDATE OR DELETE ON public.budgets_nationaux
  FOR EACH ROW EXECUTE FUNCTION public.budgets_nationaux_ecran_fusionner();

DO $$
DECLARE d text; f text := '  UPDATE public.personnages_donnees
     SET arg = greatest(0, coalesce(arg, 0) - v_amende)
   WHERE name = v_f.auteur;';
BEGIN
  d := pg_get_functiondef('public.fraude_electorale_sanctionner'::regproc);
  IF position('amende_imposer_interne' IN d) = 0 THEN
    IF (length(d)-length(replace(d,f,'')))/length(f) <> 1 THEN RAISE EXCEPTION 'fragment_introuvable_fraude'; END IF;
    EXECUTE replace(d, f, '  PERFORM public.amende_imposer_interne(''fraude-''||p_fraude_id, v_f.country, v_f.auteur, v_amende);');
  END IF;
END $$;
