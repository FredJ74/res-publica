-- Krasnov : quatre box identiques au centre commercial, 20 PSK par jour (décision de Fred, 14/11/2026).
-- Les plafonds hérités du gabarit (100 / 50 / 19 / 10) ne valaient que pour des locaux de tailles
-- différentes. Libellés alignés sur l'écran (« Box commercial 1 » à 4). Même modèle que les trois box
-- du centre artisanal (20261114003500) : loyer de départ = plafond, un local déjà demandé ou exploité
-- n'est pas touché. Appliquée en production sous le nom krasnov_centre_commercial_quatre_box_20_psk_20261114.
DO $$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n FROM public.sovarka_locaux
   WHERE pays='soviet' AND ville='ville_b' AND batiment='centre-commercial'
     AND piece IN ('vitrine_principale','boutique_milieu','arriere_boutique','cave_reserve');
  IF n <> 4 THEN RAISE EXCEPTION 'krasnov_box_commerciaux_absents'; END IF;
  IF EXISTS (SELECT 1 FROM public.sovarka_locaux l
              WHERE l.pays='soviet' AND l.ville='ville_b' AND l.batiment='centre-commercial'
                AND (l.demande_id IS NOT NULL OR public.sovarka_exploitant_interne(l.ville,l.batiment,l.piece) IS NOT NULL)) THEN
    RAISE EXCEPTION 'krasnov_box_commercial_occupe_a_examiner'; END IF;
  UPDATE public.sovarka_locaux
     SET label = CASE piece
           WHEN 'vitrine_principale' THEN 'Box commercial 1'
           WHEN 'boutique_milieu'    THEN 'Box commercial 2'
           WHEN 'arriere_boutique'   THEN 'Box commercial 3'
           WHEN 'cave_reserve'       THEN 'Box commercial 4' END,
         loyer = 20, plafond = 20
   WHERE pays='soviet' AND ville='ville_b' AND batiment='centre-commercial'
     AND piece IN ('vitrine_principale','boutique_milieu','arriere_boutique','cave_reserve');
  IF (SELECT count(*) FROM public.sovarka_locaux
       WHERE pays='soviet' AND ville='ville_b' AND batiment='centre-commercial'
         AND loyer=20 AND plafond=20 AND label LIKE 'Box commercial %') <> 4 THEN
    RAISE EXCEPTION 'krasnov_box_commerciaux_incoherents'; END IF;
END $$;
