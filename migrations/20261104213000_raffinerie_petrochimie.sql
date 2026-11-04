-- Raffinerie Montrouge : trois produits petro-chimiques.
-- Pas de fonction RPC parallele : produire_en_usine lit ces deux catalogues
-- sous verrou et conserve la consommation de 5 petroles / PA, la limite de
-- 50 produits en vente directe, le debit usine et le salaire joueur.
-- Les prix sont les tarifs de reference : ils ne remplacent PAS les prix
-- effectifs du petrole importe (douanes + transport).
--
-- Calcul : 5 * 4 FR de petrole (reference existante) + salaire
-- = 90 % de (10 * prix_achat_fournisseur du produit).
-- Diluant : 20 + 52 = 72, pour 80 FR brut ; vernis : 20 + 70 = 90,
-- pour 100 FR ; polyester : 20 + 88 = 108, pour 120 FR.
--
-- Les trois filieres sont fabriquees par les PJ uniquement dans ce lot.
-- Le filet de securite PNJ continue a fabriquer le carburant, sans
-- multiplier artificiellement la demande quotidienne de petrole.
INSERT INTO public.ressources_economie
  (cle, prix_base, prix_achat_fournisseur, plafond, source)
VALUES
  ('diluant', 16, 8, 100, 'transformation'),
  ('vernis', 20, 10, 100, 'transformation'),
  ('polyester', 24, 12, 100, 'transformation')
ON CONFLICT (cle) DO UPDATE SET
  prix_base = EXCLUDED.prix_base,
  prix_achat_fournisseur = EXCLUDED.prix_achat_fournisseur,
  plafond = EXCLUDED.plafond,
  source = EXCLUDED.source;

INSERT INTO public.chaines_production_usine
  (produit, ville, building_id, matiere, salaire_pa)
VALUES
  ('diluant', 'ville_b', 'raffinerie-montrouge', 'petrole', 52),
  ('vernis', 'ville_b', 'raffinerie-montrouge', 'petrole', 70),
  ('polyester', 'ville_b', 'raffinerie-montrouge', 'petrole', 88)
ON CONFLICT (produit) DO UPDATE SET
  ville = EXCLUDED.ville,
  building_id = EXCLUDED.building_id,
  matiere = EXCLUDED.matiere,
  salaire_pa = EXCLUDED.salaire_pa;

INSERT INTO public.ordres_couts (fn, pa, cost) VALUES
  ('produire_diluant', 1, 0),
  ('produire_vernis', 1, 0),
  ('produire_polyester', 1, 0)
ON CONFLICT DO NOTHING;
