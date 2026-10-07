-- SEED -- directions_etablissements
-- ============================================================================
-- Table      : public.directions_etablissements
-- Domaine    : finances publiques
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 6
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- Quel etablissement chaque poste de direction dirige, ou, et pour quel
-- salaire quotidien. Miroir de DIRECTEUR_USINE_INFO, ENTREPOT_PAR_VILLE et
-- SALAIRE_DIRECTEUR (plateau-justice-economie.js). Lue par
-- percevoir_salaire_directeur, qui n'accepte plus ni ville ni batiment ni
-- montant du navigateur. Seul Republia y figure : aucun etablissement de
-- production n'est declare pour les trois autres empires, et en inventer
-- serait du game design.
-- ============================================================================

INSERT INTO public.directions_etablissements (pays, poste_id, ville, souscle, building_id, salaire_jour) VALUES ('republic', 'directeur_entrepot', 'capitale', 'entrepot', 'entrepot-logistique-luthecia', '500');
INSERT INTO public.directions_etablissements (pays, poste_id, ville, souscle, building_id, salaire_jour) VALUES ('republic', 'directeur_entrepot', 'ville_a', 'entrepot', 'entrepot-logistique-psm', '500');
INSERT INTO public.directions_etablissements (pays, poste_id, ville, souscle, building_id, salaire_jour) VALUES ('republic', 'directeur_entrepot', 'ville_b', 'entrepot', 'entrepot-logistique-montrouge', '500');
INSERT INTO public.directions_etablissements (pays, poste_id, ville, souscle, building_id, salaire_jour) VALUES ('republic', 'directeur_pharma', 'capitale', 'usine', 'usine-pharmaceutique-luthecia', '500');
INSERT INTO public.directions_etablissements (pays, poste_id, ville, souscle, building_id, salaire_jour) VALUES ('republic', 'directeur_raffinerie', 'ville_b', 'usine', 'raffinerie-montrouge', '500');
INSERT INTO public.directions_etablissements (pays, poste_id, ville, souscle, building_id, salaire_jour) VALUES ('republic', 'directeur_tabac_alcools', 'ville_a', 'usine', 'pole-tabac-alcools-psm', '500');
