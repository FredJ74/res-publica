-- Généré depuis data.js par outils/generateurs/generer_infractions.py --sql-categories.
-- Ne pas retoucher ; régénérer avec outils/baseline/regenerer-seeds-miroirs.py.
INSERT INTO public.infractions_categories (id,libelle,jours_reference,amende_reference) VALUES
('crime', 'Crime', 8, 5000),
  ('crime_etat', 'Crime d''Etat', 30, 0),
  ('delit', 'Delit', 2, 500),
  ('delit_grave', 'Delit grave', 4, 1500),
  ('delit_mineur', 'Delit mineur', 2, 500)
ON CONFLICT DO NOTHING;
