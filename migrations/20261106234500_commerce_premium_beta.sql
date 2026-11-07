-- COMMERCE PREMIUM, GRATUIT PENDANT LA BÊTA (décisions de Fred, 06/11/2026 et 03/11/2026).
-- Règle des commerces (06/11) : 2 types d'activité et 4 articles en gratuit, 3 types et 10 articles
-- en premium. L'option s'achète pour un commerce donné (attachée au fonds), elle est gratuite pendant
-- la bêta « pour voir si elle fonctionne bien : quand elle sera payante, on ne pourra pas souffrir de bugs ».
-- Jusqu'ici, la base donnait 3 types et 10 articles à tout le monde et le bouton était une vitrine grisée.
--  * constantes : base gratuite 2 / 4, premium 3 / 10 ;
--  * entreprises.data.premium = true sur le fonds, posé par le serveur seul (authenticated n'a que SELECT) ;
--  * fonds_definir_types et fonds_reference_creer lisent le plafond du FONDS (patch en place) ;
--  * fonds_premium_activer : réservé au propriétaire du fonds, gratuit tant que commerce_premium_gratuit_beta = 1 ;
--  * commerces existants au-delà du gratuit (plus de 2 types ou de 4 articles) : premium d'office, rien n'est perdu.

INSERT INTO public.entreprises_constantes (cle, valeur) VALUES
  ('types_commerce_max_base','2'), ('references_max_base','4'),
  ('types_commerce_max_premium','3'), ('references_max_premium','10'), ('commerce_premium_gratuit_beta','1')
ON CONFLICT (cle) DO UPDATE SET valeur = EXCLUDED.valeur;

CREATE OR REPLACE FUNCTION public.fonds_types_max_fonds(p_data jsonb)
RETURNS integer LANGUAGE sql STABLE SET search_path TO 'public','pg_temp' AS $$
  SELECT CASE WHEN coalesce((p_data->>'premium')::boolean, false)
    THEN greatest(1, coalesce((SELECT valeur::integer FROM public.entreprises_constantes WHERE cle = 'types_commerce_max_premium'), 3))
    ELSE public.fonds_types_max(p_data->>'proprietaire') END
$$;

CREATE OR REPLACE FUNCTION public.fonds_references_max_fonds(p_data jsonb)
RETURNS integer LANGUAGE sql STABLE SET search_path TO 'public','pg_temp' AS $$
  SELECT CASE WHEN coalesce((p_data->>'premium')::boolean, false)
    THEN greatest(1, coalesce((SELECT valeur::integer FROM public.entreprises_constantes WHERE cle = 'references_max_premium'), 10))
    ELSE public.fonds_references_max(p_data->>'proprietaire') END
$$;

DO $mig$
DECLARE v_def text; v_new text;
BEGIN
  v_def := pg_get_functiondef('public.fonds_definir_types(text,text,text[])'::regprocedure);
  v_new := replace(v_def, $a$v_max := public.fonds_types_max(v_data ->> 'proprietaire');$a$,
                          $n$v_max := public.fonds_types_max_fonds(v_data);$n$);
  IF v_new = v_def THEN RAISE EXCEPTION 'patch fonds_definir_types non appliqué'; END IF;
  EXECUTE v_new;
  v_def := pg_get_functiondef('public.fonds_reference_creer(text,text,text,text,text,text)'::regprocedure);
  v_new := replace(v_def, $a$public.fonds_references_max(v_data->>'proprietaire')$a$, $n$public.fonds_references_max_fonds(v_data)$n$);
  IF v_new = v_def OR (length(v_def) - length(replace(v_def, 'fonds_references_max(v_data', ''))) / length('fonds_references_max(v_data') <> 2 THEN
    RAISE EXCEPTION 'patch fonds_reference_creer non appliqué (deux occurrences attendues)'; END IF;
  EXECUTE v_new;
END $mig$;

CREATE OR REPLACE FUNCTION public.fonds_premium_activer(p_fonds_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE moi text := public.mon_personnage(); v_data jsonb;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF NOT FOUND OR coalesce(v_data->>'proprietaire','') <> moi THEN
    RETURN jsonb_build_object('ok',false,'raison','reserve_proprietaire_fonds'); END IF;
  IF coalesce((v_data->>'premium')::boolean, false) THEN
    RETURN jsonb_build_object('ok',true,'deja',true,'typesMax',public.fonds_types_max_fonds(v_data),'referencesMax',public.fonds_references_max_fonds(v_data)); END IF;
  IF coalesce((SELECT valeur FROM public.entreprises_constantes WHERE cle = 'commerce_premium_gratuit_beta'),'0') <> '1' THEN
    RETURN jsonb_build_object('ok',false,'raison','paiement_non_active'); END IF;
  v_data := v_data || jsonb_build_object('premium', true, 'premiumDepuis', now(), 'premiumSource', 'beta_gratuite');
  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_fonds_id;
  RETURN jsonb_build_object('ok',true,'typesMax',public.fonds_types_max_fonds(v_data),'referencesMax',public.fonds_references_max_fonds(v_data));
END $$;

REVOKE ALL ON FUNCTION public.fonds_premium_activer(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fonds_premium_activer(text) TO authenticated;
REVOKE ALL ON FUNCTION public.fonds_types_max_fonds(jsonb), public.fonds_references_max_fonds(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fonds_types_max_fonds(jsonb), public.fonds_references_max_fonds(jsonb) TO authenticated;

-- Commerces déjà au-delà du gratuit : premium d'office (rien ne leur est retiré).
UPDATE public.entreprises SET data = data || jsonb_build_object('premium', true, 'premiumDepuis', now(), 'premiumSource', 'acquis_avant_option'),
       updated_at = now()
 WHERE id LIKE 'fonds-%' AND NOT coalesce((data->>'premium')::boolean, false)
   AND (coalesce(jsonb_array_length(CASE WHEN jsonb_typeof(data->'typesAutorises') = 'array' THEN data->'typesAutorises' END), 0) > 2
        OR (SELECT count(*) FROM jsonb_each(CASE WHEN jsonb_typeof(data->'references') = 'object' THEN data->'references' ELSE '{}'::jsonb END)) > 4);

DO $$
BEGIN
  IF public.fonds_types_max_fonds('{"premium":true}'::jsonb) <> 3 OR public.fonds_types_max_fonds('{}'::jsonb) <> 2
     OR public.fonds_references_max_fonds('{"premium":true}'::jsonb) <> 10 OR public.fonds_references_max_fonds('{}'::jsonb) <> 4 THEN
    RAISE EXCEPTION 'plafonds gratuit/premium incorrects'; END IF;
  IF position('fonds_types_max_fonds(v_data)' IN pg_get_functiondef('public.fonds_definir_types(text,text,text[])'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'fonds_definir_types ne lit pas le plafond du fonds'; END IF;
  IF has_function_privilege('anon', 'public.fonds_premium_activer(text)', 'EXECUTE') THEN RAISE EXCEPTION 'activer ouvert à anon'; END IF;
END $$;
