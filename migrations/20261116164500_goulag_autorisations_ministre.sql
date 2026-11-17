-- Autorisations nominatives de visite au goulag. Le ministre décide de
-- l'autorisation de VISITE, jamais de la condamnation.
-- Décision 6924193788 : permanente, réutilisable et révocable.
CREATE TABLE IF NOT EXISTS public.sovarka_goulag_autorisations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nom text NOT NULL REFERENCES public.personnages_donnees(name),
  etat text NOT NULL DEFAULT 'demandee' CHECK (etat IN ('demandee','accordee','refusee','revoquee')),
  demandee_le timestamptz NOT NULL DEFAULT now(),
  decidee_le timestamptz,
  ministre text,
  revoquee_le timestamptz,
  commentaire text
);
CREATE UNIQUE INDEX IF NOT EXISTS sovarka_goulag_autorisation_demande_active
  ON public.sovarka_goulag_autorisations(nom)
  WHERE etat IN ('demandee','accordee');
ALTER TABLE public.sovarka_goulag_autorisations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sovarka_goulag_autorisations FROM PUBLIC,anon,authenticated,service_role;

-- Ne pas se fier au pays/au poste dans un cache client : acteur_poste_courant
-- et la fonction de titulature nationale sont côté serveur.
CREATE OR REPLACE FUNCTION public.sovarka_goulag_role_interne(p_nom text)
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_poste text; v_pays text;
BEGIN
  IF NOT EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=p_nom AND country='soviet')
    THEN RETURN NULL; END IF;
  IF public.sovarka_est_titulaire_interne(p_nom,'min_just') THEN RETURN 'min_just'; END IF;
  IF public.sovarka_est_titulaire_interne(p_nom,'pm') THEN RETURN 'pm'; END IF;
  SELECT a.poste_id,a.pays INTO v_poste,v_pays FROM public.acteur_poste_courant() a
    WHERE a.nom=p_nom AND a.poste_id='juge' AND a.pays='soviet' LIMIT 1;
  IF v_poste='juge' AND v_pays='soviet' THEN RETURN 'juge'; END IF;
  RETURN NULL;
END $$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_role_interne(text)
  FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.sovarka_goulag_visite_demander()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nom text:=public.mon_personnage(); v_p record; v_id uuid;
BEGIN
  IF auth.uid() IS NULL OR v_nom IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  IF NOT EXISTS(SELECT 1 FROM public.sovarka_goulag_configuration WHERE singleton AND active) THEN
    RETURN jsonb_build_object('ok',false,'raison','goulag_non_active'); END IF;
  SELECT country,current_city,current_building INTO v_p FROM public.personnages_donnees
    WHERE name=v_nom AND user_id=auth.uid() FOR UPDATE;
  IF NOT FOUND OR v_p.country<>'soviet' OR v_p.current_city NOT IN ('capitale','ville_a','ville_b')
    THEN RETURN jsonb_build_object('ok',false,'raison','hors_sovarka'); END IF;
  IF coalesce(v_p.current_building,'') NOT LIKE 'centre-multinodal-%' THEN
    RETURN jsonb_build_object('ok',false,'raison','pas_au_terminal'); END IF;
  IF EXISTS(SELECT 1 FROM public.detention_active(v_nom)) THEN
    RETURN jsonb_build_object('ok',false,'raison','detenu_interdit'); END IF;
  IF EXISTS(SELECT 1 FROM public.sovarka_goulag_autorisations
        WHERE nom=v_nom AND etat IN ('demandee','accordee')) THEN
    RETURN jsonb_build_object('ok',false,'raison','demande_deja_existante'); END IF;
  INSERT INTO public.sovarka_goulag_autorisations(nom) VALUES(v_nom) RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok',true,'demande_id',v_id,'etat','demandee');
END $$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_visite_demander() FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.sovarka_goulag_visite_demander() TO authenticated;

CREATE OR REPLACE FUNCTION public.sovarka_goulag_visite_decider(p_id uuid,p_decision text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nom text:=public.mon_personnage(); a public.sovarka_goulag_autorisations%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL OR v_nom IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  PERFORM 1 FROM public.personnages_donnees WHERE name=v_nom AND user_id=auth.uid() FOR SHARE;
  PERFORM 1 FROM public.postes_attribues WHERE country='soviet' AND poste_id='min_just' AND titulaire=v_nom FOR SHARE;
  IF NOT public.sovarka_est_titulaire_interne(v_nom,'min_just')
     OR NOT EXISTS(SELECT 1 FROM public.personnages_donnees
       WHERE name=v_nom AND user_id=auth.uid() AND country='soviet') THEN
    RETURN jsonb_build_object('ok',false,'raison','reserve_ministre_justice_sovarka'); END IF;
  IF p_decision NOT IN ('accorder','refuser','revoquer') OR p_decision IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','decision_invalide'); END IF;
  IF NOT EXISTS(SELECT 1 FROM public.sovarka_goulag_configuration WHERE singleton AND active) THEN
    RETURN jsonb_build_object('ok',false,'raison','goulag_non_active'); END IF;
  SELECT * INTO a FROM public.sovarka_goulag_autorisations WHERE id=p_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','demande_absente'); END IF;
  IF p_decision='revoquer' THEN
    IF a.etat='revoquee' THEN RETURN jsonb_build_object('ok',true,'demande_id',p_id,'etat','revoquee','deja_revoquee',true); END IF;
    IF a.etat<>'accordee' THEN RETURN jsonb_build_object('ok',false,'raison','autorisation_non_accordee'); END IF;
    UPDATE public.sovarka_goulag_autorisations SET etat='revoquee',revoquee_le=now(),ministre=v_nom WHERE id=p_id;
    RETURN jsonb_build_object('ok',true,'demande_id',p_id,'etat','revoquee');
  END IF;
  IF a.etat<>'demandee' THEN
    RETURN jsonb_build_object('ok',false,'raison','demande_deja_traitee'); END IF;
  UPDATE public.sovarka_goulag_autorisations
    SET etat=CASE p_decision WHEN 'accorder' THEN 'accordee' ELSE 'refusee' END,
        ministre=v_nom, decidee_le=now() WHERE id=p_id;
  RETURN jsonb_build_object('ok',true,'demande_id',p_id,
     'etat',CASE p_decision WHEN 'accorder' THEN 'accordee' ELSE 'refusee' END);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_visite_decider(uuid,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.sovarka_goulag_visite_decider(uuid,text) TO authenticated;

-- La lecture rend exclusivement ses propres demandes ou les demandes du
-- ministre. Pas de données nominatives exposées à un autre joueur.
CREATE OR REPLACE FUNCTION public.sovarka_goulag_visite_lire()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nom text:=public.mon_personnage(); v_ministre boolean;
BEGIN
  IF auth.uid() IS NULL OR v_nom IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  v_ministre := public.sovarka_est_titulaire_interne(v_nom,'min_just')
   AND EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=v_nom AND country='soviet' AND user_id=auth.uid());
  RETURN jsonb_build_object('ok',true,'ministre',v_ministre,
    'demandes',coalesce((
      SELECT jsonb_agg(jsonb_build_object('id',a.id,'nom',a.nom,'etat',a.etat,
        'demandee_le',a.demandee_le,'decidee_le',a.decidee_le) ORDER BY a.demandee_le DESC)
      FROM public.sovarka_goulag_autorisations a
      WHERE a.nom=v_nom OR v_ministre
    ),'[]'::jsonb));
END $$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_visite_lire() FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.sovarka_goulag_visite_lire() TO authenticated;
