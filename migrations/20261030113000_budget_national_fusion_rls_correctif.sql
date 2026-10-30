-- Correctif de livraison #255 (30/10/2026).
-- Le declencheur de fusion doit lire les regles protegees par RLS sans accorder
-- aux joueurs la lecture de ce registre. Il doit cependant identifier le ROLE
-- REEL de l'appelant via est_appel_serveur(), comme les gardes existantes.
ALTER FUNCTION public.budgets_nationaux_ecran_fusionner() SECURITY DEFINER;
DO $fix$
DECLARE v_def text;
BEGIN
 v_def := pg_get_functiondef('public.budgets_nationaux_ecran_fusionner()'::regprocedure);
 v_def := replace(v_def,
   'IF current_user NOT IN (''authenticated'', ''anon'') THEN RETURN coalesce(NEW, OLD); END IF;',
   'IF public.est_appel_serveur() THEN RETURN coalesce(NEW, OLD); END IF;');
 IF position('IF public.est_appel_serveur() THEN RETURN coalesce(NEW, OLD); END IF;' IN v_def) = 0 THEN
   RAISE EXCEPTION 'contrat_budget_garde_inattendu';
 END IF;
 EXECUTE v_def;
END $fix$;
REVOKE SELECT ON TABLE public.budget_national_champs_regles FROM authenticated;
