-- SEED -- pa_bonus_hotel
-- ============================================================================
-- Table      : public.pa_bonus_hotel
-- Domaine    : finances publiques
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 4
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- Bonus de PA par chambre d'hotel.
-- ============================================================================

INSERT INTO public.pa_bonus_hotel (building_id, montant) VALUES ('hotel-mineur', '2');
INSERT INTO public.pa_bonus_hotel (building_id, montant) VALUES ('hotel-port', '2');
INSERT INTO public.pa_bonus_hotel (building_id, montant) VALUES ('hotel-republica', '2');
INSERT INTO public.pa_bonus_hotel (building_id, montant) VALUES ('palais-presidentiel', '8');
