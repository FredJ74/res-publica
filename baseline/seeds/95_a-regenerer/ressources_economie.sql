-- Généré depuis data.js par outils/generateurs/generer_ordres_couts.py --ressources-sql.
-- Ne pas retoucher ; régénérer avec outils/baseline/regenerer-seeds-miroirs.py.
INSERT INTO public.ressources_economie (cle,prix_base,prix_achat_fournisseur,plafond,source) VALUES
('alcool',14,7,100,'transformation'),('bois',5,2.5,750,'livraison'),('carburant',20,10,100,'transformation'),('cereales',3,1.5,150,'livraison'),('charbon',7,3.5,400,'livraison'),('desinfectant',18,9,100,'transformation'),('fruits_legumes',4,2,150,'livraison'),('laitages',3,1.5,150,'livraison'),('medicaments',22,11,100,'transformation'),('metal',15,7.5,200,'livraison'),('minerai',10,5,500,'livraison'),('petrole',8,4,200,'livraison'),('plantes',6,3,300,'livraison'),('poisson',4,2,125,'livraison'),('produits_exotiques',6,3,125,'livraison'),('tabac',18,9,100,'transformation'),('textile',5,2.5,125,'livraison'),('viande',5,2.5,125,'livraison')
ON CONFLICT DO NOTHING;
