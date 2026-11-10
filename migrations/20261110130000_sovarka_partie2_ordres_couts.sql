-- Miroir des couts des deux ordres d'ecran de la foret profonde de Krasnov (s'enfoncer, revenir a l'entree), sans PA ni
-- cout : le seed genere depuis data.js les declare, la base aussi. Les tirages passent par sovarka_foret_aller.
BEGIN;
INSERT INTO public.ordres_couts (fn, pa, cost)
SELECT x.fn, 0, 0 FROM (VALUES ('foret_enfoncer'), ('foret_revenir')) x(fn)
 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts o WHERE o.fn = x.fn AND o.pa = 0 AND o.cost = 0);
COMMIT;
