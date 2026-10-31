-- SEED -- habilitations
-- ============================================================================
-- Table      : public.habilitations
-- Domaine    : divers et technique
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 7
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- CE QU'UNE CARRIERE OUVRE, NOMME. Sept habilitations professionnelles :
-- avocat, juge, procureur, commissaire, militaire, medecine, communication.
-- Declarees et non deduites -- ajouter une correspondance est une LIGNE, pas
-- une migration de code. Seules les correspondances CERTAINES y figurent :
-- celles arbitrees (JUSTICE) et celles que le code etablissait deja ailleurs
-- (`aQualificationMilitaire`, `QUALIFICATIONS_PAR_CARRIERE`).
--
-- ARBITRAGE DE GAME DESIGN
-- SEED INDISPENSABLE : sans ces lignes, `habilitation_ouverte` rend false
-- pour tout le monde -- fail closed -- et aucune fonction specialisee n'est
-- accessible dans un monde neuf.
-- ============================================================================

-- SEED -- habilitations
-- ============================================================================
-- Table      : public.habilitations
-- Domaine    : divers et technique
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 7
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- CE QU'UNE CARRIERE OUVRE, NOMME. Sept habilitations professionnelles :
-- avocat, juge, procureur, commissaire, militaire, medecine, communication.
-- Declarees et non deduites -- ajouter une correspondance est une LIGNE, pas
-- une migration de code. Seules les correspondances CERTAINES y figurent :
-- celles arbitrees (JUSTICE) et celles que le code etablissait deja ailleurs
-- (`aQualificationMilitaire`, `QUALIFICATIONS_PAR_CARRIERE`).
--
-- ARBITRAGE DE GAME DESIGN
-- SEED INDISPENSABLE : sans ces lignes, `habilitation_ouverte` rend false
-- pour tout le monde -- fail closed -- et aucune fonction specialisee n'est
-- accessible dans un monde neuf.
-- ============================================================================

INSERT INTO public.habilitations (id, libelle, note) VALUES ('avocat', 'Exercer comme avocat', 'Exiger la carriere JUSTICE : arbitrage du 12 octobre 2026. Remplace le registre vide justice_barreau_qualifications.');
INSERT INTO public.habilitations (id, libelle, note) VALUES ('commissaire', 'Diriger un commissariat', 'Arbitrage du 12 octobre 2026.');
INSERT INTO public.habilitations (id, libelle, note) VALUES ('communication', 'Exercer dans la communication', 'Deja declaree par QUALIFICATIONS_PAR_CARRIERE ; aucun poste institutionnel ne l''exige a ce jour.');
INSERT INTO public.habilitations (id, libelle, note) VALUES ('juge', 'Sieger comme juge', 'Arbitrage du 12 octobre 2026.');
INSERT INTO public.habilitations (id, libelle, note) VALUES ('medecine', 'Exercer la medecine', 'Deja declaree par QUALIFICATIONS_PAR_CARRIERE ; aucun poste institutionnel ne l''exige a ce jour.');
INSERT INTO public.habilitations (id, libelle, note) VALUES ('militaire', 'Commander une troupe', 'Correspondance deja ecrite cote navigateur par aQualificationMilitaire depuis le chantier militaire ; ce lot la rend serveur-autoritaire.');
INSERT INTO public.habilitations (id, libelle, note) VALUES ('procureur', 'Diriger le parquet', 'Arbitrage du 12 octobre 2026.');
