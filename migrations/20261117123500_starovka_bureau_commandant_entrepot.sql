-- Starovka : le bureau du Commandant du Port est une salle de l'Entrepôt Logistique.
-- Conserve les responsabilités et les caisses du port industriel, et le contrôle de poste.
BEGIN;

DO $migration$
DECLARE v_def text; v_old text := 'm.current_building IS DISTINCT FROM p.batiment';
BEGIN
 IF NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles
   WHERE pays='soviet' AND ville='ville_a' AND batiment='entrepot-logistique-starovka'
     AND pieces @> '["salle_ventes","bureau_direction"]'::jsonb)
 THEN RAISE EXCEPTION 'Starovka : entrepot logistique ou salles existantes introuvables'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles
   WHERE pays='soviet' AND ville='ville_a' AND batiment='port-starovka'
     AND pieces @> '["quai_principal","entrepot","douanes"]'::jsonb)
 THEN RAISE EXCEPTION 'Starovka : port industriel ou salles de fret introuvables'; END IF;

 UPDATE public.navigation_lieux_regles
 SET pieces = CASE WHEN pieces ? 'administration_portuaire' THEN pieces
                   ELSE pieces || '["administration_portuaire"]'::jsonb END
 WHERE pays='soviet' AND ville='ville_a' AND batiment='entrepot-logistique-starovka';
 UPDATE public.navigation_lieux_regles
 SET pieces = pieces - 'administration_portuaire'
 WHERE pays='soviet' AND ville='ville_a' AND batiment='port-starovka';

 -- Le RPC existant exige physiquement la présence au bâtiment p.batiment (port).
 -- Pour Sovarka uniquement, le Commandant travaille désormais depuis l'entrepôt.
 -- Pour Républia, le contrôle dans le port de PSM reste inchangé.
 v_def := pg_get_functiondef('public.port_commandant_regler(text,jsonb)'::regprocedure);
 IF position(v_old in v_def)=0 THEN
   RAISE EXCEPTION 'Garde de presence RPC introuvable : aucune fonction modifiee'; END IF;
 IF length(v_def)-length(replace(v_def,v_old,'')) <> length(v_old) THEN
   RAISE EXCEPTION 'Garde du RPC apparait plusieurs fois'; END IF;
 v_def := replace(v_def, v_old,
   '(m.current_building IS DISTINCT FROM CASE WHEN m.country = ''soviet'' THEN ''entrepot-logistique-starovka'' ELSE p.batiment END)');
 EXECUTE v_def;

 IF NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles
   WHERE pays='soviet' AND ville='ville_a' AND batiment='entrepot-logistique-starovka'
     AND pieces @> '["salle_ventes","bureau_direction","administration_portuaire"]'::jsonb)
 OR EXISTS (SELECT 1 FROM public.navigation_lieux_regles
   WHERE pays='soviet' AND ville='ville_a' AND batiment='port-starovka'
     AND pieces ? 'administration_portuaire')
 OR position('entrepot-logistique-starovka' in
   pg_get_functiondef('public.port_commandant_regler(text,jsonb)'::regprocedure))=0
 THEN RAISE EXCEPTION 'Migration bureau portuaire : postcondition echouee'; END IF;
END $migration$;

COMMIT;
