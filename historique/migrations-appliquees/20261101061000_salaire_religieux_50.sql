-- Salaire religieux ramené à 50 FR/jour (décision de Fred, 01/11/2026) : prêtre de chaque église
-- et supplément du Grand Prêtre. Il rémunère la charge, sans tâche ; la prière ne rapporte aucun
-- FR. Lu par salaire_religieux_percevoir. Indépendante de l'écran (texte des règles mis à jour).
BEGIN;
UPDATE public.salaires_religieux_declares SET montant = 50
 WHERE cle IN ('pretre:capitale', 'pretre:ville_a', 'pretre:ville_b', 'grand_pretre');
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.salaires_religieux_declares WHERE montant <> 50) THEN
    RAISE EXCEPTION 'salaire_religieux_inattendu'; END IF;
END $$;
COMMIT;
