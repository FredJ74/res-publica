-- Le prisonnier est placé dans la cellule du goulag par le moteur de
-- détention. Il doit pouvoir rejoindre l'entrée pour choisir « S'enfuir
-- à pied », sans que cette circulation intérieure autorise un transport
-- ordinaire ni contourne le statut de détenu.
CREATE OR REPLACE FUNCTION public.sovarka_goulag_detenu_vers_entree()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nom text:=public.mon_personnage();
        v_p public.personnages_donnees%ROWTYPE; v_det record;
BEGIN
 IF auth.uid() IS NULL OR v_nom IS NULL THEN
  RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
 IF NOT EXISTS(SELECT 1 FROM public.sovarka_goulag_configuration c
     WHERE c.singleton AND c.active) THEN
  RETURN jsonb_build_object('ok',false,'raison','goulag_non_active'); END IF;
 SELECT * INTO v_p FROM public.personnages_donnees
   WHERE name=v_nom AND user_id=auth.uid() FOR UPDATE;
 IF NOT FOUND OR (v_p.country,v_p.current_city,v_p.current_building)
   IS DISTINCT FROM ('soviet','qhs','qhs-prison') THEN
  RETURN jsonb_build_object('ok',false,'raison','hors_goulag'); END IF;
 SELECT * INTO v_det FROM public.detention_active(v_nom);
 IF NOT FOUND OR v_det.country<>'soviet' OR NOT v_det.qhs THEN
  RETURN jsonb_build_object('ok',false,'raison','non_detenu_goulag'); END IF;
 IF v_p.current_room='entree_qhs' THEN
  RETURN jsonb_build_object('ok',true,'deja_entree',true); END IF;
 IF v_p.current_room IS DISTINCT FROM 'cellules_qhs' THEN
  RETURN jsonb_build_object('ok',false,'raison','pas_dans_les_cellules'); END IF;
 IF NOT EXISTS(SELECT 1 FROM public.navigation_lieux_regles
   WHERE pays='soviet' AND ville='qhs' AND batiment='qhs-prison'
     AND pieces ? 'entree_qhs') THEN
  RETURN jsonb_build_object('ok',false,'raison','entree_absente'); END IF;
 UPDATE public.personnages_donnees SET current_room='entree_qhs',
    current_street=NULL,updated_at=clock_timestamp()
  WHERE name=v_nom AND user_id=auth.uid();
 RETURN jsonb_build_object('ok',true,'room','entree_qhs');
END $$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_detenu_vers_entree() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sovarka_goulag_detenu_vers_entree() TO authenticated;
