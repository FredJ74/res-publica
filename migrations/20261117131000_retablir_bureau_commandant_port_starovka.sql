-- Annulation du déplacement non demandé du bureau du Commandant de Port.
-- Restaure exactement la navigation et le contrôle d'emplacement antérieurs à #1078.
DO $undo$
DECLARE v_def text;
  v_new text := '(m.current_building IS DISTINCT FROM CASE WHEN m.country = ''soviet'' THEN ''entrepot-logistique-starovka'' ELSE p.batiment END)';
  v_old text := 'm.current_building IS DISTINCT FROM p.batiment';
BEGIN
 IF NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles WHERE pays='soviet' AND ville='ville_a' AND batiment='port-starovka')
 OR NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles WHERE pays='soviet' AND ville='ville_a' AND batiment='entrepot-logistique-starovka')
 THEN RAISE EXCEPTION 'Bâtiments Starovka absents, restauration interrompue'; END IF;
 UPDATE public.navigation_lieux_regles
 SET pieces = CASE WHEN pieces ? 'administration_portuaire' THEN pieces ELSE pieces || '["administration_portuaire"]'::jsonb END
 WHERE pays='soviet' AND ville='ville_a' AND batiment='port-starovka';
 UPDATE public.navigation_lieux_regles
 SET pieces=pieces - 'administration_portuaire'
 WHERE pays='soviet' AND ville='ville_a' AND batiment='entrepot-logistique-starovka';
 v_def:=pg_get_functiondef('public.port_commandant_regler(text,jsonb)'::regprocedure);
 IF position(v_new in v_def)=0 THEN RAISE EXCEPTION 'Garde SQL inattendue, restauration interrompue'; END IF;
 IF length(v_def)-length(replace(v_def,v_new,'')) <> length(v_new) THEN
    RAISE EXCEPTION 'Nombre de gardes SQL inattendu'; END IF;
 EXECUTE replace(v_def,v_new,v_old);
 IF EXISTS (SELECT 1 FROM public.navigation_lieux_regles
  WHERE pays='soviet' AND ville='ville_a' AND batiment='entrepot-logistique-starovka' AND pieces ? 'administration_portuaire')
 OR NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles
  WHERE pays='soviet' AND ville='ville_a' AND batiment='port-starovka' AND pieces ? 'administration_portuaire')
 OR position(v_old in pg_get_functiondef('public.port_commandant_regler(text,jsonb)'::regprocedure))=0
 THEN RAISE EXCEPTION 'Postconditions restauration échouées'; END IF;
END $undo$;
