-- APPLIQUÉE en production le 24/11/2026 (contrôlée en lecture) — l'agent principal l'applique à la fusion (mission « Purge », 24/11/2026).
-- Point H.11 (Fred, 24/11/2026) : la quête active de Sovarka « Une affaire mystérieuse » (quetes_actives,
-- id quete-1790260995706, pnj_actif « Armurier Militaire », caserne-militaire / armurerie_militaire) précise dans son TEXTE
-- quel « Armurier Militaire » elle vise : le Sergent Bogdan Zatvorov (nom validé par Fred le 23/11, point 44), à
-- l'Armurerie Militaire de la Caserne centrale de Novomirsk (la seule caserne de Sovarka). La mécanique ne change pas :
-- pnj_actif, bâtiment, pièce, étapes et récompense restent tels quels (décision de Fred, en-tête de la migration
-- 20261123230000). Mise à jour gardée par l'ancien texte : rejouable ; rien du goulag.
BEGIN;
UPDATE public.quetes_actives
   SET description = 'Une étrange rumeur circule dans la ville. L''« Armurier Militaire » à trouver est le Sergent Bogdan Zatvorov, à l''Armurerie Militaire de la Caserne centrale de Novomirsk.'
 WHERE id = 'quete-1790260995706' AND country = 'soviet' AND pnj_actif = 'Armurier Militaire'
   AND description = 'Une étrange rumeur circule dans la ville.';

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.quetes_actives WHERE id = 'quete-1790260995706'
              AND (pnj_actif <> 'Armurier Militaire' OR building_id <> 'caserne-militaire' OR room_id <> 'armurerie_militaire'
                   OR position('Sergent Bogdan Zatvorov' IN description) = 0)) THEN
    RAISE EXCEPTION 'ghe_h11_quete_armurier_militaire : contrôle structurel en échec';
  END IF;
END $$;
COMMIT;
