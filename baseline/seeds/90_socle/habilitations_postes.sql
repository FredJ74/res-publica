-- SEED -- habilitations_postes
-- ============================================================================
-- Table      : public.habilitations_postes
-- Domaine    : divers et technique
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 4
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- QUEL POSTE INSTITUTIONNEL EXIGE QUELLE HABILITATION. Quatre lignes --
-- juge, procureur, commissaire, commandant -- et quatre seulement : AUCUN
-- poste politique n'y figure. Un ministere, une mairie, une presidence ne
-- sont pas des professions, et les soumettre a une carriere serait
-- inventer une regle que personne n'a arbitree. Lue par
-- poste_attribuer_interne, le goulot unique par lequel passent les trois
-- chemins d'acces a un poste nomme.
--
-- ARBITRAGE DE GAME DESIGN
-- SEED INDISPENSABLE : sans ces lignes, la garde de carriere ne s'applique
-- a aucun poste, et un officier redevient nommable juge dans un monde
-- neuf.
-- ============================================================================

INSERT INTO public.habilitations_postes (poste_id, habilitation) VALUES ('commandant', 'militaire');
INSERT INTO public.habilitations_postes (poste_id, habilitation) VALUES ('commissaire', 'commissaire');
INSERT INTO public.habilitations_postes (poste_id, habilitation) VALUES ('juge', 'juge');
INSERT INTO public.habilitations_postes (poste_id, habilitation) VALUES ('procureur', 'procureur');
