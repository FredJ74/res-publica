-- Tournées : une seule vérité, celle du serveur (Fred, 12/11/2026).
--
-- Toute tournée créée en jeu passe par tournee_creer, qui pose toujours le contrat boire_v1, réglé
-- entièrement par tournee_cloturer_boire (PA, vente, Santé, INF, ENT de l'offreur et des invités).
-- Restait un ancien chemin : l'écran pouvait INSÉRER lui-même une ligne sans contrat, la revendiquer
-- par PATCH, puis tournee_cloturer créditait les invités et l'écran s'ajoutait +2 Moral / +1 ENT.
-- Ce chemin disparaît : plus d'insertion ni de mise à jour directe, et tournee_cloturer refuse tout
-- contrat autre que boire_v1 (aucune ligne de ce type n'existe en production au 12/11/2026).
BEGIN;

DROP POLICY IF EXISTS "tournee creee par l offreur" ON public.tournees;
DROP POLICY IF EXISTS "tournee pilotee par l offreur" ON public.tournees;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.tournees FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.tournee_cloturer(p_tournee_id text, p_servie boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE t public.tournees; v_moi text := public.mon_personnage();
BEGIN
  SELECT * INTO t FROM public.tournees WHERE id = p_tournee_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'tournee_introuvable'); END IF;
  IF v_moi IS NOT NULL AND v_moi IS DISTINCT FROM t.offreur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_offre'); END IF;
  IF t.contrat = 'boire_v1' THEN RETURN public.tournee_cloturer_boire(p_tournee_id); END IF;
  RETURN jsonb_build_object('ok', false, 'raison', 'contrat_retire');
END $$;
REVOKE ALL ON FUNCTION public.tournee_cloturer(text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.tournee_cloturer(text, boolean) TO authenticated;

DO $$
BEGIN
  IF has_table_privilege('authenticated', 'public.tournees', 'INSERT')
     OR has_table_privilege('authenticated', 'public.tournees', 'UPDATE')
     OR NOT has_table_privilege('authenticated', 'public.tournees', 'SELECT')
     OR EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'public.tournees'::regclass AND polcmd::text IN ('a', 'w', 'd'))
     OR NOT has_function_privilege('authenticated', 'public.tournee_creer(text,text,text,text[])', 'EXECUTE')
     OR position('contrat_retire' IN pg_get_functiondef('public.tournee_cloturer(text,boolean)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'tournees_une_seule_verite : contrôle structurel en échec';
  END IF;
END $$;

COMMIT;
