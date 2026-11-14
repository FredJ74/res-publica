-- Krasnov : nouvelles salles de la distillerie, sans changer le bail de l'atelier.
-- Le centre d'écoute conserve sa pièce salle_ecoute.
DO $$
DECLARE v_pieces jsonb;
BEGIN
 SELECT pieces INTO v_pieces FROM public.navigation_lieux_regles
 WHERE pays='soviet' AND ville='ville_b' AND batiment='distillerie-krasnov' FOR UPDATE;
 IF v_pieces IS NULL OR NOT v_pieces ? 'atelier_distillerie' THEN
   RAISE EXCEPTION 'Distillerie de Krasnov absente ou atelier sans bail';
 END IF;
 UPDATE public.navigation_lieux_regles
 SET pieces='["salle_ventes","bureau_direction","atelier_distillerie"]'::jsonb
 WHERE pays='soviet' AND ville='ville_b' AND batiment='distillerie-krasnov';
 IF NOT EXISTS(
   SELECT 1 FROM public.navigation_lieux_regles
   WHERE pays='soviet' AND ville='ville_b' AND batiment='station-radar-krasnov'
     AND pieces ? 'salle_ecoute'
 ) THEN RAISE EXCEPTION 'Salle du centre d’écoute introuvable'; END IF;
END $$;
