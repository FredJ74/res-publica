-- Primitive commune de résolution d'un coup : les caractéristiques et les PA sont
-- fournies par l'appelant autorisé ; les tirages et les dégâts restent au serveur.
-- Cette fonction ne modifie aucun personnage et ne remplace pas la validation
-- d'employeur, de présence et de droits de chaque ordre de combat.
CREATE OR REPLACE FUNCTION public.combat_coup_resoudre(
  p_comp_attaque numeric,
  p_comp_defense numeric,
  p_stat_defense numeric,
  p_bonus_arme integer,
  p_pa_cible integer
) RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY INVOKER
SET search_path TO 'public', 'pg_temp'
AS $fn$
DECLARE
  v_taux integer;
  v_jet integer;
  v_degre text;
  v_pa integer;
BEGIN
  IF p_comp_attaque IS NULL OR p_comp_defense IS NULL OR
     p_stat_defense IS NULL OR p_pa_cible IS NULL OR
     p_pa_cible < 0 OR p_pa_cible > 100000 OR
     p_comp_attaque < 0 OR p_comp_defense < 0 OR p_stat_defense < 0 OR
     p_comp_attaque > 1000 OR p_comp_defense > 1000 OR p_stat_defense > 1000 OR
     coalesce(p_bonus_arme,0) NOT BETWEEN -100 AND 100 THEN
    RETURN jsonb_build_object('ok',false,'raison','parametres_invalides');
  END IF;
  v_taux := public.militaire_taux_combat(
    p_comp_attaque,p_comp_defense,p_stat_defense,coalesce(p_bonus_arme,0));
  v_jet := floor(random()*100)::integer+1;
  v_degre := public.militaire_degre_combat(v_taux,v_jet);
  v_pa := public.militaire_pa_restants(p_pa_cible,v_degre);
  RETURN jsonb_build_object('ok',true,'taux',v_taux,'jet',v_jet,
    'degre',v_degre,'pa_avant',p_pa_cible,'pa_apres',v_pa,
    'perte',p_pa_cible-v_pa,'neutralise',v_pa=0);
END;
$fn$;
REVOKE ALL ON FUNCTION public.combat_coup_resoudre(numeric,numeric,numeric,integer,integer) FROM PUBLIC, anon, authenticated;
COMMENT ON FUNCTION public.combat_coup_resoudre(numeric,numeric,numeric,integer,integer)
 IS 'Primitive de calcul interne réutilisant les taux, degrés et dégâts militaires. Ne confère aucune autorité ni modification de PA.';