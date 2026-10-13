-- SEED -- carrieres
-- ============================================================================
-- Table      : public.carrieres
-- Domaine    : divers et technique
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 10
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- LES DIX FAMILLES PROFESSIONNELLES, miroir serveur de CAREERS (data.js).
-- C'est le registre que lisent `carrieres_de`, `habilitations_carrieres` et
-- `universite_cursus` : sans lui, aucune verification de carriere n'est
-- possible au serveur, et un personnage redevient le couteau suisse
-- professionnel que ce lot ferme. Registre d'autorite -- aucune fonction ne
-- l'ecrit, chaque ligne est une migration.
--
-- ARBITRAGE DE GAME DESIGN
-- SEED INDISPENSABLE. Un monde neuf doit naitre avec ses dix carrieres :
-- elles sont le vocabulaire de la creation de personnage ET la condition de
-- toutes les fonctions specialisees. Une table vide fermerait le poste de
-- juge, de procureur, de commissaire, de commandant et le barreau.
-- ============================================================================

INSERT INTO public.carrieres (id, libelle, ordre) VALUES ('business', 'Affaires — Homme d''affaires / Lobbyiste', '2');
INSERT INTO public.carrieres (id, libelle, ordre) VALUES ('clergy', 'Religion — Chef de culte', '5');
INSERT INTO public.carrieres (id, libelle, ordre) VALUES ('criminal_c', 'Crime organisé — Criminel organisé', '9');
INSERT INTO public.carrieres (id, libelle, ordre) VALUES ('doctor', 'Professions intellectuelles — Médecin / Universitaire', '6');
INSERT INTO public.carrieres (id, libelle, ordre) VALUES ('escort', 'Prostitution — Prostitué(e)', '10');
INSERT INTO public.carrieres (id, libelle, ordre) VALUES ('intel', 'Renseignement — Agent des services', '8');
INSERT INTO public.carrieres (id, libelle, ordre) VALUES ('magistrat', 'Justice — Magistrat / Avocat', '3');
INSERT INTO public.carrieres (id, libelle, ordre) VALUES ('officer', 'Armée — Officier supérieur / Mercenaire', '1');
INSERT INTO public.carrieres (id, libelle, ordre) VALUES ('press', 'Médias & Communication — Grand journaliste / Influenceur', '4');
INSERT INTO public.carrieres (id, libelle, ordre) VALUES ('worker', 'Monde ouvrier — Ouvrier / Syndicaliste', '7');
