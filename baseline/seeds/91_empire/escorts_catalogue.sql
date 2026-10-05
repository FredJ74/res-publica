-- SEED -- escorts_catalogue
-- ============================================================================
-- Table      : public.escorts_catalogue
-- Domaine    : personnage et presence
-- Categorie  : B (contenu initial d'empire)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 7
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- 7 identites d'escorts, source unique du nom et des images.
-- ============================================================================

INSERT INTO public.escorts_catalogue (escort_id, pays, nom, genre, portrait, vignette, cadrage, rang, actif) VALUES ('escort_beatrice', 'republic', 'Béatrice', 'F', 'images/escort-f-3-robe-marine.png', 'images/escort-f-3-robe-marine-vignette.jpg', '50% 15%', '4', 'true');
INSERT INTO public.escorts_catalogue (escort_id, pays, nom, genre, portrait, vignette, cadrage, rang, actif) VALUES ('escort_jean_philippe', 'republic', 'Jean-Philippe', 'H', 'images/escort-h-3-chemise-ouverte.png', 'images/escort-h-3-chemise-ouverte-vignette.jpg', '50% 15%', '3', 'true');
INSERT INTO public.escorts_catalogue (escort_id, pays, nom, genre, portrait, vignette, cadrage, rang, actif) VALUES ('escort_julien', 'republic', 'Julien', 'H', 'images/escort-h-1-costume-beige.png', 'images/escort-h-1-costume-beige-vignette.jpg', '50% 15%', '1', 'true');
INSERT INTO public.escorts_catalogue (escort_id, pays, nom, genre, portrait, vignette, cadrage, rang, actif) VALUES ('escort_natacha', 'republic', 'Natacha', 'F', 'images/escort-f-1-robe-verte.png', 'images/escort-f-1-robe-verte-vignette.jpg', '50% 15%', '1', 'true');
INSERT INTO public.escorts_catalogue (escort_id, pays, nom, genre, portrait, vignette, cadrage, rang, actif) VALUES ('escort_rodolphe', 'republic', 'Rodolphe', 'H', 'images/escort-h-2-chemise-noire.png', 'images/escort-h-2-chemise-noire-vignette.jpg', '50% 15%', '2', 'true');
INSERT INTO public.escorts_catalogue (escort_id, pays, nom, genre, portrait, vignette, cadrage, rang, actif) VALUES ('escort_roxane', 'republic', 'Roxane', 'F', 'images/escort-republic.png', 'images/escort-republic-vignette.jpg', '50% 15%', '2', 'true');
INSERT INTO public.escorts_catalogue (escort_id, pays, nom, genre, portrait, vignette, cadrage, rang, actif) VALUES ('escort_veronique', 'republic', 'Véronique', 'F', 'images/escort-f-2-robe-or.png', 'images/escort-f-2-robe-or-vignette.jpg', '50% 15%', '3', 'true');
