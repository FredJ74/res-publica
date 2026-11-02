-- #379 : aucun acte réel dans cette migration. Le stock, le jet et les coûts restent ceux du moteur existant.
-- Prévol refuse tout corps différent du baseline examiné ou de ce correctif.
DO $prevol$ BEGIN
 IF to_regprocedure('public.militaire_subtiliser_tenter(text)') IS NULL OR (SELECT md5(prosrc) FROM pg_proc WHERE oid=to_regprocedure('public.militaire_subtiliser_tenter(text)')) NOT IN ('1beb8dac38360e6433f9e151a71e7601','18420b8fdbdd3f746fe9559d0840152f') THEN RAISE EXCEPTION '379_definition_non_examinee: public.militaire_subtiliser_tenter(text)'; END IF;
 IF to_regprocedure('public.inventaire_deposer_interne(text,jsonb,boolean)') IS NULL THEN RAISE EXCEPTION '379_depot_unique_absent'; END IF;
 IF to_regprocedure('public.militaire_subtiliser_tenter(text,integer)') IS NOT NULL AND (SELECT md5(prosrc) FROM pg_proc WHERE oid=to_regprocedure('public.militaire_subtiliser_tenter(text,integer)'))<>'b91964b4b6b9e29b7e2f9bdab6f089fb' THEN RAISE EXCEPTION '379_contrat_subtilisation_deja_different'; END IF;
END $prevol$;

