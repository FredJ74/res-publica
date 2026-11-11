-- SOVARKA : MARCHE DE KRASNOV (decision de Fred du 10/11/2026, 23 h 19 ; GAME-DESIGN-NOVOMIRSK.md).
-- Le marche de Krasnov heritait de la dotation « marche@ville_b » de Montrouge (casquette, cartes postales,
-- carbonade). Il vend desormais : une portion de goulash, un guide des baies sauvages de Krasnov et des chemises
-- de bucheron a carreaux. La chemise est un objet d'integration locale (+1 ENT a Krasnov), cible « soviet.ville_b »
-- pour ne pas valoir a Montrouge. Prix PNJ : formule commune (2 x cout de revient), echelle de Sovarka.
-- Aucune donnee de joueur touchee. Idempotente.
BEGIN;
INSERT INTO public.recettes_commerce (id, source, label, pa, portions, materiaux, categorie, types_autorises, pays_autorises,
  villes_autorisees, buildings_autorises, icone, image, description, famille_produit_marche, bonus_integration_ville, generique_id) VALUES
 ('goulash_krasnov','marche','Portion de goulash',1,8,'{"viande":1,"fruits_legumes":1}','objet','["marche"]','["soviet"]','["ville_b"]','["marche"]',
  'ti-bowl',NULL,'Le ragoût de bœuf au paprika du kolkhoze, servi brûlant dans une gamelle.','aliment',NULL,NULL),
 ('guide_baies_krasnov','marche','Guide des baies sauvages de Krasnov',1,10,'{"bois":1}','objet','["marche"]','["soviet"]','["ville_b"]','["marche"]',
  'ti-book',NULL,'Airelles, myrtilles, camarine… et celles qu''il ne faut surtout pas manger.',NULL,NULL,NULL),
 ('chemise_bucheron_krasnov','marche','Chemise de bûcheron à carreaux',1,6,'{"textile":2}','objet','["marche"]','["soviet"]','["ville_b"]','["marche"]',
  'ti-shirt',NULL,'La flanelle rouge et noire des forestiers de Krasnov.','integration_locale','soviet.ville_b','accessoire-vestimentaire')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.commerces_dotations (cle, type, caisse, stock_matieres, cout_moyen_matieres, carte, parametres) VALUES
 ('marche@soviet.ville_b','marche',0,'{"viande":10,"fruits_legumes":10,"bois":10,"textile":10}','{"viande":2,"fruits_legumes":1,"bois":1,"textile":1}',
  '["goulash_krasnov","guide_baies_krasnov","chemise_bucheron_krasnov"]',
  '{"stockMax":{"goulash_krasnov":20,"guide_baies_krasnov":20,"chemise_bucheron_krasnov":20},
    "prixVente":{"goulash_krasnov":4,"guide_baies_krasnov":3,"chemise_bucheron_krasnov":6}}')
ON CONFLICT (cle) DO NOTHING;
DO $$ BEGIN
  IF (SELECT count(*) FROM public.recettes_commerce WHERE id IN ('goulash_krasnov','guide_baies_krasnov','chemise_bucheron_krasnov')) <> 3
     OR NOT EXISTS (SELECT 1 FROM public.commerces_dotations WHERE cle = 'marche@soviet.ville_b') THEN
    RAISE EXCEPTION 'marche_krasnov : controle structurel en echec';
  END IF;
END $$;
COMMIT;
