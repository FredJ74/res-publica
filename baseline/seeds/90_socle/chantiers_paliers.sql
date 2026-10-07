-- SEED -- chantiers_paliers
-- ============================================================================
-- Table      : public.chantiers_paliers
-- Domaine    : economie
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 4
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- Paliers d'avancement d'un chantier.
--
-- AVERTISSEMENT : CETTE TABLE EST UN MIROIR DE data.js
-- Un generateur existe deja :
-- outils/generateurs/generer_miroirs_chantiers.py. Les lignes ci-dessous
-- sont copiees depuis la base, conformement a la strategie seed_complet du
-- chantier 2C -- mais copier un miroir fige sa derive. Celui des couts
-- d'ordre avait derive de 24 lignes mortes et 19 ordres gratuits non
-- declares. A terme, ce fichier doit etre ecrit par son generateur depuis
-- data.js, et la table doit rejoindre 95_a-regenerer.
-- ============================================================================

INSERT INTO public.chantiers_paliers (palier, label, duree_jours, cout_total, cout_materiaux, cout_travail, heures_totales, apport_minimal, gabarit) VALUES ('building', 'Building', '24', '120000', '36000', '84000', '1200', '42000', '{"type": "construction", "arrete": null, "niveau": "building", "coutTotal": 120000, "jourDebut": 1, "travauxPJ": [], "dureeJours": 24, "evenements": [], "jourTraite": null, "totalVerse": 0, "tresorerie": 0, "coutTravail": 84000, "heuresFaites": 0, "coutMateriaux": 36000, "heuresTotales": 1200, "stockMateriaux": {"bois": 0, "metal": 0, "minerai": 0}, "progressionJours": 0, "ventesMateriauxPJ": []}');
INSERT INTO public.chantiers_paliers (palier, label, duree_jours, cout_total, cout_materiaux, cout_travail, heures_totales, apport_minimal, gabarit) VALUES ('commerce_premium', 'Commerce premium', '18', '90000', '27000', '63000', '900', '31500', '{"type": "construction", "arrete": null, "niveau": "commerce_premium", "coutTotal": 90000, "jourDebut": 1, "travauxPJ": [], "dureeJours": 18, "evenements": [], "jourTraite": null, "totalVerse": 0, "tresorerie": 0, "coutTravail": 63000, "heuresFaites": 0, "coutMateriaux": 27000, "heuresTotales": 900, "stockMateriaux": {"bois": 0, "metal": 0, "minerai": 0}, "progressionJours": 0, "ventesMateriauxPJ": []}');
INSERT INTO public.chantiers_paliers (palier, label, duree_jours, cout_total, cout_materiaux, cout_travail, heures_totales, apport_minimal, gabarit) VALUES ('commerce_standard', 'Commerce standard', '12', '60000', '18000', '42000', '600', '21000', '{"type": "construction", "arrete": null, "niveau": "commerce_standard", "coutTotal": 60000, "jourDebut": 1, "travauxPJ": [], "dureeJours": 12, "evenements": [], "jourTraite": null, "totalVerse": 0, "tresorerie": 0, "coutTravail": 42000, "heuresFaites": 0, "coutMateriaux": 18000, "heuresTotales": 600, "stockMateriaux": {"bois": 0, "metal": 0, "minerai": 0}, "progressionJours": 0, "ventesMateriauxPJ": []}');
INSERT INTO public.chantiers_paliers (palier, label, duree_jours, cout_total, cout_materiaux, cout_travail, heures_totales, apport_minimal, gabarit) VALUES ('hangar', 'Hangar', '6', '30000', '9000', '21000', '300', '10500', '{"type": "construction", "arrete": null, "niveau": "hangar", "coutTotal": 30000, "jourDebut": 1, "travauxPJ": [], "dureeJours": 6, "evenements": [], "jourTraite": null, "totalVerse": 0, "tresorerie": 0, "coutTravail": 21000, "heuresFaites": 0, "coutMateriaux": 9000, "heuresTotales": 300, "stockMateriaux": {"bois": 0, "metal": 0, "minerai": 0}, "progressionJours": 0, "ventesMateriauxPJ": []}');
