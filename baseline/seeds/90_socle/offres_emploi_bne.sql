-- SEED -- offres_emploi_bne
-- ============================================================================
-- Table      : public.offres_emploi_bne
-- Domaine    : economie
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 7
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- MIROIR SERVEUR des offres du Bureau national de l'emploi, genere depuis
-- OFFRES_EMPLOI_BNE (data.js) par
-- outils/generateurs/generer_offres_emploi_bne.py. Le nombre de PLACES borne
-- une autorisation : le transmettre depuis le navigateur serait la faille
-- fermee le meme jour sur l'approvisionnement de chantier. Seules les
-- valeurs qui BORNENT une decision serveur sont miroitees -- le libelle part
-- en clair dans les messages du jeu.
--
-- ARBITRAGE DE GAME DESIGN
-- Aucun : c'est un miroir. Il se REGENERE, il ne se decide pas.
-- ============================================================================

INSERT INTO public.offres_emploi_bne (id, job, portee, ville, salaire, places) VALUES ('banquier_national', 'banquier', 'nationale', NULL, '0', '1');
INSERT INTO public.offres_emploi_bne (id, job, portee, ville, salaire, places) VALUES ('commercant_national', 'commercant', 'nationale', NULL, '0', '3');
INSERT INTO public.offres_emploi_bne (id, job, portee, ville, salaire, places) VALUES ('docker_psm', 'docker', 'locale', 'ville_a', '220', '2');
INSERT INTO public.offres_emploi_bne (id, job, portee, ville, salaire, places) VALUES ('hotelier_montrouge', 'hotelier', 'locale', 'ville_b', '250', '1');
INSERT INTO public.offres_emploi_bne (id, job, portee, ville, salaire, places) VALUES ('hotesse_ambassade', 'hotesse', 'internationale', NULL, '0', '2');
INSERT INTO public.offres_emploi_bne (id, job, portee, ville, salaire, places) VALUES ('secretaire_nationale', 'secretaire', 'nationale', NULL, '0', '3');
INSERT INTO public.offres_emploi_bne (id, job, portee, ville, salaire, places) VALUES ('serveur_luthecia', 'serveur', 'locale', 'capitale', '200', '2');
