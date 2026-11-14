-- Krasnov : trois box identiques dans le centre artisanal partagé.
-- La location reste une attribution municipale de Sovarka, signée chez le notaire.
-- Les trois identifiants de pièces existants sont conservés (pas de nouveau bail).
-- Migration de synchronisation : déjà appliquée en production via Supabase MCP
-- sous le nom krasnov_centre_artisanal_trois_box_15_psk.
DO $$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n
    FROM public.sovarka_locaux
   WHERE pays='soviet' AND ville='ville_b' AND batiment='centre-artisanal'
     AND piece IN ('echoppe_facade','atelier_milieu','reserve_arriere')
     AND origine='centre';
  IF n <> 3 THEN RAISE EXCEPTION 'krasnov_box_locaux_absents'; END IF;
  IF EXISTS (
    SELECT 1 FROM public.sovarka_locaux l
    WHERE l.pays='soviet' AND l.ville='ville_b' AND l.batiment='centre-artisanal'
      AND l.piece IN ('echoppe_facade','atelier_milieu','reserve_arriere')
      AND (l.demande_id IS NOT NULL OR public.sovarka_exploitant_interne(l.ville,l.batiment,l.piece) IS NOT NULL)
      AND (l.loyer <> 15 OR l.plafond <> 15)
  ) THEN RAISE EXCEPTION 'krasnov_box_location_a_preserver'; END IF;

  -- Pas d'écrasement de décision ultérieure du maire : les pièces déjà
  -- initialisées conservent leur loyer si cette migration est rejouée.
  UPDATE public.sovarka_locaux
     SET label = CASE piece
       WHEN 'echoppe_facade' THEN 'Box 1'
       WHEN 'atelier_milieu' THEN 'Box 2'
       WHEN 'reserve_arriere' THEN 'Box 3'
       END,
       loyer=15, plafond=15
   WHERE pays='soviet' AND ville='ville_b' AND batiment='centre-artisanal'
     AND piece IN ('echoppe_facade','atelier_milieu','reserve_arriere')
     AND (loyer=0 AND plafond <> 15);

  IF (SELECT count(*) FROM public.sovarka_locaux WHERE pays='soviet' AND ville='ville_b'
      AND batiment='centre-artisanal' AND piece IN ('echoppe_facade','atelier_milieu','reserve_arriere')
      AND plafond=15) <> 3 THEN
     RAISE EXCEPTION 'krasnov_box_plafonds_incoherents';
  END IF;
END $$;
