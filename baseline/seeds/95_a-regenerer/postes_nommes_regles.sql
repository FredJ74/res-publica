-- Généré depuis data.js par outils/generateurs/generer_postes_nommes.py --sql.
-- Ne pas retoucher ; régénérer avec outils/baseline/regenerer-seeds-miroirs.py.
INSERT INTO public.postes_nommes_regles (poste_id,label,nomme_par,scope,autorite_scope) VALUES
('capitaine_port', 'Commandant du Port', 'min_fin', 'pays', NULL),
  ('chef_douanes', 'Chef des Douanes', 'min_int', 'pays', NULL),
  ('commandant', 'Commandant de la Caserne', 'min_def', 'pays', NULL),
  ('commissaire', 'Commissaire', 'maire', 'ville', NULL),
  ('directeur_entrepot', 'Directeur de l''Entrepôt Logistique', 'maire', 'ville', NULL),
  ('directeur_pharma', 'Directeur de l''Usine Pharmaceutique', 'min_fin', 'pays', NULL),
  ('directeur_raffinerie', 'Directeur de la Raffinerie', 'min_fin', 'pays', NULL),
  ('directeur_tabac_alcools', 'Directeur du Pôle Tabac & Alcools', 'min_fin', 'pays', NULL),
  ('juge', 'Juge', 'min_just', 'ville', 'pays'),
  ('maire_adjoint', 'Maire Adjoint', 'maire', 'ville', NULL),
  ('min_ae', 'Ministre des Affaires Etrangeres', 'pm', 'pays', NULL),
  ('min_def', 'Ministre de la Defense', 'pm', 'pays', NULL),
  ('min_fin', 'Ministre des Finances', 'pm', 'pays', NULL),
  ('min_info', 'Ministre de l''Information', 'pm', 'pays', NULL),
  ('min_int', 'Ministre de l''Interieur', 'pm', 'pays', NULL),
  ('min_just', 'Ministre de la Justice', 'pm', 'pays', NULL),
  ('pm', 'Premier Ministre', 'president', 'pays', NULL),
  ('procureur', 'Procureur de la Republique', 'min_just', 'pays', 'pays')
ON CONFLICT DO NOTHING;
