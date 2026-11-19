-- Généré depuis data.js par outils/generateurs/generer_infractions.py --sql-categories.
-- Ne pas retoucher ; régénérer avec outils/baseline/regenerer-seeds-miroirs.py.
INSERT INTO public.infractions_categories (id,libelle,jours_reference,amende_reference) VALUES
('crime', 'Crime', 2, 5000),
  ('crime_etat', 'Crime d''Etat', 2, 0),
  ('delit', 'Delit', 1, 500),
  ('delit_grave', 'Delit grave', 1, 1500),
  ('delit_mineur', 'Delit mineur', 1, 500)
ON CONFLICT DO NOTHING;
