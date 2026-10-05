-- SEED -- camions_destinations
-- ============================================================================
-- Table      : public.camions_destinations
-- Domaine    : militaire
-- Categorie  : B (contenu initial d'empire)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 4
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- Destinations ouvertes aux camions d'un pays.
-- ============================================================================

INSERT INTO public.camions_destinations (pays, cle, ville, building_id, room_id, libelle, rang) VALUES ('republic', 'multimodal_capitale', 'capitale', 'centre-multinodal-luthecia', 'hall_gare', 'Centre Multimodal de Luthécia', '1');
INSERT INTO public.camions_destinations (pays, cle, ville, building_id, room_id, libelle, rang) VALUES ('republic', 'multimodal_ville_a', 'ville_a', 'centre-multinodal-port-sainte-marie', 'hall_gare_psm', 'Centre Multimodal de Port-Sainte-Marie', '2');
INSERT INTO public.camions_destinations (pays, cle, ville, building_id, room_id, libelle, rang) VALUES ('republic', 'multimodal_ville_b', 'ville_b', 'centre-multinodal-montrouge', 'hall_gare_montrouge', 'Centre Multimodal de Montrouge', '3');
INSERT INTO public.camions_destinations (pays, cle, ville, building_id, room_id, libelle, rang) VALUES ('republic', 'qhs', 'qhs', 'qhs-prison', 'entree_qhs', 'Quartier Haute Sécurité', '4');