CREATE OR REPLACE FUNCTION public.militaire_subtiliser_tenter(p_pays text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  -- hg379_subtilisation_v1 : moteur conservé, réponse versionnée.
  v_depot jsonb;
  c_seuil_detection constant integer := 20;
  c_seuil_reussite  constant integer := 66;
  c_isn_defaut      constant integer := 30;
  v_moi text; v_pj public.personnages_donnees%ROWTYPE;
  v_dup numeric; v_isn integer; v_rep integer; v_bonus_rep integer;
  v_bonus numeric; v_jet integer; v_score integer;
  v_stock jsonb; v_objet jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN coalesce((SELECT jsonb_build_object('contrat',1,'pa',pa,'inventory',inventory,'revision',inventory_revision) FROM public.personnages_donnees WHERE name=v_moi),'{}'::jsonb) || jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT * INTO v_pj FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF NOT FOUND THEN RETURN coalesce((SELECT jsonb_build_object('contrat',1,'pa',pa,'inventory',inventory,'revision',inventory_revision) FROM public.personnages_donnees WHERE name=v_moi),'{}'::jsonb) || jsonb_build_object('ok', false, 'raison', 'personnage_absent'); END IF;
  IF coalesce(v_pj.current_building,'') <> 'caserne-militaire' THEN
    RETURN coalesce((SELECT jsonb_build_object('contrat',1,'pa',pa,'inventory',inventory,'revision',inventory_revision) FROM public.personnages_donnees WHERE name=v_moi),'{}'::jsonb) || jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;

  -- LE PA EST DEBITE AVANT LE JET, comme pour toute tentative : on paie l'essai, pas le resultat.
  IF coalesce(v_pj.pa, 0) < 2 THEN
    RETURN coalesce((SELECT jsonb_build_object('contrat',1,'pa',pa,'inventory',inventory,'revision',inventory_revision) FROM public.personnages_donnees WHERE name=v_moi),'{}'::jsonb) || jsonb_build_object('ok', false, 'raison', 'pa_insuffisants', 'requis', 2);
  END IF;

  -- DUP effective : meme regle que getStatEffective -- une caracteristique affaiblie est
  -- proportionnelle aux points de vie, jamais en dessous de 1.
  v_dup := coalesce((v_pj.stats->>'DUP')::numeric, 8);
  IF v_pj.stats_affaiblies ? 'DUP' THEN
    v_dup := greatest(1, round(v_dup * greatest(0, least(1, coalesce(v_pj.hp,0)::numeric / 100))));
  END IF;

  -- ISN de la zone. La caserne n'a pas d'indices propres : repli sur le defaut, exactement comme
  -- getIndiceVille cote client.
  SELECT coalesce((data->>'isn')::integer, c_isn_defaut) INTO v_isn
    FROM public.indices_villes WHERE id = p_pays || '_' || coalesce(v_pj.current_city,'');
  v_isn := coalesce(v_isn, c_isn_defaut);

  v_rep := greatest(0, least(100, coalesce(v_pj.reputation_criminelle, 0)));
  v_bonus_rep := CASE WHEN v_rep >= 70 THEN 15 WHEN v_rep >= 40 THEN 10 WHEN v_rep >= 20 THEN 5 ELSE 0 END;

  v_bonus := (v_dup - 10) * 2 - (v_isn - 45)::numeric / 3 + v_bonus_rep;
  v_jet := floor(random() * 100)::integer + 1 - 50;
  v_score := greatest(0, least(100, round(50 + v_bonus + v_jet)::integer));

  UPDATE public.personnages_donnees SET pa = greatest(0, coalesce(pa,0) - 2) WHERE name = v_moi;

  IF v_score < c_seuil_reussite THEN
    RETURN coalesce((SELECT jsonb_build_object('contrat',1,'pa',pa,'inventory',inventory,'revision',inventory_revision) FROM public.personnages_donnees WHERE name=v_moi),'{}'::jsonb) || jsonb_build_object('ok', true, 'reussite', false,
      'detecte', v_score < c_seuil_detection, 'score', v_score);
  END IF;

  -- REUSSITE. Le stock est decremente AVANT que l'objet n'existe : jamais d'explosif cree de rien.
  v_stock := public.caserne_stock_mouvement(p_pays, 'explosif_militaire', -1, NULL);
  IF coalesce((v_stock->>'ok')::boolean, false) IS NOT TRUE THEN
    RETURN coalesce((SELECT jsonb_build_object('contrat',1,'pa',pa,'inventory',inventory,'revision',inventory_revision) FROM public.personnages_donnees WHERE name=v_moi),'{}'::jsonb) || jsonb_build_object('ok', true, 'reussite', false, 'detecte', false,
      'score', v_score, 'raison', 'stock_insuffisant');
  END IF;

  -- ...et c'est le SERVEUR qui le pose dans l'inventaire, plus le navigateur.
  v_objet := jsonb_build_object(
    'id', 'mil-' || replace(gen_random_uuid()::text, '-', ''),
    'type', 'arme', 'sousType', 'militaire', 'origineMilitaire', true,
    'lot', coalesce(v_stock->'lots'->0->>'lot', 'legacy'),
    'produitMilitaire', 'explosif_militaire', 'name', 'Explosif militaire',
    'icon', 'ti-bomb', 'legal', true, 'imageUrl', NULL,
    'desc', 'Explosif militaire. Lot ' || coalesce(v_stock->'lots'->0->>'lot', 'legacy') || '.');

  v_depot := public.inventaire_deposer_interne(v_moi, v_objet, true);
  IF (v_depot->>'ok')::boolean IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'subtilisation_depot_refuse';
  END IF;

  RETURN coalesce((SELECT jsonb_build_object('contrat',1,'pa',pa,'inventory',inventory,'revision',inventory_revision) FROM public.personnages_donnees WHERE name=v_moi),'{}'::jsonb) || jsonb_build_object('ok', true, 'reussite', true, 'detecte', false,
    'score', v_score, 'objet', v_objet, 'lot', v_objet->>'lot');
END;
$function$;

CREATE OR REPLACE FUNCTION public.militaire_subtiliser_tenter(p_pays text,p_contrat integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $v$
BEGIN
 IF p_contrat IS DISTINCT FROM 1 THEN RETURN jsonb_build_object('ok',false,'raison','contrat_invalide'); END IF;
 RETURN public.militaire_subtiliser_tenter(p_pays);
END;
$v$;

REVOKE ALL ON FUNCTION public.militaire_subtiliser_tenter(text,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.militaire_subtiliser_tenter(text,integer) TO authenticated;
