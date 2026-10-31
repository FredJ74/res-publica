-- Généré depuis data.js par outils/generateurs/generer_recettes_militaires.py --sql.
-- Ne pas retoucher ; régénérer avec outils/baseline/regenerer-seeds-miroirs.py.
INSERT INTO public.recettes_militaires (produit,label,materiaux,pa,produit_par_lot,type_objet,sous_type,prix_pnj,capacite) VALUES
('arme_de_poing', 'Pistolet militaire', '{"bois":1,"metal":2}'::jsonb, NULL, 1, 'arme', 'militaire', NULL, NULL),
  ('explosif_militaire', 'Explosifs militaires', '{"metal":2,"minerai":3}'::jsonb, 1, 3, 'explosif', 'militaire', NULL, NULL),
  ('gilet_pare_balles', 'Gilet pare-balles', '{"metal":2,"textile":2}'::jsonb, 3, 1, 'equipement', 'militaire', 380, NULL),
  ('jumelles', 'Jumelles', '{"metal":1,"minerai":1,"textile":1}'::jsonb, 2, 1, 'equipement', 'militaire', 260, NULL),
  ('mitraillette', 'Mitraillette', '{"bois":2,"metal":2}'::jsonb, NULL, 1, 'arme', 'militaire', NULL, NULL),
  ('radio', 'Radio de campagne', '{"metal":1,"minerai":1,"textile":1}'::jsonb, 3, 1, 'equipement', 'militaire', 360, NULL),
  ('tente', 'Tente de campagne', '{"metal":1,"textile":1}'::jsonb, 2, 1, 'equipement', 'militaire', 240, 13),
  ('tenue_camouflage', 'Tenue de camouflage', '{"charbon":1,"fruits_legumes":1,"textile":1}'::jsonb, 2, 1, 'equipement', 'militaire', 230, NULL)
ON CONFLICT DO NOTHING;
