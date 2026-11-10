-- Miroir des couts des deux ordres d'ecran du lot des provinces de Sovarka (bons d'Etat, rapports d'ecoute du
-- ministre), qui n'ont ni PA ni cout : le seed genere depuis data.js les declare, la base aussi.
BEGIN;
INSERT INTO public.ordres_couts (fn, pa, cost)
SELECT x.fn, 0, 0 FROM (VALUES ('souscrire_bon_etat'), ('sovarka_ecoutes')) x(fn)
 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts o WHERE o.fn = x.fn AND o.pa = 0 AND o.cost = 0);
COMMIT;
