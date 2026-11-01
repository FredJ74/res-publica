-- Généré depuis data.js par outils/generateurs/generer_villes.py --sql.
-- Ne pas retoucher ; régénérer avec outils/baseline/regenerer-seeds-miroirs.py.
INSERT INTO public.villes (pays,ville,nom,est_capitale,rang) VALUES
('khalija', 'capitale', 'Al Madina', true, 1),
  ('khalija', 'ville_a', 'Oasis City', false, 2),
  ('khalija', 'ville_b', 'Al-Petrol', false, 3),
  ('narco', 'capitale', 'Ciudad Roja', true, 1),
  ('narco', 'ville_a', 'Puerto Negro', false, 2),
  ('narco', 'ville_b', 'Villa Sangre', false, 3),
  ('republic', 'capitale', 'Luthécia', true, 1),
  ('republic', 'ville_a', 'Port-Sainte-Marie', false, 2),
  ('republic', 'ville_b', 'Montrouge', false, 3),
  ('soviet', 'capitale', 'Novomirsk', true, 1),
  ('soviet', 'ville_a', 'Starovka', false, 2),
  ('soviet', 'ville_b', 'Krasnov', false, 3)
ON CONFLICT DO NOTHING;
