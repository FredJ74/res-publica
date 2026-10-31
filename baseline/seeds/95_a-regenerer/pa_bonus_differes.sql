-- Généré depuis data.js par outils/generateurs/generer_pa_bonus_differes.py --sql.
-- Ne pas retoucher ; régénérer avec outils/baseline/regenerer-seeds-miroirs.py.
INSERT INTO public.pa_bonus_differes (source,montant) VALUES
('diner_affaires', 3),
  ('menu_gastronomique_1', 3),
  ('menu_gastronomique_2', 3),
  ('menu_gastronomique_3', 3),
  ('menu_psm_1', 3),
  ('menu_psm_2', 3),
  ('menu_psm_3', 3),
  ('repas_gastronomique', 1),
  ('sandwich', 1),
  ('service_etage_hotel', 1)
ON CONFLICT DO NOTHING;
