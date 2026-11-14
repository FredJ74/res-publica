-- Montrouge : chambre du dispensaire public (décision du 14 novembre 2026).
-- N'affecte ni Port-Sainte-Marie ni les autres empires.
-- Le moteur d'hospitalisation existant dirige automatiquement les patients vers
-- la pièce 'chambre' lorsqu'elle figure dans navigation_lieux_regles.
UPDATE public.navigation_lieux_regles
   SET pieces = pieces || '["chambre"]'::jsonb
 WHERE pays = 'republic'
   AND ville = 'ville_b'
   AND batiment = 'dispensaire-public-v'
   AND NOT pieces ? 'chambre';

-- Contrôle indispensable au déploiement : une et une seule entrée.
DO $$
DECLARE n integer;
BEGIN
 SELECT count(*) INTO n
 FROM public.navigation_lieux_regles
 WHERE pays='republic' AND ville='ville_b' AND batiment='dispensaire-public-v'
   AND pieces ? 'chambre';
 IF n <> 1 THEN RAISE EXCEPTION 'Chambre de Montrouge : entrée de navigation absente ou multiple (%)', n; END IF;
END $$;
