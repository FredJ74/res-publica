-- Miroir des tarifs (ordres_couts) pour les ordres de l'étape I (lot de Krasnov, 22/11/2026) : le marché unique,
-- « Inspecter la pièce » (1 PA) et « Désinstaller du matériel » (0 au déclenchement ; 2 PA par matériel débités par
-- desinstaller_materiel). fouiller_voler est déjà absent de la production. Rejouable.
INSERT INTO public.ordres_couts (fn, pa, cost) SELECT v.fn, v.pa, v.cost
  FROM (VALUES ('marche_krasnov', 0, 0), ('inspecter_piece', 1, 0), ('desinstaller_materiel', 0, 0)) v(fn, pa, cost)
 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts o WHERE o.fn = v.fn AND o.pa = v.pa AND o.cost = v.cost);
