-- PRÉPARATION NON APPLIQUÉE : rehorodatée après la coupe canonique du 31/10/2026.
-- Ancien fichier : 20261019003000_fortune_serveur_diagnostic.sql ; aucun changement de règle.
-- Diagnostic FINANCIER en une lecture serveur. Aucun montant fourni par le navigateur,
-- aucune correction automatique : mesurer avant de basculer les ecritures historiques.
CREATE OR REPLACE FUNCTION public.fortune_serveur_diagnostic()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public','pg_temp' AS $$
DECLARE v_pj public.personnages_donnees%ROWTYPE;
 v_comptes numeric; v_placements numeric; v_poches numeric;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'authentification_requise'; END IF;
 SELECT * INTO v_pj FROM public.personnages_donnees WHERE user_id=auth.uid() LIMIT 1;
 IF NOT FOUND THEN RAISE EXCEPTION 'personnage_introuvable'; END IF;
 SELECT coalesce(sum(solde),0) INTO v_comptes FROM public.comptes_bancaires WHERE personnage=v_pj.name;
 SELECT coalesce(sum(montant),0) INTO v_placements FROM public.placements_bancaires WHERE personnage=v_pj.name AND statut='actif';
 v_poches := coalesce(v_pj.liquide,0) + v_comptes + v_placements;
 RETURN jsonb_build_object('ok',true,'arg_enregistre',v_pj.arg,'liquide',v_pj.liquide,
    'comptes',v_comptes,'placements',v_placements,'total_composantes',v_poches,
    'ecart',coalesce(v_pj.arg,0)-v_poches,'coherent',v_pj.arg=v_poches);
END; $$;
REVOKE ALL ON FUNCTION public.fortune_serveur_diagnostic() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.fortune_serveur_diagnostic() TO authenticated;
