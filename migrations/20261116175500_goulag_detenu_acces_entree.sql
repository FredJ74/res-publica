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
REVOKE ALL ON FUNCTION public.sovarka_goulag_detenu_vers_entree() FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.sovarka_goulag_detenu_vers_entree() TO authenticated;

-- Fermer aussi les RPC gratuites et les écritures visant le PJ depuis un autre
-- acteur (don d'objets, repas, sommeil, téléportation, sauvegarde périmée).
-- request.path vient de PostgREST, pas des arguments de la fonction cliente.
CREATE OR REPLACE FUNCTION public.sovarka_goulag_fiche_garder()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_chemin text:=coalesce(current_setting('request.path',true),''); v_phase text;
BEGIN
 IF OLD.country IS DISTINCT FROM 'soviet' OR
  coalesce(nullif(current_setting('role',true),'none'),session_user) NOT IN ('anon','authenticated','service_role') THEN RETURN NEW; END IF;
 IF EXISTS(SELECT 1 FROM public.sovarka_goulag_traversees WHERE nom=OLD.name AND en_cours) THEN
  v_phase:='traversee_irreversible';
 ELSIF EXISTS(SELECT 1 FROM public.sovarka_goulag_refuges WHERE nom=OLD.name AND NOT termine) THEN
  v_phase:='repos_force_goulag';
 ELSE RETURN NEW; END IF;
 IF (NEW.pa,NEW.inventory,NEW.country,NEW.current_city,NEW.current_building,NEW.current_room,NEW.current_street)
  IS NOT DISTINCT FROM (OLD.pa,OLD.inventory,OLD.country,OLD.current_city,OLD.current_building,OLD.current_room,OLD.current_street) THEN RETURN NEW; END IF;
 IF v_chemin=ANY(ARRAY['/rpc/goulag_toundra_demarrer','/rpc/goulag_toundra_agir',
  '/rpc/sovarka_goulag_refuge_rejoindre','/rpc/sovarka_goulag_refuge_nuit',
  '/rpc/sovarka_goulag_refuge_terminer','/rpc/pa_repos_nocturne'])
  AND (OLD.user_id=auth.uid() OR (v_chemin='/rpc/pa_repos_nocturne'
   AND coalesce(nullif(current_setting('role',true),'none'),session_user)='service_role')) THEN RETURN NEW; END IF;
 RAISE EXCEPTION USING ERRCODE='42501',MESSAGE=v_phase;
END $$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_fiche_garder() FROM PUBLIC,anon,authenticated,service_role;
DROP TRIGGER IF EXISTS zz_goulag_fiche_garder ON public.personnages_donnees;
CREATE TRIGGER zz_goulag_fiche_garder BEFORE UPDATE ON public.personnages_donnees
 FOR EACH ROW EXECUTE FUNCTION public.sovarka_goulag_fiche_garder();
