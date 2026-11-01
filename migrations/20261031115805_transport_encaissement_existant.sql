-- #219 : encaissement existant, tarif unitaire contrôlé, quantité interne.
-- Fred 28/10 : le leader paie pour tous, PA de l'ordre inchangés.
DO $prevol$
DECLARE adapte boolean;
BEGIN
 SELECT md5(prosrc)='ca7abc6ac27e864f723b25e73dacd665' INTO adapte FROM pg_proc
 WHERE oid='public.payer_ordre(text,text,integer,integer)'::regprocedure;
 IF adapte IS TRUE AND (to_regprocedure('public.payer_ordre_interne(text,text,integer,integer)') IS NULL
 OR to_regprocedure('public.payer_ordre_interne(text,text,integer,integer,integer)') IS NULL)
 OR adapte IS FALSE AND (to_regprocedure('public.payer_ordre_interne(text,text,integer,integer)') IS NOT NULL
 OR to_regprocedure('public.payer_ordre_interne(text,text,integer,integer,integer)') IS NOT NULL) THEN
 RAISE EXCEPTION 'payer_ordre_installation_partielle';END IF;
 IF (SELECT md5(prosrc) FROM pg_proc WHERE oid='public.payer_ordre(text,text,integer,integer)'::regprocedure)
 NOT IN ('ca7abc6ac27e864f723b25e73dacd665','5cf45c19e4b9559f6b29e2b9207d3969') THEN
 RAISE EXCEPTION 'payer_ordre_vivant_non_examine';END IF;
 IF to_regprocedure('public.payer_ordre_interne(text,text,integer,integer)') IS NOT NULL AND
 (SELECT md5(prosrc) FROM pg_proc WHERE oid=to_regprocedure('public.payer_ordre_interne(text,text,integer,integer)'))
 NOT IN ('f315b77059d65b1ccd1879e800d18c22') THEN
 RAISE EXCEPTION 'payer_ordre_interne_non_examine';END IF;
 IF to_regprocedure('public.payer_ordre_interne(text,text,integer,integer,integer)') IS NOT NULL AND
 (SELECT md5(prosrc) FROM pg_proc WHERE oid=to_regprocedure('public.payer_ordre_interne(text,text,integer,integer,integer)')) NOT IN ('716e233a2b71a4c7be1d1227200765e6') THEN
 RAISE EXCEPTION 'payer_quantite_interne_non_examine';END IF;
END $prevol$;
-- Adapter le corps EXAMINÉ, plutôt que réintroduire une ancienne copie.
-- Le contrôle de tarif reste unitaire ; seul le coût encaissé est multiplié.
-- Conservés : acquisitions/compromis/permis, exiger_acteur et fonds en transit.
DO $adapter$
DECLARE v_corps text;v_point text := '  SELECT pa, liquide, arg INTO v_pa, v_liquide, v_arg';
BEGIN
 -- Le prévol a contrôlé le corps adapté : un rejeu conserve la même fonction.
 IF to_regprocedure('public.payer_ordre_interne(text,text,integer,integer,integer)') IS NOT NULL THEN RETURN;END IF;
 SELECT prosrc INTO STRICT v_corps FROM pg_proc
 WHERE oid='public.payer_ordre(text,text,integer,integer)'::regprocedure;
 IF (length(v_corps)-length(replace(v_corps,v_point,'')))/length(v_point) <> 1 THEN
  RAISE EXCEPTION 'payer_ordre_point_adaptation_non_unique';END IF;
 v_corps:=replace(v_corps,v_point,$injection$
  IF p_quantite IS NULL OR p_quantite<1 OR coalesce(p_cost,0)::bigint*p_quantite>2147483647 THEN
    RETURN jsonb_build_object('ok',false,'raison','quantite_de_paiement_invalide'); END IF;
  p_cost:=coalesce(p_cost,0)*p_quantite;
$injection$ || v_point);
 EXECUTE format('CREATE OR REPLACE FUNCTION public.payer_ordre_interne(p_acteur text,p_fn text,p_pa integer,p_cost integer,p_quantite integer)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS %L',v_corps);
END $adapter$;
REVOKE ALL ON FUNCTION public.payer_ordre_interne(text,text,integer,integer,integer) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.payer_ordre_interne(p_acteur text,p_fn text,p_pa integer,p_cost integer)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
 SELECT public.payer_ordre_interne(p_acteur,p_fn,p_pa,p_cost,1);
$g$;
REVOKE ALL ON FUNCTION public.payer_ordre_interne(text,text,integer,integer) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.payer_ordre(p_acteur text,p_fn text DEFAULT NULL,p_pa integer DEFAULT 0,p_cost integer DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
BEGIN
 PERFORM public.exiger_acteur(p_acteur);
 RETURN public.payer_ordre_interne(p_acteur,p_fn,p_pa,p_cost);
END;
$g$;
