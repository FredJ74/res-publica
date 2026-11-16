-- Goulag Sovarka : dépôt de détention, hors accès navigateur.
-- Le module ne déclenche aucune incarcération. Appel interne uniquement depuis
-- une condamnation judiciaire validée ou une sortie régulière.
CREATE TABLE IF NOT EXISTS public.sovarka_goulag_depots (
  detention_id text PRIMARY KEY REFERENCES public.detentions(id),
  nom text NOT NULL REFERENCES public.personnages_donnees(name),
  objets jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(objets)='array'),
  etat text NOT NULL DEFAULT 'confisque' CHECK (etat IN ('confisque','restitue','perdu')),
  cree_le timestamptz NOT NULL DEFAULT now(),
  cloture_le timestamptz
);
CREATE INDEX IF NOT EXISTS sovarka_goulag_depots_nom_idx ON public.sovarka_goulag_depots(nom);
ALTER TABLE public.sovarka_goulag_depots ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sovarka_goulag_depots FROM PUBLIC,anon,authenticated,service_role;
-- Les clés vierges et doubles sont les objets avec type canonique du catalogue
-- des serrures. Un bloc serrure_cle ne constitue PAS une clé.
CREATE OR REPLACE FUNCTION public.sovarka_goulag_est_cle_interne(p_objet jsonb)
RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path TO 'public','pg_temp' AS $$
  SELECT coalesce(p_objet->>'type','') IN ('cle_serrure','cle_vierge')
$$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_est_cle_interne(jsonb)
  FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.sovarka_goulag_confisquer_interne(p_nom text,p_detention_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_d record; v_inv jsonb; v_conserve jsonb; v_depot jsonb; v_etat text;
BEGIN
  IF p_nom IS NULL OR p_detention_id IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','identifiants_absents'); END IF;
  -- Verrou personnage en premier, même ordre que les RPC d'inventaire.
  SELECT d.country,d.current_city,d.inventory INTO v_d
    FROM public.personnages_donnees d WHERE d.name=p_nom FOR UPDATE;
  IF NOT FOUND OR v_d.country IS DISTINCT FROM 'soviet'
      OR v_d.current_city IS DISTINCT FROM 'qhs' THEN
    RETURN jsonb_build_object('ok',false,'raison','hors_goulag'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.detentions d WHERE d.id=p_detention_id
      AND d.nom=p_nom AND d.country='soviet'
      AND d.mode_fin IS NULL AND d.jour_fin_effective IS NULL AND d.qhs) THEN
    RETURN jsonb_build_object('ok',false,'raison','detention_non_validee'); END IF;
  SELECT etat INTO v_etat FROM public.sovarka_goulag_depots WHERE detention_id=p_detention_id FOR UPDATE;
  IF FOUND THEN RETURN jsonb_build_object('ok',v_etat='confisque','raison',
     CASE WHEN v_etat='confisque' THEN 'deja_confisque' ELSE 'depot_clos' END); END IF;
  IF v_d.inventory IS NOT NULL AND jsonb_typeof(v_d.inventory) IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'goulag_inventaire_invalide'; END IF;
  v_inv := coalesce(v_d.inventory,'[]'::jsonb);
  SELECT coalesce(jsonb_agg(x.objet ORDER BY x.ord)
        FILTER (WHERE public.sovarka_goulag_est_cle_interne(x.objet)),'[]'::jsonb),
         coalesce(jsonb_agg(x.objet ORDER BY x.ord)
        FILTER (WHERE NOT public.sovarka_goulag_est_cle_interne(x.objet)),'[]'::jsonb)
    INTO v_conserve,v_depot
    FROM jsonb_array_elements(v_inv) WITH ORDINALITY AS x(objet,ord);
  INSERT INTO public.sovarka_goulag_depots(detention_id,nom,objets)
    VALUES(p_detention_id,p_nom,v_depot);
  UPDATE public.personnages_donnees SET inventory=v_conserve,updated_at=now()
    WHERE name=p_nom;
  IF (SELECT inventory FROM public.personnages_donnees WHERE name=p_nom) IS DISTINCT FROM v_conserve THEN
    RAISE EXCEPTION 'goulag_confiscation_refusee'; END IF;
  RETURN jsonb_build_object('ok',true,'detention_id',p_detention_id,
    'confisques',jsonb_array_length(v_depot),'cles_conservees',jsonb_array_length(v_conserve));
END $$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_confisquer_interne(text,text)
  FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.sovarka_goulag_depot_clore_interne(
  p_nom text,p_detention_id text,p_mode text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_etat text; v_objets jsonb; v_inv jsonb; v_tous jsonb;
BEGIN
  IF p_mode NOT IN ('liberation','evasion') OR p_mode IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','mode_invalide'); END IF;
  PERFORM 1 FROM public.personnages_donnees WHERE name=p_nom FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','personnage_absent'); END IF;
  SELECT etat,objets INTO v_etat,v_objets FROM public.sovarka_goulag_depots
    WHERE detention_id=p_detention_id AND nom=p_nom FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','depot_absent'); END IF;
  IF v_etat<>'confisque' THEN
    RETURN jsonb_build_object('ok',v_etat=CASE p_mode WHEN 'liberation' THEN 'restitue' ELSE 'perdu' END,
      'raison','depot_deja_clos','etat',v_etat); END IF;
  IF p_mode='liberation' THEN
    SELECT coalesce(inventory,'[]'::jsonb) INTO v_inv FROM public.personnages_donnees WHERE name=p_nom;
    IF jsonb_typeof(v_inv)<>'array' THEN RAISE EXCEPTION 'goulag_inventaire_invalide'; END IF;
    -- Les identifiants uniques restent identiques. Aucune recompilation d'objets.
    v_tous:=v_inv||v_objets;
    UPDATE public.personnages_donnees SET inventory=v_tous,updated_at=now() WHERE name=p_nom;
    IF (SELECT inventory FROM public.personnages_donnees WHERE name=p_nom) IS DISTINCT FROM v_tous THEN
      RAISE EXCEPTION 'goulag_restitution_refusee'; END IF;
  END IF;
  UPDATE public.sovarka_goulag_depots SET
    etat=CASE p_mode WHEN 'liberation' THEN 'restitue' ELSE 'perdu' END,
    cloture_le=now() WHERE detention_id=p_detention_id;
  RETURN jsonb_build_object('ok',true,'detention_id',p_detention_id,
    'etat',CASE p_mode WHEN 'liberation' THEN 'restitue' ELSE 'perdu' END,
    'objets',jsonb_array_length(v_objets));
END $$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_depot_clore_interne(text,text,text)
  FROM PUBLIC,anon,authenticated,service_role;
