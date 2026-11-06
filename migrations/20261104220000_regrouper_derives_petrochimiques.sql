-- Arbitrage game design 04/11/2026 : UNE sous-famille petro-chimique.
-- Migration compensatrice de 20261104213000_raffinerie_petrochimie.sql
-- deja appliquee en beta. Ne pas modifier retroactivement la migration initiale.
--
-- Toutes les applications (vernis, goudron, polyester, diluant,
-- peintures/revetements) consomment la MEME ressource IG.
-- Le produit 'carburant' reste inchange.
-- Formule conservee : 5 petrole + 1 PA -> 10 derives, 70 FR de salaire.
-- 10*10 FR de gros - 5*4 FR de petrole - 70 FR = 10 FR de marge de reference.
--
-- Garde contre la disparition de stocks reels lors du regroupement.
DO $garde$ BEGIN
 IF EXISTS (
   SELECT 1 FROM public.batiments_etat
   WHERE data::text ~ '"(diluant|vernis|polyester)"'
 ) THEN
   RAISE EXCEPTION 'petrochimie_anciens_stocks_a_convertir_avant_regroupement';
 END IF;
END $garde$;

DELETE FROM public.ordres_couts
 WHERE fn IN ('produire_diluant','produire_vernis','produire_polyester')
   AND pa = 1 AND cost = 0;
DELETE FROM public.chaines_production_usine
 WHERE produit IN ('diluant','vernis','polyester')
   AND ville = 'ville_b' AND building_id = 'raffinerie-montrouge'
   AND matiere = 'petrole';
DELETE FROM public.ressources_economie
 WHERE cle IN ('diluant','vernis','polyester')
   AND source = 'transformation';

INSERT INTO public.ressources_economie
  (cle, prix_base, prix_achat_fournisseur, plafond, source)
VALUES ('derives_petrochimiques',20,10,100,'transformation')
ON CONFLICT (cle) DO UPDATE SET
  prix_base=EXCLUDED.prix_base,
  prix_achat_fournisseur=EXCLUDED.prix_achat_fournisseur,
  plafond=EXCLUDED.plafond,
  source=EXCLUDED.source;
INSERT INTO public.chaines_production_usine
  (produit, ville, building_id, matiere, salaire_pa)
VALUES ('derives_petrochimiques','ville_b','raffinerie-montrouge','petrole',70)
ON CONFLICT (produit) DO UPDATE SET
  ville=EXCLUDED.ville, building_id=EXCLUDED.building_id,
  matiere=EXCLUDED.matiere, salaire_pa=EXCLUDED.salaire_pa;
INSERT INTO public.ordres_couts (fn,pa,cost)
VALUES ('produire_derives_petrochimiques',1,0)
ON CONFLICT DO NOTHING;
