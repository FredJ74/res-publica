-- Mission du 28/11/2026 (nuit, Claude), étape 3 D — Hôtel Royal d'Al-Khalija : « tous les prix de l'hôtel sont le double de
-- l'équivalent en Républia » (Fred, 28/11/2026). Les ordres propres de l'hôtel (am_*) sont déjà au double dans ordres_couts
-- (migration 20261128030000) ; ici, les ordres habituels du gabarit d'hôtel, par le tarif national d'Al-Khalija
-- (ordres_couts_pays, lu par payer_ordre et, côté navigateur, par TARIFS_PAYS). Al Madina est la seule ville ouverte d'Al-Khalija.
BEGIN;
INSERT INTO public.ordres_couts_pays (fn, pays, pa, cost) VALUES
  ('reserver_chambre_hotel', 'khalija', 0, 160),
  ('diner_affaires', 'khalija', 2, 600),
  ('service_etage', 'khalija', 0, 300)
ON CONFLICT DO NOTHING;
COMMIT;
-- Relecture : SELECT fn, pa, cost FROM public.ordres_couts_pays WHERE pays = 'khalija' ORDER BY fn;  -- 3 lignes
