-- SEED -- pnj_candidats_catalogue
-- ============================================================================
-- Table      : public.pnj_candidats_catalogue
-- Domaine    : socle PNJ
-- Categorie  : B (contenu initial d'empire)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 12
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- 12 identites de candidats a l'embauche (Grobras). Contenu authored.
--
-- ARBITRAGE DE GAME DESIGN
-- Seedee par un fichier du depot ABSENT du registre Supabase : verifier la
-- source avant 2E.
-- ============================================================================

INSERT INTO public.pnj_candidats_catalogue (candidat_id, employeur_id, metier, nom, genre, accroche, portrait, vignette, cadrage, rang, actif) VALUES ('grobras-ag-01', 'grobras-securite', 'agent_securite', 'Gérard Menvussa', 'H', 'Quinze ans de faction. N''a jamais rien vu, et le dit avec aplomb.', NULL, NULL, NULL, '1', 'true');
INSERT INTO public.pnj_candidats_catalogue (candidat_id, employeur_id, metier, nom, genre, accroche, portrait, vignette, cadrage, rang, actif) VALUES ('grobras-ag-02', 'grobras-securite', 'agent_securite', 'Albert Hagarde', 'H', 'Ancien veilleur de nuit à la raffinerie. Dort les yeux ouverts, prétend-il.', NULL, NULL, NULL, '2', 'true');
INSERT INTO public.pnj_candidats_catalogue (candidat_id, employeur_id, metier, nom, genre, accroche, portrait, vignette, cadrage, rang, actif) VALUES ('grobras-ag-03', 'grobras-securite', 'agent_securite', 'Firmin Poigné', 'H', 'Poignée de main qui laisse une trace. Peu de mots, jamais deux fois le même.', NULL, NULL, NULL, '3', 'true');
INSERT INTO public.pnj_candidats_catalogue (candidat_id, employeur_id, metier, nom, genre, accroche, portrait, vignette, cadrage, rang, actif) VALUES ('grobras-ag-04', 'grobras-securite', 'agent_securite', 'Sylvain Guérite', 'H', 'Né dans une cabine de gardien, dit la légende de l''agence.', NULL, NULL, NULL, '4', 'true');
INSERT INTO public.pnj_candidats_catalogue (candidat_id, employeur_id, metier, nom, genre, accroche, portrait, vignette, cadrage, rang, actif) VALUES ('grobras-ag-05', 'grobras-securite', 'agent_securite', 'Léon Tourniquet', 'H', 'Tenait l''entrée du stade. Compte les gens par réflexe, même au café.', NULL, NULL, NULL, '5', 'true');
INSERT INTO public.pnj_candidats_catalogue (candidat_id, employeur_id, metier, nom, genre, accroche, portrait, vignette, cadrage, rang, actif) VALUES ('grobras-ag-06', 'grobras-securite', 'agent_securite', 'Rachel Barrage', 'F', 'Un mètre quatre-vingts dans un couloir d''un mètre vingt. Personne ne passe.', NULL, NULL, NULL, '6', 'true');
INSERT INTO public.pnj_candidats_catalogue (candidat_id, employeur_id, metier, nom, genre, accroche, portrait, vignette, cadrage, rang, actif) VALUES ('grobras-ag-07', 'grobras-securite', 'agent_securite', 'Brigitte Ronde', 'F', 'Fait le tour du bâtiment toutes les vingt minutes, montre à la main.', NULL, NULL, NULL, '7', 'true');
INSERT INTO public.pnj_candidats_catalogue (candidat_id, employeur_id, metier, nom, genre, accroche, portrait, vignette, cadrage, rang, actif) VALUES ('grobras-ag-08', 'grobras-securite', 'agent_securite', 'Josette Cadenas', 'F', 'Vérifie trois fois chaque serrure. La troisième fois est pour elle.', NULL, NULL, NULL, '8', 'true');
INSERT INTO public.pnj_candidats_catalogue (candidat_id, employeur_id, metier, nom, genre, accroche, portrait, vignette, cadrage, rang, actif) VALUES ('grobras-mc-01', 'grobras-securite', 'maitre_chien', 'Roger Croquignol', 'H', 'Avec Mâchefer, berger noir de sept ans. Ne lâche jamais la laisse.', NULL, NULL, NULL, '1', 'true');
INSERT INTO public.pnj_candidats_catalogue (candidat_id, employeur_id, metier, nom, genre, accroche, portrait, vignette, cadrage, rang, actif) VALUES ('grobras-mc-02', 'grobras-securite', 'maitre_chien', 'Marcel Mordu', 'H', 'Avec Sucrette, malinois. Le nom est de sa fille ; le caractère ne l''est pas.', NULL, NULL, NULL, '2', 'true');
INSERT INTO public.pnj_candidats_catalogue (candidat_id, employeur_id, metier, nom, genre, accroche, portrait, vignette, cadrage, rang, actif) VALUES ('grobras-mc-03', 'grobras-securite', 'maitre_chien', 'Ginette Molosse', 'F', 'Avec Praline, rottweiler. Parle au chien, pas aux clients.', NULL, NULL, NULL, '3', 'true');
INSERT INTO public.pnj_candidats_catalogue (candidat_id, employeur_id, metier, nom, genre, accroche, portrait, vignette, cadrage, rang, actif) VALUES ('grobras-mc-04', 'grobras-securite', 'maitre_chien', 'Anatole Crocs', 'H', 'Avec Réglisse, dobermann. Les deux ont le même regard.', NULL, NULL, NULL, '4', 'true');
